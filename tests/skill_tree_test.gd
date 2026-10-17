extends Node3D
## Dev check: every hero's skill tree is well formed and plays by the rules.
## Each tree has its own shape, at least two start nodes, hangs together,
## has a rage modifier and its own mix of skill kinds, only
## some nodes take several ranks, rows open by points spent in the whole
## tree, and one straight line down can't reach the bottom row.
## Run: godot --headless --path . res://tests/skill_tree_test.tscn

const RAGE_KINDS := ["fury", "bloodrage", "rampage", "frugal", "deep_rage", "blood_pact", "wrath", "overdrive"]

var _fails := 0


func _ready() -> void:
	Game.set_meta("no_save", true)
	var max_points := Skills.MAX_LEVEL * Skills.POINTS_PER_LEVEL
	var shapes := {}
	var signatures := {}
	var kind_sets := []
	for h in Content.HEROES.size():
		var hn: String = Content.HEROES[h]["name"]
		var cells := {}
		var kinds := {}
		var multi := 0
		var starts := 0
		for i in Skills.node_count(h):
			var n := Skills.node(h, i)
			var cell := "%d,%d" % [n["row"], n["col"]]
			_check(not cells.has(cell), "%s: one node at %s" % [hn, cell])
			cells[cell] = true
			_check(Skills.KINDS.has(n["kind"]), "%s: %s has a known kind" % [hn, n["name"]])
			_check(n["row"] >= 0 and n["row"] < Skills.ROWS and n["col"] >= 0 and n["col"] < Skills.COLS,
				"%s: %s sits on the grid" % [hn, n["name"]])
			var cap: bool = Skills.KINDS[n["kind"]].get("cap", false)
			_check(not cap or Skills.max_rank(h, i) == 1, "%s: %s is on/off, so one rank" % [hn, n["name"]])
			if Skills.max_rank(h, i) > 1:
				multi += 1
			kinds[n["kind"]] = true
			if n["row"] == 0:
				starts += 1
				_check(n["parents"].is_empty(), "%s: top row %s needs nothing" % [hn, n["name"]])
			else:
				_check(Skills.parents(h, i).size() == n["parents"].size() and not n["parents"].is_empty(),
					"%s: %s hangs from real nodes" % [hn, n["name"]])
		_check(starts >= 2, "%s: tree has at least two start nodes (has %d)" % [hn, starts])
		_check(kinds.size() >= 15, "%s: tree has at least 15 kinds of skills (has %d)" % [hn, kinds.size()])
		kind_sets.append(kinds)
		shapes[cells.keys().reduce(func(a, c): return a + c + ";", "")] = true
		_check(Skills.node_count(h) >= 16, "%s: tree has at least 16 skills" % hn)
		_check(multi > 0 and multi < Skills.node_count(h) - 3, "%s: only some skills take several ranks" % hn)
		_check(RAGE_KINDS.any(func(k): return kinds.has(k)), "%s: tree has a rage modifier" % hn)
		_check(Skills.tree_cost(h) > max_points * 1.3, "%s: tree is much bigger than the points (%d vs %d)" %
			[hn, Skills.tree_cost(h), max_points])
		for k in ["static", "inferno", "venom", "frostbite", "killrush", "tide_heal", "radiance", "salvage", "meltdown", "bulwark"]:
			if kinds.has(k):
				signatures[k] = signatures.get(k, []) + [h]
		_check_rules(h, hn, max_points)
	_check(shapes.size() == Content.HEROES.size(), "every hero's tree has its own shape")
	# No two heroes share most of their skill kinds.
	for a in kind_sets.size():
		for b in range(a + 1, kind_sets.size()):
			var shared: int = kind_sets[a].keys().filter(func(k): return kind_sets[b].has(k)).size()
			_check(shared * 4 <= mini(kind_sets[a].size(), kind_sets[b].size()) * 3,
				"%s and %s share at most 3/4 of their skill kinds (%d)" % [Content.HEROES[a]["name"], Content.HEROES[b]["name"], shared])
	var used := {}
	for ks in kind_sets:
		used.merge(ks)
	for k in Skills.KINDS:
		_check(used.has(k), "skill kind %s is used by some hero" % k)
	for k in signatures:
		_check(signatures[k].size() == 1, "signature %s belongs to one hero" % k)
	_check(signatures.size() == Content.HEROES.size(), "every hero has a signature skill")
	print("SKILL TREE TEST: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


## Buying straight down one line stalls before the bottom row; buying
## greedily across the tree reaches it.
func _check_rules(h: int, hn: String, max_points: int) -> void:
	var xp := 999999
	var ranks := Skills.empty_ranks(h)
	for i in Skills.node_count(h):
		if Skills.is_capstone(h, i):
			_check(Skills.buy_block(h, xp, ranks, i) != "", "%s: bottom row starts locked" % hn)
	# One line: always the first node of the next row that hangs from the last.
	var cur := -1
	for row in Skills.ROWS:
		var pick := -1
		for i in Skills.node_count(h):
			if Skills.node(h, i)["row"] == row and (cur < 0 or cur in Skills.parents(h, i)):
				pick = i
				break
		if pick < 0 or Skills.buy_block(h, xp, ranks, pick) != "":
			break
		while Skills.buy_block(h, xp, ranks, pick) == "":
			ranks[pick] += 1
		cur = pick
	var deepest := 0
	for i in Skills.node_count(h):
		if int(ranks[i]) > 0:
			deepest = maxi(deepest, Skills.node(h, i)["row"])
	_check(deepest < Skills.ROWS - 1, "%s: one line alone can't reach the bottom row (got row %d)" % [hn, deepest + 1])
	# Spreading out reaches the bottom: always take the deepest skill on offer.
	ranks = Skills.empty_ranks(h)
	xp = _xp_for_level(Skills.MAX_LEVEL)
	while true:
		var pick := -1
		for i in Skills.node_count(h):
			if Skills.buy_block(h, xp, ranks, i) != "":
				continue
			if pick < 0 or Skills.node(h, i)["row"] > Skills.node(h, pick)["row"]:
				pick = i
		if pick < 0:
			break
		ranks[pick] += 1
	_check(Skills.points_spent(h, ranks) <= max_points, "%s: never spends more than it has" % hn)
	var capped := false
	for i in Skills.node_count(h):
		if Skills.is_capstone(h, i) and int(ranks[i]) > 0:
			capped = true
	_check(capped, "%s: spreading points reaches the bottom row" % hn)
	var m := Skills.mods(h, ranks)
	_check(not m.is_empty(), "%s: learned skills give effects" % hn)
	print("%s: %d skills, tree costs %d, line reaches row %d, spread buys %d skills" % [hn, Skills.node_count(h), Skills.tree_cost(h), deepest + 1, ranks.filter(func(r): return r > 0).size()])


func _xp_for_level(lvl: int) -> int:
	var xp := 0
	for l in range(1, lvl):
		xp += Skills.xp_to_next(l)
	return xp


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
