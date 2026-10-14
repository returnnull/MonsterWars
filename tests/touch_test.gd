extends Node
## Checks the touch overlay: the stick feeds analog movement, buttons feed
## actions with exactly one "just pressed", and releasing clears everything.
## Run: KAIJU_TOUCH=1 godot --headless --path . res://tests/touch_test.tscn

var _fails := 0
## Frames on which each action was "just pressed".
var _presses := {}


func _process(_delta: float) -> void:
	for a in ["p0_move_up", "p0_heavy"]:
		if Input.is_action_just_pressed(a):
			_presses[a] = int(_presses.get(a, 0)) + 1


func _ready() -> void:
	Game.set_meta("no_save", true)
	await _frames()
	_check(TouchControls.shown, "overlay shown with KAIJU_TOUCH=1")
	# Stick: thumb down at (300, 800), dragged half right and fully up.
	_touch(0, Vector2(300, 800), true)
	_drag(0, Vector2(300 + 75, 800 - 300))
	await _frames()
	_check(Input.get_action_strength("p0_move_up") > 0.8, "stick up strength %.2f" % Input.get_action_strength("p0_move_up"))
	_check(Input.get_action_strength("p0_move_right") > 0.1, "stick right strength %.2f" % Input.get_action_strength("p0_move_right"))
	_check(Input.get_action_strength("p0_move_down") == 0.0, "stick down released")
	# Wobble: a strength change must not count as a new press.
	_drag(0, Vector2(300 + 20, 800 - 300))
	await _frames()
	_check(_presses.get("p0_move_up", 0) == 1, "strength change is not a new press")
	_check(Input.is_action_pressed("p0_move_up"), "still held after wobble")
	# Heavy button with a second finger while the stick is held.
	_touch(1, Vector2(1650, 650), true)
	await _frames()
	await _frames()
	_check(_presses.get("p0_heavy", 0) == 1 and Input.is_action_pressed("p0_heavy"), "heavy pressed once and held")
	# Slide to light.
	_drag(1, Vector2(1490, 800))
	await _frames()
	_check(Input.is_action_pressed("p0_light") and not Input.is_action_pressed("p0_heavy"), "slide heavy -> light")
	_touch(1, Vector2(1490, 800), false)
	_touch(0, Vector2(320, 500), false)
	await _frames()
	_check(not Input.is_action_pressed("p0_light") and not Input.is_action_pressed("p0_move_up"), "all released")
	# Jump also drives menus.
	_touch(2, Vector2(1650, 950), true)
	await _frames()
	_check(Input.is_action_pressed("jump") and Input.is_action_pressed("p0_jump"), "jump feeds menu jump")
	_touch(2, Vector2(1650, 950), false)
	# A gamepad press hides the overlay.
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	Input.parse_input_event(e)
	await _frames()
	_check(not TouchControls.shown, "hidden after gamepad use")
	print("TOUCH TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails else 0)


func _touch(i: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _to_window(pos)
	e.pressed = down
	Input.parse_input_event(e)


func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = _to_window(pos)
	Input.parse_input_event(e)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


## Touch events and the actions they feed each pass through the input buffer.
func _frames() -> void:
	for i in 3:
		await get_tree().process_frame


## The overlay works in the 1920x1080 canvas; events arrive in window pixels.
func _to_window(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos
