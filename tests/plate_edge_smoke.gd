extends LevelBot
## Автопроверка: игрок на самом краю плиты (на скосе). Плита не должна дрожать: нажатая
## опускается, стоящий на краю оказывается на полу — и всё равно держит её, пока не сойдёт.
## Кнопка срабатывает один раз за заход, ворота закрываются в срок.
## Запуск: Godot_console --headless --path . res://tests/plate_edge_smoke.tscn

## На сколько px игрок заходит на плиту с края.
const OVERLAPS: Array[float] = [1.0, 3.0, 6.0, 10.0, 16.0, 24.0]


func _ready() -> void:
	game = await start_game(preload("res://levels/w01_l07_two_buttons.tscn"))
	a = game.players[0]
	b = game.players[1]
	place(b, Vector2(3 * TILE, _stand_y(12)))
	await _edges(game.level.get_node("L1"), "кнопка")
	await _load(preload("res://levels/w01_l10_four_colors.tscn"))
	a = game.players[0]
	b = game.players[1]
	place(b, Vector2(8 * TILE, _stand_y(12)))
	await _edges(game.level.get_node("PlateGreen"), "плита")
	finish()


func _edges(plate: PressurePlate, what: String) -> void:
	var half := plate.width_tiles * TILE / 2.0 - 4.0
	for side: int in [-1, 1]:
		for overlap in OVERLAPS:
			# Отойти и дать плите вернуться в покой.
			place(a, Vector2(plate.global_position.x - side * 4.0 * TILE, _stand_y(12)))
			await frames(80)
			var toggles := [0]
			var count := func(_active: bool) -> void: toggles[0] += 1
			plate.changed.connect(count)
			var edge := plate.global_position.x + side * half
			var x := edge + side * (Player.SIZE.x / 2.0 - overlap)
			place(a, Vector2(x, _stand_y(12) - 6.0))
			var active_frames := 0
			for i in 150:  # 2,5 с
				await get_tree().physics_frame
				if plate.active:
					active_frames += 1
			plate.changed.disconnect(count)
			var label := "%s, %s край, заход %d px" % [what, "левый" if side < 0 else "правый", overlap]
			if plate.pulse > 0.0:
				# Нажата один раз на pulse секунд (или вовсе не нажата) — и выскочила.
				check(toggles[0] == 0 or toggles[0] == 2 and not plate.active,
						"%s: срабатываний %d, нажата %d кадров (окно %d)" % [label, toggles[0] / 2, active_frames, roundi(plate.pulse * 60)])
			else:
				# Нажата и держится, пока стоят.
				check(toggles[0] <= 1, "%s: переключений %d, нажата %d из 150 кадров" % [label, toggles[0], active_frames])
				# Сошёл с края — плита отпускается.
				place(a, Vector2(edge + side * (Player.SIZE.x / 2.0 + 8.0), _stand_y(12)))
				await frames(30)
				check(not plate.active, "%s: сошёл — плита отпущена" % label)
