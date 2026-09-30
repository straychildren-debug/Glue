extends Node2D
## Корень игры: загружает уровень, создаёт игроков по мере подключения геймпадов,
## ведёт общий чекпоинт команды и респавн.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
## Уровни по порядку, затем комнаты прототипа. F2 переключает по кругу; пройденный уровень
## открывает следующий.
const LEVELS: Array[String] = [
	"res://levels/w01_l01_first_steps.tscn",
	"res://levels/w01_l02_lend_a_shoulder.tscn",
	"res://levels/w01_l03_dont_let_go.tscn",
	"res://levels/sandbox.tscn",
	"res://levels/test_room.tscn",
]
## Пауза между прохождением и загрузкой следующего уровня.
const NEXT_LEVEL_DELAY := 2.0

signal level_completed

## Номер комнаты из LEVELS; переживает перезапуск сцены по F2/F5.
static var level_index := 0

## Если задано (автотесты), грузится эта сцена вместо комнаты из LEVELS.
@export var level_scene: PackedScene

var level: GreyboxLevel
var players := {}  # slot -> Player
var completed := false
## Грузить ли следующий уровень после финиша (нет, если уровень задан автотестом).
var _advance_after_finish := false
var _team_respawning := false
var _title := Label.new()

@onready var _players_root: Node2D = $Players
@onready var _camera: SharedCamera = $SharedCamera
@onready var _hint: Label = $HUD/Hint


func _ready() -> void:
	var from_list := level_scene == null
	if from_list:
		level_scene = load(LEVELS[level_index])
	_advance_after_finish = from_list
	level = level_scene.instantiate()
	add_child(level)
	move_child(level, 0)
	_camera.set_bounds(level.get_bounds_px())
	_camera.snap_to(level.get_spawn_position(0, 0))
	_camera.targets_source = _alive_players
	add_child(GrabLinks.new())

	InputRouter.player_joined.connect(_on_player_joined)
	InputRouter.player_left.connect(_on_player_left)
	for slot in InputRouter.joined_slots():
		_on_player_joined(slot)
	_update_hint()

	_title.text = level.title
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18))
	# Справа сверху: слева подсказки управления.
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_title.offset_top = 16.0
	_title.offset_right = -24.0
	$HUD.add_child(_title)


func _physics_process(_delta: float) -> void:
	if _team_respawning or completed:
		return
	_check_finish()
	var kill_y := level.get_kill_y()
	for player: Player in players.values():
		if not player.alive:
			continue
		if player.global_position.y > kill_y:
			player.die()
			continue
		# Чекпоинт общий: его двигает вперёд любой живой игрок.
		var reached := level.checkpoint_at_x(player.global_position.x)
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
	if not _advance_after_finish:
		return
	await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
	level_index = (level_index + 1) % LEVELS.size()
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_F5:
				get_tree().reload_current_scene()
			KEY_F2:
				level_index = (level_index + 1) % LEVELS.size()
				get_tree().reload_current_scene()


func _alive_players() -> Array:
	return players.values().filter(func(p: Player) -> bool: return p.alive)


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
	if _team_respawning:
		return
	_team_respawning = true
	for other: Player in players.values():
		other.pause_for_respawn()
	await get_tree().create_timer(player.respawn_delay).timeout
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
		lines.append("Подключиться: A на геймпаде · W/Пробел или ↑/Enter на клавиатуре")
	lines.append("Геймпад: A — прыжок · X или LB — замри · RB или RT (держать) — хват · стик у замершего — наклон/катапульта")
	lines.append("Back — выйти из игры игроку · F2 — следующий уровень · F5 — перезапуск · Esc — выход")
	_hint.text = "\n".join(lines)
