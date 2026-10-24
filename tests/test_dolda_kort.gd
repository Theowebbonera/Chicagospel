extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_dolda_kort.gd
## Spelar med hela 3D-scenen (snabbat) och kontrollerar i varje bildruta att inga kort syns med framsidan upp
## utom de som reglerna tillåter: kort i pågående stick och den egna handen för den människa som har turen
## (vid en enda människa: den människans hand). Vid poängsättning vänds inga kort. Provas med en människa mot robotar och med två människor vid samma dator.

const Regler := preload("res://scripts/regler.gd")

var fel := 0


func _init() -> void:
	await _fall("en människa mot tre robotar", [true, false, false, false], 2)
	await _fall("två människor vid samma dator", [true, false, true, false], 2)
	print("fel: %d" % fel)
	quit(1 if fel else 0)


func _fall(namn: String, manniska: Array, givar: int) -> void:
	var main: Node = load("res://main.tscn").instantiate()
	main.fart_tvingad = 30.0
	root.add_child(main)
	while main.kort.size() < 52:
		await process_frame
	main.auto_man = true
	main.fart_tvingad = 30.0
	var sp: Array = []
	for i in manniska.size():
		sp.append({"namn": "S%d" % i, "robot": not manniska[i], "niva": 1})
	var r := Regler.new()
	main.starta_parti(sp, r, {"oppna": true, "fyrfarg": false, "fart": 2, "ljud": false})
	var rutor := 0
	var brott := 0
	var overlamningar := 0
	var sag_overlamning := false
	var kontroller := 0
	var poangkoll := 0
	var t0 := Time.get_ticks_msec()
	while rutor < 200000 and Time.get_ticks_msec() - t0 < 150000:
		await process_frame
		rutor += 1
		# kast på figurerna ska inte avslöja några kort
		if rutor % 120 == 0 and not main.gubbar.is_empty():
			for q in main.gubbar.size():
				if q != main.betraktare:
					main._kasta(-1, q, ["vattenballong", "tomat", "tarta", "snoboll", "flygplan", "ros", "hjarta", "krona", "konfetti", "sexsju"][(rutor / 120) % 10], true)
					break
		if main.ui.overlamning.visible and not sag_overlamning:
			overlamningar += 1
			# när överlämningen visas får ingen hand vara uppvänd
			for c in 52:
				var k = main.kort[c]
				if not k.i_rorelse() and k.visar_framsida_mot(main.kam.global_position) and not c in main.stick_vis:
					var agare := _agare(main, c)
					if agare >= 0:
						brott += 1
						print("FEL (%s): kort %d hos %d syns under överlämning" % [namn, c, agare])
		sag_overlamning = main.ui.overlamning.visible
		if main.motor == null or main.meny_lage:
			continue
		# givens poäng visas direkt: under bytena stämmer poängtavlan med motorns totaler
		if main.vantar_pa_drag and main.motor.fas == main.Motor.Fas.BYTE:
			poangkoll += 1
			if main.vis_poang != main.motor.poang:
				brott += 1
				print("FEL (%s): poängtavlan %s visar inte givens poäng %s under bytena" % [namn, main.vis_poang, main.motor.poang])
		var kam: Vector3 = main.kam.global_position
		for c in 52:
			var k = main.kort[c]
			if k.i_rorelse() or not k.visar_framsida_mot(kam):
				continue
			kontroller += 1
			if c in main.stick_vis:
				continue
			var agare := _agare(main, c)
			if agare >= 0 and main._halls(agare):
				continue
			brott += 1
			if brott < 10:
				print("FEL (%s): kort %d syns (ägare %d, robot %s) giv %d" % [namn, c, agare, str(agare >= 0 and main.spelare[agare].robot), main.motor.giv_nr])
		if main.motor.giv_nr > givar or main.motor.fas == main.Motor.Fas.SLUT:
			break
	print("%s: %d bildrutor, %d givar, %d synliga kortlägen kontrollerade, %d poängkontroller under bytena, %d överlämningar, %d brott" % [namn, rutor, main.motor.giv_nr, kontroller, poangkoll, overlamningar, brott])
	if brott > 0:
		fel += 1
	if manniska.count(true) > 1 and overlamningar == 0:
		print("FEL: ingen överlämningsskärm visades")
		fel += 1
	if main.motor.giv_nr < givar:
		print("FEL: spelet kom inte framåt")
		fel += 1
	main.queue_free()
	await process_frame


func _agare(main: Node, c: int) -> int:
	for p in main.vhand.size():
		if c in main.vhand[p]:
			return p
	return -1
