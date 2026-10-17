extends "res://tests/trial_levels_smoke.gd"
## Автопроверка перестроенных уровней мира 1 (раскладка 5 / 5 / 5 / 5, docs/14): пара проходит
## каждый задуманным путём. Средние 06, 07, 10 — бывшие пробные (их боты — в trial_levels_smoke),
## 08–09 проверяет stage7_levels_smoke.
## Запуск: Godot_console --headless --fixed-fps 60 --path . res://tests/world1_levels_smoke.tscn [-- 06]

const WORLD1 := {
	"06": [preload("res://levels/w01_l06_crate_from_far.tscn"), "_level_04"],
	"07": [preload("res://levels/w01_l07_two_buttons.tscn"), "_level_02"],
	"10": [preload("res://levels/w01_l10_four_colors.tscn"), "_level_05"],
	"11": [preload("res://levels/w01_l11_relay.tscn"), "_level_06"],
	"12": [preload("res://levels/w01_l12_chain.tscn"), "_w12"],
	"13": [preload("res://levels/w01_l13_shy.tscn"), "_w13"],
	"14": [preload("res://levels/w01_l14_presses.tscn"), "_w14"],
	"15": [preload("res://levels/w01_l15_drawbridge.tscn"), "_w15"],
	"16": [preload("res://levels/w01_l16_rockfall.tscn"), "_level_07"],
	"17": [preload("res://levels/w01_l17_ghosts_chase.tscn"), "_w13"],
	"18": [preload("res://levels/w01_l18_relay_chase.tscn"), "_level_06"],
	"19": [preload("res://levels/w01_l19_sawmill.tscn"), "_w19"],
	"20": [preload("res://levels/w01_l20_old_bridge.tscn"), "_w20"],
}


func _catalog() -> Dictionary:
	var result := {}
	for id: String in WORLD1:
		result[id] = WORLD1[id][0]
	return result


func _method(id: String) -> String:
	return WORLD1[id][1]


## 14 «Под прессами»: волна; длинный пресс — подпорка из замершего в прыжке; пресс перед воротами —
## передачи через кнопки по обе стороны; два пресса в противофазе с колонной на одного; выход.
func _w14() -> void:
	var level: GreyboxLevel = game.level
	var exit: Door = level.get_node("Exit")
	# 1. Волна: стартуют, когда первый пресс только что поднялся выше головы, — насквозь.
	await _walk_to(b, KEYS_2, 6.95 * TILE)
	await _walk_to(a, KEYS_1, 6.3 * TILE)
	var w1: Node = level.get_node("Wave1")
	for i in 400:
		if w1.get("_state") == 3 and w1.position.y > 470.0 and w1.position.y < 505.0:
			break
		await get_tree().physics_frame
	press(KEYS_2[RIGHT], true)
	await frames(2)
	press(KEYS_1[RIGHT], true)
	for i in 200:
		await get_tree().physics_frame
		press(KEYS_2[RIGHT], b.global_position.x < 21.2 * TILE)
		press(KEYS_1[RIGHT], a.global_position.x < 20.3 * TILE)
		if not a.alive or not b.alive or (a.global_position.x >= 20.3 * TILE and b.global_position.x >= 21.2 * TILE):
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(10)
	check(a.alive and b.alive and a.global_position.x > 19.8 * TILE, "1: волна прессов пройдена (a %s b %s)" % [a.global_position, b.global_position])
	# 2. Длинный пресс: одному не пробежать. А прыгает под него и замирает — подпорка; Б проходит
	# под замершим; А оживает (пресс стоит на месте, пока внизу) и выходит.
	var long_press: Node = level.get_node("Long")
	var before := deaths
	await _settle(b, 20.4, 12)
	await _settle(a, 21.55, 12)  # под краем потолка вплотную к прессу
	for i in 600:
		# Поднимается, и низ уже выше головы: нырнуть под него, пока он не встал наверху.
		if long_press.get("_state") == 3 and long_press.position.y < 480.0 and long_press.position.y > 460.0:
			break
		await get_tree().physics_frame
	press(KEYS_1[RIGHT], true)
	var jumped := -1
	for i in 60:
		await get_tree().physics_frame
		if jumped < 0 and a.global_position.x >= 22.5 * TILE:
			press(KEYS_1[JUMP], true)
			jumped = i
		elif jumped >= 0 and a.global_position.y + Player.SIZE.y / 2.0 < 10.85 * TILE:
			break  # ноги на тайл с лишним над полом — замереть: пресс ляжет на голову, под ногами проход
	tap(KEYS_1[FREEZE])
	press(KEYS_1[RIGHT], false)
	press(KEYS_1[JUMP], false)
	await frames(30)
	check(a.frozen and long_press.position.y < 7.5 * TILE, "А замер подпоркой — пресс стоит высоко (пресс y %s, А %s)" % [long_press.position.y, a.global_position])
	await _walk_to(b, KEYS_2, 29.7 * TILE)
	check(b.alive and b.global_position.x > 28.5 * TILE, "Б прошёл под замершим А (%s)" % b.global_position)
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _walk_to(a, KEYS_1, 29.4 * TILE)
	check(deaths == before and a.global_position.x > 28.2 * TILE, "А вышел, пока пресс стоит (%s)" % a.global_position)
	await _walk_to(b, KEYS_2, 30.2 * TILE)  # дальше — под прессом у ворот
	await _walk_to(a, KEYS_1, 29.4 * TILE)
	await frames(30)
	check(level.active_checkpoint == 1, "оба у чекпоинта посередине — взят")
	# 3. Пресс перед воротами: А жмёт ближнюю кнопку — Б проскакивает; Б жмёт дальнюю — А.
	var gate_press: Node = level.get_node("GatePress")
	await _walk_to(b, KEYS_2, 31.4 * TILE)
	await _settle(b, 31.6, 12)
	await _relay(a, KEYS_1, 30.0, 20, func() -> void: await _run_plain(b, KEYS_2, 37.5),
			func() -> bool: return gate_press.get("_state") == 3 and gate_press.position.y < 520.0 and gate_press.position.y > 500.0, _press_period(gate_press))
	check(deaths == before and b.global_position.x > 37.2 * TILE, "3: Б проскочил под прессом в ворота (%s)" % b.global_position)
	await _settle(a, 31.6, 12)
	await _relay(b, KEYS_2, 38.5, 20, func() -> void: await _run_plain(a, KEYS_1, 37.9),
			func() -> bool: return gate_press.get("_state") == 3 and gate_press.position.y < 520.0 and gate_press.position.y > 500.0, _press_period(gate_press), 1)
	check(deaths == before and a.global_position.x > 37.2 * TILE, "3: А проскочил под прессом в ворота (%s)" % a.global_position)
	# 4. Два пресса в противофазе: перебежка под первым к колонне (место на одного) и дальше.
	var pa: Node = level.get_node("PairA")
	var pb: Node = level.get_node("PairB")
	var up := func(p: Node) -> bool: return p.get("_state") == 3 and p.position.y > 470.0 and p.position.y < 505.0
	for who: Player in [b, a]:
		await _walk_to(who, _keys(who), 40.6 * TILE)
		await _settle(who, 41.4, 12)
		for i in 600:
			if up.call(pa):
				break
			await get_tree().physics_frame
		await _run_plain(who, _keys(who), 45.1)
		check(who.alive, "4: %s под колонной между прессами (%s)" % [who.name, who.global_position])
		for i in 600:
			if up.call(pb):
				break
			await get_tree().physics_frame
		await _run_plain(who, _keys(who), 49.6 if who == b else 49.4)
		await _walk_to(who, _keys(who), (52.4 if who == b else 50.2) * TILE)
	check(deaths == before and a.global_position.x > 49.0 * TILE, "4: оба прошли пару прессов (a %s b %s)" % [a.global_position, b.global_position])
	# 5. Выход: обе красные в одно окно.
	await _settle(a, 50.1, 12)
	await _settle(b, 52.6, 12)
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 40:
		await get_tree().physics_frame
		press(KEYS_1[RIGHT], a.global_position.x < 51.0 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 53.5 * TILE)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(60)
	check(exit.get("_latched"), "5: обе красные в окно — выход открыт")
	await _both_to_finish()


## 15 «Разводной мост»: секции между столбами поднимаются от кнопок на миг; один жмёт — другой
## перебегает, потом наоборот; секцию 2 поднимает плита на двоих — бегут вместе. Выход — две кнопки.
func _w15() -> void:
	var level: GreyboxLevel = game.level
	var exit: Door = level.get_node("Exit")
	var before := deaths
	# Опоры: берег до 6, столбы по 4 тайла; на опоре x: L — x+2.6, R — x+1.6, старт — x+3.55,
	# прибытие — x+0.5. На берегу L1 — 4.6, старт — 5.55.
	var starts := [6.0, 14.0, 23.0, 31.0, 39.0]  # правые края опор (начала секций)
	var lands := [10.0, 19.0, 27.0, 35.0, 43.0]  # левые края следующих опор
	for n in 5:
		var l_x: float = 4.6 if n == 0 else starts[n] - 1.4
		await _settle(a, l_x - 1.0, 12)
		await _settle(b, starts[n] - 0.45, 12)
		await _bridge(a, l_x, b, n + 1, lands[n] + 0.5)
		check(deaths == before and b.global_position.x > lands[n] * TILE, "%d: Б перебежал секцию (%s)" % [n + 1, b.global_position])
		await _settle(a, starts[n] - 0.45, 12)
		await _bridge(b, lands[n] + 1.6, a, n + 1, lands[n] + 0.4)
		check(deaths == before and a.global_position.x > lands[n] * TILE, "%d: А перебежал секцию (%s)" % [n + 1, a.global_position])
		await frames(20)
		if n == 2:
			check(level.active_checkpoint == 1, "оба на столбе 3 — чекпоинт взят")
	# Выход: две красные в одно окно.
	await _settle(a, 44.6, 12)
	await _settle(b, 47.1, 12)
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 40:
		await get_tree().physics_frame
		press(KEYS_1[RIGHT], a.global_position.x < 45.5 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 48.0 * TILE)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(60)
	check(exit.get("_latched"), "выход: обе красные в окно — открыт")
	await _both_to_finish()


## Нажимающий шагает на кнопку в button_x (с той стороны, где стоит); бегущий трогается, когда
## секция n почти поднялась, и бежит до to_x.
func _bridge(presser: Player, button_x: float, runner: Player, n: int, to_x: float) -> void:
	var section: Door = game.level.get_node("S%d" % n)
	var top: float = section.get("_closed_position").y - 5.5 * TILE
	var kp := _keys(presser)
	# Прибежал и заехал краем на кнопку — она уже отработала: сойти и наступить заново.
	var away := signf(presser.global_position.x - button_x * TILE)
	if absf(presser.global_position.x - button_x * TILE) < 0.8 * TILE:
		place(presser, Vector2((button_x + away * 0.9) * TILE, presser.global_position.y))
		await frames(10)
	var key := kp[RIGHT] if button_x * TILE > presser.global_position.x else kp[LEFT]
	press(key, true)
	for i in 30:
		await get_tree().physics_frame
		if absf(presser.global_position.x - button_x * TILE) <= 8.0:
			break
	press(key, false)
	for i in 120:
		if section.global_position.y < top + 1.2 * TILE:
			break
		await get_tree().physics_frame
	# Бежит; у конца секции подпрыгивает на опору — секция могла уже начать опускаться.
	var kr := _keys(runner)
	var end_x: float = section.global_position.x + section.size_tiles.x * TILE
	press(kr[RIGHT], true)
	var hold := 0
	for i in 240:
		if hold == 0 and runner.is_on_floor() and runner.global_position.x > end_x - 0.9 * TILE and runner.global_position.x < end_x:
			hold = 14
		press(kr[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		await get_tree().physics_frame
		if runner.global_position.x >= to_x * TILE or not runner.alive:
			break
	press(kr[RIGHT], false)
	press(kr[JUMP], false)
	await frames(10)


## 13 «Стесняшки»: призраки летят, пока на них не смотрят. 1 — Б толкает ящик на плиту, держа А
## за руку (так смотрит назад, на призрака); 2 — пропасть между двумя призраками: ступенька
## в воздухе и вытягивание, затем перепрыгнуть призрака, глядя на него; 3 — ворота на кнопках:
## нажимающий стоит лицом к призраку.
func _w13() -> void:
	var level: GreyboxLevel = game.level
	var g1: Ghost = level.get_node("Ghost1")
	var crate: Crate = level.get_node("Crate")
	var before := deaths
	# 1. А сразу оборачивается к призраку; Б берёт А за руку и толкает ящик, глядя на А.
	await _face1(a, LEFT)
	check(g1.watched, "1: А обернулся — призрак замер")
	press(KEYS_2[GRAB], true)  # Б рядом с А — берёт его за руку и дальше смотрит на него (назад)
	await frames(3)
	check(b.grab_target == a, "1: Б держит А за руку (смотрит назад)")
	press(KEYS_2[RIGHT], true)
	press(KEYS_1[RIGHT], true)
	var unwatched := 0
	for i in 900:
		await get_tree().physics_frame
		if not g1.watched:
			unwatched += 1
		# Ящик — на плиту; затем рука об руку в дверь и под призраком комнаты 2: Б смотрит назад —
		# на А и на обоих призраков.
		if (a.global_position.x >= 29.6 * TILE and b.global_position.x >= 30.2 * TILE) or not a.alive or not b.alive:
			break
		press(KEYS_2[RIGHT], b.global_position.x < 32.5 * TILE)
		# А не вдавливает Б в ящик: зажатые между собой и ящиком, оба встают (как и живые игроки).
		press(KEYS_1[RIGHT], b.global_position.x - a.global_position.x > 50.0)
	press(KEYS_2[RIGHT], false)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[GRAB], false)
	await frames(20)
	check(deaths == before and level.get_node("Plate1").active, "1: ящик на плите, прошли дверь без гибели (призрак без взгляда %d кадров)" % unwatched)
	# По очереди: один стережёт призрака у входа, другой идёт.
	await _face1(a, LEFT)
	await _walk_to(b, KEYS_2, 33.6 * TILE)
	await _face1(b, LEFT)
	await _walk_to(a, KEYS_1, 33.0 * TILE)
	check((level.checkpoints.size() < 2 or level.active_checkpoint == 1) and deaths == before, "оба в комнате 2 (смертей %d)%s" % [deaths - before, _lag_note()])
	# 2. Ступенька в воздухе над пропастью и вытягивание: Б замирает, А по нему, А вытягивает Б.
	await _face1(a, LEFT)  # А прикрывает спину: смотрит на призрака сзади, пока Б прыгает и замирает
	var ok := await _step_in_air(b, KEYS_2, a, KEYS_1, 37.0, 40.55, 41.6)
	check(ok, "2: А перепрыгнул пропасть по замершему Б (a %s b %s)" % [a.global_position, b.global_position])
	await _walk_to(a, KEYS_1, 41.75 * TILE)
	press(KEYS_1[LEFT], true)
	await frames(2)
	press(KEYS_1[LEFT], false)
	press(KEYS_1[GRAB], true)
	await frames(4)
	tap(KEYS_2[FREEZE])
	await frames(6)
	# А тянет, глядя на Б (и на призрака сзади); Б висит лицом вперёд — на призрака впереди.
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		var feet := b.global_position.y + Player.SIZE.y / 2.0
		press(KEYS_1[RIGHT], feet > 12.0 * TILE - 4.0)
		if b.is_on_floor() and b.global_position.y < 12.0 * TILE:
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	press(KEYS_1[GRAB], false)
	await frames(10)
	check(deaths == before and b.global_position.y < 12 * TILE, "2: А вытянул Б из пропасти между призраками (%s)%s" % [b.global_position, _lag_note()])
	# Защёлка двери 2; затем перепрыгнуть призрака впереди, глядя на него.
	var ahead := a if a.global_position.x > b.global_position.x else b
	var behind := b if ahead == a else a
	await _face1(behind, LEFT)  # задний смотрит на призрака сзади, пока передний занят передним
	await _walk_to(ahead, _keys(ahead), 45.5 * TILE)
	var g3: Ghost = level.get_node("Ghost3")
	await _jump_over1(ahead, g3)
	await _walk_to(ahead, _keys(ahead), 55.6 * TILE)
	await _face1(ahead, LEFT)  # вошёл в третью комнату — сразу к призраку над дверью
	await _jump_over1(behind, g3)
	await _walk_to(behind, _keys(behind), 54.2 * TILE)
	check(deaths == before and a.global_position.x > 52.5 * TILE and b.global_position.x > 52.5 * TILE, "2: оба перепрыгнули призрака и прошли дверь (a %s b %s)%s" % [a.global_position, b.global_position, _lag_note()])
	await _walk_to(a, KEYS_1, 56.8 * TILE)
	await _walk_to(b, KEYS_2, 56.8 * TILE)
	# 3. Ворота: А на ближней кнопке лицом к призраку — Б пробегает; Б на дальней лицом назад — А.
	await _settle(a, 57.6, 12)
	await _settle(b, 59.4, 12)
	# Б бежит, как только А наступил на кнопку: окно ворот — ровно секунда.
	var step_on := func() -> void:
		await _walk_to(a, KEYS_1, 58.45 * TILE)
		await _face1(a, LEFT)
	step_on.call()
	await frames(4)
	await _run_plain(b, KEYS_2, 65.2)
	check(deaths == before and b.global_position.x > 65.0 * TILE, "3: Б прошёл ворота, А сторожит призрака (%s)" % b.global_position)
	await _settle(b, 67.4, 12)
	await _settle(a, 59.4, 12)
	_walk_to(b, KEYS_2, 66.55 * TILE)
	await frames(4)
	await _run_plain(a, KEYS_1, 65.2)
	check(deaths == before and a.global_position.x > 65.0 * TILE, "3: А прошёл ворота, Б сторожит (%s)" % a.global_position)
	await _both_to_finish()


## Где обвал (если он есть на уровне): «; обвал в N тайла от отставшего».
func _lag_note() -> String:
	if not game.level.has_node("Crusher"):
		return ""
	var crusher: Crusher = game.level.get_node("Crusher")
	return "; обвал в %.1f тайла от отставшего" % ((minf(a.global_position.x, b.global_position.x) - crusher.global_position.x) / TILE)


## Повернуться лицом в сторону side: короткое касание направления.
func _face1(p: Player, side: int) -> void:
	var k := _keys(p)
	press(k[side], true)
	await frames(1)
	press(k[side], false)
	await frames(2)


## С разбега перепрыгнуть призрака, глядя на него; ждёт приземления.
func _jump_over1(p: Player, ghost: Ghost) -> void:
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


## 12 «Цепь над шипами» (старый 14 без чекпоинтов между комнатами 1 и 2): крюк над шипами,
## цепь на высоком крюке, камень в шипах и мост под ним.
func _w12() -> void:
	var level: GreyboxLevel = game.level
	var hook1: Hook = level.get_node("Hook1")
	var hook2: Hook = level.get_node("Hook2")
	# Комната 1: каждый сам — прыжок к крюку, раскачка, прыжок с хвата на тот берег.
	# Первым идёт Б: на старте он стоит правее и загораживает А путь к краю.
	# Ложный путь: 8 тайлов шипов с разбега не перепрыгнуть.
	await _run_jump(b, KEYS_2, 10.0 * TILE)
	check(await _dies(b), "без крюка через шипы не перепрыгнуть — Б погиб")
	await _respawned()
	await _walk_to(b, KEYS_2, 7.5 * TILE)
	check(await _jump_to_hook(b, KEYS_2, hook1, 10.0 * TILE), "Б в прыжке схватился за крюк над шипами (%s)" % b.global_position)
	await _swing_off(b, KEYS_2, 20.0 * TILE)
	check(b.alive and b.is_on_floor() and b.global_position.x > 18.0 * TILE, "Б перелетел шипы с крюка (%s)" % b.global_position)
	await _walk_to(a, KEYS_1, 7.5 * TILE)
	check(await _jump_to_hook(a, KEYS_1, hook1, 10.0 * TILE), "А схватился за крюк (%s)" % a.global_position)
	await _swing_off(a, KEYS_1, 19.0 * TILE)
	check(a.alive and a.is_on_floor() and a.global_position.x > 18.0 * TILE, "А перелетел шипы (%s)" % a.global_position)

	# Комната 2: высокий крюк. Б впереди — встаёт под крюк, А ждёт поодаль (иначе хват возьмёт его).
	# Ложный путь: с прыжка крюк не достать.
	await _walk_to(b, KEYS_2, 25.55 * TILE)
	await _walk_to(a, KEYS_1, 23.6 * TILE)
	press(KEYS_2[GRAB], true)
	await _jump_up(b, KEYS_2)
	check(b.grab_target == null and b.is_on_floor(), "с прыжка высокий крюк не достать")
	press(KEYS_2[GRAB], false)
	await frames(5)
	# А с головы Б прыгает к крюку, Б в прыжке хватается за руку А — цепь.
	await _onto_head(a, b)
	check(await _hop_to_hook(a, KEYS_1, hook2), "А с головы Б схватился за высокий крюк (%s)" % a.global_position)
	await _jump_to_hand(b, KEYS_2, a)
	check(b.grab_target == a and a.grab_target == hook2, "Б в прыжке схватился за руку А — цепь (%s)" % b.global_position)
	# Цепь качают оба ≈ 4 с; нижний прыгает на взлёте правее крюка (замер — решение 37).
	await _swing_off(b, KEYS_2, 39.5 * TILE, [KEYS_1], 240, hook2.global_position.x + 60.0)
	check(b.alive and b.is_on_floor() and b.global_position.x > 36.0 * TILE, "нижний в цепи перелетел шипы (%s)" % b.global_position)
	# Верхний после рывка нижнего сначала успокаивается, потом раскачивается один.
	await _calm_on_grab(a, KEYS_1)
	check(a.grab_target == hook2 and a.velocity.length() < 20.0, "А успокоился на крюке (%s)" % a.global_position)
	await _swing_off(a, KEYS_1, 37.5 * TILE, [], 240)
	check(a.alive and a.is_on_floor() and a.global_position.x > 36.0 * TILE, "А один раскачался на крюке и перелетел (%s)" % a.global_position)
	# Комната 3: широкие шипы. Чекпоинт берётся, когда дошли оба.
	await _walk_to(b, KEYS_2, 40.0 * TILE)
	await _walk_to(a, KEYS_1, 39.0 * TILE)
	check(game.level.active_checkpoint == 1, "оба в комнате 3 — чекпоинт взят")
	# Ложный путь: 6 тайлов с разбега не перепрыгнуть.
	var jumper := b if b.global_position.x > a.global_position.x else a
	await _walk_to(jumper, _keys(jumper), 43.0 * TILE)
	await _run_jump(jumper, _keys(jumper), 45.0 * TILE)
	check(await _dies(jumper), "6 тайлов шипов с разбега не перепрыгнуть — %s погиб" % jumper.name)
	await _respawned()
	check(a.global_position.x > 37.0 * TILE and b.global_position.x > 37.0 * TILE,
			"оба у чекпоинта перед шипами (a %s b %s)" % [a.global_position, b.global_position])
	# Передний прыгает в шипы и замирает — камень; задний по его голове на тот берег и на плиту
	# моста; мост выдвигается под камнем, камень переходит по нему.
	# Камень прыгает, не добегая до края: иначе замрёт дальше, чем допрыгнет второй.
	var stone := b if b.global_position.x > a.global_position.x else a
	var runner := a if stone == b else b
	var ks := _keys(stone)
	var kr := _keys(runner)
	await _walk_to(stone, ks, 41.0 * TILE)
	await _walk_to(runner, kr, 39.0 * TILE)
	await _walk_to(stone, ks, 43.0 * TILE)
	press(ks[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		if stone.global_position.x >= 44.2 * TILE:
			break
	press(ks[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		# Замирает чуть выше берега: мост, выдвигаясь вровень с берегом, пройдёт под ним.
		if stone.velocity.y > 0.0 and stone.global_position.y + Player.SIZE.y / 2.0 >= 11.0 * TILE:
			break
	tap(ks[FREEZE])
	press(ks[JUMP], false)
	press(ks[RIGHT], false)
	await frames(30)
	check(stone.alive and stone.frozen, "%s замер над шипами — камень (%s)" % [stone.name, stone.global_position])
	var landed := await _run_onto(runner, kr, stone, 44.8 * TILE)
	check(landed, "%s с разбега на голове камня над шипами (%s)" % [runner.name, runner.global_position])
	await _hop_exact(runner, 52.5 * TILE)
	await _walk_to(runner, kr, 53.5 * TILE)
	check(runner.alive and runner.is_on_floor() and runner.global_position.x > 53.0 * TILE,
			"по голове камня — на тот берег, на плиту (%s)" % runner.global_position)
	check(game.level.active_checkpoint < 2, "чекпоинт за шипами не взят, пока там один")
	# Плита выдвигает из скалы мост под камнем; камень оживает, падает на мост и переходит.
	var bridge: Door = game.level.get_node("Bridge3")
	for i in 120:
		if bridge.global_position.x <= 45.05 * TILE:
			break
		await get_tree().physics_frame
	check(bridge.global_position.x <= 45.05 * TILE, "мост выдвинулся под камнем (%.0f)" % bridge.global_position.x)
	tap(ks[FREEZE])
	await frames(20)
	check(stone.alive and stone.is_on_floor(), "%s ожил — стоит на мосту над шипами (%s)" % [stone.name, stone.global_position])
	await _walk_to(stone, ks, 52.5 * TILE)
	await _walk_to(runner, kr, 55.0 * TILE)
	await _walk_to(stone, ks, 54.0 * TILE)
	check(stone.global_position.x > 53.0 * TILE and game.level.active_checkpoint == 2, "%s перешёл по мосту — оба за шипами, чекпоинт взят" % stone.name)
	await _both_to_finish()


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


## 20 «Старый мост» (экзамен мира, очень сложный): как прежний 20, но чекпоинты — только старт
## и перед цепью, а со второй половины ползёт обвал.
## 20 «Старый мост» — экзамен мира, пять участков: бросок качелей (12), обратная дверь и ступенька
## в воздухе над её плитой (17), высокий крюк и цепь над шипами (14), пресс (17) и погоня:
## последний мост рушится за спиной, просыпается призрак, выходная дверь медленно закрывается,
## а перед ней уступ в 3 тайла — живой лестницей.
func _w20() -> void:
	var level: GreyboxLevel = game.level
	# 1. Бросок качелей: Б на опущенном конце, А прыгает с насеста — Б на башне.
	var seesaw1: Seesaw = level.get_node("Seesaw1")
	var beam1 := seesaw1.get_beam()
	var step: Door = level.get_node("Step")
	var step_latch: PressurePlate = level.get_node("StepLatch")
	await _run_to(b, 12.0 * TILE)
	await _walk_to(b, KEYS_2, 13.6 * TILE)
	await frames(40)
	await _walk_to(b, KEYS_2, 19.0 * TILE)
	await frames(30)
	check(seesaw1.angle > seesaw1.max_angle() - 0.01 and Weight.floor_below(b) == beam1, "1: Б на опущенном конце у башни")
	await _run_to(a, 12.0 * TILE)
	await _walk_to(a, KEYS_1, 13.6 * TILE, 30)
	for i in 150:
		await get_tree().physics_frame
		press(KEYS_2[RIGHT], b.velocity.y < -200.0 or not b.is_on_floor())
		if i > 30 and b.is_on_floor():
			break
	press(KEYS_2[RIGHT], false)
	await frames(10)
	check(b.is_on_floor() and b.global_position.y < 7 * TILE, "1: А прыгнул с насеста — Б на башне (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, step_latch.global_position.x)
	await frames(30)
	check(step_latch.active, "1: Б выдвинул ступеньку")
	await _walk_to(a, KEYS_1, 19.5 * TILE)
	await frames(20)
	await _hop_to(a, 21.2 * TILE, 14)
	await _walk_to(b, KEYS_2, 22.35 * TILE)
	await _pull_up(b, a, RIGHT)
	await frames(20)
	check(a.global_position.y < 7 * TILE, "1: Б вытянул А на башню (a %s)" % a.global_position)

	# 2. Обратная дверь: плиту в 6 тайлов проходят по голове замершего, прошедший жмёт защёлку.
	var plate2: PressurePlate = level.get_node("Plate2")
	var door2: Door = level.get_node("Door2")
	var latch2: PressurePlate = level.get_node("Latch2")
	await _run_to(b, 31.0 * TILE)
	await _run_to(a, 30.2 * TILE)
	pass  # чекпоинтов после башни нет (очень сложный)
	place(a, Vector2(36.5 * TILE, _stand_y(11)))
	place(b, Vector2(33.4 * TILE, _stand_y(11)))
	await frames(10)
	var crossed := await _air_step(a, KEYS_1, b, KEYS_2, 39.0 * TILE, 45.7 * TILE, 12.0 * TILE, 30.0, 360.0)
	check(crossed and not plate2.active, "2: Б по голове замершего над плитой (b %s)" % b.global_position)
	await _walk_to(b, KEYS_2, latch2.global_position.x)
	tap(KEYS_1[FREEZE])
	await frames(60)
	check(latch2.active and plate2.active and door2.global_position.y < 7.0 * TILE, "2: защёлка держит обратную дверь, А на плите")
	await _walk_to(a, KEYS_1, 50.0 * TILE)

	# 3. Высокий крюк и цепь над шипами.
	var hook: Hook = level.get_node("Hook")
	await _walk_to(b, KEYS_2, 59.55 * TILE)
	await _walk_to(a, KEYS_1, 57.6 * TILE)
	check(level.active_checkpoint == 1, "3: чекпоинт у шипов — единственный в середине")
	await _onto_head(a, b)
	check(await _hop_to_hook(a, KEYS_1, hook), "3: А с головы Б на высоком крюке")
	await _jump_to_hand(b, KEYS_2, a)
	check(b.grab_target == a and a.grab_target == hook, "3: цепь")
	await _swing_off(b, KEYS_2, 73.5 * TILE, [KEYS_1], 240, hook.global_position.x + 60.0)
	check(b.alive and b.is_on_floor() and b.global_position.x > 70.0 * TILE, "3: нижний в цепи перелетел шипы (%s)" % b.global_position)
	await _calm_on_grab(a, KEYS_1)
	await _swing_off(a, KEYS_1, 71.5 * TILE, [], 240)
	check(a.alive and a.is_on_floor() and a.global_position.x > 70.0 * TILE, "3: А один раскачался и перелетел (%s)" % a.global_position)

	# 4. Пресс: Б замирает в прыжке под ним, А проходит под Б и жмёт защёлку.
	var crusher: Press = level.get_node("Press")
	var stop: PressurePlate = level.get_node("StopLatch")
	await _run_to(b, 80.0 * TILE)
	await _run_to(a, 79.2 * TILE)
	check(true, "4: у пресса%s" % _lag_note())
	await _walk_to(b, KEYS_2, 82.0 * TILE)
	await _press_up(crusher)
	await _walk_to(b, KEYS_2, 83.8 * TILE)
	press(KEYS_2[JUMP], true)
	for i in 30:
		await get_tree().physics_frame
		if b.global_position.y + Player.SIZE.y / 2.0 <= 12.0 * TILE - 80.0:
			break
	tap(KEYS_2[FREEZE])
	press(KEYS_2[JUMP], false)
	await frames(3)
	check(b.frozen, "4: Б замер в прыжке под прессом")
	await frames(90)
	await _run_to(a, stop.global_position.x)
	check(a.alive and b.alive and stop.active, "4: А прошёл под замершим и нажал защёлку пресса")
	await frames(120)
	tap(KEYS_2[FREEZE])
	await frames(30)

	# 5. Погоня. Оба вплотную по последнему мосту; первый наступил на защёлку — мост рушится,
	# дверь начинает закрываться, призрак сзади.
	var bridge: Door = level.get_node("LastBridge")
	var chase: PressurePlate = level.get_node("ChaseLatch")
	var exit_door: Door = level.get_node("ExitDoor")
	var ghost: Ghost = level.get_node("Ghost")
	await _run_to(b, 101.6 * TILE)
	await _run_to(a, 100.8 * TILE)
	check(deaths == 0, "5: перед последним мостом (смертей %d)%s" % [deaths, _lag_note()])
	press(KEYS_2[RIGHT], true)
	press(KEYS_1[RIGHT], true)
	var started := -1
	for i in 300:
		await get_tree().physics_frame
		if started < 0 and chase.active:
			started = i
		if a.global_position.x > 119.0 * TILE:
			press(KEYS_1[RIGHT], false)
		if b.global_position.x > 119.6 * TILE:
			press(KEYS_2[RIGHT], false)
		if a.global_position.x > 118.4 * TILE and b.global_position.x > 119.3 * TILE:
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(10)
	check(chase.active and a.alive and b.alive, "5: оба перебежали мост, защёлка нажата")
	check(bridge.global_position.y > 13.0 * TILE, "5: мост за спиной рухнул (%s)" % bridge.global_position)
	var open_y := 3.0 * TILE
	check(exit_door.global_position.y > open_y + 4.0, "5: выходная дверь закрывается (%s)" % exit_door.global_position)
	var chase_from := Engine.get_physics_frames()
	# Уступ 3 тайла: Б (впереди) — опора лицом к призраку, А с его головы наверх, потом вытягивает.
	await _walk_to(b, KEYS_2, 119.6 * TILE)
	await _face(b, LEFT)
	await _onto_head(a, b)
	await _jump(a, KEYS_1, RIGHT, 40)
	check(a.is_on_floor() and a.global_position.y < 9 * TILE, "5: А с головы Б на уступе")
	await _walk_to(a, KEYS_1, 120.35 * TILE)
	await _pull_up(a, b, RIGHT)
	check(b.is_on_floor() and b.global_position.y < 9 * TILE, "5: А вытянул Б на уступ")
	# Оба бегут к двери; просвет под ней — в тот миг, когда под ней пробегает последний.
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	var gap := 0.0
	var passed_at := 0.0
	for i in 300:
		await get_tree().physics_frame
		if a.global_position.x > 127.5 * TILE:
			press(KEYS_1[RIGHT], false)
		if b.global_position.x > 127.0 * TILE:
			press(KEYS_2[RIGHT], false)
		if passed_at == 0.0 and minf(a.global_position.x, b.global_position.x) > 126.0 * TILE:
			passed_at = (Engine.get_physics_frames() - chase_from) / 60.0
			gap = 9.0 * TILE - (exit_door.global_position.y + 3.0 * TILE)
		if a.global_position.x > 127.5 * TILE and b.global_position.x > 127.0 * TILE:
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	check(a.alive and b.alive and passed_at > 0.0,
			"5: оба успели в закрывающуюся дверь через %.1f с после защёлки, просвет под дверью %.0f px" % [passed_at, gap])
	check(deaths == 0, "экзамен без гибели (смертей %d)" % deaths)
	await _both_to_finish()
## Повернуться лицом в сторону side: короткое касание направления.
func _face(p: Player, side: int) -> void:
	var k := _keys(p)
	press(k[side], true)
	await frames(1)
	press(k[side], false)
	await frames(2)


# --- Приёмы --------------------------------------------------------------------------------

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


## 19 «Пилорама»: три пилы по полу; пила над ямой; катапульта на стену с пилой по верху
## и вытягивание; ступенька в воздухе над пропастью под вертикальными пилами; выход — две кнопки
## под пилами в одно окно.
func _w19() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	# 1. Три пилы по полу; между рельсами — промежутки, где можно переждать.
	for who: Player in [b, a]:
		await _settle(who, 3.4, 12)
		for gap: Array in [[1, 8.75], [2, 13.75], [3, 19.0 if who == b else 18.4]]:
			var saw: Saw = level.get_node("Saw%d" % gap[0])
			await _wait_saw_coming(saw)
			await _run_dodging(who, _keys(who), gap[1])
	check(deaths == before and a.global_position.x > 18.0 * TILE, "1: три пилы позади (a %s b %s)" % [a.global_position, b.global_position])
	# 2. Пила над ямой: прыгать, когда пила в середине хода и едет вперёд.
	var sp: Saw = level.get_node("SawPit")
	for who: Player in [b, a]:
		await _settle(who, 19.5, 12)
		for i in 300:
			if sp.forward and sp.progress >= 0.5 and sp.progress < 0.55:
				break
			await get_tree().physics_frame
		await _jump_gate(who, _keys(who), 19.85)
		await _walk_to(who, _keys(who), (26.0 if who == b else 24.5) * TILE)
	check(deaths == before and a.global_position.x > 22.2 * TILE, "2: оба проскочили под пилой над ямой (a %s b %s)" % [a.global_position, b.global_position])
	# 3. Стена: Б замирает у стены, А на него — катапульта, когда пила на дальнем конце верха;
	# А вытягивает Б, пока пила не вернулась.
	var sw: Saw = level.get_node("SawWall")
	await _settle(b, 29.3, 12)
	await _settle(a, 28.0, 12)
	tap(KEYS_2[FREEZE])
	await frames(3)
	await _hop_exact(a, 29.3 * TILE)
	check(a.standing_on() == b, "3: А на замершем Б у стены (%s)" % a.global_position)
	for i in 400:
		if sw.forward and sw.progress > 0.55 and sw.progress < 0.6:
			break
		await get_tree().physics_frame
	await _catapult(b, KEYS_2, a, KEYS_1, RIGHT)
	check(a.alive and a.is_on_floor() and a.global_position.y < 8.5 * TILE, "3: катапульта — А на стене (%s)" % a.global_position)
	tap(KEYS_2[FREEZE])
	await frames(5)
	# А ждёт у края стены (пила туда не доходит), ловит Б, когда пила уехала от края, и тянет;
	# потом оба бегут вправо, перепрыгивая вернувшуюся пилу.
	await _settle(a, 30.45, 8.5)
	press(KEYS_1[LEFT], true)
	await frames(2)
	press(KEYS_1[LEFT], false)
	for i in 400:
		if sw.forward and sw.progress > 0.02 and sw.progress < 0.08:
			break
		await get_tree().physics_frame
	await _catch_and_pull(a, KEYS_1, b, KEYS_2, 8.5)
	check(deaths == before and b.global_position.y < 8.5 * TILE, "3: А вытянул Б на стену под пилой (%s)" % b.global_position)
	_run_dodging(b, KEYS_2, 40.0)
	await frames(6)
	await _run_dodging(a, KEYS_1, 39.0)
	await frames(30)
	check(level.active_checkpoint == 1 and deaths == before, "чекпоинт посередине (смертей %d)" % (deaths - before))
	# 4. Ступенька в воздухе над пропастью под вертикальными пилами.
	await _settle(b, 42.6, 12)
	await _settle(a, 41.0, 12)
	var ok := await _step_in_air(b, KEYS_2, a, KEYS_1, 45.0, 48.55, 49.6)
	check(ok, "4: А перепрыгнул пропасть по замершему Б под пилами (a %s b %s)" % [a.global_position, b.global_position])
	await _walk_to(a, KEYS_1, 49.75 * TILE)
	press(KEYS_1[LEFT], true)
	await frames(2)
	press(KEYS_1[LEFT], false)
	press(KEYS_1[GRAB], true)
	await frames(4)
	tap(KEYS_2[FREEZE])
	await frames(6)
	press(KEYS_1[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		var feet := b.global_position.y + Player.SIZE.y / 2.0
		press(KEYS_1[RIGHT], feet > 12.0 * TILE - 4.0)
		if b.is_on_floor() and b.global_position.y < 12.0 * TILE:
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_1[GRAB], false)
	await frames(10)
	check(deaths == before and b.global_position.y < 12 * TILE, "4: А вытянул Б из пропасти (%s)" % b.global_position)
	# 5. Выход: обе кнопки под пилами в одно окно — когда обе пилы наверху.
	var sa: Saw = level.get_node("SawExitA")
	var sb: Saw = level.get_node("SawExitB")
	await _settle(a, 68.9, 12)
	await _settle(b, 72.9, 12)
	for i in 600:
		if sa.progress < 0.2 and sb.progress < 0.35:
			break
		await get_tree().physics_frame
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 30:
		await get_tree().physics_frame
		press(KEYS_1[RIGHT], a.global_position.x < 70.0 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 74.0 * TILE)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(10)
	await _walk_to(a, KEYS_1, 71.2 * TILE)
	await _walk_to(b, KEYS_2, 75.2 * TILE)
	await frames(30)
	check(deaths == before and level.get_node("Exit").get("_latched"), "5: обе кнопки под пилами в окно — выход открыт")
	await _both_to_finish()
