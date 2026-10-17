"""Модель головоломки на искрах (мир 2, «Стрелочник»): места, стрелки, бочонки, поиск в ширину.

Места — точки уровня (пол комнаты, плита, рычаг, мост...). Связи между местами есть, пока не
стоят на пути целые стены (cracked) и пока цел мост (если связь идёт по мосту). Искра бежит от
генератора по развилкам: на каждой стрелке ветка зависит от плиты (вес ≥ порога) или рычага.
Путь кончается бочонком, землёй или тупиком. Если путь кончается целым бочонком, он взрывается
(игроки оставили стрелки так и ждут): рушатся его стены/мост; незамерший в радиусе — гибель
(такой ход запрещён). Замерший — груз на плите и изолятор на проводе (обрывает путь).
Ящик толкают по связям (кроме связи «вниз», куда его можно столкнуть)."""
from collections import deque


class SparkPuzzle:
    def __init__(self, places, links, net, kegs, plates, levers, crates, start, goal, blast, wires_at=None,
                 drops=()):
        self.places = places          # имена мест
        self.links = links            # (a, b, условие) — условие: None или имя стены/моста, которые должны быть целы ('!W1' — разрушены)
        self.net = net                # развилка -> (переключатель, ветка_выкл, ветка_вкл); ветка — имя развилки, 'ground' или бочонок
        self.kegs = kegs              # бочонок -> что рушит (имена стен/мостов)
        self.plates = plates          # плита(место) -> порог
        self.levers = levers          # рычаг -> место
        self.crates = crates          # места ящиков
        self.start = start            # место старта игроков
        self.goal = goal              # место цели
        self.blast = blast            # бочонок -> места в радиусе взрыва
        self.wires_at = wires_at or {}  # место -> развилки, путь через которые проходит здесь (изолятор)
        self.drops = set(drops)       # (a, b) — из a в b только вниз (обратно нельзя)

    def link_ok(self, cond, broken):
        if cond is None:
            return True
        if cond.startswith('!'):
            return cond[1:] in broken
        return cond not in broken

    def neighbours(self, place, broken):
        for a, b, cond in self.links:
            if not self.link_ok(cond, broken):
                continue
            if a == place:
                yield b
            elif b == place and (a, b) not in self.drops:
                yield a

    def route(self, players, frozen, crates, levers, broken):
        """Куда приходит искра: имя бочонка или None (земля, тупик, изолятор)."""
        weight = {}
        for pl in list(players) + list(crates):
            weight[pl] = weight.get(pl, 0) + 1
        insulated = set()
        for pl, fz in zip(players, frozen):
            if fz:
                insulated |= set(self.wires_at.get(pl, ()))
        node = 'G'
        for _ in range(50):
            if node in insulated:
                return None
            if node in self.kegs:
                return node
            if node not in self.net:
                return None
            sw, off, on = self.net[node]
            if sw in self.plates:
                state = weight.get(sw, 0) >= self.plates[sw]
            else:
                state = sw in levers
            node = on if state else off
        return None

    def settle(self, players, frozen, crates, levers, broken, spent):
        """Взрывы, пока путь кончается целым бочонком. None — кто-то погиб."""
        while True:
            keg = self.route(players, frozen, crates, levers, broken)
            if keg is None or keg in spent:
                return broken, spent
            for pl, fz in zip(players, frozen):
                if pl in self.blast.get(keg, ()) and not fz:
                    return None
            broken = broken | frozenset(self.kegs[keg])
            spent = spent | {keg}

    def moves(self, s):
        players, frozen, crates, levers, broken, spent = s
        for i in (0, 1):
            here = players[i]
            # замереть / ожить
            nf = list(frozen); nf[i] = not nf[i]
            yield (players, tuple(nf), crates, levers, broken, spent), f"P{i} {'замер' if nf[i] else 'ожил'} в {here}"
            if frozen[i]:
                continue
            for lv, lp in self.levers.items():
                if lp == here:
                    yield (players, frozen, crates, levers ^ frozenset([lv]), broken, spent), f"P{i} рычаг {lv}"
            for nb in self.neighbours(here, broken):
                np_ = list(players); np_[i] = nb
                yield (tuple(np_), frozen, crates, levers, broken, spent), f"P{i} → {nb}"
                # пришёл и сразу замер (фитиль горит 1,5 с — успевает)
                nf2 = list(frozen); nf2[i] = True
                yield (tuple(np_), tuple(nf2), crates, levers, broken, spent), f"P{i} → {nb} и замер"
                # толкнуть ящик, стоящий здесь, в соседнее место (толкающий остаётся позади)
                for c, cp in enumerate(crates):
                    if cp == here:
                        nc = list(crates); nc[c] = nb
                        yield (players, frozen, tuple(sorted(nc)), levers, broken, spent), f"P{i} толкнул ящик → {nb}"

    def solve(self, limit=500000):
        s0 = ((self.start, self.start), (False, False), tuple(sorted(self.crates)), frozenset(), frozenset(), frozenset())
        st = self.settle(s0[0], s0[1], s0[2], s0[3], s0[4], s0[5])
        assert st is not None, 'взрыв на старте'
        s0 = s0[:4] + st
        key = lambda s: (tuple(sorted(zip(s[0], s[1]))), s[2], s[3], s[4], s[5])
        seen = {key(s0): None}
        parent = {}
        edges = {}
        q = deque([s0])
        found = None
        all_states = {key(s0): s0}
        while q:
            s = q.popleft()
            if s[0][0] == self.goal and s[0][1] == self.goal and found is None:
                found = s
            for ns, label in self.moves(s):
                st = self.settle(ns[0], ns[1], ns[2], ns[3], ns[4], ns[5])
                if st is None:
                    continue
                ns = ns[:4] + st
                k = key(ns)
                edges.setdefault(k, set()).add(key(s))
                if k not in seen:
                    seen[k] = 1
                    parent[k] = (key(s), label)
                    all_states[k] = ns
                    q.append(ns)
                    if len(seen) > limit:
                        return None
        if found is None:
            return {'path': None, 'states': len(seen)}
        path = []
        k = key(found)
        while k in parent:
            pk, label = parent[k]
            path.append(label)
            k = pk
        path.reverse()
        good = {k for k, s in all_states.items() if s[0][0] == self.goal and s[0][1] == self.goal}
        dq = deque(good)
        while dq:
            k = dq.popleft()
            for pk in edges.get(k, ()):
                if pk not in good:
                    good.add(pk)
                    dq.append(pk)
        return {'path': path, 'states': len(seen), 'dead': len(seen) - len(good)}
