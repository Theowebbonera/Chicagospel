extends SceneTree
## Rastrerar bilderna på de klädda korten ur Byron Knolls Vector Playing Cards (public domain) till assets/kort/.
## Bara bildramen tas med; hörnindex och valörtecken ritar kortbild.gd själv (svenska Kn, D, K).
##   Godot --headless --path . --script res://verktyg/rasta_kladda.gd -- <mapp med svg-cards>

const RAM := Rect2(0.1306, 0.0929, 0.7343, 0.8142)  # bildramen i andelar av kortet (samma i alla klädda kort)
const UT_B := 300
const UT_H := 484
const VALORER := {11: "jack", 12: "queen", 13: "king"}
const FARGER := ["spades", "hearts", "diamonds", "clubs"]  # samma ordning som kort.gd


func _init() -> void:
	var kalla := ""
	for a in OS.get_cmdline_user_args():
		kalla = a
	if kalla == "":
		push_error("Ange mappen med svg-cards")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/kort"))
	for f in 4:
		for v in VALORER:
			var fil := "%s/%s_of_%s.svg" % [kalla, VALORER[v], FARGER[f]]
			var img := Image.new()
			if img.load_svg_from_buffer(FileAccess.get_file_as_bytes(fil), 4.0) != OK:
				push_error("Kunde inte läsa " + fil)
				quit(1)
				return
			var w := img.get_width()
			var h := img.get_height()
			var del := img.get_region(Rect2i(int(RAM.position.x * w), int(RAM.position.y * h), int(RAM.size.x * w), int(RAM.size.y * h)))
			del.resize(UT_B, UT_H, Image.INTERPOLATE_LANCZOS)
			var ut := "res://assets/kort/%d_%d.png" % [f, v]
			del.save_png(ProjectSettings.globalize_path(ut))
			print("sparad ", ut)
	quit()
