class_name Brute
extends Kaiju
## Melee enemy kaiju. Walks up, telegraphs a claw swipe, then attacks.
## The boss variant is bigger, armoured against light hits, and charges.

enum S { APPROACH, WINDUP, ATTACK, RECOVER, CHARGE_WINDUP, CHARGE, HURT, DEAD }

const PALETTES := [
	[Color(0.32, 0.3, 0.14), Color(0.55, 0.5, 0.3), Color(0.85, 0.45, 1.0), Color(1.0, 0.25, 0.2)],
	[Color(0.22, 0.2, 0.3), Color(0.5, 0.42, 0.5), Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.2)],
	[Color(0.35, 0.18, 0.12), Color(0.6, 0.45, 0.3), Color(0.4, 1.0, 0.5), Color(0.6, 1.0, 0.3)],
]

var is_boss := false
var hp_mul := 1.0
var state := S.APPROACH
var state_t := 0.0
var cooldown := 1.2
var speed := 4.5
var dmg := 12.0
var size_mul := 1.0
var _z_bias := 0.0
var _charge_hit := false


func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		size_mul = 1.5
		max_hp = 520.0
		speed = 5.0
		dmg = 18.0
	else:
		max_hp = 90.0
	max_hp *= hp_mul
	init_body(1.2 * size_mul, 6.0 * size_mul, Game.LAYER_ENEMY)
	hit_radius = 1.6 * size_mul
	hit_height = 3.0 * size_mul
	z_min = -5.2
	z_max = 3.0
	model = KaijuModel.new()
	add_child(model)
	model.scale = Vector3.ONE * size_mul
	if is_boss:
		model.build(Color(0.32, 0.08, 0.07), Color(0.55, 0.32, 0.2), Color(1.0, 0.35, 0.1), Color(1.0, 0.8, 0.15), true)
	else:
		var p: Array = PALETTES.pick_random()
		model.build(p[0], p[1], p[2], p[3], true)
	_z_bias = randf_range(-1.5, 1.5)
	cooldown = randf_range(0.8, 1.8)


func _physics_process(delta: float) -> void:
	state_t += delta
	cooldown -= delta
	var move := Vector3.ZERO
	var p := Game.nearest_player(global_position) as Kaiju
	match state:
		S.DEAD:
			pass
		S.HURT:
			hitstun -= delta
			if hitstun <= 0.0:
				_set_state(S.APPROACH)
		S.APPROACH:
			if p and not p.dead:
				move = _approach(p)
		S.WINDUP:
			if state_t >= (0.7 if is_boss else 0.55):
				_set_state(S.ATTACK)
				_do_attack()
		S.ATTACK:
			if state_t >= 0.25:
				_set_state(S.RECOVER)
		S.RECOVER:
			if state_t >= 0.6:
				cooldown = randf_range(1.0, 2.2)
				_set_state(S.APPROACH)
		S.CHARGE_WINDUP:
			if state_t >= 0.9:
				_charge_hit = false
				_set_state(S.CHARGE)
		S.CHARGE:
			move = Vector3(facing * 24.0, 0, 0)
			if fmod(state_t, 0.15) < delta:
				FX.dust(global_position, 1.0)
				Game.shake(0.1)
			strike(global_position + Vector3(facing * 2.5, 3.0, 0), 3.0, 0.0, Vector3.ZERO, "none", 40.0)
			if not _charge_hit and p and not p.dead and p.hit_center().distance_to(hit_center()) < 4.5:
				_charge_hit = true
				if p.take_hit(20.0, Vector3(facing * 24.0, 12.0, 0), self):
					FX.hit_spark(p.hit_center(), 20.0)
					Game.shake(0.6)
					Game.hitstop(0.1)
			if state_t >= 0.9:
				cooldown = 2.0
				_set_state(S.RECOVER)
	move_body(delta, move)
	_animate(delta, move)


func _set_state(s: S) -> void:
	state = s
	state_t = 0.0


func _approach(p: Kaiju) -> Vector3:
	var dx := p.global_position.x - global_position.x
	var dz := (p.global_position.z + _z_bias * 0.3) - global_position.z
	face_toward(dx)
	var want := 3.8 * size_mul
	var mv := Vector3.ZERO
	if absf(dx) > want:
		mv.x = signf(dx) * speed
	elif absf(dx) < want - 1.3:
		mv.x = -signf(dx) * speed * 0.6
	if absf(dz) > 0.5:
		mv.z = signf(dz) * speed * 0.7
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Brute) or e.dead:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0.0
		if d.length() < 3.5 and d.length() > 0.01:
			mv += d.normalized() * 3.0
	if cooldown <= 0.0:
		if is_boss and absf(dx) > 11.0:
			_set_state(S.CHARGE_WINDUP)
			Game.shake(0.3)
			return Vector3.ZERO
		if absf(dx) < want + 0.8 and absf(dz) < 1.6:
			_set_state(S.WINDUP)
			return Vector3.ZERO
	return mv


func _do_attack() -> void:
	var center := global_position + Vector3(facing * 2.8 * size_mul, 3.0 * size_mul, 0)
	var hits := strike(center, 2.3 * size_mul, dmg, Vector3(10, 4, 0), "player")
	if hits > 0:
		Game.shake(0.35)
		Game.hitstop(0.06)


func _on_hurt(_dmg: float, _from: Node3D) -> void:
	if is_boss:
		knock *= 0.35
		if knock.length() < 5.0 or state == S.CHARGE or state == S.CHARGE_WINDUP:
			hitstun = 0.0
			return
	_set_state(S.HURT)


func _on_death() -> void:
	_set_state(S.DEAD)
	collision_layer = 0
	Game.add_score(10000 if is_boss else 1500)
	died.emit(self)
	if is_boss:
		FX.explosion(hit_center(), 2.5)
		Game.shake(1.0)
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", 1.5, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		FX.dust(global_position, 1.5 * size_mul)
		Game.shake(0.4))
	tw.tween_interval(1.6)
	tw.tween_property(self, "position:y", -8.0 * size_mul, 2.0)
	tw.tween_callback(queue_free)


func _animate(delta: float, move: Vector3) -> void:
	model.walk_amount = clampf(Vector2(move.x, move.z).length() / speed, 0.0, 1.0) if state == S.APPROACH else 0.0
	model.walk_speed = 0.8
	var ar := 0.25
	var al := 0.25
	var jaw := 0.0
	var lean := 0.0
	model.eye_glow = 0.0
	match state:
		S.WINDUP:
			ar = 2.8
			lean = -0.25
			jaw = 0.5
			model.eye_glow = 1.0
		S.ATTACK:
			ar = 0.9
			al = 0.6
			lean = 0.45
		S.RECOVER:
			ar = 0.6
			lean = 0.15
		S.CHARGE_WINDUP:
			jaw = 1.0
			lean = -0.4
			ar = 1.6
			al = 1.6
			model.eye_glow = 1.0
		S.CHARGE:
			lean = 0.6
			ar = -0.4
			al = -0.4
			model.walk_amount = 1.0
			model.walk_speed = 2.2
		S.HURT:
			lean = -0.35
			jaw = 0.5
	model.arm_r = ar
	model.arm_l = al
	model.jaw = jaw
	model.lean = lean
	if state != S.DEAD:
		update_model_facing(delta)
