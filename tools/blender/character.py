"""Персонаж «Держись!»: модель, мультяшный материал и рендер превью.

Запуск (без интерфейса Blender):
    blender -b --factory-startup -P tools/blender/character.py -- --out assets/characters/v2

Персонаж — мармеладный «боб» как на концепт-листе docs/референсы/reference.png:
тело выше, чем шире, короткие руки и ноги, два вытянутых чёрных глаза, плоская заливка
с одной тенью и бликом, толстый тёмный контур (вывернутая оболочка).
Части — отдельные гладкие объекты на иерархии пустышек-«костей»: root → body → arm/leg.
Единицы — метры. Ноги стоят на z = 0, лицо смотрит на камеру с поворотом вправо.

Контур рисуется по готовому кадру, а не вывернутой оболочкой (v1): оболочка каждой части
протыкала соседнюю на вогнутых стыках — тёмные зазубрины у плеч и серпик у ступни.
Каждый кадр рендерится ещё служебным проходом «глубина + номер части». По нему:
внешний контур — равномерная кайма вокруг силуэта; внутренняя линия — только там, где одна
часть заметно ближе к камере, чем соседняя (рука перед телом, ближняя нога перед дальней).
На стыке руки с телом глубина непрерывна — линии нет.
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
# Номера частей в служебном проходе: линия рисуется только между разными частями.
# Ступня — та же часть, что нога: шва между ними нет.
PART_BODY, PART_ARM_L, PART_ARM_R, PART_LEG_L, PART_LEG_R = 1, 2, 3, 4, 5
# Внутренняя линия тоньше внешней. Её толщина растёт с разницей глубины соседних частей:
# от нуля при DEPTH_STEP_MIN до полной при DEPTH_STEP_FULL (м) — линия сходит на нет кончиком,
# а не обрывается ступенькой там, где рука выходит из тела.
INNER_LINE_WIDTH = 0.045
DEPTH_STEP_MIN = 0.03
DEPTH_STEP_FULL = 0.12
# Рендер в SUPERSAMPLE раз крупнее, линии считаются там же, потом кадр уменьшается — сглаживание.
SUPERSAMPLE = 2


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


def add_part(name: str, mesh: bpy.types.Mesh, parent: bpy.types.Object, material, part: int,
             location=(0, 0, 0), rotation=(0, 0, 0)) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    obj.rotation_euler = rotation
    obj.pass_index = part
    mesh.materials.append(material)
    subsurf = obj.modifiers.new("Smooth", "SUBSURF")
    subsurf.levels = 1
    subsurf.render_levels = 2
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


def build_character(body_mat, eye_mat) -> dict:
    root = add_bone("root", None, (0, 0, 0))
    root.rotation_euler = (0, 0, math.radians(FACING_DEG))

    # Тело: поворот и сплющивание вокруг низа — так приседает и тянется «мармелад».
    body_bone = add_bone("body", root, (0, 0, BODY_CENTER_Z - BODY_RADII[2]))
    body = add_part("Body", ellipsoid_mesh("Body", BODY_RADII, flare=BODY_BOTTOM_FLARE,
                                           squareness=BODY_SQUARENESS),
                    body_bone, body_mat, PART_BODY, location=(0, 0, BODY_RADII[2]))

    def on_face(x: float, z: float, lift: float) -> Vector:
        """Точка на передней поверхности тела (в координатах кости тела)."""
        hit, location, normal, _ = body.ray_cast(Vector((x, -3.0, z)), Vector((0.0, 1.0, 0.0)))
        return body.location + location + normal * lift if hit else body.location + Vector((x, -0.4, z))

    # Глаза — вытянутые овалы в верхней трети, чуть вдавлены в поверхность.
    eyes = []
    for side in (-1, 1):
        eye = add_part(f"Eye.{'L' if side < 0 else 'R'}", ellipsoid_mesh("Eye", (0.068, 0.035, 0.14)),
                       body_bone, eye_mat, PART_BODY, location=on_face(0.16 * side, 0.30, -0.012))
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
    smile.pass_index = PART_BODY

    parts = {"root": root, "body": body_bone, "eyes": eyes}
    for side, label in ((-1, "L"), (1, "R")):
        # Нога: бедро у низа тела, стопа — сплюснутый шарик под ней. Стопа по центру ноги, а не
        # вынесена вперёд: при повороте персонажа вынесенный носок торчал сбоку бугорком.
        leg_part = PART_LEG_L if side < 0 else PART_LEG_R
        leg = add_bone(f"leg.{label}", root, (LEG_X * side, 0.0, 0.42))
        add_part(f"Leg.{label}", capsule_mesh("Leg", 0.17, 0.2), leg, body_mat, leg_part)
        add_part(f"Foot.{label}", ellipsoid_mesh("Foot", (0.2, 0.22, 0.13)), leg, body_mat, leg_part,
                 location=(0.0, -0.02, -0.3))
        parts[f"leg.{label}"] = leg

        # Рука: короткая «сосиска» от плеча, опущена и разведена в стороны.
        arm = add_bone(f"arm.{label}", body_bone,
                       (ARM_SHOULDER[0] * side, ARM_SHOULDER[1], ARM_SHOULDER[2] - (BODY_CENTER_Z - BODY_RADII[2])))
        parts[f"arm.{label}"] = arm
        parts[f"arm_mesh.{label}"] = add_part(f"Arm.{label}", capsule_mesh("Arm", 0.135, 0.36), arm,
                                              body_mat, PART_ARM_L if side < 0 else PART_ARM_R)
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
    # Прыжок: тело вытянуто, руки вверх буквой V, дальняя нога вперёд, ближняя назад.
    # Раньше ноги смотрели навстречу друг другу и перекрещивались — читалось как спотыкание.
    "jump": (1, 1, False, lambda p, t: set_pose(
        p, body_scale=(0.9, 1.12), lean=4.0, legs=(16, -26), arms_spread=(145, 140))),
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


def id_material() -> bpy.types.Material:
    """Служебный проход: красный канал — глубина от камеры (м), зелёный — номер части."""
    mat = bpy.data.materials.new("PartDepth")
    if hasattr(mat, "use_nodes"):
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    camera = nodes.new("ShaderNodeCameraData")
    info = nodes.new("ShaderNodeObjectInfo")
    combine = nodes.new("ShaderNodeCombineColor")
    links.new(camera.outputs["View Z Depth"], combine.inputs["Red"])
    links.new(info.outputs["Object Index"], combine.inputs["Green"])
    links.new(combine.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], out.inputs["Surface"])
    return mat


def _load_pixels(path: str, size: int) -> np.ndarray:
    """Пиксели файла (RGBA float, строки снизу вверх, как в Blender)."""
    image = bpy.data.images.load(path, check_existing=False)
    pixels = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(size, size, 4)


def _render_color(scene: bpy.types.Scene, path: str) -> np.ndarray:
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return _load_pixels(path, scene.render.resolution_x)


def _render_parts(scene: bpy.types.Scene, id_mat, path: str) -> tuple:
    """Служебный проход без сглаживания: глубина (м, фон — inf) и номер части (фон — 0)."""
    settings = scene.render.image_settings
    eevee = scene.eevee
    saved = (settings.file_format, settings.color_depth, eevee.taa_render_samples, scene.render.filter_size)
    settings.file_format = "OPEN_EXR"
    settings.color_depth = "32"
    eevee.taa_render_samples = 1
    scene.render.filter_size = 0.0
    bpy.context.view_layer.material_override = id_mat
    try:
        pixels = _render_color(scene, path)
    finally:
        bpy.context.view_layer.material_override = None
        settings.file_format, settings.color_depth, eevee.taa_render_samples, scene.render.filter_size = saved
    inside = pixels[..., 3] > 0.5
    depth = np.where(inside, pixels[..., 0], np.inf)
    parts = np.where(inside, np.rint(pixels[..., 1]), 0).astype(np.int32)
    return depth, parts


def _disk(radius: float) -> list:
    r = int(math.ceil(radius))
    return [(dx, dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= radius * radius]


def _shifted(a: np.ndarray, dx: int, dy: int, fill) -> np.ndarray:
    """out[y, x] = a[y + dy, x + dx]; за краем — fill."""
    out = np.full_like(a, fill)
    h, w = a.shape
    out[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)] = (
        a[max(dy, 0):h - max(-dy, 0), max(dx, 0):w - max(-dx, 0)])
    return out


def line_masks(depth: np.ndarray, parts: np.ndarray, px_per_m: float) -> tuple:
    """Маски контура. Внешний — всё в пределах OUTLINE_WIDTH от силуэта. Внутренний — пиксели
    дальней части рядом с другой, более близкой частью; чем больше разница глубины, тем дальше
    от края ближней части доходит линия (до INNER_LINE_WIDTH)."""
    inside = parts > 0
    outer = np.zeros_like(inside)
    for dx, dy in _disk(OUTLINE_WIDTH * px_per_m):
        outer |= _shifted(inside, dx, dy, False)
    inner = np.zeros_like(inside)
    width = INNER_LINE_WIDTH * px_per_m
    for dx, dy in _disk(width):
        need = DEPTH_STEP_MIN + (DEPTH_STEP_FULL - DEPTH_STEP_MIN) * math.hypot(dx, dy) / width
        near_part = _shifted(parts, dx, dy, 0)
        near_depth = _shifted(depth, dx, dy, np.inf)
        inner |= inside & (near_part > 0) & (near_part != parts) & (near_depth < depth - need)
    return outer, inner


OUTLINE_RGB = np.array([int(OUTLINE[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def compose(color: np.ndarray, outer: np.ndarray, inner: np.ndarray) -> np.ndarray:
    """Кадр с контуром: кайма под персонажем, внутренние линии поверх; затем уменьшение
    в SUPERSAMPLE раз (усреднение в premultiplied — края сглажены)."""
    alpha = color[..., 3]
    cover = outer.astype(np.float32)
    premul = color[..., :3] * alpha[..., None] + OUTLINE_RGB * ((1.0 - alpha) * cover)[..., None]
    alpha = alpha + (1.0 - alpha) * cover
    premul[inner] = OUTLINE_RGB
    alpha[inner] = 1.0
    h, w = alpha.shape
    k = SUPERSAMPLE
    premul = premul.reshape(h // k, k, w // k, k, 3).mean(axis=(1, 3))
    alpha = alpha.reshape(h // k, k, w // k, k).mean(axis=(1, 3))
    rgb = np.where(alpha[..., None] > 1e-6, premul / np.maximum(alpha, 1e-6)[..., None], 0.0)
    return np.concatenate([np.clip(rgb, 0.0, 1.0), alpha[..., None]], axis=-1).astype(np.float32)


def render_frame(scene, camera, body_mat, id_mat, size: int, colors, tag: str) -> dict:
    """Текущая поза во всех цветах: цвет -> кадр size×size с контуром."""
    frames_dir = os.path.join(tempfile.gettempdir(), "glue_character_frames")
    os.makedirs(frames_dir, exist_ok=True)
    scene.render.resolution_x = scene.render.resolution_y = size * SUPERSAMPLE
    bpy.context.view_layer.update()
    depth, parts = _render_parts(scene, id_mat, os.path.join(frames_dir, f"{tag}_parts.exr"))
    outer, inner = line_masks(depth, parts, size * SUPERSAMPLE / camera.data.ortho_scale)
    result = {}
    for color_name in colors:
        set_body_color(body_mat, COLORS[color_name])
        color = _render_color(scene, os.path.join(frames_dir, f"{tag}_{color_name}.png"))
        result[color_name] = compose(color, outer, inner)
    return result


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


def render_sheets(scene, camera, parts, body_mat, id_mat, out_dir: str) -> None:
    """Листы спрайтов: строка — состояние, столбец — кадр; по листу на цвет и вариант руки.
    Рядом — character_sheets.json с раскладкой, скоростями и опорными точками для игры."""
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

    for variant in VARIANTS:
        back_arm.hide_render = variant == "noarm"
        sheets = {name: np.zeros((rows * CELL, columns * CELL, 4), dtype=np.float32) for name in COLORS}
        for row, (name, (count, _fps, _loop, pose)) in enumerate(STATES.items()):
            for frame in range(count):
                pose(parts, frame / count)
                bpy.context.view_layer.update()
                if variant == "full":
                    shoulder = parts["arm.R"].matrix_world.translation
                    manifest["states"][name]["shoulder"].append(_to_cell_px(scene, camera, shoulder))
                cells = render_frame(scene, camera, body_mat, id_mat, CELL, COLORS, f"{name}_{frame}")
                # Blender хранит строки снизу вверх: строка 0 листа — внизу массива.
                top = (rows - 1 - row) * CELL
                for color_name, cell in cells.items():
                    sheets[color_name][top:top + CELL, frame * CELL:(frame + 1) * CELL] = cell
        for color_name, sheet in sheets.items():
            filename = f"{color_name}_{variant}.png"
            _save_sheet(sheet, os.path.join(out_dir, filename))
            manifest["sheets"].setdefault(color_name, {})[variant] = filename
            print("SHEET", filename)
    back_arm.hide_render = False
    with open(os.path.join(out_dir, "character_sheets.json"), "w", encoding="utf-8") as file:
        json.dump(manifest, file, ensure_ascii=False, indent=2)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = "assets/characters/v2"
    if "--out" in argv:
        out_dir = argv[argv.index("--out") + 1]
    out_dir = os.path.abspath(out_dir)
    os.makedirs(os.path.join(out_dir, "preview"), exist_ok=True)

    scene = reset_scene()
    camera = add_camera(scene)
    add_light(scene)
    body_mat = toon_material("Body", COLORS["red"])
    eye_mat = flat_material("Eye", "15161c")
    id_mat = id_material()
    parts = build_character(body_mat, eye_mat)

    # Превью: поза покоя крупно, по одному на цвет; с флагом --states — по кадру каждого состояния.
    STATES["idle"][3](parts, 0.0)
    for name, cell in render_frame(scene, camera, body_mat, id_mat, 512, COLORS, "preview").items():
        _save_sheet(cell, os.path.join(out_dir, "preview", f"idle_{name}.png"))
    if "--states" in argv:
        for state, (_count, _fps, _loop, pose) in STATES.items():
            pose(parts, 0.0)
            cell = render_frame(scene, camera, body_mat, id_mat, 512, ["red"], f"state_{state}")["red"]
            _save_sheet(cell, os.path.join(out_dir, "preview", f"state_{state}.png"))

    if "--preview-only" not in argv:
        render_sheets(scene, camera, parts, body_mat, id_mat, out_dir)
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
