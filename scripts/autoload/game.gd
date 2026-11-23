extends Node
## Global game state: progress, settings, scene transitions.

const SAVE_PATH := "user://rune_bastion_save.cfg"

const LEVEL_COUNT := 5
var stars: Array = [0, 0, 0, 0, 0]
var heroic: Array = [false, false, false, false, false]
var upgrades := {}
var difficulty := 0  # 0 = normal, 1 = heroic (veteran)
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

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	high_quality = not is_mobile
	_load()
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

var compact := false
var autopause := true  # off in automated test runs

func apply_quality() -> void:
	var vp := get_tree().root
	vp.msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 1.0 if high_quality else 0.8

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
	goto_scene("res://scenes/level.tscn")

func start_endless(map_idx: int) -> void:
	current_level = map_idx
	endless_map = map_idx
	endless = true
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
	cf.set_value("settings", "music", music_volume)
	cf.set_value("settings", "sfx", sfx_volume)
	cf.set_value("settings", "hq", high_quality)
	cf.save(SAVE_PATH)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	var s = cf.get_value("progress", "stars", stars)
	if s is Array:
		for i in mini(s.size(), LEVEL_COUNT):
			stars[i] = int(s[i])
	var h = cf.get_value("progress", "heroic", heroic)
	if h is Array:
		for i in mini(h.size(), LEVEL_COUNT):
			heroic[i] = bool(h[i])
	var u = cf.get_value("progress", "upgrades", {})
	if u is Dictionary:
		upgrades = u
	seen_tutorial = cf.get_value("progress", "tutorial", false)
	hero_id = str(cf.get_value("progress", "hero", "kael"))
	if not DB.HEROES.has(hero_id):
		hero_id = "kael"
	for key in ["seen", "stats", "achievements", "endless_best"]:
		var v = cf.get_value("progress", key, {})
		if v is Dictionary:
			match key:
				"seen": seen_enemies = v
				"stats": stats = v
				"achievements": achievements = v
				"endless_best": endless_best = v
	music_volume = cf.get_value("settings", "music", music_volume)
	sfx_volume = cf.get_value("settings", "sfx", sfx_volume)
	high_quality = cf.get_value("settings", "hq", high_quality)
