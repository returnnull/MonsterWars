extends Node
## Dev helper: walks through the menus and saves screenshots to user://.

var menu: Node


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.unlocked = 23
	menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _wait(5.0)
	_shot("menu_title")
	await _press("p0_move_down")
	await _press("p0_jump")
	await _press("p0_move_down")
	await _press("p0_move_left")
	await _wait(0.5)
	_shot("menu_settings")
	await _press("p0_move_right")
	await _press("p0_dodge")
	await _wait(0.3)
	await _press("p0_jump")
	await _wait(0.5)
	_shot("menu_difficulty")
	await _press("p0_jump")
	await _wait(0.5)
	# Skill tree for hero 0 at about level 17.
	Game.hero_xp[0] = 8000
	Game.reset_skills(0)
	await _press("p0_heavy")
	await _wait(0.3)
	await _press("p0_jump")
	await _press("p0_move_down")
	for i in 5:
		await _press("p0_jump")
	await _press("p0_move_down")
	for i in 5:
		await _press("p0_jump")
	await _press("p0_move_down")
	await _press("p0_jump")
	await _press("p0_move_left")
	await _press("p0_move_up")
	await _press("p0_move_up")
	for i in 4:
		await _press("p0_jump")
	await _press("p0_move_down")
	await _wait(0.6)
	_shot("menu_skills")
	await _press("p0_dodge")
	await _wait(0.5)
	await _press("p1_jump")
	await _press("p2_jump")
	await _press("p1_move_right")
	await _press("p1_move_right")
	await _press("p2_move_right")
	await _press("p2_move_right")
	await _press("p2_move_right")
	await _press("p2_move_right")
	await _press("p2_move_right")
	await _press("p0_jump")
	await _wait(2.0)
	_shot("menu_heroes")
	await _press("p1_jump")
	await _press("p2_jump")
	await _wait(1.0)
	await _press("p0_move_left")
	await _press("p0_move_down")
	await _wait(0.5)
	_shot("menu_map")
	await _press("p0_move_up")
	await _press("p0_jump")
	await _wait(0.5)
	_shot("menu_levels")
	get_tree().quit()


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


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("user://%s.png" % n)
	print("shot ", n)
