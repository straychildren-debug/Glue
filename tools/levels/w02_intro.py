"""Генератор вводных уровней мира 2 «Мастерские» (решение 67: 3 вводных, 5 сложных, 12 очень сложных).
Каждый вводит три механизма мастерских, по участку на механизм, с щедрыми чекпоинтами:
01 «Лента и пружина» — конвейер, батут (табличка; взведённая пружина вдвоём), ломкий настил;
02 «Ветер и кран» — меха, кран-тележка, поворотная балка (мост от плит и вращающаяся);
03 «Искра и жук» — искра на проводе, стрелка и бочонок у треснувшей стены, жук-толкатель.
Запуск: python tools/levels/w02_intro.py → levels/w02_l01_belt_spring.tscn, w02_l02_wind_crane.tscn,
w02_l03_spark_beetle.tscn"""
from w2common import Level, COLORS, paths, path, pts, text

SPRING_HINT = ('Батут: прыгни на него — подбросит выше обычного; упадёшь с высоты — ещё выше.\\n'
               'Взведённая пружина: один встаёт на батут и замирает, второй забирается\\n'
               'ему на голову, первый оживает — взлетают оба, выше всего')


def level_01():
    lv = Level('W02L01', '01 · Лента и пружина', 61, 'yard', 'w02_lm01_conveyor_gallery.png')
    # 1. Лента-разгон: пропасть в 5 тайлов берётся только с разгона по ленте.
    lv.block(0, 12, 4, 6)
    lv.block(4, 12.375, 9, 5.625)
    lv.node('RideBelt', 'conveyor', 4, 12, width_tiles='9.0')
    # 2. Батут на полу — стена 3; на уступе батут — стена 6 (только взведённой пружиной).
    lv.block(18, 12, 7, 6)
    lv.node('Hint', 'hint', 20.3, 12, text=text(SPRING_HINT), radius_tiles='5.0')
    lv.node('Pad1', 'spring', 23, 12)
    lv.block(25, 9, 6.5, 9)
    lv.node('Pad2', 'spring', 29.5, 9)
    lv.block(31.5, 3, 4.5, 15)
    # 3. Два ломких настила над шипами — по одному.
    lv.block(36, 12, 2, 6)
    lv.node('Brittle1', 'brittle', 38, 12, width_tiles='5.0')
    lv.block(43, 12, 1, 6)
    lv.node('Brittle2', 'brittle', 44, 12, width_tiles='5.0')
    lv.block(38, 15, 11, 3)
    lv.node('Spikes', 'spikes', 43.5, 15, width_tiles='11.0')
    lv.block(49, 12, 11, 6)
    lv.node('Finish', 'finish', 55.5, 12)
    lv.checkpoints = [(2, 12), (19.5, 12), (37, 12)]
    lv.write('w02_l01_belt_spring.tscn')


def level_02():
    lv = Level('W02L02', '02 · Ветер и кран', 93, 'yard', 'w02_lm02_spring_press.png')
    # 1. Меха: пропасть в 8 тайлов — прыгает один, педаль жмёт другой; педаль на каждом берегу.
    lv.block(0, 12, 10, 6)
    lv.node('Pedal1', 'plate', 6, 12, width_tiles='1.5', mark_color=COLORS['teal'])
    lv.node('Bellows', 'bellows', 10, 11, length_tiles='10.0', height_tiles='5.0', pedal=path('Pedal1'),
            pedals=paths('Pedal2'))
    lv.block(18, 12, 18, 6)
    lv.node('Pedal2', 'plate', 22, 12, width_tiles='1.5', mark_color=COLORS['teal'])
    # 2. Кран над шипами: один на крюке, другой на плите; плита на каждом берегу.
    lv.node('CranePlate1', 'plate', 32, 12, width_tiles='1.5', mark_color=COLORS['orange'])
    lv.node('Crane', 'crane', 34.5, 5, length_tiles='13.0', hang_tiles='3.5', trigger=path('CranePlate1'),
            triggers=paths('CranePlate2'))
    lv.block(36, 13, 10, 5)
    lv.node('Spikes', 'spikes', 41, 13, width_tiles='10.0')
    lv.block(46, 12, 13.5, 6)
    lv.node('CranePlate2', 'plate', 52, 12, width_tiles='1.5', mark_color=COLORS['orange'])
    # 3. Мост-балка ложится, пока стоят на плите (по плите на берегу); вращающаяся балка.
    lv.node('BridgePlate1', 'plate', 57, 12, mark_color=COLORS['blue'])
    lv.node('Bridge', 'spinner', 62.5, 12.1875, length_tiles='6.0', base_deg='90.0', step_deg='-90.0',
            triggers=paths('BridgePlate1', 'BridgePlate2'))
    lv.block(65.5, 12, 8.5, 6)
    lv.node('BridgePlate2', 'plate', 68, 12, mark_color=COLORS['blue'])
    lv.node('Wheel', 'spinner', 78.5, 12.1875, length_tiles='7.0', spin_speed='25.0')
    lv.block(83, 12, 9, 6)
    lv.node('Finish', 'finish', 89, 12)
    lv.checkpoints = [(2, 12), (20, 12), (47, 12), (66.5, 12)]
    lv.write('w02_l02_wind_crane.tscn')


def level_03():
    lv = Level('W02L03', '03 · Искра и жук', 67, 'yard', 'w02_lm03_launch_tower.png')
    lv.block(0, 12, 45, 6)
    # 1. Искра бегает по проводу на полу: встречную перепрыгнуть, за уходящей не бежать.
    lv.node('Wire1', 'wire', None, None, points=pts((5, 11.6), (15.6, 11.6)))
    lv.node('Spark1', 'spark', None, None, wire=path('Wire1'), speed='200.0')
    # 2. Стрелка: пока кто-то на плите, искра бежит к бочонку у треснувшей стены, иначе — в землю.
    lv.node('Wire2', 'wire', None, None, points=pts((18, 8.5), (24, 8.5)), next=paths('ToGround', 'ToKeg'),
            switches=paths('Switch'))
    lv.node('ToGround', 'wire', None, None, points=pts((24, 8.5), (24, 5), (21, 5)), grounded='true')
    lv.node('ToKeg', 'wire', None, None, points=pts((24, 8.5), (28.5, 8.5), (28.5, 11.2)), target=path('Keg'))
    lv.node('Spark2', 'spark', None, None, wire=path('Wire2'))
    lv.node('Switch', 'plate', 21, 12, mark_color=COLORS['yellow'])
    lv.node('Keg', 'keg', 28.5, 12, walls=paths('Wall'))
    lv.block(30, -8, 1, 17)
    lv.node('Wall', 'cracked', 30, 9)
    lv.block(31, 11.5, 0.5, 0.5)  # упор: жук за взорванную стену не уходит, игрок перешагивает
    # 3. Жук: полка в 3 тайла — со спины жука; на дорожке над шипами жук спихивает — перепрыгнуть.
    lv.node('Beetle1', 'beetle', 41, 12 - 29 / 64)
    lv.block(45, 9.25, 3, 8.75)
    lv.block(48, 13, 10, 5)
    lv.node('Spikes', 'spikes', 53, 13, width_tiles='10.0')
    lv.block(48, 9.25, 4, 0.5)
    lv.block(54, 9.25, 4, 0.5)
    lv.node('Beetle2', 'beetle', 60, 9.25 - 29 / 64, direction='-1')
    lv.block(58, 9.25, 8, 8.75)
    lv.node('Finish', 'finish', 64, 9.25)
    lv.checkpoints = [(2, 12), (16.5, 12), (31.5, 12), (46.5, 9.25), (59, 9.25)]
    lv.write('w02_l03_spark_beetle.tscn')


level_01()
level_02()
level_03()
