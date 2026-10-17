@tool
class_name Bellows
extends Node2D
## Меха (M2.5): нажали педаль (плиту pedal) — из сопла бьёт порыв ветра на gust_time секунд.
## Порыв сносит тех, кто в воздухе в полосе перед соплом; стоящих на земле и замерших — нет.
## Держащиеся за руку тяжелее: порыв делится на всех в связке. Каждое нажатие — один порыв:
## чтобы качать, на педаль надо запрыгивать снова.
## Положение узла — сопло; полоса ветра — вперёд от него на length_tiles, высотой height_tiles.

const OUTLINE := Color("1a1d33")
## Ускорение порыва, px/с², и предел скорости, до которого он разгоняет.
const FORCE := 3000.0
const MAX_SPEED := 950.0

## Куда дует: 1 — вправо, -1 — влево.
@export_enum("Влево:-1", "Вправо:1") var direction := 1:
	set(value):
		direction = value
		queue_redraw()
@export var length_tiles := 8.0:
	set(value):
		length_tiles = value
		queue_redraw()
@export var height_tiles := 4.0:
	set(value):
		height_tiles = value
		queue_redraw()
## Сколько секунд дует порыв после нажатия педали.
@export var gust_time := 1.0
@export var pedal: NodePath
## Ещё педали (на другом берегу): порыв даёт нажатие любой.
@export var pedals: Array[NodePath] = []
## Такт без педали: порыв сам каждые auto_period секунд, первый — через auto_offset (0 — сразу).
## Двое мехов навстречу с одним тактом и сдвигом на полтакта — ветер, меняющий направление.
@export var auto_period := 0.0
@export var auto_offset := 0.0
## Сила порыва (доля от обычной): мягкий порыв лишь удлиняет прыжок, а не уносит.
@export var strength := 1.0

var _gust := 0.0  # сколько ещё дует, с
var _pedal_was := {}  # педаль -> была ли нажата в прошлом кадре
var _time := 0.0
var _auto := 0.0  # сколько осталось до следующего порыва по такту, с


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GreyboxLevel.RESETTABLE)
		process_physics_priority = 22  # после плит
		_auto = auto_offset


## Полоса ветра в мире.
func get_area() -> Rect2:
	var length := length_tiles * GreyboxLevel.TILE
	var height := height_tiles * GreyboxLevel.TILE
	var x := global_position.x if direction > 0 else global_position.x - length
	return Rect2(x, global_position.y - height / 2.0, length, height)


func is_blowing() -> bool:
	return _gust > 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if auto_period > 0.0:
		_auto -= delta
		if _auto <= 0.0:
			_auto += auto_period
			_gust = gust_time
	for path in [pedal] + pedals:
		if path.is_empty():
			continue
		var node: Node = get_node_or_null(path)
		var pressed: bool = node != null and node.active
		if pressed and not _pedal_was.get(path, false):
			_gust = gust_time
		_pedal_was[path] = pressed
	if _gust <= 0.0:
		return
	_gust -= delta
	queue_redraw()
	var area := get_area()
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if not player.alive or player.frozen or player.is_on_floor() or not area.has_point(player.global_position):
			continue
		var push := direction * FORCE * strength * delta / _chain_size(player)
		if player.velocity.x * direction < MAX_SPEED * strength:
			player.velocity.x += push
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		if crate.visible and not crate.is_on_floor() and area.has_point(crate.global_position):
			if crate.velocity.x * direction < MAX_SPEED * strength:
				crate.velocity.x += direction * FORCE * strength * delta / crate.mass


## Сколько игроков в связке хвата с этим (включая его самого): связка тяжелее.
static func _chain_size(player: Player) -> int:
	var seen := {player: true}
	var queue: Array[Player] = [player]
	while not queue.is_empty():
		var current: Player = queue.pop_back()
		var linked: Array = []
		if current.grab_target is Player:
			linked.append(current.grab_target)
		for other: Player in current.get_tree().get_nodes_in_group(Player.GROUP):
			if other.grab_target == current:
				linked.append(other)
		for other: Player in linked:
			if other.alive and not seen.has(other):
				seen[other] = true
				queue.append(other)
	return seen.size()


func save_state() -> Variant:
	return null


func load_state(_state: Variant) -> void:
	_pedal_was.clear()
	if auto_period <= 0.0:
		_gust = 0.0  # по такту — дует дальше: ветер не ждёт возрождения


func _draw() -> void:
	var d := float(direction)
	if Art.enabled and Art.has("w2_bellows"):
		# P24: дует вправо; срез сопла раскрытых мехов — точка (100.3, 45.3) спрайта; при порыве —
		# сжатые (стойка на месте, сопло ближе к ней).
		var sprite := Art.tex("w2_bellows_blow" if _gust > 0.0 and Art.has("w2_bellows_blow") else "w2_bellows")
		var size := Vector2(sprite.get_size()) / 4.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(d, 1.0))
		draw_texture_rect(sprite, Rect2(Vector2(-100.3, -45.3), size), false)
		draw_set_transform(Vector2.ZERO)
		_draw_gust(d)
		return
	# Корпус мехов позади сопла: деревянные щёки с кожаной гармошкой и латунное сопло.
	var back := Vector2(-d * 70.0, 0.0)
	var squeeze := 1.0 - 0.35 * clampf(_gust / gust_time, 0.0, 1.0)
	var body := PackedVector2Array([back + Vector2(0, -34), Vector2(-d * 18.0, -14 * squeeze), Vector2(-d * 18.0, 14 * squeeze), back + Vector2(0, 34)])
	draw_colored_polygon(body, OUTLINE)
	var inner := PackedVector2Array([back + Vector2(d * 4.0, -28), Vector2(-d * 22.0, -10 * squeeze), Vector2(-d * 22.0, 10 * squeeze), back + Vector2(d * 4.0, 28)])
	draw_colored_polygon(inner, Color("a07850"))
	for i in range(1, 4):
		var x := lerpf(back.x, -d * 20.0, i / 4.0)
		draw_line(Vector2(x, -26 + i * 4), Vector2(x, 26 - i * 4), Color("6a4a2a"), 2.0)
	draw_rect(Rect2(back + Vector2(-6, -38), Vector2(12, 76)), OUTLINE)
	draw_rect(Rect2(back + Vector2(-3, -35), Vector2(6, 70)), Color("8a5a30"))
	draw_rect(Rect2(Vector2(minf(0.0, -d * 22.0), -9), Vector2(22, 18)), OUTLINE)
	draw_rect(Rect2(Vector2(minf(0.0, -d * 22.0) + 3.0, -6), Vector2(16, 12)), Color("d4a640"))
	_draw_gust(d)


## Порыв (белые полосы от сопла) или, в редакторе, рамка полосы ветра.
func _draw_gust(d: float) -> void:
	if _gust > 0.0:
		# Порыв: белые полосы бегут от сопла.
		var length := length_tiles * GreyboxLevel.TILE
		var height := height_tiles * GreyboxLevel.TILE
		var fade := clampf(_gust / gust_time, 0.0, 1.0)
		for i in 7:
			var y := (float(i) / 6.0 - 0.5) * height * 0.8
			var x0 := fposmod(_time * 900.0 + i * 137.0, length)
			draw_line(Vector2(d * x0, y), Vector2(d * minf(x0 + 90.0, length), y), Color(1, 1, 1, 0.55 * fade), 4.0)
	elif Engine.is_editor_hint():
		var area := get_area()
		draw_rect(Rect2(area.position - global_position, area.size), Color(0.7, 0.9, 1.0, 0.6), false, 2.0)
