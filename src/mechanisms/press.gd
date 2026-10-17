@tool
class_name Press
extends AnimatableBody2D
## Пресс (M7): каменная плита в нише потолка ходит вверх-вниз — быстро падает, стоит внизу,
## медленно поднимается, стоит наверху. Придавил незамершего — гибель (общий респавн).
## Замерший — камень и подпорка: пресс встаёт на нём (и на ящике) и дальше не идёт. Кто замер
## в прыжке, держит пресс высоко — под ним проходит товарищ. Триггер hold (плита, защёлка, рычаг)
## поднимает пресс и держит наверху. Плита толщиной во весь ход: внизу её верх вровень с потолком
## коридора, поэтому на пресс не встать и в нишу никого не утащит.
## Положение узла — левый верхний угол плиты в верхнем положении.

enum State { TOP, FALL, BOTTOM, RISE }

const OUTLINE := Color("1a1d33")

@export var size_tiles := Vector2(4, 3):
	set(value):
		size_tiles = value
		queue_redraw()
## Ход вниз, тайлы (высота коридора под нишей).
@export var drop_tiles := 3.0
@export var fall_speed := 900.0
@export var rise_speed := 240.0
## Сколько секунд стоит наверху и внизу.
@export var top_wait := 0.6
@export var bottom_wait := 0.4
## Сдвиг цикла на старте, с: несколько прессов падают вразнобой.
@export var start_delay := 0.0
## Плита, защёлка или рычаг: пока активен, пресс поднят и стоит.
@export var hold: NodePath

var _state := State.TOP
var _timer := 0.0
var _top := Vector2.ZERO
## Текстура тела: держим ссылку, иначе ресурс выгружается сразу после отрисовки (рисуется белым).
var _fill: Texture2D


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # кладка тела повторяется
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = shape.size / 2.0
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	process_physics_priority = 25  # после плит и движения игроков
	_top = position
	_timer = top_wait + start_delay


func is_held() -> bool:
	if hold.is_empty():
		return false
	var trigger := get_node_or_null(hold)
	return trigger != null and trigger.active


## Пресс наверху и стоит (пауза между ходами).
func is_up() -> bool:
	return _state == State.TOP


func get_rect() -> Rect2:
	return Rect2(global_position, size_tiles * GreyboxLevel.TILE)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var held := is_held()
	match _state:
		State.TOP:
			_timer -= delta
			if _timer <= 0.0 and not held:
				_state = State.FALL
		State.FALL:
			if held:
				_state = State.RISE
				return
			var bottom := _top.y + drop_tiles * GreyboxLevel.TILE
			var step := minf(fall_speed * delta, bottom - position.y)
			var limit := _prop_gap()
			var blocked := limit <= step
			step = clampf(minf(step, limit), 0.0, INF)
			_crush(step)
			position.y += step
			if blocked or position.y >= bottom - 0.01:
				_state = State.BOTTOM
				_timer = bottom_wait
		State.BOTTOM:
			_timer -= delta
			if _timer <= 0.0 or held:
				_state = State.RISE
		State.RISE:
			position.y = move_toward(position.y, _top.y, rise_speed * delta)
			if position.y <= _top.y:
				_state = State.TOP
				_timer = top_wait


## Сколько пресс может опуститься до ближайшей подпорки под ним: замершего игрока или ящика.
func _prop_gap() -> float:
	var rect := get_rect()
	var gap := INF
	var props: Array[Rect2] = []
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.frozen:
			props.append(Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE))
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		if crate.visible:
			props.append(crate.get_rect())
	for prop in props:
		if prop.end.x > rect.position.x and prop.position.x < rect.end.x and prop.position.y >= rect.end.y - 2.0:
			gap = minf(gap, prop.position.y - rect.end.y)
	return gap


## Незамерший под опускающейся плитой погибает.
func _crush(step: float) -> void:
	var next := Rect2(global_position + Vector2(0, step), size_tiles * GreyboxLevel.TILE)
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if not player.alive or player.frozen:
			continue
		var body := Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)
		if next.intersects(body) and body.end.y > next.get_center().y:
			player.die()


func save_state() -> Variant:
	return [position, _state, _timer]


func load_state(state: Variant) -> void:
	position = state[0]
	_state = state[1]
	_timer = state[2]


func _draw() -> void:
	# Каменная плита с тёмным контуром, кованой оковкой и зубьями снизу: опасное читается сразу.
	var size := size_tiles * GreyboxLevel.TILE
	var rect := Rect2(Vector2.ZERO, size)
	if Art.enabled:
		_draw_sprites(size)
		return
	draw_rect(rect, OUTLINE)
	var stone := rect.grow(-4.0)
	draw_rect(stone, Color("8a8f98"))
	# Швы кладки.
	var rows := maxi(1, int(size_tiles.y * 2.0))
	for row in rows:
		var y := stone.position.y + stone.size.y * row / rows
		if row > 0:
			draw_line(Vector2(stone.position.x, y), Vector2(stone.end.x, y), Color("6b707a"), 3.0)
		var offset := 0.0 if row % 2 == 0 else GreyboxLevel.TILE / 2.0
		var x := stone.position.x + offset + GreyboxLevel.TILE
		while x < stone.end.x - 4.0:
			draw_line(Vector2(x, y), Vector2(x, y + stone.size.y / rows), Color("6b707a"), 3.0)
			x += GreyboxLevel.TILE
	# Оковка и зубья.
	var band := Rect2(Vector2(0, size.y - 34.0), Vector2(size.x, 18.0))
	draw_rect(band, OUTLINE)
	draw_rect(band.grow(-3.0), Color("4b5563"))
	# Зубья — в пределах плиты: внизу пресс ложится на пол ровно.
	var teeth := maxi(2, int(size.x / 22.0))
	var step := size.x / teeth
	for i in teeth:
		var x0 := i * step
		var tip := Vector2(x0 + step / 2.0, size.y)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + 1.0, size.y - 16.0), tip, Vector2(x0 + step - 1.0, size.y - 16.0)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4.0, size.y - 14.0), tip + Vector2(0, -4.0), Vector2(x0 + step - 4.0, size.y - 14.0)]), Color("c3cad4"))


## Графика: тело — кладка зоны уровня (та же, что у платформ), чуть темнее и в контуре;
## снизу — железная оковка с зубьями (спрайт v2, торцы и повторяющаяся середина).
func _draw_sprites(size: Vector2) -> void:
	var level := get_parent()
	while level != null and not level is GreyboxLevel:
		level = level.get_parent()
	if _fill == null:
		_fill = load(Ground.path(level.ground_fill if level else "w01_stone_fill"))
	var fill := _fill
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE)
	# Текстуры платформ вдвое крупнее экрана (Ground.TEXELS_PER_PX) — рисуем в масштабе 1/2.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	draw_texture_rect(fill, Rect2(Vector2(6, 6), size * 2.0 - Vector2(12, 12)), true, Color(0.82, 0.82, 0.86))
	draw_set_transform(Vector2.ZERO)
	var teeth := 26.0
	Art.draw_strip_h(self, Rect2(0, size.y - teeth, size.x, teeth), "press_teeth_mid", "press_teeth_end")
