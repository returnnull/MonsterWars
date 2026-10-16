extends Node
## Dev check for the anti-spam rules and the jump, with real button presses:
## mashing light or heavy can't chain combos back to back (ATTACK_RECOVERY),
## rage skills can't be fired off in a row, combos still chain, and a jump
## crouches first, then leaves the ground and lands. Prints PASS/FAIL per step.

var main: Node
var p: Player
## [time, attack] for every attack the player started (filled by _watch).
var seen: Array = []
var _t := 0.0


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: 0}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	p = Game.players[0]
	p.max_hp = 99999.0
	p.hp = 99999.0
	for n in get_tree().get_nodes_in_group("enemies"):
		n.queue_free()
	await _wait(0.3)
	_watch()

	# Mash light for 3 seconds: combos happen, but each finisher is followed
	# by a pause before the next combo starts.
	await _mash("light", 3.0)
	var names := seen.map(func(s): return s[1])
	_check("mashing light still plays the combo", names.slice(0, 3) == ["light1", "light2", "light3"], "%s" % [names])
	var gap := _gap_after("light3")
	_check("pause after the tail spin", gap >= Player.ATTACK_RECOVERY["light3"] - 0.03, "%.2fs" % gap)
	await _settle()

	# Mash heavy: Titan Crush, then a long pause.
	await _mash("heavy", 3.0)
	names = seen.map(func(s): return s[1])
	_check("mashing heavy plays titan crush", names.slice(0, 3) == ["heavy", "heavy2", "heavy3"], "%s" % [names])
	_check("long pause after titan crush", _gap_after("heavy3") >= Player.ATTACK_RECOVERY["heavy3"] - 0.03,
		"%.2fs" % _gap_after("heavy3"))
	await _settle()

	# Rage mode: mashing light spits three fireballs, then has to wait.
	p.rage = 100.0
	p._enter_rage_mode()
	await _wait(0.5)
	await _mash("light", 2.0)
	names = seen.map(func(s): return s[1])
	_check("rage light mash = 3 fireballs", names.slice(0, 3) == ["fire1", "fire2", "fire3"], "%s" % [names])
	_check("pause after the big fireball", _gap_after("fire3") >= Player.ATTACK_RECOVERY["fire3"] - 0.03,
		"%.2fs" % _gap_after("fire3"))
	p._exit_rage_mode()
	await _settle()

	# Rage strike twice in a row: the second one waits for the cooldown.
	p.rage = 100.0
	seen.clear()
	_t = 0.0
	for i in 2:
		Input.action_press("p0_special")
		await _press("light")
		Input.action_release("p0_special")
		await _wait(0.65)
	await _settle()
	names = seen.map(func(s): return s[1])
	var strikes := seen.filter(func(s): return s[1] == "rage_strike")
	var spaced: bool = strikes.size() < 2 or strikes[1][0] - strikes[0][0] >= 0.6 + Player.ATTACK_RECOVERY["rage_strike"] - 0.05
	_check("rage strikes can't be chained", spaced, "%s" % [seen])

	# Jump: crouch first, then up, then land.
	await _wait(0.5)
	var y0 := p.global_position.y
	_press("jump")
	var crouched := false
	for i in 4:
		await get_tree().physics_frame
		crouched = crouched or (p.model.crouch > 0.0 and p.is_on_floor())
	var top := y0
	var t := 0.0
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		top = maxf(top, p.global_position.y)
		if t > 0.3 and p.is_on_floor():
			break
	_check("jump crouches before takeoff", crouched, "")
	_check("jump leaves the ground", top - y0 > 2.5, "height %.1f" % (top - y0))
	_check("jump lands again", p.is_on_floor() and not p.model.airborne, "after %.2fs" % t)
	get_tree().quit()


func _watch() -> void:
	var last: Dictionary = {}
	while is_inside_tree():
		await get_tree().physics_frame
		_t += get_physics_process_delta_time()
		if p.state == Player.S.ATTACK and p.atk != last:
			seen.append([_t, Player.ATTACKS.find_key(p.atk)])
		last = p.atk if p.state == Player.S.ATTACK else {}


## Seconds from the end of `attack_name` to the start of the next attack.
func _gap_after(attack_name: String) -> float:
	for i in seen.size() - 1:
		if seen[i][1] == attack_name:
			var d: float = Player.ATTACKS[attack_name]["dur"]
			if p.raging or attack_name.begins_with("fire"):
				d /= Player.RAGE_ATTACK_SPEED
			return seen[i + 1][0] - seen[i][0] - d
	return 99.0


func _mash(btn: String, seconds: float) -> void:
	seen.clear()
	_t = 0.0
	while _t < seconds:
		await _press(btn)
		await _wait(0.06)


func _settle() -> void:
	while p.state != Player.S.FREE or p._attack_cd > 0.0 or p._rage_cd > 0.0:
		await get_tree().physics_frame
	await _wait(0.2)


func _press(a: String) -> void:
	var action := "p0_%s" % a
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _check(what: String, ok: bool, info: String) -> void:
	print("%s: %s (%s)" % [what, "PASS" if ok else "FAIL", info])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
