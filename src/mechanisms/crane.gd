@tool
class_name Crane
extends Node2D
## Кран-тележка (M2.6): тележка с крюком едет по рельсу под потолком, пока триггер активен
## (плита, защёлка, рычаг), и возвращается, когда нет. Крюк — обычный крюк (Hook): на нём висят,
## раскачиваются, строят цепь; кран везёт висящих.
## Грузовой кран (pallet_tiles > 0): вместо крюка — поддон на тросах; на нём едут ящики и герои.
## У поддона люк (trapdoor — рычаг): пока рычаг включён, днище раскрыто и всё с поддона падает.
## Положение узла — левый конец рельса; крюк (верх поддона) — на hang_tiles ниже рельса.

const OUTLINE := Color("1a1d33")

@export var length_tiles := 8.0:
	set(value):
		length_tiles = value
		queue_redraw()
@export var hang_tiles := 1.5:
	set(value):
		hang_tiles = value
		_place_hook()
		queue_redraw()
## Где тележка в покое: 0 — у левого конца, 1 — у правого. Активный триггер везёт её к другому концу.
@export_range(0.0, 1.0) var home := 0.0:
	set(value):
		home = value
		_t = value
		_place_hook()
		queue_redraw()
@export var speed := 170.0
@export var trigger: NodePath
## Ещё триггеры: тележка едет, пока активен любой (плиты на обоих берегах).
@export var triggers: Array[NodePath] = []
## Ширина поддона в тайлах; 0 — обычный крюк.
@export var pallet_tiles := 0.0
## Рычаг люка поддона.
@export var trapdoor: NodePath

var hook: Hook
var pallet: AnimatableBody2D
var _pallet_shape: CollisionShape2D
var _t := 0.0  # положение тележки на рельсе, 0..1


func _ready() -> void:
	hook = Hook.new()
	hook.name = "Hook"
	if pallet_tiles > 0.0:
		_make_pallet()
	else:
		add_child(hook, false, Node.INTERNAL_MODE_FRONT)
	_t = home
	_place_hook()
	if not Engine.is_editor_hint():
		add_to_group(GreyboxLevel.RESETTABLE)
		process_physics_priority = -5  # до игроков: связь хвата решается по новому месту крюка


func _make_pallet() -> void:
	pallet = AnimatableBody2D.new()
	pallet.name = "Pallet"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(pallet_tiles * GreyboxLevel.TILE, 16.0)
	_pallet_shape = CollisionShape2D.new()
	_pallet_shape.shape = shape
	_pallet_shape.position = Vector2(0.0, 8.0)
	pallet.add_child(_pallet_shape)
	pallet.collision_layer = Player.LAYER_WORLD
	pallet.collision_mask = 0
	pallet.sync_to_physics = true
	add_child(pallet, false, Node.INTERNAL_MODE_FRONT)


## Люк раскрыт (рычаг включён).
func trapdoor_open() -> bool:
	var lever: Node = get_node_or_null(trapdoor) if not trapdoor.is_empty() else null
	return lever != null and lever.active


func _place_hook() -> void:
	if hook == null:
		return
	hook.position = Vector2(_t * length_tiles * GreyboxLevel.TILE, hang_tiles * GreyboxLevel.TILE)
	if pallet != null:
		pallet.position = hook.position


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var active := false
	for path in [trigger] + triggers:
		var node: Node = get_node_or_null(path) if not path.is_empty() else null
		if node != null and node.active:
			active = true
	var target := (1.0 - home) if active else home
	var length := length_tiles * GreyboxLevel.TILE
	var before := _t
	_t = move_toward(_t, target, speed * delta / length)
	hook.velocity = Vector2((_t - before) * length / delta, 0.0)
	_place_hook()
	if pallet != null:
		_pallet_shape.set_deferred("disabled", trapdoor_open())
	queue_redraw()


func save_state() -> Variant:
	return _t


func load_state(state: Variant) -> void:
	_t = state
	hook.velocity = Vector2.ZERO
	_place_hook()
	queue_redraw()


func _draw() -> void:
	var length := length_tiles * GreyboxLevel.TILE
	if Art.enabled and Art.has("w2_trolley"):
		# Рельс — балка с кронштейнами на концах; тележка надета на рельс (ось рельса — строка 20 спрайта).
		Art.draw_strip_h(self, Rect2(-10, -11.8, length + 20, 23.6), "w2_rail_mid", "w2_rail_end")
		# P25: тележка на оси рельса (строка 86 куска), от неё вниз — стержень тяги до крюка.
		var trolley := Art.tex("w2_trolley")
		var size := Vector2(83.0, 83.0 * trolley.get_height() / trolley.get_width())
		var tx := _t * length
		var hang_px := hang_tiles * GreyboxLevel.TILE
		if pallet_tiles > 0.0:
			_draw_pallet(tx, hang_px)  # поддон на тросах вместо тяги с крюком
		elif Art.has("w2_rod"):
			draw_texture_rect(Art.tex("w2_rod"), Rect2(Vector2(tx - 4.0, 10.0), Vector2(8.0, hang_px - 32.0)), false)
		draw_texture_rect(trolley, Rect2(Vector2(tx - size.x / 2.0, -86.0 * size.y / trolley.get_height()), size), false)
		return
	# Рельс-двутавр с упорами на концах.
	draw_rect(Rect2(-8, -8, length + 16, 16), OUTLINE)
	draw_rect(Rect2(-5, -5, length + 10, 10), Color("6b4a2a"))
	for x in [-8.0, length + 2.0]:
		draw_rect(Rect2(x, -14, 6, 28), OUTLINE)
	# Тележка с двумя колёсами и трос до крюка.
	var x := _t * length
	var hang := hang_tiles * GreyboxLevel.TILE
	draw_rect(Rect2(x - 22, 4, 44, 16), OUTLINE)
	draw_rect(Rect2(x - 19, 7, 38, 10), Color("8a5a30"))
	for wx in [x - 12.0, x + 12.0]:
		draw_circle(Vector2(wx, -2), 8.0, OUTLINE)
		draw_circle(Vector2(wx, -2), 5.0, Color("9aa3ad"))
	if pallet_tiles <= 0.0:
		draw_line(Vector2(x, 20), Vector2(x, hang - 22), OUTLINE, 6.0)
		draw_line(Vector2(x, 20), Vector2(x, hang - 22), Color("c8b48a"), 3.0)
		return
	_draw_pallet(x, hang)


## Поддон на четырёх тросах; раскрытый люк — створки повисли вниз.
func _draw_pallet(x: float, hang: float) -> void:
	var half := pallet_tiles * GreyboxLevel.TILE / 2.0
	if Art.enabled and Art.has("w2_pallet"):
		# N5: закрытый — верх настила на 0,857 высоты картинки; раскрытый — рама на 0,53. Трос — до крюка.
		var open := not Engine.is_editor_hint() and trapdoor_open()
		var sprite := Art.tex("w2_pallet_open" if open else "w2_pallet")
		var h := sprite.get_height() * half * 2.0 / sprite.get_width()
		var top := hang - (0.53 if open else 0.857) * h
		draw_line(Vector2(x, 20), Vector2(x, top + 6.0), OUTLINE, 6.0)
		draw_line(Vector2(x, 20), Vector2(x, top + 6.0), Color("c8b48a"), 3.0)
		draw_texture_rect(sprite, Rect2(x - half, top, half * 2.0, h), false)
		if not trapdoor.is_empty():
			Lever.draw_mark(self, Vector2(x, hang - 20.0), Color(0.9, 0.5, 0.2))
		return
	for sx in [-half + 6.0, half - 6.0]:
		draw_line(Vector2(x, 20), Vector2(x + sx, hang), OUTLINE, 4.0)
		draw_line(Vector2(x, 20), Vector2(x + sx, hang), Color("c8b48a"), 2.0)
	if Engine.is_editor_hint() or not trapdoor_open():
		draw_rect(Rect2(x - half, hang, half * 2.0, 16.0), OUTLINE)
		draw_rect(Rect2(x - half + 3.0, hang + 3.0, half * 2.0 - 6.0, 10.0), Color("b08a5a"))
		draw_line(Vector2(x, hang + 2.0), Vector2(x, hang + 14.0), OUTLINE, 2.0)
	else:
		for s in [-1.0, 1.0]:
			var hinge := Vector2(x + s * half, hang + 8.0)
			draw_line(hinge, hinge + Vector2(-s * 10.0, half * 0.9), OUTLINE, 10.0)
			draw_line(hinge, hinge + Vector2(-s * 10.0, half * 0.9), Color("b08a5a"), 5.0)
	if not trapdoor.is_empty():
		Lever.draw_mark(self, Vector2(x, hang - 20.0), Color(0.9, 0.5, 0.2))
