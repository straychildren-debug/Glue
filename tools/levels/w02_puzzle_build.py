"""Собирает уровни-головоломки мира 2 из найденных перебором головоломок: сцена (w2_puzzle_level) и
решение (levels/<сцена>.solution.json — шаги решателя и координаты для бота tests/world2_new_smoke.gd).
Запуск: python tools/levels/w02_puzzle_build.py <ключ> [файл с головоломкой (строка repr из --dump)]"""
import ast
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from w2_puzzle_level import build  # noqa: E402
from w2_split_level import build_split  # noqa: E402
from puzzle2 import Puzzle, CRATE_L, CRATE_R  # noqa: E402
from split_puzzle import SplitPuzzle  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LEVELS = {
    # ключ: (имя узла, заголовок, файл сцены, зона)
    'test04': ('W02T04', 'Проба · Сортировка', 'w02_test_sorting.tscn', 'forge', None),
    '10': ('W02L10', '10 · Весы', 'w02_l10_scales.tscn', 'forge', 'w02_lm10_weighing_tower.png'),
    '15': ('W02L15', '15 · Два цеха', 'w02_l15_two_shops.tscn', 'scaffolds', 'w02_lm15_twin_halls.png'),
    '13': ('W02L13', '13 · Механический замок', 'w02_l13_lock.tscn', 'scaffolds', 'w02_lm13_lock_gate.png'),
    '19': ('W02L19', '19 · Перекрёсток', 'w02_l19_crossroads.tscn', 'machine', 'w02_lm19_crossing.png'),
}


def seed_04():
    rooms = [0, 1, 2, 2, 2, 2, 1]
    links = [{'kind': 'open'}, {'kind': 'open'},
             {'kind': 'door', 'trig': [5, 4], 'all': True, 'inv': True},
             {'kind': 'door', 'trig': [5, 2], 'all': False, 'inv': False},
             {'kind': 'door', 'trig': [4], 'all': True, 'inv': False},
             {'kind': 'door', 'trig': [1, 2], 'all': True, 'inv': True}]
    plates = {1: {'room': 1, 'th': 1}, 2: {'room': 4, 'th': 1}, 4: {'room': 2, 'th': 2}, 5: {'room': 0, 'th': 2}}
    return (rooms, links, plates, [2, 0, 5], {}, [])


def prune(links, plates):
    """Плиты, не связанные ни с одной дверью или лентой, — убрать: их цвета нет ни на одной двери."""
    used = {t for l in links for t in l.get('trig', [])}
    return {k: d for k, d in plates.items() if k in used}


def main():
    key = sys.argv[1]
    name, title, file_name, zone, landmark = LEVELS[key]
    if key == '15':
        # два коридора: строка дампа split_puzzle — (n, links, plates, crates, levers)
        line = [l for l in Path(sys.argv[2]).read_text(encoding='utf-8').splitlines() if l[:2] in ('(4', '(5', '(6')][0]
        data = ast.literal_eval(line)
        n, links, plates, crates, levers = data
        plates = prune(links, plates)
        data = (n, links, plates, crates, levers)
        res = SplitPuzzle(n, links, plates, crates, levers).analyze(400000)
        assert res is not None, 'нет решения'
        geo = build_split(name, title, data, file_name, zone, landmark)
        sol = {'steps': res['path'], 'n': n, 'crate_l': CRATE_L, 'crate_r': CRATE_R, 'belts': [], 'floors': geo['floors'], 'room_x': geo['room_x'], 'widths': geo['widths'],
               'plate_x': {str(k): v for k, v in geo['plate_x'].items()}, 'crate_x': geo['crate_x'],
               'lever_x': geo['lever_x'], 'heavy': [], 'plates': {str(k): d for k, d in plates.items()}}
    else:
        if len(sys.argv) > 2:
            line = [l for l in Path(sys.argv[2]).read_text(encoding='utf-8').splitlines() if l.startswith('([')][0]
            data = ast.literal_eval(line)
        else:
            data = seed_04()
        rooms, links, plates, crates, levers, heavy = data
        plates = prune(links, plates)
        data = (rooms, links, plates, crates, levers, heavy)
        res = Puzzle(rooms, links, plates, crates, levers, tuple(heavy)).analyze(400000)
        assert res is not None, 'нет решения'
        geo = build(name, title, data, file_name, zone, landmark)
        sol = {'steps': res['path'], 'rooms': rooms, 'crate_l': CRATE_L, 'crate_r': CRATE_R,
               'belts': [i for i, l in enumerate(links) if l['kind'] == 'belt'], 'room_x': geo['room_x'], 'widths': geo['widths'],
               'floors': [12 - 3 * h for h in rooms],
               'plate_x': {str(k): v for k, v in geo['plate_x'].items()}, 'crate_x': geo['crate_x'],
               'lever_x': geo['lever_x'], 'heavy': list(heavy),
               'plates': {str(k): d for k, d in plates.items()}}
    (ROOT / 'levels' / (file_name.replace('.tscn', '.solution.json'))).write_text(
        json.dumps(sol, ensure_ascii=False, indent=1), encoding='utf-8')
    print(f"{file_name}: ходов {res['len']}, состояний {res['states']}, ловушек {res['dead']}")


if __name__ == '__main__':
    main()
