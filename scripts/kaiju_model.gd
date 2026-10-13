class_name KaijuModel
extends Node3D
## A kaiju assembled from primitive meshes, with procedural animation.
## Faces +X and has its origin at the feet. The owner sets the pose targets
## (walk_amount, arm_r, arm_l, jaw, lean, spin, glow) every frame.

static var _scale_normal: NoiseTexture2D

var parts := {}
var walk_amount := 0.0
var walk_speed := 1.0
var arm_r := 0.25
var arm_l := 0.25
var jaw := 0.0
var lean := 0.0
var spin := 0.0
var glow := 0.0
var eye_glow := 0.0

var _body_mats: Array[StandardMaterial3D] = []
var _eye_mat: StandardMaterial3D
var _spike_mat: StandardMaterial3D
var _tail: Array[Node3D] = []
var _flash := 0.0
var _t := 0.0
var _walk := 0.0
var _phase := 0.0
var _spike_color := Color.WHITE
var _cur := {"arm_r": 0.25, "arm_l": 0.25, "jaw": 0.0, "lean": 0.0}


func build(skin: Color, belly: Color, spike: Color, eye: Color, horns: bool = false) -> void:
	_spike_color = spike
	var skin_mat := _skin(skin, 0.7, true)
	var belly_mat := _skin(belly, 0.55, false)
	var claw_mat := _skin(Color(0.85, 0.82, 0.75), 0.3, false)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = eye
	_eye_mat.emission_enabled = true
	_eye_mat.emission = eye
	_eye_mat.emission_energy_multiplier = 3.0
	_spike_mat = StandardMaterial3D.new()
	_spike_mat.albedo_color = spike.darkened(0.45)
	_spike_mat.roughness = 0.25
	_spike_mat.emission_enabled = true
	_spike_mat.emission = spike
	_spike_mat.emission_energy_multiplier = 0.3

	var hips := _pivot("hips", self, Vector3(0, 2.4, 0))
	var torso := _pivot("torso", hips, Vector3.ZERO)
	_part(torso, _capsule(1.1, 3.9), skin_mat, Vector3(0.3, 1.3, 0), Vector3(0, 0, -0.35))
	_part(torso, _capsule(0.8, 3.0), belly_mat, Vector3(0.68, 1.05, 0), Vector3(0, 0, -0.35), Vector3(1, 1, 0.95))

	# Dorsal plates along the back, glowing with rage.
	var up := Vector2(0.34, 0.94)
	var back := Vector2(-0.94, 0.34)
	for i in 7:
		var s := -1.4 + i * 0.5
		var h := 0.6 + sin(float(i) / 6.0 * PI) * 0.7
		var p2 := Vector2(0.3, 1.3) + up * s + back * 0.95
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.28
		cone.height = h
		cone.radial_segments = 6
		var pos := Vector3(p2.x, p2.y, 0) + Vector3(back.x, back.y, 0) * h * 0.4
		_part(torso, cone, _spike_mat, pos, Vector3(0, 0, atan2(-back.x, back.y)), Vector3(1, 1, 0.45))

	# Head, snout and jaw.
	var head := _pivot("head", torso, Vector3(1.05, 3.05, 0))
	_part(head, _sphere(0.72), skin_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1.25, 0.95, 0.95))
	_part(head, _box(Vector3(1.15, 0.55, 0.85)), skin_mat, Vector3(0.8, -0.08, 0))
	var jaw_pivot := _pivot("jaw", head, Vector3(0.2, -0.36, 0))
	_part(jaw_pivot, _box(Vector3(1.2, 0.26, 0.75)), belly_mat, Vector3(0.55, -0.05, 0))
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.13), _eye_mat, Vector3(0.62, 0.22, 0.4 * side))
		for i in 4:
			var tooth := CylinderMesh.new()
			tooth.top_radius = 0.0
			tooth.bottom_radius = 0.07
			tooth.height = 0.22
			tooth.radial_segments = 4
			_part(head, tooth, claw_mat, Vector3(0.45 + i * 0.25, -0.42, 0.33 * side), Vector3(PI, 0, 0))
		if horns:
			var horn := CylinderMesh.new()
			horn.top_radius = 0.0
			horn.bottom_radius = 0.16
			horn.height = 1.1
			_part(head, horn, claw_mat, Vector3(-0.35, 0.65, 0.35 * side), Vector3(0.25 * side, 0, 0.9))

	# Arms with claws.
	for side in [1.0, -1.0]:
		var arm_name := "arm_r" if side > 0 else "arm_l"
		var arm := _pivot(arm_name, torso, Vector3(1.05, 2.3, 0.95 * side))
		_part(arm, _capsule(0.33, 1.5), skin_mat, Vector3(0, -0.6, 0))
		var fore := _pivot(arm_name + "_fore", arm, Vector3(0, -1.2, 0))
		fore.rotation.z = 0.7
		_part(fore, _capsule(0.27, 1.3), skin_mat, Vector3(0, -0.55, 0))
		for c in 3:
			var claw := CylinderMesh.new()
			claw.top_radius = 0.0
			claw.bottom_radius = 0.08
			claw.height = 0.45
			claw.radial_segments = 4
			_part(fore, claw, claw_mat, Vector3(0.1, -1.25, (c - 1) * 0.15), Vector3(0, 0, PI - 0.3))

	# Legs.
	for side in [1.0, -1.0]:
		var leg := _pivot("leg_r" if side > 0 else "leg_l", hips, Vector3(0, 0.1, 0.78 * side))
		_part(leg, _capsule(0.62, 2.1), skin_mat, Vector3(0.1, -0.9, 0))
		_part(leg, _box(Vector3(1.35, 0.45, 0.95)), skin_mat, Vector3(0.35, -2.27, 0))
		for c in 3:
			var toe := CylinderMesh.new()
			toe.top_radius = 0.0
			toe.bottom_radius = 0.1
			toe.height = 0.35
			toe.radial_segments = 4
			_part(leg, toe, claw_mat, Vector3(1.1, -2.35, (c - 1) * 0.3), Vector3(0, 0, -PI / 2))

	# Tail: a chain of shrinking segments.
	var parent: Node3D = hips
	var offset := Vector3(-0.8, 0.4, 0)
	for i in 7:
		var seg := _pivot("tail%d" % i, parent, offset)
		var r := 0.78 * (1.0 - i * 0.12)
		_part(seg, _capsule(r, maxf(r * 2.0, 1.3)), skin_mat, Vector3(-0.5, 0, 0), Vector3(0, 0, PI / 2))
		if i % 2 == 0:
			var plate := CylinderMesh.new()
			plate.top_radius = 0.0
			plate.bottom_radius = 0.22
			plate.height = 0.4 + r * 0.4
			plate.radial_segments = 6
			_part(seg, plate, _spike_mat, Vector3(-0.5, r + 0.1, 0), Vector3.ZERO, Vector3(1, 1, 0.45))
		_tail.append(seg)
		parent = seg
		offset = Vector3(-0.95, -0.1, 0)


func spike_color() -> Color:
	return _spike_color


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if parts.is_empty():
		return
	_t += delta
	_walk = lerpf(_walk, walk_amount, 1.0 - exp(-10.0 * delta))
	_phase += delta * 8.5 * walk_speed * maxf(_walk, 0.05)
	var k := 1.0 - exp(-16.0 * delta)
	_cur["arm_r"] = lerpf(_cur["arm_r"], arm_r, k)
	_cur["arm_l"] = lerpf(_cur["arm_l"], arm_l, k)
	_cur["jaw"] = lerpf(_cur["jaw"], jaw, k)
	_cur["lean"] = lerpf(_cur["lean"], lean, k)

	var s := sin(_phase)
	var breathe := sin(_t * 2.0)
	parts["leg_r"].rotation.z = s * 0.6 * _walk
	parts["leg_l"].rotation.z = -s * 0.6 * _walk
	parts["hips"].position.y = 2.4 + absf(cos(_phase)) * 0.2 * _walk + breathe * 0.04
	parts["hips"].rotation.x = s * 0.05 * _walk
	parts["torso"].rotation.z = -_cur["lean"] + breathe * 0.02
	parts["arm_r"].rotation.z = _cur["arm_r"] - s * 0.35 * _walk
	parts["arm_l"].rotation.z = _cur["arm_l"] + s * 0.35 * _walk
	parts["head"].rotation.z = sin(_t * 1.7) * 0.05 + _cur["lean"] * 0.4
	parts["jaw"].rotation.z = -_cur["jaw"] * 0.7
	for i in _tail.size():
		var seg := _tail[i]
		seg.rotation.y = sin(_t * 2.2 - i * 0.7) * 0.12 * (1.0 + _walk)
		seg.rotation.z = -0.04 + sin(_t * 1.3 - i * 0.5) * 0.05

	if _flash > 0.0:
		_flash = maxf(_flash - delta * 7.0, 0.0)
		var c := Color(1, 0.95, 0.9) * _flash * 1.5
		for m in _body_mats:
			m.emission = c
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	_spike_mat.emission_energy_multiplier = 0.3 + glow * (3.0 + pulse * (3.0 if glow >= 1.0 else 0.0))
	_eye_mat.emission_energy_multiplier = 3.0 + eye_glow * 8.0


# --- construction helpers --------------------------------------------------

static func _scales() -> NoiseTexture2D:
	if _scale_normal == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.06
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 5.0
		t.noise = n
		_scale_normal = t
	return _scale_normal


func _skin(color: Color, roughness: float, scaly: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.5
	m.emission_enabled = true
	m.emission = Color.BLACK
	if scaly:
		m.normal_enabled = true
		m.normal_texture = _scales()
		m.normal_scale = 0.9
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.8, 0.8, 0.8)
	_body_mats.append(m)
	return m


func _pivot(pivot_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	parts[pivot_name] = n
	return n


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 20
	c.rings = 10
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
