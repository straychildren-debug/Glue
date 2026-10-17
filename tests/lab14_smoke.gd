extends LevelBot
## Проба: едет ли замерший на трапеции «двойки» и что с ним делают пилы.


func _ready() -> void:
	game = await start_game(load("res://levels/w02_l14_spring_circus.tscn"))
	a = game.players[0]
	b = game.players[1]
	var tu: Mover = game.level.get_node("TrapezeU")
	var tl: Mover = game.level.get_node("TrapezeL")
	var pa := Vector2(6.5 * TILE, 8 * TILE - Player.SIZE.y / 2.0)
	var pb := Vector2(6.5 * TILE, 12 * TILE - Player.SIZE.y / 2.0)
	var camera: SharedCamera = game.get_node("SharedCamera")
	camera.snap_to((pa + pb) / 2.0)
	await frames(1)
	place(a, pa)
	place(b, pb)
	camera.snap_to((pa + pb) / 2.0)
	await frames(10)
	await frames(20)
	print("LAB старт: двойка едет %s / %s" % [tu.moving, tl.moving])
	await frames(20)
	tap(KEYS_1[FREEZE])
	for i in 8:
		await frames(30)
		print("LAB %d: A %s замер %s жив %s, трапеция x %.2f прогресс %.2f; B %s" % [i, a.global_position / TILE, a.frozen, a.alive, tu.global_position.x / TILE, tu.progress, b.global_position / TILE])
	finish()
