class_name PauseMenu
extends CanvasLayer
## Пауза: Start на геймпаде или Esc. Можно вернуть команду к чекпоинту, если она застряла,
## начать уровень заново или выйти к выбору уровня. Управляет любой игрок.

signal chosen(action: Action)

enum Action { RESUME, CHECKPOINT, RESTART, MENU, QUIT }

const ITEMS := [
	[Action.RESUME, "Продолжить"],
	[Action.CHECKPOINT, "Рестарт с чекпоинта"],
	[Action.RESTART, "Начать уровень заново"],
	[Action.MENU, "Выбор уровня"],
	[Action.QUIT, "Выйти из игры"],
]

var _selected := 0
var _labels: Array[Label] = []
var _input := MenuInput.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_input.enabled = false
	_input.moved.connect(_on_moved)
	_input.confirmed.connect(func(_device: int) -> void: _choose(ITEMS[_selected][0]))
	_input.cancelled.connect(_choose.bind(Action.RESUME))
	_input.start_pressed.connect(func(_device: int) -> void: _choose(Action.RESUME))
	add_child(_input)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4efe2")
	style.border_color = Color("3a3f47")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("1f2329"))
	column.add_child(title)
	for item in ITEMS:
		var label := Label.new()
		label.text = item[1]
		label.custom_minimum_size = Vector2(560, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 38)
		column.add_child(label)
		_labels.append(label)
	var hint := Label.new()
	hint.text = "Стик или стрелки — выбор · A / Enter — да · B / Esc / Start — назад"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("5b6470"))
	column.add_child(hint)
	_refresh()


func open() -> void:
	_selected = 0
	_refresh()
	visible = true
	_input.enabled = true
	# Нажатие, открывшее паузу, не должно её же и закрыть.
	_input.ignore_until_frame = Engine.get_process_frames()
	get_tree().paused = true


func _choose(action: Action) -> void:
	if not visible:
		return
	visible = false
	_input.enabled = false
	get_tree().paused = false
	if action != Action.RESUME:
		chosen.emit(action)


func _on_moved(direction: Vector2i) -> void:
	if direction.y == 0:
		return
	_selected = wrapi(_selected + direction.y, 0, ITEMS.size())
	_refresh()


func _refresh() -> void:
	for i in _labels.size():
		var selected := i == _selected
		_labels[i].text = ("▶  %s  ◀" if selected else "%s") % ITEMS[i][1]
		_labels[i].add_theme_color_override("font_color", Color("c2410c") if selected else Color("3a3f47"))
