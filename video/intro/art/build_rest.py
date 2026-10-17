"""Prepare the approved story assets as compact, transparent video layers."""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFilter


ART = Path(__file__).resolve().parent
OUT = ART / "layers"
OUT.mkdir(exist_ok=True)


def trim(image: Image.Image, pad: int = 6) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    # Generated sheets sometimes include an almost invisible colored haze.
    alpha = alpha.point(lambda a: 0 if a < 24 else a)
    image.putalpha(alpha)
    box = alpha.getbbox()
    if box is None:
        raise ValueError("Empty sprite cell")
    return image.crop((max(0, box[0] - pad), max(0, box[1] - pad),
                       min(image.width, box[2] + pad), min(image.height, box[3] + pad)))


def cell(sheet: str, name: str, box: tuple[int, int, int, int], height: int | None = None) -> None:
    image = trim(Image.open(ART / sheet).crop(box))
    if height:
        image = image.resize((round(image.width * height / image.height), height), Image.Resampling.LANCZOS)
    image.save(OUT / f"{name}.png", optimize=True)


def strip(sheet: str, name: str, width: int) -> None:
    """Полоса травы: ширина кадра с запасом, пропорции сохраняются."""
    image = trim(Image.open(ART / sheet))
    image.resize((width, round(image.height * width / image.width)), Image.Resampling.LANCZOS).save(OUT / f"{name}.png", optimize=True)


def component_sheet(sheet: str, names: tuple[str, ...], height: int, rows: int = 1) -> None:
    """Separate connected painted figures even when their x-ranges overlap."""
    source = Image.open(ART / sheet).convert("RGBA")
    pixels = np.asarray(source).copy()
    labels_count, labels, stats, _ = cv2.connectedComponentsWithStats(
        (pixels[:, :, 3] > 20).astype(np.uint8), 8
    )
    found = []
    for label in range(1, labels_count):
        x, y, w, h, area = stats[label]
        if area > 2000:
            found.append((x, y, w, h, label))
    if len(found) != len(names):
        raise ValueError(f"{sheet}: expected {len(names)} sprites, got {len(found)}")
    if rows == 2:
        found.sort(key=lambda item: (item[1] >= source.height // 2, item[0]))
    else:
        found.sort(key=lambda item: item[0])
    for name, (x, y, w, h, label) in zip(names, found):
        pad = 6
        x0, y0 = max(0, x - pad), max(0, y - pad)
        x1, y1 = min(source.width, x + w + pad), min(source.height, y + h + pad)
        sprite = pixels[y0:y1, x0:x1].copy()
        sprite[:, :, 3][labels[y0:y1, x0:x1] != label] = 0
        image = Image.fromarray(sprite, "RGBA")
        image.resize((round(image.width * height / image.height), height),
                     Image.Resampling.LANCZOS).save(OUT / f"{name}.png", optimize=True)


# The new grass goes in front of the feet. The foreground source PNGs remain untouched.
strip("a5_grass_front.png", "grass_front_day", 2200)
strip("d5_grass_front.png", "grass_front_dawn", 2200)
component_sheet("a6_grass_tufts.png", tuple(f"grass_tuft_{i+1}" for i in range(6)), 120)

# King, ghosts, crown and crowd: full poses are used where a puppet would look stiff.
component_sheet("k3_king_poses.png", ("king_wave", "king_frightened", "king_carried"), 520)
component_sheet("g1_ghosts.png", ("ghost_fast", "ghost_swoop", "ghost_laugh", "ghost_lift", "ghost_peek"), 300)
component_sheet("x1_crown.png", ("crown_upright", "crown_tilted"), 240)
component_sheet("b3_lanterns.png", ("lantern_lit", "lantern_unlit"), 130)
component_sheet("b4_crowd.png", tuple(f"town_dance_{i+1}" for i in range(6)) +
                tuple(f"town_run_{i+1}" for i in range(6)), 200, rows=2)

# Keep the individual king puppet parts available for later fine motion.
for name, box in {
    "king_body": (0, 0, 535, 700),
    "king_crown_part": (535, 0, 1000, 540),
    "king_cape": (1000, 0, 1536, 690),
    "king_mustache": (0, 680, 470, 1024),
    "king_left_arm": (450, 650, 745, 1024),
    "king_right_arm": (745, 650, 1000, 1024),
    "king_left_leg": (1000, 680, 1265, 1024),
    "king_right_leg": (1265, 680, 1536, 1024),
}.items():
    cell("k1_king_parts.png", name, box)

# All four game heroes share one silhouette. Recolor only the red body pixels;
# highlights and dark-navy contours are kept from the approved red art.
def recolor(image: Image.Image, hue: int) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    hsv = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2HSV)
    mask = (((hsv[:, :, 0] < 15) | (hsv[:, :, 0] > 170)) &
            (hsv[:, :, 1] > 70) & (hsv[:, :, 2] > 80) & (rgba[:, :, 3] > 16))
    hsv[:, :, 0][mask] = hue
    rgba[:, :, :3] = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    return Image.fromarray(rgba, "RGBA")


for pose in ("stand", "run", "jump", "frightened"):
    source = Image.open(OUT / f"hero_{pose}.png").convert("RGBA")
    for color, hue in (("blue", 105), ("green", 60), ("yellow", 26)):
        image = recolor(source, hue)
        if color == "yellow":
            image = image.resize((round(image.width * 0.82), round(image.height * 0.82)), Image.Resampling.LANCZOS)
        image.save(OUT / f"hero_{color}_{pose}.png", optimize=True)

# Куклы братьев и сестры: те же детали, перекрашенные (масштаб сестры задаёт сцена).
for part in ("body", "left_arm", "right_arm", "left_leg", "right_leg"):
    source = Image.open(OUT / f"hero_{part}.png").convert("RGBA")
    for color, hue in (("blue", 105), ("green", 60), ("yellow", 26)):
        recolor(source, hue).save(OUT / f"hero_{color}_{part}.png", optimize=True)

bow = trim(Image.open(ART / "slices" / "hero_bow.png"))
bow.resize((56, round(bow.height * 56 / bow.width)), Image.Resampling.LANCZOS).save(OUT / "hero_yellow_bow.png", optimize=True)

# A few standalone background plates for consistent runtime loading.
for source, name in (("b1_square_day.png", "square_day.jpg"),
                     ("b1n_square_night.png", "square_night.jpg"),
                     ("c1_cobbles_close.png", "cobbles_night.jpg"),
                     ("d1_dawn_sky.png", "dawn_sky.jpg")):
    Image.open(ART / source).convert("RGB").save(OUT / name, quality=92, subsampling=0)
for source, name in (("b2_bunting.png", "bunting.png"),
                     ("d2_far_bridges.png", "dawn_bridges.png"),
                     ("d3_road.png", "dawn_road.png"),
                     ("d4_foreground.png", "dawn_foreground.png")):
    image = Image.open(ART / source).convert("RGBA")
    image.putalpha(image.getchannel("A").filter(ImageFilter.MinFilter(3)))
    image.save(OUT / name, optimize=True)

print(f"Prepared {len(list(OUT.iterdir()))} video layers in {OUT}")
