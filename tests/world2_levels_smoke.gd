extends LevelBot
## Автопроверка уровней мира 2 «Мастерские»: пара проходит каждый задуманным путём от старта
## до двери и проверяет ложные пути — что без главной догадки не пройти.
## Запуск: Godot_console --headless --fixed-fps 60 --path . res://tests/world2_levels_smoke.tscn [-- 01]

const LEVELS := {
	"01": preload("res://levels/w02_l01_belt.tscn"),
	"02": preload("res://levels/w02_l02_spring.tscn"),
	"03": preload("res://levels/w02_l03_charged.tscn"),
	"04": preload("res://levels/w02_l04_brittle.tscn"),
	"05": preload("res://levels/w02_l05_turn.tscn"),
	"06": preload("res://levels/w02_l06_bellows.tscn"),
	"07": preload("res://levels/w02_l07_crane.tscn"),
	"08": preload("res://levels/w02_l08_presses.tscn"),
	"09": preload("res://levels/w02_l09_sawmill.tscn"),
	"10": preload("res://levels/w02_l10_workshop.tscn"),
	"11": preload("res://levels/w02_l11_beetle.tscn"),
	"12": preload("res://levels/w02_l12_beetle_plate.tscn"),
	"13": preload("res://levels/w02_l13_spark.tscn"),
	"14": preload("res://levels/w02_l14_switch.tscn"),
	"15": preload("res://levels/w02_l15_fuse.tscn"),
	"16": preload("res://levels/w02_l16_wind_crate.tscn"),
	"17": preload("res://levels/w02_l17_ghost.tscn"),
	"18": preload("res://levels/w02_l18_two_beetles.tscn"),
	"19": preload("res://levels/w02_l19_spark_springs.tscn"),
}

var deaths := 0
var camera: SharedCamera


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	for arg in only.duplicate():
		if arg.begins_with("human="):
			human = true
			rng.seed = int(arg.get_slice("=", 1))
			only.erase(arg)
			print("человеческий режим, зерно %d" % rng.seed)
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


## Уровни набора: id → сцена. Наследник (тест перестроенного мира 2) подставляет свои.
func _catalog() -> Dictionary:
	return LEVELS


## Какой бот проходит уровень id.
func _method(id: String) -> String:
	return "_level_" + id


# --- Уровни ---------------------------------------------------------------------------------

## 01 «Лента». Пропасть в 5 тайлов перепрыгивают только с разгона по ленте. Тяжёлый ящик на полке
## не сдвинуть одному — его сбрасывает на плиту лента, которую включает рычаг на полке; на полку —
## живой лестницей.
func _level_01() -> void:
	var level: GreyboxLevel = game.level
	var crate: Crate = level.get_node("HeavyCrate")
	var plate: PressurePlate = level.get_node("Plate")
	var lever: Lever = level.get_node("ShelfLever")
	# Ложный путь: с лентой, остановленной на месте (как обычный пол), пропасть не перепрыгнуть.
	var belt: Conveyor = level.get_node("RideBelt")
	belt.speed = 0.0
	place(a, Vector2(9.0 * TILE, _stand_y(12)))
	await frames(5)
	await _run_jump(a, KEYS_1, 13.0 * TILE)
	check(await _dies(a), "без ленты пропасть не перепрыгнуть")
	belt.speed = 360.0
	await _respawned()
	# С разгона по ленте — перелетают оба (первым — тот, кто правее: иначе упрётся в товарища).
	for p: Player in [b, a]:
		await _run_jump(p, _keys(p), 13.0 * TILE)
		for i in 60:
			if p.is_on_floor() or not p.alive:
				break
			await get_tree().physics_frame
		check(p.alive and p.global_position.x > 18 * TILE, "%s перелетел пропасть с ленты (%.0f)" % [p.name, p.global_position.x])
	# Тяжёлый ящик один не толкает.
	await _walk_to(a, KEYS_1, 21.5 * TILE)
	await _walk_to(b, KEYS_2, 20.5 * TILE)
	# Живая лестница: А замирает у полки, Б прыгает с его головы на полку к рычагу.
	await _walk_to(a, KEYS_1, 22.3 * TILE)
	place(a, Vector2(22.3 * TILE, _stand_y(12)))  # точно у края полки
	await frames(5)
	tap(KEYS_1[FREEZE])
	await frames(3)
	await _onto_head(b, a)
	await _hop_to(b, 23.6 * TILE)
	check(b.is_on_floor() and b.global_position.y < 9 * TILE, "Б на полке (%s)" % b.global_position)
	await hold(KEYS_2[GRAB], 3)
	check(lever.active, "Б включил рычаг — лента на полке пошла")
	for i in 400:
		if plate.active:
			break
		await get_tree().physics_frame
	check(plate.active and Weight.floor_below(crate) == plate, "лента сбросила тяжёлый ящик на плиту")
	tap(KEYS_1[FREEZE])
	await frames(3)
	await _walk_to(b, KEYS_2, 21.0 * TILE)
	await frames(40)
	# Через ящик на плите — прыжком, к двери.
	await _run_to(b, 33.0 * TILE)
	await _run_to(a, 32.0 * TILE)
	await _both_to_finish()
	await frames(30)


## 02 «Пружина». Стена в 3 тайла: прыжком не взять, прыжком на батут — да. Уступ в 5 тайлов над
## батутом на столбе: прыжок с батута его не берёт, падение на батут с высоты — берёт.
func _level_02() -> void:
	# Ложный путь: стену в 3 тайла прыжком с пола не взять.
	await _walk_to(b, KEYS_2, 7.4 * TILE)
	await _jump(b, KEYS_2, RIGHT, 30)
	check(b.global_position.y > 10 * TILE, "стену в 3 тайла прыжком не взять (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 4.0 * TILE)
	for p: Player in [b, a]:
		var k := _keys(p)
		# С разбега на батут и через стену.
		await _walk_to(p, k, 4.6 * TILE)
		press(k[RIGHT], true)
		press(k[JUMP], true)
		for i in 120:
			await get_tree().physics_frame
			if i == 25:
				press(k[JUMP], false)
			if i > 10 and p.is_on_floor() and p.global_position.y < 9 * TILE:
				break
		press(k[RIGHT], false)
		press(k[JUMP], false)
		check(p.global_position.y < 9 * TILE and p.global_position.x > 8 * TILE, "%s с батута на стену (%s)" % [p.name, p.global_position])
		await frames(10)
		# С края стены вниз на батут на столбе — отскок на уступ в 5 тайлов.
		await _walk_to(p, k, 13.0 * TILE)
		press(k[RIGHT], true)
		for i in 150:
			await get_tree().physics_frame
			if not p.alive or (i > 20 and p.is_on_floor() and p.global_position.x > 20 * TILE):
				break
		press(k[RIGHT], false)
		check(p.alive and p.global_position.x > 20 * TILE and p.global_position.y < 9 * TILE, "%s отскочил с батута на столбе на уступ (%s)" % [p.name, p.global_position])
		await frames(20)
	await _walk_to(b, KEYS_2, 25.0 * TILE)
	await _both_to_finish()


## 03 «Взведённая пружина». Стена в 6 тайлов: ни прыжок с батута, ни живая лестница её не берут.
## Один замирает на батуте (пружина сжата), второй встаёт ему на голову, первый оживает — оба наверху.
## Комната 2: плита на 8,5 тайла — её достаёт только стоящий сверху (выше на рост товарища); там
## защёлка двери в стене под плитой, через неё проходит второй.
func _level_03() -> void:
	var pad: SpringPad = game.level.get_node("Pad")
	var top := 6.0 * TILE
	# Ложный путь: прыжок на батут — высоко, но не на стену.
	await _walk_to(b, KEYS_2, 6.0 * TILE)
	press(KEYS_2[RIGHT], true)
	press(KEYS_2[JUMP], true)
	var best := INF
	for i in 120:
		await get_tree().physics_frame
		best = minf(best, b.global_position.y)
		if i == 25:
			press(KEYS_2[JUMP], false)
	press(KEYS_2[RIGHT], false)
	check(best > top, "прыжком с батута стену в 6 тайлов не взять (вершина %.0f, стена %.0f)" % [best, top])
	await frames(30)
	# Взвести пружину: А встаёт на батут и замирает, Б — ему на голову.
	await _walk_to(b, KEYS_2, 4.0 * TILE)
	await _walk_to(a, KEYS_1, pad.global_position.x)
	place(a, Vector2(pad.global_position.x, a.global_position.y))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await frames(5)
	check(pad.is_charged(), "А замер на батуте — пружина взведена")
	await _onto_head(b, a)
	check(b.standing_on() == a, "Б стоит на голове А")
	# А оживает — выстрел; оба в воздухе рулят к стене.
	tap(KEYS_1[FREEZE])
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 150:
		await get_tree().physics_frame
		if i > 20 and a.is_on_floor() and b.is_on_floor():
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	check(a.global_position.y < top and b.global_position.y < top, "оба на стене (a %s b %s)" % [a.global_position, b.global_position])
	# Комната 2: плита на 8,5 тайла. Одного выстрел не поднимает — стоящего на нём поднимает.
	var pad2: SpringPad = game.level.get_node("Pad2")
	var latch: PressurePlate = game.level.get_node("Latch")
	var slab_top := 3.5 * TILE
	await _walk_to(b, KEYS_2, 15.0 * TILE)
	await _walk_to(a, KEYS_1, 14.0 * TILE)
	for p: Player in [b, a]:
		await _run_to(p, pad2.global_position.x + (60.0 if p == b else 0.0))
	await frames(20)
	# Ложный путь: в одиночку (без стоящего сверху) не долететь.
	place(a, Vector2(pad2.global_position.x, _stand_y(12) - 22.0))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await frames(5)
	tap(KEYS_1[FREEZE])
	press(KEYS_1[RIGHT], true)
	var feet := INF
	for i in 90:
		await get_tree().physics_frame
		feet = minf(feet, a.global_position.y + Player.SIZE.y / 2.0)
	press(KEYS_1[RIGHT], false)
	check(feet > slab_top, "в одиночку выстрел до плиты не достаёт (ноги %.0f, плита %.0f)" % [feet, slab_top])
	await _walk_to(a, KEYS_1, pad2.global_position.x)
	place(a, Vector2(pad2.global_position.x, _stand_y(12) - 22.0))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _onto_head(b, a)
	tap(KEYS_1[FREEZE])
	press(KEYS_2[RIGHT], true)
	for i in 150:
		await get_tree().physics_frame
		if i > 20 and b.is_on_floor():
			break
	press(KEYS_2[RIGHT], false)
	check(b.global_position.y < slab_top, "Б вылетел со спины А на плиту (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, latch.global_position.x)
	await frames(10)
	check(latch.active, "Б нажал защёлку — дверь внизу открыта")
	await _walk_to(b, KEYS_2, 25.0 * TILE)
	for i in 90:
		if b.is_on_floor():
			break
		await get_tree().physics_frame
	await _walk_to(a, KEYS_1, 24.0 * TILE)
	check(a.global_position.x > 22 * TILE, "А прошёл в открытую дверь")
	await _both_to_finish()


## 04 «Ломкий настил». Три настила по 5 тайлов (не перепрыгнуть): вдвоём на одном — рушится,
## по одному — держат. Комната 2: дверь держит плита перед настилом; первый переходит, пока второй
## стоит на плите, и ставит защёлку за дверью; потом переходит второй.
func _level_04() -> void:
	var level: GreyboxLevel = game.level
	var b1: BrittleFloor = level.get_node("Brittle1")
	var plate: PressurePlate = level.get_node("Plate")
	var latch: PressurePlate = level.get_node("Latch")
	# Ложный путь: вдвоём на настиле — он рушится.
	await _walk_to(b, KEYS_2, 7.0 * TILE)
	await _walk_to(a, KEYS_1, 6.0 * TILE)
	await frames(30)
	check(b1.broken, "вдвоём на настиле — рухнул")
	await _dies(a)
	await _dies(b)
	await _respawned()
	check(not b1.broken, "после респавна настил цел")
	# По одному: Б переходит все три, потом А.
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 23.0 * TILE if p == b else 22.5 * TILE, 900)
		check(p.alive and p.global_position.x > 22 * TILE, "%s перешёл три настила по одному" % p.name)
	# Комната 2: А на плите, Б переходит настил, проходит дверь и ставит защёлку.
	await _walk_to(b, KEYS_2, 28.5 * TILE)
	await _walk_to(a, KEYS_1, plate.global_position.x)
	await frames(10)
	check(plate.active, "А держит плиту — дверь открыта")
	await _walk_to(b, KEYS_2, latch.global_position.x, 900)
	await frames(10)
	check(latch.active and b.global_position.x > 37 * TILE, "Б перешёл настил и поставил защёлку")
	await _walk_to(a, KEYS_1, 37.5 * TILE, 900)
	check(a.global_position.x > 37 * TILE, "А перешёл настил и прошёл дверь")
	await _both_to_finish()


## 05 «Поворот». Мост-балка стоит торчком, пока никто не стоит на плите (по плите на каждом берегу):
## один держит плиту, второй переходит и держит свою, переходит первый. Комната 2: медленно
## вращающаяся балка над пропастью — вскочить, когда она ровная, и перебежать.
func _level_05() -> void:
	var level: GreyboxLevel = game.level
	var bridge: Spinner = level.get_node("Bridge")
	var wheel: Spinner = level.get_node("Wheel")
	var p2: PressurePlate = level.get_node("Plate2")
	check(absf(bridge.rotation_degrees - 90.0) < 1.0, "мост торчком (%.0f°)" % bridge.rotation_degrees)
	await _walk_to(b, KEYS_2, 6.6 * TILE)
	await _walk_to(a, KEYS_1, 5.0 * TILE)
	await frames(60)
	check(absf(bridge.rotation_degrees) < 1.0, "А на плите — мост лёг (%.0f°)" % bridge.rotation_degrees)
	await _walk_to(b, KEYS_2, p2.global_position.x)
	await frames(20)
	check(p2.active and b.global_position.x > 13.5 * TILE, "Б перешёл и стоит на плите за мостом")
	await _run_to(a, 19.0 * TILE)
	await frames(20)
	check(a.global_position.x > 18 * TILE and absf(bridge.rotation_degrees) < 1.0, "А перешёл, пока Б держит мост")
	# Комната 2: вскочить на вращающуюся балку, когда она почти ровная, и перебежать.
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 21.3 * TILE)
		for i in 600:
			var angle := fposmod(wheel.rotation_degrees, 180.0)
			if angle > 168.0:
				break
			await get_tree().physics_frame
		await _run_to(p, 33.0 * TILE if p == b else 32.0 * TILE)
		check(p.alive and p.global_position.x > 31 * TILE, "%s перебежал по вращающейся балке (%s)" % [p.name, p.global_position])
		if not p.alive:
			await _respawned()
	await _both_to_finish()


## 06 «Меха». Пропасть в 8 тайлов: прыжок с края её не берёт, порыв мехов несёт прыгнувшего.
## Педаль на каждом берегу: прыгает один — педаль жмёт другой.
func _level_06() -> void:
	var bellows: Bellows = game.level.get_node("Bellows")
	# Ложный путь: без ветра — в пропасть.
	await _walk_to(b, KEYS_2, 8.0 * TILE)
	await _run_jump(b, KEYS_2, 10.0 * TILE)
	check(await _dies(b), "без ветра пропасть не перепрыгнуть")
	await _respawned()
	await _walk_to(b, KEYS_2, 8.0 * TILE)
	await _walk_to(a, KEYS_1, 4.4 * TILE)
	# А жмёт педаль — Б тут же прыгает с края.
	await _walk_to(a, KEYS_1, 6.0 * TILE)
	check(bellows.is_blowing(), "А на педали — дует")
	await _run_jump(b, KEYS_2, 10.0 * TILE)
	for i in 90:
		if b.is_on_floor() or not b.alive:
			break
		await get_tree().physics_frame
	check(b.alive and b.global_position.x > 18 * TILE, "порыв перенёс Б (%.0f)" % b.global_position.x)
	await _walk_to(b, KEYS_2, 23.6 * TILE)
	await _walk_to(a, KEYS_1, 8.0 * TILE)
	await frames(30)
	# Б жмёт педаль на том берегу — прыгает А.
	await _walk_to(b, KEYS_2, 22.0 * TILE)
	check(bellows.is_blowing(), "Б на педали на том берегу — дует")
	await _run_jump(a, KEYS_1, 10.0 * TILE)
	for i in 90:
		if a.is_on_floor() or not a.alive:
			break
		await get_tree().physics_frame
	check(a.alive and a.global_position.x > 18 * TILE, "порыв перенёс А (%.0f)" % a.global_position.x)
	await _both_to_finish()


## 07 «Кран». Над шипами — кран-тележка; едет, пока кто-то стоит на плите (по плите на каждом
## берегу). Один виснет на крюке, другой встаёт на плиту; на том берегу — наоборот.
func _level_07() -> void:
	var crane: Crane = game.level.get_node("Crane")
	var hook := crane.hook
	await _walk_to(b, KEYS_2, hook.global_position.x)
	await _ride_crane(b, KEYS_2, hook, func() -> void: await _walk_to(a, KEYS_1, 4.0 * TILE))
	check(b.alive and b.global_position.x > 18 * TILE, "Б переехал шипы на кране (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 21.0 * TILE)
	# А сходит с плиты — крюк возвращается; А виснет, Б встаёт на плиту на том берегу.
	await _walk_to(a, KEYS_1, 5.4 * TILE)
	for i in 600:
		if hook.global_position.x < 7.0 * TILE:
			break
		await get_tree().physics_frame
	await frames(30)
	await _walk_to(a, KEYS_1, hook.global_position.x)
	await _ride_crane(a, KEYS_1, hook, func() -> void: await _walk_to(b, KEYS_2, 24.0 * TILE))
	check(a.alive and a.global_position.x > 18 * TILE, "А переехал шипы на кране (%s)" % a.global_position)
	await _both_to_finish()


## Прыжок на крюк крана с зажатым хватом; start() включает тележку; висит, пока крюк не над
## тем берегом (x > release_x тайлов), и спрыгивает.
func _ride_crane(p: Player, k: Array[Key], hook: Hook, start: Callable, release_x := 19.0) -> void:
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
	await start.call()
	for i in 900:
		if p.global_position.x > release_x * TILE or not p.alive:
			break
		await get_tree().physics_frame
	press(k[GRAB], false)
	for i in 90:
		if p.is_on_floor() or not p.alive:
			break
		await get_tree().physics_frame
	await frames(10)


## 08 «Под прессом». Лента тянет через тоннель под тремя прессами со сдвигом: стоящего давит,
## замерший едет, как груз, и подпирает пресс собой.
func _level_08() -> void:
	# Ложный путь: Б едет по ленте стоя — пресс давит.
	await _walk_to(b, KEYS_2, 7.0 * TILE)
	check(await _dies_within(b, 600), "стоящего на ленте под прессами давит")
	await _respawned()
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 7.0 * TILE)
		tap(_keys(p)[FREEZE])
		for i in 600:
			await get_tree().physics_frame
			if not p.alive or p.global_position.x > 26.2 * TILE:
				break
		check(p.alive and p.global_position.x > 26.2 * TILE, "%s проехал под прессами замершим (%s)" % [p.name, p.global_position])
		tap(_keys(p)[FREEZE])
		await frames(30)
		await _walk_to(p, _keys(p), 30.0 * TILE if p == b else 29.0 * TILE)
	await _both_to_finish()


## Погибнет ли p за count кадров.
func _dies_within(p: Player, count: int) -> bool:
	for i in count:
		if not p.alive:
			return true
		await get_tree().physics_frame
	return not p.alive


## 09 «Пилорама». Лента тянет через низкий коридор (пилу не перепрыгнуть), по полу ходит пила.
## Пила режет и замершего (решение 10.10.2026). Укрытие — ниши в ленте на тайл ниже: лента сама
## роняет туда, пила проходит над головой; выпрыгивать, когда пила ушла влево за нишу.
func _level_09() -> void:
	var saw: Saw = game.level.get_node("Saw")
	# Ложный путь: замереть на ленте — пила режет и замершего.
	await _walk_to(b, KEYS_2, 7.6 * TILE)
	tap(KEYS_2[FREEZE])
	check(await _dies_within(b, 900), "замершего на ленте режет пила — «Замри» не спасает")
	await _respawned()
	# Старт: пила ушла вправо за первую нишу — на ленту, в нишу.
	await _until09(func() -> bool: return saw.forward and saw.blade_position().x > 21.0 * TILE)
	_walk_to(b, KEYS_2, 14.6 * TILE)
	await _walk_to(a, KEYS_1, 12.8 * TILE)
	await frames(30)
	check(a.alive and b.alive and a.global_position.y > 12 * TILE and b.global_position.y > 12 * TILE,
			"оба в первой нише (a %s b %s)" % [a.global_position, b.global_position])
	for spot: Array in [[11.6, 21.6, 19.9, 15.0], [18.6, 27.0, 26.5, 22.0]]:
		# пила прошла над нишей влево — выпрыгнуть и бегом дальше
		await _until09(func() -> bool: return not saw.forward and saw.blade_position().x < float(spot[0]) * TILE)
		_out09(b, float(spot[3]) + 0.6, float(spot[1]))
		await _out09(a, float(spot[3]) + 0.3, float(spot[2]))
		await frames(40)
		check(a.alive and b.alive, "из ниши — дальше, пила позади (a %s b %s)" % [a.global_position, b.global_position])
	await _walk_to(b, KEYS_2, 31.0 * TILE)
	await _both_to_finish()


## Выпрыгнуть из ниши на ленту (к x_out) и бегом к x (тайлы).
func _out09(p: Player, x_out: float, x: float) -> void:
	await _hop_to(p, x_out * TILE)
	await _walk_to(p, _keys(p), x * TILE)


func _until09(cond: Callable) -> void:
	for i in 900:
		if cond.call():
			return
		await get_tree().physics_frame


## 10 «Цех» — экзамен 01–09. Комната 1: с разгона по ленте через пропасть, взведённой пружиной
## вдвоём на стену в 6 тайлов. Комната 2: меха, педаль на каждом берегу. Комната 3: мост-балка,
## по плите на каждом берегу.
func _level_10() -> void:
	var level: GreyboxLevel = game.level
	var pad: SpringPad = level.get_node("Pad")
	var bellows: Bellows = level.get_node("Bellows")
	var bridge: Spinner = level.get_node("Bridge")
	# Комната 1.
	for p: Player in [b, a]:
		await _run_jump(p, _keys(p), 12.0 * TILE)
		for i in 60:
			if p.is_on_floor() or not p.alive:
				break
			await get_tree().physics_frame
		check(p.alive and p.global_position.x > 17 * TILE, "%s перелетел пропасть с ленты" % p.name)
	await _walk_to(b, KEYS_2, 20.0 * TILE)
	await _walk_to(a, KEYS_1, pad.global_position.x)
	place(a, Vector2(pad.global_position.x, _stand_y(12) - 22.0))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _onto_head(b, a)
	tap(KEYS_1[FREEZE])
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 150:
		await get_tree().physics_frame
		if i > 20 and a.is_on_floor() and b.is_on_floor():
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	check(a.global_position.y < 6 * TILE and b.global_position.y < 6 * TILE, "взведённой пружиной оба на стене")
	# Комната 2: меха.
	await _walk_to(b, KEYS_2, 32.0 * TILE)
	await _walk_to(a, KEYS_1, 28.4 * TILE)
	await _walk_to(a, KEYS_1, 30.0 * TILE)
	check(bellows.is_blowing(), "А на педали — дует")
	await _run_jump(b, KEYS_2, 34.0 * TILE)
	for i in 90:
		if b.is_on_floor() or not b.alive:
			break
		await get_tree().physics_frame
	check(b.alive and b.global_position.x > 42 * TILE, "порыв перенёс Б (%.0f)" % b.global_position.x)
	await _walk_to(b, KEYS_2, 47.6 * TILE)
	await _walk_to(a, KEYS_1, 32.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 46.0 * TILE)
	await _run_jump(a, KEYS_1, 34.0 * TILE)
	for i in 90:
		if a.is_on_floor() or not a.alive:
			break
		await get_tree().physics_frame
	check(a.alive and a.global_position.x > 42 * TILE, "порыв перенёс А (%.0f)" % a.global_position.x)
	# Комната 3: мост-балка.
	await _walk_to(b, KEYS_2, 59.2 * TILE, 900)
	await _walk_to(a, KEYS_1, 57.0 * TILE, 900)
	await frames(60)
	check(absf(bridge.rotation_degrees) < 1.0, "А на плите — мост лёг")
	await _walk_to(b, KEYS_2, 69.0 * TILE)
	await frames(20)
	await _run_to(a, 71.0 * TILE)
	check(a.global_position.x > 66 * TILE and b.global_position.x > 66 * TILE, "оба за мостом")
	await _both_to_finish()


## 11 «Жук». Полка в 3 тайла: прыжком с пола не взять, со спины жука — берётся. Дальше дорожка над
## шипами с разрывом: на той стороне ходит второй жук и спихивает в разрыв — перепрыгнуть его.
func _level_11() -> void:
	var beetle1: Beetle = game.level.get_node("Beetle1")
	var beetle2: Beetle = game.level.get_node("Beetle2")
	# Ложный путь: с пола полку не взять.
	await _walk_to(b, KEYS_2, 13.0 * TILE)
	await _jump(b, KEYS_2, RIGHT, 30)
	check(b.global_position.y > 10 * TILE, "с пола полку в 3 тайла не взять")
	for p: Player in [b, a]:
		var k := _keys(p)
		await _walk_to(p, k, 4.0 * TILE if p == a else 3.0 * TILE)
		# Ждём, пока жук подойдёт к полке, — и на него.
		for i in 900:
			if beetle1.global_position.x > 12.0 * TILE and beetle1.direction > 0:
				break
			await get_tree().physics_frame
		place(p, beetle1.global_position + Vector2(0, -52.0))
		await frames(8)
		check(Weight.floor_below(p) == beetle1, "%s на спине жука" % p.name)
		await _jump(p, k, RIGHT, 30)
		check(p.global_position.y < 9.25 * TILE and p.global_position.x > 14 * TILE, "%s со спины жука на полку (%s)" % [p.name, p.global_position])
		await _walk_to(p, k, 16.0 * TILE if p == b else 15.2 * TILE)
	# Дорожка над шипами: перепрыгнуть разрыв, когда жук ушёл вправо, и перепрыгнуть самого жука.
	for p: Player in [b, a]:
		var k := _keys(p)
		await _walk_to(p, k, 20.4 * TILE)
		for i in 1200:
			if beetle2.direction > 0 and beetle2.global_position.x > 26.0 * TILE and beetle2.global_position.x < 30.0 * TILE:
				break
			await get_tree().physics_frame
		await _run_to(p, 33.5 * TILE if p == b else 32.5 * TILE)
		check(p.alive and p.global_position.x > 31 * TILE, "%s прошёл дорожку мимо жука (%s)" % [p.name, p.global_position])
		if not p.alive:
			await _respawned()
	await _both_to_finish()


## 12 «Жук на плите». Плите нужен вес двоих: жук весит 1. Жук ходит по загону и с плиты уходит;
## замерший на краю плиты запирает его у стенки — плита нажата (жук + замерший), дверь открыта.
## Второй проходит и ставит защёлку, первый оживает и идёт следом.
func _level_12() -> void:
	var beetle: Beetle = game.level.get_node("Beetle")
	var plate: PressurePlate = game.level.get_node("Plate")
	var latch: PressurePlate = game.level.get_node("Latch")
	# Ложный путь: один на плите — мало.
	place(b, Vector2(12.0 * TILE, _stand_y(12)))
	await frames(20)
	check(not plate.active, "один игрок на плите — мало (нужен вес 2)")
	place(b, Vector2(3.0 * TILE, _stand_y(12)))
	# Жук на плите идёт вправо — А замирает на левом краю плиты, жук заперт.
	for i in 1200:
		if beetle.global_position.x > 12.4 * TILE and beetle.direction > 0:
			break
		await get_tree().physics_frame
	place(a, Vector2(11.25 * TILE, _stand_y(12) - 14.0))
	tap(KEYS_1[FREEZE])
	await frames(120)
	check(plate.active, "жук заперт на плите замершим А — плита нажата (%s)" % beetle.global_position)
	# Б по голове А и через загон к двери, на защёлку.
	await _onto_head(b, a)
	await _jump(b, KEYS_2, RIGHT, 30)
	await _run_to(b, latch.global_position.x)
	await frames(10)
	check(latch.active, "Б прошёл дверь и поставил защёлку")
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _run_to(a, 22.0 * TILE)
	check(a.global_position.x > 21 * TILE, "А прошёл следом")
	await _both_to_finish()


## 13 «Искра». Искры бегают по проводам на полу цеха: касание — гибель. Через искру прыгают;
## замерший — камень: искра в него упирается и бежит назад.
func _level_13() -> void:
	var s1: Spark = game.level.get_node("Spark1")
	# Замерший цел: А замирает на проводе — искра упирается в него.
	place(a, Vector2(10.0 * TILE, _stand_y(12)))
	await frames(3)
	tap(KEYS_1[FREEZE])
	await frames(240)
	check(a.alive and absf(s1.global_position.x - a.global_position.x) < 80.0, "искра упирается в замершего (искра %.0f, А %.0f)" % [s1.global_position.x, a.global_position.x])
	tap(KEYS_1[FREEZE])
	check(await _dies_within(a, 400), "ожил рядом с искрой — сгорел")
	await _respawned()
	# Через провод прыжками: ждём, пока искра бежит прочь, и обгоняем её прыжком.
	for p: Player in [b, a]:
		await _jump_sparks(p, [s1], 4.0 * TILE, 16.5 * TILE)
		check(p.alive and p.global_position.x > 16 * TILE, "%s миновал первую искру" % p.name)
	for p: Player in [b, a]:
		await _jump_sparks(p, [game.level.get_node("Spark2")], 18.0 * TILE, 32.5 * TILE if p == b else 31.6 * TILE)
		check(p.alive and p.global_position.x > 31 * TILE, "%s миновал быструю искру" % p.name)
	await _both_to_finish()


## Идёт от from_x к to_x вдоль провода: за уходящей искрой держится поодаль, встречную
## перепрыгивает, когда до встречи ≈ 0,2 с.
func _jump_sparks(p: Player, sparks: Array, from_x: float, to_x: float) -> void:
	var k := _keys(p)
	await _walk_to(p, k, from_x)
	var last := {}
	for spark: Spark in sparks:
		last[spark] = spark.global_position.x
	for i in 1800:
		await get_tree().physics_frame
		if not p.alive or p.global_position.x >= to_x:
			break
		var jump := false
		var wait := false
		for spark: Spark in sparks:
			var spark_v: float = (spark.global_position.x - last[spark]) * 60.0
			last[spark] = spark.global_position.x
			var dx := spark.global_position.x - p.global_position.x
			if not spark.visible or dx <= 0.0:
				continue
			if spark_v > 0.0 and dx < 100.0:
				wait = true  # уходит — не наступать на пятки
			elif spark_v <= 0.0 and dx / maxf(360.0 - spark_v, 1.0) < 0.22:
				jump = true
		press(k[RIGHT], not wait or not p.is_on_floor())
		press(k[JUMP], jump and p.is_on_floor())
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## 14 «Стрелка». Искра бежит к развилке: сама сворачивает к бочонку у моста, а пока кто-то стоит
## на плите-стрелке (по одной на каждом берегу) — к бочонку у треснувшей стены. А держит стрелку:
## стена рушится, Б проходит, переходит мост и держит стрелку на том берегу; А идёт следом.
func _level_14() -> void:
	var level: GreyboxLevel = game.level
	var wall: CrackedWall = level.get_node("Wall")
	var bridge: CrackedWall = level.get_node("Bridge")
	# Ложный путь: никто не держит стрелку — искра взрывает мост.
	for i in 1200:
		if bridge.smashed:
			break
		await get_tree().physics_frame
	check(bridge.smashed and not wall.smashed, "без стрелки искра взорвала мост")
	game.restart_from_checkpoint()
	await frames(5)
	check(not bridge.smashed, "рестарт с чекпоинта — мост цел")
	# А встаёт на стрелку (до развилки искра бежит ≈ 3 с), Б ждёт поодаль от стены.
	await _walk_to(b, KEYS_2, 9.0 * TILE)
	await _walk_to(a, KEYS_1, 6.0 * TILE)
	for i in 1200:
		if wall.smashed:
			break
		await get_tree().physics_frame
	check(wall.smashed and not bridge.smashed, "искра пошла к стене — стена рухнула, мост цел")
	await frames(30)
	await _walk_to(b, KEYS_2, 35.0 * TILE, 900)
	await frames(10)
	check(b.global_position.x > 34 * TILE, "Б прошёл в пролом и по мосту, стоит на стрелке")
	await _walk_to(a, KEYS_1, 34.0 * TILE, 900)
	check(a.global_position.x > 33 * TILE and not bridge.smashed, "А прошёл следом, мост цел")
	await _both_to_finish()


## 15 «Фитиль». Стену ломает только взрыв бочонка. Стрелку держит плита с порогом 2 — оба на ней;
## искра поджигает фитиль, а плита — в радиусе взрыва: оба замирают (замерший — камень).
func _level_15() -> void:
	var keg: Keg = game.level.get_node("Keg")
	var wall: CrackedWall = game.level.get_node("Wall")
	# Ложный путь: один на плите — искра уходит в землю.
	await _walk_to(b, KEYS_2, 18.0 * TILE)
	await frames(360)
	check(keg.state == Keg.State.READY, "один на плите — искра уходит в землю, фитиль цел")
	await _walk_to(a, KEYS_1, 17.4 * TILE)
	for i in 600:
		if keg.state == Keg.State.LIT:
			break
		await get_tree().physics_frame
	check(keg.state == Keg.State.LIT, "оба на плите — искра подожгла фитиль")
	tap(KEYS_1[FREEZE])
	tap(KEYS_2[FREEZE])
	for i in 200:
		if wall.smashed:
			break
		await get_tree().physics_frame
	check(wall.smashed and a.alive and b.alive, "взрыв проломил стену, замершие целы")
	tap(KEYS_1[FREEZE])
	tap(KEYS_2[FREEZE])
	await frames(10)
	await _both_to_finish()


## 16 «Ветер и ящик». Дверь держит плита в лунке за пропастью в 6 тайлов. Ящик, сброшенный с уступа,
## падает в пропасть; если в это время дуют меха — порыв несёт его на плиту. Потом игроки
## перелетают пропасть на порыве, как в 06 (педаль на каждом берегу).
func _level_16() -> void:
	var crate: Crate = game.level.get_node("Crate")
	var plate: PressurePlate = game.level.get_node("Plate")
	var bellows: Bellows = game.level.get_node("Bellows")
	# Б толкает ящик к краю; А встаёт на педаль, когда ящик на краю.
	await _walk_to(b, KEYS_2, crate.global_position.x - 62.0)
	await _walk_to(a, KEYS_1, 4.4 * TILE)
	press(KEYS_2[RIGHT], true)
	for i in 600:
		await get_tree().physics_frame
		# А шагает на педаль, когда ящик у края.
		press(KEYS_1[RIGHT], crate.global_position.x > 13.0 * TILE and a.global_position.x < 6.0 * TILE)
		if crate.global_position.y > 7.0 * TILE or b.global_position.x > 13.6 * TILE:
			break
	press(KEYS_2[RIGHT], false)
	press(KEYS_1[RIGHT], false)
	for i in 180:
		if plate.active:
			break
		await get_tree().physics_frame
	check(plate.active, "порыв донёс ящик на плиту за пропастью (ящик %s)" % crate.global_position)
	# Переправа на порыве: Б прыгает, А жмёт педаль; потом наоборот.
	await _walk_to(a, KEYS_1, 4.4 * TILE)
	await _walk_to(b, KEYS_2, 12.0 * TILE)
	await _walk_to(a, KEYS_1, 6.0 * TILE)
	await _run_jump(b, KEYS_2, 14.0 * TILE)
	for i in 120:
		if b.is_on_floor() or not b.alive:
			break
		await get_tree().physics_frame
	check(b.alive and b.global_position.x > 20 * TILE, "порыв перенёс Б (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 28.0 * TILE)
	await _walk_to(a, KEYS_1, 12.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 27.0 * TILE)
	check(bellows.is_blowing(), "Б на педали на том берегу — дует")
	await _run_jump(a, KEYS_1, 14.0 * TILE)
	for i in 120:
		if a.is_on_floor() or not a.alive:
			break
		await get_tree().physics_frame
	check(a.alive and a.global_position.x > 20 * TILE, "порыв перенёс А (%s)" % a.global_position)
	await _run_to(a, 29.0 * TILE)
	await _run_to(b, 29.5 * TILE)
	await _both_to_finish()


## 17 «Призрак в цеху». Лента тянет к призраку (300 против бега 360 — против неё еле идёшь), рычаг
## в её конце её останавливает. А держит призрака взглядом, Б долго идёт по ленте и останавливает
## её; А бежит по стоящей ленте — призрак не догонит.
func _level_17() -> void:
	var ghost: Ghost = game.level.get_node("Ghost")
	var lever: Lever = game.level.get_node("Lever")
	# А смотрит на призрака (лицом влево), Б идёт по ленте.
	await _face_side(a, LEFT)
	press(KEYS_2[RIGHT], true)
	for i in 1800:
		await get_tree().physics_frame
		if not b.alive or b.global_position.x > 31.0 * TILE:
			break
	press(KEYS_2[RIGHT], false)
	check(a.alive and b.alive and b.global_position.x > 31 * TILE, "Б прошёл ленту, пока А держал призрака взглядом (призрак %s)" % ghost.global_position)
	await _walk_to(b, KEYS_2, lever.global_position.x - 10.0)
	await hold(KEYS_2[GRAB], 3)
	check(lever.active, "Б остановил ленту рычагом")
	await _face_side(b, LEFT)
	await _run_to(a, 33.0 * TILE)
	check(a.alive and a.global_position.x > 32 * TILE, "А пробежал по стоящей ленте (призрак %s)" % ghost.global_position)
	await _both_to_finish()


## Повернуться лицом в сторону side (шаг на месте).
func _face_side(p: Player, side: int) -> void:
	var k := _keys(p)
	press(k[side], true)
	await frames(1)
	press(k[side], false)
	await frames(2)


## 18 «Два жука». Двери нужны обе плиты сразу — по жуку на каждой. Каждый жук ходит по своему
## загону и с плиты уходит. Первого запирает на плите ящик (Б подталкивает его вслед жуку),
## второго — замерший А. Б проходит дверь и ставит защёлку, А оживает и идёт следом.
func _level_18() -> void:
	var level: GreyboxLevel = game.level
	var beetle1: Beetle = level.get_node("Beetle1")
	var beetle2: Beetle = level.get_node("Beetle2")
	var crate: Crate = level.get_node("Crate")
	var plate1: PressurePlate = level.get_node("Plate1")
	var plate2: PressurePlate = level.get_node("Plate2")
	var latch: PressurePlate = level.get_node("Latch")
	# Б в первом загоне за ящиком; ждёт, пока жук уйдёт на плиту, и толкает ящик следом.
	place(b, Vector2(5.0 * TILE, _stand_y(12)))
	await frames(10)
	for i in 1500:
		if beetle1.global_position.x > 10.4 * TILE and beetle1.direction > 0:
			break
		await get_tree().physics_frame
	await _push_crate(b, crate, 9.0 * TILE)
	await frames(240)
	check(plate1.active and absf(crate.global_position.x - 9.0 * TILE) < 24.0, "ящик запер первого жука на плите (ящик %.0f, жук %.0f)" % [crate.global_position.x, beetle1.global_position.x])
	# Второго жука запирает замерший А.
	for i in 1500:
		if beetle2.global_position.x > 20.4 * TILE and beetle2.direction > 0:
			break
		await get_tree().physics_frame
	place(a, Vector2(19.25 * TILE, _stand_y(12) - 14.0))
	tap(KEYS_1[FREEZE])
	await frames(180)
	check(plate1.active and plate2.active, "оба жука на плитах — дверь открыта")
	# Б — по ящику, через загоны и голову А, к защёлке.
	place(b, Vector2(crate.global_position.x, crate.global_position.y - 62.0))
	await frames(5)
	await _run_to(b, latch.global_position.x)
	await frames(10)
	check(latch.active, "Б прошёл дверь и поставил защёлку")
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _run_to(a, 27.0 * TILE)
	check(a.global_position.x > 26.5 * TILE, "А прошёл следом")
	await _both_to_finish()


## 19 «Искры и пружины». Стрелка искры — плита на полке в 8,5 тайла: туда долетает только тот,
## кто стоит на взведённом товарище. Пока он на плите, искра бежит к бочонку у стены внизу.
func _level_19() -> void:
	var level: GreyboxLevel = game.level
	var pad: SpringPad = level.get_node("Pad")
	var plate: PressurePlate = level.get_node("Plate")
	var wall: CrackedWall = level.get_node("Wall")
	# Ложный путь: без стрелки искра уходит в землю — стена цела.
	await frames(480)
	check(not wall.smashed, "без стрелки искра уходит в землю")
	# Взведённая пружина: А замирает на батуте, Б на нём; А оживает — Б летит на полку.
	await _walk_to(b, KEYS_2, 9.0 * TILE)
	await _walk_to(a, KEYS_1, pad.global_position.x)
	place(a, Vector2(pad.global_position.x, _stand_y(12) - 22.0))
	await frames(10)
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _onto_head(b, a)
	tap(KEYS_1[FREEZE])
	press(KEYS_2[RIGHT], true)
	for i in 150:
		await get_tree().physics_frame
		if i > 20 and b.is_on_floor():
			break
	press(KEYS_2[RIGHT], false)
	check(b.global_position.y < 3.5 * TILE, "Б на полке (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, plate.global_position.x)
	await frames(10)
	check(plate.active, "Б держит стрелку")
	await _walk_to(a, KEYS_1, 12.0 * TILE)
	for i in 1200:
		if wall.smashed:
			break
		await get_tree().physics_frame
	check(wall.smashed and a.alive, "искра дошла до бочонка — стена рухнула, А цел поодаль")
	await _walk_to(b, KEYS_2, 12.5 * TILE)
	for i in 120:
		if b.is_on_floor() and b.global_position.y > 11 * TILE:
			break
		await get_tree().physics_frame
	await _both_to_finish()


## 20 «Большая машина» — экзамен мира. Комната 1: с разгона по ленте через пропасть, под прессами —
## замершими. Комната 2: жук на плите (вес 2: жук + замерший), защёлка за дверью. Комната 3:
## стрелка искры — к бочонку у стены, второй ждёт поодаль.
func _level_20() -> void:
	var level: GreyboxLevel = game.level
	# Комната 1.
	for p: Player in [b, a]:
		await _run_jump(p, _keys(p), 12.0 * TILE)
		for i in 60:
			if p.is_on_floor() or not p.alive:
				break
			await get_tree().physics_frame
		check(p.alive and p.global_position.x > 17 * TILE, "%s перелетел пропасть с ленты" % p.name)
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 23.8 * TILE)
		tap(_keys(p)[FREEZE])
		for i in 900:
			await get_tree().physics_frame
			if not p.alive or p.global_position.x > 37.2 * TILE:
				break
		check(p.alive and p.global_position.x > 37.2 * TILE, "%s проехал под прессами замершим" % p.name)
		tap(_keys(p)[FREEZE])
		await frames(20)
		await _walk_to(p, _keys(p), 40.0 * TILE if p == b else 39.0 * TILE)
	# Комната 2.
	var beetle: Beetle = level.get_node("Beetle")
	var plate2: PressurePlate = level.get_node("Plate2")
	var latch: PressurePlate = level.get_node("Latch")
	for i in 1500:
		if beetle.global_position.x > 48.9 * TILE and beetle.direction > 0:
			break
		await get_tree().physics_frame
	place(a, Vector2(47.75 * TILE, _stand_y(12) - 14.0))
	tap(KEYS_1[FREEZE])
	await frames(120)
	check(plate2.active, "жук заперт на плите — дверь открыта")
	place(b, a.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(10)
	await _jump(b, KEYS_2, RIGHT, 30)
	await _run_to(b, latch.global_position.x)
	await frames(10)
	check(latch.active, "Б поставил защёлку")
	tap(KEYS_1[FREEZE])
	await frames(5)
	await _run_to(a, 57.0 * TILE)
	check(a.global_position.x > 55 * TILE, "А прошёл дверь")
	# Комната 3.
	var wall: CrackedWall = level.get_node("Wall")
	await _walk_to(b, KEYS_2, 66.0 * TILE)
	await _walk_to(a, KEYS_1, 62.0 * TILE)
	for i in 1500:
		if wall.smashed:
			break
		await get_tree().physics_frame
	check(wall.smashed and a.alive and b.alive, "искра у бочонка — стена рухнула")
	await _both_to_finish()
