extends LevelBot
## Автопроверка уровней 11–20: пара проходит каждый задуманным путём от старта до двери.
## Проверяет и ложные пути — что без главной догадки не пройти.
## Запуск: Godot_console --headless --path . res://tests/stage7_levels_smoke.tscn [-- 11]

const LEVELS := {
	"11": preload("res://levels/w01_l11_seesaw.tscn"),
	"12": preload("res://levels/w01_l12_seesaw_throw.tscn"),
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

## 11 «Качели». Комната 1: ключ над поднятым концом, противовес 1 против 1, носитель ключа идёт
## первым, фиксатор жмут, пока противовес на месте. Комната 2: замерший в воздухе ничего не весит.
func _level_11() -> void:
	var level: GreyboxLevel = game.level
	var seesaw1: Seesaw = level.get_node("Seesaw1")
	var key: DoorKey = level.get_node("Key")
	var lock: KeyLock = level.get_node("KeyDoor/Lock")
	var latch: PressurePlate = level.get_node("LockLatch")
	var beam1 := seesaw1.get_beam()
	var pivot1 := seesaw1.global_position.x

	# Ложный путь: один на поднятый конец — и конец под ним опускается. (Б стоит впереди.)
	await _walk_to(b, KEYS_2, pivot1 - 5.5 * TILE)
	await _hop_to(b, pivot1 - 3.1 * TILE)
	await frames(40)
	check(Weight.floor_below(b) == beam1 and seesaw1.angle < -seesaw1.max_angle() + 0.01,
			"один запрыгнул на поднятый конец — и опустил его")
	check(key.carrier == null, "с опущенного конца ключ не достать")
	# Б уходит по балке на правый конец (теперь он внизу), А запрыгивает на поднятый левый.
	await _walk_to(b, KEYS_2, pivot1 + 3.1 * TILE)
	await frames(30)
	check(seesaw1.angle > seesaw1.max_angle() - 0.01, "Б на правом конце — он внизу")
	await _walk_to(a, KEYS_1, pivot1 - 5.5 * TILE)
	await _hop_to(a, pivot1 - 3.1 * TILE)
	await frames(40)
	check(Weight.floor_below(a) == beam1 and seesaw1.angle > seesaw1.max_angle() - 0.01,
			"А на поднятом левом конце, Б противовесом справа: 1 против 1 — стоит (a %s b %s угол %.2f)"
			% [a.global_position, b.global_position, seesaw1.angle])
	await _walk_to(a, KEYS_1, pivot1 - 3.05 * TILE)
	await _jump_up(a, KEYS_1)
	check(key.carrier == a, "А снял ключ с поднятого конца (a %s ключ %s)" % [a.global_position, key.global_position])

	# Б переходит на левую сторону: 2 против 0 — левый конец вниз, правый поднят.
	await _walk_to(b, KEYS_2, pivot1 - 0.8 * TILE)
	await frames(40)
	check(seesaw1.angle < -seesaw1.max_angle() + 0.01, "оба слева — правый конец поднялся")
	# А с ключом перепрыгивает через Б на правую половину (1 против 1) и идёт на поднятый конец.
	await _hop_to(a, pivot1 + 1.5 * TILE)
	await _walk_to(a, KEYS_1, pivot1 + 3.1 * TILE)
	await frames(20)
	check(seesaw1.angle < -seesaw1.max_angle() + 0.01, "А дошёл до поднятого конца, балка стоит")
	await _hop_to(a, 16.5 * TILE)
	check(a.is_on_floor() and a.global_position.y < 8 * TILE, "А на уступе")
	await _walk_to(a, KEYS_1, 18.6 * TILE)
	await frames(40)
	check(lock.active, "носитель ключа открыл замок двери")
	await _walk_to(a, KEYS_1, latch.global_position.x)
	await frames(10)
	check(latch.active and seesaw1.is_locked(), "А нажал фиксатор, пока Б стоит противовесом")

	# Б идёт по зафиксированной балке на поднятый конец и на уступ.
	await _walk_to(b, KEYS_2, pivot1 + 3.1 * TILE)
	await frames(20)
	check(seesaw1.angle < -seesaw1.max_angle() + 0.01, "зафиксированная балка не опрокинулась под Б")
	await _hop_to(b, 16.5 * TILE)
	check(b.is_on_floor() and b.global_position.y < 8 * TILE, "Б на уступе — оба наверху")

	# --- Комната 2: «Лёгкий шаг».
	var seesaw2: Seesaw = level.get_node("Seesaw2")
	var beam2 := seesaw2.get_beam()
	var pivot2 := seesaw2.global_position.x
	var end_x := pivot2 + 3.0 * TILE
	await _walk_to(a, KEYS_1, 30.0 * TILE)
	await _walk_to(b, KEYS_2, 28.0 * TILE)
	await _hop_to(a, pivot2 + 0.8 * TILE)
	await _walk_to(a, KEYS_1, end_x)
	check(Weight.floor_below(a) == beam2 and seesaw2.angle < -seesaw2.max_angle() + 0.01,
			"А на поднятом конце: ящик 1 против А 1 — стоит")
	# Ложный путь 1: с поднятого конца одному на стену не допрыгнуть.
	await _jump_up(a, KEYS_1)
	check(a.global_position.y > 4 * TILE and Weight.floor_below(a) == beam2, "с поднятого конца одному на стену не допрыгнуть")
	# Ложный путь 2: Б на голову стоящему А — 2 против 1, балка опрокидывается.
	await _onto_head(b, a)
	await frames(60)
	check(seesaw2.angle > seesaw2.max_angle() - 0.01, "Б на голове стоящего А: 2 против 1 — балка опрокинулась")
	# Выход без рестарта: Б спрыгивает, А уходит влево (2 против 0) и возвращается на поднятый конец.
	place(b, Vector2(28.0 * TILE, _stand_y(8)))
	await frames(20)
	await _walk_to(a, KEYS_1, pivot2 - 0.8 * TILE)
	await frames(40)
	await _walk_to(a, KEYS_1, end_x)
	await frames(20)
	check(seesaw2.angle < -seesaw2.max_angle() + 0.01 and Weight.floor_below(a) == beam2,
			"А снова на поднятом конце (a %s угол %.2f ящик %s)" % [a.global_position, seesaw2.angle, level.get_node("Crate").global_position])
	# А прыгает и замирает в воздухе невысоко над концом.
	var end_top := a.global_position.y + Player.SIZE.y / 2.0
	await _freeze_in_air(a, KEYS_1, end_top - 60.0)
	check(a.frozen, "А замер в воздухе над концом балки")
	await _walk_to(b, KEYS_2, 30.0 * TILE)  # вплотную к ящику на опущенном конце
	await _hop_to(b, pivot2 + 0.8 * TILE)
	await _walk_to(b, KEYS_2, end_x - 0.9 * TILE)
	check(seesaw2.angle < -seesaw2.max_angle() + 0.01, "Б на правом конце, замерший А ничего не весит — стоит")
	var landed := await _jump_onto(b, KEYS_2, a)
	check(landed and seesaw2.angle < -seesaw2.max_angle() + 0.01, "Б на голове замершего А — балка всё ещё стоит (a %s b %s)" % [a.global_position, b.global_position])
	await _hop_to(b, 40.5 * TILE)
	check(b.is_on_floor() and b.global_position.y < 3 * TILE, "Б с головы А — на стену 5,5 тайла")
	# А оживает, мягко падает на конец (балка стоит), прыгает — Б ловит его за руку.
	tap(KEYS_1[FREEZE])
	await frames(30)
	check(seesaw2.angle < -seesaw2.max_angle() + 0.01 and Weight.floor_below(a) == beam2,
			"А мягко опустился на конец балки — она стоит")
	await _walk_to(b, KEYS_2, 39.2 * TILE)
	await _pull_up(b, a, RIGHT)
	check(a.is_on_floor() and a.global_position.y < 3 * TILE, "Б вытянул А на стену")
	await _both_to_finish()


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


# --- Приёмы --------------------------------------------------------------------------------

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
