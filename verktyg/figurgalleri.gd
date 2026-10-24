extends SceneTree
## Renderar alla figurer i en bild: Godot --path . --position 4000,4000 --script res://verktyg/figurgalleri.gd -- ut.png

const Gubbe := preload("res://scripts/gubbe.gd")
const Figurer := preload("res://scripts/figurer.gd")


func _init() -> void:
	await process_frame
	root.size = Vector2i(1800, 900)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.2, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	root.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.7, 0.4, 0)
	sol.light_energy = 1.4
	root.add_child(sol)
	var n := Figurer.antal()
	var per_rad := 7
	for i in n:
		var g := Gubbe.new()
		root.add_child(g)
		g.bygg_figur(i)
		g.position = Vector3((i % per_rad - 3) * 2.6, -(i / per_rad) * 4.6, 0)
		g.bas_y = g.position.y
		g.rotation.y = PI  # -Z mot kameran
		g.titta_pa(Vector3(0, 0, 20))
		var l := Label3D.new()
		l.text = Figurer.namn(i)
		l.font_size = 64
		l.pixel_size = 0.006
		l.position = g.position + Vector3(0, -0.9, 1.0)
		root.add_child(l)
	var kam := Camera3D.new()
	kam.position = Vector3(0, -0.6, 16)
	kam.fov = 52
	root.add_child(kam)
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var ut := "user://figurer.png"
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			ut = a
	img.save_png(ut)
	quit()
