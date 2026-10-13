extends Control
## Front end: title -> hero select (1-4 players) -> world map (10 countries)
## -> level select (10 levels each). Any controller can navigate; in hero
## select every controller drives its own slot.

enum Screen { TITLE, HEROES, MAP, LEVELS }

const SLOT_W := 460.0

var screen := Screen.TITLE
var _root: Control
var _t := 0.0
var _country := 0
var _level := 0

# Hero select state per slot: {joined, ready, hero, widgets...}
var _slots: Array[Dictionary] = []
var _map_cards: Array[Panel] = []
var _level_cards: Array[Panel] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.1)
	add_child(bg)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.9, 0.4, 0.2, 0.55), Color(0.2, 0.1, 0.4, 0.0)])
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 1.1)
	gt.fill_to = Vector2(0.5, 0.0)
	glow.texture = gt
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(glow)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var start: String = Game.get_meta("menu_screen", "title")
	_country = mini(Game.unlocked / Content.LEVELS_PER_COUNTRY, Content.COUNTRIES.size() - 1)
	match start:
		"map":
			_show_map()
		_:
			_show_title()


func _process(delta: float) -> void:
	_t += delta
	match screen:
		Screen.TITLE:
			if _any_just("jump") or Input.is_action_just_pressed("pause"):
				_show_heroes()
		Screen.HEROES:
			_heroes_input()
		Screen.MAP:
			_map_input()
		Screen.LEVELS:
			_levels_input()


func _unhandled_input(event: InputEvent) -> void:
	# Debug/testing: F9 unlocks every level.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		Game.unlocked = Content.COUNTRIES.size() * Content.LEVELS_PER_COUNTRY - 1
		Game.save_progress()
		if screen == Screen.MAP:
			_show_map()
		elif screen == Screen.LEVELS:
			_show_levels()


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_slots.clear()
	_map_cards.clear()
	_level_cards.clear()


func _any_just(action: String) -> bool:
	for s in Game.MAX_PLAYERS:
		if Input.is_action_just_pressed("p%d_%s" % [s, action]):
			return true
	return false


# --- title -----------------------------------------------------------------

func _show_title() -> void:
	_clear()
	screen = Screen.TITLE
	var t := _label(_root, "KAIJU DAWN", Vector2(0, 300), 170, Color(1.0, 0.9, 0.75))
	_center(t)
	var s := _label(_root, "10 kaiju  -  10 countries  -  100 levels  -  up to 4 players", Vector2(0, 520), 36, Color(0.8, 0.85, 1.0))
	_center(s)
	var p := _label(_root, "Press B / Space", Vector2(0, 760), 44, Color.WHITE)
	_center(p)
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "modulate:a", 0.25, 0.6)
	tw.tween_property(p, "modulate:a", 1.0, 0.6)


# --- hero select -----------------------------------------------------------

func _show_heroes() -> void:
	_clear()
	screen = Screen.HEROES
	_center(_label(_root, "CHOOSE YOUR KAIJU", Vector2(0, 30), 64, Color(1.0, 0.9, 0.75)))
	_center(_label(_root, "Left/Right: choose    B / Space: join, then ready    A / Shift: back    All ready: world map",
		Vector2(0, 1010), 24, Color(1, 1, 1, 0.75)))
	for slot in Game.MAX_PLAYERS:
		var x := (1920.0 - SLOT_W * 4) * 0.5 + slot * SLOT_W
		var d := {"joined": false, "ready": false, "hero": Game.party.get(slot, slot)}
		var box := Panel.new()
		box.position = Vector2(x + 10, 130)
		box.size = Vector2(SLOT_W - 20, 860)
		box.add_theme_stylebox_override("panel", _card_style(Color(0.1, 0.1, 0.16, 0.85), Color(1, 1, 1, 0.15)))
		_root.add_child(box)
		d["box"] = box
		d["tag"] = _label(box, "P%d" % (slot + 1), Vector2(16, 8), 30, Color(1, 1, 1, 0.6))
		var vpc := SubViewportContainer.new()
		vpc.position = Vector2(10, 50)
		vpc.size = Vector2(SLOT_W - 40, 400)
		vpc.stretch = true
		box.add_child(vpc)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_2X
		vpc.add_child(vp)
		var pivot := Node3D.new()
		vp.add_child(pivot)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 4.0, 13.0)
		cam.rotation.x = -0.12
		cam.fov = 40.0
		vp.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 30, 0)
		sun.light_energy = 1.4
		vp.add_child(sun)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-10, 200, 0)
		rim.light_color = Color(1.0, 0.6, 0.4)
		rim.light_energy = 1.2
		vp.add_child(rim)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
		env.environment.glow_enabled = true
		vp.add_child(env)
		d["pivot"] = pivot
		d["name"] = _label(box, "", Vector2(0, 460), 44, Color.WHITE)
		d["name"].size.x = SLOT_W - 20
		d["name"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d["title"] = _label(box, "", Vector2(0, 515), 26, Color(1, 1, 1, 0.7))
		d["title"].size.x = SLOT_W - 20
		d["title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d["bars"] = []
		d["stat_labels"] = []
		for i in 3:
			d["stat_labels"].append(_label(box, ["HEALTH", "SPEED", "POWER"][i], Vector2(30, 570 + i * 46), 24, Color(1, 1, 1, 0.8)))
			var bar := ProgressBar.new()
			bar.position = Vector2(170, 576 + i * 46)
			bar.size = Vector2(240, 20)
			bar.show_percentage = false
			bar.add_theme_stylebox_override("background", _card_style(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0)))
			bar.add_theme_stylebox_override("fill", _card_style(Color(1.0, 0.6, 0.2), Color(0, 0, 0, 0)))
			box.add_child(bar)
			d["bars"].append(bar)
		d["special"] = _label(box, "", Vector2(30, 710), 26, Color(1.0, 0.8, 0.4))
		d["status"] = _label(box, "", Vector2(0, 780), 32, Color.WHITE)
		d["status"].size.x = SLOT_W - 20
		d["status"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slots.append(d)
		_set_hero(slot, d["hero"])
		_refresh_slot(slot)
	# Whoever pressed start on the title screen is already in.
	_slots[0]["joined"] = true
	_refresh_slot(0)


func _heroes_input() -> void:
	for slot in _slots.size():
		var d := _slots[slot]
		var pre := "p%d_" % slot
		d["pivot"].rotation.y = _t * 0.6 + slot
		if not d["joined"]:
			if Input.is_action_just_pressed(pre + "jump"):
				d["joined"] = true
				_refresh_slot(slot)
			continue
		if not d["ready"]:
			var step := 0
			if Input.is_action_just_pressed(pre + "move_left"):
				step = -1
			elif Input.is_action_just_pressed(pre + "move_right"):
				step = 1
			if step != 0:
				_set_hero(slot, posmod(d["hero"] + step, Content.HEROES.size()))
			if Input.is_action_just_pressed(pre + "jump"):
				d["ready"] = true
				_refresh_slot(slot)
			elif Input.is_action_just_pressed(pre + "dodge"):
				if slot == 0:
					_show_title()
					return
				d["joined"] = false
				_refresh_slot(slot)
		elif Input.is_action_just_pressed(pre + "dodge"):
			d["ready"] = false
			_refresh_slot(slot)
	var joined := _slots.filter(func(d: Dictionary) -> bool: return d["joined"])
	if not joined.is_empty() and joined.all(func(d: Dictionary) -> bool: return d["ready"]):
		Game.party = {}
		for slot in _slots.size():
			if _slots[slot]["joined"]:
				Game.party[slot] = _slots[slot]["hero"]
		Game.save_progress()
		_show_map()


func _set_hero(slot: int, hero: int) -> void:
	var d := _slots[slot]
	d["hero"] = hero
	var h := Content.hero(hero)
	for c in d["pivot"].get_children():
		c.queue_free()
	var m := KaijuModel.new()
	d["pivot"].add_child(m)
	m.build(h["skin"], h["belly"], h["accent"], h["eye"], h["horns"])
	m.glow = 1.0
	m.position = Vector3(1.0, 0, 0)
	m.scale = Vector3.ONE * float(h["size"])
	d["name"].text = h["name"]
	d["name"].label_settings.font_color = Color(h["accent"]).lerp(Color.WHITE, 0.35)
	d["title"].text = h["title"]
	d["bars"][0].value = 100.0 * float(h["hp"]) / 360.0
	d["bars"][1].value = 100.0 * float(h["speed"]) / 1.3
	d["bars"][2].value = 100.0 * float(h["power"]) / 1.3
	d["special"].text = "Rage: " + Content.SPECIAL_NAMES[h["special"]]


func _refresh_slot(slot: int) -> void:
	var d := _slots[slot]
	var on: bool = d["joined"]
	for key in ["name", "title", "special"]:
		d[key].visible = on
	for b in d["bars"] + d["stat_labels"]:
		b.visible = on
	d["pivot"].visible = on
	if not on:
		d["status"].text = "PRESS B TO JOIN"
	elif d["ready"]:
		d["status"].text = "READY!"
	else:
		d["status"].text = "<  CHOOSE  >"
	var border := Color(0.4, 1.0, 0.6) if d["ready"] else (Color(1, 1, 1, 0.5) if on else Color(1, 1, 1, 0.15))
	d["box"].add_theme_stylebox_override("panel", _card_style(Color(0.1, 0.1, 0.16, 0.85), border))


# --- world map -------------------------------------------------------------

func _show_map() -> void:
	_clear()
	screen = Screen.MAP
	_center(_label(_root, "WORLD MAP", Vector2(0, 30), 64, Color(1.0, 0.9, 0.75)))
	_center(_label(_root, "Move: choose country    B / Space: select    A / Shift: back to kaiju select",
		Vector2(0, 1010), 24, Color(1, 1, 1, 0.75)))
	for i in Content.COUNTRIES.size():
		var c := Content.country(i)
		var col := i % 5
		var row := i / 5
		var card := Panel.new()
		card.position = Vector2(110 + col * 345, 170 + row * 410)
		card.size = Vector2(320, 380)
		_root.add_child(card)
		var sky := TextureRect.new()
		var gt := GradientTexture2D.new()
		var g := Gradient.new()
		g.colors = PackedColorArray([c["sky_top"], c["sky_horizon"]])
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		sky.texture = gt
		sky.position = Vector2(8, 8)
		sky.size = Vector2(304, 150)
		sky.stretch_mode = TextureRect.STRETCH_SCALE
		card.add_child(sky)
		_label(card, "%d" % (i + 1), Vector2(20, 14), 40, Color(1, 1, 1, 0.9))
		_label(card, c["name"], Vector2(20, 170), 38, Color.WHITE)
		_label(card, c["city"], Vector2(20, 218), 26, Color(1, 1, 1, 0.75))
		var boss: Dictionary = c["boss"]
		_label(card, "BOSS: " + boss["name"], Vector2(20, 270), 22, Color(boss["accent"]).lerp(Color.WHITE, 0.3))
		var done := clampi(Game.unlocked - i * Content.LEVELS_PER_COUNTRY, 0, Content.LEVELS_PER_COUNTRY)
		var locked := i * Content.LEVELS_PER_COUNTRY > Game.unlocked
		_label(card, "LOCKED" if locked else "%d / 10 cleared" % done, Vector2(20, 320), 26,
			Color(1, 0.4, 0.4) if locked else Color(0.6, 1.0, 0.7))
		if locked:
			card.modulate = Color(0.55, 0.55, 0.6)
		_map_cards.append(card)
	_highlight(_map_cards, _country)


func _map_input() -> void:
	var prev := _country
	if _any_just("move_left"):
		_country -= 1
	elif _any_just("move_right"):
		_country += 1
	elif _any_just("move_up"):
		_country -= 5
	elif _any_just("move_down"):
		_country += 5
	_country = clampi(_country, 0, Content.COUNTRIES.size() - 1)
	if _country != prev:
		_highlight(_map_cards, _country)
	if _any_just("jump") and _country * Content.LEVELS_PER_COUNTRY <= Game.unlocked:
		_level = clampi(Game.unlocked - _country * Content.LEVELS_PER_COUNTRY, 0, Content.LEVELS_PER_COUNTRY - 1)
		_show_levels()
	elif _any_just("dodge"):
		_show_heroes()


# --- level select ----------------------------------------------------------

func _show_levels() -> void:
	_clear()
	screen = Screen.LEVELS
	var c := Content.country(_country)
	_center(_label(_root, "%s  -  %s" % [c["name"], c["city"]], Vector2(0, 40), 64, Color(1.0, 0.9, 0.75)))
	_center(_label(_root, "Move: choose level    B / Space: play    A / Shift: back to map",
		Vector2(0, 1010), 24, Color(1, 1, 1, 0.75)))
	for i in Content.LEVELS_PER_COUNTRY:
		var g := _country * Content.LEVELS_PER_COUNTRY + i
		var card := Panel.new()
		card.position = Vector2(150 + (i % 5) * 330, 220 + (i / 5) * 360)
		card.size = Vector2(300, 320)
		_root.add_child(card)
		var boss := i == Content.LEVELS_PER_COUNTRY - 1
		_label(card, "%d-%d" % [_country + 1, i + 1], Vector2(24, 20), 60, Color.WHITE)
		var lvl := Content.level(_country, i)
		var kinds := {}
		for w in lvl["waves"]:
			for k in w["spawn"]:
				kinds[k] = true
		var info := "%d waves" % lvl["waves"].size()
		if boss:
			info = "BOSS\n" + c["boss"]["name"]
		elif kinds.has("elite"):
			info += "\nElite"
		_label(card, info, Vector2(24, 110), 28, Color(1.0, 0.5, 0.4) if boss else Color(1, 1, 1, 0.8))
		var best := int(Game.best_scores.get(str(g), 0))
		var locked := g > Game.unlocked
		_label(card, "LOCKED" if locked else ("Best %d" % best if best > 0 else "New"), Vector2(24, 250), 26,
			Color(1, 0.4, 0.4) if locked else Color(0.6, 1.0, 0.7))
		if locked:
			card.modulate = Color(0.55, 0.55, 0.6)
		_level_cards.append(card)
	_highlight(_level_cards, _level)


func _levels_input() -> void:
	var prev := _level
	if _any_just("move_left"):
		_level -= 1
	elif _any_just("move_right"):
		_level += 1
	elif _any_just("move_up"):
		_level -= 5
	elif _any_just("move_down"):
		_level += 5
	_level = clampi(_level, 0, Content.LEVELS_PER_COUNTRY - 1)
	if _level != prev:
		_highlight(_level_cards, _level)
	if _any_just("jump") and _country * Content.LEVELS_PER_COUNTRY + _level <= Game.unlocked:
		Game.start_level(_country, _level)
	elif _any_just("dodge"):
		_show_map()


# --- widgets ---------------------------------------------------------------

func _highlight(cards: Array[Panel], idx: int) -> void:
	for i in cards.size():
		var sel := i == idx
		cards[i].add_theme_stylebox_override("panel", _card_style(
			Color(0.14, 0.14, 0.22, 0.95) if sel else Color(0.09, 0.09, 0.14, 0.9),
			Color(1.0, 0.75, 0.3) if sel else Color(1, 1, 1, 0.12)))
		cards[i].pivot_offset = cards[i].size * 0.5
		cards[i].scale = Vector2.ONE * (1.06 if sel else 1.0)


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	return s


func _label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = maxi(4, font_size / 8)
	ls.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _center(l: Label) -> void:
	l.size.x = 1920.0
	l.position.x = 0.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
