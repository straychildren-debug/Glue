@tool
class_name Turntable
extends AnimatableBody2D
## Поворотный круг: балка на оси поворачивается на 90° — лежит мостом через пропасть или стоит столбом.
## Пока триггеры (рычаг, плиты) активны, балка в положении «вкл», иначе — «выкл» (invert меняет местами).
## Заклинивает: ящик или замерший, лежащий на балке, не даёт ей повернуться, пока он там, — мост
## остаётся мостом при любом рычаге. Живой на поворачивающейся балке её не держит — съезжает.
## Положение узла — ось (середина балки).

const OUTLINE := Color("1a1d33")
const THICKNESS := 0.5

@export var length_tiles := 6.0:
	set(value):
		length_tiles = value
		queue_redraw()
## Угол балки (градусы): выкл — обычно 0 (мост), вкл — 90 (столб).
@export var off_degrees := 0.0:
	set(value):
		off_degrees = value
		if Engine.is_editor_hint():
			rotation_degrees = value
@export var on_degrees := 90.0
@export var triggers: Array[NodePath] = []
@export var invert := false
## Скорость поворота, градусы в секунду.
@export var turn_speed := 180.0
@export var mark_color := Color(0, 0, 0, 0):
	set(value):
		mark_color = value
		queue_redraw()
## Цвета меток — по одному на триггер. Полосы вдоль балки: сплошная — «включено — мост»,
## пунктир — «включено — столб» (как у дверей: пунктир — обратная).
@export var mark_colors: Array[Color] = []:
	set(value):
		mark_colors = value
		queue_redraw()

var jammed := false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length_tiles * GreyboxLevel.TILE, THICKNESS * GreyboxLevel.TILE)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, THICKNESS * GreyboxLevel.TILE / 2.0)  # верх балки — на оси
	add_child(collision)
	rotation_degrees = off_degrees
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	process_physics_priority = 25  # после рычагов и плит
	_snap.call_deferred()


## С начала уровня — сразу в своём положении, без поворота на глазах.
func _snap() -> void:
	rotation_degrees = on_degrees if is_on() else off_degrees


func is_on() -> bool:
	var count := 0
	for path in triggers:
		var node := get_node_or_null(path)
		if node != null and node.active:
			count += 1
	return (count > 0) != invert


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := on_degrees if is_on() else off_degrees
	if is_equal_approx(rotation_degrees, target):
		jammed = false
		return
	jammed = _jammed()
	if jammed:
		queue_redraw()
		return
	rotation_degrees = move_toward(rotation_degrees, target, turn_speed * delta)
	queue_redraw()


## На балке лежит ящик или стоит замерший — держат её.
func _jammed() -> bool:
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		if crate.visible and Weight.floor_below(crate) == self:
			return true
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.frozen and Weight.probe_below(player) == self:
			return true
	return false


func save_state() -> Variant:
	return rotation_degrees


func load_state(state: Variant) -> void:
	rotation_degrees = state
	jammed = false
	queue_redraw()


func _draw() -> void:
	var t := GreyboxLevel.TILE
	var half := length_tiles * t / 2.0
	var h := THICKNESS * t
	# Балка: доски с железными обоймами; ось — круг с болтом; заклинило — красные искры у оси.
	if Art.enabled and Art.has("w2_turn_beam"):
		draw_texture_rect(Art.tex("w2_turn_beam"), Rect2(-half, -2.0, half * 2.0, h + 4.0), false)  # N4
		var hub := 0.8 * t
		draw_texture_rect(Art.tex("w2_turn_hub"), Rect2(-hub / 2.0, h / 2.0 - hub / 2.0, hub, hub), false)
		_draw_marks(half, h)
		_draw_jam(h)
		return
	draw_rect(Rect2(-half, 0, half * 2.0, h), OUTLINE)
	draw_rect(Rect2(-half + 3, 3, half * 2.0 - 6, h - 6), Color("a87c4a"))
	var boards := maxi(2, int(length_tiles))
	for i in range(1, boards):
		var x := -half + half * 2.0 * i / boards
		draw_line(Vector2(x, 3), Vector2(x, h - 3), OUTLINE, 2.0)
	for x in [-half + 10.0, half - 16.0]:
		draw_rect(Rect2(x, 0, 6, h), Color("5b6470"))
	draw_circle(Vector2(0, h / 2.0), h * 0.75, OUTLINE)
	draw_circle(Vector2(0, h / 2.0), h * 0.55, Color("8a919c"))
	draw_circle(Vector2(0, h / 2.0), h * 0.2, OUTLINE)
	_draw_marks(half, h)
	_draw_jam(h)


## Полосы меток по обе стороны от оси. «Мост, когда включено» — по смыслу: on_degrees — мост.
func _draw_marks(half: float, h: float) -> void:
	var colors: Array[Color] = []
	for color in [mark_color] + mark_colors:
		if color.a > 0.0:
			colors.append(color)
	if colors.is_empty():
		return
	var dashed := invert != (absf(on_degrees) > 45.0)  # пунктир: включено — столб
	var band_h := 6.0
	var y0 := h / 2.0 - (colors.size() * (band_h + 3.0) - 3.0) / 2.0
	for i in colors.size():
		var y := y0 + i * (band_h + 3.0)
		for side in [-1.0, 1.0]:
			var x0 := h * 0.9 if side > 0 else -half + 14.0
			var x1 := half - 14.0 if side > 0 else -h * 0.9
			draw_rect(Rect2(x0 - 2.0, y - 2.0, x1 - x0 + 4.0, band_h + 4.0), OUTLINE)
			if not dashed:
				draw_rect(Rect2(x0, y, x1 - x0, band_h), colors[i])
			else:
				var x := x0
				while x < x1:
					draw_rect(Rect2(x, y, minf(12.0, x1 - x), band_h), colors[i])
					x += 24.0


func _draw_jam(h: float) -> void:
	if jammed:
		for i in 3:
			var a := float(i) * 2.1 + Time.get_ticks_msec() * 0.01
			draw_line(Vector2(0, h / 2.0) + Vector2.from_angle(a) * h, Vector2(0, h / 2.0) + Vector2.from_angle(a) * h * 1.5, Color("ff6040"), 3.0)
