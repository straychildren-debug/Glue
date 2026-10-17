class_name MainMenu
extends Control
## Главное меню — с него начинается игра: «История» (уровни подряд через все миры, вступительный
## мультик), «Выбор уровня» (любой уровень), «Настройки» (звук, экран, клавиши), «Выход».
## Управление: мышь, стрелки и Enter / Esc, геймпад (крестовина или стик, A / B) — стандартные
## действия Godot ui_*. Страницы меню — колонки кнопок в одной панели.

const BACKGROUND := "res://assets/backgrounds/menu/source/menu_panorama.png"
const HEROES := ["red", "blue", "yellow", "green"]
const HERO_SHEET := "res://assets/characters/v2/%s_full.png"
const HERO_CELL := 256
const HERO_FRAMES := 8
const COLOR_TEXT := Color("1f2329")
const COLOR_MUTED := Color("5b6470")
const COLOR_CARD := Color("f4efe2")
const COLOR_FOCUS := Color("f2c230")
const COLOR_ACCENT := Color("c2410c")

enum Page { MAIN, STORY, SETTINGS, CONTROLS }

var _page := Page.MAIN
var _column := VBoxContainer.new()
var _caption := Label.new()
var _status := Label.new()
var _background := TextureRect.new()
var _heroes: Array[TextureRect] = []
var _time := 0.0
## Переназначение клавиши: [раскладка, действие, кнопка] или пусто.
var _rebinding: Array = []


func _ready() -> void:
	get_tree().paused = false
	Game.story = false
	GameSettings.apply_on_start()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_show(Page.MAIN)


func _process(delta: float) -> void:
	_time += delta
	# Задник медленно плывёт, герои дышат (кадры покоя из листа персонажа).
	_background.position = Vector2(-60.0 + 60.0 * sin(_time * 0.05), -30.0 + 20.0 * cos(_time * 0.07))
	for i in _heroes.size():
		var atlas := _heroes[i].texture as AtlasTexture
		var frame := int(_time * 8.0 + i * 3) % HERO_FRAMES
		atlas.region = Rect2(frame * HERO_CELL, 0, HERO_CELL, HERO_CELL)


func _build() -> void:
	var sky := ColorRect.new()
	sky.color = Color("c9d9e8")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	_background.texture = load(BACKGROUND)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.size = Vector2(2040, 1150)
	add_child(_background)
	# Слева светлая вуаль под меню, чтобы кнопки читались поверх задника.
	var veil := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.98, 0.94, 0.78))
	gradient.set_color(1, Color(1, 0.98, 0.94, 0.0))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0.0, 0.5)
	fade.fill_to = Vector2(0.62, 0.5)
	veil.texture = fade
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	# Четверо героев — три брата и сестрёнка — стоят внизу справа.
	for i in HEROES.size():
		var atlas := AtlasTexture.new()
		atlas.atlas = load(HERO_SHEET % HEROES[i])
		atlas.region = Rect2(0, 0, HERO_CELL, HERO_CELL)
		var hero := TextureRect.new()
		hero.texture = atlas
		hero.size = Vector2(230, 230)
		hero.position = Vector2(1040 + i * 190, 790 - (i % 2) * 18)
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hero)
		_heroes.append(hero)

	var title := _label("Держись!", 150, COLOR_TEXT)
	title.position = Vector2(120, 70)
	add_child(title)
	var subtitle := _label("Спасти короля бобов", 44, COLOR_ACCENT)
	subtitle.position = Vector2(130, 250)
	add_child(subtitle)

	_caption.position = Vector2(130, 340)
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_color", COLOR_MUTED)
	_outline(_caption)
	add_child(_caption)
	_column.position = Vector2(120, 400)
	_column.add_theme_constant_override("separation", 14)
	add_child(_column)
	_status.position = Vector2(130, 1000)
	_status.add_theme_font_size_override("font_size", 26)
	_status.add_theme_color_override("font_color", COLOR_MUTED)
	_outline(_status)
	add_child(_status)


## Страница меню: колонка кнопок заново, фокус — на первой.
func _show(page: Page) -> void:
	_page = page
	_rebinding = []
	for hero in _heroes:
		hero.visible = page != Page.CONTROLS  # широкая сетка клавиш заходит на их место
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_status.text = "Стрелки или стик — выбор · Enter / A — да · Esc / B — назад"
	match page:
		Page.MAIN:
			_caption.text = ""
			_button("История", _show.bind(Page.STORY))
			_button("Выбор уровня", func() -> void: get_tree().change_scene_to_file(Game.MENU_SCENE))
			_button("Настройки", _show.bind(Page.SETTINGS))
			_button("Выход", func() -> void: get_tree().quit())
		Page.STORY:
			_caption.text = "Три брата и сестрёнка идут за королём"
			var at := Progress.story_position()
			if at.x >= 0 and Levels.is_built(at.x, at.y):
				_button("Продолжить: %s · %s" % [Levels.WORLDS[at.x].title, Levels.entry(at.x, at.y).title],
						func() -> void: Game.play_story(get_tree(), at.x, at.y))
			elif at.x == -2:
				_button("История пройдена — продолжение следует", func() -> void: pass).disabled = true
			_button("Новая история", _new_story)
			_button("Смотреть вступление", func() -> void: Cutscene.open(get_tree(), Cutscene.Then.MENU))
			_button("Назад", _show.bind(Page.MAIN))
		Page.SETTINGS:
			_caption.text = "Настройки"
			_value_button(_volume_text, _change_volume)
			_value_button(_screen_text, func(_step: int) -> void:
				GameSettings.fullscreen = not GameSettings.fullscreen
				GameSettings.apply_screen())
			_value_button(_size_text, _change_size)
			_button("Управление", _show.bind(Page.CONTROLS))
			_button("Назад", _back)
		Page.CONTROLS:
			_caption.text = "Клавиатура: выберите действие и нажмите новую клавишу"
			# две колонки: игрок 1 и игрок 2, по строке на действие
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 18)
			grid.add_theme_constant_override("v_separation", 12)
			_column.add_child(grid)
			for action in GameSettings.ACTIONS:
				for keyboard in [InputRouter.KEYBOARD_1, InputRouter.KEYBOARD_2]:
					var button := _button("", func() -> void: pass, grid)
					button.custom_minimum_size = Vector2(560, 64)
					button.add_theme_font_size_override("font_size", 32)
					button.pressed.connect(_start_rebind.bind(keyboard, action, button))
					_key_text(button, keyboard, action)
			_button("Сбросить по умолчанию", func() -> void:
				InputRouter.reset_keys()
				_show(Page.CONTROLS))
			_button("Назад", _back)
			_status.text = "Геймпад: A — прыжок · X или LB — замри · RB или RT — хват · Start — пауза"
	var first: Control = _column.get_child(0)
	if first is GridContainer:
		first = first.get_child(0)
	if first is Button:
		first.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not _rebinding.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_back()


func _input(event: InputEvent) -> void:
	# Ожидание новой клавиши: первая нажатая — новая основная, Esc — отмена.
	if _rebinding.is_empty() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	var keyboard: int = _rebinding[0]
	var action: String = _rebinding[1]
	var button: Button = _rebinding[2]
	_rebinding = []
	if event.physical_keycode != KEY_ESCAPE:
		InputRouter.set_key(keyboard, action, event.physical_keycode)
		GameSettings.save()
	_key_text(button, keyboard, action)
	button.grab_focus()


func _back() -> void:
	match _page:
		Page.STORY, Page.SETTINGS:
			GameSettings.save()
			_show(Page.MAIN)
		Page.CONTROLS:
			GameSettings.save()
			_show(Page.SETTINGS)


func _new_story() -> void:
	var worlds := Levels.story_worlds()
	var first := Levels.next_built(worlds[0], -1)
	Progress.set_story_position(Vector2i(worlds[0], first))
	Cutscene.open(get_tree(), Cutscene.Then.STORY)


func _start_rebind(keyboard: int, action: String, button: Button) -> void:
	_rebinding = [keyboard, action, button]
	button.text = "Игрок %d · %s: нажмите клавишу…" % [-keyboard, GameSettings.ACTION_NAMES[action]]


func _key_text(button: Button, keyboard: int, action: String) -> void:
	button.text = "Игрок %d · %s: %s" % [-keyboard, GameSettings.ACTION_NAMES[action], InputRouter.key_name(keyboard, action)]


func _volume_text() -> String:
	return "Громкость: ◀ %d%% ▶" % roundi(GameSettings.volume * 100.0)


func _screen_text() -> String:
	return "Экран: %s" % ("полный" if GameSettings.fullscreen else "окно")


func _size_text() -> String:
	return "Размер окна: ◀ %d × %d ▶" % [GameSettings.window_size.x, GameSettings.window_size.y]


func _change_volume(step: int) -> void:
	GameSettings.volume = clampf(snappedf(GameSettings.volume + 0.1 * step, 0.1), 0.0, 1.0)
	GameSettings.apply_volume()


func _change_size(step: int) -> void:
	var sizes := GameSettings.WINDOW_SIZES
	var at := maxi(sizes.find(GameSettings.window_size), 0)
	GameSettings.window_size = sizes[posmod(at + step, sizes.size())]
	GameSettings.apply_screen()


## Кнопка-значение: Enter / клик — шаг вперёд, ◀ ▶ — шаг назад / вперёд; текст обновляется.
func _value_button(text: Callable, change: Callable) -> Button:
	var button := _button(text.call(), func() -> void: pass)
	var step_to := func(step: int) -> void:
		change.call(step)
		button.text = text.call()
	button.pressed.connect(step_to.bind(1))
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			step_to.call(-1)
			button.accept_event()
		elif event.is_action_pressed("ui_right"):
			step_to.call(1)
			button.accept_event())
	return button


func _button(text: String, action: Callable, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(760, 74)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 38)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_CARD if state != "disabled" else Color(COLOR_CARD, 0.6)
		style.border_color = COLOR_FOCUS if state in ["focus", "hover"] else Color("3a3f47")
		style.set_border_width_all(6 if state in ["focus", "hover"] else 3)
		style.set_corner_radius_all(16)
		style.content_margin_left = 28
		style.content_margin_right = 28
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_ACCENT)
	button.add_theme_color_override("font_focus_color", COLOR_ACCENT)
	button.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	button.pressed.connect(action)
	button.mouse_entered.connect(button.grab_focus)
	(parent if parent != null else _column).add_child(button)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_outline(label)
	return label


static func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.97, 0.9))
	label.add_theme_constant_override("outline_size", 12)
