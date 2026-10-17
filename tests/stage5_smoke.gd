extends LevelBot
## Автопроверка этапа 5: пара проходит серые уровни 04–10 задуманным путём от старта до финиша,
## включая возврат того, кто был опорой. Ключевые приёмы — честными нажатиями: «Замри» в воздухе
## и приземление на товарища, катапульта, толкание ящиков, вытягивание за руку, маятник.
## Подходы к задаче (дойти до стены, встать на голову замершему) иногда сокращены телепортом.
## Запуск: Godot_console --headless --path . res://tests/stage5_smoke.tscn [-- 04 07]

const LEVELS := {
	"04": preload("res://levels/w01_l04_step_in_the_air.tscn"),
	"05": preload("res://levels/w01_l05_catapult.tscn"),
}



func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	var first := true
	for id: String in LEVELS:
		if not only.is_empty() and id not in only:
			continue
		if first:
			game = await start_game(LEVELS[id])
			first = false
		else:
			await _load(LEVELS[id])
		a = game.players[0]
		b = game.players[1]
		print("— ", game.level.title)
		await call("_level_" + id)
		check(game.completed, "оба в двери — уровень пройден (a %s b %s)" % [a.global_position, b.global_position])
	finish()


# --- Уровни ---------------------------------------------------------------------------------


func _level_04() -> void:
	# Канава 6 тайлов (x 14–20), глубина 4 — безопасная. Обычным прыжком не перепрыгнуть.
	place(b, Vector2(11 * TILE, _stand_y(12)))
	place(a, Vector2(5 * TILE, _stand_y(12)))
	await frames(10)
	await _run_jump(b, KEYS_2, 14 * TILE)
	await frames(40)
	check(b.global_position.y > 14 * TILE, "через канаву с разбега не перепрыгнуть (%s)" % b.global_position)
	# Из канавы — по ступенькам обратно на ближний берег.
	await _walk_to(b, KEYS_2, 15.5 * TILE)
	await _jump(b, KEYS_2, LEFT, 30)
	await _jump(b, KEYS_2, LEFT, 30)
	await _jump(b, KEYS_2, LEFT, 40)
	check(b.is_on_floor() and b.global_position.y < 12 * TILE, "из канавы выбрался по ступенькам (%s)" % b.global_position)

	# А прыгает над канавой и замирает в воздухе, Б встаёт на него и прыгает на тот берег.
	var crossed := await _air_step(a, KEYS_1, b, KEYS_2, 14 * TILE, 20 * TILE, 12 * TILE, 30.0)
	check(crossed, "по замершему в воздухе Б перебрался через канаву (a %s b %s)" % [a.global_position, b.global_position])
	var latch_a: PressurePlate = game.level.get_node("LatchA")
	await _walk_to(b, KEYS_2, latch_a.global_position.x)
	check(latch_a.active, "Б нажал защёлку — выдвигается мост")
	await frames(60)
	tap(KEYS_1[FREEZE])  # А оживает и встаёт на мост
	await frames(30)
	check(a.alive and a.is_on_floor() and absf(a.global_position.y - _stand_y(12)) < 4.0, "А встал на мост (%s)" % a.global_position)

	# Пропасть 7 тайлов (x 30–37), дальний берег на тайл ниже. Падение — общий респавн.
	await _run_to(a, 26 * TILE)
	await _walk_to(b, KEYS_2, 25.4 * TILE)
	check(game.level.active_checkpoint == 1, "оба у чекпоинта перед пропастью — взят (a %s b %s)" % [a.global_position, b.global_position])
	crossed = await _air_step(a, KEYS_1, b, KEYS_2, 30 * TILE, 37 * TILE, 13 * TILE, 30.0)
	check(crossed, "по замершему в воздухе Б перебрался через пропасть (a %s b %s)" % [a.global_position, b.global_position])
	var latch_b: PressurePlate = game.level.get_node("LatchB")
	await _walk_to(b, KEYS_2, latch_b.global_position.x)
	check(latch_b.active, "Б нажал защёлку на том берегу")
	await frames(70)
	tap(KEYS_1[FREEZE])
	await frames(30)
	check(a.alive and a.is_on_floor() and absf(a.global_position.y - _stand_y(13)) < 4.0, "мост выдвинулся под замершего А, он встал на мост (%s)" % a.global_position)
	await _both_to_finish()


func _level_05() -> void:
	# Уступ 4 тайла (x 16, верх y 8): ни в одиночку, ни с головы товарища.
	var wall_x := 16 * TILE
	place(a, Vector2(wall_x - 30.0, _stand_y(12)))
	place(b, Vector2(wall_x - 300.0, _stand_y(12)))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await _onto_head(b, a)
	await _jump(b, KEYS_2, RIGHT, 45)
	check(b.global_position.y > 9 * TILE, "с головы товарища на 4 тайла не запрыгнуть (%s)" % b.global_position)
	# Катапульта: Б стоит на замершем А, А резко наклоняется к стене.
	await _onto_head(b, a)
	await _catapult(a, KEYS_1, b, KEYS_2, RIGHT)
	check(b.is_on_floor() and b.global_position.y < 8 * TILE, "катапульта забросила Б на уступ (%s)" % b.global_position)
	var latch_a: PressurePlate = game.level.get_node("LatchA")
	await _walk_to(b, KEYS_2, latch_a.global_position.x)
	check(latch_a.active, "Б нажал защёлку — из стены выдвинулась ступенька")
	await frames(40)
	tap(KEYS_1[FREEZE])
	await _walk_to(a, KEYS_1, wall_x - 2.6 * TILE)
	await _jump(a, KEYS_1, RIGHT, 30)
	await _jump(a, KEYS_1, RIGHT, 40)
	check(a.is_on_floor() and a.global_position.y < 8 * TILE, "А поднялся по ступеньке (%s)" % a.global_position)

	# Пропасть 3 тайла (x 26–29) и обрыв на 3,5 тайла выше. Катапульта с края — на обрыв.
	var edge := 26 * TILE
	await _walk_to(b, KEYS_2, 22 * TILE)
	await _walk_to(a, KEYS_1, edge - 26.0)
	check(game.level.active_checkpoint == 1, "чекпоинт на уступе")
	tap(KEYS_1[FREEZE])
	await _onto_head(b, a)
	await _jump(b, KEYS_2, RIGHT, 45)
	await frames(60)
	check(not b.alive or b.global_position.y > 8 * TILE or game.level.active_checkpoint == 1 and b.global_position.x < edge,
			"с головы товарища на обрыв не запрыгнуть (%s)" % b.global_position)
	await frames(60)  # если упал — общий респавн у чекпоинта
	place(a, Vector2(edge - 26.0, _stand_y(8)))
	await frames(10)
	if not a.frozen:
		tap(KEYS_1[FREEZE])
	await _onto_head(b, a)
	await _catapult(a, KEYS_1, b, KEYS_2, RIGHT)
	check(b.is_on_floor() and b.global_position.y < 4.5 * TILE, "катапульта с края забросила Б на обрыв (%s)" % b.global_position)
	var latch_b: PressurePlate = game.level.get_node("LatchB")
	await _walk_to(b, KEYS_2, latch_b.global_position.x)
	check(latch_b.active, "Б нажал защёлку — мост и ступенька для А")
	await frames(60)
	tap(KEYS_1[FREEZE])
	# Ступенька — тайл у стены обрыва над концом моста: прыжок вверх, у вершины — вправо.
	await _walk_to(a, KEYS_1, 27.1 * TILE)
	press(KEYS_1[JUMP], true)
	await frames(14)
	press(KEYS_1[RIGHT], true)
	await frames(25)
	press(KEYS_1[JUMP], false)
	press(KEYS_1[RIGHT], false)
	await frames(15)
	check(a.is_on_floor() and a.global_position.y < 6.3 * TILE, "А запрыгнул на ступеньку (%s)" % a.global_position)
	await _jump(a, KEYS_1, RIGHT, 40)
	check(a.is_on_floor() and a.global_position.y < 4.5 * TILE, "А поднялся на обрыв (%s)" % a.global_position)
	await _both_to_finish()


# --- Приёмы ---------------------------------------------------------------------------------
