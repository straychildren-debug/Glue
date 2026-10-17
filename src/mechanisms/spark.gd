@tool
class_name Spark
extends Node2D
## Искра (E3): бегает по проводам (Wire). Касание незамершего — гибель (общий респавн).
## Замерший на проводе — изолятор: искра в него упирается и бежит назад.
## Дойдя до бочонка (Wire.target), поджигает фитиль и через respawn_time снова выбегает
## из начала своего провода; так же — дойдя до заземления (Wire.grounded). В тупике поворачивает назад.
## Положение узла роли не играет: искра стартует с начала провода wire.

const OUTLINE := Color("1a1d33")
const RADIUS := 13.0

@export var wire: NodePath
@export var speed := 220.0
## Через сколько секунд после поджога искра снова выбегает из начала.
@export var respawn_time := 2.0

var _wire: Wire
var _s := 0.0
var _dir := 1.0
var _hidden := 0.0  # > 0 — искра ушла в фитиль и ждёт
var _time := 0.0
var _face := 1.0  # куда бежит по экрану: хвост пламени — сзади
var _last_x := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 16  # после движения игроков
	_reset.call_deferred()


func _reset() -> void:
	_wire = get_node_or_null(wire) as Wire
	_s = 0.0
	_dir = 1.0
	_hidden = 0.0
	if _wire:
		global_position = _wire.at(0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _wire == null:
		return
	_time += delta
	queue_redraw()
	if _hidden > 0.0:
		_hidden -= delta
		if _hidden <= 0.0:
			_reset()
		return
	var step := speed * delta * _dir
	var next_s := _s + step
	var probe := _wire.at(clampf(next_s, 0.0, _wire.length()))
	if _insulated(probe):
		_dir = -_dir
		return
	_s = next_s
	var length := _wire.length()
	if _s >= length:
		var next := _wire.next_wire()
		var target := _wire.get_node_or_null(_wire.target) if not _wire.target.is_empty() else null
		if next != null:
			_s -= length
			_wire = next
		elif (target != null and target.has_method("ignite")) or _wire.grounded:
			if target != null:
				target.ignite()
			_hidden = respawn_time
			visible = false
			return
		else:
			_s = length
			_dir = -1.0
	elif _s <= 0.0:
		_s = 0.0
		_dir = 1.0
	visible = true
	global_position = _wire.at(_s)
	if absf(global_position.x - _last_x) > 0.1:
		_face = signf(global_position.x - _last_x)
	_last_x = global_position.x
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and not player.frozen and Saw._circle_hits(global_position, RADIUS,
				Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			player.die()


## Замерший касается провода в точке point — изолятор.
func _insulated(point: Vector2) -> bool:
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.frozen and Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE).grow(RADIUS * 0.5).has_point(point):
			return true
	return false


func save_state() -> Variant:
	return null


func load_state(_state: Variant) -> void:
	_reset()
	visible = true


func _draw() -> void:
	if _hidden > 0.0:
		return
	if Art.enabled and Art.has("w2_spark"):
		# P29: огонёк с хвостом пламени влево; середина огонька — точка (69, 30) спрайта; мерцает.
		var sprite := Art.tex("w2_spark")
		var size := Vector2(sprite.get_size()) / 4.0
		var flicker := 1.0 + 0.06 * sin(_time * 40.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_face, 1.0) * flicker)
		draw_texture_rect(sprite, Rect2(Vector2(-69.0, -30.3), size), false)
		draw_set_transform(Vector2.ZERO)
		return
	# Огонёк: оранжевое пламя с жёлтой серединой, мерцает; тёмный контур — опасно.
	var flicker := 1.0 + 0.12 * sin(_time * 40.0)
	var flame := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		var r := RADIUS * flicker * (1.25 if i % 2 == 0 else 0.95)
		if i == 9:
			r *= 1.5  # язычок пламени вверх
		flame.append(Vector2.from_angle(a) * r)
	var outline := PackedVector2Array()
	for p in flame:
		outline.append(p * 1.25)
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(flame, Color("f28a1a"))
	draw_circle(Vector2.ZERO, RADIUS * 0.55, Color("ffe066"))
	draw_circle(Vector2(-3, -2), 2.0, OUTLINE)
	draw_circle(Vector2(3, -2), 2.0, OUTLINE)
