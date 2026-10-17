"""Генератор уровня мира 2 «17 · Тяжёлый заказ» (очень сложный, на подумать; переделка после тестов).

Изюминка — доставка краном: грузовой кран с поддоном (Crane.pallet_tiles) везёт тяжёлый ящик
через пропасть. Один ведёт кран — стоит на плите (кран едет, пока плита нажата, отпустил —
возвращается); второй едет с грузом и на том берегу открывает люк поддона: ящик падает на плиту
выхода под концом пути крана.

1. Вдвоём закатить тяжёлый ящик (вес 2) с погрузочной площадки на поддон.
2. А на плите крана; Б на поддоне рядом с ящиком — через пропасть.
3. Б сходит, открывает люк — ящик на плите выхода, дверь открыта.
4. А отпускает плиту — кран возвращается. Подвох: люк ещё открыт — шагнёшь на поддон и упадёшь
   в пропасть. Б закрывает люк; А на поддоне; Б на плите крана на своём берегу — А переезжает.

Третья версия («лишь одна задачка и она быстро решается») — второй заказ, эстафета через остров:
5. Первым краном — на остров: один ведёт с плиты, второй едет с лёгким ящиком; на острове — своя плита
   первого крана: перевезти товарища.
6. Второй кран: оба ящика на поддон, один едет, второй ведёт с плиты на острове. Люк — рычагом на
   том берегу: ящики падают в колодец на весы (2) — ворота открыты.
7. Подвох: люк остался открытым — шагнувший на поддон дома падает в пропасть. Закрыть люк, кран домой,
   товарищ на поддон, с дальней плиты — к себе.
8. Третий заказ, срочный: кран под пилами. Тяжёлый ящик — щит (пила упирается в ящик и уходит вверх);
   ведущий с плиты водит поддон вперёд-назад между пилами; ящик — люком в колодец на весы. Второго
   везут уже без щита.
Чекпоинты — в начале каждого заказа.

Запуск: python tools/levels/w02_l17_heavy_order.py → levels/w02_l17_heavy_order.tscn"""
from w2common import Level, COLORS, paths, path, vec

lv = Level('W02L17', '17 · Тяжёлый заказ', 131, 'machine', 'w02_lm17_loading_dock.png')
crane_c, lid, exit_c = COLORS['yellow'], COLORS['orange'], COLORS['green']

# Левый берег: плита крана внизу, ступенька и погрузочная площадка (верх 9) с тяжёлым ящиком.
lv.block(1, 12, 9, 6)
lv.block(4, 10.5, 1.5, 1.5)
lv.block(5.5, 9, 4.5, 3)
lv.node('Heavy', 'crate', 8, 9 - 31 / 64, mass='2.0')
lv.node('CranePlate1', 'plate', 3, 12, width_tiles='1.5', mark_color=crane_c)

# Пропасть 10–26 и кран над ней: поддон вровень с площадкой (верх 9), от 11,5 до 27,5.
lv.block(10, 15, 16, 3)
lv.node('PitSpikes', 'spikes', 18, 15, width_tiles='16.0')
lv.node('Crane', 'crane', 11.5, 4, length_tiles='16.0', hang_tiles='5.0', speed='150.0', pallet_tiles='3.0',
        triggers=paths('CranePlate1', 'CranePlate2'), trapdoor=path('Lid'))

# Правый берег: лента под поддоном к плите выхода, рычаг люка, плита крана, дверь и выход.
lv.block(26, 12, 1.5, 6)
lv.block(27.5, 12, 17, 6)
lv.node('ExitPlate', 'plate', 29, 12, width_tiles='3.0', threshold='2.0', mark_color=exit_c)  # под концом поддона
lv.node('Lid', 'lever', 33.8, 12, mark_color=lid)
lv.node('CranePlate2', 'plate', 36, 12, width_tiles='1.5', mark_color=crane_c)
lv.block(37.5, -8, 1, 16)
lv.node('ExitDoor', 'door', 37.5, 8, size_tiles=vec(1, 4), triggers=paths('ExitPlate'), open_offset_tiles=vec(0, -4),
        mark_color=exit_c)

# 2. Эстафета через остров: два крана, два лёгких ящика; дальше — весы (2) в колодце под концом
# второго крана держат ворота. Краном правит тот, кто на его плите; переправиться надо обоим.
crane3_c, crane4_c, lid4, exit2_c = COLORS['blue'], COLORS['purple'], COLORS['pink'], COLORS['teal']
lv.node('CrateX', 'crate', 43.1, 12 - 31 / 64)  # подальше от плиты крана: подходя толкать, на неё не наступить
lv.node('CranePlate3', 'plate', 40.4, 12, width_tiles='1.5', mark_color=crane3_c)
lv.block(44.5, 15, 12, 3)
lv.node('PitSpikes2', 'spikes', 50.5, 15, width_tiles='12.0')
lv.node('Crane3', 'crane', 46, 7, length_tiles='9.0', hang_tiles='5.0', speed='150.0', pallet_tiles='3.0',
        triggers=paths('CranePlate3', 'CranePlate3b'))
lv.block(56.5, 12, 8, 6)                # остров 56,5–64,5
lv.node('CranePlate4', 'plate', 58.2, 12, width_tiles='1.0', mark_color=crane4_c)
lv.node('CranePlate3b', 'plate', 59.7, 12, width_tiles='1.0', mark_color=crane3_c)
lv.node('CrateY', 'crate', 66.9, 12 - 31 / 64)  # уже на поддоне второго крана
lv.block(64.5, 15, 9, 3)
lv.node('PitSpikes3', 'spikes', 69, 15, width_tiles='9.0')
lv.node('Crane4', 'crane', 66, 7, length_tiles='9.0', hang_tiles='5.0', speed='150.0', pallet_tiles='3.0',
        triggers=paths('CranePlate4', 'CranePlate4b'), trapdoor=path('Lid4'))
lv.block(73.5, 15, 3, 3)                # колодец под концом крана: весы на дне
lv.node('Scale', 'plate', 75, 15, width_tiles='3.0', threshold='2.0', mark_color=exit2_c)
lv.block(76.5, 12, 19.5, 6)            # берег до третьего заказа (до 96)
lv.node('CranePlate4b', 'plate', 78, 12, width_tiles='1.5', mark_color=crane4_c)
lv.node('Lid4', 'lever', 80.5, 12, mark_color=lid4)
lv.block(83, -8, 1, 16)
lv.node('ExitDoor2', 'door', 83, 8, size_tiles=vec(1, 4), triggers=paths('Scale'), open_offset_tiles=vec(0, -4),
        mark_color=exit2_c)

# 3. Срочный заказ — под пилами (84–131). Тяжёлый ящик вдвоём на поддон; кран через пропасть, поперёк
# пути — пять пил вверх-вниз до самого поддона, каждая со своим ходом. Пила режет и стоящего на поддоне;
# ящик — стопор: пила, упёршаяся в него, уходит вверх. Кран едет, пока плита нажата, отпустил — едет
# назад: ведущий с плиты «водит» поддон между пилами, ездок подсказывает. На том берегу люк — ящик в
# колодец на весы, ворота открыты. Потом перевезти второго — уже без ящика-щита.
saw_c, lid5, exit3_c = COLORS['red'], COLORS['orange'], COLORS['green']
lv.node('Heavy3', 'crate', 91.5, 12 - 31 / 64, mass='2.0')
lv.node('CranePlate5', 'plate', 86.5, 12, width_tiles='1.0', mark_color=COLORS['blue'])
lv.block(96, 15, 18, 3)
lv.node('PitSpikes4', 'spikes', 105, 15, width_tiles='18.0')
lv.node('Crane5', 'crane', 97.5, 3, length_tiles='18.0', hang_tiles='9.0', speed='150.0', pallet_tiles='3.0',
        triggers=paths('CranePlate5', 'CranePlate5b'), trapdoor=path('Lid5'))
for i, (x, speed, start) in enumerate([(100, 240.0, 0.0), (102.8, 320.0, 0.5), (105.6, 200.0, 0.2),
                                       (108.4, 290.0, 0.7), (111.2, 250.0, 0.4)]):
    lv.node(f'Saw{i + 1}', 'saw', x, 6, path_tiles=vec(0, 5.45), speed=f'{speed}', start_at=f'{start}')
lv.block(114, 15, 3, 3)                 # колодец под концом крана: весы на дне
lv.node('Scale3', 'plate', 115.5, 15, width_tiles='3.0', threshold='2.0', mark_color=exit3_c)
lv.block(117, 12, 14, 6)
lv.node('Lid5', 'lever', 119, 12, mark_color=lid5)
lv.node('CranePlate5b', 'plate', 121.5, 12, width_tiles='1.0', mark_color=COLORS['blue'])
lv.block(124, -8, 1, 16)
lv.node('ExitDoor3', 'door', 124, 8, size_tiles=vec(1, 4), triggers=paths('Scale3'), open_offset_tiles=vec(0, -4),
        mark_color=exit3_c)
lv.node('Finish', 'finish', 128, 12)

lv.checkpoints = [(1.5, 12), (39, 12), (84.5, 12)]
lv.write('w02_l17_heavy_order.tscn')
