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
var _boss_box: Control
var _boss_bar: ProgressBar
var _controls: Label
var _pause_panel: Control
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

	_boss_box = Control.new()
	_boss_box.position = Vector2(260, 950)
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = _label(_boss_box, "", Vector2(0, -44), 30, Color(1.0, 0.5, 0.35))
	_boss_bar = _bar(_boss_box, Vector2(0, 0), Vector2(1400, 36), Color(0.95, 0.25, 0.2))

	_controls = _label(root, "Players 2-4: press B on another controller to join\n" +
		"Move: WASD / stick    Jump: Space / B    Light: J / Y    Heavy: K / X\n" +
		"Dodge: Shift / A    Rage mode, then rage attack: L key / R    Super: U key / ZL    Pause: Esc / +\n" +
		"Knock down buildings, then press heavy (K / X) on the wreckage to pick up a weapon",
		Vector2(48, 925), 22, Color(1, 1, 1, 0.85))

	_pause_panel = _overlay(root, "PAUSED", "Resume: Esc / +      World map: Shift / A")
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
			get_tree().paused = true
			_pause_panel.visible = true)


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
	var super_bar: ProgressBar = p["super"]
	super_bar.value = 0.0
	player.super_changed.connect(func(v: float, mx: float) -> void: super_bar.value = 100.0 * v / mx)
	hp_bar.value = 100.0 * player.hp / player.max_hp
	p["trail"].value = hp_bar.value


func show_boss(boss: Kaiju) -> void:
	_boss = boss
	_boss_name.text = boss.display_name()
	_boss_box.visible = true
	_boss_bar.value = 100.0
	boss.health_changed.connect(func(hp: float, mx: float) -> void: _boss_bar.value = 100.0 * hp / mx)


func show_message(text: String, duration: float = 2.0) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.scale = Vector2(1.4, 1.4)
	_msg_label.modulate.a = 0.0
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.parallel().tween_property(_msg_label, "modulate:a", 1.0, 0.2)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.4)


func show_end(title: String, did_win: bool) -> void:
	_ended = true
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
	_end_stats.text = "Score %d\nDestruction %d%%   Best combo %d\n\n%s\n%s: Space / B      World map: Shift / A" % [
		Game.score, Game.destruction_percent(), Game.best_combo, xp_lines, "Next level" if won else "Retry"]
	_end_panel.visible = true
	_end_panel.modulate.a = 0.0
	create_tween().tween_property(_end_panel, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	for p in _panels:
		var hp: ProgressBar = p["hp"]
		var trail: ProgressBar = p["trail"]
		trail.value = move_toward(trail.value, hp.value, 25.0 * delta) if trail.value > hp.value else hp.value
		var full: bool = p["rage"].value >= 99.9
		var raging: bool = p.has("player") and is_instance_valid(p["player"]) and p["player"].raging
		if raging:
			p["fill"].bg_color = Color(1.0, 0.2 + pulse * 0.3, 0.1)
			p["rage_label"].text = "RAGE MODE! [R]"
		else:
			p["fill"].bg_color = Color(1.0, 0.55 + pulse * 0.4, 0.12 + pulse * 0.6) if full else Color(1.0, 0.55, 0.12)
			p["rage_label"].text = "RAGE! [R]" if full else "RAGE"
		if p.has("player") and is_instance_valid(p["player"]):
			var pl: Player = p["player"]
			p["weapon"].text = ("%s  x%d   (Y: swing   X: throw)" % [Weapon.KINDS[pl.weapon]["name"], pl.weapon_uses]) if pl.weapon != "" else ""
		var sfull: bool = p["super"].value >= 99.9
		p["super_fill"].bg_color = Color(0.75 + pulse * 0.25, 0.4 + pulse * 0.5, 1.0) if sfull else Color(0.6, 0.35, 1.0)
		p["super_label"].text = "SUPER! [ZL]" if sfull else "SUPER"
		p["join"].modulate.a = 0.35 + 0.4 * pulse
	if _t > 9.0 and _controls.modulate.a > 0.0:
		_controls.modulate.a = maxf(_controls.modulate.a - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		if event.is_action_pressed("jump") or event.is_action_pressed("pause"):
			get_parent().on_end_choice(true)
		elif event.is_action_pressed("back"):
			get_parent().on_end_choice(false)
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_pause_panel.visible = get_tree().paused
	elif get_tree().paused and event.is_action_pressed("back"):
		Game.go_to_menu("map")


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
