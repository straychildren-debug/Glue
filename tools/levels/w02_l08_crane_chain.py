"""Генератор уровня мира 2 «08 · Кран над настилом» (сложный, на ловкость рук).
Кран едет, пока включён рычаг на старте. Б висит на крюке; А включает рычаг и в прыжке ловит Б за руку —
цепь. На середине пути ходит вертикальная пила: нижнего в цепи она режет, если тронуться не в такт.
У дальнего края кран встаёт над ломким настилом (держит одного): нижний спрыгивает и сразу — на берег,
потом верхний. Вдвоём на настиле — рушится в шипы.
Запуск: python tools/levels/w02_l08_crane_chain.py → levels/w02_l08_crane_chain.tscn"""
from w2common import Level, COLORS, paths, path

lv = Level('W02L08', '08 · Кран над настилом', 42, 'forge', 'w02_lm08_gantry_crane.png')
lv.block(0, 12, 8, 6)
lv.node('Lever', 'lever', 5, 12, mark_color=COLORS['orange'])
lv.node('Crane', 'crane', 6.5, 5, length_tiles='21.0', hang_tiles='3.5', speed='130.0', trigger=path('Lever'))
lv.block(8, 15, 24, 3)
lv.node('Spikes', 'spikes', 20, 15, width_tiles='24.0')
lv.node('Saw', 'saw', 17.5, 14.5, radius_tiles='0.6', path_tiles='Vector2(0, -4.5)', speed='110.0')
lv.node('Brittle', 'brittle', 26, 12, width_tiles='4.0')
lv.block(32, 12, 9, 6)
lv.node('Finish', 'finish', 37, 12)
lv.checkpoints = [(2, 12)]
lv.write('w02_l08_crane_chain.tscn')
