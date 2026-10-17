@tool
class_name Beetle
extends CharacterBody2D
## Жук-толкатель (E2): ползёт по платформе, у края и у стены разворачивается. Упёрся в игрока —
## толкает его перед собой (может спихнуть с края). Ящик, замерший товарищ и другой жук его
## останавливают — он разворачивается. На жуке можно ехать; замерший на нём едет как груз.
## На плите жук весит 1 — его можно заманить на плиту. Не убивает.
## В шипы не заходит (разворачивается, как у края); занесло в шипы (лента, порыв) — лопается
## и через respawn_time появляется на своём месте: мостом над шипами не служит.
## Бросок (aggressive): увидел героя впереди на своей высоте — замирает на windup_time (видно,
## что сейчас бросится) и разгоняется до charge_speed — быстрее бега героя; толкает в шипы и с края.
## Врезавшись в стену, ящик, замершего или жука — оглушён на daze_time.
## Отбойник (knockback): ударил героя сбоку — тот отлетает, а не сдвигается.
## Положение узла — центр жука.

const OUTLINE := Color("1a1d33")
const SIZE := Vector2(72, 56)

@export var speed := 110.0
@export_enum("Влево:-1", "Вправо:1") var direction := 1:
	set(value):
		direction = value
		queue_redraw()
@export var gravity := 2400.0
@export var mass := 1.0
## Бросок на героя (уровни 11–20); без него жук только ходит и толкает.
@export var aggressive := false
@export var charge_speed := 540.0
@export var sight_tiles := 7.0
@export var windup_time := 0.3
@export var charge_time := 1.6
@export var daze_time := 1.0
## Через сколько секунд лопнувший в шипах жук появляется на своём месте.
@export var respawn_time := 2.5
## Отбойник: ударил героя сбоку — тот отлетает (у шипов и ям — гибель). Скорость отлёта
## от идущего жука и от бросающегося; вверх — общая.
@export var knockback := false
@export var knock_walk := 520.0
@export var knock_charge := 820.0
@export var knock_up := 460.0

enum Mode { WALK, WINDUP, CHARGE, DAZED, GONE }

var landing_speed := 0.0
var mode := Mode.WALK
var _mode_time := 0.0
var _home := Vector2.ZERO
var _home_dir := 1
var _walk := 0.0
var _launched := false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(Weight.GROUP)
	add_to_group(Weight.CARRIERS)
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Crate.LAYER_OBJECTS
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYERS | Crate.LAYER_OBJECTS
	floor_snap_length = 6.0
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	process_physics_priority = 4  # после игроков, до ящиков
	_home = global_position
	_home_dir = direction


func get_support() -> Node:
	return Weight.floor_below(self)


func get_rect() -> Rect2:
	return Rect2(global_position - SIZE / 2.0, SIZE)


func launch(launch_velocity: Vector2) -> void:
	velocity = launch_velocity
	_launched = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_mode_time += delta
	if mode == Mode.GONE:
		if _mode_time >= respawn_time and not _home_taken():
			_respawn()
		return
	if _in_spikes():
		_pop()
		return
	var on_floor := is_on_floor() and not _launched
	_launched = false
	_update_mode(on_floor)
	var run := _current_speed()
	if not on_floor:
		velocity.y = minf(velocity.y + gravity * delta, 1400.0)
	elif _ledge_ahead() or _spikes_ahead():
		_shove_off_edge()
		direction = -direction
		if mode == Mode.CHARGE:
			_set_mode(Mode.WALK)
	velocity.x = direction * run if on_floor else velocity.x
	var fall_speed := velocity.y
	move_and_slide()
	landing_speed = fall_speed if is_on_floor() and not on_floor else 0.0
	_walk += delta * (run / 20.0 if on_floor else 0.0)
	# Кто впереди: игрок — толкаем; ящик, замерший, жук или стена — разворот (с разбега — оглушён).
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().x * direction > -0.7:
			continue
		var other := collision.get_collider()
		if other is Player and not other.frozen and knockback:
			other.launch(Vector2(direction * (knock_charge if mode == Mode.CHARGE else knock_walk), -knock_up))
			if mode == Mode.CHARGE:
				_set_mode(Mode.WALK)
		elif other is Player and not other.frozen:
			var before: Vector2 = other.global_position
			other.push(Vector2(direction * (run * delta + 1.0), 0.0))
			if other.global_position.distance_to(before) < 0.5:
				direction = -direction  # толкаемому некуда (прижат к стене) — жук отступает
		else:
			direction = -direction
			if mode == Mode.CHARGE:
				_set_mode(Mode.DAZED)
		break
	Player.follow_carrier(self)
	queue_redraw()


func _current_speed() -> float:
	match mode:
		Mode.CHARGE:
			return charge_speed
		Mode.WINDUP, Mode.DAZED:
			return 0.0
	return speed


func _set_mode(value: Mode) -> void:
	mode = value
	_mode_time = 0.0


## Бросок: шёл — увидел героя → замах → бросок → устал или врезался → снова ходит.
func _update_mode(on_floor: bool) -> void:
	match mode:
		Mode.WALK:
			if aggressive and on_floor and _player_ahead():
				_set_mode(Mode.WINDUP)
		Mode.WINDUP:
			if _mode_time >= windup_time:
				_set_mode(Mode.CHARGE)
		Mode.CHARGE:
			if _mode_time >= charge_time:
				_set_mode(Mode.WALK)
		Mode.DAZED:
			if _mode_time >= daze_time:
				_set_mode(Mode.WALK)


## Живой незамерший герой впереди на той же высоте, ближе sight_tiles и не за стеной.
func _player_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if not player.alive or player.frozen or player.carrier == self:
			continue
		var d := player.global_position - global_position
		if d.x * direction <= 0.0 or absf(d.x) > sight_tiles * GreyboxLevel.TILE or absf(d.y) > SIZE.y * 0.6:
			continue
		var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, Player.LAYER_WORLD, [get_rid()])
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _spike_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for spikes in get_tree().get_nodes_in_group(Spikes.GROUP):
		rects.append(spikes.get_rect())
	return rects


## Впереди у ног — шипы: жук туда не идёт.
func _spikes_ahead() -> bool:
	var front := global_position.x + direction * (SIZE.x / 2.0 + 6.0)
	var probe := Rect2(minf(front, front + direction * 10.0), global_position.y + SIZE.y / 2.0 - 30.0, 10.0, 40.0)
	for rect in _spike_rects():
		if rect.intersects(probe):
			return true
	return false


func _in_spikes() -> bool:
	var body := get_rect().grow(-10.0)
	for rect in _spike_rects():
		if rect.intersects(body):
			return true
	return false


## Лопнул в шипах: исчезает и не держит ни игроков, ни ящики.
func _pop() -> void:
	_set_mode(Mode.GONE)
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.carrier == self:
			player.carrier = null


## Место появления занято другим жуком или героем — подождать: иначе встанет на него, и двое жуков
## друг на друге — стена, через которую не перепрыгнуть.
func _home_taken() -> bool:
	var home := Rect2(_home - SIZE / 2.0, SIZE).grow(8.0)
	for node in get_parent().get_children():
		if node != self and node is Beetle and (node as Beetle).mode != Mode.GONE:
			if home.intersects(Rect2((node as Beetle).global_position - SIZE / 2.0, SIZE)):
				return true
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if home.intersects(Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			return true
	return false


func _respawn() -> void:
	global_position = _home
	direction = _home_dir
	velocity = Vector2.ZERO
	visible = true
	collision_layer = Crate.LAYER_OBJECTS
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYERS | Crate.LAYER_OBJECTS
	_set_mode(Mode.WALK)


## У края жук разворачивается, а того, кто стоит вплотную перед отвалом, спихивает вниз.
func _shove_off_edge() -> void:
	var front := global_position.x + direction * SIZE.x / 2.0
	var zone := Rect2(minf(front, front + direction * 12.0), global_position.y - SIZE.y / 2.0, 12.0, SIZE.y)
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and not player.frozen and zone.intersects(Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			player.push(Vector2(direction * Player.SIZE.x * 0.7, 0.0))


## Впереди обрыв: под передним краем нет опоры.
func _ledge_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var front := global_position + Vector2(direction * (SIZE.x / 2.0 + 4.0), SIZE.y / 2.0 - 4.0)
	var query := PhysicsRayQueryParameters2D.create(front, front + Vector2(0, 24),
			Player.LAYER_WORLD | Crate.LAYER_OBJECTS, [get_rid()])
	return space.intersect_ray(query).is_empty()


func save_state() -> Variant:
	return [global_position, direction] if is_on_floor() and mode != Mode.GONE else [_home, _home_dir]


func load_state(state: Variant) -> void:
	_respawn()
	global_position = state[0]
	direction = state[1]
	velocity = Vector2.ZERO
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.carrier == self:
			player.carrier = null


func _draw() -> void:
	_draw_mood()
	if Art.enabled and Art.has("w2_beetle"):
		# P30: смотрит вправо (отвал справа), два шага по очереди. Рисунок шире и площе
		# коллизии: по высоте — вровень с ней (на панцирь встают), по ширине чуть сжат.
		var sprite := Art.tex("w2_beetle_2" if int(_walk / PI) % 2 == 1 and Art.has("w2_beetle_2") else "w2_beetle")
		var size := Vector2(sprite.get_size()) * Vector2(0.26, 0.335)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1.0))
		draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, SIZE.y / 2.0 - size.y + 3.0), size), false)
		draw_set_transform(Vector2.ZERO)
		return
	var d := float(direction)
	var half := SIZE / 2.0
	# Лапки шагают; панцирь-купол медного цвета; спереди — отвал-«бульдозер».
	for i in 3:
		var x := (-0.5 + i * 0.5) * half.x
		var swing := sin(_walk + i * 2.0) * 5.0
		draw_line(Vector2(x, half.y - 10), Vector2(x + swing, half.y), OUTLINE, 5.0)
	var shell := PackedVector2Array()
	for i in 13:
		var a := PI + i * PI / 12.0
		shell.append(Vector2(cos(a) * half.x * 0.9, half.y - 10 + sin(a) * (SIZE.y - 12)))
	draw_colored_polygon(shell, OUTLINE)
	var inner := PackedVector2Array()
	for p in shell:
		inner.append(Vector2(p.x * 0.88, (p.y - (half.y - 10)) * 0.84 + half.y - 12))
	draw_colored_polygon(inner, Color("b5652e"))
	draw_line(Vector2(0, -half.y + 4), Vector2(0, half.y - 12), OUTLINE, 3.0)
	for x in [-0.45, 0.45]:
		draw_circle(Vector2(x * half.x, -4), 4.0, Color("e0a040"))
	# Голова с глазами и отвал.
	var head := Vector2(d * half.x * 0.8, half.y - 16)
	draw_circle(head, 11.0, OUTLINE)
	draw_circle(head, 8.0, Color("6a3a1a"))
	draw_circle(head + Vector2(d * 4.0, -3), 2.5, Color.WHITE)
	var blade_x := d * (half.x + 2.0)
	draw_rect(Rect2(Vector2(minf(blade_x, blade_x - d * 8.0), -half.y + 8), Vector2(8, SIZE.y - 10)), OUTLINE)
	draw_rect(Rect2(Vector2(minf(blade_x, blade_x - d * 8.0) + 2.0, -half.y + 10), Vector2(4, SIZE.y - 14)), Color("d4a640"))


## Над жуком: «!» на замахе (сейчас бросится), кружок звёздочек — оглушён.
func _draw_mood() -> void:
	if mode == Mode.WINDUP:
		var y := -SIZE.y / 2.0 - 34.0 - sin(_mode_time * 40.0) * 3.0
		draw_rect(Rect2(-6, y - 26, 12, 30), OUTLINE)
		draw_rect(Rect2(-3, y - 23, 6, 24), Color("ffd23f"))
		draw_circle(Vector2(0, y + 14), 7.0, OUTLINE)
		draw_circle(Vector2(0, y + 14), 4.0, Color("ffd23f"))
	elif mode == Mode.DAZED:
		for i in 3:
			var a := _mode_time * 6.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 26.0, -SIZE.y / 2.0 - 12.0 + sin(a) * 8.0)
			draw_circle(p, 6.0, OUTLINE)
			draw_circle(p, 4.0, Color("ffe36e"))
