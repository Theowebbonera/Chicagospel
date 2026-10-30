extends RefCounted
## Figurerna som kan sitta vid bordet: realistiska människor från Blender (assets/gubbar/, blender/gubbar.py),
## som gubbe.gd styr via skelettet.

const FIGURER := [
	# Blender + MPFB efter Theos bild från fjälltoppen.
	{"namn": "Kevin", "modell": "res://assets/gubbar/kevin.glb"},
	{"namn": "Theo", "modell": "res://assets/gubbar/theo.glb"},
	{"namn": "Lukas", "modell": "res://assets/gubbar/lukas.glb"},
	{"namn": "Adam", "modell": "res://assets/gubbar/adam.glb"},
]


static func antal() -> int:
	return FIGURER.size()


static func namn(i: int) -> String:
	return FIGURER[posmod(i, FIGURER.size())].namn


## Fyller i figurer för platser som saknar (-1) med slumpade figurer som inte redan är valda.
static func fordela(valda: Array, rng: RandomNumberGenerator) -> Array:
	var ut := valda.duplicate()
	var tagna := {}
	for f in ut:
		if f >= 0:
			tagna[f] = true
	for i in ut.size():
		if ut[i] < 0:
			var lediga: Array = []
			for f in FIGURER.size():
				if not tagna.has(f):
					lediga.append(f)
			if lediga.is_empty():
				lediga = range(FIGURER.size())
			ut[i] = lediga[rng.randi_range(0, lediga.size() - 1)]
			tagna[ut[i]] = true
	return ut
