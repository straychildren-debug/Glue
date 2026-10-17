@tool
class_name Wheel
extends Node2D
## Беличье колесо: подошёл и нажал хват — встал в колесо; бежишь — стоишь на месте, колесо
## раскручивается (за spin_up_time до полной скорости). Пока оно крутится быстрее порога, оно активно —
## триггер для дверей, мостов, подъёмников (свойство active). Выпрыгнул — колесо крутится по инерции
## и за coast_time с полной скорости останавливается: маховик держит дверь, пока бежишь к ней.
## Выйти — только прыжком: стоящего в колесе оно держит на месте, в воздухе он летит со своей
## скоростью бега. В колесе один; проходящий мимо (без хвата) в колесо не попадает.
## Положение узла — середина дна колеса на уровне пола.

const OUTLINE := Color("1a1d33")
## Порог активности (доля полной скорости).
const THRESHOLD := 0.25
const GROUP := "wheels"

@export var radius_tiles := 1.5:
	set(value):
		radius_tiles = value
		queue_redraw()
@export var spin_up_time := 1.2
@export var coast_time := 2.5
## Цветная метка — тем же цветом помечено то, чем колесо управляет.
@export var mark_color := Color(0, 0, 0, 0):
	set(value):
		mark_color = value
		queue_redraw()

var spin := 0.0  # 0 — стоит, 1 — полная скорость
var active := false
var runner: Player = null
var _angle := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	add_to_group(GROUP)
	process_physics_priority = 12  # после движения игроков: держит бегущего на месте


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if runner != null and (not runner.alive or runner.frozen or not runner.is_on_floor()):
		runner = null  # выпрыгнул, замер или погиб — вышел из колеса
	if runner != null:
		runner.global_position.x = global_position.x  # колесо держит стоящего в нём на месте
	var running := runner != null and absf(runner.velocity.x) > 60.0
	if running:
		spin = minf(spin + delta / spin_up_time, 1.0)
	else:
		spin = maxf(spin - delta / coast_time, 0.0)
	_angle += spin * delta * 6.0
	active = spin > THRESHOLD
	queue_redraw()


## Хват у свободного колеса: игрок встаёт в него; true — нажатие ушло колесу.
static func try_enter(player: Player) -> bool:
	if not player.is_on_floor():
		return false
	for wheel: Wheel in player.get_tree().get_nodes_in_group(GROUP):
		if wheel.runner == null and wheel._near(player):
			wheel.runner = player
			return true
	return false


func _near(p: Player) -> bool:
	var feet := p.global_position.y + Player.SIZE.y / 2.0
	var r := radius_tiles * GreyboxLevel.TILE
	return absf(feet - global_position.y) < 8.0 and absf(p.global_position.x - global_position.x) < r * 0.8


## Доля полной скорости (для плавных механизмов).
func power() -> float:
	return spin


func save_state() -> Variant:
	return spin


func load_state(state: Variant) -> void:
	spin = state
	runner = null
	active = spin > THRESHOLD


func _draw() -> void:
	var r := radius_tiles * GreyboxLevel.TILE
	var c := Vector2(0, -r)
	if Art.enabled and Art.has("w2_wheel"):
		# N2: колесо вращается вокруг оси, опора спереди (её ось — на 0,12 высоты от верха).
		draw_set_transform(c, _angle)
		draw_texture_rect(Art.tex("w2_wheel"), Rect2(-r, -r, r * 2.0, r * 2.0), false)
		draw_set_transform(Vector2.ZERO)
		var stand := Art.tex("w2_wheel_stand")
		var sh := r / 0.88
		var sw := sh * stand.get_width() / stand.get_height()
		draw_texture_rect(stand, Rect2(-sw / 2.0, -sh, sw, sh), false)
		_draw_gauge(r, c)
		return
	# Стойки, обод, спицы (вращаются), перекладины по ободу — видно, что колесо крутится.
	for s in [-1.0, 1.0]:
		draw_line(c, Vector2(s * r * 0.7, 0), OUTLINE, 8.0)
		draw_line(c, Vector2(s * r * 0.7, 0), Color("8a6a44"), 4.0)
	draw_arc(c, r - 4.0, 0, TAU, 48, OUTLINE, 10.0)
	draw_arc(c, r - 4.0, 0, TAU, 48, Color("e8b860") if active else Color("c89a5a"), 5.0)
	for i in 8:
		var a := _angle + i * TAU / 8.0
		draw_line(c, c + Vector2.from_angle(a) * (r - 8.0), Color(0.1, 0.11, 0.2, 0.55), 3.0)
	for i in 16:
		var a := _angle + i * TAU / 16.0
		draw_circle(c + Vector2.from_angle(a) * (r - 4.0), 3.0, OUTLINE)
	draw_circle(c, 7.0, OUTLINE)
	draw_circle(c, 4.0, Color("e0b040"))
	_draw_gauge(r, c)


## Метка и шкала скорости под колесом.
func _draw_gauge(r: float, c: Vector2) -> void:
	if mark_color.a > 0.0:
		Lever.draw_mark(self, c + Vector2(0, -r - 18.0), mark_color)
	# Шкала скорости под колесом.
	draw_rect(Rect2(-r * 0.6, 6.0, r * 1.2, 6.0), OUTLINE)
	draw_rect(Rect2(-r * 0.6 + 1.0, 7.0, (r * 1.2 - 2.0) * spin, 4.0), Color("e8b860") if active else Color("9aa3ad"))
