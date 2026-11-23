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

func _make_circle(sz: int) -> Texture2D:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz, sz) * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(sz * 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, 0.62 * a))
	return ImageTexture.create_from_image(img)

func _res_item(icon: String, txt: String, col: Color) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(UI.icon(Assets.tex(icon), 34))
	var l := UI.label(txt, 28, col, 7)
	l.custom_minimum_size.x = 54
	hb.add_child(l)
	return [hb, l]

func _build_top() -> void:
	var p := UI.panel(Color(0.06, 0.07, 0.12, 0.85), UI.GOLD_DARK, 18)
	p.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.07, 0.12, 0.85), UI.GOLD_DARK, 18, 3, 6, 10))
	p.position = Vector2(14, 12)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	var a := _res_item("heart", "20", Color(1.0, 0.55, 0.5))
	lives_l = a[1]
	hb.add_child(a[0])
	var b := _res_item("coin", "0", UI.GOLD)
	gold_l = b[1]
	hb.add_child(b[0])
	var c := _res_item("skull", "웨이브 0/0", UI.TEXT)
	wave_l = c[1]
	wave_l.custom_minimum_size.x = 120
	hb.add_child(c[0])
	p.add_child(hb)
	root.add_child(p)

	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-160, 12)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speed_b = UI.icon_button(Assets.tex("speed1"), 66)
	speed_b.pressed.connect(func(): speed_toggled.emit())
	pause_b = UI.icon_button(Assets.tex("pause"), 66)
	pause_b.pressed.connect(func(): pause_pressed.emit())
	tr.add_child(speed_b)
	tr.add_child(pause_b)
	root.add_child(tr)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -152
	tr.offset_right = -14

func _cooldown_overlay(parent: Control, sz: int) -> TextureProgressBar:
	var t := TextureProgressBar.new()
	t.texture_progress = _circle_tex
	t.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	t.nine_patch_stretch = true
	t.size = Vector2(sz, sz)
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
	bl.offset_top = -120
	bl.offset_left = 14
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)
	# hero portrait
	hero_b = UI.icon_button(Assets.tex(DB.hero_def()["portrait"]), 96, Color(0.3, 0.12, 0.1, 0.95), 48)
	hero_b.add_theme_constant_override("icon_max_width", 88)
	hero_b.position = Vector2(0, 8)
	hero_b.pressed.connect(func(): hero_pressed.emit())
	bl.add_child(hero_b)
	hero_hp = _mini_bar(Color(0.35, 0.9, 0.35))
	hero_hp.position = Vector2(6, 104)
	hero_hp.size = Vector2(84, 9)
	bl.add_child(hero_hp)
	hero_xp = _mini_bar(Color(0.95, 0.78, 0.3))
	hero_xp.position = Vector2(6, 112)
	hero_xp.size = Vector2(84, 5)
	bl.add_child(hero_xp)
	hero_lv = UI.label("1", 22, UI.GOLD, 6)
	var lvp := UI.panel(Color(0.12, 0.08, 0.05, 0.95), UI.GOLD, 16)
	lvp.add_theme_stylebox_override("panel", UI.box(Color(0.12, 0.08, 0.05, 0.95), UI.GOLD, 16, 2, 3, 2))
	lvp.add_child(hero_lv)
	hero_lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvp.custom_minimum_size = Vector2(32, 32)
	lvp.position = Vector2(70, 0)
	lvp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(lvp)
	hero_dead = UI.label("", 30, Color(1, 0.6, 0.5), 7)
	hero_dead.position = Vector2(30, 36)
	hero_dead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(hero_dead)
	# skill
	skill_b = UI.icon_button(Assets.tex(DB.hero_def()["skill_icon"]), 66, Color(0.35, 0.15, 0.08, 0.95), 33)
	skill_b.position = Vector2(108, 38)
	skill_b.pressed.connect(func(): skill_pressed.emit())
	bl.add_child(skill_b)
	skill_cd = _cooldown_overlay(skill_b, 66)
	# spells
	var x := 196
	for id in ["meteor", "reinforce"]:
		var sb := UI.icon_button(Assets.tex("spell_" + id), 84, Color(0.16, 0.12, 0.3, 0.95), 42)
		sb.position = Vector2(x, 22)
		sb.pressed.connect(func(): spell_pressed.emit(id))
		bl.add_child(sb)
		var ov := _cooldown_overlay(sb, 84)
		var cl := UI.label("", 24, UI.TEXT, 6)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.size = Vector2(84, 84)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sb.add_child(cl)
		spell_btns[id] = {"button": sb, "cd": ov, "label": cl}
		x += 96
	target_hint = UI.label("", 26, UI.GOLD, 8)
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

func _build_info() -> void:
	info = UI.panel(Color(0.06, 0.07, 0.12, 0.92), UI.GOLD_DARK, 14)
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = -360
	info.offset_right = -14
	info.offset_top = -14
	info.offset_bottom = -14
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	info_title = UI.label("", 26, UI.GOLD, 6)
	info_body = UI.label("", 19, UI.TEXT, 4)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size.x = 320
	vb.add_child(info_title)
	vb.add_child(info_body)
	info.add_child(vb)
	info.visible = false
	root.add_child(info)

func show_info(title: String, body: String) -> void:
	info_title.text = title
	info_body.text = body
	info.visible = true
	info.modulate.a = 0.0
	info.create_tween().tween_property(info, "modulate:a", 1.0, 0.15)

func hide_info() -> void:
	info.visible = false

func _build_banner() -> void:
	banner = UI.label("", 54, UI.GOLD, 12, "title")
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_top = 120
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	root.add_child(banner)
	banner_sub = UI.label("", 26, UI.TEXT, 7)
	banner_sub.anchor_left = 0.0
	banner_sub.anchor_right = 1.0
	banner_sub.offset_top = 190
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_sub.modulate.a = 0.0
	root.add_child(banner_sub)
	hint = UI.panel(Color(0.96, 0.9, 0.74, 0.96), UI.GOLD_DARK, 14)
	hint.add_theme_stylebox_override("panel", UI.box(Color(0.96, 0.9, 0.74, 0.96), UI.GOLD_DARK, 14, 3, 8, 14))
	hint_l = UI.label("", 22, Color(0.2, 0.13, 0.08), 0)
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_l.custom_minimum_size.x = 420
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_l)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -230
	hint.offset_right = 230
	hint.offset_top = 96
	hint.visible = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

func show_banner(title: String, sub := "", col := UI.GOLD) -> void:
	banner.text = title
	banner.add_theme_color_override("font_color", col)
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
	boss_panel = UI.panel(Color(0.08, 0.05, 0.06, 0.9), Color(0.75, 0.25, 0.2), 14)
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.offset_left = -230
	boss_panel.offset_right = 230
	boss_panel.offset_top = 86
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	boss_panel.add_child(vb)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(UI.icon(Assets.tex("crown"), 28))
	boss_name = UI.label("", 20, Color(1.0, 0.75, 0.6), 5)
	hb.add_child(boss_name)
	vb.add_child(hb)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(430, 16)
	boss_bar.max_value = 1.0
	boss_bar.step = 0.001
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.05, 0.05)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.9, 0.2, 0.15)
	fg.set_corner_radius_all(6)
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fg)
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
	boss_name.text = "  " + name_txt
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

func flash_damage(low: bool) -> void:
	_vig_pulse = 1.0
	_low_lives = low

## Small enemy icons + counts beside each portal's wave button, previewing the next wave.
func set_wave_preview(per_path: Array) -> void:
	for i in wave_btns.size():
		var w: Dictionary = wave_btns[i]
		var row: HBoxContainer = w.get("preview")
		if row == null:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.position = Vector2(-80, 66)
			row.size = Vector2(160, 40)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			(w["node"] as Control).add_child(row)
			w["preview"] = row
		for c in row.get_children():
			c.queue_free()
		var counts: Dictionary = per_path[i] if i < per_path.size() else {}
		for k in counts:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", -6)
			cell.custom_minimum_size = Vector2(40, 0)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic := UI.icon(Assets.tex("portrait_" + k), 34)
			cell.add_child(ic)
			var l := UI.label("x%d" % counts[k], 15, UI.TEXT, 4)
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

func set_wave(cur: int, total: int) -> void:
	wave_l.text = ("웨이브 %d/%d" % [cur, total]) if total > 0 else ("웨이브 %d/∞" % cur)

var _toasts := 0

## Small slide-in notification (achievements).
func toast(title: String, sub: String, icon: String) -> void:
	var p := UI.panel(Color(0.1, 0.09, 0.05, 0.95), UI.GOLD, 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	hb.add_child(UI.icon(Assets.tex(icon), 52))
	var vb := VBoxContainer.new()
	vb.add_child(UI.label(title, 22, UI.GOLD, 5))
	vb.add_child(UI.label(sub, 17, UI.TEXT, 3))
	hb.add_child(vb)
	root.add_child(p)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -200
	p.offset_right = 200
	var y := 150.0 + _toasts * 86.0
	_toasts += 1
	p.offset_top = y - 30
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(p, "offset_top", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		_toasts = maxi(_toasts - 1, 0)
		p.queue_free())

func set_speed(fast: bool) -> void:
	speed_b.icon = Assets.tex("speed2" if fast else "speed1")

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

# ---------------------------------------------------------------- wave call buttons

func set_wave_buttons(points: Array) -> void:
	for w in wave_btns:
		(w["node"] as Control).queue_free()
	wave_btns.clear()
	for p in points:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b := UI.icon_button(Assets.tex("wave_call"), 78, Color(0.45, 0.1, 0.08, 0.95), 39)
		b.position = Vector2(-39, -39)
		b.pressed.connect(func(): wave_called.emit())
		holder.add_child(b)
		var ring := TextureProgressBar.new()
		ring.texture_progress = _circle_tex
		ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		ring.nine_patch_stretch = true
		ring.size = Vector2(78, 78)
		ring.position = Vector2(-39, -39)
		ring.max_value = 1.0
		ring.step = 0.001
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.tint_progress = Color(1, 1, 1, 0.6)
		holder.add_child(ring)
		var lab := UI.label("", 20, UI.GOLD, 5)
		lab.position = Vector2(-60, 40)
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

func modal(title: String, build_body: Callable, wide := 520) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := UI.panel(Color(0.07, 0.08, 0.14, 0.97), UI.GOLD, 22)
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.08, 0.14, 0.97), UI.GOLD, 22, 4, 16, 26))
	p.custom_minimum_size = Vector2(wide, 0)
	center.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var t := UI.label(title, 44, UI.GOLD, 10, "title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	build_body.call(vb)
	shade.modulate.a = 0.0
	shade.create_tween().tween_property(shade, "modulate:a", 1.0, 0.2)
	(func(): UI.pop_in(p)).call_deferred()
	return shade
