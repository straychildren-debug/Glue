"""Персонаж «Держись!»: модель, мультяшный материал и рендер превью.

Запуск (без интерфейса Blender):
    blender -b --factory-startup -P tools/blender/character.py -- --out assets/characters/v1

Персонаж — мармеладный «боб» как на концепт-листе docs/референсы/reference.png:
тело выше, чем шире, короткие руки и ноги, два вытянутых чёрных глаза, плоская заливка
с одной тенью и бликом, толстый тёмный контур (вывернутая оболочка).
Части — отдельные гладкие объекты на иерархии пустышек-«костей»: root → body → arm/leg.
Единицы — метры. Ноги стоят на z = 0, лицо смотрит на камеру с поворотом вправо.
"""

import math
import os
import sys

import json
import tempfile

import bmesh
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Quaternion, Vector

# Цвета игроков — те же, что Player.COLORS в игре.
COLORS = {
    "red": "e5484d",
    "blue": "3e7bfa",
    "yellow": "f2c230",
    "green": "3fb950",
}
OUTLINE = "1a1d33"
OUTLINE_WIDTH = 0.07
# Поворот лица в сторону движения (вправо по экрану), как на концепт-листе.
FACING_DEG = 32.0

# Пропорции, м. Тело — вытянутая капсула: высота ≈ 1,55 ширины.
BODY_CENTER_Z = 1.12
BODY_RADII = (0.52, 0.44, 0.8)
BODY_SQUARENESS = 0.35  # 0 — эллипсоид, больше — бока прямее, как у капсулы
BODY_BOTTOM_FLARE = 1.04  # низ чуть шире — «боб», а не яйцо
LEG_X = 0.22
ARM_SHOULDER = (0.48, 0.0, 1.05)


def hex_color(value: str, alpha: float = 1.0) -> tuple:
    """sRGB hex → линейный RGBA, в котором работают материалы Blender."""
    def channel(c: int) -> float:
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(channel(int(value[i:i + 2], 16)) for i in (0, 2, 4)) + (alpha,)


def shade(rgba: tuple, factor: float) -> tuple:
    return tuple(min(1.0, c * factor) for c in rgba[:3]) + (1.0,)


# --- Сцена ---------------------------------------------------------------------------------

def reset_scene() -> bpy.types.Scene:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"  # цвета как заданы, без AgX/Filmic
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    world.color = (0.0, 0.0, 0.0)
    scene.world = world
    return scene


def add_camera(scene: bpy.types.Scene) -> bpy.types.Object:
    data = bpy.data.cameras.new("Camera")
    data.type = "ORTHO"
    data.ortho_scale = 2.6
    camera = bpy.data.objects.new("Camera", data)
    camera.location = (0.0, -10.0, 0.95)
    camera.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def add_light(scene: bpy.types.Scene) -> None:
    """Солнце сверху слева спереди: тень ложится на правый низ, блик — на левый верх."""
    data = bpy.data.lights.new("Sun", "SUN")
    data.energy = 4.0
    sun = bpy.data.objects.new("Sun", data)
    direction = Vector((0.55, 0.65, -0.75)).normalized()  # куда светит
    sun.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(sun)


# --- Материалы -----------------------------------------------------------------------------

def _normal_band(nodes, links, direction: tuple, threshold: float, low, high):
    """Ступенька по нормали: цвет high там, где нормаль смотрит на direction сильнее threshold.
    Считается из геометрии, а не из света — без шума сэмплирования, края чёткие."""
    geometry = nodes.new("ShaderNodeNewGeometry")
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = Vector(direction).normalized()
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = low
    ramp.color_ramp.elements[1].position = (threshold + 1.0) / 2.0
    ramp.color_ramp.elements[1].color = high
    remap = nodes.new("ShaderNodeMapRange")  # dot ∈ [-1, 1] → [0, 1]
    remap.inputs["From Min"].default_value = -1.0
    remap.inputs["From Max"].default_value = 1.0
    links.new(geometry.outputs["Normal"], dot.inputs[0])
    links.new(dot.outputs["Value"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    return ramp


# Откуда «светит» заливка: тень на стороне, отвёрнутой от этого направления; блик — пятно,
# где нормаль почти совпадает с направлением блика (сверху слева спереди).
SHADE_FROM = (-0.45, -0.75, 0.55)
SHADE_THRESHOLD = -0.18
GLINT_FROM = (-0.55, -0.55, 0.65)
GLINT_THRESHOLD = 0.93


def toon_material(name: str, base_hex: str) -> bpy.types.Material:
    """Плоская заливка: основной цвет, тень одним тоном темнее и резкий светлый блик."""
    mat = bpy.data.materials.new(name)
    if hasattr(mat, "use_nodes"):
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    shade_band = _normal_band(nodes, links, SHADE_FROM, SHADE_THRESHOLD, (0, 0, 0, 1), (1, 1, 1, 1))
    shade_band.label = "shade"
    glint_band = _normal_band(nodes, links, GLINT_FROM, GLINT_THRESHOLD, (0, 0, 0, 1), (1, 1, 1, 1))
    glint_band.label = "glint"
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.label = "body"
    mix_glint = nodes.new("ShaderNodeMix")
    mix_glint.data_type = "RGBA"
    mix_glint.label = "glint"
    emission = nodes.new("ShaderNodeEmission")
    links.new(shade_band.outputs["Color"], mix.inputs["Factor"])
    links.new(mix.outputs["Result"], mix_glint.inputs["A"])
    links.new(glint_band.outputs["Color"], mix_glint.inputs["Factor"])
    links.new(mix_glint.outputs["Result"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], out.inputs["Surface"])
    set_body_color(mat, base_hex)
    return mat


def flat_material(name: str, color_hex: str, backface_culling: bool = False) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    if hasattr(mat, "use_nodes"):
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = hex_color(color_hex)
    mat.node_tree.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    mat.use_backface_culling = backface_culling
    return mat


# --- Геометрия -----------------------------------------------------------------------------

def ellipsoid_mesh(name: str, radii: tuple, segments: int = 32, rings: int = 16,
                   flare: float = 1.0, squareness: float = 0.0) -> bpy.types.Mesh:
    """Эллипсоид; flare > 1 расширяет нижнюю половину (форма «боба»), squareness выпрямляет
    бока в средней части (капсула вместо яйца)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        z = v.co.z
        widen = 1.0 + (flare - 1.0) * max(0.0, -z)
        horizontal = Vector((v.co.x, v.co.y)).length
        if horizontal > 1e-6 and squareness > 0.0:
            # Тянем сечение к радиусу 1 тем сильнее, чем ближе к экватору.
            target = horizontal + (1.0 - horizontal) * squareness * (1.0 - abs(z)) ** 0.5
            widen *= target / horizontal
        v.co = Vector((v.co.x * radii[0] * widen, v.co.y * radii[1] * widen, z * radii[2]))
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    return mesh


def capsule_mesh(name: str, radius: float, length: float) -> bpy.types.Mesh:
    """Капсула вдоль -Z от начала координат: верхний конец в 0, нижний в -length."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=radius)
    for v in bm.verts:
        if v.co.z < 0.0:
            v.co.z -= length
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    return mesh


def add_part(name: str, mesh: bpy.types.Mesh, parent: bpy.types.Object, material,
             outline_mat, location=(0, 0, 0), rotation=(0, 0, 0), outline=True) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    obj.rotation_euler = rotation
    mesh.materials.append(material)
    subsurf = obj.modifiers.new("Smooth", "SUBSURF")
    subsurf.levels = 1
    subsurf.render_levels = 2
    if outline:
        # Вывернутая оболочка: чуть больший силуэт с обратными нормалями, лицевые грани
        # отсекаются — видна только тёмная кайма вокруг части.
        mesh.materials.append(outline_mat)
        solid = obj.modifiers.new("Outline", "SOLIDIFY")
        solid.thickness = OUTLINE_WIDTH
        solid.offset = 1.0
        solid.use_flip_normals = True
        solid.use_rim = False
        solid.material_offset = 1
    return obj


def add_bone(name: str, parent, location) -> bpy.types.Object:
    """«Кость» — пустышка: её поворот и масштаб анимируют прикреплённую часть."""
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.15
    bpy.context.scene.collection.objects.link(empty)
    empty.parent = parent
    empty.location = location
    return empty


def build_character(body_mat, outline_mat, eye_mat) -> dict:
    root = add_bone("root", None, (0, 0, 0))
    root.rotation_euler = (0, 0, math.radians(FACING_DEG))

    # Тело: поворот и сплющивание вокруг низа — так приседает и тянется «мармелад».
    body_bone = add_bone("body", root, (0, 0, BODY_CENTER_Z - BODY_RADII[2]))
    body = add_part("Body", ellipsoid_mesh("Body", BODY_RADII, flare=BODY_BOTTOM_FLARE,
                                           squareness=BODY_SQUARENESS),
                    body_bone, body_mat, outline_mat, location=(0, 0, BODY_RADII[2]))

    def on_face(x: float, z: float, lift: float) -> Vector:
        """Точка на передней поверхности тела (в координатах кости тела)."""
        hit, location, normal, _ = body.ray_cast(Vector((x, -3.0, z)), Vector((0.0, 1.0, 0.0)))
        return body.location + location + normal * lift if hit else body.location + Vector((x, -0.4, z))

    # Глаза — вытянутые овалы в верхней трети, чуть вдавлены в поверхность.
    eyes = []
    for side in (-1, 1):
        eye = add_part(f"Eye.{'L' if side < 0 else 'R'}", ellipsoid_mesh("Eye", (0.068, 0.035, 0.14)),
                       body_bone, eye_mat, outline_mat, location=on_face(0.16 * side, 0.30, -0.012),
                       outline=False)
        eye.rotation_euler = (math.radians(-10.0), 0, math.radians(-side * 9.0))
        eyes.append(eye)

    # Улыбка — короткая дуга под глазами.
    curve = bpy.data.curves.new("Smile", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.016
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    samples = [(-0.07, 0.115), (-0.035, 0.093), (0.0, 0.086), (0.035, 0.093), (0.07, 0.115)]
    spline.points.add(len(samples) - 1)
    for point, (x, z) in zip(spline.points, samples):
        p = on_face(x, z, 0.004)
        point.co = (p.x, p.y, p.z, 1.0)
    curve.materials.append(eye_mat)
    smile = bpy.data.objects.new("Smile", curve)
    bpy.context.scene.collection.objects.link(smile)
    smile.parent = body_bone

    parts = {"root": root, "body": body_bone, "eyes": eyes}
    for side, label in ((-1, "L"), (1, "R")):
        # Нога: бедро у низа тела, стопа — сплюснутый шарик чуть вперёд.
        leg = add_bone(f"leg.{label}", root, (LEG_X * side, 0.0, 0.42))
        add_part(f"Leg.{label}", capsule_mesh("Leg", 0.17, 0.2), leg, body_mat, outline_mat)
        add_part(f"Foot.{label}", ellipsoid_mesh("Foot", (0.19, 0.25, 0.13)), leg, body_mat, outline_mat,
                 location=(0.0, -0.06, -0.31))
        parts[f"leg.{label}"] = leg

        # Рука: короткая «сосиска» от плеча, опущена и разведена в стороны.
        arm = add_bone(f"arm.{label}", body_bone,
                       (ARM_SHOULDER[0] * side, ARM_SHOULDER[1], ARM_SHOULDER[2] - (BODY_CENTER_Z - BODY_RADII[2])))
        parts[f"arm.{label}"] = arm
        parts[f"arm_mesh.{label}"] = add_part(f"Arm.{label}", capsule_mesh("Arm", 0.135, 0.36), arm,
                                              body_mat, outline_mat)
    for bone in [root, body_bone] + [parts[k] for k in ("leg.L", "leg.R", "arm.L", "arm.R")]:
        bone.rotation_mode = "QUATERNION"
        bone["rest_location"] = tuple(bone.location)
    root.rotation_quaternion = Quaternion((0, 0, 1), math.radians(FACING_DEG))
    for eye in eyes:
        eye["rest_scale"] = tuple(eye.scale)
    return parts


# --- Позы ----------------------------------------------------------------------------------
# Поворот «в плоскости экрана» — вокруг мировой оси Y (оси камеры), выраженной в осях персонажа:
# так конечности качаются влево-вправо по экрану, и бег читается в профиль.
# Положительный угол — по часовой стрелке на экране: верх уходит вправо, низ — влево.
SCREEN_AXIS = Vector((math.sin(math.radians(FACING_DEG)), math.cos(math.radians(FACING_DEG)), 0.0))


def _spread(side: int, degrees: float) -> Quaternion:
    """Развод руки в сторону от тела: 0 — вниз вдоль тела, 90 — горизонтально, 180 — вверх."""
    return Quaternion((0, 1, 0), math.radians(-degrees * side))


def _swing(degrees: float) -> Quaternion:
    return Quaternion(SCREEN_AXIS, math.radians(degrees))


def reset_pose(parts: dict) -> None:
    for key in ("body", "leg.L", "leg.R", "arm.L", "arm.R"):
        bone = parts[key]
        bone.location = bone["rest_location"]
        bone.rotation_quaternion = Quaternion()
        bone.scale = (1, 1, 1)
    for eye in parts["eyes"]:
        eye.scale = eye["rest_scale"]


def set_pose(parts: dict, body_scale=(1.0, 1.0), lean=0.0, bob=0.0, legs=(0.0, 0.0),
             arms_spread=(40.0, 40.0), arms_swing=(0.0, 0.0), eyes_closed=False) -> None:
    """Поза одним вызовом. body_scale — (ширина, высота) тела; lean — наклон тела по экрану;
    legs и arms_swing — качание (левая, правая) по экрану; arms_spread — развод рук."""
    reset_pose(parts)
    body = parts["body"]
    body.scale = (body_scale[0], body_scale[0], body_scale[1])
    body.rotation_quaternion = _swing(lean)
    body.location = Vector(body["rest_location"]) + Vector((0, 0, bob))
    for i, (side, label) in enumerate(((-1, "L"), (1, "R"))):
        parts[f"leg.{label}"].rotation_quaternion = _swing(legs[i])
        parts[f"arm.{label}"].rotation_quaternion = _swing(arms_swing[i]) @ _spread(side, arms_spread[i])
    if eyes_closed:
        for eye in parts["eyes"]:
            rest = eye["rest_scale"]
            eye.scale = (rest[0] * 1.5, rest[1], rest[2] * 0.16)


def _wave(t: float, phase: float = 0.0) -> float:
    return math.sin(2.0 * math.pi * (t + phase))


# Состояние → (число кадров, кадров в секунду, зациклено, поза(t), где t ∈ [0, 1)).
# Персонаж смотрит вправо; влево игра отражает спрайт.
STATES = {
    "idle": (8, 8, True, lambda p, t: set_pose(
        p, body_scale=(1 - 0.02 * _wave(t), 1 + 0.03 * _wave(t)),
        arms_spread=(38 + 4 * _wave(t), 38 + 4 * _wave(t)))),
    "run": (8, 14, True, lambda p, t: set_pose(
        p, body_scale=(1 + 0.03 * abs(_wave(t)), 1 - 0.04 * abs(_wave(t))), lean=9.0,
        bob=0.06 * abs(_wave(t, 0.25)),
        legs=(-38 * _wave(t), 38 * _wave(t)), arms_spread=(30, 30),
        arms_swing=(42 * _wave(t), -42 * _wave(t)))),
    "jump": (1, 1, False, lambda p, t: set_pose(
        p, body_scale=(0.92, 1.09), lean=5.0, legs=(-28, 18), arms_spread=(115, 105))),
    "fall": (2, 6, True, lambda p, t: set_pose(
        p, body_scale=(1.03, 0.98), legs=(-12 + 6 * _wave(t, 0.25), 12 - 6 * _wave(t, 0.25)),
        arms_spread=(125 + 10 * _wave(t, 0.25), 125 + 10 * _wave(t, 0.25)))),
    "land": (3, 18, False, lambda p, t: set_pose(
        p, body_scale=((1.14, 1.07, 1.02)[round(t * 3)], (0.8, 0.9, 0.97)[round(t * 3)]),
        legs=(-14, 14), arms_spread=(70, 70))),
    "hang": (4, 6, True, lambda p, t: set_pose(
        p, body_scale=(0.97, 1.05), legs=(9 * _wave(t), -9 * _wave(t)),
        arms_spread=(18, 170))),
    "freeze": (1, 1, False, lambda p, t: set_pose(
        p, body_scale=(1.06, 0.96), legs=(-7, 7), arms_spread=(92, 92), eyes_closed=True)),
}
# Вариант без дальней (правой) руки: во время хвата её рисует игра, она тянется к товарищу.
VARIANTS = ("full", "noarm")
CELL = 256


def set_body_color(material: bpy.types.Material, base_hex: str) -> None:
    """Перекрашивает материал тела: тень, основной цвет, блик (светлый тон, не белый —
    так он читается и на жёлтом)."""
    base = hex_color(base_hex)
    mixes = {n.label: n for n in material.node_tree.nodes if n.bl_idname == "ShaderNodeMix"}
    mixes["body"].inputs["A"].default_value = shade(base, 0.68)
    mixes["body"].inputs["B"].default_value = base
    mixes["glint"].inputs["B"].default_value = tuple(c + (1.0 - c) * 0.6 for c in base[:3]) + (1.0,)


def _render_cell(scene: bpy.types.Scene, path: str) -> np.ndarray:
    """Рендер одного кадра в файл и его пиксели (RGBA float, строки снизу вверх, как в Blender)."""
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(path, check_existing=False)
    pixels = np.empty(CELL * CELL * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(CELL, CELL, 4)


def _save_sheet(pixels: np.ndarray, path: str) -> None:
    height, width = pixels.shape[:2]
    image = bpy.data.images.new(os.path.basename(path), width, height, alpha=True)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def _to_cell_px(scene, camera, point: Vector) -> list:
    """Мировая точка → пиксель кадра (x вправо, y вниз от верхнего левого угла)."""
    ndc = world_to_camera_view(scene, camera, point)
    return [round(ndc.x * CELL, 1), round((1.0 - ndc.y) * CELL, 1)]


def render_sheets(scene, camera, parts, body_mat, out_dir: str) -> None:
    """Листы спрайтов: строка — состояние, столбец — кадр; по листу на цвет и вариант руки.
    Рядом — character_sheets.json с раскладкой, скоростями и опорными точками для игры."""
    frames_dir = os.path.join(tempfile.gettempdir(), "glue_character_frames")
    os.makedirs(frames_dir, exist_ok=True)
    columns = max(state[0] for state in STATES.values())
    rows = len(STATES)
    back_arm = parts["arm_mesh.R"]
    manifest = {
        "cell": CELL,
        "columns": columns,
        "states": {},
        "sheets": {},
    }
    # Опорные точки по позе покоя: ступни, макушка, плечо дальней руки (откуда игра тянет руку).
    STATES["idle"][3](parts, 0.0)
    bpy.context.view_layer.update()
    head_top = Vector((0, 0, BODY_CENTER_Z + BODY_RADII[2]))
    manifest["feet"] = _to_cell_px(scene, camera, Vector((0, 0, 0)))
    manifest["head_top"] = _to_cell_px(scene, camera, head_top)
    for row, (name, (count, fps, loop, _pose)) in enumerate(STATES.items()):
        manifest["states"][name] = {"row": row, "frames": count, "fps": fps, "loop": loop, "shoulder": []}

    for color_name, color in COLORS.items():
        set_body_color(body_mat, color)
        for variant in VARIANTS:
            back_arm.hide_render = variant == "noarm"
            sheet = np.zeros((rows * CELL, columns * CELL, 4), dtype=np.float32)
            for row, (name, (count, _fps, _loop, pose)) in enumerate(STATES.items()):
                for frame in range(count):
                    pose(parts, frame / count)
                    bpy.context.view_layer.update()
                    if color_name == "red" and variant == "full":
                        shoulder = parts["arm.R"].matrix_world.translation
                        manifest["states"][name]["shoulder"].append(_to_cell_px(scene, camera, shoulder))
                    cell = _render_cell(scene, os.path.join(frames_dir, f"{name}_{frame}.png"))
                    # Blender хранит строки снизу вверх: строка 0 листа — внизу массива.
                    top = (rows - 1 - row) * CELL
                    sheet[top:top + CELL, frame * CELL:(frame + 1) * CELL] = cell
            filename = f"{color_name}_{variant}.png"
            _save_sheet(sheet, os.path.join(out_dir, filename))
            manifest["sheets"].setdefault(color_name, {})[variant] = filename
            print("SHEET", filename)
    back_arm.hide_render = False
    with open(os.path.join(out_dir, "character_sheets.json"), "w", encoding="utf-8") as file:
        json.dump(manifest, file, ensure_ascii=False, indent=2)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = "assets/characters/v1"
    if "--out" in argv:
        out_dir = argv[argv.index("--out") + 1]
    out_dir = os.path.abspath(out_dir)
    os.makedirs(os.path.join(out_dir, "preview"), exist_ok=True)

    scene = reset_scene()
    camera = add_camera(scene)
    add_light(scene)
    body_mat = toon_material("Body", COLORS["red"])
    outline_mat = flat_material("Outline", OUTLINE, backface_culling=True)
    eye_mat = flat_material("Eye", "15161c")
    parts = build_character(body_mat, outline_mat, eye_mat)

    # Превью: поза покоя крупно, по одному на цвет.
    STATES["idle"][3](parts, 0.0)
    for name, color in COLORS.items():
        set_body_color(body_mat, color)
        scene.render.filepath = os.path.join(out_dir, "preview", f"idle_{name}.png")
        bpy.ops.render.render(write_still=True)

    if "--preview-only" not in argv:
        scene.render.resolution_x = CELL
        scene.render.resolution_y = CELL
        render_sheets(scene, camera, parts, body_mat, out_dir)
    reset_pose(parts)
    # .blend — в source/ с .gdignore: Godot не должен импортировать его как сцену.
    source_dir = os.path.join(out_dir, "source")
    os.makedirs(source_dir, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source_dir, "character.blend"), check_existing=False)
    backup = os.path.join(source_dir, "character.blend1")
    if os.path.exists(backup):
        os.remove(backup)
    print("CHARACTER_DONE", out_dir)


if __name__ == "__main__":
    main()
