extends LevelBot
## Автопроверка этапа 5: пара проходит серые уровни 04–10 задуманным путём от старта до финиша,
## включая возврат того, кто был опорой. Ключевые приёмы — честными нажатиями: «Замри» в воздухе
## и приземление на товарища, катапульта, толкание ящиков, вытягивание за руку, маятник.
## Подходы к задаче (дойти до стены, встать на голову замершему) иногда сокращены телепортом.
## Запуск: Godot_console --headless --path . res://tests/stage5_smoke.tscn [-- 04 07]

const LEVELS := {
	"04": preload("res://levels/w01_l04_step_in_the_air.tscn"),
	"05": preload("res://levels/w01_l05_catapult.tscn"),
	"06": preload("res://levels/w01_l06_the_crate.tscn"),
	"07": preload("res://levels/w01_l07_hold_it.tscn"),
	"08": preload("res://levels/w01_l08_heavy_load.tscn"),
	"09": preload("res://levels/w01_l09_living_staircase.tscn"),
	"10": preload("res://levels/w01_l10_the_pass.tscn"),
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
	await _walk_to(a, KEYS_1, 26 * TILE)
	await _walk_to(b, KEYS_2, 25 * TILE)
	check(game.level.active_checkpoint == 1, "чекпоинт перед пропастью")
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


func _level_06() -> void:
	# Стена 3 тайла (x 18): ящик к стене — ступенька для обоих.
	var crate1: Crate = game.level.get_node("Crate1")
	await _push_crate(b, crate1, 18 * TILE - 32.0)
	check(crate1.global_position.x > 17 * TILE, "Б дотолкал ящик до стены (%s)" % crate1.global_position)
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), crate1.global_position.x - 70.0)
		await _jump(p, _keys(p), RIGHT, 18)
		await _jump(p, _keys(p), RIGHT, 40)
		check(p.is_on_floor() and p.global_position.y < 9 * TILE, "%s поднялся по ящику (%s)" % [p.name, p.global_position])

	# Плита и дверь: ящик на плите держит дверь, оба проходят.
	var crate2: Crate = game.level.get_node("Crate2")
	var plate: PressurePlate = game.level.get_node("Plate")
	await _push_crate(b, crate2, plate.global_position.x)
	await frames(30)
	check(plate.active and Weight.floor_below(crate2) == plate, "ящик на плите — дверь открыта")
	await _run_to(b, 33 * TILE)
	await _run_to(a, 32 * TILE)
	check(b.global_position.x > 31 * TILE and a.global_position.x > 31 * TILE, "оба прошли дверь (a %s b %s)" % [a.global_position, b.global_position])

	# Полка 4 тайла (x 40), ящик наверху. Б — катапультой, сталкивает ящик, А — по ящику и за руку.
	var wall_x := 40 * TILE
	var crate3: Crate = game.level.get_node("Crate3")
	await _walk_to(b, KEYS_2, wall_x - 200.0)
	await _walk_to(a, KEYS_1, wall_x - 28.0)
	tap(KEYS_1[FREEZE])
	await _onto_head(b, a)
	await _catapult(a, KEYS_1, b, KEYS_2, RIGHT)
	check(b.is_on_floor() and b.global_position.y < 5 * TILE, "катапульта забросила Б на полку (%s)" % b.global_position)
	tap(KEYS_1[FREEZE])
	# Без ящика рука до прыгнувшего с пола не дотягивается — ящик нужен.
	await _walk_to(b, KEYS_2, wall_x + 26.0)
	press(KEYS_2[GRAB], true)
	await frames(5)
	await _jump(a, KEYS_1, RIGHT, 30)
	check(b.grab_target == null, "с пола до руки на полке не дотянуться")
	press(KEYS_2[GRAB], false)
	await frames(5)
	await _walk_to(a, KEYS_1, wall_x - 4 * TILE)
	await _walk_to(b, KEYS_2, crate3.global_position.x - 64.0)
	await _jump(b, KEYS_2, RIGHT, 30)
	await _push_crate(b, crate3, wall_x - 40.0)
	await frames(40)
	check(crate3.global_position.y > 8 * TILE, "Б столкнул ящик с полки (%s)" % crate3.global_position)
	await _push_crate(a, crate3, wall_x - 32.0)
	await _walk_to(b, KEYS_2, wall_x + 26.0)
	await _jump(a, KEYS_1, RIGHT, 18)
	check(Weight.floor_below(a) == crate3, "А стоит на ящике у стены")
	await _pull_up(b, a, RIGHT)
	check(a.is_on_floor() and a.global_position.y < 5 * TILE, "Б вытянул А на полку (%s)" % a.global_position)
	await _both_to_finish()


func _level_07() -> void:
	# Плита держит дверь, пока на ней стоят; защёлка за дверью держит её для второго.
	var door1: Door = game.level.get_node("Door1")
	var latch1: PressurePlate = game.level.get_node("Latch1")
	await _walk_to(b, KEYS_2, 11 * TILE)
	await _walk_to(a, KEYS_1, 8 * TILE)
	await frames(30)
	check(door1.position.y < 9 * TILE - 150.0, "А на плите — дверь открыта")
	await _walk_to(b, KEYS_2, latch1.global_position.x)
	check(latch1.active, "Б прошёл и нажал защёлку")
	await _walk_to(a, KEYS_1, 12 * TILE)
	await frames(40)
	check(door1.position.y < 9 * TILE - 150.0, "А сошёл с плиты — дверь осталась открытой")
	await _run_to(a, 19 * TILE)
	await _run_to(b, 21 * TILE)

	# Плита на двоих: передний толкает ящик на плиту и остаётся на ней, задний перепрыгивает,
	# проходит и жмёт защёлку.
	var crate2: Crate = game.level.get_node("Crate2")
	var plate2: PressurePlate = game.level.get_node("Plate2")
	var door2: Door = game.level.get_node("Door2")
	var front := b if b.global_position.x > a.global_position.x else a
	var back := a if front == b else b
	await _push_crate(front, crate2, plate2.global_position.x + 40.0)
	check(Weight.floor_below(crate2) == plate2 and is_equal_approx(plate2.required_load(), 2.0), "ящик на плите, нужна нагрузка 2")
	await _walk_to(front, _keys(front), plate2.global_position.x - 30.0)
	await frames(30)
	check(plate2.active, "ящик и %s держат плиту (%.1f)" % [front.name, plate2.current_load])
	await _run_to(back, 35 * TILE)
	check(game.level.get_node("Latch2").active, "%s перепрыгнул, прошёл и нажал защёлку" % back.name)
	await _run_to(back, 38 * TILE)
	await _run_to(front, 36 * TILE)
	check(front.global_position.x > 33 * TILE and door2.position.y < 9 * TILE - 150.0, "%s прошёл в открытую дверь (%s)" % [front.name, front.global_position])

	# Плита на балке в 3 тайла: верхний держит её, нижний проходит и жмёт защёлку, верхний спрыгивает.
	var plank_x := 40 * TILE
	var support := b if b.global_position.x > a.global_position.x else a
	var climber := a if support == b else b
	await _walk_to(support, _keys(support), plank_x - 70.0)
	tap(_keys(support)[FREEZE])
	await _onto_head(climber, support)
	await _hop_to(climber, plank_x + 60.0, 14)
	var plate3: PressurePlate = game.level.get_node("Plate3")
	await _walk_to(climber, _keys(climber), plate3.global_position.x)
	await frames(30)
	check(plate3.active and climber.global_position.y < 9 * TILE, "%s держит плиту на балке" % climber.name)
	tap(_keys(support)[FREEZE])
	await _run_to(support, 52 * TILE)
	check(game.level.get_node("Latch3").active, "%s прошёл под балкой и нажал защёлку" % support.name)
	await _run_to(support, 54 * TILE)
	await _run_to(climber, 50 * TILE)
	await _both_to_finish()


func _level_08() -> void:
	# Тяжёлый ящик одному не сдвинуть — паровозиком к стене, по нему наверх.
	var crate1: Crate = game.level.get_node("HeavyCrate1")
	var x0 := crate1.global_position.x
	await _walk_to(b, KEYS_2, x0 - 60.0)
	await hold(KEYS_2[RIGHT], 40)
	check(absf(crate1.global_position.x - x0) < 2.0, "один тяжёлый ящик не сдвинул")
	await _push_heavy(crate1, 20 * TILE - 32.0)
	check(crate1.global_position.x > 19 * TILE, "вдвоём дотолкали тяжёлый ящик до стены (%s)" % crate1.global_position)
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), crate1.global_position.x - 70.0)
		await _jump(p, _keys(p), RIGHT, 18)
		await _jump(p, _keys(p), RIGHT, 40)
		check(p.is_on_floor() and p.global_position.y < 9 * TILE, "%s поднялся по ящику (%s)" % [p.name, p.global_position])

	# Плита на 2: держит только тяжёлый ящик, оба проходят.
	var crate2: Crate = game.level.get_node("HeavyCrate2")
	var plate2: PressurePlate = game.level.get_node("Plate2")
	await _push_heavy(crate2, plate2.global_position.x)
	await frames(30)
	check(plate2.active and Weight.floor_below(crate2) == plate2, "тяжёлый ящик держит плиту на 2")
	await _run_to(b, 37 * TILE)
	await _run_to(a, 36 * TILE)
	check(a.global_position.x > 35 * TILE and b.global_position.x > 35 * TILE, "оба прошли дверь")

	# Ящик нужен за дверью: на плите он держит дверь, защёлка за ней — навсегда.
	var crate3: Crate = game.level.get_node("HeavyCrate3")
	var plate3: PressurePlate = game.level.get_node("Plate3")
	var latch3: PressurePlate = game.level.get_node("Latch3")
	await _push_heavy(crate3, plate3.global_position.x)
	await frames(30)
	check(plate3.active, "тяжёлый ящик на плите — дверь открыта")
	var front := b if b.global_position.x > a.global_position.x else a
	await _run_to(front, latch3.global_position.x)
	check(latch3.active, "%s нажал защёлку за дверью" % front.name)
	await _run_to(front, 38 * TILE)  # назад, за ящик
	await _push_heavy(crate3, 54 * TILE - 32.0)
	check(crate3.global_position.x > 53 * TILE, "ящик дотолкали через дверь к стене (%s)" % crate3.global_position)
	# Стена 4 тайла: опора замирает на ящике, верхний — с её головы; опору вытягивают за руку.
	await _living_stair_and_pull(crate3, 54 * TILE, 5 * TILE)
	await _both_to_finish()


func _level_09() -> void:
	# Ярус 1 (4 тайла, x 18): ящик к стене, опора замирает на ящике, верхний — с её головы.
	var crate0: Crate = game.level.get_node("Crate0")
	await _push_crate(b, crate0, 18 * TILE - 32.0)
	var support := b
	var climber := a
	await _jump(support, _keys(support), RIGHT, 18)
	check(Weight.floor_below(support) == crate0, "опора на ящике")
	tap(_keys(support)[FREEZE])
	await _walk_to(climber, _keys(climber), crate0.global_position.x - 70.0)
	await _jump(climber, _keys(climber), RIGHT, 14)
	await frames(10)
	if climber.standing_on() != support:
		await _onto_head(climber, support)
	await _jump(climber, _keys(climber), RIGHT, 40)
	check(climber.is_on_floor() and climber.global_position.y < 8 * TILE, "живая лестница: ящик и товарищ — наверх (%s)" % climber.global_position)
	var latch1: PressurePlate = game.level.get_node("Latch1")
	await _walk_to(climber, _keys(climber), latch1.global_position.x)
	check(latch1.active, "защёлка опускает площадку")
	await frames(90)
	tap(_keys(support)[FREEZE])
	# С ящика — влево-вверх на площадку, с её края — вправо на ярус.
	var lift1: Door = game.level.get_node("Lift1")
	await _hop_to(support, lift1.global_position.x + 48.0)
	check(support.is_on_floor() and support.global_position.y < 10 * TILE, "опора на опущенной площадке (%s)" % support.global_position)
	await _walk_to(support, _keys(support), lift1.global_position.x + 80.0)
	await _hop_to(support, 18 * TILE + 40.0)
	check(support.is_on_floor() and support.global_position.y < 8 * TILE, "опора поднялась на ярус (%s)" % support.global_position)

	# Ярус 2 (4,5 тайла, x 34): ящика и головы мало — катапульта с замершего на ящике.
	var crate1: Crate = game.level.get_node("Crate1")
	var pusher := b if b.global_position.x > a.global_position.x else a
	var other := a if pusher == b else b
	await _push_crate(pusher, crate1, 34 * TILE - 32.0)
	check(crate1.global_position.x > 33 * TILE, "ящик у стены второго яруса (%s)" % crate1.global_position)
	await _jump(pusher, _keys(pusher), RIGHT, 18)
	check(Weight.floor_below(pusher) == crate1, "опора на ящике у стены")
	tap(_keys(pusher)[FREEZE])
	await _onto_head(other, pusher)
	await _jump(other, _keys(other), RIGHT, 40)
	check(other.global_position.y > 3.5 * TILE, "с ящика и головы на 4,5 тайла не запрыгнуть (%s)" % other.global_position)
	await _onto_head(other, pusher)
	await _catapult(pusher, _keys(pusher), other, _keys(other), RIGHT)
	check(other.is_on_floor() and other.global_position.y < 3.5 * TILE, "катапульта с ящика — на верхний ярус (%s)" % other.global_position)
	var latch2: PressurePlate = game.level.get_node("Latch2")
	await _walk_to(other, _keys(other), latch2.global_position.x)
	check(latch2.active, "защёлка опускает вторую площадку")
	await frames(90)
	tap(_keys(pusher)[FREEZE])
	var lift2: Door = game.level.get_node("Lift2")
	await _hop_to(pusher, lift2.global_position.x + 48.0)
	check(pusher.is_on_floor() and pusher.global_position.y < 5.25 * TILE, "опора на второй площадке (%s)" % pusher.global_position)
	await _walk_to(pusher, _keys(pusher), lift2.global_position.x + 80.0)
	await _hop_to(pusher, 34 * TILE + 40.0)
	check(pusher.is_on_floor() and pusher.global_position.y < 3.5 * TILE, "опора на верхнем ярусе (%s)" % pusher.global_position)
	await _both_to_finish()


func _level_10() -> void:
	# 1. Стена 4 тайла: ящик к стене, живая лестница, опору вытягивают за руку с ящика.
	var crate1: Crate = game.level.get_node("Crate1")
	await _push_crate(b, crate1, 18 * TILE - 32.0)
	await _living_stair_and_pull(crate1, 18 * TILE, 8 * TILE)

	# 2. Балка над пропастью: А замирает на конце балки, Б раскачивается на нём и перелетает.
	var tip := 33 * TILE
	await _walk_to(b, KEYS_2, tip - 200.0)
	place(a, Vector2(tip - Player.SIZE.x / 2.0 - 2.0, _stand_y(8)))
	await frames(10)
	check(game.level.active_checkpoint == 1, "чекпоинт на плато")
	var swung := await _swing_across(a, KEYS_1, b, KEYS_2, tip, 39 * TILE)
	check(swung, "маятник перенёс Б через пропасть (%s)" % b.global_position)
	var latch2: PressurePlate = game.level.get_node("Latch2")
	await _walk_to(b, KEYS_2, latch2.global_position.x)
	check(latch2.active, "Б нажал защёлку — мост под концом балки")
	await frames(60)
	tap(KEYS_1[FREEZE])
	await _run_to(a, 41 * TILE)
	await _walk_to(b, KEYS_2, 43 * TILE)
	check(a.alive and a.global_position.x > 39 * TILE, "А перешёл по мосту (%s)" % a.global_position)

	# 3. Плита на 3: тяжёлый ящик паровозиком и один игрок; второй проходит и жмёт защёлку.
	var crate3: Crate = game.level.get_node("HeavyCrate3")
	var plate3: PressurePlate = game.level.get_node("Plate3")
	var latch3: PressurePlate = game.level.get_node("Latch3")
	await _push_heavy(crate3, plate3.global_position.x)
	await frames(30)
	var holder := b if b.global_position.x > a.global_position.x else a
	var runner := a if holder == b else b
	check(plate3.active and Weight.floor_below(holder) == plate3, "тяжёлый ящик и %s держат плиту на 3 (%.1f)" % [holder.name, plate3.current_load])
	await _run_to(runner, latch3.global_position.x)
	check(latch3.active, "%s перепрыгнул, прошёл в дверь и нажал защёлку" % runner.name)
	await _run_to(runner, 61 * TILE)
	await _run_to(holder, 59 * TILE)
	check(holder.global_position.x > 55 * TILE, "%s прошёл в открытую дверь" % holder.name)

	# 4. Пропасть 3 и обрыв 3,5: катапульта с края, защёлка — мост и ступенька.
	var edge := 63 * TILE
	place(b, Vector2(edge - 200.0, _stand_y(9)))
	place(a, Vector2(edge - 26.0, _stand_y(9)))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await _onto_head(b, a)
	await _catapult(a, KEYS_1, b, KEYS_2, RIGHT)
	check(b.is_on_floor() and b.global_position.y < 5.5 * TILE, "катапульта забросила Б на обрыв (%s)" % b.global_position)
	var latch4: PressurePlate = game.level.get_node("Latch4")
	await _walk_to(b, KEYS_2, latch4.global_position.x)
	check(latch4.active, "Б нажал защёлку — мост и ступенька")
	await frames(60)
	tap(KEYS_1[FREEZE])
	await _walk_to(a, KEYS_1, 64.1 * TILE)
	await _hop_to(a, 65.5 * TILE, 14)
	check(a.is_on_floor() and a.global_position.y < 7.25 * TILE, "А на ступеньке (%s)" % a.global_position)
	await _hop_to(a, 66 * TILE + 60.0, 10)
	check(a.is_on_floor() and a.global_position.y < 5.5 * TILE, "А поднялся на обрыв (%s)" % a.global_position)

	# 5. Пропасть 7, дальний берег ниже: ступенька в воздухе, мост под замершего.
	await _walk_to(b, KEYS_2, 72 * TILE)
	await _walk_to(a, KEYS_1, 73 * TILE)
	check(game.level.active_checkpoint == 4, "чекпоинт на обрыве")
	var crossed := await _air_step(a, KEYS_1, b, KEYS_2, 75 * TILE, 82 * TILE, 6.5 * TILE, 30.0)
	check(crossed, "по замершему в воздухе Б перебрался через пропасть (a %s b %s)" % [a.global_position, b.global_position])
	var latch5: PressurePlate = game.level.get_node("Latch5")
	await _walk_to(b, KEYS_2, latch5.global_position.x)
	check(latch5.active, "Б нажал защёлку на том берегу")
	await frames(70)
	tap(KEYS_1[FREEZE])
	await frames(30)
	check(a.alive and a.is_on_floor(), "А встал на мост (%s)" % a.global_position)
	await _both_to_finish()


# --- Приёмы ---------------------------------------------------------------------------------
