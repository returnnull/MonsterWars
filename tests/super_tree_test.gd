extends Node
## Dev check for the super trees: every hero has SuperTree.TIERS tiers of 2-3
## options with known effects, tiers open every SuperTree.TIER_EVERY levels,
## and every option, alone and mixed with the others, plays out its super
## without errors, hits the enemies and does what it says. Prints each
## option's super damage next to the plain super's.
## Run: godot --headless --path . res://tests/super_tree_test.tscn
## (HERO=n checks one hero only.)

const RIDERS := ["burn", "chill", "venom", "stun", "rage", "leech"]
## Effects that only some supers understand.
const ONLY := {
	"frag_air": ["meteors", "scrap"], "bounce": ["meteors", "scrap"], "giant": ["meteors", "scrap"],
	"rain_more": ["meteors", "scrap"], "rain_big": ["meteors", "scrap"], "magnet": ["meteors", "scrap"],
	"long": ["mega_beam", "storm", "meteors", "scrap"],
	"bolt_big": ["storm"], "bolt_giant": ["storm"], "storm_all": ["storm"],
}

var main: Node
var p: Player
var _fails := 0
var _dummies: Array = []


func _ready() -> void:
	Game.set_meta("no_save", true)
	_check(SuperTree.tiers_open(4) == 0 and SuperTree.tiers_open(5) == 1 and SuperTree.tiers_open(Skills.MAX_LEVEL) == SuperTree.TIERS,
		"a tier opens every %d levels, all open at max level" % SuperTree.TIER_EVERY)
	var heroes := range(Content.HEROES.size())
	if OS.get_environment("HERO") != "":
		heroes = [int(OS.get_environment("HERO"))]
	for h in Content.HEROES.size():
		_check_data(h)
	for h in heroes:
		await _play_hero(h)
	print("SUPER TREE TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_data(h: int) -> void:
	var hn: String = Content.HEROES[h]["name"]
	var pattern: String = Skills.super_def(h)["pattern"]
	_check(SuperTree.HEROES[h].size() == SuperTree.TIERS, "%s has %d tiers" % [hn, SuperTree.TIERS])
	var seen := {}
	for t in SuperTree.HEROES[h].size():
		var n := SuperTree.options(h, t).size()
		_check(n >= 2 and n <= 3, "%s tier %d has 2-3 options" % [hn, t + 1])
		for o in n:
			var op := SuperTree.option(h, t, o)
			_check(SuperTree.EFFECTS.has(op["effect"]), "%s: %s has a known effect" % [hn, op["name"]])
			_check(op["desc"] != "", "%s: %s says what it does" % [hn, op["name"]])
			_check(not seen.has(op["effect"]), "%s: %s is in one tier only" % [hn, op["effect"]])
			seen[op["effect"]] = true
			if ONLY.has(op["effect"]):
				_check(pattern in ONLY[op["effect"]], "%s: %s works with %s" % [hn, op["effect"], pattern])


func _play_hero(h: int) -> void:
	Game.party = {0: h}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	p = Game.players[0]
	var hn: String = Content.HEROES[h]["name"]
	var base := await _run({})
	print("%s plain super: %d damage" % [hn, base["dmg"]])
	_check(base["dmg"] > 0.0, "%s plain super hits" % hn)
	for t in SuperTree.TIERS:
		for o in SuperTree.options(h, t).size():
			var picks := SuperTree.empty_picks()
			picks[t] = o
			var op := SuperTree.option(h, t, o)
			var r := await _run(SuperTree.mods(h, picks, Skills.MAX_LEVEL))
			print("  T%d %-20s %-16s %5d damage (%3d%%)" % [t + 1, op["name"], op["effect"], r["dmg"], 100.0 * r["dmg"] / maxf(base["dmg"], 1.0)])
			_check(r["dmg"] > 0.0, "%s: %s still hits" % [hn, op["name"]])
			_check(r["done"], "%s: %s ends" % [hn, op["name"]])
			_check_effect(hn, op, r, base)
	# Everything at once, option k (or the last one) in every tier.
	for k in 3:
		var picks := SuperTree.empty_picks()
		for t in SuperTree.TIERS:
			picks[t] = mini(k, SuperTree.options(h, t).size() - 1)
		var r := await _run(SuperTree.mods(h, picks, Skills.MAX_LEVEL))
		print("  all picks %s: %d damage" % [str(picks), r["dmg"]])
		_check(r["dmg"] > 0.0 and r["done"], "%s: picks %s play out" % [hn, str(picks)])
	main.queue_free()
	await _wait(0.3)


func _check_effect(hn: String, op: Dictionary, r: Dictionary, base: Dictionary) -> void:
	var what := "%s: %s" % [hn, op["name"]]
	match String(op["effect"]):
		"burn", "venom":
			_check(r["burning"], what + " sets enemies burning")
		"chill":
			_check(r["slowed"], what + " slows enemies")
		"stun":
			_check(r["stunned"], what + " freezes enemies")
		"rage":
			_check(r["rage"] > 0.0, what + " gives rage")
		"leech":
			_check(r["healed"] > 0.0, what + " heals")
		"rage_full":
			_check(r["rage"] >= p.rage_max - 0.1, what + " fills rage")
		"refund":
			_check(r["meter"] >= Player.SUPER_MAX * 0.29, what + " gives meter back")
		"shield":
			_check(r["barrier"], what + " raises a shield")
		"pull":
			_check(r["closer"], what + " drags enemies in")
		"long":
			_check(r["time"] > base["time"] + 0.8, what + " lasts longer")
		"power", "shatter", "erupt", "chain", "nova_corona":
			_check(r["dmg"] > base["dmg"] * 1.1, what + " deals more damage (%d vs %d)" % [r["dmg"], base["dmg"]])
		_:
			# Shape changes trade one thing for another, but none may cripple the super.
			_check(r["dmg"] > base["dmg"] * 0.6, what + " keeps the super strong (%d vs %d)" % [r["dmg"], base["dmg"]])


## One super with these effects against four sturdy enemies ahead and one
## behind. Returns what came of it.
func _run(sup: Dictionary) -> Dictionary:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.1)
	p.revive()
	p.max_hp = 99999.0
	p.hp = 50000.0
	p.rage = 0.0
	p.invuln = 0.0
	p._barrier_up = false
	p.global_position = Vector3(0.0, p.global_position.y, -1.0)
	p.facing = 1.0
	p.sup = sup
	_dummies = []
	for dx in [8.0, 13.0, 19.0, 26.0, -9.0]:
		_dummies.append(_enemy(dx))
	await _wait(0.1)
	var dist0 := _spread()
	var out := {"burning": false, "slowed": false, "stunned": false, "closer": false}
	p.add_super(Player.SUPER_MAX)
	p._start_super()
	var hp0 := p.hp
	var t := 0.0
	while p.state == Player.S.SUPER and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for e in _dummies:
			if is_instance_valid(e):
				out["burning"] = out["burning"] or e.burn_t > 0.0
				out["slowed"] = out["slowed"] or e.slow_t > 0.0
				out["stunned"] = out["stunned"] or e.frozen_t > 0.0
		if t > 0.15 and t < 0.6 and _spread() < dist0 * 0.8:
			out["closer"] = true
	out["time"] = t
	out["done"] = p.state != Player.S.SUPER
	out["healed"] = p.hp - hp0
	out["rage"] = p.rage
	out["meter"] = p.super_meter
	out["barrier"] = p._barrier_up
	# Shards, zones, rocks and bounces still landing.
	await _wait(1.6)
	var dmg := 0.0
	for e in _dummies:
		if is_instance_valid(e):
			dmg += e.max_hp - e.hp
	out["dmg"] = dmg
	p.super_meter = 0.0
	return out


## How far the enemies are from the hero, all told.
func _spread() -> float:
	var s := 0.0
	for e in _dummies:
		if is_instance_valid(e):
			s += absf(e.global_position.x - p.global_position.x)
	return s


func _enemy(dx: float) -> Node3D:
	var e: Node3D = main.make_enemy("tank", p.global_position.x, 1.0)
	main.add_child(e)
	e.hp = 99999.0
	e.max_hp = 99999.0
	e.global_position = Vector3(p.global_position.x + dx, 0.5, p.global_position.z)
	# Sturdy dummies that stay put unless the super moves them.
	e.set("speed", 0.0)
	return e


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: " + what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
