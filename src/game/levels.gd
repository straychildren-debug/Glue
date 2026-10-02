class_name Levels
extends RefCounted
## Каталог уровней: миры по 20 уровней с нарастающей сложностью, затем комнаты прототипа.
## Пустая сцена — уровень запланирован, но ещё не собран (в меню «скоро»).

const LEVELS_PER_WORLD := 20
const WORLDS: Array[Dictionary] = [
	{
		"id": "w01",
		"title": "Забытые мосты",
		"levels": [
			{"title": "Первые шаги", "scene": "res://levels/w01_l01_first_steps.tscn"},
			{"title": "Подставь плечо", "scene": "res://levels/w01_l02_lend_a_shoulder.tscn"},
			{"title": "Не отпускай", "scene": "res://levels/w01_l03_dont_let_go.tscn"},
			{"title": "Ступенька в воздухе", "scene": "res://levels/w01_l04_step_in_the_air.tscn"},
			{"title": "Катапульта", "scene": "res://levels/w01_l05_catapult.tscn"},
			{"title": "Ящик", "scene": "res://levels/w01_l06_the_crate.tscn"},
			{"title": "Удерживай!", "scene": "res://levels/w01_l07_hold_it.tscn"},
			{"title": "Тяжёлый груз", "scene": "res://levels/w01_l08_heavy_load.tscn"},
			{"title": "Живая лестница", "scene": "res://levels/w01_l09_living_staircase.tscn"},
			{"title": "Перевал", "scene": "res://levels/w01_l10_the_pass.tscn"},
			{"title": "Качели", "scene": "res://levels/w01_l11_seesaw.tscn"},
			{"title": "Бросок качелей", "scene": "res://levels/w01_l12_seesaw_throw.tscn"},
			{"title": "Подъёмник", "scene": "res://levels/w01_l13_lift.tscn"},
			{"title": "Цепь", "scene": ""},
			{"title": "Над бездной", "scene": ""},
			{"title": "Груз через пропасть", "scene": ""},
			{"title": "Обратный путь", "scene": ""},
			{"title": "Башня", "scene": ""},
			{"title": "Разводной мост", "scene": ""},
			{"title": "Старый мост", "scene": ""},
		],
	},
]
## Комнаты прототипа: открыты всегда, в прогресс не входят.
const EXTRAS: Array[Dictionary] = [
	{"title": "Песочница", "scene": "res://levels/sandbox.tscn"},
	{"title": "Опасности", "scene": "res://levels/hazards.tscn"},
	{"title": "Комната этапа 1", "scene": "res://levels/test_room.tscn"},
]
## Номер мира для комнат прототипа.
const EXTRAS_WORLD := -1


static func world_id(world: int) -> String:
	return WORLDS[world].id


static func count(world: int) -> int:
	return EXTRAS.size() if world == EXTRAS_WORLD else WORLDS[world].levels.size()


static func entry(world: int, index: int) -> Dictionary:
	return EXTRAS[index] if world == EXTRAS_WORLD else WORLDS[world].levels[index]


static func scene_path(world: int, index: int) -> String:
	return entry(world, index).scene


static func is_built(world: int, index: int) -> bool:
	return index >= 0 and index < count(world) and scene_path(world, index) != ""


## Следующий собранный уровень того же мира или -1.
static func next_built(world: int, index: int) -> int:
	for i in range(index + 1, count(world)):
		if is_built(world, i):
			return i
	return -1


## Отладка F2: следующий собранный уровень, после последнего — комнаты прототипа, затем снова мир 1.
static func debug_next(world: int, index: int) -> Vector2i:
	var next := next_built(world, index)
	if next != -1:
		return Vector2i(world, next)
	if world == EXTRAS_WORLD:
		return Vector2i(0, 0)
	if world + 1 < WORLDS.size() and is_built(world + 1, 0):
		return Vector2i(world + 1, 0)
	return Vector2i(EXTRAS_WORLD, 0)
