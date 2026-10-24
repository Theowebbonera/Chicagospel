extends SceneTree
## Ritar kortleken och sparar den som bild: Godot --path . --position 4000,4000 --script res://verktyg/rita_kort.gd -- ut.png

const Kortbild := preload("res://scripts/kortbild.gd")


func _init() -> void:
	await process_frame
	var kb := Kortbild.new()
	root.add_child(kb)
	var font := FontVariation.new()
	font.base_font = load("res://assets/Fredoka.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	kb.fyrfarg = "--fyrfarg" in OS.get_cmdline_user_args()
	await kb.bygg(font)
	var ut := "user://kortlek.png"
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			ut = a
	# sätt ihop till en översiktsbild
	var bild := Image.create(Kortbild.B * 14, Kortbild.HJ * 4, false, Image.FORMAT_RGBA8)
	bild.fill(Color(0.1, 0.35, 0.2))
	for c in 52:
		var i: Image = kb.framsidor[c].get_image()
		bild.blend_rect(i, Rect2i(0, 0, Kortbild.B, Kortbild.HJ), Vector2i((c % 13) * Kortbild.B, (c / 13) * Kortbild.HJ))
	for k in 2:
		var i: Image = kb.baksidor[k].get_image()
		bild.blend_rect(i, Rect2i(0, 0, Kortbild.B, Kortbild.HJ), Vector2i(13 * Kortbild.B, k * Kortbild.HJ))
	bild.save_png(ut)
	print("sparad: ", ut)
	quit()
