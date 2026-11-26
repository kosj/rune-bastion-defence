class_name HUD
extends CanvasLayer
## In-game HUD: resources, wave call buttons, hero & spell buttons, info panel, banners, menus.

signal speed_toggled
signal pause_pressed
signal hero_pressed
signal skill_pressed
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
var spell_btns := {}
var wave_btns: Array = []
var info: PanelContainer
var info_title: Label
var info_body: Label
var banner: Label
var banner_sub: Label
var hint: PanelContainer
var hint_l: Label
var radial: RadialMenu
var overlay: Overlay
var target_hint: Label
var _circle_tex: Texture2D
var boss_panel: PanelContainer
var boss_bar: ProgressBar
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
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	radial = RadialMenu.new()
	radial.cam = cam
	root.add_child(radial)
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
	c.color = Color(1, 1, 1, 0.14)
	c.custom_minimum_size = Vector2(1, 26)
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
		info.visible = true
		info.modulate.a = 0.0
		info.position.y += 16
		var tw := info.create_tween().set_parallel(true)
		tw.set_ignore_time_scale(true)
		tw.tween_property(info, "modulate:a", 1.0, 0.15)
		tw.tween_property(info, "position:y", info.position.y - 16, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_info() -> void:
	info.visible = false

func _build_banner() -> void:
	banner = UI.title("", 58, "title_kr", 12)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_top = 112
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	root.add_child(banner)
	banner_sub = UI.label("", 26, UI.TEXT, 7, "ui_black")
	banner_sub.anchor_left = 0.0
	banner_sub.anchor_right = 1.0
	banner_sub.offset_top = 190
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_sub.modulate.a = 0.0
	root.add_child(banner_sub)
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
	banner.text = title
	# gold gradient for normal announcements; other colours (boss / danger) drop the gradient
	var gold := col == UI.GOLD
	banner.add_theme_color_override("font_color", Color.WHITE if gold else col)
	banner_sub.text = sub
	for l in [banner, banner_sub]:
		var tw := (l as Control).create_tween()
		(l as Control).pivot_offset = (l as Control).size * 0.5
		(l as Control).scale = Vector2(1.4, 1.4)
		tw.set_parallel(true)
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(1.8)
		tw.chain().tween_property(l, "modulate:a", 0.0, 0.5)

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
	var target := gold_l.get_global_rect().position + Vector2(-26, gold_l.size.y * 0.5)
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

var _toasts := 0

## Small slide-in notification (achievements).
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
	UI.wrap_words(sl, 400.0)
	vb.add_child(sl)
	hb.add_child(vb)
	root.add_child(p)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -200
	p.offset_right = 200
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var y := 150.0 + _toasts * 98.0
	_toasts += 1
	p.offset_top = y - 30
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(p, "offset_top", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2 if sl.text.find("\n") < 0 else 5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		_toasts = maxi(_toasts - 1, 0)
		p.queue_free())

func set_speed(fast: bool) -> void:
	speed_b.icon = Assets.tex("speed2" if fast else "speed1")

## Desktop hotkeys (the HUD keeps processing while the tree is paused, so Esc can also resume).
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and LevelMain.I:
		if LevelMain.I.hotkey((ev as InputEventKey).keycode):
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)
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
	var vs := root.get_viewport_rect().size
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
		# under the top bar: the bottom of an upright screen belongs to the hero dock and the
		# wave buttons, and the thumb
		info.anchor_left = 0.0
		info.anchor_top = 0.0
		info.anchor_bottom = 0.0
		info.grow_vertical = Control.GROW_DIRECTION_END
		info.offset_left = 8
		info.offset_right = -8
		info.offset_top = 66
		info.offset_bottom = 66
		info_body.custom_minimum_size.x = vs.x - 60
		info_stats.custom_minimum_size.x = vs.x - 60
	else:
		info.anchor_left = 1.0
		info.anchor_top = 1.0
		info.anchor_bottom = 1.0
		info.grow_vertical = Control.GROW_DIRECTION_BEGIN
		info.offset_left = -372
		info.offset_right = -16
		info.offset_top = -16
		info.offset_bottom = -16
		info_body.custom_minimum_size.x = 320
		info_stats.custom_minimum_size.x = 320
	# wave banner and boss bar
	banner.add_theme_font_size_override("font_size", 44 if t else 58)
	banner.offset_top = 96 if t else 112
	banner_sub.add_theme_font_size_override("font_size", 21 if t else 26)
	banner_sub.offset_top = 156 if t else 190
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
		var lab := UI.label("", 21, UI.GOLD, 6, "ui_black")
		lab.position = Vector2(-60, 38)
		lab.size = Vector2(120, 30)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lab)
		root.add_child(holder)
		wave_btns.append({"node": holder, "pos": p, "ring": ring, "label": lab, "button": b})

func update_wave_buttons(cam: Camera3D, visible_flag: bool, progress: float, label: String, t: float) -> void:
	var vs := root.get_viewport_rect().size
	for w in wave_btns:
		var n: Control = w["node"]
		n.visible = visible_flag
		if not visible_flag:
			continue
		var sp := cam.unproject_position(w["pos"])
		sp.x = clampf(sp.x, 70, vs.x - 70)
		sp.y = clampf(sp.y, 130, vs.y - 140)
		# keep clear of the hero/spell dock in the bottom-left corner
		if sp.x < 420.0 and sp.y > vs.y - 250.0:
			sp.y = vs.y - 250.0
		n.position = sp
		var s := 1.0 + sin(t * 5.0) * 0.06
		n.scale = Vector2(s, s)
		(w["ring"] as TextureProgressBar).value = 1.0 - progress
		(w["label"] as Label).text = label

# ---------------------------------------------------------------- menus

## A dialog over the battlefield (UI.sheet). Result screens pass a ribbon kind: their title sits on
## a ribbon (ResultFX slams it in); other dialogs get a plain header with a close button when
## `on_close` is given.
func modal(title: String, build_body: Callable, wide := 520, ribbon_kind := "", on_close := Callable()) -> Control:
	var shade := UI.sheet(root, title, {"width": wide + 40, "ribbon": ribbon_kind, "on_close": on_close})
	build_body.call(shade.get_meta("body"))
	return shade
