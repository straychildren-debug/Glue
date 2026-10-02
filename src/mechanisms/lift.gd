@tool
class_name Lift
extends Node2D
## Подъёмник: две площадки на одном тросе в соседних шахтах. Тяжёлая сторона опускается,
## лёгкая поднимается; скорость растёт с разницей нагрузки (Weight), при равенстве площадки стоят.
## Упоры сверху и снизу — пределы хода; фиксатор (lock, обычно защёлка) держит площадки на месте.
## Не давит: если площадка или стоящие на ней во что-то упираются (потолок, замерший в воздухе,
## игрок под площадкой), подъёмник останавливается.
## Прыжок с площадки вес не снимает: подпрыгнувший над своей площадкой весит на ней, пока не
## приземлится, не уйдёт в сторону или не замрёт. Снять вес в воздухе может только «Замри» —
## на этом держится «чехарда»; иначе подъёмник раскачивали бы простыми прыжками.
## Едущий вверх, который задевает головой угол потолка на несколько пикселей, сдвигается вбок
## (как в платформерах), а не останавливает подъёмник.
## Положение узла — середина верха левой площадки при нулевом ходе; правая — на span_tiles правее.
## Ход offset > 0 — левая ниже, правая выше на столько же.

const DECK := 0.5 * GreyboxLevel.TILE
## Насколько можно сдвинуть едущего вбок, чтобы он не зацепился за угол (px).
const NUDGE_MAX := 24.0

@export var width_tiles := 2.0:
	set(value):
		width_tiles = value
		queue_redraw()
## Расстояние между серединами площадок (тайлы).
@export var span_tiles := 4.0:
	set(value):
		span_tiles = value
		queue_redraw()
## Пределы хода левой площадки вниз (+) и вверх (−), тайлы.
@export var min_offset_tiles := -4.0
@export var max_offset_tiles := 4.0
@export var start_offset_tiles := 0.0:
	set(value):
		start_offset_tiles = value
		queue_redraw()
## Блоки троса — на столько тайлов выше самого высокого положения площадок.
@export var pulley_height_tiles := 2.0:
	set(value):
		pulley_height_tiles = value
		queue_redraw()
## Скорость на единицу разницы масс и предел скорости, px/с; разгон, px/с².
@export var speed_per_mass := 140.0
@export var max_speed := 280.0
@export var accel := 900.0
## Фиксатор: пока этот триггер активен, площадки стоят.
@export var lock: NodePath
## Тормоз наоборот: площадки стоят, пока триггер (обычно рычаг) НЕ активен — игроки спокойно
## загружаются и только потом отпускают тормоз.
@export var lock_inverted := false
## Пустой подъёмник (ни на одной площадке нет веса) сам возвращается в исходное положение —
## так не бывает тупика, когда пустая площадка уехала туда, где её не достать.
@export var rest_speed := 90.0

var offset := 0.0
var speed := 0.0
var _left: AnimatableBody2D
var _right: AnimatableBody2D
var _airborne := {}  # Player -> площадка, с которой он подпрыгнул (его вес ещё на ней)
var _standing := {}  # Player -> площадка, на которой он стоял в прошлом кадре
var _nudges := {}  # едущий -> сдвиг по x в обход угла (собирает _can_move)


func _ready() -> void:
	offset = start_offset_tiles * GreyboxLevel.TILE
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 20  # после игроков: их вес этого кадра уже известен
	_left = _make_platform("Left")
	_right = _make_platform("Right")
	_place_platforms()


func _make_platform(platform_name: String) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.name = platform_name
	body.collision_layer = Player.LAYER_WORLD
	body.collision_mask = 0
	body.sync_to_physics = true
	body.add_to_group(Weight.CARRIERS)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * GreyboxLevel.TILE, DECK)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, DECK / 2.0)
	body.add_child(collision)
	add_child(body)
	return body


func _place_platforms() -> void:
	_left.position = Vector2(0, offset)
	_right.position = Vector2(span_tiles * GreyboxLevel.TILE, -offset)


func get_platforms() -> Array[AnimatableBody2D]:
	return [_left, _right]


func is_locked() -> bool:
	if lock.is_empty():
		return false
	var trigger := get_node_or_null(lock)
	if trigger == null:
		return false
	return trigger.active != lock_inverted


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	queue_redraw()
	_track_jumpers()
	var left_load := _load_on(_left)
	var right_load := _load_on(_right)
	var diff := left_load - right_load
	var target := 0.0 if is_locked() else clampf(diff * speed_per_mass, -max_speed, max_speed)
	var rest := start_offset_tiles * GreyboxLevel.TILE
	if not is_locked() and left_load <= 0.0 and right_load <= 0.0 and absf(offset - rest) > 0.5:
		target = signf(rest - offset) * minf(rest_speed, absf(rest - offset) * 8.0)
	speed = move_toward(speed, target, accel * delta)
	var low := min_offset_tiles * GreyboxLevel.TILE
	var high := max_offset_tiles * GreyboxLevel.TILE
	var step := clampf(offset + speed * delta, low, high) - offset
	if is_zero_approx(step):
		speed = 0.0  # на упоре
		return
	# Левая едет на step, правая — на −step. Если хоть одна упрётся — стоят обе (один трос).
	_nudges.clear()
	if not _can_move(_left, step) or not _can_move(_right, -step):
		speed = 0.0
		return
	for body: Node2D in _nudges:
		body.global_position.x += _nudges[body]
	offset += step
	_place_platforms()
	Player.follow_carrier(_left)
	Player.follow_carrier(_right)


## Вес на площадке: стоящие на ней (Weight) и подпрыгнувшие с неё.
func _load_on(platform: AnimatableBody2D) -> float:
	var total := Weight.total_on(platform)
	for player: Player in _airborne:
		if _airborne[player] == platform:
			total += player.mass
			for body: Node in Weight.stack_on(player):
				total += body.mass
	return total


## Кто подпрыгнул со своей площадки и ещё висит над ней (не замер, не приземлился).
func _track_jumpers() -> void:
	var standing := {}
	for platform: AnimatableBody2D in [_left, _right]:
		for body: Node in Weight.stack_on(platform):
			if body is Player:
				standing[body] = platform
	var half := width_tiles * GreyboxLevel.TILE / 2.0 + Player.SIZE.x / 2.0
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		var platform: AnimatableBody2D = _airborne.get(player, _standing.get(player))
		var airborne := player.alive and not player.frozen and not player.is_on_floor() 				and not standing.has(player) and platform != null 				and absf(player.global_position.x - platform.global_position.x) < half 				and player.global_position.y < platform.global_position.y
		if airborne:
			_airborne[player] = platform
		else:
			_airborne.erase(player)
	_standing = standing


## Может ли площадка сдвинуться на dy: сама — не въезжая в чужие тела; стоящие на ней — не
## упираясь в чужое (их пробный сдвиг без своей площадки и своей стопки). Задевший угол краем
## сдвигается вбок. Вверх: не обойти угол — подъёмник стоит. Вниз: кто стоит на краю уступа
## больше, чем на площадке, остаётся на уступе (площадка уходит из-под него).
func _can_move(platform: AnimatableBody2D, dy: float) -> bool:
	var riders := Weight.stack_on(platform)
	var size := Vector2(width_tiles * GreyboxLevel.TILE, DECK)
	var next := Rect2(platform.global_position + Vector2(-size.x / 2.0, dy), size)
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		# Замерший в воздухе над площадкой — упор, а не седок, хоть и висит над ней вплотную.
		var rides := riders.has(player) and (not player.frozen or player.carrier == platform)
		if player.alive and not rides 				and next.intersects(Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			return false
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		if crate.visible and not riders.has(crate) and next.intersects(crate.get_rect()):
			return false
	for body: PhysicsBody2D in riders:
		var hit := _hit(body, body.global_transform, Vector2(0, dy), platform, riders)
		if hit == null:
			continue
		var nudge := _corner_nudge(body, dy, hit.get_position().x, platform, riders)
		if not is_nan(nudge):
			_nudges[body] = nudge
		elif dy < 0.0 or (body is Player and body.frozen):
			return false  # упёрся головой; замерший едет якорем — его площадка не бросает
	return true


## Столкновение едущего с чужим телом при сдвиге motion из положения from (null — свободно).
## Своя площадка и своя стопка не считаются.
func _hit(body: PhysicsBody2D, from: Transform2D, motion: Vector2, platform: Node, riders: Array) -> KinematicCollision2D:
	var collision := KinematicCollision2D.new()
	body.add_collision_exception_with(platform)
	var hit := body.test_move(from, motion, collision)
	body.remove_collision_exception_with(platform)
	if not hit or riders.has(collision.get_collider()):
		return null
	return collision


## Сдвиг вбок, после которого едущий проходит мимо угла (NAN — не выйдет): от угла, до NUDGE_MAX.
## Замерших не сдвигаем — они держатся за площадку своим якорем.
func _corner_nudge(body: PhysicsBody2D, dy: float, corner_x: float, platform: Node, riders: Array) -> float:
	if body is Player and body.frozen:
		return NAN
	var away := signf(body.global_position.x - corner_x)
	if away == 0.0:
		return NAN
	for n in range(2, int(NUDGE_MAX) + 1, 2):
		var shift := Vector2(away * n, 0)
		var side := _hit(body, body.global_transform, shift, platform, riders)
		if side != null and absf(side.get_normal().x) > 0.7:
			return NAN  # сбоку стена или сосед
		if _hit(body, body.global_transform.translated(shift), Vector2(0, dy), platform, riders) == null:
			return away * n
	return NAN


func save_state() -> Variant:
	return offset


func load_state(state: Variant) -> void:
	offset = state
	speed = 0.0
	_airborne.clear()
	_standing.clear()
	if _left:
		_place_platforms()
	queue_redraw()


func _draw() -> void:
	var tile := GreyboxLevel.TILE
	var width := width_tiles * tile
	var span := span_tiles * tile
	var left_y := offset
	var right_y := -offset
	if Engine.is_editor_hint():
		left_y = start_offset_tiles * tile
		right_y = -left_y
	var top := minf(min_offset_tiles, -max_offset_tiles) * tile - pulley_height_tiles * tile
	var outline := Color("1a1d33")
	# Трос: от каждой площадки вверх к своему блоку, блоки на общей балке.
	for x_y: Vector2 in [Vector2(0, left_y), Vector2(span, right_y)]:
		draw_line(Vector2(x_y.x, top), Vector2(x_y.x, x_y.y), outline, 5.0)
		draw_line(Vector2(x_y.x, top), Vector2(x_y.x, x_y.y), Color("c8b48a"), 2.5)
	draw_rect(Rect2(-width / 4.0, top - 20.0, span + width / 2.0, 12.0), outline)
	draw_rect(Rect2(-width / 4.0 + 2.0, top - 18.0, span + width / 2.0 - 4.0, 8.0), Color("8a5a30"))
	for x: float in [0.0, span]:
		draw_circle(Vector2(x, top), 15.0, outline)
		draw_circle(Vector2(x, top), 11.0, Color("9aa3ad"))
		draw_circle(Vector2(x, top), 4.0, outline)
	if lock.is_empty() == false and not Engine.is_editor_hint():
		var locked := is_locked()
		draw_circle(Vector2(span / 2.0, top - 14.0), 9.0, outline)
		draw_circle(Vector2(span / 2.0, top - 14.0), 6.0, Color("a78bfa") if locked else Color("6d28d9"))
	# Площадки — деревянные настилы.
	for x_y: Vector2 in [Vector2(0, left_y), Vector2(span, right_y)]:
		var rect := Rect2(x_y.x - width / 2.0, x_y.y, width, DECK)
		if Art.enabled:
			Art.draw_wood(self, rect)
		else:
			draw_rect(rect, Color("a0703f"))
			draw_rect(rect, Color("5a3a1c"), false, 3.0)
