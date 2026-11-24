class_name FX
extends Node3D
## VFX factory v2. Timing follows anticipation -> impact (peak in first 25%) -> quick dissipation.
## Textures: res://assets/fx (glow, spark, star, ring, rune, slash, crack, beam, flipbooks).

var hq := true
var _meshes := {}
var _frost_mat: StandardMaterial3D
var _ring_mesh: QuadMesh
var _flat: QuadMesh
var _grad_cache := {}
var _curve_cache := {}
var _lights := 0
var _cam: Camera3D

func _ready() -> void:
	hq = Game.high_quality
	_frost_mat = StandardMaterial3D.new()
	_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frost_mat.albedo_color = Color(0.4, 0.75, 1.0, 0.5)
	_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frost_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flat = QuadMesh.new()
	_flat.orientation = PlaneMesh.FACE_Y
	_flat.size = Vector2(1, 1)

func frost_overlay() -> Material:
	return _frost_mat

static func tex(n: String) -> Texture2D:
	var p := "res://assets/fx/%s.png" % n
	return load(p) if ResourceLoader.exists(p) else Assets.soft_dot()

## particle quad mesh for a texture/blend combination (cached)
func _pmesh(t: String, additive := true, flip := false) -> QuadMesh:
	var key := "%s_%s_%s" % [t, additive, flip]
	if _meshes.has(key):
		return _meshes[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(t)
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if flip:
		m.particles_anim_h_frames = 4
		m.particles_anim_v_frames = 4
		m.particles_anim_loop = false
	var q := QuadMesh.new()
	q.material = m
	_meshes[key] = q
	return q

func _grad(key: String, cols: Array) -> Gradient:
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g := Gradient.new()
	g.remove_point(1)
	g.set_color(0, cols[0])
	for i in range(1, cols.size()):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	_grad_cache[key] = g
	return g

## punchy scale curve: fast pop then shrink (impact in first quarter)
func _curve(kind: String) -> Curve:
	if _curve_cache.has(kind):
		return _curve_cache[kind]
	var c := Curve.new()
	match kind:
		"pop":
			c.add_point(Vector2(0, 0.3)); c.add_point(Vector2(0.15, 1.0)); c.add_point(Vector2(1, 0.0))
		"grow":
			c.add_point(Vector2(0, 0.4)); c.add_point(Vector2(1, 1.0))
		"puff":
			c.add_point(Vector2(0, 0.5)); c.add_point(Vector2(0.3, 1.0)); c.add_point(Vector2(1, 1.15))
		_:
			c.add_point(Vector2(0, 1.0)); c.add_point(Vector2(1, 0.0))
	_curve_cache[kind] = c
	return c

func _burst(pos: Vector3, amount: int, life: float, mesh: Mesh, grad: Gradient, vmin: float, vmax: float, spread: float,
		size_min: float, size_max: float, gravity := Vector3.ZERO, dir := Vector3.UP, radius := 0.1, curve := "shrink",
		damp := 0.0, flip := false, explosiveness := 0.95) -> CPUParticles3D:
	if not hq:
		amount = maxi(int(amount * 0.6), 1)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = explosiveness
	p.randomness = 0.4
	p.mesh = mesh
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravity
	p.damping_min = damp
	p.damping_max = damp
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.scale_amount_curve = _curve(curve)
	p.color_ramp = grad
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	if flip:
		p.anim_speed_min = 1.0
		p.anim_speed_max = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
	return p

func _flat_decal(pos: Vector3, t: String, size: float, col: Color, additive: bool, life: float, grow := 0.0, spin := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _flat
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex(t)
	m.albedo_color = col
	m.disable_receive_shadows = true
	m.no_depth_test = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var h := LevelMain.I.terrain.height_at(pos.x, pos.z) if LevelMain.I else pos.y
	mi.global_position = Vector3(pos.x, maxf(pos.y, h) + 0.08, pos.z)
	mi.scale = Vector3.ONE * size
	var tw := mi.create_tween().set_parallel(true)
	if grow != 0.0:
		tw.tween_property(mi, "scale", Vector3.ONE * size * (1.0 + grow), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if spin != 0.0:
		tw.tween_property(mi, "rotation:y", spin, life)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)
	return mi

func light_flash(pos: Vector3, c: Color, energy := 3.0, rng := 6.0, life := 0.25) -> void:
	if not hq or _lights >= 4:
		return
	_lights += 1
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos + Vector3(0, 0.8, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_lights -= 1
		l.queue_free())

# ------------------------------------------------------------------ small hits

func hit_spark(pos: Vector3, c: Color, s := 1.0) -> void:
	_burst(pos, 5, 0.28, _pmesh("fx_glow"), _grad("hs" + c.to_html(), [Color(1, 1, 1, 1), c, Color(c.r, c.g * 0.6, 0.1, 0)]), 2.5, 6.0, 85.0,
		0.12 * s, 0.24 * s, Vector3(0, -8, 0), Vector3.UP, 0.05, "pop")
	_burst(pos, 1, 0.16, _pmesh("fx_star"), _grad("hst" + c.to_html(), [Color(1, 1, 1, 1), Color(c.r, c.g, c.b, 0)]), 0.0, 0.0, 0.0,
		0.55 * s, 0.7 * s, Vector3.ZERO, Vector3.UP, 0.0, "pop")

func magic_burst(pos: Vector3, c: Color, s := 1.0) -> void:
	_burst(pos, 12, 0.45, _pmesh("fx_glow"), _grad("mb" + c.to_html(), [Color(1, 1, 1, 1), c, Color(c.r, c.g, c.b, 0)]), 1.0, 3.5 * s, 180.0,
		0.18 * s, 0.42 * s, Vector3.ZERO, Vector3.UP, 0.1, "pop", 3.0)
	_burst(pos, 3, 0.35, _pmesh("fx_star"), _grad("mbs" + c.to_html(), [Color(1, 1, 1, 1), Color(c.r, c.g, c.b, 0)]), 0.5, 1.5, 180.0,
		0.5 * s, 0.9 * s, Vector3.ZERO, Vector3.UP, 0.2, "pop")
	_burst(pos, 1, 0.25, _pmesh("fx_ring"), _grad("mbr" + c.to_html(), [Color(c.r, c.g, c.b, 0.9), Color(c.r, c.g, c.b, 0)]), 0.0, 0.0, 0.0,
		0.6 * s, 0.6 * s, Vector3.ZERO, Vector3.UP, 0.0, "grow")

func heal(pos: Vector3) -> void:
	_burst(pos, 8, 0.9, _pmesh("fx_star"), _grad("heal", [Color(0.7, 1, 0.6, 1), Color(0.3, 1, 0.4, 0)]), 0.5, 1.4, 25.0, 0.25, 0.4,
		Vector3(0, 1.5, 0), Vector3.UP, 0.4, "pop")

func burn_puff(pos: Vector3) -> void:
	_burst(pos, 2, 0.55, _pmesh("fx_fire_flip", true, true), _grad("burnf", [Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)]), 0.5, 1.4, 30.0,
		0.4, 0.65, Vector3(0, 2.5, 0), Vector3.UP, 0.25, "puff", 0.0, true)

func dust(pos: Vector3, s := 1.0) -> void:
	_burst(pos + Vector3(0, 0.25, 0), 9, 1.1, _pmesh("fx_smoke_flip", false, true), _grad("dust", [Color(0.85, 0.75, 0.6, 0.85), Color(0.8, 0.72, 0.6, 0.6), Color(0.75, 0.7, 0.62, 0)]),
		1.5 * s, 4.0 * s, 75.0, 0.9 * s, 1.5 * s, Vector3(0, 0.3, 0), Vector3.UP, 0.4 * s, "puff", 3.5, true)

func smoke(pos: Vector3, s := 1.0) -> void:
	_burst(pos, 6, 1.3, _pmesh("fx_smoke_flip", false, true), _grad("smoke", [Color(0.95, 0.95, 0.95, 0.75), Color(0.6, 0.6, 0.6, 0)]),
		0.5, 1.8, 30.0, 0.7 * s, 1.2 * s, Vector3(0, 1.4, 0), Vector3.UP, 0.2, "puff", 1.0, true)

func muzzle_flash(pos: Vector3, dir: Vector3, c := Color(1.0, 0.7, 0.3)) -> void:
	_burst(pos, 1, 0.12, _pmesh("fx_star"), _grad("mz" + c.to_html(), [Color(1, 1, 0.9, 1), Color(c.r, c.g, c.b, 0)]), 0.0, 0.0, 0.0,
		1.6, 1.8, Vector3.ZERO, Vector3.UP, 0.0, "pop")
	_burst(pos, 5, 0.4, _pmesh("fx_fire_flip", true, true), _grad("mzf", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]), 2.0, 4.0, 18.0,
		0.5, 0.9, Vector3.ZERO, dir.normalized(), 0.1, "pop", 6.0, true)
	smoke(pos + dir.normalized() * 0.5, 0.9)
	light_flash(pos, c, 2.5, 5.0, 0.15)

# ------------------------------------------------------------------ big impacts

func explosion(pos: Vector3, s := 1.0) -> void:
	var p := pos + Vector3(0, 0.35, 0)
	# impact flash
	_burst(p, 1, 0.14, _pmesh("fx_glow"), _grad("exfl", [Color(1, 0.95, 0.8, 1), Color(1, 0.6, 0.2, 0)]), 0.0, 0.0, 0.0,
		3.2 * s, 3.6 * s, Vector3.ZERO, Vector3.UP, 0.0, "pop")
	# fireball flipbook puffs
	_burst(p, 9, 0.75, _pmesh("fx_explosion_flip", true, true), _grad("exf", [Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)]),
		1.5 * s, 4.0 * s, 180.0, 1.0 * s, 1.8 * s, Vector3(0, 2.5, 0), Vector3.UP, 0.4 * s, "puff", 5.0, true)
	# smoke column
	_burst(p + Vector3(0, 0.4, 0), 7, 1.8, _pmesh("fx_smoke_flip", false, true), _grad("exs", [Color(0.35, 0.32, 0.3, 0.0), Color(0.3, 0.28, 0.27, 0.8), Color(0.25, 0.24, 0.24, 0)]),
		0.8 * s, 2.2 * s, 60.0, 1.4 * s, 2.2 * s, Vector3(0, 1.6, 0), Vector3.UP, 0.6 * s, "puff", 1.5, true, 0.85)
	# glowing debris with gravity
	_burst(p, 12, 0.9, _pmesh("fx_glow"), _grad("exd", [Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 1), Color(0.5, 0.1, 0.0, 0)]),
		5.0 * s, 10.0 * s, 65.0, 0.12, 0.2, Vector3(0, -16, 0), Vector3.UP, 0.25, "shrink")
	shockwave(pos, 2.6 * s, Color(1.0, 0.75, 0.4))
	_flat_decal(pos, "fx_crack", 2.2 * s, Color(1, 1, 1, 0.85), false, 4.0)
	light_flash(p, Color(1.0, 0.6, 0.25), 4.0 * s, 8.0 * s, 0.35)

## Danger zone for a telegraphed attack: a ring marks the edge while a disc fills toward it,
## landing exactly when the blow does.
func telegraph(pos: Vector3, r: float, t: float, c: Color) -> void:
	t = maxf(t, 0.15)
	var h := LevelMain.I.terrain.height_at(pos.x, pos.z) if LevelMain.I else pos.y
	var at := Vector3(pos.x, maxf(pos.y, h) + 0.1, pos.z)
	var parts := []
	for kind in ["fx_ring", "fx_glow"]:
		var mi := MeshInstance3D.new()
		mi.mesh = _flat
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = tex(kind)
		m.albedo_color = Color(c.r, c.g, c.b, 0.0)
		m.disable_receive_shadows = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = at
		parts.append([mi, m])
	var ring: MeshInstance3D = parts[0][0]
	var rm: StandardMaterial3D = parts[0][1]
	var disc: MeshInstance3D = parts[1][0]
	var dm: StandardMaterial3D = parts[1][1]
	ring.scale = Vector3.ONE * r * 2.2
	disc.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(rm, "albedo_color:a", 0.9, 0.12)
	tw.tween_property(dm, "albedo_color:a", 0.55, t)
	tw.tween_property(disc, "scale", Vector3.ONE * r * 2.6, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(rm, "albedo_color:a", 0.0, 0.25)
	tw.parallel().tween_property(dm, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(func():
		ring.queue_free()
		disc.queue_free())

## Persistent bonfire: looping flames + smoke and a flickering warm light.
func campfire(pos: Vector3) -> void:
	var fire := CPUParticles3D.new()
	fire.amount = 16 if hq else 9
	fire.lifetime = 0.9
	fire.mesh = _pmesh("fx_fire_flip", true, true)
	fire.direction = Vector3.UP
	fire.spread = 12.0
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 1.4
	fire.gravity = Vector3(0, 1.2, 0)
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.1
	fire.scale_amount_curve = _curve("puff")
	fire.color_ramp = _grad("campf", [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1), Color(1, 0.9, 0.8, 0)])
	fire.anim_speed_min = 1.0
	fire.anim_speed_max = 1.0
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.3
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fire)
	fire.global_position = pos
	var sm := CPUParticles3D.new()
	sm.amount = 6 if hq else 3
	sm.lifetime = 3.0
	sm.mesh = _pmesh("fx_smoke_flip", false, true)
	sm.direction = Vector3.UP
	sm.spread = 15.0
	sm.initial_velocity_min = 0.5
	sm.initial_velocity_max = 1.0
	sm.gravity = Vector3(0.25, 0.5, 0)
	sm.scale_amount_min = 1.0
	sm.scale_amount_max = 1.6
	sm.scale_amount_curve = _curve("puff")
	sm.color_ramp = _grad("camps", [Color(0.4, 0.38, 0.36, 0.0), Color(0.35, 0.33, 0.32, 0.45), Color(0.3, 0.3, 0.3, 0)])
	sm.anim_speed_min = 1.0
	sm.anim_speed_max = 1.0
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sm)
	sm.global_position = pos + Vector3(0, 1.0, 0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.28)
	l.light_energy = 2.0
	l.omni_range = 8.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos + Vector3(0, 1.0, 0)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 2.5, 0.23).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 1.7, 0.31).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 2.2, 0.19).set_trans(Tween.TRANS_SINE)

## Celebration rocket burst high above the field.
func firework(pos: Vector3, c: Color) -> void:
	var g := _grad("fw" + c.to_html(), [Color(1, 1, 1, 1), c, Color(c.r, c.g, c.b, 0)])
	_burst(pos, 1, 0.25, _pmesh("fx_glow"), g, 0.0, 0.0, 0.0, 3.0, 3.6, Vector3.ZERO, Vector3.UP, 0.0, "pop")
	_burst(pos, 46, 1.5, _pmesh("fx_spark"), g, 5.0, 8.0, 180.0, 0.16, 0.3, Vector3(0, -3.5, 0), Vector3.UP, 0.2, "shrink", 1.6)
	_burst(pos, 14, 1.1, _pmesh("fx_star"), _grad("fws" + c.to_html(), [Color(1, 1, 1, 1), Color(c.r, c.g, c.b, 0)]), 2.0, 4.5, 180.0,
		0.3, 0.5, Vector3(0, -2.0, 0), Vector3.UP, 0.3, "pop", 1.0)
	light_flash(pos, c, 5.0, 16.0, 0.5)

func shockwave(pos: Vector3, r: float, c: Color) -> void:
	_flat_decal(pos, "fx_ring", r * 0.4, Color(c.r, c.g, c.b, 1.0), true, 0.45, 2.6)

func fire_ring(pos: Vector3, r: float) -> void:
	shockwave(pos, r, Color(1.0, 0.55, 0.15))
	_flat_decal(pos, "fx_slash", r * 2.0, Color(1.0, 0.6, 0.2, 1.0), true, 0.4, 0.15, TAU * 1.5)
	var n := 16 if hq else 9
	for i in n:
		var a := i * TAU / n
		_burst(pos + Vector3(cos(a), 0.3, sin(a)) * r * 0.8, 2, 0.6, _pmesh("fx_fire_flip", true, true), _grad("fr", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]),
			0.5, 1.8, 25.0, 0.6, 0.9, Vector3(0, 3, 0), Vector3.UP, 0.1, "puff", 0.0, true)
	light_flash(pos, Color(1.0, 0.55, 0.2), 3.5, 7.0, 0.4)

func slash_arc(pos: Vector3, c: Color, size := 1.6) -> void:
	_flat_decal(pos + Vector3(0, 0.9, 0), "fx_slash", size, c, true, 0.22, 0.25, randf_range(-PI, PI))

func build_poof(pos: Vector3) -> void:
	dust(pos, 1.4)
	_burst(pos + Vector3(0, 0.6, 0), 10, 0.9, _pmesh("fx_glow"), _grad("wood", [Color(1.0, 0.8, 0.5, 1), Color(0.8, 0.5, 0.2, 0)]), 3.0, 6.5, 55.0,
		0.1, 0.18, Vector3(0, -12, 0), Vector3.UP, 0.4)
	_burst(pos + Vector3(0, 1.5, 0), 10, 1.0, _pmesh("fx_star"), _grad("bstar", [Color(1, 0.95, 0.7, 1), Color(1, 0.85, 0.4, 0)]), 0.5, 2.0, 180.0,
		0.3, 0.55, Vector3(0, 0.5, 0), Vector3.UP, 1.2, "pop")
	Audio.play("build", -3.0, 0.08)

func upgrade_beam(pos: Vector3, c := Color(1.0, 0.85, 0.4)) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.6
	cm.height = 9.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex("fx_beam")
	m.uv1_scale = Vector3(1, 1, 1)
	m.albedo_color = Color(c.r, c.g, c.b, 0.9)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 4.5, 0)
	mi.scale = Vector3(0.3, 1, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(mi.queue_free)
	_burst(pos + Vector3(0, 0.5, 0), 22, 1.4, _pmesh("fx_star"), _grad("upst", [Color(1, 1, 0.85, 1), Color(c.r, c.g, c.b, 0.8), Color(c.r, c.g, c.b, 0)]),
		2.0, 5.0, 12.0, 0.3, 0.6, Vector3(0, -1.0, 0), Vector3.UP, 1.4, "pop")
	_flat_decal(pos, "fx_rune", 3.6, Color(c.r, c.g, c.b, 1.0), true, 1.0, 0.2, PI)
	light_flash(pos, c, 3.0, 8.0, 0.6)

func level_up(n: Node3D) -> void:
	upgrade_beam(n.global_position, Color(1.0, 0.8, 0.35))

func move_marker(p: Vector3) -> void:
	_flat_decal(p, "fx_ring", 0.8, Color(0.45, 1.0, 0.55, 1.0), true, 0.5, 0.8)
	_burst(p + Vector3(0, 0.1, 0), 6, 0.5, _pmesh("fx_star"), _grad("mm", [Color(0.7, 1, 0.7, 1), Color(0.3, 1, 0.4, 0)]), 1.0, 2.0, 20.0, 0.2, 0.35,
		Vector3.ZERO, Vector3.UP, 0.4, "pop")

func stun_stars(n: Node3D) -> void:
	var p := _burst(n.global_position + Vector3(0, 2.0, 0), 5, 1.4, _pmesh("fx_star"), _grad("stun", [Color(1, 1, 0.4, 1), Color(1, 0.9, 0.3, 0)]),
		0.3, 0.6, 90.0, 0.25, 0.35, Vector3.ZERO, Vector3.UP, 0.4, "shrink", 0.0, false, 0.6)
	p.orbit_velocity_min = 1.0
	p.orbit_velocity_max = 1.2

func frost_nova(pos: Vector3, r: float) -> void:
	shockwave(pos, r, Color(0.55, 0.9, 1.0))
	_flat_decal(pos, "fx_rune", r * 1.6, Color(0.5, 0.9, 1.0, 1.0), true, 0.8, 0.1, -PI * 0.5)
	_burst(pos + Vector3(0, 0.4, 0), 16, 0.8, _pmesh("fx_star"), _grad("frost", [Color(1, 1, 1, 1), Color(0.5, 0.85, 1, 0.8), Color(0.3, 0.6, 1, 0)]),
		2.0, 4.5, 180.0, 0.25, 0.45, Vector3(0, -2, 0), Vector3.UP, 0.3, "pop", 2.0)
	ice_shards(pos, r * 0.7)

func ice_shards(pos: Vector3, r: float) -> void:
	var n := 6 if hq else 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.92, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.8
	mat.roughness = 0.1
	for i in n:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.35, 1.0, 0.35)
		mi.mesh = pm
		mi.material_override = mat
		add_child(mi)
		var a := i * TAU / n + randf() * 0.5
		var d := randf_range(0.3, r)
		var gp := pos + Vector3(cos(a) * d, 0, sin(a) * d)
		gp.y = LevelMain.I.terrain.height_at(gp.x, gp.z)
		mi.global_position = gp
		mi.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		mi.scale = Vector3(1, 0.01, 1)
		var h := randf_range(0.7, 1.4)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1, h, 1), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.6)
		tw.tween_property(mi, "scale", Vector3(0.2, 0.01, 0.2), 0.35)
		tw.tween_callback(mi.queue_free)

func rune_circle(pos: Vector3, c: Color, size := 1.6, life := 0.6) -> void:
	_flat_decal(pos, "fx_rune", size, Color(c.r, c.g, c.b, 1.0), true, life, 0.15, PI * 0.6)

func charge(pos: Vector3, c: Color, t := 0.35) -> void:
	## anticipation: particles converge into the cast point
	var p := _burst(pos, 8, t, _pmesh("fx_glow"), _grad("ch" + c.to_html(), [Color(c.r, c.g, c.b, 0), Color(1, 1, 1, 1)]), 0.0, 0.0, 0.0,
		0.12, 0.22, Vector3.ZERO, Vector3.UP, 0.9, "grow", 0.0, false, 0.6)
	p.radial_accel_min = -12.0
	p.radial_accel_max = -10.0

func lightning(a: Vector3, b: Vector3, c: Color) -> void:
	if _cam == null and LevelMain.I:
		_cam = LevelMain.I.cam_rig.cam
	var holder := Node3D.new()
	add_child(holder)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex("fx_beam")
	m.albedo_color = c.lightened(0.35)
	var segs := 8
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t)
		if i < segs:
			p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.45
		for w in [0.55, 0.22]:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1, w)
			mi.mesh = q
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			var dir := p - prev
			var l := dir.length()
			if l < 0.001:
				continue
			var xa := dir / l
			var to_cam := (_cam.global_position - (prev + p) * 0.5).normalized() if _cam else Vector3.UP
			var ya := to_cam.cross(xa).normalized()
			var za := xa.cross(ya)
			mi.global_transform = Transform3D(Basis(xa * l, ya, za), (prev + p) * 0.5)
		prev = p
	_burst(b, 4, 0.25, _pmesh("fx_star"), _grad("lt" + c.to_html(), [Color(1, 1, 1, 1), Color(c.r, c.g, c.b, 0)]), 0.5, 1.5, 180.0, 0.4, 0.7)
	light_flash(b, c, 2.5, 5.0, 0.18)
	var tw := holder.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25).set_delay(0.05)
	tw.tween_callback(holder.queue_free)

func trail(parent: Node3D, c: Color, size: float, smoky := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18 if hq else 9
	p.lifetime = 0.35 if not smoky else 0.7
	p.local_coords = false
	p.mesh = _pmesh("fx_glow") if not smoky else _pmesh("fx_smoke_flip", false, true)
	if smoky:
		p.anim_speed_min = 1.0
		p.anim_speed_max = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = size * 0.8
	p.scale_amount_max = size * 1.2
	p.scale_amount_curve = _curve("shrink")
	if smoky:
		p.color_ramp = _grad("tr_smoke", [Color(0.9, 0.9, 0.9, 0.55), Color(0.5, 0.5, 0.5, 0)])
	else:
		p.color_ramp = _grad("tr" + c.to_html(), [Color(1, 1, 1, 1), c, Color(c.r, c.g, c.b, 0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p

func detach_trail(p: CPUParticles3D) -> void:
	if not is_instance_valid(p):
		return
	var gp := p.global_position
	p.get_parent().remove_child(p)
	add_child(p)
	p.global_position = gp
	p.emitting = false
	get_tree().create_timer(p.lifetime + 0.2, false).timeout.connect(p.queue_free)

func scorch(pos: Vector3, r: float) -> void:
	_flat_decal(pos, "fx_crack", r * 2.4, Color(1, 1, 1, 0.95), false, 7.0)

func soul(pos: Vector3, c := Color(0.75, 0.7, 1.0)) -> void:
	_burst(pos, 3, 1.0, _pmesh("fx_glow"), _grad("soul" + c.to_html(), [Color(c.r, c.g, c.b, 0), Color(c.r, c.g, c.b, 0.7), Color(c.r, c.g, c.b, 0)]),
		1.0, 1.8, 15.0, 0.3, 0.5, Vector3(0, 1.2, 0), Vector3.UP, 0.25, "grow")

func coin_burst(pos: Vector3, n := 3) -> void:
	_burst(pos + Vector3(0, 0.6, 0), n, 0.7, _pmesh("fx_star"), _grad("coin", [Color(1, 0.95, 0.5, 1), Color(1, 0.75, 0.2, 0)]), 2.5, 4.0, 35.0,
		0.25, 0.4, Vector3(0, -9, 0), Vector3.UP, 0.1, "pop")

func fire_patch(pos: Vector3, r: float, dps: float) -> void:
	var node := FirePatch.new()
	node.radius = r
	node.dps = dps
	add_child(node)
	node.global_position = pos
	var p := CPUParticles3D.new()
	p.amount = 16 if hq else 8
	p.lifetime = 0.8
	p.mesh = _pmesh("fx_fire_flip", true, true)
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.7
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _curve("puff")
	p.color_ramp = _grad("fp", [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(p)
	p.emitting = true
	_flat_decal(pos, "fx_glow", r * 2.2, Color(1.0, 0.45, 0.1, 0.6), true, 4.0)

## world-space ambient emitter that follows the camera target (leaves, snow, fireflies, embers)
func ambient(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70 if hq else 30
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(34, 1, 24)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		"snow":
			p.amount = 220 if hq else 90
			p.mesh = _pmesh("fx_snow", false)
			p.gravity = Vector3(0.6, -1.6, 0.3)
			p.initial_velocity_min = 0.0
			p.initial_velocity_max = 0.4
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.24
			p.color_ramp = _grad("amb_snow", [Color(1, 1, 1, 0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
			p.position.y = 12.0
		"leaves":
			p.mesh = _pmesh("fx_leaf", false)
			p.gravity = Vector3(0.9, -0.9, 0.2)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.32
			p.angular_velocity_min = -180
			p.angular_velocity_max = 180
			p.color_ramp = _grad("amb_leaf", [Color(1.0, 0.6, 0.2, 0), Color(1.0, 0.55, 0.15, 1), Color(0.9, 0.35, 0.1, 1), Color(0.8, 0.3, 0.1, 0)])
			p.position.y = 10.0
		"fireflies":
			p.mesh = _pmesh("fx_glow")
			p.gravity = Vector3.ZERO
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.spread = 180.0
			p.scale_amount_min = 0.18
			p.scale_amount_max = 0.3
			p.color_ramp = _grad("amb_ff", [Color(0.8, 1.0, 0.4, 0), Color(0.8, 1.0, 0.4, 1), Color(0.6, 1.0, 0.3, 0.2), Color(0.8, 1.0, 0.4, 1), Color(0.8, 1.0, 0.4, 0)])
			p.position.y = 1.5
			p.emission_box_extents = Vector3(34, 1.2, 24)
		"motes":
			p.amount = 40 if hq else 16
			p.mesh = _pmesh("fx_glow")
			p.gravity = Vector3(0.1, 0.05, 0)
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
			p.spread = 180.0
			p.scale_amount_min = 0.06
			p.scale_amount_max = 0.12
			p.color_ramp = _grad("amb_mote", [Color(1, 1, 0.9, 0), Color(1, 1, 0.85, 0.7), Color(1, 1, 0.9, 0)])
			p.position.y = 2.5
		"embers":
			p.mesh = _pmesh("fx_glow")
			p.gravity = Vector3(0.2, 0.9, 0)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.16
			p.color_ramp = _grad("amb_emb", [Color(1, 0.6, 0.2, 0), Color(1, 0.55, 0.15, 1), Color(1, 0.3, 0.1, 0)])
			p.position.y = 0.5
	add_child(p)
	p.emitting = true
	return p

class FirePatch extends Node3D:
	var radius := 2.0
	var dps := 10.0
	var life := 4.0
	var _tick := 0.0
	func _process(delta: float) -> void:
		life -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for e: Enemy in LevelMain.I.enemies:
				if e.alive and not e.flying and e.global_position.distance_to(global_position) < radius:
					e.burn(dps, 1.5)
		if life <= 0.0:
			for c in get_children():
				if c is CPUParticles3D:
					c.emitting = false
			if life < -0.9:
				queue_free()
