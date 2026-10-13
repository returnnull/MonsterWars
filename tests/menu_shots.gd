extends Node
## Dev helper: walks through the menus and saves screenshots to user://.

var menu: Node


func _ready() -> void:
	Game.unlocked = 23
	menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _wait(1.0)
	await _press("p0_jump")
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
	await _press("p0_move_right")
	await _press("p0_move_right")
	await _wait(0.5)
	_shot("menu_map")
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
