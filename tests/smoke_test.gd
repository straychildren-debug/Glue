class_name SmokeTest
extends Node
## Общие помощники автопроверок: запуск игры, нажатия клавиш через Input.parse_input_event, проверки.

const GAME_SCENE := preload("res://src/game/game.tscn")

var _failures := 0


## Запускает игру (при необходимости — на другом уровне) и подключает обе раскладки клавиатуры.
func start_game(level_scene: PackedScene = null) -> Node:
	var game := GAME_SCENE.instantiate()
	if level_scene:
		game.level_scene = level_scene
	add_child(game)
	await frames(2)
	tap(KEY_SPACE)  # игрок 1 подключается
	tap(KEY_ENTER)  # игрок 2 подключается
	await frames(30)
	return game


## Ставит игрока в точку и гасит скорость.
func place(player: Player, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO


func finish() -> void:
	print("SMOKE: ", "OK" if _failures == 0 else "FAILED (%d)" % _failures)
	get_tree().quit(1 if _failures else 0)


func check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func press(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func tap(key: Key) -> void:
	press(key, true)
	press(key, false)


func hold(key: Key, count: int) -> void:
	press(key, true)
	await frames(count)
	press(key, false)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
