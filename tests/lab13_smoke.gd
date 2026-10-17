extends LevelBot
## Пробы физики для «Механического замка» (13): ящик на ленте и дверь, герой против ленты.


func _ready() -> void:
	game = await start_game(load("res://tests/lab13.tscn"))
	a = game.players[0]
	b = game.players[1]
	var crate: Crate = game.level.get_node("Crate")
	var door: Door = game.level.get_node("Door")
	place(b, Vector2(2 * TILE, _stand_y(12)))
	place(a, Vector2(3.2 * TILE, _stand_y(12)))
	await frames(120)
	print("LAB ящик у закрытой двери: x %.2f (дверь 11–12)" % (crate.get_rect().position.x / TILE))
	await hold(KEYS_1[GRAB], 4)
	await frames(120)
	print("LAB дверь открыта: ящик x %.2f..%.2f y %.2f, дверь y %.2f" % [crate.get_rect().position.x / TILE, crate.get_rect().end.x / TILE, crate.get_rect().end.y / TILE, door.position.y / TILE])
	await hold(KEYS_1[GRAB], 4)
	await frames(120)
	print("LAB рычаг выкл: дверь y %.2f (закрыта 8), ящик x %.2f" % [door.position.y / TILE, crate.get_rect().position.x / TILE])
	# Герой против ленты: бег и прыжки.
	place(b, Vector2(9.5 * TILE, _stand_y(12)))
	await frames(10)
	press(KEYS_2[LEFT], true)
	await frames(120)
	press(KEYS_2[LEFT], false)
	print("LAB бег против ленты 2 с: x %.2f (было 9.5)" % (b.global_position.x / TILE))
	place(b, Vector2(9.5 * TILE, _stand_y(12)))
	await frames(10)
	press(KEYS_2[LEFT], true)
	for i in 180:
		press(KEYS_2[JUMP], b.is_on_floor())
		await get_tree().physics_frame
	press(KEYS_2[JUMP], false)
	press(KEYS_2[LEFT], false)
	print("LAB прыжки против ленты 3 с: x %.2f (было 9.5)" % (b.global_position.x / TILE))
	finish()
