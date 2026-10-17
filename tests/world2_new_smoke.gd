extends "res://tests/world2_levels_smoke.gd"
## Автопроверка перестроенного мира 2 «Мастерские» (решение 67: 3 вводных, 5 сложных,
## 12 очень сложных; типы — голова, ловкость, скорость): пара проходит каждый уровень от старта
## до двери. Помощники (кран, искры, жуки) — из теста прежнего мира 2.
## Запуск: Godot_console --headless --fixed-fps 60 --path . res://tests/world2_new_smoke.tscn [-- 01]

const NEW_LEVELS := {
	"01": preload("res://levels/w02_l01_belt_spring.tscn"),
	"02": preload("res://levels/w02_l02_wind_crane.tscn"),
	"03": preload("res://levels/w02_l03_spark_beetle.tscn"),
	"04": preload("res://levels/w02_l04_sorting.tscn"),
	"05": preload("res://levels/w02_l05_windmill.tscn"),
	"06": preload("res://levels/w02_l06_switchman.tscn"),
	"07": preload("res://levels/w02_l07_shift.tscn"),
	"08": preload("res://levels/w02_l08_crane_chain.tscn"),
	"09": preload("res://levels/w02_l09_fuse_run.tscn"),
	"10": preload("res://levels/w02_l10_scales.tscn"),
	"11": preload("res://levels/w02_l11_beetle_belts.tscn"),
	"12": preload("res://levels/w02_l12_rockfall_shop.tscn"),
	"13": preload("res://levels/w02_l13_lock.tscn"),
	"14": preload("res://levels/w02_l14_spring_circus.tscn"),
	"15": preload("res://levels/w02_l15_wheel.tscn"),
	"16": preload("res://levels/w02_l16_gust.tscn"),
	"17": preload("res://levels/w02_l17_heavy_order.tscn"),
	"18": preload("res://levels/w02_l18_sparks_ghost.tscn"),
	"19": preload("res://levels/w02_l19_crossroads.tscn"),
	"20": preload("res://levels/w02_l20_big_machine.tscn"),
}


func _catalog() -> Dictionary:
	return NEW_LEVELS


func _method(id: String) -> String:
	return "_n" + id


## Ждёт приземления p (до count кадров).
func _land(p: Player, count := 90) -> void:
	for i in count:
		if p.is_on_floor() or not p.alive:
			return
		await get_tree().physics_frame


## Разбег вправо с прыжком (прыжок держится jump_frames кадров); до приземления выше floor_row.
func _run_hop_up(p: Player, floor_row: float, jump_frames := 25) -> void:
	var k := _keys(p)
	press(k[RIGHT], true)
	press(k[JUMP], true)
	for i in 150:
		await get_tree().physics_frame
		if i == jump_frames:
			press(k[JUMP], false)
		if i > 10 and p.is_on_floor() and p.global_position.y < floor_row * TILE:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## Взведённая пружина: low замирает на батуте pad, top встаёт ему на голову, low оживает —
## оба летят вправо до приземления.
func _charged_launch(low: Player, top: Player, pad: SpringPad, ready := Callable()) -> void:
	var kl := _keys(low)
	var kt := _keys(top)
	await _walk_to(low, kl, pad.global_position.x)
	place(low, Vector2(pad.global_position.x, pad.global_position.y - SpringPad.HEIGHT - Player.SIZE.y / 2.0 - 1.0))
	await frames(10)
	tap(kl[FREEZE])
	await frames(5)
	check(pad.is_charged(), "%s замер на батуте — пружина взведена" % low.name)
	await _onto_head(top, low)
	check(top.standing_on() == low, "%s стоит на голове %s" % [top.name, low.name])
	if ready.is_valid():
		for i in 900:
			if ready.call():
				break
			await get_tree().physics_frame
	tap(kl[FREEZE])
	press(kl[RIGHT], true)
	press(kt[RIGHT], true)
	for i in 150:
		await get_tree().physics_frame
		if i > 20 and low.is_on_floor() and top.is_on_floor():
			break
	press(kl[RIGHT], false)
	press(kt[RIGHT], false)
	await frames(10)


# --- 01–03: вводные --------------------------------------------------------------------------

## 01 «Лента и пружина»: разгон по ленте через пропасть; батут на стену 3; взведённая пружина
## вдвоём на стену 6; два ломких настила по одному.
func _n01() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	for p: Player in [b, a]:
		await _run_jump(p, _keys(p), 13.0 * TILE)
		await _land(p)
		check(p.alive and p.global_position.x > 18 * TILE, "%s перелетел пропасть с ленты (%.0f)" % [p.name, p.global_position.x])
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 21.6 * TILE)
		await _run_hop_up(p, 9.0)
		check(p.global_position.y < 9 * TILE and p.global_position.x > 25 * TILE, "%s с батута на стену 3 (%s)" % [p.name, p.global_position])
		await _walk_to(p, _keys(p), (27.4 if p == b else 26.4) * TILE)
	await _charged_launch(a, b, level.get_node("Pad2"))
	check(a.global_position.y < 3 * TILE and b.global_position.y < 3 * TILE, "взведённая пружина — оба на стене 6 (a %s b %s)" % [a.global_position, b.global_position])
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), (50.5 if p == b else 49.8) * TILE, 900)
		check(p.alive and p.global_position.x > 49.5 * TILE, "%s перешёл ломкие настилы (%s)" % [p.name, p.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## 02 «Ветер и кран»: порыв мехов через пропасть (педаль на каждом берегу); кран над шипами
## (плита на каждом берегу); мост-балка от плит и вращающаяся балка.
func _n02() -> void:
	var level: GreyboxLevel = game.level
	var bellows: Bellows = level.get_node("Bellows")
	var before := deaths
	await _walk_to(b, KEYS_2, 8.0 * TILE)
	await _walk_to(a, KEYS_1, 4.4 * TILE)
	await _walk_to(a, KEYS_1, 6.0 * TILE)
	check(bellows.is_blowing(), "А на педали — дует")
	await _run_jump(b, KEYS_2, 10.0 * TILE)
	await _land(b)
	check(b.alive and b.global_position.x > 18 * TILE, "порыв перенёс Б (%.0f)" % b.global_position.x)
	await _walk_to(b, KEYS_2, 23.6 * TILE)
	await _walk_to(a, KEYS_1, 8.0 * TILE)
	await frames(30)
	await _walk_to(b, KEYS_2, 22.0 * TILE)
	check(bellows.is_blowing(), "Б на педали на том берегу — дует")
	await _run_jump(a, KEYS_1, 10.0 * TILE)
	await _land(a)
	check(a.alive and a.global_position.x > 18 * TILE, "порыв перенёс А (%.0f)" % a.global_position.x)
	# Кран: Б на крюке, А на плите; потом А на крюке, Б на плите на том берегу.
	var hook: Hook = (level.get_node("Crane") as Crane).hook
	await _walk_to(b, KEYS_2, 28.0 * TILE)
	await _walk_to(a, KEYS_1, 26.0 * TILE)
	await _walk_to(b, KEYS_2, hook.global_position.x)
	await frames(60)
	await _walk_to(b, KEYS_2, hook.global_position.x)
	await _ride_crane(b, KEYS_2, hook, func() -> void: await _walk_to(a, KEYS_1, 32.0 * TILE), 46.5)
	check(b.alive and b.global_position.x > 46 * TILE, "Б переехал шипы на кране (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 49.0 * TILE)
	await _walk_to(a, KEYS_1, 33.4 * TILE)
	for i in 600:
		if hook.global_position.x < 35.0 * TILE:
			break
		await get_tree().physics_frame
	await frames(30)
	await _walk_to(a, KEYS_1, hook.global_position.x)
	await _ride_crane(a, KEYS_1, hook, func() -> void: await _walk_to(b, KEYS_2, 52.0 * TILE), 46.5)
	check(a.alive and a.global_position.x > 46 * TILE, "А переехал шипы на кране (%s)" % a.global_position)
	# Мост-балка: А держит плиту, Б переходит и держит свою, А переходит.
	var bridge: Spinner = level.get_node("Bridge")
	var p2: PressurePlate = level.get_node("BridgePlate2")
	await _walk_to(b, KEYS_2, 58.6 * TILE)
	await _walk_to(a, KEYS_1, 57.0 * TILE)
	await frames(60)
	check(absf(bridge.rotation_degrees) < 1.0, "А на плите — мост лёг (%.0f°)" % bridge.rotation_degrees)
	await _walk_to(b, KEYS_2, p2.global_position.x)
	await frames(20)
	check(p2.active, "Б перешёл и стоит на плите за мостом")
	await _run_to(a, 71.0 * TILE)
	await frames(20)
	check(a.global_position.x > 70 * TILE, "А перешёл, пока Б держит мост")
	# Вращающаяся балка: вскочить, когда она почти ровная, и перебежать.
	var wheel: Spinner = level.get_node("Wheel")
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 73.3 * TILE)
		for i in 600:
			if fposmod(wheel.rotation_degrees, 180.0) > 168.0:
				break
			await get_tree().physics_frame
		await _run_to(p, (85.0 if p == b else 84.0) * TILE)
		check(p.alive and p.global_position.x > 83 * TILE, "%s перебежал по вращающейся балке (%s)" % [p.name, p.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## 03 «Искра и жук»: перепрыгнуть встречную искру; стрелка шлёт искру к бочонку — стена рушится;
## со спины жука на полку; на дорожке над шипами — мимо второго жука.
func _n03() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var s1: Spark = level.get_node("Spark1")
	for p: Player in [b, a]:
		await _jump_sparks(p, [s1], 4.0 * TILE, (17.6 if p == b else 16.8) * TILE)
		check(p.alive and p.global_position.x > 16 * TILE, "%s миновал искру" % p.name)
	# Стрелка: А на плите — искра бежит к бочонку, стена рушится (Б стоит поодаль).
	var wall: Node = level.get_node("Wall")
	await _walk_to(b, KEYS_2, 24.5 * TILE)
	await _walk_to(a, KEYS_1, (level.get_node("Switch") as Node2D).global_position.x)
	for i in 900:
		if wall.smashed:
			break
		await get_tree().physics_frame
	await frames(30)
	check(wall.smashed and deaths == before, "А держит стрелку — бочонок взорвал стену")
	# Жук: со спины на полку в 3 тайла (вдвоём подходят к загону — камера держит обоих).
	var beetle1: Beetle = level.get_node("Beetle1")
	await _walk_to(b, KEYS_2, 35.0 * TILE)
	await _walk_to(a, KEYS_1, 33.6 * TILE)
	for p: Player in [b, a]:
		var k := _keys(p)
		await _walk_to(p, k, (34.0 if p == a else 35.0) * TILE)
		for attempt in 3:  # не вскочил — ждать следующего захода жука
			for i in 1500:
				if beetle1.global_position.x > 43.0 * TILE and beetle1.direction > 0:
					break
				await get_tree().physics_frame
			place(p, beetle1.global_position - Vector2(0, (Beetle.SIZE.y + Player.SIZE.y) / 2.0 + 1.0))
			await frames(8)
			if Weight.floor_below(p) == beetle1:
				break
			await _walk_to(p, k, (34.0 if p == a else 35.0) * TILE)
			for i in 900:
				if beetle1.direction < 0:
					break
				await get_tree().physics_frame
		check(Weight.floor_below(p) == beetle1, "%s на спине жука" % p.name)
		await _jump(p, k, RIGHT, 30)
		check(p.global_position.y < 9.25 * TILE and p.global_position.x > 45 * TILE, "%s со спины жука на полку (%s)" % [p.name, p.global_position])
		await _walk_to(p, k, (47.0 if p == b else 46.2) * TILE)
	# Дорожка над шипами: перепрыгнуть разрыв, когда жук ушёл вправо, и перепрыгнуть самого жука.
	var beetle2: Beetle = level.get_node("Beetle2")
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 51.4 * TILE)
		for i in 1200:
			if beetle2.direction > 0 and beetle2.global_position.x > 57.0 * TILE and beetle2.global_position.x < 61.0 * TILE:
				break
			await get_tree().physics_frame
		await _run_to(p, (64.5 if p == b else 63.5) * TILE)
		check(p.alive and p.global_position.x > 62 * TILE, "%s прошёл дорожку мимо жука (%s)" % [p.name, p.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


const WIND_FROM := 172.0
const SPIN2_FROM := 174.0
const CRANE_SAW_FROM := 0.0
const CATCH_X := 7.4
const POGO_PHASE := 1.5
const CHARGE_PHASE := 1.0
const SPARK_LEAD := 0.22
const GUST_DELAY := 0
const HEAVY_PEDAL_DELAY := 40


# --- 04–08: сложные ---------------------------------------------------------------------------

## Живая лестница на уступ в 3 тайла (стена — левый край уступа wall_x, верх — top_row):
## bottom встаёт к стене и замирает, top с его головы прыгает наверх, bottom оживает, top вытягивает.
func _ladder_up(bottom: Player, top: Player, wall_x: float, top_row: float) -> void:
	await _walk_to(bottom, _keys(bottom), (wall_x - 0.45) * TILE)
	tap(_keys(bottom)[FREEZE])
	await frames(5)
	await _onto_head(top, bottom)
	await _jump(top, _keys(top), RIGHT, 40)
	check(top.is_on_floor() and top.global_position.y < top_row * TILE, "%s с головы %s — на уступ (%s)" % [top.name, bottom.name, top.global_position])
	tap(_keys(bottom)[FREEZE])
	await _walk_to(top, _keys(top), (wall_x + 0.4) * TILE)
	await _pull_up(top, bottom, RIGHT)
	check(bottom.is_on_floor() and bottom.global_position.y < top_row * TILE, "%s вытянул %s на уступ (%s)" % [top.name, bottom.name, bottom.global_position])


## С ящика у стены — на уступ: прыжок на ящик и с него наверх.
func _crate_step_up(p: Player, top_row: float) -> void:
	await _jump(p, _keys(p), RIGHT, 18)
	await _jump(p, _keys(p), RIGHT, 30)
	check(p.is_on_floor() and p.global_position.y < top_row * TILE, "%s по ящику — на уступ (%s)" % [p.name, p.global_position])


## Перепрыгнуть через ящик (и стоящих) и встать в x.
func _hop_over(p: Player, x: float) -> void:
	await _hop_to(p, x * TILE)
	await _walk_to(p, _keys(p), x * TILE)


## 06 «Стрелочник» (на подумать): искра бежит по развилкам к бочонкам. Решение: Б замирает на
## плите A в радиусе бочонка — W1 рушится; Б идёт на дальнюю стрелку D (толкая ящик через мост),
## А включает рычаг (с D под Б искра идёт мимо моста); А — за мост; Б толкает ящик на плиту C
## и стоит на ней — D свободна, мост рушится (А уже за ним); А встаёт на D — искра к K2, стена W2
## у выхода рушится; оба вниз, в коридор, и к выходу.
func _n06() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var w1: Node = level.get_node("W1")
	var bridge: Node = level.get_node("Bridge")
	var w2: Node = level.get_node("W2")
	await _walk_to(b, KEYS_2, 9.0 * TILE)
	tap(KEYS_2[FREEZE])
	await frames(5)
	check((level.get_node("PlateA") as PressurePlate).active, "Б замер на плите A")
	for i in 900:
		if w1.smashed:
			break
		await get_tree().physics_frame
	await frames(30)
	check(w1.smashed and deaths == before, "бочонок K1 взорвал стену W1, замершему Б взрыв не страшен")
	tap(KEYS_2[FREEZE])
	await frames(5)
	await _walk_to(b, KEYS_2, 30.0 * TILE, 900)
	await frames(20)
	check((level.get_node("PlateD") as PressurePlate).active and not bridge.smashed, "Б довёз ящик через мост и стоит на стрелке D")
	await _walk_to(a, KEYS_1, 17.5 * TILE, 900)
	await hold(KEYS_1[GRAB], 4)
	await frames(10)
	check((level.get_node("LeverL") as Lever).active, "А включил рычаг")
	await _walk_to(a, KEYS_1, 28.3 * TILE, 900)
	await frames(240)
	check(not bridge.smashed and deaths == before, "мост цел: стрелка D под Б уводит искру мимо него")
	await _walk_to(b, KEYS_2, 34.5 * TILE)
	for i in 900:
		if bridge.smashed:
			break
		await get_tree().physics_frame
	await frames(30)
	check(bridge.smashed and deaths == before, "Б сошёл с D — мост рухнул (А уже за ним)")
	check((level.get_node("PlateC") as PressurePlate).active, "на плите C — ящик и Б")
	await _walk_to(a, KEYS_1, 30.0 * TILE)
	for i in 1200:
		if w2.smashed:
			break
		await get_tree().physics_frame
	await frames(30)
	check(w2.smashed and deaths == before, "А на D — искра дошла до K2, стена у выхода рухнула")
	for p: Player in [a, b]:
		var k := _keys(p)
		press(k[LEFT], true)
		for i in 240:
			await get_tree().physics_frame
			if p.global_position.y > 14.0 * TILE:
				break
		press(k[LEFT], false)
		await _land(p)
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), (45.0 if p == b else 44.0) * TILE, 900)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## 04 «Сортировка» (на подумать): см. tools/levels/w02_l04_sorting.py.
func _n04() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var c1: Crate = level.get_node("Crate1")
	var c0: Crate = level.get_node("Crate0")
	var c2: Crate = level.get_node("Crate2")
	var p5: PressurePlate = level.get_node("P5")
	var p4: PressurePlate = level.get_node("P4")
	var p2: PressurePlate = level.get_node("P2")
	# Ящик R0 — к стене, на P5; по нему — наверх (оба).
	await _push_crate(b, c1, 10.6 * TILE)
	await _crate_step_up(b, 9.0)
	await _walk_to(b, KEYS_2, 13.5 * TILE)
	await _walk_to(a, KEYS_1, 9.4 * TILE)
	await _crate_step_up(a, 9.0)
	# Живая лестница в R2 (внизу — тот, кто ближе к стене).
	await _ladder_up(b, a, 17.0, 6.0)
	# Б — обратно вниз, на P5 к ящику: P5 нажата (ящик и Б), D34 открыта.
	await _walk_to(b, KEYS_2, 9.6 * TILE, 900)
	await _land(b)
	await frames(10)
	check(p5.active, "Б с ящиком на P5 — плита для двоих нажата")
	# А везёт ящик R2 через D23 и D34 на левый край P2.
	await _push_crate(a, c0, 34.6 * TILE)
	await frames(10)
	check(p2.active, "А довёз ящик R2 на P2 (%.1f)" % (c0.global_position.x / TILE))
	# Б — по ящику обратно наверх; А — вниз в R1; живая лестница снова.
	await _crate_step_up(b, 9.0)
	await _walk_to(b, KEYS_2, 13.0 * TILE)
	await _walk_to(a, KEYS_1, 16.2 * TILE, 900)
	await _land(a)
	await _ladder_up(a, b, 17.0, 6.0)
	# А — на правый край P2; Б — между ящиком и А; Б везёт ящик обратно на P4 и встаёт на неё.
	await _walk_to(a, KEYS_1, 33.2 * TILE, 900)
	await _hop_exact(a, 36.8 * TILE)
	await _walk_to(b, KEYS_2, 33.2 * TILE, 900)
	await _hop_exact(b, 35.5 * TILE)
	await frames(10)
	check(p2.active and b.global_position.x > c0.global_position.x, "А на P2, Б за ящиком (ящик %.1f, Б %.1f, А %.1f)" % [c0.global_position.x / TILE, b.global_position.x / TILE, a.global_position.x / TILE])
	await _push_crate(b, c0, 21.9 * TILE)
	await frames(10)
	check(p4.active, "Б с ящиком на P4 — плита для двоих нажата (ящик %.1f, Б %.1f)" % [c0.global_position.x / TILE, b.global_position.x / TILE])
	# А — в R5 за третий ящик: перепрыгнуть его и вывезти в R4 левее P2; встать на P2.
	await _walk_to(a, KEYS_1, 41.0 * TILE, 900)
	await _hop_exact(a, 44.2 * TILE)
	await _push_crate(a, c2, 32.4 * TILE)
	await _walk_to(a, KEYS_1, 35.2 * TILE)
	await frames(10)
	check(p2.active and c2.global_position.x < 33.0 * TILE, "третий ящик в R4, А на P2 (ящик %.1f)" % (c2.global_position.x / TILE))
	# Б — с P4 к ящику, перепрыгнуть его и увезти на P4 ко второму: на P4 два ящика.
	await _walk_to(b, KEYS_2, 30.4 * TILE, 900)
	await _hop_exact(b, 33.6 * TILE)
	await _push_crate(b, c2, 22.9 * TILE)
	await frames(10)
	check(p4.active, "на P4 два ящика — D45 открыта без людей (ящики %.1f, %.1f)" % [c0.global_position.x / TILE, c2.global_position.x / TILE])
	# Пока А на P2 (D34 открыта), Б проходит; потом А.
	await _walk_to(b, KEYS_2, 33.6 * TILE, 900)
	await _hop_exact(b, 37.6 * TILE)
	await _walk_to(b, KEYS_2, 52.0 * TILE, 900)
	await _land(b)
	await _walk_to(a, KEYS_1, 51.0 * TILE, 900)
	await _land(a)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## Ждёт, пока угол балки (по модулю 180) войдёт в [from_deg, to_deg].
func _wait_angle(wheel: Spinner, from_deg: float, to_deg: float, limit := 900) -> void:
	for i in limit:
		var angle := fposmod(wheel.rotation_degrees, 180.0)
		if angle >= from_deg and angle <= to_deg:
			return
		await get_tree().physics_frame


## p разбегается по балке и прыгает у jump_x; в миг прыжка q встаёт на педаль pedal_x (стоит
## в 0,9 тайла от неё со стороны side); p держит «вправо» до приземления.
func _wind_jump(p: Player, q: Player, pedal_x: float, side: int, jump_x: float, lead := 1.0) -> void:
	var k := _keys(p)
	var kq := _keys(q)
	press(k[RIGHT], true)
	var jumped := false
	var started := false
	var hold := 0
	for i in 400:
		await get_tree().physics_frame
		if not started and p.global_position.x >= (jump_x - lead) * TILE:
			started = true
			press(kq[LEFT] if side > 0 else kq[RIGHT], true)  # товарищ трогается к педали чуть раньше прыжка
		if not jumped and p.global_position.x >= jump_x * TILE:
			jumped = true
			hold = 18
		press(k[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		if absf(q.global_position.x - pedal_x * TILE) < 8.0:
			press(kq[LEFT], false)
			press(kq[RIGHT], false)
		if jumped and hold == 0 and (p.is_on_floor() or not p.alive) and i > 20:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	press(kq[LEFT], false)
	press(kq[RIGHT], false)
	await frames(10)


## 05 «Ветряк» (ловкость): с вращающейся балки — в порыв мехов (педаль жмёт товарищ);
## две балки навстречу друг другу.
func _n05() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var w1: Spinner = level.get_node("Wheel1")
	await _walk_to(b, KEYS_2, 8.5 * TILE)
	await _walk_to(a, KEYS_1, 2.35 * TILE)
	await _wait_angle(w1, WIND_FROM, WIND_FROM + 3.0)
	await _wind_jump(b, a, 4.0, -1, 15.6)
	check(b.alive and b.global_position.x > 23.5 * TILE, "Б с балки в порыв — на том берегу (%s)" % b.global_position)
	if not b.alive:
		return
	await _walk_to(b, KEYS_2, 31.1 * TILE)
	await _walk_to(a, KEYS_1, 8.5 * TILE)
	await _wait_angle(w1, WIND_FROM, WIND_FROM + 3.0)
	await _wind_jump(a, b, 30.0, 1, 15.6)
	check(a.alive and a.global_position.x > 23.5 * TILE, "А с балки в порыв — на том берегу (%s)" % a.global_position)
	# 2. Длинная вращающаяся балка: прыжок на неё с края, когда она почти ровная, и с неё на берег.
	var w2: Spinner = level.get_node("Wheel2")
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 35.9 * TILE, 900)
		await _wait_angle(w2, SPIN2_FROM, SPIN2_FROM + 3.0)
		await _run_to(p, (53.0 if p == b else 52.0) * TILE)
		check(p.alive and p.global_position.x > 50 * TILE, "%s по вращающейся балке — на берег (%s)" % [p.name, p.global_position])
		if not p.alive:
			return
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## Передача на ленте: presser шагает на кнопку button_x (стоит в 0,9 тайла слева от неё), runner
## в тот же миг жмёт «вправо» и едет на развёрнутой ленте; отпускает у stop_x.
func _belt_dash(presser: Player, button_x: float, runner: Player, stop_x: float) -> void:
	var kp := _keys(presser)
	var kr := _keys(runner)
	press(kp[RIGHT], true)
	press(kr[RIGHT], true)
	var presser_done := false
	for i in 300:
		await get_tree().physics_frame
		if not presser_done and presser.global_position.x >= button_x * TILE - 6.0:
			presser_done = true
			press(kp[RIGHT], false)
		if runner.global_position.x >= stop_x * TILE or not runner.alive:
			break
	press(kp[RIGHT], false)
	press(kr[RIGHT], false)
	await frames(20)


## 07 «Смена на ленте» (скорость): эстафета на лентах, кнопка разворачивает ленту другого коридора.
func _n07() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	# А — по ступеням в верхний коридор.
	await _walk_to(a, KEYS_1, 2.9 * TILE)
	await _hop_to(a, 1.8 * TILE)
	await _hop_to(a, 3.9 * TILE)
	await _hop_to(a, 6.0 * TILE)
	check(a.global_position.y < 7 * TILE, "А в верхнем коридоре (%s)" % a.global_position)
	await _walk_to(a, KEYS_1, 7.3 * TILE)
	await _walk_to(b, KEYS_2, 6.1 * TILE)
	# Передачи: (кто жмёт, кнопка, кто бежит, докуда; потом бегущий встаёт у кнопки, жмущий — к старту ленты).
	var steps := [[b, 7.0, a, 16.4], [a, 18.2, b, 18.4], [b, 20.2, a, 28.4], [a, 30.2, b, 30.4],
			[b, 32.2, a, 40.4], [a, 42.2, b, 42.4], [b, 44.2, a, 52.4], [a, 54.2, b, 54.4]]
	var starts := {a: [19.4, 31.4, 43.4], b: [9.4, 21.4, 33.4, 45.4]}
	await _walk_to(b, KEYS_2, 6.1 * TILE)
	for n in steps.size():
		var presser: Player = steps[n][0]
		var runner: Player = steps[n][2]
		if n > 0:
			# бегущий — к началу своей ленты, жмущий — в 0,9 тайла от своей кнопки
			var runner_start: float = starts[runner][0]
			starts[runner].pop_front()
			await _walk_to(runner, _keys(runner), (runner_start) * TILE)
			await _walk_to(presser, _keys(presser), (steps[n][1] - 0.9) * TILE)
		await _belt_dash(presser, steps[n][1], runner, steps[n][3])
		check(runner.alive and runner.global_position.x > (steps[n][3] - 0.5) * TILE, "%d: %s пронёсся по ленте (%s)" % [n + 1, runner.name, runner.global_position])
		if not runner.alive:
			return
	# Выход: верхняя и нижняя красные — в одно окно.
	await _walk_to(a, KEYS_1, 54.5 * TILE)
	await _walk_to(b, KEYS_2, 55.7 * TILE)
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	for i in 40:
		await get_tree().physics_frame
		press(KEYS_1[RIGHT], a.global_position.x < 55.4 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 56.6 * TILE)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	await frames(40)
	check((level.get_node("Exit") as Door).get("_latched"), "обе красные в окно — выход открыт")
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## Фаза пилы на ходу вверх-вниз: 0 — у начала пути, 1 — у конца, 2 — снова у начала.
func _saw_cycle(saw: Saw) -> float:
	return saw.progress if saw.forward else 2.0 - saw.progress


## 08 «Кран над настилом» (ловкость): Б на крюке; А включает рычаг (кран едет) и в прыжке ловит
## Б за руку; цепь проезжает над пилой в такт; над ломким настилом — вниз по одному и на берег.
func _n08() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var hook: Hook = (level.get_node("Crane") as Crane).hook
	var saw: Saw = level.get_node("Saw")
	var brittle: Node = level.get_node("Brittle")
	# Б — на крюк.
	await _walk_to(b, KEYS_2, hook.global_position.x)
	press(KEYS_2[GRAB], true)
	press(KEYS_2[JUMP], true)
	for i in 40:
		await get_tree().physics_frame
		if b.grab_target == hook:
			break
	press(KEYS_2[JUMP], false)
	check(b.grab_target == hook, "Б на крюке")
	await frames(60)
	# А — к рычагу; ждёт такта пилы и включает кран.
	await _walk_to(a, KEYS_1, 4.9 * TILE)
	for i in 900:
		var c := _saw_cycle(saw)
		if c > CRANE_SAW_FROM and c < CRANE_SAW_FROM + 0.05:
			break
		await get_tree().physics_frame
	await hold(KEYS_1[GRAB], 4)
	check((level.get_node("Lever") as Lever).active, "А включил кран")
	# А забегает вперёд и, когда Б над ним, прыгает вверх с хватом — ловит Б за руку.
	await _walk_to(a, KEYS_1, CATCH_X * TILE)
	for i in 600:
		if b.global_position.x > a.global_position.x - 8.0:
			break
		await get_tree().physics_frame
	press(KEYS_1[GRAB], true)
	press(KEYS_1[JUMP], true)
	for i in 40:
		await get_tree().physics_frame
		if a.grab_target == b:
			break
	press(KEYS_1[JUMP], false)
	check(a.grab_target == b or a.grab_target == hook, "А в прыжке поймал Б за руку или крюк (a %s b %s)" % [a.global_position, b.global_position])
	# Едут до конца рельса.
	for i in 1200:
		if hook.velocity.x == 0.0 and hook.global_position.x > 27.0 * TILE or not a.alive or not b.alive:
			break
		await get_tree().physics_frame
	await frames(40)
	check(a.alive and b.alive, "цепь проехала под пилой (a %s)" % a.global_position)
	if not a.alive or not b.alive:
		return
	# Нижний — вниз на настил и на берег; потом верхний.
	press(KEYS_1[GRAB], false)
	await _land(a)
	await _run_to(a, 34.0 * TILE)
	check(a.alive and a.global_position.x > 32 * TILE, "А с настила — на берег (%s)" % a.global_position)
	press(KEYS_2[GRAB], false)
	await _land(b)
	await _run_to(b, 35.0 * TILE)
	check(b.alive and b.global_position.x > 32 * TILE and not brittle.broken, "Б следом — настил цел (%s)" % b.global_position)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


# --- 09–20: очень сложные ---------------------------------------------------------------------

## 09 «Бегущий фитиль» (скорость): защёлка открывает дверь и шлёт искру к бочонку под мостом —
## перейти мост, пока он цел; на втором мосту — дверь на кнопках-импульсах.
func _n09() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var bridge1: Node = level.get_node("Bridge1")
	var bridge2: Node = level.get_node("Bridge2")
	await _walk_to(a, KEYS_1, 3.0 * TILE)
	await _walk_to(b, KEYS_2, 6.0 * TILE)
	var t0 := Engine.get_physics_frames()
	_run_dodging(b, KEYS_2, 28.5)
	await frames(8)
	await _run_dodging(a, KEYS_1, 27.5)
	await frames(20)
	var crossed := Engine.get_physics_frames() - t0
	for i in 900:
		if bridge1.smashed:
			break
		await get_tree().physics_frame
	print("      мост 1: перешли за %.2f с, взорван через %.2f с" % [crossed / 60.0, (Engine.get_physics_frames() - t0) / 60.0])
	check(deaths == before and a.global_position.x > 26 * TILE and b.global_position.x > 26 * TILE and bridge1.smashed,
			"мост 1 перейдён до взрыва (a %s b %s)" % [a.global_position, b.global_position])
	# Этап 2: Б жмёт защёлку и бежит к двери; А — на кнопку перед дверью; Б — за дверь на свою кнопку; А — следом.
	await _walk_to(a, KEYS_1, 33.0 * TILE)
	await _walk_to(b, KEYS_2, 34.0 * TILE)
	t0 = Engine.get_physics_frames()
	_walk_to(b, KEYS_2, 45.6 * TILE)
	await frames(10)
	await _walk_to(a, KEYS_1, 41.1 * TILE)
	for i in 120:
		if b.global_position.x >= 45.3 * TILE:
			break
		await get_tree().physics_frame
	_walk_to(a, KEYS_1, 42.0 * TILE)
	await frames(6)
	await _run_plain(b, KEYS_2, 49.4)
	_walk_to(b, KEYS_2, 50.5 * TILE)
	await frames(6)
	await _run_plain(a, KEYS_1, 49.0)
	check(a.global_position.x > 48 * TILE and b.global_position.x > 48 * TILE, "дверь на мосту 2: передача через кнопки (a %s b %s)" % [a.global_position, b.global_position])
	_run_dodging(b, KEYS_2, 60.5)
	await frames(8)
	await _run_dodging(a, KEYS_1, 59.5)
	await frames(20)
	crossed = Engine.get_physics_frames() - t0
	for i in 900:
		if bridge2.smashed:
			break
		await get_tree().physics_frame
	print("      мост 2: перешли за %.2f с, взорван через %.2f с" % [crossed / 60.0, (Engine.get_physics_frames() - t0) / 60.0])
	check(deaths == before and a.global_position.x > 58 * TILE and b.global_position.x > 58 * TILE and bridge2.smashed,
			"мост 2 перейдён до взрыва (a %s b %s)" % [a.global_position, b.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


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


## Бег вправо до x (в тайлах) без прыжков.
func _run_plain(p: Player, k: Array[Key], x: float) -> void:
	press(k[RIGHT], true)
	for i in 240:
		await get_tree().physics_frame
		if p.global_position.x >= x * TILE or not p.alive:
			break
	press(k[RIGHT], false)
	await frames(10)


## Где сейчас препятствие: жук — его центр, пила — диск на рельсе.
func _obstacle_x(o: Node2D) -> float:
	if o is Saw:
		return o.global_position.x + o.path_tiles.x * TILE * o.progress
	return o.global_position.x


## Бег вправо до x (тайлы) по лентам с жуками и пилами: прыгает через жука или пилу, когда до встречи
## ≈ lead_s, через упёршегося в него жука и через щель у края опоры.
func _run_beetles(p: Player, x: float, lead_s := 0.12) -> void:
	var k := _keys(p)
	var space := p.get_world_2d().direct_space_state
	var obstacles: Array = game.level.find_children("*", "Beetle", true, false)
	for sw: Saw in game.level.find_children("*", "Saw", true, false):
		if sw.path_tiles.x != 0.0:
			obstacles.append(sw)
	var last := {}
	for o: Node2D in obstacles:
		last[o] = _obstacle_x(o)
	var last_p := p.global_position.x
	var hold := 0
	press(k[RIGHT], true)
	for i in 1500:
		await get_tree().physics_frame
		var pv := (p.global_position.x - last_p) * 60.0
		last_p = p.global_position.x
		var jump := false
		if p.is_on_floor() and hold == 0:
			var ahead := p.global_position + Vector2(30.0, 0.0)
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 80.0), Player.LAYER_WORLD, [p.get_rid()])
			if space.intersect_ray(query).is_empty() or p.is_on_wall():
				jump = true
			for o: Node2D in obstacles:
				var ox := _obstacle_x(o)
				var ov: float = (ox - last[o]) * 60.0
				var dx: float = ox - p.global_position.x
				var closing := pv - ov
				if dx <= 0.0 or absf(o.global_position.y - p.global_position.y) > 48.0:
					continue
				if closing > 20.0 and (dx - 60.0) / closing < lead_s:
					jump = true
				if dx < 90.0 and absf(closing) <= 20.0:
					jump = true  # упёрся в того, кто едет вровень, — через него
		for o: Node2D in obstacles:
			last[o] = _obstacle_x(o)
		if jump:
			hold = 16
		press(k[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		if p.global_position.x >= x * TILE or not p.alive:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## 11 «Жуки на ленте» (ловкость): ленты над шипами, жуков — перепрыгивать.
func _n11() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	const D := 3.5  # части 2–3 сдвинуты вправо (tools/levels/w02_l11_beetle_belts.py)
	var bump1: Beetle = level.get_node("Bump1")
	var saw1: Node2D = level.get_node("Saw1")
	var lever1: Lever = level.get_node("Lever1")
	var plate1_x: float = (level.get_node("Plate1") as Node2D).global_position.x
	# 1. А держит плиту, перепрыгивая броски отбойника; Б ждёт у шипов (жуку туда не пройти),
	# пока жук отвернётся, — и в дверь, мимо пилы, к рычагу.
	await _dash(a, plate1_x - 0.3 * TILE, [bump1])
	var hold1 := [false]
	_hold_plate(a, plate1_x, [bump1], hold1)
	await _dash(b, 5.4 * TILE, [])  # ждёт с разбегом до шипов
	await _until(func() -> bool: return bump1.direction == 1 and bump1.mode == Beetle.Mode.WALK and bump1.global_position.x > 13.0 * TILE, 900)
	await _dash(b, lever1.global_position.x - 0.3 * TILE, [bump1, saw1, a])
	check(b.alive and b.global_position.x > 26 * TILE, "Б прошёл дверь и коридор с пилой (%s)" % b.global_position)
	await hold(KEYS_2[GRAB], 4)
	await frames(10)
	check(lever1.active, "Б дёрнул рычаг — дверь открыта насовсем")
	# Дверь заперта рычагом; А сходит с плиты, когда жук ушёл за спину и идёт прочь.
	# Просвет: жук только что пронёсся влево под А — пока доедет до шипов и развернётся, А уже за дверью.
	await _until(func() -> bool: return bump1.direction == -1 and bump1.mode == Beetle.Mode.CHARGE and bump1.global_position.x < a.global_position.x - 0.6 * TILE, 1500)
	hold1[0] = true
	await _land(a)
	check(a.alive, "А удержал плиту под бросками отбойника")
	await _dash(a, (26.0 + D) * TILE, [saw1])  # без остановки: жук у дальних шипов не догонит
	check(a.alive and a.global_position.x > (25 + D) * TILE, "А догнал Б (%s)" % a.global_position)
	# 2. Ступенька в воздухе: А замирает над ямой, Б с его головы — на берег, на плиту; мост под А.
	var bump2: Beetle = level.get_node("Bump2")
	var bridge: Node2D = level.get_node("Bridge")
	var plate2_x: float = (level.get_node("Plate2") as Node2D).global_position.x
	# Прыгать, когда жук на том берегу уходит от края: пока ступенька и прыжок — он далеко.
	await _until(func() -> bool: return bump2.direction == 1 and bump2.mode == Beetle.Mode.WALK and bump2.global_position.x < (40.0 + D) * TILE, 1500)
	var stepped: bool = await _air_step(a, KEYS_1, b, KEYS_2, (28.0 + D) * TILE, (34.0 + D) * TILE, 12.0 * TILE, 40.0, 250.0)
	check(stepped, "ступенька в воздухе: Б с головы замершего А на тот берег (%s)" % b.global_position)
	await _dash(b, plate2_x - 0.3 * TILE, [bump2])
	var hold2 := [false]
	_hold_plate(b, plate2_x, [bump2], hold2)
	await _until(func() -> bool: return bridge.position.x < (28.3 + D) * TILE, 300)
	check(bridge.position.x < (28.3 + D) * TILE, "мост выдвинулся под замершим А")
	tap(KEYS_1[FREEZE])
	await _land(a)
	await _dash(a, (43.9 + D) * TILE, [bump2, b])  # с запасом до ямы: прыжок через жука проносит дальше
	check(a.alive and a.global_position.x > (43.4 + D) * TILE, "А по мосту и мимо отбойника (%s)" % a.global_position)
	# 3. Эскалатор: прыжками против ленты, через отбойников навстречу, — в закуток (оттуда жук не видит).
	# На ленту — когда оба бегуна только что упали в яму: лента пуста, пока они не вернутся. На берегу
	# бродит отбойник: ждать, перепрыгивая его броски. Б держит плиту, пока А не на ленте.
	var runners := [level.get_node("Runner1"), level.get_node("Runner2")]
	var belt_clear := func() -> bool: return runners.all(func(r: Beetle) -> bool: return r.mode == Beetle.Mode.GONE)
	for p: Player in [a, b]:
		if p == b:
			hold2[0] = true
			await frames(5)
			await _dash(b, (42.6 + D) * TILE, [bump2])
			check(b.alive and b.global_position.x > (42.1 + D) * TILE, "Б сошёл с плиты и догнал (%s)" % b.global_position)
		var waiting := [false]
		_hold_plate(p, p.global_position.x, [bump2], waiting)
		await _until(belt_clear, 900)
		waiting[0] = true
		await frames(2)
		await _belt_hops(p, (61.7 if p == a else 61.25) * TILE, (44.7 + D) * TILE, (47.4 + D) * TILE)
		check(p.alive and p.global_position.x > 61.0 * TILE, "%s пропрыгал эскалатор в закуток (%s)" % [p.name, p.global_position])
	# Подход к уступу сокращён телепортом (уворот от броска проверен в частях 1–2): когда жук уходит
	# к закутку, А — у стены уступа и замирает лестницей; Б по нему — наверх.
	var bump3: Beetle = level.get_node("Bump3")
	var wall_x := (62.0 + D) * TILE
	await _until(func() -> bool: return bump3.direction == -1 and bump3.mode == Beetle.Mode.WALK and bump3.global_position.x < wall_x - 1.6 * TILE, 900)
	place(a, Vector2(wall_x - 0.65 * TILE, _stand_y(11.0)))
	await frames(4)
	tap(KEYS_1[FREEZE])
	await _onto_head(b, a)
	await _hop_to(b, wall_x + 1.4 * TILE)
	check(b.alive and b.global_position.y < 8 * TILE, "Б с головы А на уступ (%s)" % b.global_position)
	# А оживает, когда жук ушёл к закутку: тот развернётся, увидит, бросится — замереть в последний миг.
	if bump3.global_position.x > a.global_position.x:
		# жук зажат между замершим А и стеной: сам бросится на А и оглушится — не оживать
		await _until(func() -> bool: return bump3.mode == Beetle.Mode.DAZED, 900)
	else:
		await _until(func() -> bool: return bump3.direction == -1 and bump3.mode == Beetle.Mode.WALK and a.global_position.x - bump3.global_position.x > 1.4 * TILE, 900)
		tap(KEYS_1[FREEZE])
		await _until(func() -> bool: return bump3.mode == Beetle.Mode.CHARGE and absf(bump3.global_position.x - a.global_position.x) < 110.0, 900)
		tap(KEYS_1[FREEZE])
	await _until(func() -> bool: return bump3.mode == Beetle.Mode.DAZED, 120)
	check(bump3.mode == Beetle.Mode.DAZED, "бросальщик врезался в замершего в последний миг А")
	tap(KEYS_1[FREEZE])
	for attempt in 3:  # на оглушённого жука: промахнулся — ещё раз, пока он оглушён
		await _hop_exact(a, bump3.global_position.x + 8.0)
		if Weight.floor_below(a) == bump3 or bump3.mode != Beetle.Mode.DAZED:
			break
	await _hop_to(a, wall_x + 1.6 * TILE)
	check(a.alive and a.global_position.y < 8 * TILE, "А с оглушённого жука на уступ (%s)" % a.global_position)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	if deaths > before:
		return
	await _n11_corral()
	await _both_to_finish()


## Стоит на месте; жук идёт навстречу и вот-вот толкнёт — замереть (он развернётся), ушёл — ожить.
func _freeze_guard(p: Player, beetle: Beetle, stop: Array) -> void:
	var k := _keys(p)
	while not stop[0] and p.alive:
		await get_tree().physics_frame
		var gap := beetle.global_position.x - p.global_position.x
		var coming := signf(gap) == -float(beetle.direction)
		if not p.frozen and coming and absf(gap) < 1.35 * TILE and p.is_on_floor():
			tap(k[FREEZE])
		elif p.frozen and not coming and absf(gap) > 1.2 * TILE:
			tap(k[FREEZE])
	if p.frozen:
		tap(k[FREEZE])


## 11, часть 4 «Загон»: весы на 3 держат дверь. Б перепрыгивает к ящику у двери и, когда жук слева,
## придвигает ящик к правому краю весов; А идёт за жуком и замирает на левом краю — жук заперт на весах
## (ящик + жук + А), дверь открыта. Б — в дверь, через яму, вверх по встречной ленте (когда бегун упал
## в яму) — к рычагу. А оживает и идёт следом.
func _n11_corral() -> void:
	const D := 3.5
	var level: GreyboxLevel = game.level
	var before := deaths
	var walker: Beetle = level.get_node("Walker4")
	var crate: Crate = level.get_node("Crate4")
	var door: Door = level.get_node("Door4")
	var lever: Lever = level.get_node("Lever4")
	var runner: Beetle = level.get_node("Runner4")
	var plate: PressurePlate = level.get_node("Plate4")
	await _dash(b, (75.2 + D) * TILE, [walker, crate])  # через жука и ящик — к двери
	check(b.global_position.x > crate.global_position.x, "Б за ящиком у двери (%s)" % b.global_position)
	# А ждёт на уступе: тихоход толкает — спихнул бы вниз; подошёл — замереть, и он развернётся
	await _walk_to(a, KEYS_1, (63.0 + D) * TILE)
	var guard := [false]
	_freeze_guard(a, walker, guard)
	await _until(func() -> bool: return walker.direction == -1 and walker.global_position.x < (68.8 + D) * TILE and walker.global_position.x > a.global_position.x - 0.5 * TILE, 1500)
	await _push_crate(b, crate, (71.5 + D) * TILE)
	check(crate.global_position.x < (71.7 + D) * TILE and walker.global_position.x < crate.global_position.x,
			"ящик на правом краю весов, жук слева (ящик %.2f, жук %.2f)" % [crate.global_position.x / TILE, walker.global_position.x / TILE])
	# А — за жуком, пока тот идёт к ящику; жук развернулся — замереть на левом краю весов
	await _until(func() -> bool: return walker.direction == 1 and walker.global_position.x > (66.4 + D) * TILE and not a.frozen, 900)
	guard[0] = true
	await frames(2)
	for i in 500:
		await get_tree().physics_frame
		var gap := walker.global_position.x - a.global_position.x
		var go := gap > 1.08 * TILE and a.global_position.x < (69.45 + D) * TILE
		press(KEYS_1[RIGHT], go)

		if a.global_position.x >= (68.95 + D) * TILE and walker.direction == -1:
			break
	press(KEYS_1[RIGHT], false)
	press(KEYS_1[JUMP], false)
	await _land(a)
	tap(KEYS_1[FREEZE])
	await frames(90)
	check(a.frozen and Weight.floor_below(a) == plate and Weight.floor_below(walker) == plate and plate.active and door.position.y < door.get("_closed_position").y - 3.0 * TILE,
			"жук заперт между замершим А и ящиком — на весах трое, дверь открыта (жук %.2f)" % (walker.global_position.x / TILE))
	await _walk_to(b, KEYS_2, (76.9 + D) * TILE)
	check(b.alive and b.global_position.x > (76.6 + D) * TILE, "Б прошёл дверь (%s)" % b.global_position)
	await _until(func() -> bool: return runner.mode == Beetle.Mode.GONE, 900)
	await _belt_hops(b, (90.0 + D) * TILE, (76.9 + D) * TILE, (79.0 + D) * TILE)
	check(b.alive and b.global_position.x > (89.5 + D) * TILE, "Б пропрыгал встречную ленту (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, lever.global_position.x)
	await hold(KEYS_2[GRAB], 4)
	await frames(10)
	check(lever.active, "Б дёрнул рычаг — дверь открыта насовсем")
	await _walk_to(b, KEYS_2, (91.5 + D) * TILE)
	# А оживает: через жука и ящик — в дверь, через яму, по ленте
	tap(KEYS_1[FREEZE])
	await frames(3)
	await _dash(a, (76.9 + D) * TILE, [walker, crate])
	await _until(func() -> bool: return runner.mode == Beetle.Mode.GONE, 900)
	await _belt_hops(a, (90.5 + D) * TILE, (76.9 + D) * TILE, (79.0 + D) * TILE)
	check(deaths == before and a.global_position.x > (89.5 + D) * TILE, "загон пройден (a %s b %s)" % [a.global_position, b.global_position])


func _dbg11() -> void:  # DBG
	for i in 1500:
		await get_tree().physics_frame
		if i % 4 == 0:
			var t := ""
			for bt: Beetle in game.level.find_children("*", "Beetle", true, false):
				if bt.name != "Bump1" and bt.name != "Bump3":
					t += " %s %.2f,%.2f m%d d%d" % [bt.name, bt.global_position.x / TILE, bt.global_position.y / TILE, bt.mode, bt.direction]
			print("DBG %d a %.2f,%.2f fl %s b %.2f,%.2f%s" % [i, a.global_position.x / TILE, a.global_position.y / TILE, a.is_on_floor(), b.global_position.x / TILE, b.global_position.y / TILE, t])


## Держит плиту у x, перепрыгивая жуков, которые на него несутся; до stop[0].
func _hold_plate(p: Player, x: float, threats: Array, stop: Array) -> void:
	var k := _keys(p)
	var jump := 0
	# сигнал «бежать» посреди прыжка — прыжок довести (иначе подскок, и пила/жук достанут)
	while (not stop[0] or jump > 0) and p.alive:
		var dx := x - p.global_position.x
		press(k[RIGHT], dx > 12.0 and not stop[0])
		press(k[LEFT], dx < -12.0 and not stop[0])
		if p.is_on_floor() and jump == 0 and not stop[0]:
			for t: Saw in threats.filter(func(n: Node) -> bool: return n is Saw):
				# пила над плитой: несётся навстречу — перепрыгнуть
				var bx := t.blade_position().x
				var vx := (1.0 if t.forward else -1.0) * t.speed * signf(t.path_tiles.x)
				var srel := bx - p.global_position.x
				var sclose := -signf(srel) * vx
				if sclose > 0.0 and absf(srel) < 59.0 + sclose * 0.2 and absf(t.blade_position().y - p.global_position.y) < 80.0:
					jump = 22
			for t: Beetle in threats.filter(func(n: Node) -> bool: return n is Beetle):
				var rel := t.global_position.x - p.global_position.x
				var closing := -signf(rel) * t.velocity.x
				var near := absf(t.global_position.y - p.global_position.y) < 80.0
				# Несётся навстречу — прыжок; замахивается рядом — прыжок заранее, бросок пройдёт под ним.
				var charging := closing > 60.0 and absf(rel) < 70.0 + closing * 0.2
				var winding := t.mode == Beetle.Mode.WINDUP and absf(rel) < 110.0 and t.direction * rel < 0.0
				if near and (charging or winding):
					jump = 22  # бросок виден заранее («!» и замах) — человек готов, запаздывания нет
		press(k[JUMP], jump > 0)
		jump = maxi(jump - 1, 0)
		await get_tree().physics_frame
	for key in [k[LEFT], k[RIGHT], k[JUMP]]:
		press(key, false)


## Рывок к target_x: перепрыгивает ямы, шипы и угрозы на пути (жуки, пилы).
func _dash(p: Player, target_x: float, threats: Array, max_frames := 900) -> void:
	target_x += _jit(16.0)
	var dir := 1 if target_x > p.global_position.x else -1
	var k := _keys(p)
	var key := k[RIGHT] if dir > 0 else k[LEFT]
	var space := p.get_world_2d().direct_space_state
	var jump := 0
	var last := {}  # угроза → прошлое положение: скорость по смещению
	var mate := b if p == a else a
	press(key, true)
	for i in max_frames:
		if (p.global_position.x - target_x) * dir >= 0.0 or not p.alive:
			break
		var speed := {}
		var at := {}  # где угроза: у пилы — диск, а не начало рельса
		for t: Node2D in threats:
			at[t] = (t as Saw).blade_position() if t is Saw else t.global_position
			speed[t] = (at[t].x - last.get(t, at[t].x)) * 60.0
			last[t] = at[t].x
			if t is Beetle and t.mode == Beetle.Mode.WINDUP:
				speed[t] = t.direction * t.charge_speed  # вот-вот бросится
			if t is Saw:
				# у конца рельса пила вот-вот развернётся — считать по скорости после разворота
				var saw: Saw = t
				var rail_end: Vector2 = saw.global_position + (saw.path_tiles * TILE if saw.forward else Vector2.ZERO)
				if absf(rail_end.x - float(at[t].x)) < 0.5 * TILE and saw.path_tiles.x != 0.0:
					speed[t] = -(1.0 if saw.forward else -1.0) * saw.speed * signf(saw.path_tiles.x)
		if p.is_on_floor() and jump > 0 and jump < 14 and p.velocity.y >= 0.0:
			jump = 0  # приземлился — готов к новому прыжку
		# Пила впереди уезжает туда же — не догонять: подождать, пока развернётся навстречу.
		var hold_back := false
		for t: Node2D in threats:
			if t is Saw:
				var srel := (float(at[t].x) - p.global_position.x) * dir
				if srel > 0.0 and srel < 3.2 * TILE and float(speed[t]) * dir > 20.0 and p.is_on_floor():
					hold_back = true
		press(key, not hold_back)
		if p.is_on_floor() and jump == 0:
			# Стена уровня впереди (ступенька) — прыжок; товарищ — отдельно ниже.
			var wall_q := PhysicsRayQueryParameters2D.create(p.global_position + Vector2(0, 14.0),
					p.global_position + Vector2(dir * 44.0, 14.0), Player.LAYER_WORLD, [p.get_rid()])
			var want := not space.intersect_ray(wall_q).is_empty()
			var ahead := p.global_position + Vector2(36.0 * dir, 0.0)
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 100.0),
					Player.LAYER_WORLD | Crate.LAYER_OBJECTS | Player.LAYER_PLAYERS, [p.get_rid()])
			want = want or space.intersect_ray(query).is_empty()
			var feet := Rect2(p.global_position + Vector2(dir * 44.0 - 12.0, Player.SIZE.y / 2.0 - 12.0), Vector2(36.0, 14.0))
			for sp in get_tree().get_nodes_in_group(Spikes.GROUP):
				want = want or sp.get_rect().intersects(feet)
			for t: Node2D in threats:
				var pos: Vector2 = at[t]
				var rel := (pos.x - p.global_position.x) * dir
				var closing := 360.0 - float(speed[t]) * dir
				var away := t is Saw and float(speed[t]) * dir > 20.0  # уезжающую пилу не перепрыгивать — ждать
				if rel > 0.0 and rel < 60.0 + closing * 0.18 and absf(pos.y - p.global_position.y) < 80.0 and not away:
					want = true
			# Стоящий впереди товарищ — перепрыгнуть.
			var mrel := (mate.global_position.x - p.global_position.x) * dir
			if mrel > 0.0 and mrel < 70.0 and absf(mate.global_position.y - p.global_position.y) < 30.0:
				want = true
			if want:
				jump = 20
		press(k[JUMP], jump > 0)
		jump = maxi(jump - 1, 0)
		await get_tree().physics_frame
	press(key, false)
	press(k[JUMP], false)
	await _land(p)  # следующий шаг — с земли, а не в полёте
	await frames(8)


## Ждёт, пока cond() не станет true (до limit кадров).
func _until(cond: Callable, limit := 600) -> void:
	for i in limit:
		if cond.call():
			await _react()
			return
		await get_tree().physics_frame


## Против ленты — прыжками без остановки: на земле сразу новый прыжок (до ленты — разбег до jump_x,
## лента начинается с belt_x). Цель — правее target_x.
func _belt_hops(p: Player, target_x: float, jump_x: float, belt_x: float) -> void:
	var k := _keys(p)
	press(k[RIGHT], true)
	var grounded := 0
	var wait := 0
	for i in 900:
		if p.global_position.x >= target_x or not p.alive:
			break
		var on_belt := p.global_position.x > belt_x - 0.5 * TILE
		grounded = grounded + 1 if p.is_on_floor() else 0
		if grounded == 1:
			wait = rng.randi_range(0, 5) if human else 0
		press(k[JUMP], grounded > wait and (on_belt or p.global_position.x > jump_x + _jit(10.0)))
		await get_tree().physics_frame
	press(k[RIGHT], false)
	press(k[JUMP], false)
	await frames(10)


## Насколько обвал позади отставшего (тайлы) — для строк отчёта.
func _crusher_lag() -> String:
	if not game.level.has_node("Crusher"):
		return ""
	var crusher: Crusher = game.level.get_node("Crusher")
	return "; обвал в %.1f тайла" % ((minf(a.global_position.x, b.global_position.x) - crusher.global_position.x) / TILE)


## 12 «Цех под обвалом» (скорость): два этажа, сзади обвал. А бежит наверху, Б внизу — каждый со своими
## пилами, жуками и осыпями. Двери на этаже держат плиты на другом: оба встают на свои плиты — и разом в двери.
## Посередине пол верхнего осыпается: А падает вниз и поднимается обратно взведённой пружиной.
func _n12() -> void:
	var before := deaths
	var done := {}
	_n12_upper(a, done)
	_n12_lower(b, done)
	await _until(func() -> bool: return done.size() == 2 or not a.alive or not b.alive, 3600)
	check(done.size() == 2, "оба добежали до конца цеха (a %s b %s)%s" % [a.global_position, b.global_position, _crusher_lag()])
	check((game.level.get_node("Crusher2") as Crusher).active, "второй обвал гнал за розовыми дверями")
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


func _n12_upper(p: Player, done: Dictionary) -> void:
	var level: GreyboxLevel = game.level
	var bump: Beetle = level.get_node("BumpU")
	await _to_plate(p, "U", 1, [level.get_node("SawU1")])
	await _to_plate(p, "U", 2, [bump])
	check(p.alive and p.global_position.x > 31 * TILE, "А мимо пилы, в жёлтую дверь, по осыпи — у синей плиты (%s)%s" % [p.global_position, _crusher_lag()])
	await _dash(p, 42.0 * TILE, [b, bump])
	check(p.alive and p.global_position.y > (U12 + 1.0) * TILE, "А в синюю дверь — под ним осыпалось перекрытие (%s)" % p.global_position)
	await _pad_up(p, level.get_node("Pad"))
	check(p.alive and p.global_position.y < U12 * TILE, "А взведённой пружиной — обратно наверх (%s)%s" % [p.global_position, _crusher_lag()])
	await _to_plate(p, "U", 3, [])
	await _to_plate(p, "U", 4, [level.get_node("SawU2")])
	check(p.alive and p.global_position.x > 60 * TILE, "А в зелёную дверь, мимо пилы, по осыпи — у фиолетовой плиты (%s)%s" % [p.global_position, _crusher_lag()])
	await _dash(p, 65.9 * TILE, [])  # верхний этаж обрывается — вниз, ко второму батуту
	await _pad_up(p, level.get_node("Pad2"))
	check(p.alive and p.global_position.y < U12 * TILE, "А второй пружиной — снова наверх (%s)%s" % [p.global_position, _crusher_lag()])
	await _to_plate(p, "U", 5, [level.get_node("SawU5")])
	await _to_plate(p, "U", 6, [level.get_node("SawU5"), level.get_node("BumpU6")])
	check(p.alive and p.global_position.x > 89 * TILE, "А мимо пилы над плитой, по осыпи — у бирюзовой плиты, отбойник рядом (%s)%s" % [p.global_position, _crusher_lag()])
	await _dash(p, 97.5 * TILE, [level.get_node("BumpU6")])
	await _dash(p, 101.8 * TILE, [])  # внизу — через яму к выходу
	done[p] = true


func _n12_lower(p: Player, done: Dictionary) -> void:
	var level: GreyboxLevel = game.level
	await _to_plate(p, "L", 1, [])
	await _to_plate(p, "L", 2, [level.get_node("SawL")])
	check(p.alive and p.global_position.x > 33 * TILE, "Б по мостку, в жёлтую дверь, мимо пилы, по мостку — у синей плиты (%s)%s" % [p.global_position, _crusher_lag()])
	await _to_plate(p, "L", 3, [a])
	var bump: Beetle = level.get_node("BumpL")
	await _to_plate(p, "L", 4, [bump])
	check(p.alive and p.global_position.x > 61 * TILE, "Б в зелёную дверь, через отбойника и яму — у фиолетовой плиты (%s)%s" % [p.global_position, _crusher_lag()])
	await _dash(p, 64.9 * TILE, [bump])
	# ждёт, пока А взлетит со второго батута, и — через батут к своей плите
	await _until(func() -> bool: return a.global_position.x > 66.0 * TILE and a.global_position.y < U12 * TILE or not a.alive, 1200)
	await _to_plate(p, "L", 5, [level.get_node("SawL5")])
	await _to_plate(p, "L", 6, [level.get_node("SawL5"), level.get_node("SawL6")])
	check(p.alive and p.global_position.x > 89 * TILE, "Б по мостку — у бирюзовой плиты под пилой (%s)%s" % [p.global_position, _crusher_lag()])
	await _dash(p, 102.0 * TILE, [level.get_node("SawL6")])
	done[p] = true


const U12 := 7.0  # пол верхнего этажа (12)


## Пара дверей (12): через прошлую дверь — к своей плите пары n на этаже floor ("U"/"L"); стоять на ней
## (перепрыгивая жуков), пока товарищ не встанет на свою, — тогда своя дверь открывается: можно бежать.
func _to_plate(p: Player, floor: String, n: int, threats: Array) -> void:
	var level: GreyboxLevel = game.level
	var plate: Node2D = level.get_node("Plate%s%d" % [floor, n])
	var door: Door = level.get_node("Door%s%d" % [floor, n])
	await _dash(p, plate.global_position.x - 0.2 * TILE, threats)
	if not p.alive:
		return
	var stop := [false]
	_hold_plate(p, plate.global_position.x, threats, stop)
	await _until(func() -> bool: return door.is_open_requested() or not p.alive, 900)
	stop[0] = true
	await get_tree().physics_frame
	await _until(func() -> bool: return p.is_on_floor() or not p.alive, 90)


## Взведённая пружина в одиночку: встать на батут, замереть, ожить — и, держа вправо, на перекрытие.
func _pad_up(p: Player, pad: SpringPad) -> void:
	var k := _keys(p)
	await _walk_to(p, k, pad.global_position.x)
	place(p, Vector2(pad.global_position.x + _jit(6.0), pad.global_position.y - SpringPad.HEIGHT - Player.SIZE.y / 2.0 - 1.0))
	await frames(6)
	tap(k[FREEZE])
	await frames(5)
	check(pad.is_charged(), "%s замер на батуте — пружина взведена" % p.name)
	await _react()
	tap(k[FREEZE])
	press(k[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		if i > 10 and p.is_on_floor():
			break
	press(k[RIGHT], false)
	await frames(4)


## Прыжки по батутам: с места прыжок к первой цели, после каждого отскока — руль к следующей
## (targets — x в тайлах); последняя цель — уступ, ждёт приземления на него.
func _pogo(p: Player, targets: Array) -> void:
	var k := _keys(p)
	var index := 0
	var was_falling := false
	press(k[JUMP], true)
	for i in 600:
		await get_tree().physics_frame
		if i == 12:
			press(k[JUMP], false)
		if not p.alive:
			break
		# отскок: падал — и вдруг летит вверх
		if was_falling and p.velocity.y < -200.0 and index < targets.size() - 1:
			index += 1
		was_falling = p.velocity.y > 50.0
		var dx: float = targets[index] * TILE - p.global_position.x
		press(k[RIGHT], dx > 8.0)
		press(k[LEFT], dx < -8.0)
		if index == targets.size() - 1 and p.is_on_floor() and absf(dx) < 40.0:
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(10)


## 14 «Пружинный цирк» (ловкость): две трапеции разом над пилами; батуты на столбах; взведённая
## пружина на трапецию и с неё — на уступ выхода.
func _n14() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	# 1. Две трапеции: каждый на своей, свои пилы.
	var top: Mover = level.get_node("TrapezeU")
	var low: Mover = level.get_node("TrapezeL")
	await _walk_to(a, KEYS_1, top.top_center().x)
	await _walk_to(b, KEYS_2, low.top_center().x)
	await frames(5)
	check(top.moving and low.moving, "на каждой трапеции по герою — поехали")
	var done := {}
	_ride_trapeze(a, top, [level.get_node("SawU1"), level.get_node("SawU2")], done)
	_ride_trapeze(b, low, [level.get_node("SawL1"), level.get_node("SawL2")], done)
	await _until(func() -> bool: return done.size() == 2, 900)
	check(a.alive and b.alive and a.global_position.x > 22 * TILE and b.global_position.x > 22 * TILE,
			"трапеции: оба над своими пилами — на причалах (a %s b %s)" % [a.global_position, b.global_position])
	if not a.alive or not b.alive:
		return
	# 2. Батуты на столбах между пилами вверх-вниз.
	var saw_b: Saw = level.get_node("SawB")
	for p: Player in [b, a]:
		await _walk_to(p, _keys(p), 27.0 * TILE)
		await _until(func() -> bool:
			var c := _saw_cycle(saw_b)
			return c >= POGO_PHASE and c < POGO_PHASE + 0.06, 600)
		await _pogo(p, [30.0, 35.0, 40.0, 45.0 if p == b else 44.2])
		check(p.alive and p.global_position.y < 8 * TILE and p.global_position.x > 43 * TILE, "%s по батутам — на уступ (%s)" % [p.name, p.global_position])
		if not p.alive:
			return
	# 3. Взведённая пружина на трапецию: ожить, когда трапеция подъезжает к батуту.
	var trapeze: Mover = level.get_node("TrapezeTop")
	var pad: SpringPad = level.get_node("Pad4")
	await _walk_to(b, KEYS_2, 48.0 * TILE)
	await _charged_launch_onto(a, b, pad, trapeze)
	check(a.alive and b.alive and Weight.floor_below(a) == trapeze and Weight.floor_below(b) == trapeze,
			"взведённая пружина — оба на трапеции (a %s b %s)" % [a.global_position, b.global_position])
	if not a.alive or not b.alive:
		return
	# Трапеция доехала до уступа выхода и стоит — на уступ: сначала передний, потом задний.
	await _until(func() -> bool: return trapeze.progress >= 0.999, 600)
	_hop_to(b, 61.4 * TILE)
	await frames(12)
	await _walk_to(a, KEYS_1, trapeze.global_position.x + (trapeze.size_tiles.x - 0.6) * TILE)
	await _hop_to(a, 60.6 * TILE)
	await frames(20)
	check(a.alive and b.alive and a.global_position.y < 0.5 * TILE and b.global_position.y < 0.5 * TILE, "с трапеции — на уступ выхода (a %s b %s)" % [a.global_position, b.global_position])
	# 4. «Двойка под куполом»: А — по ступенькам на верхний ярус, Б — на нижний; едут, пока стоят оба.
	var du: Mover = level.get_node("DuoU")
	var dl: Mover = level.get_node("DuoL")
	await _walk_to(b, KEYS_2, 63.0 * TILE)
	await _walk_to(a, KEYS_1, 63.6 * TILE)
	await _hop_to(a, 64.75 * TILE)
	await _hop_to(a, 67.0 * TILE)
	check(a.alive and a.global_position.y < -3.4 * TILE, "А по ступенькам — на верхний ярус (%s)" % a.global_position)
	await _hop_to(a, 68.6 * TILE)
	await _walk_to(b, KEYS_2, 68.6 * TILE)
	await _until(func() -> bool: return du.moving and dl.moving, 120)
	check(du.moving and dl.moving, "на каждой трапеции двойки по герою — поехали")
	var lanes := [[a, du, ["DuoSawU1", "DuoSawU2", "DuoSawU3", "DuoSawU4"].map(func(n: String) -> Saw: return level.get_node(n))],
			[b, dl, ["DuoSawL1", "DuoSawL2", "DuoSawL3", "DuoSawL4"].map(func(n: String) -> Saw: return level.get_node(n))]]
	var pauses := 0
	for i in 3600:
		await get_tree().physics_frame
		if not a.alive or not b.alive or (du.progress >= 0.999 and dl.progress >= 0.999):
			break
		var paused := not a.is_on_floor() or not b.is_on_floor()
		for lane: Array in lanes:
			var p: Player = lane[0]
			var m: Mover = lane[1]
			var k := _keys(p)
			var rel := p.global_position.x - m.global_position.x
			var d := _duo_danger(p, m, rel, not paused, lane[2])
			var target := rel
			if d < INF:
				var best := INF
				for c in int((m.size_tiles.x - 0.8) / 0.25) + 1:
					var cand := (0.4 + c * 0.25) * TILE
					if absf(cand - rel) < absf(best - rel) and _duo_danger(p, m, cand, not paused, lane[2]) == INF:
						best = cand
				if best < INF and absf(best - rel) / 300.0 < d:
					target = best
				elif d < 0.3 and p.is_on_floor():
					press(k[LEFT], false)
					press(k[RIGHT], false)
					hold(k[JUMP], 12)  # не уйти — подпрыгнуть: обе трапеции встали (замереть под пилой нельзя — режет)
					pauses += 1
					continue
			press(k[RIGHT], target - rel > 6.0)
			press(k[LEFT], target - rel < -6.0)
	for p: Player in [a, b]:
		for key in [_keys(p)[LEFT], _keys(p)[RIGHT]]:
			press(key, false)
	check(a.alive and b.alive and du.progress >= 0.999 and dl.progress >= 0.999, "двойка проехала под куполом (пауз %d; a %s b %s)" % [pauses, a.global_position, b.global_position])
	if not a.alive or not b.alive:
		return
	await _walk_to(b, KEYS_2, 94.0 * TILE)
	await _walk_to(a, KEYS_1, 95.0 * TILE)
	check(a.alive and b.alive and a.global_position.x > 93 * TILE, "двойка — к выходу (a %s b %s)" % [a.global_position, b.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	if deaths > before:
		return
	await _n14_catcher()
	await _both_to_finish()


## 14, часть 5 «Ловитор»: А встаёт на трапецию (она трогается), Б замер на батуте; когда трапеция
## проехала батут на шаг, Б оживает — взлетает рядом с ней, А ловит его за руку. Трапеция проносит
## висящего над шипами; над дальним уступом А отпускает — Б на уступ, А спрыгивает следом.
func _n14_catcher() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var catcher: Mover = level.get_node("Catcher")
	var pad: SpringPad = level.get_node("Pad5")
	await _walk_jumping(b, pad.global_position.x - 1.3 * TILE)  # через А
	# на батут встать (как в _pad_up): с разбега по скату подбросит
	place(b, Vector2(pad.global_position.x, pad.global_position.y - SpringPad.HEIGHT - Player.SIZE.y / 2.0 - 1.0))
	await frames(10)
	tap(KEYS_2[FREEZE])
	await frames(5)
	check(pad.is_charged(), "Б замер на батуте — пружина взведена")
	await _walk_to(a, KEYS_1, 93.8 * TILE)  # не под полочкой: прыжок — мимо её края
	await _hop_exact(a, 91.8 * TILE)
	await _hop_exact(a, 93.7 * TILE)
	await _walk_to(a, KEYS_1, 95.5 * TILE)
	check(Weight.floor_below(a) == catcher, "А на трапеции (%s)" % a.global_position)
	await _until(func() -> bool: return catcher.global_position.x + 3.0 * TILE >= 98.4 * TILE, 600)
	tap(KEYS_2[FREEZE])  # ожил — выстрел пружины
	for i in 90:
		await get_tree().physics_frame
		_reach_for(a, KEYS_1, b)
		if a.grab_target == b or not b.alive:
			break
	check(a.grab_target == b, "А поймал Б за руку (a %s b %s)" % [a.global_position, b.global_position])
	if a.grab_target != b:
		press(KEYS_1[GRAB], false)
		return
	await _until(func() -> bool: return catcher.progress >= 0.999 or not a.alive or not b.alive, 900)
	check(a.alive and b.alive and catcher.progress >= 0.999, "трапеция пронесла пойманного над шипами (a %s b %s)" % [a.global_position, b.global_position])
	press(KEYS_1[GRAB], false)
	await frames(5)
	var front := b if b.global_position.x > a.global_position.x else a
	var back := a if front == b else b
	await _hop_to(front, 119.5 * TILE)
	await _land(front)
	await _hop_to(back, 118.3 * TILE)
	await _land(back)
	check(deaths == before and a.global_position.x > 117 * TILE and b.global_position.x > 117 * TILE,
			"ловитор: оба на дальнем уступе (a %s b %s)" % [a.global_position, b.global_position])


## Через сколько секунд героя p заденет одна из его пил, если стоять на трапеции m со сдвигом rel (px)
## (moving — трапеция едет); INF — за горизонт (1,6 с) чисто. Пилы — их же ходом туда-сюда.
func _duo_danger(p: Player, m: Mover, rel: float, moving: bool, saws: Array, horizon := 1.6) -> float:
	var st := []
	for s: Saw in saws:
		st.append([s.progress, s.forward])
	var dt := 1.0 / 30.0
	var length := (m.path_tiles * TILE).length()
	var mx := m.global_position.x
	var end_x: float = (m.get("_origin") as Vector2).x + m.path_tiles.x * TILE
	var py := p.global_position.y
	var t := 0.0
	while t < horizon:
		t += dt
		if moving:
			mx = minf(mx + m.speed * dt, end_x)
		var body := Rect2(Vector2(mx + rel - Player.SIZE.x / 2.0, py - Player.SIZE.y / 2.0), Player.SIZE).grow(4.0)
		for j in saws.size():
			var s: Saw = saws[j]
			var slen := (s.path_tiles * TILE).length()
			var pr: float = st[j][0] + (1.0 if st[j][1] else -1.0) * s.speed * dt / slen
			if pr >= 1.0:
				pr = 1.0
				st[j][1] = false
			elif pr <= 0.0:
				pr = 0.0
				st[j][1] = true
			st[j][0] = pr
			var c := s.global_position + s.path_tiles * TILE * pr
			var r := s.radius() - Saw.BITE
			var near := Vector2(clampf(c.x, body.position.x, body.end.x), clampf(c.y, body.position.y, body.end.y))
			if c.distance_squared_to(near) < r * r:
				return t
	return INF


## Едет на трапеции m, держась её середины (со сдвигом offset px); пилы saws ходят вверх-вниз поперёк
## пути: пока пила впереди внизу — отступить к заднему краю, поднялась — вперёд, под неё; не успел —
## перепрыгнуть опущенную. Когда трапеция прошла долю пути leave_at (по умолчанию — доехала до конца),
## идёт или прыгает к leave_x.
func _ride_trapeze(p: Player, m: Mover, saws: Array, done: Dictionary, leave_at := 1.0, leave_x := 23.5 * TILE, lane := 0) -> void:
	var k := _keys(p)
	var jump := 0
	var last := {}
	var reach := m.size_tiles.x / 2.0 * TILE - 26.0  # насколько можно отойти от середины
	# Вдвоём на одной трапеции: lane 1 — передний (своя половина впереди), −1 — задний.
	var front := reach - (48.0 if lane < 0 else 0.0)
	var rear := -reach + (48.0 if lane > 0 else 0.0)
	var shift := lane * 30.0 + _jit(10.0)
	for i in 1800:
		if not p.alive:
			break
		if m.progress >= leave_at and (not m.moving or leave_at < 1.0) and p.is_on_floor():
			break
		if p.is_on_floor() and jump > 0 and jump < 14 and p.velocity.y >= 0.0:
			jump = 0
		var dir := 1.0 if m.forward else -1.0
		var floor_y := m.global_position.y
		var want := shift
		for saw: Saw in saws:
			var at := saw.blade_position()
			var vy: float = (at.y - float(last.get(saw, at.y))) * 60.0
			last[saw] = at.y
			var rel := (at.x - p.global_position.x) * dir
			if rel < -1.6 * TILE or rel > 3.0 * TILE:
				continue
			if rel < 45.0:
				want = front  # под ней или только что прошёл — вперёд, не пятиться под неё
				break
			# Успеть проскочить: сколько ехать до того, как пила опустится до головы.
			var room := maxf(front - (p.global_position.x - m.top_center().x) * dir, 0.0)
			var d := rel + 60.0  # пройти под диском целиком
			var t_clear := d / (360.0 + m.speed) if d <= room * (360.0 + m.speed) / 360.0 					else room / 360.0 + (d - room * (360.0 + m.speed) / 360.0) / m.speed
			var danger := floor_y - 1.55 * TILE  # ниже — задевает голову
			var top_y := saw.global_position.y
			var t_danger := 0.0
			if at.y < danger:
				t_danger = (danger - at.y) / saw.speed if vy >= 0.0 else (at.y - top_y + danger - top_y) / saw.speed
			if t_clear + 0.08 < t_danger:
				want = front  # успеваю — проскочить под ней
			else:
				want = rear
				if rel < 70.0 and rel > 0.0 and at.y > floor_y - 1.0 * TILE and p.is_on_floor() and jump == 0:
					jump = 20  # опущенная вплотную — через неё
			break
		var dx := m.top_center().x + want - p.global_position.x
		press(k[RIGHT], dx > 10.0)
		press(k[LEFT], dx < -10.0)
		press(k[JUMP], jump > 0)
		jump = maxi(jump - 1, 0)
		await get_tree().physics_frame
	press(k[JUMP], false)
	press(k[LEFT], false)
	press(k[RIGHT], false)
	if p.alive:
		if leave_at < 1.0:
			await _hop_to(p, leave_x)
		else:
			await _walk_to(p, k, leave_x)
	done[p] = true


## Взведённая пружина на трапецию: low замирает на батуте pad, top встаёт ему на голову; low оживает,
## когда трапеция подъезжает к батуту; в полёте оба рулят к её середине.
func _charged_launch_onto(low: Player, top: Player, pad: SpringPad, m: Mover) -> void:
	var kl := _keys(low)
	var kt := _keys(top)
	await _walk_to(low, kl, pad.global_position.x)
	place(low, Vector2(pad.global_position.x + _jit(6.0), pad.global_position.y - SpringPad.HEIGHT - Player.SIZE.y / 2.0 - 1.0))
	await frames(10)
	tap(kl[FREEZE])
	await frames(5)
	check(pad.is_charged(), "%s замер на батуте — пружина взведена" % low.name)
	await _onto_head(top, low)
	await _until(func() -> bool: return m.forward and m.moving and absf(m.progress - LAUNCH_AT) < 0.02, 900)
	tap(kl[FREEZE])
	for i in 150:
		await get_tree().physics_frame
		for p: Player in [low, top]:
			var k := _keys(p)
			var dx := m.top_center().x + (-50.0 if p == low else 50.0) - p.global_position.x
			var steer := p.global_position.y < m.top_center().y - 0.6 * TILE  # поднялся выше трапеции — к её середине
			if p == low:  # нижний — следом за верхним, не под ним: иначе верхний сядет ему на голову
				steer = steer and top.global_position.x - low.global_position.x > 0.6 * TILE
			press(k[RIGHT], steer and dx > 10.0)
			press(k[LEFT], steer and dx < -10.0)
		if i > 20 and low.is_on_floor() and top.is_on_floor():
			break
	for key in [kl[LEFT], kl[RIGHT], kt[LEFT], kt[RIGHT]]:
		press(key, false)
	await frames(5)


const LAUNCH_AT := 0.2  # доля пути трапеции, когда ожить: она чуть правее батута — взлететь рядом и сесть на неё


## 18 «Искры и призрак» (скорость): Б держит А за руку (смотрит назад, на призрака), оба идут вперёд;
## встречную искру перепрыгивают вдвоём, за уходящей не бегут.
func _n18() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var ghost: Ghost = level.get_node("Ghost")
	var sparks: Array = level.find_children("Spark*", "Spark", true, false)
	# Ложный путь: вперёд, не глядя назад, — призрак догоняет.
	press(KEYS_1[RIGHT], true)
	press(KEYS_2[RIGHT], true)
	var caught := false
	for i in 420:
		await get_tree().physics_frame
		if deaths > before:
			caught = true
			break
		press(KEYS_1[RIGHT], a.global_position.x < 8.5 * TILE)
		press(KEYS_2[RIGHT], b.global_position.x < 8.5 * TILE + 50.0)
	press(KEYS_1[RIGHT], false)
	press(KEYS_2[RIGHT], false)
	check(caught, "спиной к призраку — догнал")
	if caught:
		await _respawned()
	before = deaths
	# Б берёт фонарь с крюка у старта: в темноте призрак замирает, только когда освещён.
	var lantern: Lantern = level.get_node("Lantern")
	await _walk_to(b, KEYS_2, lantern.global_position.x)
	await hold(KEYS_2[GRAB], 4)
	check(lantern.holder == b, "Б взял фонарь")
	await _walk_to(a, KEYS_1, b.global_position.x - 50.0)
	await _face_side(a, LEFT)
	press(KEYS_2[GRAB], true)
	await frames(3)
	check(b.grab_target == a, "Б держит А за руку (смотрит назад)")
	var pits := [43.0 * TILE, 46.0 * TILE]
	var widths := [1.5, 3.0]
	var last := {}
	for sp: Spark in sparks:
		last[sp] = sp.global_position.x
	var last_b := b.global_position.x
	var hold := 0
	var unwatched := 0
	for i in 2400:
		await get_tree().physics_frame
		if not ghost.watched:
			unwatched += 1
		var bv := (b.global_position.x - last_b) * 60.0
		last_b = b.global_position.x
		var jump := false
		var wait := false
		var still := false  # искра сзади: на месте, без шага
		for sp: Spark in sparks:
			var sv: float = (sp.global_position.x - last[sp]) * 60.0
			last[sp] = sp.global_position.x
			var dx: float = sp.global_position.x - b.global_position.x
			# Искра быстрее бега догоняет сзади — встать и подпрыгнуть на месте: пройдёт под ногами.
			var behind: float = a.global_position.x - sp.global_position.x
			if sp.visible and sv > 0.0 and behind > -20.0 and behind < 40.0 + sv * 0.28:
				jump = true
				still = true
				continue
			if not sp.visible or dx <= -30.0:
				continue
			if sv > 0.0 and dx < 110.0 and dx > 0.0:
				wait = true
			elif sv <= 0.0 and dx > 0.0 and dx / maxf(maxf(bv, 120.0) - sv, 1.0) < SPARK_LEAD:
				jump = true
				# с разбегу прыжок над искрой кончится в яме — прыгать на месте
				for k2 in pits.size():
					var land: float = b.global_position.x + 4.0 * TILE
					if land > pits[k2] - 20.0 and land < pits[k2] + widths[k2] * TILE + 30.0 and b.global_position.x < pits[k2]:
						still = true
		for pit_x: float in pits:
			if pit_x - b.global_position.x > 0.0 and pit_x - b.global_position.x < 60.0:
				jump = true  # яма впереди — вдвоём через неё
		if jump and b.is_on_floor() and hold == 0:
			hold = 16
		var go := (not wait or not b.is_on_floor()) and not still
		for k2 in pits.size():  # над ямой (или осыпью) — только вперёд, иначе упадём
			if a.global_position.x > pits[k2] - 70.0 and b.global_position.x < pits[k2] + widths[k2] * TILE + 30.0 and not b.is_on_floor():
				go = true
		press(KEYS_2[RIGHT], go and b.global_position.x < 53.0 * TILE)
		press(KEYS_1[RIGHT], go and b.global_position.x - a.global_position.x > 50.0)
		press(KEYS_2[JUMP], hold > 0)
		press(KEYS_1[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		if not a.alive or not b.alive or a.global_position.x > 51.6 * TILE:
			break
	for key in [KEYS_1[RIGHT], KEYS_2[RIGHT], KEYS_1[JUMP], KEYS_2[JUMP], KEYS_2[GRAB]]:
		press(key, false)
	await frames(10)
	check(deaths == before and a.global_position.x > 51 * TILE, "вдвоём за руку мимо искр, призрак позади (без взгляда %d кадров; a %s)" % [unwatched, a.global_position])
	# 2. Один фонарь на двоих: А — на верхний ярус, Б с фонарём — по нижнему, вровень (под А).
	await _walk_to(b, KEYS_2, 55.0 * TILE)
	await _walk_jumping(a, 60.9 * TILE)  # через Б
	await _hop_exact(a, 62.3 * TILE)
	await _hop_exact(a, 64.0 * TILE)
	check(a.alive and a.global_position.y < 8.5 * TILE, "А на верхнем ярусе (%s)" % a.global_position)
	await _walk_to(b, KEYS_2, 63.9 * TILE)
	var ghosts := {a: level.get_node("GhostU"), b: level.get_node("GhostL")}
	var lane := {a: [level.get_node("Spark6"), level.get_node("Spark7"), level.get_node("Spark9")],
			b: [level.get_node("Spark4"), level.get_node("Spark5"), level.get_node("Spark8")]}
	var pits2 := [77.0 * TILE, 95.5 * TILE]  # ямы одна над другой: прыгать вдвоём
	var spark_x := {}
	for p: Player in [a, b]:
		for sp: Spark in lane[p]:
			spark_x[sp] = sp.global_position.x
	var hops := {a: 0, b: 0}
	before = deaths
	for i in 4800:
		await get_tree().physics_frame
		if deaths > before or (a.global_position.x > 106.4 * TILE and b.global_position.x > 106.4 * TILE):
			break
		var stop := false
		var jump := {a: false, b: false}
		var still := {a: false, b: false}
		for p: Player in [a, b]:
			for sp: Spark in lane[p]:
				var sv: float = (sp.global_position.x - spark_x[sp]) * 60.0
				spark_x[sp] = sp.global_position.x
				if not sp.visible:
					continue
				var dx: float = sp.global_position.x - p.global_position.x
				var behind := -dx
				if sv > 0.0 and behind > -20.0 and behind < 40.0 + sv * 0.28:
					jump[p] = true  # догоняет сзади — подпрыгнуть на месте
					still[p] = true
				elif sv > 0.0 and dx > 0.0 and dx < 110.0:
					stop = true  # убегает впереди — переждать
				elif sv <= 0.0 and dx > 0.0 and dx / maxf(360.0 - sv, 1.0) < SPARK_LEAD:
					# у начала провода искра развернётся и пойдёт следом — не прыгать, переждать
					var w: Wire = sp.get_node(sp.wire)
					if sp.global_position.x - w.point_global(0).x < 1.6 * TILE:
						stop = true
					else:
						jump[p] = true
			for pit_x: float in pits2:
				if pit_x - p.global_position.x > 0.0 and pit_x - p.global_position.x < 45.0:
					jump[p] = true
		for p: Player in [a, b]:
			var k := _keys(p)
			var go: bool = not stop and not still[p]
			# вровень: Б (фонарь) — чуть позади А, под его призраком; А не убегает вперёд
			if p == a and a.global_position.x - b.global_position.x > 0.9 * TILE:
				go = false
			if p == b and b.global_position.x > a.global_position.x - 0.15 * TILE:
				go = false
			if jump[p] and p.is_on_floor() and hops[p] == 0:
				hops[p] = 16
			var g: Ghost = ghosts[p]
			var back: bool = not go and g.global_position.x < p.global_position.x and g.global_position.distance_to(p.global_position) < 5.0 * TILE
			press(k[RIGHT], go and p.global_position.x < 106.8 * TILE)
			press(k[LEFT], back and p.facing > 0 and hops[p] == 0)
			press(k[JUMP], hops[p] > 0)
			hops[p] = maxi(hops[p] - 1, 0)
	for p: Player in [a, b]:
		for key in [_keys(p)[LEFT], _keys(p)[RIGHT], _keys(p)[JUMP]]:
			press(key, false)
	check(deaths == before and a.global_position.x > 106 * TILE and b.global_position.x > 106 * TILE,
			"один фонарь на двоих — оба яруса пройдены (a %s b %s)" % [a.global_position, b.global_position])
	if deaths > before:
		return
	# 3. Сквозняк: фонарь погас. У закрытой двери, когда призрак близко, — оба замирают (замерших он
	# не преследует); дверь открылась — ожить и бегом.
	await _walk_to(a, KEYS_1, 107.5 * TILE)
	await _walk_to(b, KEYS_2, 108.3 * TILE)
	var ghost3: Ghost = level.get_node("Ghost3")
	var lantern2: Lantern = level.get_node("Lantern")
	check(not lantern2.shining(), "на сквозняке фонарь погас")
	var gates := [level.get_node("Gate1"), level.get_node("Gate2"), level.get_node("Gate3"), level.get_node("Gate4")]
	var freezes := 0
	var crossing := false
	for gi in gates.size():
		var gate: Door = gates[gi]
		var clock: Clock = level.get_node("Clock%d" % (gi + 1))
		var gx := gate.global_position.x
		var open_y: float = gate.get("_closed_position").y + 2.35 * TILE
		crossing = false
		for i in 1200:
			await get_tree().physics_frame
			if deaths > before:
				break
			# идти в дверь — только в начале окна (иначе закроется перед отставшим)
			var ready := a.global_position.x > gx - 2.4 * TILE and b.global_position.x > gx - 2.4 * TILE
			if ready and clock.active and gate.position.y >= open_y and float(clock.get("_t")) < clock.open_time - 1.0:
				crossing = true
			var open := crossing
			if a.frozen or b.frozen:
				if open:
					for p: Player in [a, b]:
						if p.frozen:
							tap(_keys(p)[FREEZE])
					await frames(2)
				continue
			if open:
				press(KEYS_2[RIGHT], true)
				press(KEYS_1[RIGHT], true)
				if a.global_position.x > gx + 1.3 * TILE and b.global_position.x > gx + 1.3 * TILE:
					break
				continue
			# закрыта: подойти и ждать; призрак близко — замереть обоим
			press(KEYS_2[RIGHT], b.global_position.x < gx - 0.5 * TILE)
			press(KEYS_1[RIGHT], a.global_position.x < gx - 1.3 * TILE)
			var near3 := minf(ghost3.global_position.distance_to(a.global_position), ghost3.global_position.distance_to(b.global_position))
			if near3 < 2.2 * TILE and ghost3.global_position.x > 107.7 * TILE and a.is_on_floor() and b.is_on_floor():
				press(KEYS_1[RIGHT], false)
				press(KEYS_2[RIGHT], false)
				tap(KEYS_1[FREEZE])
				tap(KEYS_2[FREEZE])
				freezes += 1
				await frames(2)
		press(KEYS_1[RIGHT], false)
		press(KEYS_2[RIGHT], false)
	# за последней дверью — под низким потолком до конца сквозняка (без прыжков: над головой искра)
	check(deaths == before and a.global_position.x > 135 * TILE and b.global_position.x > 135 * TILE,
			"сквозняк: четыре двери по такту, призрак сзади (замирали %d раз; a %s b %s)" % [freezes, a.global_position, b.global_position])
	if deaths > before:
		return
	_walk_to(a, KEYS_1, 141.0 * TILE)
	await _walk_to(b, KEYS_2, 140.0 * TILE)
	# 4. Бегство в темноте: фонарь снова горит, сзади обвал. А впереди, Б с фонарём вплотную за ним
	# (фонарь светит на 4,5 тайла — ямы видно обоим).
	var crusher: Crusher = level.get_node("Crusher")
	var run_sparks: Array = [level.get_node("Spark13"), level.get_node("Spark14"), level.get_node("Spark15")]  # под потолком сквозняка (12) — не прыгать
	await _dark_run(a, b, [154.0, 165.0, 173.0, 186.0, 190.5, 199.0, 211.0, 216.5], run_sparks, 219.5)
	check(crusher.active, "обвал гнался")
	check(deaths == before and a.global_position.x > 218 * TILE and b.global_position.x > 218 * TILE,
			"бегство в темноте от обвала (a %s b %s)" % [a.global_position, b.global_position])
	await _both_to_finish()


## Бег вдвоём вправо (18, бегство): ведущий с фонарём впереди, второй вплотную; ямы (тайлы, левый
## край) и встречные искры — перепрыгивать.
func _dark_run(lead: Player, tail: Player, pits: Array, sparks: Array, end_x: float) -> void:
	var before := deaths
	var last := {}
	for sp: Spark in sparks:
		last[sp] = sp.global_position.x
	var hops := {lead: 0, tail: 0}
	var crusher: Crusher = game.level.get_node_or_null("Crusher")
	var gap := INF
	for i in 1800:
		await get_tree().physics_frame
		if crusher != null and crusher.active and crusher.global_position.x > 152.0 * TILE:
			gap = minf(gap, minf(lead.global_position.x, tail.global_position.x) - crusher.global_position.x)
		if deaths > before or (lead.global_position.x > end_x * TILE and tail.global_position.x > end_x * TILE - 40.0):
			break
		var sv := {}
		for sp: Spark in sparks:
			sv[sp] = (sp.global_position.x - last[sp]) * 60.0
			last[sp] = sp.global_position.x
		for p: Player in [lead, tail]:
			var k := _keys(p)
			var jump := false
			for pit: float in pits:
				var dx: float = pit * TILE - p.global_position.x
				if dx > 0.0 and dx < 40.0:
					jump = true
			for sp: Spark in sparks:
				if not sp.visible:
					continue
				var dx: float = sp.global_position.x - p.global_position.x
				if dx > 0.0 and sv[sp] <= 0.0 and dx / maxf(360.0 - sv[sp], 1.0) < SPARK_LEAD:
					jump = true
			if jump and p.is_on_floor() and hops[p] == 0:
				hops[p] = 16
			var go := p.global_position.x < end_x * TILE
			if p == tail:
				go = go and lead.global_position.x - p.global_position.x > 0.8 * TILE
			press(k[RIGHT], go)
			press(k[JUMP], hops[p] > 0)
			hops[p] = maxi(hops[p] - 1, 0)
	for p: Player in [lead, tail]:
		press(_keys(p)[RIGHT], false)
		press(_keys(p)[JUMP], false)
	if crusher != null:
		print("    обвал отставал минимум на %.1f тайла" % (gap / TILE))


## Ждёт, пока меха начнут дуть (start) или перестанут (не start) — по фронту.
func _wait_gust(bellows: Bellows, start: bool, extra := Callable()) -> void:
	var was := bellows.is_blowing()
	for i in 1800:
		await get_tree().physics_frame
		var now := bellows.is_blowing()
		if now != was and now == start and (not extra.is_valid() or extra.call()):
			return
		was = now


## 16 «Порыв» (ловкость): две шахты рядом, в каждой ветер меняет направление по своему такту;
## оба лезут разом: с полочки на полочку — только в начале попутного порыва.
func _n16() -> void:
	var before := deaths
	var done := {}
	_climb_wind(a, "A", done)
	_climb_wind(b, "B", done)
	await _until(func() -> bool: return done.size() == 2, 3000)
	check(a.alive and b.alive and a.global_position.y < 2 * TILE and b.global_position.y < 2 * TILE,
			"оба поднялись по своим шахтам на башню (a %s b %s)" % [a.global_position, b.global_position])
	# Маятник за руку: с головы Б — А на высокий крюк, Б в прыжке ловит руку А, цепь качается,
	# Б прыгает на уступ; А успокаивается и раскачивается один.
	var hook: Hook = game.level.get_node("Hook")
	await _walk_to(b, KEYS_2, hook.global_position.x - 0.95 * TILE)
	await _walk_to(a, KEYS_1, 8.0 * TILE)
	press(KEYS_2[GRAB], true)
	await _jump_up(b, KEYS_2)
	check(b.grab_target == null and b.is_on_floor(), "с прыжка высокий крюк не достать")
	press(KEYS_2[GRAB], false)
	await frames(5)
	await _onto_head(a, b)
	check(await _hop_to_hook(a, KEYS_1, hook), "А с головы Б схватился за высокий крюк (%s)" % a.global_position)
	await _jump_to_hand(b, KEYS_2, a)
	check(b.grab_target == a and a.grab_target == hook, "Б в прыжке схватился за руку А — цепь (%s)" % b.global_position)
	await _swing_off(b, KEYS_2, 21.0 * TILE, [KEYS_1], 240, hook.global_position.x + 60.0)
	check(b.alive and b.is_on_floor() and b.global_position.x > 17.0 * TILE, "нижний в цепи перелетел на уступ (%s)" % b.global_position)
	await _calm_on_grab(a, KEYS_1)
	await _swing_off(a, KEYS_1, 19.5 * TILE, [], 240, hook.global_position.x + 60.0)
	check(a.alive and a.is_on_floor() and a.global_position.x > 17.0 * TILE, "А один раскачался и перелетел (%s)" % a.global_position)
	# 3. Два коридора: А — верхним, Б — нижним, каждый в такт своему ветру.
	var level16: GreyboxLevel = game.level
	await _walk_to(b, KEYS_2, 26.4 * TILE)
	await _walk_to(b, KEYS_2, 28.3 * TILE)  # в колодец — вниз, в нижний коридор
	await _land(b)
	await _walk_to(b, KEYS_2, 30.2 * TILE)
	await _walk_to(a, KEYS_1, 26.6 * TILE)
	await _hop_exact(a, 30.0 * TILE)
	check(a.alive and b.alive and a.global_position.y < 2 * TILE and b.global_position.y > 7 * TILE,
			"А на старте верхнего коридора, Б — нижнего (a %s b %s)" % [a.global_position, b.global_position])
	var through := {}
	_corridor(a, level16.get_node("WindUR"), [31.0, 37.0, 43.0, 49.0, 55.0], [35.5, 41.5, 47.5, 53.5, 59.0], through)
	_corridor(b, level16.get_node("WindLR"), [31.0, 37.0, 43.0, 49.0, 55.0], [35.5, 41.5, 47.5, 53.5, 59.5], through)
	await _until(func() -> bool: return through.size() == 2, 2400)
	check(a.alive and b.alive and a.global_position.x > 58 * TILE and b.global_position.x > 58 * TILE,
			"оба прошли свои коридоры (a %s b %s)" % [a.global_position, b.global_position])
	await _walk_to(a, KEYS_1, 61.5 * TILE)  # в дыру — вниз, на общую площадку
	await _land(a)
	await _walk_to(a, KEYS_1, 63.0 * TILE)
	await _walk_to(b, KEYS_2, 64.0 * TILE)
	# 4. Общий коридор: прыгать разом, в начале попутного порыва своей зоны.
	var j1: Bellows = level16.get_node("WindJ1R")
	var j2: Bellows = level16.get_node("WindJ2R")
	var edges := [66.0, 72.0, 78.0, 84.0, 90.0, 96.0]
	var xs := [70.5, 76.5, 82.5, 88.5, 94.5, 100.5]
	for i in xs.size():
		var edge: float = edges[i]
		# оба разом — к заднему краю камня (кто впереди, тот и передний), прыгать в первый же порыв:
		# камень осыпается через такт
		var front := a if a.global_position.x > b.global_position.x else b
		var back := b if front == a else a
		var wind: Bellows = j1 if edge < 84.0 else j2
		_walk_to(front, _keys(front), (edge - 1.3) * TILE)
		await _walk_to(back, _keys(back), (edge - 2.1) * TILE)
		await _until(func() -> bool: return wind.is_blowing() and float(wind.get("_gust")) > wind.gust_time - 0.2, 300)
		_hop_run(front, edge * TILE, (float(xs[i]) + 0.6) * TILE)
		await frames(6)  # задний — следом за передним, в тот же порыв (вплотную — столкнутся в воздухе)
		await _hop_run(back, edge * TILE, (float(xs[i]) - 0.6) * TILE)
		await _land(front)
		if not a.alive or not b.alive:
			break
	check(a.alive and b.alive and a.global_position.x > 99 * TILE and b.global_position.x > 99 * TILE,
			"общий коридор — разом по камням (a %s b %s)" % [a.global_position, b.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## Коридор на ветру: с камня на камень (края разбега edges и центры xs, тайлы) — от заднего края камня,
## разбег и прыжок в начале попутного порыва.
func _corridor(p: Player, tail: Bellows, edges: Array, xs: Array, done: Dictionary) -> void:
	for i in xs.size():
		var edge: float = edges[i]
		await _walk_to(p, _keys(p), (edge - 1.6) * TILE)
		await _wait_gust(tail, true)
		await _hop_run(p, edge * TILE, float(xs[i]) * TILE)
		if not p.alive:
			break
	done[p] = true


## Разбег до края edge (px) и прыжок к x (px) на попутном порыве: вперёд — пока до цели больше 1,2 тайла
## (дальше несёт ветер), перелетаешь — назад.
func _hop_run(p: Player, edge: float, x: float) -> void:
	var k := _keys(p)
	press(k[RIGHT], true)
	for i in 60:
		if p.global_position.x >= edge - 0.25 * TILE:
			break
		await get_tree().physics_frame
	press(k[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		var dx := x - p.global_position.x
		press(k[RIGHT], dx > 1.2 * TILE)
		press(k[LEFT], dx < -0.3 * TILE)
		if i > 4 and (p.is_on_floor() or not p.alive):
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(4)


## Прыжок с места (с головы товарища) к крюку с подруливанием; true — повис на крюке.
## Хват остаётся зажатым.
func _hop_to_hook(p: Player, k: Array[Key], hook: Hook) -> bool:
	press(k[JUMP], true)
	for i in 90:
		await get_tree().physics_frame
		var dx := hook.global_position.x - p.global_position.x
		press(k[RIGHT], dx > 4.0)
		press(k[LEFT], dx < -4.0)
		_reach_for(p, k, hook)
		if p.grab_target == hook or not p.alive or (i > 5 and p.is_on_floor()):
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	return p.grab_target == hook


## Прыжок вверх к висящему товарищу и хват за руку. Хват остаётся зажатым.
func _jump_to_hand(p: Player, k: Array[Key], target: Player) -> void:
	press(k[JUMP], true)
	for i in 60:
		await get_tree().physics_frame
		_reach_for(p, k, target)
		if p.grab_target == target or (i > 5 and p.is_on_floor()):
			break
	press(k[JUMP], false)
	await frames(5)


## Зажимает хват, когда target в досягаемости и ближе товарища: хват берёт ближайшего,
## поэтому зажатый заранее рядом с товарищем схватил бы товарища, а не крюк.
func _reach_for(p: Player, k: Array[Key], target: Node2D) -> void:
	var to_target := p.global_position.distance_to(target.global_position)
	if to_target > p.grab_range:
		return
	for other: Player in [a, b]:
		if other != p and other != target and other.alive \
				and p.global_position.distance_to(other.global_position) <= to_target:
			return
	press(k[GRAB], true)


## Раскачка на хвате (жмёт по ходу; helpers в цепи качают вместе) и прыжок с хвата вправо
## на взлёте, не раньше pump кадров и не левее release_x; в полёте правит к target_x
## с торможением. Ждёт приземления.
func _swing_off(p: Player, k: Array[Key], target_x: float, helpers: Array = [], pump := 150,
		release_x := -INF) -> void:
	for i in 900:
		var right := p.velocity.x >= 0.0
		for keys: Array in [k] + helpers:
			press(keys[RIGHT], right)
			press(keys[LEFT], not right)
		await get_tree().physics_frame
		if i > pump and p.global_position.x >= release_x and p.velocity.x > 250.0 and p.velocity.y < 0.0:
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


## Успокоиться на хвате: жать против хода (трения на хвате нет), пока не повиснет неподвижно
## внизу. После чужого рывка размах бывает «рваным» — рука то провисает, то дёргается и гасит
## раскачку; из покоя раскачка ровная (как в tests/lab/lab_swing).
func _calm_on_grab(p: Player, k: Array[Key]) -> void:
	var still := 0
	for i in 600:
		var v := p.velocity
		press(k[RIGHT], v.x < -10.0)
		press(k[LEFT], v.x > 10.0)
		await get_tree().physics_frame
		still = still + 1 if v.length() < 20.0 else 0
		if still > 10:
			break
	press(k[RIGHT], false)
	press(k[LEFT], false)


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


## Подъём по шахте tag: на каждую следующую полочку — в начале попутного порыва; с последней — на башню.
func _climb_wind(p: Player, tag: String, done: Dictionary) -> void:
	var level: GreyboxLevel = game.level
	var k := _keys(p)
	var i := 1
	while (level.has_node("Ledge%s%d" % [tag, i]) or level.has_node("Ledge%s%d" % [tag, i - 1])) and p.alive:
		var last := not level.has_node("Ledge%s%d" % [tag, i])  # с последней полочки — на башню
		var ledge: Node2D = level.get_node("Finish") if last else level.get_node("Ledge%s%d" % [tag, i])
		var target := (8.3 if tag == "A" else 9.7) * TILE if last else ledge.global_position.x + 0.75 * TILE
		var dir := 1 if target > p.global_position.x else -1
		var wind: Bellows = level.get_node("Wind%s%s" % [tag, "R" if dir > 0 else "L"])
		if last:
			await _hop_to(p, target)  # башня рядом: просто вверх
			check(p.alive and p.global_position.y < 2 * TILE, "%s на башне (%s)" % [p.name, p.global_position])
			break
		# К краю своей полочки, обращённому к цели, — пока ждём порыва.
		var support := Weight.floor_below(p) as Node2D
		if support is BrittleFloor:
			var edge := support.global_position.x + (1.5 * TILE - 26.0 if dir > 0 else 26.0)
			await _walk_to(p, k, edge)
		await _wait_gust(wind, true)
		await _react()
		press(k[JUMP], true)
		for f in 120:
			await get_tree().physics_frame
			if f == 24:
				press(k[JUMP], false)
			var dx := target + _jit(8.0) - p.global_position.x
			press(k[RIGHT], dx > 12.0)
			press(k[LEFT], dx < -12.0)
			if (f > 8 and p.is_on_floor()) or not p.alive:
				break
		for key in [k[LEFT], k[RIGHT], k[JUMP]]:
			press(key, false)
		check(p.alive and p.global_position.y < ledge.global_position.y, "%s %s (%s)" % [p.name, "на башне" if last else "на полочке %d" % i, p.global_position])
		if last:
			break
		i += 1
	done[p] = true


## Ждёт, пока ящик оттолкнётся от батута (начал лететь вверх).
func _wait_bounce(crate: Crate, limit := 400) -> bool:
	var last := crate.velocity.y
	for i in limit:
		await get_tree().physics_frame
		if crate.velocity.y < -500.0 and last >= 0.0:
			return true
		last = crate.velocity.y
	return false


## 17 «Тяжёлый заказ» (голова): вдвоём ящик на поддон крана; Б ведёт кран с плиты, А едет с грузом
## и открывает люк над лентой — ящик на плиту выхода; люк закрыть, и А перевозит Б со своей плиты.
func _n17() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var heavy: Crate = level.get_node("Heavy")
	var crane: Crane = level.get_node("Crane")
	var lid: Lever = level.get_node("Lid")
	var exit_plate: PressurePlate = level.get_node("ExitPlate")
	# 1. На площадку и вдвоём — ящик на поддон.
	await _hop_to(a, 4.8 * TILE)
	await _hop_to(a, 6.5 * TILE)
	await _walk_to(a, KEYS_1, 7.0 * TILE)
	await _hop_to(b, 4.8 * TILE)
	await _hop_to(b, 6.0 * TILE)
	await _push_heavy(heavy, 11.9 * TILE)
	check(Weight.floor_below(heavy) == crane.pallet, "вдвоём закатили тяжёлый ящик на поддон (%s)" % heavy.global_position)
	# 2. А (передний) остаётся на поддоне у ящика; Б вниз, на плиту крана.
	await _walk_to(b, KEYS_2, 3.0 * TILE)
	await _until(func() -> bool: return crane.get("_t") >= 0.999, 900)
	check(crane.get("_t") >= 0.999 and Weight.floor_below(a) == crane.pallet and Weight.floor_below(heavy) == crane.pallet,
			"Б ведёт кран — ящик и А на поддоне над правым берегом")
	# 3. А сходит и открывает люк: ящик — на ленту, лента — на плиту выхода.
	await _hop_to(a, 31.6 * TILE)  # через ящик — с поддона на берег (мимо плиты выхода под поддоном)
	await _land(a)
	await _walk_to(a, KEYS_1, 33.8 * TILE)
	await hold(KEYS_1[GRAB], 4)
	await _until(func() -> bool: return exit_plate.active, 300)
	check(lid.active and exit_plate.active, "А открыл люк — ящик упал на плиту выхода (%s)" % heavy.global_position)
	# 4. Люк закрыть; кран домой; Б на поддон; А на плиту крана — Б на том берегу.
	await hold(KEYS_1[GRAB], 4)
	check(not lid.active, "А закрыл люк — на поддон можно встать")
	await _hop_to(b, 4.8 * TILE)  # с плиты крана — кран уходит домой
	await _hop_to(b, 6.5 * TILE)
	await _until(func() -> bool: return crane.get("_t") <= 0.001, 900)
	await _walk_to(b, KEYS_2, 11.5 * TILE)
	check(Weight.floor_below(b) == crane.pallet, "Б на поддоне дома")
	await _walk_to(a, KEYS_1, 36.0 * TILE)
	await _until(func() -> bool: return crane.get("_t") >= 0.999, 900)
	await _walk_to(b, KEYS_2, 30.0 * TILE)
	await _land(b)
	check(b.alive and b.global_position.x > 27 * TILE and b.is_on_floor(), "А со своей плиты перевёз Б (%s)" % b.global_position)
	await _hop_to(b, 34.5 * TILE)  # через ящик на плите
	# Второй заказ: эстафета через остров.
	var crane3: Crane = level.get_node("Crane3")
	var crane4: Crane = level.get_node("Crane4")
	var cx: Crate = level.get_node("CrateX")
	var cy: Crate = level.get_node("CrateY")
	var lid4: Lever = level.get_node("Lid4")
	var scale: PressurePlate = level.get_node("Scale")
	await _walk_jumping(b, 42.0 * TILE)  # через А — к ящику X
	await _walk_to(a, KEYS_1, 38.6 * TILE)  # не на плиту крана — рано
	check(a.global_position.x > 38.5 * TILE and b.global_position.x > 38.5 * TILE, "оба за воротами первого заказа (a %s b %s)" % [a.global_position, b.global_position])
	# Б — ящик X на поддон первого крана и сам за ним; А на плите — кран на остров.
	await _until(func() -> bool: return crane3.get("_t") <= 0.001, 600)  # Б проходил по плите — кран дёрнулся
	await _push_crate(b, cx, 46.6 * TILE)
	await _walk_to(b, KEYS_2, 45.55 * TILE)
	check(Weight.floor_below(cx) == crane3.pallet and Weight.floor_below(b) == crane3.pallet, "Б и ящик X на поддоне первого крана")
	await _walk_to(a, KEYS_1, 40.4 * TILE)
	await _until(func() -> bool: return crane3.get("_t") >= 0.999, 900)
	await _push_crate(b, cx, 61.4 * TILE)  # ящик с поддона на остров (за плиты)
	check(cx.global_position.x > 60.5 * TILE, "ящик X на острове (%.1f)" % (cx.global_position.x / TILE))
	# А сходит с плиты — кран домой; А на поддон; Б на островной плите — кран везёт А.
	await _walk_to(a, KEYS_1, 41.5 * TILE)
	await _until(func() -> bool: return crane3.get("_t") <= 0.001, 900)
	await _walk_to(a, KEYS_1, 45.5 * TILE)
	await _walk_to(b, KEYS_2, 59.7 * TILE)
	await _until(func() -> bool: return crane3.get("_t") >= 0.999, 900)
	await _walk_to(a, KEYS_1, 56.6 * TILE)
	check(a.global_position.x > 56.5 * TILE and a.is_on_floor(), "Б с островной плиты перевёз А (%s)" % a.global_position)
	# Второй кран: Y и X на поддон; Б едет, А на плите острова.
	await _push_crate(b, cx, 65.9 * TILE)  # X — к Y на поддон второго крана
	await _walk_to(b, KEYS_2, 65.2 * TILE)
	check(Weight.floor_below(cx) == crane4.pallet and Weight.floor_below(cy) == crane4.pallet and Weight.floor_below(b) == crane4.pallet,
			"оба ящика и Б на поддоне второго крана (X %.1f Y %.1f Б %.1f)" % [cx.global_position.x / TILE, cy.global_position.x / TILE, b.global_position.x / TILE])
	await _walk_to(a, KEYS_1, 58.2 * TILE)
	await _until(func() -> bool: return crane4.get("_t") >= 0.999, 900)
	# Б — через ящики на тот берег, люк: ящики в колодец на весы.
	await _hop_to(b, 77.0 * TILE)
	await _land(b)
	await _walk_to(b, KEYS_2, 80.5 * TILE)
	await hold(KEYS_2[GRAB], 4)
	await _until(func() -> bool: return scale.active, 300)
	check(lid4.active and scale.active, "Б открыл люк — оба ящика в колодце на весах, ворота открыты")
	# Подвох: люк закрыть, иначе А на поддоне дома упадёт в пропасть.
	await hold(KEYS_2[GRAB], 4)
	check(not lid4.active, "Б закрыл люк — на поддон можно встать")
	await _walk_to(a, KEYS_1, 60.5 * TILE)
	await _until(func() -> bool: return crane4.get("_t") <= 0.001, 900)
	await _walk_to(a, KEYS_1, 65.5 * TILE)
	check(Weight.floor_below(a) == crane4.pallet, "А на поддоне второго крана дома")
	await _walk_to(b, KEYS_2, 78.0 * TILE)
	await _until(func() -> bool: return crane4.get("_t") >= 0.999, 900)
	await _hop_to(a, 77.4 * TILE)
	await _land(a)
	check(a.alive and a.global_position.x > 76.5 * TILE, "Б с дальней плиты перевёз А (%s)" % a.global_position)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	if deaths > before:
		return
	await _n17_saws()
	await _both_to_finish()


## 17, третий заказ: кран под пилами. Тяжёлый ящик вдвоём на поддон; ящик — щит (пила упирается в него
## и уходит вверх). Ведущий с плиты водит кран между пилами; ездок на том берегу сбрасывает ящик люком
## на весы, потом с дальней плиты везёт товарища — уже без щита.
func _n17_saws() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var heavy: Crate = level.get_node("Heavy3")
	var crane: Crane = level.get_node("Crane5")
	var plate: PressurePlate = level.get_node("CranePlate5")
	var plate_b: PressurePlate = level.get_node("CranePlate5b")
	var lid: Lever = level.get_node("Lid5")
	var scale: PressurePlate = level.get_node("Scale3")
	var saws: Array = level.find_children("Saw*", "Saw", false, false)
	await _walk_to(b, KEYS_2, 84.5 * TILE)
	await _walk_to(a, KEYS_1, 83.8 * TILE)
	await _until(func() -> bool: return crane.get("_t") <= 0.001, 600)  # прошли по плите — кран дёрнулся
	await _push_heavy(heavy, 97.6 * TILE)
	var rider := b if b.global_position.x > a.global_position.x else a
	var driver := a if rider == b else b
	check(Weight.floor_below(heavy) == crane.pallet and Weight.floor_below(rider) == crane.pallet,
			"вдвоём закатили ящик на поддон, ездок рядом (ящик %.1f, ездок %.1f)" % [heavy.global_position.x / TILE, rider.global_position.x / TILE])
	await _walk_to(driver, _keys(driver), plate.global_position.x + 1.1 * TILE)
	var backs := await _drive_crane(driver, plate, plate.global_position.x + 1.1 * TILE, rider, crane, saws)
	check(deaths == before and crane.get("_t") >= 0.999, "кран провёл ящик и ездока под пилами (назад %d кадров)" % backs)
	if deaths > before:
		return
	# Ездок через ящик — на берег, люк: ящик в колодец на весы.
	await _hop_to(rider, 118.2 * TILE)
	await _land(rider)
	await _walk_to(rider, _keys(rider), 119.0 * TILE)
	await hold(_keys(rider)[GRAB], 4)
	await _until(func() -> bool: return scale.active, 300)
	check(lid.active and scale.active, "люк открыт — ящик на весах, ворота открыты")
	await hold(_keys(rider)[GRAB], 4)
	check(not lid.active, "люк закрыт")
	# Ведущий сходит с плиты — кран домой; на поддон; с дальней плиты его везут, уже без щита.
	await _walk_to(driver, _keys(driver), plate.global_position.x - 1.2 * TILE)
	await _until(func() -> bool: return crane.get("_t") <= 0.001, 900)
	await _walk_to(driver, _keys(driver), 97.0 * TILE)
	check(Weight.floor_below(driver) == crane.pallet, "второй на поддоне дома")
	await _walk_to(rider, _keys(rider), plate_b.global_position.x - 1.1 * TILE)
	backs = await _drive_crane(rider, plate_b, plate_b.global_position.x - 1.1 * TILE, driver, crane, saws)
	check(deaths == before and crane.get("_t") >= 0.999, "без щита — между пилами на тот берег (назад %d кадров)" % backs)
	if deaths > before:
		return
	await _walk_to(driver, _keys(driver), 118.0 * TILE)
	check(driver.alive and driver.global_position.x > 117 * TILE, "оба на том берегу третьего заказа")


## Кран под пилами (17): ведущий стоит на плите (кран вперёд) или рядом, в off_x (кран назад), — так, чтобы
## пилы не задели ездока. Предсказание на 1,5 с вперёд; ящик-стопор не учитывается (с ним пила только
## раньше уходит вверх). Возвращает, сколько кадров кран ехал назад.
func _drive_crane(driver: Player, plate: PressurePlate, off_x: float, rider: Player, crane: Crane, saws: Array) -> int:
	var k := _keys(driver)
	var before := deaths
	var len_px := crane.length_tiles * TILE
	var step := crane.speed / len_px / 60.0
	var backs := 0
	for i in 4800:
		await get_tree().physics_frame
		if deaths > before:
			break
		var t: float = crane.get("_t")
		if t >= 0.999 and plate.active:
			break
		var now := 1.0 if plate.active else -1.0
		var rel := rider.global_position.x - (crane.global_position.x + t * len_px)
		var fwd := _crane_hit(saws, t, step, now, 1.0, rel, rider, len_px, crane)
		var back := _crane_hit(saws, t, step, now, -1.0, rel, rider, len_px, crane)
		var go := fwd >= 90 or fwd >= back
		if not go:
			backs += 1
		var dx := (plate.global_position.x if go else off_x) - driver.global_position.x
		press(k[RIGHT], dx > 6.0)
		press(k[LEFT], dx < -6.0)
	press(k[RIGHT], false)
	press(k[LEFT], false)
	return backs


## Через сколько кадров (до 90) пила заденет ездока, если кран ещё 12 кадров едет как сейчас (now: 1 —
## вперёд, −1 — назад), а потом — dir.
func _crane_hit(saws: Array, t: float, step: float, now: float, dir: float, rel: float, rider: Player, len_px: float, crane: Crane) -> int:
	var state: Array = []
	for saw: Saw in saws:
		state.append([saw.progress, saw.forward])
	for f in 90:
		t = clampf(t + (now if f < 12 else dir) * step, 0.0, 1.0)
		var at := Vector2(crane.global_position.x + t * len_px + rel, rider.global_position.y)
		var rect := Rect2(at - Player.SIZE / 2.0, Player.SIZE).grow(6.0)
		for j in saws.size():
			var saw: Saw = saws[j]
			var p: float = state[j][0] + (1.0 if state[j][1] else -1.0) * saw.speed / (saw.path_tiles * TILE).length() / 60.0
			if p >= 1.0:
				p = 1.0
				state[j][1] = false
			elif p <= 0.0:
				p = 0.0
				state[j][1] = true
			state[j][0] = p
			if Saw._circle_hits(saw.global_position + saw.path_tiles * TILE * p, saw.radius() - Saw.BITE, rect):
				return f
	return 90


## 20 «Большая машина» (финал, босс): кулаки машины охотятся за героями; фаза 1 — четыре волны слабых
## точек (две на волну, в одно окно), уступы — с застрявшего кулака; фаза 2 — тяжёлый ящик против ленты
## между ударами кулака, подъёмник с двумя плитами, ящик на ядро наверху; фаза 3 — бегство.
func _n20() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var machine: BigMachine = level.get_node("Machine")
	var fa: Fist = level.get_node("FistA")
	var fb: Fist = level.get_node("FistB")
	_f_stop = false
	_f_target = {a: 6.4 * TILE, b: 28.6 * TILE}
	_f_bounds = {a: Vector2(1.5, 34.5) * TILE, b: Vector2(1.5, 34.5) * TILE}
	_f_manual = {}
	_fist_pilot(a)
	_fist_pilot(b)
	await frames(60)
	# Волна 1: обе точки на полу по разные стороны.
	await _fist_hit(machine, 1, {a: level.get_node("WeakF1"), b: level.get_node("WeakF2")}, {a: fa, b: fb})
	# Волна 2: А — на пол правее середины, Б — на правый уступ с застрявшего кулака.
	_f_target[a] = 22.7 * TILE
	await _until(func() -> bool: return absf(a.global_position.x - 22.7 * TILE) < 20.0, 900)
	await _climb_by_fist(b, fb, 28.4, 26.4, 30.7, Vector2(29.8, 34.2))
	_f_target[b] = 30.7 * TILE
	await _fist_hit(machine, 2, {a: level.get_node("WeakF3"), b: level.get_node("WeakH2")}, {a: fa, b: fb})
	await frames(120)  # середина арены проваливается
	check(a.alive and b.alive, "после второго попадания середина провалилась — оба целы")
	# Волна 3: А — на средний уступ с кулака у края провала; Б — снова правый уступ.
	_f_bounds[a] = Vector2(22.3, 29.5) * TILE
	await _climb_by_fist(a, fa, 22.4, 24.6, 19.6, Vector2(15.8, 20.2))
	_f_target[a] = 19.3 * TILE
	await _fist_hit(machine, 3, {a: level.get_node("WeakH3"), b: level.get_node("WeakH2")}, {a: fa, b: fb})
	# Волна 4: А — вниз налево и на левый уступ с кулака; Б — на пол справа.
	_f_target[a] = 15.9 * TILE  # к левому краю среднего уступа — и вниз, на левый берег
	await _until(func() -> bool: return absf(a.global_position.x - 15.9 * TILE) < 16.0, 600)
	_f_manual[a] = true
	await _hop_to(a, 11.8 * TILE)
	_f_manual[a] = false
	_f_bounds[a] = Vector2(1.5, 12.6) * TILE
	_f_bounds[b] = Vector2(22.3, 34.5) * TILE
	_f_target[b] = 28.4 * TILE
	await _climb_by_fist(a, fa, 7.6, 9.8, 5.4, Vector2(1.3, 6.2))
	_f_target[a] = 5.2 * TILE
	await _fist_hit(machine, 4, {a: level.get_node("WeakH1"), b: level.get_node("WeakF2")}, {a: fa, b: fb})
	check(machine.phase == 2, "четыре волны — броня треснула, пасть открыта (фаза %d)" % machine.phase)
	_f_stop = true
	await frames(10)
	check(deaths == before, "фаза 1 без гибели (%d)" % (deaths - before))
	await frames(90)  # пол арены поднимается, пасть открыта
	# 2. В нутро; тяжёлый ящик против ленты к подъёмнику между ударами нижнего кулака.
	var heavy: Crate = level.get_node("Heavy")
	var lift: Door = level.get_node("Lift")
	var lift_down: float = lift.get("_closed_position").y
	_f_manual[a] = true
	_f_manual[b] = true
	await _hop_to(a, 11.8 * TILE)
	await _dash(a, 36.4 * TILE, [])
	await _dash(b, 37.3 * TILE, [])
	_f_stop = false
	check(a.alive and b.alive and a.global_position.x > 35 * TILE, "оба в пасти (a %s b %s)" % [a.global_position, b.global_position])
	await _push_under_fist(heavy, 59.5 * TILE, Vector2(39.5, 57.4))
	check(heavy.global_position.x > 58.6 * TILE, "ящик против ленты, между ударами кулака — на подъёмнике (%.1f)" % (heavy.global_position.x / TILE))
	if not a.alive or not b.alive:
		return
	# Подъёмник: А на нём с ящиком; Б на нижнюю плиту — едут вверх. А наверху на верхнюю плиту, Б сходит;
	# А сходит с плиты — подъёмник с ящиком вниз; Б на подъёмник; А снова на плиту — Б с ящиком наверху.
	var rider := a if absf(a.global_position.x - heavy.global_position.x) < absf(b.global_position.x - heavy.global_position.x) else b
	var holder := b if rider == a else a
	var kr := _keys(rider)
	var kh := _keys(holder)
	if absf(rider.global_position.x - 58.6 * TILE) > 30.0:
		await _walk_to(rider, kr, 58.6 * TILE)
	# Подъёмник на рычагах: поднят, пока включён любой. Второй — на ящик и через шахту к нижнему рычагу.
	await _hop_to(holder, heavy.global_position.x)
	await _hop_to(holder, 62.7 * TILE)
	await hold(kh[GRAB], 4)
	await _until(func() -> bool: return lift.position.y <= lift_down - 6.95 * TILE, 600)
	await _hop_to(rider, 62.7 * TILE)
	check(rider.global_position.y < 5 * TILE, "%s с ящиком наверху, у верхнего рычага (%s)" % [rider.name, rider.global_position])
	await hold(kh[GRAB], 4)                 # нижний — выкл.: подъёмник с ящиком вниз, за вторым
	await _until(func() -> bool: return lift.position.y >= lift_down - 0.05 * TILE, 600)
	await _walk_to(holder, kh, 60.62 * TILE)  # на подъёмник справа от ящика
	await hold(kr[GRAB], 4)                 # верхний — вкл.: второй с ящиком наверху
	await _until(func() -> bool: return lift.position.y <= lift_down - 6.95 * TILE, 600)
	check(holder.global_position.y < 5 * TILE and heavy.global_position.y < 5 * TILE, "второй и ящик наверху (%s ящик %s)" % [holder.global_position, heavy.global_position])
	# Наверху: вдвоём — ящик влево на ядро между ударами верхнего кулака.
	await _walk_to(rider, kr, 61.4 * TILE)
	_f_target = {a: a.global_position.x, b: b.global_position.x}
	await _push_under_fist(heavy, 41.2 * TILE, Vector2(39.5, 63.5))
	var machine2: BigMachine = level.get_node("Machine")
	await _until(func() -> bool: return machine2.phase == 3, 120)
	check(machine2.phase == 3, "ящик на ядре — машина разваливается (ящик %.1f)" % (heavy.global_position.x / TILE))
	check(deaths == before, "фаза 2 без гибели (%d)" % (deaths - before))
	# 3. Бегство: через дверь нутра — вниз; сзади обвал, сверху последний кулак.
	var run_fist: Fist = level.get_node("FistRun")
	for p: Player in [b, a]:
		await _dash(p, (63.3 if p == b else 62.6) * TILE, [])
	await frames(30)
	_f_stop = false
	_f_manual = {a: false, b: false}
	_f_bounds = {a: Vector2(68.3, 73.4) * TILE, b: Vector2(68.3, 73.4) * TILE}  # не наступить на осыпь
	_f_target = {a: 70.4 * TILE, b: 71.8 * TILE}
	_f_manual = {a: true, b: true}
	for p: Player in [b, a]:
		await _dash(p, (71.8 if p == b else 70.4) * TILE, [])
	_f_manual = {a: false, b: false}
	_fist_pilot(a)
	_fist_pilot(b)
	await _run_calm(run_fist, [b, a], [82.4, 78.8], Vector2(78.0, 82.9))
	check(a.alive and b.alive and a.global_position.x > 75 * TILE, "по осыпи (a %s b %s)%s" % [a.global_position, b.global_position, _crusher_lag()])
	# Трапеция: сесть, когда она у берега, а кулак только что ударил.
	var trapeze: Mover = level.get_node("Trapeze")
	# трапеция возвращается к берегу (А бежать дальше — выйти заранее), кулак только что ударил
	var last := [trapeze.progress]
	await _until(func() -> bool:
		var back: bool = trapeze.progress < float(last[0]) and trapeze.progress < 0.3
		last[0] = trapeze.progress
		return back and (run_fist.state == Fist.State.STUCK or run_fist.state == Fist.State.RISE), 1500)
	_f_manual = {a: true, b: true}
	_hop_to(b, 85.0 * TILE)
	await _dash(a, 82.3 * TILE, [])
	await _hop_to(a, 84.0 * TILE)
	await _until(func() -> bool: return trapeze.progress >= 0.999, 300)
	_dash(b, 97.0 * TILE, [])
	await _dash(a, 96.2 * TILE, [])
	check(a.alive and b.alive and a.global_position.x > 95 * TILE, "трапецией над шипами (a %s b %s)%s" % [a.global_position, b.global_position, _crusher_lag()])
	# Порыв: прыгать в начале попутного.
	var wind: Bellows = level.get_node("WindR")
	for p: Player in [b, a]:
		_f_target[p] = (99.9 if p == b else 97.6) * TILE
		_f_bounds[p] = Vector2(95.3, 100.6) * TILE
		_f_manual[p] = false
	for p: Player in [b, a]:
		# прыгать, когда начался попутный порыв и кулак не бьёт по пути к краю
		for attempt in 10:
			await _wait_gust(wind, true)
			var r := run_fist.get_rect()
			if run_fist.state != Fist.State.SLAM and not (run_fist.is_winding() and r.end.x + 20.0 > p.global_position.x):
				break
		_f_manual[p] = true
		await frames(2)  # пилот отпустил клавиши
		await _run_jump(p, _keys(p), 101.0 * TILE)
		await _land(p)
		_f_target[p] = (111.6 if p == b else 109.0) * TILE
		_f_bounds[p] = Vector2(108.3, 112.6) * TILE
		_f_manual[p] = false
		check(p.alive and p.global_position.x > 108 * TILE, "%s на порыве через пропасть (%s)" % [p.name, p.global_position])
	await _run_calm(run_fist, [b, a], [118.5, 117.5], Vector2(116.3, 120.8))
	_f_manual = {a: true, b: true}
	# Ворота на колесе: Б крутит, А пробегает; Б выпрыгивает и успевает на маховике.
	var wheel: Wheel = level.get_node("WheelGate")
	await _until(func() -> bool: return _fist_calm(run_fist, b), 600)
	await _hop_to(b, wheel.global_position.x)
	var stop := [false]
	_spin(b, stop)
	await _until(func() -> bool: return wheel.active, 120)
	await _dash(a, 129.5 * TILE, [])
	await _until(func() -> bool: return wheel.spin > 0.9, 120)
	stop[0] = true
	await _leave_wheel(b, 128.6 * TILE)
	_f_stop = true
	await frames(2)  # пилоты отпустили клавиши
	check(a.alive and b.alive and a.global_position.x > 128 * TILE and b.global_position.x > 128 * TILE,
			"ворота на колесе — оба за ними (a %s b %s)%s" % [a.global_position, b.global_position, _crusher_lag()])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## Отрезок погони: пилот уворачивается, пока кулак не спокоен; тогда — бегом каждый к своей цели
## (тайлы); там пилот снова держит героя на месте, уворачиваясь в пределах площадки area (тайлы).
func _run_calm(f: Fist, players: Array, xs: Array, area: Vector2) -> void:
	# оба на своих местах (рядом) и кулак спокоен — тогда разом
	await _until(func() -> bool:
		var ready := true
		for p: Player in players:
			ready = ready and absf(p.global_position.x - float(_f_target.get(p, p.global_position.x))) < 40.0
		return ready and _fist_calm(f, players[0]) and _fist_calm(f, players[1]), 900)
	for p: Player in players:
		_f_manual[p] = true
	_dash(players[0], float(xs[0]) * TILE, [])
	await _dash(players[1], float(xs[1]) * TILE, [])
	await frames(10)
	for i in players.size():
		var p: Player = players[i]
		_f_target[p] = float(xs[i]) * TILE
		_f_bounds[p] = area * TILE
		_f_manual[p] = false


var _f_target := {}
var _f_bounds := {}
var _f_manual := {}
var _f_stop := false


## Кулаки, которые сейчас бьют.
func _live_fists() -> Array:
	var result := []
	for f in game.level.find_children("*", "Fist", true, false):
		if f.enabled:
			result.append(f)
	return result


## Фоновый пилот героя на арене кулаков: к своей цели _f_target, уворачиваясь от кулаков в замахе
## и ударе (выйти из-под кулака туда, где больше места), и не заходить под кулак, который вот-вот ударит.
func _fist_pilot(p: Player) -> void:
	var k := _keys(p)
	var driving := false
	while not _f_stop:
		await get_tree().physics_frame
		if not p.alive or _f_manual.get(p, false):
			if driving:  # управление ушло ручному приёму — отпустить свои клавиши
				press(k[LEFT], false)
				press(k[RIGHT], false)
				driving = false
			continue
		driving = true
		var target: float = _f_target.get(p, p.global_position.x)
		var bounds: Vector2 = _f_bounds.get(p, Vector2(-INF, INF))
		var x := p.global_position.x
		var dodge := 0.0
		var blocked := false
		for f: Fist in _live_fists():
			if not f.is_dangerous():
				continue
			var r := f.get_rect()
			var lo := r.position.x - 30.0
			var hi := r.end.x + 30.0
			if x + 22.0 > lo and x - 22.0 < hi:
				# куда выйти: левее кулака или правее — где после отскока есть место (в своих границах)
				var to_left := lo - 24.0
				var to_right := hi + 24.0
				var mate := b if p == a else a
				var mx := mate.global_position.x
				# товарищ мешает уйти в его сторону, если стоит между мной и выходом из-под кулака
				var left_ok := to_left >= bounds.x and not (mx < x and mx > to_left - 30.0 and absf(mate.global_position.y - p.global_position.y) < 40.0)
				var right_ok := to_right <= bounds.y and not (mx > x and mx < to_right + 30.0 and absf(mate.global_position.y - p.global_position.y) < 40.0)
				if left_ok and right_ok:
					dodge = -1.0 if x - to_left < to_right - x else 1.0
				elif left_ok:
					dodge = -1.0
				elif right_ok:
					dodge = 1.0
				else:
					dodge = -1.0 if x - bounds.x > bounds.y - x else 1.0
			elif (target - x) * (r.get_center().x - x) > 0.0 and absf(r.get_center().x - x) < absf(target - x) + 40.0:
				blocked = true  # цель за кулаком, который бьёт, — подождать
		var dx := target - x
		press(k[RIGHT], dodge > 0.0 or (dodge == 0.0 and not blocked and dx > 8.0))
		press(k[LEFT], dodge < 0.0 or (dodge == 0.0 and not blocked and dx < -8.0))
	for key in [k[LEFT], k[RIGHT], k[JUMP]]:
		press(key, false)


## Вдвоём толкать тяжёлый ящик к x под кулаком: кто под замахнувшимся кулаком, а ящик не под ним, —
## отскакивает назад (ящик под кулаком — подпорка: под ним цел), потом снова толкает.
func _push_under_fist(crate: Crate, x: float, bounds: Vector2) -> void:
	var dir := 1.0 if x > crate.global_position.x else -1.0
	var front := b if (b.global_position.x - a.global_position.x) * dir > 0.0 else a
	var back := a if front == b else b
	_f_manual[a] = true
	_f_manual[b] = true
	await _walk_to(front, _keys(front), crate.global_position.x - dir * 62.0)
	await _walk_to(back, _keys(back), front.global_position.x - dir * 50.0)
	for i in 3000:
		await get_tree().physics_frame
		if (crate.global_position.x - x) * dir >= 0.0 or not a.alive or not b.alive:
			break
		var c := crate.get_rect()
		for p: Player in [front, back]:
			var k := _keys(p)
			var flee := false
			for f: Fist in _live_fists():
				if not f.is_dangerous():
					continue
				var r := f.get_rect()
				var covers_me := p.global_position.x + 22.0 > r.position.x - 20.0 and p.global_position.x - 22.0 < r.end.x + 20.0
				var covers_crate := c.end.x > r.position.x + 4.0 and c.position.x < r.end.x - 4.0
				if covers_me and not covers_crate:
					flee = true
			press(k[RIGHT], (dir > 0.0) != flee)
			press(k[LEFT], (dir < 0.0) != flee)
	for p: Player in [a, b]:
		for key in [_keys(p)[LEFT], _keys(p)[RIGHT]]:
			press(key, false)
	await frames(10)
	_f_manual[a] = false
	_f_manual[b] = false


## Кулак спокоен для героя: застрял, поднимается или ещё далеко от него.
func _fist_calm(f: Fist, p: Player) -> bool:
	if f.state == Fist.State.STUCK or f.state == Fist.State.RISE:
		return true
	return f.state == Fist.State.TRACK and absf(f.get_rect().get_center().x - p.global_position.x) > 2.2 * TILE


## Волна: когда оба кулака спокойны — оба на свои кнопки разом; ждём, пока машина засчитает волну.
func _fist_hit(machine: BigMachine, wave: int, plates: Dictionary, fists: Dictionary) -> void:
	var prep := {}
	for p: Player in plates:
		prep[p] = _f_target[p]
	for attempt in 12:
		await _until(func() -> bool:
			return _fist_calm(fists[a], a) and _fist_calm(fists[b], b) \
					and absf(a.global_position.x - float(prep[a])) < 24.0 and absf(b.global_position.x - float(prep[b])) < 24.0, 1500)
		for p: Player in plates:
			_f_target[p] = (plates[p] as Node2D).global_position.x
		for i in 50:
			await get_tree().physics_frame
			if machine.wave >= wave or not a.alive or not b.alive:
				break
		for p: Player in plates:
			_f_target[p] = prep[p]
		if machine.wave >= wave or not a.alive or not b.alive:
			break
		await frames(30)
	check(machine.wave >= wave and a.alive and b.alive, "волна %d: две слабые точки в одно окно (a %s b %s)" % [wave, a.global_position, b.global_position])


## Подманить свой кулак к месту stand_x (тайлы), отскочить к dodge_x, запрыгнуть на застрявший кулак
## и с него — на уступ (ledge — его края, тайлы); пилот героя на это время выключен.
func _climb_by_fist(p: Player, f: Fist, stand_x: float, dodge_x: float, ledge_x: float, ledge: Vector2) -> void:
	_f_target[p] = stand_x * TILE
	await _until(func() -> bool: return absf(p.global_position.x - stand_x * TILE) < 16.0, 900)
	for attempt in 6:
		await _until(func() -> bool: return f.state == Fist.State.WINDUP and absf(f.get_rect().get_center().x - p.global_position.x) < 30.0, 900)
		_f_target[p] = dodge_x * TILE
		await _until(func() -> bool: return f.state == Fist.State.STUCK, 120)
		if f.state == Fist.State.STUCK and absf(f.get_rect().get_center().x - stand_x * TILE) < 40.0:
			break
		_f_target[p] = stand_x * TILE
	_f_manual[p] = true
	await _hop_to(p, f.get_rect().get_center().x)
	await _hop_to(p, ledge_x * TILE)
	_f_manual[p] = false
	_f_bounds[p] = ledge * TILE
	_f_target[p] = ledge_x * TILE
	check(p.alive and p.global_position.y < 8.0 * TILE, "%s с застрявшего кулака на уступ (%s)" % [p.name, p.global_position])


## Пройти под прессом влево до x (как _pass_press, но в другую сторону).
func _pass_press_left(p: Player, press_node: Node2D, x: float) -> void:
	var k := _keys(p)
	for i in 600:
		if _press_safe(press_node) > 1.0:
			break
		await get_tree().physics_frame
	press(k[LEFT], true)
	for i in 120:
		await get_tree().physics_frame
		if p.global_position.x <= x or not p.alive:
			break
	press(k[LEFT], false)


## Сколько секунд пресс ещё не придавит стоящего под ним (0 — опасен сейчас).
func _press_safe(press: Node2D) -> float:
	var state: int = press.get("_state")
	var top: Vector2 = press.get("_top")
	var head: float = (float(press.get("drop_tiles")) - Player.SIZE.y / GreyboxLevel.TILE) * GreyboxLevel.TILE
	var fall: float = head / float(press.get("fall_speed"))
	match state:
		0:  # наверху
			return float(press.get("_timer")) + fall
		3:  # поднимается
			var up: float = press.position.y - top.y
			if up > head - 8.0:
				return 0.0
			return up / float(press.get("rise_speed")) + float(press.get("top_wait")) + fall
	return 0.0


## Пройти под прессом вправо до x: у края будки дождаться паузы — и бегом.
func _pass_press(p: Player, press_node: Node2D, x: float) -> void:
	var k := _keys(p)
	var edge := press_node.global_position.x - 0.9 * TILE
	if p.global_position.x < edge:
		await _walk_to(p, k, edge)
	var need := (x - press_node.global_position.x + 0.9 * TILE) / (5.6 * TILE) + 0.15  # сколько бежать до выхода из-под пресса
	for i in 900:
		if _press_safe(press_node) > need:
			break
		await get_tree().physics_frame
	await _react()
	press(k[RIGHT], true)
	for i in 120:
		await get_tree().physics_frame
		if p.global_position.x >= x or not p.alive:
			break
	press(k[RIGHT], false)


## В будку на кнопку — и, как только нажата, сразу назад, пока пресс наверху.
func _booth_hit(p: Player, button: PressurePlate, back_x: float) -> void:
	var k := _keys(p)
	press(k[RIGHT], true)
	for i in 60:
		await get_tree().physics_frame
		if button.active:
			break
	press(k[RIGHT], false)
	press(k[LEFT], true)
	for i in 60:
		await get_tree().physics_frame
		if p.global_position.x <= back_x:
			break
	press(k[LEFT], false)


# --- Головоломки из перебора: исполнитель решения (levels/<сцена>.solution.json) -----------------

var _pz := {}


func _pz_player(i: int) -> Player:
	return a if i == 0 else b


func _pz_floor_px(room: int) -> float:
	return float(_pz.floors[room]) * TILE


## Комната, где точка: по x; в «Двух цехах» коридор — по высоте (выше перекрытия — верхний).
func _pz_room_at(pos: Vector2) -> int:
	var first := 0
	var last: int = _pz.room_x.size() - 1
	if _pz.has("n"):
		var n := int(_pz.n)
		if pos.y < 8.0 * TILE:
			last = n - 1
		else:
			first = n
	var room := first
	for i in range(first, last + 1):
		if pos.x / TILE >= float(_pz.room_x[i]):
			room = i
	return room


## Ширина комнаты (с граничным столбцом), тайлы.
func _pz_w(room: int) -> float:
	return float(_pz.widths[room])


## Идёт к x (тайлы): упёрся в ящик или товарища — перепрыгивает; с уступа спрыгивает.
func _pz_go(p: Player, x: float) -> void:
	var k := _keys(p)
	# ящики на полу между p и x — перепрыгнуть (иначе p потолкает их перед собой)
	for i in 4:
		var d := 1 if x * TILE > p.global_position.x else -1
		var next: Crate = null
		for c: Crate in game.level.find_children("Crate*", "Crate", true, false):
			var cx := c.global_position.x / TILE
			if absf(c.global_position.y - p.global_position.y) < 24.0 and (cx - p.global_position.x / TILE) * d > 0.0 					and (x - cx) * d > 0.9 and not _pz_on_latch(c) 					and (next == null or absf(cx - p.global_position.x / TILE) < absf(next.global_position.x / TILE - p.global_position.x / TILE)):
				next = c
		if next == null:
			break
		await _walk_to(p, k, next.global_position.x - d * 1.2 * TILE)
		await _pz_hop(p, next.global_position.x + d * 1.05 * TILE)
	for attempt in 3:
		var dir := 1 if x * TILE > p.global_position.x else -1
		var key := k[RIGHT] if dir > 0 else k[LEFT]
		var hurdles := _pz_hurdles(p, x, dir)
		if not hurdles.is_empty() and (hurdles[0] - p.global_position.x / TILE) * dir < 2.0:
			# разбег: защёлку перепрыгиваем только с хода
			await _walk_to(p, k, (hurdles[0] - dir * 2.3) * TILE)
		var hold_jump := 0
		var last := p.global_position.x
		var still := 0
		press(key, true)
		for i in 900:
			await get_tree().physics_frame
			if (p.global_position.x - x * TILE) * dir >= -4.0:
				break
			still = still + 1 if absf(p.global_position.x - last) < 0.5 else 0
			last = p.global_position.x
			if not hurdles.is_empty() and (p.global_position.x / TILE - hurdles[0]) * dir > -0.1:
				hurdles.pop_front()  # край защёлки позади (в прыжке)
			if p.is_on_floor() and hold_jump == 0:
				var to_hurdle: float = (hurdles[0] - p.global_position.x / TILE) * dir if not hurdles.is_empty() else 99.0
				if to_hurdle < 0.55 or p.is_on_wall() or still > 6:
					hold_jump = 22 if to_hurdle < 0.55 else 16
					still = 0
			press(k[JUMP], hold_jump > 0)
			hold_jump = maxi(hold_jump - 1, 0)
		press(key, false)
		press(k[JUMP], false)
		await _land(p)
		await frames(6)
		if absf(p.global_position.x - x * TILE) < 0.45 * TILE:
			return


## Ящик стоит на несработавшей защёлке: его перепрыгивают вместе с плитой (как защёлку), иначе
## прыгун приземлится на плиту рядом с ящиком — вдвоём они её включат.
func _pz_on_latch(c: Crate) -> bool:
	for pid: String in _pz.plate_x:
		var plate: PressurePlate = game.level.get_node("P" + pid)
		if plate.latch and not plate.active and absf(c.global_position.x - plate.global_position.x) < 1.3 * TILE 				and absf(c.global_position.y + 31.0 - plate.global_position.y) < 16.0:
			return true
	return false


## Ближние края несработавших защёлок на пути p к x (тайлы, по порядку): их перепрыгивать.
func _pz_hurdles(p: Player, x: float, dir: int) -> Array:
	var out := []
	for pid: String in _pz.plate_x:
		var plate: PressurePlate = game.level.get_node("P" + pid)
		if not plate.latch or plate.active or absf(plate.global_position.y - (p.global_position.y + Player.SIZE.y / 2.0)) > 12.0:
			continue
		var px := float(_pz.plate_x[pid])
		if absf(x - px) < 1.4:
			continue  # идём на саму защёлку
		if (px - p.global_position.x / TILE) * dir > 0.0 and (x - px) * dir > 0.0:
			out.append(px - dir * 1.25)
	out.sort_custom(func(u: float, v: float) -> bool: return (u - v) * dir < 0.0)
	return out


## Свободное место на полу комнаты: дальше от ящиков, плит и товарища.
func _pz_free_spot(room: int, p: Player) -> float:
	var x0: float = _pz.room_x[room]
	var other := a if p == b else b
	var best := x0 + 1.2
	var best_d := -99.0
	for cand: float in [x0 + 1.2, x0 + _pz_w(room) / 2.0, x0 + _pz_w(room) - 2.6]:
		var d := 99.0
		for crate: Crate in game.level.find_children("Crate*", "Crate", true, false):
			d = minf(d, absf(crate.global_position.x / TILE - cand) - 0.9)
		for pid: String in _pz.plate_x:
			var half := 1.25
			d = minf(d, absf(float(_pz.plate_x[pid]) - cand) - half - 0.45)
		d = minf(d, absf(other.global_position.x / TILE - cand) - 0.8)
		# из свободных — ближе к товарищу: камера не разведёт
		var score := (100.0 - absf(other.global_position.x / TILE - cand)) if d > 0.0 else d
		if score > best_d:
			best_d = score
			best = cand
	return best


## Куда встать на плите px: на половину, где нет ящика и товарища.
func _pz_plate_side(px: float, p: Player) -> float:
	var left_busy := false
	var right_busy := false
	var bodies: Array = game.level.find_children("Crate*", "Crate", true, false)
	bodies.append(a if p == b else b)
	var room := _pz_room_at(Vector2(px * TILE, p.global_position.y))
	for body: Node2D in bodies:
		var dx := body.global_position.x / TILE - px
		# ящики этой комнаты — с любого расстояния: их могут привезти на плиту
		var near := _pz_room_at(body.global_position) == room if body is Crate else absf(dx) < 1.4
		if near and absf(body.global_position.y - p.global_position.y) < 1.5 * TILE:
			if dx < 0.0:
				left_busy = true
			else:
				right_busy = true
	if left_busy and not right_busy:
		return px + 0.7
	if right_busy and not left_busy:
		return px - 0.7
	return px - 0.5 if p.global_position.x / TILE < px else px + 0.5


## Ящики на полу у стены, под живой лестницей, — отодвинуть, чтобы нижний встал вплотную к стене.
func _pz_clear_wall(p: Player, room: int, wall_x: float, dir: int) -> void:
	for c: Crate in game.level.find_children("Crate*", "Crate", true, false):
		if _pz_room_at(c.global_position) == room and absf(c.global_position.y - (_pz_floor_px(room) - 31.0)) < 8.0 				and absf(c.global_position.x / TILE - wall_x) < 2.3:
			await _pz_push(p, c, wall_x - dir * 2.5)
	# оба — по стенную сторону ящиков, иначе идущий к стене снова пододвинет ящик
	for q: Player in [a, b]:
		for c: Crate in game.level.find_children("Crate*", "Crate", true, false):
			if _pz_room_at(c.global_position) == room and absf(c.global_position.y - (_pz_floor_px(room) - 31.0)) < 8.0 					and (c.global_position.x - q.global_position.x) * dir > 0.0 and (wall_x * TILE - c.global_position.x) * dir > 0.0:
				await _walk_to(q, _keys(q), c.global_position.x - dir * 80.0)
				await _hop_exact(q, c.global_position.x + dir * 80.0)


## Прыжок через ящик с места: сначала вверх (выше ящика), потом вбок к target_x (px) — иначе
## на взлёте игрок толкает ящик плечом.
func _pz_hop(p: Player, target_x: float) -> void:
	var k := _keys(p)
	press(k[JUMP], true)
	for i in 110:
		await get_tree().physics_frame
		if i == 30:
			press(k[JUMP], false)
		var dir := 0
		if i >= 9:
			var dx := target_x - p.global_position.x
			var v := p.velocity.x
			if absf(dx) > 4.0:
				dir = 1 if dx > 0.0 else -1
				var stopping := v * v / (2.0 * p.air_accel) + absf(v) / 30.0
				if v * dir > 0.0 and absf(dx) <= stopping:
					dir = -dir
			elif absf(v) > 20.0:
				dir = -1 if v > 0.0 else 1
		press(k[RIGHT], dir > 0)
		press(k[LEFT], dir < 0)
		if i > 12 and (p.is_on_floor() or not p.alive):
			break
	for key in [k[JUMP], k[LEFT], k[RIGHT]]:
		press(key, false)
	await frames(5)


## Толкает ящик к x (тайлы): заходит с нужной стороны (через ящик — прыжком); тяжёлый — вдвоём.
func _pz_push(p: Player, crate: Crate, x: float, heavy := false) -> void:
	var dir := 1 if x * TILE > crate.global_position.x else -1
	# товарищ на полу на пути толкания (между толкающим, ящиком и целью) — отходит в сторону,
	# не покидая своей комнаты (модель считает его там); на плите он не стоит — модель не пустила бы
	var q := a if p == b else b
	if not heavy:
		var lo := minf(minf(p.global_position.x, crate.global_position.x), x * TILE) / TILE - 1.1
		var hi := maxf(maxf(p.global_position.x, crate.global_position.x), x * TILE) / TILE + 1.1
		var qx := q.global_position.x / TILE
		if q.is_on_floor() and absf(q.global_position.y - crate.global_position.y) < 40.0 and qx > lo and qx < hi:
			var room := _pz_room_at(q.global_position)
			var x0: float = _pz.room_x[room]
			var spots := []
			for cand: float in [lo - 0.2, hi + 0.2]:
				if cand > x0 + 0.8 and cand < x0 + _pz_w(room) - 1.8:
					spots.append(cand)
			if not spots.is_empty():
				spots.sort_custom(func(u: float, v: float) -> bool: return absf(u - qx) < absf(v - qx))
				await _pz_go(q, spots[0])
	if (p.global_position.x - crate.global_position.x) * dir > 0.0:
		await _pz_go(p, crate.global_position.x / TILE + dir * 1.3)
		await _pz_hop(p, crate.global_position.x - dir * 70.0)
	if heavy:
		if (q.global_position.x - crate.global_position.x) * dir > 0.0:
			await _pz_go(q, crate.global_position.x / TILE + dir * 1.3)
			await _pz_hop(q, crate.global_position.x - dir * 120.0)
		# оба — за ящиком, паровозиком (ящики на пути перепрыгивают)
		await _pz_go(p, crate.global_position.x / TILE - dir * 1.1)
		await _pz_go(q, crate.global_position.x / TILE - dir * 1.9)
		await _push_heavy(crate, x * TILE)
	else:
		await _push_crate(p, crate, x * TILE)


## Подъём на уступ одному: с головы товарища (тот остаётся внизу у стены) или за руку товарища,
## который уже наверху. p — поднимается; q — помогает; from — комната p, to — верхняя.
func _pz_climb(p: Player, q: Player, from: int, to: int, by_hand: bool) -> void:
	var dir := 1 if to > from else -1
	var wall_x: float = (float(_pz.room_x[to]) - 1.0) if dir > 0 else float(_pz.room_x[from])
	var top_row := _pz_floor_px(to) / TILE
	await _pz_clear_wall(p, from, wall_x, dir)
	if by_hand:
		# q наверху у края, p внизу у стены — прыгает, q ловит и тянет от края
		await _pz_go(q, wall_x + dir * 1.2)
		await _walk_to(q, _keys(q), (wall_x + dir * 0.4) * TILE)
		await _walk_to(p, _keys(p), (wall_x - dir * 0.45) * TILE)
		await _pz_pull(q, p, RIGHT if dir > 0 else LEFT, top_row, wall_x)
	else:
		await _pz_go(q, wall_x - dir * 0.6)  # с перепрыгиванием: поднимающийся может стоять на пути
		await _walk_to(q, _keys(q), (wall_x - dir * 0.45) * TILE)
		tap(_keys(q)[FREEZE])
		await frames(5)
		await _onto_head(p, q)
		await _jump(p, _keys(p), RIGHT if dir > 0 else LEFT, 40)
		await _walk_to(p, _keys(p), (wall_x + dir * 1.0) * TILE)  # с угла — на уступ
		tap(_keys(q)[FREEZE])
		await frames(5)
	check(p.is_on_floor() and p.global_position.y < top_row * TILE, "%s %s — на уступ (%s)" % [p.name, "за руку" if by_hand else "с головы", p.global_position])


## Живая лестница через границу комнат (снизу from в верхнюю to).
func _pz_ladder(i0: int, i1: int, from: int, to: int) -> void:
	var p0 := _pz_player(i0)
	var p1 := _pz_player(i1)
	var top_row := 12.0 - 3.0 * float(_pz.rooms[to])
	await _pz_clear_wall(p0, from, (float(_pz.room_x[to]) - 1.0) if to > from else float(_pz.room_x[from]), 1 if to > from else -1)
	if to > from:
		var wall_x: float = float(_pz.room_x[to]) - 1.0
		var bottom := p0 if p0.global_position.x > p1.global_position.x else p1
		var top := p1 if bottom == p0 else p0
		await _pz_ladder_right(bottom, top, wall_x, top_row)
	else:
		var wall_x2: float = float(_pz.room_x[from])
		var bottom2 := p0 if p0.global_position.x < p1.global_position.x else p1
		var top2 := p1 if bottom2 == p0 else p0
		await _ladder_up_left(bottom2, top2, wall_x2, top_row)


## Вытянуть за руку на уступ: тянуть, только пока нижний не встал наверх (дольше — верхний
## пятится и толкает ящики у стены).
func _pz_pull(top: Player, low: Player, away: int, top_row: float, edge_x: float) -> void:
	press(_keys(top)[GRAB], true)
	await frames(5)
	press(_keys(low)[JUMP], true)
	await frames(22)
	press(_keys(low)[JUMP], false)
	check(top.grab_target == low, "%s поймал %s за руку (top %s low %s)" % [top.name, low.name, top.global_position, low.global_position])
	press(_keys(top)[away], true)
	for i in 90:
		await get_tree().physics_frame
		var onto := (low.global_position.x / TILE - edge_x) * (1.0 if away == RIGHT else -1.0)
		# висит на руке над уступом, ноги выше его пола: отпустить — встанет на уступ
		if low.global_position.y + Player.SIZE.y / 2.0 < top_row * TILE - 4.0 and onto > 0.6:
			break
	press(_keys(top)[away], false)
	press(_keys(top)[GRAB], false)
	await frames(25)


## Живая лестница вправо (как _ladder_up, но вытягивание — _pz_pull).
func _pz_ladder_right(bottom: Player, top: Player, wall_x: float, top_row: float) -> void:
	await _walk_to(bottom, _keys(bottom), (wall_x - 0.45) * TILE)
	tap(_keys(bottom)[FREEZE])
	await frames(5)
	await _onto_head(top, bottom)
	await _jump(top, _keys(top), RIGHT, 40)
	check(top.is_on_floor() and top.global_position.y < top_row * TILE, "%s с головы %s — на уступ (%s)" % [top.name, bottom.name, top.global_position])
	tap(_keys(bottom)[FREEZE])
	await _walk_to(top, _keys(top), (wall_x + 0.4) * TILE)
	await _pz_pull(top, bottom, RIGHT, top_row, wall_x)
	check(bottom.is_on_floor() and bottom.global_position.y < top_row * TILE, "%s вытянул %s на уступ (%s)" % [top.name, bottom.name, bottom.global_position])


## Живая лестница влево: стена — правый край уступа wall_x.
func _ladder_up_left(bottom: Player, top: Player, wall_x: float, top_row: float) -> void:
	await _walk_to(bottom, _keys(bottom), (wall_x + 0.45) * TILE)
	tap(_keys(bottom)[FREEZE])
	await frames(5)
	await _onto_head(top, bottom)
	await _jump(top, _keys(top), LEFT, 40)
	check(top.is_on_floor() and top.global_position.y < top_row * TILE, "%s с головы %s — на уступ (%s)" % [top.name, bottom.name, top.global_position])
	tap(_keys(bottom)[FREEZE])
	await _walk_to(top, _keys(top), (wall_x - 0.4) * TILE)
	await _pz_pull(top, bottom, LEFT, top_row, wall_x)
	check(bottom.is_on_floor() and bottom.global_position.y < top_row * TILE, "%s вытянул %s на уступ (%s)" % [top.name, bottom.name, bottom.global_position])


## С ящика — на уступ: ящик (на полу комнаты from) — к стене, прыжок на него и наверх.
func _pz_crate_step(i: int, from: int, to: int) -> void:
	var p := _pz_player(i)
	var dir := 1 if to > from else -1
	var wall_x: float = (float(_pz.room_x[to]) - 1.0) if dir > 0 else float(_pz.room_x[from])
	var crate: Crate = null
	for c: Crate in game.level.find_children("Crate*", "Crate", true, false):
		if _pz_room_at(c.global_position) == from and absf(c.global_position.y - (_pz_floor_px(from) - 31.0)) < 8.0:
			if crate == null or absf(c.global_position.x / TILE - wall_x) < absf(crate.global_position.x / TILE - wall_x):
				crate = c
	await _pz_push(p, crate, wall_x - dir * 0.5)
	await _pz_go(p, crate.global_position.x / TILE - dir * 1.1)
	await _jump(p, _keys(p), RIGHT if dir > 0 else LEFT, 18)
	await _jump(p, _keys(p), RIGHT if dir > 0 else LEFT, 30)
	var top_row := 12.0 - 3.0 * float(_pz.rooms[to])
	check(p.is_on_floor() and p.global_position.y < top_row * TILE, "%s по ящику — на уступ (%s)" % [p.name, p.global_position])


## Состояние плит и ящиков — для отчёта о сбое.
func _pz_state() -> String:
	var out := ""
	for pid: String in _pz.plate_x:
		var pl: PressurePlate = game.level.get_node("P" + pid)
		out += " P%s=%s(%.0f)" % [pid, "вкл" if pl.active else "выкл", pl.current_load]
	for d: Door in game.level.find_children("D*", "Door", true, false):
		out += " %s=%s(y%.1f)" % [d.name, "откр" if d.is_open_requested() else "закр", d.position.y / TILE]
	for c: Crate in game.level.find_children("Crate*", "Crate", true, false):
		out += " %s@%.1f,%.0f" % [c.name, c.global_position.x / TILE, c.global_position.y]
	return out


## Общая камера: напарник q, стоящий на полу (не на плите), подходит к краю своей комнаты,
## ближнему к x (тайлы), — модель считает, что стоящий на полу может быть где угодно в комнате.
func _pz_follow(q: Player, x: float) -> void:
	if absf(q.global_position.x / TILE - x) < 36.0:
		return
	for pid: String in _pz.plate_x:
		var plate: PressurePlate = game.level.get_node("P" + pid)
		if absf(q.global_position.x - plate.global_position.x) < 1.25 * TILE 				and absf(plate.global_position.y - (q.global_position.y + Player.SIZE.y / 2.0)) < 16.0:
			return  # стоит на плите — держит её
	var room := _pz_room_at(q.global_position)
	var x0: float = _pz.room_x[room]
	await _pz_go(q, clampf(x, x0 + 1.4, x0 + _pz_w(room) - 2.4))


## Исполняет решение решателя шаг за шагом.
func _pz_run(file: String) -> void:
	_pz = JSON.parse_string(FileAccess.get_file_as_string(file))
	var re_plate := RegEx.create_from_string("^P(\\d): на плиту (\\d+) \\(комн (\\d+)\\)$")
	var re_floor := RegEx.create_from_string("^P(\\d): на пол \\(комн (\\d+)\\)$")
	var re_room := RegEx.create_from_string("^P(\\d): в комн (\\d+)$")
	var re_ladder := RegEx.create_from_string("^P(\\d) и P(\\d): живая лестница в комн (\\d+)$")
	var re_step := RegEx.create_from_string("^P(\\d): с ящика в комн (\\d+)$")
	var re_climb := RegEx.create_from_string("^P(\\d): (с головы|за руку) P(\\d) в комн (\\d+)$")
	var re_lever := RegEx.create_from_string("^P(\\d): рычаг (\\S+)$")
	var re_crate := RegEx.create_from_string("^P(\\d)(\\+P\\d)?: ящик (\\d+) (на плиту (\\d+)|на пол (слева|справа)|в комн (\\d+))")
	var re_drop := RegEx.create_from_string("^P(\\d): столкнул ящик (\\d+) вниз в комн (\\d+)$")
	var n := 0
	for step: String in _pz.steps:
		n += 1
		print("PZDBG %d %s | a %s b %s |%s" % [n, step, a.global_position / TILE, b.global_position / TILE, _pz_state()])
		var m := re_plate.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			await _pz_go(p, _pz_plate_side(float(_pz.plate_x[m.get_string(2)]), p))
			continue
		m = re_floor.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			await _pz_go(p, _pz_free_spot(int(m.get_string(2)), p))
			continue
		m = re_room.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			var to := int(m.get_string(2))
			var from := _pz_room_at(p.global_position)
			# через ленту — за её концом (лента кончается в 1,5 тайла от стены), перед местом ящика
			var off := 2.1 if (float(mini(from, to)) in _pz.belts) else 1.4
			await _pz_follow(a if p == b else b, float(_pz.room_x[to]) + (off if to > from else _pz_w(to) - 1.0 - off))
			await _pz_go(p, (float(_pz.room_x[to]) + off) if to > from else (float(_pz.room_x[to]) + _pz_w(to) - 1.0 - off))
			if _pz_room_at(p.global_position) != to:
				check(false, "шаг %d «%s»: не дошёл (%s)%s" % [n, step, p.global_position, _pz_state()])
				return
			continue
		m = re_ladder.search(step)
		if m:
			var p0 := _pz_player(int(m.get_string(1)))
			await _pz_ladder(int(m.get_string(1)), int(m.get_string(2)), _pz_room_at(p0.global_position), int(m.get_string(3)))
			continue
		m = re_climb.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			await _pz_climb(p, _pz_player(int(m.get_string(3))), _pz_room_at(p.global_position),
					int(m.get_string(4)), m.get_string(2) == "за руку")
			continue
		m = re_step.search(step)
		if m:
			var i := int(m.get_string(1))
			await _pz_crate_step(i, _pz_room_at(_pz_player(i).global_position), int(m.get_string(2)))
			continue
		m = re_lever.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			await _pz_go(p, float(_pz.lever_x[m.get_string(2)]))
			await hold(_keys(p)[GRAB], 4)
			await frames(6)
			continue
		m = re_drop.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			var crate: Crate = game.level.get_node("Crate" + m.get_string(2))
			var to := int(m.get_string(3))
			var from := _pz_room_at(crate.global_position)
			var edge: float = (float(_pz.room_x[to]) - 0.5) if to > from else float(_pz.room_x[from]) - 0.5
			await _pz_push(p, crate, edge + (0.9 if to > from else -0.9))
			continue
		m = re_crate.search(step)
		if m:
			var p := _pz_player(int(m.get_string(1)))
			var heavy := m.get_string(2) != ""
			var crate: Crate = game.level.get_node("Crate" + m.get_string(3))
			var room := _pz_room_at(crate.global_position)
			var target: float
			if m.get_string(5) != "":
				# ящик — к ближнему краю плиты (с той стороны, откуда приехал): толкающий остаётся вне
				# плиты, за ящиком — место для толкающих (тяжёлый толкают вдвоём); дальняя половина —
				# игроку (ящик на плите один). Ближняя занята игроком — на дальнюю
				var pid := m.get_string(5)
				var px := float(_pz.plate_x[pid])
				var side := 1.0 if crate.global_position.x / TILE < px else -1.0
				var near_busy := false
				for body: Node2D in [a, b]:
					var dx: float = (body.global_position.x / TILE - px) * side
					if body != p and dx < 0.1 and dx > -1.4 							and absf(body.global_position.y - crate.global_position.y) < 40.0:
						near_busy = true
				target = px + side * 0.6 if near_busy else px - side * 0.75
				if not near_busy and _pz.plates[pid].get("latch", false) and int(_pz.plates[pid].get("th", 1)) >= 2:
					# защёлка с порогом 2: ящик — на самом краю (середина над плитой), толкающий по
					# инерции не заступит на плиту вплотную за ящиком
					target = px - side * 0.95
			elif m.get_string(7) != "":
				var to := int(m.get_string(7))
				target = (float(_pz.room_x[to]) + _pz.crate_l) if to > room else (float(_pz.room_x[to]) + _pz_w(to) - _pz.crate_r)
			else:
				target = float(_pz.room_x[room]) + (_pz.crate_l if m.get_string(6) == "слева" else _pz_w(room) - _pz.crate_r)
			await _pz_follow(a if p == b else b, target)
			await _pz_push(p, crate, target, heavy)
			if absf(crate.global_position.x / TILE - target) > 0.7:
				# ящик упал с уступа раньше места: толкающий спрыгивает следом и доталкивает
				await _pz_push(p, crate, target, heavy)
			if absf(crate.global_position.x / TILE - target) > 0.7:
				check(false, "шаг %d «%s»: ящик не доехал до %.1f%s" % [n, step, target, _pz_state()])
				return
			continue
		check(false, "шаг не разобран: %s" % step)
	print("      решение: %d шагов" % n)


## Уровень-головоломка из перебора: решение решателя шаг за шагом, без гибели, оба в дверь.
func _pz_level(scene: String) -> void:
	var before := deaths
	await _pz_run("res://levels/%s.solution.json" % scene)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	if _pz.has("n"):
		# «Два цеха»: верхний — в проём над выходом, к нижнему
		var upper := a if a.global_position.y < 8.0 * TILE else b
		await _pz_go(upper, game.level.get_finish().global_position.x / TILE + 0.5)
		await _land(upper)
	await _both_to_finish()


## 10 «Весы»: тяжёлый ящик давит за двоих, плиты на двоих; головоломка из перебора.
func _n10() -> void:
	await _pz_level("w02_l10_scales")


## Толкнуть ящик к x (19): если стоишь не с той стороны — сначала прыжком через ящик.
func _push19(p: Player, crate: Crate, x: float) -> void:
	var dir := 1.0 if x > crate.global_position.x else -1.0
	if (p.global_position.x - crate.global_position.x) * dir > 0.0:
		await _hop_to(p, crate.global_position.x - dir * 1.2 * TILE)
	await _push_crate(p, crate, x)


## Что перепрыгивать на бегу (19): ящик и плиту — нечаянно наступишь, балка повернётся.
func _hurdles19(crate: Crate, plate: Node2D) -> Array:
	var list: Array = [crate]
	if absf(crate.global_position.x - plate.global_position.x) > 40.0:
		list.append(plate)
	return list


## 19 «Перекрёсток» (голова): шесть комнат, пять поворотных балок на рычаге и плите; решение из
## перебора (levels/w02_l19_crossroads.solution.json, 30 ходов) — бот исполняет его по шагам.
func _n19() -> void:
	var before := deaths
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/w02_l19_crossroads.solution.json"))
	var level: GreyboxLevel = game.level
	var crate: Crate = level.get_node("Crate")
	var plate: Node2D = level.get_node("PlateP0")
	var rx: Array = data.room_x
	var rw: float = data.room_w
	var pw: float = data.pit_w
	var step_no := 0
	for st: Dictionary in data.steps:
		step_no += 1
		var p: Player = a if int(st.p) == 0 else b
		var k := _keys(p)
		var off := -0.9 if p == a else 0.9
		match String(st.do):
			"go":
				var j := int(st.arg)
				await _dash(p, (float(rx[j]) + rw / 2.0 + off) * TILE, _hurdles19(crate, plate))
			"lever":
				await _walk_to(p, k, float(data.lever_x[st.arg]) * TILE)
				await hold(k[GRAB], 4)
			"freeze":
				var kb := int(st.arg)
				var center := float(rx[kb]) + rw + pw / 2.0
				var side := -1.0 if p.global_position.x < center * TILE else 1.0
				await _dash(p, (center + side * 1.6) * TILE, _hurdles19(crate, plate))
				tap(k[FREEZE])
			"unfreeze":
				tap(k[FREEZE])
				await frames(5)
				await _dash(p, (float(rx[int(st.arg)]) + rw / 2.0 + off) * TILE, _hurdles19(crate, plate))
			"push_on":
				var kb := int(st.arg)
				var left_end := float(rx[kb]) + rw
				var right_end := float(rx[kb + 1])
				var tx := left_end + 0.9 if crate.global_position.x < left_end * TILE else right_end - 0.9
				await _push19(p, crate, tx * TILE)
			"push_across":
				var j := int(st.room)
				var tx := float(rx[j]) + 0.9 if crate.global_position.x < float(rx[j]) * TILE else float(rx[j]) + rw - 0.9
				await _push19(p, crate, tx * TILE)
			"plate_on":
				await _walk_to(p, k, float(data.plate_x["P0"]) * TILE)
			"plate_off":
				await _walk_to(p, k, (float(data.plate_x["P0"]) - 1.6) * TILE)
		await frames(40)  # балки встают по цели
		if not p.alive or deaths > before:
			check(false, "шаг %d (%s %s) — гибель" % [step_no, st.do, st.get("arg", "")])
			return
	check(a.global_position.x > float(rx[5]) * TILE and b.global_position.x > float(rx[5]) * TILE,
			"по решению перебора — оба в последней комнате (a %s b %s)" % [a.global_position, b.global_position])
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	if deaths > before:
		return
	await _n19_carousel(data)  # сам проверяет и ложный путь (с гибелью)
	await _n19_relay(data)
	await _both_to_finish()


## Ждёт, пока часы станут активны (по фронту).
func _clock_rise(c: Clock, limit := 900) -> void:
	var was := c.active
	for i in limit:
		await get_tree().physics_frame
		if c.active and not was:
			return
		was = c.active


## 19, фаза 2 «Карусель»: балки на часах. Длинный мост — бегом вдвоём, как только лёг; короткий (0,9 с) —
## передний вбегает и замирает на мосту (заклинил), второй перепрыгивает его; замерший оживает на
## следующем «мосту» и бежит.
func _n19_carousel(data: Dictionary, probe := true) -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var x2 := float(data.x2)
	var pit := float(data.pit_w)
	var isle := float(data.isle2)
	await _walk_to(b, KEYS_2, (x2 + 0.4) * TILE)
	await _walk_to(a, KEYS_1, (x2 - 0.9) * TILE)
	var freezes := 0
	for k in (data.carousel as Array).size():
		var spec: Array = data.carousel[k]
		var clock: Clock = level.get_node("ClockC%d" % k)
		var turn: Turntable = level.get_node("TurnC%d" % k)
		var bl := x2 + 1.0 + k * (pit + isle)
		var br := bl + pit
		var front := b if b.global_position.x > a.global_position.x else a
		var back := a if front == b else b
		await _clock_rise(clock)
		await _until(func() -> bool: return absf(turn.rotation_degrees) < 30.0, 60)
		if float(spec[1]) > 1.5:
			_walk_to(front, _keys(front), (br + isle - 0.6) * TILE)
			await frames(8)
			await _walk_to(back, _keys(back), (br + 0.7) * TILE)
			await frames(20)
		elif probe:
			# ложный путь: перебежать короткий мост — сбросит на шипы
			press(_keys(front)[RIGHT], true)
			await _until(func() -> bool: return not front.alive or front.global_position.x > (br + 0.5) * TILE, 150)
			press(_keys(front)[RIGHT], false)
			check(deaths > before, "короткий мост бегом не перейти — сбросило")
			await _respawned()
			await _n19_carousel(data, false)
			return
		else:
			var kf := _keys(front)
			press(kf[RIGHT], true)
			await _until(func() -> bool: return front.global_position.x > (bl + 2.0) * TILE or not front.alive, 90)
			press(kf[RIGHT], false)
			tap(kf[FREEZE])
			freezes += 1
			await frames(30)
			check(turn.jammed or absf(turn.rotation_degrees) < 1.0, "балка %d заклинена замершим" % k)
			await _walk_jumping(back, (br + isle - 0.6) * TILE)
			await _clock_rise(clock)
			tap(kf[FREEZE])
			await frames(2)
			await _walk_to(front, kf, (br + 0.7) * TILE)
			await frames(20)
		if deaths > before:
			check(false, "карусель: гибель на балке %d (a %s b %s)" % [k, a.global_position, b.global_position])
			return
	check(deaths == before and a.global_position.x > (x2 + 1.0 + 6 * (pit + isle) - isle) * TILE,
			"карусель пройдена (замирали %d раз; a %s b %s)" % [freezes, a.global_position, b.global_position])


## 19, фаза 3 «Обвал»: чехарда по плитам. А стоит на правой плите острова (держит мост впереди), Б
## перебегает и встаёт на левую плиту следующего (держит тот же мост); А перебегает к правой плите
## следующего, перепрыгнув Б.
func _n19_relay(data: Dictionary) -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	var crusher: Crusher = level.get_node("Crusher")
	var n := int(data.relay)
	await _walk_to(b, KEYS_2, (float(data.x3) + 0.8) * TILE)
	await _walk_to(a, KEYS_1, level.get_node("PlateR0").global_position.x)
	var gap := INF
	for k in n:
		var turn: Turntable = level.get_node("TurnR%d" % k)
		await _until(func() -> bool: return absf(turn.rotation_degrees) < 3.0, 120)
		var plate_l: Node2D = level.get_node("PlateL%d" % k)
		await _walk_jumping(b, plate_l.global_position.x)
		await frames(6)
		if k < n - 1:
			await _walk_jumping(a, level.get_node("PlateR%d" % (k + 1)).global_position.x)
		else:
			await _walk_jumping(a, plate_l.global_position.x + 3.0 * TILE)
		if crusher.active:
			gap = minf(gap, minf(a.global_position.x, b.global_position.x) - crusher.global_position.x)
		if deaths > before:
			check(false, "обвал: гибель на балке %d (a %s b %s)" % [k, a.global_position, b.global_position])
			return
	print("    обвал отставал минимум на %.1f тайла" % (gap / TILE))
	check(crusher.active, "обвал гнался")
	check(deaths == before, "чехарда по плитам под обвалом (a %s b %s)" % [a.global_position, b.global_position])


## 13 «Механический замок»: три камеры-замка; ходы — из перебора (levels/w02_l13_lock.solution.json):
## пройти в комнату (перепрыгивая ящики), рычаг, втолкнуть ящик в проём, протолкнуть из проёма дальше,
## стянуть из проёма к себе. После каждого хода ждём, пока ленты всех довезут, и сверяем, кто где.
func _n13() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	_lk = JSON.parse_string(FileAccess.get_file_as_string("res://levels/w02_l13_lock.solution.json"))
	var step_no := 0
	for st: Dictionary in _lk.steps:
		step_no += 1
		if st.do == "chamber":
			if int(st.n) > 0:
				check(deaths == before, "камера %d пройдена без гибели" % int(st.n))
			continue
		var p := a if int(st.p) == 0 else b
		_lk_step = step_no
		match st.do:
			"go":
				await _lk_go(p, int(st.room))
			"lever":
				await _lk_lever(p, level.get_node(st.name))
			"push_in":
				await _lk_push_in(p, int(st.door))
			"push_out":
				await _lk_push_out(p, int(st.door), int(st.room))
			"push_room":
				await _lk_push_out(p, -1, int(st.room))
			"pull":
				await _lk_pull(p, int(st.door), int(st.room))
		await _lk_settle()
		var where := [_lk_room_at(a), _lk_room_at(b)]
		var crates_at := []
		for c: Crate in _lk_crates():
			crates_at.append("%s %.2f,%.2f" % [c.name, c.global_position.x / TILE, c.global_position.y / TILE])
		print("    ход %d: %s %s %s → герои %s (a %.2f b %.2f) ящики %s" % [step_no, "АБ"[int(st.p)], st.do, st.get("room", st.get("door", st.get("name", ""))), where, a.global_position.x / TILE, b.global_position.x / TILE, crates_at])
		var want := [int(st.after[0]), int(st.after[1])]
		for i in 2:
			# забежал на комнату вперёд — туда, куда и так его следующий ход
			if where[i] != want[i] and _lk_next_go(step_no, i) == where[i]:
				want[i] = where[i]
		if st.has("lever") and (level.get_node(st.lever[0]) as Lever).active != bool(st.lever[1]):
			check(false, "шаг %d (%s %s): рычаг %s не в том положении" % [step_no, "АБ"[int(st.p)], st.do, st.lever[0]])
			return
		if where != want or deaths > before:
			check(false, "шаг %d (%s %s %s): герои в %s, по решению %s (a %s b %s)" % [step_no, "АБ"[int(st.p)], st.do,
					st.get("room", st.get("door", st.get("name", ""))), where, want, a.global_position / TILE, b.global_position / TILE])
			return
	check(true, "по решению перебора — все камеры (%d ходов)" % step_no)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


var _lk := {}


## Куда следующий ход героя i (после хода step_no, нумерация с 1), если это «пройти»; иначе −2.
func _lk_next_go(step_no: int, i: int) -> int:
	for j in range(step_no, _lk.steps.size()):
		var st: Dictionary = _lk.steps[j]
		if st.do == "chamber" or int(st.p) != i:
			continue
		return int(st.room) if st.do == "go" else -2
	return -2


func _lk_room(i: int) -> Dictionary:
	return _lk.rooms[i]


func _lk_center(i: int) -> float:
	return (float(_lk_room(i).x) + float(_lk_room(i).w) / 2.0) * TILE


## Комната героя (по x). На пороге проёма — в комнате-ленте рядом (лента довозит до порога; так и
## в решателе), иначе — в ближней.
func _lk_room_at(p: Player) -> int:
	var x := p.global_position.x / TILE
	var left := -1
	for i in _lk.rooms.size():
		var r := _lk_room(i)
		if x >= float(r.x) and x < float(r.x) + float(r.w):
			return i
		if float(r.x) + float(r.w) <= x:
			left = i
	if left < 0 or left + 1 >= _lk.rooms.size():
		return left
	if _lk_room(left).kind == "b":
		return left
	if _lk_room(left + 1).kind == "b":
		return left + 1
	var edge := float(_lk_room(left).x) + float(_lk_room(left).w)
	return left if x - edge < 0.5 else left + 1


## Центр проёма k (px).
func _lk_door(k: int) -> float:
	return (float(_lk.doorways[k].x) + 0.5) * TILE


func _lk_crates() -> Array:
	return game.level.find_children("Crate*", "Crate", true, false)


## Ящик ближе всех к x (px) на высоте героя.
func _lk_crate_near(x: float, p: Player) -> Crate:
	var best: Crate = null
	for c: Crate in _lk_crates():
		if absf(c.global_position.y - p.global_position.y) < 1.2 * TILE and (best == null or absf(c.global_position.x - x) < absf(best.global_position.x - x)):
			best = c
	return best


## Идёт к цели x (px): ящики на пути перепрыгивает (не толкает); на ленте — до входа, дальше везёт она.
func _lk_walk(p: Player, x: float, room := -1) -> void:
	var k := _keys(p)
	var hold_jump := 0
	var still := 0
	var last := p.global_position.x
	for i in 900:
		var dir := 1.0 if x > p.global_position.x else -1.0
		still = still + 1 if absf(p.global_position.x - last) < 0.5 else 0
		last = p.global_position.x
		if absf(x - p.global_position.x) < 6.0 or not p.alive:
			break
		if room >= 0 and _lk_room(room).kind == "b" and _lk_room_at(p) == room:
			break
		press(k[RIGHT], dir > 0.0)
		press(k[LEFT], dir < 0.0)
		if p.is_on_floor() and hold_jump == 0:
			if still > 6 and _lk_room(_lk_room_at(p)).kind != "b":
				hold_jump = 24  # ступенька между камерами
				still = 0
			var obstacles: Array = _lk_crates()
			obstacles.append(b if p == a else a)  # товарища (у рычага) — тоже перепрыгнуть
			for c: Node2D in obstacles:
				var ahead := (c.global_position.x - p.global_position.x) * dir
				if absf(c.global_position.y - p.global_position.y) < 0.8 * TILE and ahead > 0.0 and ahead < 1.25 * TILE \
						and (x - c.global_position.x) * dir > 0.3 * TILE:
					hold_jump = 20
		press(k[JUMP], hold_jump > 0)
		hold_jump = maxi(hold_jump - 1, 0)
		await get_tree().physics_frame
	for key in [k[LEFT], k[RIGHT], k[JUMP]]:
		press(key, false)
	await _land(p)


## Следующий ход героя i после хода step_no (словарь) или пустой.
func _lk_next(step_no: int, i: int) -> Dictionary:
	for j in range(step_no, _lk.steps.size()):
		var st: Dictionary = _lk.steps[j]
		if st.do != "chamber" and int(st.p) == i:
			return st
	return {}


var _lk_step := 0


func _lk_go(p: Player, room: int) -> void:
	var nxt := _lk_next(_lk_step, 0 if p == a else 1)
	if not nxt.is_empty() and nxt.do == "push_in" and _lk_room(room).kind != "b":
		# дальше — втолкнуть ящик этой комнаты в проём: встать за ящиком со стороны, откуда толкать
		var dc := _lk_door(int(nxt.door))
		var r := _lk_room(room)
		for c: Crate in _lk_crates():
			var cx := c.global_position.x / TILE
			if cx >= float(r.x) and cx < float(r.x) + float(r.w) and absf(c.global_position.y - p.global_position.y) < 1.2 * TILE:
				var dir := 1.0 if dc > c.global_position.x else -1.0
				await _lk_walk(p, c.global_position.x - dir * 0.98 * TILE)
				return
	var other := b if p == a else a
	if other.standing_on() == p:
		# товарищ на голове — сначала он сходит туда же
		await _lk_walk(other, _lk_center(room) + 0.9 * TILE, room)
	var x := _lk_center(room)
	if _lk_room(room).kind != "b":
		if _lk_lever_in(room) != null:
			x += (0.95 if p.global_position.x > x else -0.95) * TILE  # место у рычага — для того, кто тянет
		if absf(other.global_position.x - x) < 0.7 * TILE and absf(other.global_position.y - p.global_position.y) < 2.5 * TILE:
			# не вставать товарищу на голову — рядом, но в той же комнате
			var r0 := _lk_room(room)
			for dx: float in [0.9, -0.9, 1.4, -1.4]:
				var cand := x + dx * TILE
				if cand > (float(r0.x) + 0.4) * TILE and cand < (float(r0.x) + float(r0.w) - 0.4) * TILE 						and absf(other.global_position.x - cand) >= 0.75 * TILE:
					x = cand
					break
		var from := 1.0 if x > p.global_position.x else -1.0
		var lo := (float(_lk_room(room).x) + 0.4) * TILE
		var hi := (float(_lk_room(room).x) + float(_lk_room(room).w) - 0.4) * TILE
		for c: Crate in _lk_crates():
			if absf(c.global_position.x - x) < 0.9 * TILE and absf(c.global_position.y - p.global_position.y) < 1.2 * TILE:
				# ящик на месте — встать рядом в той же комнате (лучше за ним: перепрыгнуть), не толкать
				var beyond := c.global_position.x + from * 0.95 * TILE
				var before := c.global_position.x - from * 0.95 * TILE
				x = beyond if beyond >= lo and beyond <= hi else before
	await _lk_walk(p, x, room)


func _lk_lever_in(room: int) -> Lever:
	var r := _lk_room(room)
	for lever: Lever in game.level.find_children("Lever*", "Lever", true, false):
		var lx := lever.global_position.x / TILE
		if lx >= float(r.x) and lx < float(r.x) + float(r.w) and absf(lever.global_position.y / TILE - float(r.floor)) < 0.5:
			return lever
	return null


func _lk_lever(p: Player, lever: Node2D) -> void:
	var other := b if p == a else a
	if absf(other.global_position.x - lever.global_position.x) < 0.8 * TILE and absf(other.global_position.y - lever.global_position.y) < 1.5 * TILE:
		# товарищ стоит у рычага — отступить на шаг (в той же комнате)
		await _lk_walk(other, lever.global_position.x + (0.95 if other.global_position.x > p.global_position.x else -0.95) * TILE)
	await _lk_walk(p, lever.global_position.x)
	await frames(4)
	await hold(_keys(p)[GRAB], 4)


## Толкать ящик c по направлению dir, пока его центр не дойдёт до x (px).
func _lk_shove(p: Player, c: Crate, dir: float, x: float) -> void:
	var k := _keys(p)
	# встать за ящиком (с той стороны, откуда толкать)
	if (p.global_position.x - c.global_position.x) * dir > 0.0:
		await _hop_exact(p, c.global_position.x - dir * 1.0 * TILE)
	await _lk_walk(p, c.global_position.x - dir * 1.0 * TILE)
	var origin := _lk_room_at(p)
	var key := k[RIGHT] if dir > 0.0 else k[LEFT]
	press(key, true)
	for i in 300:
		await get_tree().physics_frame
		if (c.global_position.x - x) * dir >= 0.0:
			break
	press(key, false)
	await frames(10)
	if origin >= 0 and _lk_room_at(p) != origin and _lk_room(origin).kind != "b":
		# толкавший сам остаётся в своей комнате: шаг назад из проёма
		var r := _lk_room(origin)
		await _lk_walk(p, (float(r.x) + float(r.w) - 0.45 if dir > 0.0 else float(r.x) + 0.45) * TILE)


## Ящик в комнате room (на полу комнаты, не в проёме).
func _lk_crate_in(room: int, p: Player) -> Crate:
	var r := _lk_room(room)
	var best: Crate = null
	for c: Crate in _lk_crates():
		var cx := c.global_position.x / TILE
		if cx >= float(r.x) and cx < float(r.x) + float(r.w) and absf(c.global_position.y - p.global_position.y) < 1.2 * TILE:
			if best == null or absf(c.global_position.x - p.global_position.x) < absf(best.global_position.x - p.global_position.x):
				best = c
	return best


func _lk_push_in(p: Player, door: int) -> void:
	var dc := _lk_door(door)
	var c := _lk_crate_in(_lk_room_at(p), p)
	if c == null:
		c = _lk_crate_near(p.global_position.x, p)
	var dir := 1.0 if dc > c.global_position.x else -1.0
	await _lk_shove(p, c, dir, dc - dir * 0.05 * TILE)


## Из проёма door (или, door = −1, из комнаты героя) — в комнату room.
func _lk_push_out(p: Player, door: int, room: int) -> void:
	var from := _lk_door(door) if door >= 0 else p.global_position.x
	var c := _lk_crate_near(from, p)
	var dir := 1.0 if _lk_center(room) > c.global_position.x else -1.0
	var edge := float(_lk_room(room).x) * TILE if dir > 0.0 else (float(_lk_room(room).x) + float(_lk_room(room).w)) * TILE
	# в комнату с полом — до середины (за ящиком остаётся место встать), на ленту — только заехать
	var to := edge + dir * 0.52 * TILE if _lk_room(room).kind == "b" else _lk_center(room)
	await _lk_shove(p, c, dir, to)


## Стянуть ящик из проёма к себе — в комнату room (хват и шаг назад).
func _lk_pull(p: Player, door: int, room: int) -> void:
	var k := _keys(p)
	var dc := _lk_door(door)
	var c := _lk_crate_near(dc, p)
	var away := 1.0 if _lk_center(room) > dc else -1.0
	# вплотную (хват берёт ящик с зазором до 6 px), не толкнув его
	await _lk_walk(p, c.global_position.x + away * (c.get_rect().size.x / 2.0 + Player.SIZE.x / 2.0 + 3.0))
	await frames(6)
	press(k[GRAB], true)
	await frames(3)
	var back := k[RIGHT] if away > 0.0 else k[LEFT]
	press(back, true)
	for i in 200:
		await get_tree().physics_frame
		# до середины комнаты: с обеих сторон ящика остаётся место встать
		if (c.global_position.x - _lk_center(room)) * away >= 0.0:
			break
	press(back, false)
	press(k[GRAB], false)
	await frames(10)


## Ждём, пока ленты довезут героев и ящики (все стоят).
func _lk_settle() -> void:
	await frames(20)
	var calm := 0
	for i in 400:
		await get_tree().physics_frame
		var moving := false
		for body: CharacterBody2D in [a, b] + _lk_crates():
			if body.get_real_velocity().length() > 8.0:
				moving = true
		calm = 0 if moving else calm + 1
		if calm > 15:
			break


## 15 «Беличье колесо»: колесо держит ворота (маховик — успеть самому); подъёмник от двух колёс —
## внизу и наверху; ворота на двух колёсах — раскрутить оба и выпрыгнуть разом.
func _n15() -> void:
	var level: GreyboxLevel = game.level
	var before := deaths
	# 1. А крутит колесо — Б в ворота; А выпрыгивает и успевает на маховике.
	var wheel1: Wheel = level.get_node("Wheel1")
	var gate1: Door = level.get_node("Gate1")
	await _hop_to(a, wheel1.global_position.x)
	var stop1 := [false]
	_spin(a, stop1)
	await _until(func() -> bool: return wheel1.active and gate1.position.y < gate1.get("_closed_position").y - 4.0 * TILE, 300)
	check(wheel1.active, "А крутит колесо — ворота подняты")
	await _dash(b, 13.5 * TILE, [a])
	check(b.global_position.x > 12 * TILE, "Б прошёл ворота (%s)" % b.global_position)
	await _dash(b, 19.0 * TILE, [])
	await _until(func() -> bool: return wheel1.spin > 0.99, 300)
	stop1[0] = true
	await _leave_wheel(a, 13.0 * TILE)
	check(a.global_position.x > 12 * TILE, "А выпрыгнул из колеса и успел в ворота на маховике (%s)" % a.global_position)
	# 2. Подъёмник от двух колёс: А внизу поднимает Б; Б наверху поднимает А.
	var wheel2: Wheel = level.get_node("Wheel2")
	var wheel3: Wheel = level.get_node("Wheel3")
	var lift: Door = level.get_node("Lift")
	var lift_down: float = lift.get("_closed_position").y
	await _hop_to(a, wheel2.global_position.x)
	var stop2 := [false]
	_spin(a, stop2)
	await _until(func() -> bool: return lift.position.y <= lift_down - 5.95 * TILE, 600)
	await _walk_to(b, KEYS_2, 21.5 * TILE)
	check(b.global_position.y < 6 * TILE and b.global_position.x > 20 * TILE, "А крутит нижнее колесо — Б на подъёмнике наверху (%s)" % b.global_position)
	stop2[0] = true
	await _leave_wheel(a, 17.0 * TILE)
	await _until(func() -> bool: return lift.position.y >= lift_down - 0.05 * TILE and not wheel2.active, 600)
	await _walk_to(a, KEYS_1, 18.9 * TILE)
	check(Weight.floor_below(a) == lift, "А дождался подъёмника внизу и встал на него (%s)" % a.global_position)
	await _hop_to(b, wheel3.global_position.x)
	var stop3 := [false]
	_spin(b, stop3)
	await _until(func() -> bool: return lift.position.y <= lift_down - 5.95 * TILE, 600)
	await _walk_to(a, KEYS_1, 21.0 * TILE)
	check(a.global_position.y < 6 * TILE and a.global_position.x > 20 * TILE, "Б крутит верхнее колесо — А поднялся на уступ (%s)" % a.global_position)
	stop3[0] = true
	await _leave_wheel(b, 26.5 * TILE)
	# 3. Ворота на двух колёсах: раскрутить оба до полной и выпрыгнуть разом, дальний — не позже.
	var wheel4: Wheel = level.get_node("Wheel4")
	var wheel5: Wheel = level.get_node("Wheel5")
	var gate5: Door = level.get_node("Gate5")
	await _dash(b, 30.0 * TILE, [])
	await _hop_to(b, wheel5.global_position.x)
	await _dash(a, 29.0 * TILE, [])
	await _hop_to(a, wheel4.global_position.x)
	var stop4 := [false]
	var stop5 := [false]
	_spin(a, stop4)
	_spin(b, stop5)
	await _until(func() -> bool: return wheel4.spin > 0.99 and wheel5.spin > 0.99, 300)
	check(gate5.is_open_requested(), "оба колеса раскручены — ворота подняты")
	stop4[0] = true
	stop5[0] = true
	_leave_wheel(b, 43.5 * TILE)
	await _leave_wheel(a, 42.8 * TILE, [b])
	await frames(10)
	check(a.global_position.x > 42 * TILE and b.global_position.x > 42 * TILE, "выпрыгнули разом — оба успели в ворота (a %s b %s)" % [a.global_position, b.global_position])
	# 4. Подъёмник под пилой: Б крутит нижнее колесо, А едет; трогаться, когда пила уйдёт из шахты
	# на всё время, пока А проезжает её высоту. Наверху А крутит верхнее — так же везёт Б.
	var wheel6: Wheel = level.get_node("Wheel6")
	var wheel7: Wheel = level.get_node("Wheel7")
	var lift2: Door = level.get_node("Lift2")
	var saw: Saw = level.get_node("ShaftSaw")
	var low2: float = lift2.get("_closed_position").y
	await _hop_to(a, 46.4 * TILE)  # через подставку колеса
	await _walk_to(a, KEYS_1, 47.45 * TILE)
	await _hop_to(b, wheel6.global_position.x)
	await frames(20)
	check(a.global_position.x > 47 * TILE and a.global_position.y > 11 * TILE, "А на подъёмнике внизу (%s)" % a.global_position)
	await _until(func() -> bool: return _shaft_clear(saw, a.global_position.x), 600)
	var stop6 := [false]
	_spin(b, stop6)
	await _until(func() -> bool: return lift2.position.y <= low2 - 7.95 * TILE or not a.alive, 600)
	check(a.alive and a.global_position.y < 4 * TILE, "А проехал пилу — наверху (%s)" % a.global_position)
	await _walk_to(a, KEYS_1, 50.2 * TILE)
	stop6[0] = true
	# из колеса — влево (прыжок в сторону шахты достаёт до пилы), к шахте — по полу под пилой
	press(KEYS_2[LEFT], true)
	press(KEYS_2[JUMP], true)
	await frames(14)
	press(KEYS_2[JUMP], false)
	await _land(b)
	press(KEYS_2[LEFT], false)
	await _walk_to(b, KEYS_2, 45.8 * TILE)
	await _until(func() -> bool: return lift2.position.y >= low2 - 0.05 * TILE, 900)
	await _walk_to(b, KEYS_2, 47.6 * TILE)
	await _hop_to(a, wheel7.global_position.x)
	await _until(func() -> bool: return _shaft_clear(saw, b.global_position.x), 600)
	var stop7 := [false]
	_spin(a, stop7)
	await _until(func() -> bool: return lift2.position.y <= low2 - 7.95 * TILE or not b.alive, 600)
	check(b.alive and b.global_position.y < 4 * TILE, "Б проехал пилу — наверху (%s)" % b.global_position)
	await _walk_to(b, KEYS_2, 50.0 * TILE)
	stop7[0] = true
	await _leave_wheel(a, 55.0 * TILE)
	# 5. Три колеса на двоих: Б крутит ближнее к воротам; А раскручивает дальнее, перебегает к среднему,
	# раскручивает и бежит в ворота; Б выпрыгивает следом.
	var w8: Wheel = level.get_node("Wheel8")
	var w9: Wheel = level.get_node("Wheel9")
	var w10: Wheel = level.get_node("Wheel10")
	var gate10: Door = level.get_node("Gate10")
	await _hop_exact(a, w8.global_position.x)  # А — к дальнему колесу (пока не крутит)
	await _walk_jumping(b, w10.global_position.x)
	var stop10 := [false]
	_spin(b, stop10)
	var stop8 := [false]
	_spin(a, stop8)
	await _until(func() -> bool: return w8.spin > 0.99, 300)
	stop8[0] = true
	await _leave_wheel(a, w9.global_position.x - 1.2 * TILE)
	await _hop_exact(a, w9.global_position.x)
	var stop9 := [false]
	_spin(a, stop9)
	await _until(func() -> bool: return w9.spin > 0.99, 300)
	check(gate10.is_open_requested(), "три колеса крутятся — ворота подняты (%.2f %.2f %.2f)" % [w8.spin, w9.spin, w10.spin])
	stop9[0] = true
	_leave_wheel(a, 73.5 * TILE, [b])
	# Б выпрыгивает, когда А пробегает мимо его колеса — в ворота следом
	await _until(func() -> bool: return a.global_position.x > w10.global_position.x - 0.5 * TILE, 300)
	stop10[0] = true
	await _leave_wheel(b, 72.5 * TILE)
	check(a.global_position.x > 72 * TILE, "А пробежал ворота, пока дальнее крутится по инерции (%s; %.2f)" % [a.global_position, w8.spin])
	check(b.global_position.x > 72 * TILE, "Б выпрыгнул следом — успел (%s)" % b.global_position)
	check(deaths == before, "без гибели (%d)" % (deaths - before))
	await _both_to_finish()


## Идёт к x (px), подпрыгивая, когда упёрся (подставки колёс) или впереди товарищ; останавливается точно.
func _walk_jumping(p: Player, x: float) -> void:
	var k := _keys(p)
	var other := b if p == a else a
	var still := 0
	var last := p.global_position.x
	var hold_jump := 0
	for i in 900:
		var dx := x - p.global_position.x
		if absf(dx) < 5.0 and p.is_on_floor():
			break
		var dir := signf(dx)
		still = still + 1 if absf(p.global_position.x - last) < 0.5 else 0
		last = p.global_position.x
		var ahead := (other.global_position.x - p.global_position.x) * dir
		if p.is_on_floor() and hold_jump == 0 and (still > 4 or (ahead > 0.0 and ahead < 1.3 * TILE and absf(other.global_position.y - p.global_position.y) < TILE)):
			hold_jump = 20
			still = 0
		press(k[JUMP], hold_jump > 0)
		hold_jump = maxi(hold_jump - 1, 0)
		# у цели — притормозить (в воздухе не перелететь)
		var near := absf(dx) < 0.6 * TILE
		press(k[RIGHT], dir > 0.0 and (not near or p.is_on_floor()))
		press(k[LEFT], dir < 0.0 and (not near or p.is_on_floor()))
		await get_tree().physics_frame
	for key in [k[LEFT], k[RIGHT], k[JUMP]]:
		press(key, false)
	await _land(p)


## Пила в шахте подъёмника не заденет ездока у x, если трогаться сейчас: пока подъёмник (после разгона
## колеса) проезжает высоту пилы — с 1,45 до 2,5 с — диск не над ездоком.
func _shaft_clear(saw: Saw, rider_x: float) -> bool:
	var prog := saw.progress
	var fwd := saw.forward
	var length := (saw.path_tiles * TILE).length()
	var t := 0.0
	var dt := 1.0 / 30.0
	while t < 2.5:
		t += dt
		prog += (1.0 if fwd else -1.0) * saw.speed * dt / length
		if prog >= 1.0:
			prog = 1.0
			fwd = false
		elif prog <= 0.0:
			prog = 0.0
			fwd = true
		if t > 1.45:
			var cx := saw.global_position.x + saw.path_tiles.x * TILE * prog
			if absf(cx - rider_x) < saw.radius() + Player.SIZE.x / 2.0 + 10.0:
				return false
	return true


## Крутит колесо: хват у колеса — встал в него; бежит на месте, пока stop[0] не станет true.
func _spin(p: Player, stop: Array) -> void:
	var k := _keys(p)
	await hold(k[GRAB], 4)
	press(k[RIGHT], true)
	while not stop[0] and p.alive:
		await get_tree().physics_frame
	press(k[RIGHT], false)


## Выпрыгнуть из колеса вправо и бежать к target_x.
func _leave_wheel(p: Player, target_x: float, threats := []) -> void:
	await _react()
	var k := _keys(p)
	press(k[RIGHT], true)
	press(k[JUMP], true)
	await frames(14)
	press(k[JUMP], false)
	await _dash(p, target_x, threats)
