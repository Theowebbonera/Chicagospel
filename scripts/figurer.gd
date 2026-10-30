extends RefCounted
## Galleriet med figurer som kan sitta vid bordet. Varje figur beskrivs med kroppsform, hudton, frisyr, ansikte,
## kläder och accessoarer, och byggs i kod av gubbe.gd. Specialfigurer: robot, hund och katt. Figurer med "modell"
## är realistiska människor från Blender (assets/gubbar/), som gubbe.gd styr via skelettet.

const HUD := {
	"ljus": Color(0.98, 0.84, 0.72), "rosa": Color(0.99, 0.8, 0.72), "mellan": Color(0.87, 0.67, 0.5),
	"brun": Color(0.66, 0.46, 0.32), "mork": Color(0.45, 0.3, 0.2),
}

const FIGURER := [
	{"namn": "Greta", "kropp": "smal", "hud": "ljus", "har": "lang", "harfarg": Color(0.95, 0.8, 0.45),
		"ogon": "glada", "mun": "le", "bryn": "tunna", "klader": "troja", "farg": Color(0.82, 0.18, 0.22), "farg2": Color(1, 1, 1),
		"acc": ["glasogon"]},
	{"namn": "Bosse", "kropp": "rund", "hud": "rosa", "har": "kort", "harfarg": Color(0.4, 0.25, 0.12),
		"ogon": "runda", "mun": "neutral", "bryn": "tjocka", "klader": "kavaj", "farg": Color(0.42, 0.44, 0.48), "farg2": Color(0.75, 0.1, 0.15),
		"acc": ["mustasch", "fluga"]},
	{"namn": "Leo", "kropp": "lang", "hud": "mork", "har": "kort", "harfarg": Color(0.08, 0.06, 0.06),
		"ogon": "stora", "mun": "le", "bryn": "tunna", "klader": "hoodie", "farg": Color(0.2, 0.6, 0.35), "farg2": Color(0.95, 0.95, 0.95),
		"acc": ["horlurar"]},
	{"namn": "Sanna", "kropp": "kort", "hud": "ljus", "har": "lockigt", "harfarg": Color(0.8, 0.3, 0.1),
		"ogon": "runda", "mun": "o", "bryn": "tunna", "klader": "randig", "farg": Color(0.15, 0.3, 0.75), "farg2": Color(0.97, 0.97, 0.97),
		"acc": ["mossa"]},
	{"namn": "Farbror Ove", "kropp": "rund", "hud": "rosa", "har": "flint", "harfarg": Color(0.75, 0.75, 0.78),
		"ogon": "sovande", "mun": "neutral", "bryn": "tjocka", "klader": "kavaj", "farg": Color(0.45, 0.3, 0.18), "farg2": Color(0.2, 0.35, 0.2),
		"acc": ["skagg", "hatt"]},
	{"namn": "Mika", "kropp": "smal", "hud": "mellan", "har": "tofs", "harfarg": Color(0.12, 0.1, 0.1),
		"ogon": "runda", "mun": "le", "bryn": "arga", "klader": "hoodie", "farg": Color(0.55, 0.3, 0.75), "farg2": Color(0.95, 0.85, 0.3),
		"acc": ["solglasogon", "keps"]},
	{"namn": "Kungen", "kropp": "rund", "hud": "ljus", "har": "kort", "harfarg": Color(0.92, 0.92, 0.9),
		"ogon": "glada", "mun": "le", "bryn": "tjocka", "klader": "kavaj", "farg": Color(0.7, 0.08, 0.12), "farg2": Color(0.95, 0.75, 0.2),
		"acc": ["skagg", "krona"]},
	{"namn": "Nora", "kropp": "lang", "hud": "brun", "har": "lang", "harfarg": Color(0.15, 0.08, 0.05),
		"ogon": "stora", "mun": "le", "bryn": "tunna", "klader": "randig", "farg": Color(0.95, 0.55, 0.15), "farg2": Color(0.98, 0.95, 0.85),
		"acc": ["glasogon"]},
	{"namn": "Robot R7", "special": "robot", "kropp": "kort", "hud": "ljus", "har": "ingen", "harfarg": Color(0, 0, 0),
		"ogon": "led", "mun": "galler", "bryn": "ingen", "klader": "metall", "farg": Color(0.62, 0.66, 0.72), "farg2": Color(0.2, 0.9, 1.0),
		"acc": []},
	{"namn": "Kapten Jack", "kropp": "smal", "hud": "mellan", "har": "lang", "harfarg": Color(0.1, 0.07, 0.05),
		"ogon": "runda", "mun": "le", "bryn": "arga", "klader": "randig", "farg": Color(0.1, 0.1, 0.12), "farg2": Color(0.95, 0.92, 0.85),
		"acc": ["piratlapp", "piratt", "skagg"]},
	{"namn": "Kocken", "kropp": "rund", "hud": "rosa", "har": "kort", "harfarg": Color(0.3, 0.2, 0.1),
		"ogon": "glada", "mun": "le", "bryn": "tjocka", "klader": "kockrock", "farg": Color(0.97, 0.97, 0.95), "farg2": Color(0.85, 0.15, 0.15),
		"acc": ["kockmossa", "mustasch"]},
	{"namn": "Cowboy-Kalle", "kropp": "lang", "hud": "mellan", "har": "kort", "harfarg": Color(0.35, 0.22, 0.1),
		"ogon": "sovande", "mun": "neutral", "bryn": "tjocka", "klader": "vast", "farg": Color(0.55, 0.35, 0.18), "farg2": Color(0.85, 0.82, 0.75),
		"acc": ["cowboyhatt", "mustasch"]},
	{"namn": "Hunden Doris", "special": "hund", "kropp": "kort", "hud": "ljus", "har": "ingen", "harfarg": Color(0.55, 0.35, 0.18),
		"ogon": "stora", "mun": "le", "bryn": "ingen", "klader": "pals", "farg": Color(0.62, 0.42, 0.22), "farg2": Color(0.85, 0.1, 0.15),
		"acc": []},
	{"namn": "Katten Måns", "special": "katt", "kropp": "smal", "hud": "ljus", "har": "ingen", "harfarg": Color(0.45, 0.45, 0.5),
		"ogon": "katt", "mun": "le", "bryn": "ingen", "klader": "pals", "farg": Color(0.5, 0.5, 0.55), "farg2": Color(0.95, 0.75, 0.2),
		"acc": []},
	# Realistiska figurer (Blender + MPFB, blender/gubbar.py) efter Theos bild från fjälltoppen.
	{"namn": "Kevin", "modell": "res://assets/gubbar/kevin.glb", "farg": Color(0.2, 0.2, 0.22)},
	{"namn": "Theo", "modell": "res://assets/gubbar/theo.glb", "farg": Color(0.1, 0.12, 0.25)},
	{"namn": "Lukas", "modell": "res://assets/gubbar/lukas.glb", "farg": Color(0.07, 0.07, 0.08)},
	{"namn": "Adam", "modell": "res://assets/gubbar/adam.glb", "farg": Color(0.94, 0.94, 0.93)},
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
