extends Node3D
## Dev helper: lines up every enemy kaiju type and saves screenshots to
## user://bestiary_N.png, four types per shot. BESTIARY_IDS "a,b" picks the
## ids instead (any class; "boss3" is country 4's boss).

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
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Game.LAYER_WORLD
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 60)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 60)
	mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.33, 0.35)
	mi.material_override = fm
	floor_body.add_child(mi)
	add_child(floor_body)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)

	var ids: Array = []
	var only := OS.get_environment("BESTIARY_IDS")
	if only != "":
		ids = Array(only.split(","))
	else:
		for k in Enemies.DEFS:
			if Enemies.DEFS[k]["class"] == "kaiju":
				ids.append(k)
	for start in range(0, ids.size(), PER_SHOT):
		var group := ids.slice(start, start + PER_SHOT)
		var spawned: Array = []
		for i in group.size():
			var b := _make(group[i])
			b.facing = -1.0 if i % 2 == 1 else 1.0
			add_child(b)
			b.global_position = Vector3(i * 17.0 + (randf_range(-2, 2) if b is Infantry else 0.0), 0.5, 0)
			spawned.append(b)
		cam.position = Vector3((group.size() - 1) * 8.5, 8.5, 44.0)
		cam.look_at(Vector3((group.size() - 1) * 8.5, 3.0, 0))
		await get_tree().create_timer(1.2).timeout
		var n := start / PER_SHOT
		get_viewport().get_texture().get_image().save_png("user://bestiary_%d.png" % n)
		print("shot bestiary_%d: %s" % [n, ", ".join(group)])
		for b in spawned:
			b.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _make(id: String) -> Node3D:
	if id.begins_with("boss"):
		var bb := Brute.new()
		bb.kind = "boss"
		bb.boss_def = Content.boss(int(id.substr(4)))
		return bb
	match Enemies.get_def(id)["class"]:
		"infantry":
			var s := Infantry.new()
			s.kind = id
			return s
		"ground":
			var v := Vehicle.new()
			v.kind = id
			return v
		"air":
			var f := Flyer.new()
			f.kind = id
			return f
	var b := Brute.new()
	b.kind = id
	return b
