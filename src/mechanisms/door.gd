@tool
class_name Door
extends AnimatableBody2D
## Заслонка: пока активны её триггеры (плиты), уезжает на open_offset_tiles и возвращается обратно.
## Дверь уезжает в потолок или в пол, выдвижной мост — вбок из стены.
## Возвращаясь, не давит: дверь, опускаясь, выталкивает живого из проёма в ближнюю сторону и ждёт;
## ящик или замерший на полу её останавливают (подпорка).
## Положение узла — левый верхний угол в закрытом состоянии.

@export var size_tiles := Vector2(1, 3):
	set(value):
		size_tiles = value
		queue_redraw()
## Плиты и другие узлы со свойством `active`.
@export var triggers: Array[NodePath] = []
## true — нужны все триггеры сразу, false — любой.
@export var require_all := false
## Обратная заслонка: открыта, пока условие триггеров НЕ выполнено (встал на плиту — закрылась).
@export var invert := false
## Держат заслонку открытой при любом состоянии основных триггеров: защёлка за обратной дверью,
## которую нажимает прошедший первым, чтобы прошёл и второй.
@export var keep_open: Array[NodePath] = []
## Куда сдвигается открытая заслонка, в тайлах: (0, -3) — вверх на три тайла, (-5, 0) — мост влево.
@export var open_offset_tiles := Vector2(0, -3)
## Открывшись однажды (условие триггеров выполнено), остаётся открытой — до сброса к чекпоинту.
## Для дверей на кнопках: две кнопки в одно окно открывают дверь насовсем.
@export var stay_open := false
## Как быстро опускающаяся дверь выталкивает живого из проёма (px/с): быстрее бега — не устоять.
const NUDGE_SPEED := 540.0

@export var open_speed := 480.0
@export var close_speed := 360.0
## Цветная метка — тем же цветом помечены плиты, которые держат заслонку (прозрачный — без метки).
@export var mark_color := Color(0, 0, 0, 0):
	set(value):
		mark_color = value
		queue_redraw()

## Ещё цвета метки: дверь открывают плиты разных цветов — по полосе на каждый.
@export var mark_colors: Array[Color] = []:
	set(value):
		mark_colors = value
		queue_redraw()

var _closed_position := Vector2.ZERO
var _latched := false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = size_tiles * GreyboxLevel.TILE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = shape.size / 2.0
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	# Позади блоков уровня: закрытая заслонка прячется в скале, а не торчит поверх неё.
	z_index = -1
	collision_layer = Player.LAYER_WORLD
	# Маска нужна только для проверки «не раздавить» при закрытии.
	collision_mask = Player.LAYER_PLAYERS | Crate.LAYER_OBJECTS
	sync_to_physics = true
	process_physics_priority = 25  # после плит
	_closed_position = position


func is_open_requested() -> bool:
	if _latched:
		return true
	for path in keep_open:
		var holder := get_node_or_null(path)
		if holder != null and holder.active:
			return true
	if triggers.is_empty():
		return false
	var count := 0
	for path in triggers:
		var trigger := get_node_or_null(path)
		if trigger != null and trigger.active:
			count += 1
	var met := count == triggers.size() if require_all else count > 0
	if met and stay_open and not invert:
		_latched = true
	return met != invert


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := _closed_position
	var speed := close_speed
	if is_open_requested():
		target = _closed_position + open_offset_tiles * GreyboxLevel.TILE
		speed = open_speed
	var step := (target - position).limit_length(speed * delta)
	if step.is_zero_approx():
		return
	if not _clear_path(step, target == _closed_position):
		return  # на пути кто-то, кого не сдвинуть: заслонка ждёт
	position += step


## Освобождает путь заслонки на шаг step. Замершего (он неподвижен и сам с дороги не уйдёт)
## заслонка толкает перед собой, он остаётся замершим. Если толкать некуда (в стену) — false.
## Закрываясь, заслонка не давит живых: дверь (едет по вертикали) выталкивает живого из проёма
## в ближнюю сторону и ждёт, пока проём не освободится, — под опускающейся дверью нельзя
## «передать» проём товарищу. Выдвижной мост живой просто останавливает. Ящик останавливает
## любую заслонку. Открываясь, живых не ждёт — их выталкивает их собственная физика.
func _clear_path(step: Vector2, closing: bool) -> bool:
	var next := Rect2(global_position + step, size_tiles * GreyboxLevel.TILE)
	var shoves := []
	var blocked := false
	if closing:
		# Подпёрта ящиком — стоит и никого не выталкивает: к ящику в проёме можно подойти и толкать дальше.
		for crate: Crate in get_tree().get_nodes_in_group(Crate.GROUP):
			if crate.visible and next.intersects(crate.get_rect()) and not _rides_on_top(crate.get_rect(), step):
				return false
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if not player.alive:
			continue
		var body := Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)
		if not next.intersects(body) or _rides_on_top(body, step):
			continue
		if not player.frozen:
			if closing:
				blocked = true
				if absf(step.y) > absf(step.x):
					_nudge_out(player, next, body)
			continue
		var offset := _push_out(next, body, step)
		if player.test_move(player.global_transform, offset):
			return false
		shoves.append([player, offset])
	if blocked:
		return false
	for shove: Array in shoves:
		shove[0].shove(shove[1])
	return true


## Стоит сверху на площадке, которая опускается (подъёмник везёт его вниз), — не помеха.
func _rides_on_top(body: Rect2, step: Vector2) -> bool:
	return step.y > 0.0 and body.end.y <= global_position.y + 3.0


## Выталкивает живого из-под опускающейся двери в сторону, где он ближе к краю проёма.
func _nudge_out(player: Player, rect: Rect2, body: Rect2) -> void:
	var side := 1.0 if body.get_center().x >= rect.get_center().x else -1.0
	var need := rect.end.x - body.position.x + 0.5 if side > 0.0 else rect.position.x - body.end.x - 0.5
	var amount := minf(absf(need), NUDGE_SPEED * get_physics_process_delta_time())
	player.push(Vector2(side * amount, 0.0))


## Сдвиг, выводящий body из rect по направлению движения step (с зазором в полпикселя).
static func _push_out(rect: Rect2, body: Rect2, step: Vector2) -> Vector2:
	if absf(step.x) >= absf(step.y):
		return Vector2(rect.position.x - body.end.x - 0.5 if step.x < 0.0 else rect.end.x - body.position.x + 0.5, 0.0)
	return Vector2(0.0, rect.position.y - body.end.y - 0.5 if step.y < 0.0 else rect.end.y - body.position.y + 0.5)


func save_state() -> Variant:
	return [position, _latched]


func load_state(state: Variant) -> void:
	position = state[0]
	_latched = state[1]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size_tiles * GreyboxLevel.TILE)
	if Art.enabled:
		if size_tiles.x > size_tiles.y:
			Art.draw_wood(self, rect)  # мост, ступенька, опускаемая площадка
		else:
			Art.draw_strip_v(self, rect, "door_mid", "door_end")
		_draw_mark(rect)
		return
	draw_rect(rect, Color("8b5e34"))
	# Доски: поперёк длинной стороны.
	var along_x := size_tiles.x > size_tiles.y
	var count := int((size_tiles.x if along_x else size_tiles.y) * 2)
	for i in range(1, count):
		var d := i * GreyboxLevel.TILE / 2.0
		if along_x:
			draw_line(Vector2(d, 3), Vector2(d, rect.size.y - 3), Color("6b4526"), 3.0)
		else:
			draw_line(Vector2(4, d), Vector2(rect.size.x - 4, d), Color("6b4526"), 3.0)
	draw_rect(rect, Color("4a2f18"), false, 4.0)
	_draw_mark(rect)


## Цветная полоса с контуром: по нижнему краю моста или по середине двери.
func _draw_mark(rect: Rect2) -> void:
	var colors: Array[Color] = []
	for color in [mark_color] + mark_colors:
		if color.a > 0.0:
			colors.append(color)
	if colors.is_empty():
		return
	# Полосы рядом: по одной на цвет, 8 px через 4 px, по середине двери (у моста — у нижнего края).
	var along_x := size_tiles.x > size_tiles.y
	var thick := 8.0 if colors.size() > 1 else 10.0
	var total := colors.size() * thick + (colors.size() - 1) * 4.0
	for i in colors.size():
		var band: Rect2
		if along_x:
			band = Rect2(rect.position.x + 6.0, rect.end.y - 4.0 - total + i * (thick + 4.0), rect.size.x - 12.0, thick)
		else:
			band = Rect2(rect.get_center().x - total / 2.0 + i * (thick + 4.0), rect.position.y + 8.0, thick, rect.size.y - 16.0)
		_draw_band(band, colors[i], along_x)
	if require_all and colors.size() > 1:
		# «Нужны все сразу» — полосы сшиты перемычками, как лесенка.
		var rung := 22.0
		if along_x:
			var top := rect.end.y - 4.0 - total
			var x := rect.position.x + 14.0
			while x < rect.end.x - 14.0:
				draw_rect(Rect2(x, top, 4.0, total), Color("1a1d33"))
				x += rung
		else:
			var left := rect.get_center().x - total / 2.0
			var y := rect.position.y + 16.0
			while y < rect.end.y - 16.0:
				draw_rect(Rect2(left, y, total, 4.0), Color("1a1d33"))
				y += rung


## Одна полоса метки. Обратная заслонка — пунктир: «плита нажата — закрыто»; сплошная — «нажата — открыто».
func _draw_band(band: Rect2, color: Color, along_x: bool) -> void:
	draw_rect(band.grow(2.0), Color("1a1d33"))
	if not invert:
		draw_rect(band, color)
		return
	var length := band.size.x if along_x else band.size.y
	var dash := 14.0
	var t := 0.0
	while t < length:
		var piece := minf(dash, length - t)
		if along_x:
			draw_rect(Rect2(band.position.x + t, band.position.y, piece, band.size.y), color)
		else:
			draw_rect(Rect2(band.position.x, band.position.y + t, band.size.x, piece), color)
		t += dash * 2.0
