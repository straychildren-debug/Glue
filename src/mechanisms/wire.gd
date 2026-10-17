@tool
class_name Wire
extends Node2D
## Медный провод (M2.7): ломаная, по которой бегает искра (Spark). На конце провода — либо
## развилка на следующие провода (next; со стрелкой switch — рычагом выбирается next[1], пока
## рычаг включён, иначе next[0]), либо цель (target: бочонок с фитилём — искра его поджигает),
## либо тупик — искра поворачивает назад.
## Точки — в тайлах относительно узла.

const OUTLINE := Color("1a1d33")
const COPPER := Color("c8783c")

@export var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(4, 0)]):
	set(value):
		points = value
		queue_redraw()
@export var next: Array[NodePath] = []
@export var switch: NodePath
## Ещё стрелки (плиты, рычаги): ветка next[1], пока активна любая.
@export var switches: Array[NodePath] = []
@export var target: NodePath
## Заземление на конце: дошедшая искра уходит в землю и снова выбегает из начала своего провода
## (а не бежит назад, как в тупике).
@export var grounded := false:
	set(value):
		grounded = value
		queue_redraw()


## Точка провода в мире (px).
func point_global(i: int) -> Vector2:
	return to_global(points[i] * GreyboxLevel.TILE)


## Длина провода, px.
func length() -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += (points[i + 1] - points[i]).length() * GreyboxLevel.TILE
	return total


## Точка в мире на расстоянии s от начала провода.
func at(s: float) -> Vector2:
	var left := s
	for i in points.size() - 1:
		var a := point_global(i)
		var b := point_global(i + 1)
		var seg := a.distance_to(b)
		if left <= seg or i == points.size() - 2:
			return a.lerp(b, clampf(left / seg, 0.0, 1.0) if seg > 0.0 else 0.0)
		left -= seg
	return point_global(points.size() - 1)


## Куда бежит искра с конца провода: следующий провод или null.
func next_wire() -> Wire:
	if next.is_empty():
		return null
	var index := 0
	if next.size() > 1:
		for path in [switch] + switches:
			var lever: Node = get_node_or_null(path) if not path.is_empty() else null
			if lever != null and lever.active:
				index = 1
	return get_node_or_null(next[index]) as Wire


## Графика проводов (P26): px игры на px исходника; оси провода в кусках (px исходника).
const ART_SCALE := 0.3
const MID_AXIS := 46.0      # w2_wire_mid: ось провода от верха куска
const BOX_CENTER := Vector2(144.0, 182.0)  # w2_wire_box_*: середина коробки
const END_AXIS := 48.0      # w2_wire_end: ось провода на левом крае
const GROUND_AXIS := 46.0   # w2_wire_ground: ось провода на левом крае


func _draw() -> void:
	var line := PackedVector2Array()
	for p in points:
		line.append(p * GreyboxLevel.TILE)
	if Art.enabled and Art.has("w2_wire_mid"):
		_draw_sprites(line)
		return
	draw_polyline(line, OUTLINE, 9.0)
	draw_polyline(line, COPPER, 4.0)
	# Скобы крепления на изломах.
	for p in line:
		draw_circle(p, 6.0, OUTLINE)
		draw_circle(p, 3.5, Color("d4a640"))
	if grounded and line.size() > 0:
		# Знак заземления на конце: три черты, короче и короче.
		var end := line[line.size() - 1]
		for i in 3:
			var w := 16.0 - i * 5.0
			draw_line(end + Vector2(-w, 6 + i * 6), end + Vector2(w, 6 + i * 6), OUTLINE, 4.0)
	# Ромб над развилкой — цвет её стрелки (плиты или рычага), как метки дверей.
	if next.size() > 1 and line.size() > 0 and is_inside_tree():
		for path in [switch] + switches:
			var sw: Node = get_node_or_null(path) if not path.is_empty() else null
			if sw != null and "mark_color" in sw and sw.mark_color.a > 0.0:
				Lever.draw_mark(self, line[line.size() - 1] + Vector2(0, -30), sw.mark_color)
				break
	# Стрелка на развилке показывает, куда сейчас пойдёт искра.
	if next.size() > 1 and not Engine.is_editor_hint() and is_inside_tree():
		var target_wire := next_wire()
		if target_wire != null and target_wire.points.size() > 1:
			var end := line[line.size() - 1]
			var toward := to_local(target_wire.point_global(1)) - end
			draw_line(end, end + toward.normalized() * 22.0, Color("f2c230"), 5.0)


## Провод картинками: участки — повтором куска с изолятором (целое число периодов по длине),
## на изломах — латунные скобы, на развилке — коробка со стрелкой туда, куда пойдёт искра,
## на конце — кол заземления или клемма (к бочонку или стене).
func _draw_sprites(line: PackedVector2Array) -> void:
	var mid := Art.tex("w2_wire_mid")
	var period := mid.get_width() * ART_SCALE
	var thick := mid.get_height() * ART_SCALE
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var n := maxi(1, roundi(length / period))
		var step := length / n
		draw_set_transform(a, (b - a).angle())
		for k in n:
			draw_texture_rect(mid, Rect2(Vector2(k * step, -MID_AXIS * ART_SCALE), Vector2(step, thick)), false)
		draw_set_transform(Vector2.ZERO)
	for k in range(1, line.size() - 1):
		draw_circle(line[k], 7.0, OUTLINE)
		draw_circle(line[k], 4.5, Color("d4a640"))
	if line.size() < 2:
		return
	var end := line[line.size() - 1]
	var into := (end - line[line.size() - 2]).normalized()
	if next.size() > 1 and is_inside_tree():
		var toward := Vector2.RIGHT
		var target_wire := next_wire() if not Engine.is_editor_hint() else null
		if target_wire != null and target_wire.points.size() > 1:
			toward = to_local(target_wire.point_global(1)) - end
		var box := Art.tex("w2_wire_box_left" if toward.x < -0.1 else "w2_wire_box_right")
		var angle := 0.0
		if absf(toward.y) > absf(toward.x):
			angle = PI / 2.0 if toward.y > 0.0 else -PI / 2.0
		draw_set_transform(end, angle)
		draw_texture_rect(box, Rect2(-BOX_CENTER * ART_SCALE, Vector2(box.get_size()) * ART_SCALE), false)
		draw_set_transform(Vector2.ZERO)
	elif grounded:
		var ground := Art.tex("w2_wire_ground")
		var flip := into.x < -0.1
		draw_set_transform(end, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect(ground, Rect2(Vector2(-8.0, -GROUND_AXIS * ART_SCALE), Vector2(ground.get_size()) * ART_SCALE), false)
		draw_set_transform(Vector2.ZERO)
	elif not target.is_empty():
		var term := Art.tex("w2_wire_end")
		draw_set_transform(end - into * term.get_width() * ART_SCALE, into.angle())
		draw_texture_rect(term, Rect2(Vector2(0.0, -END_AXIS * ART_SCALE), Vector2(term.get_size()) * ART_SCALE), false)
		draw_set_transform(Vector2.ZERO)
	# Ромб над развилкой — цвет её стрелки (плиты или рычага).
	if next.size() > 1 and is_inside_tree():
		for path in [switch] + switches:
			var sw: Node = get_node_or_null(path) if not path.is_empty() else null
			if sw != null and "mark_color" in sw and sw.mark_color.a > 0.0:
				Lever.draw_mark(self, end + Vector2(0, -42), sw.mark_color)
				break


func _process(_delta: float) -> void:
	if next.size() > 1 and not Engine.is_editor_hint():
		queue_redraw()
