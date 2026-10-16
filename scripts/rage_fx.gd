class_name RageFX
extends RefCounted
## How every hero's rage attacks look (see RageStyle): the breath jet and
## what it does along its length each tick, the shots' trails and impacts,
## and the marks they leave on the street. Built on FX's particle helpers.

## Breath jet shape per kind: particle speed, cone spread, flame size,
## lifetime (speed * life is roughly how far it reaches) and gravity.
const JET := {
	"flame": {"speed": 32.0, "spread": 8.0, "size": 3.4, "life": 0.42, "grav": 3.0},
	"beam": {"speed": 42.0, "spread": 3.0, "size": 1.8, "life": 0.3, "grav": 0.0},
	"lightning": {"speed": 40.0, "spread": 9.0, "size": 1.3, "life": 0.3, "grav": 0.0},
	"spikes": {"speed": 26.0, "spread": 14.0, "size": 2.2, "life": 0.45, "grav": -8.0},
	"mist": {"speed": 17.0, "spread": 17.0, "size": 4.4, "life": 0.85, "grav": 1.0},
	"frost": {"speed": 29.0, "spread": 9.0, "size": 3.0, "life": 0.45, "grav": -1.5},
	"shadow": {"speed": 27.0, "spread": 9.0, "size": 3.2, "life": 0.5, "grav": 2.0},
	"water": {"speed": 42.0, "spread": 3.5, "size": 2.0, "life": 0.32, "grav": -9.0},
	"sparks": {"speed": 38.0, "spread": 2.5, "size": 1.0, "life": 0.3, "grav": 0.0},
}
const BEAM_LEN := 13.0

static var _cache := {}


## The style's breath/trail colours as a gradient (cached per style).
static func ramp(st: Dictionary) -> GradientTexture1D:
	var k := "ramp_" + String(st["mode"])
	if not _cache.has(k):
		_cache[k] = FX._ramp(st["ramp"])
	return _cache[k]


## Hot inner colours: a pale, bright version of the glow fading out. Kept
## below white so a bright day doesn't wash it out.
static func core_ramp(st: Dictionary) -> GradientTexture1D:
	var k := "core_" + String(st["mode"])
	if not _cache.has(k):
		var c: Color = st["glow"]
		_cache[k] = FX._ramp([Color(c.lightened(0.55), 1.0), Color(c.lightened(0.2), 0.85), Color(c, 0.0)])
	return _cache[k]


static func _soft(add: bool) -> QuadMesh:
	return FX._billboard("rg_add" if add else "flame", 1.0, add, Color.WHITE)


## A small glowing spark in the style's ember colour.
static func spark_mesh(c: Color, size := 1.0) -> Mesh:
	var k := "spark_%s_%.2f" % [c.to_html(), size]
	if not _cache.has(k):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = c * 3.0
		var b := BoxMesh.new()
		b.size = Vector3(0.08, 0.7, 0.08) * size
		b.material = mat
		_cache[k] = b
	return _cache[k]


## Unshaded glowing material (`add` for additive light).
static func glow_mat(c: Color, add := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0 or add:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = c
	return mat


static func _mesh(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# --- breath ------------------------------------------------------------------

## The hero's heavy rage breath: a cone of its element pouring from the
## mouth, with an inner core, embers and (per kind) smoke or a solid beam.
## Moved each frame with jet_update and stopped with FX.stop_stream.
static func jet(st: Dictionary, dir: Vector3) -> GPUParticles3D:
	var w := FX._world()
	if w == null:
		return null
	var kind: String = st["jet"]
	var j: Dictionary = JET[kind]
	var speed: float = j["speed"]
	var size: float = j["size"]
	var life: float = j["life"]
	var aabb := AABB(Vector3(-30, -10, -30), Vector3(60, 40, 60))
	var pm := FX._pm(dir, j["spread"], speed * 0.8, speed, j["grav"], size * 0.6, size * 1.2, 1.2, 0.2 * size)
	pm.color_ramp = ramp(st)
	pm.scale_curve = FX._grow_curve()
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	# Blended, not additive: stacked particles keep their colour instead of
	# turning white.
	var p := FX._stream_part(140 if kind == "mist" else 220, life, pm, _soft(false), aabb)
	w.add_child(p)
	# Thin, hot inner jet: brightest at the mouth.
	var cm := FX._pm(dir, j["spread"] * 0.4, speed * 0.9, speed * 1.05, 0.0, size * 0.3, size * 0.5, 1.0, 0.1 * size)
	cm.color_ramp = core_ramp(st)
	cm.scale_curve = FX._grow_curve()
	p.add_child(FX._stream_part(60, life * 0.5, cm, _soft(false), aabb))
	var smoke: Color = st["smoke"]
	if smoke.a > 0.0:
		var sm := FX._pm(dir, j["spread"] * 1.6, speed * 0.55, speed * 0.75, 4.0, size * 1.0, size * 1.7, 1.6, 0.4 * size)
		sm.color_ramp = FX._ramp([Color(smoke, 0.0), Color(smoke, 0.0), Color(smoke, smoke.a), Color(smoke.lightened(0.2), 0.0)])
		sm.scale_curve = FX._grow_curve()
		p.add_child(FX._stream_part(60, life * 2.4, sm, FX._billboard("smoke", 1.0, false, Color.WHITE), aabb))
	# Embers / sparks / droplets thrown out of the stream.
	var e_grav := -12.0
	var e_spread: float = j["spread"] * 2.0
	var e_amount := 60
	match kind:
		"water":
			e_grav = -26.0
		"sparks":
			e_grav = -30.0
			e_spread = 26.0
			e_amount = 170
		"lightning", "beam":
			e_grav = 0.0
	var em := FX._pm(dir, e_spread, speed * 0.6, speed * 1.2, e_grav, 0.3, 0.7, 0.5, 0.4 * size)
	em.particle_flag_align_y = true
	em.scale_curve = FX._shrink_curve()
	p.add_child(FX._stream_part(e_amount, life * 1.5, em, spark_mesh(st["spark"]), aabb))
	if kind == "beam":
		p.add_child(_beam_mesh(st, dir))
	var l := OmniLight3D.new()
	l.name = "light"
	l.light_color = st["glow"]
	l.omni_range = 15.0
	l.light_energy = 6.0
	p.add_child(l)
	return p


## A solid ray along the breath (GORRAX, SOLAR REX): white-hot core in a
## coloured glow, a ball of light at the mouth.
static func _beam_mesh(st: Dictionary, dir: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "beam"
	root.rotation.z = atan2(-dir.x, dir.y)
	var wide := 1.35 if st["shot"] == "sun" else 1.0
	var c: Color = st["core"]
	var g: Color = st["glow"]
	for layer in [[0.24 * wide, 0.3 * wide, Color(c, 1.0), false], [0.6 * wide, 0.85 * wide, Color(g.lightened(0.25), 0.6), false],
			[1.1 * wide, 1.5 * wide, Color(g, 0.25), false]]:
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = layer[0]
		cyl.top_radius = layer[1]
		cyl.height = BEAM_LEN
		cyl.radial_segments = 16
		cyl.rings = 1
		var mi := _mesh(root, cyl, glow_mat(layer[2], layer[3]))
		mi.position.y = BEAM_LEN * 0.5
	var sph := SphereMesh.new()
	sph.radius = 1.0 * wide
	sph.height = 2.0 * wide
	_mesh(root, sph, glow_mat(Color(g.lightened(0.3), 0.6)))
	return root


## Keeps the breath at the mouth and makes it flicker.
static func jet_update(p: GPUParticles3D, st: Dictionary, mouth: Vector3, facing: float, t: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.global_position = mouth
	var f := 1.0 + sin(t * 53.0) * 0.15 + sin(t * 31.0) * 0.1
	var l := p.get_node_or_null("light") as OmniLight3D
	if l:
		l.position = Vector3(facing * BEAM_LEN * 0.45, -1.0, 0)
		l.light_energy = 6.0 * f
	var b := p.get_node_or_null("beam") as Node3D
	if b:
		b.scale = Vector3(f, 1.0, f)


## What the breath does along its length every tick, on top of the cone:
## lightning forks, spikes out of the street, lingering gas, frost, splashes,
## sparks and life drained back to the hero. `hit` are the enemies it touched.
static func jet_tick(st: Dictionary, mouth: Vector3, facing: float, length: float, tick: int, hit: Array) -> void:
	var z := mouth.z
	match String(st["jet"]):
		"flame":
			if tick % 3 == 0:
				var end := Vector3(mouth.x + facing * length * randf_range(0.55, 0.9), 0.6, z + randf_range(-0.8, 0.8))
				ground(end, st, 1.0, 1.4)
		"beam":
			if tick % 2 == 0:
				if st["shot"] == "sun":
					_flare(mouth + Vector3(facing * 0.5, 0, 0.3), st, 1.4)
				else:
					_ring(mouth + Vector3(facing * 1.5, -0.3, 0), facing, st)
			if tick % 4 == 0:
				ground(Vector3(mouth.x + facing * length * randf_range(0.6, 0.95), 0.1, z), st, 0.9, 1.2)
		"lightning":
			var tip := mouth + Vector3(facing * length * randf_range(0.6, 1.0), randf_range(-3.5, 0.5), randf_range(-1.5, 1.5))
			bolt(mouth, tip, st)
			for t in hit.slice(0, 3):
				bolt(mouth, t.hit_center(), st)
			if tick % 3 == 0:
				ground(Vector3(tip.x, 0.1, z), st, 0.8, 1.0)
		"spikes":
			# Crystal spikes burst out of the street one after another, away
			# from the hero, and start over at the mouth.
			var x := mouth.x + facing * (2.5 + (tick % 5) * (length - 2.5) / 4.0)
			spike(Vector3(x, 0.0, z + randf_range(-0.8, 0.8)), st, randf_range(0.9, 1.3))
		"mist":
			if tick % 3 == 0:
				cloud(Vector3(mouth.x + facing * length * randf_range(0.4, 0.9), 1.8, z + randf_range(-1.0, 1.0)), st, 1.0)
		"frost":
			if tick % 2 == 0:
				ice(Vector3(mouth.x + facing * length * randf_range(0.35, 0.95), 0.0, z + randf_range(-1.0, 1.0)), st, randf_range(0.7, 1.1))
		"shadow":
			# Life wisps flow out of everything it touches back into the mouth.
			for t in hit.slice(0, 4):
				var from: Vector3 = t.hit_center()
				var pm := FX._pm((mouth - from).normalized(), 12.0, 14.0, 22.0, 0.0, 0.5, 1.0, 0.0, 0.6)
				pm.color_ramp = FX._ramp([Color(st["core"], 1.0), Color(st["glow"], 0.8), Color(st["glow"], 0.0)])
				pm.scale_curve = FX._shrink_curve()
				FX._emit(from, 6, 0.55, _soft(true), pm)
			if tick % 3 == 0:
				ground(Vector3(mouth.x + facing * length * randf_range(0.5, 0.9), 0.1, z), st, 1.0, 1.4)
		"water":
			if tick % 2 == 0:
				splash(Vector3(mouth.x + facing * length * randf_range(0.75, 1.0), 0.5, z), st, 1.0)
			if tick % 4 == 1:
				ground(Vector3(mouth.x + facing * length * randf_range(0.4, 0.9), 0.1, z), st, 1.0, 1.6)
		"sparks":
			var end := Vector3(mouth.x + facing * length * randf_range(0.7, 1.0), randf_range(1.0, 3.0), z)
			var pm := FX._pm(Vector3(-facing, 0.6, 0), 70.0, 10.0, 22.0, -30.0, 0.4, 0.9, 0.4, 0.4)
			pm.particle_flag_align_y = true
			pm.scale_curve = FX._shrink_curve()
			FX._emit(end, 14, 0.7, spark_mesh(st["spark"]), pm)
			for t in hit.slice(0, 2):
				FX._emit(t.hit_center(), 10, 0.6, spark_mesh(st["spark"]), pm)
			if tick % 4 == 0:
				ground(Vector3(end.x, 0.1, z), st, 0.8, 1.6)


## A forked lightning bolt from `a` to `b`: a bright core in a coloured
## sleeve, with a short branch, that flickers out.
static func bolt(a: Vector3, b: Vector3, st: Dictionary, width := 1.0) -> void:
	var w := FX._world()
	if w == null:
		return
	var core := glow_mat(Color(1.0, 1.0, 0.95, 1.0))
	var sleeve := glow_mat(Color(st["glow"], 0.45))
	var root := Node3D.new()
	w.add_child(root)
	var pts := [a]
	var segs := 8
	for i in segs:
		var p := a.lerp(b, float(i + 1) / segs)
		if i < segs - 1:
			p += Vector3(randf_range(-0.9, 0.9), randf_range(-0.9, 0.9), randf_range(-0.4, 0.4)) * width
		pts.append(p)
	var branch_at: int = randi_range(2, 5)
	var tip: Vector3 = pts[branch_at] + (b - a).normalized() * 3.0 + Vector3(0, randf_range(-2.5, 2.5), randf_range(-1.0, 1.0))
	var lines := []
	for i in segs:
		lines.append([pts[i], pts[i + 1], 1.0])
	lines.append([pts[branch_at], tip, 0.6])
	for l in lines:
		for layer in [[0.12, core], [0.4, sleeve]]:
			var len: float = l[0].distance_to(l[1])
			if len < 0.01:
				continue
			var box := BoxMesh.new()
			box.size = Vector3(layer[0] * l[2] * width, layer[0] * l[2] * width, len)
			var mi := _mesh(root, box, layer[1])
			mi.global_position = (l[0] + l[1]) * 0.5
			var d: Vector3 = (l[1] - l[0]).normalized()
			mi.look_at(mi.global_position + d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	FX.light_flash(b, st["glow"], 6.0, 12.0, 0.15)
	var tw := root.create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(root, "visible", false, 0.0)
	tw.tween_interval(0.03)
	tw.tween_property(root, "visible", true, 0.0)
	tw.tween_property(sleeve, "albedo_color:a", 0.0, 0.12)
	tw.parallel().tween_property(core, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(root.queue_free)


## A ring of energy shooting along the atomic breath.
static func _ring(pos: Vector3, facing: float, st: Dictionary) -> void:
	var w := FX._world()
	if w == null:
		return
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	var mat := glow_mat(Color(st["glow"].lightened(0.3), 0.9))
	var mi := _mesh(w, torus, mat)
	mi.global_position = pos
	mi.rotation.z = PI / 2
	mi.scale = Vector3.ONE * 0.6
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position:x", pos.x + facing * BEAM_LEN * 0.9, 0.35)
	tw.tween_property(mi, "global_position:y", pos.y - BEAM_LEN * 0.18, 0.35)
	tw.tween_property(mi, "scale", Vector3(2.4, 1.0, 2.4), 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## A starburst of light (solar flare at the mouth, sun shot impacts).
static func _flare(pos: Vector3, st: Dictionary, size: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = pos
	var mat := glow_mat(Color(st["glow"].lightened(0.5), 0.9), true)
	for i in 4:
		var q := QuadMesh.new()
		q.size = Vector2(0.25, 4.5) * size
		var mi := _mesh(root, q, mat)
		mi.rotation.z = i * PI / 4 + randf() * 0.2
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "scale", Vector3(1.6, 1.6, 1.6), 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(root.queue_free)


## One crystal spike out of the street (TERRAXA's breath): bursts up in a
## spray of gravel, glows, then sinks back.
static func spike(pos: Vector3, st: Dictionary, size: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.36, 0.33, 0.28)
	rock.roughness = 0.95
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.2, 0.6, 0.2)
	crystal.emission_enabled = true
	crystal.emission = st["glow"]
	crystal.emission_energy_multiplier = 0.9
	crystal.roughness = 0.2
	var parts := [[Vector3.ZERO, 0.0, 4.2, 0.9, crystal], [Vector3(0.7, 0, 0.3), 0.35, 2.6, 0.6, crystal],
		[Vector3(-0.6, 0, -0.2), -0.4, 2.2, 0.55, crystal], [Vector3(0, 0, 0), 0.0, 1.1, 1.5, rock]]
	for part in parts:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0 if part[4] == crystal else part[3] * 0.6
		cyl.bottom_radius = part[3]
		cyl.height = part[2]
		cyl.radial_segments = 5
		cyl.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = part[4]
		root.add_child(mi)
		mi.position = part[0] + Vector3(0, part[2] * 0.5, 0)
		mi.rotation.z = part[1]
	root.scale = Vector3(size, 0.05, size)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(size, size, size), 0.09).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.55)
	tw.tween_property(root, "position:y", -4.5 * size, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	FX.dust(root.global_position, 0.7 * size)
	FX.debris_burst(root.global_position + Vector3(0, 0.5, 0), 0.6)
	FX.light_flash(root.global_position + Vector3(0, 2.0, 0), st["glow"], 3.0, 6.0, 0.25)


## A lingering cloud of the style's gas (SYLVARA's toxic mist).
static func cloud(pos: Vector3, st: Dictionary, size: float) -> void:
	var c1: Color = st["ramp"][1]
	var c2: Color = st["ramp"][2]
	var pm := FX._pm(Vector3.UP, 180.0, 0.5, 2.0 * size, 0.6, 3.0 * size, 5.0 * size, 1.0, 1.4 * size)
	pm.color_ramp = FX._ramp([Color(c1, 0.0), Color(c1, 0.55), Color(c2, 0.45), Color(c2, 0.0)])
	pm.scale_curve = FX._grow_curve()
	FX._emit(pos, 10, 2.2, FX._billboard("smoke", 1.0, false, Color.WHITE), pm)
	var bub := FX._pm(Vector3.UP, 40.0, 1.0, 3.0, 1.5, 0.25, 0.5, 0.5, 1.2 * size)
	bub.scale_curve = FX._shrink_curve()
	FX._emit(pos - Vector3(0, 1.2, 0), 8, 1.2, _bubble_mesh(Color(st["core"], 0.9)), bub)


## Ice crystals frozen onto the street (GLACIOR's breath) that melt away.
static func ice(pos: Vector3, st: Dictionary, size: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var mat := _ice_mat()
	for i in 4:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = randf_range(0.25, 0.45)
		cyl.height = randf_range(1.0, 2.4)
		cyl.radial_segments = 4
		cyl.rings = 1
		var mi := _mesh(root, cyl, mat)
		mi.position = Vector3(randf_range(-0.8, 0.8), cyl.height * 0.4, randf_range(-0.6, 0.6))
		mi.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
	root.scale = Vector3.ONE * 0.1
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * size, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(root, "scale", Vector3(size, 0.05, size), 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	if randf() < 0.5:
		ground(pos, st, size, 1.5)


static func _ice_mat() -> StandardMaterial3D:
	if not _cache.has("ice"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.92, 1.0, 0.75)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
		mat.metallic_specular = 1.0
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.75, 1.0)
		mat.emission_energy_multiplier = 0.8
		mat.rim_enabled = true
		mat.rim = 1.0
		_cache["ice"] = mat
	return _cache["ice"]


static func _bubble_mesh(c: Color) -> Mesh:
	var k := "bubble_%s" % c.to_html()
	if not _cache.has(k):
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(c, 0.35)
		mat.roughness = 0.05
		mat.rim_enabled = true
		mat.rim = 1.0
		mat.emission_enabled = true
		mat.emission = Color(c.r, c.g, c.b) * 0.5
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 5
		s.material = mat
		_cache[k] = s
	return _cache[k]


## Water bursting up where the hydro jet or a bubble hits.
static func splash(pos: Vector3, st: Dictionary, size: float) -> void:
	var pm := FX._pm(Vector3.UP, 35.0, 8.0 * size, 15.0 * size, -30.0, 0.8 * size, 1.6 * size, 0.5, 0.6 * size)
	pm.color_ramp = ramp(st)
	pm.scale_curve = FX._shrink_curve()
	FX._emit(pos, int(20 * size) + 6, 0.8, _soft(false), pm)
	var drops := FX._pm(Vector3.UP, 60.0, 8.0 * size, 18.0 * size, -34.0, 0.3, 0.6, 0.2, 0.5)
	drops.particle_flag_align_y = true
	drops.scale_curve = FX._shrink_curve()
	FX._emit(pos, 16, 0.9, spark_mesh(st["spark"]), drops)
	FX.shockwave(Vector3(pos.x, 0.2, pos.z), 3.0 * size, Color(0.8, 1.0, 1.0, 0.8))


# --- shots -------------------------------------------------------------------

## The flame skin / glow a shot drags behind it. Moved by the shot and
## stopped with FX.stop_stream.
static func trail(st: Dictionary, size: float, dir: float) -> GPUParticles3D:
	var w := FX._world()
	if w == null:
		return null
	var kind: String = st["shot"]
	var spread := 18.0
	var speed := 6.0
	var life := 0.38
	match kind:
		"shard", "crescent", "scrap":
			spread = 6.0
			life = 0.25
		"bubble":
			spread = 40.0
			speed = 3.0
			life = 0.6
		"venom", "glob":
			life = 0.5
		"rock":
			speed = 3.0
			life = 0.6
	var pm := FX._pm(Vector3(-dir, 0.15, 0), spread, speed * 0.75, speed, 2.5, size * 1.2, size * 2.4, 1.5, 0.5 * size)
	pm.color_ramp = ramp(st)
	pm.scale_curve = FX._grow_curve()
	var p := FX._stream_part(int(110 * size), life, pm, _soft(false), AABB(Vector3(-25, -10, -25), Vector3(50, 40, 50)))
	w.add_child(p)
	var em := FX._pm(Vector3(-dir, 0.3, 0), 50.0, 3.0, 8.0, -9.0 if kind != "bubble" else 2.0, 0.25, 0.5, 0.6, 0.5 * size)
	em.particle_flag_align_y = kind != "bubble"
	em.scale_curve = FX._shrink_curve()
	var mesh := _bubble_mesh(st["glow"]) if kind == "bubble" else spark_mesh(st["spark"])
	p.add_child(FX._stream_part(maxi(int(40 * size), 6), life * 1.6, em, mesh, p.visibility_aabb))
	return p


## Where a shot leaves the mouth: a flash in the style's colours.
static func muzzle(pos: Vector3, dir: Vector3, st: Dictionary, size := 1.0) -> void:
	var pm := FX._pm(dir, 35.0, 6.0 * size, 14.0 * size, 2.0, 1.2 * size, 2.2 * size, 4.0, 0.3 * size)
	pm.color_ramp = ramp(st)
	pm.scale_curve = FX._shrink_curve()
	FX._emit(pos, 14, 0.3, _soft(false), pm)
	FX.light_flash(pos, st["glow"], 6.0 * size, 9.0 * size, 0.18)


## Wind-up before the breath: motes of the element are sucked into the
## mouth while it glows brighter and brighter.
static func charge(pos: Vector3, st: Dictionary, duration: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var pm := FX._pm(Vector3.UP, 180.0, 0.0, 0.0, 0.0, 0.5, 1.0, 0.0, 3.2)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.radial_accel_min = -40.0
	pm.radial_accel_max = -30.0
	var c: Color = st["glow"]
	pm.color_ramp = FX._ramp([Color(c, 0.0), Color(c, 1.0), Color(st["core"], 1.0)])
	pm.scale_curve = FX._shrink_curve()
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.35
	p.one_shot = true
	p.process_material = pm
	p.draw_pass_1 = _soft(true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(p)
	p.global_position = pos
	p.emitting = true
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = 7.0
	l.light_energy = 0.0
	p.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 7.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "light_energy", 0.0, 0.1)
	w.get_tree().create_timer(duration + 0.6, false).timeout.connect(p.queue_free)


## Where a shot hits: a sharp pop in the element's colours with a ring on
## the ground, plus the element's own touch (splash, ice, gravel, sparks).
static func pop(pos: Vector3, st: Dictionary, size: float) -> void:
	var fire := FX._pm(Vector3.UP, 180.0, 6.0 * size, 14.0 * size, 2.0, 1.6 * size, 2.8 * size, 5.0, 0.4 * size)
	fire.color_ramp = ramp(st)
	fire.scale_curve = FX._grow_curve()
	FX._emit(pos, int(26 * size), 0.45, _soft(false), fire)
	var sparks := FX._pm(Vector3.UP, 180.0, 12.0 * size, 24.0 * size, -20.0, 0.6, 1.2, 0.5, 0.3)
	sparks.particle_flag_align_y = true
	sparks.scale_curve = FX._shrink_curve()
	FX._emit(pos, int(20 * size), 0.5, spark_mesh(st["spark"]), sparks)
	var flash := FX._pm(Vector3.UP, 0.0, 0.0, 0.0, 0.0, 2.5 * size, 3.0 * size, 0.0)
	flash.scale_curve = FX._shrink_curve()
	flash.color_ramp = core_ramp(st)
	FX._emit(pos, 1, 0.12, _soft(false), flash)
	FX.shockwave(Vector3(pos.x, 0.2, pos.z), 2.5 * size, st["glow"])
	FX.light_flash(pos, st["glow"], 5.0 * size, 9.0 * size, 0.25)
	match String(st["shot"]):
		"bubble":
			splash(pos, st, 0.8 * size)
		"shard":
			ice(Vector3(pos.x, 0.0, pos.z), st, 0.6 * size)
		"rock":
			FX.debris_burst(pos, 1.0 * size)
			FX.dust(Vector3(pos.x, 0.0, pos.z), 1.0 * size)
		"venom":
			cloud(pos, st, 0.7 * size)
		"sun":
			_flare(pos, st, 1.2 * size)
		"glob", "orb":
			FX.smoke(pos + Vector3(0, 1.0, 0), 0.5 * size, Color(0.16, 0.11, 0.09) if st["shot"] == "glob" else Color(0.1, 0.15, 0.3))
		"crescent":
			FX.smoke(pos, 0.5 * size, st["smoke"])


## Weapon swings in rage mode burst into the element (see Player._fire_burst).
static func burst(pos: Vector3, radius: float, st: Dictionary) -> void:
	var s := radius / 4.0
	var fire := FX._pm(Vector3.UP, 180.0, 5.0 * s, 13.0 * s, 6.0, 2.6 * s, 4.8 * s, 3.5, 1.0 * s)
	fire.color_ramp = ramp(st)
	fire.scale_curve = FX._grow_curve()
	FX._emit(pos, 48, 0.8, _soft(false), fire)
	FX.shockwave(Vector3(pos.x, 0.5, pos.z), radius, st["glow"])
	FX.light_flash(pos, st["glow"], 12.0 * s, 14.0 * s, 0.45)
	pop(pos, st, s)


# --- marks on the street -------------------------------------------------------

## Stops a stream after `t` seconds, unless it is gone by then (level ended).
static func _stop_later(p: GPUParticles3D, t: float) -> void:
	# The timer lives on the stream, so it goes when the level does.
	var timer := Timer.new()
	timer.wait_time = t
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(FX.stop_stream.bind(p))
	p.add_child(timer)


## What the element leaves on the street for a while: burning flames,
## glowing lava, a radioactive glow, frost, a poison puddle, cracks, a
## puddle of water, a pool of shadow or burning oil.
static func ground(pos: Vector3, st: Dictionary, size: float, duration: float) -> void:
	var kind: String = st["ground"]
	if kind == "fire":
		_ground_patch(pos, Color(0.05, 0.04, 0.035, 0.8), false, size, duration)
		_ground_flames(pos, st, size, duration)
		return
	var w := FX._world()
	if w == null:
		return
	var col := Color(0.05, 0.04, 0.035, 0.8)
	var glow := false
	match kind:
		"lava":
			col = Color(2.2, 0.7, 0.1, 0.95)
			glow = true
		"glow":
			col = Color(0.3, 1.2, 2.0, 0.6)
			glow = true
		"scorch":
			col = Color(0.04, 0.04, 0.06, 0.75)
		"poison":
			col = Color(0.45, 1.0, 0.25, 0.55)
			glow = true
		"crack":
			col = Color(0.08, 0.07, 0.06, 0.85)
		"ice":
			col = Color(0.8, 0.95, 1.0, 0.7)
		"puddle":
			col = Color(0.15, 0.45, 0.55, 0.6)
		"shadow":
			col = Color(0.12, 0.0, 0.03, 0.8)
		"oil":
			col = Color(0.02, 0.02, 0.025, 0.85)
	_ground_patch(pos, col, glow, size, duration)
	match kind:
		"lava":
			_ground_patch(pos, Color(0.08, 0.03, 0.02, 0.85), false, size * 1.35, duration)
			_ground_flames(pos, st, size * 0.8, duration)
		"poison":
			var bub := FX._pm(Vector3.UP, 20.0, 0.5, 1.5, 0.5, 0.2, 0.45, 0.5, 1.0 * size)
			bub.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			bub.emission_box_extents = Vector3(1.2, 0.05, 0.8) * size
			bub.scale_curve = FX._shrink_curve()
			var p := FX._stream_part(10, 0.8, bub, _bubble_mesh(st["glow"]), AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12)))
			p.fixed_fps = 0
			w.add_child(p)
			p.global_position = Vector3(pos.x, 0.1, pos.z)
			_stop_later(p, duration)
		"oil":
			_ground_flames(pos, RageStyle.for_hero(2), size * 0.6, duration)
		"glow", "shadow", "ice":
			var c: Color = st["glow"] if kind != "ice" else Color(0.9, 0.97, 1.0)
			var pm := FX._pm(Vector3.UP, 15.0, 0.6, 1.8, 0.4, 0.4 * size, 0.9 * size, 0.5, 1.0 * size)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(1.3, 0.05, 0.9) * size
			pm.color_ramp = FX._ramp([Color(c, 0.0), Color(c, 0.6), Color(c, 0.0)])
			pm.scale_curve = FX._shrink_curve()
			var p := FX._stream_part(12, 1.0, pm, _soft(kind == "glow"), AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12)))
			p.fixed_fps = 0
			w.add_child(p)
			p.global_position = Vector3(pos.x, 0.1, pos.z)
			_stop_later(p, duration)


## A flat patch on the street that fades out after `duration`.
static func _ground_patch(pos: Vector3, col: Color, glow: bool, size: float, duration: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.4, 2.6) * size
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = FX._soft_texture()
	mat.albedo_color = col
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.08 + randf() * 0.03, pos.z)
	mi.rotation.y = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_interval(duration + 1.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(mi.queue_free)


static func _ground_flames(pos: Vector3, st: Dictionary, size: float, duration: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var pm := FX._pm(Vector3.UP, 15.0, 2.0, 4.5, 2.0, 0.8 * size, 1.6 * size, 1.0, 1.0 * size)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.4, 0.1, 1.0) * size
	pm.color_ramp = ramp(st)
	pm.scale_curve = FX._shrink_curve()
	var p := FX._stream_part(int(18 * size) + 6, 0.55, pm, _soft(false), AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12)))
	p.fixed_fps = 0
	w.add_child(p)
	p.global_position = Vector3(pos.x, 0.08, pos.z)
	_stop_later(p, duration)
