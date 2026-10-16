class_name Vehicle
extends Kaiju
## Military ground unit. `kind` picks the variant (stats from Enemies.DEFS):
##   tank      - keeps its distance, aims its turret and fires shells
##   artillery - stays far back and lobs shells onto marked spots
##   missile   - SAM truck: raises its pod and launches homing missiles
##   maser     - maser cannon: charges a visible beam, then fires it down the street
##   mech      - bipedal walker: gun bursts at range, a kick up close
##   apc       - armoured carrier: drops off a rifle squad, then machine-guns
## Small next to a kaiju, so the hit sphere is generous; stomps and swipes
## crush it. Built from boxes and cylinders.

signal spawned_minion(node: Node)

var kind := "tank"
var def: Dictionary = {}
var hp_mul := 1.0
var dmg_mul := 1.0
var speed := 4.0
var dmg := 10.0

var _vis: Node3D
var _turret: Node3D
var _barrel: Node3D
var _legs: Array[Node3D] = []
var _mats: Array[StandardMaterial3D] = []
var _light_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _flash := 0.0
var _cd := 2.0
var _act := ""
var _act_t := 0.0
var _shots := 0
var _vyaw := 0.0
var _walk := 0.0
var _band := Vector2(9.0, 16.0)
var _z_bias := 0.0
var _beam_dir := 1.0
var _beam_tick := 0.0
var _deployed := false


func _ready() -> void:
	add_to_group("enemies")
	if def.is_empty():
		def = Enemies.get_def(kind)
	max_hp = float(def.get("hp", 60.0)) * hp_mul
	dmg = float(def.get("dmg", 10.0)) * dmg_mul
	speed = def.get("speed", 4.0)
	init_body(1.3, 2.6, Game.LAYER_ENEMY)
	hit_radius = 2.1
	hit_height = 1.5
	z_min = -5.2
	z_max = 3.0
	_z_bias = randf_range(-2.0, 2.0)
	_cd = randf_range(1.5, 2.5)
	_vis = Node3D.new()
	add_child(_vis)
	_light_mat = StandardMaterial3D.new()
	_light_mat.albedo_color = Color(1.0, 0.25, 0.1)
	_light_mat.emission_enabled = true
	_light_mat.emission = Color(1.0, 0.2, 0.05)
	_light_mat.emission_energy_multiplier = 1.5
	match kind:
		"artillery":
			_band = Vector2(15.0, 24.0)
			_build_artillery()
		"missile":
			_band = Vector2(11.0, 20.0)
			_build_missile()
		"maser":
			_band = Vector2(9.0, 18.0)
			_build_maser()
		"apc":
			_band = Vector2(6.0, 12.0)
			_build_apc()
		"mech":
			_band = Vector2(3.5, 9.0)
			hit_height = 2.4
			hit_radius = 2.3
			_build_mech()
		_:
			_build_tank()
	_vyaw = 0.0 if facing > 0.0 else PI
	_vis.rotation.y = _vyaw


func display_name() -> String:
	return String(def.get("name", kind.to_upper()))


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	for m in _mats:
		m.emission = Color(1, 1, 1) * _flash
	if dead:
		return
	var p := Game.nearest_player(global_position) as Kaiju
	var mv := Vector3.ZERO
	if frozen_t <= 0.0 and p:
		mv = _think(delta, p)
	move_body(delta, mv)
	# Face the player (turn through the camera side, like the kaiju).
	var target := 0.0 if facing > 0.0 else -PI
	_vyaw = lerpf(_vyaw, target, 1.0 - exp(-8.0 * delta))
	_vis.rotation.y = _vyaw
	_animate(delta, mv)


func _think(delta: float, p: Kaiju) -> Vector3:
	var dx := p.global_position.x - global_position.x
	var adx := absf(dx)
	var mv := Vector3.ZERO
	if _act == "":
		face_toward(dx)
		if adx < _band.x:
			mv.x = -signf(dx) * speed
		elif adx > _band.y:
			mv.x = signf(dx) * speed
		var dz := (p.global_position.z + _z_bias * 0.4) - global_position.z
		if absf(dz) > 0.6 and kind != "artillery":
			mv.z = signf(dz) * speed * 0.6
		# Stay inside the arena: backed against its edge it has to fight.
		var nx := global_position.x + mv.x * 0.3
		if nx < arena.x or nx > arena.y:
			mv.x = signf((arena.x + arena.y) * 0.5 - global_position.x) * speed * 0.5 if (global_position.x < arena.x or global_position.x > arena.y) else 0.0
		_cd -= delta
		if _cd <= 0.0 and adx < 30.0 and in_arena():
			_start_act(adx)
	else:
		_act_t += delta
		_run_act(delta, p)
	return mv


func _start_act(adx: float) -> void:
	_act_t = 0.0
	_shots = 0
	match kind:
		"mech":
			_act = "kick" if adx < 5.5 else "burst"
		"apc":
			_act = "burst" if _deployed else "deploy"
		"maser":
			_act = "charge"
			_beam_dir = facing
			_beam.visible = true
		_:
			_act = "aim"


func _end_act(cd_min: float, cd_max: float) -> void:
	_act = ""
	_cd = randf_range(cd_min, cd_max)
	_light_mat.emission_energy_multiplier = 1.5


func _run_act(delta: float, p: Kaiju) -> void:
	var blink := fmod(_act_t, 0.12) < 0.06
	match kind:
		"tank":
			_light_mat.emission_energy_multiplier = 8.0 if blink else 1.5
			if _act_t >= 0.6:
				_fire_shell(p)
				_end_act(2.2, 3.2)
		"artillery":
			_light_mat.emission_energy_multiplier = 8.0 if blink else 1.5
			if _barrel:
				_barrel.rotation.z = lerpf(_barrel.rotation.z, 1.0, 1.0 - exp(-6.0 * delta))
			if _act_t >= 0.5 + _shots * 0.45 and _shots < 2:
				_shots += 1
				_lob(p)
			if _act_t >= 1.6:
				_end_act(3.2, 4.2)
		"missile":
			if _turret:
				_turret.rotation.z = lerpf(_turret.rotation.z, 0.7, 1.0 - exp(-6.0 * delta))
			_light_mat.emission_energy_multiplier = 8.0 if blink else 1.5
			if _act_t >= 0.7 + _shots * 0.3 and _shots < 3:
				_shots += 1
				_launch_missile(p)
			if _act_t >= 1.8:
				_end_act(3.8, 5.0)
		"maser":
			_maser(delta)
		"apc":
			if _act == "deploy":
				_light_mat.emission_energy_multiplier = 8.0 if blink else 1.5
				if _act_t >= 0.5 and not _deployed:
					_deployed = true
					_deploy()
				if _act_t >= 1.2:
					_end_act(0.8, 1.4)
			else:
				if _act_t >= 0.2 + _shots * 0.1 and _shots < 8:
					_shots += 1
					_bullet(p)
				if _act_t >= 1.2:
					_end_act(1.8, 2.6)
		"mech":
			if _act == "kick":
				_light_mat.emission_energy_multiplier = 8.0 if blink else 1.5
				if _act_t >= 0.45 and _shots == 0:
					_shots = 1
					var c := global_position + Vector3(facing * 2.6, 2.0, 0)
					if strike(c, 2.6, dmg * 1.6, Vector3(14, 8, 0), "player") > 0:
						Game.shake(0.3)
					FX.dust(c - Vector3(0, 2, 0), 0.8)
				if _act_t >= 0.8:
					_end_act(1.0, 1.8)
			else:
				if _act_t >= 0.3 + _shots * 0.12 and _shots < 6:
					_shots += 1
					_bullet(p)
				if _act_t >= 1.2:
					_end_act(2.0, 3.0)


## Rear hatch opens and a rifle squad jumps out.
func _deploy() -> void:
	var n := 3
	for i in n:
		var s := Infantry.new()
		s.kind = "soldier"
		s.hp_mul = hp_mul
		s.dmg_mul = dmg_mul
		s.arena = arena
		s.x_min = x_min
		s.x_max = x_max
		s.facing = facing
		get_parent().add_child(s)
		s.global_position = global_position + Vector3(-facing * (2.6 + i * 0.6), 0.3, (i - 1) * 1.1)
		s.velocity.y = 5.0
		spawned_minion.emit(s)
	FX.dust(global_position - Vector3(facing * 2.4, 0, 0), 0.8)


func _fire_shell(p: Kaiju) -> void:
	var b := Projectile.new()
	b.style = "shell"
	b.color = Color(1.0, 0.6, 0.2)
	b.damage = dmg
	b.splash = 2.2
	b.gravity = 4.0
	get_parent().add_child(b)
	var muzzle := _muzzle(2.7, 1.55)
	b.global_position = muzzle
	var to := p.hit_center() + Vector3(0, -0.5, 0)
	var t := muzzle.distance_to(to) / 26.0
	var v := (to - muzzle) / maxf(t, 0.1)
	v.y += 0.5 * b.gravity * t
	b.velocity = v
	FX.light_flash(muzzle, Color(1.0, 0.7, 0.3), 6.0, 7.0, 0.12)
	FX.smoke(muzzle, 0.4, Color(0.6, 0.6, 0.6))
	if _barrel:
		_barrel.position.x = 0.6
		create_tween().tween_property(_barrel, "position:x", 1.2, 0.3)


func _lob(p: Kaiju) -> void:
	var muzzle := _muzzle(1.6, 2.6)
	FX.light_flash(muzzle, Color(1.0, 0.7, 0.3), 6.0, 7.0, 0.12)
	FX.smoke(muzzle, 0.6, Color(0.6, 0.6, 0.6))
	# A shell flies up out of view; the hit lands later on the marked spot.
	var up := Projectile.new()
	up.style = "shell"
	up.damage = 0.0
	up.velocity = Vector3(facing * 4.0, 40.0, 0)
	get_parent().add_child(up)
	up.global_position = muzzle
	up.set("_life", 0.6)
	var h := Hazard.new()
	h.style = "shell"
	h.radius = 3.2
	h.delay = 1.6
	h.damage = dmg
	h.color = Color(1.0, 0.35, 0.1)
	get_parent().add_child(h)
	var lead: Vector3 = p.velocity * 0.6
	var spread := randf_range(-2.5, 2.5) if _shots > 1 else 0.0
	h.global_position = Vector3(p.global_position.x + lead.x + spread, 0.0, p.global_position.z)


func _launch_missile(p: Kaiju) -> void:
	var b := Projectile.new()
	b.style = "missile"
	b.color = Color(1.0, 0.55, 0.2)
	b.damage = dmg
	b.splash = 1.8
	b.homing = 2.2
	b.homing_delay = 0.45
	b.target = p
	b.velocity = Vector3(facing * 4.0, 13.0, randf_range(-1.5, 1.5))
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(-facing * 0.4, 2.6, 0)
	FX.smoke(b.global_position, 0.6, Color(0.75, 0.75, 0.72))


func _bullet(p: Kaiju) -> void:
	var b := Projectile.new()
	b.style = "bullet"
	b.color = Color(1.0, 0.85, 0.3)
	b.damage = dmg * 0.6
	get_parent().add_child(b)
	var muzzle := global_position + Vector3(facing * 1.5, 2.5 if kind == "mech" else 2.2, 0)
	b.global_position = muzzle
	b.velocity = (p.hit_center() - muzzle).normalized().rotated(Vector3.UP, randf_range(-0.05, 0.05)) * 28.0
	FX.light_flash(muzzle, Color(1.0, 0.8, 0.3), 3.0, 5.0, 0.06)


## Maser: 1.2 s charge with a thin aiming beam, then 0.7 s of full beam.
func _maser(delta: float) -> void:
	var origin := global_position + Vector3(_beam_dir * 1.4, 2.6, 0)
	_beam.global_position = origin + Vector3(_beam_dir * 15.0, 0, 0)
	if _act_t < 1.2:
		var k := _act_t / 1.2
		_beam.scale = Vector3(1.0, 0.08 + k * 0.1, 0.08 + k * 0.1)
		_beam_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.25 + 0.35 * absf(sin(_act_t * 20.0)))
		_light_mat.emission_energy_multiplier = 2.0 + k * 10.0
		return
	if _act == "charge":
		_act = "fire"
		Game.shake(0.3)
		FX.light_flash(origin, Color(0.5, 0.9, 1.0), 10.0, 12.0, 0.6)
	_beam.scale = Vector3(1.0, 1.0, 1.0)
	_beam_mat.albedo_color = Color(0.7, 0.95, 1.0, 0.9)
	_beam_tick -= delta
	if _beam_tick <= 0.0:
		_beam_tick = 0.1
		for q in Game.living_players():
			var tc: Vector3 = q.hit_center()
			var along := (tc.x - origin.x) * _beam_dir
			if along > -1.0 and along < 30.0 and absf(tc.z - origin.z) < 1.0 + q.hit_radius and absf(tc.y - origin.y) < 1.2 + q.hit_radius:
				if q.take_hit(dmg, Vector3(_beam_dir * 4.0, 1.0, 0), self):
					FX.hit_spark(Vector3(tc.x - _beam_dir * q.hit_radius, origin.y, tc.z), 6.0)
		for b in get_tree().get_nodes_in_group("buildings"):
			b.try_beam(origin, _beam_dir, 30.0, 6.0)
	if _act_t >= 1.9:
		_beam.visible = false
		_end_act(3.5, 4.5)


func _muzzle(fwd: float, up: float) -> Vector3:
	return global_position + Vector3(facing * fwd, up, 0)


func _on_hurt(_dmg: float, _from: Node3D) -> void:
	_flash = 1.0
	knock *= 0.5
	hitstun = 0.0


func _on_death() -> void:
	collision_layer = 0
	if _beam:
		_beam.visible = false
	Game.add_score(int(def.get("score", 800)))
	died.emit(self)
	FX.explosion(hit_center(), 1.4)
	FX.debris_burst(hit_center(), 1.0)
	Game.shake(0.4)
	for m in _mats:
		m.albedo_color = m.albedo_color.darkened(0.7)
	_light_mat.emission_energy_multiplier = 0.0
	var tw := create_tween()
	tw.tween_property(_vis, "rotation:z", randf_range(-0.4, 0.4), 0.3)
	tw.tween_callback(func() -> void: FX.smoke(global_position + Vector3(0, 1.5, 0), 1.0, Color(0.15, 0.14, 0.13)))
	tw.tween_interval(1.5)
	tw.tween_property(self, "position:y", -3.0, 1.2)
	tw.tween_callback(queue_free)


func _animate(delta: float, mv: Vector3) -> void:
	var moving := Vector2(mv.x, mv.z).length() / maxf(speed, 0.1)
	_walk += delta * moving * 8.0
	if kind == "mech":
		for i in _legs.size():
			_legs[i].rotation.z = sin(_walk + i * PI) * 0.5 * moving
		_vis.position.y = absf(cos(_walk)) * 0.15 * moving
		if _act == "kick" and _legs.size() > 0:
			_legs[0].rotation.z = -1.2 if _act_t > 0.45 else 0.5
	else:
		# Engine rumble.
		_vis.position.y = sin(_walk * 3.0) * 0.03 * moving
	if kind == "artillery" and _act == "" and _barrel:
		_barrel.rotation.z = lerpf(_barrel.rotation.z, 0.5, 1.0 - exp(-3.0 * delta))
	if kind == "missile" and _act == "" and _turret:
		_turret.rotation.z = lerpf(_turret.rotation.z, 0.0, 1.0 - exp(-3.0 * delta))


# --- models ------------------------------------------------------------------

func _mat(c: Color, metal: float = 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.55
	m.emission_enabled = true
	m.emission = Color.BLACK
	_mats.append(m)
	return m


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, mat, pos, rot)


func _cyl(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, r_top: float = -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r if r_top < 0.0 else r_top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return _mi(parent, c, mat, pos, rot)


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _wheels(dark: Material, xs: Array, z: float, r: float) -> void:
	for x in xs:
		for side in [-1.0, 1.0]:
			_cyl(_vis, r, 0.35, dark, Vector3(x, r, z * side), Vector3(PI / 2, 0, 0))


func _build_tank() -> void:
	var hull := _mat(Color(0.33, 0.38, 0.24))
	var dark := _mat(Color(0.12, 0.12, 0.11), 0.2)
	for side in [-1.0, 1.0]:
		_box(_vis, Vector3(4.2, 0.8, 0.7), dark, Vector3(0, 0.4, 1.0 * side))
	_box(_vis, Vector3(3.8, 0.7, 1.9), hull, Vector3(0, 0.95, 0))
	_box(_vis, Vector3(0.8, 0.45, 1.8), hull, Vector3(2.0, 0.75, 0), Vector3(0, 0, 0.5))
	_turret = _pivot(_vis, Vector3(-0.2, 1.55, 0))
	_box(_turret, Vector3(1.8, 0.6, 1.4), hull, Vector3.ZERO)
	_barrel = _pivot(_turret, Vector3(1.2, 0.05, 0))
	_cyl(_barrel, 0.14, 2.4, hull, Vector3(0.8, 0, 0), Vector3(0, 0, PI / 2))
	_cyl(_barrel, 0.2, 0.4, dark, Vector3(2.0, 0, 0), Vector3(0, 0, PI / 2))
	_box(_turret, Vector3(0.4, 0.25, 0.4), dark, Vector3(-0.3, 0.42, 0.3))
	_mi(_turret, _sphere_mesh(0.12), _light_mat, Vector3(-0.8, 0.4, -0.5), Vector3.ZERO)


func _build_artillery() -> void:
	var body := _mat(Color(0.42, 0.4, 0.3))
	var dark := _mat(Color(0.12, 0.12, 0.11), 0.2)
	_wheels(dark, [-1.6, -0.6, 1.4], 0.95, 0.5)
	_box(_vis, Vector3(4.4, 0.5, 1.8), body, Vector3(0, 0.95, 0))
	_box(_vis, Vector3(1.2, 1.2, 1.7), body, Vector3(1.7, 1.75, 0))
	_box(_vis, Vector3(0.1, 0.6, 1.4), _glass_mat(), Vector3(2.31, 1.95, 0))
	_turret = _pivot(_vis, Vector3(-0.9, 1.5, 0))
	_box(_turret, Vector3(1.4, 0.5, 1.4), body, Vector3.ZERO)
	_barrel = _pivot(_turret, Vector3(0.3, 0.3, 0))
	_barrel.rotation.z = 0.5
	_cyl(_barrel, 0.2, 3.4, body, Vector3(1.5, 0, 0), Vector3(0, 0, PI / 2), 0.16)
	_box(_barrel, Vector3(0.5, 0.5, 0.5), dark, Vector3(0, 0, 0))
	_mi(_vis, _sphere_mesh(0.12), _light_mat, Vector3(1.7, 2.45, 0), Vector3.ZERO)


func _build_missile() -> void:
	var body := _mat(Color(0.3, 0.35, 0.28))
	var dark := _mat(Color(0.12, 0.12, 0.11), 0.2)
	var white := _mat(Color(0.85, 0.85, 0.8), 0.3)
	_wheels(dark, [-1.5, -0.5, 1.4], 0.95, 0.48)
	_box(_vis, Vector3(4.3, 0.5, 1.8), body, Vector3(0, 0.95, 0))
	_box(_vis, Vector3(1.1, 1.1, 1.7), body, Vector3(1.75, 1.7, 0))
	_box(_vis, Vector3(0.1, 0.55, 1.4), _glass_mat(), Vector3(2.31, 1.9, 0))
	_turret = _pivot(_vis, Vector3(-1.6, 1.25, 0))
	_box(_turret, Vector3(2.6, 0.8, 1.5), body, Vector3(1.3, 0.4, 0))
	for i in 3:
		for j in 2:
			_cyl(_turret, 0.16, 0.4, white, Vector3(2.65, 0.2 + j * 0.42, (i - 1) * 0.45), Vector3(0, 0, PI / 2))
	_mi(_vis, _sphere_mesh(0.12), _light_mat, Vector3(1.75, 2.35, 0), Vector3.ZERO)


func _build_maser() -> void:
	var body := _mat(Color(0.75, 0.76, 0.8), 0.7)
	var dark := _mat(Color(0.15, 0.15, 0.18), 0.4)
	_wheels(dark, [-1.4, -0.4, 0.6, 1.6], 1.0, 0.45)
	_box(_vis, Vector3(4.2, 0.6, 1.9), body, Vector3(0, 0.95, 0))
	_cyl(_vis, 0.35, 1.2, dark, Vector3(0.2, 1.7, 0))
	_turret = _pivot(_vis, Vector3(0.4, 2.5, 0))
	# The parabolic dish (a flattened, tilted cone) with an emitter spike.
	_cyl(_turret, 1.2, 0.35, body, Vector3(0.3, 0, 0), Vector3(0, 0, -PI / 2), 0.45)
	_cyl(_turret, 0.06, 1.4, dark, Vector3(1.0, 0, 0), Vector3(0, 0, PI / 2))
	_mi(_turret, _sphere_mesh(0.22), _light_mat, Vector3(1.7, 0, 0), Vector3.ZERO)
	_light_mat.albedo_color = Color(0.5, 0.9, 1.0)
	_light_mat.emission = Color(0.4, 0.85, 1.0)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(0.6, 0.95, 1.0, 0.5)
	_beam = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.7
	c.bottom_radius = 0.7
	c.height = 30.0
	c.radial_segments = 12
	_beam.mesh = c
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.rotation.z = PI / 2
	_beam.visible = false
	_beam.top_level = true
	add_child(_beam)


func _build_mech() -> void:
	var body := _mat(Color(0.5, 0.52, 0.42))
	var dark := _mat(Color(0.18, 0.18, 0.17), 0.3)
	for side in [-1.0, 1.0]:
		var hip := _pivot(_vis, Vector3(0, 2.3, 0.55 * side))
		_box(hip, Vector3(0.45, 1.3, 0.45), body, Vector3(0.1, -0.6, 0), Vector3(0, 0, -0.2))
		_box(hip, Vector3(0.38, 1.2, 0.38), dark, Vector3(0.0, -1.6, 0), Vector3(0, 0, 0.2))
		_box(hip, Vector3(1.1, 0.25, 0.6), dark, Vector3(0.25, -2.2, 0))
		_legs.append(hip)
	_box(_vis, Vector3(1.9, 1.2, 1.7), body, Vector3(0, 3.0, 0))
	_box(_vis, Vector3(0.6, 0.45, 1.3), _glass_mat(), Vector3(0.85, 3.2, 0))
	for side in [-1.0, 1.0]:
		_box(_vis, Vector3(0.6, 0.6, 0.5), dark, Vector3(0.1, 3.0, 1.1 * side))
		_cyl(_vis, 0.13, 1.4, dark, Vector3(0.8, 2.85, 1.1 * side), Vector3(0, 0, PI / 2))
	_box(_vis, Vector3(0.9, 0.7, 1.0), body, Vector3(-0.9, 3.4, 0))
	_cyl(_vis, 0.03, 1.0, dark, Vector3(-0.6, 4.1, 0.5))
	_mi(_vis, _sphere_mesh(0.12), _light_mat, Vector3(-0.6, 4.6, 0.5), Vector3.ZERO)


func _build_apc() -> void:
	var body := _mat(Color(0.36, 0.4, 0.28))
	var dark := _mat(Color(0.12, 0.12, 0.11), 0.2)
	_wheels(dark, [-1.5, -0.5, 0.5, 1.5], 1.0, 0.5)
	_box(_vis, Vector3(4.4, 1.2, 1.9), body, Vector3(0, 1.3, 0))
	_box(_vis, Vector3(1.1, 0.8, 1.9), body, Vector3(2.35, 1.1, 0), Vector3(0, 0, 0.6))
	_box(_vis, Vector3(0.1, 0.35, 1.2), _glass_mat(), Vector3(2.1, 1.75, 0), Vector3(0, 0, 0.6))
	_box(_vis, Vector3(0.1, 1.0, 1.2), dark, Vector3(-2.22, 1.3, 0))
	for side in [-1.0, 1.0]:
		_box(_vis, Vector3(3.6, 0.08, 0.08), dark, Vector3(-0.2, 1.75, 0.96 * side))
	_turret = _pivot(_vis, Vector3(0.3, 2.0, 0))
	_cyl(_turret, 0.4, 0.35, body, Vector3.ZERO)
	_cyl(_turret, 0.06, 1.3, dark, Vector3(0.7, 0.1, 0), Vector3(0, 0, PI / 2))
	_mi(_vis, _sphere_mesh(0.12), _light_mat, Vector3(-0.8, 2.0, 0.6), Vector3.ZERO)


func _glass_mat() -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.1, 0.15, 0.2)
	g.metallic = 0.9
	g.roughness = 0.1
	g.emission_enabled = true
	g.emission = Color(0.3, 0.6, 0.9)
	g.emission_energy_multiplier = 0.6
	return g


func _sphere_mesh(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s
