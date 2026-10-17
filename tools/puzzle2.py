"""Решатель и генератор головоломок мира 2 («на подумать»): комнаты в ряд и поиск в ширину.

Модель (всё, что можно собрать в уровне-полосе):
- комнаты 0..n-1 слева направо; у комнаты высота пола (уровень, 1 = 3 тайла): вниз — спрыгнуть
  свободно (и столкнуть ящик), вверх — только с помощью: товарищ внизу (встать ему на голову,
  потом вытянуть его за руку — поднимаются оба; или подняться одному, товарищ остаётся внизу), товарищ
  наверху (вытянет за руку) или ящик внизу (с ящика — один, ящик остаётся);
- ящик на полу стоит у левой или у правой стены (по одному; в узкой комнате — один на полу);
  на плите — не больше одного ящика; ящик не проходит сквозь товарища,
  стоящего на плите (с пола тот отходит сам); плита вмещает двоих — ящик и игрока или двух игроков;
  ящик переезжает плиты по пути — защёлка срабатывает (игрок защёлку перепрыгивает);
- в комнате — плиты (порог, защёлка), ящики (обычный — толкает один, тяжёлый — двое), рычаги;
- между соседними комнатами проход: открытый, дверь (условие по плитам и рычагам: любая / все
  сразу, обратная), конвейер (везёт игроков и ящики в одну сторону; рычаг разворачивает);
- цель — оба игрока в последней комнате;
- камера общая: игроки не дальше MAX_GAP тайлов друг от друга (иначе стена камеры не пустит).
Состояние: где игроки и ящики (комната, место: 0 — пол, k — плита k, LEFT / RIGHT — ящик у стены),
защёлки, рычаги."""
import math
import random
from collections import deque

# Раскладка комнат в уровне (тайлы) — общая для модели и сборщика tools/levels/w2_puzzle_level.py.
# Ширина комнаты — по содержимому: поля у стен (ящик-ступенька, живая лестница), плиты и рычаг.
MARGIN = 4.8     # от стены до первой плиты; за ящиком у стены — место толкающему (у стены — ящик-ступенька, конец ленты, живая лестница)
CRATE_L, CRATE_R = 3.3, 4.3  # ящик на полу: от левой стены / от правого края комнаты (с граничным столбцом);
# от конца ленты (1,5 тайла от стены) до ящика — место толкающему, не на ленте
GAP = 1.0        # между плитами
MIN_W = 8        # самая узкая комната (с граничным столбцом): в ней на полу помещается один ящик
PAIR_W = 10      # комната, где на полу два ящика (у обеих стен) и между ними проход
LAST_W = 10      # последняя комната — выход
LEFT, RIGHT = -1, -2  # места ящика на полу: у левой и у правой стены комнаты
MAX_GAP = 32.0   # камера (масштаб до 0,6) вмещает ≈ 47 тайлов между игроками; запас — на место внутри комнаты


def plate_width(d):
    """Любая плита вмещает двоих: ящик и игрока, двух игроков."""
    return 2.5


def layout(rooms, plates, crates, levers):
    """room_x, widths (с граничным столбцом), plate_x, crate_x, lever_x — в тайлах."""
    room_x, widths, plate_x, lever_x = [], [], {}, {}
    x = 1.0
    for r in range(len(rooms)):
        cursor = x + MARGIN
        items = 0
        for pid in sorted((p for p, d in plates.items() if d['room'] == r), key=str):
            w = plate_width(plates[pid])
            plate_x[pid] = cursor + w / 2
            cursor += w + GAP
            items += 1
        for name in sorted(n for n, lr in levers.items() if lr == r):
            lever_x[name] = cursor + 0.5
            cursor += 1.0 + GAP
            items += 1
        base = PAIR_W if sum(1 for c in crates if c == r) >= 2 else MIN_W
        width = max(base, math.ceil(cursor - GAP + MARGIN - x) + 1) if items else base
        if r == len(rooms) - 1:
            width = max(width, LAST_W)
        room_x.append(x)
        widths.append(width)
        x += width
    crate_x, used = [], {}
    for r in crates:
        k = used.get(r, 0)
        used[r] = k + 1
        spots = [room_x[r] + CRATE_L, room_x[r] + widths[r] - CRATE_R]
        crate_x.append(spots[k % 2] + (k // 2) * (1.1 if k % 2 == 0 else -1.1))
    return room_x, widths, plate_x, crate_x, lever_x


class Puzzle:
    def __init__(self, rooms, links, plates=None, crates=None, levers=None, heavy=()):
        self.rooms = rooms            # список высот пола (в уровнях)
        self.links = links            # links[i] — проход между i и i+1: dict(kind='open'|'door'|'belt', ...)
        self.plates = plates or {}    # id -> dict(room, th=1, latch=False)
        self.crates = crates or []    # комнаты ящиков
        self.heavy = set(heavy)       # индексы тяжёлых ящиков (в списке crates)
        self.levers = levers or {}    # id -> room

    def crate_start(self):
        """Ящики на полу у стен: первый в комнате — слева, второй — справа; третьему места нет."""
        out, used = [], {}
        for r in self.crates:
            k = used.get(r, 0)
            used[r] = k + 1
            if k > 1:
                return None
            out.append((r, LEFT if k == 0 else RIGHT))
        return tuple(out)

    def start(self):
        bodies = ((0, 0), (0, 0)) + self.crate_start()
        return (bodies, frozenset(), frozenset())

    def active(self, bodies, latched, levers):
        load = {}
        for k, (room, slot) in enumerate(bodies):
            if slot > 0:  # тяжёлый ящик (масса 2) давит за двоих
                load[slot] = load.get(slot, 0) + (2 if k >= 2 and k - 2 in self.heavy else 1)
        act = {p for p, d in self.plates.items() if load.get(p, 0) >= d.get('th', 1) or p in latched}
        return act | {l for l in levers}

    def cond(self, link, act):
        hits = [t in act for t in link.get('trig', [])]
        met = all(hits) if link.get('all') else any(hits)
        return met != link.get('inv', False)

    def passable(self, i, direction, act, crate=False):
        """Можно ли пройти из комнаты i в i+direction (direction ±1)."""
        j = i + direction
        if not 0 <= j < len(self.rooms):
            return False
        link = self.links[min(i, j)]
        kind = link['kind']
        if kind == 'door' and not self.cond(link, act):
            return False
        if kind == 'belt':
            d = link['dir']
            if link.get('trig') and self.cond(link, act):
                d = -d if link.get('mode', 'reverse') == 'reverse' else 0
            if d != direction:
                return False
        return True

    def narrow(self, bodies, room, c):
        """В узкой комнате на полу уже есть другой ящик: второму у другой стены места нет."""
        return self.widths[room] < PAIR_W and any(
            k != c and b[0] == room and b[1] < 0 for k, b in enumerate(bodies) if k >= 2)

    def slot_x(self, room, slot):
        """Где в комнате место (тайлы): ящик у левой / правой стены или плита."""
        if slot == LEFT:
            return self.room_x[room] + CRATE_L
        if slot == RIGHT:
            return self.room_x[room] + self.widths[room] - CRATE_R
        return self.plate_x[slot]

    def moves(self, state):
        bodies, latched, levers = state
        out = []

        def fin(nb, label, nlev=levers, crossed=()):
            if self.far(nb):
                return
            act = self.active(nb, latched, nlev)
            nl = latched | frozenset(p for p, d in self.plates.items() if d.get('latch') and (p in act or p in crossed))
            out.append(((nb, nl, nlev), label))

        def crowd(nb, room, slot):
            """Сколько тел на месте: плита вмещает двоих, место у стены — один ящик."""
            return sum(1 for body in nb if body == (room, slot))

        for i in (0, 1):
            room, slot = bodies[i]
            other = bodies[1 - i]
            plates_here = [p for p, d in self.plates.items() if d['room'] == room]
            for s in [0] + plates_here:
                if s != slot and (s == 0 or crowd(bodies, room, s) < 2):
                    nb = list(bodies); nb[i] = (room, s); fin(tuple(nb), f"P{i}: на {'пол' if s == 0 else 'плиту ' + str(s)} (комн {room})")
            off = list(bodies); off[i] = (room, 0)
            for lid, lroom in self.levers.items():
                if lroom == room:  # к рычагу — с плиты на пол
                    fin(tuple(off), f"P{i}: рычаг {lid}", levers ^ frozenset([lid]))
            act = self.active(tuple(off), latched, levers)
            for d in (-1, 1):
                j = room + d
                if not self.passable(room, d, act):
                    continue
                up = self.rooms[j] > self.rooms[room]
                if up:
                    # ступенька — ящик на полу у стены в сторону уступа
                    helper_crate = (room, RIGHT if d > 0 else LEFT) in bodies[2:]
                    # помощник сходит со своей плиты (к стене или к краю уступа): дверь — уже без него
                    both = list(off); both[1 - i] = (other[0], 0)
                    helped = self.passable(room, d, self.active(tuple(both), latched, levers))
                    partner = other[0] == room and helped
                    if partner and self.rooms[j] - self.rooms[room] <= 1:
                        # встать на голову и вытянуть товарища: поднимаются оба
                        nb = list(off); nb[i] = (j, 0); nb[1 - i] = (j, 0)
                        fin(tuple(nb), f"P{i} и P{1 - i}: живая лестница в комн {j}")
                        # или подняться с его головы одному: товарищ (у стены) остаётся внизу
                        nb = list(off); nb[i] = (j, 0); nb[1 - i] = (room, 0)
                        fin(tuple(nb), f"P{i}: с головы P{1 - i} в комн {j}")
                    if other[0] == j and helped and self.rooms[j] - self.rooms[room] <= 1:
                        # товарищ уже наверху: вытянет за руку
                        nb = list(off); nb[i] = (j, 0); nb[1 - i] = (j, 0)
                        fin(tuple(nb), f"P{i}: за руку P{1 - i} в комн {j}")
                    if helper_crate and self.rooms[j] - self.rooms[room] <= 1:
                        nb = list(off); nb[i] = (j, 0); fin(tuple(nb), f"P{i}: с ящика в комн {j}")
                    continue
                nb = list(off); nb[i] = (j, 0); fin(tuple(nb), f"P{i}: в комн {j}")
            # ящики: путь ящика не проходит сквозь товарища, стоящего на плите
            for c in range(2, len(bodies)):
                croom, cslot = bodies[c]
                if croom != room:
                    continue
                heavy = (c - 2) in self.heavy
                if heavy and other[0] != room:
                    continue
                block = self.plate_x[other[1]] if not heavy and other[0] == room and other[1] > 0 else None
                x_from = self.slot_x(room, cslot)

                # другие ящики этой комнаты на пути: ящик сквозь ящик не пройдёт
                others = [self.slot_x(room, b[1]) for k, b in enumerate(bodies) if k >= 2 and k != c and b[0] == room]

                def clear(x_to):
                    lo, hi = min(x_from, x_to), max(x_from, x_to)
                    if any(lo < ox < hi for ox in others):
                        return False
                    # на одной плите с товарищем ящик заперт: какая половина чья — модель не знает
                    return block is None or (x_from != block and not (lo < block < hi))

                def crossed(x_to):
                    """Плиты, которые ящик переезжает по пути (защёлка срабатывает: ящик не перепрыгнет),
                    и плита, с которой его снимают (толкающий заходит на неё за ящиком — их двое)."""
                    return [p for p in plates_here if min(x_from, x_to) < self.plate_x[p] < max(x_from, x_to)
                            or p == cslot]

                who = f"P{i}{'+P' + str(1 - i) if heavy else ''}"
                movers = (i, 1 - i) if heavy else (i,)
                off2 = list(bodies)
                for m in movers:
                    off2[m] = (room, 0)
                for s in [LEFT, RIGHT] + plates_here:
                    if s == cslot or not clear(self.slot_x(room, s)):
                        continue
                    if crowd(off2, room, s) >= (1 if s < 0 else 2) or (s < 0 and self.narrow(off2, room, c)):
                        continue
                    if s > 0 and any(k != c and b == (room, s) for k, b in enumerate(off2) if k >= 2):
                        continue  # на плите один ящик: два встали бы вплотную, ближний не толкнуть
                    nb = list(off2); nb[c] = (room, s)
                    where = {LEFT: 'на пол слева', RIGHT: 'на пол справа'}.get(s, f'на плиту {s}')
                    fin(tuple(nb), f"{who}: ящик {c - 2} {where} (комн {room})", crossed=crossed(self.slot_x(room, s)))
                off3 = list(off2); off3[c] = (room, LEFT)  # ящик снят с плиты: для дверей — на полу
                act3 = self.active(tuple(off3), latched, levers)
                for d in (-1, 1):
                    j = room + d
                    if not self.passable(room, d, act3, crate=True):
                        continue
                    if self.rooms[j] > self.rooms[room]:
                        continue  # ящик на уступ не поднять
                    if heavy and self.rooms[j] < self.rooms[room]:
                        continue  # тяжёлый с уступа падает к стене: вдвоём за ним не встать
                    edge = self.room_x[room] if d < 0 else self.room_x[room] + self.widths[room]
                    arrive = LEFT if d > 0 else RIGHT
                    if not clear(edge) or crowd(bodies, j, arrive) or self.narrow(bodies, j, c):
                        continue
                    nb = list(off3); nb[c] = (j, arrive)
                    # толкающий идёт следом, если может (вниз — спрыгивает)
                    for m in movers:
                        nb[m] = (j, 0)
                    fin(tuple(nb), f"{who}: ящик {c - 2} в комн {j}", crossed=crossed(edge))
                    if self.rooms[j] < self.rooms[room]:
                        nb2 = list(off3); nb2[c] = (j, arrive)
                        fin(tuple(nb2), f"P{i}: столкнул ящик {c - 2} вниз в комн {j}", crossed=crossed(edge))
        return out

    def _layout(self):
        self.room_x, self.widths, self.plate_x = layout(self.rooms, self.plates, self.crates, self.levers)[:3]

    def _span(self, body):
        """Где может стоять игрок: на плите — в её точке, на полу — где угодно в комнате."""
        room, slot = body
        if slot:
            return self.plate_x[slot], self.plate_x[slot]
        return self.room_x[room] + 1.0, self.room_x[room] + self.widths[room] - 2.0

    def far(self, bodies):
        """Игроки дальше, чем позволяет общая камера (ближайшие их возможные места)."""
        a, b = self._span(bodies[0]), self._span(bodies[1])
        return max(a[0], b[0]) - min(a[1], b[1]) > MAX_GAP

    def goal(self, state):
        bodies = state[0]
        last = len(self.rooms) - 1
        return bodies[0][0] == last and bodies[1][0] == last

    def canon(self, state):
        bodies, latched, levers = state
        players = tuple(sorted(bodies[:2]))
        light = tuple(sorted(b for k, b in enumerate(bodies[2:]) if k not in self.heavy))
        heavy = tuple(sorted(b for k, b in enumerate(bodies[2:]) if k in self.heavy))
        return (players, light, heavy, latched, levers)

    def search(self, limit=400000):
        """BFS: (кратчайший путь или None, число состояний, граф для анализа)."""
        self._layout()
        if self.crate_start() is None:
            return None, 0, None
        s0 = self.start()
        k0 = self.canon(s0)
        seen = {k0: s0}
        parent = {k0: None}
        edges = {}
        q = deque([s0])
        goal_key = None
        while q:
            s = q.popleft()
            ks = self.canon(s)
            if self.goal(s) and goal_key is None:
                goal_key = ks
            for ns, label in self.moves(s):
                k = self.canon(ns)
                edges.setdefault(k, set()).add(ks)
                if k not in seen:
                    seen[k] = ns
                    parent[k] = (ks, label)
                    q.append(ns)
                    if len(seen) > limit:
                        return None, len(seen), None
        path = None
        if goal_key is not None:
            path = []
            k = goal_key
            while parent[k]:
                pk, label = parent[k]
                path.append(label)
                k = pk
            path.reverse()
        return path, len(seen), (seen, edges)

    def analyze(self, limit=400000):
        path, n, graph = self.search(limit)
        if path is None:
            return None
        seen, edges = graph
        good = {k for k, s in seen.items() if self.goal(s)}
        q = deque(good)
        while q:
            k = q.popleft()
            for pk in edges.get(k, ()):
                if pk not in good:
                    good.add(pk)
                    q.append(pk)
        return {'len': len(path), 'states': n, 'dead': n - len(good), 'path': path}


def describe(p):
    lines = [f"комнаты (высоты): {p.rooms}"]
    for i, l in enumerate(p.links):
        lines.append(f"  {i}-{i + 1}: {l}")
    lines.append(f"  плиты: {p.plates}")
    lines.append(f"  ящики: {p.crates} тяжёлые: {sorted(p.heavy)}  рычаги: {p.levers}")
    return '\n'.join(lines)
