extends Node
## Dev check: Settings > CHEATS. A wrong code typed on the keyboard does
## nothing, and 1337 pressed on the keypad with the controller makes every
## kaiju level 25 with 50 skill points and its whole super tree.
## Run: godot --headless --path . res://tests/cheat_test.tscn
## (SHOTS=1 with a display saves user://menu_cheats.png.)

var menu: Node
var _fails := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	for i in Content.HEROES.size():
		Game.hero_xp[i] = 0
		Game.reset_skills(i)
	Game.hero_xp[2] = 99999
	menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _wait(0.5)
	# Title: SETTINGS is the third item; CHEATS sits just above BACK.
	await _press("p0_move_down")
	await _press("p0_move_down")
	await _press("p0_jump")
	await _press("p0_move_up")
	await _press("p0_move_up")
	await _press("p0_jump")
	await _wait(0.3)
	_check(menu.screen == menu.Screen.CHEATS, "CHEATS opens from Settings")

	for k in [KEY_4, KEY_2, KEY_ENTER]:
		await _key(k)
	_check(menu._ch_result.text == "WRONG CODE", "a wrong code says so")
	_check(Game.hero_level(0) == 1, "a wrong code changes nothing")

	# 1, 3, 3, 7, OK on the keypad (1 2 3 / 4 5 6 / 7 8 9 / DEL 0 OK).
	for a in ["jump", "move_right", "move_right", "jump", "jump", "move_down", "move_down",
			"move_left", "move_left", "jump", "move_down", "move_right", "move_right"]:
		await _press("p0_" + a)
	if OS.get_environment("SHOTS") == "1":
		await _wait(0.3)
		get_viewport().get_texture().get_image().save_png("user://menu_cheats_typed.png")
	await _press("p0_jump")
	_check(menu._ch_result.text.begins_with("ALL KAIJU"), "1337 is accepted")
	for h in Content.HEROES.size():
		var n: String = Content.hero(h)["name"]
		_check(Game.hero_level(h) == Skills.MAX_LEVEL, "%s is level 25" % n)
		_check(Game.free_points(h) == Skills.MAX_LEVEL * Skills.POINTS_PER_LEVEL, "%s has every skill point" % n)
		_check(SuperTree.tiers_open(Game.hero_level(h)) == SuperTree.TIERS, "%s has its whole super tree" % n)
	_check(Game.hero_xp[2] == 99999, "XP above level 25 is kept")
	if OS.get_environment("SHOTS") == "1":
		await _wait(0.3)
		get_viewport().get_texture().get_image().save_png("user://menu_cheats.png")
	await _press("p0_dodge")
	await _wait(0.3)
	_check(menu.screen == menu.Screen.SETTINGS, "back returns to Settings")

	print("CHEAT TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		_fails += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _press(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.05)
	var r := InputEventAction.new()
	r.action = a
	r.pressed = false
	Input.parse_input_event(r)
	await _wait(0.05)


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.05)
	var r := InputEventKey.new()
	r.keycode = k
	r.pressed = false
	Input.parse_input_event(r)
	await _wait(0.05)
