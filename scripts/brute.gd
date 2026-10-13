class_name Brute
extends Kaiju
## Enemy kaiju. `kind` picks the variant:
##   crawler - small and fast, weak claw swipe
##   brute   - standard melee kaiju
##   elite   - bigger, armoured, can charge (mini-boss)
##   boss    - a country's boss; its moves come from `boss_def`
## Every move is telegraphed (wind-up pose + glowing eyes) before it lands.

signal spawned_minion(node: Node)

enum S { APPROACH, WINDUP, ACT, RECOVER, HURT, DEAD }

const PALETTES := [
	[Color(0.32, 0.3, 0.14), Color(0.55, 0.5, 0.3), Color(0.85, 0.45, 1.0), Color(1.0, 0.25, 0.2)],
	[Color(0.22, 0.2, 0.3), Color(0.5, 0.42, 0.5), Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.2)],
	[Color(0.35, 0.18, 0.12), Color(0.6, 0.45, 0.3), Color(0.4, 1.0, 0.5), Color(0.6, 1.0, 0.3)],
	[Color(0.18, 0.28, 0.35), Color(0.5, 0.55, 0.55), Color(1.0, 0.4, 0.4), Color(1.0, 0.5, 0.2)],
]
const WINDUP := {"swipe": 0.55, "charge": 0.9, "slam": 0.9, "breath": 0.7, "summon": 1.0, "leap": 0.5}
const SCORE := {"crawler": 800, "brute": 1500, "elite": 3000, "boss": 10000}

var kind := "brute"
var boss_def: Dictionary = {}
var hp_mul := 1.0
var dmg_mul := 1.0
var state := S.APPROACH
var state_t := 0.0
var cooldown := 1.2
var speed := 4.5
var dmg := 12.0
var size_mul := 1.0
var moves: Array = ["swipe"]
var move := ""
var _z_bias := 0.0
var _charge_hit := false
var _fire_t := 0.0
var _leap_vx := 0.0
var _windup_mul := 1.0
var _armoured := false
var _base_cooldown := Vector2(1.0, 2.2)


func is_boss() -> bool:
	return kind == "boss"


func _ready() -> void:
	add_to_group("enemies")
	var pal: Array = PALETTES.pick_random()
	var colors: Array = [pal[0], pal[1], pal[2], pal[3]]
	match kind:
		"crawler":
			size_mul = 0.72
			max_hp = 45.0
			speed = 7.5
			dmg = 7.0
			_windup_mul = 0.75
		"elite":
			size_mul = 1.22
			max_hp = 220.0
			speed = 5.0
			dmg = 16.0
			moves = ["swipe", "charge"]
			_armoured = true
			colors = [pal[0].darkened(0.3), pal[1], Color(1.0, 0.2, 0.2), Color(1.0, 0.1, 0.1)]
		"boss":
			size_mul = boss_def.get("scale", 1.5)
			max_hp = boss_def.get("hp", 520.0)
			speed = boss_def.get("speed", 5.0)
			dmg = boss_def.get("dmg", 18.0)
			moves = boss_def.get("moves", ["swipe", "charge"])
			_armoured = true
			var c: float = boss_def.get("cooldown", 1.4)
			_base_cooldown = Vector2(c * 0.6, c * 1.2)
			colors = [boss_def.get("skin", Color(0.32, 0.08, 0.07)), boss_def.get("belly", Color(0.55, 0.32, 0.2)),
				boss_def.get("accent", Color(1.0, 0.35, 0.1)), boss_def.get("eye", Color(1.0, 0.8, 0.15))]
		_:
			max_hp = 90.0
	max_hp *= hp_mul
	dmg *= dmg_mul
	init_body(1.2 * size_mul, 6.0 * size_mul, Game.LAYER_ENEMY)
	hit_radius = 1.6 * size_mul
	hit_height = 3.0 * size_mul
	z_min = -5.2
	z_max = 3.0
	model = KaijuModel.new()
	add_child(model)
	model.scale = Vector3.ONE * size_mul
	model.build(colors[0], colors[1], colors[2], colors[3], kind != "crawler")
	_z_bias = randf_range(-1.5, 1.5)
	cooldown = randf_range(0.8, 1.8)


func display_name() -> String:
	if is_boss():
		return "%s, %s" % [boss_def.get("name", "BOSS"), String(boss_def.get("title", "")).to_upper()]
	return kind.to_upper()


func _physics_process(delta: float) -> void:
	state_t += delta
	cooldown -= delta
	var mv := Vector3.ZERO
	var p := Game.nearest_player(global_position) as Kaiju
	if frozen_t > 0.0 and not dead:
		move_body(delta, Vector3.ZERO)
		model.walk_amount = 0.0
		return
	match state:
		S.DEAD:
			pass
		S.HURT:
			hitstun -= delta
			if hitstun <= 0.0:
				_set_state(S.APPROACH)
		S.APPROACH:
			if p and not p.dead:
				mv = _approach(p)
		S.WINDUP:
			if p:
				face_toward(p.global_position.x - global_position.x)
			var wind: float = WINDUP[move] * _windup_mul * (1.25 if is_boss() and move == "swipe" else 1.0)
			if state_t >= wind:
				_begin_act(p)
		S.ACT:
			mv = _act(delta, p)
		S.RECOVER:
			if state_t >= 0.6:
				cooldown = randf_range(_base_cooldown.x, _base_cooldown.y)
				_set_state(S.APPROACH)
	move_body(delta, mv)
	_animate(delta, mv)


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
		var choice := _pick_move(absf(dx), absf(dz), want)
		if choice != "":
			move = choice
			_set_state(S.WINDUP)
			if move != "swipe":
				Game.shake(0.25)
			return Vector3.ZERO
	return mv


func _pick_move(adx: float, adz: float, want: float) -> String:
	var options: Array = []
	if adx < want + 0.8 and adz < 1.6:
		options.append("swipe")
		if "slam" in moves:
			options.append("slam")
	if "charge" in moves and adx > 10.0:
		options.append("charge")
	if "breath" in moves and adx > 6.0 and adx < 22.0:
		options.append("breath")
	if "leap" in moves and adx > 7.0 and adx < 20.0:
		options.append("leap")
	if "summon" in moves and randf() < 0.3 and get_tree().get_nodes_in_group("enemies").size() < 5:
		options.append("summon")
	if options.is_empty():
		return ""
	return options.pick_random()


func _begin_act(p: Kaiju) -> void:
	_set_state(S.ACT)
	match move:
		"swipe":
			var center := global_position + Vector3(facing * 2.8 * size_mul, 3.0 * size_mul, 0)
			if strike(center, 2.3 * size_mul, dmg, Vector3(10, 4, 0), "player") > 0:
				Game.shake(0.35)
				Game.hitstop(0.06)
		"charge":
			_charge_hit = false
		"slam":
			# Ground shockwave around the boss. Jumping players dodge it.
			var r := 7.0 * size_mul / 1.5
			FX.shockwave(global_position, r, Color(1.0, 0.6, 0.3))
			FX.dust(global_position, 2.0)
			Game.shake(0.7)
			for q in Game.living_players():
				var d: Vector3 = q.global_position - global_position
				if q.global_position.y < 1.2 and Vector2(d.x, d.z).length() < r:
					if q.take_hit(dmg * 0.9, Vector3(signf(d.x) * 14.0, 12.0, 0), self):
						FX.hit_spark(q.hit_center(), 14.0)
			strike(global_position + Vector3(0, 1, 0), r, 0.0, Vector3.ZERO, "none", 30.0)
		"breath":
			_fire_t = 0.0
		"summon":
			for i in 2:
				var f := Flyer.new()
				f.hp *= hp_mul * 0.6
				get_parent().add_child(f)
				f.global_position = global_position + Vector3(randf_range(-6, 6), 14.0, -2.0)
				spawned_minion.emit(f)
			FX.energy(hit_center() + Vector3(0, 2, 0), model.spike_color())
		"leap":
			velocity.y = 19.0
			var target_x := p.global_position.x if p else global_position.x + facing * 10.0
			_leap_vx = clampf(target_x - global_position.x, -22.0, 22.0)


func _act(delta: float, p: Kaiju) -> Vector3:
	match move:
		"swipe", "slam", "summon":
			if state_t >= 0.3:
				_set_state(S.RECOVER)
		"charge":
			if fmod(state_t, 0.15) < delta:
				FX.dust(global_position, 1.0)
				Game.shake(0.1)
			strike(global_position + Vector3(facing * 2.5, 3.0, 0), 3.0, 0.0, Vector3.ZERO, "none", 40.0)
			for q in Game.living_players():
				if not _charge_hit and q.hit_center().distance_to(hit_center()) < 2.5 + 2.0 * size_mul:
					_charge_hit = true
					if q.take_hit(dmg * 1.1, Vector3(facing * 24.0, 12.0, 0), self):
						FX.hit_spark(q.hit_center(), 20.0)
						Game.shake(0.6)
						Game.hitstop(0.1)
			if state_t >= 0.9:
				_set_state(S.RECOVER)
			return Vector3(facing * 24.0, 0, 0)
		"breath":
			_fire_t -= delta
			if _fire_t <= 0.0 and p:
				_fire_t = 0.18
				var b := Projectile.new()
				b.color = model.spike_color()
				b.damage = dmg * 0.5
				get_parent().add_child(b)
				b.global_position = global_position + Vector3(facing * 2.4 * size_mul, 4.6 * size_mul, 0)
				var aim := (p.hit_center() - b.global_position).normalized()
				b.velocity = aim.rotated(Vector3.UP, randf_range(-0.12, 0.12)) * 22.0
			if state_t >= 1.0:
				_set_state(S.RECOVER)
		"leap":
			if state_t > 0.2 and is_on_floor():
				var r := 5.5 * size_mul / 1.5
				FX.shockwave(global_position, r, Color(1.0, 0.7, 0.4))
				FX.dust(global_position, 2.0)
				Game.shake(0.8)
				for q in Game.living_players():
					var d: Vector3 = q.global_position - global_position
					if Vector2(d.x, d.z).length() < r + 1.0:
						if q.take_hit(dmg, Vector3(signf(d.x) * 16.0, 10.0, 0), self):
							FX.hit_spark(q.hit_center(), 16.0)
				strike(global_position + Vector3(0, 1, 0), r, 0.0, Vector3.ZERO, "none", 40.0)
				_set_state(S.RECOVER)
				return Vector3.ZERO
			if state_t > 2.5:
				_set_state(S.RECOVER)
			return Vector3(_leap_vx, 0, 0)
	return Vector3.ZERO


func _on_hurt(_dmg: float, _from: Node3D) -> void:
	if _armoured:
		knock *= 0.35
		if knock.length() < 5.0 or state == S.ACT or (state == S.WINDUP and move != "swipe"):
			hitstun = 0.0
			return
	_set_state(S.HURT)


func _on_death() -> void:
	_set_state(S.DEAD)
	collision_layer = 0
	Game.add_score(SCORE.get(kind, 1500))
	died.emit(self)
	if is_boss() or kind == "elite":
		FX.explosion(hit_center(), 2.5 if is_boss() else 1.5)
		Game.shake(1.0 if is_boss() else 0.5)
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", 1.5, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		FX.dust(global_position, 1.5 * size_mul)
		Game.shake(0.4))
	tw.tween_interval(1.6)
	tw.tween_property(self, "position:y", -8.0 * size_mul, 2.0)
	tw.tween_callback(queue_free)


func _animate(delta: float, mv: Vector3) -> void:
	model.walk_amount = clampf(Vector2(mv.x, mv.z).length() / speed, 0.0, 1.0) if state == S.APPROACH else 0.0
	model.walk_speed = 0.8 if kind != "crawler" else 1.4
	var ar := 0.25
	var al := 0.25
	var jaw := 0.0
	var lean := 0.0
	model.eye_glow = 0.0
	match state:
		S.WINDUP:
			model.eye_glow = 1.0
			match move:
				"swipe":
					ar = 2.8
					lean = -0.25
					jaw = 0.5
				"charge", "summon":
					jaw = 1.0
					lean = -0.4
					ar = 1.6
					al = 1.6
				"slam":
					ar = 3.0
					al = 3.0
					lean = -0.35
					jaw = 0.8
				"breath":
					jaw = 0.6
					lean = -0.45
				"leap":
					lean = 0.5
					ar = -0.5
					al = -0.5
		S.ACT:
			match move:
				"swipe":
					ar = 0.9
					al = 0.6
					lean = 0.45
				"charge":
					lean = 0.6
					ar = -0.4
					al = -0.4
					model.walk_amount = 1.0
					model.walk_speed = 2.2
				"slam":
					ar = 1.0
					al = 1.0
					lean = 0.5
				"breath":
					jaw = 1.0
					lean = 0.1
					model.eye_glow = 1.0
				"summon":
					jaw = 1.0
					ar = 2.2
					al = 2.2
				"leap":
					ar = 2.4
					al = 2.4
					lean = 0.3
		S.RECOVER:
			ar = 0.6
			lean = 0.15
		S.HURT:
			lean = -0.35
			jaw = 0.5
	model.arm_r = ar
	model.arm_l = al
	model.jaw = jaw
	model.lean = lean
	if state != S.DEAD:
		update_model_facing(delta)
