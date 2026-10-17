"""Решатель-перебор для «Механического замка» (мир 2, 13): камера — комнаты в ряд, между соседними —
проём с дверью (или открытый). Двери, ленты и плиты; рычаг переворачивает всё, что к нему подключено.

Модель (абстрактная, ход — одно действие одного героя):
- герой в комнате i; переходит в i±1, если проём открыт (дверь открыта или подпёрта ящиком — ящик
  в проёме перепрыгивается);
- лента — комната, где скорость ленты равна бегу: по ней идти только по ходу; войти в ленту против хода
  нельзя (отнесёт назад); выйти из ленты — только по ходу; лента довозит героя до порога, дальше — сам;
- ящик: в комнате или в проёме. Толкнуть из комнаты в открытый проём по ходу (на ленте — только по ходу
  ленты) — ящик в проёме, дверь подпёрта: не закроется, пока он там. Толкнуть из проёма дальше — в
  соседнюю комнату (если это лента против хода — нельзя); стянуть из проёма к себе (хват, не на ленте);
  ящик на ленте едет к её концу и, если проём там открыт и свободен, въезжает в проём;
- рычаг — переключить, если герой в его комнате (не на ленте); комната плиты узкая, плита во весь пол:
  нажата, пока в комнате герой или ящик;
- двери: открыта, когда (любой триггер активен) != invert, или подпёрта ящиком.
Запуск: python tools/levels/lock_solver.py"""
from collections import deque


class Chamber:
    """rooms: список 'f' (пол) / 'b' (лента); belts: комната -> (триггеры, invert): ход +1, когда
    (любой активен) != invert, иначе −1. doors: проём k (между k и k+1) -> (триггеры, invert) или None
    (открыт всегда). levers: имя -> комната; plates: имя -> комната; crates: комнаты ящиков."""

    def __init__(self, rooms, doors, belts=None, levers=None, plates=None, crates=(), start=(0, 0), lever0=None):
        self.rooms = rooms
        self.doors = doors
        self.belts = belts or {}
        self.levers = levers or {}
        self.plates = plates or {}
        self.crates = tuple(sorted(('r', c) for c in crates))
        self.start = start
        self.lever_names = sorted(self.levers)
        self.lever0 = tuple(lever0.get(n, False) for n in self.lever_names) if lever0 else tuple(False for _ in self.lever_names)

    def act(self, lv, players, crates):
        a = {n: lv[i] for i, n in enumerate(self.lever_names)}
        for n, room in self.plates.items():
            # комната плиты узкая, плита — во весь её пол: кто в комнате (герой или ящик), тот и жмёт
            a[n] = ('r', room) in crates or ('r', room) in players
        return a

    @staticmethod
    def expr(spec, a):
        trig, inv = spec
        return any(a[t] for t in trig) != inv

    def door_open(self, k, a, crates):
        spec = self.doors[k]
        return spec is None or ('d', k) in crates or self.expr(spec, a)

    def belt_dir(self, r, a):
        return 1 if self.expr(self.belts[r], a) else -1

    def passable(self, k, a, crates):
        """Герой проходит проём k: открыт, а ящик в нём перепрыгивается только между комнатами с
        высоким потолком (над лентой — тоннель: не прыгнуть)."""
        if not self.door_open(k, a, crates):
            return False
        return ('d', k) not in crates or (self.rooms[k] == 'f' and self.rooms[k + 1] == 'f')

    def settle(self, lv, players, crates):
        """Ящики на лентах — к концу ленты и в проём, если он открыт и свободен. Героя лента довозит до
        порога (в той же комнате-ленте): дальше он шагает сам."""
        players, crates = self.settle_crates(lv, players, crates)
        return players, crates

    def settle_crates(self, lv, players, crates):
        players = list(players)
        crates = list(crates)
        for _ in range(8):
            moved = False
            a = self.act(lv, tuple(players), tuple(crates))
            for i, c in enumerate(crates):
                if c[0] == 'r' and self.rooms[c[1]] == 'b':
                    d = self.belt_dir(c[1], a)
                    k = c[1] if d > 0 else c[1] - 1
                    t = c[1] + d
                    if not (0 <= k < len(self.doors)):
                        continue
                    if self.doors[k] is None:
                        # проём без двери — ящик съезжает в соседнюю комнату (на ленту против хода — нет)
                        if ('r', t) not in crates and (self.rooms[t] != 'b' or self.belt_dir(t, a) == d):
                            crates[i] = ('r', t)
                            moved = True
                    elif ('d', k) not in crates and self.door_open(k, a, crates):
                        crates[i] = ('d', k)
                        moved = True
            if not moved:
                break
        return tuple(players), tuple(sorted(crates))

    def solve(self, limit=300000, goal=None):
        n = len(self.rooms)
        goal = n - 1 if goal is None else goal
        players0 = (('r', self.start[0]), ('r', self.start[1]))
        players0, crates0 = self.settle(self.lever0, players0, self.crates)
        s0 = (players0, crates0, self.lever0)
        prev = {s0: None}
        q = deque([s0])
        while q:
            s = q.popleft()
            players, crates, lv = s
            if all(p[1] == goal for p in players):
                path = []
                while s is not None:
                    path.append(s)
                    s = prev[s][0] if prev[s] else None
                return list(reversed(path)), prev
            for ns, label in self.moves(s):
                ns = self.after(ns)
                if ns not in prev:
                    prev[ns] = (s, label)
                    q.append(ns)
                    if len(prev) > limit:
                        return None, prev
        return None, prev

    def after(self, ns):
        pl, cr = self.settle(ns[2], ns[0], ns[1])
        return (pl, cr, ns[2])

    def moves(self, s):
        players, crates, lv = s
        a = self.act(lv, players, crates)
        n = len(self.rooms)
        out = []
        for i, p in enumerate(players):
            who = 'АБ'[i]

            def put(np, nc=crates, nlv=lv, label=''):
                pl = list(players)
                pl[i] = np
                out.append(((tuple(pl), tuple(sorted(nc)), nlv), f'{who}: {label}'))
            r = p[1]
            belt = self.rooms[r] == 'b'
            for name, room in self.levers.items():
                if room == r and not belt:
                    j = self.lever_names.index(name)
                    nlv = list(lv)
                    nlv[j] = not nlv[j]
                    put(p, crates, tuple(nlv), label=f'рычаг {name}')
            for d in (-1, 1):
                if belt and self.belt_dir(r, a) != d:
                    continue
                k = r if d > 0 else r - 1
                t = r + d
                if not (0 <= k < len(self.doors) and 0 <= t < n):
                    continue
                if self.passable(k, a, crates) and (self.rooms[t] != 'b' or self.belt_dir(t, a) == d):
                    put(('r', t), label=f'перешёл в {t}')
                if self.door_open(k, a, crates):
                    # ящик из комнаты — в проём (в проём без двери — сразу в соседнюю комнату)
                    if ('r', r) in crates and self.doors[k] is None:
                        if ('r', t) not in crates and (self.rooms[t] != 'b' or self.belt_dir(t, a) == d):
                            nc = list(crates)
                            nc.remove(('r', r))
                            nc.append(('r', t))
                            put(p, nc, label=f'протолкнул ящик в {t}')
                    elif ('r', r) in crates and ('d', k) not in crates:
                        nc = list(crates)
                        nc.remove(('r', r))
                        nc.append(('d', k))
                        put(p, nc, label=f'втолкнул ящик в проём {k}')
                # ящик из проёма — дальше, в соседнюю комнату
                if ('d', k) in crates and (self.rooms[t] != 'b' or self.belt_dir(t, a) == d) \
                        and ('r', t) not in crates:
                    nc = list(crates)
                    nc.remove(('d', k))
                    nc.append(('r', t))
                    # на ленту: ящик целиком на ленте — толкающий уже на её краю, и его утягивает следом
                    put(('r', t) if self.rooms[t] == 'b' else p, nc, label=f'протолкнул ящик из проёма {k} в {t}')
            # стянуть ящик из проёма к себе (не на ленте)
            if not belt:
                for k in (r - 1, r):
                    if 0 <= k < len(self.doors) and ('d', k) in crates and ('r', r) not in crates:
                        nc = list(crates)
                        nc.remove(('d', k))
                        nc.append(('r', r))
                        put(p, nc, label=f'стянул ящик из проёма {k} в {r}')
        return out


def key_actions(ch, limit=300000):
    """Наименьшее число «решений» (рычаг, ящик, плита; ходьба бесплатна) — 0-1 BFS. Путь и метки."""
    goal = len(ch.rooms) - 1
    players0 = (('r', ch.start[0]), ('r', ch.start[1]))
    players0, crates0 = ch.settle(ch.lever0, players0, ch.crates)
    s0 = (players0, crates0, ch.lever0)
    dist = {s0: 0}
    prev = {s0: None}
    dq = deque([s0])
    while dq:
        s = dq.popleft()
        if all(p[1] == goal for p in s[0]):
            path = []
            t = s
            while t is not None:
                path.append(t)
                t = prev[t][0] if prev[t] else None
            return dist[s], list(reversed(path)), prev
        for ns, label in ch.moves(s):
            ns = ch.after(ns)
            w = 0 if 'перешёл' in label else 1
            if ns not in dist or dist[s] + w < dist[ns]:
                dist[ns] = dist[s] + w
                prev[ns] = (s, label)
                (dq.appendleft if w == 0 else dq.append)(ns)
                if len(dist) > limit:
                    return None, None, prev
    return None, None, prev


def show(path, prev):
    for s in path[1:]:
        print('  ', prev[s][1], '| ящики', s[1], '| рычаги', s[2])


if __name__ == '__main__':
    # Камера 1 — нынешний 13: старт с рычагом | дверь (открыта при выкл) | лента (выкл → вправо) |
    # пол с ящиком | дверь (открыта при вкл) | выход.
    c1 = Chamber(rooms=['f', 'b', 'f', 'f'],
                 doors=[(['L'], True), None, (['L'], False)],
                 belts={1: (['L'], True)}, levers={'L': 0}, crates=[2])
    path, prev = c1.solve()
    print('камера 1:', len(path) - 1 if path else None, 'ходов, состояний', len(prev))
    if path:
        show(path, prev)
