"""Extract the approved puppet sheets and build the first-scene art proof."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ART = Path(__file__).resolve().parent
SLICES = ART / "slices"
SLICES.mkdir(exist_ok=True)


def save_region(sheet: str, name: str, region: tuple[int, int, int, int]) -> None:
    image = Image.open(ART / sheet).convert("RGBA").crop(region)
    alpha = image.getchannel("A").point(lambda value: 255 if value > 20 else 0)
    box = alpha.getbbox()
    if box is None:
        raise ValueError(f"Empty region: {sheet} / {name}")
    margin = 12
    box = (
        max(0, box[0] - margin),
        max(0, box[1] - margin),
        min(image.width, box[2] + margin),
        min(image.height, box[3] + margin),
    )
    image.crop(box).save(SLICES / f"{name}.png")


for name, area in {
    "hero_body": (0, 0, 530, 724),
    "hero_left_arm": (530, 0, 825, 724),
    "hero_right_arm": (825, 0, 1160, 724),
    "hero_left_leg": (1160, 0, 1470, 724),
    "hero_right_leg": (1470, 0, 1810, 724),
    "hero_bow": (1810, 0, 2172, 724),
}.items():
    save_region("h1_hero_parts.png", name, area)

for name, area in {
    "hero_stand": (0, 0, 530, 724),
    "hero_run": (530, 0, 1110, 724),
    "hero_jump": (1110, 0, 1640, 724),
    "hero_frightened": (1640, 0, 2172, 724),
}.items():
    save_region("h3_hero_poses.png", name, area)

for name, area in {
    "eyes_open": (45, 180, 290, 380),
    "eyes_blink": (325, 180, 610, 380),
    "eyes_frightened": (635, 180, 900, 380),
    "eyes_side": (935, 180, 1190, 380),
    "eyes_determined": (1210, 180, 1510, 380),
    "brows_calm": (95, 470, 500, 630),
    "brows_worried": (580, 470, 950, 630),
    "brows_determined": (1050, 470, 1440, 630),
    "mouth_smile": (160, 740, 330, 900),
    "mouth_surprised": (520, 740, 655, 900),
    "mouth_shout": (860, 740, 1020, 900),
    "mouth_frown": (1220, 740, 1410, 900),
}.items():
    save_region("h2_hero_face.png", name, area)


canvas = Image.new("RGBA", (1920, 1080))
sky = Image.open(ART / "a1_sky.png").convert("RGBA")
sky = sky.resize((1920, 2880), Image.Resampling.LANCZOS)
canvas.alpha_composite(sky.crop((0, 680, 1920, 1760)))


def place(filename: str, x: int, y: int, width: int | None = None) -> None:
    layer = Image.open(ART / filename).convert("RGBA")
    if width is not None:
        height = round(layer.height * width / layer.width)
        layer = layer.resize((width, height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(layer, (x, y))


place("a2_mountains.png", -126, 340)
place("a3_kingdom.png", -126, 375)
foreground = Image.open(ART / "a4_foreground.png").convert("RGBA")
branch = foreground.crop((0, 0, 900, 350))
canvas.alpha_composite(branch, (0, 0))
grass = foreground.crop((0, 290, 2172, 724))
canvas.alpha_composite(grass, (-126, 650))
shadow = Image.new("RGBA", canvas.size)
ImageDraw.Draw(shadow).ellipse((425, 970, 625, 1015), fill=(20, 34, 42, 95))
canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
hero = Image.open(SLICES / "hero_stand.png").convert("RGBA")
hero = hero.resize((round(hero.width * 0.55), round(hero.height * 0.55)), Image.Resampling.LANCZOS)
canvas.alpha_composite(hero, (400, 1080 - hero.height - 80))
canvas.convert("RGB").save(ART / "scene1_preview.jpg", quality=94, subsampling=0)
