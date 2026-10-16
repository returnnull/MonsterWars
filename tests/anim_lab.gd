extends Node3D
## Dev helper: plays a hero through a fixed routine (idle, slow walk, run,
## stop, turn, jump, attacks) the way the player drives it, to judge the
## animation. Record it with Godot's movie writer:
##   xvfb-run godot --path . --write-movie /tmp/lab.avi --fixed-fps 30 res://tests/anim_lab.tscn
## ANIM_HERO picks the hero (default 0).

const SPEED := 9.5
const GRAVITY := 38.0
## [start time, walk amount, facing, action]
const SCRIPT := [
	[0.0, 0.0, 1, ""], [1.4, 0.35, 1, ""], [2.8, 0.68, 1, ""], [4.2, 1.0, 1, ""], [5.8, 0.0, 1, ""],
	[6.8, 1.0, 1, ""], [7.6, 1.0, -1, ""], [8.8, 0.0, -1, ""], [9.6, 0.0, -1, "jump"], [11.0, 1.0, -1, "jump"],
	[12.4, 0.0, -1, "attack"], [13.4, 0.0, -1, "attack"], [13.9, 0.0, -1, "attack"], [15.0, 1.0, 1, "hit"],
	[16.0, 0.0, 1, ""], [17.0, 0.0, 1, "end"],
]

var model: KaijuModel
var body := Node3D.new()
var cam := Camera3D.new()
var t := 0.0
var _step := -1
var _vy := 0.0
var _squat := 0.0
var _atk := 0.0
var _yaw := 0.0
var _facing := 1.0
var _walk := 0.0
## ANIM_LAB_SLIDE=1 prints, per step of the routine, how fast planted feet
## slide over the ground (0 is perfect).
var _slide := {}
var _feet := {}
var _skel: Skeleton3D
var _att := {}


func _ready() -> void:
	Game.set_meta("no_save", true)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.47, 0.42)
	ground.material_override = gm
	add_child(ground)
	# Stripes every two units show whether the feet slide.
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.25, 0.26, 0.23)
	for i in 300:
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 0.02, 16)
		s.mesh = bm
		s.material_override = sm
		s.position = Vector3(-300 + i * 2.0, 0.01, 0)
		add_child(s)
	add_child(body)
	var h := Content.hero(int(OS.get_environment("ANIM_HERO")) if OS.get_environment("ANIM_HERO") != "" else 0)
	model = GlbKaijuModel.for_hero(h, body)
	model.scale = Vector3.ONE * float(h["size"])
	_skel = model.find_children("*", "Skeleton3D", true, false)[0] if model.find_children("*", "Skeleton3D", true, false).size() > 0 else null
	cam.fov = 40.0
	add_child(cam)


func _process(delta: float) -> void:
	t += delta
	while _step + 1 < SCRIPT.size() and t >= SCRIPT[_step + 1][0]:
		_step += 1
		var a: String = SCRIPT[_step][3]
		if a == "end":
			if OS.get_environment("ANIM_LAB_SLIDE") == "1":
				for k in _slide:
					print("step %s: planted feet slide %.2f u/s" % [k, _slide[k][0] / maxf(_slide[k][1], 1.0)])
			get_tree().quit()
			return
		if a == "jump":
			_squat = 0.1
		elif a == "attack":
			_atk = 0.35
		elif a == "hit":
			model.flash()
	var cur: Array = SCRIPT[maxi(_step, 0)]
	_walk = cur[1]
	_facing = cur[2]
	if _squat > 0.0:
		_squat -= delta
		if _squat <= 0.0:
			_vy = 17.0
	var airborne := body.position.y > 0.0 or _vy > 0.0
	if airborne:
		_vy -= GRAVITY * delta
		body.position.y += _vy * delta
		if body.position.y <= 0.0:
			body.position.y = 0.0
			model.land(clampf(-_vy / 25.0, 0.0, 1.6))
			_vy = 0.0
			airborne = false
	var spd := _walk * SPEED
	body.position.x += spd * _facing * delta
	model.walk_amount = _walk if not airborne and _atk <= 0.0 else 0.0
	model.airborne = airborne
	model.crouch = 1.0 - _squat / 0.1 if _squat > 0.0 else 0.0
	model.arm_r = 1.6 if _atk > 0.0 else 0.25
	_atk = maxf(_atk - delta, 0.0)
	_yaw = lerpf(_yaw, 0.0 if _facing > 0.0 else -PI, 1.0 - exp(-14.0 * delta))
	model.rotation.y = _yaw
	_measure(delta)
	var focus := body.position + Vector3(0, 3.5, 0)
	cam.position = Vector3(focus.x + 2.0, 5.0, 15.0)
	cam.look_at(Vector3(focus.x, 2.6, 0))
	if OS.get_environment("ANIM_LAB_TOP") == "1":
		cam.position = Vector3(focus.x, 22.0, 0.01)
		cam.look_at(Vector3(focus.x, 0, 0))


func _measure(delta: float) -> void:
	if _skel == null or delta <= 0.0:
		return
	# Feet near the ground carry the weight; they should stay put. Bone
	# attachments follow the final pose, foot planting included.
	for bn in ["BackLowLeg.L_end", "BackLowLeg.R_end"]:
		if not _att.has(bn):
			var ba := BoneAttachment3D.new()
			ba.bone_name = bn
			_skel.add_child(ba)
			_att[bn] = ba
			continue
		var p: Vector3 = _att[bn].global_position
		if _feet.has(bn) and p.y < 0.13 and body.position.y <= 0.0:
			var key := "%d (walk %.2f)" % [_step, _walk]
			var acc: Array = _slide.get(key, [0.0, 0.0])
			acc[0] += absf(p.x - _feet[bn].x) / delta
			acc[1] += 1.0
			_slide[key] = acc
		_feet[bn] = p
