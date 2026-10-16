extends Node3D
## Dev helper: screenshots of heroes wearing cosmetics (see Cosmetics).
##   COSMETIC_IDS "halo,monocle" picks items (default all); they are handed
##   out one per slot to as many heroes as needed, two heroes per shot.
##   COSMETIC_VIEW "side" (default), "flat" (straight side on), "front" or "back"; HERO_IDS "0,4" picks the
##   heroes worn on (cycled). COSMETIC_CLOSE=1 shoots a head close-up of one
##   hero per shot. Shots go to user://cosmetics_N.png.

const PER_SHOT := 2


func _ready() -> void:
	Game.set_meta("no_save", true)
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
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	var ids: Array = Cosmetics.ITEMS.keys()
	if OS.get_environment("COSMETIC_IDS") != "":
		ids = Array(OS.get_environment("COSMETIC_IDS").split(","))
	var heroes: Array = range(Content.HEROES.size())
	if OS.get_environment("HERO_IDS") != "":
		heroes = Array(OS.get_environment("HERO_IDS").split(",")).map(func(s: String) -> int: return int(s))
	# One outfit per hero: fill each slot once, then start the next outfit.
	var outfits: Array = []
	for id in ids:
		var slot: String = Cosmetics.item(id)["slot"]
		var placed := false
		for o in outfits:
			if not o.has(slot):
				o[slot] = id
				placed = true
				break
		if not placed:
			outfits.append({slot: id})
	var view := OS.get_environment("COSMETIC_VIEW")
	var yaw: float = {"front": -1.2, "back": 2.2, "flat": 0.0}.get(view, -0.35)
	var close := OS.get_environment("COSMETIC_CLOSE") == "1"
	var per := 1 if close else PER_SHOT
	for start in range(0, outfits.size(), per):
		var group := outfits.slice(start, start + per)
		var made: Array = []
		for i in group.size():
			var h := Content.hero(heroes[(start + i) % heroes.size()])
			var m := GlbKaijuModel.for_hero(h, self)
			m.scale = Vector3.ONE * float(h["size"])
			m.position.x = i * 11.0
			m.rotation.y = yaw
			Cosmetics.dress(m, group[i])
			made.append(m)
		cam.position = Vector3((group.size() - 1) * 5.5, 6.0, 26.0)
		cam.look_at(Vector3((group.size() - 1) * 5.5, 3.4, 0))
		if close:
			var head: Vector3 = made[0].to_global(Vector3(2.9, 4.2, 0))
			cam.position = head + Vector3(0, 1.2, 0) + Vector3(0, 0, 9.0).rotated(Vector3.UP, yaw + 0.35)
			cam.look_at(head)
		await get_tree().create_timer(1.0).timeout
		var n := start / per
		get_viewport().get_texture().get_image().save_png("user://cosmetics_%d.png" % n)
		print("shot cosmetics_%d: %s" % [n, group])
		for m in made:
			m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
