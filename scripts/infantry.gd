class_name Infantry
extends Kaiju
## Foot soldier. `kind` picks the weapon (stats from Enemies.DEFS):
##   soldier - rifle squad: short bursts from mid range
##   rocket  - shoulder launcher: slow rocket that bursts on impact
##   flamer  - flamethrower: closes in and sprays burning fire
## Tiny next to a kaiju: any hit sends them flying. They hold a firing band
## around the nearest kaiju and scatter when one gets too close.

var kind := "soldier"
var def: Dictionary = {}
var hp_mul := 1.0
var dmg_mul := 1.0
var speed := 5.5
var dmg := 3.0

var _vis: Node3D
var _legs: Array[Node3D] = []
var _arms: Node3D
var _band := Vector2(7.0, 14.0)
var _cd := 1.5
var _act_t := -1.0
var _shots := 0
var _walk := 0.0
var _z_bias := 0.0
var _panic := 0.0
var _vyaw := 0.0
## 1 right after a shot, decays: the weapon kicks up and the soldier rocks.
var _recoil := 0.0
var _t := 0.0
var _arm_rest := 0.5
var _mats: Array[StandardMaterial3D] = []
var _muzzle_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemies")
	if def.is_empty():
		def = Enemies.get_def(kind)
	max_hp = float(def.get("hp", 10.0)) * hp_mul
	dmg = float(def.get("dmg", 3.0)) * dmg_mul
	speed = float(def.get("speed", 5.5)) * randf_range(0.9, 1.1)
	init_body(0.55, 2.4, Game.LAYER_ENEMY)
	hit_radius = 1.4
	hit_height = 1.3
	z_min = -5.2
	z_max = 3.0
	_z_bias = randf_range(-2.5, 2.5)
	_cd = randf_range(0.8, 2.2)
	match kind:
		"rocket":
			_band = Vector2(10.0, 18.0)
		"flamer":
			_band = Vector2(2.5, 5.5)
		_:
			_band = Vector2(6.0 + randf() * 2.0, 13.0 + randf() * 3.0)
	_build()
	_vyaw = 0.0 if facing > 0.0 else PI
	_vis.rotation.y = _vyaw


func display_name() -> String:
	return String(def.get("name", kind.to_upper()))


func _physics_process(delta: float) -> void:
	for m in _mats:
		m.emission = m.emission.lerp(Color.BLACK, 1.0 - exp(-12.0 * delta))
	_muzzle_mat.emission_energy_multiplier = maxf(_muzzle_mat.emission_energy_multiplier - delta * 40.0, 0.0)
	if dead:
		return
	var p := Game.nearest_player(global_position) as Kaiju
	var mv := Vector3.ZERO
	if frozen_t <= 0.0 and p and hitstun <= 0.0:
		mv = _think(delta, p)
	hitstun = maxf(hitstun - delta, 0.0)
	move_body(delta, mv)
	var target := 0.0 if facing > 0.0 else -PI
	_vyaw = lerpf(_vyaw, target, 1.0 - exp(-12.0 * delta))
	_vis.rotation.y = _vyaw
	_animate(delta, mv)


func _think(delta: float, p: Kaiju) -> Vector3:
	var dx := p.global_position.x - global_position.x
	var adx := absf(dx)
	var mv := Vector3.ZERO
	_panic = maxf(_panic - delta, 0.0)
	if adx < 3.0 and kind != "flamer":
		_panic = 1.2
	if _act_t >= 0.0:
		_act_t += delta
		face_toward(dx)
		_fire(p)
		return mv
	if _panic > 0.0:
		# Run for it.
		face_toward(-dx)
		mv.x = -signf(dx) * speed * 1.3
		mv.z = signf(_z_bias) * speed * 0.5
	else:
		face_toward(dx)
		if adx < _band.x:
			mv.x = -signf(dx) * speed
		elif adx > _band.y:
			mv.x = signf(dx) * speed
		var dz := (p.global_position.z + _z_bias) - global_position.z
		if absf(dz) > 0.5:
			mv.z = signf(dz) * speed * 0.6
		_cd -= delta
		if _cd <= 0.0 and adx < _band.y + 4.0 and in_arena():
			_act_t = 0.0
			_shots = 0
	# Soldiers come in over the arena gates; inside they stay in the arena.
	var nx := global_position.x + mv.x * 0.3
	if global_position.x < arena.x:
		mv.x = speed
	elif global_position.x > arena.y:
		mv.x = -speed
	elif nx < arena.x or nx > arena.y:
		mv.x = 0.0
	return mv


func _fire(p: Kaiju) -> void:
	match kind:
		"rocket":
			if _act_t >= 0.7 and _shots == 0:
				_shots = 1
				var b := Projectile.new()
				b.style = "missile"
				b.color = Color(1.0, 0.6, 0.25)
				b.damage = dmg
				b.splash = 1.8
				b.size = 0.6
				get_parent().add_child(b)
				var m := _muzzle()
				b.global_position = m
				b.velocity = (p.hit_center() - m).normalized() * 20.0
				_flash_muzzle()
				FX.smoke(m - Vector3(facing * 0.8, 0, 0), 0.4, Color(0.8, 0.8, 0.78))
			if _act_t >= 1.2:
				_end(2.6, 3.6)
		"flamer":
			if _act_t >= 0.3 and _act_t <= 1.5 and fmod(_act_t, 0.1) < 0.017:
				var b := Projectile.new()
				b.color = Color(1.0, 0.5, 0.1)
				b.element = "fire"
				b.damage = dmg
				b.size = 0.55
				get_parent().add_child(b)
				var m := _muzzle()
				b.global_position = m
				var aim := (p.hit_center() - m).normalized()
				b.velocity = aim.rotated(Vector3.UP, randf_range(-0.15, 0.15)) * 14.0
				b.set("_life", 0.55)
				_flash_muzzle()
			if _act_t >= 1.6:
				_end(1.8, 2.6)
		_:
			if _act_t >= 0.35 + _shots * 0.12 and _shots < 3:
				_shots += 1
				var b := Projectile.new()
				b.style = "bullet"
				b.color = Color(1.0, 0.85, 0.35)
				b.damage = dmg
				b.size = 0.6
				get_parent().add_child(b)
				var m := _muzzle()
				b.global_position = m
				b.velocity = (p.hit_center() - m).normalized().rotated(Vector3.UP, randf_range(-0.06, 0.06)) * 30.0
				_flash_muzzle()
			if _act_t >= 0.9:
				_end(1.6, 2.8)


func _end(a: float, b: float) -> void:
	_act_t = -1.0
	_cd = randf_range(a, b)


func _muzzle() -> Vector3:
	return global_position + Vector3(facing * 1.2, 1.7, 0)


func _flash_muzzle() -> void:
	_recoil = 1.0
	_muzzle_mat.emission_energy_multiplier = 8.0
	FX.light_flash(_muzzle(), Color(1.0, 0.75, 0.3), 2.0, 3.0, 0.05)


func take_hit(dmg_in: float, kb: Vector3, from: Node3D = null) -> bool:
	# Anything a kaiju throws at a soldier is lethal-ish and sends them flying.
	return super.take_hit(dmg_in, kb * 1.6 + Vector3(0, 6, 0), from)


func _on_hurt(_dmg: float, _from: Node3D) -> void:
	for m in _mats:
		m.emission = Color(1, 1, 1)
	_act_t = -1.0
	hitstun = 0.35


func _on_death() -> void:
	collision_layer = 0
	Game.add_score(int(def.get("score", 150)))
	died.emit(self)
	FX.dust(global_position, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_vis, "rotation:z", randf_range(4.0, 8.0) * -facing, 0.8)
	tw.tween_property(_vis, "rotation:x", randf_range(-2.0, 2.0), 0.8)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(_vis, "scale", Vector3(1, 0.05, 1), 0.4)
	tw.chain().tween_callback(queue_free)
	# Keep flying with the knockback until it lands.
	set_physics_process(false)
	var fly := create_tween()
	var land := global_position + Vector3(knock.x * 0.5, 0, knock.z * 0.5)
	land.x = clampf(land.x, x_min, x_max)
	fly.tween_property(self, "global_position:x", land.x, 0.8)
	var up := create_tween()
	up.tween_property(self, "global_position:y", global_position.y + 2.5, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	up.tween_property(self, "global_position:y", 0.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _animate(delta: float, mv: Vector3) -> void:
	_t += delta
	var moving := clampf(Vector2(mv.x, mv.z).length() / maxf(speed, 0.1), 0.0, 1.5)
	_walk += delta * moving * 14.0
	_recoil = maxf(_recoil - delta * 9.0, 0.0)
	for i in _legs.size():
		_legs[i].rotation.z = sin(_walk + i * PI) * 0.8 * moving
	# Bob twice per stride, rock over the standing leg, breathe when still.
	_vis.position.y = absf(cos(_walk)) * 0.1 * moving + sin(_t * 2.4) * 0.015 * (1.0 - minf(moving, 1.0))
	_vis.rotation.x = sin(_walk) * 0.08 * moving
	var aiming := _act_t >= 0.0
	var lean := -0.25 * moving if not aiming else _recoil * 0.12
	_vis.rotation.z = lerpf(_vis.rotation.z, lean, 1.0 - exp(-10.0 * delta))
	# Arms raise the weapon to aim and kick up with each shot; walking they
	# sway with the stride, while panicking they flail.
	var want := 0.0 if aiming else (sin(_walk * 2.0) * 0.6 if _panic > 0.0 else 0.5 + sin(_walk) * 0.1 * moving)
	_arm_rest = lerpf(_arm_rest, want, 1.0 - exp(-12.0 * delta))
	_arms.rotation.z = _arm_rest + _recoil * _recoil * 0.06


# --- model -------------------------------------------------------------------

func _build() -> void:
	_vis = Node3D.new()
	_vis.scale = Vector3.ONE * 1.35
	add_child(_vis)
	var ci: int = Game.level.get("country", 0)
	var camo := Color(0.3, 0.36, 0.2)
	if ci == 4 or ci == 6:
		camo = Color(0.62, 0.52, 0.34)
	elif ci == 7 or ci == 8:
		camo = Color(0.72, 0.74, 0.76)
	var uni := _mat(camo)
	var dark := _mat(camo.darkened(0.45))
	var skin := _mat(Color(0.85, 0.65, 0.5).darkened(randf() * 0.5))
	var gun := _mat(Color(0.12, 0.12, 0.13), 0.6)
	_muzzle_mat = StandardMaterial3D.new()
	_muzzle_mat.albedo_color = Color(1.0, 0.7, 0.3)
	_muzzle_mat.emission_enabled = true
	_muzzle_mat.emission = Color(1.0, 0.65, 0.2)
	_muzzle_mat.emission_energy_multiplier = 0.0
	# Stylised and a bit oversized so they read at kaiju scale.
	for side in [-1.0, 1.0]:
		var hip := _pivot(_vis, Vector3(0, 0.75, 0.13 * side))
		_box(hip, Vector3(0.2, 0.7, 0.2), uni, Vector3(0, -0.35, 0))
		_box(hip, Vector3(0.28, 0.12, 0.22), dark, Vector3(0.05, -0.7, 0))
		_legs.append(hip)
	_box(_vis, Vector3(0.36, 0.6, 0.5), uni, Vector3(0, 1.08, 0))
	_box(_vis, Vector3(0.4, 0.35, 0.54), dark, Vector3(-0.05, 1.12, 0))
	if kind == "flamer":
		# Fuel tanks on the back.
		for side in [-1.0, 1.0]:
			_cyl(_vis, 0.11, 0.5, _mat(Color(0.65, 0.2, 0.12)), Vector3(-0.3, 1.1, 0.12 * side))
	_sphere(_vis, 0.15, skin, Vector3(0.02, 1.55, 0))
	# Helmet.
	_sphere(_vis, 0.19, dark, Vector3(0, 1.62, 0), Vector3(1.1, 0.7, 1.1))
	_arms = _pivot(_vis, Vector3(0.05, 1.3, 0))
	for side in [-1.0, 1.0]:
		_box(_arms, Vector3(0.45, 0.13, 0.13), uni, Vector3(0.2, -0.05, 0.22 * side), Vector3(0, 0.4 * side, 0))
	match kind:
		"rocket":
			_cyl(_arms, 0.12, 1.4, dark, Vector3(0.1, 0.25, 0.18), Vector3(0, 0, PI / 2))
			_cyl(_arms, 0.08, 0.05, _muzzle_mat, Vector3(0.82, 0.25, 0.18), Vector3(0, 0, PI / 2))
		"flamer":
			_cyl(_arms, 0.05, 0.8, gun, Vector3(0.6, -0.05, 0), Vector3(0, 0, PI / 2))
			_sphere(_arms, 0.07, _muzzle_mat, Vector3(1.0, -0.05, 0))
		_:
			_box(_arms, Vector3(0.75, 0.1, 0.08), gun, Vector3(0.5, 0.0, 0))
			_box(_arms, Vector3(0.08, 0.2, 0.06), gun, Vector3(0.35, -0.12, 0))
			_sphere(_arms, 0.05, _muzzle_mat, Vector3(0.9, 0.0, 0))


func _mat(c: Color, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission = Color.BLACK
	_mats.append(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mi(parent, b, mat, pos, rot, Vector3.ONE)


func _cyl(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	_mi(parent, c, mat, pos, rot, Vector3.ONE)


func _sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	_mi(parent, s, mat, pos, Vector3.ZERO, scl)


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, scl: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)
