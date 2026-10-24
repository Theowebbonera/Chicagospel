extends Node3D
## Rummet och bordet: runt kortbord med grön filt, stoppad läderkant, träsarg, hängande lampa med mjuka skuggor,
## mörkt rum med trägolv. Allt byggs i kod.

const RADIE := 6.2

var lampa: SpotLight3D
var miljo: WorldEnvironment


## Körs vi med Compatibility-renderaren (webben)?
static func ar_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func _ready() -> void:
	_miljo()
	_bord()
	_lampa()
	_golv()


func _miljo() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.015, 0.013)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.47, 0.38)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	miljo = WorldEnvironment.new()
	miljo.environment = env
	add_child(miljo)


func _filt_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 farg : source_color = vec3(0.05, 0.29, 0.16);
uniform sampler2D brus : filter_linear_mipmap, repeat_enable;
uniform sampler2D fin : filter_linear_mipmap, repeat_enable;
varying vec3 vp;
void vertex() { vp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vp.xz;
	float r = length(p);
	float n = texture(brus, p * 0.08).r;
	float f = texture(fin, p * 0.9).r;
	vec3 c = farg * (0.78 + 0.32 * n) * (0.9 + 0.2 * f);
	c *= mix(1.0, 0.62, smoothstep(3.8, 6.2, r));
	// tryckt guldlinje runt spelytan
	float ring = 1.0 - smoothstep(0.0, 0.025, abs(r - 5.15));
	float ring2 = 1.0 - smoothstep(0.0, 0.012, abs(r - 5.05));
	c = mix(c, vec3(0.62, 0.48, 0.2), (ring + ring2 * 0.7) * 0.75);
	ALBEDO = c;
	ROUGHNESS = 0.97;
	SPECULAR = 0.15;
	NORMAL_MAP = vec3(0.5 + (f - 0.5) * 0.25, 0.5 + (n - 0.5) * 0.15, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("brus", _brus(0.02, 4, 256))
	m.set_shader_parameter("fin", _brus(0.5, 2, 256))
	return m


func _tra_mat(farg: Color, rand: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 farg : source_color;
uniform float rand = 1.0;
uniform sampler2D brus : filter_linear_mipmap, repeat_enable;
varying vec3 vp;
void vertex() { vp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float a = atan(vp.z, vp.x);
	float n = texture(brus, vec2(a * 3.0, vp.y * 0.6)).r;
	float ringar = sin((length(vp.xz) * 9.0 + n * 6.0 + vp.y * 2.0) * rand) * 0.5 + 0.5;
	vec3 c = farg * (0.75 + 0.35 * ringar) * (0.85 + 0.3 * n);
	ALBEDO = c;
	ROUGHNESS = 0.32;
	CLEARCOAT = 0.6;
	CLEARCOAT_ROUGHNESS = 0.2;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("farg", Vector3(farg.r, farg.g, farg.b))
	m.set_shader_parameter("rand", rand)
	m.set_shader_parameter("brus", _brus(0.05, 3, 128))
	return m


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


func _mesh(m: Mesh, mat: Material, pos: Vector3, skugga := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	if not skugga:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _bord() -> void:
	# filtytan
	var c := CylinderMesh.new()
	c.top_radius = RADIE + 0.2
	c.bottom_radius = RADIE + 0.2
	c.height = 0.3
	c.radial_segments = 128
	_mesh(c, _filt_mat(), Vector3(0, -0.15, 0))
	# stoppad läderkant
	var t := TorusMesh.new()
	t.inner_radius = RADIE - 0.05
	t.outer_radius = RADIE + 0.75
	t.rings = 128
	t.ring_segments = 24
	var lader := StandardMaterial3D.new()
	lader.albedo_color = Color(0.17, 0.075, 0.04)
	lader.roughness = 0.38
	lader.clearcoat_enabled = true
	lader.clearcoat = 0.4
	lader.clearcoat_roughness = 0.35
	var kant := _mesh(t, lader, Vector3(0, 0.05, 0))
	kant.scale = Vector3(1, 0.75, 1)
	# träsarg under kanten
	var s := CylinderMesh.new()
	s.top_radius = RADIE + 0.7
	s.bottom_radius = RADIE + 0.55
	s.height = 0.7
	s.radial_segments = 128
	_mesh(s, _tra_mat(Color(0.36, 0.2, 0.1), 1.0), Vector3(0, -0.5, 0))
	# pelarfot
	var f := CylinderMesh.new()
	f.top_radius = 0.9
	f.bottom_radius = 1.4
	f.height = 7.0
	_mesh(f, _tra_mat(Color(0.25, 0.13, 0.07), 0.6), Vector3(0, -4.3, 0))
	# diskret tryck i mitten av filten
	var l := Label3D.new()
	l.text = "CHICAGO"
	l.font = load("res://assets/Fredoka.ttf")
	l.font_size = 160
	l.pixel_size = 0.006
	l.modulate = Color(0.75, 0.6, 0.25, 0.16)
	l.outline_size = 0
	l.rotation = Vector3(-PI / 2, 0, 0)
	l.position = Vector3(0, 0.002, 0)
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	add_child(l)


func _lampa() -> void:
	lampa = SpotLight3D.new()
	lampa.position = Vector3(0, 11.5, 0)
	lampa.rotation = Vector3(-PI / 2, 0, 0)
	lampa.spot_angle = 48.0
	lampa.spot_angle_attenuation = 1.6
	lampa.spot_range = 30.0
	lampa.spot_attenuation = 0.3
	lampa.light_energy = 4.6
	lampa.light_color = Color(1.0, 0.86, 0.68)
	lampa.shadow_enabled = true
	lampa.shadow_blur = 1.6
	lampa.light_size = 0.6
	lampa.shadow_bias = 0.02
	lampa.shadow_normal_bias = 0.6
	if ar_compat():
		# Compatibility (webben): skuggor från spotlampan blir helt svarta där, så lampan lyser utan skuggor
		lampa.shadow_enabled = false
	add_child(lampa)
	# lampskärm
	var sk := CylinderMesh.new()
	sk.top_radius = 0.35
	sk.bottom_radius = 1.9
	sk.height = 1.2
	sk.radial_segments = 64
	sk.cap_bottom = false
	var skm := StandardMaterial3D.new()
	skm.albedo_color = Color(0.06, 0.2, 0.12)
	skm.metallic = 0.6
	skm.roughness = 0.35
	skm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(sk, skm, Vector3(0, 12.4, 0), false)
	var gl := SphereMesh.new()
	gl.radius = 0.32
	gl.height = 0.64
	var glm := StandardMaterial3D.new()
	glm.emission_enabled = true
	glm.emission = Color(1.0, 0.85, 0.6)
	glm.emission_energy_multiplier = 6.0
	glm.albedo_color = Color(1, 0.95, 0.85)
	_mesh(gl, glm, Vector3(0, 12.0, 0), false)
	# svag fyllnadsljus från sidan så att kanterna inte blir helt svarta
	var fyll := OmniLight3D.new()
	fyll.position = Vector3(-9, 6, 7)
	fyll.omni_range = 25
	fyll.light_energy = 0.5
	fyll.light_color = Color(0.7, 0.75, 1.0)
	add_child(fyll)


func _golv() -> void:
	var p := PlaneMesh.new()
	p.size = Vector2(80, 80)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D brus : filter_linear_mipmap, repeat_enable;
varying vec3 vp;
void vertex() { vp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float planka = floor(vp.x / 1.6);
	float skarv = smoothstep(0.0, 0.04, fract(vp.x / 1.6)) * smoothstep(1.0, 0.96, fract(vp.x / 1.6));
	float n = texture(brus, vec2(vp.x * 0.05 + planka * 0.37, vp.z * 0.01)).r;
	vec3 c = vec3(0.2, 0.11, 0.06) * (0.7 + 0.5 * n) * (0.85 + 0.15 * fract(sin(planka * 12.9) * 43758.5));
	ALBEDO = c * mix(0.4, 1.0, skarv);
	ROUGHNESS = 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("brus", _brus(0.08, 4, 256))
	_mesh(p, m, Vector3(0, -7.8, 0))
