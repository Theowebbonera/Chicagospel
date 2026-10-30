extends SceneTree
## Kör: Godot --headless --path . --script res://tests/test_figurer.gd
## Bygger alla figurer i galleriet och låter var och en andas, titta, gestikulera, jubla, göra 6-7
## och träffas av alla sorters kast. Kontrollerar att inget saknas och att slumpade figurer blir unika.

const Gubbe := preload("res://scripts/gubbe.gd")
const Figurer := preload("res://scripts/figurer.gd")

var fel := 0


func _ok(v: bool, t: String) -> void:
	if not v:
		fel += 1
		print("FEL: ", t)


func _init() -> void:
	await process_frame
	_ok(Figurer.antal() == 4, "fyra figurer (%d)" % Figurer.antal())
	for i in Figurer.antal():
		var d: Dictionary = Figurer.FIGURER[i]
		var g := Gubbe.new()
		root.add_child(g)
		g.bygg_figur(i)
		g.position = Vector3(i * 3.0, 0, 0)
		# skelett med huvud, armar och händer, och effekterna på huvudet
		_ok(g.skelett != null and g.huvud != null and g.tomatfleck != null and g.bubbla != null and g.ben.size() == 9 and not g.ben.values().has(-1), "%s har skelett och alla delar" % d.namn)
		g.titta_pa(Vector3(0, 2, -5))
		g.gest()
		for typ in ["vattenballong", "tomat", "tarta", "snoboll", "flygplan", "ros", "hjarta", "krona", "konfetti"]:
			g.traffad(typ)
		g.jubel(true)
		g.sexsju()
		for f in 30:
			await process_frame
		g.ledsen()
		for f in 10:
			await process_frame
		_ok(g.traff_avstand(g.huvudpos() + Vector3(0, 0, -10), Vector3(0, 0, 1)) > 0.0, "%s går att klicka på" % d.namn)
		g.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var f := Figurer.fordela([2, -1, -1, -1], rng)
	var unika := {}
	for x in f:
		unika[x] = true
	_ok(unika.size() == 4 and f[0] == 2, "slumpade figurer är unika och valda behålls: %s" % [f])
	# fler spelare än figurer: alla figurer används, de sista får dubbletter
	f = Figurer.fordela([2, -1, -1, -1, -1, -1], rng)
	unika = {}
	for x in f:
		unika[x] = true
	_ok(unika.size() == 4 and f[0] == 2 and not f.has(-1), "sex spelare får alla fyra figurerna: %s" % [f])
	print("%d figurer provade, fel: %d" % [Figurer.antal(), fel])
	quit(1 if fel else 0)
