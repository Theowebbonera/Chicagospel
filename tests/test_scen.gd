extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_scen.gd
## Startar hela 3D-scenen och låter fyra robotar spela ett helt parti (snabbat) till slutskärmen.
## Kontrollerar att grafikens bild av händerna stämmer med motorn när varje drag ska göras.
## Under partiet kastas vattenballonger, tomater och rosor på figurerna, vilket inte får påverka spelet.

const Regler := preload("res://scripts/regler.gd")
const Motor := preload("res://scripts/motor.gd")
const TYPER := ["vattenballong", "tomat", "tarta", "snoboll", "flygplan", "ros", "hjarta", "krona", "konfetti", "sexsju"]

var fel := 0


func _init() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.kort.size() < 52:
		await process_frame
	main.fart_tvingad = 60.0
	var sp: Array = []
	for i in 4:
		sp.append({"namn": "Robot %d" % i, "robot": true, "niva": [2, 1, 2, 0][i]})
	main.starta_parti(sp, Regler.new(), {"oppna": true, "fyrfarg": false, "fart": 2, "ljud": false})
	for i in 5:
		await process_frame
	# kastmenyn: öppnas för en figur, startar ett kast och spärrtiden stoppar nästa
	main.ui.visa_kastmeny(Vector2(400, 300), 2, "Robot 2")
	if not main.ui.kastmeny.visible:
		fel += 1
		print("FEL: kastmenyn öppnades inte")
	var barn_fore := main.get_child_count()
	main.ui.kastmeny.id_pressed.emit(0)
	if main.kastsparr <= 0.0 or main.get_child_count() <= barn_fore:
		fel += 1
		print("FEL: vattenballongen kastades inte")
	var sparr: float = main.kastsparr
	var barn_efter := main.get_child_count()
	main.ui.kastmeny.id_pressed.emit(1)
	if main.get_child_count() != barn_efter or main.kastsparr > sparr:
		fel += 1
		print("FEL: spärrtiden stoppade inte ett andra kast")
	var t0 := Time.get_ticks_msec()
	var senaste := ""
	var kontroller := 0
	var kast := 0
	var provade := {}
	while Time.get_ticks_msec() - t0 < 240000:
		await process_frame
		if main.ui.slut.visible:
			break
		if Engine.get_process_frames() % 60 == 0 and not main.gubbar.is_empty():
			var mal: int = 1 + (kast % 3)
			main._kasta(-1, mal, TYPER[kast % TYPER.size()], true)
			provade[TYPER[kast % TYPER.size()]] = true
			kast += 1
			if kast == 5:
				main.kastsparr = 0.0
				main._egen_sexsju()
				provade["egen 6-7"] = true
		if false:
			break
		var m = main.motor
		if m == null:
			continue
		# när motorn väntar på ett drag och alla animeringar är uppspelade ska händerna stämma
		var nyckel := "%d-%d-%d-%d" % [m.giv_nr, m.fas, m.tur, m.spelade.size() + m.byte_nr * 100]
		if nyckel != senaste and main.vantar_pa_drag:
			senaste = nyckel
			for p in 4:
				var a: Array = m.hander[p].duplicate()
				var b: Array = main.vhand[p].duplicate()
				a.sort()
				b.sort()
				if a != b:
					fel += 1
					print("FEL: grafikens hand %d stämmer inte med motorn: %s / %s" % [p, b, a])
			kontroller += 1
	var m = main.motor
	if not main.ui.slut.visible or m.fas != Motor.Fas.SLUT:
		fel += 1
		print("FEL: partiet tog inte slut (fas %d, giv %d)" % [m.fas, m.giv_nr])
	else:
		print("partiet klart efter %d givar på %d s, vinnare %s med %d poäng, %d handkontroller, %d kast" % [m.giv_nr, (Time.get_ticks_msec() - t0) / 1000, m.namn[m.vinnare], m.poang[m.vinnare], kontroller, kast])
	for t in TYPER + ["egen 6-7"]:
		if not provade.has(t):
			fel += 1
			print("FEL: %s provades inte" % t)
	print("provade kast och hälsningar: %d av %d" % [provade.size(), TYPER.size() + 1])
	print("fel: %d" % fel)
	quit(1 if fel else 0)
