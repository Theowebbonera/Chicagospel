extends RefCounted
## Regelmotorn för Chicago. Ren logik utan grafik: styrs med drag (byt, ropa_chicago, spela)
## och lägger allt som händer i en händelselista som grafiken spelar upp i ordning.
##
## Poäng: givens hand (och poäng efter byten) läggs till och visas direkt. Stick-rundans poäng (sluthand, sista
## sticket, tvåan, Chicago) samlas med regeln "visa vid rundslut" (standard) och redovisas när sticket är klart.
## `intern` är totalen inklusive stick-rundans ännu ej visade poäng; under byten och Chicago-frågan är den lika
## med den visade totalen, så köpstopp och Chicago-rätt följer det som syns.

const K := preload("res://scripts/kort.gd")
const H := preload("res://scripts/handvarde.gd")

enum Fas {INTE_STARTAD, BYTE, CHICAGO, STICK, GIV_SLUT, SLUT}

var regler
var namn: Array = []
var n := 0
var poang: Array = []  # visade totaler
var intern: Array = []  # löpande totaler som reglerna använder (dolda under rundan)
var vantande: Array = []  # poänghändelser som redovisas när sticket är klart
var chicago_tagen: Array = []  # per spelare: har lyckats med Chicago i partiet (offentligt)
var royal_vinst := -1
var givare := 0
var giv_nr := 0
var rng := RandomNumberGenerator.new()

var lek: Array = []  # talongen, översta kortet sist
var slangda: Array = []  # slänghögen
var hander: Array = []
var sluthander: Array = []  # händerna när sticken börjar (poängsätts efter sticket)
var egna_slangda: Array = []  # per spelare: egna slängda kort som fortfarande ligger i slänghögen
var fas: int = Fas.INTE_STARTAD
var tur := 0
var gjort := 0  # antal spelare som har agerat i nuvarande runda
var byte_nr := 0  # 1-baserat under bytena
var bytes_antal: Array = []  # [byte][spelare] = antal bytta kort (offentligt)
var star_over: Array = []  # per spelare: står över bytena (köpstopp) – offentligt
var chicago := -1
var chicago_sprack := false
var stick_nr := 0
var stick: Array = []  # [[spelare, kort], ...]
var utspelare := 0
var stick_vunna: Array = []
var spelade: Array = []  # alla kort som spelats i given: [spelare, kort]
var renons: Array = []  # per spelare: {färg: true} när spelaren visat att färgen saknas
var vinnare := -1
var handelser: Array = []


func starta(spelarnamn: Array, r, fro := -1, forsta_givare := -1) -> void:
	regler = r
	namn = spelarnamn.duplicate()
	n = namn.size()
	assert(n >= 2 and n <= 6)
	poang = _nollor()
	intern = _nollor()
	vantande = []
	chicago_tagen = []
	for i in n:
		chicago_tagen.append(false)
	star_over = []
	for i in n:
		star_over.append(false)
	if fro >= 0:
		rng.seed = fro
	else:
		rng.randomize()
	givare = forsta_givare if forsta_givare >= 0 else rng.randi_range(0, n - 1)
	giv_nr = 0
	vinnare = -1
	royal_vinst = -1
	handelser.clear()
	fas = Fas.GIV_SLUT
	_h({"typ": "parti_start", "givare": givare})


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
## Ny giv. fast_lek (för tester) ger kortordningen, där sista elementet ges först.
func ny_giv(fast_lek: Array = []) -> void:
	assert(fas == Fas.GIV_SLUT)
	giv_nr += 1
	if giv_nr > 1:
		givare = (givare + 1) % n
	if fast_lek.is_empty():
		lek = K.ny_lek()
		K.blanda(lek, rng)
	else:
		lek = fast_lek.duplicate()
	slangda = []
	hander = []
	sluthander = []
	egna_slangda = []
	renons = []
	for i in n:
		hander.append([])
		egna_slangda.append([])
		renons.append({})
		star_over[i] = false
	spelade = []
	stick = []
	stick_vunna = _nollor()
	chicago = -1
	chicago_sprack = false
	stick_nr = 0
	byte_nr = 0
	bytes_antal = []
	vantande = []
	_h({"typ": "blanda", "givare": givare, "giv": giv_nr})
	for runda in 5:
		for p in i_ordning(forhand()):
			var c: int = lek.pop_back()
			hander[p].append(c)
			_h({"typ": "giv", "spelare": p, "kort": c})
	_h({"typ": "giv_klar"})
	if regler.poang_vid_given > 0:
		_poangrakning("given", 2 if regler.poang_vid_given == 2 else 1, hander)
		if fas == Fas.SLUT:
			return
	_till_byte(1)


# ------------------------------------------------------------------ byten
func _till_byte(nr: int) -> void:
	if nr > regler.antal_byten:
		_till_chicago()
		return
	byte_nr = nr
	fas = Fas.BYTE
	tur = forhand()
	gjort = 0
	bytes_antal.append(_nollor())
	_h({"typ": "byte_start", "nr": nr, "poangsatts": poangsatts_bytet()})
	_hoppa_over_kopstopp()


## Räknas pokerhänderna direkt efter nuvarande byte?
func poangsatts_bytet() -> bool:
	match int(regler.poang_byten):
		1:
			return byte_nr < regler.antal_byten
		2:
			return true
	return false


## Köpstopp: den som (enligt den löpande totalen) har nått gränsen får inte byta.
func har_kopstopp(p: int) -> bool:
	return regler.kopstopp_pa and intern[p] >= regler.kopstopp


func _hoppa_over_kopstopp() -> void:
	while gjort < n and har_kopstopp(tur):
		star_over[tur] = true
		_h({"typ": "star_over", "spelare": tur, "nr": byte_nr})
		gjort += 1
		tur = (tur + 1) % n
	if gjort >= n:
		_efter_byteomgang()


func _efter_byteomgang() -> void:
	if poangsatts_bytet():
		_poangrakning("byte", 1, hander)
		if fas == Fas.SLUT:
			return
	_till_byte(byte_nr + 1)


func max_byte(p: int) -> int:
	if fas != Fas.BYTE or har_kopstopp(p):
		return 0
	var finns: int = lek.size() + (slangda.size() if regler.blanda_om else 0)
	return mini(mini(regler.max_byte, hander[p].size()), finns)


func byt(p: int, kort: Array) -> bool:
	if fas != Fas.BYTE or p != tur:
		return false
	if kort.size() > max_byte(p):
		return false
	var sett := {}
	for c in kort:
		if not c in hander[p] or sett.has(c):
			return false
		sett[c] = true
	for c in kort:
		hander[p].erase(c)
	var nya: Array = []
	for i in kort.size():
		if lek.is_empty():
			# talongen är slut: blanda slänghögen (utan kort som just slängts) till en ny talong
			lek = slangda
			slangda = []
			K.blanda(lek, rng)
			for q in n:
				egna_slangda[q] = []
			_h({"typ": "omblandning", "antal": lek.size()})
		nya.append(lek.pop_back())
	slangda.append_array(kort)
	egna_slangda[p].append_array(kort)
	hander[p].append_array(nya)
	bytes_antal[byte_nr - 1][p] = kort.size()
	_h({"typ": "byte", "spelare": p, "slangda": kort.duplicate(), "nya": nya, "nr": byte_nr})
	gjort += 1
	if gjort < n:
		tur = (tur + 1) % n
		_hoppa_over_kopstopp()
		return true
	_efter_byteomgang()
	return true


# ------------------------------------------------------------------ poäng
func _poangrakning(nar: String, faktor: int, vilka: Array) -> void:
	var basta := -1
	var lista: Array = []
	var varden := {}
	for p in i_ordning(forhand()):
		var v := H.varde(vilka[p], regler.ess_lag)
		varden[p] = v
		if v.nyckel > basta:
			basta = v.nyckel
			lista = [p]
		elif v.nyckel == basta:
			lista.append(p)
	var kat: int = varden[lista[0]].kat
	var pts: int = regler.kat_poang(kat) * faktor
	if kat == H.HOGT or pts <= 0:
		_poanghandelse({"typ": "ingen_poang", "nar": nar})
		return
	if lista.size() > 1:
		match regler.lika_regel:
			0:
				lista = [lista[0]]
			1:
				_poanghandelse({"typ": "lika", "spelare": lista.duplicate(), "hand": H.KAT_NAMN[kat].to_lower(), "nar": nar})
				return
	# bara handtypen blir offentlig: inga kort vänds och inga valörer eller färger avslöjas
	for p in lista:
		_ge_poang(p, pts, "hand", H.KAT_NAMN[kat].to_lower(), nar)
		if kat == H.FYRTAL and regler.fyrtal_nollstaller:
			_nollstall_andra(p, nar)
		if kat == H.ROYAL and regler.royal_vinner and royal_vinst < 0:
			royal_vinst = p
	# givens hand och byten redovisas direkt; sluthanden hör till stick-rundan (avgörs i _rundans_slut)
	if nar != "sluthand":
		if royal_vinst >= 0:
			_vinst(royal_vinst)
			return
		_kolla_vinst()


## Poäng till den löpande totalen. Visas direkt eller vid rundslut beroende på regeln.
func _ge_poang(p: int, pts: int, orsak: String, text: String, nar := "") -> void:
	var nytt: int = intern[p] + pts
	if pts > 0 and not regler.vinna_pa_stick and (orsak == "stick" or orsak == "chicago"):
		nytt = mini(nytt, maxi(intern[p], regler.malpoang - 1))
	var faktiskt: int = nytt - intern[p]
	intern[p] = nytt
	_poanghandelse({"typ": "poang", "spelare": p, "poang": faktiskt, "orsak": orsak, "text": text, "nar": nar, "begransad": faktiskt != pts})


## Fyrtal: alla andra spelares total blir noll.
func _nollstall_andra(p: int, nar := "") -> void:
	var vilka: Array = []
	for q in n:
		if q != p:
			intern[q] = 0
			vilka.append(q)
	_poanghandelse({"typ": "nollstall", "spelare": p, "nollstallda": vilka, "nar": nar})


## Givens hand (och poäng efter byten) visas direkt. Stick-rundans poäng (sluthand, sista sticket, tvåan,
## Chicago) visas med regeln "visa vid rundslut" först när sticket är klart.
func _poanghandelse(e: Dictionary) -> void:
	var stickrunda: bool = e.get("nar", "") == "sluthand" or e.get("orsak", "") in ["stick", "chicago", "chicago_miss"]
	if regler.visa_vid_rundslut and stickrunda:
		vantande.append(e)
	else:
		_redovisa_en(e)


## För över en poänghändelse till de visade totalerna och lägger den i händelselistan.
func _redovisa_en(e: Dictionary) -> void:
	match e.typ:
		"poang":
			poang[e.spelare] += e.poang
			e["tot"] = poang[e.spelare]
		"nollstall":
			for q in e.nollstallda:
				poang[q] = 0
	e["poang_efter"] = poang.duplicate()
	_h(e)


## Rundans alla poäng visas när sticket är klart.
func _redovisa() -> void:
	if vantande.is_empty():
		return
	_h({"typ": "redovisning", "antal": vantande.size()})
	for e in vantande:
		_redovisa_en(e)
	vantande = []
	poang = intern.duplicate()


## Vinst: total minst målpoängen och (med husregeln) en lyckad Chicago någon gång i partiet.
## Uppfyller flera villkoren vinner högst total, vid lika den som är först i tur efter given.
func far_vinna(p: int) -> bool:
	return poang[p] >= regler.malpoang and (not kravs_chicago() or chicago_tagen[p])


## Kravet gäller bara när Chicago får ropas (annars kunde ingen vinna).
func kravs_chicago() -> bool:
	return regler.chicago_kravs_for_vinst and regler.chicago_tillatet


## Har nått målpoängen men saknar Chicago (offentligt: både poäng och Chicago-markering syns).
func behover_chicago(p: int) -> bool:
	return kravs_chicago() and poang[p] >= regler.malpoang and not chicago_tagen[p]


func _kolla_vinst() -> bool:
	var w := -1
	for p in i_ordning(forhand()):
		if far_vinna(p) and (w < 0 or poang[p] > poang[w]):
			w = p
	if w < 0:
		return false
	_vinst(w)
	return true


func _vinst(p: int) -> void:
	vinnare = p
	fas = Fas.SLUT
	_h({"typ": "vinst", "spelare": p, "poang": poang.duplicate()})


# ------------------------------------------------------------------ chicago
## Rätt att ropa: Chicago tillåtet, minst minimipoängen i den löpande totalen och (med regeln en gång per parti)
## inte redan lyckats med Chicago i partiet.
func far_ropa(p: int) -> bool:
	if not regler.chicago_tillatet or intern[p] < regler.chicago_min:
		return false
	return not (regler.chicago_en_gang and chicago_tagen[p])


func _till_chicago() -> void:
	byte_nr = 0
	sluthander = hander.duplicate(true)
	if regler.chicago_tillatet:
		fas = Fas.CHICAGO
		gjort = 0
		tur = forhand()
		_hoppa_over_obehoriga()
		if fas == Fas.CHICAGO:
			# vem som får ropa är hemligt, därför sägs inte vems tur det är
			_h({"typ": "chicago_fraga"})
		return
	_till_stick(forhand())


func _hoppa_over_obehoriga() -> void:
	while gjort < n and not far_ropa(tur):
		gjort += 1
		tur = (tur + 1) % n
	if gjort >= n:
		_till_stick(forhand())


func ropa_chicago(p: int, ja: bool) -> bool:
	if fas != Fas.CHICAGO or p != tur:
		return false
	if ja and not far_ropa(p):
		return false
	if ja:
		chicago = p
		_h({"typ": "chicago", "spelare": p})
		_till_stick(p if regler.chicago_spelar_ut else forhand())
		return true
	gjort += 1
	tur = (tur + 1) % n
	_hoppa_over_obehoriga()
	return true


# ------------------------------------------------------------------ stick
func _till_stick(ut: int) -> void:
	if sluthander.is_empty():
		sluthander = hander.duplicate(true)
	fas = Fas.STICK
	stick_nr = 1
	stick = []
	utspelare = ut
	tur = ut
	_h({"typ": "stick_start", "nr": 1, "utspelare": ut})


func tillatna(p: int) -> Array:
	if fas != Fas.STICK or p != tur:
		return []
	return tillatna_kort(hander[p], stick)


## Bekänna färg: har man kort i utspelad färg måste ett av dem spelas.
static func tillatna_kort(hand: Array, pagaende: Array) -> Array:
	if pagaende.is_empty():
		return hand.duplicate()
	var f := K.farg(pagaende[0][1])
	var samma: Array = []
	for c in hand:
		if K.farg(c) == f:
			samma.append(c)
	return samma if not samma.is_empty() else hand.duplicate()


## Vem tar sticket: högsta kortet i utspelad färg.
static func stickvinnare(s: Array) -> Array:
	var f := K.farg(s[0][1])
	var bast: Array = s[0]
	for x in s:
		if K.farg(x[1]) == f and K.valor(x[1]) > K.valor(bast[1]):
			bast = x
	return bast


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
	var vinn := stickvinnare(stick)
	var w: int = vinn[0]
	stick_vunna[w] += 1
	_h({"typ": "stick", "vinnare": w, "kort": vinn[1], "nr": stick_nr, "stick": stick.duplicate(true)})
	if chicago >= 0 and w != chicago and not chicago_sprack:
		chicago_sprack = true
		_h({"typ": "chicago_sprack", "spelare": chicago, "av": w})
		_ge_poang(chicago, -regler.chicago_straff, "chicago_miss", "Chicago sprack")
		if regler.chicago_avbryt:
			_rundans_slut(-1, -1)
			return true
	if stick_nr == 5:
		_rundans_slut(w, vinn[1])
		return true
	stick_nr += 1
	stick = []
	utspelare = w
	tur = w
	_h({"typ": "stick_start", "nr": stick_nr, "utspelare": w})
	return true


## Sticken är klara (eller avbrutna av en sprucken Chicago). Lyckad Chicago ger Chicagopoängen och inget annat
## efter sticket. Annars räknas sluthanden och sista sticket – även för den vars Chicago sprack.
func _rundans_slut(sista_vinnare: int, sista_kort: int) -> void:
	if chicago >= 0 and not chicago_sprack:
		_ge_poang(chicago, regler.chicago_poang, "chicago", "Chicago")
		chicago_tagen[chicago] = true
	else:
		if regler.poang_efter_stick and not sluthander.is_empty():
			_poangrakning("sluthand", 1, sluthander)
			if fas == Fas.SLUT:
				return
		if sista_vinnare >= 0:
			var pts: int = regler.stick_poang
			var text := "Sista sticket"
			if regler.tvaa_bonus and K.valor(sista_kort) == 2:
				pts = regler.tvaa_poang
				text = "Sista sticket med en tvåa"
			if pts > 0:
				_ge_poang(sista_vinnare, pts, "stick", text)
	_redovisa()
	if royal_vinst >= 0:
		_vinst(royal_vinst)
		return
	if not _kolla_vinst():
		_giv_slut()


func _giv_slut() -> void:
	fas = Fas.GIV_SLUT
	_h({"typ": "giv_slut", "poang": poang.duplicate()})


# ------------------------------------------------------------------ vad en spelare får veta
## Allt spelare p får känna till. Robotar får bara denna vy och kan alltså inte se andras kort.
## Den löpande totalen är dold, men spelaren får veta om sig själv om den har köpstopp och rätt att ropa Chicago.
func vy(p: int) -> Dictionary:
	var kvar: Array = []
	for q in n:
		kvar.append(hander[q].size() if q < hander.size() else 0)
	return {
		"jag": p,
		"n": n,
		"hand": hander[p].duplicate() if p < hander.size() else [],
		"poang": poang.duplicate(),
		"fas": fas,
		"givare": givare,
		"byte_nr": byte_nr,
		"poangsatts": fas == Fas.BYTE and (poangsatts_bytet() or regler.poang_efter_stick),
		"byten_kvar": regler.antal_byten - byte_nr if fas == Fas.BYTE else 0,
		"max_byte": max_byte(p),
		"kopstopp": har_kopstopp(p),
		"star_over": star_over.duplicate(),
		"bytes_antal": bytes_antal.duplicate(true),
		"egna_slangda": egna_slangda[p].duplicate() if p < egna_slangda.size() else [],
		"far_ropa": far_ropa(p),
		"chicago": chicago,
		"chicago_sprack": chicago_sprack,
		"chicago_tagen": chicago_tagen.duplicate(),
		"stick_nr": stick_nr,
		"stick": stick.duplicate(true),
		"utspelare": utspelare,
		"spelade": spelade.duplicate(true),
		"renons": renons.duplicate(true),
		"kvar": kvar,
		"stick_vunna": stick_vunna.duplicate(),
		"tillatna": tillatna(p),
		"regler": regler,
	}


## Sätter både visade och löpande totaler (för tester och återställning).
func satt_poang(p: Array) -> void:
	poang = p.duplicate()
	intern = p.duplicate()
