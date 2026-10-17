class_name Brute
extends Kaiju
## Enemy kaiju. `kind` is an Enemies.DEFS id (brute, crawler, rhinox, ...)
## whose data sets size, look, stats and move set, or "boss" (a country's
## boss; its moves come from `boss_def`).
## Moves: swipe, combo, charge, slam, breath, spit, summon, leap, explode,
## burrow, shock, lunge, hurl, plus the bosses' signature moves (SIGNATURES).
## Every move is telegraphed (a wind-up pose that builds up + glowing eyes).
## Big enemies (bosses and the large kaiju, see is_heavy()) wind up their
## direct hits for longer, shake with effort before letting go, stop turning
## and aiming partway through, and mark the ground they are about to hit
## (Telegraph), so a player who watches can step out of it. Every enemy, bosses included, uses a CreatureModel body
## plan (the def's "body"), never the heroes' upright kaiju model; bosses get
## the high-detail meshes. Insects fight hit-and-run,
## zigzagging in and hopping back after a bite.

signal spawned_minion(node: Node)

enum S { APPROACH, WINDUP, ACT, RECOVER, HURT, DEAD }

const PALETTES := [
	[Color(0.32, 0.3, 0.14), Color(0.55, 0.5, 0.3), Color(0.85, 0.45, 1.0), Color(1.0, 0.25, 0.2)],
	[Color(0.22, 0.2, 0.3), Color(0.5, 0.42, 0.5), Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.2)],
	[Color(0.35, 0.18, 0.12), Color(0.6, 0.45, 0.3), Color(0.4, 1.0, 0.5), Color(0.6, 1.0, 0.3)],
	[Color(0.18, 0.28, 0.35), Color(0.5, 0.55, 0.55), Color(1.0, 0.4, 0.4), Color(1.0, 0.5, 0.2)],
]
const WINDUP := {"swipe": 0.55, "charge": 0.9, "slam": 0.9, "breath": 0.7, "summon": 1.0, "leap": 0.5,
	"spit": 0.6, "combo": 0.45, "explode": 1.1, "burrow": 0.6, "shock": 0.8, "lunge": 0.5, "hurl": 0.75,
	"barrage": 0.9, "meteor": 1.0, "quake": 0.9, "storm": 0.9, "venom_rain": 0.8, "frenzy": 0.5,
	"sweep": 0.8, "sandstorm": 0.8, "dive": 0.6}
## Moves that hit straight off the wind-up. Big enemies wind these up longer
## and mark them on the ground; the others already drop their own warned
## hazards (meteor, storm, quake, shock...).
const DIRECT := ["swipe", "combo", "charge", "slam", "breath", "spit", "leap", "explode", "lunge", "hurl",
	"sweep", "sandstorm", "dive", "frenzy"]
## Wind-up multiplier for big enemies' direct hits (bosses get BOSS_WINDUP).
const HEAVY_WINDUP := 1.6
const BOSS_WINDUP := 1.75
## Share of a big enemy's wind-up after which it stops turning and aiming:
## from then on the marked area stays put.
const AIM_LOCK := 0.6
## Boss-only signature moves; a boss favours its own when it is in range.
const SIGNATURES := ["barrage", "meteor", "quake", "storm", "venom_rain", "frenzy", "sweep", "sandstorm", "dive"]
const ELEMENT_COLORS := {"fire": Color(1.0, 0.45, 0.08), "acid": Color(0.45, 1.0, 0.15),
	"venom": Color(0.8, 0.3, 1.0), "ice": Color(0.55, 0.9, 1.0), "plasma": Color(0.3, 0.8, 1.0)}

var kind := "brute"
var def: Dictionary = {}
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
var _shape := Vector3.ONE
var _range_mul := 1.0
var _walk_speed := 0.8
var _element := ""
var _summon := "drone"
var _combo_n := 0
var _burrowed := false
var _score := 1500
var _body := "ape"
## Height of the body relative to a hero kaiju; places hit boxes and muzzles.
var _tall := 1.0
## Where the current move is aimed; frozen once a big enemy locks its aim.
var _aim := Vector3.ZERO
var _aim_locked := false
var _tele: Telegraph


func is_boss() -> bool:
	return kind == "boss"


## Bosses and the big kaiju: slow, warned attacks you can get out of.
func is_heavy() -> bool:
	return is_boss() or size_mul >= 1.1


## How long the current move winds up.
func wind_time() -> float:
	var w: float = WINDUP[move] * _windup_mul
	if is_boss() and move == "swipe":
		w *= 1.25
	if move in DIRECT:
		if is_boss():
			w *= BOSS_WINDUP
		elif is_heavy():
			w *= HEAVY_WINDUP
	return w


func _ready() -> void:
	add_to_group("enemies")
	var pal: Array = PALETTES.pick_random()
	var colors: Array = [pal[0], pal[1], pal[2], pal[3]]
	var horns := true
	var extras: Array = []
	if kind == "boss":
		size_mul = boss_def.get("scale", 1.5)
		max_hp = boss_def.get("hp", 520.0)
		speed = boss_def.get("speed", 5.0)
		dmg = boss_def.get("dmg", 18.0)
		moves = boss_def.get("moves", ["swipe", "charge"])
		_armoured = true
		_score = 10000
		var c: float = boss_def.get("cooldown", 1.4)
		_base_cooldown = Vector2(c * 0.6, c * 1.2)
		colors = [boss_def.get("skin", Color(0.32, 0.08, 0.07)), boss_def.get("belly", Color(0.55, 0.32, 0.2)),
			boss_def.get("accent", Color(1.0, 0.35, 0.1)), boss_def.get("eye", Color(1.0, 0.8, 0.15))]
		_element = boss_def.get("element", "fire")
		_body = boss_def.get("body", "ape")
		extras = boss_def.get("extras", [])
		horns = boss_def.get("horns", true)
		_summon = boss_def.get("summon", "drone")
	else:
		if def.is_empty():
			def = Enemies.get_def(kind)
		size_mul = def.get("size", 1.0)
		max_hp = def.get("hp", 90.0)
		speed = def.get("speed", 4.5)
		dmg = def.get("dmg", 12.0)
		moves = def.get("moves", ["swipe"]).duplicate()
		_armoured = def.get("armour", false)
		_windup_mul = def.get("windup", 1.0)
		_base_cooldown = def.get("cooldown", Vector2(1.0, 2.2))
		_shape = def.get("shape", Vector3.ONE)
		_range_mul = def.get("range", 1.0)
		_walk_speed = def.get("walk", 0.8)
		_element = def.get("element", "fire")
		_summon = def.get("summon", "drone")
		_score = def.get("score", 1500)
		horns = def.get("horns", false)
		extras = def.get("extras", [])
		_body = def.get("body", "ape")
		var cdef = def.get("colors", "random")
		if cdef is Array:
			colors = cdef
		elif cdef == "elite":
			colors = [pal[0].darkened(0.3), pal[1], Color(1.0, 0.2, 0.2), Color(1.0, 0.1, 0.1)]
		if kind == "elite":
			# Elites learn more tricks the further the campaign goes.
			var ci: int = Game.level.get("country", 0)
			if ci >= 3:
				moves.append("leap")
			if ci >= 6:
				moves.append("slam")
			if ci >= 8:
				moves.append("breath")
	max_hp *= hp_mul
	dmg *= dmg_mul
	_tall = _shape.y * float(CreatureModel.HEIGHT.get(_body, 1.0))
	init_body(1.2 * size_mul, 6.0 * size_mul * _tall, Game.LAYER_ENEMY)
	hit_radius = 1.6 * size_mul * maxf(1.0, (_shape.x + _shape.z) * 0.5)
	hit_height = 3.0 * size_mul * maxf(_tall, 0.6)
	z_min = -5.2
	z_max = 3.0
	var cm := CreatureModel.new()
	cm.plan = _body if CreatureModel.HEIGHT.has(_body) else "ape"
	cm.extras = extras
	cm.detail = 2 if kind == "boss" else 1
	model = cm
	add_child(model)
	model.scale = _shape * size_mul
	model.build(colors[0], colors[1], colors[2], colors[3], horns)
	# Big bodies move slower and swing further; small bugs are snappy.
	model.heft = clampf(sqrt(size_mul * maxf(_shape.x, 1.0)), 0.75, 1.7)
	_z_bias = randf_range(-1.5, 1.5)
	cooldown = randf_range(0.8, 1.8)


func _elem_color() -> Color:
	if kind == "boss":
		return model.spike_color()
	return ELEMENT_COLORS.get(_element, model.spike_color())


func display_name() -> String:
	if is_boss():
		return "%s, %s" % [boss_def.get("name", "BOSS"), String(boss_def.get("title", "")).to_upper()]
	return String(def.get("name", kind.to_upper()))


func _physics_process(delta: float) -> void:
	state_t += delta
	cooldown -= delta
	var mv := Vector3.ZERO
	var p := Game.nearest_player(global_position) as Kaiju
	if frozen_t > 0.0 and not dead:
		move_body(delta, Vector3.ZERO)
		model.walk_amount = 0.0
		return
	if _burrowed and not (state == S.ACT and move == "burrow"):
		_surface(false)
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
			var wind := wind_time()
			if p and not _aim_locked:
				face_toward(p.global_position.x - global_position.x)
				_aim = p.global_position
			if is_heavy() and state_t >= wind * AIM_LOCK:
				_aim_locked = true
			_place_telegraph()
			if state_t >= wind:
				_begin_act(p)
		S.ACT:
			mv = _act(delta, p)
		S.RECOVER:
			# Big ones take a moment to gather themselves: a window to hit back.
			if state_t >= (0.9 if is_heavy() else 0.6):
				cooldown = randf_range(_base_cooldown.x, _base_cooldown.y)
				_set_state(S.APPROACH)
	if state == S.DEAD and move == "explode":
		return
	move_body(delta, mv)
	_animate(delta, mv)


func _set_state(s: S) -> void:
	if s == S.RECOVER and _body == "insect" and move in ["swipe", "combo"] and is_on_floor():
		# Hit and run: hop back out of reach after biting.
		knock = Vector3(-facing * 14.0, 7.0, 0)
	if (state == S.WINDUP and s != S.ACT or s == S.DEAD) and _tele:
		# Interrupted before letting go.
		_tele.cancel()
		_tele = null
	state = s
	state_t = 0.0
	if s == S.WINDUP:
		_aim_locked = false
		var p := Game.nearest_player(global_position)
		_aim = p.global_position if p else global_position + Vector3(facing * 8.0, 0, 0)
		if is_heavy() and move in DIRECT:
			_new_telegraph()


func _melee_range() -> float:
	return 3.8 * size_mul * maxf(_shape.x, 1.0)


func _approach(p: Kaiju) -> Vector3:
	var dx := p.global_position.x - global_position.x
	var dz := (p.global_position.z + _z_bias * 0.3) - global_position.z
	face_toward(dx)
	var melee := _melee_range()
	var want := melee * _range_mul
	var mv := Vector3.ZERO
	if not in_arena():
		# Still behind the gate: come in before doing anything else.
		mv.x = signf((arena.x + arena.y) * 0.5 - global_position.x) * speed
		if absf(dz) > 0.5:
			mv.z = signf(dz) * speed * 0.7
		return mv
	if arena.x > x_min or arena.y < x_max:
		# Inside now: no retreating back out behind the gates.
		x_min = maxf(x_min, arena.x)
		x_max = minf(x_max, arena.y)
	if absf(dx) > want:
		mv.x = signf(dx) * speed
	elif absf(dx) < want - 1.3:
		# Back off, but never out of the arena.
		var nx := global_position.x - signf(dx) * 2.0
		if nx > x_min + 1.0 and nx < x_max - 1.0:
			mv.x = -signf(dx) * speed * 0.6
	if absf(dz) > 0.5:
		mv.z = signf(dz) * speed * 0.7
	if _body == "insect" and absf(dx) > want:
		mv.z += sin(state_t * 5.0 + _z_bias * 3.0) * speed * 0.6
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Brute) or e.dead:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0.0
		var sep: float = 2.2 + 1.3 * (size_mul + e.size_mul) * 0.5
		if d.length() < sep and d.length() > 0.01:
			mv += d.normalized() * 3.0
	if cooldown <= 0.0:
		var choice := _pick_move(absf(dx), absf(dz), melee)
		if choice != "":
			move = choice
			_set_state(S.WINDUP)
			if move != "swipe" and move != "combo":
				Game.shake(0.25 * clampf(size_mul, 0.4, 1.5))
			if move == "hurl":
				# Rips a chunk out of the street to throw.
				FX.dust(global_position + Vector3(facing * 1.5 * size_mul, 0, 0), 1.2 * size_mul)
				FX.debris_burst(global_position + Vector3(facing * 1.5 * size_mul, 0.5, 0), 0.8)
			return Vector3.ZERO
	return mv


func _pick_move(adx: float, adz: float, melee: float) -> String:
	var options: Array = []
	if adx < melee + 0.8 and adz < 1.6:
		for m in ["swipe", "slam", "combo"]:
			if m in moves:
				options.append(m)
	if "explode" in moves and adx < melee + 1.5 and adz < 2.2:
		options.append("explode")
	if options.is_empty() and adx < melee + 0.8 and adz < 1.6 and not ("explode" in moves):
		options.append("swipe")
	if "charge" in moves and adx > 10.0:
		options.append("charge")
	if "lunge" in moves and adx > melee + 0.5 and adx < melee + 9.0 and adz < 1.6:
		options.append("lunge")
	if "hurl" in moves and adx > 8.0 and adx < 24.0 and randf() < 0.6:
		options.append("hurl")
	if "breath" in moves and adx > 6.0 and adx < 22.0:
		options.append("breath")
	if "spit" in moves and adx > 5.0 and adx < 20.0:
		options.append("spit")
	if "leap" in moves and adx > 7.0 and adx < 20.0:
		options.append("leap")
	if "burrow" in moves and adx > 6.0 and adx < 24.0 and randf() < 0.6:
		options.append("burrow")
	if "shock" in moves and adx < 26.0 and randf() < 0.5:
		options.append("shock")
	if "summon" in moves and randf() < 0.3:
		var limit := 5 if _summon == "drone" else 9
		if get_tree().get_nodes_in_group("enemies").size() < limit:
			options.append("summon")
	for m in SIGNATURES:
		if m in moves and _signature_ok(m, adx, melee) and randf() < 0.55:
			options.append(m)
			options.append(m)
	if options.is_empty():
		return ""
	return options.pick_random()


func _signature_ok(m: String, adx: float, melee: float) -> bool:
	match m:
		"barrage", "dive", "frenzy":
			return adx > 6.0 and adx < 26.0
		"quake":
			return adx < 22.0
		"venom_rain", "sandstorm":
			return adx > 4.0 and adx < 22.0
		"sweep":
			return adx < melee + 3.0
	return true


func _swipe(mul: float) -> void:
	var center := global_position + Vector3(facing * 2.8 * size_mul * maxf(_shape.x, 1.0), 3.0 * size_mul * maxf(_tall, 0.6), 0)
	if strike(center, 2.3 * size_mul, dmg * mul, Vector3(10, 4, 0), "player") > 0:
		Game.shake(0.35)
		Game.hitstop(0.06)


func _begin_act(p: Kaiju) -> void:
	if _tele:
		_tele.release(_telegraph_hold())
		_tele = null
	_set_state(S.ACT)
	match move:
		"swipe":
			_swipe(1.0)
		"combo":
			_combo_n = 1
			_swipe(0.8)
		"charge", "lunge":
			_charge_hit = false
		"hurl":
			if p:
				_hurl(_aim)
		"slam":
			# Ground shockwave around the kaiju. Jumping players dodge it.
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
		"spit":
			if p:
				_glob_at(Vector3(_aim.x, 0.2, _aim.z))
		"summon":
			_do_summon()
		"leap", "frenzy", "dive":
			_combo_n = 1
			_jump_at(p, 30.0 if move == "dive" else 19.0)
		"barrage", "sandstorm":
			_combo_n = 0
			_fire_t = 0.0
		"meteor":
			# Burning rocks rain down on marked spots around every player.
			FX.energy(hit_center() + Vector3(0, 3, 0), _elem_color())
			Game.shake(0.5)
			for q in Game.living_players():
				for i in 4:
					_hazard("shell", Vector3(q.global_position.x + randf_range(-6, 6), 0, q.global_position.z + randf_range(-2, 2)),
						3.0, 1.1 + i * 0.3, dmg * 0.9, Color(1.0, 0.4, 0.05), "fire")
		"quake":
			# Shockwaves ripple outward along the street on both sides.
			FX.shockwave(global_position, 6.0, Color(1.0, 0.7, 0.4))
			Game.shake(0.9)
			var z := p.global_position.z if p else global_position.z
			for k in range(1, 7):
				for side in [-1.0, 1.0]:
					_hazard("blast", Vector3(global_position.x + side * k * 4.0, 0, z), 2.6, 0.45 + k * 0.22, dmg * 0.8,
						Color(1.0, 0.6, 0.3), "")
		"storm":
			FX.bolt(hit_center() + Vector3(0, 3, 0), hit_center() + Vector3(0, 18, -1), _elem_color())
			for q in Game.living_players():
				for i in 3:
					var lead: Vector3 = q.velocity * (0.4 + i * 0.3)
					_hazard("bolt", Vector3(q.global_position.x + lead.x + randf_range(-2, 2), 0, q.global_position.z),
						2.8, 0.8 + i * 0.55, dmg, _elem_color(), "")
		"venom_rain":
			if p:
				for i in 5:
					var to := Vector3(p.global_position.x + (i - 2) * 3.2, 0.2, p.global_position.z + randf_range(-2, 2))
					_glob_at(to)
					if is_heavy():
						_mark(to, 2.6, _glob_time(to), _elem_color())
		"sweep":
			# Full spin with the tail: hits all round, jumping clears it.
			var r := 4.5 * size_mul
			FX.shockwave(global_position, r, Color(1.0, 0.85, 0.5))
			FX.dust(global_position, 2.5)
			Game.shake(0.7)
			for q in Game.living_players():
				var d: Vector3 = q.global_position - global_position
				if q.global_position.y < 1.4 and Vector2(d.x, d.z).length() < r:
					if q.take_hit(dmg * 1.2, Vector3(signf(d.x) * 22.0, 10.0, 0), self):
						FX.hit_spark(q.hit_center(), 18.0)
			strike(global_position + Vector3(0, 1, 0), r, 0.0, Vector3.ZERO, "none", 40.0)
			create_tween().tween_property(model, "spin", TAU, 0.45).from(0.0)
		"explode":
			_explode()
		"burrow":
			_burrowed = true
			invuln = 99.0
			model.visible = false
			FX.dust(global_position, 2.0 * size_mul)
			FX.debris_burst(global_position + Vector3(0, 0.5, 0), 1.0)
			Game.shake(0.3)
		"shock":
			var c := _elem_color() if _element != "fire" else model.spike_color()
			FX.bolt(hit_center() + Vector3(0, 2, 0), hit_center() + Vector3(randf_range(-2, 2), 14, -1), c)
			for q in Game.living_players():
				var h := Hazard.new()
				h.style = "bolt"
				h.radius = 2.8
				h.delay = 0.9
				h.damage = dmg
				h.color = c
				get_parent().add_child(h)
				var lead: Vector3 = q.velocity * 0.4
				h.global_position = Vector3(q.global_position.x + lead.x, 0.0, q.global_position.z)


func _glob_at(to: Vector3) -> void:
	var b := Projectile.new()
	b.style = "glob"
	b.color = _elem_color()
	b.element = _element
	b.damage = dmg * 0.8
	b.gravity = 22.0
	b.splash = 2.4
	b.size = 1.3
	get_parent().add_child(b)
	var start := global_position + Vector3(facing * 2.0 * size_mul, 4.4 * size_mul * _tall, 0)
	b.global_position = start
	var t := _glob_time(to)
	var v := (to - start) / t
	v.y += 0.5 * b.gravity * t
	b.velocity = v
	FX.light_flash(start, b.color, 4.0, 6.0, 0.15)


## Seconds an arcing glob takes to reach `to`.
func _glob_time(to: Vector3) -> float:
	return clampf(absf(to.x - (global_position.x + facing * 2.0 * size_mul)) / 15.0, 0.6, 1.3)


## Throws a boulder (magma rock for a fire golem) in an arc at a spot.
func _hurl(at: Vector3) -> void:
	var b := Projectile.new()
	b.style = "boulder"
	b.element = _element if _body == "golem" else ""
	b.color = _elem_color() if b.element != "" else Color(1.0, 0.65, 0.35)
	b.damage = dmg * 1.1
	b.gravity = 26.0
	b.splash = 2.8
	b.size = 1.5 * size_mul
	get_parent().add_child(b)
	var start := global_position + Vector3(facing * 1.0 * size_mul, 6.0 * size_mul * _tall, 0)
	b.global_position = start
	var to := Vector3(at.x, 0.2, at.z)
	var t := clampf(absf(to.x - start.x) / 16.0, 0.7, 1.4)
	var v := (to - start) / t
	v.y += 0.5 * b.gravity * t
	b.velocity = v
	FX.debris_burst(start, 0.6)
	Game.shake(0.3)


func _jump_at(p: Kaiju, vy: float) -> void:
	velocity.y = vy
	# The first jump comes down where the wind-up aimed; frenzy's follow-up
	# pounces go for wherever the player is now.
	var target_x := _aim.x
	if _combo_n > 1:
		target_x = p.global_position.x if p else global_position.x + facing * 10.0
	_leap_vx = _leap_speed(target_x, vy)


## Sideways speed of a leap that should come down at target_x.
func _leap_speed(target_x: float, vy: float) -> float:
	var t := 2.0 * vy / GRAVITY
	if move == "dive":
		return clampf((target_x - global_position.x) / t, -26.0, 26.0)
	return clampf(target_x - global_position.x, -22.0, 22.0)


# --- ground warnings for big enemies --------------------------------------

func _new_telegraph() -> void:
	var th := _threat()
	if th.is_empty():
		return
	_tele = Telegraph.new()
	_tele.shape = th[0]
	if th[0] == "lane":
		_tele.length = th[2]
		_tele.width = th[3]
	else:
		_tele.radius = th[2]
	_tele.duration = wind_time()
	_tele.color = _elem_color() if move in ["breath", "spit", "sandstorm"] else Color(1.0, 0.22, 0.08)
	get_parent().add_child(_tele)
	_place_telegraph()


## A ground warning that lets go by itself after `secs` (for things already
## on their way).
func _mark(at: Vector3, r: float, secs: float, c: Color) -> void:
	var w := Telegraph.new()
	w.radius = r
	w.duration = secs
	w.color = c
	w.auto = true
	get_parent().add_child(w)
	w.global_position = Vector3(at.x, 0.0, at.z)


## Keeps the warning on the area the move will hit (it stops following the
## player once the aim locks).
func _place_telegraph() -> void:
	if not _tele:
		return
	var th := _threat()
	if th.is_empty():
		return
	var at: Vector3 = th[1]
	at.y = 0.0
	_tele.global_position = at
	if th[0] == "lane":
		var dir := Vector3(facing, 0, 0)
		if move == "breath":
			dir = Vector3(_aim.x - global_position.x, 0, _aim.z - global_position.z)
			if dir.length() < 0.5 or signf(dir.x) != facing:
				dir = Vector3(facing, 0, 0)
		_tele.rotation.y = atan2(-dir.z, dir.x)


## What the current move will hit: [shape, ground point, radius] for a
## circle or [shape, start, length, width] for a lane along the facing.
func _threat() -> Array:
	var g := Vector3(global_position.x, 0.0, global_position.z)
	var reach := 2.8 * size_mul * maxf(_shape.x, 1.0)
	match move:
		"swipe":
			return ["circle", g + Vector3(facing * reach, 0, 0), 2.3 * size_mul + 0.8]
		"combo":
			return ["lane", g, reach + 2.3 * size_mul + 4.0, 4.6 * size_mul]
		"slam":
			return ["circle", g, 7.0 * size_mul / 1.5]
		"sweep":
			return ["circle", g, 4.5 * size_mul]
		"explode":
			return ["circle", g, 4.5 * maxf(size_mul, 0.8)]
		"charge":
			return ["lane", g, 24.0 * 0.9 + 2.5 + 2.0 * size_mul, 3.0 + 2.0 * size_mul]
		"lunge":
			return ["lane", g, 26.0 * 0.3 + 2.5 + 3.9 * size_mul, 4.8 * size_mul]
		"breath", "sandstorm":
			return ["lane", g, 20.0, 5.0]
		"spit":
			return ["circle", Vector3(_aim.x, 0, _aim.z), 2.4]
		"hurl":
			return ["circle", Vector3(_aim.x, 0, _aim.z), 2.8]
		"leap", "frenzy", "dive":
			var vy := 30.0 if move == "dive" else 19.0
			var x := global_position.x + _leap_speed(_aim.x, vy) * 2.0 * vy / GRAVITY
			var r := 5.5 * size_mul / 1.5 * (1.6 if move == "dive" else 1.0) + 1.0
			return ["circle", Vector3(clampf(x, x_min, x_max), 0, global_position.z), r]
	return []


## How long the warning stays after the attack lets go: until the boulder,
## glob or leap comes down, or the charge or breath is over.
func _telegraph_hold() -> float:
	match move:
		"hurl":
			return clampf(absf(_aim.x - global_position.x) / 16.0, 0.7, 1.4)
		"spit":
			return clampf(absf(_aim.x - global_position.x) / 15.0, 0.6, 1.3)
		"leap", "frenzy":
			return 1.0
		"dive":
			return 1.6
		"charge", "combo":
			return 0.8
		"breath":
			return 1.0
		"sandstorm":
			return 1.4
	return 0.0


func _hazard(style: String, pos: Vector3, radius: float, delay: float, damage: float, color: Color, element: String) -> void:
	var h := Hazard.new()
	h.style = style
	h.radius = radius
	h.delay = delay
	h.damage = damage
	h.color = color
	h.element = element
	get_parent().add_child(h)
	pos.x = clampf(pos.x, x_min, x_max)
	h.global_position = pos


func _do_summon() -> void:
	for i in 2:
		var m: Node3D
		if Enemies.get_def(_summon)["class"] == "infantry":
			var s := Infantry.new()
			s.kind = _summon
			s.hp_mul = hp_mul
			s.dmg_mul = dmg_mul
			s.arena = arena
			m = s
			get_parent().add_child(s)
			s.global_position = global_position + Vector3(-facing * (3.0 + i * 1.5), 0.3, (i - 0.5) * 2.0)
		elif _summon == "drone":
			var f := Flyer.new()
			f.kind = "drone"
			f.hp_mul = hp_mul * 0.6
			f.dmg_mul = dmg_mul
			f.arena = arena
			m = f
			get_parent().add_child(f)
			f.global_position = global_position + Vector3(randf_range(-6, 6), 14.0, -2.0)
		else:
			var b := Brute.new()
			b.kind = _summon
			b.hp_mul = hp_mul * 0.8
			b.dmg_mul = dmg_mul
			b.x_min = x_min
			b.x_max = x_max
			b.arena = arena
			m = b
			get_parent().add_child(b)
			b.global_position = global_position + Vector3(facing * (2.5 + i * 1.5), 0.5, (i - 0.5) * 2.0)
			b.facing = facing
			b.velocity.y = 8.0
		spawned_minion.emit(m)
	FX.energy(hit_center() + Vector3(0, 2, 0), model.spike_color())


## Self-destruct: a big blast that also takes out this kaiju.
func _explode() -> void:
	var r := 4.5 * maxf(size_mul, 0.8)
	var pos := global_position + Vector3(0, 1.0, 0)
	FX.explosion(pos, 1.6)
	FX.shockwave(global_position, r, Color(1.0, 0.55, 0.15))
	Game.shake(0.6)
	for q in Game.living_players():
		var d: Vector3 = q.global_position - global_position
		if Vector2(d.x, d.z).length() < r + q.hit_radius * 0.5:
			if q.take_hit(dmg, Vector3(signf(d.x) * 16.0, 12.0, 0), self):
				FX.hit_spark(q.hit_center(), 16.0)
				Projectile.apply_element(q, "fire", dmg * 0.5)
	strike(pos, r, 0.0, Vector3.ZERO, "none", 60.0)
	hp = 0.0
	dead = true
	health_changed.emit(hp, max_hp)
	_set_state(S.DEAD)
	collision_layer = 0
	model.visible = false
	Game.add_score(_score / 2)
	died.emit(self)
	get_tree().create_timer(0.2, false).timeout.connect(queue_free)


## Comes back up from underground; erupting under someone hurts them.
func _surface(attack: bool) -> void:
	_burrowed = false
	invuln = 0.0
	model.visible = true
	FX.dust(global_position, 2.0 * size_mul)
	FX.debris_burst(global_position + Vector3(0, 0.5, 0), 1.2)
	if not attack:
		return
	var r := 3.6 * size_mul
	FX.shockwave(global_position, r, model.spike_color())
	FX.energy(global_position + Vector3(0, 1.5, 0), model.spike_color())
	Game.shake(0.6)
	for q in Game.living_players():
		var d: Vector3 = q.global_position - global_position
		if Vector2(d.x, d.z).length() < r + q.hit_radius * 0.5 and q.global_position.y < 2.5:
			if q.take_hit(dmg * 1.2, Vector3(signf(d.x) * 6.0, 18.0, 0), self):
				FX.hit_spark(q.hit_center(), 16.0)
	strike(global_position + Vector3(0, 1, 0), r, 0.0, Vector3.ZERO, "none", 30.0)


func _act(delta: float, p: Kaiju) -> Vector3:
	match move:
		"swipe", "slam", "summon", "spit", "shock", "hurl", "meteor", "quake", "storm", "venom_rain", "sweep":
			if state_t >= (0.6 if move == "sweep" else 0.3):
				_set_state(S.RECOVER)
		"barrage":
			# A volley of homing missiles from the back.
			_fire_t -= delta
			if _fire_t <= 0.0 and _combo_n < 6:
				_fire_t = 0.14
				_combo_n += 1
				var b := Projectile.new()
				b.style = "missile"
				b.color = Color(1.0, 0.55, 0.2)
				b.damage = dmg * 0.6
				b.splash = 2.0
				b.homing = 2.4
				b.homing_delay = 0.5
				if is_heavy():
					b.homing_until = 1.2
				b.target = Game.living_players().pick_random() if not Game.living_players().is_empty() else p
				b.velocity = Vector3(-facing * randf_range(2.0, 6.0), 16.0, randf_range(-3.0, 3.0))
				get_parent().add_child(b)
				b.global_position = global_position + Vector3(-facing * 1.0 * size_mul, 6.0 * size_mul * _tall, 0)
				FX.smoke(b.global_position, 0.6, Color(0.75, 0.75, 0.72))
			if state_t >= 1.3:
				_set_state(S.RECOVER)
		"sandstorm":
			# A breath that sweeps from high to low across the street.
			_fire_t -= delta
			if _fire_t <= 0.0:
				_fire_t = 0.07
				var b := Projectile.new()
				b.color = Color(1.0, 0.8, 0.4)
				b.damage = dmg * 0.4
				b.size = 1.3
				get_parent().add_child(b)
				b.global_position = global_position + Vector3(facing * 2.4 * size_mul * _shape.x, 4.6 * size_mul * _tall, 0)
				var ang := lerpf(0.35, -0.45, state_t / 1.4)
				b.velocity = Vector3(facing, 0, 0).rotated(Vector3.BACK, ang * facing).rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 24.0
			if state_t >= 1.4:
				_set_state(S.RECOVER)
		"lunge":
			# Fast strike from range: the head snaps forward and back.
			var head := global_position + Vector3(facing * (2.5 + 1.5 * size_mul), 2.6 * size_mul * _tall + 0.5, 0)
			if not _charge_hit and strike(head, 2.4 * size_mul, dmg * 1.15, Vector3(14, 6, 0), "player") > 0:
				_charge_hit = true
				Game.shake(0.4)
				Game.hitstop(0.08)
			if state_t >= 0.3:
				_set_state(S.RECOVER)
				return Vector3.ZERO
			return Vector3(facing * 26.0, 0, 0)
		"combo":
			if _combo_n < 3 and state_t >= 0.22 * _combo_n:
				_combo_n += 1
				_swipe(0.8 if _combo_n < 3 else 1.2)
			if state_t >= 0.75:
				_set_state(S.RECOVER)
			return Vector3(facing * 5.0, 0, 0)
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
				b.color = _elem_color()
				b.element = "" if is_boss() else _element
				b.damage = dmg * 0.5
				get_parent().add_child(b)
				b.global_position = global_position + Vector3(facing * 2.4 * size_mul * _shape.x, 4.6 * size_mul * _tall, 0)
				var to := _aim + Vector3(0, 3.0, 0) if _aim_locked else p.hit_center()
				var aim := (to - b.global_position).normalized()
				b.velocity = aim.rotated(Vector3.UP, randf_range(-0.12, 0.12)) * 22.0
			if state_t >= 1.0:
				_set_state(S.RECOVER)
		"burrow":
			if fmod(state_t, 0.12) < delta:
				FX.dust(global_position, 1.0)
			var mv := Vector3.ZERO
			if p:
				var d := p.global_position - global_position
				d.y = 0.0
				if d.length() < 1.0 or state_t > 2.2:
					_surface(true)
					_set_state(S.RECOVER)
					return Vector3.ZERO
				mv = d.normalized() * 13.0
				face_toward(d.x)
			elif state_t > 0.5:
				_surface(false)
				_set_state(S.RECOVER)
			return mv
		"leap", "frenzy", "dive":
			if state_t > 0.2 and is_on_floor():
				var r := 5.5 * size_mul / 1.5 * (1.6 if move == "dive" else 1.0)
				var hot := kind == "magmite"
				FX.shockwave(global_position, r, Color(1.0, 0.4, 0.1) if hot else Color(1.0, 0.7, 0.4))
				FX.dust(global_position, 2.0)
				if hot:
					FX.explosion(global_position + Vector3(0, 0.5, 0), 0.8)
				Game.shake(0.8)
				for q in Game.living_players():
					var d: Vector3 = q.global_position - global_position
					if Vector2(d.x, d.z).length() < r + 1.0:
						if q.take_hit(dmg, Vector3(signf(d.x) * 16.0, 10.0, 0), self):
							FX.hit_spark(q.hit_center(), 16.0)
							if hot:
								Projectile.apply_element(q, "fire", dmg)
				strike(global_position + Vector3(0, 1, 0), r, 0.0, Vector3.ZERO, "none", 40.0)
				if move == "frenzy" and _combo_n < 3:
					# Pounces again straight away.
					_combo_n += 1
					state_t = 0.0
					if p:
						face_toward(p.global_position.x - global_position.x)
					_jump_at(p, 16.0)
					if is_heavy():
						# Each pounce marks where it will come down.
						var air := 2.0 * 16.0 / GRAVITY
						var lx := clampf(global_position.x + _leap_vx * air, x_min, x_max)
						_mark(Vector3(lx, 0.0, global_position.z), 5.5 * size_mul / 1.5 + 1.0, air, Color(1.0, 0.22, 0.08))
					return Vector3(_leap_vx, 0, 0)
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


func _exit_tree() -> void:
	if _tele and is_instance_valid(_tele):
		_tele.cancel()
	_tele = null


func _on_death() -> void:
	_set_state(S.DEAD)
	if _burrowed:
		_burrowed = false
		invuln = 0.0
		model.visible = true
	collision_layer = 0
	Game.add_score(_score)
	died.emit(self)
	if is_boss() or kind == "elite" or size_mul >= 1.3:
		FX.explosion(hit_center(), 2.5 if is_boss() else 1.5)
		Game.shake(1.0 if is_boss() else 0.5)
	# Staggers back on buckling legs, topples over and bounces once on the
	# ground. Bigger bodies go down slower.
	model.crouch = 1.0
	model.lean = -0.5
	model.arm_r = 2.0
	model.arm_l = 1.4
	model.jaw = 1.0
	model.eye_glow = 0.0
	var h := model.heft
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", -0.18, 0.3 * h).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(model, "rotation:z", 1.5, 0.7 * h).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		FX.dust(global_position, 1.5 * size_mul)
		Game.shake(0.4)
		model.kick("squash", 4.0)
		model.arm_r = 0.25
		model.arm_l = 0.25
		model.jaw = 0.3)
	tw.tween_property(model, "rotation:z", 1.32, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(model, "rotation:z", 1.5, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(1.3)
	tw.tween_property(self, "position:y", -8.0 * size_mul, 2.0)
	tw.tween_callback(queue_free)


func _animate(delta: float, mv: Vector3) -> void:
	if state == S.DEAD:
		# The death tween owns the pose.
		model.walk_amount = 0.0
		model.tremble = 0.0
		return
	model.walk_amount = clampf(Vector2(mv.x, mv.z).length() / speed, 0.0, 1.0) if state == S.APPROACH else 0.0
	model.walk_speed = _walk_speed
	var ar := 0.25
	var al := 0.25
	var jaw := 0.0
	var lean := 0.0
	model.eye_glow = 0.0
	model.glow = 0.0
	match state:
		S.WINDUP:
			model.eye_glow = 1.0
			match move:
				"swipe", "combo":
					ar = 2.8
					lean = -0.25
					jaw = 0.5
				"charge", "summon", "shock":
					jaw = 1.0
					lean = -0.4
					ar = 1.6
					al = 1.6
					if move == "shock":
						model.glow = 1.0
				"slam":
					ar = 3.0
					al = 3.0
					lean = -0.35
					jaw = 0.8
				"breath", "spit":
					jaw = 0.6
					lean = -0.45
				"lunge":
					jaw = 0.7
					lean = -0.4
					ar = 1.6
					al = 1.6
				"hurl":
					ar = 3.0
					al = 3.0
					lean = -0.3
					jaw = 0.6
				"barrage", "meteor", "quake", "storm", "venom_rain", "sweep", "sandstorm":
					ar = 2.6
					al = 2.6
					lean = -0.45
					jaw = 1.0
					model.glow = 1.0
				"leap", "burrow", "frenzy", "dive":
					lean = 0.5
					ar = -0.5
					al = -0.5
				"explode":
					ar = 2.6
					al = 2.6
					jaw = 1.0
					lean = randf_range(-0.15, 0.15)
					model.glow = 1.0 if fmod(state_t, 0.16) < 0.08 else 0.2
		S.ACT:
			match move:
				"swipe":
					ar = 0.9
					al = 0.6
					lean = 0.45
				"combo":
					if _combo_n % 2 == 1:
						ar = 0.6
						al = 2.6
					else:
						ar = 2.6
						al = 0.6
					lean = 0.45
					model.walk_amount = 0.6
					model.walk_speed = 2.0
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
				"breath", "spit":
					jaw = 1.0
					lean = 0.1
					model.eye_glow = 1.0
				"lunge":
					jaw = 1.0
					lean = 0.9
				"hurl":
					ar = 0.4
					al = 0.4
					lean = 0.5
				"summon", "shock":
					jaw = 1.0
					ar = 2.2
					al = 2.2
				"leap", "frenzy", "dive":
					ar = 2.4
					al = 2.4
					lean = 0.3
				"barrage", "meteor", "quake", "storm", "venom_rain", "sandstorm":
					jaw = 1.0
					ar = 2.0
					al = 2.0
					model.glow = 1.0
				"sweep":
					lean = 0.4
					ar = 1.2
					al = 1.2
		S.RECOVER:
			ar = 0.6
			lean = 0.15
			if is_heavy():
				# Spent: head low, heaving breaths.
				lean = 0.3
				jaw = 0.35 + 0.25 * sin(state_t * 9.0)
				ar = 0.4
				al = 0.4
		S.HURT:
			lean = -0.35
			jaw = 0.5
	model.tremble = 0.0
	if state == S.WINDUP:
		# Gather into the wind-up pose instead of snapping to it: small ones
		# coil quickly, big ones rise slowly, hold it, and shake with effort
		# while the eyes blink faster just before they let go.
		var k := clampf(state_t / maxf(wind_time(), 0.01), 0.0, 1.0)
		var a := 1.0 - pow(1.0 - minf(k / (0.7 if is_heavy() else 0.45), 1.0), 2.0)
		ar = lerpf(0.25, ar, a)
		al = lerpf(0.25, al, a)
		jaw = lerpf(0.0, jaw, a)
		lean = lerpf(0.0, lean, a)
		model.eye_glow = a
		if is_heavy():
			model.tremble = smoothstep(0.5, 1.0, k)
			if k > 0.7:
				model.eye_glow = 1.0 if fmod(state_t, lerpf(0.2, 0.08, k)) < 0.05 else 0.3
	model.arm_r = ar
	model.arm_l = al
	model.jaw = jaw
	model.lean = lean
	if state != S.DEAD:
		update_model_facing(delta)
