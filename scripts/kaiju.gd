class_name Kaiju
extends CharacterBody3D
## Shared body for the player and enemy kaiju: health, knockback, gravity,
## facing, and the strike() hit test used by every melee attack.
##
## Anything in the "enemies" or "player" groups must expose: dead, hit_radius,
## hit_center() and take_hit(dmg, knockback, from) -> bool.

signal health_changed(hp: float, max_hp: float)
signal died(who: Node)

const GRAVITY := 38.0

var max_hp := 100.0
var hp := 100.0
var facing := 1.0
var model: KaijuModel
var knock := Vector3.ZERO
var hitstun := 0.0
var invuln := 0.0
var dead := false
var hit_radius := 1.6
var hit_height := 3.0
var x_min := -INF
var x_max := INF
var z_min := -5.0
var z_max := 3.0
## Status effects put on by player abilities.
var slow_t := 0.0
var slow_amt := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var frozen_t := 0.0

var _was_on_floor := true
var _yaw := 0.0


func init_body(radius: float, height: float, layer: int) -> void:
	collision_layer = layer
	collision_mask = Game.LAYER_WORLD
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	col.shape = cap
	col.position.y = height * 0.5
	add_child(col)
	hp = max_hp


func hit_center() -> Vector3:
	return global_position + Vector3(0, hit_height, 0)


func take_hit(dmg: float, kb: Vector3, from: Node3D = null) -> bool:
	if dead or invuln > 0.0:
		return false
	dmg = _incoming(dmg, from)
	if dmg <= 0.0:
		return false
	hp = maxf(hp - dmg, 0.0)
	health_changed.emit(hp, max_hp)
	knock = kb
	hitstun = 0.22 + kb.length() * 0.012
	if model:
		model.flash()
	_on_hurt(dmg, from)
	if hp <= 0.0:
		dead = true
		_on_death()
	return true


## Lets a kaiju reduce or block damage before it lands. 0 blocks the hit.
func _incoming(dmg: float, _from: Node3D) -> float:
	return dmg


## Lets an attacker change its damage against a target (crits and the like).
func _modify_damage(_target: Node, dmg: float) -> float:
	return dmg


## Called on the attacker after each of its hits lands.
func _on_strike_hit(_target: Node, _dmg: float) -> void:
	pass


## Hits one target through the attacker's damage hooks.
func deal(t: Node, dmg: float, kb: Vector3) -> bool:
	var d := _modify_damage(t, dmg)
	if t.take_hit(d, kb, self):
		_on_strike_hit(t, d)
		return true
	return false


func apply_slow(amount: float, duration: float) -> void:
	slow_amt = maxf(slow_amt if slow_t > 0.0 else 0.0, amount)
	slow_t = maxf(slow_t, duration)


func apply_burn(dps: float, duration: float) -> void:
	burn_dps = maxf(burn_dps if burn_t > 0.0 else 0.0, dps)
	burn_t = maxf(burn_t, duration)


func _tick_status(delta: float) -> void:
	slow_t = maxf(slow_t - delta, 0.0)
	frozen_t = maxf(frozen_t - delta, 0.0)
	if burn_t > 0.0 and not dead:
		burn_t -= delta
		hp = maxf(hp - burn_dps * delta, 0.0)
		health_changed.emit(hp, max_hp)
		if hp <= 0.0:
			dead = true
			_on_death()


func _on_hurt(_dmg: float, _from: Node3D) -> void:
	pass


func _on_death() -> void:
	died.emit(self)


func _on_land() -> void:
	FX.dust(global_position, 0.8)
	Game.shake(0.12)


func move_body(delta: float, move: Vector3) -> void:
	_tick_status(delta)
	if frozen_t > 0.0:
		move = Vector3.ZERO
	elif slow_t > 0.0:
		move *= 1.0 - slow_amt
	velocity.x = move.x + knock.x
	velocity.z = move.z + knock.z
	if knock.y > 0.0:
		velocity.y = knock.y
		knock.y = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	knock.x = move_toward(knock.x, 0.0, 45.0 * delta)
	knock.z = move_toward(knock.z, 0.0, 45.0 * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, x_min, x_max)
	global_position.z = clampf(global_position.z, z_min, z_max)
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_land()
	_was_on_floor = on_floor


func face_toward(dx: float) -> void:
	if absf(dx) > 0.05:
		facing = signf(dx)


## Turns the model to face left/right, always turning through the camera side.
func update_model_facing(delta: float) -> void:
	var target := 0.0 if facing > 0.0 else -PI
	_yaw = lerpf(_yaw, target, 1.0 - exp(-14.0 * delta))
	model.rotation.y = _yaw + model.spin


## Damages every live member of `group` whose hit sphere touches the sphere
## at `center`. Knockback x is pushed away from this kaiju. Optionally also
## damages buildings. Returns the number of things hit.
func strike(center: Vector3, radius: float, dmg: float, kb: Vector3, group: String, building_dmg: float = 0.0) -> int:
	var hits := 0
	for t in get_tree().get_nodes_in_group(group):
		if t == self or t.dead:
			continue
		var tc: Vector3 = t.hit_center()
		if tc.distance_to(center) <= radius + t.hit_radius:
			var dir := signf(tc.x - global_position.x)
			if dir == 0.0:
				dir = facing
			if deal(t, dmg, Vector3(kb.x * dir, kb.y, kb.z)):
				hits += 1
				FX.hit_spark(tc.lerp(center, 0.5), dmg)
	if building_dmg > 0.0:
		for b in get_tree().get_nodes_in_group("buildings"):
			if b.try_hit(center, radius, building_dmg):
				hits += 1
	return hits
