extends Node3D
## Chicago i 3D, bara online: värden skapar ett bord och delar länken, servern (server.gd) styr partiet
## och spelar upp motorns händelser som animeringar (blandning, giv, byten, visning, stick, poäng).
## Regler: motor.gd · Bord: bord.gd · Kort: kort3d.gd + kortbild.gd · Gränssnitt: ui.gd

const K := preload("res://scripts/kort.gd")
const H := preload("res://scripts/handvarde.gd")
const Motor := preload("res://scripts/motor.gd")
const Regler := preload("res://scripts/regler.gd")
const Kort3D := preload("res://scripts/kort3d.gd")
const Kortbild := preload("res://scripts/kortbild.gd")
const Bord := preload("res://scripts/bord.gd")
const Ljud := preload("res://scripts/ljud.gd")
const UI := preload("res://scripts/ui.gd")
const Gubbe := preload("res://scripts/gubbe.gd")
const Server := preload("res://scripts/server.gd")
const Klient := preload("res://scripts/klient.gd")
const Fjarrmotor := preload("res://scripts/fjarrmotor.gd")
const Natverk := preload("res://scripts/natverk.gd")
const Figurer := preload("res://scripts/figurer.gd")
const R_GUBBE := 7.4
const GUBBSKALA := 0.74
const KASTSPARR := 3.0

const R_HAND := 4.45
const R_STICK := 1.75
const LYFT := 0.0035

signal beslut(data)

var regler = Regler.new()
var motor
var spelare: Array = []
var visning := {"oppna": false, "fyrfarg": false, "fart": 1, "ljud": true}
var n := 4
var kort: Array = []
var kortbild
var ljud
var ui
var kam: Camera3D
var kam_vinkel := 0.0
var kam_tw: Tween
var meny_lage := true
var betraktare := 0
var visad := true
var vhand: Array = []
var lek_vis: Array = []
var slang_vis: Array = []
var stick_vis: Array = []
var hogar: Array = []
var vis_poang: Array = []
var vis_givare := 0
var gubbar: Array = []  # figur per plats (ingen framför kameran)
var kastsparr := 0.0
var hover_gubbe := -1
var bytes_info: Array = []
var brickor: Array = []
var visar := -1
var korning := 0
var rng := RandomNumberGenerator.new()
var tf := 1.0
var fart_tvingad := -1.0
var fro := -1
var stick_par: Array = []  # [spelare, kort] för korten som ligger i sticket
var stick_etiketter: Array = []
var online := false
var klient
var fjarr
var min_plats := 0
var vantar_pa_drag := false  # sant när alla händelser är uppspelade och ett drag väntar
var inmatning := ""
var valda: Array = []
var hover_id := -1
var tillatna: Array = []
var max_val := 5
var stol_etiketter: Array = []
var chicago_etikett: Label3D
var tur_ring: MeshInstance3D
var givarknapp: Node3D
var glod_mat: ShaderMaterial
var font_b: FontVariation
var kortlager: Node3D


func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_kor_server(args)
		return
	if Natverk.ar_mobil():
		# telefon: större gränssnitt (knappar och text) och lägre 3D-upplösning för äldre telefoner
		get_window().content_scale_factor = 1.5
		get_viewport().scaling_3d_scale = 0.75
	for a in args:
		if a.begins_with("--seed="):
			fro = int(a.substr(7))
			rng.seed = fro
		elif a.begins_with("--fart="):
			fart_tvingad = float(a.substr(7))
	var bord := Bord.new()
	add_child(bord)
	kam = Camera3D.new()
	kam.fov = 40.0
	kam.near = 0.1
	kam.far = 120.0
	add_child(kam)
	# mjukt ljus för handen man håller (den ligger utanför lampans kägla)
	var handljus := OmniLight3D.new()
	handljus.position = Vector3(0.0, 0.4, -3.4)
	handljus.omni_range = 6.0
	handljus.omni_attenuation = 0.5
	handljus.light_energy = 2.1
	handljus.light_color = Color(1.0, 0.9, 0.78)
	kam.add_child(handljus)
	ljud = Ljud.new()
	ljud.name = "Ljud"
	ljud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ljud)
	font_b = FontVariation.new()
	font_b.base_font = load("res://assets/Fredoka.ttf")
	font_b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	kortbild = Kortbild.new()
	add_child(kortbild)
	ui = UI.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.atgard.connect(func(d) -> void: beslut.emit(d))
	ui.till_meny.connect(_till_meny)
	ui.spela_igen.connect(_spela_igen)
	ui.skapa_online.connect(skapa_online)
	ui.ga_med_online.connect(ga_med_online)
	ui.fraga_bordinfo.connect(fraga_bordinfo)
	ui.lobby_starta.connect(lobby_starta)
	ui.lobby_figur.connect(func(f: int) -> void: klient.skicka({"t": "figur", "figur": f}))
	ui.lobby_lamna.connect(func() -> void:
		lamna_online()
		ui.visa_huvudmeny())
	ui.avsluta.connect(func() -> void: get_tree().quit())
	ui.paus_andrad.connect(func(p: bool) -> void: get_tree().paused = p)
	ui.kasta.connect(func(mal: int, typ: String) -> void: _kasta_fran_mig(mal, typ))
	ui.egen_sexsju.connect(_egen_sexsju)
	_glod_material()
	_markorer()
	kam.transform = _kam_tf(0.0)
	await kortbild.bygg(font_b)
	kortlager = Node3D.new()
	add_child(kortlager)
	for c in 52:
		var k := Kort3D.new()
		k.skapa(c, kortbild.framsidor[c], kortbild.baksidor[0], glod_mat)
		kortlager.add_child(k)
		kort.append(k)
	_meny_dekor(true)
	# handen anpassas efter fönstret (t.ex. när telefonen vrids)
	get_viewport().size_changed.connect(func() -> void:
		if not meny_lage and betraktare < vhand.size():
			_layout_sats(betraktare, 0.15, 0.0))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.chicagoStartad = true;", true)
	var kod := Natverk.bord_fran_adress()
	if kod != "":
		# delad länk: välj figur och gå med, sedan lobbyn (klicket på Gå med låter också ljudet starta)
		ui.visa_ga_med(kod, sparat_namn(), ui.spelar_rader[0].figur)
	elif OS.has_feature("web"):
		ui.visa_klick_start(func() -> void: pass)


## Serverläge (headless): ingen grafik, bara den auktoritativa servern. Porten tas från --port=N eller miljövariabeln PORT.
func _kor_server(args: Array) -> void:
	var port := 9080
	if OS.get_environment("PORT") != "":
		port = int(OS.get_environment("PORT"))
	for a in args:
		if a.begins_with("--port="):
			port = int(a.substr(7))
	var s := Server.new()
	add_child(s)
	if s.starta(port) != OK:
		get_tree().quit(1)


func _glod_material() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform vec4 farg : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform float styrka = 1.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	vec2 q = max(d - vec2(0.62, 0.68), 0.0) / vec2(0.38, 0.32);
	float e = length(q);
	float puls = mix(1.0, 0.75 + 0.25 * sin(TIME * 4.0), clamp(styrka - 0.5, 0.0, 1.0));
	float a = (1.0 - smoothstep(0.0, 1.0, e)) * puls;
	ALBEDO = farg.rgb * a * 0.9 * styrka;
}
"""
	glod_mat = ShaderMaterial.new()
	glod_mat.shader = sh


func _markorer() -> void:
	# ring under den som har tur
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 farg : source_color = vec4(1.0, 0.8, 0.3, 1.0);
void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d);
	float a = smoothstep(1.0, 0.35, r) * 0.22 * (0.8 + 0.2 * sin(TIME * 3.0));
	ALBEDO = farg.rgb * a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	tur_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.8, 2.4)
	tur_ring.mesh = pm
	tur_ring.material_override = m
	tur_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tur_ring.visible = false
	add_child(tur_ring)
	# givarknapp: vit bricka med text
	givarknapp = Node3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.3
	cy.bottom_radius = 0.3
	cy.height = 0.07
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.95, 0.93, 0.88)
	cm.roughness = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = cy
	mi.material_override = cm
	mi.position.y = 0.035
	givarknapp.add_child(mi)
	var gl := Label3D.new()
	gl.text = "GIV"
	gl.font = font_b
	gl.font_size = 64
	gl.pixel_size = 0.004
	gl.modulate = Color(0.15, 0.1, 0.05)
	gl.outline_size = 0
	gl.rotation.x = -PI / 2
	gl.position.y = 0.072
	givarknapp.add_child(gl)
	givarknapp.visible = false
	add_child(givarknapp)
	chicago_etikett = Label3D.new()
	chicago_etikett.text = "CHICAGO"
	chicago_etikett.font = font_b
	chicago_etikett.font_size = 90
	chicago_etikett.pixel_size = 0.006
	chicago_etikett.modulate = Color(1.0, 0.82, 0.35)
	chicago_etikett.outline_size = 16
	chicago_etikett.outline_modulate = Color(0.2, 0.08, 0.0, 0.8)
	chicago_etikett.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chicago_etikett.visible = false
	add_child(chicago_etikett)
	# namnlappar under korten i sticken
	for i in 6:
		var l := Label3D.new()
		l.font = font_b
		l.font_size = 40
		l.pixel_size = 0.0062
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.8)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.visible = false
		add_child(l)
		stick_etiketter.append(l)


# ================================================================== geometri
func _vinkel(s: int) -> float:
	return -float(s) * TAU / n


func _d(s: int) -> Vector3:
	var a := _vinkel(s)
	return Vector3(sin(a), 0, cos(a))


func _t(s: int) -> Vector3:
	var a := _vinkel(s)
	return Vector3(cos(a), 0, -sin(a))


## Bas för ett kort som ligger på bordet vänt mot spelare s (uppåtvänt eller nedåtvänt).
func _bas(s: int, upp: bool) -> Basis:
	var t := _t(s)
	var d := _d(s)
	if upp:
		return Basis(t, -d, Vector3.UP)
	return Basis(-t, -d, Vector3.DOWN)


func _kam_tf(a: float) -> Transform3D:
	var pos := Vector3(0, 10.2, 13.6)
	var mal := Vector3(0, 0.4, -0.9)
	if meny_lage:
		pos = Vector3(0, 7.0, 10.8)
		mal = Vector3(0, 0, 0)
	var t := Transform3D(Basis(), pos).looking_at(mal, Vector3.UP)
	var ut := Transform3D(Basis(Vector3.UP, a), Vector3.ZERO) * t
	if meny_lage:
		ut.origin -= ut.basis.x * 3.2
	return ut


func _kamera_till(s: int, tid := 1.1) -> void:
	var mal := _vinkel(s)
	mal = kam_vinkel + wrapf(mal - kam_vinkel, -PI, PI)
	if kam_tw and kam_tw.is_valid():
		kam_tw.kill()
	kam_tw = create_tween()
	kam_tw.tween_property(self, "kam_vinkel", mal, tid).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _halls(p: int) -> bool:
	return p == betraktare and not meny_lage and visad


const HAND_DJUP := 6.5
const HAND_GLIPA := 0.07
const HAND_VANSTER := 360.0  # poängtavlan (px i gränssnittet)
const HAND_HOGER := 460.0  # rutan med "Byt", "din tur" osv.


func _hallen_tf(k: int, m: int, vald: bool, hov: bool) -> Transform3D:
	var T := _kam_tf(_vinkel(betraktare))
	# Korten ligger bredvid varandra med en liten glipa, så att hela kortet syns (inte bara hörnet).
	# Handen får plats mellan poängtavlan och åtgärdsrutan: krymps vid behov och centreras där emellan.
	var vp := get_viewport().get_visible_rect().size
	var ui_skala := get_window().content_scale_factor
	var per_px := 2.0 * HAND_DJUP * tan(deg_to_rad(kam.fov) * 0.5) / vp.y
	var fri_v := HAND_VANSTER * ui_skala
	var fri_h := HAND_HOGER * ui_skala
	var bredd_px := maxf(vp.x - fri_v - fri_h, vp.x * 0.45)
	var behov := 5 * Kort3D.BREDD + 4 * HAND_GLIPA
	var s := clampf(bredd_px * per_px / behov, 0.6, 1.0)
	var mitt := (fri_v + (vp.x - fri_v - fri_h) * 0.5 - vp.x * 0.5) * per_px if vp.x - fri_v - fri_h >= vp.x * 0.45 else 0.0
	var xc := (k - (m - 1) / 2.0) * (Kort3D.BREDD + HAND_GLIPA) * s
	var x := mitt + xc
	var y := -2.37 + Kort3D.HOJD * s * 0.5 + 0.38 - 0.02 * xc * xc
	var lyft := ((0.24 if vald else 0.0) + (0.08 if hov else 0.0)) * s
	# handen hålls lätt lutad bakåt så att lampan lyser på korten
	var lok := Basis(Vector3.RIGHT, -0.32) * Basis(Vector3.BACK, -xc * 0.03)
	var off := Vector3(x, y, -HAND_DJUP + k * 0.012) + lok * Vector3.UP * lyft
	return Transform3D((T.basis * lok).scaled(Vector3(s, s, s)), T.origin + T.basis * off)


func _liggande_tf(p: int, k: int, m: int, upp: bool) -> Transform3D:
	var off := k - (m - 1) / 2.0
	var pos := _d(p) * (R_HAND + off * off * 0.025) + _t(p) * off * 0.46 + Vector3.UP * (0.012 + k * 0.004)
	var b := Basis(Vector3.UP, -off * 0.06) * _bas(p, upp)
	return Transform3D(b, pos)


func _lekpos(g: int) -> Vector3:
	return _d(g) * 2.65 - _t(g) * 1.5


func _lek_tf(k: int, g: int) -> Transform3D:
	var b := Basis(Vector3.UP, sin(k * 7.3) * 0.015) * _bas(g, false)
	return Transform3D(b, _lekpos(g) + Vector3.UP * (0.012 + k * LYFT))


func _slang_tf(k: int) -> Transform3D:
	var g := vis_givare
	var jit := Vector3(sin(k * 3.7), 0, cos(k * 5.1)) * 0.07
	var b := Basis(Vector3.UP, sin(k * 2.3) * 0.45) * _bas(g, false)
	return Transform3D(b, _d(g) * 2.5 - _t(g) * 2.75 + jit + Vector3.UP * (0.012 + k * LYFT))


## Kort i sticken: större, nära bordets mitt, alltid rättvända för den som tittar och lätt lutade mot kameran
## så att valörerna går att läsa. Platsen (mot spelarens sida av mitten) visar vem som lade kortet.
## Kortets plats i sticket: åt det håll spelaren sitter, utlagt på en ellips (bredare i sidled sett från kameran).
func _stickpos(p: int) -> Vector3:
	var tv := _t(betraktare)
	var dv := _d(betraktare)
	var a := _d(p).dot(tv)
	var b := _d(p).dot(dv)
	var rx := 2.05 if n <= 4 else 2.3
	var rz := 1.65 if n <= 4 else 1.75
	return _stickmitt() + tv * a * rx + dv * b * rz


func _stickmitt() -> Vector3:
	return _d(betraktare) * 0.5


func _stick_radie() -> float:
	return 1.55 if n <= 4 else 2.1


func _stick_skala() -> float:
	return 1.95 if n <= 4 else 1.45


func _stick_tf(p: int, ordning: int) -> Transform3D:
	var sk := _stick_skala()
	var luta := 0.38
	var b := Basis(_t(betraktare), luta) * Basis(Vector3.UP, sin(float(p) * 2.7 + ordning) * 0.05) * _bas(betraktare, true)
	var lyft := Kort3D.HOJD * sk * 0.5 * sin(luta) + 0.03 + ordning * 0.01
	return Transform3D(b.scaled(Vector3(sk, sk, sk)), _stickpos(p) + Vector3.UP * lyft)


## Namnlapp under varje stickkort och markering av kortet som just nu vinner sticket.
func _markera_stick() -> void:
	var vinn: Array = Motor.stickvinnare(stick_par) if not stick_par.is_empty() else []
	for i in stick_par.size():
		var p: int = stick_par[i][0]
		var c: int = stick_par[i][1]
		var leder: bool = not vinn.is_empty() and vinn[1] == c
		kort[c].satt_glod(true, Color(1.0, 0.82, 0.3) if leder else UI.SPELARFARG[p], 1.0 if leder else 0.4)
		var l: Label3D = stick_etiketter[i]
		l.text = spelare[p].namn + ("  ·  leder" if leder and stick_par.size() > 1 else "")
		l.modulate = Color(1.0, 0.86, 0.4) if leder and stick_par.size() > 1 else UI.SPELARFARG[p]
		var sk := _stick_skala()
		l.position = _stickpos(p) + _d(betraktare) * (Kort3D.HOJD * sk * 0.5 * cos(0.38) + 0.2) + Vector3.UP * 0.1
		l.visible = true
	for i in range(stick_par.size(), stick_etiketter.size()):
		stick_etiketter[i].visible = false


func _rensa_stick() -> void:
	for c in stick_vis:
		kort[c].satt_glod(false)
	stick_par = []
	for l in stick_etiketter:
		l.visible = false


func _hog_tf(p: int, j: int, k: int) -> Transform3D:
	var b := Basis(Vector3.UP, PI / 2 + sin(j * 4.1 + k) * 0.04) * _bas(p, false)
	return Transform3D(b, _d(p) * 3.3 + _t(p) * (1.75 + j * 0.3) + Vector3.UP * (0.012 + k * LYFT))


func _etikett_pos(p: int) -> Vector3:
	return _d(p) * R_GUBBE + Vector3.UP * 3.15


# ================================================================== loop
func _process(dt: float) -> void:
	if kam == null:
		return  # serverläge: ingen grafik
	if meny_lage:
		kam_vinkel += dt * 0.05
	kam.transform = _kam_tf(kam_vinkel)
	kastsparr = maxf(kastsparr - dt, 0.0)
	_hover_gubbar()
	_hover_kort(get_viewport().get_mouse_position())


## Vilket kort i handen pekaren eller fingret är över.
func _hover_kort(mp: Vector2) -> void:
	if not ((inmatning == "byte" or inmatning == "spela") and _halls(betraktare)):
		return
	var o := kam.project_ray_origin(mp)
	var r := kam.project_ray_normal(mp)
	var bast := -1
	var bt := 1e9
	for c in vhand[betraktare]:
		var t: float = kort[c].trraff(o, r)
		if t > 0.0 and t < bt:
			bt = t
			bast = c
	if bast != hover_id:
		hover_id = bast
		_layout_sats(betraktare, 0.1, 0.0)


func _unhandled_input(e: InputEvent) -> void:
	if kam == null:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		# vid touch kommer positionen samtidigt som trycket: räkna om vad som träffas just där
		_hover_kort(e.position)
		_hover_gubbar(e.position)
		if hover_id >= 0:
			_klicka(hover_id)
		elif hover_gubbe >= 0:
			ui.visa_kastmeny(e.position, hover_gubbe, spelare[hover_gubbe].namn)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			ui.visa_paus(not ui.ar_pausad)
		elif e.keycode >= KEY_1 and e.keycode <= KEY_5 and inmatning != "" and _halls(betraktare):
			var i: int = e.keycode - KEY_1
			if i < vhand[betraktare].size():
				_klicka(vhand[betraktare][i])
		elif (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and inmatning == "byte":
			beslut.emit("byt")


func _klicka(c: int) -> void:
	if inmatning == "byte":
		if c in valda:
			valda.erase(c)
		elif valda.size() < max_val:
			valda.append(c)
		else:
			ljud.spela("fel")
			return
		ljud.spela("kort", 1.3)
		_layout_sats(betraktare, 0.12, 0.0)
		_byte_ui(betraktare)
	elif inmatning == "spela":
		if c in tillatna:
			beslut.emit(c)
		else:
			ljud.spela("fel")
			ui.visa_banner("Bekänn färg", "Du har %s och måste spela det" % K.FARG_NAMN[K.farg(motor.stick[0][1])], UI.KRAM, 0.8)


func _vanta(sek: float) -> void:
	await get_tree().create_timer(maxf(sek * tf, 0.0), false).timeout


# ================================================================== menyläge
func _meny_dekor(direkt := false) -> void:
	meny_lage = true
	n = 4
	vis_givare = 0
	tur_ring.visible = false
	givarknapp.visible = false
	chicago_etikett.visible = false
	for l in stol_etiketter:
		l.queue_free()
	stol_etiketter.clear()
	_rensa_gubbar()
	stick_par = []
	for l in stick_etiketter:
		l.visible = false
	var royal := [K.kort(K.HJARTER, 10), K.kort(K.HJARTER, 11), K.kort(K.HJARTER, 12), K.kort(K.HJARTER, 13), K.kort(K.HJARTER, 14)]
	var k := 0
	for c in 52:
		kort[c].satt_glod(false)
		kort[c].satt_dimmad(false)
		var mal: Transform3D
		var ri := royal.find(c)
		if ri >= 0:
			var off := ri - 2.0
			var b := Basis(Vector3.UP, -off * 0.16) * _bas(0, true)
			mal = Transform3D(b, Vector3(off * 0.5, 0.02 + ri * 0.004, 0.6 + off * off * 0.05))
		else:
			mal = Transform3D(Basis(Vector3.UP, 0.3) * _bas(0, false), Vector3(-1.4, 0.012 + k * LYFT, -1.2))
			k += 1
		if direkt:
			kort[c].satt_direkt(mal)
		else:
			kort[c].flyg(mal, 0.7, 0.5, randf() * 0.2)


func _till_meny() -> void:
	if online:
		lamna_online()
	korning += 1
	inmatning = ""
	get_tree().paused = false
	ui.dolj_atgard()
	_meny_dekor()
	ui.visa_huvudmeny()


# ================================================================== partiet
## Bordet när ett parti börjar: händer, etiketter, figurer och gränssnitt.
func _satt_upp_bord() -> void:
	# menyns dekorkort samlas direkt till en nedvänd hög
	for c in 52:
		kort[c].satt_glod(false)
		kort[c].flyg(_lek_tf(c, 0), 0.35, 0.3)
	vhand = []
	vis_poang = []
	bytes_info = []
	brickor = []
	hogar = []
	for i in n:
		vhand.append([])
		vis_poang.append(0)
		bytes_info.append("")
		brickor.append("")
		hogar.append(0)
	for l in stol_etiketter:
		l.queue_free()
	stol_etiketter.clear()
	for i in n:
		var l := Label3D.new()
		l.font = font_b
		l.font_size = 48
		l.pixel_size = 0.0065
		l.outline_size = 14
		l.outline_modulate = Color(0, 0, 0, 0.75)
		l.modulate = UI.SPELARFARG[i]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = _etikett_pos(i)
		add_child(l)
		stol_etiketter.append(l)
	_rensa_gubbar()
	for i in n:
		var g := Gubbe.new()
		add_child(g)
		g.bygg_figur(int(spelare[i].get("figur", (i * 5 + 2) % Figurer.antal())))
		g.bas_y = -0.2
		g.position = _d(i) * R_GUBBE + Vector3.UP * g.bas_y
		g.look_at(Vector3(0, g.bas_y, 0), Vector3.UP)
		g.scale = Vector3.ONE * GUBBSKALA
		g.titta_pa(Vector3.ZERO)
		gubbar.append(g)
	ui.visa_hud(spelare, regler.malpoang)
	_tavla()


func _tur(id: int) -> void:
	vantar_pa_drag = true
	await _tur_inre(id)
	vantar_pa_drag = false


func _tur_inre(id: int) -> void:
	var p: int = motor.tur
	_visa_tur(p)
	await _forbered_manniska(p, id)
	if id != korning:
		return
	ljud.spela("tur", 1.0, -6.0)
	match motor.fas:
		Motor.Fas.BYTE:
			valda = []
			max_val = motor.max_byte(p)
			inmatning = "byte"
			_byte_ui(p)
			await beslut
			if id != korning:
				return
			inmatning = ""
			ui.dolj_atgard()
			var sl := valda.duplicate()
			valda = []
			hover_id = -1
			motor.byt(p, sl)
		Motor.Fas.CHICAGO:
			inmatning = "chicago"
			ui.visa_atgard("Vill du ropa Chicago?", "Du lovar att ta alla fem stick. Lyckas det får du %d poäng, annars dras %d poäng." % [regler.chicago_poang, regler.chicago_straff], [["Ropa Chicago!", true, true], ["Nej tack", false]])
			var ja = await beslut
			if id != korning:
				return
			inmatning = ""
			ui.dolj_atgard()
			motor.ropa_chicago(p, bool(ja))
		Motor.Fas.STICK:
			tillatna = motor.tillatna(p)
			for c in vhand[p]:
				kort[c].satt_dimmad(not c in tillatna)
			var info := "Stick %d av 5 – din tur" % motor.stick_nr
			var under := "Spela ut valfritt kort." if motor.stick.is_empty() else "Spelat: %s." % K.namn(motor.stick[0][1])
			if not motor.stick.is_empty():
				var f := K.farg(motor.stick[0][1])
				under += " Du måste bekänna %s." % K.FARG_NAMN[f] if K.farg(tillatna[0]) == f else " Du saknar %s och får spela vad du vill." % K.FARG_NAMN[f]
			if motor.stick_nr == 5:
				under += " Sista sticket ger %d poäng%s." % [regler.stick_poang, (", ut på en tvåa %d" % regler.tvaa_poang) if regler.tvaa_bonus else ""]
			ui.visa_atgard(info, under, [])
			inmatning = "spela"
			var c = await beslut
			if id != korning:
				return
			inmatning = ""
			hover_id = -1
			ui.dolj_atgard()
			for k in vhand[p]:
				kort[k].satt_dimmad(false)
			motor.spela(p, int(c))


func _forbered_manniska(p: int, _id: int) -> void:
	if betraktare != p or not visad:
		betraktare = p
		visad = true
		_kamera_till(p)
		_layout_alla(0.5)


func _byte_ui(p: int) -> void:
	var v := H.varde(vhand[p], regler.ess_lag)
	var pts: int = regler.kat_poang(v.kat)
	var info := "Byte %d av %d" % [motor.byte_nr, regler.antal_byten]
	var raknas: bool = motor.poangsatts_bytet() or regler.poang_efter_stick
	if motor.poangsatts_bytet():
		info += " – poängen räknas efteråt"
	elif regler.poang_efter_stick:
		info += " – handen räknas efter sticket"
	else:
		info += " – inför sticken"
	var hand: String = "Du har: %s" % v.namn
	if pts > 0 and raknas:
		hand += " (%d p om den är bäst)" % pts
	hand += "\nKlicka på korten du vill byta (högst %d)." % max_val
	var t := "Byt %d kort" % valda.size() if valda.size() > 0 else "Behåll alla"
	ui.visa_atgard(info, hand, [[t, "byt", true]])


# ================================================================== layout
func _layout_sats(p: int, tid: float, bage := 0.25) -> void:
	if p >= vhand.size():
		return
	var h: Array = vhand[p]
	var m := h.size()
	var halls := _halls(p)
	for k in m:
		var c: int = h[k]
		var mal: Transform3D
		if halls:
			mal = _hallen_tf(k, m, c in valda, c == hover_id)
		else:
			mal = _liggande_tf(p, k, m, false)
		kort[c].flyg(mal, tid * tf, bage)


func _layout_alla(tid: float) -> void:
	for p in n:
		_layout_sats(p, tid)


func _fran_lek(c: int) -> void:
	var i := lek_vis.find(c)
	if i < 0:
		return
	var top := lek_vis.size() - 1
	if i != top:
		# korten ser likadana ut bakifrån: byt plats på dem så att kortet tas överst
		var o: int = lek_vis[top]
		lek_vis[i] = o
		lek_vis[top] = c
		var tc: Transform3D = kort[c].transform
		kort[c].satt_direkt(kort[o].transform)
		kort[o].satt_direkt(tc)
	lek_vis.pop_back()


func _tavla() -> void:
	if motor != null and "chicago_tagen" in motor:
		for i in mini(n, brickor.size()):
			var tagen: bool = i < motor.chicago_tagen.size() and motor.chicago_tagen[i]
			var behover: bool = regler.chicago_kravs_for_vinst and regler.chicago_tillatet and i < vis_poang.size() and vis_poang[i] >= regler.malpoang and not tagen
			if behover:
				brickor[i] = "behöver Chicago"
			elif brickor[i] == "behöver Chicago":
				brickor[i] = "Chicago tagen" if tagen else ""
	var tur := -1
	if motor and (motor.fas == Motor.Fas.BYTE or motor.fas == Motor.Fas.STICK):
		tur = motor.tur
	ui.uppdatera_tavla(vis_poang, tur, vis_givare, bytes_info, brickor)
	_uppdatera_etiketter()


func _uppdatera_etiketter() -> void:
	for i in stol_etiketter.size():
		var l: Label3D = stol_etiketter[i]
		l.text = "%s\n%d p" % [spelare[i].namn, vis_poang[i]]
		l.visible = i != betraktare and not meny_lage
	for i in gubbar.size():
		gubbar[i].visible = i != betraktare and not meny_lage


func _visa_tur(p: int) -> void:
	if motor != null and motor.fas == Motor.Fas.CHICAGO:
		tur_ring.visible = false
		_tavla()
		return
	tur_ring.visible = true
	tur_ring.transform = Transform3D(Basis(Vector3.UP, _vinkel(p)), _d(p) * R_HAND + Vector3.UP * 0.006)
	(tur_ring.material_override as ShaderMaterial).set_shader_parameter("farg", UI.SPELARFARG[p])
	# figurerna tittar mot den som har turen, den som har turen tittar på sina kort
	for i in gubbar.size():
		if i == p:
			gubbar[i].titta_pa(_d(i) * 3.5)
		else:
			gubbar[i].titta_pa(_sittplats(p))
	_tavla()


## Ungefär där en spelares huvud är (kameran för den som tittar).
func _sittplats(p: int) -> Vector3:
	if p == betraktare:
		return kam.global_position
	if p >= gubbar.size():
		return _d(p) * R_GUBBE + Vector3.UP * 2.6
	return gubbar[p].huvudpos()


func _nar_text(nar: String) -> String:
	match nar:
		"given":
			return " · givens hand"
		"sluthand":
			return " · handen efter sticket"
		"byte":
			return " · efter bytet"
	return ""


func _chicago_tagen(p: int) -> bool:
	if motor == null or not "chicago_tagen" in motor:
		return false
	var t: Array = motor.chicago_tagen
	return p < t.size() and t[p]


func _rensa_gubbar() -> void:
	for g in gubbar:
		g.queue_free()
	gubbar.clear()
	hover_gubbe = -1


func _gest(p: int) -> void:
	if p < gubbar.size():
		gubbar[p].gest()


# ================================================================== kasta vattenballong, tomat, ros
## Musen över en figur ger handpekare och möjlighet att kasta. Påverkar inte spelet och avslöjar inga kort.
func _hover_gubbar(punkt = null) -> void:
	var ny := -1
	if not meny_lage and not gubbar.is_empty() and not ui.ar_pausad and ui.hud.visible and hover_id < 0:
		var mp: Vector2 = punkt if punkt != null else get_viewport().get_mouse_position()
		var o := kam.project_ray_origin(mp)
		var r := kam.project_ray_normal(mp)
		var bt := 1e9
		for i in gubbar.size():
			var t: float = gubbar[i].traff_avstand(o, r)
			if t > 0.0 and t < bt:
				bt = t
				ny = i
	if ny != hover_gubbe:
		hover_gubbe = ny
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if ny >= 0 else Input.CURSOR_ARROW)


func _kasta_fran_mig(mal: int, typ: String) -> void:
	if meny_lage or mal >= gubbar.size():
		return
	if online:
		klient.skicka({"t": "kasta", "till": mal, "vad": typ})
		return
	if kastsparr > 0.0:
		ui.visa_banner("Vänta lite", "Du kan kasta igen om %d s" % ceili(kastsparr), UI.KRAM, 0.7)
		return
	kastsparr = KASTSPARR
	_kasta(-1, mal, typ, true)


## fran/till: plats, eller -1 för den som tittar (kameran). svar = om figuren får kasta tillbaka.
func _kasta(fran: int, till: int, typ: String, svar: bool) -> void:
	var k := korning
	if typ == "sexsju":
		_sexsju(till)
		return
	if typ == "konfetti":
		# tårtsmällare: smäller direkt över figuren
		ljud.spela("small", 1.0, -2.0, 0.08)
		get_tree().create_timer(0.15, false).timeout.connect(func() -> void:
			if k == korning:
				_traff(fran, till, typ, _kast_mal(till) + Vector3.UP * 1.2, svar))
		return
	var start := _kast_start(fran)
	var proj := _projektil(typ)
	add_child(proj)
	proj.position = start
	ljud.spela("kast_luft", 1.3 if typ == "flygplan" else 1.0, -4.0, 0.1)
	if fran >= 0:
		_gest(fran)
	var snurr := Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	var tid := 0.85
	var bage := 2.4
	match typ:
		"flygplan":
			tid = 1.5
			bage = 0.9
		"hjarta", "krona":
			tid = 1.2
			bage = 1.6
	var tw := proj.create_tween()
	tw.tween_method(func(t: float) -> void:
		var mal := _kast_mal(till)
		var p := start.lerp(mal, t) + Vector3.UP * bage * sin(PI * t)
		if typ == "flygplan":
			# glider: pekar framåt i flygriktningen och gungar lite
			var fram := (mal - start).normalized()
			if (p - proj.position).length() > 0.001:
				proj.look_at_from_position(p, p + fram + Vector3.UP * cos(PI * t) * 0.6, Vector3.UP)
			proj.rotate_object_local(Vector3.FORWARD, sin(t * 9.0) * 0.25)
			proj.position = p
		elif typ == "hjarta" or typ == "krona":
			proj.position = p
			proj.rotation = Vector3(0, t * TAU, 0)
		else:
			proj.position = p
			proj.rotation = snurr * t, 0.0, 1.0, tid)
	tw.tween_callback(func() -> void:
		var pos := proj.position
		if typ == "flygplan":
			# studsar mot huvudet och faller ned
			var ned := proj.create_tween()
			ned.set_parallel(true)
			ned.tween_property(proj, "position", pos + Vector3(rng.randf_range(-0.8, 0.8), -2.6, rng.randf_range(-0.8, 0.8)), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			ned.tween_property(proj, "rotation", proj.rotation + Vector3(2.5, 1.0, 3.0), 1.0)
			ned.chain().tween_callback(proj.queue_free)
		else:
			proj.queue_free()
		if k == korning:
			_traff(fran, till, typ, pos, svar))


## 6-7: figuren gör rörelsen. Den egna platsen (utan figur framför kameran) visas i 2D.
func _egen_sexsju() -> void:
	if meny_lage:
		return
	if online:
		klient.skicka({"t": "kasta", "till": min_plats, "vad": "sexsju"})
		return
	if kastsparr > 0.0:
		ui.visa_banner("Vänta lite", "Du kan göra det igen om %d s" % ceili(kastsparr), UI.KRAM, 0.7)
		return
	kastsparr = KASTSPARR
	_sexsju(betraktare)


func _sexsju(p: int) -> void:
	ljud.spela("sexsju", 1.0, -2.0, 0.04)
	if p >= 0 and p < gubbar.size() and p != betraktare:
		gubbar[p].sexsju()
	else:
		ui.sexsju_skarm()


func _traff(fran: int, till: int, typ: String, pos: Vector3, svar: bool) -> void:
	var farg := Color(0.5, 0.78, 1.0)
	match typ:
		"vattenballong":
			ljud.spela("plask", 1.0, 0.0, 0.08)
		"tomat":
			farg = Color(0.85, 0.12, 0.05)
			ljud.spela("splatt", 1.0, 0.0, 0.08)
		"tarta":
			farg = Color(0.99, 0.96, 0.9)
			ljud.spela("splatt", 1.3, 0.0, 0.08)
		"snoboll":
			farg = Color(0.95, 0.97, 1.0)
			ljud.spela("puff", 1.0, 0.0, 0.1)
		"flygplan":
			farg = Color(1, 1, 1)
			ljud.spela("klick", 0.6, 0.0, 0.1)
		"hjarta":
			farg = Color(1.0, 0.3, 0.45)
			ljud.spela("kyss", 1.0, -2.0, 0.08)
		"krona":
			farg = Color(1.0, 0.82, 0.3)
			ljud.spela("stor_poang", 1.2, -4.0, 0.0)
		"konfetti":
			farg = Color(1, 1, 1)
		_:
			farg = Color(1.0, 0.45, 0.6)
			ljud.spela("poang", 1.3, -4.0, 0.0)
	var mot_mig := till < 0 or till >= gubbar.size() or till == betraktare
	if mot_mig:
		ui.plask_skarm(typ)
	else:
		if typ != "flygplan":
			_stank(pos, farg, typ)
		gubbar[till].traffad(typ)


func _kast_start(fran: int) -> Vector3:
	if fran < 0 or fran >= gubbar.size() or fran == betraktare:
		return kam.global_position + kam.global_basis * Vector3(0.8, -1.6, -2.2)
	return gubbar[fran].huvudpos() + gubbar[fran].global_basis * Vector3(0.9, -0.6, -1.0)


func _kast_mal(till: int) -> Vector3:
	if till < 0 or till >= gubbar.size() or till == betraktare:
		return kam.global_position + kam.global_basis * Vector3(0, -0.2, -1.4)
	return gubbar[till].huvudpos()


func _projektil(typ: String) -> Node3D:
	var n3 := Node3D.new()
	match typ:
		"vattenballong":
			var mat := _enkel_mat(Color(0.35, 0.65, 1.0, 0.8), 0.08)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.metallic_specular = 0.9
			_klot_i(n3, 0.3, mat, Vector3.ZERO, Vector3(1, 1.15, 1))
			_klot_i(n3, 0.07, mat, Vector3(0, -0.36, 0), Vector3.ONE)
		"tomat":
			_klot_i(n3, 0.27, _enkel_mat(Color(0.85, 0.12, 0.06), 0.25), Vector3.ZERO, Vector3(1, 0.88, 1))
			_cyl_i(n3, 0.12, 0.04, _enkel_mat(Color(0.2, 0.55, 0.15), 0.6), Vector3(0, 0.24, 0))
		"tarta":
			# gräddtårta på en tallrik
			_cyl_i(n3, 0.42, 0.04, _enkel_mat(Color(0.95, 0.95, 0.97), 0.3), Vector3(0, -0.12, 0))
			_cyl_i(n3, 0.36, 0.18, _enkel_mat(Color(0.85, 0.65, 0.4), 0.7), Vector3(0, 0.0, 0))
			_klot_i(n3, 0.36, _enkel_mat(Color(0.99, 0.97, 0.92), 0.35), Vector3(0, 0.1, 0), Vector3(1, 0.45, 1))
			_klot_i(n3, 0.07, _enkel_mat(Color(0.85, 0.05, 0.1), 0.3), Vector3(0, 0.27, 0), Vector3.ONE)
		"snoboll":
			_klot_i(n3, 0.26, _enkel_mat(Color(0.96, 0.98, 1.0), 0.9), Vector3.ZERO, Vector3.ONE)
		"flygplan":
			n3.add_child(_pappersflygplan())
		"hjarta":
			var s := Sprite3D.new()
			s.texture = _hjarttextur()
			s.pixel_size = 0.012
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.modulate = Color(1.0, 0.3, 0.45)
			n3.add_child(s)
		"krona":
			var guld := _enkel_mat(Color(1.0, 0.78, 0.2), 0.25)
			guld.metallic = 0.8
			_cyl_i(n3, 0.3, 0.14, guld, Vector3.ZERO)
			for k in 5:
				var a := TAU * k / 5.0
				var sp := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.07
				c.height = 0.2
				sp.mesh = c
				sp.material_override = guld
				sp.position = Vector3(cos(a) * 0.26, 0.16, sin(a) * 0.26)
				n3.add_child(sp)
		_:
			# ros
			_klot_i(n3, 0.16, _enkel_mat(Color(0.85, 0.08, 0.2), 0.5), Vector3.ZERO, Vector3(1, 0.9, 1))
			_cyl_i(n3, 0.025, 0.8, _enkel_mat(Color(0.15, 0.5, 0.15), 0.6), Vector3(0, -0.45, 0))
	return n3


func _enkel_mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _klot_i(f: Node3D, r: float, mat: Material, pos: Vector3, sk: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = sk
	f.add_child(mi)


func _cyl_i(f: Node3D, r: float, h: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	f.add_child(mi)


## Pappersflygplan av två trianglar (vingar) och en köl, vikt av vitt papper. Nosen pekar mot -Z.
func _pappersflygplan() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nos := Vector3(0, 0, -0.55)
	var bak := Vector3(0, 0, 0.35)
	var v := Vector3(-0.4, 0.06, 0.35)
	var h := Vector3(0.4, 0.06, 0.35)
	var kol := Vector3(0, -0.12, 0.3)
	for tri in [[nos, bak, v], [nos, h, bak], [nos, kol, bak]]:
		for p in tri:
			st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _enkel_mat(Color(0.98, 0.98, 0.95), 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


var _hjart_tex: ImageTexture


## Hjärta ritat pixel för pixel med hjärtkurvan (x² + y² − 1)³ − x²y³ ≤ 0.
func _hjarttextur() -> ImageTexture:
	if _hjart_tex:
		return _hjart_tex
	var st := 64
	var img := Image.create(st, st, false, Image.FORMAT_RGBA8)
	for py in st:
		for px in st:
			var x := (px - st / 2.0) / (st * 0.38)
			var y := -(py - st / 2.0) / (st * 0.38) + 0.15
			var f := pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y
			img.set_pixel(px, py, Color(1, 1, 1, 1) if f <= 0.0 else Color(1, 1, 1, 0))
	_hjart_tex = ImageTexture.create_from_image(img)
	return _hjart_tex


func _stank(pos: Vector3, farg: Color, typ: String) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 70
	p.lifetime = 1.1
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -12.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	var mat := _enkel_mat(farg, 0.1)
	mat.metallic_specular = 0.8
	match typ:
		"ros":
			p.amount = 30
			p.gravity = Vector3(0, -2.0, 0)
			sm.radius = 0.08
			sm.height = 0.05
		"snoboll":
			# snöpuffar: mjuka, långsamma
			p.amount = 50
			p.gravity = Vector3(0, -1.5, 0)
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 2.2
			p.lifetime = 1.6
			sm.radius = 0.14
			sm.height = 0.28
			mat.roughness = 1.0
			mat.metallic_specular = 0.0
		"hjarta":
			# svävande hjärtan
			var q := QuadMesh.new()
			q.size = Vector2(0.35, 0.35)
			p.mesh = q
			p.amount = 14
			p.lifetime = 2.2
			p.explosiveness = 0.3
			p.gravity = Vector3(0, 1.2, 0)
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.0
			var hm := StandardMaterial3D.new()
			hm.albedo_texture = _hjarttextur()
			hm.albedo_color = farg
			hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			hm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			p.material_override = hm
		"krona":
			p.amount = 40
			p.gravity = Vector3(0, -1.0, 0)
			p.initial_velocity_max = 2.5
			sm.radius = 0.04
			sm.height = 0.08
			mat.emission_enabled = true
			mat.emission = farg
			mat.emission_energy_multiplier = 2.0
		"konfetti":
			# glatt regn i alla färger
			var q := QuadMesh.new()
			q.size = Vector2(0.09, 0.14)
			p.mesh = q
			p.amount = 140
			p.lifetime = 2.4
			p.explosiveness = 0.9
			p.direction = Vector3.UP
			p.spread = 70.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 6.0
			p.gravity = Vector3(0, -4.0, 0)
			p.damping_min = 1.5
			p.damping_max = 3.0
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			var gr := Gradient.new()
			gr.colors = PackedColorArray([Color(1, 0.2, 0.3), Color(1, 0.8, 0.1), Color(0.2, 0.8, 0.3), Color(0.2, 0.5, 1), Color(0.8, 0.3, 1)])
			gr.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			gr.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			p.color_initial_ramp = gr
			var km := StandardMaterial3D.new()
			km.vertex_color_use_as_albedo = true
			km.cull_mode = BaseMaterial3D.CULL_DISABLED
			km.roughness = 0.5
			p.material_override = km
	if p.mesh == null:
		p.mesh = sm
	if p.material_override == null:
		p.material_override = mat
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0, false).timeout.connect(p.queue_free)


func _popup(p: int, text: String, farg: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font_b
	l.font_size = 110
	l.pixel_size = 0.008
	l.outline_size = 20
	l.outline_modulate = Color(0, 0, 0, 0.75)
	l.modulate = farg
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	var start := _d(p) * (2.9 if _halls(p) else 4.0) + Vector3.UP * 0.7
	l.position = start
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", start + Vector3.UP * 0.9, 1.8 * tf).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6 * tf).set_delay(1.2 * tf)
	tw.chain().tween_callback(l.queue_free)


# ================================================================== händelser
func _spela_upp(id: int) -> void:
	for e in motor.ta_handelser():
		if id != korning:
			return
		await _handelse(e, id)


func _handelse(e: Dictionary, id: int) -> void:
	if online:
		_tolka_online(e)
	match e.typ:
		"parti_start":
			vis_givare = e.givare
			ui.logga("Partiet börjar. Först till %d poäng." % regler.malpoang, UI.GULD)
			_tavla()
		"blanda":
			vis_givare = e.givare
			for i in n:
				bytes_info[i] = ""
				brickor[i] = "Chicago tagen" if _chicago_tagen(i) else ""
				vhand[i] = []
				hogar[i] = 0
			chicago_etikett.visible = false
			givarknapp.visible = true
			var gt := Transform3D(Basis(Vector3.UP, _vinkel(e.givare)), _d(e.givare) * 3.55 - _t(e.givare) * 0.2)
			var tw := create_tween()
			tw.tween_property(givarknapp, "transform", gt, 0.6 * tf).set_trans(Tween.TRANS_CUBIC)
			ui.satt_fas("Giv %d · %s blandar" % [e.giv, spelare[e.givare].namn])
			ui.logga("Giv %d: %s blandar och ger." % [e.giv, spelare[e.givare].namn])
			_tavla()
			await _blanda_anim(e.givare, id)
		"giv":
			var p: int = e.spelare
			_fran_lek(e.kort)
			vhand[p].append(e.kort)
			_layout_sats(p, 0.3, 0.45)
			ljud.spela("kort", 1.0, -3.0)
			await _vanta(0.075)
		"giv_klar":
			await _vanta(0.25)
			for p in n:
				vhand[p] = K.sortera_hand(vhand[p])
			_layout_alla(0.35)
			await _vanta(0.4)
		"byte_start":
			for i in n:
				bytes_info[i] = ""
			var vad := "inför sticken"
			if e.poangsatts:
				vad = "poängen räknas efteråt"
			elif regler.poang_efter_stick:
				vad = "handen räknas efter sticket"
			ui.satt_fas("Byte %d av %d · %s" % [e.nr, regler.antal_byten, vad])
			_tavla()
		"omblandning":
			ui.logga("Talongen är slut. Slänghögen blandas om.")
			ui.visa_banner("Talongen är slut", "Slänghögen blandas till en ny talong", UI.KRAM, 1.0)
			lek_vis = slang_vis + lek_vis
			slang_vis = []
			for k in lek_vis.size():
				kort[lek_vis[k]].flyg(_lek_tf(k, vis_givare), 0.45 * tf, 0.4, k * 0.01 * tf)
			ljud.spela("blanda")
			await _vanta(0.9)
		"byte":
			await _byte_anim(e, id)
		"poang":
			await _poang_anim(e, id)
		"ingen_poang":
			ui.visa_banner("Ingen poänghand", "Ingen har par eller bättre%s" % _nar_text(e.get("nar", "")), UI.KRAM, 0.9)
			ui.logga("Ingen fick poäng.")
			await _vanta(1.3)
		"lika":
			var namnen: Array = []
			for p in e.spelare:
				namnen.append(spelare[p].namn)
			ui.visa_banner("Lika händer", "Ingen får poäng", UI.KRAM, 1.2)
			ui.logga("Lika händer mellan %s: ingen poäng." % ", ".join(namnen))
			await _vanta(1.6)
		"chicago_fraga":
			# vem som får ropa är hemligt: ingen markering av tur under frågan
			tur_ring.visible = false
			ui.satt_fas("Chicago?")
			_tavla()
		"star_over":
			var p: int = e.spelare
			bytes_info[p] = "står över"
			_popup(p, "Står över", UI.KRAM)
			if p == betraktare:
				ui.visa_banner("Köpstopp", "Du har nått köpstoppet och står över bytena", UI.GULD, 1.6)
				ui.logga("Köpstopp: du står över bytena.", UI.GULD)
			else:
				ui.logga("%s står över." % spelare[p].namn)
			_tavla()
			await _vanta(0.9 if p == betraktare else 0.5)
		"nollstall":
			var p: int = e.spelare
			vis_poang = e.poang_efter.duplicate()
			ljud.spela("sprack", 1.2, 0.0, 0.0)
			for q in e.nollstallda:
				_popup(q, "0", Color(1.0, 0.45, 0.4))
				if q < gubbar.size():
					gubbar[q].ledsen()
			if p < gubbar.size():
				gubbar[p].jubel(true)
			ui.visa_banner("Fyrtal!", "%s nollställer alla andras poäng" % spelare[p].namn, UI.GULD, 1.6)
			ui.logga("Fyrtal: %s nollställer alla andra." % spelare[p].namn, UI.GULD)
			_tavla()
			await _vanta(2.0)
		"redovisning":
			ui.satt_fas("Rundans poäng")
			ui.visa_banner("Rundans poäng", "", UI.KRAM, 0.8)
			await _vanta(1.0)
		"chicago":
			var p: int = e.spelare
			brickor[p] = "Chicago"
			chicago_etikett.position = _etikett_pos(p) + Vector3.UP * 0.9
			if _halls(p):
				chicago_etikett.position = _d(p) * 3.0 + Vector3.UP * 1.6
			chicago_etikett.visible = true
			ljud.spela("chicago", 1.0, 0.0, 0.0)
			ui.visa_banner("CHICAGO!", "%s ska ta alla fem stick" % spelare[p].namn, UI.GULD, 1.8)
			ui.logga("%s ropar Chicago!" % spelare[p].namn, UI.GULD)
			_tavla()
			await _vanta(2.2)
		"stick_start":
			stick_vis = []
			_rensa_stick()
			if e.nr == 1:
				for i in n:
					bytes_info[i] = ""
			var t := "Stick %d av 5" % e.nr
			if motor.chicago >= 0 and not motor.chicago_sprack:
				t += " · Chicago: %s" % spelare[motor.chicago].namn
			ui.satt_fas(t)
		"spela":
			var p: int = e.spelare
			vhand[p].erase(e.kort)
			stick_vis.append(e.kort)
			stick_par.append([p, e.kort])
			kort[e.kort].satt_dimmad(false)
			kort[e.kort].flyg(_stick_tf(p, stick_vis.size() - 1), 0.38 * tf, 0.55)
			_layout_sats(p, 0.3)
			_gest(p)
			await _vanta(0.3)
			ljud.spela("kast", 1.0, 0.0, 0.09)
			_markera_stick()
			await _vanta(0.15)
		"stick":
			await _stick_anim(e, id)
		"chicago_sprack":
			ljud.spela("sprack", 1.0, 0.0, 0.0)
			chicago_etikett.visible = false
			brickor[e.spelare] = "Sprack"
		"giv_slut":
			ui.satt_fas("Given är slut")
			tur_ring.visible = false
			_tavla()
		"vinst":
			tur_ring.visible = false
			ljud.spela("vinst", 1.0, 0.0, 0.0)
			ui.visa_banner("%s vinner!" % spelare[e.spelare].namn, "%d poäng" % e.poang[e.spelare], UI.GULD, 2.5)
			ui.logga("%s vinner partiet med %d poäng!" % [spelare[e.spelare].namn, e.poang[e.spelare]], UI.GULD)
			await _vanta(3.0)


func _blanda_anim(g: int, id: int) -> void:
	_rensa_stick()
	for c in 52:
		kort[c].satt_glod(false)
		kort[c].satt_dimmad(false)
	lek_vis = K.ny_lek()
	K.blanda(lek_vis, rng)
	slang_vis = []
	stick_vis = []
	# samla ihop alla kort till givaren
	for k in 52:
		kort[lek_vis[k]].flyg(_lek_tf(k, g), 0.5 * tf, 0.6, (k % 26) * 0.008 * tf)
	ljud.spela("glid")
	await _vanta(0.85)
	if id != korning:
		return
	var tb := _t(g)
	var mitt := _lekpos(g)
	for varv in 2:
		# dela leken i två halvor som lutas mot varandra
		for k in 52:
			var vanster := k < 26
			var kk := k if vanster else k - 26
			var pos := mitt + tb * (-0.42 if vanster else 0.42) + Vector3.UP * (0.03 + kk * LYFT)
			var b := Basis(_d(g), 0.16 if vanster else -0.16) * _bas(g, false)
			kort[lek_vis[k]].flyg(Transform3D(b, pos), 0.2 * tf, 0.08)
		ljud.spela("kort", 0.8)
		await _vanta(0.26)
		if id != korning:
			return
		# riffla ihop halvorna
		var a: Array = lek_vis.slice(0, 26)
		var bb: Array = lek_vis.slice(26)
		var ny: Array = []
		while not a.is_empty() or not bb.is_empty():
			for x in rng.randi_range(1, 2):
				if not a.is_empty():
					ny.append(a.pop_front())
			for x in rng.randi_range(1, 2):
				if not bb.is_empty():
					ny.append(bb.pop_front())
		lek_vis = ny
		ljud.spela("blanda", 1.0, 0.0, 0.03)
		for k in 52:
			kort[lek_vis[k]].flyg(_lek_tf(k, g), 0.12 * tf, 0.04, k * 0.013 * tf)
		await _vanta(52 * 0.013 + 0.22)
		if id != korning:
			return


func _byte_anim(e: Dictionary, id: int) -> void:
	var p: int = e.spelare
	var sl: Array = e.slangda
	for i in sl.size():
		var c: int = sl[i]
		vhand[p].erase(c)
		slang_vis.append(c)
		kort[c].flyg(_slang_tf(slang_vis.size() - 1), 0.36 * tf, 0.4, i * 0.06 * tf)
	var namn: String = spelare[p].namn
	if sl.is_empty():
		_popup(p, "Står", UI.KRAM)
		ui.logga("%s byter inga kort." % namn)
		bytes_info[p] = "stod"
	else:
		_popup(p, "Byter %d" % sl.size(), UI.KRAM)
		_gest(p)
		ui.logga("%s byter %d kort." % [namn, sl.size()])
		bytes_info[p] = "bytte %d" % sl.size()
		ljud.spela("glid", 1.2)
	_tavla()
	_layout_sats(p, 0.3)
	await _vanta(0.42 if sl.size() > 0 else 0.3)
	if id != korning:
		return
	for c in e.nya:
		_fran_lek(c)
		vhand[p].append(c)
		_layout_sats(p, 0.3, 0.45)
		ljud.spela("kort", 1.0, -3.0)
		await _vanta(0.09)
		if id != korning:
			return
	if not e.nya.is_empty():
		await _vanta(0.3)
		vhand[p] = K.sortera_hand(vhand[p])
		_layout_sats(p, 0.3, 0.1)
		await _vanta(0.2)


func _poang_anim(e: Dictionary, id: int) -> void:
	var p: int = e.spelare
	var namn: String = spelare[p].namn
	vis_poang[p] = e.tot
	if e.has("poang_efter"):
		vis_poang = e.poang_efter.duplicate()
	var pts: int = e.poang
	# husregeln: når man målet utan Chicago fortsätter partiet
	if regler.chicago_kravs_for_vinst and regler.chicago_tillatet and p == betraktare and vis_poang[p] >= regler.malpoang and not _chicago_tagen(p):
		ui.logga("Du har %d poäng men behöver en lyckad Chicago för att vinna." % vis_poang[p], UI.GULD)
	var txt := ("+%d" % pts) if pts >= 0 else ("−%d" % -pts)
	_popup(p, txt, UI.GULD if pts >= 0 else Color(1.0, 0.4, 0.35))
	if p < gubbar.size():
		if pts > 0:
			gubbar[p].jubel(pts >= 5)
		elif pts < 0:
			gubbar[p].ledsen()
	_tavla()
	match e.orsak:
		"hand":
			# bara vem som tar poängen och handtypen visas, inga kort vänds
			ljud.spela("poang" if pts < 5 else "stor_poang", 1.0, -2.0, 0.0)
			ui.visa_banner("%s: %s" % [namn, e.text], "%d poäng%s" % [pts, _nar_text(e.get("nar", ""))], UI.SPELARFARG[p], 1.3)
			ui.logga("%s: %s, %d poäng." % [namn, e.text, pts], UI.SPELARFARG[p])
			await _vanta(1.9)
		"stick":
			ljud.spela("stor_poang" if pts > regler.stick_poang else "poang", 1.0, -2.0, 0.0)
			var under := "+%d poäng" % pts
			if e.text.ends_with("tvåa"):
				under = "Med en tvåa! +%d poäng" % pts
			if e.begransad:
				under += " (man kan inte vinna på sticket)"
			ui.visa_banner("%s tar sista sticket" % namn, under, UI.SPELARFARG[p], 1.4)
			ui.logga("%s tar sista sticket: +%d." % [namn, pts], UI.SPELARFARG[p])
			await _vanta(1.8)
		"chicago":
			ljud.spela("vinst", 1.0, 0.0, 0.0)
			ui.visa_banner("Chicago!", "%s tog alla fem stick · +%d poäng" % [namn, pts], UI.GULD, 1.8)
			ui.logga("%s klarade Chicago: +%d." % [namn, pts], UI.GULD)
			brickor[p] = "Chicago tagen"
			chicago_etikett.visible = false
			await _vanta(2.2)
		"chicago_miss":
			ui.visa_banner("Chicagot sprack", "%s förlorar %d poäng" % [namn, -pts], Color(1.0, 0.45, 0.4), 1.6)
			ui.logga("%s klarade inte Chicago: %d." % [namn, pts], Color(1.0, 0.5, 0.45))
			await _vanta(2.0)


func _stick_anim(e: Dictionary, id: int) -> void:
	var w: int = e.vinnare
	await _vanta(0.3)
	if id != korning:
		return
	kort[e.kort].satt_glod(true, Color(1.0, 0.82, 0.3), 1.3)
	ui.logga("%s tar stick %d med %s." % [spelare[w].namn, e.nr, K.namn(e.kort)])
	if e.nr < 5:
		_popup(w, "Sticket", UI.SPELARFARG[w])
	await _vanta(1.2 if e.nr == 5 else 0.75)
	if id != korning:
		return
	_rensa_stick()
	var j: int = hogar[w]
	hogar[w] += 1
	var k := 0
	for c in stick_vis:
		kort[c].flyg(_hog_tf(w, j, k), 0.4 * tf, 0.3, k * 0.03 * tf)
		k += 1
	stick_vis = []
	ljud.spela("glid", 0.9)
	if motor.fas == Motor.Fas.STICK or e.nr < 5:
		bytes_info[w] = "%d stick" % hogar[w]
	_tavla()
	await _vanta(0.4)


# ================================================================== onlinespel
## Flödet online: klienten ansluter till servern, skapar eller går med i ett bord och visar lobbyn.
## När värden startar kommer serverns steg (händelser + tillstånd) som spelas upp med samma grafik som lokalt.
## Andra spelares kort kommer som -1 och visas med anonyma kortnoder (se _tolka_online).

const ONLINEFIL := "user://chicago_online.cfg"

var senaste_lobby := {}
var online_kod := ""
var online_namn := ""
var online_kor := false
var ar_varde := false
var ateransluter := false
var server_url_tvingad := ""  # för tester


func _server_url() -> String:
	return server_url_tvingad if server_url_tvingad != "" else Natverk.server_url()

signal nat_nytt


func _klient() -> Node:
	if klient == null:
		klient = Klient.new()
		klient.name = "Klient"
		klient.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(klient)
		klient.meddelande.connect(_natmeddelande)
		klient.frankopplad.connect(_nat_frankopplad)
	return klient


func skapa_online(namn: String, antal: int, r, vis: Dictionary) -> void:
	online_namn = namn
	visning = vis.duplicate()
	ui.visa_lobby_vantar("Ansluter till servern …")
	_anslut_om_behovs()
	klient.skicka({"t": "skapa", "namn": namn, "antal": antal, "regler": r.till_dict(), "figur": ui.spelar_rader[0].figur})


func ga_med_online(kod: String, namn: String, figur: int) -> void:
	online_namn = namn
	online_kod = kod.to_upper().strip_edges()
	# kom ihåg figurvalet till nästa gång
	ui._satt_radfigur(0, figur)
	ui._spara_installningar()
	_anslut_om_behovs()
	klient.skicka({"t": "ga_med", "kod": online_kod, "namn": namn, "token": _sparad_token(online_kod), "figur": figur})


## Frågar servern om ett bord (regler, värd, tagna figurer) innan man går med.
func fraga_bordinfo(kod: String) -> void:
	_anslut_om_behovs()
	klient.skicka({"t": "bordinfo", "kod": kod})


func _anslut_om_behovs() -> void:
	_klient()
	if not klient.ar_ansluten() and klient.url == "":
		klient.anslut(_server_url())


func _sparad_token(kod: String) -> String:
	var cf := ConfigFile.new()
	if cf.load(ONLINEFIL) != OK:
		return ""
	return str(cf.get_value("token", kod, ""))


func _spara_token(kod: String, token: String) -> void:
	var cf := ConfigFile.new()
	cf.load(ONLINEFIL)
	cf.set_value("token", kod, token)
	cf.set_value("spelare", "namn", online_namn)
	cf.save(ONLINEFIL)


func sparat_namn() -> String:
	var cf := ConfigFile.new()
	if cf.load(ONLINEFIL) != OK:
		return ""
	return str(cf.get_value("spelare", "namn", ""))


func _natmeddelande(d: Dictionary) -> void:
	match d.t:
		"valkommen":
			min_plats = d.plats
			online_kod = d.kod
			ar_varde = d.varde
			ateransluter = false
			_spara_token(d.kod, d.token)
		"lobby":
			senaste_lobby = d
			if d.startad and not online_kor:
				_starta_online(null)
			elif not d.startad and not online_kor:
				ui.visa_lobby(d, min_plats, Natverk.lank(d.kod))
		"steg":
			if not online_kor:
				_starta_online(null)
			fjarr.lagg_till(d)
			nat_nytt.emit()
		"ogonblick":
			# återanslutning: börja om flödet så att pågående animeringar avbryts, och bygg bordet från serverns läge
			_starta_online(d)
			nat_nytt.emit()
		"bordinfo":
			ui.visa_bordinfo(d)
		"kast":
			if online_kor and not meny_lage:
				_kasta(d.fran, d.till, d.vad, false)
		"fel":
			if online_kor:
				ui.visa_banner("Servern", d.text, UI.KRAM, 1.2)
				if fjarr:
					fjarr.skickat = false
				nat_nytt.emit()
			else:
				ui.visa_lobby_fel(d.text)


func _nat_frankopplad() -> void:
	if not online:
		return
	if online_kor:
		ui.visa_banner("Anslutningen bröts", "Försöker ansluta igen …", UI.KRAM, 1.5)
		_ateranslut()
	else:
		ui.visa_lobby_fel("Kunde inte ansluta till servern (%s)." % _server_url())


## Ansluter igen med sparad token (samma plats vid bordet).
func _ateranslut() -> void:
	if ateransluter:
		return
	ateransluter = true
	var k := korning
	while ateransluter and k == korning and online:
		klient.anslut(_server_url())
		klient.skicka({"t": "ga_med", "kod": online_kod, "namn": online_namn, "token": _sparad_token(online_kod)})
		await get_tree().create_timer(3.0).timeout


func lobby_starta() -> void:
	klient.skicka({"t": "starta"})


func lamna_online() -> void:
	if klient:
		klient.skicka({"t": "lamna"})
		klient.koppla_fran()
	online = false
	online_kor = false
	ateransluter = false


func _starta_online(ogon) -> void:
	korning += 1
	var id := korning
	online = true
	online_kor = true
	var l: Dictionary = senaste_lobby
	spelare = []
	for x in l.platser:
		spelare.append({"namn": x.namn if x.namn != "" else "Ledig", "figur": int(x.get("figur", 0))})
	regler = Regler.new()
	regler.fran_dict(l.regler)
	n = spelare.size()
	ar_varde = l.varde == min_plats
	fjarr = Fjarrmotor.new()
	fjarr.klient = klient
	fjarr.regler = regler
	fjarr.n = n
	fjarr.jag = min_plats
	for s in spelare:
		fjarr.namn.append(s.namn)
	fjarr.poang = []
	for i in n:
		fjarr.poang.append(0)
	motor = fjarr
	visning["oppna"] = false
	tf = [1.35, 1.0, 0.55][clampi(int(visning.get("fart", 1)), 0, 2)]
	if fart_tvingad > 0.0:
		tf = 1.0 / fart_tvingad
	ljud.tyst = not visning.get("ljud", true)
	inmatning = ""
	valda = []
	hover_id = -1
	meny_lage = false
	betraktare = min_plats
	visad = true
	kam_vinkel = wrapf(kam_vinkel, -PI, PI)
	_kamera_till(betraktare, 1.4)
	_satt_upp_bord()
	if ogon != null:
		_bygg_ogonblick(ogon)
	await _kor_online(id)


func _kor_online(id: int) -> void:
	var senast_tur := -2
	while id == korning:
		if fjarr.har_mer():
			await _spela_upp(id)
			continue
		if fjarr.fas == Motor.Fas.SLUT:
			break
		if fjarr.min_tur():
			vantar_pa_drag = true
			await _tur(id)
			vantar_pa_drag = false
			continue
		if (fjarr.fas == Motor.Fas.BYTE or fjarr.fas == Motor.Fas.STICK) and fjarr.tur != senast_tur:
			senast_tur = fjarr.tur
			_visa_tur(fjarr.tur)
		await nat_nytt
	if id != korning:
		return
	online_kor = false
	_visa_slutskarm()


func _visa_slutskarm() -> void:
	tur_ring.visible = false
	var rader: Array = []
	for i in n:
		rader.append([spelare[i].namn, motor.poang[i], UI.SPELARFARG[i]])
	rader.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	ui.visa_slut(spelare[motor.vinnare].namn if motor.vinnare >= 0 else "Ingen", rader)


func _spela_igen() -> void:
	if online:
		if ar_varde:
			klient.skicka({"t": "starta"})
		else:
			ui.visa_banner("Väntar på värden", "Värden startar nästa parti", UI.KRAM, 1.5)


## Andra spelares kort kommer som -1. Välj en anonym kortnod, och se till att riktiga kort (egna och
## utspelade) finns där de ska genom att byta identitet med en anonym nod. Bara nedåtvända kort byts.
func _tolka_online(e: Dictionary) -> void:
	match e.typ:
		"giv":
			if e.kort < 0:
				e.kort = lek_vis.back()
			else:
				_hamta_till(e.kort, lek_vis)
		"byte":
			var p: int = e.spelare
			if p != min_plats:
				var sl: Array = []
				for i in e.slangda.size():
					sl.append(vhand[p][i])
				e.slangda = sl
				var ny: Array = []
				for i in e.nya.size():
					ny.append(lek_vis[lek_vis.size() - 1 - i])
				e.nya = ny
			else:
				for c in e.nya:
					_hamta_till(c, lek_vis)
		"spela":
			if e.spelare != min_plats:
				_hamta_till(e.kort, vhand[e.spelare])


func _hamta_till(c: int, lista: Array) -> void:
	if c in lista:
		return
	var egen: Array = vhand[min_plats] if min_plats < vhand.size() else []
	var x := -1
	for i in range(lista.size() - 1, -1, -1):
		var y: int = lista[i]
		if not y in egen and not y in stick_vis:
			x = y
			break
	if x < 0:
		return
	# hitta var kort c ligger nu (en annan hand, talongen eller slänghögen)
	var behallare: Array = []
	var behallare_index := -1
	for arr in vhand + [lek_vis, slang_vis]:
		var i: int = arr.find(c)
		if i >= 0:
			behallare = arr
			behallare_index = i
			break
	lista[lista.find(x)] = c
	if behallare_index >= 0:
		behallare[behallare_index] = x
	var tc: Transform3D = kort[c].transform
	kort[c].satt_direkt(kort[x].transform)
	kort[x].satt_direkt(tc)


## Återanslutning mitt i ett parti: bygg upp bordet direkt från serverns läge.
func _bygg_ogonblick(d: Dictionary) -> void:
	var s: Dictionary = d.s
	fjarr.ko.clear()
	fjarr.tillampa(s)
	var eg: Dictionary = s.egen
	vis_givare = s.givare
	vis_poang = s.poang.duplicate()
	_rensa_stick()
	for c in 52:
		kort[c].satt_glod(false)
		kort[c].satt_dimmad(false)
	var anv := {}
	vhand = []
	for i in n:
		vhand.append([])
		hogar[i] = 0
		bytes_info[i] = ""
		brickor[i] = "Chicago tagen" if i < fjarr.chicago_tagen.size() and fjarr.chicago_tagen[i] else ""
	vhand[min_plats] = K.sortera_hand(eg.hand)
	for c in eg.hand:
		anv[c] = true
	stick_vis = []
	stick_par = []
	for x in s.stick:
		stick_vis.append(x[1])
		stick_par.append([x[0], x[1]])
		anv[x[1]] = true
	var tagna: Array = d.get("tagna", [])
	for t in tagna:
		for c in t[1]:
			anv[c] = true
	var pool: Array = []
	for c in 52:
		if not anv.has(c):
			pool.append(c)
	for q in n:
		if q == min_plats:
			continue
		for i in int(eg.kvar[q]):
			vhand[q].append(pool.pop_back())
	slang_vis = []
	for i in int(s.slang):
		if not pool.is_empty():
			slang_vis.append(pool.pop_back())
	lek_vis = pool
	for k in lek_vis.size():
		kort[lek_vis[k]].satt_direkt(_lek_tf(k, vis_givare))
	for k in slang_vis.size():
		kort[slang_vis[k]].satt_direkt(_slang_tf(k))
	for i in stick_par.size():
		kort[stick_par[i][1]].satt_direkt(_stick_tf(stick_par[i][0], i))
	for t in tagna:
		var w: int = t[0]
		var k := 0
		for c in t[1]:
			kort[c].satt_direkt(_hog_tf(w, hogar[w], k))
			k += 1
		hogar[w] += 1
	_layout_alla(0.01)
	if not stick_par.is_empty():
		_markera_stick()
	givarknapp.visible = true
	givarknapp.transform = Transform3D(Basis(Vector3.UP, _vinkel(vis_givare)), _d(vis_givare) * 3.55 - _t(vis_givare) * 0.2)
	_tavla()
