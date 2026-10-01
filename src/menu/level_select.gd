extends Control
## Выбор уровня: сетка 20 уровней мира и комнаты прототипа. Уровень открыт, если пройден
## предыдущий (прогресс хранит Progress). Здесь же подключаются игроки — тем же нажатием,
## что и в игре; выбрать уровень может только подключившийся.

const COLUMNS := 5
const CARD_SIZE := Vector2(300, 116)
const COLOR_BG := Color("c9d9e8")
const COLOR_TEXT := Color("1f2329")
const COLOR_MUTED := Color("5b6470")
const COLOR_CARD := Color("f4efe2")
const COLOR_DONE := Color("7fae5c")
const COLOR_LOCKED := Color("9aa3ad")
const COLOR_FOCUS := Color("f2c230")

var world := 0
## Курсор: строка и столбец. Последняя строка — комнаты прототипа.
var _cursor := Vector2i.ZERO
var _cards := {}  # Vector2i -> PanelContainer
var _players_label := Label.new()
var _status := Label.new()
var _input := MenuInput.new()


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_input.consume = false
	_input.moved.connect(_on_moved)
	_input.confirmed.connect(_on_confirmed)
	_input.start_pressed.connect(_on_confirmed)
	_input.cancelled.connect(func() -> void: get_tree().quit())
	add_child(_input)
	InputRouter.player_joined.connect(_on_players_changed.unbind(1))
	InputRouter.player_left.connect(_on_players_changed.unbind(1))
	_build()
	# Курсор — на уровне, откуда вернулись; если он пройден — на первом непройденном открытом после него.
	var start := Game.level_index if Game.world == world else 0
	while Progress.is_completed(world, start):
		var next := Levels.next_built(world, start)
		if next == -1 or not Progress.is_unlocked(world, next):
			break
		start = next
	if Game.world == Levels.EXTRAS_WORLD:
		_cursor = Vector2i(_extras_row(), Game.level_index)
	else:
		_cursor = Vector2i(start / COLUMNS, start % COLUMNS)
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 80
	column.offset_right = -80
	column.offset_top = 48
	column.offset_bottom = -40
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	column.add_child(_label("Держись!  ·  мир %d — %s" % [world + 1, Levels.WORLDS[world].title], 52, COLOR_TEXT))

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	for i in Levels.count(world):
		var card := _card()
		grid.add_child(card)
		_cards[Vector2i(i / COLUMNS, i % COLUMNS)] = card

	column.add_child(_label("Комнаты прототипа", 28, COLOR_MUTED))
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 20)
	extras.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(extras)
	for i in Levels.EXTRAS.size():
		var card := _card(Vector2(CARD_SIZE.x, 64))
		extras.add_child(card)
		_cards[Vector2i(_extras_row(), i)] = card

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_status.add_theme_font_size_override("font_size", 28)
	_status.add_theme_color_override("font_color", COLOR_TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_players_label.add_theme_font_size_override("font_size", 26)
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_players_label)
	column.add_child(_label(
			"Стик, крестовина или стрелки — выбор · A / Enter / Пробел — играть · F9 — открыть все уровни (отладка) · Esc — выход",
			22, COLOR_MUTED))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		Progress.set_unlock_all(not Progress.unlock_all)
		_refresh()


func _extras_row() -> int:
	return ceili(Levels.count(world) / float(COLUMNS))


## Мир и номер уровня под курсором.
func _selection(cell: Vector2i) -> Vector2i:
	if cell.x == _extras_row():
		return Vector2i(Levels.EXTRAS_WORLD, cell.y)
	return Vector2i(world, cell.x * COLUMNS + cell.y)


func _on_moved(direction: Vector2i) -> void:
	var cell := _cursor + Vector2i(direction.y, direction.x)
	cell.x = clampi(cell.x, 0, _extras_row())
	var row_length := Levels.EXTRAS.size() if cell.x == _extras_row() else COLUMNS
	cell.y = clampi(cell.y, 0, row_length - 1)
	if _cards.has(cell):
		_cursor = cell
		_refresh()


func _on_confirmed(device: int) -> void:
	# Нажатие, которым игрок только что подключился, уровень не запускает.
	if not InputRouter.is_device_joined(device) or InputRouter.just_joined(device):
		return
	var target := _selection(_cursor)
	if not Levels.is_built(target.x, target.y):
		_status.text = "Этот уровень ещё не собран."
		return
	if not Progress.is_unlocked(target.x, target.y):
		_status.text = "Сначала пройдите предыдущий уровень."
		return
	Game.play(get_tree(), target.x, target.y)


func _on_players_changed() -> void:
	_refresh()


func _refresh() -> void:
	for cell: Vector2i in _cards:
		_paint(cell, _cards[cell])
	var target := _selection(_cursor)
	var title: String = Levels.entry(target.x, target.y).title
	if target.x == Levels.EXTRAS_WORLD:
		_status.text = title
	else:
		_status.text = "%02d · %s" % [target.y + 1, title]
		if not Levels.is_built(target.x, target.y):
			_status.text += " — скоро"
		elif not Progress.is_unlocked(target.x, target.y):
			_status.text += " — закрыт"
		elif Progress.is_completed(target.x, target.y):
			_status.text += " — пройден"
	_status.text += "   ·   пройдено %d из %d" % [Progress.completed_count(world), Levels.count(world)]
	if Progress.unlock_all:
		_status.text += "   ·   открыты все (F9)"

	var slots := InputRouter.joined_slots()
	if slots.is_empty():
		_players_label.text = "Подключитесь: A на геймпаде · W/Пробел или ↑/Enter на клавиатуре (вдвоём — две раскладки)"
		_players_label.add_theme_color_override("font_color", Color("c2410c"))
	else:
		var names: Array[String] = []
		for slot in slots:
			names.append(Player.COLOR_NAMES[slot])
		_players_label.text = "Игроки: %s   ·   ещё один — A на своём геймпаде" % ", ".join(names)
		_players_label.add_theme_color_override("font_color", COLOR_TEXT)


func _paint(cell: Vector2i, card: PanelContainer) -> void:
	var target := _selection(cell)
	var built := Levels.is_built(target.x, target.y)
	var unlocked := built and Progress.is_unlocked(target.x, target.y)
	var done := target.x != Levels.EXTRAS_WORLD and Progress.is_completed(target.x, target.y)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	style.bg_color = COLOR_CARD if unlocked else COLOR_CARD.darkened(0.18)
	style.border_color = COLOR_DONE if done else (COLOR_TEXT if unlocked else COLOR_LOCKED)
	style.set_border_width_all(4)
	if cell == _cursor:
		style.border_color = COLOR_FOCUS
		style.set_border_width_all(10)
	card.add_theme_stylebox_override("panel", style)

	var number: Label = card.get_node("Box/Number")
	var title: Label = card.get_node("Box/Title")
	var state: Label = card.get_node("Box/State")
	var entry := Levels.entry(target.x, target.y)
	if target.x == Levels.EXTRAS_WORLD:
		number.visible = false
		state.visible = false
		title.text = entry.title
	else:
		number.text = "%02d" % (target.y + 1)
		title.text = entry.title
		state.text = "✓ пройден" if done else ("открыт" if unlocked else ("закрыт" if built else "скоро"))
	var text_color := COLOR_TEXT if unlocked else COLOR_MUTED
	for label in [number, title]:
		label.add_theme_color_override("font_color", text_color)
	state.add_theme_color_override("font_color", COLOR_DONE.darkened(0.3) if done else COLOR_MUTED)


func _card(size := CARD_SIZE) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = size
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	for part in [["Number", 34], ["Title", 26], ["State", 20]]:
		var label := Label.new()
		label.name = part[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", part[1])
		box.add_child(label)
	return card


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
