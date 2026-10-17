"""Генератор уровня мира 2 «06 · Стрелочник» (сложный, на подумать, без таймера).
Искра бежит от генератора по развилкам: стрелки — плиты A, D, C (C — на двоих) и рычаг L.
Бочонки: K1 рушит стену W1, KB — мост над нижним коридором, K2 — стену W2 в коридоре у выхода.
Плита A — в радиусе K1: нажать её можно только замершим. Ящик стоит за стеной W1.
Выход — только вниз, через взорванный мост, и через W2. Решение (перебор tools/spark_puzzle.py,
31 ход, треть состояний — ловушки): замереть на A → W1; один встаёт на дальнюю D (иначе с рычагом
искра пойдёт к мосту), второй включает рычаг и везёт ящик через мост; на C — ящик и игрок → W2;
сойти с D — мост рушится; вниз и к выходу.
Запуск: python tools/levels/w02_l06_switchman.py → levels/w02_l06_switchman.tscn"""
from w2common import Level, COLORS, paths, path, pts

lv = Level('W02L06', '06 · Стрелочник', 50, 'forge', 'w02_lm06_switch_tower.png')
lv.bounds_h = 31
lv.kill_y = 22.0
# R1: старт, плита A в радиусе бочонка K1, треснувшая стена W1.
lv.block(0, 12, 12, 9)
lv.node('PlateA', 'plate', 9, 12, width_tiles='1.0', mark_color=COLORS['yellow'])
lv.node('K1', 'keg', 10.8, 12, walls=paths('W1'))
lv.block(12, -8, 1, 17)
lv.node('W1', 'cracked', 12, 9)
lv.block(12, 12, 1, 9)
# R2: ящик, рычаг L, бочонок у моста.
lv.block(13, 12, 8, 9)
lv.node('Crate', 'crate', 15.5, 12 - 31 / 64)
lv.node('LeverL', 'lever', 17.5, 12, mark_color=COLORS['blue'])
lv.node('KB', 'keg', 20.4, 12, walls=paths('Bridge'))
lv.node('Bridge', 'cracked', 21, 12, size_tiles='Vector2(6, 1)')
# R3: плиты D и C (на двоих) над нижним коридором.
lv.block(27, 12, 13, 1)
lv.node('PlateD', 'plate', 30, 12, width_tiles='1.5', mark_color=COLORS['teal'])
lv.node('PlateC', 'plate', 35, 12, width_tiles='2.0', threshold='2.0', mark_color=COLORS['pink'])
lv.block(40, -8, 1, 21)
# Нижний коридор: под мостом вниз, стена W2 и выход.
lv.block(21, 18, 28, 3)
lv.block(41, -8, 8, 21)
lv.node('K2', 'keg', 42.2, 18, walls=paths('W2'))
lv.node('W2', 'cracked', 43, 13, size_tiles='Vector2(1, 5)')
lv.node('Finish', 'finish', 46.5, 18)
# Провода (над комнатами, y 6).
lv.node('WG', 'wire', None, None, points=pts((2, 6), (8, 6)), next=paths('ToJ2', 'ToK1'), switches=paths('PlateA'))
lv.node('ToK1', 'wire', None, None, points=pts((8, 6), (10.8, 6), (10.8, 11.2)), target=path('K1'))
lv.node('ToJ2', 'wire', None, None, points=pts((8, 6), (16, 6)), next=paths('Ground2', 'ToJ3'), switches=paths('LeverL'))
lv.node('Ground2', 'wire', None, None, points=pts((16, 6), (16, 4.5)), grounded='true')
lv.node('ToJ3', 'wire', None, None, points=pts((16, 6), (20.4, 6)), next=paths('ToKB', 'ToJ4'), switches=paths('PlateD'))
lv.node('ToKB', 'wire', None, None, points=pts((20.4, 6), (20.4, 11.2)), target=path('KB'))
lv.node('ToJ4', 'wire', None, None, points=pts((20.4, 6), (33, 6)), next=paths('Ground4', 'ToK2'), switches=paths('PlateC'))
lv.node('Ground4', 'wire', None, None, points=pts((33, 6), (33, 4.5)), grounded='true')
lv.node('ToK2', 'wire', None, None, points=pts((33, 6), (42.2, 6), (42.2, 17.2)), target=path('K2'))
lv.node('Spark', 'spark', None, None, wire=path('WG'))
lv.checkpoints = [(2, 12)]
lv.write('w02_l06_switchman.tscn')
