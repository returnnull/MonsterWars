extends Node
## Dev check for the combos, played with real button presses:
## light x3 = TAIL SPIN, light light heavy = KAIJU RUSH, heavy x3 = TITAN
## CRUSH, jump + heavy = GROUND POUND (AoE), jump + light = SKY CLAW (hits
## aircraft). Also checks a single heavy stays a plain slam and rage mode
## still turns light light heavy into fire. Prints PASS/FAIL per step.

var main: Node
var p: Player
## Attacks the player started, in order (filled by _watch).
var seen: Array = []


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
	_clear()
	await _wait(0.3)
	p.facing = 1.0
	_watch()

	var e := _enemy(3.0)
	await _combo(["light", "light", "light"], 0.18)
	_check("light x3 = TAIL SPIN", seen == ["light1", "light2", "light3"] and p.combo_uses.get("light3", 0) == 1,
		"%s" % [seen])
	_check("tail spin hits", _lost(e) > 0.0, "dmg %.0f" % _lost(e))
	_clear()

	# The rush rams both enemies in its way and carries the player forward.
	var a := _enemy(3.5)
	var b := _enemy(7.5)
	var x0 := p.global_position.x
	await _combo(["light", "light", "heavy"], 0.18)
	_check("light light heavy = KAIJU RUSH", seen == ["light1", "light2", "rush"], "%s" % [seen])
	_check("rush charges forward", p.global_position.x - x0 > 5.0, "moved %.1f" % (p.global_position.x - x0))
	_check("rush rams everything in its way", _lost(a) > 0.0 and _lost(b) > 0.0, "dmg %.0f / %.0f" % [_lost(a), _lost(b)])
	_clear()

	var single := _enemy(3.0)
	await _combo(["heavy"], 0.3)
	_check("single heavy stays a slam", seen == ["heavy"], "%s" % [seen])
	var slam_dmg := _lost(single)
	_clear()

	# Titan Crush: a big slam plus shockwaves that reach far ahead.
	var near := _enemy(3.0)
	var far := _enemy(16.0)
	await _combo(["heavy", "heavy", "heavy"], 0.3)
	await _wait(0.8)
	_check("heavy x3 = TITAN CRUSH", seen == ["heavy", "heavy2", "heavy3"], "%s" % [seen])
	_check("titan crush hits harder than a slam", _lost(near) > slam_dmg * 2.5, "dmg %.0f vs slam %.0f" % [_lost(near), slam_dmg])
	_check("titan crush shockwaves reach far", _lost(far) > 0.0, "dmg %.0f" % _lost(far))
	_clear()

	# Ground pound: hits enemies on both sides, even a bit away.
	var left := _enemy(-5.0)
	var right := _enemy(5.0)
	var outer := _enemy(9.5)
	await _jump_and("heavy")
	_check("jump + heavy = GROUND POUND", p.combo_uses.get("pound", 0) == 1, "%s" % [p.combo_uses])
	_check("ground pound hits all around", _lost(left) > 0.0 and _lost(right) > 0.0 and _lost(outer) > 0.0,
		"dmg %.0f / %.0f / outer %.0f" % [_lost(left), _lost(right), _lost(outer)])
	_check("ground pound beats a plain slam", _lost(right) > slam_dmg, "dmg %.0f vs slam %.0f" % [_lost(right), slam_dmg])
	_clear()

	# Sky claw: the wave finds a helicopter hovering up and ahead.
	var heli := _heli(Vector3(13.0, 8.0, -2.0))
	var hp0: float = heli.hp
	await _jump_and("light")
	await _wait(1.2)
	_check("jump + light = SKY CLAW", seen == ["sky_claw"], "%s" % [seen])
	_check("sky claw wave hits the helicopter", heli.hp < hp0, "hp %.0f -> %.0f" % [hp0, heli.hp])
	_check("aircraft take bonus damage", hp0 - heli.hp >= p.ATTACKS["sky_claw"]["dmg"] * Player.AIR_BONUS,
		"dmg %.0f" % (hp0 - heli.hp))
	_clear()

	# Rage mode keeps its fire: light light heavy spits and then sprays.
	p.rage = 100.0
	p._enter_rage_mode()
	await _wait(0.5)
	await _combo(["light", "light", "heavy"], 0.18)
	while p.state == Player.S.ATTACK:
		await get_tree().physics_frame
	_check("rage mode light light heavy = fire", seen == ["fire1", "fire2", "flame"], "%s" % [seen])
	get_tree().quit()


func _watch() -> void:
	var last: Dictionary = {}
	while is_inside_tree():
		await get_tree().physics_frame
		if p.state == Player.S.ATTACK and p.atk != last:
			seen.append(Player.ATTACKS.find_key(p.atk))
		last = p.atk if p.state == Player.S.ATTACK else {}


func _press(a: String) -> void:
	var action := "p0_%s" % a
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


## Presses the buttons `gap` seconds apart and waits until the kaiju is done.
func _combo(buttons: Array, gap: float) -> void:
	# A new combo can only start once the last one's recovery is over.
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


func _heli(offset: Vector3) -> Node3D:
	var f: Node3D = main.make_enemy("heli", p.global_position.x, 1.0)
	main.add_child(f)
	f.set_process(false)
	f.hp = 400.0
	f.global_position = p.global_position + offset
	return f


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
