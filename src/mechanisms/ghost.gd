@tool
class_name Ghost
extends Node2D
## Призрак-стесняшка (как в Pico Park): летит сквозь стены к ближайшему игроку, пока на него
## никто не смотрит, и замирает, пряча лицо, когда хоть один смотрит. «Смотрит» — живой
## незамерший игрок, повёрнутый к призраку лицом (по горизонтали) и не слишком далеко.
## У замершего глаза закрыты: он не смотрит. Зато замерший — камень: касание ему не страшно.
## Касание незамершего — гибель (общий респавн). Положение узла — где призрак ждёт на чекпоинте.
## У призрака может быть своя комната (area_tiles): охотится он только на тех, кто в ней, и сам
## из неё не вылетает. Так призраки соседних комнат не сбегаются вместе, а вышедший из комнаты
## спасён. Стесняется же он любого взгляда — и из-за порога комнаты тоже.

const OUTLINE := Color("1a1d33")
const RADIUS := 26.0
## Призрак рисуется крупнее рисунка-основы — заметный, как и положено врагу.
const SCALE := 1.35

## Скорость и разгон, когда никто не смотрит; с места трогается медленно — успеешь обернуться.
@export var max_speed := 230.0
@export var accel := 420.0
## Дальше этого (px) призрак не видит игроков и не чувствует их взгляда — висит на месте.
@export var range_px := 1400.0
## В тёмном цехе (Darkness): взгляд останавливает, только если призрак освещён.
@export var needs_light := false
## Просыпается, когда кто-то из героев зашёл правее этой точки (тайлы; 0 — сразу): так призрак ждёт
## у входа и выходит охотиться уже за спиной у вошедших.
@export var wake_x_tiles := 0.0
## Комната призрака в тайлах (x, y, ширина, высота); пустая — без границ.
@export var area_tiles := Rect2():
	set(value):
		area_tiles = value
		queue_redraw()

var velocity := Vector2.ZERO
var watched := false
var _target: Player = null
var _bob := 0.0
var _home := Vector2.ZERO
var _awake := false


func _ready() -> void:
	_home = position
	if not Engine.is_editor_hint():
		add_to_group(GreyboxLevel.RESETTABLE)
		process_physics_priority = 15  # после движения игроков: их взгляд этого кадра


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_bob += delta
	var players := _active_players()
	if not _awake:
		for player in players:
			if player.global_position.x > wake_x_tiles * GreyboxLevel.TILE:
				_awake = true
		if not _awake:
			queue_redraw()
			return
	var area := get_area_px()
	watched = false
	_target = null
	var best := range_px
	for player in players:
		var dx := global_position.x - player.global_position.x
		var distance := player.global_position.distance_to(global_position)
		if distance > range_px or player.frozen:
			continue
		var lit := not needs_light or Darkness.is_lit(get_tree(), global_position)
		if absf(dx) > 4.0 and signi(roundi(signf(dx))) == player.facing and lit:
			watched = true
		if distance < best and (not has_area() or area.has_point(player.global_position)):
			best = distance
			_target = player
	if watched or _target == null:
		velocity = Vector2.ZERO  # смотрят — замер (и разгоняться снова с нуля)
	else:
		var desired := (_target.global_position - global_position).normalized() * max_speed
		velocity = velocity.move_toward(desired, accel * delta)
		global_position += velocity * delta
		if has_area():
			global_position = global_position.clamp(area.position, area.end)
	var touch := RADIUS * SCALE - 6.0
	for player in players:
		if not player.frozen and Saw._circle_hits(global_position, touch,
				Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			player.die()
	queue_redraw()


## Живые игроки, которые сейчас играют (на паузе перед общим респавном — нет).
func _active_players() -> Array[Player]:
	var result: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.is_physics_processing():
			result.append(player)
	return result


func has_area() -> bool:
	return area_tiles.size != Vector2.ZERO


## Комната призрака в мире (px).
func get_area_px() -> Rect2:
	return Rect2(area_tiles.position * GreyboxLevel.TILE, area_tiles.size * GreyboxLevel.TILE)


## После общего респавна призрак всегда дома: если бы он запоминал, где был при взятии чекпоинта,
## то, взятый в погоне, появлялся бы рядом с командой — и та гибла бы снова и снова.
func save_state() -> Variant:
	return _home


func load_state(state: Variant) -> void:
	position = state
	velocity = Vector2.ZERO
	_awake = false  # после общего респавна снова ждёт у входа


func _draw() -> void:
	if Engine.is_editor_hint() and has_area():
		# В редакторе видно комнату призрака.
		var area := get_area_px()
		draw_rect(Rect2(area.position - global_position, area.size), Color(0.6, 0.7, 1.0, 0.8), false, 3.0)
	var shy := watched and not Engine.is_editor_hint()
	var face := 1.0
	if _target != null:
		face = signf(_target.global_position.x - global_position.x) if absf(_target.global_position.x - global_position.x) > 2.0 else 1.0
	var bob := Vector2(0, sin(_bob * 3.0) * 3.0)
	if Art.enabled:
		# Спрайт смотрит вправо, середина головы — точка (56, 36); к цели — лицом.
		var sprite := Art.tex("ghost_shy" if shy else ("ghost_chase" if _target != null else "ghost_calm"))
		draw_set_transform(bob, 0.0, Vector2(face, 1.0))
		draw_texture_rect(sprite, Rect2(Vector2(-56, -36), Vector2(sprite.get_size()) / 4.0), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	var body_color := Color(0.97, 0.98, 1.0, 0.82 if shy else 0.95)
	# Тело: круглая голова и волнистый хвостик, контур снаружи.
	var outline_points := _body(bob, RADIUS + 3.0, face)
	draw_colored_polygon(outline_points, OUTLINE)
	draw_colored_polygon(_body(bob, RADIUS, face), body_color)
	draw_circle(bob + Vector2(-9 * face, -10), 6.0, Color(1, 1, 1, 0.9))  # блик
	if shy:
		# Стесняется: зажмурился, румянец, ладошки на щеках.
		for side: float in [-1.0, 1.0]:
			var eye := bob + Vector2(side * 9.0 + 4.0 * face, -3)
			draw_line(eye - Vector2(5, -1), eye + Vector2(5, 1), OUTLINE, 3.0)
			draw_circle(bob + Vector2(side * 15.0 + 4.0 * face, 7), 5.0, Color(1.0, 0.55, 0.6, 0.8))
			var hand := bob + Vector2(side * 20.0 + 4.0 * face, 4)
			draw_circle(hand, 8.5, OUTLINE)
			draw_circle(hand, 6.0, body_color)
		return
	# Охотится: глаза на цель, рот с язычком.
	for side: float in [-1.0, 1.0]:
		var eye := bob + Vector2(side * 9.0 + 5.0 * face, -5)
		draw_set_transform(eye * SCALE, 0.0, Vector2(1.0, 1.5) * SCALE)
		draw_circle(Vector2.ZERO, 4.0, OUTLINE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	var mouth := bob + Vector2(5.0 * face, 10)
	draw_circle(mouth, 7.0, OUTLINE)
	draw_circle(mouth + Vector2(0, 3), 3.5, Color("e5484d"))


## Контур тела радиуса r: верх — полукруг, низ — три волны хвостика (хвост позади по ходу).
func _body(offset: Vector2, r: float, face: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 17:
		var angle := PI + i * PI / 16.0
		points.append(offset + Vector2.from_angle(angle) * r)
	var bottom := r * 0.9
	for i in 13:
		var t := float(i) / 12.0
		var x := r - t * 2.0 * r
		var wave := sin(t * TAU * 1.5 + _bob * 6.0) * 4.0
		var trail := -face * t * 6.0  # хвостик отстаёт от направления полёта
		points.append(offset + Vector2(x + trail, bottom + wave))
	return points
