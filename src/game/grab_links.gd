class_name GrabLinks
extends Node
## Решает связи хвата после того, как все игроки сделали свой шаг движения.
## Связь — «верёвка» длиной grab_length: растянуться дальше нельзя, сблизиться можно.
## Поправка делится по подвижности: замерший — неподвижный якорь, стоящий на земле
## поддаётся слабо, игрок в воздухе — полностью. Так получаются висение, маятник и цепи.
## Держаться можно и за крюк (Hook): для связи это вечный замерший якорь.

@export var iterations := 4
## Насколько легко сдвинуть стоящего на земле (0 — как замерший, 1 — как в воздухе).
@export var grounded_mobility := 0.15
## Во сколько раз можно увеличить касательную скорость при сохранении модуля.
## Ограничивает прирост у крайних точек размаха, где почти вся скорость радиальная.
@export var swing_keep_limit := 1.25


func _ready() -> void:
	# После _physics_process всех игроков.
	process_physics_priority = 10


func _physics_process(_delta: float) -> void:
	var links: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and player.grab_target != null and player.grab_target.alive:
			links.append(player)
	if links.is_empty():
		return

	for i in iterations:
		for holder in links:
			_solve_position(holder, holder.grab_target)
	for holder in links:
		_solve_velocity(holder, holder.grab_target)


func _solve_position(a: Player, b: Node2D) -> void:
	var delta := b.global_position - a.global_position
	var distance := delta.length()
	if distance <= a.grab_length or is_zero_approx(distance):
		return
	var shares := _shares(a, b)
	if shares == Vector2.ZERO:
		return
	var correction := delta / distance * (distance - a.grab_length)
	if shares.x > 0.0:
		a.push(correction * shares.x)
	if shares.y > 0.0:
		b.push(-correction * shares.y)


## Гасит скорость, растягивающую натянутую связь; касательная скорость остаётся — это раскачивание.
func _solve_velocity(a: Player, b: Node2D) -> void:
	var delta := b.global_position - a.global_position
	var distance := delta.length()
	if distance < a.grab_length - 1.0 or is_zero_approx(distance):
		return
	var dir := delta / distance
	var relative: Vector2 = b.velocity - a.velocity
	var separating: float = relative.dot(dir)
	if separating <= 0.0:
		return
	# Скорость меняем только тем, кто в воздухе: стоящие на земле управляют своей скоростью сами,
	# а их сдвиг уже учтён поправкой положения.
	var shares := _shares(a, b, true)
	if shares.x == 1.0 or shares.y == 1.0:
		# Висит один на неподвижной опоре — маятник. Радиальную скорость убираем, а модуль
		# сохраняем, чтобы шаг симуляции не съедал размах.
		var tangent: Vector2 = relative - dir * separating
		if tangent.length_squared() > 1.0:
			tangent = tangent.normalized() * minf(relative.length(), tangent.length() * swing_keep_limit)
		if shares.y == 1.0:
			b.velocity = a.velocity + tangent
		else:
			a.velocity = b.velocity - tangent
		return
	a.velocity += dir * separating * shares.x
	b.velocity -= dir * separating * shares.y


## Доли поправки для a и b (в сумме 1) или ноль, если оба неподвижны.
func _shares(a: Player, b: Node2D, airborne_only := false) -> Vector2:
	var wa := _mobility(a)
	var wb := _mobility(b)
	if airborne_only:
		wa = 1.0 if wa >= 1.0 else 0.0
		wb = 1.0 if wb >= 1.0 else 0.0
	if wa + wb <= 0.0:
		return Vector2.ZERO
	return Vector2(wa, wb) / (wa + wb)


## Замерший и крюк — неподвижный якорь.
func _mobility(player: Node2D) -> float:
	if player.frozen:
		return 0.0
	if player.is_on_floor():
		return grounded_mobility
	return 1.0
