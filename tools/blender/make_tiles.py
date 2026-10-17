"""Игровые копии текстур платформ (исходники в assets/tiles/world_XX/source не меняются).

Запуск:
    blender -b --factory-startup -P tools/blender/make_tiles.py [-- имя имя ...]

Для каждой текстуры: вырезать полезную полосу (у мха и края холст шире рисунка), свести шов
по нужным осям, уменьшить до размера «вдвое крупнее, чем на экране при масштабе камеры 1».
Сведение шва — как в make_seamless.py: край картинки на полосе перекрытия плавно перетекает
в противоположный, в премультиплицированном цвете (без каёмок у прозрачных мест).
Blender здесь — просто Python с numpy и чтением/записью PNG.
"""

import os
import sys

import bpy
import numpy as np

# Папка мира — по префиксу имени: w01_… → assets/tiles/world_01/{source,game}.
def world_dir(name: str, kind: str) -> str:
    return "assets/tiles/world_%s/%s" % (name[1:3], kind)


# имя → (файл, обрезка (x, y, ширина, высота) или None, оси шва, перекрытие px, размер результата
# [, поправка {"saturation": доля, "contrast": доля, "flip_x": True}]).
# Кладка и скала уже почти бесшовные (перепад на стыке ≈ 5–7 из 255): смешение рисовало бы
# полупрозрачные двойные швы между камнями — их не сводим. У мха перекрытие узкое по той же причине.
# Заливки, нарисованные рядами (виадук, каменоломня), режем по середине горизонтального шва
# сверху и снизу: при повторе половинки сложатся в обычный шов.
# Размер результата — вдвое больше мирового периода повтора (Ground.TEXELS_PER_PX).
TILES = {
    # Кладка: период 256 px мира (4 тайла) — камни примерно по полтайла.
    "w01_stone_fill": ("w01_stone_fill.png", None, "", 0, (512, 512)),
    # Скала: камни крупнее кладки, период 384 px.
    "w01_cliff_fill": ("w01_cliff_fill.png", None, "", 0, (768, 768)),
    # Мох: строки 225–480 — травинки, подушка (≈ 270–340) и свисающие капли. Масштаб 0,2:
    # полоса 51 px мира, период 374 px.
    "w01_moss_top": ("w01_moss_top.png", (0, 225, 2172, 255), "x", 80, (748, 102)),
    # Край: столбцы 60–300 — каменная колонна (≈ 85–245) с плющом. Масштаб 0,15:
    # полоса 36 px мира, период 229 px.
    "w01_stone_side": ("w01_stone_side.png", (60, 0, 240, 1774), "y", 250, (72, 457)),
    # Заливки зон 11–20 (задание 09). Масштаб, как у кладки: 1254 px исходника → 512.
    # Река (T8) и святилище (T9) почти бесшовные — как кладка.
    "w01_river_fill": ("w01_river_fill.png", None, "", 0, (512, 512)),
    "w01_shrine_fill": ("w01_shrine_fill.png", None, "", 0, (512, 512)),
    # Виадук (T7): ряды тёсаных блоков, шов по вертикали не сведён (перепад 21) — режем
    # по горизонтальным швам на строках 5 и 1251; он ярче остальных — приглушаем.
    "w01_viaduct_fill": ("w01_viaduct_fill.png", (0, 5, 1254, 1246), "", 0, (512, 509),
                         {"saturation": 0.7, "contrast": 0.85}),
    # Каменоломня (T5): слои породы, режем по линиям слоёв на строках 225 и 1175.
    "w01_canyon_fill": ("w01_canyon_fill.png", (0, 225, 1254, 950), "", 0, (512, 388)),
    # Глубина каньона (T6): глыбы крупные, как у скалы — период 384 px.
    "w01_canyon_deep": ("w01_canyon_deep.png", None, "", 0, (768, 768)),
    # Мир 2 «Мастерские» (задание 11, C2.1–C2.4). Заливка — кирпич с камнем, как кладка;
    # глубина — крупный серый камень, как скала.
    "w02_fill": ("w02_fill.png", None, "", 0, (512, 512)),
    "w02_deep": ("w02_deep.png", None, "", 0, (768, 768)),
    # Верх — каменный бордюр: строки 195–330 (над бордюром — пыль и травинки, ходят по строке
    # ≈ 215). Масштаб 0,25: полоса 34 px мира, период 523 px.
    "w02_top": ("w02_top.png", (0, 195, 2172, 135), "x", 80, (1046, 68)),
    # Бок — колонна кирпича, внешняя грань справа (столбец ≈ 333): отражаем, чтобы грань была
    # слева, как у мира 1. Масштаб 0,1: полоса 36 px мира, период 217 px.
    "w02_side": ("w02_side.png", (0, 0, 360, 2172), "y", 250, (72, 384), {"flip_x": True}),
}


def load(path: str) -> np.ndarray:
    image = bpy.data.images.load(os.path.abspath(path))
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    # Строки Blender идут снизу вверх — переворачиваем, чтобы обрезка была в координатах файла.
    return pixels.reshape(height, width, 4)[::-1].copy()


def seamless(premul: np.ndarray, axis: int, overlap: int) -> np.ndarray:
    """Конец картинки вдоль оси плавно перетекает в её начало; результат короче на overlap."""
    moved = np.moveaxis(premul, axis, 0)
    length = moved.shape[0] - overlap
    result = moved[:length].copy()
    t = (np.arange(overlap, dtype=np.float32) / overlap).reshape(-1, *([1] * (moved.ndim - 1)))
    result[:overlap] = moved[length:] * (1.0 - t) + moved[:overlap] * t
    return np.moveaxis(result, 0, axis)


def save(pixels: np.ndarray, size: tuple, path: str) -> None:
    height, width = pixels.shape[:2]
    image = bpy.data.images.new("tile", width, height, alpha=True)
    image.pixels.foreach_set(pixels[::-1].ravel())
    image.scale(size[0], size[1])
    image.filepath_raw = os.path.abspath(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def adjust(pixels: np.ndarray, saturation: float = 1.0, contrast: float = 1.0, flip_x: bool = False) -> np.ndarray:
    """Приглушить цвет: насыщенность к серому той же яркости, контраст к средней яркости."""
    rgb = pixels[..., :3]
    gray = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    rgb = gray[..., None] + (rgb - gray[..., None]) * saturation
    mean = float(gray.mean())
    pixels[..., :3] = np.clip(mean + (rgb - mean) * contrast, 0.0, 1.0)
    return pixels[:, ::-1].copy() if flip_x else pixels


def main() -> None:
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, (file, crop, axes, overlap, size, *rest) in TILES.items():
        if only and name not in only:
            continue
        out = world_dir(name, "game")
        os.makedirs(out, exist_ok=True)
        pixels = load(os.path.join(world_dir(name, "source"), file))
        if crop:
            x, y, w, h = crop
            pixels = pixels[y:y + h, x:x + w]
        if rest:
            pixels = adjust(pixels, **rest[0])
        premul = pixels.copy()
        premul[..., :3] *= premul[..., 3:4]
        if "x" in axes:
            premul = seamless(premul, 1, overlap)
        if "y" in axes:
            premul = seamless(premul, 0, overlap)
        alpha = premul[..., 3:4]
        premul[..., :3] = np.where(alpha > 1e-4, premul[..., :3] / np.maximum(alpha, 1e-4), 0.0)
        save(premul, size, os.path.join(out, name + ".png"))
        print("TILE", name, premul.shape[1], "x", premul.shape[0], "->", size)


if __name__ == "__main__":
    main()
