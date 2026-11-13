extends RefCounted
## Regelmotorn för Plump (Theo 2026-11-13), med samma gränssnitt som motor.gd så att servern, nätverket och
## grafiken kan köra båda spelen. Ren logik utan grafik: styrs med drag (bjud, spela) och lägger allt som händer
## i en händelselista.
##
## Reglerna (spelregler.org/plump-regler): varje giv har ett visst antal kort, först 10 (eller så många som leken
## räcker till), sedan ett färre per giv ner till 1 och upp igen. Alla ser sina kort och bjuder hur många stick de
## ska ta, med början hos spelaren efter given. Givaren bjuder sist och får inte bjuda så att buden tillsammans går
## jämnt ut med antalet stick. Man måste bekänna färg, ingen trumf: högsta kortet i utspelad färg tar sticket.
## Exakt bud ger 10 + budet (0 stick ger 10), annars en plump och inga poäng. Flest poäng efter sista given vinner.
## Med 1 kort ser man sitt kort och bjuder sedan, som vanligt (Theo: "man får se och sen välja").

const K := preload("res://scripts/kort.gd")
const Motor := preload("res://scripts/motor.gd")
const Fas := Motor.Fas

var regler
var namn: Array = []
var n := 0
var poang: Array = []
var plumpar: Array = []  # antal missade bud per spelare
var givare := 0
var giv_nr := 0
var rundor: Array = []  # antal kort i varje giv
var kort_i_giv := 0
var rng := RandomNumberGenerator.new()

var lek: Array = []
var slangda: Array = []  # används inte, finns för samma tillstånd som Chicago
var hander: Array = []
var bud: Array = []  # per spelare, -1 = inte bjudit än
var fas: int = Fas.INTE_STARTAD
var tur := 0
var stick_nr := 0
var stick: Array = []
var utspelare := 0
var stick_vunna: Array = []
var spelade: Array = []
var renons: Array = []
var vinnare := -1
var handelser: Array = []

# Fält som Chicago har och som servern och nätverket läser: alltid tomma i Plump.
var byte_nr := 0
var chicago := -1
var chicago_sprack := false
var chicago_tagen: Array = []
var upp_kort := -1
var upp_slangt := -1


## Antal kort i varje giv: max ner till 1, och upp igen om regeln säger det. Max begränsas av leken.
static func rundlista(antal_spelare: int, max_kort: int, upp_igen: bool) -> Array:
	var m := mini(max_kort, 52 / antal_spelare)
	m = maxi(m, 1)
	var a: Array = []
	for k in range(m, 0, -1):
		a.append(k)
	if upp_igen:
		for k in range(2, m + 1):
			a.append(k)
	return a


func starta(spelarnamn: Array, r, fro := -1, forsta_givare := -1) -> void:
	regler = r
	namn = spelarnamn.duplicate()
	n = namn.size()
	assert(n >= 2 and n <= 6)
	poang = _nollor()
	plumpar = _nollor()
	chicago_tagen = []
	for i in n:
		chicago_tagen.append(false)
	if fro >= 0:
		rng.seed = fro
	else:
		rng.randomize()
	givare = forsta_givare if forsta_givare >= 0 else rng.randi_range(0, n - 1)
	giv_nr = 0
	vinnare = -1
	rundor = rundlista(n, int(r.plump_max), bool(r.plump_upp))
	handelser.clear()
	fas = Fas.GIV_SLUT
	_h({"typ": "parti_start", "givare": givare, "spel": "plump", "rundor": rundor.duplicate()})


func _nollor() -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(0)
	return a


func forhand() -> int:
	return (givare + 1) % n


func i_ordning(start: int) -> Array:
	var a: Array = []
	for i in n:
		a.append((start + i) % n)
	return a


func _h(d: Dictionary) -> void:
	handelser.append(d)


func ta_handelser() -> Array:
	var a := handelser
	handelser = []
	return a


# ------------------------------------------------------------------ given
func ny_giv(fast_lek: Array = []) -> void:
	assert(fas == Fas.GIV_SLUT)
	giv_nr += 1
	if giv_nr > 1:
		givare = (givare + 1) % n
	kort_i_giv = rundor[giv_nr - 1]
	if fast_lek.is_empty():
		lek = K.ny_lek()
		K.blanda(lek, rng)
	else:
		lek = fast_lek.duplicate()
	hander = []
	renons = []
	bud = []
	for i in n:
		hander.append([])
		renons.append({})
		bud.append(-1)
	spelade = []
	stick = []
	stick_vunna = _nollor()
	stick_nr = 0
	_h({"typ": "blanda", "givare": givare, "giv": giv_nr, "kort": kort_i_giv})
	for runda in kort_i_giv:
		for p in i_ordning(forhand()):
			var c: int = lek.pop_back()
			hander[p].append(c)
			_h({"typ": "giv", "spelare": p, "kort": c})
	_h({"typ": "giv_klar"})
	fas = Fas.BUD
	tur = forhand()
	_h({"typ": "bud_start", "giv": giv_nr, "kort": kort_i_giv, "spelare": tur})


# ------------------------------------------------------------------ bud
## Budet som givaren inte får lägga (så att buden går jämnt ut), eller -1 om alla bud är tillåtna.
func forbjudet_bud(p: int) -> int:
	if p != givare:
		return -1
	var summa := 0
	for q in n:
		if q != p:
			summa += maxi(bud[q], 0)
	var f := kort_i_giv - summa
	return f if f >= 0 and f <= kort_i_giv else -1


func tillatna_bud(p: int) -> Array:
	if fas != Fas.BUD or p != tur:
		return []
	var f := forbjudet_bud(p)
	var a: Array = []
	for b in kort_i_giv + 1:
		if b != f:
			a.append(b)
	return a


func bjud(p: int, b: int) -> bool:
	if not b in tillatna_bud(p):
		return false
	bud[p] = b
	_h({"typ": "bud", "spelare": p, "bud": b})
	if p == givare:
		_till_stick(forhand())
	else:
		tur = (tur + 1) % n
	return true


# ------------------------------------------------------------------ stick
func _till_stick(ut: int) -> void:
	fas = Fas.STICK
	stick_nr = 1
	stick = []
	utspelare = ut
	tur = ut
	_h({"typ": "stick_start", "nr": 1, "utspelare": ut, "av": kort_i_giv})


func tillatna(p: int) -> Array:
	if fas != Fas.STICK or p != tur:
		return []
	return Motor.tillatna_kort(hander[p], stick)


func spela(p: int, c: int) -> bool:
	if not c in tillatna(p):
		return false
	hander[p].erase(c)
	if not stick.is_empty() and K.farg(c) != K.farg(stick[0][1]):
		renons[p][K.farg(stick[0][1])] = true
	stick.append([p, c])
	spelade.append([p, c])
	_h({"typ": "spela", "spelare": p, "kort": c, "nr": stick_nr})
	if stick.size() < n:
		tur = (tur + 1) % n
		return true
	var vinn := Motor.stickvinnare(stick)
	var w: int = vinn[0]
	stick_vunna[w] += 1
	_h({"typ": "stick", "vinnare": w, "kort": vinn[1], "nr": stick_nr, "av": kort_i_giv, "stick": stick.duplicate(true)})
	if stick_nr == kort_i_giv:
		_givens_poang()
		return true
	stick_nr += 1
	stick = []
	utspelare = w
	tur = w
	_h({"typ": "stick_start", "nr": stick_nr, "utspelare": w, "av": kort_i_giv})
	return true


## Exakt bud: 10 + budet. Annars plump.
func _givens_poang() -> void:
	var fick: Array = _nollor()
	var lyckad: Array = []
	for p in n:
		var ok: bool = stick_vunna[p] == bud[p]
		lyckad.append(ok)
		if ok:
			fick[p] = 10 + bud[p]
			poang[p] += fick[p]
		else:
			plumpar[p] += 1
	_h({"typ": "plump_resultat", "bud": bud.duplicate(), "stick": stick_vunna.duplicate(), "lyckad": lyckad,
		"fick": fick, "poang": poang.duplicate(), "plumpar": plumpar.duplicate()})
	if giv_nr >= rundor.size():
		_slut()
		return
	fas = Fas.GIV_SLUT
	_h({"typ": "giv_slut", "poang": poang.duplicate()})


## Flest poäng vinner; vid lika den med minst plumpar, sedan den som satt först efter första givaren.
func _slut() -> void:
	var bast := 0
	for p in range(1, n):
		if poang[p] > poang[bast] or (poang[p] == poang[bast] and plumpar[p] < plumpar[bast]):
			bast = p
	vinnare = bast
	fas = Fas.SLUT
	_h({"typ": "vinst", "spelare": bast, "poang": poang.duplicate(), "plumpar": plumpar.duplicate()})


# ------------------------------------------------------------------ för servern och nätverket
func poangsatts_bytet() -> bool:
	return false


func max_byte(_p: int) -> int:
	return 0


func vy(p: int) -> Dictionary:
	var kvar: Array = []
	for q in n:
		kvar.append(hander[q].size() if q < hander.size() else 0)
	return {
		"jag": p,
		"n": n,
		"spel": "plump",
		"hand": hander[p].duplicate() if p < hander.size() else [],
		"poang": poang.duplicate(),
		"plumpar": plumpar.duplicate(),
		"fas": fas,
		"givare": givare,
		"giv_nr": giv_nr,
		"rundor": rundor.duplicate(),
		"kort_i_giv": kort_i_giv,
		"bud": bud.duplicate(),
		"tillatna_bud": tillatna_bud(p),
		"forbjudet_bud": forbjudet_bud(p) if fas == Fas.BUD and p == tur else -1,
		"stick_nr": stick_nr,
		"stick": stick.duplicate(true),
		"utspelare": utspelare,
		"spelade": spelade.duplicate(true),
		"renons": renons.duplicate(true),
		"kvar": kvar,
		"stick_vunna": stick_vunna.duplicate(),
		"tillatna": tillatna(p),
		"regler": regler,
		# samma nycklar som Chicago, tomma
		"byte_nr": 0, "max_byte": 0, "upp_kort": -1, "kopstopp": false, "star_over": [], "bytes_antal": [],
		"egna_slangda": [], "far_ropa": false, "chicago": -1, "chicago_sprack": false, "chicago_tagen": chicago_tagen.duplicate(),
		"poangsatts": false, "byten_kvar": 0,
	}


func satt_poang(p: Array) -> void:
	poang = p.duplicate()
