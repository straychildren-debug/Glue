"""Генератор пробного уровня 06 «Эстафета»: два коридора, кнопки одного коридора на миг
открывают ворота другого; перед каждыми воротами — препятствие, которое надо пройти в окно.
Запуск: python tools/levels/t06_relay.py          → levels/trial/t06_relay.tscn (пробный, с лентами)
        python tools/levels/t06_relay.py --world1 → levels/w01_l11_relay.tscn (мир 1: вместо лент —
        пила над ямой и пила навстречу перед ямой у ворот)"""
import sys
from pathlib import Path

WORLD1 = '--world1' in sys.argv or '--chase' in sys.argv
# --chase: мир 1, уровень 18 «Эстафета под обвалом» — слева через оба коридора ползёт обвал
CHASE = '--chase' in sys.argv
CRUSHER_SPEED = 55.0   # px/с; подбирается по боту (запас в строках «обвал в N тайла»)
CATCH_UP = 9.0

T = 64
ORANGE, BLUE, GREEN, PURPLE, RED = ('Color(0.95, 0.6, 0.2, 1)', 'Color(0.4, 0.7, 0.95, 1)',
    'Color(0.35, 0.8, 0.4, 1)', 'Color(0.7, 0.45, 0.95, 1)', 'Color(0.9, 0.3, 0.3, 1)')
YELLOW, TEAL, PINK, WHITE, LIME, BROWN = ('Color(0.95, 0.85, 0.3, 1)', 'Color(0.3, 0.8, 0.75, 1)',
    'Color(0.95, 0.5, 0.7, 1)', 'Color(0.88, 0.88, 0.92, 1)', 'Color(0.65, 0.9, 0.3, 1)', 'Color(0.7, 0.5, 0.3, 1)')
# Сколько кнопка держит ворота, с (подобраны замером tests/tuning/t06_windows: окна ≈ 0,3–0,5 с).
PULSE_U1, PULSE_L1, PULSE_U2, PULSE_L2 = 0.4, 0.3, 0.4, 0.25
PULSE_U3, PULSE_L3, PULSE_U4, PULSE_L4, PULSE_U5, PULSE_L5 = 0.25, 0.25, 0.6, 0.25, 0.4, 0.3
EXIT_PULSE = 0.3   # окно кнопок выхода, с
if WORLD1:
    PULSE_U2 = 0.6  # прыжок под пилой в ворота — уже испытание ловкости, окно кнопки шире

blocks = [
    (0, -8, 1, 26), (61, -8, 1, 26),
    # пол нижнего коридора: яма 9.5–11.5; дальше — по варианту (см. LOWER); двойная яма 34.4–36.2
    # и 37.2–39 с площадкой в тайл
    (0, 12, 9.5, 6), (11.5, 12, 3.3, 6), (9.5, 14.5, 2, 3.5),
    (34.4, 14.5, 1.8, 3.5), (36.2, 12, 1, 6), (37.2, 14.5, 1.8, 3.5),
    # потолок верхнего коридора (y 3) с нишами прессов 23–26 и 36.5–40.5
    (1, -8, 22, 11), (23, -8, 3, 7), (26, -8, 10.5, 11), (36.5, -8, 4, 7), (40.5, -8, 20.5, 11),
    # перекрытие между коридорами
    (5, 7, 50, 1),
    # ступени на старте: наверх, в верхний коридор
    (1, 10, 1.5, 2), (3.2, 8.5, 1.3, 0.5),
]

if WORLD1:
    # мир 1: яма 16.6–18.8 под пилой (ворота 18.8); яма 47–48 сразу перед воротами
    blocks += [(14.8, 12, 1.8, 6), (16.6, 14.5, 2.2, 3.5), (18.8, 12, 15.6, 6), (39, 12, 8, 6), (47, 14.5, 1, 3.5),
               (48, 12, 13, 6)]
else:
    # пробный: яма у ленты 14.8–15.6; лента 15.6–21.6 (назад); лента 42.5–46.5 (вперёд); яма 46.5–48
    blocks += [(14.8, 14.5, 0.8, 3.5), (15.6, 12.375, 6, 5.625), (21.6, 12, 12.8, 6), (39, 12, 3.5, 6),
               (42.5, 12.375, 4, 5.625), (46.5, 14.5, 1.5, 3.5), (48, 12, 13, 6)]

nodes = []
def node(name, kind, script, x, y, **props):
    lines = [f'[node name="{name}" type="{kind}" parent="."]', f'position = Vector2({x * T:g}, {y * T:g})',
             f'script = ExtResource("{script}")']
    for k, v in props.items():
        lines.append(f'{k} = {v}')
    nodes.append('\n'.join(lines) + '\n')

def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'

def gate_u(name, x, button, color):
    node(name, 'AnimatableBody2D', 'door', x, 3, size_tiles='Vector2(1, 4)', triggers=paths(button),
         open_offset_tiles='Vector2(0, -3.5)', mark_color=color)

def gate_l(name, x, button, color, open_speed=480.0):
    node(name, 'AnimatableBody2D', 'door', x, 8, size_tiles='Vector2(1, 4)', triggers=paths(button),
         open_offset_tiles='Vector2(0, 4)', open_speed=f'{open_speed}', mark_color=color)

def button(name, x, row, pulse, color):
    node(name, 'AnimatableBody2D', 'plate', x, row, width_tiles='1.0', pulse=pulse, mark_color=color)

def floor_saw(name, x, row, path, speed=240.0):
    node(name, 'Node2D', 'saw', x, row - 50 / T, radius_tiles='0.4', path_tiles=f'Vector2({path}, 0)', speed=f'{speed}')

def drop_saw(name, x, start_at=0.0, forward=True):
    # пила ходит вверх-вниз перед воротами верхнего коридора: под ней не постоишь
    node(name, 'Node2D', 'saw', x, 3.6, radius_tiles='0.5', path_tiles='Vector2(0, 2.9)', speed='260.0',
         start_at=f'{start_at}', start_forward='true' if forward else 'false')

# Верхний коридор (пол y 7)
button('ButtonU1', 8.5, 7, PULSE_U1, ORANGE)
drop_saw('SawU', 13.8)
gate_u('GateU1', 14.5, 'ButtonL1', BLUE)
button('ButtonU2', 17.5, 7, PULSE_U2, GREEN)
node('PressU', 'AnimatableBody2D', 'press', 23, -1, size_tiles='Vector2(3, 4)', drop_tiles='4.0', top_wait='0.25')
gate_u('GateU2', 26, 'ButtonL2', PURPLE)
button('ButtonU3', 28, 7, PULSE_U3, YELLOW)
drop_saw('SawU2', 30.3)
drop_saw('SawU3', 31.9, 0.38, False)  # отстаёт от первой на пробежку между ними
gate_u('GateU3', 32.45, 'ButtonL3', TEAL)  # вплотную к пиле: ждать у ворот негде
button('ButtonU4', 35, 7, PULSE_U4, PINK)
node('PressU2', 'AnimatableBody2D', 'press', 36.5, -1, size_tiles='Vector2(4, 4)', drop_tiles='4.0',
     top_wait='0.25', rise_speed='320.0')
gate_u('GateU4', 40.5, 'ButtonL4', WHITE)
button('ButtonU5', 42.9, 7, PULSE_U5, LIME)  # слева от неё место на ждущего
floor_saw('SawU4', 44, 7, 3.2, 360.0)  # быстрая: у ворот не переждать
gate_u('GateU5', 47.6, 'ButtonL5', BROWN)  # вплотную к концу рельса пилы
button('ButtonU6', 52, 7, EXIT_PULSE, RED)
# Нижний коридор (пол y 12)
node('SpikesL', 'Node2D', 'spikes', 10.5, 14.5, width_tiles='2.0')
gate_l('GateL1', 11.5, 'ButtonU1', ORANGE)
button('ButtonL1', 14, 12, PULSE_L1, BLUE)
if WORLD1:
    node('SpikesPitSaw', 'Node2D', 'spikes', 17.7, 14.5, width_tiles='2.2')
    # пила ходит над ямой на высоте прыжка: прыгать в просвет
    node('SawOverPit', 'Node2D', 'saw', 16.9, 10.5, radius_tiles='0.45', path_tiles='Vector2(1.6, 0)', speed='150.0')
    gate_l('GateL2', 18.8, 'ButtonU2', GREEN)
else:
    node('SpikesBelt', 'Node2D', 'spikes', 15.2, 14.5, width_tiles='0.8')
    node('BeltL', 'StaticBody2D', 'belt', 15.6, 12, width_tiles='6.0', speed='-560.0')
    gate_l('GateL2', 21.6, 'ButtonU2', GREEN)
button('ButtonL2', 23.6, 12, PULSE_L2, PURPLE)
floor_saw('SawL', 27.4, 12, 2.8)
gate_l('GateL3', 31, 'ButtonU3', YELLOW, 900.0)  # быстро в пол: прыгают в него сразу за пилой
button('ButtonL3', 33, 12, PULSE_L3, TEAL)
node('SpikesPit1', 'Node2D', 'spikes', 35.3, 14.5, width_tiles='1.8')
node('SpikesPit2', 'Node2D', 'spikes', 38.1, 14.5, width_tiles='1.8')
gate_l('GateL4', 39, 'ButtonU4', PINK)
button('ButtonL4', 41, 12, PULSE_L4, WHITE)
if WORLD1:
    floor_saw('SawL2', 43.2, 12, 3.0)  # навстречу; сразу за ней — яма у ворот
    node('SpikesPit3', 'Node2D', 'spikes', 47.5, 14.5, width_tiles='1.0')
else:
    node('BeltL2', 'StaticBody2D', 'belt', 42.5, 12, width_tiles='4.0', speed='480.0')
    node('SpikesPit3', 'Node2D', 'spikes', 47.25, 14.5, width_tiles='1.5')
gate_l('GateL5', 48, 'ButtonU5', LIME)
button('ButtonL5', 49.6, 12, PULSE_L5, BROWN)
button('ButtonL6', 52, 12, EXIT_PULSE, RED)
# Выход: обе красные кнопки в одно окно — ворота во всю высоту открываются насовсем.
node('Exit', 'AnimatableBody2D', 'door', 55, 3, size_tiles='Vector2(1, 9)', triggers=paths('ButtonU6', 'ButtonL6'),
     require_all='true', stay_open='true', open_offset_tiles='Vector2(0, -8.5)', mark_color=RED)
node('Finish', 'Node2D', 'finish', 58.5, 12)
if CHASE:
    node('Crusher', 'Node2D', 'crusher', -2.5, -8, height_tiles='27.0', speed=f'{CRUSHER_SPEED}',
         start_x_tiles='6.5', stop_x_tiles='56.0', catch_up_tiles=f'{CATCH_UP}')

import backdrop
W02_GROUND = 'ground_fill = "w02_fill"\nground_deep = "w02_deep"\nground_top = "w02_top"\nground_side = "w02_side"\n'
BD_ZONE, BD_LM = ('pass', 'w01_v2_lm25_pass_towers.png') if CHASE else ('viaduct', 'w01_v2_lm18_twin_towers.png')

head = f'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]
{backdrop.resources(BD_ZONE, BD_LM) if WORLD1 else '[ext_resource type="PackedScene" path="res://levels/backdrops/w02_scaffolds.tscn" id="bd"]'}
[ext_resource type="Script" path="res://src/mechanisms/pressure_plate.gd" id="plate"]
[ext_resource type="Script" path="res://src/mechanisms/door.gd" id="door"]
[ext_resource type="Script" path="res://src/mechanisms/saw.gd" id="saw"]
[ext_resource type="Script" path="res://src/mechanisms/press.gd" id="press"]
[ext_resource type="Script" path="res://src/mechanisms/spikes.gd" id="spikes"]
[ext_resource type="Script" path="res://src/mechanisms/conveyor.gd" id="belt"]
[ext_resource type="Script" path="res://src/mechanisms/finish.gd" id="finish"]
[ext_resource type="Script" path="res://src/mechanisms/crusher.gd" id="crusher"]

[node name="{'W01L18' if CHASE else 'W01L11' if WORLD1 else 'T06'}" type="Node2D"]
script = ExtResource("1")
title = "{'18 · Эстафета под обвалом' if CHASE else '11 · Эстафета' if WORLD1 else '06 · Эстафета'}"
blocks = Array[Rect2]([{', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in blocks)}])
checkpoints = Array[Vector2]([Vector2(3, 12)])
bounds_tiles = Rect2(0, -8, 62, 27)
kill_y_tiles = 19.0
{backdrop.ground(BD_ZONE) if WORLD1 else W02_GROUND}'''
tail = backdrop.tail(BD_ZONE, BD_LM, 62) if WORLD1 else '[node name="Backdrop" parent="." instance=ExtResource("bd")]\n'
out = Path(__file__).resolve().parents[2] / ('levels/w01_l18_relay_chase.tscn' if CHASE else 'levels/w01_l11_relay.tscn' if WORLD1 else 'levels/trial/t06_relay.tscn')
out.write_text(head + '\n' + '\n'.join(nodes) + '\n' + tail, encoding='utf-8')
print('written', out)
