extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_regler.gd
## Handvärdering, jämförelser, bekänna färg, poängräkning, sista sticket, tvåan, Chicago och omblandning.

const K := preload("res://scripts/kort.gd")
const H := preload("res://scripts/handvarde.gd")
const Motor := preload("res://scripts/motor.gd")
const Regler := preload("res://scripts/regler.gd")
const Robot := preload("res://scripts/robot.gd")

var fel := 0
var antal := 0


func _ok(villkor: bool, text: String) -> void:
	antal += 1
	if not villkor:
		fel += 1
		print("FEL: ", text)


## Klassiska regler (första versionens standard) för de äldre testerna.
func _klassisk():
	var r := Regler.new()
	r.klassiska()
	return r


func _kat(t: String, ess_lag := true) -> int:
	return H.varde(K.las(t), ess_lag).kat


func _storre(a: String, b: String, text: String) -> void:
	_ok(H.jamfor(K.las(a), K.las(b)) == 1, text + " (" + a + " > " + b + ")")


func _init() -> void:
	_handvardering()
	_jamforelser()
	_bekanna()
	_poangrakning()
	_sticken()
	_chicago()
	_omblandning()
	_robot_fuskar_inte()
	_husregler()
	print("%d kontroller, %d fel" % [antal, fel])
	quit(1 if fel else 0)


func _handvardering() -> void:
	_ok(_kat("AS KD 9H 7C 3S") == H.HOGT, "högt kort")
	_ok(_kat("AS AD 9H 7C 3S") == H.PAR, "par")
	_ok(_kat("AS AD 9H 9C 3S") == H.TVA_PAR, "två par")
	_ok(_kat("7S 7D 7H 9C 3S") == H.TRISS, "triss")
	_ok(_kat("5S 6D 7H 8C 9S") == H.STEGE, "stege")
	_ok(_kat("10S JD QH KC AS") == H.STEGE, "stege ess högt")
	_ok(_kat("AS 2D 3H 4C 5S") == H.STEGE, "ess-låg stege")
	_ok(_kat("AS 2D 3H 4C 5S", false) == H.HOGT, "ess-låg stege avstängd")
	_ok(_kat("QS KD AH 2C 3S") == H.HOGT, "ingen stege runt hörnet")
	_ok(_kat("2H 7H 9H JH KH") == H.FARG, "färg")
	_ok(_kat("KS KD KH 4C 4S") == H.KAK, "kåk")
	_ok(_kat("9S 9D 9H 9C 2S") == H.FYRTAL, "fyrtal")
	_ok(_kat("5C 6C 7C 8C 9C") == H.FARGSTEGE, "färgstege")
	_ok(_kat("AD 2D 3D 4D 5D") == H.FARGSTEGE, "ess-låg färgstege är inte royal")
	_ok(_kat("10H JH QH KH AH") == H.ROYAL, "royal straight flush")
	_ok(H.varde(K.las("KS KD KH 4C 4S")).namn == "Kåk, kungar över fyror", "namn kåk")
	_ok(H.varde(K.las("AS 2D 3H 4C 5S")).namn == "Stege, femma högst", "namn ess-låg stege")
	_ok(H.varde(K.las("JS JD 9H 7C 3S")).namn == "Par i knektar", "namn par")
	var r := Regler.new()
	_ok(r.kat_poang(H.PAR) == 1 and r.kat_poang(H.FYRTAL) == 8 and r.kat_poang(H.FARGSTEGE) == 10 and r.kat_poang(H.ROYAL) == 52, "standardtabell (husregler)")
	_ok(r.stick_poang == 2 and r.tvaa_poang == 5 and r.tvaa_bonus, "standard: sista sticket 2, ut på en tvåa 5")
	_ok(r.fyrtal_nollstaller and r.poang_vid_given == 1 and r.poang_byten == 0 and r.poang_efter_stick and r.visa_vid_rundslut, "standard: poäng vid given och efter sticket, visas efter sticket")
	_ok(r.kopstopp_pa and r.kopstopp == 41 and r.chicago_min == 15 and r.chicago_en_gang, "standard: köpstopp 41, Chicago från 15, en gång per parti")
	# äldre sparfil (före husreglerna) läses inte in, ny sparfil behåller sina värden
	var cf := ConfigFile.new()
	cf.set_value("regler", "stick_poang", 5)
	cf.set_value("regler", "malpoang", 40)
	var r2 := Regler.new()
	r2.ladda(cf)
	_ok(r2.stick_poang == 2 and r2.malpoang == 52, "gammal sparfil ger husreglerna")
	cf = ConfigFile.new()
	r2.stick_poang = 4
	r2.malpoang = 40
	r2.spara(cf)
	var r3 := Regler.new()
	r3.ladda(cf)
	_ok(r3.stick_poang == 4 and r3.malpoang == 40, "ny sparfil behåller egna värden")
	r.theos_tabell()
	_ok(r.kat_poang(H.FYRTAL) == 8 and r.kat_poang(H.FARGSTEGE) == 10, "Theos tabell")


func _jamforelser() -> void:
	_storre("2S 3D 4H 5C 6S", "AS 2D 3H 4C 5S", "sexa-hög stege slår ess-låg")
	_storre("10S JD QH KC AS", "9S 10D JH QC KS", "ess-hög stege bäst")
	_storre("AS AD 4H 3C 2S", "KS KD QH JC 9S", "par i ess slår par i kungar")
	_storre("KS KD QH 3C 2S", "KH KC JH 10C 9S", "kicker avgör vid lika par")
	_storre("AS AD 3H 3C 2S", "KS KD QH QC AH", "två par: högsta paret avgör")
	_storre("KS KD 5H 5C 2S", "KH KC 4H 4D AS", "två par: andra paret avgör")
	_storre("2S 2D 2H AC AS", "KS KD KH 3C 4S", "kåk är bättre än triss")
	_storre("3S 3D 3H 2C 2S", "2H 2C 2D AC AH", "kåk avgörs av trissen")
	_storre("2H 4H 6H 8H KH", "AS KS QS JS 9D", "färg slår stege-lös hand")
	_storre("2H 3H 4H 5H 7H", "AS 2D 3H 4C 5S", "färg slår stege")
	_storre("AC 2C 3C 4C 5C", "AS AD AH AC KS", "färgstege slår fyrtal")
	_ok(H.jamfor(K.las("KS KD QH 3C 2S"), K.las("KH KC QD 3D 2H")) == 0, "exakt lika händer i olika färger")
	_ok(H.jamfor(K.las("AS 2D 3H 4C 5S"), K.las("AH 2C 3D 4S 5H")) == 0, "två ess-låga stegar är lika")


func _bekanna() -> void:
	var hand := K.las("AS 5H 9H KD 2C")
	var t := Motor.tillatna_kort(hand, [[0, K.las("7H")[0]]])
	_ok(t.size() == 2 and K.las("5H")[0] in t and K.las("9H")[0] in t, "måste bekänna hjärter")
	t = Motor.tillatna_kort(hand, [[0, K.las("7D")[0]]])
	_ok(t.size() == 1 and t[0] == K.las("KD")[0], "enda rutern måste spelas")
	t = Motor.tillatna_kort(K.las("AS 5H 9H 2C"), [[0, K.las("7D")[0]]])
	_ok(t.size() == 4, "renons i ruter: alla kort tillåtna")
	_ok(Motor.tillatna_kort(hand, []).size() == 5, "utspel: alla kort tillåtna")
	var s := [[0, K.las("7H")[0]], [1, K.las("AS")[0]], [2, K.las("9H")[0]]]
	_ok(Motor.stickvinnare(s)[0] == 2, "högsta i utspelad färg vinner, inte högsta kortet")


## Motor med n spelare där korten sätts för hand efter given.
func _motor(n: int, r, givare := 0) -> RefCounted:
	var m := Motor.new()
	var namn: Array = []
	for i in n:
		namn.append("S%d" % i)
	m.starta(namn, r, 7, givare)
	m.ny_giv()
	return m


func _satt_hander(m, hander: Array) -> void:
	# lägg tillbaka givna kort i talongen och ge de önskade
	var anv := {}
	for h in hander:
		for c in K.las(h):
			anv[c] = true
	var lek: Array = []
	for c in 52:
		if not anv.has(c):
			lek.append(c)
	m.lek = lek
	m.hander = []
	for h in hander:
		m.hander.append(K.las(h))


func _poangrakning() -> void:
	# ett byte som räknas, alla behåller sina kort
	var r = _klassisk()
	r.antal_byten = 1
	r.poang_byten = 2
	r.chicago_tillatet = false
	var m := _motor(3, r)  # givare 0, förhand 1
	_satt_hander(m, ["KS KD 5H 3C 2S", "QS QD 8H 7C 6S", "9S 9D 9H 4C 2D"])
	for p in [1, 2, 0]:
		_ok(m.byt(p, []), "byte noll kort för " + str(p))
	_ok(m.poang == [0, 0, 3], "bara bästa handen (triss) får poäng: " + str(m.poang))
	_ok(m.fas == Motor.Fas.STICK, "sticken börjar efter sista bytet")

	# lika händer: standard = den som visar först (förhand först)
	for regel in 3:
		r = _klassisk()
		r.antal_byten = 1
		r.poang_byten = 2
		r.chicago_tillatet = false
		r.lika_regel = regel
		m = _motor(3, r)  # förhand = 1
		_satt_hander(m, ["KS KD QH 3C 2S", "4S 5D 8H 9C JS", "KH KC QD 3D 2H"])
		for p in [1, 2, 0]:
			m.byt(p, [])
		var vant: Array = [[0, 0, 1], [0, 0, 0], [1, 0, 1]][regel]
		_ok(m.poang == vant, "lika-regel %d ger %s, fick %s" % [regel, vant, m.poang])

	# högt kort ger inga poäng
	r = _klassisk()
	r.antal_byten = 1
	r.poang_byten = 2
	m = _motor(2, r)
	_satt_hander(m, ["AS QD 9H 7C 3S", "KS JD 8H 6C 2S"])
	m.byt(1, [])
	m.byt(0, [])
	_ok(m.poang == [0, 0], "ingen poäng för högt kort")

	# standard: tre byten, poäng efter byte 1 och 2 men inte efter det tredje
	r = _klassisk()
	r.chicago_tillatet = false
	m = _motor(2, r)
	_satt_hander(m, ["AS AD 9H 7C 3S", "KS JD 8H 6C 2S"])
	var visningar := 0
	for b in 3:
		m.byt(1, [])
		m.byt(0, [])
	for e in m.ta_handelser():
		if e.typ == "poang" and e.orsak == "hand":
			visningar += 1
		_ok(e.typ != "visa" and not e.has("kort") or e.typ == "giv" or e.typ == "spela" or e.typ == "stick" or e.typ == "byte", "händelse avslöjar inga kort: " + e.typ)
		if e.typ == "poang":
			_ok(e.text == "par", "poängtexten är bara handtypen: " + e.text)
	_ok(visningar == 2 and m.poang == [2, 0], "poäng efter två av tre byten (%d visningar, %s)" % [visningar, m.poang])

	# poäng direkt vid given, dubbelt
	r = _klassisk()
	r.poang_vid_given = 2
	var hittad := false
	for fro in 40:
		var m2 := Motor.new()
		m2.starta(["A", "B", "C", "D"], r, fro, 0)
		m2.ny_giv()
		for e in m2.ta_handelser():
			if e.typ == "poang" and e.orsak == "hand":
				var kat: int = H.varde(m2.hander[e.spelare], true).kat
				_ok(e.poang == 2 * r.kat_poang(kat), "dubbla poäng vid given")
				hittad = true
		if hittad:
			break
	_ok(hittad, "någon giv gav poäng vid given")

	# poäng sista bytet räknas om regeln är på
	r = _klassisk()
	r.poang_byten = 2
	r.chicago_tillatet = false
	m = _motor(2, r)
	_satt_hander(m, ["AS AD 9H 7C 3S", "KS JD 8H 6C 2S"])
	for b in 3:
		m.byt(1, [])
		m.byt(0, [])
	_ok(m.poang == [3, 0], "poäng efter alla tre byten med regeln på")

	# målpoäng nås på pokerhand
	r = _klassisk()
	r.antal_byten = 1
	r.poang_byten = 2
	m = _motor(2, r)
	m.satt_poang([50, 0])
	_satt_hander(m, ["AS AD 9H 9C 3S", "KS JD 8H 6C 2S"])
	m.byt(1, [])
	m.byt(0, [])
	_ok(m.fas == Motor.Fas.SLUT and m.vinnare == 0, "vinst vid 52 på två par")


## Spelar fem stick med fasta kort. ordning[i] = kortet varje spelare spelar i sticket i tur och ordning.
func _spela_alla(m, drag: Array) -> void:
	for d in drag:
		for c in K.las(d):
			var ok: bool = m.spela(m.tur, c)
			_ok(ok, "tillåtet drag %s av %d" % [K.namn(c), m.tur])
			if m.fas != Motor.Fas.STICK:
				return


func _stickmotor(hander: Array, mod: Callable = func(_r): pass) -> RefCounted:
	var r = _klassisk()
	r.antal_byten = 0
	r.chicago_tillatet = false
	mod.call(r)
	var m := _motor(hander.size(), r)  # givare 0 → förhand 1 spelar ut
	_satt_hander(m, hander)
	return m


func _sticken() -> void:
	# två spelare, förhand (1) spelar ut
	var m := _stickmotor(["AS KS 3H 4H 5D", "2S 7H 8H 9C 6D"])
	_ok(m.fas == Motor.Fas.STICK and m.tur == 1, "förhand spelar ut")
	_ok(not m.spela(0, K.las("AS")[0]), "fel spelare får inte spela")
	m.spela(1, K.las("7H")[0])
	_ok(not m.spela(0, K.las("AS")[0]), "måste bekänna hjärter")
	m.spela(0, K.las("3H")[0])  # 1 tar
	_ok(m.tur == 1 and m.stick_vunna[1] == 1, "den som tar sticket spelar ut")
	_spela_alla(m, ["8H 4H", "9C 5D", "6D KS"])
	# sista sticket: 1 leder 2S, 0 måste bekänna med AS
	m.spela(1, K.las("2S")[0])
	m.spela(0, K.las("AS")[0])
	_ok(m.poang == [2, 0], "sista sticket ger 2 poäng: " + str(m.poang))
	_ok(m.fas == Motor.Fas.GIV_SLUT, "given slut")

	# tvåa i sista sticket: dubbla poäng
	m = _stickmotor(["AS KS 3H 4H 5D", "2C 7H 8H 9C 6D"])
	_spela_alla(m, ["7H 3H", "8H 4H", "9C 5D", "6D AS"])
	if m.tur == 1:
		m.spela(1, K.las("2C")[0])
		m.spela(0, K.las("KS")[0])
		_ok(m.poang == [0, 5], "ut på en tvåa ger 5: " + str(m.poang))
	else:
		_ok(false, "fel utspelare inför sista sticket")

	# tvåan utan bonus
	m = _stickmotor(["AS KS 3H 4H 5D", "2C 7H 8H 9C 6D"], func(r): r.tvaa_bonus = false)
	_spela_alla(m, ["7H 3H", "8H 4H", "9C 5D", "6D AS", "2C KS"])
	_ok(m.poang == [0, 2], "tvåa utan särskild poäng ger vanliga 2")

	# egna värden: sista sticket 3, ut på en tvåa 7
	m = _stickmotor(["AS KS 3H 4H 5D", "2C 7H 8H 9C 6D"], func(r):
		r.stick_poang = 3
		r.tvaa_poang = 7)
	_spela_alla(m, ["7H 3H", "8H 4H", "9C 5D", "6D AS", "2C KS"])
	_ok(m.poang == [0, 7], "ut på en tvåa med eget värde 7: " + str(m.poang))
	m = _stickmotor(["AS KS 3H 4H 5D", "2S 7H 8H 9C 6D"], func(r): r.stick_poang = 3)
	_spela_alla(m, ["7H 3H", "8H 4H", "9C 5D", "6D KS", "2S AS"])
	_ok(m.poang == [3, 0], "sista sticket med eget värde 3: " + str(m.poang))

	# får inte vinna på sticket
	m = _stickmotor(["AS KS 3H 4H 5D", "2S 7H 8H 9C 6D"], func(r): r.vinna_pa_stick = false)
	m.satt_poang([50, 0])
	_spela_alla(m, ["7H 3H", "8H 4H", "9C 5D", "6D KS", "2S AS"])
	_ok(m.poang == [51, 0] and m.fas == Motor.Fas.GIV_SLUT, "stannar på 51 utan vinst på stick: " + str(m.poang))
	m = _stickmotor(["AS KS 3H 4H 5D", "2S 7H 8H 9C 6D"])
	m.satt_poang([50, 0])
	_spela_alla(m, ["7H 3H", "8H 4H", "9C 5D", "6D KS", "2S AS"])
	_ok(m.poang == [52, 0] and m.fas == Motor.Fas.SLUT and m.vinnare == 0, "vinst på sticket när det är tillåtet: " + str(m.poang))

	# fyra spelare, renons registreras
	m = _stickmotor(["AS 2S 3S 4S 5S", "KH 7H 8H 9C 6D", "QC 2H 3D 4D 5C", "JD 9D 10D 7D 8D"])
	m.spela(1, K.las("KH")[0])
	m.spela(2, K.las("2H")[0])
	m.spela(3, K.las("JD")[0])
	_ok(m.renons[3].has(K.HJARTER), "renons i hjärter registreras")
	m.spela(0, K.las("AS")[0])
	_ok(m.tur == 1, "kung i hjärter tar sticket trots spader ess")


func _chicago() -> void:
	# lyckad chicago: spelare 0 har fyra ess och kung
	var r = _klassisk()
	r.antal_byten = 0
	var m := _motor(3, r)  # förhand 1
	_satt_hander(m, ["AS AH AD AC KS", "2S 3H 4D 5C 6S", "7S 8H 9D 10C JS"])
	_ok(m.fas == Motor.Fas.CHICAGO and m.tur == 1, "chicagofrågan börjar hos förhand")
	_ok(m.ropa_chicago(1, false), "förhand avstår")
	_ok(m.ropa_chicago(2, false), "spelare 2 avstår")
	_ok(m.ropa_chicago(0, true), "spelare 0 ropar")
	_ok(m.fas == Motor.Fas.STICK and m.tur == 0, "den som ropar spelar ut")
	_spela_alla(m, ["AS 2S 7S", "AH 3H 8H", "AD 4D 9D", "AC 5C 10C", "KS 6S JS"])
	_ok(m.poang == [15, 0, 0], "lyckad chicago ger 15 och inga stickpoäng: " + str(m.poang))

	# misslyckad chicago: given avbryts
	m = _motor(3, r)
	_satt_hander(m, ["AS AH AD KC KS", "2S 3H 4D AC 6S", "7S 8H 9D 10C JS"])
	m.ropa_chicago(1, false)
	m.ropa_chicago(2, true)
	_ok(m.chicago == 2 and m.tur == 2, "spelare 2 ropar och spelar ut")
	m.spela(2, K.las("JS")[0])
	m.spela(0, K.las("AS")[0])
	m.spela(1, K.las("2S")[0])
	_ok(m.poang == [0, 0, -15], "misslyckad chicago ger -15: " + str(m.poang))
	_ok(m.fas == Motor.Fas.GIV_SLUT, "given avbryts när chicago spricker")

	# misslyckad chicago utan avbrott: sista sticket räknas ändå
	r = _klassisk()
	r.antal_byten = 0
	r.chicago_avbryt = false
	m = _motor(2, r)  # förhand 1
	_satt_hander(m, ["AS AH AD AC 2S", "KS 3H 4D 5C 6S"])
	m.ropa_chicago(1, true)
	_spela_alla(m, ["KS AS"])
	_ok(m.poang == [0, -15], "sprack i första sticket")
	_spela_alla(m, ["AH 3H", "AD 4D", "AC 5C", "2S 6S"])
	_ok(m.poang == [0, -13], "spelare 1 tar sista sticket trots sprucken chicago: " + str(m.poang))

	# minsta poäng för att ropa
	r = _klassisk()
	r.antal_byten = 0
	r.chicago_min = 10
	m = _motor(2, r)
	_ok(m.fas == Motor.Fas.STICK, "ingen får ropa med 0 poäng när minimum är 10")
	m = Motor.new()
	m.starta(["A", "B"], r, 3, 0)
	m.satt_poang([12, 3])
	m.ny_giv()
	_ok(m.fas == Motor.Fas.CHICAGO and m.tur == 0, "bara spelaren med 12 poäng tillfrågas ")
	_ok(not m.ropa_chicago(1, true), "obehörig får inte ropa")

	# chicago inte tillåtet
	r = _klassisk()
	r.antal_byten = 0
	r.chicago_tillatet = false
	m = _motor(2, r)
	_ok(m.fas == Motor.Fas.STICK, "chicago avstängt går direkt till sticken")

	# chicago som ger vinst: 45 + 15
	r = _klassisk()
	r.antal_byten = 0
	m = _motor(2, r)
	m.satt_poang([45, 0])
	_satt_hander(m, ["AS AH AD AC KS", "2S 3H 4D 5C 6S"])
	m.ropa_chicago(1, false)
	m.ropa_chicago(0, true)
	_spela_alla(m, ["AS 2S", "AH 3H", "AD 4D", "AC 5C", "KS 6S"])
	_ok(m.vinnare == 0 and m.poang[0] == 60, "chicago tar spelaren i mål")


func _bevarade(m) -> bool:
	var sett := {}
	var alla: Array = m.lek + m.slangda
	for h in m.hander:
		alla += h
	for s in m.spelade:
		alla.append(s[1])
	for c in alla:
		if sett.has(c):
			return false
		sett[c] = true
	return sett.size() == 52


func _omblandning() -> void:
	var r = _klassisk()
	var m := Motor.new()
	m.starta(["A", "B", "C", "D", "E", "F"], r, 11, 0)
	m.ny_giv()
	var blandat := false
	for b in 3:
		for i in 6:
			var p: int = m.tur
			var maxb: int = m.max_byte(p)
			_ok(m.byt(p, m.hander[p].slice(0, maxb)), "byt %d kort" % maxb)
			_ok(_bevarade(m), "alla 52 kort finns kvar exakt en gång")
	for e in m.ta_handelser():
		if e.typ == "omblandning":
			blandat = true
	_ok(blandat, "slänghögen blandas om när talongen tar slut")
	for h in m.hander:
		_ok(h.size() == 5, "alla har fem kort efter omblandning")

	r = _klassisk()
	r.blanda_om = false
	m = Motor.new()
	m.starta(["A", "B", "C", "D", "E", "F"], r, 11, 0)
	m.ny_giv()
	var total := 0
	for b in 3:
		for i in 6:
			var p: int = m.tur
			var maxb: int = m.max_byte(p)
			total += maxb
			if maxb < 5:
				_ok(not m.byt(p, m.hander[p].slice(0, 5)), "kan inte byta fler än talongen har")
			_ok(m.byt(p, m.hander[p].slice(0, maxb)), "byte inom talongen")
	_ok(total == 22, "utan omblandning räcker talongen till 22 kort (%d)" % total)
	_ok(_bevarade(m), "korten bevarade utan omblandning")


## Roboten ska fatta samma beslut oavsett vad motståndarna har på hand.
func _robot_fuskar_inte() -> void:
	var r = _klassisk()
	var m := Motor.new()
	m.starta(["A", "B", "C", "D"], r, 5, 0)
	m.ny_giv()
	var p: int = m.tur
	var vy: Dictionary = m.vy(p)
	for k in vy.keys():
		_ok(k != "hander" and k != "lek" and k != "slangda", "vyn innehåller inte " + k)
	for niva in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var a := Robot.valj_byte(m.vy(p), niva, rng)
		# byt motståndarnas händer mot talongens kort
		var spar: Array = m.hander.duplicate(true)
		var lek_spar: Array = m.lek.duplicate()
		for q in 4:
			if q != p:
				var ny: Array = []
				for i in 5:
					ny.append(m.lek.pop_back())
				m.lek.append_array(m.hander[q])
				m.hander[q] = ny
		rng.seed = 99
		var b := Robot.valj_byte(m.vy(p), niva, rng)
		_ok(a == b, "byte nivå %d oberoende av andras kort" % niva)
		m.hander = spar
		m.lek = lek_spar


# ================================================================== husreglerna (standard)
## Lek där spelarna får exakt de angivna händerna vid given. hander[p] som text, givare anger turordningen.
func _lek_for(hander: Array, givare: int) -> Array:
	var n := hander.size()
	var h: Array = []
	var anv := {}
	for t in hander:
		var k := K.las(t)
		h.append(k)
		for c in k:
			anv[c] = true
	var sekvens: Array = []
	for runda in 5:
		for i in n:
			var p := (givare + 1 + i) % n
			sekvens.append(h[p][runda])
	var lek: Array = []
	for c in 52:
		if not anv.has(c):
			lek.append(c)
	sekvens.reverse()
	lek.append_array(sekvens)
	return lek


func _husmotor(hander: Array, totaler: Array, mod: Callable = func(_r): pass) -> RefCounted:
	var r := Regler.new()
	mod.call(r)
	var m := Motor.new()
	var namn: Array = []
	for i in hander.size():
		namn.append("S%d" % i)
	m.starta(namn, r, 3, 0)
	m.poang = totaler.duplicate()
	m.intern = totaler.duplicate()
	m.ta_handelser()
	m.ny_giv(_lek_for(hander, 0))
	return m


## Spelar klart rundan: ingen byter, ingen ropar Chicago, alla spelar första tillåtna kortet.
func _spela_rundan(m) -> void:
	var steg := 0
	while (m.fas == Motor.Fas.BYTE or m.fas == Motor.Fas.CHICAGO or m.fas == Motor.Fas.STICK) and steg < 200:
		steg += 1
		match m.fas:
			Motor.Fas.BYTE:
				m.byt(m.tur, [])
			Motor.Fas.CHICAGO:
				m.ropa_chicago(m.tur, false)
			Motor.Fas.STICK:
				m.spela(m.tur, m.tillatna(m.tur)[0])


func _typer(h: Array) -> Array:
	var ut: Array = []
	for e in h:
		ut.append(e.typ)
	return ut


func _husregler() -> void:
	# --- poäng vid given och efter sticket, visas först efter sticket
	var m := _husmotor(["7C 9D JH KC 2S", "AS AD 9H 7H 3S"], [0, 0])  # förhand = 1 (par i ess)
	var h: Array = m.ta_handelser()
	_ok(not "poang" in _typer(h), "inga poäng visas vid given")
	_ok(m.poang == [0, 0] and m.intern == [0, 1], "givens par räknas i den löpande totalen men visas inte: %s / %s" % [m.poang, m.intern])
	_ok(m.vy(0).poang == [0, 0], "andra ser inte givens poäng")
	_spela_rundan(m)
	h = m.ta_handelser()
	var typer := _typer(h)
	_ok("redovisning" in typer, "rundans poäng redovisas efter sticket")
	var given := 0
	var slut := 0
	for e in h:
		if e.typ == "poang" and e.orsak == "hand":
			if e.nar == "given":
				given += 1
				_ok(e.text == "par" and e.spelare == 1, "givens hand: bara typen 'par'")
			elif e.nar == "sluthand":
				slut += 1
	_ok(given == 1 and slut == 1, "poäng för givens hand och för handen efter sticket (%d, %d)" % [given, slut])
	_ok(m.poang == m.intern and m.poang[1] >= 2, "visade poäng = löpande efter sticket: %s" % [m.poang])
	_ok(typer.find("redovisning") > typer.rfind("spela"), "redovisningen kommer efter sista spelade kortet")

	# --- fyrtal nollställer alla andra (vid given, direkt i den löpande totalen)
	m = _husmotor(["7C 9D JH KC 2S", "9S 9D 9H 9C 3S", "4H 6D 8S 10C QD"], [10, 20, 30])  # förhand 1
	_ok(m.intern == [0, 28, 0], "fyrtal vid given nollställer andra direkt: %s" % [m.intern])
	_ok(m.poang == [10, 20, 30], "nollställningen syns inte förrän efter sticket")
	_ok(not m.har_kopstopp(2), "nollställd spelare har inte längre köpstopp")
	_spela_rundan(m)
	h = m.ta_handelser()
	_ok("nollstall" in _typer(h), "nollställningen redovisas")
	_ok(m.poang[1] >= 36 and m.poang[0] <= 5 and m.poang[2] <= 5, "efter rundan: fyrtalet två gånger, andra nästan noll: %s" % [m.poang])
	m = _husmotor(["7C 9D JH KC 2S", "9S 9D 9H 9C 3S"], [10, 20], func(r): r.fyrtal_nollstaller = false)
	_ok(m.intern == [10, 28], "fyrtal utan nollställning: %s" % [m.intern])

	# --- köpstopp vid 41, även när givens poäng tar spelaren dit
	m = _husmotor(["7C 9D JH KC 2S", "AS AD 9H 7H 3S", "4H 6D 8S 10C QS"], [41, 40, 12])  # förhand 1 får par: 41
	h = m.ta_handelser()
	var over: Array = []
	for e in h:
		if e.typ == "star_over":
			over.append(e.spelare)
	_ok(m.fas == Motor.Fas.BYTE and m.tur == 2, "spelare 1 (41 genom givens par) står över, turen går till 2")
	_ok(1 in over, "köpstopp utlöst av givens poäng")
	_ok(m.max_byte(1) == 0 and m.vy(1).kopstopp and not m.vy(2).kopstopp, "köpstopp syns bara för spelaren själv")
	_ok(m.byt(2, []), "spelare 2 byter")
	_ok(m.tur != 0 or m.fas != Motor.Fas.BYTE, "spelare 0 med 41 står också över")
	h = m.ta_handelser()
	over.clear()
	for e in h:
		if e.typ == "star_over":
			over.append(e.spelare)
	_ok(0 in over, "spelare 0 med 41 från början står över")
	_ok(not m.byt(0, []) and not m.byt(1, []), "köpstopp: byte avvisas")

	# --- Chicago spärrat under 15, men rätten kan nås genom givens poäng
	m = _husmotor(["7C 9D JH KC 2S", "AS AD 9H 7H 3S", "4H 6D 8S 10C QS"], [14, 14, 14], func(r): r.antal_byten = 0)
	_ok(m.fas == Motor.Fas.CHICAGO and m.tur == 1, "bara spelare 1 (14 + par = 15) tillfrågas om Chicago")
	_ok(m.far_ropa(1) and not m.far_ropa(0) and not m.far_ropa(2), "Chicago-rätt från 15 i den löpande totalen")
	_ok(not m.ropa_chicago(0, true) and not m.ropa_chicago(2, true), "under 15 får man inte ropa")
	_ok(m.vy(1).far_ropa and not m.vy(0).far_ropa, "rätten syns bara för spelaren själv")
	for e in m.ta_handelser():
		_ok(e.typ != "chicago_fraga" or not e.has("tur"), "Chicagofrågan avslöjar inte vem som får ropa")

	# --- lyckad Chicago: +15, inga poäng för sluthanden (fyrtal!) och inga stickpoäng
	m = _husmotor(["AS AH AD AC KS", "2S 3H 4D 5C 7S"], [20, 3], func(r):
		r.antal_byten = 0
		r.poang_vid_given = 0)
	_ok(m.fas == Motor.Fas.CHICAGO and m.tur == 0, "bara spelare 0 får ropa")
	m.ropa_chicago(0, true)
	_spela_alla(m, ["AS 2S", "AH 3H", "AD 4D", "AC 5C", "KS 7S"])
	_ok(m.poang == [35, 3], "lyckad Chicago: bara +15, ingen sluthand, inga stickpoäng, ingen nollställning: %s" % [m.poang])
	_ok(m.chicago_tagen == [true, false], "Chicagon är tagen")

	# --- Theos exempel: Chicago spricker, men sista sticket (2) och paret (1) räknas: −15 + 3 = −12
	m = _husmotor(["AS AH 3D 4C KS", "QS 2H KD 5C 6S"], [20, 0], func(r):
		r.antal_byten = 0
		r.poang_vid_given = 0)
	m.ropa_chicago(0, true)
	_spela_alla(m, ["AS 6S", "3D KD", "2H AH", "4C 5C", "QS KS"])
	_ok(m.poang == [8, 0], "Chicago sprack men sista sticket och par räknas (20 − 15 + 2 + 1 = 8): %s" % [m.poang])
	_ok(m.chicago_tagen == [false, false], "misslyckad Chicago förbrukar inte rätten")

	# --- givens poäng räknas även när någon ropar Chicago
	m = _husmotor(["AS AH AD KC KS", "2S 3H 4D 5C 7S"], [20, 0], func(r): r.antal_byten = 0)  # kåk vid given
	m.ropa_chicago(0, true)
	_spela_alla(m, ["AS 2S", "AH 3H", "AD 4D", "KC 5C", "KS 7S"])
	_ok(m.poang == [41, 0], "kåk vid given (6) + Chicago (15): %s" % [m.poang])

	# --- en gång per parti: spärrat efter lyckad Chicago, även efter nollställning; tillåtet efter misslyckad
	var r := Regler.new()
	r.antal_byten = 0
	r.poang_vid_given = 0
	m = Motor.new()
	m.starta(["A", "B"], r, 3, 0)
	m.satt_poang([20, 0])
	m.intern = [20, 0]
	m.ny_giv(_lek_for(["AS AH AD AC KS", "2S 3H 4D 5C 7S"], 0))
	m.ropa_chicago(0, true)
	_spela_alla(m, ["AS 2S", "AH 3H", "AD 4D", "AC 5C", "KS 7S"])
	_ok(m.chicago_tagen[0] and m.vy(1).chicago_tagen[0], "tagen Chicago är offentlig")
	_ok(not m.far_ropa(0), "35 poäng men Chicagon redan tagen: får inte ropa")
	# nollställd av motståndarens fyrtal och sedan över 15 igen: fortfarande spärrad
	m.regler.poang_vid_given = 1
	m.ny_giv(_lek_for(["7C 9D JH KC 2S", "9S 9D 9H 9C 3S"], 1))  # givaren är nu 1, förhand 0
	_ok(m.intern[0] == 0, "nollställd av fyrtal")
	m.intern[0] = 30
	_ok(not m.far_ropa(0), "efter nollställning fortfarande spärrad (tagen)")
	m.regler.chicago_en_gang = false
	_ok(m.far_ropa(0), "med regeln avstängd får man ropa igen")

	# --- robotarna följer reglerna
	m = _husmotor(["7C 9D JH KC 2S", "AS AD 9H 7H 3S"], [10, 10], func(r): r.antal_byten = 0)
	var rng := RandomNumberGenerator.new()
	_ok(not Robot.valj_chicago(m.vy(0), Robot.SVAR, rng), "robot under 15 ropar inte Chicago")
	var vy_k: Dictionary = {"max_byte": 0, "poangsatts": true, "hand": K.las("2S 4D 7H 9C JS"), "regler": Regler.new(), "egna_slangda": [], "spelade": [], "n": 2, "byten_kvar": 2}
	_ok(Robot.valj_byte(vy_k, Robot.SVAR, rng).is_empty(), "robot med köpstopp byter inget")
