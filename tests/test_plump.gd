extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_plump.gd
## Regelmotorn för Plump (scripts/plump.gd): givarnas antal kort, givarens förbjudna bud, bekänna färg,
## stick och poäng (exakt bud 10 + budet, annars plump), och hela partier med 2–6 spelare och slumpade drag.

const Plump := preload("res://scripts/plump.gd")
const Regler := preload("res://scripts/regler.gd")
const K := preload("res://scripts/kort.gd")
const Fas := Plump.Fas

var fel := 0
var kontroller := 0


func _ok(v: bool, t: String) -> void:
	kontroller += 1
	if not v:
		fel += 1
		print("FEL: ", t)


func _init() -> void:
	_rundor()
	_givarens_bud()
	_poang()
	for n in range(2, 7):
		for fro in 6:
			_helt_parti(n, fro, fro % 2 == 0)
	print("%d kontroller, %d fel" % [kontroller, fel])
	quit(1 if fel > 0 else 0)


func _rundor() -> void:
	_ok(Plump.rundlista(4, 10, true) == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "4 spelare 10 ner och upp")
	_ok(Plump.rundlista(4, 10, false) == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1], "bara ner")
	_ok(Plump.rundlista(6, 10, true)[0] == 8, "6 spelare börjar på 8 (52/6)")
	_ok(Plump.rundlista(5, 10, true)[0] == 10, "5 spelare räcker till 10")
	_ok(Plump.rundlista(3, 3, true) == [3, 2, 1, 2, 3], "3 kort")


func _regler(max_kort := 10, upp := true):
	var r := Regler.new()
	r.spel = 1
	r.plump_max = max_kort
	r.plump_upp = upp
	return r


## Givaren får inte bjuda så att summan blir lika med antalet stick.
func _givarens_bud() -> void:
	var m := Plump.new()
	m.starta(["A", "B", "C"], _regler(3), 1, 0)
	m.ny_giv()
	_ok(m.fas == Fas.BUD and m.tur == 1, "budet börjar efter given")
	_ok(m.kort_i_giv == 3 and m.hander[0].size() == 3 and m.hander[2].size() == 3, "3 kort var")
	_ok(m.bjud(1, 1), "B bjuder 1")
	_ok(not m.bjud(1, 1), "B kan inte bjuda igen")
	_ok(m.bjud(2, 1), "C bjuder 1")
	_ok(m.tur == 0, "givaren sist")
	_ok(not 1 in m.tillatna_bud(0), "givaren får inte bjuda 1 (1+1+1 = 3)")
	_ok(m.tillatna_bud(0) == [0, 2, 3], "givarens tillåtna bud")
	_ok(not m.bjud(0, 1), "förbjudet bud nekas")
	_ok(m.bjud(0, 0), "givaren bjuder 0")
	_ok(m.fas == Fas.STICK and m.tur == 1, "lika bud (B och C 1): B, närmast till vänster om given, spelar ut")
	# högst bud spelar ut, också när den sitter längre bort från given
	var m3 := Plump.new()
	m3.starta(["A", "B", "C", "D"], _regler(4), 4, 0)
	m3.ny_giv()
	m3.bjud(1, 0)
	m3.bjud(2, 1)
	m3.bjud(3, 2)
	m3.bjud(0, 2)
	_ok(m3.tur == 3, "D bjöd 2 som givaren men sitter närmare given: D spelar ut (fick %d)" % m3.tur)
	var m4 := Plump.new()
	m4.starta(["A", "B", "C"], _regler(3), 5, 0)
	m4.ny_giv()
	m4.bjud(1, 0)
	m4.bjud(2, 2)
	m4.bjud(0, 0)
	_ok(m4.tur == 2, "C har högst bud och spelar ut (fick %d)" % m4.tur)
	# summan överstiger antalet: inget bud är förbjudet
	var m2 := Plump.new()
	m2.starta(["A", "B", "C"], _regler(2), 2, 0)
	m2.ny_giv()
	m2.bjud(1, 2)
	m2.bjud(2, 2)
	_ok(m2.tillatna_bud(0) == [0, 1, 2], "inget förbjudet när summan redan är för stor")


## Fast lek: kontrollera stick och poäng exakt.
func _poang() -> void:
	var m := Plump.new()
	m.starta(["A", "B"], _regler(2, false), 3, 0)
	# sista kortet ges först: B (förhand) får kort 0, A kort 1, B kort 2, A kort 3
	var es := K.kort(K.SPADER, 14)
	var kung := K.kort(K.SPADER, 13)
	var tva := K.kort(K.HJARTER, 2)
	var tre := K.kort(K.HJARTER, 3)
	m.ny_giv([tre, tva, kung, es])  # sista ges först: B ess, A kung, B tvåa, A trea
	_ok(m.hander[1].has(es) and m.hander[1].has(tva), "B har ess och tvåa")
	m.bjud(1, 1)
	_ok(m.forbjudet_bud(0) == 1, "A får inte bjuda 1")
	m.bjud(0, 0)
	_ok(m.spela(1, es), "B spelar ut ess")
	_ok(not m.spela(0, tre), "A måste bekänna spader")
	_ok(m.spela(0, kung), "A lägger kung")
	_ok(m.stick_vunna[1] == 1 and m.tur == 1, "B tar sticket och spelar ut")
	m.spela(1, tva)
	m.spela(0, tre)
	_ok(m.stick_vunna[0] == 1, "A tar andra sticket med trean")
	_ok(m.poang == [0, 11], "A plump, B 10 + 1 = 11")
	_ok(m.plumpar == [1, 0], "A har en plump")
	_ok(m.fas == Fas.GIV_SLUT, "nästa giv")
	var h := m.ta_handelser()
	var res: Array = h.filter(func(e: Dictionary) -> bool: return e.typ == "plump_resultat")
	_ok(res.size() == 1 and res[0].fick == [0, 11], "resultathändelsen")


func _helt_parti(n: int, fro: int, upp: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + fro * 7 + n
	var namn: Array = []
	for i in n:
		namn.append("S%d" % i)
	var m := Plump.new()
	m.starta(namn, _regler(10, upp), fro)
	var rundor: Array = m.rundor.duplicate()
	var forvantat := 0
	var steg := 0
	while m.fas != Fas.SLUT and steg < 20000:
		steg += 1
		match m.fas:
			Fas.GIV_SLUT:
				m.ny_giv()
				var k: int = rundor[m.giv_nr - 1]
				for p in n:
					if m.hander[p].size() != k:
						_ok(false, "fel antal kort i giv %d" % m.giv_nr)
			Fas.BUD:
				var p: int = m.tur
				var t: Array = m.tillatna_bud(p)
				if p == m.givare:
					var summa := 0
					for q in n:
						if q != p:
							summa += m.bud[q]
					if (m.kort_i_giv - summa) in t:
						_ok(false, "givaren fick bjuda jämnt")
				m.bjud(p, t[rng.randi() % t.size()])
			Fas.STICK:
				var p: int = m.tur
				var t: Array = m.tillatna(p)
				var c: int = t[rng.randi() % t.size()]
				var fore := m.stick_nr
				var stick_fore: Array = m.stick.duplicate()
				m.spela(p, c)
				if not stick_fore.is_empty() and K.farg(c) != K.farg(stick_fore[0][1]):
					for x in m.hander[p] + [c]:
						if x != c and K.farg(x) == K.farg(stick_fore[0][1]):
							_ok(false, "bekände inte färg")
							break
				if m.stick_nr == fore and m.stick.is_empty():
					pass
		var h := m.ta_handelser()
		for e in h:
			if e.typ == "plump_resultat":
				var summa_stick := 0
				for p in n:
					summa_stick += e.stick[p]
					if e.lyckad[p]:
						forvantat += 0
						_ok(e.fick[p] == 10 + e.bud[p], "poäng för exakt bud")
					else:
						_ok(e.fick[p] == 0, "plump ger 0")
				_ok(summa_stick == rundor[m.giv_nr - 1], "alla stick delas ut")
				var bud_summa := 0
				for p in n:
					bud_summa += e.bud[p]
				_ok(bud_summa != rundor[m.giv_nr - 1], "buden går aldrig jämnt ut")
	_ok(m.fas == Fas.SLUT, "partiet tar slut (%d spelare)" % n)
	_ok(m.giv_nr == rundor.size(), "alla givar spelade")
	_ok(m.vinnare >= 0, "vinnare finns")
	for p in n:
		_ok(m.poang[p] <= m.poang[m.vinnare], "vinnaren har flest poäng")
	var _f := forvantat
