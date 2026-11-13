extends Node3D
## Stolen figuren sitter på (Theo 2026-11-13): hög klubbstol i mörkt trä med stoppad sits och rygg i samma
## oxblodsskinn som bordskanten, mässingsnubb och en fotring där figurens fötter vilar. Byggs i kod.
## Lokalt rum: origo i figurens position (R_GUBBE från bordets mitt, y = 0), -Z pekar mot bordet.
## Måtten är tagna ur figurens skelett vid bordet: höften y −0,25, låren framåt till z −1,3, fötterna y −1,7.

const GOLV_Y := -7.8
const SITS_Y := -0.68  # sitsens mitt
const SITS_DJUP := 1.7
const SITS_BREDD := 1.8
const RYGG_Z := 0.66
const RYGG_TOPP := 1.5

static var _tra: StandardMaterial3D
static var _skinn: StandardMaterial3D
static var _massing: StandardMaterial3D


func _ready() -> void:
	_material()
	# sitsen: träram och stoppning
	_box(Vector3(SITS_BREDD + 0.1, 0.16, SITS_DJUP + 0.1), Vector3(0, SITS_Y - 0.12, -0.5), _tra)
	_box(Vector3(SITS_BREDD, 0.22, SITS_DJUP), Vector3(0, SITS_Y + 0.05, -0.5), _skinn)
	# ben ner till golvet, något utåtställda
	for x in [-1, 1]:
		for z in [-1, 1]:
			var topp := Vector3(x * (SITS_BREDD * 0.5 - 0.08), SITS_Y - 0.2, -0.5 + z * (SITS_DJUP * 0.5 - 0.08))
			var fot := Vector3(topp.x * 1.25, GOLV_Y, -0.5 + (topp.z + 0.5) * 1.25)
			_stang(topp, fot, 0.075, _tra)
	# fotringen där fötterna vilar
	var ring := TorusMesh.new()
	ring.inner_radius = 1.02
	ring.outer_radius = 1.12
	ring.rings = 48
	ring.ring_segments = 8
	_mi(ring, _massing, Transform3D(Basis(), Vector3(0, -1.95, -0.5)))
	# ryggen: två stolpar, stoppad panel och ett rundat krön
	for x in [-1, 1]:
		_stang(Vector3(x * 0.84, SITS_Y - 0.2, RYGG_Z - 0.05), Vector3(x * 0.84, RYGG_TOPP, RYGG_Z + 0.12), 0.075, _tra)
	var luta := Basis(Vector3.RIGHT, -0.08)
	var panel := BoxMesh.new()
	panel.size = Vector3(1.56, 1.45, 0.16)
	_mi(panel, _skinn, Transform3D(luta, Vector3(0, 0.58, RYGG_Z)))
	var kron := CylinderMesh.new()
	kron.top_radius = 0.09
	kron.bottom_radius = 0.09
	kron.height = 1.86
	_mi(kron, _tra, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, RYGG_TOPP, RYGG_Z + 0.12)))
	# mässingsnubb längs panelens kant
	var nubb := SphereMesh.new()
	nubb.radius = 0.03
	nubb.height = 0.06
	nubb.radial_segments = 8
	nubb.rings = 4
	for i in 9:
		var x := lerpf(-0.74, 0.74, float(i) / 8.0)
		_mi(nubb, _massing, Transform3D(Basis(), luta * Vector3(x, 0.7, -0.09) + Vector3(0, 0.58, RYGG_Z)), false)


static func _material() -> void:
	if _tra:
		return
	_tra = StandardMaterial3D.new()
	_tra.albedo_color = Color(0.2, 0.1, 0.05)
	_tra.roughness = 0.35
	_tra.clearcoat_enabled = true
	_tra.clearcoat = 0.5
	_tra.clearcoat_roughness = 0.25
	_skinn = StandardMaterial3D.new()
	_skinn.albedo_color = Color(0.2, 0.06, 0.04)
	_skinn.roughness = 0.45
	_skinn.clearcoat_enabled = true
	_skinn.clearcoat = 0.35
	_skinn.clearcoat_roughness = 0.4
	_massing = StandardMaterial3D.new()
	_massing.albedo_color = Color(0.8, 0.6, 0.27)
	_massing.metallic = 1.0
	_massing.roughness = 0.3


func _mi(m: Mesh, mat: Material, tf: Transform3D, skugga := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.transform = tf
	if not skugga:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(storlek: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = storlek
	_mi(b, mat, Transform3D(Basis(), pos))


## En rund stång mellan två punkter.
func _stang(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 12
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var z := x.cross(y)
	_mi(c, mat, Transform3D(Basis(x, y, z), (a + b) * 0.5))
