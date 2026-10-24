extends RefCounted
## Kortleken som ren data. Ett kort är ett heltal 0–51:
## färg = kort / 13 (0 spader, 1 hjärter, 2 ruter, 3 klöver), valör = kort % 13 + 2 (2–14, där ess = 14).

const SPADER := 0
const HJARTER := 1
const RUTER := 2
const KLOVER := 3

const FARG_NAMN := ["spader", "hjärter", "ruter", "klöver"]
## Tecken som står i kortets hörn.
const VALOR_TECKEN := ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Kn", "D", "K", "E"]
const VALOR_NAMN := ["", "", "tvåa", "trea", "fyra", "femma", "sexa", "sjua", "åtta", "nia", "tia", "knekt", "dam", "kung", "ess"]
const VALOR_PLURAL := ["", "", "tvåor", "treor", "fyror", "femmor", "sexor", "sjuor", "åttor", "nior", "tior", "knektar", "damer", "kungar", "ess"]
const VALOR_ORD := ["", "", "två", "tre", "fyra", "fem", "sex", "sju", "åtta", "nio", "tio", "knekt", "dam", "kung", "ess"]


static func farg(c: int) -> int:
	return c / 13


static func valor(c: int) -> int:
	return c % 13 + 2


static func kort(f: int, v: int) -> int:
	return f * 13 + v - 2


static func ar_rod(c: int) -> bool:
	var f := farg(c)
	return f == HJARTER or f == RUTER


## "hjärter kung", "spader ess", "klöver sju"
static func namn(c: int) -> String:
	return "%s %s" % [FARG_NAMN[farg(c)], VALOR_ORD[valor(c)]]


## Kort ur kort text, t.ex. "AS KH 10D 2C" (S spader, H hjärter, D ruter, C klöver; J Q K A). Används i testerna.
static func las(text: String) -> Array:
	var ut: Array = []
	for bit in text.split(" ", false):
		var s := bit.strip_edges().to_upper()
		var fb := s.substr(s.length() - 1)
		var vb := s.substr(0, s.length() - 1)
		var f: int = "SHDC".find(fb)
		var v := 0
		match vb:
			"J":
				v = 11
			"Q":
				v = 12
			"K":
				v = 13
			"A":
				v = 14
			_:
				v = int(vb)
		assert(f >= 0 and v >= 2 and v <= 14, "felaktigt kort: " + bit)
		ut.append(kort(f, v))
	return ut


static func ny_lek() -> Array:
	var lek: Array = []
	for i in 52:
		lek.append(i)
	return lek


## Fisher–Yates med egen slumpgenerator så att samma frö ger samma giv.
static func blanda(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Sortering för visning: färg (spader, hjärter, klöver, ruter så att röda och svarta varvas), sedan valör.
static func sortera_hand(h: Array) -> Array:
	var ut := h.duplicate()
	var ordning := [0, 1, 3, 2]
	ut.sort_custom(func(a: int, b: int) -> bool:
		var fa: int = ordning[farg(a)]
		var fb: int = ordning[farg(b)]
		if fa != fb:
			return fa < fb
		return valor(a) < valor(b))
	return ut
