@tool
class_name CrackedWall
extends StaticBody2D
## Треснувшая стена (к M2.8): твёрдая, пока её не взорвёт бочонок (Keg.walls) или не проломит
## голем. Рухнувшая возвращается к состоянию чекпоинта.
## Положение узла — левый верхний угол.

const OUTLINE := Color("1a1d33")

@export var size_tiles := Vector2(1, 3):
	set(value):
		size_tiles = value
		queue_redraw()

var smashed := false
var _fall := 10.0
var _shape: CollisionShape2D


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE
	_shape = CollisionShape2D.new()
	_shape.shape = shape
	_shape.position = shape.size / 2.0
	add_child(_shape)
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0


func smash() -> void:
	if smashed:
		return
	smashed = true
	_fall = 0.0
	_shape.set_deferred("disabled", true)


func _process(delta: float) -> void:
	if _fall < 1.5:
		_fall += delta
		queue_redraw()


func save_state() -> Variant:
	return smashed


func load_state(state: Variant) -> void:
	smashed = state
	_fall = 10.0
	_shape.set_deferred("disabled", smashed)
	queue_redraw()


func _draw() -> void:
	var size := size_tiles * GreyboxLevel.TILE
	var art := Art.enabled and Art.has("w2_slab_mid")
	if art and not smashed:
		# P28: стоячая — колонна целиком, лежачая — пролёт (торцы и повторяемая середина)
		if size_tiles.y >= size_tiles.x:
			draw_texture_rect(Art.tex("w2_wall"), Rect2(Vector2.ZERO, size), false)
		else:
			Art.draw_strip_h(self, Rect2(Vector2.ZERO, size), "w2_slab_mid", "w2_slab_end")
		return
	if smashed and art:
		# Обломки летят вниз и разлетаются, потом лежат грудой у подножия.
		var count := int(maxf(size_tiles.x, size_tiles.y) * 3.0)
		for i in count:
			var chunk := Art.tex("w2_chunk_%d" % (i % 6 + 1))
			var csize := Vector2(chunk.get_size()) * 0.26
			var spread := (float(i) + 0.5) / count
			var at: Vector2
			if _fall > 1.2:
				if size_tiles.y < size_tiles.x:
					return  # пролёт над пропастью: обломки упали вниз
				at = Vector2(spread * size.x, size.y + 12.0 * (i % 2)) - Vector2(csize.x / 2.0, csize.y)
			else:
				var from := Vector2(spread * size.x, (i % 3 + 0.5) * size.y / 3.0) if size_tiles.y >= size_tiles.x 						else Vector2(spread * size.x, size.y / 2.0)
				at = from + Vector2((spread - 0.5) * 80.0 * _fall, 900.0 * _fall * _fall * (0.6 + 0.1 * (i % 4))) - csize / 2.0
			draw_texture_rect(chunk, Rect2(at, csize), false)
		return
	if smashed:
		if _fall > 1.2:
			# Груда обломков у подножия.
			for i in int(size_tiles.x * 3.0):
				var x := (i + 0.5) * size.x / (size_tiles.x * 3.0)
				draw_circle(Vector2(x, size.y - 8.0), 11.0, OUTLINE)
				draw_circle(Vector2(x, size.y - 8.0), 8.0, Color("8a8f98"))
			return
		var rows := int(size_tiles.y * 2.0)
		for i in rows:
			var y := (i + 0.5) * size.y / rows + 900.0 * _fall * _fall * (0.6 + 0.1 * i)
			var x := size.x / 2.0 + (i % 2 * 2 - 1) * 60.0 * _fall
			draw_rect(Rect2(x - 14, y - 12, 28, 24), OUTLINE)
			draw_rect(Rect2(x - 11, y - 9, 22, 18), Color("9aa0a8"))
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, OUTLINE)
	draw_rect(rect.grow(-4.0), Color("9aa0a8"))
	# Кладка и крупная трещина наискосок: стену можно сломать.
	var rows := int(size_tiles.y * 2.0)
	for i in range(1, rows):
		var y := i * size.y / rows
		draw_line(Vector2(4, y), Vector2(size.x - 4, y), Color("737a84"), 3.0)
	var crack := PackedVector2Array()
	for i in rows + 1:
		crack.append(Vector2(size.x * (0.3 + 0.4 * (i % 2)), i * size.y / rows))
	draw_polyline(crack, OUTLINE, 4.0)
