class_name Levels
extends RefCounted
## Каталог уровней: миры по 20 уровней с нарастающей сложностью, затем комнаты прототипа.
## Пустая сцена — уровень запланирован, но ещё не собран (в меню «скоро»).

const LEVELS_PER_WORLD := 20
const WORLDS: Array[Dictionary] = [
	{
		"id": "w01",
		"title": "Забытые мосты",
		"story": true,
		"levels": [
			# Раскладка 5 / 5 / 5 / 5 (решение 63, docs/14): лёгкие, средние, немного сложные, очень сложные.
			{"title": "Первые шаги", "scene": "res://levels/w01_l01_first_steps.tscn"},
			{"title": "Подставь плечо", "scene": "res://levels/w01_l02_lend_a_shoulder.tscn"},
			{"title": "Не отпускай", "scene": "res://levels/w01_l03_dont_let_go.tscn"},
			{"title": "Ступенька в воздухе", "scene": "res://levels/w01_l04_step_in_the_air.tscn"},
			{"title": "Катапульта", "scene": "res://levels/w01_l05_catapult.tscn"},
			{"title": "Ящик с той стороны", "scene": "res://levels/w01_l06_crate_from_far.tscn"},
			{"title": "Две кнопки", "scene": "res://levels/w01_l07_two_buttons.tscn"},
			{"title": "Качели", "scene": "res://levels/w01_l08_seesaw_throw.tscn"},
			{"title": "Подъёмник", "scene": "res://levels/w01_l09_lift.tscn"},
			{"title": "Четыре цвета", "scene": "res://levels/w01_l10_four_colors.tscn"},
			{"title": "Эстафета", "scene": "res://levels/w01_l11_relay.tscn"},
			{"title": "Цепь над шипами", "scene": "res://levels/w01_l12_chain.tscn"},
			{"title": "Стесняшки", "scene": "res://levels/w01_l13_shy.tscn"},
			{"title": "Под прессами", "scene": "res://levels/w01_l14_presses.tscn"},
			{"title": "Разводной мост", "scene": "res://levels/w01_l15_drawbridge.tscn"},
			{"title": "Обвал", "scene": "res://levels/w01_l16_rockfall.tscn"},
			{"title": "Призраки и обвал", "scene": "res://levels/w01_l17_ghosts_chase.tscn"},
			{"title": "Эстафета под обвалом", "scene": "res://levels/w01_l18_relay_chase.tscn"},
			{"title": "Сквозь пилы", "scene": "res://levels/w01_l19_sawmill.tscn"},
			{"title": "Старый мост", "scene": "res://levels/w01_l20_old_bridge.tscn"},
		],
	},
	{
		"id": "w02",
		"title": "Мастерские",
		"story": true,
		# Решение 67: 3 вводных, 5 сложных, 12 очень сложных; типы чередуются — голова, ловкость, скорость.
		"levels": [
			{"title": "Лента и пружина", "scene": "res://levels/w02_l01_belt_spring.tscn"},
			{"title": "Ветер и кран", "scene": "res://levels/w02_l02_wind_crane.tscn"},
			{"title": "Искра и жук", "scene": "res://levels/w02_l03_spark_beetle.tscn"},
			{"title": "Сортировка", "scene": "res://levels/w02_l04_sorting.tscn"},
			{"title": "Ветряк", "scene": "res://levels/w02_l05_windmill.tscn"},
			{"title": "Стрелочник", "scene": "res://levels/w02_l06_switchman.tscn"},
			{"title": "Смена на ленте", "scene": "res://levels/w02_l07_shift.tscn"},
			{"title": "Кран над настилом", "scene": "res://levels/w02_l08_crane_chain.tscn"},
			{"title": "Бегущий фитиль", "scene": "res://levels/w02_l09_fuse_run.tscn"},
			{"title": "Весы", "scene": "res://levels/w02_l10_scales.tscn"},
			{"title": "Жуки на ленте", "scene": "res://levels/w02_l11_beetle_belts.tscn"},
			{"title": "Цех под обвалом", "scene": "res://levels/w02_l12_rockfall_shop.tscn"},
			{"title": "Механический замок", "scene": "res://levels/w02_l13_lock.tscn"},
			{"title": "Пружинный цирк", "scene": "res://levels/w02_l14_spring_circus.tscn"},
			{"title": "Беличье колесо", "scene": "res://levels/w02_l15_wheel.tscn"},
			{"title": "Порыв", "scene": "res://levels/w02_l16_gust.tscn"},
			{"title": "Тяжёлый заказ", "scene": "res://levels/w02_l17_heavy_order.tscn"},
			{"title": "Искры и призрак", "scene": "res://levels/w02_l18_sparks_ghost.tscn"},
			{"title": "Перекрёсток", "scene": "res://levels/w02_l19_crossroads.tscn"},
			{"title": "Большая машина", "scene": "res://levels/w02_l20_big_machine.tscn"},
		],
	},
	{
		# Пробные трудные уровни (решение 58): мерило сложности для переделки 11–20 миров.
		"id": "trial",
		"title": "Пробные сложные",
		"levels": [
			{"title": "Груз на пружине", "scene": "res://levels/trial/t01_cargo_spring.tscn"},
			{"title": "Две кнопки", "scene": "res://levels/trial/t02_two_buttons.tscn"},
			{"title": "Кран и ветер", "scene": "res://levels/trial/t03_crane_wind.tscn"},
			{"title": "Ящик с той стороны", "scene": "res://levels/trial/t04_crate_from_far.tscn"},
			{"title": "Четыре цвета", "scene": "res://levels/trial/t05_four_colors.tscn"},
			{"title": "Эстафета", "scene": "res://levels/trial/t06_relay.tscn"},
			{"title": "Обвал", "scene": "res://levels/trial/t07_rockfall.tscn"},
		],
	},
	{
		# Прежний состав мира 2 (до решения 67): играбелен, пока новый не собран.
		"id": "w02old",
		"title": "Мастерские — прежние",
		"levels": [
			{"title": "Лента", "scene": "res://levels/w02_l01_belt.tscn"},
			{"title": "Пружина", "scene": "res://levels/w02_l02_spring.tscn"},
			{"title": "Взведённая пружина", "scene": "res://levels/w02_l03_charged.tscn"},
			{"title": "Ломкий настил", "scene": "res://levels/w02_l04_brittle.tscn"},
			{"title": "Поворот", "scene": "res://levels/w02_l05_turn.tscn"},
			{"title": "Меха", "scene": "res://levels/w02_l06_bellows.tscn"},
			{"title": "Кран", "scene": "res://levels/w02_l07_crane.tscn"},
			{"title": "Под прессом", "scene": "res://levels/w02_l08_presses.tscn"},
			{"title": "Пилорама", "scene": "res://levels/w02_l09_sawmill.tscn"},
			{"title": "Цех", "scene": "res://levels/w02_l10_workshop.tscn"},
			{"title": "Жук", "scene": "res://levels/w02_l11_beetle.tscn"},
			{"title": "Жук на плите", "scene": "res://levels/w02_l12_beetle_plate.tscn"},
			{"title": "Искра", "scene": "res://levels/w02_l13_spark.tscn"},
			{"title": "Стрелка", "scene": "res://levels/w02_l14_switch.tscn"},
			{"title": "Фитиль", "scene": "res://levels/w02_l15_fuse.tscn"},
			{"title": "Ветер и ящик", "scene": "res://levels/w02_l16_wind_crate.tscn"},
			{"title": "Призрак в цеху", "scene": "res://levels/w02_l17_ghost.tscn"},
			{"title": "Два жука", "scene": "res://levels/w02_l18_two_beetles.tscn"},
			{"title": "Искры и пружины", "scene": "res://levels/w02_l19_spark_springs.tscn"},
		],
	},
]

## Комнаты прототипа: открыты всегда, в прогресс не входят.
const EXTRAS: Array[Dictionary] = [
	{"title": "Песочница", "scene": "res://levels/sandbox.tscn"},
	{"title": "Опасности", "scene": "res://levels/hazards.tscn"},
	{"title": "Мастерская", "scene": "res://levels/workshop_lab.tscn"},
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


## Мир открыт: первый — всегда, следующий — когда пройден последний уровень предыдущего.
static func is_world_unlocked(world: int) -> bool:
	if world <= 0 or Progress.unlock_all or Progress.playtest_open:
		return true
	return Progress.is_completed(world - 1, count(world - 1) - 1)


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


## Режим «История»: миры подряд (только помеченные "story"), в каждом уровни по порядку.
static func story_worlds() -> Array[int]:
	var out: Array[int] = []
	for i in WORLDS.size():
		if WORLDS[i].get("story", false):
			out.append(i)
	return out


## Следующий уровень истории после (world, index): дальше в мире, потом первый собранный
## следующего мира истории. Vector2i(-1, -1) — история (пока) кончилась.
static func story_next(world: int, index: int) -> Vector2i:
	var next := next_built(world, index)
	if next != -1:
		return Vector2i(world, next)
	var worlds := story_worlds()
	var at := worlds.find(world)
	for k in range(at + 1, worlds.size()):
		var first := next_built(worlds[k], -1)
		if first != -1:
			return Vector2i(worlds[k], first)
	return Vector2i(-1, -1)
