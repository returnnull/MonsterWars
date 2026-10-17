class_name RageStyle
extends RefCounted
## Every hero's own rage mode attacks, as data. In rage mode light fires the
## hero's shot (see Fireball) and heavy pours the hero's breath (see
## Player._flame_tick); both look and work like the hero's element, and no
## two heroes' light attacks move or hit the same way.
##
##   attack  name of the hero's rage attack (special + heavy, see
##           Content "special" for how it works: beam, lightning, nova, quake)
##   mode / light / heavy  names shown over the kaiju (rage mode, shot, breath)
##   shot    what flies: ring, ball, glob, vine, rock, icicle, crescent,
##           wave, sun, scrap (see Fireball._build)
##   move    how the light attack moves and hits (see Fireball): ring, bolt
##           (instant chain lightning, Player._spit_bolt), pool, lash, roll,
##           drop, boomerang, wave, homing, burst (also straight, lob)
##   effect  what a hit does on top of damage (see Player._rage_effect):
##           burn, shock (lightning jumps on), poison (long burn and slow),
##           quake (throws up, wrecks buildings), frost (slows, the breath
##           freezes), leech (heals the hero), push (washes enemies back),
##           shred (wrecks buildings, sparks burn)
##   jet     how the breath looks: flame, beam, lightning, spikes, mist,
##           frost, shadow, water, sunray, sparks (see RageFX.jet and jet_tick)
##   ground  mark the shot and breath leave on the street (RageFX.ground)
##   ramp    breath/trail colours from the mouth outwards
##   core    hot inner colour (HDR, so it blooms), shell outer colour
##   glow    light colour, spark ember colour, smoke colour (alpha 0: none)

const STYLES := [
	# GORRAX: blue atomic fire. Atom rings that grow as they fly and cut
	# through every enemy in the row.
	{"attack": "ATOMIC BEAM", "mode": "ATOMIC FURY", "light": "ATOM RING", "heavy": "ATOMIC BREATH",
		"shot": "ring", "move": "ring", "effect": "burn", "jet": "beam", "ground": "glow",
		"ramp": [Color(0.6, 0.95, 1.0, 1.0), Color(0.25, 0.7, 1.0, 1.0), Color(0.1, 0.4, 0.95, 0.9), Color(0.08, 0.15, 0.6, 0.6), Color(0.05, 0.05, 0.2, 0.0)],
		"core": Color(1.6, 2.6, 3.0), "shell": Color(0.15, 0.6, 1.0, 0.45), "glow": Color(0.35, 0.8, 1.0),
		"spark": Color(0.5, 0.9, 1.0), "smoke": Color(0.1, 0.12, 0.2, 0.0)},
	# VOLTRA: instant chain lightning that jumps from enemy to enemy and a
	# breath of forked bolts.
	{"attack": "LIGHTNING STORM", "mode": "STORM FURY", "light": "CHAIN LIGHTNING", "heavy": "THUNDER BREATH",
		"shot": "ball", "move": "bolt", "effect": "shock", "jet": "lightning", "ground": "scorch",
		"ramp": [Color(1.0, 0.97, 0.6, 1.0), Color(1.0, 0.88, 0.25, 0.95), Color(0.65, 0.65, 1.0, 0.7), Color(0.35, 0.35, 0.85, 0.35), Color(0.2, 0.2, 0.5, 0.0)],
		"core": Color(3.0, 2.8, 1.6), "shell": Color(1.0, 0.9, 0.3, 0.4), "glow": Color(1.0, 0.92, 0.45),
		"spark": Color(1.0, 0.95, 0.6), "smoke": Color(0.2, 0.2, 0.25, 0.0)},
	# MAGMOS: lobbed lava bombs that leave burning pools of lava, and the
	# classic roaring flamethrower.
	{"attack": "ERUPTION", "mode": "MAGMA FURY", "light": "LAVA BOMB", "heavy": "MAGMA BREATH",
		"shot": "glob", "move": "pool", "effect": "burn", "jet": "flame", "ground": "lava",
		"ramp": [Color(1.0, 0.82, 0.35, 0.95), Color(1.0, 0.5, 0.06, 1.0), Color(0.95, 0.25, 0.02, 0.95), Color(0.6, 0.1, 0.02, 0.8), Color(0.12, 0.06, 0.05, 0.0)],
		"core": Color(2.6, 1.3, 0.3), "shell": Color(0.9, 0.22, 0.02, 0.45), "glow": Color(1.0, 0.45, 0.12),
		"spark": Color(1.0, 0.6, 0.2), "smoke": Color(0.14, 0.11, 0.1, 0.55)},
	# SYLVARA: a thorny vine that lashes out, poisons the row and drags it
	# in, and a creeping toxic cloud that lingers.
	{"attack": "VENOM NOVA", "mode": "VENOM FURY", "light": "VENOM LASH", "heavy": "TOXIC MIST",
		"shot": "vine", "move": "lash", "effect": "poison", "jet": "mist", "ground": "poison",
		"ramp": [Color(0.75, 1.0, 0.45, 0.9), Color(0.45, 0.95, 0.25, 0.85), Color(0.55, 0.3, 0.85, 0.7), Color(0.35, 0.15, 0.5, 0.45), Color(0.15, 0.05, 0.2, 0.0)],
		"core": Color(1.2, 2.4, 0.6), "shell": Color(0.6, 0.2, 0.9, 0.5), "glow": Color(0.6, 1.0, 0.35),
		"spark": Color(0.7, 1.0, 0.4), "smoke": Color(0.3, 0.12, 0.4, 0.5)},
	# TERRAXA: boulders that roll down the street bowling enemies over, and
	# a march of crystal spikes out of the street.
	{"attack": "EARTHQUAKE", "mode": "QUAKE FURY", "light": "ROLLING BOULDER", "heavy": "CRYSTAL SPIKES",
		"shot": "rock", "move": "roll", "effect": "quake", "jet": "spikes", "ground": "crack",
		"ramp": [Color(0.75, 0.68, 0.5, 0.8), Color(0.62, 0.55, 0.4, 0.7), Color(0.5, 0.45, 0.35, 0.55), Color(0.4, 0.38, 0.32, 0.3), Color(0.35, 0.33, 0.3, 0.0)],
		"core": Color(0.9, 2.6, 0.7), "shell": Color(0.45, 1.0, 0.35, 0.4), "glow": Color(0.55, 1.0, 0.4),
		"spark": Color(0.6, 1.0, 0.45), "smoke": Color(0.5, 0.45, 0.38, 0.6)},
	# GLACIOR: icicles that fall from the sky and freeze what they land on,
	# and a freezing white breath.
	{"attack": "ICE BEAM", "mode": "FROST FURY", "light": "ICICLE DROP", "heavy": "FROST BREATH",
		"shot": "icicle", "move": "drop", "effect": "frost", "jet": "frost", "ground": "ice",
		"ramp": [Color(1.0, 1.0, 1.0, 0.95), Color(0.8, 0.95, 1.0, 0.9), Color(0.55, 0.8, 1.0, 0.75), Color(0.45, 0.65, 0.9, 0.4), Color(0.6, 0.75, 0.9, 0.0)],
		"core": Color(1.8, 2.4, 2.8), "shell": Color(0.6, 0.85, 1.0, 0.45), "glow": Color(0.6, 0.9, 1.0),
		"spark": Color(0.85, 0.97, 1.0), "smoke": Color(0.85, 0.92, 1.0, 0.35)},
	# NOCTYR: a shadow blade that flies out and comes back, cutting the row
	# twice, and a breath that drains their life back to it.
	{"attack": "BLOOD NOVA", "mode": "BLOOD FURY", "light": "SHADOW BOOMERANG", "heavy": "SOUL DRAIN",
		"shot": "crescent", "move": "boomerang", "effect": "leech", "jet": "shadow", "ground": "shadow",
		"ramp": [Color(1.0, 0.35, 0.4, 0.95), Color(0.75, 0.05, 0.15, 0.9), Color(0.3, 0.02, 0.08, 0.85), Color(0.1, 0.02, 0.05, 0.6), Color(0.05, 0.02, 0.04, 0.0)],
		"core": Color(2.8, 0.3, 0.5), "shell": Color(0.25, 0.0, 0.05, 0.7), "glow": Color(1.0, 0.15, 0.25),
		"spark": Color(1.0, 0.2, 0.3), "smoke": Color(0.08, 0.02, 0.05, 0.6)},
	# CORALIS: a wave rolling down the street that carries the row away, and
	# a hydro jet that washes enemies back.
	{"attack": "TORRENT", "mode": "TIDE FURY", "light": "RIPTIDE", "heavy": "HYDRO JET",
		"shot": "wave", "move": "wave", "effect": "push", "jet": "water", "ground": "puddle",
		"ramp": [Color(0.95, 1.0, 1.0, 0.95), Color(0.55, 0.95, 1.0, 0.9), Color(0.2, 0.7, 0.9, 0.8), Color(0.15, 0.5, 0.7, 0.45), Color(0.8, 0.95, 1.0, 0.0)],
		"core": Color(1.2, 2.6, 2.4), "shell": Color(0.3, 0.9, 0.85, 0.3), "glow": Color(0.35, 1.0, 0.85),
		"spark": Color(0.8, 1.0, 1.0), "smoke": Color(0.85, 0.95, 1.0, 0.35)},
	# SOLAR REX: little suns that seek out enemies (also in the air) and a
	# cone of blinding sunbeams.
	{"attack": "SUN BURST", "mode": "SOLAR FURY", "light": "SEEKING SUN", "heavy": "SUN RAY",
		"shot": "sun", "move": "homing", "effect": "burn", "jet": "sunray", "ground": "fire",
		"ramp": [Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.88, 0.4, 1.0), Color(1.0, 0.6, 0.12, 0.9), Color(0.85, 0.3, 0.05, 0.6), Color(0.3, 0.1, 0.02, 0.0)],
		"core": Color(3.0, 2.5, 1.2), "shell": Color(1.0, 0.65, 0.1, 0.45), "glow": Color(1.0, 0.8, 0.35),
		"spark": Color(1.0, 0.85, 0.4), "smoke": Color(0.2, 0.12, 0.05, 0.0)},
	# RUSTFANG: a rattling burst of red-hot rivets and a plasma cutter in a
	# shower of sparks.
	{"attack": "SCRAP QUAKE", "mode": "SCRAP FURY", "light": "RIVET GUN", "heavy": "PLASMA CUTTER",
		"shot": "scrap", "move": "burst", "effect": "shred", "jet": "sparks", "ground": "oil",
		"ramp": [Color(0.9, 0.95, 1.0, 1.0), Color(0.5, 0.75, 1.0, 1.0), Color(0.35, 0.45, 1.0, 0.8), Color(0.3, 0.25, 0.6, 0.4), Color(0.15, 0.12, 0.2, 0.0)],
		"core": Color(1.8, 2.2, 3.0), "shell": Color(1.0, 0.35, 0.08, 0.5), "glow": Color(0.55, 0.75, 1.0),
		"spark": Color(1.0, 0.55, 0.15), "smoke": Color(0.1, 0.09, 0.09, 0.6)},
]


static func for_hero(hero: int) -> Dictionary:
	return STYLES[clampi(hero, 0, STYLES.size() - 1)]
