extends SceneTree
## Dev helper: prints how many enemies of each class all 100 levels spawn.

func _init() -> void:
	var by := {}
	for c in 10:
		for l in 10:
			for w in Content.level(c, l)["waves"]:
				for id in w["spawn"]:
					var cls: String = "boss" if id == "boss" else ("robot" if id in Enemies.ROBOTS or id == "elite" else Enemies.get_def(id)["class"])
					by[cls] = by.get(cls, 0) + 1
	print(by)
	quit()
