class_name Cosmetics
extends RefCounted
## Cosmetic items the kaiju can wear, one per slot (head, face, neck, back,
## tail). Each is unlocked by a trophy (see Trophies) and built from a few
## primitive meshes, so no art files are needed.
##
## Every item is modelled in its slot's anchor frame, in world units for a
## size 1.0 hero (the hero's scale does the rest). KaijuModel.cosmetic_anchor()
## puts that frame on the body and keeps it there while the kaiju animates:
##   head  origin on top of the skull. X points along the snout, Y up, Z to the side.
##   face  origin between the eyes, which sit at about z = +-0.32 (they bulge out to
##         about +-0.5); the top of the snout tip is near (0.65, 0, 0).
##   neck  origin in the middle of the neck (radius about 0.6). Y runs along the
##         neck towards the head, X points out of the throat.
##   back  origin on the back between the shoulders. X forward, Y up.
##   tail  origin near the tail tip (tail radius about 0.15). X points back
##         towards the body.

const SLOTS := ["head", "face", "neck", "back", "tail"]
const SLOT_NAMES := {"head": "HEAD", "face": "FACE", "neck": "NECK", "back": "BACK", "tail": "TAIL"}
## Hats and tail toys are drawn a bit larger than life so they read from the
## game camera. Face items stay true to size to sit on the eyes.
const SLOT_SCALE := {"head": 1.35, "face": 1.0, "neck": 1.0, "back": 1.15, "tail": 1.3}

const GOLD := Color(1.0, 0.76, 0.28)
const SILVER := Color(0.82, 0.85, 0.9)
const BRONZE := Color(0.78, 0.47, 0.25)
const IRON := Color(0.22, 0.22, 0.24)
const BLACK := Color(0.07, 0.07, 0.08)
const WHITE := Color(0.95, 0.95, 0.92)
const BONE := Color(0.92, 0.88, 0.76)

## id -> name, slot and optionally a "scale" that overrides SLOT_SCALE (for
## bands that have to fit snugly). The parts are in _parts().
const ITEMS := {
	"bronze_crown": {"name": "Bronze Crown", "slot": "head"},
	"silver_crown": {"name": "Silver Crown", "slot": "head"},
	"gold_crown": {"name": "Gold Crown", "slot": "head"},
	"viking_helmet": {"name": "Viking Helmet", "slot": "head"},
	"beret": {"name": "Beret", "slot": "head"},
	"cowboy_hat": {"name": "Cowboy Hat", "slot": "head"},
	"carnival_feathers": {"name": "Carnival Feathers", "slot": "head"},
	"fez": {"name": "Fez", "slot": "head"},
	"turban": {"name": "Jewelled Turban", "slot": "head"},
	"cork_hat": {"name": "Cork Hat", "slot": "head"},
	"ushanka": {"name": "Ushanka", "slot": "head"},
	"wool_scarf": {"name": "Wool Scarf", "slot": "neck"},
	"hachimaki": {"name": "Hachimaki", "slot": "head", "scale": 1.0},
	"party_hat": {"name": "Party Hat", "slot": "head"},
	"sunglasses": {"name": "Sunglasses", "slot": "face"},
	"gold_chain": {"name": "Gold Chain", "slot": "neck"},
	"rubber_duck": {"name": "Rubber Duck", "slot": "head"},
	"propeller_cap": {"name": "Propeller Cap", "slot": "head"},
	"traffic_cone": {"name": "Traffic Cone", "slot": "head"},
	"bone_necklace": {"name": "Bone Necklace", "slot": "neck"},
	"dynamite_tail": {"name": "Lit Dynamite", "slot": "tail"},
	"toy_chopper": {"name": "Toy Chopper", "slot": "back"},
	"tinfoil_hat": {"name": "Tinfoil Hat", "slot": "head"},
	"hard_hat": {"name": "Hard Hat", "slot": "head"},
	"wrecking_ball": {"name": "Wrecking Ball", "slot": "tail"},
	"tnt_pack": {"name": "TNT Backpack", "slot": "back"},
	"tourist_camera": {"name": "Tourist Camera", "slot": "neck"},
	"sweatband": {"name": "Sweatband", "slot": "head", "scale": 1.0},
	"star_shades": {"name": "Star Shades", "slot": "face"},
	"flame_tip": {"name": "Flame Tip", "slot": "tail"},
	"devil_horns": {"name": "Devil Horns", "slot": "head"},
	"ruff_collar": {"name": "Opera Ruff", "slot": "neck"},
	"hero_cape": {"name": "Hero Cape", "slot": "back"},
	"fire_helmet": {"name": "Firefighter Helmet", "slot": "head"},
	"whistle": {"name": "Coach's Whistle", "slot": "neck"},
	"hiking_pack": {"name": "Hiking Pack", "slot": "back"},
	"ninja_mask": {"name": "Ninja Mask", "slot": "face"},
	"jetpack": {"name": "Jetpack", "slot": "back"},
	"grad_cap": {"name": "Graduation Cap", "slot": "head"},
	"monocle": {"name": "Monocle", "slot": "face"},
	"medal": {"name": "Gold Medal", "slot": "neck"},
	"rainbow_scarf": {"name": "Rainbow Scarf", "slot": "neck"},
	"wizard_hat": {"name": "Wizard Hat", "slot": "head"},
	"halo": {"name": "Halo", "slot": "head"},
	"eyepatch": {"name": "Eyepatch", "slot": "face"},
	"prayer_beads": {"name": "Prayer Beads", "slot": "neck"},
	"racing_goggles": {"name": "Racing Goggles", "slot": "face"},
	"bowtie": {"name": "Bow Tie", "slot": "neck"},
	"balloon": {"name": "Party Balloon", "slot": "tail"},
	"clown_nose": {"name": "Clown Nose", "slot": "face"},
	"lollipop": {"name": "Lollipop", "slot": "tail"},
	"top_hat": {"name": "Top Hat", "slot": "head"},
	"spiked_collar": {"name": "Spiked Collar", "slot": "neck"},
}

static var _meshes := {}
static var _mats := {}


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


## Item ids for one slot, in ITEMS order.
static func for_slot(slot: String) -> Array:
	return ITEMS.keys().filter(func(id: String) -> bool: return ITEMS[id]["slot"] == slot)


## Dresses a kaiju model in an outfit ({slot: item id}), replacing what it
## wore before. Unknown ids and empty slots are skipped.
static func dress(model: KaijuModel, outfit: Dictionary) -> void:
	if model == null:
		return
	for n in model.get_meta("cosmetics", []):
		if is_instance_valid(n):
			n.queue_free()
	var worn: Array = []
	for slot in SLOTS:
		var id: String = outfit.get(slot, "")
		if id == "" or not ITEMS.has(id):
			continue
		var anchor := model.cosmetic_anchor(slot)
		if anchor == null:
			continue
		var piece := build(id)
		piece.scale = Vector3.ONE * float(ITEMS[id].get("scale", SLOT_SCALE[slot]))
		anchor.add_child(piece)
		# A GlbKaijuModel anchor hangs on its own bone attachment.
		worn.append(anchor.get_parent() if anchor.get_parent() is BoneAttachment3D else anchor)
	model.set_meta("cosmetics", worn)


## Builds one item as a node tree in its slot's anchor frame.
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	for p in _parts(id):
		var opts: Dictionary = p[5] if p.size() > 5 else {}
		var rot: Vector3 = p[4] if p.size() > 4 else Vector3.ZERO
		var around: Array = opts.get("around", [1, 0.0])
		for i in int(around[0]):
			var a := TAU * i / float(around[0])
			var mi := Piece.new()
			mi.mesh = _mesh(p[0], p[2], opts)
			mi.material_override = _mat(p[3], opts)
			var size: Vector3 = p[2]
			if p[0] == "torus":
				mi.scale = Vector3(1, 1, size.z / size.x)
			elif p[0] != "cap":
				mi.scale = size
			mi.rotation_degrees = rot
			mi.position = p[1] + Vector3(float(around[1]), 0, 0)
			if around[0] > 1:
				# Repeated around the Y axis: hang it on a turned pivot.
				var pivot := Node3D.new()
				pivot.rotation.y = a
				pivot.add_child(mi)
				root.add_child(pivot)
			else:
				root.add_child(mi)
			mi.spin = opts.get("spin", Vector3.ZERO)
			mi.bob = float(opts.get("bob", 0.0))
			mi.flicker = bool(opts.get("flicker", false))
			mi.set_process(mi.spin != Vector3.ZERO or mi.bob > 0.0 or mi.flicker)
	return root


## A mesh piece that can spin, bob or flicker like a flame.
class Piece extends MeshInstance3D:
	var spin := Vector3.ZERO
	var bob := 0.0
	var flicker := false
	var _t := randf() * 10.0
	var _base := Vector3.ZERO
	var _scale := Vector3.ONE

	func _ready() -> void:
		_base = position
		_scale = scale

	func _process(delta: float) -> void:
		_t += delta
		rotation += spin * delta
		if bob > 0.0:
			position = _base + Vector3(0, sin(_t * 2.2) * bob, 0)
		if flicker:
			var f := 1.0 + sin(_t * 23.0) * 0.12 + sin(_t * 37.0) * 0.08
			scale = Vector3(_scale.x * (2.0 - f), _scale.y * f, _scale.z * (2.0 - f))


## Shapes: "box", "sph" (ellipsoid), "cyl", "cone" are unit meshes scaled to
## `size`; opts "top" sets a cylinder's top radius ratio and "seg" its sides.
## "torus" takes size.x as its outer diameter, size.y as the tube thickness and
## size.z/size.x as a squash; "cap" is a capsule size.x wide and size.y long.
static func _mesh(shape: String, size: Vector3, opts: Dictionary) -> Mesh:
	var key := shape
	match shape:
		"torus":
			key += str(size)
		"cap":
			key += str(size)
		"cyl", "cone":
			key += "%s_%s" % [opts.get("top", -1.0), opts.get("seg", 20)]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match shape:
		"box":
			m = BoxMesh.new()
		"sph":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 20
			s.rings = 10
			m = s
		"cyl", "cone":
			var c := CylinderMesh.new()
			c.height = 1.0
			c.bottom_radius = 0.5
			c.top_radius = 0.5 * float(opts.get("top", 1.0 if shape == "cyl" else 0.0))
			c.radial_segments = int(opts.get("seg", 20))
			c.rings = 1
			m = c
		"torus":
			var t := TorusMesh.new()
			t.outer_radius = size.x * 0.5
			t.inner_radius = maxf(size.x * 0.5 - size.y, 0.01)
			t.rings = 24
			t.ring_segments = 8
			m = t
		"cap":
			var cp := CapsuleMesh.new()
			cp.radius = size.x * 0.5
			cp.height = maxf(size.y, size.x)
			cp.radial_segments = 12
			cp.rings = 4
			m = cp
	_meshes[key] = m
	return m


## opts: "metal" (0-1), "rough", "glow" (emission energy).
static func _mat(color: Color, opts: Dictionary) -> Material:
	var key := "%s_%s_%s_%s" % [color, opts.get("metal", 0.0), opts.get("rough", -1.0), opts.get("glow", 0.0)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	# Half metal: the menus have no sky to reflect, and full metal goes black.
	m.metallic = float(opts.get("metal", 0.0)) * 0.55
	m.roughness = float(opts.get("rough", 0.35 if m.metallic > 0.0 else 0.7))
	var glow := float(opts.get("glow", 0.0))
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


## The parts of an item: [shape, position, size, colour, rotation (degrees),
## opts]. opts may also hold "around": [count, radius] to repeat the part
## around the anchor's Y axis, and "spin" (rad/s), "bob" or "flicker".
static func _parts(id: String) -> Array:
	var metal := {"metal": 1.0}
	match id:
		"bronze_crown", "silver_crown", "gold_crown":
			var c: Color = {"bronze_crown": BRONZE, "silver_crown": SILVER, "gold_crown": GOLD}[id]
			var out := [
				["cyl", Vector3(0, 0.1, 0), Vector3(0.8, 0.22, 0.76), c, Vector3.ZERO, metal],
				["cone", Vector3(0, 0.34, 0), Vector3(0.17, 0.3, 0.17), c, Vector3.ZERO, {"metal": 1.0, "around": [7, 0.32]}],
				["sph", Vector3(0, 0.5, 0), Vector3(0.09, 0.09, 0.09), c.lightened(0.2), Vector3.ZERO, {"metal": 1.0, "around": [7, 0.32]}],
				["sph", Vector3(0.39, 0.1, 0), Vector3(0.06, 0.14, 0.14), Color(0.9, 0.1, 0.15), Vector3.ZERO, {"glow": 1.5}],
			]
			if id == "gold_crown":
				out.append(["sph", Vector3(0, 0.1, 0), Vector3(0.1, 0.1, 0.05), Color(0.2, 0.5, 1.0), Vector3.ZERO,
					{"glow": 1.5, "around": [6, 0.39]}])
				out.append(["sph", Vector3(0, 0.36, 0), Vector3(0.62, 0.3, 0.6), Color(0.6, 0.08, 0.12)])
			return out
		"viking_helmet":
			return [
				["sph", Vector3(0, 0.02, 0), Vector3(0.9, 0.66, 0.86), SILVER.darkened(0.25), Vector3.ZERO, metal],
				["cyl", Vector3(0, 0.03, 0), Vector3(0.94, 0.1, 0.9), BRONZE, Vector3.ZERO, metal],
				["box", Vector3(0, 0.2, 0), Vector3(0.94, 0.07, 0.07), BRONZE, Vector3.ZERO, metal],
				["cone", Vector3(0, 0.32, 0.5), Vector3(0.18, 0.55, 0.18), BONE, Vector3(55, 0, 0)],
				["cone", Vector3(0, 0.32, -0.5), Vector3(0.18, 0.55, 0.18), BONE, Vector3(-55, 0, 0)],
			]
		"beret":
			return [
				["sph", Vector3(-0.05, 0.08, 0), Vector3(1.05, 0.28, 1.0), Color(0.12, 0.13, 0.3), Vector3(0, 0, 12)],
				["cyl", Vector3(-0.03, 0.22, 0), Vector3(0.05, 0.1, 0.05), Color(0.12, 0.13, 0.3), Vector3(0, 0, 12)],
			]
		"cowboy_hat":
			var brown := Color(0.5, 0.32, 0.17)
			return [
				["sph", Vector3(0, 0.04, 0), Vector3(1.6, 0.1, 1.35), brown],
				["cyl", Vector3(0, 0.28, 0), Vector3(0.72, 0.46, 0.62), brown, Vector3.ZERO, {"top": 0.8}],
				["cyl", Vector3(0, 0.12, 0), Vector3(0.74, 0.08, 0.64), Color(0.2, 0.12, 0.07)],
				["box", Vector3(0, 0.5, 0), Vector3(0.45, 0.06, 0.12), brown.darkened(0.2)],
			]
		"carnival_feathers":
			var cols := [Color(0.1, 0.8, 0.3), Color(1.0, 0.85, 0.1), Color(0.15, 0.5, 1.0), Color(1.0, 0.2, 0.4)]
			var out := [["cyl", Vector3(0, 0.06, 0), Vector3(0.84, 0.14, 0.8), GOLD, Vector3.ZERO, metal]]
			for k in range(-3, 4):
				out.append(["sph", Vector3(-0.2, 0.55, k * 0.13), Vector3(0.12, 1.0, 0.26), cols[(k + 3) % cols.size()],
					Vector3(k * 14, 0, 18), {"glow": 0.3}])
			out.append(["sph", Vector3(0.42, 0.08, 0), Vector3(0.08, 0.16, 0.16), Color(0.2, 1.0, 0.6), Vector3.ZERO, {"glow": 1.5}])
			return out
		"fez":
			return [
				["cyl", Vector3(0, 0.22, 0), Vector3(0.56, 0.44, 0.56), Color(0.75, 0.1, 0.1), Vector3.ZERO, {"top": 0.8}],
				["cyl", Vector3(0, 0.45, 0), Vector3(0.05, 0.03, 0.05), BLACK],
				["cyl", Vector3(-0.08, 0.36, 0.13), Vector3(0.03, 0.3, 0.03), BLACK, Vector3(40, 0, 0)],
				["sph", Vector3(-0.08, 0.22, 0.25), Vector3(0.08, 0.16, 0.08), BLACK],
			]
		"turban":
			var o := Color(1.0, 0.55, 0.15)
			return [
				["torus", Vector3(0, 0.1, 0), Vector3(0.9, 0.32, 0.9), o],
				["torus", Vector3(0, 0.27, 0), Vector3(0.76, 0.28, 0.76), o.lightened(0.15)],
				["sph", Vector3(0, 0.28, 0), Vector3(0.6, 0.36, 0.6), o],
				["sph", Vector3(0.42, 0.2, 0), Vector3(0.08, 0.16, 0.12), Color(0.1, 0.9, 0.4), Vector3.ZERO, {"glow": 1.5}],
				["sph", Vector3(0.36, 0.5, 0), Vector3(0.07, 0.4, 0.14), WHITE, Vector3(0, 0, -15)],
			]
		"cork_hat":
			var khaki := Color(0.68, 0.58, 0.38)
			return [
				["sph", Vector3(0, 0.04, 0), Vector3(1.35, 0.06, 1.35), khaki],
				["cyl", Vector3(0, 0.2, 0), Vector3(0.72, 0.32, 0.72), khaki, Vector3.ZERO, {"top": 0.85}],
				["cyl", Vector3(0, 0.08, 0), Vector3(0.74, 0.07, 0.74), Color(0.3, 0.2, 0.1)],
				["cyl", Vector3(0, -0.12, 0), Vector3(0.015, 0.3, 0.015), Color(0.3, 0.2, 0.1), Vector3.ZERO, {"around": [8, 0.6]}],
				["cyl", Vector3(0, -0.3, 0), Vector3(0.08, 0.13, 0.08), Color(0.8, 0.62, 0.4), Vector3.ZERO, {"around": [8, 0.6]}],
			]
		"ushanka":
			var fur := Color(0.42, 0.3, 0.2)
			return [
				["sph", Vector3(0, 0.12, 0), Vector3(0.98, 0.58, 0.96), fur],
				["box", Vector3(0.42, 0.24, 0), Vector3(0.14, 0.3, 0.84), fur.lightened(0.1)],
				["box", Vector3(-0.02, -0.12, 0.5), Vector3(0.42, 0.46, 0.1), fur.lightened(0.1)],
				["box", Vector3(-0.02, -0.12, -0.5), Vector3(0.42, 0.46, 0.1), fur.lightened(0.1)],
				["sph", Vector3(0.5, 0.26, 0), Vector3(0.04, 0.12, 0.12), Color(0.9, 0.1, 0.1), Vector3.ZERO, {"glow": 1.0}],
			]
		"wool_scarf":
			var cream := Color(0.9, 0.86, 0.76)
			var brown := Color(0.35, 0.22, 0.14)
			return [
				["torus", Vector3(0, 0, 0), Vector3(1.4, 0.36, 1.4), cream],
				["torus", Vector3(0, 0.13, 0), Vector3(1.35, 0.12, 1.35), brown],
				["torus", Vector3(0, -0.13, 0), Vector3(1.35, 0.12, 1.35), brown],
				["box", Vector3(0.6, -0.38, 0.28), Vector3(0.14, 0.7, 0.26), cream, Vector3(0, 0, 8)],
				["box", Vector3(0.62, -0.6, 0.28), Vector3(0.15, 0.08, 0.27), brown, Vector3(0, 0, 8)],
			]
		"hachimaki":
			return [
				["torus", Vector3(0, -0.06, 0), Vector3(1.12, 0.2, 1.06), WHITE],
				["cyl", Vector3(0.56, -0.04, 0), Vector3(0.2, 0.02, 0.2), Color(0.85, 0.05, 0.1), Vector3(0, 0, 90)],
				["box", Vector3(-0.66, -0.16, 0.06), Vector3(0.34, 0.06, 0.12), WHITE, Vector3(0, 15, 30)],
				["box", Vector3(-0.66, -0.2, -0.06), Vector3(0.3, 0.06, 0.12), WHITE, Vector3(0, -15, 40)],
			]
		"party_hat":
			return [
				["cone", Vector3(0, 0.36, 0), Vector3(0.5, 0.72, 0.5), Color(1.0, 0.3, 0.7), Vector3(0, 0, -10)],
				["torus", Vector3(0.02, 0.2, 0), Vector3(0.4, 0.06, 0.4), Color(0.3, 0.8, 1.0), Vector3(0, 0, -10)],
				["torus", Vector3(0.05, 0.4, 0), Vector3(0.26, 0.05, 0.26), Color(1.0, 0.9, 0.2), Vector3(0, 0, -10)],
				["sph", Vector3(0.12, 0.74, 0), Vector3(0.16, 0.16, 0.16), Color(1.0, 0.9, 0.2), Vector3.ZERO, {"glow": 0.5}],
			]
		"sunglasses":
			return [
				["box", Vector3(0.06, 0.02, 0.53), Vector3(0.38, 0.24, 0.05), BLACK, Vector3.ZERO, {"metal": 0.6, "rough": 0.08}],
				["box", Vector3(0.06, 0.02, -0.53), Vector3(0.38, 0.24, 0.05), BLACK, Vector3.ZERO, {"metal": 0.6, "rough": 0.08}],
				["box", Vector3(0.25, 0.12, 0), Vector3(0.05, 0.05, 1.1), BLACK],
				["box", Vector3(-0.3, 0.08, 0.54), Vector3(0.6, 0.04, 0.03), BLACK],
				["box", Vector3(-0.3, 0.08, -0.54), Vector3(0.6, 0.04, 0.03), BLACK],
			]
		"gold_chain":
			return [
				["torus", Vector3(0, -0.05, 0), Vector3(1.36, 0.1, 1.36), GOLD, Vector3(0, 0, 12), metal],
				["torus", Vector3(0, 0, 0), Vector3(0.1, 0.03, 0.1), GOLD, Vector3(90, 0, 0), {"metal": 1.0, "around": [16, 0.66]}],
				["cyl", Vector3(0.74, -0.25, 0), Vector3(0.36, 0.06, 0.36), GOLD, Vector3(0, 0, 90), metal],
				["box", Vector3(0.78, -0.25, 0), Vector3(0.02, 0.18, 0.04), GOLD.darkened(0.3), Vector3.ZERO, metal],
			]
		"rubber_duck":
			var y := Color(1.0, 0.85, 0.1)
			return [
				["sph", Vector3(0, 0.2, 0), Vector3(0.52, 0.4, 0.44), y],
				["sph", Vector3(0.15, 0.5, 0), Vector3(0.3, 0.3, 0.3), y],
				["sph", Vector3(0.33, 0.47, 0), Vector3(0.16, 0.06, 0.13), Color(1.0, 0.45, 0.1)],
				["sph", Vector3(0.26, 0.56, 0.09), Vector3(0.05, 0.05, 0.05), BLACK],
				["sph", Vector3(0.26, 0.56, -0.09), Vector3(0.05, 0.05, 0.05), BLACK],
				["cone", Vector3(-0.25, 0.32, 0), Vector3(0.14, 0.18, 0.14), y, Vector3(0, 0, 40)],
			]
		"propeller_cap":
			return [
				["sph", Vector3(0, 0.03, 0), Vector3(0.86, 0.52, 0.86), Color(0.9, 0.15, 0.15)],
				["sph", Vector3(0.01, 0.04, 0), Vector3(0.88, 0.5, 0.3), Color(0.15, 0.35, 0.95)],
				["box", Vector3(0.44, 0.02, 0), Vector3(0.28, 0.03, 0.5), Color(0.15, 0.35, 0.95)],
				["cyl", Vector3(0, 0.33, 0), Vector3(0.05, 0.16, 0.05), Color(1.0, 0.85, 0.1)],
				["box", Vector3(0, 0.42, 0), Vector3(0.9, 0.02, 0.12), Color(1.0, 0.85, 0.1), Vector3.ZERO, {"spin": Vector3(0, 16, 0)}],
			]
		"traffic_cone":
			var o := Color(1.0, 0.42, 0.05)
			return [
				["box", Vector3(0, 0.02, 0), Vector3(0.72, 0.05, 0.72), o],
				["cone", Vector3(0, 0.4, 0), Vector3(0.6, 0.76, 0.6), o, Vector3.ZERO, {"top": 0.12}],
				["cyl", Vector3(0, 0.42, 0), Vector3(0.39, 0.13, 0.39), WHITE, Vector3.ZERO, {"top": 0.8, "glow": 0.4}],
			]
		"bone_necklace":
			return [
				["torus", Vector3(0, 0, 0), Vector3(1.3, 0.05, 1.3), Color(0.35, 0.22, 0.12)],
				["cap", Vector3(0, 0, 0), Vector3(0.08, 0.3, 0.08), BONE, Vector3(0, 0, 90), {"around": [11, 0.7]}],
				["sph", Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.1), BONE, Vector3.ZERO, {"around": [11, 0.85]}],
			]
		"dynamite_tail":
			return [
				["cyl", Vector3(0.05, 0, 0), Vector3(0.36, 0.55, 0.36), Color(0.8, 0.1, 0.08), Vector3(0, 0, 90)],
				["torus", Vector3(0.05, 0, 0), Vector3(0.38, 0.04, 0.38), Color(0.3, 0.22, 0.1), Vector3(0, 0, 90)],
				["cyl", Vector3(-0.35, 0.12, 0), Vector3(0.03, 0.35, 0.03), BLACK, Vector3(0, 0, 55)],
				["sph", Vector3(-0.5, 0.22, 0), Vector3(0.16, 0.16, 0.16), Color(1.0, 0.6, 0.15), Vector3.ZERO, {"glow": 6.0, "flicker": true}],
			]
		"toy_chopper":
			var olive := Color(0.35, 0.42, 0.22)
			return [
				["sph", Vector3(0, 0.3, 0), Vector3(0.75, 0.45, 0.5), olive],
				["sph", Vector3(0.25, 0.32, 0), Vector3(0.28, 0.28, 0.4), Color(0.5, 0.75, 0.95), Vector3.ZERO, {"metal": 0.5, "rough": 0.1}],
				["box", Vector3(-0.6, 0.35, 0), Vector3(0.7, 0.1, 0.1), olive],
				["box", Vector3(-0.92, 0.45, 0), Vector3(0.1, 0.25, 0.04), olive],
				["cyl", Vector3(0, 0.58, 0), Vector3(0.06, 0.2, 0.06), IRON],
				["box", Vector3(0, 0.69, 0), Vector3(1.7, 0.02, 0.12), IRON, Vector3.ZERO, {"spin": Vector3(0, 18, 0)}],
				["box", Vector3(0, 0.69, 0), Vector3(0.12, 0.02, 1.7), IRON, Vector3.ZERO, {"spin": Vector3(0, 18, 0)}],
			]
		"tinfoil_hat":
			return [
				["cone", Vector3(0, 0.3, 0), Vector3(0.8, 0.62, 0.8), SILVER, Vector3(0, 0, 6), {"metal": 1.0, "rough": 0.45, "seg": 7}],
				["cyl", Vector3(0.03, 0.66, 0), Vector3(0.02, 0.14, 0.02), SILVER, Vector3.ZERO, metal],
				["sph", Vector3(0.04, 0.75, 0), Vector3(0.09, 0.09, 0.09), Color(0.3, 1.0, 0.4), Vector3.ZERO, {"glow": 4.0}],
			]
		"hard_hat":
			var y := Color(1.0, 0.8, 0.1)
			return [
				["sph", Vector3(0, 0.04, 0), Vector3(0.92, 0.62, 0.9), y],
				["sph", Vector3(0.06, 0.02, 0), Vector3(1.14, 0.05, 1.0), y],
				["box", Vector3(0, 0.3, 0), Vector3(0.72, 0.08, 0.1), y.darkened(0.1)],
				["cyl", Vector3(0.44, 0.17, 0), Vector3(0.16, 0.08, 0.16), WHITE, Vector3(0, 0, 90), {"glow": 3.0}],
			]
		"wrecking_ball":
			return [
				["torus", Vector3(0.05, 0, 0), Vector3(0.36, 0.07, 0.36), IRON, Vector3(0, 0, 90), metal],
				["cyl", Vector3(-0.08, -0.35, 0), Vector3(0.05, 0.7, 0.05), IRON, Vector3(0, 0, -20), metal],
				["sph", Vector3(-0.2, -0.95, 0), Vector3(0.62, 0.62, 0.62), IRON, Vector3.ZERO, {"metal": 0.9, "rough": 0.5}],
			]
		"tnt_pack":
			var out := []
			for z in [-0.33, 0.0, 0.33]:
				out.append(["cyl", Vector3(-0.1, 0.42, z), Vector3(0.3, 0.85, 0.3), Color(0.8, 0.1, 0.08)])
			out.append(["box", Vector3(-0.1, 0.4, 0), Vector3(0.34, 0.12, 1.0), Color(0.3, 0.22, 0.1)])
			out.append(["box", Vector3(0.1, 0.56, 0), Vector3(0.08, 0.26, 0.42), BLACK])
			out.append(["box", Vector3(0.145, 0.56, 0), Vector3(0.02, 0.1, 0.3), Color(1.0, 0.1, 0.1), Vector3.ZERO, {"glow": 4.0, "flicker": true}])
			return out
		"tourist_camera":
			return [
				["torus", Vector3(0, -0.04, 0), Vector3(1.32, 0.04, 1.32), Color(0.2, 0.4, 0.8), Vector3(0, 0, 10)],
				["box", Vector3(0.74, -0.25, 0), Vector3(0.18, 0.3, 0.46), BLACK],
				["cyl", Vector3(0.86, -0.25, 0), Vector3(0.2, 0.14, 0.2), IRON, Vector3(0, 0, 90), metal],
				["cyl", Vector3(0.94, -0.25, 0), Vector3(0.14, 0.02, 0.14), Color(0.4, 0.6, 1.0), Vector3(0, 0, 90), {"metal": 0.5, "rough": 0.05}],
				["box", Vector3(0.74, -0.06, 0.14), Vector3(0.1, 0.06, 0.1), SILVER, Vector3.ZERO, metal],
			]
		"sweatband":
			return [
				["torus", Vector3(0, -0.06, 0), Vector3(1.12, 0.24, 1.06), Color(0.9, 0.1, 0.15)],
				["torus", Vector3(0, -0.06, 0), Vector3(1.14, 0.08, 1.08), WHITE],
			]
		"star_shades":
			var pink := Color(1.0, 0.25, 0.7)
			return [
				["cyl", Vector3(0.06, 0.02, 0.53), Vector3(0.42, 0.04, 0.42), pink, Vector3(90, 0, 0), {"seg": 5, "glow": 0.6}],
				["cyl", Vector3(0.06, 0.02, -0.53), Vector3(0.42, 0.04, 0.42), pink, Vector3(90, 0, 0), {"seg": 5, "glow": 0.6}],
				["cyl", Vector3(0.06, 0.02, 0.555), Vector3(0.28, 0.02, 0.28), Color(0.15, 0.05, 0.2), Vector3(90, 0, 0), {"seg": 5, "rough": 0.05}],
				["cyl", Vector3(0.06, 0.02, -0.555), Vector3(0.28, 0.02, 0.28), Color(0.15, 0.05, 0.2), Vector3(90, 0, 0), {"seg": 5, "rough": 0.05}],
				["box", Vector3(0.25, 0.14, 0), Vector3(0.05, 0.05, 1.1), pink],
			]
		"flame_tip":
			return [
				["cone", Vector3(-0.2, 0.25, 0), Vector3(0.4, 0.75, 0.4), Color(1.0, 0.35, 0.05), Vector3(0, 0, 30), {"glow": 3.5, "flicker": true}],
				["cone", Vector3(-0.17, 0.2, 0), Vector3(0.24, 0.5, 0.24), Color(1.0, 0.85, 0.3), Vector3(0, 0, 30), {"glow": 5.0, "flicker": true}],
			]
		"devil_horns":
			var red := Color(0.8, 0.05, 0.08)
			return [
				["cone", Vector3(0.05, 0.12, 0.3), Vector3(0.17, 0.42, 0.17), red, Vector3(25, 0, -15), {"rough": 0.2, "glow": 0.4}],
				["cone", Vector3(0.05, 0.12, -0.3), Vector3(0.17, 0.42, 0.17), red, Vector3(-25, 0, -15), {"rough": 0.2, "glow": 0.4}],
			]
		"ruff_collar":
			return [
				["torus", Vector3(0, 0, 0), Vector3(1.3, 0.2, 1.3), WHITE],
				["sph", Vector3(0, 0, 0), Vector3(0.34, 0.2, 0.26), WHITE, Vector3.ZERO, {"around": [16, 0.66]}],
				["sph", Vector3(0, 0.08, 0), Vector3(0.3, 0.16, 0.22), WHITE.darkened(0.08), Vector3.ZERO, {"around": [16, 0.7]}],
			]
		"hero_cape":
			# A sheet over the shoulders that falls to both sides and flares
			# out towards the tail.
			var red := Color(0.85, 0.08, 0.1)
			var out := [
				["box", Vector3(-0.8, 0.02, 0), Vector3(1.7, 0.05, 1.5), red, Vector3(0, 0, 12), {"rough": 0.6}],
				["box", Vector3(-0.8, -0.01, 0), Vector3(1.66, 0.05, 1.46), GOLD, Vector3(0, 0, 12)],
				["torus", Vector3(0.25, -0.05, 0), Vector3(1.25, 0.1, 1.25), GOLD, Vector3(0, 0, 70), metal],
			]
			for side in [-1.0, 1.0]:
				out.append(["box", Vector3(-0.85, -0.5, 0.86 * side), Vector3(1.75, 1.05, 0.05), red,
					Vector3(-14 * side, 0, 12), {"rough": 0.6}])
				out.append(["sph", Vector3(0.2, -0.05, 0.62 * side), Vector3(0.16, 0.16, 0.1), GOLD, Vector3.ZERO, metal])
			return out
		"fire_helmet":
			var red := Color(0.8, 0.08, 0.06)
			return [
				["sph", Vector3(0, 0.04, 0), Vector3(0.9, 0.6, 0.88), red, Vector3.ZERO, {"rough": 0.25}],
				["box", Vector3(-0.42, 0.02, 0), Vector3(0.5, 0.04, 0.9), red, Vector3(0, 0, 15), {"rough": 0.25}],
				["box", Vector3(0, 0.3, 0), Vector3(0.7, 0.07, 0.07), red.darkened(0.2)],
				["box", Vector3(0.42, 0.26, 0), Vector3(0.05, 0.3, 0.26), GOLD, Vector3(0, 0, -10), metal],
			]
		"whistle":
			return [
				["torus", Vector3(0, -0.04, 0), Vector3(1.32, 0.03, 1.32), Color(0.1, 0.3, 0.9), Vector3(0, 0, 10)],
				["cyl", Vector3(0.74, -0.28, 0), Vector3(0.02, 0.4, 0.02), Color(0.1, 0.3, 0.9)],
				["cap", Vector3(0.76, -0.5, 0), Vector3(0.14, 0.2, 0.14), SILVER, Vector3(90, 0, 0), metal],
				["box", Vector3(0.76, -0.5, 0.15), Vector3(0.1, 0.08, 0.14), SILVER, Vector3.ZERO, metal],
			]
		"hiking_pack":
			var green := Color(0.2, 0.45, 0.25)
			return [
				["box", Vector3(-0.15, 0.36, 0), Vector3(0.6, 0.7, 0.82), green],
				["box", Vector3(-0.46, 0.26, 0), Vector3(0.12, 0.38, 0.52), green.darkened(0.25)],
				["cap", Vector3(-0.12, 0.78, 0), Vector3(0.26, 0.9, 0.26), Color(0.2, 0.4, 0.85), Vector3(90, 0, 0)],
				["cyl", Vector3(-0.5, 0.55, 0.3), Vector3(0.22, 0.05, 0.22), IRON, Vector3(0, 0, 90), metal],
			]
		"ninja_mask":
			return [
				["torus", Vector3(-0.05, 0.02, 0), Vector3(1.2, 0.3, 1.12), BLACK],
				["box", Vector3(0.0, 0.03, 0.58), Vector3(0.24, 0.05, 0.02), WHITE, Vector3.ZERO, {"glow": 2.0}],
				["box", Vector3(0.0, 0.03, -0.58), Vector3(0.24, 0.05, 0.02), WHITE, Vector3.ZERO, {"glow": 2.0}],
				["box", Vector3(-0.72, -0.05, 0.06), Vector3(0.45, 0.08, 0.12), BLACK, Vector3(0, 15, 30)],
				["box", Vector3(-0.7, -0.1, -0.06), Vector3(0.4, 0.08, 0.12), BLACK, Vector3(0, -15, 40)],
			]
		"jetpack":
			return [
				["box", Vector3(-0.1, 0.3, 0), Vector3(0.18, 0.5, 0.5), IRON, Vector3.ZERO, metal],
				["cap", Vector3(-0.18, 0.36, 0.24), Vector3(0.3, 0.8, 0.3), SILVER, Vector3.ZERO, metal],
				["cap", Vector3(-0.18, 0.36, -0.24), Vector3(0.3, 0.8, 0.3), SILVER, Vector3.ZERO, metal],
				["cone", Vector3(-0.18, -0.2, 0.24), Vector3(0.2, 0.45, 0.2), Color(1.0, 0.5, 0.1), Vector3(180, 0, 0), {"glow": 4.0, "flicker": true}],
				["cone", Vector3(-0.18, -0.2, -0.24), Vector3(0.2, 0.45, 0.2), Color(1.0, 0.5, 0.1), Vector3(180, 0, 0), {"glow": 4.0, "flicker": true}],
			]
		"grad_cap":
			return [
				["cyl", Vector3(0, 0.1, 0), Vector3(0.64, 0.22, 0.64), BLACK],
				["box", Vector3(0, 0.24, 0), Vector3(0.95, 0.04, 0.95), BLACK, Vector3(0, 45, 0)],
				["sph", Vector3(0, 0.27, 0), Vector3(0.07, 0.04, 0.07), GOLD, Vector3.ZERO, metal],
				["cyl", Vector3(0.3, 0.12, 0.3), Vector3(0.02, 0.26, 0.02), GOLD],
				["cyl", Vector3(0.3, -0.02, 0.3), Vector3(0.07, 0.12, 0.07), GOLD, Vector3.ZERO, {"top": 0.3}],
			]
		"monocle":
			return [
				["torus", Vector3(0.06, 0.02, 0.54), Vector3(0.34, 0.04, 0.34), GOLD, Vector3(90, 0, 0), metal],
				["cyl", Vector3(0.06, 0.02, 0.54), Vector3(0.28, 0.01, 0.28), Color(0.8, 0.9, 1.0), Vector3(90, 0, 0), {"metal": 0.4, "rough": 0.05}],
				["cyl", Vector3(-0.04, -0.3, 0.55), Vector3(0.015, 0.5, 0.015), GOLD, Vector3(0, 0, -20), metal],
			]
		"medal":
			var blue := Color(0.1, 0.25, 0.75)
			return [
				["torus", Vector3(0, -0.02, 0), Vector3(1.34, 0.05, 1.34), blue, Vector3(0, 0, 8)],
				["box", Vector3(0.7, -0.24, 0), Vector3(0.04, 0.4, 0.2), blue],
				["cyl", Vector3(0.73, -0.5, 0), Vector3(0.32, 0.05, 0.32), GOLD, Vector3(0, 0, 90), metal],
				["cyl", Vector3(0.76, -0.5, 0), Vector3(0.18, 0.02, 0.18), GOLD.lightened(0.3), Vector3(0, 0, 90), {"seg": 5, "metal": 1.0}],
			]
		"rainbow_scarf":
			var cols := [Color(0.9, 0.15, 0.15), Color(1.0, 0.55, 0.1), Color(1.0, 0.9, 0.15), Color(0.2, 0.8, 0.3),
				Color(0.2, 0.45, 0.95), Color(0.55, 0.25, 0.85)]
			var out := []
			for i in cols.size():
				out.append(["torus", Vector3(0, 0.2 - i * 0.08, 0), Vector3(1.4, 0.1, 1.4), cols[i]])
				out.append(["box", Vector3(0.62, -0.25 - i * 0.1, 0.3), Vector3(0.14, 0.1, 0.24), cols[i], Vector3(0, 0, 8)])
			return out
		"wizard_hat":
			var purple := Color(0.32, 0.15, 0.6)
			return [
				["sph", Vector3(0, 0.03, 0), Vector3(1.25, 0.05, 1.25), purple],
				["cone", Vector3(-0.08, 0.6, 0), Vector3(0.66, 1.15, 0.66), purple, Vector3(0, 0, 12)],
				["sph", Vector3(0.22, 0.45, 0.14), Vector3(0.08, 0.08, 0.08), Color(1.0, 0.9, 0.3), Vector3.ZERO, {"glow": 4.0}],
				["sph", Vector3(0.05, 0.8, -0.1), Vector3(0.06, 0.06, 0.06), Color(1.0, 0.9, 0.3), Vector3.ZERO, {"glow": 4.0}],
				["sph", Vector3(0.2, 0.25, -0.24), Vector3(0.07, 0.07, 0.07), Color(1.0, 0.9, 0.3), Vector3.ZERO, {"glow": 4.0}],
			]
		"halo":
			return [["torus", Vector3(0, 0.32, 0), Vector3(0.8, 0.08, 0.8), Color(1.0, 0.92, 0.5), Vector3.ZERO, {"glow": 3.0, "bob": 0.05}]]
		"eyepatch":
			return [
				["cyl", Vector3(0.04, 0.02, 0.55), Vector3(0.36, 0.05, 0.32), BLACK, Vector3(90, 0, 0)],
				["torus", Vector3(-0.1, 0.08, 0), Vector3(1.2, 0.05, 1.12), BLACK, Vector3(0, 0, -25)],
			]
		"prayer_beads":
			return [
				["sph", Vector3(0, 0, 0), Vector3(0.13, 0.13, 0.13), Color(0.45, 0.25, 0.12), Vector3.ZERO, {"around": [18, 0.66]}],
				["sph", Vector3(0.68, -0.2, 0), Vector3(0.16, 0.16, 0.16), Color(0.1, 0.6, 0.4)],
				["cone", Vector3(0.68, -0.38, 0), Vector3(0.12, 0.25, 0.12), Color(0.9, 0.2, 0.15), Vector3(180, 0, 0)],
			]
		"racing_goggles":
			return [
				["torus", Vector3(-0.08, 0.2, 0), Vector3(1.16, 0.1, 1.08), Color(0.4, 0.25, 0.12)],
				["cyl", Vector3(0.02, 0.2, 0.52), Vector3(0.32, 0.12, 0.32), SILVER, Vector3(90, 0, 0), metal],
				["cyl", Vector3(0.02, 0.2, -0.52), Vector3(0.32, 0.12, 0.32), SILVER, Vector3(90, 0, 0), metal],
				["cyl", Vector3(0.02, 0.2, 0.585), Vector3(0.24, 0.02, 0.24), Color(1.0, 0.6, 0.1), Vector3(90, 0, 0), {"glow": 0.8, "rough": 0.05}],
				["cyl", Vector3(0.02, 0.2, -0.585), Vector3(0.24, 0.02, 0.24), Color(1.0, 0.6, 0.1), Vector3(90, 0, 0), {"glow": 0.8, "rough": 0.05}],
			]
		"bowtie":
			var red := Color(0.85, 0.1, 0.2)
			return [
				["cone", Vector3(0.66, 0, 0.16), Vector3(0.1, 0.3, 0.32), red, Vector3(-90, 0, 0)],
				["cone", Vector3(0.66, 0, -0.16), Vector3(0.1, 0.3, 0.32), red, Vector3(90, 0, 0)],
				["sph", Vector3(0.67, 0, 0), Vector3(0.1, 0.12, 0.12), red.darkened(0.2)],
			]
		"balloon":
			return [
				["cyl", Vector3(-0.1, 0.9, 0), Vector3(0.015, 1.8, 0.015), WHITE],
				["sph", Vector3(-0.1, 2.15, 0), Vector3(0.72, 0.88, 0.72), Color(0.95, 0.15, 0.2), Vector3.ZERO, {"rough": 0.15, "bob": 0.08}],
				["cone", Vector3(-0.1, 1.68, 0), Vector3(0.1, 0.1, 0.1), Color(0.95, 0.15, 0.2), Vector3(180, 0, 0)],
			]
		"clown_nose":
			return [["sph", Vector3(0.64, 0.04, 0), Vector3(0.36, 0.36, 0.36), Color(0.95, 0.05, 0.08), Vector3.ZERO, {"rough": 0.15}]]
		"lollipop":
			var pink := Color(1.0, 0.35, 0.65)
			return [
				["cyl", Vector3(-0.15, 0.32, 0), Vector3(0.05, 0.7, 0.05), WHITE, Vector3(0, 0, 25)],
				["cyl", Vector3(-0.32, 0.72, 0), Vector3(0.6, 0.1, 0.6), pink, Vector3(90, 0, 0), {"rough": 0.15}],
				["torus", Vector3(-0.32, 0.72, 0), Vector3(0.42, 0.05, 0.42), WHITE, Vector3(90, 0, 0)],
				["torus", Vector3(-0.32, 0.72, 0), Vector3(0.22, 0.05, 0.22), WHITE, Vector3(90, 0, 0)],
			]
		"top_hat":
			return [
				["cyl", Vector3(0, 0.03, 0), Vector3(1.0, 0.04, 0.95), BLACK],
				["cyl", Vector3(0, 0.4, 0), Vector3(0.62, 0.74, 0.6), BLACK],
				["cyl", Vector3(0, 0.12, 0), Vector3(0.64, 0.12, 0.62), Color(0.7, 0.05, 0.1)],
			]
		"spiked_collar":
			return [
				["torus", Vector3(0, 0, 0), Vector3(1.38, 0.3, 1.38), BLACK, Vector3.ZERO, {"rough": 0.4}],
				["cone", Vector3(0, 0, 0), Vector3(0.13, 0.24, 0.13), SILVER, Vector3(0, 0, -90), {"metal": 1.0, "around": [10, 0.78]}],
			]
	return []
