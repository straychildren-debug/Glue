extends "res://tests/world2_new_smoke.gd"
## Проба: сколько пролетает герой в коридоре 16 (низкий потолок) — с попутным порывом и без.


func _ready() -> void:
	game = await start_game(load("res://levels/w02_l16_gust.tscn"))
	a = game.players[0]
	b = game.players[1]
	var camera: SharedCamera = game.get_node("SharedCamera")
	var wind: Bellows = game.level.get_node("WindUR")
	for st: float in [0.0, 0.4, 0.5, 0.6, 0.7]:
		var with_wind := st > 0.0
		wind.strength = st
		var pa := Vector2(29.4 * TILE, 2 * TILE - Player.SIZE.y / 2.0)
		var pb := Vector2(28.0 * TILE, 8 * TILE - Player.SIZE.y / 2.0)
		camera.snap_to((pa + pb) / 2.0)
		await frames(1)
		place(a, pa)
		place(b, pb)
		camera.snap_to((pa + pb) / 2.0)
		await frames(5)
		if with_wind:
			await _wait_gust(wind, true)
		else:
			await _wait_gust(wind, false)
			await frames(5)
		press(KEYS_1[RIGHT], true)
		for i in 60:
			await get_tree().physics_frame
			if a.global_position.x > 30.75 * TILE:
				break
		press(KEYS_1[JUMP], true)
		var max_x := 0.0
		for i in 90:
			await get_tree().physics_frame
			if i > 3 and a.is_on_floor():
				break
		press(KEYS_1[RIGHT], false)
		press(KEYS_1[JUMP], false)
		print("LAB сила %.1f: приземлился x %.2f скорость %.0f (камень 34–37)" % [st, a.global_position.x / TILE, a.velocity.x])
		await frames(120)
	finish()
