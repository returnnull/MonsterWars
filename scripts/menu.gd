extends Control
## Front end: title menu (play / settings / quit) -> hero select (1-4 players) -> world map (10 countries)
## -> level select (10 levels each). Any controller can navigate; in hero
## select every controller drives its own slot.

enum Screen { TITLE, SETTINGS, HEROES, MAP, LEVELS, SKILLS }

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
# Skill tree screen: who opened it, for which hero, and the selected node.
var _sk_slot := 0
var _sk_hero := 0
var _sk_sel := 0
var _sk_cards: Array[Panel] = []
var _sk_return: Array = []
# Title and settings: vertical menu items and the 3D backdrop.
var _items: Array[Dictionary] = []
var _item_actions: Array = []
var _sel := 0
var _stage: SubViewportContainer
var _stage_vp: SubViewport
var _stage_pivot: Node3D
var _stage_cam: Camera3D
var _stage_fire: OmniLight3D
var _stage_model: KaijuModel
var _stage_hero_idx := 0
var _roar_t := 0.0
var _was_roaring := false


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
	_build_stage()
	var start: String = Game.get_meta("menu_screen", "title")
	_country = mini(Game.unlocked / Content.LEVELS_PER_COUNTRY, Content.COUNTRIES.size() - 1)
	match start:
		"map":
			_show_map()
		_:
			_show_title()


func _process(delta: float) -> void:
	_t += delta
	_animate_stage(delta)
	match screen:
		Screen.TITLE:
			_title_input()
		Screen.SETTINGS:
			_settings_input()
		Screen.HEROES:
			_heroes_input()
		Screen.MAP:
			_map_input()
		Screen.LEVELS:
			_levels_input()
		Screen.SKILLS:
			_skills_input()


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
	_sk_cards.clear()
	_items.clear()
	_set_stage_visible(false)
	_root.modulate.a = 0.0
	_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)


func _any_just(action: String) -> bool:
	for s in Game.MAX_PLAYERS:
		if Input.is_action_just_pressed("p%d_%s" % [s, action]):
			return true
	return false


# --- title -----------------------------------------------------------------

## Builds the 3D backdrop behind the title and options screens: a kaiju
## towering over a burning skyline at dusk. It lives outside _root so it
## survives screen changes and is only rendered while visible.
func _build_stage() -> void:
	_stage = SubViewportContainer.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.stretch = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	move_child(_stage, _root.get_index())
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	_stage.add_child(vp)
	_stage_vp = vp

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.06, 0.05, 0.16)
	sky_mat.sky_horizon_color = Color(0.85, 0.35, 0.18)
	sky_mat.ground_horizon_color = Color(0.35, 0.12, 0.08)
	sky_mat.ground_bottom_color = Color(0.03, 0.02, 0.04)
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.4, 0.55)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.2, 0.14)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-30, -40, 0)
	moon.light_color = Color(0.6, 0.65, 1.0)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	vp.add_child(moon)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 160, 0)
	rim.light_color = Color(1.0, 0.5, 0.25)
	rim.light_energy = 2.2
	vp.add_child(rim)
	_stage_fire = OmniLight3D.new()
	_stage_fire.position = Vector3(3, 2.5, 6)
	_stage_fire.light_color = Color(1.0, 0.45, 0.15)
	_stage_fire.omni_range = 22.0
	_stage_fire.light_energy = 3.0
	vp.add_child(_stage_fire)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.06, 0.05, 0.07)
	gmat.roughness = 0.9
	ground.material_override = gmat
	vp.add_child(ground)

	# Skyline: rows of towers with lit windows, getting darker with depth.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.05, 0.05, 0.07)
	tower_mat.roughness = 0.8
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(1.0, 0.8, 0.45)
	win_mat.emission_enabled = true
	win_mat.emission = Color(1.0, 0.75, 0.4)
	win_mat.emission_energy_multiplier = 2.5
	for row in 3:
		var z := -24.0 - row * 14.0
		var x := -60.0
		while x < 60.0:
			var w := rng.randf_range(3.0, 6.5)
			var h := rng.randf_range(8.0, 26.0) * (1.0 + row * 0.4)
			var tower := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(w, h, rng.randf_range(3.0, 6.0))
			tower.mesh = box
			tower.material_override = tower_mat
			tower.position = Vector3(x + w * 0.5, h * 0.5, z + rng.randf_range(-2.0, 2.0))
			vp.add_child(tower)
			for i in int(h / 2.2):
				if rng.randf() < 0.45:
					var win := MeshInstance3D.new()
					var wb := BoxMesh.new()
					wb.size = Vector3(w * rng.randf_range(0.2, 0.7), 0.5, 0.05)
					win.mesh = wb
					win.material_override = win_mat
					win.position = Vector3(rng.randf_range(-0.15, 0.15) * w, -h * 0.5 + 1.4 + i * 2.2, box.size.z * 0.5 + 0.03)
					tower.add_child(win)
			x += w + rng.randf_range(0.5, 2.5)

	# Embers drifting up from the burning city.
	var embers := GPUParticles3D.new()
	embers.amount = 160
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.position = Vector3(0, 0, -4)
	embers.visibility_aabb = AABB(Vector3(-40, -2, -20), Vector3(80, 40, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 0.5, 12)
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0.3, 0.4, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	embers.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	emat.albedo_color = Color(1.0, 0.6, 0.25)
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.5, 0.2)
	emat.emission_energy_multiplier = 4.0
	quad.material = emat
	embers.draw_pass_1 = quad
	vp.add_child(embers)

	_stage_pivot = Node3D.new()
	_stage_pivot.position = Vector3(5.0, 0, 0)
	vp.add_child(_stage_pivot)
	_stage_cam = Camera3D.new()
	_stage_cam.fov = 50.0
	_stage_cam.position = Vector3(0, 2.2, 17.0)
	_stage_cam.rotation_degrees = Vector3(7, 0, 0)
	vp.add_child(_stage_cam)

	# Darken the left side so the menu reads over the scene.
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.02, 0.05, 0.85), Color(0.02, 0.02, 0.05, 0.0)])
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(0.6, 0.5)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(shade)
	_stage_hero(int(Game.party.get(0, 0)))


func _stage_hero(hero: int) -> void:
	_stage_hero_idx = hero
	for c in _stage_pivot.get_children():
		c.queue_free()
	var h := Content.hero(hero)
	_stage_model = KaijuModel.new()
	_stage_model.look = h.get("look", {})
	_stage_pivot.add_child(_stage_model)
	_stage_model.build(h["skin"], h["belly"], h["accent"], h["eye"], h["horns"])
	_stage_model.scale = Vector3.ONE * float(h["size"]) * 1.25
	_stage_model.glow = 0.4


func _set_stage_visible(on: bool) -> void:
	_stage.visible = on
	_stage_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## Idle sway, a roar every few seconds, and a new kaiju after each roar.
func _animate_stage(delta: float) -> void:
	if not _stage.visible or _stage_model == null:
		return
	_roar_t += delta
	var cycle := fmod(_roar_t, 7.0)
	var roaring := cycle > 4.5 and cycle < 6.2
	_stage_model.jaw = 1.0 if roaring else 0.1
	_stage_model.arm_r = 1.4 if roaring else 0.25
	_stage_model.arm_l = 1.4 if roaring else 0.25
	_stage_model.lean = -0.2 if roaring else 0.0
	_stage_model.eye_glow = 1.0 if roaring else 0.2
	_stage_model.glow = lerpf(_stage_model.glow, 1.0 if roaring else 0.4, 1.0 - exp(-4.0 * delta))
	_stage_pivot.rotation.y = -0.9 + sin(_t * 0.3) * 0.12
	_stage_fire.light_energy = 3.0 + sin(_t * 13.0) * 0.5 + sin(_t * 7.3) * 0.4
	var quake := 0.08 if roaring else 0.0
	_stage_cam.h_offset = randf_range(-quake, quake)
	_stage_cam.v_offset = randf_range(-quake, quake) + sin(_t * 0.4) * 0.15
	if roaring and not _was_roaring:
		for d in Input.get_connected_joypads():
			Game.rumble(d, 0.3, 0.5, 0.6)
	if _was_roaring and not roaring:
		_stage_hero(posmod(_stage_hero_idx + 1, Content.HEROES.size()))
	_was_roaring = roaring


func _show_title() -> void:
	_clear()
	screen = Screen.TITLE
	_set_stage_visible(true)
	var t := _label(_root, "KAIJU DAWN", Vector2(110, 150), 150, Color(1.0, 0.88, 0.7))
	t.label_settings.outline_size = 24
	t.label_settings.shadow_size = 18
	t.label_settings.shadow_color = Color(1.0, 0.35, 0.1, 0.45)
	_label(_root, "10 kaiju  -  10 countries  -  100 levels  -  up to 4 players", Vector2(120, 340), 30, Color(0.8, 0.85, 1.0))
	_items.clear()
	_item_actions = ["play", "settings"]
	if Game.can_quit():
		_item_actions.append("quit")
	var names := {"play": "PLAY", "settings": "SETTINGS", "quit": "QUIT"}
	for i in _item_actions.size():
		_items.append(_menu_item(names[_item_actions[i]], Vector2(110, 520 + i * 110)))
	_sel = 0
	_highlight_items()
	_label(_root, "Up/Down: choose    B / Space: select", Vector2(120, 1010), 24, Color(1, 1, 1, 0.7))


func _title_input() -> void:
	if _move_items():
		return
	if _any_just("jump") or Input.is_action_just_pressed("pause"):
		match _item_actions[_sel]:
			"play":
				_show_heroes()
			"settings":
				_show_settings()
			"quit":
				get_tree().quit()


# --- settings --------------------------------------------------------------

func _show_settings() -> void:
	_clear()
	screen = Screen.SETTINGS
	_set_stage_visible(true)
	_label(_root, "SETTINGS", Vector2(110, 150), 110, Color(1.0, 0.88, 0.7))
	_items.clear()
	_item_actions = Game.setting_keys() + ["back"]
	for i in _item_actions.size():
		_items.append(_menu_item("", Vector2(110, 360 + i * 110), 760))
	_sel = 0
	_refresh_settings()
	_label(_root, "Up/Down: choose    Left/Right: change    A / Shift: back", Vector2(120, 1010), 24, Color(1, 1, 1, 0.7))


func _refresh_settings() -> void:
	for i in _item_actions.size():
		var key: String = _item_actions[i]
		_items[i]["label"].text = Game.SETTING_NAMES.get(key, "BACK")
		_items[i]["value"].text = Game.setting_text(key) if key != "back" else ""
	_highlight_items()


func _settings_input() -> void:
	if _move_items():
		return
	var key: String = _item_actions[_sel]
	var step := 0
	if _any_just("move_left"):
		step = -1
	elif _any_just("move_right"):
		step = 1
	elif _any_just("jump") or Input.is_action_just_pressed("pause"):
		if key == "back":
			_show_title()
			return
		step = 1
	elif _any_just("dodge"):
		_show_title()
		return
	if step == 0 or key == "back":
		return
	Game.step_setting(key, step)
	_refresh_settings()


# --- vertical menu widgets -------------------------------------------------

func _menu_item(text: String, pos: Vector2, width: float = 520.0) -> Dictionary:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(width, 88)
	panel.pivot_offset = Vector2(0, 44)
	_root.add_child(panel)
	var l := _label(panel, text, Vector2(40, 12), 52, Color.WHITE)
	var v := _label(panel, "", Vector2(width - 300, 18), 40, Color(1.0, 0.8, 0.4))
	v.size.x = 270
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"panel": panel, "label": l, "value": v}


func _highlight_items() -> void:
	for i in _items.size():
		var sel := i == _sel
		var it: Dictionary = _items[i]
		it["panel"].add_theme_stylebox_override("panel", _card_style(
			Color(0.9, 0.42, 0.15, 0.85) if sel else Color(0.05, 0.05, 0.1, 0.55),
			Color(1.0, 0.85, 0.5) if sel else Color(1, 1, 1, 0.1)))
		it["label"].label_settings.font_color = Color.WHITE if sel else Color(1, 1, 1, 0.7)
		it["value"].label_settings.font_color = Color(1.0, 0.95, 0.75) if sel else Color(1.0, 0.8, 0.4, 0.7)
		var tw: Tween = it["panel"].create_tween()
		tw.tween_property(it["panel"], "scale", Vector2.ONE * (1.05 if sel else 1.0), 0.12)


## Up/down moves the selection; returns true if it moved.
func _move_items() -> bool:
	var step := 0
	if _any_just("move_up"):
		step = -1
	elif _any_just("move_down"):
		step = 1
	if step == 0:
		return false
	_sel = posmod(_sel + step, _items.size())
	_highlight_items()
	return true


# --- hero select -----------------------------------------------------------

func _show_heroes(restore: Array = []) -> void:
	_clear()
	screen = Screen.HEROES
	_center(_label(_root, "CHOOSE YOUR KAIJU", Vector2(0, 30), 64, Color(1.0, 0.9, 0.75)))
	_center(_label(_root, "Left/Right: choose    B / Space: join, then ready    X / K: skill tree    A / Shift: back    All ready: world map",
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
		cam.position = Vector3(0, 4.6, 16.5)
		cam.rotation.x = -0.1
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
		d["special"] = _label(box, "", Vector2(30, 700), 22, Color(1.0, 0.8, 0.4))
		d["lvl"] = _label(box, "", Vector2(30, 758), 24, Color(1.0, 0.95, 0.6))
		d["status"] = _label(box, "", Vector2(0, 800), 32, Color.WHITE)
		d["status"].size.x = SLOT_W - 20
		d["status"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slots.append(d)
		_set_hero(slot, d["hero"])
		_refresh_slot(slot)
	# Whoever pressed start on the title screen is already in.
	_slots[0]["joined"] = true
	for slot in mini(restore.size(), _slots.size()):
		_slots[slot]["joined"] = restore[slot]["joined"]
		_slots[slot]["ready"] = restore[slot]["ready"]
		_set_hero(slot, restore[slot]["hero"])
	for slot in _slots.size():
		_refresh_slot(slot)


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
			if Input.is_action_just_pressed(pre + "heavy"):
				_show_skills(slot, d["hero"])
				return
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
	m.look = h.get("look", {})
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
	d["special"].text = "Rage attack: %s\nSuper: %s" % [Content.SPECIAL_NAMES[h["special"]],
		String(Skills.super_def(hero)["name"]).capitalize()]
	var pts := Game.free_points(hero)
	d["lvl"].text = "LV %d%s" % [Game.hero_level(hero), ("   -   %d skill points  [X]" % pts) if pts > 0 else ""]


func _refresh_slot(slot: int) -> void:
	var d := _slots[slot]
	var on: bool = d["joined"]
	for key in ["name", "title", "special", "lvl"]:
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
	_backdrop()
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
		_skyline(sky, i, Color(c["sky_top"]).darkened(0.75))
		_label(card, "%d" % (i + 1), Vector2(20, 14), 40, Color(1, 1, 1, 0.9))
		_label(card, c["name"], Vector2(20, 170), 38, Color.WHITE)
		_label(card, c["city"], Vector2(20, 218), 26, Color(1, 1, 1, 0.75))
		var boss: Dictionary = c["boss"]
		_label(card, "BOSS: " + boss["name"], Vector2(20, 270), 22, Color(boss["accent"]).lerp(Color.WHITE, 0.3))
		var done := clampi(Game.unlocked - i * Content.LEVELS_PER_COUNTRY, 0, Content.LEVELS_PER_COUNTRY)
		var locked := i * Content.LEVELS_PER_COUNTRY > Game.unlocked
		_label(card, "LOCKED" if locked else "%d / 10 cleared" % done, Vector2(20, 312), 26,
			Color(1, 0.4, 0.4) if locked else Color(0.6, 1.0, 0.7))
		if not locked:
			_progress(card, Vector2(20, 352), 280.0, float(done) / Content.LEVELS_PER_COUNTRY)
		if locked:
			card.modulate = Color(0.55, 0.55, 0.6)
			_lock_badge(card)
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
	_backdrop()
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
		if boss:
			card.set_meta("tint", Color(0.3, 0.06, 0.06, 0.92))
		if g < Game.unlocked:
			_label(card, "CLEARED", Vector2(24, 212), 22, Color(0.6, 1.0, 0.7))
		if locked:
			card.modulate = Color(0.55, 0.55, 0.6)
			_lock_badge(card)
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


# --- skill tree ------------------------------------------------------------

const SK_COL_X := [150.0, 720.0, 1290.0]
const SK_ROW_Y := [330.0, 520.0, 710.0]


func _show_skills(slot: int, hero: int) -> void:
	_sk_return = _slots.map(func(d: Dictionary) -> Dictionary:
		return {"joined": d["joined"], "ready": d["ready"], "hero": d["hero"]})
	_sk_slot = slot
	_sk_hero = hero
	_sk_sel = 0
	_build_skills()


func _build_skills() -> void:
	_clear()
	screen = Screen.SKILLS
	var h := Content.hero(_sk_hero)
	var accent: Color = Color(h["accent"]).lerp(Color.WHITE, 0.3)
	var xp: int = Game.hero_xp[_sk_hero]
	var ranks: Array = Game.hero_skills[_sk_hero]
	var lvl := Game.hero_level(_sk_hero)
	_label(_root, "%s  SKILL TREE" % h["name"], Vector2(60, 30), 56, accent)
	_label(_root, "P%d" % (_sk_slot + 1), Vector2(60, 100), 26, Color(1, 1, 1, 0.6))
	var prog := Skills.xp_progress(xp)
	var info := "LV %d / %d" % [lvl, Skills.MAX_LEVEL]
	if lvl < Skills.MAX_LEVEL:
		info += "    XP %d / %d" % [prog.x, prog.y]
	var lv_label := _label(_root, info, Vector2(1060, 36), 32, Color(1.0, 0.95, 0.6))
	lv_label.size.x = 800
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pts := _label(_root, "SKILL POINTS: %d   (used %d of %d)" % [Game.free_points(_sk_hero), Skills.points_spent(ranks),
		Skills.points_total(xp)], Vector2(1060, 80), 30, Color(0.6, 1.0, 0.7))
	pts.size.x = 800
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i in Skills.NODE_COUNT:
		var n := Skills.node(_sk_hero, i)
		var card := Panel.new()
		if i == 0:
			card.position = Vector2(720, 122)
		else:
			card.position = Vector2(SK_COL_X[n[2]], SK_ROW_Y[n[3] - 1])
		card.size = Vector2(450, 160)
		_root.add_child(card)
		var r := int(ranks[i])
		var mx := Skills.max_rank(i)
		var block := Skills.buy_block(xp, ranks, i)
		var title_col := accent if r > 0 else Color(1, 1, 1, 0.9)
		_label(card, n[0], Vector2(18, 10), 30, title_col)
		var tier_name := "ROOT" if i == 0 else ("BRANCH END" if n[3] == 3 else "TIER %d" % n[3])
		_label(card, tier_name, Vector2(18, 50), 18, Color(1, 1, 1, 0.5))
		var rank_label := _label(card, "%d / %d" % [r, mx], Vector2(300, 14), 26, Color(0.6, 1.0, 0.7) if r == mx else Color.WHITE)
		rank_label.size.x = 130
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var desc := _label(card, "", Vector2(18, 76), 20, Color(1, 1, 1, 0.85))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(414, 0)
		desc.size = Vector2(414, 50)
		desc.text = Skills.describe(_sk_hero, i, r)
		var cost_text := "MAXED" if r == mx else "COST %d" % Skills.cost(i)
		var cost_label := _label(card, cost_text, Vector2(300, 50), 18, Color(1.0, 0.8, 0.4) if block == "" else Color(1, 1, 1, 0.4))
		cost_label.size.x = 130
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if r == 0 and block != "" and block != "NOT ENOUGH POINTS":
			card.modulate = Color(0.6, 0.6, 0.65)
		_sk_cards.append(card)
	for b in 3:
		var bl := _label(_root, Skills.branch_name(_sk_hero, b), Vector2(SK_COL_X[b], 292), 28, accent)
		bl.size.x = 450
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var super_def := Skills.super_def(_sk_hero)
	_label(_root, "Rage attack: %s     Super special: %s" % [Content.SPECIAL_NAMES[h["special"]], super_def["name"]],
		Vector2(150, 890), 26, Color(1.0, 0.8, 0.4))
	var sel_block := Skills.buy_block(xp, ranks, _sk_sel)
	var hint := _label(_root, "" if sel_block == "" else sel_block, Vector2(150, 935), 26, Color(1.0, 0.5, 0.4))
	hint.size.x = 1620
	_center(_label(_root, "Move: choose    B / Space: learn    Y / J: reset all points    A / Shift: back",
		Vector2(0, 1010), 24, Color(1, 1, 1, 0.75)))
	_highlight(_sk_cards, _sk_sel)


func _skills_input() -> void:
	var pre := "p%d_" % _sk_slot
	var n := Skills.node(_sk_hero, _sk_sel)
	var b: int = n[2]
	var tier: int = n[3]
	var nxt := _sk_sel
	if Input.is_action_just_pressed(pre + "move_down"):
		nxt = 4 if _sk_sel == 0 else (_sk_sel + 1 if tier < 3 else _sk_sel)
	elif Input.is_action_just_pressed(pre + "move_up"):
		nxt = 0 if tier == 1 else (_sk_sel - 1 if tier > 1 else _sk_sel)
	elif Input.is_action_just_pressed(pre + "move_left") and b > 0:
		nxt = 1 + (b - 1) * 3 + tier - 1
	elif Input.is_action_just_pressed(pre + "move_right") and b >= 0 and b < 2:
		nxt = 1 + (b + 1) * 3 + tier - 1
	if nxt != _sk_sel:
		_sk_sel = nxt
		_build_skills()
	if Input.is_action_just_pressed(pre + "jump"):
		if Game.buy_skill(_sk_hero, _sk_sel):
			_build_skills()
			var card := _sk_cards[_sk_sel]
			card.scale = Vector2.ONE * 1.15
			card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.06, 0.2)
	elif Input.is_action_just_pressed(pre + "light"):
		Game.reset_skills(_sk_hero)
		_build_skills()
	elif Input.is_action_just_pressed(pre + "dodge"):
		_show_heroes(_sk_return)


# --- widgets ---------------------------------------------------------------

func _highlight(cards: Array[Panel], idx: int) -> void:
	for i in cards.size():
		var sel := i == idx
		var bg: Color = cards[i].get_meta("tint", Color(0.09, 0.09, 0.14, 0.9))
		var st := _card_style(bg.lightened(0.08) if sel else bg,
			Color(1.0, 0.75, 0.3) if sel else Color(1, 1, 1, 0.12))
		if sel:
			st.shadow_color = Color(1.0, 0.55, 0.15, 0.55)
			st.shadow_size = 22
		cards[i].add_theme_stylebox_override("panel", st)
		cards[i].pivot_offset = cards[i].size * 0.5
		cards[i].z_index = 1 if sel else 0
		var tw := cards[i].create_tween()
		tw.tween_property(cards[i], "scale", Vector2.ONE * (1.06 if sel else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The title scene, dimmed, behind the map and level select.
func _backdrop() -> void:
	_set_stage_visible(true)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)


## A row of city towers with a few lit windows along the bottom of a sky strip.
func _skyline(sky: Control, seed_value: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	var x := 0.0
	while x < sky.size.x:
		var w := rng.randf_range(14.0, 34.0)
		var h := rng.randf_range(24.0, 80.0)
		var tower := ColorRect.new()
		tower.color = color
		tower.position = Vector2(x, sky.size.y - h)
		tower.size = Vector2(minf(w, sky.size.x - x), h)
		tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky.add_child(tower)
		for j in int(h / 12.0):
			if rng.randf() < 0.3 and w > 16.0:
				var win := ColorRect.new()
				win.color = Color(1.0, 0.85, 0.5, 0.8)
				win.position = Vector2(rng.randf_range(3.0, w - 9.0), 6.0 + j * 12.0)
				win.size = Vector2(5, 4)
				tower.add_child(win)
		x += w + rng.randf_range(0.0, 6.0)


func _progress(parent: Control, pos: Vector2, width: float, frac: float) -> void:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(width, 10)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = frac
	bar.add_theme_stylebox_override("background", _card_style(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0)))
	bar.add_theme_stylebox_override("fill", _card_style(Color(0.45, 0.95, 0.6), Color(0, 0, 0, 0)))
	parent.add_child(bar)


## A padlock drawn from two boxes in the card's top-right corner.
func _lock_badge(card: Control) -> void:
	var lock := Control.new()
	lock.position = Vector2(card.size.x - 70, 18)
	card.add_child(lock)
	var shackle := Panel.new()
	shackle.position = Vector2(10, 0)
	shackle.size = Vector2(30, 34)
	var ss := StyleBoxFlat.new()
	ss.draw_center = false
	ss.border_color = Color(0.9, 0.9, 0.95)
	ss.set_border_width_all(6)
	ss.set_corner_radius_all(14)
	shackle.add_theme_stylebox_override("panel", ss)
	lock.add_child(shackle)
	var body := Panel.new()
	body.position = Vector2(0, 20)
	body.size = Vector2(50, 36)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.9, 0.9, 0.95)
	bs.set_corner_radius_all(6)
	body.add_theme_stylebox_override("panel", bs)
	lock.add_child(body)


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
