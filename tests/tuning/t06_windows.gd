extends LevelBot
## Замер окон уровня 06: для каждой связки «кнопка — проход» перебирает кадр нажатия кнопки
## при одинаковых действиях бегущего и печатает удачные кадры. Бегущий трогается на кадре
## RUN_DELAY отсчёта, поэтому видны и нажатия раньше его старта. Ширина окна — сколько времени
## подряд нажатие ещё приводит к успеху.
## Запуск: Godot_console --headless --fixed-fps 60 --path . res://tests/tuning/t06_windows.tscn [-- w1] [-- 1 2 … 10]
## w1 — версия мира 1 (w01_l11): связки 3 и 9 без лент.

var LEVEL: PackedScene = preload("res://levels/trial/t06_relay.tscn")
var world1 := false
## Где камера на каждой связке (тайлы по x).
const CENTERS := {"1": 9.0, "2": 12.0, "3": 17.0, "4": 23.0, "5": 29.0, "6": 31.0, "7": 37.0, "8": 38.0,
		"9": 45.0, "10": 46.0}
## На каком кадре отсчёта трогается бегущий.
const RUN_DELAY := 40
## С какой стороны кнопки (по её x) ждёт нажимающий: +1 — справа, иначе слева.
const SIDES := {23.6: 1, 28.0: 1, 33.0: 1, 41.0: 1, 49.6: 1}
const LAST_FRAME := 160


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	if "w1" in only:
		world1 = true
		LEVEL = load("res://levels/w01_l11_relay.tscn")
		only.erase("w1")
	game = await start_game(LEVEL)
	for seg: String in CENTERS:
		if not only.is_empty() and seg not in only:
			continue
		var ok: Array[int] = []
		for frame in range(0, LAST_FRAME + 1, 4):
			await _load(LEVEL)
			a = game.players[0]
			b = game.players[1]
			# Края кадра — стены: на время переноса камеры и игроков их выключаем, иначе стена
			# прежнего кадра выталкивает перенесённых (а новая — оставшихся на старте).
			var camera: SharedCamera = game.get_node("SharedCamera")
			var walls: Array = [camera.get("_wall_left"), camera.get("_wall_right"), camera.get("_wall_top")]
			for wall: StaticBody2D in walls:
				wall.collision_layer = 0
			camera.snap_to(Vector2(CENTERS[seg] * TILE, 8 * TILE))
			_restore_walls(walls)
			if await call("_seg" + seg, frame):
				ok.append(frame - RUN_DELAY)
		print("seg %s: удачные нажатия (кадр относительно старта бегущего) %s → окно ≈ %.2f с" % [
				seg, ok, (ok.size() * 4) / 60.0])
	get_tree().quit()


## Стены кадра включаются обратно, когда игроки уже перенесены (через несколько кадров).
func _restore_walls(walls: Array) -> void:
	await frames(6)
	for wall: StaticBody2D in walls:
		wall.collision_layer = Player.LAYER_CAMERA_WALLS


## Нажимающий стоит в 0,9 тайла от кнопки (как бот) и в кадр отсчёта шагает на неё. Сторона —
## где есть место: сразу за воротами до кнопки полтайла, там не встать.
func _hover(p: Player, x: float, floor_row: float) -> void:
	var side: int = SIDES.get(x, -1)
	place(p, Vector2((x + 0.9 * side) * TILE, _stand_y(floor_row)))
	p.set_meta("button_x", x)


## Отсчёт: в кадр frame нажимающий шагает на кнопку; ждёт RUN_DELAY кадров.
func _countdown(presser: Player, frame: int) -> void:
	_press_timer(presser, frame)
	await frames(RUN_DELAY)


func _press_timer(p: Player, frame: int) -> void:
	await frames(frame)
	if not is_instance_valid(p):
		return
	var k := _keys(p)
	var x: float = p.get_meta("button_x")
	var dir := 1.0 if x * TILE > p.global_position.x else -1.0
	var key := k[RIGHT] if dir > 0.0 else k[LEFT]
	press(key, true)
	for i in 30:
		await get_tree().physics_frame
		if not is_instance_valid(p) or (x * TILE - p.global_position.x) * dir <= 6.0:
			break
	press(key, false)


## Ждёт фазы препятствия так, чтобы бегущий тронулся ровно в ней после отсчёта: дождаться
## условия, переждать период без RUN_DELAY — условие повторится как раз к концу отсчёта.
func _sync_phase(presser: Player, frame: int, ready: Callable, period: float) -> void:
	for i in 600:
		if ready.call():
			break
		await get_tree().physics_frame
	await frames(roundi(period * 60.0) - RUN_DELAY)
	await _countdown(presser, frame)


func _saw_period(saw: Saw) -> float:
	return 2.0 * saw.path_tiles.length() * TILE / saw.speed


func _press_period(p: Node) -> float:
	var travel: float = p.drop_tiles * TILE
	return travel / p.fall_speed + p.bottom_wait + travel / p.rise_speed + p.top_wait


## Бег вправо до x (тайлы); перепрыгивает пилы на полу (из списка), если они едут навстречу;
## у jump_at (тайлы) прыгает — в ворота, которые могут уже подниматься.
func _go(p: Player, k: Array[Key], x: float, saws: Array = [], jump_at := INF) -> bool:
	press(k[RIGHT], true)
	var hold := 0
	var gate_jump := false
	for f in 300:
		if not gate_jump and hold == 0 and p.is_on_floor() and p.global_position.x >= jump_at * TILE:
			hold = 18
			gate_jump = true
		for saw: Saw in saws:
			var dx: float = saw.global_position.x + saw.path_tiles.x * TILE * saw.progress - p.global_position.x
			var closing: float = p.velocity.x - saw.speed * (1.0 if saw.forward else -1.0)
			if hold == 0 and p.is_on_floor() and dx > 0.0 and closing > 50.0 and (dx - 48.0) / closing < 0.22:
				hold = 18
		press(k[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		await get_tree().physics_frame
		if not p.alive or p.global_position.x > x * TILE:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	return p.alive and p.global_position.x > x * TILE


## Разбег и прыжок у края edge (тайлы) до x.
func _go_jump(p: Player, k: Array[Key], edge: float, x: float) -> bool:
	press(k[RIGHT], true)
	var hold := 0
	var jumped := false
	for f in 240:
		if not jumped and p.is_on_floor() and p.global_position.x >= edge * TILE:
			hold = 18
			jumped = true
		press(k[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		await get_tree().physics_frame
		if not p.alive or p.global_position.x > x * TILE:
			break
	press(k[RIGHT], false)
	press(k[JUMP], false)
	return p.alive and p.global_position.x > x * TILE


## 1. Б с 6.0 бежит и прыгает через яму у края в ворота GateL1; А жмёт оранжевую.
func _seg1(frame: int) -> bool:
	_hover(a, 8.5, 7)
	place(b, Vector2(6.0 * TILE, _stand_y(12)))
	await frames(20)
	await _countdown(a, frame)
	return await _go_jump(b, KEYS_2, 9.4, 13.0)


## 2. А с 9.2 — под вертикальной пилой (внизу, пошла вверх) в ворота GateU1; Б жмёт синюю.
func _seg2(frame: int) -> bool:
	var saw: Saw = game.level.get_node("SawU")
	_hover(b, 14.0, 12)
	place(a, Vector2(9.2 * TILE, _stand_y(7)))
	await _sync_phase(b, frame, func() -> bool: return saw.progress > 0.9 and saw.progress < 0.95 and not saw.forward, _saw_period(saw))
	return await _go(a, KEYS_1, 15.6)


## 3. Б с 14.3 прыгает на ленту и с неё — в ворота GateL2; А жмёт зелёную.
## Мир 1: Б с 16.0 прыгает через яму под пилой (пила у правого конца) прямо в ворота GateL2.
func _seg3(frame: int) -> bool:
	if world1:
		var saw: Saw = game.level.get_node("SawOverPit")
		_hover(a, 17.5, 7)
		place(b, Vector2(16.0 * TILE, _stand_y(12)))
		await _sync_phase(a, frame, func() -> bool: return saw.forward and saw.progress >= 0.5 and saw.progress < 0.55, _saw_period(saw))
		return await _go_jump(b, KEYS_2, 16.35, 20.6)
	_hover(a, 17.5, 7)
	place(b, Vector2(14.3 * TILE, _stand_y(12)))
	await frames(10)
	await _countdown(a, frame)
	press(KEYS_2[RIGHT], true)
	var hold := 0
	var jumps := 0
	for f in 240:
		if hold == 0 and b.is_on_floor() and (jumps == 0 and b.global_position.x >= 14.5 * TILE or jumps > 0 and b.global_position.x > 15.7 * TILE):
			jumps += 1
			hold = 18
		press(KEYS_2[JUMP], hold > 0)
		hold = maxi(hold - 1, 0)
		await get_tree().physics_frame
		if not b.alive or b.global_position.x > 22.6 * TILE:
			break
	press(KEYS_2[RIGHT], false)
	press(KEYS_2[JUMP], false)
	return b.alive and b.global_position.x > 22.6 * TILE


## 4. А с 22.0 — под прессом (поднимается, уже выше головы) в ворота GateU2; Б жмёт фиолетовую.
func _seg4(frame: int) -> bool:
	var p: Node = game.level.get_node("PressU")
	_hover(b, 23.6, 12)
	place(a, Vector2(22.0 * TILE, _stand_y(7)))
	await _sync_phase(b, frame, func() -> bool: return p.get("_state") == 3 and p.position.y < 120.0 and p.position.y > 100.0, _press_period(p))
	return await _go(a, KEYS_1, 26.9)


## 5. Б через пилу на полу (едет навстречу) в ворота GateL3; А жмёт жёлтую.
func _seg5(frame: int) -> bool:
	var saw: Saw = game.level.get_node("SawL")
	_hover(a, 28.0, 7)
	place(b, Vector2(26.6 * TILE, _stand_y(12)))
	await _sync_phase(a, frame, func() -> bool: return not saw.forward and saw.progress > 0.8 and saw.progress < 0.85, _saw_period(saw))
	return await _go(b, KEYS_2, 31.8, [saw], 30.2)


## 6. А под двумя вертикальными пилами в ворота GateU3; Б жмёт бирюзовую.
func _seg6(frame: int) -> bool:
	var saw: Saw = game.level.get_node("SawU2")
	_hover(b, 33.0, 12)
	place(a, Vector2(29.1 * TILE, _stand_y(7)))
	await _sync_phase(b, frame, func() -> bool: return saw.progress < 0.55 and saw.progress > 0.5 and not saw.forward, _saw_period(saw))
	return await _go(a, KEYS_1, 33.6)


## 7. Б с площадки в тайл между ямами — прыжок в ворота GateL4; А жмёт розовую.
func _seg7(frame: int) -> bool:
	_hover(a, 35.0, 7)
	place(b, Vector2(36.7 * TILE, _stand_y(12)))
	await frames(10)
	await _countdown(a, frame)
	return await _go_jump(b, KEYS_2, 36.7, 40.2)


## 8. А под широким прессом в ворота GateU4; Б жмёт белую.
func _seg8(frame: int) -> bool:
	var p: Node = game.level.get_node("PressU2")
	_hover(b, 41.0, 12)
	place(a, Vector2(35.9 * TILE, _stand_y(7)))
	await _sync_phase(b, frame, func() -> bool: return p.get("_state") == 3 and p.position.y < 132.0 and p.position.y > 112.0, _press_period(p))
	return await _go(a, KEYS_1, 41.4)


## 9. Б: лента вперёд, прыжок через яму у края — в ворота GateL5; А жмёт салатовую.
## Мир 1: Б перепрыгивает пилу навстречу и сразу яму у ворот.
func _seg9(frame: int) -> bool:
	if world1:
		var saw: Saw = game.level.get_node("SawL2")
		_hover(a, 42.9, 7)
		place(b, Vector2(42.0 * TILE, _stand_y(12)))
		await _sync_phase(a, frame, func() -> bool: return not saw.forward and saw.progress > 0.8 and saw.progress < 0.85, _saw_period(saw))
		return await _go(b, KEYS_2, 49.1, [saw], 46.75)
	_hover(a, 42.9, 7)
	place(b, Vector2(41.6 * TILE, _stand_y(12)))  # левее — на скате ленты её уже тащит
	await frames(10)
	await _countdown(a, frame)
	return await _go_jump(b, KEYS_2, 46.1, 49.1)


## 10. А через пилу на полу (навстречу) в ворота GateU5; Б жмёт коричневую.
func _seg10(frame: int) -> bool:
	var saw: Saw = game.level.get_node("SawU4")
	_hover(b, 49.6, 12)
	place(a, Vector2(43.1 * TILE, _stand_y(7)))
	await _sync_phase(b, frame, func() -> bool: return not saw.forward and saw.progress > 0.8 and saw.progress < 0.85, _saw_period(saw))
	return await _go(a, KEYS_1, 48.7, [saw])
