"""Генератор уровня мира 2 «13 · Механический замок» (очень сложный, головоломка; третья версия после
тестов: «очень простой, ящиком закрыли поднимающуюся стенку и всё»; мерило — не меньше 10 минут).

Изюминка — камера-замок: один рычаг переворачивает в ней всё разом — двери и ленты. Три камеры подряд,
каждая — своя головоломка, по нарастающей. Камеры подобраны перебором (tools/levels/lock_solver.py):
у каждой проверено, что решение есть, сколько в нём решений (ход рычага, ящика, шаг на плиту — ходьба
не в счёт) и сколько тупиков.

Правила камеры (их же знает решатель):
- лента в тоннеле: скорость ленты равна бегу, потолок низкий — против хода не пройти и не пропрыгать;
  кого лента довезла до открытого проёма — того выносит дальше;
- ящик в проёме подпирает дверь: та не закроется, пока он там. Между комнатами с высоким потолком ящик
  в проёме перепрыгивается, у тоннеля — нет (только протолкнуть);
- лента сама довозит ящик до своего конца и вкатывает в проём, если дверь там открыта;
- комната плиты узкая, плита во весь пол: кто в комнате (герой или ящик) — тот и жмёт.

1. Вводная (3 решения): ящик подпирает дверь, которая открыта, только пока второй у рычага.
2. Плита за тоннелем (10): ящик с ленты сам встаёт в проём; ящики — на плиту и в проёмы, чтобы рычаг
   выпустил обоих; около половины состояний — тупики.
3. Третья (13): две плиты, лента-подпорка, ящик обратно к рычагу — подпереть дверь тому, кто его тянул;
   почти две трети состояний — тупики (застрявшие начинают камеру заново с чекпоинта).
4. Финал (35, четвёртая версия: «11–14 — по мерке 15–16»): два рычага — у входа и посреди камеры,
   восемь комнат, два ящика, лента у выхода; больше половины состояний — тупики.
Между камерами — ступенька в 1,5 тайла: героям запрыгнуть, ящику не въехать — ящики остаются в своей камере.

Запуск: python tools/levels/w02_l13_lock.py → levels/w02_l13_lock.tscn и .solution.json"""
import json

from w2common import Level, COLORS, paths, path, vec, ROOT
from lock_solver import Chamber, key_actions

# Камеры: описание для решателя (комнаты 'f' — пол, 'b' — лента в тоннеле; двери — (триггеры, invert)
# или None — проём без двери; ленты — комната → (триггеры, invert): вправо, когда (активен) != invert).
CHAMBERS = [
    dict(rooms=['f', 'b', 'f', 'f'], doors=[(['L'], True), None, (['L'], False)],
         belts={1: (['L'], True)}, levers={'L': 0}, plates={}, crates=[2]),
    dict(rooms=['f', 'b', 'f', 'f', 'f', 'f'],
         doors=[(['L'], False), (['L'], False), (['L'], False), (['L'], True), (['L'], True)],
         belts={1: (['L'], False)}, levers={'L': 0}, plates={'P': 3}, crates=[1, 3]),
    dict(rooms=['f', 'f', 'f', 'f', 'f', 'b', 'f'],
         doors=[(['L'], True), (['L'], False), (['Q'], True), (['L'], True), (['Q'], False), (['L'], False)],
         belts={5: (['L'], False)}, levers={'L': 0}, plates={'P': 1, 'Q': 4}, crates=[2, 5]),
    # 4. Два рычага (найдена перебором tools/levels/lock_search.py): второй рычаг M посреди камеры
    # правит дальним концом — лентой и двумя последними дверями.
    dict(rooms=['f', 'f', 'f', 'f', 'f', 'f', 'b', 'f'],
         doors=[(['L'], True), (['L'], False), (['L'], True), (['L'], False), (['L'], False), (['M'], True), (['M'], False)],
         belts={6: (['M'], False)}, levers={'L': 0, 'M': 3}, plates={}, crates=[4, 6]),
]
LEVER_COLORS = [{'L': COLORS['orange']}, {'L': COLORS['teal']}, {'L': COLORS['pink']},
                {'L': COLORS['yellow'], 'M': COLORS['blue']}]
PLATE_COLORS = [{'P': COLORS['yellow']}, {'P': COLORS['purple']}, {'P': COLORS['blue'], 'Q': COLORS['green']}, {}]
W_FLOOR, W_BELT, W_PLATE = 3, 4, 3
STEP = 1.5           # ступенька между камерами
TUNNEL = 1.1         # просвет тоннеля над лентой
BELT = 360.0         # скорость ленты — как бег

# Раскладка: комнаты всех камер подряд (глобальные номера), x, ширина, пол.
rooms = []           # (камера, номер в камере, вид, x, ширина, пол y)
doorways = []        # (камера, номер в камере, x, пол y)
x = 1.0
floor = 12.0
for ci, ch in enumerate(CHAMBERS):
    for ri, kind in enumerate(ch['rooms']):
        w = W_BELT if kind == 'b' else (W_PLATE if ri in ch['plates'].values() else W_FLOOR)
        if ri == len(ch['rooms']) - 1 and ci < len(CHAMBERS) - 1:
            w += 1   # комната выхода — с местом под ступеньку
        if ri in ch['levers'].values() and len(ch['levers']) > 1:
            w = 5    # комната рычага шире: у проёма хват берёт ящик, а не рычаг (рычаг достаёт на 1,25 тайла)
        rooms.append((ci, ri, kind, x, w, floor))
        x += w
        if ri < len(ch['rooms']) - 1:
            if ch['doors'][ri] is None:
                doorways.append((ci, ri, x - 0.5, floor))   # без двери — комнаты встык, проёма нет
            else:
                doorways.append((ci, ri, x, floor))
                x += 1
    floor -= STEP
width = x + 6

lv = Level('W02L13', '13 · Механический замок', width, 'scaffolds', 'w02_lm13_lock_gate.png')
# потолок: над каждой комнатой — на 4 тайла выше её пола (над тоннелем — низкий)
for ci, ri, kind, rx, w, fy in rooms:
    top = fy - TUNNEL if kind == 'b' else fy - 4
    lv.block(rx, -8, w, top + 8)
    if kind == 'b':
        lv.block(rx, fy + 0.375, w, 18 - fy - 0.375)
    else:
        lv.block(rx, fy, w, 18 - fy)
for ci, k, dx, fy in doorways:
    if CHAMBERS[ci]['doors'][k] is None:
        continue
    lv.block(dx, -8, 1, fy - 4 + 8)
    lv.block(dx, fy, 1, 18 - fy)
lv.block(x, -8, width - x, (floor + STEP) - 4 + 8)          # над выходом
lv.block(x, floor + STEP, width - x, 18 - floor - STEP)

names = {}
for ci, ch in enumerate(CHAMBERS):
    trig = {name: f'Lever{ci + 1}' if name == 'L' else f'Lever{ci + 1}{name}' for name in ch['levers']}
    for pname, room in ch['plates'].items():
        trig[pname] = f'Plate{ci + 1}{pname}'
    names[ci] = trig
    color = {**LEVER_COLORS[ci], **{p: PLATE_COLORS[ci][p] for p in ch['plates']}}
    my_rooms = [r for r in rooms if r[0] == ci]
    my_doors = [d for d in doorways if d[0] == ci]
    for name, room in ch['levers'].items():
        _, _, _, rx, w, fy = my_rooms[room]
        lv.node(trig[name], 'lever', rx + w / 2, fy, mark_color=color[name])
    for pname, room in ch['plates'].items():
        _, _, _, rx, w, fy = my_rooms[room]
        lv.node(trig[pname], 'plate', rx + w / 2, fy, width_tiles=f'{w:.1f}', mark_color=color[pname])
    for k, spec in enumerate(ch['doors']):
        if spec is None:
            continue
        tr, inv = spec
        _, _, dx, fy = my_doors[k]
        lv.node(f'Door{ci + 1}{k}', 'door', dx, fy - 4, size_tiles=vec(1, 4), triggers=paths(*(trig[t] for t in tr)),
                invert='true' if inv else 'false', open_offset_tiles=vec(0, 4), close_speed='900.0',
                mark_colors=f'Array[Color]([{", ".join(color[t] for t in tr)}])')
    for room, (tr, inv) in ch['belts'].items():
        _, _, _, rx, w, fy = my_rooms[room]
        # лента от рычага: вкл — −speed, выкл — +speed; вправо, когда (рычаг вкл) != invert
        lv.node(f'Belt{ci + 1}{room}', 'conveyor', rx, fy, width_tiles=f'{w:.1f}',
                speed=f'{BELT if inv else -BELT}', control=path(trig[tr[0]]))
    for j, room in enumerate(ch['crates']):
        _, _, kind, rx, w, fy = my_rooms[room]
        lv.node(f'Crate{ci + 1}{j}', 'crate', rx + w / 2, fy - 31 / 64)

last = rooms[-1]
lv.node('Finish', 'finish', x + 3, floor + STEP)
lv.checkpoints = [(r[3] + 1, r[5]) for r in rooms if r[1] == 0]
lv.write('w02_l13_lock.tscn')

# Решение для бота: по камерам, ходы решателя (меньше всего решений) — в глобальных номерах.
steps = []
total = 0
for ci, ch in enumerate(CHAMBERS):
    k, sol, prev = key_actions(Chamber(**ch))
    total += k
    base = next(i for i, r in enumerate(rooms) if r[0] == ci)
    dbase = next(i for i, d in enumerate(doorways) if d[0] == ci)
    steps.append({'do': 'chamber', 'n': ci})
    if ci > 0:   # оба — на ступеньку, в начало камеры
        for p in (1, 0):
            steps.append({'p': p, 'do': 'go', 'room': base, 'after': [base if q == p or p == 0 else base - 1 for q in (0, 1)]})
    for s in sol[1:]:
        who, act = prev[s][1].split(': ', 1)
        p = 0 if who == 'А' else 1
        nums = [int(t) for t in act.replace(',', ' ').split() if t.isdigit()]
        if act.startswith('перешёл'):
            steps.append({'p': p, 'do': 'go', 'room': base + nums[0]})
        elif act.startswith('рычаг'):
            steps.append({'p': p, 'do': 'lever', 'name': names[ci][act.split()[1]]})
        elif act.startswith('втолкнул'):
            steps.append({'p': p, 'do': 'push_in', 'door': dbase + nums[0]})
        elif act.startswith('протолкнул ящик из проёма'):
            steps.append({'p': p, 'do': 'push_out', 'door': dbase + nums[0], 'room': base + nums[1]})
        elif act.startswith('протолкнул ящик в'):
            steps.append({'p': p, 'do': 'push_room', 'room': base + nums[0]})
        elif act.startswith('стянул'):
            steps.append({'p': p, 'do': 'pull', 'door': dbase + nums[0], 'room': base + nums[1]})
        else:
            raise ValueError(act)
        # где все после хода (ленты сносят) — для проверки
        steps[-1]['after'] = [base + q[1] for q in s[0]]
        steps[-1]['lever'] = [names[ci]['L'], bool(s[2][sorted(ch['levers']).index('L')])]
    print(f'камера {ci + 1}: {k} решений')
data = {'rooms': [{'x': r[3], 'w': r[4], 'floor': r[5], 'kind': r[2], 'chamber': r[0]} for r in rooms],
        'doorways': [{'x': d[2], 'floor': d[3]} for d in doorways], 'steps': steps}
(ROOT / 'levels' / 'w02_l13_lock.solution.json').write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')
print('всего решений', total, 'ширина', width)
