class_name Skills
extends RefCounted
## Hero progression: XP, levels (max 25, 2 skill points per level), each
## hero's 10 abilities and their skill tree, and each hero's super special.
##
## Every tree has the same shape:
##   node 0            root (1 point, unlocks the three branches)
##   nodes 1, 4, 7     tier 1 of branch A/B/C: up to 5 ranks, 1 point each
##   nodes 2, 5, 8     tier 2: up to 5 ranks, 2 points each, needs 3 ranks in tier 1
##   nodes 3, 6, 9     branch end: 1 rank, 6 points, needs tier 2 maxed
## A branch end costs at least 19 points, so with 50 points a hero can finish
## two branches (39 points) but never all three (58).

const MAX_LEVEL := 25
const POINTS_PER_LEVEL := 2
const NODE_COUNT := 10

## Per-rank value and description for every ability kind. "%s" is replaced
## by value * ranks. Branch ends ("cap": true) have a single rank.
const KINDS := {
	"power": {"v": 6.0, "desc": "+%s%% melee damage"},
	"vitality": {"v": 8.0, "desc": "+%s%% max health"},
	"swift": {"v": 5.0, "desc": "+%s%% move speed and faster dodge"},
	"fury": {"v": 12.0, "desc": "+%s%% rage gain"},
	"armor": {"v": 5.0, "desc": "-%s%% damage taken"},
	"leech": {"v": 2.0, "desc": "Heal %s%% of damage dealt"},
	"focus": {"v": 10.0, "desc": "+%s%% rage attack and super damage"},
	"wrecker": {"v": 25.0, "desc": "+%s%% damage to buildings, more rage from them"},
	"crit": {"v": 5.0, "desc": "%s%% chance to deal double damage"},
	"regen": {"v": 0.3, "desc": "Regenerate %s%% health per second"},
	"thorns": {"v": 5.0, "desc": "Attackers take %s damage"},
	"burn": {"v": 2.0, "desc": "Hits burn enemies for %s damage per second"},
	"frost": {"v": 12.0, "desc": "Hits slow enemies by %s%%"},
	"shock": {"v": 6.0, "desc": "Combo finishers chain lightning for %s damage"},
	"quake_slam": {"v": 8.0, "desc": "Heavy slam sends a shockwave forward for %s damage"},
	"stomp": {"v": 15.0, "desc": "+%s%% stomp damage and size"},
	"afterimage": {"v": 6.0, "desc": "Dodging leaves an explosion for %s damage"},
	"execute": {"v": 10.0, "desc": "+%s%% damage to enemies below 30%% health"},
	"berserk": {"v": 1.0, "cap": true, "desc": "Below 40% health: +35% damage and +20% speed"},
	"second_wind": {"v": 1.0, "cap": true, "desc": "Once per stage, survive a deadly hit with 40% health"},
	"overdrive": {"v": 1.0, "cap": true, "desc": "Rage and super fill up by themselves"},
	"long_special": {"v": 1.0, "cap": true, "desc": "Rage attack lasts 50% longer and hits 25% harder"},
	"aftershock": {"v": 1.0, "cap": true, "desc": "Light combo finisher releases a nova blast"},
	"meteor": {"v": 1.0, "cap": true, "desc": "Stomping calls down three meteors"},
	"aura": {"v": 1.0, "cap": true, "desc": "Burn every enemy close to you"},
	"barrier": {"v": 1.0, "cap": true, "desc": "A shield blocks one hit every 8 seconds"},
	"vampire": {"v": 1.0, "cap": true, "desc": "Every defeated enemy heals you 6%"},
}

## Per hero (same order as Content.HEROES): the root ability, then three
## branches of [branch name, tier 1, tier 2, branch end]. Each ability is
## [name, kind]. The super is the hero's super special.
const TREES := [
	{"root": ["Atomic Heart", "focus"], "branches": [
		["BRAWLER", ["Heavy Fists", "power"], ["Seismic Slam", "quake_slam"], ["Unstoppable", "berserk"]],
		["ATOMIC", ["Radiant Scales", "fury"], ["Core Meltdown", "burn"], ["Endless Breath", "long_special"]],
		["SURVIVOR", ["Thick Hide", "vitality"], ["Ancient Blood", "regen"], ["King Never Falls", "second_wind"]]],
		"super": {"name": "OMEGA BREATH", "pattern": "mega_beam"}},
	{"root": ["Static Charge", "swift"], "branches": [
		["CONDUCTOR", ["Arc Claws", "shock"], ["Overvolt", "crit"], ["Living Storm", "aura"]],
		["SPRINTER", ["Flash Step", "afterimage"], ["Hunter's Rush", "execute"], ["Overdrive", "overdrive"]],
		["DYNAMO", ["Capacitor", "fury"], ["Ground Wire", "armor"], ["Lightning Rod", "barrier"]]],
		"super": {"name": "THUNDERSTORM", "pattern": "storm"}},
	{"root": ["Molten Core", "burn"], "branches": [
		["ERUPTION", ["Lava Fists", "power"], ["Magma Wave", "quake_slam"], ["Meteor Stomp", "meteor"]],
		["FURNACE", ["Heat Shield", "armor"], ["Obsidian Skin", "thorns"], ["Volcanic Rebirth", "second_wind"]],
		["DEMOLISHER", ["Wrecking Heat", "wrecker"], ["Slag Crush", "stomp"], ["Pyroclasm", "long_special"]]],
		"super": {"name": "MAGMA RAIN", "pattern": "meteors"}},
	{"root": ["Void Sight", "crit"], "branches": [
		["ECLIPSE", ["Dark Matter", "focus"], ["Gravity Well", "frost"], ["Event Horizon", "aftershock"]],
		["PHANTOM", ["Phase Shift", "afterimage"], ["Void Drain", "leech"], ["Soul Eater", "vampire"]],
		["ASTRAL", ["Star Fury", "fury"], ["Cosmic Flow", "regen"], ["Nebula Shroud", "barrier"]]],
		"super": {"name": "SINGULARITY", "pattern": "vortex"}},
	{"root": ["Bedrock", "vitality"], "branches": [
		["QUAKE", ["Fault Line", "quake_slam"], ["Landslide", "stomp"], ["Avalanche", "meteor"]],
		["FORTRESS", ["Granite Plates", "armor"], ["Spiked Ridge", "thorns"], ["Mountain Ward", "barrier"]],
		["OVERGROWTH", ["Moss Bloom", "regen"], ["Root Grip", "frost"], ["World Tree", "second_wind"]]],
		"super": {"name": "TECTONIC RIFT", "pattern": "rift"}},
	{"root": ["Permafrost", "frost"], "branches": [
		["BLIZZARD", ["Ice Breath", "focus"], ["Shatter", "execute"], ["Endless Winter", "long_special"]],
		["GLACIER", ["Ice Armor", "armor"], ["Frozen Heart", "vitality"], ["Ice Mirror", "barrier"]],
		["AVALANCHE", ["Ice Hammer", "power"], ["Frost Quake", "quake_slam"], ["Hailstorm", "meteor"]]],
		"super": {"name": "ABSOLUTE ZERO", "pattern": "freeze"}},
	{"root": ["Killer Instinct", "execute"], "branches": [
		["PREDATOR", ["Razor Claws", "crit"], ["Bloodlust", "leech"], ["Night Feast", "vampire"]],
		["SHADOW", ["Shadow Dash", "afterimage"], ["Swift Hunter", "swift"], ["Frenzy", "berserk"]],
		["TERROR", ["Dread Roar", "fury"], ["Venom Bite", "burn"], ["Blood Moon", "overdrive"]]],
		"super": {"name": "SHADOW FRENZY", "pattern": "frenzy"}},
	{"root": ["Tidal Heart", "regen"], "branches": [
		["REEF", ["Coral Armor", "armor"], ["Sea Urchin", "thorns"], ["Bubble Ward", "barrier"]],
		["CURRENT", ["Riptide", "frost"], ["Electric Eel", "shock"], ["Maelstrom", "aura"]],
		["ABYSS", ["Pressure Beam", "focus"], ["Deep Lungs", "fury"], ["Tsunami Breath", "long_special"]]],
		"super": {"name": "TIDAL WAVE", "pattern": "wave"}},
	{"root": ["Sun King", "power"], "branches": [
		["CORONA", ["Solar Flare", "burn"], ["Sunspot", "crit"], ["Supernova Fists", "aftershock"]],
		["TYRANT", ["Crushing Jaws", "execute"], ["Tyrant Stomp", "stomp"], ["Reign of Fire", "berserk"]],
		["DAWN", ["Solar Charge", "fury"], ["Radiance", "leech"], ["Eternal Sun", "overdrive"]]],
		"super": {"name": "SUPERNOVA", "pattern": "supernova"}},
	{"root": ["Scrap Armor", "armor"], "branches": [
		["JUNKYARD", ["Wrecking Ball", "wrecker"], ["Crusher Slam", "quake_slam"], ["Scrap Storm", "meteor"]],
		["MACHINE", ["Piston Fists", "power"], ["Overclock", "swift"], ["Rust Engine", "overdrive"]],
		["SALVAGE", ["Spare Parts", "vitality"], ["Barbed Wire", "thorns"], ["Reboot", "second_wind"]]],
		"super": {"name": "SCRAP BARRAGE", "pattern": "scrap"}},
]

const XP_KILL := {"crawler": 10, "brute": 18, "flyer": 12, "elite": 60, "boss": 250}


## Returns [name, kind, branch, tier] for node 0-9 of a hero's tree.
## branch is -1 for the root; tier is 1, 2 or 3 (branch end).
static func node(hero: int, idx: int) -> Array:
	var t: Dictionary = TREES[hero]
	if idx == 0:
		return [t["root"][0], t["root"][1], -1, 0]
	var b := (idx - 1) / 3
	var tier := (idx - 1) % 3 + 1
	var a: Array = t["branches"][b][tier]
	return [a[0], a[1], b, tier]


static func branch_name(hero: int, b: int) -> String:
	return TREES[hero]["branches"][b][0]


static func super_def(hero: int) -> Dictionary:
	return TREES[hero]["super"]


static func max_rank(idx: int) -> int:
	if idx == 0:
		return 1
	return 1 if (idx - 1) % 3 == 2 else 5


static func cost(idx: int) -> int:
	if idx == 0:
		return 1
	return [1, 2, 6][(idx - 1) % 3]


## XP needed to go from level `lvl` to the next.
static func xp_to_next(lvl: int) -> int:
	return 80 + 40 * lvl


static func level_for_xp(xp: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_to_next(lvl):
		xp -= xp_to_next(lvl)
		lvl += 1
	return lvl


## XP collected inside the current level, and how much the level needs.
static func xp_progress(xp: int) -> Vector2i:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_to_next(lvl):
		xp -= xp_to_next(lvl)
		lvl += 1
	if lvl >= MAX_LEVEL:
		return Vector2i(1, 1)
	return Vector2i(xp, xp_to_next(lvl))


static func points_total(xp: int) -> int:
	return level_for_xp(xp) * POINTS_PER_LEVEL


static func points_spent(ranks: Array) -> int:
	var s := 0
	for i in NODE_COUNT:
		s += int(ranks[i]) * cost(i)
	return s


## Why node `idx` can't be bought ("" if it can).
static func buy_block(xp: int, ranks: Array, idx: int) -> String:
	if int(ranks[idx]) >= max_rank(idx):
		return "MAXED"
	if points_total(xp) - points_spent(ranks) < cost(idx):
		return "NOT ENOUGH POINTS"
	if idx == 0:
		return ""
	if int(ranks[0]) == 0:
		return "LEARN %s FIRST" % "THE ROOT"
	var tier := (idx - 1) % 3
	if tier == 1 and int(ranks[idx - 1]) < 3:
		return "NEEDS 3 RANKS IN THE ABILITY ABOVE"
	if tier == 2 and int(ranks[idx - 1]) < 5:
		return "NEEDS THE ABILITY ABOVE MAXED"
	return ""


static func describe(hero: int, idx: int, ranks: int) -> String:
	var n := node(hero, idx)
	var k: Dictionary = KINDS[n[1]]
	if k.get("cap", false):
		return k["desc"]
	var show := maxi(ranks, 1) * (2 if idx == 0 else 1)
	return k["desc"] % _num(float(k["v"]) * show)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v


## Sums a hero's learned abilities into {kind: value}. The root counts double.
static func mods(hero: int, ranks: Array) -> Dictionary:
	var out := {}
	for i in NODE_COUNT:
		var r := int(ranks[i])
		if r == 0:
			continue
		var n := node(hero, i)
		var k: Dictionary = KINDS[n[1]]
		out[n[1]] = float(out.get(n[1], 0.0)) + float(k["v"]) * r * (2 if i == 0 else 1)
	return out
