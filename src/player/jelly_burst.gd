class_name JellyBurst
extends Node2D
## Эффекты гибели и появления мармеладного персонажа.
## Гибель: сплющился, глаза — крестиками, лопнул брызгами своего цвета; брызги падают, налипают
## на землю и стены кляксами и тают, на месте — облачко. Укладывается в паузу перед общим респавном (≈ 1 с).
## Появление: облачко-кольцо и искорки, сам персонаж «выпрыгивает» с перебором (PlayerSprite.pop_in).

const OUTLINE := Color("1a1d33")
const SQUASH := 0.14
const LIFETIME := 1.0
const GRAVITY := 1500.0
const DROPS := 11

var color := Color.WHITE
var appear := false
var _time := 0.0
var _drops: Array[Dictionary] = []


## Гибель игрока: эффект встаёт на его место, сам игрок уже скрыт.
static func burst(player: Player) -> void:
	_spawn(player, false)


## Появление игрока у чекпоинта.
static func pop(player: Player) -> void:
	_spawn(player, true)


static func _spawn(player: Player, is_appear: bool) -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var effect := JellyBurst.new()
	effect.color = player.color
	effect.appear = is_appear
	effect.z_index = 5
	parent.add_child(effect)
	effect.global_position = player.global_position + Vector2(0, Player.SIZE.y / 2.0 - 4.0)
	if not is_appear:
		for i in DROPS:
			var angle := -PI / 2.0 + randf_range(-1.25, 1.25)
			effect._drops.append({
				"pos": Vector2(randf_range(-14, 14), -26.0),
				"vel": Vector2.from_angle(angle) * randf_range(260.0, 560.0),
				"r": randf_range(5.0, 10.5),
			})


func _process(delta: float) -> void:
	_time += delta
	if _time >= (0.5 if appear else LIFETIME):
		queue_free()
		return
	if not appear and _time > SQUASH:
		var space := get_world_2d().direct_space_state
		var query := PhysicsPointQueryParameters2D.new()
		query.collision_mask = Player.LAYER_WORLD
		for drop in _drops:
			if drop.get("stuck", false):
				continue
			drop.vel = drop.vel + Vector2(0, GRAVITY * delta)
			var next: Vector2 = drop.pos + drop.vel * delta
			query.position = global_position + next
			if not space.intersect_point(query, 1).is_empty():
				# Налипла: клякса прижимается к поверхности, по которой ударилась.
				drop.stuck = true
				drop.splat = absf(drop.vel.y) >= absf(drop.vel.x)
				continue
			drop.pos = next
	queue_redraw()


func _draw() -> void:
	if appear:
		_draw_appear()
		return
	if _time < SQUASH:
		# Сплющивается: шире и ниже, глаза — крестиками.
		var k := _time / SQUASH
		var w := 24.0 * (1.0 + 0.6 * k)
		var h := 28.0 * (1.0 - 0.5 * k)
		var center := Vector2(0, -h)
		draw_set_transform(center, 0.0, Vector2(w, h) / 24.0)
		draw_circle(Vector2.ZERO, 27.0, OUTLINE)
		draw_circle(Vector2.ZERO, 24.0, color)
		draw_set_transform(Vector2.ZERO)
		for side: float in [-1.0, 1.0]:
			var eye := center + Vector2(side * 8.0, -h * 0.25)
			draw_line(eye + Vector2(-4, -4), eye + Vector2(4, 4), OUTLINE, 2.5)
			draw_line(eye + Vector2(-4, 4), eye + Vector2(4, -4), OUTLINE, 2.5)
		return
	var t := (_time - SQUASH) / (LIFETIME - SQUASH)
	# Облачко на месте: расходится и тает.
	var puff_alpha := clampf(1.0 - t * 2.2, 0.0, 1.0)
	if puff_alpha > 0.0:
		for i in 6:
			var angle := i * TAU / 6.0 + 0.4
			var p := Vector2.from_angle(angle) * (14.0 + 30.0 * t) + Vector2(0, -24)
			draw_circle(p, 13.0 * (1.0 - t * 0.6), Color(1, 1, 1, 0.75 * puff_alpha))
	# Брызги: капли цвета персонажа с контуром и бликом, к концу тают и сжимаются.
	var fade := clampf((1.0 - t) / 0.4, 0.0, 1.0)
	for drop in _drops:
		var r: float = drop.r * (0.5 + 0.5 * fade)
		if drop.get("stuck", false):
			# Клякса: приплюснута вдоль поверхности (пол — по горизонтали, стена — по вертикали).
			var flat := Vector2(1.6, 0.45) if drop.splat else Vector2(0.45, 1.6)
			draw_set_transform(drop.pos, 0.0, flat)
		else:
			var stretch := clampf(drop.vel.length() / 900.0, 0.0, 0.5)
			draw_set_transform(drop.pos, drop.vel.angle(), Vector2(1.0 + stretch, 1.0 - stretch * 0.5))
		draw_circle(Vector2.ZERO, r + 2.5, Color(OUTLINE, fade))
		draw_circle(Vector2.ZERO, r, Color(color, fade))
		draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.6 * fade))
	draw_set_transform(Vector2.ZERO)


func _draw_appear() -> void:
	var t := _time / 0.5
	var alpha := clampf(1.0 - t, 0.0, 1.0)
	var ring := 18.0 + 40.0 * t
	draw_arc(Vector2(0, -28), ring, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * alpha), 6.0 * (1.0 - t) + 1.0)
	for i in 8:
		var angle := i * TAU / 8.0
		var p := Vector2(0, -28) + Vector2.from_angle(angle) * (ring + 6.0)
		draw_circle(p, 3.5 * alpha + 0.5, Color(color.lightened(0.5), alpha))
