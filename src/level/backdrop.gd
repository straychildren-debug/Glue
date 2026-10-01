class_name Backdrop
extends CanvasLayer
## Задник уровня из слоёв с параллаксом (дочерние BackdropLayer, рисуются по порядку:
## первый — самый дальний). Лежит в сцене уровня; рисуется позади всего на экране
## и следует за общей камерой. Пока у уровня есть задник, GreyboxLevel не рисует серое небо.

## Опорная высота камеры в мире (px): на ней слои стоят на своих center_y.
## NAN — взять высоту первого чекпоинта уровня минус четыре тайла (обычная высота камеры).
@export var reference_y := NAN


func _ready() -> void:
	layer = -10
	follow_viewport_enabled = false
	if is_nan(reference_y):
		var level := get_parent() as GreyboxLevel
		reference_y = (level.checkpoints[0].y - 4.0) * GreyboxLevel.TILE if level else 0.0
	# Порядок рисования — по глубине: чем меньше параллакс, тем дальше слой. Так ориентир,
	# добавленный уровнем к общему заднику, встаёт между дальним и средним планом.
	var layers := get_children().filter(func(child: Node) -> bool: return child is BackdropLayer)
	layers.sort_custom(func(a: BackdropLayer, b: BackdropLayer) -> bool: return a.parallax < b.parallax)
	for i in layers.size():
		move_child(layers[i], i)
		layers[i].texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport().get_visible_rect().size
	var center := camera.get_screen_center_position()
	for child in get_children():
		if child is BackdropLayer:
			child.update_view(view, center, camera.zoom.x, reference_y)
