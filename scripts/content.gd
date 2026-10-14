class_name Content
extends RefCounted
## All game content as data: 10 heroes, 10 countries (each with its own look,
## landmark and boss) and a deterministic generator for the 100 levels.

const LEVELS_PER_COUNTRY := 10

# special: "beam" (straight breath beam), "nova" (radial blasts), "quake" (travelling ground shockwaves)
# look: body shape overrides for KaijuModel (spike_shape, rows, neck_len, head_size, snout, bulk,
# arm_size, tail_len, tail_thick, posture, crest, gem, seams, arm_spikes, spike_size).
const HEROES := [
	{"name": "GORRAX", "title": "The Original", "skin": Color(0.2, 0.33, 0.3), "belly": Color(0.68, 0.62, 0.48),
		"accent": Color(0.3, 0.85, 1.0), "eye": Color(0.5, 0.95, 1.0), "horns": false, "size": 1.0,
		"hp": 260.0, "speed": 1.0, "power": 1.0, "special": "beam", "look": {"spike_shape": 3, "rows": 3, "neck_len": 1.0, "posture": 0.14, "snout": 1.0}},
	{"name": "VOLTRA", "title": "Storm Runner", "skin": Color(0.36, 0.33, 0.18), "belly": Color(0.75, 0.68, 0.45),
		"accent": Color(1.0, 0.9, 0.25), "eye": Color(1.0, 0.95, 0.5), "horns": true, "size": 0.92,
		"hp": 210.0, "speed": 1.25, "power": 0.9, "special": "beam", "look": {"spike_shape": 2, "rows": 2, "neck_len": 1.25, "bulk": 0.9, "arm_size": 0.9, "head_size": 0.92, "snout": 1.15, "tail_len": 1.25, "tail_thick": 0.88}},
	{"name": "MAGMOS", "title": "Molten Heart", "skin": Color(0.32, 0.16, 0.13), "belly": Color(0.7, 0.5, 0.36),
		"accent": Color(1.0, 0.4, 0.15), "eye": Color(1.0, 0.6, 0.25), "horns": true, "size": 1.12,
		"hp": 300.0, "speed": 0.85, "power": 1.3, "special": "quake", "look": {"spike_shape": 4, "rows": 3, "neck_len": 0.85, "bulk": 1.1, "head_size": 1.05, "seams": true, "tail_thick": 1.08}},
	{"name": "SYLVARA", "title": "Void Empress", "skin": Color(0.25, 0.2, 0.34), "belly": Color(0.65, 0.58, 0.7),
		"accent": Color(0.85, 0.4, 1.0), "eye": Color(0.95, 0.6, 1.0), "horns": false, "size": 1.0,
		"hp": 240.0, "speed": 1.1, "power": 1.0, "special": "nova", "look": {"spike_shape": 2, "rows": 3, "neck_len": 1.35, "bulk": 0.94, "snout": 1.2, "crest": true, "gem": true, "posture": 0.16}},
	{"name": "TERRAXA", "title": "Living Mountain", "skin": Color(0.3, 0.3, 0.2), "belly": Color(0.55, 0.5, 0.35),
		"accent": Color(0.5, 1.0, 0.35), "eye": Color(0.7, 1.0, 0.4), "horns": true, "size": 1.18,
		"hp": 360.0, "speed": 0.8, "power": 1.15, "special": "quake", "look": {"spike_shape": 1, "rows": 3, "neck_len": 0.75, "bulk": 1.16, "arm_size": 1.2, "head_size": 1.08, "tail_len": 0.85, "tail_thick": 1.15, "posture": 0.04}},
	{"name": "GLACIOR", "title": "Frost Titan", "skin": Color(0.55, 0.62, 0.7), "belly": Color(0.85, 0.9, 0.95),
		"accent": Color(0.6, 0.9, 1.0), "eye": Color(0.8, 1.0, 1.0), "horns": true, "size": 1.05,
		"hp": 280.0, "speed": 0.95, "power": 1.05, "special": "beam", "look": {"spike_shape": 4, "rows": 2, "neck_len": 1.05, "spike_size": 1.25, "seams": true, "tail_len": 1.05}},
	{"name": "NOCTYR", "title": "Night Stalker", "skin": Color(0.12, 0.1, 0.14), "belly": Color(0.35, 0.25, 0.3),
		"accent": Color(1.0, 0.15, 0.3), "eye": Color(1.0, 0.3, 0.3), "horns": true, "size": 0.95,
		"hp": 220.0, "speed": 1.3, "power": 1.05, "special": "nova", "look": {"spike_shape": 2, "rows": 2, "neck_len": 1.25, "bulk": 0.92, "arm_size": 1.1, "head_size": 0.92, "snout": 1.25, "arm_spikes": true, "tail_len": 1.15, "tail_thick": 0.9}},
	{"name": "CORALIS", "title": "Reef Guardian", "skin": Color(0.16, 0.36, 0.38), "belly": Color(0.9, 0.6, 0.5),
		"accent": Color(0.3, 1.0, 0.8), "eye": Color(0.5, 1.0, 0.9), "horns": false, "size": 1.0,
		"hp": 270.0, "speed": 1.05, "power": 0.95, "special": "beam", "look": {"spike_shape": 0, "rows": 3, "neck_len": 1.12, "crest": true, "tail_len": 1.15, "snout": 1.08}},
	{"name": "SOLAR REX", "title": "Sun Tyrant", "skin": Color(0.45, 0.32, 0.12), "belly": Color(0.85, 0.75, 0.5),
		"accent": Color(1.0, 0.75, 0.2), "eye": Color(1.0, 0.9, 0.4), "horns": true, "size": 1.08,
		"hp": 260.0, "speed": 0.95, "power": 1.25, "special": "nova", "look": {"spike_shape": 3, "rows": 2, "neck_len": 0.95, "head_size": 1.15, "snout": 1.22, "arm_size": 0.85, "posture": 0.06}},
	{"name": "RUSTFANG", "title": "Scrapyard King", "skin": Color(0.4, 0.38, 0.38), "belly": Color(0.55, 0.3, 0.2),
		"accent": Color(1.0, 0.25, 0.1), "eye": Color(1.0, 0.4, 0.2), "horns": true, "size": 1.1,
		"hp": 320.0, "speed": 0.9, "power": 1.2, "special": "quake", "look": {"spike_shape": 1, "rows": 2, "neck_len": 0.9, "bulk": 1.1, "arm_size": 1.15, "arm_spikes": true, "gem": false, "tail_thick": 1.05}},
]

const SPECIAL_NAMES := {"beam": "Atomic Beam", "nova": "Nova Burst", "quake": "Earthquake"}

# Boss keys: moves (any Brute move plus its signature move, see Brute.SIGNATURES),
# body (CreatureModel plan; never the heroes' kaiju model), extras, horns, element, summon.
const COUNTRIES := [
	{"name": "DENMARK", "city": "Copenhagen", "landmark": "windmills",
		"sky_top": Color(0.32, 0.4, 0.52), "sky_horizon": Color(0.75, 0.75, 0.75), "ground_horizon": Color(0.5, 0.5, 0.5),
		"sun": Color(0.95, 0.92, 0.85), "sun_energy": 1.2, "sun_rot": Vector3(-35, 150, 0),
		"fill": Color(0.7, 0.75, 0.9), "fill_energy": 1.0, "ambient": 1.0, "exposure": 1.0,
		"fog": Color(0.7, 0.72, 0.75), "fog_density": 0.008, "ground": Color(0.25, 0.3, 0.22),
		"walls": [Color(0.75, 0.35, 0.25), Color(0.85, 0.75, 0.45), Color(0.45, 0.55, 0.6), Color(0.8, 0.8, 0.75)],
		"window": Color(1.0, 0.9, 0.7), "lit": 0.15, "emission": 0.6, "height": Vector2(5, 11),
		"look": {"facades": [0.15, 0.7, 0.1, 0.05], "roofs": ["gable", "gable", "mansard", "hip", "flat"],
			"roof_colors": [Color(0.32, 0.55, 0.46), Color(0.24, 0.26, 0.3), Color(0.55, 0.24, 0.17)],
			"cloud_cover": 0.85, "cloud_color": Color(0.82, 0.83, 0.86), "cloud_shade": Color(0.45, 0.47, 0.52),
			"sun_strength": 0.3, "wet": 1.0, "tree": Color(0.2, 0.34, 0.18), "skyline": 1.0,
			"grade_shadow": Color(0.0, 0.02, 0.05), "saturation": 1.05},
		"boss": {"name": "HAVTROLD", "title": "The Sea Troll", "skin": Color(0.15, 0.3, 0.32), "belly": Color(0.5, 0.6, 0.5),
			"accent": Color(0.3, 0.9, 0.8), "eye": Color(0.9, 1.0, 0.6), "body": "ape",
			"extras": ["seaweed", "crest"], "horns": false, "moves": ["swipe", "charge", "quake"]}},
	{"name": "FRANCE", "city": "Paris", "landmark": "iron_tower",
		"sky_top": Color(0.2, 0.22, 0.45), "sky_horizon": Color(1.0, 0.65, 0.4), "ground_horizon": Color(0.6, 0.4, 0.3),
		"sun": Color(1.0, 0.75, 0.5), "sun_energy": 1.6, "sun_rot": Vector3(-14, 160, 0),
		"fill": Color(0.6, 0.65, 1.0), "fill_energy": 1.2, "ambient": 0.9, "exposure": 1.05,
		"fog": Color(0.85, 0.6, 0.5), "fog_density": 0.006, "ground": Color(0.3, 0.28, 0.24),
		"walls": [Color(0.85, 0.8, 0.68), Color(0.78, 0.72, 0.6), Color(0.7, 0.68, 0.62)],
		"window": Color(1.0, 0.8, 0.5), "lit": 0.3, "emission": 1.2, "height": Vector2(7, 13),
		"look": {"facades": [0.1, 0.8, 0.05, 0.05], "roofs": ["mansard", "mansard", "mansard", "flat"],
			"roof_colors": [Color(0.36, 0.4, 0.46), Color(0.26, 0.28, 0.33)], "neon": 0.15,
			"cloud_cover": 0.4, "cloud_color": Color(1.0, 0.72, 0.52), "cloud_shade": Color(0.42, 0.3, 0.42),
			"tree": Color(0.24, 0.32, 0.16), "skyline": 1.1, "grade_shadow": Color(0.03, 0.0, 0.06)},
		"boss": {"name": "GARGOUILLE", "title": "Stone Watcher", "skin": Color(0.4, 0.4, 0.42), "belly": Color(0.6, 0.58, 0.55),
			"accent": Color(0.6, 0.8, 1.0), "eye": Color(1.0, 0.3, 0.2), "body": "ape", "extras": ["wings"], "moves": ["swipe", "leap", "dive"]}},
	{"name": "USA", "city": "New York", "landmark": "spires",
		"sky_top": Color(0.03, 0.04, 0.12), "sky_horizon": Color(0.25, 0.2, 0.4), "ground_horizon": Color(0.1, 0.1, 0.15),
		"sun": Color(0.6, 0.7, 1.0), "sun_energy": 0.5, "sun_rot": Vector3(-40, 140, 0),
		"fill": Color(0.5, 0.55, 0.9), "fill_energy": 0.9, "ambient": 0.6, "exposure": 1.2,
		"fog": Color(0.2, 0.18, 0.3), "fog_density": 0.007, "ground": Color(0.12, 0.12, 0.14),
		"walls": [Color(0.3, 0.32, 0.38), Color(0.4, 0.38, 0.36), Color(0.25, 0.27, 0.32)],
		"window": Color(1.0, 0.85, 0.55), "lit": 0.35, "emission": 1.5, "height": Vector2(10, 24),
		"look": {"night": true, "neon": 0.55, "facades": [0.3, 0.1, 0.25, 0.35],
			"roofs": ["flat", "tank", "tank", "crown", "helipad", "flat"], "roof_colors": [Color(0.3, 0.3, 0.32)],
			"cloud_cover": 0.35, "cloud_color": Color(0.16, 0.14, 0.24), "cloud_shade": Color(0.05, 0.05, 0.1),
			"city_glow": Color(0.28, 0.16, 0.12), "stars": 0.5, "shop": 1.6, "skyline": 1.7,
			"tree": Color(0.12, 0.2, 0.12), "grade_shadow": Color(0.0, 0.01, 0.05)},
		"boss": {"name": "IRONCLAW", "title": "Steel Colossus", "skin": Color(0.3, 0.32, 0.35), "belly": Color(0.5, 0.45, 0.4),
			"accent": Color(1.0, 0.3, 0.2), "eye": Color(1.0, 0.2, 0.1), "body": "mech", "element": "plasma", "summon": "soldier", "moves": ["swipe", "charge", "summon", "barrage"]}},
	{"name": "BRAZIL", "city": "Rio de Janeiro", "landmark": "sugarloaf",
		"sky_top": Color(0.2, 0.45, 0.85), "sky_horizon": Color(0.75, 0.85, 0.95), "ground_horizon": Color(0.4, 0.5, 0.4),
		"sun": Color(1.0, 0.95, 0.85), "sun_energy": 2.0, "sun_rot": Vector3(-55, 150, 0),
		"fill": Color(0.7, 0.8, 1.0), "fill_energy": 1.0, "ambient": 1.0, "exposure": 0.95,
		"fog": Color(0.75, 0.85, 0.9), "fog_density": 0.004, "ground": Color(0.3, 0.42, 0.22),
		"walls": [Color(0.95, 0.85, 0.4), Color(0.4, 0.75, 0.6), Color(0.95, 0.55, 0.45), Color(0.9, 0.9, 0.85)],
		"window": Color(1.0, 0.95, 0.85), "lit": 0.05, "emission": 0.3, "height": Vector2(6, 16),
		"look": {"facades": [0.35, 0.3, 0.25, 0.1], "roofs": ["flat", "flat", "tank", "helipad"],
			"roof_colors": [Color(0.6, 0.35, 0.25)], "cloud_cover": 0.3, "cloud_color": Color(1, 1, 1),
			"cloud_shade": Color(0.62, 0.7, 0.82), "tree": Color(0.15, 0.4, 0.15), "skyline": 1.2, "saturation": 1.18},
		"boss": {"name": "JAGUARON", "title": "Jungle Fury", "skin": Color(0.6, 0.45, 0.15), "belly": Color(0.85, 0.75, 0.5),
			"accent": Color(0.3, 1.0, 0.3), "eye": Color(0.6, 1.0, 0.2), "body": "quad", "horns": false, "extras": ["crest"], "moves": ["swipe", "leap", "charge", "frenzy"]}},
	{"name": "EGYPT", "city": "Cairo", "landmark": "pyramids",
		"sky_top": Color(0.3, 0.5, 0.8), "sky_horizon": Color(0.95, 0.85, 0.65), "ground_horizon": Color(0.8, 0.65, 0.45),
		"sun": Color(1.0, 0.92, 0.75), "sun_energy": 2.2, "sun_rot": Vector3(-60, 160, 0),
		"fill": Color(0.9, 0.8, 0.7), "fill_energy": 0.8, "ambient": 1.0, "exposure": 0.9,
		"fog": Color(0.9, 0.8, 0.6), "fog_density": 0.007, "ground": Color(0.75, 0.62, 0.42),
		"walls": [Color(0.85, 0.75, 0.55), Color(0.75, 0.62, 0.45), Color(0.9, 0.85, 0.7)],
		"window": Color(1.0, 0.85, 0.6), "lit": 0.08, "emission": 0.4, "height": Vector2(5, 12),
		"look": {"facades": [0.2, 0.7, 0.05, 0.05], "roofs": ["flat", "flat", "tank", "dome"],
			"roof_colors": [Color(0.75, 0.62, 0.42), Color(0.3, 0.55, 0.5)], "roof_flat": Color(0.62, 0.55, 0.45),
			"cloud_cover": 0.12, "cloud_color": Color(1.0, 0.97, 0.9), "cloud_shade": Color(0.8, 0.72, 0.62),
			"tree": Color(0.3, 0.42, 0.16), "skyline": 1.0, "grade_shadow": Color(0.04, 0.02, 0.0)},
		"boss": {"name": "SPHINXAR", "title": "Riddle of Sand", "skin": Color(0.7, 0.55, 0.3), "belly": Color(0.85, 0.75, 0.5),
			"accent": Color(1.0, 0.8, 0.2), "eye": Color(0.3, 0.8, 1.0), "body": "quad", "extras": ["crest", "nose_horn"], "moves": ["swipe", "breath", "slam", "sandstorm"]}},
	{"name": "INDIA", "city": "Mumbai", "landmark": "temple",
		"sky_top": Color(0.35, 0.25, 0.5), "sky_horizon": Color(1.0, 0.55, 0.45), "ground_horizon": Color(0.6, 0.4, 0.35),
		"sun": Color(1.0, 0.6, 0.45), "sun_energy": 1.5, "sun_rot": Vector3(-12, 150, 0),
		"fill": Color(0.8, 0.6, 0.9), "fill_energy": 1.1, "ambient": 0.9, "exposure": 1.05,
		"fog": Color(0.9, 0.6, 0.55), "fog_density": 0.01, "ground": Color(0.4, 0.3, 0.22),
		"walls": [Color(0.9, 0.6, 0.4), Color(0.85, 0.85, 0.75), Color(0.6, 0.75, 0.8), Color(0.9, 0.5, 0.55)],
		"window": Color(1.0, 0.75, 0.45), "lit": 0.3, "emission": 1.2, "height": Vector2(6, 15),
		"look": {"neon": 0.3, "facades": [0.35, 0.45, 0.1, 0.1], "roofs": ["flat", "tank", "dome", "flat"],
			"roof_colors": [Color(0.85, 0.65, 0.3), Color(0.7, 0.4, 0.3)], "cloud_cover": 0.45,
			"cloud_color": Color(1.0, 0.62, 0.55), "cloud_shade": Color(0.4, 0.28, 0.45), "shop": 1.0,
			"tree": Color(0.18, 0.32, 0.14), "skyline": 1.3},
		"boss": {"name": "NAGARAJ", "title": "Serpent King", "skin": Color(0.2, 0.35, 0.2), "belly": Color(0.75, 0.7, 0.35),
			"accent": Color(1.0, 0.85, 0.2), "eye": Color(1.0, 0.4, 0.8), "body": "serpent", "element": "venom", "extras": ["hood", "crest"], "moves": ["swipe", "breath", "summon", "lunge", "venom_rain"]}},
	{"name": "AUSTRALIA", "city": "Sydney", "landmark": "sails",
		"sky_top": Color(0.25, 0.5, 0.85), "sky_horizon": Color(0.95, 0.8, 0.7), "ground_horizon": Color(0.5, 0.55, 0.6),
		"sun": Color(1.0, 0.88, 0.7), "sun_energy": 1.8, "sun_rot": Vector3(-30, 125, 0),
		"fill": Color(0.6, 0.75, 1.0), "fill_energy": 1.0, "ambient": 1.0, "exposure": 0.95,
		"fog": Color(0.75, 0.8, 0.9), "fog_density": 0.005, "ground": Color(0.35, 0.4, 0.3),
		"walls": [Color(0.8, 0.82, 0.85), Color(0.55, 0.6, 0.7), Color(0.75, 0.65, 0.55)],
		"window": Color(0.9, 0.95, 1.0), "lit": 0.1, "emission": 0.5, "height": Vector2(8, 20),
		"look": {"facades": [0.3, 0.15, 0.45, 0.1], "roofs": ["flat", "helipad", "crown", "flat"],
			"roof_colors": [Color(0.4, 0.4, 0.42)], "cloud_cover": 0.25, "cloud_color": Color(1.0, 0.95, 0.92),
			"cloud_shade": Color(0.6, 0.62, 0.75), "tree": Color(0.25, 0.38, 0.2), "skyline": 1.4},
		"boss": {"name": "CROCODON", "title": "Harbour Terror", "skin": Color(0.25, 0.32, 0.15), "belly": Color(0.65, 0.6, 0.4),
			"accent": Color(0.9, 0.9, 0.3), "eye": Color(1.0, 0.8, 0.1), "body": "quad", "extras": ["snout", "tail_club"], "moves": ["swipe", "charge", "slam", "lunge", "sweep"]}},
	{"name": "RUSSIA", "city": "Moscow", "landmark": "domes",
		"sky_top": Color(0.15, 0.18, 0.35), "sky_horizon": Color(0.7, 0.55, 0.6), "ground_horizon": Color(0.6, 0.6, 0.65),
		"sun": Color(1.0, 0.7, 0.55), "sun_energy": 1.0, "sun_rot": Vector3(-10, 165, 0),
		"fill": Color(0.6, 0.7, 1.0), "fill_energy": 1.2, "ambient": 0.9, "exposure": 1.0,
		"fog": Color(0.7, 0.7, 0.8), "fog_density": 0.012, "ground": Color(0.85, 0.87, 0.92),
		"walls": [Color(0.75, 0.3, 0.25), Color(0.85, 0.82, 0.75), Color(0.5, 0.55, 0.5), Color(0.9, 0.85, 0.6)],
		"window": Color(1.0, 0.8, 0.5), "lit": 0.3, "emission": 0.9, "height": Vector2(7, 16),
		"look": {"neon": 0.15, "facades": [0.2, 0.6, 0.05, 0.15], "roofs": ["flat", "hip", "gable", "crown"],
			"roof_colors": [Color(0.24, 0.42, 0.32), Color(0.45, 0.18, 0.16)], "snow": 1.0,
			"cloud_cover": 0.6, "cloud_color": Color(0.95, 0.75, 0.75), "cloud_shade": Color(0.4, 0.38, 0.52),
			"tree": Color(0.12, 0.22, 0.16), "skyline": 1.3, "grade_shadow": Color(0.0, 0.01, 0.05)},
		"boss": {"name": "MAMMOTHRAX", "title": "Winter Behemoth", "skin": Color(0.4, 0.3, 0.25), "belly": Color(0.6, 0.55, 0.5),
			"accent": Color(0.6, 0.9, 1.0), "eye": Color(0.6, 0.9, 1.0), "body": "ape", "extras": ["fur", "crystals"], "moves": ["swipe", "slam", "charge", "breath", "hurl", "quake"]}},
	{"name": "ICELAND", "city": "Reykjavik", "landmark": "volcano",
		"sky_top": Color(0.02, 0.08, 0.12), "sky_horizon": Color(0.1, 0.45, 0.35), "ground_horizon": Color(0.1, 0.15, 0.18),
		"sun": Color(0.5, 1.0, 0.75), "sun_energy": 0.6, "sun_rot": Vector3(-30, 150, 0),
		"fill": Color(0.5, 0.65, 1.0), "fill_energy": 0.9, "ambient": 0.7, "exposure": 1.2,
		"fog": Color(0.15, 0.3, 0.3), "fog_density": 0.009, "ground": Color(0.75, 0.8, 0.85),
		"walls": [Color(0.85, 0.85, 0.85), Color(0.75, 0.3, 0.25), Color(0.3, 0.45, 0.6)],
		"window": Color(1.0, 0.85, 0.6), "lit": 0.35, "emission": 1.3, "height": Vector2(4, 10),
		"look": {"night": true, "neon": 0.12, "facades": [0.1, 0.8, 0.05, 0.05], "roofs": ["gable", "gable", "hip", "flat"],
			"roof_colors": [Color(0.7, 0.18, 0.15), Color(0.2, 0.35, 0.6), Color(0.2, 0.45, 0.35)], "snow": 1.0,
			"cloud_cover": 0.2, "cloud_color": Color(0.1, 0.18, 0.2), "cloud_shade": Color(0.02, 0.05, 0.07),
			"stars": 1.0, "city_glow": Color(0.12, 0.1, 0.06), "shop": 1.2, "tree": Color(0.1, 0.2, 0.15), "skyline": 0.9},
		"boss": {"name": "SURTUR", "title": "Lord of Lava", "skin": Color(0.15, 0.1, 0.1), "belly": Color(0.5, 0.2, 0.1),
			"accent": Color(1.0, 0.35, 0.05), "eye": Color(1.0, 0.6, 0.1), "body": "golem", "moves": ["breath", "slam", "leap", "summon", "swipe", "hurl", "meteor"]}},
	{"name": "JAPAN", "city": "Tokyo", "landmark": "radio_tower",
		"sky_top": Color(0.05, 0.02, 0.12), "sky_horizon": Color(0.45, 0.15, 0.4), "ground_horizon": Color(0.12, 0.08, 0.15),
		"sun": Color(0.9, 0.5, 0.9), "sun_energy": 0.6, "sun_rot": Vector3(-35, 150, 0),
		"fill": Color(0.5, 0.6, 1.0), "fill_energy": 1.0, "ambient": 0.6, "exposure": 1.2,
		"fog": Color(0.3, 0.12, 0.3), "fog_density": 0.008, "ground": Color(0.1, 0.1, 0.12),
		"walls": [Color(0.3, 0.3, 0.35), Color(0.45, 0.42, 0.45), Color(0.25, 0.25, 0.3)],
		"window": Color(1.0, 0.5, 0.85), "lit": 0.3, "emission": 1.4, "height": Vector2(10, 22),
		"look": {"night": true, "neon": 1.0, "facades": [0.45, 0.1, 0.3, 0.15], "roofs": ["flat", "helipad", "crown", "flat", "tank"],
			"roof_colors": [Color(0.3, 0.3, 0.32)], "cloud_cover": 0.5, "cloud_color": Color(0.3, 0.12, 0.3),
			"cloud_shade": Color(0.06, 0.03, 0.1), "city_glow": Color(0.4, 0.1, 0.32), "stars": 0.15, "shop": 2.0,
			"neon_colors": [Color(1.0, 0.2, 0.55), Color(0.2, 0.85, 1.0), Color(1.0, 0.7, 0.15), Color(0.65, 0.35, 1.0), Color(0.3, 1.0, 0.5)],
			"tree": Color(0.12, 0.2, 0.14), "skyline": 1.6, "grade_shadow": Color(0.02, 0.0, 0.05)},
		"boss": {"name": "RYUJIN PRIME", "title": "The Last Dragon", "skin": Color(0.08, 0.1, 0.12), "belly": Color(0.35, 0.3, 0.35),
			"accent": Color(0.8, 0.3, 1.0), "eye": Color(1.0, 0.2, 0.5), "body": "serpent",
			"extras": ["whiskers", "crest", "fins"], "moves": ["swipe", "charge", "slam", "breath", "summon", "leap", "storm"]}},
]


static func hero(i: int) -> Dictionary:
	return HEROES[clampi(i, 0, HEROES.size() - 1)]


static func country(i: int) -> Dictionary:
	return COUNTRIES[clampi(i, 0, COUNTRIES.size() - 1)]


## Boss stats grow with each country.
static func boss(country_idx: int) -> Dictionary:
	var b: Dictionary = country(country_idx)["boss"].duplicate()
	b["hp"] = 700.0 + country_idx * 160.0
	b["scale"] = 1.9 + country_idx * 0.05
	b["dmg"] = 16.0 + country_idx * 1.6
	b["speed"] = 4.8 + country_idx * 0.15
	b["cooldown"] = maxf(0.6, 1.6 - country_idx * 0.08)
	return b


## Builds level `level_idx` (0-9) of country `country_idx` (0-9). Same input,
## same level. Level 10 of each country ends with that country's boss;
## levels 5 and 8 end with an elite.
static func level(country_idx: int, level_idx: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + country_idx * 101 + level_idx * 13
	var d := country_idx * LEVELS_PER_COUNTRY + level_idx
	var is_boss := level_idx == LEVELS_PER_COUNTRY - 1
	var wave_count := 3 if is_boss else 2 + level_idx / 4
	var waves: Array = []
	var x := 35.0
	var pool := Enemies.pool(country_idx, level_idx)
	for w in wave_count:
		var spawn: Array = []
		if is_boss and w == wave_count - 1:
			spawn = ["boss"]
			var support := 1 if country_idx < 5 else 2
			for i in support:
				spawn.append(_pick_small(rng, pool))
		else:
			# Spend a threat budget on enemies from this level's pool. The
			# types this level introduces are guaranteed in wave 1.
			var budget := minf(1.5 * (2.0 + d / 18.0 + rng.randf() + w * 0.5), 11.0)
			if w == 0:
				for id in Enemies.introduced(country_idx, level_idx):
					budget -= _add(spawn, id)
			var guard := 0
			while budget > 0.3 and spawn.size() < 14 and guard < 24:
				guard += 1
				var id := Enemies.pick(rng, pool)
				# Every wave leads with something on the ground.
				if spawn.is_empty() and Enemies.get_def(id)["class"] == "air":
					continue
				var cost: float = float(Enemies.get_def(id)["cost"]) * Enemies.get_def(id).get("group", 1)
				if cost > budget + 0.8 and not spawn.is_empty():
					continue
				budget -= _add(spawn, id)
			if w == wave_count - 1 and (level_idx == 4 or level_idx == 7):
				spawn.append("elite")
		var title := "BOSS" if (is_boss and w == wave_count - 1) else "WAVE %d" % (w + 1)
		waves.append({"x": x, "title": title, "spawn": spawn})
		x += rng.randf_range(55.0, 70.0)
	return {
		"country": country_idx,
		"index": level_idx,
		"global": d,
		"title": "%s %d-%d" % [country(country_idx)["city"].to_upper(), country_idx + 1, level_idx + 1],
		"waves": waves,
		"length": x - 30.0,
		"hp_mul": 1.0 + d * 0.035,
		"dmg_mul": 1.0 + d * 0.012,
		"seed": rng.seed,
	}


## Appends `id` (as many times as its group size) and returns its threat cost.
static func _add(spawn: Array, id: String) -> float:
	var def := Enemies.get_def(id)
	var n: int = def.get("group", 1)
	for i in n:
		spawn.append(id)
	return float(def["cost"]) * n


## A cheap support enemy for boss waves (air units preferred).
static func _pick_small(rng: RandomNumberGenerator, pool: Array) -> String:
	var small := pool.filter(func(e: Array) -> bool:
		return float(Enemies.get_def(e[0])["cost"]) <= 2.0 and Enemies.get_def(e[0]).get("group", 1) == 1)
	if small.is_empty():
		return "drone"
	return Enemies.pick(rng, small)
