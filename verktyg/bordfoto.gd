extends SceneTree
## Skärmbilder av bordet mitt i ett parti, för att jämföra grafiken (Theo 2026-11-12).
## Fyra spelare mot en lokal server: Theo i spelet och tre enkla klienter (testspelarens logik).
##
##   Godot --path . --script res://verktyg/bordfoto.gd -- ut_katalog [prefix]
##   Godot --path . --rendering-method gl_compatibility --script res://verktyg/bordfoto.gd -- ut_katalog webb
##
## Bilder: <prefix>_byte.png (egen hand vid bytet) och <prefix>_stick.png (kort i sticket).

const Server := preload("res://scripts/server.gd")
const Regler := preload("res://scripts/regler.gd")
const Motor := preload("res://scripts/motor.gd")
const Gast := preload("res://verktyg/bordfoto_gast.gd")
const Figurer := preload("res://scripts/figurer.gd")

const PORT := 9187


func _vanta(sek: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sek * 1000.0:
		await process_frame


func _vanta_pa(villkor: Callable, sek: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sek * 1000.0:
		if villkor.call():
			return true
		await process_frame
	return false


func _spara(katalog: String, namn: String) -> void:
	await RenderingServer.frame_post_draw
	var bild := root.get_texture().get_image()
	var fil := katalog.path_join(namn)
	bild.save_png(fil)
	print("sparade ", fil)


## Närbild av figuren till vänster och den mittemot: armarna på bordskanten.
func _narbild(main: Node, katalog: String, prefix: String) -> void:
	var kam: Camera3D = main.kam
	main.set_process(false)
	for p in main.gubbar.size():
		var g = main.gubbar[p]
		if g == null or not g.visible:
			continue
		var h: Vector3 = g.huvudpos()
		var mot := Vector3(-h.x, 0, -h.z).normalized()
		var sida := mot.cross(Vector3.UP).normalized()
		kam.global_position = h + mot * 7.0 + Vector3.UP * 1.0 + sida * 2.5
		kam.look_at(h - Vector3.UP * 1.6, Vector3.UP)
		await _vanta(0.3)
		await _spara(katalog, "%s_narbild_%d.png" % [prefix, p])
		# Lukas: skratta och fånga handen uppe strax före smällen vid 2,145 s, och vid smällen
		if Figurer.skratt(int(main.spelare[p].get("figur", 0))) != "":
			main._skratt(p)
			while g.skratt_tid < main.SKRATT_FORE + 2.145 - 0.12:
				await process_frame
			var sk: Skeleton3D = g.skelett
			for sd in ["r", "l"]:
				var hw: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_" + sd)).origin
				print("LYFT %s: tid %.3f lyft %.2f handens y %.2f slag %s" % [sd, g.skratt_tid, g._slaglyft(sd), hw.y, str(g.skratt_slag)])
			g.set_process(false)  # fryst medan bilden ritas: långsamma datorer hinner annars förbi slaget
			await _spara(katalog, "%s_skratt_upp_%d.png" % [prefix, p])
			g.set_process(true)
			while g.skratt_tid < main.SKRATT_FORE + 2.145:
				await process_frame
			await _spara(katalog, "%s_skratt_slag_%d.png" % [prefix, p])
	main.set_process(true)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var katalog: String = args[0] if args.size() > 0 else "user://"
	var prefix: String = args[1] if args.size() > 1 else "dator"
	root.size = Vector2i(1600, 900)
	var server := Server.new()
	server.tempo = 0.6
	server.logga_ut = false
	root.add_child(server)
	server.starta(PORT)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.kort.size() < 52:
		await process_frame
	main.server_url_tvingad = "ws://127.0.0.1:%d" % PORT
	var r := Regler.new()
	var gaster: Array = []
	var namn := ["Anna", "Lukas", "Adam"]
	var figur := [0, 2, 3]
	for i in 3:
		var g := Gast.new()
		root.add_child(g)
		g.k.anslut("ws://127.0.0.1:%d" % PORT)
		gaster.append(g)
	var vard = gaster[0]
	vard.k.skicka({"t": "skapa", "namn": namn[0], "antal": 4, "regler": r.till_dict(), "figur": figur[0]})
	await _vanta_pa(func() -> bool: return vard.kod != "", 5.0)
	for i in range(1, 3):
		gaster[i].k.skicka({"t": "ga_med", "kod": vard.kod, "namn": namn[i], "figur": figur[i]})
	main.ui.visa_ga_med(vard.kod, "", 1)
	await _vanta_pa(func() -> bool: return main.ui.ga_tagna.size() >= 3, 5.0)
	main.ui.ga_knapp.pressed.emit()
	await _vanta_pa(func() -> bool: return main.ui.lobby_vy.visible and main.min_plats >= 0, 5.0)
	await _vanta(0.5)
	vard.k.skicka({"t": "starta"})
	await _vanta_pa(func() -> bool: return main.online_kor, 5.0)
	var tagit_byte := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		if main.vantar_pa_drag and main.inmatning != "":
			match main.inmatning:
				"byte":
					if not tagit_byte:
						tagit_byte = true
						await _vanta(1.5)
						await _spara(katalog, prefix + "_byte.png")
						# inzoomningen vid Chicago: mot figuren mittemot, handen ska ligga kvar på skärmen
						main._zooma_chicago((main.betraktare + 2) % main.n)
						await _vanta(1.2)
						await _spara(katalog, prefix + "_zoom.png")
						await _vanta(2.0)
					main.valda = []
					main.beslut.emit("byt")
				"upp":
					main.beslut.emit(false)
				"chicago":
					main.beslut.emit(false)
				"spela":
					if main.stick_vis.size() >= 2:
						await _vanta(1.2)
						await _spara(katalog, prefix + "_stick.png")
						await _narbild(main, katalog, prefix)
						quit()
						return
					if not main.tillatna.is_empty():
						main.beslut.emit(main.tillatna[0])
	print("hann inte till sticket")
	quit()
