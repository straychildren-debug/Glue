@tool
class_name HintSign
extends Node2D
## Табличка-подсказка у механизма: столбик с дощечкой и знаком «?». Пока рядом кто-то из
## игроков, её текст показывается плашкой внизу экрана (Game._update_sign_banner): в мире текст
## мельчал бы с камерой и налезал на стены. Подсказка — к догадке, которую не вывести из
## правил сама собой (например, взведённая пружина).
## Положение узла — основание столбика на уровне пола.

const GROUP := "hint_signs"
const OUTLINE := Color("1a1d33")
const WOOD := Color("b07a45")
const BOARD := Color("f3e2b8")

@export_multiline var text := "":
	set(value):
		text = value
		queue_redraw()
## Насколько близко (тайлы) должен подойти игрок, чтобы показалась подсказка.
@export var radius_tiles := 7.0


func _ready() -> void:
	z_index = -1  # за игроками и механизмами
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## Близко ли игрок: по горизонтали — radius_tiles, по вертикали — с запасом на прыжки.
func is_near(point: Vector2) -> bool:
	var offset := (point - global_position).abs()
	return offset.x <= radius_tiles * GreyboxLevel.TILE and offset.y <= (radius_tiles + 3.0) * GreyboxLevel.TILE


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if Art.enabled and Art.has("hint_sign"):
		# Табличка P19 (пустая доска), знак «?» — поверх, по середине доски (71 px над полом).
		var sprite := Art.tex("hint_sign")
		var size := Vector2(sprite.get_size()) / 4.0
		draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, -size.y + 0.75), size), false)
		draw_string(font, Vector2(-26, -59), "?", HORIZONTAL_ALIGNMENT_CENTER, 52, 34, OUTLINE)
	else:
		# Столбик и дощечка со знаком вопроса.
		draw_rect(Rect2(-5, -70, 10, 70), OUTLINE)
		draw_rect(Rect2(-3, -68, 6, 68), WOOD)
		var board := Rect2(-26, -104, 52, 40)
		draw_rect(board.grow(3.0), OUTLINE)
		draw_rect(board, BOARD)
		draw_string(font, Vector2(-26, -73), "?", HORIZONTAL_ALIGNMENT_CENTER, 52, 34, OUTLINE)
	if Engine.is_editor_hint() and text != "":
		draw_string(font, Vector2(-200, -120), text.replace("\n", " · "), HORIZONTAL_ALIGNMENT_CENTER, 400, 16, OUTLINE)
