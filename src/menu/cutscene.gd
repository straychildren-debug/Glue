class_name Cutscene
extends Control
## Вступительный мультик «Истории» (assets/video/intro.ogv — Godot играет Ogg Theora; ролик
## собран HyperFrames, исходник — video/intro). Пропуск: Enter, Пробел, Esc, A, B, Start или клик.
## После ролика — первый уровень истории или главное меню.

const VIDEO := "res://assets/video/intro.ogv"
const SCENE := "res://src/menu/cutscene.tscn"

enum Then { STORY, MENU }

## Что открыть после ролика (задаётся перед сменой сцены).
static var then := Then.MENU

var _player := VideoStreamPlayer.new()
var _done := false


static func open(tree: SceneTree, p_then: Then) -> void:
	then = p_then
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	if not ResourceLoader.exists(VIDEO):
		_finish.call_deferred()
		return
	_player.stream = load(VIDEO)
	_player.expand = true
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.finished.connect(_finish)
	add_child(_player)
	var hint := Label.new()
	hint.text = "Enter / A — пропустить"
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(1640, 1030)
	add_child(hint)
	_player.play()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	skip = skip or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	skip = skip or (event is InputEventMouseButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_player.stop()
	if then == Then.STORY:
		var at := Progress.story_position()
		Game.play_story(get_tree(), at.x, at.y)
	else:
		get_tree().change_scene_to_file(Game.MAIN_MENU_SCENE)
