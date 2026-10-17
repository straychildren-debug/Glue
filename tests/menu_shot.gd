extends Node
## Снимок меню в PNG (проверка оформления): выбор уровня или другая сцена меню.
## Запуск: Godot --path . --resolution 1920x1080 --position -6000,-6000 res://tests/menu_shot.tscn -- <файл.png> [res://сцена.tscn] [страница]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := args[1] if args.size() > 1 else "res://src/menu/level_select.tscn"
	var menu: Control = load(scene).instantiate()
	add_child(menu)
	if args.size() > 2 and menu.has_method("_show"):
		await get_tree().process_frame
		menu.call("_show", int(args[2]))
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
