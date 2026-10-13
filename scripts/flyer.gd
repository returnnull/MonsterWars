class_name Flyer
extends Node3D
## Military attack drone. Hovers out of reach and fires plasma bolts.
## Hit it with jump stomps, spin attacks or the beam.

signal died(who: Node)

var hp := 35.0
var dead := false
var hit_radius := 1.5

var _vel := Vector3.ZERO
var _fire_cd := 2.0
var _side := 1.0
var _t := 0.0
var _flash := 0.0
var _rotors: Array[Node3D] = []
var _swoop := 0.0
var _swoop_cd := 4.0
var _hull_mat: StandardMaterial3D
var _warn_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemies")
	_side = 1.0 if randf() > 0.5 else -1.0
	_t = randf() * 10.0
	_fire_cd = randf_range(1.5, 2.5)
	_build()


func hit_center() -> Vector3:
	return global_position


func take_hit(dmg: float, kb: Vector3, _from: Node3D = null) -> bool:
	if dead:
		return false
	hp -= dmg
	_flash = 1.0
	_vel += kb * 0.6
	if hp <= 0.0:
		dead = true
		_vel = kb * 0.5 + Vector3(0, 4, 0)
		Game.add_score(600)
		died.emit(self)
	return true


func _process(delta: float) -> void:
	_t += delta
	for r in _rotors:
		r.rotate_y(delta * 40.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_hull_mat.emission = Color(1, 1, 1) * _flash
	if dead:
		_vel.y -= 25.0 * delta
		rotate_z(delta * 5.0)
		rotate_x(delta * 3.0)
		global_position += _vel * delta
		if global_position.y < 0.6:
			FX.explosion(global_position, 1.2)
			Game.shake(0.3)
			queue_free()
		return

	var p := Game.player as Kaiju
	if p == null:
		return
	# Hover out of reach and shoot, then periodically swoop low across the
	# kaiju to the other side, which is the window to swat it.
	var target := p.global_position + Vector3(_side * 10.0 + sin(_t * 0.7) * 2.5, 6.2 + sin(_t * 1.3) * 0.9, -1.0 + sin(_t * 0.5) * 1.5)
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
	var want := (target - global_position) * 1.6
	want = want.limit_length(max_speed)
	_vel = _vel.lerp(want, 1.0 - exp(-2.5 * delta))
	global_position += _vel * delta
	var dx := p.global_position.x - global_position.x
	rotation.y = lerp_angle(rotation.y, 0.0 if dx > 0.0 else PI, 1.0 - exp(-6.0 * delta))
	rotation.z = clampf(-_vel.x * 0.03 * (1.0 if dx > 0.0 else -1.0), -0.4, 0.4)

	_fire_cd -= delta
	var warning := _fire_cd < 0.45
	_warn_mat.emission_energy_multiplier = 8.0 if (warning and fmod(_t, 0.12) < 0.06) else 1.5
	if _swoop > 0.0:
		_fire_cd = maxf(_fire_cd, 0.8)
	if _fire_cd <= 0.0 and absf(dx) < 24.0 and not p.dead:
		_fire(p)
		_fire_cd = randf_range(1.8, 3.0)


func _fire(p: Kaiju) -> void:
	var b := Projectile.new()
	get_parent().add_child(b)
	b.global_position = global_position
	b.velocity = (p.hit_center() - global_position).normalized() * 20.0
	FX.light_flash(global_position, Color(1.0, 0.5, 0.2), 4.0, 6.0, 0.15)


func _build() -> void:
	_hull_mat = StandardMaterial3D.new()
	_hull_mat.albedo_color = Color(0.3, 0.34, 0.3)
	_hull_mat.metallic = 0.6
	_hull_mat.roughness = 0.35
	_hull_mat.emission_enabled = true
	_hull_mat.emission = Color.BLACK
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.2, 0.3)
	glass.metallic = 0.9
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = Color(0.2, 0.6, 1.0)
	glass.emission_energy_multiplier = 0.8
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.albedo_color = Color(1, 0.2, 0.1)
	_warn_mat.emission_enabled = true
	_warn_mat.emission = Color(1, 0.15, 0.05)
	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.45)
	rotor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var body := CapsuleMesh.new()
	body.radius = 0.6
	body.height = 3.0
	_mi(body, _hull_mat, Vector3.ZERO, Vector3(0, 0, PI / 2))
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 0.8
	_mi(canopy, glass, Vector3(0.9, 0.3, 0))
	var tail := BoxMesh.new()
	tail.size = Vector3(2.2, 0.25, 0.25)
	_mi(tail, _hull_mat, Vector3(-2.2, 0.15, 0))
	var fin := BoxMesh.new()
	fin.size = Vector3(0.6, 0.9, 0.08)
	_mi(fin, _hull_mat, Vector3(-3.1, 0.5, 0))
	var wing := BoxMesh.new()
	wing.size = Vector3(0.9, 0.12, 3.6)
	_mi(wing, _hull_mat, Vector3(0, 0.1, 0))
	for side in [-1.0, 1.0]:
		var pod := CylinderMesh.new()
		pod.top_radius = 0.28
		pod.bottom_radius = 0.28
		pod.height = 0.6
		_mi(pod, _hull_mat, Vector3(0, 0.3, 1.8 * side))
		var rotor := Node3D.new()
		rotor.position = Vector3(0, 0.65, 1.8 * side)
		add_child(rotor)
		var disc := CylinderMesh.new()
		disc.top_radius = 1.2
		disc.bottom_radius = 1.2
		disc.height = 0.03
		var dmi := MeshInstance3D.new()
		dmi.mesh = disc
		dmi.material_override = rotor_mat
		rotor.add_child(dmi)
		var blade := BoxMesh.new()
		blade.size = Vector3(2.4, 0.04, 0.18)
		var bmi := MeshInstance3D.new()
		bmi.mesh = blade
		bmi.material_override = _hull_mat
		rotor.add_child(bmi)
		_rotors.append(rotor)
	var gun := CylinderMesh.new()
	gun.top_radius = 0.1
	gun.bottom_radius = 0.14
	gun.height = 1.0
	_mi(gun, _hull_mat, Vector3(1.2, -0.45, 0), Vector3(0, 0, PI / 2))
	var lamp := SphereMesh.new()
	lamp.radius = 0.14
	lamp.height = 0.28
	_mi(lamp, _warn_mat, Vector3(-3.3, 0.95, 0))
	_mi(lamp, _warn_mat, Vector3(1.75, -0.45, 0))


func _mi(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	add_child(m)
	return m
