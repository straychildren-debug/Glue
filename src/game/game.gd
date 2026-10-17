class_name Game
extends Node2D
## Корень игры: загружает уровень, создаёт игроков по мере подключения геймпадов,
## ведёт общий чекпоинт команды и респавн. Пройденный уровень записывается в прогресс
## и открывает следующий; после последнего собранного уровня мира — возврат в меню.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MENU_SCENE := "res://src/menu/level_select.tscn"
const MAIN_MENU_SCENE := "res://src/menu/main_menu.tscn"
const GAME_SCENE := "res://src/game/game.tscn"
## Пауза между прохождением и загрузкой следующего уровня.
const NEXT_LEVEL_DELAY := 2.0

signal level_completed

## Что играем: мир и номер уровня в нём (Levels.EXTRAS_WORLD — комнаты прототипа).
## Переживает перезапуск сцены.
static var world := 0
static var level_index := 0

## Если задано (автотесты), грузится эта сцена вместо уровня из каталога.
@export var level_scene: PackedScene

var level: GreyboxLevel
var players := {}  # slot -> Player
var completed := false
## Записывать прогресс и грузить следующий уровень после финиша (нет, если уровень задан автотестом).
var _from_catalog := false
var _team_respawning := false
var _title := Label.new()
## Плашка подсказки внизу экрана: текст таблички (HintSign), у которой стоит кто-то из игроков.
var _sign_banner := PanelContainer.new()
var _sign_label := Label.new()

@onready var _players_root: Node2D = $Players
@onready var _camera: SharedCamera = $SharedCamera
@onready var _hint: Label = $HUD/Hint
@onready var _pause: PauseMenu = $PauseMenu


## Запускает уровень из каталога (из меню или по F2).
static func play(tree: SceneTree, p_world: int, p_index: int) -> void:
	world = p_world
	level_index = p_index
	tree.paused = false
	tree.change_scene_to_file(GAME_SCENE)


## Режим «История»: уровни подряд через все миры (Levels.story_next), место — в Progress.
static var story := false


## Начинает или продолжает историю с уровня (мир, номер).
static func play_story(tree: SceneTree, p_world: int, p_index: int) -> void:
	story = true
	Progress.set_story_position(Vector2i(p_world, p_index))
	play(tree, p_world, p_index)


## Выход из уровня: из истории — в главное меню, иначе — к выбору уровня.
static func open_menu(tree: SceneTree) -> void:
	tree.paused = false
	tree.change_scene_to_file(MAIN_MENU_SCENE if story else MENU_SCENE)
	story = false


func _ready() -> void:
	_from_catalog = level_scene == null
	if _from_catalog:
		if not Levels.is_built(world, level_index):
			world = 0
			level_index = 0
		level_scene = load(Levels.scene_path(world, level_index))
	level = level_scene.instantiate()
	add_child(level)
	move_child(level, 0)
	_camera.set_bounds(level.get_bounds_px())
	_camera.snap_to(level.get_spawn_position(0, 0))
	_camera.targets_source = _camera_targets
	add_child(GrabLinks.new())

	InputRouter.player_joined.connect(_on_player_joined)
	InputRouter.player_left.connect(_on_player_left)
	InputRouter.pause_requested.connect(_open_pause)
	for slot in InputRouter.joined_slots():
		_on_player_joined(slot)
	_update_hint()
	_pause.chosen.connect(_on_pause_chosen)

	_title.text = level.title
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18))
	# Светлая обводка: надписи читаются и поверх веток переднего плана, и на тёмных задниках.
	for label: Label in [_title, _hint]:
		label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.97, 0.85))
		label.add_theme_constant_override("outline_size", 8)
	# Справа сверху: слева подсказки управления.
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_title.offset_top = 16.0
	_title.offset_right = -24.0
	$HUD.add_child(_title)
	_build_sign_banner()


func _build_sign_banner() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.92, 0.94)
	style.border_color = Color("1a1d33")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_sign_banner.add_theme_stylebox_override("panel", style)
	_sign_label.add_theme_font_size_override("font_size", 32)
	_sign_label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18))
	_sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign_banner.add_child(_sign_label)
	_sign_banner.modulate.a = 0.0
	_sign_banner.visible = false
	$HUD.add_child(_sign_banner)


func _process(delta: float) -> void:
	_update_sign_banner(delta)


## Подсказка ближайшей таблички, у которой стоит кто-то из живых игроков; плавно проявляется и гаснет.
func _update_sign_banner(delta: float) -> void:
	var shown: Node2D = null
	var best := INF
	for sign: Node2D in get_tree().get_nodes_in_group("hint_signs"):  # HintSign.GROUP
		for player: Player in players.values():
			if player.alive and sign.is_near(player.global_position):
				var distance := player.global_position.distance_to(sign.global_position)
				if distance < best:
					best = distance
					shown = sign
	if shown != null and _sign_label.text != shown.text:
		_sign_label.text = shown.text
		_sign_banner.reset_size()
	var target := 1.0 if shown != null else 0.0
	_sign_banner.modulate.a = move_toward(_sign_banner.modulate.a, target, delta * 4.0)
	_sign_banner.visible = _sign_banner.modulate.a > 0.0
	if _sign_banner.visible:
		var screen := get_viewport().get_visible_rect().size
		_sign_banner.position = Vector2((screen.x - _sign_banner.size.x) / 2.0, screen.y - _sign_banner.size.y - 40.0)


func _physics_process(_delta: float) -> void:
	if _team_respawning or completed:
		return
	_check_finish()
	var kill_y := level.get_kill_y()
	for player: Player in players.values():
		if player.alive and player.global_position.y > kill_y:
			player.die()
	# Чекпоинт общий и берётся, только когда до него дошли все: иначе ушедший вперёд брал
	# чекпоинт за препятствием, а оставшийся «переходил» нарочной гибелью (решение 57).
	if _team_respawning or players.is_empty():
		return
	var reached := level.checkpoints.size()
	for player: Player in players.values():
		if not player.alive:
			return
		reached = mini(reached, level.checkpoint_at_x(player.global_position.x))
	if reached > level.active_checkpoint:
		level.active_checkpoint = reached
		level.save_checkpoint_state()


## Уровень пройден, когда все игроки живы и стоят в двери финиша.
func _check_finish() -> void:
	var finish := level.get_finish()
	if finish == null:
		return
	var inside := 0
	for player: Player in players.values():
		if player.alive and finish.contains(player):
			inside += 1
	finish.needed = players.size()
	finish.inside = inside
	if players.is_empty() or inside < players.size():
		return
	completed = true
	_title.text = "%s — пройден!" % level.title
	level_completed.emit()
	if not _from_catalog:
		return
	Progress.mark_completed(world, level_index)
	if story:
		# История: следующий уровень — дальше в мире или первый следующего мира.
		var step := Levels.story_next(world, level_index)
		Progress.set_story_position(step if step.x >= 0 else Vector2i(-2, -2))
		await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
		if step.x < 0:
			open_menu(get_tree())
		else:
			play(get_tree(), step.x, step.y)
		return
	await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
	var next := Levels.next_built(world, level_index) if world != Levels.EXTRAS_WORLD else -1
	if next == -1:
		open_menu(get_tree())
	else:
		play(get_tree(), world, next)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_open_pause()
			KEY_F5:
				get_tree().reload_current_scene()
			KEY_F2:
				var next := Levels.debug_next(world, level_index)
				play(get_tree(), next.x, next.y)
			KEY_F3:
				# Отладка: графика из Blender ↔ серые прямоугольники с хитбоксами.
				Art.enabled = not Art.enabled
				Art.redraw_all(self)


func _open_pause() -> void:
	if not _pause.visible and _from_catalog:
		_pause.open()


func _on_pause_chosen(action: PauseMenu.Action) -> void:
	match action:
		PauseMenu.Action.CHECKPOINT:
			restart_from_checkpoint()
		PauseMenu.Action.RESTART:
			get_tree().reload_current_scene()
		PauseMenu.Action.MENU:
			open_menu(get_tree())
		PauseMenu.Action.QUIT:
			get_tree().quit()


## Команда сама возвращается к чекпоинту (если застряла) — как общий респавн, но без паузы.
func restart_from_checkpoint() -> void:
	if not _team_respawning and not completed:
		_respawn_team(0.0)


func _alive_players() -> Array:
	return players.values().filter(func(p: Player) -> bool: return p.alive)


## Камера держит в кадре живых игроков и подсказки механизмов (край подошедшего обвала).
func _camera_targets() -> Array:
	var targets := _alive_players()
	if targets.is_empty():
		return targets
	for hint in get_tree().get_nodes_in_group(Crusher.GROUP):
		var point: Node2D = hint.camera_target()
		if point != null:
			targets.append(point)
	return targets


func _on_player_joined(slot: int) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(slot)
	player.position = _join_position(slot)
	player.died.connect(_on_player_died)
	_players_root.add_child(player)
	players[slot] = player
	_update_hint()


func _on_player_left(slot: int) -> void:
	if players.has(slot):
		players[slot].queue_free()
		players.erase(slot)
	_update_hint()


## Новый игрок встаёт у чекпоинта рядом с остальными. Если команда уже ушла и чекпоинт
## за кадром — появляется на голове уже играющего, чтобы не оказаться за стеной кадра.
func _join_position(slot: int) -> Vector2:
	var spawn := level.get_spawn_position(level.active_checkpoint, slot)
	var alive := _alive_players()
	if alive.is_empty() or _camera.get_view_rect().grow(-Player.SIZE.x).has_point(spawn):
		return spawn
	return alive[0].global_position + Vector2(0, -Player.SIZE.y - 8.0)


## Гибель любого игрока — общий респавн команды: упавший исчезает, остальные замирают,
## через respawn_delay все появляются у активного чекпоинта.
func _on_player_died(player: Player) -> void:
	_respawn_team(player.respawn_delay)


func _respawn_team(delay: float) -> void:
	if _team_respawning:
		return
	_team_respawning = true
	for other: Player in players.values():
		other.pause_for_respawn()
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	# Сначала камера: стены кадра переезжают к чекпоинту. Физика видит их новое место только
	# со следующего кадра, иначе старая стена вытолкнет появившихся игроков.
	_camera.snap_to(level.get_spawn_position(level.active_checkpoint, 0))
	await get_tree().physics_frame
	for other: Player in players.values():
		other.respawn(level.get_spawn_position(level.active_checkpoint, other.slot))
	_camera.snap_to(level.get_spawn_position(level.active_checkpoint, 0))
	# Механизмы — после игроков: иначе стоявший на защёлке успел бы нажать её снова.
	level.restore_checkpoint_state()
	_team_respawning = false


func _update_hint() -> void:
	var lines: Array[String] = []
	for slot in InputRouter.joined_slots():
		lines.append("%s — %s" % [Player.COLOR_NAMES[slot], InputRouter.device_name(slot)])
	if players.size() < InputRouter.MAX_PLAYERS:
		lines.append("Подключиться: A на геймпаде · %s или %s на клавиатуре" % [
				InputRouter.key_name(InputRouter.KEYBOARD_1, "jump"), InputRouter.key_name(InputRouter.KEYBOARD_2, "jump")])
	lines.append("Геймпад: A — прыжок · X или LB — замри · RB или RT (держать) — хват · стик у замершего — наклон/катапульта")
	lines.append("Start или Esc — пауза: рестарт с чекпоинта, выбор уровня · Back — выйти игроку · F2 — следующий уровень · F3 — серые прямоугольники · F5 — заново")
	_hint.text = "\n".join(lines)
