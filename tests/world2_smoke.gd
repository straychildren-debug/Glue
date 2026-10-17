extends LevelBot
## Автопроверка механизмов мира 2 «Мастерские» в комнате levels/workshop_lab.tscn:
## конвейер, пружинный батут, ломкий настил, поворотная платформа, меха, кран-тележка,
## искра на проводе с бочонком и треснувшей стеной, жук-толкатель.
## Запуск: Godot_console --headless --fixed-fps 60 --path . res://tests/world2_smoke.tscn

var deaths := 0
var camera: SharedCamera


func _ready() -> void:
	game = await start_game(preload("res://levels/workshop_lab.tscn"))
	camera = game.get_node("SharedCamera")
	a = game.players[0]
	b = game.players[1]
	for p: Player in [a, b]:
		p.died.connect(func(_who: Player) -> void: deaths += 1)
	await _conveyor()
	await _spring()
	await _brittle()
	await _spinner()
	await _bellows()
	await _crane()
	await _spark()
	await _beetle()
	finish()


func _teleport(p: Player, p_at: Vector2, q: Player, q_at: Vector2) -> void:
	if not (a.alive and b.alive):
		await _respawned()  # прошлая проверка кончилась гибелью — дождаться общего респавна
	camera.snap_to((p_at + q_at) / 2.0)
	await frames(1)
	place(p, p_at)
	place(q, q_at)
	await frames(1)
	# Ещё раз: сошедший с ленты получает её скорость (скорость опоры при отрыве).
	place(p, p_at)
	place(q, q_at)
	camera.snap_to((p_at + q_at) / 2.0)
	await frames(10)


func _set_frozen(p: Player, value: bool) -> void:
	if p.frozen != value:
		tap(_keys(p)[FREEZE])
		await frames(2)


func _conveyor() -> void:
	print("Конвейер")
	var belt: Conveyor = game.level.get_node("Conveyor")
	var lever: Lever = game.level.get_node("ConveyorLever")
	var crate: Crate = game.level.get_node("ConveyorCrate")
	var top := belt.global_position.y
	var start := crate.global_position.x
	await frames(30)
	check(crate.global_position.x > start + 100.0, "лента везёт ящик (%.0f → %.0f)" % [start, crate.global_position.x])
	# Стоящий едет; бегущий против ленты стоит на месте.
	await _teleport(a, Vector2(7 * TILE, top - 29.0), b, Vector2(2 * TILE, _stand_y(12)))
	var x0 := a.global_position.x
	await frames(30)
	check(a.global_position.x > x0 + 120.0, "стоящего лента везёт (%.0f → %.0f)" % [x0, a.global_position.x])
	await _teleport(a, Vector2(9 * TILE, top - 29.0), b, Vector2(2 * TILE, _stand_y(12)))
	x0 = a.global_position.x
	press(KEYS_1[LEFT], true)
	await frames(40)
	press(KEYS_1[LEFT], false)
	check(absf(a.global_position.x - x0) < 40.0, "бегущий против ленты стоит на месте (%.0f → %.0f)" % [x0, a.global_position.x])
	# Замерший едет как груз и везёт стоящего на нём.
	await _teleport(a, Vector2(7 * TILE, top - 29.0), b, Vector2(2 * TILE, _stand_y(12)))
	await _set_frozen(a, true)
	await _onto_head(b, a)
	x0 = a.global_position.x
	var bx := b.global_position.x
	await frames(20)
	check(a.frozen and a.global_position.x > x0 + 80.0, "замерший едет по ленте (%.0f → %.0f)" % [x0, a.global_position.x])
	check(b.standing_on() == a and b.global_position.x > bx + 80.0, "стоящий на замершем едет с ним")
	await _set_frozen(a, false)
	# Рычаг разворачивает ленту.
	lever.active = true
	await _teleport(a, Vector2(10 * TILE, top - 29.0), b, Vector2(2 * TILE, _stand_y(12)))
	x0 = a.global_position.x
	await frames(30)
	check(a.global_position.x < x0 - 120.0, "рычаг развернул ленту (%.0f → %.0f)" % [x0, a.global_position.x])
	lever.active = false


func _spring() -> void:
	print("Пружинный батут")
	var pad: SpringPad = game.level.get_node("Spring")
	var ledge_top := 7.0 * TILE
	# Падение на батут подбрасывает выше обычного прыжка.
	await _teleport(a, Vector2(pad.global_position.x, 8.0 * TILE), b, Vector2(15 * TILE, _stand_y(12)))
	var best := INF
	for i in 70:
		await get_tree().physics_frame
		if i > 15:
			best = minf(best, a.global_position.y)
	var rise := 12.0 * TILE - 22.0 - (best + Player.SIZE.y / 2.0)
	check(rise > 180.0, "отскок с батута выше прыжка (%.0f px)" % rise)
	await frames(60)
	# Замерший на батуте — взведённая пружина; ожил — оба улетают выше уступа.
	await _teleport(a, Vector2(pad.global_position.x, _stand_y(12) - 22.0), b, Vector2(15 * TILE, _stand_y(12)))
	await frames(20)
	await _set_frozen(a, true)
	await frames(5)
	check(pad.is_charged(), "замерший взвёл пружину")
	await _onto_head(b, a)
	await _set_frozen(a, false)
	var top_a := INF
	var top_b := INF
	for i in 50:
		await get_tree().physics_frame
		top_a = minf(top_a, a.global_position.y)
		top_b = minf(top_b, b.global_position.y)
	check(top_a < ledge_top - 40.0 and top_b < ledge_top - 40.0,
			"ожил — выстрел: оба выше уступа (a %.0f b %.0f, уступ %.0f)" % [top_a, top_b, ledge_top])
	await frames(90)


func _brittle() -> void:
	print("Ломкий настил")
	var floor: BrittleFloor = game.level.get_node("Brittle")
	var y := floor.global_position.y - Player.SIZE.y / 2.0 - 1.0
	await _teleport(a, Vector2(28 * TILE, y), b, Vector2(25 * TILE, _stand_y(12)))
	await frames(30)
	check(not floor.broken and a.alive, "одного настил держит")
	await _walk_to(a, KEYS_1, 34.5 * TILE)
	check(not floor.broken and a.global_position.x > 33 * TILE, "один перешёл по настилу")
	# Замерший в воздухе ничего не весит: второй стоит на его голове над настилом.
	await _teleport(a, Vector2(25 * TILE, _stand_y(12)), b, Vector2(28 * TILE, y))
	place(a, Vector2(30 * TILE, y - 40.0))
	tap(KEYS_1[FREEZE])  # замирает в воздухе в том же кадре
	await frames(10)
	await _onto_head(b, a)
	await frames(20)
	check(not floor.broken, "замерший в воздухе не весит: настил цел под стоящим на нём")
	await _set_frozen(a, false)
	await frames(20)
	# Двое на настиле — рушится.
	await _teleport(a, Vector2(29 * TILE, y), b, Vector2(31 * TILE, y))
	await frames(30)
	check(floor.broken, "под двумя настил рухнул")
	await _respawned()
	check(not floor.broken, "после общего респавна настил снова цел")


func _spinner() -> void:
	print("Поворотная платформа")
	var spinner: Spinner = game.level.get_node("Spinner")
	var lever: Lever = game.level.get_node("SpinnerLever")
	await _teleport(a, Vector2(lever.global_position.x + 10.0, _stand_y(12)), b, Vector2(33 * TILE, _stand_y(12)))
	await hold(KEYS_1[GRAB], 3)
	check(lever.active, "рычаг включён")
	await frames(60)
	check(absf(spinner.rotation_degrees - 90.0) < 1.0, "балка повернулась на 90° (%.1f)" % spinner.rotation_degrees)
	await hold(KEYS_1[GRAB], 3)
	await frames(60)
	check(absf(spinner.rotation_degrees) < 1.0, "и обратно (%.1f)" % spinner.rotation_degrees)
	# Замерший на балке поворачивается вместе с ней.
	await _teleport(a, Vector2(spinner.global_position.x + 80.0, spinner.global_position.y - 12.0 - 29.0), b, Vector2(34 * TILE, _stand_y(12)))
	await frames(10)
	await _set_frozen(a, true)
	await hold(KEYS_2[GRAB], 3)  # Б не у рычага — рычаг жмём сами
	lever.active = true
	await frames(60)
	var offset := a.global_position - spinner.global_position
	check(offset.y > 50.0 and absf(offset.x) < 50.0, "замерший повернулся с балкой (%s)" % offset)
	lever.active = false
	await frames(60)
	await _set_frozen(a, false)
	await frames(30)


func _bellows() -> void:
	print("Меха")
	var bellows: Bellows = game.level.get_node("Bellows")
	var pedal: PressurePlate = game.level.get_node("Pedal")
	# Без мехов пропасть в 8 тайлов не перепрыгнуть.
	await _teleport(a, Vector2(42.8 * TILE, _stand_y(12)), b, Vector2(36 * TILE, _stand_y(12)))
	await _run_jump(a, KEYS_1, 44 * TILE)
	check(await _dies(a), "без ветра — в пропасть")
	await _respawned()
	# Б прыгает на педаль, А сразу прыгает с края — порыв (1 с) несёт его на тот берег.
	await _teleport(a, Vector2(42.8 * TILE, _stand_y(12)), b, Vector2(pedal.global_position.x - 100.0, _stand_y(12)))
	_hop_to(b, pedal.global_position.x)
	for i in 60:
		await get_tree().physics_frame
		if bellows.is_blowing():
			break
	check(bellows.is_blowing(), "Б прыгнул на педаль — дует")
	press(KEYS_1[RIGHT], true)
	for i in 200:
		if a.global_position.x >= 44 * TILE - 12.0:
			break
		await get_tree().physics_frame
	press(KEYS_1[JUMP], true)
	for i in 120:
		await get_tree().physics_frame
		if i > 5 and (a.is_on_floor() or not a.alive):
			break
	press(KEYS_1[JUMP], false)
	press(KEYS_1[RIGHT], false)
	check(a.alive and a.global_position.x > 52 * TILE, "порыв перенёс А через пропасть (%.0f)" % a.global_position.x)
	await frames(30)


func _crane() -> void:
	print("Кран-тележка")
	var crane: Crane = game.level.get_node("Crane")
	var plate: PressurePlate = game.level.get_node("CranePlate")
	var hook := crane.hook
	# А висит на крюке, Б встаёт на плиту — кран везёт А над пропастью.
	await _teleport(a, Vector2(55 * TILE, _stand_y(12)), b, Vector2(53 * TILE, _stand_y(12)))
	press(KEYS_1[GRAB], false)
	await frames(2)
	place(a, hook.global_position + Vector2(0, 80))
	press(KEYS_1[GRAB], true)
	await frames(3)
	check(a.grab_target == hook, "А схватился за крюк крана")
	await _walk_to(b, KEYS_2, plate.global_position.x)
	await frames(10)
	check(plate.active, "Б на плите")
	await frames(240)
	check(hook.global_position.x > 62 * TILE, "крюк уехал к концу рельса (%.0f)" % hook.global_position.x)
	check(a.alive and a.global_position.x > 61 * TILE, "кран перевёз А над пропастью (%.0f)" % a.global_position.x)
	# Висящий отстаёт от крюка и раскачивается: отпускает, когда он над тем берегом.
	for i in 300:
		if a.global_position.x > 63.4 * TILE:
			break
		await get_tree().physics_frame
	press(KEYS_1[GRAB], false)
	await frames(60)
	check(a.alive and a.global_position.x > 63 * TILE and a.is_on_floor(), "А спрыгнул на том берегу")
	await _walk_to(b, KEYS_2, 52.6 * TILE)
	await frames(200)
	check(hook.global_position.x < 57 * TILE, "без плиты крюк вернулся")


func _spark() -> void:
	print("Искра, провод, бочонок")
	var spark: Spark = game.level.get_node("Spark")
	var keg: Keg = game.level.get_node("Keg")
	var wall: CrackedWall = game.level.get_node("CrackedWall")
	# Искра бегает с начала уровня и давно взорвала бочонок — возвращаем всё к началу.
	keg.load_state(Keg.State.READY)
	wall.load_state(false)
	spark.load_state(null)
	# Замерший на проводе — изолятор: искра поворачивает назад и до бочонка не доходит.
	await _teleport(a, Vector2(72 * TILE, _stand_y(12)), b, Vector2(66 * TILE, _stand_y(12)))
	await _set_frozen(a, true)
	await frames(240)
	check(keg.state == Keg.State.READY and spark.global_position.x < 72 * TILE, "искра упёрлась в замершего (x %.0f)" % spark.global_position.x)
	# Ожил на проводе — искра бьёт.
	await _set_frozen(a, false)
	check(await _dies(a), "незамерший на проводе — искра сожгла")
	await _respawned()
	await _teleport(a, Vector2(66 * TILE, _stand_y(12)), b, Vector2(65 * TILE, _stand_y(12)))
	# Провод свободен — искра доходит до бочонка, фитиль горит, стена рушится.
	for i in 400:
		if keg.state != Keg.State.READY:
			break
		await get_tree().physics_frame
	check(keg.state == Keg.State.LIT, "искра подожгла фитиль")
	for i in 200:
		if wall.smashed:
			break
		await get_tree().physics_frame
	check(wall.smashed and keg.state == Keg.State.BLOWN, "взрыв проломил стену")
	check(a.alive and b.alive, "стоявшие поодаль целы")


func _beetle() -> void:
	print("Жук-толкатель")
	var beetle: Beetle = game.level.get_node("Beetle")
	var plate: PressurePlate = game.level.get_node("BeetlePlate")
	var top := 10.0 * TILE
	# Жук ходит по уступу и разворачивается у краёв.
	var turns := 0
	var last_dir := beetle.direction
	var min_x := INF
	var max_x := -INF
	await _teleport(a, Vector2(80 * TILE, _stand_y(12)), b, Vector2(79 * TILE, _stand_y(12)))
	var plate_seen := false
	for i in 600:
		await get_tree().physics_frame
		min_x = minf(min_x, beetle.global_position.x)
		max_x = maxf(max_x, beetle.global_position.x)
		plate_seen = plate_seen or plate.active
		if beetle.direction != last_dir:
			turns += 1
			last_dir = beetle.direction
	check(turns >= 2 and min_x > 84 * TILE and max_x < 92 * TILE, "жук ходит по уступу и не падает (%.0f…%.0f, разворотов %d)" % [min_x, max_x, turns])
	check(plate_seen, "жук на плите — плита нажата (весит 1)")
	# На жуке можно ехать.
	await frames(30)
	await _teleport(a, beetle.global_position + Vector2(0, -60.0), b, Vector2(79 * TILE, _stand_y(12)))
	await frames(10)
	var on := Weight.floor_below(a) == beetle
	var x0 := a.global_position.x
	var bx0 := beetle.global_position.x
	await frames(20)
	var moved := beetle.global_position.x - bx0
	check(on and absf(moved) > 10.0 and absf(a.global_position.x - x0 - moved) < 8.0,
			"А едет на жуке (А %.0f, жук %.0f)" % [a.global_position.x - x0, moved])
	await frames(30)
	# Игрок перед жуком: жук толкает его и спихивает с уступа.
	var ahead := 1.0 if beetle.direction > 0 else -1.0
	var edge_x := 92.0 * TILE if ahead > 0 else 84.0 * TILE
	await _teleport(a, Vector2(beetle.global_position.x + ahead * 70.0, top - 29.0), b, Vector2(79 * TILE, _stand_y(12)))
	for i in 360:
		await get_tree().physics_frame
		if a.global_position.y > top + 40.0:
			break
	check(a.global_position.y > top + 40.0, "жук спихнул А с уступа (%s)" % a.global_position)
	await frames(30)
	# Замерший останавливает жука: тот разворачивается.
	ahead = 1.0 if beetle.direction > 0 else -1.0
	await _teleport(a, Vector2(beetle.global_position.x + ahead * 90.0, top - 29.0), b, Vector2(79 * TILE, _stand_y(12)))
	await _set_frozen(a, true)
	var dir_before := beetle.direction
	var ax := a.global_position.x
	for i in 90:
		await get_tree().physics_frame
		if beetle.direction != dir_before:
			break
	check(beetle.direction != dir_before and absf(a.global_position.x - ax) < 2.0, "замерший — стена для жука")
	await _set_frozen(a, false)
