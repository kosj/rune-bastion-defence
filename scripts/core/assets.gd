class_name Assets
## Asset loading helpers with caching.

const MODEL_DIR := "res://assets/models/"
const CHAR_DIR := "res://assets/characters/"
const ICON_DIR := "res://assets/ui/"

static var _scenes := {}
static var _meshes := {}
static var _tex := {}
static var _fixed := {}
static var _fonts := {}

static func scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var p := MODEL_DIR + name + ".glb"
		if not ResourceLoader.exists(p):
			p = CHAR_DIR + name + ".glb"
		if not ResourceLoader.exists(p):
			return null  # not cached: streamed content may still arrive (Content)
		_scenes[name] = load(p)
	return _scenes[name]

static func instance(name: String) -> Node3D:
	var ps := scene(name)
	if ps == null:
		push_warning("missing model " + name)
		return Node3D.new()
	var n: Node3D = ps.instantiate()
	fix_vertex_color_materials(n)
	return n

## A model whose painted lava / crystal parts glow: every surface gets an emissive copy of its
## material. The emission map is <name>_emit.png (the albedo masked to the glowing hues by
## tools/pipeline/make_emit.py), so the cracks and shards light up while rock, wood and gold stay lit
## normally; without a mask the albedo itself is used.
static var _glow_mats := {}
static var _glow_shader: Shader

static func instance_glow(name: String, energy := 1.2, tint := Color.WHITE, albedo := Color.WHITE) -> Node3D:
	var n := instance(name)
	if _glow_shader == null:
		# an explicit PBR shader: the stock material's emission map did not stay confined to the
		# masked texels on the Compatibility renderer and washed the whole prop out
		_glow_shader = Shader.new()
		_glow_shader.code = """shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap;
uniform vec4 albedo_mul : source_color = vec4(1.0);
uniform vec4 emit_tint : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform bool has_normal = true;
void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_mul.rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	EMISSION = texture(emit_tex, UV).rgb * emit_tint.rgb * energy;
}"""
	var emit_p := MODEL_DIR + name + "_emit.png"
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as StandardMaterial3D
			if src == null:
				continue
			var key := "%d_%.2f_%s_%s" % [src.get_instance_id(), energy, tint.to_html(), albedo.to_html()]
			if not _glow_mats.has(key):
				var g := ShaderMaterial.new()
				g.shader = _glow_shader
				g.set_shader_parameter("albedo_tex", src.albedo_texture)
				g.set_shader_parameter("orm_tex", src.roughness_texture if src.roughness_texture else src.metallic_texture)
				g.set_shader_parameter("normal_tex", src.normal_texture)
				g.set_shader_parameter("has_normal", src.normal_texture != null)
				g.set_shader_parameter("emit_tex", load(emit_p) if ResourceLoader.exists(emit_p) else src.albedo_texture)
				g.set_shader_parameter("albedo_mul", albedo)
				g.set_shader_parameter("emit_tint", tint)
				g.set_shader_parameter("energy", energy)
				_glow_mats[key] = g
			m.set_surface_override_material(s, _glow_mats[key])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## Ensure meshes exported with baked vertex colors (AO) use them as albedo multiplier.
static func fix_vertex_color_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		fix_mesh(m)

static func fix_mesh(m: Mesh) -> void:
	var id := m.get_instance_id()
	if _fixed.has(id):
		return
	_fixed[id] = true
	for s in m.get_surface_count():
		var fmt := (m as ArrayMesh).surface_get_format(s) if m is ArrayMesh else 0
		var mat := m.surface_get_material(s)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			if fmt & Mesh.ARRAY_FORMAT_COLOR and sm.albedo_texture == null:
				sm.vertex_color_use_as_albedo = true
			if sm.emission_enabled:
				sm.emission_energy_multiplier = 0.75
			if sm.albedo_texture != null:
				# the game camera sees walls and roofs at grazing angles: anisotropic filtering keeps
				# the painted detail readable instead of smearing into the next mip level
				sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if sm.ao_enabled and sm.ao_texture != null:
				# baked AO (ORM.R) also shades a little of the direct light so crevices and eaves read
				sm.ao_light_affect = 0.4

## Returns the mesh of the named node inside a GLB (default "Body").
static func mesh(name: String, node_name := "Body") -> Mesh:
	var key := name + "/" + node_name
	if _meshes.has(key):
		return _meshes[key]
	var ps := scene(name)
	var result: Mesh = null
	if ps:
		var inst := ps.instantiate()
		var n := inst.find_child(node_name, true, false)
		if n == null:
			for c in inst.find_children("*", "MeshInstance3D", true, false):
				n = c
				break
		if n is MeshInstance3D:
			result = (n as MeshInstance3D).mesh
			fix_mesh(result)
		inst.free()
	if result:
		_meshes[key] = result
	return result

static func multimesh(name: String, xforms: Array, parent: Node, shadows := true) -> MultiMeshInstance3D:
	var m := mesh(name)
	if m == null or xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := ICON_DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]

static func tex_path(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

static func font(kind := "ui") -> Font:
	if not _fonts.has(kind):
		var p := "res://assets/fonts/%s.ttf" % kind
		var f: Font = load(p) if ResourceLoader.exists(p) else ThemeDB.fallback_font
		if kind == "title" and f is FontFile:
			var fb: Array[Font] = [font("title_kr"), font("ui")]
			(f as FontFile).fallbacks = fb
		elif kind == "ui_black" and f is FontFile:
			var fb3: Array[Font] = [font("ui")]
			(f as FontFile).fallbacks = fb3
		elif kind == "title_kr" and f is FontFile:
			var fb2: Array[Font] = [font("ui")]
			(f as FontFile).fallbacks = fb2
		_fonts[kind] = f
	return _fonts[kind]

## Radial soft dot texture for particles.
static func soft_dot() -> Texture2D:
	if _tex.has("__dot"):
		return _tex["__dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_tex["__dot"] = gt
	return gt


static var _env_shader: Shader
static var _snow_overlay: ShaderMaterial

## Theme material for textured decor: optional colorize of green foliage (autumn/night) and snow caps.
static func env_material(m: Mesh, colorize: Color, snow: float) -> Material:
	if m == null:
		return null
	var src := m.surface_get_material(0)
	if not (src is StandardMaterial3D) or (src as StandardMaterial3D).albedo_texture == null:
		return null
	if _env_shader == null:
		_env_shader = Shader.new()
		_env_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 colorize = vec4(0.0);
uniform float snow = 0.0;
varying vec3 wnorm;
void vertex() { wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float greenness = clamp((c.g - max(c.r, c.b)) * 4.0, 0.0, 1.0);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, colorize.rgb * lum * 2.2, colorize.a * greenness);
	float cap = smoothstep(0.35, 0.75, wnorm.y) * snow;
	c = mix(c, vec3(0.92, 0.95, 1.0), cap);
	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.6, cap);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _env_shader
	sm.set_shader_parameter("albedo_tex", (src as StandardMaterial3D).albedo_texture)
	sm.set_shader_parameter("colorize", colorize)
	sm.set_shader_parameter("snow", snow)
	return sm

## Overlay pass that dusts any mesh (towers, castle, characters) with snow on upward faces.
static func snow_overlay() -> ShaderMaterial:
	if _snow_overlay:
		return _snow_overlay
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_burley;
varying vec3 wnorm;
varying vec3 wpos;
void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = sin(wpos.x * 3.1) * sin(wpos.z * 2.7) * 0.5 + 0.5;
	ALBEDO = vec3(0.86, 0.9, 0.97);
	ROUGHNESS = 0.6;
	ALPHA = smoothstep(0.72, 0.92, wnorm.y + (n - 0.5) * 0.08) * 0.8;
}
"""
	_snow_overlay = ShaderMaterial.new()
	_snow_overlay.shader = sh
	return _snow_overlay
