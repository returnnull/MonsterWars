class_name KaijuModel
extends Node3D
## A kaiju sculpted from primitive meshes, with procedural animation.
## Faces +X and has its origin at the feet. The owner sets the pose targets
## (walk_amount, arm_r, arm_l, jaw, lean, spin, glow) every frame.
## Named pivots live in `parts` (hips, torso, neck, head, jaw, arm_r/arm_l,
## arm_r_fore/arm_l_fore, arm_r_hand/arm_l_hand, leg_r/leg_l (thighs),
## leg_r_shin/leg_l_shin, leg_r_foot/leg_l_foot, tail0..tail9); the right
## hand sits at about (0.1, -1.3, 0) in arm_r_fore. The static pieces on each
## pivot are merged into one mesh per material to keep draw calls low.
##
## The look varies with the colours passed to build(): a stable hash of them
## picks the dorsal spike shape (leaf plates, cone spikes or swept blades),
## how many spike rows, their size, and extras such as a chest gem, glowing
## seams between the belly plates, a head crest or forearm spikes, plus body
## proportions (neck length, head size, snout, bulk, arm size, tail length).
## `look` overrides any of these per hero.
##
## Motion is smoothed with damped springs: pose targets ease in and settle
## with a little overshoot, forearms, hands and the tail trail behind the
## body, the legs bend at the knee and keep the feet flat, and landings
## squash the body down.

const SKIN_SHADER := preload("res://shaders/kaiju_skin.gdshader")
const SPIKE_SHADER := preload("res://shaders/kaiju_spike.gdshader")
const TAIL_SEGMENTS := 10
## Spring frequency (rad/s) and damping ratio per pose channel.
const SPRINGS := {"arm_r": [24.0, 0.72], "arm_l": [24.0, 0.72], "jaw": [30.0, 0.6], "lean": [16.0, 0.8],
	"squash": [14.0, 0.45], "turn": [9.0, 0.9]}

static var _tex := {}
static var _meshes := {}

## Mesh resolution: 0 low, 1 medium (regular enemies), 2 high (heroes, bosses).
## Set before build().
var detail := 2
## Optional per-hero body overrides merged over the colour-hashed variant
## (see _variant() for the keys). Set before build().
var look := {}
var parts := {}
var walk_amount := 0.0
var walk_speed := 1.0
var arm_r := 0.25
var arm_l := 0.25
var jaw := 0.0
var lean := 0.0
var spin := 0.0
## Jumping: crouch (0-1) is the takeoff squat, airborne is set while off
## the ground. land() is called on touchdown with how hard it was (0-1.6).
var crouch := 0.0
var airborne := false
var glow := 0.0
var eye_glow := 0.0
## How heavy the body moves: 1 is hero weight, higher makes every pose spring
## slower and swingier so big monsters read as massive. Set any time.
var heft := 1.0
## 0-1: the body shakes with effort, building up to a big attack.
var tremble := 0.0

var _body_mats: Array[ShaderMaterial] = []
var _eye_mat: StandardMaterial3D
var _spike_mat: ShaderMaterial
var _seam_mat: ShaderMaterial
var _tail: Array[Node3D] = []
var _flash := 0.0
var _t := 0.0
var _walk := 0.0
var _phase := 0.0
var _spike_color := Color.WHITE
var _cur := {"arm_r": 0.25, "arm_l": 0.25, "jaw": 0.0, "lean": 0.0, "squash": 0.0, "turn": 0.0}
var _vel := {}  # spring velocities, same keys as _cur
var _pending := {}  # pivot -> {material -> [[mesh, transform], ...]}
var _v := {}  # look variant
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _vy := 0.0
var _yaw_rate := 0.0
var _moved := false


func build(skin: Color, belly: Color, spike: Color, eye: Color, horns: bool = false) -> void:
	_spike_color = spike
	_v = _variant(skin, belly, spike)
	var skin_mat := _skin(skin, skin.darkened(0.35).lerp(spike.darkened(0.75), 0.12), 0.58, 1.0, 1.0, 0.0)
	var plate_col := belly.lerp(skin, 0.25)
	var belly_mat := _skin(belly, belly.darkened(0.25), 0.45, 0.35, 0.4, 0.0)
	var plate_mat := _skin(plate_col, plate_col.darkened(0.3), 0.4, 0.3, 0.5, 0.0)
	var armor_mat := _skin(skin.lerp(belly, 0.22).darkened(0.08), skin.darkened(0.3), 0.35, 0.3, 0.6, 0.0)
	var claw_mat := _spike(Color(0.86, 0.82, 0.72), Color(0.2, 0.17, 0.15), Color.BLACK, 0.0, 0.3)
	_spike_mat = _spike(skin.darkened(0.45), spike.lerp(Color.WHITE, 0.15), spike, 0.3, 0.3)
	_seam_mat = _spike(spike.darkened(0.5), spike, spike, 0.2, 0.4)
	var mouth_mat := _flat(Color(0.32, 0.07, 0.08), 0.35)
	var tongue_mat := _flat(Color(0.55, 0.18, 0.2), 0.3)
	var socket_mat := _flat(skin.darkened(0.8), 0.9)
	var pupil_mat := _flat(Color(0.02, 0.02, 0.02), 0.2)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = eye
	_eye_mat.emission_enabled = true
	_eye_mat.emission = eye
	_eye_mat.emission_energy_multiplier = 3.0
	var ss: float = _v["spike_size"]

	# --- hips and torso: wide pelvis, hunched barrel body ---------------
	var hips := _pivot("hips", self, Vector3(0, 2.4, 0))
	_part(hips, _sphere(1.0), skin_mat, Vector3(-0.2, 0.2, 0), Vector3.ZERO, Vector3(1.25, 1.0, 1.35))
	var torso := _pivot("torso", hips, Vector3.ZERO)
	torso.scale = Vector3(1.0, 1.0, _v["bulk"])
	var up := Vector2(0.42, 0.91)    # torso axis
	var fwd := Vector2(0.91, -0.42)  # front of the torso
	var base := Vector2(0.25, 1.3)
	_part(torso, _capsule(1.18, 4.0), skin_mat, Vector3(base.x, base.y, 0), Vector3(0, 0, -0.43), Vector3(1, 1, 1.05))
	_part(torso, _sphere(1.1), skin_mat, Vector3(0.62, 2.15, 0), Vector3(0, 0, -0.4), Vector3(1.0, 0.95, 1.15))
	# Shoulder hump behind the neck.
	_part(torso, _sphere(1.0), skin_mat, Vector3(-0.05, 2.45, 0), Vector3(0, 0, -0.5), Vector3(1.05, 0.85, 1.05))
	# Pectorals and flank muscles.
	for side in [-1.0, 1.0]:
		var pc := base + up * 1.05 + fwd * 0.62
		_part(torso, _sphere(0.62), skin_mat, Vector3(pc.x, pc.y, 0.55 * side), Vector3(0, 0.25 * side, -0.5), Vector3(0.75, 0.9, 0.95))
		var fl := base + up * 0.1 + fwd * 0.2
		_part(torso, _sphere(0.7), skin_mat, Vector3(fl.x, fl.y, 0.72 * side), Vector3(0, 0, -0.43), Vector3(0.9, 1.5, 0.6))
	# Overlapping belly plates down the front, with glowing seams on some.
	for i in 11:
		var s := -1.6 + i * 0.31
		var r := 1.0 - absf(s) * 0.12
		var p := base + up * s + fwd * (r * 1.02 + (0.12 if s > 0.6 else 0.0))
		var w := 0.95 - absf(s - 0.2) * 0.14
		_part(torso, _sphere(0.5), belly_mat, Vector3(p.x, p.y, 0), Vector3(0, 0, -0.43 - 0.22),
			Vector3(0.42, 0.46, w * 1.75))
		if _v["seams"] and i < 10:
			var q := p + up * 0.16 + fwd * 0.1
			_part(torso, _box(Vector3(0.05, 0.05, w * 1.3)), _seam_mat, Vector3(q.x, q.y, 0), Vector3(0, 0, -0.43))
	if _v["gem"]:
		var g := base + up * 1.25 + fwd * 1.0
		_part(torso, _sphere(0.24), _seam_mat, Vector3(g.x, g.y, 0), Vector3(0, 0, -0.4), Vector3(0.6, 1.0, 1.0))
		_part(torso, _sphere(0.3), armor_mat, Vector3(g.x - 0.05, g.y, 0), Vector3(0, 0, -0.4), Vector3(0.5, 1.15, 1.15))
	# Rows of bony scutes along the flanks.
	for row in 2:
		for i in 9:
			var s := -1.5 + i * 0.36 + row * 0.18
			var p := base + up * s - fwd * (0.1 + row * 0.35)
			var zz := 1.1 - row * 0.12 - absf(s) * 0.12
			for side in [-1.0, 1.0]:
				_part(torso, _sphere(0.2), armor_mat, Vector3(p.x, p.y, zz * side), Vector3(0.6 * side, 0, -0.43),
					Vector3(1.0, 0.75, 0.45))
	# Shoulder armour.
	for side in [-1.0, 1.0]:
		_part(torso, _sphere(0.55), armor_mat, Vector3(0.9, 2.42, 0.98 * side), Vector3(0.45 * side, 0, -0.3), Vector3(1.0, 0.5, 0.8))
		_part(torso, _sphere(0.32), armor_mat, Vector3(0.72, 2.66, 0.9 * side), Vector3(0.45 * side, 0, -0.3), Vector3(1.0, 0.45, 0.8))

	# --- neck: thick, rising up and forward from the chest -----------------
	var nl: float = _v["neck_len"]
	var neck := _pivot("neck", torso, Vector3(0.8, 2.65, 0))
	var nv := Vector3(0.3 + 0.45 * nl, 0.45 + 0.8 * nl, 0)  # neck base -> head
	var nfwd := Vector3(nv.y, -nv.x, 0).normalized()  # throat side
	for i in 5:
		var t := float(i) / 4.0
		var r := lerpf(0.8, 0.5, t)
		_part(neck, _sphere(r), skin_mat, nv * t, Vector3(0, 0, -atan2(nv.x, nv.y)), Vector3(1.0, 0.85, 0.95))
	_seg(neck, Vector3.ZERO, nv, 0.6, skin_mat, Vector3(1.0, 1.0, 0.95))
	# Throat plates down the front and skin folds around the neck.
	for i in 5:
		var t := 0.1 + i * 0.2
		var r := lerpf(0.78, 0.5, t)
		_part(neck, _sphere(0.4), belly_mat, nv * t + nfwd * r * 0.72, Vector3(0, 0, -atan2(nv.x, nv.y) - 0.3),
			Vector3(0.42, 0.5, 1.3 * r / 0.65))
		if i % 2 == 1:
			_part(neck, _sphere(r), skin_mat, nv * t, Vector3(0, 0, -atan2(nv.x, nv.y)), Vector3(1.08, 0.2, 1.05))
	# Dewlap where the throat meets the chest.
	_part(neck, _sphere(0.6), belly_mat, nfwd * 0.55 + Vector3(0.1, -0.1, 0), Vector3(0, 0, -0.6), Vector3(0.7, 0.9, 1.1))

	# --- dorsal spikes from the neck down the back ------------------------
	var shape: int = _v["spike_shape"]
	var rows: int = _v["rows"]
	var back := Vector2(-0.91, 0.42)
	for i in 10:
		var s := -1.75 + i * 0.4
		var h := (0.55 + sin(float(i) / 9.0 * PI) * 1.0) * ss
		var p2 := base + up * s + back * 0.98
		var rot := atan2(-back.x, back.y) + 0.15
		_spike_piece(torso, shape, Vector3(p2.x, p2.y, 0), rot, h, 0.0)
		# A ridge of skin the spikes grow out of.
		_part(torso, _sphere(0.3), skin_mat, Vector3(p2.x, p2.y, 0), Vector3(0, 0, rot), Vector3(0.9, 0.45, 0.7))
		if rows >= 2 and i > 0:
			for side in [-1.0, 1.0]:
				var q := p2 + up * 0.2 - back * 0.12
				_spike_piece(torso, shape, Vector3(q.x, q.y, 0.34 * side), rot, h * 0.6, 0.3 * side)
		if rows >= 3 and i > 1 and i < 9:
			for side in [-1.0, 1.0]:
				var q := p2 - up * 0.05 - back * 0.4
				_spike_piece(torso, shape, Vector3(q.x, q.y, 0.68 * side), rot - 0.2, h * 0.35, 0.6 * side)
	# Spikes continue up the back of the neck, shrinking toward the head.
	var nback := -nfwd
	var nrot := atan2(-nback.x, nback.y)
	for i in 4:
		var t := 0.1 + i * 0.25
		var r := lerpf(0.78, 0.5, t)
		_spike_piece(neck, shape, nv * t + nback * r * 0.85, nrot, (0.75 - i * 0.13) * ss, 0.0)
		if rows >= 3 and i < 2:
			for side in [-1.0, 1.0]:
				_spike_piece(neck, shape, nv * t + nback * r * 0.7 + Vector3(0, 0, 0.3 * side), nrot, (0.45 - i * 0.1) * ss, 0.3 * side)

	# --- head: small, pushed forward, heavy jaw ---------------------------
	var head := _pivot("head", neck, nv + Vector3(0.15, 0.05, 0))
	var hsz: float = _v["head_size"]
	head.scale = Vector3(hsz * float(_v["snout"]), hsz, hsz)
	_part(head, _sphere(0.7), skin_mat, Vector3(-0.05, 0.02, 0), Vector3.ZERO, Vector3(1.15, 0.9, 1.0))
	_part(head, _capsule(0.42, 1.5), skin_mat, Vector3(0.68, -0.06, 0), Vector3(0, 0, -PI / 2 + 0.1), Vector3(1.0, 1.0, 1.28))
	_part(head, _sphere(0.4), skin_mat, Vector3(1.15, 0.0, 0), Vector3.ZERO, Vector3(0.75, 0.55, 1.05))
	# Bumpy skull top.
	for i in 6:
		var a := float(i) / 5.0
		_part(head, _sphere(0.12), armor_mat, Vector3(-0.35 + a * 0.75, 0.55 - absf(a - 0.4) * 0.25, (0.18 if i % 2 == 0 else -0.18)),
			Vector3.ZERO, Vector3(1.2, 0.6, 1.0))
	# Heavy brow ridges over dark sockets with glowing eyes.
	for side in [-1.0, 1.0]:
		_part(head, _capsule(0.13, 0.7), armor_mat, Vector3(0.45, 0.33, 0.38 * side), Vector3(0.3 * side, 0, -PI / 2 + 0.35))
		_part(head, _sphere(0.17), socket_mat, Vector3(0.58, 0.18, 0.39 * side), Vector3.ZERO, Vector3(1.2, 0.75, 0.6))
		_part(head, _sphere(0.1), _eye_mat, Vector3(0.64, 0.18, 0.43 * side), Vector3.ZERO, Vector3(1.4, 0.7, 0.6))
		_part(head, _sphere(0.04), pupil_mat, Vector3(0.7, 0.18, 0.465 * side), Vector3.ZERO, Vector3(0.6, 1.5, 0.5))
		# Lower lid.
		_part(head, _capsule(0.05, 0.36), skin_mat, Vector3(0.63, 0.1, 0.44 * side), Vector3(0.2 * side, 0, -PI / 2 + 0.1))
		# Cheeks and jaw muscles.
		_part(head, _sphere(0.42), skin_mat, Vector3(0.05, -0.22, 0.42 * side), Vector3.ZERO, Vector3(1.15, 0.85, 0.55))
		_part(head, _sphere(0.06), socket_mat, Vector3(1.38, 0.12, 0.15 * side))
		_part(head, _sphere(0.1), skin_mat, Vector3(1.33, 0.1, 0.16 * side), Vector3.ZERO, Vector3(1.0, 0.7, 0.9))
		# Lip ridge over the teeth.
		_part(head, _capsule(0.08, 1.2), skin_mat, Vector3(0.8, -0.26, 0.36 * side), Vector3(0.06 * side, 0, -PI / 2 + 0.04))
		# Upper teeth: a row of fangs, bigger at the front.
		for i in 9:
			var tl := 0.14 + (0.1 if i == 7 else 0.0) + i * 0.007
			_part(head, _claw(), claw_mat, Vector3(0.32 + i * 0.125, -0.33, (0.33 - i * 0.012) * side),
				Vector3(PI, 0, 0.2), Vector3(tl * 0.55, tl, tl * 0.55))
		if horns:
			var hs: float = _v["horn_size"]
			_part(head, _claw(), claw_mat, Vector3(-0.3, 0.45, 0.42 * side), Vector3(0.45 * side, 0, 1.25),
				Vector3(0.9, 1.3, 0.9) * hs)
			_part(head, _claw(), claw_mat, Vector3(-0.55, 0.15, 0.48 * side), Vector3(0.6 * side, 0, 1.6),
				Vector3(0.5, 0.7, 0.5) * hs)
			# Horn bases.
			_part(head, _sphere(0.16), armor_mat, Vector3(-0.3, 0.45, 0.42 * side), Vector3.ZERO, Vector3(1.0, 0.6, 1.0) * hs)
	if _v["crest"]:
		for i in 3:
			_spike_piece(head, 0, Vector3(0.2 - i * 0.35, 0.58 - i * 0.08, 0), 0.45 + i * 0.2, (0.55 - i * 0.08) * ss, 0.0)
	else:
		for i in 3:
			_part(head, _claw(), _spike_mat, Vector3(-0.55 - i * 0.12, 0.42 - i * 0.2, 0), Vector3(0, 0, 1.0 + i * 0.3),
				Vector3(0.6, 0.6 - i * 0.1, 0.4) * ss)
	var jaw_pivot := _pivot("jaw", head, Vector3(0.2, -0.36, 0))
	_part(jaw_pivot, _capsule(0.2, 1.35), skin_mat, Vector3(0.58, -0.04, 0), Vector3(0, 0, -PI / 2 + 0.05), Vector3(1.0, 0.85, 1.75))
	_part(jaw_pivot, _capsule(0.16, 1.1), belly_mat, Vector3(0.5, -0.12, 0), Vector3(0, 0, -PI / 2 + 0.05), Vector3(1.0, 0.8, 1.6))
	_part(jaw_pivot, _sphere(0.3), skin_mat, Vector3(0.0, -0.05, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.35))
	_part(jaw_pivot, _box(Vector3(1.0, 0.05, 0.52)), mouth_mat, Vector3(0.58, 0.12, 0))
	_part(jaw_pivot, _capsule(0.1, 0.8), tongue_mat, Vector3(0.45, 0.15, 0), Vector3(0, 0, -PI / 2 + 0.08), Vector3(1.0, 0.6, 1.6))
	# Throat folds under the jaw.
	for i in 3:
		_part(jaw_pivot, _capsule(0.05, 0.6), belly_mat, Vector3(0.1 + i * 0.25, -0.24, 0), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.8))
	for side in [-1.0, 1.0]:
		for i in 8:
			var tl := 0.12 + i * 0.005
			_part(jaw_pivot, _claw(), claw_mat, Vector3(0.22 + i * 0.125, 0.12, 0.27 * side), Vector3(0, 0, -0.2),
				Vector3(tl * 0.55, tl, tl * 0.55))
	_part(head, _box(Vector3(1.0, 0.05, 0.6)), mouth_mat, Vector3(0.72, -0.31, 0))

	# --- arms: muscled upper arms, plated forearms, jointed clawed fingers --
	for side in [1.0, -1.0]:
		var arm_name := "arm_r" if side > 0 else "arm_l"
		var arm := _pivot(arm_name, torso, Vector3(1.05, 2.3, 0.95 * side))
		arm.scale = Vector3.ONE * float(_v["arm_size"])
		_part(arm, _sphere(0.48), skin_mat, Vector3(0.0, -0.05, 0))
		_part(arm, _capsule(0.42, 1.6), skin_mat, Vector3(0.02, -0.62, 0))
		# Biceps and triceps.
		_part(arm, _sphere(0.36), skin_mat, Vector3(0.18, -0.6, 0.02 * side), Vector3(0, 0, 0.1), Vector3(0.8, 1.35, 0.95))
		_part(arm, _sphere(0.32), skin_mat, Vector3(-0.17, -0.7, 0), Vector3(0, 0, -0.1), Vector3(0.75, 1.3, 0.9))
		var fore := _pivot(arm_name + "_fore", arm, Vector3(0, -1.2, 0))
		fore.rotation.z = 0.7
		# Elbow knob.
		_part(fore, _sphere(0.3), armor_mat, Vector3(-0.12, 0.02, 0), Vector3.ZERO, Vector3(1.0, 0.85, 0.95))
		_part(fore, _capsule(0.34, 1.35), skin_mat, Vector3(0.0, -0.55, 0))
		_part(fore, _sphere(0.3), skin_mat, Vector3(-0.08, -0.3, 0.05 * side), Vector3.ZERO, Vector3(0.9, 1.4, 0.95))
		for i in 3:
			_part(fore, _sphere(0.3), armor_mat, Vector3(0.2, -0.2 - i * 0.3, 0), Vector3(0, 0, 0.15), Vector3(0.6, 0.75, 1.15))
		if _v["arm_spikes"]:
			for i in 2:
				_spike_piece(fore, 1, Vector3(-0.22, -0.3 - i * 0.35, 0), PI / 2 + 0.5, 0.35 * ss, 0.0)
		# Hand on its own wrist pivot so it can trail the forearm.
		var hand := _pivot(arm_name + "_hand", fore, Vector3(0.06, -1.05, 0))
		_part(hand, _sphere(0.32), skin_mat, Vector3(0.0, -0.15, 0), Vector3.ZERO, Vector3(1.15, 0.9, 1.2))
		for c in 3:
			var z := (c - 1) * 0.17
			_part(hand, _sphere(0.11), skin_mat, Vector3(0.12, -0.3, z))
			_part(hand, _capsule(0.085, 0.26), skin_mat, Vector3(0.155, -0.36, z), Vector3(0, 0, 0.6))
			_part(hand, _sphere(0.08), skin_mat, Vector3(0.18, -0.4, z))
			_part(hand, _claw(), claw_mat, Vector3(0.18, -0.39, z), Vector3(0, 0, PI - 0.35), Vector3(0.75, 0.62, 0.75))
		_part(hand, _sphere(0.1), skin_mat, Vector3(-0.1, -0.22, 0.17 * side))
		_part(hand, _claw(), claw_mat, Vector3(-0.14, -0.25, 0.2 * side), Vector3(0.3 * side, 0, PI + 0.5), Vector3(0.6, 0.5, 0.6))

	# --- legs: massive thighs, knees, clawed feet ---------------------------
	for side in [1.0, -1.0]:
		var nm := "leg_r" if side > 0 else "leg_l"
		var leg := _pivot(nm, hips, Vector3(0, 0.1, 0.85 * side))
		_part(leg, _sphere(0.95), skin_mat, Vector3(0.05, -0.45, 0.05 * side), Vector3(0, 0, 0.1), Vector3(1.05, 1.35, 1.0))
		# Outer thigh muscle and hamstring.
		_part(leg, _sphere(0.6), skin_mat, Vector3(0.25, -0.55, 0.32 * side), Vector3(0, 0, 0.2), Vector3(0.9, 1.3, 0.75))
		_part(leg, _sphere(0.55), skin_mat, Vector3(-0.3, -0.7, 0.05 * side), Vector3(0, 0, -0.15), Vector3(0.8, 1.2, 0.9))
		var shin := _pivot(nm + "_shin", leg, Vector3(0.3, -1.0, 0))
		_part(shin, _capsule(0.55, 1.6), skin_mat, Vector3(-0.12, -0.45, 0))
		_part(shin, _sphere(0.42), armor_mat, Vector3(0.25, -0.05, 0), Vector3.ZERO, Vector3(0.6, 0.7, 0.9))
		_part(shin, _sphere(0.2), armor_mat, Vector3(0.36, -0.25, 0), Vector3.ZERO, Vector3(0.7, 0.8, 1.0))
		# Calf.
		_part(shin, _sphere(0.45), skin_mat, Vector3(-0.42, -0.35, 0), Vector3(0, 0, -0.1), Vector3(0.75, 1.3, 0.9))
		var foot := _pivot(nm + "_foot", shin, Vector3(-0.1, -0.95, 0))
		_part(foot, _sphere(0.62), skin_mat, Vector3(0.15, -0.15, 0), Vector3.ZERO, Vector3(1.45, 0.55, 1.1))
		# Ankle scutes.
		for i in 4:
			_part(foot, _sphere(0.14), armor_mat, Vector3(0.0 + i * 0.22, 0.1 - i * 0.05, 0.42 * (1.0 if i % 2 == 0 else -1.0)),
				Vector3.ZERO, Vector3(1.0, 0.6, 0.8))
		for c in 3:
			var z := (c - 1) * 0.34
			_part(foot, _sphere(0.22), skin_mat, Vector3(0.55, -0.22, z), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
			_part(foot, _sphere(0.18), skin_mat, Vector3(0.78, -0.26, z), Vector3.ZERO, Vector3(1.2, 0.75, 0.95))
			_part(foot, _claw(), claw_mat, Vector3(0.95, -0.27, z), Vector3(0, 0, -PI / 2 + 0.1), Vector3(0.9, 0.75, 0.9))
		_part(foot, _claw(), claw_mat, Vector3(-0.5, -0.3, 0), Vector3(0, 0, PI / 2 - 0.2), Vector3(0.7, 0.55, 0.7))

	# --- tail: thick, tapering, overlapping segments with ridge plates -------
	var parent: Node3D = hips
	var offset := Vector3(-0.9, 0.3, 0)
	var tl: float = _v["tail_len"]
	for i in TAIL_SEGMENTS:
		var seg := _pivot("tail%d" % i, parent, offset)
		var r := 0.9 * (1.0 - i * 0.085) * float(_v["tail_thick"])
		_part(seg, _capsule(r, r * 2.0 + 0.85 * tl), skin_mat, Vector3(-0.36, 0, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 1.05))
		_part(seg, _sphere(r * 0.8), belly_mat, Vector3(-0.33, -r * 0.42, 0), Vector3(0, 0, 0.1), Vector3(1.0, 0.55, 1.0))
		for side in [-1.0, 1.0]:
			_part(seg, _sphere(r * 0.24), armor_mat, Vector3(-0.35, r * 0.25, r * 0.88 * side), Vector3(0.6 * side, 0, 0),
				Vector3(1.4, 0.7, 0.45))
		var ph := (0.3 + r * 0.6) * ss
		_spike_piece(seg, shape, Vector3(-0.18, r * 0.88, 0), 0.4, ph, 0.0)
		if i % 2 == 0:
			_spike_piece(seg, shape, Vector3(-0.52, r * 0.85, 0), 0.4, ph * 0.8, 0.0)
		if rows >= 2 and i < 7 and i % 2 == 1:
			for side in [-1.0, 1.0]:
				_spike_piece(seg, shape, Vector3(-0.36, r * 0.7, r * 0.45 * side), 0.45, ph * 0.5, 0.45 * side)
		if i == TAIL_SEGMENTS - 1:
			_part(seg, _claw(), skin_mat, Vector3(-0.85, 0, 0), Vector3(0, 0, PI / 2 + 0.15), Vector3(r * 4.5, 1.4, r * 4.5))
		_tail.append(seg)
		parent = seg
		offset = Vector3(-0.68 * tl, -0.07, 0)
	_commit()


## World position of the tip of the open mouth (for breath beams).
func mouth_global() -> Vector3:
	return parts["jaw"].to_global(Vector3(1.1, 0.1, 0)) if parts.has("jaw") else global_position + Vector3(0, 5, 0)


## A node to hang a cosmetic item on (see Cosmetics): it rides on the body
## part for the slot ("head", "face", "neck", "back" or "tail") and its axes
## follow the slot's frame described in Cosmetics. Null if there is no such
## part. These offsets are rough; the heroes use GlbKaijuModel's.
func cosmetic_anchor(slot: String) -> Node3D:
	var spot: Array = {"head": ["head", Vector3(0.3, 0.75, 0), 0.0], "face": ["head", Vector3(0.8, 0.3, 0), 0.0],
		"neck": ["neck", Vector3(0.2, 0.4, 0), -60.0], "back": ["torso", Vector3(0.4, 2.9, 0), 0.0],
		"tail": ["tail%d" % (TAIL_SEGMENTS - 1), Vector3.ZERO, 0.0]}.get(slot, [])
	if spot.is_empty() or not parts.has(spot[0]):
		return null
	var n := Node3D.new()
	n.position = spot[1]
	n.rotation.z = deg_to_rad(spot[2])
	parts[spot[0]].add_child(n)
	return n


func spike_color() -> Color:
	return _spike_color


func flash() -> void:
	_flash = 1.0


## Gives a pose channel's spring a shove (a flinch, a recoil).
func kick(key: String, v: float) -> void:
	_vel[key] = _vel.get(key, 0.0) + v


## Touchdown after a jump or fall; `hard` (0-1.6) scales the landing squash.
func land(hard: float) -> void:
	_vel["squash"] = maxf(_vel.get("squash", 0.0), 2.0 + hard * 3.5)


func _process(delta: float) -> void:
	if parts.is_empty():
		return
	_pose(delta)
	var ar: float = _cur["arm_r"]
	var al: float = _cur["arm_l"]
	var ln: float = _cur["lean"]
	var sq: float = _cur["squash"]
	var w := _walk
	var s := sin(_phase)
	var c := cos(_phase)
	var breathe := sin(_t * 2.0)
	var sway := sin(_t * 0.7)

	# Legs: thighs swing, knees fold while the leg swings forward, feet stay
	# level. A landing squash bends both knees.
	for side in [1.0, -1.0]:
		var nm := "leg_r" if side > 0 else "leg_l"
		var ls: float = s * side
		var lc: float = c * side
		var thigh: float = ls * 0.55 * w + sq * 0.35 + 0.08
		var knee: float = -maxf(lc, 0.0) * 0.85 * w - 0.16 - sq * 0.7 - (1.0 - w) * 0.04 * (1.0 + sway * side)
		parts[nm].rotation.z = thigh
		parts[nm + "_shin"].rotation.z = knee
		parts[nm + "_foot"].rotation.z = -(thigh + knee) * 0.9 + maxf(-lc, 0.0) * maxf(-ls, 0.0) * 0.4 * w

	# Body: bob twice per stride, rock side to side over the standing leg,
	# drop on landings, breathe when idle.
	var hips: Node3D = parts["hips"]
	hips.position.y = 2.38 + absf(c) * 0.16 * w - 0.06 * w + breathe * 0.035 - sq * 0.35
	hips.rotation.x = s * 0.07 * w + sway * 0.015 * (1.0 - w)
	hips.rotation.y = s * 0.05 * w
	var torso: Node3D = parts["torso"]
	torso.rotation.z = -ln + breathe * 0.02 - w * 0.06 + sq * 0.12 + float(_v["posture"])
	torso.rotation.y = -s * 0.08 * w
	torso.rotation.x = -hips.rotation.x * 0.6
	# Neck and head trail the torso slightly and stay steady while walking.
	parts["neck"].rotation.z = ln * 0.15 + sin(_t * 1.7 - 0.4) * 0.03 - float(_v["posture"]) * 0.6
	var head: Node3D = parts["head"]
	head.rotation.z = sin(_t * 1.7) * 0.05 + ln * 0.4 - absf(c) * 0.05 * w + w * 0.05 - sq * 0.15
	head.rotation.y = s * 0.06 * w + sin(_t * 0.6) * 0.05 * (1.0 - w)
	head.rotation.x = -hips.rotation.x * 0.8
	parts["jaw"].rotation.z = -_cur["jaw"] * 0.7

	# Arms swing against the legs; forearms and hands lag behind the upper
	# arm's motion and snap through after it.
	for side in [1.0, -1.0]:
		var nm := "arm_r" if side > 0 else "arm_l"
		var v: float = ar if side > 0 else al
		var vv: float = _vel.get(nm, 0.0)
		parts[nm].rotation.z = v - s * 0.35 * w * side
		parts[nm].rotation.x = -side * (0.06 + breathe * 0.015)
		parts[nm + "_fore"].rotation.z = 0.7 + clampf(-vv * 0.035, -0.45, 0.6) + sin(_phase - 0.8) * 0.12 * w * side \
			- clampf(v - 1.5, 0.0, 1.5) * 0.25
		parts[nm + "_hand"].rotation.z = clampf(-vv * 0.03, -0.5, 0.5) + sin(_t * 1.9 + side) * 0.04

	# Tail: travelling wave in step with the stride, trails turns, rises to
	# balance a forward lean and droops on the way up from a jump.
	var turn: float = _cur["turn"]
	for i in _tail.size():
		var seg := _tail[i]
		var k := float(i + 1) / _tail.size()
		seg.rotation.y = sin(_t * 2.2 - i * 0.55) * 0.09 * (1.0 + w) + sin(_phase - 0.9 - i * 0.45) * 0.07 * w \
			- turn * 0.12 * k
		seg.rotation.z = -0.03 + sin(_t * 1.3 - i * 0.4) * 0.035 + ln * 0.05 + clampf(-_vy * 0.006, -0.08, 0.08) \
			- sq * 0.06 * (1.0 - k)

	_update_glow(delta)


## Advances the springs, walk phase and the body's own motion (vertical speed,
## turning rate, landings) that drive the secondary animation.
func _pose(delta: float, gait: float = 8.5) -> void:
	_t += delta
	_walk = lerpf(_walk, walk_amount, 1.0 - exp(-8.0 / heft * delta))
	_phase += delta * gait * walk_speed * maxf(_walk, 0.05)
	var targets := {"arm_r": arm_r, "arm_l": arm_l, "jaw": jaw, "lean": lean, "squash": crouch * 0.6, "turn": 0.0}
	var pos := global_position
	var yaw := rotation.y
	if _moved and delta > 0.0:
		var vy := (pos.y - _last_pos.y) / delta
		if _vy < -8.0 and vy > _vy * 0.3:
			# Just landed: kick the squash spring.
			_vel["squash"] = _vel.get("squash", 0.0) + clampf(-_vy * 0.22, 0.0, 6.0)
		_vy = vy
		_yaw_rate = lerpf(_yaw_rate, wrapf(yaw - _last_yaw, -PI, PI) / delta, 1.0 - exp(-20.0 * delta))
		targets["turn"] = clampf(_yaw_rate * 0.25, -2.0, 2.0)
	_last_pos = pos
	_last_yaw = yaw
	_moved = true
	# Small fixed substeps keep the springs stable at low frame rates.
	var steps := clampi(ceili(delta / (1.0 / 120.0)), 1, 8)
	var dt := delta / steps
	for key in targets:
		var spring: Array = SPRINGS[key]
		var f: float = spring[0] / heft
		var z: float = spring[1]
		var x: float = _cur.get(key, 0.0)
		var v: float = _vel.get(key, 0.0)
		var target: float = targets[key]
		for _i in steps:
			v += (f * f * (target - x) - 2.0 * z * f * v) * dt
			x += v * dt
		_cur[key] = x
		_vel[key] = v


func _update_glow(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 7.0, 0.0)
		var c := Vector3(1, 0.95, 0.9) * _flash * 1.5
		for m in _body_mats:
			m.set_shader_parameter("flash_color", c)
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	var e := 0.3 + glow * (3.0 + pulse * (3.0 if glow >= 1.0 else 0.0))
	_spike_mat.set_shader_parameter("glow_energy", e)
	_seam_mat.set_shader_parameter("glow_energy", 0.6 + e * 0.8)
	_eye_mat.emission_energy_multiplier = 3.0 + eye_glow * 8.0


# --- look variants ---------------------------------------------------------

## Stable per-colour-set look: same colours, same kaiju.
func _variant(skin: Color, belly: Color, spike: Color) -> Dictionary:
	var h := hash(skin.to_html() + belly.to_html() + spike.to_html())
	var r := RandomNumberGenerator.new()
	r.seed = h
	var v := {
		"spike_shape": r.randi() % 5,
		"rows": 2 + r.randi() % 2,
		"spike_size": r.randf_range(0.85, 1.25),
		"horn_size": r.randf_range(0.8, 1.3),
		"gem": r.randf() < 0.35,
		"seams": r.randf() < 0.4,
		"crest": r.randf() < 0.3,
		"arm_spikes": r.randf() < 0.4,
		"neck_len": r.randf_range(0.85, 1.15),
		"head_size": r.randf_range(0.95, 1.08),
		"snout": r.randf_range(0.92, 1.1),
		"bulk": r.randf_range(0.95, 1.08),
		"arm_size": r.randf_range(0.92, 1.08),
		"tail_len": r.randf_range(0.92, 1.1),
		"tail_thick": 1.0,
		"posture": 0.1,
	}
	v.merge(look, true)
	return v


## One dorsal spike: 0 leaf plate, 1 cone spike, 2 swept blade, 3 three-lobed
## maple-leaf plate, 4 crystal shard cluster. `rot` tilts it in the side plane
## (0 = straight up), `roll` leans it outward.
func _spike_piece(parent: Node3D, shape: int, pos: Vector3, rot: float, h: float, roll: float) -> void:
	match shape:
		0:
			_part(parent, _plate(), _spike_mat, pos, Vector3(roll, 0, rot), Vector3(h * 0.78, h, h * 0.22))
		1:
			_part(parent, _claw(), _spike_mat, pos, Vector3(roll, 0, rot + 0.25), Vector3(h * 0.9, h * 1.05, h * 0.9))
		3:
			_part(parent, _plate(), _spike_mat, pos, Vector3(roll, 0, rot), Vector3(h * 0.7, h * 1.1, h * 0.24))
			for a in [-0.55, 0.55]:
				_part(parent, _plate(), _spike_mat, pos, Vector3(roll, 0, rot + a), Vector3(h * 0.5, h * 0.72, h * 0.2))
		4:
			for k in 3:
				var a: float = [0.0, -0.45, 0.4][k]
				var l: float = h * [1.15, 0.75, 0.6][k]
				var b := Basis.from_euler(Vector3(roll + (k - 1) * 0.25, 0, rot + a))
				_part(parent, _shard(), _spike_mat, pos - b.y * l * 0.08,
					Vector3(roll + (k - 1) * 0.25, 0, rot + a), Vector3(h * 0.85, l, h * 0.85))
		_:
			_part(parent, _plate(), _spike_mat, pos, Vector3(roll, 0, rot + 0.55), Vector3(h * 0.55, h * 1.25, h * 0.14))


# --- construction helpers --------------------------------------------------

static func _noise_tex(key: String, normal: bool, cellular: bool, freq: float, size: int, invert: bool, bump: float) -> NoiseTexture2D:
	if _tex.has(key):
		return _tex[key]
	var n := FastNoiseLite.new()
	n.seed = 7
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	else:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 3
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.generate_mipmaps = true
	t.invert = invert
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	t.noise = n
	_tex[key] = t
	return t


func _skin(color: Color, dark: Color, roughness: float, scaly: float, bumps: float, ribs: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKIN_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("albedo_dark", dark)
	m.set_shader_parameter("cavity_color", color.darkened(0.85))
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("scale_normal", _noise_tex("scales", true, true, 0.07, 256, true, 6.0))
	m.set_shader_parameter("scale_mask", _noise_tex("scale_mask", false, true, 0.07, 256, false, 0.0))
	m.set_shader_parameter("bump_normal", _noise_tex("bumps", true, true, 0.035, 256, true, 10.0))
	m.set_shader_parameter("mottle", _noise_tex("mottle", false, false, 0.012, 128, false, 0.0))
	m.set_shader_parameter("scale_strength", scaly)
	m.set_shader_parameter("bump_strength", bumps)
	m.set_shader_parameter("ribs", ribs)
	m.set_shader_parameter("backlight_color", color.lerp(Color(0.6, 0.12, 0.08), 0.5) * 0.4)
	_body_mats.append(m)
	return m


func _spike(base_c: Color, tip: Color, glow_c: Color, energy: float, rough: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SPIKE_SHADER
	m.set_shader_parameter("base_color", base_c)
	m.set_shader_parameter("tip_color", tip)
	m.set_shader_parameter("glow_color", glow_c)
	m.set_shader_parameter("glow_energy", energy)
	m.set_shader_parameter("roughness", rough)
	_body_mats.append(m)
	return m


func _flat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _pivot(pivot_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	parts[pivot_name] = n
	return n


## Queues a static piece on a pivot; _commit() merges them per material.
func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	if not _pending.has(parent):
		_pending[parent] = {}
	var by_mat: Dictionary = _pending[parent]
	if not by_mat.has(mat):
		by_mat[mat] = []
	var xf := Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)
	by_mat[mat].append([mesh, xf])


## A capsule limb from a to b.
func _seg(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, scl: Vector3 = Vector3.ONE) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var basis := Basis(Quaternion(Vector3.UP, d / l)) * Basis.from_scale(scl)
	_part_xf(parent, _capsule(r, l + r * 2.0), mat, Transform3D(basis, (a + b) * 0.5))


func _part_xf(parent: Node3D, mesh: Mesh, mat: Material, xf: Transform3D) -> void:
	if not _pending.has(parent):
		_pending[parent] = {}
	var by_mat: Dictionary = _pending[parent]
	if not by_mat.has(mat):
		by_mat[mat] = []
	by_mat[mat].append([mesh, xf])


func _commit() -> void:
	for pivot in _pending:
		var by_mat: Dictionary = _pending[pivot]
		for mat in by_mat:
			var st := SurfaceTool.new()
			for item in by_mat[mat]:
				st.append_from(item[0], 0, item[1])
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat
			pivot.add_child(mi)
	_pending.clear()


static func _cached(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]

## Radial segment count for a round part of radius `r`: big parts get many
## segments so silhouettes stay smooth, small ones stay cheap.
func _segments(r: float) -> int:
	var base := 10.0 + 26.0 * clampf(r / 1.2, 0.0, 1.0)
	var mul: float = [0.6, 0.85, 1.25][clampi(detail, 0, 2)]
	return maxi(8, int(round(base * mul / 2.0)) * 2)


func _capsule(r: float, h: float) -> Mesh:
	var seg := _segments(r)
	var rings := maxi(6, int(seg * (0.35 + clampf(h / (r * 8.0), 0.0, 0.4))))
	return _cached("cap_%.3f_%.3f_%d_%d" % [r, h, seg, rings], func() -> Mesh:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(h, r * 2.0)
		c.radial_segments = seg
		c.rings = rings
		return c)


func _sphere(r: float) -> Mesh:
	var seg := _segments(r)
	return _cached("sph_%.3f_%d" % [r, seg], func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = seg / 2
		return s)


func _box(size: Vector3) -> Mesh:
	return _cached("box_%s" % size, func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)


## Curved, tapering claw / horn / tooth: base radius 0.15 at the origin,
## about 1 long, curving from +Y toward +X. UV.y = 0 at the tip.
func _claw() -> Mesh:
	var d := clampi(detail, 0, 2)
	return _claw_mesh([6, 8, 12][d], [6, 8, 12][d])


static func _claw_mesh(steps: int, sides: int) -> Mesh:
	var key := "claw_%d_%d" % [steps, sides]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var centres: Array = []
	for j in steps + 1:
		var t := float(j) / steps
		var th := t * 1.1
		var cpos := Vector3(0.9 * (1.0 - cos(th)), 0.9 * sin(th), 0)
		var nrm := Vector3(cos(th), -sin(th), 0)
		# Slightly convex taper: fuller near the base, sharp at the tip.
		var rad := 0.15 * pow(1.0 - t, 0.85) + 0.004
		var ring: Array = []
		for k in sides:
			var a := TAU * k / sides
			ring.append(cpos + (nrm * cos(a) + Vector3(0, 0, 1) * sin(a)) * rad)
		rings.append(ring)
		centres.append(cpos)
	for j in steps:
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Vector3 = rings[j][k]
			var b: Vector3 = rings[j][k2]
			var c: Vector3 = rings[j + 1][k2]
			var e: Vector3 = rings[j + 1][k]
			var cen: Vector3 = (centres[j] + centres[j + 1]) * 0.5
			var v0 := 1.0 - float(j) / steps
			var v1 := 1.0 - float(j + 1) / steps
			_tri_smooth(st, [a, b, c], [centres[j], centres[j], centres[j + 1]], [v0, v0, v1], cen)
			_tri_smooth(st, [a, c, e], [centres[j], centres[j + 1], centres[j + 1]], [v0, v1, v1], cen)
	# Base cap.
	for k in sides:
		var k2 := (k + 1) % sides
		_tri_flat(st, centres[0], rings[0][k], rings[0][k2], centres[0] + Vector3(0, 0.1, 0), 1.0)
	st.generate_tangents()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _tri_smooth(st: SurfaceTool, v: Array, c: Array, uv: Array, centre: Vector3) -> void:
	var a: Vector3 = v[0]
	var n: Vector3 = (v[1] - a).cross(v[2] - a)
	var order := [0, 2, 1]
	if n.dot((a + v[1] + v[2]) / 3.0 - centre) < 0.0:
		order = [0, 1, 2]
	for i in order:
		var p: Vector3 = v[i]
		st.set_normal((p - c[i]).normalized())
		st.set_uv(Vector2(0.5, uv[i]))
		st.add_vertex(p)


static func _tri_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, v: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		n = -n
		var tmp := b
		b = c
		c = tmp
	for p in [a, c, b]:
		st.set_normal(n)
		st.set_uv(Vector2(0.5, v))
		st.add_vertex(p)


## Six-sided crystal: base radius 0.18 at y=0, faceted point at y=1.
static func _shard() -> Mesh:
	if _meshes.has("shard"):
		return _meshes["shard"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 1.0, 0)
	var centre := Vector3(0, 0.4, 0)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var b0 := Vector3(cos(a0), 0, sin(a0)) * 0.18
		var b1 := Vector3(cos(a1), 0, sin(a1)) * 0.18
		var m0 := b0 * 1.15 + Vector3(0, 0.68, 0)
		var m1 := b1 * 1.15 + Vector3(0, 0.68, 0)
		_tri_flat(st, b0, m0, m1, centre, 0.4)
		_tri_flat(st, b0, m1, b1, centre, 0.4)
		_tri_flat(st, m0, tip, m1, centre, 0.0)
		_tri_flat(st, b0, b1, Vector3.ZERO, centre + Vector3(0, 0.5, 0), 1.0)
	st.generate_tangents()
	var mesh := st.commit()
	_meshes["shard"] = mesh
	return mesh


## Faceted, jagged dorsal plate in the XY plane: base on y=0 (width 1),
## tip at y=1, thickest along the middle (z +-0.5 before scaling).
static func _plate() -> Mesh:
	if _meshes.has("plate"):
		return _meshes["plate"]
	var outline := [Vector2(-0.5, 0.0), Vector2(-0.46, 0.28), Vector2(-0.33, 0.25), Vector2(-0.3, 0.52),
		Vector2(-0.17, 0.5), Vector2(-0.1, 0.78), Vector2(0.0, 1.0), Vector2(0.09, 0.74), Vector2(0.2, 0.48),
		Vector2(0.3, 0.5), Vector2(0.3, 0.24), Vector2(0.42, 0.22), Vector2(0.5, 0.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zs in [1.0, -1.0]:
		var ridge := Vector3(0.0, 0.32, 0.5 * zs)
		for i in outline.size() - 1:
			var a := Vector3(outline[i].x, outline[i].y, 0)
			var b := Vector3(outline[i + 1].x, outline[i + 1].y, 0)
			_plate_tri(st, ridge, a, b, Vector3(0, 0.32, 0))
		_plate_tri(st, ridge, Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0.32, 0))
	st.generate_tangents()
	var mesh := st.commit()
	_meshes["plate"] = mesh
	return mesh


static func _plate_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		n = -n
		var tmp := b
		b = c
		c = tmp
	# Clockwise front faces in Godot.
	for v in [a, c, b]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x + 0.5, 1.0 - v.y))
		st.add_vertex(v)
