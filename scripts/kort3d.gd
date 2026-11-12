extends Node3D
## Ett kort i 3D: framsida och baksida som två plan med rundade hörn (alfa-kant), markering och animering.
## Kortets lokala plan är XY, framsidan pekar mot +Z.

const BREDD := 0.8
const HOJD := 1.12
## Kortets tjocklek och hörnradie (22 av 300 px i kortbild.gd), för kanten (Theo 2026-11-12, snyggare-3d).
const TJOCK := 0.006
const HORN := 0.0587

static var _kant_mesh: ArrayMesh
static var _kant_mat: StandardMaterial3D

var id := -1
var fram: MeshInstance3D
var bak: MeshInstance3D
var glod: MeshInstance3D
var mat_fram: StandardMaterial3D
var mat_bak: StandardMaterial3D
var tw: Tween
var _fran := Transform3D()
var vald := false
var dimmad := false
var hover := false


func skapa(kort_id: int, framsida: Texture2D, baksida: Texture2D, glod_mat: Material) -> void:
	id = kort_id
	var q := QuadMesh.new()
	q.size = Vector2(BREDD, HOJD)
	mat_fram = _mat(framsida)
	mat_bak = _mat(baksida)
	fram = MeshInstance3D.new()
	fram.mesh = q
	fram.material_override = mat_fram
	add_child(fram)
	bak = MeshInstance3D.new()
	bak.mesh = q
	bak.material_override = mat_bak
	bak.rotation.y = PI
	bak.position.z = -TJOCK
	add_child(bak)
	# kanten: ett smalt band runt kortet med samma rundade hörn som bilden
	var kant := MeshInstance3D.new()
	kant.mesh = _kant()
	kant.material_override = _kant_material()
	kant.position.z = -TJOCK * 0.5
	kant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(kant)
	var gq := QuadMesh.new()
	gq.size = Vector2(BREDD + 0.2, HOJD + 0.2)
	glod = MeshInstance3D.new()
	glod.mesh = gq
	glod.material_override = glod_mat
	glod.position.z = -0.004
	glod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glod.visible = false
	add_child(glod)


## Bandet runt kortet (delas av alla 52): en rundad rektangel, extruderad TJOCK i Z.
static func _kant() -> ArrayMesh:
	if _kant_mesh:
		return _kant_mesh
	var pts: PackedVector2Array = []
	var hx := BREDD * 0.5 - HORN
	var hy := HOJD * 0.5 - HORN
	var mitt := [Vector2(hx, hy), Vector2(-hx, hy), Vector2(-hx, -hy), Vector2(hx, -hy)]
	for h in 4:
		for i in 7:
			var a := PI * 0.5 * h + PI * 0.5 * float(i) / 6.0
			pts.append(mitt[h] + Vector2(cos(a), sin(a)) * HORN)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := TJOCK * 0.5
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var n := Vector3(b.y - a.y, -(b.x - a.x), 0).normalized()
		for v in [Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y, -z),
				Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, -z)]:
			st.set_normal(n)
			st.add_vertex(v)
	_kant_mesh = st.commit()
	return _kant_mesh


static func _kant_material() -> StandardMaterial3D:
	if _kant_mat:
		return _kant_mat
	_kant_mat = StandardMaterial3D.new()
	_kant_mat.albedo_color = Color(0.9, 0.88, 0.83)
	_kant_mat.roughness = 0.8
	_kant_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _kant_mat


func _mat(t: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# matt yta: kort som lutas mot kameran ska inte spegla lampan, men en svag lackglans i kanten av sheenen
	m.roughness = 0.62
	m.metallic_specular = 0.25
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.3
	return m


func satt_texturer(framsida: Texture2D, baksida: Texture2D) -> void:
	mat_fram.albedo_texture = framsida
	mat_bak.albedo_texture = baksida


func satt_glod(pa: bool, farg := Color(1.0, 0.8, 0.3), styrka := 1.0) -> void:
	glod.visible = pa
	if pa:
		glod.set_instance_shader_parameter("farg", farg)
		glod.set_instance_shader_parameter("styrka", styrka)


func satt_dimmad(d: bool) -> void:
	dimmad = d
	var c := Color(0.46, 0.46, 0.48) if d else Color(0.93, 0.93, 0.93)
	mat_fram.albedo_color = c


## Flyger kortet till målet längs en båge och vrider det samtidigt (sfärisk interpolation).
func flyg(mal: Transform3D, tid := 0.4, bage := 0.4, fordrojning := 0.0) -> Tween:
	if tw and tw.is_valid():
		tw.kill()
	tw = create_tween()
	if fordrojning > 0.0:
		tw.tween_interval(fordrojning)
	tw.tween_callback(func() -> void: _fran = transform)
	tw.tween_method(_steg.bind(mal, bage), 0.0, 1.0, maxf(tid, 0.001)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tw


func _steg(t: float, mal: Transform3D, bage: float) -> void:
	var p := _fran.origin.lerp(mal.origin, t) + Vector3.UP * bage * sin(PI * t)
	var q := _fran.basis.get_rotation_quaternion().slerp(mal.basis.get_rotation_quaternion(), t)
	# skalan följer med (korten i sticken visas större)
	var s := lerpf(_fran.basis.get_scale().x, mal.basis.get_scale().x, t)
	transform = Transform3D(Basis(q).scaled(Vector3(s, s, s)), p)


func i_rorelse() -> bool:
	return tw != null and tw.is_valid() and tw.is_running()


## Vänder kortet framsidan mot punkten (t.ex. kameran)?
func visar_framsida_mot(punkt: Vector3) -> bool:
	return global_transform.basis.z.dot(punkt - global_position) > 0.0


func satt_direkt(mal: Transform3D) -> void:
	if tw and tw.is_valid():
		tw.kill()
	transform = mal


## Träff med en stråle mot kortets plan. Returnerar avståndet längs strålen, eller -1.
func trraff(fran: Vector3, rikt: Vector3) -> float:
	var n := global_transform.basis.z.normalized()
	var d := rikt.dot(n)
	if absf(d) < 1e-5:
		return -1.0
	var t := (global_position - fran).dot(n) / d
	if t < 0.0:
		return -1.0
	var p := fran + rikt * t - global_position
	var sk := global_transform.basis.get_scale().x
	var x := p.dot(global_transform.basis.x.normalized())
	var y := p.dot(global_transform.basis.y.normalized())
	if absf(x) <= BREDD * 0.5 * sk and absf(y) <= HOJD * 0.5 * sk:
		return t
	return -1.0
