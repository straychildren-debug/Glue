@tool
class_name Crate
extends CharacterBody2D
## Ящик: падает, толкается игроками, давит весом на плиты и качели, возит замершего.
## Тяжёлый ящик сдвигают только вдвоём (паровозиком: второй толкает первого).
## Упавший в пропасть ящик возвращается туда, где стоял при взятии чекпоинта.
## Положение узла — центр ящика.

const LAYER_OBJECTS := 8
const GROUP := "crates"

@export var size_tiles := Vector2(1, 1):
	set(value):
		size_tiles = value
		queue_redraw()
## Масса в «игроках»: 1 — как один игрок. Чтобы сдвинуть, толкающих нужно не меньше массы.
@export var mass := 1.0:
	set(value):
		mass = value
		queue_redraw()
@export var push_speed := 200.0
@export var gravity := 2400.0
@export var max_fall_speed := 1400.0
@export var ground_friction := 3000.0
## В воздухе ящик почти не тормозит: брошенный качелями, он летит дугой.
@export var air_friction := 60.0
## Через сколько секунд упавший ящик появляется снова.
@export var respawn_delay := 0.5

## Скорость падения в кадре приземления (для удара по качелям), иначе 0.
var landing_speed := 0.0
## Масса толкающих в этом кадре: направление (-1/1) -> сумма.
var _push := {}
var _home := Vector2.ZERO
var _respawn_timer := -1.0
var _launched := false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE - Vector2(2, 2)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(Weight.GROUP)
	add_to_group(Weight.CARRIERS)
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = LAYER_OBJECTS
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYERS | LAYER_OBJECTS
	floor_snap_length = 6.0
	# Скорость опоры при отрыве не добавляется: бросок качелей задаёт скорость сам, иначе ящик
	# получает её дважды и улетает вдвое выше игрока.
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	# После игроков: их толчки этого кадра уже собраны.
	process_physics_priority = 5
	_home = global_position


## Игрок упёрся в ящик сбоку и толкает его в сторону direction.
func add_push(direction: int, pusher_mass: float) -> void:
	_push[direction] = _push.get(direction, 0.0) + pusher_mass


## Прямоугольник ящика в мире.
func get_rect() -> Rect2:
	var size := size_tiles * GreyboxLevel.TILE - Vector2(2, 2)
	return Rect2(global_position - size / 2.0, size)


## Бросок катапультой или качелями.
func launch(launch_velocity: Vector2) -> void:
	velocity = launch_velocity
	_launched = true


func get_support() -> Node:
	if _respawn_timer >= 0.0:
		return null
	return Weight.floor_below(self)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			_appear()
		return

	# Брошенный ящик уже в полёте, хоть движок ещё и считает его стоящим: без трения о пол.
	var on_floor := is_on_floor() and not _launched
	_launched = false
	var direction := 0
	if on_floor:
		var right: float = _push.get(1, 0.0)
		var left: float = _push.get(-1, 0.0)
		if right >= mass and right > left:
			direction = 1
		elif left >= mass and left > right:
			direction = -1
	_push.clear()

	if not on_floor:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if direction != 0:
		velocity.x = direction * push_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, (ground_friction if on_floor else air_friction) * delta)

	var fall_speed := velocity.y
	move_and_slide()
	landing_speed = fall_speed if is_on_floor() and not on_floor else 0.0
	Player.follow_carrier(self)


## Упал за линию смерти: исчезает и появляется у точки чекпоинта.
func fall_out() -> void:
	if _respawn_timer >= 0.0:
		return
	_respawn_timer = respawn_delay
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	_release_frozen_riders()


func _appear() -> void:
	_respawn_timer = -1.0
	_place(_home)


func _place(at: Vector2) -> void:
	_release_frozen_riders()
	global_position = at
	velocity = Vector2.ZERO
	visible = true
	collision_layer = LAYER_OBJECTS
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYERS | LAYER_OBJECTS


## Замерший на ящике остаётся на месте, а не телепортируется вместе с ним.
func _release_frozen_riders() -> void:
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.carrier == self:
			player.carrier = null


## Состояние для чекпоинта: ящик вернётся сюда. Сохраняем только устойчивое положение.
func save_state() -> Variant:
	if _respawn_timer < 0.0 and is_on_floor():
		_home = global_position
	return _home


func load_state(state: Variant) -> void:
	_home = state
	_respawn_timer = -1.0
	_place(_home)


func _draw() -> void:
	if Art.enabled:
		var sprite_size := size_tiles * GreyboxLevel.TILE
		draw_texture_rect(Art.tex("crate_heavy" if mass > 1.0 else "crate"),
				Rect2(-sprite_size / 2.0, sprite_size), false)
		return
	var size := size_tiles * GreyboxLevel.TILE - Vector2(2, 2)
	var rect := Rect2(-size / 2.0, size)
	var wood := Color("b07a45") if mass <= 1.0 else Color("7a5230")
	draw_rect(rect, wood)
	draw_rect(rect, wood.darkened(0.45), false, 4.0)
	var inset := rect.grow(-8.0)
	draw_rect(inset, wood.darkened(0.25), false, 3.0)
	draw_line(inset.position, inset.end, wood.darkened(0.25), 3.0)
	draw_line(Vector2(inset.position.x, inset.end.y), Vector2(inset.end.x, inset.position.y), wood.darkened(0.25), 3.0)
	if mass > 1.0:
		# Тяжёлый ящик окован железом.
		for y in [inset.position.y, inset.end.y]:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("4b5563"), 6.0)
