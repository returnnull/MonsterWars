extends Node3D
## Dev check: trophies and cosmetics. Every trophy unlocks one existing item
## and every item has one trophy, every item builds and has an anchor on
## every hero, stats award trophies, beating the game gives the crowns, and
## locked items can't be worn.
## Run: godot --headless --path . res://tests/trophy_test.tscn

var _fails := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	Game.stats = {}
	Game.trophies = {}
	Game.outfits = {}
	Game.reset()

	_check(Trophies.LIST.size() == 53, "53 trophies (3 crowns + 50)")
	_check(Cosmetics.ITEMS.size() == Trophies.LIST.size(), "one item per trophy")
	var ids := {}
	var items := {}
	for t in Trophies.LIST:
		_check(not ids.has(t["id"]), "trophy id %s is unique" % t["id"])
		ids[t["id"]] = true
		_check(Cosmetics.ITEMS.has(t["item"]), "%s unlocks an existing item" % t["id"])
		_check(not items.has(t["item"]), "%s is the only trophy for %s" % [t["id"], t["item"]])
		items[t["item"]] = true
	for id in Cosmetics.ITEMS:
		_check(Cosmetics.item(id)["slot"] in Cosmetics.SLOTS, "%s has a slot" % id)
		var n := Cosmetics.build(id)
		_check(n.get_child_count() > 0, "%s builds" % id)
		n.free()

	# Every slot has an anchor on every hero, and dressing in a full outfit works.
	for hi in Content.HEROES.size():
		var m := GlbKaijuModel.for_hero(Content.hero(hi), self)
		for slot in Cosmetics.SLOTS:
			var a := m.cosmetic_anchor(slot)
			_check(a != null, "%s has a %s anchor" % [Content.hero(hi)["name"], slot])
		var outfit := {}
		for slot in Cosmetics.SLOTS:
			outfit[slot] = Cosmetics.for_slot(slot)[hi % Cosmetics.for_slot(slot).size()]
		Cosmetics.dress(m, outfit)
		_check(m.get_meta("cosmetics", []).size() == Cosmetics.SLOTS.size(), "%s wears 5 items" % Content.hero(hi)["name"])
		Cosmetics.dress(m, {})
		m.queue_free()

	# Stats award trophies.
	Game.track("kills", 99)
	_check(not Game.has_trophy("kills_100"), "99 kills is not enough")
	Game.count_kill("heli")
	_check(Game.has_trophy("kills_100"), "100 kills gives Pest Control")
	_check(int(Game.stats.get("kills_air", 0)) == 1 and int(Game.stats.get("kills_heli", 0)) == 1, "kills count by class and kind")

	# Locked items can't be worn; unlocked ones can.
	Game.wear(0, "head", "gold_crown")
	_check(Game.outfit(0).get("head", "") == "", "a locked crown can't be worn")
	Game.wear(0, "head", "party_hat")
	_check(Game.outfit(0).get("head", "") == "party_hat", "the party hat can be worn")
	Game.wear(0, "face", "party_hat")
	_check(not Game.outfit(0).has("face"), "an item only fits its own slot")
	Game.wear(0, "head", "")
	_check(Game.outfit(0).is_empty(), "taking the hat off")

	# Beating the final boss on Hard gives all three crowns and the boss trophies.
	Game.reset()
	Game.settings["difficulty"] = 2
	var final := Content.level(Content.COUNTRIES.size() - 1, Content.LEVELS_PER_COUNTRY - 1)
	Game.run["time"] = 200.0
	Game.run["hurt"] = true
	Game.run["rage"] = true
	Game.level_won(final)
	Game.settings["difficulty"] = 1
	for c in ["crown_easy", "crown_normal", "crown_hard", "boss_9", "hard_boss"]:
		_check(Game.has_trophy(c), "final boss on Hard gives %s" % c)
	_check(not Game.has_trophy("zen") and not Game.has_trophy("flawless") and not Game.has_trophy("fast"),
		"a hurt, raging, slow win gives no special clears")

	# On Easy only the bronze crown.
	Game.trophies = {}
	Game.stats = {}
	Game.reset()
	Game.settings["difficulty"] = 0
	Game.run["time"] = 30.0
	Game.level_won(final)
	Game.settings["difficulty"] = 1
	_check(Game.has_trophy("crown_easy") and not Game.has_trophy("crown_normal"), "Easy gives only the bronze crown")
	_check(Game.has_trophy("zen") and Game.has_trophy("flawless") and Game.has_trophy("fast"), "a clean fast boss win counts")

	# Hero levels count for the level trophies.
	Game.hero_xp[3] = 999999
	Game.check_trophies()
	_check(Game.has_trophy("level_10") and Game.has_trophy("level_25"), "a level 25 kaiju gives both level trophies")
	_check(not Game.has_trophy("all_level_10"), "one kaiju is not all of them")
	Game.hero_xp[3] = 0

	print("TROPHY TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		_fails += 1
