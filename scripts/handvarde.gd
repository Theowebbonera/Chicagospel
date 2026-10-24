extends RefCounted
## Värdering och jämförelse av pokerhänder med fem kort.
## nyckel(): ett heltal där större = bättre hand (kategori först, sedan avgörande valörer i ordning).

const K := preload("res://scripts/kort.gd")

enum {HOGT, PAR, TVA_PAR, TRISS, STEGE, FARG, KAK, FYRTAL, FARGSTEGE, ROYAL}

const KAT_NAMN := ["Högt kort", "Par", "Två par", "Triss", "Stege", "Färg", "Kåk", "Fyrtal", "Färgstege", "Royal straight flush"]
## Namnen på poängvärdena i regelinställningarna, i kategoriordning.
const KAT_REGEL := ["", "p_par", "p_tva_par", "p_triss", "p_stege", "p_farg", "p_kak", "p_fyrtal", "p_fargstege", "p_royal"]
const BAS := 759375  # 15^5: nyckel = kat * BAS + avgörande valörer i basen 15


static func kategori(nyck: int) -> int:
	return nyck / BAS


## Kategori och avgörande valörer (högst först) för en hand med fem kort.
static func analys(hand: Array, ess_lag := true) -> Array:
	var cnt := PackedInt32Array()
	cnt.resize(15)
	var flush := hand.size() == 5
	var f0: int = hand[0] / 13 if hand.size() > 0 else 0
	for c in hand:
		cnt[c % 13 + 2] += 1
		if c / 13 != f0:
			flush = false
	var fyra := 0
	var tre := 0
	var par: Array = []
	var ett: Array = []
	for r in range(14, 1, -1):
		match cnt[r]:
			4:
				fyra = r
			3:
				tre = r
			2:
				par.append(r)
			1:
				ett.append(r)
	var stege := 0
	if ett.size() == 5:
		if ett[0] - ett[4] == 4:
			stege = ett[0]
		elif ess_lag and ett[0] == 14 and ett[1] == 5:
			stege = 5  # ess-låg stege: E-2-3-4-5, femman är högst
	if stege > 0 and flush:
		return [ROYAL if stege == 14 else FARGSTEGE, [stege]]
	if fyra > 0:
		return [FYRTAL, [fyra] + ett]
	if tre > 0 and par.size() == 1:
		return [KAK, [tre, par[0]]]
	if flush:
		return [FARG, ett]
	if stege > 0:
		return [STEGE, [stege]]
	if tre > 0:
		return [TRISS, [tre] + ett]
	if par.size() == 2:
		return [TVA_PAR, par + ett]
	if par.size() == 1:
		return [PAR, par + ett]
	return [HOGT, ett]


static func nyckel(hand: Array, ess_lag := true) -> int:
	var a := analys(hand, ess_lag)
	var n: int = a[0]
	var tb: Array = a[1]
	for i in 5:
		n = n * 15 + (tb[i] if i < tb.size() else 0)
	return n


## Hela värderingen: {kat, nyckel, namn}
static func varde(hand: Array, ess_lag := true) -> Dictionary:
	var a := analys(hand, ess_lag)
	return {"kat": a[0], "nyckel": nyckel(hand, ess_lag), "namn": namn_for(a[0], a[1], hand)}


static func namn_for(kat: int, tb: Array, hand: Array) -> String:
	var f := ""
	if hand.size() > 0:
		f = K.FARG_NAMN[K.farg(hand[0])]
	match kat:
		PAR:
			return "Par i %s" % K.VALOR_PLURAL[tb[0]]
		TVA_PAR:
			return "Två par, %s och %s" % [K.VALOR_PLURAL[tb[0]], K.VALOR_PLURAL[tb[1]]]
		TRISS:
			return "Triss i %s" % K.VALOR_PLURAL[tb[0]]
		STEGE:
			return "Stege, %s högst" % K.VALOR_NAMN[tb[0]]
		FARG:
			return "Färg i %s, %s högst" % [f, K.VALOR_NAMN[tb[0]]]
		KAK:
			return "Kåk, %s över %s" % [K.VALOR_PLURAL[tb[0]], K.VALOR_PLURAL[tb[1]]]
		FYRTAL:
			return "Fyrtal i %s" % K.VALOR_PLURAL[tb[0]]
		FARGSTEGE:
			return "Färgstege i %s, %s högst" % [f, K.VALOR_NAMN[tb[0]]]
		ROYAL:
			return "Royal straight flush i %s" % f
	return "%s högst" % K.VALOR_NAMN[tb[0]].capitalize() if tb.size() > 0 else "Inga kort"


## -1, 0 eller 1 som jämförelse mellan två händer.
static func jamfor(a: Array, b: Array, ess_lag := true) -> int:
	var na := nyckel(a, ess_lag)
	var nb := nyckel(b, ess_lag)
	return 0 if na == nb else (1 if na > nb else -1)
