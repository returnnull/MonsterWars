extends Node
## Dev smoke test: bots play levels by pressing each player's actions.
##   godot --headless --path . res://tests/autoplay.tscn
## Env:
##   AUTOPLAY_LEVELS  "c-l,c-l,..." (1-based, e.g. "1-1,1-10"), "bosses", or "all". Default "1-10" (one level with a boss).
##   AUTOPLAY_PLAYERS 1-4 (heroes are picked in order, or AUTOPLAY_HEROES "0,5,9")
##   AUTOPLAY_SECONDS max game seconds per level (0 = just build the level and run 3 s)
##   AUTOPLAY_SPEED   time scale; AUTOPLAY_SHOTS "t1,t2" screenshot times;
##   AUTOPLAY_MORTAL  let players die; AUTOPLAY_RAGE start with full rage.
##   AUTOPLAY_ROSTER  replace each level's waves with every regular enemy type
##                    (N per wave, default 3), to check they can all be killed.
##                    AUTOPLAY_ROSTER_IDS "tank,heli,..." limits it to those ids.

var t := 0.0
var main: Node
var queue: Array = []
var results: Array = []
var current := ""
var log_t := 0.0
var _super_test := false


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


func _ready() -> void:
	Game.set_meta("no_save", true)
	var spec := _env("AUTOPLAY_LEVELS", "1-10")
	if spec == "all":
		for c in 10:
			for l in 10:
				queue.append([c, l])
	elif spec == "bosses":
		for c in 10:
			queue.append([c, 9])
	else:
		for part in spec.split(","):
			var cl := part.split("-")
			queue.append([int(cl[0]) - 1, int(cl[1]) - 1])
	var heroes := _env("AUTOPLAY_HEROES", "")
	Game.party = {}
	for slot in int(_env("AUTOPLAY_PLAYERS", "1")):
		Game.party[slot] = int(heroes.split(",")[slot]) if heroes != "" else slot
	Engine.time_scale = float(_env("AUTOPLAY_SPEED", "1"))
	# AUTOPLAY_SKILLS=1 maxes every hero's level and learns two full branches
	# plus some of the third, so every ability gets exercised.
	if _env("AUTOPLAY_SKILLS", "") != "":
		for h in Content.HEROES.size():
			Game.hero_xp[h] = 999999
			Game.hero_skills[h] = [1, 5, 5, 1, 5, 5, 1, 4, 1, 0]
	if _env("AUTOPLAY_SUPER", "") != "":
		_super_test = true
	_next()


func _next() -> void:
	if main:
		main.queue_free()
		main = null
		await get_tree().process_frame
		await get_tree().process_frame
	if queue.is_empty():
		print("RESULTS: ", " ".join(results))
		get_tree().quit()
		return
	var cl: Array = queue.pop_front()
	Game.level = Content.level(cl[0], cl[1])
	if _env("AUTOPLAY_ROSTER", "") != "":
		_roster_waves(int(_env("AUTOPLAY_ROSTER", "3")))
	current = Game.level["title"]
	t = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _roster_waves(per: int) -> void:
	per = maxi(per, 1)
	var ids := Enemies.regular_ids()
	var only := _env("AUTOPLAY_ROSTER_IDS", "")
	if only != "":
		ids = Array(only.split(","))
	var waves: Array = []
	var x := 35.0
	for i in range(0, ids.size(), per):
		waves.append({"x": x, "title": "ROSTER %d" % (i / per + 1), "spawn": ids.slice(i, i + per)})
		x += 60.0
	Game.level["waves"] = waves
	Game.level["length"] = x - 30.0


func _press(slot: int, a: String) -> void:
	var action := "p%d_%s" % [slot, a]
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


## Holds special and presses `a` with it (a rage skill).
func _press_combo(slot: int, a: String) -> void:
	var special := "p%d_special" % slot
	Input.action_press(special)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_press(slot, a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(special)


func _physics_process(delta: float) -> void:
	if main == null or not main.is_node_ready():
		return
	t += delta
	for p in Game.players:
		if not is_instance_valid(p):
			continue
		if p.max_hp < 99999.0 and _env("AUTOPLAY_MORTAL", "") == "":
			p.max_hp = 99999.0
			p.hp = 99999.0
			if _env("AUTOPLAY_RAGE", "") != "":
				p.add_rage(100.0)
		if _super_test and p.state != Player.S.SUPER:
			p.add_super(2.0)
		_drive(p, delta)
	for st in _env("AUTOPLAY_SHOTS", "").split(",", false):
		if t - delta < float(st) and t >= float(st):
			get_viewport().get_texture().get_image().save_png("user://shot_%s_%03d.png" % [current.replace(" ", "_"), int(float(st))])
			print("shot ", st)
	log_t += delta
	if log_t > 10.0:
		log_t = 0.0
		var held := Game.players.filter(func(q) -> bool: return is_instance_valid(q) and q.weapon != "").size()
		print("%s t=%.0f wave=%d/%d enemies=%d score=%d armed=%d" % [current, t, main._wave, main.waves.size(), _enemies().size(), Game.score, held])
	var limit := float(_env("AUTOPLAY_SECONDS", "400"))
	if limit == 0.0 and t > 3.0:
		results.append("%s:built" % current)
		_next()
	elif main._finished:
		var res := "CLEAR" if main._wave >= main.waves.size() else "LOST"
		print("%s %s at t=%.1f score=%d" % [current, res, t, Game.score])
		for p in Game.players:
			if is_instance_valid(p):
				print("  P%d %s rage skills %s" % [p.slot + 1, p.display_name(), p.rage_uses])
				print("  P%d %s combo specials %s" % [p.slot + 1, p.display_name(), p.combo_uses])
		results.append("%s:%s" % [current, res])
		_next()
	elif limit > 0.0 and t > limit:
		print("%s TIMEOUT wave=%d %s" % [current, main._wave, main.waves[mini(main._wave, main.waves.size() - 1)]["spawn"]])
		results.append("%s:TIMEOUT" % current)
		_next()


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.dead)


func _drive(p: Player, delta: float) -> void:
	var s := p.slot
	var enemies := _enemies()
	var target_x: float = p.x_max
	if enemies.size() > 0:
		target_x = enemies[s % enemies.size()].global_position.x
	Input.action_release("p%d_move_left" % s)
	Input.action_release("p%d_move_right" % s)
	if target_x > p.global_position.x + 3.0:
		Input.action_press("p%d_move_right" % s)
	elif target_x < p.global_position.x - 3.0:
		Input.action_press("p%d_move_left" % s)
	var off := s * 0.07
	if fmod(t + off, 0.35) < delta: _press(s, "light")
	if fmod(t + off, 2.1) < delta: _press(s, "heavy")
	# Grab building pieces lying close by.
	if p.weapon == "" and fmod(t + off, 0.4) < delta:
		for w in get_tree().get_nodes_in_group("weapons"):
			if w.thrower == null and Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length() < Player.GRAB_RANGE:
				_press(s, "heavy")
				break
	if fmod(t + off, 3.3) < delta: _press(s, "jump")
	if fmod(t + off, 3.6) < delta: _press(s, "light")
	# Rage skills: hold special and press a button; tap special for rage mode.
	if fmod(t + off, 0.5) < delta:
		if not p.raging and p.rage >= p.rage_max * 0.9:
			_press(s, "special")
		elif p.can_afford("attack") and randf() < 0.4:
			_press_combo(s, "heavy")
		elif p.can_afford("roar") and randf() < 0.3:
			_press_combo(s, "jump")
		elif p.can_afford("strike"):
			_press_combo(s, "light")
	if p.super_meter >= 100.0 and fmod(t + off, 0.5) < delta: _press(s, "super")
