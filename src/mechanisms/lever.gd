@tool
class_name Lever
extends Node2D
## Рычаг: подойти и нажать хват — переключается (вкл/выкл). Триггер для заслонок, фиксаторов
## и тормоза подъёмника (свойство active). В отличие от защёлки, его можно выключить обратно.
## Нажатие хвата у рычага уходит рычагу: товарища рядом оно не хватает (Player._update_grab).
## Положение узла — середина основания рычага на уровне пола или стены, где он стоит.

const GROUP := "levers"
const OUTLINE := Color("1a1d33")
## Игрок переключает рычаг, когда его центр ближе этого (px) к ручке.
const REACH := 80.0

@export var active := false:
	set(value):
		active = value
		queue_redraw()
## Цветная метка (ромб над рычагом): тем же цветом помечено то, чем он управляет (развилка провода).
@export var mark_color := Color(0, 0, 0, 0):
	set(value):
		mark_color = value
		queue_redraw()

var _swing := 0.0  # для анимации ручки: -1 выкл, 1 вкл


## Переключает рычаг рядом с игроком; true — нажатие ушло рычагу.
static func try_toggle(player: Player) -> bool:
	for lever: Lever in player.get_tree().get_nodes_in_group(GROUP):
		if player.global_position.distance_to(lever.global_position + Vector2(0, -24)) <= REACH:
			lever.active = not lever.active
			return true
	return false


## Цветной ромб с тёмным контуром (как у плит) — метка «чем управляет».
static func draw_mark(item: CanvasItem, c: Vector2, color: Color) -> void:
	item.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(14, 0), c + Vector2(0, 14), c + Vector2(-14, 0)]), OUTLINE)
	item.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0)]), color)


func _ready() -> void:
	_swing = 1.0 if active else -1.0
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
		add_to_group(GreyboxLevel.RESETTABLE)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := 1.0 if active else -1.0
	if _swing != target:
		_swing = move_toward(_swing, target, delta * 8.0)
		queue_redraw()


func save_state() -> Variant:
	return active


func load_state(state: Variant) -> void:
	active = state
	_swing = 1.0 if active else -1.0


func _draw() -> void:
	if mark_color.a > 0.0:
		draw_mark(self, Vector2(0, -80), mark_color)
	if Art.enabled:
		# Спрайт 80×32: середина низа каменного основания — точка (40, 31).
		draw_texture_rect(Art.tex("lever_on" if active else "lever_off"), Rect2(-40, -31, 80, 32), false)
		return
	# Основание — каменная колодка; ручка с набалдашником наклонена влево (выкл) или вправо (вкл);
	# набалдашник: зелёный — вкл, красный — выкл.
	var angle := deg_to_rad(35.0) * _swing
	var pivot := Vector2(0, -10)
	var handle := pivot + Vector2(0, -34).rotated(angle)
	draw_rect(Rect2(-17, -14, 34, 16), OUTLINE)
	draw_rect(Rect2(-14, -11, 28, 11), Color("8a7d6b"))
	draw_line(pivot, handle, OUTLINE, 9.0)
	draw_line(pivot, handle, Color("8a5a30"), 5.0)
	draw_circle(handle, 8.0, OUTLINE)
	draw_circle(handle, 5.5, Color("e5484d") if not active else Color("7fdc5a"))
	draw_circle(pivot, 5.0, OUTLINE)
	draw_circle(pivot, 3.0, Color("9aa3ad"))
