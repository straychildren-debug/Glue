"""Механизмы и предметы «Держись!»: ящики, мост, балка, дверь, плита, финиш, флажок, опора качелей.

Запуск (без интерфейса Blender):
    blender -b --factory-startup -P tools/blender/props.py -- --out assets/props/v1

Стиль тот же, что у персонажа (tools/blender/character.py): плоская заливка с тенью и бликом
по нормали и тёмный контур-оболочка. Всё, с чем можно взаимодействовать, обведено — так оно
отделяется от нарисованных задников. Вид — строго сбоку (ортографическая камера спереди).

Масштаб общий с персонажем: 1 тайл игры = 64 px = 256 px текстуры. Координаты деталей ниже —
в пикселях игры на «холсте» спрайта: x вправо, y вниз от левого верхнего угла (как в Godot).
Растягиваемые детали (мост, балка, дверь, плита) — бесшовный кусок «mid» и торец «end»:
игра повторяет кусок на нужную длину и ставит торцы по краям.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import character as toon  # noqa: E402  (общие материал, контур, сцена)

TILE_PX = 64.0          # пикселей игры на тайл
TEX_PER_TILE = 256      # пикселей текстуры на тайл
# Тот же масштаб, что у персонажа: 56 px игры = рост 1,92 м.
METERS_PER_PX = 1.92 / 56.0
INNER_OUTLINE = 0.55    # контур внутренних деталей тоньше внешнего

WOOD = "b07a45"
WOOD_DARK = "8a5a30"
WOOD_HEAVY = "7a5230"
WOOD_HEAVY_DARK = "5c3d22"
PLANK = "a0703f"
IRON = "4b5563"
# Шипы: кованое железо (светлая и тёмная грани, блик) на пороге из тёплого камня кладки.
SPIKE_LIGHT = "9aa1ab"
SPIKE_DARK = "4f5662"
SPIKE_GLINT = "d6dbe1"
SILL = "6e6253"
SILL_TOP = "9a8b77"
RIVET = "9aa3ad"
STONE = "8b919a"
STONE_DARK = "6f757e"
OPENING = "2b2118"
ARCH_YELLOW = "f2c230"
ARCH_GREEN = "7fdc5a"
PLATE_COLORS = {  # (не нажата, нажата) — как в сером прототипе: плита оранжевая, защёлка фиолетовая
    "plate": ("c2410c", "f2994a"),
    "latch": ("6d28d9", "a78bfa"),
}
FLAG_COLORS = {"off": "9aa3ad", "on": "f2c230"}


def m(px: float) -> float:
    return px * METERS_PER_PX


class Canvas:
    """Холст спрайта: размер в пикселях игры; переводит его координаты в мировые."""

    def __init__(self, width: float, height: float):
        self.width = width
        self.height = height

    def to_world(self, x: float, y: float, depth_y: float = 0.0) -> Vector:
        return Vector((m(x), depth_y, -m(y)))


_materials = {}


def material(kind: str, color: str) -> bpy.types.Material:
    """Матовый мультяшный материал (блик слабее, чем у персонажа) или плоский цвет."""
    key = (kind, color)
    if key in _materials:
        return _materials[key]
    if kind == "flat":
        mat = toon.flat_material(f"flat_{color}", color)
    else:
        mat = toon.toon_material(f"toon_{color}", color)
        base = toon.hex_color(color)
        mixes = {n.label: n for n in mat.node_tree.nodes if n.bl_idname == "ShaderNodeMix"}
        mixes["glint"].inputs["B"].default_value = tuple(c + (1.0 - c) * 0.22 for c in base[:3]) + (1.0,)
    _materials[key] = mat
    return mat


_outline_mat = None


def outline_material() -> bpy.types.Material:
    global _outline_mat
    if _outline_mat is None:
        _outline_mat = toon.flat_material("Outline", toon.OUTLINE, backface_culling=True)
    return _outline_mat


def _finish_object(name: str, mesh: bpy.types.Mesh, mat, bevel_px: float, outline: float):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(mat)
    if bevel_px > 0:
        bevel = obj.modifiers.new("Bevel", "BEVEL")
        bevel.width = m(bevel_px)
        bevel.segments = 3
        bevel.limit_method = "ANGLE"
        bevel.harden_normals = False
    for poly in mesh.polygons:
        poly.use_smooth = True
    if outline > 0:
        mesh.materials.append(outline_material())
        solid = obj.modifiers.new("Outline", "SOLIDIFY")
        solid.thickness = toon.OUTLINE_WIDTH * outline
        solid.offset = 1.0
        solid.use_flip_normals = True
        solid.use_rim = False
        solid.material_offset = 1
    return obj


def box(x0, y0, x1, y1, depth, color, front=0.0, bevel=1.5, outline=1.0, rotate=0.0, kind="toon"):
    """Брусок по прямоугольнику холста (x0, y0)–(x1, y1), толщиной depth (px), передняя грань
    выдвинута к камере на front (px). rotate — поворот в плоскости экрана, градусы."""
    mesh = bpy.data.meshes.new("box")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * m(x1 - x0), v.co.y * m(depth), v.co.z * m(y1 - y0)))
    bm.to_mesh(mesh)
    bm.free()
    obj = _finish_object("box", mesh, material(kind, color), bevel, outline)
    center = Vector((m((x0 + x1) / 2.0), -m(front) + m(depth) / 2.0, -m((y0 + y1) / 2.0)))
    obj.location = center
    obj.rotation_euler = (0.0, math.radians(rotate), 0.0)
    return obj


def polygon_prism(points, depth, color, front=0.0, bevel=1.0, outline=1.0, kind="toon"):
    """Призма по многоугольнику холста (точки в px, по часовой стрелке на экране)."""
    mesh = bpy.data.meshes.new("prism")
    bm = bmesh.new()
    front_verts = [bm.verts.new((m(x), -m(front), -m(y))) for x, y in points]
    face = bm.faces.new(front_verts)
    result = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in result["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0.0, m(depth), 0.0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    return _finish_object("prism", mesh, material(kind, color), bevel, outline)


def arch_points(cx, cy, r_in, r_out, a0=0.0, a1=180.0, steps=12):
    """Кольцевой сектор (дуга) на холсте: углы от a0 до a1 против часовой (0 — вправо)."""
    outer = [(cx + r_out * math.cos(math.radians(a)), cy - r_out * math.sin(math.radians(a)))
             for a in [a0 + (a1 - a0) * i / steps for i in range(steps + 1)]]
    if r_in <= 0:
        return [(cx, cy)] + outer[::-1]
    inner = [(cx + r_in * math.cos(math.radians(a)), cy - r_in * math.sin(math.radians(a)))
             for a in [a0 + (a1 - a0) * i / steps for i in range(steps + 1)]]
    return outer[::-1] + inner


def stud(x, y, radius, color, front=0.0):
    """Шляпка гвоздя или заклёпка: приплюснутый шарик без контура."""
    mesh = bpy.data.meshes.new("stud")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=m(radius))
    for v in bm.verts:
        v.co.y *= 0.5
    bm.to_mesh(mesh)
    bm.free()
    obj = _finish_object("stud", mesh, material("toon", color), 0, 0)
    obj.location = Vector((m(x), -m(front), -m(y)))
    return obj


# --- Детали --------------------------------------------------------------------------------

def crate(heavy: bool) -> Canvas:
    """Ящик 1×1 тайл: рамка из досок, крест-накрест раскос, гвозди. Тяжёлый — тёмное дерево,
    две железные полосы с заклёпками."""
    c = Canvas(64, 64)
    face, frame = (WOOD_HEAVY, WOOD_HEAVY_DARK) if heavy else (WOOD, WOOD_DARK)
    box(3, 3, 61, 61, 40, face, bevel=2.0)
    for x0, y0, x1, y1 in ((3, 3, 61, 12), (3, 52, 61, 61), (3, 12, 12, 52), (52, 12, 61, 52)):
        box(x0, y0, x1, y1, 4, frame, front=3, bevel=1.2, outline=INNER_OUTLINE)
    length = math.hypot(40, 40)
    box(32 - length / 2, 28.5, 32 + length / 2, 35.5, 4, frame, front=3, bevel=1.2,
        outline=INNER_OUTLINE, rotate=45)
    if heavy:
        for y in (19, 45):
            box(1.5, y - 3.5, 62.5, y + 3.5, 6, IRON, front=5, bevel=1.0, outline=INNER_OUTLINE)
            for x in (8, 32, 56):
                stud(x, y, 1.6, RIVET, front=6)
    else:
        for x, y in ((7.5, 7.5), (56.5, 7.5), (7.5, 56.5), (56.5, 56.5)):
            stud(x, y, 1.4, RIVET, front=6)
    return c


def bridge(part: str) -> Canvas:
    """Настил выдвижного моста и ступеньки, толщина 0,5 тайла (32 px). Две продольные доски
    и поперечная планка с гвоздями. mid — бесшовный кусок 32 px, end — левый торец 16 px."""
    if part == "mid":
        c = Canvas(32, 32)
        box(-20, 2, 52, 15, 18, PLANK, bevel=1.5)
        box(-20, 17, 52, 30, 18, PLANK, bevel=1.5)
        box(13, 1, 19, 31, 3, WOOD_DARK, front=2, bevel=1.0, outline=INNER_OUTLINE)
        for y in (8, 24):
            stud(16, y, 1.3, RIVET, front=4)
        return c
    c = Canvas(16, 32)
    box(2, 2, 40, 15, 18, PLANK, bevel=2.5)
    box(2, 17, 40, 30, 18, PLANK, bevel=2.5)
    box(4, 1, 10, 31, 3, WOOD_DARK, front=2, bevel=1.0, outline=INNER_OUTLINE)
    for y in (8, 24):
        stud(7, y, 1.3, RIVET, front=4)
    return c


def beam(part: str) -> Canvas:
    """Брус толщиной 0,25 тайла (16 px): балки над пропастью, насесты, балка качелей.
    mid — бесшовный кусок 32 px, end — левый торец 16 px с годичными кольцами."""
    if part == "mid":
        c = Canvas(32, 16)
        box(-20, 2, 52, 14, 14, PLANK, bevel=2.0)
        box(-20, 6.4, 52, 7.4, 1, WOOD_DARK, front=0.6, bevel=0, outline=0)
        box(-20, 10, 52, 10.8, 1, WOOD_DARK, front=0.6, bevel=0, outline=0)
        return c
    c = Canvas(16, 16)
    box(2, 2, 40, 14, 14, PLANK, bevel=3.0)
    box(8, 6.4, 40, 7.4, 1, WOOD_DARK, front=0.6, bevel=0, outline=0)
    box(8, 10, 40, 10.8, 1, WOOD_DARK, front=0.6, bevel=0, outline=0)
    return c


def door(part: str) -> Canvas:
    """Дверь шириной 1 тайл: три вертикальные доски и железная полоса с заклёпками.
    mid — бесшовный по вертикали кусок 64 px, end — верхний торец 16 px (низ — отражение)."""
    if part == "mid":
        c = Canvas(64, 64)
        for i in range(3):
            x0 = 3 + i * 19.4
            box(x0, -20, x0 + 18.6, 84, 16, WOOD, bevel=1.5)
        box(1.5, 27, 62.5, 37, 5, IRON, front=2, bevel=1.0, outline=INNER_OUTLINE)
        for x in (10, 32, 54):
            stud(x, 32, 1.6, RIVET, front=3)
        return c
    c = Canvas(64, 16)
    for i in range(3):
        x0 = 3 + i * 19.4
        box(x0, 2, x0 + 18.6, 40, 16, WOOD, bevel=3.0)
    return c


def plate(part: str, kind: str = "plate", pressed: bool = False) -> Canvas:
    """Нажимная плита высотой 14 px: каменное основание и цветная крышка сверху, которая идёт
    и по скосам (оранжевая — плита, фиолетовая — защёлка; нажатая — светлая, «горит»).
    mid — бесшовный кусок 32 px, end — левый скос 32 px (у игры скос 28 px на 14 px высоты)."""
    color = PLATE_COLORS[kind][1 if pressed else 0]
    lid_kind = "flat" if pressed else "toon"
    c = Canvas(32, 16)
    if part == "mid":
        box(-20, 8, 52, 16, 14, STONE_DARK, bevel=1.0)
        box(-20, 2, 52, 8.5, 16, color, front=1, bevel=1.0, kind=lid_kind)
        return c
    # Скос: верх идёт от (4, 16) к (32, 2); крышка — полоса 6 px вдоль скоса и сверху.
    polygon_prism([(16, 16), (32, 8), (52, 8), (52, 16)], 14, STONE_DARK, bevel=0.8)
    polygon_prism([(4, 16), (32, 2), (52, 2), (52, 8.5), (32, 8.5), (17, 16)], 16, color, front=1,
                  bevel=0.8, kind=lid_kind)
    return c


def finish(complete: bool) -> Canvas:
    """Дверь финиша 2×3 тайла в каменной раме с аркой. Начало координат игры — середина низа:
    на холсте 184×224 это точка (92, 224). Жёлтая арка, когда пришли все, — зелёная."""
    c = Canvas(184, 224)
    cx, base, spring = 92.0, 224.0, 224.0 - 128.0  # пята арки — на высоте 2 тайла
    # Тёмный проём: прямоугольник и полукруг сверху.
    box(cx - 64, spring, cx + 64, base, 6, OPENING, front=-14, bevel=0, outline=0, kind="flat")
    polygon_prism(arch_points(cx, spring, 0, 64, steps=24), 6, OPENING, front=-14, bevel=0, outline=0,
                  kind="flat")
    # Цветная арка вокруг проёма.
    band = ARCH_GREEN if complete else ARCH_YELLOW
    polygon_prism(arch_points(cx, spring, 64, 73, steps=24), 8, band, front=1, bevel=1.0)
    for x0 in (cx - 73, cx + 64):
        box(x0, spring - 0.5, x0 + 9, base, 8, band, front=1, bevel=1.0)
    # Каменная рама: клинья арки и блоки опор.
    for i in range(7):
        a0, a1 = i * 180 / 7 + 1.2, (i + 1) * 180 / 7 - 1.2
        polygon_prism(arch_points(cx, spring, 73, 88, a0, a1, steps=4), 12, STONE, front=-2, bevel=1.5)
    for side in (-1, 1):
        x0 = cx + 73 if side > 0 else cx - 88
        for y0, y1 in ((spring, spring + 40), (spring + 41.5, spring + 84), (spring + 85.5, base)):
            box(x0, y0, x0 + 15, y1, 12, STONE_DARK if y0 > spring + 40 else STONE, front=-2, bevel=1.5)
    return c


def flag(active: bool) -> Canvas:
    """Флажок чекпоинта: древко 96 px, треугольный флаг. Основание древка — точка (8, 104) холста."""
    c = Canvas(48, 104)
    box(5.5, 6, 10.5, 101, 5, "3a3f47", bevel=1.2)
    stud(8, 5, 3.2, "3a3f47", front=0)
    box(1, 98, 15, 104, 8, STONE, bevel=1.2)
    polygon_prism([(10, 8), (46, 20), (10, 32)], 3, FLAG_COLORS["on" if active else "off"], front=1, bevel=0.8)
    return c


def spike(x: float, base_y: float, width: float, height: float, front: float = 0.0):
    """Кованый четырёхгранный кол остриём вверх, ребром к камере: левая грань светлая,
    правая тёмная (две плоские половины), тёмный контур вокруг всего кола."""
    tip = (x, base_y - height)
    left, right = (x - width / 2.0, base_y), (x + width / 2.0, base_y)
    polygon_prism([left, tip, right], 6, SPIKE_DARK, front=front, bevel=0.6, outline=0.8, kind="flat")
    polygon_prism([left, tip, (x, base_y)], 1, SPIKE_LIGHT, front=front + 0.5, bevel=0, outline=0, kind="flat")
    # Тонкий блик по левому ребру.
    polygon_prism([(left[0] + 1.2, base_y - 1.0), (tip[0] - 0.3, tip[1] + 3.0), (tip[0] - 1.6, tip[1] + 6.5),
                   (left[0] + 3.2, base_y - 1.0)], 1, SPIKE_GLINT, front=front + 0.8, bevel=0, outline=0, kind="flat")


def spikes(part: str) -> Canvas:
    """Шипы: каменный порог высотой 8 px (тёплый камень, как кладка уровня) и на нём два
    кованых кола на кусок 32 px. Игра рисует холст 36 px высотой, низ порога утоплен в землю
    на 4 px. mid — бесшовный кусок 32 px, end — левый торец порога 10 px без кола."""
    if part == "mid":
        c = Canvas(32, 36)
        box(-20, 28, 52, 37, 20, SILL, bevel=1.5)
        box(-20, 28, 52, 30.5, 20.5, SILL_TOP, bevel=0.8, outline=0)
        for x in (8, 24):
            spike(x, 29, 12, 26, front=4)
        return c
    c = Canvas(10, 36)
    box(1.5, 28, 40, 37, 20, SILL, bevel=3.0)
    box(3, 28, 40, 30.5, 20.5, SILL_TOP, bevel=0.8, outline=0)
    return c


def seesaw_base() -> Canvas:
    """Опора качелей: деревянные козлы высотой 1 тайл и железная ступица.
    Шарнир игры — точка (48, 12) холста 96×76; пол — низ холста."""
    c = Canvas(96, 76)
    px, py, floor = 48.0, 12.0, 76.0
    for side in (-1, 1):
        foot = px + side * 36
        length = math.hypot(foot - px, floor - py)
        angle = math.degrees(math.atan2(foot - px, floor - py))
        mid = ((px + foot) / 2.0, (py + floor) / 2.0)
        # Поворот в Blender (вокруг оси Y, к камере) — против часовой на экране: знак обратный.
        box(mid[0] - 5, mid[1] - length / 2, mid[0] + 5, mid[1] + length / 2, 10, WOOD_DARK, bevel=1.5,
            rotate=-angle)
    box(px - 24, 50, px + 24, 57, 8, WOOD, front=2, bevel=1.2, outline=INNER_OUTLINE)
    polygon_prism(arch_points(px, py, 0, 10, 0, 360, steps=20)[1:], 12, IRON, front=4, bevel=1.0)
    stud(px, py, 3.0, RIVET, front=6)
    return c


ASSETS = {
    "crate": lambda: crate(False),
    "crate_heavy": lambda: crate(True),
    "bridge_mid": lambda: bridge("mid"),
    "bridge_end": lambda: bridge("end"),
    "beam_mid": lambda: beam("mid"),
    "beam_end": lambda: beam("end"),
    "door_mid": lambda: door("mid"),
    "door_end": lambda: door("end"),
    **{f"{kind}_{part}_{state}": (lambda kind=kind, part=part, state=state:
                                   plate(part, kind, state == "on"))
       for kind in ("plate", "latch") for part in ("mid", "end") for state in ("off", "on")},
    "finish": lambda: finish(False),
    "finish_complete": lambda: finish(True),
    "flag_off": lambda: flag(False),
    "flag_on": lambda: flag(True),
    "seesaw_base": seesaw_base,
    "spikes_mid": lambda: spikes("mid"),
    "spikes_end": lambda: spikes("end"),
}


def clear_objects() -> None:
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"MESH", "CURVE"}:
            bpy.data.objects.remove(obj, do_unlink=True)


## Запас вокруг холста при рендере (px игры): сглаживание подмешивает прозрачность к краю кадра,
## поэтому рендерим шире и обрезаем запас — края бесшовных кусков остаются плотными.
OVERSCAN = 2.0


def render(scene, camera, canvas: Canvas, path: str) -> None:
    """Камера на холст с запасом OVERSCAN; 1 px игры = 4 px текстуры; запас обрезается."""
    scale = TEX_PER_TILE / TILE_PX
    width, height = canvas.width + 2 * OVERSCAN, canvas.height + 2 * OVERSCAN
    scene.render.resolution_x = round(width * scale)
    scene.render.resolution_y = round(height * scale)
    camera.data.ortho_scale = m(max(width, height))
    camera.location = (m(canvas.width / 2.0), -20.0, -m(canvas.height / 2.0))
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

    full = bpy.data.images.load(path, check_existing=False)
    w, h = full.size
    pixels = np.empty(w * h * 4, dtype=np.float32)
    full.pixels.foreach_get(pixels)
    bpy.data.images.remove(full)
    pad = round(OVERSCAN * scale)
    cropped = pixels.reshape(h, w, 4)[pad:h - pad, pad:w - pad]
    out = bpy.data.images.new(os.path.basename(path), w - 2 * pad, h - 2 * pad, alpha=True)
    out.pixels.foreach_set(np.ascontiguousarray(cropped).ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[argv.index("--out") + 1] if "--out" in argv else "assets/props/v1")
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(ASSETS)
    os.makedirs(out_dir, exist_ok=True)

    scene = toon.reset_scene()
    data = bpy.data.cameras.new("Camera")
    data.type = "ORTHO"
    data.sensor_fit = "AUTO"
    camera = bpy.data.objects.new("Camera", data)
    camera.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.collection.objects.link(camera)
    scene.camera = camera
    for name in only:
        clear_objects()
        canvas = ASSETS[name]()
        render(scene, camera, canvas, os.path.join(out_dir, f"{name}.png"))
        print("PROP", name, canvas.width, "x", canvas.height)
    print("PROPS_DONE", out_dir)


if __name__ == "__main__":
    main()
