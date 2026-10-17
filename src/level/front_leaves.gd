class_name FrontLeaves
extends Node2D
## Ветки переднего плана — рамка кадра, как на концепт-листе: входят в верхние углы экрана,
## темнее мира (ближе к камере, чем игроки) и чуть качаются. Держатся у краёв экрана при любом
## положении и масштабе общей камеры. Только декорация: в середину кадра не заходят.
## Создаёт GreyboxLevel, если у уровня включено front_leaves и есть задник.

const DIR := "res://assets/decals/world_01/game/"
## Ширина ветки — доля ширины экрана; насколько ветка уходит за верх и за бок экрана.
const WIDTH := 0.17
const OFF_TOP := 0.38
const OFF_SIDE := 0.03
const TINT := Color(0.6, 0.66, 0.56)
## Покачивание: амплитуда (градусы) и период (с).
const SWAY_DEG := 1.2
const SWAY_PERIOD := 5.0

var _left: Texture2D
var _right: Texture2D
var _time := 0.0
var _view := Vector2.ZERO


func _ready() -> void:
	z_index = 50  # над игроками и механизмами (HUD — свой CanvasLayer, он выше)
	_left = load(DIR + "w01_front_branch.png")
	_right = load(DIR + "w01_front_branch_2.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	modulate = TINT


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		visible = false
		return
	visible = Art.enabled
	_view = get_viewport().get_visible_rect().size
	var zoom := camera.zoom.x
	global_position = camera.get_screen_center_position() - _view / 2.0 / zoom
	scale = Vector2.ONE / zoom
	queue_redraw()


func _draw() -> void:
	if _view == Vector2.ZERO:
		return
	var sway := deg_to_rad(SWAY_DEG) * sin(_time * TAU / SWAY_PERIOD)
	_draw_branch(_left, false, sway)
	_draw_branch(_right, true, -sway * 0.8)


## Ветка из бокового края: точка крепления — у края экрана над верхом; правая — зеркально.
func _draw_branch(texture: Texture2D, right: bool, angle: float) -> void:
	var width := _view.x * WIDTH
	var size := Vector2(width, width * texture.get_height() / texture.get_width())
	var anchor := Vector2(_view.x if right else 0.0, -size.y * OFF_TOP)
	var side := -1.0 if right else 1.0
	draw_set_transform(anchor, angle * side, Vector2(side, 1.0))
	draw_texture_rect(texture, Rect2(Vector2(-_view.x * OFF_SIDE, 0.0), size), false)
	draw_set_transform(Vector2.ZERO)
