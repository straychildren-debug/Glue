@tool
class_name GreyboxLevel
extends Node2D
## Серый уровень из прямоугольников в тайлах. Строит коллизии и рисует себя сам,
## поэтому геометрию можно править прямо в инспекторе.

const TILE := 64.0

## Твёрдые блоки: Rect2 в тайлах (x, y, ширина, высота); y растёт вниз.
@export var blocks: Array[Rect2] = []:
	set(value):
		blocks = value
		queue_redraw()
## Чекпоинты команды: (x, y пола) в тайлах. Первый — точка старта.
@export var checkpoints: Array[Vector2] = [Vector2(2, 12)]:
	set(value):
		checkpoints = value
		queue_redraw()
## Границы камеры в тайлах.
@export var bounds_tiles := Rect2(0, -10, 40, 29)
## Ниже этой линии (в тайлах) игрок погибает.
@export var kill_y_tiles := 19.0
@export var sky_color := Color("c9d9e8")
@export var block_color := Color("6b7280")
@export var top_color := Color("7fae5c")

var active_checkpoint := 0:
	set(value):
		active_checkpoint = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for rect in blocks:
		var body := StaticBody2D.new()
		body.collision_layer = Player.LAYER_WORLD
		body.collision_mask = 0
		var shape := RectangleShape2D.new()
		shape.size = rect.size * TILE
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = (rect.position + rect.size / 2.0) * TILE
		body.add_child(collision)
		add_child(body)


func get_bounds_px() -> Rect2:
	return Rect2(bounds_tiles.position * TILE, bounds_tiles.size * TILE)


func get_kill_y() -> float:
	return kill_y_tiles * TILE


## Точка появления игрока у чекпоинта: игроки встают рядом, не друг в друге.
func get_spawn_position(checkpoint: int, slot: int) -> Vector2:
	var base := checkpoints[checkpoint] * TILE
	return base + Vector2(slot * (Player.SIZE.x + 8.0), -Player.SIZE.y / 2.0 - 1.0)


## Индекс последнего чекпоинта, который лежит левее x (в пикселях).
func checkpoint_at_x(x: float) -> int:
	var result := 0
	for i in checkpoints.size():
		if x >= checkpoints[i].x * TILE:
			result = i
	return result


func _draw() -> void:
	draw_rect(get_bounds_px(), sky_color)
	draw_line(Vector2(bounds_tiles.position.x * TILE, get_kill_y()),
			Vector2(bounds_tiles.end.x * TILE, get_kill_y()), Color(0.8, 0.2, 0.2, 0.5), 4.0)
	for rect in blocks:
		var px := Rect2(rect.position * TILE, rect.size * TILE)
		draw_rect(px, block_color)
		draw_rect(Rect2(px.position, Vector2(px.size.x, minf(10.0, px.size.y))), top_color)
		draw_rect(px, block_color.darkened(0.3), false, 2.0)
	for i in checkpoints.size():
		var base := checkpoints[i] * TILE
		var flag := Color("f2c230") if i == active_checkpoint else Color("9aa3ad")
		draw_line(base, base + Vector2(0, -96), Color("3a3f47"), 4.0)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(2, -96), base + Vector2(42, -82), base + Vector2(2, -68)]), flag)
