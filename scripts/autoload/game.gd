extends Node
## Global game state: progress, settings, scene transitions.

const SAVE_PATH := "user://rune_bastion_save.cfg"
## A copy of the last save that loaded cleanly (taken once per session). A save that cannot be
## read (a tab closed mid-write, a damaged browser store) falls back to it.
const BACKUP_PATH := "user://rune_bastion_save.bak.cfg"
const SAVE_VERSION := 2
var _persist_asked := false
## Tester tools (the play-log export in Settings): debug builds, or "?dev" in the page address.
var dev := OS.is_debug_build()
var restored_from_backup := false

var stars: Array = []
var heroic: Array = []
var upgrades := {}
var difficulty := 0  # 0 = normal, 1 = heroic (veteran), 2 = casual (easy)
var challenge := false  # iron challenge run (3 lives, no spells), unlocked by 3 stars in a region
var daily := false      # today's challenge run (DB.daily_for)
var daily_mods: Array = []
var hero_id := "kael"
var seen_enemies := {}
var stats := {}
var achievements := {}
var endless := false
var endless_map := 0
var endless_best := {}

signal achievement_unlocked(id: String)
var current_level := 0
var music_volume := 0.7
var sfx_volume := 0.9
var high_quality := true
var seen_tutorial := false
var is_mobile := false
var hero_xp := {}        # lifetime battle experience per hero -> talent ranks
var hero_talents := {}   # hero id -> {talent id: level}
var ui_scale := 1.0
var screen_shake := true
var vibration := true
var language := ""       # "" = follow the browser / OS language
var battery_saver := false  # cap the frame rate at 30 (cooler, longer-lasting phones)

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_note: Label  # "preparing the battlefield" while the shader warm-up holds the frames
var _wipe: SceneWipe    # the scene change: a slanted ink panel sweeps across with an or edge
var _busy := false
var _vis_cb: JavaScriptObject  # kept alive: the page calls it on visibilitychange / pagehide

## visibilitychange / pagehide: when the page is hidden, keep the progress (a phone may close a
## background tab without asking) and let a battle pause itself.
func _on_page_hidden(args: Array) -> void:
	var ev: JavaScriptObject = args[0] if args.size() > 0 else null
	var kind := str(ev.type) if ev != null else ""
	if kind == "pagehide" or str(JavaScriptBridge.eval("document.visibilityState", true)) == "hidden":
		save()
		backgrounded.emit()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	high_quality = not is_mobile
	reset_progress()
	_load()
	Lang.apply(language)
	if OS.has_feature("web"):
		print("[RB] gpu texture formats: etc2=%s astc=%s s3tc=%s" % [OS.has_feature("etc2"), OS.has_feature("astc"), OS.has_feature("s3tc")])
		# "?perf=1" in the address: the performance readout for testing on devices (docs/DEVICE_TEST.md)
		var q := str(JavaScriptBridge.eval("location.search", true))
		dev = dev or q.contains("dev")
		var sq := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('safe') || ''", true))
		if sq != "" and sq != "null":
			safe_override = sq
		if q.contains("perf"):
			(func(): PerfOverlay.toggle(get_tree())).call_deferred()
		_vis_cb = JavaScriptBridge.create_callback(_on_page_hidden)
		(JavaScriptBridge.get_interface("document") as JavaScriptObject).addEventListener("visibilitychange", _vis_cb)
		(JavaScriptBridge.get_interface("window") as JavaScriptObject).addEventListener("pagehide", _vis_cb)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.03, 0.03, 0.06, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	_wipe = SceneWipe.new()
	_fade_layer.add_child(_wipe)
	_fade_note = Label.new()
	_fade_note.visible = false
	_fade_note.set_anchors_preset(Control.PRESET_CENTER)
	_fade_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fade_note.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fade_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_note.add_theme_font_override("font", Assets.font("ui"))
	_fade_note.add_theme_font_size_override("font_size", 20)
	_fade_note.add_theme_color_override("font_color", Color(0.62, 0.667, 0.73))
	_fade_layer.add_child(_fade_note)
	apply_quality()
	get_tree().root.size_changed.connect(_fit_ui)
	_fit_ui()

## Phones (small CSS viewport) get a smaller virtual canvas so buttons stay finger-sized.
## A window taller than it is wide (a phone held upright) gets an upright canvas, so the UI keeps
## its size instead of shrinking to fit a landscape layout into the narrow width; screens that
## lay themselves out by orientation listen to `layout_changed`.
func _fit_ui() -> void:
	var win := get_tree().root
	var px := Vector2(win.size)
	var dpr := maxf(DisplayServer.screen_get_scale(), 1.0)
	var css := px / dpr
	var small := minf(css.x, css.y) < 560.0
	compact = small
	var was_tall := tall
	tall = px.y > px.x * 1.05
	if tall:
		win.content_scale_size = Vector2i(480, 854) if small else Vector2i(720, 1280)
	else:
		win.content_scale_size = Vector2i(960, 540) if small else Vector2i(1280, 720)
	# phones have little headroom below the 540-line layouts, so their range is narrower
	win.content_scale_factor = clampf(ui_scale, 0.9, 1.1) if small else ui_scale
	_read_safe_area()
	# a turned phone reports its new insets a moment after the resize
	if OS.has_feature("web") and is_inside_tree():
		get_tree().create_timer(0.5).timeout.connect(_read_safe_area)
	if was_tall != tall:
		layout_changed.emit()

var compact := false

## Safe area: the edges of the screen a notch, rounded corners or the home indicator cover
## (left, top, right, bottom, in canvas units). The page fills the whole screen (viewport-fit=cover)
## so the battlefield runs under them; screens keep their buttons and text inside (apply_safe).
var safe := Vector4.ZERO
signal safe_changed
## Test override (canvas units "l,t,r,b"): test_runner's safe=, or "?safe=" in the page address.
var safe_override := ""

## Reads the browser's safe-area insets (CSS env(), through a hidden probe element) and converts
## them from CSS pixels to canvas units.
func _read_safe_area() -> void:
	var v := Vector4.ZERO
	if safe_override != "":
		var f := safe_override.split_floats(",")
		if f.size() == 4:
			v = Vector4(f[0], f[1], f[2], f[3])
	elif OS.has_feature("web"):
		var r = JavaScriptBridge.eval("""(() => {
			let d = document.getElementById('rb_safe');
			if (!d) {
				d = document.createElement('div');
				d.id = 'rb_safe';
				d.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;' +
					'padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
				document.body.appendChild(d);
			}
			const s = getComputedStyle(d);
			return [s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom].map(x => parseFloat(x) || 0).join(',') + ',' + window.innerWidth;
		})()""", true)
		var f := str(r).split_floats(",")
		if f.size() == 5 and f[4] > 0.0:
			var k := get_tree().root.get_visible_rect().size.x / f[4]
			v = Vector4(f[0], f[1], f[2], f[3]) * k
	v = v.round()
	if v != safe:
		safe = v
		safe_changed.emit()

## The part of the screen inside the safe area (canvas units).
func safe_rect() -> Rect2:
	var vs := get_tree().root.get_visible_rect().size
	return Rect2(Vector2(safe.x, safe.y), vs - Vector2(safe.x + safe.z, safe.y + safe.w))

func safe_size() -> Vector2:
	return safe_rect().size

## Keeps a full-rect Control inside the safe area (its children anchor to the safe edges), now and
## whenever the insets change. bleed=true does the opposite for a child of such a control: it
## reaches back out to the screen edges (backdrops, dimmers).
func apply_safe(c: Control, bleed := false) -> void:
	var k := -1.0 if bleed else 1.0
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = safe.x * k
	c.offset_top = safe.y * k
	c.offset_right = -safe.z * k
	c.offset_bottom = -safe.w * k
	c.set_meta("safe_inset", not bleed)
	if not c.has_meta("safe_hooked"):
		c.set_meta("safe_hooked", true)
		safe_changed.connect(func():
			if is_instance_valid(c):
				apply_safe(c, bleed))
## The window is upright (portrait): screens stack their parts vertically and dialogs come up
## from the bottom edge as sheets.
var tall := false
signal layout_changed
## The page went to the background (another tab, another app on a phone, the screen locked). The
## window's blur event, which the engine turns into a focus-out, does not come in every browser
## (mobile Safari switching apps), so the page's own visibility is watched as well.
signal backgrounded
var autopause := true  # off in automated test runs
var testing := false  # automated runs: skip the first-visit level intros
## Recent runs (newest last) for playtest feedback: shared as a code from the settings screen.
var playlog: Array = []
const PLAYLOG_MAX := 60

## The 3D resolution the quality setting asks for; ResGuard may go below it on a slow GPU.
func base_3d_scale() -> float:
	return 1.0 if high_quality else 0.8

var res_guard: ResGuard

## Startup / loading timing marks for the browser console (ms since the engine started).
func mark(what: String) -> void:
	print("RB_MARK %s %d" % [what, Time.get_ticks_msec()])

func apply_quality() -> void:
	var vp := get_tree().root
	vp.msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = base_3d_scale()
	if res_guard == null:
		res_guard = ResGuard.new()
		add_child(res_guard)
	res_guard.reset()
	# automatic mesh LOD: on the low setting accept ~4 px of simplification error (phones, small screens)
	vp.mesh_lod_threshold = 1.0 if high_quality else 4.0
	get_tree().call_group("unit_shadow", "refresh_shadow")
	Engine.max_fps = 30 if battery_saver else 0

func set_ui_scale(v: float) -> void:
	ui_scale = v
	_fit_ui()
	save()

## Short haptic pulse (Android browsers / native mobile; silently ignored elsewhere).
func vibrate(ms: int) -> void:
	if vibration and is_mobile:
		Input.vibrate_handheld(ms)

## Fresh (empty) progress sized to the current region list.
func reset_progress() -> void:
	stars = []
	heroic = []
	for i in DB.LEVELS.size():
		stars.append(0)
		heroic.append(false)
	upgrades = {}
	seen_tutorial = false
	seen_enemies = {}
	stats = {}
	achievements = {}
	endless_best = {}
	hero_id = "kael"
	hero_xp = {}
	hero_talents = {}
	playlog = []

func log_play(entry: Dictionary) -> void:
	playlog.append(entry)
	while playlog.size() > PLAYLOG_MAX:
		playlog.pop_front()
	save()

## Play log as a compact text code (gzip + base64) a tester can paste into a chat or an issue.
func playlog_code() -> String:
	var body := JSON.stringify({"v": 1, "lang": TranslationServer.get_locale(), "runs": playlog})
	var b64 := Marshalls.raw_to_base64(body.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	return "RBP1-%s-%s" % [b64.md5_text().substr(0, 6), b64]

## Lifetime hero experience (talent ranks). Returns true when the hero reached a new rank.
func add_hero_xp(id: String, v: float) -> bool:
	var before := DB.hero_rank(id)
	hero_xp[id] = float(hero_xp.get(id, 0.0)) + v
	return DB.hero_rank(id) > before

func unlocked(level_idx: int) -> bool:
	return level_idx == 0 or stars[level_idx - 1] > 0

func set_stars(level_idx: int, s: int) -> void:
	stars[level_idx] = maxi(stars[level_idx], s)
	if difficulty == 1:
		heroic[level_idx] = true
	save()

func available_stars() -> int:
	return DB.total_stars() - DB.spent_stars()

func goto_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	Content.warm_cancel()  # the next scene loads what it needs itself
	if path.ends_with("level.tscn"):
		# the battle needs its download chunks (web): wait for them behind a progress card
		await Content.ensure(Content.level_needs(current_level), "전장을 준비하는 중...")
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _wipe.cover(0.34)
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if path.ends_with("level.tscn") and LevelMain.I and is_instance_valid(LevelMain.I) and LevelMain.I.is_inside_tree():
		# compile every shader the battle can need while the screen is still dark (ShaderWarmup)
		_fade_note.text = tr("전장을 준비하는 중...")
		_fade_note.visible = true
		await get_tree().process_frame  # the note is on screen before the compiles hold the frames
		await ShaderWarmup.run(LevelMain.I)
		_fade_note.visible = false
	await _wipe.uncover(0.42)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

## F3: performance readout on/off (any screen).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3:
		PerfOverlay.toggle(get_tree())

func start_level(idx: int) -> void:
	current_level = idx
	endless = false
	challenge = false
	daily = false
	goto_scene("res://scenes/level.tscn")

func start_challenge(idx: int) -> void:
	current_level = idx
	endless = false
	challenge = true
	daily = false
	goto_scene("res://scenes/level.tscn")

func iron_done(idx: int) -> bool:
	return int(stats.get("iron_%d" % idx, 0)) > 0

func start_endless(map_idx: int) -> void:
	current_level = map_idx
	endless_map = map_idx
	endless = true
	challenge = false
	daily = false
	goto_scene("res://scenes/level.tscn")

func hero_unlocked(id: String) -> bool:
	var need := int(DB.HEROES[id].get("unlock", -1))
	return need < 0 or stars[need] > 0

func endless_unlocked() -> bool:
	return stars[2] > 0

# ---------------------------------------------------------------- daily challenge

## Days since 1970 in the player's local time (the challenge changes at local midnight).
func today() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floor((Time.get_unix_time_from_system() + bias * 60.0) / 86400.0))

func daily_unlocked() -> bool:
	return stars[1] > 0

func daily_today() -> Dictionary:
	var cleared: Array = []
	for i in stars.size():
		if int(stars[i]) > 0:
			cleared.append(i)
	return DB.daily_for(today(), cleared)

func daily_done_today() -> bool:
	return int(stats.get("daily_last", -1)) == today()

func daily_streak() -> int:
	var last := int(stats.get("daily_last", -1))
	if last == today() or last == today() - 1:
		return int(stats.get("daily_streak", 0))
	return 0

func start_daily() -> void:
	var dd := daily_today()
	current_level = int(dd["level"])
	endless = false
	challenge = false
	daily = true
	daily_mods = dd["mods"]
	goto_scene("res://scenes/level.tscn")

func daily_has(mod: String) -> bool:
	return daily and mod in daily_mods

## A daily win: the first one each day pays out and extends the streak. Returns the reward
## (hero xp) or 0 when today's was already done.
func daily_won(hid: String) -> int:
	if daily_done_today():
		return 0
	var last := int(stats.get("daily_last", -1))
	var streak := int(stats.get("daily_streak", 0)) + 1 if last == today() - 1 else 1
	stats["daily_last"] = today()
	stats["daily_streak"] = streak
	stat("daily_streak_best", streak, "max")
	stat("daily_wins")
	if hid != "":
		add_hero_xp(hid, DB.DAILY_XP)
	return DB.DAILY_XP

## Track a lifetime statistic; mode "add" accumulates, "max" keeps the best value.
func stat(key: String, v := 1, mode := "add") -> void:
	var cur := int(stats.get(key, 0))
	stats[key] = cur + v if mode == "add" else maxi(cur, v)
	_check_achievements()

func mark_seen(enemy_type: String) -> void:
	if not seen_enemies.has(enemy_type):
		seen_enemies[enemy_type] = true

func _check_achievements() -> void:
	for a in DB.ACHIEVEMENTS:
		var id: String = a["id"]
		if achievements.get(id, false):
			continue
		if int(stats.get(a["stat"], 0)) >= int(a["goal"]):
			achievements[id] = true
			achievement_unlocked.emit(id)

func achievement_count() -> int:
	var n := 0
	for k in achievements:
		if achievements[k]:
			n += 1
	return n

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "stars", stars)
	cf.set_value("progress", "heroic", heroic)
	cf.set_value("progress", "upgrades", upgrades)
	cf.set_value("progress", "tutorial", seen_tutorial)
	cf.set_value("progress", "hero", hero_id)
	cf.set_value("progress", "seen", seen_enemies)
	cf.set_value("progress", "stats", stats)
	cf.set_value("progress", "achievements", achievements)
	cf.set_value("progress", "endless_best", endless_best)
	cf.set_value("progress", "hero_xp", hero_xp)
	cf.set_value("progress", "hero_talents", hero_talents)
	cf.set_value("progress", "playlog", playlog)
	cf.set_value("settings", "music", music_volume)
	cf.set_value("settings", "sfx", sfx_volume)
	cf.set_value("settings", "hq", high_quality)
	cf.set_value("settings", "ui_scale", ui_scale)
	cf.set_value("settings", "shake", screen_shake)
	cf.set_value("settings", "vibration", vibration)
	cf.set_value("settings", "language", language)
	cf.set_value("settings", "battery_saver", battery_saver)
	cf.set_value("meta", "version", SAVE_VERSION)
	cf.save(SAVE_PATH)
	_ask_persist()

## Web: ask the browser to keep this site's storage (it may otherwise clear a rarely visited
## site's data under storage pressure). Granted silently for installed / often used sites.
func _ask_persist() -> void:
	if _persist_asked or not OS.has_feature("web"):
		return
	_persist_asked = true
	JavaScriptBridge.eval("try{navigator.storage&&navigator.storage.persist&&navigator.storage.persist()}catch(e){}", true)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK and cf.has_section("progress"):
		_apply_config(cf)
		# a good save: keep a copy to fall back on
		cf.save(BACKUP_PATH)
		return
	var bk := ConfigFile.new()
	if FileAccess.file_exists(SAVE_PATH) and bk.load(BACKUP_PATH) == OK and bk.has_section("progress"):
		_apply_config(bk)
		restored_from_backup = true
		print("[RB] save unreadable, restored the backup")

func _apply_config(cf: ConfigFile) -> void:
	var s = cf.get_value("progress", "stars", stars)
	if s is Array:
		for i in mini(s.size(), stars.size()):
			stars[i] = clampi(int(s[i]), 0, 3)
	var h = cf.get_value("progress", "heroic", heroic)
	if h is Array:
		for i in mini(h.size(), heroic.size()):
			heroic[i] = bool(h[i])
	var u = cf.get_value("progress", "upgrades", {})
	if u is Dictionary:
		upgrades = u
	seen_tutorial = cf.get_value("progress", "tutorial", false)
	hero_id = str(cf.get_value("progress", "hero", "kael"))
	if not DB.HEROES.has(hero_id):
		hero_id = "kael"
	for key in ["seen", "stats", "achievements", "endless_best", "hero_xp", "hero_talents"]:
		var v = cf.get_value("progress", key, {})
		if v is Dictionary:
			match key:
				"seen": seen_enemies = v
				"stats": stats = v
				"achievements": achievements = v
				"endless_best": endless_best = v
				"hero_xp": hero_xp = v
				"hero_talents": hero_talents = v
	var pl = cf.get_value("progress", "playlog", [])
	if pl is Array:
		playlog = pl
	music_volume = float(cf.get_value("settings", "music", music_volume))
	sfx_volume = float(cf.get_value("settings", "sfx", sfx_volume))
	high_quality = bool(cf.get_value("settings", "hq", high_quality))
	ui_scale = clampf(float(cf.get_value("settings", "ui_scale", ui_scale)), 0.8, 1.25)
	screen_shake = bool(cf.get_value("settings", "shake", screen_shake))
	vibration = bool(cf.get_value("settings", "vibration", vibration))
	language = str(cf.get_value("settings", "language", language))
	battery_saver = bool(cf.get_value("settings", "battery_saver", battery_saver))

# ---------------------------------------------------------------- save transfer codes

const CODE_TAG := "RB1"

## Whole save as a copy-pasteable text code (moves progress between browsers / devices).
func export_code() -> String:
	save()
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var body := Marshalls.utf8_to_base64(cf.encode_to_text())
	return "%s-%s-%s" % [CODE_TAG, body.md5_text().substr(0, 6), body]

## Validates and applies a save code. Returns "" on success or an error message.
func import_code(code: String) -> String:
	var c := code.strip_edges().replace(" ", "").replace("\n", "").replace("\r", "")
	var parts := c.split("-", true, 2)
	if parts.size() != 3 or parts[0] != CODE_TAG:
		return "올바른 저장 코드가 아닙니다."
	if parts[2].md5_text().substr(0, 6) != parts[1]:
		return "코드가 손상되었습니다. 전체를 다시 복사해 주세요."
	var cf := ConfigFile.new()
	if cf.parse(Marshalls.base64_to_utf8(parts[2])) != OK or not cf.has_section("progress"):
		return "저장 데이터를 읽을 수 없습니다."
	reset_progress()
	_apply_config(cf)
	if not DB.HEROES.has(hero_id):
		hero_id = "kael"
	save()
	Lang.apply(language)
	_fit_ui()
	apply_quality()
	return ""
