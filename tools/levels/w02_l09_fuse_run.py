"""Генератор уровня мира 2 «09 · Бегущий фитиль» (очень сложный, на скорость).
Защёлка открывает дверь впереди — и шлёт искру по длинному проводу к бочонку под мостом, по которому
надо пройти. Искры у генератора выбегают часто (короткий провод до развилки, малая пауза): фитиль
загорается почти сразу после нажатия. Пока искра бежит (FUSE1/FUSE2 тайлов провода) — перейти мост:
пилы по настилу, прыжки; на втором мосту — дверь на кнопке-импульсе: один держит, другой проходит
и жмёт кнопку за дверью для первого. Мост рушится — кто на нём, падает на шипы (рестарт с чекпоинта).
Запуск: python tools/levels/w02_l09_fuse_run.py → levels/w02_l09_fuse_run.tscn"""
from w2common import Level, COLORS, paths, path, pts

FUSE1 = 14.0   # длина провода от развилки до бочонка 1 (тайлы); искра — 220 px/с ≈ 3,4 тайла/с
FUSE2 = 17.8   # петля провода 2: туда и обратно над мостом (вся длина ≈ FUSE2 + 7,2)
DOOR_PULSE = 0.8

lv = Level('W02L09', '09 · Бегущий фитиль', 72, 'forge', 'w02_lm09_powder_store.png')
lv.block(0, 12, 8, 6)
# Этап 1: защёлка T1 — дверь D1 за мостом открыта, искра — к бочонку под мостом 1.
lv.node('T1', 'plate', 6, 12, width_tiles='1.5', latch='true', mark_color=COLORS['orange'])
lv.node('Bridge1', 'cracked', 8, 12, size_tiles='Vector2(18, 1)')
lv.block(8, 15, 18, 3)
lv.node('Spikes1', 'spikes', 17, 15, width_tiles='18.0')
lv.node('K1', 'keg', 17, 12, walls=paths('Bridge1'))
lv.node('Saw1a', 'saw', 11, 12 - 50 / 64, radius_tiles='0.4', path_tiles='Vector2(3, 0)', speed='200.0')
lv.node('Saw1b', 'saw', 20, 12 - 50 / 64, radius_tiles='0.4', path_tiles='Vector2(3, 0)', speed='200.0', start_at='0.5')
lv.block(26, 12, 10, 6)
lv.block(32, -8, 1, 16)
lv.node('D1', 'door', 32, 8, size_tiles='Vector2(1, 4)', triggers=paths('T1'), open_offset_tiles='Vector2(0, -3.5)',
        mark_color=COLORS['orange'])
# провод 1: генератор — развилка (стрелка T1) — земля или к бочонку K1
lv.node('G1', 'wire', None, None, points=pts((5, 6), (5.5, 6)), next=paths('G1ground', 'Fuse1'), switches=paths('T1'))
lv.node('G1ground', 'wire', None, None, points=pts((5.5, 6), (5.5, 5)), grounded='true')
lv.node('Fuse1', 'wire', None, None, points=pts((5.5, 6), (5.5 + FUSE1 - 5.2, 6), (5.5 + FUSE1 - 5.2, 6.4)),
        next=paths('Fuse1b'))
lv.node('Fuse1b', 'wire', None, None, points=pts((5.5 + FUSE1 - 5.2, 6.4), (17, 6.4), (17, 11.2)), target=path('K1'))
lv.node('Spark1', 'spark', None, None, wire=path('G1'), respawn_time='0.3')
# Этап 2: защёлка T2 — дверь D3 на выходе открыта, искра — к бочонку под мостом 2; на мосту — дверь D2
# на кнопках-импульсах B2a (перед ней) и B2b (за ней).
lv.node('T2', 'plate', 35, 12, width_tiles='1.5', latch='true', mark_color=COLORS['teal'])
lv.node('Bridge2', 'cracked', 36, 12, size_tiles='Vector2(22, 1)')
lv.block(36, 15, 22, 3)
lv.node('Spikes2', 'spikes', 47, 15, width_tiles='22.0')
lv.node('K2', 'keg', 33.5, 12, walls=paths('Bridge2'))  # за защёлкой: нажал — беги
lv.node('B2a', 'plate', 42, 12, width_tiles='1.0', pulse=f'{DOOR_PULSE}', mark_color=COLORS['pink'])
lv.block(47, -8, 1, 16)
lv.node('D2', 'door', 47, 8, size_tiles='Vector2(1, 4)', triggers=paths('B2a', 'B2b'), open_offset_tiles='Vector2(0, -3.5)',
        open_speed='900.0', mark_color=COLORS['pink'])
lv.node('B2b', 'plate', 50.5, 12, width_tiles='1.0', pulse=f'{DOOR_PULSE}', mark_color=COLORS['pink'])
lv.node('Saw2', 'saw', 53, 12 - 50 / 64, radius_tiles='0.4', path_tiles='Vector2(3, 0)', speed='220.0', start_at='1.0', start_forward='false')
lv.block(58, 12, 13, 6)
lv.block(62, -8, 1, 16)
lv.node('D3', 'door', 62, 8, size_tiles='Vector2(1, 4)', triggers=paths('T2'), open_offset_tiles='Vector2(0, -3.5)',
        mark_color=COLORS['teal'])
lv.node('G2', 'wire', None, None, points=pts((34, 6), (34.5, 6)), next=paths('G2ground', 'Fuse2'), switches=paths('T2'))
lv.node('G2ground', 'wire', None, None, points=pts((34.5, 6), (34.5, 5)), grounded='true')
lv.node('Fuse2', 'wire', None, None, points=pts((34.5, 6), (34.5 + FUSE2 / 2, 6), (34.5 + FUSE2 / 2, 5.5), (33.5, 5.5),
        (33.5, 11.2)), target=path('K2'))
lv.node('Spark2', 'spark', None, None, wire=path('G2'), respawn_time='0.3')
lv.node('Finish', 'finish', 67, 12)
lv.checkpoints = [(2, 12), (29, 12)]
lv.write('w02_l09_fuse_run.tscn')
