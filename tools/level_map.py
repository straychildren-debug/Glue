"""Схема уровня из сцены .tscn — для обзора и проектирования: блоки, механизмы с подписями,
чекпоинты, финиш. Масштаб — 16 px на тайл.

Запуск: python tools/level_map.py levels/w02_l13_lock.tscn [ещё сцены...] [--out папка]
По умолчанию картинки — в папку tmp/maps рядом с проектом.
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

T = 64
S = 16  # px на тайл
COLORS = {
    'plate': (240, 200, 60), 'door': (150, 110, 70), 'crate': (190, 130, 70), 'lever': (230, 120, 220),
    'conveyor': (90, 90, 110), 'spring': (80, 200, 120), 'brittle': (200, 170, 120), 'spinner': (120, 160, 230),
    'bellows': (160, 220, 255), 'crane': (120, 120, 120), 'wire': (230, 150, 60), 'spark': (255, 220, 60),
    'keg': (200, 80, 40), 'cracked': (170, 120, 110), 'beetle': (180, 100, 40), 'spikes': (220, 40, 40),
    'saw': (230, 60, 60), 'press': (110, 110, 140), 'hook': (60, 60, 60), 'ghost': (230, 230, 255),
    'crusher': (130, 60, 60), 'finish': (40, 200, 90), 'hint': (200, 200, 200),
}


def parse(path):
    text = Path(path).read_text(encoding='utf-8')
    ids = dict(re.findall(r'\[ext_resource [^\]]*path="res://src/(?:mechanisms|level)/(\w+)\.gd" id="(\w+)"', text))
    ids = {v: k for k, v in ids.items()}
    bounds = re.search(r'bounds_tiles = Rect2\(([^)]*)\)', text)
    bx, by, bw, bh = (float(v) for v in bounds.group(1).split(','))
    blocks = [tuple(float(v) for v in m.split(',')) for m in re.findall(r'Rect2\(([^)]*)\)', re.search(r'blocks = Array\[Rect2\]\(\[(.*?)\]\)', text).group(1))]
    cps = [tuple(float(v) for v in m.split(',')) for m in re.findall(r'Vector2\(([^)]*)\)', re.search(r'checkpoints = Array\[Vector2\]\(\[(.*?)\]\)', text).group(1))]
    nodes = []
    for chunk in text.split('\n[node ')[1:]:
        head, _, body = chunk.partition('\n')
        hm = re.match(r'name="([^"]+)" type="\w+" parent="\."\]', head)
        if not hm:
            continue
        name = hm.group(1)
        sc = re.search(r'script = ExtResource\("(\w+)"\)', body)
        kind = sc.group(1) if sc else ''
        kind = ids.get(kind, kind)
        pos = re.search(r'position = Vector2\(([^)]*)\)', body)
        pts = re.search(r'points = PackedVector2Array\(([^)]*)\)', body)
        props = dict(re.findall(r'^(\w+) = (.+)$', body, re.M))
        nodes.append((name, kind, tuple(float(v) for v in pos.group(1).split(',')) if pos else None, pts.group(1) if pts else None, props))
    return (bx, by, bw, bh), blocks, cps, nodes


def draw(path, out_dir):
    (bx, by, bw, bh), blocks, cps, nodes = parse(path)
    W, H = int(bw * S) + 40, int(bh * S) + 40
    img = Image.new('RGB', (W, H), (205, 220, 235))
    d = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    X = lambda x: 20 + (x - bx) * S
    Y = lambda y: 20 + (y - by) * S
    for x in range(int(bx), int(bx + bw) + 1, 5):
        d.line((X(x), 20, X(x), H - 20), fill=(190, 205, 222))
        d.text((X(x) + 2, 4), str(x), fill=(90, 100, 120), font=font)
    for (x, y, w, h) in blocks:
        d.rectangle((X(x), Y(y), X(x + w) - 1, Y(y + h) - 1), fill=(105, 110, 125), outline=(60, 60, 75))
    for name, kind, pos, pts, props in nodes:
        c = COLORS.get(kind, (0, 0, 0))
        if pts:
            nums = [float(v) for v in pts.split(',')]
            line = [(X(nums[i] / T), Y(nums[i + 1] / T)) for i in range(0, len(nums), 2)]
            d.line(line, fill=c, width=3)
            continue
        if not pos:
            continue
        px, py = pos[0] / T, pos[1] / T
        size = props.get('size_tiles') or props.get('size')
        w = float(props.get('width_tiles', props.get('length_tiles', '1')).strip('"'))
        if size and 'Vector2' in size:
            sw, sh = (float(v) for v in re.search(r'\(([^)]*)\)', size).group(1).split(','))
            d.rectangle((X(px), Y(py), X(px + sw), Y(py + sh)), outline=c, width=3)
        elif kind in ('conveyor',):
            d.rectangle((X(px), Y(py), X(px + w), Y(py) + 6), fill=c)
        elif kind in ('spikes', 'brittle', 'spring', 'plate'):
            d.rectangle((X(px - w / 2), Y(py) - 6, X(px + w / 2), Y(py)), fill=c)
        elif kind == 'saw':
            path_t = re.search(r'\(([^)]*)\)', props.get('path_tiles', 'Vector2(6, 0)')).group(1).split(',')
            d.line((X(px), Y(py), X(px + float(path_t[0])), Y(py + float(path_t[1]))), fill=c, width=2)
            d.ellipse((X(px) - 8, Y(py) - 8, X(px) + 8, Y(py) + 8), fill=c)
        else:
            d.ellipse((X(px) - 6, Y(py) - 6, X(px) + 6, Y(py) + 6), fill=c, outline=(0, 0, 0))
        d.text((X(px) + 6, Y(py) - 14), name, fill=(0, 0, 0), font=font)
    for (x, y) in cps:
        d.polygon([(X(x), Y(y)), (X(x), Y(y) - 18), (X(x) + 10, Y(y) - 13)], fill=(250, 250, 250), outline=(0, 0, 0))
    out = Path(out_dir) / (Path(path).stem + '.png')
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    return out


if __name__ == '__main__':
    args = sys.argv[1:]
    out_dir = Path(__file__).resolve().parents[1] / 'tmp' / 'maps'
    if '--out' in args:
        i = args.index('--out'); out_dir = Path(args[i + 1]); del args[i:i + 2]
    for a in args:
        print(draw(a, out_dir))
