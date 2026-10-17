extends Node
## Dev helper: shots of player 1 carrying each building piece in its jaws,
## from the game camera and close up. Shots go to user://bite_<kind>.png and
## user://bite_<kind>_close.png. BITE_HERO picks the hero (default 0).


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.party = {0: int(OS.get_environment("BITE_HERO")) if OS.get_environment("BITE_HERO") != "" else 0}
	Game.level = Content.level(0, 0)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(4.0).timeout
	var p: Player = Game.players[0]
	p.max_hp = 99999.0
	p.hp = 99999.0
	var game_cam := get_viewport().get_camera_3d()
	var close := Camera3D.new()
	close.fov = 35.0
	main.add_child(close)
	for kind in Weapon.KINDS:
		p._set_weapon(kind)
		await get_tree().create_timer(0.6).timeout
		game_cam.make_current()
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://bite_%s.png" % kind)
		var head := p.model.mouth_global()
		close.global_position = head + Vector3(1.0, 1.0, 14.0)
		close.look_at(head)
		close.make_current()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://bite_%s_close.png" % kind)
		print("shot bite_%s" % kind)
	get_tree().quit()
