"""Генератор уровня мира 2 «20 · Большая машина» (финал мира: босс в три фазы; третья переделка: «босса
даже не почувствовали»; мерило — очень сложный уровень проходится не быстрее 10 минут).

Босс — «Большая машина» (src/mechanisms/big_machine.gd): морда на стене с пастью-воротами, глаза следят
за героями, слабые точки текущей волны она подсвечивает прицелами. Бьёт кулаками (src/mechanisms/fist.gd):
молот на рельсе под потолком едет за своей добычей, тень на полу — замах, удар до пола, застревает на
миг — на застрявший кулак можно запрыгнуть, как на ступеньку. С каждым попаданием кулаки злее.
Чекпоинты — только в начале фаз.

1. Кулаки (арена 1–35). Два кулака: один охотится за А, другой за Б. Слабые точки — кнопки (держат
   0,3 с): по две за волну, в одно окно. Четыре волны:
   - обе на полу по разные стороны;
   - на полу справа от середины и на правом уступе (уступ — только с застрявшего кулака);
   - после второго попадания середина арены проваливается в шипы (пасть открылась — пол поднялся); третья пара — на среднем уступе над
     провалом (с кулака, застрявшего у края провала) и снова на правом уступе;
   - четвёртая — на левом уступе (через провал: с кулака на средний уступ, вниз, снова кулак у уступа)
     и на полу справа.
2. Нутро (39–64), два яруса. Внизу лента к пасти и кулак: тяжёлый ящик (только вдвоём) толкать против
   ленты между ударами; ящик под кулаком — подпорка. Ящик — на подъёмник. Подъёмник поднят, пока включён
   рычаг внизу или рычаг наверху: поднять и груз, и обоих (подумать, кто где и когда переключает). Наверху второй
   кулак; ящик вдвоём — на ядро в дальнем конце.
3. Бегство (64–139). Машина разваливается, сзади обвал, сверху последний кулак: осыпающийся мосток,
   трапеция над шипами, прыжок на порыве ветра, осыпь, ворота на беличьем колесе — один крутит, второй
   пробегает; крутивший выпрыгивает и успевает на маховике.

Запуск: python tools/levels/w02_l20_big_machine.py → levels/w02_l20_big_machine.tscn"""
from w2common import Level, COLORS, paths, path, vec

lv = Level('W02L20', '20 · Большая машина', 140, 'machine', 'w02_lm20_machine_core.png')
red, yellow, purple, blue, green = COLORS['red'], COLORS['yellow'], COLORS['purple'], COLORS['blue'], COLORS['green']

# --- 1. Арена (1–35) ---
lv.block(1, -8, 34, 7)                  # потолок (низ −1)
lv.block(1, 12, 12, 6)
lv.block(22, 12, 13, 6)
lv.block(13, 16, 9, 2)
lv.node('PitArena', 'spikes', 17.5, 16, width_tiles='9.0')
lv.node('Gate2', 'machine_gate', None, None, machine=path('Machine'), phase_at='1', wave_at='2')
lv.node('ArenaFloor', 'door', 13, 12, size_tiles=vec(9, 1), triggers=paths('Gate2'), open_offset_tiles=vec(0, 4),
        open_speed='120.0', mark_color=red)
lv.block(1, 8, 5.5, 1)                  # левый уступ
lv.block(29.5, 8, 5, 1)                 # правый уступ
lv.block(15.5, 8, 5, 1)                 # средний уступ над провалом (5 — чтобы на нём увернуться)
for name, x, y in (('F1', 8, 12), ('F2', 27, 12), ('F3', 24, 12), ('H1', 4, 8), ('H2', 32, 8), ('H3', 18, 8)):
    lv.node(f'Weak{name}', 'plate', x, y, width_tiles='1.0', pulse='0.3', mark_color=red)
lv.node('FistA', 'fist', 8, 0, x_min='2.0', x_max='34.0', floor_y='12.0', prey='0', phase='1')
lv.node('FistB', 'fist', 25, 0, x_min='2.0', x_max='34.0', floor_y='12.0', prey='1', phase='1')

# Стена машины (35–39) с пастью-воротами.
lv.block(35, -8, 4, 16)
lv.block(35, 12, 4, 6)
lv.node('Mouth', 'door', 35, 8, size_tiles=vec(4, 4), triggers=paths('Machine'), open_offset_tiles=vec(0, -4),
        mark_color=red)
lv.node('Machine', 'big_machine', 37, 8, face_tiles=vec(8, 6),
        weak_spots=paths('WeakF1', 'WeakF2', 'WeakF3', 'WeakH2', 'WeakH3', 'WeakH2', 'WeakH1', 'WeakF2'),
        wave_sizes='Array[int]([2, 2, 2, 2])',
        fists=paths('FistA', 'FistB', 'FistLow', 'FistTop', 'FistRun'), fist_rage='0.2', core=path('Core'))

# --- 2. Нутро (39–64): нижний ярус (пол 12, потолок 6,5) и верхний (пол 5) ---
lv.block(39, -8, 25, 1)                 # потолок верхнего яруса (низ −7)
lv.block(39, 5, 19, 1.5)                # перекрытие между ярусами 39–58 (верх 5)
lv.block(61, 5, 3, 1.5)                 # перекрытие справа от шахты подъёмника (61–64)
lv.block(39, 12, 2, 6)
lv.block(41, 12.375, 14, 5.625)
lv.node('Belt', 'conveyor', 41, 12, width_tiles='14.0', speed='-60.0')
lv.block(55, 12, 3, 6)
lv.block(58, 12.5, 3, 5.5)              # шахта подъёмника (3 — ящик и герой рядом)
lv.block(61, 12, 3, 6)
lv.node('Heavy', 'crate', 42, 12 - 0.375 - 31 / 64, mass='2.0')
lv.node('FistLow', 'fist', 46, 6.5, x_min='41.0', x_max='57.0', floor_y='12.0', prey='-1', phase='2',
        track_speed='200.0', stuck_time='1.0')
lv.node('Lift', 'door', 58, 12, size_tiles=vec(3, 0.5), triggers=paths('LiftDown', 'LiftUp'),
        open_offset_tiles=vec(0, -7), open_speed='150.0', close_speed='150.0', mark_color=blue)
lv.node('LiftDown', 'lever', 62.7, 12, mark_color=blue)
lv.node('LiftUp', 'lever', 62.7, 5, mark_color=blue)
lv.node('Core', 'plate', 41, 5, width_tiles='2.0', threshold='2.0', mark_color=yellow)
lv.node('FistTop', 'fist', 50, -3, x_min='40.0', x_max='56.5', floor_y='5.0', prey='-1', phase='2',
        track_speed='220.0')
lv.block(64, -8, 1, 9)                  # стена над дверью нутра (проём 1–5 — дверь)
lv.node('Gut', 'door', 64, 1, size_tiles=vec(1, 4), triggers=paths('Core'), stay_open='true',
        open_offset_tiles=vec(0, -4), mark_color=yellow)

# --- 3. Бегство (65–139), пол 12, потолок −1; площадки между испытаниями — не меньше 5–6 тайлов:
# вдвоём увернуться от кулака ---
lv.block(65, -8, 74, 7)
lv.block(64, 5, 4, 13)                  # выход из нутра — на уступ 64–68 (верх 5), с него вниз
lv.block(68, 12, 6, 6)                  # куда приземляешься с уступа (пролетаешь ~3 тайла)
lv.block(74, 16, 3, 2)
lv.node('PitR1', 'spikes', 75.5, 16, width_tiles='3.0')
lv.node('CrumbleR1', 'brittle', 74, 12, width_tiles='3.0', crumble_time='1.0')
lv.block(77, 12, 6, 6)
# трапеция над шипами 83–95
lv.block(83, 16, 12, 2)
lv.node('PitR2', 'spikes', 89, 16, width_tiles='12.0')
lv.node('Trapeze', 'mover', 83, 12, size_tiles=vec(3, 0.5), path_tiles=vec(9, 0), speed='260.0', pause='1.2')
lv.block(95, 12, 6, 6)
# порыв: пропасть 101–108, ветер по такту
lv.block(101, 16, 7, 2)
lv.node('PitR3', 'spikes', 104.5, 16, width_tiles='7.0')
lv.node('WindR', 'bellows', 101, 9.5, length_tiles='8.0', height_tiles='6.0', gust_time='1.0', auto_period='2.2')
lv.node('WindL', 'bellows', 108, 9.5, direction='-1', length_tiles='8.0', height_tiles='6.0', gust_time='1.0',
        auto_period='2.2', auto_offset='1.1')
lv.block(108, 12, 5, 6)
lv.block(113, 16, 3, 2)
lv.node('PitR4', 'spikes', 114.5, 16, width_tiles='3.0')
lv.node('CrumbleR4', 'brittle', 113, 12, width_tiles='3.0', crumble_time='1.0')
lv.block(116, 12, 23, 6)
# ворота на колесе
lv.node('WheelGate', 'wheel', 122.5, 11, mark_color=green, coast_time='1.6')
lv.block(121, 11, 3, 1)
lv.block(127, -8, 1, 16)
lv.node('ExitGate', 'door', 127, 8, size_tiles=vec(1, 4), triggers=paths('WheelGate'), open_offset_tiles=vec(0, -4),
        close_speed='900.0', mark_color=green)
lv.node('FistRun', 'fist', 70, 0, x_min='66.0', x_max='126.0', floor_y='12.0', prey='-1', phase='3',
        track_speed='300.0', stuck_time='0.8', wind_time='0.5')
lv.node('Finish', 'finish', 134, 12)
lv.node('Crusher', 'crusher', 64, -8, height_tiles='27.0', speed='110.0', start_x_tiles='78.0',
        stop_x_tiles='117.0', catch_up_tiles='12.0', catch_up_speed='220.0')

lv.checkpoints = [(3, 12), (40, 12), (66, 5)]
lv.write('w02_l20_big_machine.tscn')
