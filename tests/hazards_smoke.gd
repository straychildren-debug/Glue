extends LevelBot
## Автопроверка опасностей: шипы, пила, призрак-стесняшка (комната levels/hazards.tscn).
## Запуск: Godot_console --headless --path . res://tests/hazards_smoke.tscn
## Шипы — x 8–14 тайлов; пила по полу — x 20–29; ниша с финишем за дверью на замке — x 33–40;
## зал призрака — x 41–70 (призрак у x 55, ключ у x 66).

var deaths := 0
var camera: SharedCamera


func _ready() -> void:
	game = await start_game(preload("res://levels/hazards.tscn"))
	camera = game.get_node("SharedCamera")
	a = game.players[0]
	b = game.players[1]
	for p: Player in [a, b]:
		p.died.connect(func(_who: Player) -> void: deaths += 1)
	await _spikes()
	await _saw()
	await _ghost()
	finish()


func _spikes() -> void:
	var spikes: Spikes = game.level.get_node("Spikes")
	var zone := spikes.get_rect()
	# Незамерший падает в шипы — гибель и общий респавн.
	var before := deaths
	await _teleport(a, Vector2(11 * TILE, zone.position.y - 60.0), b, Vector2(3 * TILE, _stand_y(12)))
	await frames(40)
	check(deaths == before + 1, "упал в шипы — погиб")
	await frames(90)
	check(a.alive and a.global_position.x < 4 * TILE, "общий респавн у старта")
	# Замерший — камень: в шипах цел, по нему проходят.
	tap(KEYS_1[FREEZE])
	await frames(2)
	await _teleport(a, Vector2(11 * TILE, zone.end.y - Player.SIZE.y / 2.0 - 4.0), b, Vector2(7 * TILE, _stand_y(12)))
	await frames(30)
	check(a.alive and a.frozen and deaths == before + 1, "замерший стоит в шипах и цел")
	await _onto_head(b, a)
	check(b.alive and b.standing_on() == a, "Б стоит на голове замершего над шипами")
	await _hop_to(b, 15.5 * TILE)
	await _walk_to(b, KEYS_2, 17.0 * TILE)
	check(b.alive and b.global_position.x > 16 * TILE, "Б перешёл шипы по голове замершего и взял чекпоинт")
	# А оживает в шипах — гибнет, и оба появляются у чекпоинта за шипами.
	tap(KEYS_1[FREEZE])
	await frames(10)
	check(deaths == before + 2, "ожил в шипах — погиб")
	await frames(90)
	check(a.alive and b.alive and a.global_position.x > 15 * TILE and b.global_position.x > 15 * TILE,
			"оба у чекпоинта за шипами (a %s b %s)" % [a.global_position, b.global_position])


func _saw() -> void:
	var saw: Saw = game.level.get_node("FloorSaw")
	var hanging: Saw = game.level.get_node("HangingSaw")
	hanging.speed = 0.0  # не мешает проверке пилы на полу
	hanging.progress = 0.0
	# Пила режет незамершего.
	var before := deaths
	await _teleport(a, Vector2(16 * TILE, _stand_y(12)), b, Vector2(17 * TILE, _stand_y(12)))
	place(b, Vector2(saw.blade_position().x + 10.0, _stand_y(12)))
	await frames(5)
	check(deaths == before + 1, "пила режет незамершего")
	await frames(120)
	# Замерший укорачивает пиле путь: она отскакивает от него и не заходит дальше.
	tap(KEYS_1[FREEZE])  # сначала замереть: на рельсе пила режет незамершего
	await frames(2)
	await _teleport(a, Vector2(25 * TILE, _stand_y(12)), b, Vector2(17 * TILE, _stand_y(12)))
	var farthest := 0.0
	var moved := 0.0
	var last := saw.blade_position().x
	for i in 360:
		await get_tree().physics_frame
		farthest = maxf(farthest, saw.blade_position().x)
		moved += absf(saw.blade_position().x - last)
		last = saw.blade_position().x
	check(a.alive and farthest < a.global_position.x - Player.SIZE.x / 2.0,
			"пила не проходит дальше замершего (край пилы %.0f, замерший %.0f)" % [farthest + saw.radius(), a.global_position.x])
	check(moved > 400.0, "пила продолжает ездить — от замершего назад (%.0f px)" % moved)
	place(a, Vector2(17.5 * TILE, _stand_y(12)))  # замерший уходит с рельса и только потом оживает
	await frames(2)
	tap(KEYS_1[FREEZE])
	await frames(5)
	hanging.speed = 160.0


func _ghost() -> void:
	var ghost: Ghost = game.level.get_node("Ghost")
	var home := ghost.global_position
	var floor_y := _stand_y(12)
	await _teleport(a, Vector2(48 * TILE, floor_y), b, Vector2(46 * TILE, floor_y))
	await hold(KEYS_1[RIGHT], 2)
	await hold(KEYS_2[RIGHT], 2)
	var start := ghost.global_position
	await frames(60)
	check(ghost.watched and ghost.global_position.distance_to(start) < 2.0, "на призрака смотрят — он стоит")
	# Отвернулись оба — летит к ближайшему.
	await hold(KEYS_1[LEFT], 2)
	await hold(KEYS_2[LEFT], 2)
	start = ghost.global_position
	await frames(60)
	check(not ghost.watched and ghost.global_position.distance_to(start) > 40.0, "отвернулись — призрак летит")
	# Замерший не смотрит: глаза закрыты.
	await hold(KEYS_1[RIGHT], 2)
	tap(KEYS_1[FREEZE])
	await frames(3)
	start = ghost.global_position
	await frames(30)
	check(a.frozen and not ghost.watched and ghost.global_position.distance_to(start) > 10.0,
			"замерший лицом к призраку не смотрит — тот летит (замер %s смотрят %s сдвиг %.0f, a %s b %s призрак %s b.facing %d)"
			% [a.frozen, ghost.watched, ghost.global_position.distance_to(start), a.global_position, b.global_position, ghost.global_position, b.facing])
	tap(KEYS_1[FREEZE])
	await frames(3)
	# Касание незамершего — гибель; после респавна призрак на месте.
	var before := deaths
	await hold(KEYS_1[LEFT], 2)
	for i in 600:
		await get_tree().physics_frame
		if deaths > before:
			break
	check(deaths > before, "призрак догнал и коснулся — гибель")
	for i in 150:  # ждём появления команды — в этот кадр призрак уже на месте
		await get_tree().physics_frame
		if a.alive and b.alive and a.is_physics_processing():
			break
	check(ghost.global_position.distance_to(home) < 4.0, "после общего респавна призрак на своём месте")


## Стены кадра физика видит на новом месте только со следующего кадра — поэтому сначала камера.
func _teleport(p: Player, p_at: Vector2, q: Player, q_at: Vector2) -> void:
	camera.snap_to((p_at + q_at) / 2.0)
	await frames(1)
	place(p, p_at)
	place(q, q_at)
	camera.snap_to((p_at + q_at) / 2.0)
	await frames(10)
