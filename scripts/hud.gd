class_name Hud
extends CanvasLayer
## In-game HUD: one health/rage panel per player slot (with a join prompt for
## empty slots), score, destruction, combo counter, boss bar, banner messages,
## pause menu and end screen. Laid out for a 1920x1080 canvas.

const PANEL_W := 400.0

var _panels: Array[Dictionary] = []
var _score_label: Label
var _destroy_label: Label
var _combo_label: Label
var _msg_label: Label
var _sub_label: Label
var _go_label: Label
var _boss_box: Control
var _boss_bar: ProgressBar
var _controls: Label
var _pause_panel: Control
var _pause_list: Control
var _pause_items: Array[Dictionary] = []
var _pause_actions: Array = []
var _pause_sel := 0
var _pause_settings := false
var _end_panel: Control
var _end_title: Label
var _end_stats: Label
var _ended := false
var won := false
var _boss_name: Label
var _boss: Kaiju
var _msg_tween: Tween
var _t := 0.0


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	for slot in Game.MAX_PLAYERS:
		_panels.append(_make_panel(root, slot))

	_score_label = _label(root, "0", Vector2(1420, 150), 46, Color.WHITE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.size = Vector2(450, 60)
	_destroy_label = _label(root, "DESTRUCTION 0%", Vector2(1420, 210), 26, Color(1.0, 0.75, 0.45))
	_destroy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_destroy_label.size = Vector2(450, 36)
	_combo_label = _label(root, "", Vector2(1420, 260), 52, Color(1.0, 0.9, 0.3))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.size = Vector2(450, 70)

	_msg_label = _label(root, "", Vector2(0, 380), 110, Color(1.0, 0.95, 0.85))
	_msg_label.size = Vector2(1920, 160)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.pivot_offset = Vector2(960, 80)
	_msg_label.modulate.a = 0.0
	_sub_label = _label(_msg_label, "", Vector2(0, 150), 40, Color(1.0, 0.8, 0.55))
	_sub_label.size = Vector2(1920, 60)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Blinks at the right edge while the way on is open.
	_go_label = _label(root, "GO  >>", Vector2(1560, 470), 72, Color(1.0, 0.85, 0.3))
	_go_label.visible = false

	_boss_box = Control.new()
	_boss_box.position = Vector2(260, 950)
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = _label(_boss_box, "", Vector2(0, -44), 30, Color(1.0, 0.5, 0.35))
	_boss_bar = _bar(_boss_box, Vector2(0, 0), Vector2(1400, 36), Color(0.95, 0.25, 0.2))

	_controls = _label(root, "Players 2-4: press B on another controller to join\n" +
		"Move: WASD / stick    Jump: Space / B    Light: J / Y    Heavy: K / X\n" +
		"Dodge: Shift / A    Super: U key / ZL    Pause: Esc / +\n" +
		"Rage skills: hold L / R and press J / Y (strike), Space / B (roar) or K / X (rage attack). Tap L / R for rage mode\n" +
		"Knock down buildings, then press heavy (K / X) on the wreckage to pick up a weapon",
		Vector2(48, 895), 22, Color(1, 1, 1, 0.85))
	_controls.visible = bool(Game.settings["hints"])

	_pause_panel = _make_pause(root)
	_end_panel = _overlay(root, "", "")
	_end_title = _end_panel.get_child(1)
	_end_stats = _end_panel.get_child(2)
	_end_stats.position.y = 480
	_end_stats.size.y = 520
	_end_stats.label_settings.font_size = 30

	Game.score_changed.connect(func(s: int) -> void: _score_label.text = str(s))
	Game.destruction_changed.connect(func(_d: int, _t2: int) -> void:
		_destroy_label.text = "DESTRUCTION %d%%" % Game.destruction_percent())
	Game.combo_changed.connect(_on_combo)
	Input.joy_connection_changed.connect(func(device: int, connected: bool) -> void:
		show_message("CONTROLLER %d %s" % [device + 1, "CONNECTED" if connected else "DISCONNECTED"], 1.4)
		if not connected and not get_tree().paused and not _ended:
			_set_paused(true))


func bind(player: Player) -> void:
	var p: Dictionary = _panels[player.slot]
	p["root"].visible = true
	p["join"].visible = false
	p["player"] = player
	p["name"].text = player.display_name()
	p["level"].text = "LV %d" % player.level
	p["name"].label_settings.font_color = player.color().lerp(Color.WHITE, 0.4)
	var hp_bar: ProgressBar = p["hp"]
	var rage_bar: ProgressBar = p["rage"]
	player.health_changed.connect(func(hp: float, mx: float) -> void: hp_bar.value = 100.0 * hp / mx)
	player.rage_changed.connect(func(r: float, mx: float) -> void: rage_bar.value = 100.0 * r / mx)
	rage_bar.value = 100.0 * player.rage / player.rage_max
	# Tick marks where the bar pays for each rage skill.
	for c in rage_bar.get_children():
		c.queue_free()
	for skill in ["strike", "roar", "attack"]:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.7)
		tick.size = Vector2(2, rage_bar.size.y)
		tick.position = Vector2(rage_bar.size.x * minf(player.rage_cost(skill) / player.rage_max, 1.0), 0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rage_bar.add_child(tick)
	var super_bar: ProgressBar = p["super"]
	super_bar.value = 0.0
	player.super_changed.connect(func(v: float, mx: float) -> void: super_bar.value = 100.0 * v / mx)
	hp_bar.value = 100.0 * player.hp / player.max_hp
	p["trail"].value = hp_bar.value


## Red flash on a player's rage bar when they can't pay for a rage skill.
func flash_rage(slot: int) -> void:
	_panels[slot]["rage_flash"] = 0.3


func show_boss(boss: Kaiju) -> void:
	_boss = boss
	_boss_name.text = boss.display_name()
	_boss_box.visible = true
	_boss_bar.value = 100.0
	boss.health_changed.connect(func(hp: float, mx: float) -> void: _boss_bar.value = 100.0 * hp / mx)


func show_message(text: String, duration: float = 2.0, sub: String = "") -> void:
	_msg_label.text = text
	_sub_label.text = sub
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.scale = Vector2(1.4, 1.4)
	_msg_label.modulate.a = 0.0
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.parallel().tween_property(_msg_label, "modulate:a", 1.0, 0.2)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.4)


## Shows or hides the blinking "GO >>" arrow.
func show_go(on: bool) -> void:
	_go_label.visible = on


func show_end(title: String, did_win: bool) -> void:
	_ended = true
	_go_label.visible = false
	won = did_win
	_boss_box.visible = false
	_end_title.text = title
	_end_title.label_settings.font_color = Color(0.5, 1.0, 0.7) if won else Color(1.0, 0.35, 0.3)
	var xp_lines := ""
	for pl in Game.players:
		if is_instance_valid(pl):
			var lv := Game.hero_level(pl.hero)
			var pts := Game.free_points(pl.hero)
			xp_lines += "%s  +%d XP   LV %d%s\n" % [pl.display_name(), int(Game.xp_gained.get(pl.hero, 0)), lv,
				("   (%d skill points to spend)" % pts) if pts > 0 else ""]
	var keys := "%s: Space / B      World map: Shift / A" % ("Next level" if won else "Retry")
	if TouchControls.shown:
		keys = "%s: tap %s      World map: tap MAP" % ["Next level" if won else "Retry", "NEXT" if won else "RETRY"]
	_end_stats.text = "Score %d\nDestruction %d%%   Best combo %d   Difficulty %s\n\n%s\n%s" % [
		Game.score, Game.destruction_percent(), Game.best_combo, Game.difficulty()["name"], xp_lines, keys]
	TouchControls.menu_buttons({"JUMP": "NEXT" if won else "RETRY", "DODGE": "MAP"})
	_end_panel.visible = true
	_end_panel.modulate.a = 0.0
	create_tween().tween_property(_end_panel, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if _pause_panel.visible and get_tree().paused and not _ended:
		_pause_input()
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	for p in _panels:
		var hp: ProgressBar = p["hp"]
		var trail: ProgressBar = p["trail"]
		trail.value = move_toward(trail.value, hp.value, 25.0 * delta) if trail.value > hp.value else hp.value
		var pl_ok: bool = p.has("player") and is_instance_valid(p["player"])
		var raging: bool = pl_ok and p["player"].raging
		var rage_now: float = p["player"].rage if pl_ok else 0.0
		var big: bool = pl_ok and p["player"].rage >= p["player"].rage_cost("attack")
		p["rage_flash"] = maxf(float(p.get("rage_flash", 0.0)) - delta, 0.0)
		if p["rage_flash"] > 0.0:
			p["fill"].bg_color = Color(1.0, 0.1, 0.1)
		elif raging:
			p["fill"].bg_color = Color(1.0, 0.2 + pulse * 0.3, 0.1)
		else:
			p["fill"].bg_color = Color(1.0, 0.55 + pulse * 0.4, 0.12 + pulse * 0.6) if big else Color(1.0, 0.55, 0.12)
		p["rage_label"].text = ("RAGE MODE %d" if raging else "RAGE %d") % int(rage_now)
		if p.has("player") and is_instance_valid(p["player"]):
			var pl: Player = p["player"]
			p["weapon"].text = ("%s  x%d   (Y: swing   X: throw)" % [Weapon.KINDS[pl.weapon]["name"], pl.weapon_uses]) if pl.weapon != "" else ""
		var sfull: bool = p["super"].value >= 99.9
		p["super_fill"].bg_color = Color(0.75 + pulse * 0.25, 0.4 + pulse * 0.5, 1.0) if sfull else Color(0.6, 0.35, 1.0)
		p["super_label"].text = "SUPER! [ZL]" if sfull else "SUPER"
		p["join"].modulate.a = 0.35 + 0.4 * pulse
	if _go_label.visible:
		_go_label.modulate.a = 0.4 + 0.6 * pulse
		_go_label.position.x = 1560.0 + pulse * 24.0
	if TouchControls.shown:
		# The keyboard/controller hints would sit under the touch stick.
		_controls.modulate.a = 0.0
	elif _t > 9.0 and _controls.modulate.a > 0.0:
		_controls.modulate.a = maxf(_controls.modulate.a - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		if event.is_action_pressed("jump") or event.is_action_pressed("pause"):
			get_parent().on_end_choice(true)
		elif event.is_action_pressed("back"):
			get_parent().on_end_choice(false)
		return
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


# --- pause menu ------------------------------------------------------------

func _set_paused(on: bool) -> void:
	_pause_panel.visible = on
	_controls.visible = not on and bool(Game.settings["hints"])
	if on:
		TouchControls.menu_buttons({"JUMP": "OK", "DODGE": "BACK", "II": "II"})
	else:
		TouchControls.game_buttons()
	if on:
		get_tree().paused = true
		_pause_settings = false
		_build_pause_list()
	else:
		# Unpause next frame, so the button that closed the menu does not also
		# make a kaiju jump.
		await get_tree().process_frame
		get_tree().paused = false


func _pause_input() -> void:
	var step := 0
	if _any_just("move_up"):
		step = -1
	elif _any_just("move_down"):
		step = 1
	if step != 0:
		_pause_sel = posmod(_pause_sel + step, _pause_items.size())
		_highlight_pause()
		return
	var key: String = _pause_actions[_pause_sel]
	var confirm := Input.is_action_just_pressed("jump") or _any_just("jump")
	var back := Input.is_action_just_pressed("back") or _any_just("dodge")
	if _pause_settings:
		var change := 0
		if _any_just("move_left"):
			change = -1
		elif _any_just("move_right"):
			change = 1
		elif confirm:
			change = 1
		if back or (confirm and key == "back"):
			_pause_settings = false
			_build_pause_list(2)
			return
		if change != 0 and key != "back":
			Game.step_setting(key, change)
			_refresh_pause_values()
		return
	if back:
		_set_paused(false)
	elif confirm:
		match key:
			"resume":
				_set_paused(false)
			"restart":
				Game.start_level(int(Game.level["country"]), int(Game.level["index"]))
			"settings":
				_pause_settings = true
				_build_pause_list()
			"map":
				Game.go_to_menu("map")
			"title":
				Game.go_to_menu("title")


func _any_just(action: String) -> bool:
	for s in Game.MAX_PLAYERS:
		if Input.is_action_just_pressed("p%d_%s" % [s, action]):
			return true
	return false


func _make_pause(root: Control) -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	root.add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	_label(panel, "PAUSED", Vector2(110, 90), 110, Color(1.0, 0.88, 0.7))
	_pause_list = Control.new()
	panel.add_child(_pause_list)
	_label(panel, "Up/Down: choose    B / Space: select    Left/Right: change    A / Shift: back    + / Esc: resume",
		Vector2(110, 1010), 22, Color(1, 1, 1, 0.7))

	# Controls overview, always visible while paused.
	var card := Panel.new()
	card.position = Vector2(820, 110)
	card.size = Vector2(1000, 860)
	card.add_theme_stylebox_override("panel", _card_style(Color(0.06, 0.06, 0.11, 0.9), Color(1, 1, 1, 0.15)))
	panel.add_child(card)
	_label(card, "CONTROLS", Vector2(40, 24), 48, Color(1.0, 0.88, 0.7))
	_label(card, "KEYBOARD", Vector2(430, 44), 24, Color(1.0, 0.75, 0.4))
	_label(card, "CONTROLLER", Vector2(690, 44), 24, Color(1.0, 0.75, 0.4))
	var y := 110.0
	# Rows shrink to fit the card when the list grows.
	var step := minf(66.0, 735.0 / Game.CONTROLS.size())
	for i in Game.CONTROLS.size():
		var row: Array = Game.CONTROLS[i]
		if i % 2 == 0:
			var stripe := ColorRect.new()
			stripe.color = Color(1, 1, 1, 0.04)
			stripe.position = Vector2(20, y - 6)
			stripe.size = Vector2(960, step - 4.0)
			card.add_child(stripe)
		_label(card, row[0], Vector2(40, y), 28, Color.WHITE)
		_label(card, row[1], Vector2(430, y + 2), 26, Color(0.8, 0.88, 1.0))
		_label(card, row[2], Vector2(690, y + 2), 26, Color(1.0, 0.92, 0.7))
		y += step
	return panel


func _build_pause_list(select: int = 0) -> void:
	for c in _pause_list.get_children():
		c.queue_free()
	_pause_items.clear()
	var names := {"resume": "RESUME", "restart": "RESTART LEVEL", "settings": "SETTINGS",
		"map": "WORLD MAP", "title": "QUIT TO TITLE", "back": "BACK"}
	if _pause_settings:
		_pause_actions = Game.setting_keys() + ["back"]
	else:
		_pause_actions = ["resume", "restart", "settings", "map", "title"]
	for i in _pause_actions.size():
		var key: String = _pause_actions[i]
		var item := Panel.new()
		item.position = Vector2(110, 300 + i * 100)
		item.size = Vector2(640, 80)
		item.pivot_offset = Vector2(0, 40)
		_pause_list.add_child(item)
		var l := _label(item, Game.SETTING_NAMES.get(key, names.get(key, "")), Vector2(32, 12), 40, Color.WHITE)
		var v := _label(item, "", Vector2(370, 16), 34, Color(1.0, 0.8, 0.4))
		v.size.x = 240
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_pause_items.append({"panel": item, "label": l, "value": v, "key": key})
	_pause_sel = clampi(select, 0, _pause_items.size() - 1)
	_refresh_pause_values()


func _refresh_pause_values() -> void:
	for it in _pause_items:
		var key: String = it["key"]
		it["value"].text = Game.setting_text(key) if Game.SETTING_NAMES.has(key) else ""
	_highlight_pause()


func _highlight_pause() -> void:
	for i in _pause_items.size():
		var sel := i == _pause_sel
		var it: Dictionary = _pause_items[i]
		it["panel"].add_theme_stylebox_override("panel", _card_style(
			Color(0.9, 0.42, 0.15, 0.9) if sel else Color(0.05, 0.05, 0.1, 0.7),
			Color(1.0, 0.85, 0.5) if sel else Color(1, 1, 1, 0.1)))
		it["label"].label_settings.font_color = Color.WHITE if sel else Color(1, 1, 1, 0.7)
		it["panel"].scale = Vector2.ONE * (1.04 if sel else 1.0)


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	return st


func _on_combo(hits: int) -> void:
	if hits < 2:
		_combo_label.text = ""
		return
	_combo_label.text = "%d HITS" % hits
	_combo_label.pivot_offset = Vector2(450, 35)
	_combo_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_combo_label, "scale", Vector2.ONE, 0.15)


# --- widgets ---------------------------------------------------------------

func _make_panel(root: Control, slot: int) -> Dictionary:
	var x := 40.0 + slot * PANEL_W
	var panel := Control.new()
	panel.position = Vector2(x, 24)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var name_label := _label(panel, "", Vector2(0, 0), 30, Color.WHITE)
	_label(panel, "P%d" % (slot + 1), Vector2(PANEL_W - 110, 4), 24, Color(1, 1, 1, 0.6))
	var trail := _bar(panel, Vector2(0, 44), Vector2(PANEL_W - 60, 24), Color(1, 1, 1, 0.85))
	var hp := _bar(panel, Vector2(0, 44), Vector2(PANEL_W - 60, 24), Color(0.3, 0.95, 0.55))
	hp.get_theme_stylebox("background").bg_color = Color(0, 0, 0, 0)
	var rage := _bar(panel, Vector2(0, 78), Vector2(PANEL_W - 160, 14), Color(1.0, 0.55, 0.12))
	rage.value = 0.0
	var rage_label := _label(panel, "RAGE", Vector2(PANEL_W - 150, 70), 20, Color(1.0, 0.7, 0.3))
	var level_label := _label(panel, "", Vector2(PANEL_W - 195, 4), 24, Color(1.0, 0.95, 0.6))
	var sup := _bar(panel, Vector2(0, 100), Vector2(PANEL_W - 160, 10), Color(0.6, 0.35, 1.0))
	sup.value = 0.0
	var super_label := _label(panel, "SUPER", Vector2(PANEL_W - 150, 94), 18, Color(0.8, 0.65, 1.0))
	var weapon_label := _label(panel, "", Vector2(0, 116), 20, Color(1.0, 0.85, 0.55))
	var join := _label(root, "P%d  PRESS B TO JOIN" % (slot + 1), Vector2(x, 40), 26, Color(1, 1, 1))
	join.visible = slot > 0
	return {"root": panel, "name": name_label, "hp": hp, "trail": trail, "rage": rage,
		"fill": rage.get_theme_stylebox("fill"), "rage_label": rage_label, "join": join,
		"level": level_label, "super": sup, "super_fill": sup.get_theme_stylebox("fill"), "super_label": super_label, "weapon": weapon_label}


func _label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = maxi(4, font_size / 7)
	ls.outline_color = Color(0, 0, 0, 0.85)
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(3, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, pos: Vector2, bar_size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = bar_size
	b.show_percentage = false
	b.max_value = 100.0
	b.value = 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	bg.border_color = Color(1, 1, 1, 0.6)
	bg.set_border_width_all(2)
	bg.skew = Vector2(0.35, 0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.skew = Vector2(0.35, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


func _overlay(parent: Control, title: String, sub: String) -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	parent.add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var t := _label(panel, title, Vector2(0, 330), 120, Color.WHITE)
	t.size = Vector2(1920, 160)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := _label(panel, sub, Vector2(0, 520), 36, Color(1, 1, 1, 0.9))
	s.size = Vector2(1920, 300)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel
