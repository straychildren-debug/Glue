extends LevelBot
## Автопроверка уровней «Качели» и «Подъёмник» (сейчас 08 и 09 мира 1; ключи — старые номера 12, 13): пара проходит каждый задуманным путём от старта до двери.
## Проверяет и ложные пути — что без главной догадки не пройти.
## Запуск: Godot_console --headless --path . res://tests/stage7_levels_smoke.tscn [-- 11]

const LEVELS := {
	"12": preload("res://levels/w01_l08_seesaw_throw.tscn"),
	"13": preload("res://levels/w01_l09_lift.tscn"),
}
## Черновики: бот ещё доводится — запускаются только явно (-- 15), в общий прогон не входят.
const DRAFTS: Array[String] = []

## Сколько раз погибали игроки на текущем уровне.
var deaths := 0


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	var first := true
	for id: String in LEVELS:
		if not only.is_empty() and id not in only:
			continue
		if only.is_empty() and id in DRAFTS:
			continue
		if first:
			game = await start_game(LEVELS[id])
			first = false
		else:
			await _load(LEVELS[id])
		a = game.players[0]
		b = game.players[1]
		deaths = 0
		for p: Player in [a, b]:
			p.died.connect(func(who: Player) -> void:
				deaths += 1
				var near := ""
				for node in game.level.get_children():
					if node is Ghost:
						near += " %s%s" % [node.name, node.global_position.round()]
				print("    гибель %s в %s%s" % [who.name, who.global_position.round(), near]))
		print("— ", game.level.title)
		await call("_level_" + id)
		check(game.completed, "оба в двери — уровень пройден (a %s b %s)" % [a.global_position, b.global_position])
	finish()


## 12 «Бросок качелей». Комната 1: прыжок с насеста на поднятый конец бросает товарища на башню.
## Комната 2: плиту на полке держит закинутый туда ящик, а не игрок.
func _level_12() -> void:
	var level: GreyboxLevel = game.level
	var seesaw1: Seesaw = level.get_node("Seesaw1")
	var beam1 := seesaw1.get_beam()
	var step: Door = level.get_node("Step")
	var step_latch: PressurePlate = level.get_node("StepLatch")
	# Б поднимается по лестнице на насест и сходит на пустые качели: конец опускается под ним.
	await _run_to(b, 12.0 * TILE)
	check(b.global_position.y < 6 * TILE, "Б на насесте (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 13.6 * TILE)
	await frames(40)
	check(Weight.floor_below(b) == beam1, "Б сошёл с насеста на поднятый конец")
	await _walk_to(b, KEYS_2, 19.0 * TILE)
	await frames(30)
	check(seesaw1.angle > seesaw1.max_angle() - 0.01 and Weight.floor_below(b) == beam1, "Б на правом конце — он внизу у башни")
	# Ложный путь: с конца балки на башню не допрыгнуть.
	await _jump_up(b, KEYS_2)
	check(b.global_position.y > 8 * TILE, "с опущенного конца на башню не допрыгнуть")
	# А с насеста прыгает на поднятый левый конец — Б летит вверх и рулит к башне.
	await _run_to(a, 12.0 * TILE)
	await _walk_to(a, KEYS_1, 13.6 * TILE, 30)
	for i in 150:
		await get_tree().physics_frame
		press(KEYS_2[RIGHT], b.velocity.y < -200.0 or not b.is_on_floor())  # рулит в полёте
		if i > 30 and b.is_on_floor():
			break
	press(KEYS_2[RIGHT], false)
	await frames(10)
	check(b.is_on_floor() and b.global_position.y < 7 * TILE, "А прыгнул с насеста — Б на башне (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, step_latch.global_position.x)
	await frames(30)
	check(step_latch.active and step.global_position.x < 21 * TILE, "Б выдвинул ступеньку")
	# А по балке вниз к башне, на ступеньку, Б вытягивает его наверх.
	await _walk_to(a, KEYS_1, 19.5 * TILE)
	await frames(20)
	await _hop_to(a, 21.2 * TILE, 14)  # вверх, а над ступенькой — к ней
	check(Weight.floor_below(a) == step, "А на ступеньке (%s)" % a.global_position)
	await _walk_to(b, KEYS_2, 22.35 * TILE)
	await _pull_up(b, a, RIGHT)
	check(a.is_on_floor() and a.global_position.y < 7 * TILE, "Б вытянул А на башню")

	# --- Комната 2: «Груз вместо игрока».
	var crate: Crate = level.get_node("Crate")
	var plate: PressurePlate = level.get_node("ShelfPlate")
	var door: Door = level.get_node("ExitDoor")
	var seesaw2: Seesaw = level.get_node("Seesaw2")
	check(seesaw2.angle > seesaw2.max_angle() - 0.01 and crate.global_position.x > 34 * TILE,
			"ящик лежит на опущенном правом конце вторых качелей")
	# А с колонны прыгает на поднятый левый конец — ящик летит на полку с плитой.
	await _walk_to(a, KEYS_1, 25.6 * TILE)
	await _hop_to(a, 27.0 * TILE)
	await _walk_to(a, KEYS_1, 28.6 * TILE)
	await frames(90)
	check(plate.active, "ящик лёг на плиту на полке (ящик %s)" % crate.global_position)
	check(door.global_position.y < 7 * TILE, "дверь выхода открыта")
	await _run_to(b, 41.0 * TILE)
	await _run_to(a, 41.0 * TILE)
	await _both_to_finish()


## 13 «Подъёмник». Комната 1: тормоз-рычаг, 2 против 1 поднимает одного; потом вниз уезжает
## груз, а не человек. Комната 2: «чехарда» — прыжок вес с площадки не снимает, а замерший в
## воздухе не весит: площадка поднимается под ним; второго поднимает ящик-противовес.
func _level_13() -> void:
	var level: GreyboxLevel = game.level
	var lift1: Lift = level.get_node("Lift1")
	var c1: Crate = level.get_node("Crate1")
	var c2: Crate = level.get_node("Crate2")
	var c3: Crate = level.get_node("Crate3")
	var left1: AnimatableBody2D = lift1.get_platforms()[0]
	var right1: AnimatableBody2D = lift1.get_platforms()[1]
	var lever1: Lever = level.get_node("Lever1")
	# Подъёмник на тормозе: загружаемся спокойно. Б справа, А закатывает ящик на левую площадку.
	await _run_to(b, 17.0 * TILE)
	await frames(30)
	check(Weight.floor_below(b) == right1 and absf(lift1.offset) < 1.0, "на тормозе один на площадке не уезжает")
	await _push_crate(a, c1, 13.0 * TILE)
	await _hop_exact(a, 14.1 * TILE)
	check(Weight.floor_below(a) == left1 and Weight.floor_below(c1) == left1,
			"А и ящик на левой площадке (a %s ящик %s)" % [a.global_position, c1.global_position])
	# А отпускает тормоз рычагом на перегородке: 2 против 1 — Б едет наверх.
	await _toggle_lever(a, KEYS_1, lever1)
	check(lever1.active and not lift1.is_locked() and a.grab_target == null,
			"А отпустил тормоз рычагом (и не схватил Б)")
	await frames(260)
	check(lift1.offset > 6.7 * TILE, "А и ящик слева перевесили — Б наверху (ход %.0f)" % lift1.offset)
	await _walk_to(b, KEYS_2, 20.0 * TILE)
	check(b.is_on_floor() and b.global_position.y < 5.25 * TILE, "Б сошёл на уступ")
	# Б грузит на свою площадку два ящика с уступа: 2 против 2 — стоит.
	await _hop_exact(b, 23.25 * TILE)
	await _push_crate(b, c2, 16.4 * TILE)
	await _walk_to(b, KEYS_2, 23.2 * TILE)
	await _hop_exact(b, 25.8 * TILE)
	await _push_crate(b, c3, 17.7 * TILE)
	await _walk_to(b, KEYS_2, 20.0 * TILE)
	await frames(30)
	check(Weight.floor_below(c2) == right1 and Weight.floor_below(c3) == right1 and lift1.offset > 6.0 * TILE,
			"два ящика на площадке Б — 2 против 2, стоит (ход %.0f, ящики %s %s)" % [lift1.offset, c2.global_position, c3.global_position])
	# А сталкивает свой ящик в тоннель: внизу остаётся только он, 1 против 2 — А едет наверх.
	await _push_crate(a, c1, 11.7 * TILE)
	await frames(450)
	check(lift1.offset < -6.7 * TILE and Weight.floor_below(a) == left1,
			"А столкнул ящик в тоннель и уехал наверх, ящики вниз (ход %.0f, a %s)" % [lift1.offset, a.global_position])
	await _walk_to(a, KEYS_1, 12.6 * TILE)
	await _run_jump(a, KEYS_1, 14.75 * TILE)
	await frames(30)
	check(a.is_on_floor() and a.global_position.y < 5.25 * TILE and a.global_position.x > 18.0 * TILE,
			"А с разбега перепрыгнул на уступ — оба наверху (%s)" % a.global_position)

	# --- Комната 2: «Чехарда».
	var lift2: Lift = level.get_node("Lift2")
	var c4: Crate = level.get_node("Crate4")
	var left2: AnimatableBody2D = lift2.get_platforms()[0]
	var right2: AnimatableBody2D = lift2.get_platforms()[1]
	var lever2: Lever = level.get_node("Lever2")
	await _run_to(b, 34.0 * TILE)
	await _run_to(a, 31.0 * TILE)
	await _walk_to(a, KEYS_1, 31.4 * TILE)
	await _toggle_lever(a, KEYS_1, lever2)
	await frames(30)
	check(lever2.active and Weight.floor_below(a) == left2 and Weight.floor_below(b) == right2 and absf(lift2.offset) < 4.0,
			"А и Б на площадках, тормоз отпущен: 1 против 1 — стоит (a %s b %s)" % [a.global_position, b.global_position])
	# Ложный путь: простой прыжок вес не снимает — площадка не едет.
	await _jump_up(b, KEYS_2)
	await frames(20)
	check(absf(lift2.offset) < 4.0, "Б подпрыгнул — подъёмник стоит (ход %.0f)" % lift2.offset)
	# Б поднимается чехардой: противовес — А внизу.
	await _chehard(b, KEYS_2, lift2, func() -> bool: return lift2.offset >= 6.0 * TILE - 1.0)
	check(lift2.offset >= 6.0 * TILE - 1.0 and Weight.floor_below(b) == right2,
			"Б чехардой поднялся до верха (ход %.0f)" % lift2.offset)
	# Б с выходного уступа сталкивает ящик на свою площадку — теперь противовес у А ящик.
	await _hop_exact(b, 37.4 * TILE)
	await _push_crate(b, c4, 34.0 * TILE)
	await _hop_exact(b, 36.6 * TILE)
	await frames(20)
	check(Weight.floor_below(c4) == right2 and b.global_position.y < 0.0,
			"Б положил ящик на поднятую площадку и вернулся на уступ (ход %.0f)" % lift2.offset)
	await _chehard(a, KEYS_1, lift2, func() -> bool: return lift2.offset <= -6.0 * TILE + 1.0)
	check(lift2.offset <= -6.0 * TILE + 1.0 and Weight.floor_below(a) == left2,
			"А чехардой поднялся до верха, ящик уехал вниз (ход %.0f)" % lift2.offset)
	await _walk_to(a, KEYS_1, 30.3 * TILE)
	await _run_jump(a, KEYS_1, 32.0 * TILE)
	await frames(30)
	check(a.is_on_floor() and a.global_position.y < 0.0 and a.global_position.x > 35.0 * TILE,
			"А с разбега на выходном уступе (%s)" % a.global_position)
	await _both_to_finish()


## Ждёт, пока пресс снова поднимется до верха: начало стоянки наверху.
func _press_up(crusher: Press) -> void:
	for i in 400:
		if not crusher.is_up():
			break
		await get_tree().physics_frame
	for i in 400:
		if crusher.is_up():
			break
		await get_tree().physics_frame

## top стоит у края пропасти с зажатым хватом; low с разбега прыгает с края edge_x, не долетает —
## top ловит его за руку и отходит от края, вытягивая. anchor — top ловит замерев: замерший —
## неподвижный якорь, рывок пойманного не стащит его с края; пойманный выпрыгивает с хвата
## сквозь него наверх (как с балки в 03), потом top оживает.
func _catch_jump(top: Player, low: Player, edge_x: float, anchor := false) -> void:
	var kt := _keys(top)
	var kl := _keys(low)
	if anchor:
		tap(kt[FREEZE])
		await frames(2)
	press(kt[GRAB], true)
	press(kl[RIGHT], true)
	var jumped := false
	for i in 200:
		await get_tree().physics_frame
		if not jumped and low.global_position.x >= edge_x - 12.0:
			press(kl[JUMP], true)
			jumped = true
		if top.grab_target == low or not low.alive:
			break
	press(kl[JUMP], false)
	press(kl[RIGHT], false)
	check(top.grab_target == low, "%s поймал %s за руку над пропастью (low %s)" % [top.name, low.name, low.global_position])
	if anchor:
		await frames(10)
		press(kl[RIGHT], true)
		await hold(kl[JUMP], 30)
		for i in 60:
			await get_tree().physics_frame
			if low.is_on_floor() or not low.alive:
				break
		press(kl[RIGHT], false)
		press(kt[GRAB], false)
		await frames(10)
		tap(kt[FREEZE])
		await frames(25)
		return
	await hold(kt[RIGHT], 60)
	press(kt[GRAB], false)
	await frames(25)

## Рука об руку: front держит back (поворачивается к нему лицом — смотрит назад) и пятится
## вправо до target_x; back идёт вперёд, глядя вперёд. Проверяет, что призраки под взглядом.
func _walk_hand_in_hand(front: Player, back: Player, target_x: float, ghosts: Array) -> void:
	var kf := _keys(front)
	var kb := _keys(back)
	await _walk_to(back, kb, front.global_position.x - 60.0)
	press(kf[GRAB], true)
	await frames(3)
	if front.grab_target != back:
		print("    рука об руку: %s не схватил %s" % [front.name, back.name])
	press(kf[RIGHT], true)
	press(kb[RIGHT], true)
	var unwatched := 0
	for i in 900:
		await get_tree().physics_frame
		for g: Ghost in ghosts:
			if not g.watched and g.global_position.distance_to(front.global_position) < 1400.0:
				unwatched += 1
		if front.global_position.x >= target_x or not (a.alive and b.alive):
			break
	press(kf[RIGHT], false)
	press(kb[RIGHT], false)
	press(kf[GRAB], false)
	await frames(10)
	if unwatched > 10:
		print("    рука об руку: призраки без взгляда %d кадров" % unwatched)


## Повернуться лицом в сторону side: короткое касание направления.
func _face(p: Player, side: int) -> void:
	var k := _keys(p)
	press(k[side], true)
	await frames(1)
	press(k[side], false)
	await frames(2)


## С разбега перепрыгнуть призрака, глядя на него; ждёт приземления.
func _jump_over(p: Player, ghost: Ghost) -> void:
	var k := _keys(p)
	press(k[RIGHT], true)
	var jumped_at := -1
	for i in 240:
		await get_tree().physics_frame
		if jumped_at < 0 and p.global_position.x >= ghost.global_position.x - 120.0:
			press(k[JUMP], true)
			jumped_at = i
		if jumped_at >= 0 and i - jumped_at == 30:
			press(k[JUMP], false)
		if jumped_at >= 0 and i - jumped_at > 5 and p.is_on_floor() or not p.alive:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(5)


## Тяжёлый ящик паровозиком рывками: оба идут к ящику и толкают, а когда призрак подлетает
## ближе safe, каждый оборачивается к нему — призрак замирает, — и потом рывок в burst кадров
## без оглядки: с места призрак за рывок пролетит ≈ 23 px, ящик проедет ≈ 67. safe < 0 —
## толкать, не оглядываясь (ложный путь). Прерывается гибелью.
func _push_heavy_watched(crate: Crate, target_x: float, ghost: Ghost, safe := 150.0, burst := 20) -> void:
	var dir := 1 if target_x > crate.global_position.x else -1
	var front := b if (b.global_position.x - a.global_position.x) * dir > 0.0 else a
	var back := a if front == b else b
	var push := [_keys(front)[RIGHT if dir > 0 else LEFT], _keys(back)[RIGHT if dir > 0 else LEFT]]
	var free := 0
	for i in 2400:
		if (crate.global_position.x - target_x) * dir >= 0.0 or not (a.alive and b.alive):
			break
		var near := minf(ghost.global_position.distance_to(a.global_position), ghost.global_position.distance_to(b.global_position))
		if free <= 0 and near < safe:
			for key in push:
				press(key, false)
			for p: Player in [back, front]:
				await _face(p, LEFT if ghost.global_position.x < p.global_position.x else RIGHT)
			await frames(4)
			free = burst
		for key in push:
			press(key, true)
		await get_tree().physics_frame
		free -= 1
	for key in push:
		press(key, false)
	await frames(10)


## Подняться по ящику у стены на уступ с верхом top_y.
func _climb_crate(p: Player, crate: Crate, top_y: float) -> void:
	await _walk_to(p, _keys(p), crate.global_position.x - 70.0)
	await _jump(p, _keys(p), RIGHT, 18)
	await _jump(p, _keys(p), RIGHT, 40)
	check(p.is_on_floor() and p.global_position.y < top_y, "%s поднялся по ящику (%s)" % [p.name, p.global_position])

## Разбег к краю edge_x и прыжок к крюку; хват зажимается, когда крюк рядом (_reach_for).
## true — повис на крюке. Хват остаётся зажатым.
func _jump_to_hook(p: Player, k: Array[Key], hook: Hook, edge_x: float) -> bool:
	press(k[RIGHT], true)
	var jumped := false
	for i in 180:
		await get_tree().physics_frame
		if not jumped and p.global_position.x >= edge_x - 12.0:
			press(k[JUMP], true)
			jumped = true
		if jumped:
			var dx := hook.global_position.x - p.global_position.x
			press(k[RIGHT], dx > 4.0)
			press(k[LEFT], dx < -4.0)
			_reach_for(p, k, hook)
		if p.grab_target == hook or not p.alive:
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	return p.grab_target == hook


## Прыжок с места (с головы товарища) к крюку с подруливанием; true — повис на крюке.
## Хват остаётся зажатым.
func _hop_to_hook(p: Player, k: Array[Key], hook: Hook) -> bool:
	press(k[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		var dx := hook.global_position.x - p.global_position.x
		press(k[RIGHT], dx > 4.0)
		press(k[LEFT], dx < -4.0)
		_reach_for(p, k, hook)
		if p.grab_target == hook or not p.alive or (i > 5 and p.is_on_floor()):
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	return p.grab_target == hook


## Прыжок вверх к висящему товарищу и хват за руку. Хват остаётся зажатым.
func _jump_to_hand(p: Player, k: Array[Key], target: Player) -> void:
	press(k[JUMP], true)
	for i in 60:
		await get_tree().physics_frame
		_reach_for(p, k, target)
		if p.grab_target == target or (i > 5 and p.is_on_floor()):
			break
	press(k[JUMP], false)
	await frames(5)


## Зажимает хват, когда target в досягаемости и ближе товарища: хват берёт ближайшего,
## поэтому зажатый заранее рядом с товарищем схватил бы товарища, а не крюк.
func _reach_for(p: Player, k: Array[Key], target: Node2D) -> void:
	var to_target := p.global_position.distance_to(target.global_position)
	if to_target > p.grab_range:
		return
	for other: Player in [a, b]:
		if other != p and other != target and other.alive \
				and p.global_position.distance_to(other.global_position) <= to_target:
			return
	press(k[GRAB], true)


## Раскачка на хвате (жмёт по ходу; helpers в цепи качают вместе) и прыжок с хвата вправо
## на взлёте, не раньше pump кадров и не левее release_x; в полёте правит к target_x
## с торможением. Ждёт приземления.
func _swing_off(p: Player, k: Array[Key], target_x: float, helpers: Array = [], pump := 150,
		release_x := -INF) -> void:
	for i in 900:
		var right := p.velocity.x >= 0.0
		for keys: Array in [k] + helpers:
			press(keys[RIGHT], right)
			press(keys[LEFT], not right)
		await get_tree().physics_frame
		if i > pump and p.global_position.x >= release_x and p.velocity.x > 250.0 and p.velocity.y < 0.0:
			break
	for keys: Array in [k] + helpers:
		press(keys[RIGHT], false)
		press(keys[LEFT], false)
	press(k[JUMP], true)
	await frames(2)
	press(k[GRAB], false)
	for i in 240:
		await get_tree().physics_frame
		if i == 30:
			press(k[JUMP], false)
		var dx := target_x - p.global_position.x
		var v := p.velocity.x
		var dir := 0
		if absf(dx) > 4.0:
			dir = 1 if dx > 0.0 else -1
			if v * dir > 0.0 and absf(dx) <= v * v / (2.0 * p.air_accel) + absf(v) / 30.0:
				dir = -dir
		press(k[RIGHT], dir > 0)
		press(k[LEFT], dir < 0)
		if i > 5 and (p.is_on_floor() or not p.alive):
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(10)


## Успокоиться на хвате: жать против хода (трения на хвате нет), пока не повиснет неподвижно
## внизу. После чужого рывка размах бывает «рваным» — рука то провисает, то дёргается и гасит
## раскачку; из покоя раскачка ровная (как в tests/lab/lab_swing).
func _calm_on_grab(p: Player, k: Array[Key]) -> void:
	var still := 0
	for i in 600:
		var v := p.velocity
		press(k[RIGHT], v.x < -10.0)
		press(k[LEFT], v.x > 10.0)
		await get_tree().physics_frame
		still = still + 1 if v.length() < 20.0 else 0
		if still > 10:
			break
	press(k[RIGHT], false)
	press(k[LEFT], false)


## Разбег, прыжок у края edge_x и посадка на голову target; true — стоит на нём.
func _run_onto(p: Player, k: Array[Key], target: Player, edge_x: float) -> bool:
	press(k[RIGHT], true)
	var jumped_at := -1
	var landed := false
	for i in 200:
		await get_tree().physics_frame
		if jumped_at < 0 and p.global_position.x >= edge_x - 12.0:
			press(k[JUMP], true)
			jumped_at = i
		if jumped_at >= 0:
			var dx := target.global_position.x - p.global_position.x
			press(k[RIGHT], dx > 4.0)
			press(k[LEFT], dx < -4.0)
			if i - jumped_at > 5 and p.is_on_floor():
				landed = p.standing_on() == target
				break
		if not p.alive:
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(5)
	return landed


## Нажать хват у рычага — переключить.
func _toggle_lever(p: Player, k: Array[Key], lever: Lever) -> void:
	var before := lever.active
	await hold(k[GRAB], 3)
	await frames(3)
	if lever.active == before:
		print("    рычаг не переключился: игрок %s, рычаг %s" % [p.global_position, lever.global_position])


## «Чехарда» на подъёмнике: прыжок, «Замри» на вершине (замерший не весит), площадка
## поднимается под ногами и встаёт; ожить, повторить — пока done() не скажет «наверху».
func _chehard(p: Player, k: Array[Key], lift: Lift, done: Callable) -> void:
	for cycle in 12:
		if done.call():
			return
		press(k[JUMP], true)
		for i in 60:
			await get_tree().physics_frame
			if i > 3 and p.velocity.y >= -30.0:
				break
		tap(k[FREEZE])
		press(k[JUMP], false)
		await frames(8)
		for i in 300:
			await get_tree().physics_frame
			if i > 20 and is_zero_approx(lift.speed):
				break
		tap(k[FREEZE])
		await frames(25)

## Полный прыжок на месте; ждёт приземления.
func _jump_up(p: Player, k: Array[Key]) -> void:
	press(k[JUMP], true)
	await frames(30)
	press(k[JUMP], false)
	for i in 90:
		if p.is_on_floor() or not p.alive:
			break
		await get_tree().physics_frame
	await frames(5)


## Прыжок вверх и «Замри» на спуске, когда ноги опустятся до feet_y.
func _freeze_in_air(p: Player, k: Array[Key], feet_y: float) -> void:
	press(k[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		if p.velocity.y > 0.0 and p.global_position.y + Player.SIZE.y / 2.0 >= feet_y:
			break
	tap(k[FREEZE])
	press(k[JUMP], false)
	await frames(3)


## Прыжок с подруливанием на голову игрока target. true — стоит на нём.
func _jump_onto(p: Player, k: Array[Key], target: Player) -> bool:
	press(k[JUMP], true)
	var landed := false
	for i in 90:
		await get_tree().physics_frame
		var dx := target.global_position.x - p.global_position.x
		press(k[RIGHT], dx > 4.0)
		press(k[LEFT], dx < -4.0)
		if i > 5 and p.is_on_floor():
			landed = p.standing_on() == target
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(5)
	return landed
