class_name BackdropLayer
extends Node2D
## Один слой задника: дальний план, средний план или одиночный ориентир.
## Рисуется в экранных координатах (Backdrop — CanvasLayer); положение и масштаб считает
## Backdrop по камере каждый кадр. Параметры — в долях экрана, поэтому слой не зависит
## от разрешения окна.

@export var texture: Texture2D
## Доля движения камеры, с которой слой едет по горизонтали: 0 — стоит, 1 — как уровень.
@export_range(0.0, 1.0) var parallax := 0.2
## То же по вертикали: обычно меньше, чем по горизонтали.
@export_range(0.0, 1.0) var parallax_y := 0.05
## Высота слоя в долях высоты экрана.
@export var height := 1.0
## Где середина слоя по высоте экрана (0 — верх, 1 — низ), когда камера на опорной высоте уровня.
@export var center_y := 0.5
## Насколько слой уменьшается вместе с камерой: 0 — всегда одного размера на экране,
## 1 — как уровень. Немного (0,2–0,4) даёт ощущение глубины при отдалении.
@export_range(0.0, 1.0) var zoom_follow := 0.0
## Повторять по горизонтали (для бесшовных полос). Ориентир не повторяется.
@export var repeat := true
## Для ориентира: x в мире уровня (px), где он стоит, когда камера смотрит в эту точку.
@export var world_x := 0.0
## Цвет слоя: приглушить или подсинить, не перерисовывая картинку (только затемняет).
@export var tint := Color.WHITE
## Воздушная дымка: насколько слой уходит в цвет haze_color (0 — как нарисован).
## Так слой отодвигается вглубь и меньше спорит с игроками.
@export_range(0.0, 1.0) var haze := 0.0
@export var haze_color := Color("cfe2f5")

const HAZE_SHADER := """
shader_type canvas_item;
uniform vec4 haze_color : source_color;
uniform float haze = 0.0;
void fragment() {
	COLOR = vec4(mix(COLOR.rgb, haze_color.rgb, haze), COLOR.a);
}
"""
static var _haze_shader: Shader

var _origin := Vector2.ZERO  # левый верхний угол первой копии на экране
var _scale := 1.0
var _view_width := 0.0


func _ready() -> void:
	if haze <= 0.0:
		return
	if _haze_shader == null:
		_haze_shader = Shader.new()
		_haze_shader.code = HAZE_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _haze_shader
	shader_material.set_shader_parameter("haze_color", haze_color)
	shader_material.set_shader_parameter("haze", haze)
	material = shader_material


## Вызывает Backdrop: размер экрана, центр камеры и её масштаб, опорная высота уровня.
func update_view(view: Vector2, camera_center: Vector2, zoom: float, reference_y: float) -> void:
	if texture == null:
		return
	var size := Vector2(texture.get_size())
	_scale = view.y * height / size.y * lerpf(1.0, zoom, zoom_follow)
	var drawn := size * _scale
	var y := view.y * center_y - drawn.y / 2.0 - (camera_center.y - reference_y) * zoom * parallax_y
	var x: float
	if repeat:
		x = fposmod(-camera_center.x * zoom * parallax, drawn.x) - drawn.x
	else:
		x = view.x / 2.0 + (world_x - camera_center.x) * zoom * parallax - drawn.x / 2.0
	_origin = Vector2(x, y)
	_view_width = view.x
	modulate = tint
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var drawn := Vector2(texture.get_size()) * _scale
	var x := _origin.x
	while true:
		draw_texture_rect(texture, Rect2(Vector2(x, _origin.y), drawn), false)
		x += drawn.x
		if not repeat or x >= _view_width:
			break
