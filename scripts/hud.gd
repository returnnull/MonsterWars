class_name Hud
extends CanvasLayer
## In-game HUD: health/rage bars, score, destruction, combo counter, boss bar,
## banner messages, pause menu and end screen. Laid out for a 1920x1080 canvas.

var _hp_bar: ProgressBar
var _hp_trail: ProgressBar
var _rage_bar: ProgressBar
var _rage_fill: StyleBoxFlat
var _rage_label: Label
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

	_label(root, "GORRAX", Vector2(48, 28), 34, Color(0.75, 0.95, 1.0))
	_hp_trail = _bar(root, Vector2(48, 78), Vector2(560, 28), Color(1, 1, 1, 0.85))
	_hp_bar = _bar(root, Vector2(48, 78), Vector2(560, 28), Color(0.3, 0.95, 0.55))
	_hp_bar.get_theme_stylebox("background").bg_color = Color(0, 0, 0, 0)
	_rage_bar = _bar(root, Vector2(48, 116), Vector2(440, 16), Color(1.0, 0.55, 0.12))
	_rage_fill = _rage_bar.get_theme_stylebox("fill")
	_rage_bar.value = 0
	_rage_label = _label(root, "RAGE", Vector2(500, 108), 22, Color(1.0, 0.7, 0.3))

	_score_label = _label(root, "0", Vector2(1420, 24), 46, Color.WHITE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.size = Vector2(450, 60)
	_destroy_label = _label(root, "DESTRUCTION 0%", Vector2(1420, 84), 26, Color(1.0, 0.75, 0.45))
	_destroy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_destroy_label.size = Vector2(450, 36)
	_combo_label = _label(root, "", Vector2(1420, 140), 52, Color(1.0, 0.9, 0.3))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.size = Vector2(450, 70)

	_msg_label = _label(root, "", Vector2(0, 380), 110, Color(1.0, 0.95, 0.85))
	_msg_label.size = Vector2(1920, 160)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.pivot_offset = Vector2(960, 80)
	_msg_label.modulate.a = 0.0

	_boss_box = Control.new()
	_boss_box.position = Vector2(460, 960)
	_boss_box.visible = false
	root.add_child(_boss_box)
	_label(_boss_box, "TYRANNOX, THE CRIMSON KING", Vector2(0, -44), 30, Color(1.0, 0.5, 0.35))
	_boss_bar = _bar(_boss_box, Vector2(0, 0), Vector2(1000, 22), Color(0.95, 0.25, 0.2))

	_controls = _label(root, "Move: WASD / stick    Jump: Space / B    Light: J / Y    Heavy: K / X\n" +
		"Dodge: Shift / A    Rage beam: L key / R or ZR    Pause: Esc / +    Attack in the air = stomp",
		Vector2(48, 980), 22, Color(1, 1, 1, 0.85))

	_pause_panel = _overlay(root, "PAUSED", "Press Esc / + to resume")
	_end_panel = _overlay(root, "", "")
	_end_title = _end_panel.get_child(1)
	_end_stats = _end_panel.get_child(2)

	Game.score_changed.connect(func(s: int) -> void: _score_label.text = str(s))
	Game.destruction_changed.connect(func(_d: int, _t2: int) -> void:
		_destroy_label.text = "DESTRUCTION %d%%" % Game.destruction_percent())
	Game.combo_changed.connect(_on_combo)


func bind(player: Player) -> void:
	player.health_changed.connect(func(hp: float, mx: float) -> void: _hp_bar.value = 100.0 * hp / mx)
	player.rage_changed.connect(func(r: float, mx: float) -> void: _rage_bar.value = 100.0 * r / mx)
	_hp_bar.value = 100.0
	_hp_trail.value = 100.0


func show_boss(boss: Kaiju) -> void:
	_boss = boss
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


func show_end(title: String, won: bool) -> void:
	_ended = true
	_boss_box.visible = false
	_end_title.text = title
	_end_title.label_settings.font_color = Color(0.5, 1.0, 0.7) if won else Color(1.0, 0.35, 0.3)
	_end_stats.text = "Score %d\nDestruction %d%%   Best combo %d\n\nPress Space / B to play again" % [
		Game.score, Game.destruction_percent(), Game.best_combo]
	_end_panel.visible = true
	_end_panel.modulate.a = 0.0
	create_tween().tween_property(_end_panel, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_hp_trail.value = move_toward(_hp_trail.value, _hp_bar.value, 25.0 * delta) if _hp_trail.value > _hp_bar.value else _hp_bar.value
	var full := _rage_bar.value >= 99.9
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	_rage_fill.bg_color = Color(1.0, 0.55 + pulse * 0.4, 0.12 + pulse * 0.6) if full else Color(1.0, 0.55, 0.12)
	_rage_label.text = "RAGE READY  [L / R]" if full else "RAGE"
	if _t > 9.0 and _controls.modulate.a > 0.0:
		_controls.modulate.a = maxf(_controls.modulate.a - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		if event.is_action_pressed("jump") or event.is_action_pressed("pause"):
			get_tree().paused = false
			get_tree().reload_current_scene()
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_pause_panel.visible = get_tree().paused


func _on_combo(hits: int) -> void:
	if hits < 2:
		_combo_label.text = ""
		return
	_combo_label.text = "%d HITS" % hits
	_combo_label.pivot_offset = Vector2(450, 35)
	_combo_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_combo_label, "scale", Vector2.ONE, 0.15)


# --- widgets ---------------------------------------------------------------

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
