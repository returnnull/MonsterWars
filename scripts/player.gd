class_name Player
extends Kaiju
## A playable kaiju: 3-hit light combo, heavy slam, jump stomp, dodge,
## and a rage-fuelled special (beam, nova or quake, depending on the hero).
## `slot` (0-3) picks the controller; `hero` picks a Content.HEROES entry.

signal rage_changed(rage: float, max_rage: float)

enum S { FREE, ATTACK, DODGE, BEAM, STOMP, HURT, DEAD }

const SPEED := 9.5
const DEPTH_SPEED := 6.5
const JUMP_VEL := 17.0
const RAGE_MAX := 100.0
const BEAM_LEN := 42.0
const BEAM_TIME := 2.6
const BEAM_CHARGE := 0.4

const ATTACKS := {
	"light1": {"dur": 0.30, "active": 0.11, "dmg": 7.0, "kb": Vector3(4, 0, 0), "reach": 2.6, "radius": 2.3,
		"pose": "jab_r", "shake": 0.12, "bdmg": 10.0, "next": "light2"},
	"light2": {"dur": 0.30, "active": 0.11, "dmg": 7.0, "kb": Vector3(4, 0, 0), "reach": 2.6, "radius": 2.3,
		"pose": "jab_l", "shake": 0.12, "bdmg": 10.0, "next": "light3"},
	"light3": {"dur": 0.55, "active": 0.24, "dmg": 13.0, "kb": Vector3(15, 8, 0), "reach": 0.0, "radius": 4.8,
		"pose": "spin", "shake": 0.35, "bdmg": 18.0, "next": ""},
	"heavy": {"dur": 0.72, "active": 0.38, "dmg": 22.0, "kb": Vector3(20, 10, 0), "reach": 3.0, "radius": 3.0,
		"pose": "slam", "shake": 0.55, "bdmg": 45.0, "next": ""},
}

var slot := 0
var hero := 0
var speed_mul := 1.0
var power := 1.0
var state := S.FREE
var state_t := 0.0
var rage := 0.0
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
var _death_tween: Tween
var _h: Dictionary
var _special := "beam"
var _special_step := 0


func _ready() -> void:
	_h = Content.hero(hero)
	max_hp = _h["hp"]
	speed_mul = _h["speed"]
	power = _h["power"]
	_special = _h["special"]
	add_to_group("player")
	init_body(1.2, 6.0, Game.LAYER_PLAYER)
	z_min = -5.2
	z_max = 3.0
	model = KaijuModel.new()
	add_child(model)
	model.build(_h["skin"], _h["belly"], _h["accent"], _h["eye"], _h["horns"])
	model.scale = Vector3.ONE * _h["size"]
	hit_radius = 1.6 * _h["size"]
	_beam = _make_beam(_h["accent"])
	add_child(_beam)
	_beam.visible = false
	Game.players.append(self)


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


func _act(action: String) -> String:
	return "p%d_%s" % [slot, action]


func add_rage(amount: float) -> void:
	if state == S.BEAM or dead:
		return
	rage = minf(rage + amount, RAGE_MAX)
	rage_changed.emit(rage, RAGE_MAX)
	if rage >= RAGE_MAX and not _rage_announced:
		_rage_announced = true
		# In co-op the player's own HUD panel says READY instead of a banner.
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and Game.players.size() == 1:
			hud.show_message("RAGE READY!", 1.4)


func _physics_process(delta: float) -> void:
	state_t += delta
	invuln = maxf(invuln - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
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
	move_body(delta, move)
	_animate(delta)


func _set_state(s: S) -> void:
	state = s
	state_t = 0.0


func _read_buffer(delta: float) -> void:
	_buffer_t -= delta
	if _buffer_t <= 0.0:
		_buffered = ""
	for a in ["light", "heavy", "jump", "dodge", "special"]:
		if Input.is_action_just_pressed(_act(a)):
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
			if is_on_floor():
				_start_attack("light1" if b == "light" else "heavy")
			else:
				_start_stomp()
			return Vector3.ZERO
		"dodge":
			if _dodge_cd <= 0.0:
				_consume()
				_dodge_dir = Vector3(input.x, 0, input.y).normalized()
				if _dodge_dir == Vector3.ZERO:
					_dodge_dir = Vector3(-facing, 0, 0)
				invuln = 0.4
				_dodge_cd = 0.6
				FX.dust(global_position, 0.6)
				_set_state(S.DODGE)
		"special":
			if rage >= RAGE_MAX and is_on_floor():
				_consume()
				_start_beam()
				return Vector3.ZERO
	return Vector3(input.x * SPEED * speed_mul, 0, input.y * DEPTH_SPEED * speed_mul)


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
		if _buffered == "light" and next != "":
			_consume()
			_start_attack(next)
		elif _buffered == "heavy" and atk["pose"] != "slam":
			_consume()
			_start_attack("heavy")
		elif state_t >= atk["dur"]:
			_set_state(S.FREE)
	if state_t < active:
		return Vector3(3.5 * facing, 0, 0)
	return Vector3.ZERO


func _do_hit() -> void:
	var reach: float = atk["reach"]
	var center := global_position + Vector3(facing * reach, 3.2, 0)
	if atk["pose"] == "spin":
		center = global_position + Vector3(0, 2.6, 0)
	var dmg: float = atk["dmg"] * power
	var hits := strike(center, atk["radius"], dmg, atk["kb"], "enemies", atk["bdmg"] * power)
	if atk["pose"] == "slam":
		FX.shockwave(global_position + Vector3(facing * 3.0, 0, 0), 5.0, Color(1.0, 0.8, 0.5))
		FX.dust(global_position + Vector3(facing * 3.0, 0, 0), 1.2)
		Game.shake(0.3)
	if hits > 0:
		Game.shake(atk["shake"])
		Game.hitstop(0.05 if dmg < 15.0 else 0.09)
		for i in hits:
			Game.register_hit()
		add_rage(dmg * 0.45 * hits)


func _start_stomp() -> void:
	velocity.y = -42.0
	_set_state(S.STOMP)


func _stomp_land() -> void:
	var hits := strike(global_position + Vector3(0, 1.2, 0), 5.5, 16.0 * power, Vector3(10, 12, 0), "enemies", 30.0 * power)
	FX.shockwave(global_position, 7.0)
	FX.dust(global_position, 1.6)
	Game.shake(0.6)
	if hits > 0:
		Game.hitstop(0.08)
		for i in hits:
			Game.register_hit()
		add_rage(8.0 * hits)
	_set_state(S.FREE)


func _start_beam() -> void:
	_set_state(S.BEAM)
	_beam_tick = 0.0
	_special_step = 0
	invuln = 0.0
	Game.shake(0.3)
	FX.energy(global_position + Vector3(facing * 2.0, 5.0, 0), color())


## Runs the hero's rage special. All three last BEAM_TIME and drain rage.
func _state_beam(delta: float) -> void:
	rage = RAGE_MAX * (1.0 - state_t / BEAM_TIME)
	rage_changed.emit(rage, RAGE_MAX)
	if _special == "nova":
		_state_nova()
		return
	if _special == "quake":
		_state_quake()
		return
	if state_t < BEAM_CHARGE:
		return
	_beam.visible = true
	_beam.position = Vector3(facing * 2.2, 4.85, 0)
	_beam.rotation.y = 0.0 if facing > 0.0 else PI
	var flicker := 1.0 + sin(state_t * 60.0) * 0.12
	_beam.scale = Vector3(1, flicker, flicker)
	_beam_light.light_energy = 6.0 * flicker
	_beam_tick -= delta
	if _beam_tick <= 0.0:
		_beam_tick = 0.1
		_beam_damage()
		Game.shake(0.1)
	if state_t >= BEAM_TIME:
		_beam.visible = false
		rage = 0.0
		_rage_announced = false
		rage_changed.emit(rage, RAGE_MAX)
		_set_state(S.FREE)


func _end_special() -> void:
	rage = 0.0
	_rage_announced = false
	rage_changed.emit(rage, RAGE_MAX)
	_set_state(S.FREE)


## Three expanding energy blasts centred on the hero.
func _state_nova() -> void:
	var pulse_t := BEAM_CHARGE + 0.15 + _special_step * 0.6
	if _special_step < 3 and state_t >= pulse_t:
		_special_step += 1
		var c := global_position + Vector3(0, 3.0, 0)
		var hits := strike(c, 9.0, 18.0 * power, Vector3(14, 10, 0), "enemies", 45.0 * power)
		FX.shockwave(global_position, 10.0, color())
		FX.energy(c, color())
		Game.shake(0.5)
		for i in hits:
			Game.register_hit()
	if state_t >= BEAM_TIME:
		_end_special()


## Stomps that send eruptions marching forward along the street.
func _state_quake() -> void:
	var step_t := BEAM_CHARGE + _special_step * 0.2
	if _special_step < 9 and state_t >= step_t:
		var x := global_position.x + facing * (3.0 + _special_step * 4.5)
		var c := Vector3(x, 1.5, global_position.z)
		_special_step += 1
		var hits := strike(c, 3.8, 14.0 * power, Vector3(6, 16, 0), "enemies", 0.0)
		for b in get_tree().get_nodes_in_group("buildings"):
			b.try_hit(Vector3(x, 1.5, clampf(global_position.z - 3.0, -7.6, 5.0)), 3.5, 40.0 * power)
		FX.dust(c, 1.4)
		FX.debris_burst(c, 1.2)
		FX.shockwave(Vector3(x, 0, c.z), 4.0, color())
		Game.shake(0.35)
		for i in hits:
			Game.register_hit()
	if state_t >= BEAM_TIME:
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
			if t.take_hit(5.0 * power, Vector3(facing * 4.0, 1.0, 0), self):
				Game.register_hit()
				FX.hit_spark(Vector3(tc.x - facing * r, origin.y, tc.z), 6.0)
	for b in get_tree().get_nodes_in_group("buildings"):
		b.try_beam(origin, facing, BEAM_LEN, 14.0)


func _on_hurt(dmg: float, _from: Node3D) -> void:
	add_rage(dmg * 0.35)
	Game.combo = 0
	if state == S.BEAM:
		hitstun = 0.0
		knock = Vector3.ZERO
		return
	_beam.visible = false
	_set_state(S.HURT)


func _on_death() -> void:
	_set_state(S.DEAD)
	_beam.visible = false
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
	model.glow = rage / RAGE_MAX
	model.eye_glow = 1.0 if state == S.BEAM else 0.0
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
