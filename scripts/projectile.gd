class_name Projectile
extends Node3D
## Plasma bolt fired by drones and fire-breathing bosses. Dodging (i-frames) lets it pass through.

var velocity := Vector3.ZERO
var color := Color(1.0, 0.45, 0.1)
var damage := 8.0
var _life := 4.0


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lerp(Color.WHITE, 0.4)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var trail := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.3
	c.height = 1.6
	trail.mesh = c
	trail.material_override = mat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	trail.rotation.z = PI / 2
	trail.position.x = -0.8


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if velocity.length() > 0.1:
		rotation.y = atan2(-velocity.z, velocity.x)
		rotation.z = atan2(velocity.y, Vector2(velocity.x, velocity.z).length())
	_life -= delta
	for p in Game.living_players():
		if global_position.distance_to(p.hit_center()) < p.hit_radius + 0.6:
			if p.take_hit(damage, Vector3(signf(velocity.x) * 5.0, 2.0, 0), self):
				FX.hit_spark(global_position, 8.0)
				Game.shake(0.2)
				queue_free()
				return
	if global_position.y < 0.2 or _life <= 0.0:
		FX.hit_spark(global_position, 5.0)
		queue_free()
