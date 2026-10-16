class_name HeroMoves
extends RefCounted
## Every hero's own way of fighting, as data (indexed like Content.HEROES).
## The buttons and combos are the same for everyone, but each hero hits at
## its own pace and every combo is its own move in the hero's element (see
## RageStyle for the element and RageFX.erupt for how it bursts out).
##
##   style   one line on how the hero fights (shown on the hero card)
##   tempo   attack speed: >1 faster punches and combos, <1 slower
##   dmg     damage of normal attacks and combos (slower heroes hit harder)
##   reach   extra reach of punches and slams (long arms, claws, water)
##   kb      knockback of normal attacks and combos
##   bdmg    damage to buildings
##   combos  the hero's name for each combo special:
##           light3 (light x3), rush (light light heavy), heavy3 (heavy x3),
##           sky_claw (jump + light), pound (jump + heavy, the ground stomp)

const MOVES := [
	# GORRAX: the all-rounder, atomic blue.
	{"style": "Balanced brawler", "tempo": 1.0, "dmg": 1.0, "reach": 0.0, "kb": 1.0, "bdmg": 1.0,
		"combos": {"light3": "ATOMIC SPIN", "rush": "REACTOR RUSH", "heavy3": "MELTDOWN CRUSH",
			"sky_claw": "ION CLAW", "pound": "ATOM STOMP"}},
	# VOLTRA: lightning fast, light hits that stun.
	{"style": "Lightning-fast strikes", "tempo": 1.22, "dmg": 0.86, "reach": 0.0, "kb": 0.9, "bdmg": 0.9,
		"combos": {"light3": "STATIC SPIN", "rush": "BOLT RUSH", "heavy3": "THUNDER CRUSH",
			"sky_claw": "SKY BOLT", "pound": "THUNDER STOMP"}},
	# MAGMOS: slow, heavy, burning blows.
	{"style": "Slow, burning blows", "tempo": 0.9, "dmg": 1.12, "reach": 0.0, "kb": 1.05, "bdmg": 1.15,
		"combos": {"light3": "MAGMA SPIN", "rush": "LAVA RUSH", "heavy3": "VOLCANO CRUSH",
			"sky_claw": "CINDER CLAW", "pound": "MAGMA STOMP"}},
	# SYLVARA: quick vine lashes with long reach.
	{"style": "Long, quick vine lashes", "tempo": 1.1, "dmg": 0.92, "reach": 0.6, "kb": 0.9, "bdmg": 0.9,
		"combos": {"light3": "THORN SPIN", "rush": "VENOM RUSH", "heavy3": "BLIGHT CRUSH",
			"sky_claw": "SPORE CLAW", "pound": "TOXIC STOMP"}},
	# TERRAXA: the slowest and hardest hitter, sends everything flying.
	{"style": "Slow, crushing rock fists", "tempo": 0.84, "dmg": 1.22, "reach": 0.0, "kb": 1.3, "bdmg": 1.35,
		"combos": {"light3": "BOULDER SPIN", "rush": "AVALANCHE RUSH", "heavy3": "TECTONIC CRUSH",
			"sky_claw": "CRYSTAL CLAW", "pound": "CRYSTAL STOMP"}},
	# GLACIOR: steady, icy blows that slow enemies.
	{"style": "Steady, freezing blows", "tempo": 0.96, "dmg": 1.04, "reach": 0.3, "kb": 1.0, "bdmg": 1.0,
		"combos": {"light3": "BLIZZARD SPIN", "rush": "GLACIER SLIDE", "heavy3": "GLACIER CRUSH",
			"sky_claw": "FROST CLAW", "pound": "FROST STOMP"}},
	# NOCTYR: fast slashing claws with long reach.
	{"style": "Fast, slashing claws", "tempo": 1.15, "dmg": 0.9, "reach": 0.5, "kb": 0.85, "bdmg": 0.85,
		"combos": {"light3": "SHADOW SPIN", "rush": "BLOOD RUSH", "heavy3": "NIGHTFALL CRUSH",
			"sky_claw": "BAT CLAW", "pound": "ECLIPSE STOMP"}},
	# CORALIS: blows like breaking waves that wash enemies far away.
	{"style": "Waves that wash foes away", "tempo": 1.0, "dmg": 0.95, "reach": 0.4, "kb": 1.35, "bdmg": 1.0,
		"combos": {"light3": "WHIRLPOOL SPIN", "rush": "TIDAL RUSH", "heavy3": "TSUNAMI CRUSH",
			"sky_claw": "SPRAY CLAW", "pound": "SPLASH STOMP"}},
	# SOLAR REX: big, blazing hits.
	{"style": "Big, blazing hits", "tempo": 0.94, "dmg": 1.08, "reach": 0.2, "kb": 1.1, "bdmg": 1.05,
		"combos": {"light3": "SOLAR SPIN", "rush": "COMET RUSH", "heavy3": "SUPERNOVA CRUSH",
			"sky_claw": "FLARE CLAW", "pound": "SUNQUAKE"}},
	# RUSTFANG: grinding machine that tears buildings apart.
	{"style": "Grinding wrecker", "tempo": 1.05, "dmg": 0.96, "reach": 0.0, "kb": 0.95, "bdmg": 1.45,
		"combos": {"light3": "SAW SPIN", "rush": "PISTON RUSH", "heavy3": "SCRAP CRUSH",
			"sky_claw": "RIVET CLAW", "pound": "HAMMER STOMP"}},
]


static func for_hero(hero: int) -> Dictionary:
	return MOVES[clampi(hero, 0, MOVES.size() - 1)]


## The hero's version of a normal attack: same move, own pace, damage,
## reach and knockback. Rage skills, rage mode shots and weapon swings are
## left alone (they have their own per-hero styles).
static func tune(attack: Dictionary, hero: int) -> Dictionary:
	var m := for_hero(hero)
	var a := attack.duplicate()
	var tempo: float = m["tempo"]
	a["dur"] = float(a["dur"]) / tempo
	a["active"] = float(a["active"]) / tempo
	a["dmg"] = float(a["dmg"]) * float(m["dmg"])
	a["kb"] = a["kb"] * float(m["kb"])
	a["bdmg"] = float(a["bdmg"]) * float(m["bdmg"])
	if float(a["reach"]) > 0.0:
		a["reach"] = float(a["reach"]) + float(m["reach"])
	return a


## The hero's name for a combo special ("light3", "rush", "heavy3",
## "sky_claw" or "pound").
static func combo_name(hero: int, combo: String) -> String:
	return String(for_hero(hero)["combos"].get(combo, combo.to_upper()))
