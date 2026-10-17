"""Генератор уровня мира 1 «15 · Разводной мост» (немного сложный): пропасть с шипами, столбы и
секции моста между ними. Секция поднимается из пропасти от кнопки на миг и уходит обратно — кто на
ней не успел, уезжает на шипы. У каждой секции по кнопке с двух сторон: один жмёт, другой бежит,
потом прошедший жмёт для первого. Окна к концу уже. Выход — две кнопки в одно окно.
Запуск: python tools/levels/w01_l15_drawbridge.py → levels/w01_l15_drawbridge.tscn"""
from pathlib import Path

T = 64
COLORS = ['Color(0.95, 0.6, 0.2, 1)', 'Color(0.4, 0.7, 0.95, 1)', 'Color(0.35, 0.8, 0.4, 1)',
          'Color(0.7, 0.45, 0.95, 1)', 'Color(0.95, 0.85, 0.3, 1)']
RED = 'Color(0.9, 0.3, 0.3, 1)'
DECK = 12           # верх берегов, столбов и поднятых секций
SUNK = 5.5          # на сколько секция уходит вниз — ниже шипов, в дно: по опущенной не пройти
# Столбы (x, ширина) и секции между ними; окна кнопок (с) по секциям — к концу уже.
BANK_END = 6
PILLARS = [(10, 4), (19, 4), (27, 4), (35, 4)]   # 4 тайла: кнопка «назад» слева, «вперёд» справа, между — место
FAR_BANK = 43
PULSES = [1.2, 1.25, 1.0, 0.9, 0.85]   # секция 2 — длиннее (5 тайлов); к концу запас тает
TWO_PULSE = 1.7
EXIT_PULSE = 0.3

blocks = [(0, -8, 1, 26), (53, -8, 1, 26), (0, DECK, BANK_END, 6), (FAR_BANK, DECK, 10, 6)]
for x, w in PILLARS:
    blocks.append((x, DECK, w, 6))
blocks.append((BANK_END, 17, FAR_BANK - BANK_END, 1))   # дно пропасти

nodes = []
def node(name, kind, script, x, y, **props):
    lines = [f'[node name="{name}" type="{kind}" parent="."]', f'position = Vector2({x * T:g}, {y * T:g})',
             f'script = ExtResource("{script}")']
    lines += [f'{k} = {v}' for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')

def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'

node('Spikes', 'Node2D', 'spikes', (BANK_END + FAR_BANK) / 2, 17, width_tiles=f'{FAR_BANK - BANK_END}')
# Опоры: берег (0..6), столбы, дальний берег. На опоре x: кнопка «назад» R — в x+1.6, «вперёд» L — в x+2.6;
# слева (x+0.5) — куда прибегают, справа (x+3.55) — откуда стартуют. На берегу кнопка L1 — в 4.6.
supports = [(0, BANK_END)] + PILLARS + [(FAR_BANK, 10)]
for i in range(5):
    x0 = supports[i][0] + supports[i][1]          # начало секции — правый край опоры
    x1 = supports[i + 1][0]                       # конец — левый край следующей
    color = COLORS[i]
    if PULSES[i] > 0.0:
        left_x = 4.6 if i == 0 else supports[i][0] + 2.6
        node(f'L{i + 1}', 'AnimatableBody2D', 'plate', left_x, DECK, width_tiles='1.0', pulse=f'{PULSES[i]}', mark_color=color)
        node(f'R{i + 1}', 'AnimatableBody2D', 'plate', x1 + 1.6, DECK, width_tiles='1.0', pulse=f'{PULSES[i]}', mark_color=color)
        trig = paths(f'L{i + 1}', f'R{i + 1}')
    else:
        node(f'Two{i + 1}', 'AnimatableBody2D', 'plate', supports[i][0] + 2.9, DECK, width_tiles='1.6', threshold='2.0',
             pulse=f'{TWO_PULSE}', mark_color=color)
        trig = paths(f'Two{i + 1}')
    # секция: мост, в покое — внизу, поднимается на SUNK тайлов вровень с опорами
    node(f'S{i + 1}', 'AnimatableBody2D', 'door', x0, DECK + SUNK, size_tiles=f'Vector2({x1 - x0}, 0.5)',
         triggers=trig, open_offset_tiles=f'Vector2(0, {-SUNK})', open_speed='900.0', close_speed='300.0',
         mark_color=color)
node('ExitA', 'AnimatableBody2D', 'plate', 45.5, DECK, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=RED)
node('ExitB', 'AnimatableBody2D', 'plate', 48, DECK, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=RED)
node('Exit', 'AnimatableBody2D', 'door', 49.5, DECK - 4, size_tiles='Vector2(1, 4)', triggers=paths('ExitA', 'ExitB'),
     require_all='true', stay_open='true', open_offset_tiles='Vector2(0, -3.5)', mark_color=RED)
blocks.append((49.5, -8, 1, 12))  # над выходом — до неба
node('Finish', 'Node2D', 'finish', 51.5, DECK)

import backdrop
BD_ZONE, BD_LM = 'river', 'w01_v2_lm19_drawbridge.png'

head = f'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]
{backdrop.resources(BD_ZONE, BD_LM)}
[ext_resource type="Script" path="res://src/mechanisms/pressure_plate.gd" id="plate"]
[ext_resource type="Script" path="res://src/mechanisms/door.gd" id="door"]
[ext_resource type="Script" path="res://src/mechanisms/spikes.gd" id="spikes"]
[ext_resource type="Script" path="res://src/mechanisms/finish.gd" id="finish"]

[node name="W01L15" type="Node2D"]
script = ExtResource("1")
title = "15 · Разводной мост"
blocks = Array[Rect2]([{', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in blocks)}])
checkpoints = Array[Vector2]([Vector2(3, 12), Vector2(27.3, 12)])
bounds_tiles = Rect2(0, -8, 54, 27)
kill_y_tiles = 19.0
{backdrop.ground(BD_ZONE)}'''
tail = backdrop.tail(BD_ZONE, BD_LM, 54)
out = Path(__file__).resolve().parents[2] / 'levels/w01_l15_drawbridge.tscn'
out.write_text(head + '\n' + '\n'.join(nodes) + '\n' + tail, encoding='utf-8')
print('written', out)
