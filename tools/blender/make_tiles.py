"""Игровые копии текстур платформ мира 01 (исходники в assets/tiles/world_01/source не меняются).

Запуск:
    blender -b --factory-startup -P tools/blender/make_tiles.py

Для каждой текстуры: вырезать полезную полосу (у мха и края холст шире рисунка), свести шов
по нужным осям, уменьшить до размера «вдвое крупнее, чем на экране при масштабе камеры 1».
Сведение шва — как в make_seamless.py: край картинки на полосе перекрытия плавно перетекает
в противоположный, в премультиплицированном цвете (без каёмок у прозрачных мест).
Blender здесь — просто Python с numpy и чтением/записью PNG.
"""

import os

import bpy
import numpy as np

SRC = "assets/tiles/world_01/source"
OUT = "assets/tiles/world_01/game"

# имя → (файл, обрезка (x, y, ширина, высота) или None, оси шва, перекрытие px, размер результата).
# Кладка и скала уже почти бесшовные (перепад на стыке ≈ 5–7 из 255): смешение рисовало бы
# полупрозрачные двойные швы между камнями — их не сводим. У мха перекрытие узкое по той же причине.
# Размер результата — вдвое больше мирового периода повтора: см. Art.GROUND в src/game/art.gd.
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


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, (file, crop, axes, overlap, size) in TILES.items():
        pixels = load(os.path.join(SRC, file))
        if crop:
            x, y, w, h = crop
            pixels = pixels[y:y + h, x:x + w]
        premul = pixels.copy()
        premul[..., :3] *= premul[..., 3:4]
        if "x" in axes:
            premul = seamless(premul, 1, overlap)
        if "y" in axes:
            premul = seamless(premul, 0, overlap)
        alpha = premul[..., 3:4]
        premul[..., :3] = np.where(alpha > 1e-4, premul[..., :3] / np.maximum(alpha, 1e-4), 0.0)
        save(premul, size, os.path.join(OUT, name + ".png"))
        print("TILE", name, premul.shape[1], "x", premul.shape[0], "->", size)


if __name__ == "__main__":
    main()
