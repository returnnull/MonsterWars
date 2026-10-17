class_name Player
extends Kaiju
## A playable kaiju: light and heavy combos (see ATTACKS), jump attacks,
## dodge,
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
## Untouchable this long after a super or rage attack, so enemies that
## waited it out can't punish the hero the moment it ends.
const AFTER_SUPER_INVULN := 0.8
## Rage works like mana: dealing and taking damage fills the bar, and rage
## skills spend it. Hold special and press another button to use one; tap
## special on its own to switch rage mode on or off.
##   strike  special + light: lunge forward with a heavy blow
##   roar    special + jump:  knock enemies back and share rage with allies
##   attack  special + heavy: the hero's rage attack (beam, nova or quake)
##   mode    special tapped:  rage mode, drains RAGE_MODE_DRAIN per second
const RAGE_SKILLS := {"strike": 25.0, "roar": 35.0, "attack": 50.0, "mode": 30.0}
const RAGE_MODE_DRAIN := 10.0
## In rage mode attacks play this much faster and turn into the hero's own
## element (see RageStyle): light spits the hero's shot (fire1-3, see
## Fireball) and heavy stops to pour the hero's breath ahead (flame, see
## _flame_tick) that does the most damage. Weapon swings burst into the
## element for FIRE_DMG of their damage (see _fire_burst).
const RAGE_ATTACK_SPEED := 1.25
const FIRE_DMG := 0.6
## Rage attacks shake the screen this much of what other hits do: they come
## fast and often (fireballs, breath ticks), so full shake gets tiring.
const RAGE_SHAKE := 0.25
## The heavy flame stream: how far it reaches, how wide it gets at the end,
## and how often it hurts what it touches.
const FLAME_LEN := 12.0
const FLAME_WIDTH := 2.4
const FLAME_TICK := 0.1
## Holding heavy keeps the flame pouring past its normal length (the
## "stream" of the flame attack) up to FLAME_MAX seconds, burning
## FLAME_DRAIN extra rage per second on top of the rage mode drain.
const FLAME_MAX := 4.0
const FLAME_DRAIN := 8.0
## A special press held longer than this without a combo does nothing.
const SPECIAL_TAP := 0.45
## Combos. "next" is the attack a light press chains into, "next_h" the one
## a heavy press chains into, and "combo" names a combo special (shown over
## the kaiju when it starts):
##   (every hero has its own name and element for each combo, see HeroMoves)
##   light light light  TAIL SPIN    spins round and knocks back all around
##   light light heavy  KAIJU RUSH   charges forward, ramming what's in the way
##   heavy heavy heavy  TITAN CRUSH  huge slam with shockwaves marching ahead
##   jump + heavy       GROUND POUND drops onto the street, hurts all around
##   jump + light       SKY CLAW     slashes up and sends a claw wave that homes
##                                   in on aircraft (does AIR_BONUS to them)
const AIR_MOVES := 2
const AIR_BONUS := 2.5
## Anti-spam: after an attack (or a whole combo) ends, light and heavy do
## nothing for this many seconds; a press in that time waits in the buffer.
## Chaining into the next hit of a combo is not slowed down, but finishers
## leave the kaiju open for longer. Rage skills have their own cooldown
## (rage strike, roar and the rage attack beam/nova/quake).
const ATTACK_RECOVERY := {
	"light1": 0.25, "light2": 0.25, "light3": 0.6, "heavy": 0.4, "heavy2": 0.45, "heavy3": 1.0,
	"rush": 0.8, "sky_claw": 0.0, "swing1": 0.3, "swing2": 0.5, "throw": 0.4,
	"fire1": 0.35, "fire2": 0.35, "fire3": 0.8, "flame": 1.0,
	"rage_strike": 0.6, "roar": 0.8, "stomp": 0.45, "rage_attack": 1.0,
}
## Takeoff crouch before the kaiju leaves the ground.
const JUMP_SQUAT := 0.07

const ATTACKS := {
	"light1": {"dur": 0.30, "active": 0.11, "dmg": 7.0, "kb": Vector3(4, 0, 0), "reach": 2.6, "radius": 2.3,
		"pose": "jab_r", "shake": 0.12, "bdmg": 10.0, "next": "light2", "next_h": "heavy"},
	"light2": {"dur": 0.30, "active": 0.11, "dmg": 7.0, "kb": Vector3(4, 0, 0), "reach": 2.6, "radius": 2.3,
		"pose": "jab_l", "shake": 0.12, "bdmg": 10.0, "next": "light3", "next_h": "rush"},
	"light3": {"dur": 0.55, "active": 0.24, "dmg": 15.0, "kb": Vector3(15, 8, 0), "reach": 0.0, "radius": 5.2,
		"pose": "spin", "shake": 0.35, "bdmg": 18.0, "next": "", "next_h": "heavy", "combo": "TAIL SPIN"},
	"heavy": {"dur": 0.72, "active": 0.38, "dmg": 22.0, "kb": Vector3(14, 10, 0), "reach": 3.0, "radius": 3.0,
		"pose": "slam", "shake": 0.55, "bdmg": 45.0, "next": "", "next_h": "heavy2"},
	"heavy2": {"dur": 0.66, "active": 0.32, "dmg": 24.0, "kb": Vector3(10, 9, 0), "reach": 3.2, "radius": 3.2,
		"pose": "slam", "shake": 0.55, "bdmg": 45.0, "next": "", "next_h": "heavy3"},
	# Combo specials. "rush" lunges and rams everything it runs into on the way.
	"rush": {"dur": 0.62, "active": 0.32, "dmg": 26.0, "kb": Vector3(24, 10, 0), "reach": 2.6, "radius": 3.2,
		"pose": "rush", "shake": 0.55, "bdmg": 60.0, "next": "", "lunge": 26.0, "rush": true, "combo": "KAIJU RUSH"},
	"heavy3": {"dur": 1.0, "active": 0.5, "dmg": 38.0, "kb": Vector3(18, 18, 0), "reach": 3.4, "radius": 4.4,
		"pose": "crush", "shake": 0.9, "bdmg": 90.0, "next": "", "lunge": 2.0, "combo": "TITAN CRUSH"},
	"sky_claw": {"dur": 0.42, "active": 0.12, "dmg": 14.0, "kb": Vector3(6, 12, 0), "reach": 1.8, "radius": 4.2,
		"pose": "claw_up", "shake": 0.25, "bdmg": 15.0, "next": "", "lunge": 2.0, "combo": "SKY CLAW"},
	# With a building piece in hand (damage is multiplied by the weapon).
	"swing1": {"dur": 0.42, "active": 0.16, "dmg": 9.0, "kb": Vector3(10, 4, 0), "reach": 3.4, "radius": 2.9,
		"pose": "swing", "shake": 0.25, "bdmg": 30.0, "next": "swing2", "next_h": "heavy"},
	"swing2": {"dur": 0.5, "active": 0.18, "dmg": 11.0, "kb": Vector3(18, 9, 0), "reach": 3.4, "radius": 3.1,
		"pose": "swing", "shake": 0.35, "bdmg": 30.0, "next": "", "next_h": "heavy"},
	"throw": {"dur": 0.45, "active": 0.2, "dmg": 0.0, "kb": Vector3.ZERO, "reach": 0.0, "radius": 0.0,
		"pose": "throw", "shake": 0.0, "bdmg": 0.0, "next": ""},
	# Rage skills ("rage": true): boosted by Focus, don't refill rage themselves.
	"rage_strike": {"dur": 0.6, "active": 0.22, "dmg": 30.0, "kb": Vector3(24, 11, 0), "reach": 3.2, "radius": 3.6,
		"pose": "jab_r", "shake": 0.5, "bdmg": 60.0, "next": "", "lunge": 30.0, "rage": true},
	"roar": {"dur": 0.75, "active": 0.25, "dmg": 12.0, "kb": Vector3(18, 9, 0), "reach": 0.0, "radius": 9.0,
		"pose": "roar", "shake": 0.45, "bdmg": 10.0, "next": "", "lunge": 0.0, "rage": true},
	# Rage mode fire. "shot" spits a Fireball of that size for "dmg"; "stream"
	# sprays flame for that long, hurting for "dmg" every FLAME_TICK.
	"fire1": {"dur": 0.34, "active": 0.12, "dmg": 10.0, "kb": Vector3.ZERO, "reach": 0.0, "radius": 0.0,
		"pose": "spit_r", "shake": 0.0, "bdmg": 0.0, "next": "fire2", "next_h": "flame", "lunge": 1.0, "shot": 1.0},
	"fire2": {"dur": 0.34, "active": 0.12, "dmg": 10.0, "kb": Vector3.ZERO, "reach": 0.0, "radius": 0.0,
		"pose": "spit_l", "shake": 0.0, "bdmg": 0.0, "next": "fire3", "next_h": "flame", "lunge": 1.0, "shot": 1.0},
	"fire3": {"dur": 0.55, "active": 0.2, "dmg": 18.0, "kb": Vector3.ZERO, "reach": 0.0, "radius": 0.0,
		"pose": "spit", "shake": 0.0, "bdmg": 0.0, "next": "", "next_h": "flame", "lunge": 0.0, "shot": 1.7},
	"flame": {"dur": 1.5, "active": 0.28, "dmg": 5.5, "kb": Vector3.ZERO, "reach": 0.0, "radius": 0.0,
		"pose": "flame", "shake": 0.0, "bdmg": 0.0, "next": "", "lunge": 0.0, "stream": 1.0},
}
const GRAB_RANGE := 4.5
## Button pressed with special held -> buffered rage skill.
const RAGE_BUTTONS := {"light": "rage_strike", "jump": "rage_roar", "heavy": "rage_attack"}
## A downed player gets back up after a teammate has stood next to them for
## REVIVE_TIME seconds (two helpers do it twice as fast). Progress drains
## slowly while nobody is close.
const REVIVE_RANGE := 4.5
const REVIVE_TIME := 3.0
const REVIVE_HP := 0.4

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
## How often each combo special (ATTACKS with "combo") was used this stage.
var combo_uses := {}
var atk: Dictionary = {}
var _atk_name := ""
var _atk_done := false
## Time left before light/heavy (and before rage skills) work again.
var _attack_cd := 0.0
var _rage_cd := 0.0
## Takeoff crouch time left (> 0 while crouching to jump), and how fast the
## kaiju was falling just before it landed.
var _jump_squat := 0.0
var _fall_speed := 0.0
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
var revive_progress := 0.0
var _revive_label: Label3D
var _revive_ring: MeshInstance3D
var _h: Dictionary
var _special := "beam"
var _special_step := 0
var level := 1
## Learned abilities, {kind: value} (see Skills.KINDS).
var sk := {}
var _kill_rush_t := 0.0
var _arcing := false
var raging := false
var super_meter := 0.0
var _special_time := BEAM_TIME
var _super := {}
var _super_tick := 0.0
var _super_step := 0
var _super_targets: Array = []
## Picked super tree effects ({effect: true}, see SuperTree), the length of
## the running super, one-shot events already set off in it, and whether a
## hit being dealt now comes from the super (for the riders).
var sup := {}
var _super_len := SUPER_TIME
var _super_once := {}
var _super_hits := 0
## Per-super effect nodes (ice blocks of ABSOLUTE ZERO).
var _super_fx = null
var _super_ice: Array = []
var _barrier_up := false
var _barrier_t := 0.0
var _barrier_fx: MeshInstance3D
var _second_wind_used := false
var _aura_t := 0.0
## Building piece in hand ("" for none, else a Weapon.KINDS key) and swings left.
var weapon := ""
var weapon_uses := 0
var _held: Node3D
## This hero's rage attacks (RageStyle.STYLES entry).
var rage_style: Dictionary
## How this hero fights: pace, reach and the names of its combos (HeroMoves).
var moves: Dictionary
var _rush_fx_t := 0.0
## The heavy flame stream while it burns (see _flame_tick).
var _flame_fx: GPUParticles3D
var _flame_ticks := 0
## How long the current flame pours (grows while heavy is held).
var _stream_len := 0.0
## Jump attacks used since leaving the ground, and who a rush already rammed.
var _air_moves := 0
var _rush_hit: Array = []


func _ready() -> void:
	_h = Content.hero(hero)
	level = Game.hero_level(hero)
	sk = Skills.mods(hero, Game.hero_skills[hero])
	_super = Skills.super_def(hero)
	sup = SuperTree.mods(hero, Game.hero_supers[hero], level)
	rage_style = RageStyle.for_hero(hero)
	moves = HeroMoves.for_hero(hero)
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
	model = GlbKaijuModel.for_hero(_h, self)
	model.scale = Vector3.ONE * _h["size"]
	Cosmetics.dress(model, Game.outfit(hero))
	hit_radius = 1.6 * _h["size"]
	_beam = _make_beam(_h["accent"])
	add_child(_beam)
	_beam.visible = false
	_barrier_fx = _make_barrier()
	_barrier_fx.visible = _barrier_up
	add_child(_barrier_fx)
	_make_revive_marker()
	Game.players.append(self)


func _m(kind: String) -> float:
	return float(sk.get(kind, 0.0))


func _has(kind: String) -> bool:
	return sk.has(kind)


## Damage multiplier from rage mode and Berserk.
func _boost() -> float:
	var b := 1.3 if raging else 1.0
	if _kill_rush_t > 0.0:
		b *= 1.0 + _m("killrush") / 100.0
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


## Brings a downed player back: between waves at half health, or by a
## teammate mid-wave (REVIVE_HP).
func revive(hp_frac: float = 0.5) -> void:
	if not dead:
		return
	if _death_tween:
		_death_tween.kill()
	dead = false
	revive_progress = 0.0
	_revive_label.visible = false
	_revive_ring.visible = false
	hp = max_hp * hp_frac
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
	amount *= 1.0 + _m("radiance") / 100.0
	super_meter = minf(super_meter + amount, SUPER_MAX)
	super_changed.emit(super_meter, SUPER_MAX)
	if super_meter >= SUPER_MAX and not was_full:
		FX.energy(global_position + Vector3(0, 4, 0), Color(0.8, 0.5, 1.0))


## Called by the level for every defeated enemy.
func on_enemy_killed() -> void:
	add_super(4.0)
	if _m("rampage") > 0.0:
		add_rage(_m("rampage"))
	if _m("killrush") > 0.0:
		_kill_rush_t = 5.0
	if _m("salvage") > 0.0:
		heal(max_hp * _m("salvage") / 100.0)
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
	Game.run["rage"] = true
	if _m("tide_heal") > 0.0:
		heal(max_hp * _m("tide_heal") / 100.0)
		FX.energy(global_position + Vector3(0, 3, 0), Color(0.4, 0.8, 1.0))
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
	Game.track("roars")
	FX.shockwave(global_position, 9.0, color())
	FX.shockwave(global_position, 5.0, rage_style["glow"])
	RageFX.burst(global_position + Vector3(0, 2.5, 0), 6.0, rage_style)
	rage_shake(0.4)
	for p in Game.living_players():
		if p != self and p.global_position.distance_to(global_position) < 16.0:
			p.add_rage(15.0)
			FX.energy(p.global_position + Vector3(0, 4, 0), color())


## Screen shake for rage attacks, scaled down by RAGE_SHAKE.
static func rage_shake(amount: float) -> void:
	Game.shake(amount * RAGE_SHAKE)


## Rage mode: the kaiju glows, hits 30% harder, attacks 25% faster with
## fire (light spits fireballs, heavy sprays flame), moves 20% faster, takes
## less damage and can't be staggered. It drains rage every second and ends
## when the bar is empty or special is tapped again.
func _enter_rage_mode() -> void:
	raging = true
	Game.track("rage_modes")
	rumble(0.6, 0.8, 0.4)
	_rage_announced = false
	rage_shake(0.5)
	Game.hitstop(0.12)
	FX.shockwave(global_position, 8.0, color())
	FX.shockwave(global_position, 5.0, rage_style["glow"] * 1.6)
	FX.energy(global_position + Vector3(0, 4, 0), color())
	RageFX.burst(global_position + Vector3(0, 2.5, 0), 4.0, rage_style)
	FX.callout(global_position + Vector3(0, 7.5, 0), rage_style["mode"], rage_style["glow"])
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and Game.players.size() == 1:
		hud.show_message("RAGE MODE!", 1.2)
	if _has("meltdown"):
		FX.shockwave(global_position, 11.0, Color(0.5, 1.0, 0.6))
		FX.light_flash(global_position + Vector3(0, 3, 0), Color(0.5, 1.0, 0.6), 16.0, 12.0, 0.3)
		strike(global_position + Vector3(0, 2.5, 0), 10.0, 4.0 * _special_power(), Vector3(0, 9, 0), "enemies", 2.0 * power)


func _exit_rage_mode() -> void:
	raging = false
	rage_changed.emit(rage, rage_max)


func _physics_process(delta: float) -> void:
	state_t += delta * (RAGE_ATTACK_SPEED if raging and state == S.ATTACK and not atk.get("rage", false) else 1.0)
	invuln = maxf(invuln - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_rage_cd = maxf(_rage_cd - delta, 0.0)
	if not is_on_floor():
		_fall_speed = maxf(-velocity.y, 0.0)
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
			_tick_revive(delta)
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
	_kill_rush_t = maxf(_kill_rush_t - delta, 0.0)
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
	if _flame_fx:
		_stop_flame()
	_jump_squat = 0.0
	# Leaving an attack (not chaining into the next one) starts its recovery.
	if state == S.ATTACK and s != S.ATTACK:
		if atk.get("rage", false):
			_rage_cd = ATTACK_RECOVERY.get(_atk_name, 0.5)
		else:
			_attack_cd = ATTACK_RECOVERY.get(_atk_name, 0.2)
	elif state == S.BEAM and s != S.BEAM:
		_rage_cd = ATTACK_RECOVERY["rage_attack"]
		_beam.visible = false
	elif state == S.STOMP and s != S.STOMP:
		_attack_cd = ATTACK_RECOVERY["stomp"]
	if (state == S.SUPER or state == S.BEAM) and s != state:
		invuln = maxf(invuln, AFTER_SUPER_INVULN)
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
	# In rage mode, holding light keeps spitting fireballs (each one still
	# waits for the attack before it and its recovery).
	if raging and _buffered == "" and _special_held < 0.0 and Input.is_action_pressed(_act("light")):
		_buffered = "light"
		_buffer_t = 0.05


func _consume() -> String:
	var b := _buffered
	_buffered = ""
	return b


func _state_free(input: Vector2) -> Vector3:
	face_toward(input.x)
	if _jump_squat > 0.0:
		_jump_squat -= get_physics_process_delta_time()
		if _jump_squat <= 0.0 and is_on_floor():
			velocity.y = JUMP_VEL
			FX.dust(global_position, 0.9)
			rumble(0.15, 0.1, 0.08)
	match _buffered:
		"jump":
			if is_on_floor() and _jump_squat <= 0.0:
				_consume()
				_jump_squat = JUMP_SQUAT
				FX.dust(global_position, 0.5)
				Game.track("jumps")
		"light", "heavy":
			# While recovering from an attack (or crouching to jump) the press
			# waits in the buffer instead of starting another attack.
			if _jump_squat > 0.0 or (_attack_cd > 0.0 and is_on_floor()):
				pass
			else:
				var b := _consume()
				if not is_on_floor():
					if b == "heavy":
						_start_stomp()
					elif _air_moves < AIR_MOVES:
						_air_moves += 1
						velocity.y = maxf(velocity.y, 7.0)
						_start_attack("sky_claw")
				elif raging:
					# Rage mode always breathes fire, even with a weapon in hand.
					_start_attack("fire1" if b == "light" else "flame")
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
				Game.track("dodges")
				_dodge_cd = 0.6 * (1.0 - minf(_m("swift"), 40.0) / 100.0)
				FX.dust(global_position, 0.6)
				if _m("afterimage") > 0.0:
					var hits := strike(global_position + Vector3(0, 2.5, 0), 4.5, _m("afterimage") * power * _boost(), Vector3(8, 6, 0), "enemies")
					FX.energy(global_position + Vector3(0, 2.5, 0), color())
					FX.shockwave(global_position, 4.5, color())
					add_rage(3.0 * hits)
				_set_state(S.DODGE)
		"rage_strike", "rage_roar", "rage_attack":
			# Rage skills wait out their own cooldown in the buffer too.
			if _rage_cd > 0.0:
				pass
			elif _use_rage_skill(_consume().trim_prefix("rage_")) and state != S.FREE:
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
	if not atk.get("rage", false) and not atk.has("shot") and not atk.has("stream") \
			and not atk["pose"] in ["swing", "throw"]:
		atk = HeroMoves.tune(atk, hero)
	_atk_name = attack_name
	_rush_fx_t = 0.0
	_atk_done = false
	_stream_len = float(atk.get("stream", 0.0))
	if atk.has("stream"):
		# Wind-up: the mouth glows and sucks in the element before the breath.
		RageFX.charge(to_global(_mouth_pos()) + Vector3(facing * 0.6, 0, 0), rage_style, float(atk["active"]) / RAGE_ATTACK_SPEED)
	_rush_hit.clear()
	_set_state(S.ATTACK)
	if atk.has("combo"):
		combo_uses[attack_name] = int(combo_uses.get(attack_name, 0)) + 1
		FX.callout(global_position + Vector3(0, 7.5, 0), HeroMoves.combo_name(hero, attack_name), rage_style["glow"])


func _state_attack() -> Vector3:
	var active: float = atk["active"]
	if not _atk_done and state_t >= active:
		_atk_done = true
		_do_hit()
	# The flame stream holds the kaiju in place until it has burnt out.
	if atk.has("rush") and state_t < active:
		_rush_tick()
	var streaming: bool = atk.has("stream") and state_t < active + _stream_len
	if streaming and state_t >= active:
		# Held heavy keeps the flame going while there is rage to burn.
		if Input.is_action_pressed(_act("heavy")) and raging and _stream_len < FLAME_MAX \
				and state_t + FLAME_TICK > active + _stream_len:
			_stream_len = minf(_stream_len + FLAME_TICK, FLAME_MAX)
		if state_t > active + float(atk["stream"]):
			rage = maxf(rage - FLAME_DRAIN * get_physics_process_delta_time(), 0.0)
			rage_changed.emit(rage, rage_max)
		_flame_update()
	elif _flame_fx:
		_stop_flame()
	if state_t >= active and not streaming:
		var next: String = atk["next"]
		var armed := weapon != "" and not raging
		if _buffered == "light" and next != "" and (armed or atk["pose"] != "swing"):
			_consume()
			_start_attack(next)
		elif _buffered == "heavy" and atk.get("next_h", "") != "":
			_consume()
			_start_attack("throw" if armed else ("flame" if raging else String(atk["next_h"])))
		elif _buffered.begins_with("rage_") and not atk.get("rage", false):
			# Rage skills cut the recovery of a normal attack short.
			_set_state(S.FREE)
		elif state_t >= float(atk["dur"]) + _stream_len - float(atk.get("stream", 0.0)):
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
	Game.track("grabs")
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
	if raging:
		var fire_hits := _fire_burst(reach_c, atk["radius"], dmg, atk["next"] == "")
		for i in fire_hits:
			Game.register_hit()
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
	Game.track("throws")


func _do_hit() -> void:
	if atk["pose"] == "throw":
		if weapon != "":
			_throw_weapon()
		return
	if atk["pose"] == "swing":
		if weapon != "":
			_swing_weapon(global_position)
		return
	if atk.has("shot"):
		_spit_fireball(float(atk["shot"]), atk["dmg"] * power * _boost())
		return
	if atk.has("stream"):
		_start_flame()
		return
	if atk["pose"] == "claw_up":
		_sky_claw()
		return
	var reach: float = atk["reach"]
	var center := global_position + Vector3(facing * reach, 3.2, 0)
	if atk["pose"] == "spin" or atk["pose"] == "roar":
		center = global_position + Vector3(0, 2.6, 0)
	var rage_skill: bool = atk.get("rage", false)
	var dmg: float = atk["dmg"] * (_special_power() if rage_skill else power * _boost())
	var finisher: bool = atk["pose"] in ["spin", "slam", "crush", "rush"]
	# Fire goes first so the punch's own knockback wins. Fire hits count as
	# hits but give no rage, so rage mode can't feed itself.
	var fire_hits := _fire_burst(center, atk["radius"], dmg, finisher) if raging and not rage_skill else 0
	var hits := strike(center, atk["radius"], dmg, atk["kb"], "enemies", atk["bdmg"] * power * _bdmg())
	if atk["pose"] == "spin":
		# The hero's element bursts up in a ring all around it.
		FX.shockwave(global_position, atk["radius"] + 1.0, rage_style["glow"])
		_erupt_ring(global_position, atk["radius"] * 0.9, 6, 0.7)
	if atk["pose"] == "rush":
		FX.shockwave(center - Vector3(0, 3.0, 0), 4.5, rage_style["glow"])
		FX.dust(center - Vector3(0, 3.0, 0), 1.2)
		FX.debris_burst(center, 0.8)
		RageFX.burst(center, 3.5, rage_style)
	if atk["pose"] == "crush":
		var ground := global_position + Vector3(facing * (atk["reach"] + 0.4), 0, 0)
		FX.shockwave(ground, 8.0, rage_style["glow"])
		FX.dust(ground, 2.0)
		FX.debris_burst(ground + Vector3(0, 1, 0), 1.4)
		_erupt(ground, 1.3)
		rumble(0.6, 0.9, 0.3)
		_eruption_line(global_position.x, facing, 5, 16.0 * power * _boost() * float(moves["dmg"]))
	if atk["pose"] == "slam":
		var ground := global_position + Vector3(facing * atk["reach"], 0, 0)
		FX.shockwave(ground, 5.0, rage_style["glow"])
		FX.dust(ground, 1.2)
		_erupt(ground, 0.75)
		Game.shake(0.3)
		if _m("quake_slam") > 0.0:
			_eruption_line(global_position.x, facing, 4, _m("quake_slam") * power * _boost())
	if atk["pose"] == "spin" and _has("aftershock"):
		var c := global_position + Vector3(0, 3.0, 0)
		hits += strike(c, 7.5, 16.0 * power * _boost(), Vector3(12, 9, 0), "enemies", 20.0 * power)
		FX.shockwave(global_position, 7.5, color())
		FX.energy(c, color())
	if finisher and not rage_skill and not raging:
		# Combo finishers put the hero's element on what they hit (burn,
		# shock, poison, frost, leech...).
		for t in _targets_near(center, atk["radius"]):
			_rage_effect(t, dmg * 0.5, false)
	elif hits > 0 and not rage_skill and not raging:
		RageFX.pop(center, rage_style, 0.4)
	if finisher and hits > 0 and _m("shock") > 0.0:
		_chain_lightning(center, _m("shock") * power * _boost())
	if atk["pose"] == "jab_r" and rage_skill:
		# Rage strike: the blow bursts into the hero's element.
		FX.shockwave(center - Vector3(0, 3.2, 0), 4.0, color())
		RageFX.burst(center, atk["radius"], rage_style)
		for t in _targets_near(center, atk["radius"]):
			_rage_effect(t, dmg, false)
		FX.dust(global_position, 1.0)
	if hits + fire_hits > 0:
		rumble(0.3, 0.15 if dmg < 15.0 else 0.5, 0.1)
		if rage_skill or raging:
			rage_shake(atk["shake"])
		else:
			Game.shake(atk["shake"])
		Game.hitstop(0.05 if dmg < 15.0 else 0.09)
		for i in hits + fire_hits:
			Game.register_hit()
		if not rage_skill:
			add_rage(dmg * 0.45 * hits)


## Rage mode turns every normal attack into a blast of the hero's element:
## it bursts around the point of impact, hurts every enemy and building
## close by and puts the hero's rage effect on them. Finishers (spin, slam,
## last weapon swing) make a bigger blast.
func _fire_burst(center: Vector3, radius: float, dmg: float, finisher: bool) -> int:
	var r := radius * (1.6 if finisher else 1.3) + 1.5
	var c := Vector3(center.x, maxf(center.y - 0.8, 1.6), center.z)
	var targets: Array = get_tree().get_nodes_in_group("enemies").filter(func(t) -> bool:
		return not t.dead and t.hit_center().distance_to(c) <= r + t.hit_radius)
	var hits := strike(c, r, dmg * FIRE_DMG, Vector3(6, 6, 0), "enemies", dmg * FIRE_DMG * _bdmg())
	for t in targets:
		_rage_effect(t, dmg * FIRE_DMG, false)
	RageFX.burst(c, r, rage_style)
	if finisher:
		rage_shake(0.25)
	return hits


## What the hero's element does to an enemy it hits, on top of the damage
## (RageStyle "effect"). `heavy` is a tick of the breath.
func _rage_effect(t: Node, dmg: float, heavy: bool) -> void:
	if not is_instance_valid(t) or t.dead:
		return
	match String(rage_style["effect"]):
		"burn":
			if t.has_method("apply_burn"):
				t.apply_burn(dmg * (0.4 if heavy else 0.25), 2.5)
		"poison":
			# Poison eats away for longer than fire and makes them sluggish.
			if t.has_method("apply_burn"):
				t.apply_burn(dmg * (0.45 if heavy else 0.3), 4.5)
			if t.has_method("apply_slow"):
				t.apply_slow(0.3, 2.0)
		"frost":
			if t.has_method("apply_slow"):
				t.apply_slow(0.55, 2.2)
			# The breath freezes what it keeps blowing on.
			if heavy and "frozen_t" in t and _flame_ticks % 6 == 0:
				t.frozen_t = maxf(t.frozen_t, 0.8)
				RageFX.ice(Vector3(t.global_position.x, 0, t.global_position.z), rage_style, 1.3)
		"leech":
			heal(dmg * 0.25)
		"shock":
			if "hitstun" in t:
				t.hitstun = maxf(t.hitstun, 0.15)
		"shred":
			if t.has_method("apply_burn"):
				t.apply_burn(dmg * 0.15, 1.5)


## VOLTRA's ball lightning: bolts jump from the burst on to the two closest
## enemies it didn't already hit.
func _chain_shock(from: Node, dmg: float, skip: Array) -> void:
	var src: Vector3 = from.hit_center()
	var others: Array = get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
		return not e.dead and not e in skip and e.hit_center().distance_to(src) < 12.0)
	others.sort_custom(func(a, b) -> bool:
		return a.hit_center().distance_to(src) < b.hit_center().distance_to(src))
	for e in others.slice(0, 2):
		FX.bolt(src, e.hit_center(), rage_style["glow"])
		if deal(e, dmg, Vector3(facing * 3.0, 2.0, 0)):
			Game.register_hit()
			_rage_effect(e, dmg, false)
		src = e.hit_center()


## Light attack in rage mode: the hero's shot flies from the mouth (see
## Fireball). RUSTFANG's spray fires three smaller ones side by side.
func _spit_fireball(size: float, dmg: float) -> void:
	var mouth := to_global(_mouth_pos()) + Vector3(facing * 0.8, 0, 0)
	var spread: bool = rage_style["move"] == "spread"
	for z in ([-1.3, 0.0, 1.3] if spread else [0.0]):
		var fb := Fireball.new()
		fb.shooter = self
		fb.style = rage_style
		fb.dir = facing
		fb.damage = dmg * (0.45 if spread else 1.0)
		fb.size = size * (0.7 if spread else 1.0)
		fb.splash = 2.4 * size * (0.7 if spread else 1.0)
		get_parent().add_child(fb)
		fb.global_position = mouth + Vector3(-absf(z) * facing * 0.6, absf(z) * 0.3, z)
	RageFX.muzzle(mouth, Vector3(facing, 0, 0), rage_style, size)
	Game.track("fireballs")
	rumble(0.25, 0.1 * size, 0.08)
	if size > 1.2:
		rage_shake(0.15)
		FX.callout(global_position + Vector3(0, 7.5, 0), rage_style["light"], rage_style["glow"])


## Heavy attack in rage mode: the kaiju plants its feet and pours out its
## breath (see RageFX.jet).
func _start_flame() -> void:
	_flame_ticks = 0
	_flame_fx = RageFX.jet(rage_style, Vector3(facing, -0.2, 0).normalized())
	var mouth := to_global(_mouth_pos())
	RageFX.muzzle(mouth, Vector3(facing, 0, 0), rage_style, 1.6)
	FX.shockwave(global_position + Vector3(facing * 1.5, 0, 0), 4.0, rage_style["glow"] * 1.4)
	FX.callout(global_position + Vector3(0, 7.5, 0), rage_style["heavy"], rage_style["glow"])
	rage_shake(0.35)
	rumble(0.5, 0.6, 0.15)


## Keeps the breath at the mouth and hurts what it touches every FLAME_TICK.
func _flame_update() -> void:
	var mouth := to_global(_mouth_pos()) + Vector3(facing * 0.6, 0, 0)
	RageFX.jet_update(_flame_fx, rage_style, mouth, facing, state_t)
	var ticks := int(_stream_len / FLAME_TICK + 0.001)
	while _flame_ticks < ticks and state_t >= float(atk["active"]) + _flame_ticks * FLAME_TICK:
		_flame_ticks += 1
		_flame_tick(mouth)
	rumble(0.35, 0.2, 0.1)


## One burst of breath damage along the stream: it widens and dips with
## distance from the mouth, like the breath does.
func _flame_tick(mouth: Vector3) -> void:
	var dmg: float = atk["dmg"] * power * _boost()
	var effect: String = rage_style["effect"]
	var kb := Vector3(facing * 1.5, 0.4, 0)
	if effect == "push":
		kb = Vector3(facing * 9.0, 1.0, 0)
	elif effect == "quake" and _flame_ticks % 4 == 0:
		kb = Vector3(facing * 3.0, 9.0, 0)
	var hit: Array = []
	for t in get_tree().get_nodes_in_group("enemies"):
		if t.dead:
			continue
		var tc: Vector3 = t.hit_center()
		var r: float = t.hit_radius
		var along := (tc.x - mouth.x) * facing
		var k := clampf(along / FLAME_LEN, 0.0, 1.0)
		var flame_y := mouth.y - along * 0.22
		if along > -r - 1.0 and along < FLAME_LEN + r and absf(tc.z - mouth.z) < 0.8 + FLAME_WIDTH * k + r \
				and absf(tc.y - flame_y) < 2.2 + FLAME_WIDTH * k + r:
			if deal(t, dmg, kb):
				hit.append(t)
				_rage_effect(t, dmg, true)
				if _flame_ticks % 3 == 1:
					RageFX.muzzle(Vector3(tc.x - facing * r, tc.y, tc.z), Vector3(0, 1, 0), rage_style, 0.7)
	if _flame_ticks % 2 == 1:
		var bmul := 2.0 if effect in ["quake", "shred"] else 1.0
		for b in get_tree().get_nodes_in_group("buildings"):
			b.try_beam(Vector3(mouth.x, mouth.y - 2.0, mouth.z), facing, FLAME_LEN, dmg * 2.0 * _bdmg() * bmul)
	RageFX.jet_tick(rage_style, mouth, facing, FLAME_LEN, _flame_ticks, hit)
	# Breath hits count for the combo but, like all rage attacks, give no rage.
	for i in hit.size():
		Game.register_hit()
	rage_shake(0.1 if not hit.is_empty() else 0.05)


func _stop_flame() -> void:
	FX.stop_stream(_flame_fx)
	_flame_fx = null


## KAIJU RUSH: rams every enemy the charge runs into once on the way and
## carries it along, so the final blow hits them all.
func _rush_tick() -> void:
	var c := global_position + Vector3(facing * 2.2, 3.0, 0)
	# The charge leaves a trail of the hero's element on the street.
	if state_t >= _rush_fx_t:
		_rush_fx_t = state_t + 0.09
		_erupt(global_position + Vector3(-facing * 0.5, 0, randf_range(-0.6, 0.6)), 0.55)
	var dmg: float = atk["dmg"] * 0.4 * power * _boost()
	for t in get_tree().get_nodes_in_group("enemies"):
		if t.dead or t in _rush_hit or t.hit_center().distance_to(c) > 2.8 + t.hit_radius:
			continue
		_rush_hit.append(t)
		if deal(t, dmg, Vector3(facing * 24.0, 3.0, 0)):
			FX.hit_spark(t.hit_center(), dmg)
			Game.register_hit()
			Game.shake(0.15)
			add_rage(dmg * 0.45)


## SKY CLAW: slashes overhead and sends a claw wave flying up and ahead that
## homes in on aircraft (see SkyWave).
func _sky_claw() -> void:
	var c := global_position + Vector3(facing * atk["reach"], 4.6, 0)
	var dmg: float = atk["dmg"] * power * _boost()
	var hits := 0
	for t in get_tree().get_nodes_in_group("enemies"):
		if not t.dead and t.hit_center().distance_to(c) <= atk["radius"] + t.hit_radius:
			if deal(t, dmg * (AIR_BONUS if t is Flyer else 1.0), Vector3(facing * 6.0, 12.0, 0)):
				hits += 1
				FX.hit_spark(t.hit_center(), dmg)
	var wave := SkyWave.new()
	wave.shooter = self
	wave.dir = facing
	wave.damage = dmg * 1.2
	wave.tint = rage_style["glow"]
	get_parent().add_child(wave)
	wave.global_position = c + Vector3(facing * 1.0, 0.5, 0)
	FX.energy(c, rage_style["glow"])
	RageFX.pop(c, rage_style, 0.7)
	if hits > 0:
		Game.shake(atk["shake"])
		Game.hitstop(0.05)
		for i in hits:
			Game.register_hit()
		add_rage(dmg * 0.45 * hits)


func _on_land() -> void:
	super._on_land()
	_air_moves = 0
	# The harder the fall, the bigger the thud (the ground pound has its own).
	var k := clampf(_fall_speed / JUMP_VEL, 0.0, 1.6)
	if state != S.STOMP and k > 0.5:
		FX.dust(global_position, 0.5 + 0.6 * k)
		FX.shockwave(global_position, 2.0 + 2.5 * k, Color(0.9, 0.85, 0.75))
		Game.shake(0.1 * k)
		rumble(0.2 * k, 0.35 * k, 0.12)
	model.land(k)
	_fall_speed = 0.0


func _bdmg() -> float:
	return 1.0 + _m("wrecker") / 100.0


## The hero's element bursting out of the street (see RageFX.erupt).
func _erupt(pos: Vector3, size: float) -> void:
	RageFX.erupt(pos, rage_style, size)


## A ring of `count` element bursts around `pos`.
func _erupt_ring(pos: Vector3, radius: float, count: int, size: float) -> void:
	for i in count:
		var a := TAU * i / count + randf_range(-0.2, 0.2)
		_erupt(pos + Vector3(cos(a) * radius, 0, sin(a) * radius * 0.6), size)


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
		FX.shockwave(Vector3(c.x, 0, z), 3.0, rage_style["glow"])
		_erupt(c, 0.8)


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


## Jump + heavy: GROUND POUND. Dives down and hits everything around the
## landing spot, with a weaker outer ring.
func _start_stomp() -> void:
	velocity.y = -46.0
	_set_state(S.STOMP)


func _stomp_land() -> void:
	var st := 1.0 + _m("stomp") / 100.0
	var c := global_position + Vector3(0, 1.2, 0)
	var dmg := 30.0 * power * _boost() * st
	var hits := strike(c, 7.0 * st, dmg, Vector3(10, 14, 0), "enemies", 55.0 * power * _bdmg())
	for t in get_tree().get_nodes_in_group("enemies"):
		var d: float = t.hit_center().distance_to(c) - t.hit_radius
		if not t.dead and d > 7.0 * st and d <= 11.0 * st and absf(t.hit_center().y - c.y) < 5.0:
			if deal(t, dmg * 0.35, Vector3(signf(t.global_position.x - global_position.x) * 6.0, 6.0, 0)):
				hits += 1
	combo_uses["pound"] = int(combo_uses.get("pound", 0)) + 1
	for t in _targets_near(c, 7.0 * st):
		_rage_effect(t, dmg * 0.5, false)
	FX.callout(global_position + Vector3(0, 7.5, 0), HeroMoves.combo_name(hero, "pound"), rage_style["glow"])
	FX.shockwave(global_position, 7.0 * st, rage_style["glow"])
	FX.shockwave(global_position, 11.0 * st, rage_style["spark"])
	FX.debris_burst(global_position + Vector3(0, 0.8, 0), 1.3)
	# The stomp makes the hero's element burst out of the street around it.
	RageFX.burst(global_position + Vector3(0, 1.0, 0), 5.0 * st, rage_style)
	_erupt(global_position, 1.2)
	_erupt_ring(global_position, 5.5 * st, 8, 0.9)
	rumble(0.5, 0.8, 0.25)
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
	_flame_ticks = 0
	invuln = 0.0
	rage_shake(0.3)
	FX.energy(global_position + Vector3(facing * 2.0, 5.0, 0), color())
	RageFX.charge(to_global(_mouth_pos()) + Vector3(facing * 0.6, 0, 0), rage_style, BEAM_CHARGE)
	FX.callout(global_position + Vector3(0, 7.5, 0), rage_style["attack"], rage_style["glow"])


## Runs the hero's rage attack (paid for up front, see _use_rage_skill).
## How it works comes from Content "special", how it looks and what it
## does to enemies from the hero's RageStyle.
func _state_beam(delta: float) -> void:
	invuln = 0.2
	match _special:
		"nova":
			_state_nova()
			return
		"quake":
			_state_quake()
			return
		"lightning":
			_state_lightning(delta)
			return
	if state_t < BEAM_CHARGE:
		return
	_beam.visible = true
	_beam.position = _mouth_pos()
	_beam.rotation.y = 0.0 if facing > 0.0 else PI
	var flicker := 1.0 + sin(state_t * 60.0) * 0.12
	_beam.scale = Vector3(1, flicker, flicker)
	_beam_light.light_energy = 6.0 * flicker
	# The hero's own breath swirls round the beam (atomic fire, frost, water).
	if _flame_fx == null:
		_flame_fx = RageFX.jet(rage_style, Vector3(facing, 0, 0))
	RageFX.jet_update(_flame_fx, rage_style, to_global(_mouth_pos()), facing, state_t)
	_beam_tick -= delta
	if _beam_tick <= 0.0:
		_beam_tick = 0.1
		_beam_damage()
		rage_shake(0.1)
	if state_t >= _special_time:
		_beam.visible = false
		_end_special()


func _end_special() -> void:
	_set_state(S.FREE)


## VOLTRA's LIGHTNING STORM: forked bolts leap from the mouth into the
## enemies ahead and chain on, while lightning strikes down from the sky.
func _state_lightning(delta: float) -> void:
	if state_t < BEAM_CHARGE:
		return
	_beam_tick -= delta
	if _beam_tick > 0.0:
		if state_t >= _special_time:
			_end_special()
		return
	_beam_tick = 0.15
	_special_step += 1
	var mouth := to_global(_mouth_pos())
	var dmg := 7.0 * _special_power()
	var foes: Array = get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
		var dx: float = (e.global_position.x - global_position.x) * facing
		return not e.dead and dx > -2.0 and dx < 26.0)
	foes.sort_custom(func(a, b) -> bool:
		return absf(a.global_position.x - global_position.x) < absf(b.global_position.x - global_position.x))
	if foes.is_empty():
		var tip := mouth + Vector3(facing * randf_range(8.0, 20.0), randf_range(-4.0, -1.0), randf_range(-1.5, 1.5))
		RageFX.bolt(mouth, tip, rage_style, 1.6)
		RageFX.ground(Vector3(tip.x, 0, tip.z), rage_style, 1.0, 1.2)
	else:
		var first: Node3D = foes[_special_step % mini(foes.size(), 3)]
		RageFX.bolt(mouth, first.hit_center(), rage_style, 1.8)
		if deal(first, dmg, Vector3(facing * 3.0, 2.0, 0)):
			Game.register_hit()
			FX.hit_spark(first.hit_center(), dmg)
			_rage_effect(first, dmg, true)
		_chain_shock(first, dmg * 0.6, [first])
	if _special_step % 3 == 0:
		var target := global_position + Vector3(facing * randf_range(5.0, 22.0), 0, randf_range(-3.0, 1.5))
		if not foes.is_empty():
			var e: Node3D = foes[randi() % foes.size()]
			target = Vector3(e.global_position.x, 0, e.global_position.z)
		SuperFX.lightning_strike(target, rage_style)
		var hits := strike(target + Vector3(0, 2.0, 0), 3.5, dmg * 1.5, Vector3(4, 10, 0), "enemies", 30.0 * _bdmg())
		for i in hits:
			Game.register_hit()
	rage_shake(0.15)
	rumble(0.3, 0.4, 0.1)
	if state_t >= _special_time:
		_end_special()


## Expanding blasts centred on the hero, in the hero's element.
func _state_nova() -> void:
	var pulse_t := BEAM_CHARGE + 0.15 + _special_step * 0.6
	var pulses := 5 if _has("long_special") else 3
	if _special_step < pulses and state_t >= pulse_t:
		_special_step += 1
		var c := global_position + Vector3(0, 3.0, 0)
		var dmg := 18.0 * _special_power()
		var targets := _targets_near(c, 9.0)
		var hits := strike(c, 9.0, dmg, Vector3(14, 10, 0), "enemies", 45.0 * power * _bdmg())
		for t in targets:
			_rage_effect(t, dmg, false)
		FX.shockwave(global_position, 10.0, color())
		SuperFX.nova_blast(global_position, 9.0, rage_style)
		RageFX.burst(c, 6.0, rage_style)
		match String(rage_style["effect"]):
			"poison":
				for i in 4:
					RageFX.cloud(global_position + Vector3(randf_range(-7, 7), 1.8, randf_range(-2, 2)), rage_style, 1.2)
			"leech":
				RageFX.jet_tick(rage_style, c, facing, 9.0, 1, targets)
				RageFX.ground(global_position, rage_style, 2.4, 1.5)
			_:
				RageFX.ground(global_position, rage_style, 2.4, 1.5)
		rage_shake(0.5)
		for i in hits:
			Game.register_hit()
	if state_t >= _special_time:
		_end_special()


## Stomps that send eruptions of the hero's element marching forward along
## the street: lava geysers, crystal spikes, bursts of red-hot scrap.
func _state_quake() -> void:
	var step_t := BEAM_CHARGE + _special_step * 0.2
	var steps := 14 if _has("long_special") else 9
	if _special_step < steps and state_t >= step_t:
		var x := global_position.x + facing * (3.0 + (_special_step % 9) * 4.5)
		var c := Vector3(x, 1.5, global_position.z)
		_special_step += 1
		var dmg := 14.0 * _special_power()
		var targets := _targets_near(c, 3.8)
		var hits := strike(c, 3.8, dmg, Vector3(6, 16, 0), "enemies", 0.0)
		for t in targets:
			_rage_effect(t, dmg, false)
		for b in get_tree().get_nodes_in_group("buildings"):
			b.try_hit(Vector3(x, 1.5, clampf(global_position.z - 3.0, -7.6, 5.0)), 3.5, 40.0 * power * _bdmg())
		FX.dust(c, 1.4)
		FX.debris_burst(c, 1.2)
		FX.shockwave(Vector3(x, 0, c.z), 4.0, color())
		RageFX.ground(Vector3(x, 0, c.z), rage_style, 1.5, 1.8)
		match String(rage_style["jet"]):
			"spikes":
				RageFX.spike(Vector3(x, 0, c.z + randf_range(-0.8, 0.8)), rage_style, 1.4)
			"flame":
				# A lava geyser shoots up out of the crack.
				RageFX.trail_burst(Vector3(x, 0.5, c.z), rage_style)
			_:
				RageFX.pop(c + Vector3(0, 1.0, 0), rage_style, 1.4)
		rage_shake(0.35)
		for i in hits:
			Game.register_hit()
	if state_t >= _special_time:
		_end_special()


func _targets_near(c: Vector3, r: float) -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(t) -> bool:
		return not t.dead and t.hit_center().distance_to(c) <= r + t.hit_radius)


func _beam_damage() -> void:
	var origin := global_position + Vector3(facing * 2.2, 4.85, 0)
	_flame_ticks += 1
	var dmg := 5.0 * _special_power()
	var hit: Array = []
	for t in get_tree().get_nodes_in_group("enemies"):
		if t.dead:
			continue
		var tc: Vector3 = t.hit_center()
		var along := (tc.x - origin.x) * facing
		var r: float = t.hit_radius
		if along > -1.0 and along < BEAM_LEN and absf(tc.z - origin.z) < 2.5 + r and absf(tc.y - origin.y) < 3.0 + r:
			var kb := Vector3(facing * (9.0 if rage_style["effect"] == "push" else 4.0), 1.0, 0)
			if deal(t, dmg, kb):
				Game.register_hit()
				hit.append(t)
				_rage_effect(t, dmg, true)
				FX.hit_spark(Vector3(tc.x - facing * r, origin.y, tc.z), 6.0)
				if _flame_ticks % 3 == 0:
					RageFX.pop(Vector3(tc.x - facing * r, origin.y, tc.z), rage_style, 1.0)
	if _flame_ticks % 3 == 0:
		RageFX.ground(Vector3(origin.x + facing * randf_range(6.0, BEAM_LEN * 0.8), 0, origin.z), rage_style, 1.3, 1.6)
	for b in get_tree().get_nodes_in_group("buildings"):
		b.try_beam(origin, facing, BEAM_LEN, 14.0 * _bdmg())


## Barrier, Armor, rage mode and Second Wind.
func _incoming(dmg: float, _from: Node3D) -> float:
	# Supers and the rage attack root the hero to the spot, so nothing gets through.
	if state == S.SUPER or state == S.BEAM:
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
		dmg *= 0.5 if _has("bulwark") else 0.75
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
	if _super_hits > 0:
		_super_rider(target, dmg)
	if _m("leech") > 0.0:
		heal(dmg * _m("leech") / 100.0)
	if _m("ability_leech") > 0.0 and _rage_hit():
		heal(dmg * _m("ability_leech") / 100.0)
	if target is Kaiju:
		if _m("burn") > 0.0 or _m("venom") > 0.0:
			var dot := (_m("burn") + _m("venom")) * power * (1.0 + _m("inferno") / 100.0)
			target.apply_burn(dot, 5.0 if _m("venom") > 0.0 else 3.0)
		if _m("frost") > 0.0:
			target.apply_slow(minf(_m("frost"), 70.0) / 100.0, 1.5)
	# Static arcs can't set off more arcs.
	if _m("static") > 0.0 and not _arcing and randf() * 100.0 < _m("static"):
		_arcing = true
		_chain_shock(target, power * 1.5 * _boost(), [target])
		_arcing = false


## True while the hero's hits come from a rage attack, rage mode or a super.
func _rage_hit() -> bool:
	return raging or state == S.BEAM or state == S.SUPER or (state == S.ATTACK and atk.get("rage", false))


func _on_hurt(dmg: float, from: Node3D) -> void:
	Game.run["hurt"] = true
	rumble(0.4, clampf(dmg / 30.0, 0.2, 1.0), 0.18)
	add_rage(dmg * 0.35 * (1.0 + _m("bloodrage") / 100.0))
	Game.combo = 0
	if _m("frostbite") > 0.0 and from is Kaiju and from.is_in_group("enemies"):
		from.apply_slow(minf(_m("frostbite"), 70.0) / 100.0, 2.0)
	if _m("thorns") > 0.0 and from is Kaiju and from.is_in_group("enemies"):
		from.take_hit(_m("thorns") * power, Vector3.ZERO, self)
	# Rage attacks and supers can't be interrupted; rage mode shrugs off stagger.
	# Plain gunfire never staggers either, so the player can close in on shooters.
	if from is Projectile and from.is_plain_shot():
		return
	if state == S.BEAM or state == S.SUPER or raging:
		hitstun = 0.0
		knock *= 0.3 if raging else 0.0
		return
	_beam.visible = false
	_set_state(S.HURT)


func _on_death() -> void:
	_set_state(S.DEAD)
	Game.track("knockouts")
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


## Teammates standing close to a downed player fill its revive meter.
func _tick_revive(delta: float) -> void:
	if not dead:
		return
	var helpers := 0
	for q in Game.living_players():
		var d: Vector3 = q.global_position - global_position
		if Vector2(d.x, d.z).length() <= REVIVE_RANGE:
			helpers += 1
	if helpers > 0:
		revive_progress += delta * helpers / REVIVE_TIME
	else:
		revive_progress = maxf(revive_progress - delta * 0.25 / REVIVE_TIME, 0.0)
	_revive_label.visible = true
	_revive_ring.visible = true
	_revive_label.text = "REVIVE  %d%%" % int(minf(revive_progress, 1.0) * 100.0) if revive_progress > 0.0 else "REVIVE!"
	var mat: StandardMaterial3D = _revive_ring.material_override
	var c := color()
	mat.albedo_color = Color(c.r, c.g, c.b, 0.25 + 0.6 * revive_progress)
	mat.emission_energy_multiplier = 0.5 + 2.5 * revive_progress
	_revive_ring.scale = Vector3.ONE * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.008))
	if revive_progress >= 1.0:
		revive(REVIVE_HP)
		Game.track("revives")
		FX.shockwave(global_position, 5.0, c)
		var hud = Game.world.get("hud") if Game.world else null
		if hud:
			hud.show_message("%s IS BACK!" % display_name(), 1.2)


## The "REVIVE" tag over a downed player and the ring on the ground that
## shows where a teammate has to stand.
func _make_revive_marker() -> void:
	_revive_label = Label3D.new()
	_revive_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_revive_label.no_depth_test = true
	_revive_label.render_priority = 10
	_revive_label.pixel_size = 0.012
	_revive_label.font_size = 64
	_revive_label.outline_size = 18
	_revive_label.modulate = color().lerp(Color.WHITE, 0.5)
	_revive_label.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	_revive_label.position = Vector3(0, 6.5 * _h["size"], 0)
	_revive_label.visible = false
	add_child(_revive_label)
	var torus := TorusMesh.new()
	torus.inner_radius = REVIVE_RANGE - 0.25
	torus.outer_radius = REVIVE_RANGE
	torus.rings = 48
	torus.ring_segments = 6
	_revive_ring = MeshInstance3D.new()
	_revive_ring.mesh = torus
	_revive_ring.scale = Vector3.ONE
	_revive_ring.position = Vector3(0, 0.08, 0)
	_revive_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color()
	_revive_ring.material_override = mat
	_revive_ring.visible = false
	add_child(_revive_ring)


func _animate(delta: float) -> void:
	var on_floor := is_on_floor()
	var spd := Vector2(velocity.x, velocity.z).length()
	model.walk_amount = clampf(spd / SPEED, 0.0, 1.0) if (on_floor and state == S.FREE) else 0.0
	model.glow = 1.0 if raging else rage / rage_max * 0.7
	model.eye_glow = 1.0 if (state == S.BEAM or state == S.SUPER or raging) else 0.0
	model.airborne = not on_floor
	model.crouch = 1.0 - _jump_squat / JUMP_SQUAT if _jump_squat > 0.0 else 0.0
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
				"spit_r", "spit_l":
					var thrust := lerpf(-0.3, 1.6, p * p) if after == 0.0 else lerpf(1.6, 0.3, after)
					if atk["pose"] == "spit_r":
						ar = thrust
					else:
						al = thrust
					jaw = p if after == 0.0 else lerpf(1.0, 0.0, minf(after * 2.0, 1.0))
					lean = lerpf(-0.15, 0.3, p) if after == 0.0 else lerpf(0.3, 0.0, after)
				"spit":
					ar = lerpf(0.4, 2.0, p) if after == 0.0 else lerpf(2.0, 0.4, after)
					al = ar
					jaw = p if after == 0.0 else lerpf(1.0, 0.0, minf(after * 2.0, 1.0))
					lean = lerpf(-0.35, 0.4, p * p) if after == 0.0 else lerpf(0.4, 0.0, after)
				"flame":
					# Rears back, then braces and pours fire out with a shudder.
					var pour := state_t >= active and state_t < active + _stream_len
					jaw = p if after == 0.0 else (1.0 if pour else lerpf(1.0, 0.0, minf((state_t - active - _stream_len) * 4.0, 1.0)))
					lean = lerpf(0.0, -0.4, p) if after == 0.0 else (0.25 + sin(state_t * 40.0) * 0.04 if pour else lerpf(0.25, 0.0, after))
					ar = 1.1 if pour else 0.6
					al = ar
				"roar":
					jaw = 1.0 if after < 0.7 else lerpf(1.0, 0.0, (after - 0.7) / 0.3)
					ar = 2.2
					al = 2.2
					lean = -0.35 if after == 0.0 else lerpf(-0.35, 0.0, after)
				"rush":
					# Head down, shoulders first.
					ar = 0.9
					al = 0.9
					jaw = 0.6
					lean = 0.55 if after == 0.0 else lerpf(0.55, 0.0, after)
				"claw_up":
					ar = lerpf(-0.4, 3.0, p) if after == 0.0 else lerpf(3.0, 1.2, after)
					al = lerpf(-0.2, 2.6, p * p) if after == 0.0 else lerpf(2.6, 1.0, after)
					lean = lerpf(0.1, -0.45, p) if after == 0.0 else lerpf(-0.45, 0.0, after)
					jaw = p
				"crush":
					if after == 0.0:
						ar = lerpf(0.3, 3.3, minf(p * 1.5, 1.0))
						al = ar
						lean = -0.4 * p
						jaw = p
					else:
						ar = lerpf(0.9, 0.4, after)
						al = ar
						lean = lerpf(0.7, 0.0, after)
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
	core_mat.albedo_color = tint.lerp(Color.WHITE, 0.55)
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
	# Blended, not additive, so the beam keeps its colour on a bright day.
	glow_mat.albedo_color = Color(tint.r * 0.5, tint.g * 0.8, tint.b, 0.5)
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
## The picks in the hero's super tree (SuperTree, in `sup`) change how it
## plays: riders on every hit, what happens where it lands, and the shape of
## the super itself.
func _start_super() -> void:
	if raging:
		_exit_rage_mode()
	super_meter = 0.0
	super_changed.emit(super_meter, SUPER_MAX)
	Game.track("supers")
	_super_tick = 0.0
	_super_step = 0
	_super_targets = []
	_super_once = {}
	# Turning round gives each side about the beam a plain breath has.
	_super_len = SUPER_TIME * (1.4 if _sup("long") or _sup("beam_turn") else 1.0) + (0.8 if _sup("wave_whirlpool") else 0.0)
	_set_state(S.SUPER)
	rumble(1.0, 1.0, _super_len)
	Game.shake(0.8)
	Game.hitstop(0.25)
	FX.shockwave(global_position, 12.0, color())
	FX.energy(global_position + Vector3(0, 5, 0), color())
	FX.light_flash(global_position + Vector3(0, 6, 0), color(), 14.0, 30.0, 0.8)
	SuperFX.charge(global_position, rage_style, 0.6)
	_super_fx = null
	if _sup("pull"):
		for e in _enemies_near(32.0):
			if e is Kaiju:
				var d: float = global_position.x + facing * 4.0 - e.global_position.x
				e.knock = Vector3(clampf(d * 2.5, -28.0, 28.0), 4.0, 0)
				e.hitstun = 0.6
		FX.shockwave(global_position, 30.0, color())
	match String(_super["pattern"]):
		"storm":
			SuperFX.storm_cloud(global_position, facing, _super_len)
		"supernova":
			SuperFX.sun(global_position, rage_style, SUPER_TIME - 0.3)
		"wave":
			# Rolls in step with the wave's hits in _super_wave.
			var size := 1.6 if _sup("wave_tsunami") else 1.0
			SuperFX.tidal_wave(global_position + Vector3(-facing * 7.0, 0, 0), facing, 12 * 3.5, 12 * 0.15, 0.5, size)
			if _sup("wave_double"):
				SuperFX.tidal_wave(global_position + Vector3(facing * 7.0, 0, 0), -facing, 12 * 3.5, 12 * 0.15, 0.5, size)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message(_super["name"], 1.6)


func _sup(effect: String) -> bool:
	return sup.has(effect)


## True the first time it is asked for `key` during one super.
func _once(key: String) -> bool:
	if _super_once.has(key):
		return false
	_super_once[key] = true
	return true


func _enemies_near(r: float) -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
		return not e.dead and absf(e.global_position.x - global_position.x) < r)


func _super_hit(t: Node, dmg: float, kb: Vector3) -> void:
	_super_hits += 1
	if deal(t, dmg, kb):
		Game.register_hit()
		FX.hit_spark(t.hit_center(), dmg)
	_super_hits -= 1


## A super's area hit: counts the hits, carries the super tree's riders and,
## with `impact`, its impact effects (shards, zones, chains) at `center`.
func _super_strike(center: Vector3, radius: float, dmg: float, kb: Vector3, building_dmg := 0.0, impact := true) -> int:
	_super_hits += 1
	var hits := strike(center, radius, dmg, kb, "enemies", building_dmg)
	_super_hits -= 1
	for i in hits:
		Game.register_hit()
	if impact:
		# A wide blast lands on the enemies it hits rather than at its middle.
		var at: Array = [center]
		if radius > 6.0:
			at = get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
				return e.hit_center().distance_to(center) <= radius + e.hit_radius).slice(0, 3).map(func(e) -> Vector3:
					return e.hit_center())
		for q in at:
			_impact(q, dmg)
	return hits


## Riders from the super tree's first tier, on every super hit.
func _super_rider(target: Node, dmg: float) -> void:
	if _sup("leech"):
		heal(dmg * 0.1)
	if _sup("rage"):
		add_rage(3.0)
	if target is Kaiju:
		if _sup("burn"):
			target.apply_burn(power * 6.0, 4.0)
		if _sup("venom"):
			target.apply_burn(power * 4.0, 8.0)
		if _sup("chill"):
			target.apply_slow(0.5, 3.0)
		if _sup("stun"):
			target.frozen_t = maxf(target.frozen_t, 0.8)


## Where a super lands: shards fly out, a zone keeps hurting, or lightning
## arcs on (the super tree's second tier). These follow-ups set off no more.
func _impact(p: Vector3, dmg: float) -> void:
	if _sup("shatter"):
		for i in 4:
			var a := TAU * (i + randf() * 0.6) / 4.0
			var q := Vector3(p.x + cos(a) * randf_range(4.0, 7.0), 0.3, clampf(p.z + sin(a) * 3.0, z_min, z_max))
			var d := dmg * 0.22
			SuperFX.lob(Vector3(p.x, maxf(p.y, 1.0), p.z), q, rage_style, 0.6, 0.35, 3.0, func() -> void:
				if is_inside_tree():
					_super_strike(q + Vector3(0, 1.0, 0), 2.4, d, Vector3(3, 6, 0), 0.0, false))
	if _sup("erupt"):
		var g := Vector3(p.x, 0.0, p.z)
		RageFX.ground(g, rage_style, 1.8, 2.4)
		var d := dmg * 0.12
		var tw := create_tween()
		for i in 5:
			tw.tween_interval(0.45)
			tw.tween_callback(func() -> void:
				_super_strike(g + Vector3(0, 1.0, 0), 3.0, d, Vector3.ZERO, 0.0, false))
	if _sup("chain"):
		var src := p
		var foes: Array = get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool:
			return not e.dead and e.hit_center().distance_to(p) < 14.0)
		foes.sort_custom(func(a, b) -> bool:
			return a.hit_center().distance_to(p) < b.hit_center().distance_to(p))
		for e in foes.slice(0, 2):
			RageFX.bolt(src, e.hit_center(), rage_style, 1.0)
			_super_hit(e, dmg * 0.4, Vector3(facing * 3.0, 2.0, 0))
			src = e.hit_center()


## Damage of this super, with the super tree's power pick.
func _super_power() -> float:
	return _special_power() * (1.25 if _sup("power") else 1.0)


func _state_super(delta: float) -> void:
	invuln = 0.2
	var sp := _super_power()
	var pattern: String = _super["pattern"]
	_super_tick -= delta
	match pattern:
		"mega_beam":
			_super_beam(sp)
		"storm", "meteors", "scrap":
			_super_rain(sp, pattern)
		"vortex":
			_super_vortex(sp)
		"freeze":
			_super_freeze(sp)
		"frenzy":
			_super_frenzy(sp)
		"rift":
			_super_rift(sp)
		"wave":
			_super_wave(sp)
		"supernova":
			_super_nova(sp)
	if state_t >= _super_len:
		_end_super(sp)


## After the super: the super tree's third tier and any lingering effect.
func _end_super(sp: float) -> void:
	if _super_fx is GPUParticles3D:
		FX.stop_stream(_super_fx)
	_super_fx = null
	for b in _super_ice:
		SuperFX.shatter(b)
	_super_ice.clear()
	_beam.visible = false
	_beam.scale = Vector3.ONE
	_set_state(S.FREE)
	if _sup("finale"):
		var c := global_position + Vector3(0, 3.0, 0)
		_super_strike(c, 12.0, 30.0 * sp, Vector3(16, 12, 0), 50.0, false)
		RageFX.burst(c, 12.0, rage_style)
		Game.shake(0.7)
	if _sup("shield"):
		_barrier_up = true
		_barrier_fx.visible = true
		heal(max_hp * 0.15)
	if _sup("refund"):
		super_meter = SUPER_MAX * 0.3
		super_changed.emit(super_meter, SUPER_MAX)
	if _sup("rage_full"):
		add_rage(rage_max)
	if _sup("nova_corona"):
		var tw := create_tween()
		for i in 12:
			tw.tween_interval(0.5)
			tw.tween_callback(func() -> void:
				if dead:
					return
				var c := global_position + Vector3(0, 2.5, 0)
				_super_strike(c, 12.0, 7.0 * sp, Vector3(4, 3, 0), 10.0, false)
				SuperFX.nova_blast(global_position, 12.0, rage_style))


## OMEGA BREATH: a giant beam from the mouth. The super tree can turn it
## round halfway, make it a ray from the sky, or end it in an atomic blast.
func _super_beam(sp: float) -> void:
	var t1 := _super_len - 0.2
	if _sup("beam_core") and state_t >= t1 and _once("core"):
		var c := global_position + Vector3(0, 3.0, 0)
		_super_strike(c, 16.0, 70.0 * sp, Vector3(22, 16, 0), 100.0)
		SuperFX.nova_blast(global_position, 16.0, rage_style)
		FX.explosion(c, 2.4)
		FX.light_flash(c, color(), 24.0, 40.0, 0.6)
		Game.shake(1.0)
		Game.hitstop(0.12)
	if _sup("beam_sky"):
		# The ray sweeps from the hero's feet to far down the street.
		if state_t >= 0.5 and state_t < t1 and _super_tick <= 0.0:
			_super_tick = 0.12
			_super_step += 1
			var k := (state_t - 0.5) / maxf(t1 - 0.5, 0.1)
			var p := Vector3(global_position.x + facing * lerpf(3.0, 34.0, k), 0.0, global_position.z - 1.0)
			if _super_step % 2 == 1:
				SuperFX.pillar(p, rage_style, 0.5, 3.5)
			RageFX.ground(p, rage_style, 1.6, 2.0)
			_super_strike(p + Vector3(0, 2.0, 0), 4.5, 26.0 * sp, Vector3(4, 12, 0), 40.0, _super_step % 3 == 0)
			Game.shake(0.25)
		return
	if state_t >= 0.5 and state_t < t1:
		if _sup("beam_turn") and state_t >= (0.5 + t1) * 0.5 and _once("turn"):
			facing = -facing
			model.spin = TAU * 0.5
			if _super_fx is GPUParticles3D:
				FX.stop_stream(_super_fx)
			_super_fx = null
		_beam.visible = true
		_beam.position = _mouth_pos()
		_beam.rotation.y = 0.0 if facing > 0.0 else PI
		var f := 1.0 + sin(state_t * 70.0) * 0.15
		_beam.scale = Vector3(1.4, 3.2 * f, 3.2 * f)
		_beam_light.light_energy = 14.0 * f
		if _super_fx == null:
			_super_fx = RageFX.jet(rage_style, Vector3(facing, 0, 0))
		RageFX.jet_update(_super_fx, rage_style, to_global(_mouth_pos()), facing, state_t)
		if _super_tick <= 0.0:
			_super_tick = 0.1
			_super_step += 1
			Game.shake(0.25)
			var origin := global_position + Vector3(facing * 2.2, 4.85, 0)
			SuperFX.mega_beam_tick(to_global(_mouth_pos()), facing, BEAM_LEN * 1.2, rage_style, _super_step)
			var hit := 0
			for t in get_tree().get_nodes_in_group("enemies"):
				if t.dead:
					continue
				var along: float = (t.hit_center().x - origin.x) * facing
				if along > -2.0 and along < BEAM_LEN * 1.4 and absf(t.hit_center().z - origin.z) < 6.0 + t.hit_radius:
					_super_hit(t, 9.0 * sp, Vector3(facing * 6.0, 1.0, 0))
					# Impact effects every few ticks, on a few of the enemies burnt.
					if _super_step % 4 == 0 and hit < 4:
						hit += 1
						_impact(t.hit_center(), 9.0 * sp * 3.0)
			for b in get_tree().get_nodes_in_group("buildings"):
				b.try_beam(origin, facing, BEAM_LEN * 1.4, 40.0)
	else:
		_beam.visible = false
		if _super_fx is GPUParticles3D:
			FX.stop_stream(_super_fx)
		_super_fx = null


## A spot near an enemy ahead of the hero for the next bolt or rock.
func _rain_target() -> Vector3:
	var foes := _enemies_near(34.0)
	var target := global_position + Vector3(facing * randf_range(4.0, 24.0), 0, randf_range(-4.0, 2.0))
	if not foes.is_empty():
		var e: Node3D = foes[_super_step % foes.size()]
		target = Vector3(e.global_position.x, 0.0, e.global_position.z) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
	return target


## THUNDERSTORM, MAGMA RAIN and SCRAP BARRAGE: bolts or rocks rain on the
## enemies. The super tree changes how many and how big, splits or bounces
## the rocks, or turns the rain into one giant rock or bolt.
func _super_rain(sp: float, pattern: String) -> void:
	var scrap := pattern == "scrap"
	if pattern != "storm" and _sup("giant"):
		if state_t >= 0.5 and _once("giant"):
			var target := _rain_target()
			SuperFX.target_ring(target, 12.0, rage_style, 1.5)
			_rain_rock(target, scrap, 4.0, 180.0 * sp, 12.0, 1.5, target + Vector3(-18.0, 34.0, -6.0))
		return
	if pattern == "storm" and _sup("bolt_giant") and state_t >= _super_len - 0.6 and _once("giant"):
		var target := _rain_target()
		SuperFX.pillar(target, rage_style, 0.7, 6.0)
		for i in 4:
			RageFX.bolt(target + Vector3(randf_range(-6, 6), 22.0, -3.0), target + Vector3(randf_range(-2, 2), 0.3, 0), rage_style, 4.0)
		_super_strike(target + Vector3(0, 2.0, 0), 12.0, 90.0 * sp, Vector3(14, 18, 0), 120.0)
		FX.light_flash(target + Vector3(0, 10, 0), rage_style["glow"], 30.0, 50.0, 0.4)
		FX.shockwave(target, 14.0, color())
		Game.shake(1.1)
		Game.hitstop(0.12)
	var tick := 0.16
	var size := 1.0
	var mul := 1.0
	var radius := 3.5 if pattern == "storm" else 3.8
	if _sup("rain_more"):
		tick = 0.08
		size = 0.7
		mul = 0.6
		radius *= 0.8
	elif _sup("rain_big") or _sup("bolt_big"):
		tick = 0.32
		size = 1.7
		mul = 2.2
		radius *= 1.6
	elif _sup("storm_all"):
		tick = 0.4
	if state_t < 0.5 or state_t >= _super_len - 0.4 or _super_tick > 0.0:
		return
	_super_tick = tick
	if pattern == "storm" and _sup("storm_all"):
		for e in _enemies_near(34.0):
			_rain_bolt(Vector3(e.global_position.x, 0.0, e.global_position.z), 1.0, 12.0 * sp, 2.8)
		_super_step += 1
		return
	var target := _rain_target()
	_super_step += 1
	if pattern == "storm":
		_rain_bolt(target, size, 16.0 * sp * mul, radius)
	else:
		_rain_rock(target, scrap, size, 18.0 * sp * mul, radius)


func _rain_bolt(target: Vector3, size: float, dmg: float, radius: float) -> void:
	SuperFX.lightning_strike(target, rage_style)
	if size > 1.2:
		RageFX.bolt(target + Vector3(randf_range(-3, 3), 19.0, -3.0), target + Vector3(0, 0.3, 0), rage_style, 3.5)
		FX.shockwave(target, radius, color())
	_super_strike(target + Vector3(0, 2.0, 0), radius, dmg, Vector3(4, 10, 0), 30.0)
	Game.shake(0.2 * size)


## One falling rock or hunk of scrap. With the super tree it may first drag
## enemies in (magnet) or split in mid-air (frag_air).
func _rain_rock(target: Vector3, scrap: bool, size: float, dmg: float, radius: float, fall := 0.45, start := Vector3.INF) -> void:
	if _sup("magnet"):
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Kaiju and not e.dead and absf(e.global_position.x - target.x) < 10.0:
				e.knock = Vector3(clampf((target.x - e.global_position.x) * 3.0, -20.0, 20.0), 2.0, 0)
				e.hitstun = 0.4
		FX.shockwave(target, 10.0, color())
	if start == Vector3.INF:
		start = target + Vector3(-12.0, 36.0, -4.0) * clampf(size, 1.0, 2.0)
	if _sup("frag_air"):
		var mid := start.lerp(target, 0.55)
		SuperFX.falling(mid, rage_style, scrap, fall * 0.55, func() -> void:
			if not is_inside_tree():
				return
			Game.shake(0.15)
			for i in 3:
				var q := Vector3(target.x + (i - 1) * 3.2 * size + randf_range(-0.6, 0.6), 0.0,
					clampf(target.z + randf_range(-1.5, 1.5), z_min, z_max))
				SuperFX.falling(q, rage_style, scrap, fall * 0.5, func() -> void:
					_rock_land(q, radius * 0.75, dmg * 0.5, size * 0.55), size * 0.55, mid), size, start, true)
		return
	SuperFX.falling(target, rage_style, scrap, fall, func() -> void:
		_rock_land(target, radius, dmg, size), size, start)


## A rock lands. With the bounce pick it hops on along the street twice.
func _rock_land(p: Vector3, radius: float, dmg: float, size: float, bounces := 2) -> void:
	if not is_inside_tree():
		return
	_super_strike(p + Vector3(0, 1.5, 0), radius, dmg, Vector3(8, 14, 0), dmg * _bdmg())
	Game.shake(minf(0.3 * size, 1.2))
	if size >= 2.5:
		FX.shockwave(p, radius * 1.5, color())
		FX.light_flash(p + Vector3(0, 6, 0), rage_style["glow"], 24.0, 50.0, 0.5)
		RageFX.ground(p, rage_style, size, 4.0)
		Game.hitstop(0.15)
	if _sup("bounce") and bounces > 0:
		var q := Vector3(p.x + facing * randf_range(5.0, 7.0) * clampf(size, 1.0, 2.0), 0.0, p.z)
		SuperFX.lob(p + Vector3(0, 1.0, 0), q, rage_style, 1.2 * size, 0.4, 4.0 * clampf(size, 1.0, 2.0), func() -> void:
			_rock_land(q, radius * 0.85, dmg * 0.6, size * 0.8, bounces - 1))


## SINGULARITY: a black hole pulls enemies in, then blows up. The super tree
## opens two, lets it drift, makes it far bigger or makes it burst again and
## again.
func _super_vortex(sp: float) -> void:
	var big := _sup("vortex_collapse")
	var t := clampf((state_t - 0.4) / 1.9, 0.0, 1.0)
	var centers: Array = []
	if _sup("vortex_twin"):
		centers = [global_position + Vector3(facing * 8.0, 3.0, 0), global_position + Vector3(-facing * 8.0, 3.0, 0)]
	elif _sup("vortex_drift"):
		centers = [global_position + Vector3(facing * lerpf(5.0, 22.0, t), 3.0, 0)]
	else:
		centers = [global_position + Vector3(facing * (8.0 if big else 6.0), 3.0, 0)]
	if state_t >= 0.4 and _once("open"):
		for c in centers:
			var drift := Vector3(facing * 17.0, 0, 0) if _sup("vortex_drift") else Vector3.ZERO
			SuperFX.singularity(c, rage_style, 1.9, 1.6 if big else (0.75 if centers.size() > 1 else 1.0), drift)
	var reach := 42.0 if big else 30.0
	if state_t >= 0.4 and state_t < 2.3:
		for e in _enemies_near(reach):
			if e is Kaiju:
				var best: Vector3 = centers[0]
				for c in centers:
					if absf(c.x - e.global_position.x) < absf(best.x - e.global_position.x):
						best = c
				var d: Vector3 = best - e.global_position
				d.y = 0.0
				e.knock = d.normalized() * minf(d.length() * 2.0, 18.0)
				e.hitstun = 0.2
		if _super_tick <= 0.0:
			_super_tick = 0.45 if _sup("vortex_pulse") else 0.25
			_super_step += 1
			for c in centers:
				FX.shockwave(Vector3(c.x, 0.3, c.z), 9.0, color())
				FX.energy(c, color())
				if _sup("vortex_pulse"):
					_super_strike(c, 8.0, 22.0 * sp, Vector3(6, 8, 0), 20.0)
					RageFX.burst(c, 8.0, rage_style)
					Game.shake(0.4)
				else:
					_super_strike(c, 6.0, 3.0 * sp, Vector3.ZERO, 0.0, false)
	elif state_t >= 2.3 and _once("blast") and not _sup("vortex_pulse"):
		var r := 18.0 if big else 11.0
		var dmg := (110.0 if big else 70.0) * (0.8 if centers.size() > 1 else 1.0) * sp
		for c in centers:
			_super_strike(c, r, dmg, Vector3(22, 16, 0), 80.0)
			FX.explosion(c, 2.2 * (1.6 if big else 1.0))
			FX.shockwave(Vector3(c.x, 0.3, c.z), r * 1.5, color())
		Game.shake(1.0)
		Game.hitstop(0.12)


## ABSOLUTE ZERO: every enemy around is frozen in ice, then shattered. The
## super tree can freeze twice, freeze deeper, rain hail on the ice or
## freeze the whole screen.
func _super_freeze(sp: float) -> void:
	var phases: Array = [[0.5, 1.5], [1.7, 2.7]] if _sup("freeze_twice") else [[0.5, 2.6]]
	var reach := 60.0 if _sup("freeze_age") else 34.0
	var dmg := 75.0 * sp
	if _sup("freeze_twice"):
		dmg *= 0.65
	if _sup("freeze_deep"):
		dmg *= 1.4
	if _sup("freeze_age"):
		dmg *= 1.3
	for i in phases.size():
		var ph: Array = phases[i]
		if state_t >= ph[0] and _once("freeze%d" % i):
			_super_ice.clear()
			_super_targets.clear()
			for e in _enemies_near(reach):
				if e is Kaiju:
					e.frozen_t = ph[1] - ph[0] + 0.2
				_super_targets.append(e)
				_super_ice.append(SuperFX.encase(e, clampf(e.hit_radius / 1.6, 0.7, 2.0)))
			SuperFX.freeze_wave(global_position, reach * 0.9, rage_style)
			Game.shake(0.5)
		elif state_t >= ph[1] and _once("shatter%d" % i):
			for b in _super_ice:
				SuperFX.shatter(b)
			_super_ice.clear()
			for e in _super_targets:
				if is_instance_valid(e) and not e.dead:
					_super_hit(e, dmg, Vector3(facing * 10.0, 14.0, 0))
					_impact(e.hit_center(), dmg)
					if _sup("freeze_deep") and e is Kaiju:
						e.apply_slow(0.6, 4.0)
					FX.debris_burst(e.hit_center(), 1.4)
					FX.shockwave(e.global_position, 5.0, Color(0.8, 1.0, 1.0))
			Game.shake(0.9)
			Game.hitstop(0.12)
	# Hail pounds the frozen enemies while they are stuck in the ice.
	if _sup("freeze_hail") and not _super_ice.is_empty() and _super_tick <= 0.0:
		_super_tick = 0.18
		var e = _super_targets[_super_step % _super_targets.size()]
		_super_step += 1
		if is_instance_valid(e) and not e.dead:
			var to: Vector3 = e.hit_center() + Vector3(randf_range(-1.0, 1.0), 1.0, 0)
			var d := 7.0 * sp
			SuperFX.lob(to + Vector3(-4.0, 18.0, -2.0), to, rage_style, 0.9, 0.3, 0.0, func() -> void:
				if is_inside_tree():
					_super_strike(to, 2.6, d, Vector3.ZERO, 10.0, false))


## SHADOW FRENZY: the hero blinks from enemy to enemy, slashing. The super
## tree trades number of slashes for power, adds clones that strike again or
## a last slash that cuts everyone.
func _super_frenzy(sp: float) -> void:
	var count := 9
	var tick := 0.28
	var dmg := 20.0
	var kb := 8.0
	if _sup("slash_more"):
		count = 15
		tick = 0.17
		dmg = 13.0
	elif _sup("slash_heavy"):
		count = 6
		tick = 0.42
		dmg = 36.0
		kb = 16.0
	if _sup("slash_clones") and _super_step >= count and state_t >= 0.6 + count * tick and _once("clones"):
		for e in _super_targets:
			if is_instance_valid(e) and not e.dead:
				var side := -1.0 if randf() < 0.5 else 1.0
				SuperFX.slash(e.global_position + Vector3(-side * 3.2, 0, 0), e.hit_center(), side, rage_style)
				_super_hit(e, 25.0 * sp, Vector3(side * 8.0, 8.0, 0))
		Game.shake(0.6)
	if state_t < 0.4 or _super_step >= count or _super_tick > 0.0:
		return
	_super_tick = tick
	var foes := _enemies_near(34.0)
	_super_step += 1
	if foes.is_empty():
		return
	var e: Node3D = foes[_super_step % foes.size()]
	if not e in _super_targets:
		_super_targets.append(e)
	var side := -1.0 if _super_step % 2 == 0 else 1.0
	var from := global_position
	global_position = Vector3(e.global_position.x - side * 3.2, global_position.y, clampf(e.global_position.z, z_min, z_max))
	facing = side
	model.spin = TAU * 0.5
	_super_hit(e, dmg * sp, Vector3(side * kb, 6.0, 0))
	_impact(e.hit_center(), dmg * sp)
	SuperFX.slash(from, e.hit_center(), side, rage_style)
	Game.shake(0.3 if kb < 10.0 else 0.6)
	if _sup("slash_eclipse") and _super_step == count:
		for o in _enemies_near(34.0):
			SuperFX.slash(o.hit_center() + Vector3(-side * 3.0, 0, 0), o.hit_center(), side, rage_style)
			_super_hit(o, 40.0 * sp, Vector3(side * 12.0, 10.0, 0))
		FX.light_flash(global_position + Vector3(0, 6, 0), Color(0.6, 0.05, 0.1), 20.0, 40.0, 0.4)
		Game.shake(0.9)
		Game.hitstop(0.12)


## TECTONIC RIFT: a crack runs out both ways from the hero. The super tree
## sends it only forward, closes it again, raises pillars or splits the
## whole street at the end.
func _super_rift(sp: float) -> void:
	var steps := 24 if _sup("rift_return") else 12
	var tick := 0.11 if _sup("rift_return") else 0.15
	if _sup("rift_split") and state_t >= 2.5 and _once("split"):
		for x in range(-34, 35, 5):
			SuperFX.rift_step(Vector3(global_position.x + x, 1.5, global_position.z), rage_style)
		for e in _enemies_near(36.0):
			_super_hit(e, 55.0 * sp, Vector3(facing * 4.0, 22.0, 0))
			FX.dust(e.global_position, 1.6)
		FX.shockwave(global_position, 36.0, color())
		Game.shake(1.1)
		Game.hitstop(0.12)
	if state_t < 0.5 or _super_step >= steps or _super_tick > 0.0:
		return
	_super_tick = tick
	_super_step += 1
	var k := _super_step if _super_step <= 12 else 25 - _super_step
	var forward := _sup("rift_forward")
	var dirs := [facing] if forward else [-1.0, 1.0]
	for dir in dirs:
		var p := Vector3(global_position.x + dir * k * (4.4 if forward else 3.2), 1.5, global_position.z)
		_super_strike(p, 3.4, (22.0 if forward else 12.0) * sp, Vector3(4, 16, 0), 40.0)
		SuperFX.rift_step(p, rage_style)
		FX.dust(p, 1.2)
		FX.shockwave(Vector3(p.x, 0, p.z), 3.0, color())
	Game.shake(0.3)
	# A stone pillar under one more enemy every third step.
	if _sup("rift_pillars") and _super_step % 3 == 0:
		for e in _enemies_near(34.0):
			if not e in _super_targets:
				_super_targets.append(e)
				var at := Vector3(e.global_position.x, 0.0, e.global_position.z)
				RageFX.spike(at, rage_style, 2.6)
				FX.debris_burst(at + Vector3(0, 1, 0), 1.2)
				_super_hit(e, 30.0 * sp, Vector3(0, 22.0, 0))
				break


## TIDAL WAVE: a wall of water rolls down the street. The super tree adds
## one rolling the other way, makes it drag enemies back, makes it a
## tsunami or ends it in a whirlpool.
func _super_wave(sp: float) -> void:
	var big := _sup("wave_tsunami")
	var mid := global_position + Vector3(facing * 18.0, 0, -1.0)
	if _sup("wave_whirlpool") and state_t >= 2.4 and state_t < _super_len - 0.1:
		if _once("pool"):
			RageFX.ground(Vector3(mid.x, 0, mid.z), rage_style, 4.0, 2.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Kaiju and not e.dead and absf(e.global_position.x - mid.x) < 22.0:
				var d: Vector3 = mid - e.global_position
				d.y = 0.0
				e.knock = d.normalized() * minf(d.length() * 2.5, 18.0)
				e.hitstun = 0.2
		if _super_tick <= 0.0:
			_super_tick = 0.2
			_super_strike(mid + Vector3(0, 1.5, 0), 6.0, 9.0 * sp, Vector3.ZERO, 0.0, false)
			RageFX.splash(mid, rage_style, 1.6)
			FX.shockwave(Vector3(mid.x, 0.3, mid.z), 7.0, color())
			Game.shake(0.3)
	if state_t < 0.5 or _super_step >= 12 or _super_tick > 0.0:
		return
	_super_tick = 0.15
	_super_step += 1
	var k := _super_step
	var reach := 6.0 if big else 3.5
	var dmg := (20.0 if big else 13.0) * sp
	var dirs := [facing, -facing] if _sup("wave_double") else [facing]
	for dir in dirs:
		var p := Vector3(global_position.x + dir * (k * 3.5 - 6.0), 2.5, global_position.z - 1.0)
		var kb := Vector3(-dir * 12.0, 5.0, 0) if _sup("wave_undertow") else Vector3(dir * 18.0, 6.0, 0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.dead and absf(e.global_position.x - p.x) < reach + e.hit_radius:
				_super_hit(e, dmg, kb)
		if k % 3 == 0:
			_impact(p, dmg * 2.0)
		for b in get_tree().get_nodes_in_group("buildings"):
			b.try_hit(Vector3(p.x, 2.0, -7.0), reach + 0.5, 30.0)
		RageFX.splash(Vector3(p.x, 0.5, p.z), rage_style, 1.4 * (1.5 if big else 1.0))
		if k % 2 == 0:
			RageFX.ground(Vector3(p.x, 0, p.z), rage_style, 2.0, 2.0)
	Game.shake(0.25)


## SUPERNOVA: a sun swells over the hero and blasts the street around it.
## The super tree pulses it more often, adds flares down the street, makes
## the last blast giant, or leaves a corona burning after it.
func _super_nova(sp: float) -> void:
	if state_t < 0.5 or _super_step >= 12 or _super_tick > 0.0:
		return
	_super_tick = 0.15
	_super_step += 1
	var k := _super_step
	var pulse := _sup("nova_pulse")
	if k % (2 if pulse else 4) != 1:
		return
	var last := k == (11 if pulse else 9)
	var c := global_position + Vector3(0, 3.0, 0)
	var r := 14.0 if pulse else 18.0
	var dmg := (22.0 if pulse else 35.0) * sp
	if last and _sup("nova_bang"):
		r = 32.0
		dmg = 80.0 * sp
		FX.light_flash(c, Color.WHITE, 40.0, 60.0, 0.6)
		Game.hitstop(0.15)
	_super_strike(c, r, dmg, Vector3(18, 12, 0), 60.0)
	SuperFX.nova_blast(global_position, r, rage_style)
	FX.explosion(c, 1.6 * r / 18.0)
	FX.light_flash(c, color(), 20.0, 40.0, 0.5)
	Game.shake(0.8)
	if _sup("nova_flare"):
		for i in 4:
			var dir := -1.0 if i % 2 == 0 else 1.0
			var q := Vector3(global_position.x + dir * randf_range(16.0, 30.0), 0.3,
				clampf(global_position.z + randf_range(-3.0, 2.0), z_min, z_max))
			var d := 18.0 * sp
			SuperFX.lob(c + Vector3(0, 6.0, 0), q, rage_style, 1.0, 0.5, 6.0, func() -> void:
				if is_inside_tree():
					_super_strike(q + Vector3(0, 1.0, 0), 3.5, d, Vector3(6, 10, 0), 30.0, false)
					RageFX.ground(q, rage_style, 1.4, 1.6))
