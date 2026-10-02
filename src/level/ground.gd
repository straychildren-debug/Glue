@tool
class_name Ground
extends Node2D
## Платформы уровня в графике мира 01: любой прямоугольник блока «одевается» текстурами
## (tools/blender/make_tiles.py → assets/tiles/world_01/game). Внутри — кладка у поверхности,
## глубже — скала; сверху по открытой кромке — мох; по открытым бокам — каменный край с плющом.
## Открытая — значит не прижата к соседнему блоку: на стыке блоков ни мха, ни края нет.
## Текстуры привязаны к миру, а не к блоку: соседние блоки продолжают друг друга без шва.
## Тонкие блоки (балки, насесты) рисует GreyboxLevel деревом. F3 — серые прямоугольники.

const DIR := "res://assets/tiles/world_01/game/"
## Текстуры вдвое крупнее, чем на экране при масштабе камеры 1: период повтора = размер / 2.
const TEXELS_PER_PX := 2.0
## Кладка у поверхности блока на такую глубину, ниже — скала; нижние MASONRY_FEATHER растушёваны.
const MASONRY_DEPTH := 2.0 * GreyboxLevel.TILE
const MASONRY_FEATHER := 0.75 * GreyboxLevel.TILE
## Узкий и высокий блок — стена уровня: целиком скала.
const WALL_MAX_WIDTH := 1.5
const WALL_MIN_HEIGHT := 6.0
## Камень темнеет к низу уровня: последние SHADE_SPAN над линией гибели уходят в DEEP_SHADE.
## Тон зависит только от высоты в мире, поэтому соседние блоки не расходятся по тону.
const DEEP_SHADE := Color(0.6, 0.6, 0.66)
const SHADE_SPAN := 6.0 * GreyboxLevel.TILE
## Блок, доходящий почти до низа камеры, рисуется ниже её границы — под землёй не видно неба.
const BOTTOM_REACH := 1.5
const BOTTOM_EXTRA := 3.0
## Линия, по которой ходят, в полосе мха — доля её высоты (выше — травинки, ниже — капли).
const MOSS_SURFACE := 0.17
## Мох чуть заходит за углы блока, прикрывая верх бокового края.
const MOSS_OVERHANG := 5.0
## Внешний край каменной колонны в полосе края — доля её ширины (левее — свисающий плющ).
const SIDE_EDGE := 0.104
const EPS := 0.001

var _textures := {}
var _shade_from := 0.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(DIR + name + ".png")
	return _textures[name]


func _draw() -> void:
	var level := get_parent() as GreyboxLevel
	if level == null or not Art.enabled:
		return
	_shade_from = level.get_kill_y() - SHADE_SPAN
	var blocks: Array[Rect2] = []
	var bottom := level.bounds_tiles.end.y
	for rect in level.blocks:
		if rect.size.y <= 0.5:
			continue
		if rect.end.y >= bottom - BOTTOM_REACH:
			rect.size.y = bottom + BOTTOM_EXTRA - rect.position.y
		blocks.append(rect)
	for rect in blocks:
		_draw_fill(rect)
	for rect in blocks:
		for span in _open_side(rect, blocks, true):
			_draw_side(rect.position.x, span, true)
		for span in _open_side(rect, blocks, false):
			_draw_side(rect.end.x, span, false)
	for rect in blocks:
		for span in _open_top(rect, blocks):
			_draw_moss(rect.position.y, span)


## Скала на весь блок, поверх — кладка у поверхности с растушёванным низом.
func _draw_fill(rect: Rect2) -> void:
	var px := Rect2(rect.position * GreyboxLevel.TILE, rect.size * GreyboxLevel.TILE)
	_rows(_tex("w01_cliff_fill"), px, Vector2.ZERO, false)
	if rect.size.x <= WALL_MAX_WIDTH and rect.size.y >= WALL_MIN_HEIGHT:
		return
	var solid := minf(px.size.y, MASONRY_DEPTH - MASONRY_FEATHER)
	var masonry := Rect2(px.position, Vector2(px.size.x, minf(px.size.y, MASONRY_DEPTH)))
	# Невысокий блок — кладка целиком, без растушёвки.
	var fade := Vector2(px.position.y + solid, masonry.end.y) if masonry.size.y > solid + EPS else Vector2.ZERO
	_rows(_tex("w01_stone_fill"), masonry, fade, false)


## Мох по открытому участку кромки [span.x, span.y] (тайлы) на высоте top (тайлы). Не темнеет:
## поверхности, по которым ходят, должны читаться всегда.
func _draw_moss(top: float, span: Vector2) -> void:
	var texture := _tex("w01_moss_top")
	var size := texture.get_size() / TEXELS_PER_PX
	var y := top * GreyboxLevel.TILE - MOSS_SURFACE * size.y
	var x0 := span.x * GreyboxLevel.TILE - MOSS_OVERHANG
	var x1 := span.y * GreyboxLevel.TILE + MOSS_OVERHANG
	var points := PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + size.y), Vector2(x0, y + size.y)])
	var uvs := PackedVector2Array([Vector2(x0 / size.x, 0), Vector2(x1 / size.x, 0),
			Vector2(x1 / size.x, 1), Vector2(x0 / size.x, 1)])
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)


## Каменный край с плющом по открытому участку бока [span.x, span.y] (тайлы) на x (тайлы).
## Правый край — зеркальная копия левого.
func _draw_side(x: float, span: Vector2, left: bool) -> void:
	var texture := _tex("w01_stone_side")
	var size := texture.get_size() / TEXELS_PER_PX
	var edge := x * GreyboxLevel.TILE
	var x0 := edge - SIDE_EDGE * size.x if left else edge + SIDE_EDGE * size.x - size.x
	var rect := Rect2(x0, span.x * GreyboxLevel.TILE, size.x, (span.y - span.x) * GreyboxLevel.TILE)
	_rows(texture, rect, Vector2.ZERO, true, not left)


## Текстура на прямоугольник мира полосами по высоте: в каждой полосе тон и прозрачность
## меняются линейно. fade = (y начала, y конца) растушёвки до прозрачности; Vector2.ZERO — без неё.
## strip — полоса края: по x текстура целиком (зеркально при flip), по y — повтор от мира;
## иначе повтор по обеим осям от мира.
func _rows(texture: Texture2D, px: Rect2, fade: Vector2, strip: bool, flip := false) -> void:
	var period := texture.get_size() / TEXELS_PER_PX
	var cuts: Array[float] = [px.position.y, px.end.y]
	for y: float in [_shade_from, _shade_from + SHADE_SPAN, fade.x, fade.y]:
		if y > px.position.y + EPS and y < px.end.y - EPS and not cuts.has(y):
			cuts.append(y)
	cuts.sort()
	var u0 := px.position.x / period.x
	var u1 := px.end.x / period.x
	if strip:
		u0 = 1.0 if flip else 0.0
		u1 = 1.0 - u0
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		var ca := _color_at(a, fade)
		var cb := _color_at(b, fade)
		if ca.a <= 0.0 and cb.a <= 0.0:
			continue
		var points := PackedVector2Array([Vector2(px.position.x, a), Vector2(px.end.x, a),
				Vector2(px.end.x, b), Vector2(px.position.x, b)])
		var uvs := PackedVector2Array([Vector2(u0, a / period.y), Vector2(u1, a / period.y),
				Vector2(u1, b / period.y), Vector2(u0, b / period.y)])
		draw_polygon(points, PackedColorArray([ca, ca, cb, cb]), uvs, texture)


func _color_at(y: float, fade: Vector2) -> Color:
	var color := Color.WHITE.lerp(DEEP_SHADE, clampf((y - _shade_from) / SHADE_SPAN, 0.0, 1.0))
	if fade != Vector2.ZERO:
		color.a = 1.0 - clampf((y - fade.x) / (fade.y - fade.x), 0.0, 1.0)
	return color


## Участки верхней кромки, над которыми нет другого блока.
static func _open_top(rect: Rect2, blocks: Array[Rect2]) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(rect.position.x, rect.end.x)]
	for other in blocks:
		if other != rect and other.position.y < rect.position.y - EPS and other.end.y >= rect.position.y - EPS:
			spans = _subtract(spans, other.position.x, other.end.x)
	return spans


## Участки левого (или правого) бока, к которым не прижат другой блок.
static func _open_side(rect: Rect2, blocks: Array[Rect2], left: bool) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(rect.position.y, rect.end.y)]
	var x := rect.position.x if left else rect.end.x
	for other in blocks:
		if other == rect:
			continue
		var covers := (other.position.x < x - EPS and other.end.x >= x - EPS) if left \
				else (other.position.x <= x + EPS and other.end.x > x + EPS)
		if covers:
			spans = _subtract(spans, other.position.y, other.end.y)
	return spans


static func _subtract(spans: Array[Vector2], from: float, to: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for span in spans:
		if to <= span.x + EPS or from >= span.y - EPS:
			result.append(span)
			continue
		if from > span.x + EPS:
			result.append(Vector2(span.x, from))
		if to < span.y - EPS:
			result.append(Vector2(to, span.y))
	return result
