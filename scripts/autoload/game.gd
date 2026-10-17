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
signal trophy_unlocked(id: String)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_DEBRIS := 8
const MAX_PLAYERS := 4
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
## Defaults for the options screen. "shake" is a percentage (0-100).
## "difficulty" indexes DIFFICULTIES.
const DEFAULT_SETTINGS := {"difficulty": 1, "rumble": true, "shake": 100, "fullscreen": false, "hints": true}
const SETTING_NAMES := {"difficulty": "DIFFICULTY", "rumble": "RUMBLE", "shake": "SCREEN SHAKE",
	"fullscreen": "FULLSCREEN", "hints": "CONTROLS HELP"}
## Enemy health and damage multipliers, and the XP bonus for the risk.
const DIFFICULTIES := [
	{"name": "EASY", "hp": 0.7, "dmg": 0.6, "xp": 1.0, "color": Color(0.45, 0.95, 0.6),
		"desc": "Weaker enemies that hit softly. For learning the ropes and playing with kids."},
	{"name": "NORMAL", "hp": 1.0, "dmg": 1.0, "xp": 1.0, "color": Color(1.0, 0.8, 0.35),
		"desc": "The intended challenge."},
	{"name": "HARD", "hp": 1.4, "dmg": 1.5, "xp": 1.3, "color": Color(1.0, 0.35, 0.3),
		"desc": "Tougher enemies that hit much harder. +30% XP."},
]
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
	["Rage strike", "L + J", "R + Y"],
	["War roar", "L + Space", "R + B"],
	["Rage attack", "L + K", "R + X"],
	["Rage mode on / off", "Tap L", "Tap R / ZR"],
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
## Per hero: the option picked in each tier of its super tree (-1 for none).
var hero_supers: Array = []
## XP each hero earned in the level being played (for the end screen).
var xp_gained := {}
## Player options, saved separately from progress so a reset keeps them.
var settings := DEFAULT_SETTINGS.duplicate()
## Lifetime counters that trophies are earned from (see Trophies), the
## trophies earned ({id: true}) and what each hero wears: {"hero index":
## {slot: cosmetic id}} (see Cosmetics).
var stats := {}
var trophies := {}
var outfits := {}
## The level being played, for the trophies checked when it is cleared:
## time played, whether anyone got hurt or used rage. Trophies earned in it
## are listed on the end screen.
var run := {}
var new_trophies: Array = []

var _combo_timer := 0.0
var _hitstop_active := false
var _toasts: Array = []
var _toast_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_reset_heroes()
	load_progress()
	load_settings()
	_keep_web_storage()
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 90
	add_child(_toast_layer)


## Saves on the way out: closing the window, or a phone/browser putting the
## game in the background (it may be killed there without warning).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_progress()


## In the browser user:// lives in IndexedDB, which the browser may clear
## when space runs low. Asking for persistent storage keeps saves safe.
func _keep_web_storage() -> void:
	if OS.has_feature("web") and not has_meta("no_save"):
		JavaScriptBridge.eval("navigator.storage && navigator.storage.persist && navigator.storage.persist()", true)


func difficulty() -> Dictionary:
	return DIFFICULTIES[clampi(int(settings["difficulty"]), 0, DIFFICULTIES.size() - 1)]


func _reset_heroes() -> void:
	hero_xp = []
	hero_skills = []
	hero_supers = []
	for i in Content.HEROES.size():
		hero_xp.append(0)
		hero_skills.append(Skills.empty_ranks(i))
		hero_supers.append(SuperTree.empty_picks())


func hero_level(hero: int) -> int:
	return Skills.level_for_xp(hero_xp[hero])


func free_points(hero: int) -> int:
	return Skills.points_total(hero_xp[hero]) - Skills.points_spent(hero, hero_skills[hero])


## Gives a hero XP and returns how many levels it gained.
func add_xp(hero: int, amount: int) -> int:
	var before := hero_level(hero)
	hero_xp[hero] += amount
	xp_gained[hero] = int(xp_gained.get(hero, 0)) + amount
	if hero_level(hero) != before:
		check_trophies()
	return hero_level(hero) - before


func buy_skill(hero: int, idx: int) -> bool:
	if Skills.buy_block(hero, hero_xp[hero], hero_skills[hero], idx) != "":
		return false
	hero_skills[hero][idx] += 1
	if Skills.is_capstone(hero, idx):
		track("branch_ends")
	save_progress()
	return true


## Picks one option in a tier of a hero's super tree, replacing the tier's
## earlier pick. False while the tier is still locked.
func pick_super(hero: int, tier: int, idx: int) -> bool:
	if tier >= SuperTree.tiers_open(hero_level(hero)):
		return false
	hero_supers[hero][tier] = idx
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
	run = {"time": 0.0, "hurt": false, "rage": false}
	new_trophies = []
	Engine.time_scale = 1.0
	_hitstop_active = false


func add_score(value: int) -> void:
	score += value
	score_changed.emit(score)


func register_hit() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	if combo > int(stats.get("best_combo", 0)):
		stats["best_combo"] = combo
		check_trophies("best_combo")
	_combo_timer = 1.6
	combo_changed.emit(combo)


func on_building_destroyed(building: Node3D, height: float) -> void:
	buildings_destroyed += 1
	track("buildings")
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
	# Keeps XP earned in a level that was left through the pause menu.
	save_progress()
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_meta("menu_screen", screen)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func complete_level(lvl: Dictionary, final_score: int) -> void:
	var g: int = lvl["global"]
	unlocked = maxi(unlocked, mini(g + 1, Content.COUNTRIES.size() * Content.LEVELS_PER_COUNTRY - 1))
	best_scores[str(g)] = maxi(int(best_scores.get(str(g), 0)), final_score)
	save_progress()


# --- trophies and cosmetics -------------------------------------------------

## Adds to a lifetime stat and awards any trophy it completes.
func track(stat: String, amount: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount
	check_trophies(stat)


## Counts a defeated enemy by its kind and class (see Trophies).
func count_kill(kind: String) -> void:
	var cls: String = "boss" if kind == "boss" else String(Enemies.get_def(kind).get("class", "kaiju"))
	track("kills")
	track("kills_" + cls)
	track("kills_" + kind)


## Stats for a cleared level: bosses, the final boss per difficulty and the
## special clears (see Trophies).
func level_won(lvl: Dictionary) -> void:
	var g: int = lvl["global"]
	var diff := int(settings["difficulty"])
	track("clears")
	track("score", score)
	if g % Content.LEVELS_PER_COUNTRY == Content.LEVELS_PER_COUNTRY - 1:
		track("boss_%d" % int(lvl["country"]))
		if diff == 2:
			track("clears_hard_boss")
		if not run.get("rage", false):
			track("clears_zen")
	if g == Content.COUNTRIES.size() * Content.LEVELS_PER_COUNTRY - 1:
		track("final_%d" % diff)
	if not run.get("hurt", false):
		track("clears_flawless")
	for p in living_players():
		if p.hp < p.max_hp * 0.1:
			track("clears_close")
			break
	if buildings_total > 0 and buildings_destroyed >= buildings_total:
		track("clears_wrecked")
	if buildings_total > 0 and buildings_destroyed == 0:
		track("clears_tourist")
	if float(run.get("time", 999.0)) < Trophies.FAST_CLEAR:
		track("clears_fast")
	if players.size() >= 2:
		track("clears_coop")
	if players.size() >= 4:
		track("clears_coop4")
	for p in players:
		if is_instance_valid(p):
			track("clear_hero_%d" % p.hero)


## Awards every trophy whose goal is reached (only those counting `stat`,
## if given). Quiet ones (from loading a save) show no banner.
func check_trophies(stat: String = "", quiet: bool = false) -> void:
	for t: Dictionary in Trophies.LIST:
		if trophies.has(t["id"]):
			continue
		var counts: Array = t["stat"] if t["stat"] is Array else [t["stat"]]
		if stat != "" and not stat in counts:
			continue
		var p: Vector2i = Trophies.progress(t)
		if p.x >= p.y:
			trophies[t["id"]] = true
			if not quiet:
				new_trophies.append(t["id"])
				trophy_unlocked.emit(t["id"])
				_toast(t)
				save_progress()


func has_trophy(id: String) -> bool:
	return trophies.has(id)


func item_unlocked(item_id: String) -> bool:
	var t := Trophies.for_item(item_id)
	return not t.is_empty() and trophies.has(t["id"])


## What a hero wears: {slot: cosmetic id}, unlocked items only.
func outfit(hero: int) -> Dictionary:
	var o: Dictionary = outfits.get(str(hero), {})
	var out := {}
	for slot in o:
		if item_unlocked(String(o[slot])):
			out[slot] = String(o[slot])
	return out


## Puts an unlocked item on a hero ("" takes the slot off).
func wear(hero: int, slot: String, item_id: String) -> void:
	var o: Dictionary = outfit(hero).duplicate()
	if item_id == "":
		o.erase(slot)
	elif item_unlocked(item_id) and Cosmetics.item(item_id).get("slot", "") == slot:
		o[slot] = item_id
	else:
		return
	outfits[str(hero)] = o
	save_progress()


## A banner at the top of the screen for a new trophy. Several in a row wait
## their turn.
func _toast(t: Dictionary) -> void:
	_toasts.append(t)
	if _toasts.size() == 1:
		_show_toast()


func _show_toast() -> void:
	if _toasts.is_empty() or _toast_layer == null:
		return
	var t: Dictionary = _toasts[0]
	var panel := Panel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.size = Vector2(760, 112)
	panel.position = Vector2((1920 - 760) * 0.5, -130)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.06, 0.12, 0.92)
	st.border_color = Color(1.0, 0.8, 0.35)
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.shadow_color = Color(1.0, 0.6, 0.2, 0.4)
	st.shadow_size = 16
	panel.add_theme_stylebox_override("panel", st)
	_toast_layer.add_child(panel)
	var head := _toast_label(panel, "TROPHY:  " + String(t["name"]).to_upper(), 12, 36, Color(1.0, 0.85, 0.4))
	head.size.x = panel.size.x
	var item: Dictionary = Cosmetics.item(t["item"])
	var sub := _toast_label(panel, "New %s item: %s" % [String(item.get("slot", "")), item.get("name", "")], 62, 26, Color(1, 1, 1, 0.9))
	sub.size.x = panel.size.x
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", 24.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(panel, "position:y", -130.0, 0.3)
	tw.tween_callback(func() -> void:
		panel.queue_free()
		_toasts.pop_front()
		_show_toast())


func _toast_label(parent: Control, text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = 5
	ls.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = ls
	parent.add_child(l)
	return l


func save_progress() -> void:
	# Dev tests (tests/*.tscn) set this so they never touch the player's save.
	if has_meta("no_save"):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": unlocked, "best": best_scores, "party": party,
			"hero_xp": hero_xp, "hero_skills": hero_skills, "hero_supers": hero_supers, "skill_ver": Skills.SAVE_VERSION, "stats": stats, "trophies": trophies.keys(),
			"outfits": outfits}))
		# Closing flushes the file (and on the web syncs it to IndexedDB).
		f.close()


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
		# Older saves used one tree shape for every hero: their points are refunded.
		if int(data.get("skill_ver", 1)) != Skills.SAVE_VERSION:
			sk = []
		for i in mini(sk.size(), hero_skills.size()):
			for j in mini(sk[i].size(), Skills.node_count(i)):
				hero_skills[i][j] = clampi(int(sk[i][j]), 0, Skills.max_rank(i, j))
		var sp = data.get("hero_supers", [])
		if sp is Array:
			for i in mini(sp.size(), hero_supers.size()):
				if sp[i] is Array:
					for t in mini(sp[i].size(), SuperTree.TIERS):
						var n := SuperTree.options(i, t).size()
						var v := int(sp[i][t])
						hero_supers[i][t] = v if v >= 0 and v < n else -1
		var st = data.get("stats", {})
		if st is Dictionary:
			for k in st:
				stats[k] = int(st[k])
		var tr = data.get("trophies", [])
		if tr is Array:
			for id in tr:
				trophies[String(id)] = true
		var of = data.get("outfits", {})
		if of is Dictionary:
			for h in of:
				if of[h] is Dictionary:
					outfits[str(h)] = of[h]
	# Saves from before trophies: bosses already beaten count.
	for c in Content.COUNTRIES.size():
		if unlocked >= (c + 1) * Content.LEVELS_PER_COUNTRY and int(stats.get("boss_%d" % c, 0)) == 0:
			stats["boss_%d" % c] = 1
	check_trophies("", true)


## Settings shown in the options lists, in order.
func setting_keys() -> Array:
	var keys := ["difficulty", "rumble", "shake", "hints"]
	if can_quit():
		keys.insert(3, "fullscreen")
	return keys


## Consoles and the web have no window to quit or resize.
func can_quit() -> bool:
	return not (OS.has_feature("switch") or OS.has_feature("web"))


func setting_text(key: String) -> String:
	if key == "shake":
		return "<  %d%%  >" % int(settings["shake"])
	if key == "difficulty":
		return "<  %s  >" % difficulty()["name"]
	return "<  %s  >" % ("ON" if settings[key] else "OFF")


## Left/right on an options row: steps screen shake by 25%, cycles the
## difficulty, flips the rest.
func step_setting(key: String, step: int) -> void:
	if key == "shake":
		set_setting("shake", clampi(int(settings["shake"]) + step * 25, 0, 100))
		return
	if key == "difficulty":
		set_setting("difficulty", posmod(int(settings["difficulty"]) + step, DIFFICULTIES.size()))
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
		f.close()


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f else null
		if data is Dictionary:
			for k in DEFAULT_SETTINGS:
				if data.has(k):
					settings[k] = type_convert(data[k], typeof(DEFAULT_SETTINGS[k]))
	settings["shake"] = clampi(int(settings["shake"]), 0, 100)
	settings["difficulty"] = clampi(int(settings["difficulty"]), 0, DIFFICULTIES.size() - 1)
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
