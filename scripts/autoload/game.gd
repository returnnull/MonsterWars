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
const SETTINGS_PATH := "user://settings.json"
## Defaults for the options screen. "shake" is a percentage (0-100).
const DEFAULT_SETTINGS := {"rumble": true, "shake": 100, "fullscreen": false, "hints": true}
const SETTING_NAMES := {"rumble": "RUMBLE", "shake": "SCREEN SHAKE", "fullscreen": "FULLSCREEN", "hints": "CONTROLS HELP"}
## Controls overview shown in the pause menu: [action, keyboard, controller].
## Controller names follow the Nintendo Switch layout (see _setup_input).
const CONTROLS := [
	["Move", "WASD / Arrows", "Left stick / D-pad"],
	["Jump", "Space", "B"],
	["Light attack", "J", "Y"],
	["Heavy attack", "K", "X"],
	["Pick up wreckage", "K (on wreckage)", "X (on wreckage)"],
	["Swing / throw weapon", "J / K", "Y / X"],
	["Dodge", "Shift", "A / L"],
	["Rage mode, rage attack", "L", "R / ZR"],
	["Super special", "U", "ZL"],
	["Pause", "Esc / Enter", "+"],
	["Join (players 2-4)", "-", "B on a new controller"],
]

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
## Per hero: total XP and the ranks bought in each of the 10 skill tree nodes.
var hero_xp: Array = []
var hero_skills: Array = []
## XP each hero earned in the level being played (for the end screen).
var xp_gained := {}
## Player options, saved separately from progress so a reset keeps them.
var settings := DEFAULT_SETTINGS.duplicate()

var _combo_timer := 0.0
var _hitstop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_reset_heroes()
	load_progress()
	load_settings()


func _reset_heroes() -> void:
	hero_xp = []
	hero_skills = []
	for i in Content.HEROES.size():
		hero_xp.append(0)
		var ranks := []
		ranks.resize(Skills.NODE_COUNT)
		ranks.fill(0)
		hero_skills.append(ranks)


func hero_level(hero: int) -> int:
	return Skills.level_for_xp(hero_xp[hero])


func free_points(hero: int) -> int:
	return Skills.points_total(hero_xp[hero]) - Skills.points_spent(hero_skills[hero])


## Gives a hero XP and returns how many levels it gained.
func add_xp(hero: int, amount: int) -> int:
	var before := hero_level(hero)
	hero_xp[hero] += amount
	xp_gained[hero] = int(xp_gained.get(hero, 0)) + amount
	return hero_level(hero) - before


func buy_skill(hero: int, idx: int) -> bool:
	if Skills.buy_block(hero_xp[hero], hero_skills[hero], idx) != "":
		return false
	hero_skills[hero][idx] += 1
	save_progress()
	return true


func reset_skills(hero: int) -> void:
	hero_skills[hero].fill(0)
	save_progress()


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
	xp_gained = {}
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
	# Dev tests (tests/*.tscn) set this so they never touch the player's save.
	if has_meta("no_save"):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": unlocked, "best": best_scores, "party": party,
			"hero_xp": hero_xp, "hero_skills": hero_skills}))


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
		var xp = data.get("hero_xp", [])
		var sk = data.get("hero_skills", [])
		for i in mini(xp.size(), hero_xp.size()):
			hero_xp[i] = int(xp[i])
		for i in mini(sk.size(), hero_skills.size()):
			for j in mini(sk[i].size(), Skills.NODE_COUNT):
				hero_skills[i][j] = clampi(int(sk[i][j]), 0, Skills.max_rank(j))


## Settings shown in the options lists, in order.
func setting_keys() -> Array:
	var keys := ["rumble", "shake", "hints"]
	if can_quit():
		keys.insert(2, "fullscreen")
	return keys


## Consoles and the web have no window to quit or resize.
func can_quit() -> bool:
	return not (OS.has_feature("switch") or OS.has_feature("web"))


func setting_text(key: String) -> String:
	if key == "shake":
		return "<  %d%%  >" % int(settings["shake"])
	return "<  %s  >" % ("ON" if settings[key] else "OFF")


## Left/right on an options row: steps screen shake by 25%, flips the rest.
func step_setting(key: String, step: int) -> void:
	if key == "shake":
		set_setting("shake", clampi(int(settings["shake"]) + step * 25, 0, 100))
		return
	set_setting(key, not bool(settings[key]))
	if key == "rumble" and settings["rumble"]:
		for d in Input.get_connected_joypads():
			rumble(d, 0.5, 0.7, 0.3)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


func apply_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(settings["fullscreen"])
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


func save_settings() -> void:
	if has_meta("no_save"):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f else null
		if data is Dictionary:
			for k in DEFAULT_SETTINGS:
				if data.has(k):
					settings[k] = type_convert(data[k], typeof(DEFAULT_SETTINGS[k]))
	settings["shake"] = clampi(int(settings["shake"]), 0, 100)
	apply_settings()


## Starts a rumble on a gamepad, unless rumble is switched off in the options.
func rumble(device: int, weak: float, strong: float, duration: float) -> void:
	if settings["rumble"] and device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


func shake(amount: float) -> void:
	if camera_rig and is_instance_valid(camera_rig):
		camera_rig.shake(amount * float(settings["shake"]) / 100.0)


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
		_action(pre + "super", [KEY_U] if kb else [], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], slot)
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
