@tool
class_name DoorKey
extends Node2D
## Ключ, как в Pico Park: висит в воздухе, подбирается касанием и летит следом за носителем.
## Товарищ перехватывает ключ, коснувшись его самого (ключ летит за спиной носителя).
## Носитель, подошедший к замку (KeyLock), отдаёт ключ — замок открывается навсегда.
## Ничего не весит и сквозь стены не мешает. При общем респавне — состояние на чекпоинте.
## Положение узла — где ключ висит, пока его не взяли.

const GROUP := "keys"
## Касание: ключ ближе этого (px) к телу игрока.
const TOUCH := 22.0
## После смены носителя ключ какое-то время нельзя перехватить — без «пинг-понга».
const HANDOFF_COOLDOWN := 0.6
## Где ключ летит относительно носителя: за спиной и над головой.
const FOLLOW_OFFSET := Vector2(-34, -46)
const FOLLOW_SPEED := 10.0

var carrier: Player = null
var used := false
var _home := Vector2.ZERO
var _cooldown := 0.0
var _bob := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(GreyboxLevel.RESETTABLE)
	_home = position
	z_index = 2  # поверх игроков: ключ должно быть видно всегда
	process_physics_priority = 30  # после игроков


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or used:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_bob += delta
	if carrier != null and (not is_instance_valid(carrier) or not carrier.alive):
		carrier = null
	if carrier != null:
		var target := carrier.global_position + Vector2(FOLLOW_OFFSET.x * carrier.facing, FOLLOW_OFFSET.y)
		global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	else:
		position = position.lerp(_home, 1.0 - exp(-FOLLOW_SPEED * delta))
	if _cooldown <= 0.0:
		for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
			if player != carrier and player.alive and _touches(player):
				carrier = player
				_cooldown = HANDOFF_COOLDOWN
				break
	queue_redraw()


func _touches(player: Player) -> bool:
	var body := Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE).grow(TOUCH)
	return body.has_point(global_position)


## Замок забирает ключ.
func use() -> void:
	used = true
	carrier = null
	visible = false


func save_state() -> Variant:
	return {"used": used, "slot": carrier.slot if carrier != null else -1, "position": position}


func load_state(state: Variant) -> void:
	used = state.used
	visible = not used
	carrier = null
	position = _home
	if state.slot >= 0:
		for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
			if player.slot == state.slot and player.alive:
				carrier = player
				global_position = player.global_position + FOLLOW_OFFSET
	_cooldown = HANDOFF_COOLDOWN


func _draw() -> void:
	# Покачивание, пока ключ ждёт; у носителя — ровно.
	var lift := 0.0 if carrier != null else sin(_bob * 3.0) * 4.0
	var outline := Color("1a1d33")
	var gold := Color("f2c230")
	var shine := Color("ffe58a")
	var o := Vector2(0, lift)
	# Контур (интерактивное обведено), затем заливка: кольцо головки, стержень, бородка.
	for pass_index in 2:
		var grow := 3.0 if pass_index == 0 else 0.0
		var fill := outline if pass_index == 0 else gold
		draw_circle(o + Vector2(-14, 0), 11.0 + grow, fill)
		draw_rect(Rect2(o + Vector2(-6, -3.5 - grow), Vector2(26 + grow, 7 + grow * 2)), fill)
		draw_rect(Rect2(o + Vector2(12 - grow, 0), Vector2(5 + grow * 2, 11 + grow)), fill)
		draw_rect(Rect2(o + Vector2(4 - grow, 0), Vector2(5 + grow * 2, 8 + grow)), fill)
	draw_circle(o + Vector2(-14, 0), 5.0, outline)
	draw_circle(o + Vector2(-18, -4), 2.5, shine)
	draw_line(o + Vector2(-4, -2), o + Vector2(16, -2), shine, 1.5)
