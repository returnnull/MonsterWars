extends Node3D
## Plays one level (Game.level, from Content.level()): builds the country's
## stage, spawns the party, runs the arena waves and handles win/lose.

var hud: Hud
var cam: CameraRig
var lvl: Dictionary
var waves: Array = []
var _wave := 0
var _wave_active := false
var _alive := 0
var _finished := false
var _arena_min := -8.0
var _arena_max := 0.0


func _ready() -> void:
	randomize()
	Game.reset()
	Game.world = self
	if Game.level.is_empty():
		Game.level = Content.level(0, 0)
	lvl = Game.level
	waves = lvl["waves"]
	var country := Content.country(lvl["country"])
	var builder := StageBuilder.new(self, country, lvl["length"], lvl["seed"])
	builder.build()

	hud = Hud.new()
	add_child(hud)
	_update_limits()
	var slots: Array = Game.party.keys()
	slots.sort()
	for slot in slots:
		_join(slot, Game.party[slot])

	cam = CameraRig.new()
	add_child(cam)
	Game.camera_rig = cam
	var weather := builder.make_weather()
	if weather:
		cam.add_child(weather)
	hud.show_message(lvl["title"], 2.2)


func _physics_process(_delta: float) -> void:
	_check_joins()
	_leash_players()
	if _finished or _wave_active or _wave >= waves.size():
		return
	for p in Game.living_players():
		if p.global_position.x >= waves[_wave]["x"] - 4.0:
			_start_wave()
			return


## Drop-in co-op: pressing jump on an unused controller spawns that player
## with the first hero nobody else is using.
func _check_joins() -> void:
	if _finished:
		return
	for slot in range(Game.MAX_PLAYERS):
		if _player_in_slot(slot) == null and Input.is_action_just_pressed("p%d_jump" % slot):
			var used: Array = Game.players.map(func(p: Node3D) -> int: return p.hero)
			var hero := 0
			while hero in used:
				hero += 1
			Game.party[slot] = hero
			_join(slot, hero)


func _player_in_slot(slot: int) -> Player:
	for p in Game.players:
		if is_instance_valid(p) and p.slot == slot:
			return p
	return null


func _join(slot: int, hero: int) -> void:
	var p := Player.new()
	p.slot = slot
	p.hero = hero
	var living := Game.living_players()
	var x := 0.0
	if not living.is_empty():
		for q in living:
			x += q.global_position.x
		x /= living.size()
	var dropping := not living.is_empty()
	p.position = Vector3(clampf(x + randf_range(-3.0, 3.0) + slot * 2.0, _arena_min + 2.0, _arena_max - 2.0),
		14.0 if dropping else 0.2, -1.5 + slot)
	add_child(p)
	p.died.connect(_on_player_died)
	hud.bind(p)
	if dropping:
		hud.show_message("%s JOINS!" % p.display_name(), 1.2)


## Keeps everyone inside the arena and within one screen of each other.
func _leash_players() -> void:
	var living := Game.living_players()
	for p in Game.players:
		if not is_instance_valid(p):
			continue
		var lo := _arena_min
		var hi := _arena_max
		for q in living:
			if q != p:
				lo = maxf(lo, q.global_position.x - 30.0)
				hi = minf(hi, q.global_position.x + 30.0)
		p.x_min = lo
		p.x_max = maxf(hi, lo)


func _update_limits() -> void:
	_arena_min = -8.0
	_arena_max = (waves[_wave]["x"] + 4.0) if _wave < waves.size() else float(lvl["length"])


func _start_wave() -> void:
	_wave_active = true
	var w: Dictionary = waves[_wave]
	var cx: float = w["x"]
	_arena_min = cx - 20.0
	_arena_max = cx + 20.0
	hud.show_message(w["title"], 1.6)
	var kinds: Array = w["spawn"].duplicate()
	if Game.players.size() >= 3 and w["title"] != "BOSS":
		kinds.append("brute")
	_alive = kinds.size()
	for i in kinds.size():
		_spawn(kinds[i], cx, i)


## Enemy health scales with the level and the number of players.
func _player_mul() -> float:
	return 1.0 + 0.5 * (Game.players.size() - 1)


func _spawn(kind: String, cx: float, i: int) -> void:
	await get_tree().create_timer(0.3 + i * 0.9, false).timeout
	var side := 1.0 if i % 2 == 0 else -1.0
	if kind == "flyer":
		var f := Flyer.new()
		f.hp *= float(lvl["hp_mul"]) * _player_mul()
		f.position = Vector3(cx + side * 26.0, 14.0, -2.0)
		add_child(f)
		f.died.connect(_on_enemy_died)
		return
	var b := Brute.new()
	b.kind = kind
	b.hp_mul = float(lvl["hp_mul"]) * _player_mul()
	b.dmg_mul = lvl["dmg_mul"]
	if kind == "boss":
		# Boss stats already grow per country (Content.boss).
		b.boss_def = Content.boss(lvl["country"])
		b.hp_mul = _player_mul()
	b.position = Vector3(cx + side * 23.0, 0.2, randf_range(-3.0, 2.0))
	b.facing = -side
	add_child(b)
	b.died.connect(_on_enemy_died)
	b.spawned_minion.connect(add_enemy)
	if kind == "boss":
		hud.show_boss(b)
		hud.show_message(b.boss_def["name"], 1.6)
		Game.shake(0.8)


## Registers an enemy spawned mid-wave (e.g. a boss summon) so the wave
## only ends once it is dead too.
func add_enemy(e: Node) -> void:
	_alive += 1
	e.died.connect(_on_enemy_died)


func _on_enemy_died(_who: Node) -> void:
	_alive -= 1
	if _alive > 0 or not _wave_active:
		return
	_wave_active = false
	_wave += 1
	if _wave >= waves.size():
		_finished = true
		Game.complete_level(lvl, Game.score)
		await get_tree().create_timer(2.5, false).timeout
		hud.show_end("STAGE CLEAR", true)
	else:
		hud.show_message("GO  >>", 1.6)
		_update_limits()
		for p in Game.players:
			if is_instance_valid(p) and p.dead:
				p.revive()


func _on_player_died(_who: Node) -> void:
	if _finished or not Game.living_players().is_empty():
		return
	_finished = true
	hud.show_end("GAME OVER", false)


## Called from the end screen: after a win, continue to the next level;
## after a loss, retry. Otherwise back to the world map.
func on_end_choice(cont: bool) -> void:
	if not cont:
		Game.go_to_menu("map")
		return
	var g: int = lvl["global"]
	if hud.won:
		g += 1
		if g >= Content.COUNTRIES.size() * Content.LEVELS_PER_COUNTRY:
			Game.go_to_menu("map")
			return
	Game.start_level(g / Content.LEVELS_PER_COUNTRY, g % Content.LEVELS_PER_COUNTRY)
