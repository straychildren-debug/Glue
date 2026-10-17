class_name Clock
extends Node
## Часы цеха: активны по такту — open_time секунд из каждых period, со сдвигом offset. Триггер для
## дверей, открывающихся по такту (свойство active, как у плит и рычагов).

@export var period := 4.0
@export var open_time := 1.2
@export var offset := 0.0

var active := false
var _t := 0.0


func _ready() -> void:
	add_to_group(GreyboxLevel.RESETTABLE)
	process_physics_priority = 20  # до дверей
	_t = offset


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, period)
	active = _t < open_time


func save_state() -> Variant:
	return offset


func load_state(_state: Variant) -> void:
	_t = offset  # после общего респавна такт — с начала
	active = _t < open_time
