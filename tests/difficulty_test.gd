extends Node
## Dev check: the three difficulties scale enemy health and damage, and the
## difficulty setting survives a settings round trip through JSON.
## Run: godot --headless --path . res://tests/difficulty_test.tscn

var main: Node
var _fails := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: 0}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	for kind in [Enemies.regular_ids()[0], "boss"]:
		var stats := []
		for d in Game.DIFFICULTIES.size():
			Game.settings["difficulty"] = d
			var e: Node3D = main.make_enemy(kind, 0.0, 1.0)
			main.add_child(e)
			stats.append([e.max_hp, e.dmg])
			e.queue_free()
		print("%s hp/dmg per difficulty: %s" % [kind, stats])
		for d in Game.DIFFICULTIES.size():
			var want: Dictionary = Game.DIFFICULTIES[d]
			_check(is_equal_approx(stats[d][0] / stats[1][0], want["hp"]), "%s %s health" % [kind, want["name"]])
			_check(is_equal_approx(stats[d][1] / stats[1][1], want["dmg"]), "%s %s damage" % [kind, want["name"]])
	Game.settings["difficulty"] = 2
	var back = JSON.parse_string(JSON.stringify(Game.settings))
	Game.settings["difficulty"] = 1
	_check(type_convert(back["difficulty"], TYPE_INT) == 2, "difficulty survives JSON")
	print("DIFFICULTY TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1
