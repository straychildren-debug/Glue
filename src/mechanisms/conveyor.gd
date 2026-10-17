@tool
class_name Conveyor
extends StaticBody2D
## Конвейер (M2.1): лента везёт всё, что на ней стоит, — игроков, ящиков, жуков и замерших.
## Бегущий против ленты стоит на месте (скорость ленты по умолчанию равна скорости бега).
## Идущих и ящики везёт сам движок (скорость опоры), замерших конвейер сдвигает сам:
## замерший едет, как груз, и везёт стоящего на нём.
## Триггер control (плита, защёлка, рычаг): пока активен — лента делает то, что задано
## в control_mode (разворот или стоп; «пуск» — без триггера стоит).
## Положение узла — левый верхний угол ленты.

enum ControlMode { REVERSE, STOP, RUN }

const OUTLINE := Color("1a1d33")
const HEIGHT := 24.0
## Скаты на концах, px.
const RAMP := 40.0

@export var width_tiles := 4.0:
	set(value):
		width_tiles = value
		queue_redraw()
## Скорость ленты, px/с; знак — направление (плюс — вправо).
@export var speed := 360.0:
	set(value):
		speed = value
		queue_redraw()
@export var control: NodePath
@export var control_mode := ControlMode.REVERSE

var _shift := 0.0  # сдвиг рисунка ленты, px (ленте со спрайтом — по модулю периода планок)


func _ready() -> void:
	# Короб ленты со скатами на концах: на ленту, стоящую на полу, заходят пешком.
	# Утопленную в пол ленту (верх вровень с полом) скаты не мешают — они уходят в пол.
	var w := width_tiles * GreyboxLevel.TILE
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([Vector2(-RAMP, HEIGHT), Vector2(0, 0), Vector2(w, 0), Vector2(w + RAMP, HEIGHT)])
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if Engine.is_editor_hint():
		return
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	process_physics_priority = 18  # после игроков и ящиков: двигаем тех, кто стоит сейчас


## Текущая скорость ленты с учётом триггера.
func belt_speed() -> float:
	var active := false
	if not control.is_empty():
		var trigger := get_node_or_null(control)
		active = trigger != null and trigger.active
	match control_mode:
		ControlMode.REVERSE:
			return -speed if active else speed
		ControlMode.STOP:
			return 0.0 if active else speed
		_:
			return speed if active else 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var v := belt_speed()
	constant_linear_velocity = Vector2(v, 0.0)
	_shift = fposmod(_shift + v * delta, 3200.0)
	queue_redraw()
	if v == 0.0:
		return
	# Замершие на ленте едут сдвигом (их движок не двигает): только если впереди свободно.
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.frozen and player.carrier == null and Weight.probe_below(player) == self:
			var step := Vector2(v * delta, 0.0)
			if not player.test_move(player.global_transform, step):
				player.shove(step)


func _draw() -> void:
	var size := Vector2(width_tiles * GreyboxLevel.TILE, HEIGHT)
	if Art.enabled and Art.has("w2_belt_mid"):
		_draw_sprites(size)
		return
	var r := HEIGHT / 2.0
	# Корпус: скруглённая лента с валами на концах, тёмный контур.
	draw_rect(Rect2(Vector2(r, 0), Vector2(size.x - 2.0 * r, size.y)), OUTLINE)
	draw_circle(Vector2(r, r), r, OUTLINE)
	draw_circle(Vector2(size.x - r, r), r, OUTLINE)
	draw_rect(Rect2(Vector2(r, 3), Vector2(size.x - 2.0 * r, size.y - 6)), Color("4a4f5a"))
	draw_circle(Vector2(r, r), r - 3.0, Color("6b7280"))
	draw_circle(Vector2(size.x - r, r), r - 3.0, Color("6b7280"))
	# Планки ленты сверху едут вместе с лентой.
	var x := r - 32.0 + fposmod(_shift, 32.0)
	while x < size.x - r:
		if x > r - 4.0:
			draw_rect(Rect2(Vector2(x, 2), Vector2(14, 6)), Color("8a6a45"))
		x += 32.0
	# Стрелка направления на боку корпуса.
	var v := belt_speed() if not Engine.is_editor_hint() else speed
	if v != 0.0:
		var dir := signf(v)
		var c := Vector2(size.x / 2.0, r + 3.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8 * dir, -6), c + Vector2(8 * dir, 0), c + Vector2(-8 * dir, 6)]), Color("f2c230"))
	for end in [Vector2(r, r), Vector2(size.x - r, r)]:
		draw_circle(end, 4.0, OUTLINE)


## Графика: валы на концах (торец и его отражение), между ними лента с планками; планки едут.
func _draw_sprites(size: Vector2) -> void:
	var mid := Art.tex("w2_belt_mid")
	var end := Art.tex("w2_belt_end")
	var scale := size.y / mid.get_height()
	var mid_w := mid.get_width() * scale
	var end_w := minf(end.get_width() * scale, size.x / 2.0)
	var left := end_w * 0.6
	var right := size.x - end_w * 0.6
	var x := left - mid_w + fposmod(_shift, mid_w)
	while x < right:
		var from := maxf(x, left)
		var to := minf(x + mid_w, right)
		if to > from:
			draw_texture_rect_region(mid, Rect2(from, 0, to - from, size.y),
					Rect2((from - x) / scale, 0, (to - from) / scale, mid.get_height()))
		x += mid_w
	draw_texture_rect_region(end, Rect2(0, 0, end_w, size.y), Rect2(0, 0, end_w / scale, end.get_height()))
	var flipped := Art.tex_flipped("w2_belt_end")
	draw_texture_rect_region(flipped, Rect2(size.x - end_w, 0, end_w, size.y),
			Rect2(flipped.get_width() - end_w / scale, 0, end_w / scale, flipped.get_height()))
