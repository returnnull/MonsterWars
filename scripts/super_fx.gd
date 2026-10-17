class_name SuperFX
extends RefCounted
## How the heroes' super specials look (see Player._state_super): the
## power-up every super starts with and each super's own big effects. Uses
## the hero's RageStyle colours so a super matches its rage attacks.


## Every super starts here: a glowing rune circle spins up under the hero,
## a pillar of light shoots up through it and the element is sucked in.
static func charge(pos: Vector3, st: Dictionary, duration: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var g: Color = st["glow"]
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = Vector3(pos.x, 0.12, pos.z)
	# Rune circle: two thin rings and a soft disc, turning opposite ways.
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	disc.mesh = plane
	var dmat := RageFX.glow_mat(Color(g, 0.55), true)
	dmat.albedo_texture = FX._soft_texture()
	disc.material_override = dmat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var rings: Array = []
	for r in [[7.0, 0.25], [5.2, 0.15]]:
		var t := TorusMesh.new()
		t.inner_radius = r[0] - r[1]
		t.outer_radius = r[0]
		t.rings = 48
		t.ring_segments = 4
		var mi := RageFX._mesh(root, t, RageFX.glow_mat(Color(g.lightened(0.4), 0.95)))
		mi.scale.y = 0.2
		rings.append(mi)
	# Six glowing marks on the outer ring.
	for i in 6:
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.05, 1.4)
		var mi := RageFX._mesh(rings[0], b, RageFX.glow_mat(Color(g.lightened(0.5), 1.0)))
		var a := i * TAU / 6.0
		mi.position = Vector3(cos(a), 0, sin(a)) * 6.1
		mi.rotation.y = -a
	root.scale = Vector3.ONE * 0.2
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rings[0], "rotation:y", TAU * 1.5, duration)
	tw.tween_property(rings[1], "rotation:y", -TAU * 2.0, duration)
	tw.chain().tween_property(dmat, "albedo_color:a", 0.0, 0.5)
	tw.tween_property(root, "scale", Vector3(1.3, 1.0, 1.3), 0.5)
	tw.chain().tween_callback(root.queue_free)
	pillar(pos, st, 0.9)
	# The element is sucked in from all round.
	var pm := FX._pm(Vector3.UP, 180.0, 0.0, 0.0, 0.0, 0.8, 1.6, 0.0, 9.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.radial_accel_min = -55.0
	pm.radial_accel_max = -40.0
	pm.tangential_accel_min = 20.0
	pm.tangential_accel_max = 30.0
	pm.color_ramp = FX._ramp([Color(g, 0.0), Color(g, 1.0), Color(g.lightened(0.6), 1.0)])
	pm.scale_curve = FX._shrink_curve()
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 0.3
	p.process_material = pm
	p.draw_pass_1 = RageFX._soft(false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(p)
	p.global_position = pos + Vector3(0, 4.0, 0)
	p.emitting = true
	w.get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


## A pillar of light shooting up from the street and fading.
static func pillar(pos: Vector3, st: Dictionary, duration: float, radius := 3.0) -> void:
	var w := FX._world()
	if w == null:
		return
	var g: Color = st["glow"]
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var mats: Array = []
	for layer in [[radius * 0.25, Color(g.lightened(0.3), 0.5)], [radius, Color(g, 0.18)]]:
		var c := CylinderMesh.new()
		c.top_radius = layer[0] * 0.6
		c.bottom_radius = layer[0]
		c.height = 60.0
		c.radial_segments = 20
		c.rings = 1
		var m := RageFX.glow_mat(layer[1])
		var mi := RageFX._mesh(root, c, m)
		mi.position.y = 30.0
		mats.append(m)
	root.scale = Vector3(0.2, 0.01, 0.2)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration * 0.4)
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3(0.05, 1.0, 0.05), duration * 0.6).set_ease(Tween.EASE_IN)
	for m in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, duration * 0.6)
	tw.chain().tween_callback(root.queue_free)


## OMEGA BREATH: energy rings racing down the beam, and the far end
## exploding where it hits.
static func mega_beam_tick(origin: Vector3, facing: float, length: float, st: Dictionary, step: int) -> void:
	var w := FX._world()
	if w == null:
		return
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.4
	torus.rings = 32
	torus.ring_segments = 4
	var mat := RageFX.glow_mat(Color(st["glow"].lightened(0.35), 0.9))
	var mi := RageFX._mesh(w, torus, mat)
	mi.global_position = origin
	mi.rotation.z = PI / 2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position:x", origin.x + facing * length, 0.4)
	tw.tween_property(mi, "scale", Vector3(2.0, 1.0, 2.0), 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	if step % 3 == 0:
		var end := Vector3(origin.x + facing * randf_range(length * 0.5, length * 0.9), randf_range(1.0, 5.0), origin.z + randf_range(-2.0, 2.0))
		RageFX.pop(end, st, 1.6)
		RageFX.ground(Vector3(end.x, 0, end.z), st, 1.6, 2.0)


## THUNDERSTORM: a dark storm cloud boils up over the street.
static func storm_cloud(pos: Vector3, facing: float, duration: float) -> void:
	var c := Color(0.12, 0.12, 0.16)
	var pm := FX._pm(Vector3(0, 0.1, 0), 90.0, 0.5, 2.5, 0.0, 9.0, 15.0, 1.0, 4.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18.0, 1.5, 5.0)
	pm.color_ramp = FX._ramp([Color(c, 0.0), Color(c, 0.85), Color(c, 0.85), Color(c, 0.0)])
	pm.scale_curve = FX._grow_curve()
	FX._emit(pos + Vector3(facing * 12.0, 19.0, -5.0), 40, duration, FX._billboard("smoke", 1.0, false, Color.WHITE), pm)


## One lightning strike from the cloud: a thick forked bolt, a blast of
## sparks and a scorched spot on the street.
static func lightning_strike(target: Vector3, st: Dictionary) -> void:
	var top := target + Vector3(randf_range(-4, 4), 19.0, -3.0)
	RageFX.bolt(top, target + Vector3(0, 0.3, 0), st, 2.6)
	RageFX.bolt(top + Vector3(randf_range(-2, 2), 0, 0), target + Vector3(randf_range(-1.5, 1.5), 0.3, 0), st, 1.4)
	RageFX.pop(target + Vector3(0, 0.6, 0), st, 1.4)
	RageFX.ground(target, st, 1.4, 2.0)
	FX.light_flash(target + Vector3(0, 8, 0), st["glow"], 14.0, 34.0, 0.18)


## A burning rock (MAGMA RAIN) or a red-hot hunk of scrap (SCRAP BARRAGE)
## that streaks down trailing fire and smoke onto `target`, then calls
## `on_land`. `size` scales it, `start` sets where it falls from (default:
## high up behind) and `air` bursts it in mid-air (no crater).
static func falling(target: Vector3, st: Dictionary, scrap: bool, fall_time: float, on_land: Callable,
		size := 1.0, start := Vector3.INF, air := false) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	var mat := StandardMaterial3D.new()
	if scrap:
		mat.albedo_color = Color(0.4, 0.33, 0.28)
		mat.metallic = 0.85
		mat.roughness = 0.4
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.08)
		mat.emission_energy_multiplier = 1.2
		for i in 3:
			var b := BoxMesh.new()
			b.size = Vector3(randf_range(0.8, 2.0), randf_range(0.3, 0.8), randf_range(0.6, 1.4))
			var mi := RageFX._mesh(root, b, mat)
			mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
			mi.position = Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), 0)
	else:
		mat.albedo_color = Color(0.14, 0.06, 0.04)
		mat.roughness = 0.9
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.06)
		mat.emission_energy_multiplier = 2.2
		var s := SphereMesh.new()
		s.radius = 1.2
		s.height = 2.4
		s.radial_segments = 7
		s.rings = 4
		RageFX._mesh(root, s, mat)
		var glow := SphereMesh.new()
		glow.radius = 1.8
		glow.height = 3.6
		RageFX._mesh(root, glow, RageFX.glow_mat(Color(1.0, 0.45, 0.1, 0.35)))
	if start == Vector3.INF:
		start = target + Vector3(-12.0, 36.0, -4.0) * clampf(size, 1.0, 2.0)
	root.global_position = start
	root.scale = Vector3.ONE * size
	var fire_st: Dictionary = RageStyle.for_hero(2)
	var trail := RageFX.trail(fire_st, 1.6 * size, 1.0)
	var spin := Vector3(randf_range(4, 9), randf_range(4, 9), 0)
	var tw := root.create_tween()
	tw.tween_method(func(k: float) -> void:
		root.global_position = start.lerp(target, k * k)
		root.rotation = spin * k
		if trail and is_instance_valid(trail):
			trail.global_position = root.global_position, 0.0, 1.0, fall_time)
	tw.tween_callback(func() -> void:
		FX.stop_stream(trail)
		FX.explosion(target, size)
		if air:
			RageFX.pop(target, st, 1.4 * size)
		else:
			RageFX.ground(target, st, 1.5 * size, 2.5)
		if scrap and not air:
			FX.debris_burst(target + Vector3(0, 1, 0), 1.2 * size)
			var pm := FX._pm(Vector3.UP, 70.0, 10.0, 22.0, -30.0, 0.4, 0.9, 0.3, 0.6)
			pm.particle_flag_align_y = true
			pm.scale_curve = FX._shrink_curve()
			FX._emit(target + Vector3(0, 0.5, 0), 30, 0.9, RageFX.spark_mesh(st["spark"]), pm)
		on_land.call()
		root.queue_free())


## A small glowing chunk (shard, ball lightning, bouncing rock, flare) that
## arcs from `from` to `to`, then calls `on_land`.
static func lob(from: Vector3, to: Vector3, st: Dictionary, size: float, time: float, height: float, on_land: Callable) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = from
	var s := SphereMesh.new()
	s.radius = 0.5 * size
	s.height = 1.0 * size
	s.radial_segments = 6
	s.rings = 3
	RageFX._mesh(root, s, RageFX.glow_mat(Color(st["core"], 1.0)))
	var g := SphereMesh.new()
	g.radius = 1.0 * size
	g.height = 2.0 * size
	RageFX._mesh(root, g, RageFX.glow_mat(Color(st["glow"], 0.35)))
	var tw := root.create_tween()
	tw.tween_method(func(k: float) -> void:
		root.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * height, 0), 0.0, 1.0, time)
	tw.tween_callback(func() -> void:
		RageFX.pop(to + Vector3(0, 0.4, 0), st, 0.8 * size + 0.4)
		on_land.call()
		root.queue_free())


## A glowing ring on the street that warns where something huge will land
## within `time`.
static func target_ring(pos: Vector3, radius: float, st: Dictionary, time: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.5
	t.outer_radius = radius
	t.rings = 48
	t.ring_segments = 4
	var mat := RageFX.glow_mat(Color(st["glow"], 0.0))
	var mi := RageFX._mesh(w, t, mat)
	mi.global_position = Vector3(pos.x, 0.15, pos.z)
	mi.scale = Vector3(1.6, 0.05, 1.6)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.0, 0.05, 1.0), time)
	tw.tween_property(mat, "albedo_color:a", 0.85, time)
	tw.chain().tween_callback(mi.queue_free)


## SINGULARITY: a black hole forms ahead of the hero, a swirling disc of
## purple matter is pulled into it, and it blows up at the end.
static func singularity(center: Vector3, st: Dictionary, pull_time: float, size := 1.0, drift := Vector3.ZERO) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = center
	var core := SphereMesh.new()
	core.radius = 1.6
	core.height = 3.2
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.01, 0.0, 0.02)
	var hole := RageFX._mesh(root, core, black)
	var halo := SphereMesh.new()
	halo.radius = 2.4
	halo.height = 4.8
	var halo_mat := RageFX.glow_mat(Color(0.85, 0.4, 1.0, 0.5))
	halo_mat.rim_enabled = true
	RageFX._mesh(root, halo, halo_mat)
	# Accretion disc: tilted rings spinning round the hole.
	var disc := Node3D.new()
	root.add_child(disc)
	disc.rotation.x = 0.35
	for r in [[4.0, 0.5, Color(1.0, 0.7, 1.0, 0.9)], [5.5, 0.7, Color(0.7, 0.3, 1.0, 0.6)], [7.2, 0.6, Color(0.4, 0.1, 0.7, 0.4)]]:
		var t := TorusMesh.new()
		t.inner_radius = r[0] - r[1]
		t.outer_radius = r[0]
		t.rings = 48
		t.ring_segments = 6
		var mi := RageFX._mesh(disc, t, RageFX.glow_mat(r[2]))
		mi.scale.y = 0.15
	# Matter spiralling in.
	var pm := FX._pm(Vector3.UP, 180.0, 0.0, 0.0, 0.0, 0.6, 1.4, 0.0, 10.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0.35).normalized()
	pm.emission_ring_radius = 10.0
	pm.emission_ring_inner_radius = 6.0
	pm.emission_ring_height = 1.0
	pm.radial_accel_min = -30.0
	pm.radial_accel_max = -20.0
	pm.tangential_accel_min = 40.0
	pm.tangential_accel_max = 55.0
	pm.color_ramp = FX._ramp([Color(0.6, 0.2, 1.0, 0.0), Color(0.9, 0.5, 1.0, 1.0), Color(1.0, 0.85, 1.0, 0.0)])
	pm.scale_curve = FX._shrink_curve()
	var p := FX._stream_part(140, 0.7, pm, RageFX._soft(false), AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40)))
	p.fixed_fps = 0
	root.add_child(p)
	root.scale = Vector3.ONE * 0.1
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * size, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(disc, "rotation:y", TAU * 4.0, pull_time)
	tw.parallel().tween_property(hole, "scale", Vector3.ONE * 1.4, pull_time)
	if drift != Vector3.ZERO:
		tw.parallel().tween_property(root, "global_position", center + drift, pull_time)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		FX.stop_stream(p)
		root.queue_free())


## TECTONIC RIFT: a glowing crack splits the street and crystal spikes
## burst out of it.
static func rift_step(p: Vector3, st: Dictionary) -> void:
	RageFX._ground_patch(p, Color(0.06, 0.05, 0.04, 0.9), false, 1.4, 1.8)
	var crack := RageFX.glow_mat(Color(st["glow"].lightened(0.3), 0.9))
	var w := FX._world()
	if w:
		var b := BoxMesh.new()
		b.size = Vector3(3.6, 0.05, 0.35)
		var mi := RageFX._mesh(w, b, crack)
		mi.global_position = Vector3(p.x, 0.12, p.z + randf_range(-0.3, 0.3))
		mi.rotation.y = randf_range(-0.4, 0.4)
		var tw := mi.create_tween()
		tw.tween_interval(1.4)
		tw.tween_property(crack, "albedo_color:a", 0.0, 0.6)
		tw.tween_callback(mi.queue_free)
	RageFX.spike(Vector3(p.x, 0, p.z + randf_range(-1.2, 1.2)), st, randf_range(1.2, 1.7))


## ABSOLUTE ZERO: frost spreads over the street and every enemy is encased
## in a block of ice (returned so shatter() can break them).
static func freeze_wave(pos: Vector3, radius: float, st: Dictionary) -> void:
	for i in 10:
		var x := pos.x + randf_range(-radius, radius)
		RageFX.ground(Vector3(x, 0, pos.z + randf_range(-3.0, 2.0)), st, randf_range(1.4, 2.2), 2.4)
	FX.shockwave(pos, radius, Color(0.75, 0.95, 1.0))
	var pm := FX._pm(Vector3.UP, 180.0, 6.0, 16.0, -2.0, 1.5, 3.0, 2.0, 2.0)
	pm.color_ramp = FX._ramp([Color(1, 1, 1, 0.0), Color(0.85, 0.95, 1.0, 0.8), Color(0.7, 0.85, 1.0, 0.0)])
	pm.scale_curve = FX._grow_curve()
	FX._emit(pos + Vector3(0, 2, 0), 50, 1.2, RageFX._soft(false), pm)


static func encase(target: Node3D, size: float) -> Node3D:
	var w := FX._world()
	if w == null or not is_instance_valid(target):
		return null
	var root := Node3D.new()
	w.add_child(root)
	var c: Vector3 = target.hit_center() if target.has_method("hit_center") else target.global_position
	root.global_position = c
	var mat := RageFX._ice_mat()
	var b := BoxMesh.new()
	b.size = Vector3(2.4, 3.0, 2.4) * size
	var block := RageFX._mesh(root, b, mat)
	block.rotation = Vector3(0.1, 0.4, -0.08)
	for i in 5:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = 0.4 * size
		cyl.height = randf_range(1.4, 2.4) * size
		cyl.radial_segments = 4
		cyl.rings = 1
		var mi := RageFX._mesh(root, cyl, mat)
		var a := randf() * TAU
		mi.position = Vector3(cos(a) * 1.2, randf_range(-0.5, 1.4), sin(a) * 1.2) * size
		mi.rotation = Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)
	root.scale = Vector3.ONE * 0.2
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


## Ice blocks burst into shards.
static func shatter(block: Node3D) -> void:
	if block == null or not is_instance_valid(block):
		return
	var pos := block.global_position
	var pm := FX._pm(Vector3.UP, 120.0, 8.0, 20.0, -30.0, 0.5, 1.4, 0.0, 1.2)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	var shard := CylinderMesh.new()
	shard.top_radius = 0.0
	shard.bottom_radius = 0.25
	shard.height = 0.9
	shard.radial_segments = 4
	shard.rings = 1
	shard.material = RageFX._ice_mat()
	FX._emit(pos, 26, 1.2, shard, pm)
	FX.light_flash(pos, Color(0.7, 0.95, 1.0), 8.0, 12.0, 0.3)
	block.queue_free()


## SHADOW FRENZY: a dark afterimage where the hero was and a red slash
## across the enemy it strikes.
static func slash(from: Vector3, at: Vector3, side: float, st: Dictionary) -> void:
	FX.smoke(from + Vector3(0, 2.5, 0), 1.0, Color(0.08, 0.02, 0.06))
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = at
	root.rotation.z = randf_range(-0.9, 0.9)
	var mat := RageFX.glow_mat(Color(st["core"], 1.0))
	var mi := RageFX._mesh(root, Fireball._crescent(3.2, 0.5), mat)
	mi.scale.x = side
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "scale", Vector3(1.5, 1.2, 1.0), 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)
	var pm := FX._pm(Vector3(side, 0.3, 0), 50.0, 6.0, 14.0, -10.0, 0.4, 0.9, 0.5, 0.6)
	pm.particle_flag_align_y = true
	pm.scale_curve = FX._shrink_curve()
	FX._emit(at, 16, 0.6, RageFX.spark_mesh(st["spark"]), pm)


## TIDAL WAVE: a wall of water with a foaming crest rolls along the street.
## It rises during `delay`, then rolls `travel` along the street in `duration`.
static func tidal_wave(start: Vector3, facing: float, travel: float, duration: float, delay: float, size := 1.0) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = Vector3(start.x, 0.0, start.z)
	var water := StandardMaterial3D.new()
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(0.1, 0.5, 0.6, 0.75)
	water.roughness = 0.05
	water.metallic_specular = 1.0
	water.rim_enabled = true
	water.rim = 0.6
	water.emission_enabled = true
	water.emission = Color(0.05, 0.3, 0.35)
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A curling wall: stacked slabs leaning forward more towards the top.
	for i in 6:
		var k := float(i) / 5.0
		var b := BoxMesh.new()
		b.size = Vector3(2.2 - k * 0.8, 1.6, 12.0)
		var mi := RageFX._mesh(root, b, water)
		mi.position = Vector3(facing * (k * k * 2.4), 0.8 + i * 1.4, -1.5)
		mi.rotation.z = -facing * k * 0.7
	var foam := FX._pm(Vector3(facing, 1.0, 0), 50.0, 4.0, 10.0, -18.0, 1.0, 2.2, 0.8, 1.0)
	foam.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	foam.emission_box_extents = Vector3(0.6, 0.3, 6.0)
	foam.color_ramp = FX._ramp([Color(1, 1, 1, 0.95), Color(0.85, 0.97, 1.0, 0.7), Color(0.7, 0.9, 1.0, 0.0)])
	foam.scale_curve = FX._grow_curve()
	var crest := FX._stream_part(160, 0.7, foam, RageFX._soft(false), AABB(Vector3(-40, -10, -20), Vector3(80, 40, 40)))
	crest.position = Vector3(facing * 2.4, 8.4, -1.5)
	root.add_child(crest)
	var base := FX._pm(Vector3(facing, 0.6, 0), 40.0, 6.0, 12.0, -14.0, 1.4, 2.6, 0.8, 1.0)
	base.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	base.emission_box_extents = Vector3(1.0, 0.3, 6.0)
	base.color_ramp = foam.color_ramp
	base.scale_curve = FX._grow_curve()
	var spray := FX._stream_part(120, 0.6, base, RageFX._soft(false), crest.visibility_aabb)
	spray.position = Vector3(facing * 1.0, 0.4, -1.0)
	root.add_child(spray)
	root.scale = Vector3(size, 0.1, 1.0)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(size, size, 1.0), delay).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "global_position:x", start.x + facing * travel, duration)
	tw.tween_property(root, "scale", Vector3(size, 0.05, 1.0), 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(water, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		FX.stop_stream(crest)
		FX.stop_stream(spray)
		root.queue_free())


## SUPERNOVA: a sun swells over the hero's head, flaring with every blast.
static func sun(pos: Vector3, st: Dictionary, duration: float) -> void:
	var w := FX._world()
	if w == null:
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = pos + Vector3(0, 11.0, 0)
	var g: Color = st["glow"]
	for layer in [[1.6, RageFX.glow_mat(Color(g.lightened(0.5), 1.0))], [2.6, RageFX.glow_mat(Color(g, 0.45))], [4.0, RageFX.glow_mat(Color(g, 0.15))]]:
		var s := SphereMesh.new()
		s.radius = layer[0]
		s.height = layer[0] * 2.0
		RageFX._mesh(root, s, layer[1])
	var rays := Node3D.new()
	root.add_child(rays)
	var ray_mat := RageFX.glow_mat(Color(g.lightened(0.3), 0.45))
	for i in 6:
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 16.0)
		var mi := RageFX._mesh(rays, q, ray_mat)
		mi.rotation.z = i * PI / 6
	var l := OmniLight3D.new()
	l.light_color = g
	l.light_energy = 4.0
	l.omni_range = 30.0
	root.add_child(l)
	root.scale = Vector3.ONE * 0.1
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rays, "rotation:z", PI, duration)
	tw.tween_property(root, "scale", Vector3.ONE * 2.2, 0.25)
	tw.parallel().tween_property(ray_mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(root.queue_free)


## One SUPERNOVA blast: a ring of solar fire racing out over the street.
static func nova_blast(pos: Vector3, radius: float, st: Dictionary) -> void:
	FX.shockwave(pos, radius, st["glow"])
	FX.shockwave(pos, radius * 0.6, st["glow"].lightened(0.5))
	var pm := FX._pm(Vector3.UP, 15.0, 0.0, 2.0, 2.0, 2.0, 3.6, 0.0, radius * 0.9)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius * 0.9
	pm.emission_ring_inner_radius = radius * 0.5
	pm.emission_ring_height = 0.5
	pm.color_ramp = RageFX.ramp(st)
	pm.scale_curve = FX._grow_curve()
	FX._emit(Vector3(pos.x, 0.8, pos.z), 90, 0.8, RageFX._soft(false), pm)
	RageFX._flare(pos + Vector3(0, 11.0, 0), st, 3.0)
