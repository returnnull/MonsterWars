extends Node
## Check: no enemy or boss may use a hero's look. Every boss and enemy kaiju
## must have a CreatureModel body plan (never the heroes' KaijuModel), and no
## enemy or boss may share a hero's name or colours.
##   godot --headless --path . res://tests/no_hero_enemies.tscn

func _ready() -> void:
	Game.set_meta("no_save", true)
	var errors: Array = []
	var hero_names := {}
	var hero_looks := {}
	for h in Content.HEROES:
		hero_names[h["name"]] = true
		hero_looks[_look(h["skin"], h["belly"], h["accent"])] = h["name"]
	for c in Content.COUNTRIES.size():
		var b := Content.boss(c)
		var body: String = b.get("body", "")
		if not CreatureModel.HEIGHT.has(body):
			errors.append("boss %s uses body '%s', not a CreatureModel plan" % [b["name"], body])
		if hero_names.has(b["name"]):
			errors.append("boss %s shares a hero's name" % b["name"])
		var look := _look(b.get("skin", Color.BLACK), b.get("belly", Color.BLACK), b.get("accent", Color.BLACK))
		if hero_looks.has(look):
			errors.append("boss %s has hero %s's colours" % [b["name"], hero_looks[look]])
	for id in Enemies.DEFS:
		var d: Dictionary = Enemies.DEFS[id]
		if hero_names.has(d.get("name", "")):
			errors.append("enemy %s shares a hero's name" % id)
		if d["class"] == "kaiju" and not CreatureModel.HEIGHT.has(d.get("body", "")):
			errors.append("enemy %s uses body '%s', not a CreatureModel plan" % [id, d.get("body", "")])
	# Spawned bosses and kaiju enemies must really build a CreatureModel.
	var ids: Array = ["boss"]
	for id in Enemies.DEFS:
		if Enemies.DEFS[id]["class"] == "kaiju":
			ids.append(id)
	for c in Content.COUNTRIES.size():
		for id in ids:
			if id != "boss" and c > 0:
				continue
			var e := Brute.new()
			e.kind = id
			if id == "boss":
				e.boss_def = Content.boss(c)
			add_child(e)
			if not (e.model is CreatureModel):
				errors.append("%s built a hero KaijuModel" % (e.boss_def.get("name", id)))
			e.free()
	if errors.is_empty():
		print("OK: no enemy or boss uses a hero model")
	else:
		for e in errors:
			printerr("FAIL: ", e)
	get_tree().quit(0 if errors.is_empty() else 1)


func _look(a: Color, b: Color, c: Color) -> String:
	return a.to_html() + b.to_html() + c.to_html()
