class_name Pickup
extends Node3D
## Healing energy orb dropped by destroyed buildings.

const HEAL := 30.0

var _t := 0.0
var _life := 14.0
var _base_y := 1.5


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.5)
	mat.emission_energy_multiplier = 5.0
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.6)
	l.light_energy = 2.0
	l.omni_range = 5.0
	add_child(l)
	_base_y = global_position.y


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	global_position.y = _base_y + sin(_t * 3.0) * 0.4
	rotate_y(delta * 2.0)
	if _life < 3.0:
		visible = fmod(_t, 0.2) < 0.12
	if _life <= 0.0:
		queue_free()
		return
	for p in Game.living_players():
		var d := p.global_position - global_position
		d.y = 0.0
		if d.length() < 3.0:
			p.hp = minf(p.hp + HEAL, p.max_hp)
			p.health_changed.emit(p.hp, p.max_hp)
			FX.energy(global_position, Color(0.4, 1.0, 0.6))
			queue_free()
			return
