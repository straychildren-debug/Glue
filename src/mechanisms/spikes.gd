@tool
class_name Spikes
extends Node2D
## Шипы: касание — гибель (общий респавн команды). Шипы не твёрдые — это зона над полом.
## Замерший — камень: шипы ему не страшны. Прыгнуть в шипы и замереть до касания — и стать
## мостом, по голове которого пройдёт товарищ. Ожил в шипах — погиб.
## Ящики шипам безразличны. Положение узла — середина основания шипов на уровне пола.

const HEIGHT := 30.0
## Насколько тело игрока должно зайти в шипы, чтобы уколоться (px): касание краем не считается.
const BITE := 4.0
const TOOTH := 22.0

@export var width_tiles := 2.0:
	set(value):
		width_tiles = value
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		process_physics_priority = 15  # после движения игроков


func get_rect() -> Rect2:
	var width := width_tiles * GreyboxLevel.TILE
	return Rect2(global_position + Vector2(-width / 2.0, -HEIGHT), Vector2(width, HEIGHT))


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var zone := get_rect().grow(-BITE)
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if player.alive and not player.frozen \
				and zone.intersects(Rect2(player.global_position - Player.SIZE / 2.0, Player.SIZE)):
			player.die()


func _draw() -> void:
	var width := width_tiles * GreyboxLevel.TILE
	var count := maxi(1, int(round(width / TOOTH)))
	var step := width / count
	var outline := Color("1a1d33")
	var steel := Color("dfe4ea")
	var shade := Color("8f98a6")
	var tip_color := Color("e5484d")
	# Основание — тёмная планка; на ней ряд крупных стальных зубьев с толстым контуром,
	# бликом слева и красными кончиками: опасное должно бросаться в глаза.
	draw_rect(Rect2(-width / 2.0 - 3.0, -7.0, width + 6.0, 9.0), outline)
	for i in count:
		var x0 := -width / 2.0 + i * step
		var tip := Vector2(x0 + step / 2.0, -HEIGHT)
		var base_l := Vector2(x0 + 1.0, -4.0)
		var base_r := Vector2(x0 + step - 1.0, -4.0)
		draw_colored_polygon(PackedVector2Array([base_l + Vector2(-3, 3), tip + Vector2(0, -5), base_r + Vector2(3, 3)]), outline)
		draw_colored_polygon(PackedVector2Array([base_l, tip, base_r]), shade)
		draw_colored_polygon(PackedVector2Array([base_l, tip, Vector2(tip.x, -4.0)]), steel)
		var cut := 0.32
		draw_colored_polygon(PackedVector2Array([tip, tip.lerp(base_l, cut), tip.lerp(base_r, cut)]), tip_color)
