extends Node3D
## Rummet runt bordet (Theo 2026-11-12, grenen snyggare-3d): ett mörkt spelrum med boaserad panel och
## mönstrad tapet, vägglampor, tavlor, hyllor med flaskor och en rund matta under bordet. Allt byggs i kod.
## Väggarna står i en ring, så att bakgrunden ser likadan ut vilken plats kameran än tittar från.

const VAGG_RADIE := 24.0
const GOLV_Y := -7.8
const TAK_Y := 16.0
const PANEL_TOPP := -3.4  # boaseringens överkant
const SEKTIONER := 12
## Webben (Compatibility) får inget allmänt ljus på rummet: väggen lyser svagt själv där.
const SJALVLJUS_WEBB := 1.0

var ljus: Array[OmniLight3D] = []


static func ar_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func _ready() -> void:
	_vaggar()
	_matta()
	for i in SEKTIONER:
		var a := TAU * (float(i) + 0.5) / SEKTIONER
		_vagglampa(a)
		var mitt := TAU * float(i) / SEKTIONER
		if i % 3 == 1:
			_tavla(mitt, i)
		else:
			_hylla(mitt, i)


func _mesh(m: Mesh, mat: Material, tf: Transform3D, skugga := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.transform = tf
	if not skugga:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## En bit av väggen mellan vinklarna a0 och a1 (samma vinklar som _vid_vagg), normalen inåt.
func _vaggbit(a0: float, a1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var delar := 8
	for k in delar:
		var x0 := lerpf(a0, a1, float(k) / delar)
		var x1 := lerpf(a0, a1, float(k + 1) / delar)
		var p0 := Vector3(sin(x0) * VAGG_RADIE, 0, cos(x0) * VAGG_RADIE)
		var p1 := Vector3(sin(x1) * VAGG_RADIE, 0, cos(x1) * VAGG_RADIE)
		var n0 := -p0.normalized()
		var n1 := -p1.normalized()
		var lo := Vector3.UP * GOLV_Y
		var hi := Vector3.UP * TAK_Y
		for v in [[p0 + lo, n0], [p1 + lo, n1], [p1 + hi, n1], [p0 + lo, n0], [p1 + hi, n1], [p0 + hi, n0]]:
			st.set_normal(v[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(v[0])
	st.generate_tangents()
	return st.commit()


## Punkt på väggen vid vinkel a (sett från bordets mitt), en bit in från väggen.
func _vid_vagg(a: float, y: float, in_fran_vagg := 0.0) -> Transform3D:
	var r := VAGG_RADIE - in_fran_vagg
	var pos := Vector3(sin(a) * r, y, cos(a) * r)
	# lokala -Z pekar in mot bordet
	return Transform3D(Basis(Vector3.UP, a), pos)


func _vaggar() -> void:
	var c := CylinderMesh.new()
	c.top_radius = VAGG_RADIE
	c.bottom_radius = VAGG_RADIE
	c.height = TAK_Y - GOLV_Y
	c.radial_segments = 96
	c.cap_top = false
	c.cap_bottom = false
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float panel_topp;
uniform float golv;
uniform float sjalvljus = 0.0;  // bara i Compatibility (webben), som saknar rummets allmänna ljus
uniform sampler2D brus : filter_linear_mipmap, repeat_enable;
varying vec3 vp;
void vertex() { vp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float a = atan(vp.x, vp.z);
	float u = a * 24.0;          // väggens bredd i ungefär meter
	float y = vp.y;
	float n = texture(brus, vec2(u * 0.05, y * 0.05)).r;
	vec3 c;
	float rough;
	vec3 nrm = vec3(0.5, 0.5, 1.0);
	if (y < panel_topp) {
		// boaserad panel: mörkt valnötsträ i fyllningar med profilerade ramar
		float pu = fract(u / 3.2);
		float pv = (y - golv) / (panel_topp - golv);
		float ram = step(pu, 0.06) + step(0.94, pu) + step(pv, 0.1) + step(0.86, pv);
		float list = smoothstep(0.97, 1.0, pv);
		float adring = sin((u * 0.4 + n * 5.0) * 6.0) * 0.5 + 0.5;
		c = vec3(0.16, 0.085, 0.045) * (0.8 + 0.25 * adring) * (0.85 + 0.3 * n);
		c *= mix(1.0, 0.72, clamp(ram, 0.0, 1.0));
		c = mix(c, vec3(0.42, 0.3, 0.12), list * 0.8);
		rough = 0.35;
		float kant = smoothstep(0.055, 0.065, pu) - smoothstep(0.935, 0.945, pu);
		nrm = vec3(0.5 + (1.0 - kant) * 0.1, 0.5, 1.0);
	} else {
		// tapet: mörkgrön med ett diskret damastmönster i lite ljusare grönt
		vec2 p = vec2(u / 1.6, (y - panel_topp) / 2.2);
		vec2 f = fract(p) - 0.5;
		vec2 id = floor(p);
		if (mod(id.y, 2.0) > 0.5) { f = fract(p + vec2(0.5, 0.0)) - 0.5; }
		float d = abs(f.x) * 1.6 + abs(f.y);
		float blad = smoothstep(0.42, 0.38, d) * (0.5 + 0.5 * sin(atan(f.y, f.x) * 6.0 + d * 18.0));
		float rand = smoothstep(0.47, 0.45, d) - smoothstep(0.43, 0.41, d);
		c = vec3(0.045, 0.1, 0.07) * (0.9 + 0.2 * n);
		c = mix(c, vec3(0.09, 0.17, 0.11), clamp(blad * 0.6 + rand * 0.5, 0.0, 1.0));
		rough = mix(0.85, 0.45, clamp(blad + rand, 0.0, 1.0));
	}
	// sotigare upptill
	c *= mix(1.0, 0.55, smoothstep(6.0, 15.0, y));
	ALBEDO = c * 1.35;
	EMISSION = c * sjalvljus;
	ROUGHNESS = rough;
	NORMAL_MAP = nrm;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("panel_topp", PANEL_TOPP)
	m.set_shader_parameter("golv", GOLV_Y)
	m.set_shader_parameter("sjalvljus", SJALVLJUS_WEBB if ar_compat() else 0.0)
	m.set_shader_parameter("brus", _brus(0.06, 4, 256))
	# En bit per sektion i stället för en hel cylinder: Compatibility (webben) tar bara med ett
	# fåtal lampor per yta, så en enda vägg runt hela rummet blev svart där (Theo 2026-11-13).
	for i in SEKTIONER:
		_mesh(_vaggbit(TAU * float(i) / SEKTIONER, TAU * float(i + 1) / SEKTIONER), m, Transform3D())
	# tak: mörkt, med kassetter som knappt syns
	var tak := CylinderMesh.new()
	tak.top_radius = VAGG_RADIE
	tak.bottom_radius = VAGG_RADIE
	tak.height = 0.2
	tak.radial_segments = 64
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.03, 0.025, 0.02)
	tm.roughness = 0.9
	_mesh(tak, tm, Transform3D(Basis(), Vector3(0, TAK_Y, 0)))
	# golvlist längs väggen
	var lst := TorusMesh.new()
	lst.inner_radius = VAGG_RADIE - 0.35
	lst.outer_radius = VAGG_RADIE + 0.05
	lst.rings = 96
	lst.ring_segments = 6
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.1, 0.05, 0.025)
	lm.roughness = 0.4
	var li := _mesh(lst, lm, Transform3D(Basis(), Vector3(0, GOLV_Y + 0.15, 0)))
	li.scale = Vector3(1, 1.5, 1)


func _matta() -> void:
	var p := CylinderMesh.new()
	p.top_radius = 12.5
	p.bottom_radius = 12.5
	p.height = 0.04
	p.radial_segments = 96
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D brus : filter_linear_mipmap, repeat_enable;
varying vec3 vp;
void vertex() { vp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float r = length(vp.xz);
	float a = atan(vp.z, vp.x);
	float n = texture(brus, vp.xz * 0.15).r;
	vec3 botten = vec3(0.24, 0.035, 0.03);
	vec3 bard = vec3(0.55, 0.38, 0.14);
	vec3 morkt = vec3(0.06, 0.03, 0.025);
	vec3 c = botten;
	// bårder: två guldringar med ett mörkt band och ett slingrande mönster emellan
	float b1 = 1.0 - smoothstep(0.0, 0.08, abs(r - 11.7));
	float b2 = 1.0 - smoothstep(0.0, 0.06, abs(r - 10.3));
	float band = step(10.4, r) * step(r, 11.6);
	c = mix(c, morkt, band);
	float slinga = smoothstep(0.15, 0.0, abs(r - 11.0 - 0.35 * sin(a * 36.0)));
	c = mix(c, bard * 0.8, slinga * band);
	c = mix(c, bard, max(b1, b2));
	// medaljong i mitten (syns knappt under bordet) och fransar
	float rosett = 0.5 + 0.5 * sin(a * 12.0) * sin(r * 1.4);
	c = mix(c, botten * 1.35, step(r, 10.2) * rosett * 0.35);
	c *= 0.82 + 0.3 * n;
	c *= mix(1.0, 0.6, smoothstep(12.2, 12.5, r));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	NORMAL_MAP = vec3(0.5 + (n - 0.5) * 0.3, 0.5, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("brus", _brus(0.4, 3, 256))
	_mesh(p, m, Transform3D(Basis(), Vector3(0, GOLV_Y + 0.02, 0)), true)


func _massing() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.58, 0.26)
	m.metallic = 1.0
	m.roughness = 0.3
	return m


func _vagglampa(a: float) -> void:
	var y := 3.6
	var bas := _vid_vagg(a, y, 0.15)
	var platta := CylinderMesh.new()
	platta.top_radius = 0.28
	platta.bottom_radius = 0.28
	platta.height = 0.08
	_mesh(platta, _massing(), bas * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	var arm := CylinderMesh.new()
	arm.top_radius = 0.04
	arm.bottom_radius = 0.04
	arm.height = 0.7
	_mesh(arm, _massing(), bas * Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.5), Vector3(0, 0.15, -0.3)))
	# skärm av frostat glas med glöd
	var sk := CylinderMesh.new()
	sk.top_radius = 0.18
	sk.bottom_radius = 0.34
	sk.height = 0.5
	var skm := StandardMaterial3D.new()
	skm.albedo_color = Color(1.0, 0.9, 0.75)
	skm.emission_enabled = true
	skm.emission = Color(1.0, 0.72, 0.42)
	skm.emission_energy_multiplier = 2.4
	skm.roughness = 0.6
	_mesh(sk, skm, bas * Transform3D(Basis(), Vector3(0, 0.55, -0.62)))
	var o := OmniLight3D.new()
	o.transform = bas * Transform3D(Basis(), Vector3(0, 0.6, -0.9))
	o.light_color = Color(1.0, 0.72, 0.45)
	o.light_energy = 2.2 * (2.5 if ar_compat() else 1.0)
	o.omni_range = 7.0
	o.omni_attenuation = 1.4
	o.shadow_enabled = false
	o.light_volumetric_fog_energy = 0.0
	add_child(o)
	ljus.append(o)


func _tavla(a: float, i: int) -> void:
	var y := 4.5
	var bas := _vid_vagg(a, y, 0.1)
	var ram := BoxMesh.new()
	ram.size = Vector3(4.4, 3.2, 0.18)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.5, 0.36, 0.14)
	rm.metallic = 0.8
	rm.roughness = 0.38
	_mesh(ram, rm, bas)
	# målningen: mörkt, oljeaktigt landskap i varma toner (procedurellt, olika för varje tavla)
	var q := QuadMesh.new()
	q.size = Vector2(3.8, 2.6)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D brus : filter_linear_mipmap, repeat_enable;
uniform float fro;
void fragment() {
	vec2 uv = UV;
	float n = texture(brus, uv * vec2(1.6, 1.0) + fro).r;
	float n2 = texture(brus, uv * 5.0 + fro * 2.0).r;
	float horisont = 0.55 + 0.12 * (n - 0.5);
	vec3 himmel = mix(vec3(0.55, 0.38, 0.2), vec3(0.18, 0.14, 0.12), uv.y * 1.6);
	vec3 mark = mix(vec3(0.12, 0.1, 0.05), vec3(0.06, 0.05, 0.03), (uv.y - horisont) * 2.0);
	vec3 c = mix(himmel, mark, smoothstep(horisont - 0.01, horisont + 0.01, uv.y));
	c *= 0.75 + 0.5 * n2;
	// fernissa: mörkare i kanterna
	c *= 1.0 - 0.6 * pow(length(uv - 0.5) * 1.3, 2.0);
	ALBEDO = c;
	ROUGHNESS = 0.35;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("brus", _brus(0.03, 5, 256))
	m.set_shader_parameter("fro", float(i) * 0.37)
	_mesh(q, m, bas * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.1)))


func _hylla(a: float, i: int) -> void:
	var bas := _vid_vagg(a, 0.0, 0.0)
	var tra := StandardMaterial3D.new()
	tra.albedo_color = Color(0.13, 0.065, 0.035)
	tra.roughness = 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + i
	for niva in 3:
		var y := 1.2 + niva * 1.9
		var hylla := BoxMesh.new()
		hylla.size = Vector3(4.6, 0.12, 0.7)
		_mesh(hylla, tra, bas * Transform3D(Basis(), Vector3(0, y, -0.4)))
		# flaskor och glas
		var x := -2.0
		while x < 2.0:
			var hojd := rng.randf_range(0.7, 1.2)
			var bred := rng.randf_range(0.13, 0.2)
			var f := CylinderMesh.new()
			f.top_radius = bred * 0.35
			f.bottom_radius = bred
			f.height = hojd
			f.radial_segments = 16
			var gm := StandardMaterial3D.new()
			var farger := [Color(0.35, 0.18, 0.05), Color(0.08, 0.22, 0.1), Color(0.5, 0.32, 0.1), Color(0.2, 0.05, 0.05), Color(0.7, 0.62, 0.45)]
			gm.albedo_color = farger[rng.randi() % farger.size()]
			gm.albedo_color.a = 0.82
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.roughness = 0.08
			gm.metallic_specular = 0.9
			gm.rim_enabled = true
			gm.rim = 0.4
			_mesh(f, gm, bas * Transform3D(Basis(), Vector3(x, y + 0.06 + hojd * 0.5, -0.45)))
			x += bred * 2.0 + rng.randf_range(0.08, 0.35)
	# svag varm list-belysning under översta hyllan
	var strip := BoxMesh.new()
	strip.size = Vector3(4.4, 0.03, 0.05)
	var sm := StandardMaterial3D.new()
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.7, 0.4)
	sm.emission_energy_multiplier = 3.0
	_mesh(strip, sm, bas * Transform3D(Basis(), Vector3(0, 1.2 + 2 * 1.9 + 0.95, -0.6)))


func _brus(frekvens: float, oktaver: int, storlek: int) -> NoiseTexture2D:
	var nz := FastNoiseLite.new()
	nz.frequency = frekvens
	nz.fractal_octaves = oktaver
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.width = storlek
	t.height = storlek
	t.seamless = true
	t.generate_mipmaps = true
	return t
