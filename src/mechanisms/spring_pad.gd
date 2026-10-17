@tool
class_name SpringPad
extends StaticBody2D
## Пружинный батут (M2.2): кто приземлился на него, того подбрасывает — тем выше, чем с большей
## высоты упал (но не ниже BASE и не выше MAX). Прыжок на месте на батуте выше обычного,
## прыжок сверху — ещё выше. Ящики и жуки подпрыгивают так же.
## Замерший на батуте сжимает пружину до упора; ожил — выстрел CHARGED: улетает он сам
## и все, кто стоит на нём. Так замерший — «взведённая пружина» для себя и товарища.
## Положение узла — середина батута на уровне пола.

const OUTLINE := Color("1a1d33")
const HEIGHT := 22.0
## Скаты по бокам, px.
const RAMP := 40.0
## Приземление медленнее этого (px/с) — просто встал, без отскока.
const MIN_LANDING := 150.0
## Скорость отскока: доля скорости падения, нижний и верхний пределы, px/с.
const RESTITUTION := 0.95
const BASE := 980.0
const MAX := 1500.0
## Выстрел взведённой пружины, px/с (≈ 7,3 тайла вверх).
const CHARGED := 1500.0
const RIDER_BONUS := 60.0

@export var width_tiles := 1.5:
	set(value):
		width_tiles = value
		queue_redraw()

var _charged_by: Player = null
var _squash := 0.0  # 0 — пружина свободна, 1 — сжата до упора


func _ready() -> void:
	# Трапеция со скатами по краям: на батут можно зайти пешком (тогда он не подбрасывает).
	var half := width_tiles * GreyboxLevel.TILE / 2.0 - 4.0
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([Vector2(-half - RAMP, 0), Vector2(-half, -HEIGHT),
			Vector2(half, -HEIGHT), Vector2(half + RAMP, 0)])
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	if Engine.is_editor_hint():
		return
	add_to_group(GreyboxLevel.RESETTABLE)
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	process_physics_priority = 20  # после игроков и ящиков: их приземление в этом кадре известно


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var loaded := false
	for body: Node in get_tree().get_nodes_in_group(Weight.GROUP):
		if not body is PhysicsBody2D or (body is Player and not body.alive):
			continue
		var frozen_player: bool = body is Player and body.frozen
		var on_pad: bool = Weight.probe_below(body) == self if frozen_player else Weight.floor_below(body) == self
		if not on_pad:
			continue
		loaded = true
		if frozen_player:
			_charged_by = body
		elif body.landing_speed > MIN_LANDING:
			var bounce := clampf(body.landing_speed * RESTITUTION, BASE, MAX)
			# Игрок сохраняет разгон; ящик и жук подлетают строго вверх — прыгают на месте,
			# а не уплывают с батута (снести ящик может порыв мехов).
			var vx: float = body.velocity.x if body is Player else 0.0
			body.launch(Vector2(vx, -bounce))
			_squash = 1.0
	# Взведённая пружина: замерший ожил, стоя на батуте, — выстрел.
	if _charged_by != null:
		var player := _charged_by
		if not player.alive:
			_charged_by = null
		elif not player.frozen:
			_charged_by = null
			if Weight.probe_below(player) == self:
				var riders := Weight.stack_on(player)
				player.launch(Vector2(0.0, -CHARGED))
				# Стоящие сверху летят чуть быстрее и на время проходят сквозь нижнего:
				# иначе нижний, двигаясь первым, упирается в них и теряет взлёт.
				for rider: Node in riders:
					if rider.has_method("launch"):
						rider.launch(Vector2(0.0, -CHARGED - RIDER_BONUS))
					if rider is Player:
						player._pass_through(rider)
				_squash = 1.0
	var target := 1.0 if _charged_by != null else (0.35 if loaded else 0.0)
	_squash = move_toward(_squash, target, delta * 6.0)
	queue_redraw()


## Взведена ли пружина (на ней замер игрок).
func is_charged() -> bool:
	return _charged_by != null


func save_state() -> Variant:
	return null


func load_state(_state: Variant) -> void:
	_charged_by = null
	_squash = 0.0


func _draw() -> void:
	var w := width_tiles * GreyboxLevel.TILE - 8.0
	var top := -HEIGHT + _squash * 8.0
	if Art.enabled and Art.has("spring_pad"):
		# Батут P20 со скатами: свободный приседает, сжатый до упора — свой рисунок;
		# взведённый — потеплее (пружина держит товарища).
		var down := _squash > 0.7
		var sprite := Art.tex("spring_pad_down" if down else "spring_pad")
		var size := Vector2(w + 2.0 * RAMP, sprite.get_height() / 4.0)
		if not down:
			size.y *= 1.0 - 0.3 * _squash
		var tint := Color(1.0, 0.8, 0.65) if _charged_by != null else Color.WHITE
		draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, -size.y + 0.75), size), false, tint)
		return
	# Основание, пружина-зигзаг и крышка: крышка опускается, когда пружина сжата.
	for side: float in [-1.0, 1.0]:
		var base := PackedVector2Array([Vector2(side * w / 2.0, 0), Vector2(side * (w / 2.0 + RAMP), 0), Vector2(side * w / 2.0, -HEIGHT)])
		draw_colored_polygon(base, OUTLINE)
		draw_colored_polygon(PackedVector2Array([base[0] + Vector2(-side * 2.0, -2), base[1] + Vector2(-side * 6.0, -2), base[2] + Vector2(-side * 2.0, 5)]), Color("8a6a45"))
	draw_rect(Rect2(-w / 2.0, -8.0, w, 8.0), OUTLINE)
	draw_rect(Rect2(-w / 2.0 + 3.0, -6.0, w - 6.0, 5.0), Color("8a6a45"))
	var coil := PackedVector2Array()
	var turns := 4
	for i in turns * 2 + 1:
		var t := float(i) / (turns * 2)
		var y := lerpf(-8.0, top + 6.0, t)
		coil.append(Vector2((w * 0.28) * (1.0 if i % 2 == 0 else -1.0), y))
	draw_polyline(coil, OUTLINE, 7.0)
	draw_polyline(coil, Color("9aa3ad"), 3.5)
	draw_rect(Rect2(-w / 2.0, top, w, 9.0), OUTLINE)
	draw_rect(Rect2(-w / 2.0 + 3.0, top + 2.0, w - 6.0, 5.0), Color("c2410c") if _charged_by != null else Color("e0a040"))
