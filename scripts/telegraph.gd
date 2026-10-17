class_name Telegraph
extends Node3D
## Ground warning for a big enemy's attack: shows the area it is about to hit
## while it winds up. The fill grows as the strike gets closer and the rim
## blinks faster; when the attack lets go the marker flashes and fades.
## shape "circle" (radius) or "lane" (a strip `length` long and `width` wide
## from the node's position along its local +x; turn the node to aim it).

var shape := "circle"
var radius := 3.0
var length := 10.0
var width := 3.0
## Seconds until the attack lands; drives the fill.
var duration := 1.0
var color := Color(1.0, 0.25, 0.1)
## Lets go by itself when the time is up (for things already on their way,
## like a falling glob or a pounce in mid-air).
var auto := false

var _t := 0.0
var _released := -1.0
var _hold := 0.0
var _rim_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _fill: MeshInstance3D


func _ready() -> void:
	add_to_group("telegraphs")
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_rim_mat.albedo_color = Color(color, 0.7)
	_rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_mat = _rim_mat.duplicate() as StandardMaterial3D
	_fill_mat.albedo_color = Color(color, 0.22)
	var rim := MeshInstance3D.new()
	_fill = MeshInstance3D.new()
	var under := MeshInstance3D.new()
	var under_mat := _fill_mat.duplicate() as StandardMaterial3D
	under_mat.albedo_color = Color(color, 0.08)
	if shape == "lane":
		var outline := BoxMesh.new()
		outline.size = Vector3(length, 0.03, width)
		rim.mesh = _frame(length, width)
		var fill := BoxMesh.new()
		fill.size = Vector3(length, 0.03, width)
		_fill.mesh = fill
		under.mesh = outline
		for m in [rim, _fill, under]:
			m.position.x = length * 0.5
	else:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.3
		torus.outer_radius = radius
		torus.rings = 48
		rim.mesh = torus
		rim.scale = Vector3(1, 0.12, 1)
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.03
		_fill.mesh = disc
		under.mesh = disc
	rim.material_override = _rim_mat
	_fill.material_override = _fill_mat
	under.material_override = under_mat
	rim.position.y = 0.14
	_fill.position.y = 0.12
	under.position.y = 0.1
	for m in [rim, _fill, under]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	_update(0.0)


## The attack has let go: flash, then fade out after `hold` seconds (for a
## boulder or a leap still on its way to the marked spot).
func release(hold: float = 0.0) -> void:
	if _released >= 0.0:
		return
	_released = 0.0
	_hold = hold
	_rim_mat.albedo_color = Color(1.0, 0.95, 0.85, 1.0)
	_fill_mat.albedo_color = Color(color.lerp(Color.WHITE, 0.5), 0.5)


## Gone without the attack (the enemy got interrupted or died).
func cancel() -> void:
	queue_free()


## True while the warned area covers a point on the ground.
func covers(p: Vector3) -> bool:
	var d := global_transform.affine_inverse() * p
	if shape == "lane":
		return d.x >= -1.0 and d.x <= length + 1.0 and absf(d.z) <= width * 0.5 + 1.0
	return Vector2(d.x, d.z).length() <= radius + 1.0


func _process(delta: float) -> void:
	_t += delta
	if _released >= 0.0:
		_released += delta
		var fade := clampf((_released - _hold) / 0.25, 0.0, 1.0)
		_rim_mat.albedo_color.a = 1.0 - fade
		_fill_mat.albedo_color.a = 0.5 * (1.0 - fade)
		if fade >= 1.0:
			queue_free()
		return
	_update(clampf(_t / maxf(duration, 0.01), 0.0, 1.0))
	if auto and _t >= duration:
		release()


func _update(k: float) -> void:
	# Fill grows from the centre (circle) or from the attacker out (lane).
	var g := maxf(k, 0.04)
	if shape == "lane":
		_fill.scale = Vector3(g, 1, 1)
		_fill.position.x = length * 0.5 * g
	else:
		_fill.scale = Vector3(g, 1, g)
	var blink := absf(sin(_t * (5.0 + k * k * 22.0)))
	_rim_mat.albedo_color.a = 0.45 + 0.55 * blink
	_fill_mat.albedo_color = Color(color.lerp(Color(1.0, 0.9, 0.6), k * k * 0.5), 0.18 + 0.2 * k)


## Four thin bars outlining a lane.
func _frame(l: float, w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t := 0.3
	for r in [Rect2(-l * 0.5, -w * 0.5, l, t), Rect2(-l * 0.5, w * 0.5 - t, l, t),
			Rect2(-l * 0.5, -w * 0.5, t, w), Rect2(l * 0.5 - t, -w * 0.5, t, w)]:
		var a := Vector3(r.position.x, 0, r.position.y)
		var b := Vector3(r.end.x, 0, r.position.y)
		var c := Vector3(r.end.x, 0, r.end.y)
		var d := Vector3(r.position.x, 0, r.end.y)
		for v in [a, c, b, a, d, c]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
