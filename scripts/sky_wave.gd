class_name SkyWave
extends Node3D
## The claw wave a kaiju sends off with SKY CLAW (jump + light, see
## Player._sky_claw). It flies up and ahead, turns toward the closest
## aircraft in front of it and cuts through everything it touches once.
## Aircraft (Flyer) take Player.AIR_BONUS times the damage.

const SPEED := 30.0
const RANGE := 30.0
const TURN := 5.0
const HIT_R := 2.0
## How far ahead (and how far behind) it looks for aircraft to chase.
const SEEK := 32.0

var shooter: Player
var dir := 1.0
var damage := 12.0
var tint := Color(0.6, 0.9, 1.0)
var _vel := Vector3.ZERO
var _flown := 0.0
var _hit: Array = []
var _mat: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	_vel = Vector3(dir, 0.6, 0).normalized() * SPEED
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(tint.r * 1.6 + 0.3, tint.g * 1.6 + 0.3, tint.b * 1.6 + 0.3, 0.9)
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _crescent(1.9 - i * 0.45, 0.55 - i * 0.15)
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.x = -i * 0.7
		add_child(mi)
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 4.0
	_light.omni_range = 7.0
	add_child(_light)
	_face()


## A flat moon-shaped blade bulging toward local +X, thickest in the middle.
func _crescent(r: float, w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var prev_o := Vector3.ZERO
	var prev_i := Vector3.ZERO
	for k in n + 1:
		var a := lerpf(-1.25, 1.25, float(k) / n)
		var thick := w * cos(a * 1.2)
		var o := Vector3(cos(a) * r, sin(a) * r, 0)
		var i := Vector3(cos(a) * (r - thick), sin(a) * (r - thick), 0) - Vector3(r * 0.35, 0, 0) * (1.0 - absf(a) / 1.25)
		if k > 0:
			st.add_vertex(prev_o)
			st.add_vertex(o)
			st.add_vertex(i)
			st.add_vertex(prev_o)
			st.add_vertex(i)
			st.add_vertex(prev_i)
		prev_o = o
		prev_i = i
	return st.commit()


func _target() -> Node3D:
	var best: Node3D = null
	var best_d := SEEK
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e is Flyer or e in _hit:
			continue
		var d: Vector3 = e.hit_center() - global_position
		if d.x * dir < -2.0:
			continue
		if d.length() < best_d:
			best_d = d.length()
			best = e
	return best


func _face() -> void:
	rotation = Vector3(0, 0, atan2(_vel.y, _vel.x))


func _physics_process(delta: float) -> void:
	var t := _target()
	if t:
		var want: Vector3 = (t.hit_center() - global_position).normalized() * SPEED
		_vel = _vel.lerp(want, minf(TURN * delta, 1.0)).normalized() * SPEED
	global_position += _vel * delta
	_flown += SPEED * delta
	_face()
	var fade := clampf((RANGE - _flown) / 6.0, 0.0, 1.0)
	_mat.albedo_color.a = 0.9 * fade
	_light.light_energy = 4.0 * fade
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e in _hit:
			continue
		if e.hit_center().distance_to(global_position) <= HIT_R + e.hit_radius:
			_hit.append(e)
			var dmg := damage * (Player.AIR_BONUS if e is Flyer else 1.0)
			if is_instance_valid(shooter) and shooter.deal(e, dmg, Vector3(dir * 8.0, 6.0, 0)):
				FX.hit_spark(e.hit_center(), dmg)
				Game.register_hit()
				shooter.add_rage(dmg * 0.3)
	if _flown >= RANGE or global_position.y > 24.0:
		queue_free()
