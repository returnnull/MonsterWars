extends Node
## Dev check for rage mode fire. Light spits a fireball that flies far out
## of punch reach and burns what it hits; heavy stops the kaiju and sprays
## flame ahead, doing more damage than a fireball; fire gives no rage back
## and rage attacks play faster. Prints PASS/FAIL per step.

var main: Node
var p: Player


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
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	p.facing = 1.0

	# Normal light punch can't reach an enemy 14 units away.
	var far := _enemy(14.0)
	var hp0: float = far.hp
	await _attack("light1")
	await _wait(1.0)
	_check("normal light misses far enemy", far.hp == hp0, "hp %.0f -> %.0f" % [hp0, far.hp])

	_rage()
	hp0 = far.hp
	await _attack("fire1")
	await _wait(1.0)
	var fireball_dmg: float = hp0 - far.hp
	_check("rage light fireball hits far enemy", fireball_dmg > 0.0 and far.burn_t > 0.0,
		"dmg %.0f, burning %s" % [fireball_dmg, far.burn_t > 0.0])
	_check("fire gives no rage", p.rage <= 100.0, "rage %.0f" % p.rage)
	far.queue_free()

	# Heavy flame: the kaiju stays put and burns an enemy in front of it.
	var near := _enemy(7.0)
	_rage()
	hp0 = near.hp
	var x0 := p.global_position.x
	var moved := 0.0
	p._start_attack("flame")
	var saw_fx := false
	while p.state == Player.S.ATTACK:
		await get_tree().physics_frame
		moved = maxf(moved, absf(p.global_position.x - x0))
		saw_fx = saw_fx or p._flame_fx != null
	var flame_dmg: float = hp0 - near.hp
	_check("rage heavy sprays flame", saw_fx and p._flame_fx == null, "")
	_check("flame hurts enemy ahead", flame_dmg > 0.0 and near.burn_t > 0.0, "dmg %.0f" % flame_dmg)
	_check("heavy does more damage than light", flame_dmg > fireball_dmg * 2.0,
		"flame %.0f vs fireball %.0f" % [flame_dmg, fireball_dmg])
	_check("kaiju stands still while spraying", moved < 0.3, "moved %.2f" % moved)
	_check("flame gives no rage", p.rage <= 100.0, "rage %.0f" % p.rage)
	near.queue_free()
	await _wait(0.3)

	# Rage attacks play faster (count frames for the same attack).
	var frames := []
	for raging in [false, true]:
		if raging:
			_rage()
		else:
			p._exit_rage_mode()
		# Let the hitstop from entering rage mode pass first.
		await _wait(0.4)
		var n := 0
		p._start_attack("fire3")
		while p.state == Player.S.ATTACK:
			n += 1
			await get_tree().physics_frame
		frames.append(n)
	_check("rage attacks faster", frames[1] < frames[0], "%d -> %d frames" % [frames[0], frames[1]])
	get_tree().quit()


func _rage() -> void:
	p.rage = 100.0
	if not p.raging:
		p._enter_rage_mode()


func _attack(attack_name: String) -> void:
	p._start_attack(attack_name)
	while p.state == Player.S.ATTACK:
		await get_tree().physics_frame


func _check(what: String, ok: bool, info: String) -> void:
	print("%s: %s (%s)" % [what, "PASS" if ok else "FAIL", info])


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
