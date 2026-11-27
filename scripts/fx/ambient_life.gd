class_name AmbientLife
extends Node3D
## Things that move on the map by themselves, so a level does not look frozen between waves:
##  - flocks crossing the sky every so often (small birds by day, gulls over rivers, bats on the dark
##    maps): wing beats come from a vertex shader, one cheap mesh per bird
##  - chimney smoke rising from the cottages
## Nothing here touches the game; it is skipped on low quality where it would cost frames.

const FLOCK_GAP := Vector2(12.0, 26.0)    # seconds between two flocks
const KINDS := {
	# colour, wing span (m), flap speed (rad/s), flap depth, cruise speed (m/s), height, flock size
	"bird": [Color(0.16, 0.13, 0.11), 0.8, 15.0, 0.55, 6.5, 8.5, Vector2i(5, 9)],
	"gull": [Color(0.93, 0.93, 0.9), 1.15, 9.0, 0.45, 5.5, 9.5, Vector2i(3, 6)],
	"bat": [Color(0.07, 0.05, 0.08), 0.9, 24.0, 0.8, 7.5, 7.0, Vector2i(6, 11)],
}
const THEME_KIND := {"meadow": "bird", "autumn": "bird", "river": "gull", "snow": "", "night": "bat",
	"swamp": "bat", "necro": "bat", "ruins": "bird"}

var bounds := Rect2(-30, -18, 60, 34)
var kind := ""
var _next := 2.5
var _flocks: Array = []
static var _mat_cache := {}

## Adds the ambient life for a level: its flock kind by theme and smoke over its houses.
static func make(parent: Node3D, theme: String, p_bounds: Rect2, houses: Array, hq: bool) -> AmbientLife:
	var a := AmbientLife.new()
	a.name = "AmbientLife"
	a.bounds = p_bounds
	a.kind = THEME_KIND.get(theme, "")
	parent.add_child(a)
	var n := 0
	for xf: Transform3D in houses:
		if n >= (3 if hq else 1):
			break
		a._chimney(xf, theme)
		n += 1
	return a

func _process(delta: float) -> void:
	if kind != "":
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(FLOCK_GAP.x, FLOCK_GAP.y)
			_spawn_flock()
	var keep: Array = []
	for f: Dictionary in _flocks:
		var root: Node3D = f["root"]
		if not is_instance_valid(root):
			continue
		root.position += f["vel"] * delta
		var t := float(f["t"]) + delta
		f["t"] = t
		# the flock drifts a little and each bird bobs on its own
		for i in root.get_child_count():
			var b := root.get_child(i) as Node3D
			var off: Vector3 = f["offs"][i]
			b.position = off + Vector3(0, sin(t * 1.3 + i * 1.7) * 0.35, cos(t * 0.9 + i) * 0.4)
		if t > float(f["life"]):
			root.queue_free()
		else:
			keep.append(f)
	_flocks = keep

func _spawn_flock() -> void:
	var k: Array = KINDS[kind]
	var dir := Vector2.from_angle(randf() * TAU)
	var h: float = float(k[5]) + randf_range(-1.0, 1.5)
	var c := _view_centre(h)
	var half := 30.0
	# enters at one side, crosses what the camera is looking at (a little off centre), leaves at the other
	var across := Vector2(-dir.y, dir.x) * randf_range(-6.0, 6.0)
	var start := c - dir * half + across
	var speed: float = float(k[4]) * randf_range(0.85, 1.15)
	var root := Node3D.new()
	root.position = Vector3(start.x, h, start.y)
	root.rotation.y = atan2(-dir.x, -dir.y)
	add_child(root)
	var n := randi_range(int(k[6].x), int(k[6].y))
	var offs := []
	for i in n:
		# a loose V behind the leader
		var row := (i + 1) / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var off := Vector3(side * row * 0.9 * randf_range(0.8, 1.3), randf_range(-0.4, 0.4), row * 1.1 * randf_range(0.8, 1.2))
		if i == 0:
			off = Vector3.ZERO
		offs.append(off)
		var b := MeshInstance3D.new()
		b.mesh = _bird_mesh(float(k[1]))
		b.material_override = _material(kind)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = off
		root.add_child(b)
	_flocks.append({"root": root, "vel": Vector3(dir.x, 0, dir.y) * speed, "t": 0.0, "offs": offs,
		"life": half * 2.0 / speed})

## Where the camera's line of sight passes height h (a flock there crosses the middle of the
## screen); the middle of the map when there is no camera.
func _view_centre(h: float) -> Vector2:
	var L := LevelMain.I
	if L == null or L.cam_rig == null or L.cam_rig.cam == null:
		return bounds.get_center()
	var t: Vector3 = L.cam_rig.target
	var d: Vector3 = L.cam_rig.cam.global_position - t
	if d.y < 0.5:
		return Vector2(t.x, t.z)
	var p := t + d * clampf((h - t.y) / d.y, 0.0, 1.0)
	return Vector2(p.x, p.z)

## One bird of a kind, standing still (shader warm-up draws it once so its program is compiled).
static func probe(k: String, at: Vector3) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var d: Array = KINDS.get(k if k != "" else "bird", KINDS["bird"])
	b.mesh = _bird_mesh(float(d[1]))
	b.material_override = _material(k if KINDS.has(k) else "bird")
	b.position = at
	return b

## Two wings and a sliver of body; the wing tips carry UV.x = 1 so the shader knows what to flap.
static func _bird_mesh(span: float) -> ArrayMesh:
	var key := "bird_%.2f" % span
	if _mat_cache.has(key):
		return _mat_cache[key]
	var w := span * 0.5
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	for s in [-1.0, 1.0]:
		# wing: root front, root back, tip (swept back)
		v.append_array([Vector3(0, 0, -0.12), Vector3(0, 0, 0.1), Vector3(s * w, 0, 0.12)])
		uv.append_array([Vector2(0, 0), Vector2(0, 0), Vector2(1, 0)])
	# body
	v.append_array([Vector3(-0.04, 0, -0.18), Vector3(0.04, 0, -0.18), Vector3(0, 0, 0.22)])
	uv.append_array([Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mat_cache[key] = m
	return m

const BIRD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 col : source_color;
uniform float flap_speed = 15.0;
uniform float flap_depth = 0.5;
void vertex() {
	// each bird beats out of step with its neighbours (phase from where it is)
	float ph = NODE_POSITION_WORLD.x * 1.7 + NODE_POSITION_WORLD.z * 2.3;
	float beat = sin(TIME * flap_speed + ph);
	// glide now and then: the beat fades in and out slowly
	float glide = 0.35 + 0.65 * smoothstep(-0.3, 0.4, sin(TIME * 0.7 + ph));
	VERTEX.y += UV.x * beat * flap_depth * glide * abs(VERTEX.x) * 2.0;
}
void fragment() {
	ALBEDO = col.rgb;
}
"""

static func _material(k: String) -> ShaderMaterial:
	var key := "mat_" + k
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = BIRD_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var d: Array = KINDS[k]
	m.set_shader_parameter("col", d[0])
	m.set_shader_parameter("flap_speed", d[2])
	m.set_shader_parameter("flap_depth", d[3])
	_mat_cache[key] = m
	return m

## A thin column of smoke from a cottage roof, leaning with the wind.
func _chimney(xf: Transform3D, theme: String) -> void:
	var top := 4.68
	var mesh := Assets.mesh("house")
	if mesh:
		top = mesh.get_aabb().end.y
	var p := CPUParticles3D.new()
	p.mesh = LevelMain.I.fx._pmesh("fx_smoke_flip", false, true) if LevelMain.I else null
	p.amount = 12
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.fixed_fps = 20
	p.local_coords = false
	p.direction = Vector3(0.12, 1, 0.05)
	p.spread = 7.0
	p.gravity = Vector3(0.18, 0.2, 0.06)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.75
	p.scale_amount_max = 1.0
	# only the dense first half of the flipbook (its later frames fade out on their own, and the
	# colour ramp below already does the fading)
	p.anim_speed_min = 0.45
	p.anim_speed_max = 0.55
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.55))
	curve.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	# the smoke texture is mid grey; lifted past 1 so the smoke reads as light against the grass
	# and not as a smudge
	var cl := Color(1.9, 1.87, 1.82) if theme != "snow" else Color(1.7, 1.75, 1.85)
	g.set_color(0, Color(cl, 0.0))
	g.set_color(1, Color(cl, 0.0))
	g.add_point(0.08, Color(cl, 0.8))
	g.add_point(0.5, Color(cl, 0.45))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the stone chimney at the cottage's back gable (house.glb: top centre about (0.58, 4.6, -1.3))
	p.position = xf.origin + xf.basis * Vector3(0.58, top - 0.1, -1.3)
	add_child(p)
	p.emitting = true
