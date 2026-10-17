"""Решатель-перебор для головоломки «Перекрёсток» (мир 2, 19): комнаты в ряд, между соседними —
пропасть с поворотной балкой (мост или столб). Рычаги и плиты поворачивают балки; ящик или замерший
на балке её заклинивает (она не поворачивается, пока он там).

Модель (абстрактная, ход — одно действие одного героя):
- герой в комнате i; переходит в i±1, если балка между ними лежит мостом;
- замереть на мосту k (герой рядом, мост лежит): герой «на мосту k», балку держит; ожить можно,
  только если цель балки — мост (иначе повернётся и сбросит в пропасть) — и сойти в соседнюю комнату;
- ящик: толкнуть из комнаты на соседний мост (мост лежит) — ящик на мосту, держит балку;
  толкнуть с моста дальше, в следующую комнату (толкающий — на мосту за ним: можно, только если
  цель балки — мост); стянуть с моста к себе (хват) — в комнату толкающего;
  ящик в комнате с плитой — на плите;
- рычаг — переключить, если герой в его комнате; плита нажата ящиком на ней или стоящим героем
  (герой «держит плиту» — отдельное положение в комнате плиты).
После каждого хода балки без заклинивания встают по цели.
Запуск: python tools/levels/turn_solver.py"""
from collections import deque

# ---------------------------------------------------------------------------------------------
# Описание уровня: комнаты 0..N, балки k — между комнатами k и k+1.
# beams[k] = (список триггеров, invert): мост, когда (любой триггер активен) != invert.
# Триггер — 'L0', 'L1' (рычаги) или 'P0' (плита). levers: рычаг -> комната. plates: плита -> комната.


def solve(n_rooms, beams, levers, plates, crate_room, start=(0, 0), goal_room=None, limit=400000,
          verbose=False):
    goal_room = n_rooms - 1 if goal_room is None else goal_room
    lever_names = sorted(levers)
    plate_names = sorted(plates)

    def triggers_state(lv, players, crate):
        act = {name: lv[i] for i, name in enumerate(lever_names)}
        for name in plate_names:
            room = plates[name]
            act[name] = crate == ('r', room) or any(p == ('p', room) for p in players)
        return act

    def target(k, act):
        trig, inv = beams[k]
        return any(act[t] for t in trig) != inv

    def settle(lv, players, crate, angles):
        act = triggers_state(lv, players, crate)
        new = []
        for k in range(len(beams)):
            jam = crate == ('b', k) or any(p == ('f', k) for p in players)
            new.append(angles[k] if jam else target(k, act))
        return tuple(new), act

    lv0 = tuple(False for _ in lever_names)
    players0 = (('r', start[0]), ('r', start[1]))
    crate0 = ('r', crate_room)
    ang0, _ = settle(lv0, players0, crate0, tuple(True for _ in beams))
    s0 = (players0, crate0, lv0, ang0)
    prev = {s0: None}
    q = deque([s0])

    def room_of(p):
        return p[1] if p[0] in ('r', 'p') else None

    while q:
        s = q.popleft()
        players, crate, lv, ang = s
        if all(p == ('r', goal_room) or p == ('p', goal_room) for p in players):
            path = []
            while s is not None:
                path.append(s)
                s = prev[s][0] if prev[s] else None
            return list(reversed(path)), prev
        _, act = settle(lv, players, crate, ang)
        moves = []
        for i, p in enumerate(players):
            other = players[1 - i]
            r = room_of(p)

            def put(np, ncrate=crate, nlv=lv, label=''):
                pl = list(players)
                pl[i] = np
                moves.append((tuple(pl), ncrate, nlv, f'{"АБ"[i]}: {label}'))
            if p[0] == 'p':
                put(('r', r), label=f'сошёл с плиты в {r}')  # стоя на плите (середина комнаты) — больше ничего
            elif r is not None:
                if r in plates.values():
                    put(('p', r), label=f'встал на плиту в {r}')
                for d in (-1, 1):
                    k = r if d > 0 else r - 1
                    if 0 <= k < len(beams) and ang[k] and 0 <= r + d < n_rooms:
                        if crate != ('b', k) or True:  # ящик на мосту перепрыгивается
                            put(('r', r + d), label=f'перешёл в {r + d}')
                        put(('f', k), label=f'замер на мосту {k}')
                        # ящик из комнаты — на мост
                        if crate == ('r', r):
                            put(p, ('b', k), label=f'толкнул ящик на мост {k}')
                    # стянуть ящик с моста к себе
                    if 0 <= k < len(beams) and crate == ('b', k):
                        put(p, ('r', r), label=f'стянул ящик с моста {k} в {r}')
                for name, room in levers.items():
                    if room == r:
                        j = lever_names.index(name)
                        nlv = list(lv)
                        nlv[j] = not nlv[j]
                        put(p, crate, tuple(nlv), label=f'рычаг {name}')
            elif p[0] == 'f':
                k = p[1]
                # ожить и сойти — только если цель балки мост (иначе сбросит)
                if target(k, act):
                    put(('r', k), label=f'ожил, сошёл в {k}')
                    put(('r', k + 1), label=f'ожил, сошёл в {k + 1}')
                    # толкнуть ящик с моста дальше (стоя за ним на мосту) — тоже только при цели «мост»
        # толкнуть ящик с моста в следующую комнату: толкающий в комнате по одну сторону, мост — цель «мост»
        if crate[0] == 'b':
            k = crate[1]
            if target(k, act):
                for i, p in enumerate(players):
                    if p[0] == 'r' and p[1] in (k, k + 1):
                        far = k + 1 if p[1] == k else k
                        pl = list(players)
                        pl[i] = ('r', far)  # прошёл следом по мосту
                        moves.append((tuple(pl), ('r', far), lv, f'{"АБ"[i]}: протолкнул ящик по мосту {k} в {far}'))
        for npl, ncrate, nlv, label in moves:
            nang, _ = settle(nlv, npl, ncrate, ang)
            ns = (npl, ncrate, nlv, nang)
            if ns not in prev:
                prev[ns] = (s, label)
                q.append(ns)
                if len(prev) > limit:
                    return None, prev
    return None, prev


def show(path, prev):
    for s in path[1:]:
        print('  ', prev[s][1], '| балки', ''.join('—' if a else '|' for a in s[3]), '| ящик', s[1])


def stats(prev):
    return len(prev)


if __name__ == '__main__':
    # пробная раскладка — см. tools/levels/w02_l19_crossroads.py
    beams = [(['L0'], False), (['L0'], True)]
    path, prev = solve(3, beams, {'L0': 0}, {}, crate_room=0)
    print('нынешний 19:', len(path) - 1 if path else None, 'ходов')
    show(path, prev)
