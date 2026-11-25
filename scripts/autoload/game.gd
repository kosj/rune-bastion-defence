extends Node
## Global game state: progress, settings, scene transitions.

const SAVE_PATH := "user://rune_bastion_save.cfg"

var stars: Array = []
var heroic: Array = []
var upgrades := {}
var difficulty := 0  # 0 = normal, 1 = heroic (veteran), 2 = casual (easy)
var challenge := false  # iron challenge run (3 lives, no spells), unlocked by 3 stars in a region
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
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	high_quality = not is_mobile
	reset_progress()
	_load()
	Lang.apply(language)
	if OS.has_feature("web"):
		print("[RB] gpu texture formats: etc2=%s astc=%s s3tc=%s" % [OS.has_feature("etc2"), OS.has_feature("astc"), OS.has_feature("s3tc")])
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.03, 0.03, 0.06, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	apply_quality()
	get_tree().root.size_changed.connect(_fit_ui)
	_fit_ui()

## Phones (small CSS viewport) get a smaller virtual canvas so buttons stay finger-sized.
func _fit_ui() -> void:
	var win := get_tree().root
	var px := Vector2(win.size)
	var dpr := maxf(DisplayServer.screen_get_scale(), 1.0)
	var css := px / dpr
	var small := minf(css.x, css.y) < 560.0
	compact = small
	win.content_scale_size = Vector2i(960, 540) if small else Vector2i(1280, 720)
	# phones have little headroom below the 540-line layouts, so their range is narrower
	win.content_scale_factor = clampf(ui_scale, 0.9, 1.1) if small else ui_scale

var compact := false
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
	if path.ends_with("level.tscn") and not Content.is_ready:
		# the battle needs the streamed 3D content (web): wait for it behind a progress card
		await Content.wait_with_overlay()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade_rect, "color:a", 0.0, 0.5)
	await tw2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func start_level(idx: int) -> void:
	current_level = idx
	endless = false
	challenge = false
	goto_scene("res://scenes/level.tscn")

func start_challenge(idx: int) -> void:
	current_level = idx
	endless = false
	challenge = true
	goto_scene("res://scenes/level.tscn")

func iron_done(idx: int) -> bool:
	return int(stats.get("iron_%d" % idx, 0)) > 0

func start_endless(map_idx: int) -> void:
	current_level = map_idx
	endless_map = map_idx
	endless = true
	challenge = false
	goto_scene("res://scenes/level.tscn")

func hero_unlocked(id: String) -> bool:
	var need := int(DB.HEROES[id].get("unlock", -1))
	return need < 0 or stars[need] > 0

func endless_unlocked() -> bool:
	return stars[2] > 0

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
	cf.save(SAVE_PATH)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	_apply_config(cf)

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
