@tool
class_name Seesaw
extends Node2D
## Качели: балка на шарнире. Перевешивает сторона, на которой больше вес (как весы):
## 2 против 1 — тяжёлая сторона опускается, 1 против 1 — балка стоит, где стояла. Где именно
## на своей половине стоит груз, неважно: загадки решает вес, а не пиксели от шарнира.
## Концом балка упирается в пол. Приземление на конец балки толкает её сильнее, чем простой вес;
## когда балка с разгона упирается в пол, стоящих на поднявшемся конце подбрасывает.
## Положение узла — шарнир (середина балки); пол — на pivot_height_tiles ниже.

const BEAM_THICKNESS := 16.0
## Сколько секунд балка помнит тех, кто на ней стоял (для броска).
const RIDER_MEMORY := 0.25
## Бросает тех, чей центр не выше этого над балкой: стопку из двух-трёх тел.
const RIDER_REACH := 160.0
## Стоящий почти над шарниром (ближе этого, px) ни одну сторону не перевешивает.
const PIVOT_DEAD_ZONE := 20.0

@export var length_tiles := 7.0:
	set(value):
		length_tiles = value
		queue_redraw()
@export var pivot_height_tiles := 1.0:
	set(value):
		pivot_height_tiles = value
		queue_redraw()
## Начальный наклон: -1 — левый конец внизу, 0 — ровно, 1 — правый внизу.
@export_range(-1, 1) var start_side := -1:
	set(value):
		start_side = value
		queue_redraw()
## Масса самой балки (в массах игрока); чем тяжелее, тем медленнее разгон.
@export var beam_mass := 2.0
@export var gravity := 2400.0
## Затухание угловой скорости, 1/с.
@export var damping := 1.0
## Удар приземления срабатывает, только если падали быстрее impact_threshold (px/с) — с высоты
## больше ≈ 3,5 тайла. Запрыгнуть на балку, перепрыгнуть товарища, ступить, отпустить «Замри»
## невысоко — балка не шелохнётся (1 против 1 стоит). Прыжок сверху с высоты — полноценный
## бросок; impact_mult — сила удара относительно неупругого.
@export var impact_threshold := 1150.0
@export var impact_mult := 1.6
## Подброс стоящих на поднявшемся конце: скорость = скорость конца × launch_mult.
@export var launch_mult := 2.4
## Медленнее этого (скорость конца, px/с) качели не подбрасывают.
@export var min_launch_speed := 250.0
## Фиксатор: пока этот триггер (обычно защёлка) активен, балка стоит в том наклоне, где её
## застали, — вес на ней ничего не меняет.
@export var lock: NodePath

var angle := 0.0
var angular_velocity := 0.0
var _beam: AnimatableBody2D
## Недавние седоки: тело -> сколько секунд ещё помнить.
var _recent_riders := {}


func max_angle() -> float:
	var half := length_tiles * GreyboxLevel.TILE / 2.0
	var drop := pivot_height_tiles * GreyboxLevel.TILE - BEAM_THICKNESS / 2.0
	return asin(clampf(drop / half, 0.0, 1.0))


func _ready() -> void:
	angle = max_angle() * start_side
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 20

	_beam = AnimatableBody2D.new()
	_beam.name = "Beam"
	_beam.collision_layer = Player.LAYER_WORLD
	_beam.collision_mask = 0
	_beam.sync_to_physics = true
	_beam.add_to_group(Weight.CARRIERS)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length_tiles * GreyboxLevel.TILE, BEAM_THICKNESS)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_beam.add_child(collision)
	_beam.rotation = angle
	add_child(_beam)

	# Опора под шарниром: сквозь неё не пройти.
	var base := StaticBody2D.new()
	base.name = "Base"
	base.collision_layer = Player.LAYER_WORLD
	base.collision_mask = 0
	var base_shape := RectangleShape2D.new()
	var height := pivot_height_tiles * GreyboxLevel.TILE - BEAM_THICKNESS
	base_shape.size = Vector2(24, height)
	var base_collision := CollisionShape2D.new()
	base_collision.shape = base_shape
	base_collision.position = Vector2(0, BEAM_THICKNESS / 2.0 + height / 2.0)
	base.add_child(base_collision)
	add_child(base)


func get_beam() -> AnimatableBody2D:
	return _beam


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var half := length_tiles * GreyboxLevel.TILE / 2.0
	var loads := Weight.loads_on(_beam)
	for body: Node2D in _recent_riders.keys():
		_recent_riders[body] -= delta
		if _recent_riders[body] <= 0.0 or not is_instance_valid(body):
			_recent_riders.erase(body)
	for body: Node2D in Weight.stack_on(_beam):
		if not (body is Player and body.frozen):
			_recent_riders[body] = RIDER_MEMORY
	if is_locked():
		angular_velocity = 0.0
		Player.follow_carrier(_beam)
		queue_redraw()
		return
	var inertia := beam_mass * pow(half * 2.0, 2) / 12.0
	var torque := 0.0
	for entry: Dictionary in loads:
		var arm: float = entry.contact.global_position.x - global_position.x
		inertia += entry.mass * arm * arm
		# Вес действует как на конце своей половины: важна сторона, а не плечо.
		if absf(arm) > PIVOT_DEAD_ZONE:
			torque += entry.mass * signf(arm) * half * gravity
	# Приземление: момент импульса падающего передаётся балке.
	for entry: Dictionary in loads:
		var speed: float = entry.body.landing_speed
		if speed >= impact_threshold:
			var arm: float = entry.contact.global_position.x - global_position.x
			angular_velocity += impact_mult * entry.mass * speed * arm / inertia

	angular_velocity += torque / inertia * delta
	angular_velocity *= exp(-damping * delta)
	angle += angular_velocity * delta
	var limit := max_angle()
	if absf(angle) >= limit and signf(angular_velocity) == signf(angle):
		angle = clampf(angle, -limit, limit)
		_launch_rising_side(half)
		angular_velocity = 0.0
	_beam.rotation = angle
	Player.follow_carrier(_beam)
	queue_redraw()


func is_locked() -> bool:
	if lock.is_empty():
		return false
	var trigger := get_node_or_null(lock)
	return trigger != null and trigger.active


## Балка с разгона упёрлась в пол: поднявшийся конец останавливается, а стоящие на нём летят дальше.
## Берём недавних седоков, а не только текущих: на резком подъёме стоящий отрывается от балки
## на кадр-другой раньше, чем она упрётся. Бросаем тех, кто ещё над своим концом балки.
func _launch_rising_side(half: float) -> void:
	var rising := -signf(angle)  # сторона, которая шла вверх
	for body: Node2D in _recent_riders:
		var arm: float = body.global_position.x - global_position.x
		if signf(arm) != rising:
			continue
		var height_above := global_position.y + tan(angle) * arm - body.global_position.y
		if height_above < 0.0 or height_above > RIDER_REACH:
			continue
		var speed := absf(angular_velocity) * minf(absf(arm), half) * cos(angle) * launch_mult
		if speed >= min_launch_speed and body.velocity.y > -speed:
			body.launch(Vector2(body.velocity.x, -speed))


func save_state() -> Variant:
	return angle


func load_state(state: Variant) -> void:
	angle = state
	angular_velocity = 0.0
	if _beam:
		_beam.rotation = angle


func _draw() -> void:
	var height := pivot_height_tiles * GreyboxLevel.TILE
	if Art.enabled:
		# Козлы 96×76: шарнир — точка (48, 12), низ — пол; под другую высоту тянутся по вертикали.
		draw_texture_rect(Art.tex("seesaw_base"), Rect2(-48, -12, 96, 12 + height), false)
		var half_length := length_tiles * GreyboxLevel.TILE / 2.0
		draw_set_transform(Vector2.ZERO, angle)
		Art.draw_strip_h(self, Rect2(-half_length, -BEAM_THICKNESS / 2.0, half_length * 2.0, BEAM_THICKNESS),
				"beam_mid", "beam_end")
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2.ZERO, 6.0, PlayerSprite.OUTLINE_COLOR)
		draw_circle(Vector2.ZERO, 4.0, Color("9aa3ad"))
		_draw_lock()
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-40, height), Vector2(40, height)]),
			Color("5b6470"))
	var half := length_tiles * GreyboxLevel.TILE / 2.0
	draw_set_transform(Vector2.ZERO, angle)
	var rect := Rect2(-half, -BEAM_THICKNESS / 2.0, half * 2.0, BEAM_THICKNESS)
	draw_rect(rect, Color("a0703f"))
	draw_rect(rect, Color("5a3a1c"), false, 3.0)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, 9.0, Color("3a3f47"))
	_draw_lock()


## Фиксатор у шарнира: фиолетовый, как защёлки; светится, когда держит балку.
func _draw_lock() -> void:
	if lock.is_empty() or Engine.is_editor_hint():
		return
	var locked := is_locked()
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, PlayerSprite.OUTLINE_COLOR, 7.0)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color("a78bfa") if locked else Color("6d28d9"), 4.0)
