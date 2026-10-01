class_name Art
extends RefCounted
## Готовая графика поверх серого прототипа. Механизмы — спрайты из Blender
## (tools/blender/props.py → assets/props/v1, 4 px текстуры на 1 px игры), персонажи — PlayerSprite.
## F3 в игре переключает графику и серые прямоугольники (хитбоксы видны как есть).

const PROPS_DIR := "res://assets/props/v1/"

## Графика или серые прямоугольники прототипа.
static var enabled := true
static var _textures := {}


static func tex(sprite: String) -> Texture2D:
	if not _textures.has(sprite):
		_textures[sprite] = load(PROPS_DIR + sprite + ".png")
	return _textures[sprite]


## Отражённая копия спрайта (правый или нижний торец). Отражение через трансформацию
## не подходит: полоса может рисоваться уже под поворотом (балка качелей).
static func tex_flipped(sprite: String, vertical := false) -> Texture2D:
	var key := sprite + ("@flip_v" if vertical else "@flip_h")
	if not _textures.has(key):
		var image := tex(sprite).get_image()
		image.decompress()
		if image.has_mipmaps():
			image.clear_mipmaps()
		if vertical:
			image.flip_y()
		else:
			image.flip_x()
		image.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


## Полоса по горизонтали: торец end слева, его отражение справа, между ними повторяется
## бесшовный кусок mid (последний обрезается). Масштаб — по высоте rect.
static func draw_strip_h(item: CanvasItem, rect: Rect2, mid: String, end: String) -> void:
	var mid_tex := tex(mid)
	var end_tex := tex(end)
	var scale := rect.size.y / mid_tex.get_height()
	var mid_w := mid_tex.get_width() * scale
	var end_w := minf(end_tex.get_width() * scale, rect.size.x / 2.0)
	var x := rect.position.x + end_w
	var stop := rect.end.x - end_w
	while x < stop - 0.01:
		var w := minf(mid_w, stop - x)
		item.draw_texture_rect_region(mid_tex, Rect2(x, rect.position.y, w, rect.size.y),
				Rect2(0, 0, w / scale, mid_tex.get_height()))
		x += w
	var end_src := Rect2(0, 0, end_w / scale, end_tex.get_height())
	item.draw_texture_rect_region(end_tex, Rect2(rect.position.x, rect.position.y, end_w, rect.size.y), end_src)
	# Правый торец — отражение левого.
	var right := tex_flipped(end)
	item.draw_texture_rect_region(right, Rect2(rect.end.x - end_w, rect.position.y, end_w, rect.size.y),
			Rect2(right.get_width() - end_w / scale, 0, end_w / scale, right.get_height()))


## То же по вертикали: торец сверху, отражение снизу, куски между ними. Масштаб — по ширине.
static func draw_strip_v(item: CanvasItem, rect: Rect2, mid: String, end: String) -> void:
	var mid_tex := tex(mid)
	var end_tex := tex(end)
	var scale := rect.size.x / mid_tex.get_width()
	var mid_h := mid_tex.get_height() * scale
	var end_h := minf(end_tex.get_height() * scale, rect.size.y / 2.0)
	var y := rect.position.y + end_h
	var stop := rect.end.y - end_h
	while y < stop - 0.01:
		var h := minf(mid_h, stop - y)
		item.draw_texture_rect_region(mid_tex, Rect2(rect.position.x, y, rect.size.x, h),
				Rect2(0, 0, mid_tex.get_width(), h / scale))
		y += h
	var end_src := Rect2(0, 0, end_tex.get_width(), end_h / scale)
	item.draw_texture_rect_region(end_tex, Rect2(rect.position.x, rect.position.y, rect.size.x, end_h), end_src)
	var bottom := tex_flipped(end, true)
	item.draw_texture_rect_region(bottom, Rect2(rect.position.x, rect.end.y - end_h, rect.size.x, end_h),
			Rect2(0, bottom.get_height() - end_h / scale, bottom.get_width(), end_h / scale))


## Деревянная деталь любой длины: тонкая (≤ 0,3 тайла) — брус, толще — настил из досок.
static func draw_wood(item: CanvasItem, rect: Rect2) -> void:
	if rect.size.y <= GreyboxLevel.TILE * 0.3:
		draw_strip_h(item, rect, "beam_mid", "beam_end")
	else:
		draw_strip_h(item, rect, "bridge_mid", "bridge_end")


## После переключения F3: перерисовать всё дерево узлов (механизмы рисуют себя в _draw).
static func redraw_all(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		redraw_all(child)
