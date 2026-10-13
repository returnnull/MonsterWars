class_name CameraRig
extends Node3D
## Side-on beat 'em up camera with look-ahead and trauma-based screen shake.

var target: Kaiju
var cam: Camera3D
var _trauma := 0.0
var _look_ahead := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.position = Vector3(0, 8.5, 22.0)
	cam.rotation.x = -atan2(8.5 - 3.0, 23.0)
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	if target:
		global_position = Vector3(target.global_position.x, 0, 0)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		_look_ahead = lerpf(_look_ahead, target.facing * 3.0, 1.0 - exp(-1.5 * delta))
		var tp := target.global_position
		var want := Vector3(tp.x + _look_ahead, maxf(tp.y - 0.5, 0.0) * 0.4, tp.z * 0.3)
		global_position = global_position.lerp(want, 1.0 - exp(-5.0 * delta))
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var s := _trauma * _trauma
	cam.h_offset = randf_range(-1.0, 1.0) * s * 1.2
	cam.v_offset = randf_range(-1.0, 1.0) * s * 1.2
	cam.rotation.z = randf_range(-1.0, 1.0) * s * 0.04
