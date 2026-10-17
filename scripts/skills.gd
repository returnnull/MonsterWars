class_name Skills
extends RefCounted
## Hero progression: XP, levels (max 25, 2 skill points per level), each
## hero's own skill tree, and each hero's super special.
##
## Every hero has a tree of its own shape: 7 rows of abilities on a 5-column
## grid. A node needs at least one rank in one of the nodes it hangs from in
## the row above (row 0 needs nothing), and a row only opens once enough
## points are spent in the tree as a whole (ROW_GATE). One straight line
## down a tree costs far less than the last gate asks for, so a hero has to
## spread points over several lines to reach the bottom. Only some nodes
## take several ranks; the rest are learned once. With 50 points a hero
## gets a bit over half of its tree.

const MAX_LEVEL := 25
const POINTS_PER_LEVEL := 2
const ROWS := 7
const COLS := 5
## Points that must be spent in the tree before a row opens.
const ROW_GATE := [0, 3, 7, 13, 20, 28, 36]
## Price of one rank, per row.
const ROW_COST := [1, 2, 2, 3, 3, 4, 5]
## Saves made before trees were hero-specific are refunded (see Game).
const SAVE_VERSION := 2

## Per-rank value and description for every ability kind. "%s" is replaced
## by the value. Kinds with "cap": true are on/off. A stat node that can only
## be learned once gives twice the per-rank value.
const KINDS := {
	"power": {"v": 6.0, "desc": "+%s%% melee damage"},
	"vitality": {"v": 8.0, "desc": "+%s%% max health"},
	"swift": {"v": 5.0, "desc": "+%s%% move speed and faster dodge"},
	"fury": {"v": 12.0, "desc": "+%s%% rage gain"},
	"bloodrage": {"v": 25.0, "desc": "+%s%% rage from taking damage"},
	"rampage": {"v": 2.0, "desc": "Every defeated enemy gives %s rage"},
	"frugal": {"v": 6.0, "desc": "Rage skills and rage mode cost %s%% less rage"},
	"deep_rage": {"v": 10.0, "desc": "+%s max rage"},
	"armor": {"v": 5.0, "desc": "-%s%% damage taken"},
	"leech": {"v": 3.0, "desc": "Heal %s%% of damage dealt"},
	"ability_leech": {"v": 4.0, "desc": "Rage attacks and supers heal %s%% of the damage they deal"},
	"focus": {"v": 10.0, "desc": "+%s%% rage skill and super damage"},
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
	# Hero signatures: each fits one hero's element.
	"static": {"v": 5.0, "desc": "%s%% chance per hit to arc lightning to two enemies"},
	"inferno": {"v": 20.0, "desc": "+%s%% burn and poison damage"},
	"venom": {"v": 2.0, "desc": "Hits poison enemies for %s damage per second for 5 seconds"},
	"frostbite": {"v": 15.0, "desc": "Enemies that hit you are slowed by %s%%"},
	"killrush": {"v": 6.0, "desc": "Every defeated enemy gives +%s%% damage for 5 seconds"},
	"tide_heal": {"v": 3.0, "desc": "Rage skills heal %s%% max health"},
	"radiance": {"v": 10.0, "desc": "+%s%% super meter gain"},
	"salvage": {"v": 2.0, "desc": "Every defeated enemy repairs %s%% health"},
	"meltdown": {"v": 1.0, "cap": true, "desc": "Entering rage mode sets off an atomic blast"},
	"bulwark": {"v": 1.0, "cap": true, "desc": "Rage mode halves damage taken (instead of -25%)"},
	"berserk": {"v": 1.0, "cap": true, "desc": "Below 40% health: +35% damage and +20% speed"},
	"second_wind": {"v": 1.0, "cap": true, "desc": "Once per stage, survive a deadly hit with 40% health"},
	"overdrive": {"v": 1.0, "cap": true, "desc": "Rage and super fill up by themselves"},
	"blood_pact": {"v": 1.0, "cap": true, "desc": "Rage skills can be used without enough rage: health pays the rest"},
	"wrath": {"v": 1.0, "cap": true, "desc": "Half of all rage spent also fills the super meter"},
	"long_special": {"v": 1.0, "cap": true, "desc": "Rage attack lasts 50% longer and hits 25% harder"},
	"aftershock": {"v": 1.0, "cap": true, "desc": "Light combo finisher releases a nova blast"},
	"meteor": {"v": 1.0, "cap": true, "desc": "Stomping calls down three meteors"},
	"aura": {"v": 1.0, "cap": true, "desc": "Burn every enemy close to you"},
	"barrier": {"v": 1.0, "cap": true, "desc": "A shield blocks one hit every 8 seconds"},
	"vampire": {"v": 1.0, "cap": true, "desc": "Every defeated enemy heals you 6%"},
}

## Per hero (same order as Content.HEROES): its super special and its tree.
## Each node is [name, kind, row, column, ranks, parents], where parents are
## the columns in the row above it hangs from (any one of them will do). Every tree has at least one
## rage modifier (fury, bloodrage, rampage, frugal, deep_rage, blood_pact,
## wrath or overdrive), and a way to heal in row 1 (leech or ability_leech).
## Saves store ranks by node index, so new nodes go at the end of a list.
const TREES := [
	{"super": {"name": "OMEGA BREATH", "pattern": "mega_beam"}, "nodes": [  # GORRAX, atom
		["Atomic Heart", "focus", 0, 2, 3, []],
		["Heavy Fists", "power", 1, 1, 5, [2]],
		["Glowing Eyes", "crit", 1, 2, 1, [2]],
		["Radiant Scales", "fury", 1, 3, 3, [2]],
		["Thick Hide", "vitality", 2, 0, 1, [1]],
		["Seismic Slam", "quake_slam", 2, 2, 1, [1, 2, 3]],
		["Chain Reaction", "rampage", 2, 4, 1, [3]],
		["Ancient Blood", "regen", 3, 0, 3, [0]],
		["Bone Plates", "armor", 3, 1, 1, [0, 2]],
		["Fission", "afterimage", 3, 3, 1, [2, 4]],
		["Half-Life", "frugal", 3, 4, 1, [4]],
		["Unstoppable", "berserk", 4, 1, 1, [0, 1]],
		["Critical Mass", "stomp", 4, 2, 1, [1, 3]],
		["Isotope Burn", "burn", 4, 3, 3, [3, 4]],
		["Fallout", "aura", 5, 0, 1, [1]],
		["Reactor Core", "deep_rage", 5, 2, 1, [1, 2, 3]],
		["Endless Breath", "long_special", 5, 4, 1, [3]],
		["King Never Falls", "second_wind", 6, 1, 1, [0, 2]],
		["Meltdown", "meltdown", 6, 3, 1, [2, 4]],
		["Atomic Siphon", "ability_leech", 1, 4, 3, [2]]]},
	{"super": {"name": "THUNDERSTORM", "pattern": "storm"}, "nodes": [  # VOLTRA, storm
		["Static Charge", "swift", 0, 1, 3, []],
		["Spark Gap", "static", 0, 3, 3, []],
		["Arc Claws", "shock", 1, 0, 1, [1]],
		["Capacitor", "fury", 1, 2, 3, [1, 3]],
		["Flash Step", "afterimage", 1, 4, 1, [3]],
		["Overvolt", "crit", 2, 0, 1, [0]],
		["Conductor", "power", 2, 1, 1, [0, 2]],
		["Ion Skin", "armor", 2, 3, 1, [2, 4]],
		["Hunter's Rush", "execute", 2, 4, 1, [4]],
		["Storm Core", "deep_rage", 3, 2, 1, [1, 3]],
		["Forked Bolt", "static", 4, 0, 3, [2]],
		["Lightning Rod", "barrier", 4, 1, 1, [2]],
		["Storm Surge", "frugal", 4, 3, 1, [2]],
		["Tailwind", "swift", 4, 4, 1, [2]],
		["Thunderclap", "quake_slam", 5, 1, 1, [0, 1]],
		["Supercell", "focus", 5, 2, 3, [1, 3]],
		["Ozone Shield", "vitality", 5, 3, 1, [3, 4]],
		["Living Storm", "aura", 6, 0, 1, [1]],
		["Overdrive", "overdrive", 6, 2, 1, [1, 2, 3]],
		["Eye of the Storm", "wrath", 6, 4, 1, [3]],
		["Siphon Claws", "leech", 1, 1, 3, [1]]]},
	{"super": {"name": "MAGMA RAIN", "pattern": "meteors"}, "nodes": [  # MAGMOS, magma
		["Molten Core", "burn", 0, 2, 3, []],
		["Lava Fists", "power", 1, 0, 5, [2]],
		["Boiling Blood", "bloodrage", 1, 2, 1, [2]],
		["Wrecking Heat", "wrecker", 1, 4, 1, [2]],
		["Magma Wave", "quake_slam", 2, 1, 1, [0, 2]],
		["Obsidian Skin", "thorns", 2, 3, 3, [2, 4]],
		["Slag Crush", "stomp", 3, 0, 1, [1]],
		["White Heat", "inferno", 3, 2, 3, [1, 3]],
		["Basalt Hide", "armor", 3, 4, 1, [3]],
		["Fire Walker", "afterimage", 4, 0, 1, [0]],
		["Ember Heart", "regen", 4, 1, 1, [0, 2]],
		["Pressure Vent", "deep_rage", 4, 3, 1, [2, 4]],
		["Ash Cloud", "frost", 4, 4, 1, [4]],
		["Volcanic Rebirth", "second_wind", 5, 1, 1, [0, 1]],
		["Hot Temper", "fury", 5, 2, 3, [1, 3]],
		["Lava Lake", "aura", 5, 3, 1, [3, 4]],
		["Meteor Stomp", "meteor", 6, 0, 1, [1]],
		["Caldera", "inferno", 6, 2, 1, [1, 2, 3]],
		["Pyroclasm", "long_special", 6, 4, 1, [3]],
		["Ember Feast", "ability_leech", 1, 3, 3, [2]]]},
	{"super": {"name": "SINGULARITY", "pattern": "vortex"}, "nodes": [  # SYLVARA, venom
		["Void Sight", "crit", 0, 1, 3, []],
		["Toxic Glands", "venom", 0, 3, 3, []],
		["Phase Shift", "afterimage", 1, 0, 1, [1]],
		["Dark Matter", "focus", 1, 2, 1, [1, 3]],
		["Acid Blood", "thorns", 1, 4, 1, [3]],
		["Void Drain", "leech", 2, 1, 3, [0, 2]],
		["Neurotoxin", "frost", 2, 3, 1, [2, 4]],
		["Star Fury", "fury", 3, 0, 1, [1]],
		["Gravity Pull", "execute", 3, 1, 1, [1]],
		["Event Horizon", "aftershock", 3, 2, 1, [1, 3]],
		["Virulence", "venom", 3, 3, 3, [3]],
		["Spore Cloud", "regen", 3, 4, 1, [3]],
		["Cosmic Flow", "frugal", 4, 1, 3, [0, 1, 2]],
		["Wither", "power", 4, 3, 1, [2, 3, 4]],
		["Nebula Shroud", "barrier", 5, 0, 1, [1]],
		["Miasma", "aura", 5, 2, 1, [1, 3]],
		["Blight Hide", "vitality", 5, 4, 1, [3]],
		["Void Hunger", "vampire", 6, 1, 1, [0, 2]],
		["Plague Empress", "wrath", 6, 3, 1, [2, 4]],
		["Venom Siphon", "ability_leech", 1, 1, 3, [1]]]},
	{"super": {"name": "TECTONIC RIFT", "pattern": "rift"}, "nodes": [  # TERRAXA, earth
		["Bedrock", "vitality", 0, 2, 3, []],
		["Fault Line", "quake_slam", 1, 1, 1, [2]],
		["Granite Plates", "armor", 1, 2, 5, [2]],
		["Moss Bloom", "regen", 1, 3, 1, [2]],
		["Landslide", "stomp", 2, 0, 1, [1]],
		["Old Grudge", "bloodrage", 2, 2, 1, [1, 2, 3]],
		["Root Grip", "frost", 2, 4, 1, [3]],
		["Boulder Fists", "power", 3, 0, 3, [0]],
		["Aftershock", "aftershock", 3, 1, 1, [0, 2]],
		["Crystal Thorns", "thorns", 3, 3, 3, [2, 4]],
		["Mountain Ward", "barrier", 3, 4, 1, [4]],
		["Avalanche", "meteor", 4, 0, 1, [0, 1]],
		["Stone Heart", "deep_rage", 4, 2, 3, [1, 3]],
		["Deep Roots", "leech", 4, 4, 1, [3, 4]],
		["Rockslide", "execute", 5, 1, 1, [0, 2]],
		["Rumble", "fury", 5, 2, 1, [2]],
		["World Tree", "second_wind", 5, 3, 1, [2, 4]],
		["Unbreakable", "bulwark", 6, 1, 1, [1, 2]],
		["Tectonic Rage", "rampage", 6, 3, 1, [2, 3]],
		["Earth Drink", "ability_leech", 1, 4, 3, [2]]]},
	{"super": {"name": "ABSOLUTE ZERO", "pattern": "freeze"}, "nodes": [  # GLACIOR, frost
		["Permafrost", "frost", 0, 1, 3, []],
		["Ice Armor", "armor", 0, 3, 3, []],
		["Ice Breath", "focus", 1, 0, 1, [1]],
		["Cold Blood", "frugal", 1, 2, 3, [1, 3]],
		["Rime Shell", "frostbite", 1, 4, 1, [3]],
		["Shatter", "execute", 2, 0, 1, [0]],
		["Ice Hammer", "power", 2, 1, 1, [0, 2]],
		["Glacial Bulk", "vitality", 2, 3, 1, [2, 4]],
		["Frozen Heart", "deep_rage", 2, 4, 1, [4]],
		["Frost Quake", "quake_slam", 3, 1, 3, [0, 1]],
		["Deep Freeze", "frostbite", 3, 3, 3, [3, 4]],
		["Endless Winter", "long_special", 4, 0, 1, [1]],
		["Snow Drift", "swift", 4, 2, 1, [1, 3]],
		["Ice Mirror", "barrier", 4, 4, 1, [3]],
		["Black Ice", "crit", 5, 1, 1, [0, 2]],
		["Icicle Burst", "afterimage", 5, 2, 1, [2]],
		["Frozen Fury", "fury", 5, 3, 1, [2, 4]],
		["Hailstorm", "meteor", 6, 0, 1, [1]],
		["Ice Age", "wrath", 6, 2, 1, [1, 2, 3]],
		["Glacier Heart", "second_wind", 6, 4, 1, [3]],
		["Frozen Bite", "leech", 1, 1, 3, [1]]]},
	{"super": {"name": "SHADOW FRENZY", "pattern": "frenzy"}, "nodes": [  # NOCTYR, shadow and blood
		["Killer Instinct", "execute", 0, 2, 3, []],
		["Razor Claws", "crit", 1, 0, 3, [2]],
		["Dread Roar", "fury", 1, 2, 1, [2]],
		["Shadow Dash", "afterimage", 1, 4, 1, [2]],
		["Bloodlust", "leech", 2, 0, 1, [0]],
		["Night Eyes", "power", 2, 1, 1, [0, 2]],
		["Swift Hunter", "swift", 2, 3, 3, [2, 4]],
		["Fade", "barrier", 2, 4, 1, [4]],
		["Night Feast", "killrush", 3, 2, 3, [1, 3]],
		["Blood Scent", "rampage", 4, 0, 1, [2]],
		["Blood Pact", "blood_pact", 4, 1, 1, [2]],
		["Rend", "power", 4, 3, 1, [2]],
		["Bone Armor", "armor", 4, 4, 1, [2]],
		["Hemorrhage", "burn", 5, 0, 1, [0, 1]],
		["Frenzy", "berserk", 5, 2, 1, [1, 3]],
		["Gloom Hide", "vitality", 5, 4, 1, [3, 4]],
		["Soul Eater", "vampire", 6, 1, 1, [0, 2]],
		["Endless Hunt", "killrush", 6, 2, 3, [2]],
		["Blood Moon", "overdrive", 6, 3, 1, [2, 4]],
		["Crimson Drain", "ability_leech", 1, 3, 3, [2]]]},
	{"super": {"name": "TIDAL WAVE", "pattern": "wave"}, "nodes": [  # CORALIS, water
		["Tidal Heart", "regen", 0, 1, 3, []],
		["Pressure Beam", "focus", 0, 3, 3, []],
		["Coral Armor", "armor", 1, 0, 3, [1]],
		["Riptide", "frost", 1, 2, 1, [1, 3]],
		["Deep Lungs", "deep_rage", 1, 4, 1, [3]],
		["Sea Urchin", "thorns", 2, 1, 1, [0, 2]],
		["Undertow", "execute", 2, 2, 1, [2]],
		["Electric Eel", "shock", 2, 3, 1, [2, 4]],
		["Healing Tide", "tide_heal", 3, 0, 3, [1]],
		["Hydro Fists", "power", 3, 2, 3, [1, 2, 3]],
		["Shell Plates", "vitality", 3, 4, 1, [3]],
		["Bubble Ward", "barrier", 4, 0, 1, [0]],
		["Whirlpool", "afterimage", 4, 1, 1, [0, 2]],
		["Rogue Wave", "quake_slam", 4, 3, 1, [2, 4]],
		["Moon Tide", "fury", 4, 4, 1, [4]],
		["Spring Tide", "tide_heal", 5, 1, 1, [0, 1]],
		["Kelp Hide", "leech", 5, 3, 1, [3, 4]],
		["Maelstrom", "aura", 6, 0, 1, [1]],
		["Call of the Deep", "second_wind", 6, 2, 1, [1, 3]],
		["Tidal Fury", "wrath", 6, 4, 1, [3]],
		["Tidal Siphon", "ability_leech", 1, 1, 3, [1]]]},
	{"super": {"name": "SUPERNOVA", "pattern": "supernova"}, "nodes": [  # SOLAR REX, sun
		["Sun King", "power", 0, 2, 5, []],
		["Solar Flare", "burn", 1, 1, 3, [2]],
		["Crushing Jaws", "execute", 1, 3, 1, [2]],
		["Sunspot", "crit", 2, 0, 1, [1]],
		["Heat Haze", "afterimage", 2, 1, 1, [1]],
		["Solar Charge", "fury", 2, 2, 1, [1, 3]],
		["Tyrant Stomp", "stomp", 2, 3, 3, [3]],
		["Royal Hide", "vitality", 2, 4, 1, [3]],
		["Radiance", "radiance", 3, 1, 3, [0, 1, 2]],
		["Sunscale", "armor", 3, 3, 1, [2, 3, 4]],
		["Supernova Fists", "aftershock", 4, 0, 1, [1]],
		["Solar Wind", "frugal", 4, 2, 1, [1, 3]],
		["Reign of Fire", "berserk", 4, 4, 1, [3]],
		["Zenith", "radiance", 5, 1, 3, [0, 2]],
		["Daybreak", "regen", 5, 2, 1, [2]],
		["Tyrant's Roar", "rampage", 5, 3, 1, [2, 4]],
		["Corona", "aura", 6, 0, 1, [1]],
		["Eternal Sun", "overdrive", 6, 2, 1, [1, 2, 3]],
		["Solar Throne", "second_wind", 6, 4, 1, [3]],
		["Sun Feast", "leech", 1, 2, 3, [2]]]},
	{"super": {"name": "SCRAP BARRAGE", "pattern": "scrap"}, "nodes": [  # RUSTFANG, scrap
		["Scrap Armor", "armor", 0, 1, 3, []],
		["Piston Fists", "power", 0, 3, 3, []],
		["Spare Parts", "vitality", 1, 0, 1, [1]],
		["Barbed Wire", "thorns", 1, 1, 1, [1]],
		["Wrecking Ball", "wrecker", 1, 3, 3, [3]],
		["Overclock", "frugal", 1, 4, 1, [3]],
		["Riveted Hide", "regen", 2, 0, 1, [0, 1]],
		["Crusher Slam", "quake_slam", 2, 2, 1, [1, 3]],
		["Turbo", "swift", 2, 4, 1, [3, 4]],
		["Salvage", "salvage", 3, 1, 3, [0, 2]],
		["Hydraulics", "stomp", 3, 3, 3, [2, 4]],
		["Magnet Claw", "leech", 4, 0, 1, [1]],
		["Scrap Shield", "barrier", 4, 1, 1, [1]],
		["Coolant Tank", "deep_rage", 4, 2, 1, [1, 3]],
		["Grinder", "crit", 4, 3, 1, [3]],
		["Exhaust", "burn", 4, 4, 1, [3]],
		["Reboot", "second_wind", 5, 1, 1, [0, 1, 2]],
		["Junk Rage", "bloodrage", 5, 3, 1, [2, 3, 4]],
		["Scrap Storm", "meteor", 6, 0, 1, [1]],
		["Rust Engine", "overdrive", 6, 2, 1, [1, 3]],
		["Recycler", "wrath", 6, 4, 1, [3]],
		["Siphon Pump", "leech", 1, 2, 3, [1, 3]]]},
]

## Fallback kill XP; regular enemies take theirs from Enemies.DEFS.
const XP_KILL := {"crawler": 10, "brute": 18, "flyer": 12, "drone": 12, "elite": 60, "boss": 250}


static func node_count(hero: int) -> int:
	return TREES[hero]["nodes"].size()


## Returns {name, kind, row, col, ranks, parents} for one node of a hero's tree.
static func node(hero: int, idx: int) -> Dictionary:
	var a: Array = TREES[hero]["nodes"][idx]
	return {"name": a[0], "kind": a[1], "row": a[2], "col": a[3], "ranks": a[4], "parents": a[5]}


## Index of the node at (row, col), or -1.
static func node_at(hero: int, row: int, col: int) -> int:
	var nodes: Array = TREES[hero]["nodes"]
	for i in nodes.size():
		if nodes[i][2] == row and nodes[i][3] == col:
			return i
	return -1


## Indexes of the nodes `idx` hangs from.
static func parents(hero: int, idx: int) -> Array:
	var n := node(hero, idx)
	var out := []
	for c in n["parents"]:
		var p := node_at(hero, n["row"] - 1, c)
		if p >= 0:
			out.append(p)
	return out


static func super_def(hero: int) -> Dictionary:
	return TREES[hero]["super"]


static func max_rank(hero: int, idx: int) -> int:
	return int(TREES[hero]["nodes"][idx][4])


static func cost(hero: int, idx: int) -> int:
	return ROW_COST[int(TREES[hero]["nodes"][idx][2])]


## True for the bottom row, the hardest nodes to reach.
static func is_capstone(hero: int, idx: int) -> bool:
	return int(TREES[hero]["nodes"][idx][2]) == ROWS - 1


## A fresh, unlearned tree for a hero.
static func empty_ranks(hero: int) -> Array:
	var ranks := []
	ranks.resize(node_count(hero))
	ranks.fill(0)
	return ranks


## Every point it takes to learn a hero's whole tree.
static func tree_cost(hero: int) -> int:
	var s := 0
	for i in node_count(hero):
		s += max_rank(hero, i) * cost(hero, i)
	return s


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


static func points_spent(hero: int, ranks: Array) -> int:
	var s := 0
	for i in mini(ranks.size(), node_count(hero)):
		s += int(ranks[i]) * cost(hero, i)
	return s


## Why node `idx` can't be bought ("" if it can).
static func buy_block(hero: int, xp: int, ranks: Array, idx: int) -> String:
	if int(ranks[idx]) >= max_rank(hero, idx):
		return "MAXED"
	var n := node(hero, idx)
	var spent := points_spent(hero, ranks)
	if spent < ROW_GATE[n["row"]]:
		return "SPEND %d MORE POINTS IN THIS TREE TO OPEN ROW %d" % [ROW_GATE[n["row"]] - spent, n["row"] + 1]
	var ps := parents(hero, idx)
	if not ps.is_empty() and not ps.any(func(p: int) -> bool: return int(ranks[p]) > 0):
		return "LEARN A SKILL IT HANGS FROM FIRST"
	if points_total(xp) - spent < cost(hero, idx):
		return "NOT ENOUGH POINTS"
	return ""


## What one rank of a node is worth.
static func rank_value(hero: int, idx: int) -> float:
	var k: Dictionary = KINDS[node(hero, idx)["kind"]]
	return float(k["v"]) * (2.0 if max_rank(hero, idx) == 1 and not k.get("cap", false) else 1.0)


static func describe(hero: int, idx: int, ranks: int) -> String:
	var k: Dictionary = KINDS[node(hero, idx)["kind"]]
	if k.get("cap", false):
		return k["desc"]
	return k["desc"] % _num(rank_value(hero, idx) * maxi(ranks, 1))


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v


## Sums a hero's learned abilities into {kind: value}.
static func mods(hero: int, ranks: Array) -> Dictionary:
	var out := {}
	for i in mini(ranks.size(), node_count(hero)):
		var r := int(ranks[i])
		if r == 0:
			continue
		var kind: String = node(hero, i)["kind"]
		out[kind] = float(out.get(kind, 0.0)) + rank_value(hero, i) * r
	return out
