class_name Player
extends Kaiju
## A playable kaiju: 3-hit light combo, heavy slam, jump stomp, dodge,
## rage skills paid for with rage (see RAGE_SKILLS) and a super special
## unique to each hero. Learned skill tree abilities
## (Skills.mods) change stats and add effects to the attacks.
## `slot` (0-3) picks the controller; `hero` picks a Content.HEROES entry.

signal rage_changed(rage: float, max_rage: float)
signal super_changed(value: float, max_value: float)

enum S { FREE, ATTACK, DODGE, BEAM, STOMP, HURT, DEAD, SUPER }

const SPEED := 9.5
const DEPTH_SPEED := 6.5
const JUMP_VEL := 17.0
const RAGE_MAX := 100.0
const BEAM_LEN := 42.0
const BEAM_TIME := 2.6
const BEAM_CHARGE := 0.4
const SUPER_MAX := 100.0
const SUPER_TIME := 3.2
## Rage works like mana: dealing and taking damage fills the bar, and rage
## skills spend it. Hold special and press another button to use one; tap
## special on its own to switch rage mode on or off.
##   strike  special + light: lunge forward with a heavy blow
##   roar    special + jump:  knock enemies back and share rage with allies
##   attack  special + heavy: the hero's rage attack (beam, nova or quake)
##   mode    special tapped:  rage mode, drains RAGE_MODE_DRAIN per second
const RAGE_SKILLS := {"strike": 25.0, "roar": 35.0, "attack": 50.0, "mode": 30.0}
const RAGE_MODE_DRAIN := 10.0
## A special press held longer than this without a combo does nothing.
const SPECIAL_TAP := 0.45

const ATTACKS := {
	"light1": {"dur": 0.30, "active": 0.11, "dmg": 7.0, "kb": Vector3(4, 0, 0), "reach": 2.6, "radius": 2.3,
		"pose": "jab_r", "shake": 0.12, "bdmg": 10.0, "next": "light2"},
	"light2": {"dur": 0.30, "active": 0.11, "dmg": 7.0, "kb": Vector3(4, 0, 0), "reach": 2.6, "radius": 2.3,
		"pose": "jab_l", "shake": 0.12, "bdmg": 10.0, "next": "light3"},
	"light3": {"dur": 0.55, "active": 0.24, "dmg": 13.0, "kb": Vector3(15, 8, 0), "reach": 0.0, "radius": 4.8,
		"pose": "spin", "shake": 0.35, "bdmg": 18.0, "next": ""},
	"heavy": {"dur": 0.72, "active": 0.38, "dmg": 22.0, "kb": Vector3(20, 10, 0), "reach": 3.0, "radius": 3.0,
		"pose": "slam", "shake": 0.55, "bdmg": 45.0, "next": ""},
	# With a building piece in hand (damage is multiplied by the weapon).
	"swing1": {"dur": 0.42, "active": 0.16, "dmg": 9.0, "kb": Vector3(10, 4, 0), "reach": 3.4, "radius": 2.9,
		"pose": "swing", "shake": 0.25, "bdmg": 30.0, "next": "swing2"},
	"swing2": {"dur": 0.5, "active": 0.18, "dmg": 11.0, "kb": Vector3(18, 9, 0), "reach": 3.4, "radius": 3.1,
		"pose": "swing", "shake": 0.35, "bdmg": 30.0, "next": ""},
	"throw": {"dur": 0.45, "active": 0.2, "dmg": 0.0, "kb": Vector3.ZERO, "reach": 0.0, "radius": 0.0,
		"pose": "throw", "shake": 0.0, "bdmg": 0.0, "next": ""},
	# Rage skills ("rage": true): boosted by Focus, don't refill rage themselves.
	"rage_strike": {"dur": 0.6, "active": 0.22, "dmg": 30.0, "kb": Vector3(24, 11, 0), "reach": 3.2, "radius": 3.6,
		"pose": "jab_r", "shake": 0.5, "bdmg": 60.0, "next": "", "lunge": 30.0, "rage": true},
	"roar": {"dur": 0.75, "active": 0.25, "dmg": 12.0, "kb": Vector3(18, 9, 0), "reach": 0.0, "radius": 9.0,
		"pose": "roar", "shake": 0.45, "bdmg": 10.0, "next": "", "lunge": 0.0, "rage": true},
}
const GRAB_RANGE := 4.5
## Button pressed with special held -> buffered rage skill.
const RAGE_BUTTONS := {"light": "rage_strike", "jump": "rage_roar", "heavy": "rage_attack"}

var slot := 0
var hero := 0
var speed_mul := 1.0
var power := 1.0
var state := S.FREE
var state_t := 0.0
var rage := 0.0
## Size of the rage bar (RAGE_MAX plus Deep Rage from the skill tree).
var rage_max := RAGE_MAX
## How often each rage skill was used this stage (for tests and stats).
var rage_uses := {}
var atk: Dictionary = {}
var _atk_done := false
var _buffered := ""
var _buffer_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _beam_tick := 0.0
var _beam: Node3D
var _beam_light: OmniLight3D
var _rage_announced := false
## Special is held as a modifier for rage skills; _special_combo is set once
## another button was pressed with it, so letting go doesn't toggle rage mode.
var _special_held := -1.0
var _special_combo := false
var _death_tween: Tween
var _h: Dictionary
var _special := "beam"
var _special_step := 0
var level := 1
## Learned abilities, {kind: value} (see Skills.KINDS).
var sk := {}
var raging := false
var super_meter := 0.0
var _special_time := BEAM_TIME
var _super := {}
var _super_tick := 0.0
var _super_step := 0
var _super_targets: Array = []
var _barrier_up := false
var _barrier_t := 0.0
var _barrier_fx: MeshInstance3D
var _second_wind_used := false
var _aura_t := 0.0
## Building piece in hand ("" for none, else a Weapon.KINDS key) and swings left.
var weapon := ""
var weapon_uses := 0
var _held: Node3D


func _ready() -> void:
	_h = Content.hero(hero)
	level = Game.hero_level(hero)
	sk = Skills.mods(hero, Game.hero_skills[hero])
	_super = Skills.super_def(hero)
	# Each level above 1 adds 3% health and 2% damage on top of the skill tree.
	max_hp = _h["hp"] * (1.0 + 0.03 * (level - 1)) * (1.0 + _m("vitality") / 100.0)
	speed_mul = _h["speed"] * (1.0 + _m("swift") / 100.0)
	power = _h["power"] * (1.0 + 0.02 * (level - 1)) * (1.0 + _m("power") / 100.0)
	_special = _h["special"]
	_special_time = BEAM_TIME * (1.5 if _has("long_special") else 1.0)
	rage_max = RAGE_MAX + _m("deep_rage")
	_barrier_up = _has("barrier")
	add_to_group("player")
	init_body(1.2, 6.0, Game.LAYER_PLAYER)
	z_min = -5.2
	z_max = 3.0
	model = KaijuModel.new()
	model.look = _h.get("look", {})
	add_child(model)
	model.build(_h["skin"], _h["belly"], _h["accent"], _h["eye"], _h["horns"])
	model.scale = Vector3.ONE * _h["size"]
	hit_radius = 1.6 * _h["size"]
	_beam = _make_beam(_h["accent"])
	add_child(_beam)
	_beam.visible = false
	_barrier_fx = _make_barrier()
	_barrier_fx.visible = _barrier_up
	add_child(_barrier_fx)
	Game.players.append(self)


func _m(kind: String) -> float:
	return float(sk.get(kind, 0.0))


func _has(kind: String) -> bool:
	return sk.has(kind)


## Damage multiplier from rage mode and Berserk.
func _boost() -> float:
	var b := 1.3 if raging else 1.0
	if _has("berserk") and hp < max_hp * 0.4:
		b *= 1.35
	return b


func _speed_boost() -> float:
	var b := 1.2 if raging else 1.0
	if _has("berserk") and hp < max_hp * 0.4:
		b *= 1.2
	return b


func _special_power() -> float:
	return power * _boost() * (1.0 + _m("focus") / 100.0) * (1.25 if _has("long_special") else 1.0)


func display_name() -> String:
	return _h["name"]


func color() -> Color:
	return _h["accent"]


## Brings a downed player back between waves.
func revive() -> void:
	if not dead:
		return
	if _death_tween:
		_death_tween.kill()
	dead = false
	hp = max_hp * 0.5
	health_changed.emit(hp, max_hp)
	invuln = 2.0
	model.rotation.z = 0.0
	_set_state(S.FREE)
	FX.energy(global_position + Vector3(0, 3, 0), color())


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)


func add_super(amount: float) -> void:
	if state == S.SUPER or dead:
		return
	var was_full := super_meter >= SUPER_MAX
	super_meter = minf(super_meter + amount, SUPER_MAX)
	super_changed.emit(super_meter, SUPER_MAX)
	if super_meter >= SUPER_MAX and not was_full:
		FX.energy(global_position + Vector3(0, 4, 0), Color(0.8, 0.5, 1.0))


## Called by the level for every defeated enemy.
func on_enemy_killed() -> void:
	add_super(4.0)
	if _m("rampage") > 0.0:
		add_rage(_m("rampage"))
	if _has("vampire"):
		heal(max_hp * 0.06)
		FX.energy(global_position + Vector3(0, 3, 0), Color(1.0, 0.2, 0.3))


## Controller rumble for this player's gamepad (slot N = gamepad N).
func rumble(weak: float, strong: float, duration: float) -> void:
	Game.rumble(slot, weak, strong, duration)


func _act(action: String) -> String:
	return "p%d_%s" % [slot, action]


## Fills the rage bar. Fury raises every gain; rage mode halves gains so it
## can't keep itself going for ever.
func add_rage(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	amount *= 1.0 + _m("fury") / 100.0
	if raging:
		amount *= 0.5
	rage = minf(rage + amount, rage_max)
	rage_changed.emit(rage, rage_max)
	if rage >= rage_max and not _rage_announced:
		_rage_announced = true
		FX.energy(global_position + Vector3(0, 4, 0), color())
	elif rage < rage_max * 0.9:
		_rage_announced = false


## What a rage skill costs this hero (the "frugal" skill makes it cheaper).
func rage_cost(skill: String) -> float:
	return RAGE_SKILLS[skill] * (1.0 - minf(_m("frugal"), 50.0) / 100.0)


## True if the hero can pay for a rage skill now (Blood Pact pays the
## missing rage with health, but never the last of it, and not for rage mode).
func can_afford(skill: String) -> bool:
	if rage >= rage_cost(skill):
		return true
	return skill != "mode" and _has("blood_pact") and hp > _blood_price(rage_cost(skill) - rage) + 1.0


func _blood_price(missing: float) -> float:
	return missing * max_hp * 0.006


## Pays for a rage skill. Wrath turns the spent rage into super meter.
func _spend_rage(amount: float) -> void:
	var paid := minf(amount, rage)
	if amount > rage and _has("blood_pact"):
		hp = maxf(hp - _blood_price(amount - rage), 1.0)
		health_changed.emit(hp, max_hp)
		FX.energy(global_position + Vector3(0, 3, 0), Color(0.8, 0.05, 0.1))
	rage = maxf(rage - amount, 0.0)
	rage_changed.emit(rage, rage_max)
	if _has("wrath"):
		add_super(paid * 0.5)


## Uses a rage skill if the hero can pay for it. Returns true if it started.
func _use_rage_skill(skill: String) -> bool:
	if not can_afford(skill):
		_no_rage()
		return false
	if skill != "mode" and not is_on_floor():
		return false
	rage_uses[skill] = int(rage_uses.get(skill, 0)) + 1
	match skill:
		"strike", "roar":
			_spend_rage(rage_cost(skill))
			if skill == "roar":
				_roar()
			_start_attack("rage_strike" if skill == "strike" else "roar")
			FX.energy(global_position + Vector3(facing * 1.5, 4.0, 0), color())
			rumble(0.4, 0.6, 0.2)
		"attack":
			_spend_rage(rage_cost(skill))
			_start_beam()
		"mode":
			_enter_rage_mode()
	return true


## Not enough rage: a short red flash on the bar instead of the skill.
func _no_rage() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_rage"):
		hud.flash_rage(slot)


## War Roar: other players nearby get rage too.
func _roar() -> void:
	FX.shockwave(global_position, 9.0, color())
	FX.shockwave(global_position, 5.0, Color(1.0, 0.9, 0.6))
	Game.shake(0.4)
	for p in Game.living_players():
		if p != self and p.global_position.distance_to(global_position) < 16.0:
			p.add_rage(15.0)
			FX.energy(p.global_position + Vector3(0, 4, 0), color())


## Rage mode: the kaiju glows, hits 30% harder, moves 20% faster, takes
## less damage and can't be staggered. It drains rage every second and ends
## when the bar is empty or special is tapped again.
func _enter_rage_mode() -> void:
	raging = true
	rumble(0.6, 0.8, 0.4)
	_rage_announced = false
	Game.shake(0.5)
	Game.hitstop(0.12)
	FX.shockwave(global_position, 8.0, color())
	FX.energy(global_position + Vector3(0, 4, 0), color())
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and Game.players.size() == 1:
		hud.show_message("RAGE MODE!", 1.2)


func _exit_rage_mode() -> void:
	raging = false
	rage_changed.emit(rage, rage_max)


func _physics_process(delta: float) -> void:
	state_t += delta
	invuln = maxf(invuln - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_passives(delta)
	_read_buffer(delta)
	var input := Vector2(Input.get_axis(_act("move_left"), _act("move_right")), Input.get_axis(_act("move_up"), _act("move_down")))
	if input.length() > 1.0:
		input = input.normalized()

	var move := Vector3.ZERO
	match state:
		S.FREE:
			move = _state_free(input)
		S.ATTACK:
			move = _state_attack()
		S.DODGE:
			move = _dodge_dir * 22.0 * maxf(1.0 - state_t / 0.35, 0.2)
			if state_t >= 0.35:
				_set_state(S.FREE)
		S.BEAM:
			_state_beam(delta)
		S.STOMP:
			if state_t > 0.05 and is_on_floor():
				_stomp_land()
		S.HURT:
			hitstun -= delta
			if hitstun <= 0.0:
				_set_state(S.FREE)
		S.DEAD:
			pass
		S.SUPER:
			_state_super(delta)
	move_body(delta, move)
	_animate(delta)


## Rage mode drain, regeneration, Overdrive, Barrier and Aura.
func _passives(delta: float) -> void:
	if dead:
		return
	if raging and state != S.BEAM:
		rage = maxf(rage - RAGE_MODE_DRAIN * (1.0 - minf(_m("frugal"), 50.0) / 100.0) * delta, 0.0)
		rage_changed.emit(rage, rage_max)
		if rage <= 0.0:
			_exit_rage_mode()
	if _m("regen") > 0.0 and hp < max_hp:
		heal(max_hp * _m("regen") / 100.0 * delta)
	if _has("overdrive"):
		add_rage(3.0 * delta)
		add_super(1.2 * delta)
	if _has("barrier") and not _barrier_up:
		_barrier_t -= delta
		if _barrier_t <= 0.0:
			_barrier_up = true
			_barrier_fx.visible = true
	if _has("aura"):
		_aura_t -= delta
		if _aura_t <= 0.0:
			_aura_t = 0.5
			for e in get_tree().get_nodes_in_group("enemies"):
				if not e.dead and e.hit_center().distance_to(hit_center()) < 6.0 + e.hit_radius:
					if e.take_hit(4.0 * power, Vector3.ZERO, self):
						FX.hit_spark(e.hit_center(), 4.0)
	_barrier_fx.rotation.y += delta * 2.0


func _set_state(s: S) -> void:
	state = s
	state_t = 0.0


func _read_buffer(delta: float) -> void:
	_buffer_t -= delta
	if _buffer_t <= 0.0:
		_buffered = ""
	# Special is a modifier: with it held, light/jump/heavy become rage skills.
	var special := _act("special")
	if Input.is_action_just_pressed(special):
		_special_held = 0.0
		_special_combo = false
	elif _special_held >= 0.0:
		if Input.is_action_pressed(special):
			_special_held += delta
		else:
			if not _special_combo and _special_held < SPECIAL_TAP:
				_buffered = "rage_mode"
				_buffer_t = 0.3
			_special_held = -1.0
	for a in ["light", "heavy", "jump", "dodge", "super"]:
		if Input.is_action_just_pressed(_act(a)):
			if _special_held >= 0.0 and a in RAGE_BUTTONS:
				_special_combo = true
				_buffered = RAGE_BUTTONS[a]
				_buffer_t = 0.4
			else:
				_buffered = a
				_buffer_t = 0.25


func _consume() -> String:
	var b := _buffered
	_buffered = ""
	return b


func _state_free(input: Vector2) -> Vector3:
	face_toward(input.x)
	match _buffered:
		"jump":
			_consume()
			if is_on_floor():
				velocity.y = JUMP_VEL
		"light", "heavy":
			var b := _consume()
			if not is_on_floor():
				_start_stomp()
			elif b == "heavy" and weapon == "" and _grab_weapon():
				pass
			elif weapon != "":
				_start_attack("swing1" if b == "light" else "throw")
			else:
				_start_attack("light1" if b == "light" else "heavy")
			return Vector3.ZERO
		"dodge":
			if _dodge_cd <= 0.0:
				_consume()
				_dodge_dir = Vector3(input.x, 0, input.y).normalized()
				if _dodge_dir == Vector3.ZERO:
					_dodge_dir = Vector3(-facing, 0, 0)
				invuln = 0.4
				_dodge_cd = 0.6 * (1.0 - minf(_m("swift"), 40.0) / 100.0)
				FX.dust(global_position, 0.6)
				if _m("afterimage") > 0.0:
					var hits := strike(global_position + Vector3(0, 2.5, 0), 4.5, _m("afterimage") * power * _boost(), Vector3(8, 6, 0), "enemies")
					FX.energy(global_position + Vector3(0, 2.5, 0), color())
					FX.shockwave(global_position, 4.5, color())
					add_rage(3.0 * hits)
				_set_state(S.DODGE)
		"rage_strike", "rage_roar", "rage_attack":
			var skill: String = _consume().trim_prefix("rage_")
			if _use_rage_skill(skill) and state != S.FREE:
				return Vector3.ZERO
		"rage_mode":
			_consume()
			if raging:
				_exit_rage_mode()
			else:
				_use_rage_skill("mode")
		"super":
			if super_meter >= SUPER_MAX and is_on_floor():
				_consume()
				_start_super()
				return Vector3.ZERO
	var sp := speed_mul * _speed_boost()
	return Vector3(input.x * SPEED * sp, 0, input.y * DEPTH_SPEED * sp)


func _start_attack(attack_name: String) -> void:
	atk = ATTACKS[attack_name]
	_atk_done = false
	_set_state(S.ATTACK)


func _state_attack() -> Vector3:
	var active: float = atk["active"]
	if not _atk_done and state_t >= active:
		_atk_done = true
		_do_hit()
	if state_t >= active:
		var next: String = atk["next"]
		var armed := weapon != ""
		if _buffered == "light" and next != "" and (armed or atk["pose"] != "swing"):
			_consume()
			_start_attack(next)
		elif _buffered == "heavy" and atk["pose"] != "slam" and atk["pose"] != "throw" and not atk.get("rage", false):
			_consume()
			_start_attack("throw" if armed else "heavy")
		elif _buffered.begins_with("rage_") and not atk.get("rage", false):
			# Rage skills cut the recovery of a normal attack short.
			_set_state(S.FREE)
		elif state_t >= atk["dur"]:
			_set_state(S.FREE)
	if state_t < active:
		return Vector3(float(atk.get("lunge", 3.5)) * facing, 0, 0)
	return Vector3.ZERO


## Picks up the nearest building piece in reach. Returns false if none.
func _grab_weapon() -> bool:
	var best: Weapon = null
	var best_d := GRAB_RANGE
	for w in get_tree().get_nodes_in_group("weapons"):
		if w.thrower != null:
			continue
		var d := Vector2(w.global_position.x - global_position.x, w.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = w
	if best == null:
		return false
	_set_weapon(best.kind)
	best.queue_free()
	FX.dust(best.global_position, 0.8)
	Game.shake(0.15)
	return true


func _set_weapon(kind: String) -> void:
	weapon = kind
	if _held:
		_held.queue_free()
		_held = null
	if kind == "":
		return
	weapon_uses = Weapon.KINDS[kind]["uses"]
	_held = Weapon.make_mesh(kind)
	_held.scale = Vector3.ONE * 0.85
	var hand: Node3D = model.parts.get("arm_r_fore", model)
	hand.add_child(_held)
	_held.position = Vector3(0.1, -1.3, 0)
	_held.rotation.z = -PI / 2


func _swing_weapon(center: Vector3) -> void:
	var w: Dictionary = Weapon.KINDS[weapon]
	var reach_c := global_position + Vector3(facing * (atk["reach"] + w["reach"]), 3.0, 0)
	var dmg: float = atk["dmg"] * w["dmg"] * power * _boost()
	var hits := strike(reach_c, atk["radius"], dmg, atk["kb"], "enemies", atk["bdmg"] * power * _bdmg())
	if hits > 0:
		Game.shake(atk["shake"])
		Game.hitstop(0.08)
		for i in hits:
			Game.register_hit()
		add_rage(dmg * 0.4 * hits)
		weapon_uses -= 1
		if weapon_uses <= 0:
			FX.debris_burst(reach_c, 1.2)
			FX.dust(reach_c, 1.0)
			_set_weapon("")
	FX.dust(center, 0.4)


func _throw_weapon() -> void:
	var w := Weapon.new()
	w.kind = weapon
	var vel := Vector3(facing * 34.0, 0.0, 0.0)
	if weapon == "slab":
		vel = Vector3(facing * 24.0, 11.0, 0.0)
	w.launch(self, vel, float(Weapon.KINDS[weapon]["throw_dmg"]) * power * _boost())
	get_parent().add_child(w)
	w.global_position = global_position + Vector3(facing * 2.5, 4.5, 0)
	_set_weapon("")
	Game.shake(0.2)


func _do_hit() -> void:
	if atk["pose"] == "throw":
		if weapon != "":
			_throw_weapon()
		return
	if atk["pose"] == "swing":
		if weapon != "":
			_swing_weapon(global_position)
		return
	var reach: float = atk["reach"]
	var center := global_position + Vector3(facing * reach, 3.2, 0)
	if atk["pose"] == "spin" or atk["pose"] == "roar":
		center = global_position + Vector3(0, 2.6, 0)
	var rage_skill: bool = atk.get("rage", false)
	var dmg: float = atk["dmg"] * (_special_power() if rage_skill else power * _boost())
	var hits := strike(center, atk["radius"], dmg, atk["kb"], "enemies", atk["bdmg"] * power * _bdmg())
	var finisher: bool = atk["pose"] == "spin" or atk["pose"] == "slam"
	if atk["pose"] == "slam":
		FX.shockwave(global_position + Vector3(facing * 3.0, 0, 0), 5.0, Color(1.0, 0.8, 0.5))
		FX.dust(global_position + Vector3(facing * 3.0, 0, 0), 1.2)
		Game.shake(0.3)
		if _m("quake_slam") > 0.0:
			_eruption_line(global_position.x, facing, 4, _m("quake_slam") * power * _boost())
	if atk["pose"] == "spin" and _has("aftershock"):
		var c := global_position + Vector3(0, 3.0, 0)
		hits += strike(c, 7.5, 16.0 * power * _boost(), Vector3(12, 9, 0), "enemies", 20.0 * power)
		FX.shockwave(global_position, 7.5, color())
		FX.energy(c, color())
	if finisher and hits > 0 and _m("shock") > 0.0:
		_chain_lightning(center, _m("shock") * power * _boost())
	if atk["pose"] == "jab_r" and rage_skill:
		FX.shockwave(center - Vector3(0, 3.2, 0), 4.0, color())
		FX.energy(center, color())
		FX.dust(global_position, 1.0)
	if hits > 0:
		rumble(0.3, 0.15 if dmg < 15.0 else 0.5, 0.1)
		Game.shake(atk["shake"])
		Game.hitstop(0.05 if dmg < 15.0 else 0.09)
		for i in hits:
			Game.register_hit()
		if not rage_skill:
			add_rage(dmg * 0.45 * hits)


func _bdmg() -> float:
	return 1.0 + _m("wrecker") / 100.0


## Shockwaves that travel forward along the ground (Seismic Slam and co).
func _eruption_line(x0: float, dir: float, count: int, dmg: float) -> void:
	var z := global_position.z
	for i in count:
		await get_tree().create_timer(0.1, false).timeout
		if not is_inside_tree():
			return
		var c := Vector3(x0 + dir * (5.0 + i * 3.5), 1.5, z)
		strike(c, 3.0, dmg, Vector3(5, 13, 0), "enemies", dmg * _bdmg())
		FX.dust(c, 1.0)
		FX.debris_burst(c, 0.8)
		FX.shockwave(Vector3(c.x, 0, z), 3.0, color())


## Lightning that jumps from a hit to the two closest other enemies.
func _chain_lightning(from_pos: Vector3, dmg: float) -> void:
	var targets: Array = get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
		return not e.dead and e.hit_center().distance_to(from_pos) < 14.0)
	targets.sort_custom(func(a, b) -> bool:
		return a.hit_center().distance_to(from_pos) < b.hit_center().distance_to(from_pos))
	var src := from_pos
	for e in targets.slice(0, 3):
		FX.bolt(src, e.hit_center(), color())
		deal(e, dmg, Vector3(facing * 3.0, 2.0, 0))
		src = e.hit_center()


func _start_stomp() -> void:
	velocity.y = -42.0
	_set_state(S.STOMP)


func _stomp_land() -> void:
	var st := 1.0 + _m("stomp") / 100.0
	var hits := strike(global_position + Vector3(0, 1.2, 0), 5.5 * st, 16.0 * power * _boost() * st, Vector3(10, 12, 0), "enemies", 30.0 * power * _bdmg())
	FX.shockwave(global_position, 7.0 * st)
	if _has("meteor"):
		for i in 3:
			_drop_meteor(global_position + Vector3(facing * (4.0 + i * 4.0), 0, randf_range(-2.0, 2.0)), 0.5 + i * 0.18, 18.0 * power * _boost())
	FX.dust(global_position, 1.6)
	Game.shake(0.6)
	if hits > 0:
		Game.hitstop(0.08)
		for i in hits:
			Game.register_hit()
		add_rage(8.0 * hits)
	_set_state(S.FREE)


func _drop_meteor(target: Vector3, fall_time: float, dmg: float, tint: Color = Color(1.0, 0.45, 0.15)) -> void:
	FX.meteor(target, tint, fall_time, func() -> void:
		if is_inside_tree():
			var hits := strike(target + Vector3(0, 1.5, 0), 3.8, dmg, Vector3(8, 14, 0), "enemies", dmg * _bdmg())
			Game.shake(0.3)
			for i in hits:
				Game.register_hit())


func _start_beam() -> void:
	_set_state(S.BEAM)
	_beam_tick = 0.0
	_special_step = 0
	invuln = 0.0
	Game.shake(0.3)
	FX.energy(global_position + Vector3(facing * 2.0, 5.0, 0), color())


## Runs the hero's rage attack (paid for up front, see _use_rage_skill).
func _state_beam(delta: float) -> void:
	if _special == "nova":
		_state_nova()
		return
	if _special == "quake":
		_state_quake()
		return
	if state_t < BEAM_CHARGE:
		return
	_beam.visible = true
	_beam.position = _mouth_pos()
	_beam.rotation.y = 0.0 if facing > 0.0 else PI
	var flicker := 1.0 + sin(state_t * 60.0) * 0.12
	_beam.scale = Vector3(1, flicker, flicker)
	_beam_light.light_energy = 6.0 * flicker
	_beam_tick -= delta
	if _beam_tick <= 0.0:
		_beam_tick = 0.1
		_beam_damage()
		Game.shake(0.1)
	if state_t >= _special_time:
		_beam.visible = false
		_end_special()


func _end_special() -> void:
	_set_state(S.FREE)


## Three expanding energy blasts centred on the hero.
func _state_nova() -> void:
	var pulse_t := BEAM_CHARGE + 0.15 + _special_step * 0.6
	var pulses := 5 if _has("long_special") else 3
	if _special_step < pulses and state_t >= pulse_t:
		_special_step += 1
		var c := global_position + Vector3(0, 3.0, 0)
		var hits := strike(c, 9.0, 18.0 * _special_power(), Vector3(14, 10, 0), "enemies", 45.0 * power * _bdmg())
		FX.shockwave(global_position, 10.0, color())
		FX.energy(c, color())
		Game.shake(0.5)
		for i in hits:
			Game.register_hit()
	if state_t >= _special_time:
		_end_special()


## Stomps that send eruptions marching forward along the street.
func _state_quake() -> void:
	var step_t := BEAM_CHARGE + _special_step * 0.2
	var steps := 14 if _has("long_special") else 9
	if _special_step < steps and state_t >= step_t:
		var x := global_position.x + facing * (3.0 + (_special_step % 9) * 4.5)
		var c := Vector3(x, 1.5, global_position.z)
		_special_step += 1
		var hits := strike(c, 3.8, 14.0 * _special_power(), Vector3(6, 16, 0), "enemies", 0.0)
		for b in get_tree().get_nodes_in_group("buildings"):
			b.try_hit(Vector3(x, 1.5, clampf(global_position.z - 3.0, -7.6, 5.0)), 3.5, 40.0 * power * _bdmg())
		FX.dust(c, 1.4)
		FX.debris_burst(c, 1.2)
		FX.shockwave(Vector3(x, 0, c.z), 4.0, color())
		Game.shake(0.35)
		for i in hits:
			Game.register_hit()
	if state_t >= _special_time:
		_end_special()


func _beam_damage() -> void:
	var origin := global_position + Vector3(facing * 2.2, 4.85, 0)
	for t in get_tree().get_nodes_in_group("enemies"):
		if t.dead:
			continue
		var tc: Vector3 = t.hit_center()
		var along := (tc.x - origin.x) * facing
		var r: float = t.hit_radius
		if along > -1.0 and along < BEAM_LEN and absf(tc.z - origin.z) < 2.5 + r and absf(tc.y - origin.y) < 3.0 + r:
			if deal(t, 5.0 * _special_power(), Vector3(facing * 4.0, 1.0, 0)):
				Game.register_hit()
				FX.hit_spark(Vector3(tc.x - facing * r, origin.y, tc.z), 6.0)
	for b in get_tree().get_nodes_in_group("buildings"):
		b.try_beam(origin, facing, BEAM_LEN, 14.0 * _bdmg())


## Barrier, Armor, rage mode and Second Wind.
func _incoming(dmg: float, _from: Node3D) -> float:
	if state == S.SUPER:
		return 0.0
	if _barrier_up:
		_barrier_up = false
		_barrier_t = 8.0
		_barrier_fx.visible = false
		FX.shockwave(global_position + Vector3(0, 2, 0), 4.0, Color(0.6, 0.9, 1.0))
		invuln = 0.3
		return 0.0
	dmg *= 1.0 - minf(_m("armor"), 60.0) / 100.0
	if raging:
		dmg *= 0.75
	if dmg >= hp and _has("second_wind") and not _second_wind_used:
		_second_wind_used = true
		hp = max_hp * 0.4
		health_changed.emit(hp, max_hp)
		invuln = 2.0
		FX.energy(global_position + Vector3(0, 3, 0), Color(0.5, 1.0, 0.6))
		FX.shockwave(global_position, 8.0, Color(0.5, 1.0, 0.6))
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_message("SECOND WIND!", 1.2)
		return 0.0
	return dmg


## Crits and Execute.
func _modify_damage(target: Node, dmg: float) -> float:
	if _m("execute") > 0.0 and "max_hp" in target and target.hp < target.max_hp * 0.3:
		dmg *= 1.0 + _m("execute") / 100.0
	if _m("crit") > 0.0 and randf() * 100.0 < _m("crit"):
		dmg *= 2.0
		FX.light_flash(target.hit_center(), Color(1.0, 1.0, 0.6), 8.0, 8.0, 0.15)
	return dmg


## Life leech, burn, frost and super meter gain.
func _on_strike_hit(target: Node, dmg: float) -> void:
	add_super(dmg * (0.12 if state != S.SUPER else 0.0))
	if _m("leech") > 0.0:
		heal(dmg * _m("leech") / 100.0)
	if target is Kaiju:
		if _m("burn") > 0.0:
			target.apply_burn(_m("burn") * power, 3.0)
		if _m("frost") > 0.0:
			target.apply_slow(minf(_m("frost"), 70.0) / 100.0, 1.5)


func _on_hurt(dmg: float, from: Node3D) -> void:
	rumble(0.4, clampf(dmg / 30.0, 0.2, 1.0), 0.18)
	add_rage(dmg * 0.35 * (1.0 + _m("bloodrage") / 100.0))
	Game.combo = 0
	if _m("thorns") > 0.0 and from is Kaiju and from.is_in_group("enemies"):
		from.take_hit(_m("thorns") * power, Vector3.ZERO, self)
	# Rage attacks and supers can't be interrupted; rage mode shrugs off stagger.
	if state == S.BEAM or state == S.SUPER or raging:
		hitstun = 0.0
		knock *= 0.3 if raging else 0.0
		return
	_beam.visible = false
	_set_state(S.HURT)


func _on_death() -> void:
	_set_state(S.DEAD)
	_beam.visible = false
	_set_weapon("")
	if raging:
		_exit_rage_mode()
	var tw := create_tween()
	_death_tween = tw
	tw.tween_property(model, "rotation:z", 1.45, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		FX.dust(global_position, 2.0)
		Game.shake(0.8))
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void: died.emit(self))


func _animate(delta: float) -> void:
	var on_floor := is_on_floor()
	var spd := Vector2(velocity.x, velocity.z).length()
	model.walk_amount = clampf(spd / SPEED, 0.0, 1.0) if (on_floor and state == S.FREE) else 0.0
	model.glow = 1.0 if raging else rage / rage_max * 0.7
	model.eye_glow = 1.0 if (state == S.BEAM or state == S.SUPER or raging) else 0.0
	var ar := 0.25
	var al := 0.25
	var jaw := 0.0
	var lean := 0.0
	model.spin = 0.0
	match state:
		S.FREE:
			if not on_floor:
				ar = 1.2
				al = 1.0
		S.ATTACK:
			var active: float = atk["active"]
			var dur: float = atk["dur"]
			var p := clampf(state_t / active, 0.0, 1.0)
			var after := clampf((state_t - active) / maxf(dur - active, 0.01), 0.0, 1.0)
			match atk["pose"]:
				"jab_r":
					ar = lerpf(-0.5, 1.8, p * p) if after == 0.0 else lerpf(1.8, 0.3, after)
					lean = 0.25
				"jab_l":
					al = lerpf(-0.5, 1.8, p * p) if after == 0.0 else lerpf(1.8, 0.3, after)
					lean = 0.25
				"spin":
					model.spin = -TAU * clampf(state_t / (active * 1.6), 0.0, 1.0)
					ar = 1.4
					al = 1.4
				"swing":
					if after == 0.0:
						ar = lerpf(0.5, 3.0, p)
						lean = -0.15 * p
					else:
						ar = lerpf(3.0, -0.6, minf(after * 3.0, 1.0))
						lean = 0.3
				"throw":
					ar = lerpf(0.5, 3.2, p) if after == 0.0 else lerpf(3.2, 1.2, minf(after * 3.0, 1.0))
					lean = -0.2 if after == 0.0 else 0.35
				"roar":
					jaw = 1.0 if after < 0.7 else lerpf(1.0, 0.0, (after - 0.7) / 0.3)
					ar = 2.2
					al = 2.2
					lean = -0.35 if after == 0.0 else lerpf(-0.35, 0.0, after)
				"slam":
					if after == 0.0:
						ar = lerpf(0.3, 3.0, p)
						al = ar
						lean = -0.25 * p
						jaw = p
					else:
						ar = lerpf(1.1, 0.4, after)
						al = ar
						lean = lerpf(0.5, 0.0, after)
		S.DODGE:
			lean = 0.4
			ar = -0.4
			al = -0.4
		S.BEAM:
			jaw = 1.0
			match _special:
				"nova":
					ar = 2.6
					al = 2.6
					lean = -0.3
				"quake":
					var up := fmod(state_t, 0.4) < 0.2
					ar = 2.6 if up else 0.9
					al = ar
					lean = -0.2 if up else 0.45
				_:
					lean = -0.05 if state_t > BEAM_CHARGE else -0.35
					ar = 0.8
					al = 0.8
		S.STOMP:
			ar = 2.4
			al = 2.4
			lean = 0.3
		S.SUPER:
			jaw = 1.0
			ar = 2.8 if state_t < 0.5 else 1.6 + sin(state_t * 12.0) * 0.6
			al = ar
			lean = -0.35 if state_t < 0.5 else 0.1
		S.HURT:
			lean = -0.35
			jaw = 0.6
	model.arm_r = ar
	model.arm_l = al
	model.jaw = jaw
	model.lean = lean
	update_model_facing(delta)


func _make_beam(tint: Color) -> Node3D:
	var root := Node3D.new()
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = tint.lerp(Color.WHITE, 0.8)
	var core := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = BEAM_LEN
	core.mesh = cyl
	core.material_override = core_mat
	core.rotation.z = -PI / 2
	core.position.x = BEAM_LEN / 2
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.albedo_color = Color(tint, 0.6)
	var outer := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = 1.0
	cyl2.bottom_radius = 0.7
	cyl2.height = BEAM_LEN
	outer.mesh = cyl2
	outer.material_override = glow_mat
	outer.rotation.z = -PI / 2
	outer.position.x = BEAM_LEN / 2
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outer)

	var mouth := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	mouth.mesh = sph
	mouth.material_override = glow_mat
	root.add_child(mouth)

	_beam_light = OmniLight3D.new()
	_beam_light.light_color = tint
	_beam_light.omni_range = 18.0
	_beam_light.position.x = 6.0
	root.add_child(_beam_light)
	return root


## Where breath beams start, in this body's space: the model's open mouth.
func _mouth_pos() -> Vector3:
	var m := to_local(model.mouth_global())
	return Vector3(facing * maxf(absf(m.x), 1.5), m.y, 0)


func _make_barrier() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 3.6 * float(_h["size"])
	sph.height = 7.6 * float(_h["size"])
	mi.mesh = sph
	mi.position.y = 3.4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.4, 0.7, 1.0, 0.12)
	mat.rim_enabled = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- super special -----------------------------------------------------------

## Every hero has one super special (Skills.TREES[hero]["super"]). It needs
## a full super meter, which fills from damage dealt and defeated enemies.
func _start_super() -> void:
	if raging:
		_exit_rage_mode()
	super_meter = 0.0
	super_changed.emit(super_meter, SUPER_MAX)
	_super_tick = 0.0
	_super_step = 0
	_super_targets = []
	_set_state(S.SUPER)
	rumble(1.0, 1.0, SUPER_TIME)
	Game.shake(0.8)
	Game.hitstop(0.25)
	FX.shockwave(global_position, 12.0, color())
	FX.energy(global_position + Vector3(0, 5, 0), color())
	FX.light_flash(global_position + Vector3(0, 6, 0), color(), 14.0, 30.0, 0.8)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message(_super["name"], 1.6)


func _enemies_near(r: float) -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
		return not e.dead and absf(e.global_position.x - global_position.x) < r)


func _super_hit(t: Node, dmg: float, kb: Vector3) -> void:
	if deal(t, dmg, kb):
		Game.register_hit()
		FX.hit_spark(t.hit_center(), dmg)


func _state_super(delta: float) -> void:
	invuln = 0.2
	var sp := _special_power()
	var pattern: String = _super["pattern"]
	_super_tick -= delta
	match pattern:
		"mega_beam":
			if state_t >= 0.5 and state_t < SUPER_TIME - 0.2:
				_beam.visible = true
				_beam.position = _mouth_pos()
				_beam.rotation.y = 0.0 if facing > 0.0 else PI
				var f := 1.0 + sin(state_t * 70.0) * 0.15
				_beam.scale = Vector3(1.4, 3.2 * f, 3.2 * f)
				_beam_light.light_energy = 14.0 * f
				if _super_tick <= 0.0:
					_super_tick = 0.1
					Game.shake(0.25)
					var origin := global_position + Vector3(facing * 2.2, 4.85, 0)
					for t in get_tree().get_nodes_in_group("enemies"):
						if t.dead:
							continue
						var along: float = (t.hit_center().x - origin.x) * facing
						if along > -2.0 and along < BEAM_LEN * 1.4 and absf(t.hit_center().z - origin.z) < 6.0 + t.hit_radius:
							_super_hit(t, 9.0 * sp, Vector3(facing * 6.0, 1.0, 0))
					for b in get_tree().get_nodes_in_group("buildings"):
						b.try_beam(origin, facing, BEAM_LEN * 1.4, 40.0)
			else:
				_beam.visible = false
		"storm", "meteors", "scrap":
			if state_t >= 0.5 and state_t < SUPER_TIME - 0.4 and _super_tick <= 0.0:
				_super_tick = 0.16
				var foes := _enemies_near(34.0)
				var target := global_position + Vector3(facing * randf_range(4.0, 24.0), 0, randf_range(-4.0, 2.0))
				if not foes.is_empty():
					var e: Node3D = foes[_super_step % foes.size()]
					target = Vector3(e.global_position.x, 0.0, e.global_position.z) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
				_super_step += 1
				if pattern == "storm":
					FX.bolt(target + Vector3(randf_range(-4, 4), 36.0, -2.0), target + Vector3(0, 0.5, 0), color())
					FX.energy(target + Vector3(0, 1, 0), color())
					var hits := strike(target + Vector3(0, 2.0, 0), 3.5, 16.0 * sp, Vector3(4, 10, 0), "enemies", 30.0)
					for i in hits:
						Game.register_hit()
					Game.shake(0.2)
				else:
					var tint := Color(1.0, 0.45, 0.15) if pattern == "meteors" else Color(0.75, 0.7, 0.65)
					_drop_meteor(target, 0.45, 18.0 * sp, tint)
		"vortex":
			var c := global_position + Vector3(facing * 6.0, 3.0, 0)
			if state_t >= 0.4 and state_t < 2.3:
				for e in _enemies_near(30.0):
					if e is Kaiju:
						var d: Vector3 = c - e.global_position
						d.y = 0.0
						e.knock = d.normalized() * minf(d.length() * 2.0, 18.0)
						e.hitstun = 0.2
				if _super_tick <= 0.0:
					_super_tick = 0.25
					FX.shockwave(Vector3(c.x, 0.3, c.z), 9.0, color())
					FX.energy(c, color())
					strike(c, 6.0, 3.0 * sp, Vector3.ZERO, "enemies")
			elif state_t >= 2.3 and _super_step == 0:
				_super_step = 1
				var hits := strike(c, 11.0, 70.0 * sp, Vector3(22, 16, 0), "enemies", 80.0)
				for i in hits:
					Game.register_hit()
				FX.explosion(c, 2.2)
				FX.shockwave(Vector3(c.x, 0.3, c.z), 16.0, color())
				Game.shake(1.0)
				Game.hitstop(0.12)
		"freeze":
			if state_t >= 0.5 and _super_step == 0:
				_super_step = 1
				for e in _enemies_near(34.0):
					if e is Kaiju:
						e.frozen_t = 2.4
					_super_targets.append(e)
					FX.energy(e.hit_center(), Color(0.7, 0.95, 1.0))
				FX.shockwave(global_position, 30.0, Color(0.7, 0.95, 1.0))
				Game.shake(0.5)
			elif state_t >= 2.6 and _super_step == 1:
				_super_step = 2
				for e in _super_targets:
					if is_instance_valid(e) and not e.dead:
						_super_hit(e, 75.0 * sp, Vector3(facing * 10.0, 14.0, 0))
						FX.debris_burst(e.hit_center(), 1.4)
						FX.shockwave(e.global_position, 5.0, Color(0.8, 1.0, 1.0))
				Game.shake(0.9)
				Game.hitstop(0.12)
		"frenzy":
			if state_t >= 0.4 and _super_step < 9 and _super_tick <= 0.0:
				_super_tick = 0.28
				var foes := _enemies_near(34.0)
				_super_step += 1
				if foes.is_empty():
					return
				var e: Node3D = foes[_super_step % foes.size()]
				var side := -1.0 if _super_step % 2 == 0 else 1.0
				FX.smoke(global_position + Vector3(0, 2, 0), 1.0, Color(0.1, 0.05, 0.1))
				global_position = Vector3(e.global_position.x - side * 3.2, global_position.y, clampf(e.global_position.z, z_min, z_max))
				facing = side
				model.spin = TAU * 0.5
				_super_hit(e, 20.0 * sp, Vector3(side * 8.0, 6.0, 0))
				FX.bolt(global_position + Vector3(-side * 2.0, 5.0, 0), e.hit_center() + Vector3(side * 2.0, -1.0, 0), color())
				Game.shake(0.3)
		"rift", "wave", "supernova":
			if state_t >= 0.5 and _super_step < 12 and _super_tick <= 0.0:
				_super_tick = 0.15
				_super_step += 1
				var k := _super_step
				match pattern:
					"rift":
						for dir in [-1.0, 1.0]:
							var p := Vector3(global_position.x + dir * k * 3.2, 1.5, global_position.z)
							strike(p, 3.4, 12.0 * sp, Vector3(4, 16, 0), "enemies", 40.0)
							FX.debris_burst(p, 1.3)
							FX.dust(p, 1.2)
							FX.shockwave(Vector3(p.x, 0, p.z), 3.0, color())
						Game.shake(0.3)
					"wave":
						var p := Vector3(global_position.x + facing * (k * 3.5 - 6.0), 2.5, global_position.z - 1.0)
						for e in get_tree().get_nodes_in_group("enemies"):
							if not e.dead and absf(e.global_position.x - p.x) < 3.5 + e.hit_radius:
								_super_hit(e, 13.0 * sp, Vector3(facing * 18.0, 6.0, 0))
						for b in get_tree().get_nodes_in_group("buildings"):
							b.try_hit(Vector3(p.x, 2.0, -7.0), 4.0, 30.0)
						FX.smoke(p, 1.6, Color(0.5, 0.75, 0.9))
						FX.shockwave(Vector3(p.x, 0.2, p.z), 6.0, color())
						Game.shake(0.25)
					"supernova":
						if k % 4 == 1:
							var c := global_position + Vector3(0, 3.0, 0)
							var hits := strike(c, 18.0, 35.0 * sp, Vector3(18, 12, 0), "enemies", 60.0)
							for i in hits:
								Game.register_hit()
							FX.shockwave(global_position, 18.0, color())
							FX.explosion(c, 1.6)
							FX.light_flash(c, color(), 20.0, 40.0, 0.5)
							Game.shake(0.8)
	if state_t >= SUPER_TIME:
		_beam.visible = false
		_beam.scale = Vector3.ONE
		_set_state(S.FREE)
