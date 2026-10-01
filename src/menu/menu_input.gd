class_name MenuInput
extends Node
## Ввод в меню с любого устройства: крестовина, стик (с автоповтором), стрелки и WASD —
## перемещение; A, Enter, Пробел — выбрать; B, Esc — назад; Start — отдельный сигнал.
## Работает и на паузе.

signal moved(direction: Vector2i)
## device — устройство в нумерации InputRouter (геймпад или раскладка клавиатуры).
signal confirmed(device: int)
signal cancelled
signal start_pressed(device: int)

const STICK_THRESHOLD := 0.55
const REPEAT_DELAY := 0.35
const REPEAT_INTERVAL := 0.12
const KEY_DIRECTIONS := {
	KEY_UP: Vector2i.UP, KEY_W: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN, KEY_S: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT, KEY_A: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT, KEY_D: Vector2i.RIGHT,
}
const PAD_DIRECTIONS := {
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
}

## Принимать ли ввод (меню открыто).
var enabled := true
## Поглощать ли события. В меню выбора уровня — нет: те же нажатия подключают игроков (InputRouter).
var consume := true
## Кадр, до которого (включительно) ввод игнорируется: нажатие, открывшее меню, его же не закроет.
var ignore_until_frame := -1

## Геймпад -> {direction, timer} для автоповтора стика.
var _stick := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not enabled or Engine.get_process_frames() <= ignore_until_frame:
		return
	if event is InputEventKey and event.pressed:
		var key: Key = event.physical_keycode
		if KEY_DIRECTIONS.has(key):
			_handled()
			moved.emit(KEY_DIRECTIONS[key])
		elif event.echo:
			return
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_handled()
			confirmed.emit(InputRouter.device_of_event(event))
		elif key == KEY_ESCAPE:
			_handled()
			cancelled.emit()
	elif event is InputEventJoypadButton and event.pressed:
		if PAD_DIRECTIONS.has(event.button_index):
			_handled()
			moved.emit(PAD_DIRECTIONS[event.button_index])
		elif event.button_index == JOY_BUTTON_A:
			_handled()
			confirmed.emit(event.device)
		elif event.button_index == JOY_BUTTON_B:
			_handled()
			cancelled.emit()
		elif event.button_index == JOY_BUTTON_START:
			_handled()
			start_pressed.emit(event.device)


func _process(delta: float) -> void:
	if not enabled:
		_stick.clear()
		return
	for device in Input.get_connected_joypads():
		var axis := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		var direction := Vector2i.ZERO
		if absf(axis.x) >= STICK_THRESHOLD and absf(axis.x) >= absf(axis.y):
			direction = Vector2i(signi(roundi(signf(axis.x))), 0)
		elif absf(axis.y) >= STICK_THRESHOLD:
			direction = Vector2i(0, signi(roundi(signf(axis.y))))
		var state: Dictionary = _stick.get(device, {"direction": Vector2i.ZERO, "timer": 0.0})
		if direction == Vector2i.ZERO:
			_stick.erase(device)
			continue
		if direction != state.direction:
			state = {"direction": direction, "timer": REPEAT_DELAY}
			moved.emit(direction)
		else:
			state.timer -= delta
			if state.timer <= 0.0:
				state.timer = REPEAT_INTERVAL
				moved.emit(direction)
		_stick[device] = state


func _handled() -> void:
	if consume:
		get_viewport().set_input_as_handled()
