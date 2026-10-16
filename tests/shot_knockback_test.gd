extends Node
## Dev check: a plain enemy shot hurts player 1 without pushing or staggering
## it, while a splash shot (shell/bomb/missile) still knocks it back.
## Prints PASS/FAIL per step.

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
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	for splash in [0.0, 2.2]:
		var hp0 := p.hp
		var x0 := p.global_position.x
		var b := Projectile.new()
		b.style = "bullet" if splash == 0.0 else "shell"
		b.splash = splash
		b.damage = 10.0
		main.add_child(b)
		b.global_position = p.hit_center() + Vector3(-3.0, 0, 0)
		b.velocity = Vector3(30.0, 0, 0)
		await _wait(0.15)
		var hurt := p.state == Player.S.HURT
		var pushed := absf(p.global_position.x - x0) + absf(p.knock.x)
		var ok := p.hp < hp0 and ((not hurt and pushed < 0.05) if splash == 0.0 else pushed > 0.5)
		print("%s shot: %s (hp %.0f -> %.0f, pushed %.2f, staggered %s)" % [
			"plain" if splash == 0.0 else "splash", "PASS" if ok else "FAIL", hp0, p.hp, pushed, hurt])
		await _wait(1.0)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
