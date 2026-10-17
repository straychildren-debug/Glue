"""Генератор уровня мира 2 «16 · Порыв» (очень сложный, на ловкость рук; переделка после тестов).

Изюминка — ветер меняет направление по такту: в каждой шахте двое мехов дуют навстречу по очереди
(auto_period, сдвиг на полтакта). Две шахты рядом — А лезет в левой, Б в правой, — и такт у них
разный: каждый следит за своим ветром, один человек за двоих не уследит.

Подъём зигзагом: полочки по очереди у левой и правой стены, каждая на 2 тайла выше; между ними
3,5 тайла — без попутного порыва не долететь, встречный посреди прыжка сдувает вниз, на шипы.
Полочки осыпаются через такт и ещё 0,6 с после шага: пропустил свой порыв — падаешь.
Старт и последняя полочка — у башни между шахтами; с последней — на башню.
С башни к выходу — маятником за руку: высокий крюк над верхом шахты Б, цепь из двоих, раскачка.

Третья версия («очень прикольный, но проходится быстро»):
3. Два коридора: А — верхним, Б — нижним; камни-осыпь, ветер в каждом меняет направление со своим
   тактом. Между камнями 3 тайла и низкий потолок: только с попутным порывом; встречный посреди
   прыжка — на шипы. Камень осыпается через такт: пропустил свой порыв — падаешь.
4. Общий коридор: оба на одних камнях — прыгать разом (отставший провалится: камень осыпается под
   обоими). С середины ветер чаще, камни сыплются быстрее.
Чекпоинты: старт, после маятника, перед общим коридором.

Запуск: python tools/levels/w02_l16_gust.py → levels/w02_l16_gust.tscn"""
from w2common import Level

lv = Level('W02L16', '16 · Порыв', 106, 'machine', 'w02_lm16_wind_tunnel.png')
lv.bounds_h = 30
lv.kill_y = 22.0
lv.slot_spawns = [(6.75, 12), (11.25, 12)]

TOWER = (7.5, 10.5)  # башня между шахтами
lv.block(1, -8, 6.5, 6)                 # потолок над шахтой А (низ на −2); над башней и шахтой Б — высокий
lv.block(7.5, -8, 21.5, 2)               # (низ на −6): там крюк маятника
lv.block(TOWER[0], 2, TOWER[1] - TOWER[0], 16)
lv.block(1, 15, 17, 3)
lv.node('SpikesA', 'spikes', 4.25, 15, width_tiles='6.5')
lv.node('SpikesB', 'spikes', 13.75, 15, width_tiles='6.5')


def shaft(tag, left, right, start_side, period, gust, crumble):
    """Шахта между стенами left..right: старт внизу у стены start_side, дальше полочки зигзагом
    до башни; меха у обеих стен дуют по очереди."""
    lv.block(left if start_side < 0 else right - 1.5, 12, 1.5, 3)  # стартовая полочка (твёрдая)
    side = -start_side
    y = 10
    i = 1
    while y >= 4:
        x = left if side < 0 else right - 1.5
        lv.node(f'Ledge{tag}{i}', 'brittle', x, y, width_tiles='1.5', crumble_time=f'{crumble}')
        side = -side
        y -= 2
        i += 1
    half = period / 2
    lv.node(f'Wind{tag}R', 'bellows', left, 7, length_tiles=f'{right - left:g}', height_tiles='10.0',
            gust_time=f'{gust}', auto_period=f'{period}', auto_offset='0.4')
    lv.node(f'Wind{tag}L', 'bellows', right, 7, direction='-1', length_tiles=f'{right - left:g}', height_tiles='10.0',
            gust_time=f'{gust}', auto_period=f'{period}', auto_offset=f'{0.4 + half:g}')


shaft('A', 1, TOWER[0], 1, 2.0, 1.0, 2.6)
shaft('B', TOWER[1], 17, -1, 1.6, 0.8, 2.2)
# Маятник за руку: с башни через верх шахты Б (6,5 тайла — не перепрыгнуть) на уступ выхода.
# Крюк высоко: с прыжка не достать, только с головы товарища; второй ловит его руку в прыжке —
# цепь, раскачка, нижний прыгает на уступ; верхний раскачивается один.
lv.block(17, 2, 10.5, 16)               # правая стена шахты Б и уступ после маятника (верх 2)
lv.node('Hook', 'hook', 11, -3)


GUST = '0.65'  # порыв в коридорах мягче: удлиняет прыжок на 3 тайла, но не уносит с камня


def corridor(tag, x0, x1, floor, stones, width, period, gust, crumble, offset=0.0):
    """Коридор с низким потолком (2,5 тайла над камнями) над шипами: камни-осыпь, ветер по такту
    навстречу-попутный. Между камнями 3 тайла: без попутного порыва не долететь."""
    for i, x in enumerate(stones):
        lv.node(f'Stone{tag}{i + 1}', 'brittle', x, floor, width_tiles=f'{width:g}', crumble_time=f'{crumble}')
    mid = floor - 1.25
    lv.node(f'Wind{tag}R', 'bellows', x0, mid, length_tiles=f'{x1 - x0:g}', height_tiles='2.4',
            gust_time=f'{gust}', auto_period=f'{period}', auto_offset=f'{offset:g}', strength=GUST)
    lv.node(f'Wind{tag}L', 'bellows', x1, mid, direction='-1', length_tiles=f'{x1 - x0:g}', height_tiles='2.4',
            gust_time=f'{gust}', auto_period=f'{period}', auto_offset=f'{offset + period / 2:g}', strength=GUST)


# 3. Два коридора: А — верхний (камни на 2), Б — нижний (на 8), ветер в каждом — со своим тактом.
# Б спускается в нижний по колодцу 27,5–29; А перепрыгивает колодец на верхний. Камни по 3 тайла:
# порыв в воздухе сильнее торможения — разбежавшегося проносит, широкий камень его ловит.
STONES = [34, 40, 46, 52]
lv.block(29, -8, 33, 7.5)               # потолок верхнего коридора (низ −0,5)
lv.block(29, 2, 2, 2.5)                 # старт верхнего
lv.block(27.5, 8, 3.5, 2.5)             # старт нижнего (дно колодца)
lv.block(31, 4.5, 27, 1)                # шипы верхнего коридора и перекрытие
lv.node('SpikesU', 'spikes', 44.5, 4.5, width_tiles='27.0')
lv.block(58, 2, 2, 3.5)                 # конец верхнего; за ним — дыра вниз 60–62
lv.block(31, 10.5, 68, 7.5)             # дно нижних коридоров
lv.node('SpikesL', 'spikes', 44.5, 10.5, width_tiles='27.0')
corridor('U', 31, 58, 2, STONES, 3, 2.2, 1.0, 2.6)
corridor('L', 31, 58, 8, STONES, 3, 1.7, 0.8, 2.1, offset=0.3)
lv.block(58, 8, 8, 2.5)                 # общая площадка после коридоров (верх 8)
lv.block(62, -8, 44, 13.5)              # потолок общего коридора (низ 5,5)

# 4. Общий коридор: оба на одних камнях-осыпи, прыгать разом; с середины такт быстрее.
JOINT = [69, 75, 81, 87, 93]
for i, x in enumerate(JOINT):
    zone = 1 if x < 84 else 2
    lv.node(f'StoneJ{i + 1}', 'brittle', x, 8, width_tiles='3.0', crumble_time='2.4' if zone == 1 else '1.9')
lv.node('SpikesJ', 'spikes', 82.5, 10.5, width_tiles='33.0')
for name, x, d, length, period, off in (('WindJ1R', 66, 1, 18, 2.0, 0.0), ('WindJ1L', 84, -1, 18, 2.0, 1.0),
                                        ('WindJ2R', 84, 1, 15, 1.5, 0.2), ('WindJ2L', 99, -1, 15, 1.5, 0.95)):
    lv.node(name, 'bellows', x, 6.75, direction=f'{d}', length_tiles=f'{length:g}', height_tiles='2.4',
            gust_time='0.9' if period == 2.0 else '0.7', auto_period=f'{period}', auto_offset=f'{off:g}', strength=GUST)
lv.block(99, 8, 7, 10)
lv.node('Finish', 'finish', 103, 8)
lv.checkpoints = [(6.75, 12), (24, 2), (63, 8)]
lv.write('w02_l16_gust.tscn')
