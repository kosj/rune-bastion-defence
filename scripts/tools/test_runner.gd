extends Node
## Automated playtest / screenshot harness.  Args (after --):  level=<i> mode=<auto|shots|menu> speed=<f> shots=<dir>

var args := {}
var level: LevelMain
var t := 0.0
var shot_i := 0
var built := false
var _next_report := 0.0
var _next_ab := 0.0
var _shots_at := []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep shooting while the game is paused (pause menu shots)
	Game.autopause = false
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.get("cine", "0") == "1":
		Game.testing = false  # review runs: keep the level intro / boss cinematics
	var mode: String = args.get("mode", "auto")
	if args.has("lang"):
		Game.language = args["lang"]
		Lang.apply(Game.language)
	if args.has("perf_off"):
		# A/B cost probe: switch a whole subsystem off for every node that enters the tree
		var off: String = args["perf_off"]
		get_tree().node_added.connect(func(n):
			if off.contains("anim") and n is AnimationMixer:
				(n as AnimationMixer).set_deferred("active", false)
			if off.contains("particles") and n is CPUParticles3D:
				n.set_deferred("emitting", false)
			if off.contains("tween") and n is Node:
				pass)
	if args.has("hq"):
		Game.high_quality = args["hq"] == "1"
		Game.apply_quality()
	if args.has("ui_scale"):
		Game.ui_scale = float(args["ui_scale"])
		Game._fit_ui()
	if args.get("selftest", "0") == "1":
		_selftest()
		return
	if mode == "menu":
		if args.get("progress", "0") == "1":
			# fake a mid-game save so locked content shows up unlocked
			Game.stars = [3, 3, 2, 1, 0, 0, 0, 0]
			if args.get("progress_all", "0") == "1":
				Game.stars = [3, 3, 3, 2, 3, 2, 1, 0]
				Game.hero_xp = {"kael": 3000.0, "sera": 900.0}
			if args.get("progress_max", "0") == "1":
				Game.stars = [3, 3, 3, 3, 3, 3, 3, 3, 3, 2]
			if args.has("stars_csv"):
				Game.stars = Array((args["stars_csv"] as String).split(",")).map(func(x): return int(x))
			while Game.stars.size() < DB.LEVELS.size():
				Game.stars.append(0)
			Game.seen_enemies = {"goblin": true, "wolf": true, "shaman": true, "orc": true, "sapper": true, "gargoyle": true}
			Game.stats = {"kills": 812, "wins": 4, "towers": 41, "masteries": 5, "meteors": 12, "gold": 9000, "endless_wave": 0}
			if args.get("progress_max", "0") == "1":
				Game.stats["iron_1"] = 1
			Game._check_achievements()
		if args.has("hero"):
			Game.hero_id = args["hero"]
			var need_m := int((DB.HEROES.get(Game.hero_id, {}) as Dictionary).get("unlock", -1))
			if need_m >= 0 and Game.stars[need_m] == 0:
				Game.stars[need_m] = 1
		_menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(_menu)
		_shots_at = [3.0, 6.0]
		if args.has("backdrop"):
			# title backdrop for the streamed start: the diorama at the opening camera pose, no UI
			_shots_at = []
			get_tree().create_timer(3.0).timeout.connect(_render_backdrop)
		if args.has("start_at"):
			# press start on level 1 from the title screen (streamed content: before it has arrived);
			# the menu is made the current scene so the scene change frees it as in the game
			(func(): get_tree().current_scene = _menu).call_deferred()
			get_tree().create_timer(float(args["start_at"])).timeout.connect(func(): Game.start_level(0))
		if args.has("open"):
			get_tree().create_timer(4.0).timeout.connect(func(): _menu.call(args["open"]))
		if args.has("map_card"):
			# open a region briefing card on the world map (endless card for "e")
			get_tree().create_timer(4.6).timeout.connect(func():
				var wm = _menu.get("_select")
				if wm:
					if args["map_card"] == "e":
						wm._open_endless_card()
					else:
						wm._open_card(int(args["map_card"])))
		if args.has("shot_times"):
			_shots_at = Array((args["shot_times"] as String).split(",")).map(func(x): return float(x))
		return
	Game.current_level = int(args.get("level", "0"))
	if args.get("intro", "1") == "0":
		Game.stats["intro_%d" % Game.current_level] = 1
	Game.seen_tutorial = args.get("tutorial", "0") == "0"
	Game.difficulty = int(args.get("diff", "0"))
	Game.hero_id = args.get("hero", "kael")
	var need := int((DB.HEROES.get(Game.hero_id, {}) as Dictionary).get("unlock", -1))
	if need >= 0 and Game.stars[need] == 0:
		Game.stars[need] = 1
	Game.endless = args.get("endless", "0") == "1"
	Game.challenge = args.get("challenge", "0") == "1"
	if args.get("alt_mastery", "0") == "1":
		BEST_MASTERY = {"archer": "ranger", "barracks": "lancer", "mage": "frost", "artillery": "cluster"}
	# star upgrades a player would plausibly own by this level (default: 3 stars per earlier level)
	Game.upgrades = {}
	var budget := int(args.get("stars", str(Game.current_level * 3)))
	for id in ["gold", "archer_dmg", "mage_dmg", "bar_hp", "meteor", "reinforce", "art_splash", "hero", "archer_range", "mage_speed", "art_dmg", "bar_dmg"]:
		for u in DB.UPGRADES:
			if u["id"] == id and budget >= int(u["cost"]):
				budget -= int(u["cost"])
				Game.upgrades[id] = true
	if args.has("prewarm"):
		# what the briefing card preloads (Content.warm), done up front: first-use hitch comparison
		var t0 := Time.get_ticks_msec()
		for n in Assets.battle_models(Game.current_level):
			Assets.warm_one(n)
		print("PREWARM %d ms" % (Time.get_ticks_msec() - t0))
	var ps: PackedScene = load("res://scenes/level.tscn")
	level = ps.instantiate()
	get_tree().root.add_child.call_deferred(level)
	if args.has("shot_times"):
		for s in (args["shot_times"] as String).split(","):
			_shots_at.append(float(s))

var _hitch_us := 0
var _hitch_log: Array = []

func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.01)
	var mode: String = args.get("mode", "auto")
	if args.has("hitch"):
		# hitch=<ms>: log every frame slower than that (first-use loads / shader compiles)
		var now := Time.get_ticks_usec()
		if _hitch_us > 0 and LevelMain.I:
			var ms := (now - _hitch_us) / 1000.0
			if ms > float(args["hitch"]):
				var L := LevelMain.I
				var kinds := {}
				for e in L.enemies:
					kinds[(e as Enemy).type] = true
				var tws := {}
				for k in L.towers:
					tws["%s%d" % [(L.towers[k] as Tower).type, (L.towers[k] as Tower).level]] = true
				print("HITCH t=%.1f %.0fms tick=%d enemies=%s towers=%s" % [t, ms, Time.get_ticks_msec(), ",".join(kinds.keys()), ",".join(tws.keys())])
				_hitch_log.append(ms)
		_hitch_us = now
	if args.has("dbg_anim") and t >= float(args["dbg_anim"]) and not has_meta("dbg_anim") and LevelMain.I:
		set_meta("dbg_anim", true)
		for bl in get_tree().root.find_children("*", "BlobLayer", true, false):
			if bl.members.size() > 0:
				print("DBGBLOB xf0=", bl.multimesh.get_instance_transform(0), " model0=", bl.members[0].global_position, " mesh=", bl.multimesh.mesh, " mat=", bl.material_override, " gxf=", bl.global_transform)
			print("DBGBLOB members=", bl.members.size(), " vis=", bl.multimesh.visible_instance_count, " inside=", bl.is_inside_tree(), " parent=", bl.get_parent(), " aabb=", bl.custom_aabb, " visible=", bl.is_visible_in_tree())
		print("DBGBLOB layers=", BlobLayer._layers.size())

		for cm in get_tree().get_nodes_in_group("unit_shadow").slice(0, 6):
			var en: VisibleOnScreenEnabler3D = null
			for c in cm.get_children():
				if c is VisibleOnScreenEnabler3D:
					en = c
			print("DBGANIM ", cm.model_name, " anim_pm=", cm.anim.process_mode if cm.anim else -1, " can_process=", cm.anim.can_process() if cm.anim else false, " playing=", cm.anim.is_playing() if cm.anim else false, " cur=", cm.current, " onscreen=", en.is_on_screen() if en else "none", " active=", cm.anim.active if cm.anim else false)
	if args.has("perf") and LevelMain.I:
		_perf_tick()
	if args.has("lodprobe") and t >= float(args["lodprobe"]) and not has_meta("lodprobe") and LevelMain.I:
		set_meta("lodprobe", true)
		_lod_probe()
	if args.has("radial_at") and t >= float(args["radial_at"]) and not has_meta("radial") and LevelMain.I:
		set_meta("radial", true)
		var L := LevelMain.I
		for i in L.plots.size():
			if not L.towers.has(i):
				L._select_plot(i)
				L.cam_rig.focus(Vector3(L.plots[i].x, 0, L.plots[i].y))
				L._on_radial_preview("build_mage")
				L.hud.radial._on_press("build_mage")
				break
	if args.has("taps") and LevelMain.I and LevelMain.I.cine:
		# simulated taps on a running cut-scene (story advance / skip)
		var due: Array = get_meta("taps_left", Array((args["taps"] as String).split(",")).map(func(x): return float(x)))
		if not due.is_empty() and t >= float(due[0]):
			due.pop_front()
			var cn = LevelMain.I.cine
			if cn._skip.is_valid():
				cn._skip.call()
		set_meta("taps_left", due)
	if args.get("print_events", "0") == "1" and t > 1.0 and not has_meta("pe") and LevelMain.I:
		set_meta("pe", true)
		print("EVENTS %s %d/%d" % [LevelMain.I.def["id"], LevelMain.I.events.size(), (LevelMain.EVENTS.get(LevelMain.I.def["id"], []) as Array).size()])
		get_tree().quit()
	if args.has("evt_at") and t >= float(args["evt_at"]) and not has_meta("evt_done") and LevelMain.I and not LevelMain.I.events.is_empty():
		# review a map event: frame it, put a few enemies on the road beside it
		set_meta("evt_done", true)
		var L4 := LevelMain.I
		var ev: Dictionary = L4.events[int(args.get("evt", "0")) % L4.events.size()]
		var ep: Vector3 = ev["pos"]
		var rd: Vector3 = ev["road"]
		L4.cam_rig.focus((ep + rd) * 0.5, float(args.get("zoom", "15")))
		for lp4 in L4.paths:
			var al: float = lp4.closest(Vector2(rd.x, rd.z)).y
			if lp4.sample(al).distance_to(Vector2(rd.x, rd.z)) < 1.5:
				for k in int(args.get("n", "5")):
					L4.spawn_enemy_at(args.get("enemy", "orc"), lp4, clampf(al - 2.0 + k * 0.9, 1.0, lp4.length - 1.0))
				break
	if args.has("evt_fire") and t >= float(args["evt_fire"]) and not has_meta("evt_fired") and LevelMain.I and not LevelMain.I.events.is_empty():
		set_meta("evt_fired", true)
		LevelMain.I._trigger_event(LevelMain.I.events[int(args.get("evt", "0")) % LevelMain.I.events.size()])
	if args.has("skip_at") and t >= float(args["skip_at"]) and not has_meta("skip_done") and LevelMain.I:
		set_meta("skip_done", true)
		var sk = LevelMain.I.cine.root.get_node_or_null("StorySkip")
		if sk:
			sk.emit_signal("pressed")
	if args.has("ui_at") and t >= float(args["ui_at"]) and not has_meta("ui_done") and LevelMain.I:
		# put the level UI into a given state for review screenshots
		set_meta("ui_done", true)
		var L2 := LevelMain.I
		match args.get("ui", ""):
			"tower":
				var ks: Array = L2.towers.keys()
				if not ks.is_empty():
					var tw: Tower = L2.towers[ks[0]]
					L2.cam_rig.focus(tw.global_position, float(args.get("zoom", "18")))
					L2._select_tower(ks[0])
			"plot":
				for i in L2.plots.size():
					if not L2.towers.has(i):
						L2.cam_rig.focus(Vector3(L2.plots[i].x, 0, L2.plots[i].y), float(args.get("zoom", "18")))
						L2._select_plot(i)
						break
			"hero":
				L2._select_hero()
			"pause":
				L2._pause()
			"pause_lang":
				# pause, then press a language button in the pause menu (lang_to=en|ko|auto)
				L2._pause()
				L2.get_tree().create_timer(0.6).timeout.connect(func():
					var want := {"en": "English", "ko": "한국어", "auto": "자동"}.get(args.get("lang_to", "en"), "English") as String
					for b in L2._modal.find_children("*", "Button", true, false):
						if (b as Button).text == want:
							(b as Button).pressed.emit()
							break)
			"victory":
				L2._victory()
			"defeat":
				L2._defeat()
			"enemy":
				L2._show_enemy_card(args.get("enemy", "orc"))
			"boss":
				L2._spawn_enemy(args.get("enemy", "troll"), 0)
			"skillshow":
				# enemies on the road beside the hero, then the hero's skill on them
				var lp2: LanePath = L2.paths[0]
				var hp2 := L2.hero.global_position
				var off: float = lp2.closest(Vector2(hp2.x, hp2.z)).y
				for k in int(args.get("n", "8")):
					L2.spawn_enemy_at(args.get("enemy", "goblin"), lp2, clampf(off - 1.5 + k * 0.5, 1.0, lp2.length - 1.0))
				var cp := lp2.sample(off)
				L2.cam_rig.focus(Vector3(cp.x, 0, cp.y), float(args.get("zoom", "14")))
				L2.cam_rig._pos = L2.cam_rig.target
				L2.get_tree().create_timer(0.3).timeout.connect(func(): L2.hero.cast_skill())
			"meteor":
				var lpm: LanePath = L2.paths[0]
				var mp := lpm.sample(float(args.get("at", "12")))
				for k in 3:
					Projectile.meteor(Vector3(mp.x + k * 1.2 - 1.2, 0, mp.y), 1.0, 2.0, k * 0.22)
				L2.cam_rig.focus(Vector3(mp.x, 0, mp.y), float(args.get("zoom", "14")))
				L2.cam_rig._pos = L2.cam_rig.target
				if args.has("slowmo"):
					Engine.time_scale = float(args["slowmo"])
			"props":
				# a row of models on the road for look-dev: name or name!glow, comma-separated
				var lpp: LanePath = L2.paths[0]
				var pp := lpp.sample(float(args.get("at", "12")))
				var names: Array = (args.get("props", "meteor") as String).split(",")
				for k in names.size():
					var nm: String = names[k]
					var nd: Node3D = Assets.instance_glow(nm.trim_suffix("!glow"), float(args.get("energy", "1.0"))) if nm.ends_with("!glow") else Assets.instance(nm)
					nd.scale = Vector3.ONE * float(args.get("pscale", "1.0"))
					L2.add_child(nd)
					nd.global_position = Vector3(pp.x + (k - (names.size() - 1) * 0.5) * float(args.get("gap", "1.8")), float(args.get("py", "0.6")), pp.y)
				L2.cam_rig.focus(Vector3(pp.x, 0, pp.y), float(args.get("zoom", "8")))
				L2.cam_rig._pos = L2.cam_rig.target
			"spawn":
				var lp: LanePath = L2.paths[0]
				for k in int(args.get("n", "6")):
					L2.spawn_enemy_at(args.get("enemy", "wolf"), lp, float(args.get("at", "6")) + k * 1.3)
			"inspect":
				if not L2.enemies.is_empty():
					var e: Enemy = L2.enemies[L2.enemies.size() / 2]
					L2.cam_rig.focus(e.global_position, float(args.get("zoom", "16")))
					L2._select_enemy(e)
			"endless":
				L2._endless_over()
	if LevelMain.I and not has_meta("env_over") and (args.has("tm") or args.has("white") or args.has("exp") or args.has("sun") or args.has("amb")):
		set_meta("env_over", true)
		for we in LevelMain.I.find_children("*", "WorldEnvironment", true, false):
			var env: Environment = (we as WorldEnvironment).environment
			if args.has("tm"):
				env.tonemap_mode = {"filmic": Environment.TONE_MAPPER_FILMIC, "agx": Environment.TONE_MAPPER_AGX, "aces": Environment.TONE_MAPPER_ACES, "linear": Environment.TONE_MAPPER_LINEAR}[args["tm"]]
			if args.has("white"):
				env.tonemap_white = float(args["white"])
			if args.has("exp"):
				env.tonemap_exposure = float(args["exp"])
			if args.has("amb"):
				env.ambient_light_energy = float(args["amb"])
		if args.has("sun"):
			for l in LevelMain.I.find_children("*", "DirectionalLight3D", true, false):
				(l as DirectionalLight3D).light_energy = float(args["sun"])
	if not _shots_at.is_empty() and t >= _shots_at[0]:
		_shots_at.pop_front()
		if args.get("overview", "0") == "1" and LevelMain.I:
			var b: Rect2 = LevelMain.I.cam_rig.bounds
			LevelMain.I.cam_rig.zoom = float(args.get("zoom", "40"))
			LevelMain.I.cam_rig.target = Vector3(b.get_center().x, 0, b.get_center().y)
			LevelMain.I.cam_rig._pos = LevelMain.I.cam_rig.target
			LevelMain.I.hud.root.visible = args.get("hud", "1") == "1"
			LevelMain.I.hud.overlay.visible = args.get("hud", "1") == "1"
			await get_tree().process_frame
		if args.has("focus") and LevelMain.I:
			var L2 := LevelMain.I
			var fp := Vector3.ZERO
			var f: String = args["focus"]
			if f.begins_with("xy:"):
				var parts := f.split(":")
				fp = Vector3(float(parts[1]), 0, float(parts[2]))
			elif f.begins_with("tower_type:"):
				for k in L2.towers:
					if (L2.towers[k] as Tower).type == f.split(":")[1]:
						fp = (L2.towers[k] as Tower).global_position
						break
			elif f == "hero" and L2.hero:
				fp = L2.hero.global_position
			elif f == "portal":
				var s0: Vector2 = (L2.paths[0] as LanePath).sample(2.0)
				fp = Vector3(s0.x, 0, s0.y)
			elif f == "castle":
				var lp0: LanePath = L2.paths[0]
				var e0: Vector2 = lp0.sample(lp0.length - 2.0)
				fp = Vector3(e0.x, 0, e0.y)
			else:
				var keys := L2.towers.keys()
				keys.sort()
				var ti := int(f) % maxi(keys.size(), 1)
				if not keys.is_empty():
					fp = (L2.towers[keys[ti]] as Tower).global_position
			fp.y += float(args.get("fy", "0"))
			L2.cam_rig.zoom = float(args.get("zoom", "14"))
			L2.cam_rig.target = fp
			L2.cam_rig._pos = fp
			L2.hud.root.visible = args.get("hud", "1") == "1"
			L2.hud.overlay.visible = args.get("hud", "1") == "1"
			await get_tree().process_frame
		if args.get("follow", "0") == "1" and LevelMain.I and not LevelMain.I.enemies.is_empty():
			var e: Enemy = LevelMain.I.enemies[LevelMain.I.enemies.size() / 2]
			for c: Enemy in LevelMain.I.enemies:
				if c.type == args.get("follow_type", "") and c.alive:
					e = c
					break
			LevelMain.I.cam_rig.focus(e.global_position, float(args.get("zoom", "22")))
			LevelMain.I.cam_rig._pos = LevelMain.I.cam_rig.target
			await get_tree().process_frame
		_shot()
	if has_meta("texab_done") and not has_meta("texab_fin"):
		return  # the texture A/B probe is still shooting
	if mode == "menu":
		if t > float(args.get("max_t", "7.0")):
			get_tree().quit()
		return
	if level == null or not is_instance_valid(level) or LevelMain.I == null:
		return
	if mode == "ai":
		_ai_tick(delta)
		return
	if mode == "smart":
		_smart_tick(delta)
		return
	if not built and t > 1.5:
		built = true
		_build_all()
	if mode == "auto" or mode == "shots":
		if args.has("warp") and LevelMain.I.state == "playing":
			_gt += delta
			Engine.time_scale = 6.0 if _gt < float(args["warp"]) else float(args.get("speed", "1"))
		if args.get("track", "0") == "1" and not LevelMain.I.enemies.is_empty():
			# continuously frame the busiest fight (for movie capture)
			var L3 := LevelMain.I
			var c := Vector3.ZERO
			var n := 0
			for e: Enemy in L3.enemies:
				if e.alive and n < 6:
					c += e.global_position
					n += 1
			if n > 0:
				c /= n
				L3.cam_rig.zoom = float(args.get("zoom", "16"))
				L3.cam_rig.target = L3.cam_rig.target.lerp(c, 0.04)
		if args.get("god", "0") == "1":
			LevelMain.I.lives = maxi(LevelMain.I.lives, 15)
		if args.has("abreport") and t > _next_ab:
			_next_ab = t + 10.0
			print("ABILITIES ", Tower.ability_hits)
		if LevelMain.I.state == "ready" and t > 2.0 and args.get("nowave", "0") != "1":
			Engine.time_scale = float(args.get("speed", "3"))
			LevelMain.I._call_wave()
		elif LevelMain.I.state == "playing" and LevelMain.I._spawning_done() and randf() < 0.01:
			LevelMain.I._call_wave()
		if t > _next_report:
			_next_report = t + 5.0
			var L := LevelMain.I
			print("[t=%.0f] wave %d/%d enemies=%d soldiers=%d lives=%d gold=%d state=%s fps=%d" % [t, L.wave_idx + 1, L.waves.size(), L.enemies.size(), L.soldiers.size(), L.lives, L.gold, L.state, Engine.get_frames_per_second()])
			if randf() < 0.5 and L.spell_cd["meteor"] <= 0.0 and not L.enemies.is_empty():
				L.targeting = "meteor"
				L._handle_targeting(L.enemies[0].global_position)
			if L.spell_cd["reinforce"] <= 0.0 and not L.enemies.is_empty():
				L.targeting = "reinforce"
				L._handle_targeting(L.enemies[0].global_position)
		if LevelMain.I.state == "won" or LevelMain.I.state == "lost":
			if not has_meta("end"):
				set_meta("end", t)
				print("RESULT ", LevelMain.I.state, " lives=", LevelMain.I.lives, " stars=", Game.stars)
			elif t - float(get_meta("end")) > float(args.get("end_wait", "3")):
				if args.has("final_shot"):
					_shot()
				get_tree().quit()
	if t > float(args.get("max_t", "600")):
		print("TIMEOUT")
		get_tree().quit()

var _ai_cd := 0.0
var _ai_build_i := 0

func _ai_tick(delta: float) -> void:
	var L := LevelMain.I
	if t < 1.0:
		return
	Engine.time_scale = float(args.get("speed", "4"))
	_ai_cd -= delta
	if _ai_cd <= 0.0:
		_ai_cd = 0.5
		var types := ["archer", "barracks", "mage", "artillery", "archer", "mage"]
		var max_towers := int(args.get("max_towers", "10"))
		# prefer: build until 4 towers, then alternate upgrades and new towers
		var built_n := L.towers.size()
		var did := false
		if built_n < 4 or (built_n < max_towers and randf() < 0.5):
			var tp: String = types[_ai_build_i % types.size()]
			var c: int = DB.TOWERS[tp]["levels"][0]["cost"]
			if L.gold >= c:
				for i in L.plots.size():
					if not L.towers.has(i):
						L._select_plot(i)
						L._on_radial_chosen("build_" + tp)
						_ai_build_i += 1
						did = true
						break
		if not did:
			for i in L.towers.keys():
				var tw: Tower = L.towers[i]
				if tw.level < 3 and L.gold >= tw.next_cost():
					L._select_tower(i)
					L._on_radial_chosen("upgrade")
					break
				elif tw.level == 3 and tw.mastery == "" and args.get("mastery", "1") == "1":
					var md: Dictionary = tw.data()["masteries"][i % 2]
					if L.gold >= int(md["cost"]):
						L._select_tower(i)
						L._on_radial_chosen("mastery_" + md["id"])
						break
		# spells on the most advanced enemy cluster
		if not L.enemies.is_empty():
			var lead: Enemy = L.enemies[0]
			for e: Enemy in L.enemies:
				if e.dist > lead.dist:
					lead = e
			if L.spell_cd["meteor"] <= 0.0 and L.enemies.size() >= 4:
				L.targeting = "meteor"
				L._handle_targeting(lead.global_position)
			if L.spell_cd["reinforce"] <= 0.0:
				L.targeting = "reinforce"
				L._handle_targeting(lead.global_position)
			if L.hero and L.hero.alive and not L.hero.commanded and L.hero.target == null and randf() < 0.1:
				L.hero.move_to(lead.global_position)
	if L.state == "ready":
		L._call_wave()
	if t > _next_report:
		_next_report = t + 10.0
		print("[t=%.0f] wave %d/%d enemies=%d towers=%d lives=%d gold=%d" % [t, L.wave_idx + 1, L.waves.size(), L.enemies.size(), L.towers.size(), L.lives, L.gold])
	if L.state == "won" or L.state == "lost":
		var lv := []
		for k in L.towers.keys():
			lv.append("%s%d%s" % [L.towers[k].type.substr(0, 2), L.towers[k].level, L.towers[k].mastery.substr(0, 2)])
		print("RESULT ", L.state, " wave=", L.wave_idx + 1, " lives=", L.lives, " towers=", lv)
		get_tree().quit()

# ------------------------------------------------------------------ smart AI (balance testing)

var BEST_MASTERY := {"archer": "marksman", "barracks": "paladin", "mage": "arcane", "artillery": "bombard"}

func _upcoming(L: LevelMain, n: int) -> Dictionary:
	var c := {}
	for wi in range(L.wave_idx + 1, mini(L.wave_idx + 1 + n, L.waves.size())):
		for g in L.waves[wi]:
			c[g[0]] = int(c.get(g[0], 0)) + int(g[1])
	return c

func _desired_type(L: LevelMain) -> String:
	var w := _upcoming(L, 3)
	var have := {"archer": 0, "barracks": 0, "mage": 0, "artillery": 0}
	for k in L.towers:
		have[L.towers[k].type] += 1
	var armored := 0.0
	var flying := 0.0
	var swarm := 0.0
	var fast := 0.0
	for t in w:
		var d: Dictionary = DB.ENEMIES[t]
		var hpw := float(w[t]) * float(d["hp"]) / 60.0
		if float(d["armor"]) >= 0.3:
			armored += hpw
		if d.get("flying", false):
			flying += hpw
		if float(d["hp"]) <= 70.0:
			swarm += float(w[t])
		if float(d["speed"]) >= 3.0:
			fast += float(w[t])
	var sc := {
		"archer": 1.2 + flying * 1.5,
		"barracks": 0.9 + fast * 0.08 + swarm * 0.02,
		"mage": 0.8 + armored * 0.6,
		"artillery": 0.7 + swarm * 0.06,
	}
	if have["barracks"] >= 3:
		sc["barracks"] = 0.0
	var best := "archer"
	var bv := -1.0
	for t in sc:
		var v: float = sc[t] / (1.0 + have[t] * 0.9)
		if v > bv:
			bv = v
			best = t
	if L.towers.is_empty():
		best = "archer" if w.has("gargoyle") else "barracks"
	return best

var _last_lives := 999

func _ai_build(L: LevelMain, want: String) -> void:
	var free := []
	for i in L.plots.size():
		if not L.towers.has(i):
			free.append(i)
	if free.is_empty():
		return
	# a beginner taps whichever empty plot catches the eye; the expert fills plots in order
	var pick: int = free[randi() % free.size()] if _casual() else free[0]
	L._select_plot(pick)
	L._on_radial_chosen("build_" + want)

var _mastery_pick := {}

func _mastery_for(tw: Tower) -> String:
	if not _casual():
		return BEST_MASTERY[tw.type]
	if not _mastery_pick.has(tw):
		var ms: Array = tw.data()["masteries"]
		_mastery_pick[tw] = String((ms[randi() % ms.size()] as Dictionary)["id"])
	return _mastery_pick[tw]

var _menu: Node
var _gt := 0.0

## skill=casual imitates a first-time player: slow reactions, half-random tower picks,
## random specialisations, no ability purchases, sparse spells, no hero micro, no early calls.
func _casual() -> bool:
	return args.get("skill", "expert") == "casual"

func _smart_tick(delta: float) -> void:
	var L := LevelMain.I
	if t < 1.0:
		return
	Engine.time_scale = float(args.get("speed", "6"))
	_ai_cd -= delta
	if _ai_cd <= 0.0:
		_ai_cd = 2.5 if _casual() else 0.35
		var limit := mini(L.plots.size(), int(args.get("base_towers", "5")) + int((L.wave_idx + 1) * float(args.get("tower_rate", "0.7"))))
		var want := _desired_type(L)
		if _casual() and randf() < 0.5:
			want = ["archer", "barracks", "mage", "artillery"][randi() % 4]
		var cost: int = DB.TOWERS[want]["levels"][0]["cost"]
		# cheapest pending upgrade (towers below Lv3 first, then masteries)
		var up_i := -1
		var up_c := 1 << 30
		var all_l3 := true
		for i in L.towers.keys():
			var tw: Tower = L.towers[i]
			if tw.level < 3:
				all_l3 = false
				if tw.next_cost() < up_c:
					up_c = tw.next_cost()
					up_i = i
		var buy_ability := false
		if all_l3:
			for i in L.towers.keys():
				var tw: Tower = L.towers[i]
				if tw.level == 3 and tw.mastery == "":
					var mc := int(DB.mastery_def(tw.type, _mastery_for(tw))["cost"])
					if mc < up_c:
						up_c = mc
						up_i = i
			if up_i < 0 and not _casual():
				for i in L.towers.keys():
					var tw: Tower = L.towers[i]
					if tw.mastery != "" and tw.ability == "":
						var ac := DB.ability_cost(tw.type, tw.mastery)
						if ac < up_c:
							up_c = ac
							up_i = i
							buy_ability = true
		var leaking := L.lives < _last_lives
		_last_lives = L.lives
		var can_build := L.towers.size() < limit and L.gold >= cost
		if L.towers.size() < 4 or leaking:
			if can_build:
				_ai_build(L, want)
		elif up_i >= 0 and L.gold >= up_c:
			var tw2: Tower = L.towers[up_i]
			L._select_tower(up_i)
			if buy_ability:
				L._on_radial_chosen("ability")
			else:
				L._on_radial_chosen("upgrade" if tw2.level < 3 else "mastery_" + _mastery_for(tw2))
		elif can_build and (up_i < 0 or L.gold >= cost + up_c or (L.towers.size() < 4 + L.paths.size() * 2 and up_c > cost)):
			_ai_build(L, want)
		L._deselect()
		# spells: meteor on the densest cluster, reinforcements on the leak
		if not L.enemies.is_empty():
			var lead: Enemy = null
			var dense: Enemy = null
			var dn := 0
			for e: Enemy in L.enemies:
				if not e.alive:
					continue
				if lead == null or e.dist / e.path.length > lead.dist / lead.path.length:
					lead = e
				var n := 0
				for o: Enemy in L.enemies:
					if o.alive and o.global_position.distance_to(e.global_position) < 2.6:
						n += 1
				if e.boss:
					n += 6
				if n > dn:
					dn = n
					dense = e
			var spells_ok := not _casual() or randf() < 0.3
			if dense and L.spell_cd["meteor"] <= 0.0 and dn >= (8 if _casual() else 5) and spells_ok:
				L.targeting = "meteor"
				L._handle_targeting(dense.global_position + dense.vel * 0.6)
			if lead and L.spell_cd["reinforce"] <= 0.0 and lead.dist / lead.path.length > (0.7 if _casual() else 0.45) and spells_ok:
				L.targeting = "reinforce"
				L._handle_targeting(lead.global_position + lead.vel * 1.5)
			if not _casual() and L.hero and L.hero.alive and lead and L.hero.target == null and randf() < 0.15:
				L.hero.move_to(lead.global_position + lead.vel * 1.2)
	if L.state == "ready":
		L._call_wave()
	elif L.state == "playing" and L._spawning_done() and L.enemies.is_empty() and args.get("early", "1") == "1" and not _casual():
		L._call_wave()
	if t > _next_report:
		_next_report = t + 10.0
		print("[t=%.0f] wave %d/%d enemies=%d towers=%d lives=%d gold=%d" % [t, L.wave_idx + 1, L.waves.size(), L.enemies.size(), L.towers.size(), L.lives, L.gold])
	if L.state == "won" or L.state == "lost":
		var lv := []
		for k in L.towers.keys():
			lv.append("%s%d%s" % [L.towers[k].type.substr(0, 2), L.towers[k].level, L.towers[k].mastery.substr(0, 2)])
		print("RESULT ", L.state, " wave=", L.wave_idx + 1, "/", L.waves.size(), " lives=", L.lives, "/", L.max_lives, " towers=", lv)
		get_tree().quit()

func _build_all() -> void:
	var L := LevelMain.I
	L.gold = int(args.get("gold", "4000"))
	var types := ["archer", "barracks", "mage", "artillery"]
	var n := int(args.get("towers", "99"))
	for i in mini(L.plots.size(), n):
		L._select_plot(i)
		var tp: String = types[i % 4]
		L._on_radial_chosen("build_" + tp)
	var up := int(args.get("upgrade", "2"))
	for i in L.towers.keys():
		var tw: Tower = L.towers[i]
		for k in up:
			if tw.level < 3:
				tw.upgrade()
		if args.get("mastery", "0") == "1" and tw.level == 3:
			var ms: Array = tw.data()["masteries"]
			tw.apply_mastery(ms[(i + int(args.get("mflip", "0"))) % 2]["id"])
			if args.get("abilities", "0") == "1":
				tw.buy_ability()
	L.hud.set_gold(L.gold)

## Save-code round trip, corrupted codes, talent math (headless).
func _selftest() -> void:
	var ok := true
	var keep_stars := Game.stars.duplicate()
	Game.stars = [3, 2, 1, 0, 0, 0, 0, 0]
	Game.hero_xp = {"kael": 1300.0}
	Game.hero_talents = {"kael": {"hp": 2}}
	Game.upgrades = {"gold": true}
	var code := Game.export_code()
	Game.reset_progress()
	var err := Game.import_code(code)
	ok = ok and err == "" and Game.stars[0] == 3 and Game.stars[2] == 1 and Game.upgrades.get("gold", false)
	ok = ok and is_equal_approx(float(Game.hero_xp.get("kael", 0)), 1300.0) and DB.talent("kael", "hp") == 2
	print("SELFTEST roundtrip ", err == "", " rank=", DB.hero_rank("kael"), " points=", DB.talent_points("kael"), " hp_mult=", DB.talent_mult("kael", "hp"))
	var bad1 := Game.import_code("hello")
	var bad2 := Game.import_code(code.substr(0, code.length() - 8) + "AAAAAAAA")
	ok = ok and bad1 != "" and bad2 != ""
	print("SELFTEST bad codes: [", bad1, "] [", bad2, "]")
	# old 5-region saves load into the 8-region list
	var cf := ConfigFile.new()
	cf.set_value("progress", "stars", [3, 3, 3, 3, 3])
	Game.reset_progress()
	Game._apply_config(cf)
	ok = ok and Game.stars.size() == DB.LEVELS.size() and Game.stars[4] == 3 and Game.stars[5] == 0
	print("SELFTEST old save stars=", Game.stars, " unlocked6=", Game.unlocked(5), " unlocked7=", Game.unlocked(6))
	# playtest log code: gzip + base64 round trip
	Game.playlog = [{"lv": 3, "r": "lost", "wv": 7, "lw": {"7": 12}, "tw": ["ar3", "ma2"]}]
	var pcode := Game.playlog_code()
	var pp := pcode.split("-", true, 2)
	var raw := Marshalls.base64_to_raw(pp[2]).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	var pl_ok: bool = pp[0] == "RBP1" and pp[2].md5_text().substr(0, 6) == pp[1] and parsed is Dictionary and int(parsed["runs"][0]["wv"]) == 7
	ok = ok and pl_ok
	print("SELFTEST playlog code len=", pcode.length(), " ok=", pl_ok)
	print("PLAYLOG_CODE ", pcode)
	print("SELFTEST ", "PASS" if ok else "FAIL")
	Game.reset_progress()
	Game.stars = keep_stars
	Game.save()
	get_tree().quit()

## Prints drawn primitives at several mesh LOD thresholds and the cost of each group of 3D nodes.
func _lod_probe() -> void:
	var vp := get_viewport()
	get_tree().paused = true
	print("FEATURES etc2=%s astc=%s s3tc=%s bptc=%s" % [OS.has_feature("etc2"), OS.has_feature("astc"), OS.has_feature("s3tc"), OS.has_feature("bptc")])
	for th in [0.0, 1.0, 4.0, 32.0]:
		vp.mesh_lod_threshold = th
		for k in 4:
			await RenderingServer.frame_post_draw
		print("LOD threshold=%.1f primitives=%d draws=%d" % [th, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	vp.mesh_lod_threshold = 1.0
	for k in 4:
		await RenderingServer.frame_post_draw
	var base := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("BASE primitives=%d draws=%d" % [base, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var us := get_tree().get_nodes_in_group("unit_shadow")
	var nb := 0
	for u in us:
		if u._blob:
			nb += 1
	print("UNITS %d with blob %d hq=%s" % [us.size(), nb, Game.high_quality])
	if not us.is_empty():
		var u0: CharacterModel = us[0]
		print("blob0 ", u0._blob, " model ", u0.global_position, " body_shadow ", u0.body.cast_shadow if u0.body else -1)
	if args.get("groups", "0") != "1":
		get_tree().quit()
		return
	var groups := {}
	for n in LevelMain.I.find_children("*", "GeometryInstance3D", true, false):
		if not (n as GeometryInstance3D).visible:
			continue
		var top: Node = n
		while top.get_parent() != LevelMain.I and top.get_parent() != null:
			top = top.get_parent()
		var key := String(top.name).rstrip("0123456789_") + "/" + n.get_class()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mp := (n as MeshInstance3D).mesh.resource_path
			var own: Node = n.owner
			key += "(" + (mp.get_file().get_basename() if mp != "" and not mp.contains("::") else (own.scene_file_path.get_file().get_basename() if own and own.scene_file_path != "" else mp.get_file())) + ")"
		if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh and (n as MultiMeshInstance3D).multimesh.mesh:
			key += "(" + (n as MultiMeshInstance3D).multimesh.mesh.resource_path.get_file().get_basename() + ")"
		if not groups.has(key):
			groups[key] = []
		groups[key].append(n)
	var costs := {}
	var dcosts := {}
	var base_draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	for key in groups:
		for n in groups[key]:
			if is_instance_valid(n):
				(n as GeometryInstance3D).visible = false
		for k in 2:
			await RenderingServer.frame_post_draw
		costs[key] = base - Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		dcosts[key] = base_draws - Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for n in groups[key]:
			if is_instance_valid(n):
				(n as GeometryInstance3D).visible = true
	var ks := costs.keys()
	ks.sort_custom(func(a, b): return costs[a] > costs[b])
	for k in ks.slice(0, 30):
		print("COST %8d n=%d %s" % [costs[k], groups[k].size(), k])
	ks.sort_custom(func(a, b): return dcosts[a] > dcosts[b])
	for k in ks.slice(0, 30):
		print("DRAWS %4d n=%d %s" % [dcosts[k], groups[k].size(), k])
	# shadow-pass share of each group: switch only its shadow casting off
	var scosts := {}
	for key in groups:
		var was := {}
		for n in groups[key]:
			if is_instance_valid(n):
				was[n] = (n as GeometryInstance3D).cast_shadow
				(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 2:
			await RenderingServer.frame_post_draw
		scosts[key] = base - Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		for n in was:
			(n as GeometryInstance3D).cast_shadow = was[n]
	ks.sort_custom(func(a, b): return scosts[a] > scosts[b])
	for k in ks.slice(0, 16):
		var info := ""
		var g0 = groups[k][0]
		if g0 is MultiMeshInstance3D and g0.multimesh and g0.multimesh.mesh:
			var mm: MultiMesh = g0.multimesh
			var tri := 0
			for si in mm.mesh.get_surface_count():
				var ia = mm.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
				tri += (ia.size() if ia else mm.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX].size()) / 3
			info = " tris=%d inst=%d surf=%d" % [tri, mm.instance_count, mm.mesh.get_surface_count()]
		print("SHADOWCOST %8d of %8d n=%d %s%s" % [scosts[k], costs[k], groups[k].size(), k, info])
	for l in LevelMain.I.find_children("*", "DirectionalLight3D", true, false):
		(l as Light3D).shadow_enabled = false
	for k in 3:
		await RenderingServer.frame_post_draw
	print("NO-SHADOW primitives=%d (base %d)" % [Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), base])

func _render_backdrop() -> void:
	_menu.ui.visible = false
	_menu._t = 0.0
	for i in 4:
		await get_tree().process_frame
	_menu._t = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(args["backdrop"])
	print("BACKDROP ", args["backdrop"], " ", img.get_size())
	get_tree().quit()


func _shot() -> void:
	var dir: String = args.get("shots", "/tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := "%s/%s_%02d.png" % [dir, args.get("tag", "shot"), shot_i]
	shot_i += 1
	img.save_png(p)
	print("SHOT ", p)
	if args.has("texab") and not has_meta("texab_done"):
		set_meta("texab_done", true)
		await _texab(p)


## texab=normal:0.5,orm:0.5,c_albedo:0.5,castle_albedo:0.5 — texture-size A/B probe.  After the
## normal shot (A) the tree is paused, a second shot (A2) measures what still moves (shader time),
## then every matching model / character texture is resized in place (cubic, as the importer's
## size_limit does) and shot again (B).  Keys: role (albedo|normal|orm), m_<role> / c_<role> for
## models / characters only, or a texture name such as castle_normal.
func _texab(p: String) -> void:
	# freeze everything, shader time included (it advances by the scaled frame step)
	get_tree().paused = true
	Engine.time_scale = 0.0
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(p.replace(".png", "_a2.png"))
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(p.replace(".png", "_a3.png"))
	var stage := 0
	for spec in (args["texab"] as String).split("|"):
		stage += 1
		var rules := {}
		for r in spec.split(","):
			var kv := r.split(":")
			rules[kv[0]] = float(kv[1])
		var swapped := {}
		var stack: Array[Node] = [get_tree().root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var mats: Array = []
			if n is GeometryInstance3D and (n as GeometryInstance3D).material_override:
				mats.append((n as GeometryInstance3D).material_override)
			var mesh: Mesh = null
			if n is MeshInstance3D:
				mesh = (n as MeshInstance3D).mesh
				for s in (n as MeshInstance3D).get_surface_override_material_count():
					if (n as MeshInstance3D).get_surface_override_material(s):
						mats.append((n as MeshInstance3D).get_surface_override_material(s))
			elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
				mesh = (n as MultiMeshInstance3D).multimesh.mesh
			if mesh:
				for s in mesh.get_surface_count():
					if mesh.surface_get_material(s):
						mats.append(mesh.surface_get_material(s))
			for m in mats:
				if m is BaseMaterial3D:
					for tp in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ORM,
							BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, BaseMaterial3D.TEXTURE_EMISSION]:
						var nt := _texab_swap((m as BaseMaterial3D).get_texture(tp), rules, swapped)
						if nt:
							(m as BaseMaterial3D).set_texture(tp, nt)
				elif m is ShaderMaterial and (m as ShaderMaterial).shader:
					for u in (m as ShaderMaterial).shader.get_shader_uniform_list():
						var v = (m as ShaderMaterial).get_shader_parameter(u["name"])
						if v is Texture2D:
							var nt2 := _texab_swap(v, rules, swapped)
							if nt2:
								(m as ShaderMaterial).set_shader_parameter(u["name"], nt2)
		print("TEXAB stage ", stage, " swapped ", swapped.size(), " ", swapped.keys())
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pb := p.replace(".png", "_b%d.png" % stage)
		get_viewport().get_texture().get_image().save_png(pb)
		print("SHOT ", pb)
	set_meta("texab_fin", true)


func _texab_swap(tx: Texture2D, rules: Dictionary, swapped: Dictionary) -> Texture2D:
	if tx == null or tx is ImageTexture or tx.resource_path == "":
		return null
	var path := tx.resource_path
	if swapped.has(path):
		return swapped[path]
	var nm := path.get_file().get_basename()
	var role := nm.get_slice("_", nm.get_slice_count("_") - 1)
	var grp := "c_" if path.contains("/characters/") else ("m_" if path.contains("/models/") else "x_")
	var f := -1.0
	for k in [nm, grp + role, role]:
		if rules.has(k):
			f = rules[k]
			break
	if f <= 0.0 or f >= 1.0:
		return null
	var img := tx.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.resize(maxi(1, int(img.get_width() * f)), maxi(1, int(img.get_height() * f)), Image.INTERPOLATE_CUBIC)
	img.generate_mipmaps(role == "normal")
	var nt := ImageTexture.create_from_image(img)
	swapped[path] = nt
	return nt


## perf=START,DUR: from START (test seconds) sample DUR seconds of frames and print one summary line:
## real frame time (mean / p95), script+animation process time, physics, render CPU time,
## draw calls, primitives, visible objects, node count and live enemies.
var _pf := {}

func _perf_tick() -> void:
	var a := (args["perf"] as String).split(",")
	var t0 := float(a[0])
	var dur := float(a[1]) if a.size() > 1 else 10.0
	if t < t0:
		return
	var now := Time.get_ticks_usec()
	if _pf.is_empty():
		_pf = {"last": now, "start": now, "ft": [], "pt": [], "ph": [], "rc": [], "dc": [], "pr": [], "ob": [], "en": []}
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		Prof.on = args.has("prof")
		Prof.acc.clear()
		Prof.cnt.clear()
		return
	if _pf.has("done"):
		return
	_pf["ft"].append((now - int(_pf["last"])) / 1000.0)
	_pf["last"] = now
	_pf["pt"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_pf["ph"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_pf["rc"].append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
	_pf["dc"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_pf["pr"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_pf["ob"].append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_pf["en"].append(LevelMain.I.enemies.size())
	if (now - int(_pf["start"])) / 1e6 >= dur:
		_pf["done"] = true
		var mean := func(k): return (_pf[k] as Array).reduce(func(x, y): return x + y, 0.0) / maxf((_pf[k] as Array).size(), 1)
		var ft: Array = (_pf["ft"] as Array).duplicate()
		ft.sort()
		var p95: float = ft[int(ft.size() * 0.95)] if not ft.is_empty() else 0.0
		print("PERF level=%s hq=%s frames=%d frame=%.2fms p95=%.2fms process=%.2fms physics=%.2fms render_cpu=%.2fms draws=%.0f prims=%.0f objs=%.0f nodes=%d enemies=%.1f towers=%d" % [
			LevelMain.I.def["id"], Game.high_quality, ft.size(), mean.call("ft"), p95, mean.call("pt"), mean.call("ph"), mean.call("rc"),
			mean.call("dc"), mean.call("pr"), mean.call("ob"), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), mean.call("en"), LevelMain.I.towers.size()])
		if Prof.on:
			var nf: int = ft.size()
			var keys: Array = Prof.acc.keys()
			keys.sort_custom(func(x, y): return Prof.acc[x] > Prof.acc[y])
			var pl := "PROF per-frame:"
			for k in keys:
				pl += " %s=%.2fms(%.1fus x%.1f)" % [k, Prof.acc[k] / 1000.0 / nf, float(Prof.acc[k]) / Prof.cnt[k], float(Prof.cnt[k]) / nf]
			print(pl)
		if args.has("perf_list"):
			var by := {}
			for n in LevelMain.I.find_children("*", "CPUParticles3D", true, false):
				var c := n as CPUParticles3D
				var k := "%s/%s amt=%d em=%s fps=%d" % [c.get_parent().name.rstrip("0123456789_@"), c.name.rstrip("0123456789_@"), c.amount, c.emitting, c.fixed_fps]
				by[k] = by.get(k, 0) + 1
			for k in by:
				print("PLIST x%d %s" % [by[k], k])
			var mx := {}
			for n in LevelMain.I.find_children("*", "AnimationMixer", true, false):
				var own: Node = n.get_parent()
				var k2 := own.scene_file_path.get_file() if own.scene_file_path != "" else String(own.name)
				mx[k2] = mx.get(k2, 0) + 1
			print("MLIST ", mx)
		if args.has("proc_list"):
			# who runs every frame: processing nodes by script (or class) under the level and the HUD
			var by2 := {}
			for n in LevelMain.I.find_children("*", "", true, false):
				if n.is_processing() or n.is_physics_processing():
					var sc: Script = n.get_script()
					var k3 := (sc.resource_path.get_file() if sc and sc.resource_path != "" else n.get_class()) + ("/phys" if n.is_physics_processing() else "")
					by2[k3] = by2.get(k3, 0) + 1
			var ks: Array = by2.keys()
			ks.sort_custom(func(x, y): return by2[x] > by2[y])
			print("PROCLIST ", ", ".join(ks.map(func(k): return "%s x%d" % [k, by2[k]])))
		if args.has("perf_split"):
			_perf_split()
		elif args.get("perf_quit", "1") == "1":
			get_tree().quit()

## Process-time share of each system: switch one group of nodes off for a moment and see how much
## script + animation time disappears (entities freeze meanwhile; only the timing matters).
func _perf_split() -> void:
	var L := LevelMain.I
	var phases := {
		"enemies": func(on): for e in L.enemies: if is_instance_valid(e): e.set_process(on),
		"towers": func(on): for k in L.towers: L.towers[k].set_process(on),
		"projectiles": func(on): for n in get_tree().get_nodes_in_group("projectile"): n.set_process(on),
		"soldiers": func(on): for n in get_tree().get_nodes_in_group("soldier"): n.set_process(on),
		"anim": func(on): for n in L.find_children("*", "AnimationMixer", true, false): (n as AnimationMixer).active = on,
		"particles": func(on): for n in L.find_children("*", "CPUParticles3D", true, false): (n as CPUParticles3D).speed_scale = 1.0 if on else 0.0,
		"hud": func(on): L.hud.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"level": func(on): L.set_process(on),
	}
	var res := {}
	for k in ["base"] + phases.keys():
		if k != "base":
			phases[k].call(false)
		var acc := 0.0
		var n := 0
		for f in 90:
			await get_tree().process_frame
			acc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			n += 1
		res[k] = acc / n
		if k != "base":
			phases[k].call(true)
		for f in 10:
			await get_tree().process_frame
	var line := "SPLIT base=%.2fms" % res["base"]
	for k in phases.keys():
		line += " %s=-%.2f" % [k, res["base"] - res[k]]
	print(line, " groups: soldier=", get_tree().get_nodes_in_group("soldier").size(), " projectile=", get_tree().get_nodes_in_group("projectile").size(),
		" mixers=", L.find_children("*", "AnimationMixer", true, false).size(), " cpuparticles=", L.find_children("*", "CPUParticles3D", true, false).size())
	get_tree().quit()
