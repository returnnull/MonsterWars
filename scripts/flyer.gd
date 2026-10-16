class_name Flyer
extends Node3D
## Military aircraft. `kind` picks the variant (stats from Enemies.DEFS):
##   drone  - hovers out of reach, fires plasma bolts, swoops low now and then
##   heli   - attack helicopter: bullet bursts, swoops like the drone
##   bomber - jet that strafes across the street dropping bombs
##   wasp   - small kamikaze drone: hovers, blinks, then dives and explodes
##   saucer - plasma spreads from up high, drops low for a ring blast
## Swat them with jump attacks, stomps, spin attacks or the beam when low.

signal died(who: Node)

var kind := "drone"
var def: Dictionary = {}
var hp_mul := 1.0
var dmg_mul := 1.0
var hp := 35.0
var dmg := 8.0
var dead := false
var hit_radius := 1.5
## The wave arena between its gates (set by main). Aircraft fly in over the
## gates, hold their fire until they are over the arena and then stay over it,
## so they never hang out of reach beyond the barricades.
var arena := Vector2(-INF, INF)
const ARENA_MARGIN := 1.5

var _vel := Vector3.ZERO
var _fire_cd := 2.0
var _side := 1.0
var _t := 0.0
var _flash := 0.0
var _rotors: Array[Node3D] = []
var _tail_rotor: Node3D
var _swoop := 0.0
var _swoop_cd := 4.0
var _hull_mat: StandardMaterial3D
var _warn_mat: StandardMaterial3D
var _burst := 0
var _burst_t := 0.0
var _dive := false
var _dive_dir := Vector3.ZERO
var _arm_t := 0.0
var _bomb_t := 0.0
var _dir := 1.0
var _visual: Node3D
var _entered := false


func _ready() -> void:
	add_to_group("enemies")
	if def.is_empty():
		def = Enemies.get_def(kind)
	hp = float(def.get("hp", 35.0)) * hp_mul
	dmg = float(def.get("dmg", 8.0)) * dmg_mul
	_side = 1.0 if randf() > 0.5 else -1.0
	_t = randf() * 10.0
	_fire_cd = randf_range(1.5, 2.5)
	_visual = Node3D.new()
	add_child(_visual)
	_materials()
	match kind:
		"heli":
			hit_radius = 1.8
			_build_heli()
		"bomber":
			hit_radius = 2.0
			var p := Game.nearest_player(global_position)
			_dir = signf(p.global_position.x - global_position.x) if p else -_side
			if _dir == 0.0:
				_dir = 1.0
			_build_bomber()
		"wasp":
			hit_radius = 1.2
			_fire_cd = randf_range(1.5, 3.0)
			_build_wasp()
		"saucer":
			hit_radius = 2.2
			_build_saucer()
		_:
			_build_drone()


func hit_center() -> Vector3:
	return global_position


func display_name() -> String:
	return String(def.get("name", kind.to_upper()))


func take_hit(dmg_in: float, kb: Vector3, _from: Node3D = null) -> bool:
	if dead:
		return false
	hp -= dmg_in
	_flash = 1.0
	_vel += kb * 0.6
	if hp <= 0.0:
		dead = true
		_vel = kb * 0.5 + Vector3(0, 4, 0)
		Game.add_score(int(def.get("score", 600)))
		died.emit(self)
		if kind == "wasp":
			_blow_up(false)
	return true


func _process(delta: float) -> void:
	_t += delta
	for r in _rotors:
		r.rotate_y(delta * 40.0)
	if _tail_rotor:
		_tail_rotor.rotate_z(delta * 50.0)
	if kind == "saucer":
		_visual.rotate_y(delta * 2.5)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_hull_mat.emission = Color(1, 1, 1) * _flash
	if dead:
		_vel.y -= 25.0 * delta
		rotate_z(delta * 5.0)
		rotate_x(delta * 3.0)
		global_position += _vel * delta
		if global_position.y < 0.6:
			FX.explosion(global_position, 1.2 if kind != "saucer" else 1.8)
			Game.shake(0.3)
			queue_free()
		return

	var p := Game.nearest_player(global_position) as Kaiju
	if p == null:
		return
	if not _entered and _over_arena():
		_entered = true
	match kind:
		"bomber":
			_fly_bomber(delta, p)
		"wasp":
			_fly_wasp(delta, p)
		"saucer":
			_fly_saucer(delta, p)
		_:
			_fly_hover(delta, p)
	if _entered and not dead:
		var lo := arena.x + ARENA_MARGIN
		var hi := arena.y - ARENA_MARGIN
		if global_position.x < lo or global_position.x > hi:
			global_position.x = clampf(global_position.x, lo, hi)
			_vel.x = 0.0


## Over the arena, far enough in from the gates to be hit.
func _over_arena() -> bool:
	return global_position.x >= arena.x + ARENA_MARGIN and global_position.x <= arena.y - ARENA_MARGIN


## Keeps a hover point over the arena. Next to a gate the aircraft switches
## to the player's open side instead of hanging behind the barricade.
func _arena_target(target: Vector3, px: float) -> Vector3:
	var lo := arena.x + ARENA_MARGIN
	var hi := arena.y - ARENA_MARGIN
	if target.x < lo or target.x > hi:
		var mirrored := 2.0 * px - target.x
		if mirrored >= lo and mirrored <= hi:
			_side = -_side
			target.x = mirrored
	target.x = clampf(target.x, lo, hi)
	return target


# --- behaviours --------------------------------------------------------------

## Drone and helicopter: hover out of reach and shoot, then periodically
## swoop low across the kaiju to the other side (the window to swat it).
func _fly_hover(delta: float, p: Kaiju) -> void:
	var heli := kind == "heli"
	var dist := 12.0 if heli else 10.0
	var target := p.global_position + Vector3(_side * dist + sin(_t * 0.7) * 2.5, 6.2 + sin(_t * 1.3) * 0.9, -1.0 + sin(_t * 0.5) * 1.5)
	var max_speed := 13.0
	_swoop_cd -= delta
	if _swoop > 0.0:
		_swoop -= delta
		target = p.global_position + Vector3(_side * 9.0, 3.8, 0.5)
		max_speed = 15.0
		if _swoop <= 0.0:
			_swoop_cd = randf_range(4.0, 6.5)
	elif _swoop_cd <= 0.0:
		_swoop = 2.4
		_side = -_side
	_steer(delta, _arena_target(target, p.global_position.x), max_speed, 2.5)
	var dx := p.global_position.x - global_position.x
	_face(delta, dx, heli)

	if _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst -= 1
			_burst_t = 0.11
			_shoot_bullet(p)
		return
	_fire_cd -= delta
	var warning := _fire_cd < 0.45
	_warn_mat.emission_energy_multiplier = 8.0 if (warning and fmod(_t, 0.12) < 0.06) else 1.5
	if _swoop > 0.0:
		_fire_cd = maxf(_fire_cd, 0.8)
	if _fire_cd <= 0.0 and absf(dx) < 24.0 and not p.dead and _entered:
		if heli:
			_burst = 5
			_burst_t = 0.0
			_fire_cd = randf_range(2.6, 3.6)
		else:
			_fire(p)
			_fire_cd = randf_range(1.8, 3.0)


## Jet: strafing runs across the player at low altitude, dropping bombs
## ahead of them, then a wide turn for the next run.
func _fly_bomber(delta: float, p: Kaiju) -> void:
	var dx := p.global_position.x - global_position.x
	# Passed far enough beyond the player: turn around.
	# Passed far enough beyond the player, or about to cross a gate: turn around.
	var at_gate := _entered and ((_dir > 0.0 and global_position.x > arena.y - ARENA_MARGIN - 2.0) \
			or (_dir < 0.0 and global_position.x < arena.x + ARENA_MARGIN + 2.0))
	if dx * _dir < -16.0 or at_gate:
		_dir = -_dir
		_bomb_t = 0.0
	var alt := 4.8 + sin(_t * 0.8) * 0.4
	var turning := absf(_vel.x) < 8.0 or signf(_vel.x) != _dir
	if turning:
		alt += 2.5
	var target := Vector3(global_position.x + _dir * 20.0, alt, p.global_position.z - 0.5)
	var want := target - global_position
	want = Vector3(_dir * 14.0, want.y * 2.0, want.z * 1.5)
	_vel = _vel.lerp(want, 1.0 - exp(-1.6 * delta))
	global_position += _vel * delta
	rotation.y = lerp_angle(rotation.y, 0.0 if _vel.x > 0.0 else PI, 1.0 - exp(-4.0 * delta))
	rotation.x = clampf(_vel.z * 0.03, -0.3, 0.3)
	# Bombs away while closing in on the player.
	_bomb_t -= delta
	var ahead := dx * _dir
	_warn_mat.emission_energy_multiplier = 8.0 if (ahead > 0.0 and ahead < 14.0 and fmod(_t, 0.2) < 0.1) else 1.5
	if not turning and ahead > 1.0 and ahead < 11.0 and _bomb_t <= 0.0 and _entered:
		_bomb_t = 0.35
		var b := Projectile.new()
		b.style = "bomb"
		b.color = Color(1.0, 0.5, 0.15)
		b.damage = dmg
		b.gravity = 22.0
		b.splash = 3.0
		get_parent().add_child(b)
		b.global_position = global_position + Vector3(0, -0.8, 0)
		b.velocity = Vector3(_vel.x * 0.6, -2.0, 0)


## Kamikaze wasp: hover nearby, blink, then dive straight at the player.
func _fly_wasp(delta: float, p: Kaiju) -> void:
	if _dive:
		_vel = _vel.lerp(_dive_dir * 22.0, 1.0 - exp(-6.0 * delta))
		global_position += _vel * delta
		_face(delta, _vel.x, true)
		for q in Game.living_players():
			if global_position.distance_to(q.hit_center()) < q.hit_radius + 1.0:
				_blow_up(true)
				return
		if global_position.y < 0.5 or _arm_t > 2.5:
			_blow_up(true)
		_arm_t += delta
		return
	var target := p.global_position + Vector3(_side * 7.0 + sin(_t * 2.0) * 1.5, 5.0 + sin(_t * 3.1) * 0.7, sin(_t * 1.7) * 1.5)
	_steer(delta, _arena_target(target, p.global_position.x), 16.0, 3.5)
	_face(delta, p.global_position.x - global_position.x, false)
	if _entered:
		_fire_cd -= delta
	_warn_mat.emission_energy_multiplier = 10.0 if (_fire_cd < 0.7 and fmod(_t, 0.1) < 0.05) else 2.0
	if _fire_cd <= 0.0:
		_dive = true
		_arm_t = 0.0
		_dive_dir = (p.hit_center() - global_position).normalized()


func _blow_up(attack: bool) -> void:
	if attack:
		if not dead:
			dead = true
			Game.add_score(int(def.get("score", 400)) / 2)
			died.emit(self)
		for q in Game.living_players():
			if q.hit_center().distance_to(global_position) < 3.2 + q.hit_radius * 0.5:
				if q.take_hit(dmg, Vector3(signf(q.global_position.x - global_position.x) * 10.0, 8.0, 0), self):
					FX.hit_spark(q.hit_center(), 12.0)
	FX.explosion(global_position, 0.9)
	Game.shake(0.3)
	queue_free()


## Saucer: hovers high firing 3-way plasma spreads; every so often it sinks
## low and releases a ring of plasma (and can be hit easily).
func _fly_saucer(delta: float, p: Kaiju) -> void:
	_swoop_cd -= delta
	var target := p.global_position + Vector3(_side * 6.0 + sin(_t * 0.5) * 4.0, 7.5 + sin(_t * 1.1) * 0.6, -1.5)
	if _swoop > 0.0:
		_swoop -= delta
		target = p.global_position + Vector3(_side * 3.5, 3.6, -0.5)
		_warn_mat.emission_energy_multiplier = 10.0 if fmod(_t, 0.14) < 0.07 else 3.0
		if _swoop < 1.0 and _burst == 0:
			_burst = 1
			_ring_blast()
		if _swoop <= 0.0:
			_swoop_cd = randf_range(5.0, 7.0)
			_side = -_side
	elif _swoop_cd <= 0.0 and _entered:
		_swoop = 3.0
		_burst = 0
	else:
		_warn_mat.emission_energy_multiplier = 3.0
	_steer(delta, _arena_target(target, p.global_position.x), 11.0, 2.0)
	_fire_cd -= delta
	if _swoop <= 0.0 and _fire_cd <= 0.0 and not p.dead and _entered:
		_fire_cd = randf_range(2.2, 3.0)
		for a in [-0.18, 0.0, 0.18]:
			var b := Projectile.new()
			b.color = Color(0.4, 1.0, 0.6)
			b.damage = dmg
			get_parent().add_child(b)
			b.global_position = global_position + Vector3(0, -0.6, 0)
			b.velocity = (p.hit_center() - b.global_position).normalized().rotated(Vector3.UP, a) * 17.0
		FX.light_flash(global_position, Color(0.4, 1.0, 0.6), 5.0, 8.0, 0.2)


func _ring_blast() -> void:
	FX.shockwave(Vector3(global_position.x, 0.1, global_position.z), 6.0, Color(0.4, 1.0, 0.6))
	for i in 10:
		var a := TAU * i / 10.0
		var b := Projectile.new()
		b.color = Color(0.4, 1.0, 0.6)
		b.damage = dmg
		get_parent().add_child(b)
		b.global_position = global_position + Vector3(0, -0.4, 0)
		b.velocity = Vector3(cos(a) * 14.0, -3.0, sin(a) * 6.0)


func _steer(delta: float, target: Vector3, max_speed: float, k: float) -> void:
	var want := ((target - global_position) * 1.6).limit_length(max_speed)
	_vel = _vel.lerp(want, 1.0 - exp(-k * delta))
	global_position += _vel * delta


func _face(delta: float, dx: float, tilt_forward: bool) -> void:
	rotation.y = lerp_angle(rotation.y, 0.0 if dx > 0.0 else PI, 1.0 - exp(-6.0 * delta))
	var sgn := 1.0 if dx > 0.0 else -1.0
	rotation.z = clampf(-_vel.x * 0.03 * sgn, -0.4, 0.4) - (0.15 if tilt_forward else 0.0)


func _fire(p: Kaiju) -> void:
	var b := Projectile.new()
	b.damage = dmg
	get_parent().add_child(b)
	b.global_position = global_position
	b.velocity = (p.hit_center() - global_position).normalized() * 20.0
	FX.light_flash(global_position, Color(1.0, 0.5, 0.2), 4.0, 6.0, 0.15)


func _shoot_bullet(p: Kaiju) -> void:
	var b := Projectile.new()
	b.style = "bullet"
	b.color = Color(1.0, 0.85, 0.3)
	b.damage = dmg
	get_parent().add_child(b)
	var muzzle := global_position + Vector3(signf(p.global_position.x - global_position.x) * 1.4, -0.7, 0)
	b.global_position = muzzle
	b.velocity = (p.hit_center() - muzzle).normalized().rotated(Vector3.UP, randf_range(-0.05, 0.05)) * 30.0
	FX.light_flash(muzzle, Color(1.0, 0.8, 0.3), 3.0, 5.0, 0.06)


# --- models ------------------------------------------------------------------

func _materials() -> void:
	_hull_mat = StandardMaterial3D.new()
	_hull_mat.albedo_color = Color(0.3, 0.34, 0.3)
	_hull_mat.metallic = 0.6
	_hull_mat.roughness = 0.35
	_hull_mat.emission_enabled = true
	_hull_mat.emission = Color.BLACK
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.albedo_color = Color(1, 0.2, 0.1)
	_warn_mat.emission_enabled = true
	_warn_mat.emission = Color(1, 0.15, 0.05)


func _glass(c: Color = Color(0.2, 0.6, 1.0)) -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.2, 0.3)
	glass.metallic = 0.9
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = c
	glass.emission_energy_multiplier = 0.8
	return glass


func _rotor_mat() -> StandardMaterial3D:
	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.45)
	rotor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return rotor_mat


func _add_rotor(pos: Vector3, r: float) -> Node3D:
	var rotor := Node3D.new()
	rotor.position = pos
	_visual.add_child(rotor)
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.03
	var dmi := MeshInstance3D.new()
	dmi.mesh = disc
	dmi.material_override = _rotor_mat()
	rotor.add_child(dmi)
	var blade := BoxMesh.new()
	blade.size = Vector3(r * 2.0, 0.04, 0.18)
	var bmi := MeshInstance3D.new()
	bmi.mesh = blade
	bmi.material_override = _hull_mat
	rotor.add_child(bmi)
	_rotors.append(rotor)
	return rotor


func _build_drone() -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.6
	body.height = 3.0
	_mi(body, _hull_mat, Vector3.ZERO, Vector3(0, 0, PI / 2))
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 0.8
	_mi(canopy, _glass(), Vector3(0.9, 0.3, 0))
	_mi(_box(Vector3(2.2, 0.25, 0.25)), _hull_mat, Vector3(-2.2, 0.15, 0))
	_mi(_box(Vector3(0.6, 0.9, 0.08)), _hull_mat, Vector3(-3.1, 0.5, 0))
	_mi(_box(Vector3(0.9, 0.12, 3.6)), _hull_mat, Vector3(0, 0.1, 0))
	for side in [-1.0, 1.0]:
		_mi(_cyl(0.28, 0.28, 0.6), _hull_mat, Vector3(0, 0.3, 1.8 * side))
		_add_rotor(Vector3(0, 0.65, 1.8 * side), 1.2)
	_mi(_cyl(0.1, 0.14, 1.0), _hull_mat, Vector3(1.2, -0.45, 0), Vector3(0, 0, PI / 2))
	var lamp := _sphere(0.14)
	_mi(lamp, _warn_mat, Vector3(-3.3, 0.95, 0))
	_mi(lamp, _warn_mat, Vector3(1.75, -0.45, 0))


func _build_heli() -> void:
	_hull_mat.albedo_color = Color(0.22, 0.26, 0.2)
	var body := CapsuleMesh.new()
	body.radius = 0.85
	body.height = 3.4
	_mi(body, _hull_mat, Vector3(0.2, 0, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.8))
	var canopy := SphereMesh.new()
	canopy.radius = 0.7
	canopy.height = 1.0
	_mi(canopy, _glass(Color(0.3, 0.7, 1.0)), Vector3(1.4, 0.15, 0), Vector3.ZERO, Vector3(1.0, 0.9, 0.8))
	_mi(_cyl(0.18, 0.35, 3.4), _hull_mat, Vector3(-2.6, 0.25, 0), Vector3(0, 0, PI / 2))
	_mi(_box(Vector3(0.8, 1.2, 0.1)), _hull_mat, Vector3(-4.1, 0.75, 0), Vector3(0, 0, -0.3))
	_mi(_box(Vector3(0.25, 0.5, 0.25)), _hull_mat, Vector3(0.1, 0.95, 0))
	_add_rotor(Vector3(0.1, 1.25, 0), 3.0)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(-4.2, 0.8, 0.2)
	_visual.add_child(_tail_rotor)
	var tr := MeshInstance3D.new()
	tr.mesh = _box(Vector3(0.12, 1.4, 0.04))
	tr.material_override = _hull_mat
	_tail_rotor.add_child(tr)
	# Stub wings with rocket pods, skids and a chin gun.
	_mi(_box(Vector3(0.7, 0.12, 2.8)), _hull_mat, Vector3(0, -0.2, 0))
	for side in [-1.0, 1.0]:
		_mi(_cyl(0.22, 0.22, 1.1), _hull_mat, Vector3(0.1, -0.45, 1.25 * side), Vector3(0, 0, PI / 2))
		_mi(_box(Vector3(2.6, 0.08, 0.1)), _hull_mat, Vector3(0.2, -1.05, 0.6 * side))
		_mi(_box(Vector3(0.08, 0.5, 0.08)), _hull_mat, Vector3(0.6, -0.8, 0.6 * side))
	_mi(_cyl(0.07, 0.1, 1.0), _hull_mat, Vector3(1.9, -0.6, 0), Vector3(0, 0, PI / 2))
	_mi(_sphere(0.14), _warn_mat, Vector3(-4.3, 1.4, 0))
	_mi(_sphere(0.12), _warn_mat, Vector3(2.4, -0.6, 0))


func _build_bomber() -> void:
	_hull_mat.albedo_color = Color(0.45, 0.47, 0.5)
	var body := CapsuleMesh.new()
	body.radius = 0.55
	body.height = 5.6
	_mi(body, _hull_mat, Vector3.ZERO, Vector3(0, 0, PI / 2))
	_mi(_cyl(0.0, 0.55, 1.4), _hull_mat, Vector3(3.3, 0, 0), Vector3(0, 0, -PI / 2))
	_mi(_sphere(0.4), _glass(), Vector3(1.6, 0.4, 0), Vector3.ZERO, Vector3(2.0, 0.8, 0.9))
	# Swept delta wings (a flattened prism) and twin tail fins.
	var wing := PrismMesh.new()
	wing.size = Vector3(5.0, 3.0, 0.12)
	_mi(wing, _hull_mat, Vector3(-0.6, -0.05, 0), Vector3(-PI / 2, 0, -PI / 2))
	for side in [-1.0, 1.0]:
		_mi(_box(Vector3(1.2, 1.1, 0.08)), _hull_mat, Vector3(-2.3, 0.7, 0.4 * side), Vector3(0.2 * side, 0, -0.5))
		_mi(_cyl(0.18, 0.18, 1.2), _hull_mat, Vector3(-0.2, -0.45, 1.2 * side), Vector3(0, 0, PI / 2))
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.6, 0.2)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.5, 0.15)
	flame.emission_energy_multiplier = 6.0
	_mi(_cyl(0.35, 0.0, 1.4), flame, Vector3(-3.4, 0, 0), Vector3(0, 0, PI / 2))
	_mi(_sphere(0.15), _warn_mat, Vector3(0, -0.55, 0))


func _build_wasp() -> void:
	_hull_mat.albedo_color = Color(0.85, 0.65, 0.1)
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(0.08, 0.08, 0.08)
	stripe.metallic = 0.5
	_mi(_sphere(0.45), _hull_mat, Vector3(0.5, 0, 0), Vector3.ZERO, Vector3(1.2, 1.0, 1.0))
	_mi(_sphere(0.6), stripe, Vector3(-0.6, -0.05, 0), Vector3.ZERO, Vector3(1.5, 0.9, 0.9))
	_mi(_cyl(0.0, 0.18, 0.7), stripe, Vector3(-1.55, -0.1, 0), Vector3(0, 0, PI / 2))
	_mi(_sphere(0.2), _warn_mat, Vector3(0.95, 0.1, 0))
	for side in [-1.0, 1.0]:
		_mi(_cyl(0.15, 0.15, 0.25), stripe, Vector3(0, 0.25, 0.75 * side))
		_add_rotor(Vector3(0, 0.45, 0.75 * side), 0.6)


func _build_saucer() -> void:
	_hull_mat.albedo_color = Color(0.7, 0.72, 0.78)
	_hull_mat.metallic = 0.9
	_hull_mat.roughness = 0.2
	_mi(_sphere(2.4), _hull_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.22, 1.0))
	_mi(_sphere(1.0), _glass(Color(0.4, 1.0, 0.6)), Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
	_mi(_cyl(1.0, 1.3, 0.35), _hull_mat, Vector3(0, -0.45, 0))
	_warn_mat.albedo_color = Color(0.4, 1.0, 0.6)
	_warn_mat.emission = Color(0.3, 1.0, 0.5)
	_mi(_cyl(0.8, 0.8, 0.1), _warn_mat, Vector3(0, -0.65, 0))
	for i in 8:
		var a := TAU * i / 8.0
		_mi(_sphere(0.18), _warn_mat, Vector3(cos(a) * 2.25, 0.0, sin(a) * 2.25))


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _mi(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	_visual.add_child(m)
	return m
