extends Node3D
## Dev helper: one enemy fights a stand-in hero so its animation and attack
## warnings can be judged. Record it with Godot's movie writer:
##   xvfb-run godot --path . --write-movie /tmp/enemy.avi --fixed-fps 30 res://tests/enemy_lab.tscn
## ENEMY_ID picks the enemy (any Enemies id, or "bossN" for country N+1's
## boss; default titanodon), ENEMY_SECONDS how long it runs (default 14).
## ENEMY_DODGE=1 makes the stand-in step out of every warned area. At the end
## it prints how many attacks were warned and how often the stand-in got hit.

var enemy: Node3D
var target := StandIn.new()
var cam := Camera3D.new()
var t := 0.0
var _secs := 14.0
var _dodge := false
var _dodge_t := 0.0
var _dodge_axis := Vector3.RIGHT
var _hits := 0
var _by := {}
var _warnings := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.level = {"country": 0}
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Game.LAYER_WORLD
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 60)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 60)
	mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.33, 0.35)
	mi.material_override = fm
	floor_body.add_child(mi)
	add_child(floor_body)
	cam.fov = 40.0
	add_child(cam)
	if OS.get_environment("ENEMY_SECONDS") != "":
		_secs = float(OS.get_environment("ENEMY_SECONDS"))
	_dodge = OS.get_environment("ENEMY_DODGE") == "1"

	# Stand-in hero: a capsule that never dies.
	add_child(target)
	target.init_body(1.2, 6.0, Game.LAYER_PLAYER)
	var cap := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 1.2
	cm.height = 6.0
	cap.mesh = cm
	cap.position.y = 3.0
	target.add_child(cap)
	target.global_position = Vector3(0, 0.5, 0)
	target.max_hp = 1e9
	target.hp = 1e9
	Game.players.assign([target])
	target.hurt.connect(func(by: String) -> void:
		_hits += 1
		_by[by] = _by.get(by, 0) + 1)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Telegraph:
			_warnings += 1
		elif n is Kaiju and n != enemy and n != target and enemy != null and n.get_parent() == self:
			# Summoned helpers would muddy the count: only the enemy itself fights.
			n.queue_free.call_deferred())

	var id := OS.get_environment("ENEMY_ID")
	if id == "":
		id = "titanodon"
	enemy = _make(id)
	add_child(enemy)
	enemy.global_position = Vector3(16, 0.5, 0)
	enemy.facing = -1.0


func _physics_process(delta: float) -> void:
	t += delta
	if t >= _secs:
		print("%s: %d warned attacks, stand-in hit %d times%s " % [OS.get_environment("ENEMY_ID"), _warnings, _hits,
			" (dodging)" if _dodge else ""], _by)
		get_tree().quit()
		return
	var mv := Vector3.ZERO
	if _dodge:
		_dodge_t -= delta
		var w := _threat()
		if _dodge_t <= 0.0 and w:
			_dodge_t = 0.7
			if w is Hazard or w.shape == "lane":
				# Step sideways out of a lane or a marked spot, away from its
				# middle unless the street ends that way.
				var side := signf((w.global_transform.affine_inverse() * target.global_position).z)
				var z := signf((w.global_transform.basis * Vector3(0, 0, side if side != 0.0 else 1.0)).z)
				if target.global_position.z + z * 3.0 > target.z_max or target.global_position.z + z * 3.0 < target.z_min:
					z = -z
				_dodge_axis = Vector3(0, 0, z)
			else:
				_dodge_axis = Vector3(signf(target.global_position.x - w.global_position.x), 0, 0)
				if _dodge_axis.x == 0.0:
					_dodge_axis.x = 1.0
		if _dodge_t > 0.0:
			mv = _dodge_axis * 11.0
		elif absf(enemy.global_position.x - target.global_position.x) > 9.0:
			mv.x = signf(enemy.global_position.x - target.global_position.x) * 5.0
	target.move_body(delta, mv)
	target.global_position.x = clampf(target.global_position.x, -40.0, 40.0)
	var mid := (target.global_position + enemy.global_position) * 0.5 if is_instance_valid(enemy) else target.global_position
	cam.position = Vector3(mid.x, 9.0, 40.0)
	cam.look_at(Vector3(mid.x, 3.0, 0))


## The warning marker covering the stand-in, if any.
func _threat() -> Node3D:
	for w in get_tree().get_nodes_in_group("telegraphs"):
		if w.covers(target.global_position):
			return w
	return null


func _make(id: String) -> Node3D:
	if id.begins_with("boss"):
		var bb := Brute.new()
		bb.kind = "boss"
		bb.boss_def = Content.boss(int(id.substr(4)))
		return bb
	match Enemies.get_def(id)["class"]:
		"infantry":
			var s := Infantry.new()
			s.kind = id
			return s
		"ground":
			var v := Vehicle.new()
			v.kind = id
			return v
		"air":
			var f := Flyer.new()
			f.kind = id
			return f
	var b := Brute.new()
	b.kind = id
	return b


## Counts the hits it takes (burning does not count) and what dealt them.
class StandIn extends Kaiju:
	signal hurt(by: String)

	func _on_hurt(_dmg: float, from: Node3D) -> void:
		var by := "?"
		if from is Brute:
			by = from.move
		elif from is Projectile:
			by = "shot:" + String(from.style)
		elif from is Hazard:
			by = "hazard"
		elif from:
			by = from.get_class()
		hurt.emit(by)
