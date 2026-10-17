"""Поиск камеры-замка для «Механического замка» (13) перебором случайных раскладок: решение есть,
решений (ходов рычага, ящика, плиты) много, тупиков много. Печатает лучшие.

Запуск: python tools/levels/lock_search.py [число проб] [зерно]"""
import random
import sys
from collections import deque

from lock_solver import Chamber, key_actions


def dead_share(ch, limit=200000):
    """Доля достижимых состояний, из которых выхода уже нет."""
    _, _, prev = key_actions(ch, limit)
    states = list(prev)
    goal = len(ch.rooms) - 1
    # обратный граф: из каких состояний можно дойти до цели
    succ = {}
    for s in states:
        succ[s] = [ch.after(ns) for ns, _ in ch.moves(s)]
    good = {s for s in states if all(p[1] == goal for p in s[0])}
    changed = True
    while changed:
        changed = False
        for s in states:
            if s not in good and any(t in good for t in succ[s]):
                good.add(s)
                changed = True
    return 1 - len(good) / max(len(states), 1), len(states)


def random_chamber(rng):
    n = rng.randint(6, 8)
    rooms = ['f'] * n
    belt_rooms = rng.sample(range(1, n - 1), rng.randint(1, 2))
    for r in belt_rooms:
        rooms[r] = 'b'
    names = ['L', 'M']
    levers = {'L': 0, 'M': rng.choice([r for r in range(1, n - 1) if rooms[r] == 'f'] or [0])}
    free = [r for r in range(1, n - 1) if rooms[r] == 'f' and r not in levers.values()]
    plates = {}
    if free and rng.random() < 0.8:
        plates['P'] = rng.choice(free)
        names.append('P')
    doors = []
    for k in range(n - 1):
        if rooms[k] == 'b' or rooms[k + 1] == 'b':
            doors.append(None if rng.random() < 0.3 else ([rng.choice(names)], rng.random() < 0.5))
        else:
            doors.append(([rng.choice(names)], rng.random() < 0.5))
    belts = {r: ([rng.choice(['L', 'M'])], rng.random() < 0.5) for r in belt_rooms}
    crate_rooms = rng.sample(range(1, n - 1), rng.randint(1, 2))
    return dict(rooms=rooms, doors=doors, belts=belts, levers=levers, plates=plates, crates=crate_rooms)


if __name__ == '__main__':
    tries = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    best = []
    for i in range(tries):
        spec = random_chamber(rng)
        try:
            k, sol, prev = key_actions(Chamber(**spec), 60000)
        except Exception:
            continue
        if k is None or k < 12:
            continue
        dead, total = dead_share(Chamber(**spec), 60000)
        best.append((k, dead, total, spec))
        best.sort(key=lambda b: -(b[0] + 10 * b[1]))
        best = best[:8]
        print(f'{i}: решений {k}, тупики {dead:.2f}, состояний {total}', flush=True)
    print('ЛУЧШИЕ:')
    for k, dead, total, spec in best:
        print(k, round(dead, 2), total, spec)
