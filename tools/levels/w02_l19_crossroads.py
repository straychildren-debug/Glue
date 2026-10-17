"""Генератор уровня мира 2 «19 · Перекрёсток» (очень сложный, головоломка; вторая переделка после тестов:
«очень лёгкая задачка, решили за 5 секунд»).

Изюминка — поворотные балки (src/mechanisms/turntable.gd): лежит — мост через пропасть, стоит — столб.
Шесть комнат в ряд, между ними пять балок. Метка на балке — цвет того, что её поворачивает: сплошная —
«включено — мост», пунктир — «включено — столб». Ящик или замерший на балке её заклинивает.

Головоломка найдена перебором (tools/levels/turn_solver.py): кратчайшее решение — 30 ходов.
- Ящик стоит на плите и держит первую балку мостом. Снимешь — товарищ у рычага отрезан.
- Рычаг у старта: вторая и третья балки — мосты при включённом, пятая — при выключенном.
- Четвёртая — мост, пока плита НЕ нажата. Плиту держит ящик или стоящий на ней.
- Рычаг во второй комнате — приманка: ни к чему не подключён.
Нужно: заклинить мост замершим, сменить его ящиком, держать плиту собой, вернуться к рычагу и
переключать его в нужные моменты.

Низкий потолок (2,5 тайла над полом): с головы товарища и «ступенькой в воздухе» пропасть не перейти,
на верх столба не забраться.

Запуск: python tools/levels/w02_l19_crossroads.py → levels/w02_l19_crossroads.tscn и .solution.json"""
import json
import re
from pathlib import Path

from w2common import Level, COLORS, paths, ROOT
from turn_solver import solve

ROOM, PIT = 5, 6
N = 6
BEAMS = [(['P0'], False), (['L1'], False), (['L1'], False), (['P0'], True), (['L1'], True)]
LEVERS = {'L0': 1, 'L1': 0}
PLATES = {'P0': 3}
CRATE = 3
COLOR = {'L1': COLORS['orange'], 'L0': COLORS['teal'], 'P0': COLORS['purple']}


def room_x(i):
    return 1 + i * (ROOM + PIT)


# Фаза 2 «Карусель» (от X2): балки на часах; фаза 3 «Обвал» (от X3): эстафета по плитам под обвалом.
X2 = room_x(N - 1) + ROOM          # 61
CAROUSEL = [  # (период, мост, сдвиг) часов каждой балки; мост 0,9 с — перебежать не успеть
    (3.8, 2.2, 0.0), (3.6, 2.1, 0.7), (3.0, 0.9, 0.0), (4.0, 2.2, 1.2), (3.0, 0.9, 1.5), (3.0, 0.9, 0.0)]
ISLE2, ISLE3 = 3, 4
X3 = X2 + 1 + len(CAROUSEL) * (PIT + ISLE2)
RELAY = 6
WIDTH = X3 + RELAY * (PIT + ISLE3) + 6

lv = Level('W02L19', '19 · Перекрёсток', WIDTH, 'machine', 'w02_lm19_crossing.png')
lv.block(1, -8, room_x(N - 1) + ROOM - 1, 17.5)        # низкий потолок (низ 9,5)
lever_x = {'L1': room_x(0) + 1.5, 'L0': room_x(1) + 2.5}
plate_x = {'P0': room_x(3) + 2.5}
for i in range(N):
    lv.block(room_x(i), 12, ROOM, 6)
for name, room in LEVERS.items():
    lv.node(f'Lever{name}', 'lever', lever_x[name], 12, mark_color=COLOR[name])
lv.node('PlateP0', 'plate', plate_x['P0'], 12, width_tiles='1.5', mark_color=COLOR['P0'])
lv.node('Crate', 'crate', plate_x['P0'], 12 - 31 / 64)
for k, (trig, inv) in enumerate(BEAMS):
    x0 = room_x(k) + ROOM
    lv.block(x0, 15, PIT, 3)
    lv.node(f'Pit{k}', 'spikes', x0 + PIT / 2, 15, width_tiles=f'{PIT}.0')
    marks = ', '.join(COLOR[t] for t in trig)
    lv.node(f'Turn{k}', 'turntable', x0 + PIT / 2, 12, length_tiles=f'{PIT}.0', off_degrees='90.0', on_degrees='0.0',
            triggers=paths(*(f'Lever{t}' if t.startswith('L') else f'Plate{t}' for t in trig)),
            invert='true' if inv else 'false', mark_colors=f'Array[Color]([{marks}])')

# --- Фаза 2 «Карусель» (X2…X3): острова по 3 тайла, балки по 6 на часах (Clock): мост, пока часы
# активны; поворачиваются быстро (0,25 с). Три балки — мост лишь на 0,9 с: пробежать 6 тайлов не успеть
# (сбросит на шипы). Один вбегает на мост и замирает
# (заклинил — балка не повернётся), второй перепрыгивает его; замерший оживает, только когда часы снова
# «мост», — иначе балка повернётся и сбросит. Две последние подряд — эстафетой: каждый держит одну. ---
lv.block(X2, 12, 1, 6)
x = X2 + 1
for k, (period, bridge, off) in enumerate(CAROUSEL):
    lv.block(x, 15, PIT, 3)
    lv.node(f'PitC{k}', 'spikes', x + PIT / 2, 15, width_tiles=f'{PIT}.0')
    lv.node(f'ClockC{k}', 'clock', None, None, period=f'{period}', open_time=f'{bridge}', offset=f'{off}')
    lv.node(f'TurnC{k}', 'turntable', x + PIT / 2, 12, length_tiles=f'{PIT}.0', off_degrees='90.0', on_degrees='0.0',
            triggers=paths(f'ClockC{k}'), turn_speed='360.0')
    x += PIT
    lv.block(x, 12, ISLE2, 6)
    x += ISLE2
assert x == X3

# --- Фаза 3 «Обвал» (X3…): сзади обвал. На каждом острове (4 тайла) две плиты: левая держит мостом
# балку позади, правая — балку впереди. Чехарда: один стоит на правой — второй перебегает и встаёт на
# левую следующего острова; первый сходит (балка позади встаёт столбом) и бежит к правой плите... Сошёл
# с плиты, пока товарищ на мосту, — тот падает на шипы. ---
relay_colors = [COLORS['orange'], COLORS['blue'], COLORS['green'], COLORS['pink'], COLORS['yellow'], COLORS['purple']]
lv.block(X3, 12, ISLE3, 6)
x = X3
for k in range(RELAY):
    c = relay_colors[k]
    lv.node(f'PlateR{k}', 'plate', x + ISLE3 - 0.75, 12, width_tiles='1.0', mark_color=c)   # правая плита острова k
    b0 = x + ISLE3
    lv.block(b0, 15, PIT, 3)
    lv.node(f'PitR{k}', 'spikes', b0 + PIT / 2, 15, width_tiles=f'{PIT}.0')
    lv.node(f'PlateL{k}', 'plate', b0 + PIT + 0.75, 12, width_tiles='1.0', mark_color=c)  # левая следующего
    lv.node(f'TurnR{k}', 'turntable', b0 + PIT / 2, 12, length_tiles=f'{PIT}.0', off_degrees='90.0', on_degrees='0.0',
            triggers=paths(f'PlateR{k}', f'PlateL{k}'), mark_colors=f'Array[Color]([{c}, {c}])',
            turn_speed='360.0')
    x = b0 + PIT
    lv.block(x, 12, ISLE3 if k < RELAY - 1 else WIDTH - x, 6)
lv.node('Crusher', 'crusher', X3 - 4, -8, height_tiles='27.0', speed='155.0', start_x_tiles=f'{X3 + 1.5}',
        stop_x_tiles=f'{WIDTH - 5}', catch_up_tiles='8.0', catch_up_speed='260.0')
lv.node('Finish', 'finish', WIDTH - 3, 12)
lv.checkpoints = [(room_x(0) + 3, 12), (X2 - 2, 12), (X3 + 1, 12)]
lv.write('w02_l19_crossroads.tscn')

# Решение для бота: ходы решателя в виде действий.
path, prev = solve(N, BEAMS, LEVERS, PLATES, CRATE)
steps = []
for s in path[1:]:
    label = prev[s][1]
    who, act = label.split(': ', 1)
    m = re.match(r'(перешёл в|замер на мосту|ожил, сошёл в|толкнул ящик на мост|встал на плиту в|сошёл с плиты в|рычаг) ?(\S*)', act)
    kind = {'перешёл в': 'go', 'замер на мосту': 'freeze', 'ожил, сошёл в': 'unfreeze', 'толкнул ящик на мост': 'push_on',
            'встал на плиту в': 'plate_on', 'сошёл с плиты в': 'plate_off', 'рычаг': 'lever'}.get(m.group(1)) if m else None
    if act.startswith('протолкнул ящик по мосту'):
        k, j = re.findall(r'\d+', act)
        steps.append({'p': 0 if who == 'А' else 1, 'do': 'push_across', 'beam': int(k), 'room': int(j)})
        continue
    if act.startswith('стянул ящик с моста'):
        k, j = re.findall(r'\d+', act)
        steps.append({'p': 0 if who == 'А' else 1, 'do': 'pull_off', 'beam': int(k), 'room': int(j)})
        continue
    arg = m.group(2)
    steps.append({'p': 0 if who == 'А' else 1, 'do': kind, 'arg': arg})
data = {'room_x': [room_x(i) for i in range(N)], 'room_w': ROOM, 'pit_w': PIT, 'x2': X2, 'x3': X3,
        'isle2': ISLE2, 'isle3': ISLE3, 'carousel': CAROUSEL, 'relay': RELAY,
        'lever_x': lever_x, 'plate_x': plate_x, 'steps': steps}
(ROOT / 'levels' / 'w02_l19_crossroads.solution.json').write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')
print(len(steps), 'шагов решения')
