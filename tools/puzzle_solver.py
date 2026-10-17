"""Абстрактная модель «комнаты в ряд — двери — плиты — ящики» и поиск в ширину.
Тела: игроки 0,1 и ящики 2... Положение тела: (комната, слот); слот 0 — пол, k — плита k.
"""
import random, itertools
from collections import deque

class Puzzle:
    def __init__(self, rooms, plates, doors, crates, latches=()):
        self.rooms = rooms                  # число комнат
        self.plates = plates                # plate id -> (room, threshold)
        self.doors = doors                  # door i между комнатами i и i+1: dict(trig=[ids], inv=bool, all=bool, keep=[latch ids])
        self.crates = crates                # список комнат, где стоят ящики (на полу)
        self.latches = set(latches)         # id плит-защёлок

    def start(self):
        bodies = ((0, 0), (0, 0)) + tuple((r, 0) for r in self.crates)
        return (bodies, frozenset())

    def loads(self, bodies):
        load = {}
        for room, slot in bodies:
            if slot:
                load[slot] = load.get(slot, 0) + 1
        return load

    def active(self, bodies, latched):
        load = self.loads(bodies)
        return {p for p, (room, th) in self.plates.items() if load.get(p, 0) >= th or p in latched}

    def door_open(self, i, act):
        d = self.doors[i]
        if any(k in act for k in d.get('keep', [])):
            return True
        hits = [t in act for t in d['trig']]
        met = all(hits) if d.get('all') else any(hits)
        return met != d.get('inv', False)

    def moves(self, state):
        bodies, latched = state
        n = len(bodies)
        out = []
        def fin(nb, label):
            act = self.active(nb, latched)
            nl = latched | frozenset(p for p in self.latches if p in act)
            out.append(((nb, nl), label))
        for i in (0, 1):
            room, slot = bodies[i]
            slots = [0] + [p for p, (r, th) in self.plates.items() if r == room]
            # шаг на другой слот в той же комнате
            for s in slots:
                if s != slot:
                    nb = list(bodies); nb[i] = (room, s); fin(tuple(nb), f"P{i} -> слот {s} (комн {room})")
            # проход в соседнюю комнату
            off = list(bodies); off[i] = (room, 0)
            act = self.active(tuple(off), latched)
            for dr, di in ((-1, room - 1), (1, room)):
                nr = room + dr
                if 0 <= nr < self.rooms and self.door_open(di, act):
                    nb = list(off); nb[i] = (nr, 0); fin(tuple(nb), f"P{i} -> комн {nr}")
            # ящики в той же комнате
            for c in range(2, n):
                croom, cslot = bodies[c]
                if croom != room:
                    continue
                for s in slots:
                    if s != cslot:
                        nb = list(off); nb[c] = (room, s); fin(tuple(nb), f"P{i} двигает ящик {c} на слот {s} (комн {room})")
                off2 = list(off); off2[c] = (room, 0)
                act2 = self.active(tuple(off2), latched)
                for dr, di in ((-1, room - 1), (1, room)):
                    nr = room + dr
                    if 0 <= nr < self.rooms and self.door_open(di, act2):
                        nb = list(off2); nb[i] = (nr, 0); nb[c] = (nr, 0)
                        fin(tuple(nb), f"P{i} везёт ящик {c} в комн {nr}")
        return out

    def goal(self, state):
        bodies, _ = state
        return bodies[0][0] == self.rooms - 1 and bodies[1][0] == self.rooms - 1

    def canon(self, state):
        bodies, latched = state
        players = tuple(sorted(bodies[:2]))
        crates = tuple(sorted(bodies[2:]))
        return (players + crates, latched)

    def solve(self, limit=200000):
        s0 = self.start()
        seen = {self.canon(s0): None}
        parent = {}
        q = deque([s0])
        while q:
            s = q.popleft()
            if self.goal(s):
                path = []
                k = self.canon(s)
                while parent.get(k):
                    pk, label = parent[k]
                    path.append(label); k = pk
                return list(reversed(path)), len(seen)
            for ns, label in self.moves(s):
                k = self.canon(ns)
                if k not in seen:
                    seen[k] = 1
                    parent[k] = (self.canon(s), label)
                    q.append(ns)
                    if len(seen) > limit:
                        return None, len(seen)
        return None, len(seen)

    def reachable(self):
        s0 = self.start(); seen = {self.canon(s0): s0}; q = deque([s0])
        while q:
            s = q.popleft()
            for ns, _ in self.moves(s):
                k = self.canon(ns)
                if k not in seen:
                    seen[k] = ns; q.append(ns)
        return seen

    def dead_ends(self):
        """Доля достижимых состояний, из которых цель уже недостижима (ловушки)."""
        seen = self.reachable()
        # обратный поиск: из каких состояний достижима цель
        good = {k for k, s in seen.items() if self.goal(s)}
        edges = {}
        for k, s in seen.items():
            for ns, _ in self.moves(s):
                edges.setdefault(self.canon(ns), set()).add(k)
        q = deque(good)
        while q:
            k = q.popleft()
            for pk in edges.get(k, ()):
                if pk not in good:
                    good.add(pk); q.append(pk)
        return len(seen), len(seen) - len(good)

def macro_len(path):
    """Длина без переходов на пол (сжатая): считаем только «значимые» ходы."""
    return len(path)
