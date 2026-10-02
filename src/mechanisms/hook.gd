@tool
class_name Hook
extends Node2D
## Крюк: неподвижная точка в мире, за которую хватаются, как за замершего товарища, —
## висеть, раскачиваться, прыгать с хвата, строить цепь (за висящего на крюке можно держаться).
## Для системы хвата (Player, GrabLinks) крюк — вечный якорь: живой, замерший, не сдвигается.
## Положение узла — точка хвата.

const GROUP := "grab_anchors"

## Свойства, которые хват спрашивает у цели (как у Player).
var alive := true
var frozen := true
var velocity := Vector2.ZERO


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## Связь хвата крюк не сдвигает.
func push(_offset: Vector2) -> void:
	pass


func is_on_floor() -> bool:
	return false


func _draw() -> void:
	# Железный крюк на кольце, вбитом в балку или скалу: тёмный контур, как у всего интерактивного.
	var outline := Color("1a1d33")
	var iron := Color("9aa3ad")
	draw_rect(Rect2(-9, -22, 18, 8), outline)
	draw_rect(Rect2(-6, -20, 12, 4), Color("6b7280"))
	draw_line(Vector2(0, -16), Vector2(0, -4), outline, 8.0)
	draw_line(Vector2(0, -16), Vector2(0, -4), iron, 4.0)
	draw_arc(Vector2(0, 4), 9.0, -PI * 0.5, PI * 1.15, 16, outline, 8.0)
	draw_arc(Vector2(0, 4), 9.0, -PI * 0.5, PI * 1.15, 16, iron, 4.0)
