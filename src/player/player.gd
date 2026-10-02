class_name Player
extends CharacterBody2D
## Игрок-прямоугольник: бег, прыжок, стояние на других игроках, «Замри» и хват.
## Связь хвата решает GrabLinks после движения всех игроков.
## Вес игрока давит на плиты и качели (см. Weight), игрок толкает ящики.
## Все значения — стартовые для настройки, не утверждённые (см. docs/06_параметры_и_решения.md).

signal died(player: Player)

const SIZE := Vector2(44, 56)
const COLORS: Array[Color] = [Color("e5484d"), Color("3e7bfa"), Color("f2c230"), Color("3fb950")]
const COLOR_NAMES: Array[String] = ["Красный", "Синий", "Жёлтый", "Зелёный"]
const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_CAMERA_WALLS := 4
const GROUP := "players"
## Зазор над товарищем, на котором стоит игрок (px): больше safe_margin, незаметен глазу.
const STACK_GAP := 0.25

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
## Масса игрока: единица веса для плит, качелей и толкания ящиков.
@export var mass := 1.0

var slot := 0
var color := Color.WHITE
var alive := true
## «Замри»: игрок неподвижен в мире и служит твёрдой опорой и якорем для хвата.
var frozen := false
## За кого или за что держится этот игрок (товарищ или крюк, null — ни за что)
## и максимальная длина связи.
var grab_target: Node2D = null
var grab_length := 0.0
## Механизм, на котором замер игрок (ящик, качели, плита): замерший едет вместе с ним.
var carrier: Node2D = null
## Скорость падения в кадре приземления (для удара по качелям), иначе 0.
var landing_speed := 0.0
## Ящик, который игрок толкал в прошлом кадре (сам или через товарища впереди), и направление.
var pushing: Crate = null
var pushing_dir := 0

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
## Наклон замершего; поворот игрока = наклон + поворот механизма, на котором он замер.
var _tilt := 0.0
var _carrier_local := Vector2.ZERO
var _carrier_rotation := 0.0
var _style := StyleBoxFlat.new()
var _frozen_style := StyleBoxFlat.new()
var _sprite: PlayerSprite

## Куда смотрит игрок: 1 — вправо, -1 — влево.
var facing: int:
	get:
		return _facing


func setup(p_slot: int) -> void:
	slot = p_slot
	color = COLORS[slot]
	name = "Player%d" % (slot + 1)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Weight.GROUP)
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

	_sprite = PlayerSprite.new()
	add_child(_sprite)
	_sprite.setup(self)


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
		landing_speed = 0.0
		pushing = null
		_update_tilt(delta)
		_apply_carrier_transform()
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
	# Держащий смотрит на того, кого держит: рука тянется вперёд, а не из-за спины.
	if grab_target != null and absf(grab_target.global_position.x - global_position.x) > 6.0:
		_facing = signi(roundi(signf(grab_target.global_position.x - global_position.x)))
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
	var fall_speed := velocity.y
	move_and_slide()
	# Нижний игрок «отодвигается» от стоящего на нём в пределах safe_margin и уходит в пол,
	# пока не застрянет. Стоящий на товарище держится чуть выше — нижний его не касается.
	if standing_on() != null:
		global_position.y -= STACK_GAP
	landing_speed = fall_speed if is_on_floor() and not on_floor else 0.0
	_update_push(input_x)
	_update_pass_through(delta)


## Упёрся сбоку в ящик — толкает его. Упёрся в товарища, который толкает ящик, — толкает вместе
## с ним (паровозик): так тяжёлый ящик сдвигают вдвоём. Толкающий идёт со скоростью ящика.
func _update_push(input_x: float) -> void:
	var direction := 0 if absf(input_x) < 0.01 else signi(roundi(signf(input_x)))
	var target: Crate = null
	if direction != 0 and is_on_floor():
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			if collision.get_normal().x * direction > -0.7:
				continue
			var collider := collision.get_collider()
			if collider is Crate:
				target = collider
			elif collider is Player and collider.pushing != null and collider.pushing_dir == direction:
				target = collider.pushing
			if target != null:
				break
	pushing = target
	pushing_dir = direction if target != null else 0
	if target != null:
		target.add_push(direction, mass)
		velocity.x = direction * minf(run_speed, target.push_speed)


func set_frozen(value: bool) -> void:
	frozen = value
	velocity = Vector2.ZERO
	_jump_rising = false
	_tilt = 0.0
	rotation = 0.0
	_catapult_armed = true
	carrier = null
	if frozen:
		var below := Weight.probe_below(self)
		if below != null and below.is_in_group(Weight.CARRIERS):
			carrier = below
			_carrier_local = below.global_transform.affine_inverse() * global_position
			_carrier_rotation = below.global_rotation


## Замершие на механизме едут вместе с ним. Механизм вызывает это после своего движения.
static func follow_carrier(moved: Node2D) -> void:
	for player: Player in moved.get_tree().get_nodes_in_group(GROUP):
		if player.carrier == moved and player.frozen:
			player._apply_carrier_transform()


func _apply_carrier_transform() -> void:
	if carrier != null and not is_instance_valid(carrier):
		carrier = null
	if carrier == null:
		rotation = _tilt
		return
	global_position = carrier.global_transform * _carrier_local
	rotation = _tilt + carrier.global_rotation - _carrier_rotation


## Прямая опора для расчёта веса: на чём стоит, на ком висит, на чём замер.
## Замерший в воздухе опоры не имеет — он якорь.
func get_support() -> Node:
	if not alive:
		return null
	if frozen:
		return carrier if carrier != null else Weight.probe_below(self)
	var below := Weight.floor_below(self)
	if below != null:
		return below
	# Висит на руке: вес уходит тому, кто выше по натянутой связи.
	if grab_target != null and _hangs_from(grab_target, grab_length):
		return grab_target
	for holder in _holders():
		if _hangs_from(holder, holder.grab_length):
			return holder
	return null


func _hangs_from(other: Node2D, length: float) -> bool:
	return other.alive and other.global_position.y < global_position.y - 8.0 \
			and global_position.distance_to(other.global_position) >= length - 4.0


## Замерший наклоняется стиком. Резкий наклон из нейтрали — катапульта:
## стоящие сверху улетают вдоль наклонённой поверхности, в сторону наклона.
func _update_tilt(delta: float) -> void:
	var input_x := InputRouter.get_move_x(slot)
	var side := 0 if absf(input_x) < 0.5 else signi(roundi(signf(input_x)))
	var neutral := absf(_tilt) < deg_to_rad(5.0)
	if side == 0 and neutral:
		_catapult_armed = true
	elif side != 0 and not neutral and signf(_tilt) == -side:
		_catapult_armed = true  # перекладка с одного бока на другой — тоже бросок
	if side != 0 and neutral and _catapult_armed:
		_catapult_armed = false
		_launch_riders(side)
	_tilt = move_toward(_tilt, deg_to_rad(max_tilt_deg) * side, deg_to_rad(tilt_speed_deg) * delta)


func _launch_riders(side: int) -> void:
	var tilt := deg_to_rad(max_tilt_deg)
	var direction := Vector2(side * sin(tilt), -cos(tilt))
	# Подбрасывает всех, кто стоит сверху: игроков и ящики (не висящих на руке).
	for rider: Node2D in Weight.riders_of(self):
		if rider.global_position.y < global_position.y:
			rider.launch(direction * catapult_speed)


## На ком из игроков стоит этот игрок (null — ни на ком).
func standing_on() -> Player:
	return Weight.floor_below(self) as Player


## Бросок катапультой: скорость задаётся целиком, отпускание прыжка его не гасит.
func launch(launch_velocity: Vector2) -> void:
	if frozen:
		return  # замерший приклеен к месту
	velocity = launch_velocity
	_jump_rising = false
	_coyote = 0.0
	_jump_buffer = 0.0


## Хват держится, пока зажата кнопка; при зажатой кнопке рядом с товарищем или крюком —
## хватает ближайшего.
func _update_grab() -> void:
	if not InputRouter.is_grab_held(slot):
		_grab_blocked = false
		release_grab()
		return
	if grab_target != null and not grab_target.alive:
		release_grab()
	if grab_target != null or _grab_blocked:
		return
	if Lever.try_toggle(self):
		_grab_blocked = true  # нажатие ушло рычагу; до отпускания кнопки никого не хватаем
		return
	var nearest: Node2D = null
	var nearest_distance := grab_range
	var candidates := get_tree().get_nodes_in_group(GROUP) + get_tree().get_nodes_in_group(Hook.GROUP)
	for other: Node2D in candidates:
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


## Висит на руке: в воздухе и держит товарища или держат его.
func is_hanging() -> bool:
	return alive and not is_on_floor() and (grab_target != null or not _holders().is_empty())


## Кнопка хвата зажата, но хватать некого — руки вытянуты вперёд.
func is_reaching() -> bool:
	return alive and grab_target == null and not _grab_blocked and InputRouter.is_grab_held(slot)


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
		if grab_target is Player:
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


## Механизм толкает замершего (выдвигающийся мост, заслонка): замерший остаётся замершим,
## просто стоит теперь в другом месте. Проверить, свободно ли там, должен механизм (test_move).
func shove(offset: Vector2) -> void:
	global_position += offset
	if carrier != null and is_instance_valid(carrier):
		_carrier_local = carrier.global_transform.affine_inverse() * global_position


## Сдвиг от связи хвата: скользит вдоль препятствий, не проходит сквозь них.
func push(offset: Vector2) -> void:
	var collision := move_and_collide(offset)
	if collision:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))


func die() -> void:
	if not alive:
		return
	if visible:
		JellyBurst.burst(self)  # лопнул брызгами
	alive = false
	visible = false
	velocity = Vector2.ZERO
	carrier = null
	pushing = null
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
	if _sprite:
		_sprite.pop_in()
	JellyBurst.pop(self)


func _enable_collisions(enabled: bool) -> void:
	collision_layer = LAYER_PLAYERS if enabled else 0
	collision_mask = (LAYER_WORLD | LAYER_PLAYERS | LAYER_CAMERA_WALLS | Crate.LAYER_OBJECTS) if enabled else 0


func _draw() -> void:
	if Art.enabled:
		_draw_sprite_arm()
		return
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


## Рука хвата поверх спрайтов: из плеча дальней руки к товарищу (или вперёд, если хватать
## некого). Рисуется до спрайта-ребёнка, поэтому уходит за тело — как рука из-за плеча.
## Стиль модели: цвет тела с тёмным контуром и округлая кисть.
func _draw_sprite_arm() -> void:
	if not alive or not (grab_target != null or is_reaching()):
		return
	var start := _sprite.shoulder_local()
	var end: Vector2
	if grab_target != null:
		var to_target := to_local(grab_target.global_position)
		end = to_target - (to_target - start).normalized() * SIZE.x * 0.3
	else:
		end = start + Vector2(_facing * 20.0, 2.0).rotated(-rotation)
	var outline := PlayerSprite.OUTLINE_COLOR
	for pass_index in 2:
		var width := 12.0 if pass_index == 0 else 7.0
		var fill := outline if pass_index == 0 else color
		draw_line(start, end, fill, width)
		draw_circle(start, width / 2.0, fill)
		draw_circle(end, width / 2.0 + 2.5, fill)
