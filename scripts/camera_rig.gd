class_name CameraRig
extends Node3D
## Shared side-on camera for 1-4 players. Frames the middle of everyone
## still standing, pulls back as they spread out, and handles screen shake.

const BASE_POS := Vector3(0, 8.5, 22.0)
const LOOK_Y := 3.0

var cam: Camera3D
var _trauma := 0.0
var _look_ahead := 0.0
var _zoom := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	_apply_zoom()
	var f := _framing()
	if not f.is_empty():
		global_position = Vector3(f["pos"].x, 0, 0)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Returns {pos, spread, facing} for the players to frame, or {} if none.
func _framing() -> Dictionary:
	var ps := Game.living_players()
	if ps.is_empty():
		ps = Game.players.filter(func(p: Node3D) -> bool: return is_instance_valid(p))
	if ps.is_empty():
		return {}
	var lo := INF
	var hi := -INF
	var sum := Vector3.ZERO
	var facing := 0.0
	for p in ps:
		lo = minf(lo, p.global_position.x)
		hi = maxf(hi, p.global_position.x)
		sum += p.global_position
		facing += p.facing
	var avg := sum / ps.size()
	avg.x = (lo + hi) * 0.5
	return {"pos": avg, "spread": hi - lo, "facing": facing if ps.size() == 1 else 0.0}


func _process(delta: float) -> void:
	var f := _framing()
	if not f.is_empty():
		var pos: Vector3 = f["pos"]
		_look_ahead = lerpf(_look_ahead, f["facing"] * 3.0, 1.0 - exp(-1.5 * delta))
		var want := Vector3(pos.x + _look_ahead, maxf(pos.y - 0.5, 0.0) * 0.4, pos.z * 0.3)
		global_position = global_position.lerp(want, 1.0 - exp(-5.0 * delta))
		_zoom = lerpf(_zoom, clampf((f["spread"] - 12.0) / 18.0, 0.0, 1.0), 1.0 - exp(-3.0 * delta))
		_apply_zoom()
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var s := _trauma * _trauma
	cam.h_offset = randf_range(-1.0, 1.0) * s * 1.2
	cam.v_offset = randf_range(-1.0, 1.0) * s * 1.2
	cam.rotation.z = randf_range(-1.0, 1.0) * s * 0.04


func _apply_zoom() -> void:
	cam.position = BASE_POS * (1.0 + _zoom * 0.45)
	cam.rotation.x = -atan2(cam.position.y - LOOK_Y, cam.position.z + 1.0)
