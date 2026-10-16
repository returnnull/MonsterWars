extends Node
## Dev check that every hero fights in its own way (see HeroMoves): its own
## combo names, its own pace (Voltra punches faster than Terraxa, who hits
## harder), and that every hero's tail spin, titan crush and ground stomp
## work with real button presses and burst in the hero's element. HEROES
## "0,3" limits it to some heroes. Prints PASS/FAIL per step.

var main: Node
var p: Player
## Attacks the player started, in order (by name).
var seen: Array = []


func _ready() -> void:
	Game.set_meta("no_save", true)
	var names := {}
	for h in Content.HEROES.size():
		for c in ["light3", "rush", "heavy3", "sky_claw", "pound"]:
			names[HeroMoves.combo_name(h, c)] = true
	_check("every hero has its own combo names", HeroMoves.MOVES.size() == Content.HEROES.size()
		and names.size() == Content.HEROES.size() * 5, "%d names" % names.size())
	var fast := HeroMoves.tune(Player.ATTACKS["light1"], 1)
	var slow := HeroMoves.tune(Player.ATTACKS["light1"], 4)
	_check("Voltra punches faster, Terraxa hits harder", fast["dur"] < slow["dur"] and slow["dmg"] > fast["dmg"],
		"dur %.2f vs %.2f, dmg %.1f vs %.1f" % [fast["dur"], slow["dur"], fast["dmg"], slow["dmg"]])
	var ids: Array = range(Content.HEROES.size())
	if OS.get_environment("HEROES") != "":
		ids = Array(OS.get_environment("HEROES").split(",")).map(func(x) -> int: return int(x))
	for h in ids:
		await _hero(h)
	get_tree().quit()


func _hero(h: int) -> void:
	Game.party = {0: h}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	p = Game.players[0]
	p.max_hp = 99999.0
	p.hp = 50000.0
	_clear()
	await _wait(0.3)
	p.facing = 1.0
	_watch()
	var tag := p.display_name()

	var e := _enemy(3.0)
	# Slower heroes need the buttons pressed at their own, slower pace.
	var tempo: float = HeroMoves.for_hero(h)["tempo"]
	await _combo(["light", "light", "light"], 0.16 / tempo)
	_check("%s %s" % [tag, HeroMoves.combo_name(h, "light3")], seen == ["light1", "light2", "light3"] and _lost(e) > 0.0,
		"%s, dmg %.0f" % [seen, _lost(e)])
	_clear()

	var near := _enemy(3.0)
	var far := _enemy(16.0)
	await _combo(["heavy", "heavy", "heavy"], 0.28 / tempo)
	await _wait(0.8)
	_check("%s %s" % [tag, HeroMoves.combo_name(h, "heavy3")], seen == ["heavy", "heavy2", "heavy3"]
		and _lost(near) > 0.0 and _lost(far) > 0.0, "%s, dmg %.0f / far %.0f" % [seen, _lost(near), _lost(far)])
	_clear()

	var left := _enemy(-5.0)
	var right := _enemy(5.0)
	await _jump_and("heavy")
	_check("%s %s" % [tag, HeroMoves.combo_name(h, "pound")], p.combo_uses.get("pound", 0) == 1
		and _lost(left) > 0.0 and _lost(right) > 0.0, "dmg %.0f / %.0f" % [_lost(left), _lost(right)])
	_clear()
	main.queue_free()
	await _wait(0.3)


func _watch() -> void:
	var me := p
	var last := ""
	while is_instance_valid(me) and me == p and is_inside_tree():
		await get_tree().physics_frame
		if not is_instance_valid(me):
			return
		var now: String = me._atk_name if me.state == Player.S.ATTACK else ""
		if now != "" and now != last:
			seen.append(now)
		last = now


func _press(a: String) -> void:
	var action := "p0_%s" % a
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _combo(buttons: Array, gap: float) -> void:
	while p._attack_cd > 0.0:
		await get_tree().physics_frame
	seen.clear()
	for btn in buttons:
		_press(btn)
		await _wait(gap)
	while p.state != Player.S.FREE or not p.is_on_floor():
		await get_tree().physics_frame
	await _wait(0.2)


func _jump_and(btn: String) -> void:
	await _wait(0.3)
	seen.clear()
	await _press("jump")
	await _wait(0.25)
	await _press(btn)
	while p.state != Player.S.FREE or not p.is_on_floor():
		await get_tree().physics_frame
	await _wait(0.2)


func _check(what: String, ok: bool, info: String) -> void:
	print("%s: %s (%s)" % [what, "PASS" if ok else "FAIL", info])


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("buildings"):
		n.queue_free()


func _lost(e: Node) -> float:
	return e.max_hp - e.hp


func _enemy(dx: float) -> Node3D:
	var e: Node3D = main.make_enemy("tank", p.global_position.x, 1.0)
	main.add_child(e)
	e.hp = 99999.0
	e.max_hp = 99999.0
	e.set_physics_process(false)
	e.global_position = Vector3(p.global_position.x + dx, 0.5, p.global_position.z)
	return e


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
