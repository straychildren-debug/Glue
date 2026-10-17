"""Уровень мира 2 из головоломки модели tools/puzzle2.py (комнаты в ряд): build(...) пишет сцену.

Раскладка — puzzle2.layout: ширина комнаты по содержимому, пол на высоте 12 − 3·h (h — уровень комнаты).
Граница — столбец в тайл на уровне верхней из двух комнат: в нём дверь (если связь — дверь) с потолком
до неба; уступ — стена от нижнего пола до верхнего. Пол собран сплошными полосами одной высоты.
Лента — конвейер через границу (по умолчанию едет в сторону dir, рычаг разворачивает). Старт — в комнате 0,
выход — в последней. build(...) отдаёт координаты для бота: room_x, widths, plate_x, crate_x, lever_x."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from w2common import Level, COLORS, paths, path  # noqa: E402
from puzzle2 import layout  # noqa: E402

PLATE_COLORS = ['orange', 'blue', 'green', 'purple', 'yellow', 'teal', 'pink', 'red']


def floor_y(h):
    return 12 - 3 * h


def build(name, title, data, file_name, zone='forge', landmark=None):
    rooms, links, plates, crates, levers, heavy = data
    room_x, widths, plate_x, crate_x, lever_x = layout(rooms, plates, crates, levers)
    width = room_x[-1] + widths[-1] + 1
    lv = Level(name, title, width, zone, landmark)
    colors = {pid: COLORS[PLATE_COLORS[k % len(PLATE_COLORS)]] for k, pid in enumerate(sorted(plates))}
    colors.update({ln: COLORS[PLATE_COLORS[(len(plates) + k) % len(PLATE_COLORS)]] for k, ln in enumerate(sorted(levers))})
    n = len(rooms)
    # пол — сплошными полосами одной высоты: на стыке соседних блоков ящик застревает
    tops = []
    for i in range(n):
        tops += [floor_y(rooms[i])] * (widths[i] if i == n - 1 else widths[i] - 1)
        if i < n - 1:
            tops.append(min(floor_y(rooms[i]), floor_y(rooms[i + 1])))  # граничный столбец
    # лента — 4 тайла (длиннее прыжка с разбега, 3,8) вровень с полом: пол под ней ниже на её толщину;
    # в комнаты заходит на 1,5 тайла (концы над полутайловыми ямками закрывают её скаты)
    BELT_SINK = 0.375
    for i, link in enumerate(links):
        if link['kind'] == 'belt':
            col = int(room_x[i] + widths[i] - 1 - room_x[0])
            for t in range(col - 2, col + 3):
                tops[t] += BELT_SINK
    start = 0
    for k in range(1, len(tops) + 1):
        if k == len(tops) or tops[k] != tops[start]:
            lv.block(room_x[0] + start, tops[start], k - start, 18 - tops[start])
            start = k
    for i in range(n):
        y = floor_y(rooms[i])
        x0 = room_x[i]
        last = i == n - 1
        if not last:
            yb = min(y, floor_y(rooms[i + 1]))
            col = x0 + widths[i] - 1
            link = links[i]
            if link['kind'] == 'belt':
                d = link['dir']
                trig = link.get('trig', [])
                props = {'width_tiles': '4.0', 'speed': f'{360.0 * d}'}
                if trig:
                    props['control'] = path(trig[0])
                lv.node(f'Belt{i}', 'conveyor', col - 1.5, yb, **props)
            if link['kind'] == 'door':
                trig = link['trig']
                lv.block(col, -8, 1, yb - 4 + 8)
                extra = {}
                if link.get('all'):
                    extra['require_all'] = 'true'
                if link.get('inv'):
                    extra['invert'] = 'true'
                lv.node(f'D{i}', 'door', col, yb - 4, size_tiles='Vector2(1, 4)', triggers=paths(*[f'P{t}' if isinstance(t, int) else t for t in trig]),
                        open_offset_tiles='Vector2(0, -3.5)',
                        mark_colors='Array[Color]([' + ', '.join(colors[t] for t in trig) + '])', **extra)
    for pid, d in plates.items():
        props = {'width_tiles': '2.5', 'mark_color': colors[pid]}
        if d.get('th', 1) != 1:
            props['threshold'] = f"{d['th']}.0"
        if d.get('latch'):
            props['latch'] = 'true'
        lv.node(f'P{pid}', 'plate', plate_x[pid], floor_y(rooms[d['room']]), **props)
    for k, (r, x) in enumerate(zip(crates, crate_x)):
        props = {'mass': '2.0'} if k in heavy else {}
        lv.node(f'Crate{k}', 'crate', x, floor_y(rooms[r]) - 31 / 64, **props)
    for ln, x in lever_x.items():
        lv.node(ln, 'lever', x, floor_y(rooms[levers[ln]]), mark_color=colors[ln])
    lv.node('Finish', 'finish', room_x[-1] + widths[-1] - 3.0, floor_y(rooms[-1]))
    lv.checkpoints = [(room_x[0] + 1.0, floor_y(rooms[0]))]
    lv.write(file_name)
    return {'room_x': room_x, 'widths': widths, 'plate_x': plate_x, 'crate_x': crate_x, 'lever_x': lever_x, 'width': width}
