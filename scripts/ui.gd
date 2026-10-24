extends CanvasLayer
## Allt 2D-gränssnitt: huvudmeny, inställningar för nytt parti (spelare + alla regler), regelsida,
## poängtavla, fas, banderoller, åtgärdsknappar, händelselogg, överlämning mellan människor, paus och slutskärm.

const Regler := preload("res://scripts/regler.gd")
const Figurer := preload("res://scripts/figurer.gd")
const Gubbe := preload("res://scripts/gubbe.gd")

signal snabbstart
signal starta(spelare: Array, regler, visning: Dictionary)
signal atgard(data)
signal overlamning_klar
signal till_meny
signal spela_igen
signal avsluta
signal paus_andrad(pausad: bool)
signal kasta(mal: int, typ: String)
signal egen_sexsju
signal skapa_online(namn: String, antal: int, regler, visning: Dictionary)
signal ga_med_online(kod: String, namn: String)
signal lobby_plats(plats: int, typ: String, niva: int)
signal lobby_fyll
signal lobby_starta
signal lobby_lamna
signal lobby_figur(figur: int)

const KASTA := [["vattenballong", "Vattenballong"], ["tomat", "Tomat"], ["tarta", "Gräddtårta"], ["snoboll", "Snöboll"], ["flygplan", "Pappersflygplan"]]
const HALSA := [["ros", "Ros"], ["hjarta", "Fingerkyss"], ["krona", "Krona"], ["konfetti", "Konfetti"], ["sexsju", "6-7"]]

const GULD := Color(0.95, 0.77, 0.36)
const KRAM := Color(0.97, 0.94, 0.87)
const GRA := Color(0.68, 0.66, 0.6)
const SPELARFARG := [Color(0.95, 0.77, 0.36), Color(0.42, 0.72, 0.98), Color(0.95, 0.45, 0.42), Color(0.55, 0.85, 0.5), Color(0.8, 0.55, 0.95), Color(0.98, 0.6, 0.25)]
const TYPER := ["Människa", "Robot – lätt", "Robot – medel", "Robot – svår"]
const STANDARDNAMN := ["Theo", "Astrid", "Bertil", "Cecilia", "Doris", "Erik"]

var font_r: FontVariation
var font_b: FontVariation
var tema: Theme

var huvudmeny: Control
var installningar: Control
var regelvy: Control
var hud: Control
var overlamning: Control
var paus: Control
var slut: Control

# inställningar
var arb_regler
var regel_kontroller := {}
var antal_spin: SpinBox
var spelar_rader: Array = []
var vis_fyrfarg: CheckBox
var vis_fart: OptionButton
var vis_ljud: CheckBox
var vis_kasta: CheckBox
var inst_titel: Label
var inst_start: Button
var antal_text: Label
var inst_tips: Label
var kastmeny: PopupMenu
var kast_mal := -1

# hud
var tavla_rader: Array = []
var tavla_rubrik: Label
var fas_label: Label
var fas_panel: PanelContainer
var banner: Label
var banner_under: Label
var banner_tw: Tween
var atgard_panel: PanelContainer
var atgard_info: Label
var atgard_hand: Label
var atgard_knappar: HBoxContainer
var logg: VBoxContainer
var regel_text: RichTextLabel
var overlamning_namn: Label
var overlamning_text: Label
var slut_titel: Label
var slut_lista: VBoxContainer
var mal := 52
var ar_pausad := false


func _ready() -> void:
	layer = 5
	_tema()
	_bygg_hud()
	_bygg_huvudmeny()
	_bygg_installningar()
	_bygg_regelvy()
	_bygg_overlamning()
	_bygg_paus()
	_bygg_slut()
	_bygg_online()
	_bygg_figurvaljare()
	visa_huvudmeny()


# ================================================================== tema
func _tema() -> void:
	var base: FontFile = load("res://assets/Fredoka.ttf")
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	font_r = FontVariation.new()
	font_r.base_font = base
	font_r.variation_opentype = {wght: 450}
	font_b = FontVariation.new()
	font_b.base_font = base
	font_b.variation_opentype = {wght: 620}
	tema = Theme.new()
	tema.default_font = font_r
	tema.default_font_size = 22
	tema.set_color("font_color", "Label", KRAM)
	var knapp := _sb(Color(0.1, 0.16, 0.12, 0.95), 12, Color(0.95, 0.77, 0.36, 0.45), 1)
	knapp.content_margin_left = 20
	knapp.content_margin_right = 20
	knapp.content_margin_top = 10
	knapp.content_margin_bottom = 10
	var hov := knapp.duplicate()
	hov.bg_color = Color(0.16, 0.26, 0.19, 0.98)
	hov.border_color = GULD
	var tryck := knapp.duplicate()
	tryck.bg_color = Color(0.08, 0.12, 0.09)
	var av := knapp.duplicate()
	av.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	av.border_color = Color(0.4, 0.4, 0.4, 0.4)
	for typ in ["Button", "OptionButton"]:
		tema.set_stylebox("normal", typ, knapp)
		tema.set_stylebox("hover", typ, hov)
		tema.set_stylebox("pressed", typ, tryck)
		tema.set_stylebox("disabled", typ, av)
		tema.set_stylebox("focus", typ, StyleBoxEmpty.new())
		tema.set_color("font_color", typ, KRAM)
		tema.set_color("font_hover_color", typ, Color.WHITE)
		tema.set_color("font_disabled_color", typ, Color(0.5, 0.5, 0.5))
	tema.set_font("font", "Button", font_b)
	tema.set_stylebox("panel", "PanelContainer", _sb(Color(0.035, 0.05, 0.042, 0.9), 16, Color(0.95, 0.77, 0.36, 0.28), 1))
	tema.set_stylebox("panel", "PopupMenu", _sb(Color(0.06, 0.08, 0.07, 0.98), 8, Color(0.95, 0.77, 0.36, 0.4), 1))
	tema.set_color("font_color", "PopupMenu", KRAM)
	tema.set_color("font_hover_color", "PopupMenu", GULD)
	tema.set_stylebox("hover", "PopupMenu", _sb(Color(0.16, 0.26, 0.19), 6, Color(0, 0, 0, 0), 0))
	var falt := _sb(Color(0.02, 0.03, 0.025, 0.95), 8, Color(0.95, 0.77, 0.36, 0.3), 1)
	falt.content_margin_left = 10
	falt.content_margin_right = 10
	falt.content_margin_top = 6
	falt.content_margin_bottom = 6
	tema.set_stylebox("normal", "LineEdit", falt)
	tema.set_stylebox("focus", "LineEdit", _sb(Color(0.02, 0.03, 0.025, 0.95), 8, GULD, 1))
	tema.set_color("font_color", "LineEdit", KRAM)
	tema.set_color("font_color", "CheckBox", KRAM)
	tema.set_color("font_hover_color", "CheckBox", Color.WHITE)
	tema.set_color("font_pressed_color", "CheckBox", KRAM)
	tema.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		tema.set_stylebox(s, "CheckBox", StyleBoxEmpty.new())
	tema.set_icon("unchecked", "CheckBox", _kryssikon(false))
	tema.set_icon("checked", "CheckBox", _kryssikon(true))
	tema.set_constant("h_separation", "CheckBox", 10)
	tema.set_stylebox("background", "ProgressBar", _sb(Color(1, 1, 1, 0.08), 3, Color(0, 0, 0, 0), 0))
	tema.set_stylebox("fill", "ProgressBar", _sb(GULD, 3, Color(0, 0, 0, 0), 0))
	tema.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	tema.set_font_size("font_size", "RichTextLabel", 22)
	tema.set_font("normal_font", "RichTextLabel", font_r)
	tema.set_font("bold_font", "RichTextLabel", font_b)
	tema.set_color("default_color", "RichTextLabel", KRAM)


## Kryssruta ritad pixel för pixel: guldram, ifylld med bock när den är vald.
func _kryssikon(vald: bool) -> ImageTexture:
	var st := 26
	var img := Image.create(st, st, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in st:
		for x in st:
			var kant := x < 2 or y < 2 or x >= st - 2 or y >= st - 2
			var horn := (x < 2 or x >= st - 2) and (y < 2 or y >= st - 2)
			if horn:
				continue
			if vald:
				img.set_pixel(x, y, GULD)
			elif kant:
				img.set_pixel(x, y, Color(GULD, 0.8))
			else:
				img.set_pixel(x, y, Color(0.02, 0.03, 0.025, 0.9))
	if vald:
		var punkter := [Vector2(6, 13), Vector2(11, 18), Vector2(20, 7)]
		for i in 2:
			var a: Vector2 = punkter[i]
			var b: Vector2 = punkter[i + 1]
			for k in 40:
				var p := a.lerp(b, k / 39.0)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						img.set_pixel(clampi(int(p.x) + dx, 0, st - 1), clampi(int(p.y) + dy, 0, st - 1), Color(0.08, 0.06, 0.03))
	return ImageTexture.create_from_image(img)


func _sb(bg: Color, radie: int, kant: Color, kb: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radie)
	s.border_color = kant
	s.set_border_width_all(kb)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


func _lbl(text: String, storlek := 22, fet := false, farg := KRAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", storlek)
	if fet:
		l.add_theme_font_override("font", font_b)
	l.add_theme_color_override("font_color", farg)
	return l


func _knapp(text: String, f: Callable, storlek := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", storlek)
	b.pressed.connect(func() -> void:
		get_parent().get_node("Ljud").spela("klick")
		f.call())
	return b


func _helskarm(farg := Color(0, 0, 0, 0)) -> Control:
	var c := Control.new()
	c.theme = tema
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if farg.a > 0.0:
		var r := ColorRect.new()
		r.color = farg
		c.add_child(r)
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _centrerad_panel(foralder: Control, bredd: float, hojd: float) -> PanelContainer:
	var cc := CenterContainer.new()
	foralder.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(bredd, hojd)
	cc.add_child(p)
	return p


func _gomt_allt() -> void:
	for c in [huvudmeny, installningar, regelvy, hud, overlamning, paus, slut, ga_med_vy, lobby_vy]:
		if c:
			c.visible = false


# ================================================================== huvudmeny
func _bygg_huvudmeny() -> void:
	huvudmeny = _helskarm()
	var grad := TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.0)])
	g.gradient = gr
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0.75, 0)
	grad.texture = g
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	huvudmeny.add_child(grad)
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	huvudmeny.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = 110
	v.offset_right = 700
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	var titel := _lbl("Chicago", 150, true, GULD)
	titel.add_theme_constant_override("shadow_offset_x", 0)
	titel.add_theme_constant_override("shadow_offset_y", 6)
	titel.add_theme_constant_override("shadow_outline_size", 18)
	titel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	v.add_child(titel)
	var under := _lbl("Svensk poker med stick · bara poäng, inga insatser", 26, false, Color(0.9, 0.86, 0.76))
	v.add_child(under)
	var mell := Control.new()
	mell.custom_minimum_size = Vector2(0, 30)
	v.add_child(mell)
	var knappar := [["Snabbstart – du mot tre robotar", func() -> void: snabbstart.emit()], ["Nytt parti …", func() -> void: visa_installningar()], ["Skapa bord online …", func() -> void: visa_installningar_online()], ["Gå med i bord …", func() -> void: visa_ga_med("", get_parent().sparat_namn())], ["Regler", func() -> void: visa_regler(null)]]
	# på webben går det inte att avsluta programmet
	if not OS.has_feature("web"):
		knappar.append(["Avsluta", func() -> void: avsluta.emit()])
	for k in knappar:
		var b := _knapp(k[0], k[1], 28)
		b.custom_minimum_size = Vector2(460, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	var fot := _lbl("Kortleken, bordet och ljuden är gjorda i kod · Typsnitt Fredoka (SIL OFL)", 16, false, Color(0.7, 0.68, 0.62, 0.7))
	huvudmeny.add_child(fot)
	fot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fot.offset_left = 110
	fot.offset_top = -50
	fot.offset_bottom = -24


func visa_huvudmeny() -> void:
	_gomt_allt()
	huvudmeny.visible = true


# ================================================================== inställningar
func _bygg_installningar() -> void:
	installningar = _helskarm(Color(0, 0, 0, 0.55))
	arb_regler = Regler.new()
	var p := _centrerad_panel(installningar, 1440, 800)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	inst_titel = _lbl("Nytt parti", 44, true, GULD)
	v.add_child(inst_titel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	# vänster: spelare och visning
	var vv := VBoxContainer.new()
	vv.custom_minimum_size = Vector2(560, 0)
	vv.add_theme_constant_override("separation", 10)
	h.add_child(vv)
	vv.add_child(_rubrik("Spelare"))
	var ah := HBoxContainer.new()
	antal_text = _lbl("Antal spelare")
	ah.add_child(antal_text)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ah.add_child(sp)
	antal_spin = SpinBox.new()
	antal_spin.min_value = 2
	antal_spin.max_value = 6
	antal_spin.value = 4
	antal_spin.value_changed.connect(func(_x: float) -> void: _visa_rader())
	ah.add_child(antal_spin)
	vv.add_child(ah)
	for i in 6:
		var rad := HBoxContainer.new()
		rad.add_theme_constant_override("separation", 10)
		var prick := ColorRect.new()
		prick.color = SPELARFARG[i]
		prick.custom_minimum_size = Vector2(10, 40)
		rad.add_child(prick)
		var namn := LineEdit.new()
		namn.text = STANDARDNAMN[i] if i > 0 else "Du"
		namn.custom_minimum_size = Vector2(170, 0)
		namn.max_length = 14
		rad.add_child(namn)
		var typ := OptionButton.new()
		for t in TYPER:
			typ.add_item(t)
		typ.select(0 if i == 0 else 2)
		typ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rad.add_child(typ)
		vv.add_child(rad)
		var fk := Button.new()
		fk.custom_minimum_size = Vector2(170, 0)
		fk.clip_text = true
		fk.add_theme_font_size_override("font_size", 17)
		var rad_i: int = i
		fk.pressed.connect(func() -> void:
			visa_figurvaljare(spelar_rader[rad_i].figur, true, func(f: int) -> void: _satt_radfigur(rad_i, f)))
		rad.add_child(fk)
		spelar_rader.append({"rad": rad, "namn": namn, "typ": typ, "figur": 0 if i == 0 else -1, "figurknapp": fk})
		fk.text = _figurtext(0 if i == 0 else -1)
	inst_tips = _lbl("Flera människor turas om vid samma dator. Handen döljs mellan turerna.", 17, false, GRA)
	inst_tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inst_tips.custom_minimum_size = Vector2(540, 0)
	vv.add_child(inst_tips)
	vv.add_child(_rubrik("Visning"))
	vis_fyrfarg = CheckBox.new()
	vis_fyrfarg.text = "Fyrfärgslek (ruter blå, klöver grön)"
	vv.add_child(vis_fyrfarg)
	vis_kasta = CheckBox.new()
	vis_kasta.text = "Robotar kastar tillbaka och busar (6-7)"
	vis_kasta.button_pressed = true
	vv.add_child(vis_kasta)
	vis_ljud = CheckBox.new()
	vis_ljud.text = "Ljud"
	vis_ljud.button_pressed = true
	vv.add_child(vis_ljud)
	var fh := HBoxContainer.new()
	fh.add_child(_lbl("Spelhastighet"))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(sp2)
	vis_fart = OptionButton.new()
	for t in ["Lugn", "Normal", "Snabb"]:
		vis_fart.add_item(t)
	vis_fart.select(1)
	fh.add_child(vis_fart)
	vv.add_child(fh)
	# höger: regler
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(hv)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hv.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	scroll.add_child(lista)
	for d in Regler.LISTA:
		if d.has("grupp"):
			lista.add_child(_rubrik(d.grupp))
			continue
		var rad := HBoxContainer.new()
		var l := _lbl(d.text)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rad.add_child(l)
		var k: Control
		match d.typ:
			"tal":
				var s := SpinBox.new()
				s.min_value = d.min
				s.max_value = d.max
				s.custom_minimum_size = Vector2(130, 0)
				s.value_changed.connect(func(x: float) -> void: arb_regler.set(d.namn, int(x)))
				k = s
			"bool":
				var c := CheckBox.new()
				c.toggled.connect(func(x: bool) -> void: arb_regler.set(d.namn, x))
				k = c
			"val":
				var o := OptionButton.new()
				for t in d.val:
					o.add_item(t)
				o.item_selected.connect(func(x: int) -> void: arb_regler.set(d.namn, x))
				k = o
		rad.add_child(k)
		regel_kontroller[d.namn] = k
		lista.add_child(rad)
		if d.has("hjalp"):
			var hj := _lbl(d.hjalp, 16, false, GRA)
			hj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hj.custom_minimum_size = Vector2(600, 0)
			lista.add_child(hj)
	# knappar
	var kh := HBoxContainer.new()
	kh.add_theme_constant_override("separation", 12)
	v.add_child(kh)
	kh.add_child(_knapp("Husregler (standard)", func() -> void:
		arb_regler.aterstall()
		_uppdatera_kontroller()))
	kh.add_child(_knapp("Klassiska regler", func() -> void:
		arb_regler.klassiska()
		_uppdatera_kontroller()))
	kh.add_child(_knapp("Läs reglerna", func() -> void: visa_regler(arb_regler)))
	var mel := Control.new()
	mel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(mel)
	kh.add_child(_knapp("Tillbaka", func() -> void:
		online_lage = false
		_satt_lage()
		visa_huvudmeny()))
	var start := _knapp("Starta partiet", func() -> void: _starta(), 26)
	inst_start = start
	start.add_theme_color_override("font_color", GULD)
	kh.add_child(start)
	_ladda_installningar()
	_uppdatera_kontroller()
	_visa_rader()


func _rubrik(t: String) -> Label:
	var l := _lbl(t, 26, true, GULD)
	l.add_theme_constant_override("line_spacing", 0)
	return l


func _visa_rader() -> void:
	for i in 6:
		spelar_rader[i].rad.visible = i < int(antal_spin.value)


func _uppdatera_kontroller() -> void:
	for k in regel_kontroller:
		var c: Control = regel_kontroller[k]
		var val = arb_regler.get(k)
		if c is SpinBox:
			c.set_value_no_signal(val)
		elif c is CheckBox:
			c.set_pressed_no_signal(val)
		elif c is OptionButton:
			c.select(val)


func visa_installningar() -> void:
	online_lage = false
	_satt_lage()
	_gomt_allt()
	installningar.visible = true


func spelarlista() -> Array:
	var ut: Array = []
	for i in int(antal_spin.value):
		var r: Dictionary = spelar_rader[i]
		var namn: String = r.namn.text.strip_edges()
		if namn == "":
			namn = "Spelare %d" % (i + 1)
		var t: int = r.typ.selected
		ut.append({"namn": namn, "robot": t > 0, "niva": maxi(t - 1, 0), "figur": r.figur})
	return ut


func visningsval() -> Dictionary:
	return {"oppna": false, "kasta_tillbaka": vis_kasta.button_pressed, "fyrfarg": vis_fyrfarg.button_pressed, "fart": vis_fart.selected, "ljud": vis_ljud.button_pressed}


func _starta() -> void:
	_spara_installningar()
	if online_lage:
		var namn: String = spelar_rader[0].namn.text.strip_edges()
		skapa_online.emit(namn if namn != "" else "Värd", int(antal_spin.value), arb_regler.kopia(), visningsval())
		return
	starta.emit(spelarlista(), arb_regler.kopia(), visningsval())


func _spara_installningar() -> void:
	var cf := ConfigFile.new()
	arb_regler.spara(cf)
	cf.set_value("spelare", "antal", int(antal_spin.value))
	for i in 6:
		cf.set_value("spelare", "namn%d" % i, spelar_rader[i].namn.text)
		cf.set_value("spelare", "typ%d" % i, spelar_rader[i].typ.selected)
		cf.set_value("spelare", "figur%d" % i, spelar_rader[i].figur)
	var vis := visningsval()
	for k in vis:
		cf.set_value("visning", k, vis[k])
	cf.save(Regler.SPARFIL)


func _ladda_installningar() -> void:
	var cf := ConfigFile.new()
	if cf.load(Regler.SPARFIL) != OK:
		return
	arb_regler.ladda(cf)
	antal_spin.set_value_no_signal(int(cf.get_value("spelare", "antal", 4)))
	for i in 6:
		spelar_rader[i].namn.text = str(cf.get_value("spelare", "namn%d" % i, spelar_rader[i].namn.text))
		spelar_rader[i].typ.select(int(cf.get_value("spelare", "typ%d" % i, spelar_rader[i].typ.selected)))
		_satt_radfigur(i, int(cf.get_value("spelare", "figur%d" % i, spelar_rader[i].figur)))
	vis_fyrfarg.button_pressed = bool(cf.get_value("visning", "fyrfarg", false))
	vis_ljud.button_pressed = bool(cf.get_value("visning", "ljud", true))
	vis_kasta.button_pressed = bool(cf.get_value("visning", "kasta_tillbaka", true))
	vis_fart.select(int(cf.get_value("visning", "fart", 1)))


# ================================================================== regelvy
func _bygg_regelvy() -> void:
	regelvy = _helskarm(Color(0, 0, 0, 0.6))
	var p := _centrerad_panel(regelvy, 1100, 760)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_lbl("Så spelar man Chicago", 40, true, GULD))
	regel_text = RichTextLabel.new()
	regel_text.bbcode_enabled = true
	regel_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	regel_text.scroll_active = true
	v.add_child(regel_text)
	var kh := HBoxContainer.new()
	kh.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(kh)
	kh.add_child(_knapp("Stäng", func() -> void: regelvy.visible = false))


func visa_regler(r) -> void:
	if r == null:
		r = arb_regler
	var t: String = r.beskrivning()
	t += "\n\n[b]Pokerhänderna, från sämst till bäst:[/b] par · två par · triss (tre lika) · stege (fem i följd) · färg (fem i samma färg) · kåk (triss + par) · fyrtal · färgstege · royal straight flush (tio till ess i samma färg). Vid samma sorts hand avgör högsta valören, sedan nästa och så vidare."
	t += "\n\n[b]Styrning:[/b] klicka på kort för att välja vilka som ska bytas och tryck Byt. I sticken klickar du på kortet du vill spela, otillåtna kort är mörkare. Tangenterna 1–5 väljer kort, Enter bekräftar och Esc pausar."
	t += "\n\n[b]Dolda kort:[/b] bara korten som läggs ut i sticken syns öppet, och din egen hand när det är din tur. Robotarnas händer, slängda kort och tagna stick ligger alltid med baksidan upp. Spelar flera människor vid samma dator visas en överlämningsskärm och handen vänds först när nästa spelare klickar."
	regel_text.text = t
	regelvy.visible = true
	regelvy.move_to_front()


# ================================================================== hud
func _bygg_hud() -> void:
	hud = _helskarm()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# poängtavla
	var tp := PanelContainer.new()
	hud.add_child(tp)
	# poängtavlan nere till vänster så att figurerna vid bordet syns
	tp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tp.offset_left = 20
	tp.offset_bottom = -20
	tp.custom_minimum_size = Vector2(330, 0)
	var tv := VBoxContainer.new()
	tv.name = "Tavla"
	tv.add_theme_constant_override("separation", 6)
	tp.add_child(tv)
	tavla_rubrik = _lbl("Poäng", 20, true, GULD)
	tv.add_child(tavla_rubrik)
	# fas
	fas_panel = PanelContainer.new()
	var fsb := _sb(Color(0.035, 0.05, 0.042, 0.85), 22, Color(0.95, 0.77, 0.36, 0.35), 1)
	fsb.content_margin_top = 8
	fsb.content_margin_bottom = 8
	fsb.content_margin_left = 26
	fsb.content_margin_right = 26
	fas_panel.add_theme_stylebox_override("panel", fsb)
	hud.add_child(fas_panel)
	fas_label = _lbl("", 24, true, KRAM)
	fas_panel.add_child(fas_label)
	fas_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fas_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fas_panel.offset_top = 18
	# banner
	var bc := VBoxContainer.new()
	hud.add_child(bc)
	bc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bc.grow_vertical = Control.GROW_DIRECTION_BOTH
	bc.offset_top = -200
	bc.offset_bottom = -40
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = _lbl("", 68, true, GULD)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 14)
	banner.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.85))
	bc.add_child(banner)
	banner_under = _lbl("", 30, true, KRAM)
	banner_under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_under.add_theme_constant_override("outline_size", 10)
	banner_under.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.85))
	bc.add_child(banner_under)
	bc.modulate.a = 0.0
	bc.name = "Banner"
	# åtgärder
	atgard_panel = PanelContainer.new()
	hud.add_child(atgard_panel)
	atgard_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	atgard_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	atgard_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	atgard_panel.offset_right = -24
	atgard_panel.offset_bottom = -24
	atgard_panel.custom_minimum_size = Vector2(420, 0)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 8)
	atgard_panel.add_child(av)
	atgard_info = _lbl("", 24, true, GULD)
	atgard_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atgard_info.custom_minimum_size = Vector2(390, 0)
	av.add_child(atgard_info)
	atgard_hand = _lbl("", 20, false, KRAM)
	atgard_hand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atgard_hand.custom_minimum_size = Vector2(390, 0)
	av.add_child(atgard_hand)
	atgard_knappar = HBoxContainer.new()
	atgard_knappar.add_theme_constant_override("separation", 10)
	av.add_child(atgard_knappar)
	atgard_panel.visible = false
	# logg
	var lp := PanelContainer.new()
	var lsb := _sb(Color(0.035, 0.05, 0.042, 0.6), 12, Color(0, 0, 0, 0), 0)
	lp.add_theme_stylebox_override("panel", lsb)
	hud.add_child(lp)
	lp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lp.offset_right = -20
	lp.offset_top = 84
	lp.custom_minimum_size = Vector2(300, 0)
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logg = VBoxContainer.new()
	logg.add_theme_constant_override("separation", 2)
	lp.add_child(logg)
	# meny- och regelknappar
	var mh := HBoxContainer.new()
	hud.add_child(mh)
	mh.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mh.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mh.offset_right = -20
	mh.offset_top = 20
	mh.add_theme_constant_override("separation", 8)
	var sj := _knapp("6-7", func() -> void: egen_sexsju.emit())
	sj.tooltip_text = "Gör 6-7 själv"
	mh.add_child(sj)
	mh.add_child(_knapp("Regler", func() -> void: visa_regler(get_parent().regler)))
	mh.add_child(_knapp("Meny", func() -> void: visa_paus(true)))


## Liten meny när man klickar på en annan spelare.
func visa_kastmeny(pos: Vector2, mal: int, namn: String) -> void:
	if kastmeny == null:
		kastmeny = PopupMenu.new()
		kastmeny.theme = tema
		kastmeny.add_theme_font_size_override("font_size", 22)
		kastmeny.id_pressed.connect(func(id: int) -> void:
			var alla: Array = KASTA + HALSA
			kasta.emit(kast_mal, alla[id][0]))
		add_child(kastmeny)
	kastmeny.clear()
	kastmeny.add_separator("Kasta på " + namn)
	for i in KASTA.size():
		kastmeny.add_item(KASTA[i][1], i)
	kastmeny.add_separator("Hälsa på " + namn)
	for i in HALSA.size():
		kastmeny.add_item(HALSA[i][1], KASTA.size() + i)
	kast_mal = mal
	kastmeny.position = Vector2i(pos)
	kastmeny.reset_size()
	kastmeny.popup()


## Stänk över hela skärmen när någon kastar på en själv.
func plask_skarm(typ: String) -> void:
	var p := Plask.new()
	p.farg = {"vattenballong": Color(0.55, 0.8, 1.0, 0.42), "tomat": Color(0.85, 0.1, 0.05, 0.75), "tarta": Color(0.99, 0.97, 0.92, 0.9), "snoboll": Color(0.95, 0.97, 1.0, 0.8), "flygplan": Color(1, 1, 1, 0.0), "ros": Color(1.0, 0.5, 0.65, 0.7), "hjarta": Color(1.0, 0.3, 0.45, 0.75), "krona": Color(1.0, 0.82, 0.3, 0.8), "konfetti": Color(1, 1, 1, 0.9)}.get(typ, Color(0.55, 0.8, 1.0, 0.55))
	p.ros = typ in ["ros", "hjarta", "krona", "konfetti"]
	p.konfetti = typ == "konfetti"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := p.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(p, "modulate:a", 0.0, 1.4)
	tw.tween_callback(p.queue_free)


## 6-7 för den egna platsen (ingen figur framför kameran): två handflator som gungar i otakt och en pratbubbla.
func sexsju_skarm() -> void:
	var s := SexSju.new()
	s.font = font_b
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := s.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.tween_callback(s.queue_free)


class SexSju extends Control:
	var t := 0.0
	var font: Font

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var mitt := Vector2(size.x * 0.5, size.y * 0.62)
		var v := sin(t * 13.0) * 60.0
		for sida in [-1.0, 1.0]:
			var p := mitt + Vector2(sida * 170.0, (v if sida < 0 else -v))
			# handflata uppåt med fingrar
			draw_circle(p, 52.0, Color(0.98, 0.82, 0.66), true, -1.0, true)
			for f in 4:
				draw_circle(p + Vector2(-33.0 + f * 22.0, -55.0), 13.0, Color(0.98, 0.82, 0.66), true, -1.0, true)
			draw_circle(p + Vector2(sida * -58.0, -8.0), 14.0, Color(0.98, 0.82, 0.66), true, -1.0, true)
		var b := Rect2(mitt + Vector2(-110, -250), Vector2(220, 120))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.95)
		sb.set_corner_radius_all(40)
		sb.anti_aliasing = true
		draw_style_box(sb, b)
		draw_colored_polygon(PackedVector2Array([b.position + Vector2(90, 118), b.position + Vector2(130, 118), b.position + Vector2(100, 160)]), Color(1, 1, 1, 0.95))
		draw_string(font, b.position + Vector2(0, 88), "6-7", HORIZONTAL_ALIGNMENT_CENTER, 220, 80, Color(0.12, 0.1, 0.15))


class Plask extends Control:
	var farg := Color.WHITE
	var ros := false
	var konfetti := false
	var slump := RandomNumberGenerator.new()
	var t := 0.0

	func _ready() -> void:
		slump.randomize()

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		slump.seed = 77
		var s := size
		if ros:
			for i in 40:
				var p := Vector2(slump.randf() * s.x, fmod(slump.randf() * s.y + t * 120.0 * (0.5 + slump.randf()), s.y))
				draw_set_transform(p, slump.randf() * TAU + t, Vector2(1.0, 0.55))
				var fc := farg
				if konfetti:
					fc = [Color(1, 0.2, 0.3), Color(1, 0.8, 0.1), Color(0.2, 0.8, 0.3), Color(0.2, 0.5, 1), Color(0.8, 0.3, 1)][i % 5]
				draw_circle(Vector2.ZERO, 14.0 + slump.randf() * 10.0, fc, true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
			return
		for i in 7:
			var c := Vector2(slump.randf() * s.x, slump.randf() * s.y * 0.8)
			var r := 60.0 + slump.randf() * 110.0
			draw_circle(c, r, farg, true, -1.0, true)
			for k in 9:
				var a := slump.randf() * TAU
				var d := r * (1.0 + slump.randf() * 0.8)
				draw_circle(c + Vector2(cos(a), sin(a)) * d, r * (0.08 + slump.randf() * 0.18), farg, true, -1.0, true)
			# rinnande droppar
			for k in 3:
				var x := c.x + (slump.randf() - 0.5) * r
				var l := t * (80.0 + slump.randf() * 160.0)
				draw_line(Vector2(x, c.y), Vector2(x, c.y + r * 0.5 + l), farg, 10.0 + slump.randf() * 8.0, true)
				draw_circle(Vector2(x, c.y + r * 0.5 + l), 9.0, farg, true, -1.0, true)


func dolj_banner() -> void:
	if banner_tw and banner_tw.is_valid():
		banner_tw.kill()
	var bc: Control = hud.find_child("Banner", true, false)
	bc.modulate.a = 0.0


func visa_hud(spelare: Array, malpoang: int) -> void:
	_gomt_allt()
	dolj_banner()
	hud.visible = true
	mal = malpoang
	for r in tavla_rader:
		r.panel.queue_free()
	tavla_rader.clear()
	for c in logg.get_children():
		c.queue_free()
	var tv: VBoxContainer = hud.find_child("Tavla", true, false)
	tavla_rubrik.text = "Poäng · först till %d" % malpoang
	for i in spelare.size():
		var s: Dictionary = spelare[i]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _rad_sb(false, i))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		p.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		var namn := _lbl(s.namn, 22, true, SPELARFARG[i])
		namn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		namn.clip_text = true
		h.add_child(namn)
		var bricka := _lbl("", 15, true, Color(0.1, 0.08, 0.05))
		var bsb := _sb(GULD, 8, Color(0, 0, 0, 0), 0)
		bsb.content_margin_left = 7
		bsb.content_margin_right = 7
		bsb.content_margin_top = 1
		bsb.content_margin_bottom = 1
		bricka.add_theme_stylebox_override("normal", bsb)
		bricka.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bricka)
		var pts := _lbl("0", 30, true, KRAM)
		pts.custom_minimum_size = Vector2(54, 0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pts)
		var under := _lbl(("Robot · " + ["lätt", "medel", "svår"][s.niva]) if s.robot else "Människa", 16, false, GRA)
		v.add_child(under)
		var bar := ProgressBar.new()
		bar.max_value = malpoang
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		var fill := _sb(SPELARFARG[i], 3, Color(0, 0, 0, 0), 0)
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0
		bar.add_theme_stylebox_override("fill", fill)
		var bg := _sb(Color(1, 1, 1, 0.08), 3, Color(0, 0, 0, 0), 0)
		bg.content_margin_top = 0
		bg.content_margin_bottom = 0
		bar.add_theme_stylebox_override("background", bg)
		v.add_child(bar)
		tv.add_child(p)
		tavla_rader.append({"panel": p, "pts": pts, "under": under, "bricka": bricka, "bar": bar, "typ": under.text})


func _rad_sb(aktiv: bool, i: int) -> StyleBoxFlat:
	var s := _sb(Color(1, 1, 1, 0.07) if aktiv else Color(0, 0, 0, 0), 10, SPELARFARG[i] if aktiv else Color(0, 0, 0, 0), 2 if aktiv else 0)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


func uppdatera_tavla(poang: Array, tur: int, givare: int, info: Array, brickor: Array) -> void:
	for i in tavla_rader.size():
		var r: Dictionary = tavla_rader[i]
		r.pts.text = str(poang[i])
		r.bar.value = clampi(poang[i], 0, mal)
		r.panel.add_theme_stylebox_override("panel", _rad_sb(i == tur, i))
		var txt: String = r.typ
		if i < info.size() and info[i] != "":
			txt += " · " + info[i]
		r.under.text = txt
		var b: String = brickor[i] if i < brickor.size() else ""
		if i == givare:
			b = ("Giv  " + b).strip_edges() if b == "" else "Giv · " + b
		r.bricka.text = b
		r.bricka.visible = b != ""


func satt_fas(t: String) -> void:
	fas_label.text = t
	fas_panel.visible = t != ""
	fas_panel.reset_size()
	fas_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	fas_panel.offset_top = 18
	fas_panel.offset_bottom = 18 + fas_panel.size.y


func visa_banner(t: String, under := "", farg := GULD, tid := 1.8) -> void:
	var bc: Control = hud.find_child("Banner", true, false)
	banner.text = t
	banner.add_theme_color_override("font_color", farg)
	banner_under.text = under
	banner_under.visible = under != ""
	if banner_tw and banner_tw.is_valid():
		banner_tw.kill()
	bc.pivot_offset = bc.size * 0.5
	bc.modulate.a = 0.0
	bc.scale = Vector2(0.85, 0.85)
	banner_tw = create_tween()
	banner_tw.set_parallel(true)
	banner_tw.tween_property(bc, "modulate:a", 1.0, 0.18)
	banner_tw.tween_property(bc, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tw.chain().tween_interval(tid)
	banner_tw.chain().tween_property(bc, "modulate:a", 0.0, 0.35)


func logga(t: String, farg := KRAM) -> void:
	var l := _lbl(t, 16, false, farg)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	logg.add_child(l)
	while logg.get_child_count() > 5:
		var c := logg.get_child(0)
		logg.remove_child(c)
		c.queue_free()
	for i in logg.get_child_count():
		logg.get_child(i).modulate.a = 0.45 + 0.55 * float(i + 1) / logg.get_child_count()


## Visar åtgärdspanelen. knappar = [[text, data, primär?], ...] där data skickas med signalen atgard.
func visa_atgard(info: String, hand: String, knappar: Array) -> void:
	atgard_info.text = info
	atgard_hand.text = hand
	atgard_hand.visible = hand != ""
	for c in atgard_knappar.get_children():
		c.queue_free()
	for k in knappar:
		var data = k[1]
		var b := _knapp(k[0], func() -> void: atgard.emit(data), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k.size() > 2 and k[2]:
			b.add_theme_color_override("font_color", GULD)
		atgard_knappar.add_child(b)
	atgard_panel.visible = true


func atgard_knapptext(i: int, t: String) -> void:
	if i < atgard_knappar.get_child_count():
		(atgard_knappar.get_child(i) as Button).text = t


func dolj_atgard() -> void:
	atgard_panel.visible = false


# ================================================================== överlämning, paus, slut
func _bygg_overlamning() -> void:
	overlamning = _helskarm(Color(0.01, 0.015, 0.012, 0.97))
	var p := _centrerad_panel(overlamning, 700, 320)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	overlamning_namn = _lbl("", 44, true, GULD)
	overlamning_namn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(overlamning_namn)
	overlamning_text = _lbl("", 22, false, KRAM)
	overlamning_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlamning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(overlamning_text)
	var b := _knapp("Visa mina kort", func() -> void:
		overlamning.visible = false
		overlamning_klar.emit(), 28)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)


func visa_overlamning(namn: String) -> void:
	overlamning_namn.text = "Lämna över till %s" % namn
	overlamning_text.text = "Alla kort är vända. Bara %s ska titta på skärmen när korten vänds upp." % namn
	overlamning.visible = true
	overlamning.move_to_front()


func _bygg_paus() -> void:
	paus = _helskarm(Color(0, 0, 0, 0.6))
	var p := _centrerad_panel(paus, 460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := _lbl("Paus", 40, true, GULD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_knapp("Fortsätt", func() -> void: visa_paus(false), 26))
	v.add_child(_knapp("Regler", func() -> void: visa_regler(get_parent().regler), 26))
	v.add_child(_knapp("Avbryt partiet", func() -> void:
		visa_paus(false)
		till_meny.emit(), 26))


func visa_paus(pa: bool) -> void:
	if not hud.visible and pa:
		return
	paus.visible = pa
	ar_pausad = pa
	if pa:
		paus.move_to_front()
	paus_andrad.emit(pa)


func _bygg_slut() -> void:
	slut = _helskarm(Color(0, 0, 0, 0.5))
	var p := _centrerad_panel(slut, 620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	slut_titel = _lbl("", 52, true, GULD)
	slut_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(slut_titel)
	slut_lista = VBoxContainer.new()
	v.add_child(slut_lista)
	var kh := HBoxContainer.new()
	kh.add_theme_constant_override("separation", 12)
	v.add_child(kh)
	var b1 := _knapp("Spela igen", func() -> void: spela_igen.emit(), 24)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(b1)
	var b2 := _knapp("Huvudmeny", func() -> void: till_meny.emit(), 24)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(b2)


func visa_slut(vinnare: String, rader: Array) -> void:
	dolj_banner()
	slut_titel.text = "%s vinner!" % vinnare
	for c in slut_lista.get_children():
		c.queue_free()
	var plats := 1
	for r in rader:
		var h := HBoxContainer.new()
		var a := _lbl("%d." % plats, 26, true, GULD if plats == 1 else GRA)
		a.custom_minimum_size = Vector2(44, 0)
		h.add_child(a)
		var n := _lbl(r[0], 26, plats == 1, r[2])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(_lbl("%d p" % r[1], 26, true, KRAM))
		slut_lista.add_child(h)
		plats += 1
	slut.visible = true
	slut.move_to_front()


# ================================================================== onlinespel: gå med, lobby, klicka för att börja
var ga_med_vy: Control
var ga_kod: LineEdit
var ga_namn: LineEdit
var ga_status: Label
var lobby_vy: Control
var lobby_titel: Label
var lobby_status: Label
var lobby_lista: VBoxContainer
var lobby_regler: RichTextLabel
var lobby_lank := ""
var lobby_knapp_starta: Button
var lobby_knapp_fyll: Button
var klick_vy: Control
var online_lage := false


func _bygg_online() -> void:
	# gå med i bord
	ga_med_vy = _helskarm(Color(0, 0, 0, 0.6))
	var p := _centrerad_panel(ga_med_vy, 560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_lbl("Gå med i bord", 40, true, GULD))
	v.add_child(_lbl("Bordskod"))
	ga_kod = LineEdit.new()
	ga_kod.placeholder_text = "t.ex. K7Q2"
	ga_kod.max_length = 6
	ga_kod.add_theme_font_size_override("font_size", 30)
	v.add_child(ga_kod)
	v.add_child(_lbl("Ditt namn"))
	ga_namn = LineEdit.new()
	ga_namn.max_length = 14
	v.add_child(ga_namn)
	ga_status = _lbl("", 18, false, Color(1.0, 0.6, 0.55))
	ga_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ga_status)
	var kh := HBoxContainer.new()
	kh.add_theme_constant_override("separation", 10)
	kh.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(kh)
	kh.add_child(_knapp("Tillbaka", func() -> void: visa_huvudmeny()))
	var gb := _knapp("Gå med", func() -> void:
		if ga_kod.text.strip_edges() == "":
			ga_status.text = "Skriv bordskoden."
			return
		ga_med_online.emit(ga_kod.text.strip_edges().to_upper(), ga_namn.text.strip_edges() if ga_namn.text.strip_edges() != "" else "Spelare"), 24)
	gb.add_theme_color_override("font_color", GULD)
	kh.add_child(gb)
	# lobby
	lobby_vy = _helskarm(Color(0, 0, 0, 0.55))
	var lp := _centrerad_panel(lobby_vy, 1200, 720)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	lp.add_child(lv)
	lobby_titel = _lbl("Bord", 44, true, GULD)
	lv.add_child(lobby_titel)
	lobby_status = _lbl("", 20, false, KRAM)
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(lobby_status)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 24)
	lh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(lh)
	var vans := VBoxContainer.new()
	vans.custom_minimum_size = Vector2(460, 0)
	vans.add_theme_constant_override("separation", 8)
	lh.add_child(vans)
	vans.add_child(_rubrik("Platser"))
	lobby_lista = VBoxContainer.new()
	lobby_lista.add_theme_constant_override("separation", 8)
	vans.add_child(lobby_lista)
	var hog := VBoxContainer.new()
	hog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(hog)
	hog.add_child(_rubrik("Regler för partiet"))
	lobby_regler = RichTextLabel.new()
	lobby_regler.bbcode_enabled = true
	lobby_regler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_regler.add_theme_font_size_override("normal_font_size", 17)
	lobby_regler.add_theme_font_size_override("bold_font_size", 17)
	hog.add_child(lobby_regler)
	var kb := HBoxContainer.new()
	kb.add_theme_constant_override("separation", 10)
	lv.add_child(kb)
	kb.add_child(_knapp("Kopiera länk", func() -> void:
		DisplayServer.clipboard_set(lobby_lank)
		lobby_status.text = "Länken är kopierad: " + lobby_lank))
	lobby_knapp_fyll = _knapp("Fyll tomma platser med robotar", func() -> void: lobby_fyll.emit())
	kb.add_child(lobby_knapp_fyll)
	var mel := Control.new()
	mel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kb.add_child(mel)
	kb.add_child(_knapp("Lämna bordet", func() -> void: lobby_lamna.emit()))
	lobby_knapp_starta = _knapp("Starta", func() -> void: lobby_starta.emit(), 26)
	lobby_knapp_starta.add_theme_color_override("font_color", GULD)
	kb.add_child(lobby_knapp_starta)
	# klicka för att börja (webb: ljudet får starta först efter ett klick)
	klick_vy = _helskarm(Color(0.02, 0.03, 0.025, 0.92))
	var kc := CenterContainer.new()
	klick_vy.add_child(kc)
	kc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var kv := VBoxContainer.new()
	kv.alignment = BoxContainer.ALIGNMENT_CENTER
	kv.add_theme_constant_override("separation", 20)
	kc.add_child(kv)
	var kt := _lbl("Chicago", 120, true, GULD)
	kt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kv.add_child(kt)
	var kk := _knapp("Klicka för att börja", func() -> void: _klick_start(), 32)
	kk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kv.add_child(kk)
	klick_vy.visible = false
	klick_vy.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_klick_start())


var _efter_klick: Callable


func visa_klick_start(efter: Callable) -> void:
	_efter_klick = efter
	klick_vy.visible = true
	klick_vy.move_to_front()


func _klick_start() -> void:
	if not klick_vy.visible:
		return
	klick_vy.visible = false
	get_parent().get_node("Ljud").spela("klick")
	if _efter_klick.is_valid():
		_efter_klick.call()


func visa_ga_med(kod := "", namn := "") -> void:
	_gomt_allt()
	ga_med_vy.visible = true
	ga_status.text = ""
	if kod != "":
		ga_kod.text = kod
	if namn != "" and ga_namn.text == "":
		ga_namn.text = namn


func visa_lobby_vantar(text: String) -> void:
	_gomt_allt()
	lobby_vy.visible = true
	lobby_titel.text = "Ansluter …"
	lobby_status.text = text
	for c in lobby_lista.get_children():
		c.queue_free()
	lobby_regler.text = ""
	lobby_knapp_starta.visible = false
	lobby_knapp_fyll.visible = false


func visa_lobby_fel(text: String) -> void:
	if ga_med_vy.visible:
		ga_status.text = text
	elif lobby_vy.visible:
		lobby_status.text = text
	else:
		visa_ga_med()
		ga_status.text = text


func visa_lobby(d: Dictionary, min_plats: int, lank: String) -> void:
	_gomt_allt()
	lobby_vy.visible = true
	lobby_lank = lank
	var varde: bool = int(d.varde) == min_plats
	lobby_titel.text = "Bord %s" % d.kod
	var tomma := 0
	for x in d.platser:
		if x.typ == "tom":
			tomma += 1
	var t := "Dela länken eller koden %s med dina vänner. " % d.kod
	if varde:
		t += "Du är värd: fyll tomma platser med robotar och starta när alla sitter." if tomma > 0 else "Alla platser är fyllda – starta när ni är redo."
	else:
		t += "Väntar på att värden startar partiet."
	lobby_status.text = t
	for c in lobby_lista.get_children():
		c.queue_free()
	for q in d.platser.size():
		var x: Dictionary = d.platser[q]
		var rad := HBoxContainer.new()
		rad.add_theme_constant_override("separation", 10)
		var prick := ColorRect.new()
		prick.color = SPELARFARG[q]
		prick.custom_minimum_size = Vector2(10, 36)
		rad.add_child(prick)
		var namn := "Ledig plats" if x.typ == "tom" else str(x.namn)
		if q == min_plats:
			namn += " (du)"
		if q == int(d.varde):
			namn += " · värd"
		var l := _lbl(namn, 22, x.typ != "tom", KRAM if x.typ != "tom" else GRA)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rad.add_child(l)
		var fig: int = int(x.get("figur", -1))
		if q == min_plats:
			var fk := _knapp(_figurtext(fig), func() -> void:
				visa_figurvaljare(fig, false, func(f: int) -> void: lobby_figur.emit(f)), 17)
			rad.add_child(fk)
		elif x.typ != "tom":
			rad.add_child(_lbl(_figurtext(fig).replace("Figur: ", ""), 16, false, GRA))
		if x.typ == "manniska":
			rad.add_child(_lbl("Människa" if x.ansluten else "Frånkopplad", 17, false, GRA if x.ansluten else Color(1.0, 0.6, 0.5)))
		elif varde and not d.startad:
			var o := OptionButton.new()
			for tt in ["Ledig", "Robot – lätt", "Robot – medel", "Robot – svår"]:
				o.add_item(tt)
			o.select(0 if x.typ == "tom" else 1 + int(x.niva))
			var plats: int = q
			o.item_selected.connect(func(i: int) -> void:
				lobby_plats.emit(plats, "tom" if i == 0 else "robot", maxi(i - 1, 0)))
			rad.add_child(o)
		else:
			rad.add_child(_lbl("Robot – " + ["lätt", "medel", "svår"][int(x.niva)] if x.typ == "robot" else "", 17, false, GRA))
		lobby_lista.add_child(rad)
	var r := Regler.new()
	r.fran_dict(d.regler)
	lobby_regler.text = r.beskrivning()
	lobby_knapp_starta.visible = varde
	lobby_knapp_starta.disabled = tomma > 0
	lobby_knapp_fyll.visible = varde and tomma > 0


func visa_installningar_online() -> void:
	online_lage = true
	_satt_lage()
	_gomt_allt()
	installningar.visible = true


func _satt_lage() -> void:
	inst_titel.text = "Skapa bord online" if online_lage else "Nytt parti"
	inst_start.text = "Skapa bord" if online_lage else "Starta partiet"
	antal_text.text = "Antal platser" if online_lage else "Antal spelare"
	for i in 6:
		spelar_rader[i].typ.visible = not online_lage
		spelar_rader[i].figurknapp.visible = not online_lage or i == 0
	inst_tips.text = "Du får en kod och en länk som dina vänner öppnar. Tomma platser kan fyllas med robotar." if online_lage else "Flera människor turas om vid samma dator. Handen döljs mellan turerna."
	_visa_rader()


# ================================================================== figurväljare
var figur_vy: Control
var figur_vp: SubViewport
var figur_gubbe: Node3D
var figur_namn: Label
var figur_index := 0
var figur_slump := false
var figur_klar: Callable
var figur_slumpknapp: Button


func _bygg_figurvaljare() -> void:
	figur_vy = _helskarm(Color(0, 0, 0, 0.65))
	var p := _centrerad_panel(figur_vy, 520, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_lbl("Välj figur", 36, true, GULD))
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(480, 420)
	v.add_child(cont)
	figur_vp = SubViewport.new()
	figur_vp.own_world_3d = true
	figur_vp.transparent_bg = false
	figur_vp.msaa_3d = Viewport.MSAA_4X
	cont.add_child(figur_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.16, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.82, 0.78)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	figur_vp.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.6, 0.5, 0)
	sol.light_energy = 1.3
	figur_vp.add_child(sol)
	var kam := Camera3D.new()
	kam.position = Vector3(0, 2.4, 8.0)
	kam.fov = 38
	figur_vp.add_child(kam)
	kam.look_at(Vector3(0, 1.7, 0), Vector3.UP)
	figur_namn = _lbl("", 28, true, KRAM)
	figur_namn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(figur_namn)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	v.add_child(nh)
	var fore := _knapp("< Föregående", func() -> void: _visa_figur(figur_index - 1))
	fore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(fore)
	var nasta := _knapp("Nästa >", func() -> void: _visa_figur(figur_index + 1))
	nasta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(nasta)
	var kh := HBoxContainer.new()
	kh.add_theme_constant_override("separation", 10)
	v.add_child(kh)
	figur_slumpknapp = _knapp("Slumpad", func() -> void: _valj_figur(-1))
	kh.add_child(figur_slumpknapp)
	var mel := Control.new()
	mel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(mel)
	kh.add_child(_knapp("Avbryt", func() -> void: figur_vy.visible = false))
	var valj := _knapp("Välj", func() -> void: _valj_figur(figur_index), 24)
	valj.add_theme_color_override("font_color", GULD)
	kh.add_child(valj)
	figur_vy.visible = false


## Öppnar väljaren. klar anropas med figurens nummer (eller -1 för slumpad om det är tillåtet).
func visa_figurvaljare(start: int, tillat_slump: bool, klar: Callable) -> void:
	figur_klar = klar
	figur_slump = tillat_slump
	figur_slumpknapp.visible = tillat_slump
	figur_vy.visible = true
	figur_vy.move_to_front()
	_visa_figur(maxi(start, 0))


func _visa_figur(i: int) -> void:
	figur_index = posmod(i, Figurer.antal())
	if figur_gubbe:
		figur_gubbe.queue_free()
	figur_gubbe = Gubbe.new()
	figur_vp.add_child(figur_gubbe)
	figur_gubbe.bygg_figur(figur_index)
	figur_gubbe.rotation.y = PI
	figur_gubbe.titta_pa(Vector3(0, 2.3, 6.2))
	figur_namn.text = "%s  (%d av %d)" % [Figurer.namn(figur_index), figur_index + 1, Figurer.antal()]


func _valj_figur(i: int) -> void:
	figur_vy.visible = false
	if figur_klar.is_valid():
		figur_klar.call(i)


func _process(dt: float) -> void:
	if figur_vy and figur_vy.visible and figur_gubbe:
		figur_gubbe.rotation.y += dt * 0.8
		if fmod(figur_gubbe.tid, 4.0) < dt:
			figur_gubbe.jubel(false)


func _figurtext(f: int) -> String:
	return "Figur: slumpad" if f < 0 else "Figur: " + Figurer.namn(f)


func _satt_radfigur(i: int, f: int) -> void:
	spelar_rader[i].figur = f
	spelar_rader[i].figurknapp.text = _figurtext(f)
