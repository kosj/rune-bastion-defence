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
var run_kills := 0
var run_gold := 0
var run_time := 0.0
var _enemy_info_t := 0.0
var cine: Cinematics
var _env: Environment
# playtest log for this run
var _lost_by_wave := {}
var _leaks := {}
var _spells_used := 0
var _logged := false

func _ready() -> void:
	I = self
	Game.mark("level_build_start")
	get_viewport().disable_3d = false
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
	elif Game.challenge:
		# iron challenge: three lives, no spells, a little more gold to plan with
		lives = 3
		gold = int(gold * 1.4)
	elif Game.difficulty == 1:
		hp_mult *= 1.15
		lives = 10
		enemy_dmg_mult = 1.1
	elif Game.difficulty == 2:
		# casual: softer enemies and a richer start for players still learning the towers
		hp_mult *= 0.72
		enemy_dmg_mult = 0.85
		gold = int(gold * 1.3)
	if DB.up("gold"):
		gold += 60
	if DB.up("lives") and not Game.challenge:
		lives += 2 if (Game.difficulty == 1 and not Game.endless) else 5
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
	_place_vignette(bounds)
	_place_events(bounds)
	# the hero's spot is chosen after the plots and set pieces and kept clear of props
	_hero_at = _hero_spot(bounds)
	terrain.keepout.append(Vector3(_hero_at.x, _hero_at.y, HERO_CLEAR))
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
	Game.layout_changed.connect(_on_layout_changed)
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
	# intro: the first visit flies along the enemy road; later visits just zoom in
	cine = Cinematics.new()
	add_child(cine)
	cine.setup(self)
	Game.mark("level_built")
	get_tree().process_frame.connect(func(): Game.mark("level_first_frame"), CONNECT_ONE_SHOT)
	var intro_key := "intro_%d" % level_idx
	var first := not Game.testing and not Game.endless and int(Game.stats.get(intro_key, 0)) == 0
	if first:
		Game.stat(intro_key)
	var story: Array = DB.STORY.get(def["id"], [])
	if first and not story.is_empty():
		# first visit: a short scene in front of the enemy portal, then the road fly-over
		var s0: Vector2 = (paths[0] as LanePath).sample(2.0)
		cam_rig.zoom = 21.0
		cam_rig.target = Vector3(s0.x, 0, s0.y)
		cam_rig._pos = cam_rig.target
		cine.story(story, func(): cine.level_intro(true), true)
	else:
		cine.level_intro(first)
	if Game.challenge:
		hud.show_banner(def["name"], "철인 도전 · 생명 3 · 주문 없음", Color(1.0, 0.55, 0.4))
		for sid in hud.spell_btns:
			((hud.spell_btns[sid] as Dictionary)["button"] as Control).visible = false
	Audio.play_music(battle_music())
	# first time a kind of map event shows up: say what the gold "!" does
	if not events.is_empty() and not Game.testing:
		var kind0: String = events[0]["kind"]
		if int(Game.stats.get("evt_hint_" + kind0, 0)) == 0:
			_evt_hint = kind0  # shown a few seconds into the first wave, never over a cut-scene
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
		"ruins":
			# overcast, misty cliffs by the falls
			sm.sky_top_color = Color(0.42, 0.5, 0.6)
			sm.sky_horizon_color = Color(0.74, 0.78, 0.82)
			sm.ground_horizon_color = Color(0.55, 0.58, 0.6)
			sm.ground_bottom_color = Color(0.25, 0.28, 0.3)
			sun_col = Color(0.9, 0.93, 1.0)
			sun_rot = Vector3(-60, 40, 0)
			sun_e = 0.84
			fog_col = Color(0.58, 0.64, 0.7)
		"swamp":
			# ghost-lit temple marsh: moonlike green key light, dark sky
			sm.sky_top_color = Color(0.04, 0.07, 0.07)
			sm.sky_horizon_color = Color(0.18, 0.28, 0.22)
			sm.ground_horizon_color = Color(0.12, 0.17, 0.14)
			sm.ground_bottom_color = Color(0.03, 0.04, 0.04)
			sun_col = Color(0.62, 0.86, 0.72)
			sun_rot = Vector3(-62, -30, 0)
			sun_e = 0.66
			fog_col = Color(0.15, 0.24, 0.18)
		"necro":
			# ash and embers around the black citadel (neutral key light keeps materials readable)
			sm.sky_top_color = Color(0.08, 0.06, 0.1)
			sm.sky_horizon_color = Color(0.36, 0.17, 0.15)
			sm.ground_horizon_color = Color(0.2, 0.15, 0.15)
			sm.ground_bottom_color = Color(0.05, 0.04, 0.04)
			sun_col = Color(0.98, 0.9, 0.86)
			sun_rot = Vector3(-48, 30, 0)
			sun_e = 0.95
			fog_col = Color(0.32, 0.2, 0.2)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = {"night": 0.75, "snow": 0.36, "swamp": 0.72, "necro": 0.5, "ruins": 0.55}.get(theme, 0.42)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# white point 2.0: the cleaned (non-metallic, matte) materials are brighter in diffuse, so give
	# the filmic shoulder more headroom - painted stone keeps its brick detail instead of clipping
	env.tonemap_white = 2.0
	env.tonemap_exposure = {"night": 1.1, "snow": 0.88, "autumn": 0.94, "swamp": 1.1, "necro": 1.08, "ruins": 0.94}.get(theme, 0.98)
	env.glow_enabled = true
	env.glow_intensity = 0.8 if theme in ["night", "swamp", "necro"] else 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.35
	env.fog_enabled = true
	env.fog_light_color = fog_col
	env.fog_density = {"night": 0.004, "swamp": 0.0045, "necro": 0.0035, "ruins": 0.0036}.get(theme, 0.0022)
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = {"necro": 0.9, "ruins": 0.95, "swamp": 0.88}.get(theme, 1.06)
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	_env = env
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
	_landmark_light(castle, Vector3(0, 3.0, 3.5), Color(1.0, 0.75, 0.4), 1.6 if def["theme"] in ["night", "swamp", "necro"] else 0.0)
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
		_landmark_light(portal, PORTAL_HOLE + Vector3(0, 0, 1.2), Color(0.7, 0.3, 1.0), 2.2 if def["theme"] in ["night", "swamp", "necro"] else 1.0)
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

# ------------------------------------------------------------------ map events
## Tappable set pieces beside the road: a boulder to roll onto the enemies, an altar whose
## pulse freezes the crowd around it, a hidden supply cache. A gold "!" shows when one is ready.
const EVENTS := {"greenvale": ["cache"], "twinfords": ["cache"], "frostwind": ["rockfall"], "moonwood": ["altar"],
	"trollgorge": ["rockfall", "rockfall"], "citadel": ["altar"], "falls": ["rockfall", "altar"], "temple": ["altar"],
	"harbor": ["cache", "rockfall"], "capital": ["altar", "rockfall"]}
const EVENT_CD := {"rockfall": 50.0, "altar": 40.0}
var events: Array = []

func _event_spot(lp: LanePath, along: float, bounds: Rect2, plot_r := 3.8) -> Vector2:
	var inner := bounds.grow(-2.5)
	for da in [0.0, 3.0, -3.0, 6.0, -6.0, 9.0, -9.0]:
		var at := clampf(along + da, 2.0, lp.length - 4.0)
		var q := lp.sample(at)
		var t := lp.tangent(at)
		var side := Vector2(-t.y, t.x)
		for dist in [4.0, 4.8, 5.6, 6.4]:
			for sg in [1.0, -1.0]:
				var p: Vector2 = q + side * dist * sg
				if not inner.has_point(p) or terrain.in_river(p.x, p.y) or terrain.path_dist(p.x, p.y) < 3.2:
					continue
				if terrain.height_at(p.x, p.y) > 2.5:
					continue
				var ok := true
				for pl in plots:
					if (pl as Vector2).distance_to(p) < plot_r:
						ok = false
						break
				for k in terrain.keepout:
					if ok and Vector2(k.x, k.y).distance_to(p) < k.z + 1.2:
						ok = false
				if ok:
					return p
	return Vector2.INF

func _place_events(bounds: Rect2) -> void:
	var kinds: Array = EVENTS.get(def["id"], [])
	for k in kinds.size():
		var lp: LanePath = paths[k % paths.size()]
		var along := lp.length * (0.32 if k % 2 == 0 else 0.6)
		var spot := _event_spot(lp, along, bounds)
		if spot == Vector2.INF:
			spot = _event_spot(lp, along, bounds, 3.0)
		if spot == Vector2.INF:
			continue
		terrain.keepout.append(Vector3(spot.x, spot.y, 2.4))
		var road := lp.sample(lp.closest(spot).y)
		var kind: String = kinds[k]
		var pos := Vector3(spot.x, terrain.height_at(spot.x, spot.y), spot.y)
		var ev := {"kind": kind, "pos": pos, "road": Vector3(road.x, terrain.walk_height(road.x, road.y), road.y), "cd": 0.0, "used": false}
		_event_visual(ev)
		var mk := Label3D.new()
		mk.text = "!"
		mk.font = Assets.font("ui_black")
		mk.font_size = 96
		mk.outline_size = 22
		mk.modulate = Color(1.0, 0.85, 0.3)
		mk.outline_modulate = Color(0.25, 0.12, 0.02)
		mk.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mk.no_depth_test = true
		mk.pixel_size = 0.012
		world.add_child(mk)
		mk.global_position = pos + Vector3(0, 3.0, 0)
		var bob := mk.create_tween().set_loops()
		bob.tween_property(mk, "position:y", pos.y + 3.4, 0.6).set_trans(Tween.TRANS_SINE)
		bob.tween_property(mk, "position:y", pos.y + 3.0, 0.6).set_trans(Tween.TRANS_SINE)
		ev["marker"] = mk
		events.append(ev)

func _event_visual(ev: Dictionary) -> void:
	var pos: Vector3 = ev["pos"]
	var n: Node3D
	match String(ev["kind"]):
		"rockfall":
			n = Assets.instance("rocks_v")
			n.scale = Vector3(1.35, 1.2, 1.35)
		"altar":
			n = Assets.instance("crystals")
			n.scale = Vector3.ONE * 1.3
			if not ev.has("disc"):
				ev["disc"] = _event_disc(pos + Vector3(0, 0.07, 0))
		_:
			n = Assets.instance("barrels")
			n.scale = Vector3.ONE * 1.05
	world.add_child(n)
	n.global_position = pos
	n.rotation.y = randf() * TAU
	_theme_overlay(n)
	ev["node"] = n

func _event_disc(p: Vector3) -> MeshInstance3D:
	_rune_disc(p, 3.2, Color(0.4, 0.95, 1.0, 0.8))
	return world.get_child(world.get_child_count() - 1) as MeshInstance3D

func _tap_event(sp: Vector2) -> bool:
	for ev in events:
		if ev["used"] or float(ev["cd"]) > 0.0:
			continue
		var p: Vector3 = ev["pos"] + Vector3(0, 1.4, 0)
		if cam_rig.cam.is_position_behind(p):
			continue
		if cam_rig.cam.unproject_position(p).distance_to(sp) < 54.0:
			_trigger_event(ev)
			return true
	return false

func _trigger_event(ev: Dictionary) -> void:
	var kind: String = ev["kind"]
	var pos: Vector3 = ev["pos"]
	(ev["marker"] as Node3D).visible = false
	Game.stat("events")
	match kind:
		"cache":
			ev["used"] = true
			var g := 50 + level_idx * 10
			add_gold(g, pos + Vector3(0, 1.0, 0))
			fx.coin_burst(pos + Vector3(0, 1.0, 0), 6)
			fx.magic_burst(pos + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.4), 1.0)
			overlay.float_text(pos + Vector3(0, 2.2, 0), tr("숨은 보급품 +%d") % g, UI.GOLD, 1.2)
			Audio.play("upgrade", -2.0)
			var nd: Node3D = ev["node"]
			var tw := nd.create_tween()
			tw.tween_property(nd, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(nd.queue_free)
		"rockfall":
			ev["cd"] = EVENT_CD["rockfall"]
			var rock: Node3D = ev["node"]
			var road: Vector3 = ev["road"]
			Audio.play("slam", -4.0, 0.1)
			var tw2 := rock.create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(rock, "global_position", road + Vector3(0, 0.4, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.tween_property(rock, "rotation:x", rock.rotation.x + TAU * 1.2, 0.6)
			tw2.chain().tween_callback(func(): _rock_impact(road, rock))
		"altar":
			ev["cd"] = EVENT_CD["altar"]
			fx.frost_nova(pos, 6.5)
			fx.magic_burst(pos + Vector3(0, 1.2, 0), Color(0.5, 0.9, 1.0), 1.6)
			fx.shockwave(pos, 6.5, Color(0.5, 0.9, 1.0))
			Audio.play("frost", 0.0, 0.05)
			for e: Enemy in enemies:
				if e.alive and e.global_position.distance_to(pos) < 6.5:
					e.slow(0.45, 4.0)
			if ev.has("disc"):
				(ev["disc"] as MeshInstance3D).visible = false

func _rock_impact(at: Vector3, rock: Node3D) -> void:
	fx.explosion(at, 1.1)
	fx.dust(at, 1.6)
	cam_rig.shake(0.6)
	Audio.play("boom", 0.0, 0.1, 2)
	var dmg := 160.0 * hp_mult
	for e: Enemy in enemies.duplicate():
		if e.alive and not e.flying and e.global_position.distance_to(at) < 2.8:
			e.damage(dmg, "physical", true, 0.5)
			if e.alive:
				e.stun(1.2)
	var tw := rock.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(rock, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(rock.queue_free)

var _evt_hint := ""
var _evt_hint_t := 0.0

## Recharge timers; a recharged boulder rises again on its ledge.
func _update_events(delta: float) -> void:
	if _evt_hint != "" and state == "playing" and cine.active == "":
		_evt_hint_t += delta
		if _evt_hint_t > 4.0:
			Game.stat("evt_hint_" + _evt_hint)
			var tip: String = {"cache": "길가의 금빛 ‘!’를 탭하면 숨은 보급품(골드)을 얻습니다",
				"rockfall": "금빛 ‘!’가 뜬 바위를 탭하면 길 위로 굴러 떨어져 적을 덮칩니다",
				"altar": "금빛 ‘!’가 뜬 제단을 탭하면 주변 적을 얼려 느리게 만듭니다"}[_evt_hint]
			hud.toast(tr("맵 장치"), tr(tip), "ic_map")
			_evt_hint = ""
	for ev in events:
		if ev["used"] or float(ev["cd"]) <= 0.0:
			continue
		ev["cd"] = float(ev["cd"]) - delta
		if float(ev["cd"]) <= 0.0:
			if ev["kind"] == "rockfall":
				_event_visual(ev)
				var nd: Node3D = ev["node"]
				var s := nd.scale
				nd.scale = s * 0.01
				nd.create_tween().tween_property(nd, "scale", s, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				fx.dust(ev["pos"], 0.8)
			elif ev.has("disc"):
				(ev["disc"] as MeshInstance3D).visible = true
			(ev["marker"] as Node3D).visible = true

# ------------------------------------------------------------------ set pieces
## Each region gets one composed scene in the clearest open ground beside the road, so maps
## read as places rather than random scatter (the scatter keeps clear of it).
const VIGNETTE := {"meadow": "farm", "river": "dock", "snow": "outpost", "night": "shrine",
	"autumn": "camp", "necro": "ritual", "ruins": "henge", "swamp": "bog"}

func _vignette_spot(bounds: Rect2, r: float) -> Vector2:
	var best := Vector2.INF
	var best_s := -1e9
	var hs: Array = def["hero_start"]
	var home := Vector2(hs[0], hs[1])
	var center := bounds.get_center()
	var gx := bounds.position.x + 3.0
	while gx <= bounds.end.x - 3.0:
		var gz := bounds.position.y + 3.0
		while gz <= bounds.end.y - 2.5:
			var p := Vector2(gx, gz)
			gz += 1.5
			var pd := terrain.path_dist(p.x, p.y)
			if pd < r + 1.6 or terrain.in_river(p.x, p.y) or p.distance_to(home) < r + 3.0:
				continue
			var pl_d := 99.0
			for pl in plots:
				pl_d = minf(pl_d, (pl as Vector2).distance_to(p))
			if pl_d < r + 2.0:
				continue
			var blocked := false
			for k in terrain.keepout:
				if Vector2(k.x, k.y).distance_to(p) < k.z + r:
					blocked = true
					break
			if blocked or terrain.height_at(p.x, p.y) > 2.5:
				continue
			var sc := -absf(pd - (r + 2.8)) * 0.9 - p.distance_to(center) * 0.07 + minf(pl_d - r, 6.0) * 0.15
			if sc > best_s:
				best_s = sc
				best = p
		gx += 1.5
	return best

func _place_vignette(bounds: Rect2) -> void:
	var kind: String = VIGNETTE.get(def["theme"], "")
	if kind == "":
		return
	var r := 4.4
	var c := _vignette_spot(bounds, r)
	if c == Vector2.INF:
		return
	terrain.keepout.append(Vector3(c.x, c.y, r + 0.8))
	# face the nearest stretch of road
	var to_road := Vector2(0, 1)
	var bd := 1e9
	for lp in paths:
		var cl: Vector2 = (lp as LanePath).closest(c)
		if cl.x < bd:
			bd = cl.x
			var q: Vector2 = (lp as LanePath).sample(cl.y)
			to_road = (q - c).normalized()
	var yaw := atan2(to_road.x, to_road.y)
	var basis := Basis(Vector3.UP, yaw)
	var put := func(model: String, lx: float, lz: float, rot_deg := 0.0, sc := Vector3.ONE) -> Node3D:
		var w := basis * Vector3(lx, 0, lz)
		var n := Assets.instance(model)
		world.add_child(n)
		n.position = Vector3(c.x + w.x, terrain.height_at(c.x + w.x, c.y + w.z) - 0.05, c.y + w.z)
		n.rotation.y = yaw + deg_to_rad(rot_deg)
		n.scale = sc
		_theme_overlay(n)
		if not Game.high_quality and model != "house" and not model.begins_with("tree"):
			for g in n.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return n
	var at := func(lx: float, lz: float, y := 0.0) -> Vector3:
		var w := basis * Vector3(lx, 0, lz)
		return Vector3(c.x + w.x, terrain.height_at(c.x + w.x, c.y + w.z) + y, c.y + w.z)
	match kind:
		"farm":
			put.call("house", -3.3, -1.8, 8.0, Vector3.ONE * 0.85)
			put.call("house", 3.2, -2.3, -10.0, Vector3.ONE * 0.8)
			for f in [[-3.9, 2.2, 90.0], [-1.3, 3.0, 0.0], [1.3, 3.0, 0.0], [3.9, 2.2, -90.0]]:
				put.call("fence", f[0], f[1], f[2])
			put.call("barrels", 0.1, -0.9, 30.0)
			put.call("lamp", 0.2, 1.2)
			for fl in [[-0.8, 1.4], [1.5, 1.3], [-4.3, 0.2]]:
				put.call("flowers", fl[0], fl[1], randf() * 360.0, Vector3.ONE * 1.2)
			put.call("tree_round_v", 0.2, -4.6, 0.0, Vector3.ONE * 1.1)
		"dock":
			put.call("house", -0.4, -1.8, 0.0)
			put.call("barrels", 2.2, 0.5, 15.0)
			put.call("barrels", 3.0, -0.6, 70.0, Vector3.ONE * 0.8)
			put.call("fence", -2.6, 1.9, 0.0)
			put.call("fence", 0.0, 2.5, 6.0)
			put.call("lamp", -2.6, 0.1)
			put.call("bush", -3.6, -1.3, 0.0, Vector3.ONE * 1.1)
			put.call("flowers", 1.4, 1.7, 0.0, Vector3.ONE * 1.2)
		"outpost":
			put.call("crystals", 0.0, 0.0, 0.0, Vector3.ONE * 1.5)
			put.call("crystals", -1.7, 1.1, 40.0, Vector3.ONE * 0.9)
			put.call("crystals", 1.6, 1.0, -30.0, Vector3.ONE)
			put.call("lamp", -3.0, -0.6)
			put.call("lamp", 3.0, -0.6)
			put.call("barrels", 2.5, -2.2, 10.0)
			put.call("fence", -2.6, 2.7, 20.0)
			put.call("fence", 2.6, 2.7, -20.0)
			_set_light(at.call(0.0, 0.0, 1.6), Color(0.55, 0.8, 1.0), 1.6, 8.0)
		"shrine":
			put.call("crystals", 0.0, 0.0, 0.0, Vector3.ONE * 1.7)
			for i in 6:
				var a := i * TAU / 6.0
				put.call("crystals", cos(a) * 2.7, sin(a) * 2.7, i * 50.0, Vector3.ONE * (0.75 + 0.1 * (i % 3)))
			_rune_disc(at.call(0.0, 0.0, 0.06), 6.4, Color(0.35, 0.95, 1.0, 0.75))
			_set_light(at.call(0.0, 0.0, 1.8), Color(0.4, 0.9, 1.0), 2.2, 9.0)
		"camp":
			for i in 7:
				var a := i * TAU / 7.0 + 0.3
				put.call("rocks_v", cos(a) * 2.3, sin(a) * 2.3, i * 47.0, Vector3.ONE * (0.5 + 0.08 * (i % 3)))
			fx.campfire(at.call(0.0, 0.0, 0.15))
			put.call("barrels", 3.5, -1.3, 20.0)
			put.call("barrels", 4.1, -0.3, 80.0, Vector3.ONE * 0.8)
			put.call("fence", -3.7, 0.5, 70.0)
			put.call("bush", -3.1, -2.7, 0.0, Vector3.ONE * 1.1)
		"ritual":
			for i in 8:
				var a := i * TAU / 8.0
				put.call("crystals", cos(a) * 3.0, sin(a) * 3.0, i * 45.0, Vector3.ONE * 0.85)
			_rune_disc(at.call(0.0, 0.0, 0.06), 7.0, Color(1.0, 0.3, 0.18, 0.8))
			put.call("lamp", -4.0, 0.0)
			put.call("lamp", 4.0, 0.0)
			_set_light(at.call(0.0, 0.0, 1.5), Color(1.0, 0.35, 0.2), 2.4, 9.0)
		"henge":
			for i in 7:
				var a := i * TAU / 7.0
				var tall := 2.2 if i % 3 != 1 else 1.1  # a few have fallen to stumps
				put.call("rocks_v", cos(a) * 3.0, sin(a) * 3.0, i * 31.0, Vector3(0.55, tall, 0.55))
			put.call("crystals", 0.0, 0.0, 0.0, Vector3.ONE * 1.3)
			_rune_disc(at.call(0.0, 0.0, 0.06), 5.2, Color(0.5, 1.0, 0.8, 0.55))
			_set_light(at.call(0.0, 0.0, 1.6), Color(0.5, 1.0, 0.8), 1.8, 8.0)
		"bog":
			put.call("crystals", -1.6, 0.2, 10.0, Vector3.ONE * 1.1)
			put.call("crystals", 1.4, -0.8, 70.0, Vector3.ONE * 0.8)
			put.call("crystals", 0.2, 1.6, 140.0, Vector3.ONE * 0.7)
			put.call("lamp", -3.2, -1.4)
			put.call("lamp", 3.1, 1.2)
			for b2 in [[-3.4, 1.8], [2.9, -2.6], [0.4, -3.2]]:
				put.call("bush", b2[0], b2[1], randf() * 360.0, Vector3.ONE * 1.2)
			_rune_disc(at.call(0.0, 0.0, 0.06), 5.6, Color(0.5, 1.0, 0.35, 0.6))
			_set_light(at.call(0.0, 0.0, 1.4), Color(0.55, 1.0, 0.45), 2.4, 9.0)

func _set_light(p: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	world.add_child(l)
	l.global_position = p

## Slowly turning glowing rune circle on the ground.
func _rune_disc(p: Vector3, size: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = FX.tex("fx_rune")
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = p
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "rotation:y", TAU, 60.0).from(0.0)

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
	_plot_mmi = Assets.multimesh("plot", _plot_xf, world, Game.high_quality)
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
		"ruins":
			terrain.decor_colorize = Color(0.4, 0.58, 0.52, 0.4)
		"swamp":
			terrain.decor_colorize = Color(0.3, 0.5, 0.38, 0.45)
		"necro":
			terrain.decor_colorize = Color(0.42, 0.3, 0.32, 0.85)
	var round_n := 26
	var pine_n := 26
	match theme:
		"river": pine_n = 34; round_n = 20
		"autumn": round_n = 40; pine_n = 12
		"snow": round_n = 0; pine_n = 52
		"night": round_n = 22; pine_n = 34
		"ruins": round_n = 18; pine_n = 16
		"swamp": round_n = 30; pine_n = 14
		"necro": round_n = 10; pine_n = 22
	var dark: bool = theme in ["night", "swamp", "necro"]
	var defs := []
	# [model, count, min spacing, region, scale min, scale max]
	if round_n > 0:
		defs.append(["tree_round_v", round_n, 3.2, "edge", 0.75, 1.25])
		defs.append(["tree_round_v", 3, 4.0, "inner", 0.65, 0.95])
	defs.append(["tree_pine_v", pine_n, 3.0, "edge", 0.7, 1.3])
	defs.append(["tree_pine_v", 3, 4.0, "inner", 0.6, 0.9])
	var rocky: bool = theme in ["ruins", "necro"]
	defs.append(["rocks_v", 22 if rocky else 14, 2.8, "near", 0.45, 0.9])
	defs.append(["rocks_v", 16 if rocky else 10, 3.5, "edge", 0.8, 1.5])
	if theme != "snow":
		defs.append(["bush", 10 if theme == "necro" else 18, 2.2, "near", 0.7, 1.15])
		defs.append(["flowers", 14 if dark else 30, 1.5, "inner", 0.8, 1.3])
	defs.append(["crystals", 12 if dark else (8 if theme == "ruins" else 5), 6.0, "near", 0.8, 1.3])
	defs.append(["lamp", 10 if dark else 6, 6.0, "inner", 1.0, 1.0])
	defs.append(["fence", 6, 5.0, "inner", 1.0, 1.0])
	defs.append(["barrels", 4, 6.0, "inner", 1.0, 1.0])
	defs.append(["house", 1 if theme in ["ruins", "necro", "swamp"] else 3, 9.0, "near", 0.9, 1.05])
	terrain.scatter_decor(defs, 99 + level_idx * 17)
	if dark:
		# lantern pools of light on the dark maps (warm, ghost-green in the marsh, ember-red at the citadel)
		var lc: Color = {"swamp": Color(0.6, 1.0, 0.5), "necro": Color(1.0, 0.45, 0.25)}.get(theme, Color(1.0, 0.72, 0.38))
		var n := 0
		for xf: Transform3D in terrain.decor_xf.get("lamp", []):
			if n >= (6 if Game.high_quality else 3):
				break
			var l := OmniLight3D.new()
			l.light_color = lc
			l.light_energy = 1.8
			l.omni_range = 7.0
			l.omni_attenuation = 1.6
			l.position = xf.origin + Vector3(0.6, 2.3, 0)
			world.add_child(l)
			n += 1
	var amb := {"snow": "snow", "autumn": "leaves", "night": "fireflies", "meadow": "motes", "river": "motes", "ruins": "motes", "swamp": "fireflies", "necro": "embers"}
	if amb.has(theme):
		fx.ambient(amb[theme])
	if theme in ["night", "swamp"]:
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

## Room the hero keeps around its spot: no prop is scattered inside it.
const HERO_CLEAR := 1.6
var _hero_at := Vector2.INF

## Where the hero appears: the level's `hero_start`, moved to the nearest spot that is clear of
## build plots (their stone rings are 1.8 m across the middle), set pieces, the river and steep
## ground, beside or on the road. The plots are placed with a random tie-break and the set pieces
## move with them, so a fixed point could land inside a ring or a prop; this runs after both.
func _hero_spot(bounds: Rect2) -> Vector2:
	var hs: Array = def["hero_start"]
	var want := Vector2(hs[0], hs[1])
	var inner := bounds.grow(-2.0)
	var best := want
	var best_cost := INF
	for ring in 13:
		var r := ring * 0.6
		var n := 1 if ring == 0 else 8 + ring * 4
		for i in n:
			var a := TAU * float(i) / float(n)
			var p := want + Vector2(cos(a), sin(a)) * r
			if not inner.has_point(p) or terrain.in_river(p.x, p.y):
				continue
			var ok := true
			for pl in plots:
				if (pl as Vector2).distance_to(p) < 1.8 + 1.0:
					ok = false
					break
			if not ok:
				continue
			for k in terrain.keepout:
				if Vector2(k.x, k.y).distance_to(p) < k.z + 0.8:
					ok = false
					break
			if not ok:
				continue
			# level ground under the feet
			var h0 := terrain.height_at(p.x, p.y)
			var steep := 0.0
			for d in [Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0, 0.7), Vector2(0, -0.7)]:
				steep = maxf(steep, absf(terrain.height_at(p.x + d.x, p.y + d.y) - h0))
			if steep > 0.3:
				continue
			# near the road, where the fighting is; close to the designed spot
			var pd := terrain.path_dist(p.x, p.y)
			var cost := r + maxf(pd - 2.5, 0.0) * 2.0
			if cost < best_cost:
				best_cost = cost
				best = p
		if best_cost <= r:
			break  # nothing further out can beat what was found
	return best

func _spawn_hero() -> void:
	var hs := _hero_at if _hero_at != Vector2.INF else Vector2(def["hero_start"][0], def["hero_start"][1])
	var p := Vector3(hs.x, terrain.walk_height(hs.x, hs.y), hs.y)
	hero = Hero.new()
	world.add_child(hero)
	hero.setup_hero(p)
	soldiers.append(hero)

# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	_time += delta
	if state == "playing":
		run_time += delta
	if selection.get("kind", "") == "enemy":
		_track_enemy_selection(delta)
	if state == "playing" or state == "ready":
		_update_spawns(delta)
		_update_waves(delta)
		for k in spell_cd:
			spell_cd[k] = maxf(spell_cd[k] - delta, 0.0)
		_update_events(delta)
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
		Audio.voice("ann_boss")
		Audio.play_music("boss", 1.0)
		if not cine.boss_intro(e):
			hud.show_banner("보스 출현!", DB.ENEMIES[type]["name"], Color(1.0, 0.4, 0.3))
			Audio.play("boss_intro", 0.0, 0.0)
			Audio.play("boss_roar", 2.0, 0.0)
			Game.vibrate(140)
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
		overlay.float_text(_wave_button_world(), tr("+%d 보너스!") % bonus, UI.GOLD, 1.3)
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
		hud.show_banner(tr("웨이브 %d") % (wave_idx + 1), "보스 웨이브!" if boss_wave else tr("적이 점점 강해집니다 (체력 x%.1f)") % DB.endless_hp_scale(wave_idx))
		Game.stat("endless_wave", wave_idx + 1, "max")
	else:
		hud.show_banner("마지막 웨이브!" if last else tr("웨이브 %d") % (wave_idx + 1), "적이 몰려옵니다!" if not last else "끝까지 버텨내세요!")
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
		hud.skill_cd.value = hero.skill_cd / hero.skill_cd_max()
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
	run_kills += 1
	run_gold += int(e.d["gold"])
	add_gold(int(e.d["gold"]), e.global_position)
	Game.stat("kills")
	Game.stat("gold", int(e.d["gold"]))
	if not cam_rig.cam.is_position_behind(e.global_position):
		hud.fly_coins(cam_rig.cam.unproject_position(e.aim_point()), clampi(int(e.d["gold"]) / 8 + 1, 1, 3))
	if e.boss:
		Game.stat("boss_kills")
		if e.type == "lich":
			Game.stat("lich_kills")
		if e.type == "ogre_king":
			Game.stat("ogre_king_kills")
		cine.boss_down(e)
		Audio.play_music(battle_music(), 2.5)
	Audio.play("coin", -10.0, 0.1)
	if hero:
		var xp := float(e.d["gold"]) * 2.0 * (1.3 if DB.up("hero_xp") else 1.0)
		hero.add_xp(xp)
		if Game.add_hero_xp(hero.hid, xp):
			hud.toast(tr("영웅 등급 상승! 등급 %d") % DB.hero_rank(hero.hid), "영웅 화면에서 재능 포인트를 사용하세요", DB.hero_def()["portrait"])
			Audio.play("levelup", -4.0)

func on_enemy_exit(e: Enemy) -> void:
	enemies.erase(e)
	if state == "won" or state == "lost":
		return
	lives = maxi(lives - int(e.d["lives"]), 0)
	var wk := str(wave_idx + 1)
	_lost_by_wave[wk] = int(_lost_by_wave.get(wk, 0)) + int(e.d["lives"])
	_leaks[e.type] = int(_leaks.get(e.type, 0)) + int(e.d["lives"])
	hud.set_lives(lives)
	Game.vibrate(45)
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
	if _tap_event(sp):
		return
	# hero pick (screen space)
	if hero and hero.alive and not cam_rig.cam.is_position_behind(hero.global_position):
		var hs := cam_rig.cam.unproject_position(hero.global_position + Vector3(0, 1.0, 0))
		if hs.distance_to(sp) < 52.0:
			_select_hero()
			return
	# enemy pick (screen space): tap a monster to read its live stats
	var pick: Enemy = null
	var pd := 34.0
	for e: Enemy in enemies:
		if not e.alive:
			continue
		var p3 := e.global_position + Vector3(0, e.height * 0.5, 0)
		if cam_rig.cam.is_position_behind(p3):
			continue
		var dd := cam_rig.cam.unproject_position(p3).distance_to(sp)
		if dd < pd:
			pd = dd
			pick = e
	if pick != null:
		_select_enemy(pick)
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
	hud.show_info(tr(DB.hero_def()["name"]) + "  Lv.%d" % hero.level, tr("땅을 탭하면 이동 · 스킬: %s (자동/수동)") % tr(DB.hero_def()["skill_name"]),
		[["heart", "%d/%d" % [hero.hp, hero.max_hp]], ["st_dmg", "%d-%d" % [hero.dmg[0], hero.dmg[1]]], ["st_armor", "%d%%" % int(hero.armor * 100)]])
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
		opts.append({"id": "upgrade", "icon": Assets.tex("upgrade"), "label": str(c), "coin": true, "cost": c, "enabled": gold >= c, "kind": "green"})
	elif t.level == 3:
		for m in t.data()["masteries"]:
			opts.append({"id": "mastery_" + m["id"], "icon": Assets.tex("m_" + m["id"]), "label": str(m["cost"]), "coin": true, "cost": m["cost"], "enabled": gold >= int(m["cost"]), "kind": "purple"})
	elif t.mastery != "" and t.ability == "":
		var ad := DB.ability_def(t.type, t.mastery)
		if not ad.is_empty():
			var ac := DB.ability_cost(t.type, t.mastery)
			opts.append({"id": "ability", "icon": Assets.tex("a_" + ad["id"]), "label": str(ac), "coin": true, "cost": ac, "enabled": gold >= ac, "kind": "teal"})
	if t.type == "barracks":
		opts.append({"id": "rally", "icon": Assets.tex("rally"), "instant": true})
	else:
		opts.append({"id": "priority", "icon": Assets.tex("target_" + t.priority), "label": PRIORITY_NAMES[t.priority], "instant": true})
	opts.append({"id": "sell", "icon": Assets.tex("sell"), "label": "+%d" % t.sell_value(), "coin": true, "kind": "red"})
	hud.radial.open(t.global_position + Vector3(0, 1.5, 0), opts)
	_show_range(t.global_position, t.range_r())
	var sp := _tower_special_text(t.stats)
	if t.ability != "":
		sp = ("◆ " + tr(DB.ability_def(t.type, t.mastery)["name"])) + (" · " + sp if sp != "" else "")
	hud.show_info(_tower_title(t), sp, _tower_stats(t.type, t.stats))

const PRIORITY_NAMES := {"first": "선두", "strong": "강적", "close": "근접"}

func _tower_title(t: Tower) -> String:
	if t.mastery != "":
		return DB.mastery_def(t.type, t.mastery)["name"]
	return "%s  Lv.%d" % [tr(t.data()["name"]), t.level]

func _tower_stats_text(type: String, st: Dictionary) -> String:
	var parts: Array = []
	for row in _tower_stats(type, st):
		parts.append(row[1])
	var sp := _tower_special_text(st)
	return " · ".join(parts) + ("\n" + sp if sp != "" else "")

## [icon, text, improved?] rows for the selection card; `prev` marks what an upgrade changes.
func _tower_stats(type: String, st: Dictionary, prev := {}) -> Array:
	var up := func(k: String) -> bool:
		return not prev.is_empty() and prev.has(k) and str(prev[k]) != str(st[k])
	if type == "barracks":
		return [["st_unit", tr("병사 %d") % st["count"], up.call("count")],
			["heart", "%d" % st["soldier_hp"], up.call("soldier_hp")],
			["st_dmg", "%d-%d" % [st["soldier_dmg"][0], st["soldier_dmg"][1]], up.call("soldier_dmg")],
			["st_armor", "%d%%" % int(st["soldier_armor"] * 100), up.call("soldier_armor")],
			["st_range", tr("집결 %.1f") % st["range"], up.call("range")]]
	return [["st_dmg", "%d-%d" % [st["dmg"][0], st["dmg"][1]], up.call("dmg")],
		["st_rate", tr("%.1f초") % st["rate"], up.call("rate")],
		["st_range", "%.1f" % st["range"], up.call("range")]]

func _tower_special_text(st: Dictionary) -> String:
	var extra: Array = []
	if st.has("splash"):
		extra.append(tr("폭발 범위 %.1f") % st["splash"])
	if st.has("multishot"):
		extra.append(tr("%d연발") % st["multishot"])
	if st.has("chain"):
		extra.append(tr("연쇄 %d") % st["chain"])
	if st.has("slow"):
		extra.append(tr("둔화 %d%%") % int(st["slow"] * 100))
	if st.has("crit"):
		extra.append(tr("치명 %d%%") % int(st["crit"] * 100))
	return " · ".join(extra)

# ------------------------------------------------------------------ enemy inspection

func _select_enemy(e: Enemy) -> void:
	_deselect()
	selection = {"kind": "enemy", "enemy": e}
	_enemy_info_t = 0.0
	_refresh_enemy_info()
	Audio.play("click", -6.0, 0.05)

func _track_enemy_selection(delta: float) -> void:
	var e: Enemy = selection.get("enemy")
	if e == null or not is_instance_valid(e) or not e.alive:
		_deselect()
		return
	_show_range(e.global_position, 0.75 if not e.boss else 1.4, Color(1.0, 0.35, 0.3))
	range_ring.global_position.y = e.global_position.y + 0.12  # follow bridges / ramps, not the river bed
	_enemy_info_t += delta
	if _enemy_info_t > 0.2:
		_enemy_info_t = 0.0
		_refresh_enemy_info()

func _refresh_enemy_info() -> void:
	var e: Enemy = selection.get("enemy")
	if e == null or not is_instance_valid(e):
		return
	var d: Dictionary = e.d
	var spd := float(d["speed"])
	var spd_t := "빠름" if spd >= 3.0 else ("느림" if spd < 1.5 else "보통")
	var title: String = tr(d["name"]) + (tr("  · 보스") if e.boss else "")
	hud.show_info(title, str(d.get("desc", "")), [
		["heart", "%d/%d" % [int(ceil(e.hp)), int(ceil(e.max_hp))]],
		["st_armor", tr("방어 %d%%") % int(float(d["armor"]) * 100)],
		["st_magic", tr("마저 %d%%") % int(float(d["mr"]) * 100)],
		["st_speed", spd_t],
		["coin", "%d" % int(d["gold"])],
		["skull", tr("생명 -%d") % int(d["lives"])]])

func _on_radial_preview(id: String) -> void:
	var kind: String = selection.get("kind", "")
	if kind == "plot":
		var p: Vector2 = plots[selection["idx"]]
		var t := id.trim_prefix("build_")
		var s: Dictionary = DB.TOWERS[t]["levels"][0]
		_show_range(Vector3(p.x, 0, p.y), s["range"], Color(0.5, 1.0, 0.6))
		hud.show_info(DB.TOWERS[t]["name"], DB.TOWERS[t]["desc"], _tower_stats(t, s))
	elif kind == "tower":
		var tw: Tower = towers[selection["idx"]]
		if id == "upgrade":
			var s2 := DB.tower_stats(tw.type, tw.level + 1, "")
			_show_range(tw.global_position, s2["range"], Color(0.5, 1.0, 0.6))
			hud.show_info(tr("업그레이드 → Lv.%d") % (tw.level + 1), _tower_special_text(s2), _tower_stats(tw.type, s2, tw.stats))
		elif id.begins_with("mastery_"):
			var mid := id.trim_prefix("mastery_")
			var s3 := DB.tower_stats(tw.type, 3, mid)
			var md := DB.mastery_def(tw.type, mid)
			_show_range(tw.global_position, s3["range"], md["tint"])
			hud.show_info(md["name"], md["desc"], _tower_stats(tw.type, s3, tw.stats))
		elif id == "ability":
			var ad := DB.ability_def(tw.type, tw.mastery)
			hud.show_info(tr("특수 능력 · ") + tr(ad["name"]), ad["desc"], [["coin", "%d" % DB.ability_cost(tw.type, tw.mastery)]])
		elif id == "sell":
			hud.show_info("타워 판매", "한 번 더 탭하면 판매합니다.", [["coin", tr("+%d 골드") % tw.sell_value()]])
		elif id == "priority":
			hud.show_info(tr("공격 우선순위: ") + tr(PRIORITY_NAMES[tw.priority]), "탭할 때마다 변경: 선두(가장 앞선 적) → 강적(체력 최대) → 근접(가장 가까운 적)")

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
	if (id == "upgrade" or id.begins_with("mastery_")) and not tower.model_ready(tower.level + 1):
		# web, first battle: the upgraded towers are still downloading (Content, towers chunk)
		Audio.play("error", -4.0)
		hud.toast("업그레이드 준비 중", tr("추가 데이터를 받는 중...") + " %d%%" % int(Content.progress(["towers"]) * 100.0), "upgrade")
		return
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
		# one-time pointer to the next step (special abilities), for players who have not found it yet
		if int(Game.stats.get("abilities", 0)) == 0 and int(Game.stats.get("ability_tip", 0)) == 0:
			Game.stats["ability_tip"] = 1
			var ad0 := DB.ability_def(tower.type, mid)
			hud.toast("특수 능력을 배울 수 있어요", "전문화한 타워를 다시 탭하면 특수 능력을 배울 수 있어요.", "a_" + str(ad0.get("id", "poison")))
	elif id == "ability":
		var ac := DB.ability_cost(tower.type, tower.mastery)
		if gold < ac or tower.ability != "":
			Audio.play("error", -4.0)
			return
		gold -= ac
		hud.set_gold(gold)
		tower.buy_ability()
		Game.stat("abilities")
		Audio.play("upgrade", 0.0)
		var ad := DB.ability_def(tower.type, tower.mastery)
		hud.show_banner(ad["name"], "특수 능력 습득!", Color(0.45, 0.9, 1.0))
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
		overlay.float_text(tower.global_position + Vector3(0, 4.5, 0), tr("우선순위: ") + tr(PRIORITY_NAMES[pr]), Color(1.0, 0.7, 0.5), 1.0)
		_select_tower(idx)
	elif id == "rally":
		hud.radial.close()
		targeting = "rally"
		_show_range(tower.global_position, tower.range_r(), Color(0.5, 0.8, 1.0))
		hud.target_hint.text = "집결 지점을 탭하세요 (길 위, 범위 내)"

func _spell_pressed(id: String) -> void:
	if Game.challenge:
		return
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
	if Game.challenge and t in ["meteor", "reinforce"]:
		return
	match t:
		"meteor":
			spell_cd["meteor"] = spell_defs["meteor"]["cd"]
			Game.stat("meteors")
			_spells_used += 1
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
			_spells_used += 1
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
	var p := UI.framed("card", 6)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.add_child(UI.bust(Assets.tex("portrait_" + type), 84, 1.3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.add_child(UI.ink("새로운 적", UI.T_SMALL, UI.EMBER, "ui_black"))
	vb.add_child(UI.ink(e["name"], 23, UI.INK, "title_kr"))
	var tw_w := hud.note_width() - 84.0 - 12.0 - 26.0
	var desc := UI.ink(tr(e["desc"]), UI.T_SMALL, UI.INK_SOFT)
	UI.wrap_words(desc, tw_w)
	desc.custom_minimum_size.x = tw_w - 6.0
	vb.add_child(desc)
	hb.add_child(vb)
	p.add_child(hb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# joins the HUD's notice column (under the top bar, after the selection card on an upright
	# phone), drops in, stays for five seconds, fades out
	hud.add_note(p)
	_info_card = p
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

func _clear_cards() -> void:
	if _info_card and is_instance_valid(_info_card):
		_info_card.queue_free()
	_info_card = null
	_deselect()

## Keyboard shortcuts: Esc/P pause, Space next wave, F speed, 1/2 spells, H hero, Q hero skill.
func hotkey(k: int) -> bool:
	if k == KEY_ESCAPE or k == KEY_P:
		if get_tree().paused and _modal != null:
			_resume()
		elif targeting != "" and k == KEY_ESCAPE:
			targeting = ""
			hud.target_hint.text = ""
		elif k == KEY_ESCAPE and _modal == null and hud.radial.visible:
			# Esc closes what is open first (the build / upgrade ring), then pauses
			_deselect()
		elif _modal == null:
			_pause()
		return true
	if _modal != null or state == "won" or state == "lost":
		return false
	if cine and cine.active != "":
		if k == KEY_SPACE or k == KEY_ENTER:
			cine.skip()
		return true
	match k:
		KEY_SPACE:
			_call_wave()
		KEY_F:
			_toggle_speed()
		KEY_1:
			_spell_pressed("meteor")
		KEY_2:
			_spell_pressed("reinforce")
		KEY_H:
			_select_hero()
		KEY_Q:
			if hero:
				hero.cast_skill()
		_:
			return false
	return true

## Mobile app switch / browser tab hidden: pause so nobody loses lives in the background.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if Game.autopause and state == "playing" and _modal == null and is_inside_tree():
			_pause()

func _toggle_speed() -> void:
	fast = not fast
	Engine.time_scale = 2.0 if fast else 1.0
	hud.set_speed(fast)

func _pause() -> void:
	if _modal != null or state == "won" or state == "lost":
		return
	if cine:
		cine.abort()  # a cut-scene hides the HUD the pause menu lives in
	get_tree().paused = true
	_clear_cards()
	_modal = hud.modal("일시 정지", func(vb: VBoxContainer):
		vb.add_theme_constant_override("separation", 10)
		vb.add_child(_volume_row("음악", Game.music_volume, func(v): Game.music_volume = v; Audio.update_music_volume(); Game.save()))
		vb.add_child(_volume_row("효과음", Game.sfx_volume, func(v): Game.sfx_volume = v; Game.save()))
		var hq := CheckButton.new()
		hq.text = "고품질 그래픽"
		hq.button_pressed = Game.high_quality
		hq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hq.toggled.connect(func(v): Game.high_quality = v; Game.apply_quality(); Game.save())
		vb.add_child(hq)
		# language: labels switch at once; the menu is rebuilt so its own lines follow
		vb.add_child(UI.choice("언어", UI.LANGUAGES, Game.language, func(v):
			if str(v) == Game.language:
				return
			Game.language = v
			Lang.apply(v)
			Game.save()
			hud.refresh_language()
			if _modal:
				_modal.queue_free()
				_modal = null
			_pause(), 92.0))
		if not Game.is_mobile and not Game.tall:
			var keys := UI.ink("Esc 일시 정지   Space 다음 웨이브   F 배속   1, 2 주문   H 영웅   Q 영웅 스킬", UI.T_SMALL, UI.MUTED)
			keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(keys)
		var sp := Control.new()
		sp.custom_minimum_size.y = 4
		vb.add_child(sp)
		var b2 := UI.button("다시 시작", 20, false, Vector2(0, 52), "secondary")
		b2.icon = Assets.tex("ic_retry")
		b2.pressed.connect(func(): Game.start_level(level_idx) if not Game.endless else Game.start_endless(level_idx))
		var b3 := UI.button("지도로", 20, false, Vector2(0, 52), "secondary")
		b3.icon = Assets.tex("ic_map")
		b3.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		vb.add_child(UI.action_row([b3, b2]))
		var b1 := UI.button("계속하기", 24, true, Vector2(0, 60), "primary")
		b1.icon = Assets.tex("ic_play")
		b1.pressed.connect(_resume)
		b1.grab_focus.call_deferred(true)  # Enter presses it; the ring shows only once the keyboard moves focus
		vb.add_child(b1), 440, "", _resume)

## The phone was turned during the pause menu: open it again, laid out for the new shape.
func _on_layout_changed() -> void:
	if _modal and get_tree().paused and (state == "playing" or state == "ready"):
		_modal.queue_free()
		_modal = null
		_pause()

func _volume_row(label: String, v: float, cb: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := UI.label(label, UI.T_BODY, UI.TEXT, 0, "ui")
	l.custom_minimum_size.x = 112  # "Sound FX" too, so both sliders line up in either language
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = v
	s.custom_minimum_size = Vector2(160, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var prev_stars := int(Game.stars[level_idx])
	if Game.challenge:
		stars = prev_stars
		Game.stat("iron_%d" % level_idx, 1, "max")
		var iron_n := 0
		for li in DB.LEVELS.size():
			if Game.iron_done(li):
				iron_n += 1
		Game.stat("iron_clears", iron_n, "max")
	else:
		Game.set_stars(level_idx, stars)
	Game.stat("wins")
	if lives >= max_l:
		Game.stat("flawless")
	if Game.difficulty == 1:
		Game.stat("heroic_wins")
	if hero and hero.hid == "sera":
		Game.stat("sera_wins")
	if hero and hero.hid == "ren":
		Game.stat("ren_wins")
	var st_total := 0
	for v in Game.stars:
		st_total += int(v)
	Game.stat("stars", st_total, "max")
	_log_run("won", stars)
	Game.save()
	Audio.voice("ann_victory", 0.0, 1.0)
	cine.abort()
	# the winning moment plays in slow motion, then eases back to normal speed (real-time tween)
	Engine.time_scale = 0.3
	var slow := create_tween()
	slow.set_ignore_time_scale(true)
	slow.tween_interval(0.35)
	slow.tween_method(func(v: float): Engine.time_scale = v, 0.3, 1.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	hud.flash(Color(1.0, 0.9, 0.6, 0.35))
	_celebrate()
	Audio.play("victory", 0.0, 0.0)
	Audio.play_music("menu", 3.0)
	_clear_cards()
	if level_idx == DB.LEVELS.size() - 1 and prev_stars == 0 and not Game.endless and not Game.testing:
		# first time the campaign is won: the epilogue plays before the results
		get_tree().create_timer(1.8, true, false, true).timeout.connect(func(): cine.story(DB.STORY["epilogue"], func(): _victory_modal(stars, prev_stars)))
	else:
		get_tree().create_timer(1.6, true, false, true).timeout.connect(func(): _victory_modal(stars, prev_stars))

## Everyone still standing cheers; fireworks go up over the gate.
func _celebrate() -> void:
	for s: Soldier in soldiers:
		if s.alive and s != hero:
			s.celebrate()
	if hero and hero.alive:
		hero.celebrate()
		cam_rig.focus(hero.global_position, 20.0)
	# fireworks go up where the camera is looking (the hero, else the gate)
	var at := cam_rig.target
	if hero and hero.alive:
		at = hero.global_position
	elif not paths.is_empty():
		var lp: LanePath = paths[0]
		var g := lp.sample(lp.length)
		at = Vector3(g.x, 0, g.y)
	cine.victory_fireworks(Vector3(at.x, terrain.height_at(at.x, at.z), at.z))

func battle_music() -> String:
	if Game.endless:
		return "battle"
	return "battle_dark" if def.get("theme", "") in ["night", "necro", "ruins", "swamp"] else "battle"

func _victory_modal(stars: int, prev_stars: int) -> void:
	var max_l: int = max_lives
	var fx: ResultFX
	var t0 := 0.5                                   # after the card and the ribbon have landed
	var t_done := t0 + maxi(stars, 1) * 0.42 + 0.2  # the last star has landed
	_modal = hud.modal("승리!", func(vb: VBoxContainer):
		vb.add_theme_constant_override("separation", 14)
		# the star stage: a fixed-width block centred in the card (it used to hug the left edge)
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(420, 150)
		stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.name = "StarStage"
		vb.add_child(stage)
		var mid := Vector2(210, 64)
		var rays := UI.icon(UI.kit("rays"), 320)
		rays.name = "Rays"
		rays.size = Vector2(320, 320)
		rays.position = mid - rays.size * 0.5
		rays.pivot_offset = rays.size * 0.5
		rays.modulate = Color(1, 0.9, 0.6, 0.0)
		stage.add_child(rays)
		var rt := rays.create_tween().set_loops()
		rt.set_ignore_time_scale(true)
		rt.tween_property(rays, "rotation", TAU, 14.0).from(0.0)
		var spots := [[Vector2(210 - 124, 86), 84.0], [mid, 108.0], [Vector2(210 + 124, 86), 84.0]]
		for i in 3:
			var sz: float = spots[i][1]
			var base := UI.icon(Assets.tex("star_empty"), int(sz))
			base.size = Vector2(sz, sz)
			base.position = spots[i][0] - base.size * 0.5
			stage.add_child(base)
		# four results; their numbers run up once the stars are in
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 34)
		grid.add_theme_constant_override("v_separation", 6)
		var cg := CenterContainer.new()
		cg.add_child(grid)
		vb.add_child(cg)
		var rows := [
			["heart", func(v): return tr("남은 생명 %d / %d") % [v, max_l], lives],
			["skull", func(v): return tr("처치 %d") % v, run_kills],
			["coin", func(v): return tr("획득 골드 %d") % v, run_gold],
			["st_rate", func(v): return tr("전투 %d:%02d") % [v / 60, v % 60], int(run_time)],
		]
		for r in rows:
			var stl := UI.stat(r[0], r[1].call(r[2]), 19, UI.TEXT)
			stl.set_meta("fmt", r[1])
			stl.set_meta("to", r[2])
			grid.add_child(stl)
		var gained := maxi(stars - prev_stars, 0)
		var notes: Array[Label] = []
		if Game.challenge:
			notes.append(UI.label("철인 도전 성공! 지역 카드에 철인 배지가 붙었습니다", 19, Color(1.0, 0.62, 0.45), 5, "ui_black"))
		elif gained > 0 or (Game.difficulty == 1):
			notes.append(UI.label((tr("새로 얻은 ★ %d  — 왕국 강화에 사용하세요") % gained) if gained > 0 else "영웅 난이도 클리어!", 19, UI.GOLD, 5, "ui_black"))
		if level_idx >= DB.LEVELS.size() - 1:
			notes.append(UI.label("왕국을 지켜냈습니다! 모든 지역 정복", 21, UI.GOLD, 5, "ui_black"))
		for nl in notes:
			# long lines (English especially) wrap inside the card instead of running past its edge
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size.x = minf(500.0, hud.root.get_viewport_rect().size.x - 60.0)
			nl.name = "Note"
			vb.add_child(nl)
		# map and retry on the left, the way forward on the right and widest
		var btns: Array = []
		var mb := UI.button("지도", 20, false, Vector2(0, 56), "secondary")
		mb.icon = Assets.tex("ic_map")
		mb.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		btns.append(mb)
		var rb := UI.button("다시", 20, false, Vector2(0, 56), "secondary")
		rb.icon = Assets.tex("ic_retry")
		rb.pressed.connect(func(): Game.start_level(level_idx))
		btns.append(rb)
		if level_idx < DB.LEVELS.size() - 1:
			var nb := UI.button("다음 지역", 22, true, Vector2(0, 56), "primary")
			nb.icon = Assets.tex("ic_play")
			nb.name = "Next"
			nb.pressed.connect(func(): Game.start_level(level_idx + 1))
			btns.append(nb)
		var row := UI.action_row(btns)
		row.name = "Buttons"
		if btns.size() == 3:
			(btns[2] as Control).size_flags_stretch_ratio = 1.7
		vb.add_child(row), 560, "red")
	# --- the sequence (see ResultFX): ribbon slam, stars one by one, numbers, then the buttons
	fx = ResultFX.new(_modal, _modal.get_meta("center"))
	_modal.set_meta("fx", fx)
	# a tap anywhere (backdrop or card) fast-forwards the sequence
	var skip_tap := func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			fx.skip()
	_modal.gui_input.connect(skip_tap)
	(_modal.get_meta("panel") as Control).gui_input.connect(skip_tap)
	fx.slam(_modal.get_meta("ribbon"), 0.15)
	var stage: Control = _modal.find_child("StarStage", true, false)
	var spots := [[Vector2(210 - 124, 86), 84.0], [Vector2(210, 64), 108.0], [Vector2(210 + 124, 86), 84.0]]
	for i in stars:
		fx.star(stage, spots[i][0], spots[i][1], t0 + i * 0.42, i)
	# (a lambda's assignments stay inside it: the parts built there are looked up by name)
	var rays: Control = stage.get_node("Rays")
	var rt := fx.tween(rays)
	rt.tween_property(rays, "modulate:a", 0.45 + 0.15 * stars, 0.5).set_delay(t0 + 0.2)
	if stars >= 3:
		# a perfect clear gets the full celebration
		var ct := fx.tween(_modal)
		ct.tween_interval(t_done - 0.1)
		ct.tween_callback(func():
			Audio.play("levelup", -4.0)
			fx.flash(stage, Vector2(210, 64), 360.0, Color(1.0, 0.9, 0.55)))
		fx.confetti(70, t_done - 0.1)
	var k := 0
	for stl in _modal.find_children("*", "HBoxContainer", true, false):
		if not stl.has_meta("fmt"):
			continue
		fx.reveal(stl, t_done + k * 0.08)
		var l: Label = stl.get_child(1)
		fx.count_up(l, stl.get_meta("fmt"), int(stl.get_meta("to")), t_done + k * 0.08, 0.7)
		k += 1
	for nl in _modal.find_children("Note", "Label", true, false):
		fx.reveal(nl, t_done + 0.55)
		var nt := fx.tween(nl)
		nt.tween_interval(t_done + 0.55)
		nt.tween_callback(func(): Audio.play("coin", -6.0))
	var btns: Control = _modal.find_child("Buttons", true, false)
	var bi := 0
	for b in btns.get_children():
		fx.reveal(b, t_done + 0.75 + bi * 0.09)
		bi += 1
	var nb: Control = btns.get_node_or_null("Next")
	if nb:
		var pt := fx.tween(nb)
		pt.tween_interval(t_done + 1.2)
		pt.tween_callback(func(): ResultFX.breathe(nb))

const DEFEAT_TIPS := [
	"오크 돌격병은 방어력이 높아요. 마법 탑으로 녹이세요.",
	"가고일은 하늘을 날아요. 궁수 탑과 마법 탑만 공격할 수 있어요.",
	"병영 병사로 길목을 막으면 궁수와 포병이 안전하게 공격해요.",
	"웨이브 버튼을 일찍 누르면 보너스 골드를 받아요. 여유가 있을 때 활용하세요.",
	"주술사는 주변 적을 치료해요. 먼저 처치하도록 우선순위를 '강적'으로 바꿔 보세요.",
	"유성 낙하는 적이 뭉쳤을 때 쓰면 효과가 커요.",
	"폭탄병은 병사를 무시하고 달려요. 길 초입에 화력을 모으세요.",
	"레벨 3 타워의 전문화가 전세를 뒤집어요. 상황에 맞는 쪽을 고르세요.",
	"해골 기사는 한 번 다시 일어나요. 마법 피해가 더 잘 들어요.",
	"전문화한 타워를 다시 탭하면 특수 능력을 배울 수 있어요.",
	"리치 군주는 해골을 계속 불러내요. 광역 공격으로 잔챙이를 정리하세요.",
]

func _defeat() -> void:
	if state == "lost":
		return
	state = "lost"
	Engine.time_scale = 1.0
	Audio.play("defeat", 0.0, 0.0)
	Audio.play_music("", 1.5)
	Game.vibrate(300)
	_log_run("lost")
	Game.save()
	_clear_cards()
	cine.defeat(_env, _after_defeat)

func _after_defeat() -> void:
	if Game.endless:
		_endless_over()
		return
	Audio.voice("ann_defeat", 0.0, 1.0)
	_modal = hud.modal("패배...", func(vb: VBoxContainer):
		var l := UI.label("성문이 뚫렸습니다. 전략을 바꿔 다시 도전하세요!", 20, UI.TEXT, 0, "ui_black")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
		var grid := HBoxContainer.new()
		grid.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_theme_constant_override("separation", 28)
		grid.add_child(UI.stat("skull", tr("처치 %d") % run_kills, 18, UI.TEXT))
		grid.add_child(UI.stat("st_rate", tr("웨이브 %d / %d") % [maxi(wave_idx + 1, 0), waves.size()], 18, UI.TEXT))
		vb.add_child(grid)
		# one tip, set apart as advice rather than a second message
		var tipp := UI.framed("well", 8)
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", 12)
		var tip := UI.ink(str(DEFEAT_TIPS[randi() % DEFEAT_TIPS.size()]), UI.T_BODY, UI.INK)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(UI.ink("팁", UI.T_SMALL, UI.GOLD, "ui_black"))
		th.add_child(tip)
		tipp.add_child(th)
		vb.add_child(tipp)
		var mb := UI.button("지도로", 20, false, Vector2(0, 56), "secondary")
		mb.icon = Assets.tex("ic_map")
		mb.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		var rb := UI.button("다시 도전", 22, true, Vector2(0, 56), "primary")
		rb.icon = Assets.tex("ic_retry")
		rb.pressed.connect(func(): Game.start_level(level_idx))
		var row := UI.action_row([mb, rb])
		rb.size_flags_stretch_ratio = 1.6
		vb.add_child(row), 520, "dark")

func _on_achievement(id: String) -> void:
	for a in DB.ACHIEVEMENTS:
		if a["id"] == id:
			hud.toast(tr("업적 달성: ") + tr(a["name"]), tr(a["desc"]) + tr("  (보상 ★1)"), a["icon"])
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
	_clear_cards()
	_modal = hud.modal("전투 종료", func(vb: VBoxContainer):
		var l := UI.title(tr("웨이브 %d") % reached, 54, "title_kr", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		var r := UI.label("신기록 달성!" if record else tr("최고 기록  웨이브 %d") % maxi(best, reached), 23, Color(1.0, 0.75, 0.4) if record else UI.TEXT, 5, "ui_black")
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(r)
		var grid := HBoxContainer.new()
		grid.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_theme_constant_override("separation", 28)
		grid.add_child(UI.stat("skull", tr("처치 %d") % run_kills, 18, UI.TEXT))
		grid.add_child(UI.stat("coin", tr("획득 골드 %d") % run_gold, 18, UI.TEXT))
		vb.add_child(grid)
		var mb := UI.button("지도로", 20, false, Vector2(0, 56), "secondary")
		mb.icon = Assets.tex("ic_map")
		mb.pressed.connect(func(): Game.goto_scene("res://scenes/main_menu.tscn"))
		var rb := UI.button("다시 도전", 22, true, Vector2(0, 56), "primary")
		rb.icon = Assets.tex("ic_retry")
		rb.pressed.connect(func(): Game.start_endless(level_idx))
		var row := UI.action_row([mb, rb])
		rb.size_flags_stretch_ratio = 1.6
		vb.add_child(row), 520, "blue")

## One line in the playtest log: how far the run got, where lives were lost and what was built.
func _log_run(result: String, stars := 0) -> void:
	if _logged or Game.testing or wave_idx < 0:
		return
	_logged = true
	var tw := []
	for k in towers:
		var t: Tower = towers[k]
		tw.append("%s%d%s%s" % [t.type.substr(0, 2), t.level, ("-" + t.mastery) if t.mastery != "" else "", "+" if t.ability != "" else ""])
	Game.log_play({"lv": level_idx, "d": Game.difficulty, "e": Game.endless, "c": Game.challenge, "h": hero.hid if hero else "",
		"r": result, "s": stars, "wv": wave_idx + 1, "nw": waves.size(), "li": lives, "ml": max_lives,
		"t": int(run_time), "k": run_kills, "g": gold, "tw": tw, "lw": _lost_by_wave, "lt": _leaks,
		"sp": _spells_used, "hl": hero.level if hero else 0, "ts": int(Time.get_unix_time_from_system())})

func _exit_tree() -> void:
	if state == "playing" or state == "ready":
		_log_run("quit")
	if Game.achievement_unlocked.is_connected(_on_achievement):
		Game.achievement_unlocked.disconnect(_on_achievement)
	if I == self:
		I = null
	Engine.time_scale = 1.0
