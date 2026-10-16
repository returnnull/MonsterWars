class_name Fireball
extends Node3D
## A ball of fire a raging kaiju spits with a light attack (see
## Player._spit_fireball). It flies straight ahead, dips from the mouth down
## to body height, trails flames and bursts on the first enemy or building it
## touches, or at the end of its range. The burst hurts and burns everything
## inside `splash`.

const SPEED := 34.0
const RANGE := 30.0
## Height above the ground it settles at, so it also hits small enemies.
const CRUISE_Y := 2.6

var shooter: Player
var dir := 1.0
var damage := 8.0
var splash := 2.6
var size := 1.0
var _flown := 0.0
var _trail: GPUParticles3D
var _light: OmniLight3D
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	# A small white-hot core inside a hard orange shell, wrapped in a ragged
	# red flame skin that spins, so each ball reads as a solid shot.
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.9, 0.55)
	_core = _ball(0.55 * size, core_mat)
	var mid_mat := StandardMaterial3D.new()
	mid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mid_mat.albedo_color = Color(1.0, 0.55, 0.08, 0.85)
	_ball(0.9 * size, mid_mat)
	# Outer shell is blended, not added, so it stays orange on a bright sky.
	var shell_mat := mid_mat.duplicate() as StandardMaterial3D
	shell_mat.albedo_color = Color(0.9, 0.22, 0.02, 0.45)
	_glow = _ball(1.35 * size, shell_mat)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.light_energy = 3.0 * size
	_light.omni_range = 7.0 * size
	add_child(_light)
	# The flame skin licks back along the flight path like a comet's tail.
	_trail = FX.fire_stream(Vector3(-dir, 0.15, 0), 6.0, 18.0, 2.0 * size, 0.38, int(120 * size))
	if _trail:
		_trail.global_position = global_position


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	_t += delta
	var step := SPEED * delta
	_flown += step
	global_position.x += dir * step
	global_position.y = move_toward(global_position.y, CRUISE_Y + size * 0.4, 9.0 * delta)
	var flicker := 1.0 + sin(_t * 47.0) * 0.1 + sin(_t * 23.0) * 0.06
	_glow.scale = Vector3(1.3, 0.9, 0.9) * flicker
	_light.light_energy = 3.0 * size * flicker
	if _trail and is_instance_valid(_trail):
		_trail.global_position = global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d: Vector3 = e.hit_center() - global_position
		var r: float = e.hit_radius
		if absf(d.x) < r + 0.9 * size and absf(d.z) < r + 1.6 and absf(d.y) < r + 2.6:
			_burst()
			return
	for b in get_tree().get_nodes_in_group("buildings"):
		if not b.destroyed and b._aabb().grow(0.8 * size).has_point(global_position):
			_burst()
			return
	if _flown >= RANGE:
		_burst()


## Flames burst out where it lands: hurts, burns and wrecks what is close by.
## Fire never feeds rage back (see Player._do_hit).
func _burst() -> void:
	var pos := global_position
	var r := splash
	var hits := 0
	if is_instance_valid(shooter):
		hits = shooter.strike(pos, r, damage, Vector3(dir * 7.0, 5.0, 0), "enemies", damage * shooter._bdmg())
		for t in get_tree().get_nodes_in_group("enemies"):
			if not t.dead and t.hit_center().distance_to(pos) <= r + t.hit_radius:
				if t.has_method("apply_burn"):
					t.apply_burn(damage * 0.25, 2.5)
		if hits > 0:
			shooter.rumble(0.2, 0.25 * size, 0.08)
	for i in hits:
		Game.register_hit()
	FX.fireball_pop(pos, size)
	if size > 1.2:
		# The big third fireball bursts into a fire ball and sets the street alight.
		FX.fire_burst(pos, r)
		FX.ground_fire(pos, 1.2, 1.0)
	Game.shake(0.1 * size + (0.1 if hits > 0 else 0.0))
	FX.stop_stream(_trail)
	queue_free()
