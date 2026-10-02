@tool
class_name Saw
extends Node2D
## Циркулярная пила на рельсе: ездит туда-сюда между началом (положение узла) и концом
## (path_tiles от начала). Касание — гибель. Замерший — камень: пила упирается в него (и в ящик)
## и едет назад, так замерший укорачивает ей путь. Сквозь блоки уровня рельс проложен уровнем.

const OUTLINE := Color("1a1d33")
## Насколько тело должно зайти под диск, чтобы порезаться (px).
const BITE := 4.0

@export var radius_tiles := 0.55:
	set(value):
		radius_tiles = value
		queue_redraw()
## Конец рельса относительно начала, тайлы.
@export var path_tiles := Vector2(6, 0):
	set(value):
		path_tiles = value
		queue_redraw()
@export var speed := 200.0
## Откуда пила начинает: доля пути 0–1 и направление.
@export_range(0.0, 1.0) var start_at := 0.0:
	set(value):
		start_at = value
		queue_redraw()
@export var start_forward := true

var progress := 0.0
var forward := true
var _spin := 0.0


func _ready() -> void:
	progress = start_at
	forward = start_forward
	if not Engine.is_editor_hint():
		add_to_group(GreyboxLevel.RESETTABLE)
		process_physics_priority = 15  # после движения игроков


func radius() -> float:
	return radius_tiles * GreyboxLevel.TILE


## Середина диска в мире.
func blade_position() -> Vector2:
	return global_position + path_tiles * GreyboxLevel.TILE * progress


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_spin += delta * 14.0
	var length := (path_tiles * GreyboxLevel.TILE).length()
	if length > 0.0:
		var next := clampf(progress + (1.0 if forward else -1.0) * speed * delta / length, 0.0, 1.0)
		var next_center := global_position + path_tiles * GreyboxLevel.TILE * next
		# Упёрлась в замершего или ящик — назад. Если диск уже касается тела (замер вплотную),
		# от него не отскакивает, а выезжает: иначе застрял бы, зажатый с обеих сторон.
		if _blocked(next_center) and not _blocked(blade_position()):
			forward = not forward
		else:
			progress = next
			if progress <= 0.0 or progress >= 1.0:
				forward = progress <= 0.0
	var center := blade_position()
	var cut := radius() - BITE
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and not player.frozen \
				and _circle_hits(center, cut, Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			player.die()
	queue_redraw()


func _blocked(center: Vector2) -> bool:
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.frozen \
				and _circle_hits(center, radius(), Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			return true
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		if crate.visible and _circle_hits(center, radius(), crate.get_rect()):
			return true
	return false


static func _circle_hits(center: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < r * r


func save_state() -> Variant:
	return [progress, forward]


func load_state(state: Variant) -> void:
	progress = state[0]
	forward = state[1]


func _draw() -> void:
	var end := path_tiles * GreyboxLevel.TILE
	# Рельс: тёмный паз со светлой серединой и упорами на концах.
	if end != Vector2.ZERO:
		draw_line(Vector2.ZERO, end, OUTLINE, 10.0)
		draw_line(Vector2.ZERO, end, Color("5b6470"), 4.0)
		for point: Vector2 in [Vector2.ZERO, end]:
			draw_circle(point, 7.0, OUTLINE)
			draw_circle(point, 4.0, Color("8a919c"))
	var p := end * (start_at if Engine.is_editor_hint() else progress)
	var r := radius()
	# Диск с зубьями: контур, сталь, тёмное кольцо, ступица. Вращается.
	var teeth := 14
	var outer := PackedVector2Array()
	var steel := PackedVector2Array()
	for i in teeth * 2:
		var angle := _spin + i * PI / teeth
		var rr := r if i % 2 == 0 else r * 0.8
		outer.append(p + Vector2.from_angle(angle) * (rr + 3.0))
		steel.append(p + Vector2.from_angle(angle) * rr)
	draw_colored_polygon(outer, OUTLINE)
	draw_colored_polygon(steel, Color("c3cad4"))
	draw_circle(p, r * 0.62, Color("8a919c"))
	draw_arc(p, r * 0.62, _spin, _spin + PI * 0.7, 10, Color("e6eaef"), 3.0)
	draw_circle(p, r * 0.22, OUTLINE)
	draw_circle(p, r * 0.12, Color("c3cad4"))
