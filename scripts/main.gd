extends Node3D
## Stage 1, "Neon Harbor District": builds the lighting, street, city and
## skyline, then runs the arena waves until the boss is down.

const STAGE_END := 250.0
const WAVES := [
	{"x": 35.0, "title": "WAVE 1", "spawn": ["brute", "brute"]},
	{"x": 95.0, "title": "WAVE 2", "spawn": ["brute", "flyer", "flyer"]},
	{"x": 155.0, "title": "WAVE 3", "spawn": ["brute", "brute", "flyer", "flyer"]},
	{"x": 225.0, "title": "BOSS", "spawn": ["boss", "flyer"]},
]

var player: Player
var hud: Hud
var cam: CameraRig
var _wave := 0
var _wave_active := false
var _alive := 0
var _finished := false


func _ready() -> void:
	randomize()
	Game.reset()
	Game.world = self
	_build_environment()
	_build_ground()
	_build_city()
	_build_skyline()

	player = Player.new()
	player.position = Vector3(0, 0.2, 0)
	add_child(player)
	player.died.connect(_on_player_died)

	cam = CameraRig.new()
	cam.target = player
	add_child(cam)
	Game.camera_rig = cam

	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	hud.show_message("SMASH THE CITY!", 2.2)
	_update_limits()


func _physics_process(_delta: float) -> void:
	if _finished or _wave_active or _wave >= WAVES.size():
		return
	if player.global_position.x >= WAVES[_wave]["x"] - 4.0:
		_start_wave()


func _update_limits() -> void:
	player.x_min = -8.0
	player.x_max = (WAVES[_wave]["x"] + 4.0) if _wave < WAVES.size() else STAGE_END


func _start_wave() -> void:
	_wave_active = true
	var w: Dictionary = WAVES[_wave]
	var cx: float = w["x"]
	player.x_min = cx - 20.0
	player.x_max = cx + 20.0
	hud.show_message(w["title"], 1.6)
	var kinds: Array = w["spawn"]
	_alive = kinds.size()
	for i in kinds.size():
		_spawn(kinds[i], cx, i)


func _spawn(kind: String, cx: float, i: int) -> void:
	await get_tree().create_timer(0.3 + i * 0.9, false).timeout
	var side := 1.0 if i % 2 == 0 else -1.0
	if kind == "flyer":
		var f := Flyer.new()
		f.position = Vector3(cx + side * 26.0, 14.0, -2.0)
		add_child(f)
		f.died.connect(_on_enemy_died)
	else:
		var b := Brute.new()
		b.is_boss = kind == "boss"
		b.position = Vector3(cx + side * 23.0, 0.2, randf_range(-3.0, 2.0))
		b.facing = -side
		add_child(b)
		b.died.connect(_on_enemy_died)
		if b.is_boss:
			hud.show_boss(b)
			Game.shake(0.8)


func _on_enemy_died(_who: Node) -> void:
	_alive -= 1
	if _alive > 0 or not _wave_active:
		return
	_wave_active = false
	_wave += 1
	if _wave >= WAVES.size():
		_finished = true
		await get_tree().create_timer(2.5, false).timeout
		hud.show_end("STAGE CLEAR", true)
	else:
		hud.show_message("GO  >>", 1.6)
		_update_limits()


func _on_player_died(_who: Node) -> void:
	if _finished:
		return
	_finished = true
	hud.show_end("GAME OVER", false)


# --- stage construction ----------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.11, 0.3)
	sky_mat.sky_horizon_color = Color(0.95, 0.5, 0.32)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.55, 0.32, 0.26)
	sky_mat.ground_bottom_color = Color(0.06, 0.05, 0.08)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 0.6)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(5, 0.5)
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.5, 0.45)
	env.fog_density = 0.0055
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Low sun behind the skyline (rim light), plus a cool fill from the camera side.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 1.7
	sun.rotation_degrees = Vector3(-18, 155, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.65, 1.0)
	fill.light_energy = 1.3
	fill.rotation_degrees = Vector3(-35, 20, 0)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000, 2, 400)
	col.shape = shape
	col.position = Vector3(120, -1, 0)
	body.add_child(col)
	add_child(body)

	var rough := NoiseTexture2D.new()
	rough.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 4
	rough.noise = n

	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.12, 0.12, 0.13)
	asphalt.roughness = 1.0
	asphalt.roughness_texture = rough
	asphalt.uv1_triplanar = true
	asphalt.uv1_scale = Vector3(0.05, 0.05, 0.05)
	_plane(Vector2(900, 400), asphalt, Vector3(120, 0, -60))

	var street := StandardMaterial3D.new()
	street.albedo_color = Color(0.09, 0.09, 0.1)
	street.roughness = 0.55
	street.roughness_texture = rough
	street.uv1_triplanar = true
	street.uv1_scale = Vector3(0.08, 0.08, 0.08)
	_plane(Vector2(900, 11), street, Vector3(120, 0.01, -1.0))

	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.36, 0.35, 0.34)
	curb.roughness = 0.9
	_box(Vector3(900, 0.25, 1.6), curb, Vector3(120, 0.12, -7.3))
	_box(Vector3(900, 0.25, 1.6), curb, Vector3(120, 0.12, 5.3))

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.75, 0.2)
	paint.emission_enabled = true
	paint.emission = Color(0.9, 0.65, 0.15)
	paint.emission_energy_multiplier = 0.3
	for i in 90:
		_box(Vector3(3.0, 0.03, 0.25), paint, Vector3(-80 + i * 6.0, 0.02, -1.0))

	# Street lamps along the back sidewalk.
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.15, 0.15, 0.17)
	pole_mat.metallic = 0.7
	pole_mat.roughness = 0.4
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1, 0.9, 0.7)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.8, 0.5)
	bulb_mat.emission_energy_multiplier = 3.0
	for i in 22:
		var x := -20.0 + i * 14.0
		var pole := CylinderMesh.new()
		pole.top_radius = 0.08
		pole.bottom_radius = 0.12
		pole.height = 4.5
		_mesh(pole, pole_mat, Vector3(x, 2.25, -6.9))
		_box(Vector3(1.2, 0.1, 0.1), pole_mat, Vector3(x + 0.5, 4.5, -6.9))
		var bulb := SphereMesh.new()
		bulb.radius = 0.18
		bulb.height = 0.3
		_mesh(bulb, bulb_mat, Vector3(x + 1.0, 4.4, -6.9))

	# A low railing along the near sidewalk.
	for i in 90:
		_box(Vector3(0.12, 1.0, 0.12), pole_mat, Vector3(-80 + i * 6.0, 0.5, 6.3))
	_box(Vector3(900, 0.1, 0.1), pole_mat, Vector3(120, 1.0, 6.3))
	_box(Vector3(900, 0.25, 6.0), curb, Vector3(120, 0.12, 9.0))


func _build_city() -> void:
	# Back row: tall towers you can smash from the far side of the street.
	var x := -20.0
	while x < STAGE_END + 30.0:
		var w := randf_range(6.0, 10.0)
		var d := randf_range(6.0, 9.0)
		var h := randf_range(6.0, 17.0)
		_building(Vector3(w, h, d), Vector3(x + w * 0.5, 0, -7.0 - d * 0.5))
		x += w + randf_range(1.0, 3.5)


func _building(size: Vector3, pos: Vector3) -> void:
	var b := Building.new()
	b.size = size
	b.position = pos
	add_child(b)


func _build_skyline() -> void:
	var mats: Array[ShaderMaterial] = []
	for i in 6:
		mats.append(Building.make_material(randf() * 10.0, randf_range(0.15, 0.35), 1.1))
	for row in 3:
		var x := -120.0
		while x < 420.0:
			var w := randf_range(8.0, 16.0)
			var d := randf_range(8.0, 14.0)
			var h := randf_range(18.0, 55.0) * (1.0 + row * 0.35)
			var box := BoxMesh.new()
			box.size = Vector3(w, h, d)
			var mi := _mesh(box, mats.pick_random(), Vector3(x, h * 0.5, -32.0 - row * 26.0 - randf() * 8.0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if row > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			x += w + randf_range(1.0, 6.0)


func _plane(size: Vector2, mat: Material, pos: Vector3) -> void:
	var p := PlaneMesh.new()
	p.size = size
	_mesh(p, mat, pos)


func _box(size: Vector3, mat: Material, pos: Vector3) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(b, mat, pos)


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
