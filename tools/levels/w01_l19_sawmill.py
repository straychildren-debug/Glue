"""Генератор уровня мира 1 «19 · Сквозь пилы» (очень сложный): долгая полоса пил, чекпоинт один —
посередине. 1 — три пилы по полу в разных фазах; 2 — пила над ямой с шипами (прыгать в просвет);
3 — катапульта на стену, по верху которой ездит пила, взлетевший вытягивает товарища, пока пила
не вернулась; 4 — «ступенька в воздухе» над пропастью с шипами под качающимися вертикальными
пилами; 5 — выход: две кнопки в одно окно, над каждой ходит пила.
Запуск: python tools/levels/w01_l19_sawmill.py → levels/w01_l19_sawmill.tscn"""
from pathlib import Path

T = 64
RED = 'Color(0.9, 0.3, 0.3, 1)'
EXIT_PULSE = 0.35

blocks = [
    (0, -8, 1, 26), (86, -8, 1, 26),
    (0, 12, 20, 6),                 # 1: пилы по полу 6–18
    (20, 14.5, 2.2, 3.5),           # 2: яма под пилой 20–22.2
    (22.2, 12, 13.8, 6),            # 2–3: берег, площадка перед стеной и под ней
    (30, 8.5, 6, 3.5),              # 3: стена 3,5 тайла (верх 30–36, y 8.5), по верху — пила
    (36, 12, 9, 6),                 # 3–4: за стеной, разбег к пропасти
    (45, 15, 4.6, 3),               # 4: пропасть с шипами 45–49.6
    (49.6, 12, 36.4, 6),            # 4–5: дальний берег, выход
    (78, -8, 1, 16),                # над выходом
]

nodes = []
def node(name, kind, script, x, y, **props):
    lines = [f'[node name="{name}" type="{kind}" parent="."]', f'position = Vector2({x * T:g}, {y * T:g})',
             f'script = ExtResource("{script}")']
    lines += [f'{k} = {v}' for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')

def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'

def floor_saw(name, x, row, path, speed, start_at=0.0, forward=True):
    node(name, 'Node2D', 'saw', x, row - 50 / T, radius_tiles='0.4', path_tiles=f'Vector2({path}, 0)',
         speed=f'{speed}', start_at=f'{start_at}', start_forward='true' if forward else 'false')

# 1. Три пилы по полу
floor_saw('Saw1', 5.0, 12, 2.5, 240.0)     # в одной фазе, через 5 тайлов: прыжки в ритм
floor_saw('Saw2', 10.0, 12, 2.5, 240.0)
floor_saw('Saw3', 15.0, 12, 2.5, 240.0)
# 2. Пила над ямой — прыгать в просвет
node('SpikesPit', 'Node2D', 'spikes', 21.1, 14.5, width_tiles='2.2')
node('SawPit', 'Node2D', 'saw', 20.3, 10.5, radius_tiles='0.45', path_tiles='Vector2(1.6, 0)', speed='150.0')
# 3. Пила по верху стены
floor_saw('SawWall', 31.9, 8.5, 3.6, 220.0)  # у левого края стены — 1,4 тайла на ловящего
# 4. Пропасть с шипами; над ней две вертикальные пилы
node('SpikesGap', 'Node2D', 'spikes', 47.3, 15, width_tiles='4.6')
node('SawDrop1', 'Node2D', 'saw', 46.4, 6.0, radius_tiles='0.45', path_tiles='Vector2(0, 2.6)', speed='200.0')
node('SawDrop2', 'Node2D', 'saw', 48.6, 6.0, radius_tiles='0.45', path_tiles='Vector2(0, 2.6)', speed='200.0',
     start_at='1.0', start_forward='false')
# 5. Выход: две кнопки, над каждой ходит пила
node('ExitA', 'AnimatableBody2D', 'plate', 70, 12, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=RED)
node('ExitB', 'AnimatableBody2D', 'plate', 74, 12, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=RED)
node('SawExitA', 'Node2D', 'saw', 70, 8.4, radius_tiles='0.45', path_tiles='Vector2(0, 2.2)', speed='180.0')
node('SawExitB', 'Node2D', 'saw', 74, 8.4, radius_tiles='0.45', path_tiles='Vector2(0, 2.2)', speed='180.0',
     start_at='0.6')
node('Exit', 'AnimatableBody2D', 'door', 78, 8, size_tiles='Vector2(1, 4)', triggers=paths('ExitA', 'ExitB'),
     require_all='true', stay_open='true', open_offset_tiles='Vector2(0, -3.5)', mark_color=RED)
node('Finish', 'Node2D', 'finish', 82, 12)

import backdrop
BD_ZONE, BD_LM = 'pass', 'w01_v2_lm11_watermill.png'  # мельница на воде — она же пилорама

head = f'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]
{backdrop.resources(BD_ZONE, BD_LM)}
[ext_resource type="Script" path="res://src/mechanisms/pressure_plate.gd" id="plate"]
[ext_resource type="Script" path="res://src/mechanisms/door.gd" id="door"]
[ext_resource type="Script" path="res://src/mechanisms/saw.gd" id="saw"]
[ext_resource type="Script" path="res://src/mechanisms/spikes.gd" id="spikes"]
[ext_resource type="Script" path="res://src/mechanisms/finish.gd" id="finish"]

[node name="W01L19" type="Node2D"]
script = ExtResource("1")
title = "19 · Сквозь пилы"
blocks = Array[Rect2]([{', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in blocks)}])
checkpoints = Array[Vector2]([Vector2(3, 12), Vector2(38.5, 12)])
bounds_tiles = Rect2(0, -8, 87, 27)
kill_y_tiles = 19.0
{backdrop.ground(BD_ZONE)}'''
tail = backdrop.tail(BD_ZONE, BD_LM, 87)
out = Path(__file__).resolve().parents[2] / 'levels/w01_l19_sawmill.tscn'
out.write_text(head + '\n' + '\n'.join(nodes) + '\n' + tail, encoding='utf-8')
print('written', out)
