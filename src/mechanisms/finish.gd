@tool
class_name Finish
extends Node2D
## Выход уровня. Уровень пройден, когда внутри все активные игроки: переход одного не считается.
## Положение узла — середина низа двери на уровне пола.

const GROUP := "finish"

@export var size_tiles := Vector2(2, 3):
	set(value):
		size_tiles = value
		queue_redraw()

## Сколько игроков внутри и сколько нужно — рисуется над дверью. Обновляет игра.
var inside := 0:
	set(value):
		if value != inside:
			inside = value
			queue_redraw()
var needed := 0:
	set(value):
		if value != needed:
			needed = value
			queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func get_rect() -> Rect2:
	var size := size_tiles * GreyboxLevel.TILE
	return Rect2(global_position + Vector2(-size.x / 2.0, -size.y), size)


func contains(player: Player) -> bool:
	return get_rect().has_point(player.global_position)


func _draw() -> void:
	var size := size_tiles * GreyboxLevel.TILE
	var rect := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	var done := needed > 0 and inside >= needed
	# Каменный проём с жёлтой аркой, как двери выхода на концепт-листе.
	draw_rect(rect.grow(10.0), Color("7c7f86"))
	draw_rect(rect, Color("2b2118"))
	var radius := size.x / 2.0
	draw_circle(Vector2(0, -size.y + radius), radius + 10.0, Color("f2c230") if not done else Color("7fdc5a"))
	draw_circle(Vector2(0, -size.y + radius), radius, Color("2b2118"))
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(size.x, size.y - radius)), Color("2b2118"))
	if needed > 0 and not Engine.is_editor_hint():
		var font := ThemeDB.fallback_font
		var text := "%d / %d" % [inside, needed]
		draw_string(font, Vector2(-40, -size.y - 24), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 28,
				Color("7fdc5a") if done else Color(0.1, 0.1, 0.12))
