@tool
class_name Spikes
extends Node2D
## Шипы: касание — гибель (общий респавн команды). Шипы не твёрдые — это зона над полом.
## Замерший — камень: шипы ему не страшны. Прыгнуть в шипы и замереть до касания — и стать
## мостом, по голове которого пройдёт товарищ. Ожил в шипах — погиб.
## Ящики шипам безразличны. Положение узла — середина основания шипов на уровне пола.
## Рисуются спрайтами из Blender в стиле механизмов; F3 — серый вариант.

const HEIGHT := 30.0
## Насколько тело игрока должно зайти в шипы, чтобы уколоться (px): касание краем не считается.
const BITE := 4.0
const TOOTH := 22.0
## Спрайт шипов: высота холста и насколько его низ утоплен в землю (px).
const SPRITE_HEIGHT := 36.0
const SPRITE_SINK := 4.0

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
	if Art.enabled:
		_draw_sprite(width)
		return
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


## Спрайты из Blender (tools/blender/props.py): кованые колья на каменном пороге, как остальные
## механизмы. Торцы по краям, между ними куски по два кола, подогнанные по ширине, — без
## обрезанных половинок. Холст 36 px, низ порога утоплен в землю на 4 px.
func _draw_sprite(width: float) -> void:
	var mid := Art.tex("spikes_mid")
	var end := Art.tex("spikes_end")
	var end_w := end.get_width() / 4.0
	var top := -SPRITE_HEIGHT + SPRITE_SINK
	draw_texture_rect(end, Rect2(-width / 2.0, top, end_w, SPRITE_HEIGHT), false)
	draw_texture_rect(Art.tex_flipped("spikes_end"), Rect2(width / 2.0 - end_w, top, end_w, SPRITE_HEIGHT), false)
	var inner := width - 2.0 * end_w
	var count := maxi(1, int(round(inner / (mid.get_width() / 4.0))))
	var piece := inner / count
	for i in count:
		draw_texture_rect(mid, Rect2(-width / 2.0 + end_w + i * piece, top, piece, SPRITE_HEIGHT), false)
