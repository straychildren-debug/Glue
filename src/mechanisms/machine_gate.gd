class_name MachineGate
extends Node
## Триггер от «Большой машины» (для дверей, мостов, балок): активен, пока машина в фазе phase_at и дошла
## до волны wave_at (например, после второго попадания проваливается пол арены, а когда пасть открылась —
## пол поднимается обратно).

@export var machine: NodePath
@export var phase_at := 1
@export var wave_at := 0

var active := false


func _physics_process(_delta: float) -> void:
	var m := get_node_or_null(machine)
	if m != null:
		active = m.phase == phase_at and m.wave >= wave_at
