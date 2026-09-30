class_name Player
extends CharacterBody2D
## Игрок-прямоугольник: бег, прыжок, стояние на других игроках, «Замри» и хват.
## Связь хвата решает GrabLinks после движения всех игроков.
## Все значения — стартовые для настройки, не утверждённые (см. docs/06_параметры_и_решения.md).

signal died(player: Player)

const SIZE := Vector2(44, 56)
const COLORS: Array[Color] = [Color("e5484d"), Color("3e7bfa"), Color("f2c230"), Color("3fb950")]
const COLOR_NAMES: Array[String] = ["Красный", "Синий", "Жёлтый", "Зелёный"]
const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_CAMERA_WALLS := 4
const GROUP := "players"

@export var run_speed := 360.0
@export var ground_accel := 3000.0
@export var ground_friction := 3600.0
@export var air_accel := 1800.0
@export var air_friction := 900.0
@export var gravity := 2400.0
@export var fall_gravity_mult := 1.25
@export var max_fall_speed := 1400.0
## Высота прыжка ≈ jump_velocity² / (2 · gravity) ≈ 154 px ≈ 2,4 тайла.
@export var jump_velocity := 860.0
## Во сколько раз гасится скорость подъёма, если кнопку отпустили раньше.
@export var jump_cut_mult := 0.45
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var respawn_delay := 1.0
## Хват дотягивается до товарища, чей центр не дальше grab_range.
@export var grab_range := 100.0
## Длина «руки»: связь не даёт разойтись дальше этого расстояния между центрами.
@export var grab_arm_length := 100.0
## Прыжок с хвата сильнее обычного (≈ 208 px): из-под товарища на всю длину руки
## можно запрыгнуть ему на голову.
@export var hang_jump_velocity := 1000.0
## Сколько секунд после прыжка с хвата игрок минимум проходит сквозь товарищей по связи.
@export var pass_through_time := 0.35
## Какая доля скорости взлёта маятника добавляется к прыжку с хвата.
@export var hang_jump_carry := 0.6
## Ускорение раскачивания стиком, пока игрок висит на хвате.
@export var swing_accel := 1400.0
## В воздухе скорость выше run_speed (после маятника или катапульты) гаснет медленно.
@export var overspeed_air_drag := 250.0
## Наклон замершего: предельный угол и скорость поворота.
@export var max_tilt_deg := 25.0
@export var tilt_speed_deg := 600.0
## Катапульта: скорость, с которой резкий наклон подбрасывает стоящего сверху (≈ 275 px).
@export var catapult_speed := 1150.0

var slot := 0
var color := Color.WHITE
var alive := true
## «Замри»: игрок неподвижен в мире и служит твёрдой опорой и якорем для хвата.
var frozen := false
## За кого держится этот игрок (null — ни за кого) и максимальная длина связи.
var grab_target: Player = null
var grab_length := 0.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_rising := false
var _facing := 1
## После прыжка с хвата кнопку хвата нужно отпустить, иначе игрок сразу схватится снова.
var _grab_blocked := false
## Товарищи, сквозь которых игрок сейчас пролетает после прыжка с хвата: Player -> оставшееся время.
var _passing_through := {}
## Катапульта взведена: следующий резкий наклон из нейтрали подбросит стоящих сверху.
var _catapult_armed := true
var _style := StyleBoxFlat.new()
var _frozen_style := StyleBoxFlat.new()


func setup(p_slot: int) -> void:
	slot = p_slot
	color = COLORS[slot]
	name = "Player%d" % (slot + 1)


func _ready() -> void:
	add_to_group(GROUP)
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	$CollisionShape2D.shape = shape
	_enable_collisions(true)
	floor_snap_length = 6.0

	for style: StyleBoxFlat in [_style, _frozen_style]:
		style.set_border_width_all(3)
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.anti_aliasing = true
	_style.bg_color = color
	_style.border_color = color.darkened(0.45)
	# Замерший: темнее, с толстой светлой рамкой — читается как «камень».
	_frozen_style.bg_color = color.darkened(0.25)
	_frozen_style.border_color = Color(1, 1, 1, 0.85)
	_frozen_style.set_border_width_all(5)


func _physics_process(delta: float) -> void:
	var jump_pressed := InputRouter.take_jump_press(slot)
	var freeze_pressed := InputRouter.take_freeze_press(slot)
	if not alive:
		return
	if freeze_pressed:
		set_frozen(not frozen)
	_update_grab()
	queue_redraw()
	if frozen:
		velocity = Vector2.ZERO
		_update_tilt(delta)
		return

	var on_floor := is_on_floor()
	var holders := _holders()
	var hanging := not on_floor and (grab_target != null or not holders.is_empty())
	_coyote = coyote_time if on_floor else _coyote - delta
	_jump_buffer = jump_buffer_time if jump_pressed else _jump_buffer - delta

	if not on_floor:
		# На хвате гравитация одинакова вверх и вниз, иначе маятник сам набирает размах.
		var fall_mult := fall_gravity_mult if velocity.y > 0.0 and not hanging else 1.0
		velocity.y = minf(velocity.y + gravity * fall_mult * delta, max_fall_speed)

	if _jump_buffer > 0.0 and (_coyote > 0.0 or hanging):
		if hanging:
			_break_free(holders)
			# Взлёт маятника добавляется к прыжку: прыгать выгоднее на подъёме.
			velocity.y = minf(velocity.y, 0.0) * hang_jump_carry - hang_jump_velocity
		else:
			velocity.y = -jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_jump_rising = true
	elif _jump_rising and (velocity.y >= 0.0 or not InputRouter.is_jump_held(slot)):
		if velocity.y < 0.0:
			velocity.y *= jump_cut_mult
		_jump_rising = false

	var input_x := InputRouter.get_move_x(slot)
	if absf(input_x) > 0.01:
		_facing = signi(roundi(signf(input_x)))
	if hanging and grab_target == null and holders.is_empty():
		hanging = false  # только что вырвался прыжком
	if hanging:
		# Висит: трения нет, стик раскачивает, как на качелях.
		velocity.x += input_x * swing_accel * delta
	elif not on_floor and absf(velocity.x) > run_speed and signf(input_x) != -signf(velocity.x):
		# Разгон маятника или катапульты не обрезается до обычной скорости бега.
		velocity.x = move_toward(velocity.x, signf(velocity.x) * run_speed, overspeed_air_drag * delta)
	else:
		var rate: float
		if absf(input_x) > 0.01:
			rate = ground_accel if on_floor else air_accel
		else:
			rate = ground_friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, input_x * run_speed, rate * delta)

	# Стоящий на товарище едет вместе с ним: move_and_slide берёт скорость опоры сам.
	move_and_slide()
	_update_pass_through(delta)


func set_frozen(value: bool) -> void:
	frozen = value
	velocity = Vector2.ZERO
	_jump_rising = false
	rotation = 0.0
	_catapult_armed = true


## Замерший наклоняется стиком. Резкий наклон из нейтрали — катапульта:
## стоящие сверху улетают вдоль наклонённой поверхности, в сторону наклона.
func _update_tilt(delta: float) -> void:
	var input_x := InputRouter.get_move_x(slot)
	var side := 0 if absf(input_x) < 0.5 else signi(roundi(signf(input_x)))
	var neutral := absf(rotation) < deg_to_rad(5.0)
	if side == 0 and neutral:
		_catapult_armed = true
	elif side != 0 and not neutral and signf(rotation) == -side:
		_catapult_armed = true  # перекладка с одного бока на другой — тоже бросок
	if side != 0 and neutral and _catapult_armed:
		_catapult_armed = false
		_launch_riders(side)
	rotation = move_toward(rotation, deg_to_rad(max_tilt_deg) * side, deg_to_rad(tilt_speed_deg) * delta)


func _launch_riders(side: int) -> void:
	var tilt := deg_to_rad(max_tilt_deg)
	var direction := Vector2(side * sin(tilt), -cos(tilt))
	for other: Player in get_tree().get_nodes_in_group(GROUP):
		if other != self and other.alive and not other.frozen and other.standing_on() == self:
			other.launch(direction * catapult_speed)


## На ком из игроков стоит этот игрок (null — ни на ком).
func standing_on() -> Player:
	if not is_on_floor():
		return null
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.5 and collision.get_collider() is Player:
			return collision.get_collider()
	return null


## Бросок катапультой: скорость задаётся целиком, отпускание прыжка его не гасит.
func launch(launch_velocity: Vector2) -> void:
	velocity = launch_velocity
	_jump_rising = false
	_coyote = 0.0
	_jump_buffer = 0.0


## Хват держится, пока зажата кнопка; при зажатой кнопке рядом с товарищем — хватает ближайшего.
func _update_grab() -> void:
	if not InputRouter.is_grab_held(slot):
		_grab_blocked = false
		release_grab()
		return
	if grab_target != null and not grab_target.alive:
		release_grab()
	if grab_target != null or _grab_blocked:
		return
	var nearest: Player = null
	var nearest_distance := grab_range
	for other: Player in get_tree().get_nodes_in_group(GROUP):
		if other == self or not other.alive:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance <= nearest_distance:
			nearest = other
			nearest_distance = distance
	if nearest != null:
		grab_target = nearest
		grab_length = maxf(nearest_distance, grab_arm_length)


func release_grab() -> void:
	grab_target = null


## Товарищи, которые держатся за этого игрока.
func _holders() -> Array[Player]:
	var result: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group(GROUP):
		if other.grab_target == self:
			result.append(other)
	return result


## Прыжок с хвата: разжимаются и свои руки, и руки тех, кто держит этого игрока,
## поэтому висящий сам выбирает момент прыжка. Горизонтальный разгон маятника сохраняется.
## Сквозь товарищей по связи игрок пролетает — так можно забраться им на голову (живая лестница).
func _break_free(holders: Array[Player]) -> void:
	if grab_target != null:
		_pass_through(grab_target)
		release_grab()
		_grab_blocked = true
	for holder in holders:
		_pass_through(holder)
		holder.release_grab()
		holder._grab_blocked = true


## Временно отключает столкновения с товарищем, пока хитбоксы не разойдутся.
## Держится не меньше pass_through_time: на длинной руке прыгающий ещё не касается товарища.
func _pass_through(other: Player) -> void:
	if not _passing_through.has(other):
		add_collision_exception_with(other)
		other.add_collision_exception_with(self)
	_passing_through[other] = pass_through_time


func _update_pass_through(delta: float) -> void:
	for other in _passing_through.keys():
		if not is_instance_valid(other):
			_passing_through.erase(other)
			continue
		_passing_through[other] -= delta
		var offset: Vector2 = (other.global_position - global_position).abs()
		if _passing_through[other] <= 0.0 and (offset.x >= SIZE.x or offset.y >= SIZE.y):
			_stop_passing(other)


func _end_pass_through() -> void:
	for other in _passing_through.keys():
		_stop_passing(other)
	_passing_through.clear()


func _stop_passing(other: Player) -> void:
	_passing_through.erase(other)
	if is_instance_valid(other):
		remove_collision_exception_with(other)
		other.remove_collision_exception_with(self)


## Сдвиг от связи хвата: скользит вдоль препятствий, не проходит сквозь них.
func push(offset: Vector2) -> void:
	var collision := move_and_collide(offset)
	if collision:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))


func die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	velocity = Vector2.ZERO
	release_grab()
	_end_pass_through()
	_enable_collisions(false)
	died.emit(self)


## Пауза до общего респавна команды.
func pause_for_respawn() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO


func respawn(at: Vector2) -> void:
	set_physics_process(true)
	global_position = at
	velocity = Vector2.ZERO
	set_frozen(false)
	release_grab()
	_end_pass_through()
	_grab_blocked = true  # зажатая кнопка не должна сразу схватить соседа по респавну
	_coyote = 0.0
	# Нажатия во время паузы не должны сработать после появления.
	InputRouter.take_jump_press(slot)
	InputRouter.take_freeze_press(slot)
	_jump_buffer = 0.0
	_jump_rising = false
	_enable_collisions(true)
	alive = true
	visible = true


func _enable_collisions(enabled: bool) -> void:
	collision_layer = LAYER_PLAYERS if enabled else 0
	collision_mask = (LAYER_WORLD | LAYER_PLAYERS | LAYER_CAMERA_WALLS) if enabled else 0


func _draw() -> void:
	# Рука тянется к товарищу, за которого держится игрок.
	if grab_target != null:
		var to_target := to_local(grab_target.global_position)
		var dir := to_target.normalized()
		var start := dir * SIZE.x * 0.35
		var end := to_target - dir * SIZE.x * 0.35
		draw_line(start, end, color.darkened(0.45), 11.0)
		draw_line(start, end, color, 7.0)
		draw_circle(end, 7.0, color.darkened(0.45))
		draw_circle(end, 5.0, color)
	elif InputRouter.is_grab_held(slot) and not _grab_blocked:
		# Кнопка зажата, но хватать некого: руки вытянуты вперёд.
		var hand := Vector2(_facing * (SIZE.x * 0.5 + 12.0), 0.0)
		draw_line(Vector2(_facing * SIZE.x * 0.3, 0.0), hand, color.darkened(0.45), 7.0)
		draw_circle(hand, 6.0, color)

	draw_style_box(_frozen_style if frozen else _style, Rect2(-SIZE / 2.0, SIZE))
	var eye_center := Vector2(_facing * 6.0, -SIZE.y * 0.16)
	for eye_x in [-7.0, 7.0]:
		if frozen:
			# Замерший «зажмурился».
			var eye := eye_center + Vector2(eye_x, 0.0)
			draw_line(eye - Vector2(4, 0), eye + Vector2(4, 0), Color.BLACK, 2.5)
		else:
			# Глаза смотрят в сторону движения, как у персонажей концепт-листа.
			draw_set_transform(eye_center + Vector2(eye_x, 0.0), 0.0, Vector2(1.0, 1.6))
			draw_circle(Vector2.ZERO, 3.6, Color.BLACK)
			draw_set_transform(Vector2.ZERO)
