extends Node
## Dev smoke test: plays the stage by pressing actions. Run with
## godot --path . res://tests/autoplay.tscn  (add --headless for CI)

var t := 0.0
var shots := 0
var main: Node
var log_t := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.player.max_hp = 99999.0
	main.player.hp = 99999.0
	if OS.get_environment("AUTOPLAY_RAGE") != "": main.player.add_rage(100.0)
	Engine.time_scale = float(OS.get_environment("AUTOPLAY_SPEED")) if OS.get_environment("AUTOPLAY_SPEED") != "" else 1.0

func _press(a: String) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(a)

func _physics_process(delta: float) -> void:
	t += delta
	var p = main.player
	var enemies := get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.dead)
	var target_x: float = p.x_max
	if enemies.size() > 0:
		target_x = enemies[0].global_position.x
	Input.action_release("move_left"); Input.action_release("move_right")
	if target_x > p.global_position.x + 3.0: Input.action_press("move_right")
	elif target_x < p.global_position.x - 3.0: Input.action_press("move_left")
	if fmod(t, 0.35) < delta: _press("light")
	if fmod(t, 2.1) < delta: _press("heavy")
	if fmod(t, 3.3) < delta: _press("jump")
	if fmod(t, 3.3 + 0.3) < delta: _press("light")
	if p.rage >= 100.0 and not Input.is_action_pressed("special"): _press("special")
	for st in OS.get_environment("AUTOPLAY_SHOTS").split(",", false):
		if t - delta < float(st) and t >= float(st):
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot_%03d.png" % int(float(st)))
			print("shot ", st)
	log_t += delta
	if log_t > 5.0:
		log_t = 0.0
		print("t=%.0f x=%.1f wave=%d enemies=%d score=%d destroyed=%d/%d rage=%.0f fps=%d" % [t, p.global_position.x, main._wave, enemies.size(), Game.score, Game.buildings_destroyed, Game.buildings_total, p.rage, Engine.get_frames_per_second()])
	if main._finished and main._wave >= 4:
		print("STAGE CLEARED at t=%.1f score=%d" % [t, Game.score])
		get_tree().quit()
	if t > float(OS.get_environment("AUTOPLAY_MAX") if OS.get_environment("AUTOPLAY_MAX") != "" else "400"):
		print("TIMEOUT"); get_tree().quit()
