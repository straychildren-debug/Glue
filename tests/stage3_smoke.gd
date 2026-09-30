extends SmokeTest
## Автопроверка этапа 3: ящики, вес, нажимная плита, дверь, качели, сброс механизмов к чекпоинту.
## Запуск: Godot_console --headless --path . res://tests/stage3_smoke.tscn
## Уровень tests/stage3_room.tscn: пол 0–48 тайлов, пропасть 48–52, пол 52–80.
## Ящик — x 6,5; тяжёлый ящик — x 14,5; плита — x 22 (дверь x 26); защёлка — x 30; качели — x 38.

const ROOM := preload("res://tests/stage3_room.tscn")
const SANDBOX := preload("res://levels/sandbox.tscn")
const TILE := 64.0
const FLOOR_Y := 12 * TILE - Player.SIZE.y / 2.0 - 1.0

var game: Node
var camera: SharedCamera


func _ready() -> void:
	game = await start_game(ROOM)
	camera = game.get_node("SharedCamera")
	var p1: Player = game.players.get(0)
	var p2: Player = game.players.get(1)
	if p1 == null or p2 == null:
		check(false, "оба игрока подключились")
		return finish()
	var level: GreyboxLevel = game.level
	var crate: Crate = level.get_node("Crate")
	var heavy: Crate = level.get_node("HeavyCrate")
	var plate: PressurePlate = level.get_node("Plate")
	var door: Door = level.get_node("Door")
	var latch: PressurePlate = level.get_node("LatchPlate")
	var seesaw: Seesaw = level.get_node("Seesaw")
	var crate_home := crate.global_position

	# --- Ящик толкается одним игроком.
	await _teleport(p1, Vector2(crate.global_position.x - 70.0, FLOOR_Y), p2, Vector2(3 * TILE, FLOOR_Y))
	var crate_x := crate.global_position.x
	await hold(KEY_D, 60)
	check(crate.global_position.x > crate_x + 100.0,
			"игрок толкнул ящик на %.0f px" % (crate.global_position.x - crate_x))

	# --- Тяжёлый ящик: одному не сдвинуть, вдвоём паровозиком — можно.
	await _teleport(p1, Vector2(heavy.global_position.x - 60.0, FLOOR_Y), p2, Vector2(heavy.global_position.x - 120.0, FLOOR_Y))
	var heavy_x := heavy.global_position.x
	await hold(KEY_D, 60)
	check(absf(heavy.global_position.x - heavy_x) < 2.0, "один игрок не сдвинул тяжёлый ящик")
	press(KEY_D, true)
	press(KEY_RIGHT, true)
	await frames(60)
	press(KEY_D, false)
	press(KEY_RIGHT, false)
	check(heavy.global_position.x > heavy_x + 80.0,
			"вдвоём паровозиком сдвинули тяжёлый ящик на %.0f px" % (heavy.global_position.x - heavy_x))

	# --- Плита и дверь: встал — дверь открылась, ушёл — закрылась.
	var plate_top := plate.global_position.y - PressurePlate.RAISED - Player.SIZE.y / 2.0 - 1.0
	var door_closed_y := door.global_position.y
	await _teleport(p1, Vector2(plate.global_position.x, plate_top - 10.0), p2, Vector2(18 * TILE, FLOOR_Y))
	await frames(40)
	check(plate.active and is_equal_approx(plate.current_load, 1.0), "игрок нажал плиту (нагрузка %.1f)" % plate.current_load)
	check(door.global_position.y < door_closed_y - 150.0, "дверь открылась")
	place(p1, Vector2(18 * TILE - 60.0, FLOOR_Y))
	await frames(60)
	check(not plate.active and is_equal_approx(door.global_position.y, door_closed_y), "ушёл с плиты — дверь закрылась")

	# --- Ящик на плите держит дверь сам.
	crate.global_position = Vector2(plate.global_position.x, plate_top - 20.0)
	await frames(40)
	check(plate.active and door.global_position.y < door_closed_y - 150.0, "ящик на плите держит дверь открытой")
	crate.global_position = crate_home
	await frames(40)

	# --- Вес стопкой: игрок 2 стоит на замершем игроке 1, оба давят на плиту.
	await _teleport(p1, Vector2(plate.global_position.x, plate_top - 4.0), p2, Vector2(18 * TILE, FLOOR_Y))
	await frames(20)
	tap(KEY_S)
	await frames(2)
	place(p2, p1.global_position + Vector2(0, -Player.SIZE.y - 4.0))
	await frames(20)
	check(is_equal_approx(plate.current_load, 2.0), "стопка из двух игроков давит на плиту: %.1f" % plate.current_load)
	tap(KEY_S)
	place(p2, Vector2(18 * TILE, FLOOR_Y))
	await frames(10)

	# --- Дверь не давит: закрываясь, останавливается над игроком.
	await frames(30)
	check(plate.active, "игрок 1 держит плиту")
	place(p2, Vector2(door.global_position.x + TILE / 2.0, FLOOR_Y))
	await frames(10)
	place(p1, Vector2(18 * TILE - 60.0, FLOOR_Y))
	await frames(60)
	var door_bottom := door.global_position.y + 3 * TILE
	check(p2.alive and door_bottom <= p2.global_position.y - Player.SIZE.y / 2.0 + 1.0
			and door.global_position.y > door_closed_y - 3 * TILE + 10.0,
			"дверь опустилась до игрока под ней и остановилась")
	place(p2, Vector2(28 * TILE, FLOOR_Y))
	await frames(60)
	check(is_equal_approx(door.global_position.y, door_closed_y), "игрок ушёл — дверь закрылась до конца")

	# --- Качели: игрок на поднятом конце перевешивает балку.
	var pivot := seesaw.global_position
	var half := seesaw.length_tiles * TILE / 2.0
	check(seesaw.angle < -seesaw.max_angle() + 0.01, "качели стоят левым концом вниз")
	await _teleport(p1, Vector2(pivot.x - half - 3 * TILE, FLOOR_Y), p2, pivot + Vector2(half - 40.0, -120.0))
	await frames(90)
	check(seesaw.angle > seesaw.max_angle() - 0.01, "игрок 2 перевесил качели на правую сторону")

	# --- Замерший едет на качелях: игрок 1 замер на опущенном левом конце... сначала вернём наклон.
	place(p2, Vector2(pivot.x + half + 3 * TILE, FLOOR_Y))
	seesaw.load_state(-seesaw.max_angle())
	await frames(5)
	place(p1, pivot + Vector2(-half + 50.0, 20.0 - Player.SIZE.y))
	await frames(20)
	check(Weight.floor_below(p1) == seesaw.get_beam(), "игрок 1 стоит на левом конце качелей")

	# --- Катапульта качелей: игрок 2 прыгает сверху на поднятый правый конец — игрока 1 подбрасывает.
	place(p2, pivot + Vector2(half - 40.0, -5 * TILE))
	var start_y := p1.global_position.y
	var peak_y := start_y
	for i in 90:
		await get_tree().physics_frame
		peak_y = minf(peak_y, p1.global_position.y)
	check(start_y - peak_y > 150.0, "приземление на качели подбросило товарища на %.0f px" % (start_y - peak_y))
	await frames(60)

	# --- Замерший на качелях: едет вместе с балкой и перевешивает её своим весом.
	seesaw.load_state(-seesaw.max_angle())
	await _teleport(p1, pivot + Vector2(-half + 50.0, 20.0 - Player.SIZE.y), p2, Vector2(pivot.x + half + 3 * TILE, FLOOR_Y))
	await frames(20)
	tap(KEY_S)
	await frames(5)
	check(p1.frozen and p1.carrier == seesaw.get_beam(), "игрок 1 замер на качелях")
	var frozen_y := p1.global_position.y
	place(p2, pivot + Vector2(half - 40.0, -5 * TILE))
	await frames(40)
	check(p1.global_position.y < frozen_y - 60.0,
			"замерший поднялся вместе с концом балки на %.0f px" % (frozen_y - p1.global_position.y))
	place(p2, Vector2(pivot.x + half + 3 * TILE, FLOOR_Y))
	await frames(90)
	check(seesaw.angle < -seesaw.max_angle() + 0.01 and p1.frozen,
			"вес замершего вернул качели влево")
	tap(KEY_S)
	await frames(20)

	# --- Катапульта замершего подбрасывает и ящик.
	await _teleport(p1, Vector2(10 * TILE, FLOOR_Y), p2, Vector2(12 * TILE, FLOOR_Y))
	await frames(10)
	tap(KEY_S)
	await frames(2)
	crate.global_position = p1.global_position + Vector2(0, -Player.SIZE.y / 2.0 - 34.0)
	await frames(20)
	var crate_start := crate.global_position.y
	var crate_peak := crate_start
	press(KEY_D, true)
	for i in 40:
		await get_tree().physics_frame
		crate_peak = minf(crate_peak, crate.global_position.y)
	press(KEY_D, false)
	check(crate_start - crate_peak > 150.0, "катапульта замершего подбросила ящик на %.0f px" % (crate_start - crate_peak))
	tap(KEY_S)
	await frames(40)

	# --- Упавший в пропасть ящик возвращается на своё место.
	crate.global_position = Vector2(50 * TILE, 14 * TILE)
	await frames(90)
	check(crate.visible and crate.global_position.distance_to(crate_home) < 4.0, "упавший ящик вернулся на место")

	# --- Общий респавн возвращает механизмы к состоянию чекпоинта.
	var latch_top := latch.global_position.y - PressurePlate.RAISED - Player.SIZE.y / 2.0 - 1.0
	await _teleport(p1, Vector2(latch.global_position.x, latch_top - 4.0), p2, Vector2(latch.global_position.x + 120.0, FLOOR_Y))
	await frames(20)
	check(latch.active, "защёлка нажата")
	place(p1, Vector2(latch.global_position.x - 150.0, FLOOR_Y))
	await frames(20)
	check(latch.active, "защёлка осталась нажатой без нагрузки")
	crate.global_position = Vector2(8 * TILE, FLOOR_Y)
	heavy.global_position = Vector2(20 * TILE, FLOOR_Y)
	place(p2, Vector2(latch.global_position.x, latch_top - 4.0))  # стоит на защёлке, пока товарищ гибнет
	await frames(10)
	p1.global_position.y = level.get_kill_y() + 10.0
	await frames(120)
	check(not latch.active, "после общего респавна защёлка отжата, как при взятии чекпоинта")
	check(p1.global_position.distance_to(level.get_spawn_position(0, 0)) < 8.0
			and p2.global_position.distance_to(level.get_spawn_position(0, 1)) < 8.0,
			"оба появились у чекпоинта, стена кадра не помешала")
	check(crate.global_position.distance_to(crate_home) < 4.0, "ящик вернулся к состоянию чекпоинта")

	# --- Песочница загружается и живёт без ошибок.
	game.queue_free()
	await frames(2)
	game = await start_game(SANDBOX)
	await frames(60)
	var mechanisms: Array = game.level.get_children().filter(func(n: Node) -> bool:
			return n is Crate or n is PressurePlate or n is Door or n is Seesaw)
	check(game.players.size() == 2 and mechanisms.size() == 13,
			"песочница: 2 игрока, %d механизмов" % mechanisms.size())
	finish()


## Переносит обоих игроков и камеру: стены кадра не должны мешать телепорту.
## Стены кадра физика видит на новом месте только со следующего кадра — поэтому сначала камера.
func _teleport(a: Player, a_at: Vector2, b: Player, b_at: Vector2) -> void:
	camera.snap_to((a_at + b_at) / 2.0)
	await frames(1)
	place(a, a_at)
	place(b, b_at)
	camera.snap_to((a_at + b_at) / 2.0)
	await frames(15)
