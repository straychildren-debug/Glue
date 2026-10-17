"""Генератор уровня мира 2 «07 · Смена на ленте» (сложный, на скорость).
Два коридора, верхний и нижний. Все ленты едут назад со скоростью бега — по такой стоишь на месте.
Кнопка в другом коридоре на миг (PULSE) разворачивает ленту: она мчит вперёд вдвое быстрее бега.
Эстафета: нижний жмёт — верхний проносится по своей ленте и жмёт кнопку за ней — нижний проносится…
Выход — две красные кнопки (верхняя и нижняя) в одно окно.
Запуск: python tools/levels/w02_l07_shift.py → levels/w02_l07_shift.tscn"""
from w2common import Level, COLORS, paths, path

PULSES = [1.15, 1.15, 1.15, 1.15, 1.05, 1.05, 1.05, 1.05]  # окна кнопок, с: лента 8 тайлов с разгоном — ≈ 0,8 с
EXIT_PULSE = 0.4
UP, LOW = 7, 12      # верх пола коридоров

lv = Level('W02L07', '07 · Смена на ленте', 64, 'forge', 'w02_lm07_shift_bell.png')
colors = [COLORS[c] for c in ('orange', 'blue', 'green', 'purple', 'yellow', 'teal', 'pink', 'red')]
# Ленты: (коридор, x, длина, кнопка-управление); кнопки: (имя, коридор, x).
belts = [('U1', UP, 8, 8, 'BL1'), ('L1', LOW, 10, 8, 'BU1'), ('U2', UP, 20, 8, 'BL2'), ('L2', LOW, 22, 8, 'BU2'),
         ('U3', UP, 32, 8, 'BL3'), ('L3', LOW, 34, 8, 'BU3'), ('U4', UP, 44, 8, 'BL4'), ('L4', LOW, 46, 8, 'BU4')]
buttons = [('BL1', LOW, 7), ('BU1', UP, 18.2), ('BL2', LOW, 20.2), ('BU2', UP, 30.2), ('BL3', LOW, 32.2),
           ('BU3', UP, 42.2), ('BL4', LOW, 44.2), ('BU4', UP, 54.2)]
color_of = {b[4]: colors[i] for i, b in enumerate(belts)}


def floor(row, x0, x1, gaps):
    """Пол коридора от x0 до x1 с углублениями под ленты (gaps — (x, длина))."""
    x = x0
    for gx, gw in sorted(gaps):
        if gx > x:
            lv.block(x, row, gx - x, 1 if row == UP else 6)
        lv.block(gx, row + 0.375, gw, (1 if row == UP else 6) - 0.375)
        x = gx + gw
    if x < x1:
        lv.block(x, row, x1 - x, 1 if row == UP else 6)


lv.block(5, -8, 51, 11)                    # потолок верхнего коридора (низ — y 3)
floor(UP, 5, 56, [(x, w) for _, r, x, w, _ in belts if r == UP])
floor(LOW, 0, 63, [(x, w) for _, r, x, w, _ in belts if r == LOW])
lv.block(1, 10, 1.5, 2)                    # ступени на старте: наверх, в верхний коридор
lv.block(3.2, 8.5, 1.3, 0.5)
for name, row, x, w, ctrl in belts:
    lv.node(name, 'conveyor', x, row, width_tiles=f'{w}.0', speed='-360.0', control=path(ctrl), control_mode='0')
for (name, row, x), pulse in zip(buttons, PULSES):
    lv.node(name, 'plate', x, row, width_tiles='1.0', pulse=f'{pulse}', mark_color=color_of[name])
# Выход: верхняя кнопка у конца верхнего коридора, нижняя — внизу; ворота — в одно окно.
lv.node('ExitU', 'plate', 55.4, UP, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=COLORS['red'])
lv.node('ExitL', 'plate', 56.6, LOW, width_tiles='1.0', pulse=f'{EXIT_PULSE}', mark_color=COLORS['red'])
lv.block(59, -8, 1, 16)
lv.node('Exit', 'door', 59, 8, size_tiles='Vector2(1, 4)', triggers=paths('ExitU', 'ExitL'), require_all='true',
        stay_open='true', open_offset_tiles='Vector2(0, -3.5)', mark_color=COLORS['red'])
lv.node('Finish', 'finish', 61.5, LOW)
lv.checkpoints = [(3.5, 12)]
lv.write('w02_l07_shift.tscn')
