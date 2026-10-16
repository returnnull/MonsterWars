class_name Fireball
extends Node3D
## The shot a raging kaiju spits with a light attack (see
## Player._spit_fireball). Each hero's shot looks and flies like its element
## (RageStyle "shot" and "move"): it flies straight ahead and dips from the
## mouth down to body height, or is lobbed in an arc onto the street, or
## (pierce) cuts through every enemy in a row. It trails its element and
## bursts on the first enemy or building it touches, or at the end of its
## range. The burst hurts everything inside `splash` and puts the hero's
## rage effect on it (Player._rage_effect).

const SPEED := 34.0
const RANGE := 30.0
## Height above the ground it settles at, so it also hits small enemies.
const CRUISE_Y := 2.6
## Lobbed shots: speed along the street, launch speed up, gravity.
const LOB_SPEED := 27.0
const LOB_UP := 9.0
const LOB_GRAVITY := 30.0

var shooter: Player
var style: Dictionary = RageStyle.STYLES[2]
var dir := 1.0
var damage := 8.0
var splash := 2.6
var size := 1.0
var _flown := 0.0
var _vy := 0.0
var _trail: GPUParticles3D
var _light: OmniLight3D
var _body: Node3D
var _spin: Node3D
var _glow: Node3D
var _arcs: Array = []
var _pierced: Array = []
var _t := 0.0


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_build(String(style["shot"]))
	_light = OmniLight3D.new()
	_light.light_color = style["glow"]
	_light.light_energy = 3.0 * size
	_light.omni_range = 7.0 * size
	add_child(_light)
	if style["move"] == "lob":
		_vy = LOB_UP
	_trail = RageFX.trail(style, size, dir)
	if _trail:
		_trail.global_position = global_position


## Builds the shot's body for its kind of shot.
func _build(kind: String) -> void:
	var core: Color = style["core"]
	var shell: Color = style["shell"]
	var glow: Color = style["glow"]
	var s := size
	match kind:
		"orb":
			# Atomic orb: white-hot core in a blue shell, two electron rings.
			_ball(0.5 * s, RageFX.glow_mat(core))
			_ball(0.85 * s, RageFX.glow_mat(Color(glow, 0.6)))
			_glow = _ball(1.3 * s, RageFX.glow_mat(shell))
			_spin = Node3D.new()
			_body.add_child(_spin)
			for i in 2:
				var t := TorusMesh.new()
				t.inner_radius = 1.35 * s
				t.outer_radius = 1.5 * s
				t.rings = 24
				t.ring_segments = 4
				var mi := RageFX._mesh(_spin, t, RageFX.glow_mat(Color(core, 1.0)))
				mi.rotation = Vector3(PI * 0.5 + i * 0.9, i * 1.2, 0.4)
		"ball":
			# Ball lightning: a fizzing white ball with arcs crackling round it.
			_ball(0.45 * s, RageFX.glow_mat(core))
			_glow = _ball(1.1 * s, RageFX.glow_mat(Color(glow, 0.35)))
			var arc_mat := RageFX.glow_mat(Color(core, 1.0))
			for i in 5:
				var b := BoxMesh.new()
				b.size = Vector3(0.08, 1.6 * s, 0.08)
				var mi := RageFX._mesh(_body, b, arc_mat)
				_arcs.append(mi)
		"glob":
			# Lava glob: a dark, cracked crust round a glowing molten heart.
			_ball(0.6 * s, RageFX.glow_mat(core))
			var crust := StandardMaterial3D.new()
			crust.albedo_color = Color(0.12, 0.05, 0.03)
			crust.roughness = 0.9
			crust.emission_enabled = true
			crust.emission = Color(1.0, 0.3, 0.05)
			crust.emission_energy_multiplier = 1.4
			_spin = _ball(0.95 * s, crust, 6, 4)
			_glow = _ball(1.35 * s, RageFX.glow_mat(shell))
		"venom":
			# Venom orb: green poison sloshing inside a purple bubble skin.
			_ball(0.55 * s, RageFX.glow_mat(core))
			var skin := StandardMaterial3D.new()
			skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			skin.albedo_color = shell
			skin.roughness = 0.1
			skin.rim_enabled = true
			skin.rim = 1.0
			skin.emission_enabled = true
			skin.emission = Color(0.5, 0.2, 0.8)
			_glow = _ball(1.15 * s, skin)
		"rock":
			# A boulder torn from the street, studded with glowing crystals.
			var rock := StandardMaterial3D.new()
			rock.albedo_color = Color(0.4, 0.36, 0.3)
			rock.roughness = 0.95
			_spin = _ball(1.05 * s, rock, 6, 3)
			var crystal := StandardMaterial3D.new()
			crystal.albedo_color = Color(0.4, 1.0, 0.35)
			crystal.emission_enabled = true
			crystal.emission = glow
			crystal.emission_energy_multiplier = 0.9
			for i in 4:
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.28 * s
				c.height = 1.1 * s
				c.radial_segments = 4
				c.rings = 1
				var mi := RageFX._mesh(_spin, c, crystal)
				var a := i * TAU / 4.0 + 0.4
				mi.position = Vector3(cos(a), sin(a), 0.3 * (i % 2)) * 0.95 * s
				mi.rotation.z = a - PI / 2
		"shard":
			# A volley of three ice spikes, points first.
			var ice := RageFX._ice_mat()
			for off in [Vector3(0, 0, 0), Vector3(-0.9, 0.55, 0.35), Vector3(-0.7, -0.5, -0.35)]:
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.32 * s
				c.height = 2.2 * s
				c.radial_segments = 5
				c.rings = 1
				var mi := RageFX._mesh(_body, c, ice)
				mi.position = off * s * Vector3(dir, 1, 1)
				mi.rotation.z = -PI / 2 * dir
			_glow = _ball(0.9 * s, RageFX.glow_mat(Color(glow, 0.25)))
		"crescent":
			# A shadow blade: a dark crescent with a blood-red edge.
			_spin = Node3D.new()
			_body.add_child(_spin)
			RageFX._mesh(_spin, _crescent(2.0 * s, 0.55 * s), RageFX.glow_mat(Color(core, 1.0)))
			var dark := RageFX._mesh(_spin, _crescent(1.75 * s, 0.4 * s), RageFX.glow_mat(Color(0.05, 0.0, 0.02, 0.9)))
			dark.position = Vector3(-0.12 * s, 0, 0.05)
			_spin.scale.x = dir
		"bubble":
			# A wobbling bubble with a glowing teal heart.
			_ball(0.35 * s, RageFX.glow_mat(core))
			var skin := StandardMaterial3D.new()
			skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			skin.albedo_color = shell
			skin.roughness = 0.0
			skin.metallic_specular = 1.0
			skin.rim_enabled = true
			skin.rim = 1.0
			skin.rim_tint = 0.2
			skin.emission_enabled = true
			skin.emission = Color(0.1, 0.4, 0.4)
			_glow = _ball(1.2 * s, skin, 20, 10)
		"sun":
			# A tiny sun: blinding core, a corona and spinning flares.
			_ball(0.6 * s, RageFX.glow_mat(core))
			_glow = _ball(1.2 * s, RageFX.glow_mat(Color(glow, 0.55)))
			_ball(1.7 * s, RageFX.glow_mat(Color(glow, 0.18)))
			_spin = Node3D.new()
			_body.add_child(_spin)
			var ray_mat := RageFX.glow_mat(Color(glow.lightened(0.4), 0.8))
			for i in 4:
				var q := QuadMesh.new()
				q.size = Vector2(0.2, 3.6) * s
				var mi := RageFX._mesh(_spin, q, ray_mat)
				mi.rotation.z = i * PI / 4
		"scrap":
			# A red-hot hex nut spinning end over end.
			var metal := StandardMaterial3D.new()
			metal.albedo_color = Color(0.45, 0.32, 0.25)
			metal.metallic = 0.9
			metal.roughness = 0.35
			metal.emission_enabled = true
			metal.emission = Color(1.0, 0.35, 0.08)
			metal.emission_energy_multiplier = 1.6
			var nut := CylinderMesh.new()
			nut.top_radius = 0.7 * s
			nut.bottom_radius = 0.7 * s
			nut.height = 0.4 * s
			nut.radial_segments = 6
			nut.rings = 1
			_spin = Node3D.new()
			_body.add_child(_spin)
			var mi := RageFX._mesh(_spin, nut, metal)
			mi.rotation.x = PI / 2
			_glow = _ball(0.9 * s, RageFX.glow_mat(Color(1.0, 0.45, 0.1, 0.3)))


func _ball(r: float, mat: Material, segs := 16, rings := 8) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings
	return RageFX._mesh(_body, s, mat)


## A flat crescent facing the camera, its curve pointing ahead (+x).
static func _crescent(r: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var a0 := lerpf(-1.25, 1.25, float(i) / n)
		var a1 := lerpf(-1.25, 1.25, float(i + 1) / n)
		# Thickest in the middle, sharp at the tips.
		var t0 := thick * cos(a0 / 1.25 * PI * 0.5)
		var t1 := thick * cos(a1 / 1.25 * PI * 0.5)
		var o0 := Vector3(cos(a0), sin(a0), 0) * r
		var o1 := Vector3(cos(a1), sin(a1), 0) * r
		var i0 := Vector3(cos(a0), sin(a0), 0) * (r - t0)
		var i1 := Vector3(cos(a1), sin(a1), 0) * (r - t1)
		for v in [o0, i0, o1, o1, i0, i1]:
			st.add_vertex(v - Vector3(r * 0.7, 0, 0))
	return st.commit()


func _physics_process(delta: float) -> void:
	_t += delta
	var lob: bool = style["move"] == "lob"
	var step := (LOB_SPEED if lob else SPEED) * delta
	_flown += step
	global_position.x += dir * step
	if lob:
		_vy -= LOB_GRAVITY * delta
		global_position.y += _vy * delta
	else:
		global_position.y = move_toward(global_position.y, CRUISE_Y + size * 0.4, 9.0 * delta)
	_animate()
	if _trail and is_instance_valid(_trail):
		_trail.global_position = global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e in _pierced:
			continue
		var d: Vector3 = e.hit_center() - global_position
		var r: float = e.hit_radius
		if absf(d.x) < r + 0.9 * size and absf(d.z) < r + 1.6 and absf(d.y) < r + 2.6:
			if style["move"] == "pierce":
				# Cuts through and keeps going; each enemy is hit once.
				_pierced.append(e)
				_hit_one(e)
				continue
			_burst()
			return
	for b in get_tree().get_nodes_in_group("buildings"):
		if not b.destroyed and b._aabb().grow(0.8 * size).has_point(global_position):
			_burst()
			return
	if _flown >= RANGE or (lob and global_position.y <= 0.4):
		_burst()


func _animate() -> void:
	var flicker := 1.0 + sin(_t * 47.0) * 0.1 + sin(_t * 23.0) * 0.06
	_light.light_energy = 3.0 * size * flicker
	if _glow:
		_glow.scale = Vector3(1.3, 0.9, 0.9) * flicker
	match String(style["shot"]):
		"orb":
			_spin.rotation.y += 0.35
			_spin.rotation.x += 0.2
		"glob", "rock":
			_spin.rotation.z -= 0.25 * dir
			_spin.rotation.x += 0.1
		"crescent":
			_body.rotation.z = sin(_t * 30.0) * 0.08
		"bubble":
			_glow.scale = Vector3(1.0 + sin(_t * 18.0) * 0.12, 1.0 - sin(_t * 18.0) * 0.1, 1.0)
		"sun":
			_spin.rotation.z += 0.12
		"scrap":
			_spin.rotation.z -= 0.6 * dir
		"ball":
			# Fresh arcs every couple of frames.
			if Engine.get_physics_frames() % 2 == 0:
				for a in _arcs:
					a.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
					a.position = Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)) * size


## A piercing shot cuts one enemy on its way through.
func _hit_one(e: Node) -> void:
	if not is_instance_valid(shooter):
		return
	var kb := Vector3(dir * 7.0, 5.0, 0)
	if shooter.deal(e, damage, kb):
		Game.register_hit()
		FX.hit_spark(e.hit_center(), damage)
		shooter._rage_effect(e, damage, false)
		RageFX.pop(e.hit_center(), style, size * 0.7)
		Player.rage_shake(0.08)


## The shot bursts where it lands: hurts and wrecks what is close by and
## puts the hero's rage effect on it. Rage never feeds rage back (see
## Player._do_hit).
func _burst() -> void:
	var pos := global_position
	var r := splash
	var hits := 0
	if is_instance_valid(shooter):
		var kb := Vector3(dir * 7.0, 5.0, 0)
		match String(style["effect"]):
			"push":
				kb = Vector3(dir * 18.0, 4.0, 0)
			"quake":
				kb = Vector3(dir * 8.0, 13.0, 0)
		var bmul := 2.0 if style["effect"] in ["quake", "shred"] else 1.0
		var targets: Array = get_tree().get_nodes_in_group("enemies").filter(func(t) -> bool:
			return not t.dead and t.hit_center().distance_to(pos) <= r + t.hit_radius)
		hits = shooter.strike(pos, r, damage, kb, "enemies", damage * shooter._bdmg() * bmul)
		for t in targets:
			shooter._rage_effect(t, damage, false)
		if style["effect"] == "shock" and not targets.is_empty():
			shooter._chain_shock(targets[0], damage * 0.5, targets)
		if hits > 0:
			shooter.rumble(0.2, 0.25 * size, 0.08)
	for i in hits:
		Game.register_hit()
	RageFX.pop(pos, style, size)
	if size > 1.2 or style["move"] == "lob":
		# The big third shot (and every lobbed one) marks the street.
		RageFX.ground(pos, style, 1.2 if size > 1.2 else 0.8, 1.0)
	if size > 1.2:
		RageFX.burst(pos, r, style)
	Player.rage_shake(0.1 * size + (0.1 if hits > 0 else 0.0))
	FX.stop_stream(_trail)
	queue_free()
