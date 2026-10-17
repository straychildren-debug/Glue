"""Генератор уровня мира 2 «05 · Ветряк» (сложный, на ловкость рук).
1 — вращающаяся балка над шипами: вскочить, когда ровная, добежать до края и прыгнуть в порыв мехов;
    педаль жмёт товарищ на старте — в одно мгновение с прыжком (порыв 1 с); потом прыгает второй, а педаль
    жмёт уже перелетевший — на том берегу. Без порыва с балки не долететь.
2 — длинная вращающаяся балка в 2,5 тайла от краёв: запрыгнуть на неё в нужную фазу, пробежать и спрыгнуть.
Запуск: python tools/levels/w02_l05_windmill.py → levels/w02_l05_windmill.tscn"""
from w2common import Level, COLORS, paths, path

lv = Level('W02L05', '05 · Ветряк', 60, 'yard', 'w02_lm05_windmill_bellows.png')
teal = COLORS['teal']
lv.block(0, 12, 9, 6)
lv.node('PedalA', 'plate', 4, 12, width_tiles='1.5', mark_color=teal)
# 1. Балка над шипами и меха за ней; пропасть 9–23,5 (с балки без порыва — до ≈ 19,8).
lv.block(9, 15, 14.5, 3)
lv.node('Spikes1', 'spikes', 16.25, 15, width_tiles='14.5')
lv.node('Wheel1', 'spinner', 13, 12.1875, length_tiles='6.0', spin_speed='-20.0')
lv.node('Bellows', 'bellows', 16.5, 9.5, length_tiles='11.0', height_tiles='8.0', pedal=path('PedalA'),
        pedals=paths('PedalB'))
lv.block(23.5, 12, 13, 6)
lv.node('PedalB', 'plate', 30, 12, width_tiles='1.5', mark_color=teal)
# 2. Длинная вращающаяся балка: запрыгнуть с края (до неё 3 тайла), пробежать, спрыгнуть на берег.
lv.block(36.5, 15, 13, 3)
lv.node('Spikes2', 'spikes', 43, 15, width_tiles='13.0')
lv.node('Wheel2', 'spinner', 43, 12.1875, length_tiles='8.0', spin_speed='-18.0')
lv.block(49.5, 12, 9.5, 6)
lv.node('Finish', 'finish', 55.5, 12)
lv.checkpoints = [(2, 12), (25.5, 12)]
lv.write('w02_l05_windmill.tscn')
