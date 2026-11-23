class_name LevelMain
extends Node3D
## Level controller: world building, waves, economy, selection/build UI flow, spells, win/lose.

static var I: LevelMain

var level_idx := 0
var def: Dictionary
var terrain: Terrain
var paths: Array = []
var world: Node3D
var fx: FX
var cam_rig: CameraRig
var hud: HUD
var overlay: Overlay
var hero: Hero
var enemies: Array = []
var soldiers: Array = []
var towers := {}
var plots: Array = []
var gold := 0
var lives := 20
var wave_idx := -1
var waves: Array = []
var groups: Array = []
var wave_timer := 0.0
var wave_wait := 22.0
var state := "ready"
var selection := {}
var targeting := ""
var spell_cd := {"meteor": 0.0, "reinforce": 0.0}
var fast := false
var enemy_dmg_mult := 1.0
var hp_mult := 1.0
var range_ring: MeshInstance3D
var seen := {}
var tutorial_step := -1
var _time := 0.0
var _modal: Control
var _info_card: Control
var _sun: DirectionalLight3D
var max_lives := 20
var spell_defs := {}

func _ready() -> void:
	I = self
	level_idx = Game.current_level
	def = DB.LEVELS[level_idx]
	gold = def["gold"]
	lives = def["lives"]
	hp_mult = def["hp_mult"]
	waves = def["waves"]
	if Game.endless:
		waves = DB.endless_waves(120, def["paths"].size(), 7 + level_idx * 31)
		gold = int(def["gold"]) + 200
		lives = 20
		hp_mult = 1.0
	elif Game.difficulty == 1:
		hp_mult *= 1.15
		lives = 10
		enemy_dmg_mult = 1.1
	if DB.up("gold"):
		gold += 60
	max_lives = lives
	for p in def["paths"]:
		paths.append(LanePath.new(p))
	spell_defs = DB.SPELLS.duplicate(true)
	if DB.up("meteor"):
		spell_defs["meteor"]["dmg"] = int(spell_defs["meteor"]["dmg"] * 1.3)
		spell_defs["meteor"]["cd"] = spell_defs["meteor"]["cd"] - 10.0
	if DB.up("reinforce"):
		spell_defs["reinforce"]["count"] = 3
		spell_defs["reinforce"]["hp"] = int(spell_defs["reinforce"]["hp"] * 1.3)
	_setup_environment(def["theme"])
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	fx = FX.new()
	add_child(fx)
	var b: Array = def["bounds"]
	var bounds := Rect2(b[0], b[2], b[1] - b[0], b[3] - b[2])
	plots = _auto_plots(def["plots_auto"], bounds)
	var keep := []
	for lp in paths:
		var s: Vector2 = (lp as LanePath).pts[0]
		keep.append(Vector3(s.x + 3.0, s.y, 5.0))
	var endp: Vector2 = (paths[0] as LanePath).sample(paths[0].length - 4.0)
	keep.append(Vector3(endp.x, endp.y, 6.0))
	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(paths, plots, def["theme"], bounds, keep, def.get("river_x", INF))
	_place_landmarks()
	_place_plots()
	_decorate(def["theme"])
	terrain.build_grass(2600 if Game.high_quality else 1100)
	_make_range_ring()
	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.set_bounds(bounds)
	cam_rig.tapped.connect(_on_tap)
	hud = HUD.new()
	add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.build(cam_rig.cam)
	overlay = hud.overlay
	hud.speed_toggled.connect(_toggle_speed)
	hud.pause_pressed.connect(_pause)
	hud.hero_pressed.connect(_select_hero)
	Game.achievement_unlocked.connect(_on_achievement)
	hud.skill_pressed.connect(func(): if hero: hero.cast_skill())
	hud.spell_pressed.connect(_spell_pressed)
	hud.wave_called.connect(_call_wave)
	hud.radial.chosen.connect(_on_radial_chosen)
	hud.radial.previewed.connect(_on_radial_preview)
	var wp := []
	for lp in paths:
		var s2: Vector2 = (lp as LanePath).sample(6.0)
		wp.append(Vector3(s2.x, 1.5, s2.y))
	hud.set_wave_buttons(wp)
	_spawn_hero()
	hud.set_gold(gold)
	hud.set_lives(lives)
	hud.set_wave(0, waves.size())
	_update_wave_preview()
	# intro camera
	var hs: Array = def["hero_start"]
	cam_rig.zoom = 40.0
	cam_rig.focus(Vector3(hs[0], 0, hs[1]))
	cam_rig._pos = cam_rig.target
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(cam_rig, "zoom", 30.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hud.show_banner(def["name"], def["subtitle"])
	Audio.play_music("battle")
	if level_idx == 0 and not Game.seen_tutorial:
		tutorial_step = 0
		get_tree().create_timer(2.5).timeout.connect(func(): if tutorial_step == 0: hud.show_hint("빈 건설 부지(돌 울타리)를 탭해서 타워를 지으세요.\n한 번 탭하면 미리보기, 한 번 더 탭하면 건설!"))

# ------------------------------------------------------------------ world

func _setup_environment(theme: String) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var sun_col := Color(1.0, 0.95, 0.86)
	var sun_rot := Vector3(-52, -38, 0)
	var sun_e := 1.15
	var fog_col := Color(0.72, 0.82, 0.95)
	match theme:
		"meadow":
			sm.sky_top_color = Color(0.28, 0.5, 0.86)
			sm.sky_horizon_color = Color(0.74, 0.84, 0.95)
			sm.ground_horizon_color = Color(0.6, 0.66, 0.55)
			sm.ground_bottom_color = Color(0.3, 0.34, 0.26)
		"river":
			sm.sky_top_color = Color(0.3, 0.52, 0.8)
			sm.sky_horizon_color = Color(0.8, 0.86, 0.92)
			sm.ground_horizon_color = Color(0.55, 0.62, 0.58)
			sm.ground_bottom_color = Color(0.25, 0.3, 0.3)
			sun_col = Color(1.0, 0.97, 0.92)
			sun_rot = Vector3(-58, 30, 0)
			fog_col = Color(0.78, 0.86, 0.92)
		"autumn":
			sm.sky_top_color = Color(0.32, 0.3, 0.55)
			sm.sky_horizon_color = Color(1.0, 0.68, 0.45)
			sm.ground_horizon_color = Color(0.7, 0.5, 0.38)
			sm.ground_bottom_color = Color(0.3, 0.22, 0.2)
			sun_col = Color(1.0, 0.84, 0.66)
			sun_rot = Vector3(-34, -55, 0)
			sun_e = 1.15
			fog_col = Color(0.95, 0.68, 0.5)
		"snow":
			sm.sky_top_color = Color(0.42, 0.55, 0.78)
			sm.sky_horizon_color = Color(0.86, 0.9, 0.97)
			sm.ground_horizon_color = Color(0.8, 0.85, 0.92)
			sm.ground_bottom_color = Color(0.5, 0.55, 0.62)
			sun_col = Color(0.92, 0.95, 1.0)
			sun_rot = Vector3(-46, 25, 0)
			sun_e = 0.9
			fog_col = Color(0.85, 0.9, 0.98)
		"night":
			sm.sky_top_color = Color(0.03, 0.05, 0.14)
			sm.sky_horizon_color = Color(0.16, 0.2, 0.38)
			sm.ground_horizon_color = Color(0.12, 0.14, 0.24)
			sm.ground_bottom_color = Color(0.04, 0.05, 0.08)
			sun_col = Color(0.55, 0.66, 1.0)
			sun_rot = Vector3(-60, 40, 0)
			sun_e = 0.62
			fog_col = Color(0.12, 0.16, 0.3)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42 if theme != "night" else 0.75
	if theme == "snow":
		env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# white point 2.0: the cleaned (non-metallic, matte) materials are brighter in diffuse, so give
	# the filmic shoulder more headroom - painted stone keeps its brick detail instead of clipping
	env.tonemap_white = 2.0
	env.tonemap_exposure = {"night": 1.1, "snow": 0.88, "autumn": 0.94}.get(theme, 0.98)
	env.glow_enabled = true
	env.glow_intensity = 0.45 if theme != "night" else 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.35
	env.fog_enabled = true
	env.fog_light_color = fog_col
	env.fog_density = 0.0022 if theme != "night" else 0.004
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = sun_col
	_sun.light_energy = sun_e
	_sun.rotation_degrees = sun_rot
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.2
	_sun.directional_shadow_max_distance = 75.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if Game.high_quality else DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.shadow_blur = 1.5
	add_child(_sun)

func _auto_plots(n: int, bounds: Rect2) -> Array:
	var cands := []
	var x := bounds.position.x + 2.0
	while x <= bounds.end.x - 2.0:
		var z := bounds.position.y + 2.0
		while z <= bounds.end.y - 1.0:
			var p := Vector2(x, z)
			var dmin := 1e9
			var score := 0.0
			for lp in paths:
				dmin = minf(dmin, (lp as LanePath).closest(p).x)
			if dmin >= 3.6 and dmin <= 5.4:
				for lp in paths:
					var pts: PackedVector2Array = (lp as LanePath).pts
					for i in range(0, pts.size(), 2):
						if pts[i].distance_to(p) < 7.5:
							score += 1.0
				var ok := true
				for lp in paths:
					if (lp as LanePath).pts[0].distance_to(p) < 7.0:
						ok = false
				var endp: Vector2 = (paths[0] as LanePath).pts[(paths[0] as LanePath).pts.size() - 1]
				if endp.distance_to(p) < 9.0:
					ok = false
				if def.has("river_x") and absf(p.x - float(def["river_x"])) < 5.0:
					ok = false
				if ok:
					cands.append([score + randf() * 0.01, p])
			z += 1.0
		x += 1.0
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for c in cands:
		var p: Vector2 = c[1]
		var good := true
		for q in out:
			if (q as Vector2).distance_to(p) < 4.4:
				good = false
				break
		if good:
			out.append(p)
		if out.size() >= n:
			break
	return out

func _place_landmarks() -> void:
	# castle at path end, facing incoming path
	var lp: LanePath = paths[0]
	var e2 := lp.sample(lp.length - 1.0)
	var t2 := lp.tangent(lp.length - 1.0)
	var castle := Assets.instance("castle")
	world.add_child(castle)
	castle.position = Vector3(e2.x, terrain.height_at(e2.x, e2.y) - 0.1, e2.y)
	castle.rotation.y = atan2(t2.x, t2.y) + PI
	_theme_overlay(castle)
	_landmark_light(castle, Vector3(0, 3.0, 3.5), Color(1.0, 0.75, 0.4), 1.6 if def["theme"] == "night" else 0.0)
	for p in paths:
		var s2: Vector2 = (p as LanePath).sample(1.0)
		var st: Vector2 = (p as LanePath).tangent(1.0)
		var portal := Assets.instance("portal")
		world.add_child(portal)
		portal.position = Vector3(s2.x, terrain.height_at(s2.x, s2.y) - 0.15, s2.y)
		portal.rotation.y = atan2(st.x, st.y)
		_theme_overlay(portal)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(3.1, 3.4)
		q.mesh = qm
		q.material_override = _portal_material()
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = PORTAL_HOLE
		portal.add_child(q)
		_landmark_light(portal, PORTAL_HOLE + Vector3(0, 0, 1.2), Color(0.7, 0.3, 1.0), 2.2 if def["theme"] == "night" else 1.0)
	# bridges where paths cross the river
	if def.has("river_x"):
		var rx: float = def["river_x"]
		for p in paths:
			var plp: LanePath = p
			for i in plp.pts.size():
				var q := plp.pts[i]
				if absf(q.x - rx - sin(q.y * 0.15) * 1.5) < 0.3:
					var tg := plp.tangent(i * LanePath.STEP)
					var br := Assets.instance("bridge")
					world.add_child(br)
					br.position = Vector3(q.x, 0.0, q.y)
					br.rotation.y = atan2(tg.x, tg.y) - PI * 0.5
					br.scale = Vector3(1.2, 1.15, 1.25)
					break

const PORTAL_HOLE := Vector3(0.0, 2.25, 0.55)

func _theme_overlay(n: Node3D) -> void:
	if def["theme"] != "snow":
		return
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = Assets.snow_overlay()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = Assets.snow_overlay()

func _landmark_light(parent: Node3D, at: Vector3, c: Color, energy: float) -> void:
	if energy <= 0.0:
		return
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 9.0
	l.omni_attenuation = 1.4
	l.position = at
	parent.add_child(l)

func _portal_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 9.0 - TIME * 3.5) * 0.5 + 0.5;
	float swirl2 = sin(a * 5.0 - r * 14.0 - TIME * 5.0) * 0.5 + 0.5;
	vec3 deep = vec3(0.05, 0.0, 0.1);
	vec3 mid = vec3(0.45, 0.08, 0.75);
	vec3 hot = vec3(0.95, 0.55, 1.0);
	vec3 c = mix(deep, mid, swirl * smoothstep(0.05, 0.9, r));
	c = mix(c, hot, pow(swirl2, 6.0) * 0.6 * r);
	c += hot * smoothstep(0.75, 1.0, r) * 0.8;
	ALBEDO = c * 1.6;
	ALPHA = smoothstep(1.0, 0.9, r);
}
"""
	m.shader = sh
	return m

var _plot_mmi: MultiMeshInstance3D
var _plot_xf: Array = []

func _place_plots() -> void:
	_plot_xf.clear()
	for p in plots:
		# signpost faces roughly toward the camera side for readability
		_plot_xf.append(Transform3D(Basis(Vector3.UP, randf_range(-0.6, 0.6)), Vector3(p.x, terrain.height_at(p.x, p.y), p.y)))
	_plot_mmi = Assets.multimesh("plot", _plot_xf, world)
	if _plot_mmi:
		_theme_overlay(_plot_mmi)

## Hide/show a build spot's marker (hidden while a tower stands on it).
func set_plot_visible(i: int, v: bool) -> void:
	if _plot_mmi == null or i < 0 or i >= _plot_xf.size():
		return
	var xf: Transform3D = _plot_xf[i]
	if not v:
		xf = xf.scaled_local(Vector3(0.001, 0.001, 0.001))
	_plot_mmi.multimesh.set_instance_transform(i, xf)

func _decorate(theme: String) -> void:
	match theme:
		"autumn":
			terrain.decor_colorize = Color(0.95, 0.45, 0.14, 0.75)
		"snow":
			terrain.decor_snow = 0.9
			terrain.decor_colorize = Color(0.55, 0.75, 0.7, 0.35)
		"night":
			terrain.decor_colorize = Color(0.35, 0.6, 0.75, 0.2)
	var round_n := 26
	var pine_n := 26
	match theme:
		"river": pine_n = 34; round_n = 20
		"autumn": round_n = 40; pine_n = 12
		"snow": round_n = 0; pine_n = 52
		"night": round_n = 22; pine_n = 34
	var defs := []
	# [model, count, min spacing, region, scale min, scale max]
	if round_n > 0:
		defs.append(["tree_round_v", round_n, 3.2, "edge", 0.75, 1.25])
		defs.append(["tree_round_v", 3, 4.0, "inner", 0.65, 0.95])
	defs.append(["tree_pine_v", pine_n, 3.0, "edge", 0.7, 1.3])
	defs.append(["tree_pine_v", 3, 4.0, "inner", 0.6, 0.9])
	defs.append(["rocks_v", 14, 2.8, "near", 0.45, 0.9])
	defs.append(["rocks_v", 10, 3.5, "edge", 0.8, 1.5])
	if theme != "snow":
		defs.append(["bush", 18, 2.2, "near", 0.7, 1.15])
		defs.append(["flowers", 30 if theme != "night" else 14, 1.5, "inner", 0.8, 1.3])
	defs.append(["crystals", 5 if theme != "night" else 12, 6.0, "near", 0.8, 1.3])
	defs.append(["lamp", 6 if theme != "night" else 10, 6.0, "inner", 1.0, 1.0])
	defs.append(["fence", 6, 5.0, "inner", 1.0, 1.0])
	defs.append(["barrels", 4, 6.0, "inner", 1.0, 1.0])
	defs.append(["house", 3, 9.0, "near", 0.9, 1.05])
	terrain.scatter_decor(defs, 99 + level_idx * 17)
	if theme == "night":
		# warm lantern pools of light on the dark map
		var n := 0
		for xf: Transform3D in terrain.decor_xf.get("lamp", []):
			if n >= (6 if Game.high_quality else 3):
				break
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.38)
			l.light_energy = 1.8
			l.omni_range = 7.0
			l.omni_attenuation = 1.6
			l.position = xf.origin + Vector3(0.6, 2.3, 0)
			world.add_child(l)
			n += 1
	var amb := {"snow": "snow", "autumn": "leaves", "night": "fireflies", "meadow": "motes", "river": "motes"}
	if amb.has(theme):
		fx.ambient(amb[theme])
	if theme == "night":
		fx.ambient("motes")

func _make_range_ring() -> void:
	range_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	range_ring.mesh = pm
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.85, 0.35, 1.0);
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.93, 0.97, d) * (1.0 - smoothstep(0.99, 1.0, d));
	float fill = (1.0 - smoothstep(0.96, 1.0, d)) * 0.12;
	float dash = step(0.5, fract(atan(UV.y - 0.5, UV.x - 0.5) * 6.0 + TIME * 0.6));
	ALBEDO = col.rgb;
	ALPHA = edge * mix(0.6, 1.0, dash) + fill;
}
"""
	m.shader = s
	range_ring.material_override = m
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_ring.visible = false
	add_child(range_ring)

func _show_range(p: Vector3, r: float, c := Color(1.0, 0.85, 0.35)) -> void:
	range_ring.visible = true
	range_ring.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.25, p.z)
	range_ring.scale = Vector3(r, 1, r)
	(range_ring.material_override as ShaderMaterial).set_shader_parameter("col", c)

func _spawn_hero() -> void:
	var hs: Array = def["hero_start"]
	var p := Vector3(hs[0], terrain.walk_height(hs[0], hs[1]), hs[1])
	hero = Hero.new()
	world.add_child(hero)
	hero.setup_hero(p)
	soldiers.append(hero)

# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	_time += delta
	if state == "playing" or state == "ready":
		_update_spawns(delta)
		_update_waves(delta)
		for k in spell_cd:
			spell_cd[k] = maxf(spell_cd[k] - delta, 0.0)
	_update_hud()

func _update_spawns(delta: float) -> void:
	for g in groups:
		if g["left"] <= 0:
			continue
		g["delay"] -= delta
		if g["delay"] > 0.0:
			continue
		g["timer"] -= delta
		if g["timer"] <= 0.0:
			g["timer"] = g["interval"]
			g["left"] -= 1
			_spawn_enemy(g["type"], g["path"])

func _spawning_done() -> bool:
	for g in groups:
		if g["left"] > 0:
			return false
	return true

func _update_waves(delta: float) -> void:
	if state != "playing":
		return
	if _spawning_done():
		if wave_idx < waves.size() - 1:
			wave_timer -= delta
			if wave_timer <= 0.0:
				_call_wave()
		elif enemies.is_empty():
			_victory()

func spawn_enemy_at(type: String, lp: LanePath, at_dist: float) -> Enemy:
	var e := Enemy.new()
	world.add_child(e)
	e.setup(type, lp, hp_mult)
	e.dist = at_dist
	e._update_transform(0.0)
	e._prev = e.global_position
	enemies.append(e)
	fx.magic_burst(e.aim_point(), Color(0.6, 1.0, 0.4), 0.7)
	return e

func _spawn_enemy(type: String, path_i: int) -> void:
	var e := Enemy.new()
	world.add_child(e)
	var m := hp_mult * (DB.endless_hp_scale(wave_idx) if Game.endless else 1.0)
	e.setup(type, paths[mini(path_i, paths.size() - 1)], m)
	enemies.append(e)
	Game.mark_seen(type)
	if not seen.has(type):
		seen[type] = true
		_show_enemy_card(type)
	if e.boss:
		hud.show_banner("보스 출현!", DB.ENEMIES[type]["name"], Color(1.0, 0.4, 0.3))
		Audio.play("boss_roar", 2.0, 0.0)
		Audio.voice("ann_boss")
		Audio.play_music("boss", 1.5)
		cam_rig.shake(0.6)
		if e.model.has("roar"):
			e.model.play("roar", 1.4, 0.1, true)
			e.stun_t = 2.0

func _call_wave() -> void:
	if state == "won" or state == "lost":
		return
	if wave_idx >= waves.size() - 1:
		return
	if state == "playing" and not _spawning_done():
		return
	var bonus := 0
	if state == "playing" and wave_timer > 1.0:
		bonus = int(wave_timer * 1.5)
		add_gold(bonus, hero.global_position if hero else Vector3.ZERO, false)
		for k in spell_cd:
			spell_cd[k] = maxf(spell_cd[k] - wave_timer * 0.5, 0.0)
		overlay.float_text(_wave_button_world(), "+%d 보너스!" % bonus, UI.GOLD, 1.3)
	state = "playing"
	wave_idx += 1
	if Game.endless and wave_idx > 0:
		add_gold(20 + wave_idx * 3, _wave_button_world(), true)
	groups.clear()
	for g in waves[wave_idx]:
		groups.append({"type": g[0], "left": int(g[1]), "interval": float(g[2]), "delay": float(g[3]), "path": int(g[4]), "timer": 0.0})
	wave_timer = wave_wait
	hud.set_wave(wave_idx + 1, -1 if Game.endless else waves.size())
	_update_wave_preview()
	var last := wave_idx == waves.size() - 1 and not Game.endless
	if Game.endless:
		var boss_wave := (wave_idx + 1) % 10 == 0
		hud.show_banner("웨이브 %d" % (wave_idx + 1), "보스 웨이브!" if boss_wave else "적이 점점 강해집니다 (체력 x%.1f)" % DB.endless_hp_scale(wave_idx))
		Game.stat("endless_wave", wave_idx + 1, "max")
	else:
		hud.show_banner("마지막 웨이브!" if last else "웨이브 %d" % (wave_idx + 1), "적이 몰려옵니다!" if not last else "끝까지 버텨내세요!")
	Audio.play("horn", 0.0, 0.0)
	Audio.voice("ann_final" if last else ("ann_wave_first" if wave_idx == 0 else "ann_wave"), 0.0, 1.0)
	if tutorial_step == 1:
		tutorial_step = 2
		hud.show_hint("영웅 초상화(왼쪽 아래)를 탭한 뒤 땅을 탭하면\n영웅 카엘이 그곳으로 이동해 싸웁니다.")
		get_tree().create_timer(9.0).timeout.connect(func():
			if tutorial_step == 2:
				tutorial_step = 3
				hud.show_hint("")
				Game.seen_tutorial = true
				Game.save())

func _update_wave_preview() -> void:
	var nxt := wave_idx + 1
	var per := []
	for i in paths.size():
		per.append({})
	if nxt < waves.size():
		for g in waves[nxt]:
			var pi := mini(int(g[4]), paths.size() - 1)
			var dct: Dictionary = per[pi]
			dct[g[0]] = int(dct.get(g[0], 0)) + int(g[1])
	hud.set_wave_preview(per)

func _wave_button_world() -> Vector3:
	var s2: Vector2 = (paths[0] as LanePath).sample(6.0)
	return Vector3(s2.x, 2.0, s2.y)

func _update_hud() -> void:
	if hud == null:
		return
	var show_call := state == "ready" or (state == "playing" and _spawning_done() and wave_idx < waves.size() - 1)
	var prog := 0.0 if state == "ready" else clampf(wave_timer / wave_wait, 0.0, 1.0)
	var label := "전투 시작!" if state == "ready" else "+%d" % int(wave_timer * 1.5)
	hud.update_wave_buttons(cam_rig.cam, show_call, 1.0 - prog if state != "ready" else 0.0, label, _time)
	if hero:
		hud.hero_hp.value = hero.hp / hero.max_hp if hero.alive else 0.0
		hud.hero_xp.value = hero.xp_progress()
		hud.hero_lv.text = str(hero.level)
		hud.hero_dead.text = "" if hero.alive else str(int(ceil(hero.respawn_t)))
		hud.hero_b.modulate = Color(1, 1, 1) if hero.alive else Color(0.45, 0.45, 0.5)
		hud.skill_cd.value = hero.skill_cd / DB.hero_def()["skill_cd"]
	for id in spell_cd:
		var d: Dictionary = hud.spell_btns[id]
		var cdm: float = spell_defs[id]["cd"]
		(d["cd"] as TextureProgressBar).value = spell_cd[id] / cdm
		(d["label"] as Label).text = "" if spell_cd[id] <= 0.0 else str(int(ceil(spell_cd[id])))
		var btn: Button = d["button"]
		btn.modulate = Color(1.25, 1.15, 0.8) if targeting == id else Color.WHITE
	if hud.radial.visible:
		hud.radial.refresh_enabled(gold)
	var big: Enemy = null
	for e: Enemy in enemies:
		if e.alive and (e.boss or e.type == "ogre" or e.type == "warchief") and (big == null or e.max_hp > big.max_hp):
			big = e
	if big:
		hud.set_boss(DB.ENEMIES[big.type]["name"], big.hp / big.max_hp)
	else:
		hud.set_boss("", 0.0)

# ------------------------------------------------------------------ economy

func add_gold(n: int, at := Vector3.ZERO, popup := true) -> void:
	gold += n
	hud.set_gold(gold)
	if popup and at != Vector3.ZERO:
		overlay.float_text(at + Vector3(0, 1.0, 0), "+%d" % n, UI.GOLD, 0.9)

func on_enemy_killed(e: Enemy) -> void:
	enemies.erase(e)
	add_gold(int(e.d["gold"]), e.global_position)
	Game.stat("kills")
	Game.stat("gold", int(e.d["gold"]))
	if not cam_rig.cam.is_position_behind(e.global_position):
		hud.fly_coins(cam_rig.cam.unproject_position(e.aim_point()), clampi(int(e.d["gold"]) / 8 + 1, 1, 3))
	if e.boss:
		Game.stat("boss_kills")
		Audio.play_music("battle", 2.0)
	Audio.play("coin", -10.0, 0.1)
	if hero:
		hero.add_xp(float(e.d["gold"]) * 2.0)

func on_enemy_exit(e: Enemy) -> void:
	enemies.erase(e)
	if state == "won" or state == "lost":
		return
	lives = maxi(lives - int(e.d["lives"]), 0)
	hud.set_lives(lives)
	hud.flash_damage(lives <= maxi(max_lives / 4, 3))
	Audio.play("life_lost", -2.0)
	if lives <= maxi(max_lives / 4, 3):
		Audio.voice("ann_danger", 0.0, 20.0)
	cam_rig.shake(0.3)
	if lives <= 0:
		_defeat()

# ------------------------------------------------------------------ input & selection

func _refine_ground(sp: Vector2) -> Vector3:
	var p := cam_rig.ground_point(sp, 0.0)
	for i in 3:
		var h := terrain.height_at(p.x, p.z)
		p = cam_rig.ground_point(sp, h)
	return p

func _on_tap(sp: Vector2) -> void:
	if _modal != null or state == "won" or state == "lost":
		return
	var gp := _refine_ground(sp)
	if targeting != "":
		_handle_targeting(gp)
		return
	# hero pick (screen space)
	if hero and hero.alive and not cam_rig.cam.is_position_behind(hero.global_position):
		var hs := cam_rig.cam.unproject_position(hero.global_position + Vector3(0, 1.0, 0))
		if hs.distance_to(sp) < 52.0:
			_select_hero()
			return
	# plot / tower pick
	var best := -1
	var bd := 2.4
	for i in plots.size():
		var d := (plots[i] as Vector2).distance_to(Vector2(gp.x, gp.z))
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		if towers.has(best):
			_select_tower(best)
		else:
			_select_plot(best)
		return
	if selection.get("kind", "") == "hero" and hero and hero.alive:
		if terrain.in_river(gp.x, gp.z) and terrain.path_dist(gp.x, gp.z) > 2.0:
			return
		var b: Rect2 = cam_rig.bounds
		gp.x = clampf(gp.x, b.position.x, b.end.x)
		gp.z = clampf(gp.z, b.position.y, b.end.y)
		gp.y = terrain.walk_height(gp.x, gp.z)
		hero.move_to(gp)
		_deselect()
		return
	_deselect()

func _deselect() -> void:
	selection = {}
	hud.radial.close()
	hud.hide_info()
	range_ring.visible = false
	if hero:
		hero.set_selected(false)
	if targeting == "rally":
		targeting = ""
		hud.target_hint.text = ""

func _select_hero() -> void:
	if hero == null or not hero.alive:
		return
	_deselect()
	selection = {"kind": "hero"}
	hero.set_selected(true)
	Audio.voice(hero.hid + "_select", 0.0, 6.0)
	hud.show_info(DB.hero_def()["name"] + "  Lv.%d" % hero.level, "체력 %d/%d · 공격력 %d-%d\n땅을 탭해 이동 · 스킬: %s (자동/수동)" % [hero.hp, hero.max_hp, hero.dmg[0], hero.dmg[1], DB.hero_def()["skill_name"]])
	Audio.play("hero_select", -4.0, 0.05)

func _select_plot(i: int) -> void:
	_deselect()
	selection = {"kind": "plot", "idx": i}
	var p: Vector2 = plots[i]
	var opts := []
	for t in DB.TOWER_ORDER:
		var c: int = DB.TOWERS[t]["levels"][0]["cost"]
		opts.append({"id": "build_" + t, "icon": Assets.tex("tower_%s_1" % t), "label": str(c), "coin": true, "cost": c, "enabled": gold >= c})
	hud.radial.open(Vector3(p.x, terrain.height_at(p.x, p.y) + 0.5, p.y), opts)
	if tutorial_step == 0:
		hud.show_hint("")

func _select_tower(i: int) -> void:
	_deselect()
	selection = {"kind": "tower", "idx": i}
	var t: Tower = towers[i]
	var opts := []
	if t.level < 3:
		var c := t.next_cost()
		opts.append({"id": "upgrade", "icon": Assets.tex("upgrade"), "label": str(c), "coin": true, "cost": c, "enabled": gold >= c})
	elif t.level == 3:
		for m in t.data()["masteries"]:
			opts.append({"id": "mastery_" + m["id"], "icon": Assets.tex("m_" + m["id"]), "label": str(m["cost"]), "coin": true, "cost": m["cost"], "enabled": gold >= int(m["cost"])})
	if t.type == "barracks":
		opts.append({"id": "rally", "icon": Assets.tex("rally"), "instant": true})
	else:
		opts.append({"id": "priority", "icon": Assets.tex("target_" + t.priority), "label": PRIORITY_NAMES[t.priority], "instant": true})
	opts.append({"id": "sell", "icon": Assets.tex("sell"), "label": "+%d" % t.sell_value(), "coin": true})
	hud.radial.open(t.global_position + Vector3(0, 1.5, 0), opts)
	_show_range(t.global_position, t.range_r())
	hud.show_info(_tower_title(t), _tower_stats_text(t.type, t.stats))

const PRIORITY_NAMES := {"first": "선두", "strong": "강적", "close": "근접"}

func _tower_title(t: Tower) -> String:
	if t.mastery != "":
		return DB.mastery_def(t.type, t.mastery)["name"]
	return "%s  Lv.%d" % [t.data()["name"], t.level]

func _tower_stats_text(type: String, s: Dictionary) -> String:
	if type == "barracks":
		return "병사 %d명 · 체력 %d · 공격력 %d-%d\n방어력 %d%% · 집결 범위 %.1f" % [s["count"], s["soldier_hp"], s["soldier_dmg"][0], s["soldier_dmg"][1], int(s["soldier_armor"] * 100), s["range"]]
	var extra := ""
	if s.has("splash"):
		extra += " · 폭발 범위 %.1f" % s["splash"]
	if s.has("multishot"):
		extra += " · %d연발" % s["multishot"]
	if s.has("chain"):
		extra += " · 연쇄 %d" % s["chain"]
	if s.has("slow"):
		extra += " · 둔화 %d%%" % int(s["slow"] * 100)
	if s.has("crit"):
		extra += " · 치명 %d%%" % int(s["crit"] * 100)
	return "공격력 %d-%d · 공격 간격 %.1f초\n사거리 %.1f%s" % [s["dmg"][0], s["dmg"][1], s["rate"], s["range"], extra]

func _on_radial_preview(id: String) -> void:
	var kind: String = selection.get("kind", "")
	if kind == "plot":
		var p: Vector2 = plots[selection["idx"]]
		var t := id.trim_prefix("build_")
		var s: Dictionary = DB.TOWERS[t]["levels"][0]
		_show_range(Vector3(p.x, 0, p.y), s["range"], Color(0.5, 1.0, 0.6))
		hud.show_info(DB.TOWERS[t]["name"], DB.TOWERS[t]["desc"] + "\n" + _tower_stats_text(t, s))
	elif kind == "tower":
		var tw: Tower = towers[selection["idx"]]
		if id == "upgrade":
			var s2 := DB.tower_stats(tw.type, tw.level + 1, "")
			_show_range(tw.global_position, s2["range"], Color(0.5, 1.0, 0.6))
			hud.show_info("업그레이드 → Lv.%d" % (tw.level + 1), _tower_stats_text(tw.type, s2))
		elif id.begins_with("mastery_"):
			var mid := id.trim_prefix("mastery_")
			var s3 := DB.tower_stats(tw.type, 3, mid)
			var md := DB.mastery_def(tw.type, mid)
			_show_range(tw.global_position, s3["range"], md["tint"])
			hud.show_info(md["name"], md["desc"] + "\n" + _tower_stats_text(tw.type, s3))
		elif id == "sell":
			hud.show_info("타워 판매", "%d 골드를 돌려받습니다. 한 번 더 탭하면 판매합니다." % tw.sell_value())
		elif id == "priority":
			hud.show_info("공격 우선순위: " + PRIORITY_NAMES[tw.priority], "탭할 때마다 변경: 선두(가장 앞선 적) → 강적(체력 최대) → 근접(가장 가까운 적)")

func _on_radial_chosen(id: String) -> void:
	var kind: String = selection.get("kind", "")
	if kind == "plot" and id.begins_with("build_"):
		var t := id.trim_prefix("build_")
		var c: int = DB.TOWERS[t]["levels"][0]["cost"]
		if gold < c:
			Audio.play("error", -4.0)
			return
		var i: int = selection["idx"]
		gold -= c
		hud.set_gold(gold)
		var tw := Tower.new()
		world.add_child(tw)
		tw.setup(t, plots[i])
		towers[i] = tw
		Game.stat("towers")
		set_plot_visible(i, false)
		_deselect()
		if tutorial_step == 0:
			tutorial_step = 1
			hud.show_hint("좋아요! 왼쪽 위 포털의 해골 버튼을 눌러 첫 웨이브를 부르세요.\n일찍 부를수록 보너스 골드를 받습니다.")
		return
	if kind != "tower":
		return
	var idx: int = selection["idx"]
	var tower: Tower = towers[idx]
	if id == "upgrade":
		var c2 := tower.next_cost()
		if gold < c2:
			Audio.play("error", -4.0)
			return
		gold -= c2
		hud.set_gold(gold)
		tower.upgrade()
		Audio.play("upgrade", -2.0)
		_deselect()
	elif id.begins_with("mastery_"):
		var mid := id.trim_prefix("mastery_")
		var md := DB.mastery_def(tower.type, mid)
		if gold < int(md["cost"]):
			Audio.play("error", -4.0)
			return
		gold -= int(md["cost"])
		hud.set_gold(gold)
		tower.apply_mastery(mid)
		Game.stat("masteries")
		Audio.play("upgrade", 0.0)
		hud.show_banner(md["name"], "전문화 완료!", md["tint"])
		_deselect()
	elif id == "sell":
		add_gold(tower.sell_value(), tower.global_position)
		fx.dust(tower.global_position, 1.5)
		Audio.play("sell", -2.0)
		tower.remove()
		towers.erase(idx)
		set_plot_visible(idx, true)
		_deselect()
	elif id == "priority":
		var pr := tower.cycle_priority()
		Audio.play("tick", -2.0)
		overlay.float_text(tower.global_position + Vector3(0, 4.5, 0), "우선순위: " + PRIORITY_NAMES[pr], Color(1.0, 0.7, 0.5), 1.0)
		_select_tower(idx)
	elif id == "rally":
		hud.radial.close()
		targeting = "rally"
		_show_range(tower.global_position, tower.range_r(), Color(0.5, 0.8, 1.0))
		hud.target_hint.text = "집결 지점을 탭하세요 (길 위, 범위 내)"

func _spell_pressed(id: String) -> void:
	if spell_cd[id] > 0.0 or state == "won" or state == "lost":
		Audio.play("error", -6.0)
		return
	_deselect()
	if targeting == id:
		targeting = ""
		hud.target_hint.text = ""
		return
	targeting = id
	hud.target_hint.text = "유성을 떨어뜨릴 곳을 탭하세요" if id == "meteor" else "지원군을 배치할 길 위를 탭하세요"

func _handle_targeting(gp: Vector3) -> void:
	var t := targeting
	targeting = ""
	hud.target_hint.text = ""
	match t:
		"meteor":
			spell_cd["meteor"] = spell_defs["meteor"]["cd"]
			Game.stat("meteors")
			var sp: Dictionary = spell_defs["meteor"]
			for i in int(sp["count"]):
				var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.2, 2.6)
				var to := gp + off
				to.y = terrain.walk_height(to.x, to.z)
				Projectile.meteor(to, sp["dmg"], sp["radius"], i * 0.22)
			Audio.play("meteor_cast", 0.0)
		"reinforce":
			if terrain.path_dist(gp.x, gp.z) > 3.0:
				hud.target_hint.text = "길 근처에만 배치할 수 있습니다"
				targeting = "reinforce"
				Audio.play("error", -6.0)
				return
			spell_cd["reinforce"] = spell_defs["reinforce"]["cd"]
			var sd: Dictionary = spell_defs["reinforce"]
			var cnt: int = sd["count"]
			for i in cnt:
				var s := Soldier.new()
				world.add_child(s)
				s.setup_unit("footman", 1.7, Color(0.8, 0.9, 1.15), "")
				s.set_stats(sd["hp"], sd["dmg"], 0.1, 1.0)
				s.hp = s.max_hp
				s.lifetime = sd["duration"]
				s.rally = Vector3(gp.x, terrain.walk_height(gp.x, gp.z), gp.z)
				s.slot = Vector3(-0.6 * (cnt - 1) + i * 1.2, 0, 0)
				s.global_position = s.rally + s.slot
				soldiers.append(s)
				fx.magic_burst(s.aim_point(), Color(0.6, 0.85, 1.0), 1.0)
			Audio.play("reinforce", -2.0)
		"rally":
			var kind: String = selection.get("kind", "")
			if kind == "tower":
				var tw: Tower = towers[selection["idx"]]
				if not tw.set_rally(gp):
					Audio.play("error", -6.0)
					hud.target_hint.text = "범위 안의 길 위를 탭하세요"
					targeting = "rally"
					return
				Audio.play("rally", -4.0)
			_deselect()

# ------------------------------------------------------------------ cards & menus

func _show_enemy_card(type: String) -> void:
	var e: Dictionary = DB.ENEMIES[type]
	if _info_card:
		_info_card.queue_free()
	var p := UI.panel(Color(0.08, 0.07, 0.1, 0.94), Color(0.75, 0.3, 0.25), 16)
	p.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.07, 0.1, 0.94), Color(0.75, 0.3, 0.25), 16, 3, 8, 10))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_child(UI.icon(Assets.tex("portrait_" + type), 84))
	var vb := VBoxContainer.new()
	vb.add_child(UI.label("새로운 적!", 18, Color(1.0, 0.55, 0.45), 4))
	vb.add_child(UI.label(e["name"], 26, UI.TEXT, 6))
	var desc := UI.label(e["desc"], 18, UI.MUTED, 4)
	vb.add_child(desc)
	hb.add_child(vb)
	p.add_child(hb)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -360
	p.offset_right = -14
	p.offset_top = 96
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(p)
	_info_card = p
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

func _toggle_speed() -> void:
	fast = not fast
	Engine.time_scale = 2.0 if fast else 1.0
	hud.set_speed(fast)

func _pause() -> void:
	if _modal != null or state == "won" or state == "lost":
		return
	get_tree().paused = true
	_modal = hud.modal("일시 정지", func(vb: VBoxContainer):
		var b1 := UI.button("계속하기", 28, true, Vector2(320, 70))
		b1.pressed.connect(_resume)
		vb.add_child(b1)
		var b2 := UI.button("다시 시작", 26, false, Vector2(320, 64))
		b2.pressed.connect(func(): Game.start_level(level_idx))
		vb.add_child(b2)
		var hq := CheckButton.new()
		hq.text = "고품질 그래픽"
		hq.button_pressed = Game.high_quality
		hq.add_theme_font_override("font", Assets.font("ui"))
		hq.add_theme_font_size_override("font_size", 22)
		hq.toggled.connect(func(v): Game.high_quality = v; Game.apply_quality(); Game.save())
		vb.add_child(hq)
		vb.add_child(_volume_row("음악", Game.music_volume, func(v): Game.music_volume = v; Audio.update_music_volume(); Game.save()))
		vb.add_child(_volume_row("효과음", Game.sfx_volume, func(v): Game.sfx_volume = v; Game.save()))
		var b3 := UI.button("지도로 나가기", 24, false, Vector2(320, 60))
		b3.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		vb.add_child(b3))

func _volume_row(label: String, v: float, cb: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := UI.label(label, 22, UI.TEXT, 4)
	l.custom_minimum_size.x = 80
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = v
	s.custom_minimum_size = Vector2(220, 36)
	s.value_changed.connect(cb)
	hb.add_child(s)
	return hb

func _resume() -> void:
	get_tree().paused = false
	if _modal:
		_modal.queue_free()
		_modal = null

func _victory() -> void:
	if state == "won":
		return
	state = "won"
	var max_l: int = max_lives
	var stars := 3 if lives >= max_l - 2 else (2 if lives >= max_l / 2 else 1)
	Game.set_stars(level_idx, stars)
	Game.stat("wins")
	if lives >= max_l:
		Game.stat("flawless")
	if Game.difficulty == 1:
		Game.stat("heroic_wins")
	if hero and hero.hid == "sera":
		Game.stat("sera_wins")
	var st_total := 0
	for v in Game.stars:
		st_total += int(v)
	Game.stat("stars", st_total, "max")
	Game.save()
	Audio.voice("ann_victory", 0.0, 1.0)
	Engine.time_scale = 1.0
	if hero and hero.alive:
		hero.model.play("cheer", 1.0, 0.2, true)
		cam_rig.focus(hero.global_position, 20.0)
	Audio.play("victory", 0.0, 0.0)
	Audio.play_music("menu", 3.0)
	get_tree().create_timer(1.6).timeout.connect(func():
		_modal = hud.modal("승리!", func(vb: VBoxContainer):
			var st := UI.stars_row(stars, 72)
			vb.add_child(st)
			var l := UI.label("남은 생명 %d / %d" % [lives, max_l], 24, UI.TEXT, 5)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(l)
			if level_idx < DB.LEVELS.size() - 1:
				var nb := UI.button("다음 지역  ▶", 28, true, Vector2(340, 72))
				nb.pressed.connect(func(): Game.start_level(level_idx + 1))
				vb.add_child(nb)
			else:
				var fl := UI.label("왕국을 지켜냈습니다! 모든 지역 정복", 22, UI.GOLD, 5)
				fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vb.add_child(fl)
			var rb := UI.button("다시 도전", 24, false, Vector2(340, 62))
			rb.pressed.connect(func(): Game.start_level(level_idx))
			vb.add_child(rb)
			var mb := UI.button("지도로", 24, false, Vector2(340, 62))
			mb.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
			vb.add_child(mb)))

func _defeat() -> void:
	if state == "lost":
		return
	state = "lost"
	Engine.time_scale = 1.0
	Audio.play("defeat", 0.0, 0.0)
	Game.save()
	if Game.endless:
		_endless_over()
		return
	Audio.voice("ann_defeat", 0.0, 1.0)
	_modal = hud.modal("패배...", func(vb: VBoxContainer):
		var l := UI.label("성문이 뚫렸습니다. 전략을 바꿔 다시 도전하세요!", 22, UI.TEXT, 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		var tip := UI.label("팁: 오크는 마법 탑, 비행 적은 궁수/마법 탑으로 대응하세요.", 19, UI.MUTED, 4)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tip)
		var rb := UI.button("다시 도전", 28, true, Vector2(340, 72))
		rb.pressed.connect(func(): Game.start_level(level_idx))
		vb.add_child(rb)
		var mb := UI.button("지도로", 24, false, Vector2(340, 62))
		mb.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		vb.add_child(mb))

func _on_achievement(id: String) -> void:
	for a in DB.ACHIEVEMENTS:
		if a["id"] == id:
			hud.toast("업적 달성: " + a["name"], a["desc"] + "  (보상 ★1)", a["icon"])
			Audio.play("levelup", -4.0)
			Game.save()
			return

func _endless_over() -> void:
	var reached := wave_idx + 1
	var key := str(level_idx)
	var best := int(Game.endless_best.get(key, 0))
	var record := reached > best
	if record:
		Game.endless_best[key] = reached
	Game.stat("endless_wave", reached, "max")
	Game.save()
	_modal = hud.modal("전투 종료", func(vb: VBoxContainer):
		var l := UI.label("도달 웨이브  %d" % reached, 40, UI.GOLD, 8, "title_kr")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		var r := UI.label("신기록 달성!" if record else "최고 기록  %d" % maxi(best, reached), 24, Color(1.0, 0.75, 0.4) if record else UI.TEXT, 5)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(r)
		var rb := UI.button("다시 도전", 28, true, Vector2(340, 72))
		rb.pressed.connect(func(): Game.start_endless(level_idx))
		vb.add_child(rb)
		var mb := UI.button("지도로", 24, false, Vector2(340, 62))
		mb.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		vb.add_child(mb))

func _exit_tree() -> void:
	if Game.achievement_unlocked.is_connected(_on_achievement):
		Game.achievement_unlocked.disconnect(_on_achievement)
	if I == self:
		I = null
	Engine.time_scale = 1.0
