extends Node3D
## Plays one level (Game.level, from Content.level()): builds the country's
## stage, spawns the party, runs the arena waves and handles win/lose.
## The level is a walk to the right through a row of arenas. A barricade
## (ArenaGate) blocks the street at each arena's right edge; when a player
## walks in, a second one closes behind them, and both are smashed open
## once every enemy of the wave is down.

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
var _gates: Array = []  # per wave: [left gate, right gate]


func _ready() -> void:
	randomize()
	Game.reset()
	Game.world = self
	TouchControls.game_buttons()
	if Game.level.is_empty():
		Game.level = Content.level(0, 0)
	lvl = Game.level
	waves = lvl["waves"]
	var country := Content.country(lvl["country"])
	var builder := StageBuilder.new(self, Content.with_mood(country, lvl.get("mood", "")), lvl["length"], lvl["seed"],
		lvl.get("district", "downtown"))
	builder.build()
	_build_gates()

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
	hud.show_message(lvl["title"], 2.6, lvl.get("subtitle", ""))


func _physics_process(delta: float) -> void:
	if not _finished:
		Game.run["time"] = float(Game.run.get("time", 0.0)) + delta
	_check_joins()
	_leash_players()
	if _finished or _wave_active or _wave >= waves.size():
		return
	var w: Dictionary = waves[_wave]
	for p in Game.living_players():
		if p.global_position.x >= _trigger_x(w):
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


## Half the width of a wave's arena (older level data has none).
static func _half(w: Dictionary) -> float:
	return float(w.get("half", 20.0))


## Where a player has to get to for a wave to start: a bit into its arena.
static func _trigger_x(w: Dictionary) -> float:
	return float(w["x"]) - _half(w) * 0.3


## One pair of gates per arena. The right ones stand from the start.
func _build_gates() -> void:
	for w in waves:
		var pair: Array = []
		for side in [-1.0, 1.0]:
			var g := ArenaGate.new()
			g.kind = w.get("gate", "barricade")
			g.position = Vector3(float(w["x"]) + side * (_half(w) + 1.0), 0, 0)
			add_child(g)
			pair.append(g)
		pair[1].raise(true)
		_gates.append(pair)


## Before a wave the way on ends at its right gate; after the last one the
## street is open to the end of the level.
func _update_limits() -> void:
	if _wave < waves.size():
		var w: Dictionary = waves[_wave]
		_arena_min = -8.0 if _wave == 0 else float(waves[_wave - 1]["x"]) - _half(waves[_wave - 1])
		_arena_max = float(w["x"]) + _half(w) - 0.5
	else:
		_arena_min = -8.0 if waves.is_empty() else float(waves[-1]["x"]) - _half(waves[-1])
		_arena_max = float(lvl["length"]) + 20.0


func _start_wave() -> void:
	_wave_active = true
	var w: Dictionary = waves[_wave]
	var cx: float = w["x"]
	var half := _half(w)
	_arena_min = cx - half + 0.5
	_arena_max = cx + half - 0.5
	if _wave < _gates.size():
		_gates[_wave][0].raise()
	# Anyone left behind the closing gate is pulled into the arena.
	for p in Game.players:
		if is_instance_valid(p) and p.global_position.x < _arena_min + 1.0:
			p.global_position = Vector3(_arena_min + 2.0 + p.slot * 1.5, 8.0, p.global_position.z)
			FX.dust(Vector3(p.global_position.x, 0.3, p.global_position.z), 1.2)
	hud.show_go(false)
	hud.show_message(w["title"], 1.6)
	var kinds := party_spawns(w["spawn"], Game.players.size())
	if Game.players.size() >= 3 and w["title"] != "BOSS":
		kinds.append("brute")
	_alive = kinds.size()
	for i in kinds.size():
		_spawn(kinds[i], cx, half, i)


## Each player beyond the first brings 20% more enemies, picked from the
## wave's own (non-boss) kinds, so the wave keeps its mix whatever the
## level data puts in it.
const EXTRA_ENEMIES_PER_PLAYER := 0.2


static func party_spawns(spawn: Array, players: int) -> Array:
	var kinds: Array = spawn.duplicate()
	var pool: Array = spawn.filter(func(k: String) -> bool: return k != "boss")
	var extra := roundi(pool.size() * EXTRA_ENEMIES_PER_PLAYER * maxi(players - 1, 0))
	pool.shuffle()
	for i in extra:
		kinds.append(pool[i % pool.size()])
	return kinds


## Enemy health scales with the level and the number of players.
func _player_mul() -> float:
	return 1.0 + 0.5 * (Game.players.size() - 1)


func _spawn(kind: String, cx: float, half: float, i: int) -> void:
	await get_tree().create_timer(0.3 + i * 0.9, false).timeout
	if not is_inside_tree():
		return
	var e = make_enemy(kind, cx, 1.0 if i % 2 == 0 else -1.0, half)
	add_child(e)
	e.died.connect(_on_enemy_died)
	if e.has_signal("spawned_minion"):
		e.spawned_minion.connect(add_enemy)
	if kind == "boss":
		hud.show_boss(e)
		hud.show_message(e.boss_def["name"], 1.6)
		Game.shake(0.8)


## Builds any enemy by its Enemies.DEFS id (or "boss") for the arena centred
## on `cx` (`half` wide each way), entering from `side` over the gate,
## scaled to the level and the party size.
func make_enemy(kind: String, cx: float, side: float, half: float = 20.0) -> Node3D:
	var def := Enemies.get_def(kind)
	var diff := Game.difficulty()
	var hp_mul := float(lvl["hp_mul"]) * _player_mul() * float(diff["hp"])
	var dmg_mul := float(lvl["dmg_mul"]) * float(diff["dmg"])
	match def.get("class", "kaiju") if kind != "boss" else "kaiju":
		"air":
			var f := Flyer.new()
			f.kind = kind
			f.def = def
			f.hp_mul = hp_mul
			f.dmg_mul = dmg_mul
			f.arena = Vector2(cx - half, cx + half)
			f.position = Vector3(cx + side * (half + 6.0), 14.0 if kind != "bomber" else 9.0, -2.0)
			return f
		"infantry":
			var s := Infantry.new()
			s.kind = kind
			s.def = def
			s.hp_mul = hp_mul
			s.dmg_mul = dmg_mul
			s.arena = Vector2(cx - half, cx + half)
			s.position = Vector3(cx + side * randf_range(half, half + 5.0), 0.2, randf_range(-4.0, 2.5))
			s.facing = -side
			return s
		"ground":
			var v := Vehicle.new()
			v.kind = kind
			v.def = def
			v.hp_mul = hp_mul
			v.dmg_mul = dmg_mul
			v.arena = Vector2(cx - half + 2.0, cx + half - 2.0)
			v.position = Vector3(cx + side * (half + 3.0), 0.2, randf_range(-3.0, 2.0))
			v.facing = -side
			return v
	var b := Brute.new()
	b.kind = kind
	b.hp_mul = hp_mul
	b.dmg_mul = dmg_mul
	if kind == "boss":
		# Boss stats already grow per country (Content.boss).
		b.boss_def = Content.boss(lvl["country"])
		b.hp_mul = _player_mul() * float(diff["hp"])
	else:
		b.def = def
	b.arena = Vector2(cx - half, cx + half)
	b.x_min = cx - half - 2.5
	b.x_max = cx + half + 2.5
	b.position = Vector3(cx + side * (half + 2.0), 0.2, randf_range(-3.0, 2.0))
	b.facing = -side
	return b


## Registers an enemy spawned mid-wave (e.g. a boss summon) so the wave
## only ends once it is dead too.
func add_enemy(e: Node) -> void:
	_alive += 1
	e.died.connect(_on_enemy_died)


func _on_enemy_died(who: Node) -> void:
	_alive -= 1
	var kind: String = who.kind if "kind" in who else "drone"
	Game.count_kill(kind)
	var base := Enemies.xp(kind) if kind != "boss" else int(Skills.XP_KILL.get(kind, 250))
	var xp := int(base * (1.0 + lvl["global"] * 0.04) * float(Game.difficulty()["xp"]))
	for p in Game.living_players():
		p.on_enemy_killed()
		_give_xp(p, xp)
	if _alive > 0 or not _wave_active:
		return
	_wave_active = false
	if _wave < _gates.size():
		for g in _gates[_wave]:
			g.open()
	_wave += 1
	if _wave >= waves.size():
		_finished = true
		var bonus := int((60 + int(lvl["global"]) * 6) * float(Game.difficulty()["xp"]))
		for p in Game.players:
			if is_instance_valid(p):
				_give_xp(p, bonus)
		Game.level_won(lvl)
		Game.complete_level(lvl, Game.score)
		await get_tree().create_timer(2.5, false).timeout
		hud.show_end("STAGE CLEAR", true)
	else:
		# Bank the wave's XP, in case the game is closed mid-level.
		Game.save_progress()
		hud.show_message("GO  >>", 1.6)
		hud.show_go(true)
		_update_limits()
		for p in Game.players:
			if is_instance_valid(p) and p.dead:
				p.revive()


func _give_xp(p: Player, xp: int) -> void:
	var gained := Game.add_xp(p.hero, xp)
	if gained > 0:
		var lv := Game.hero_level(p.hero)
		var tier := SuperTree.tiers_open(lv) > SuperTree.tiers_open(lv - gained)
		hud.show_message("%s  LV %d!%s" % [p.display_name(), lv, "  NEW SUPER PICK" if tier else ""], 1.4)
		FX.energy(p.global_position + Vector3(0, 4, 0), Color(1.0, 0.95, 0.5))
		FX.shockwave(p.global_position, 6.0, Color(1.0, 0.95, 0.5))


func _on_player_died(_who: Node) -> void:
	if _finished or not Game.living_players().is_empty():
		return
	_finished = true
	Game.save_progress()
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
