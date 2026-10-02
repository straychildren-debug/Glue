extends SmokeTest
## Автопроверка механизмов этапа 7.
## Запуск: Godot_console --headless --path . res://tests/stage7_smoke.tscn
## Уровень tests/stage7_room.tscn: пол 0–20 тайлов, пропасть 20–26, пол 26–80; мост (5 тайлов)
## спрятан в правом берегу и выдвигается влево от защёлки на x 34; дверь на x 44 от плиты на x 40.

const ROOM := preload("res://tests/stage7_room.tscn")
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
	await _check_bridge_shoves_frozen(p1, p2, level)
	await _check_door_waits_for_frozen(p1, p2, level)
	await _check_hook(p1, p2, level)
	await _check_inverse_door(p1, p2, level)
	await _check_key(p1, p2, level)
	await _check_seesaw_lock(p1, p2, level)
	await _check_lift(p1, p2, level)
	finish()


## Крюк: хватаются, висят, раскачиваются и прыгают с хвата, как с замершего товарища.
func _check_hook(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var hook: Hook = level.get_node("Hook")
	await _teleport(p1, Vector2(hook.global_position.x, FLOOR_Y), p2, Vector2(47 * TILE, FLOOR_Y))
	press(KEY_E, true)  # хват зажат заранее, как в прыжке к крюку
	place(p1, hook.global_position + Vector2(30, 70))
	await frames(3)
	check(p1.grab_target == hook, "игрок 1 схватился за крюк")
	await frames(40)
	var hanging := p1.global_position.y > hook.global_position.y + 60.0 \
			and p1.global_position.distance_to(hook.global_position) <= p1.grab_length + 2.0
	check(hanging and not p1.is_on_floor(), "висит под крюком на длину руки")
	var min_x := INF
	var max_x := -INF
	for i in 6:
		await hold(KEY_D if p1.velocity.x >= 0.0 else KEY_A, 12)
		min_x = minf(min_x, p1.global_position.x)
		max_x = maxf(max_x, p1.global_position.x)
	check(max_x - min_x > 80.0, "раскачался на крюке (размах %.0f px)" % (max_x - min_x))
	press(KEY_W, true)
	await frames(3)
	check(p1.grab_target == null and p1.velocity.y < -500.0, "прыжок с крюка разжал руку")
	press(KEY_W, false)
	press(KEY_E, false)
	await frames(60)
	check(hook.global_position == Vector2(3200, 576), "крюк не сдвинулся")


## Обратная дверь: открыта, пока плита пуста; встал на плиту — закрылась.
func _check_inverse_door(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var door: Door = level.get_node("InvDoor")
	var plate: PressurePlate = level.get_node("InvPlate")
	await _teleport(p1, Vector2(52 * TILE, FLOOR_Y), p2, Vector2(51 * TILE, FLOOR_Y))
	await frames(30)
	check(door.global_position.y <= 6 * TILE + 1.0, "обратная дверь открыта, пока плита пуста")
	var plate_top := plate.global_position.y - PressurePlate.RAISED - Player.SIZE.y / 2.0 - 1.0
	place(p2, Vector2(plate.global_position.x, plate_top - 4.0))
	await frames(60)
	check(plate.active and is_equal_approx(door.global_position.y, 9 * TILE), "встал на плиту — обратная дверь закрылась")
	place(p2, Vector2(51 * TILE, FLOOR_Y))
	await frames(60)


## Ключ: подбирается касанием, следует за носителем, перехватывается товарищем, открывает замок.
## Гибель носителя возвращает ключ на место.
func _check_key(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var key: DoorKey = level.get_node("Key")
	var door: Door = level.get_node("LockDoor")
	var lock: KeyLock = level.get_node("LockDoor/Lock")
	var home := key.global_position
	await _teleport(p1, Vector2(58 * TILE, FLOOR_Y), p2, Vector2(56 * TILE, FLOOR_Y))
	check(key.carrier == null and not lock.active, "ключ висит на месте, замок закрыт")
	place(p1, Vector2(home.x, FLOOR_Y))
	await frames(5)
	check(key.carrier == p1, "игрок 1 подобрал ключ касанием")
	await hold(KEY_A, 40)
	await frames(20)
	check(key.global_position.distance_to(p1.global_position) < 90.0, "ключ летит следом за носителем")
	# Гибель носителя: общий респавн, ключ возвращается туда, где был на чекпоинте.
	p1.global_position.y = level.get_kill_y() + 10.0
	await frames(140)
	check(key.carrier == null and key.global_position.distance_to(home) < 4.0,
			"после гибели носителя ключ вернулся на место")
	await _teleport(p1, Vector2(home.x, FLOOR_Y), p2, Vector2(home.x - 200.0, FLOOR_Y))
	await frames(40)
	check(key.carrier == p1, "игрок 1 снова взял ключ")
	place(p2, key.global_position + Vector2(0, 20))
	await frames(5)
	check(key.carrier == p2, "игрок 2 перехватил ключ, коснувшись его")
	var closed_y := door.global_position.y
	place(p2, Vector2(door.global_position.x - 40.0, FLOOR_Y))
	await frames(60)
	check(lock.active and key.used and door.global_position.y < closed_y - 150.0, "носитель открыл замок — дверь открылась")
	place(p2, Vector2(62 * TILE, FLOOR_Y))
	await frames(60)
	check(door.global_position.y < closed_y - 150.0, "дверь замка осталась открытой")


## Фиксатор качелей: пока нажата его защёлка, балка стоит, как бы её ни нагружали.
func _check_seesaw_lock(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var seesaw: Seesaw = level.get_node("Seesaw")
	var latch: PressurePlate = level.get_node("SeesawLatch")
	var pivot := seesaw.global_position
	var half := seesaw.length_tiles * TILE / 2.0
	var latch_top := latch.global_position.y - PressurePlate.RAISED - Player.SIZE.y / 2.0 - 1.0
	await _teleport(p1, Vector2(pivot.x - half - 2 * TILE, FLOOR_Y), p2, Vector2(latch.global_position.x, latch_top - 4.0))
	await frames(30)
	check(latch.active and seesaw.is_locked(), "защёлка фиксатора нажата")
	var angle := seesaw.angle
	place(p1, pivot + Vector2(half - 40.0, -120.0))
	await frames(90)
	check(absf(seesaw.angle - angle) < 0.01 and Weight.floor_below(p1) == seesaw.get_beam(),
			"игрок на поднятом конце, а зафиксированная балка не шелохнулась")


## Подъёмник: тяжёлая сторона опускается, при равенстве стоит; упирается — останавливается.
func _check_lift(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var lift: Lift = level.get_node("Lift")
	var left: AnimatableBody2D = lift.get_platforms()[0]
	var right: AnimatableBody2D = lift.get_platforms()[1]
	await _teleport(p1, Vector2(96 * TILE, FLOOR_Y), p2, Vector2(106 * TILE, FLOOR_Y))
	check(is_zero_approx(lift.offset), "площадки подъёмника на уровне пола")
	place(p1, left.global_position + Vector2(0, -Player.SIZE.y / 2.0 - 2.0))
	await frames(150)
	check(is_equal_approx(lift.offset, 3 * TILE), "игрок 1 перевесил: левая внизу, правая на 3 тайла выше (%.0f)" % lift.offset)
	place(p2, right.global_position + Vector2(0, -Player.SIZE.y / 2.0 - 2.0))
	await frames(60)
	var offset := lift.offset
	await frames(60)
	check(absf(lift.offset - offset) < 1.0, "1 против 1 — площадки стоят")
	# Замерший в воздухе над правой площадкой — правая поднимается до него и останавливается.
	place(p2, Vector2(106 * TILE, FLOOR_Y))
	place(p1, Vector2(96 * TILE, FLOOR_Y))
	await frames(10)
	lift.load_state(0.0)
	await frames(10)
	var stopper := Vector2(right.global_position.x, 12 * TILE - 100.0)
	place(p2, stopper)
	await frames(2)
	tap(KEY_DOWN)
	await frames(3)
	place(p1, left.global_position + Vector2(0, -Player.SIZE.y / 2.0 - 2.0))
	await frames(150)
	var right_top := right.global_position.y
	check(p2.frozen and p2.global_position.distance_to(stopper) < 4.0
			and right_top >= p2.global_position.y + Player.SIZE.y / 2.0 - 1.0 and lift.offset > 40.0,
			"правая площадка поднялась до замершего и встала под ним (ход %.0f, верх %.1f, замерший %s)" % [lift.offset, right_top, p2.global_position])
	tap(KEY_DOWN)
	await frames(10)


## Выдвигающийся мост толкает замершего в воздухе перед собой, а не проходит сквозь него.
func _check_bridge_shoves_frozen(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var bridge: Door = level.get_node("Bridge")
	var latch: PressurePlate = level.get_node("BridgeLatch")
	var anchor := Vector2(23 * TILE, 12 * TILE - 20.0)  # низ замершего ниже верха моста
	await _teleport(p1, Vector2(23 * TILE, FLOOR_Y), p2, Vector2(32 * TILE, FLOOR_Y))
	tap(KEY_S)
	place(p1, anchor)
	await frames(5)
	check(p1.frozen, "игрок 1 замер в воздухе над пропастью на пути моста")
	var latch_top := latch.global_position.y - PressurePlate.RAISED - Player.SIZE.y / 2.0 - 1.0
	place(p2, Vector2(latch.global_position.x, latch_top - 4.0))
	await frames(90)
	var bridge_rect := Rect2(bridge.global_position, bridge.size_tiles * TILE)
	var body := Rect2(p1.global_position - Player.SIZE / 2.0, Player.SIZE)
	check(latch.active and is_equal_approx(bridge.global_position.x, 21 * TILE), "мост выдвинулся до конца")
	check(p1.frozen and not bridge_rect.intersects(body) and p1.global_position.x < 21 * TILE,
			"мост сдвинул замершего перед собой (x %.0f → %.0f)" % [anchor.x, p1.global_position.x])
	tap(KEY_S)
	await frames(60)
	check(p1.alive and p1.global_position.y > 13 * TILE or not p1.alive,
			"ожив, игрок 1 падает в пропасть, а не стоит внутри моста")
	await frames(90)  # общий респавн


## Закрывающаяся дверь не может столкнуть замершего, стоящего на полу, — останавливается над ним.
func _check_door_waits_for_frozen(p1: Player, p2: Player, level: GreyboxLevel) -> void:
	var door: Door = level.get_node("Door")
	var plate: PressurePlate = level.get_node("DoorPlate")
	var plate_top := plate.global_position.y - PressurePlate.RAISED - Player.SIZE.y / 2.0 - 1.0
	await _teleport(p1, Vector2(42 * TILE, FLOOR_Y), p2, Vector2(plate.global_position.x, plate_top - 4.0))
	await frames(60)
	check(plate.active and door.global_position.y <= 6 * TILE + 1.0, "дверь открыта, пока на плите игрок 2")
	place(p1, Vector2(door.global_position.x + TILE / 2.0, FLOOR_Y))
	await frames(10)
	tap(KEY_S)
	await frames(5)
	place(p2, Vector2(38 * TILE, FLOOR_Y))
	await frames(90)
	var door_bottom := door.global_position.y + 3 * TILE
	check(p1.frozen and door_bottom <= p1.global_position.y - Player.SIZE.y / 2.0 + 1.0,
			"закрываясь, дверь остановилась над замершим и не раздавила его")
	tap(KEY_S)
	place(p1, Vector2(46 * TILE, FLOOR_Y))
	await frames(90)
	check(is_equal_approx(door.global_position.y, 9 * TILE), "замерший ушёл — дверь закрылась")


## Стены кадра физика видит на новом месте только со следующего кадра — поэтому сначала камера.
func _teleport(a: Player, a_at: Vector2, b: Player, b_at: Vector2) -> void:
	camera.snap_to((a_at + b_at) / 2.0)
	await frames(1)
	place(a, a_at)
	place(b, b_at)
	camera.snap_to((a_at + b_at) / 2.0)
	await frames(15)
