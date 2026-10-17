@tool
class_name BrittleFloor
extends StaticBody2D
## Ломкий настил (M2.4): держит одного; больше capacity (по умолчанию — двое) — трескается
## и через CRACK_TIME рушится. Вес — как у плит: стоящие, стопка, висящие на руке у стоящих,
## ящики. Замерший в воздухе над настилом ничего не весит — по нему можно перейти вторым.
## Осыпающийся (crumble_time > 0): держит любого, но, как только на него ступили, трещит и через
## crumble_time рушится сам — пол рушится за спиной, стоять на нём нельзя.
## Рухнувший настил возвращается к состоянию чекпоинта.
## Положение узла — левый верхний угол настила.

const OUTLINE := Color("1a1d33")
const HEIGHT := 16.0
## Сколько секунд настил трещит под лишним весом, прежде чем рухнуть (успеть сойти нельзя).
const CRACK_TIME := 0.2

@export var width_tiles := 3.0:
	set(value):
		width_tiles = value
		queue_redraw()
## Сколько выдерживает (в массах игрока).
@export var capacity := 1.0
## > 0 — осыпающийся: рушится через столько секунд после первого шага, под любым весом.
@export var crumble_time := 0.0

var broken := false
var _crack := 0.0  # сколько уже трещит, с
var _crumbling := false
var _fall := 0.0   # время с обрушения — обломки падают
var _shape: CollisionShape2D


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * GreyboxLevel.TILE, HEIGHT)
	_shape = CollisionShape2D.new()
	_shape.shape = shape
	_shape.position = shape.size / 2.0
	add_child(_shape)
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	process_physics_priority = 20


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if broken:
		_fall += delta
		queue_redraw()
		return
	if crumble_time > 0.0:
		_crumbling = _crumbling or Weight.total_on(self) > 0.01
		if _crumbling:
			_crack += delta
			if _crack >= crumble_time:
				_break()
	elif Weight.total_on(self) > capacity + 0.01:
		_crack += delta
		if _crack >= CRACK_TIME:
			_break()
	else:
		_crack = 0.0
	queue_redraw()


func _break() -> void:
	broken = true
	_fall = 0.0
	_shape.set_deferred("disabled", true)
	# Замершие на настиле больше не стоят ни на чём: остаются висеть якорем, как в воздухе.


func save_state() -> Variant:
	return broken


func load_state(state: Variant) -> void:
	broken = state
	_crack = 0.0
	_crumbling = false
	_fall = 10.0 if broken else 0.0
	_shape.set_deferred("disabled", broken)
	queue_redraw()


func _draw() -> void:
	var w := width_tiles * GreyboxLevel.TILE
	if broken:
		# Обломки падают и исчезают.
		if _fall > 1.2:
			return
		var drop := 1200.0 * _fall * _fall
		var pieces := maxi(2, int(width_tiles * 1.5))
		for i in pieces:
			var x := w * i / pieces
			var spin := (i % 2 * 2 - 1) * _fall * 3.0
			draw_set_transform(Vector2(x + w / pieces / 2.0, HEIGHT / 2.0 + drop * (1.0 + i * 0.15)), spin)
			draw_rect(Rect2(-w / pieces / 2.0 + 2.0, -HEIGHT / 2.0, w / pieces - 4.0, HEIGHT), OUTLINE)
			draw_rect(Rect2(-w / pieces / 2.0 + 5.0, -HEIGHT / 2.0 + 3.0, w / pieces - 10.0, HEIGHT - 6.0), Color("b08a5a"))
		draw_set_transform(Vector2.ZERO)
		return
	var shake := Vector2(sin(_crack * 90.0) * 2.0, 0.0) if _crack > 0.0 else Vector2.ZERO
	if Art.enabled and Art.has("w2_plank_mid"):
		# P23: доски на верёвках (верх доски — строка 19 куска, толщина 31 px → HEIGHT); под весом
		# трещит — треснувший рисунок целиком.
		var k := HEIGHT / 31.0
		var rect := Rect2(shake + Vector2(0, -19.0 * k), Vector2(w, 68.0 * k))
		if _crack > 0.0 and Art.has("w2_plank_cracked"):
			draw_texture_rect(Art.tex("w2_plank_cracked"), Rect2(rect.position, Vector2(w, 81.0 * k)), false)
		else:
			Art.draw_strip_h(self, rect, "w2_plank_mid", "w2_plank_end")
		return
	var rect := Rect2(shake, Vector2(w, HEIGHT))
	draw_rect(rect, OUTLINE)
	draw_rect(rect.grow(-3.0), Color("b08a5a"))
	# Доски, трещины и подпорки снизу: ненадёжный настил видно сразу.
	var boards := maxi(1, int(width_tiles))
	for i in range(1, boards):
		var x := w * i / boards + shake.x
		draw_line(Vector2(x, 2), Vector2(x, HEIGHT - 2), OUTLINE, 2.0)
	for i in boards:
		var x := w * (i + 0.5) / boards + shake.x
		draw_polyline(PackedVector2Array([Vector2(x - 10, 4), Vector2(x - 2, 9), Vector2(x + 4, 5), Vector2(x + 11, 11)]), Color("5a3d22"), 2.0)
	for x in [10.0, w - 10.0]:
		draw_line(Vector2(x, HEIGHT), Vector2(x + (8.0 if x < w / 2.0 else -8.0), HEIGHT + 12.0), OUTLINE, 4.0)
