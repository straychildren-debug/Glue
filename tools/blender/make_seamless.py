"""Бесшовная по горизонтали копия слоя задника (исходник не меняется).

Запуск:
    blender -b --factory-startup -P tools/blender/make_seamless.py -- <вход.png> <выход.png> [перекрытие_px]

Правый край картинки на полосе шириной «перекрытие» плавно перетекает в левый: результат
уже исходника на эту полосу, и его последний столбец продолжается первым. Для слоёв
с прозрачностью смешивание идёт в премультиплицированном цвете — без тёмных и светлых каёмок.
Blender здесь — просто Python с numpy и чтением/записью PNG.
"""

import os
import sys

import bpy
import numpy as np


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    src, dst = os.path.abspath(args[0]), os.path.abspath(args[1])
    overlap = int(args[2]) if len(args) > 2 else 256

    image = bpy.data.images.load(src)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)

    # Премультиплицированный цвет: смешивание прозрачных и непрозрачных мест без ореолов.
    premul = pixels.copy()
    premul[..., :3] *= premul[..., 3:4]

    out_width = width - overlap
    result = premul[:, :out_width].copy()
    t = (np.arange(overlap, dtype=np.float32) / overlap)[None, :, None]
    # Начало результата — смесь «хвоста» исходника (справа) и его начала.
    result[:, :overlap] = premul[:, out_width:] * (1.0 - t) + premul[:, :overlap] * t

    alpha = result[..., 3:4]
    result[..., :3] = np.where(alpha > 1e-4, result[..., :3] / np.maximum(alpha, 1e-4), 0.0)

    out = bpy.data.images.new("seamless", out_width, height, alpha=True)
    out.pixels.foreach_set(result.ravel())
    out.filepath_raw = dst
    out.file_format = "PNG"
    out.save()
    print("SEAMLESS", dst, out_width, "x", height)


if __name__ == "__main__":
    main()
