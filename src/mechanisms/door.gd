@tool
class_name Door
extends AnimatableBody2D
## Заслонка: пока активны её триггеры (плиты), уезжает на open_offset_tiles и возвращается обратно.
## Дверь уезжает в потолок или в пол, выдвижной мост — вбок из стены.
## Возвращаясь, не давит: если на пути игрок или ящик, останавливается.
## Положение узла — левый верхний угол в закрытом состоянии.

@export var size_tiles := Vector2(1, 3):
	set(value):
		size_tiles = value
		queue_redraw()
## Плиты и другие узлы со свойством `active`.
@export var triggers: Array[NodePath] = []
## true — нужны все триггеры сразу, false — любой.
@export var require_all := false
## Куда сдвигается открытая заслонка, в тайлах: (0, -3) — вверх на три тайла, (-5, 0) — мост влево.
@export var open_offset_tiles := Vector2(0, -3)
@export var open_speed := 480.0
@export var close_speed := 360.0

var _closed_position := Vector2.ZERO


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = shape.size / 2.0
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	# Позади блоков уровня: закрытая заслонка прячется в скале, а не торчит поверх неё.
	z_index = -1
	collision_layer = Player.LAYER_WORLD
	# Маска нужна только для проверки «не раздавить» при закрытии.
	collision_mask = Player.LAYER_PLAYERS | Crate.LAYER_OBJECTS
	sync_to_physics = true
	process_physics_priority = 25  # после плит
	_closed_position = position


func is_open_requested() -> bool:
	if triggers.is_empty():
		return false
	var count := 0
	for path in triggers:
		var trigger := get_node_or_null(path)
		if trigger != null and trigger.active:
			count += 1
	return count == triggers.size() if require_all else count > 0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_open_requested():
		var open_position := _closed_position + open_offset_tiles * GreyboxLevel.TILE
		position = position.move_toward(open_position, open_speed * delta)
		return
	var step := (_closed_position - position).limit_length(close_speed * delta)
	if step.is_zero_approx():
		return
	if test_move(global_transform, step):
		return  # на пути заслонки кто-то есть
	position += step


func save_state() -> Variant:
	return position


func load_state(state: Variant) -> void:
	position = state


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size_tiles * GreyboxLevel.TILE)
	if Art.enabled:
		if size_tiles.x > size_tiles.y:
			Art.draw_wood(self, rect)  # мост, ступенька, опускаемая площадка
		else:
			Art.draw_strip_v(self, rect, "door_mid", "door_end")
		return
	draw_rect(rect, Color("8b5e34"))
	# Доски: поперёк длинной стороны.
	var along_x := size_tiles.x > size_tiles.y
	var count := int((size_tiles.x if along_x else size_tiles.y) * 2)
	for i in range(1, count):
		var d := i * GreyboxLevel.TILE / 2.0
		if along_x:
			draw_line(Vector2(d, 3), Vector2(d, rect.size.y - 3), Color("6b4526"), 3.0)
		else:
			draw_line(Vector2(4, d), Vector2(rect.size.x - 4, d), Color("6b4526"), 3.0)
	draw_rect(rect, Color("4a2f18"), false, 4.0)
