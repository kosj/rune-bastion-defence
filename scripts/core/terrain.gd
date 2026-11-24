class_name Terrain
extends Node3D
## Procedural terrain: height field, vertex painted path, water, wind grass and decor scatter.

const X0 := -48.0
const X1 := 48.0
const Z0 := -34.0
const Z1 := 32.0
const RES := 1.0

var paths: Array = []          # Array[LanePath]
var plots: Array = []          # Array[Vector2]
var keepout: Array = []        # Array[Vector3] (x, z, radius)
var theme := "meadow"
var river_x := INF
var bounds := Rect2(-30, -18, 60, 34)
var decor_colorize := Color(0, 0, 0, 0)
var decor_snow := 0.0
var decor_xf := {}
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var _nx := 0
var _nz := 0
var _heights := PackedFloat32Array()

const THEMES := {
	"meadow": {"grass": "terrain_grass", "grass_tint": Color(0.92, 0.98, 0.86), "colorize": Color(0, 0, 0, 0), "dirt_tint": Color(1, 1, 1),
		"rock": Color(0.52, 0.5, 0.47), "sand": Color(0.82, 0.74, 0.52), "tuft": Color(0.36, 0.6, 0.2), "tufts": 1.0},
	"river": {"grass": "terrain_grass", "grass_tint": Color(0.86, 0.95, 0.9), "colorize": Color(0, 0, 0, 0), "dirt_tint": Color(0.95, 0.95, 0.95),
		"rock": Color(0.48, 0.5, 0.5), "sand": Color(0.8, 0.74, 0.56), "tuft": Color(0.32, 0.56, 0.24), "tufts": 1.0},
	"autumn": {"grass": "terrain_grass", "grass_tint": Color(0.88, 0.84, 0.8), "colorize": Color(0.8, 0.6, 0.3, 0.45), "dirt_tint": Color(0.9, 0.82, 0.78),
		"rock": Color(0.5, 0.45, 0.42), "sand": Color(0.8, 0.66, 0.46), "tuft": Color(0.66, 0.54, 0.24), "tufts": 0.8},
	"snow": {"grass": "terrain_snow", "grass_tint": Color(0.8, 0.84, 0.92), "colorize": Color(0, 0, 0, 0), "dirt_tint": Color(0.72, 0.72, 0.8),
		"rock": Color(0.5, 0.53, 0.6), "sand": Color(0.85, 0.88, 0.95), "tuft": Color(0.75, 0.82, 0.9), "tufts": 0.0},
	"night": {"grass": "terrain_grass", "grass_tint": Color(0.7, 0.86, 0.9), "colorize": Color(0.3, 0.55, 0.6, 0.35), "dirt_tint": Color(0.8, 0.8, 0.9),
		"rock": Color(0.42, 0.44, 0.52), "sand": Color(0.6, 0.62, 0.7), "tuft": Color(0.24, 0.42, 0.36), "tufts": 0.9},
	"ruins": {"grass": "terrain_grass", "grass_tint": Color(0.66, 0.78, 0.7), "colorize": Color(0.4, 0.55, 0.5, 0.3), "dirt_tint": Color(0.78, 0.76, 0.74),
		"rock": Color(0.5, 0.53, 0.55), "sand": Color(0.72, 0.72, 0.68), "tuft": Color(0.32, 0.5, 0.38), "tufts": 0.9},
	"swamp": {"grass": "terrain_grass", "grass_tint": Color(0.5, 0.6, 0.52), "colorize": Color(0.32, 0.42, 0.36, 0.55), "dirt_tint": Color(0.6, 0.62, 0.55),
		"rock": Color(0.32, 0.36, 0.34), "sand": Color(0.45, 0.5, 0.42), "tuft": Color(0.22, 0.38, 0.24), "tufts": 1.0},
	"necro": {"grass": "terrain_grass", "grass_tint": Color(0.6, 0.58, 0.56), "colorize": Color(0.42, 0.4, 0.4, 0.75), "dirt_tint": Color(0.66, 0.6, 0.58),
		"rock": Color(0.3, 0.28, 0.3), "sand": Color(0.45, 0.4, 0.38), "tuft": Color(0.38, 0.34, 0.3), "tufts": 0.5},
}


func setup(p_paths: Array, p_plots: Array, p_theme: String, p_bounds: Rect2, p_keepout: Array, p_river := INF) -> void:
	paths = p_paths
	plots = p_plots
	theme = p_theme
	bounds = p_bounds
	keepout = p_keepout
	river_x = p_river
	noise.seed = hash(theme) & 0xffff
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	noise2.seed = noise.seed + 7
	noise2.frequency = 0.12
	_build_heights()
	_build_mesh()
	if river_x != INF:
		_build_water()

func path_dist(x: float, z: float) -> float:
	var best := 1e9
	var p := Vector2(x, z)
	for lp in paths:
		best = minf(best, (lp as LanePath).closest(p).x)
	return best

func _raw_height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 0.55 + noise2.get_noise_2d(x, z) * 0.12
	# rise outside play bounds -> natural framing hills
	var dx := maxf(maxf(bounds.position.x - 2.0 - x, x - bounds.end.x - 2.0), 0.0)
	var dz := maxf(maxf(bounds.position.y - 2.0 - z, z - bounds.end.y - 2.0), 0.0)
	var edge := maxf(dx, dz)
	h += smoothstep(0.0, 12.0, edge) * (3.5 + noise.get_noise_2d(x * 2.0, z * 2.0) * 2.5)
	# path & plots flatten
	var pd := path_dist(x, z)
	var flat := smoothstep(5.0, 1.5, pd)
	for pl in plots:
		var d: float = (pl as Vector2).distance_to(Vector2(x, z))
		flat = maxf(flat, smoothstep(3.6, 2.0, d))
	for k in keepout:
		var d2: float = Vector2(k.x, k.y).distance_to(Vector2(x, z))
		flat = maxf(flat, smoothstep(k.z + 2.0, k.z, d2))
	h = lerpf(h, -0.05 if pd < 1.8 else 0.0, flat)
	if river_x != INF:
		var rd := absf(x - river_x - sin(z * 0.15) * 1.5)
		h = lerpf(-1.4, h, smoothstep(2.4, 4.2, rd))
	return h

func _build_heights() -> void:
	_nx = int((X1 - X0) / RES) + 1
	_nz = int((Z1 - Z0) / RES) + 1
	_heights.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			_heights[j * _nx + i] = _raw_height(X0 + i * RES, Z0 + j * RES)

func height_at(x: float, z: float) -> float:
	var fx := clampf((x - X0) / RES, 0.0, _nx - 1.001)
	var fz := clampf((z - Z0) / RES, 0.0, _nz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := _heights[j * _nx + i]
	var h10 := _heights[j * _nx + i + 1]
	var h01 := _heights[(j + 1) * _nx + i]
	var h11 := _heights[(j + 1) * _nx + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func walk_height(x: float, z: float) -> float:
	if river_x != INF:
		var rd := absf(x - river_x - sin(z * 0.15) * 1.5)
		if rd < 4.2:
			return maxf(height_at(x, z), 0.32)
	return height_at(x, z)

func in_river(x: float, z: float) -> bool:
	if river_x == INF:
		return false
	return absf(x - river_x - sin(z * 0.15) * 1.5) < 3.4

func _vertex_data(x: float, z: float, h: float, slope: float) -> Array:
	var pd := path_dist(x, z)
	var pw := clampf(1.0 - (pd - 1.2) / 1.6, 0.0, 1.0)
	var shade := 1.0 - smoothstep(2.5, 7.0, h) * 0.25
	shade *= 0.92 + 0.08 * (noise2.get_noise_2d(x * 0.7, z * 0.7) * 0.5 + 0.5)
	var rock := smoothstep(0.5, 0.9, slope) * 0.9
	var sand := 0.0
	if river_x != INF:
		var rd := absf(x - river_x - sin(z * 0.15) * 1.5)
		sand = smoothstep(4.6, 3.4, rd)
		shade *= lerpf(1.0, 0.7, smoothstep(3.0, 2.0, rd))
	return [Color(shade, shade, shade, pw), Vector2(rock, sand)]

func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	verts.resize(_nx * _nz)
	cols.resize(_nx * _nz)
	uv2.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var x := X0 + i * RES
			var z := Z0 + j * RES
			var h := _heights[j * _nx + i]
			var hx := _heights[j * _nx + mini(i + 1, _nx - 1)] - _heights[j * _nx + maxi(i - 1, 0)]
			var hz := _heights[mini(j + 1, _nz - 1) * _nx + i] - _heights[maxi(j - 1, 0) * _nx + i]
			var slope := Vector2(hx, hz).length() * 0.5
			verts[j * _nx + i] = Vector3(x, h, z)
			var vd := _vertex_data(x, z, h, slope)
			cols[j * _nx + i] = vd[0]
			uv2[j * _nx + i] = vd[1]
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var idx := PackedInt32Array()
	for j in _nz - 1:
		for i in _nx - 1:
			var a := j * _nx + i
			var b := a + 1
			var c := a + _nx
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(tmp, 0)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader()
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	nt.noise = fn
	mat.set_shader_parameter("detail", nt)
	var th: Dictionary = THEMES[theme]
	mat.set_shader_parameter("grass_tex", load("res://assets/textures/%s.png" % th["grass"]))
	mat.set_shader_parameter("dirt_tex", load("res://assets/textures/terrain_dirt.png"))
	mat.set_shader_parameter("grass_tint", th["grass_tint"])
	mat.set_shader_parameter("dirt_tint", th["dirt_tint"])
	mat.set_shader_parameter("colorize", th["colorize"])
	mat.set_shader_parameter("rock_col", th["rock"])
	mat.set_shader_parameter("sand_col", th["sand"])
	mat.set_shader_parameter("cloud_strength", 0.12 if theme in ["night", "swamp", "necro"] else 0.24)
	mi.material_override = mat
	mi.name = "TerrainMesh"
	add_child(mi)

func _terrain_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D detail : repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 dirt_tint : source_color = vec3(1.0);
uniform vec4 colorize = vec4(0.0);
uniform vec3 rock_col : source_color = vec3(0.5);
uniform vec3 sand_col : source_color = vec3(0.8, 0.7, 0.5);
uniform float cloud_strength = 0.24;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.16;
	float n = texture(detail, wpos.xz * 0.035).r;
	float n2 = texture(detail, wpos.xz * 0.11 + vec2(0.3, 0.7)).r;
	vec3 g = texture(grass_tex, uv).rgb;
	vec3 g2 = texture(grass_tex, uv * 0.37 + vec2(0.31, 0.17)).rgb;
	g = mix(g, g2, 0.4) * grass_tint * (0.82 + 0.36 * n);
	float lum = dot(g, vec3(0.3, 0.59, 0.11));
	g = mix(g, colorize.rgb * lum * 2.0, colorize.a);
	vec3 d = texture(dirt_tex, uv * 1.1 + vec2(n2 * 0.05)).rgb * dirt_tint * (0.9 + 0.2 * n);
	float pw = COLOR.a;
	float edge = smoothstep(0.42, 0.6, pw + (n2 - 0.5) * 0.4);
	vec3 c = mix(g, d, edge);
	c *= 1.0 - 0.28 * smoothstep(0.15, 0.42, pw) * (1.0 - edge);
	c = mix(c, rock_col * (0.75 + 0.5 * n2), clamp(UV2.x, 0.0, 1.0));
	c = mix(c, sand_col * (0.85 + 0.3 * n2), clamp(UV2.y, 0.0, 1.0));
	c *= COLOR.rgb;
	float cl = texture(detail, wpos.xz * 0.011 + vec2(TIME * 0.006, TIME * 0.0035)).r;
	c *= 1.0 - cloud_strength * smoothstep(0.48, 0.72, cl);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""
	return sh

func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(10.0, Z1 - Z0)
	pm.subdivide_depth = 64
	pm.subdivide_width = 6
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(river_x, -0.42, (Z0 + Z1) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode blend_mix, specular_schlick_ggx, cull_disabled, depth_draw_opaque;
uniform float river_x;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// bend with river curve
	VERTEX.x += sin(wpos.z * 0.15) * 1.5;
	VERTEX.y += sin(wpos.z * 1.3 + TIME * 1.6) * 0.03;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = wpos.xz * 0.7;
	float n = vnoise(uv + vec2(0.0, TIME * 0.6)) * 0.6 + vnoise(uv * 2.3 - vec2(TIME * 0.3, TIME * 0.9)) * 0.4;
	float edge = abs(wpos.x - sin(wpos.z * 0.15) * 1.5 - river_x);
	vec3 deep = vec3(0.07, 0.32, 0.45);
	vec3 shallow = vec3(0.22, 0.62, 0.68);
	vec3 c = mix(deep, shallow, smoothstep(0.6, 3.2, edge) * 0.8 + n * 0.25);
	float foam = smoothstep(2.95, 3.35, edge + n * 0.35);
	c = mix(c, vec3(0.85, 0.93, 0.97), foam * 0.55);
	float sparkle = smoothstep(0.78, 0.95, n);
	ALBEDO = c + sparkle * 0.18;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(0.82, 0.95, foam);
	NORMAL_MAP = normalize(vec3(0.5 + (n - 0.5) * 0.4, 0.5 + (vnoise(uv * 3.0 + TIME) - 0.5) * 0.4, 1.0));
}
"""
	mat.shader = s
	mat.set_shader_parameter("river_x", river_x)
	mi.material_override = mat
	mi.name = "Water"
	add_child(mi)

# ---------------------------------------------------------------- vegetation

func _blocked(x: float, z: float, path_clear: float, plot_clear: float) -> bool:
	if path_dist(x, z) < path_clear:
		return true
	for pl in plots:
		if (pl as Vector2).distance_to(Vector2(x, z)) < plot_clear:
			return true
	for k in keepout:
		if Vector2(k.x, k.y).distance_to(Vector2(x, z)) < k.z:
			return true
	if in_river(x, z):
		return true
	return false

func build_grass(count: int) -> void:
	count = int(count * float(THEMES[theme]["tufts"]))
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var xf := []
	var cols := []
	var base: Color = THEMES[theme]["tuft"]
	var tries := 0
	while xf.size() < count and tries < count * 6:
		tries += 1
		var x := rng.randf_range(bounds.position.x - 6.0, bounds.end.x + 6.0)
		var z := rng.randf_range(bounds.position.y - 4.0, bounds.end.y + 5.0)
		if _blocked(x, z, 2.3, 2.1):
			continue
		var h := height_at(x, z)
		if h > 2.5:
			continue
		var s := rng.randf_range(0.6, 1.25)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		xf.append(Transform3D(b, Vector3(x, h - 0.02, z)))
		cols.append(base.lerp(base.lightened(0.25), rng.randf()).lerp(base.darkened(0.2), rng.randf() * 0.5))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft_mesh()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform vec3 tint_a : source_color;
uniform vec3 tint_b : source_color;
varying vec3 tint;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.2 + wp.x * 0.6 + wp.z * 0.4) * 0.12 + sin(TIME * 3.7 + wp.z) * 0.04;
	VERTEX.x += sway * UV.y;
	VERTEX.z += sway * 0.5 * UV.y;
	float n = fract(sin(dot(floor(wp.xz * 0.35), vec2(12.9898, 78.233))) * 43758.5453);
	float n2 = sin(wp.x * 0.21 + cos(wp.z * 0.17) * 2.0) * 0.5 + 0.5;
	tint = mix(tint_a, tint_b, n2 * 0.7 + n * 0.3);
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	ALBEDO = tint * mix(0.6, 1.12, UV.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
}
"""
	mat.shader = s
	mat.set_shader_parameter("tint_a", base.darkened(0.25))
	mat.set_shader_parameter("tint_b", base.lightened(0.18))
	mmi.material_override = mat
	mmi.name = "Grass"
	add_child(mmi)

func _tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var blades := 6
	for b in blades:
		var a := b * TAU / blades + randf() * 0.5
		var r := 0.08
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.045
		var base := dir * r
		var tip := dir * (r + 0.18) + Vector3(0, 0.42 + randf() * 0.18, 0)
		verts.append_array([base - side, base + side, tip])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	nrm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nrm
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func scatter_decor(defs: Array, seed_val: int) -> void:
	## defs: [ [model_name, count, min_spacing, region("edge"/"inner"/"any"), scale_min, scale_max], ... ]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var placed: Array = []  # Vector3(x,z,r)
	for d in defs:
		var name: String = d[0]
		var count: int = d[1]
		var spacing: float = d[2]
		var region: String = d[3]
		var xf := []
		var tries := 0
		while xf.size() < count and tries < count * 40:
			tries += 1
			var x := rng.randf_range(X0 + 4.0, X1 - 4.0)
			var z := rng.randf_range(Z0 + 3.0, Z1 - 2.0)
			var inside := bounds.grow(-1.0).has_point(Vector2(x, z))
			if region == "edge" and inside:
				continue
			if region == "inner" and not inside:
				continue
			if region == "near" and not bounds.grow(4.0).has_point(Vector2(x, z)):
				continue
			if _blocked(x, z, 3.0 if region != "edge" else 3.6, 2.8):
				continue
			var h := height_at(x, z)
			if region == "edge" and h > 6.5:
				continue
			var ok := true
			for p in placed:
				if Vector2(p.x, p.y).distance_to(Vector2(x, z)) < maxf(spacing, p.z):
					ok = false
					break
			if not ok:
				continue
			placed.append(Vector3(x, z, spacing * 0.8))
			var s := rng.randf_range(d[4], d[5])
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			xf.append(Transform3D(b, Vector3(x, h - 0.05, z)))
		if not decor_xf.has(name):
			decor_xf[name] = []
		(decor_xf[name] as Array).append_array(xf)
		# low quality (phones): only trees and houses keep shadow-map shadows; small props skip the shadow pass
		var shadows: bool = region != "tiny" and (Game.high_quality or name.begins_with("tree") or name == "house")
		var mmi := Assets.multimesh(name, xf, self, shadows)
		if mmi and name in ["lamp", "crystals", "house", "barrels", "fence"] and decor_snow > 0.0:
			mmi.material_overlay = Assets.snow_overlay()
		elif mmi and (decor_colorize.a > 0.0 or decor_snow > 0.0):
			var em := Assets.env_material(mmi.multimesh.mesh, decor_colorize, decor_snow)
			if em:
				mmi.material_override = em
