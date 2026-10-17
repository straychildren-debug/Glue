"""Игровые текстуры декораций из картинок генератора: растительность мира 01 (задание docs/09,
D1–D6) и декорации миров 2–6 (задание docs/11, часть D).

Запуск (нужен Python 3 с Pillow):
    python tools/make_decals.py

Исходники — assets/decals/world_XX/source/ (не меняются), результат — assets/decals/world_XX/game/.
Каждая картинка обрезается по непрозрачной части и уменьшается так, чтобы при масштабе камеры 1
на 1 px экрана приходилось 2 px текстуры (как у платформ, Ground.TEXELS_PER_PX). Размер на экране
задаёт таблица SIZES (ширина в px игры); src/level/decals.gd берёт размер из текстуры.
Уменьшение — в премультиплицированном цвете (без тёмной каймы по краю прозрачности).
"""

import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
WORLDS = ["01", "02"]
TEXELS_PER_PX = 2

# Ширина на экране, px игры (тайл — 64 px).
SIZES = {
    "grass": 128,         # пучок травы — два тайла
    "bush": 92,
    "flowers": 64,
    "ivy_hang": 38,       # плеть плюща ≈ 180 px длиной
    "roots": 176,         # корни под нависающим краем
    "front_branch": 420,  # ветка переднего плана (рамка кадра)
    # Мир 2 «Мастерские»
    "soot_moss": 104,     # мох с сажей на кромке
    "lantern": 52,        # фонарь на кронштейне у стены
    "banner": 52,         # полотнище под нависающим краем
    "pipes": 44,          # вертикальные трубы на стене
    "steam": 84,          # клуб пара (поднимается и тает)
}


def main() -> None:
    for world in WORLDS:
        src = os.path.join(ROOT, "assets", "decals", "world_" + world, "source")
        out = os.path.join(ROOT, "assets", "decals", "world_" + world, "game")
        if os.path.isdir(src):
            convert(world, src, out)


def convert(world: str, src: str, out: str) -> None:
    os.makedirs(out, exist_ok=True)
    for file in sorted(os.listdir(src)):
        if not file.endswith(".png"):
            continue
        name = file[len("w01_decal_"):-len(".png")]
        kind = name[:-2] if name[-2:] in ("_2", "_3") else name
        if kind not in SIZES:
            print("пропуск", file)
            continue
        image = Image.open(os.path.join(src, file)).convert("RGBA")
        alpha = image.getchannel("A").point(lambda a: 255 if a > 8 else 0)
        box = alpha.getbbox()
        cut = image.crop(box).convert("RGBa")
        width = SIZES[kind] * TEXELS_PER_PX
        height = max(1, round(cut.height * width / cut.width))
        cut = cut.resize((width, height), Image.LANCZOS).convert("RGBA")
        cut.save(os.path.join(out, "w%s_%s.png" % (world, name)))
        print("DECAL", name, (width, height))


if __name__ == "__main__":
    main()
