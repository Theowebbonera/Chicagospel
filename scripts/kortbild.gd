extends Node
## Ritar kortleken i kod: 52 framsidor (hörnindex, rätt placerade valörtecken, klädda kort med figurer)
## och två baksidor. Allt ritas med vektorer i en SubViewport och delas sedan upp i en textur per kort.

const K := preload("res://scripts/kort.gd")

const B := 300  # bredd per kort i pixlar
const HJ := 420  # höjd
const KOL := 14

signal klar

var framsidor: Array = []  # ImageTexture per kort 0–51
var baksidor: Array = []  # [röd, blå]
var fyrfarg := false
var skala := 1.0


func bygg(font: Font) -> void:
	framsidor.clear()
	baksidor.clear()
	if DisplayServer.get_name() == "headless":
		# utan grafik (tester): enkla platshållare, ingen rendering
		await get_tree().process_frame
		_platshallare()
		klar.emit()
		return
	var vp := SubViewport.new()
	# på webben ritas leken i 70 % storlek: mindre minne på mobiler, fortfarande skarpt
	skala = 0.7 if OS.has_feature("web") else 1.0
	vp.size = Vector2i(int(B * KOL * skala), int(HJ * 4 * skala))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_DISABLED if OS.has_feature("web") else Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := Ritare.new()
	r.font = font
	r.fyrfarg = fyrfarg
	r.size = Vector2(B * KOL, HJ * 4)
	vp.add_child(r)
	add_child(vp)
	vp.canvas_transform = Transform2D().scaled(Vector2(skala, skala))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if vp.get_texture() else null
	if img == null or img.is_empty():
		_platshallare()
	else:
		img.convert(Image.FORMAT_RGBA8)
		for c in 52:
			framsidor.append(_bit(img, c % 13, c / 13))
		baksidor = [_bit(img, 13, 0), _bit(img, 13, 1)]
	vp.queue_free()
	klar.emit()


func _platshallare() -> void:
	var tom := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	tom.fill(Color.WHITE)
	var t := ImageTexture.create_from_image(tom)
	framsidor.clear()
	for c in 52:
		framsidor.append(t)
	baksidor = [t, t]


func _bit(img: Image, kol: int, rad: int) -> ImageTexture:
	var bb := int(B * skala)
	var hh := int(HJ * skala)
	var del := img.get_region(Rect2i(kol * bb, rad * hh, bb, hh))
	del.fix_alpha_edges()
	del.generate_mipmaps()
	return ImageTexture.create_from_image(del)


# ==================================================================
class Ritare extends Control:
	const K := preload("res://scripts/kort.gd")
	const B := 300
	const HJ := 420
	var font: Font
	var fyrfarg := false
	var vit: StyleBoxFlat
	var ram: StyleBoxFlat
	var bilder := {}  # färg * 100 + valör -> bild för klädda kort

	func _init() -> void:
		for f in 4:
			for v in [11, 12, 13]:
				var fil := "res://assets/kort/%d_%d.png" % [f, v]
				if ResourceLoader.exists(fil):
					# som ImageTexture: den importerade texturen ritades vit i leken
					bilder[f * 100 + v] = ImageTexture.create_from_image((load(fil) as Texture2D).get_image())

	func _farg(f: int) -> Color:
		if fyrfarg:
			return [Color(0.08, 0.08, 0.1), Color(0.78, 0.06, 0.12), Color(0.06, 0.3, 0.78), Color(0.05, 0.47, 0.16)][f]
		return Color(0.08, 0.08, 0.1) if f == K.SPADER or f == K.KLOVER else Color(0.78, 0.06, 0.12)

	func _draw() -> void:
		vit = StyleBoxFlat.new()
		vit.bg_color = Color(0.985, 0.975, 0.95)
		vit.set_corner_radius_all(22)
		vit.set_border_width_all(2)
		vit.border_color = Color(0.72, 0.7, 0.66)
		vit.anti_aliasing = true
		vit.anti_aliasing_size = 1.2
		ram = StyleBoxFlat.new()
		ram.draw_center = false
		ram.set_border_width_all(2)
		ram.anti_aliasing = true
		for c in 52:
			_kort(c, Vector2((c % 13) * B, (c / 13) * HJ))
		_baksida(Vector2(13 * B, 0), Color(0.6, 0.07, 0.12), Color(0.78, 0.2, 0.24))
		_baksida(Vector2(13 * B, HJ), Color(0.07, 0.19, 0.48), Color(0.2, 0.36, 0.7))
		_tf(Vector2.ZERO)

	# ------------------------------------------------------------ framsida
	func _kort(c: int, o: Vector2) -> void:
		var f := K.farg(c)
		var v := K.valor(c)
		var col := _farg(f)
		_tf(o)
		draw_style_box(vit, Rect2(4, 4, B - 8, HJ - 8))
		_index(f, v, col)
		_tf(o + Vector2(B, HJ), PI)
		_index(f, v, col)
		_tf(o)
		if v == 14:
			var stor := 175.0 if f == K.SPADER else 140.0
			_symbol(f, o + Vector2(B / 2.0, HJ / 2.0), stor, 0.0, col)
			if f == K.SPADER:
				# spader ess får en tunn dekorring som på riktiga lekar
				_tf(o)
				draw_arc(Vector2(B / 2.0, HJ / 2.0 + 4), 112, 0, TAU, 64, col, 2.0, true)
		elif v >= 11:
			_kladd_bild(f, v, col, o)
		else:
			for pt in _pipar(v):
				var p := o + Vector2(B / 2.0 + pt.x * 58.0, HJ / 2.0 + pt.y * 114.0)
				_symbol(f, p, 52.0, PI if pt.y > 0.01 else 0.0, col)

	## kant: på klädda kort når bilden in i hörnet, så indexet får en krämvit kant mot bilden.
	func _index(f: int, v: int, col: Color, kant := false) -> void:
		# stora index: i handen och i sticket ska valören gå att läsa direkt, särskilt Kn och K
		var txt: String = K.VALOR_TECKEN[v]
		var fs := 62
		if txt.length() > 1:
			fs = 42
		if kant:
			draw_string_outline(font, Vector2(4, 64), txt, HORIZONTAL_ALIGNMENT_CENTER, 58, fs, 12, vit.bg_color)
			_symbol_lokal(f, Vector2(33, 98), 44.0, vit.bg_color)
		draw_string(font, Vector2(4, 64), txt, HORIZONTAL_ALIGNMENT_CENTER, 58, fs, col)
		_symbol_lokal(f, Vector2(33, 98), 32.0, col)

	## Valörtecknens platser (kolumn -1..1, rad -1..1) för 2–10.
	func _pipar(v: int) -> Array:
		var a: Array = []
		match v:
			2:
				a = [Vector2(0, -1), Vector2(0, 1)]
			3:
				a = [Vector2(0, -1), Vector2(0, 0), Vector2(0, 1)]
			4:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
			5:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]
			6:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]
			7:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -0.5), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]
			8:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -0.5), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(-1, 1), Vector2(1, 1)]
			9:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, -1.0 / 3), Vector2(1, -1.0 / 3), Vector2(0, 0), Vector2(-1, 1.0 / 3), Vector2(1, 1.0 / 3), Vector2(-1, 1), Vector2(1, 1)]
			10:
				a = [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -2.0 / 3), Vector2(-1, -1.0 / 3), Vector2(1, -1.0 / 3), Vector2(-1, 1.0 / 3), Vector2(1, 1.0 / 3), Vector2(0, 2.0 / 3), Vector2(-1, 1), Vector2(1, 1)]
		return a

	# ------------------------------------------------------------ färgtecken
	func _symbol(f: int, p: Vector2, storlek: float, rot: float, col: Color) -> void:
		_tf(p, rot, Vector2(storlek, storlek))
		_form(f, col)

	## Ritar i nuvarande transform men förskjutet och skalat (används i hörnen och i bilden).
	func _symbol_lokal(f: int, p: Vector2, storlek: float, col: Color) -> void:
		var spar := _mat
		draw_set_transform_matrix(_mat * Transform2D(0.0, Vector2(storlek, storlek), 0.0, p))
		_form(f, col)
		draw_set_transform_matrix(spar)

	var _mat := Transform2D()

	func _tf(pos: Vector2, rot := 0.0, sk := Vector2.ONE) -> void:
		_mat = Transform2D(rot, sk, 0.0, pos)
		draw_set_transform_matrix(_mat)

	func _form(f: int, col: Color) -> void:
		match f:
			K.HJARTER:
				draw_colored_polygon(_hjarta(), col)
			K.RUTER:
				draw_colored_polygon(_ruter(), col)
			K.SPADER:
				var h := _hjarta()
				var sp := PackedVector2Array()
				for q in h:
					sp.append(Vector2(q.x * 0.92, -q.y * 0.86 - 0.08))
				draw_colored_polygon(sp, col)
				draw_colored_polygon(_fot(), col)
			K.KLOVER:
				draw_colored_polygon(_cirkel(Vector2(0, -0.235), 0.215), col)
				draw_colored_polygon(_cirkel(Vector2(-0.235, 0.09), 0.215), col)
				draw_colored_polygon(_cirkel(Vector2(0.235, 0.09), 0.215), col)
				draw_colored_polygon(_cirkel(Vector2(0, 0.0), 0.13), col)
				draw_colored_polygon(_fot(), col)

	func _cirkel(c: Vector2, r: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			p.append(c + Vector2(cos(a), sin(a)) * r)
		return p

	func _hjarta() -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 64:
			var t := TAU * i / 64.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			p.append(Vector2(x / 29.0, (y - 2.5) / 29.0))
		return p

	func _ruter() -> PackedVector2Array:
		var horn := [Vector2(0, -0.52), Vector2(0.39, 0), Vector2(0, 0.52), Vector2(-0.39, 0)]
		var p := PackedVector2Array()
		for i in 4:
			var a: Vector2 = horn[i]
			var b: Vector2 = horn[(i + 1) % 4]
			var mitt := (a + b) * 0.5 * 0.86
			for k in 8:
				var t := k / 8.0
				p.append(a.lerp(mitt, t).lerp(mitt.lerp(b, t), t))
		return p

	func _fot() -> PackedVector2Array:
		return PackedVector2Array([Vector2(-0.045, 0.12), Vector2(0.045, 0.12), Vector2(0.07, 0.33), Vector2(0.14, 0.45), Vector2(0.22, 0.5), Vector2(-0.22, 0.5), Vector2(-0.14, 0.45), Vector2(-0.07, 0.33)])

	# ------------------------------------------------------------ klädda kort
	## Klädda kort med David Bellots bilder (SVG-cards, LGPL-2.1, assets/kort/, gjorda av verktyg/bellot_kladda.py).
	## Bilden har egna ramlinjer; hörnet där de engelska indexen satt är vitt, och de svenska ritas bredvid.
	## Saknas bilden ritas den enkla figuren i kod.
	func _kladd_bild(f: int, v: int, col: Color, o: Vector2) -> void:
		var tex: Texture2D = bilder.get(f * 100 + v)
		if tex == null:
			_kladd(f, v, col, o)
			return
		# bilden fyller kortet med samma proportioner (304 × 469)
		var r := Rect2(0, 0, (HJ - 16) * 304.0 / 469.0, HJ - 16)
		r.position = Vector2((B - r.size.x) / 2.0, 8)
		_tf(o)
		draw_texture_rect(tex, r, false)
		# Bellots engelska hörn är borttagna i bilden; de svenska indexen ritas ovanpå
		for horn in 2:
			if horn == 0:
				_tf(o)
			else:
				_tf(o + Vector2(B, HJ), PI)
			_index(f, v, col, true)
		_tf(o)

	func _kladd(f: int, v: int, col: Color, o: Vector2) -> void:
		var x0 := 66.0
		var y0 := 60.0
		var w := B - 132.0
		var h := HJ - 120.0
		_tf(o)
		var bak := col.lerp(Color(1, 1, 1), 0.9)
		draw_rect(Rect2(x0, y0, w, h), bak)
		var drakt: Array = [Color(0.72, 0.1, 0.12), Color(0.1, 0.22, 0.6), Color(0.93, 0.68, 0.12)]
		if f == K.HJARTER or f == K.RUTER:
			drakt = [Color(0.1, 0.22, 0.6), Color(0.78, 0.1, 0.13), Color(0.93, 0.68, 0.12)]
		# två halvor, den undre roterad ett halvt varv runt mitten
		for halva in 2:
			if halva == 0:
				_tf(o + Vector2(x0, y0))
			else:
				_tf(o + Vector2(x0 + w, y0 + h), PI)
			_figur(f, v, col, drakt, w, h * 0.5)
		_tf(o)
		draw_line(Vector2(x0 + 8, y0 + h * 0.5), Vector2(x0 + w - 8, y0 + h * 0.5), col.lerp(Color.WHITE, 0.4), 2.0, true)
		ram.border_color = col
		ram.set_border_width_all(3)
		ram.set_corner_radius_all(4)
		draw_style_box(ram, Rect2(x0, y0, w, h))
		ram.border_color = Color(0.85, 0.66, 0.2)
		ram.set_border_width_all(1)
		draw_style_box(ram, Rect2(x0 + 5, y0 + 5, w - 10, h - 10))

	func _figur(f: int, v: int, col: Color, d: Array, w: float, h: float) -> void:
		var cx := w * 0.5
		var hud := Color(0.98, 0.84, 0.7)
		var guld := Color(0.93, 0.72, 0.18)
		var mork := Color(0.12, 0.1, 0.12)
		# drakt: axlar och bröst
		var kropp := PackedVector2Array([Vector2(8, h), Vector2(14, h - 34), Vector2(cx - 34, h - 62), Vector2(cx + 34, h - 62), Vector2(w - 14, h - 34), Vector2(w - 8, h)])
		draw_colored_polygon(kropp, d[0])
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 16, h - 62), Vector2(cx + 16, h - 62), Vector2(cx + 22, h), Vector2(cx - 22, h)]), d[1])
		draw_rect(Rect2(cx - 4, h - 60, 8, 60), guld)
		for k in 4:
			draw_circle(Vector2(cx, h - 50 + k * 13), 3.0, Color.WHITE, true, -1.0, true)
		# mönster på ärmarna
		for k in 3:
			var y := h - 26 + k * 9
			draw_line(Vector2(18 + k * 2, y), Vector2(cx - 26, y - 8), guld, 2.5, true)
			draw_line(Vector2(w - 18 - k * 2, y), Vector2(cx + 26, y - 8), guld, 2.5, true)
		# krage
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 30, h - 64), Vector2(cx + 30, h - 64), Vector2(cx + 18, h - 50), Vector2(cx, h - 56), Vector2(cx - 18, h - 50)]), Color(0.97, 0.96, 0.92))
		# huvud
		var hy := h - 92
		if v == 12:
			# dam: hår på sidorna
			draw_circle(Vector2(cx - 18, hy + 6), 15, Color(0.45, 0.25, 0.1), true, -1.0, true)
			draw_circle(Vector2(cx + 18, hy + 6), 15, Color(0.45, 0.25, 0.1), true, -1.0, true)
		draw_circle(Vector2(cx, hy), 22, hud, true, -1.0, true)
		draw_circle(Vector2(cx - 8, hy - 2), 2.6, mork, true, -1.0, true)
		draw_circle(Vector2(cx + 8, hy - 2), 2.6, mork, true, -1.0, true)
		draw_arc(Vector2(cx, hy + 6), 7, 0.4, PI - 0.4, 10, Color(0.7, 0.25, 0.25), 2.0, true)
		match v:
			13:
				# kung: helskägg och krona
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 21, hy + 4), Vector2(cx - 12, hy + 12), Vector2(cx + 12, hy + 12), Vector2(cx + 21, hy + 4), Vector2(cx + 10, hy + 32), Vector2(cx, hy + 36), Vector2(cx - 10, hy + 32)]), Color(0.55, 0.36, 0.2))
				draw_arc(Vector2(cx, hy + 6), 7, 0.4, PI - 0.4, 10, Color(0.75, 0.3, 0.3), 2.0, true)
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 22, hy - 16), Vector2(cx - 24, hy - 42), Vector2(cx - 12, hy - 28), Vector2(cx, hy - 46), Vector2(cx + 12, hy - 28), Vector2(cx + 24, hy - 42), Vector2(cx + 22, hy - 16)]), guld)
				for k in 3:
					draw_circle(Vector2(cx - 12 + k * 12, hy - 21), 2.8, d[0], true, -1.0, true)
				# svärd
				draw_line(Vector2(w - 26, h - 6), Vector2(w - 26, h - 70), Color(0.78, 0.8, 0.84), 4.0, true)
				draw_line(Vector2(w - 36, h - 22), Vector2(w - 16, h - 22), guld, 4.0, true)
			12:
				# dam: tiara och blomma
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 18, hy - 14), Vector2(cx - 10, hy - 28), Vector2(cx, hy - 34), Vector2(cx + 10, hy - 28), Vector2(cx + 18, hy - 14), Vector2(cx, hy - 20)]), guld)
				draw_circle(Vector2(cx, hy - 27), 3.2, d[1], true, -1.0, true)
				var bl := Vector2(26, h - 40)
				draw_line(bl, bl + Vector2(6, 34), Color(0.2, 0.5, 0.2), 3.0, true)
				for k in 5:
					draw_circle(bl + Vector2(cos(TAU * k / 5.0), sin(TAU * k / 5.0)) * 7.0, 5.0, col, true, -1.0, true)
				draw_circle(bl, 4.0, guld, true, -1.0, true)
			11:
				# knekt: basker med fjäder och hillebard
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 26, hy - 10), Vector2(cx - 20, hy - 28), Vector2(cx, hy - 34), Vector2(cx + 22, hy - 28), Vector2(cx + 28, hy - 12), Vector2(cx, hy - 16)]), d[1])
				draw_line(Vector2(cx + 14, hy - 28), Vector2(cx + 34, hy - 50), Color(0.95, 0.95, 0.9), 4.0, true)
				draw_line(Vector2(cx + 18, hy - 30), Vector2(cx + 30, hy - 48), guld, 1.5, true)
				draw_line(Vector2(24, h - 4), Vector2(24, h - 78), Color(0.5, 0.32, 0.16), 3.5, true)
				draw_colored_polygon(PackedVector2Array([Vector2(24, h - 92), Vector2(32, h - 76), Vector2(24, h - 70), Vector2(16, h - 76)]), Color(0.75, 0.77, 0.8))
		# färgtecken i övre hörnet av bilden
		_symbol_lokal(f, Vector2(w - 22, 22), 26.0, col)

	# ------------------------------------------------------------ baksida
	func _baksida(o: Vector2, bas: Color, ljus: Color) -> void:
		_tf(o)
		draw_style_box(vit, Rect2(4, 4, B - 8, HJ - 8))
		var inner := Rect2(20, 20, B - 40, HJ - 40)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bas
		sb.set_corner_radius_all(12)
		sb.anti_aliasing = true
		draw_style_box(sb, inner)
		# rutmönster av små romber
		var steg := 18.0
		var y := inner.position.y + 10
		var rad := 0
		while y < inner.end.y - 8:
			var x := inner.position.x + 10 + (steg * 0.5 if rad % 2 == 1 else 0.0)
			while x < inner.end.x - 8:
				draw_colored_polygon(PackedVector2Array([Vector2(x, y - 6), Vector2(x + 6, y), Vector2(x, y + 6), Vector2(x - 6, y)]), ljus)
				x += steg
			y += steg * 0.5
			rad += 1
		ram.border_color = Color(0.98, 0.92, 0.75)
		ram.set_border_width_all(3)
		ram.set_corner_radius_all(12)
		draw_style_box(ram, inner)
		ram.set_border_width_all(1)
		ram.set_corner_radius_all(8)
		draw_style_box(ram, inner.grow(-9))
		# medaljong i mitten
		var m := Vector2(B / 2.0, HJ / 2.0)
		_tf(o + m, 0.0, Vector2(1.0, 1.35))
		draw_circle(Vector2.ZERO, 62, Color(0.98, 0.92, 0.75), true, -1.0, true)
		draw_circle(Vector2.ZERO, 56, bas, true, -1.0, true)
		draw_arc(Vector2.ZERO, 48, 0, TAU, 64, Color(0.95, 0.78, 0.35), 2.0, true)
		_tf(o)
		draw_string(font, Vector2(m.x - 60, m.y + 30), "C", HORIZONTAL_ALIGNMENT_CENTER, 120, 92, Color(0.98, 0.86, 0.5))
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4
			var p := m + Vector2(cos(a) * 92, sin(a) * 140)
			_tf(o + p, 0.0, Vector2(22, 22))
			draw_colored_polygon(_ruter(), Color(0.98, 0.92, 0.75))
		_tf(o)
