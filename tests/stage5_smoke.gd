extends SmokeTest
## Автопроверка этапа 5: пара проходит серые уровни 04–10 задуманным путём от старта до финиша,
## включая возврат того, кто был опорой. Ключевые приёмы — честными нажатиями: «Замри» в воздухе
## и приземление на товарища, катапульта, толкание ящиков, вытягивание за руку, маятник.
## Подходы к задаче (дойти до стены, встать на голову замершему) иногда сокращены телепортом.
## Запуск: Godot_console --headless --path . res://tests/stage5_smoke.tscn [-- 04 07]

const TILE := 64.0
const LEVELS := {
	"04": preload("res://levels/w01_l04_step_in_the_air.tscn"),
	"05": preload("res://levels/w01_l05_catapult.tscn"),
	"06": preload("res://levels/w01_l06_the_crate.tscn"),
	"07": preload("res://levels/w01_l07_hold_it.tscn"),
	"08": preload("res://levels/w01_l08_heavy_load.tscn"),
	"09": preload("res://levels/w01_l09_living_staircase.tscn"),
	"10": preload("res://levels/w01_l10_the_pass.tscn"),
}

## Раскладки: [влево, вправо, прыжок, замри, хват].
const KEYS_1: Array[Key] = [KEY_A, KEY_D, KEY_W, KEY_S, KEY_E]
const KEYS_2: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PERIOD]
enum { LEFT, RIGHT, JUMP, FREEZE, GRAB }

var game: Node
var a: Player
var b: Player


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


func _keys(p: Player) -> Array[Key]:
	return KEYS_1 if p == a else KEYS_2


## Толкает ящик к target_x: заходит с нужной стороны и упирается, пока ящик не дойдёт или не встанет.
func _push_crate(p: Player, crate: Crate, target_x: float) -> void:
	var dir := 1 if target_x > crate.global_position.x else -1
	var k := _keys(p)
	await _walk_to(p, k, crate.global_position.x - dir * 62.0)
	var key := k[RIGHT] if dir > 0 else k[LEFT]
	press(key, true)
	var last := crate.global_position.x
	var stuck := 0
	for i in 900:
		await get_tree().physics_frame
		if (crate.global_position.x - target_x) * dir >= 0.0:
			break
		stuck = stuck + 1 if absf(crate.global_position.x - last) < 0.3 else 0
		last = crate.global_position.x
		if stuck > 40:
			break
	press(key, false)
	await frames(10)


## Тяжёлый ящик — паровозиком: передний упирается в ящик, задний — в переднего.
func _push_heavy(crate: Crate, target_x: float) -> void:
	var dir := 1 if target_x > crate.global_position.x else -1
	var front := b if (b.global_position.x - a.global_position.x) * dir > 0.0 else a
	var back := a if front == b else b
	await _walk_to(front, _keys(front), crate.global_position.x - dir * 62.0)
	await _walk_to(back, _keys(back), front.global_position.x - dir * 50.0)
	var keys: Array[Key] = [_keys(front)[RIGHT if dir > 0 else LEFT], _keys(back)[RIGHT if dir > 0 else LEFT]]
	for key in keys:
		press(key, true)
	var last := crate.global_position.x
	var stuck := 0
	for i in 1200:
		await get_tree().physics_frame
		if (crate.global_position.x - target_x) * dir >= 0.0:
			break
		stuck = stuck + 1 if absf(crate.global_position.x - last) < 0.3 else 0
		last = crate.global_position.x
		if stuck > 40:
			break
	for key in keys:
		press(key, false)
	await frames(10)


## Ящик у стены wall_x высотой до top_y: опора замирает на ящике, верхний встаёт ей на голову
## и прыгает наверх; затем опора прыгает с ящика, верхний ловит её за руку и вытягивает.
func _living_stair_and_pull(crate: Crate, wall_x: float, top_y: float) -> void:
	var support := a if absf(a.global_position.x - crate.global_position.x) < absf(b.global_position.x - crate.global_position.x) else b
	var climber := b if support == a else a
	await _walk_to(support, _keys(support), crate.global_position.x - 70.0)
	await _jump(support, _keys(support), RIGHT, 18)
	check(Weight.floor_below(support) == crate, "%s стоит на ящике" % support.name)
	tap(_keys(support)[FREEZE])
	await _walk_to(climber, _keys(climber), crate.global_position.x - 150.0)
	await _onto_head(climber, support)
	await _jump(climber, _keys(climber), RIGHT, 40)
	check(climber.is_on_floor() and climber.global_position.y < top_y, "%s по ящику и голове товарища — наверх (%s)" % [climber.name, climber.global_position])
	tap(_keys(support)[FREEZE])
	await _walk_to(climber, _keys(climber), wall_x + 26.0)
	await _pull_up(climber, support, RIGHT)
	check(support.is_on_floor() and support.global_position.y < top_y, "%s вытянул %s наверх (%s)" % [climber.name, support.name, support.global_position])


## top стоит у края и держит хват; low прыгает вверх, top ловит его за руку и отходит от края.
func _pull_up(top: Player, low: Player, away: int) -> void:
	press(_keys(top)[GRAB], true)
	await frames(5)
	press(_keys(low)[JUMP], true)
	await frames(22)
	press(_keys(low)[JUMP], false)
	check(top.grab_target == low, "%s поймал %s за руку (top %s low %s)" % [top.name, low.name, top.global_position, low.global_position])
	await hold(_keys(top)[away], 60)
	press(_keys(top)[GRAB], false)
	await frames(25)


## Бот бежит к target_x и перепрыгивает препятствия и ямы на пути.
func _run_to(p: Player, target_x: float, max_frames := 900) -> void:
	var dir := 1 if target_x > p.global_position.x else -1
	var k := _keys(p)
	var key := k[RIGHT] if dir > 0 else k[LEFT]
	var space := p.get_world_2d().direct_space_state
	var jump_frames := 0
	press(key, true)
	for i in max_frames:
		if (p.global_position.x - target_x) * dir >= 0.0:
			break
		if p.alive and p.is_on_floor() and jump_frames == 0:
			var ahead := p.global_position + Vector2(36.0 * dir, 0.0)
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 100.0),
					Player.LAYER_WORLD | Crate.LAYER_OBJECTS | Player.LAYER_PLAYERS, [p.get_rid()])
			if space.intersect_ray(query).is_empty() or p.is_on_wall():
				jump_frames = 20
		press(k[JUMP], jump_frames > 0)
		jump_frames = maxi(jump_frames - 1, 0)
		await get_tree().physics_frame
	press(key, false)
	press(k[JUMP], false)
	await frames(10)


## «Ступенька в воздухе»: А с разбега прыгает с края и замирает, когда, падая, опустится
## до freeze_above px над уровнем берега. Б с разбега прыгает, приземляется на голову А
## и прыгает дальше — на дальний берег (far_x — его край, far_top — его верх).
func _air_step(p: Player, kp: Array[Key], q: Player, kq: Array[Key], edge_x: float, far_x: float,
		far_top: float, freeze_above: float) -> bool:
	var bank_top := p.global_position.y + Player.SIZE.y / 2.0 + 1.0
	place(p, Vector2(edge_x - 160.0, p.global_position.y))
	place(q, Vector2(edge_x - 420.0, q.global_position.y))
	await frames(10)
	press(kp[RIGHT], true)
	var jumped := false
	for i in 120:
		await get_tree().physics_frame
		if not jumped and p.global_position.x >= edge_x - 12.0:
			press(kp[JUMP], true)
			jumped = true
		var feet := p.global_position.y + Player.SIZE.y / 2.0
		if jumped and p.velocity.y > 0.0 and feet >= bank_top - freeze_above:
			break
	tap(kp[FREEZE])
	press(kp[RIGHT], false)
	press(kp[JUMP], false)
	await frames(2)
	if not p.frozen:
		return false
	print("    А замер в воздухе в %s" % p.global_position)
	# Б с разбега: прыжок у края, в воздухе правит к А.
	press(kq[RIGHT], true)
	jumped = false
	var landed := false
	for i in 150:
		await get_tree().physics_frame
		if not jumped and q.global_position.x >= edge_x - 12.0:
			press(kq[JUMP], true)
			jumped = true
		if jumped:
			var dx := p.global_position.x - q.global_position.x
			press(kq[RIGHT], dx > 4.0)
			press(kq[LEFT], dx < -4.0)
			if q.is_on_floor() and q.standing_on() == p:
				landed = true
				break
		if not q.alive:
			break
	press(kq[LEFT], false)
	press(kq[RIGHT], false)
	press(kq[JUMP], false)
	if not landed:
		print("    Б не попал на А: %s" % q.global_position)
		return false
	await frames(4)
	# С головы — прыжок вперёд, держим направление до приземления.
	press(kq[RIGHT], true)
	press(kq[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		if i > 5 and q.is_on_floor():
			break
	press(kq[JUMP], false)
	press(kq[RIGHT], false)
	await frames(5)
	return q.alive and q.is_on_floor() and q.global_position.x > far_x and q.global_position.y < far_top


## Маятник: p замер на конце балки tip_x, q сходит с его головы, держась за руку, раскачивается
## и прыгает с хвата на взлёте, выйдя из-под балки. Успех — q стоит на берегу правее far_x.
func _swing_across(p: Player, kp: Array[Key], q: Player, kq: Array[Key], tip_x: float, far_x: float) -> bool:
	tap(kp[FREEZE])
	await _onto_head(q, p)
	press(kq[GRAB], true)
	await hold(kq[RIGHT], 20)  # сходит с головы и повисает
	await frames(30)
	if q.grab_target != p:
		press(kq[GRAB], false)
		return false
	var clear_x := tip_x + Player.SIZE.x / 2.0 + 8.0
	var reach := 0.0
	for i in 600:
		var right := q.velocity.x >= 0.0
		press(kq[RIGHT], right)
		press(kq[LEFT], not right)
		await get_tree().physics_frame
		reach = maxf(reach, q.global_position.x - p.global_position.x)
		if reach > 80.0 and q.global_position.x > clear_x and q.velocity.x > 300.0 and q.velocity.y < 0.0:
			break
	press(kq[LEFT], false)
	press(kq[JUMP], true)
	await frames(2)
	press(kq[GRAB], false)
	press(kq[RIGHT], true)
	await frames(70)
	press(kq[JUMP], false)
	press(kq[RIGHT], false)
	await frames(10)
	return q.alive and q.is_on_floor() and q.global_position.x > far_x


## Катапульта: q стоит на замершем p, p резко наклоняется в сторону direction; q держит
## направление в полёте, пока не приземлится.
func _catapult(p: Player, kp: Array[Key], q: Player, kq: Array[Key], direction: int) -> void:
	press(kq[direction], true)
	press(kp[direction], true)
	await frames(10)
	press(kp[direction], false)
	for i in 80:
		await get_tree().physics_frame
		if i > 10 and q.is_on_floor():
			break
	press(kq[direction], false)
	await frames(10)


## q встаёт на голову p (подход сокращён телепортом).
func _onto_head(q: Player, p: Player) -> void:
	place(q, p.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(15)


## Идёт к x (влево или вправо); останавливается, дойдя.
func _walk_to(p: Player, k: Array[Key], x: float, max_frames := 600) -> void:
	var right := x > p.global_position.x
	var key := k[RIGHT] if right else k[LEFT]
	press(key, true)
	for i in max_frames:
		if (p.global_position.x >= x) == right:
			break
		await get_tree().physics_frame
	press(key, false)
	await frames(10)


## Разбег до края и прыжок с него.
func _run_jump(p: Player, k: Array[Key], edge_x: float) -> void:
	press(k[RIGHT], true)
	for i in 200:
		if p.global_position.x >= edge_x - 12.0:
			break
		await get_tree().physics_frame
	press(k[JUMP], true)
	await frames(40)
	press(k[JUMP], false)
	press(k[RIGHT], false)


## Полный прыжок с удержанием направления; ждёт приземления (или гибели).
func _jump(p: Player, k: Array[Key], direction: int, count: int) -> void:
	press(k[JUMP], true)
	press(k[direction], true)
	await frames(count)
	press(k[JUMP], false)
	press(k[direction], false)
	for i in 90:
		if p.is_on_floor() or not p.alive:
			break
		await get_tree().physics_frame
	await frames(5)


## Прыжок к target_x с подруливанием в воздухе (после delay кадров): на площадку или уступ.
func _hop_to(p: Player, target_x: float, delay := 0) -> void:
	var k := _keys(p)
	press(k[JUMP], true)
	for i in 100:
		await get_tree().physics_frame
		if i == 30:
			press(k[JUMP], false)
		var dx := target_x - p.global_position.x
		var steer := i >= delay and absf(dx) > 6.0
		press(k[RIGHT], steer and dx > 0.0)
		press(k[LEFT], steer and dx < 0.0)
		if i > 5 and (p.is_on_floor() or not p.alive):
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(5)


## Оба идут в дверь: первым — тот, кто ближе к ней.
func _both_to_finish() -> void:
	var door_x: float = game.level.get_finish().global_position.x
	var first := b if b.global_position.x > a.global_position.x else a
	var second := a if first == b else b
	await _walk_to(first, KEYS_2 if first == b else KEYS_1, door_x + 30.0)
	await _walk_to(second, KEYS_2 if second == b else KEYS_1, door_x - 30.0)
	await frames(5)


## Перезапускает игру на другом уровне; подключённые игроки остаются.
func _load(level: PackedScene) -> void:
	game.queue_free()
	await frames(2)
	game = GAME_SCENE.instantiate()
	game.level_scene = level
	add_child(game)
	await frames(20)


## Центр стоящего игрока над полом с верхом на высоте row тайлов.
func _stand_y(row: float) -> float:
	return row * TILE - Player.SIZE.y / 2.0 - 1.0
