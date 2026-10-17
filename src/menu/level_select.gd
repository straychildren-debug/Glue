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
## Панорама мира за сеткой (задание 09 — M1, задание 17 — W2M2); у мира без своей — ровный цвет COLOR_BG.
const BACKGROUNDS := {0: "res://assets/backgrounds/menu/source/menu_panorama.png",
		1: "res://assets/backgrounds/menu/source/menu_panorama_w02.png"}
## Светлая обводка надписей: читаются поверх панорамы.
const OUTLINE := Color(1.0, 1.0, 0.97, 0.8)
## «Мир» карточки в ряду миров (_selection).
const WORLD_TAB := -2

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
	_input.cancelled.connect(func() -> void: get_tree().change_scene_to_file(Game.MAIN_MENU_SCENE))
	_input.paged.connect(_on_paged)
	add_child(_input)
	InputRouter.player_joined.connect(_on_players_changed.unbind(1))
	InputRouter.player_left.connect(_on_players_changed.unbind(1))
	# Вернулись из уровня другого мира — показываем его.
	if Game.world > 0 and Game.world < Levels.WORLDS.size() and Levels.is_world_unlocked(Game.world):
		world = Game.world
	_build()
	# Курсор — на уровне, откуда вернулись; если он пройден — на первом непройденном открытом после него.
	var start := Game.level_index if Game.world == world else 0
	while Progress.is_completed(world, start):
		var next := Levels.next_built(world, start)
		if next == -1 or not Progress.is_unlocked(world, next):
			break
		start = next
	_cursor = Vector2i(start / COLUMNS, start % COLUMNS)
	_refresh()


func _build() -> void:
	_cards.clear()
	_status = Label.new()
	_players_label = Label.new()
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	if BACKGROUNDS.has(world):
		var panorama := TextureRect.new()
		panorama.texture = load(BACKGROUNDS[world])
		panorama.set_anchors_preset(Control.PRESET_FULL_RECT)
		panorama.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		panorama.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(panorama)
		# Низ панорамы (туман) чуть светлее: подсказки внизу читаются, сетка не спорит с деталями.
		var veil := TextureRect.new()
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.0))
		gradient.set_color(1, Color(1, 1, 1, 0.45))
		var fade := GradientTexture2D.new()
		fade.gradient = gradient
		fade.fill_from = Vector2(0, 0.35)
		fade.fill_to = Vector2(0, 1)
		veil.texture = fade
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		veil.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(veil)

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

	# Под сеткой — миры: выбрать курсором или Q/E (комнаты прототипа в меню не показываются).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 20)
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tabs)
	for i in Levels.WORLDS.size():
		var card := _card(Vector2(CARD_SIZE.x + 80.0, 64))
		tabs.add_child(card)
		_cards[Vector2i(_tabs_row(), i)] = card

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_status.add_theme_font_size_override("font_size", 28)
	_status.add_theme_color_override("font_color", COLOR_TEXT)
	_outline(_status)
	_outline(_players_label)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_players_label.add_theme_font_size_override("font_size", 26)
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_players_label)
	var debug_hint := "" if Progress.playtest_open else " · F9 — открыть все уровни (отладка)"
	column.add_child(_label(
			"Стик, крестовина или стрелки — выбор · A / Enter / Пробел — играть · Q/E, LB/RB — другой мир%s · Esc — главное меню" % debug_hint,
			22, COLOR_MUTED))


## Листать миры: закрытый мир не открывается, курсор встаёт на первый уровень.
func _on_paged(direction: int) -> void:
	_switch_world(world + direction)


func _switch_world(target: int) -> void:
	if target < 0 or target >= Levels.WORLDS.size() or target == world:
		return
	if not Levels.is_world_unlocked(target):
		_status.text = "Мир %d «%s» откроется, когда пройден последний уровень мира %d." % [
				target + 1, Levels.WORLDS[target].title, target]
		return
	world = target
	for child in get_children():
		if child != _input:
			remove_child(child)
			child.queue_free()
	_build()
	_cursor = Vector2i.ZERO
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		Progress.set_unlock_all(not Progress.unlock_all)
		_refresh()


## Ряд карточек миров — под сеткой уровней.
func _tabs_row() -> int:
	return ceili(Levels.count(world) / float(COLUMNS))


## Мир и номер уровня под курсором (на карточке мира — WORLD_TAB и номер мира).
func _selection(cell: Vector2i) -> Vector2i:
	if cell.x == _tabs_row():
		return Vector2i(WORLD_TAB, cell.y)
	return Vector2i(world, cell.x * COLUMNS + cell.y)


func _on_moved(direction: Vector2i) -> void:
	var cell := _cursor + Vector2i(direction.y, direction.x)
	cell.x = clampi(cell.x, 0, _tabs_row())
	var row_length := Levels.WORLDS.size() if cell.x == _tabs_row() else COLUMNS
	cell.y = clampi(cell.y, 0, row_length - 1)
	if _cards.has(cell):
		_cursor = cell
		_refresh()


func _on_confirmed(device: int) -> void:
	# Нажатие, которым игрок только что подключился, уровень не запускает.
	if InputRouter.just_joined(device):
		return
	if not InputRouter.is_device_joined(device):
		_status.text = "Сначала подключитесь: A на геймпаде · W/Пробел или ↑/Enter на клавиатуре"
		return
	var target := _selection(_cursor)
	if target.x == WORLD_TAB:
		_switch_world(target.y)
		return
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
	if target.x == WORLD_TAB:
		_status.text = "Мир %d «%s»%s" % [target.y + 1, Levels.WORLDS[target.y].title,
				" — вы здесь" if target.y == world else " — выбрать: A / Enter"]
	else:
		var title: String = Levels.entry(target.x, target.y).title
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
	if target.x == WORLD_TAB:
		_paint_world(cell, card, target.y)
		return
	var built := Levels.is_built(target.x, target.y)
	var unlocked := built and Progress.is_unlocked(target.x, target.y)
	var done := target.x != Levels.EXTRAS_WORLD and Progress.is_completed(target.x, target.y)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	style.bg_color = COLOR_CARD if unlocked else COLOR_CARD.darkened(0.18)
	style.bg_color.a = 0.95 if unlocked else 0.9  # панорама мира чуть просвечивает
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
	number.text = "%02d" % (target.y + 1)
	title.text = entry.title
	state.text = "✓ пройден" if done else ("открыт" if unlocked else ("закрыт" if built else "скоро"))
	var text_color := COLOR_TEXT if unlocked else COLOR_MUTED
	for label in [number, title]:
		label.add_theme_color_override("font_color", text_color)
	state.add_theme_color_override("font_color", COLOR_DONE.darkened(0.3) if done else COLOR_MUTED)


## Карточка мира в нижнем ряду: текущий мир выделен цветом пройденного.
func _paint_world(cell: Vector2i, card: PanelContainer, index: int) -> void:
	var unlocked := Levels.is_world_unlocked(index)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.set_content_margin_all(8)
	style.bg_color = COLOR_CARD if unlocked else COLOR_CARD.darkened(0.18)
	style.bg_color.a = 0.95
	style.border_color = COLOR_DONE if index == world else (COLOR_TEXT if unlocked else COLOR_LOCKED)
	style.set_border_width_all(6 if index == world else 3)
	if cell == _cursor:
		style.border_color = COLOR_FOCUS
		style.set_border_width_all(10)
	card.add_theme_stylebox_override("panel", style)
	var number: Label = card.get_node("Box/Number")
	var title: Label = card.get_node("Box/Title")
	var state: Label = card.get_node("Box/State")
	number.visible = false
	state.visible = false
	title.text = "Мир %d · %s" % [index + 1, Levels.WORLDS[index].title]
	title.add_theme_color_override("font_color", COLOR_TEXT if unlocked else COLOR_MUTED)


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
	_outline(label)
	return label


static func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 10)
