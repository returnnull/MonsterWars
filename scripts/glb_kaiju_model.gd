class_name GlbKaijuModel
extends KaijuModel
## A hero kaiju loaded from a rigged .glb (the T-Rex variants in
## assets/heroes, built from Quaternius' CC0 T-Rex by tools/make_hero_variants.py:
## a smooth subdivided body with a baked skin texture). It takes the same pose
## targets as KaijuModel and maps them onto the model's own animations:
## Idle, Walk, Run, Attack and Jump. Lean tilts the whole body, glow drives
## the emissive spikes and eye_glow the eyes. Faces +X with its origin at the
## feet, like KaijuModel.
##
## The animations are mixed by an AnimationTree that this script poses by
## hand every frame: Walk and Run share one stride phase and blend by speed,
## and their playback rate follows the ground speed so the feet don't slide.
## On top of that a skeleton modifier adds secondary motion: the head leads
## and the tail trails turns, the tail swings with the stride and whips on
## jumps and landings, the upper body leans into speeding up and braking,
## hits make it flinch, and when idle it breathes and looks around.

## World units per glTF unit; the T-Rex is about 15 units tall in the file.
const MODEL_SCALE := 0.31
## Ground speed (world units/s at size 1) the Walk and Run animations cover
## at normal playback, from how fast a planted foot moves back. Walk blends
## into Run between RUN_FROM and RUN_TO.
const WALK_GROUND_SPEED := 4.5
const RUN_GROUND_SPEED := 10.5
const RUN_FROM := 5.0
const RUN_TO := 8.5
## The player's full speed; walk_amount 1 means this many units/s.
const FULL_SPEED := 9.5
const ATTACK_SPEED := 1.4
## Times in the Attack clip that `bite` maps onto: the head rears back with
## the mouth wide open, snaps shut thrust forward, and is back in its stance.
const BITE_OPEN := 0.22
const BITE_SNAP := 0.47
const BITE_SHUT := 0.58
const BITE_END := 0.85
## How fast (1/s) each layer fades in and out.
const FADE := {"move": [14.0, 8.0], "jump": [30.0, 10.0], "atk": [26.0, 9.0]}
## Springs for the secondary motion: frequency (rad/s) and damping ratio.
const SEC_SPRINGS := {"tail_y": [7.0, 0.45], "tail_z": [8.0, 0.4], "flinch": [16.0, 0.35], "accel": [9.0, 0.7]}
## Foot planting: a hind foot this close to the ground (world units at size
## 1) that isn't swinging forward is held where it touched down, and the
## leg bends to reach it, so the feet grip the ground instead of sliding.
## It lets go when the foot lifts, or once it would be pulled too far.
const FOOT_CONTACT := 0.14
const FOOT_MAX_PULL := 1.3
const LEGS := [["BackUpLeg.L", "BackLowLeg.L", "BackLowLeg.L_end"], ["BackUpLeg.R", "BackLowLeg.R", "BackLowLeg.R_end"]]
const TAIL_BONES := ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
const SPINE_BONES := ["Hips", "Torso", "Shoulders", "Neck", "Head"]
## The models are dense (30-70k triangles); this lets Godot's automatic LODs
## step down a little sooner. At the game camera's distance it looks the
## same and draws about 40% fewer triangles; close-ups keep full detail.
const LOD_BIAS := 0.5
## Where cosmetics sit (see Cosmetics): the bone they ride on, the anchor's
## position in model space (rest pose, size 1.0) and its tilt about Z in
## degrees. The neck frame leans with the neck, so its Y runs along it.
const COSMETIC_ANCHORS := {
	"head": ["Head", Vector3(3.2, 4.62, 0), 0.0],
	"face": ["Head", Vector3(3.69, 4.29, 0), 0.0],
	"neck": ["Neck", Vector3(2.4, 3.78, 0), -64.0],
	"back": ["Shoulders", Vector3(1.1, 3.75, 0), 0.0],
	"tail": ["Tail5", Vector3(-5.2, 2.95, 0), 0.0],
}
## Where a carried building piece is clamped between the jaws: same format
## as COSMETIC_ANCHORS, a spot just behind the front teeth.
const BITE_SPOT := ["Head", Vector3(3.45, 4.12, 0), 0.0]

var _inst: Node3D
var _lean: Node3D
var _anim: AnimationPlayer
var _mouth: Node3D
var _glow_mats: Array[StandardMaterial3D] = []
var _glow_base: Array[float] = []
var _skin_mats: Array[StandardMaterial3D] = []
var _eyes: Array[StandardMaterial3D] = []
var _tree: AnimationTree
var _len := {}
var _skel: Skeleton3D
var _body_bone := -1
var _body_rest := 0.0
## Landing: time into the Jump animation's touchdown part (< 0 when not landing).
var _land_t := -1.0
var _jump_t := 0.0
var _jumping := false
## Layer weights in the tree: move (idle -> gait), run (walk -> run),
## jump and atk (attack over everything).
var _wt := {"move": 0.0, "run": 0.0, "jump": 0.0, "atk": 0.0, "slot": 0.0}
var _speed := 0.0  # smoothed ground speed, world units/s at size 1
var _stride := 0.0  # gait phase, 0-1 per stride
var _idle_t := 0.0
## Two attack slots, so an attack that starts over crossfades from the old one.
var _atk_t := [0.0, 0.0]
var _atk_slot := 0
var _striking := false
## Secondary motion springs: value and velocity per channel; the tail ones
## are chains, one entry per tail bone.
var _sec := {}
var _sec_v := {}
var _bones := {}  # bone name -> index
var _skel_basis := Basis()  # skeleton space -> model space
var _sec_rots := {}  # bone name -> extra rotation, see _secondary()
var _legs: Array = []  # [thigh, shin, foot end] bone indices per hind leg
var _foot_lock: Array = [null, null]  # world spot a planted foot holds
var _foot_off: Array = [Vector3.ZERO, Vector3.ZERO]  # world pull toward it
var _foot_prev: Array = [Vector3.ZERO, Vector3.ZERO]  # model-space foot, last frame
var _dt := 0.0

## Parts of the Jump animation (seconds): crouch, push off, tucked in the
## air at the apex, legs reaching down, and the landing crouch and recovery.
const JUMP_CROUCH := 0.25
const JUMP_RISE := 0.375
const JUMP_APEX := 0.5
const JUMP_FALL := 0.625
const JUMP_LAND := 0.75
const JUMP_END := 1.2


## Builds a hero from h (a Content hero): its "model" .glb when it has one,
## otherwise the procedural KaijuModel. The model must already be wanted in
## the tree under parent.
static func for_hero(h: Dictionary, parent: Node) -> KaijuModel:
	var path: String = h.get("model", "")
	if path != "" and ResourceLoader.exists(path):
		var g := GlbKaijuModel.new()
		parent.add_child(g)
		g.build_glb(path, h["accent"])
		return g
	var m := KaijuModel.new()
	m.look = h.get("look", {})
	parent.add_child(m)
	m.build(h["skin"], h["belly"], h["accent"], h["eye"], h["horns"])
	return m


func build_glb(path: String, spike: Color) -> void:
	_spike_color = spike
	_lean = Node3D.new()
	add_child(_lean)
	_inst = (load(path) as PackedScene).instantiate()
	_lean.add_child(_inst)
	# The file's snout points along +Z; KaijuModel faces +X.
	_inst.rotation.y = PI / 2
	_inst.scale = Vector3.ONE * MODEL_SCALE
	_anim = _find(_inst, "AnimationPlayer") as AnimationPlayer
	var skel := _find(_inst, "Skeleton3D") as Skeleton3D
	_skel = skel
	if skel:
		_body_bone = skel.find_bone("Body")
		if _body_bone >= 0:
			_body_rest = _body_y(skel.get_bone_global_rest(_body_bone).origin)
		for b in TAIL_BONES + SPINE_BONES:
			_bones[b] = skel.find_bone(b)
		for leg in LEGS:
			var ids: Array = leg.map(func(b: String) -> int: return skel.find_bone(b))
			if not ids.has(-1):
				_legs.append(ids)
		var n: Node = skel
		while n != self and n is Node3D:
			_skel_basis = (n as Node3D).basis * _skel_basis
			n = n.get_parent()
		_skel_basis = _skel_basis.orthonormalized()
		var mod := Secondary.new()
		mod.model = self
		skel.add_child(mod)
	if _anim:
		_build_tree()
	_collect_materials(_inst)
	# Pivots the player uses: the jaws carry weapons, the snout fires beams.
	var hand := _attach(skel, "FrontFoot.R")
	_mouth = _attach(skel, "Head_end")
	parts = {"arm_r_fore": hand, "hips": _lean}
	var bite := _anchor(BITE_SPOT)
	if bite:
		parts["bite"] = bite
	if hand and hand.get_parent() is Node3D:
		# Undo the rig's scale so held weapons keep their size.
		var s := (hand.get_parent() as Node3D).global_basis.get_scale().x
		if s > 0.0:
			hand.scale = Vector3.ONE * global_basis.get_scale().x / s
	if _tree:
		_tree.advance(0.0)


## Hangs the anchor on its bone so that, in the rest pose, it sits at the
## model-space spot in COSMETIC_ANCHORS; from then on it moves with the bone.
func cosmetic_anchor(slot: String) -> Node3D:
	return _anchor(COSMETIC_ANCHORS.get(slot, []))


## A node on the spot's bone at its model-space rest position (see
## COSMETIC_ANCHORS), or null if the rig lacks that bone.
func _anchor(spot: Array) -> Node3D:
	var skel := _find(_inst, "Skeleton3D") as Skeleton3D if _inst else null
	if spot.is_empty() or skel == null or skel.find_bone(spot[0]) < 0:
		return null
	# The skeleton's transform in model space, from the local transforms up
	# the tree (the model may not be in the scene tree yet).
	var skel_xf := Transform3D.IDENTITY
	var n: Node = skel
	while n != self and n is Node3D:
		skel_xf = (n as Node3D).transform * skel_xf
		n = n.get_parent()
	var bone_xf := skel_xf * skel.get_bone_global_rest(skel.find_bone(spot[0]))
	var want := Transform3D(Basis(Vector3.BACK, deg_to_rad(spot[2])), spot[1])
	var ba := BoneAttachment3D.new()
	ba.bone_name = spot[0]
	skel.add_child(ba)
	var anchor := Node3D.new()
	anchor.transform = bone_xf.affine_inverse() * want
	ba.add_child(anchor)
	return anchor


func mouth_global() -> Vector3:
	return _mouth.global_position if _mouth else global_position + Vector3(0, 5, 0)


func _process(delta: float) -> void:
	if _inst == null:
		return
	_pose(delta)
	# Squash on landings and the takeoff crouch, stretch while flying, and
	# the nose tips up on the way up and down on the way down.
	var sq: float = _cur["squash"]
	var stretch := clampf(absf(_vy) * 0.004, 0.0, 0.07) if airborne else 0.0
	_lean.scale = Vector3(1.0 + sq * 0.06 - stretch * 0.5, 1.0 - sq * 0.12 + stretch, 1.0 + sq * 0.06 - stretch * 0.5)
	var tilt := clampf(_vy * 0.012, -0.22, 0.22) if airborne else 0.0
	_lean.rotation.z = -float(_cur["lean"]) * 0.45 + tilt
	_inst.position.y = 0.0
	if _tree:
		_pick_animation(delta)
		_sec_rots = _secondary(delta)
		_dt = delta
	_update_glb_glow(delta)


## Sets the time of each animation and the weight of each layer (moving,
## running, jumping, attacking), then poses the tree.
func _pick_animation(delta: float) -> void:
	var striking: bool = arm_r > 1.3 or arm_l > 1.3 or jaw > 0.5 or bite >= 0.0
	var jump_t := -1.0
	if bite >= 0.0:
		# The bite drives the clip itself, so the jaws close on the hit.
		_land_t = -1.0
		var t := _bite_time(bite)
		if not _striking or t < _atk_t[_atk_slot] - 0.1:
			_atk_slot = 1 - _atk_slot if _wt["atk"] > 0.05 else _atk_slot
		_atk_t[_atk_slot] = t
	elif striking:
		_land_t = -1.0
		var alen: float = _len.get("Attack", 1.0)
		if not _striking or _atk_t[_atk_slot] >= alen:
			# A new strike (or the old one ran out): start over in the other
			# slot so the restart crossfades.
			_atk_slot = 1 - _atk_slot if _wt["atk"] > 0.05 else _atk_slot
			_atk_t[_atk_slot] = 0.0
		elif not (jaw > 0.9 and _atk_t[_atk_slot] > alen * 0.45):  # hold the mouth open for beams and roars
			_atk_t[_atk_slot] += delta * ATTACK_SPEED
	elif _wt["atk"] > 0.0:
		# Let the strike play on while it fades out.
		_atk_t[_atk_slot] = minf(_atk_t[_atk_slot] + delta * ATTACK_SPEED, _len.get("Attack", 1.0))
	_striking = striking
	if not striking:
		# Jumps are posed by hand from the Jump animation: crouch, push off,
		# tuck at the top, reach down while falling, then crouch on touchdown.
		if airborne or crouch > 0.01:
			var t := JUMP_CROUCH * crouch
			if airborne:
				t = JUMP_APEX - clampf(_vy / 17.0, -1.0, 1.0) * (JUMP_APEX - JUMP_RISE)
			_jump_t = lerpf(_jump_t, t, 1.0 - exp(-18.0 * delta)) if _jumping else t
			jump_t = _jump_t
			_land_t = -1.0
		elif _land_t >= 0.0:
			_land_t += delta * 1.5
			# Walking off cuts the recovery short.
			if _land_t < JUMP_END and not (_walk > 0.3 and _land_t > JUMP_LAND + 0.15):
				jump_t = _land_t
			else:
				_land_t = -1.0
	_jumping = jump_t >= 0.0
	if _jumping:
		_jump_t = jump_t

	# Locomotion: the ground speed sets the walk/run mix and how fast the
	# shared stride phase runs, so the planted feet move with the ground.
	var target := walk_amount * walk_speed * FULL_SPEED / maxf(scale.x, 0.01)
	_speed = lerpf(_speed, target, 1.0 - exp(-(12.0 if target > _speed else 8.0) * delta))
	var run := smoothstep(RUN_FROM, RUN_TO, _speed)
	var stride := lerpf(WALK_GROUND_SPEED * _len.get("Walk", 1.0), RUN_GROUND_SPEED * _len.get("Run", 1.0), run)
	var move := clampf(target / 1.5, 0.0, 1.0)
	# Keep stepping while the gait fades out, so it settles instead of freezing mid-stride.
	_stride = fposmod(_stride + delta * maxf(_speed, 2.5 * _wt["move"]) / stride, 1.0)
	_idle_t += delta
	_fade("move", move, delta)
	_wt["run"] = run
	_fade("jump", 1.0 if _jumping else 0.0, delta)
	_fade("atk", 1.0 if striking else 0.0, delta)
	_wt["slot"] = move_toward(_wt["slot"], float(_atk_slot), delta / 0.08)

	_tree.set("parameters/move/blend_amount", _wt["move"])
	_tree.set("parameters/run/blend_amount", _wt["run"])
	_tree.set("parameters/jump/blend_amount", _wt["jump"])
	_tree.set("parameters/atk/blend_amount", _wt["atk"])
	_tree.set("parameters/slot/blend_amount", _wt["slot"])
	_seek("Idle", fposmod(_idle_t, _len.get("Idle", 1.0)))
	_seek("Walk", _stride * _len.get("Walk", 1.0))
	_seek("Run", _stride * _len.get("Run", 1.0))
	_seek("Jump", _jump_t)
	_seek("Attack", _atk_t[0])
	_seek("Attack2", _atk_t[1])
	_tree.advance(0.0)
	if _wt["jump"] > 0.01 and _body_bone >= 0:
		# The Jump animation's own upward motion is taken out, since the
		# body already flies through the air.
		var lift: float = _body_y(_skel.get_bone_global_pose(_body_bone).origin) - _body_rest
		_inst.position.y = -maxf(lift, 0.0)


## Attack clip time for a bite phase (see KaijuModel.bite).
func _bite_time(b: float) -> float:
	if b <= 1.0:
		return lerpf(BITE_OPEN, BITE_SNAP, b)
	if b <= 1.3:
		return lerpf(BITE_SNAP, BITE_SHUT, (b - 1.0) / 0.3)
	return lerpf(BITE_SHUT, BITE_END, minf((b - 1.3) / 0.7, 1.0))


## Height of a skeleton-space point in the space _inst sits in.
func _body_y(p: Vector3) -> float:
	return _lean.to_local(_skel.to_global(p)).y


func _fade(layer: String, target: float, delta: float) -> void:
	var rates: Array = FADE[layer]
	var rate: float = rates[0] if target > _wt[layer] else rates[1]
	_wt[layer] = lerpf(_wt[layer], target, 1.0 - exp(-rate * delta))
	if absf(_wt[layer] - target) < 0.002:
		_wt[layer] = target


func _seek(n: String, t: float) -> void:
	_tree.set("parameters/t_%s/seek_request" % n, maxf(t, 0.0))


func land(hard: float) -> void:
	super.land(hard)
	if _jumping:
		_land_t = JUMP_LAND
	_kick("tail_z", 0.9 + hard * 0.8)


func flash() -> void:
	super.flash()
	_kick("flinch", 7.0)


## Builds the tree: Idle, Walk, Run, Jump and two Attack slots, each behind a
## TimeSeek so _pick_animation sets their times, mixed by Blend2 layers.
func _build_tree() -> void:
	var lib := _anim.get_animation_library("")
	if lib == null:
		return
	var bt := AnimationNodeBlendTree.new()
	var clips := {"Idle": "Idle", "Walk": "Walk", "Run": "Run", "Jump": "Jump", "Attack": "Attack", "Attack2": "Attack"}
	for n in clips:
		if not lib.has_animation(clips[n]):
			return
		_len[n] = lib.get_animation(clips[n]).length
		var a := AnimationNodeAnimation.new()
		a.animation = clips[n]
		bt.add_node(n, a)
		var ts := AnimationNodeTimeSeek.new()
		ts.explicit_elapse = false
		bt.add_node("t_" + n, ts)
		bt.connect_node("t_" + n, 0, n)
	for layer in [["run", "t_Walk", "t_Run"], ["move", "t_Idle", "run"], ["jump", "move", "t_Jump"],
			["slot", "t_Attack", "t_Attack2"], ["atk", "jump", "slot"]]:
		bt.add_node(layer[0], AnimationNodeBlend2.new())
		bt.connect_node(layer[0], 0, layer[1])
		bt.connect_node(layer[0], 1, layer[2])
	bt.connect_node("output", 0, "atk")
	_tree = AnimationTree.new()
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.add_animation_library("", lib)
	_tree.tree_root = bt
	# Same parent as the player, so the tracks' paths resolve the same way.
	_anim.get_parent().add_child(_tree)
	_anim.stop()
	_anim.active = false


## Secondary motion, worked out after the tree has posed the skeleton:
## advances the springs and returns, per bone, an extra rotation as a
## model-space rotation vector (axis * angle). See Secondary.
func _secondary(delta: float) -> Dictionary:
	var out := {}
	if _bones.is_empty():
		return out
	var idle: float = (1.0 - _wt["move"]) * (1.0 - _wt["atk"]) * (1.0 - _wt["jump"])
	var mv: float = _wt["move"] * (1.0 - _wt["jump"])
	var turn: float = _cur["turn"]
	# Tail: a chain of springs, each chasing the one before, so motion
	# travels down it. Sideways it trails turns and swings with the stride;
	# up and down it lags the body's vertical motion.
	var swing: float = sin(_stride * TAU - 0.6) * 0.05 * mv + sin(_t * 1.1) * 0.03 * idle
	_chain("tail_y", -turn * 0.16 + swing, delta)
	_chain("tail_z", clampf(_vy * 0.012, -0.3, 0.3) if airborne else 0.0, delta)
	_spring("flinch", 0.0, delta)
	# Leaning into speeding up and back when braking.
	_spring("accel", clampf((walk_amount * walk_speed * FULL_SPEED / maxf(scale.x, 0.01) - _speed) * 0.03, -0.18, 0.14), delta)
	var ty: Array = _sec["tail_y"]
	var tz: Array = _sec["tail_z"]
	var fl: float = _sec["flinch"]
	for i in TAIL_BONES.size():
		var k := 0.6 + 0.4 * i / (TAIL_BONES.size() - 1.0)
		out[TAIL_BONES[i]] = Vector3(0, ty[i] * k, 0) + Vector3(0, 0, (tz[i] - fl * 0.25) * k)
	# Spine: the head leads turns, the upper body leans with acceleration,
	# a hit throws it back, and when idle it breathes and looks around.
	var look: float = (sin(_t * 0.37) * 0.6 + sin(_t * 0.91 + 1.3) * 0.4) * 0.16 * idle
	var nod: float = (sin(_t * 0.53 + 0.4) * 0.5 + 0.5) * 0.06 * idle
	var breathe: float = sin(_t * 1.9) * 0.025 * idle
	var acc: float = _sec["accel"]
	var share := [0.25, 0.2, 0.15, 0.2, 0.2]
	for i in SPINE_BONES.size():
		var yaw: float = turn * 0.13 * share[i] * 5.0 * (0.4 + 0.6 * i / 4.0) + look * (0.0 if i < 3 else 0.5)
		var pitch: float = -acc * share[i] + fl * 0.05 * share[i] * 5.0 + breathe * (1.0 if i < 3 else -0.5) \
			- nod * (1.0 if i == 4 else 0.0) + (tz[0] * 0.25 if i >= 3 else 0.0)
		out[SPINE_BONES[i]] = Vector3(0, yaw, pitch)
	return out


func _spring(key: String, target: float, delta: float) -> void:
	var sp: Array = SEC_SPRINGS[key]
	var x: float = _sec.get(key, 0.0)
	var v: float = _sec_v.get(key, 0.0)
	var steps := clampi(ceili(delta * 120.0), 1, 8)
	var dt := delta / steps
	for _i in steps:
		v += (sp[0] * sp[0] * (target - x) - 2.0 * sp[1] * sp[0] * v) * dt
		x += v * dt
	_sec[key] = x
	_sec_v[key] = v


func _chain(key: String, target: float, delta: float) -> void:
	var sp: Array = SEC_SPRINGS[key]
	if not _sec.has(key):
		_sec[key] = [0.0, 0.0, 0.0, 0.0, 0.0]
		_sec_v[key] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var xs: Array = _sec[key]
	var vs: Array = _sec_v[key]
	var steps := clampi(ceili(delta * 120.0), 1, 8)
	var dt := delta / steps
	for _i in steps:
		var goal := target
		for j in xs.size():
			var f: float = sp[0] * (1.0 - 0.1 * j)
			vs[j] += (f * f * (goal - xs[j]) - 2.0 * sp[1] * f * vs[j]) * dt
			xs[j] += vs[j] * dt
			goal = xs[j]


## Kicks a spring (or the first link of a chain) with velocity v.
func _kick(key: String, v: float) -> void:
	if not _sec_v.has(key):
		if SEC_SPRINGS.has(key) and key.begins_with("tail"):
			_chain(key, 0.0, 0.0)
		else:
			_sec_v[key] = 0.0
	if _sec_v[key] is Array:
		_sec_v[key][0] += v
	else:
		_sec_v[key] += v


func _update_glb_glow(delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	var e := 0.45 + glow * (0.9 + pulse * (1.2 if glow >= 1.0 else 0.0))
	for i in _glow_mats.size():
		_glow_mats[i].emission_energy_multiplier = _glow_base[i] * e
	for m in _eyes:
		m.emission_energy_multiplier = 1.5 + eye_glow * 5.0
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 7.0, 0.0)
		for m in _skin_mats:
			m.emission_enabled = _flash > 0.0
			m.emission = Color(1, 0.95, 0.9)
			m.emission_energy_multiplier = _flash * 1.5


## Gives this instance its own copies of the materials (so one hero's flash or
## glow never lights up another) and sorts them into skin, glow and eyes.
func _collect_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.lod_bias = LOD_BIAS
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if not (src is StandardMaterial3D):
				continue
			var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mi.set_surface_override_material(i, m)
			if m.resource_name == "Eyes":
				_eyes.append(m)
			elif m.emission_enabled:
				_glow_mats.append(m)
				_glow_base.append(1.0)  # the file's strengths are tuned for offline renders
			else:
				_skin_mats.append(m)
	for c in n.get_children():
		_collect_materials(c)


func _attach(skel: Skeleton3D, bone: String) -> Node3D:
	if skel == null or skel.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var n := Node3D.new()
	ba.add_child(n)
	return n


func _find(n: Node, type: String) -> Node:
	if n.is_class(type):
		return n
	for c in n.get_children():
		var r := _find(c, type)
		if r:
			return r
	return null


## Holds planted hind feet in place (see FOOT_CONTACT). Runs in the skeleton
## modifier, after the animation and the spine and tail motion.
func _plant_feet(sk: Skeleton3D) -> void:
	var w: float = 0.0 if airborne else _wt["move"] * (1.0 - _wt["jump"]) * (1.0 - _wt["atk"])
	var xf := sk.global_transform
	var size := global_basis.get_scale().y
	for i in _legs.size():
		var ids: Array = _legs[i]
		var e: Vector3 = xf * sk.get_bone_global_pose(ids[2]).origin
		var local := to_local(e)
		var swing: float = (local.x - _foot_prev[i].x) / maxf(_dt, 0.001)
		_foot_prev[i] = local
		var down := e.y - global_position.y < FOOT_CONTACT * size
		if w > 0.3 and down and (_foot_lock[i] != null or swing < 3.0 * size):
			if _foot_lock[i] == null:
				_foot_lock[i] = e
			var off: Vector3 = _foot_lock[i] - e
			off.y = 0.0
			if off.length() > FOOT_MAX_PULL * size:
				# Stride too long to hold: let the foot slip along.
				off = off.limit_length(FOOT_MAX_PULL * size)
				_foot_lock[i] = e + off
			_foot_off[i] = off
		else:
			_foot_lock[i] = null
			_foot_off[i] = (_foot_off[i] as Vector3).lerp(Vector3.ZERO, 1.0 - exp(-14.0 * _dt))
		var pull: Vector3 = _foot_off[i] * minf(w * 1.5, 1.0)
		if pull.length_squared() > 1e-6:
			_reach(sk, ids, xf.affine_inverse() * (e + pull))


## Two-bone IK: bends the knee so thigh and shin span the distance to
## `target` (skeleton space), then swings the thigh to point the foot at it.
func _reach(sk: Skeleton3D, ids: Array, target: Vector3) -> void:
	var gt := sk.get_bone_global_pose(ids[0])
	var gk := sk.get_bone_global_pose(ids[1])
	var h := gt.origin
	var k := gk.origin
	var e := sk.get_bone_global_pose(ids[2]).origin
	var a := h.distance_to(k)
	var b := k.distance_to(e)
	var n := (h - k).cross(e - k)
	if a < 1e-4 or b < 1e-4 or n.length_squared() < 1e-10:
		return
	var c := clampf(h.distance_to(target), absf(a - b) + 0.01, a + b - 0.01)
	var bend := Basis(n.normalized(), acos(clampf((a * a + b * b - c * c) / (2.0 * a * b), -1.0, 1.0)) - (h - k).angle_to(e - k))
	var swing := Basis(Quaternion((k + bend * (e - k) - h).normalized(), (target - h).normalized()))
	gt.basis = swing * gt.basis
	gk.basis = swing * bend * gk.basis
	gk.origin = h + swing * (k - h)
	sk.set_bone_global_pose(ids[0], gt)
	sk.set_bone_global_pose(ids[1], gk)


## Adds GlbKaijuModel's secondary motion on top of the animated pose. Each
## bone turns about model-space axes through its own origin, so a rotation
## on a spine or tail bone bends everything after it.
class Secondary extends SkeletonModifier3D:
	var model: GlbKaijuModel

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or model == null:
			return
		var rots := model._sec_rots
		var to_skel := model._skel_basis.inverse()
		for b in rots:
			var idx: int = model._bones.get(b, -1)
			var r: Vector3 = rots[b]
			if idx < 0 or r.length_squared() < 1e-8:
				continue
			var parent := sk.get_bone_parent(idx)
			var pq := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion()
			# Model-space rotation vector -> skeleton space -> the parent bone's space.
			var axis := pq.inverse() * (to_skel * r)
			var ang := axis.length()
			sk.set_bone_pose_rotation(idx, Quaternion(axis / ang, ang) * sk.get_bone_pose_rotation(idx))
		model._plant_feet(sk)
