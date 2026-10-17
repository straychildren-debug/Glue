"""Генератор уровня мира 1 «13 · Стесняшки» (немного сложный): три комнаты, в каждой свои призраки
(летят, пока на них никто не смотрит; у замершего глаза закрыты).
1 — ящик на плиту двери, призрак сзади: ящик едет медленнее призрака — толкающий держит товарища
    за руку и так смотрит назад;
2 — пропасть с шипами между двумя призраками: «ступенька в воздухе» и вытягивание за руку; кто
    смотрит на одного, тот спиной к другому;
3 — ворота на кнопках: нажимающий стоит лицом к призраку, пока товарищ пробегает; потом наоборот.
Запуск: python tools/levels/w01_l13_shy.py         → levels/w01_l13_shy.tscn
        python tools/levels/w01_l13_shy.py --chase → levels/w01_l17_ghosts_chase.tscn (очень сложный
        «Призраки и обвал»: те же комнаты без промежуточных чекпоинтов, слева ползёт обвал)"""
import sys
from pathlib import Path

CHASE = '--chase' in sys.argv
CRUSHER_SPEED = 50.0   # px/с; подбирается по боту (запас — строки «обвал в N тайла»)
CATCH_UP = 9.0

T = 64
BLUE, GREEN, RED = 'Color(0.4, 0.7, 0.95, 1)', 'Color(0.35, 0.8, 0.4, 1)', 'Color(0.9, 0.3, 0.3, 1)'
GATE_PULSE = 1.2  # окно честное (без дребезга кнопки на краю): бегущему ≈ 1 с

blocks = [
    (0, -8, 1, 26), (74, -8, 1, 26),
    (0, 12, 20, 6), (21.5, 12, 15.5, 6), (20, 13.03, 1.5, 4.97),  # комната 1 (выемка с плитой 20–21,5: ящик в неё падает) и начало комнаты 2
    (26.5, -8, 1, 16),         # над дверью 1
    (37, 15, 4.6, 3),          # пропасть комнаты 2 (дно с шипами)
    (41.6, 12, 32.4, 6),       # дальний берег, комната 3
    (52, -8, 1, 16),           # над дверью 2
    (64, -8, 1, 16),           # над воротами комнаты 3
]

nodes = []
def node(name, kind, script, x, y, **props):
    lines = [f'[node name="{name}" type="{kind}" parent="."]', f'position = Vector2({x * T:g}, {y * T:g})',
             f'script = ExtResource("{script}")']
    lines += [f'{k} = {v}' for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')

def paths(*names):
    return 'Array[NodePath]([' + ', '.join(f'NodePath("../{n}")' for n in names) + '])'

# 1. Ящик в выемку на плиту, призрак сзади
node('Ghost1', 'Node2D', 'ghost', 1.8, 10.8, area_tiles='Rect2(1, 2, 25.5, 10)')
node('Crate', 'CharacterBody2D', 'crate', 11, 12 - 31 / T)
node('Plate1', 'AnimatableBody2D', 'plate', 20.75, 13.03, width_tiles='1.5', mark_color=BLUE)  # нажатая — 4 px: ящик вровень с полом  # в выемке: ящик встанет вровень с полом
node('Door1', 'AnimatableBody2D', 'door', 26.5, 8, size_tiles='Vector2(1, 4)', triggers=paths('Plate1'),
     open_offset_tiles='Vector2(0, -3.5)', mark_color=BLUE)
# 2. Пропасть между двумя призраками; защёлка открывает дверь 2
node('Ghost2', 'Node2D', 'ghost', 28.3, 8.4, area_tiles='Rect2(27.5, 2, 24.5, 10)')
node('Ghost3', 'Node2D', 'ghost', 50.3, 11.3, area_tiles='Rect2(27.5, 2, 24.5, 10)')
node('Spikes2', 'Node2D', 'spikes', 39.3, 15, width_tiles='4.6')
node('Latch2', 'AnimatableBody2D', 'plate', 45.5, 12, width_tiles='1.5', latch='true', mark_color=GREEN)
node('Door2', 'AnimatableBody2D', 'door', 52, 8, size_tiles='Vector2(1, 4)', triggers=paths('Latch2'),
     open_offset_tiles='Vector2(0, -3.5)', mark_color=GREEN)
# 3. Ворота на кнопках, призрак у входа
node('Ghost4', 'Node2D', 'ghost', 53.6, 8.4, area_tiles='Rect2(53, 2, 21, 10)')
node('GateNear', 'AnimatableBody2D', 'plate', 58.5, 12, width_tiles='1.0', pulse=f'{GATE_PULSE}', mark_color=RED)
node('Gate', 'AnimatableBody2D', 'door', 64, 8, size_tiles='Vector2(1, 4)', triggers=paths('GateNear', 'GateFar'),
     open_offset_tiles='Vector2(0, -3.5)', mark_color=RED)
node('GateFar', 'AnimatableBody2D', 'plate', 66.5, 12, width_tiles='1.0', pulse=f'{GATE_PULSE}', mark_color=RED)
node('Finish', 'Node2D', 'finish', 71.5, 12)
if CHASE:
    node('Crusher', 'Node2D', 'crusher', 1.5, -8, height_tiles='27.0', speed=f'{CRUSHER_SPEED}',
         start_x_tiles='9.0', stop_x_tiles='70.0', catch_up_tiles=f'{CATCH_UP}')

import backdrop
BD_ZONE, BD_LM = ('shrine', 'w01_v2_lm24_buried_shrine.png') if CHASE else ('shrine', 'w01_v2_lm15_bell_crypt.png')

head = f'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/level/greybox_level.gd" id="1"]
{backdrop.resources(BD_ZONE, BD_LM)}
[ext_resource type="Script" path="res://src/mechanisms/pressure_plate.gd" id="plate"]
[ext_resource type="Script" path="res://src/mechanisms/door.gd" id="door"]
[ext_resource type="Script" path="res://src/mechanisms/ghost.gd" id="ghost"]
[ext_resource type="Script" path="res://src/mechanisms/crate.gd" id="crate"]
[ext_resource type="Script" path="res://src/mechanisms/spikes.gd" id="spikes"]
[ext_resource type="Script" path="res://src/mechanisms/finish.gd" id="finish"]
[ext_resource type="Script" path="res://src/mechanisms/crusher.gd" id="crusher"]

[node name="{'W01L17' if CHASE else 'W01L13'}" type="Node2D"]
script = ExtResource("1")
title = "{'17 · Призраки и обвал' if CHASE else '13 · Стесняшки'}"
blocks = Array[Rect2]([{', '.join(f'Rect2({a:g}, {b:g}, {c:g}, {d:g})' for a, b, c, d in blocks)}])
checkpoints = Array[Vector2]([{'Vector2(8, 12)' if CHASE else 'Vector2(8, 12), Vector2(33, 12), Vector2(56.5, 12)'}])
bounds_tiles = Rect2(0, -8, 75, 27)
kill_y_tiles = 19.0
{backdrop.ground(BD_ZONE)}'''
tail = backdrop.tail(BD_ZONE, BD_LM, 75)
out = Path(__file__).resolve().parents[2] / ('levels/w01_l17_ghosts_chase.tscn' if CHASE else 'levels/w01_l13_shy.tscn')
out.write_text(head + '\n' + '\n'.join(nodes) + '\n' + tail, encoding='utf-8')
print('written', out)
