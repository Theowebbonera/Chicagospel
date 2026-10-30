extends Node3D
## En tecknad figur som sitter vid bordet, byggd i kod från en beskrivning i figurer.gd:
## kroppsform, hudton, frisyr, ansikte, kläder och accessoarer (även robot, hund och katt).
## Andas, tittar mot den som har turen, gör en gest när den spelar ett kort, jublar vid poäng,
## gör 6-7 och reagerar på kast (blöt, tomat, tårta, snöboll, flygplan, hjärta, krona, konfetti).
## Lokal -Z pekar mot bordets mitt.

const Figurer := preload("res://scripts/figurer.gd")

var def := {}
var huvud: Node3D
var kropp: MeshInstance3D
var arm_v: Node3D
var arm_h: Node3D
var mun: MeshInstance3D
var tomatfleck: MeshInstance3D
var droppar: CPUParticles3D
var mat_troja: StandardMaterial3D
var mat_har: StandardMaterial3D
var mat_hud: StandardMaterial3D
var troj_farg: Color
var har_farg: Color
var blick_mal := Vector3.ZERO
var tid := 0.0
var blot := 0.0
var skak := 0.0
var hopp := 0.0
var glad := 0.0
var gest_t := -1.0
var fas := 0.0
var tomat_t := 0.0
var gradde_t := 0.0
var krona_t := 0.0
var rodnad := 0.0
var sexsju_t := 0.0
var gradde: Node3D
var krona: Node3D
var kinder: Array = []
var mat_kind: StandardMaterial3D
var bubbla: Label3D
var bas_yaw := 0.0
var bas_y := 0.0
var huvud_y := 2.98
var svans: Node3D


## Bakåtkompatibelt: figur nummer stil ur galleriet.
func bygg(_farg: Color, stil: int) -> void:
	bygg_figur(stil)


func bygg_figur(index: int) -> void:
	def = Figurer.FIGURER[posmod(index, Figurer.FIGURER.size())]
	fas = index * 1.7
	if def.has("modell"):
		_bygg_modell()
		return
	var special: String = def.get("special", "")
	# kroppsform: bredd, höjd, djup
	var form: Vector3 = {"smal": Vector3(0.95, 1.05, 0.72), "rund": Vector3(1.42, 0.95, 1.08), "lang": Vector3(1.05, 1.16, 0.8), "kort": Vector3(1.18, 0.86, 0.86)}.get(def.kropp, Vector3(1.18, 1.0, 0.82))
	var h := form.y
	huvud_y = 2.98 + (h - 1.0) * 2.4
	var axel_y := 2.0 + (h - 1.0) * 2.0
	troj_farg = def.farg
	har_farg = def.harfarg
	var hudfarg: Color = Figurer.HUD.get(def.hud, Figurer.HUD.ljus)
	if special == "robot":
		hudfarg = Color(0.7, 0.73, 0.78)
	elif special == "hund" or special == "katt":
		hudfarg = def.farg
	mat_hud = _mat(hudfarg, 0.7)
	if special == "robot":
		mat_hud.metallic = 0.7
		mat_hud.roughness = 0.3
	mat_har = _mat(har_farg, 0.6)
	mat_troja = _mat(troj_farg, 0.8)
	if special == "robot":
		mat_troja.metallic = 0.75
		mat_troja.roughness = 0.3
	# överkropp
	if special == "robot":
		var bm := BoxMesh.new()
		bm.size = Vector3(1.9, 2.6, 1.3)
		kropp = _del(bm, mat_troja, Vector3(0, 0.95, 0), self)
		kropp.scale = Vector3(form.x * 0.9, h, 0.9)
	else:
		kropp = _del(_kapsel(0.85, 2.9), mat_troja, Vector3(0, 0.85, 0), self)
		kropp.scale = Vector3(form.x * 1.0, h, form.z)
	_klader(def.klader, def.farg2, form, axel_y, special)
	if special != "robot":
		_del(_cylinder(0.26, 0.45), mat_hud, Vector3(0, axel_y + 0.35, 0), self)
	else:
		_del(_cylinder(0.18, 0.5), _mat(Color(0.3, 0.3, 0.34), 0.4), Vector3(0, axel_y + 0.35, 0), self)
	# huvud
	huvud = Node3D.new()
	huvud.position = Vector3(0, huvud_y, 0)
	add_child(huvud)
	match special:
		"robot":
			_robothuvud()
		"hund":
			_djurhuvud(true)
		"katt":
			_djurhuvud(false)
		_:
			_manniskohuvud()
	tomatfleck = _del(_klot(0.26), _mat(Color(0.85, 0.1, 0.06), 0.3), Vector3(0.1, 0.1, -0.62), huvud)
	tomatfleck.scale = Vector3(1.3, 1.0, 0.35)
	tomatfleck.visible = false
	_gradde_och_krona()
	for a in def.acc:
		_accessoar(a)
	# armar som vilar på bordskanten
	var bred := 0.85 * form.x + 0.12
	arm_v = _arm(Vector3(-bred, axel_y, 0.0))
	arm_h = _arm(Vector3(bred, axel_y, 0.0))
	_droppar_och_ljus()


# ------------------------------------------------------------------ huvuden
func _manniskohuvud() -> void:
	_del(_klot(0.64), mat_hud, Vector3.ZERO, huvud)
	_del(_klot(0.14), mat_hud, Vector3(0.62, -0.05, 0.02), huvud)
	_del(_klot(0.14), mat_hud, Vector3(-0.62, -0.05, 0.02), huvud)
	_frisyr(def.har)
	_ogon(def.ogon)
	_bryn(def.bryn)
	_del(_klot(0.1), _mat(mat_hud.albedo_color.darkened(0.12), 0.7), Vector3(0, -0.07, -0.64), huvud)
	_kinder(Vector3(0.36, -0.14, -0.5))
	_mun(def.mun, -0.3, -0.57)


func _robothuvud() -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(1.15, 0.95, 1.0)
	_del(bm, mat_hud, Vector3.ZERO, huvud)
	# antenn med lampa
	_del(_cylinder(0.03, 0.45), _mat(Color(0.3, 0.3, 0.34), 0.4), Vector3(0, 0.7, 0), huvud)
	var lampa := _mat(Color(1.0, 0.25, 0.2), 0.3)
	lampa.emission_enabled = true
	lampa.emission = Color(1.0, 0.2, 0.15)
	lampa.emission_energy_multiplier = 2.5
	_del(_klot(0.09), lampa, Vector3(0, 0.95, 0), huvud)
	# öron (bultar)
	for sx in [-1.0, 1.0]:
		var b := _del(_cylinder(0.14, 0.12), _mat(Color(0.35, 0.36, 0.4), 0.3), Vector3(0.62 * sx, 0, 0), huvud)
		b.rotation.z = PI / 2
	_ogon("led")
	_kinder(Vector3(0.36, -0.2, -0.51))
	_mun("galler", -0.25, -0.51)


func _djurhuvud(hund: bool) -> void:
	var p: Color = def.farg
	var ljus := p.lightened(0.35)
	_del(_klot(0.62), mat_hud, Vector3.ZERO, huvud)
	# nos
	var nos := _del(_klot(0.34 if hund else 0.24), _mat(ljus, 0.7), Vector3(0, -0.18, -0.5), huvud)
	nos.scale = Vector3(1.0, 0.8, 1.1 if hund else 0.8)
	_del(_klot(0.11 if hund else 0.07), _mat(Color(0.08, 0.06, 0.06) if hund else Color(0.95, 0.5, 0.6), 0.2), Vector3(0, -0.07, -0.86 if hund else -0.7), huvud)
	if hund:
		# hängande öron
		for sx in [-1.0, 1.0]:
			var ora := _del(_klot(0.3), _mat(p.darkened(0.35), 0.7), Vector3(0.58 * sx, -0.08, 0.05), huvud)
			ora.scale = Vector3(0.45, 1.25, 0.8)
			ora.rotation.z = 0.25 * sx
		# halsband
		var hb := _del(_cylinder(0.33, 0.12), _mat(def.farg2, 0.4), Vector3(0, -0.62, 0), huvud)
		_del(_klot(0.08), _mat(Color(1.0, 0.8, 0.2), 0.2), Vector3(0, -0.66, -0.34), huvud)
	else:
		# spetsiga öron och morrhår
		for sx in [-1.0, 1.0]:
			var kon := CylinderMesh.new()
			kon.top_radius = 0.0
			kon.bottom_radius = 0.22
			kon.height = 0.42
			var o := _del(kon, mat_hud, Vector3(0.36 * sx, 0.55, 0.0), huvud)
			o.rotation.z = -0.35 * sx
			var inre := CylinderMesh.new()
			inre.top_radius = 0.0
			inre.bottom_radius = 0.12
			inre.height = 0.26
			var oi := _del(inre, _mat(Color(0.95, 0.6, 0.65), 0.7), Vector3(0.36 * sx, 0.52, -0.08), huvud)
			oi.rotation.z = -0.35 * sx
			for k in 3:
				var m := _del(_cylinder(0.008, 0.55), _mat(Color(0.95, 0.95, 0.95), 0.5), Vector3(0.32 * sx, -0.16 + k * 0.05, -0.62), huvud)
				m.rotation = Vector3(0, 0, PI / 2 + (k - 1) * 0.15 * sx)
		# svans bakom stolen
		svans = Node3D.new()
		svans.position = Vector3(0, 0.3, 0.75)
		add_child(svans)
		var sv := _del(_kapsel(0.1, 1.4), mat_hud, Vector3(0, 0.6, 0.1), svans)
		sv.rotation.x = 0.4
	_ogon(def.ogon)
	_kinder(Vector3(0.34, -0.12, -0.5))
	_mun("le", -0.36, -0.58 if not hund else -0.66)


# ------------------------------------------------------------------ ansikte
func _ogon(typ: String) -> void:
	var vit := _mat(Color(0.98, 0.98, 0.98), 0.3)
	var svart := _mat(Color(0.05, 0.05, 0.07), 0.2)
	for sx in [-1.0, 1.0]:
		match typ:
			"glada":
				var o := _del(_kapsel(0.045, 0.24), svart, Vector3(0.22 * sx, 0.08, -0.6), huvud)
				o.rotation.z = PI / 2
				o.scale = Vector3(1, 1, 1)
			"sovande":
				var o2 := _del(_klot(0.13), vit, Vector3(0.22 * sx, 0.06, -0.53), huvud)
				o2.scale = Vector3(1.0, 1.0, 0.6)
				_del(_klot(0.07), svart, Vector3(0.22 * sx, 0.04, -0.62), huvud)
				var lock := _del(_klot(0.145), mat_hud, Vector3(0.22 * sx, 0.12, -0.53), huvud)
				lock.scale = Vector3(1.05, 0.6, 0.65)
			"stora":
				var o3 := _del(_klot(0.18), vit, Vector3(0.24 * sx, 0.1, -0.5), huvud)
				o3.scale = Vector3(1.0, 1.2, 0.6)
				_del(_klot(0.09), svart, Vector3(0.24 * sx, 0.08, -0.6), huvud)
				_del(_klot(0.03), vit, Vector3(0.21 * sx, 0.13, -0.65), huvud)
			"led":
				var led := _mat(def.farg2, 0.2)
				led.emission_enabled = true
				led.emission = def.farg2
				led.emission_energy_multiplier = 3.0
				var bm := BoxMesh.new()
				bm.size = Vector3(0.24, 0.14, 0.05)
				_del(bm, led, Vector3(0.25 * sx, 0.12, -0.51), huvud)
			"katt":
				var o4 := _del(_klot(0.15), _mat(Color(0.75, 0.85, 0.25), 0.3), Vector3(0.22 * sx, 0.1, -0.5), huvud)
				o4.scale = Vector3(1.0, 1.1, 0.6)
				var pup := _del(_klot(0.07), svart, Vector3(0.22 * sx, 0.1, -0.59), huvud)
				pup.scale = Vector3(0.45, 1.3, 1.0)
			_:
				var o5 := _del(_klot(0.14), vit, Vector3(0.22 * sx, 0.08, -0.53), huvud)
				o5.scale = Vector3(1.0, 1.15, 0.6)
				_del(_klot(0.075), svart, Vector3(0.22 * sx, 0.07, -0.62), huvud)


func _bryn(typ: String) -> void:
	if typ == "ingen":
		return
	var tjock := 0.055 if typ == "tjocka" else 0.035
	for sx in [-1.0, 1.0]:
		var vinkel: float = PI / 2 + 0.15 * sx
		if typ == "arga":
			vinkel = PI / 2 - 0.35 * sx
		var b := _del(_kapsel(tjock, 0.28), mat_har, Vector3(0.22 * sx, 0.27, -0.56), huvud)
		b.rotation = Vector3(0, 0, vinkel)


func _mun(typ: String, y: float, z: float) -> void:
	var m := _mat(Color(0.45, 0.12, 0.12), 0.5)
	match typ:
		"o":
			mun = _del(_klot(0.07), m, Vector3(0, y, z), huvud)
			mun.scale = Vector3(1, 1.2, 0.5)
		"galler":
			var g := _mat(Color(0.15, 0.15, 0.18), 0.4)
			var bm := BoxMesh.new()
			bm.size = Vector3(0.45, 0.12, 0.04)
			mun = _del(bm, g, Vector3(0, y, z), huvud)
		_:
			mun = _del(_kapsel(0.045, 0.34 if typ == "le" else 0.24), m, Vector3(0, y, z), huvud)
			mun.rotation.z = PI / 2


func _kinder(p: Vector3) -> void:
	mat_kind = _mat(Color(1.0, 0.55, 0.55, 1.0), 0.8)
	for sx in [-1.0, 1.0]:
		var kind := _del(_klot(0.1), mat_kind, Vector3(p.x * sx, p.y, p.z), huvud)
		kind.scale = Vector3(1, 0.6, 0.4)
		kinder.append(kind)


func _frisyr(typ: String) -> void:
	match typ:
		"ingen":
			return
		"flint":
			for sx in [-1.0, 1.0]:
				var t := _del(_klot(0.22), mat_har, Vector3(0.52 * sx, 0.05, 0.12), huvud)
				t.scale = Vector3(0.6, 0.8, 1.0)
			return
		"lockigt":
			for k in 16:
				var a := TAU * k / 16.0
				_del(_klot(0.2), mat_har, Vector3(cos(a) * 0.5, 0.36 + 0.08 * sin(a * 3.0), sin(a) * 0.45 + 0.08), huvud)
			_del(_klot(0.42), mat_har, Vector3(0, 0.45, 0.08), huvud)
			return
	var har := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.68
	hs.height = 0.68
	hs.is_hemisphere = true
	har.mesh = hs
	har.material_override = mat_har
	har.position = Vector3(0, 0.06, 0.07)
	har.rotation.x = 0.35
	huvud.add_child(har)
	match typ:
		"lang":
			var bak := _del(_kapsel(0.5, 1.7), mat_har, Vector3(0, -0.45, 0.28), huvud)
			bak.scale = Vector3(1.25, 1.0, 0.6)
		"tofs":
			_del(_klot(0.26), mat_har, Vector3(0, 0.62, 0.32), huvud)


# ------------------------------------------------------------------ kläder
func _klader(typ: String, farg2: Color, form: Vector3, axel_y: float, special: String) -> void:
	var h := form.y
	var fram := -0.7 * form.z / 0.82
	match typ:
		"troja":
			var krage := _del(_klot(0.42), _mat(troj_farg.lightened(0.5), 0.7), Vector3(0, axel_y + 0.2, fram * 0.6), self)
			krage.scale = Vector3(1.2, 0.45, 0.6)
		"kavaj", "kockrock", "vast":
			# skjorta och slag
			var skjorta := BoxMesh.new()
			skjorta.size = Vector3(0.5, 1.5 * h, 0.05)
			_del(skjorta, _mat(Color(0.96, 0.96, 0.94), 0.6), Vector3(0, axel_y - 0.55, fram - 0.02), self)
			if typ == "kavaj":
				var slips := BoxMesh.new()
				slips.size = Vector3(0.14, 1.0 * h, 0.04)
				_del(slips, _mat(farg2, 0.5), Vector3(0, axel_y - 0.55, fram - 0.06), self)
				for sx in [-1.0, 1.0]:
					var slag := BoxMesh.new()
					slag.size = Vector3(0.18, 1.1 * h, 0.05)
					var s := _del(slag, _mat(troj_farg.darkened(0.25), 0.6), Vector3(0.28 * sx, axel_y - 0.5, fram - 0.03), self)
					s.rotation.z = 0.28 * sx
			elif typ == "kockrock":
				for k in 4:
					for sx in [-1.0, 1.0]:
						_del(_klot(0.06), _mat(Color(0.2, 0.2, 0.22), 0.4), Vector3(0.22 * sx, axel_y - 0.25 - k * 0.32, fram - 0.04), self)
				var sjal := _del(_cylinder(0.32, 0.14), _mat(farg2, 0.5), Vector3(0, axel_y + 0.22, 0), self)
			else:
				# väst över ljus skjorta: ärmarna blir skjortfärg
				mat_troja = _mat(farg2, 0.8)
				troj_farg = farg2
				kropp.material_override = _mat(def.farg, 0.8)
				var stjarna := _del(_klot(0.1), _mat(Color(0.95, 0.8, 0.2), 0.2), Vector3(-0.35, axel_y - 0.35, fram - 0.03), self)
				stjarna.scale = Vector3(1, 1, 0.3)
		"hoodie":
			var luva := _del(_klot(0.6), _mat(troj_farg.darkened(0.1), 0.8), Vector3(0, axel_y + 0.25, 0.4), self)
			luva.scale = Vector3(1.4, 0.7, 0.8)
			var ficka := BoxMesh.new()
			ficka.size = Vector3(1.0, 0.45, 0.05)
			_del(ficka, _mat(troj_farg.darkened(0.15), 0.8), Vector3(0, axel_y - 1.35 * h, fram - 0.02), self)
			for sx in [-1.0, 1.0]:
				_del(_cylinder(0.02, 0.5), _mat(farg2, 0.5), Vector3(0.14 * sx, axel_y - 0.1, fram - 0.04), self)
		"randig":
			for k in 5:
				var t := TorusMesh.new()
				t.inner_radius = 0.82
				t.outer_radius = 0.9
				var r := _del(t, _mat(farg2, 0.8), Vector3(0, axel_y - 0.15 - k * 0.36 * h, 0), self)
				r.scale = Vector3(form.x * 1.02, 1.6, form.z * 1.05)
		"metall":
			var panel := BoxMesh.new()
			panel.size = Vector3(0.9, 0.7, 0.05)
			_del(panel, _mat(Color(0.2, 0.22, 0.26), 0.3), Vector3(0, axel_y - 0.7, -0.62), self)
			for k in 3:
				var l := _mat([Color(1, 0.2, 0.2), Color(0.2, 1, 0.3), Color(1, 0.85, 0.2)][k], 0.2)
				l.emission_enabled = true
				l.emission = l.albedo_color
				l.emission_energy_multiplier = 2.0
				_del(_klot(0.06), l, Vector3(-0.25 + k * 0.25, axel_y - 0.6, -0.66), self)
		"pals":
			var mage := _del(_klot(0.7), _mat(def.farg.lightened(0.35), 0.8), Vector3(0, axel_y - 0.9, fram * 0.75), self)
			mage.scale = Vector3(0.9, 1.1, 0.4)


# ------------------------------------------------------------------ accessoarer
func _accessoar(a: String) -> void:
	var svart := _mat(Color(0.1, 0.1, 0.12), 0.4)
	match a:
		"glasogon", "solglasogon":
			for sx in [-1.0, 1.0]:
				var t := TorusMesh.new()
				t.inner_radius = 0.12
				t.outer_radius = 0.16
				var g := _del(t, svart, Vector3(0.22 * sx, 0.08, -0.62), huvud)
				g.rotation.x = PI / 2
				if a == "solglasogon":
					var lins := _del(_cylinder(0.13, 0.02), _mat(Color(0.05, 0.05, 0.08), 0.1), Vector3(0.22 * sx, 0.08, -0.63), huvud)
					lins.rotation.x = PI / 2
			_del(_cylinder(0.015, 0.14), svart, Vector3(0, 0.1, -0.63), huvud).rotation.z = PI / 2
		"hatt":
			var b := _del(_cylinder(0.85, 0.06), svart, Vector3(0, 0.5, 0.05), huvud)
			b.rotation.x = 0.15
			var k := _del(_cylinder(0.5, 0.55), svart, Vector3(0, 0.78, 0.09), huvud)
			k.rotation.x = 0.15
			var band := _del(_cylinder(0.51, 0.12), _mat(def.farg2, 0.5), Vector3(0, 0.6, 0.065), huvud)
			band.rotation.x = 0.15
		"keps":
			var c := _del(_klot(0.68), _mat(def.farg2, 0.6), Vector3(0, 0.15, 0.03), huvud)
			c.scale = Vector3(1.0, 0.6, 1.0)
			var sk := _del(_cylinder(0.42, 0.05), _mat(def.farg2, 0.6), Vector3(0, 0.22, -0.55), huvud)
			sk.scale = Vector3(1.0, 1.0, 0.8)
		"mossa":
			var m := _del(_klot(0.69), _mat(def.farg2.lerp(Color(0.85, 0.2, 0.2), 0.6), 0.9), Vector3(0, 0.2, 0.05), huvud)
			m.scale = Vector3(1.0, 0.72, 1.0)
			_del(_cylinder(0.66, 0.16), _mat(Color(0.95, 0.95, 0.95), 0.9), Vector3(0, 0.08, 0.04), huvud)
			_del(_klot(0.18), _mat(Color(0.98, 0.98, 0.98), 0.9), Vector3(0, 0.72, 0.05), huvud)
		"skagg":
			var s := _del(_klot(0.4), mat_har, Vector3(0, -0.38, -0.4), huvud)
			s.scale = Vector3(1.1, 0.8, 0.6)
			mun.position.z = -0.72
		"mustasch":
			for sx in [-1.0, 1.0]:
				var mu := _del(_klot(0.12), mat_har, Vector3(0.12 * sx, -0.19, -0.64), huvud)
				mu.scale = Vector3(1.5, 0.55, 0.6)
				mu.rotation.z = -0.25 * sx
		"horlurar":
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.66
			t2.outer_radius = 0.74
			var bage := _del(t2, svart, Vector3(0, 0.05, 0.02), huvud)
			bage.rotation.z = PI / 2
			bage.scale = Vector3(1.0, 1.0, 0.5)
			for sx in [-1.0, 1.0]:
				var kopp := _del(_cylinder(0.2, 0.14), _mat(def.farg2.lerp(Color(0.9, 0.2, 0.3), 0.5), 0.4), Vector3(0.68 * sx, -0.05, 0.02), huvud)
				kopp.rotation.z = PI / 2
		"fluga":
			for sx in [-1.0, 1.0]:
				var f := _del(_klot(0.16), _mat(def.farg2, 0.5), Vector3(0.15 * sx, -0.75, -0.62), huvud)
				f.scale = Vector3(1.2, 0.8, 0.5)
		"krona":
			var guld := _mat(Color(1.0, 0.78, 0.2), 0.25)
			guld.metallic = 0.8
			var kr := Node3D.new()
			kr.position = Vector3(0, 0.58, 0.05)
			huvud.add_child(kr)
			_del(_cylinder(0.4, 0.16), guld, Vector3.ZERO, kr)
			for k in 5:
				var a2 := TAU * k / 5.0
				var spets := CylinderMesh.new()
				spets.top_radius = 0.0
				spets.bottom_radius = 0.09
				spets.height = 0.24
				_del(spets, guld, Vector3(cos(a2) * 0.34, 0.18, sin(a2) * 0.34), kr)
		"piratlapp":
			var lapp := _del(_cylinder(0.15, 0.03), svart, Vector3(0.22, 0.08, -0.64), huvud)
			lapp.rotation.x = PI / 2
			var rem := TorusMesh.new()
			rem.inner_radius = 0.64
			rem.outer_radius = 0.67
			var r := _del(rem, svart, Vector3(0, 0.15, 0), huvud)
			r.rotation = Vector3(0, 0, 0.4)
		"piratt":
			var p := _del(_klot(0.75), svart, Vector3(0, 0.42, 0.05), huvud)
			p.scale = Vector3(1.25, 0.45, 1.0)
			_del(_klot(0.12), _mat(Color(0.95, 0.95, 0.95), 0.4), Vector3(0, 0.55, -0.62), huvud)
		"kockmossa":
			_del(_cylinder(0.55, 0.5), _mat(Color(0.98, 0.98, 0.98), 0.8), Vector3(0, 0.62, 0.05), huvud)
			var puff := _del(_klot(0.62), _mat(Color(0.98, 0.98, 0.98), 0.9), Vector3(0, 1.0, 0.05), huvud)
			puff.scale = Vector3(1.05, 0.7, 1.05)
		"cowboyhatt":
			var brun := _mat(Color(0.45, 0.28, 0.12), 0.7)
			var bratte := _del(_cylinder(1.0, 0.05), brun, Vector3(0, 0.48, 0.05), huvud)
			bratte.scale = Vector3(1.0, 1.0, 0.8)
			var topp := _del(_cylinder(0.48, 0.5), brun, Vector3(0, 0.72, 0.06), huvud)
			_del(_cylinder(0.49, 0.1), _mat(Color(0.15, 0.1, 0.06), 0.6), Vector3(0, 0.55, 0.06), huvud)


func _gradde_och_krona() -> void:
	gradde = Node3D.new()
	huvud.add_child(gradde)
	var vit_gradde := _mat(Color(0.99, 0.97, 0.92), 0.35)
	for k in 9:
		var a := TAU * k / 9.0
		var g := _del(_klot(0.2 + 0.06 * (k % 3)), vit_gradde, Vector3(cos(a) * 0.32, sin(a) * 0.3 - 0.02, -0.55 + 0.05 * (k % 2)), gradde)
		g.scale = Vector3(1.0, 0.85, 0.55)
	_del(_klot(0.32), vit_gradde, Vector3(0, 0, -0.62), gradde).scale = Vector3(1.1, 1.0, 0.45)
	_del(_klot(0.08), _mat(Color(0.8, 0.05, 0.1), 0.3), Vector3(0.05, 0.12, -0.78), gradde)
	gradde.visible = false
	krona = Node3D.new()
	krona.position = Vector3(0, 0.66, 0.05)
	huvud.add_child(krona)
	var guld := _mat(Color(1.0, 0.78, 0.2), 0.25)
	guld.metallic = 0.8
	_del(_cylinder(0.42, 0.18), guld, Vector3.ZERO, krona)
	for k in 6:
		var a := TAU * k / 6.0
		var spets := CylinderMesh.new()
		spets.top_radius = 0.0
		spets.bottom_radius = 0.09
		spets.height = 0.26
		_del(spets, guld, Vector3(cos(a) * 0.36, 0.2, sin(a) * 0.36), krona)
		_del(_klot(0.05), _mat([Color(0.9, 0.1, 0.15), Color(0.15, 0.4, 0.95), Color(0.1, 0.7, 0.3)][k % 3], 0.2), Vector3(cos(a) * 0.36, 0.34, sin(a) * 0.36), krona)
	krona.visible = false
	bubbla = Label3D.new()
	bubbla.text = "6-7"
	bubbla.font_size = 170
	bubbla.pixel_size = 0.01
	bubbla.outline_size = 30
	bubbla.modulate = Color(0.12, 0.1, 0.15)
	bubbla.outline_modulate = Color(1, 1, 1)
	bubbla.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubbla.position = Vector3(0, huvud_y + 1.35, 0)
	bubbla.no_depth_test = true
	bubbla.visible = false
	add_child(bubbla)


func _droppar_och_ljus() -> void:
	droppar = CPUParticles3D.new()
	droppar.emitting = false
	droppar.amount = 24
	droppar.lifetime = 0.8
	droppar.position = Vector3(0, huvud_y - 0.1, -0.2)
	droppar.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	droppar.emission_sphere_radius = 0.55
	droppar.gravity = Vector3(0, -9.0, 0)
	droppar.initial_velocity_min = 0.2
	droppar.initial_velocity_max = 0.8
	var dm := SphereMesh.new()
	dm.radius = 0.045
	dm.height = 0.12
	droppar.mesh = dm
	var dmat := _mat(Color(0.55, 0.8, 1.0), 0.05)
	dmat.metallic_specular = 0.9
	droppar.material_override = dmat
	add_child(droppar)
	var ljus := OmniLight3D.new()
	ljus.position = Vector3(0, huvud_y + 1.6, -2.6)
	ljus.omni_range = 6.5
	ljus.light_energy = 0.9
	ljus.light_color = Color(1.0, 0.88, 0.74)
	add_child(ljus)


func _arm(axel: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = axel
	add_child(pivot)
	var langd := 1.55
	_del(_kapsel(0.27, langd), mat_troja, Vector3(0, -langd * 0.5, 0), pivot)
	var special: String = def.get("special", "")
	if special == "hund" or special == "katt":
		_del(_klot(0.27), _mat(def.farg.lightened(0.35), 0.8), Vector3(0, -langd + 0.05, 0), pivot)
	else:
		_del(_klot(0.25), mat_hud, Vector3(0, -langd + 0.05, 0), pivot)
	pivot.rotation = Vector3(0.85, 0, 0.2 * signf(axel.x))
	pivot.set_meta("vila", pivot.rotation)
	return pivot


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.4
	return m


func _klot(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


func _kapsel(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	return c


func _cylinder(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


func _del(m: Mesh, mat: Material, pos: Vector3, foralder: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	foralder.add_child(mi)
	return mi


# ------------------------------------------------------------------ beteende
func titta_pa(punkt: Vector3) -> void:
	blick_mal = punkt


func gest() -> void:
	gest_t = 0.0


func jubel(stor := false) -> void:
	hopp = 1.0 if stor else 0.6
	glad = 1.0


func ledsen() -> void:
	skak = 0.8


## 6-7: båda handflatorna uppåt och händerna gungar upp och ned i otakt, med en pratbubbla.
func sexsju() -> void:
	sexsju_t = 2.4
	bubbla.visible = true


## typ: vattenballong, tomat, tarta, snoboll, flygplan, ros, hjarta, krona, konfetti
func traffad(typ: String) -> void:
	match typ:
		"vattenballong":
			blot = 1.0
			skak = 1.0
		"tomat":
			tomat_t = 5.0
			tomatfleck.visible = true
			skak = 0.7
		"tarta":
			gradde_t = 5.0
			gradde.visible = true
			skak = 0.5
		"snoboll":
			skak = 1.0
		"flygplan":
			skak = 0.4
			gest_t = 0.0
		"hjarta":
			rodnad = 1.0
			glad = 1.0
		"krona":
			krona_t = 8.0
			krona.visible = true
			glad = 1.0
			hopp = 0.5
		"konfetti":
			glad = 1.0
			hopp = 1.0
		"ros":
			glad = 1.0
			hopp = 0.8


func traff_avstand(fran: Vector3, rikt: Vector3) -> float:
	if not visible:
		return -1.0
	var bast := -1.0
	for c in [[huvud.global_position, 0.95], [global_position + global_basis.y * 1.4, 1.25]]:
		var mitt: Vector3 = c[0]
		var r: float = c[1]
		var t := (mitt - fran).dot(rikt)
		if t < 0.0:
			continue
		var d := (fran + rikt * t).distance_to(mitt)
		if d <= r and (bast < 0.0 or t < bast):
			bast = t
	return bast


func huvudpos() -> Vector3:
	return huvud.global_position


func _process(dt: float) -> void:
	tid += dt
	if skelett:
		_process_modell(dt)
		return
	# andning
	var andas := sin(tid * 1.6 + fas)
	kropp.position.y = (0.95 if def.get("special", "") == "robot" else 0.85) + 0.02 * andas
	huvud.position.y = huvud_y + 0.03 * andas
	if svans:
		svans.rotation.z = sin(tid * 2.2 + fas) * 0.35
	# blick: vrid huvudet mot målet (begränsat)
	var lokal := to_local(blick_mal) - huvud.position
	var yaw := 0.0
	var pitch := 0.0
	if lokal.length() > 0.1:
		yaw = clampf(atan2(-lokal.x, -lokal.z), -1.0, 1.0)
		pitch = clampf(atan2(lokal.y, Vector2(lokal.x, lokal.z).length()), -0.5, 0.3)
	bas_yaw = lerp_angle(bas_yaw, yaw, minf(dt * 4.0, 1.0))
	huvud.rotation.y = bas_yaw + sin(tid * 26.0) * 0.4 * skak
	huvud.rotation.x = lerpf(huvud.rotation.x, pitch, minf(dt * 4.0, 1.0))
	skak = maxf(skak - dt * 0.9, 0.0)
	# hopp/jubel
	position.y = bas_y + absf(sin(tid * 9.0)) * 0.35 * hopp
	hopp = maxf(hopp - dt * 0.7, 0.0)
	glad = maxf(glad - dt * 0.4, 0.0)
	mun.scale = Vector3(1.0 + glad * 0.8, 1.0 + glad * 0.6, 1.0)
	# armar: vila, gest med höger arm, båda upp vid jubel
	var vh: Vector3 = arm_h.get_meta("vila")
	var vv: Vector3 = arm_v.get_meta("vila")
	var upp := hopp
	var gestv := 0.0
	if gest_t >= 0.0:
		gest_t += dt
		gestv = sin(clampf(gest_t / 0.6, 0.0, 1.0) * PI)
		if gest_t > 0.6:
			gest_t = -1.0
	arm_h.rotation = vh.lerp(Vector3(1.85, 0.0, vh.z), maxf(gestv, upp))
	arm_v.rotation = vv.lerp(Vector3(2.6, 0.0, vv.z - 0.35), upp)
	if upp > 0.01:
		arm_h.rotation = arm_h.rotation.lerp(Vector3(2.6, 0.0, vh.z + 0.35), upp)
	# blöt: mörkare, blåare tröja och hår, droppar
	if blot > 0.0:
		blot = maxf(blot - dt * 0.16, 0.0)
		mat_troja.albedo_color = troj_farg.lerp(troj_farg.darkened(0.4).lerp(Color(0.2, 0.35, 0.6), 0.3), blot)
		mat_troja.roughness = lerpf(0.8, 0.25, blot)
		mat_har.albedo_color = har_farg.lerp(har_farg.darkened(0.45), blot)
		mat_har.roughness = lerpf(0.6, 0.15, blot)
	droppar.emitting = blot > 0.15
	if tomat_t > 0.0:
		tomat_t -= dt
		if tomat_t <= 0.0:
			tomatfleck.visible = false
	if gradde_t > 0.0:
		gradde_t -= dt
		# torkar sig i ansiktet den sista sekunden
		if gradde_t < 1.0:
			arm_h.rotation = arm_h.rotation.lerp(Vector3(2.2, 0.0, -0.5), 0.8)
			gradde.scale = Vector3.ONE * maxf(gradde_t, 0.05)
		if gradde_t <= 0.0:
			gradde.visible = false
			gradde.scale = Vector3.ONE
	if krona_t > 0.0:
		krona_t -= dt
		krona.position.y = 0.66 + 0.03 * sin(tid * 3.0)
		if krona_t <= 0.0:
			krona.visible = false
	if rodnad > 0.0:
		rodnad = maxf(rodnad - dt * 0.25, 0.0)
		mat_kind.albedo_color = Color(1.0, 0.55, 0.55).lerp(Color(0.95, 0.15, 0.2), rodnad)
		for k in kinder:
			k.scale = Vector3(1.0 + rodnad * 0.8, 0.6 + rodnad * 0.4, 0.4)
	if sexsju_t > 0.0:
		sexsju_t -= dt
		var v := sin(tid * 13.0) * 0.38
		arm_h.rotation = Vector3(1.55 + v, 0.0, -0.25)
		arm_v.rotation = Vector3(1.55 - v, 0.0, 0.25)
		bubbla.scale = Vector3.ONE * (1.0 + 0.08 * sin(tid * 13.0))
		if sexsju_t <= 0.0:
			bubbla.visible = false


# ================================================================== realistiska figurer (modell)
## En människa från Blender (assets/gubbar/*.glb, blender/gubbar.py). Vilan i skelettet är sittande, framsidan mot +Z
## och måtten i meter. Modellen skalas så att huvud och axlar hamnar där de tecknade figurernas gör, och vänds mot -Z.
## Ett osynligt huvud följer huvudbenet, så att kast, grädde, krona och droppar hamnar rätt. Blick, skakning,
## gest, jubel och 6-7 görs genom att vrida nacke, huvud och armar i skelettet.
const MODELL_SKALA := 4.2  # meter -> figurens enheter (huvudet där de tecknades sitter, lite större kroppar)
const HUVUD_MITT := 0.1  # huvudets mitt ovanför huvudbenets början (m)
var skelett: Skeleton3D
var modell: Node3D
var ben := {}
var vila := {}
var nick := 0.0


func _bygg_modell() -> void:
	var scen: PackedScene = load(def.modell)
	modell = scen.instantiate()
	add_child(modell)
	modell.rotation.y = PI
	modell.scale = Vector3.ONE * MODELL_SKALA
	skelett = modell.find_children("*", "Skeleton3D", true, false)[0]
	for b in ["spine_03", "neck_01", "head", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]:
		var i := skelett.find_bone(b)
		ben[b] = i
		vila[b] = skelett.get_bone_global_rest(i)
	# huvudets höjd: som de tecknade figurerna
	var huvud_m: Vector3 = vila.head.origin + Vector3(0, HUVUD_MITT, 0)
	huvud_y = 2.98
	modell.position.y = huvud_y - huvud_m.y * MODELL_SKALA
	# osynligt huvud på huvudbenet: de tecknade figurernas effekter (huvudradie ~0.62) krympta till ett riktigt huvud
	var faste := BoneAttachment3D.new()
	faste.bone_name = "head"
	skelett.add_child(faste)
	huvud = Node3D.new()
	huvud.position = Vector3(0, HUVUD_MITT, 0.0)
	# figurens -Z (framåt) är modellens +Z: huvudet vänds så att effekterna hamnar framför ansiktet
	huvud.rotation.y = PI
	huvud.scale = Vector3.ONE * (0.11 / 0.62)
	faste.add_child(huvud)
	tomatfleck = _del(_klot(0.26), _mat(Color(0.85, 0.1, 0.06), 0.3), Vector3(0.1, 0.1, -0.62), huvud)
	tomatfleck.scale = Vector3(1.3, 1.0, 0.35)
	tomatfleck.visible = false
	_gradde_och_krona()
	_droppar_och_ljus()
	mat_troja = _mat(def.farg, 0.8)
	troj_farg = def.farg


## Vrider ett ben i skelettets rum: globalt läge = q * vila, räknat mot förälderns (nya) globala läge.
func _vrid(namn: String, q: Basis, foralder_global: Basis) -> Basis:
	var ny: Basis = q * vila[namn].basis
	skelett.set_bone_pose_rotation(ben[namn], (foralder_global.inverse() * ny).get_rotation_quaternion())
	return ny


func _foralder_vila(namn: String) -> Basis:
	return skelett.get_bone_global_rest(skelett.get_bone_parent(ben[namn])).basis


func _process_modell(dt: float) -> void:
	var andas := sin(tid * 1.6 + fas)
	# blick som hos de tecknade, räknat i figurens rum (-Z framåt). I modellens rum (vänd ett halvt varv)
	# blir vridningen kring Y densamma och nickningen kring X omvänd.
	var lokal := to_local(blick_mal) - Vector3(0, huvud_y, 0)
	var yaw := 0.0
	var pitch := 0.0
	if lokal.length() > 0.1:
		yaw = clampf(atan2(-lokal.x, -lokal.z), -1.0, 1.0)
		pitch = clampf(atan2(lokal.y, Vector2(lokal.x, lokal.z).length()), -0.5, 0.3)
	bas_yaw = lerp_angle(bas_yaw, yaw, minf(dt * 4.0, 1.0))
	nick = lerpf(nick, pitch, minf(dt * 4.0, 1.0))
	var vrid_y := bas_yaw + sin(tid * 26.0) * 0.35 * skak
	skak = maxf(skak - dt * 0.9, 0.0)
	# andning: bröstet höjs lite
	var brost := _vrid("spine_03", Basis(Vector3.RIGHT, 0.015 * andas), _foralder_vila("spine_03"))
	var halv := Basis(Vector3.UP, vrid_y * 0.4) * Basis(Vector3.RIGHT, -nick * 0.4)
	var hel := Basis(Vector3.UP, vrid_y) * Basis(Vector3.RIGHT, -nick)
	var nacke := _vrid("neck_01", halv, brost)
	_vrid("head", hel, nacke)
	# hopp/jubel
	position.y = bas_y + absf(sin(tid * 9.0)) * 0.35 * hopp
	hopp = maxf(hopp - dt * 0.7, 0.0)
	glad = maxf(glad - dt * 0.4, 0.0)
	# armar: gest med höger arm, båda upp vid jubel, 6-7 med handflatorna upp
	var gestv := 0.0
	if gest_t >= 0.0:
		gest_t += dt
		gestv = sin(clampf(gest_t / 0.6, 0.0, 1.0) * PI)
		if gest_t > 0.6:
			gest_t = -1.0
	var upp := hopp
	for s in [["r", -1.0], ["l", 1.0]]:
		var sida: String = s[0]
		var sx: float = s[1]
		# överarmen svingas framåt och upp kring sidledsaxeln (negativ vinkel = framåt/upp), ut åt sidan vid jubel
		var lyft := upp * 2.3 + (gestv * 1.3 if sida == "r" else 0.0)
		var q := Basis(Vector3.FORWARD, sx * upp * 0.35) * Basis(Vector3.RIGHT, -lyft)
		var ov := _vrid("upperarm_" + sida, q, _foralder_vila("upperarm_" + sida))
		var under_q := Basis()
		if sexsju_t > 0.0:
			# underarmarna gungar upp och ned i otakt
			under_q = Basis(Vector3.RIGHT, -(0.35 + sin(tid * 13.0 + (0.0 if sida == "r" else PI)) * 0.3))
		# underarmen följer överarmen: dess vila vrids med överarmen
		var u_ny: Basis = under_q * q * vila["lowerarm_" + sida].basis
		skelett.set_bone_pose_rotation(ben["lowerarm_" + sida], (ov.inverse() * u_ny).get_rotation_quaternion())
		var h_q := under_q * q
		if sexsju_t > 0.0:
			# handflatorna uppåt: handen rullas nästan ett halvt varv kring underarmen
			var axel: Vector3 = (u_ny * Vector3.UP).normalized()
			h_q = Basis(axel, PI * 0.9 * -sx) * h_q
		skelett.set_bone_pose_rotation(ben["hand_" + sida], (u_ny.inverse() * (h_q * vila["hand_" + sida].basis)).get_rotation_quaternion())
	if sexsju_t > 0.0:
		sexsju_t -= dt
		bubbla.scale = Vector3.ONE * (1.0 + 0.08 * sin(tid * 13.0))
		if sexsju_t <= 0.0:
			bubbla.visible = false
	blot = maxf(blot - dt * 0.16, 0.0)
	droppar.emitting = blot > 0.15
	if tomat_t > 0.0:
		tomat_t -= dt
		if tomat_t <= 0.0:
			tomatfleck.visible = false
	if gradde_t > 0.0:
		gradde_t -= dt
		if gradde_t < 1.0:
			gradde.scale = Vector3.ONE * maxf(gradde_t, 0.05)
		if gradde_t <= 0.0:
			gradde.visible = false
			gradde.scale = Vector3.ONE
	if krona_t > 0.0:
		krona_t -= dt
		krona.position.y = 0.66 + 0.03 * sin(tid * 3.0)
		if krona_t <= 0.0:
			krona.visible = false
	rodnad = maxf(rodnad - dt * 0.25, 0.0)
