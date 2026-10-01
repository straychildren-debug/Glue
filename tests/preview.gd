extends Node
## Снимки сцен в PNG — превью уровней и меню без ручного запуска игры.
## Запуск (окно можно увести за экран):
##   Godot --path . --position -6000,-6000 res://tests/preview.tscn -- <папка> <res://сцена.tscn> [...]
## Уровень снимается целиком (камера охватывает его границы), остальные сцены — как есть.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("preview: нужны <папка> и хотя бы одна сцена")
		get_tree().quit(1)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for path in args.slice(1):
		var scene: Node = load(path).instantiate()
		add_child(scene)
		var camera: Camera2D = null
		if scene is GreyboxLevel:
			var bounds: Rect2 = scene.get_bounds_px()
			camera = Camera2D.new()
			camera.position = bounds.get_center()
			var view := get_viewport().get_visible_rect().size
			var zoom := minf(view.x / bounds.size.x, view.y / bounds.size.y)
			camera.zoom = Vector2(zoom, zoom)
			add_child(camera)
			camera.make_current()
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var file := out_dir.path_join(path.get_file().get_basename() + ".png")
		image.save_png(file)
		print("preview: ", file)
		scene.queue_free()
		if camera:
			camera.queue_free()
		await get_tree().process_frame
	get_tree().quit()
