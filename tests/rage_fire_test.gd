extends Node
## Dev check: in rage mode player 1's normal attacks also burst into flames,
## hurting and burning an enemy the punch itself can't reach, play faster,
## and the fire gives no rage back. Prints PASS/FAIL per step.

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
	var frames_by_mode := []
	for raging in [false, true]:
		var far := _enemy()
		# Just beyond the punch (reach 2.6, radius 2.3), inside the fire.
		far.global_position.x = p.global_position.x + 2.6 + 2.3 + far.hit_radius + 1.2
		await _wait(0.1)
		p.facing = 1.0
		p.rage = 100.0 if raging else 0.0
		if raging:
			p._enter_rage_mode()
		var hp0: float = far.hp
		p._start_attack("light1")
		while p.state == Player.S.ATTACK:
			await get_tree().physics_frame
		var rage_after := p.rage
		var hurt: bool = far.hp < hp0
		var ok: bool = (hurt and far.burn_t > 0.0 and rage_after <= 100.0) if raging else not hurt
		print("%s light punch just out of reach: %s (hp %.0f -> %.0f, burning %s, rage %.0f)" % [
			"rage" if raging else "normal", "PASS" if ok else "FAIL", hp0, far.hp, far.burn_t > 0.0, rage_after])
		far.queue_free()
		await _wait(0.5)
		# With nobody to hit (no hitstop), count frames for a heavy attack.
		var frames := 0
		p._start_attack("heavy")
		while p.state == Player.S.ATTACK:
			frames += 1
			await get_tree().physics_frame
		frames_by_mode.append(frames)
		if raging:
			p._exit_rage_mode()
	var faster: bool = frames_by_mode[1] < frames_by_mode[0]
	print("rage attacks faster: %s (heavy %d -> %d frames)" % ["PASS" if faster else "FAIL", frames_by_mode[0], frames_by_mode[1]])
	get_tree().quit()


func _enemy() -> Node3D:
	var e: Node3D = main.make_enemy("tank", p.global_position.x, 1.0)
	main.add_child(e)
	e.hp = 99999.0
	e.max_hp = 99999.0
	e.set_physics_process(false)
	e.global_position = Vector3(p.global_position.x, 0.5, p.global_position.z)
	return e


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
