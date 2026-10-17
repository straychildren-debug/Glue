@tool
class_name Crusher
extends Node2D
## Обвал (погоня, как наезжающий экран в Pico Park): стена камней с шипами ползёт вправо,
## когда кто-нибудь пересёк линию старта. Касание живого — гибель (общий респавн). Замерший —
## камень: стена толкает его перед собой, а прижатого к препятствию давит. Сквозь блоки уровня
## проходит. Отстав дальше catch_up_tiles, догоняет быстрее. Подойдя к команде ближе camera_tiles,
## держит свой край в кадре — погоню видно.
## При общем респавне возвращается к состоянию чекпоинта (с чекпоинта на старте — назад и стоит).
## Если на чекпоинте он уже ехал, после респавна отходит не ближе restart_gap_tiles от команды
## и ждёт, пока кто-нибудь шагнёт вперёд, — иначе гибель за гибелью у самого чекпоинта.
## Пока не тронулся — невидим и безопасен: так обвал можно поставить и посреди уровня.
## Положение узла — верх переднего края стены; стена уходит вниз на height_tiles и влево на thickness_tiles.

const GROUP := "camera_hints"
const OUTLINE := Color("1a1d33")
const TOOTH := 40.0

@export var height_tiles := 24.0:
	set(value):
		height_tiles = value
		queue_redraw()
@export var thickness_tiles := 3.0:
	set(value):
		thickness_tiles = value
		queue_redraw()
## Скорость, px/с (бег игрока — 360).
@export var speed := 150.0
## Обвал трогается, когда кто-нибудь из живых зашёл правее этой линии (тайлы, в мире).
@export var start_x_tiles := 6.0
## Дальше этой линии (тайлы, в мире) передний край не идёт.
@export var stop_x_tiles := 1000.0
## Догоняет: дальше этого от самого отставшего (тайлы) обвал едет быстрее — catch_up_speed,
## чтобы давление было на каждом участке, а не только на первом. 0 — не догоняет.
@export var catch_up_tiles := 0.0
@export var catch_up_speed := 260.0
## После респавна на чекпоинте, взятом на ходу, — не ближе этого к команде, тайлы.
@export var restart_gap_tiles := 8.0
## С какого расстояния до самого отставшего игрока край обвала держится в кадре, тайлы.
@export var camera_tiles := 12.0

var active := false
var _shake := 0.0
## Линия, за которой обвал трогается (px, в мире); после респавна — чуть впереди команды.
var _start_line := 0.0
## После респавна: отойти от команды и ждать, пока она тронется.
var _rearm := false
## Точка для камеры: передний край на высоте самого отставшего игрока.
var _hint := Node2D.new()
var _hint_on := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	add_to_group(GROUP)
	add_child(_hint)
	_start_line = start_x_tiles * GreyboxLevel.TILE
	z_index = 5
	process_physics_priority = 16  # после движения игроков


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var players: Array = get_tree().get_nodes_in_group(Player.GROUP).filter(
			func(p: Player) -> bool: return p.alive)
	if _rearm and players.size() == get_tree().get_nodes_in_group(Player.GROUP).size() and not players.is_empty():
		var rear := INF
		for p: Player in players:
			rear = minf(rear, p.global_position.x)
		global_position.x = minf(global_position.x, rear - restart_gap_tiles * GreyboxLevel.TILE)
		_start_line = rear + GreyboxLevel.TILE
		_rearm = false
	# Трогается, когда линию прошла вся команда: иначе убежавший вперёд будил обвал, и тот
	# сразу давил отставшего товарища.
	if not active and not _rearm and not players.is_empty():
		active = players.all(func(p: Player) -> bool: return p.global_position.x > _start_line)
	if active:
		var pace := speed
		if catch_up_tiles > 0.0 and not players.is_empty():
			var rear := INF
			for p: Player in players:
				rear = minf(rear, p.global_position.x)
			if rear - global_position.x > catch_up_tiles * GreyboxLevel.TILE:
				pace = catch_up_speed
		global_position.x = minf(global_position.x + pace * delta, stop_x_tiles * GreyboxLevel.TILE)
		_shake += delta
		queue_redraw()
	visible = active  # не тронулся — его не видно (обвал посреди уровня появляется, когда команда прошла линию)
	if active:
		_crush(players)
	_update_hint(players)


func _crush(players: Array) -> void:
	var front := global_position.x
	var top := global_position.y
	var bottom := top + height_tiles * GreyboxLevel.TILE
	for p: Player in players:
		var body := Rect2(p.global_position - Player.SIZE / 2.0, Player.SIZE)
		if body.position.x >= front or body.end.y <= top or body.position.y >= bottom:
			continue
		if p.frozen:
			var offset := Vector2(front - body.position.x + 0.5, 0.0)
			if not p.test_move(p.global_transform, offset):
				p.shove(offset)
				continue
		p.die()


func _update_hint(players: Array) -> void:
	_hint_on = false
	if not active or players.is_empty():
		return
	var rear: Player = players[0]
	for p: Player in players:
		if p.global_position.x < rear.global_position.x:
			rear = p
	if rear.global_position.x - global_position.x > camera_tiles * GreyboxLevel.TILE:
		return
	_hint.global_position = Vector2(global_position.x, rear.global_position.y)
	_hint_on = true


## Цель для общей камеры или null, если обвал далеко.
func camera_target() -> Node2D:
	return _hint if _hint_on else null


func save_state() -> Variant:
	return [position, active]


func load_state(state: Variant) -> void:
	position = state[0]
	_rearm = state[1]  # ехал на чекпоинте — после респавна отойти и ждать
	active = false
	if not _rearm:
		_start_line = start_x_tiles * GreyboxLevel.TILE
	_hint_on = false
	queue_redraw()


func _draw() -> void:
	var t := GreyboxLevel.TILE
	var h := height_tiles * t
	var w := thickness_tiles * t
	var jitter := sin(_shake * 40.0) * 2.0 if active else 0.0
	draw_set_transform(Vector2(jitter, 0.0))
	if Art.enabled and Art.has("rockfall"):
		# Обвал P18: кончики шипов — на переднем крае смертельной зоны; копии одна под другой.
		var sprite := Art.tex("rockfall")
		var piece := Vector2(w + TOOTH * 0.9, 0.0)
		piece.y = sprite.get_height() * piece.x / sprite.get_width()
		var y := 0.0
		var flip := false
		while y < h:
			draw_texture_rect(Art.tex_flipped("rockfall", true) if flip else sprite,
					Rect2(Vector2(-w, y), piece), false)
			y += piece.y
			flip = not flip
		draw_set_transform(Vector2.ZERO)
		return
	# Каменная стена: тёмная кладка, светлее к краю.
	draw_rect(Rect2(-w, 0, w, h), OUTLINE)
	draw_rect(Rect2(-w + 4, 4, w - 8, h - 8), Color("4b4f5c"))
	draw_rect(Rect2(-w * 0.45, 4, w * 0.45 - 4, h - 8), Color("5d6270"))
	var rows := int(h / 48.0)
	for i in rows:
		var y := i * 48.0 + 24.0
		var shift := 24.0 if i % 2 else 0.0
		var x := -w + 8.0 + shift
		while x < -16.0:
			draw_rect(Rect2(x, y - 20.0, 40.0, 36.0), Color("434754"), false, 3.0)
			x += 48.0
	# Шипы по переднему краю: стальные с красными кончиками.
	var y0 := 8.0
	while y0 < h - 8.0:
		var tip := Vector2(TOOTH * 0.9, y0 + TOOTH / 2.0)
		var base_a := Vector2(-4.0, y0)
		var base_b := Vector2(-4.0, y0 + TOOTH)
		draw_colored_polygon(PackedVector2Array([base_a + Vector2(0, -3), tip + Vector2(5, 0), base_b + Vector2(0, 3)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([base_a, tip, base_b]), Color("c9ced8"))
		draw_colored_polygon(PackedVector2Array([tip, tip.lerp(base_a, 0.3), tip.lerp(base_b, 0.3)]), Color("e5484d"))
		y0 += TOOTH + 6.0
	draw_set_transform(Vector2.ZERO)
