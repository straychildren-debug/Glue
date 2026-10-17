"""Генератор уровня мира 2 «04 · Сортировка» (сложный, на подумать, без таймера).
Головоломка найдена перебором (tools/puzzle2_gen.py, модель tools/puzzle2.py): 37 ходов, 71% состояний —
ловушки (откуда уже не выйти — только рестарт), каждый ящик обязателен.
Комнаты слева направо (высота пола): R0 (низ) — ящик и плита на двоих P5 у стены; R1 (уступ 3) —
плита-ловушка P1; R2…R5 (ещё уступ 3) — ящик и плита на двоих P4, дверь D23 (закрыта, только
если нажаты обе P5 и P4), дверь D34 (P5 или P2), плита P2, дверь D45 (P4), ящик, дверь D56
(закрыта, только если нажаты обе P1 и P2); R6 — вниз к выходу.
Ход решения: ящик R0 — к стене (на P5) и ступенькой наверх; живая лестница в R2; один возвращается
на P5 (ящик + он — D34 открыта), второй везёт ящик R2 на P2; со ступеньки-ящика — наверх;
ящик R2 обратно на P4, на P4 — он и ящик (D45), третий ящик — на P2; потом его же — на P4 к первому:
на P4 два ящика — D45 открыта без людей; к выходу.
Запуск: python tools/levels/w02_l04_sorting.py → levels/w02_l04_sorting.tscn"""
from w2common import Level, COLORS, paths

lv = Level('W02L04', '04 · Сортировка', 57, 'yard', 'w02_lm04_sorting_yard.png')
c5, c4, c2, c1 = COLORS['orange'], COLORS['blue'], COLORS['green'], COLORS['purple']
# R0: старт, ящик, плита на двоих P5 вплотную к уступу.
lv.block(0, 12, 11, 6)
lv.node('Crate1', 'crate', 6, 12 - 31 / 64)
lv.node('P5', 'plate', 10, 12, width_tiles='2.0', threshold='2.0', mark_color=c5)
# R1: уступ 3, плита-ловушка P1.
lv.block(11, 9, 6, 9)
lv.node('P1', 'plate', 14, 9, width_tiles='1.5', mark_color=c1)
# R2…R5: ещё уступ 3; двери с потолком до неба.
lv.block(17, 6, 29, 12)
lv.node('Crate0', 'crate', 19, 6 - 31 / 64)
lv.node('P4', 'plate', 22.5, 6, width_tiles='2.5', threshold='2.0', mark_color=c4)
for name, x, trig, extra in [('D23', 25, ('P5', 'P4'), {'require_all': 'true', 'invert': 'true'}),
                             ('D34', 31, ('P5', 'P2'), {}),
                             ('D45', 39, ('P4',), {}),
                             ('D56', 45, ('P1', 'P2'), {'require_all': 'true', 'invert': 'true'})]:
    lv.block(x, -8, 1, 10)
    lv.node(name, 'door', x, 2, size_tiles='Vector2(1, 4)', triggers=paths(*trig),
            open_offset_tiles='Vector2(0, -3.5)', mark_colors=f'Array[Color]([{", ".join({"P5": c5, "P4": c4, "P2": c2, "P1": c1}[t] for t in trig)}])', **extra)
lv.node('P2', 'plate', 35.5, 6, width_tiles='3.5', mark_color=c2)
lv.node('Crate2', 'crate', 43, 6 - 31 / 64)
# R6: вниз к выходу.
lv.block(46, 9, 10, 9)
lv.node('Finish', 'finish', 52, 9)
lv.checkpoints = [(2, 12)]
lv.write('w02_l04_sorting.tscn')
