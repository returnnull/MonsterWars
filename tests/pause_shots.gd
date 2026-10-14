extends Node
## Dev helper: starts level 1-1, opens the pause menu (main list, then
## settings) and saves screenshots to user://.


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: 0, 1: 3}
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.level = Content.level(0, 0)
	add_child(load("res://scenes/main.tscn").instantiate())
	await _wait(4.0)
	await _press("pause")
	await _wait(0.5)
	await _press("p0_move_down")
	await _wait(0.3)
	_shot("pause_menu")
	await _press("p0_move_down")
	await _press("p0_jump")
	await _press("p0_move_down")
	await _press("p0_move_left")
	await _wait(0.3)
	_shot("pause_settings")
	await _press("back")
	await _press("back")
	await _wait(0.5)
	print("paused after resume: ", get_tree().paused)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


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
