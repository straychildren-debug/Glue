@tool
class_name Mover
extends AnimatableBody2D
## Движущаяся площадка (трапеция): ездит между началом (положение узла) и концом (path_tiles от начала).
## Обычно — туда-сюда без остановки (с паузой pause на концах). Аттракцион (ride): стоит в начале, пока
## на ней и на всех площадках partners никого нет; как только загружены все — едут разом до конца и уже
## не останавливаются; в конце ждут, пока с площадки сойдут, и возвращаются. Так две трапеции едут,
## только когда на каждой по герою: каждый на своей проходит свои пилы — одновременно.
## Стоящих везёт движок (скорость опоры), подпрыгнувший летит с её скоростью и приземляется на неё же.
## Положение узла — левый верхний угол площадки в начале пути.

const OUTLINE := Color("1a1d33")

@export var size_tiles := Vector2(2.5, 0.5):
	set(value):
		size_tiles = value
		queue_redraw()
## Конец пути относительно начала, тайлы.
@export var path_tiles := Vector2(10, 0):
	set(value):
		path_tiles = value
		queue_redraw()
@export var speed := 160.0
## Откуда площадка начинает: доля пути 0–1 и направление (без ride).
@export_range(0.0, 1.0) var start_at := 0.0
@export var start_forward := true
## Стоянка на концах пути, с (без ride).
@export var pause := 0.0
## Аттракцион: везёт, когда загружена она и все partners.
@export var ride := false
@export var partners: Array[NodePath] = []
## Сколько стоит в конце пути пустой, прежде чем вернуться, с (ride).
@export var return_delay := 1.0
## «Двойка» (ride): едут, только пока загружены все — подпрыгнул один (переждать пилу), встали обе,
## и у товарища сбился свой такт пил. Подпрыгнувший летит дальше со скоростью трапеции — рулить назад.
@export var hold := false

var progress := 0.0
var forward := true
var moving := true
var _wait := 0.0
var _origin := Vector2.ZERO


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = shape.size / 2.0
	add_child(collision)
	if Engine.is_editor_hint():
		return
	_origin = position
	progress = 0.0 if ride else start_at
	forward = true if ride else start_forward
	moving = not ride
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	process_physics_priority = -5  # раньше игроков: они едут с её скоростью в этом же кадре
	_place()


## Кто-нибудь стоит на площадке (или висит на стоящем).
func loaded() -> bool:
	return Weight.total_on(self) > 0.01


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if ride:
		_ride_logic(delta)
		if hold and moving and progress > 0.0 and progress < 1.0 and forward and not _all_loaded():
			return  # двойка: кто-то в прыжке — стоим
	elif _wait > 0.0:
		_wait -= delta
		return
	if not moving:
		return
	var length := (path_tiles * GreyboxLevel.TILE).length()
	if length <= 0.0:
		return
	progress = clampf(progress + (1.0 if forward else -1.0) * speed * delta / length, 0.0, 1.0)
	if progress <= 0.0 or progress >= 1.0:
		if ride:
			moving = false
		else:
			forward = progress <= 0.0
			_wait = pause
	_place()


func _all_loaded() -> bool:
	if not loaded():
		return false
	for p in partners:
		var other := get_node_or_null(p)
		if other != null and not other.loaded():
			return false
	return true


func _ride_logic(delta: float) -> void:
	if moving:
		return
	if progress <= 0.0:
		if not loaded():
			return
		for p in partners:
			var other := get_node_or_null(p)
			if other != null and not other.loaded():
				return
		forward = true
		moving = true
	elif loaded():
		_wait = return_delay
	else:
		_wait -= delta
		if _wait <= 0.0:
			forward = false
			moving = true


func _place() -> void:
	position = _origin + path_tiles * GreyboxLevel.TILE * progress


## Середина верха площадки в мире.
func top_center() -> Vector2:
	return global_position + Vector2(size_tiles.x * GreyboxLevel.TILE / 2.0, 0.0)


func save_state() -> Variant:
	return [progress, forward, moving, _wait]


func load_state(state: Variant) -> void:
	progress = state[0]
	forward = state[1]
	moving = state[2]
	_wait = state[3]
	_place()


func _draw() -> void:
	var size := size_tiles * GreyboxLevel.TILE
	var start := Vector2.ZERO if Engine.is_editor_hint() else -path_tiles * GreyboxLevel.TILE * progress
	var end := start + path_tiles * GreyboxLevel.TILE
	# Путь: пунктир по середине площадки от начала до конца.
	var mid := Vector2(size.x / 2.0, size.y / 2.0)
	var length := (end - start).length()
	if length > 0.0:
		var step := (end - start) / length
		var t := 0.0
		while t < length:
			draw_line(start + mid + step * t, start + mid + step * minf(t + 10.0, length), Color(0.1, 0.11, 0.2, 0.35), 3.0)
			t += 22.0
	# Трапеция: спрайт N1 (доска — нижняя треть картинки, её верх — на 0,654 высоты) или кодом.
	if Art.enabled and Art.has("w2_trapeze"):
		var sprite := Art.tex("w2_trapeze")
		var h := sprite.get_height() * size.x / sprite.get_width()
		draw_texture_rect(sprite, Rect2(0, -0.654 * h, size.x, h), false)
		return
	for x in [8.0, size.x - 8.0]:
		draw_line(Vector2(x, 0), Vector2(size.x / 2.0, -40.0), OUTLINE, 3.0)
	draw_circle(Vector2(size.x / 2.0, -40.0), 6.0, OUTLINE)
	draw_circle(Vector2(size.x / 2.0, -40.0), 3.0, Color("e0b040"))
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE)
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("d8574a"))
	var stripes := int(size.x / 24.0)
	for i in stripes:
		if i % 2 == 0:
			draw_rect(Rect2(Vector2(3 + i * 24.0, 3), Vector2(minf(24.0, size.x - 6 - i * 24.0), size.y - 6)), Color("f2e6c8"))
