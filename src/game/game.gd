extends Node2D
## Корень игры: загружает уровень, создаёт игроков по мере подключения геймпадов,
## ведёт общий чекпоинт команды и респавн.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
## Комнаты прототипа, F2 переключает по кругу.
const LEVELS: Array[String] = ["res://levels/sandbox.tscn", "res://levels/test_room.tscn"]

## Номер комнаты из LEVELS; переживает перезапуск сцены по F2/F5.
static var level_index := 0

## Если задано (автотесты), грузится эта сцена вместо комнаты из LEVELS.
@export var level_scene: PackedScene

var level: GreyboxLevel
var players := {}  # slot -> Player
var _team_respawning := false

@onready var _players_root: Node2D = $Players
@onready var _camera: SharedCamera = $SharedCamera
@onready var _hint: Label = $HUD/Hint


func _ready() -> void:
	if level_scene == null:
		level_scene = load(LEVELS[level_index])
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


func _physics_process(_delta: float) -> void:
	if _team_respawning:
		return
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


## Новый игрок появляется на голове уже играющего, чтобы не оказаться за краем кадра.
func _join_position(slot: int) -> Vector2:
	var alive := _alive_players()
	if alive.is_empty():
		return level.get_spawn_position(level.active_checkpoint, slot)
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
	lines.append("Back — выйти из игры игроку · F2 — другая комната · F5 — перезапуск · Esc — выход")
	_hint.text = "\n".join(lines)
