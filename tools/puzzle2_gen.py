"""Перебор случайных головоломок модели puzzle2 и отбор трудных: длинное кратчайшее решение,
много ловушек (состояний, откуда уже не выйти), каждый ящик, плита и рычаг обязательны.
Запуск: python tools/puzzle2_gen.py [число попыток] [зерно] [--belts] [--heavy]"""
import random
import sys

BIG = '--big' in sys.argv
HEAVY_OPS = '--heavy' in sys.argv
BELT_OPS = '--belts' in sys.argv
from puzzle2 import Puzzle, describe


def random_puzzle(rng, belts=False, heavy=False):
    n = rng.randint(6, 9) if BIG else rng.randint(5, 7)
    rooms = [0]
    for i in range(1, n):
        step = rng.choice([0, 0, 0, 1, -1])
        rooms.append(max(0, min(2, rooms[-1] + step)))
    plates = {}
    pid = 1
    for _ in range(rng.randint(3, 6) if BIG else rng.randint(2, 5)):
        room = rng.randrange(0, n - 1)
        plates[pid] = {'room': room, 'th': rng.choice([1, 1, 1, 2]), 'latch': rng.random() < 0.2}
        pid += 1
    levers = {}
    if belts or rng.random() < 0.3:
        levers['L'] = rng.randrange(0, n - 1)
    links = []
    trig_pool = list(plates) + list(levers)
    for i in range(n - 1):
        r = rng.random()
        if belts and r < 0.25:
            link = {'kind': 'belt', 'dir': rng.choice([-1, 1])}
            if levers and rng.random() < 0.7:
                link['trig'] = ['L']
            links.append(link)
        elif r < 0.85:
            k = rng.choice([1, 1, 2])
            trig = rng.sample(trig_pool, min(k, len(trig_pool)))
            links.append({'kind': 'door', 'trig': trig, 'all': len(trig) > 1 and rng.random() < 0.6,
                          'inv': rng.random() < 0.25})
        else:
            links.append({'kind': 'open'})
    crates = [rng.randrange(0, n - 1) for _ in range(rng.randint(2, 4) if BIG else rng.randint(1, 3))]
    hv = (0,) if heavy and crates and rng.random() < 0.5 else ()
    return Puzzle(rooms, links, plates, crates, levers, hv)


def necessary(p, res):
    """Каждый ящик обязателен: без него решения нет."""
    for c in range(len(p.crates)):
        q = Puzzle(p.rooms, p.links, p.plates, p.crates[:c] + p.crates[c + 1:], p.levers,
                   tuple(h - (h > c) for h in p.heavy if h != c))
        if q.analyze(60000) is not None:
            return False
    return True


def mutate(p, rng):
    """Случайная правка головоломки (копия)."""
    import copy
    q = Puzzle(list(p.rooms), copy.deepcopy(p.links), copy.deepcopy(p.plates), list(p.crates), dict(p.levers), tuple(p.heavy))
    n = len(q.rooms)
    trig_pool = list(q.plates) + list(q.levers)
    op = rng.randrange(14 if (HEAVY_OPS or BELT_OPS) else 11)
    if op == 0 and n > 2:
        i = rng.randrange(1, n)
        q.rooms[i] = max(0, min(2, q.rooms[i] + rng.choice([-1, 1])))
    elif op == 1:
        i = rng.randrange(n - 1)
        link = q.links[i]
        if link['kind'] == 'door' and trig_pool:
            link['trig'] = rng.sample(trig_pool, min(rng.choice([1, 1, 2]), len(trig_pool)))
    elif op == 2:
        i = rng.randrange(n - 1)
        if q.links[i]['kind'] == 'door':
            q.links[i]['inv'] = not q.links[i].get('inv')
    elif op == 3:
        i = rng.randrange(n - 1)
        if q.links[i]['kind'] == 'door':
            q.links[i]['all'] = not q.links[i].get('all')
    elif op == 4 and q.plates:
        pid = rng.choice(list(q.plates))
        q.plates[pid]['room'] = rng.randrange(0, n - 1)
    elif op == 5 and q.plates:
        pid = rng.choice(list(q.plates))
        q.plates[pid]['th'] = 3 - q.plates[pid].get('th', 1)
    elif op == 6 and q.plates:
        pid = rng.choice(list(q.plates))
        q.plates[pid]['latch'] = not q.plates[pid].get('latch')
    elif op == 7:
        if q.crates and rng.random() < 0.5:
            q.crates[rng.randrange(len(q.crates))] = rng.randrange(0, n - 1)
        elif len(q.crates) < 4:
            q.crates.append(rng.randrange(0, n - 1))
    elif op == 9 and n < 10:
        # вставить комнату (открытый проход к соседу)
        i = rng.randrange(1, n)
        q.rooms.insert(i, q.rooms[i - 1])
        q.links.insert(i - 1, {'kind': 'open'})
        for d in q.plates.values():
            if d['room'] >= i:
                d['room'] += 1
        q.crates = [c + (c >= i) for c in q.crates]
        q.levers = {k: v + (v >= i) for k, v in q.levers.items()}
    elif op == 10 and n > 4:
        # убрать комнату без плит, ящиков и рычагов (кроме последней)
        i = rng.randrange(1, n - 1)
        if not any(d['room'] == i for d in q.plates.values()) and i not in q.crates and i not in q.levers.values():
            del q.rooms[i]
            del q.links[i - 1 if i > 0 else 0]
            for d in q.plates.values():
                if d['room'] > i:
                    d['room'] -= 1
            q.crates = [c - (c > i) for c in q.crates]
            q.levers = {k: v - (v > i) for k, v in q.levers.items()}
    elif op == 11 and HEAVY_OPS and q.crates:
        c = rng.randrange(len(q.crates))
        q.heavy = set(q.heavy) ^ {c}
    elif op == 12 and BELT_OPS:
        # рычаг в случайной комнате; какая-то дверь или лента слушает его
        q.levers = {'L': rng.randrange(0, n - 1)}
        doors = [l for l in q.links if l['kind'] in ('door', 'belt')]
        if doors:
            link = rng.choice(doors)
            link['trig'] = list(dict.fromkeys(list(link.get('trig', [])) + ['L']))[-2:]
    elif op == 13 and BELT_OPS:
        i = rng.randrange(n - 1)
        if q.links[i]['kind'] != 'belt':
            q.links[i] = {'kind': 'belt', 'dir': rng.choice([-1, 1])}
            if q.levers and rng.random() < 0.7:
                q.links[i]['trig'] = ['L']
        else:
            q.links[i] = {'kind': 'open'}
    elif op == 8:
        if len(q.plates) < 6 and rng.random() < 0.6:
            pid = max(q.plates or {0: 0}) + 1
            q.plates[pid] = {'room': rng.randrange(0, n - 1), 'th': 1, 'latch': False}
        elif q.plates:
            pid = rng.choice(list(q.plates))
            del q.plates[pid]
            for link in q.links:
                if pid in link.get('trig', []):
                    link['trig'] = [t for t in link['trig'] if t != pid] or rng.sample(list(q.plates) or ['L'], 1)
    return q


def meaningful(path):
    """Значимые ходы: ящики, плиты, живая лестница, ступенька-ящик, рычаг (без простых переходов)."""
    return sum(1 for step in path if ': в комн ' not in step)


def score_of(p, limit=150000):
    # лента — только между комнатами одной высоты: у уступа она не мешает спрыгнуть
    if any(l['kind'] == 'belt' and p.rooms[i] != p.rooms[i + 1] for i, l in enumerate(p.links)):
        return None, None
    res = p.analyze(limit)
    if res is None:
        return None, None
    res['meaningful'] = meaningful(res['path'])
    return res['meaningful'] * 1.5 + 0.2 * res['len'] + 30 * res['dead'] / res['states'] - 1.5 * len(p.rooms), res


def seed_04():
    """Головоломка «Сортировки» (04) — отправная точка для более трудных."""
    rooms = [0, 1, 2, 2, 2, 2, 1]
    links = [{'kind': 'open'}, {'kind': 'open'},
             {'kind': 'door', 'trig': [5, 4], 'all': True, 'inv': True},
             {'kind': 'door', 'trig': [5, 2], 'all': False, 'inv': False},
             {'kind': 'door', 'trig': [4], 'all': True, 'inv': False},
             {'kind': 'door', 'trig': [1, 2], 'all': True, 'inv': True}]
    plates = {1: {'room': 1, 'th': 1}, 2: {'room': 4, 'th': 1}, 4: {'room': 2, 'th': 2}, 5: {'room': 0, 'th': 2}}
    return Puzzle(rooms, links, plates, [2, 0, 5], {}, ())


def evolve(rng, rounds, belts, heavy):
    pool = []
    seed_file = next((a[len('--seed='):] for a in sys.argv if a.startswith('--seed=')), None)
    if seed_file:
        # затравка — головоломка из дампа (строка repr), дальше пул добирается её мутациями
        import ast
        line = [l for l in open(seed_file, encoding='utf-8').read().splitlines() if l.startswith('([')][0]
        r_, l_, pl_, c_, lv_, h_ = ast.literal_eval(line)
        p = Puzzle(r_, l_, pl_, c_, lv_, tuple(h_))
        sc, res = score_of(p)
        pool.append((sc, p, res))
        while len(pool) < 12:
            q = mutate(rng.choice(pool)[1], rng)
            sc, res = score_of(q)
            if sc is not None and necessary(q, res):
                pool.append((sc, q, res))
        pool.sort(key=lambda x: -x[0])
    if '--from04' in sys.argv:
        p = seed_04()
        sc, res = score_of(p)
        pool.append((sc, p, res))
        while len(pool) < 12:
            q = mutate(rng.choice(pool)[1], rng)
            sc, res = score_of(q)
            if sc is not None and necessary(q, res):
                pool.append((sc, q, res))
        pool.sort(key=lambda x: -x[0])
    while len(pool) < 12:
        p = random_puzzle(rng, belts, heavy)
        sc, res = score_of(p)
        if sc is not None and res['len'] >= 12 and necessary(p, res):
            pool.append((sc, p, res))
    for r in range(rounds):
        sc0, p0, res0 = rng.choice(pool[:6])
        q = mutate(p0, rng)
        sc, res = score_of(q)
        # «каждый ящик обязателен» — дорогая проверка (поиск на каждый ящик): только для прошедших в пул
        if sc is None or (len(pool) >= 12 and sc <= pool[-1][0]) or not necessary(q, res):
            continue
        improved = sc > pool[0][0]
        pool.append((sc, q, res))
        pool.sort(key=lambda x: -x[0])
        pool = pool[:12]
        if r % 50 == 0 or improved:
            print(f"раунд {r}: лучшая оценка {pool[0][0]:.1f} (ходов {pool[0][2]['len']}, значимых {pool[0][2]['meaningful']})", flush=True)
            dump = next((a[len('--dump='):] for a in sys.argv if a.startswith('--dump=')), None)
            if dump:
                sc, bp, bres = pool[0]
                with open(dump, 'w', encoding='utf-8') as f:
                    f.write(f"значимых {bres['meaningful']}, ходов {bres['len']}, состояний {bres['states']}, ловушек {bres['dead']}\n{describe(bp)}\n")
                    f.write(repr((bp.rooms, bp.links, bp.plates, bp.crates, bp.levers, sorted(bp.heavy))) + '\n')
                    f.write('\n'.join(bres['path']) + '\n')
    return pool


def main():
    if '--evolve' in sys.argv:
        rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 1)
        pool = evolve(rng, int(sys.argv[1]), '--belts' in sys.argv, '--heavy' in sys.argv)
        for score, p, res in pool[:3]:
            print(f"=== ходов {res['len']}, состояний {res['states']}, ловушек {res['dead']} ({res['dead'] / res['states']:.0%}), оценка {score:.1f}")
            print(describe(p))
            for step in res['path']:
                print('   ', step)
        return
    tries = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 1
    rng = random.Random(seed)
    best = []
    for t in range(tries):
        p = random_puzzle(rng, '--belts' in sys.argv, '--heavy' in sys.argv)
        res = p.analyze(60000)
        if res is None or res['len'] < 18:
            continue
        if not necessary(p, res):
            continue
        score = res['len'] + 40 * res['dead'] / res['states']
        best.append((score, t, p, res))
        best.sort(key=lambda x: -x[0])
        best = best[:5]
    for score, t, p, res in best:
        print(f"=== попытка {t}: ходов {res['len']}, состояний {res['states']}, ловушек {res['dead']} ({res['dead'] / res['states']:.0%}), оценка {score:.1f}")
        print(describe(p))
        for step in res['path']:
            print('   ', step)


if __name__ == '__main__':
    main()
