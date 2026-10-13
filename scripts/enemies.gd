class_name Enemies
extends RefCounted
## Every regular enemy type as data, plus which country introduces it.
##
## class: "kaiju" (Brute), "air" (Flyer) or "ground" (Vehicle).
## Shared keys: name, hp, dmg, speed, xp, score, cost (threat used to fill
## waves), group (how many spawn per pick, default 1), desc.
## Kaiju keys: size, shape (non-uniform model scale), colors [skin, belly,
## spike, eye] (or "random"), horns, moves, armour, windup (multiplier),
## cooldown, element (breath/spit: fire, acid, venom, ice, plasma), summon,
## range (preferred distance as a multiple of melee range), walk, extras
## (EnemyLook features).

const DEFS := {
	# --- kaiju ---------------------------------------------------------------
	"brute": {"name": "BRAWLER", "class": "kaiju", "desc": "Standard melee kaiju",
		"hp": 90.0, "dmg": 12.0, "speed": 4.5, "size": 1.0, "colors": "random", "horns": true,
		"moves": ["swipe"], "xp": 18, "score": 1500, "cost": 1.5},
	"crawler": {"name": "SKITTER", "class": "kaiju", "desc": "Small, fast clawer",
		"hp": 45.0, "dmg": 7.0, "speed": 7.5, "size": 0.72, "colors": "random", "horns": false,
		"moves": ["swipe"], "windup": 0.75, "walk": 1.4, "xp": 10, "score": 800, "cost": 1.0},
	"mossback": {"name": "MOSSBACK", "class": "kaiju", "desc": "Bog kaiju with a mossy shell; slow, tough, slams",
		"hp": 150.0, "dmg": 12.0, "speed": 3.4, "size": 1.1, "shape": Vector3(1.15, 0.9, 1.15),
		"colors": [Color(0.18, 0.26, 0.12), Color(0.45, 0.42, 0.3), Color(0.55, 0.85, 0.25), Color(1.0, 0.9, 0.3)],
		"moves": ["swipe", "slam"], "armour": true, "extras": ["shell"], "walk": 0.6,
		"xp": 26, "score": 2000, "cost": 2.2},
	"rhinox": {"name": "RHINOX", "class": "kaiju", "desc": "Horned charger",
		"hp": 110.0, "dmg": 13.0, "speed": 5.0, "size": 1.05, "shape": Vector3(1.1, 0.95, 1.1),
		"colors": [Color(0.36, 0.34, 0.33), Color(0.6, 0.55, 0.5), Color(1.0, 0.5, 0.2), Color(1.0, 0.25, 0.15)],
		"moves": ["swipe", "charge"], "extras": ["nose_horn"], "xp": 22, "score": 1800, "cost": 2.0},
	"gargling": {"name": "GARGLING", "class": "kaiju", "desc": "Winged stone imp that pounces",
		"hp": 70.0, "dmg": 11.0, "speed": 6.0, "size": 0.85,
		"colors": [Color(0.42, 0.42, 0.44), Color(0.6, 0.58, 0.55), Color(0.5, 0.75, 1.0), Color(1.0, 0.45, 0.15)],
		"horns": true, "moves": ["swipe", "leap"], "extras": ["wings"], "windup": 0.85,
		"xp": 18, "score": 1500, "cost": 1.5},
	"mite": {"name": "MITE", "class": "kaiju", "desc": "Tiny swarmer, comes in packs",
		"hp": 22.0, "dmg": 3.5, "speed": 9.0, "size": 0.5,
		"colors": [Color(0.55, 0.5, 0.25), Color(0.75, 0.7, 0.45), Color(0.9, 0.3, 1.0), Color(1.0, 0.2, 0.6)],
		"moves": ["swipe"], "windup": 0.8, "cooldown": Vector2(1.4, 2.6), "walk": 1.8, "group": 3, "xp": 5, "score": 300, "cost": 0.5},
	"scythe": {"name": "SCYTHE", "class": "kaiju", "desc": "Mantis kaiju, lightning-fast blade combos",
		"hp": 80.0, "dmg": 7.0, "speed": 7.0, "size": 0.95, "shape": Vector3(0.9, 1.12, 0.85),
		"colors": [Color(0.25, 0.42, 0.15), Color(0.6, 0.75, 0.35), Color(0.8, 1.0, 0.3), Color(1.0, 0.95, 0.2)],
		"moves": ["combo", "swipe"], "windup": 0.7, "cooldown": Vector2(1.6, 2.6), "extras": ["blades"], "walk": 1.3,
		"xp": 22, "score": 1800, "cost": 2.0},
	"venomaw": {"name": "VENOMAW", "class": "kaiju", "desc": "Jungle spitter, acid globs and acid breath",
		"hp": 85.0, "dmg": 11.0, "speed": 4.5, "size": 0.95,
		"colors": [Color(0.12, 0.22, 0.14), Color(0.4, 0.5, 0.3), Color(0.4, 1.0, 0.2), Color(0.7, 1.0, 0.2)],
		"moves": ["swipe", "spit", "breath"], "element": "acid", "range": 2.0, "extras": ["sacs"],
		"xp": 22, "score": 1800, "cost": 2.0},
	"boomtick": {"name": "BOOMTICK", "class": "kaiju", "desc": "Bloated runner that blows itself up",
		"hp": 35.0, "dmg": 26.0, "speed": 8.0, "size": 0.62, "shape": Vector3(1.2, 0.85, 1.25),
		"colors": [Color(0.4, 0.2, 0.1), Color(0.8, 0.5, 0.25), Color(1.0, 0.45, 0.05), Color(1.0, 0.8, 0.2)],
		"moves": ["explode"], "extras": ["sacs", "bomb_glow"], "walk": 1.6,
		"xp": 12, "score": 1000, "cost": 1.2},
	"pyrodon": {"name": "PYRODON", "class": "kaiju", "desc": "Fire breather; flames set you alight",
		"hp": 110.0, "dmg": 12.0, "speed": 4.5, "size": 1.05,
		"colors": [Color(0.38, 0.12, 0.08), Color(0.7, 0.45, 0.25), Color(1.0, 0.4, 0.05), Color(1.0, 0.75, 0.1)],
		"horns": true, "moves": ["swipe", "breath"], "element": "fire", "range": 1.6, "extras": ["crest"],
		"xp": 24, "score": 1900, "cost": 2.0},
	"scorpex": {"name": "SCORPEX", "class": "kaiju", "desc": "Desert stinger, lobs venom",
		"hp": 100.0, "dmg": 12.0, "speed": 5.0, "size": 0.95, "shape": Vector3(1.2, 0.85, 1.1),
		"colors": [Color(0.62, 0.48, 0.25), Color(0.85, 0.75, 0.5), Color(0.8, 0.3, 1.0), Color(0.3, 1.0, 0.6)],
		"moves": ["swipe", "spit"], "element": "venom", "range": 1.8, "extras": ["stinger"],
		"xp": 22, "score": 1800, "cost": 2.0},
	"broodmother": {"name": "BROODMOTHER", "class": "kaiju", "desc": "Bloated summoner that hatches mites",
		"hp": 170.0, "dmg": 13.0, "speed": 3.2, "size": 1.25, "shape": Vector3(1.15, 0.95, 1.2),
		"colors": [Color(0.35, 0.25, 0.38), Color(0.75, 0.6, 0.7), Color(0.95, 0.35, 1.0), Color(1.0, 0.3, 0.6)],
		"moves": ["swipe", "summon"], "summon": "mite", "range": 1.6, "extras": ["sacs"], "walk": 0.6,
		"xp": 34, "score": 2600, "cost": 2.5},
	"nagling": {"name": "NAGLING", "class": "kaiju", "desc": "Hooded serpent kaiju, spits venom and strikes",
		"hp": 80.0, "dmg": 11.0, "speed": 6.0, "size": 0.9, "shape": Vector3(0.9, 1.1, 0.9),
		"colors": [Color(0.18, 0.32, 0.15), Color(0.85, 0.75, 0.3), Color(1.0, 0.8, 0.15), Color(1.0, 0.3, 0.8)],
		"moves": ["swipe", "spit", "leap"], "element": "venom", "extras": ["hood"],
		"xp": 20, "score": 1700, "cost": 1.8},
	"shellback": {"name": "SHELLBACK", "class": "kaiju", "desc": "Armoured tank kaiju; shrugs off light hits",
		"hp": 220.0, "dmg": 15.0, "speed": 3.5, "size": 1.15, "shape": Vector3(1.2, 0.85, 1.2),
		"colors": [Color(0.35, 0.25, 0.12), Color(0.75, 0.6, 0.35), Color(1.0, 0.75, 0.2), Color(1.0, 0.5, 0.1)],
		"moves": ["swipe", "slam", "charge"], "armour": true, "extras": ["shell", "tail_club"], "walk": 0.6,
		"xp": 36, "score": 2800, "cost": 3.0},
	"saltjaw": {"name": "SALTJAW", "class": "kaiju", "desc": "Long-snouted croc that rushes in",
		"hp": 120.0, "dmg": 14.0, "speed": 5.5, "size": 1.0, "shape": Vector3(1.25, 0.85, 1.0),
		"colors": [Color(0.22, 0.28, 0.13), Color(0.65, 0.6, 0.4), Color(0.9, 0.9, 0.3), Color(1.0, 0.8, 0.1)],
		"moves": ["swipe", "charge"], "extras": ["snout"], "xp": 24, "score": 1900, "cost": 2.0},
	"frostfang": {"name": "FROSTFANG", "class": "kaiju", "desc": "Ice breather; frost slows you down",
		"hp": 110.0, "dmg": 12.0, "speed": 4.5, "size": 1.0,
		"colors": [Color(0.5, 0.6, 0.7), Color(0.85, 0.9, 0.95), Color(0.5, 0.9, 1.0), Color(0.7, 1.0, 1.0)],
		"horns": true, "moves": ["swipe", "breath"], "element": "ice", "range": 1.6, "extras": ["crystals"],
		"xp": 24, "score": 1900, "cost": 2.0},
	"titanodon": {"name": "TITANODON", "class": "kaiju", "desc": "Huge, slow behemoth with a tail club",
		"hp": 340.0, "dmg": 20.0, "speed": 2.8, "size": 1.55,
		"colors": [Color(0.2, 0.18, 0.16), Color(0.45, 0.4, 0.35), Color(1.0, 0.3, 0.1), Color(1.0, 0.6, 0.1)],
		"horns": true, "moves": ["swipe", "slam", "charge"], "armour": true, "windup": 1.15,
		"cooldown": Vector2(1.6, 2.8), "extras": ["tail_club", "crest"], "walk": 0.5,
		"xp": 50, "score": 4000, "cost": 4.0},
	"geysirwurm": {"name": "GEYSIRWURM", "class": "kaiju", "desc": "Burrows underground and erupts beneath you",
		"hp": 120.0, "dmg": 15.0, "speed": 4.0, "size": 1.0, "shape": Vector3(1.05, 0.95, 1.05),
		"colors": [Color(0.3, 0.32, 0.33), Color(0.55, 0.5, 0.45), Color(0.3, 1.0, 0.85), Color(0.5, 1.0, 0.9)],
		"moves": ["swipe", "burrow"], "extras": ["crest", "crystals"], "xp": 26, "score": 2100, "cost": 2.2},
	"magmite": {"name": "MAGMITE", "class": "kaiju", "desc": "Lava kaiju: fire breath and burning leaps",
		"hp": 100.0, "dmg": 12.0, "speed": 5.0, "size": 0.9,
		"colors": [Color(0.1, 0.07, 0.07), Color(0.4, 0.15, 0.08), Color(1.0, 0.35, 0.0), Color(1.0, 0.7, 0.1)],
		"moves": ["swipe", "leap", "breath"], "element": "fire", "extras": ["crystals"],
		"xp": 24, "score": 1900, "cost": 2.0},
	"voltwyrm": {"name": "VOLTWYRM", "class": "kaiju", "desc": "Calls lightning down on your position",
		"hp": 140.0, "dmg": 15.0, "speed": 4.5, "size": 1.1,
		"colors": [Color(0.1, 0.14, 0.3), Color(0.35, 0.4, 0.6), Color(1.0, 0.95, 0.3), Color(0.6, 0.9, 1.0)],
		"moves": ["swipe", "shock"], "range": 1.8, "extras": ["crest", "antenna"],
		"xp": 30, "score": 2400, "cost": 2.5},
	"mechadon": {"name": "MECHADON", "class": "kaiju", "desc": "Armoured robot kaiju: plasma breath and charge",
		"hp": 200.0, "dmg": 14.0, "speed": 4.5, "size": 1.2,
		"colors": [Color(0.42, 0.44, 0.48), Color(0.25, 0.26, 0.3), Color(0.3, 0.8, 1.0), Color(1.0, 0.15, 0.1)],
		"horns": true, "moves": ["swipe", "breath", "charge"], "element": "plasma", "armour": true,
		"extras": ["armor_plates", "antenna"], "xp": 40, "score": 3200, "cost": 3.0},
	"elite": {"name": "ELITE", "class": "kaiju", "desc": "Armoured mini-boss",
		"hp": 220.0, "dmg": 16.0, "speed": 5.0, "size": 1.22, "colors": "elite", "horns": true,
		"moves": ["swipe", "charge"], "armour": true, "extras": ["crest"], "xp": 60, "score": 3000, "cost": 4.0},
	# --- air -----------------------------------------------------------------
	"drone": {"name": "DRONE", "class": "air", "desc": "Hovers, shoots plasma, swoops low",
		"hp": 35.0, "dmg": 8.0, "xp": 12, "score": 600, "cost": 1.0},
	"heli": {"name": "GUNSHIP", "class": "air", "desc": "Attack helicopter firing bullet bursts",
		"hp": 55.0, "dmg": 4.0, "xp": 16, "score": 900, "cost": 1.5},
	"bomber": {"name": "BOMBER JET", "class": "air", "desc": "Strafes across the street dropping bombs",
		"hp": 45.0, "dmg": 13.0, "xp": 16, "score": 1000, "cost": 1.8},
	"wasp": {"name": "WASP DRONE", "class": "air", "desc": "Kamikaze drone that dives and explodes",
		"hp": 14.0, "dmg": 12.0, "group": 2, "xp": 6, "score": 400, "cost": 0.7},
	"saucer": {"name": "SAUCER", "class": "air", "desc": "Plasma spreads; drops low for ring blasts",
		"hp": 80.0, "dmg": 8.0, "xp": 24, "score": 1600, "cost": 2.5},
	# --- ground --------------------------------------------------------------
	"tank": {"name": "TANK", "class": "ground", "desc": "Keeps its distance and fires shells",
		"hp": 60.0, "dmg": 10.0, "speed": 4.0, "xp": 12, "score": 800, "cost": 1.3},
	"artillery": {"name": "ARTILLERY", "class": "ground", "desc": "Lobs shells onto marked spots from afar",
		"hp": 55.0, "dmg": 15.0, "speed": 3.0, "xp": 16, "score": 1000, "cost": 1.8},
	"missile": {"name": "SAM LAUNCHER", "class": "ground", "desc": "Launches homing missiles",
		"hp": 65.0, "dmg": 9.0, "speed": 3.5, "xp": 18, "score": 1100, "cost": 2.0},
	"mech": {"name": "MECH WALKER", "class": "ground", "desc": "Bipedal mech: gun bursts and kicks",
		"hp": 120.0, "dmg": 8.0, "speed": 4.0, "xp": 24, "score": 1600, "cost": 2.5},
	"maser": {"name": "MASER CANNON", "class": "ground", "desc": "Charges a long-range beam",
		"hp": 90.0, "dmg": 5.0, "speed": 2.2, "xp": 24, "score": 1500, "cost": 2.5},
}

## Per country: which enemy types it introduces and at which level (0-9).
## "new" types stay in the mix for every later country; "local" types only
## show up in their own country (and in the Japan finale).
const ROSTER := [
	{"new": [["brute", 0], ["drone", 1], ["crawler", 2], ["tank", 5]], "local": [["mossback", 3]]},
	{"new": [["rhinox", 0], ["heli", 3]], "local": [["gargling", 1]]},
	{"new": [["mite", 0], ["missile", 2], ["bomber", 5]], "local": [["mech", 3]]},
	{"new": [["scythe", 0], ["boomtick", 3]], "local": [["venomaw", 1]]},
	{"new": [["pyrodon", 0], ["artillery", 2]], "local": [["scorpex", 1]]},
	{"new": [["wasp", 0], ["broodmother", 2]], "local": [["nagling", 1]]},
	{"new": [["shellback", 0]], "local": [["saltjaw", 1]]},
	{"new": [["frostfang", 0], ["maser", 2], ["titanodon", 5]], "local": []},
	{"new": [["geysirwurm", 0], ["saucer", 2]], "local": [["magmite", 1]]},
	{"new": [["voltwyrm", 0]], "local": [["mechadon", 1]]},
]

const BASICS := ["brute", "crawler", "drone"]


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["brute"])


static func xp(id: String) -> int:
	if DEFS.has(id):
		return int(DEFS[id].get("xp", 12))
	return int(Skills.XP_KILL.get(id, 12))


## All regular enemy ids (no elite, no bosses).
static func regular_ids() -> Array:
	return DEFS.keys().filter(func(k: String) -> bool: return k != "elite")


## Enemy ids introduced exactly at this level (shown first in wave 1).
static func introduced(country_idx: int, level_idx: int) -> Array:
	var out: Array = []
	var r: Dictionary = ROSTER[clampi(country_idx, 0, ROSTER.size() - 1)]
	for e in r["new"] + r["local"]:
		if int(e[1]) == level_idx:
			out.append(e[0])
	return out


## Weighted pool of [id, weight] that may appear on this level.
static func pool(country_idx: int, level_idx: int) -> Array:
	var out: Array = []
	for c in range(0, country_idx + 1):
		var r: Dictionary = ROSTER[c]
		for e in r["new"]:
			if c == country_idx and int(e[1]) > level_idx:
				continue
			var w := 2.2 if c == country_idx else 1.0
			if c < country_idx and e[0] in BASICS and country_idx >= 3:
				w = 0.5
			out.append([e[0], w])
		for e in r["local"]:
			if c == country_idx and int(e[1]) <= level_idx:
				out.append([e[0], 2.0])
			elif c < country_idx and country_idx == ROSTER.size() - 1:
				out.append([e[0], 0.6])
	return out


static func pick(rng: RandomNumberGenerator, entries: Array) -> String:
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var r := rng.randf() * total
	for e in entries:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return entries[-1][0]
