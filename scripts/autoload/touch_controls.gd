extends CanvasLayer
## On-screen touch controls for phones and tablets (autoload "TouchControls").
##
## Drives player slot 0 by feeding the same input actions a gamepad would
## ("p0_light", "jump", ...), so menus and gameplay need no touch code of their
## own. The left half of the screen is a floating stick that appears where the
## thumb lands; the right side holds the face buttons in the Switch layout,
## plus rage, super and pause.
##
## Menus switch it to menu buttons (menu_buttons()): only the buttons that do
## something on that screen are shown, renamed to what they do ("OK" in green,
## "BACK" in red), so it is clear which one accepts.
##
## Shown on touchscreens (and on desktop with KAIJU_TOUCH=1, where the mouse
## acts as a finger). Hidden again as soon as a gamepad or keyboard is used,
## and back on the next touch.

const STICK_RADIUS := 150.0
## Stick deflection (0-1) below which no direction is pressed.
const STICK_DEADZONE := 0.25
## The stick only starts in this part of the screen (1920x1080 canvas).
const STICK_ZONE := Rect2(0, 260, 900, 820)
const BUTTON_RADIUS := 82.0
## [label, position, radius, actions fed while held].
const BUTTONS := [
	["JUMP", Vector2(1650, 950), BUTTON_RADIUS, ["p0_jump", "jump"]],
	["LIGHT", Vector2(1490, 800), BUTTON_RADIUS, ["p0_light"]],
	["HEAVY", Vector2(1650, 650), BUTTON_RADIUS, ["p0_heavy"]],
	["DODGE", Vector2(1810, 800), BUTTON_RADIUS, ["p0_dodge", "back"]],
	["RAGE", Vector2(1310, 950), 72.0, ["p0_special"]],
	["SUPER", Vector2(1310, 620), 72.0, ["p0_super"]],
	["II", Vector2(1850, 70), 48.0, ["pause"]],
]
const MOVE_ACTIONS := ["p0_move_left", "p0_move_right", "p0_move_up", "p0_move_down"]
const OK_COLOR := Color(0.35, 1.0, 0.5)
const BACK_COLOR := Color(1.0, 0.4, 0.35)

## True while the overlay is drawn and listening.
var shown := false

var _enabled := false
var _draw: Control
## Finger index of the stick touch, or -1.
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
## Finger index -> button index it is holding.
var _fingers := {}
## Action -> current strength (0 = released), so only changes are sent.
var _strength := {}
## Menu mode: button name ("JUMP", "DODGE", ...) -> label shown instead.
## Buttons left out are hidden. Empty = the in-game layout.
var _menu := {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
			or OS.get_environment("KAIJU_TOUCH") == "1"
	if OS.get_environment("KAIJU_TOUCH") == "1":
		Input.emulate_touch_from_mouse = true
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	_set_shown(_enabled and Input.get_connected_joypads().is_empty())


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		if not shown:
			_set_shown(true)
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif shown and (event is InputEventJoypadButton or (event is InputEventKey and not event.echo)):
		_set_shown(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_all()


## Switches to menu buttons, e.g. {"JUMP": "OK", "DODGE": "BACK"}. The
## buttons keep their places and actions; only the named ones are shown.
func menu_buttons(labels: Dictionary) -> void:
	if labels == _menu:
		return
	_menu = labels.duplicate()
	_release_all()


## Back to the full in-game layout.
func game_buttons() -> void:
	menu_buttons({})


func in_menu() -> bool:
	return not _menu.is_empty()


func _active(i: int) -> bool:
	return _menu.is_empty() or _menu.has(BUTTONS[i][0])


func _radius(i: int) -> float:
	var r: float = BUTTONS[i][2]
	# The menu's confirm button is the one to find at a glance.
	return r * 1.2 if not _menu.is_empty() and BUTTONS[i][0] == "JUMP" else r


func _set_shown(on: bool) -> void:
	shown = on
	visible = on
	if not on:
		_release_all()


func _touch_down(finger: int, pos: Vector2) -> void:
	var b := _button_at(pos)
	if b >= 0:
		_fingers[finger] = b
		_refresh_buttons()
	elif _stick_finger < 0 and STICK_ZONE.has_point(pos):
		_stick_finger = finger
		_stick_origin = pos
		_set_stick(Vector2.ZERO)


func _touch_move(finger: int, pos: Vector2) -> void:
	if finger == _stick_finger:
		var v := (pos - _stick_origin) / STICK_RADIUS
		if v.length() > 1.0:
			# Drag the base along so reversing direction is instant.
			_stick_origin += (pos - _stick_origin) - v.normalized() * STICK_RADIUS
			v = v.normalized()
		_set_stick(v)
	elif _fingers.has(finger):
		# Sliding a thumb onto a neighbouring button switches to it.
		var b := _button_at(pos)
		if b >= 0 and b != _fingers[finger]:
			_fingers[finger] = b
			_refresh_buttons()


func _touch_up(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		_set_stick(Vector2.ZERO)
	elif _fingers.erase(finger):
		_refresh_buttons()


func _button_at(pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in BUTTONS.size():
		if not _active(i):
			continue
		# A little slack around each button makes them easier to hit.
		var d: float = pos.distance_to(BUTTONS[i][1]) - _radius(i) * 1.2
		if d <= 0.0 and d < best_d:
			best = i
			best_d = d
	return best


func _set_stick(v: Vector2) -> void:
	_stick_vec = v
	var len := v.length()
	var dir := Vector2.ZERO
	if len > STICK_DEADZONE:
		dir = v.normalized() * inverse_lerp(STICK_DEADZONE, 1.0, minf(len, 1.0))
	_feed("p0_move_left", maxf(-dir.x, 0.0))
	_feed("p0_move_right", maxf(dir.x, 0.0))
	_feed("p0_move_up", maxf(-dir.y, 0.0))
	_feed("p0_move_down", maxf(dir.y, 0.0))
	_draw.queue_redraw()


func _refresh_buttons() -> void:
	var held := {}
	for b in _fingers.values():
		for a in BUTTONS[b][3]:
			held[a] = true
	for b in BUTTONS:
		for a in b[3]:
			_feed(a, 1.0 if held.has(a) else 0.0)
	_draw.queue_redraw()


## Sends an action event when its strength changes. Directions snap to steps
## of 0.1 so a wobbling thumb does not flood the input queue.
func _feed(action: String, strength: float) -> void:
	strength = snappedf(strength, 0.1)
	if is_equal_approx(float(_strength.get(action, 0.0)), strength):
		return
	_strength[action] = strength
	var e := InputEventAction.new()
	e.action = action
	e.pressed = strength > 0.0
	e.strength = strength
	Input.parse_input_event(e)


func _release_all() -> void:
	_fingers.clear()
	_stick_finger = -1
	for a in _strength.keys():
		_feed(a, 0.0)
	_stick_vec = Vector2.ZERO
	if _draw:
		_draw.queue_redraw()


func _on_draw() -> void:
	var held := {}
	for b in _fingers.values():
		held[b] = true
	var font := ThemeDB.fallback_font
	# Stick: a faint hint where it rests, the real base while a thumb is down.
	var base := _stick_origin if _stick_finger >= 0 else Vector2(330, 800)
	# Fainter at rest in menus, where it sits over the menu items.
	var alpha := 0.55 if _stick_finger >= 0 else (0.15 if not _menu.is_empty() else 0.25)
	_draw.draw_circle(base, STICK_RADIUS, Color(0, 0, 0, alpha * 0.5))
	_draw.draw_arc(base, STICK_RADIUS, 0, TAU, 64, Color(1, 1, 1, alpha), 4.0, true)
	_draw.draw_circle(base + _stick_vec * STICK_RADIUS, 62.0, Color(1, 1, 1, alpha + 0.15))
	if not _menu.is_empty() and _stick_finger < 0:
		var mw := font.get_string_size("MOVE", HORIZONTAL_ALIGNMENT_CENTER, -1, 26).x
		_draw.draw_string(font, base + Vector2(-mw * 0.5, STICK_RADIUS + 40), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.5))
	for i in BUTTONS.size():
		if not _active(i):
			continue
		var pos: Vector2 = BUTTONS[i][1]
		var r := _radius(i)
		var on := held.has(i)
		var text: String = _menu.get(BUTTONS[i][0], BUTTONS[i][0])
		var tint := Color.WHITE
		if not _menu.is_empty():
			tint = OK_COLOR if BUTTONS[i][0] == "JUMP" else BACK_COLOR if BUTTONS[i][0] == "DODGE" else Color(0.55, 0.8, 1.0)
		elif text == "RAGE":
			tint = Color(1.0, 0.45, 0.25)
		elif text == "SUPER":
			tint = Color(0.7, 0.45, 1.0)
		var fill := (0.5 if on else 0.32) if not _menu.is_empty() else (0.5 if on else 0.18)
		_draw.draw_circle(pos, r, Color(tint.r, tint.g, tint.b, fill))
		_draw.draw_arc(pos, r, 0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.9), 5.0 if not _menu.is_empty() else 4.0, true)
		var size := 30 if r > 60.0 else 26
		# Long menu labels shrink to fit inside the circle.
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		while w > r * 1.7 and size > 16:
			size -= 2
			w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		_draw.draw_string(font, pos + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.95))
