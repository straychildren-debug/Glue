@tool
class_name Spinner
extends AnimatableBody2D
## Поворотная платформа (M2.3): балка на оси. Два режима:
## - с триггером (рычаг, плита) и step_deg — поворачивается на step_deg, пока триггер активен,
##   и обратно, когда нет (мост становится стеной и наоборот);
## - со spin_speed — медленно вращается всё время (с триггером — только пока он активен).
## Замерший на балке поворачивается вместе с ней — вращающийся якорь для хвата и маятника.
## Положение узла — ось.

const OUTLINE := Color("1a1d33")
const THICKNESS := 24.0

@export var length_tiles := 4.0:
	set(value):
		length_tiles = value
		queue_redraw()
## Угол балки в покое, градусы (0 — горизонтально).
@export var base_deg := 0.0:
	set(value):
		base_deg = value
		if Engine.is_editor_hint():
			rotation_degrees = value
@export var step_deg := 90.0
## Скорость поворота на шаг, градусы/с.
@export var turn_speed := 120.0
## Постоянное вращение, градусы/с (0 — нет).
@export var spin_speed := 0.0
@export var trigger: NodePath
## Ещё триггеры: балка повёрнута, пока активен любой из них (плиты на обоих берегах).
@export var triggers: Array[NodePath] = []

var _angle := 0.0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length_tiles * GreyboxLevel.TILE, THICKNESS)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	rotation_degrees = base_deg
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	add_to_group(Weight.CARRIERS)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	process_physics_priority = -5  # до игроков: они стоят на балке уже повёрнутой
	_angle = base_deg


func _has_trigger() -> bool:
	return not trigger.is_empty() or not triggers.is_empty()


func _is_on() -> bool:
	if not _has_trigger():
		return true
	for path in [trigger] + triggers:
		var node: Node = get_node_or_null(path) if not path.is_empty() else null
		if node != null and node.active:
			return true
	return false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if spin_speed != 0.0:
		if _is_on():
			_angle = fposmod(_angle + spin_speed * delta, 360.0)
	else:
		var target := base_deg + (step_deg if _has_trigger() and _is_on() else 0.0)
		_angle = move_toward(_angle, target, turn_speed * delta)
	rotation_degrees = _angle
	Player.follow_carrier(self)


func save_state() -> Variant:
	return _angle


func load_state(state: Variant) -> void:
	_angle = state
	rotation_degrees = _angle


func _draw() -> void:
	var half := length_tiles * GreyboxLevel.TILE / 2.0
	if Art.enabled and Art.has("w2_beam_mid"):
		# P22: брус с железными накладками и заклёпками, на оси — латунная ступица.
		Art.draw_strip_h(self, Rect2(-half, -12.85, half * 2.0, 25.7), "w2_beam_mid", "w2_beam_end")
		var hub := Art.tex("w2_hub")
		draw_texture_rect(hub, Rect2(Vector2(-20, -20), Vector2(40, 40)), false)
		return
	var rect := Rect2(-half, -THICKNESS / 2.0, half * 2.0, THICKNESS)
	draw_rect(rect, OUTLINE)
	draw_rect(rect.grow(-3.0), Color("a0703f"))
	# Железные накладки на концах и ступица на оси.
	for x in [-half + 10.0, half - 10.0]:
		draw_rect(Rect2(x - 6.0, -THICKNESS / 2.0 + 3.0, 12.0, THICKNESS - 6.0), Color("6b7280"))
	draw_circle(Vector2.ZERO, 16.0, OUTLINE)
	draw_circle(Vector2.ZERO, 12.0, Color("8a8f98"))
	for i in 6:
		draw_line(Vector2.ZERO, Vector2.from_angle(i * TAU / 6.0) * 10.0, OUTLINE, 2.0)
	draw_circle(Vector2.ZERO, 4.0, OUTLINE)
