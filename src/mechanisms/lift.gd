@tool
class_name Lift
extends Node2D
## Подъёмник: две площадки на одном тросе в соседних шахтах. Тяжёлая сторона опускается,
## лёгкая поднимается; скорость растёт с разницей нагрузки (Weight), при равенстве площадки стоят.
## Упоры сверху и снизу — пределы хода; фиксатор (lock, обычно защёлка) держит площадки на месте.
## Не давит: если площадка или стоящие на ней во что-то упираются (потолок, замерший в воздухе,
## игрок под площадкой), подъёмник останавливается.
## Положение узла — середина верха левой площадки при нулевом ходе; правая — на span_tiles правее.
## Ход offset > 0 — левая ниже, правая выше на столько же.

const DECK := 0.5 * GreyboxLevel.TILE

@export var width_tiles := 2.0:
	set(value):
		width_tiles = value
		queue_redraw()
## Расстояние между серединами площадок (тайлы).
@export var span_tiles := 4.0:
	set(value):
		span_tiles = value
		queue_redraw()
## Пределы хода левой площадки вниз (+) и вверх (−), тайлы.
@export var min_offset_tiles := -4.0
@export var max_offset_tiles := 4.0
@export var start_offset_tiles := 0.0:
	set(value):
		start_offset_tiles = value
		queue_redraw()
## Блоки троса — на столько тайлов выше самого высокого положения площадок.
@export var pulley_height_tiles := 2.0:
	set(value):
		pulley_height_tiles = value
		queue_redraw()
## Скорость на единицу разницы масс и предел скорости, px/с; разгон, px/с².
@export var speed_per_mass := 140.0
@export var max_speed := 280.0
@export var accel := 900.0
## Фиксатор: пока этот триггер активен, площадки стоят.
@export var lock: NodePath

var offset := 0.0
var speed := 0.0
var _left: AnimatableBody2D
var _right: AnimatableBody2D


func _ready() -> void:
	offset = start_offset_tiles * GreyboxLevel.TILE
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 20  # после игроков: их вес этого кадра уже известен
	_left = _make_platform("Left")
	_right = _make_platform("Right")
	_place_platforms()


func _make_platform(platform_name: String) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.name = platform_name
	body.collision_layer = Player.LAYER_WORLD
	body.collision_mask = 0
	body.sync_to_physics = true
	body.add_to_group(Weight.CARRIERS)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * GreyboxLevel.TILE, DECK)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, DECK / 2.0)
	body.add_child(collision)
	add_child(body)
	return body


func _place_platforms() -> void:
	_left.position = Vector2(0, offset)
	_right.position = Vector2(span_tiles * GreyboxLevel.TILE, -offset)


func get_platforms() -> Array[AnimatableBody2D]:
	return [_left, _right]


func is_locked() -> bool:
	if lock.is_empty():
		return false
	var trigger := get_node_or_null(lock)
	return trigger != null and trigger.active


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	queue_redraw()
	var diff := Weight.total_on(_left) - Weight.total_on(_right)
	var target := 0.0 if is_locked() else clampf(diff * speed_per_mass, -max_speed, max_speed)
	speed = move_toward(speed, target, accel * delta)
	var low := min_offset_tiles * GreyboxLevel.TILE
	var high := max_offset_tiles * GreyboxLevel.TILE
	var step := clampf(offset + speed * delta, low, high) - offset
	if is_zero_approx(step):
		speed = 0.0  # на упоре
		return
	# Левая едет на step, правая — на −step. Если хоть одна упрётся — стоят обе (один трос).
	if not _can_move(_left, step) or not _can_move(_right, -step):
		speed = 0.0
		return
	offset += step
	_place_platforms()
	Player.follow_carrier(_left)
	Player.follow_carrier(_right)


## Может ли площадка сдвинуться на dy: сама — не въезжая в чужие тела, стоящие на ней — не
## упираясь головой (их пробный сдвиг; столкновения внутри своей стопки не считаются).
func _can_move(platform: AnimatableBody2D, dy: float) -> bool:
	var riders := Weight.stack_on(platform)
	var size := Vector2(width_tiles * GreyboxLevel.TILE, DECK)
	var next := Rect2(platform.global_position + Vector2(-size.x / 2.0, dy), size)
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		# Замерший в воздухе над площадкой — упор, а не седок, хоть и висит над ней вплотную.
		var rides := riders.has(player) and (not player.frozen or player.carrier == platform)
		if player.alive and not rides \
				and next.intersects(Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			return false
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		if crate.visible and not riders.has(crate) and next.intersects(crate.get_rect()):
			return false
	if dy < 0.0:
		var collision := KinematicCollision2D.new()
		for body: PhysicsBody2D in riders:
			if body.test_move(body.global_transform, Vector2(0, dy), collision):
				var other := collision.get_collider()
				if other != platform and not riders.has(other):
					return false
	return true


func save_state() -> Variant:
	return offset


func load_state(state: Variant) -> void:
	offset = state
	speed = 0.0
	if _left:
		_place_platforms()
	queue_redraw()


func _draw() -> void:
	var tile := GreyboxLevel.TILE
	var width := width_tiles * tile
	var span := span_tiles * tile
	var left_y := offset
	var right_y := -offset
	if Engine.is_editor_hint():
		left_y = start_offset_tiles * tile
		right_y = -left_y
	var top := minf(min_offset_tiles, -max_offset_tiles) * tile - pulley_height_tiles * tile
	var outline := Color("1a1d33")
	# Трос: от каждой площадки вверх к своему блоку, блоки на общей балке.
	for x_y: Vector2 in [Vector2(0, left_y), Vector2(span, right_y)]:
		draw_line(Vector2(x_y.x, top), Vector2(x_y.x, x_y.y), outline, 5.0)
		draw_line(Vector2(x_y.x, top), Vector2(x_y.x, x_y.y), Color("c8b48a"), 2.5)
	draw_rect(Rect2(-width / 4.0, top - 20.0, span + width / 2.0, 12.0), outline)
	draw_rect(Rect2(-width / 4.0 + 2.0, top - 18.0, span + width / 2.0 - 4.0, 8.0), Color("8a5a30"))
	for x: float in [0.0, span]:
		draw_circle(Vector2(x, top), 15.0, outline)
		draw_circle(Vector2(x, top), 11.0, Color("9aa3ad"))
		draw_circle(Vector2(x, top), 4.0, outline)
	if lock.is_empty() == false and not Engine.is_editor_hint():
		var locked := is_locked()
		draw_circle(Vector2(span / 2.0, top - 14.0), 9.0, outline)
		draw_circle(Vector2(span / 2.0, top - 14.0), 6.0, Color("a78bfa") if locked else Color("6d28d9"))
	# Площадки — деревянные настилы.
	for x_y: Vector2 in [Vector2(0, left_y), Vector2(span, right_y)]:
		var rect := Rect2(x_y.x - width / 2.0, x_y.y, width, DECK)
		if Art.enabled:
			Art.draw_wood(self, rect)
		else:
			draw_rect(rect, Color("a0703f"))
			draw_rect(rect, Color("5a3a1c"), false, 3.0)
