extends Node
## Dev helper: screenshots of a hero's super special and rage attacks, to
## judge how they look. HERO picks the hero (default 0) and SUPER_PICKS its
## super tree picks (e.g. "0,1,-1,0,0", one option index per tier). Shots go
## to user://super_<hero>_N.png.

var main: Node
var p: Player


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: int(OS.get_environment("HERO"))}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	p = Game.players[0]
	if OS.get_environment("SUPER_PICKS") != "":
		var picks := Array(OS.get_environment("SUPER_PICKS").split(",")).map(func(v: String) -> int: return int(v))
		p.sup = SuperTree.mods(p.hero, picks, Skills.MAX_LEVEL)
	p.max_hp = 99999.0
	p.hp = 99999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	p.facing = 1.0
	for dx in [8.0, 13.0, 19.0, -9.0]:
		_enemy(dx)
	await _wait(0.2)
	p.add_super(Player.SUPER_MAX)
	p._start_super()
	var n := 0
	for t in [0.25, 0.55, 0.9, 1.3, 1.7, 2.1, 2.5, 2.9]:
		await _wait(0.35 if n > 0 else 0.25)
		get_viewport().get_texture().get_image().save_png("user://super_%d_%d.png" % [p.hero, n])
		n += 1
	get_tree().quit()


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
