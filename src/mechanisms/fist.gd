@tool
class_name Fist
extends AnimatableBody2D
## Кулак «Большой машины»: тяжёлый молот на рельсе под потолком. Едет за своей добычей (герой prey или
## ближайший), над ней замирает — на полу тень (wind_time) — и бьёт вниз до пола. Придавил героя —
## гибель, и замершего тоже: кулак машины бьёт сильнее пресса, «Замри» не спасает. Ящик — подпорка:
## кулак встаёт на него (ящик выше героя — под кулаком на ящике герой цел). Ударив, застревает на stuck_time:
## на застрявший кулак можно запрыгнуть, как на ступеньку, — с него достать высокие уступы. Потом
## поднимается и снова охотится. rage (его задаёт машина) — во сколько раз быстрее всё.
## Положение узла — левый верхний угол кулака в верхнем положении; рельс — от x_min до x_max (тайлы).

const OUTLINE := Color("1a1d33")
enum State { TRACK, WINDUP, SLAM, STUCK, RISE }

@export var size_tiles := Vector2(2, 2):
	set(value):
		size_tiles = value
		queue_redraw()
@export var x_min := 2.0
@export var x_max := 30.0
## Пол под рельсом (тайлы): до него бьёт кулак.
@export var floor_y := 12.0
## Чья добыча: 0 — первый герой, 1 — второй, −1 — ближайший.
@export var prey := -1
@export var track_speed := 230.0
@export var wind_time := 0.6
@export var slam_speed := 1500.0
@export var stuck_time := 1.2
@export var rise_speed := 420.0
## Сколько стоит наверху над целью, прежде чем замахнуться, с.
@export var aim_time := 0.35
@export var rage := 1.0
## Выключен — висит наверху и не бьёт (машина включает по фазам).
@export var enabled := true
## В какой фазе машины кулак работает (0 — всегда, машина не трогает).
@export var phase := 0

var state := State.TRACK
var _timer := 0.0
var _top_y := 0.0
var _home := Vector2.ZERO
var _shake := 0.0
var _collision: CollisionShape2D


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = shape.size / 2.0
	add_child(collision)
	_collision = collision
	if Engine.is_editor_hint():
		return
	_home = position
	_top_y = position.y
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	process_physics_priority = 25


func get_rect() -> Rect2:
	return Rect2(global_position, size_tiles * GreyboxLevel.TILE)


## Нижний край кулака в самом низу (на полу).
func _bottom_y() -> float:
	return floor_y * GreyboxLevel.TILE - size_tiles.y * GreyboxLevel.TILE


func _target_x() -> float:
	var players: Array = get_tree().get_nodes_in_group(Player.GROUP).filter(func(p: Player) -> bool: return p.alive)
	if players.is_empty():
		return position.x
	var target: Player = null
	if prey >= 0:
		for p: Player in players:
			if p.slot == prey:
				target = p
	if target == null:
		target = players[0]
		for p: Player in players:
			if absf(p.global_position.x - global_position.x) < absf(target.global_position.x - global_position.x):
				target = p
	var w := size_tiles.x * GreyboxLevel.TILE
	return clampf(target.global_position.x - w / 2.0, x_min * GreyboxLevel.TILE, x_max * GreyboxLevel.TILE - w)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_shake = maxf(_shake - delta, 0.0)
	if not enabled:
		position.y = move_toward(position.y, _top_y, rise_speed * delta)
		queue_redraw()
		return
	var d := delta * rage
	match state:
		State.TRACK:
			var tx := _target_x()
			position.x = move_toward(position.x, tx, track_speed * d)
			if absf(position.x - tx) < 2.0:
				_timer += d
				if _timer >= aim_time:
					state = State.WINDUP
					_timer = wind_time
			else:
				_timer = 0.0
		State.WINDUP:
			_timer -= d
			if _timer <= 0.0:
				state = State.SLAM
		State.SLAM:
			var bottom := _bottom_y()
			var step := minf(slam_speed * d, bottom - position.y)
			var gap := _prop_gap()
			var blocked := gap <= step
			step = clampf(minf(step, gap), 0.0, INF)
			_crush(step)
			position.y += step
			if blocked or position.y >= bottom - 0.01:
				state = State.STUCK
				_timer = stuck_time
				_shake = 0.4
		State.STUCK:
			_timer -= d
			if _timer <= 0.0:
				state = State.RISE
		State.RISE:
			position.y = move_toward(position.y, _top_y, rise_speed * d)
			if position.y <= _top_y:
				state = State.TRACK
				_timer = 0.0
	# Твёрдый только застрявший — на него можно встать; поднимаясь, сквозь уступы и героев не тащит их вверх.
	_collision.disabled = state != State.STUCK
	queue_redraw()


## Сколько можно опуститься до подпорки — ящика под кулаком.
func _prop_gap() -> float:
	var rect := get_rect()
	var gap := INF
	for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
		var c := crate.get_rect()
		if crate.visible and c.position.x < rect.end.x and c.end.x > rect.position.x and c.position.y >= rect.end.y - 1.0:
			gap = minf(gap, c.position.y - rect.end.y)
	return maxf(gap, 0.0)


## Герой под опускающимся кулаком гибнет — и замерший тоже.
func _crush(step: float) -> void:
	var next := Rect2(global_position + Vector2(0, step), size_tiles * GreyboxLevel.TILE)
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if not player.alive:
			continue
		var body := Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE).grow(-4.0)
		if next.intersects(body):
			player.die()


## Где тень на полу и замах ли сейчас (для бота и игрока).
func is_winding() -> bool:
	return enabled and state == State.WINDUP


func is_dangerous() -> bool:
	return enabled and (state == State.WINDUP or state == State.SLAM)


func save_state() -> Variant:
	return [position, state, _timer, rage, enabled]


func load_state(s: Variant) -> void:
	position = s[0]
	state = s[1]
	_timer = s[2]
	rage = s[3]
	enabled = s[4]
	queue_redraw()


func _draw() -> void:
	var size := size_tiles * GreyboxLevel.TILE
	var jitter := Vector2(sin(_shake * 80.0) * 3.0, 0.0) if _shake > 0.0 else Vector2.ZERO
	if Engine.is_editor_hint():
		draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, -40), OUTLINE, 6.0)
	# Тяга вверх до рельса.
	var up := -(position.y - _top_y) - 30.0 if not Engine.is_editor_hint() else -30.0
	draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, up), OUTLINE, 10.0)
	draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, up), Color("8a919c"), 5.0)
	# Тень на полу при замахе.
	if not Engine.is_editor_hint() and state == State.WINDUP:
		var floor_local := floor_y * GreyboxLevel.TILE - global_position.y
		var k := 1.0 - _timer / maxf(wind_time, 0.01)
		draw_rect(Rect2(Vector2(4, floor_local - 10), Vector2(size.x - 8, 10)), Color(0.1, 0.05, 0.1, 0.35 + 0.4 * k))
		draw_rect(Rect2(Vector2(0, floor_local - 4), Vector2(size.x, 4)), Color(1, 0.25, 0.15, 0.4 + 0.5 * k))
	# Кулак: тёмный чугун, костяшки сверху вниз, заклёпки; при замахе — красный накал.
	draw_set_transform(jitter)
	var hot_art := state == State.WINDUP or state == State.SLAM
	var art := "w2_fist_hot" if hot_art else "w2_fist"
	if Art.enabled and Art.has(art):
		# спрайт N6 — шире, чем выше: по ширине кулака, костяшками к низу (ими он и давит)
		var sprite := Art.tex(art)
		var h := sprite.get_height() * size.x / sprite.get_width()
		draw_texture_rect(sprite, Rect2(0, size.y - h, size.x, h), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE)
	var hot := state == State.WINDUP or state == State.SLAM
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color("6a4a44") if hot else Color("4b4f5c"))
	for i in 4:
		var x := 8.0 + i * (size.x - 16.0) / 4.0
		draw_rect(Rect2(Vector2(x, size.y - 26), Vector2((size.x - 16.0) / 4.0 - 4.0, 20)), Color("2c303a"))
		draw_rect(Rect2(Vector2(x + 2, size.y - 24), Vector2((size.x - 16.0) / 4.0 - 8.0, 8)), Color("8a919c"))
	for p in [Vector2(14, 14), Vector2(size.x - 14, 14)]:
		draw_circle(p, 5.0, OUTLINE)
		draw_circle(p, 3.0, Color("c8b48a"))
	draw_set_transform(Vector2.ZERO)
