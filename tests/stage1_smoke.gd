extends SmokeTest
## Автопроверка этапа 1 без геймпадов: две раскладки клавиатуры.
## Запуск: Godot_console --headless --path . res://tests/stage1_smoke.tscn


func _ready() -> void:
	var game: Node = await start_game()
	var p1: Player = game.players.get(0)
	var p2: Player = game.players.get(1)
	check(p1 != null and p2 != null, "оба игрока подключились")
	if p1 == null or p2 == null:
		return finish()
	check(p1.is_on_floor() and p2.is_on_floor(), "оба стоят на полу")

	# Игроки не проходят друг сквозь друга: игрок 1 упирается в игрока 2 справа.
	var blocked_x := p1.global_position.x
	await hold(KEY_D, 20)
	check(p1.global_position.x - blocked_x < 12.0, "игрок 1 упирается в игрока 2")

	p2.global_position.x += 400.0
	await frames(10)
	var x0 := p1.global_position.x
	await hold(KEY_D, 30)
	check(p1.global_position.x > x0 + 100.0, "игрок 1 бежит вправо (%.0f px)" % (p1.global_position.x - x0))

	var y0 := p1.global_position.y
	var top := y0
	press(KEY_W, true)
	for i in 40:
		await get_tree().physics_frame
		top = minf(top, p1.global_position.y)
	press(KEY_W, false)
	await frames(30)
	check(y0 - top > 120.0, "прыжок ≈ %.0f px" % (y0 - top))
	check(p1.is_on_floor(), "игрок 1 приземлился")

	# Игрок 2 становится на голову игрока 1.
	place(p2, p1.global_position + Vector2(0, -Player.SIZE.y - 4.0))
	await frames(20)
	check(p2.is_on_floor() and absf(p2.global_position.y - (p1.global_position.y - Player.SIZE.y)) < 3.0,
			"игрок 2 стоит на игроке 1")
	var dx1 := p1.global_position.x
	var dx2 := p2.global_position.x
	await hold(KEY_A, 20)
	var moved1 := p1.global_position.x - dx1
	var moved2 := p2.global_position.x - dx2
	check(moved1 < -40.0 and absf(moved2 - moved1) < 12.0,
			"игрок 2 едет на игроке 1 (%.0f / %.0f px)" % [moved1, moved2])

	# Высокая платформа (3 тайла) доступна только с головы товарища.
	# Ставим игрока 1 под краем платформы, игрока 2 — на него.
	place(p1, Vector2(27.5 * 64.0, 12 * 64.0 - Player.SIZE.y / 2.0 - 1.0))
	place(p2, p1.global_position + Vector2(0, -Player.SIZE.y - 2.0))
	await frames(20)
	press(KEY_UP, true)
	press(KEY_RIGHT, true)
	await frames(45)
	press(KEY_UP, false)
	press(KEY_RIGHT, false)
	await frames(20)
	check(p2.is_on_floor() and p2.global_position.y < 9 * 64.0,
			"с головы товарища запрыгнул на платформу 3 тайла")
	check(game.level.active_checkpoint == 1, "чекпоинт 2 активирован")

	# Падение одного — общий респавн команды через ~1 с у активного чекпоинта.
	p2.global_position.x += 300.0
	await frames(5)
	var p2_before := p2.global_position
	p1.global_position.y = game.level.get_kill_y() + 10.0
	await frames(3)
	check(not p1.alive, "игрок 1 погиб за линией смерти")
	press(KEY_RIGHT, true)
	await frames(20)
	press(KEY_RIGHT, false)
	check(p2.global_position.is_equal_approx(p2_before), "игрок 2 замер до общего респавна")
	await frames(50)
	check(p1.alive and p1.global_position.distance_to(game.level.get_spawn_position(1, 0)) < 2.0,
			"игрок 1 возродился у чекпоинта 2")
	check(p2.global_position.distance_to(game.level.get_spawn_position(1, 1)) < 2.0,
			"игрок 2 тоже перенесён к чекпоинту 2")
	finish()
