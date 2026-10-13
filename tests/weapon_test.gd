extends Node
## Dev check: spawns each building piece next to player 1, grabs it, swings
## it at an enemy and throws it. Prints PASS/FAIL per step.

var main: Node


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: 0}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	var p: Player = Game.players[0]
	p.max_hp = 99999.0
	p.hp = 99999.0
	for kind in Weapon.KINDS:
		var w := Weapon.new()
		w.kind = kind
		main.add_child(w)
		w.global_position = p.global_position + Vector3(1.5, 0, 0)
		await _wait(0.2)
		await _press("p0_heavy")
		await _wait(0.3)
		print("%s grab: %s" % [kind, "PASS" if p.weapon == kind else "FAIL (%s)" % p.weapon])
		var e := Brute.new()
		e.kind = "brute"
		main.add_child(e)
		e.global_position = p.global_position + Vector3(4.0 * p.facing, 0.2, 0)
		await _wait(0.3)
		var hp0 := e.hp
		await _press("p0_light")
		await _wait(0.6)
		print("%s swing: %s (enemy hp %.0f -> %.0f, uses %d)" % [kind, "PASS" if e.hp < hp0 else "FAIL", hp0, e.hp, p.weapon_uses])
		var hp1 := e.hp
		await _press("p0_heavy")
		await _wait(1.2)
		print("%s throw: %s (enemy hp %.0f -> %.0f, still armed: %s)" % [kind, "PASS" if (e.hp < hp1 or e.dead) and p.weapon == "" else "FAIL", hp1, e.hp, p.weapon])
		if is_instance_valid(e):
			e.queue_free()
		await _wait(0.3)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _press(a: String) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(a)
