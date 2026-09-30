extends SmokeTest
## Автопроверка этапа 4: пара проходит три серых уровня задуманным путём от старта до финиша,
## включая возврат того, кто был опорой. Уровень засчитан только когда в двери оба.
## Запуск: Godot_console --headless --path . res://tests/stage4_smoke.tscn

const TILE := 64.0
const L01 := preload("res://levels/w01_l01_first_steps.tscn")
const L02 := preload("res://levels/w01_l02_lend_a_shoulder.tscn")
const L03 := preload("res://levels/w01_l03_dont_let_go.tscn")

## Раскладки: [влево, вправо, прыжок, замри, хват].
const KEYS_1: Array[Key] = [KEY_A, KEY_D, KEY_W, KEY_S, KEY_E]
const KEYS_2: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PERIOD]
enum { LEFT, RIGHT, JUMP, FREEZE, GRAB }

var game: Node


func _ready() -> void:
	game = await start_game(L01)
	await _level_01()
	await _load(L02)
	await _level_02()
	await _load(L03)
	await _level_03()
	finish()


func _level_01() -> void:
	print("— 01 · Первые шаги")
	var p1: Player = game.players[0]
	var p2: Player = game.players[1]
	var door_x: float = game.level.get_finish().global_position.x
	# Каждый проходит уступы, канаву и пропасть обычным бегом и прыжком, без помощи.
	var ok1 := await _run(p1, KEYS_1, door_x + 30.0)
	check(ok1 and p1.alive, "игрок 1 сам дошёл до двери (%s)" % p1.global_position)
	check(not game.completed, "один в двери — уровень не засчитан")
	var ok2 := await _run(p2, KEYS_2, door_x - 30.0)
	check(ok2 and p2.alive, "игрок 2 сам дошёл до двери (%s)" % p2.global_position)
	await frames(5)
	check(game.completed, "оба в двери — уровень пройден (a %s b %s)" % [game.players[0].global_position, game.players[1].global_position])


func _level_02() -> void:
	print("— 02 · Подставь плечо")
	var a: Player = game.players[0]
	var b: Player = game.players[1]
	var wall_x := 16 * TILE
	var floor_y := _stand_y(12)
	# Один в одиночку на стену в 3 тайла не запрыгивает.
	place(b, Vector2(wall_x - 40.0, floor_y))
	await frames(10)
	await _jump(b, KEYS_2, RIGHT, 40)
	check(b.global_position.y > 10 * TILE, "в одиночку на стену не запрыгнуть")
	# А замирает у стены, Б встаёт ему на голову и запрыгивает наверх.
	place(a, Vector2(wall_x - 30.0, floor_y))
	place(b, Vector2(wall_x - 200.0, floor_y))
	await frames(10)
	tap(KEYS_1[FREEZE])
	place(b, a.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(15)
	await _jump(b, KEYS_2, RIGHT, 45)
	check(b.is_on_floor() and b.global_position.y < 9 * TILE, "с головы товарища — наверх")
	# Наверху Б нажимает защёлку: из стены выдвигается ступенька.
	var latch: PressurePlate = game.level.get_node("Latch")
	await _walk_until(b, KEYS_2[RIGHT], func() -> bool: return latch.active, 120)
	check(latch.active, "поднявшийся нажал защёлку")
	await frames(40)
	var step: Door = game.level.get_node("Step")
	check(step.global_position.x < wall_x - TILE, "ступенька выдвинулась")
	# А оживает, отходит из-под ступеньки и поднимается по ней.
	tap(KEYS_1[FREEZE])
	await hold(KEYS_1[LEFT], 20)
	await _jump(a, KEYS_1, RIGHT, 40)
	await _jump(a, KEYS_1, RIGHT, 40)
	check(a.is_on_floor() and a.global_position.y < 9 * TILE, "опора поднялась по ступеньке")
	# Первым к двери идёт тот, кто впереди, иначе второй упрётся в него.
	var door_x: float = game.level.get_finish().global_position.x
	await _walk_until(b, KEYS_2[RIGHT], func() -> bool: return b.global_position.x > door_x + 30.0, 240)
	await _walk_until(a, KEYS_1[RIGHT], func() -> bool: return a.global_position.x > door_x - 30.0, 240)
	await frames(5)
	check(game.completed, "оба в двери — уровень пройден (a %s b %s)" % [game.players[0].global_position, game.players[1].global_position])


func _level_03() -> void:
	print("— 03 · Не отпускай")
	var a: Player = game.players[0]
	var b: Player = game.players[1]
	var ledge_x := 10 * TILE
	# Знакомство с хватом: Б поднимается с головы А, ловит прыгнувшего А за руку и вытягивает.
	place(a, Vector2(ledge_x - 30.0, _stand_y(12)))
	place(b, Vector2(ledge_x - 200.0, _stand_y(12)))
	await frames(10)
	tap(KEYS_1[FREEZE])
	place(b, a.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(15)
	await _jump(b, KEYS_2, RIGHT, 45)
	check(b.is_on_floor() and b.global_position.y < 9 * TILE, "Б поднялся на уступ")
	# К самому краю уступа.
	await _walk_until(b, KEYS_2[LEFT], func() -> bool: return b.global_position.x < ledge_x + 30.0, 60)
	tap(KEYS_1[FREEZE])
	press(KEYS_2[GRAB], true)
	await frames(5)
	press(KEYS_1[JUMP], true)
	await frames(20)
	press(KEYS_1[JUMP], false)
	check(b.grab_target == a, "Б поймал прыгнувшего А за руку (a %s b %s)" % [a.global_position, b.global_position])
	await hold(KEYS_2[RIGHT], 60)
	press(KEYS_2[GRAB], false)
	await frames(20)
	check(a.is_on_floor() and a.global_position.y < 9 * TILE, "Б вытянул А на уступ")

	# Пропасть: обычным прыжком с балки не перепрыгнуть.
	var tip := 23 * TILE
	var far_bank := 29 * TILE
	place(b, Vector2(tip - 200.0, _stand_y(9)))
	await frames(10)
	await _walk_until(b, KEYS_2[RIGHT], func() -> bool: return b.global_position.x > tip - 20.0, 120)
	await _jump(b, KEYS_2, RIGHT, 50)
	check(b.global_position.x < far_bank, "с разбега через пропасть не перепрыгнуть")
	await frames(80)  # общий респавн у чекпоинта на уступе
	check(a.alive and b.alive, "после падения оба снова у чекпоинта")

	# А замирает на конце балки, Б держится за него и раскачивается.
	place(a, Vector2(tip - Player.SIZE.x / 2.0 - 2.0, _stand_y(9)))
	await frames(10)
	tap(KEYS_1[FREEZE])
	place(b, a.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(10)
	press(KEYS_2[GRAB], true)
	await hold(KEYS_2[RIGHT], 20)  # сходит с головы и повисает
	await frames(30)
	check(b.grab_target == a and b.global_position.y > a.global_position.y + 60.0, "Б висит на А под балкой")
	# Раскачка: жмём в сторону движения. Когда размах почти полный, прыгаем на взлёте вправо,
	# как только вышли из-под балки, — и летим к дальнему берегу.
	var clear_x := tip + Player.SIZE.x / 2.0 + 8.0
	var reach := 0.0
	for i in 600:
		var right := b.velocity.x >= 0.0
		press(KEYS_2[RIGHT], right)
		press(KEYS_2[LEFT], not right)
		await get_tree().physics_frame
		reach = maxf(reach, b.global_position.x - a.global_position.x)
		if reach > 80.0 and b.global_position.x > clear_x and b.velocity.x > 300.0 and b.velocity.y < 0.0:
			break
	press(KEYS_2[LEFT], false)
	print("    размах %.0f px, прыжок из %s со скоростью %s" % [reach, b.global_position, b.velocity])
	press(KEYS_2[JUMP], true)
	await frames(2)
	press(KEYS_2[GRAB], false)
	press(KEYS_2[RIGHT], true)
	await frames(70)
	press(KEYS_2[JUMP], false)
	press(KEYS_2[RIGHT], false)
	check(b.alive and b.is_on_floor() and b.global_position.x > far_bank, "маятник перенёс Б на дальний берег (%s alive=%s)" % [b.global_position, b.alive])

	# Б нажимает защёлку — выдвигается мост, А оживает и переходит.
	var latch: PressurePlate = game.level.get_node("Latch")
	await _walk_until(b, KEYS_2[RIGHT], func() -> bool: return latch.active, 180)
	check(latch.active, "Б нажал защёлку на том берегу")
	await frames(60)
	var door_x: float = game.level.get_finish().global_position.x
	await _walk_until(b, KEYS_2[RIGHT], func() -> bool: return b.global_position.x > door_x + 30.0, 240)
	tap(KEYS_1[FREEZE])
	await _walk_until(a, KEYS_1[RIGHT], func() -> bool: return a.global_position.x > door_x - 30.0, 400)
	check(a.alive, "А перешёл по мосту")
	await frames(5)
	check(game.completed, "оба в двери — уровень пройден (a %s b %s)" % [game.players[0].global_position, game.players[1].global_position])


## Перезапускает игру на другом уровне; подключённые игроки остаются.
func _load(level: PackedScene) -> void:
	game.queue_free()
	await frames(2)
	game = GAME_SCENE.instantiate()
	game.level_scene = level
	add_child(game)
	await frames(20)


## Простой бот: бежит вправо до target_x, прыгает перед ямой и перед стенкой.
func _run(player: Player, keys: Array[Key], target_x: float, max_frames := 1500) -> bool:
	var space := player.get_world_2d().direct_space_state
	var jump_frames := 0
	press(keys[RIGHT], true)
	for i in max_frames:
		if player.global_position.x >= target_x:
			break
		if player.alive and player.is_on_floor() and jump_frames == 0:
			var ahead := player.global_position + Vector2(36.0, 0.0)
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 100.0), Player.LAYER_WORLD)
			if space.intersect_ray(query).is_empty() or player.is_on_wall():
				jump_frames = 20
		press(keys[JUMP], jump_frames > 0)
		jump_frames = maxi(jump_frames - 1, 0)
		await get_tree().physics_frame
	press(keys[RIGHT], false)
	press(keys[JUMP], false)
	await frames(10)
	return player.global_position.x >= target_x - 1.0


## Полный прыжок с удержанием направления.
func _jump(player: Player, keys: Array[Key], direction: int, count: int) -> void:
	press(keys[JUMP], true)
	press(keys[direction], true)
	await frames(count)
	press(keys[JUMP], false)
	press(keys[direction], false)
	await frames(15)


func _walk_until(player: Player, key: Key, done: Callable, max_frames: int) -> void:
	press(key, true)
	for i in max_frames:
		if done.call():
			break
		await get_tree().physics_frame
	press(key, false)
	await frames(10)


## Центр стоящего игрока над полом с верхом на высоте row тайлов.
func _stand_y(row: float) -> float:
	return row * TILE - Player.SIZE.y / 2.0 - 1.0
