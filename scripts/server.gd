extends Node
## Auktoritativ server för onlinespel. Kör: Godot --headless --path . -- --server --port=9080
## Regelmotorn (motor.gd) är enda sanningen: servern blandar, ger och avgör stick och poäng.
## Bara människor spelar (inga robotar sedan 2026-10-30). Värden startar när minst två har gått med.
## Varje klient får bara sin egen hand och det offentliga (natverk.filtrera / natverk.tillstand).
## Protokoll: JSON-text över WebSocket. Allt från klienter valideras.

const Motor := preload("res://scripts/motor.gd")
const Regler := preload("res://scripts/regler.gd")
const Natverk := preload("res://scripts/natverk.gd")
const Figurer := preload("res://scripts/figurer.gd")

const KASTSPARR := 3.0
const STADA_EFTER := 600.0  # sekunder utan anslutna människor innan bordet tas bort
const MAX_PLATSER := 6
const FRANVARO_AUTO := 45.0  # sekunder innan servern gör ett enkelt drag åt en frånkopplad spelare

var tcp := TCPServer.new()
var anslutningar := {}  # id -> {ws, bord, plats, tid}
var nasta_id := 1
var bord := {}  # kod -> Dictionary
var rng := RandomNumberGenerator.new()
var tid := 0.0
var stada_efter := STADA_EFTER
var franvaro_auto := FRANVARO_AUTO
var tempo := 1.0  # < 1 snabbar upp pauserna mellan händelser (tester)
var logga_ut := true


func starta(port: int) -> int:
	rng.randomize()
	var e := tcp.listen(port)
	if logga_ut:
		print("Chicago-server lyssnar på port %d (%s)" % [port, "ok" if e == OK else "fel %d" % e])
	return e


func _process(dt: float) -> void:
	tid += dt
	while tcp.is_connection_available():
		var s := tcp.take_connection()
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 256 * 1024
		ws.outbound_buffer_size = 1024 * 1024
		ws.accept_stream(s)
		anslutningar[nasta_id] = {"ws": ws, "bord": "", "plats": -1, "tid": tid}
		nasta_id += 1
	for id in anslutningar.keys():
		var a: Dictionary = anslutningar[id]
		var ws: WebSocketPeer = a.ws
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var text := ws.get_packet().get_string_from_utf8()
				_ta_emot(id, text)
				if not anslutningar.has(id):
					break
		elif st == WebSocketPeer.STATE_CLOSED:
			_koppla_fran(id)
	for kod in bord.keys():
		_tick(bord[kod], dt)


func _skicka(id: int, d: Dictionary) -> void:
	if not anslutningar.has(id):
		return
	var ws: WebSocketPeer = anslutningar[id].ws
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(d))


func _fel(id: int, text: String) -> void:
	_skicka(id, {"t": "fel", "text": text})


# ------------------------------------------------------------------ meddelanden
func _ta_emot(id: int, text: String) -> void:
	var d = Natverk.avkoda(text)
	if not d is Dictionary or not d.has("t"):
		_fel(id, "Felaktigt meddelande")
		return
	var a: Dictionary = anslutningar[id]
	match str(d.t):
		"skapa":
			_skapa(id, d)
		"ga_med":
			_ga_med(id, d)
		"ping":
			_skicka(id, {"t": "pong"})
		"bordinfo":
			_bordinfo(id, d)
		_:
			if a.bord == "" or not bord.has(a.bord):
				_fel(id, "Du sitter inte vid något bord")
				return
			var b: Dictionary = bord[a.bord]
			var p: int = a.plats
			match str(d.t):
				"starta":
					_starta_parti(id, b, p)
				"figur":
					var f := _figur(d)
					if f >= 0 and _figur_upptagen(b, f, p):
						_fel(id, "Figuren är upptagen, välj en annan")
						return
					b.platser[p].figur = f
					_skicka_lobby(b)
				"regler":
					# bara värden (värdens token) får ändra reglerna, och bara före start
					if p != b.varde or b.startad:
						_fel(id, "Bara värden kan ändra reglerna före start")
						return
					if d.get("regler") is Dictionary:
						b.regler.fran_dict(d.regler)
						b.regler.malpoang = clampi(b.regler.malpoang, 5, 500)
					_skicka_lobby(b)
				"byt", "upp", "chicago", "spela":
					_drag(id, b, p, d)
				"kasta":
					_kasta(id, b, p, d)
				"lamna":
					_koppla_fran(id, true)
				_:
					_fel(id, "Okänt meddelande")


func _ny_kod() -> String:
	for forsok in 1000:
		var k := ""
		for i in 4:
			k += Natverk.KODTECKEN[rng.randi_range(0, Natverk.KODTECKEN.length() - 1)]
		if not bord.has(k):
			return k
	return "X%d" % rng.randi()


func _ny_token() -> String:
	var t := ""
	for i in 16:
		t += "%x" % rng.randi_range(0, 15)
	return t


func _rent_namn(n) -> String:
	var s := str(n).strip_edges().left(14)
	return s if s != "" else "Spelare"


func _skapa(id: int, d: Dictionary) -> void:
	if anslutningar[id].bord != "":
		_fel(id, "Du sitter redan vid ett bord")
		return
	var antal := clampi(int(d.get("antal", MAX_PLATSER)), 2, MAX_PLATSER)
	var r := Regler.new()
	if d.get("regler") is Dictionary:
		r.fran_dict(d.regler)
	r.malpoang = clampi(r.malpoang, 5, 500)
	var kod := _ny_kod()
	var platser: Array = []
	for i in antal:
		platser.append({"namn": "", "typ": "tom", "token": "", "id": -1, "borta": 0.0, "figur": -1})
	var b := {"kod": kod, "regler": r, "platser": platser, "varde": 0, "startad": false, "motor": null,
		"vanta": 0.0, "tomt": 0.0, "kast": {}, "tagna": []}
	bord[kod] = b
	b.platser[0].figur = _figur(d)
	_satt_ner(id, b, 0, _rent_namn(d.get("namn", "")))
	if logga_ut:
		print("Bord %s skapat (%d platser)" % [kod, antal])


func _satt_ner(id: int, b: Dictionary, p: int, namn: String) -> void:
	var pl: Dictionary = b.platser[p]
	pl.typ = "manniska"
	pl.namn = namn
	if pl.token == "":
		pl.token = _ny_token()
	pl.id = id
	pl.borta = 0.0
	anslutningar[id].bord = b.kod
	anslutningar[id].plats = p
	_skicka(id, {"t": "valkommen", "kod": b.kod, "plats": p, "token": pl.token, "varde": p == b.varde})
	_skicka_lobby(b)
	if b.startad and b.motor != null:
		_skicka(id, {"t": "ogonblick", "s": Natverk.tillstand(b.motor, p), "tagna": b.tagna.duplicate(true)})


func _ga_med(id: int, d: Dictionary) -> void:
	var kod := str(d.get("kod", "")).to_upper().strip_edges()
	if not bord.has(kod):
		_fel(id, "Bordet %s finns inte" % kod)
		return
	var b: Dictionary = bord[kod]
	var token := str(d.get("token", ""))
	# tillbaka med sparad token
	if token != "":
		for p in b.platser.size():
			var pl: Dictionary = b.platser[p]
			if pl.token == token and pl.typ == "manniska":
				if pl.id >= 0 and anslutningar.has(pl.id) and pl.id != id:
					var gammal: int = pl.id
					anslutningar[gammal].bord = ""
					anslutningar[gammal].plats = -1
					anslutningar[gammal].ws.close()
				_satt_ner(id, b, p, pl.namn)
				return
	if b.startad:
		_fel(id, "Partiet vid bord %s har redan börjat" % kod)
		return
	var f := _figur(d)
	if f >= 0 and _figur_upptagen(b, f, -1):
		_fel(id, "Figuren %s är redan tagen vid bordet, välj en annan" % Figurer.namn(f))
		return
	for p in b.platser.size():
		if b.platser[p].typ == "tom":
			b.platser[p].figur = f
			_satt_ner(id, b, p, _rent_namn(d.get("namn", "")))
			return
	_fel(id, "Bordet %s är fullt" % kod)


## Information om ett bord för den som funderar på att gå med: regler, värd, platser och tagna figurer.
func _bordinfo(id: int, d: Dictionary) -> void:
	var kod := str(d.get("kod", "")).to_upper().strip_edges()
	if not bord.has(kod):
		_skicka(id, {"t": "bordinfo", "kod": kod, "finns": false})
		return
	var b: Dictionary = bord[kod]
	var l := _lobby(b)
	l["t"] = "bordinfo"
	l["finns"] = true
	l["varde_namn"] = b.platser[b.varde].namn
	_skicka(id, l)


## En figur är upptagen om någon annan vid bordet har den. När alla figurer är tagna (fler spelare än
## figurer) får man välja en som redan används.
func _figur_upptagen(b: Dictionary, f: int, utom: int) -> bool:
	var tagna := {}
	for q in b.platser.size():
		if q != utom and b.platser[q].typ != "tom" and b.platser[q].figur >= 0:
			tagna[b.platser[q].figur] = true
	return tagna.has(f) and tagna.size() < Figurer.antal()


func _figur(d: Dictionary) -> int:
	var f := int(d.get("figur", -1))
	return f if f >= 0 and f < Figurer.antal() else -1


func _lobby(b: Dictionary) -> Dictionary:
	var pl: Array = []
	for p in b.platser.size():
		var x: Dictionary = b.platser[p]
		pl.append({"namn": x.namn, "typ": x.typ, "figur": x.figur, "ansluten": x.typ != "manniska" or (x.id >= 0 and anslutningar.has(x.id))})
	return {"t": "lobby", "kod": b.kod, "platser": pl, "regler": b.regler.till_dict(), "startad": b.startad, "varde": b.varde}


func _skicka_lobby(b: Dictionary) -> void:
	var l := _lobby(b)
	for pl in b.platser:
		if pl.typ == "manniska" and pl.id >= 0:
			_skicka(pl.id, l)


func _starta_parti(id: int, b: Dictionary, p: int) -> void:
	if p != b.varde:
		_fel(id, "Bara värden kan starta")
		return
	if b.startad and b.motor != null and b.motor.fas != Motor.Fas.SLUT:
		_fel(id, "Partiet pågår redan")
		return
	# bara de som har gått med och är anslutna spelar; lediga platser tas bort
	var kvar: Array = []
	for q in b.platser.size():
		var pl: Dictionary = b.platser[q]
		if pl.typ == "manniska" and (q == b.varde or (pl.id >= 0 and anslutningar.has(pl.id))):
			kvar.append(pl)
	if kvar.size() < 2:
		_fel(id, "Minst två spelare behövs. Dela länken med dina vänner.")
		return
	if kvar.size() != b.platser.size():
		_packa_platser(b, kvar)
	var namn: Array = []
	for pl in b.platser:
		namn.append(pl.namn)
	# den som inte valt figur får en som inte redan är vald
	var valda: Array = []
	for pl in b.platser:
		valda.append(pl.figur)
	var fig := Figurer.fordela(valda, rng)
	for q in b.platser.size():
		b.platser[q].figur = fig[q]
	var m := Motor.new()
	m.starta(namn, b.regler.kopia(), rng.randi() % 1000000)
	b.motor = m
	b.startad = true
	b.tagna = []
	b.vanta = 0.0
	_skicka_lobby(b)
	_sanda_steg(b)


## Platserna blir bara de som spelar, i samma ordning. Var och en får sin nya plats (och värden sin).
func _packa_platser(b: Dictionary, kvar: Array) -> void:
	var vard: Dictionary = b.platser[b.varde]
	for pl in b.platser:
		if not pl in kvar and pl.id >= 0 and anslutningar.has(pl.id):
			anslutningar[pl.id].bord = ""
			anslutningar[pl.id].plats = -1
	b.platser = kvar
	b.varde = kvar.find(vard)
	for q in kvar.size():
		var pl: Dictionary = kvar[q]
		if pl.id >= 0 and anslutningar.has(pl.id):
			anslutningar[pl.id].plats = q
			_skicka(pl.id, {"t": "valkommen", "kod": b.kod, "plats": q, "token": pl.token, "varde": q == b.varde})


## Skickar motorns nya händelser filtrerade till varje människa, och räknar ut hur länge klienterna animerar.
func _sanda_steg(b: Dictionary) -> void:
	var m = b.motor
	# även utan händelser skickas läget (t.ex. när någon avstår Chicago tyst och turen går vidare)
	var h: Array = m.ta_handelser()
	var paus := 0.3
	for e in h:
		match e.typ:
			"blanda":
				paus += 3.6
				b.tagna = []
			"giv":
				paus += 0.08
			"giv_klar":
				paus += 0.7
			"byte":
				paus += 1.3
			"upp":
				paus += 1.4
			"upp_svar":
				paus += 1.0
			"poang":
				paus += 2.2
			"ingen_poang", "lika":
				paus += 1.4
			"chicago":
				paus += 2.3
			"spela":
				paus += 0.5
			"stick":
				paus += 1.6
				b.tagna.append([e.vinnare, e.stick.map(func(x): return x[1])])
			"vinst":
				paus += 3.0
			"giv_slut":
				paus += 1.2
	b.vanta = maxf(b.vanta, paus * tempo)
	for p in b.platser.size():
		var pl: Dictionary = b.platser[p]
		if pl.typ != "manniska" or pl.id < 0:
			continue
		var lista: Array = []
		for e in h:
			lista.append(Natverk.filtrera(e, p))
		_skicka(pl.id, {"t": "steg", "h": lista, "s": Natverk.tillstand(m, p)})


func _drag(id: int, b: Dictionary, p: int, d: Dictionary) -> void:
	var m = b.motor
	if m == null or p != m.tur:
		_fel(id, "Det är inte din tur")
		return
	var ok := false
	match str(d.t):
		"byt":
			ok = m.fas == Motor.Fas.BYTE and d.get("kort") is Array and m.byt(p, d.kort)
		"upp":
			ok = m.fas == Motor.Fas.BYTE and m.ta_upp(p, bool(d.get("ja", false)))
		"chicago":
			ok = m.fas == Motor.Fas.CHICAGO and m.ropa_chicago(p, bool(d.get("ja", false)))
		"spela":
			ok = m.fas == Motor.Fas.STICK and m.spela(p, int(d.get("kort", -1)))
	if not ok:
		_fel(id, "Otillåtet drag")
		return
	_sanda_steg(b)


func _kasta(id: int, b: Dictionary, p: int, d: Dictionary) -> void:
	var till := int(d.get("till", -1))
	var vad := str(d.get("vad", ""))
	# 6-7 får man göra själv (till sin egen plats), allt annat kastas på någon annan
	if till < 0 or till >= b.platser.size() or not vad in Natverk.KASTTYPER or (till == p and vad != "sexsju"):
		_fel(id, "Går inte att kasta så")
		return
	var senast: float = b.kast.get(p, -100.0)
	if tid - senast < KASTSPARR:
		_fel(id, "Vänta lite innan du kastar igen")
		return
	b.kast[p] = tid
	_sand_kast(b, p, till, vad)


func _sand_kast(b: Dictionary, fran: int, till: int, vad: String) -> void:
	for pl in b.platser:
		if pl.typ == "manniska" and pl.id >= 0:
			_skicka(pl.id, {"t": "kast", "fran": fran, "till": till, "vad": vad})


func _koppla_fran(id: int, frivilligt := false) -> void:
	if not anslutningar.has(id):
		return
	var a: Dictionary = anslutningar[id]
	if a.bord != "" and bord.has(a.bord):
		var b: Dictionary = bord[a.bord]
		var pl: Dictionary = b.platser[a.plats]
		if frivilligt and pl.id == id and a.plats == b.varde:
			# värden lämnar (Lämna bordet eller Meny): bordet stängs för alla
			_avsluta_bord(b, "%s lämnade bordet, så partiet avbröts." % pl.namn)
		elif pl.id == id:
			pl.id = -1
			pl.borta = 0.0
			# lämnar man före start blir platsen ledig igen
			if frivilligt and not b.startad and a.plats != b.varde:
				pl.typ = "tom"
				pl.namn = ""
				pl.token = ""
			_skicka_lobby(b)
	if frivilligt:
		a.ws.close()
		a.bord = ""
	anslutningar.erase(id)


## Stänger bordet: alla andra får "avslutat" och sitter inte längre vid något bord.
func _avsluta_bord(b: Dictionary, text: String) -> void:
	for q in b.platser.size():
		var pl: Dictionary = b.platser[q]
		if q == b.varde or pl.id < 0 or not anslutningar.has(pl.id):
			continue
		_skicka(pl.id, {"t": "avslutat", "text": text})
		anslutningar[pl.id].bord = ""
		anslutningar[pl.id].plats = -1
	bord.erase(b.kod)
	if logga_ut:
		print("Bord %s avslutat av värden" % b.kod)


# ------------------------------------------------------------------ frånvaro och städning
func _tick(b: Dictionary, dt: float) -> void:
	var nagon := false
	for pl in b.platser:
		if pl.typ == "manniska":
			if pl.id >= 0 and anslutningar.has(pl.id):
				nagon = true
			else:
				pl.borta += dt
	b.tomt = 0.0 if nagon else b.tomt + dt
	if b.tomt > stada_efter:
		if logga_ut:
			print("Bord %s städas bort" % b.kod)
		bord.erase(b.kod)
		return
	var m = b.motor
	if m == null:
		return
	b.vanta -= dt
	if b.vanta > 0.0:
		return
	if m.fas == Motor.Fas.GIV_SLUT:
		m.ny_giv()
		_sanda_steg(b)
		return
	if m.fas != Motor.Fas.BYTE and m.fas != Motor.Fas.CHICAGO and m.fas != Motor.Fas.STICK:
		return
	# Är den som har turen frånkopplad länge gör servern ett enkelt drag, så att partiet inte står still:
	# inget byte (vid 1 upp tar den kortet), ingen Chicago, och det lägsta tillåtna kortet i sticket. Ingen robot, ingen taktik.
	var p: int = m.tur
	var pl: Dictionary = b.platser[p]
	var franvarande: bool = (pl.id < 0 or not anslutningar.has(pl.id)) and pl.borta > franvaro_auto
	if not franvarande:
		return
	match m.fas:
		Motor.Fas.BYTE:
			if m.upp_kort >= 0:
				m.ta_upp(p, true)
			else:
				m.byt(p, [])
		Motor.Fas.CHICAGO:
			m.ropa_chicago(p, false)
		Motor.Fas.STICK:
			var till: Array = m.tillatna(p)
			till.sort_custom(func(a: int, c: int) -> bool: return a % 13 < c % 13)
			m.spela(p, till[0])
	b.vanta = 0.6 * tempo
	_sanda_steg(b)
