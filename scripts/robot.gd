extends RefCounted
## Robotspelare för Chicago. Alla beslut tar bara spelarens egen vy från motorn (motor.vy(p)):
## egen hand, egna slängda kort, spelade kort, hur många kort andra bytt och vilka färger de visat sig sakna.
## Andras kort är okända och gissas genom slumpade utdelningar av de kort spelaren inte har sett.

const K := preload("res://scripts/kort.gd")
const H := preload("res://scripts/handvarde.gd")
const Motor := preload("res://scripts/motor.gd")

enum {LATT, MEDEL, SVAR}
const NIVA_NAMN := ["Lätt", "Medel", "Svår"]

## Ungefärlig fördelning av en motståndares hand efter ett byte (andel per kategori), används av den svåra roboten
## för att väga en hand efter chansen att den är bäst vid bordet.
const FORDELNING := [0.20, 0.43, 0.19, 0.095, 0.03, 0.025, 0.025, 0.004, 0.0008, 0.0002]


## Kort som spelaren inte har sett (finns hos andra, i talongen eller bland andras slängda kort).
static func okanda(vy: Dictionary) -> Array:
	var kand := {}
	for c in vy.hand:
		kand[c] = true
	for c in vy.egna_slangda:
		kand[c] = true
	for s in vy.spelade:
		kand[s[1]] = true
	var ut: Array = []
	for c in 52:
		if not kand.has(c):
			ut.append(c)
	return ut


static func _dra(pool: Array, k: int, rng: RandomNumberGenerator) -> Array:
	var p := pool.duplicate()
	var ut: Array = []
	for i in k:
		var j := rng.randi_range(i, p.size() - 1)
		var t = p[i]
		p[i] = p[j]
		p[j] = t
		ut.append(p[i])
	return ut


# ================================================================== byten
static func valj_byte(vy: Dictionary, niva: int, rng: RandomNumberGenerator) -> Array:
	var maxb: int = vy.max_byte
	if maxb <= 0:
		return []
	var ut: Array
	if not vy.poangsatts:
		ut = _byte_for_stick(vy, niva, rng)
	elif niva == LATT:
		ut = _byte_enkel(vy.hand, vy.regler, rng)
	else:
		ut = _byte_mc(vy, niva, rng)
	return _begransa(ut, maxb)


## Om fler kort än tillåtet valts, behåll de högsta av de valda.
static func _begransa(sl: Array, maxb: int) -> Array:
	if sl.size() <= maxb:
		return sl
	var s := sl.duplicate()
	s.sort_custom(func(a: int, b: int) -> bool: return K.valor(a) < K.valor(b))
	return s.slice(0, maxb)


## Lätt robot: tumregler. Behåll par/triss/fyrtal, färg- och stegdrag med fyra kort, annars höga kort.
static func _byte_enkel(hand: Array, r, rng: RandomNumberGenerator) -> Array:
	var a := H.analys(hand, r.ess_lag)
	var kat: int = a[0]
	if kat >= H.STEGE and kat != H.TRISS:
		return []
	var cnt := {}
	for c in hand:
		cnt[K.valor(c)] = cnt.get(K.valor(c), 0) + 1
	var sl: Array = []
	if kat >= H.PAR:
		for c in hand:
			if cnt[K.valor(c)] == 1:
				sl.append(c)
		# ibland sparas en hög kicker
		if sl.size() >= 2 and rng.randf() < 0.3:
			sl.sort_custom(func(x: int, y: int) -> bool: return K.valor(x) < K.valor(y))
			sl.pop_back()
		return sl
	var drag := _farg_drag(hand)
	if drag.size() == 1:
		return drag
	drag = _stege_drag(hand, r.ess_lag)
	if drag.size() == 1 and rng.randf() < 0.7:
		return drag
	var s := hand.duplicate()
	s.sort_custom(func(x: int, y: int) -> bool: return K.valor(x) > K.valor(y))
	var behall := 1 if K.valor(s[0]) >= 12 else 0
	if behall == 1 and K.valor(s[1]) >= 13 and rng.randf() < 0.5:
		behall = 2
	return s.slice(behall)


## Kortet som inte hör till ett fyrkorts färgdrag (tom om inget drag).
static func _farg_drag(hand: Array) -> Array:
	var per := [[], [], [], []]
	for c in hand:
		per[K.farg(c)].append(c)
	for f in 4:
		if per[f].size() == 4:
			for c in hand:
				if K.farg(c) != f:
					return [c]
	return []


static func _stege_drag(hand: Array, ess_lag: bool) -> Array:
	for i in hand.size():
		var rest: Array = []
		for j in hand.size():
			if j != i:
				rest.append(K.valor(hand[j]))
		rest.sort()
		var unika := true
		for j in 3:
			if rest[j] == rest[j + 1]:
				unika = false
		if unika and (rest[3] - rest[0] <= 4 or (ess_lag and rest[3] == 14 and rest[2] <= 5)):
			return [hand[i]]
	return []


## Medel och svår: provar alla 32 sätt att behålla kort och simulerar nya kort ur de okända.
static func _byte_mc(vy: Dictionary, niva: int, rng: RandomNumberGenerator) -> Array:
	var hand: Array = vy.hand
	var pool := okanda(vy)
	var r = vy.regler
	var antal := 30 if niva == MEDEL else 110
	var bast := -1e9
	var bast_sl: Array = []
	for mask in 32:
		var behall: Array = []
		var sl: Array = []
		for i in 5:
			if mask & (1 << i):
				behall.append(hand[i])
			else:
				sl.append(hand[i])
		if sl.size() > vy.max_byte:
			continue
		var u := 0.0
		var k := sl.size()
		if k == 0:
			u = _nytta(H.nyckel(hand, r.ess_lag), vy, niva)
		elif k == 1:
			# exakt: gå igenom alla okända kort
			for c in pool:
				u += _nytta(H.nyckel(behall + [c], r.ess_lag), vy, niva)
			u /= pool.size()
		else:
			var m := antal if k < 5 else antal / 2
			for s in m:
				u += _nytta(H.nyckel(behall + _dra(pool, k, rng), r.ess_lag), vy, niva)
			u /= m
		# fler byten kvar: ett drag är värt mer än poängen nu
		if vy.byten_kvar > 1 and k > 0:
			u += 0.02 * k
		if u > bast + 1e-9:
			bast = u
			bast_sl = sl
	return bast_sl


## Hur bra en hand är för en robot: poängen den ger, och för svår robot chansen att den är bäst vid bordet.
static func _nytta(nyck: int, vy: Dictionary, niva: int) -> float:
	var kat := H.kategori(nyck)
	var pts: float = vy.regler.kat_poang(kat)
	if pts <= 0.0:
		return 0.0
	var inom := float((nyck % H.BAS) / 50625) / 14.0  # högsta avgörande valör, 0–1
	if niva == MEDEL:
		return pts + 0.4 * inom
	var under := 0.0
	for i in kat:
		under += FORDELNING[i]
	var f: float = under + FORDELNING[kat] * inom
	return pts * pow(clampf(f, 0.0, 1.0), vy.n - 1)


## Sista bytet räknas inte som pokerhand: sikta på sticken (behåll höga kort, och Chicago-chans).
static func _byte_for_stick(vy: Dictionary, niva: int, rng: RandomNumberGenerator) -> Array:
	var hand: Array = vy.hand
	var sl: Array = []
	if niva == LATT:
		# den lätta roboten tänker som vid pokerbyte
		return _byte_enkel(hand, vy.regler, rng)
	var hoga := 0
	for c in hand:
		if K.valor(c) >= 13:
			hoga += 1
	var grans := 12 if hoga >= 3 else 13
	for c in hand:
		if K.valor(c) < grans:
			sl.append(c)
	# svår robot: behåll en låg tvåa som kan ge dubbel stickpoäng om den är ensam i sin färg
	if niva == SVAR and vy.regler.tvaa_bonus and sl.size() >= 4:
		for c in sl:
			if K.valor(c) == 2:
				sl.erase(c)
				break
	return sl


# ================================================================== chicago
static func valj_chicago(vy: Dictionary, niva: int, rng: RandomNumberGenerator) -> bool:
	if not vy.far_ropa:
		return false
	var r = vy.regler
	var hoga := 0
	for c in vy.hand:
		if K.valor(c) >= 12:
			hoga += 1
	# husregeln: den som har nått målet men saknar Chicago måste ta en Chicago för att vinna
	var behover: bool = r.chicago_kravs_for_vinst and r.chicago_tillatet and vy.poang[vy.jag] >= r.malpoang and not vy.chicago_tagen[vy.jag]
	if hoga < (2 if behover else 3):
		return false
	var antal: int = [30, 80, 200][niva]
	var chans := chicago_chans(vy, antal, rng)
	var ev: float = chans * r.chicago_poang - (1.0 - chans) * r.chicago_straff
	var annars: float = float(r.stick_poang) / vy.n
	if behover:
		return chans > [0.6, 0.3, 0.22][niva]
	match niva:
		LATT:
			return chans > 0.85
		MEDEL:
			return chans > 0.7 and ev > annars
	# svår: vägs mot målet, nära vinst tar den större risk
	var mal_nara: bool = vy.poang[vy.jag] + r.chicago_poang >= r.malpoang and r.vinna_pa_stick
	return ev > annars * 1.2 and chans > (0.45 if mal_nara else 0.55)


## Chansen att ta alla fem stick, uppskattad med slumpade motståndarhänder.
static func chicago_chans(vy: Dictionary, antal: int, rng: RandomNumberGenerator) -> float:
	var me: int = vy.jag
	var n: int = vy.n
	var pool := okanda(vy)
	var ut: int = me if vy.regler.chicago_spelar_ut else (vy.givare + 1) % n
	var lyckat := 0
	for s in antal:
		var hander := _fordela(vy, pool, rng)
		var res := _simulera(hander, ut, [], 1, me, false, n, vy.regler, -1, rng)
		if res.chicago_ok:
			lyckat += 1
	return float(lyckat) / antal


# ================================================================== stick
static func valj_kort(vy: Dictionary, niva: int, rng: RandomNumberGenerator) -> int:
	var tillatna: Array = vy.tillatna
	if tillatna.size() == 1:
		return tillatna[0]
	if niva == LATT and rng.randf() < 0.3:
		return tillatna[rng.randi_range(0, tillatna.size() - 1)]
	if niva == SVAR:
		return _kort_mc(vy, rng)
	return heuristik(vy.hand, tillatna, vy.stick, vy.stick_nr, vy.jag, vy.chicago, vy.chicago_sprack, vy.n)


static func _lagst(a: Array) -> int:
	var b: int = a[0]
	for c in a:
		if K.valor(c) < K.valor(b):
			b = c
	return b


static func _hogst(a: Array) -> int:
	var b: int = a[0]
	for c in a:
		if K.valor(c) > K.valor(b):
			b = c
	return b


## Enkel men vettig spelstrategi: spara höga kort till sista sticket, försök spräcka andras Chicago,
## och spela högt när man själv ropat.
static func heuristik(hand: Array, tillatna: Array, pagaende: Array, stick_nr: int, jag: int, chicago: int, sprack: bool, n: int) -> int:
	var aktiv := chicago >= 0 and not sprack
	if pagaende.is_empty():
		if aktiv and chicago == jag:
			return _hogst(tillatna)
		if aktiv:
			return _hogst(tillatna)
		if stick_nr == 4 and tillatna.size() == 2:
			return _lagst(tillatna)  # spara det högre till sista sticket
		return _lagst(tillatna)
	var f := K.farg(pagaende[0][1])
	var leder := Motor.stickvinnare(pagaende)
	var kan_folja := K.farg(tillatna[0]) == f
	if aktiv and chicago == jag:
		var h := _hogst(tillatna)
		return h if kan_folja else _lagst(tillatna)
	if aktiv:
		if not kan_folja:
			return _lagst(tillatna)
		var caller_spelat := false
		for x in pagaende:
			if x[0] == chicago:
				caller_spelat = true
		if leder[0] == chicago:
			# slå ropet med lägsta kort som räcker
			var slar: Array = []
			for c in tillatna:
				if K.valor(c) > K.valor(leder[1]):
					slar.append(c)
			return _lagst(slar) if not slar.is_empty() else _lagst(tillatna)
		if not caller_spelat:
			return _hogst(tillatna)
		return _lagst(tillatna)
	return _lagst(tillatna)


## Svår robot: provar varje tillåtet kort mot många slumpade fördelningar av de okända korten
## (som stämmer med vilka färger motståndarna visat sig sakna) och spelar resten med heuristiken.
static func _kort_mc(vy: Dictionary, rng: RandomNumberGenerator) -> int:
	var tillatna: Array = vy.tillatna
	var pool := okanda(vy)
	var antal := 36
	var bast := -1e9
	var bast_kort: int = tillatna[0]
	var varde := {}
	for c in tillatna:
		varde[c] = 0.0
	for s in antal:
		var hander := _fordela(vy, pool, rng)
		for c in tillatna:
			var h := hander.duplicate(true)
			var res := _simulera(h, vy.utspelare, vy.stick, vy.stick_nr, vy.jag, vy.chicago_sprack, vy.n, vy.regler, c, rng, vy.chicago)
			varde[c] += _resultat_nytta(res, vy)
	for c in tillatna:
		# lika värde: spela lägsta kortet
		var v: float = varde[c] - 0.001 * K.valor(c)
		if v > bast:
			bast = v
			bast_kort = c
	return bast_kort


static func _resultat_nytta(res: Dictionary, vy: Dictionary) -> float:
	var r = vy.regler
	var me: int = vy.jag
	var u := 0.0
	if vy.chicago >= 0 and not vy.chicago_sprack:
		if vy.chicago == me:
			return float(r.chicago_poang) if res.chicago_ok else -float(r.chicago_straff)
		u += (-0.4 * r.chicago_poang) if res.chicago_ok else 0.5 * r.chicago_straff
		if r.chicago_avbryt and not res.chicago_ok:
			return u
	if res.sista == me:
		u += r.tvaa_poang if r.tvaa_bonus and K.valor(res.sista_kort) == 2 else r.stick_poang
	return u


## En gissad fördelning av de okända korten till motståndarna. Spelaren själv behåller sin hand.
static func _fordela(vy: Dictionary, pool: Array, rng: RandomNumberGenerator) -> Array:
	var n: int = vy.n
	var me: int = vy.jag
	for forsok in 25:
		var p := pool.duplicate()
		K.blanda(p, rng)
		var hander: Array = []
		var ok := true
		for q in n:
			if q == me:
				hander.append(vy.hand.duplicate())
				continue
			var behov: int = vy.kvar[q]
			var h: Array = []
			var i := 0
			while h.size() < behov and i < p.size():
				var c: int = p[i]
				if forsok < 24 and vy.renons[q].has(K.farg(c)):
					i += 1
					continue
				h.append(c)
				p.remove_at(i)
			if h.size() < behov:
				ok = false
				break
			hander.append(h)
		if ok:
			return hander
	return []


## Spelar klart given från ett givet läge. forsta = kortet som spelaren 'jag' spelar först (eller -1).
static func _simulera(hander: Array, ut: int, pagaende: Array, stick_nr: int, jag: int, sprack: bool, n: int, r, forsta: int, rng: RandomNumberGenerator, chicago := -2) -> Dictionary:
	if chicago == -2:
		chicago = jag  # Chicago-uppskattning: jag har ropat
	var s := pagaende.duplicate(true)
	var nr := stick_nr
	var tur: int = (ut + s.size()) % n
	var sista := -1
	var sista_kort := -1
	var ok := true
	if hander.is_empty():
		return {"chicago_ok": false, "sista": -1, "sista_kort": -1}
	while nr <= 5:
		var hand: Array = hander[tur]
		if hand.is_empty():
			break
		var till := Motor.tillatna_kort(hand, s)
		var c: int
		if tur == jag and forsta >= 0:
			c = forsta
			forsta = -1
		else:
			c = heuristik(hand, till, s, nr, tur, chicago, not ok or sprack, n)
		hand.erase(c)
		s.append([tur, c])
		if s.size() < n:
			tur = (tur + 1) % n
			continue
		var v := Motor.stickvinnare(s)
		if chicago >= 0 and v[0] != chicago:
			ok = false
			if chicago == jag and forsta < 0 and pagaende.is_empty() and stick_nr == 1:
				return {"chicago_ok": false, "sista": -1, "sista_kort": -1}
		sista = v[0]
		sista_kort = v[1]
		tur = v[0]
		s = []
		nr += 1
	return {"chicago_ok": ok and chicago >= 0 and not sprack, "sista": sista, "sista_kort": sista_kort}
