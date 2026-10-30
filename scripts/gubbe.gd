extends Node3D
## En figur som sitter vid bordet: en realistisk människa från Blender (figurer.gd, assets/gubbar/).
## Andas, tittar mot den som har turen, gör en gest när den spelar ett kort, jublar vid poäng,
## gör 6-7 och reagerar på kast (blöt, tomat, tårta, snöboll, flygplan, hjärta, krona, konfetti).
## Lokal -Z pekar mot bordets mitt.

const Figurer := preload("res://scripts/figurer.gd")

var def := {}
var huvud: Node3D
var tomatfleck: MeshInstance3D
var droppar: CPUParticles3D
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
var bubbla: Label3D
var bas_yaw := 0.0
var bas_y := 0.0
var huvud_y := 2.98


## En människa från Blender (assets/gubbar/*.glb, blender/gubbar.py). Vilan i skelettet är sittande, framsidan mot +Z
## och måtten i meter. Modellen skalas till bordets mått och vänds mot -Z.
## Ett osynligt huvud följer huvudbenet, så att kast, grädde, krona och droppar hamnar rätt. Blick, skakning,
## gest, jubel och 6-7 görs genom att vrida nacke, huvud och armar i skelettet.
const MODELL_SKALA := 4.2  # meter -> bordets enheter
const HUVUD_MITT := 0.1  # huvudets mitt ovanför huvudbenets början (m)
var skelett: Skeleton3D
var modell: Node3D
var ben := {}
var vila := {}
var nick := 0.0


func bygg_figur(index: int) -> void:
	def = Figurer.FIGURER[posmod(index, Figurer.FIGURER.size())]
	fas = index * 1.7
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
	var huvud_m: Vector3 = vila.head.origin + Vector3(0, HUVUD_MITT, 0)
	huvud_y = 2.98
	modell.position.y = huvud_y - huvud_m.y * MODELL_SKALA
	# osynligt huvud på huvudbenet: effekterna är ritade för huvudradie ~0.62 och krymps till ett riktigt huvud
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



## Vrider ett ben i skelettets rum: globalt läge = q * vila, räknat mot förälderns (nya) globala läge.
func _vrid(namn: String, q: Basis, foralder_global: Basis) -> Basis:
	var ny: Basis = q * vila[namn].basis
	skelett.set_bone_pose_rotation(ben[namn], (foralder_global.inverse() * ny).get_rotation_quaternion())
	return ny


func _foralder_vila(namn: String) -> Basis:
	return skelett.get_bone_global_rest(skelett.get_bone_parent(ben[namn])).basis


func _process(dt: float) -> void:
	tid += dt
	var andas := sin(tid * 1.6 + fas)
	# blick räknad i figurens rum (-Z framåt). I modellens rum (vänd ett halvt varv)
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
