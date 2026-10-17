extends "res://tests/tuning/t06_windows.gd"

func _ready() -> void:
	world1 = true
	LEVEL = load("res://levels/w01_l11_relay.tscn")
	game = await start_game(LEVEL)
	for y in [10.5, 10.7]:
		var ok: Array[int] = []
		for delay in range(0, 80, 4):
			await _load(LEVEL)
			a = game.players[0]
			b = game.players[1]
			var camera: SharedCamera = game.get_node("SharedCamera")
			var walls: Array = [camera.get("_wall_left"), camera.get("_wall_right"), camera.get("_wall_top")]
			for wall: StaticBody2D in walls:
				wall.collision_layer = 0
			camera.snap_to(Vector2(17 * TILE, 8 * TILE))
			_restore_walls(walls)
			var saw: Saw = game.level.get_node("SawOverPit")
			saw.position.y = y * TILE
			saw.speed = 150.0
			game.level.get_node("GateL2").set("_latched", true)
			place(a, Vector2(10 * TILE, _stand_y(7)))
			place(b, Vector2(16.0 * TILE, _stand_y(12)))
			for i in 300:
				if saw.forward and saw.progress < 0.05:
					break
				await get_tree().physics_frame
			await frames(delay)
			if await _go_jump(b, KEYS_2, 16.35, 20.0):
				ok.append(delay)
		print("y ", y, " удачные задержки ", ok)
	get_tree().quit()
