"""Уровень «Два цеха» (мир 2, 15) из головоломки tools/split_puzzle.py: два коридора один над другим,
по игроку в каждом; плиты и рычаги одного коридора открывают двери другого.

Раскладка по горизонтали — puzzle2.layout для каждого коридора (комнаты 0..n-1 — верхний, n..2n-1 —
нижний), оба начинаются у левой стены. Верхний пол — строка UP, под ним перекрытие до SLAB; нижний
коридор — от SLAB до пола LOW (6 тайлов: не допрыгнуть, не пролезть). Последние комнаты обоих коридоров
кончаются у правой стены; в полу верхней — проём вниз, к выходу в нижней: так оба приходят к одному финишу.
build_split(...) отдаёт координаты для бота tests/world2_new_smoke.gd."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from w2common import Level, COLORS, paths  # noqa: E402
from puzzle2 import layout, CRATE_L, CRATE_R  # noqa: E402

UP, SLAB, LOW = 6, 8, 14
HOLE = 3  # ширина проёма вниз в последней верхней комнате
PLATE_COLORS = ['orange', 'blue', 'green', 'purple', 'yellow', 'teal', 'pink', 'red']


def build_split(name, title, data, file_name, zone='scaffolds', landmark=None):
    n, links, plates, crates, levers = data
    up = layout([0] * n, {p: d for p, d in plates.items() if d['room'] < n}, [],
                {k: r for k, r in levers.items() if r < n})
    low = layout([0] * n, {p: dict(d, room=d['room'] - n) for p, d in plates.items() if d['room'] >= n}, [],
                 {k: r - n for k, r in levers.items() if r >= n})
    room_x = up[0] + low[0]
    widths = up[1] + low[1]
    end = max(room_x[n - 1] + widths[n - 1], room_x[-1] + widths[-1])
    widths[n - 1] = end - room_x[n - 1]
    widths[-1] = end - room_x[-1]
    plate_x = dict(up[2])
    plate_x.update(low[2])
    lever_x = dict(up[4])
    lever_x.update(low[4])
    floors = [UP] * n + [LOW] * n
    # ящики: первый в комнате — у левой стены, второй — у правой (как в модели)
    crate_x, used = [], {}
    for r in crates:
        k = used.get(r, 0)
        used[r] = k + 1
        crate_x.append(room_x[r] + (CRATE_L if k == 0 else widths[r] - CRATE_R))

    lv = Level(name, title, end + 1, zone, landmark)
    lv.kill_y = LOW + 7
    lv.bounds_h = LOW + 16
    colors = {pid: COLORS[PLATE_COLORS[k % len(PLATE_COLORS)]] for k, pid in enumerate(sorted(plates))}
    colors.update({ln: COLORS[PLATE_COLORS[(len(plates) + k) % len(PLATE_COLORS)]] for k, ln in enumerate(sorted(levers))})
    lv.block(1, UP, end - HOLE - 1, SLAB - UP)          # верхний пол — перекрытие
    lv.block(1, LOW, end - 1, lv.kill_y + 1 - LOW)      # нижний пол
    for i, link in enumerate(links):
        if link['kind'] == 'wall' or i == 2 * n - 1:
            continue
        col = room_x[i] + widths[i] - 1
        floor = floors[i]
        top = -8 if floor == UP else SLAB
        if link['kind'] == 'door':
            trig = link['trig']
            lv.block(col, top, 1, floor - 4 - top)
            extra = {}
            if link.get('all'):
                extra['require_all'] = 'true'
            if link.get('inv'):
                extra['invert'] = 'true'
            lv.node(f'D{i}', 'door', col, floor - 4, size_tiles='Vector2(1, 4)',
                    triggers=paths(*[f'P{t}' if isinstance(t, int) else t for t in trig]),
                    open_offset_tiles='Vector2(0, -3.5)',
                    mark_colors='Array[Color]([' + ', '.join(colors[t] for t in trig) + '])', **extra)
    for pid, d in plates.items():
        props = {'width_tiles': '2.5', 'mark_color': colors[pid]}
        if d.get('th', 1) != 1:
            props['threshold'] = f"{d['th']}.0"
        if d.get('latch'):
            props['latch'] = 'true'
        lv.node(f'P{pid}', 'plate', plate_x[pid], floors[d['room']], **props)
    for k, (r, x) in enumerate(zip(crates, crate_x)):
        lv.node(f'Crate{k}', 'crate', x, floors[r] - 31 / 64)
    for ln, r in levers.items():
        lv.node(ln, 'lever', lever_x[ln], floors[r], mark_color=colors[ln])
    lv.node('Finish', 'finish', end - HOLE / 2 - 1, LOW)
    lv.checkpoints = [(room_x[n] + 1.2, LOW)]
    lv.slot_spawns = [(room_x[0] + 1.2, UP), (room_x[n] + 1.2, LOW)]
    lv.write(file_name)
    return {'room_x': room_x, 'widths': widths, 'plate_x': plate_x, 'crate_x': crate_x, 'lever_x': lever_x,
            'floors': floors, 'n': n, 'width': end + 1}
