class_name EnemyLook
extends RefCounted
## Extra procedural features bolted onto a built KaijuModel so the enemy
## kaiju types read differently: horns, shells, blades, glowing sacs, wings...
## Each feature attaches to one of the model's named pivots (falling back to
## the model root), so it keeps working if the base model is restyled.


static func add(model: KaijuModel, extras: Array, colors: Array) -> void:
	var skin: Color = colors[0]
	var belly: Color = colors[1]
	var spike: Color = colors[2]
	var bone := _mat(Color(0.85, 0.82, 0.72), 0.35)
	var glow := _glow(spike, 2.5)
	for e in extras:
		match e:
			"nose_horn":
				var head := _p(model, "head")
				_cone(head, 0.32, 1.6, bone, Vector3(1.25, 0.45, 0), Vector3(0, 0, -0.5))
				_cone(head, 0.18, 0.7, bone, Vector3(0.7, 0.6, 0), Vector3(0, 0, -0.3))
			"crest":
				var head := _p(model, "head")
				for i in 3:
					var fin := _box(Vector3(0.55 - i * 0.1, 0.9 - i * 0.18, 0.08))
					_add(head, fin, glow, Vector3(0.1 - i * 0.45, 0.75 - i * 0.08, 0), Vector3(0, 0, 0.35))
			"shell":
				var torso := _p(model, "torso")
				var shell_mat := _mat(skin.lerp(belly, 0.35).darkened(0.15), 0.5)
				var s := _sphere(1.0)
				_add(torso, s, shell_mat, Vector3(-0.35, 1.5, 0), Vector3(0, 0, -0.35), Vector3(1.55, 1.25, 1.45))
				for i in 4:
					var ridge := _box(Vector3(0.35, 0.3, 2.4))
					var a := -0.9 + i * 0.6
					_add(torso, ridge, _mat(skin.darkened(0.35), 0.6),
						Vector3(-0.35 + sin(a) * 1.45, 1.5 + cos(a) * 1.2, 0), Vector3(0, 0, -a - 0.35))
			"blades":
				for arm in ["arm_r_fore", "arm_l_fore"]:
					var fore := _p(model, arm)
					var blade := _box(Vector3(0.14, 2.4, 0.3))
					_add(fore, blade, _glow(spike.lerp(Color.WHITE, 0.4), 0.8), Vector3(0.45, -1.0, 0), Vector3(0, 0, 0.5))
			"sacs":
				var torso := _p(model, "torso")
				for i in 3:
					var sac := _sphere(0.42 - i * 0.06)
					_add(torso, sac, glow, Vector3(-0.75 - i * 0.1, 0.6 + i * 0.75, (i - 1) * 0.55))
			"bomb_glow":
				var torso := _p(model, "torso")
				_add(torso, _sphere(0.9), _glow(spike, 3.5), Vector3(0.6, 1.0, 0), Vector3.ZERO, Vector3(1, 1, 1.1))
			"wings":
				var torso := _p(model, "torso")
				var wing_mat := _mat(skin.darkened(0.2), 0.8)
				for side in [-1.0, 1.0]:
					var wing := _box(Vector3(1.6, 2.6, 0.08))
					_add(torso, wing, wing_mat, Vector3(-0.8, 2.6, 0.9 * side), Vector3(0.55 * side, 0.35 * side, 0.5))
					_cone(torso, 0.1, 0.6, bone, Vector3(-1.2, 3.9, 1.5 * side), Vector3(0.5 * side, 0, 0.3))
			"stinger":
				var tail := _tail_end(model)
				_add(tail, _sphere(0.45), glow, Vector3(-1.0, 0.4, 0))
				_cone(tail, 0.2, 1.2, bone, Vector3(-0.7, 1.0, 0), Vector3(0, 0, -0.9))
			"tail_club":
				var tail := _tail_end(model)
				_add(tail, _sphere(0.7), _mat(skin.darkened(0.3), 0.5), Vector3(-1.1, 0, 0))
				for i in 4:
					var a := i * PI / 2.0
					_cone(tail, 0.14, 0.6, bone, Vector3(-1.1, cos(a) * 0.65, sin(a) * 0.65), Vector3(a, 0, 0))
			"hood":
				var head := _p(model, "head")
				var hood := _sphere(1.0)
				_add(head, hood, _mat(belly.lerp(spike, 0.3), 0.6), Vector3(-0.45, -0.1, 0), Vector3.ZERO, Vector3(0.25, 1.4, 1.6))
				for side in [-1.0, 1.0]:
					_add(head, _sphere(0.18), glow, Vector3(-0.32, 0.25, 0.75 * side))
			"snout":
				var head := _p(model, "head")
				_add(head, _box(Vector3(1.8, 0.4, 0.7)), _mat(skin, 0.7), Vector3(1.5, -0.12, 0))
				for i in 6:
					_cone(head, 0.06, 0.25, bone, Vector3(0.9 + i * 0.3, -0.38, 0.3 * (1 if i % 2 == 0 else -1)), Vector3(PI, 0, 0))
				var jaw := _p(model, "jaw")
				_add(jaw, _box(Vector3(1.7, 0.22, 0.6)), _mat(belly, 0.6), Vector3(1.55, -0.05, 0))
			"crystals":
				var torso := _p(model, "torso")
				for i in 5:
					var c := CylinderMesh.new()
					c.top_radius = 0.0
					c.bottom_radius = 0.22
					c.height = 0.9 + (i % 2) * 0.5
					c.radial_segments = 4
					_add(torso, c, glow, Vector3(-0.85 + i * 0.12, 0.3 + i * 0.6, (i % 3 - 1) * 0.35), Vector3(0.3 * (i % 3 - 1), 0, 0.9))
			"armor_plates":
				var steel := _mat(Color(0.55, 0.57, 0.6), 0.3)
				steel.metallic = 0.85
				var torso := _p(model, "torso")
				_add(torso, _box(Vector3(1.0, 2.0, 1.9)), steel, Vector3(0.45, 1.3, 0), Vector3(0, 0, -0.35))
				_add(_p(model, "head"), _box(Vector3(1.1, 0.35, 1.0)), steel, Vector3(0.2, 0.5, 0))
				for arm in ["arm_r", "arm_l"]:
					_add(_p(model, arm), _box(Vector3(0.75, 0.9, 0.75)), steel, Vector3(0, -0.3, 0))
				for leg in ["leg_r", "leg_l"]:
					_add(_p(model, leg), _box(Vector3(1.3, 1.0, 1.25)), steel, Vector3(0.1, -0.7, 0))
				_add(torso, _box(Vector3(0.4, 0.4, 0.5)), glow, Vector3(0.95, 1.3, 0))
			"antenna":
				var head := _p(model, "head")
				for side in [-1.0, 1.0]:
					var rod := CylinderMesh.new()
					rod.top_radius = 0.03
					rod.bottom_radius = 0.06
					rod.height = 1.3
					_add(head, rod, _mat(Color(0.3, 0.3, 0.32), 0.3), Vector3(-0.2, 0.95, 0.3 * side), Vector3(0.3 * side, 0, 0.5))
					_add(head, _sphere(0.13), glow, Vector3(-0.5, 1.55, 0.5 * side))


static func _p(model: KaijuModel, part: String) -> Node3D:
	var n: Node3D = model.parts.get(part)
	return n if n else model


static func _tail_end(model: KaijuModel) -> Node3D:
	var last: Node3D = model
	for i in 12:
		if model.parts.has("tail%d" % i):
			last = model.parts["tail%d" % i]
	return last


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.3
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.2)
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _cone(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot: Vector3) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	_add(parent, c, mat, pos, rot)


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi
