class_name LevelBot
extends SmokeTest
## Бот для автотестов уровней: пара игроков на двух раскладках клавиатуры проходит уровень
## честными нажатиями (бег, прыжок, «Замри», хват, катапульта, толкание ящиков, маятник).
## Подходы к задаче иногда сокращены телепортом. Наследуют stage5_smoke и тесты уровней 11–20.

const TILE := 64.0
## Раскладки: [влево, вправо, прыжок, замри, хват].
const KEYS_1: Array[Key] = [KEY_A, KEY_D, KEY_W, KEY_S, KEY_E]
const KEYS_2: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PERIOD]
enum { LEFT, RIGHT, JUMP, FREEZE, GRAB }

var game: Node
var a: Player
var b: Player


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


## Прыжок к target_x с торможением в воздухе: приземляется точно (±10 px) — на узкое место.
func _hop_exact(p: Player, target_x: float) -> void:
	var k := _keys(p)
	press(k[JUMP], true)
	for i in 100:
		await get_tree().physics_frame
		if i == 30:
			press(k[JUMP], false)
		var dx := target_x - p.global_position.x
		var v := p.velocity.x
		var dir := 0
		if absf(dx) > 4.0:
			dir = 1 if dx > 0.0 else -1
			var stopping := v * v / (2.0 * p.air_accel) + absf(v) / 30.0
			if v * dir > 0.0 and absf(dx) <= stopping:
				dir = -dir  # пора тормозить
		elif absf(v) > 20.0:
			dir = -1 if v > 0.0 else 1
		press(k[RIGHT], dir > 0)
		press(k[LEFT], dir < 0)
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
