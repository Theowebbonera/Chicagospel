extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_online_scen.gd
## Hela spelet (main.tscn med 3D-bordet) som onlineklient mot en lokal server:
## Theo skapar ett bord, en andra klient går med via koden, värden lägger en robot på sista platsen och startar.
## Partiet spelas med den riktiga grafiken. I varje bildruta kontrolleras att inget kort syns med framsidan mot
## kameran utom kort i sticket och den egna handen. Mitt i partiet bryts Theos anslutning: klienten ansluter
## igen med sin token, bygger upp bordet från serverns läge och spelar vidare.

const Server := preload("res://scripts/server.gd")
const Klient := preload("res://scripts/klient.gd")
const Regler := preload("res://scripts/regler.gd")
const Robot := preload("res://scripts/robot.gd")
const Motor := preload("res://scripts/motor.gd")

const PORT := 9185
var fel := 0


func _ok(v: bool, t: String) -> void:
	if not v:
		fel += 1
		print("FEL: ", t)


## En enkel andra klient som spelar med robotens logik på sin egen vy.
class Gast extends Node:
	const Klient := preload("res://scripts/klient.gd")
	const Robot := preload("res://scripts/robot.gd")
	const Regler := preload("res://scripts/regler.gd")
	const Motor := preload("res://scripts/motor.gd")
	var k
	var plats := -1
	var s := {}
	var regler_d := {}
	var skickat := false
	var rng := RandomNumberGenerator.new()

	func _init() -> void:
		k = Klient.new()
		add_child(k)
		k.meddelande.connect(_m)

	func _m(d: Dictionary) -> void:
		match d.t:
			"valkommen":
				plats = d.plats
			"lobby":
				regler_d = d.regler
			"steg", "ogonblick":
				s = d.s
				skickat = false
			"fel":
				skickat = false

	func _process(_dt: float) -> void:
		if skickat or s.is_empty() or plats < 0 or s.tur != plats:
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


func _vanta_pa(villkor: Callable, sek: float, text: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sek * 1000.0:
		if villkor.call():
			return true
		await process_frame
	_ok(false, "tidsgräns: " + text)
	return false


func _init() -> void:
	var server := Server.new()
	server.tempo = 0.08
	server.franvaro_robot = 1.0
	server.logga_ut = false
	root.add_child(server)
	_ok(server.starta(PORT) == OK, "servern startar")
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.kort.size() < 52:
		await process_frame
	main.server_url_tvingad = "ws://127.0.0.1:%d" % PORT
	main.fart_tvingad = 25.0
	main.auto_man = true
	var r := Regler.new()
	r.malpoang = 20
	main.skapa_online("Theo", 3, r, {"fart": 2, "ljud": false, "kasta_tillbaka": true, "fyrfarg": false})
	await _vanta_pa(func() -> bool: return main.online_kod != "", 5.0, "bordskod")
	print("bord: ", main.online_kod)
	_ok(main.ui.lobby_vy.visible, "lobbyn visas")
	var gast := Gast.new()
	root.add_child(gast)
	gast.k.anslut("ws://127.0.0.1:%d" % PORT)
	gast.k.skicka({"t": "ga_med", "kod": main.online_kod, "namn": "Anna"})
	await _vanta_pa(func() -> bool: return gast.plats == 1, 5.0, "gästen går med")
	await _vanta_pa(func() -> bool: return main.senaste_lobby.get("platser", [{}, {}])[1].get("namn", "") == "Anna", 5.0, "lobbyn visar Anna")
	main.lobby_plats(2, "robot", 2)
	await _vanta_pa(func() -> bool: return main.senaste_lobby.platser[2].typ == "robot", 5.0, "robot på plats 2")
	main.lobby_starta()
	await _vanta_pa(func() -> bool: return main.online_kor, 5.0, "partiet startar i klienten")
	var b: Dictionary = server.bord[main.online_kod]
	var m = b.motor
	var brott := 0
	var kontroller := 0
	var avbrott_gjort := false
	var aterbyggd := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await process_frame
		# dolda kort: bara stickkort och egen hand får synas
		var kam: Vector3 = main.kam.global_position
		for c in 52:
			var kk = main.kort[c]
			if kk.i_rorelse() or not kk.visar_framsida_mot(kam):
				continue
			kontroller += 1
			if c in main.stick_vis:
				continue
			if main.min_plats < main.vhand.size() and c in main.vhand[main.min_plats]:
				# måste verkligen vara Theos kort enligt servern (eller nyss spelat)
				if not c in m.hander[main.min_plats] and not _spelat(m, c):
					brott += 1
					print("FEL: kort %d visas som Theos men tillhör inte Theo" % c)
				continue
			brott += 1
			if brott < 6:
				print("FEL: kort %d syns med framsidan upp (giv %d)" % [c, m.giv_nr])
		if not avbrott_gjort and m.giv_nr >= 2 and m.fas == Motor.Fas.STICK:
			# bryt anslutningen: klienten ska ansluta igen själv med sin token
			avbrott_gjort = true
			print("bryter Theos anslutning i giv ", m.giv_nr)
			main.klient.ws.close()
		if avbrott_gjort and not aterbyggd and main.klient.ar_ansluten() and not main.ateransluter:
			aterbyggd = true
			await _vanta_pa(func() -> bool: return main.vantar_pa_drag or not main.fjarr.har_mer(), 20.0, "klienten kommer ikapp")
			print("återansluten, fortsätter")
		if m.fas == Motor.Fas.SLUT and not main.online_kor:
			break
	if m.fas != Motor.Fas.SLUT:
		print("server: fas %d tur %d vanta %.2f platser %s intern %s" % [m.fas, m.tur, b.vanta, str(b.platser.map(func(x): return [x.typ, x.id])), str(m.intern)])
		print("klient: fas %d tur %d skickat %s ko %d inmatning '%s' vantar %s far_ropa %s kor %s" % [main.fjarr.fas, main.fjarr.tur, main.fjarr.skickat, main.fjarr.ko.size(), main.inmatning, main.vantar_pa_drag, main.fjarr.egen.get("far_ropa"), main.online_kor])
		print("gast: plats %d tur %s fas %s skickat %s" % [gast.plats, gast.s.get("tur"), gast.s.get("fas"), gast.skickat])
	_ok(m.fas == Motor.Fas.SLUT, "partiet spelas klart online (giv %d, fas %d)" % [m.giv_nr, m.fas])
	_ok(avbrott_gjort and aterbyggd, "återanslutning provad")
	_ok(main.ui.slut.visible, "slutskärmen visas hos klienten")
	_ok(main.vis_poang == m.poang, "klientens poäng = serverns: %s / %s" % [main.vis_poang, m.poang])
	print("online-scen: %d givar, %d synliga kortlägen kontrollerade, %d brott, %d s" % [m.giv_nr, kontroller, brott, (Time.get_ticks_msec() - t0) / 1000])
	if brott > 0:
		fel += 1
	print("fel: %d" % fel)
	quit(1 if fel else 0)


func _spelat(m, c: int) -> bool:
	for x in m.spelade:
		if x[1] == c:
			return true
	return false
