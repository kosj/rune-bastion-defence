extends Node
## Automated playtest / screenshot harness.  Args (after --):  level=<i> mode=<auto|shots|menu> speed=<f> shots=<dir>

var args := {}
var level: LevelMain
var t := 0.0
var shot_i := 0
var built := false
var _next_report := 0.0
var _shots_at := []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep shooting while the game is paused (pause menu shots)
	Game.autopause = false
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var mode: String = args.get("mode", "auto")
	if mode == "menu":
		if args.get("progress", "0") == "1":
			# fake a mid-game save so locked content shows up unlocked
			Game.stars = [3, 3, 2, 1, 0]
			Game.seen_enemies = {"goblin": true, "wolf": true, "shaman": true, "orc": true, "sapper": true, "gargoyle": true}
			Game.stats = {"kills": 812, "wins": 4, "towers": 41, "masteries": 5, "meteors": 12, "gold": 9000, "endless_wave": 0}
			Game._check_achievements()
		_menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(_menu)
		_shots_at = [3.0, 6.0]
		if args.has("open"):
			get_tree().create_timer(4.0).timeout.connect(func(): _menu.call(args["open"]))
		return
	Game.current_level = int(args.get("level", "0"))
	Game.seen_tutorial = args.get("tutorial", "0") == "0"
	Game.difficulty = int(args.get("diff", "0"))
	Game.hero_id = args.get("hero", "kael")
	if Game.hero_id == "sera" and Game.stars[1] == 0:
		Game.stars[1] = 1
	Game.endless = args.get("endless", "0") == "1"
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
	var ps: PackedScene = load("res://scenes/level.tscn")
	level = ps.instantiate()
	get_tree().root.add_child.call_deferred(level)
	if args.has("shot_times"):
		for s in (args["shot_times"] as String).split(","):
			_shots_at.append(float(s))

func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.01)
	var mode: String = args.get("mode", "auto")
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
			"victory":
				L2._victory()
			"defeat":
				L2._defeat()
			"enemy":
				L2._show_enemy_card(args.get("enemy", "orc"))
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
			L2.cam_rig.zoom = float(args.get("zoom", "14"))
			L2.cam_rig.target = fp
			L2.cam_rig._pos = fp
			L2.hud.root.visible = args.get("hud", "1") == "1"
			L2.hud.overlay.visible = args.get("hud", "1") == "1"
			await get_tree().process_frame
		if args.get("follow", "0") == "1" and LevelMain.I and not LevelMain.I.enemies.is_empty():
			var e: Enemy = LevelMain.I.enemies[LevelMain.I.enemies.size() / 2]
			LevelMain.I.cam_rig.focus(e.global_position, float(args.get("zoom", "22")))
			LevelMain.I.cam_rig._pos = LevelMain.I.cam_rig.target
			await get_tree().process_frame
		_shot()
	if mode == "menu":
		if t > 7.0:
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
		if LevelMain.I.state == "ready" and t > 2.0:
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
			elif t - float(get_meta("end")) > 3.0:
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
	for i in L.plots.size():
		if not L.towers.has(i):
			L._select_plot(i)
			L._on_radial_chosen("build_" + want)
			return

var _menu: Node
var _gt := 0.0

func _smart_tick(delta: float) -> void:
	var L := LevelMain.I
	if t < 1.0:
		return
	Engine.time_scale = float(args.get("speed", "6"))
	_ai_cd -= delta
	if _ai_cd <= 0.0:
		_ai_cd = 0.35
		var limit := mini(L.plots.size(), int(args.get("base_towers", "5")) + int((L.wave_idx + 1) * float(args.get("tower_rate", "0.7"))))
		var want := _desired_type(L)
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
		if all_l3:
			for i in L.towers.keys():
				var tw: Tower = L.towers[i]
				if tw.level == 3 and tw.mastery == "":
					var mc := int(DB.mastery_def(tw.type, BEST_MASTERY[tw.type])["cost"])
					if mc < up_c:
						up_c = mc
						up_i = i
		var leaking := L.lives < _last_lives
		_last_lives = L.lives
		var can_build := L.towers.size() < limit and L.gold >= cost
		if L.towers.size() < 4 or leaking:
			if can_build:
				_ai_build(L, want)
		elif up_i >= 0 and L.gold >= up_c:
			var tw2: Tower = L.towers[up_i]
			L._select_tower(up_i)
			L._on_radial_chosen("upgrade" if tw2.level < 3 else "mastery_" + BEST_MASTERY[tw2.type])
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
			if dense and L.spell_cd["meteor"] <= 0.0 and dn >= 5:
				L.targeting = "meteor"
				L._handle_targeting(dense.global_position + dense.vel * 0.6)
			if lead and L.spell_cd["reinforce"] <= 0.0 and lead.dist / lead.path.length > 0.45:
				L.targeting = "reinforce"
				L._handle_targeting(lead.global_position + lead.vel * 1.5)
			if L.hero and L.hero.alive and lead and L.hero.target == null and randf() < 0.15:
				L.hero.move_to(lead.global_position + lead.vel * 1.2)
	if L.state == "ready":
		L._call_wave()
	elif L.state == "playing" and L._spawning_done() and L.enemies.is_empty() and args.get("early", "1") == "1":
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
			tw.apply_mastery(ms[i % 2]["id"])
	L.hud.set_gold(L.gold)

func _shot() -> void:
	var dir: String = args.get("shots", "/tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := "%s/%s_%02d.png" % [dir, args.get("tag", "shot"), shot_i]
	shot_i += 1
	img.save_png(p)
	print("SHOT ", p)
