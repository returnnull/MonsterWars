class_name StageBuilder
extends RefCounted
## Builds a level's world from a Content.COUNTRIES entry: sky and lighting,
## the boulevard with its street furniture and traffic, the destructible
## front row of buildings, three layers of background city with side streets
## running into the distance, the country's landmark and weather. Everything
## is added as children of `root`. Repeated props use MultiMesh.

const ROAD_Z := -1.0
const ROAD_HALF := 5.5
const BACK_CURB := -6.75
const FRONT_CURB := 4.75
const CROSS_HALF := 3.0

var root: Node3D
var c: Dictionary
var look: Dictionary
var length := 250.0
var rng := RandomNumberGenerator.new()
var night := false
var crossings: Array[float] = []
var _clear: Array = []  # [x0, x1, z] spans kept free for landmarks


func _init(p_root: Node3D, country: Dictionary, stage_length: float, seed_value: int) -> void:
	root = p_root
	c = country
	look = c.get("look", {})
	night = look.get("night", false)
	length = stage_length
	rng.seed = seed_value


func build() -> void:
	Building.style = {"walls": c["walls"], "window": c["window"], "lit": c["lit"], "emission": c["emission"],
		"facades": look.get("facades", [0.4, 0.3, 0.2, 0.1]), "roofs": look.get("roofs", ["flat", "tank"]),
		"roof_colors": look.get("roof_colors", [Color(0.3, 0.3, 0.32)]), "neon": look.get("neon", 0.0),
		"snow": look.get("snow", 0.0), "shop": look.get("shop", 1.0 if night else 0.35),
		"roof_flat": look.get("roof_flat", Color(0.3, 0.3, 0.31))}
	if look.has("neon_colors"):
		Building.style["neon_colors"] = look["neon_colors"]
	_plan()
	_environment()
	_ground()
	_street_props()
	_cars()
	_city()
	_skyline()
	_sky_life()
	for lx in _landmark_xs:
		_landmark(c["landmark"], lx)


var _landmark_xs: Array[float] = []


## Decides where side streets and landmarks go, so the rows of buildings
## can leave room for them.
func _plan() -> void:
	var x := rng.randf_range(10.0, 25.0)
	while x < length + 60.0:
		crossings.append(x)
		x += rng.randf_range(34.0, 52.0)
	x = 60.0
	while x < length + 60.0:
		var lx := x + rng.randf_range(-15, 15)
		_landmark_xs.append(lx)
		var span: Vector3 = {"windmills": Vector3(-6, 34, -27), "iron_tower": Vector3(-13, 13, -33),
			"radio_tower": Vector3(-13, 13, -33), "spires": Vector3(-10, 10, -31), "pyramids": Vector3(-42, 106, -47),
			"sugarloaf": Vector3(-26, 82, -57), "temple": Vector3(-11, 11, -33), "sails": Vector3(-23, 23, -31),
			"domes": Vector3(-6, 27, -31), "volcano": Vector3(-20, 60, -97)}.get(c["landmark"], Vector3(-10, 10, -30))
		_clear.append([lx + span.x, lx + span.y, span.z])
		x += rng.randf_range(110.0, 150.0)


func _near_crossing(x0: float, x1: float, pad: float = 0.0) -> bool:
	for cx in crossings:
		if x1 > cx - CROSS_HALF - pad and x0 < cx + CROSS_HALF + pad:
			return true
	return false


## True if a background building at [x0,x1] whose front is at depth z would
## hide a landmark.
func _blocks_landmark(x0: float, x1: float, z: float) -> bool:
	for cl in _clear:
		if x1 > cl[0] and x0 < cl[1] and z > cl[2] - 6.0:
			return true
	return false


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
	else:
		pm.scale_min = 0.5
		pm.scale_max = 1.2
	p.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.8, 0.9, 0.3) if kind == "rain" else Color(1, 1, 1, 0.9)
	var mesh: Mesh
	if kind == "rain":
		var b := BoxMesh.new()
		b.size = Vector3(0.025, 0.9, 0.025)
		mesh = b
	else:
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.14)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = _radial_tex(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
		mesh = q
	(mesh as PrimitiveMesh).material = mat
	p.draw_pass_1 = mesh
	p.position = Vector3(0, 22, -2)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# --- sky, light, post ------------------------------------------------------

func _environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("top_color", c["sky_top"])
	sky_mat.set_shader_parameter("horizon_color", c["sky_horizon"])
	sky_mat.set_shader_parameter("ground_color", Color(c["ground_horizon"]).darkened(0.5))
	sky_mat.set_shader_parameter("cover", look.get("cloud_cover", 0.4))
	sky_mat.set_shader_parameter("cloud_color", look.get("cloud_color", Color(1, 1, 1)))
	sky_mat.set_shader_parameter("cloud_shade", look.get("cloud_shade", Color(0.55, 0.6, 0.7)))
	sky_mat.set_shader_parameter("city_glow", look.get("city_glow", Color(0, 0, 0)))
	sky_mat.set_shader_parameter("stars", look.get("stars", 0.0))
	sky_mat.set_shader_parameter("sun_strength", look.get("sun_strength", 0.35 if night else 1.0))
	sky_mat.set_shader_parameter("sun_size", 0.02 if night else 0.035)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = c["ambient"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = c["exposure"]
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6 if night else 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 0.6)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(5, 0.5)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_detail = 0.6
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.fog_enabled = true
	env.fog_light_color = c["fog"]
	env.fog_density = c["fog_density"] * 0.85
	env.fog_sun_scatter = 0.3
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.25
	# Low haze between the buildings deepens the street canyons.
	env.fog_height = 3.0
	env.fog_height_density = c["fog_density"] * 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = look.get("saturation", 1.1)
	env.adjustment_contrast = 1.08
	env.adjustment_color_correction = _grade(look.get("grade_shadow", Color(0.0, 0.01, 0.03)))
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = c["sun"]
	sun.light_energy = c["sun_energy"]
	sun.rotation_degrees = c["sun_rot"]
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = c["fill"]
	fill.light_energy = c["fill_energy"]
	fill.rotation_degrees = Vector3(-35, 20, 0)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	root.add_child(fill)
	# Back rim light, so the kaiju separate from busy facades. Forward+ only:
	# a third directional light crashes the Mobile renderer in some stages.
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		if c["name"] == "ICELAND":
			_aurora()
		return
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(c["sky_horizon"]).lerp(Color.WHITE, 0.3)
	rim.light_energy = 0.7 if night else 0.45
	rim.rotation_degrees = Vector3(-20, 0, 0)
	rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	rim.light_specular = 1.0
	root.add_child(rim)

	if c["name"] == "ICELAND":
		_aurora()


## Per-channel colour curve: lifts the shadows toward `shadow` (split toning)
## and adds a gentle S-curve.
func _grade(shadow: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(shadow.r, shadow.g, shadow.b),
		Color(0.22 + shadow.r, 0.22 + shadow.g, 0.22 + shadow.b),
		Color(0.77, 0.77, 0.76),
		Color(1, 1, 1)])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


func _radial_tex(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([inner, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


# --- ground: boulevard, sidewalks, side streets -----------------------------

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

	var mid := length * 0.5
	var span := length + 600.0
	var wet: float = look.get("wet", 0.0)
	var snow: float = look.get("snow", 0.0)

	var land := ShaderMaterial.new()
	land.shader = preload("res://shaders/pavement.gdshader")
	land.set_shader_parameter("stone", Color(c["ground"]).lerp(Color(0.32, 0.32, 0.33), 0.5))
	land.set_shader_parameter("tile", 2.5)
	land.set_shader_parameter("snow", snow)
	land.set_shader_parameter("wet", wet)
	_plane(Vector2(span, 400), land, Vector3(mid, -0.01, -60))

	var road := _road_mat(false, ROAD_Z, ROAD_HALF, 3)
	_plane(Vector2(span, ROAD_HALF * 2.0), road, Vector3(mid, 0.01, ROAD_Z))

	var pave := ShaderMaterial.new()
	pave.shader = preload("res://shaders/pavement.gdshader")
	pave.set_shader_parameter("stone", Color(0.5, 0.49, 0.47) if not night else Color(0.4, 0.4, 0.42))
	pave.set_shader_parameter("tile", 0.55)
	pave.set_shader_parameter("snow", snow)
	pave.set_shader_parameter("wet", wet)
	var curb := _mat(Color(0.55, 0.54, 0.52), 0.8)
	# Back sidewalk (in front of the destructible row) and its curb.
	_box(Vector3(span, 0.18, 1.2), pave, Vector3(mid, 0.09, -7.1))
	_box(Vector3(span, 0.2, 0.18), curb, Vector3(mid, 0.1, ROAD_Z - ROAD_HALF - 0.09))
	# Front sidewalk + plaza, curb.
	_box(Vector3(span, 0.18, 8.0), pave, Vector3(mid, 0.09, FRONT_CURB + 4.0))
	_box(Vector3(span, 0.2, 0.18), curb, Vector3(mid, 0.1, ROAD_Z + ROAD_HALF + 0.09))
	# Granite band and low wall along the plaza.
	_box(Vector3(span, 0.2, 0.5), _mat(Color(0.3, 0.3, 0.32), 0.6), Vector3(mid, 0.1, 6.6))

	# Side streets running back into the city.
	var side := _road_mat(true, 0.0, CROSS_HALF, 1)
	var side_pave := pave
	for cx in crossings:
		var sm := side.duplicate() as ShaderMaterial
		sm.set_shader_parameter("center", cx)
		_plane(Vector2(CROSS_HALF * 2.0, 70.0), sm, Vector3(cx, 0.012, ROAD_Z - ROAD_HALF - 35.0))
		for s in [-1.0, 1.0]:
			_box(Vector3(1.0, 0.18, 70.0), side_pave, Vector3(cx + s * (CROSS_HALF + 0.5), 0.09, ROAD_Z - ROAD_HALF - 35.5))
	var cr := PackedFloat32Array()
	for cx in crossings:
		if cr.size() < 16:
			cr.append(cx)
	road.set_shader_parameter("crossings", cr)
	road.set_shader_parameter("crossing_count", cr.size())


func _road_mat(along_z: bool, center: float, half: float, lanes: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/road.gdshader")
	m.set_shader_parameter("along_z", along_z)
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("half_width", half)
	m.set_shader_parameter("lanes", lanes)
	m.set_shader_parameter("wet", look.get("wet", 0.0))
	m.set_shader_parameter("snow", look.get("snow", 0.0))
	m.set_shader_parameter("asphalt", Color(0.11, 0.11, 0.12) if not night else Color(0.08, 0.08, 0.09))
	return m


# --- street furniture --------------------------------------------------------

func _street_props() -> void:
	var lamp_col: Color = Color(1.0, 0.82, 0.55) if c["name"] != "JAPAN" else Color(0.85, 0.9, 1.0)
	var pole_mat := _mat(Color(0.14, 0.15, 0.16), 0.45, 0.6)
	var head_mat := _glow(lamp_col, 4.0 if night else 0.6)
	var poles: Array = []
	var arms: Array = []
	var heads: Array = []
	var pools: Array = []
	var x := -40.0
	while x < length + 60.0:
		if not _near_crossing(x - 1.0, x + 1.0, 1.0):
			poles.append(Transform3D(Basis.from_scale(Vector3(1, 3.4, 1)), Vector3(x, 1.7, -7.25)))
			arms.append(Transform3D(Basis.from_scale(Vector3(0.08, 0.08, 1.3)), Vector3(x, 3.35, -6.65)))
			heads.append(Transform3D(Basis.from_scale(Vector3(0.3, 0.1, 0.45)), Vector3(x, 3.3, -6.05)))
			pools.append(Transform3D(Basis.from_scale(Vector3(5.5, 1, 4.5)), Vector3(x, 0.035, -5.4)))
		x += 9.0
	_multi(_cyl(0.05, 0.07, 6), pole_mat, poles)
	_multi(_unit_box(), pole_mat, arms, [], false)
	_multi(_unit_box(), head_mat, heads, [], false)
	if night or look.get("wet", 0.0) > 0.0:
		var pool_mat := StandardMaterial3D.new()
		pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pool_mat.albedo_texture = _radial_tex(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
		pool_mat.albedo_color = Color(lamp_col.r, lamp_col.g, lamp_col.b, 0.35 if night else 0.08)
		pool_mat.disable_receive_shadows = true
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		_multi(pm, pool_mat, pools, [], false)

	# Low bollard lights, planters with shrubs, benches and the plaza railing.
	var bollards: Array = []
	var caps: Array = []
	var planters: Array = []
	var shrubs: Array = []
	var shrub_cols: Array = []
	var benches: Array = []
	var trunks: Array = []
	var crowns: Array = []
	var crown_cols: Array = []
	var tree: Color = look.get("tree", Color(0.2, 0.35, 0.18))
	var snow: float = look.get("snow", 0.0)
	x = -40.0
	while x < length + 60.0:
		bollards.append(Transform3D(Basis.from_scale(Vector3(1, 0.55, 1)), Vector3(x, 0.45, FRONT_CURB + 0.45)))
		caps.append(Transform3D(Basis.from_scale(Vector3(0.14, 0.06, 0.14)), Vector3(x, 0.75, FRONT_CURB + 0.45)))
		x += 4.5
	x = -36.0
	while x < length + 60.0:
		var kind := rng.randi() % 3
		var px := x + rng.randf_range(-1.0, 1.0)
		if kind == 0:
			planters.append(Transform3D(Basis.from_scale(Vector3(2.2, 0.45, 0.9)), Vector3(px, 0.4, 7.6)))
			for i in 3:
				shrubs.append(Transform3D(Basis.from_scale(Vector3(0.8, 0.55, 0.7) * rng.randf_range(0.8, 1.1)), Vector3(px - 0.65 + i * 0.65, 0.75, 7.6)))
				shrub_cols.append(tree.lightened(rng.randf_range(0.0, 0.15)).lerp(Color(0.9, 0.92, 0.95), snow * 0.6))
		elif kind == 1:
			benches.append(Transform3D(Basis.from_scale(Vector3(1.4, 0.1, 0.4)), Vector3(px, 0.45, 7.2)))
			benches.append(Transform3D(Basis.from_scale(Vector3(1.4, 0.35, 0.08)), Vector3(px, 0.65, 7.42)))
		else:
			trunks.append(Transform3D(Basis.from_scale(Vector3(1, 1.1, 1)), Vector3(px, 0.73, 8.4)))
			var s := rng.randf_range(0.8, 1.0)
			for k in 4:
				var off := Vector3(rng.randf_range(-0.35, 0.35), 1.25 + k * 0.12 + rng.randf() * 0.15, rng.randf_range(-0.3, 0.3))
				if k == 3:
					off = Vector3(0, 1.65, 0)
				crowns.append(Transform3D(Basis.from_scale(Vector3(0.75, 0.65, 0.75) * s * rng.randf_range(0.8, 1.1)), Vector3(px, 0, 8.4) + off))
				crown_cols.append(tree.lightened(rng.randf_range(-0.08, 0.15) + k * 0.03).lerp(Color(0.9, 0.92, 0.95), snow * (0.3 + k * 0.12)))
		x += rng.randf_range(5.0, 8.0)
	var metal := _mat(Color(0.2, 0.21, 0.22), 0.4, 0.7)
	_multi(_cyl(0.07, 0.08, 6), metal, bollards)
	_multi(_unit_box(), _glow(lamp_col, 3.0 if night else 0.3), caps, [], false)
	_multi(_unit_box(), _mat(Color(0.45, 0.43, 0.4), 0.9), planters)
	_multi(_sphere_mesh(), _vc_mat(0.9), shrubs, shrub_cols)
	var wood := _mat(Color(0.4, 0.28, 0.18), 0.8)
	_multi(_unit_box(), wood, benches)
	_multi(_cyl(0.06, 0.1, 6), _mat(Color(0.25, 0.18, 0.12), 0.9), trunks)
	_multi(_sphere_mesh(), _vc_mat(0.9), crowns, crown_cols)
	# Railing along the edge of the plaza.
	var posts: Array = []
	x = -60.0
	while x < length + 80.0:
		posts.append(Transform3D(Basis.from_scale(Vector3(0.08, 0.7, 0.08)), Vector3(x, 0.55, 6.6)))
		x += 2.0
	_multi(_unit_box(), metal, posts)
	_box(Vector3(length + 140.0, 0.06, 0.08), metal, Vector3(length * 0.5 + 10.0, 0.9, 6.6))

	# Traffic lights and pedestrian signals at every side street (back corners only).
	var red := _glow(Color(1.0, 0.15, 0.1), 5.0)
	var amber := _glow(Color(1.0, 0.6, 0.1), 0.4)
	var green := _glow(Color(0.2, 1.0, 0.45), 0.4)
	var black := _mat(Color(0.08, 0.08, 0.09), 0.5)
	for cx in crossings:
		for s in [-1.0, 1.0]:
			var px: float = cx + s * (CROSS_HALF + 0.6)
			_mesh_s(_cyl(0.06, 0.08, 6), metal, Vector3(px, 1.6, -6.8), Vector3(1, 3.2, 1))
			_mesh_s(_unit_box(), metal, Vector3(px, 3.1, -5.6), Vector3(0.08, 0.08, 2.4))
			_mesh_s(_unit_box(), black, Vector3(px, 2.75, -4.5), Vector3(0.3, 0.8, 0.25))
			for i in 3:
				var m: Material = [red, amber, green][i]
				_mesh_s(_unit_box(), m, Vector3(px, 3.0 - i * 0.25, -4.37), Vector3(0.15, 0.15, 0.04))
		if night:
			var l := OmniLight3D.new()
			var palette: Array = look.get("neon_colors", [Color(1.0, 0.75, 0.45), Color(0.6, 0.8, 1.0)])
			l.light_color = palette[rng.randi() % palette.size()]
			l.light_energy = 2.0
			l.omni_range = 10.0
			l.position = Vector3(cx, 3.5, -7.5)
			root.add_child(l)


# --- traffic ---------------------------------------------------------------

func _cars() -> void:
	var bodies: Array = []
	var cabins: Array = []
	var colors: Array = []
	var front_l: Array = []
	var back_l: Array = []
	var palette := [Color(0.7, 0.1, 0.08), Color(0.9, 0.9, 0.88), Color(0.1, 0.12, 0.15), Color(0.2, 0.3, 0.55),
		Color(0.55, 0.57, 0.6), Color(0.95, 0.75, 0.1), Color(0.15, 0.35, 0.25), Color(0.4, 0.42, 0.45)]
	var place := func(pos: Vector3, yaw: float, wreck: bool) -> void:
		var b := Basis(Vector3.UP, yaw)
		var big := rng.randf() < 0.15
		var L := 2.1 if big else 1.35
		var tf := Transform3D(b, pos)
		bodies.append(tf * Transform3D(Basis.from_scale(Vector3(L, 0.36 if not big else 0.6, 0.6)), Vector3(0, 0.3 if not big else 0.42, 0)))
		cabins.append(tf * Transform3D(Basis.from_scale(Vector3(L * (0.52 if not big else 0.3), 0.26, 0.54)), Vector3(-L * 0.06 if not big else L * 0.32, 0.6 if not big else 0.84, 0)))
		var col: Color = palette[rng.randi() % palette.size()]
		if wreck:
			col = col.darkened(0.6)
		colors.append(col)
		if not wreck:
			front_l.append(tf * Transform3D(Basis.from_scale(Vector3(0.04, 0.08, 0.5)), Vector3(L * 0.5, 0.36, 0)))
			back_l.append(tf * Transform3D(Basis.from_scale(Vector3(0.04, 0.08, 0.5)), Vector3(-L * 0.5, 0.36, 0)))
	# Parked along both curbs.
	var x := -40.0
	while x < length + 60.0:
		if not _near_crossing(x - 1.5, x + 1.5, 1.0) and rng.randf() < 0.7:
			place.call(Vector3(x, 0, ROAD_Z - ROAD_HALF + 0.75), PI if rng.randf() < 0.1 else 0.0, false)
		if rng.randf() < 0.55:
			place.call(Vector3(x + 0.8, 0, ROAD_Z + ROAD_HALF - 0.75), PI, false)
		x += rng.randf_range(1.9, 3.2)
	# Abandoned in the street, skewed as if dropped in a hurry.
	x = 0.0
	while x < length + 40.0:
		x += rng.randf_range(8.0, 22.0)
		place.call(Vector3(x, 0, ROAD_Z + rng.randf_range(-3.5, 3.5)), rng.randf() * TAU, rng.randf() < 0.3)
	# Side-street traffic jams.
	for cx in crossings:
		var z := -9.0
		while z > -60.0:
			if rng.randf() < 0.6:
				place.call(Vector3(cx + (0.9 if rng.randf() < 0.5 else -0.9), 0, z), PI / 2.0 if rng.randf() < 0.5 else -PI / 2.0, false)
			z -= rng.randf_range(1.8, 3.0)
	_multi(_unit_box(), _vc_mat(0.25, 0.4), bodies, colors)
	_multi(_unit_box(), _mat(Color(0.14, 0.17, 0.22), 0.08, 0.6), cabins, [], false)
	_multi(_unit_box(), _glow(Color(1.0, 0.95, 0.8), 3.5 if night else 0.3), front_l, [], false)
	_multi(_unit_box(), _glow(Color(1.0, 0.1, 0.05), 3.0 if night else 0.5), back_l, [], false)


# --- buildings ---------------------------------------------------------------

## The destructible front row, broken by side streets.
func _city() -> void:
	var h: Vector2 = c["height"]
	var x := -20.0
	while x < length + 30.0:
		var w := rng.randf_range(5.5, 9.5)
		if _near_crossing(x, x + w, 0.6):
			x += 1.5
			continue
		var d := rng.randf_range(6.0, 9.0)
		var b := Building.new()
		b.size = Vector3(w, rng.randf_range(h.x, h.y), d)
		b.position = Vector3(x + w * 0.5, 0, -7.7 - d * 0.5)
		root.add_child(b)
		x += w + rng.randf_range(0.4, 1.6)


func _skyline() -> void:
	var lit: float = c["lit"]
	var emis: float = c["emission"]
	var h: Vector2 = c["height"]
	var mul: float = look.get("skyline", 1.0)

	# Row A: detailed static towers right behind the destructible row.
	var mats: Array[ShaderMaterial] = []
	for i in 8:
		mats.append(Building.make_material(rng.randf() * 10.0, lit, emis))
	var x := -60.0
	while x < length + 90.0:
		var w := rng.randf_range(6.0, 11.0)
		var zf := -18.5 - rng.randf() * 3.0
		if _near_crossing(x, x + w, 0.6) or _blocks_landmark(x, x + w, zf):
			x += 1.5
			continue
		var d := rng.randf_range(7.0, 12.0)
		var bh := rng.randf_range(h.x * 1.3, h.y * 1.8) * mul
		var n := Node3D.new()
		n.position = Vector3(x + w * 0.5, 0, zf - d * 0.5)
		root.add_child(n)
		var sz := Vector3(w, bh, d)
		Building.build_tower(n, sz, mats[rng.randi() % mats.size()], rng.randi(), true)
		Building.add_facade_signs(n, sz, rng.randi())
		x += w + rng.randf_range(0.3, 1.5)

	# Rows B and C: MultiMesh blocks, each tier one instance.
	_far_row(-42.0, 14.0, Vector2(h.x * 1.8, h.y * 2.6) * mul, lit * 0.9, emis * 0.9, true)
	_far_row(-85.0, 30.0, Vector2(h.x * 2.4, h.y * 3.4) * mul, lit * 0.8, emis * 0.8, false)


func _far_row(z_front: float, z_jitter: float, hr: Vector2, lit: float, emis: float, side_gaps: bool) -> void:
	var mats: Array[ShaderMaterial] = []
	var by_mat: Array = []
	for i in 4:
		var m := Building.make_material(rng.randf() * 10.0, lit, emis, i)
		m.set_shader_parameter("use_custom", true)
		m.set_shader_parameter("shop_band", side_gaps)
		mats.append(m)
		by_mat.append({"xf": [], "col": [], "cus": []})
	var roofs: Array = []
	var spires: Array = []
	var beacons: Array = []
	var roof_cols: Array = []
	var roof_palette: Array = look.get("roof_colors", [Color(0.3, 0.3, 0.32)])
	var pitched := false
	for r in look.get("roofs", []):
		if r in ["gable", "hip", "mansard"]:
			pitched = true
	var x := -160.0
	while x < length + 200.0:
		var w := rng.randf_range(8.0, 16.0)
		var zf := z_front - rng.randf() * z_jitter
		if (side_gaps and _near_crossing(x, x + w, 0.5)) or _blocks_landmark(x, x + w, zf):
			x += 2.0
			continue
		var d := rng.randf_range(8.0, 14.0)
		var bh := rng.randf_range(hr.x, hr.y)
		var mi := rng.randi() % 4
		var tint := Color(1, 1, 1).darkened(rng.randf() * 0.25)
		var seedv := rng.randf()
		var foot := Vector2(w, d)
		var y := 0.0
		var tiers := 1 if bh < 20.0 else rng.randi_range(1, 3)
		for t in tiers:
			var th := bh - y if t == tiers - 1 else (bh - y) * rng.randf_range(0.55, 0.75)
			var tf := Transform3D(Basis.from_scale(Vector3(foot.x, th, foot.y)), Vector3(x + w * 0.5, y + th * 0.5, zf - d * 0.5))
			by_mat[mi]["xf"].append(tf)
			by_mat[mi]["col"].append(tint)
			by_mat[mi]["cus"].append(Color(seedv + t, 0, 0, 0))
			y += th
			if t < tiers - 1:
				foot *= rng.randf_range(0.68, 0.82)
		var top := Vector3(x + w * 0.5, y, zf - d * 0.5)
		if pitched and bh < 22.0 and rng.randf() < 0.6:
			roofs.append(Transform3D(Basis.from_scale(Vector3(foot.x + 0.3, minf(foot.y * 0.4, 3.5), foot.y + 0.3)), top))
			roof_cols.append(roof_palette[rng.randi() % roof_palette.size()])
		elif bh > 24.0 and rng.randf() < 0.35:
			spires.append(Transform3D(Basis.from_scale(Vector3(foot.x * 0.5, rng.randf_range(4.0, 12.0), foot.y * 0.5)), top))
		elif bh > 16.0 and rng.randf() < 0.5:
			beacons.append(Transform3D(Basis.from_scale(Vector3(0.35, 0.35, 0.35)), top + Vector3(rng.randf_range(-0.3, 0.3) * foot.x, 0.3, 0)))
		x += w + rng.randf_range(0.5, 3.0)
	for i in 4:
		_multi(_unit_box(), mats[i], by_mat[i]["xf"], by_mat[i]["col"], side_gaps, by_mat[i]["cus"])
	if not roofs.is_empty():
		var rm := _vc_mat(0.7)
		_multi(Building.frustum_mesh(1.0, 0.0), rm, roofs, roof_cols.map(func(col: Color) -> Color:
			return col.lerp(Color(0.92, 0.94, 1.0), float(look.get("snow", 0.0)) * 0.7)), false)
	if not spires.is_empty():
		_multi(Building.frustum_mesh(0.0, 0.0), _mat(Color(0.55, 0.56, 0.6), 0.35, 0.6), spires, [], false)
	if not beacons.is_empty():
		_multi(_unit_box(), _glow(Color(1, 0.1, 0.05), 4.0), beacons, [], false)


# --- life in the sky -------------------------------------------------------

## News helicopters hovering over the boulevard (with searchlights at night)
## and, at night, searchlight beams sweeping the clouds.
func _sky_life() -> void:
	var body_mat := _mat(Color(0.18, 0.2, 0.24) if night else Color(0.85, 0.85, 0.82), 0.4, 0.4)
	var dark := _mat(Color(0.08, 0.08, 0.1), 0.5)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.disable_receive_shadows = true
	beam_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.05)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	beam_mat.albedo_texture = gt
	var x := 30.0
	while x < length + 40.0:
		var heli := Node3D.new()
		heli.position = Vector3(x, rng.randf_range(9.5, 11.0), rng.randf_range(-8.0, -5.0))
		root.add_child(heli)
		var hull := MeshInstance3D.new()
		hull.mesh = _sphere_mesh()
		hull.material_override = body_mat
		hull.scale = Vector3(1.0, 0.55, 0.55)
		heli.add_child(hull)
		var boom := MeshInstance3D.new()
		boom.mesh = _unit_box()
		boom.material_override = body_mat
		boom.scale = Vector3(1.1, 0.1, 0.1)
		boom.position = Vector3(-0.9, 0.08, 0)
		heli.add_child(boom)
		var fin := MeshInstance3D.new()
		fin.mesh = _unit_box()
		fin.material_override = body_mat
		fin.scale = Vector3(0.2, 0.35, 0.04)
		fin.position = Vector3(-1.4, 0.2, 0)
		heli.add_child(fin)
		var rotor := MeshInstance3D.new()
		rotor.mesh = _unit_box()
		rotor.material_override = dark
		rotor.scale = Vector3(2.4, 0.02, 0.1)
		rotor.position = Vector3(0, 0.34, 0)
		heli.add_child(rotor)
		var rt := rotor.create_tween().set_loops()
		rt.tween_property(rotor, "rotation:y", TAU, 0.15).from(0.0)
		var lamp := MeshInstance3D.new()
		lamp.mesh = _unit_box()
		lamp.material_override = _glow(Color(1, 0.15, 0.1), 5.0)
		lamp.scale = Vector3.ONE * 0.08
		lamp.position = Vector3(-1.45, 0.4, 0)
		heli.add_child(lamp)
		if night:
			var beam := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.06
			cone.bottom_radius = 1.3
			cone.height = 10.0
			cone.radial_segments = 12
			cone.rings = 1
			cone.cap_top = false
			cone.cap_bottom = false
			beam.mesh = cone
			beam.material_override = beam_mat
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.position = Vector3(0.9, -4.9, 0.6)
			beam.rotation = Vector3(0.12, 0, 0.18)
			heli.add_child(beam)
			var spot := SpotLight3D.new()
			spot.light_color = Color(0.9, 0.95, 1.0)
			spot.light_energy = 6.0
			spot.spot_range = 16.0
			spot.spot_angle = 12.0
			spot.position = Vector3(0.3, -0.3, 0)
			spot.rotation = Vector3(-PI / 2.0 + 0.12, 0, 0.18)
			heli.add_child(spot)
		# Slow hover drift.
		var base := heli.position
		var tw := heli.create_tween().set_loops()
		var dx := rng.randf_range(4.0, 8.0)
		tw.tween_property(heli, "position", base + Vector3(dx, 0.6, 0.5), rng.randf_range(5.0, 7.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(heli, "position", base, rng.randf_range(5.0, 7.0)).set_trans(Tween.TRANS_SINE)
		heli.rotation.z = -0.08
		x += rng.randf_range(70.0, 110.0)

	if not night:
		return
	# Searchlights from the city behind, sweeping slowly.
	var sweep_mat := beam_mat.duplicate() as StandardMaterial3D
	sweep_mat.albedo_color = Color(0.85, 0.9, 1.0, 0.07)
	var x2 := -20.0
	while x2 < length + 60.0:
		var pivot := Node3D.new()
		pivot.position = Vector3(x2, 0, -60.0 - rng.randf() * 30.0)
		root.add_child(pivot)
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 6.0
		cone.bottom_radius = 0.4
		cone.height = 160.0
		cone.radial_segments = 10
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		beam.mesh = cone
		beam.material_override = sweep_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = Vector3(0, 80.0, 0)
		pivot.add_child(beam)
		pivot.rotation.z = rng.randf_range(-0.5, 0.5)
		var tw := pivot.create_tween().set_loops()
		var t := rng.randf_range(6.0, 10.0)
		tw.tween_property(pivot, "rotation:z", 0.5, t).set_trans(Tween.TRANS_SINE)
		tw.tween_property(pivot, "rotation:z", -0.5, t).set_trans(Tween.TRANS_SINE)
		x2 += rng.randf_range(50.0, 80.0)


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

var _meshes := {}


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


func _mesh_s(mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := _mesh(mesh, mat, pos)
	mi.scale = scl
	return mi


func _unit_box() -> Mesh:
	if not _meshes.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["box"] = b
	return _meshes["box"]


func _sphere_mesh() -> Mesh:
	if not _meshes.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 6
		_meshes["sphere"] = s
	return _meshes["sphere"]


## Unit-height cylinder (scale Y for the height).
func _cyl(top: float, bottom: float, sides: int) -> Mesh:
	var key := "cyl_%.2f_%.2f_%d" % [top, bottom, sides]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = 1.0
		m.radial_segments = sides
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


## Material that takes its albedo from MultiMesh instance colours.
func _vc_mat(rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic = metal
	return m


func _multi(mesh: Mesh, mat: Material, xforms: Array, colors: Array = [], shadows: bool = true,
		customs: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not customs.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, customs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mmi
