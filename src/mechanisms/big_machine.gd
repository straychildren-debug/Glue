@tool
class_name BigMachine
extends Node2D
## «Большая машина» — босс мира 2 в три фазы. Сама не бьёт: бьют её механизмы (прессы, жуки, обвал);
## машина — лицо на стене с пастью-воротами, следит глазами за героями и показывает, как ей досталось.
## Фаза 1 — волнами: слабые точки (weak_spots — кнопки) разбиты на волны по wave_sizes; в каждой волне
## все её точки нажать в одно окно. Точки текущей волны машина подсвечивает. После каждой волны прессы
## rush_presses бьют чаще (rush). Последняя волна — броня треснула, пасть (ворота с триггером на машину)
## открывается: active = фаза ≥ 2.
## Фаза 2 → 3: ядро (core — плита) нажато — машина разваливается: дымит, трясётся, сыплется (обвал
## запускается отдельно, как обычно).
## Положение узла — середина верха пасти.

const OUTLINE := Color("1a1d33")

@export var weak_spots: Array[NodePath] = []
## Сколько точек в каждой волне (по порядку weak_spots); пусто — одна волна из всех.
@export var wave_sizes: Array[int] = []
@export var rush_presses: Array[NodePath] = []
## Во сколько раз короче паузы прессов с каждой волной.
@export var rush := 0.7
## Кулаки машины: работают в своей фазе (Fist.phase), с каждой волной злее на fist_rage.
@export var fists: Array[NodePath] = []
@export var fist_rage := 0.2
@export var core: NodePath
## Размер морды, тайлы (ширина, высота над пастью).
@export var face_tiles := Vector2(7, 6):
	set(value):
		face_tiles = value
		queue_redraw()

var phase := 1
var wave := 0
var active := false
var _press_base := {}  # пресс -> [top_wait, bottom_wait, rise_speed]
var _time := 0.0
var _hit := 0.0  # вспышка после удара, с


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 24  # после плит, до дверей
	for path in rush_presses:
		var press := get_node_or_null(path)
		if press != null:
			_press_base[press] = [press.top_wait, press.bottom_wait, press.rise_speed]


## Точки текущей волны.
func wave_spots() -> Array:
	var sizes := wave_sizes if not wave_sizes.is_empty() else [weak_spots.size()]
	var start := 0
	for i in wave:
		start += sizes[i]
	var result := []
	if wave < sizes.size():
		for i in range(start, mini(start + sizes[wave], weak_spots.size())):
			var n := get_node_or_null(weak_spots[i])
			if n != null:
				result.append(n)
	return result


func _waves() -> int:
	return wave_sizes.size() if not wave_sizes.is_empty() else 1


func _apply_rush() -> void:
	var k := pow(rush, wave)
	for press: Node in _press_base:
		var base: Array = _press_base[press]
		press.top_wait = base[0] * k
		press.bottom_wait = base[1] * k
		press.rise_speed = base[2] / k


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_hit = maxf(_hit - delta, 0.0)
	if phase == 1 and not weak_spots.is_empty():
		var spots := wave_spots()
		if not spots.is_empty() and spots.all(func(n: Node) -> bool: return n.active):
			wave += 1
			_hit = 0.7
			_apply_rush()
			if wave >= _waves():
				phase = 2
				_hit = 1.0
	elif phase == 2 and not core.is_empty():
		var c := get_node_or_null(core)
		if c != null and c.active:
			phase = 3
			_hit = 1.5
	active = phase >= 2
	_drive_fists()
	queue_redraw()


func _drive_fists() -> void:
	for path in fists:
		var fist := get_node_or_null(path)
		if fist == null:
			continue
		fist.enabled = fist.phase == 0 or fist.phase == phase
		fist.rage = 1.0 + fist_rage * wave if fist.phase == 1 else 1.0  # злее с волнами — только кулаки арены


func save_state() -> Variant:
	return [phase, wave]


func load_state(state: Variant) -> void:
	phase = state[0]
	wave = state[1]
	_apply_rush()
	active = phase >= 2
	_hit = 0.0
	queue_redraw()


## Ближайший живой герой (куда смотреть).
func _target() -> Vector2:
	var best := Vector2(global_position.x - 400.0, global_position.y + 200.0)
	var dist := INF
	if Engine.is_editor_hint() or not is_inside_tree():
		return best
	for p: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if p.alive and p.global_position.distance_to(global_position) < dist:
			dist = p.global_position.distance_to(global_position)
			best = p.global_position
	return best


func _draw() -> void:
	var t := GreyboxLevel.TILE
	var w := face_tiles.x * t
	var h := face_tiles.y * t
	var shake := Vector2(sin(_time * 50.0), cos(_time * 43.0)) * (6.0 if phase == 3 else 3.0 * _hit)
	draw_set_transform(shake)
	var top := Vector2(-w / 2.0, -h)
	var art := "w2_face" if phase == 1 else ("w2_face_cracked" if phase == 2 else "w2_face_broken")
	if Art.enabled and Art.has(art):
		_draw_face_art(Art.tex(art), shake)
		return
	# Морда: клёпаная железная плита, по краям — трубы.
	draw_rect(Rect2(top - Vector2(6, 6), Vector2(w + 12, h + 6)), OUTLINE)
	draw_rect(Rect2(top, Vector2(w, h)), Color("4a4f5c") if phase < 3 else Color("3d3f48"))
	for i in int(face_tiles.x) + 1:
		for j in int(face_tiles.y):
			draw_circle(top + Vector2(i * t, j * t + 8.0), 4.0, Color("2c303a"))
	for s: float in [-1.0, 1.0]:
		var x := s * (w / 2.0 + 14.0)
		draw_rect(Rect2(Vector2(x - 10.0, -h - 30.0), Vector2(20, h + 30.0)), OUTLINE)
		draw_rect(Rect2(Vector2(x - 6.0, -h - 26.0), Vector2(12, h + 26.0)), Color("8a6a44"))
	# Глаза: следят за героем; фаза 1 — злые красные, 2 — треснувшие, 3 — мигают.
	var look := (_target() - global_position).normalized() * 12.0
	var eye_color := Color("ff4a3a") if phase == 1 else (Color("ffa040") if phase == 2 else Color("ffd060"))
	if phase == 3 and fmod(_time, 0.4) < 0.15:
		eye_color = Color("40343a")
	for s: float in [-1.0, 1.0]:
		var c := Vector2(s * w * 0.22, -h * 0.62)
		draw_circle(c, 30.0, OUTLINE)
		draw_circle(c, 24.0, Color("1f2129"))
		draw_circle(c + look, 12.0, eye_color)
		draw_circle(c + look + Vector2(-3, -3), 4.0, Color(1, 1, 1, 0.8))
		# Брови-пластины: злые внутрь.
		var brow := PackedVector2Array([c + Vector2(-s * 34.0, -48.0), c + Vector2(s * 34.0, -30.0),
				c + Vector2(s * 34.0, -20.0), c + Vector2(-s * 34.0, -38.0)])
		draw_colored_polygon(brow, OUTLINE)
	# Трещины после ударов.
	if phase >= 2:
		draw_polyline(PackedVector2Array([top + Vector2(w * 0.1, 10), top + Vector2(w * 0.25, h * 0.3),
				top + Vector2(w * 0.18, h * 0.55), top + Vector2(w * 0.32, h * 0.8)]), Color("1a1a20"), 5.0)
	if phase >= 3:
		draw_polyline(PackedVector2Array([top + Vector2(w * 0.9, 6), top + Vector2(w * 0.7, h * 0.35),
				top + Vector2(w * 0.82, h * 0.6), top + Vector2(w * 0.6, h)]), Color("1a1a20"), 6.0)
		for i in 5:
			var p := top + Vector2(fposmod(i * 97.0 + _time * 60.0, w), -fposmod(_time * 80.0 + i * 41.0, 120.0))
			draw_circle(p, 10.0 + i * 2.0, Color(0.3, 0.3, 0.32, 0.5))
	# Слабые точки текущей волны — мигающие кольца-прицелы.
	if phase == 1 and not Engine.is_editor_hint():
		draw_set_transform(Vector2.ZERO)
		for spot: Node2D in wave_spots():
			var c := to_local(spot.global_position) + Vector2(0, -18)
			var pulse := 0.5 + 0.5 * sin(_time * 8.0)
			draw_arc(c, 34.0 + pulse * 6.0, 0, TAU, 32, Color(1, 0.3, 0.2, 0.5 + 0.4 * pulse), 4.0)
			for ang in [0.0, PI / 2, PI, PI * 1.5]:
				var d := Vector2.from_angle(ang)
				draw_line(c + d * 26.0, c + d * 46.0, Color(1, 0.3, 0.2, 0.8), 3.0)
		draw_set_transform(shake)
	# Вспышка удара.
	if _hit > 0.0:
		draw_rect(Rect2(top, Vector2(w, h)), Color(1, 0.9, 0.6, 0.35 * _hit))
	draw_set_transform(Vector2.ZERO)


## Морда спрайтом N7 (на тайл шире плиты — трубы по бокам; низ — по низу плиты): глазницы пустые,
## глаза рисуются поверх — следят за героем. Прицелы на слабых точках и вспышка удара — как без спрайта.
func _draw_face_art(sprite: Texture2D, shake: Vector2) -> void:
	var t := GreyboxLevel.TILE
	var w := (face_tiles.x + 1.0) * t
	var h := sprite.get_height() * w / sprite.get_width()
	var rect := Rect2(Vector2(-w / 2.0, -h), Vector2(w, h))
	draw_texture_rect(sprite, rect, false)
	if phase == 3:
		for i in 5:
			var p := rect.position + Vector2(fposmod(i * 97.0 + _time * 60.0, w), -fposmod(_time * 80.0 + i * 41.0, 120.0))
			draw_circle(p, 10.0 + i * 2.0, Color(0.3, 0.3, 0.32, 0.5))
	var look := (_target() - global_position).normalized() * 10.0
	var eye_color := Color("ff4a3a") if phase == 1 else (Color("ffa040") if phase == 2 else Color("ffd060"))
	if phase == 3 and fmod(_time, 0.4) < 0.15:
		eye_color = Color("40343a")
	# глазницы на картинке: x 0,33 и 0,68 ширины, y 0,53 высоты
	for fx: float in [0.33, 0.68]:
		var c := rect.position + Vector2(fx * w, 0.53 * h)
		draw_circle(c + look, 12.0, eye_color)
		draw_circle(c + look + Vector2(-3, -3), 4.0, Color(1, 1, 1, 0.8))
	if phase == 1 and not Engine.is_editor_hint():
		draw_set_transform(Vector2.ZERO)
		for spot: Node2D in wave_spots():
			var c := to_local(spot.global_position) + Vector2(0, -18)
			var pulse := 0.5 + 0.5 * sin(_time * 8.0)
			draw_arc(c, 34.0 + pulse * 6.0, 0, TAU, 32, Color(1, 0.3, 0.2, 0.5 + 0.4 * pulse), 4.0)
			for ang in [0.0, PI / 2, PI, PI * 1.5]:
				var d := Vector2.from_angle(ang)
				draw_line(c + d * 26.0, c + d * 46.0, Color(1, 0.3, 0.2, 0.8), 3.0)
		draw_set_transform(shake)
	if _hit > 0.0:
		draw_rect(rect, Color(1, 0.9, 0.6, 0.35 * _hit))
	draw_set_transform(Vector2.ZERO)
