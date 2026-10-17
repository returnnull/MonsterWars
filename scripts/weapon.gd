class_name Weapon
extends Node3D
## A piece of a destroyed building lying in the street. A kaiju picks it up
## with the heavy attack button, swings it with light attacks and throws it
## with the heavy attack. Also used for the flying, thrown version.
##
## Kinds:
##   girder  steel beam: long reach, thrown it spins and hits the first enemy
##   slab    concrete block: heavy hits, thrown it lands with an explosion
##   spire   antenna mast: longest reach, thrown it pierces every enemy

## grip: where along the piece (mesh units) a kaiju bites it, near one end;
## tilt: how far (radians) it points down from the jaws. The slab is bitten
## by its rebar and hangs below the head.
const KINDS := {
	"girder": {"name": "STEEL GIRDER", "dmg": 1.8, "reach": 1.6, "uses": 8, "throw_dmg": 38.0, "grip": 0.1, "tilt": 0.55},
	"slab": {"name": "CONCRETE SLAB", "dmg": 2.2, "reach": 0.8, "uses": 6, "throw_dmg": 46.0, "grip": 3.35, "tilt": -1.5},
	"spire": {"name": "ANTENNA SPIRE", "dmg": 1.6, "reach": 2.8, "uses": 7, "throw_dmg": 30.0, "grip": 0.3, "tilt": 0.55},
}

var kind := "girder"
var uses := 8
## When thrown: who threw it, flight velocity and damage.
var thrower: Player
var velocity := Vector3.ZERO
var throw_dmg := 0.0
var _thrown := false
var _hit: Array = []
var _t := 0.0
var _life := 18.0
var _mesh: Node3D
var _ring: MeshInstance3D


static func random_kind(building_height: float) -> String:
	if building_height > 14.0 and randf() < 0.5:
		return "spire"
	return "girder" if randf() < 0.55 else "slab"


## Builds the weapon's mesh (also used for the copy held in a kaiju's hand).
static func make_mesh(weapon_kind: String) -> Node3D:
	var root := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.45, 0.3, 0.25)
	steel.metallic = 0.7
	steel.roughness = 0.45
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.6, 0.56)
	concrete.roughness = 0.95
	match weapon_kind:
		"girder":
			# I-beam: two flanges and a web, with a rivet-plate end.
			for y in [-0.32, 0.32]:
				_box(root, Vector3(5.2, 0.1, 0.55), steel, Vector3(2.0, y, 0))
			_box(root, Vector3(5.2, 0.58, 0.1), steel, Vector3(2.0, 0, 0))
			_box(root, Vector3(0.12, 0.8, 0.7), steel, Vector3(4.6, 0, 0))
		"slab":
			_box(root, Vector3(2.6, 1.6, 1.8), concrete, Vector3(1.3, 0, 0))
			# Rebar sticking out and a strip of windows.
			for i in 4:
				_box(root, Vector3(0.9, 0.06, 0.06), steel, Vector3(2.9, -0.5 + i * 0.33, 0.4 - i * 0.25))
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.2, 0.3, 0.4)
			glass.metallic = 0.6
			glass.roughness = 0.1
			_box(root, Vector3(2.0, 0.5, 0.05), glass, Vector3(1.3, 0.25, 0.92))
		"spire":
			var mast := CylinderMesh.new()
			mast.top_radius = 0.06
			mast.bottom_radius = 0.22
			mast.height = 7.0
			var mi := MeshInstance3D.new()
			mi.mesh = mast
			mi.material_override = steel
			mi.rotation.z = -PI / 2
			mi.position.x = 3.2
			root.add_child(mi)
			for i in 4:
				_box(root, Vector3(0.08, 0.8 - i * 0.15, 0.08), steel, Vector3(1.0 + i * 1.4, 0, 0))
			var tip := StandardMaterial3D.new()
			tip.albedo_color = Color(1.0, 0.2, 0.15)
			tip.emission_enabled = true
			tip.emission = Color(1.0, 0.2, 0.1)
			tip.emission_energy_multiplier = 4.0
			var bulb := SphereMesh.new()
			bulb.radius = 0.18
			bulb.height = 0.36
			var b := MeshInstance3D.new()
			b.mesh = bulb
			b.material_override = tip
			b.position.x = 6.7
			root.add_child(b)
	return root


static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _ready() -> void:
	add_to_group("weapons")
	uses = KINDS[kind]["uses"]
	_mesh = make_mesh(kind)
	add_child(_mesh)
	if _thrown:
		return
	# Lying in the rubble, tilted, with a pulsing ring so it reads as pick-up-able.
	_mesh.position = Vector3(-2.0, 0.5, 0)
	_mesh.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.6), 0.15)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.6
	torus.outer_radius = 2.9
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.8, 0.3, 0.5)
	_ring.material_override = mat
	_ring.position.y = 0.1
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


## Turns this into a thrown projectile.
func launch(by: Player, vel: Vector3, dmg: float) -> void:
	_thrown = true
	thrower = by
	velocity = vel
	throw_dmg = dmg


func _physics_process(delta: float) -> void:
	_t += delta
	if _thrown:
		_fly(delta)
		return
	_life -= delta
	_ring.scale = Vector3.ONE * (1.0 + sin(_t * 5.0) * 0.08)
	if _life < 3.0:
		visible = fmod(_t, 0.2) < 0.12
	if _life <= 0.0:
		queue_free()


func _fly(delta: float) -> void:
	if kind == "slab":
		velocity.y -= 30.0 * delta
	global_position += velocity * delta
	var dir := signf(velocity.x)
	match kind:
		"girder":
			_mesh.rotation.z += delta * 18.0 * -dir
		"slab":
			_mesh.rotation.z += delta * 6.0 * -dir
		"spire":
			_mesh.rotation.y = 0.0 if dir > 0.0 else PI
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e in _hit:
			continue
		if e.hit_center().distance_to(global_position) < e.hit_radius + 2.0:
			_hit.append(e)
			if is_instance_valid(thrower):
				thrower.deal(e, throw_dmg, Vector3(dir * 16.0, 10.0, 0))
			else:
				e.take_hit(throw_dmg, Vector3(dir * 16.0, 10.0, 0))
			Game.register_hit()
			Game.shake(0.35)
			Game.hitstop(0.07)
			FX.hit_spark(e.hit_center(), 20.0)
			if kind != "spire":
				_impact()
				return
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.try_hit(global_position, 1.5, throw_dmg):
			if kind != "spire":
				_impact()
				return
	if global_position.y < 0.6 or _t > 2.5 or absf(global_position.z) > 30.0:
		_impact()


func _impact() -> void:
	if kind == "slab":
		var hits := 0
		if is_instance_valid(thrower):
			hits = thrower.strike(global_position + Vector3(0, 1.0, 0), 4.5, throw_dmg * 0.6, Vector3(10, 12, 0), "enemies", throw_dmg)
		FX.explosion(global_position, 1.1)
		Game.shake(0.5)
		for i in hits:
			Game.register_hit()
	else:
		FX.debris_burst(global_position, 0.9)
		FX.dust(global_position, 0.8)
	queue_free()
