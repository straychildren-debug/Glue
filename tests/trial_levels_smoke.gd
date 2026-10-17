extends LevelBot
## Автопроверка пробных сложных уровней (решение 58): пара проходит каждый задуманным путём
## и проверяет ложные пути.
## Запуск: Godot_console --headless --fixed-fps 60 --path . res://tests/trial_levels_smoke.tscn [-- 01]

## Кадры нажатий в «Эстафете» (середины окон замера tests/tuning/t06_windows, относительно старта бегущего).
const T06_PRESS: Array[int] = [30, 40, 82, 40, 42, 32, -6, 38, 20, 28]
## То же для «Эстафеты» мира 1 (w01_l11): связки 3 и 9, где вместо лент пилы.
const T06_W1_PRESS: Array[int] = [-4, 42]

const LEVELS := {
	"01": preload("res://levels/trial/t01_cargo_spring.tscn"),
	"02": preload("res://levels/trial/t02_two_buttons.tscn"),
	"03": preload("res://levels/trial/t03_crane_wind.tscn"),
	"04": preload("res://levels/trial/t04_crate_from_far.tscn"),
	"05": preload("res://levels/trial/t05_four_colors.tscn"),
	"06": preload("res://levels/trial/t06_relay.tscn"),
	"07": preload("res://levels/trial/t07_rockfall.tscn"),
}

var deaths := 0
var camera: SharedCamera


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	var first := true
	var catalog := _catalog()
	for id: String in catalog:
		if not only.is_empty() and id not in only:
			continue
		if first:
			game = await start_game(catalog[id])
			first = false
		else:
			await _load(catalog[id])
		camera = game.get_node("SharedCamera")
		a = game.players[0]
		b = game.players[1]
		deaths = 0
		for p: Player in [a, b]:
			p.died.connect(func(who: Player) -> void:
				deaths += 1
				print("    гибель %s в %s%s" % [who.name, who.global_position.round(), " (замерший)" if who.frozen else ""]))
		print("— ", game.level.title)
		await call(_method(id))
		check(game.completed, "оба в двери — уровень пройден (a %s b %s)" % [a.global_position, b.global_position])
	finish()


## Уровни набора: id → сцена. Наследники (тест мира 1) подставляют свои.
func _catalog() -> Dictionary:
	return LEVELS


## Какой бот проходит уровень id.
func _method(id: String) -> String:
	return "_level_" + id


## 01 «Груз на пружине». Ящик с полки — на батут (прыгает без конца); порыв мехов, пойманный
## в прыжке ящика, несёт его через пропасть в стену и в лунку с плитой. Ящик по ломкому настилу
## не протолкнуть (толкающий с ящиком — двое, настил рушится). Плите нужен вес 2: ящик и игрок
## на нём; второй проходит дверь и ставит защёлку.
func _level_01() -> void:
	var level: GreyboxLevel = game.level
	var crate: Crate = level.get_node("Crate")
	var pad: SpringPad = level.get_node("Pad")
	var plate: PressurePlate = level.get_node("Plate")
	var latch: PressurePlate = level.get_node("Latch")
	var bridge: BrittleFloor = level.get_node("Bridge")
	# Ложный путь: толкать ящик по настилу — настил рушится под двоими.
	crate.global_position = Vector2(14.0 * TILE, 12 * TILE - 31.0)
	place(b, Vector2(12.9 * TILE, _stand_y(12)))
	await frames(10)
	await _push_crate(b, crate, 17.0 * TILE)
	for i in 60:
		if bridge.broken:
			break
		await get_tree().physics_frame
	check(bridge.broken, "толкать ящик по настилу — рушится")
	await _dies(b)
	await _respawned()
	check(not bridge.broken and crate.global_position.y < 9 * TILE, "после респавна настил цел, ящик на полке")
	# Б на полке за ящиком (подход сокращён: живая лестница или батут — уровень 03 мира 2).
	place(b, Vector2(6.2 * TILE, 9 * TILE - 29.0))
	await _walk_to(a, KEYS_1, 12.1 * TILE)
	await frames(20)
	# Б сталкивает ящик на батут: толкает, пока ящик не сорвался с края, и останавливается.
	await _walk_to(b, KEYS_2, crate.global_position.x - 62.0)
	press(KEYS_2[RIGHT], true)
	for i in 300:
		await get_tree().physics_frame
		if crate.global_position.x > 10.0 * TILE + 26.0:
			break  # ящик сейчас сорвётся сам; толкающий остаётся на краю
	press(KEYS_2[RIGHT], false)
	var bounces := 0
	var last_vy := 0.0
	for i in 240:
		await get_tree().physics_frame
		if crate.velocity.y < -500.0 and last_vy >= 0.0:
			bounces += 1
		last_vy = crate.velocity.y
		if bounces >= 2:
			break
	check(bounces >= 2, "ящик прыгает на батуте")
	# А жмёт педаль, как только ящик снова оттолкнулся от батута.
	last_vy = crate.velocity.y
	for i in 120:
		await get_tree().physics_frame
		if crate.velocity.y < -500.0 and last_vy >= 0.0:
			break
		last_vy = crate.velocity.y
	await _walk_to(a, KEYS_1, 13.8 * TILE)
	for i in 180:
		if plate.active or Weight.floor_below(crate) == plate:
			break
		await get_tree().physics_frame
	check(Weight.floor_below(crate) == plate, "порыв донёс ящик через пропасть в лунку с плитой (%s)" % crate.global_position)
	# Б спрыгивает с полки; по настилу — по одному.
	await _walk_to(b, KEYS_2, 11.6 * TILE)
	await frames(30)
	for p: Player in [b, a]:
		await _run_to(p, 20.6 * TILE if p == b else 20.3 * TILE)
		check(p.alive and p.global_position.x > 20 * TILE and not bridge.broken, "%s перешёл настил один" % p.name)
		if p == b:
			await _walk_to(b, KEYS_2, 22.0 * TILE)
			await frames(20)
			check(plate.active, "Б встал на ящик в лунке — плита нажата (вес 2), дверь открыта")
	await _run_to(a, latch.global_position.x)
	await frames(10)
	check(latch.active, "А прошёл дверь и поставил защёлку")
	await _run_to(b, 28.0 * TILE)
	await _both_to_finish()


## 02 «Две кнопки». Два коридора друг над другом; двери верхнего открывают кнопки нижнего и
## наоборот. Кнопка держит нажатие 0,9 с: проходящий бежит к двери в тот момент, когда товарищ
## вскакивает на кнопку. Выход открывают две кнопки (верхняя и нижняя) в одно окно 0,5 с.
func _level_02() -> void:
	var level: GreyboxLevel = game.level
	var exit: Door = level.get_node("Exit")
	var exit_closed := exit.global_position
	# Б — в нижний коридор, А — наверх: на насест и на перекрытие.
	await _walk_to(b, KEYS_2, 8.9 * TILE)
	place(a, Vector2(4.2 * TILE, _stand_y(10)))  # подход сокращён: на насест — прыжком с разбега
	await frames(10)
	await _hop_to(a, 6.8 * TILE)
	check(a.is_on_floor() and a.global_position.y < 8 * TILE, "А в верхнем коридоре (%s)" % a.global_position)
	await _walk_to(a, KEYS_1, 11.2 * TILE)
	# Ложный путь: кнопка без бегущего — дверь закрылась, пока до неё шли.
	await _walk_to(b, KEYS_2, 10.0 * TILE)
	await frames(80)
	await _walk_to(a, KEYS_1, 12.6 * TILE)
	check(a.global_position.x < 11.8 * TILE, "кнопка отжалась — дверь закрыта, одному не успеть (%s)" % a.global_position)
	await _walk_to(b, KEYS_2, 8.9 * TILE)
	# Проходы: один вскакивает на кнопку — второй в тот же миг бежит в дверь.
	await _sync_pass(b, KEYS_2, 10.0, a, KEYS_1, 13.3)  # Б жмёт L1 — А проходит U1
	await _walk_to(b, KEYS_2, 16.2 * TILE)
	await _sync_pass(a, KEYS_1, 15.0, b, KEYS_2, 18.2)  # А жмёт U1p — Б проходит D1
	await _walk_to(a, KEYS_1, 20.7 * TILE)
	await _sync_pass(b, KEYS_2, 20.0, a, KEYS_1, 22.8)  # Б жмёт L2 — А проходит U2
	await _walk_to(b, KEYS_2, 25.7 * TILE)
	await _sync_pass(a, KEYS_1, 24.5, b, KEYS_2, 27.8)  # А жмёт U2p — Б проходит D2
	check(a.global_position.x > 22.5 * TILE and b.global_position.x > 27.5 * TILE, "оба прошли свои двери (a %s b %s)" % [a.global_position, b.global_position])
	# Выход: одна кнопка — мало; обе в одно окно — дверь открыта насовсем.
	await _walk_to(a, KEYS_1, 27.9 * TILE)
	await _walk_to(b, KEYS_2, 29.5 * TILE)
	await frames(40)
	check(exit.global_position.is_equal_approx(exit_closed), "одна нижняя кнопка — выход закрыт")
	await _walk_to(b, KEYS_2, 27.9 * TILE)
	await frames(10)
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 30:
		await get_tree().physics_frame
		press(KEYS_1[RIGHT], a.global_position.x < 29.3 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 29.3 * TILE)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(60)
	check(exit.global_position.y < exit_closed.y - 100.0, "обе кнопки в одно окно — выход открыт и остался открытым")
	await _walk_to(a, KEYS_1, 31.4 * TILE)
	for i in 60:
		if a.is_on_floor() and a.global_position.y > 11 * TILE:
			break
		await get_tree().physics_frame
	await _both_to_finish()


## 03 «Кран и ветер». Крюк крана довозит только до середины пропасти; дальше — порыв мехов,
## пойманный в прыжке с крюка. Плита крана и педаль мехов далеко друг от друга: один не успеет
## сойти с плиты и нажать педаль — плиту держит ящик. Без ветра с крюка не долететь.
## На том берегу защёлка поднимает мост для второго.
func _level_03() -> void:
	var level: GreyboxLevel = game.level
	var crane: Crane = level.get_node("Crane")
	var bellows: Bellows = level.get_node("Bellows")
	var hook := crane.hook
	await _walk_to(a, KEYS_1, 3.9 * TILE)
	await _walk_to(b, KEYS_2, hook.global_position.x)
	await frames(80)  # Б прошёл по педали — порыв должен стихнуть
	# Ложный путь: без ветра с крюка до того берега не долететь.
	await _hang_on(b, KEYS_2, hook)
	await _walk_to(a, KEYS_1, 2.6 * TILE)
	await _wait_hook_end(hook)
	var before := deaths
	press(KEYS_2[GRAB], false)
	for i in 120:
		if deaths > before:
			break
		await get_tree().physics_frame
	check(deaths > before, "без ветра с крюка не долететь — гибель на шипах")
	await frames(90)
	# Ложный путь: А сам на плите и бежит к педали — пока бежит, крюк уезжает назад, поздно.
	# (Ящик убран с дороги — даже так не выходит.)
	var crate: Crate = level.get_node("Crate")
	crate.global_position = Vector2(27.0 * TILE, 10.0 * TILE)
	await _walk_to(b, KEYS_2, hook.global_position.x)
	await frames(80)
	await _hang_on(b, KEYS_2, hook)
	await _walk_to(a, KEYS_1, 1.75 * TILE)
	await _wait_hook_end(hook)
	before = deaths
	for i in 90:
		press(KEYS_1[RIGHT], a.global_position.x < 5.5 * TILE)
		await get_tree().physics_frame
		if bellows.is_blowing():
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[GRAB], false)
	for i in 150:
		if deaths > before or b.is_on_floor():
			break
		await get_tree().physics_frame
	check(deaths > before, "с плиты к педали не успеть — Б не долетел (%s)" % b.global_position)
	await frames(90)
	# Задуманный путь: Б на крюке, А задвигает ящик на плиту и ждёт у педали.
	await _walk_to(a, KEYS_1, 3.9 * TILE)
	await _walk_to(b, KEYS_2, hook.global_position.x)
	await frames(80)
	await _hang_on(b, KEYS_2, hook)
	await _walk_to(a, KEYS_1, 2.6 * TILE)
	await _walk_to(a, KEYS_1, 3.7 * TILE)  # с разгона проскакивает ≈ 0,4: дальше — край педали
	check(crane.hook.global_position.x > 8.0 * TILE, "ящик держит плиту — кран едет без А (%s)" % hook.global_position)
	await _wait_hook_end(hook)
	for i in 90:
		press(KEYS_1[RIGHT], a.global_position.x < 5.5 * TILE)
		await get_tree().physics_frame
		if bellows.is_blowing():
			break
	press(KEYS_1[RIGHT], false)
	check(bellows.is_blowing(), "А на педали — порыв (%s)" % a.global_position)
	# Порыв раскачивает висящего вперёд: отпустить крюк на взмахе, когда скорость вперёд наибольшая.
	var top_speed := 0.0
	for i in 60:
		await get_tree().physics_frame
		if b.velocity.x < top_speed - 5.0:
			break
		top_speed = maxf(top_speed, b.velocity.x)
	press(KEYS_2[GRAB], false)
	for i in 120:
		if b.is_on_floor() or not b.alive:
			break
		await get_tree().physics_frame
	check(b.alive and b.global_position.x > 20.0 * TILE, "порыв донёс Б с крюка на тот берег (%s)" % b.global_position)
	# Защёлка поднимает мост — А переходит.
	await _walk_to(b, KEYS_2, 22.75 * TILE)
	await frames(90)
	await _walk_to(a, KEYS_1, 21.5 * TILE)
	check(a.alive and a.global_position.x > 20.0 * TILE, "А перешёл по мосту (%s)" % a.global_position)
	await _both_to_finish()


## 04 «Ящик с той стороны». Четыре комнаты в ряд. Оранжевая плита у старта открывает дверь 0,
## синие (у старта и в последней комнате) открывают дверь 1 и закрывают дверь 2 (обратная).
## Единственный ящик стоит в последней комнате: его надо привезти к старту на оранжевую плиту,
## а потом пройти связку дверей 1–2 «передачей» через дальнюю синюю плиту.
func _level_04() -> void:
	var level: GreyboxLevel = game.level
	var crate: Crate = level.get_node("Crate")
	var doors: Array[Door] = [level.get_node("Door0"), level.get_node("Door1"), level.get_node("Door2")]
	var closed: Array[float] = []
	for d in doors:
		closed.append(d.get("_closed_position").y)
	var is_open := func(i: int) -> bool: return doors[i].global_position.y < closed[i] - 150.0
	# Б уходит вперёд: А держит оранжевую, затем синюю, затем сходит.
	await _walk_to(a, KEYS_1, 3.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 16.5 * TILE)
	await _walk_to(a, KEYS_1, 6.5 * TILE)
	await frames(30)
	check(is_open.call(1) and not is_open.call(2), "синяя плита: дверь 1 открыта, обратная дверь 2 закрыта")
	await _walk_to(b, KEYS_2, 22.5 * TILE)
	await _walk_to(a, KEYS_1, 9.0 * TILE)
	await frames(40)
	check(not is_open.call(1) and is_open.call(2), "сошёл с синей: дверь 1 закрылась, дверь 2 открылась")
	await _walk_to(b, KEYS_2, 26.5 * TILE)
	check(b.global_position.x > 26.0 * TILE, "Б в последней комнате, А один у старта (%s)" % b.global_position)
	# Ложный путь: в одиночку А из стартовой не выйти — оранжевая отпускает дверь 0, как только с неё сходят.
	await _walk_to(a, KEYS_1, 3.0 * TILE)
	await frames(20)
	await _walk_to(a, KEYS_1, 12.6 * TILE)
	await frames(30)
	check(a.global_position.x < 13.0 * TILE - 21.0, "один до двери 0 не успевает — нужен груз на оранжевую (%s)" % a.global_position)
	# Ящик — назад, к старту: дверь 2 открыта (синие свободны), дверь 1 — А на синей, дверь 0 — А на оранжевой.
	await _hop_to(b, 30.0 * TILE)
	await _push_crate(b, crate, 22.5 * TILE)
	check(crate.global_position.x < 25.0 * TILE, "ящик провезён через обратную дверь 2 (%s)" % crate.global_position)
	await _walk_to(a, KEYS_1, 6.5 * TILE)
	await frames(30)
	await _push_crate(b, crate, 16.5 * TILE)
	await _walk_to(a, KEYS_1, 3.0 * TILE)
	await frames(30)
	await _push_crate(b, crate, 9.0 * TILE)
	check(crate.global_position.x < 13.0 * TILE, "ящик привезён в стартовую комнату (%s)" % crate.global_position)
	await _walk_to(a, KEYS_1, 1.5 * TILE)
	await _push_crate(b, crate, 3.0 * TILE)
	await frames(30)
	check(is_open.call(0), "ящик на оранжевой — дверь 0 открыта насовсем")
	# Передача: А на синей — Б в комнату 2; А сходит — Б в последнюю, на дальнюю синюю; А проходит дверь 1;
	# Б сходит — А проходит дверь 2.
	await _walk_to(b, KEYS_2, 10.0 * TILE)
	await _hop_to(a, 5.0 * TILE)
	await _walk_to(a, KEYS_1, 6.5 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 22.5 * TILE)
	await _walk_to(a, KEYS_1, 9.0 * TILE)
	await frames(40)
	await _walk_to(b, KEYS_2, 32.0 * TILE)
	await frames(40)
	check(is_open.call(1) and not is_open.call(2), "Б на дальней синей: дверь 1 открыта")
	await _walk_to(a, KEYS_1, 22.5 * TILE)
	check(a.global_position.x > 20.0 * TILE, "А прошёл двери 0 и 1 (%s)" % a.global_position)
	await _walk_to(b, KEYS_2, 34.0 * TILE)
	await frames(40)
	await _walk_to(a, KEYS_1, 29.0 * TILE)
	check(a.global_position.x > 26.0 * TILE, "А прошёл обратную дверь 2 (%s)" % a.global_position)
	await _both_to_finish()


## 05 «Четыре цвета». Пять комнат. Оранжевая (старт) открывает двери 0 и 1; зелёная (комната 1)
## открывает двери 0 и 1 и закрывает обратную дверь 2; синяя (комната 3) открывает дверь 1;
## фиолетовая защёлка (комната 3, порог 2) вместе с оранжевой открывает выход — дверь 3.
## Ящик — в финишной комнате. Обоим надо попасть в комнату 3 и встать на фиолетовую, затем
## один возвращается на оранжевую, второй везёт ящик из финиша на оранжевую.
func _level_05() -> void:
	var level: GreyboxLevel = game.level
	var crate: Crate = level.get_node("Crate")
	var purple: PressurePlate = level.get_node("PlatePurple")
	var doors: Array[Door] = []
	var closed: Array[float] = []
	for i in 4:
		doors.append(level.get_node("Door%d" % i))
		closed.append(doors[i].get("_closed_position").y)
	var is_open := func(i: int) -> bool: return doors[i].global_position.y < closed[i] - 150.0
	# А на оранжевой — Б в комнату 1 на зелёную; А перепрыгивает Б и идёт в комнату 2.
	await _walk_to(a, KEYS_1, 4.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 17.5 * TILE)
	await frames(30)
	check(not is_open.call(2), "Б на зелёной — обратная дверь 2 закрыта")
	await _walk_to(a, KEYS_1, 16.0 * TILE)
	await _hop_to(a, 19.5 * TILE)
	await _walk_to(a, KEYS_1, 27.0 * TILE)
	check(a.global_position.x > 25.0 * TILE, "А в комнате 2 (%s)" % a.global_position)
	# Б сходит с зелёной — дверь 2 открыта; А в комнату 3, на синюю — Б в комнату 2.
	await _walk_to(b, KEYS_2, 15.0 * TILE)
	await frames(40)
	await _walk_to(a, KEYS_1, 34.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 27.0 * TILE)
	check(b.global_position.x > 25.0 * TILE, "А на синей — Б прошёл дверь 1 (%s)" % b.global_position)
	# Ложный путь: один на фиолетовой — мало (порог 2).
	await _walk_to(a, KEYS_1, 37.3 * TILE)
	await frames(30)
	check(not purple.active, "один на фиолетовой — защёлка не взята")
	await _walk_to(b, KEYS_2, 36.6 * TILE)
	await frames(30)
	check(purple.active, "оба на фиолетовой — защёлка взята")
	check(not is_open.call(3), "выход закрыт: нужна ещё оранжевая")
	# Б — в комнату 2; А на синюю — Б в комнату 1 на зелёную. А возвращается к старту, на оранжевую.
	await _walk_to(b, KEYS_2, 27.0 * TILE)
	await _walk_to(a, KEYS_1, 34.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 20.0 * TILE)
	await _walk_to(a, KEYS_1, 26.5 * TILE)
	await _walk_to(b, KEYS_2, 17.5 * TILE)
	await frames(30)
	await _walk_to(a, KEYS_1, 19.5 * TILE)
	await _hop_to(a, 15.5 * TILE)
	await _walk_to(a, KEYS_1, 4.0 * TILE)
	await frames(40)
	check(a.global_position.x < 6.0 * TILE, "А вернулся к старту (%s)" % a.global_position)
	check(is_open.call(3), "оранжевая и фиолетовая — выход открыт")
	# Б сходит с зелёной и идёт за ящиком в финишную комнату; везёт его на оранжевую.
	await _walk_to(b, KEYS_2, 42.0 * TILE)
	check(b.global_position.x > 41.0 * TILE, "Б в финишной комнате (%s)" % b.global_position)
	await _hop_to(b, 46.0 * TILE)
	await _push_crate(b, crate, 8.0 * TILE)
	check(crate.global_position.x < 12.0 * TILE, "ящик привезён к старту (%s)" % crate.global_position)
	await _walk_to(a, KEYS_1, 1.5 * TILE)
	await _push_crate(b, crate, 4.0 * TILE)
	await frames(40)
	check(is_open.call(0) and is_open.call(3), "ящик на оранжевой — путь открыт")
	await _walk_to(b, KEYS_2, 45.0 * TILE)
	await _hop_to(a, 6.0 * TILE)
	await _both_to_finish()


## 06 «Эстафета». Два коридора: А наверху, Б внизу. Кнопка одного коридора на миг (0,2–0,6 с)
## открывает ворота другого; перед воротами — препятствие, пройти его надо ровно в окно. Десять
## передач: яма в ворота, вертикальная пила, лента назад, пресс, пила навстречу, две пилы со
## сдвигом, площадка между ямами, широкий пресс, лента вперёд к яме, быстрая пила.
## Выход — две красные кнопки в одно окно 0,3 с.
func _level_06() -> void:
	var level: GreyboxLevel = game.level
	var saw: Saw = level.get_node("SawU")
	var press_u: Node = level.get_node("PressU")
	var exit: Door = level.get_node("Exit")
	# А — по ступеням наверх.
	await _walk_to(a, KEYS_1, 2.6 * TILE)
	await _hop_to(a, 1.75 * TILE)
	await _hop_to(a, 3.85 * TILE)
	await _hop_to(a, 6.0 * TILE)
	check(a.is_on_floor() and a.global_position.y < 7 * TILE, "А в верхнем коридоре (%s)" % a.global_position)
	await _walk_to(a, KEYS_1, 7.3 * TILE)
	await _walk_to(b, KEYS_2, 6.0 * TILE)
	# Ложный путь: Б прыгает через яму, не дождавшись кнопки, — ворота закрыты, падает на шипы.
	var before := deaths
	await _jump_gate(b, KEYS_2, 9.4)
	await _dies(b)
	check(deaths > before, "ворота закрыты — прыжок в яму с шипами (гибель)")
	await _respawned()
	await frames(60)
	place(a, Vector2(7.6 * TILE, _stand_y(7)))  # подъём наверх уже проверен
	place(b, Vector2(6.0 * TILE, _stand_y(12)))
	await frames(20)
	# Нажатия — середины окон из замера tests/tuning/t06_windows: кадр относительно старта бегущего.
	before = deaths
	var w := T06_PRESS
	# 1. Б разбегается и прыгает через яму в ворота; А встаёт на оранжевую.
	await _relay(a, KEYS_1, 8.5, w[0], func() -> void: await _jump_gate(b, KEYS_2, 9.4))
	check(deaths == before and b.global_position.x > 12.5 * TILE, "1: Б прыгнул в открывшиеся ворота (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 13.0 * TILE)
	place(a, Vector2(9.2 * TILE, _stand_y(7)))
	# 2. А — под вертикальной пилой в ворота: бежит, когда пила внизу пошла вверх; Б жмёт синюю.
	await _relay(b, KEYS_2, 14.0, w[1], func() -> void: await _run_plain(a, KEYS_1, 15.6),
			func() -> bool: return saw.progress > 0.9 and saw.progress < 0.95 and not saw.forward, _saw_period(saw))
	check(deaths == before and a.global_position.x > 15.5 * TILE, "2: А проскочил пилу и ворота (%s)" % a.global_position)
	await _walk_to(a, KEYS_1, 16.6 * TILE)
	var world1 := level.has_node("SawOverPit")  # мир 1: вместо лент — пилы
	if world1:
		# 3. Б — прыжок через яму под пилой (ходит над ямой) прямо в ворота; А жмёт зелёную.
		var saw_pit: Saw = level.get_node("SawOverPit")
		await _walk_to(b, KEYS_2, 15.7 * TILE)
		await _settle(b, 16.0, 12)
		await _relay(a, KEYS_1, 17.5, T06_W1_PRESS[0], func() -> void: await _jump_gate(b, KEYS_2, 16.35),
				func() -> bool: return saw_pit.forward and saw_pit.progress >= 0.5 and saw_pit.progress < 0.55, _saw_period(saw_pit))
		check(deaths == before and b.global_position.x > 19.9 * TILE, "3: Б проскочил под пилой над ямой в ворота (%s)" % b.global_position)
	else:
		await _walk_to(b, KEYS_2, 14.3 * TILE)
		await _settle(b, 14.3, 12)
		# 3. Б — через ленту прыжками; А жмёт зелёную.
		await _relay(a, KEYS_1, 17.5, w[2], func() -> void: await _belt_hops(b, KEYS_2))
		check(deaths == before and b.global_position.x > 22.3 * TILE, "3: Б пропрыгал ленту и прошёл ворота (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 22.7 * TILE)
	await _walk_to(a, KEYS_1, 22.0 * TILE)
	await _settle(a, 22.0, 7)
	# 4. А — под прессом в ворота: бежит, когда пресс поднимается выше головы; Б жмёт фиолетовую.
	await _relay(b, KEYS_2, 23.6, w[3], func() -> void: await _run_plain(a, KEYS_1, 26.9),
			func() -> bool: return press_u.get("_state") == 3 and press_u.position.y < 120.0 and press_u.position.y > 100.0, _press_period(press_u))
	check(deaths == before and a.global_position.x > 26.5 * TILE, "4: А проскочил под прессом в ворота (%s)" % a.global_position)
	# 5. Б — через пилу на полу, едущую навстречу; А жмёт жёлтую.
	var saw_l: Saw = level.get_node("SawL")
	await _walk_to(a, KEYS_1, 27.5 * TILE)  # левее — закрытые ворота: упрётся
	await _walk_to(b, KEYS_2, 26.1 * TILE)  # с разгона проскакивает ≈ 0,3 — у 26,8 пила в крайнем левом
	await _settle(b, 26.6, 12)
	await _relay(a, KEYS_1, 28.0, w[4], func() -> void: await _run_dodging(b, KEYS_2, 31.8, 30.2),
			func() -> bool: return not saw_l.forward and saw_l.progress > 0.8 and saw_l.progress < 0.85, _saw_period(saw_l))
	check(deaths == before and b.global_position.x > 31.6 * TILE, "5: Б проскочил пилу и ворота (%s)" % b.global_position)
	# 6. А — под двумя вертикальными пилами; Б жмёт бирюзовую.
	var saw_u2: Saw = level.get_node("SawU2")
	await _walk_to(a, KEYS_1, 28.6 * TILE)  # с разгона проскакивает ≈ 0,4 — дальше пила
	await _walk_to(b, KEYS_2, 32.5 * TILE)  # левее — закрытые ворота: упрётся
	await _settle(a, 29.1, 7)
	await _relay(b, KEYS_2, 33.0, w[5], func() -> void: await _run_plain(a, KEYS_1, 34.0),
			func() -> bool: return saw_u2.progress < 0.55 and saw_u2.progress > 0.5 and not saw_u2.forward, _saw_period(saw_u2))
	check(deaths == before and a.global_position.x > 33.9 * TILE, "6: А проскочил две пилы и ворота (%s)" % a.global_position)
	# 7. Б — на площадку в тайл между ямами и с неё в ворота; А жмёт розовую.
	await _walk_to(a, KEYS_1, 34.1 * TILE)
	await _walk_to(b, KEYS_2, 33.9 * TILE)
	await _hop_exact(b, 36.7 * TILE)
	check(b.alive and b.is_on_floor(), "7: Б на площадке между ямами (%s)" % b.global_position)
	await _settle(b, 36.7, 12)
	await _relay(a, KEYS_1, 35.0, w[6], func() -> void: await _jump_gate(b, KEYS_2, 36.7))
	check(deaths == before and b.global_position.x > 40.0 * TILE, "7: Б прыгнул с площадки в ворота (%s)" % b.global_position)
	# 8. А — под широким прессом; Б жмёт белую.
	var press_u2: Node = level.get_node("PressU2")
	await _walk_to(a, KEYS_1, 35.4 * TILE)  # с бега проскакивает ≈ 0,3 тайла — под пресс нельзя
	await _walk_to(b, KEYS_2, 41.2 * TILE)  # левее — закрытые ворота: упрётся
	await _settle(a, 35.9, 7)
	await _relay(b, KEYS_2, 41.0, w[7], func() -> void: await _run_plain(a, KEYS_1, 41.4),
			func() -> bool: return press_u2.get("_state") == 3 and press_u2.position.y < 132.0 and press_u2.position.y > 112.0, _press_period(press_u2))
	check(deaths == before and a.global_position.x > 41.3 * TILE, "8: А проскочил под прессом в ворота (%s)" % a.global_position)
	# 9. Б — лента вперёд и прыжок через яму у края в ворота; А жмёт салатовую.
	await _walk_to(a, KEYS_1, 41.95 * TILE)  # левее — закрытые ворота: упрётся
	if world1:
		# 9. Б — через пилу навстречу и сразу яму у ворот; А жмёт салатовую.
		var saw_l2: Saw = level.get_node("SawL2")
		await _walk_to(b, KEYS_2, 41.8 * TILE)
		await _settle(b, 42.0, 12)
		await _relay(a, KEYS_1, 42.9, T06_W1_PRESS[1], func() -> void: await _run_dodging(b, KEYS_2, 49.1, 46.75),
				func() -> bool: return not saw_l2.forward and saw_l2.progress > 0.8 and saw_l2.progress < 0.85, _saw_period(saw_l2))
		check(deaths == before and b.global_position.x > 49.0 * TILE, "9: Б перепрыгнул пилу и яму в ворота (%s)" % b.global_position)
	else:
		await _walk_to(b, KEYS_2, 41.4 * TILE)
		await _settle(b, 41.6, 12)  # левее — на скате ленты её уже тащит
		await _relay(a, KEYS_1, 42.9, w[8], func() -> void: await _jump_gate(b, KEYS_2, 46.1))
		check(deaths == before and b.global_position.x > 49.0 * TILE, "9: Б перепрыгнул яму с ленты в ворота (%s)" % b.global_position)
	# 10. А — через пилу на полу навстречу; Б жмёт коричневую.
	var saw_u4: Saw = level.get_node("SawU4")
	await _walk_to(a, KEYS_1, 43.1 * TILE)
	await _walk_to(b, KEYS_2, 49.4 * TILE)  # левее — закрытые ворота: упрётся
	await _settle(a, 43.1, 7)
	await _relay(b, KEYS_2, 49.6, w[9], func() -> void: await _run_dodging(a, KEYS_1, 48.9),
			func() -> bool: return not saw_u4.forward and saw_u4.progress > 0.8 and saw_u4.progress < 0.85, _saw_period(saw_u4))
	check(deaths == before and a.global_position.x > 48.8 * TILE, "10: А проскочил пилу и ворота (%s)" % a.global_position)
	# Выход: обе красные в одно окно.
	await _walk_to(a, KEYS_1, 50.6 * TILE)
	await _walk_to(b, KEYS_2, 50.6 * TILE)
	await _walk_to(b, KEYS_2, 52.0 * TILE)
	await frames(60)
	await _walk_to(b, KEYS_2, 50.6 * TILE)
	check(not exit.get("_latched"), "одна красная — выход закрыт")
	await frames(60)
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 30:
		await get_tree().physics_frame
		press(KEYS_1[RIGHT], a.global_position.x < 52.0 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 52.0 * TILE)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(90)
	check(exit.get("_latched"), "обе красные в окно — выход открыт насовсем")
	await _walk_to(a, KEYS_1, 56.0 * TILE)
	await frames(40)
	await _both_to_finish()


## 07 «Обвал». Стена с шипами ползёт слева, чекпоинтов нет. Стена 3,5: катапульта с замершего
## и вытягивание за руку; дверь с плитой и пилой (обратная плита за дверью); пропасть: А замирает
## в прыжке ступенькой у дальнего края, Б по нему перепрыгивает и вытягивает А за руку;
## выход — две кнопки (одна на уступе) в одно окно.
func _level_07() -> void:
	var level: GreyboxLevel = game.level
	var crusher: Crusher = level.get_node("Crusher")
	var exit: Door = level.get_node("Exit")
	var t0 := Time.get_ticks_msec()
	var lag := func() -> String:
		return "обвал в %.1f тайла от отставшего" % ((minf(a.global_position.x, b.global_position.x) - crusher.global_position.x) / TILE)
	# 1. Стена: Б замирает у стены, А встаёт на него, катапульта; А вытягивает Б.
	await _walk_to(b, KEYS_2, 8.3 * TILE)
	await _walk_to(a, KEYS_1, 7.2 * TILE)
	check(crusher.active, "обвал тронулся, когда команда пошла")
	tap(KEYS_2[FREEZE])
	await frames(3)
	await _hop_exact(a, 8.3 * TILE)
	check(a.standing_on() == b, "А на замершем Б (%s)" % a.global_position)
	await _catapult(b, KEYS_2, a, KEYS_1, RIGHT)
	check(a.is_on_floor() and a.global_position.y < 8.5 * TILE, "катапульта: А на стене (%s)" % a.global_position)
	tap(KEYS_2[FREEZE])
	await frames(10)
	await _walk_to(a, KEYS_1, 9.35 * TILE)
	press(KEYS_1[LEFT], true)
	await frames(2)
	press(KEYS_1[LEFT], false)
	await _catch_and_pull(a, KEYS_1, b, KEYS_2, 8.5)
	check(b.global_position.y < 8.5 * TILE, "А вытянул Б на стену (%s); %s" % [b.global_position, lag.call()])
	# 2. Дверь: А на плите, Б через пилу в дверь, на обратную плиту; А — через пилу в дверь.
	var saw: Saw = level.get_node("Saw")
	await _walk_to(b, KEYS_2, 16.0 * TILE)
	await _walk_to(a, KEYS_1, 15.0 * TILE)
	await _wait_saw_coming(saw)
	await _run_dodging(b, KEYS_2, 23.5)
	await _wait_saw_coming(saw)
	await _run_dodging(a, KEYS_1, 22.3)
	check(a.global_position.x > 22.0 * TILE and b.global_position.x > 22.0 * TILE, "оба за дверью (%s)" % lag.call())
	# 3. Пропасть: Б замирает в прыжке у дальнего края, А перепрыгивает по нему и вытягивает Б.
	await _walk_to(b, KEYS_2, 24.6 * TILE)
	var ok := await _step_in_air(b, KEYS_2, a, KEYS_1, 26.0, 29.55, 30.6)
	check(ok, "А перепрыгнул пропасть по замершему Б (a %s b %s)" % [a.global_position, b.global_position])
	await _walk_to(a, KEYS_1, 30.75 * TILE)
	press(KEYS_1[LEFT], true)
	await frames(2)
	press(KEYS_1[LEFT], false)
	press(KEYS_1[GRAB], true)
	await frames(4)
	check(a.grab_target == b, "А держит замершего Б за руку (a %s b %s)" % [a.global_position, b.global_position])
	tap(KEYS_2[FREEZE])
	await frames(6)
	press(KEYS_1[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		var feet := b.global_position.y + Player.SIZE.y / 2.0
		press(KEYS_1[RIGHT], feet > 12.0 * TILE - 4.0)
		if b.is_on_floor() and b.global_position.y < 12.0 * TILE:
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_1[GRAB], false)
	await frames(10)
	check(b.alive and b.global_position.x > 30.6 * TILE and b.global_position.y < 12 * TILE, "А вытянул Б из пропасти (%s); %s" % [b.global_position, lag.call()])
	var world1 := level.has_node("PlateTwo")  # мир 1: без механизмов мастерских
	if world1:
		# 4. Плита на двоих: Б уходит вперёд (через ящик), А задвигает ящик на плиту и встаёт
		# на него — дверь открыта; Б за дверью жмёт защёлку; А проходит.
		var crate1: Crate = level.get_node("Crate1")
		var plate_two: PressurePlate = level.get_node("PlateTwo")
		await _walk_to(b, KEYS_2, 35.6 * TILE)
		await _hop_to(b, 39.2 * TILE)
		await _walk_to(b, KEYS_2, 42.4 * TILE)
		await _walk_to(a, KEYS_1, 35.6 * TILE)
		await _push_crate(a, crate1, 38.0 * TILE)
		await _hop_exact(a, crate1.global_position.x)
		await frames(10)
		check(plate_two.active, "ящик на плите и А на ящике — вес 2 (%s)" % a.global_position)
		await _walk_to(b, KEYS_2, 45.2 * TILE)
		await frames(15)
		check(b.global_position.x > 44.4 * TILE, "Б прошёл дверь и нажал защёлку (%s)" % b.global_position)
		await _walk_to(b, KEYS_2, 46.9 * TILE)  # дальше — пила (левый край рельса 47.8)
		await _walk_to(a, KEYS_1, 45.9 * TILE)
		check(a.global_position.x > 44.4 * TILE, "защёлка держит дверь — А прошёл (%s); %s" % [a.global_position, lag.call()])
		# 5. Две пилы по полу — перепрыгнуть на бегу, когда едут навстречу.
		var saw_run: Saw = level.get_node("SawRun1")
		await _wait_saw_coming(saw_run)
		await _run_dodging(b, KEYS_2, 57.6)
		await _wait_saw_coming(saw_run)
		await _run_dodging(a, KEYS_1, 57.0)
		check(a.alive and b.alive and a.global_position.x > 56.8 * TILE, "пилы перепрыгнуты (%s)" % lag.call())
	else:
		# 4. Ветер: Б прыгает с края, А в этот миг вскакивает на ближнюю педаль; затем наоборот —
		# А прыгает, Б на дальней педали. Педали далеко от края: в одиночку порыв кончится до прыжка.
		await _walk_to(a, KEYS_1, 30.9 * TILE)
		await _walk_to(b, KEYS_2, 35.6 * TILE)
		await _gust_jump(b, KEYS_2, 37.0, a, KEYS_1, 31.8)
		check(b.alive and b.global_position.x > 44.0 * TILE, "порыв перенёс Б через пропасть (%s)" % b.global_position)
		await _walk_to(b, KEYS_2, 45.6 * TILE)
		await _walk_to(a, KEYS_1, 35.6 * TILE)
		await _gust_jump(a, KEYS_1, 37.0, b, KEYS_2, 46.5)
		check(a.alive and a.global_position.x > 44.0 * TILE, "порыв перенёс А через пропасть (%s); %s" % [a.global_position, lag.call()])
		# 5. Ломкий настил держит одного: по очереди.
		await _walk_to(b, KEYS_2, 58.3 * TILE)
		await _walk_to(a, KEYS_1, 57.4 * TILE)
		check(not level.get_node("Bridge").broken and a.global_position.x > 57.0 * TILE, "настил перешли по одному (%s)" % lag.call())
	# 6. Прессы волной: перебежки между колоннами (под колонной пресса нет, но место — на одного).
	await _walk_to(b, KEYS_2, 58.95 * TILE)  # с разгона проскакивает ≈ 0,4 тайла
	await _walk_to(a, KEYS_1, 58.45 * TILE)
	# Волна: стартовали, когда первый пресс только что поднялся выше головы, — бегут насквозь.
	var p1: Node = level.get_node("Press1")
	for i in 400:
		if p1.get("_state") == 3 and p1.position.y > 470.0 and p1.position.y < 505.0:
			break
		await get_tree().physics_frame
	press(KEYS_2[RIGHT], true)
	await frames(2)
	press(KEYS_1[RIGHT], true)
	for i in 200:
		await get_tree().physics_frame
		press(KEYS_2[RIGHT], b.global_position.x < 73.2 * TILE)
		press(KEYS_1[RIGHT], a.global_position.x < 72.3 * TILE)
		if not a.alive or not b.alive or (a.global_position.x >= 72.3 * TILE and b.global_position.x >= 73.2 * TILE):
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(10)
	check(a.alive and b.alive and a.global_position.x > 71.0 * TILE, "прессы пройдены (%s)" % lag.call())
	if world1:
		# 7. Ящик к стене 4,5: Б задвигает ящик к стене, встаёт на него и замирает; А на Б —
		# катапульта на стену; А вытягивает Б с ящика.
		var crate2: Crate = level.get_node("Crate2")
		await _push_crate(b, crate2, 74.45 * TILE)
		await _hop_exact(b, crate2.global_position.x)
		tap(KEYS_2[FREEZE])
		await frames(3)
		await _walk_to(a, KEYS_1, 72.8 * TILE)
		await _hop_exact(a, crate2.global_position.x)
		check(a.standing_on() == b and b.frozen, "А на замершем Б на ящике у стены (%s)" % a.global_position)
		await _catapult(b, KEYS_2, a, KEYS_1, RIGHT)
		check(a.is_on_floor() and a.global_position.y < 7.5 * TILE, "катапульта: А на стене (%s)" % a.global_position)
		tap(KEYS_2[FREEZE])
		await frames(10)
		await _walk_to(a, KEYS_1, 75.35 * TILE)
		press(KEYS_1[LEFT], true)
		await frames(2)
		press(KEYS_1[LEFT], false)
		await _catch_and_pull(a, KEYS_1, b, KEYS_2, 7.5)
		check(a.global_position.y < 7.5 * TILE and b.global_position.y < 7.5 * TILE, "оба на стене (a %s b %s); %s" % [a.global_position, b.global_position, lag.call()])
	else:
		await _walk_to(b, KEYS_2, 74.0 * TILE)
		await _walk_to(a, KEYS_1, 72.6 * TILE)
		# 7. Взведённая пружина: Б замер на батуте, А встал на него, Б ожил — выстрел на скалу.
		tap(KEYS_2[FREEZE])
		await frames(3)
		await _hop_exact(a, 74.0 * TILE)
		check(a.standing_on() == b, "А на замершем Б на батуте (%s)" % a.global_position)
		press(KEYS_1[RIGHT], true)
		press(KEYS_2[RIGHT], true)
		tap(KEYS_2[FREEZE])
		for i in 90:
			await get_tree().physics_frame
			if i > 10 and a.is_on_floor() and b.is_on_floor():
				break
		press(KEYS_1[RIGHT], false)
		press(KEYS_2[RIGHT], false)
		check(a.global_position.y < 5.5 * TILE and b.global_position.y < 5.5 * TILE, "выстрел пружины: оба на скале (a %s b %s); %s" % [a.global_position, b.global_position, lag.call()])
	# 8. Выход: А на кнопку на полу, Б на кнопку на уступе — в одно окно.
	var ahead := a if a.global_position.x > b.global_position.x else b
	var behind := b if ahead == a else a
	await _walk_to(ahead, _keys(ahead), 89.9 * TILE)
	await _walk_to(behind, _keys(behind), 88.1 * TILE)
	await frames(5)
	_run_jump_to(ahead, _keys(ahead), 90.3, 93.0)  # не ждём: второй вскакивает на свою кнопку, как только первый приземлился
	for i in 90:
		await get_tree().physics_frame
		if ahead.is_on_floor() and ahead.global_position.y < 10.0 * TILE:
			break
	await _step_on_at(behind, _keys(behind), 89.0, 0)
	await frames(30)
	check(exit.get("_latched"), "обе красные в окно — выход открыт (%s)" % lag.call())
	await _both_to_finish()
	print("    время прохода %.1f с" % ((Time.get_ticks_msec() - t0) / 1000.0))


## Ступенька в воздухе без подхода телепортом: p с разбега прыгает у края edge (тайлы) и замирает,
## долетев до freeze_x; q с разбега прыгает у края, встаёт на p и прыгает на берег за far.
func _step_in_air(p: Player, kp: Array[Key], q: Player, kq: Array[Key], edge: float, freeze_x: float, far: float) -> bool:
	press(kp[RIGHT], true)
	var hold_jump := 0
	for i in 120:
		await get_tree().physics_frame
		if p.is_on_floor() and p.global_position.x >= (edge - 0.25) * TILE:
			hold_jump = 18
		press(kp[JUMP], hold_jump > 0)
		hold_jump = maxi(hold_jump - 1, 0)
		if p.global_position.x >= freeze_x * TILE:
			break
	tap(kp[FREEZE])
	press(kp[RIGHT], false)
	press(kp[JUMP], false)
	await frames(2)
	print("    А замер в воздухе в %s" % p.global_position)
	press(kq[RIGHT], true)
	hold_jump = 0
	var landed := false
	for i in 150:
		await get_tree().physics_frame
		if q.is_on_floor() and q.global_position.x >= (edge - 0.25) * TILE and q.global_position.x < edge * TILE:
			hold_jump = 18
		press(kq[JUMP], hold_jump > 0)
		hold_jump = maxi(hold_jump - 1, 0)
		if q.global_position.x > edge * TILE:
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
	press(kq[RIGHT], true)
	press(kq[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		if i > 5 and q.is_on_floor():
			break
	press(kq[JUMP], false)
	press(kq[RIGHT], false)
	await frames(5)
	return q.alive and q.is_on_floor() and q.global_position.x > far * TILE


## top у края держит хват; low прыгает, top ловит его за руку и отходит вправо, пока low
## не встанет наверху (верх — top_row, тайлы), — не дальше.
func _catch_and_pull(top: Player, kt: Array[Key], low: Player, kl: Array[Key], top_row: float) -> void:
	press(kt[GRAB], true)
	await frames(3)
	press(kl[JUMP], true)
	await frames(22)
	press(kl[JUMP], false)
	check(top.grab_target == low, "%s поймал %s за руку" % [top.name, low.name])
	# Отходит, пока ноги вытягиваемого не поднимутся над краем; дальше стоит и держит —
	# рука не даёт улететь, вытянутый встаёт рядом.
	press(kt[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		var feet := low.global_position.y + Player.SIZE.y / 2.0
		press(kt[RIGHT], feet > top_row * TILE - 4.0)
		if low.is_on_floor() and low.global_position.y < top_row * TILE:
			break
	press(kt[RIGHT], false)
	press(kt[GRAB], false)
	# Вытянутого несёт по инерции: тормозит, пока не встанет.
	for i in 40:
		press(kl[LEFT], low.velocity.x > 20.0)
		await get_tree().physics_frame
		if low.is_on_floor() and absf(low.velocity.x) < 20.0:
			break
	press(kl[LEFT], false)
	await frames(5)


## p разбегается и прыгает у края edge (тайлы); presser в миг отрыва вскакивает на педаль
## pedal_x (стоит в 0,9 тайла левее неё). Порыв несёт p, пока тот в воздухе.
func _gust_jump(p: Player, k: Array[Key], edge: float, presser: Player, kp: Array[Key], pedal_x: float) -> void:
	press(k[RIGHT], true)
	var hold_jump := 0
	var stepped := false
	for i in 200:
		await get_tree().physics_frame
		if p.is_on_floor() and p.global_position.x >= (edge - 0.25) * TILE and hold_jump == 0 and not stepped:
			hold_jump = 18
		press(k[JUMP], hold_jump > 0)
		hold_jump = maxi(hold_jump - 1, 0)
		if not stepped and not p.is_on_floor() and p.global_position.x >= (edge - 0.3) * TILE:
			stepped = true
			_step_on_at(presser, kp, pedal_x, 0)
		if stepped and p.is_on_floor() or not p.alive:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## Перебежка под прессом к безопасному месту spot (тайлы, под колонной): ждёт, пока пресс
## только что поднялся выше головы, и бежит.
func _dash_under(p: Player, k: Array[Key], press_node: Node, spot: float) -> void:
	for i in 400:
		var y: float = press_node.position.y
		if press_node.get("_state") == 3 and y > 440.0 and y < 500.0:
			break
		await get_tree().physics_frame
	press(k[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		if p.global_position.x >= (spot - 0.38) * TILE or not p.alive:  # с бега проскакивает ≈ 0,4 тайла
			break
	press(k[RIGHT], false)
	await frames(12)


## Разбег, прыжок у take_off и посадка точно на land (тайлы): в воздухе тормозит у цели.
func _run_jump_to(p: Player, k: Array[Key], take_off: float, land: float) -> void:
	press(k[RIGHT], true)
	for i in 60:
		await get_tree().physics_frame
		if p.global_position.x >= take_off * TILE:
			break
	press(k[RIGHT], false)
	await _hop_exact(p, land * TILE)


## Ждёт, пока пила на рельсе не поедет навстречу (влево) от правого конца.
func _wait_saw_coming(saw: Saw) -> void:
	for i in 300:
		if not saw.forward and saw.progress > 0.8:
			break
		await get_tree().physics_frame


## Бег вправо до x (тайлы) с прыжками через пилы на полу (едут навстречу); у jump_at (тайлы)
## прыжок — в ворота, которые могут уже подниматься.
func _run_dodging(p: Player, k: Array[Key], x: float, jump_at := INF) -> void:
	press(k[RIGHT], true)
	var hold_jump := 0
	var gate_jump := false
	for i in 300:
		await get_tree().physics_frame
		var jump := hold_jump > 0
		hold_jump = maxi(hold_jump - 1, 0)
		if not gate_jump and p.is_on_floor() and p.global_position.x >= jump_at * TILE:
			jump = true
			hold_jump = 18
			gate_jump = true
		for s: Saw in game.level.find_children("*", "Saw", true, false):
			if s.path_tiles.x == 0.0:
				continue  # вертикальные пилы не перепрыгивают
			var dx: float = s.global_position.x + s.path_tiles.x * TILE * s.progress - p.global_position.x
			var closing: float = p.velocity.x - s.speed * (1.0 if s.forward else -1.0)
			if dx > 0.0 and closing > 50.0 and (dx - 48.0) / closing < 0.22 and p.is_on_floor():
				jump = true
				hold_jump = 18
		press(k[JUMP], jump)
		if p.global_position.x >= x * TILE or not p.alive:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## Подход сокращён: бегущий встаёт точно на точку старта из замера окон (с бега он проскакивает
## ≈ 0,3 тайла, а окна тесные).
func _settle(p: Player, x: float, row: float) -> void:
	place(p, Vector2(x * TILE, _stand_y(row)))
	await frames(10)


## Передача в «Эстафете»: нажимающий встаёт на кнопку в button_x на кадре offset относительно
## старта бегущего (отрицательный — раньше старта). Если у препятствия есть фаза (ready, period),
## бегущий трогается в ней: дождаться условия и переждать период минус упреждение.
func _relay(presser: Player, kp: Array[Key], button_x: float, offset: int, run: Callable,
		ready := Callable(), period := 0.0, side := 0) -> void:
	# Сразу за воротами до кнопки полтайла — там не встать: ждут справа от кнопки.
	if side == 0:
		side = 1 if button_x in [23.6, 28.0, 33.0, 41.0, 49.6] else -1
	const LEAD := 60
	if ready.is_valid():
		for i in 600:
			if ready.call():
				break
			await get_tree().physics_frame
		await frames(roundi(period * 60.0) - LEAD)
	_step_on_at(presser, kp, button_x, LEAD + offset, side)
	await frames(LEAD)
	await run.call()
	if game.level.has_node("Crusher"):
		var crusher: Crusher = game.level.get_node("Crusher")
		print("      обвал в %.1f тайла от отставшего" % ((minf(a.global_position.x, b.global_position.x) - crusher.global_position.x) / TILE))


func _saw_period(saw: Saw) -> float:
	return 2.0 * saw.path_tiles.length() * TILE / saw.speed


func _press_period(p: Node) -> float:
	var travel: float = p.drop_tiles * TILE
	return travel / p.fall_speed + p.bottom_wait + travel / p.rise_speed + p.top_wait


## Через frame кадров p (стоит в 0,9 тайла от кнопки — справа, если side > 0) шагает на кнопку
## в button_x и встаёт. Не ждут: идёт параллельно с действиями бегущего.
func _step_on_at(p: Player, k: Array[Key], button_x: float, frame: int, side := -1) -> void:
	place(p, Vector2((button_x + 0.9 * side) * TILE, p.global_position.y))
	await frames(frame)
	var key := k[LEFT] if side > 0 else k[RIGHT]
	press(key, true)
	for i in 30:
		await get_tree().physics_frame
		if (p.global_position.x - button_x * TILE) * side <= 6.0:
			break
	press(key, false)


## Бег вправо до x (в тайлах) без прыжков.
func _run_plain(p: Player, k: Array[Key], x: float) -> void:
	press(k[RIGHT], true)
	for i in 240:
		await get_tree().physics_frame
		if p.global_position.x >= x * TILE or not p.alive:
			break
	press(k[RIGHT], false)
	await frames(10)


## Разбег и прыжок через яму в ворота: p прыгает у края edge_x (в тайлах) и летит до приземления.
func _jump_gate(p: Player, k: Array[Key], edge_x: float) -> void:
	press(k[RIGHT], true)
	var jumped := false
	var airborne := false
	for i in 150:
		await get_tree().physics_frame
		if not jumped and p.global_position.x >= edge_x * TILE:
			press(k[JUMP], true)
			jumped = true
		if jumped and not p.is_on_floor():
			airborne = true
		if (airborne and p.is_on_floor()) or not p.alive:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## Лента быстрее бега: p прыгает через яму на ленту и с ленты сразу прыгает ещё раз — в ворота.
func _belt_hops(p: Player, k: Array[Key]) -> void:
	press(k[RIGHT], true)
	var jumps := 0
	var hold_jump := 0
	for i in 240:
		await get_tree().physics_frame
		var ready := p.is_on_floor() and hold_jump == 0
		if ready and (jumps == 0 and p.global_position.x >= 14.5 * TILE or jumps > 0 and p.global_position.x > 15.7 * TILE):
			jumps += 1
			hold_jump = 18  # полный прыжок: кнопку держим
		press(k[JUMP], hold_jump > 0)
		hold_jump = maxi(hold_jump - 1, 0)
		if p.global_position.x > 22.3 * TILE or not p.alive:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## Прыжок с зажатым хватом на крюк над головой.
func _hang_on(p: Player, k: Array[Key], hook: Hook) -> void:
	press(k[GRAB], false)
	await frames(2)
	press(k[GRAB], true)
	press(k[JUMP], true)
	for i in 40:
		await get_tree().physics_frame
		if p.grab_target == hook:
			break
	press(k[JUMP], false)
	check(p.grab_target == hook, "%s на крюке" % p.name)


func _wait_hook_end(hook: Hook) -> void:
	for i in 600:
		if hook.velocity.x == 0.0 and hook.global_position.x > 13.0 * TILE:
			break
		await get_tree().physics_frame
	await frames(20)


## Одновременный проход: presser идёт на кнопку в button_x, runner в тот же миг бежит до run_x.
func _sync_pass(presser: Player, kp: Array[Key], button_x: float, runner: Player, kr: Array[Key], run_x: float) -> void:
	press(kp[RIGHT], true)
	press(kr[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		press(kp[RIGHT], presser.global_position.x < button_x * TILE)
		if runner.global_position.x >= run_x * TILE:
			break
	press(kp[RIGHT], false)
	press(kr[RIGHT], false)
	await frames(10)
	check(runner.global_position.x >= run_x * TILE - 8.0, "%s прошёл, пока %s на кнопке (%s)" % [runner.name, presser.name, runner.global_position])
