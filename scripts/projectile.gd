class_name Projectile
extends Node3D
## Enemy shot: plasma bolts, breath, bullets, tank shells, bombs, lobbed
## spit and homing missiles. Dodging (i-frames) lets it pass through.
##
## style: "orb", "bullet", "shell", "bomb", "glob", "missile", "boulder".
## element: "", "fire" (burns), "acid"/"venom" (corrodes), "ice" (slows).
## splash > 0 makes it burst on impact (or on the ground) and hurt everyone
## inside that radius. Only bursts knock back; a direct shot without splash
## neither pushes nor staggers (see is_plain_shot()).

var velocity := Vector3.ZERO
var color := Color(1.0, 0.45, 0.1)
var damage := 8.0
var style := "orb"
var element := ""
var gravity := 0.0
var splash := 0.0
var size := 1.0
## Turn rate toward `target` (0 = straight). Homing starts after `homing_delay`.
var homing := 0.0
var homing_delay := 0.3
## After this many seconds it stops steering and flies straight on, so a
## player who moves at the last moment gets out of the way.
var homing_until := INF
var target: Node3D
var _life := 4.0
var _t := 0.0
var _speed := 0.0


func _ready() -> void:
	if style == "missile":
		_life = 6.0
	_speed = velocity.length()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lerp(Color.WHITE, 0.4)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	match style:
		"shell", "bomb", "missile":
			var hull := StandardMaterial3D.new()
			hull.albedo_color = Color(0.25, 0.27, 0.22) if style != "missile" else Color(0.85, 0.85, 0.8)
			hull.metallic = 0.5
			hull.roughness = 0.4
			var body := CapsuleMesh.new()
			body.radius = 0.22 * size if style != "bomb" else 0.35 * size
			body.height = 1.0 * size if style != "bomb" else 1.1 * size
			_mesh(body, hull, Vector3.ZERO, Vector3(0, 0, PI / 2))
			var glow := SphereMesh.new()
			glow.radius = 0.2 * size
			glow.height = 0.4 * size
			_mesh(glow, mat, Vector3(-0.55 * size, 0, 0))
			if style == "missile":
				var fin := BoxMesh.new()
				fin.size = Vector3(0.3, 0.5, 0.05) * size
				_mesh(fin, hull, Vector3(-0.35 * size, 0, 0))
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.18 * size
				cone.height = 1.2 * size
				_mesh(cone, mat, Vector3(-1.0 * size, 0, 0), Vector3(0, 0, PI / 2))
		"boulder":
			var rock := StandardMaterial3D.new()
			rock.albedo_color = Color(0.36, 0.33, 0.3)
			rock.roughness = 0.95
			for i in 3:
				var b := BoxMesh.new()
				b.size = Vector3.ONE * (0.95 - i * 0.15) * size
				_mesh(b, rock if i < 2 else mat, Vector3(i * 0.1, -i * 0.08, i * 0.12) * size, Vector3(i * 0.7, i * 1.1, i * 0.4))
		"bullet":
			var b := CapsuleMesh.new()
			b.radius = 0.12 * size
			b.height = 0.9 * size
			_mesh(b, mat, Vector3.ZERO, Vector3(0, 0, PI / 2))
		_:
			var s := SphereMesh.new()
			s.radius = 0.35 * size
			s.height = 0.7 * size
			_mesh(s, mat, Vector3.ZERO)
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.3 * size
			c.height = 1.6 * size
			_mesh(c, mat, Vector3(-0.8 * size, 0, 0), Vector3(0, 0, PI / 2))


func _mesh(m: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
	add_child(mi)


func _physics_process(delta: float) -> void:
	_t += delta
	velocity.y -= gravity * delta
	if homing > 0.0 and _t > homing_delay and _t < homing_until:
		if target == null or not is_instance_valid(target) or target.dead:
			target = Game.nearest_player(global_position)
		if target:
			var want: Vector3 = (target.hit_center() - global_position).normalized() * _speed
			velocity = velocity.lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized() * _speed
	global_position += velocity * delta
	if style == "boulder":
		rotation += Vector3(4.0, 0.0, -6.0) * delta
	elif velocity.length() > 0.1:
		rotation.y = atan2(-velocity.z, velocity.x)
		rotation.z = atan2(velocity.y, Vector2(velocity.x, velocity.z).length())
	if style == "missile" and fmod(_t, 0.09) < delta:
		FX.smoke(global_position, 0.25, Color(0.8, 0.8, 0.78))
	_life -= delta
	for p in Game.living_players():
		if global_position.distance_to(p.hit_center()) < p.hit_radius + 0.6 * size:
			if splash > 0.0:
				_burst()
				return
			# Plain shots only sting: no knockback, so the player can push through
			# gunfire to reach the shooters. Splash bursts below still shove.
			if p.take_hit(damage, Vector3.ZERO, self):
				apply_element(p, element, damage)
				FX.hit_spark(global_position, 8.0)
				Game.shake(0.2)
				queue_free()
				return
	if global_position.y < 0.2 or _life <= 0.0:
		if splash > 0.0:
			_burst()
			return
		FX.hit_spark(global_position, 5.0)
		queue_free()


## True for a direct hit from a shot without splash: the player takes the
## damage but isn't pushed or staggered by it.
func is_plain_shot() -> bool:
	return splash <= 0.0


## Area burst: hurts every player within `splash` (horizontal distance).
func _burst() -> void:
	var pos := Vector3(global_position.x, maxf(global_position.y, 0.3), global_position.z)
	if element == "" or element == "fire":
		FX.explosion(pos, clampf(splash / 3.0, 0.5, 1.5))
	else:
		FX.smoke(pos, splash / 2.5, color)
		FX.energy(pos, color)
	FX.shockwave(Vector3(pos.x, 0.05, pos.z), splash, color)
	Game.shake(0.25)
	for p in Game.living_players():
		var d: Vector3 = p.hit_center() - pos
		if Vector2(d.x, d.z).length() < splash + p.hit_radius * 0.5 and p.global_position.y < pos.y + 4.0:
			if p.take_hit(damage, Vector3(signf(d.x) * 8.0, 6.0, 0), self):
				apply_element(p, element, damage)
	for b in get_tree().get_nodes_in_group("buildings"):
		b.try_hit(pos + Vector3(0, 1, 0), splash, damage * 2.0)
	queue_free()


## Status effect a hit with this element leaves on a kaiju.
static func apply_element(p: Node, elem: String, dmg: float) -> void:
	if not (p is Kaiju) or p.dead:
		return
	match elem:
		"fire":
			p.apply_burn(dmg * 0.2, 2.0)
		"acid", "venom":
			p.apply_burn(dmg * 0.15, 2.5)
		"ice":
			p.apply_slow(0.45, 1.8)
