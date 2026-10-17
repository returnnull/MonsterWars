extends Node
## Dev check for staying alive: every level has at least Content.MIN_WAVES
## waves, every hero can learn life leech early (row 1 or above), the hero
## takes no damage (hits or burning) during a super or rage attack, and
## ability leech heals from super damage.
## Run: godot --headless --path . res://tests/sustain_test.tscn

var main: Node
var _fails := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	for c in Content.COUNTRIES.size():
		for l in Content.LEVELS_PER_COUNTRY:
			var n: int = Content.level(c, l)["waves"].size()
			_check(n >= Content.MIN_WAVES, "level %d-%d has %d waves" % [c + 1, l + 1, n], false)
	for h in Content.HEROES.size():
		var early := false
		for i in Skills.node_count(h):
			var n := Skills.node(h, i)
			if n["row"] <= 1 and (n["kind"] == "leech" or n["kind"] == "ability_leech"):
				early = true
		_check(early, "%s can learn leech in the first two rows" % Content.HEROES[h]["name"])

	Game.party = {0: 0}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p: Player = Game.players[0]
	await _wait(0.3)

	# Super: hits and burning do nothing for its whole length.
	p.hp = p.max_hp * 0.5
	var hp0 := p.hp
	p._start_super()
	p.apply_burn(20.0, 10.0)
	var t := 0.0
	while t < Player.SUPER_TIME - 0.1:
		p.take_hit(25.0, Vector3(10, 5, 0), null)
		await _wait(0.2)
		t += 0.2
	_check(p.hp >= hp0, "no damage during super (hp %.0f -> %.0f)" % [hp0, p.hp])
	await _wait(0.4)
	_check(p.state != Player.S.SUPER and p.invuln > 0.0, "a moment of safety right after the super")
	p.burn_t = 0.0
	await _wait(1.0)

	# Rage attack (stands still): untouchable too.
	p.hp = p.max_hp * 0.5
	hp0 = p.hp
	p.rage = p.rage_max
	p._set_state(Player.S.BEAM)
	for i in 4:
		p.take_hit(25.0, Vector3(10, 5, 0), null)
		await _wait(0.1)
	_check(p.hp >= hp0, "no damage during rage attack (hp %.0f -> %.0f)" % [hp0, p.hp])
	p._set_state(Player.S.FREE)
	await _wait(1.0)

	# Ability leech heals from super hits, plain hits don't count.
	p.sk["ability_leech"] = 10.0
	p.hp = p.max_hp * 0.3
	var dummy := _dummy(p)
	hp0 = p.hp
	p.deal(dummy, 50.0, Vector3.ZERO)
	_check(is_equal_approx(p.hp, hp0), "ability leech ignores plain hits")
	p.state = Player.S.SUPER
	p.deal(dummy, 50.0, Vector3.ZERO)
	p.state = Player.S.FREE
	_check(p.hp > hp0 + 4.0, "ability leech heals from super hits (hp %.1f -> %.1f)" % [hp0, p.hp])

	print("SUSTAIN TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


## A tough enemy far away to hit by hand.
func _dummy(p: Player) -> Node:
	var e := Brute.new()
	e.kind = "brute"
	e.position = p.global_position + Vector3(60, 0.2, 0)
	main.add_child(e)
	e.max_hp = 99999.0
	e.hp = 99999.0
	e.set_physics_process(false)
	return e


func _check(ok: bool, what: String, show_pass := true) -> void:
	if not ok:
		_fails += 1
	if show_pass or not ok:
		print("%s %s" % ["PASS" if ok else "FAIL", what])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
