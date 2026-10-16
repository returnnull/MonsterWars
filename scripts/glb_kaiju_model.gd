class_name GlbKaijuModel
extends KaijuModel
## A hero kaiju loaded from a rigged .glb (the T-Rex variants in
## assets/heroes, built from Quaternius' CC0 T-Rex). It takes the same pose
## targets as KaijuModel and maps them onto the model's own animations:
## Idle, Walk, Run, Attack and Jump. Lean tilts the whole body, glow drives
## the emissive spikes and eye_glow the eyes. Faces +X with its origin at the
## feet, like KaijuModel.

## World units per glTF unit; the T-Rex is about 15 units tall in the file.
const MODEL_SCALE := 0.31
const BLEND := 0.15
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

var _inst: Node3D
var _lean: Node3D
var _anim: AnimationPlayer
var _mouth: Node3D
var _glow_mats: Array[StandardMaterial3D] = []
var _glow_base: Array[float] = []
var _skin_mats: Array[StandardMaterial3D] = []
var _eyes: Array[StandardMaterial3D] = []
var _playing := ""
var _skel: Skeleton3D
var _body_bone := -1
var _body_rest := 0.0
## Landing: time into the Jump animation's touchdown part (< 0 when not landing).
var _land_t := -1.0
var _jump_t := 0.0

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
	if _anim:
		for n in ["Idle", "Walk", "Run"]:
			if _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var skel := _find(_inst, "Skeleton3D") as Skeleton3D
	_skel = skel
	if skel:
		_body_bone = skel.find_bone("Body")
		if _body_bone >= 0:
			_body_rest = _body_y(skel.get_bone_global_rest(_body_bone).origin)
	_collect_materials(_inst)
	# Pivots the player uses: the right hand holds weapons, the snout fires beams.
	var hand := _attach(skel, "FrontFoot.R")
	_mouth = _attach(skel, "Head_end")
	parts = {"arm_r_fore": hand, "hips": _lean}
	if hand and hand.get_parent() is Node3D:
		# Undo the rig's scale so held weapons keep their size.
		var s := (hand.get_parent() as Node3D).global_basis.get_scale().x
		if s > 0.0:
			hand.scale = Vector3.ONE * global_basis.get_scale().x / s
	_play("Idle")


## Hangs the anchor on its bone so that, in the rest pose, it sits at the
## model-space spot in COSMETIC_ANCHORS; from then on it moves with the bone.
func cosmetic_anchor(slot: String) -> Node3D:
	var spot: Array = COSMETIC_ANCHORS.get(slot, [])
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
	if _anim:
		_pick_animation(delta)
	_update_glb_glow(delta)


func _pick_animation(delta: float) -> void:
	var striking: bool = arm_r > 1.3 or arm_l > 1.3 or jaw > 0.5
	if striking:
		_land_t = -1.0
		if _playing != "Attack":
			_play("Attack", 0.08)
			_anim.speed_scale = 1.4
		elif jaw > 0.9 and _anim.current_animation_position > _anim.current_animation_length * 0.45:
			_anim.speed_scale = 0.0  # hold the mouth open for beams and roars
		elif not _anim.is_playing():
			_play("Attack", 0.0)
		return
	# Jumps are posed by hand from the Jump animation: crouch, push off,
	# tuck at the top, reach down while falling, then crouch on touchdown.
	if airborne or crouch > 0.01:
		var t := JUMP_CROUCH * crouch
		if airborne:
			t = JUMP_APEX - clampf(_vy / 17.0, -1.0, 1.0) * (JUMP_APEX - JUMP_RISE)
		_jump_t = lerpf(_jump_t, t, 1.0 - exp(-18.0 * delta)) if _playing == "Jump" else t
		_hold_jump(_jump_t)
		_land_t = -1.0
		return
	if _land_t >= 0.0:
		_land_t += delta * 1.5
		# Walking off cuts the recovery short.
		if _land_t < JUMP_END and not (_walk > 0.3 and _land_t > JUMP_LAND + 0.15):
			_hold_jump(_land_t)
			return
		_land_t = -1.0
	if _walk > 0.08:
		var fast := walk_amount * walk_speed > 0.8
		_play("Run" if fast else "Walk")
		_anim.speed_scale = clampf(walk_amount * walk_speed * (1.0 if fast else 1.6), 0.6, 1.8)
	else:
		_play("Idle")
		_anim.speed_scale = 1.0


func land(hard: float) -> void:
	super.land(hard)
	if _playing == "Jump":
		_land_t = JUMP_LAND


## Shows the Jump animation frozen at `t`. Its own upward root motion is
## taken out, since the body already flies through the air.
func _hold_jump(t: float) -> void:
	if not _anim.has_animation("Jump"):
		return
	if _playing != "Jump":
		_playing = "Jump"
		_anim.play("Jump", 0.06)
	_anim.speed_scale = 0.0
	_anim.seek(t, true)
	if _body_bone >= 0:
		var lift := _body_y(_skel.get_bone_global_pose(_body_bone).origin) - _body_rest
		_inst.position.y = -maxf(lift, 0.0)


## Height of a skeleton-space point in the space _inst sits in.
func _body_y(p: Vector3) -> float:
	return _lean.to_local(_skel.to_global(p)).y


func _play(n: String, blend: float = BLEND) -> void:
	if not _anim.has_animation(n):
		return
	if _playing == n and _anim.is_playing():
		return
	_playing = n
	_anim.play(n, blend)


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
