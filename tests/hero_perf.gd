extends Node3D
## Dev helper: how many triangles the hero models cost per frame.
##   godot --path . res://tests/hero_perf.tscn
## Puts HERO_COUNT heroes (default 4) walking at the game camera's distance
## under a shadow-casting sun and prints the triangles drawn per frame with
## and without them, near (gameplay zoom) and far (zoomed out).

func _ready() -> void:
	Game.set_meta("no_save", true)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	add_child(we)
	var cam := Camera3D.new()
	cam.fov = 46.0
	add_child(cam)
	var models: Array = []
	for i in int(OS.get_environment("HERO_COUNT") if OS.get_environment("HERO_COUNT") != "" else "4"):
		var h := Content.hero(i)
		var m := GlbKaijuModel.for_hero(h, self)
		m.scale = Vector3.ONE * float(h["size"])
		m.walk_amount = 1.0
		m.position.x = i * 7.0 - 10.0
		models.append(m)
	for dist in [24.0, 34.0, 60.0]:
		cam.position = Vector3(0, 9.0, dist)
		cam.look_at(Vector3(0, 4.0, 0))
		for m in models:
			m.visible = true
		var with := await _tris()
		if OS.get_environment("HERO_PERF_SHOT") != "":  # saves user://perf_<value>_<dist>.png
			get_viewport().get_texture().get_image().save_png("user://perf_%s_%d.png" % [OS.get_environment("HERO_PERF_SHOT"), int(dist)])
		for m in models:
			m.visible = false
		var without := await _tris()
		print("camera %.0f m: heroes draw %dk triangles (%dk in all)" % [dist, (with - without) / 1000, with / 1000])
	get_tree().quit()


func _tris() -> int:
	for i in 4:
		await get_tree().process_frame
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
