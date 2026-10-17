class_name GameSettings
extends RefCounted
## Настройки игрока: громкость, экран (окно или полный, размер окна), основные клавиши двух
## раскладок клавиатуры. Файл — ConfigFile в user://settings.cfg. Применяются в главном меню
## (автотесты главное меню не открывают — их раскладки не меняются).

const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const ACTIONS: Array[String] = ["left", "right", "jump", "freeze", "grab"]
const ACTION_NAMES := {"left": "Влево", "right": "Вправо", "jump": "Прыжок", "freeze": "Замри", "grab": "Хват"}

static var path := "user://settings.cfg"
## Громкость 0–1 (общая шина Master).
static var volume := 0.8
static var fullscreen := false
static var window_size := Vector2i(1280, 720)
static var _loaded := false


static func load_settings() -> void:
	_loaded = true
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	volume = clampf(float(file.get_value("audio", "volume", volume)), 0.0, 1.0)
	fullscreen = bool(file.get_value("screen", "fullscreen", fullscreen))
	window_size = file.get_value("screen", "window_size", window_size)
	InputRouter.reset_keys()
	for keyboard in [InputRouter.KEYBOARD_1, InputRouter.KEYBOARD_2]:
		for action in ACTIONS:
			var key := int(file.get_value("keys_%d" % -keyboard, action, 0))
			if key != 0:
				InputRouter.set_key(keyboard, action, key)


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("screen", "fullscreen", fullscreen)
	file.set_value("screen", "window_size", window_size)
	for keyboard in [InputRouter.KEYBOARD_1, InputRouter.KEYBOARD_2]:
		for action in ACTIONS:
			file.set_value("keys_%d" % -keyboard, action, int(InputRouter.keyboard_keys[keyboard][action][0]))
	var error := file.save(path)
	if error != OK:
		push_warning("Не удалось сохранить настройки в %s: %s" % [path, error_string(error)])


## Загружает (один раз за запуск) и применяет: громкость и экран.
static func apply_on_start() -> void:
	if not _loaded:
		load_settings()
		apply_screen()
	apply_volume()


static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)


static func apply_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(window_size)
		var screen := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(screen.position + (screen.size - window_size) / 2)
