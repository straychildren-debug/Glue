class_name SharedCamera
extends Camera2D
## Общая камера: держит в кадре прямоугольник всех живых игроков,
## плавно двигается и меняет масштаб, но не отдаляется дальше min_zoom.
## Левый, правый и верхний края кадра — невидимые стены (как в Pico Park):
## когда камера отдалилась до предела, игроки не могут разойтись дальше. Низ открыт — там пропасти.

## Поля вокруг игроков в пикселях мира.
@export var margin := Vector2(320, 220)
## Предельное отдаление (меньше — дальше). Стартовое значение, не утверждено.
@export var min_zoom := 0.6
@export var max_zoom := 1.0
@export var follow_speed := 5.0
@export var zoom_speed := 3.0

## Возвращает Array[Node2D] целей. Задаётся сценой игры.
var targets_source := func() -> Array: return []

var _wall_left := _make_wall(Vector2.RIGHT)
var _wall_right := _make_wall(Vector2.LEFT)
var _wall_top := _make_wall(Vector2.DOWN)
## Стены включаются только через пару физических кадров после появления камеры. Физика видит
## новое место стены лишь со следующего кадра, а до того стены стоят в начале координат:
## правая выталкивала бы влево игроков, появившихся вместе с уровнем.
var _walls_delay := 2


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	for wall in [_wall_left, _wall_right, _wall_top]:
		add_child(wall)


func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func snap_to(point: Vector2) -> void:
	global_position = point
	reset_smoothing()
	_update_walls()


## Видимая область мира с учётом масштаба и границ уровня.
func get_view_rect() -> Rect2:
	var half := get_viewport_rect().size / (2.0 * zoom)
	var center := global_position
	for axis in 2:
		var low := float(limit_left if axis == 0 else limit_top)
		var high := float(limit_right if axis == 0 else limit_bottom)
		if high - low <= half[axis] * 2.0:
			center[axis] = (low + high) / 2.0
		else:
			center[axis] = clampf(center[axis], low + half[axis], high - half[axis])
	return Rect2(center - half, half * 2.0)


func _physics_process(delta: float) -> void:
	var targets: Array = targets_source.call()
	if not targets.is_empty():
		var box := Rect2(targets[0].global_position, Vector2.ZERO)
		for target in targets:
			box = box.expand(target.global_position)
		box = box.grow_individual(margin.x, margin.y, margin.x, margin.y)

		var view := get_viewport_rect().size
		var fit := minf(view.x / box.size.x, view.y / box.size.y)
		var target_zoom := clampf(fit, min_zoom, max_zoom)
		zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 1.0 - exp(-zoom_speed * delta))
		global_position = global_position.lerp(box.get_center(), 1.0 - exp(-follow_speed * delta))
	_update_walls()
	if _walls_delay > 0:
		_walls_delay -= 1
		if _walls_delay == 0:
			for wall in [_wall_left, _wall_right, _wall_top]:
				wall.collision_layer = Player.LAYER_CAMERA_WALLS


func _update_walls() -> void:
	var view := get_view_rect()
	_wall_left.global_position = Vector2(view.position.x, view.get_center().y)
	_wall_right.global_position = Vector2(view.end.x, view.get_center().y)
	_wall_top.global_position = Vector2(view.get_center().x, view.position.y)


## Стена-полуплоскость: normal смотрит внутрь кадра, всё за линией твёрдое.
static func _make_wall(normal: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.top_level = true
	body.collision_layer = 0  # включается в _physics_process, см. _walls_delay
	body.collision_mask = 0
	var shape := WorldBoundaryShape2D.new()
	shape.normal = normal
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	return body
