class_name Building
extends Node3D
## Destructible building. Takes damage from attacks (try_hit / try_beam),
## darkens as it is damaged, and collapses into the street with debris.

const SHADER := preload("res://shaders/building.gdshader")
const WALLS := [Color(0.34, 0.36, 0.4), Color(0.45, 0.4, 0.34), Color(0.28, 0.3, 0.36),
	Color(0.5, 0.48, 0.45), Color(0.3, 0.25, 0.24)]
const LIGHTS := [Color(1.0, 0.78, 0.45), Color(0.75, 0.9, 1.0), Color(1.0, 0.9, 0.7)]

var size := Vector3(8, 16, 7)
var hp := 60.0
var max_hp := 60.0
var destroyed := false

var _holder: Node3D
var _mat: ShaderMaterial
var _beacon_mat: StandardMaterial3D
var _shake := 0.0
var _t := 0.0


static func make_material(seed_value: float, lit_ratio: float, emission: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var wall: Color = WALLS[int(seed_value * 7.0) % WALLS.size()]
	m.set_shader_parameter("wall_color", wall)
	m.set_shader_parameter("trim_color", wall.darkened(0.35))
	m.set_shader_parameter("lit_color", LIGHTS[int(seed_value * 13.0) % LIGHTS.size()])
	m.set_shader_parameter("seed", seed_value)
	m.set_shader_parameter("lit_ratio", lit_ratio)
	m.set_shader_parameter("emission_strength", emission)
	m.set_shader_parameter("cell", Vector2(randf_range(1.3, 2.0), randf_range(1.8, 2.4)))
	return m


func _ready() -> void:
	add_to_group("buildings")
	max_hp = 25.0 + size.x * size.y * 0.35
	hp = max_hp
	_holder = Node3D.new()
	add_child(_holder)
	_mat = make_material(randf() * 10.0, randf_range(0.2, 0.4), 1.3)
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _mat
	mi.position.y = size.y * 0.5
	_holder.add_child(mi)

	# Rooftop clutter.
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.3, 0.32)
	roof_mat.roughness = 0.8
	if size.y > 6.0:
		var unit := BoxMesh.new()
		unit.size = Vector3(size.x * randf_range(0.2, 0.4), randf_range(0.8, 1.6), size.z * randf_range(0.2, 0.4))
		_add(unit, roof_mat, Vector3(randf_range(-0.2, 0.2) * size.x, size.y + unit.size.y * 0.5, randf_range(-0.2, 0.2) * size.z))
	if size.y > 12.0:
		var mast := CylinderMesh.new()
		mast.top_radius = 0.05
		mast.bottom_radius = 0.12
		mast.height = randf_range(3.0, 6.0)
		var mx := size.x * 0.25
		_add(mast, roof_mat, Vector3(mx, size.y + mast.height * 0.5, 0))
		_beacon_mat = StandardMaterial3D.new()
		_beacon_mat.albedo_color = Color(1, 0.1, 0.1)
		_beacon_mat.emission_enabled = true
		_beacon_mat.emission = Color(1, 0.1, 0.05)
		var bulb := SphereMesh.new()
		bulb.radius = 0.2
		bulb.height = 0.4
		_add(bulb, _beacon_mat, Vector3(mx, size.y + mast.height, 0))
	Game.buildings_total += 1


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_holder.add_child(mi)


func _aabb() -> AABB:
	return AABB(global_position - Vector3(size.x * 0.5, 0, size.z * 0.5), size)


func try_hit(center: Vector3, radius: float, dmg: float) -> bool:
	if destroyed:
		return false
	var box := _aabb()
	var closest := center.clamp(box.position, box.end)
	if closest.distance_to(center) > radius:
		return false
	damage(dmg, closest)
	return true


func try_beam(origin: Vector3, dir: float, length: float, dmg: float) -> bool:
	if destroyed:
		return false
	var box := _aabb()
	var x1 := origin.x + dir * length
	if maxf(origin.x, x1) < box.position.x or minf(origin.x, x1) > box.end.x:
		return false
	if absf(global_position.z - origin.z) > size.z * 0.5 + 8.0:
		return false
	var hit_x := clampf(origin.x + dir * 2.0, box.position.x, box.end.x)
	var face_z := box.end.z if origin.z > global_position.z else box.position.z
	damage(dmg, Vector3(hit_x, minf(origin.y, size.y - 0.5), face_z))
	return true


func damage(dmg: float, at: Vector3) -> void:
	if destroyed:
		return
	hp -= dmg
	_mat.set_shader_parameter("damage", clampf(1.0 - hp / max_hp, 0.0, 1.0))
	_shake = 0.3
	FX.debris_burst(at, 0.6)
	if hp <= 0.0:
		_destroy()


func _process(delta: float) -> void:
	_t += delta
	if _beacon_mat:
		_beacon_mat.emission_energy_multiplier = 6.0 if fmod(_t, 1.4) < 0.25 else 0.2
	if _shake > 0.0 and not destroyed:
		_shake -= delta
		_holder.position.x = randf_range(-1.0, 1.0) * _shake * 0.5
		_holder.position.z = randf_range(-1.0, 1.0) * _shake * 0.5
	elif not destroyed:
		_holder.position.x = 0.0
		_holder.position.z = 0.0


func _destroy() -> void:
	destroyed = true
	remove_from_group("buildings")
	Game.on_building_destroyed(self, size.y)
	Game.shake(0.4 + size.y * 0.02)
	var c := global_position + Vector3(0, size.y * 0.5, size.z * 0.5)
	FX.explosion(c, clampf(size.y / 10.0, 0.8, 2.2))
	FX.smoke(global_position + Vector3(0, 1, size.z * 0.3), clampf(size.x / 5.0, 1.0, 2.5), Color(0.5, 0.46, 0.4))
	_spawn_chunks()

	var tw := create_tween()
	tw.tween_property(_holder, "position:y", -size.y - 1.0, 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_holder, "rotation:z", randf_range(-0.12, 0.12), 1.6)
	tw.tween_callback(_holder.queue_free)
	_add_rubble()

	if randf() < 0.35:
		var orb := Pickup.new()
		orb.position = Vector3(global_position.x, 1.5, clampf(global_position.z, -4.5, 2.5))
		get_parent().add_child(orb)


func _spawn_chunks() -> void:
	var count := clampi(int(size.y * 0.6), 5, 14)
	for i in count:
		var rb := RigidBody3D.new()
		rb.collision_layer = Game.LAYER_DEBRIS
		rb.collision_mask = Game.LAYER_WORLD
		var s := Vector3(randf_range(0.6, 1.6), randf_range(0.5, 1.4), randf_range(0.6, 1.6))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s
		col.shape = shape
		rb.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s
		mi.mesh = bm
		mi.material_override = _mat
		rb.add_child(mi)
		get_parent().add_child(rb)
		rb.global_position = global_position + Vector3(randf_range(-0.5, 0.5) * size.x, randf_range(0.3, 0.9) * size.y, randf_range(-0.5, 0.5) * size.z)
		rb.apply_central_impulse(Vector3(randf_range(-6, 6), randf_range(4, 12), randf_range(1, 9)) * rb.mass)
		rb.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		var tw := rb.create_tween()
		tw.tween_interval(randf_range(4.0, 6.0))
		tw.tween_property(rb, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(rb.queue_free)


func _add_rubble() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.28, 0.27)
	mat.roughness = 1.0
	for i in 5:
		var b := BoxMesh.new()
		b.size = Vector3(size.x * randf_range(0.3, 0.6), randf_range(0.5, 1.6), size.z * randf_range(0.3, 0.6))
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.3, 0.3) * size.x, b.size.y * 0.3, randf_range(-0.3, 0.3) * size.z)
		mi.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		add_child(mi)
