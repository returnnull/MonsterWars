extends Node
## Dev helper: screenshots of rage mode fire and the jump, to judge how they
## look. SHOTS picks "light", "heavy", "jump" (default all), HERO the hero
## (default 0). Shots go to user://rage_<hero>_<what>_N.png.

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
	p.max_hp = 99999.0
	p.hp = 99999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	p.facing = 1.0
	var what := OS.get_environment("SHOTS")
	if what == "" or "light" in what:
		await _light()
	if what == "" or "heavy" in what:
		await _heavy()
	if "attack" in what:
		await _attack()
	if what == "" or "jump" in what:
		await _jump()
	get_tree().quit()


func _light() -> void:
	var e := _enemy(16.0)
	_rage()
	var n := 0
	for a in ["fire1", "fire2", "fire3"]:
		p._start_attack(a)
		for f in 4:
			await _wait(0.09)
			_shot("light", n)
			n += 1
		while p.state == Player.S.ATTACK:
			await get_tree().physics_frame
	await _wait(1.0)
	e.queue_free()


func _heavy() -> void:
	var e := _enemy(8.0)
	_rage()
	p._start_attack("flame")
	for f in 8:
		await _wait(0.2)
		_shot("heavy", f)
	while p.state == Player.S.ATTACK:
		await get_tree().physics_frame
	await _wait(1.0)
	e.queue_free()


## The hero's rage attack (special + heavy).
func _attack() -> void:
	var e := _enemy(9.0)
	var e2 := _enemy(16.0)
	p._exit_rage_mode()
	p.rage = 100.0
	p._use_rage_skill("attack")
	for f in 8:
		await _wait(0.3)
		_shot("attack", f)
	while p.state == Player.S.BEAM:
		await get_tree().physics_frame
	e.queue_free()
	e2.queue_free()


func _jump() -> void:
	p._exit_rage_mode()
	await _wait(0.5)
	p._buffered = "jump"
	p._buffer_t = 0.3
	for f in 16:
		await _wait(0.07)
		_shot("jump", f)


func _shot(what: String, n: int) -> void:
	get_viewport().get_texture().get_image().save_png("user://rage_%d_%s_%d.png" % [p.hero, what, n])


func _rage() -> void:
	p.rage = 100.0
	if not p.raging:
		p._enter_rage_mode()


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
