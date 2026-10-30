extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_online.gd
## Startar en server och tre klienter (Anna, Bo, Cia) som skapar ett bord och går med via kod. Värden startar
## med de tre som har gått med (lediga platser tas bort), och de spelar ett helt parti. Under partiet tappar Bo anslutningen och kommer tillbaka med sin token.
## Varje mottaget meddelande inspekteras: ingen klient får någonsin andras kort. Servern ska avvisa otillåtna drag,
## drag i fel tur, för tidiga kast, start av fel person och att gå med i ett pågående parti utan token.
## Sist startas servern som egen process med -- --server och en klient skapar ett bord där.

const Server := preload("res://scripts/server.gd")
const Klient := preload("res://scripts/klient.gd")
const Regler := preload("res://scripts/regler.gd")
const Robot := preload("res://tests/testspelare.gd")
const Motor := preload("res://scripts/motor.gd")
const K := preload("res://scripts/kort.gd")

const PORT := 9181
var server
var fel := 0
var meddelanden := 0
var korthandelser := 0


func _ok(v: bool, t: String) -> void:
	if not v:
		fel += 1
		print("FEL: ", t)


class Bot extends Node:
	const Klient := preload("res://scripts/klient.gd")
	const Robot := preload("res://tests/testspelare.gd")
	const Regler := preload("res://scripts/regler.gd")
	const Motor := preload("res://scripts/motor.gd")
	var test
	var k
	var namn := ""
	var plats := -1
	var kod := ""
	var token := ""
	var s := {}
	var regler_d := {}
	var felmeddelanden: Array = []
	var skickat := false
	var aktiv := true
	var egna := {}
	var offentliga := {}
	var steg := 0
	var kast_mottagna := 0
	var ogonblick := 0
	var avslutat := ""
	var rng := RandomNumberGenerator.new()

	func _init() -> void:
		k = Klient.new()
		add_child(k)
		k.meddelande.connect(_m)

	func _m(d: Dictionary) -> void:
		test.meddelanden += 1
		test.kolla_integritet(self, d)
		match d.t:
			"valkommen":
				plats = d.plats
				kod = d.kod
				token = d.token
			"lobby":
				regler_d = d.regler
			"steg":
				steg += 1
				s = d.s
				skickat = false
			"ogonblick":
				ogonblick += 1
				s = d.s
				skickat = false
				for c in d.s.egen.spelade:
					offentliga[c[1]] = true
				for c in d.s.egen.hand:
					egna[c] = true
			"kast":
				kast_mottagna += 1
			"avslutat":
				avslutat = d.text
			"fel":
				felmeddelanden.append(d.text)
				skickat = false

	func _process(_dt: float) -> void:
		if not aktiv or skickat or s.is_empty() or plats < 0:
			return
		if s.tur != plats:
			return
		var vy: Dictionary = s.egen.duplicate(true)
		var r := Regler.new()
		r.fran_dict(regler_d)
		vy["regler"] = r
		match int(s.fas):
			Motor.Fas.BYTE:
				k.skicka({"t": "byt", "kort": Robot.valj_byte(vy, Robot.MEDEL, rng)})
			Motor.Fas.CHICAGO:
				k.skicka({"t": "chicago", "ja": Robot.valj_chicago(vy, Robot.MEDEL, rng)})
			Motor.Fas.STICK:
				k.skicka({"t": "spela", "kort": Robot.valj_kort(vy, Robot.MEDEL, rng)})
			_:
				return
		skickat = true


## Kontrollerar att ett meddelande bara innehåller kort som klienten får känna till.
func kolla_integritet(b: Bot, d: Dictionary) -> void:
	_sok_forbjudna_nycklar(d, b.namn)
	if d.t == "steg":
		for e in d.h:
			match e.typ:
				"giv":
					korthandelser += 1
					if e.spelare == b.plats:
						b.egna[e.kort] = true
						_ok(e.kort >= 0, "egen giv saknar kort")
					else:
						_ok(e.kort == -1, "%s fick se %s giv till plats %d" % [b.namn, K.namn(e.kort), e.spelare])
				"byte":
					if e.spelare == b.plats:
						for c in e.nya:
							b.egna[c] = true
					else:
						for c in e.slangda + e.nya:
							_ok(c == -1, "%s fick se ett kort i plats %d:s byte" % [b.namn, e.spelare])
				"spela":
					b.offentliga[e.kort] = true
	if d.t == "ogonblick":
		# återanslutning: handen jämförs med serverns facit nedan
		for c in d.s.egen.hand:
			b.egna[c] = true
	if d.t == "steg" or d.t == "ogonblick":
		var eg: Dictionary = d.s.egen
		# egen hand ska vara exakt serverns hand för platsen, och bara den
		var bo: Dictionary = server.bord.get(b.kod, {})
		if not bo.is_empty() and bo.motor != null and bo.motor.hander.size() > b.plats:
			var facit: Array = bo.motor.hander[b.plats].duplicate()
			var hand: Array = eg.hand.duplicate()
			facit.sort()
			hand.sort()
			_ok(hand == facit or bo.motor.hander[b.plats].size() != hand.size(), "%s: egen hand stämmer inte med servern" % b.namn)
			for q in bo.motor.n:
				if q == b.plats:
					continue
				for c in bo.motor.hander[q]:
					_ok(not _innehaller_kort(d, c, b), "%s fick %s som ligger hos plats %d" % [b.namn, K.namn(c), q])
		for c in eg.hand:
			_ok(b.egna.has(c), "%s: kort i egen hand som aldrig getts till spelaren" % b.namn)
		for x in eg.spelade:
			_ok(b.offentliga.has(x[1]) or d.t == "ogonblick", "%s: spelat kort som inte var offentligt" % b.namn)


## Finns kortet c någonstans i meddelandet där det skulle avslöja det? (Spelade kort och egen hand är tillåtna.)
func _innehaller_kort(d: Dictionary, c: int, b: Bot) -> bool:
	if d.t == "steg":
		for e in d.h:
			if e.typ == "giv" and e.kort == c:
				return true
			if e.typ == "byte" and (c in e.nya or c in e.slangda):
				return true
	var eg: Dictionary = d.s.egen
	return c in eg.hand or c in eg.tillatna or c in eg.egna_slangda


func _sok_forbjudna_nycklar(v, namn: String) -> void:
	if v is Dictionary:
		for k in v:
			_ok(not str(k) in ["hander", "lek_kort", "slanghog", "token_alla"], "%s fick fältet %s" % [namn, k])
			_sok_forbjudna_nycklar(v[k], namn)
	elif v is Array:
		for x in v:
			_sok_forbjudna_nycklar(x, namn)


func _vanta(sek: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sek * 1000.0:
		await process_frame


func _vanta_pa(villkor: Callable, sek: float, text: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sek * 1000.0:
		if villkor.call():
			return true
		await process_frame
	_ok(false, "tidsgräns: " + text)
	return false


func _bot(namn: String) -> Bot:
	var b := Bot.new()
	b.namn = namn
	b.test = self
	root.add_child(b)
	b.k.spara_logg = true
	b.k.anslut("ws://127.0.0.1:%d" % PORT)
	return b


func _init() -> void:
	server = Server.new()
	server.tempo = 0.04
	server.franvaro_auto = 0.8
	server.stada_efter = 2.0
	server.logga_ut = false
	root.add_child(server)
	_ok(server.starta(PORT) == OK, "servern startar")
	var r := Regler.new()
	r.malpoang = 60
	var anna := _bot("Anna")
	anna.k.skicka({"t": "skapa", "namn": "Anna", "antal": 4, "regler": r.till_dict(), "figur": 3})
	await _vanta_pa(func() -> bool: return anna.kod != "", 5.0, "Anna får en bordskod")
	print("bord skapat: ", anna.kod)
	_ok(anna.kod.length() == 4 and anna.plats == 0, "kod med fyra tecken och värden på plats 0")
	_ok(int(anna.regler_d.get("malpoang", 0)) == 60, "lobbyn visar bordets regler")
	# ensam vid bordet går det inte att starta
	anna.k.skicka({"t": "starta"})
	await _vanta_pa(func() -> bool: return not anna.felmeddelanden.is_empty(), 3.0, "start med en spelare avvisas")
	_ok(server.bord[anna.kod].motor == null, "inget parti med bara värden")
	anna.felmeddelanden.clear()
	# den som ska gå med får först bordets information: regler i läsläge och tagna figurer
	var titt := _bot("Titt")
	var info := {}
	titt.k.meddelande.connect(func(d: Dictionary) -> void:
		if d.t == "bordinfo":
			info.merge(d, true))
	titt.k.skicka({"t": "bordinfo", "kod": anna.kod})
	await _vanta_pa(func() -> bool: return not info.is_empty(), 3.0, "bordinfo")
	_ok(info.get("finns", false) and info.varde_namn == "Anna" and int(info.platser[0].figur) == 3 and int(info.regler.malpoang) == 60, "bordinfo med värd, regler och tagen figur")
	# samma figur som Anna går inte
	var dubbel := _bot("Dubbel")
	dubbel.k.skicka({"t": "ga_med", "kod": anna.kod, "namn": "Dubbel", "figur": 3})
	await _vanta_pa(func() -> bool: return not dubbel.felmeddelanden.is_empty(), 3.0, "dubbel figur avvisas")
	_ok(dubbel.plats < 0, "dubbel figur gav ingen plats")
	var bo := _bot("Bo")
	bo.k.skicka({"t": "ga_med", "kod": anna.kod.to_lower(), "namn": "Bo", "figur": 1})
	var cia := _bot("Cia")
	cia.k.skicka({"t": "ga_med", "kod": anna.kod, "namn": "Cia", "figur": 2})
	await _vanta_pa(func() -> bool: return bo.plats >= 0 and cia.plats >= 0, 5.0, "Bo och Cia går med")
	_ok(bo.plats == 1 and cia.plats == 2, "platser 1 och 2")
	# fel bordskod
	var fel_bot := _bot("Fel")
	fel_bot.k.skicka({"t": "ga_med", "kod": "ZZZZ", "namn": "X"})
	await _vanta_pa(func() -> bool: return not fel_bot.felmeddelanden.is_empty(), 3.0, "fel kod avvisas")
	# bara värden får ändra regler och starta; robotar och "fyll" finns inte
	cia.felmeddelanden.clear()
	cia.k.skicka({"t": "plats", "plats": 3, "typ": "robot", "niva": 1})
	cia.k.skicka({"t": "regler", "regler": {"malpoang": 99}})
	cia.k.skicka({"t": "fyll"})
	cia.k.skicka({"t": "figur", "figur": 1})
	await _vanta_pa(func() -> bool: return cia.felmeddelanden.size() >= 4, 3.0, "icke-värd och robotmeddelanden avvisas")
	_ok(server.bord[anna.kod].platser[3].typ == "tom" and server.bord[anna.kod].regler.malpoang == 60, "icke-värd ändrade inget")
	_ok(server.bord[anna.kod].platser[2].figur == 2, "Cia fick inte ta Bos figur")
	# värden kan ändra reglerna före start
	var r2 := Regler.new()
	r2.malpoang = 60
	r2.kopstopp = 30
	anna.k.skicka({"t": "regler", "regler": r2.till_dict()})
	await _vanta_pa(func() -> bool: return server.bord[anna.kod].regler.kopstopp == 30, 3.0, "värden ändrar regler")
	# bara värden får starta
	bo.felmeddelanden.clear()
	bo.k.skicka({"t": "starta"})
	await _vanta_pa(func() -> bool: return not bo.felmeddelanden.is_empty(), 3.0, "start av icke-värd avvisas")
	_ok(server.bord[anna.kod].motor == null, "Bo kunde inte starta")
	# för tidigt kast: två kast direkt efter varandra
	anna.felmeddelanden.clear()
	anna.k.skicka({"t": "kasta", "till": 1, "vad": "vattenballong"})
	anna.k.skicka({"t": "kasta", "till": 2, "vad": "tomat"})
	anna.k.skicka({"t": "kasta", "till": 0, "vad": "ros"})
	await _vanta_pa(func() -> bool: return anna.felmeddelanden.size() >= 2, 3.0, "för tidigt kast avvisas")
	_ok(bo.kast_mottagna == 1, "det första kastet skickas till alla (Bo fick %d)" % bo.kast_mottagna)
	# starta
	for x in [anna, bo, cia]:
		x.aktiv = false
	anna.k.skicka({"t": "starta"})
	await _vanta_pa(func() -> bool: return not anna.s.is_empty() and int(anna.s.fas) == Motor.Fas.BYTE, 10.0, "partiet startar")
	# bara de tre som gick med spelar, med sina figurer och samma platser
	var figs: Array = server.bord[anna.kod].platser.map(func(x): return x.figur)
	_ok(figs == [3, 1, 2], "tre spelare med sina figurer efter start: %s" % [figs])
	_ok(server.bord[anna.kod].motor.n == 3 and anna.plats == 0 and bo.plats == 1 and cia.plats == 2, "lediga platser borttagna, platserna kvar")
	# otillåtna drag: fel tur och kort man inte har
	var m = server.bord[anna.kod].motor
	var tur: int = m.tur
	var spelarna := [anna, bo, cia]
	if tur < 3:
		var ej_tur: Bot = spelarna[(tur + 1) % 3]
		ej_tur.felmeddelanden.clear()
		ej_tur.k.skicka({"t": "byt", "kort": []})
		var pa_tur: Bot = spelarna[tur]
		pa_tur.felmeddelanden.clear()
		var frammande := -1
		for c in 52:
			if not c in m.hander[tur]:
				frammande = c
				break
		pa_tur.k.skicka({"t": "byt", "kort": [frammande]})
		pa_tur.k.skicka({"t": "spela", "kort": frammande})
		await _vanta_pa(func() -> bool: return ej_tur.felmeddelanden.size() >= 1 and pa_tur.felmeddelanden.size() >= 2, 3.0, "otillåtna drag avvisas")
		_ok(m.hander[tur].size() == 5 and not frammande in m.hander[tur], "otillåtet byte ändrade inte handen")
	# en som inte har token kommer inte in i ett pågående parti
	var sen := _bot("Sen")
	sen.k.skicka({"t": "ga_med", "kod": anna.kod, "namn": "Sen"})
	await _vanta_pa(func() -> bool: return not sen.felmeddelanden.is_empty(), 3.0, "pågående parti stängt utan token")
	# spela
	for x in [anna, bo, cia]:
		x.aktiv = true
	await _vanta_pa(func() -> bool: return m.giv_nr >= 2, 60.0, "andra given börjar")
	# Bo tappar anslutningen, servern gör enkla drag åt honom, sedan kommer han tillbaka med token
	var bo_token := bo.token
	var bo_kod := bo.kod
	bo.k.koppla_fran()
	bo.aktiv = false
	var giv_fore: int = m.giv_nr
	await _vanta_pa(func() -> bool: return m.giv_nr >= giv_fore + 1 or m.fas == Motor.Fas.SLUT, 60.0, "partiet fortsätter när Bo är borta")
	var bo2 := _bot("Bo")
	bo2.k.skicka({"t": "ga_med", "kod": bo_kod, "namn": "Bo igen", "token": bo_token})
	await _vanta_pa(func() -> bool: return bo2.ogonblick >= 1, 5.0, "Bo kommer tillbaka och får läget")
	_ok(bo2.plats == 1, "Bo får tillbaka plats 1 (fick %d)" % bo2.plats)
	var t0 := Time.get_ticks_msec()
	await _vanta_pa(func() -> bool: return m.fas == Motor.Fas.SLUT, 240.0, "partiet spelas klart")
	print("partiet klart efter %d givar, %d s, vinnare %s med %d poäng" % [m.giv_nr, (Time.get_ticks_msec() - t0) / 1000, m.namn[m.vinnare], m.poang[m.vinnare]])
	await _vanta(0.5)
	_ok(anna.s.vinnare == m.vinnare, "klienterna får veta vinnaren")
	# städning: alla går, bordet tas bort
	var kod := anna.kod
	for x in [anna, bo2, cia, sen, fel_bot, titt, dubbel]:
		x.k.koppla_fran()
	await _vanta_pa(func() -> bool: return not server.bord.has(kod), 8.0, "tomt bord städas bort")
	print("meddelanden inspekterade: %d (varav %d giv-händelser)" % [meddelanden, korthandelser])
	await _vard_lamnar()
	# servern som egen process
	await _extern_server()
	print("fel: %d" % fel)
	quit(1 if fel else 0)


## Värden lämnar bordet (i lobbyn och mitt i ett parti): bordet stängs och de andra får veta det.
func _vard_lamnar() -> void:
	for startat in [false, true]:
		var v := _bot("Vera")
		v.k.skicka({"t": "skapa", "namn": "Vera", "antal": 3, "regler": Regler.new().till_dict()})
		await _vanta_pa(func() -> bool: return v.kod != "", 5.0, "Vera skapar bord")
		var g := _bot("Gus")
		g.aktiv = false
		g.k.skicka({"t": "ga_med", "kod": v.kod, "namn": "Gus"})
		await _vanta_pa(func() -> bool: return g.plats >= 0, 5.0, "Gus går med")
		if startat:
			v.aktiv = false
			v.k.skicka({"t": "starta"})
			await _vanta_pa(func() -> bool: return not g.s.is_empty(), 5.0, "partiet startar")
		var kod := v.kod
		v.k.skicka({"t": "lamna"})
		await _vanta_pa(func() -> bool: return g.avslutat != "", 5.0, "Gus får veta att bordet stängts")
		_ok("Vera" in g.avslutat, "meddelandet nämner värden: '%s'" % g.avslutat)
		_ok(not server.bord.has(kod), "bordet är borttaget (startat: %s)" % startat)
		g.felmeddelanden.clear()
		g.k.skicka({"t": "byt", "kort": []})
		await _vanta_pa(func() -> bool: return not g.felmeddelanden.is_empty(), 3.0, "Gus sitter inte längre vid bordet")
		g.k.koppla_fran()
		v.k.koppla_fran()


func _extern_server() -> void:
	var port := PORT + 1
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--server", "--port=%d" % port])
	_ok(pid > 0, "serverprocessen startar")
	var b := Bot.new()
	b.namn = "Extern"
	b.test = self
	root.add_child(b)
	var t0 := Time.get_ticks_msec()
	# vänta tills servern lyssnar
	while b.kod == "" and Time.get_ticks_msec() - t0 < 20000:
		if not b.k.ar_ansluten():
			b.k.anslut("ws://127.0.0.1:%d" % port)
			b.k.skicka({"t": "skapa", "namn": "Extern", "antal": 2, "regler": Regler.new().till_dict()})
		await _vanta(0.5)
	_ok(b.kod != "", "bord skapat på servern som körs med -- --server")
	print("extern server: bord ", b.kod)
	b.k.koppla_fran()
	OS.kill(pid)
