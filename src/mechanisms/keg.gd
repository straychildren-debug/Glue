@tool
class_name Keg
extends Node2D
## Бочонок с фитилём (M2.8): искра поджигает фитиль, через fuse_time — взрыв: треснувшие стены
## walls рушатся, незамерших в радиусе blast_tiles сносит (гибель — общий респавн). Замерший —
## камень: взрыв ему не страшен. Порядок: сначала уйти из-под стены.
## Состояние (цел, горит, взорван) возвращается к чекпоинту вместе со стенами.
## Положение узла — середина дна бочонка на полу.

enum State { READY, LIT, BLOWN }

const OUTLINE := Color("1a1d33")

@export var walls: Array[NodePath] = []
@export var fuse_time := 1.5
@export var blast_tiles := 2.0

var state := State.READY
var _timer := 0.0
var _flash := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GreyboxLevel.RESETTABLE)


func ignite() -> void:
	if state == State.READY:
		state = State.LIT
		_timer = fuse_time


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	if state != State.LIT:
		return
	_timer -= delta
	queue_redraw()
	if _timer <= 0.0:
		_explode()


func _explode() -> void:
	state = State.BLOWN
	_flash = 0.5
	var center := global_position + Vector2(0, -24)
	for path in walls:
		var wall := get_node_or_null(path)
		if wall and wall.has_method("smash"):
			wall.smash()
	var radius := blast_tiles * GreyboxLevel.TILE
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and not player.frozen and Saw._circle_hits(center, radius,
				Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			player.die()


func save_state() -> Variant:
	return State.BLOWN if state == State.BLOWN else State.READY


func load_state(saved: Variant) -> void:
	state = saved
	_timer = 0.0
	_flash = 0.0
	queue_redraw()


func _draw() -> void:
	if state == State.BLOWN:
		if _flash > 0.0:
			var r := blast_tiles * GreyboxLevel.TILE * (1.0 - _flash)
			draw_circle(Vector2(0, -24), r, Color(1.0, 0.8, 0.3, _flash))
		return
	if state == State.LIT:
		# Предупреждение: круг взрыва мигает тем чаще, чем меньше осталось.
		var left := clampf(_timer / maxf(fuse_time, 0.01), 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin((1.0 - left) * (6.0 + 30.0 * (1.0 - left)))
		var r := blast_tiles * GreyboxLevel.TILE
		draw_circle(Vector2(0, -24), r, Color(1.0, 0.45, 0.15, 0.08 + 0.12 * blink))
		draw_arc(Vector2(0, -24), r, 0.0, TAU, 48, Color(1.0, 0.35, 0.1, 0.5 + 0.4 * blink), 4.0)
	var top := -48.0
	if Art.enabled and Art.has("w2_keg_lit"):
		# P27: фитиль нарисован; горящий — свой рисунок с искрой, она мерцает.
		var lit := state == State.LIT
		var sprite := Art.tex("w2_keg_lit" if lit else "w2_keg")
		var size := Vector2(sprite.get_size()) / 4.0
		var tint := Color(1, 1, 1, 0.75 + 0.25 * sin(_timer * 30.0)) if lit else Color.WHITE
		draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, -size.y + 0.25), size), false)
		if lit:
			draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, -size.y + 0.25), size), false, tint)
		return
	# Бочонок: деревянные клёпки, железные обручи; фитиль сверху, горящий — с огоньком.
	draw_rect(Rect2(-20, -48, 40, 48), OUTLINE)
	draw_rect(Rect2(-17, -45, 34, 42), Color("9a6a3a"))
	for y in [-38.0, -12.0]:
		draw_rect(Rect2(-20, y, 40, 6), OUTLINE)
		draw_rect(Rect2(-18, y + 1.5, 36, 3), Color("6b7280"))
	_draw_fuse(top)


## Фитиль из крышки; горящий — с огоньком на конце.
func _draw_fuse(top: float) -> void:
	var fuse_end := Vector2(10, top - 16.0)
	var line := PackedVector2Array([Vector2(0, top), Vector2(4, top - 8.0), fuse_end])
	draw_polyline(line, OUTLINE, 5.0)
	draw_polyline(line, Color("c8b48a"), 2.5)
	if state == State.LIT:
		var blink := 0.5 + 0.5 * sin(_timer * 30.0)
		draw_circle(fuse_end, 7.0, Color(1.0, 0.6, 0.1))
		draw_circle(fuse_end, 4.0, Color(1.0, 1.0, 0.5, blink))
