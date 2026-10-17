"""Головоломка «Два цеха» (мир 2, 15): два коридора, по игроку в каждом; проходить между ними нельзя.
Плиты, защёлки и рычаги одного коридора открывают двери другого — договариваться голосом.
Модель — Puzzle из puzzle2 (комнаты в ряд): верхний коридор — комнаты 0..n-1, нижний — n..2n-1,
между ними связь 'wall'. Старт: P0 в комнате 0, P1 в комнате n; цель: P0 в n-1, P1 в 2n-1.
Перебор и эволюция — как в puzzle2_gen (отбор: длинное решение, ловушки, каждый ящик нужен).
Запуск: python tools/split_puzzle.py [раунды] [зерно] [файл для промежуточного лучшего]"""
import copy
import random
import sys
from puzzle2 import Puzzle, layout


class SplitPuzzle(Puzzle):
    def __init__(self, n, links, plates=None, crates=None, levers=None, heavy=()):
        super().__init__([0] * (2 * n), links, plates, crates, levers, heavy)
        self.n = n

    def start(self):
        bodies = ((0, 0), (self.n, 0)) + self.crate_start()
        return (bodies, frozenset(), frozenset())

    def passable(self, i, direction, act, crate=False):
        j = i + direction
        if not 0 <= j < len(self.rooms) or self.links[min(i, j)]['kind'] == 'wall':
            return False
        return super().passable(i, direction, act, crate)

    def _layout(self):
        # коридоры один над другим, каждый от левого края уровня
        n = self.n
        up = layout([0] * n, {p: d for p, d in self.plates.items() if d['room'] < n}, [], {k: r for k, r in self.levers.items() if r < n})
        low = layout([0] * n, {p: dict(d, room=d['room'] - n) for p, d in self.plates.items() if d['room'] >= n}, [],
                     {k: r - n for k, r in self.levers.items() if r >= n})
        self.room_x = up[0] + low[0]
        self.widths = up[1] + low[1]
        self.plate_x = dict(up[2])
        self.plate_x.update(low[2])

    def goal(self, state):
        bodies = state[0]
        return bodies[0][0] == self.n - 1 and bodies[1][0] == 2 * self.n - 1

    def canon(self, state):
        bodies, latched, levers = state
        return (bodies[0], bodies[1], tuple(sorted(bodies[2:])), latched, levers)


def random_split(rng):
    n = rng.randint(4, 6)
    work = [r for r in range(2 * n) if r not in (n - 1, 2 * n - 1)]
    plates = {}
    for pid in range(1, rng.randint(3, 6) + 1):
        plates[pid] = {'room': rng.choice(work), 'th': rng.choice([1, 1, 2]), 'latch': rng.random() < 0.25}
    levers = {}
    for name in ('L1', 'L2')[:rng.randint(0, 2)]:
        levers[name] = rng.choice(work)
    crates = [rng.choice(work) for _ in range(rng.randint(1, 3))]
    links = []
    for i in range(2 * n - 1):
        if i == n - 1:
            links.append({'kind': 'wall'})
            continue
        upper = i < n - 1
        other = [p for p, d in plates.items() if (d['room'] >= n) == upper] + \
                [l for l, r in levers.items() if (r >= n) == upper]
        own = [p for p, d in plates.items() if (d['room'] >= n) != upper] + \
              [l for l, r in levers.items() if (r >= n) != upper]
        pool = other if (other and rng.random() < 0.8) else (own or other)
        if not pool or rng.random() < 0.1:
            links.append({'kind': 'open'})
            continue
        trig = rng.sample(pool, min(rng.choice([1, 1, 2]), len(pool)))
        links.append({'kind': 'door', 'trig': trig, 'all': len(trig) > 1 and rng.random() < 0.5,
                      'inv': rng.random() < 0.25})
    return SplitPuzzle(n, links, plates, crates, levers)


def mutate(p, rng):
    q = SplitPuzzle(p.n, copy.deepcopy(p.links), copy.deepcopy(p.plates), list(p.crates), dict(p.levers))
    n = q.n
    work = [r for r in range(2 * n) if r not in (n - 1, 2 * n - 1)]
    pool = list(q.plates) + list(q.levers)
    op = rng.randrange(9)
    doors = [i for i, l in enumerate(q.links) if l['kind'] == 'door']
    if op == 0 and doors and pool:
        q.links[rng.choice(doors)]['trig'] = rng.sample(pool, min(rng.choice([1, 1, 2]), len(pool)))
    elif op == 1 and doors:
        link = q.links[rng.choice(doors)]
        link['inv'] = not link.get('inv')
    elif op == 2 and doors:
        link = q.links[rng.choice(doors)]
        link['all'] = not link.get('all')
    elif op == 3 and q.plates:
        q.plates[rng.choice(list(q.plates))]['room'] = rng.choice(work)
    elif op == 4 and q.plates:
        d = q.plates[rng.choice(list(q.plates))]
        d['th'] = 3 - d.get('th', 1)
    elif op == 5 and q.plates:
        d = q.plates[rng.choice(list(q.plates))]
        d['latch'] = not d.get('latch')
    elif op == 6:
        if q.crates and rng.random() < 0.5:
            q.crates[rng.randrange(len(q.crates))] = rng.choice(work)
        elif len(q.crates) < 4:
            q.crates.append(rng.choice(work))
    elif op == 7:
        if q.levers and rng.random() < 0.5:
            q.levers[rng.choice(list(q.levers))] = rng.choice(work)
        elif len(q.levers) < 2:
            q.levers['L%d' % (len(q.levers) + 1)] = rng.choice(work)
    elif op == 8:
        i = rng.randrange(2 * n - 1)
        if q.links[i]['kind'] == 'open' and pool:
            q.links[i] = {'kind': 'door', 'trig': rng.sample(pool, 1), 'all': False, 'inv': False}
        elif q.links[i]['kind'] == 'door':
            q.links[i] = {'kind': 'open'}
    return q


def necessary(p):
    for c in range(len(p.crates)):
        q = SplitPuzzle(p.n, p.links, p.plates, p.crates[:c] + p.crates[c + 1:], p.levers)
        if q.analyze(80000) is not None:
            return False
    return True


def score(p):
    res = p.analyze(150000)
    if res is None:
        return None, None
    res['meaningful'] = sum(1 for step in res['path'] if ': в комн ' not in step)
    return res['meaningful'] * 1.5 + 0.2 * res['len'] + 30 * res['dead'] / res['states'], res


def describe(p):
    lines = [f"коридоры по {p.n} комнат"]
    for i, l in enumerate(p.links):
        lines.append(f"  {i}-{i + 1}: {l}")
    lines.append(f"  плиты: {p.plates}")
    lines.append(f"  ящики: {p.crates}  рычаги: {p.levers}")
    return '\n'.join(lines)


def dump(path, p, res):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(f"значимых {res['meaningful']}, ходов {res['len']}, состояний {res['states']}, ловушек {res['dead']}\n{describe(p)}\n")
        f.write(repr((p.n, p.links, p.plates, p.crates, p.levers)) + '\n')
        f.write('\n'.join(res['path']) + '\n')


def main():
    rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    out = sys.argv[3] if len(sys.argv) > 3 else 'split_best.txt'
    pool = []
    while len(pool) < 10:
        p = random_split(rng)
        sc, res = score(p)
        if sc is not None and res['len'] >= 10 and necessary(p):
            pool.append((sc, p, res))
    pool.sort(key=lambda x: -x[0])
    for r in range(rounds):
        q = mutate(rng.choice(pool[:5])[1], rng)
        sc, res = score(q)
        if sc is None or (len(pool) >= 10 and sc <= pool[-1][0]) or not necessary(q):
            continue
        pool.append((sc, q, res))
        pool.sort(key=lambda x: -x[0])
        pool = pool[:10]
        if r % 50 == 0:
            print(f"раунд {r}: лучшая оценка {pool[0][0]:.1f} (ходов {pool[0][2]['len']}, значимых {pool[0][2]['meaningful']})", flush=True)
            dump(out, pool[0][1], pool[0][2])
    sc, p, res = pool[0]
    dump(out, p, res)
    print(f"=== ходов {res['len']}, состояний {res['states']}, ловушек {res['dead']} ({res['dead'] / res['states']:.0%})")
    print(describe(p))


if __name__ == '__main__':
    main()
