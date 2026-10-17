"""Нарезка спрайтов новых механизмов мира 2 (задание docs/22, рисовал Codex) для игры.

Исходники — assets/props/v2/source/n0*.png: на одной картинке несколько кусков рядом (состояния или
детали). Куски разделяются пустыми (прозрачными) столбцами; каждый обрезается по непрозрачному
и уменьшается до 4 px текстуры на 1 px игры (как весь набор v2, см. src/game/art.gd).
Запуск: python tools/cut_new_props.py"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/props/v2/source'
DST = ROOT / 'assets/props/v2'
T = 64 * 4  # тайл в пикселях текстуры

# исходник: [(имя куска, ширина в тайлах)], слева направо
PIECES = {
    'n01_trapeze.png': [('w2_trapeze', 4.0)],
    'n02_wheel.png': [('w2_wheel', 3.0), ('w2_wheel_stand', 2.0)],
    'n03_lantern.png': [('w2_lantern', 0.5), ('w2_lantern_off', 0.5)],
    'n04_turn_beam.png': [('w2_turn_beam', 6.0), ('w2_turn_hub', 0.8)],
    'n05_pallet.png': [('w2_pallet', 3.0), ('w2_pallet_open', 3.0)],
    'n06_fist.png': [('w2_fist', 2.0), ('w2_fist_hot', 2.0)],
    'n07_machine_face.png': [('w2_face', 9.0), ('w2_face_cracked', 9.0), ('w2_face_broken', 9.0)],
}
# Состояния одной вещи — общей рамкой (одна высота и низ): при смене состояния картинка не прыгает.
SAME_FRAME = {'n06_fist.png', 'n07_machine_face.png'}


def segments(im):
    """Горизонтальные отрезки непрозрачных столбцов (куски рядом)."""
    alpha = im.getchannel('A').point(lambda v: 255 if v > 24 else 0)
    w, h = im.size
    cols = [alpha.crop((x, 0, x + 1, h)).getbbox() is not None for x in range(w)]
    result, start = [], None
    for x, filled in enumerate(cols + [False]):
        if filled and start is None:
            start = x
        elif not filled and start is not None:
            if x - start > 20:
                result.append((start, x))
            start = None
    return result


for name, pieces in PIECES.items():
    im = Image.open(SRC / name).convert('RGBA')
    segs = segments(im)
    # мелкие соседние отрезки (цепи, блики) — к ближайшему крупному: склеить, пока их больше кусков
    while len(segs) > len(pieces):
        gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
        i = gaps.index(min(gaps))
        segs[i:i + 2] = [(segs[i][0], segs[i + 1][1])]
    boxes = [im.crop((x0, 0, x1, im.height)).getchannel('A').point(lambda v: 255 if v > 24 else 0).getbbox()
             for x0, x1 in segs]
    top, bottom = min(b[1] for b in boxes), max(b[3] for b in boxes)
    for (sprite, tiles), (x0, x1), box in zip(pieces, segs, boxes):
        piece = im.crop((x0, 0, x1, im.height))
        if name in SAME_FRAME:
            # общая рамка: по ширине — самый широкий кусок вокруг центра, по высоте — общая
            # по ширине — по корпусу ниже середины (дым сверху не сдвигает рамку)
            body = [im.crop((x0, (top + bottom) // 2, x1, bottom)).getchannel('A').point(
                lambda v: 255 if v > 24 else 0).getbbox() for x0, x1 in segs]
            half = max(b[2] - b[0] for b in body) / 2 * 1.04
            mine = body[segs.index((x0, x1))]
            cx = (mine[0] + mine[2]) / 2
            piece = piece.crop((round(cx - half), top, round(cx + half), bottom))
        else:
            piece = piece.crop(box)
        width = round(tiles * T)
        height = round(piece.height * width / piece.width)
        piece.resize((width, height), Image.LANCZOS).save(DST / f'{sprite}.png')
        print(f'{sprite}: {width}x{height}')
