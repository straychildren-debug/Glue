@tool
class_name Lantern
extends Node2D
## Фонарь: светит на light_tiles вокруг (в тёмном цехе — Darkness). Подошёл и нажал хват — взял:
## фонарь в руке у героя и светит вокруг него; хват после этого снова свободен (держать товарища).
## Погибший роняет фонарь; при общем респавне фонарь висит там, где был на чекпоинте.
## Положение узла — где фонарь висит на крюке в начале.

const GROUP := "lanterns"
const OUTLINE := Color("1a1d33")
## С какого расстояния (px) до фонаря его можно взять.
const REACH := 70.0

@export var light_tiles := 4.5
## Сквозняк (тайлы: x, y, ширина, высота): тут фонарь гаснет — светят только искры.
@export var draft_tiles := Rect2()

var holder: Player = null
var _home := Vector2.ZERO
var _sway := 0.0


func _ready() -> void:
	_home = position
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 14  # после движения игроков: висит у героя в руке


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_sway += delta
	if holder != null and not holder.alive:
		holder = null  # погибший роняет фонарь там, где был
	if holder != null:
		global_position = holder.global_position + Vector2(holder.facing * 20.0, -4.0)
	var light: PointLight2D = get_meta("glow") if has_meta("glow") else null
	if light != null:
		light.enabled = shining()
	queue_redraw()


## Горит: не на сквозняке.
func shining() -> bool:
	if draft_tiles.size == Vector2.ZERO:
		return true
	var area := Rect2(draft_tiles.position * GreyboxLevel.TILE, draft_tiles.size * GreyboxLevel.TILE)
	return not area.has_point(global_position)


## Хват у ничейного фонаря: берёт; true — нажатие ушло фонарю.
static func try_take(player: Player) -> bool:
	for lantern: Lantern in player.get_tree().get_nodes_in_group(GROUP):
		if lantern.holder == null and lantern.global_position.distance_to(player.global_position) <= REACH:
			lantern.holder = player
			return true
	return false


## На чекпоинте фонарь остаётся там, где был (в руке у того, кто брал чекпоинт, — у чекпоинта):
## после общего респавна он висит рядом, а не на крюке у старта уровня.
func save_state() -> Variant:
	return position


func load_state(state: Variant) -> void:
	holder = null
	position = state
	queue_redraw()


func _draw() -> void:
	var tilt := sin(_sway * 3.0) * 0.12 if holder != null else 0.0
	draw_set_transform(Vector2.ZERO, tilt)
	var lit := Engine.is_editor_hint() or shining()
	if Art.enabled and Art.has("w2_lantern"):
		var art := "w2_lantern" if lit or not Art.has("w2_lantern_off") else "w2_lantern_off"
		draw_texture_rect(Art.tex(art), Rect2(-16, -38, 32, 56), false)  # N3: горящий или погасший
		draw_set_transform(Vector2.ZERO)
		return
	# Дужка, колпак, стекло со свечой, донце.
	draw_arc(Vector2(0, -14), 7.0, PI, TAU, 10, OUTLINE, 3.0)
	draw_rect(Rect2(-9, -14, 18, 5), OUTLINE)
	draw_rect(Rect2(-8, -9, 16, 16), OUTLINE)
	draw_rect(Rect2(-6, -7, 12, 12), Color("ffd27a") if lit else Color("4a4650"))
	if lit:
		draw_circle(Vector2(0, -1), 3.0, Color("fff4c8"))
	draw_rect(Rect2(-9, 7, 18, 4), OUTLINE)
	draw_set_transform(Vector2.ZERO)
