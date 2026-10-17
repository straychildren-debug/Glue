"""Генератор уровня «Обвал»: восемь испытаний подряд под наезжающей стеной с шипами (Crusher),
без чекпоинтов. Запуск: python tools/levels/t07_rockfall.py          → levels/trial/t07_rockfall.tscn
                        python tools/levels/t07_rockfall.py --world1 → levels/w01_l16_rockfall.tscn
Мир 1 — без механизмов мастерских: вместо ветра плита на двоих (ящик и игрок на нём) с защёлкой
за дверью, вместо ломкого настила две пилы по полу, вместо пружины — ящик к стене 4,5 тайла."""
import sys
from pathlib import Path

WORLD1 = '--world1' in sys.argv

T = 64
ORANGE, RED, BLUE = 'Color(0.95, 0.6, 0.2, 1)', 'Color(0.9, 0.3, 0.3, 1)', 'Color(0.4, 0.7, 0.95, 1)'
CRUSHER_SPEED = 100.0  # px/с; запас у бота — в тесте (строки «обвал в N тайла»)
CRUSHER_START = -2.5   # где стоит передний край на старте, тайлы
CATCH_UP = 8.0         # дальше этого от отставшего (тайлы) обвал догоняет со скоростью 260 px/с
EXIT_PULSE = 0.35
SAW2_AT, SAW2_FWD = 0.5, True  # фаза второй пилы на бегу (подобрана прогоном бота)
GUST = 0.7             # порыв мехов, с: короче, чем добежать от педали до края (в одиночку не успеть)

blocks = [
    (0, -8, 1, 26), (101, -8, 1, 26),
    (0, 12, 26, 6),                  # 1–2: старт, стена, плита, пила, дверь
    (9, 8.5, 4, 3.5),                # 1: стена 3,5 тайла (верх y 8.5)
    (21, -8, 1, 16),                 # 2: над дверью — до неба
    (26, 15, 4.6, 3),                # 3: дно пропасти «ступенька в воздухе»
    (59, -8, 13, 14), (59, 6, 1, 3), (63, 6, 1, 3), (67, 6, 1, 3), (71, 6, 1, 3),  # 6: потолок и ниши прессов
    (85, 12, 16, 6),                 # 8: кнопки и выход
    (92, 10, 2, 0.5),                # 8: уступ с кнопкой (2 тайла над полом)
    (96, -8, 1, 16),                 # 8: над выходом — до неба
]
if WORLD1:
    blocks += [
        (30.6, 12, 44.4, 6),         # 4–7: плита на двоих, пилы, коридор прессов, ящик к стене
        (43.2, -8, 1, 16),           # 4: над дверью плиты на двоих — до неба
        (75, 7.5, 10, 10.5),         # 7: стена 4,5 тайла
    ]
else:
    blocks += [
        (30.6, 12, 6.4, 6),          # 3–4: берег, педаль у старта ветра
        (37, 15, 7, 3),              # 4: дно пропасти с ветром
        (44, 12, 5, 6),              # 4–5: дальний берег ветра, педаль
        (49, 15, 8, 3),              # 5: дно под ломким настилом
        (57, 12, 18, 6),             # 5–7: коридор прессов, площадка батута
        (75, 5.5, 10, 12.5),         # 7: скала 6,5 тайла
    ]

nodes = []
def node(name, kind, script, x, y, **props):
    lines = [f'[node name="{name}" type="{kind}" parent="."]', f'position = Vector2({x * T:g}, {y * T:g})',
             f'script = ExtResource("{script}")']
    lines += [f'{k} = {v}' for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')

def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'

# 2. Дверь с плитой и пилой
node('Plate', 'AnimatableBody2D', 'plate', 15, 12, width_tiles='1.5', mark_color=ORANGE)
node('Saw', 'Node2D', 'saw', 17.2, 12 - 50 / T, radius_tiles='0.4', path_tiles='Vector2(2.8, 0)', speed='240.0')
node('Door', 'AnimatableBody2D', 'door', 21, 8, size_tiles='Vector2(1, 4)', triggers=paths('Plate', 'PlateBack'),
     open_offset_tiles='Vector2(0, -3.5)', mark_color=ORANGE)
node('PlateBack', 'AnimatableBody2D', 'plate', 23.5, 12, width_tiles='1.5', mark_color=ORANGE)
# 3. Пропасть «ступенька в воздухе»
node('Spikes', 'Node2D', 'spikes', 28.3, 15, width_tiles='4.6')
if WORLD1:
    # 4. Плита на двоих: ящик на плиту, игрок на ящик — дверь; за дверью защёлка держит её открытой
    node('Crate1', 'CharacterBody2D', 'crate', 36.7, 12 - 31 / T)
    node('PlateTwo', 'AnimatableBody2D', 'plate', 38, 12, width_tiles='1.5', threshold='2.0', mark_color=BLUE)
    node('DoorTwo', 'AnimatableBody2D', 'door', 43.2, 8, size_tiles='Vector2(1, 4)', triggers=paths('PlateTwo'),
         keep_open=paths('LatchTwo'), open_offset_tiles='Vector2(0, -3.5)', mark_color=BLUE)
    node('LatchTwo', 'AnimatableBody2D', 'plate', 45.2, 12, width_tiles='1.5', latch='true', mark_color=BLUE)
    # 5. Две пилы по полу в одном такте — прыгать на бегу, одну за другой
    node('SawRun1', 'Node2D', 'saw', 48.2, 12 - 50 / T, radius_tiles='0.4', path_tiles='Vector2(3, 0)', speed='260.0')
    node('SawRun2', 'Node2D', 'saw', 52.8, 12 - 50 / T, radius_tiles='0.4', path_tiles='Vector2(3, 0)', speed='260.0',
         start_at=f'{SAW2_AT}', start_forward='true' if SAW2_FWD else 'false')
else:
    # 4. Ветер над пропастью: педаль на каждом берегу далеко от края
    node('PedalNear', 'AnimatableBody2D', 'plate', 31.8, 12, width_tiles='1.0', mark_color=BLUE)
    node('Bellows', 'Node2D', 'bellows', 37, 10.5, length_tiles='8.0', height_tiles='4.0', gust_time=f'{GUST}',
         pedal='NodePath("../PedalNear")', pedals=paths('PedalFar'))
    node('SpikesWind', 'Node2D', 'spikes', 40.5, 15, width_tiles='7.0')
    node('PedalFar', 'AnimatableBody2D', 'plate', 46.5, 12, width_tiles='1.0', mark_color=BLUE)
    # 5. Ломкий настил над шипами: держит одного
    node('Bridge', 'StaticBody2D', 'brittle', 49, 12, width_tiles='8.0')
    node('SpikesBridge', 'Node2D', 'spikes', 53, 15, width_tiles='8.0')
# 6. Коридор с прессами волной
# сдвиг волны = пробежка под одним прессом (4 тайла за 0,71 с): стартовал вовремя — бежишь насквозь
for i, delay in enumerate((0.0, 0.71, 1.42)):
    node(f'Press{i + 1}', 'AnimatableBody2D', 'press', 60 + 4 * i, 6, size_tiles='Vector2(3, 3)',
         top_wait='0.8', bottom_wait='0.3', start_delay=f'{delay}')
if WORLD1:
    # 7. Ящик к стене 4,5: на ящик — замерший, на него — товарищ, катапульта; затем вытянуть
    node('Crate2', 'CharacterBody2D', 'crate', 73.7, 12 - 31 / T)
else:
    # 7. Взведённая пружина у скалы
    node('Spring', 'StaticBody2D', 'spring', 74, 12, width_tiles='1.5')
# 8. Выход: две кнопки, одна на уступе
node('ButtonA', 'AnimatableBody2D', 'plate', 89, 12, width_tiles='1.0', pulse=EXIT_PULSE, mark_color=RED)
node('ButtonB', 'AnimatableBody2D', 'plate', 93, 10, width_tiles='1.0', pulse=EXIT_PULSE, mark_color=RED)
node('Exit', 'AnimatableBody2D', 'door', 96, 8, size_tiles='Vector2(1, 4)', triggers=paths('ButtonA', 'ButtonB'),
     require_all='true', stay_open='true', open_offset_tiles='Vector2(0, -3.5)', mark_color=RED)
node('Finish', 'Node2D', 'finish', 98.5, 12)
node('Crusher', 'Node2D', 'crusher', CRUSHER_START, -8, height_tiles='27.0', speed=f'{CRUSHER_SPEED}',
     start_x_tiles='7.0', stop_x_tiles='99.0', catch_up_tiles=f'{CATCH_UP}')

import backdrop
BD_ZONE, BD_LM = 'canyon', 'w01_v2_lm23_landslide.png'

head = f'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]
{backdrop.resources(BD_ZONE, BD_LM)}
[ext_resource type="Script" path="res://src/mechanisms/pressure_plate.gd" id="plate"]
[ext_resource type="Script" path="res://src/mechanisms/door.gd" id="door"]
[ext_resource type="Script" path="res://src/mechanisms/saw.gd" id="saw"]
[ext_resource type="Script" path="res://src/mechanisms/spikes.gd" id="spikes"]
[ext_resource type="Script" path="res://src/mechanisms/bellows.gd" id="bellows"]
[ext_resource type="Script" path="res://src/mechanisms/brittle_floor.gd" id="brittle"]
[ext_resource type="Script" path="res://src/mechanisms/press.gd" id="press"]
[ext_resource type="Script" path="res://src/mechanisms/spring_pad.gd" id="spring"]
[ext_resource type="Script" path="res://src/mechanisms/crusher.gd" id="crusher"]
[ext_resource type="Script" path="res://src/mechanisms/finish.gd" id="finish"]
[ext_resource type="Script" path="res://src/mechanisms/crate.gd" id="crate"]

[node name="{'W01L16' if WORLD1 else 'T07'}" type="Node2D"]
script = ExtResource("1")
title = "{'16' if WORLD1 else '07'} · Обвал"
blocks = Array[Rect2]([{', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in blocks)}])
checkpoints = Array[Vector2]([Vector2(3, 12)])
bounds_tiles = Rect2(0, -8, 102, 27)
kill_y_tiles = 19.0
{backdrop.ground(BD_ZONE) if WORLD1 else ''}'''
tail = backdrop.tail(BD_ZONE, BD_LM, 102)
out = Path(__file__).resolve().parents[2] / ('levels/w01_l16_rockfall.tscn' if WORLD1 else 'levels/trial/t07_rockfall.tscn')
out.write_text(head + '\n' + '\n'.join(nodes) + '\n' + tail, encoding='utf-8')
print('written', out)
