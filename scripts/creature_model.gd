class_name CreatureModel
extends KaijuModel
## Enemy monster with its own body plan, so enemies never share the heroes'
## upright, tailed kaiju silhouette. Set `plan` and `extras` before build().
##
## Plans:
##   quad     four-legged beast (horned chargers, crocs, shelled tanks)
##   insect   six- or eight-legged arthropod (spiders, mantises, scorpions, ticks)
##   serpent  legless snake or worm with a raised neck
##   ape      knuckle-walking brute: huge arms, short legs, no tail
##   golem    ape rig built from rock chunks with glowing cracks
##   mech     four-legged walking war machine with a turret head
##
## It takes the same pose targets as KaijuModel (walk_amount, walk_speed,
## arm_r, arm_l, jaw, lean, glow, eye_glow, spin) and maps them onto the plan:
## a quad rears up where a kaiju raises its arms, a serpent pulls its neck
## back, an insect lifts its front legs or blades.

## Rough standing height of each plan relative to a hero kaiju (1.0).
const HEIGHT := {"quad": 0.66, "insect": 0.5, "serpent": 0.8, "ape": 0.85, "golem": 0.95, "mech": 0.75}

var plan := "quad"
var extras: Array = []

var _m := {}
var _legs: Array = []  # [{n, ph, swing, lift, rest}]
var _arms: Array = []  # [{n, fore, side, rest, fore_rest}]
var _body: Node3D
var _body_y := 0.0
var _body_rest := 0.0
var _neck: Array[Node3D] = []
var _abdomen: Node3D
var _stinger: Node3D
var _mands: Array[Node3D] = []


func _init() -> void:
	detail = 1


func build(skin: Color, belly: Color, spike: Color, eye: Color, horns: bool = false) -> void:
	_spike_color = spike
	_v = _variant(skin, belly, spike)
	_materials(skin, belly, spike, eye)
	match plan:
		"insect", "mech":
			_build_insect(horns)
		"serpent":
			_build_serpent(horns)
		"ape", "golem":
			_build_ape(horns)
		_:
			_build_quad(horns)
	_commit()


func has(extra: String) -> bool:
	return extra in extras


func _materials(skin: Color, belly: Color, spike: Color, eye: Color) -> void:
	var dark := skin.darkened(0.35).lerp(spike.darkened(0.75), 0.12)
	match plan:
		"insect":
			# Glossy chitin: few scales, banded segments.
			_m["skin"] = _skin(skin, dark, 0.28, 0.15, 0.25, 0.6)
			_m["belly"] = _skin(belly, belly.darkened(0.3), 0.3, 0.1, 0.2, 0.8)
		"mech":
			_m["skin"] = _skin(skin, skin.darkened(0.25), 0.25, 0.0, 0.08, 0.9)
			_m["belly"] = _skin(belly, belly.darkened(0.2), 0.3, 0.0, 0.05, 0.0)
		"golem":
			_m["skin"] = _skin(skin, skin.darkened(0.5), 0.9, 0.0, 1.6, 0.0)
			_m["belly"] = _skin(belly, belly.darkened(0.4), 0.85, 0.0, 1.4, 0.0)
		"serpent":
			_m["skin"] = _skin(skin, dark, 0.45, 1.3, 0.4, 0.0)
			_m["belly"] = _skin(belly, belly.darkened(0.25), 0.4, 0.2, 0.2, 1.0)
		"ape":
			# Leathery hide, deep folds.
			_m["skin"] = _skin(skin, dark, 0.75, 0.2, 1.3, 0.0)
			_m["belly"] = _skin(belly, belly.darkened(0.3), 0.7, 0.1, 0.9, 0.0)
		_:
			_m["skin"] = _skin(skin, dark, 0.6, 1.0, 1.1, 0.0)
			_m["belly"] = _skin(belly, belly.darkened(0.25), 0.45, 0.3, 0.4, 0.7)
	var armor_c := skin.lerp(belly, 0.3).darkened(0.12)
	_m["armor"] = _skin(armor_c, skin.darkened(0.4), 0.35, 0.1, 0.5, 0.0)
	_m["bone"] = _spike(Color(0.86, 0.82, 0.72), Color(0.25, 0.2, 0.17), Color.BLACK, 0.0, 0.3)
	_m["mouth"] = _flat(Color(0.3, 0.06, 0.07), 0.35)
	_m["socket"] = _flat(skin.darkened(0.8), 0.9)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.5, 0.52, 0.56)
	steel.metallic = 0.85
	steel.roughness = 0.3
	_m["steel"] = steel
	_spike_mat = _spike(skin.darkened(0.45), spike.lerp(Color.WHITE, 0.15), spike, 0.3, 0.3)
	_seam_mat = _spike(spike.darkened(0.5), spike, spike, 0.2, 0.4)
	_m["spike"] = _spike_mat
	_m["glow"] = _seam_mat
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = eye
	_eye_mat.emission_enabled = true
	_eye_mat.emission = eye
	_eye_mat.emission_energy_multiplier = 3.0
	_m["eye"] = _eye_mat


# --- quad ----------------------------------------------------------------

func _build_quad(horns: bool) -> void:
	var sk: Material = _m["skin"]
	var bl: Material = _m["belly"]
	var croc := has("snout")
	var low := 0.75 if croc else 1.0
	_body_y = 2.3 * low
	_body = _pivot("hips", self, Vector3(0, _body_y, 0))
	parts["torso"] = _body
	_part(_body, _capsule(1.25, 5.0), sk, Vector3(0, 0.1, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 1.1))
	_part(_body, _sphere(1.25), sk, Vector3(1.4, 0.35, 0), Vector3.ZERO, Vector3(1.0, 1.05, 1.15))
	_part(_body, _sphere(1.2), sk, Vector3(-1.3, 0.2, 0), Vector3.ZERO, Vector3(1.05, 1.0, 1.15))
	_part(_body, _sphere(1.0), bl, Vector3(0.1, -0.62, 0), Vector3.ZERO, Vector3(2.2, 0.5, 1.0))
	# Bony ridge down the spine.
	if not has("shell"):
		var shape: int = _v["spike_shape"]
		for i in 9:
			var x := 1.9 - i * 0.48
			var h := (0.45 + sin(float(i) / 8.0 * PI) * 0.6) * float(_v["spike_size"])
			_spike_piece(_body, shape, Vector3(x, 1.12 + sin(float(i) / 8.0 * PI) * 0.15, 0), -0.2, h, 0.0)

	# Neck and head, held low and forward.
	var neck := _pivot("neck", _body, Vector3(2.4, 0.35, 0))
	_seg(neck, Vector3.ZERO, Vector3(0.9, 0.25, 0), 0.72, sk)
	var head := _pivot("head", neck, Vector3(1.1, 0.3, 0))
	_neck.append(neck)
	_part(head, _sphere(0.75), sk, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.2, 0.85, 1.05))
	var snout_len := 3.0 if croc else 1.6
	_seg(head, Vector3(0.4, -0.1, 0), Vector3(0.4 + snout_len, -0.15, 0), 0.42 if croc else 0.48, sk, Vector3(1, 0.7, 1.15))
	for side in [-1.0, 1.0]:
		_part(head, _capsule(0.14, 0.75), _m["armor"], Vector3(0.45, 0.42, 0.42 * side), Vector3(0.3 * side, 0, -PI / 2 + 0.3))
		_part(head, _sphere(0.17), _m["socket"], Vector3(0.55, 0.28, 0.48 * side), Vector3.ZERO, Vector3(1.2, 0.75, 0.6))
		_part(head, _sphere(0.1), _eye_mat, Vector3(0.62, 0.28, 0.52 * side), Vector3.ZERO, Vector3(1.4, 0.7, 0.6))
		_part(head, _sphere(0.07), _m["socket"], Vector3(0.4 + snout_len, 0.05, 0.16 * side))
		var n := int(snout_len / 0.2)
		for i in n:
			var tl := 0.17 + (0.06 if i % 3 == 0 else 0.0)
			_claw_at(head, Vector3(0.55 + i * 0.2, -0.38, 0.3 * side), Vector3.DOWN, Vector3.RIGHT, tl, _m["bone"])
		if horns:
			var hs: float = _v["horn_size"] * 1.4
			_claw_at(head, Vector3(-0.15, 0.55, 0.45 * side), Vector3(0.3, 1, 0.5 * side), Vector3.RIGHT, hs, _m["bone"])
	var jaw := _pivot("jaw", head, Vector3(0.25, -0.38, 0))
	_seg(jaw, Vector3(0.1, -0.05, 0), Vector3(snout_len + 0.1, -0.05, 0), 0.32 if croc else 0.34, sk, Vector3(1, 0.65, 1.35))
	_part(jaw, _box(Vector3(snout_len, 0.05, 0.5)), _m["mouth"], Vector3(0.2 + snout_len * 0.5, 0.15, 0))
	for side in [-1.0, 1.0]:
		for i in int(snout_len / 0.22):
			_claw_at(jaw, Vector3(0.35 + i * 0.22, 0.12, 0.26 * side), Vector3.UP, Vector3.RIGHT, 0.14, _m["bone"])
	if has("nose_horn"):
		_claw_at(head, Vector3(1.35, 0.25, 0), Vector3(0.15, 1, 0), Vector3.RIGHT, 2.1, _m["bone"])
		_claw_at(head, Vector3(0.7, 0.55, 0), Vector3(0, 1, 0), Vector3.RIGHT, 1.0, _m["bone"])
	if has("crest"):
		# Bony neck frill rimmed with spikes.
		_part(head, _sphere(1.0), _m["armor"], Vector3(-0.45, 0.55, 0), Vector3(0, 0, 0.55), Vector3(0.22, 1.25, 1.55))
		for i in 7:
			var a := -1.2 + i * 0.4
			_claw_at(head, Vector3(-0.75, 0.55 + cos(a) * 1.1, sin(a) * 1.45), Vector3(-0.5, cos(a), sin(a) * 1.2), Vector3(-1, 0, 0), 0.7, _m["spike"])
	if has("sacs"):
		_part(head, _sphere(0.55), _m["glow"], Vector3(0.35, -0.75, 0), Vector3.ZERO, Vector3(1.2, 0.9, 1.0))
		for i in 3:
			_part(_body, _sphere(0.36), _m["glow"], Vector3(0.8 - i * 0.9, 1.05, 0.55 * (1 if i % 2 == 0 else -1)))

	# Four legs. Crocs splay theirs out to the sides.
	var leg_defs := [["leg_fr", 1.6, 1.0, 0.0], ["leg_bl", -1.5, -1.0, 0.0], ["leg_fl", 1.6, -1.0, PI], ["leg_br", -1.5, 1.0, PI]]
	for ld in leg_defs:
		var side: float = ld[2]
		var leg := _pivot(ld[0], _body, Vector3(ld[1], -0.35, (1.0 + (0.35 if croc else 0.0)) * side))
		var drop := _body_y - 0.35 - 0.05
		var foot := Vector3(0.15, -drop + 0.2, (0.5 if croc else 0.0) * side)
		_part(leg, _sphere(0.72), sk, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1.1, 1.15, 0.9))
		var knee := Vector3(0.05, -drop * 0.55, foot.z * 0.6)
		_seg(leg, Vector3(0, -0.2, 0), knee, 0.5, sk)
		_seg(leg, knee, foot, 0.42, sk)
		_part(leg, _sphere(0.5), sk, foot + Vector3(0.1, -0.02, 0), Vector3.ZERO, Vector3(1.35, 0.5, 1.15))
		for c in 3:
			_claw_at(leg, foot + Vector3(0.6, -0.08, (c - 1) * 0.28), Vector3.RIGHT, Vector3.DOWN, 0.75, _m["bone"])
		_legs.append({"n": leg, "ph": ld[3], "swing": 0.55, "lift": 0.0, "rest": leg.rotation})

	# Heavy tapering tail.
	var parent: Node3D = _body
	var off := Vector3(-2.4, 0.1, 0)
	for i in 6:
		var seg := _pivot("tail%d" % i, parent, off)
		var r := 0.78 * (1.0 - i * 0.14)
		_part(seg, _capsule(r, r * 2.0 + 1.0), sk, Vector3(-0.45, 0, 0), Vector3(0, 0, PI / 2))
		if not has("shell"):
			_spike_piece(seg, _v["spike_shape"], Vector3(-0.4, r * 0.85, 0), 0.3, (0.25 + r * 0.45) * float(_v["spike_size"]), 0.0)
		_tail.append(seg)
		parent = seg
		off = Vector3(-0.9, -0.08, 0)
	if has("tail_club"):
		var end := _tail[-1]
		_part(end, _sphere(0.75), _m["armor"], Vector3(-1.0, 0, 0))
		for i in 6:
			var a := i * TAU / 6.0
			var d := Vector3(0, cos(a), sin(a))
			_claw_at(end, Vector3(-1.0, 0, 0) + d * 0.65, d, Vector3.LEFT, 0.6, _m["bone"])

	if has("shell"):
		_shell()
	if has("moss"):
		_moss()


func _shell() -> void:
	var a: Material = _m["armor"]
	_part(_body, _sphere(1.0), a, Vector3(-0.1, 0.75, 0), Vector3.ZERO, Vector3(2.9, 1.5, 1.75))
	# Raised scutes in rings over the dome.
	for ring in 3:
		var n := 6 - ring * 2
		for i in n:
			var t := (float(i) + 0.5) / n
			var x := lerpf(-2.0, 1.8, t) * (1.0 - ring * 0.3)
			var y := 1.25 + ring * 0.48 - absf(t - 0.5) * 0.5
			var z := (0.0 if ring == 2 else (0.95 - ring * 0.45))
			for side in ([1.0] if z == 0.0 else [1.0, -1.0]):
				_part(_body, _sphere(0.5), a, Vector3(x, y, z * side), Vector3(z * side * 0.5, 0, 0), Vector3(1.0, 0.35, 0.85))
				_part(_body, _sphere(0.12), _m["glow"], Vector3(x, y + 0.16, z * side))
	# Rim of the shell.
	for i in 12:
		var t := float(i) / 11.0
		for side in [-1.0, 1.0]:
			_part(_body, _sphere(0.32), a, Vector3(lerpf(-2.7, 2.4, t), -0.05, 1.55 * side), Vector3.ZERO, Vector3(1.4, 0.6, 1.0))


func _moss() -> void:
	var moss := _skin(_m["glow"].get_shader_parameter("base_color").lerp(Color(0.25, 0.45, 0.12), 0.6),
		Color(0.08, 0.15, 0.05), 0.95, 0.0, 1.8, 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for i in 26:
		var x := r.randf_range(-2.4, 2.2)
		var z := r.randf_range(-1.1, 1.1)
		var y := 1.6 + 0.9 * (1.0 - absf(x) / 2.6) - absf(z) * 0.35
		_part(_body, _sphere(r.randf_range(0.25, 0.5)), moss, Vector3(x, y, z), Vector3.ZERO, Vector3(1.3, 0.6, 1.2))
	for i in 7:
		var x := r.randf_range(-1.8, 1.6)
		var z := r.randf_range(-0.7, 0.7)
		_claw_at(_body, Vector3(x, 2.1 - absf(x) * 0.25, z), Vector3(r.randf_range(-0.3, 0.3), 1, z * 0.4), Vector3.RIGHT,
			r.randf_range(0.5, 0.9), _m["spike"])


# --- insect / mech -------------------------------------------------------

func _build_insect(horns: bool) -> void:
	var mech := plan == "mech"
	var sk: Material = _m["skin"]
	var bl: Material = _m["belly"]
	var spider := has("spider")
	var mantis := has("blades")
	var scorpion := has("stinger")
	var pairs := 4 if spider else (2 if mantis or mech else 3)
	var leg_len := 1.35 if spider else (1.25 if mech else 1.0)
	_body_y = 1.55 * leg_len
	_body = _pivot("hips", self, Vector3(0, _body_y, 0))
	parts["torso"] = _body

	# Thorax.
	if mech:
		_part(_body, _box(Vector3(3.2, 1.4, 2.4)), sk, Vector3(0, 0.2, 0))
		_part(_body, _box(Vector3(2.4, 0.6, 1.9)), _m["steel"], Vector3(-0.2, 1.15, 0))
		_part(_body, _box(Vector3(1.0, 0.9, 2.0)), _m["armor"], Vector3(1.45, 0.05, 0), Vector3(0, 0, 0.5))
		_part(_body, _box(Vector3(3.4, 0.3, 2.6)), bl, Vector3(0, -0.55, 0))
		for side in [-1.0, 1.0]:
			_part(_body, _box(Vector3(2.6, 0.8, 0.14)), _m["armor"], Vector3(0, 0.3, 1.25 * side))
			for k in 3:
				_part(_body, _box(Vector3(0.35, 0.12, 0.06)), _m["glow"], Vector3(0.9 - k * 0.5, 0.45, 1.33 * side))
		for k in 4:
			_part(_body, _cylinder(0.12, 0.6), _m["steel"], Vector3(-1.0 + k * 0.3, 1.7, 0.6))
	else:
		_part(_body, _sphere(0.9), sk, Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.35, 0.75, 0.95))
		_part(_body, _sphere(0.8), _m["armor"], Vector3(-0.05, 0.3, 0), Vector3.ZERO, Vector3(1.4, 0.5, 0.95))
		if horns or has("spines"):
			for i in 4:
				_claw_at(_body, Vector3(0.5 - i * 0.4, 0.55, 0), Vector3(-0.3, 1, 0), Vector3.LEFT, 0.6 + (i % 2) * 0.25, _m["spike"])

	# Head.
	var head_pos := Vector3(1.4, 0.1, 0)
	if mantis:
		# Long upright prothorax carrying the head high.
		_seg(_body, Vector3(0.7, 0.2, 0), Vector3(1.3, 1.5, 0), 0.32, sk)
		head_pos = Vector3(1.45, 1.75, 0)
	var head := _pivot("head", _body, head_pos)
	if mech:
		# Turret: armoured dome, visor slit and a plasma barrel.
		_part(head, _box(Vector3(1.6, 1.0, 1.4)), sk, Vector3(0.1, 0.45, 0))
		_part(head, _box(Vector3(0.15, 0.22, 1.1)), _eye_mat, Vector3(0.92, 0.6, 0))
		_part(head, _box(Vector3(1.2, 0.25, 1.5)), _m["steel"], Vector3(0.1, 1.0, 0))
		for side in [-1.0, 1.0]:
			_seg(head, Vector3(0.8, 0.15, 0.35 * side), Vector3(2.6, 0.2, 0.35 * side), 0.2, _m["steel"])
			_part(head, _cylinder(0.24, 0.4), _m["armor"], Vector3(1.6, 0.17, 0.35 * side), Vector3(0, 0, PI / 2))
			_part(head, _sphere(0.22), _m["glow"], Vector3(2.65, 0.2, 0.35 * side))
		for side in [-1.0, 1.0]:
			_seg(head, Vector3(-0.2, 0.6, 0.35 * side), Vector3(-0.6, 1.6, 0.5 * side), 0.04, _m["steel"])
			_part(head, _sphere(0.12), _m["glow"], Vector3(-0.62, 1.65, 0.5 * side))
	else:
		var hs := 0.42 if has("tiny_head") else 0.6
		_part(head, _sphere(hs), sk, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
		# Compound eyes: a big glowing pair, and four more for spiders.
		for side in [-1.0, 1.0]:
			_part(head, _sphere(hs * 0.45), _eye_mat, Vector3(hs * 0.45, hs * 0.45, hs * 0.6 * side), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
			if spider:
				for k in 2:
					_part(head, _sphere(hs * 0.18), _eye_mat, Vector3(hs * (0.75 + k * 0.15), hs * (0.65 - k * 0.3), hs * (0.3 - k * 0.05) * side))
		if mantis:
			for side in [-1.0, 1.0]:
				_seg(head, Vector3(0.1, 0.45, 0.2 * side), Vector3(0.9, 1.4, 0.6 * side), 0.03, sk)
		# Mandibles open sideways.
		for side in [-1.0, 1.0]:
			var mnd := _pivot("jaw" if side > 0 else "jaw_l", head, Vector3(hs * 0.75, -hs * 0.45, hs * 0.35 * side))
			_claw_at(mnd, Vector3.ZERO, Vector3.RIGHT, Vector3(0, 0, -side), 0.6 if spider else 0.8, _m["bone"])
			_mands.append(mnd)

	# Abdomen.
	var abd_scale := 1.0
	if has("bloated"):
		abd_scale = 1.65
	if has("bomb_glow"):
		abd_scale = 1.45
	_abdomen = _pivot("tail0", _body, Vector3(-1.0, 0.15, 0))
	if mech:
		_part(_abdomen, _box(Vector3(1.4, 0.9, 1.6)), sk, Vector3(-0.6, 0.1, 0))
		for i in 3:
			_part(_abdomen, _cylinder(0.18, 0.5), _m["steel"], Vector3(-1.0, 0.75, (i - 1) * 0.45))
			_part(_abdomen, _sphere(0.12), _m["glow"], Vector3(-1.0, 1.02, (i - 1) * 0.45))
	else:
		var n := 3 if not scorpion else 2
		for i in n:
			var r := (0.95 - i * 0.15) * abd_scale
			var x := -0.55 - i * 0.85 * abd_scale
			_part(_abdomen, _sphere(r), sk if i % 2 == 0 else _m["armor"], Vector3(x, 0.15 + i * 0.05, 0), Vector3.ZERO, Vector3(1.0, 0.85, 0.95))
			_part(_abdomen, _box(Vector3(0.06, r * 1.1, r * 1.5)), _m["glow"] if has("bomb_glow") else bl,
				Vector3(x - r * 0.75, 0.15, 0))
		if has("bomb_glow"):
			_part(_abdomen, _sphere(1.0), _m["glow"], Vector3(-1.2, 0.35, 0), Vector3.ZERO, Vector3(1.25, 1.05, 1.1))
		if has("bloated") or has("sacs"):
			var r := RandomNumberGenerator.new()
			r.seed = 11
			for i in 9:
				var a := r.randf_range(0.0, TAU)
				var x := r.randf_range(-2.4, -0.7) * abd_scale * 0.75
				_part(_abdomen, _sphere(r.randf_range(0.18, 0.32)), _m["glow"],
					Vector3(x, 0.3 + absf(sin(a)) * 0.9 * abd_scale * 0.6, cos(a) * 0.95 * abd_scale * 0.6))

	if scorpion:
		# Segmented tail arcing up and over the back, ending in a glowing sting.
		var tail := _pivot("tail1", _abdomen, Vector3(-1.95, 0.25, 0))
		_tail.append(tail)
		var prev := Vector3.ZERO
		for i in 7:
			var th := PI * 0.95 - i * 0.36
			var p := Vector3(cos(th) * 1.3 + 1.3, sin(th) * 1.6 + 0.15 * i, 0)
			_seg(tail, prev, p, 0.34 - i * 0.025, sk if i % 2 == 0 else _m["armor"])
			prev = p
		_stinger = _pivot("stinger", tail, prev)
		_part(_stinger, _sphere(0.42), _m["glow"], Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 0.85))
		_claw_at(_stinger, Vector3(0.25, -0.1, 0), Vector3(0.6, -1, 0), Vector3(1, 0.3, 0), 1.1, _m["bone"])

	# Walking legs, alternating tripod gait.
	var span := 1.45 if pairs > 1 else 1.0
	for i in pairs:
		var t := 0.0 if pairs == 1 else float(i) / (pairs - 1)
		var x := lerpf(0.75, -0.75, t)
		var fwd := lerpf(1.0, -1.0, t)
		for side in [-1.0, 1.0]:
			var leg := _pivot("leg_%d_%s" % [i, "r" if side > 0 else "l"], _body, Vector3(x, -0.15, 0.6 * side))
			var knee := Vector3(fwd * 0.45 * leg_len, (1.15 if spider or mech else 0.75) * leg_len, 1.25 * leg_len * side)
			var foot := Vector3(fwd * 1.15 * leg_len, -_body_y + 0.15 + 0.05, 2.1 * span * leg_len * side * 0.8)
			if mech:
				_part(leg, _sphere(0.38), _m["steel"], Vector3.ZERO)
				_seg(leg, Vector3.ZERO, knee, 0.26, sk)
				_part(leg, _sphere(0.3), _m["steel"], knee)
				_seg(leg, knee, foot + Vector3(0, 0.3, 0), 0.22, _m["armor"])
				_part(leg, _cylinder(0.38, 0.3), _m["steel"], foot + Vector3(0, 0.1, 0))
			else:
				_seg(leg, Vector3.ZERO, knee, 0.17 * leg_len, sk)
				_part(leg, _sphere(0.2 * leg_len), _m["armor"], knee)
				_seg(leg, knee, foot.lerp(knee, 0.25), 0.13 * leg_len, sk)
				_claw_at(leg, foot.lerp(knee, 0.25), foot - foot.lerp(knee, 0.25), Vector3(fwd, 0, 0), (foot - knee).length() * 0.28, _m["bone"])
			var ph := PI if (i + (0 if side > 0 else 1)) % 2 == 1 else 0.0
			_legs.append({"n": leg, "ph": ph, "swing": 0.35, "lift": 0.22 * side, "rest": leg.rotation, "front": i == 0, "side": side})

	if mantis:
		# Raptorial forelegs folded under the head, with glowing scythe blades.
		for side in [1.0, -1.0]:
			var nm := "arm_r" if side > 0 else "arm_l"
			var arm := _pivot(nm, _body, Vector3(1.25, 1.0, 0.4 * side))
			_seg(arm, Vector3.ZERO, Vector3(0.5, 0.9, 0.15 * side), 0.2, sk)
			var fore := _pivot(nm + "_fore", arm, Vector3(0.5, 0.9, 0.15 * side))
			_seg(fore, Vector3.ZERO, Vector3(0.75, -1.1, 0), 0.16, sk)
			_part(fore, _box(Vector3(0.1, 2.0, 0.28)), _m["glow"], Vector3(0.55, -1.0, 0), Vector3(0, 0, 0.55))
			for k in 4:
				_claw_at(fore, Vector3(0.18 + k * 0.15, -0.3 - k * 0.22, 0), Vector3(-1, -0.3, 0), Vector3.DOWN, 0.22, _m["bone"])
			fore.rotation.z = 0.2
			_arms.append({"n": arm, "fore": fore, "side": side, "rest": 0.0, "fore_rest": 0.2})
	elif scorpion:
		# Big pincers held forward.
		for side in [1.0, -1.0]:
			var nm := "arm_r" if side > 0 else "arm_l"
			var arm := _pivot(nm, _body, Vector3(1.1, -0.05, 0.6 * side))
			_seg(arm, Vector3.ZERO, Vector3(0.8, 0.15, 0.75 * side), 0.2, sk)
			var fore := _pivot(nm + "_fore", arm, Vector3(0.8, 0.15, 0.75 * side))
			_seg(fore, Vector3.ZERO, Vector3(0.7, 0.1, -0.15 * side), 0.2, sk)
			_part(fore, _sphere(0.45), _m["armor"], Vector3(0.95, 0.1, -0.15 * side), Vector3.ZERO, Vector3(1.6, 0.75, 0.9))
			_claw_at(fore, Vector3(1.5, 0.15, -0.05 * side), Vector3.RIGHT, Vector3(0, 0, -side), 0.95, _m["armor"])
			_claw_at(fore, Vector3(1.4, -0.05, -0.3 * side), Vector3.RIGHT, Vector3(0, 0, side), 0.75, _m["bone"])
			_arms.append({"n": arm, "fore": fore, "side": side, "rest": 0.0, "fore_rest": 0.0})


# --- serpent -------------------------------------------------------------

func _build_serpent(horns: bool) -> void:
	var sk: Material = _m["skin"]
	var bl: Material = _m["belly"]
	var worm := has("worm")
	_body_y = 0.0
	_body = _pivot("hips", self, Vector3.ZERO)
	# Coiled trailing body lying on the ground.
	var parent: Node3D = _body
	var off := Vector3(-0.35, 0.0, 0)
	for i in 9:
		var seg := _pivot("tail%d" % i, parent, off)
		var r := 0.85 * (1.0 - i * 0.085)
		_part(seg, _sphere(r), sk, Vector3(-0.45, r, 0), Vector3.ZERO, Vector3(1.45, 1.0, 1.0))
		_part(seg, _sphere(r * 0.85), bl, Vector3(-0.45, r * 0.35, 0), Vector3.ZERO, Vector3(1.5, 0.45, 1.05))
		if worm and i % 2 == 0:
			_part(seg, _box(Vector3(0.12, r * 1.6, r * 2.05)), _m["armor"], Vector3(-0.1, r, 0))
		if has("fins"):
			_part(seg, _plate(), _m["glow"], Vector3(-0.4, r * 1.85, 0), Vector3(0, 0, 0.3), Vector3(0.9, r * 1.1, 0.15))
		_tail.append(seg)
		parent = seg
		off = Vector3(-0.95, 0.0, 0)

	# Raised neck rising from the front coil, curving forward at the top.
	var bend := [Vector3(0.35, 0.9, 0), Vector3(0.2, 0.95, 0), Vector3(0.15, 0.95, 0), Vector3(0.45, 0.8, 0), Vector3(0.75, 0.35, 0)]
	var np: Node3D = _pivot("torso", _body, Vector3(0.3, 0.7, 0))
	for i in bend.size():
		var r := 0.82 - i * 0.05
		var nk := _pivot("neck%d" % i, np, Vector3.ZERO if i == 0 else bend[i - 1])
		_seg(nk, Vector3.ZERO, bend[i], r, sk)
		var front: Vector3 = bend[i].normalized().rotated(Vector3.BACK, -PI / 2) * r * 0.55
		_part(nk, _sphere(r * 0.75), bl, bend[i] * 0.5 + front, Vector3.ZERO, Vector3(0.6, 0.9, 0.95))
		if worm:
			_part(nk, _cylinder(r * 1.08, 0.16), _m["armor"], bend[i] * 0.85,
				Basis(Quaternion(Vector3.UP, bend[i].normalized())).get_euler())
		_neck.append(nk)
		np = nk
	var head := _pivot("head", np, bend[-1])
	if worm:
		# Round lamprey mouth ringed with teeth; no eyes.
		_part(head, _sphere(0.85), sk, Vector3(0.2, 0, 0), Vector3.ZERO, Vector3(1.1, 1.0, 1.0))
		_part(head, _cylinder(0.75, 0.3), _m["mouth"], Vector3(0.95, 0, 0), Vector3(0, 0, PI / 2))
		for i in 10:
			var a := i * TAU / 10.0
			var d := Vector3(0, cos(a), sin(a))
			_claw_at(head, Vector3(1.0, 0, 0) + d * 0.62, Vector3(0.6, 0, 0) - d * 0.5, -d, 0.45, _m["bone"])
		for i in 3:
			_part(head, _cylinder(0.95 - i * 0.02, 0.12), _m["armor"], Vector3(0.45 - i * 0.4, 0, 0), Vector3(0, 0, PI / 2))
		var j := _pivot("jaw", head, Vector3(0.9, 0, 0))
		_part(j, _sphere(0.3), _m["glow"], Vector3.ZERO, Vector3.ZERO, Vector3(0.4, 1.0, 1.0))
	else:
		_part(head, _sphere(0.7), sk, Vector3(0.25, 0.05, 0), Vector3.ZERO, Vector3(1.45, 0.62, 1.15))
		_part(head, _sphere(0.5), sk, Vector3(0.95, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.5, 0.85))
		for side in [-1.0, 1.0]:
			_part(head, _sphere(0.14), _eye_mat, Vector3(0.65, 0.3, 0.42 * side), Vector3.ZERO, Vector3(1.4, 0.8, 0.7))
			_part(head, _capsule(0.1, 0.6), _m["armor"], Vector3(0.55, 0.4, 0.38 * side), Vector3(0.2 * side, 0, -PI / 2 + 0.2))
			if horns:
				_claw_at(head, Vector3(-0.15, 0.3, 0.45 * side), Vector3(-1, 0.6, 0.4 * side), Vector3.UP, 1.0, _m["bone"])
		var j := _pivot("jaw", head, Vector3(0.3, -0.2, 0))
		_part(j, _sphere(0.5), bl, Vector3(0.5, -0.1, 0), Vector3.ZERO, Vector3(1.6, 0.35, 1.0))
		_part(j, _box(Vector3(0.9, 0.04, 0.6)), _m["mouth"], Vector3(0.55, 0.05, 0))
		for side in [-1.0, 1.0]:
			_claw_at(head, Vector3(1.05, -0.2, 0.22 * side), Vector3.DOWN, Vector3(-1, 0, 0), 0.55, _m["bone"])
	if has("hood"):
		var nk: Node3D = _neck[-2]
		_part(nk, _sphere(1.0), _m["armor"], Vector3(0.05, 0.45, 0), Vector3(0, 0, -0.35), Vector3(0.22, 1.35, 1.75))
		for side in [-1.0, 1.0]:
			_part(nk, _sphere(0.24), _m["glow"], Vector3(0.12, 0.65, 0.95 * side))
			_part(nk, _sphere(0.13), _m["socket"], Vector3(0.16, 0.65, 1.0 * side))
	if has("antenna"):
		for side in [-1.0, 1.0]:
			_seg(head, Vector3(0.9, 0.0, 0.35 * side), Vector3(1.9, 0.6, 1.1 * side), 0.04, _m["glow"])
			_part(head, _sphere(0.14), _m["glow"], Vector3(1.95, 0.62, 1.12 * side))
	if has("crystals"):
		for i in 5:
			var seg: Node3D = _tail[i * 2 % _tail.size()]
			_claw_at(seg, Vector3(-0.4, 1.4 - i * 0.08, 0.2 * (1 - i % 3)), Vector3(-0.3, 1, 0.3 * (1 - i % 3)), Vector3.LEFT,
				0.9 - i * 0.1, _m["glow"])
	if has("crest"):
		for i in _neck.size():
			_spike_piece(_neck[i], 2, bend[i] * 0.5 + Vector3(-0.5, 0.0, 0), 0.9, 0.7, 0.0)
	if has("whiskers"):
		# Dragon barbels trailing from the snout, and a flowing mane.
		for side in [-1.0, 1.0]:
			var prev := Vector3(1.15, -0.05, 0.3 * side)
			for k in range(1, 8):
				var nxt := Vector3(1.15 - k * 0.38, -0.05 - 0.22 * sin(k * 0.55), (0.3 + k * 0.3) * side)
				_seg(head, prev, nxt, 0.055 - k * 0.005, _m["glow"])
				prev = nxt
		for i in _neck.size():
			for j in 3:
				var o: Vector3 = bend[i] * (0.2 + j * 0.3)
				_claw_at(_neck[i], o + Vector3(-0.55, 0.1, (j - 1) * 0.3), Vector3(-1, 0.35, (j - 1) * 0.5), Vector3.DOWN,
					1.1 - i * 0.06, _m["spike"])
		_claw_at(head, Vector3(-0.3, 0.3, 0), Vector3(-1, 0.4, 0), Vector3.DOWN, 1.3, _m["spike"])


# --- ape / golem ---------------------------------------------------------

func _build_ape(horns: bool) -> void:
	var rock := plan == "golem"
	var sk: Material = _m["skin"]
	var bl: Material = _m["belly"]
	_body_y = 2.2
	_body_rest = -0.55 if not rock else -0.3
	var hips := _pivot("hips", self, Vector3(0, _body_y, 0))
	_blob(hips, 0.95, sk, Vector3(0, 0, 0), Vector3(1.1, 0.9, 1.3), rock)
	_body = _pivot("torso", hips, Vector3(0.1, 0.3, 0))
	_body.rotation.z = _body_rest
	_blob(_body, 1.45, sk, Vector3(0.3, 1.45, 0), Vector3(1.15, 1.1, 1.25), rock)
	_blob(_body, 1.05, bl, Vector3(0.65, 0.55, 0), Vector3(0.9, 1.0, 1.05), rock)
	for side in [-1.0, 1.0]:
		_blob(_body, 0.85, sk, Vector3(0.2, 2.05, 1.2 * side), Vector3(1.0, 0.9, 1.0), rock)
		_blob(_body, 0.7, bl, Vector3(1.1, 1.5, 0.55 * side), Vector3(0.65, 0.85, 0.9), rock)
	if rock:
		# Lava cracks between the chunks.
		var r := RandomNumberGenerator.new()
		r.seed = 21
		for i in 34:
			var p := Vector3(r.randf_range(-0.6, 1.4), r.randf_range(0.0, 2.7), r.randf_range(-1.5, 1.5))
			_part(_body, _box(Vector3(0.16, r.randf_range(0.6, 1.4), 0.16)), _m["glow"], p,
				Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)))
		_part(_body, _sphere(0.45), _m["glow"], Vector3(1.35, 1.3, 0), Vector3.ZERO, Vector3(0.5, 1.0, 1.0))
	elif not has("fur"):
		# Bony plates down the back.
		for i in 4:
			_part(_body, _plate(), _m["spike"], Vector3(-0.85 + i * 0.25, 1.1 + i * 0.45, 0), Vector3(0, 0, 0.9),
				Vector3(1.0, 0.9 + i * 0.1, 0.35) * float(_v["spike_size"]))

	var head := _pivot("head", _body, Vector3(1.35, 2.1, 0))
	head.rotation.z = -_body_rest * 0.8
	_blob(head, 0.62, sk, Vector3(0, 0.05, 0), Vector3(1.05, 0.95, 1.05), rock)
	_part(head, _box(Vector3(0.55, 0.22, 1.05)), _m["armor"], Vector3(0.3, 0.38, 0), Vector3(0, 0, -0.25))
	_blob(head, 0.42, bl, Vector3(0.5, -0.22, 0), Vector3(1.0, 0.75, 1.1), rock)
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.13), _m["socket"], Vector3(0.52, 0.22, 0.27 * side), Vector3.ZERO, Vector3(0.8, 0.8, 1.0))
		_part(head, _sphere(0.08), _eye_mat, Vector3(0.6, 0.22, 0.27 * side))
		if horns:
			var hs: float = _v["horn_size"]
			_claw_at(head, Vector3(-0.05, 0.45, 0.5 * side), Vector3(0, 0.6, side), Vector3(0.6, 0.8, 0), 1.5 * hs, _m["bone"])
	var jaw := _pivot("jaw", head, Vector3(0.3, -0.38, 0))
	_blob(jaw, 0.35, sk, Vector3(0.25, -0.05, 0), Vector3(1.0, 0.55, 1.2), rock)
	_part(jaw, _box(Vector3(0.5, 0.04, 0.55)), _m["mouth"], Vector3(0.3, 0.12, 0))
	for side in [-1.0, 1.0]:
		_claw_at(jaw, Vector3(0.45, 0.1, 0.3 * side), Vector3(0.2, 1, 0), Vector3.LEFT, 0.55, _m["bone"])

	# Huge arms; knuckles rest on the ground.
	for side in [1.0, -1.0]:
		var nm := "arm_r" if side > 0 else "arm_l"
		var arm := _pivot(nm, _body, Vector3(0.45, 2.0, 1.55 * side))
		_blob(arm, 0.72, sk, Vector3(0, 0, 0), Vector3.ONE, rock)
		_seg(arm, Vector3.ZERO, Vector3(0.2, -1.6, 0.15 * side), 0.62, sk)
		var fore := _pivot(nm + "_fore", arm, Vector3(0.2, -1.6, 0.15 * side))
		_seg(fore, Vector3.ZERO, Vector3(0.2, -1.4, 0), 0.56, bl if has("fur") else sk)
		_blob(fore, 0.66, _m["armor"] if rock else sk, Vector3(0.3, -1.8, 0), Vector3(1.1, 0.9, 1.0), rock)
		for c in 3:
			_claw_at(fore, Vector3(0.85, -1.85, (c - 1) * 0.3), Vector3(1, -0.4, 0), Vector3.DOWN, 0.55, _m["bone"])
		arm.rotation.z = 0.85
		_arms.append({"n": arm, "fore": fore, "side": side, "rest": 0.85, "fore_rest": 0.0})

	for side in [1.0, -1.0]:
		var leg := _pivot("leg_r" if side > 0 else "leg_l", hips, Vector3(0, -0.1, 0.85 * side))
		_blob(leg, 0.75, sk, Vector3(0.05, -0.3, 0), Vector3(1.0, 1.2, 1.0), rock)
		_seg(leg, Vector3(0, -0.3, 0), Vector3(0.25, -1.25, 0), 0.55, sk)
		_seg(leg, Vector3(0.25, -1.25, 0), Vector3(0.0, -1.75, 0), 0.45, sk)
		_blob(leg, 0.5, sk, Vector3(0.3, -1.88, 0), Vector3(1.45, 0.45, 1.05), rock)
		for c in 3:
			_claw_at(leg, Vector3(0.85, -1.92, (c - 1) * 0.28), Vector3.RIGHT, Vector3.DOWN, 0.5, _m["bone"])
		_legs.append({"n": leg, "ph": 0.0 if side > 0 else PI, "swing": 0.5, "lift": 0.0, "rest": leg.rotation})

	if has("fur"):
		# Shaggy mane over the shoulders and back.
		var fur := _skin(Color(_m["belly"].get_shader_parameter("albedo")).lightened(0.15), Color(0.6, 0.65, 0.72), 0.95, 0.0, 2.0, 0.0)
		var r := RandomNumberGenerator.new()
		r.seed = 3
		for i in 46:
			var a := r.randf_range(-1.4, 1.4)
			var up := r.randf_range(0.6, 2.7)
			var p := Vector3(-0.7 + up * 0.3 + r.randf_range(-0.2, 0.2), up, sin(a) * 1.45)
			_claw_at(_body, p, Vector3(-0.8, 0.2, sin(a) * 0.6), Vector3.DOWN, r.randf_range(0.5, 0.9), fur)
		for side in [1.0, -1.0]:
			var arm: Node3D = parts["arm_r" if side > 0 else "arm_l"]
			for i in 6:
				_claw_at(arm, Vector3(-0.35, -0.3 - i * 0.25, 0.3 * side), Vector3(-0.6, -0.6, 0.4 * side), Vector3.DOWN, 0.6, fur)
	if has("seaweed"):
		_seaweed(head)
	if has("crystals"):
		for i in 6:
			_claw_at(_body, Vector3(-0.7 + i * 0.2, 1.2 + i * 0.32, (i % 3 - 1) * 0.55), Vector3(-0.6, 1, (i % 3 - 1) * 0.5),
				Vector3.LEFT, 0.9 + (i % 2) * 0.5, _m["glow"])
	if has("wings"):
		var wing_mat := _skin(Color(_m["skin"].get_shader_parameter("albedo")).darkened(0.25), Color(0.1, 0.1, 0.12), 0.8, 0.0, 0.6, 1.0)
		for side in [-1.0, 1.0]:
			var w := _pivot("wing_%s" % ("r" if side > 0 else "l"), _body, Vector3(-0.4, 2.2, 0.9 * side))
			var wrist := Vector3(-0.6, 1.9, 1.3 * side)
			_seg(w, Vector3.ZERO, wrist, 0.13, sk)
			_claw_at(w, wrist, Vector3(0.3, 1, 0), Vector3.RIGHT, 0.5, _m["bone"])
			# Three finger bones fanning back, with membrane panels between.
			var tips := [Vector3(-2.6, 2.0, 2.4 * side), Vector3(-3.0, 0.6, 2.0 * side), Vector3(-2.2, -0.6, 1.4 * side)]
			var prev := Vector3(-0.3, 0.2, 0.6 * side)
			for tip in tips:
				_seg(w, wrist, tip, 0.06, sk)
				var a: Vector3 = (wrist + prev + tip) / 3.0
				var span: Vector3 = tip - prev
				var nrm: Vector3 = (tip - wrist).cross(prev - wrist).normalized()
				var bx: Vector3 = span.normalized()
				var by: Vector3 = nrm.cross(bx).normalized()
				var xf := Transform3D(Basis(bx, by, nrm) * Basis.from_scale(Vector3(span.length() * 0.6, (wrist - (prev + tip) * 0.5).length() * 1.0, 0.04)), a)
				_part_xf(w, _sphere(1.0), wing_mat, xf)
				prev = tip
			_neck.append(w)
	if has("armor_plates"):
		var st: Material = _m["steel"]
		_part(_body, _box(Vector3(1.2, 1.8, 2.2)), st, Vector3(0.8, 1.4, 0), Vector3(0, 0, -0.1))
		_part(head, _box(Vector3(0.9, 0.3, 1.0)), st, Vector3(0.15, 0.5, 0))
		for side in [1.0, -1.0]:
			_part(parts["arm_r" if side > 0 else "arm_l"], _box(Vector3(0.9, 1.0, 0.9)), st, Vector3(0.1, -0.5, 0))
			_part(parts["arm_r_fore" if side > 0 else "arm_l_fore"], _box(Vector3(0.95, 1.1, 0.95)), st, Vector3(0.2, -0.9, 0))
		_part(_body, _box(Vector3(0.35, 0.35, 0.6)), _m["glow"], Vector3(1.42, 1.4, 0))
	if has("crest"):
		for i in 3:
			_spike_piece(head, 0, Vector3(0.1 - i * 0.3, 0.55 - i * 0.05, 0), 0.4 + i * 0.2, 0.7 - i * 0.12, 0.0)


## Sea troll dressing: kelp hanging off the shoulders, back and arms, and
## barnacle clusters crusted over the hide.
func _seaweed(head: Node3D) -> void:
	var kelp := _skin(Color(0.3, 0.5, 0.16), Color(0.1, 0.2, 0.06), 0.55, 0.0, 0.8, 0.6)
	var shell := _skin(Color(0.82, 0.8, 0.72), Color(0.45, 0.42, 0.36), 0.8, 0.0, 1.2, 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	# Points on the surface of the chest blob (see _build_ape).
	var centre := Vector3(0.3, 1.45, 0)
	var radii := Vector3(1.15, 1.1, 1.25) * 1.45
	var anchors: Array = []
	for i in 18:
		var d := Vector3(r.randf_range(-1.0, 0.5), r.randf_range(0.2, 1.0), r.randf_range(-1.0, 1.0)).normalized()
		anchors.append([_body, centre + d * radii * 0.97])
	for side in [1.0, -1.0]:
		for i in 3:
			anchors.append([parts["arm_r" if side > 0 else "arm_l"], Vector3(r.randf_range(-0.4, 0.2), -0.2 - i * 0.45, 0.55 * side)])
	for a in anchors:
		var prev: Vector3 = a[1]
		var drift := Vector3(r.randf_range(-0.35, 0.05), -1.0, r.randf_range(-0.15, 0.15)).normalized()
		var n := r.randi_range(4, 6)
		for k in n:
			var nxt := prev + (drift + Vector3(sin(k * 1.3 + prev.x * 3.0) * 0.3, 0, 0)) * 0.4
			_seg(a[0], prev, nxt, 0.16 - k * 0.018, kelp, Vector3(1.6, 1.0, 0.3))
			prev = nxt
	for i in 26:
		var d := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.3, 1.0), r.randf_range(-1.0, 1.0)).normalized()
		var p := centre + d * radii * 0.98
		_part(_body, _sphere(0.16), shell, p, Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
		_claw_at(_body, p, d, Vector3.UP, r.randf_range(0.3, 0.45), shell)
	for i in 5:
		var d := Vector3(r.randf_range(-1.0, 0.3), r.randf_range(0.3, 1.0), r.randf_range(-1.0, 1.0)).normalized()
		_claw_at(head, d * 0.62, d, Vector3.UP, 0.3, shell)


func _blob(parent: Node3D, r: float, mat: Material, pos: Vector3, scl: Vector3, rock: bool) -> void:
	if not rock:
		_part(parent, _sphere(r), mat, pos, Vector3.ZERO, scl)
		return
	# A rough cluster of tilted boulders instead of one smooth lump.
	var h := hash(pos)
	for i in 5:
		var a := float((h >> (i * 5)) & 31) / 31.0 * TAU
		var o := Vector3(cos(a), sin(a * 1.7), sin(a)) * r * (0.1 if i == 0 else 0.42)
		_part(parent, _box(Vector3.ONE * r * (1.25 if i == 0 else 0.8)), mat, pos + o * scl, Vector3(a, a * 0.6, a * 0.3), scl)


# --- animation -----------------------------------------------------------

func _process(delta: float) -> void:
	if parts.is_empty():
		return
	var gait := 8.5
	match plan:
		"insect":
			gait = 13.0
		"quad":
			gait = 7.0
		"serpent":
			gait = 5.0
	_pose(delta, gait)
	var ar: float = _cur["arm_r"] - 0.25
	var al: float = _cur["arm_l"] - 0.25
	var rear := clampf(maxf(ar, al) / 2.6, 0.0, 1.0)
	var ln: float = _cur["lean"]
	var jw: float = _cur["jaw"]
	var s := sin(_phase)
	var breathe := sin(_t * 2.0)
	var sq: float = _cur["squash"]
	var turn: float = _cur["turn"]

	match plan:
		"quad":
			var pitch := rear * 0.5 - ln * 0.4
			_body.rotation.z = pitch
			_body.position.y = _body_y + absf(cos(_phase)) * 0.15 * _walk + breathe * 0.04 + rear * 0.5 - sq * 0.3
			_body.rotation.x = s * 0.05 * _walk
			_body.rotation.y = s * 0.04 * _walk
			for l in _legs:
				var front: bool = String(l["n"].name).begins_with("leg_f")
				var rz: float = sin(_phase + l["ph"]) * l["swing"] * _walk
				if front:
					rz += rear * (0.9 + 0.3 * sin(_t * 9.0))
				rz -= pitch
				rz += sq * (0.25 if front else -0.25)
				l["n"].rotation.z = rz
			_neck[0].rotation.z = -rear * 0.2 + ln * 0.15 + sin(_t * 1.6) * 0.04 - absf(cos(_phase)) * 0.05 * _walk + sq * 0.2
			_neck[0].rotation.y = turn * 0.08
			parts["jaw"].rotation.z = -jw * 0.6
		"insect", "mech":
			_body.position.y = _body_y + absf(sin(_phase * 2.0)) * 0.06 * _walk + breathe * 0.03 - sq * 0.15
			_body.rotation.z = rear * 0.25 - ln * 0.25
			for l in _legs:
				var p: float = _phase + l["ph"]
				l["n"].rotation.y = sin(p) * l["swing"] * _walk
				l["n"].rotation.x = maxf(cos(p), 0.0) * l["lift"] * _walk
				l["n"].rotation.z = -_body.rotation.z
				if l.get("front", false) and _arms.is_empty():
					l["n"].rotation.z += (ar if l["side"] > 0 else al) * 0.35
			for a in _arms:
				var v := ar if a["side"] > 0 else al
				a["n"].rotation.z = a["rest"] + v * 0.35
				if has("blades"):
					# Blades raise high in the wind-up and slash down.
					a["fore"].rotation.z = a["fore_rest"] + v * 0.65
				else:
					a["fore"].rotation.z = a["fore_rest"] - v * 0.2
				if has("stinger"):
					a["fore"].rotation.y = -a["side"] * (0.2 + 0.25 * sin(_t * 5.0)) * (0.3 + v * 0.3)
			if _abdomen:
				_abdomen.rotation.z = sin(_t * 1.8) * 0.04 + rear * 0.15
				_abdomen.scale = Vector3.ONE * (1.0 + breathe * (0.05 if has("bloated") or has("bomb_glow") else 0.015))
			for t in _tail:
				t.rotation.z = -ln * 0.6 - rear * 0.25 + sin(_t * 2.4) * 0.05
				t.rotation.y = sin(_t * 1.5) * 0.08 - turn * 0.1
			for i in _mands.size():
				_mands[i].rotation.y = (1.0 if i == 0 else -1.0) * (jw * 0.6 + sin(_t * 7.0) * 0.06)
			if plan == "mech":
				parts["head"].rotation.y = sin(_t * 0.9) * 0.15
		"serpent":
			for i in _tail.size():
				var amp := 0.18 + 0.22 * _walk
				_tail[i].rotation.y = sin(_t * 3.0 * walk_speed + _phase - i * 0.8) * amp * (0.4 if i == 0 else 1.0) \
					- turn * 0.08 * float(i + 1) / _tail.size()
			var strike_k := ln * 0.55 - rear * 0.35
			for i in _neck.size():
				_neck[i].rotation.z = -strike_k * (0.35 if i < 3 else 0.2) + sin(_t * 1.7 - i * 0.6) * 0.04
				_neck[i].rotation.y = sin(_t * 1.3 - i * 0.5) * 0.05 + turn * 0.04
			parts["jaw"].rotation.z = -jw * 0.9
			if has("worm"):
				parts["jaw"].scale = Vector3.ONE * (1.0 + jw * 0.6)
		_:
			_body.rotation.z = _body_rest + rear * 0.35 - ln * 0.5 + breathe * 0.02
			_body.rotation.y = s * 0.07 * _walk
			parts["hips"].position.y = _body_y + absf(cos(_phase)) * 0.18 * _walk + breathe * 0.04 - sq * 0.3
			parts["hips"].rotation.x = s * 0.06 * _walk
			for l in _legs:
				l["n"].rotation.z = sin(_phase + l["ph"]) * l["swing"] * _walk
			for a in _arms:
				var v := ar if a["side"] > 0 else al
				var sw: float = -s * 0.45 * _walk * a["side"]
				var vv: float = _vel.get("arm_r" if a["side"] > 0 else "arm_l", 0.0)
				a["n"].rotation.z = a["rest"] + v * 1.0 + sw
				a["fore"].rotation.z = a["fore_rest"] - v * 0.25 + clampf(-vv * 0.03, -0.4, 0.5) + sin(_phase - 0.8) * 0.1 * _walk * a["side"]
			parts["head"].rotation.z = -_body.rotation.z * 0.8 + sin(_t * 1.7) * 0.05
			parts["jaw"].rotation.z = -jw * 0.7
			for i in _neck.size():
				# Wings flap.
				var side := 1.0 if i == 0 else -1.0
				_neck[i].rotation.x = side * (0.25 + sin(_t * 6.0) * 0.35 * (0.3 + rear))
	if plan == "quad":
		for i in _tail.size():
			_tail[i].rotation.y = sin(_t * 2.0 - i * 0.7) * 0.12 * (1.0 + _walk) - turn * 0.1 * float(i + 1) / _tail.size()
			_tail[i].rotation.z = -0.03 + sin(_t * 1.3 - i * 0.5) * 0.04

	if _flash > 0.0:
		_flash = maxf(_flash - delta * 7.0, 0.0)
		var c := Vector3(1, 0.95, 0.9) * _flash * 1.5
		for m in _body_mats:
			m.set_shader_parameter("flash_color", c)
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	var e := 0.3 + glow * (3.0 + pulse * (3.0 if glow >= 1.0 else 0.0))
	_spike_mat.set_shader_parameter("glow_energy", e)
	_seam_mat.set_shader_parameter("glow_energy", 0.8 + e * 0.8 + (pulse * 0.6 if plan == "golem" else 0.0))
	_eye_mat.emission_energy_multiplier = 3.0 + eye_glow * 8.0


# --- helpers -------------------------------------------------------------

## A capsule limb from a to b.
func _seg(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, scl: Vector3 = Vector3.ONE) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var basis := Basis(Quaternion(Vector3.UP, d / l)) * Basis.from_scale(scl)
	_part_xf(parent, _capsule(r, l + r * 2.0), mat, Transform3D(basis, (a + b) * 0.5))


## A curved claw/horn/tooth whose base sits at pos, pointing along `along`
## and curving toward `curve`, about `length` long.
func _claw_at(parent: Node3D, pos: Vector3, along: Vector3, curve: Vector3, length: float, mat: Material) -> void:
	var y := along.normalized()
	var x := (curve - y * curve.dot(y))
	if x.length() < 0.01:
		x = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	var basis := Basis(x, y, z) * Basis.from_scale(Vector3(length * 0.9, length, length * 0.9))
	_part_xf(parent, _claw(), mat, Transform3D(basis, pos))


func _part_xf(parent: Node3D, mesh: Mesh, mat: Material, xf: Transform3D) -> void:
	if not _pending.has(parent):
		_pending[parent] = {}
	var by_mat: Dictionary = _pending[parent]
	if not by_mat.has(mat):
		by_mat[mat] = []
	by_mat[mat].append([mesh, xf])


func _cylinder(r: float, h: float) -> Mesh:
	return _cached("cyl_%.3f_%.3f_%d" % [r, h, _segments(r)], func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = _segments(r)
		return c)
