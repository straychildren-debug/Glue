"""Typeset exact Russian comic copy into final raster panels.

The generated illustration remains separate (p01_festival.png). Video and game
use the lettered PNG, so balloons and captions are part of the picture.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


HERE = Path(__file__).resolve().parent
FONT_COMIC = Path(r"C:\Windows\Fonts\comicbd.ttf")
FONT_BODY = Path(r"C:\Windows\Fonts\trebucbd.ttf")
NAVY = (26, 29, 51, 255)
PAPER = (255, 249, 229, 255)
YELLOW = (255, 227, 112, 255)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def outlined_text(draw: ImageDraw.ImageDraw, xy, value: str, size: int,
                  fill=PAPER, stroke=NAVY, stroke_width=5,
                  family=FONT_COMIC) -> None:
    draw.text(xy, value, font=font(family, size), fill=fill,
              stroke_width=stroke_width, stroke_fill=stroke,
              anchor="mm", align="center")


def narrator(draw: ImageDraw.ImageDraw, box, lines: list[str]) -> None:
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=13, fill=YELLOW, outline=NAVY, width=6)
    draw.rectangle((x0 + 20, y0 - 7, x0 + 73, y0 + 12), fill=PAPER, outline=NAVY, width=3)
    draw.rectangle((x1 - 80, y1 - 10, x1 - 26, y1 + 8), fill=PAPER, outline=NAVY, width=3)
    f = font(FONT_BODY, 39)
    line_height = 45
    top = (y0 + y1 - len(lines) * line_height) / 2 + 1
    for i, line in enumerate(lines):
        draw.text((x0 + 31, top + i * line_height), line, font=f, fill=NAVY)


def speech(draw: ImageDraw.ImageDraw, box, tail, lines: list[str]) -> None:
    x0, y0, x1, y1 = box
    draw.polygon(tail, fill=PAPER)
    draw.line((tail[0], tail[1], tail[2]), fill=NAVY, width=7, joint="curve")
    draw.ellipse(box, fill=PAPER, outline=NAVY, width=7)
    f = font(FONT_COMIC, 48)
    line_height = 56
    top = (y0 + y1 - len(lines) * line_height) / 2 - 4
    for i, line in enumerate(lines):
        bb = draw.textbbox((0, 0), line, font=f)
        draw.text(((x0 + x1 - (bb[2] - bb[0])) / 2, top + i * line_height),
                  line, font=f, fill=NAVY)


def sfx(base: Image.Image, value: str, center, angle: float) -> None:
    layer = Image.new("RGBA", (650, 180))
    d = ImageDraw.Draw(layer)
    outlined_text(d, (325, 90), value, 88, fill=(255, 242, 98, 255),
                  stroke_width=8)
    layer = layer.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(layer, (int(center[0] - layer.width / 2),
                                 int(center[1] - layer.height / 2)))


def make_p01() -> Image.Image:
    base = Image.open(HERE / "p01_festival.png").convert("RGBA")
    if base.size != (1536, 1024):
        raise ValueError(f"P01 canvas changed: {base.size}")
    d = ImageDraw.Draw(base)
    narrator(d, (35, 30, 765, 202), [
        "Каждый год бобы праздновали",
        "весёлый Праздник бобов.",
    ])
    speech(d, (1160, 69, 1512, 305),
           [(1200, 268), (1113, 388), (1245, 291)],
           ["Да начнётся", "праздник!"])
    sfx(base, "УРА-А!", (255, 435), 8)
    base.save(HERE / "p01_festival_lettered.png")
    return base


def make_proof(panel: Image.Image) -> None:
    canvas = Image.new("RGB", (1920, 1080), (242, 230, 198))
    dot = ImageDraw.Draw(canvas)
    for y in range(15, 1080, 22):
        for x in range(15 + (y // 22 % 2) * 9, 1920, 22):
            dot.ellipse((x, y, x + 2, y + 2), fill=(230, 216, 183))

    panel = panel.resize((1440, 960), Image.Resampling.LANCZOS)
    framed = Image.new("RGBA", (1464, 984), NAVY)
    framed.alpha_composite(panel, (12, 12))
    framed = framed.rotate(0.7, Image.Resampling.BICUBIC, expand=True)
    shadow = Image.new("RGBA", framed.size)
    shadow.putalpha(framed.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    shadow_rgb = Image.new("RGBA", shadow.size, (32, 35, 44, 0))
    shadow_rgb.putalpha(shadow.getchannel("A").point(lambda a: round(a * 0.28)))
    x = (1920 - framed.width) // 2
    y = (1080 - framed.height) // 2
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba.alpha_composite(shadow_rgb, (x + 16, y + 21))
    canvas_rgba.alpha_composite(framed, (x, y))
    canvas_rgba.convert("RGB").save(HERE / "p01_page_proof.jpg", quality=93)


def _fit_font(draw, lines, width, height, preferred=48, family=FONT_COMIC):
    for size in range(preferred, 23, -2):
        f = font(family, size)
        widest = max(draw.textbbox((0, 0), line, font=f)[2] for line in lines)
        if widest < width and len(lines) * size * 1.18 < height:
            return f, size
    return font(family, 24), 24


def caption(base, box, lines):
    d = ImageDraw.Draw(base)
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius=15, fill=YELLOW, outline=NAVY, width=6)
    d.rectangle((x0 + 25, y0 - 7, x0 + 90, y0 + 12), fill=PAPER, outline=NAVY, width=3)
    f, size = _fit_font(d, lines, x1 - x0 - 54, y1 - y0 - 28, 45, FONT_BODY)
    lh = int(size * 1.18)
    top = (y0 + y1 - len(lines) * lh) // 2
    for i, line in enumerate(lines):
        d.text((x0 + 27, top + i * lh), line, font=f, fill=NAVY)


def bubble(base, box, tip, lines, preferred=48):
    d = ImageDraw.Draw(base)
    x0, y0, x1, y1 = box
    mid = max(x0 + 55, min(x1 - 55, tip[0]))
    anchor_y = y1 - 23 if tip[1] > (y0 + y1) // 2 else y0 + 23
    d.polygon([(mid - 35, anchor_y), tip, (mid + 35, anchor_y)],
              fill=PAPER, outline=NAVY, width=5)
    d.ellipse(box, fill=PAPER, outline=NAVY, width=7)
    f, size = _fit_font(d, lines, (x1 - x0) * .74, (y1 - y0) * .68,
                        preferred)
    lh = int(size * 1.15)
    top = (y0 + y1 - len(lines) * lh) // 2
    for i, line in enumerate(lines):
        w = d.textbbox((0, 0), line, font=f)[2]
        d.text(((x0 + x1 - w) / 2, top + i * lh), line, font=f,
               fill=NAVY)


def word(base, value, center, angle=0, size=85):
    layer = Image.new("RGBA", (max(850, len(value) * size), 220))
    d = ImageDraw.Draw(layer)
    outlined_text(d, (layer.width // 2, 110), value, size,
                  fill=(255, 240, 93, 255), stroke_width=9)
    layer = layer.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(layer, (int(center[0] - layer.width / 2),
                                 int(center[1] - layer.height / 2)))


def letter_remaining():
    specs = [
        ("p02_ghosts_watch", [
            (caption, (530, 25, 1500, 204), ["А далеко, в старых руинах,", "на праздник смотрели призраки.", "Их никогда не звали."]),
            (bubble, (5, 35, 500, 253), (290, 322), ["Опять без нас…"]),
            (bubble, (680, 244, 1110, 435), (575, 541), ["Нас все боятся…"]),
        ]),
        ("p03_ghost_plan", [
            (bubble, (616, 35, 1230, 369), (826, 507), ["Не зовут —", "сами придём!", "И заберём", "праздник себе!"]),
            (bubble, (22, 260, 404, 460), (338, 578), ["У-у-у!"]),
        ]),
        ("p04_raid", [
            (word, "ФЬЮ-У-У!", (428, 205), 9, 88),
            (bubble, (20, 478, 540, 724), (380, 816), ["Призраки!!"]),
        ]),
        ("p05_grab", [
            (bubble, (18, 26, 593, 282), (455, 408), ["Отпустите!", "Я король!"]),
            (bubble, (655, 35, 1232, 355), (890, 462), ["Вот и устроишь", "праздник —", "только для нас!"]),
        ]),
        ("p06_carried", [
            (caption, (23, 24, 1001, 226), ["И унесли его далеко-далеко —", "в свой замок за облаками."]),
            (word, "ДЗЫНЬ!", (758, 971), -8, 87),
        ]),
        ("p07_crown", [
            (caption, (34, 30, 1220, 224), ["Наутро на опустевшей площади", "осталась только корона."]),
        ]),
        ("p08_found", [
            (bubble, (20, 35, 660, 269), (426, 443), ["Его унесли", "призраки…"]),
            (bubble, (840, 38, 1510, 285), (1269, 503), ["Это же корона", "короля!"]),
        ]),
        ("p09_decision", [
            (bubble, (38, 28, 982, 304), (550, 530), ["Мы найдём короля", "и вернём его домой!"]),
            (bubble, (13, 378, 478, 622), (195, 753), ["Но путь", "далёкий…"]),
            (bubble, (553, 423, 1000, 658), (693, 783), ["Вместе —", "справимся!"]),
        ]),
        ("p10_map", [
            (bubble, (45, 5, 1492, 266), (793, 460), ["Замок призраков — за облаками,", "у Небесной кузницы.", "Путь лежит через Забытые мосты…"], 49),
        ]),
        ("p11_road", [
            (bubble, (970, 35, 1600, 285), (1070, 331), ["Вперёд!"], 68),
        ]),
        ("p12_bridge", [
            (caption, (40, 32, 1108, 183), ["Чтобы пройти этот путь,", "им придётся держаться вместе."]),
            (word, "Держись!", (770, 345), 0, 148),
        ]),
    ]
    for stem, ops in specs:
        base = Image.open(HERE / f"{stem}.png").convert("RGBA")
        for fn, *args in ops:
            fn(base, *args)
        base.save(HERE / f"{stem}_lettered.png")


if __name__ == "__main__":
    make_proof(make_p01())
    letter_remaining()
