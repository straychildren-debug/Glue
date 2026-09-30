extends SmokeTest
## Автопроверка этапа 2: «Замри», хват, висение, раскачивание, прыжок с хвата, стены кадра.
## Запуск: Godot_console --headless --path . res://tests/stage2_smoke.tscn
## Уровень tests/stage2_room.tscn: пол 0–20 тайлов, пропасть 20–24, длинный пол 24–80.

const ROOM := preload("res://tests/stage2_room.tscn")
const TILE := 64.0
const FLOOR_Y := 12 * TILE - Player.SIZE.y / 2.0 - 1.0


func _ready() -> void:
	var game: Node = await start_game(ROOM)
	var p1: Player = game.players.get(0)
	var p2: Player = game.players.get(1)
	if p1 == null or p2 == null:
		check(false, "оба игрока подключились")
		return finish()

	# --- «Замри» в воздухе над пропастью: не падает.
	var anchor := Vector2(22 * TILE, 8.5 * TILE)
	tap(KEY_S)
	place(p1, anchor)
	await frames(30)
	check(p1.frozen and p1.global_position.distance_to(anchor) < 3.0, "замерший висит в воздухе неподвижно")

	# --- На замершего можно встать.
	place(p2, anchor + Vector2(0, -Player.SIZE.y - 6.0))
	await frames(20)
	check(p2.is_on_floor() and absf(p2.global_position.y - (anchor.y - Player.SIZE.y)) < 3.0,
			"игрок 2 стоит на замершем")

	# --- Хват сбоку: игрок 2 висит на замершем и раскачивается под ним.
	place(p2, anchor + Vector2(70, 0))
	press(KEY_PERIOD, true)
	await frames(2)
	check(p2.grab_target == p1, "игрок 2 схватился за замершего")
	var length := p2.grab_length
	var max_stretch := 0.0
	var min_x := INF
	var max_y := -INF
	for i in 120:
		await get_tree().physics_frame
		max_stretch = maxf(max_stretch, p2.global_position.distance_to(p1.global_position) - length)
		min_x = minf(min_x, p2.global_position.x)
		max_y = maxf(max_y, p2.global_position.y)
	check(p2.alive and max_stretch < 3.0, "связь не растягивается (запас %.1f px)" % max_stretch)
	check(max_y > anchor.y + length * 0.9, "игрок 2 провисает под якорем")
	check(min_x < anchor.x - length * 0.5, "маятник качнулся на другую сторону (%.0f px)" % (anchor.x - min_x))

	# --- Без ввода маятник не должен сам набирать размах.
	var swing_early := await _measure_swing(p2, p1, 60)
	await frames(120)
	var swing_late := await _measure_swing(p2, p1, 60)
	check(swing_late < swing_early * 1.15 + 5.0,
			"без раскачки размах не растёт сам (%.0f → %.0f px)" % [swing_early, swing_late])

	# --- Раскачивание стиком с места: висит неподвижно под якорем и раскачивается сам.
	await _hang_still(p2, anchor, length)
	var swing_before := await _measure_swing(p2, p1, 30)
	for i in 6:
		await hold(KEY_RIGHT if p2.velocity.x >= 0.0 else KEY_LEFT, 12)
	var swing_after := await _measure_swing(p2, p1, 60)
	check(swing_after > swing_before + 60.0, "раскачка стиком с места (%.0f → %.0f px)" % [swing_before, swing_after])

	# --- Прыжок с хвата из-под якоря: руки разжаты, игрок проходит сквозь товарища
	# и встаёт ему на голову (живая лестница).
	await _hang_still(p2, anchor, length)
	var y_before := p2.global_position.y
	press(KEY_UP, true)  # полный прыжок: кнопку держат, короткое нажатие даёт низкий прыжок
	await frames(4)
	check(p2.grab_target == null and p2.global_position.y < y_before - 20.0,
			"прыжок с хвата: руки разжаты, игрок взлетел на %.0f px" % (y_before - p2.global_position.y))
	press(KEY_PERIOD, false)
	for i in 50:
		if i == 20:
			press(KEY_UP, false)
		await get_tree().physics_frame
	check(p2.is_on_floor() and absf(p2.global_position.y - (anchor.y - Player.SIZE.y)) < 3.0,
			"из-под якоря забрался ему на голову")
	# --- Держат его, а не он: висящий всё равно сам вырывается прыжком.
	place(p2, anchor + Vector2(90, 0))
	press(KEY_E, true)  # замерший игрок 1 держит игрока 2
	await frames(2)
	check(p1.grab_target == p2, "замерший игрок 1 схватил игрока 2")
	await frames(25)
	y_before = p2.global_position.y
	press(KEY_UP, true)
	await frames(4)
	check(p1.grab_target == null and p2.global_position.y < y_before - 20.0,
			"игрок 2 вырвался из чужого хвата прыжком")
	await frames(10)
	check(p1.grab_target == null, "кнопка хвата ещё зажата, но игрок 1 не хватает снова")
	press(KEY_UP, false)
	press(KEY_E, false)

	# Игрок 2 падает в пропасть → общий респавн.
	p2.global_position.y = game.level.get_kill_y() + 10.0
	# Игрок 2 падает в пропасть → общий респавн.
	await frames(120)
	check(p1.alive and p2.alive and not p1.frozen, "после общего респавна оба живы, «Замри» снято")

	# --- Идущий тащит за руку стоящего товарища.
	place(p1, Vector2(6 * TILE, FLOOR_Y))
	place(p2, Vector2(6 * TILE + 60.0, FLOOR_Y))
	await frames(10)
	press(KEY_E, true)  # игрок 1 держится за игрока 2
	await frames(2)
	var p1_x := p1.global_position.x
	await hold(KEY_RIGHT, 40)
	check(p1.grab_target == p2 and p1.global_position.x > p1_x + 40.0,
			"игрок 2 тащит за собой держащегося игрока 1 (%.0f px)" % (p1.global_position.x - p1_x))
	press(KEY_E, false)
	await frames(2)
	check(p1.grab_target == null, "отпустил кнопку — отпустил руку")

	# --- Вытягивание: игрок 1 стоит у края обрыва и держит висящего игрока 2,
	# отходит от края и вытаскивает товарища на платформу.
	var edge := 20 * TILE
	place(p1, Vector2(edge - Player.SIZE.x / 2.0 - 2.0, FLOOR_Y))
	place(p2, Vector2(edge + 30.0, 12 * TILE + 40.0))
	press(KEY_E, true)
	await frames(2)
	check(p1.grab_target == p2, "стоящий у края схватил висящего")
	await frames(20)
	check(p2.global_position.y > 12 * TILE, "игрок 2 висит ниже края обрыва")
	await hold(KEY_A, 70)
	await frames(20)
	check(p2.alive and p2.global_position.x < edge and p2.global_position.y < 12 * TILE,
			"стоящий вытянул товарища на платформу")
	press(KEY_E, false)
	await frames(10)

	# --- Выбраться самому: висящий под стоящим у края прыгает с хвата и залетает на платформу.
	place(p1, Vector2(edge - Player.SIZE.x / 2.0 - 2.0, FLOOR_Y))
	place(p2, Vector2(edge + 30.0, 12 * TILE + 40.0))
	press(KEY_E, true)
	await frames(40)
	press(KEY_UP, true)
	press(KEY_LEFT, true)
	await frames(30)
	press(KEY_UP, false)
	await frames(30)
	press(KEY_LEFT, false)
	press(KEY_E, false)
	check(p2.alive and p2.is_on_floor() and p2.global_position.x < edge,
			"висящий у края сам выпрыгнул на платформу")
	await frames(10)

	# --- Раскачаться под замершим в воздухе и запрыгнуть ему на голову.
	place(p1, anchor)
	await frames(2)
	tap(KEY_S)
	await frames(2)
	place(p2, anchor + Vector2(0, 100))
	press(KEY_PERIOD, true)
	await frames(5)
	for i in 6:
		await hold(KEY_RIGHT if p2.velocity.x >= 0.0 else KEY_LEFT, 12)
	# Прыгаем на подъёме маятника и рулим к якорю.
	for i in 240:
		var dx := p2.global_position.x - p1.global_position.x
		if p2.velocity.y < -150.0 and absf(dx) > 50.0:
			break
		await get_tree().physics_frame
	press(KEY_UP, true)
	await frames(2)
	press(KEY_PERIOD, false)
	var landed := false
	for i in 90:
		# Подруливаем к якорю, как игрок: жмём в его сторону, пока не окажемся над ним.
		var dx := p2.global_position.x - p1.global_position.x
		press(KEY_LEFT, dx > 8.0)
		press(KEY_RIGHT, dx < -8.0)
		await get_tree().physics_frame
		if p2.standing_on() == p1:
			landed = true
			break
	press(KEY_LEFT, false)
	press(KEY_RIGHT, false)
	press(KEY_UP, false)
	check(landed, "раскачался под замершим и запрыгнул ему на голову")

	# --- Катапульта: игрок 2 стоит на замершем игроке 1, тот резко наклоняется вправо.
	place(p1, Vector2(30 * TILE, FLOOR_Y))  # всё ещё замерший
	await frames(3)
	check(p1.frozen, "игрок 1 замер на полу")
	place(p2, p1.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(15)
	check(p2.standing_on() == p1, "игрок 2 стоит на замершем игроке 1")
	var start := p2.global_position
	var peak := start
	press(KEY_D, true)
	for i in 40:
		await get_tree().physics_frame
		if p2.global_position.y < peak.y:
			peak = p2.global_position
	check(absf(rad_to_deg(p1.rotation) - p1.max_tilt_deg) < 1.0, "замерший наклонён на %.0f°" % rad_to_deg(p1.rotation))
	press(KEY_D, false)
	check(start.y - peak.y > 200.0 and peak.x > start.x + 40.0,
			"катапульта подбросила на %.0f px вверх и %.0f px вправо" % [start.y - peak.y, peak.x - start.x])
	await frames(40)
	check(is_zero_approx(p1.rotation), "отпустил стик — замерший выпрямился")
	tap(KEY_S)
	await frames(30)

	# --- Стены кадра: при предельном отдалении игроки не расходятся дальше экрана.
	place(p1, Vector2(25 * TILE, FLOOR_Y))
	place(p2, Vector2(26 * TILE, FLOOR_Y))
	tap(KEY_S)
	await frames(30)
	await hold(KEY_RIGHT, 12 * 60)
	var spread := p2.global_position.x - p1.global_position.x
	var view_width: float = game.get_node("SharedCamera").get_view_rect().size.x
	check(spread < view_width, "игрок 2 упёрся в край кадра (разошлись на %.0f из %.0f px)" % [spread, view_width])
	check(p2.global_position.x < 78 * TILE, "стена кадра остановила раньше стены уровня")
	finish()


## Ставит висящего неподвижно в нижнюю точку под якорем.
func _hang_still(holder: Player, anchor: Vector2, length: float) -> void:
	place(holder, anchor + Vector2(0, length))
	await frames(10)


## Размах маятника по горизонтали за count кадров.
func _measure_swing(holder: Player, anchor: Player, count: int) -> float:
	var low := INF
	var high := -INF
	for i in count:
		await get_tree().physics_frame
		var dx := holder.global_position.x - anchor.global_position.x
		low = minf(low, dx)
		high = maxf(high, dx)
	return high - low
