@tool
class_name Decals
extends Node2D
## Декорации уровня (без контура): расставляются автоматически по блокам уровня, по стилю мира
## (мир — по префиксу текстуры платформ: w01_… → мир 1). Расстановка не меняется от запуска
## к запуску (случайность с зерном от уровня). У механизмов, флажков и финиша декораций нет:
## интерактивное и опасное не должно прятаться. Текстуры — tools/make_decals.py.
##   Мир 1: трава, кусты и цветы по верхним кромкам, плющ с верхних углов, корни под козырьками.
##   Мир 2: мох с сажей по кромкам, фонари на открытых боках, полотнища под козырьками, трубы
##   на больших стенах, клубы пара над кромками (поднимаются и тают).
## Рисуется над платформами и под механизмами и игроками. F3 — без декораций.

const TEXELS_PER_PX := 2.0
const EPS := 0.001
## Пучок «врастает» в кромку: низ спрайта ниже линии, по которой ходят.
const SINK := 6.0
## Вокруг механизма свободно на столько px.
const CLEAR := 24.0
## Клуб пара: подъём (px) и период (с).
const STEAM_RISE := 70.0
const STEAM_PERIOD := 3.2

## Стили миров. top — что растёт на кромке и с какой вероятностью; top_gap — шаг, тайлы;
## side — что на верхнем углу открытого бока; under — что под козырьком; face — что на стенах.
const STYLES := {
	"01": {"top": {"grass": 0.5, "flowers": 0.25, "bush": 0.25}, "top_gap": Vector2(0.25, 1.5),
			"side": "ivy_hang", "side_chance": 0.8, "under": "roots", "face": "", "steam": 0.0},
	"02": {"top": {"soot_moss": 1.0}, "top_gap": Vector2(1.0, 3.5),
			"side": "lantern", "side_chance": 0.45, "under": "banner", "face": "pipes", "steam": 0.35},
}
## У этих вариантов кронштейн слева (у остальных фонарей — справа).
const BRACKET_LEFT := ["lantern_2"]

var _textures := {}
## Декорации: {tex, rect, flip, steam (сдвиг фазы или -1)}.
var _items: Array[Dictionary] = []
var _built_for := ""
var _world := "01"
var _time := 0.0
var _animated := false


func _tex(name: String) -> Texture2D:
	var key := _world + name
	if not _textures.has(key):
		_textures[key] = load("res://assets/decals/world_%s/game/w%s_%s.png" % [_world, _world, name])
	return _textures[key]


## Один из двух вариантов картинки: имя варианта и текстура.
func _variant(rng: RandomNumberGenerator, kind: String) -> Array:
	var name := kind if rng.randf() < 0.5 else kind + "_2"
	return [name, _tex(name)]


func _process(delta: float) -> void:
	if _animated and not Engine.is_editor_hint():
		_time += delta
		queue_redraw()


func _draw() -> void:
	var level := get_parent() as GreyboxLevel
	if level == null or not Art.enabled or not level.decals:
		return
	# В игре расстановка одна на уровень (ящики ездят — декорации за ними не перескакивают);
	# в редакторе — следует за правкой механизмов.
	var key := "%s|%s|%s" % [level.blocks, level.checkpoints, level.ground_fill]
	if Engine.is_editor_hint():
		key += str(_mechanism_rects(level))
	if key != _built_for:
		_built_for = key
		_build(level)
	for item in _items:
		var rect: Rect2 = item.rect
		var color := Color.WHITE
		if item.steam >= 0.0:
			var t := fposmod(_time / STEAM_PERIOD + item.steam, 1.0)
			rect.position.y -= STEAM_RISE * t
			color.a = 0.75 * sin(t * PI)
		draw_set_transform(rect.get_center(), 0.0, Vector2(-1.0 if item.flip else 1.0, 1.0))
		draw_texture_rect(item.tex, Rect2(-rect.size / 2.0, rect.size), false, color)
	draw_set_transform(Vector2.ZERO)


func _build(level: GreyboxLevel) -> void:
	_items.clear()
	_world = level.ground_fill.substr(1, 2)
	if not STYLES.has(_world):
		_world = "01"
	var style: Dictionary = STYLES[_world]
	_animated = style.steam > 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.title + str(level.blocks))
	var tile := GreyboxLevel.TILE
	var bottom := level.bounds_tiles.end.y
	var blocks: Array[Rect2] = []
	for rect in level.blocks:
		if rect.size.y > 0.5:
			blocks.append(rect)
	var clear := _mechanism_rects(level)
	for point in level.checkpoints:
		clear.append(Rect2(point * tile + Vector2(-40, -110), Vector2(96, 110)))
	for rect in blocks:
		for span in Ground._open_top(rect, blocks):
			_plant_top(rng, style, rect.position.y * tile, span * tile, clear)
			if style.steam > 0.0 and span.y - span.x >= 2.0 and rng.randf() < style.steam:
				_add_steam(rng, rect.position.y * tile, span * tile, clear)
		for left: bool in [true, false]:
			for span in Ground._open_side(rect, blocks, left):
				# С верхнего угла бока: свисает плющ или висит фонарь.
				if absf(span.x - rect.position.y) < EPS and span.y - span.x >= 1.5 and rng.randf() < style.side_chance:
					_plant_side(rng, style.side, (rect.position.x if left else rect.end.x) * tile, span * tile, left, clear)
		if rect.end.y < bottom - 1.5:
			for span in _open_bottom(rect, blocks):
				_plant_under(rng, style.under, rect.end.y * tile, span * tile, clear)
		if style.face != "" and rect.size.y >= 3.0 and rect.size.x >= 2.0:
			_plant_face(rng, style.face, rect, clear)


func _add(texture: Texture2D, rect: Rect2, flip: bool, steam := -1.0) -> void:
	_items.append({tex = texture, rect = rect, flip = flip, steam = steam})


## Растения на кромке на высоте top (px) по участку span (px, x от и до).
func _plant_top(rng: RandomNumberGenerator, style: Dictionary, top: float, span: Vector2, clear: Array[Rect2]) -> void:
	var gap: Vector2 = style.top_gap
	var x := span.x + rng.randf_range(0.0, gap.y) * GreyboxLevel.TILE * 0.5
	while x < span.y:
		var texture: Texture2D = _variant(rng, _pick(rng, style.top))[1]
		var size := Vector2(texture.get_size()) / TEXELS_PER_PX * rng.randf_range(0.75, 1.1)
		var area := Rect2(x, top - size.y + SINK, size.x, size.y)
		if x >= span.x - 4.0 and x + size.x <= span.y + 4.0 and not _blocked(area, clear):
			_add(texture, area, rng.randf() < 0.5)
			x += size.x * 0.8
		x += rng.randf_range(gap.x, gap.y) * GreyboxLevel.TILE


## Клуб пара над кромкой: поднимается и тает, по кругу.
func _add_steam(rng: RandomNumberGenerator, top: float, span: Vector2, clear: Array[Rect2]) -> void:
	var texture: Texture2D = _variant(rng, "steam")[1]
	var size := Vector2(texture.get_size()) / TEXELS_PER_PX * rng.randf_range(0.6, 0.9)
	var x := rng.randf_range(span.x, span.y - size.x)
	var area := Rect2(x, top - size.y, size.x, size.y)
	if not _blocked(area, clear):
		_add(texture, area, rng.randf() < 0.5, rng.randf())


## Верхний угол открытого бока на x (px); span — участок бока по высоте (px).
func _plant_side(rng: RandomNumberGenerator, kind: String, x: float, span: Vector2, left: bool, clear: Array[Rect2]) -> void:
	var picked := _variant(rng, kind)
	var texture: Texture2D = picked[1]
	var size := Vector2(texture.get_size()) / TEXELS_PER_PX * rng.randf_range(0.75, 1.15)
	var rect: Rect2
	var flip: bool
	if kind == "ivy_hang":
		# Плеть свисает с кромки по боку, не длиннее бока.
		size *= minf(1.0, (span.y - span.x - 0.3 * GreyboxLevel.TILE) / size.y)
		rect = Rect2(x + (-8.0 if left else 8.0) - size.x / 2.0, span.x - 6.0, size.x, size.y)
		flip = not left
	else:
		# Фонарь на кронштейне: кронштейн у грани, фонарь — в воздухе перед ней.
		size *= 0.9
		var top := span.x + 0.35 * GreyboxLevel.TILE
		rect = Rect2(x - size.x if left else x, top, size.x, size.y)
		var bracket_left: bool = picked[0] in BRACKET_LEFT
		flip = bracket_left if left else not bracket_left
	if not _blocked(rect, clear):
		_add(texture, rect, flip)


## Под нависающим краем на высоте y (px) по участку span (px): корни, полотнища.
func _plant_under(rng: RandomNumberGenerator, kind: String, y: float, span: Vector2, clear: Array[Rect2]) -> void:
	var roots := kind == "roots"
	var x := span.x + rng.randf_range(0.2, 1.5) * GreyboxLevel.TILE
	while x < span.y:
		var texture: Texture2D = _variant(rng, kind)[1]
		var scale := rng.randf_range(0.5, 0.75) if roots else rng.randf_range(0.8, 1.0)
		var size := Vector2(texture.get_size()) / TEXELS_PER_PX * scale
		var area := Rect2(x, y - 6.0, size.x, size.y)
		if x + size.x <= span.y and rng.randf() < (0.7 if roots else 0.5) and not _blocked(area, clear):
			_add(texture, area, rng.randf() < 0.5)
			x += size.x
		x += rng.randf_range(1.0, 3.0 if roots else 4.0) * GreyboxLevel.TILE


## На стене большого блока (рисунок заливки — это стена за кромкой): трубы.
func _plant_face(rng: RandomNumberGenerator, kind: String, rect: Rect2, clear: Array[Rect2]) -> void:
	var tile := GreyboxLevel.TILE
	var count := int(rect.size.x / 5.0) + (1 if rng.randf() < 0.5 else 0)
	for i in count:
		var texture: Texture2D = _variant(rng, kind)[1]
		var size := Vector2(texture.get_size()) / TEXELS_PER_PX * rng.randf_range(0.8, 1.1)
		var x := rng.randf_range(rect.position.x + 0.5, rect.end.x - 0.5) * tile - size.x / 2.0
		var area := Rect2(x, rect.position.y * tile + rng.randf_range(0.7, 1.4) * tile, size.x, size.y)
		if area.end.y < rect.end.y * tile - 0.5 * tile and not _blocked(area, clear):
			_add(texture, area, rng.randf() < 0.5)


func _pick(rng: RandomNumberGenerator, kinds: Dictionary) -> String:
	var roll := rng.randf()
	for kind: String in kinds:
		roll -= kinds[kind]
		if roll <= 0.0:
			return kind
	return kinds.keys()[0]


static func _blocked(area: Rect2, clear: Array[Rect2]) -> bool:
	return clear.any(func(rect: Rect2) -> bool: return rect.intersects(area))


## Где механизмы уровня (px, с запасом CLEAR): там декораций нет.
static func _mechanism_rects(level: GreyboxLevel) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var tile := GreyboxLevel.TILE
	for child in level.get_children():
		var node := child as Node2D
		if node == null or node.get_script() == null:
			continue
		var pos := node.position
		var rect := Rect2(pos - Vector2(40, 72), Vector2(80, 88))
		if node is Ghost or node is Crate or node is Beetle or node is Spark:
			continue  # летает или ездит: постоянного места на кромке нет
		if node is Wire:
			for i in node.points.size() - 1:
				var a: Vector2 = node.point_global(i)
				var b: Vector2 = node.point_global(i + 1)
				result.append(Rect2(a, Vector2.ZERO).expand(b).grow(CLEAR))
			continue
		if node is Crane or node is Bellows:
			rect = Rect2(pos - Vector2(96, 48), Vector2(node.length_tiles * tile + 192, 96 + 3.0 * tile))
		elif node.has_method("get_rect") and not Engine.is_editor_hint():
			rect = node.get_rect()
		elif "size_tiles" in node:
			rect = Rect2(pos, node.size_tiles * tile)
		elif node is Conveyor or node is BrittleFloor:
			rect = Rect2(pos.x, pos.y - 48.0, node.width_tiles * tile, 72.0)
		elif "width_tiles" in node:
			var w: float = node.width_tiles * tile
			rect = Rect2(pos.x - w / 2.0, pos.y - 48.0, w, 64.0)
		elif node is Seesaw:
			rect = Rect2(pos.x - 56.0, pos.y - 32.0, 112.0, 128.0)  # доска ходит над травой, опора — нет
		elif node is Spinner:
			var r: float = node.length_tiles * tile / 2.0
			rect = Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0)
		result.append(rect.grow(CLEAR))
	return result


## Участки нижней кромки, под которыми нет другого блока.
static func _open_bottom(rect: Rect2, blocks: Array[Rect2]) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(rect.position.x, rect.end.x)]
	for other in blocks:
		if other != rect and other.position.y <= rect.end.y + EPS and other.end.y > rect.end.y + EPS:
			spans = Ground._subtract(spans, other.position.x, other.end.x)
	return spans
