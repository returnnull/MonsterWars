class_name Hazard
extends Node3D
## A telegraphed strike on the ground: a pulsing warning ring that fills up,
## then an artillery shell, lightning bolt or bomb lands on it and hurts every
## player standing inside. Set the fields, add it to the world and place it.

var radius := 3.0
var delay := 1.4
var damage := 14.0
## "shell" (artillery round falls in), "bolt" (lightning) or "blast".
var style := "shell"
var color := Color(1.0, 0.3, 0.1)
var element := ""

var _t := 0.0
var _ring_mat: StandardMaterial3D
var _fill: MeshInstance3D
var _shell: MeshInstance3D


func _ready() -> void:
	add_to_group("telegraphs")
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(color, 0.8)
	_ring_mat.no_depth_test = false
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.25
	torus.outer_radius = radius
	torus.rings = 40
	ring.mesh = torus
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.12
	add_child(ring)
	_fill = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	_fill.mesh = disc
	var fill_mat := _ring_mat.duplicate() as StandardMaterial3D
	fill_mat.albedo_color = Color(color, 0.25)
	_fill.material_override = fill_mat
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.position.y = 0.1
	_fill.scale = Vector3(0.05, 1, 0.05)
	add_child(_fill)
	if style == "shell":
		_shell = MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.3
		cap.height = 1.4
		_shell.mesh = cap
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.22, 0.18)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
		_shell.material_override = m
		_shell.visible = false
		add_child(_shell)


## True while the warning ring covers a point on the ground.
func covers(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= radius + 1.0


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / delay, 0.0, 1.0)
	_fill.scale = Vector3(maxf(k, 0.05), 1, maxf(k, 0.05))
	_ring_mat.albedo_color.a = 0.5 + 0.5 * absf(sin(_t * (8.0 + k * 14.0)))
	if _shell and _t > delay - 0.4:
		_shell.visible = true
		_shell.position.y = lerpf(18.0, 0.5, clampf((_t - (delay - 0.4)) / 0.4, 0.0, 1.0))
	if _t >= delay:
		_detonate()


func _detonate() -> void:
	var pos := global_position
	match style:
		"bolt":
			FX.bolt(pos + Vector3(randf_range(-2, 2), 26.0, -2.0), pos + Vector3(0, 0.3, 0), color)
			FX.energy(pos + Vector3(0, 1, 0), color)
		_:
			FX.explosion(pos + Vector3(0, 0.5, 0), radius / 3.0)
	FX.shockwave(pos, radius, color)
	FX.dust(pos, radius / 3.0)
	Game.shake(0.35)
	for p in Game.living_players():
		var d: Vector3 = p.global_position - pos
		if Vector2(d.x, d.z).length() < radius + p.hit_radius * 0.4 and p.global_position.y < 5.0:
			if p.take_hit(damage, Vector3(signf(d.x) * 8.0, 9.0, 0), self):
				FX.hit_spark(p.hit_center(), damage)
				Projectile.apply_element(p, element, damage)
	for b in get_tree().get_nodes_in_group("buildings"):
		b.try_hit(pos + Vector3(0, 1.5, 0), radius, damage * 2.0)
	queue_free()
