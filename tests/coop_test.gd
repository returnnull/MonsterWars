extends Node
## Dev check for co-op: every player beyond the first adds 20% enemies to a
## wave, and a downed player is revived by a teammate standing next to them
## (but not by one standing far away). Prints PASS/FAIL per step.
## COOP_SHOT=/path.png saves a screenshot mid-revive (needs a renderer).

var main: Node


func _ready() -> void:
	Game.set_meta("no_save", true)
	var spawn := ["soldier", "soldier", "soldier", "soldier", "tank", "tank", "heli", "heli", "jeep", "jeep"]
	for n in range(1, 5):
		var got: int = main_script().party_spawns(spawn, n).size()
		var want := int(10 * (1.0 + 0.2 * (n - 1)))
		print("%d players: %d enemies (want %d) %s" % [n, got, want, "PASS" if got == want else "FAIL"])
	var boss: int = main_script().party_spawns(["boss"], 4).size()
	print("boss wave stays 1 boss: %s" % ("PASS" if boss == 1 else "FAIL"))

	Game.party = {0: 0, 1: 1}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.5)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var a: Player = Game.players[0]
	var b: Player = Game.players[1]
	a.max_hp = 99999.0
	a.hp = 99999.0
	a.global_position = Vector3(0, 0.2, 0)
	b.global_position = Vector3(20, 0.2, 0)
	await _wait(0.5)
	b.take_hit(b.hp + 10.0, Vector3.ZERO)
	await _wait(2.5)
	print("far teammate does not revive: %s (dead %s)" % ["PASS" if b.dead else "FAIL", b.dead])
	a.global_position = b.global_position + Vector3(-2.0, 0, 0)
	await _wait(1.5)
	var shot := OS.get_environment("COOP_SHOT")
	if shot != "":
		get_viewport().get_texture().get_image().save_png(shot)
	print("half-way: %s (progress %.2f)" % ["PASS" if b.dead and b.revive_progress > 0.3 else "FAIL", b.revive_progress])
	await _wait(2.0)
	print("revived by teammate: %s (dead %s, hp %.0f/%.0f)" % [
		"PASS" if not b.dead and b.hp > 0.0 else "FAIL", b.dead, b.hp, b.max_hp])
	get_tree().quit()


func main_script() -> Script:
	return load("res://scripts/main.gd")


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
