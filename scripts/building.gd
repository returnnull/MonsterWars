class_name Building
extends Node3D
## Destructible building. Takes damage from attacks (try_hit / try_beam),
## darkens as it is damaged, and collapses into the street with debris.

const SHADER := preload("res://shaders/building.gdshader")
const WALLS := [Color(0.34, 0.36, 0.4), Color(0.45, 0.4, 0.34), Color(0.28, 0.3, 0.36),
	Color(0.5, 0.48, 0.45), Color(0.3, 0.25, 0.24)]
const LIGHTS := [Color(1.0, 0.78, 0.45), Color(0.75, 0.9, 1.0), Color(1.0, 0.9, 0.7)]

## Country look for buildings created from now on: walls (Array of Color),
## window (Color), lit (lit-window ratio), emission. Set by the stage builder.
static var style := {}

var size := Vector3(8, 16, 7)
var hp := 60.0
var max_hp := 60.0
var destroyed := false

var _holder: Node3D
var _mat: ShaderMaterial
var _beacon_mat: StandardMaterial3D
var _shake := 0.0
var _t := 0.0


static func make_material(seed_value: float, lit_ratio: float, emission: float, facade: int = -1) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var walls: Array = style.get("walls", WALLS)
	var wall: Color = walls[int(seed_value * 7.0) % walls.size()]
	wall = wall.darkened(fmod(seed_value * 3.7, 1.0) * 0.2)
	if facade < 0:
		facade = pick_facade(seed_value)
	var glass := Color(0.05, 0.075, 0.11)
	var cell := Vector2(randf_range(0.95, 1.15), randf_range(0.95, 1.05))
	match facade:
		1:
			cell = Vector2(randf_range(1.05, 1.3), randf_range(1.05, 1.2))
		2:
			cell = Vector2(randf_range(0.8, 1.0), 0.9)
			glass = [Color(0.06, 0.1, 0.16), Color(0.05, 0.12, 0.12), Color(0.1, 0.1, 0.12), Color(0.12, 0.1, 0.07)][int(seed_value * 11.0) % 4]
			wall = wall.lerp(Color(0.25, 0.28, 0.32), 0.5)
		3:
			cell = Vector2(randf_range(0.9, 1.1), 1.0)
	m.set_shader_parameter("wall_color", wall)
	m.set_shader_parameter("trim_color", wall.darkened(0.35) if facade != 1 else wall.lerp(Color(0.9, 0.88, 0.82), 0.45))
	m.set_shader_parameter("glass_color", glass)
	m.set_shader_parameter("roof_color", style.get("roof_flat", Color(0.3, 0.3, 0.31)))
	m.set_shader_parameter("lit_color", style.get("window", LIGHTS[int(seed_value * 13.0) % LIGHTS.size()]))
	m.set_shader_parameter("seed", seed_value)
	m.set_shader_parameter("lit_ratio", lit_ratio)
	m.set_shader_parameter("emission_strength", emission)
	m.set_shader_parameter("shop_emission", style.get("shop", 0.6))
	m.set_shader_parameter("snow", style.get("snow", 0.0))
	m.set_shader_parameter("style", facade)
	m.set_shader_parameter("cell", cell)
	return m


## Facade style (see building.gdshader) from the country's "facades" weights.
static func pick_facade(seed_value: float) -> int:
	var w: Array = style.get("facades", [0.4, 0.3, 0.2, 0.1])
	var total := 0.0
	for v in w:
		total += v
	var r := fmod(seed_value * 7.31, 1.0) * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return 0


func _ready() -> void:
	add_to_group("buildings")
	max_hp = 25.0 + size.x * size.y * 0.35
	hp = max_hp
	_holder = Node3D.new()
	add_child(_holder)
	var lit: float = style.get("lit", 0.3)
	_mat = make_material(randf() * 10.0, clampf(lit + randf_range(-0.1, 0.1), 0.0, 1.0), style.get("emission", 1.3))
	var seed_i := randi()
	var info := build_tower(_holder, size, _mat, seed_i, true)
	add_facade_signs(_holder, size, seed_i)
	if info.has("beacon"):
		_beacon_mat = info["beacon"]
	Game.buildings_total += 1


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_holder.add_child(mi)


# --- procedural tower construction (shared with the stage skyline) ---------

static var _cache := {}


## Builds a building of footprint/height `sz` (origin at the base centre) under
## `parent`: setback tiers with cornices, a roof shape and rooftop clutter,
## and neon signs in night cities. Returns {"beacon": material} when it has a
## blinking aircraft light. `detail` adds the small props.
static func build_tower(parent: Node3D, sz: Vector3, mat: ShaderMaterial, seed_i: int, detail: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var out := {}
	var facade: int = mat.get_shader_parameter("style")
	var trim: Color = mat.get_shader_parameter("trim_color")
	var cornice_mat := _std(trim.darkened(0.1), 0.85)
	# Setback tiers for tall buildings.
	var tiers: Array = []
	var foot := Vector2(sz.x, sz.z)
	var y := 0.0
	if sz.y > 13.0 and rng.randf() < 0.65:
		var n := 2 if sz.y < 22.0 or rng.randf() < 0.5 else 3
		var left := sz.y
		for i in n:
			var th := left if i == n - 1 else left * rng.randf_range(0.55, 0.72)
			tiers.append([foot, y, th])
			y += th
			left -= th
			foot = Vector2(maxf(foot.x * rng.randf_range(0.66, 0.82), 2.5), maxf(foot.y * rng.randf_range(0.7, 0.85), 2.5))
	else:
		tiers.append([foot, 0.0, sz.y])
	for t in tiers:
		var f: Vector2 = t[0]
		var mi := _inst(parent, _unit_box(), mat, Vector3(0, t[1] + t[2] * 0.5, 0))
		mi.scale = Vector3(f.x, t[2], f.y)
		# Cornice ledge around the top of each tier.
		if facade != 2:
			var c := _inst(parent, _unit_box(), cornice_mat, Vector3(0, t[1] + t[2] - 0.08, 0))
			c.scale = Vector3(f.x + 0.24, 0.16, f.y + 0.24)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var last: Array = tiers[-1]
	var top: float = last[1] + last[2]
	var tf: Vector2 = last[0]

	# Roof shape.
	var roofs: Array = style.get("roofs", ["flat"])
	var roof: String = roofs[rng.randi() % roofs.size()]
	if roof in ["gable", "hip", "mansard"] and (sz.y > 16.0 or facade == 2):
		roof = "flat"
	if roof == "crown" and sz.y < 12.0:
		roof = "flat"
	var roof_cols: Array = style.get("roof_colors", [Color(0.3, 0.3, 0.32)])
	var rc: Color = roof_cols[rng.randi() % roof_cols.size()]
	var snow: float = style.get("snow", 0.0)
	match roof:
		"gable", "hip", "mansard":
			var shape := {"gable": Vector2(1.0, 0.0), "hip": Vector2(0.45, 0.0), "mansard": Vector2(0.8, 0.55)}[roof] as Vector2
			var rh := minf(tf.y * (0.45 if roof != "mansard" else 0.32), 3.0)
			var r := _inst(parent, frustum_mesh(shape.x, shape.y), _std(rc.lerp(Color(0.93, 0.95, 1.0), snow * 0.7), 0.7), Vector3(0, top, 0))
			r.scale = Vector3(tf.x + 0.3, rh, tf.y + 0.3)
			if roof != "hip" and detail:
				# Dormers / chimneys.
				for i in rng.randi_range(1, 3):
					var ch := _inst(parent, _unit_box(), cornice_mat, Vector3(rng.randf_range(-0.35, 0.35) * tf.x, top + rh * 0.55, rng.randf_range(-0.2, 0.2) * tf.y))
					ch.scale = Vector3(0.35, rh * 0.9, 0.35)
			return out
		"crown":
			var steps := rng.randi_range(2, 3)
			var w := tf
			var cy := top
			for i in steps:
				w *= 0.72
				var s := _inst(parent, _unit_box(), mat, Vector3(0, cy + 0.6, 0))
				s.scale = Vector3(w.x, 1.2, w.y)
				cy += 1.2
			var spire := _inst(parent, frustum_mesh(0.0, 0.0), _std(trim.lerp(Color(0.8, 0.8, 0.82), 0.4), 0.35, 0.6), Vector3(0, cy, 0))
			spire.scale = Vector3(w.x * 0.8, rng.randf_range(3.0, 7.0), w.y * 0.8)
			var lamp := _inst(parent, _unit_box(), _glow_mat(style.get("window", Color(1, 0.85, 0.6)), 3.0), Vector3(0, cy - 0.6, 0))
			lamp.scale = Vector3(w.x / 0.72 + 0.05, 0.12, w.y / 0.72 + 0.05)
			return out
		"dome":
			var d := _inst(parent, _cached("dome", func() -> Mesh:
				var s := SphereMesh.new()
				s.radius = 0.5
				s.height = 0.5
				s.is_hemisphere = true
				return s), _std(rc, 0.4, 0.5), Vector3(0, top, 0))
			var ds := minf(tf.x, tf.y) * 0.8
			d.scale = Vector3(ds, ds * 1.3, ds)
			return out

	# Flat roof clutter.
	if not detail:
		return out
	var props := _std(Color(0.42, 0.42, 0.44), 0.8)
	# Stair / lift housing.
	if tf.x > 3.0:
		var hx := rng.randf_range(-0.25, 0.25) * tf.x
		var h := _inst(parent, _unit_box(), props, Vector3(hx, top + 0.5, -tf.y * 0.2))
		h.scale = Vector3(rng.randf_range(1.2, 2.0), 1.0, rng.randf_range(1.0, 1.6))
	# AC units.
	for i in rng.randi_range(1, 4):
		var a := _inst(parent, _unit_box(), props, Vector3(rng.randf_range(-0.4, 0.4) * tf.x, top + 0.2, rng.randf_range(-0.4, 0.4) * tf.y))
		a.scale = Vector3(rng.randf_range(0.5, 0.9), 0.4, rng.randf_range(0.4, 0.7))
		a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if roof == "tank":
		var tx := rng.randf_range(-0.3, 0.3) * tf.x
		var tz := rng.randf_range(-0.3, 0.1) * tf.y
		var wood := _std(Color(0.42, 0.3, 0.2), 0.9)
		var tank := _inst(parent, _cached("tank", func() -> Mesh:
			var cy := CylinderMesh.new()
			cy.top_radius = 0.5
			cy.bottom_radius = 0.5
			cy.height = 1.0
			cy.radial_segments = 10
			cy.rings = 1
			return cy), wood, Vector3(tx, top + 1.6, tz))
		tank.scale = Vector3(1.2, 1.3, 1.2)
		var cap := _inst(parent, frustum_mesh(0.0, 0.0), _std(Color(0.25, 0.25, 0.27), 0.6, 0.4), Vector3(tx, top + 2.25, tz))
		cap.scale = Vector3(1.25, 0.45, 1.25)
		for lx in [-0.4, 0.4]:
			for lz in [-0.4, 0.4]:
				var leg := _inst(parent, _unit_box(), props, Vector3(tx + lx, top + 0.5, tz + lz))
				leg.scale = Vector3(0.08, 1.0, 0.08)
	elif roof == "helipad" and tf.x > 4.5 and tf.y > 4.5:
		var pad := _inst(parent, _cached("pad", func() -> Mesh:
			var cy := CylinderMesh.new()
			cy.top_radius = 0.5
			cy.bottom_radius = 0.5
			cy.height = 1.0
			cy.radial_segments = 16
			cy.rings = 1
			return cy), _std(Color(0.2, 0.22, 0.24), 0.7), Vector3(0, top + 0.12, 0))
		var pr := minf(tf.x, tf.y) * 0.8
		pad.scale = Vector3(pr, 0.12, pr)
		var ring := _inst(parent, _cached("ring", func() -> Mesh:
			var to := TorusMesh.new()
			to.inner_radius = 0.44
			to.outer_radius = 0.5
			to.rings = 16
			to.ring_segments = 4
			return to), _glow_mat(Color(1.0, 0.75, 0.2), 1.5), Vector3(0, top + 0.19, 0))
		ring.scale = Vector3(pr, 1.0, pr)
		for hx in [-0.12, 0.12]:
			var bar := _inst(parent, _unit_box(), _std(Color(0.9, 0.9, 0.9), 0.6), Vector3(hx * pr, top + 0.19, 0))
			bar.scale = Vector3(0.06 * pr, 0.02, 0.4 * pr)
		var mid := _inst(parent, _unit_box(), _std(Color(0.9, 0.9, 0.9), 0.6), Vector3(0, top + 0.19, 0))
		mid.scale = Vector3(0.24 * pr, 0.02, 0.06 * pr)
	# Antenna mast with aircraft beacon.
	if sz.y > 12.0 and rng.randf() < 0.7:
		var mh := rng.randf_range(2.5, 6.0)
		var mx := rng.randf_range(0.15, 0.35) * tf.x * (1.0 if rng.randf() < 0.5 else -1.0)
		var mast := _inst(parent, _cached("mast", func() -> Mesh:
			var cy := CylinderMesh.new()
			cy.top_radius = 0.02
			cy.bottom_radius = 0.06
			cy.height = 1.0
			cy.radial_segments = 5
			cy.rings = 1
			return cy), props, Vector3(mx, top + mh * 0.5, 0))
		mast.scale = Vector3(1, mh, 1)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(1, 0.1, 0.1)
		bm.emission_enabled = true
		bm.emission = Color(1, 0.1, 0.05)
		var bulb := _inst(parent, _unit_box(), bm, Vector3(mx, top + mh, 0))
		bulb.scale = Vector3.ONE * 0.22
		out["beacon"] = bm
	# Neon: rooftop billboard and signs on the front face.
	var neon: float = style.get("neon", 0.0)
	if neon >= 0.3 and rng.randf() < 0.2 + neon * 0.5 and tf.x > 3.0:
		var bw := minf(tf.x * 0.85, rng.randf_range(3.0, 6.0))
		var bh := bw * rng.randf_range(0.3, 0.45)
		var bz := tf.y * 0.5 - 0.3
		var frame := _inst(parent, _unit_box(), props, Vector3(0, top + 0.3 + bh * 0.5, bz - 0.12))
		frame.scale = Vector3(bw + 0.2, bh + 0.2, 0.15)
		_sign(parent, Vector3(0, top + 0.3 + bh * 0.5, bz), Vector2(bw, bh), rng, neon)
		for lx in [-0.35, 0.35]:
			var leg := _inst(parent, _unit_box(), props, Vector3(lx * bw, top + 0.2, bz - 0.15))
			leg.scale = Vector3(0.12, 0.4, 0.12)
	return out


## Neon / billboard signs on a building's front face (+Z), call after build_tower.
static func add_facade_signs(parent: Node3D, sz: Vector3, seed_i: int) -> void:
	var neon: float = style.get("neon", 0.0)
	if neon <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 77
	var z := sz.z * 0.5 + 0.06
	var count := int(rng.randf() * (1.0 + neon * 2.2))
	for i in count:
		if rng.randf() < 0.6:
			# Vertical banner.
			var h := minf(rng.randf_range(3.0, 7.0), sz.y - 2.5)
			if h < 2.0:
				continue
			var w := rng.randf_range(0.7, 1.0)
			var x := rng.randf_range(-0.5, 0.5) * (sz.x - w - 0.4)
			_sign(parent, Vector3(x, 2.0 + h * 0.5 + rng.randf() * maxf(sz.y - h - 3.0, 0.0), z), Vector2(w, h), rng, neon)
		else:
			var w := minf(rng.randf_range(2.5, 5.0), sz.x - 0.6)
			var h := rng.randf_range(0.7, 1.1)
			var y := rng.randf_range(2.2, maxf(sz.y - 1.5, 2.3))
			_sign(parent, Vector3(rng.randf_range(-0.3, 0.3) * (sz.x - w), y, z), Vector2(w, h), rng, neon)


static func _sign(parent: Node3D, pos: Vector3, s: Vector2, rng: RandomNumberGenerator, neon: float) -> void:
	var mi := _inst(parent, _cached("quad", func() -> Mesh:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		return q), _neon_material(), pos)
	mi.scale = Vector3(s.x, s.y, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var palette: Array = style.get("neon_colors", [Color(1.0, 0.2, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.5, 1.0, 0.3), Color(0.7, 0.4, 1.0)])
	mi.set_instance_shader_parameter("sign_color", palette[rng.randi() % palette.size()])
	mi.set_instance_shader_parameter("sign_seed", rng.randf() * 100.0)
	var vertical := s.y > s.x
	var cells := Vector2(1.0, maxf(1.0, roundf(s.y / s.x))) if vertical else Vector2(maxf(1.0, roundf(s.x / s.y * 1.4)), 1.0)
	mi.set_instance_shader_parameter("cells", cells)
	mi.set_instance_shader_parameter("brightness", 0.6 + neon * 2.6)


static func _neon_material() -> ShaderMaterial:
	if not _cache.has("neon_mat"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/neon_sign.gdshader")
		_cache["neon_mat"] = m
	return _cache["neon_mat"]


static func _inst(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cached(key: String, make: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _unit_box() -> Mesh:
	return _cached("box", func() -> Mesh:
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		return b)


## Shared StandardMaterial3D per colour, so rooftop props batch well.
static func _std(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var key := "std_%s_%.2f_%.2f" % [color.to_html(), rough, metal]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_cache[key] = m
	return _cache[key]


static func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var key := "glow_%s_%.2f" % [color.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		_cache[key] = m
	return _cache[key]


## Unit square frustum: base -0.5..0.5 at y=0, top rectangle of tx x tz
## (fractions of the base) at y=1. tx=1,tz=0 is a gable, 0,0 a pyramid.
static func frustum_mesh(tx: float, tz: float) -> Mesh:
	var key := "frustum_%.2f_%.2f" % [tx, tz]
	if _cache.has(key):
		return _cache[key]
	var b := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	var t := [Vector3(-0.5 * tx, 1, -0.5 * tz), Vector3(0.5 * tx, 1, -0.5 * tz), Vector3(0.5 * tx, 1, 0.5 * tz), Vector3(-0.5 * tx, 1, 0.5 * tz)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0, 0.4, 0)
	for i in 4:
		var j := (i + 1) % 4
		_quad(st, b[i], b[j], t[j], t[i], centre)
	_quad(st, t[0], t[1], t[2], t[3], centre)
	_quad(st, b[0], b[1], b[2], b[3], centre)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, centre: Vector3) -> void:
	_tri(st, a, b, c, centre)
	_tri(st, a, c, d, centre)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	var mid := (a + b + c) / 3.0
	if n.dot(mid - centre) < 0.0:
		n = -n
		var tmp := b
		b = c
		c = tmp
	# Godot treats clockwise triangles as front faces: cross(b-a, c-a) must point inward.
	var tmp2 := b
	b = c
	c = tmp2
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


func _aabb() -> AABB:
	return AABB(global_position - Vector3(size.x * 0.5, 0, size.z * 0.5), size)


func try_hit(center: Vector3, radius: float, dmg: float) -> bool:
	if destroyed:
		return false
	var box := _aabb()
	var closest := center.clamp(box.position, box.end)
	if closest.distance_to(center) > radius:
		return false
	damage(dmg, closest)
	return true


func try_beam(origin: Vector3, dir: float, length: float, dmg: float) -> bool:
	if destroyed:
		return false
	var box := _aabb()
	var x1 := origin.x + dir * length
	if maxf(origin.x, x1) < box.position.x or minf(origin.x, x1) > box.end.x:
		return false
	if absf(global_position.z - origin.z) > size.z * 0.5 + 8.0:
		return false
	var hit_x := clampf(origin.x + dir * 2.0, box.position.x, box.end.x)
	var face_z := box.end.z if origin.z > global_position.z else box.position.z
	damage(dmg, Vector3(hit_x, minf(origin.y, size.y - 0.5), face_z))
	return true


func damage(dmg: float, at: Vector3) -> void:
	if destroyed:
		return
	hp -= dmg
	_mat.set_shader_parameter("damage", clampf(1.0 - hp / max_hp, 0.0, 1.0))
	_shake = 0.3
	FX.debris_burst(at, 0.6)
	if hp <= 0.0:
		_destroy()


func _process(delta: float) -> void:
	_t += delta
	if _beacon_mat:
		_beacon_mat.emission_energy_multiplier = 6.0 if fmod(_t, 1.4) < 0.25 else 0.2
	if destroyed and is_instance_valid(_holder):
		_mat.set_shader_parameter("sink", _holder.position.y)
	if _shake > 0.0 and not destroyed:
		_shake -= delta
		_holder.position.x = randf_range(-1.0, 1.0) * _shake * 0.5
		_holder.position.z = randf_range(-1.0, 1.0) * _shake * 0.5
	elif not destroyed:
		_holder.position.x = 0.0
		_holder.position.z = 0.0


func _destroy() -> void:
	destroyed = true
	remove_from_group("buildings")
	Game.on_building_destroyed(self, size.y)
	Game.shake(0.4 + size.y * 0.02)
	var c := global_position + Vector3(0, size.y * 0.5, size.z * 0.5)
	FX.explosion(c, clampf(size.y / 10.0, 0.8, 2.2))
	FX.smoke(global_position + Vector3(0, 1, size.z * 0.3), clampf(size.x / 5.0, 1.0, 2.5), Color(0.5, 0.46, 0.4))
	_spawn_chunks()

	var tw := create_tween()
	tw.tween_property(_holder, "position:y", -size.y - 1.0, 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_holder, "rotation:z", randf_range(-0.12, 0.12), 1.6)
	tw.tween_callback(_holder.queue_free)
	_add_rubble()

	# Most buildings leave a piece behind that a kaiju can pick up and fight with.
	if randf() < 0.75:
		var w := Weapon.new()
		w.kind = Weapon.random_kind(size.y)
		w.position = Vector3(global_position.x + randf_range(-1.5, 1.5), 0.0, clampf(global_position.z + size.z * 0.5 + 2.5, -4.5, 1.5))
		get_parent().add_child(w)
	if randf() < 0.35:
		var orb := Pickup.new()
		orb.position = Vector3(global_position.x, 1.5, clampf(global_position.z, -4.5, 2.5))
		get_parent().add_child(orb)


func _spawn_chunks() -> void:
	var count := clampi(int(size.y * 0.6), 5, 14)
	for i in count:
		var rb := RigidBody3D.new()
		rb.collision_layer = Game.LAYER_DEBRIS
		rb.collision_mask = Game.LAYER_WORLD
		var s := Vector3(randf_range(0.6, 1.6), randf_range(0.5, 1.4), randf_range(0.6, 1.6))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s
		col.shape = shape
		rb.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s
		mi.mesh = bm
		mi.material_override = _mat
		rb.add_child(mi)
		get_parent().add_child(rb)
		rb.global_position = global_position + Vector3(randf_range(-0.5, 0.5) * size.x, randf_range(0.3, 0.9) * size.y, randf_range(-0.5, 0.5) * size.z)
		rb.apply_central_impulse(Vector3(randf_range(-6, 6), randf_range(4, 12), randf_range(1, 9)) * rb.mass)
		rb.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		var tw := rb.create_tween()
		tw.tween_interval(randf_range(4.0, 6.0))
		tw.tween_property(rb, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(rb.queue_free)


func _add_rubble() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.28, 0.27)
	mat.roughness = 1.0
	for i in 5:
		var b := BoxMesh.new()
		b.size = Vector3(size.x * randf_range(0.3, 0.6), randf_range(0.5, 1.6), size.z * randf_range(0.3, 0.6))
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.3, 0.3) * size.x, b.size.y * 0.3, randf_range(-0.3, 0.3) * size.z)
		mi.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		add_child(mi)
