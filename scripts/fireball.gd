class_name Fireball
extends Node3D
## The shot a raging kaiju makes with a light attack (see
## Player._spit_fireball). Every hero's shot has its own look (RageStyle
## "shot") and, above all, its own way of moving and hitting (RageStyle
## "move"), so no two heroes' light attacks play alike:
##
##   ring      GORRAX: an atomic ring that grows as it flies and cuts through
##             everything it passes
##   lob/pool  MAGMOS: a glob of lava lobbed onto the street that leaves a
##             pool of lava burning whatever stands in it
##   lash      SYLVARA: a thorny vine whips out from the mouth, poisons the
##             whole row and drags it back towards her
##   roll      TERRAXA: a boulder thrown down that rolls along the street,
##             bowling enemies over into the air
##   drop      GLACIOR: an icicle falls from the sky onto the closest enemy
##             ahead (three on the big third shot)
##   boomerang NOCTYR: a shadow blade that flies out and comes back, cutting
##             on the way out and on the way home
##   wave      CORALIS: a wave rolling along the street that washes the whole
##             row away
##   homing    SOLAR REX: a little sun that seeks out an enemy, also in the air
##   burst     RUSTFANG: a rattling burst of red-hot rivets
##   straight  flies straight ahead and bursts on the first thing it touches
##
## VOLTRA's chain lightning is instant and has no shot (Player._spit_bolt).
## A burst hurts everything inside `splash` and puts the hero's rage effect
## on it (Player._rage_effect); cutting moves hit each enemy once.

const SPEED := 34.0
const RANGE := 30.0
## Height above the ground it settles at, so it also hits small enemies.
const CRUISE_Y := 2.6
## Lobbed shots: speed along the street, launch speed up, gravity.
const LOB_SPEED := 27.0
const LOB_UP := 9.0
const LOB_GRAVITY := 30.0
## Atom ring: speed and how much bigger it is at the end of its range.
const RING_SPEED := 30.0
const RING_GROW := 1.6
## Lava pool: how long it burns and how often it hurts.
const POOL_TIME := 3.0
const POOL_TICK := 0.4
## Vine lash: full length, how fast it shoots out and is pulled back.
const LASH_LEN := 17.0
const LASH_OUT := 95.0
const LASH_BACK := 70.0
## Rolling boulder: speed on the street and how far it rolls.
const ROLL_SPEED := 23.0
const ROLL_RANGE := 30.0
## Icicle: fall speed at the start and gravity.
const DROP_VEL := 10.0
const DROP_GRAVITY := 70.0
## Shadow blade: how far it flies out before it turns, how fast it returns.
const BOOMERANG_OUT := 17.0
const BOOMERANG_BACK := 38.0
## Wave: speed and how far it rolls.
const WAVE_SPEED := 25.0
const WAVE_RANGE := 26.0
## Seeking sun: speed, how hard it turns, how long it looks for a target.
const HOMING_SPEED := 24.0
const HOMING_TURN := 5.0
const HOMING_RANGE := 36.0
## Rivets: speed.
const RIVET_SPEED := 52.0

var shooter: Player
var style: Dictionary = RageStyle.STYLES[2]
var dir := 1.0
var damage := 8.0
var splash := 2.6
var size := 1.0
## Rivets in a burst wait this long at the mouth before they fly.
var delay := 0.0
## Set by the player for an icicle: what it falls on.
var target: Node3D
var _move := "straight"
var _flown := 0.0
var _vy := 0.0
var _vel := Vector3.ZERO
var _trail: GPUParticles3D
var _light: OmniLight3D
var _body: Node3D
var _spin: Node3D
var _glow: Node3D
var _segs: Array = []
var _pierced: Array = []
var _hit_buildings: Array = []
var _t := 0.0
## 0: on its way. lash: 1 = pulled back. roll: 1 = rolling. boomerang:
## 1 = coming back. pool: 1 = a burning pool on the street.
var _phase := 0
var _len := 0.0
var _pool_t := 0.0


func _ready() -> void:
	_move = String(style["move"])
	_body = Node3D.new()
	add_child(_body)
	_build(String(style["shot"]))
	_light = OmniLight3D.new()
	_light.light_color = style["glow"]
	_light.light_energy = 3.0 * size
	_light.omni_range = 7.0 * size
	add_child(_light)
	match _move:
		"lob", "pool":
			_vy = LOB_UP
		"roll":
			_vy = 5.0
		"drop":
			_vy = -DROP_VEL
		"homing":
			_vel = Vector3(dir, 0.25, 0).normalized() * HOMING_SPEED
		"burst":
			_vel = Vector3(dir, randf_range(-0.05, 0.03), randf_range(-0.04, 0.04)).normalized() * RIVET_SPEED
	if delay > 0.0:
		visible = false
	elif _move != "lash" and _move != "burst":
		_start_trail()
	if _move == "drop":
		# Frost on the street shows where the icicle will come down.
		RageFX.ground(Vector3(global_position.x, 0.1, global_position.z), style, 0.8 * size, 0.8)


func _start_trail() -> void:
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
		"ring":
			# Atom ring: a bright ring of energy facing ahead (turned towards
			# the camera so it reads as a ring), a glowing sleeve round it and
			# an atom in the middle.
			_spin = Node3D.new()
			_body.add_child(_spin)
			var axis := Vector3(dir, 0, 0.8).normalized()
			_spin.basis = Basis(Quaternion(Vector3.UP, axis))
			for layer in [[1.3, 1.5, Color(glow.lightened(0.45), 1.0)], [1.1, 1.75, Color(glow, 0.3)]]:
				var t := TorusMesh.new()
				t.inner_radius = layer[0] * s
				t.outer_radius = layer[1] * s
				t.rings = 32
				t.ring_segments = 8
				RageFX._mesh(_spin, t, RageFX.glow_mat(layer[2]))
			_ball(0.3 * s, RageFX.glow_mat(Color(glow.lightened(0.5), 1.0)))
			_glow = _ball(0.55 * s, RageFX.glow_mat(Color(glow, 0.35)))
		"vine":
			# A thorny vine: green segments with purple thorns and a venom bulb
			# at the tip. Laid out along the lash every frame (_lay_vine).
			var vine := StandardMaterial3D.new()
			vine.albedo_color = Color(0.2, 0.42, 0.12)
			vine.roughness = 0.7
			vine.emission_enabled = true
			vine.emission = Color(0.35, 0.9, 0.2)
			vine.emission_energy_multiplier = 0.5
			var thorn := RageFX.glow_mat(Color(shell, 1.0))
			for i in 14:
				var seg := Node3D.new()
				_body.add_child(seg)
				var c := CylinderMesh.new()
				c.top_radius = 0.24 * s * (1.0 - i / 20.0)
				c.bottom_radius = 0.3 * s * (1.0 - i / 20.0)
				c.height = 1.6 * s
				c.radial_segments = 6
				c.rings = 1
				RageFX._mesh(seg, c, vine).rotation.z = PI / 2
				var th := CylinderMesh.new()
				th.top_radius = 0.0
				th.bottom_radius = 0.12 * s
				th.height = 0.6 * s
				th.radial_segments = 4
				th.rings = 1
				var mi := RageFX._mesh(seg, th, thorn)
				mi.position.y = 0.3 * s * (1 if i % 2 == 0 else -1)
				mi.rotation.z = 0.0 if i % 2 == 0 else PI
				_segs.append(seg)
			_glow = _ball(0.55 * s, RageFX.glow_mat(core))
		"icicle":
			# A huge icicle, point down, with a cold glow round it.
			var ice := RageFX._ice_mat()
			var c := CylinderMesh.new()
			c.top_radius = 0.75 * s
			c.bottom_radius = 0.0
			c.height = 4.2 * s
			c.radial_segments = 6
			c.rings = 1
			RageFX._mesh(_body, c, ice).position.y = 1.4 * s
			for i in 3:
				var sc := CylinderMesh.new()
				sc.top_radius = 0.35 * s
				sc.bottom_radius = 0.0
				sc.height = 2.0 * s
				sc.radial_segments = 5
				sc.rings = 1
				var mi := RageFX._mesh(_body, sc, ice)
				var a := i * TAU / 3.0
				mi.position = Vector3(cos(a) * 0.55, 2.4, sin(a) * 0.55) * s
				mi.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
			_glow = _ball(1.2 * s, RageFX.glow_mat(Color(glow, 0.22)))
		"wave":
			# A curling wall of water across the street with a foaming crest.
			var water := StandardMaterial3D.new()
			water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			water.albedo_color = Color(0.15, 0.6, 0.75, 0.7)
			water.roughness = 0.05
			water.metallic_specular = 1.0
			water.rim_enabled = true
			water.rim = 1.0
			water.emission_enabled = true
			water.emission = Color(0.05, 0.45, 0.5)
			var foam := RageFX.glow_mat(Color(0.9, 1.0, 1.0, 0.9))
			_spin = Node3D.new()
			_body.add_child(_spin)
			# The wave's side view, from its low back to the lip curling over
			# in front, pulled across the street.
			var curl := PackedVector2Array([Vector2(-3.0, 0.0), Vector2(-1.6, 1.2), Vector2(-0.4, 2.7), Vector2(0.5, 3.4),
				Vector2(1.3, 3.2), Vector2(1.7, 2.6), Vector2(1.1, 2.6), Vector2(0.7, 2.1), Vector2(0.9, 0.9), Vector2(1.4, 0.0)])
			RageFX._mesh(_spin, _extrude(curl, 5.0, s), water)
			var lip := PackedVector2Array([Vector2(0.2, 3.2), Vector2(0.6, 3.6), Vector2(1.3, 3.5), Vector2(1.9, 2.8), Vector2(1.5, 2.9), Vector2(1.1, 3.25)])
			RageFX._mesh(_spin, _extrude(lip, 5.2, s), foam)
			_spin.scale.x = dir
			_glow = _spin
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
		"crescent":
			# A shadow blade: a dark crescent with a blood-red edge.
			_spin = Node3D.new()
			_body.add_child(_spin)
			RageFX._mesh(_spin, _crescent(2.0 * s, 0.55 * s), RageFX.glow_mat(Color(core, 1.0)))
			var dark := RageFX._mesh(_spin, _crescent(1.75 * s, 0.4 * s), RageFX.glow_mat(Color(0.05, 0.0, 0.02, 0.9)))
			dark.position = Vector3(-0.12 * s, 0, 0.05)
			_spin.scale.x = dir
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
			if _move == "burst":
				# A rivet from the gun leaves a hot tracer streak behind it.
				var tracer := BoxMesh.new()
				tracer.size = Vector3(3.0, 0.14, 0.14) * s * Vector3(1, 1.6, 1.6)
				RageFX._mesh(_body, tracer, RageFX.glow_mat(Color(1.0, 0.6, 0.2, 0.85))).position.x = -dir * 1.6 * s


## A flat side view `pts` (x ahead, y up) pulled `depth` across the street
## into a solid, scaled by `s`.
static func _extrude(pts: PackedVector2Array, depth: float, s: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := depth * 0.5 * s
	var tris := Geometry2D.triangulate_polygon(pts)
	for side in [-1.0, 1.0]:
		for i in range(0, tris.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for k in order:
				var p: Vector2 = pts[tris[i + k]] * s
				st.add_vertex(Vector3(p.x, p.y, z * side))
	for i in pts.size():
		var a: Vector2 = pts[i] * s
		var b: Vector2 = pts[(i + 1) % pts.size()] * s
		for v in [Vector3(a.x, a.y, -z), Vector3(b.x, b.y, -z), Vector3(b.x, b.y, z),
				Vector3(a.x, a.y, -z), Vector3(b.x, b.y, z), Vector3(a.x, a.y, z)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


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
	if delay > 0.0:
		# A rivet still waiting its turn rides along at the mouth.
		delay -= delta
		if is_instance_valid(shooter):
			global_position = shooter.to_global(shooter._mouth_pos()) + Vector3(dir * 0.8, 0, 0)
		if delay <= 0.0:
			visible = true
			RageFX.muzzle(global_position, Vector3(dir, 0, 0), style, 0.5)
		return
	match _move:
		"lash":
			_lash(delta)
		"ring":
			_fly_ring(delta)
		"roll":
			_roll(delta)
		"drop":
			_drop(delta)
		"boomerang":
			_boomerang(delta)
		"wave":
			_wave(delta)
		"homing":
			_homing(delta)
		"burst":
			_fly(delta, _vel * delta)
		_:
			if _phase == 1:
				_pool(delta)
			else:
				_fly_plain(delta)
	if is_instance_valid(self) and not is_queued_for_deletion():
		_animate()
		if _trail and is_instance_valid(_trail):
			_trail.global_position = global_position


## Straight or lobbed: flies until it touches an enemy or a building, or its
## range runs out.
func _fly_plain(delta: float) -> void:
	var lob := _move == "lob" or _move == "pool"
	var step := (LOB_SPEED if lob else SPEED) * delta
	var v := Vector3(dir * step, 0, 0)
	if lob:
		_vy -= LOB_GRAVITY * delta
		v.y = _vy * delta
	else:
		v.y = move_toward(global_position.y, CRUISE_Y + size * 0.4, 9.0 * delta) - global_position.y
	_fly(delta, v)
	if not is_queued_for_deletion() and _phase == 0 and lob and global_position.y <= 0.4:
		_burst()


## Moves by `v` and bursts on the first enemy or building it touches.
func _fly(_delta: float, v: Vector3) -> void:
	global_position += v
	_flown += v.length()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and _touches(e, 0.9 * size, 1.6, 2.6):
			_burst()
			return
	if _in_building():
		_burst()
		return
	if _flown >= (HOMING_RANGE if _move == "homing" else RANGE):
		_burst()


func _touches(e: Node, rx: float, rz: float, ry: float) -> bool:
	var d: Vector3 = e.hit_center() - global_position
	var r: float = e.hit_radius
	return absf(d.x) < r + rx and absf(d.z) < r + rz and absf(d.y) < r + ry


func _in_building() -> bool:
	for b in get_tree().get_nodes_in_group("buildings"):
		if not b.destroyed and b._aabb().grow(0.8 * size).has_point(global_position):
			return true
	return false


## Cutting moves wreck a building they pass through once and keep going.
func _cut_buildings(r: float) -> void:
	if not is_instance_valid(shooter):
		return
	for b in get_tree().get_nodes_in_group("buildings"):
		if not b.destroyed and not b in _hit_buildings and b._aabb().grow(r).has_point(global_position):
			_hit_buildings.append(b)
			if b.try_hit(global_position, r, damage * shooter._bdmg()):
				Game.register_hit()
				RageFX.pop(global_position, style, size * 0.6)


## Hits every enemy the shape touches once (cutting moves).
func _cut(touch: Callable, kb: Vector3) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e in _pierced or not touch.call(e):
			continue
		_pierced.append(e)
		_hit_one(e, kb)


## GORRAX: the ring grows as it flies and cuts through all it passes.
func _fly_ring(delta: float) -> void:
	var step := RING_SPEED * delta
	_flown += step
	global_position.x += dir * step
	global_position.y = move_toward(global_position.y, CRUISE_Y + size * 0.6, 9.0 * delta)
	var grow := 1.0 + _flown / RANGE * RING_GROW
	_body.scale = Vector3.ONE * grow
	var rr := 1.7 * size * grow
	_cut(func(e) -> bool:
		var d: Vector3 = e.hit_center() - global_position
		return absf(d.x) < e.hit_radius + 0.9 and Vector2(d.y, d.z).length() < rr + e.hit_radius,
		Vector3(dir * 6.0, 5.0, 0))
	_cut_buildings(rr)
	if Engine.get_physics_frames() % 6 == 0:
		RageFX._ring(global_position, dir, style)
	if _flown >= RANGE:
		RageFX.pop(global_position, style, size * grow * 0.6)
		_finish()


## MAGMOS: what is left where the glob landed burns for a while.
func _pool(delta: float) -> void:
	_pool_t -= delta
	var before := int((_pool_t + delta) / POOL_TICK)
	if int(_pool_t / POOL_TICK) != before and is_instance_valid(shooter):
		var r := 2.6 * size
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead:
				continue
			var d: Vector3 = e.hit_center() - global_position
			if Vector2(d.x, d.z).length() < r + e.hit_radius and d.y < 4.0 + e.hit_radius:
				if shooter.deal(e, damage * 0.22, Vector3(0, 1.5, 0)):
					Game.register_hit()
					shooter._rage_effect(e, damage, false)
		# Lava spits up out of the pool now and then.
		if randf() < 0.3:
			RageFX.pop(global_position + Vector3(randf_range(-1.2, 1.2), 0.4, randf_range(-0.8, 0.8)) * size, style, 0.4 * size)
		else:
			FX.smoke(global_position + Vector3(0, 0.6, 0), 0.4 * size, Color(0.16, 0.11, 0.09))
	_light.light_energy = 4.0 * size * clampf(_pool_t, 0.0, 1.0)
	if _pool_t <= 0.0:
		queue_free()


## SYLVARA: the vine shoots out from the mouth, hits the whole row once and
## pulls it back towards her as it retracts.
func _lash(delta: float) -> void:
	if not is_instance_valid(shooter):
		queue_free()
		return
	global_position = shooter.to_global(shooter._mouth_pos()) + Vector3(dir * 0.4, 0, 0)
	var full := LASH_LEN * sqrt(size)
	if _phase == 0:
		_len = minf(_len + LASH_OUT * delta, full)
		if _len >= full:
			_phase = 1
			var tip := global_position + Vector3(dir * full, -full * 0.12, 0)
			RageFX.pop(tip, style, size * 0.6)
			RageFX.cloud(tip, style, 0.6 * size)
	else:
		_len -= LASH_BACK * delta
		if _len <= 0.0:
			queue_free()
			return
	var mouth := global_position
	var reach := _len
	_cut(func(e) -> bool:
		var c: Vector3 = e.hit_center()
		var along := (c.x - mouth.x) * dir
		var y := mouth.y - along * 0.12
		return along > -e.hit_radius and along < reach + e.hit_radius \
			and absf(c.z - mouth.z) < e.hit_radius + 1.4 and absf(c.y - y) < e.hit_radius + 2.4,
		Vector3(-dir * 11.0, 5.0, 0))
	_lay_vine()


## Lays the vine's segments along the lash with a whip-like wave in it.
func _lay_vine() -> void:
	var n := _segs.size()
	for i in n:
		var k := (i + 0.5) / n
		var x := _len * k
		var wave := sin(k * 9.0 - _t * 40.0) * 0.5 * size * k * (1.0 - k) * 4.0
		_segs[i].position = Vector3(dir * x, -x * 0.12 + wave, 0)
		_segs[i].rotation.z = -0.12 * dir + cos(k * 9.0 - _t * 40.0) * 0.3 * dir
	_glow.position = Vector3(dir * _len, -_len * 0.12, 0)
	_light.position = _glow.position


## TERRAXA: thrown down onto the street, then it rolls on, bowling over
## every enemy in its way, until it smashes into a building or crumbles.
func _roll(delta: float) -> void:
	var r := 1.05 * size
	if _phase == 0:
		_vy -= 40.0 * delta
		global_position += Vector3(dir * LOB_SPEED * delta, _vy * delta, 0)
		if global_position.y <= r:
			global_position.y = r
			_phase = 1
			FX.dust(Vector3(global_position.x, 0, global_position.z), 1.0 * size)
			FX.shockwave(Vector3(global_position.x, 0.2, global_position.z), 3.0 * size, style["glow"])
			Player.rage_shake(0.12)
	else:
		var step := ROLL_SPEED * delta
		_flown += step
		global_position.x += dir * step
		global_position.y = r + absf(sin(_t * 14.0)) * 0.25
		if Engine.get_physics_frames() % 4 == 0:
			FX.dust(Vector3(global_position.x, 0, global_position.z), 0.5 * size)
		if Engine.get_physics_frames() % 10 == 0:
			RageFX.ground(Vector3(global_position.x, 0.1, global_position.z), style, 0.6, 1.2)
	_cut(func(e) -> bool: return _touches(e, r, 1.4, r + 2.0), Vector3(dir * 8.0, 13.0, 0))
	if _in_building() or _flown >= ROLL_RANGE:
		_burst()


## GLACIOR: the icicle falls from above onto its target and shatters.
func _drop(delta: float) -> void:
	if is_instance_valid(target) and not target.dead:
		global_position.x = move_toward(global_position.x, target.global_position.x, 20.0 * delta)
		global_position.z = move_toward(global_position.z, target.global_position.z, 20.0 * delta)
	_vy -= DROP_GRAVITY * delta
	global_position.y += _vy * delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and _touches(e, 0.9 * size, 1.4, 1.0):
			_burst()
			return
	if global_position.y <= 0.3:
		_burst()


## NOCTYR: the blade flies out, turns and comes home to the hero, cutting
## every enemy once on the way out and once more on the way back.
func _boomerang(delta: float) -> void:
	if _phase == 0:
		var step := SPEED * delta
		_flown += step
		global_position.x += dir * step
		global_position.y = move_toward(global_position.y, CRUISE_Y + size * 0.4, 9.0 * delta)
		if _flown >= BOOMERANG_OUT * sqrt(size):
			_phase = 1
			_pierced.clear()
			_hit_buildings.clear()
			RageFX.pop(global_position, style, size * 0.5)
	else:
		if not is_instance_valid(shooter) or shooter.dead or _t > 3.0:
			_finish()
			return
		var home := shooter.global_position + Vector3(0, 3.5, 0)
		var to := home - global_position
		if to.length() < 2.0:
			RageFX.muzzle(global_position, Vector3(-dir, 0, 0), style, 0.6)
			_finish()
			return
		global_position += to.normalized() * minf(BOOMERANG_BACK * delta, to.length())
	_cut(func(e) -> bool: return _touches(e, 1.2 * size, 1.8, 2.6), Vector3(dir * (7.0 if _phase == 0 else -5.0), 5.0, 0))
	_cut_buildings(1.2 * size)


## CORALIS: a wave rolls along the street, growing as it goes, and carries
## off everything in its way.
func _wave(delta: float) -> void:
	var step := WAVE_SPEED * delta
	_flown += step
	global_position.x += dir * step
	global_position.y = 0.0
	var k := clampf(_flown / WAVE_RANGE, 0.0, 1.0)
	var grow := lerpf(0.7, 1.35, k)
	_body.scale = Vector3(1.0, grow, 1.0)
	var top := 3.6 * size * grow
	_cut(func(e) -> bool:
		var d: Vector3 = e.hit_center() - global_position
		return absf(d.x) < e.hit_radius + 1.5 * size and absf(d.z) < e.hit_radius + 2.6 * size \
			and d.y < top + e.hit_radius,
		Vector3(dir * 18.0, 5.0, 0))
	_cut_buildings(1.5 * size)
	if Engine.get_physics_frames() % 5 == 0:
		RageFX.splash(global_position + Vector3(dir * 0.8, top * 0.8, randf_range(-1.5, 1.5)), style, 0.5 * size)
	if Engine.get_physics_frames() % 8 == 0:
		RageFX.ground(Vector3(global_position.x, 0.1, global_position.z), style, 0.8, 1.4)
	if _flown >= WAVE_RANGE:
		RageFX.splash(global_position + Vector3(0, 1.0, 0), style, 1.2 * size)
		_finish()


## SOLAR REX: the sun curves after the closest enemy ahead, air or ground.
func _homing(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		target = _seek()
	var want := Vector3(dir, 0, 0)
	if target:
		want = (target.hit_center() - global_position).normalized()
	_vel = _vel.lerp(want * HOMING_SPEED, minf(HOMING_TURN * delta, 1.0)).normalized() * HOMING_SPEED
	if target == null:
		_vel.y = move_toward(_vel.y, (CRUISE_Y + size * 0.4 - global_position.y) * 3.0, 40.0 * delta)
	_fly(delta, _vel * delta)
	if not is_queued_for_deletion() and global_position.y <= 0.4:
		_burst()


func _seek() -> Node3D:
	var best: Node3D = null
	var best_d := 30.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d: Vector3 = e.hit_center() - global_position
		# Only what is ahead of it.
		if d.x * signf(_vel.x if _vel.x != 0.0 else dir) < -1.0:
			continue
		if d.length() < best_d:
			best_d = d.length()
			best = e
	return best


func _finish() -> void:
	FX.stop_stream(_trail)
	queue_free()


func _animate() -> void:
	if _move == "pool" and _phase == 1:
		return
	var flicker := 1.0 + sin(_t * 47.0) * 0.1 + sin(_t * 23.0) * 0.06
	_light.light_energy = 3.0 * size * flicker
	if _glow and _glow != _spin:
		_glow.scale = Vector3(1.3, 0.9, 0.9) * flicker
	match String(style["shot"]):
		"ring":
			_spin.rotate_object_local(Vector3.UP, 0.3)
		"icicle":
			_body.rotation.y += 0.15
		"wave":
			_spin.position.y = sin(_t * 12.0) * 0.15
			_spin.scale = Vector3(dir * (1.0 + sin(_t * 9.0) * 0.06), 1.0, 1.0)
		"glob", "rock":
			_spin.rotation.z -= 0.25 * dir
			_spin.rotation.x += 0.1
		"crescent":
			if _move == "boomerang":
				_spin.rotation.z -= 0.55 * dir
			else:
				_body.rotation.z = sin(_t * 30.0) * 0.08
		"sun":
			_spin.rotation.z += 0.12
		"scrap":
			_spin.rotation.z -= 0.6 * dir



## A cutting shot hits one enemy on its way through.
func _hit_one(e: Node, kb: Vector3) -> void:
	if not is_instance_valid(shooter):
		return
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
	var targets: Array = []
	if is_instance_valid(shooter):
		var kb := Vector3(dir * 7.0, 5.0, 0)
		match String(style["effect"]):
			"push":
				kb = Vector3(dir * 18.0, 4.0, 0)
			"quake":
				kb = Vector3(dir * 8.0, 13.0, 0)
		var bmul := 2.0 if style["effect"] in ["quake", "shred"] else 1.0
		targets = get_tree().get_nodes_in_group("enemies").filter(func(t) -> bool:
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
	if _move == "drop":
		# The icicle freezes what it lands on solid for a moment.
		for t in targets:
			if is_instance_valid(t) and "frozen_t" in t:
				t.frozen_t = maxf(t.frozen_t, 0.7 * size)
		RageFX.ice(Vector3(pos.x, 0.0, pos.z), style, 1.1 * size)
		FX.shockwave(Vector3(pos.x, 0.2, pos.z), 3.5 * size, style["glow"])
	if _move == "pool":
		# The glob stays as a pool of lava that keeps burning (see _pool).
		_phase = 1
		_pool_t = POOL_TIME
		global_position = Vector3(pos.x, 0.2, pos.z)
		_body.visible = false
		FX.stop_stream(_trail)
		_trail = null
		RageFX.ground(global_position, style, 1.5 * size, POOL_TIME)
		Player.rage_shake(0.1 * size + (0.1 if hits > 0 else 0.0))
		return
	if size > 1.2 or _move in ["lob", "roll"]:
		# The big third shot (and every lobbed one) marks the street.
		RageFX.ground(pos, style, 1.2 if size > 1.2 else 0.8, 1.0)
	if size > 1.2:
		RageFX.burst(pos, r, style)
	Player.rage_shake(0.1 * size + (0.1 if hits > 0 else 0.0))
	FX.stop_stream(_trail)
	queue_free()
