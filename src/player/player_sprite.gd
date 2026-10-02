class_name PlayerSprite
extends AnimatedSprite2D
## Внешний вид игрока: кадры из Blender (tools/blender/character.py → assets/characters/v2).
## Физика и хитбокс остаются у Player — спрайт только выбирает анимацию по его состоянию.
## Вариант «_noarm» — без дальней руки: пока игрок держит товарища или тянется к нему,
## руку рисует Player, и она тянется под любым углом.

const MANIFEST := "res://assets/characters/v2/character_sheets.json"
const SHEET_DIR := "res://assets/characters/v2/"
const COLOR_KEYS: Array[String] = ["red", "blue", "yellow", "green"]
const OUTLINE_COLOR := Color("1a1d33")
## Скорость падения, после которой приземление проигрывает сплющивание.
const HARD_LANDING := 500.0
const SHADER := """
shader_type canvas_item;
// Замерший: тёмный контур модели становится светлым — как белая рамка у серого прототипа.
uniform vec4 outline_color : source_color;
uniform vec4 tint : source_color = vec4(1.0);
uniform float amount = 0.0;
void fragment() {
	vec4 c = COLOR;  // уже текстура × modulate
	float mask = (1.0 - smoothstep(0.08, 0.24, distance(c.rgb, outline_color.rgb))) * amount;
	COLOR = vec4(mix(c.rgb, tint.rgb, mask), c.a);
}
"""

static var _manifest := {}
static var _frames_cache := {}  # ключ цвета -> SpriteFrames
static var _shader: Shader

var _player: Player
var _landing := false
var _cell := 256.0
var _base_scale := Vector2.ONE
## Появление у чекпоинта: «выпрыгивает» с перебором; -1 — не идёт.
var _pop_time := -1.0


func setup(player: Player) -> void:
	_player = player
	var manifest := _load_manifest()
	_cell = float(manifest.cell)
	sprite_frames = _frames_for(COLOR_KEYS[player.slot])
	# Ступни кадра — на нижней грани хитбокса, высота от ступней до макушки — высота хитбокса.
	var feet: Array = manifest.feet
	var head_top: Array = manifest.head_top
	var size := Player.SIZE.y / (float(feet[1]) - float(head_top[1]))
	scale = Vector2(size, size)
	_base_scale = scale
	position = Vector2((_cell / 2.0 - float(feet[0])) * size,
			Player.SIZE.y / 2.0 - (float(feet[1]) - _cell / 2.0) * size)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _shader
	shader_material.set_shader_parameter("outline_color", OUTLINE_COLOR)
	material = shader_material
	animation_finished.connect(func() -> void: _landing = false)
	play("idle")


## Появление у чекпоинта: вырасти из точки с перебором, как упругий мармелад.
func pop_in() -> void:
	_pop_time = 0.0


func _update_pop(delta: float) -> void:
	if _pop_time < 0.0:
		return
	_pop_time += delta
	var t := _pop_time
	var k := 1.0
	if t < 0.16:
		k = 0.2 + t / 0.16 * 1.0  # 0,2 → 1,2
	elif t < 0.34:
		k = 1.2 - (t - 0.16) / 0.18 * 0.2
	else:
		_pop_time = -1.0
	# Растёт от ступней: ширина чуть отстаёт от высоты — упругий «выпрыг».
	scale = _base_scale * Vector2(lerpf(1.0, k, 0.8), k)


## Плечо дальней руки в координатах игрока — отсюда Player рисует руку хвата.
func shoulder_local() -> Vector2:
	var info: Dictionary = _load_manifest().states[animation.trim_suffix("_noarm")]
	var points: Array = info.shoulder
	var point: Array = points[clampi(frame, 0, points.size() - 1)]
	var local := (Vector2(float(point[0]), float(point[1])) - Vector2(_cell, _cell) / 2.0) * scale
	if flip_h:
		local.x = -local.x
	return position + local


func _physics_process(delta: float) -> void:
	_update_pop(delta)
	visible = Art.enabled
	if not Art.enabled or _player == null:
		return
	var state := _state()
	var arm_drawn_by_player := _player.grab_target != null or _player.is_reaching()
	var next := state + ("_noarm" if arm_drawn_by_player else "")
	if animation != next:
		var progress := frame_progress
		var keep_frame := frame if animation.trim_suffix("_noarm") == state else 0
		play(next)
		set_frame_and_progress(keep_frame, progress if keep_frame > 0 else 0.0)
	flip_h = _player.facing < 0
	speed_scale = clampf(absf(_player.get_real_velocity().x) / _player.run_speed, 0.5, 1.4) \
			if state == "run" else 1.0
	(material as ShaderMaterial).set_shader_parameter("amount", 1.0 if _player.frozen else 0.0)


func _state() -> String:
	var p := _player
	if p.frozen:
		_landing = false
		return "freeze"
	if not p.is_on_floor():
		_landing = false
		if p.is_hanging():
			return "hang"
		return "jump" if p.velocity.y < -60.0 else "fall"
	if p.landing_speed > HARD_LANDING:
		_landing = true
		if animation.trim_suffix("_noarm") == "land":
			frame = 0
	if _landing:
		return "land"
	if absf(p.get_real_velocity().x) > 30.0:
		return "run"
	return "idle"


static func _load_manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = (load(MANIFEST) as JSON).data
	return _manifest


## Кадры одного цвета: по анимации на состояние и вариант руки. Общие для всех игроков этого цвета.
static func _frames_for(key: String) -> SpriteFrames:
	if _frames_cache.has(key):
		return _frames_cache[key]
	var manifest := _load_manifest()
	var cell := float(manifest.cell)
	var frames := SpriteFrames.new()
	for variant in ["full", "noarm"]:
		var sheet: Texture2D = load(SHEET_DIR + str(manifest.sheets[key][variant]))
		for state: String in manifest.states:
			var info: Dictionary = manifest.states[state]
			var anim := state if variant == "full" else state + "_noarm"
			frames.add_animation(anim)
			frames.set_animation_speed(anim, float(info.fps))
			frames.set_animation_loop(anim, bool(info.loop))
			for i in int(info.frames):
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(i * cell, float(info.row) * cell, cell, cell)
				frames.add_frame(anim, atlas)
	frames.remove_animation("default")
	_frames_cache[key] = frames
	return frames
