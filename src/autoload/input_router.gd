extends Node
## Привязка устройств ввода к игрокам (слоты 0–3).
## Геймпад — основное устройство; две раскладки клавиатуры — для отладки.
## Игрок подключается кнопкой A / Start на геймпаде или клавишей прыжка своей раскладки.
## Основные клавиши раскладок переназначаются в настройках (GameSettings).

signal player_joined(slot: int)
signal player_left(slot: int)
## Подключённый игрок нажал Start на геймпаде — игра открывает паузу.
signal pause_requested

const MAX_PLAYERS := 4
const STICK_DEADZONE := 0.25
const TRIGGER_THRESHOLD := 0.4
const NO_DEVICE := -100
## Отрицательные id — раскладки клавиатуры, неотрицательные — id геймпадов Godot.
const KEYBOARD_1 := -1
const KEYBOARD_2 := -2
## Раскладки по умолчанию; действующие — keyboard_keys (меняются в настройках, GameSettings).
const DEFAULT_KEYS := {
	KEYBOARD_1: {
		"left": [KEY_A], "right": [KEY_D], "jump": [KEY_W, KEY_SPACE],
		"freeze": [KEY_S], "grab": [KEY_E],
	},
	KEYBOARD_2: {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "jump": [KEY_UP, KEY_ENTER],
		"freeze": [KEY_DOWN], "grab": [KEY_PERIOD, KEY_KP_0],
	},
}
const PAD_JUMP := JOY_BUTTON_A
const PAD_FREEZE: Array[JoyButton] = [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER]
const PAD_GRAB := JOY_BUTTON_RIGHT_SHOULDER  # и правый курок

## Раскладка -> действие -> клавиши (первая — основная, её переназначают в настройках).
var keyboard_keys: Dictionary = DEFAULT_KEYS.duplicate(true)
var _devices: Array[int] = [NO_DEVICE, NO_DEVICE, NO_DEVICE, NO_DEVICE]
var _jump_pressed: Array[bool] = [false, false, false, false]
var _freeze_pressed: Array[bool] = [false, false, false, false]
## Устройство -> номер кадра, в котором оно подключилось: это нажатие не должно ещё и выбрать
## пункт меню.
var _join_frame := {}


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Отладка: `-- --autojoin=2` сразу подключает обе раскладки клавиатуры.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autojoin="):
			var count := int(arg.get_slice("=", 1))
			for kb in [KEYBOARD_1, KEYBOARD_2].slice(0, clampi(count, 0, 2)):
				_join(kb)


func _input(event: InputEvent) -> void:
	var device := NO_DEVICE
	var action := ""
	if event is InputEventJoypadButton and event.pressed:
		device = event.device
		if event.button_index == PAD_JUMP:
			action = "jump"
		elif event.button_index in PAD_FREEZE:
			action = "freeze"
		elif event.button_index == JOY_BUTTON_START:
			action = "join"
		elif event.button_index == JOY_BUTTON_BACK:
			action = "leave"
	elif event is InputEventKey and event.pressed and not event.echo:
		for kb in keyboard_keys:
			for key_action in ["jump", "freeze"]:
				if event.physical_keycode in keyboard_keys[kb][key_action]:
					device = kb
					action = key_action
	if device == NO_DEVICE or action == "":
		return

	var slot := _devices.find(device)
	if slot == -1:
		if action == "jump" or action == "join":
			_join(device)
		return
	match action:
		"leave":
			_leave(slot)
		"join":
			pause_requested.emit()
		"jump":
			_jump_pressed[slot] = true
		"freeze":
			_freeze_pressed[slot] = true


func is_joined(slot: int) -> bool:
	return _devices[slot] != NO_DEVICE


func joined_slots() -> Array[int]:
	var result: Array[int] = []
	for slot in MAX_PLAYERS:
		if is_joined(slot):
			result.append(slot)
	return result


## Устройство, от которого пришло событие: id геймпада, раскладка клавиатуры или NO_DEVICE.
func device_of_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device
	if event is InputEventKey:
		for kb in keyboard_keys:
			for keys: Array in keyboard_keys[kb].values():
				if event.physical_keycode in keys:
					return kb
	return NO_DEVICE


func is_device_joined(device: int) -> bool:
	return device != NO_DEVICE and device in _devices


## Устройство подключилось в этом кадре (его нажатие уже потрачено на подключение).
func just_joined(device: int) -> bool:
	return _join_frame.get(device, -1) == Engine.get_process_frames()


func device_name(slot: int) -> String:
	var device := _devices[slot]
	match device:
		NO_DEVICE:
			return ""
		KEYBOARD_1, KEYBOARD_2:
			return "клавиатура: %s/%s, прыжок %s, замри %s, хват %s" % [key_name(device, "left"),
					key_name(device, "right"), key_name(device, "jump"), key_name(device, "freeze"),
					key_name(device, "grab")]
	return Input.get_joy_name(device)


## Горизонтальный ввод от -1 до 1.
func get_move_x(slot: int) -> float:
	var device := _devices[slot]
	if device == NO_DEVICE:
		return 0.0
	if device < 0:
		var keys: Dictionary = keyboard_keys[device]
		return float(_any_key(keys["right"])) - float(_any_key(keys["left"]))
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	x = 0.0 if absf(x) < STICK_DEADZONE else signf(x) * inverse_lerp(STICK_DEADZONE, 1.0, absf(x))
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		x -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		x += 1.0
	return clampf(x, -1.0, 1.0)


func is_jump_held(slot: int) -> bool:
	var device := _devices[slot]
	if device == NO_DEVICE:
		return false
	if device < 0:
		return _any_key(keyboard_keys[device]["jump"])
	return Input.is_joy_button_pressed(device, PAD_JUMP)


func is_grab_held(slot: int) -> bool:
	var device := _devices[slot]
	if device == NO_DEVICE:
		return false
	if device < 0:
		return _any_key(keyboard_keys[device]["grab"])
	return Input.is_joy_button_pressed(device, PAD_GRAB) \
			or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_THRESHOLD


## Возвращает true один раз на каждое нажатие прыжка.
func take_jump_press(slot: int) -> bool:
	var pressed := _jump_pressed[slot]
	_jump_pressed[slot] = false
	return pressed


## Возвращает true один раз на каждое нажатие «Замри».
func take_freeze_press(slot: int) -> bool:
	var pressed := _freeze_pressed[slot]
	_freeze_pressed[slot] = false
	return pressed


func _join(device: int) -> void:
	if device in _devices:
		return
	var slot := _devices.find(NO_DEVICE)
	if slot == -1:
		return
	_devices[slot] = device
	_join_frame[device] = Engine.get_process_frames()
	_jump_pressed[slot] = false
	_freeze_pressed[slot] = false
	player_joined.emit(slot)


func _leave(slot: int) -> void:
	_devices[slot] = NO_DEVICE
	_jump_pressed[slot] = false
	_freeze_pressed[slot] = false
	player_left.emit(slot)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	var slot := _devices.find(device)
	if slot != -1:
		_leave(slot)


func _any_key(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false


## Название основной клавиши действия раскладки для подсказок: стрелки — значками.
func key_name(keyboard: int, action: String) -> String:
	var key: Key = keyboard_keys[keyboard][action][0]
	match key:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_SPACE: return "Пробел"
		KEY_PERIOD: return "."
	return OS.get_keycode_string(key)


## Основная клавиша действия раскладки (первая в списке); запасные клавиши остаются.
func set_key(keyboard: int, action: String, key: Key) -> void:
	var keys: Array = keyboard_keys[keyboard][action].duplicate()
	# Основная клавиша не изменилась — запасные (Пробел у прыжка 1-й раскладки, Enter у 2-й) остаются.
	if not keys.is_empty() and keys[0] == key:
		return
	keys.erase(key)
	if keys.is_empty():
		keys.append(key)
	else:
		keys[0] = key
	keyboard_keys[keyboard][action] = keys


func reset_keys() -> void:
	keyboard_keys = DEFAULT_KEYS.duplicate(true)
