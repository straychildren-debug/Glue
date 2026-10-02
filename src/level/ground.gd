@tool
class_name Ground
extends Node2D
## Платформы уровня в графике мира 01: любой прямоугольник блока «одевается» текстурами
## (tools/blender/make_tiles.py → assets/tiles/world_01/game). Внутри — кладка у поверхности,
## глубже — скала; сверху по открытой кромке — мох; по открытым бокам — каменный край с плющом.
## Открытая — значит не прижата к соседнему блоку: на стыке блоков ни мха, ни края нет.
## Текстуры привязаны к миру, а не к блоку: соседние блоки продолжают друг друга без шва.
##
## Кладка или скала — решает не блок, а рельеф: карта глубины под поверхностью для всего уровня
## (клетка — полтайла, сглажена), шейдер смешивает кладку и скалу по ней, и граница идёт по швам
## между камнями. Если решал бы каждый блок от своего верха, на стыке блоков разной высоты
## в одной строке встречались бы кладка и скала — прямые швы по границам блоков.
## Тонкие блоки (балки, насесты) рисует GreyboxLevel деревом. F3 — серые прямоугольники.

const DIR := "res://assets/tiles/world_01/game/"
## Текстуры вдвое крупнее, чем на экране при масштабе камеры 1: период повтора = размер / 2.
const TEXELS_PER_PX := 2.0
## Кладка у поверхности на такую глубину, переход в скалу — последние MASONRY_FEATHER;
## граница смещается на ±MASONRY_JITTER по рисунку кладки (швы режут раньше, камни — позже).
const MASONRY_DEPTH := 2.0 * GreyboxLevel.TILE
const MASONRY_FEATHER := 0.75 * GreyboxLevel.TILE
const MASONRY_JITTER := 0.6 * GreyboxLevel.TILE
## Клетка карты глубины, px, и сколько раз её сглаживать (каждый проход — соседи 3 × 3).
const DEPTH_CELL := GreyboxLevel.TILE / 2.0
const DEPTH_BLUR_PASSES := 2
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

const FILL_SHADER := """
shader_type canvas_item;
uniform sampler2D stone_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D cliff_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_map : repeat_disable, filter_linear;
uniform vec2 stone_period;
uniform vec2 cliff_period;
uniform vec2 map_origin;
uniform vec2 map_size_px;
uniform float masonry_depth;
uniform float masonry_feather;
uniform float masonry_jitter;
uniform float shade_from;
uniform float shade_span;
uniform vec4 deep_shade : source_color;
varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec3 stone = texture(stone_tex, world / stone_period).rgb;
	vec3 cliff = texture(cliff_tex, world / cliff_period).rgb;
	float depth = texture(depth_map, (world - map_origin) / map_size_px).r;
	// Светлые камни кладки держатся глубже, тёмные швы уступают скале раньше.
	float jitter = (dot(stone, vec3(0.333)) - 0.42) * 2.0 * masonry_jitter;
	float masonry = 1.0 - smoothstep(masonry_depth - masonry_feather, masonry_depth, depth - jitter);
	vec3 color = mix(cliff, stone, masonry);
	color *= mix(vec3(1.0), deep_shade.rgb, clamp((world.y - shade_from) / shade_span, 0.0, 1.0));
	COLOR = vec4(color, 1.0);
}
"""

static var _fill_shader: Shader

var _textures := {}
var _fill: Node2D
var _trim: Node2D
var _material: ShaderMaterial
## Блоки уровня, подготовленные к рисованию (без тонких, низ продлён под камеру), в тайлах.
var _blocks: Array[Rect2] = []
var _built_for := ""


func _ready() -> void:
	if _fill_shader == null:
		_fill_shader = Shader.new()
		_fill_shader.code = FILL_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _fill_shader
	_fill = Node2D.new()
	_fill.name = "Fill"
	_fill.material = _material
	_fill.draw.connect(_draw_fill)
	add_child(_fill, false, Node.INTERNAL_MODE_FRONT)
	_trim = Node2D.new()
	_trim.name = "Trim"
	_trim.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_trim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_trim.draw.connect(_draw_trim)
	add_child(_trim, false, Node.INTERNAL_MODE_FRONT)


func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(DIR + name + ".png")
	return _textures[name]


## Перестроить по блокам уровня. GreyboxLevel зовёт при каждой своей перерисовке (и при взятии
## чекпоинта), поэтому карта глубины пересчитывается, только если изменились блоки или F3.
func _draw() -> void:
	var level := get_parent() as GreyboxLevel
	var key := "%s|%s|%s" % [Art.enabled, level.blocks if level else null, level.bounds_tiles if level else null]
	if key == _built_for:
		return
	_built_for = key
	_blocks.clear()
	if level != null and Art.enabled:
		var bottom := level.bounds_tiles.end.y
		for rect in level.blocks:
			if rect.size.y <= 0.5:
				continue
			if rect.end.y >= bottom - BOTTOM_REACH:
				rect.size.y = bottom + BOTTOM_EXTRA - rect.position.y
			_blocks.append(rect)
		_update_material(level)
	_fill.queue_redraw()
	_trim.queue_redraw()


func _update_material(level: GreyboxLevel) -> void:
	var area := level.bounds_tiles
	area.size.y += BOTTOM_EXTRA
	var origin := area.position * GreyboxLevel.TILE
	var depth := _depth_map(area)
	var stone := _tex("w01_stone_fill")
	var cliff := _tex("w01_cliff_fill")
	_material.set_shader_parameter("stone_tex", stone)
	_material.set_shader_parameter("cliff_tex", cliff)
	_material.set_shader_parameter("depth_map", ImageTexture.create_from_image(depth))
	_material.set_shader_parameter("stone_period", stone.get_size() / TEXELS_PER_PX)
	_material.set_shader_parameter("cliff_period", cliff.get_size() / TEXELS_PER_PX)
	_material.set_shader_parameter("map_origin", origin)
	_material.set_shader_parameter("map_size_px", Vector2(depth.get_size()) * DEPTH_CELL)
	_material.set_shader_parameter("masonry_depth", MASONRY_DEPTH)
	_material.set_shader_parameter("masonry_feather", MASONRY_FEATHER)
	_material.set_shader_parameter("masonry_jitter", MASONRY_JITTER)
	_material.set_shader_parameter("shade_from", level.get_kill_y() - SHADE_SPAN)
	_material.set_shader_parameter("shade_span", SHADE_SPAN)
	_material.set_shader_parameter("deep_shade", DEEP_SHADE)


## Карта глубины под поверхностью рельефа (px) по клеткам DEPTH_CELL над областью area (тайлы).
## В каждом столбце глубина считается от верха сплошного участка; сглаживание — только между
## твёрдыми клетками (воздух не тянет глубину к нулю у открытых боков); клетка воздуха берёт
## среднее соседних твёрдых, чтобы линейная фильтрация у края не проваливалась.
func _depth_map(area: Rect2) -> Image:
	var per_tile := GreyboxLevel.TILE / DEPTH_CELL
	var w := int(ceil(area.size.x * per_tile))
	var h := int(ceil(area.size.y * per_tile))
	var solid := PackedByteArray()
	solid.resize(w * h)
	var depth := PackedFloat32Array()
	depth.resize(w * h)
	for x in w:
		var run_top := -1.0
		for y in h:
			var center := area.position + Vector2(x + 0.5, y + 0.5) / per_tile
			var inside := _blocks.any(func(rect: Rect2) -> bool: return rect.has_point(center))
			solid[y * w + x] = 1 if inside else 0
			if not inside:
				run_top = -1.0
				continue
			if run_top < 0.0:
				run_top = y
			depth[y * w + x] = (y + 0.5 - run_top) * DEPTH_CELL
	for pass_index in DEPTH_BLUR_PASSES:
		var blurred := depth.duplicate()
		for y in h:
			for x in w:
				if solid[y * w + x] == 0:
					continue
				var sum := 0.0
				var count := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx] == 1:
							sum += depth[ny * w + nx]
							count += 1
				blurred[y * w + x] = sum / count
		depth = blurred
	var image := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			var value := depth[y * w + x]
			if solid[y * w + x] == 0:
				var sum := 0.0
				var count := 0
				for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx] == 1:
						sum += depth[ny * w + nx]
						count += 1
				value = sum / count if count > 0 else 0.0
			image.set_pixel(x, y, Color(value, 0, 0))
	return image


func _draw_fill() -> void:
	for rect in _blocks:
		_fill.draw_rect(Rect2(rect.position * GreyboxLevel.TILE, rect.size * GreyboxLevel.TILE), Color.WHITE)


func _draw_trim() -> void:
	var level := get_parent() as GreyboxLevel
	if level == null:
		return
	var shade_from := level.get_kill_y() - SHADE_SPAN
	for rect in _blocks:
		for span in _open_side(rect, _blocks, true):
			_draw_side(rect.position.x, span, true, shade_from)
		for span in _open_side(rect, _blocks, false):
			_draw_side(rect.end.x, span, false, shade_from)
	for rect in _blocks:
		for span in _open_top(rect, _blocks):
			_draw_moss(rect.position.y, span)


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
	_trim.draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)


## Каменный край с плющом по открытому участку бока [span.x, span.y] (тайлы) на x (тайлы).
## Правый край — зеркальная копия левого. Темнеет к низу уровня, как кладка и скала.
func _draw_side(x: float, span: Vector2, left: bool, shade_from: float) -> void:
	var texture := _tex("w01_stone_side")
	var size := texture.get_size() / TEXELS_PER_PX
	var edge := x * GreyboxLevel.TILE
	var x0 := edge - SIDE_EDGE * size.x if left else edge + SIDE_EDGE * size.x - size.x
	var x1 := x0 + size.x
	var u0 := 0.0 if left else 1.0
	var u1 := 1.0 - u0
	var cuts: Array[float] = [span.x * GreyboxLevel.TILE, span.y * GreyboxLevel.TILE]
	for y: float in [shade_from, shade_from + SHADE_SPAN]:
		if y > cuts[0] + EPS and y < cuts[-1] - EPS:
			cuts.insert(cuts.size() - 1, y)
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		var points := PackedVector2Array([Vector2(x0, a), Vector2(x1, a), Vector2(x1, b), Vector2(x0, b)])
		var uvs := PackedVector2Array([Vector2(u0, a / size.y), Vector2(u1, a / size.y),
				Vector2(u1, b / size.y), Vector2(u0, b / size.y)])
		var ca := Color.WHITE.lerp(DEEP_SHADE, clampf((a - shade_from) / SHADE_SPAN, 0.0, 1.0))
		var cb := Color.WHITE.lerp(DEEP_SHADE, clampf((b - shade_from) / SHADE_SPAN, 0.0, 1.0))
		_trim.draw_polygon(points, PackedColorArray([ca, ca, cb, cb]), uvs, texture)


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
