extends LevelBot
## Лаборатория: как далеко улетает игрок с крюка — один и цепочкой (Б висит на А, А на крюке).


func _ready() -> void:
	game = await start_game(load("res://tests/lab/lab_room.tscn"))
	a = game.players[0]
	b = game.players[1]
	var hook: Hook = game.level.get_node("Hook")
	for d in [0.0, 30.0, 60.0, 90.0, 120.0]:
		print("один, отпускает правее крюка на %d: %s" % [d, await _single(hook, d)])
	for d in [0.0, 60.0, 120.0, 180.0]:
		print("цепь, отпускает правее крюка на %d: %s" % [d, await _chain(hook, d, false)])
	for d in [60.0, 120.0]:
		print("цепь, А тоже качает, %d: %s" % [d, await _chain(hook, d, true)])
	finish()


func _reset() -> void:
	for key in KEYS_1 + KEYS_2:
		press(key, false)
	await frames(3)
	place(a, Vector2(200, _stand_y(12)))
	place(b, Vector2(300, _stand_y(12)))
	await frames(10)


func _single(hook: Hook, release_dx: float) -> String:
	await _reset()
	place(a, hook.global_position + Vector2(0, 100))
	press(KEYS_1[GRAB], true)
	await frames(2)
	var hung := a.grab_target == hook
	var landing := await _pump_and_fly(a, KEYS_1, hook.global_position.x, release_dx, null, [])
	return "схватился %s, приземлился на %.0f px (%.2f т) правее крюка" % [hung, landing, landing / TILE]


func _chain(hook: Hook, release_dx: float, both: bool) -> String:
	await _reset()
	place(a, hook.global_position + Vector2(0, 100))
	press(KEYS_1[GRAB], true)
	await frames(2)
	place(b, hook.global_position + Vector2(0, 196))
	press(KEYS_2[GRAB], true)
	await frames(2)
	var ok := a.grab_target == hook and b.grab_target == a
	var landing := await _pump_and_fly(b, KEYS_2, hook.global_position.x, release_dx, a, KEYS_1 if both else [])
	return "цепь %s, Б приземлился на %.0f px (%.2f т) правее крюка" % [ok, landing, landing / TILE]


## Раскачка (жмём по ходу), отпускает на взлёте вправо, когда x - hook_x > release_dx.
func _pump_and_fly(p: Player, k: Array[Key], hook_x: float, release_dx: float, helper: Player, kh: Array) -> float:
	var reach := 0.0
	for i in 900:
		var right := p.velocity.x >= 0.0
		press(k[RIGHT], right)
		press(k[LEFT], not right)
		if not kh.is_empty():
			press(kh[RIGHT], right)
			press(kh[LEFT], not right)
		await get_tree().physics_frame
		reach = maxf(reach, p.global_position.x - hook_x)
		if i > 240 and p.global_position.x - hook_x > release_dx and p.velocity.x > 250.0 and p.velocity.y < 0.0:
			break
	if not kh.is_empty():
		press(kh[RIGHT], false)
		press(kh[LEFT], false)
	press(k[LEFT], false)
	press(k[JUMP], true)
	await frames(2)
	press(k[GRAB], false)
	press(k[RIGHT], true)
	var top := p.global_position.y
	for i in 200:
		await get_tree().physics_frame
		top = minf(top, p.global_position.y)
		if i > 5 and p.is_on_floor():
			break
	press(k[JUMP], false)
	press(k[RIGHT], false)
	print("    размах до %.0f, вершина полёта %.0f px над полом" % [reach, 12 * TILE - top - 28])
	return p.global_position.x - hook_x
