extends SmokeTest
## Снимки уровня с задником для настройки слоёв: два игрока ставятся в заданные точки,
## камера успокаивается, кадр сохраняется в PNG.
## Запуск (окно можно увести за экран):
##   Godot --path . --resolution 1920x1080 --position -6000,-6000 res://tests/backdrop_shot.tscn -- \
##       <папка> <res://уровень.tscn> <x1,y1;x2,y2 в тайлах> [ещё пары точек ...]
## Каждая пара точек — отдельный снимок <имя_уровня>_<n>.png. Точка — где стоит игрок (низ ног).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("backdrop_shot: нужны <папка> <уровень> <точки>")
		get_tree().quit(1)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game: Node = await start_game(load(args[1]))
	var shot := 0
	for spec in args.slice(2):
		var points := spec.split(";")
		for slot in mini(points.size(), game.players.size()):
			var xy := points[slot].split(",")
			var player: Player = game.players[slot]
			place(player, Vector2(float(xy[0]), float(xy[1])) * GreyboxLevel.TILE
					- Vector2(0, Player.SIZE.y / 2.0 + 1.0))
		await frames(150)  # камера доезжает и меняет масштаб
		await RenderingServer.frame_post_draw
		var file := out_dir.path_join("%s_%d.png" % [args[1].get_file().get_basename(), shot])
		get_viewport().get_texture().get_image().save_png(file)
		print("backdrop_shot: ", file)
		shot += 1
	get_tree().quit()
