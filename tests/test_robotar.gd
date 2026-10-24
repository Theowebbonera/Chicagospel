extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_robotar.gd
## Hela partier mellan robotar till målpoängen med olika antal spelare, nivåer och regler.
## Kontrollerar att inga otillåtna drag görs, att korten bevaras och att partiet tar slut med rätt vinnare.

const Motor := preload("res://scripts/motor.gd")
const Regler := preload("res://scripts/regler.gd")
const Robot := preload("res://scripts/robot.gd")

var fel := 0


func _ok(v: bool, t: String) -> void:
	if not v:
		fel += 1
		print("FEL: ", t)


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


## Spelar ett helt parti. Returnerar statistik.
func parti(nivaer: Array, r, fro: int) -> Dictionary:
	var m := Motor.new()
	var namn: Array = []
	for i in nivaer.size():
		namn.append("Robot %d" % i)
	m.starta(namn, r, fro)
	var rng := RandomNumberGenerator.new()
	rng.seed = fro * 31 + 1
	var stat := {"givar": 0, "chicago": 0, "chicago_ok": 0, "drag": 0, "vinnare": -1, "stick_tvaa": 0}
	var giv := 0
	# säkerhetstak: ett parti får inte bli oändligt
	while m.fas != Motor.Fas.SLUT and giv < 1500:
		m.ny_giv()
		giv += 1
		var steg := 0
		while m.fas == Motor.Fas.BYTE or m.fas == Motor.Fas.CHICAGO or m.fas == Motor.Fas.STICK:
			steg += 1
			if steg > 200:
				_ok(false, "given fastnade")
				break
			var p: int = m.tur
			var niva: int = nivaer[p]
			var vy := m.vy(p)
			var ok := false
			match m.fas:
				Motor.Fas.BYTE:
					ok = m.byt(p, Robot.valj_byte(vy, niva, rng))
				Motor.Fas.CHICAGO:
					ok = m.ropa_chicago(p, Robot.valj_chicago(vy, niva, rng))
				Motor.Fas.STICK:
					ok = m.spela(p, Robot.valj_kort(vy, niva, rng))
			_ok(ok, "otillåtet drag av robot %d i fas %d" % [p, m.fas])
			if not ok:
				return stat
			stat.drag += 1
			if not _bevarade(m):
				_ok(false, "kort försvann eller dubblerades")
				return stat
		for e in m.ta_handelser():
			if e.typ == "chicago":
				stat.chicago += 1
			elif e.typ == "poang" and e.orsak == "chicago":
				stat.chicago_ok += 1
			elif e.typ == "poang" and e.text == "Sista sticket med en tvåa":
				stat.stick_tvaa += 1
	stat.givar = giv
	stat.vinnare = m.vinnare
	_ok(m.fas == Motor.Fas.SLUT, "partiet tog inte slut")
	_ok(m.vinnare >= 0 and m.far_vinna(m.vinnare), "vinnaren uppfyller vinstvillkoren (målpoäng och vid husregeln en tagen Chicago)")
	if m.vinnare >= 0:
		for q in m.n:
			_ok(not m.far_vinna(q) or m.poang[q] <= m.poang[m.vinnare], "ingen annan som uppfyller villkoren har fler poäng")
	return stat


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var fall := [
		["2 spelare medel", [1, 1], func(_r): pass],
		["3 spelare blandat", [0, 1, 2], func(_r): pass],
		["4 spelare svåra", [2, 2, 2, 2], func(_r): pass],
		["4 spelare standard", [0, 1, 2, 1], func(_r): pass],
		["5 spelare", [1, 0, 1, 0, 1], func(_r): pass],
		["6 spelare, omblandning", [1, 1, 0, 0, 1, 2], func(_r): pass],
		["6 spelare utan omblandning", [0, 0, 1, 1, 0, 0], func(r): r.blanda_om = false],
		["inga byten", [1, 1, 1], func(r): r.antal_byten = 0],
		["fem byten, poäng alla, max 3", [1, 2, 0, 1], func(r):
			r.antal_byten = 5
			r.poang_byten = 2
			r.max_byte = 3],
		["poäng vid given dubbelt, ingen vid lika", [1, 1, 1, 1], func(r):
			r.poang_vid_given = 2
			r.lika_regel = 1],
		["ingen vinst på stick, chicago kräver 20", [2, 1, 2], func(r):
			r.vinna_pa_stick = false
			r.chicago_min = 20],
		["chicago avstängd, mål 30", [1, 1, 1, 1], func(r):
			r.chicago_tillatet = false
			r.malpoang = 30],
		["klassiska regler", [2, 0, 1, 2], func(r): r.klassiska()],
		["husregler, köpstopp 20, chicago från 5", [2, 1, 2, 1], func(r):
			r.kopstopp = 20
			r.chicago_min = 5],
	]
	var vinster := [0, 0, 0]
	var tot_chic := 0
	var tot_ok := 0
	var fro := 1
	for f in fall:
		var r := Regler.new()
		f[2].call(r)
		for k in 2:
			fro += 1
			var t1 := Time.get_ticks_msec()
			var s := parti(f[1], r, fro)
			tot_chic += s.chicago
			tot_ok += s.chicago_ok
			print("%-42s frö %3d: %3d givar, vinnare %d (%s), chicago %d/%d, %d ms" % [f[0], fro, s.givar, s.vinnare, Robot.NIVA_NAMN[f[1][s.vinnare]] if s.vinnare >= 0 else "-", s.chicago_ok, s.chicago, Time.get_ticks_msec() - t1])
	# nivåjämförelse: lätt mot medel mot svår, platserna roteras
	var r2 := Regler.new()
	for i in 12:
		var niv: Array = [[0, 1, 2], [1, 2, 0], [2, 0, 1]][i % 3]
		var s := parti(niv, r2, 500 + i)
		if s.vinnare >= 0:
			vinster[niv[s.vinnare]] += 1
	print("vinster per nivå i 12 partier (lätt, medel, svår): ", vinster)
	print("chicago: %d rop, %d lyckade" % [tot_chic, tot_ok])
	print("tid %d ms, fel: %d" % [Time.get_ticks_msec() - t0, fel])
	quit(1 if fel else 0)
