extends SmokeTest
## Автопроверка главного меню и «Истории»: порядок уровней через миры, место в истории в
## сохранении, страницы меню, ролик и его пропуск, сквозной путь меню → история →
## уровень пройден → следующий. Настоящие сохранение и настройки не трогает.
## Запуск: Godot_console --headless --path . res://tests/story_smoke.tscn

const TEST_SAVE := "user://test_story_progress.cfg"
const TEST_SETTINGS := "user://test_settings.cfg"


func _ready() -> void:
	Progress.path = TEST_SAVE
	GameSettings.path = TEST_SETTINGS
	Progress.reset()
	_order()
	_saved_position()
	await _menu_pages()
	await _story_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	finish()


func _order() -> void:
	print("— порядок истории")
	var worlds := Levels.story_worlds()
	check(worlds == [0, 1], "история — миры 1 и 2, без пробного и прежних (%s)" % [worlds])
	check(Levels.story_next(0, 3) == Vector2i(0, 4), "после 1-04 — 1-05")
	check(Levels.story_next(0, Levels.count(0) - 1) == Vector2i(1, 0), "после последнего уровня мира 1 — первый мира 2")
	check(Levels.story_next(1, Levels.count(1) - 1) == Vector2i(-1, -1), "после последнего уровня мира 2 — конец истории")


func _saved_position() -> void:
	print("— место в истории")
	check(Progress.story_position() == Vector2i(-1, -1), "новое сохранение — история не начата")
	Progress.set_story_position(Vector2i(1, 6))
	Progress.reload_from_disk()
	check(Progress.story_position() == Vector2i(1, 6), "место в истории пережило перезагрузку")
	Progress.reset()


func _menu_pages() -> void:
	print("— главное меню")
	var menu: MainMenu = load("res://src/menu/main_menu.tscn").instantiate()
	add_child(menu)
	await frames(5)
	var texts := func() -> Array:
		return menu._column.get_children().map(func(b: Node) -> String: return b.text if b is Button else "grid")
	check(texts.call() == ["История", "Выбор уровня", "Настройки", "Выход"], "главная страница: %s" % [texts.call()])
	menu._show(MainMenu.Page.STORY)
	await frames(2)
	check(texts.call() == ["Новая история", "Смотреть вступление", "Назад"], "история не начата — без «Продолжить»: %s" % [texts.call()])
	Progress.set_story_position(Vector2i(0, 4))
	menu._show(MainMenu.Page.STORY)
	await frames(2)
	check(str(texts.call()[0]).begins_with("Продолжить: Забытые мосты"), "есть «Продолжить» с названием мира: %s" % texts.call()[0])
	menu._show(MainMenu.Page.SETTINGS)
	await frames(2)
	var volume := GameSettings.volume
	menu._change_volume(-1)
	check(is_equal_approx(GameSettings.volume, volume - 0.1), "громкость убавляется на 10%")
	menu._show(MainMenu.Page.CONTROLS)
	await frames(2)
	InputRouter.set_key(InputRouter.KEYBOARD_1, "jump", KEY_K)
	check(InputRouter.key_name(InputRouter.KEYBOARD_1, "jump") == "K", "прыжок игрока 1 переназначен на K")
	check(KEY_SPACE in InputRouter.keyboard_keys[InputRouter.KEYBOARD_1]["jump"], "запасной Пробел остался")
	GameSettings.save()
	InputRouter.reset_keys()
	GameSettings.load_settings()
	check(InputRouter.key_name(InputRouter.KEYBOARD_1, "jump") == "K", "переназначение сохранилось в настройках")
	InputRouter.reset_keys()
	menu.queue_free()
	await frames(2)


## Меню → «Новая история» → ролик → пропуск → уровень 1-01 → пройден → 1-02, место записано.
func _story_run() -> void:
	print("— сквозной путь истории")
	Progress.reset()
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	get_tree().change_scene_to_file(Game.MAIN_MENU_SCENE)
	await frames(10)
	var menu := get_tree().current_scene as MainMenu
	check(menu != null, "открылось главное меню")
	if menu == null:
		return
	menu._new_story()
	await frames(3)
	var cutscene := get_tree().current_scene as Cutscene
	check(cutscene != null, "новая история открывает вступительный ролик")
	if cutscene != null:
		check(cutscene._player.stream != null, "вступительный ролик загружен")
		cutscene._finish()
	await frames(30)
	var game := get_tree().current_scene as Game
	check(game != null and Game.story and game.level.title.begins_with("01 · "), "история началась с уровня 01 (ролик пропущен или проигран)")
	if game == null:
		return
	check(Progress.story_position() == Vector2i(0, 0), "место в истории — 1-01")
	tap(KEY_SPACE)
	tap(KEY_ENTER)
	await frames(20)
	var door: Vector2 = game.level.get_finish().global_position
	for player: Player in game.players.values():
		place(player, door + Vector2(-30 + 60 * game.players.values().find(player), -29))
	await frames(10)
	check(game.completed and Progress.story_position() == Vector2i(0, 1), "уровень пройден — место в истории 1-02")
	await get_tree().create_timer(Game.NEXT_LEVEL_DELAY + 0.5).timeout
	await frames(10)
	var next := get_tree().current_scene as Game
	check(next != null and next.level.title.begins_with("02 · "), "история сама перешла к уровню 02")
	Game.open_menu(get_tree())
	await frames(10)
	check(get_tree().current_scene is MainMenu and not Game.story, "из истории — в главное меню")
