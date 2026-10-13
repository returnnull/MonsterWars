class_name FX
extends RefCounted
## Short-lived visual effects (particles, light flashes, shockwaves) spawned into the active world.

static var _cache := {}


static func _world() -> Node3D:
	if Game.world and is_instance_valid(Game.world):
		return Game.world
	return null


static func hit_spark(pos: Vector3, power: float = 10.0) -> void:
	var s := clampf(power / 12.0, 0.6, 2.2)
	var pm := _pm(Vector3.UP, 180.0, 8.0 * s, 20.0 * s, -18.0, 0.6, 1.3, 0.2)
	pm.particle_flag_align_y = true
	pm.scale_curve = _shrink_curve()
	_emit(pos, int(12 * s) + 6, 0.35, _spark_mesh(), pm)
	var flash_pm := _pm(Vector3.UP, 0.0, 0.0, 0.0, 0.0, 2.5 * s, 3.5 * s, 0.0)
	flash_pm.scale_curve = _shrink_curve()
	_emit(pos, 2, 0.12, _billboard("flash", 1.0, true, Color(1.6, 1.3, 0.8)), flash_pm)
	light_flash(pos, Color(1.0, 0.8, 0.5), 4.0 * s, 7.0 * s, 0.12)


static func explosion(pos: Vector3, size: float = 1.0) -> void:
	var fire_ramp := _ramp([Color(2.0, 1.5, 0.7, 1.0), Color(1.4, 0.45, 0.08, 0.85), Color(0.2, 0.08, 0.04, 0.0)])
	var fire := _pm(Vector3.UP, 180.0, 2.0 * size, 8.0 * size, 3.0, 2.0 * size, 4.0 * size, 2.0, 1.0 * size)
	fire.color_ramp = fire_ramp
	fire.scale_curve = _grow_curve()
	_emit(pos, 26, 0.9, _billboard("fire", 1.0, true, Color.WHITE), fire)
	smoke(pos, size * 1.3, Color(0.16, 0.14, 0.13))
	debris_burst(pos, size)
	light_flash(pos + Vector3.UP, Color(1.0, 0.55, 0.2), 10.0 * size, 16.0 * size, 0.6)


static func smoke(pos: Vector3, size: float = 1.0, color: Color = Color(0.55, 0.5, 0.45)) -> void:
	var c0 := Color(color, 0.0)
	var ramp := _ramp([c0, Color(color, 0.75), Color(color.darkened(0.3), 0.0)])
	var pm := _pm(Vector3(0, 0.4, 0), 80.0, 1.5 * size, 5.0 * size, 1.2, 3.0 * size, 6.0 * size, 2.5, 1.5 * size)
	pm.color_ramp = ramp
	pm.scale_curve = _grow_curve()
	_emit(pos, 18, 2.4, _billboard("smoke", 1.0, false, Color.WHITE), pm)


static func dust(pos: Vector3, size: float = 1.0) -> void:
	var ramp := _ramp([Color(0.7, 0.62, 0.5, 0.0), Color(0.7, 0.62, 0.5, 0.6), Color(0.6, 0.55, 0.5, 0.0)])
	var pm := _pm(Vector3(0, 0.15, 0), 90.0, 3.0 * size, 7.0 * size, 0.4, 1.5 * size, 3.0 * size, 4.0, 0.8 * size)
	pm.color_ramp = ramp
	pm.scale_curve = _grow_curve()
	_emit(pos + Vector3(0, 0.4, 0), 12, 1.2, _billboard("smoke", 1.0, false, Color.WHITE), pm)


static func debris_burst(pos: Vector3, size: float = 0.6) -> void:
	var pm := _pm(Vector3.UP, 70.0, 5.0, 12.0 * maxf(size, 0.6), -28.0, 0.4, 1.4 * maxf(size, 0.6), 0.0, 0.6)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	_emit(pos, 12, 1.4, _debris_mesh(), pm)


static func energy(pos: Vector3, color: Color) -> void:
	var pm := _pm(Vector3.UP, 180.0, 3.0, 9.0, 4.0, 0.5, 1.2, 1.5, 1.0)
	pm.scale_curve = _shrink_curve()
	_emit(pos, 30, 0.8, _billboard("energy_%s" % color.to_html(), 0.6, true, color * 2.0), pm)
	light_flash(pos, color, 6.0, 9.0, 0.4)


static func shockwave(pos: Vector3, radius: float, color: Color = Color(0.6, 0.9, 1.0)) -> void:
	var w := _world()
	if w == null:
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 48
	mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(0.5, 2.0, 0.5)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.6, radius), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)


static func light_flash(pos: Vector3, color: Color, energy_amount: float, light_range: float, duration: float) -> void:
	var w := _world()
	if w == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy_amount
	l.omni_range = light_range
	l.shadow_enabled = false
	w.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


# --- internals -------------------------------------------------------------

static func _emit(pos: Vector3, amount: int, lifetime: float, mesh: Mesh, pm: ParticleProcessMaterial) -> void:
	var w := _world()
	if w == null:
		return
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-25, -10, -25), Vector3(50, 40, 50))
	w.add_child(p)
	p.global_position = pos
	p.emitting = true
	w.get_tree().create_timer(lifetime + 0.4, false).timeout.connect(p.queue_free)


static func _pm(dir: Vector3, spread: float, vmin: float, vmax: float, grav: float,
		smin: float, smax: float, damp: float, radius: float = 0.3) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = dir
	m.spread = spread
	m.initial_velocity_min = vmin
	m.initial_velocity_max = vmax
	m.gravity = Vector3(0, grav, 0)
	m.scale_min = smin
	m.scale_max = smax
	m.damping_min = damp
	m.damping_max = damp
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = maxf(radius, 0.01)
	return m


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _shrink_curve() -> CurveTexture:
	if not _cache.has("shrink"):
		var c := Curve.new()
		c.add_point(Vector2(0, 1))
		c.add_point(Vector2(1, 0))
		var t := CurveTexture.new()
		t.curve = c
		_cache["shrink"] = t
	return _cache["shrink"]


static func _grow_curve() -> CurveTexture:
	if not _cache.has("grow"):
		var c := Curve.new()
		c.add_point(Vector2(0, 0.35))
		c.add_point(Vector2(1, 1))
		var t := CurveTexture.new()
		t.curve = c
		_cache["grow"] = t
	return _cache["grow"]


static func _soft_texture() -> Texture2D:
	if not _cache.has("soft"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_cache["soft"] = t
	return _cache["soft"]


static func _billboard(key: String, size: float, additive: bool, tint: Color) -> QuadMesh:
	var k := "bb_" + key
	if not _cache.has(k):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = tint
		mat.albedo_texture = _soft_texture()
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = mat
		_cache[k] = q
	return _cache[k]


static func _spark_mesh() -> Mesh:
	if not _cache.has("spark"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.5)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.3)
		mat.emission_energy_multiplier = 8.0
		var b := BoxMesh.new()
		b.size = Vector3(0.07, 0.7, 0.07)
		b.material = mat
		_cache["spark"] = b
	return _cache["spark"]


static func _debris_mesh() -> Mesh:
	if not _cache.has("debris"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.4, 0.38)
		mat.roughness = 0.95
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 0.25, 0.3)
		b.material = mat
		_cache["debris"] = b
	return _cache["debris"]
