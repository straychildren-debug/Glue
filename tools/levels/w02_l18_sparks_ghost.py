"""Генератор уровня мира 2 «18 · Искры и призрак» (очень сложный, на скорость; четвёртая версия: «крутой
уровень, где бежишь в темноте, но проходится довольно быстро» — мерило теперь 20 «Большая машина»).

Изюминка — тёмный цех (src/level/darkness.gd): свет только от искр, фонаря и слабое свечение героев.
Сзади призрак: летит, пока на него не смотрят, — а в темноте взгляд не помогает, его надо осветить
(needs_light). Фонарь на крюке у старта: светит на 4,5 тайла вокруг того, кто его взял. Свечение
героев призрака не освещает (Darkness.is_lit). Ямы с шипами видно только в свете.

Чекпоинты — только в начале фаз (как в 20): старт, ярусы, сквозняк (сквозняк и бегство — одна фаза).
1. За руку (0–58). Передний держит заднего за руку и потому смотрит на него — и на призрака; фонарь у
   переднего. Три провода с искрами (последняя быстрее бега), яма и сразу осыпь над шипами — прыгать
   вдвоём, не расцепляясь; на осыпи не стоять.
2. Один фонарь на двоих (58–107). Два яруса, на каждом свой призрак и искры; призрак замирает, только
   если освещён, — держащему фонарь (внизу) идти вровень с товарищем. Две ямы — одна над другой: в полу
   верхнего яруса провал прямо над шипами нижнего — прыгать вдвоём в одно место.
3. Сквозняк (107–149). Фонарь гаснет (Lantern.draft_tiles); светят только искры на проводах под низким
   потолком. Четыре двери по такту (Clock): ждать у закрытой, а призрак сзади замирает, только когда
   мимо пробегает искра, — или замереть самим.
4. Бегство в темноте (149–223), без чекпоинта после сквозняка. Фонарь снова горит, сзади обвал: ямы
   видно только в круге фонаря, навстречу по полу бегут искры, осыпи над шипами. Отставший бежит в
   темноте — держаться вплотную за фонарём.

Запуск: python tools/levels/w02_l18_sparks_ghost.py → levels/w02_l18_sparks_ghost.tscn"""
from w2common import Level, path, pts, paths, vec

W = 223
lv = Level('W02L18', '18 · Искры и призрак', W, 'machine', 'w02_lm18_lightning_tower.png')
lv.node('Darkness', 'darkness', None, None)


def floor_with_pits(x0, x1, pits, y=12):
    """Пол от x0 до x1 с ямами (x, ширина): в яме шипы на дне (16)."""
    x = x0
    for i, (px, pw) in enumerate(pits):
        lv.block(x, y, px - x, 18 - y)
        lv.block(px, 16, pw, 2)
        yield px, pw
        x = px + pw
    lv.block(x, y, x1 - x, 18 - y)


def spark_wire(name, x0, x1, y, speed, **wire):
    lv.node(f'Wire{name}', 'wire', None, None, points=pts((x0, y), (x1, y)), **wire)
    lv.node(f'Spark{name}', 'spark', None, None, wire=path(f'Wire{name}'), speed=f'{speed}',
            **({'respawn_time': '0.6'} if wire else {}))


# --- 1. За руку (0–58) ---
pits1 = [(43, 1.5), (46, 3)]
for i, (px, pw) in enumerate(floor_with_pits(0, 58, pits1)):
    lv.node(f'Pit1{i}', 'spikes', px + pw / 2, 16, width_tiles=f'{pw}')
# сразу за ямой — осыпь над второй: на неё надо ступить, но не стоять
lv.node('Crumble1', 'brittle', 46, 12, width_tiles='3.0', crumble_time='0.8')
lv.node('Lantern', 'lantern', 4.5, 11.2, draft_tiles='Rect2(107, 5, 42, 8)')
lv.node('Ghost', 'ghost', 1.5, 9.5, area_tiles='Rect2(1, 2, 49, 10)', needs_light='true', max_speed='290.0')
for i, (x0, x1, speed) in enumerate([(9, 17, 300.0), (20, 29.5, 340.0), (33, 42, 380.0)]):
    spark_wire(str(i + 1), x0, x1, 11.6, speed)
lv.block(50, -8, 1, 17)          # проход в 3 тайла: призрак дальше не летит (его поле до 50)

# --- 2. Один фонарь на двоих (58–107): низ — пол 12, верх — 8,5. Каждый оборачивается на своего
# призрака, но освещён тот, только если рядом фонарь. Ямы одна над другой: прыгать вдвоём. ---
O, L = 58, 49
lv.block(O, -8, L, 13.5)                # потолок над ярусами (низ 5,5)
pits2 = [(O + 19, 2), (O + 37.5, 2)]
for i, (px, pw) in enumerate(floor_with_pits(O, O + L, pits2)):
    lv.node(f'Pit2{i}', 'spikes', px + pw / 2, 16, width_tiles=f'{pw}')
# пол верхнего (верх 8,5): провалы — прямо над ямами нижнего (упавший сверху — на шипы)
x = O + 5
for px, pw in pits2 + [(O + 47, 0)]:
    lv.block(x, 8.5, px - x, 0.5)
    x = px + pw
lv.block(O + 3.5, 10.25, 1.5, 0.5)      # полочка на верхний ярус (висит: нижний проходит под ней)
for name, x0, x1, y, speed in (('4', O + 5, O + 15, 11.6, 300.0), ('5', O + 22, O + 34, 11.6, 360.0),
                               ('6', O + 8, O + 18, 8.1, 330.0), ('7', O + 25, O + 36, 8.1, 390.0),
                               ('8', O + 40, O + 46.5, 11.6, 380.0), ('9', O + 40.5, O + 46.5, 8.1, 400.0)):
    spark_wire(name, x0, x1, y, speed)
# призраки ждут у входа и просыпаются, когда герои прошли дальше, — уже за спиной
lv.node('GhostU', 'ghost', O + 0.5, 7, area_tiles=f'Rect2({O}, 5.5, {L}, 3)', needs_light='true',
        max_speed='340.0', wake_x_tiles=f'{O + 7}')
lv.node('GhostL', 'ghost', O + 0.5, 10.2, area_tiles=f'Rect2({O}, 9, {L}, 3)', needs_light='true',
        max_speed='340.0', wake_x_tiles=f'{O + 7}')

# --- 3. Сквозняк (107–149): фонарь гаснет. Светят только искры на проводах под низким потолком (2,4
# тайла: не прыгать — искра над головой). Двери по такту: ждать у закрытой, а призрак сзади замирает,
# только когда мимо него пробегает искра. ---
D = O + L
lv.block(D, -8, 42, 17.6)               # низкий потолок (низ 9,6)
lv.block(D, 12, 42, 6)
for name, x0, x1, speed in (('10', D + 1, D + 15, 260.0), ('11', D + 13, D + 30, 300.0), ('12', D + 28, D + 41, 320.0)):
    spark_wire(name, x0, x1, 9.85, speed)
for i, x in enumerate([D + 7, D + 14, D + 21, D + 28]):
    lv.node(f'Clock{i + 1}', 'clock', None, None, period='5.6', open_time='1.6', offset=f'{i * 1.4:.1f}')
    lv.node(f'Gate{i + 1}', 'door', x, 9.6, size_tiles=vec(1, 2.4), triggers=paths(f'Clock{i + 1}'),
            open_offset_tiles=vec(0, 2.4), close_speed='600.0')
lv.node('Ghost3', 'ghost', D + 0.5, 10.2, area_tiles=f'Rect2({D}, 9.6, 30, 2.4)', needs_light='true',
        max_speed='250.0', wake_x_tiles=f'{D + 3}')

# --- 4. Бегство в темноте (149–223): фонарь снова горит, сзади обвал. Ямы видно только в свете,
# навстречу по полу бегут искры (провода заземлены: добежав, искра пропадает и выбегает снова). ---
R = D + 42
lv.block(R, -8, W - R, 7)               # потолок (низ −1)
pits4 = [(R + 5, 2), (R + 16, 4.5), (R + 24, 2), (R + 37, 2.5), (R + 41.5, 4.5), (R + 50, 2), (R + 62, 4.5), (R + 67.5, 2)]
for i, (px, pw) in enumerate(floor_with_pits(R, W, pits4)):
    lv.node(f'Pit4{i}', 'spikes', px + pw / 2, 16, width_tiles=f'{pw}')
lv.node('Crumble4a', 'brittle', R + 16, 12, width_tiles='4.5', crumble_time='0.9')
lv.node('Crumble4b', 'brittle', R + 41.5, 12, width_tiles='4.5', crumble_time='0.9')
lv.node('Crumble4c', 'brittle', R + 62, 12, width_tiles='4.5', crumble_time='0.8')
# навстречу: провод сверху вниз по столбу и по полу справа налево — искру видно издалека
lv.node('Wire13', 'wire', None, None, points=pts((R + 15, 6), (R + 15, 11.6), (R + 8, 11.6)), grounded='true')
lv.node('Spark13', 'spark', None, None, wire=path('Wire13'), speed='380.0', respawn_time='0.7')
lv.node('Wire14', 'wire', None, None, points=pts((R + 35.5, 6), (R + 35.5, 11.6), (R + 26.5, 11.6)), grounded='true')
lv.node('Spark14', 'spark', None, None, wire=path('Wire14'), speed='420.0', respawn_time='0.6')
lv.node('Wire15', 'wire', None, None, points=pts((R + 60, 6), (R + 60, 11.6), (R + 53, 11.6)), grounded='true')
lv.node('Spark15', 'spark', None, None, wire=path('Wire15'), speed='450.0', respawn_time='0.5')
lv.node('Crusher', 'crusher', R - 3, -8, height_tiles='27.0', speed='290.0', start_x_tiles=f'{R + 2}',
        stop_x_tiles=f'{W - 4}', catch_up_tiles='7.0', catch_up_speed='330.0')
lv.node('Finish', 'finish', W - 3, 12)
lv.checkpoints = [(4, 12), (O - 3, 12), (D - 2, 12)]
lv.write('w02_l18_sparks_ghost.tscn')
