extends Node
## Dev helper: films the light attacks (light1, light2, light3) of a hero
## from the side, close up, and saves a frame every FRAME_STEP seconds to
## user://attack_shots/<attack>_NN.png. ATTACK_HERO picks the hero (default 0).
##   xvfb-run godot --path . res://tests/attack_shots.tscn

const FRAME_STEP := 0.05

var main: Node
var p: Player
var cam := Camera3D.new()


func _ready() -> void:
	Game.set_meta("no_save", true)
	var hero := int(OS.get_environment("ATTACK_HERO")) if OS.get_environment("ATTACK_HERO") != "" else 0
	Game.party = {0: hero}
	Game.level = Content.level(0, 0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	p = Game.players[0]
	p.max_hp = 99999.0
	p.hp = 99999.0
	for n in get_tree().get_nodes_in_group("enemies"):
		n.queue_free()
	# Let the level title fade first.
	await _wait(2.5)
	p.facing = 1.0
	cam.fov = 38.0
	add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/attack_shots")
	for i in 3:
		while p._attack_cd > 0.0 or p.state != Player.S.FREE:
			await get_tree().physics_frame
		var e := _enemy(3.2)
		var name := "light%d" % (i + 1)
		Input.action_press("p0_light")
		var t := 0.0
		var n := 0
		while t < 0.5:
			_aim()
			await RenderingServer.frame_post_draw
			if t >= n * FRAME_STEP:
				get_viewport().get_texture().get_image().save_png("user://attack_shots/%s_%02d.png" % [name, n])
				n += 1
			t += get_process_delta_time()
			if t > 0.05:
				Input.action_release("p0_light")
		e.queue_free()
	print("attack shots saved to ", OS.get_user_data_dir() + "/attack_shots")
	get_tree().quit()


func _aim() -> void:
	var f := p.global_position + Vector3(2.0, 3.0, 0)
	cam.global_position = f + Vector3(0, 0.5, 16.0)
	cam.look_at(f)


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
