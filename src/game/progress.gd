class_name Progress
extends RefCounted
## Сохранение прогресса: какие уровни пройдены. Уровень открыт, если он первый в мире
## или пройден предыдущий. Файл — ConfigFile в user:// (на Windows — %APPDATA%\Godot\app_userdata\…).

## Автотесты подменяют путь, чтобы не трогать настоящее сохранение.
static var path := "user://progress.cfg"
## Отладка: все собранные уровни открыты (переключается в меню, сохраняется).
static var unlock_all := false

## id мира -> Array[int] номеров пройденных уровней (с нуля).
static var _completed := {}
static var _loaded_from := ""


static func is_completed(world: int, index: int) -> bool:
	_ensure_loaded()
	return index in _completed.get(Levels.world_id(world), [])


static func is_unlocked(world: int, index: int) -> bool:
	if world == Levels.EXTRAS_WORLD:
		return true
	_ensure_loaded()
	return unlock_all or index == 0 or is_completed(world, index - 1) or is_completed(world, index)


static func completed_count(world: int) -> int:
	_ensure_loaded()
	return _completed.get(Levels.world_id(world), []).size()


static func mark_completed(world: int, index: int) -> void:
	if world == Levels.EXTRAS_WORLD or is_completed(world, index):
		return
	var id := Levels.world_id(world)
	var done: Array = _completed.get(id, [])
	done.append(index)
	done.sort()
	_completed[id] = done
	save()


static func set_unlock_all(value: bool) -> void:
	_ensure_loaded()
	unlock_all = value
	save()


## Стирает прогресс (автотесты и будущая кнопка «сбросить»).
static func reset() -> void:
	_completed.clear()
	unlock_all = false
	_loaded_from = path
	save()


static func save() -> void:
	var file := ConfigFile.new()
	for id: String in _completed:
		file.set_value(id, "completed", _completed[id])
	file.set_value("debug", "unlock_all", unlock_all)
	var error := file.save(path)
	if error != OK:
		push_warning("Не удалось сохранить прогресс в %s: %s" % [path, error_string(error)])


## Перечитывает файл (при смене пути или для проверки сохранения).
static func reload_from_disk() -> void:
	_loaded_from = ""
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded_from == path:
		return
	_loaded_from = path
	_completed.clear()
	unlock_all = false
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for id in file.get_sections():
		if file.has_section_key(id, "completed"):
			var done: Array = []
			for index in file.get_value(id, "completed", []):
				done.append(int(index))
			_completed[id] = done
	unlock_all = file.get_value("debug", "unlock_all", false)
