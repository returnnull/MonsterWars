class_name ArenaGate
extends Node3D
## A barricade across the whole street that closes one side of an arena.
## The gate at an arena's right edge stands from the start of the level and
## blocks the way on; the left one rises behind the players when the fight
## starts. Both are smashed open when the wave is beaten. The blocking itself
## is done by main.gd (player x limits); this is what the players see.
##   kind: "barricade", "wreck", "containers", "energy" or "tank_traps".

const Z0 := -7.4
const Z1 := 6.8

var kind := "barricade"
var up := false

var _body: Node3D
var _lights: Array[StandardMaterial3D] = []
var _field: StandardMaterial3D
var _t := 0.0
var _mats := {}


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_build()
	_body.visible = false


func _process(delta: float) -> void:
	if not up:
		return
	_t += delta
	var blink := 0.5 + 0.5 * sin(_t * 6.0)
	for m in _lights:
		m.emission_energy_multiplier = 1.0 + blink * 5.0
	if _field:
		_field.albedo_color.a = 0.28 + 0.12 * sin(_t * 3.0)


## Shows the gate. Unless `instant`, it rises out of the ground with dust.
func raise(instant: bool = false) -> void:
	if up:
		return
	up = true
	_body.visible = true
	if instant:
		_body.position.y = 0.0
		return
	_body.position.y = -7.0
	var tw := create_tween()
	tw.tween_property(_body, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for z in [-5.0, -1.0, 3.0]:
		FX.dust(global_position + Vector3(0, 0.3, z), 1.6)
	Game.shake(0.35)


## Smashes the gate open: explosions along it, then it sinks away.
func open() -> void:
	if not up:
		return
	up = false
	var p := global_position
	if kind == "energy":
		FX.light_flash(p + Vector3(0, 4, 0), Color(0.4, 0.8, 1.0), 6.0, 20.0, 0.3)
		for z in [-5.0, -1.0, 3.0]:
			FX.energy(p + Vector3(0, 3, z), Color(0.4, 0.8, 1.0))
	else:
		for z in [-5.5, -2.0, 1.5, 5.0]:
			FX.explosion(p + Vector3(0, 1.5, z), 0.8)
			FX.debris_burst(p + Vector3(0, 2.0, z), 0.8)
	Game.shake(0.5)
	var tw := create_tween()
	tw.tween_property(_body, "position:y", -8.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _body.visible = false)


# --- looks -----------------------------------------------------------------

func _build() -> void:
	match kind:
		"wreck":
			_build_wreck()
		"containers":
			_build_containers()
		"energy":
			_build_energy()
		"tank_traps":
			_build_traps()
		_:
			_build_barricade()


## Two rows of concrete blocks with sandbags and a striped boom on top.
func _build_barricade() -> void:
	var concrete := _mat(Color(0.62, 0.6, 0.56), 0.9)
	var z := Z0
	while z < Z1:
		_box(Vector3(1.6, 1.6, 2.0), concrete, Vector3(0, 0.8, z + 1.0), randf_range(-0.05, 0.05))
		z += 2.1
	z = Z0 + 1.0
	while z < Z1 - 1.0:
		_box(Vector3(1.4, 1.4, 2.0), concrete, Vector3(0.05, 2.3, z + 1.0), randf_range(-0.08, 0.08))
		z += 2.15
	var bag := _mat(Color(0.5, 0.45, 0.32), 1.0)
	z = Z0 + 0.4
	while z < Z1:
		_box(Vector3(1.0, 0.5, 0.9), bag, Vector3(-1.2, 0.25, z), randf_range(-0.3, 0.3))
		_box(Vector3(1.0, 0.5, 0.9), bag, Vector3(-1.2, 0.72, z + 0.45), randf_range(-0.3, 0.3))
		z += 1.0
	_striped_boom(3.4)
	_warning_lights(3.6)


## A pile of wrecked cars and a bus on its side.
func _build_wreck() -> void:
	var cols := [Color(0.5, 0.12, 0.1), Color(0.2, 0.25, 0.35), Color(0.6, 0.6, 0.6), Color(0.7, 0.55, 0.1), Color(0.15, 0.15, 0.17)]
	_box(Vector3(2.6, 2.6, 10.0), _mat(Color(0.75, 0.6, 0.15).darkened(0.4), 0.6, 0.3), Vector3(0, 1.3, -1.0), 0.06)
	var z := Z0 + 0.5
	while z < Z1:
		var c: Color = cols[randi() % cols.size()].darkened(randf_range(0.3, 0.6))
		var car := _box(Vector3(1.6, 1.0, 2.8), _mat(c, 0.5, 0.4), Vector3(randf_range(-0.6, 0.6), 3.0 + randf() * 0.4, z), randf_range(-0.6, 0.6))
		car.rotation.z = randf_range(-0.4, 0.4)
		car.rotation.x = randf_range(-0.2, 0.2)
		z += randf_range(2.2, 3.0)
	for i in 4:
		var c: Color = cols[randi() % cols.size()].darkened(0.5)
		_box(Vector3(1.5, 1.0, 2.6), _mat(c, 0.5, 0.4), Vector3(0, 0.5, [Z0 + 1.0, 5.0, 6.0, -6.2][i]), randf_range(-0.8, 0.8))
	_warning_lights(4.2)


## Shipping containers stacked across the street.
func _build_containers() -> void:
	var cols := [Color(0.7, 0.18, 0.12), Color(0.15, 0.35, 0.6), Color(0.85, 0.55, 0.12), Color(0.2, 0.45, 0.3)]
	for layer in 2:
		var z := Z0 + (0.0 if layer == 0 else 1.5)
		while z < Z1 - (0.0 if layer == 0 else 1.5):
			var box_len := 6.0
			_box(Vector3(2.4, 2.5, box_len), _mat(cols[randi() % cols.size()], 0.6, 0.3),
				Vector3(randf_range(-0.2, 0.2), 1.25 + layer * 2.55, z + box_len * 0.5), randf_range(-0.04, 0.04))
			z += box_len + 0.2
	_warning_lights(5.2)


## A force field between two pylons.
func _build_energy() -> void:
	var metal := _mat(Color(0.25, 0.27, 0.3), 0.4, 0.7)
	for z in [Z0, Z1]:
		_box(Vector3(1.2, 9.0, 1.2), metal, Vector3(0, 4.5, z))
		_box(Vector3(0.5, 8.0, 0.2), _glow(Color(0.4, 0.8, 1.0), 4.0), Vector3(0, 4.5, z + (0.65 if z < 0 else -0.65)))
	_box(Vector3(0.6, 0.6, Z1 - Z0), metal, Vector3(0, 9.0, (Z0 + Z1) * 0.5))
	_field = StandardMaterial3D.new()
	_field.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_field.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_field.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_field.cull_mode = BaseMaterial3D.CULL_DISABLED
	_field.albedo_color = Color(0.35, 0.75, 1.0, 0.3)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 1)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_field.albedo_texture = gt
	var q := QuadMesh.new()
	q.size = Vector2(Z1 - Z0, 8.6)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _field
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = PI / 2
	mi.position = Vector3(0, 4.5, (Z0 + Z1) * 0.5)
	_body.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.8, 1.0)
	l.light_energy = 2.0
	l.omni_range = 10.0
	l.position = Vector3(0, 4, 0)
	_body.add_child(l)


## Steel tank traps (crossed beams) with razor wire in front.
func _build_traps() -> void:
	var steel := _mat(Color(0.3, 0.28, 0.26), 0.6, 0.6)
	var z := Z0 + 0.8
	while z < Z1:
		var trap := Node3D.new()
		trap.position = Vector3(randf_range(-0.4, 0.4), 1.6, z)
		_body.add_child(trap)
		trap.basis = Basis.from_euler(Vector3(0.62, randf_range(-0.4, 0.4), 0.62))
		for sz in [Vector3(4.2, 0.35, 0.35), Vector3(0.35, 4.2, 0.35), Vector3(0.35, 0.35, 4.2)]:
			var beam := MeshInstance3D.new()
			beam.mesh = _unit_box()
			beam.material_override = steel
			beam.scale = sz
			trap.add_child(beam)
		z += 2.4
	var wire := _mat(Color(0.55, 0.55, 0.55), 0.3, 0.9)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.55
	coil.outer_radius = 0.62
	var zz := Z0
	while zz < Z1:
		var mi := MeshInstance3D.new()
		mi.mesh = coil
		mi.material_override = wire
		mi.rotation = Vector3(PI / 2, 0, 0.3)
		mi.position = Vector3(-2.0, 0.6, zz)
		_body.add_child(mi)
		zz += 0.7
	_warning_lights(3.4)


## A red-and-white boom across the top.
func _striped_boom(y: float) -> void:
	var red := _mat(Color(0.8, 0.1, 0.08), 0.5)
	var white := _mat(Color(0.92, 0.92, 0.9), 0.5)
	var z := Z0
	var i := 0
	while z < Z1:
		_box(Vector3(0.3, 0.3, 1.0), red if i % 2 == 0 else white, Vector3(0, y, z + 0.5))
		z += 1.0
		i += 1


## Blinking amber lamps along the top, so the gate reads as "closed".
func _warning_lights(y: float) -> void:
	var z := Z0 + 1.0
	while z < Z1:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.45, 0.05)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.05)
		m.emission_energy_multiplier = 3.0
		_lights.append(m)
		var s := SphereMesh.new()
		s.radius = 0.25
		s.height = 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = s
		mi.material_override = m
		mi.position = Vector3(0, y, z)
		_body.add_child(mi)
		z += 3.5


func _box(size: Vector3, mat: Material, pos: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_box()
	mi.material_override = mat
	mi.basis = Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	mi.position = pos
	_body.add_child(mi)
	return mi


func _unit_box() -> Mesh:
	if not _mats.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_mats["box"] = b
	return _mats["box"]


func _mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
