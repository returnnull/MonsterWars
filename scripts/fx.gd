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


## Rage-mode punch: a ball of flame with a burning ring on the ground.
static func fire_burst(pos: Vector3, radius: float) -> void:
	var s := radius / 4.0
	var fire_ramp := _flame_ramp()
	var fire := _pm(Vector3.UP, 180.0, 5.0 * s, 13.0 * s, 6.0, 2.6 * s, 4.8 * s, 3.5, 1.0 * s)
	fire.color_ramp = fire_ramp
	fire.scale_curve = _grow_curve()
	_emit(pos, 48, 0.8, _billboard("flame", 1.0, false, Color.WHITE), fire)
	var core := _pm(Vector3.UP, 180.0, 1.0 * s, 4.0 * s, 0.0, 2.0 * s, 3.2 * s, 3.0, 0.4 * s)
	core.scale_curve = _shrink_curve()
	_emit(pos, 6, 0.25, _billboard("fire_core", 1.0, true, Color(1.0, 0.75, 0.35)), core)
	var ground := Vector3(pos.x, 0.5, pos.z)
	var ring := _pm(Vector3.UP, 20.0, 3.0, 9.0, 6.0, 2.0 * s, 3.6 * s, 2.0, radius * 0.85)
	ring.color_ramp = fire_ramp
	ring.scale_curve = _grow_curve()
	_emit(ground, 40, 0.9, _billboard("flame", 1.0, false, Color.WHITE), ring)
	shockwave(ground, radius, Color(1.6, 0.5, 0.08))
	smoke(pos + Vector3(0, 1.5, 0), s, Color(0.16, 0.11, 0.09))
	light_flash(pos, Color(1.0, 0.45, 0.1), 12.0 * s, 14.0 * s, 0.45)


## Rage-fire colours: white-hot core fading through orange and red to soot.
static func _flame_ramp() -> GradientTexture1D:
	if not _cache.has("flame_ramp"):
		_cache["flame_ramp"] = _ramp([Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.62, 0.12, 1.0), Color(0.95, 0.3, 0.03, 0.95),
			Color(0.55, 0.08, 0.02, 0.7), Color(0.12, 0.05, 0.04, 0.0)])
	return _cache["flame_ramp"]


## A continuous flame emitter in the world: the fireball trail and the heavy
## fire spray. Flames leave along `dir` and stay where they were emitted, so
## the caller moves the node each frame and ends it with stop_stream().
static func fire_stream(dir: Vector3, speed: float, spread: float, size: float, lifetime: float, amount: int, hot_core := false) -> GPUParticles3D:
	var w := _world()
	if w == null:
		return null
	var pm := _pm(dir, spread, speed * 0.75, speed, 2.5, size * 0.6, size * 1.2, 1.5, 0.25 * size)
	pm.color_ramp = _flame_ramp()
	pm.scale_curve = _grow_curve()
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	# Emit every frame so a fast-moving stream leaves no gaps.
	p.fixed_fps = 60
	p.process_material = pm
	# Blended, not additive: stacked flames stay orange instead of turning white.
	p.draw_pass_1 = _billboard("flame", 1.0, false, Color.WHITE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-25, -10, -25), Vector3(50, 40, 50))
	w.add_child(p)
	# Embers: small sparks thrown out of the flames that fall as they cool.
	var em := _pm(dir, spread * 1.6, speed * 0.5, speed * 1.1, -9.0, 0.25, 0.5, 0.6, 0.3 * size)
	em.particle_flag_align_y = true
	em.scale_curve = _shrink_curve()
	var embers := GPUParticles3D.new()
	embers.amount = maxi(amount / 3, 4)
	embers.lifetime = lifetime * 1.4
	embers.local_coords = false
	embers.process_material = em
	embers.draw_pass_1 = _spark_mesh()
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.visibility_aabb = p.visibility_aabb
	p.add_child(embers)
	if hot_core:
		# A white-hot, glowing inner jet in the first part of the flames.
		var cm := _pm(dir, spread * 0.5, speed * 0.8, speed, 0.0, size * 0.35, size * 0.6, 2.0, 0.1 * size)
		cm.scale_curve = _shrink_curve()
		var core := GPUParticles3D.new()
		core.amount = maxi(amount / 2, 4)
		core.lifetime = lifetime * 0.45
		core.local_coords = false
		core.fixed_fps = 60
		core.process_material = cm
		core.draw_pass_1 = _billboard("fire_core", 1.0, true, Color(1.0, 0.75, 0.35))
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.visibility_aabb = p.visibility_aabb
		p.add_child(core)
	return p


## Lets a fire_stream's last flames burn out, then frees it.
static func stop_stream(p: GPUParticles3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	for c in p.get_children():
		if c is GPUParticles3D:
			c.emitting = false
	p.get_tree().create_timer(p.lifetime * 1.5 + 0.2, false).timeout.connect(p.queue_free)


## Small fiery flash where the rage fire leaves the mouth.
static func fire_muzzle(pos: Vector3, dir: Vector3, size: float = 1.0) -> void:
	var pm := _pm(dir, 35.0, 6.0 * size, 14.0 * size, 2.0, 1.2 * size, 2.2 * size, 4.0, 0.3 * size)
	pm.color_ramp = _flame_ramp()
	pm.scale_curve = _shrink_curve()
	_emit(pos, 14, 0.3, _billboard("flame", 1.0, false, Color.WHITE), pm)
	light_flash(pos, Color(1.0, 0.5, 0.12), 6.0 * size, 9.0 * size, 0.18)


## Deep flamethrower colours for the heavy rage attack: yellow at the mouth,
## then saturated orange and red, ending in dark smoke, so the stream reads
## as a long orange cone instead of a white blob.
static func _jet_ramp() -> GradientTexture1D:
	if not _cache.has("jet_ramp"):
		_cache["jet_ramp"] = _ramp([Color(1.0, 0.82, 0.35, 0.95), Color(1.0, 0.5, 0.06, 1.0), Color(0.95, 0.25, 0.02, 0.95),
			Color(0.6, 0.1, 0.02, 0.8), Color(0.18, 0.08, 0.06, 0.55), Color(0.1, 0.08, 0.08, 0.0)])
	return _cache["jet_ramp"]


## The heavy rage attack's flamethrower: a wide, roaring cone of flame with
## a yellow inner jet, sparks, and black smoke boiling up off its far end.
## Moved and stopped like fire_stream (see stop_stream).
static func flame_jet(dir: Vector3, speed: float, size: float, lifetime: float) -> GPUParticles3D:
	var w := _world()
	if w == null:
		return null
	var aabb := AABB(Vector3(-30, -10, -30), Vector3(60, 40, 60))
	var pm := _pm(dir, 8.0, speed * 0.8, speed, 3.0, size * 0.6, size * 1.2, 1.2, 0.2 * size)
	pm.color_ramp = _jet_ramp()
	pm.scale_curve = _grow_curve()
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	var p := _stream_part(220, lifetime, pm, _billboard("flame", 1.0, false, Color.WHITE), aabb)
	w.add_child(p)
	# Yellow inner jet: thin and short, so the cone is hottest at the mouth.
	var cm := _pm(dir, 4.0, speed * 0.9, speed * 1.05, 0.0, size * 0.35, size * 0.55, 1.0, 0.1 * size)
	cm.color_ramp = _ramp([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.75, 0.25, 0.9), Color(1.0, 0.45, 0.05, 0.0)])
	cm.scale_curve = _grow_curve()
	p.add_child(_stream_part(90, lifetime * 0.45, cm, _billboard("flame", 1.0, false, Color.WHITE), aabb))
	# Smoke rides the flames out and only shows up near the end of the cone.
	var sm := _pm(dir, 14.0, speed * 0.55, speed * 0.75, 5.0, size * 1.0, size * 1.7, 1.6, 0.4 * size)
	sm.color_ramp = _ramp([Color(0.1, 0.08, 0.07, 0.0), Color(0.1, 0.08, 0.07, 0.0), Color(0.16, 0.13, 0.12, 0.55), Color(0.22, 0.2, 0.19, 0.0)])
	sm.scale_curve = _grow_curve()
	p.add_child(_stream_part(60, lifetime * 2.6, sm, _billboard("smoke", 1.0, false, Color.WHITE), aabb))
	var em := _pm(dir, 16.0, speed * 0.6, speed * 1.2, -12.0, 0.3, 0.6, 0.5, 0.4 * size)
	em.particle_flag_align_y = true
	em.scale_curve = _shrink_curve()
	p.add_child(_stream_part(60, lifetime * 1.5, em, _spark_mesh(), aabb))
	return p


static func _stream_part(amount: int, lifetime: float, pm: ParticleProcessMaterial, mesh: Mesh, aabb: AABB) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.fixed_fps = 60
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = aabb
	return p


## Wind-up for the flamethrower: sparks get sucked into the mouth while it
## glows brighter and brighter.
static func mouth_charge(pos: Vector3, duration: float) -> void:
	var pm := _pm(Vector3.UP, 180.0, 0.0, 0.0, 0.0, 0.5, 1.0, 0.0, 3.2)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.radial_accel_min = -40.0
	pm.radial_accel_max = -30.0
	pm.color_ramp = _ramp([Color(1.0, 0.5, 0.1, 0.0), Color(1.0, 0.6, 0.15, 1.0), Color(1.0, 0.9, 0.5, 1.0)])
	pm.scale_curve = _shrink_curve()
	var w := _world()
	if w == null:
		return
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 0.0
	p.process_material = pm
	p.draw_pass_1 = _billboard("flame", 1.0, false, Color.WHITE)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(p)
	p.global_position = pos
	p.emitting = true
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.15)
	l.omni_range = 7.0
	l.light_energy = 0.0
	p.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 7.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "light_energy", 0.0, 0.1)
	w.get_tree().create_timer(duration + 0.6, false).timeout.connect(p.queue_free)


## Flames left burning on the street, with a black scorch mark under them
## that fades out afterwards.
static func ground_fire(pos: Vector3, size: float, duration: float) -> void:
	var w := _world()
	if w == null:
		return
	var ground := Vector3(pos.x, 0.08, pos.z)
	var scorch := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.4, 2.6) * size
	scorch.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_texture()
	mat.albedo_color = Color(0.05, 0.04, 0.035, 0.8)
	scorch.material_override = mat
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(scorch)
	scorch.global_position = ground + Vector3(0, randf() * 0.02, 0)
	scorch.rotation.y = randf() * TAU
	var tw := scorch.create_tween()
	tw.tween_interval(duration + 1.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(scorch.queue_free)
	var pm := _pm(Vector3.UP, 15.0, 2.0, 4.5, 2.0, 0.8 * size, 1.6 * size, 1.0, 1.0 * size)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.4, 0.1, 1.0) * size
	pm.color_ramp = _jet_ramp()
	pm.scale_curve = _shrink_curve()
	var p := _stream_part(int(18 * size) + 6, 0.55, pm, _billboard("flame", 1.0, false, Color.WHITE), AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12)))
	p.fixed_fps = 0
	w.add_child(p)
	p.global_position = ground
	w.get_tree().create_timer(duration, false).timeout.connect(stop_stream.bind(p))


## Where a fireball hits: a quick, sharp pop of flame and sparks with a ring
## on the ground. `size` grows everything (the third, big fireball).
static func fireball_pop(pos: Vector3, size: float) -> void:
	var fire := _pm(Vector3.UP, 180.0, 6.0 * size, 14.0 * size, 2.0, 1.6 * size, 2.8 * size, 5.0, 0.4 * size)
	fire.color_ramp = _flame_ramp()
	fire.scale_curve = _grow_curve()
	_emit(pos, int(26 * size), 0.45, _billboard("flame", 1.0, false, Color.WHITE), fire)
	var sparks := _pm(Vector3.UP, 180.0, 12.0 * size, 24.0 * size, -20.0, 0.6, 1.2, 0.5, 0.3)
	sparks.particle_flag_align_y = true
	sparks.scale_curve = _shrink_curve()
	_emit(pos, int(22 * size), 0.5, _spark_mesh(), sparks)
	var flash := _pm(Vector3.UP, 0.0, 0.0, 0.0, 0.0, 3.0 * size, 4.0 * size, 0.0)
	flash.scale_curve = _shrink_curve()
	_emit(pos, 1, 0.1, _billboard("fire_core", 1.0, true, Color(1.0, 0.75, 0.35)), flash)
	shockwave(Vector3(pos.x, 0.2, pos.z), 2.5 * size, Color(1.4, 0.45, 0.06))
	smoke(pos + Vector3(0, 1.0, 0), 0.5 * size, Color(0.16, 0.11, 0.09))
	light_flash(pos, Color(1.0, 0.5, 0.12), 5.0 * size, 9.0 * size, 0.25)


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


## The name of a combo special popping up over the kaiju that used it.
static func callout(pos: Vector3, text: String, color: Color) -> void:
	var w := _world()
	if w == null:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.pixel_size = 0.012
	l.font_size = 72
	l.outline_size = 20
	l.modulate = color.lerp(Color.WHITE, 0.45)
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	w.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 1.5
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y + 2.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.65)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.65)
	tw.chain().tween_callback(l.queue_free)


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


## A jagged lightning bolt from `a` to `b` that flickers out.
static func bolt(a: Vector3, b: Vector3, color: Color) -> void:
	var w := _world()
	if w == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color * 2.5
	var root := Node3D.new()
	w.add_child(root)
	var segs := 7
	var prev := a
	for i in segs:
		var t := float(i + 1) / segs
		var p := a.lerp(b, t)
		if i < segs - 1:
			p += Vector3(randf_range(-1.2, 1.2), randf_range(-0.6, 0.6), randf_range(-0.5, 0.5))
		var seg_len := prev.distance_to(p)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.22, seg_len)
		mi.mesh = box
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = (prev + p) * 0.5
		if not (p - prev).normalized().is_equal_approx(Vector3.UP) and not (p - prev).normalized().is_equal_approx(Vector3.DOWN):
			mi.look_at(p, Vector3.UP)
		else:
			mi.look_at(p, Vector3.RIGHT)
		prev = p
	light_flash(b + Vector3.UP, color, 8.0, 14.0, 0.25)
	var tw := root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(root.queue_free)


## A glowing rock that falls from the sky onto `target`, then calls `on_land`.
static func meteor(target: Vector3, color: Color, fall_time: float, on_land: Callable) -> void:
	var w := _world()
	if w == null:
		return
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.1
	sph.height = 2.2
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	w.add_child(mi)
	var start := target + Vector3(-10.0, 34.0, -4.0)
	mi.global_position = start
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", target, fall_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		explosion(target, 0.9)
		on_land.call()
		mi.queue_free())


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
