extends Node
## Dev check that every hero has its own rage attacks and super, and that
## they work: the light shot reaches a far enemy and puts the hero's effect
## on it, the heavy breath keeps the hero still and does more damage than a
## shot, and the super hurts enemies and ends cleanly. HEROES "0,3" limits
## it to some heroes. Prints PASS/FAIL per step.

var main: Node
var p: Player


func _ready() -> void:
	Game.set_meta("no_save", true)
	var attacks := {}
	var specials := {}
	for h in Content.HEROES.size():
		attacks[RageStyle.for_hero(h)["attack"]] = true
		specials[Content.HEROES[h]["special"]] = true
	_check("every hero has its own rage attack", attacks.size() == Content.HEROES.size() and specials.size() == 4,
		"%d names, %d kinds" % [attacks.size(), specials.size()])
	var lights := {}
	var shots := {}
	var moves := {}
	var jets := {}
	for st in RageStyle.STYLES:
		lights[st["light"]] = true
		shots[st["shot"] + st["jet"]] = true
		moves[st["move"]] = true
		jets[st["jet"]] = true
	_check("every hero has its own rage attacks", RageStyle.STYLES.size() == Content.HEROES.size()
		and lights.size() == Content.HEROES.size() and shots.size() == Content.HEROES.size(),
		"%d styles, %d names, %d looks" % [RageStyle.STYLES.size(), lights.size(), shots.size()])
	_check("every hero's light attack moves its own way", moves.size() == Content.HEROES.size(), "%d moves" % moves.size())
	_check("every hero's breath looks its own way", jets.size() == Content.HEROES.size(), "%d breaths" % jets.size())
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
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	p.facing = 1.0
	var st: Dictionary = p.rage_style
	var tag := "%s %s" % [p.display_name(), st["light"]]

	# Light: the shot reaches an enemy 14 units away and puts the effect on it.
	var far := _enemy(14.0)
	var beside := _enemy(20.0, -1.5)
	_rage()
	var hp0: float = far.hp
	var hp_b: float = beside.hp
	var me0 := p.hp
	p._start_attack("fire1")
	while p.state == Player.S.ATTACK:
		await get_tree().physics_frame
	await _wait(1.0)
	var shot_dmg: float = hp0 - far.hp
	_check("%s hits far enemy" % tag, shot_dmg > 0.0, "dmg %.0f" % shot_dmg)
	var effect := ""
	match String(st["effect"]):
		"burn", "poison", "shred":
			effect = "burning %s" % (far.burn_t > 0.0)
			_check("%s %s" % [tag, st["effect"]], far.burn_t > 0.0, effect)
		"frost":
			_check("%s slows" % tag, far.slow_t > 0.0, "slow %.1fs" % far.slow_t)
		"leech":
			_check("%s heals" % tag, p.hp > me0, "hp %.0f -> %.0f" % [me0, p.hp])
		"push":
			_check("%s washes back" % tag, far.knock.x > 6.0, "knock %.1f" % far.knock.x)
		"quake":
			_check("%s throws up" % tag, far.knock.y > 5.0, "knock up %.1f" % far.knock.y)
		"shock":
			_check("%s chains lightning" % tag, beside.hp < hp_b, "second enemy dmg %.0f" % (hp_b - beside.hp))
	if st["move"] in ["ring", "lash", "roll", "boomerang", "wave"]:
		_check("%s cuts through both" % tag, beside.hp < hp_b, "second enemy dmg %.0f" % (hp_b - beside.hp))
	far.queue_free()
	beside.queue_free()
	await _wait(0.3)

	# Heavy: the breath holds the hero still and beats a shot.
	var near := _enemy(7.0)
	_rage()
	await _wait(0.4)
	hp0 = near.hp
	var x0 := p.global_position.x
	var moved := 0.0
	var saw_fx := false
	p._start_attack("flame")
	while p.state == Player.S.ATTACK:
		await get_tree().physics_frame
		moved = maxf(moved, absf(p.global_position.x - x0))
		saw_fx = saw_fx or p._flame_fx != null
	var breath: float = hp0 - near.hp
	_check("%s %s pours and stops" % [p.display_name(), st["heavy"]], saw_fx and p._flame_fx == null and moved < 0.3,
		"moved %.2f" % moved)
	_check("%s breath beats a shot" % p.display_name(), breath > shot_dmg * 2.0, "breath %.0f vs shot %.0f" % [breath, shot_dmg])
	near.queue_free()
	p._exit_rage_mode()
	await _wait(0.5)

	# Rage attack (special + heavy): the hero's own attack hurts enemies
	# ahead with its effect and ends cleanly.
	var ahead := [_enemy(7.0), _enemy(14.0)]
	var ahead0: float = ahead[0].hp + ahead[1].hp
	p.rage = 100.0
	p._rage_cd = 0.0
	p._use_rage_skill("attack")
	var ta := 0.0
	while p.state == Player.S.BEAM and ta < 6.0:
		await get_tree().physics_frame
		ta += get_physics_process_delta_time()
	_check("%s rage attack %s" % [p.display_name(), st["attack"]], ahead[0].hp + ahead[1].hp < ahead0
		and p.state == Player.S.FREE and not p._beam.visible and p._flame_fx == null,
		"%s, dmg %.0f in %.1fs" % [p._special, ahead0 - ahead[0].hp - ahead[1].hp, ta])
	for e in ahead:
		e.queue_free()
	await _wait(0.5)

	# Super: hurts enemies around and ends cleanly.
	var foes := [_enemy(8.0), _enemy(15.0), _enemy(-8.0)]
	var total0 := 0.0
	for e in foes:
		total0 += e.hp
	p.add_super(Player.SUPER_MAX)
	p._start_super()
	var t := 0.0
	while p.state == Player.S.SUPER and t < 6.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _wait(0.6)
	var total := 0.0
	for e in foes:
		total += e.hp
	_check("%s super %s" % [p.display_name(), p._super["name"]], total < total0 and p.state == Player.S.FREE
		and p._super_ice.is_empty() and p._super_fx == null, "dmg %.0f in %.1fs" % [total0 - total, t])
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _rage() -> void:
	p.rage = 100.0
	if not p.raging:
		p._enter_rage_mode()


func _check(what: String, ok: bool, info: String) -> void:
	print("%s: %s (%s)" % [what, "PASS" if ok else "FAIL", info])


func _enemy(dx: float, dz := 0.0) -> Node3D:
	var e: Node3D = main.make_enemy("tank", p.global_position.x, 1.0)
	main.add_child(e)
	e.hp = 99999.0
	e.max_hp = 99999.0
	e.set_physics_process(false)
	e.global_position = Vector3(p.global_position.x + dx, 0.5, p.global_position.z + dz)
	return e


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
