extends Node
## Global game state, input mapping and small helpers (autoload "Game").
##
## Input is mapped in code. Every player slot gets its own actions
## ("p0_light", "p1_jump", ...): slot N listens to gamepad N, and slot 0 also
## listens to the keyboard. The unprefixed "jump" and "pause" actions listen to
## every device and drive menus. Buttons are positional, so on a Nintendo
## Switch layout: bottom = B, right = A, left = Y, top = X.

signal score_changed(score: int)
signal destruction_changed(destroyed: int, total: int)
signal combo_changed(hits: int)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_DEBRIS := 8
const MAX_PLAYERS := 4
const SAVE_PATH := "user://save.json"

var score := 0
var buildings_total := 0
var buildings_destroyed := 0
var combo := 0
var best_combo := 0
var world: Node3D
var camera_rig: Node
var players: Array[Node3D] = []
## Chosen heroes per slot, set in the menu: {slot: hero_index}.
var party := {0: 0}
## The level being played (a Content.level() dictionary).
var level: Dictionary = {}
## Highest unlocked global level (0-99) and best scores per level.
var unlocked := 0
var best_scores := {}

var _combo_timer := 0.0
var _hitstop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_progress()


func _process(delta: float) -> void:
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(combo)


func reset() -> void:
	score = 0
	buildings_total = 0
	buildings_destroyed = 0
	combo = 0
	best_combo = 0
	players.clear()
	Engine.time_scale = 1.0
	_hitstop_active = false


func add_score(value: int) -> void:
	score += value
	score_changed.emit(score)


func register_hit() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	_combo_timer = 1.6
	combo_changed.emit(combo)


func on_building_destroyed(building: Node3D, height: float) -> void:
	buildings_destroyed += 1
	add_score(int(height * 60.0))
	for p in living_players():
		p.add_rage(12.0)
	destruction_changed.emit(buildings_destroyed, buildings_total)


func living_players() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p in players:
		if is_instance_valid(p) and not p.dead:
			out.append(p)
	return out


func nearest_player(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in living_players():
		var d := p.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func destruction_percent() -> int:
	if buildings_total == 0:
		return 0
	return int(round(100.0 * buildings_destroyed / buildings_total))


func start_level(country_idx: int, level_idx: int) -> void:
	level = Content.level(country_idx, level_idx)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func go_to_menu(screen: String = "map") -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_meta("menu_screen", screen)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func complete_level(lvl: Dictionary, final_score: int) -> void:
	var g: int = lvl["global"]
	unlocked = maxi(unlocked, mini(g + 1, Content.COUNTRIES.size() * Content.LEVELS_PER_COUNTRY - 1))
	best_scores[str(g)] = maxi(int(best_scores.get(str(g), 0)), final_score)
	save_progress()


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": unlocked, "best": best_scores, "party": party}))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if data is Dictionary:
		unlocked = int(data.get("unlocked", 0))
		best_scores = data.get("best", {})
		var saved_party = data.get("party", {})
		if saved_party is Dictionary and not saved_party.is_empty():
			party = {}
			for k in saved_party:
				party[int(k)] = int(saved_party[k])


func shake(amount: float) -> void:
	if camera_rig and is_instance_valid(camera_rig):
		camera_rig.shake(amount)


## Freezes time for a few frames to sell the weight of a hit.
func hitstop(duration: float = 0.06) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func _setup_input() -> void:
	for slot in MAX_PLAYERS:
		var kb := slot == 0
		var pre := "p%d_" % slot
		_action(pre + "move_left", [KEY_A, KEY_LEFT] if kb else [], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]], slot)
		_action(pre + "move_right", [KEY_D, KEY_RIGHT] if kb else [], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]], slot)
		_action(pre + "move_up", [KEY_W, KEY_UP] if kb else [], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]], slot)
		_action(pre + "move_down", [KEY_S, KEY_DOWN] if kb else [], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]], slot)
		_action(pre + "jump", [KEY_SPACE] if kb else [], [JOY_BUTTON_A], [], slot)
		_action(pre + "light", [KEY_J] if kb else [], [JOY_BUTTON_X], [], slot)
		_action(pre + "heavy", [KEY_K] if kb else [], [JOY_BUTTON_Y], [], slot)
		_action(pre + "dodge", [KEY_SHIFT] if kb else [], [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], [], slot)
		_action(pre + "special", [KEY_L] if kb else [], [JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], slot)
	_action("jump", [KEY_SPACE], [JOY_BUTTON_A], [], -1)
	_action("pause", [KEY_ESCAPE, KEY_ENTER], [JOY_BUTTON_START], [], -1)
	_action("back", [KEY_SHIFT, KEY_BACKSPACE], [JOY_BUTTON_B], [], -1)


func _action(action: String, keys: Array, buttons: Array, axes: Array, device: int) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.device = device
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.device = device
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
