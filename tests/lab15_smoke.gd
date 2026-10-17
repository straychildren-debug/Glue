extends "res://tests/world2_new_smoke.gd"
## Проба: успевает ли один раскрутить все три колеса пятой части 15 и пробежать ворота.


func _ready() -> void:
	game = await start_game(load("res://levels/w02_l15_wheel.tscn"))
	a = game.players[0]
	b = game.players[1]
	var camera: SharedCamera = game.get_node("SharedCamera")
	var pa := Vector2(55.0 * TILE, 4 * TILE - Player.SIZE.y / 2.0)
	var pb := Vector2(50.5 * TILE, 4 * TILE - Player.SIZE.y / 2.0)
	camera.snap_to((pa + pb) / 2.0)
	await frames(1)
	place(a, pa)
	place(b, pb)
	camera.snap_to((pa + pb) / 2.0)
	await frames(10)
	var w := [game.level.get_node("Wheel8"), game.level.get_node("Wheel9"), game.level.get_node("Wheel10")]
	var gate: Door = game.level.get_node("Gate10")
	for i in 3:
		await _walk_jumping(a, w[i].global_position.x)
		var stop := [false]
		_spin(a, stop)
		await _until(func() -> bool: return w[i].spin > 0.99, 300)
		stop[0] = true
		if i < 2:
			await _leave_wheel(a, w[i + 1].global_position.x - 1.5 * TILE)
	print("LAB все три раскручены: %.2f %.2f %.2f, ворота %s" % [w[0].spin, w[1].spin, w[2].spin, gate.is_open_requested()])
	await _leave_wheel(a, 73.5 * TILE)
	print("LAB один: А %s (за воротами — x > 72), колёса %.2f %.2f %.2f" % [a.global_position / TILE, w[0].spin, w[1].spin, w[2].spin])
	finish()
