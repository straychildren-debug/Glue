@tool
class_name PressurePlate
extends AnimatableBody2D
## Нажимная плита: активна, пока нагрузка не меньше порога. Нагрузку дают игроки и ящики,
## стоящие на ней прямо или стопкой, и висящие на руке у стоящих. С защёлкой плита,
## нажатая один раз, остаётся нажатой (до сброса к чекпоинту).
## Положение узла — середина плиты на уровне пола.

signal changed(active: bool)

const RAISED := 14.0
const PRESSED := 4.0
## Края плиты — скосы такой длины: ящик въезжает на плиту, а не упирается в ступеньку.
const RAMP := 28.0

@export var width_tiles := 2.0:
	set(value):
		width_tiles = value
		queue_redraw()
## Порог нагрузки для двух игроков (в массах игрока).
@export var threshold := 1.0:
	set(value):
		threshold = value
		queue_redraw()
## Добавка к порогу за каждого игрока сверх двух: один уровень на 2/3/4 игрока.
@export var threshold_per_extra_player := 0.0
@export var latch := false:
	set(value):
		latch = value
		queue_redraw()
## Плита отпускается не сразу: подпрыгнувший на ней не мигает дверью.
@export var release_delay := 0.15
@export var sink_speed := 120.0

var active := false
var current_load := 0.0
var _release_timer := 0.0
var _base := Vector2.ZERO
var _label: Label


func _ready() -> void:
	var shape := ConvexPolygonShape2D.new()
	shape.points = _outline()
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(Weight.CARRIERS)
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	process_physics_priority = 20
	_base = position
	# Отладка: нагрузка / порог над плитой.
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	_label.position = Vector2(-40, -48)
	_label.size = Vector2(80, 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func required_load() -> float:
	var players := get_tree().get_nodes_in_group(Player.GROUP).size()
	return threshold + threshold_per_extra_player * maxi(players - 2, 0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	current_load = Weight.total_on(self)
	var pressed := current_load >= required_load() - 0.01
	if pressed:
		_release_timer = release_delay
	else:
		_release_timer -= delta
	if pressed and not active:
		_set_active(true)
	elif active and not latch and _release_timer <= 0.0:
		_set_active(false)
	var sink := RAISED - PRESSED if active else 0.0
	position.y = move_toward(position.y, _base.y + sink, sink_speed * delta)
	Player.follow_carrier(self)
	_label.text = "%s / %s" % [_format(current_load), _format(required_load())]


func _set_active(value: bool) -> void:
	active = value
	queue_redraw()
	changed.emit(active)


func save_state() -> Variant:
	return active and latch


func load_state(state: Variant) -> void:
	_release_timer = 0.0
	if active != state:
		_set_active(state)
	position = _base + Vector2(0, RAISED - PRESSED if active else 0.0)


static func _format(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


## Трапеция плиты: низ на уровне пола, по бокам — скосы.
func _outline() -> PackedVector2Array:
	var half := width_tiles * GreyboxLevel.TILE / 2.0 - 4.0
	return PackedVector2Array([
		Vector2(-half, 0), Vector2(-half + RAMP, -RAISED), Vector2(half - RAMP, -RAISED), Vector2(half, 0)])


func _draw() -> void:
	var color := Color("f2994a") if active else Color("c2410c")
	if latch:
		color = Color("a78bfa") if active else Color("6d28d9")
	var outline := _outline()
	draw_colored_polygon(outline, color)
	outline.append(outline[0])
	draw_polyline(outline, color.darkened(0.4), 2.0)
