class_name Trophies
extends RefCounted
## Trophies: special feats that each unlock a cosmetic item (see Cosmetics).
## Beating the game gives a crown for the difficulty (a harder win also
## counts for the easier crowns), and 50 more trophies come from the stats
## Game keeps (Game.stats, saved with the progress).
##
## Each trophy counts "stat" (one stat name or several to add up) up to
## "goal". Stats starting with "@" are worked out from the save instead (see
## progress()). Stats Game tracks:
##   kills, kills_<class> (infantry, air, ground, kaiju), kills_<enemy id>,
##   buildings, jumps, dodges, rage_modes, roars, supers, fireballs, throws,
##   grabs, knockouts, orbs, score, branch_ends, best_combo (the highest),
##   and per cleared level: clears, boss_<country>, final_<difficulty>,
##   clears_hard_boss, clears_flawless, clears_close, clears_wrecked,
##   clears_tourist, clears_fast, clears_zen, clears_coop, clears_coop4,
##   clear_hero_<hero>.

## A level cleared faster than this (seconds) counts for "clears_fast".
const FAST_CLEAR := 75.0

const LIST := [
	{"id": "crown_easy", "name": "Bronze Monarch", "desc": "Beat the final boss on Easy (or harder)",
		"stat": ["final_0", "final_1", "final_2"], "goal": 1, "item": "bronze_crown"},
	{"id": "crown_normal", "name": "Silver Sovereign", "desc": "Beat the final boss on Normal (or Hard)",
		"stat": ["final_1", "final_2"], "goal": 1, "item": "silver_crown"},
	{"id": "crown_hard", "name": "Golden Emperor", "desc": "Beat the final boss on Hard",
		"stat": "final_2", "goal": 1, "item": "gold_crown"},
	# One per country boss.
	{"id": "boss_0", "name": "Troll Toppler", "desc": "Defeat HAVTROLD in Denmark", "stat": "boss_0", "goal": 1, "item": "viking_helmet"},
	{"id": "boss_1", "name": "Gargoyle Grinder", "desc": "Defeat GARGOUILLE in France", "stat": "boss_1", "goal": 1, "item": "beret"},
	{"id": "boss_2", "name": "Steel Breaker", "desc": "Defeat IRONCLAW in the USA", "stat": "boss_2", "goal": 1, "item": "cowboy_hat"},
	{"id": "boss_3", "name": "Jungle Party", "desc": "Defeat JAGUARON in Brazil", "stat": "boss_3", "goal": 1, "item": "carnival_feathers"},
	{"id": "boss_4", "name": "Riddle Solved", "desc": "Defeat SPHINXAR in Egypt", "stat": "boss_4", "goal": 1, "item": "fez"},
	{"id": "boss_5", "name": "Snake Charmer", "desc": "Defeat NAGARAJ in India", "stat": "boss_5", "goal": 1, "item": "turban"},
	{"id": "boss_6", "name": "Croc Wrangler", "desc": "Defeat CROCODON in Australia", "stat": "boss_6", "goal": 1, "item": "cork_hat"},
	{"id": "boss_7", "name": "Mammoth Melter", "desc": "Defeat MAMMOTHRAX in Russia", "stat": "boss_7", "goal": 1, "item": "ushanka"},
	{"id": "boss_8", "name": "Fire and Ice", "desc": "Defeat SURTUR in Iceland", "stat": "boss_8", "goal": 1, "item": "wool_scarf"},
	{"id": "boss_9", "name": "Dragon Slayer", "desc": "Defeat RYUJIN PRIME in Japan", "stat": "boss_9", "goal": 1, "item": "hachimaki"},
	# Defeating enemies.
	{"id": "kills_100", "name": "Pest Control", "desc": "Defeat 100 enemies", "stat": "kills", "goal": 100, "item": "party_hat"},
	{"id": "kills_1000", "name": "Exterminator", "desc": "Defeat 1,000 enemies", "stat": "kills", "goal": 1000, "item": "sunglasses"},
	{"id": "kills_5000", "name": "Extinction Event", "desc": "Defeat 5,000 enemies", "stat": "kills", "goal": 5000, "item": "gold_chain"},
	{"id": "infantry_500", "name": "Stomp Stomp", "desc": "Defeat 500 infantry squads", "stat": "kills_infantry", "goal": 500, "item": "rubber_duck"},
	{"id": "air_200", "name": "Flyswatter", "desc": "Shoot down 200 aircraft", "stat": "kills_air", "goal": 200, "item": "propeller_cap"},
	{"id": "ground_200", "name": "Scrap Collector", "desc": "Wreck 200 vehicles", "stat": "kills_ground", "goal": 200, "item": "traffic_cone"},
	{"id": "monsters_300", "name": "Monster Mash", "desc": "Defeat 300 enemy monsters", "stat": "kills_kaiju", "goal": 300, "item": "bone_necklace"},
	{"id": "boomtick_40", "name": "Bomb Squad", "desc": "Defeat 40 Boomticks", "stat": "kills_boomtick", "goal": 40, "item": "dynamite_tail"},
	{"id": "heli_60", "name": "Chopper Chopper", "desc": "Shoot down 60 gunships", "stat": "kills_heli", "goal": 60, "item": "toy_chopper"},
	{"id": "saucer_25", "name": "Close Encounters", "desc": "Shoot down 25 saucers", "stat": "kills_saucer", "goal": 25, "item": "tinfoil_hat"},
	# Smashing the city.
	{"id": "buildings_100", "name": "Urban Renewal", "desc": "Destroy 100 buildings", "stat": "buildings", "goal": 100, "item": "hard_hat"},
	{"id": "buildings_1000", "name": "Wrecking Crew", "desc": "Destroy 1,000 buildings", "stat": "buildings", "goal": 1000, "item": "wrecking_ball"},
	{"id": "wrecked", "name": "Nothing Left Standing", "desc": "Clear a level with 100% destruction", "stat": "clears_wrecked", "goal": 1, "item": "tnt_pack"},
	{"id": "tourist", "name": "Just Visiting", "desc": "Clear a level with every building still standing", "stat": "clears_tourist", "goal": 1, "item": "tourist_camera"},
	# Fighting style.
	{"id": "combo_25", "name": "Warming Up", "desc": "Reach a 25-hit combo", "stat": "best_combo", "goal": 25, "item": "sweatband"},
	{"id": "combo_50", "name": "Combo Star", "desc": "Reach a 50-hit combo", "stat": "best_combo", "goal": 50, "item": "star_shades"},
	{"id": "combo_100", "name": "Unstoppable", "desc": "Reach a 100-hit combo", "stat": "best_combo", "goal": 100, "item": "flame_tip"},
	{"id": "rage_50", "name": "Short Fuse", "desc": "Go into rage mode 50 times", "stat": "rage_modes", "goal": 50, "item": "devil_horns"},
	{"id": "roar_100", "name": "Loudmouth", "desc": "War roar 100 times", "stat": "roars", "goal": 100, "item": "ruff_collar"},
	{"id": "super_25", "name": "Super Star", "desc": "Unleash 25 super specials", "stat": "supers", "goal": 25, "item": "hero_cape"},
	{"id": "fireball_500", "name": "Hot Breath", "desc": "Spit 500 fireballs in rage mode", "stat": "fireballs", "goal": 500, "item": "fire_helmet"},
	{"id": "throw_100", "name": "Quarterback", "desc": "Throw 100 pieces of wreckage", "stat": "throws", "goal": 100, "item": "whistle"},
	{"id": "grab_250", "name": "Hoarder", "desc": "Pick up 250 pieces of wreckage", "stat": "grabs", "goal": 250, "item": "hiking_pack"},
	{"id": "dodge_500", "name": "Can't Touch This", "desc": "Dodge 500 times", "stat": "dodges", "goal": 500, "item": "ninja_mask"},
	{"id": "jump_1000", "name": "Frequent Flyer", "desc": "Jump 1,000 times", "stat": "jumps", "goal": 1000, "item": "jetpack"},
	# Growing up.
	{"id": "level_10", "name": "Growing Up", "desc": "Get a kaiju to level 10", "stat": "@best_level", "goal": 10, "item": "grad_cap"},
	{"id": "level_25", "name": "Distinguished", "desc": "Get a kaiju to level 25", "stat": "@best_level", "goal": 25, "item": "monocle"},
	{"id": "all_level_10", "name": "Proud Parent", "desc": "Get all 10 kaiju to level 10", "stat": "@heroes_level_10", "goal": 10, "item": "medal"},
	{"id": "all_heroes", "name": "Team Spirit", "desc": "Clear a level with each of the 10 kaiju", "stat": "@heroes_cleared", "goal": 10, "item": "rainbow_scarf"},
	{"id": "branch_end", "name": "Specialist", "desc": "Learn a skill at the end of a skill tree branch", "stat": "branch_ends", "goal": 1, "item": "wizard_hat"},
	# Special clears.
	{"id": "flawless", "name": "Untouchable", "desc": "Clear a level without taking any damage", "stat": "clears_flawless", "goal": 1, "item": "halo"},
	{"id": "close_call", "name": "Close Call", "desc": "Clear a level with less than 10% health left", "stat": "clears_close", "goal": 1, "item": "eyepatch"},
	{"id": "zen", "name": "Inner Peace", "desc": "Defeat a boss without using any rage skill or rage mode", "stat": "clears_zen", "goal": 1, "item": "prayer_beads"},
	{"id": "fast", "name": "Speed Demon", "desc": "Clear a level in under 75 seconds", "stat": "clears_fast", "goal": 1, "item": "racing_goggles"},
	{"id": "coop", "name": "Buddy System", "desc": "Clear a level with 2 or more players", "stat": "clears_coop", "goal": 1, "item": "bowtie"},
	{"id": "coop_4", "name": "Full House", "desc": "Clear a level with 4 players", "stat": "clears_coop4", "goal": 1, "item": "balloon"},
	{"id": "knockouts_25", "name": "Comeback Kid", "desc": "Get knocked out 25 times", "stat": "knockouts", "goal": 25, "item": "clown_nose"},
	{"id": "orbs_100", "name": "Snack Time", "desc": "Pick up 100 healing orbs", "stat": "orbs", "goal": 100, "item": "lollipop"},
	{"id": "score_1m", "name": "Millionaire", "desc": "Score 1,000,000 points in total", "stat": "score", "goal": 1000000, "item": "top_hat"},
	{"id": "hard_boss", "name": "Hardcore", "desc": "Defeat any boss on Hard", "stat": "clears_hard_boss", "goal": 1, "item": "spiked_collar"},
]


static func get_def(id: String) -> Dictionary:
	for t in LIST:
		if t["id"] == id:
			return t
	return {}


## The trophy that unlocks a cosmetic item.
static func for_item(item_id: String) -> Dictionary:
	for t in LIST:
		if t["item"] == item_id:
			return t
	return {}


## How far along a trophy is, from the stats and the save, as
## Vector2i(current, goal). Current is capped at the goal.
static func progress(t: Dictionary) -> Vector2i:
	var names: Array = t["stat"] if t["stat"] is Array else [t["stat"]]
	var cur := 0
	for s in names:
		cur += _stat(s)
	return Vector2i(mini(cur, int(t["goal"])), int(t["goal"]))


static func _stat(s: String) -> int:
	match s:
		"@best_level":
			var best := 1
			for h in Content.HEROES.size():
				best = maxi(best, Game.hero_level(h))
			return best
		"@heroes_level_10":
			return range(Content.HEROES.size()).filter(func(h: int) -> bool: return Game.hero_level(h) >= 10).size()
		"@heroes_cleared":
			return range(Content.HEROES.size()).filter(func(h: int) -> bool:
				return int(Game.stats.get("clear_hero_%d" % h, 0)) > 0).size()
	return int(Game.stats.get(s, 0))


## Text for a trophy's progress, e.g. "37 / 100", or "DONE".
static func progress_text(t: Dictionary) -> String:
	if Game.has_trophy(t["id"]):
		return "DONE"
	var p := progress(t)
	if p.y <= 1:
		return "NOT YET"
	return "%s / %s" % [_num(p.x), _num(p.y)]


static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
