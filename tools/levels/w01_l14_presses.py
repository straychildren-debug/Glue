"""Генератор уровня мира 1 «14 · Под прессами» (немного сложный): низкий коридор с прессами.
1 — волна прессов (сдвиг = пробежка под одним прессом); 2 — длинный пресс: внизу долго, наверху
миг — одному не пробежать, один замирает в прыжке подпоркой, второй проходит под ним;
3 — пресс перед воротами: один жмёт кнопку, второй проскакивает под прессом в ворота, затем наоборот; 4 — два пресса в противофазе, между ними
колонна на одного; 5 — выход: две кнопки в одно окно.
Запуск: python tools/levels/w01_l14_presses.py → levels/w01_l14_presses.tscn"""
from pathlib import Path

T = 64
BLUE, RED = 'Color(0.4, 0.7, 0.95, 1)', 'Color(0.9, 0.3, 0.3, 1)'
GATE_PULSE = 0.35
EXIT_PULSE = 0.3

# Коридор: пол y 12, потолок y 9 (высота 3). Над прессами ниши до y 6, между ними колонны.
blocks = [
    (0, -8, 1, 26), (59, -8, 1, 26),
    (0, 12, 59, 6),
    (1, -8, 58, 14),                                  # потолок до y 6 над всем уровнем
    (1, 6, 6, 3),                                     # над стартом
    (7, 6, 1, 3), (11, 6, 1, 3), (15, 6, 1, 3),       # колонны волны
    (19, 6, 3, 3),                                    # между волной и длинным прессом
    (28, 6, 5, 3),                                    # за длинным прессом: кнопка, ждущий, бегущий
    (36, 6, 6, 3),                                    # за прессом у ворот (ворота 36)
    (45, 6, 1, 3),                                    # колонна между прессами в противофазе
    (49, 6, 10, 3),                                   # над выходом
]

nodes = []
def node(name, kind, script, x, y, **props):
    lines = [f'[node name="{name}" type="{kind}" parent="."]', f'position = Vector2({x * T:g}, {y * T:g})',
             f'script = ExtResource("{script}")']
    lines += [f'{k} = {v}' for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')

def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'

def press(name, x, width, **props):
    node(name, 'AnimatableBody2D', 'press', x, 6, size_tiles=f'Vector2({width}, 3)', **props)

# 1. Волна: сдвиг 0,71 с — пробежка под одним прессом
for i, delay in enumerate((0.0, 0.71, 1.42)):
    press(f'Wave{i + 1}', 8 + 4 * i, 3, top_wait='0.8', bottom_wait='0.3', start_delay=f'{delay}')
# 2. Длинный пресс 6 тайлов: внизу 2,5 с, наверху 0,3 с — одному не пробежать
press('Long', 22, 6, top_wait='0.3', bottom_wait='2.5')
# 3. Пресс перед воротами: кнопка до пресса — для первого, за воротами — первый жмёт для второго
press('GatePress', 33, 3, top_wait='0.25')
node('GateNear', 'AnimatableBody2D', 'plate', 30.0, 12, width_tiles='1.0', pulse=f'{GATE_PULSE}', mark_color=BLUE)
node('Gate', 'AnimatableBody2D', 'door', 36, 9, size_tiles='Vector2(1, 3)', triggers=paths('GateNear', 'GateButton'),
     open_offset_tiles='Vector2(0, -2.5)', mark_color=BLUE)
node('GateButton', 'AnimatableBody2D', 'plate', 38.5, 12, width_tiles='1.0', pulse=f'{GATE_PULSE}', mark_color=BLUE)
# 4. Два пресса в противофазе, между ними колонна на одного
press('PairA', 42, 3, top_wait='0.9', bottom_wait='0.9')
press('PairB', 46, 3, top_wait='0.9', bottom_wait='0.9', start_delay='1.4')
# 5. Выход: две красные кнопки в одно окно — ворота открываются насовсем
node('ExitA', 'AnimatableBody2D', 'plate', 51, 12, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=RED)
node('ExitB', 'AnimatableBody2D', 'plate', 53.5, 12, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=RED)
node('Exit', 'AnimatableBody2D', 'door', 55, 9, size_tiles='Vector2(1, 3)', triggers=paths('ExitA', 'ExitB'),
     require_all='true', stay_open='true', open_offset_tiles='Vector2(0, -2.5)', mark_color=RED)
node('Finish', 'Node2D', 'finish', 57.5, 12)

import backdrop
BD_ZONE, BD_LM = 'shrine', 'w01_v2_lm22_stone_press.png'

head = f'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]
{backdrop.resources(BD_ZONE, BD_LM)}
[ext_resource type="Script" path="res://src/mechanisms/pressure_plate.gd" id="plate"]
[ext_resource type="Script" path="res://src/mechanisms/door.gd" id="door"]
[ext_resource type="Script" path="res://src/mechanisms/press.gd" id="press"]
[ext_resource type="Script" path="res://src/mechanisms/finish.gd" id="finish"]

[node name="W01L14" type="Node2D"]
script = ExtResource("1")
title = "14 · Под прессами"
blocks = Array[Rect2]([{', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in blocks)}])
checkpoints = Array[Vector2]([Vector2(3, 12), Vector2(29.2, 12)])
bounds_tiles = Rect2(0, -8, 60, 27)
kill_y_tiles = 19.0
{backdrop.ground(BD_ZONE)}'''
tail = backdrop.tail(BD_ZONE, BD_LM, 60)
out = Path(__file__).resolve().parents[2] / 'levels/w01_l14_presses.tscn'
out.write_text(head + '\n' + '\n'.join(nodes) + '\n' + tail, encoding='utf-8')
print('written', out)
