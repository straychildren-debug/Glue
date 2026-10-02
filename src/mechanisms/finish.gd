@tool
class_name Finish
extends Node2D
## Выход уровня. Уровень пройден, когда внутри все активные игроки: переход одного не считается.
## Положение узла — середина низа двери на уровне пола.

const GROUP := "finish"
## Ворота в графике: кладка и мох — те же текстуры, что у платформ (Ground).
const GATE_STONE := "res://assets/tiles/world_01/game/w01_stone_fill.png"
const GATE_MOSS := "res://assets/tiles/world_01/game/w01_moss_top.png"
## Размеры, px: проём 2 тайла, пята арки на высоте 2 тайлов, кайма, камни рамы, швы, контур.
const GATE_OPENING := 128.0
const GATE_SPRING := 128.0
const GATE_TRIM := 6.0
const GATE_FRAME := 28.0
const GATE_JOINT := 2.5
const GATE_WEDGE_GAP := 1.2
const GATE_OUTLINE := 4.0
## Рисунок кладки на камнях ворот крупнее, чем на платформах: камень текстуры ≈ камень рамы.
const GATE_STONE_SCALE := 1.8
## Мох на арке — от этого угла до этого (градусы: 90 — верх).
const GATE_MOSS_FROM := 128.0
const GATE_MOSS_TO := 52.0
const GATE_DARK := Color("1a1d33")
const GATE_DEEP := Color("16121a")
const GATE_FLOOR := Color("3a2c22")

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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	if Art.enabled and size_tiles == Vector2(2, 3):
		_draw_gate(done)
		_draw_counter(size, done)
		return
	# Каменный проём с жёлтой аркой, как двери выхода на концепт-листе.
	draw_rect(rect.grow(10.0), Color("7c7f86"))
	draw_rect(rect, Color("2b2118"))
	var radius := size.x / 2.0
	draw_circle(Vector2(0, -size.y + radius), radius + 10.0, Color("f2c230") if not done else Color("7fdc5a"))
	draw_circle(Vector2(0, -size.y + radius), radius, Color("2b2118"))
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(size.x, size.y - radius)), Color("2b2118"))
	_draw_counter(size, done)


## Ворота из той же кладки, что платформы (Ground), — часть руин, а не наклейка поверх них:
## клинья арки и блоки опор с тёмными швами, общий тёмный контур (всё интерактивное обведено),
## мох на замковом камне, проём уходит в темноту. Тонкая кайма вокруг проёма — знак цели:
## жёлтая, зелёная, когда пришли все.
func _draw_gate(done: bool) -> void:
	var stone: Texture2D = load(GATE_STONE)
	var period := stone.get_size() / 2.0  # как у платформ: текстура вдвое крупнее экрана
	var center := Vector2(0, -GATE_SPRING)
	var trim_in := GATE_OPENING / 2.0
	var trim_out := trim_in + GATE_TRIM
	var outer := trim_out + GATE_FRAME
	# Контур и швы: тёмный силуэт ворот, камни ложатся поверх с зазором.
	draw_colored_polygon(_arch_shape(center, outer + GATE_OUTLINE), GATE_DARK)
	# Проём: сверху темно, к полу чуть светлее — проход вглубь руин.
	var opening := _arch_shape(center, trim_in)
	var shades := PackedColorArray()
	for point in opening:
		shades.append(GATE_DEEP.lerp(GATE_FLOOR, clampf(1.0 + point.y / (GATE_SPRING + trim_in), 0.0, 1.0)))
	draw_polygon(opening, shades)
	# Кайма — знак цели.
	var trim := Color("7fdc5a") if done else Color("f2c230")
	draw_colored_polygon(_ring(center, trim_in + GATE_JOINT, trim_out, 180.0, 0.0, 24), trim)
	for side: float in [-1.0, 1.0]:
		var x0 := side * (trim_in + GATE_JOINT)
		var x1 := side * trim_out
		draw_colored_polygon(PackedVector2Array([Vector2(minf(x0, x1), -GATE_SPRING),
				Vector2(maxf(x0, x1), -GATE_SPRING), Vector2(maxf(x0, x1), 0),
				Vector2(minf(x0, x1), 0)]), trim)
	# Клинья арки: свет слева сверху — правая половина чуть темнее.
	var wedges := 7
	for i in wedges:
		var a0 := 180.0 - i * 180.0 / wedges
		var a1 := 180.0 - (i + 1) * 180.0 / wedges
		var points := _ring(center, trim_out + GATE_JOINT, outer, a0 - GATE_WEDGE_GAP, a1 + GATE_WEDGE_GAP, 5)
		_stone(stone, period, points, i * 37.0, 1.0 if i < 3 else (0.94 if i == 3 else 0.86))
	# Опоры: по три блока, нижние крупнее.
	var rows := [[-GATE_SPRING, -GATE_SPRING + 40.0], [-GATE_SPRING + 40.0, -GATE_SPRING + 82.0],
			[-GATE_SPRING + 82.0, 0.0]]
	for side: float in [-1.0, 1.0]:
		for r in rows.size():
			var y0: float = rows[r][0] + GATE_JOINT / 2.0
			var y1: float = rows[r][1] - GATE_JOINT / 2.0
			var xa := side * (trim_out + GATE_JOINT)
			var xb := side * outer
			var points := PackedVector2Array([Vector2(minf(xa, xb), y0), Vector2(maxf(xa, xb), y0),
					Vector2(maxf(xa, xb), y1), Vector2(minf(xa, xb), y1)])
			_stone(stone, period, points, 91.0 * r + (0.0 if side < 0 else 53.0), 1.0 if side < 0 else 0.86)
	# Мох изгибается по верху арки (полоса мха платформ, согнутая по дуге): подушка лежит на камнях,
	# капли свисают по клиньям.
	var moss: Texture2D = load(GATE_MOSS)
	var moss_size := moss.get_size() / 2.0
	var r_top := outer + GATE_OUTLINE + moss_size.y * 0.17 - 3.0
	var r_bottom := r_top - moss_size.y
	var steps := 8
	for i in steps:
		var a0 := deg_to_rad(lerpf(GATE_MOSS_FROM, GATE_MOSS_TO, float(i) / steps))
		var a1 := deg_to_rad(lerpf(GATE_MOSS_FROM, GATE_MOSS_TO, float(i + 1) / steps))
		var d0 := Vector2(cos(a0), -sin(a0))
		var d1 := Vector2(cos(a1), -sin(a1))
		var u0 := (a0 - deg_to_rad(GATE_MOSS_FROM)) * r_top / moss_size.x
		var u1 := (a1 - deg_to_rad(GATE_MOSS_FROM)) * r_top / moss_size.x
		draw_polygon(PackedVector2Array([center + d0 * r_top, center + d1 * r_top,
				center + d1 * r_bottom, center + d0 * r_bottom]), PackedColorArray([Color.WHITE]),
				PackedVector2Array([Vector2(-u0, 0), Vector2(-u1, 0), Vector2(-u1, 1), Vector2(-u0, 1)]), moss)


## Камень ворот: многоугольник с текстурой кладки (сдвиг shift — у каждого камня свой узор).
func _stone(texture: Texture2D, period: Vector2, points: PackedVector2Array, shift: float, light: float) -> void:
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((point + Vector2(shift, shift * 0.6)) / (period * GATE_STONE_SCALE))
	draw_polygon(points, PackedColorArray([Color(light, light, light * 1.02)]), uvs, texture)


## Силуэт арки: прямоугольник от пола до пяты и полукруг радиуса radius сверху.
static func _arch_shape(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(-radius, 0)])
	for i in 25:
		var angle := deg_to_rad(180.0 - i * 180.0 / 24.0)
		points.append(center + Vector2(cos(angle), -sin(angle)) * radius)
	points.append(Vector2(radius, 0))
	return points


## Кольцевой сектор от угла a0 до a1 (градусы: 180 — слева, 90 — верх, 0 — справа).
static func _ring(center: Vector2, inner: float, outer: float, a0: float, a1: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := deg_to_rad(lerpf(a0, a1, float(i) / steps))
		points.append(center + Vector2(cos(angle), -sin(angle)) * outer)
	for i in steps + 1:
		var angle := deg_to_rad(lerpf(a1, a0, float(i) / steps))
		points.append(center + Vector2(cos(angle), -sin(angle)) * inner)
	return points


## «Внутри / нужно» над дверью.
func _draw_counter(size: Vector2, done: bool) -> void:
	if needed > 0 and not Engine.is_editor_hint():
		var font := ThemeDB.fallback_font
		var text := "%d / %d" % [inside, needed]
		draw_string(font, Vector2(-40, -size.y - 40), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 28,
				Color("7fdc5a") if done else Color(0.1, 0.1, 0.12))
