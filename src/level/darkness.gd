class_name Darkness
extends Node2D
## Тёмный цех: уровень и задник в полумраке, видно только то, что освещено, — фонарь (Lantern),
## искры и слабое свечение самих героев. Свет здесь и для игры: призрак с needs_light замирает
## от взгляда, только когда сам освещён (is_lit).
## Узел ставится в уровень один; положение роли не играет.

const GROUP := "darkness"

@export var ambient := Color(0.09, 0.1, 0.17)
## Задник чуть светлее: силуэты цеха угадываются.
@export var backdrop_ambient := Color(0.11, 0.11, 0.19)
@export var player_light_tiles := 1.6
@export var spark_light_tiles := 2.6

static var _texture: GradientTexture2D


func _ready() -> void:
	add_to_group(GROUP)
	var modulate_node := CanvasModulate.new()
	modulate_node.color = ambient
	add_child(modulate_node)
	var backdrop := get_parent().get_node_or_null("Backdrop")
	if backdrop is CanvasLayer:
		var back := CanvasModulate.new()
		back.color = backdrop_ambient
		backdrop.add_child.call_deferred(back)


func _process(_delta: float) -> void:
	# Свечение тем, у кого его ещё нет: герои появляются после уровня, искры — с уровнем.
	for player: Player in get_tree().get_nodes_in_group(Player.GROUP):
		if not player.has_meta("glow"):
			player.set_meta("glow", glow(player, player_light_tiles * GreyboxLevel.TILE, Color(1.0, 0.95, 0.85), 0.8))
	for spark: Node in get_parent().find_children("*", "Spark", true, false):
		if not spark.has_meta("glow"):
			spark.set_meta("glow", glow(spark, spark_light_tiles * GreyboxLevel.TILE, Color(1.0, 0.75, 0.35), 1.3))
	for lantern: Lantern in get_tree().get_nodes_in_group(Lantern.GROUP):
		if not lantern.has_meta("glow"):
			lantern.set_meta("glow", glow(lantern, lantern.light_tiles * GreyboxLevel.TILE, Color(1.0, 0.88, 0.6), 1.2))


## Круглый мягкий свет радиуса radius на узле node.
static func glow(node: Node2D, radius: float, color: Color, energy: float) -> PointLight2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.55, Color(1, 1, 1, 0.75))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = 256
		_texture.height = 256
	var light := PointLight2D.new()
	light.texture = _texture
	light.texture_scale = radius * 2.0 / 256.0
	light.color = color
	light.energy = energy
	node.add_child(light)
	return light


## Освещена ли точка: в круге горящего фонаря или искры (свет — с небольшим запасом внутрь).
## Свечение героев — только чтобы их было видно: призрака оно не освещает (иначе обернувшийся всегда
## останавливал бы его в шаге от себя, и фонарь был бы не нужен).
static func is_lit(tree: SceneTree, point: Vector2) -> bool:
	var dark: Darkness = tree.get_first_node_in_group(GROUP)
	if dark == null:
		return true
	var t := GreyboxLevel.TILE
	for lantern: Lantern in tree.get_nodes_in_group(Lantern.GROUP):
		if lantern.shining() and lantern.global_position.distance_to(point) < lantern.light_tiles * t * 0.85:
			return true
	for spark: Node in dark.get_parent().find_children("*", "Spark", true, false):
		if spark.visible and (spark as Node2D).global_position.distance_to(point) < dark.spark_light_tiles * t * 0.85:
			return true
	return false
