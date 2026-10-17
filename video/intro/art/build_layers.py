"""Готовит слои и куклу героя для композиции HyperFrames (video/intro/art/layers/).

Запуск из video/intro/art: python build_layers.py — после prepare_scene1.py (он режет листы в slices/).
Печатает CSS-координаты деталей куклы: точка (0, 0) контейнера — середина ступней.
"""

from pathlib import Path

from PIL import Image, ImageFilter

ART = Path(__file__).resolve().parent
SLICES = ART / "slices"
OUT = ART / "layers"
OUT.mkdir(exist_ok=True)


def tighten(image: Image.Image) -> Image.Image:
    """Срезает светлую кайму по краю прозрачности (1 px)."""
    alpha = image.getchannel("A").filter(ImageFilter.MinFilter(3))
    image.putalpha(alpha)
    return image


def fill_holes(image: Image.Image) -> Image.Image:
    """Белки глаз: прозрачные области, не связанные с краем листа, заливает белым."""
    w, h = image.size
    alpha = image.getchannel("A").load()
    outside = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if outside[y][x] or alpha[x, y] > 128:
            continue
        outside[y][x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx]:
                stack.append((nx, ny))
    pixels = image.load()
    for y in range(h):
        for x in range(w):
            if not outside[y][x] and alpha[x, y] <= 128:
                pixels[x, y] = (255, 255, 255, 255)
    return image


# Пейзаж кадра 1.
Image.open(ART / "a1_sky.png").convert("RGB").resize((1920, 2880), Image.Resampling.LANCZOS).save(OUT / "sky.jpg", quality=92)
for src, dst in (("a2_mountains.png", "mountains.png"), ("a3_kingdom.png", "kingdom.png")):
    tighten(Image.open(ART / src).convert("RGBA")).save(OUT / dst)
fg = tighten(Image.open(ART / "a4_foreground.png").convert("RGBA"))
branch = fg.crop((0, 0, 820, 320))
branch.crop(branch.getchannel("A").getbbox()).save(OUT / "fg_branch.png")
fg.crop((0, 300, 2172, 724)).save(OUT / "fg_grass.png")

# Кукла героя. Масштабы деталей подобраны так, чтобы кукла совпала с цельной позой hero_stand;
# K — общий масштаб: рост героя в кадре ≈ 300 px.
K = 0.64
PARTS = {  # имя: (масштаб, x, y в координатах сборки, слой)
    "hero_right_arm": (0.55, 383, 350),
    "hero_left_leg": (0.42, 260, 475),
    "hero_right_leg": (0.42, 350, 475),
    "hero_body": (0.60, 200, 150),
    "hero_left_arm": (0.55, 160, 340),
}
FOOT_X, FOOT_Y = 346, 619
css = []


def emit(name: str, image: Image.Image, x: float, y: float) -> None:
    image.save(OUT / f"{name}.png")
    css.append(f"#hero .{name.replace('_', '-')} {{ left: {round((x - FOOT_X) * K)}px; top: {round((y - FOOT_Y) * K)}px; }}")


def scaled(name: str, scale: float) -> Image.Image:
    image = Image.open(SLICES / f"{name}.png").convert("RGBA")
    if name.startswith("eyes"):
        image = fill_holes(image)
    size = (round(image.width * scale * K), round(image.height * scale * K))
    return image.resize(size, Image.Resampling.LANCZOS)


for name, (scale, x, y) in PARTS.items():
    emit(name, scaled(name, scale), x, y)

# Лицо: варианты центрируются на месте открытых глаз / улыбки.
FACE = 0.42
EYES_C, MOUTH_C, BROWS_C = (398, 303), (400, 366), (398, 252)
for group, centre in (("eyes", EYES_C), ("mouth", MOUTH_C), ("brows", BROWS_C)):
    for path in sorted(SLICES.glob(f"{group}_*.png")):
        image = scaled(path.stem, FACE * (0.8 if group == "brows" else 1.0))
        w, h = image.width / K, image.height / K
        emit(path.stem, image, centre[0] - w / 2, centre[1] - h / 2)

# Цельные позы — тем же ростом, что кукла (hero_stand 546 px ≈ 300 px в кадре).
POSE = 300 / 546
for name in ("hero_jump", "hero_run", "hero_frightened", "hero_stand"):
    image = Image.open(SLICES / f"{name}.png").convert("RGBA")
    image.resize((round(image.width * POSE), round(image.height * POSE)), Image.Resampling.LANCZOS).save(OUT / f"{name}.png")
    css.append(f"/* {name}: {round(image.width * POSE)}x{round(image.height * POSE)} */")

print("\n".join(css))
