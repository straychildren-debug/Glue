@tool
class_name KeyLock
extends Node2D
## Замок: открывается, когда к нему подходит носитель ключа (DoorKey), и дальше держит
## свою заслонку открытой, как защёлка. Для двери, моста, ступеньки — это обычный триггер
## (свойство active). Удобно класть дочерним узлом двери — тогда уезжает вместе с ней.
## Положение узла — середина замка.

## Носитель ключа открывает замок, когда его центр ближе этого (px) к замку.
const REACH := 100.0

var active := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	z_index = 1
	process_physics_priority = 31  # после ключей


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or active:
		return
	for key: DoorKey in get_tree().get_nodes_in_group(DoorKey.GROUP):
		if key.used or key.carrier == null:
			continue
		if key.carrier.global_position.distance_to(global_position) <= REACH:
			key.use()
			active = true
			queue_redraw()
			return


func save_state() -> Variant:
	return active


func load_state(state: Variant) -> void:
	active = state
	queue_redraw()


func _draw() -> void:
	var outline := Color("1a1d33")
	if active:
		# Открытый замок: пустая скоба.
		draw_arc(Vector2(0, -10), 9.0, PI, TAU, 12, outline, 6.0)
		draw_arc(Vector2(0, -10), 9.0, PI, TAU, 12, Color("ffe58a"), 3.0)
		return
	draw_rect(Rect2(-17, -6, 34, 30), outline)
	draw_arc(Vector2(0, -6), 11.0, PI, TAU, 14, outline, 8.0)
	draw_arc(Vector2(0, -6), 11.0, PI, TAU, 14, Color("9aa3ad"), 4.0)
	draw_rect(Rect2(-14, -3, 28, 24), Color("f2c230"))
	draw_circle(Vector2(0, 6), 4.5, outline)
	draw_rect(Rect2(-2, 6, 4, 10), outline)
