extends Node3D
## Dev helper: close-up screenshots of the hero kaiju models.
##   HERO_IDS "0,2,5" picks heroes (default all, four per shot), HERO_WALK=1
##   makes them walk, HERO_STRIP=1 shoots one walking hero eight times in a row
##   to check the stride. Shots go to user://heroes_N.png / user://stride_N.png.

const PER_SHOT := 4


func _ready() -> void:
	Game.set_meta("no_save", true)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 60)
	mi.mesh = pm
	add_child(mi)
	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	var ids: Array = []
	var only := OS.get_environment("HERO_IDS")
	if only != "":
		for s in only.split(","):
			ids.append(int(s))
	else:
		ids = range(Content.HEROES.size())
	var walk := OS.get_environment("HERO_WALK") == "1"
	if OS.get_environment("HERO_STRIP") == "1":
		var m := _make(ids[0], walk or true)
		m.rotation.y = -0.35
		cam.position = Vector3(0.5, 5.0, 20.0)
		cam.look_at(Vector3(0.5, 3.8, 0))
		await get_tree().create_timer(1.0).timeout
		for n in 8:
			get_viewport().get_texture().get_image().save_png("user://stride_%d.png" % n)
			await get_tree().create_timer(0.09).timeout
		print("shot stride of hero %d" % ids[0])
		get_tree().quit()
		return
	for start in range(0, ids.size(), PER_SHOT):
		var group := ids.slice(start, start + PER_SHOT)
		var made: Array = []
		for i in group.size():
			var m := _make(group[i], walk)
			m.position.x = i * 11.0
			m.rotation.y = -0.45
			made.append(m)
		cam.position = Vector3((group.size() - 1) * 5.5, 6.0, 30.0)
		cam.look_at(Vector3((group.size() - 1) * 5.5, 3.6, 0))
		await get_tree().create_timer(1.0).timeout
		var n := start / PER_SHOT
		get_viewport().get_texture().get_image().save_png("user://heroes_%d.png" % n)
		print("shot heroes_%d: %s" % [n, group])
		for m in made:
			m.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _make(i: int, walk: bool) -> KaijuModel:
	var h := Content.hero(i)
	var m := KaijuModel.new()
	add_child(m)
	m.build(h["skin"], h["belly"], h["accent"], h["eye"], h["horns"])
	m.scale = Vector3.ONE * float(h["size"])
	m.walk_amount = 1.0 if walk else 0.0
	m.glow = 0.4
	return m
