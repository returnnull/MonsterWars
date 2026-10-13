class_name StageBuilder
extends RefCounted
## Builds a level's world from a Content.COUNTRIES entry: sky and lighting,
## street, destructible buildings, background skyline, the country's landmark
## and weather. Everything is added as children of `root`.

var root: Node3D
var c: Dictionary
var length := 250.0
var rng := RandomNumberGenerator.new()


func _init(p_root: Node3D, country: Dictionary, stage_length: float, seed_value: int) -> void:
	root = p_root
	c = country
	length = stage_length
	rng.seed = seed_value


func build() -> void:
	Building.style = {"walls": c["walls"], "window": c["window"], "lit": c["lit"], "emission": c["emission"]}
	_environment()
	_ground()
	_city()
	_skyline()
	var x := 60.0
	while x < length + 60.0:
		_landmark(c["landmark"], x + rng.randf_range(-15, 15))
		x += rng.randf_range(110.0, 150.0)


## Returns a particle node for snow/rain to attach to the camera, or null.
func make_weather() -> Node3D:
	var kind: String = {"DENMARK": "rain", "RUSSIA": "snow", "ICELAND": "snow"}.get(c["name"], "")
	if kind == "":
		return null
	var p := GPUParticles3D.new()
	p.amount = 1500 if kind == "rain" else 900
	p.lifetime = 1.2 if kind == "rain" else 5.0
	p.preprocess = 4.0
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(40, 1, 18)
	pm.direction = Vector3(0.1 if kind == "rain" else 0.3, -1, 0)
	pm.spread = 4.0 if kind == "rain" else 20.0
	pm.initial_velocity_min = 28.0 if kind == "rain" else 2.0
	pm.initial_velocity_max = 34.0 if kind == "rain" else 4.0
	pm.gravity = Vector3(0, -9.8 if kind == "rain" else -0.5, 0)
	if kind == "rain":
		pm.particle_flag_align_y = true
	p.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.8, 0.9, 0.35) if kind == "rain" else Color(1, 1, 1, 0.9)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.9, 0.03) if kind == "rain" else Vector3(0.12, 0.12, 0.12)
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.position = Vector3(0, 22, -2)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = c["sky_top"]
	sky_mat.sky_horizon_color = c["sky_horizon"]
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = c["ground_horizon"]
	sky_mat.ground_bottom_color = Color(c["ground_horizon"]).darkened(0.8)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = c["ambient"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = c["exposure"]
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
	env.fog_light_color = c["fog"]
	env.fog_density = c["fog_density"]
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = c["sun"]
	sun.light_energy = c["sun_energy"]
	sun.rotation_degrees = c["sun_rot"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = c["fill"]
	fill.light_energy = c["fill_energy"]
	fill.rotation_degrees = Vector3(-35, 20, 0)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	root.add_child(fill)

	if c["name"] == "ICELAND":
		_aurora()


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2400, 2, 400)
	col.shape = shape
	col.position = Vector3(length * 0.5, -1, 0)
	body.add_child(col)
	root.add_child(body)

	var rough := NoiseTexture2D.new()
	rough.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 4
	rough.noise = n
	var mid := length * 0.5
	var span := length + 600.0

	var land := StandardMaterial3D.new()
	land.albedo_color = c["ground"]
	land.roughness = 1.0
	land.roughness_texture = rough
	land.uv1_triplanar = true
	land.uv1_scale = Vector3(0.05, 0.05, 0.05)
	_plane(Vector2(span, 400), land, Vector3(mid, 0, -60))

	var street := StandardMaterial3D.new()
	street.albedo_color = Color(0.09, 0.09, 0.1)
	street.roughness = 0.55
	street.roughness_texture = rough
	street.uv1_triplanar = true
	street.uv1_scale = Vector3(0.08, 0.08, 0.08)
	_plane(Vector2(span, 11), street, Vector3(mid, 0.01, -1.0))

	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.36, 0.35, 0.34)
	curb.roughness = 0.9
	_box(Vector3(span, 0.25, 1.6), curb, Vector3(mid, 0.12, -7.3))
	_box(Vector3(span, 0.25, 1.6), curb, Vector3(mid, 0.12, 5.3))
	_box(Vector3(span, 0.25, 6.0), curb, Vector3(mid, 0.12, 9.0))

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.75, 0.2)
	paint.emission_enabled = true
	paint.emission = Color(0.9, 0.65, 0.15)
	paint.emission_energy_multiplier = 0.3
	var x := -80.0
	while x < length + 100.0:
		_box(Vector3(3.0, 0.03, 0.25), paint, Vector3(x, 0.02, -1.0))
		x += 6.0

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.15, 0.15, 0.17)
	pole_mat.metallic = 0.7
	pole_mat.roughness = 0.4
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1, 0.9, 0.7)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = c["window"]
	bulb_mat.emission_energy_multiplier = 3.0
	x = -20.0
	while x < length + 40.0:
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
		x += 14.0

	x = -80.0
	while x < length + 100.0:
		_box(Vector3(0.12, 1.0, 0.12), pole_mat, Vector3(x, 0.5, 6.3))
		x += 6.0
	_box(Vector3(span, 0.1, 0.1), pole_mat, Vector3(mid, 1.0, 6.3))


func _city() -> void:
	var h: Vector2 = c["height"]
	var x := -20.0
	while x < length + 30.0:
		var w := rng.randf_range(6.0, 10.0)
		var d := rng.randf_range(6.0, 9.0)
		var b := Building.new()
		b.size = Vector3(w, rng.randf_range(h.x, h.y), d)
		b.position = Vector3(x + w * 0.5, 0, -7.0 - d * 0.5)
		root.add_child(b)
		x += w + rng.randf_range(1.0, 3.5)


func _skyline() -> void:
	var mats: Array[ShaderMaterial] = []
	var lit: float = c["lit"]
	for i in 6:
		mats.append(Building.make_material(rng.randf() * 10.0, lit * 0.8, float(c["emission"]) * 0.8))
	var h: Vector2 = c["height"]
	for row in 3:
		var x := -120.0
		while x < length + 170.0:
			var w := rng.randf_range(8.0, 16.0)
			var d := rng.randf_range(8.0, 14.0)
			var bh := rng.randf_range(h.x * 1.6, h.y * 2.4) * (1.0 + row * 0.35)
			var box := BoxMesh.new()
			box.size = Vector3(w, bh, d)
			var mi := _mesh(box, mats[rng.randi() % mats.size()], Vector3(x, bh * 0.5, -36.0 - row * 26.0 - rng.randf() * 8.0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if row > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			x += w + rng.randf_range(1.0, 6.0)


# --- landmarks -------------------------------------------------------------

func _landmark(kind: String, x: float) -> void:
	var z := -27.0
	match kind:
		"windmills":
			for i in 3:
				_windmill(Vector3(x + i * 14.0, 0, z - i * 4.0))
		"iron_tower":
			_lattice_tower(Vector3(x, 0, z - 6), 60.0, Color(0.35, 0.25, 0.18), Color(1.0, 0.8, 0.4))
		"radio_tower":
			_lattice_tower(Vector3(x, 0, z - 6), 64.0, Color(0.85, 0.2, 0.12), Color(1.0, 0.95, 0.95))
		"spires":
			_deco_spire(Vector3(x, 0, z - 4))
		"pyramids":
			for i in 3:
				var s := 30.0 - i * 8.0
				_pyramid(Vector3(x + i * 32.0, 0, z - 20.0 - i * 6.0), s)
		"sugarloaf":
			_hill(Vector3(x, 0, z - 30.0), 24.0, 46.0, Color(0.2, 0.32, 0.18))
			_hill(Vector3(x + 50.0, 0, z - 40.0), 30.0, 58.0, Color(0.18, 0.28, 0.16))
			_statue(Vector3(x + 50.0, 58.0, z - 40.0))
		"temple":
			_temple(Vector3(x, 0, z - 6))
		"sails":
			_sails(Vector3(x, 0, z - 4))
		"domes":
			for i in 4:
				_onion_dome(Vector3(x + i * 7.0, 0, z - 4.0 - (i % 2) * 4.0), 16.0 + (i % 3) * 6.0, i)
		"volcano":
			_volcano(Vector3(x + 20.0, 0, z - 70.0))


func _mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _frustum(bottom: float, top: float, h: float, sides: int = 4) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


func _windmill(pos: Vector3) -> void:
	var body := _mat(Color(0.85, 0.82, 0.75))
	var dark := _mat(Color(0.25, 0.22, 0.2))
	_mesh(_frustum(3.0, 1.8, 16.0, 8), body, pos + Vector3(0, 8, 0))
	var cap := SphereMesh.new()
	cap.radius = 2.2
	cap.height = 3.0
	_mesh(cap, dark, pos + Vector3(0, 16.5, 0))
	var hub := Node3D.new()
	hub.position = pos + Vector3(0, 16.5, 2.4)
	root.add_child(hub)
	for i in 4:
		var blade := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.4, 11.0, 0.2)
		blade.mesh = b
		blade.material_override = dark
		blade.position = Vector3(0, 5.5, 0).rotated(Vector3.BACK, i * PI / 2)
		blade.rotation.z = i * PI / 2
		hub.add_child(blade)
	var tw := hub.create_tween().set_loops()
	tw.tween_property(hub, "rotation:z", -TAU, 8.0 + rng.randf() * 4.0).from(0.0)


func _lattice_tower(pos: Vector3, h: float, color: Color, light: Color) -> void:
	var m := _mat(color, 0.5, 0.6)
	_mesh(_frustum(h * 0.16, h * 0.06, h * 0.32), m, pos + Vector3(0, h * 0.16, 0)).rotation.y = PI / 4
	_box(Vector3(h * 0.17, h * 0.02, h * 0.17), m, pos + Vector3(0, h * 0.33, 0))
	_mesh(_frustum(h * 0.06, h * 0.025, h * 0.38), m, pos + Vector3(0, h * 0.52, 0)).rotation.y = PI / 4
	_box(Vector3(h * 0.07, h * 0.015, h * 0.07), m, pos + Vector3(0, h * 0.71, 0))
	_mesh(_frustum(h * 0.025, 0.05, h * 0.3, 6), m, pos + Vector3(0, h * 0.86, 0))
	var lamp := SphereMesh.new()
	lamp.radius = 0.6
	lamp.height = 1.2
	_mesh(lamp, _glow(light, 6.0), pos + Vector3(0, h * 1.01, 0))
	for y in [0.33, 0.71]:
		var ring := TorusMesh.new()
		ring.inner_radius = h * (0.08 if y < 0.5 else 0.035)
		ring.outer_radius = ring.inner_radius + 0.3
		_mesh(ring, _glow(light, 2.0), pos + Vector3(0, h * y + 0.6, 0))


func _deco_spire(pos: Vector3) -> void:
	var m := _mat(Color(0.5, 0.5, 0.52), 0.4, 0.3)
	var w := 14.0
	var y := 0.0
	for i in 5:
		var h := 18.0 - i * 2.5
		_box(Vector3(w, h, w), m, pos + Vector3(0, y + h * 0.5, 0))
		y += h
		w *= 0.75
	_mesh(_frustum(w * 0.5, 0.1, 14.0, 8), m, pos + Vector3(0, y + 7.0, 0))
	var crown := TorusMesh.new()
	crown.inner_radius = w * 0.45
	crown.outer_radius = w * 0.5
	_mesh(crown, _glow(Color(1.0, 0.85, 0.5), 3.0), pos + Vector3(0, y + 0.5, 0))


func _pyramid(pos: Vector3, s: float) -> void:
	var m := _mat(Color(0.82, 0.68, 0.45), 0.95)
	_mesh(_frustum(s * 1.4, 0.0, s, 4), m, pos + Vector3(0, s * 0.5, 0)).rotation.y = PI / 4


func _hill(pos: Vector3, r: float, h: float, color: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	var mi := _mesh(s, _mat(color, 1.0), pos)
	mi.scale = Vector3(1.0, h / r, 1.0)


func _statue(pos: Vector3) -> void:
	var m := _mat(Color(0.9, 0.9, 0.88), 0.6)
	_box(Vector3(1.2, 8.0, 1.2), m, pos + Vector3(0, 4.0, 0))
	_box(Vector3(7.0, 1.0, 1.0), m, pos + Vector3(0, 6.5, 0))
	var head := SphereMesh.new()
	head.radius = 0.7
	head.height = 1.4
	_mesh(head, m, pos + Vector3(0, 8.6, 0))


func _temple(pos: Vector3) -> void:
	var stone := _mat(Color(0.75, 0.55, 0.4), 0.9)
	var y := 0.0
	var w := 12.0
	for i in 7:
		var h := 5.0
		_mesh(_frustum(w, w * 0.88, h, 4), stone, pos + Vector3(0, y + h * 0.5, 0)).rotation.y = PI / 4
		y += h
		w *= 0.8
	var dome := SphereMesh.new()
	dome.radius = w
	dome.height = w * 2.0
	_mesh(dome, _mat(Color(0.95, 0.75, 0.3), 0.3, 0.8), pos + Vector3(0, y, 0))
	_mesh(_frustum(0.4, 0.0, 4.0, 6), _glow(Color(1.0, 0.8, 0.3), 2.0), pos + Vector3(0, y + w + 2.0, 0))


func _sails(pos: Vector3) -> void:
	var white := _mat(Color(0.95, 0.95, 0.92), 0.3)
	_box(Vector3(40.0, 4.0, 16.0), _mat(Color(0.6, 0.5, 0.4), 0.9), pos + Vector3(0, 2.0, 0))
	for i in 5:
		var s := SphereMesh.new()
		s.radius = 9.0 - absf(i - 2) * 1.5
		s.height = s.radius
		s.is_hemisphere = true
		var mi := _mesh(s, white, pos + Vector3(-14.0 + i * 7.0, 4.0, 0))
		mi.scale = Vector3(0.45, 2.0, 1.0)
		mi.rotation.z = -0.5


func _onion_dome(pos: Vector3, h: float, i: int) -> void:
	var colors := [Color(0.85, 0.2, 0.2), Color(0.2, 0.55, 0.4), Color(0.95, 0.75, 0.25), Color(0.25, 0.4, 0.8)]
	var wall := _mat(Color(0.88, 0.85, 0.78), 0.8)
	_mesh(_frustum(2.4, 2.2, h, 8), wall, pos + Vector3(0, h * 0.5, 0))
	var bulb := SphereMesh.new()
	bulb.radius = 3.2
	bulb.height = 6.4
	var mi := _mesh(bulb, _mat(colors[i % colors.size()], 0.35, 0.4), pos + Vector3(0, h + 2.2, 0))
	mi.scale = Vector3(1.0, 1.15, 1.0)
	_mesh(_frustum(1.4, 0.0, 4.0, 8), _mat(Color(0.95, 0.8, 0.3), 0.3, 0.8), pos + Vector3(0, h + 6.5, 0))


func _volcano(pos: Vector3) -> void:
	_mesh(_frustum(70.0, 9.0, 55.0, 24), _mat(Color(0.12, 0.11, 0.12), 1.0), pos + Vector3(0, 27.5, 0))
	_mesh(_frustum(9.0, 8.0, 1.0, 24), _glow(Color(1.0, 0.35, 0.05), 8.0), pos + Vector3(0, 55.2, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.4, 0.1)
	l.light_energy = 6.0
	l.omni_range = 40.0
	l.position = pos + Vector3(0, 60, 0)
	root.add_child(l)


func _aurora() -> void:
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(0.1, 1.0, 0.5, 0.0), Color(0.2, 1.0, 0.6, 0.6), Color(0.5, 0.2, 1.0, 0.0)])
	tex.gradient = g
	tex.fill_from = Vector2(0, 1)
	tex.fill_to = Vector2(0, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.4, 1.4, 1.4)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	var x := -100.0
	while x < length + 150.0:
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(80, 140), rng.randf_range(40, 70))
		var mi := _mesh(q, mat, Vector3(x, 75.0 + rng.randf() * 20.0, -180.0 - rng.randf() * 40.0))
		mi.rotation.y = rng.randf_range(-0.4, 0.4)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x += rng.randf_range(70, 110)


# --- mesh helpers ----------------------------------------------------------

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
	root.add_child(mi)
	return mi
