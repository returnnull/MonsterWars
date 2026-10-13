extends Node
## Dev smoke test: plays the stage by pressing each player's actions.
##   godot --headless --path . res://tests/autoplay.tscn
## Env: AUTOPLAY_PLAYERS (1-4), AUTOPLAY_SPEED, AUTOPLAY_MAX (seconds),
##      AUTOPLAY_SHOTS (comma-separated times to save screenshots), AUTOPLAY_RAGE.

var t := 0.0
var main: Node
var log_t := 0.0
var want_players := 1


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	want_players = int(_env("AUTOPLAY_PLAYERS", "1"))
	Engine.time_scale = float(_env("AUTOPLAY_SPEED", "1"))


func _press(slot: int, a: String) -> void:
	var action := "p%d_%s" % [slot, a]
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _physics_process(delta: float) -> void:
	t += delta
	# Join extra players one by one during the first seconds.
	for slot in range(1, want_players):
		if absf(t - slot * 1.5) < delta:
			_press(slot, "jump")
	for p in Game.players:
		if not is_instance_valid(p):
			continue
		if p.max_hp < 99999.0 and _env("AUTOPLAY_MORTAL", "") == "":
			p.max_hp = 99999.0
			p.hp = 99999.0
			if _env("AUTOPLAY_RAGE", "") != "":
				p.add_rage(100.0)
		_drive(p, delta)
	# AUTOPLAY_KILL: down P2 early (should revive after the wave), then everyone (game over).
	if _env("AUTOPLAY_KILL", "") != "":
		if absf(t - 8.0) < delta and Game.players.size() > 1:
			Game.players[1].take_hit(1e6, Vector3.ZERO)
			print("killed P2")
		if absf(t - 60.0) < delta:
			print("P2 dead before kill-all: ", Game.players[1].dead)
			for p in Game.players:
				p.take_hit(1e6, Vector3.ZERO)
			print("killed all")
		if main._finished and main.hud._ended:
			print("END SCREEN: ", main.hud._end_title.text)
			get_tree().quit()
	log_t += delta
	for st in _env("AUTOPLAY_SHOTS", "").split(",", false):
		if t - delta < float(st) and t >= float(st):
			get_viewport().get_texture().get_image().save_png("user://shot_%03d.png" % int(float(st)))
			print("shot ", st)
	if log_t > 5.0:
		log_t = 0.0
		var xs := Game.players.map(func(p): return "%.0f" % p.global_position.x)
		print("t=%.0f players=%d x=%s wave=%d enemies=%d score=%d destroyed=%d/%d" % [t, Game.players.size(), ",".join(xs),
			main._wave, _enemies().size(), Game.score, Game.buildings_destroyed, Game.buildings_total])
	if main._finished and main._wave >= main.WAVES.size():
		print("STAGE CLEARED at t=%.1f score=%d players=%d" % [t, Game.score, Game.players.size()])
		get_tree().quit()
	if t > float(_env("AUTOPLAY_MAX", "400")):
		print("TIMEOUT")
		get_tree().quit()


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.dead)


func _drive(p: Player, delta: float) -> void:
	var s := p.slot
	var enemies := _enemies()
	var target_x: float = p.x_max
	if enemies.size() > 0:
		target_x = enemies[s % enemies.size()].global_position.x
	Input.action_release("p%d_move_left" % s)
	Input.action_release("p%d_move_right" % s)
	if target_x > p.global_position.x + 3.0:
		Input.action_press("p%d_move_right" % s)
	elif target_x < p.global_position.x - 3.0:
		Input.action_press("p%d_move_left" % s)
	var off := s * 0.07
	if fmod(t + off, 0.35) < delta: _press(s, "light")
	if fmod(t + off, 2.1) < delta: _press(s, "heavy")
	if fmod(t + off, 3.3) < delta: _press(s, "jump")
	if fmod(t + off, 3.6) < delta: _press(s, "light")
	if p.rage >= 100.0 and not Input.is_action_pressed("p%d_special" % s): _press(s, "special")
