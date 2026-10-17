class_name SuperTree
extends RefCounted
## Each hero's small super tree: every TIER_EVERY levels a new tier opens,
## and in each tier the player picks one of two or three options that change
## how the hero's super special plays (see Player._state_super). A pick can
## be swapped at any time; only one option per tier is ever active.

const TIER_EVERY := 5
const TIERS := 5

## What every effect does. Options take the text from here unless they bring
## their own (heroes give the shared effects their own flavour).
const EFFECTS := {
	# Tier 1, riders on every super hit.
	"burn": "Super hits set enemies on fire",
	"chill": "Super hits slow enemies by 50% for 3 seconds",
	"venom": "Super hits poison enemies for 8 seconds",
	"stun": "Super hits freeze enemies in place for a moment",
	"rage": "Every super hit gives 3 rage",
	"leech": "The super heals 10% of the damage it deals",
	"power": "+25% super damage",
	# Tier 2, what happens where the super lands.
	"shatter": "Every impact bursts into shards that fly out and hit again",
	"erupt": "Every impact leaves a zone on the street that keeps hurting",
	"chain": "Every impact arcs lightning on to two more enemies",
	"frag_air": "Every meteor splits into three in mid-air",
	"bounce": "Meteors bounce on along the street and hit twice more",
	# Tier 3, before and after the super.
	"refund": "The super gives back 30% of its meter",
	"shield": "After the super a shield blocks the next hit and you heal 15%",
	"rage_full": "The super fills your rage to the top",
	"finale": "The super ends with a blast all around you",
	"pull": "The super drags every enemy close before it starts",
	"long": "The super lasts 40% longer",
	# Tiers 4-5, per super (see the options).
	"beam_turn": "", "beam_sky": "", "beam_core": "",
	"bolt_big": "", "bolt_giant": "", "storm_all": "",
	"rain_more": "", "rain_big": "", "giant": "", "magnet": "",
	"vortex_twin": "", "vortex_drift": "", "vortex_collapse": "", "vortex_pulse": "",
	"rift_forward": "", "rift_return": "", "rift_split": "", "rift_pillars": "",
	"freeze_twice": "", "freeze_deep": "", "freeze_hail": "", "freeze_age": "",
	"slash_more": "", "slash_heavy": "", "slash_clones": "", "slash_eclipse": "",
	"wave_double": "", "wave_undertow": "", "wave_tsunami": "", "wave_whirlpool": "",
	"nova_pulse": "", "nova_flare": "", "nova_bang": "", "nova_corona": "",
}

## Per hero (same order as Content.HEROES), its tiers top to bottom; each
## option is [name, effect] or [name, effect, own description]. Saves store
## the picked option's index per tier, so options keep their order.
const HEROES := [
	[  # GORRAX, OMEGA BREATH
		[["Isotope Fire", "burn", "Omega Breath sets enemies on fire"],
			["Radiation Sickness", "chill", "Omega Breath slows enemies by 50% for 3 seconds"],
			["Charged Breath", "rage"]],
		[["Fission Sparks", "shatter", "The breath splits atoms: shards fly off every enemy it burns"],
			["Hot Zone", "erupt", "The breath leaves glowing radioactive ground behind"],
			["Arc Discharge", "chain", "The breath arcs lightning from the enemies it hits"]],
		[["Reactor Vent", "refund"], ["King's Rest", "shield"]],
		[["Turn and Burn", "beam_turn", "The breath lasts longer and halfway through Gorrax turns to burn the other side"],
			["Endless Breath", "long", "Omega Breath lasts 40% longer"]],
		[["Orbital Ray", "beam_sky", "The breath becomes a ray from the sky that sweeps along the street"],
			["Critical Core", "beam_core", "The breath ends in a huge atomic blast around Gorrax"]],
	],
	[  # VOLTRA, THUNDERSTORM
		[["Static Paralysis", "stun", "Bolts freeze enemies in place for a moment"],
			["Overcharge", "rage", "Every bolt gives 3 rage"],
			["Ion Burn", "burn", "Bolts set enemies on fire"]],
		[["Forked Bolts", "chain", "Every bolt forks on to two more enemies"],
			["Ball Lightning", "shatter", "Every bolt throws out balls of lightning that hit again"],
			["Charged Ground", "erupt", "Every bolt leaves the street crackling with power"]],
		[["Eye of the Storm", "pull"], ["Capacitor", "refund"], ["Lightning Rod", "shield"]],
		[["Thunderheads", "bolt_big", "Fewer bolts, but each is twice as big and twice as strong"],
			["Long Storm", "long", "The storm rages 40% longer"]],
		[["Wrath of Heaven", "bolt_giant", "The storm ends with one colossal bolt"],
			["Supercell", "storm_all", "Every bolt strikes all enemies under the cloud at once"]],
	],
	[  # MAGMOS, MAGMA RAIN
		[["Molten Rock", "burn", "Meteors set enemies on fire"],
			["Ash Fall", "chill", "Meteors bury enemies in ash: 50% slower for 3 seconds"],
			["Hot Blood", "leech", "Magma Rain heals 10% of the damage it deals"]],
		[["Air Burst", "frag_air", "Every meteor splits into three in mid-air"],
			["Bouncing Boulders", "bounce", "Meteors bounce on along the street and hit twice more"],
			["Shatter Stone", "shatter", "Meteors burst into burning shards when they hit the ground"]],
		[["Volcanic Heart", "rage_full", "Magma Rain fills your rage to the top"],
			["Pressure Release", "finale", "Magma Rain ends with an eruption all around Magmos"]],
		[["Meteor Shower", "rain_more", "Twice as many meteors, but smaller"],
			["Boulder Rain", "rain_big", "Fewer meteors, but each is huge"],
			["Lava Pools", "erupt", "Every meteor leaves a pool of lava that keeps burning"]],
		[["Extinction", "giant", "One gigantic meteor instead of the rain"],
			["Endless Eruption", "long", "Magma Rain lasts 40% longer"]],
	],
	[  # SYLVARA, SINGULARITY
		[["Toxic Matter", "venom", "The singularity poisons enemies for 8 seconds"],
			["Time Dilation", "chill", "The singularity slows enemies by 50% for 3 seconds"],
			["Void Feast", "leech", "The singularity heals 10% of the damage it deals"]],
		[["Star Shards", "shatter", "The collapse throws out shards of dead stars"],
			["Spore Nebula", "erupt", "The collapse leaves a poison cloud behind"],
			["Dark Current", "chain", "The collapse arcs void lightning on to more enemies"]],
		[["Event Horizon", "pull"], ["Cosmic Flow", "refund"]],
		[["Binary Holes", "vortex_twin", "Two singularities open, one on each side of Sylvara"],
			["Wandering Void", "vortex_drift", "The singularity drifts down the street, swallowing as it goes"]],
		[["Big Crunch", "vortex_collapse", "A far bigger hole: it pulls from further and blows up much harder"],
			["Pulsar", "vortex_pulse", "Instead of one blast at the end, the hole bursts again and again"]],
	],
	[  # TERRAXA, TECTONIC RIFT
		[["Crushing Stone", "stun", "The rift pins enemies in place for a moment"],
			["Old Grudge", "rage", "Every rift hit gives 3 rage"],
			["Earth Drink", "leech", "The rift heals 10% of the damage it deals"]],
		[["Crystal Burst", "shatter", "Crystals burst out of the crack and fly at enemies"],
			["Magma Seam", "erupt", "The crack keeps glowing and burns whoever stands on it"],
			["Geomagnetic", "chain", "The rift arcs lightning on to more enemies"]],
		[["Mountain Ward", "shield"], ["Aftershock", "finale"], ["Gravity Well", "pull"]],
		[["Fault Line", "rift_forward", "The rift only runs forward, but twice as far and harder"],
			["Closing Rift", "rift_return", "The rift runs out, then slams shut back toward Terraxa"]],
		[["Continental Split", "rift_split", "The whole street splits and throws every enemy in sight"],
			["Stone Pillars", "rift_pillars", "Stone pillars shoot up under enemies as the rift runs"]],
	],
	[  # GLACIOR, ABSOLUTE ZERO
		[["Frostbite", "chill", "Enemies stay 50% slower for 3 seconds after they thaw"],
			["Cold Fury", "rage", "Every frozen enemy hit gives 3 rage"],
			["Ice Power", "power", "+25% Absolute Zero damage"]],
		[["Ice Shrapnel", "shatter", "Shattering ice blocks throw shards at other enemies"],
			["Frozen Ground", "erupt", "The street freezes over and keeps hurting enemies on it"],
			["Cold Snap", "chain", "Shattering ice arcs frost on to two more enemies"]],
		[["Glacier Heart", "shield"], ["Cold Blood", "refund"]],
		[["Flash Freeze", "freeze_twice", "Freezes and shatters twice, a bit weaker each time"],
			["Deep Freeze", "freeze_deep", "Shatters 40% harder and leaves enemies frozen to the bone"]],
		[["Hailstorm", "freeze_hail", "Hailstones pound the frozen enemies before they shatter"],
			["Ice Age", "freeze_age", "Freezes everything on the whole screen and hits harder"]],
	],
	[  # NOCTYR, SHADOW FRENZY
		[["Hemorrhage", "venom", "Slashes make enemies bleed for 8 seconds"],
			["Bloodlust", "leech", "Shadow Frenzy heals 10% of the damage it deals"],
			["Dread", "stun", "Slashes freeze enemies in fear for a moment"]],
		[["Blood Spray", "shatter", "Every slash sprays blades of blood at nearby enemies"],
			["Shadow Pools", "erupt", "Every slash leaves a pool of shadow that keeps cutting"],
			["Pack Hunt", "chain", "Every slash jumps on to two more enemies"]],
		[["Night Feast", "rage_full", "Shadow Frenzy fills your rage to the top"],
			["Blood Moon", "refund"]],
		[["Thousand Cuts", "slash_more", "Many more, faster slashes, each a bit weaker"],
			["Executioner", "slash_heavy", "Fewer slashes, but each hits much harder"]],
		[["Shadow Clones", "slash_clones", "Shadow clones strike every enemy you slashed again at the end"],
			["Eclipse", "slash_eclipse", "The last slash cuts every enemy in sight"]],
	],
	[  # CORALIS, TIDAL WAVE
		[["Cold Current", "chill", "The wave slows enemies by 50% for 3 seconds"],
			["Healing Tide", "leech", "The wave heals 10% of the damage it deals"],
			["Jellyfish", "venom", "The wave stings enemies with poison for 8 seconds"]],
		[["Sea Spray", "shatter", "The wave throws out shards of coral that hit again"],
			["Tide Pools", "erupt", "The wave leaves churning pools that keep hurting"],
			["Electric Eels", "chain", "Eels in the wave shock two more enemies"]],
		[["Riptide", "pull"], ["Bubble Ward", "shield"], ["Moon Tide", "refund"]],
		[["Double Wave", "wave_double", "A second wave rolls the other way, behind Coralis"],
			["Undertow", "wave_undertow", "The wave drags enemies back toward Coralis instead of away"]],
		[["Tsunami", "wave_tsunami", "A far bigger, wider wave that hits 50% harder"],
			["Maelstrom", "wave_whirlpool", "The wave ends in a whirlpool that pulls in and drowns enemies"]],
	],
	[  # SOLAR REX, SUPERNOVA
		[["Solar Fire", "burn", "Supernova sets enemies on fire"],
			["Blinding Light", "stun", "The blasts blind enemies and freeze them for a moment"],
			["Sun Power", "power", "+25% Supernova damage"]],
		[["Solar Shards", "shatter", "Every blast throws out shards of sunfire"],
			["Sunspots", "erupt", "Every blast leaves burning sunspots on the street"],
			["Solar Arcs", "chain", "Every blast arcs fire on to two more enemies"]],
		[["Zenith", "refund"], ["Tyrant's Roar", "rage_full", "Supernova fills your rage to the top"]],
		[["Pulsing Star", "nova_pulse", "Twice as many blasts, each a little smaller"],
			["Solar Flares", "nova_flare", "Every blast also shoots flares far down the street"]],
		[["Big Bang", "nova_bang", "The last blast is a giant one that reaches the whole screen"],
			["Corona", "nova_corona", "After the super, a corona burns around Solar Rex for 6 seconds"]],
	],
	[  # RUSTFANG, SCRAP BARRAGE
		[["Red-Hot Scrap", "burn", "Scrap sets enemies on fire"],
			["Heavy Metal", "stun", "Scrap pins enemies in place for a moment"],
			["Recycler", "rage", "Every scrap hit gives 3 rage"]],
		[["Cluster Bombs", "frag_air", "Every piece of scrap splits into three in mid-air"],
			["Ricochet", "bounce", "Scrap bounces on along the street and hits twice more"],
			["Shrapnel", "shatter", "Scrap bursts into shrapnel when it hits the ground"]],
		[["Spare Parts", "shield"], ["Overclock", "refund"], ["Junk Rage", "rage_full", "Scrap Barrage fills your rage to the top"]],
		[["Magnet Scrap", "magnet", "Every piece of scrap drags nearby enemies in before it lands"],
			["Junk Storm", "rain_more", "Twice as much scrap, but smaller"]],
		[["Junk Titan", "giant", "One gigantic heap of scrap crashes down instead of the barrage"],
			["Assembly Line", "long", "Scrap Barrage lasts 40% longer"]],
	],
]


static func tier_level(tier: int) -> int:
	return (tier + 1) * TIER_EVERY


## Tiers open at a hero level.
static func tiers_open(lvl: int) -> int:
	return clampi(floori(lvl / float(TIER_EVERY)), 0, TIERS)


static func options(hero: int, tier: int) -> Array:
	return HEROES[hero][tier]


## Returns {name, effect, desc} for one option.
static func option(hero: int, tier: int, idx: int) -> Dictionary:
	var a: Array = HEROES[hero][tier][idx]
	return {"name": a[0], "effect": a[1], "desc": a[2] if a.size() > 2 else String(EFFECTS[a[1]])}


## A hero with nothing picked: -1 per tier.
static func empty_picks() -> Array:
	var p := []
	p.resize(TIERS)
	p.fill(-1)
	return p


## The effects a hero's picks switch on at its level: {effect: true}.
static func mods(hero: int, picks: Array, lvl: int) -> Dictionary:
	var out := {}
	for t in mini(tiers_open(lvl), picks.size()):
		var i := int(picks[t])
		if i >= 0 and i < options(hero, t).size():
			out[option(hero, t, i)["effect"]] = true
	return out
