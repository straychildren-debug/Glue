extends LevelBot
## Автопроверка уровней 11–20: пара проходит каждый задуманным путём от старта до двери.
## Проверяет и ложные пути — что без главной догадки не пройти.
## Запуск: Godot_console --headless --path . res://tests/stage7_levels_smoke.tscn [-- 11]

const LEVELS := {
	"11": preload("res://levels/w01_l11_seesaw.tscn"),
	"12": preload("res://levels/w01_l12_seesaw_throw.tscn"),
	"13": preload("res://levels/w01_l13_lift.tscn"),
	"14": preload("res://levels/w01_l14_chain.tscn"),
}
## Черновики: бот ещё доводится — запускаются только явно (-- 14), в общий прогон не входят.
const DRAFTS := ["14"]


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	var first := true
	for id: String in LEVELS:
		if not only.is_empty() and id not in only:
			continue
		if only.is_empty() and id in DRAFTS:
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


## 13 «Подъёмник». Комната 1: тормоз-рычаг, 2 против 1 поднимает одного; потом вниз уезжает
## груз, а не человек. Комната 2: «чехарда» — прыжок вес с площадки не снимает, а замерший в
## воздухе не весит: площадка поднимается под ним; второго поднимает ящик-противовес.
func _level_13() -> void:
	var level: GreyboxLevel = game.level
	var lift1: Lift = level.get_node("Lift1")
	var c1: Crate = level.get_node("Crate1")
	var c2: Crate = level.get_node("Crate2")
	var c3: Crate = level.get_node("Crate3")
	var left1: AnimatableBody2D = lift1.get_platforms()[0]
	var right1: AnimatableBody2D = lift1.get_platforms()[1]
	var lever1: Lever = level.get_node("Lever1")
	# Подъёмник на тормозе: загружаемся спокойно. Б справа, А закатывает ящик на левую площадку.
	await _run_to(b, 17.0 * TILE)
	await frames(30)
	check(Weight.floor_below(b) == right1 and absf(lift1.offset) < 1.0, "на тормозе один на площадке не уезжает")
	await _push_crate(a, c1, 13.0 * TILE)
	await _hop_exact(a, 14.1 * TILE)
	check(Weight.floor_below(a) == left1 and Weight.floor_below(c1) == left1,
			"А и ящик на левой площадке (a %s ящик %s)" % [a.global_position, c1.global_position])
	# А отпускает тормоз рычагом на перегородке: 2 против 1 — Б едет наверх.
	await _toggle_lever(a, KEYS_1, lever1)
	check(lever1.active and not lift1.is_locked() and a.grab_target == null,
			"А отпустил тормоз рычагом (и не схватил Б)")
	await frames(260)
	check(lift1.offset > 6.7 * TILE, "А и ящик слева перевесили — Б наверху (ход %.0f)" % lift1.offset)
	await _walk_to(b, KEYS_2, 20.0 * TILE)
	check(b.is_on_floor() and b.global_position.y < 5.25 * TILE, "Б сошёл на уступ")
	# Б грузит на свою площадку два ящика с уступа: 2 против 2 — стоит.
	await _hop_exact(b, 23.25 * TILE)
	await _push_crate(b, c2, 16.4 * TILE)
	await _walk_to(b, KEYS_2, 23.2 * TILE)
	await _hop_exact(b, 25.8 * TILE)
	await _push_crate(b, c3, 17.7 * TILE)
	await _walk_to(b, KEYS_2, 20.0 * TILE)
	await frames(30)
	check(Weight.floor_below(c2) == right1 and Weight.floor_below(c3) == right1 and lift1.offset > 6.0 * TILE,
			"два ящика на площадке Б — 2 против 2, стоит (ход %.0f, ящики %s %s)" % [lift1.offset, c2.global_position, c3.global_position])
	# А сталкивает свой ящик в тоннель: внизу остаётся только он, 1 против 2 — А едет наверх.
	await _push_crate(a, c1, 11.7 * TILE)
	await frames(450)
	check(lift1.offset < -6.7 * TILE and Weight.floor_below(a) == left1,
			"А столкнул ящик в тоннель и уехал наверх, ящики вниз (ход %.0f, a %s)" % [lift1.offset, a.global_position])
	await _walk_to(a, KEYS_1, 12.6 * TILE)
	await _run_jump(a, KEYS_1, 14.75 * TILE)
	await frames(30)
	check(a.is_on_floor() and a.global_position.y < 5.25 * TILE and a.global_position.x > 18.0 * TILE,
			"А с разбега перепрыгнул на уступ — оба наверху (%s)" % a.global_position)

	# --- Комната 2: «Чехарда».
	var lift2: Lift = level.get_node("Lift2")
	var c4: Crate = level.get_node("Crate4")
	var left2: AnimatableBody2D = lift2.get_platforms()[0]
	var right2: AnimatableBody2D = lift2.get_platforms()[1]
	var lever2: Lever = level.get_node("Lever2")
	await _run_to(b, 34.0 * TILE)
	await _run_to(a, 31.0 * TILE)
	await _walk_to(a, KEYS_1, 31.4 * TILE)
	await _toggle_lever(a, KEYS_1, lever2)
	await frames(30)
	check(lever2.active and Weight.floor_below(a) == left2 and Weight.floor_below(b) == right2 and absf(lift2.offset) < 4.0,
			"А и Б на площадках, тормоз отпущен: 1 против 1 — стоит (a %s b %s)" % [a.global_position, b.global_position])
	# Ложный путь: простой прыжок вес не снимает — площадка не едет.
	await _jump_up(b, KEYS_2)
	await frames(20)
	check(absf(lift2.offset) < 4.0, "Б подпрыгнул — подъёмник стоит (ход %.0f)" % lift2.offset)
	# Б поднимается чехардой: противовес — А внизу.
	await _chehard(b, KEYS_2, lift2, func() -> bool: return lift2.offset >= 6.0 * TILE - 1.0)
	check(lift2.offset >= 6.0 * TILE - 1.0 and Weight.floor_below(b) == right2,
			"Б чехардой поднялся до верха (ход %.0f)" % lift2.offset)
	# Б с выходного уступа сталкивает ящик на свою площадку — теперь противовес у А ящик.
	await _hop_exact(b, 37.4 * TILE)
	await _push_crate(b, c4, 34.0 * TILE)
	await _hop_exact(b, 36.6 * TILE)
	await frames(20)
	check(Weight.floor_below(c4) == right2 and b.global_position.y < 0.0,
			"Б положил ящик на поднятую площадку и вернулся на уступ (ход %.0f)" % lift2.offset)
	await _chehard(a, KEYS_1, lift2, func() -> bool: return lift2.offset <= -6.0 * TILE + 1.0)
	check(lift2.offset <= -6.0 * TILE + 1.0 and Weight.floor_below(a) == left2,
			"А чехардой поднялся до верха, ящик уехал вниз (ход %.0f)" % lift2.offset)
	await _walk_to(a, KEYS_1, 30.3 * TILE)
	await _run_jump(a, KEYS_1, 32.0 * TILE)
	await frames(30)
	check(a.is_on_floor() and a.global_position.y < 0.0 and a.global_position.x > 35.0 * TILE,
			"А с разбега на выходном уступе (%s)" % a.global_position)
	await _both_to_finish()


## 14 «Цепь». Комната 1: крюк над шипами — повиснуть, раскачаться, перелететь. Комната 2:
## высокий крюк достают только с головы товарища, второй цепляется за руку — и цепь перелетает.
## Комната 3: замерший — камень, шипы ему не страшны; кто стал мостом, тот выходит гибелью к
## чекпоинту, который товарищ уже взял на том берегу.
func _level_14() -> void:
	var level: GreyboxLevel = game.level
	var hook1: Hook = level.get_node("Hook1")
	var hook2: Hook = level.get_node("Hook2")
	# Комната 1: каждый сам — прыжок к крюку, раскачка, прыжок с хвата на тот берег.
	await _walk_to(a, KEYS_1, 7.5 * TILE)
	check(await _jump_to_hook(a, KEYS_1, hook1, 10.0 * TILE), "А в прыжке схватился за крюк над шипами")
	await _swing_off(a, KEYS_1, 20.0 * TILE)
	check(a.alive and a.is_on_floor() and a.global_position.x > 18.0 * TILE, "А перелетел шипы с крюка (%s)" % a.global_position)
	await _walk_to(b, KEYS_2, 7.5 * TILE)
	check(await _jump_to_hook(b, KEYS_2, hook1, 10.0 * TILE), "Б схватился за крюк")
	await _swing_off(b, KEYS_2, 19.0 * TILE)
	check(b.alive and b.is_on_floor() and b.global_position.x > 18.0 * TILE, "Б перелетел шипы (%s)" % b.global_position)

	# Комната 2: высокий крюк. Ложный путь: с прыжка не достать.
	await _walk_to(a, KEYS_1, 24.6 * TILE)
	await _walk_to(b, KEYS_2, 23.6 * TILE)
	await _walk_to(a, KEYS_1, 25.55 * TILE)
	press(KEYS_1[GRAB], true)
	await _jump_up(a, KEYS_1)
	check(a.grab_target == null and a.is_on_floor(), "с прыжка высокий крюк не достать")
	press(KEYS_1[GRAB], false)
	await frames(5)
	# Б с головы А прыгает к крюку, А в прыжке хватается за руку Б — цепь.
	await _onto_head(b, a)
	press(KEYS_2[GRAB], true)
	await _hop_exact(b, hook2.global_position.x)
	check(b.grab_target == hook2, "Б с головы А схватился за высокий крюк (%s)" % b.global_position)
	press(KEYS_1[GRAB], true)
	await _jump_up(a, KEYS_1)
	check(a.grab_target == b, "А в прыжке схватился за руку Б — цепь (%s)" % a.global_position)
	await _swing_off(a, KEYS_1, 39.0 * TILE, [KEYS_2])
	check(a.alive and a.is_on_floor() and a.global_position.x > 36.0 * TILE, "нижний в цепи перелетел шипы (%s)" % a.global_position)
	await _swing_off(b, KEYS_2, 38.0 * TILE)
	check(b.alive and b.is_on_floor() and b.global_position.x > 36.0 * TILE, "Б один раскачался на крюке и перелетел (%s)" % b.global_position)

	# Комната 3: широкие шипы. А прыгает в них и замирает — камень; Б по его голове на тот берег.
	await _walk_to(a, KEYS_1, 41.0 * TILE)
	await _walk_to(b, KEYS_2, 39.0 * TILE)
	await _walk_to(a, KEYS_1, 43.0 * TILE)
	press(KEYS_1[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		if a.global_position.x >= 44.8 * TILE:
			break
	press(KEYS_1[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		if a.velocity.y > 0.0 and a.global_position.y + Player.SIZE.y / 2.0 >= 12.0 * TILE:
			break
	tap(KEYS_1[FREEZE])
	press(KEYS_1[JUMP], false)
	press(KEYS_1[RIGHT], false)
	await frames(30)
	check(a.alive and a.frozen, "А замер над шипами — камень (%s)" % a.global_position)
	var landed := await _run_onto(b, KEYS_2, a, 44.8 * TILE)
	check(landed, "Б с разбега на голове А над шипами (%s)" % b.global_position)
	await _hop_exact(b, 53.5 * TILE)
	await frames(10)
	check(b.alive and b.is_on_floor() and b.global_position.x > 51.0 * TILE, "Б по голове А — на тот берег (%s)" % b.global_position)
	# А оживает в шипах — погибает, и оба появляются у чекпоинта, который взял Б.
	tap(KEYS_1[FREEZE])
	await frames(150)
	check(a.alive and a.global_position.x > 51.0 * TILE and b.global_position.x > 51.0 * TILE,
			"А ожил в шипах — оба у чекпоинта за ними (a %s b %s)" % [a.global_position, b.global_position])
	await _both_to_finish()


# --- Приёмы --------------------------------------------------------------------------------

## Разбег к краю edge_x и прыжок к крюку с зажатым хватом; true — повис на крюке.
## Хват остаётся зажатым.
func _jump_to_hook(p: Player, k: Array[Key], hook: Hook, edge_x: float) -> bool:
	press(k[GRAB], true)
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
		if p.grab_target == hook or not p.alive:
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	return p.grab_target == hook


## Раскачка на хвате (жмёт по ходу; helpers в цепи качают вместе) и прыжок с хвата вправо на
## взлёте; в полёте правит к target_x с торможением. Ждёт приземления.
func _swing_off(p: Player, k: Array[Key], target_x: float, helpers: Array = [], pump := 150) -> void:
	for i in 900:
		var right := p.velocity.x >= 0.0
		for keys: Array in [k] + helpers:
			press(keys[RIGHT], right)
			press(keys[LEFT], not right)
		await get_tree().physics_frame
		if i > pump and p.velocity.x > 250.0 and p.velocity.y < 0.0:
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


## Разбег, прыжок у края edge_x и посадка на голову target; true — стоит на нём.
func _run_onto(p: Player, k: Array[Key], target: Player, edge_x: float) -> bool:
	press(k[RIGHT], true)
	var jumped := false
	var landed := false
	for i in 200:
		await get_tree().physics_frame
		if not jumped and p.global_position.x >= edge_x - 12.0:
			press(k[JUMP], true)
			jumped = true
		if jumped:
			var dx := target.global_position.x - p.global_position.x
			press(k[RIGHT], dx > 4.0)
			press(k[LEFT], dx < -4.0)
			if i > 5 and p.is_on_floor():
				landed = p.standing_on() == target
				break
		if not p.alive:
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(5)
	return landed


## Нажать хват у рычага — переключить.
func _toggle_lever(p: Player, k: Array[Key], lever: Lever) -> void:
	var before := lever.active
	await hold(k[GRAB], 3)
	await frames(3)
	if lever.active == before:
		print("    рычаг не переключился: игрок %s, рычаг %s" % [p.global_position, lever.global_position])


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
