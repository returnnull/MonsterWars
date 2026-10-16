extends Node
## Dev check: enemies come in over the arena gate before they attack, and
## aircraft stay over the arena once they are in. Player 1 stands right by
## the gate; one enemy of each kind is sent in from behind it. Fails if the
## enemy attacks while still outside, never comes in, never attacks, or (for
## aircraft) drifts back out beyond the gate. Prints PASS/FAIL per kind.
## Env: ARENA_KINDS "tank,heli" limits the kinds; ARENA_GAP how far inside the
## gate player 1 stands (default 8); ARENA_DEBUG prints where an attack came from.

var KINDS: Array = OS.get_environment("ARENA_KINDS").split(",") if OS.has_environment("ARENA_KINDS") else ["soldier", "rocket", "flamer", "tank", "artillery", "missile", "mech", "apc",
	"maser", "brute", "rhinox", "nagling", "drone", "heli", "bomber", "wasp", "saucer"]
const RUN := 12.0
var GAP := float(OS.get_environment("ARENA_GAP")) if OS.has_environment("ARENA_GAP") else 8.0

var main: Node
var fails := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: 0}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	var p: Player = Game.players[0]
	var w: Dictionary = main.waves[0]
	var cx: float = w["x"]
	var half: float = w.get("half", 20.0)
	# Walk into the first arena so its wave starts, then clear its own enemies.
	p.global_position = Vector3(cx, 1.0, 0.0)
	await _wait(8.0)
	for kind in KINDS:
		_clear(null)
		p.max_hp = 99999.0
		p.hp = 99999.0
		# The flamer sets player 1 alight; don't let that burn count against the next kind.
		p.burn_t = 0.0
		p.slow_t = 0.0
		p.global_position = Vector3(cx + half - GAP, 1.0, 0.0)
		await _wait(0.3)
		var e: Node3D = main.make_enemy(kind, cx, 1.0, half)
		main.add_child(e)
		var gate := cx + half
		var known := _shots()
		var entered := false
		var attacked := false
		var outside_attack := false
		var escaped := 0.0
		var t := 0.0
		while t < RUN:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			_clear(e)
			p.global_position.x = cx + half - GAP
			var gone: bool = not is_instance_valid(e) or e.dead
			var shots := _shots()
			var fresh := shots.filter(func(s): return not known.has(s))
			known = shots
			var hp_lost := p.hp < 99999.0
			p.hp = 99999.0
			if gone:
				attacked = attacked or hp_lost or not fresh.is_empty() or kind == "wasp"
				break
			var outside: bool = e.global_position.x > gate
			var busy: bool = e is Brute and e.state in [Brute.S.WINDUP, Brute.S.ACT]
			if outside and (hp_lost or not fresh.is_empty() or busy):
				if not outside_attack and OS.has_environment("ARENA_DEBUG"):
					print("  outside attack at x %.1f (gate %.1f) hp_lost %s shots %s busy %s" % [e.global_position.x, gate, hp_lost, fresh, busy])
				outside_attack = true
			if not outside:
				entered = true
			elif entered and e is Flyer:
				escaped = maxf(escaped, e.global_position.x - gate)
			if not outside and (hp_lost or not fresh.is_empty() or busy):
				attacked = true
		var ok := entered and attacked and not outside_attack and escaped <= 0.0
		if not ok:
			fails += 1
		print("%-9s %s (entered %s, attacked %s, attacked from outside %s, out beyond gate %.1f)" % [
			kind, "PASS" if ok else "FAIL", entered, attacked, outside_attack, escaped])
		if is_instance_valid(e):
			e.queue_free()
	print("arena entry: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	get_tree().quit()


## Shots and ground strikes currently in the level.
func _shots() -> Array:
	return main.get_children().filter(func(c): return c is Projectile or c is Hazard)


## Removes every enemy but `keep` (wave spawns, squads, summons).
func _clear(keep: Variant) -> void:
	if keep != null and not is_instance_valid(keep):
		keep = null
	for x in get_tree().get_nodes_in_group("enemies"):
		if x != keep:
			x.remove_from_group("enemies")
			x.queue_free()
	for s in _shots():
		if keep == null:
			s.queue_free()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
