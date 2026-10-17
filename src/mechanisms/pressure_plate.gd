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
## Кнопка: нажатие держит плиту активной только pulse секунд, потом она выскакивает; чтобы
## нажать снова — сойти и встать опять. Две кнопки под одной дверью — нажать в одно окно.
@export var pulse := 0.0:
	set(value):
		pulse = value
		queue_redraw()
## Цветная метка: плита и заслонка, которую она держит, помечены одним цветом (прозрачный — без метки).
@export var mark_color := Color(0, 0, 0, 0):
	set(value):
		mark_color = value
		queue_redraw()
@export var sink_speed := 120.0

var active := false
var current_load := 0.0
var _release_timer := 0.0
var _pulse_left := 0.0
var _was_loaded := false
var _base := Vector2.ZERO
## Уровень пола под плитой (глобальный y).
var _floor_y := 0.0
## Кто давил на плиту в этом нажатии: только они удерживают её, сойдя на пол у края.
var _pressers := {}
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
	_floor_y = global_position.y
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
	if not (active or _was_loaded):
		_pressers.clear()
	for entry: Dictionary in Weight.loads_on(self):
		_pressers[entry.contact] = true
	if active or _was_loaded:
		current_load += _edge_load()
	var pressed := current_load >= required_load() - 0.01
	if pulse > 0.0:
		if pressed and not _was_loaded:
			_pulse_left = pulse
		_was_loaded = pressed
		_pulse_left = maxf(_pulse_left - delta, 0.0)
		pressed = pressed and _pulse_left > 0.0
		if pressed or active:
			queue_redraw()
		if not pressed:
			_release_timer = 0.0  # у кнопки отпускание без задержки: окно — ровно pulse
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


## Нагрузка тех, кто давил на плиту, а теперь стоит на полу над её краем. Нажатая плита
## опускается, и стоящий на скосе оказывается на полу — без этого плита отпускалась, поднималась
## под ним и нажималась снова: дрожала, а кнопка срабатывала заново каждые несколько кадров.
## Нажать так нельзя — только удержать: плиту держат, пока с неё не сойдут.
func _edge_load() -> float:
	var half := width_tiles * GreyboxLevel.TILE / 2.0 - 4.0
	var x0 := global_position.x - half
	var x1 := global_position.x + half
	var loads := Weight.all_loads(get_tree())
	var total := 0.0
	for support: Node in loads:
		if support == self:
			continue
		for entry: Dictionary in loads[support]:
			var contact: Node = entry.contact
			if not _pressers.has(contact):
				continue
			var rect: Rect2
			if contact is Player:
				rect = Rect2(contact.global_position - Player.SIZE / 2.0, Player.SIZE)
			elif contact.has_method("get_rect"):
				rect = contact.get_rect()
			else:
				continue
			if rect.end.x > x0 and rect.position.x < x1 and absf(rect.end.y - _floor_y) < 6.0:
				total += entry.mass
			elif rect.end.x <= x0 or rect.position.x >= x1:
				_pressers.erase(contact)  # сошёл — больше не держит
	return total


func _set_active(value: bool) -> void:
	active = value
	queue_redraw()
	changed.emit(active)


func save_state() -> Variant:
	return active and latch


func load_state(state: Variant) -> void:
	_pressers.clear()
	_release_timer = 0.0
	_pulse_left = 0.0
	_was_loaded = false
	if active != state:
		_set_active(state)
	position = _base + Vector2(0, RAISED - PRESSED if active else 0.0)


## Цветной ромб с тёмным контуром над серединой плиты — рядом со счётчиком нагрузки.
func _draw_mark() -> void:
	if mark_color.a <= 0.0:
		return
	var c := Vector2(0, -62)
	var outline := PackedVector2Array([c + Vector2(0, -14), c + Vector2(14, 0), c + Vector2(0, 14), c + Vector2(-14, 0)])
	var fill := PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0)])
	draw_colored_polygon(outline, Color("1a1d33"))
	draw_colored_polygon(fill, mark_color)


## Кнопка: кольцо-таймер над плитой — сколько ещё держится нажатие.
func _draw_pulse() -> void:
	var c := Vector2(0, -62 if mark_color.a > 0.0 else -40)
	if mark_color.a > 0.0:
		c.y -= 30.0
	draw_arc(c, 11.0, 0.0, TAU, 24, Color("1a1d33"), 6.0)
	draw_arc(c, 11.0, 0.0, TAU, 24, Color("9aa3ad"), 3.0)
	if active and _pulse_left > 0.0:
		draw_arc(c, 11.0, -PI / 2.0, -PI / 2.0 + TAU * _pulse_left / pulse, 24, Color("f2c230"), 4.0)


static func _format(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


## Трапеция плиты: низ на уровне пола, по бокам — скосы.
func _outline() -> PackedVector2Array:
	var half := width_tiles * GreyboxLevel.TILE / 2.0 - 4.0
	return PackedVector2Array([
		Vector2(-half, 0), Vector2(-half + RAMP, -RAISED), Vector2(half - RAMP, -RAISED), Vector2(half, 0)])


func _draw() -> void:
	_draw_mark()
	if pulse > 0.0:
		_draw_pulse()
	if Art.enabled:
		var kind := "latch" if latch else "plate"
		var state := "on" if active else "off"
		var width := width_tiles * GreyboxLevel.TILE
		# Каменное основание с цветной крышкой: 20 px, низ утоплен в пол на 4 px.
		Art.draw_strip_h(self, Rect2(-width / 2.0, -16.0, width, 20.0),
				"%s_mid_%s" % [kind, state], "%s_end_%s" % [kind, state])
		return
	var color := Color("f2994a") if active else Color("c2410c")
	if latch:
		color = Color("a78bfa") if active else Color("6d28d9")
	var outline := _outline()
	draw_colored_polygon(outline, color)
	outline.append(outline[0])
	draw_polyline(outline, color.darkened(0.4), 2.0)
