class_name HUD
extends CanvasLayer
## In-game HUD: resources, wave call buttons, hero & spell buttons, info panel, banners, menus.

signal speed_toggled
signal pause_pressed
signal hero_pressed
signal skill_pressed
signal skill2_pressed
signal spell_pressed(id: String)
signal wave_called

var root: Control
var lives_l: Label
var gold_l: Label
var wave_l: Label
var speed_b: Button
var pause_b: Button
var hero_b: Button
var hero_hp: ProgressBar
var hero_xp: ProgressBar
var hero_lv: Label
var hero_dead: Label
var skill_b: Button
var skill_cd: TextureProgressBar
var skill2_b: Button
var skill2_cd: TextureProgressBar
var _skill2_lock: Control
var spell_btns := {}
var wave_btns: Array = []
var info: PanelContainer
var info_title: Label
var info_body: Label
var banner: Label
## Screen-space layer under the panels: the wave call buttons and the radial build menu.
var world_ui: Control
var banner_sub: Label
var hint: PanelContainer
var hint_l: Label
var radial: RadialMenu
var overlay: Overlay
var target_hint: Label
var _circle_tex: Texture2D
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var markers: Control
## Notices (a new enemy, achievements, tips) stacked in one column so they never overlap each
## other or the selection card: across the width under the top bar on an upright phone (after
## the selection card), down the right side under the corner buttons on a wide screen.
var _notes: Array = []
var _info_dy := 0.0  # selection card slide-in, eased to 0 in _process
var _wb_t := -1.0
var boss_name: Label
var vignette: TextureRect
var _vig_pulse := 0.0
var _low_lives := false
var _gold_shown := 0.0
var _gold_target := 0

func build(cam: Camera3D) -> void:
	layer = 10
	_circle_tex = _make_circle(96)
	overlay = Overlay.new()
	overlay.cam = cam
	add_child(overlay)
	# world-anchored markers (wave call buttons and their previews) draw under every HUD panel:
	# a selection card or a notice must never be covered by a button that follows the map. They
	# live in screen space (the whole screen); the panels in `root`, inside the safe area.
	world_ui = Control.new()
	world_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_ui.theme = UI.theme()
	add_child(world_ui)
	markers = Control.new()
	markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_ui.add_child(markers)
	radial = RadialMenu.new()
	radial.cam = cam
	world_ui.add_child(radial)
	radial.keepout = _panel_rects
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	Game.apply_safe(root)
	_build_top()
	_build_bottom()
	_build_info()
	_build_banner()
	_build_boss_bar()
	_build_vignette()
	_apply_layout()
	Game.layout_changed.connect(_apply_layout)

func _make_circle(sz: int) -> Texture2D:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz, sz) * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(sz * 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, 0.62 * a))
	return ImageTexture.create_from_image(img)

var _res_items: Array = []  # [icon, label, min width] of the top-bar counters
var top_panel: PanelContainer
var top_right: HBoxContainer
var dock: Control

func _res_item(icon: String, txt: String, col: Color, min_w := 58) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UI.icon(Assets.tex(icon), 36)
	hb.add_child(ic)
	var l := UI.label(txt, 28, col, 7, "ui_black")
	l.custom_minimum_size.x = min_w
	hb.add_child(l)
	_res_items.append([ic, l, min_w])
	return [hb, l]

func _vsep() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.93, 0.74, 0.36, 0.32)  # a hairline in the trim's gold
	c.custom_minimum_size = Vector2(2, 28)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _build_top() -> void:
	var p := UI.framed("slim", 2)
	p.position = Vector2(14, 12)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _res_item("heart", "20", Color(1.0, 0.62, 0.56), 40)
	lives_l = a[1]
	hb.add_child(a[0])
	hb.add_child(_vsep())
	var b := _res_item("coin", "0", UI.GOLD, 70)
	gold_l = b[1]
	hb.add_child(b[0])
	hb.add_child(_vsep())
	var c := _res_item("skull", "1/10", UI.TEXT, 74)
	wave_l = c[1]
	hb.add_child(c[0])
	# room before the frame's right edge: "웨이브 10/10" / "Wave 10/10" ran into the border
	var pad := Control.new()
	pad.custom_minimum_size.x = 6
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(pad)
	p.add_child(hb)
	root.add_child(p)
	top_panel = p

	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	speed_b = UI.round_button(Assets.tex("speed1"), 64)
	speed_b.pressed.connect(func(): speed_toggled.emit())
	pause_b = UI.round_button(Assets.tex("pause"), 64)
	pause_b.pressed.connect(func(): pause_pressed.emit())
	tr.add_child(speed_b)
	tr.add_child(pause_b)
	root.add_child(tr)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -152
	tr.offset_right = -14
	tr.offset_top = 12
	top_right = tr

func _cooldown_overlay(parent: Control, sz: int) -> TextureProgressBar:
	var t := TextureProgressBar.new()
	t.texture_progress = _circle_tex
	t.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	t.nine_patch_stretch = true
	t.position = Vector2(sz, sz) * 0.09
	t.size = Vector2(sz, sz) * 0.82
	t.max_value = 1.0
	t.step = 0.001
	t.value = 0.0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _build_bottom() -> void:
	var bl := Control.new()
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_top = -128
	bl.offset_left = 14
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)
	dock = bl
	# hero portrait medallion
	hero_b = UI.icon_button(null, 98, UI.NAVY, 49, "brown")
	var hp_por := UI.portrait(Assets.tex(DB.hero_def()["portrait"]), 80)
	hp_por.position = Vector2(9, 9)
	hp_por.size = Vector2(80, 80)
	hero_b.add_child(hp_por)
	hero_b.position = Vector2(0, 2)
	hero_b.pressed.connect(func(): hero_pressed.emit())
	bl.add_child(hero_b)
	hero_hp = UI.bar("green", 90, 13)
	hero_hp.position = Vector2(4, 98)
	hero_hp.size = Vector2(90, 13)
	bl.add_child(hero_hp)
	hero_xp = UI.bar("gold", 90, 9)
	hero_xp.position = Vector2(4, 111)
	hero_xp.size = Vector2(90, 9)
	bl.add_child(hero_xp)
	var badge := UI.badge("1", 36, 20)
	badge.position = Vector2(68, -4)
	bl.add_child(badge)
	hero_lv = badge.get_node("Text") as Label
	hero_dead = UI.label("", 34, Color(1, 0.7, 0.6), 8, "ui_black")
	hero_dead.position = Vector2(0, 26)
	hero_dead.size = Vector2(98, 48)
	hero_dead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_dead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(hero_dead)
	# hero skill
	skill_b = UI.icon_button(Assets.tex(DB.hero_def()["skill_icon"]), 68, UI.NAVY, 34, "red")
	skill_b.position = Vector2(110, 40)
	skill_b.pressed.connect(func(): skill_pressed.emit())
	bl.add_child(skill_b)
	skill_cd = _cooldown_overlay(skill_b, 68)
	# second hero skill, stacked above the first (the dock stays as wide as before); locked until
	# the hero reaches battle level DB.SKILL2_LEVEL
	skill2_b = UI.icon_button(Assets.tex(DB.hero_def()["skill2"]["icon"]), 58, UI.NAVY, 29, "red")
	skill2_b.position = Vector2(115, -28)
	skill2_b.pressed.connect(func(): skill2_pressed.emit())
	bl.add_child(skill2_b)
	skill2_cd = _cooldown_overlay(skill2_b, 58)
	_skill2_lock = Control.new()
	_skill2_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill2_lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	skill2_b.add_child(_skill2_lock)
	var lk := UI.icon(Assets.tex("lock"), 26)
	lk.position = Vector2(16, 8)
	_skill2_lock.add_child(lk)
	var ll := UI.label("Lv%d" % DB.SKILL2_LEVEL, 17, UI.TEXT, 5, "ui_black")
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.position = Vector2(0, 31)
	ll.size = Vector2(58, 20)
	_skill2_lock.add_child(ll)
	set_skill2_open(false)
	# spells
	var x := 192
	for id in ["meteor", "reinforce"]:
		var sb := UI.icon_button(Assets.tex("spell_" + id), 86, UI.NAVY, 43, "purple")
		sb.position = Vector2(x, 22)
		sb.pressed.connect(func(): spell_pressed.emit(id))
		bl.add_child(sb)
		var ov := _cooldown_overlay(sb, 86)
		var cl := UI.label("", 28, UI.TEXT, 7, "ui_black")
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.size = Vector2(86, 86)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sb.add_child(cl)
		spell_btns[id] = {"button": sb, "cd": ov, "label": cl}
		x += 98
	target_hint = UI.label("", 26, UI.GOLD, 8, "ui_black")
	target_hint.anchor_left = 0.5
	target_hint.anchor_right = 0.5
	target_hint.anchor_top = 1.0
	target_hint.anchor_bottom = 1.0
	target_hint.offset_left = -300
	target_hint.offset_right = 300
	target_hint.offset_top = -150
	target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(target_hint)

## Daily "no hero": the portrait, bars and skill buttons go.
func hide_hero() -> void:
	for c in [hero_b, hero_hp, hero_xp, hero_lv.get_parent(), hero_dead, skill_b, skill2_b]:
		(c as Control).visible = false
	# the spells slide into the corner the hero left
	for sid in spell_btns:
		var b: Control = (spell_btns[sid] as Dictionary)["button"]
		b.position.x -= 186.0

## The second hero skill opens (pulse: just now, in battle) or shows its lock.
func set_skill2_open(open: bool, pulse := false) -> void:
	skill2_b.disabled = not open
	_skill2_lock.visible = not open
	skill2_b.self_modulate = Color.WHITE if open else Color(0.55, 0.55, 0.62)
	if open:
		skill2_cd.value = 0.0
	if pulse:
		skill2_b.pivot_offset = skill2_b.size * 0.5
		var tw := skill2_b.create_tween()
		tw.tween_property(skill2_b, "scale", Vector2.ONE * 1.35, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(skill2_b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var gl := skill2_b.create_tween().set_loops(3)
		gl.tween_property(skill2_b, "modulate", Color(1.6, 1.4, 0.9), 0.25)
		gl.tween_property(skill2_b, "modulate", Color.WHITE, 0.25)

func _mini_bar(c: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.001
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.05, 0.9)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb

var info_stats: HFlowContainer

func _build_info() -> void:
	info = UI.framed("card", 6)
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = -372
	info.offset_right = -16
	info.offset_top = -16
	info.offset_bottom = -16
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	info_title = UI.ink("", 22, UI.INK, "title_kr")
	info_body = UI.ink("", UI.T_SMALL, UI.INK_SOFT)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size.x = 320
	info_stats = HFlowContainer.new()
	info_stats.add_theme_constant_override("h_separation", 12)
	info_stats.add_theme_constant_override("v_separation", 2)
	info_stats.custom_minimum_size.x = 320
	vb.add_child(info_title)
	vb.add_child(info_body)
	vb.add_child(info_stats)
	info.add_child(vb)
	info.visible = false
	root.add_child(info)

## Selection card. `stats` is a list of [icon, text] or [icon, text, highlighted].
func show_info(title: String, body: String, stats: Array = []) -> void:
	info_title.text = title
	info_body.text = body
	info_body.visible = body != ""
	for c in info_stats.get_children():
		c.queue_free()
	for st in stats:
		var up: bool = st.size() > 2 and st[2]
		info_stats.add_child(UI.stat(st[0], st[1], 16, UI.SAGE if up else UI.INK))
	info_stats.visible = not stats.is_empty()
	if not info.visible:
		# slides 16 in (eased in _process through the offsets) and fades in. The slide never
		# touches `position`: setting it writes the current height into the offsets, and the
		# card then kept the height of the tallest text it had shown
		info.visible = true
		info.modulate.a = 0.0
		_info_dy = 16.0
		_place_info()
		var tw := info.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(info, "modulate:a", 1.0, 0.15)

func hide_info() -> void:
	info.visible = false

## The announcement band (waves, bosses, specialisations): a pennant plate across the top centre
## with the title in the display face and a line under it. It wipes open from the left, holds, and
## slides off to the right.
var banner_band: PanelContainer
var _banner_tw: Tween

func _build_banner() -> void:
	banner_band = PanelContainer.new()
	banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_band.anchor_left = 0.5
	banner_band.anchor_right = 0.5
	banner_band.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_band.offset_top = 112
	banner_band.modulate.a = 0.0
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_band.add_child(vb)
	banner = UI.label("", 50, UI.SABLE, 0, "title_kr")
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(banner)
	banner_sub = UI.label("", 22, UI.SABLE, 0, "ui_black")
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(banner_sub)
	root.add_child(banner_band)
	# tutorial hints sit low and centred, clear of the wave banner and the corner widgets
	hint = UI.framed("card", 8)
	hint_l = UI.ink("", 19, UI.INK, "ui")
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_l.custom_minimum_size.x = 440
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_l)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -240
	hint.offset_right = 240
	hint.offset_bottom = -150
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.visible = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

func show_banner(title: String, sub := "", col := UI.GOLD) -> void:
	# the caller's colour names the kind: or for the usual announcements, a red for bosses and
	# danger, a blue for the daily twist; anything else becomes a dark plate in its own hue
	var face := UI.GOLD
	var ink := UI.SABLE
	if col != UI.GOLD:
		ink = UI.VELLUM
		if col.r > 0.8 and col.g < 0.6 and col.b < 0.5:
			face = UI.EMBER
		elif col.b > col.r and col.b > 0.8:
			face = UI.AZURE
		elif col.r > 0.9 and col.g > 0.7 and col.b < 0.6:
			face = UI.GOLD
			ink = UI.SABLE
		else:
			face = Color.from_hsv(col.h, minf(col.s + 0.2, 0.75), 0.48)
	banner_band.add_theme_stylebox_override("panel", UI.plate(face, 6, Vector4(56, 6, 56, 10), 7.0, Color(UI.SABLE, 0.7), 0.22))
	banner.text = title
	banner_sub.text = sub
	banner_sub.visible = sub != ""
	for l in [banner, banner_sub]:
		(l as Label).add_theme_color_override("font_color", ink)
	# a long title steps its size down; a long line (the daily twists, a narrow phone) wraps
	var bfs := 40 if Game.tall else 50
	var bf: Font = banner.get_theme_font("font")
	while bfs > 26 and bf.get_string_size(tr(title), HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x > Game.safe_size().x - 160.0:
		bfs -= 2
	banner.add_theme_font_size_override("font_size", bfs)
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner_sub.custom_minimum_size.x = 0
	var max_w := Game.safe_size().x - 40.0
	if banner_band.get_combined_minimum_size().x > max_w:
		banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner_sub.custom_minimum_size.x = max_w - 120.0
	banner_band.size = Vector2.ZERO
	banner_band.reset_size()
	var w := minf(banner_band.get_combined_minimum_size().x, max_w)
	banner_band.offset_left = -w * 0.5
	banner_band.offset_right = w * 0.5
	banner_band.pivot_offset = Vector2(0, banner_band.get_combined_minimum_size().y * 0.5)
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	banner_band.scale = Vector2(0.0, 1.0)
	banner_band.modulate.a = 1.0
	var tw := banner_band.create_tween()
	_banner_tw = tw
	tw.tween_property(banner_band, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.7)
	tw.tween_property(banner_band, "modulate:a", 0.0, 0.22)
	var base_l := banner_band.offset_left
	var base_r := banner_band.offset_right
	tw.parallel().tween_property(banner_band, "offset_left", base_l + 60.0, 0.22).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(banner_band, "offset_right", base_r + 60.0, 0.22).set_ease(Tween.EASE_IN)

func show_hint(txt: String) -> void:
	if txt == "":
		hint.visible = false
		return
	hint_l.text = txt
	hint.visible = true
	UI.pop_in(hint)

func _build_boss_bar() -> void:
	boss_panel = UI.framed("slim", 2)
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.offset_left = -240
	boss_panel.offset_right = 240
	boss_panel.offset_top = 84
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	boss_panel.add_child(vb)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(UI.icon(Assets.tex("crown"), 30))
	boss_name = UI.label("", 21, Color(1.0, 0.78, 0.62), 5, "ui_black")
	hb.add_child(boss_name)
	vb.add_child(hb)
	boss_bar = UI.bar("red", 440, 18)
	vb.add_child(boss_bar)
	boss_panel.visible = false
	root.add_child(boss_panel)

func set_boss(name_txt: String, frac: float) -> void:
	if name_txt == "":
		if boss_panel.visible:
			boss_panel.visible = false
		return
	if not boss_panel.visible:
		boss_panel.visible = true
		UI.pop_in(boss_panel)
	boss_name.text = "  " + tr(name_txt)
	boss_bar.value = lerpf(boss_bar.value, frac, 0.25)

func _build_vignette() -> void:
	vignette = TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.8, 0.02, 0.0, 0.85))
	g.add_point(0.55, Color(0.8, 0.0, 0.0, 0.0))
	gt.gradient = g
	vignette.texture = gt
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	root.add_child(vignette)
	Game.apply_safe(vignette, true)  # the danger glow reaches the screen edges
	root.move_child(vignette, 0)

## Full-screen colour flash that fades out (the winning moment).
func flash(col: Color, dur := 0.6) -> void:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	var t := r.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(r, "modulate:a", 0.0, dur).set_ease(Tween.EASE_OUT)
	t.tween_callback(r.queue_free)

func flash_damage(low: bool) -> void:
	_vig_pulse = 1.0
	_low_lives = low

## Small enemy icons + counts beside each portal's wave button, previewing the next wave.
func set_wave_preview(per_path: Array) -> void:
	for i in wave_btns.size():
		var w: Dictionary = wave_btns[i]
		var row: HBoxContainer = w.get("preview")
		if row == null:
			var pill := UI.framed("pill", 0)
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			pill.add_child(row)
			pill.position = Vector2(-70, 70)
			(w["node"] as Control).add_child(pill)
			pill.resized.connect(func(): pill.position.x = -pill.size.x * 0.5)
			w["preview"] = row
		for c in row.get_children():
			c.queue_free()
		var counts: Dictionary = per_path[i] if i < per_path.size() else {}
		(row.get_parent() as Control).visible = not counts.is_empty()
		for k in counts:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", -6)
			cell.custom_minimum_size = Vector2(40, 0)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic := UI.bust(Assets.tex("portrait_" + k), 34, 1.55, Vector2(0.5, 0.34))
			cell.add_child(ic)
			var l := UI.label("x%d" % counts[k], 15, UI.GOLD, 4, "ui_black")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(l)
			row.add_child(cell)

func set_gold(g: int) -> void:
	_gold_target = g

var _coins_live := 0

## Coins pop out of a kill and fly into the gold counter (Kingdom Rush style reward feedback).
func fly_coins(from: Vector2, n: int) -> void:
	if gold_l == null:
		return
	var tex := Assets.tex("coin")
	# screen points to the HUD's own space (it sits inside the safe area)
	from -= root.global_position
	var target := gold_l.get_global_rect().position + Vector2(-26, gold_l.size.y * 0.5) - root.global_position
	for i in mini(n, 3):
		if _coins_live >= 24:
			return
		_coins_live += 1
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.size = Vector2(26, 26)
		c.pivot_offset = Vector2(13, 13)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = from - Vector2(13, 13)
		root.add_child(c)
		var burst := from + Vector2(randf_range(-46, 46), randf_range(-60, -20)) - Vector2(13, 13)
		var tw := c.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(c, "position", burst, 0.22 + i * 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", target - Vector2(13, 13), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "scale", Vector2(0.7, 0.7), 0.45)
		tw.tween_callback(func():
			_coins_live -= 1
			c.queue_free()
			var gb := gold_l.get_parent() as Control
			if gb:
				gb.pivot_offset = gb.size * 0.5
				var t2 := gb.create_tween()
				t2.set_ignore_time_scale(true)
				gb.scale = Vector2(1.12, 1.12)
				t2.tween_property(gb, "scale", Vector2.ONE, 0.18))

func set_lives(l: int) -> void:
	if lives_l.text != str(l):
		lives_l.text = str(l)
		var tw := lives_l.create_tween()
		lives_l.pivot_offset = lives_l.size * 0.5
		lives_l.scale = Vector2(1.4, 1.4)
		tw.tween_property(lives_l, "scale", Vector2.ONE, 0.3)

var _wave_shown := [0, 0]

func set_wave(cur: int, total: int) -> void:
	_wave_shown = [cur, total]
	if Game.tall:
		# upright top bar: the skull icon says "wave", the number is what changes
		wave_l.text = ("%d/%d" % [cur, total]) if total > 0 else ("%d/∞" % cur)
	else:
		wave_l.text = (tr("웨이브 %d/%d") % [cur, total]) if total > 0 else (tr("웨이브 %d/∞") % cur)

## After a language switch in the pause menu: labels and buttons follow on their own, the lines
## formatted once (tr("...%d") % n) are written again.
func refresh_language() -> void:
	set_wave(_wave_shown[0], _wave_shown[1])

## Small slide-in notification (achievements, tips): joins the notice column, fades out.
func toast(title: String, sub: String, icon: String) -> void:
	var p := UI.framed("card", 8)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	hb.add_child(UI.icon(Assets.tex(icon), 52))
	var vb := VBoxContainer.new()
	vb.add_child(UI.ink(title, 21, UI.INK, "ui_black"))
	var sl := UI.ink(sub, 16, UI.INK_SOFT)
	UI.wrap_words(sl, note_width() - 100.0)
	vb.add_child(sl)
	hb.add_child(vb)
	add_note(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.2 if sl.text.find("\n") < 0 else 5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

## Width of a card in the notice column.
func note_width() -> float:
	return Game.safe_size().x - 16.0 if Game.tall else 356.0

## Puts a notice card (built by the caller, not yet in the tree) into the notice column.
func add_note(p: Control) -> void:
	_anchor_note(p)
	root.add_child(p)
	_notes.append(p)

func _anchor_note(p: Control) -> void:
	p.grow_vertical = Control.GROW_DIRECTION_END
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	if Game.tall:
		p.anchor_left = 0.0
		p.anchor_right = 1.0
		p.offset_left = 8
		p.offset_right = -8
	else:
		p.anchor_left = 1.0
		p.anchor_right = 1.0
		p.offset_left = -372
		p.offset_right = -16

## The selection card's offsets: both edges equal, so its height always follows its content.
func _place_info() -> void:
	if Game.tall:
		var y := _column_top() + _info_dy
		info.offset_top = y
		info.offset_bottom = y
	else:
		info.offset_top = -16.0 + _info_dy
		info.offset_bottom = -16.0 + _info_dy

## Top of the notice column: under the top bar (or the corner buttons), and under the boss bar
## when it is up and in the way.
func _column_top() -> float:
	var y := 66.0 if Game.tall else 90.0
	if boss_panel and boss_panel.visible:
		var br := boss_panel.get_rect()
		var vs := Game.safe_size()
		var col_x := 0.0 if Game.tall else vs.x - 372.0
		if br.end.x > col_x:
			y = maxf(y, br.end.y + 8.0)
	return y

## Stacks the notice column: each card eases to its slot, a new card drops in from just above.
func _layout_notes(k: float) -> void:
	var y := _column_top()
	if Game.tall and info.visible:
		y = info.offset_top - _info_dy + info.size.y + 8.0
	# on a wide screen the column runs down the right side towards the selection card in the
	# corner: a notice that would reach it waits (hidden) until one above it has gone
	var floor_y := INF
	if not Game.tall and info.visible:
		floor_y = info.get_global_rect().position.y - root.global_position.y - 8.0
	var keep: Array = []
	for n in _notes:
		if not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
			continue
		keep.append(n)
		var c := n as Control
		if not c.has_meta("slot"):
			c.set_meta("slot", true)
			c.offset_top = y - 20.0
		c.offset_top = lerpf(c.offset_top, y, k)
		c.offset_bottom = c.offset_top
		c.visible = y + c.size.y <= floor_y
		y += c.size.y + 8.0
	_notes = keep

## Screen rects the wave call buttons stay out of: the selection card, notices, boss bar, hint.
## The HUD panels a map-following button must not slip under: the top bar, the corner buttons,
## the hero and spell dock and the selection card.
func _panel_rects() -> Array:
	var out: Array = []
	for c in [top_panel, top_right, info]:
		if is_instance_valid(c) and (c as Control).is_visible_in_tree() and (c as Control).modulate.a > 0.05:
			out.append((c as Control).get_global_rect().grow(6.0))
	if is_instance_valid(dock) and dock.is_visible_in_tree():
		var d := Rect2()
		for ch in dock.get_children():
			var cc := ch as Control
			if cc and cc.visible:
				d = cc.get_global_rect() if d.size == Vector2.ZERO else d.merge(cc.get_global_rect())
		if d.size != Vector2.ZERO:
			out.append(d.grow(6.0))
	return out

func _keepout_rects() -> Array:
	var out: Array = []
	for c in [info, boss_panel, hint] + _notes:
		if is_instance_valid(c) and (c as Control).visible and (c as Control).modulate.a > 0.05:
			out.append((c as Control).get_global_rect().grow(6.0))
	return out

func set_speed(fast: bool) -> void:
	speed_b.icon = Assets.tex("speed2" if fast else "speed1")

## Desktop hotkeys (the HUD keeps processing while the tree is paused, so Esc can also resume).
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and LevelMain.I:
		if LevelMain.I.hotkey((ev as InputEventKey).keycode):
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)
	var k := clampf(rd * 14.0, 0.0, 1.0)
	if info:
		_info_dy = lerpf(_info_dy, 0.0, k) if absf(_info_dy) > 0.2 else 0.0
		_place_info()
		_layout_notes(k)
	if vignette:
		_vig_pulse = maxf(_vig_pulse - rd * 1.6, 0.0)
		var base := (0.28 + sin(Time.get_ticks_msec() * 0.004) * 0.1) if _low_lives else 0.0
		vignette.modulate.a = maxf(base, _vig_pulse * 0.8)
	if absf(_gold_shown - _gold_target) > 0.5:
		_gold_shown = lerpf(_gold_shown, _gold_target, clampf(rd * 10.0, 0.0, 1.0))
		if absf(_gold_shown - _gold_target) < 1.0:
			_gold_shown = _gold_target
		gold_l.text = str(int(round(_gold_shown)))

# ---------------------------------------------------------------- layout by orientation

## Wide screens keep the corner layout; an upright phone gets a slimmer top bar, smaller corner
## buttons, and the selection card across the width above the hero dock (not in a corner it
## would cover half of). Runs again when the phone is turned.
func _apply_layout() -> void:
	var t := Game.tall
	var vs := Game.safe_size()
	var fs := 22 if t else 28
	var isz := 28 if t else 36
	for it in _res_items:
		(it[0] as Control).custom_minimum_size = Vector2(isz, isz)
		(it[1] as Label).add_theme_font_size_override("font_size", fs)
		(it[1] as Label).add_theme_constant_override("outline_size", 5 if t else 7)
		(it[1] as Control).custom_minimum_size.x = float(it[2]) * (0.78 if t else 1.0)
	(top_panel.get_child(0) as HBoxContainer).add_theme_constant_override("separation", 8 if t else 14)
	top_panel.position = Vector2(8, 8) if t else Vector2(14, 12)
	top_panel.size = Vector2.ZERO
	var bs := 50 if t else 64
	for b in [speed_b, pause_b]:
		(b as Control).custom_minimum_size = Vector2(bs, bs)
		(b as Button).add_theme_constant_override("icon_max_width", int(bs * 0.78))
	top_right.add_theme_constant_override("separation", 6 if t else 10)
	top_right.offset_left = -(bs * 2 + (6 if t else 10) + (8 if t else 14))
	top_right.offset_right = -(8 if t else 14)
	top_right.offset_top = 8 if t else 12
	# selection card
	if t:
		# under the top bar, at the head of the notice column: the bottom of an upright screen
		# belongs to the hero dock and the wave buttons, and the thumb
		info.anchor_left = 0.0
		info.anchor_top = 0.0
		info.anchor_bottom = 0.0
		info.grow_vertical = Control.GROW_DIRECTION_END
		info.offset_left = 8
		info.offset_right = -8
		info_body.custom_minimum_size.x = vs.x - 60
		info_stats.custom_minimum_size.x = vs.x - 60
	else:
		info.anchor_left = 1.0
		info.anchor_top = 1.0
		info.anchor_bottom = 1.0
		info.grow_vertical = Control.GROW_DIRECTION_BEGIN
		info.offset_left = -372
		info.offset_right = -16
		info_body.custom_minimum_size.x = 320
		info_stats.custom_minimum_size.x = 320
	_place_info()
	for n in _notes:
		if is_instance_valid(n):
			_anchor_note(n)
	# wave banner and boss bar
	banner.add_theme_font_size_override("font_size", 40 if t else 50)
	banner_band.offset_top = 92 if t else 108
	banner_sub.add_theme_font_size_override("font_size", 19 if t else 22)
	var bw := minf(480.0, vs.x - 24.0)
	boss_panel.offset_left = -bw * 0.5
	boss_panel.offset_right = bw * 0.5
	boss_panel.offset_top = 70 if t else 84
	boss_bar.custom_minimum_size.x = bw - 40
	var hw := minf(480.0, vs.x - 24.0)
	hint.offset_left = -hw * 0.5
	hint.offset_right = hw * 0.5
	hint_l.custom_minimum_size.x = hw - 40
	hint.offset_bottom = -160 if t else -150
	target_hint.offset_left = -vs.x * 0.5 + 12
	target_hint.offset_right = vs.x * 0.5 - 12
	target_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_hint.add_theme_font_size_override("font_size", 21 if t else 26)
	set_wave(_wave_shown[0], _wave_shown[1])

# ---------------------------------------------------------------- wave call buttons

func set_wave_buttons(points: Array) -> void:
	for w in wave_btns:
		(w["node"] as Control).queue_free()
	wave_btns.clear()
	for p in points:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b := UI.icon_button(Assets.tex("wave_call"), 80, UI.NAVY, 40, "red")
		b.position = Vector2(-40, -40)
		b.pressed.connect(func(): wave_called.emit())
		holder.add_child(b)
		var ring := TextureProgressBar.new()
		ring.texture_progress = _circle_tex
		ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		ring.nine_patch_stretch = true
		ring.size = Vector2(66, 66)
		ring.position = Vector2(-33, -33)
		ring.max_value = 1.0
		ring.step = 0.001
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.tint_progress = Color(1, 1, 1, 0.6)
		holder.add_child(ring)
		# the call to action under the button: an or pennant tag with dark text, centred
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UI.plate(UI.GOLD, 5, Vector4(12, 1, 12, 3), 3.0, Color(UI.SABLE, 0.7), UI.CUT))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := UI.label("", 21, UI.SABLE, 0, "title_kr")
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(lab)
		tag.position = Vector2(-60, 40)
		tag.visible = false
		holder.add_child(tag)
		markers.add_child(holder)
		wave_btns.append({"node": holder, "pos": p, "ring": ring, "label": lab, "tag": tag, "button": b})

const DOCK_CLEAR := 272.0

func update_wave_buttons(cam: Camera3D, visible_flag: bool, progress: float, label: String, t: float) -> void:
	var vs := root.get_viewport_rect().size
	var sr := Game.safe_rect()  # buttons stay clear of a notch and the home indicator
	var lo := sr.position
	var hi := sr.end
	var keep := _keepout_rects() if visible_flag else []
	var dt := clampf(t - _wb_t, 0.0, 0.1) if _wb_t >= 0.0 else 0.0
	_wb_t = t
	var kk := clampf(maxf(dt, 0.016) * 12.0, 0.0, 1.0)
	# screen spots first: two portals off the same edge clamp to the same spot, so markers that
	# would overlap are spread apart (along the edge they sit on, else sideways)
	var spots: Array = []
	for w in wave_btns:
		var sp := cam.unproject_position(w["pos"])
		var at_edge := sp.x < lo.x + 70.0 or sp.x > hi.x - 70.0
		sp.x = clampf(sp.x, lo.x + 70, hi.x - 70)
		sp.y = clampf(sp.y, lo.y + 130, hi.y - 140)
		# keep clear of the hero/spell dock in the bottom-left corner (the marker's enemy preview
		# hangs 125 below its centre; the portrait and its level badge reach ~140 above the bottom)
		if sp.x < lo.x + 420.0 and sp.y > hi.y - DOCK_CLEAR:
			sp.y = hi.y - DOCK_CLEAR
		for _k in 3:
			var moved := false
			for o in spots:
				var op: Vector2 = o
				if absf(op.x - sp.x) < 140.0 and absf(op.y - sp.y) < 172.0:
					# beside the other marker: along the edge first (above, below), else sideways;
					# the first spot that stays on screen and off the bottom-left dock
					var tries: Array = [op + Vector2(0, -172), op + Vector2(0, 172), op + Vector2(150, 0), op + Vector2(-150, 0)]
					if not at_edge:
						tries = [tries[2], tries[3], tries[0], tries[1]]
					for c in tries:
						var cv: Vector2 = c
						var bottom := hi.y - (DOCK_CLEAR if cv.x < lo.x + 420.0 else 140.0)
						if cv.x >= lo.x + 70.0 and cv.x <= hi.x - 70.0 and cv.y >= lo.y + 130.0 and cv.y <= bottom:
							sp = cv
							break
					moved = true
			if not moved:
				break
		spots.append(sp)
	for wi in wave_btns.size():
		var w: Dictionary = wave_btns[wi]
		var n: Control = w["node"]
		n.visible = visible_flag
		if not visible_flag:
			continue
		var sp: Vector2 = spots[wi]
		# and step aside from the selection card and notices (below a card in the upper half,
		# above one in the lower half); the button with its label and preview spans -42..+125
		var dy := 0.0
		for _pass in 2:
			var fr := Rect2(sp.x - 70.0, sp.y + dy - 42.0, 140.0, 167.0)
			for r in keep:
				var rr: Rect2 = r
				if fr.intersects(rr):
					if rr.get_center().y < vs.y * 0.5:
						dy = rr.end.y + 44.0 - sp.y
					else:
						dy = rr.position.y - 127.0 - sp.y
					fr.position.y = sp.y + dy - 42.0
		var cur: float = w.get("dy", dy)
		w["dy"] = lerpf(cur, dy, kk) if absf(cur - dy) > 0.5 else dy
		n.position = sp + Vector2(0.0, w["dy"])
		var s := 1.0 + sin(t * 5.0) * 0.06
		n.scale = Vector2(s, s)
		(w["ring"] as TextureProgressBar).value = 1.0 - progress
		var lab := w["label"] as Label
		if lab.text != label:
			lab.text = label
			var tag := w["tag"] as Control
			tag.visible = label != ""
			tag.size = tag.get_combined_minimum_size()
			tag.position = Vector2(-tag.size.x * 0.5, 40)

# ---------------------------------------------------------------- menus

## A dialog over the battlefield (UI.sheet). Result screens pass a ribbon kind: their title sits on
## a ribbon (ResultFX slams it in); other dialogs get a plain header with a close button when
## `on_close` is given.
func modal(title: String, build_body: Callable, wide := 520, ribbon_kind := "", on_close := Callable()) -> Control:
	var shade := UI.sheet(root, title, {"width": wide + 40, "ribbon": ribbon_kind, "on_close": on_close})
	build_body.call(shade.get_meta("body"))
	return shade
