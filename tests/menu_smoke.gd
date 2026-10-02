extends SmokeTest
## Автопроверка меню и прогресса: каталог уровней, открытие уровней по прохождению, сохранение
## на диск, экран выбора, пауза и рестарт с чекпоинта. Настоящее сохранение не трогает.
## Запуск: Godot_console --headless --path . res://tests/menu_smoke.tscn

const TEST_SAVE := "user://test_progress.cfg"
const MENU := preload("res://src/menu/level_select.tscn")
const L06 := preload("res://levels/w01_l06_the_crate.tscn")


func _ready() -> void:
	_catalog()
	_progress()
	await _level_select()
	await _pause_and_checkpoint()
	await _menu_to_game_and_back()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	finish()


func _catalog() -> void:
	print("— каталог")
	check(Levels.count(0) == Levels.LEVELS_PER_WORLD, "в мире 1 — %d уровней" % Levels.count(0))
	var built := 0
	for i in Levels.count(0):
		if Levels.is_built(0, i):
			built += 1
			var scene: PackedScene = load(Levels.scene_path(0, i))
			var level := scene.instantiate() as GreyboxLevel
			check(level != null and level.title.begins_with("%02d · " % (i + 1)), "уровень %02d загружается: %s" % [i + 1, level.title if level else "—"])
			check(level != null and level.title.ends_with(Levels.entry(0, i).title), "название %02d совпадает с каталогом" % (i + 1))
			if level:
				level.free()
	# Уровни собираются по порядку: собранные — первые built штук.
	check(built >= 10 and Levels.is_built(0, built - 1), "собрано %d уровней, подряд с первого" % built)
	check(Levels.next_built(0, 2) == 3, "после 03 идёт 04")
	check(Levels.next_built(0, built - 1) == -1, "после последнего собранного (%02d) — возврат в меню" % built)
	check(Levels.debug_next(0, built - 1) == Vector2i(Levels.EXTRAS_WORLD, 0), "F2 после последнего — комнаты прототипа")
	check(Levels.debug_next(Levels.EXTRAS_WORLD, Levels.EXTRAS.size() - 1) == Vector2i(0, 0), "F2 после комнат — снова уровень 01")


func _progress() -> void:
	print("— прогресс")
	Progress.path = TEST_SAVE
	Progress.reset()
	check(Progress.is_unlocked(0, 0) and not Progress.is_unlocked(0, 1), "сначала открыт только 01")
	Progress.mark_completed(0, 0)
	Progress.mark_completed(0, 1)
	check(Progress.is_unlocked(0, 2) and not Progress.is_unlocked(0, 3), "пройдены 01–02 — открыт 03")
	Progress.reload_from_disk()
	check(Progress.is_completed(0, 1) and Progress.completed_count(0) == 2, "прогресс пережил перечитывание файла")
	Progress.set_unlock_all(true)
	Progress.reload_from_disk()
	check(Progress.is_unlocked(0, 9), "отладка: открыты все уровни")
	Progress.set_unlock_all(false)
	check(Progress.is_unlocked(Levels.EXTRAS_WORLD, 0), "комнаты прототипа открыты всегда")


func _level_select() -> void:
	print("— выбор уровня")
	var menu: Control = MENU.instantiate()
	add_child(menu)
	await frames(5)
	check(menu._cards.size() == Levels.count(0) + Levels.EXTRAS.size(), "карточек: %d" % menu._cards.size())
	var status: String = menu._status.text
	check(status.contains("пройдено 2 из 20"), "в строке состояния — прогресс (%s)" % status)
	# Курсор открылся на первом непройденном открытом уровне.
	Game.world = 0
	Game.level_index = 1
	menu.queue_free()
	await frames(2)
	menu = MENU.instantiate()
	add_child(menu)
	await frames(5)
	check(menu._cursor == Vector2i(0, 2), "курсор на 03 после возврата с пройденного 02 (%s)" % menu._cursor)
	# Закрытый уровень не запускается.
	menu._cursor = Vector2i(0, 4)
	menu._on_confirmed(InputRouter.NO_DEVICE)
	await frames(2)
	check(is_instance_valid(menu) and menu.is_inside_tree(), "неподключённый игрок уровень не запускает")
	menu.queue_free()
	await frames(2)


func _pause_and_checkpoint() -> void:
	print("— пауза и рестарт с чекпоинта")
	var game: Game = await start_game(L06)
	var a: Player = game.players[0]
	var crate: Crate = game.level.get_node("Crate1")
	var home := crate.global_position
	crate.global_position += Vector2(200, 0)
	place(a, Vector2(15 * 64.0, 12 * 64.0 - 29.0))
	await frames(10)
	game.restart_from_checkpoint()
	await frames(5)
	check(crate.global_position.distance_to(home) < 2.0 and a.global_position.x < 4 * 64.0,
			"рестарт с чекпоинта вернул ящик и команду (ящик %s, игрок %s)" % [crate.global_position, a.global_position])
	game._from_catalog = true  # пауза открывается только в обычной игре
	game._open_pause()
	await frames(2)
	check(get_tree().paused and game._pause.visible, "Esc/Start — пауза, игра стоит")
	tap(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not get_tree().paused and not game._pause.visible, "Esc — продолжить")
	game._from_catalog = false
	game.queue_free()
	await frames(2)


## Сквозной путь, как у игрока: меню → уровень 01 → пройден → сам грузится 02, прогресс записан →
## пауза → «Выбор уровня». Смена сцены заменяет current_scene, поэтому тест подставляет вместо
## себя пустой узел и остаётся в дереве сам.
func _menu_to_game_and_back() -> void:
	print("— меню → игра → меню")
	Progress.reset()
	Game.world = 0
	Game.level_index = 0
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	get_tree().change_scene_to_file(Game.MENU_SCENE)
	await frames(10)
	check(get_tree().current_scene.name == "LevelSelect", "открылось меню выбора уровня")
	tap(KEY_SPACE)  # игрок 1 уже подключён — Пробел запускает уровень под курсором
	await frames(15)
	var game := get_tree().current_scene as Game
	check(game != null and game.level.title == "01 · Первые шаги" and game.players.size() == 2,
			"из меню запустился уровень 01 с двумя игроками")
	if game == null:
		return
	var door: Vector2 = game.level.get_finish().global_position
	place(game.players[0], door + Vector2(-30, -29))
	place(game.players[1], door + Vector2(30, -29))
	await frames(10)
	check(game.completed and Progress.is_completed(0, 0), "уровень 01 пройден и записан в прогресс")
	await get_tree().create_timer(Game.NEXT_LEVEL_DELAY + 0.5).timeout
	game = get_tree().current_scene as Game
	check(game != null and game.level.title == "02 · Подставь плечо", "после прохождения сам загрузился 02")
	if game == null:
		return
	tap(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().paused, "Esc — пауза")
	for i in 3:
		tap(KEY_DOWN)
		await get_tree().process_frame
	tap(KEY_ENTER)  # «Выбор уровня»
	for i in 10:
		await get_tree().process_frame
	var menu := get_tree().current_scene
	check(menu != null and menu.name == "LevelSelect" and not get_tree().paused, "из паузы — в меню")
	check(menu != null and menu._cursor == Vector2i(0, 1), "курсор на 02, с которого вышли (%s)" % (menu._cursor if menu else "—"))
	Progress.reset()
