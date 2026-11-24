class_name Cinematics
extends CanvasLayer
## Level presentation: letterbox bars, title and boss cards, scripted camera moves, slow motion.
## Everything here runs on real time (tweens ignore Engine.time_scale), so slow motion never
## stretches the presentation itself. A tap skips the level intro and the boss introduction.

const BAR := 0.1

var lv: LevelMain
var root: Control
var active := ""
var _top: ColorRect
var _bot: ColorRect
var _catch: Control
var _card: Control
var _seq: Tween
var _skip: Callable
var _saved_target := Vector3.ZERO
var _saved_zoom := 30.0
var _boss: Enemy
## Cut timeline: advanced by real time but capped per frame, so a long frame (shader compile,
## a phone hiccup) pauses the cut instead of skipping through it.
var _t := 0.0
var _events: Array = []
var _update := Callable()

func _run(events: Array, update := Callable()) -> void:
	_t = 0.0
	_events = events
	_events.sort_custom(func(a, b): return a[0] < b[0])
	_update = update

func _stop_timeline() -> void:
	_events = []
	_update = Callable()

func _process(delta: float) -> void:
	if _events.is_empty() and not _update.is_valid():
		return
	_t += minf(delta / maxf(Engine.time_scale, 0.001), 0.1)
	if _update.is_valid():
		_update.call(_t)
	while not _events.is_empty() and _t >= float(_events[0][0]):
		var ev: Array = _events.pop_front()
		(ev[1] as Callable).call()

func setup(level: LevelMain) -> void:
	lv = level
	layer = 11
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_top = _bar(true)
	_bot = _bar(false)
	_catch = Control.new()
	_catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_catch.visible = false
	_catch.gui_input.connect(_on_catch)
	root.add_child(_catch)

func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.01, 0.01, 0.02, 0.94)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	root.add_child(r)
	return r

func _rt() -> Tween:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	return tw

func _letterbox(on: bool, t := 0.4) -> void:
	var tw := _rt().set_parallel(true)
	var tr := Tween.TRANS_CUBIC
	var ease := Tween.EASE_OUT if on else Tween.EASE_IN
	tw.tween_property(_top, "anchor_bottom", BAR if on else 0.0, t).set_trans(tr).set_ease(ease)
	tw.tween_property(_bot, "anchor_top", 1.0 - BAR if on else 1.0, t).set_trans(tr).set_ease(ease)

func _hud_visible(on: bool, t := 0.25) -> void:
	var tw := _rt()
	tw.tween_property(lv.hud.root, "modulate:a", 1.0 if on else 0.0, t)
	lv.hud.overlay.visible = on

## Enter a skippable cut: bars in, HUD out, camera input off, taps go to `skip`.
func _begin(kind: String, skip: Callable) -> void:
	active = kind
	_skip = skip
	_saved_target = lv.cam_rig.target
	_saved_zoom = lv.cam_rig.zoom
	lv.cam_rig.input_enabled = false
	lv.cam_rig.free = true
	lv._deselect()
	_catch.visible = true
	_letterbox(true)
	_hud_visible(false)

func _finish(immediate := false) -> void:
	active = ""
	_catch.visible = false
	lv.cam_rig.input_enabled = true
	lv.cam_rig.free = false
	if immediate:
		# no tweens: the tree may be about to pause (pause menu, app switch)
		_top.anchor_bottom = 0.0
		_bot.anchor_top = 1.0
		lv.hud.root.modulate.a = 1.0
		lv.hud.overlay.visible = true
		if _card and is_instance_valid(_card):
			_card.queue_free()
		_card = null
		return
	_letterbox(false)
	_hud_visible(true)
	_drop_card()

func skip() -> void:
	if _skip.is_valid():
		var cb := _skip
		_skip = Callable()
		cb.call()

func _on_catch(ev: InputEvent) -> void:
	var tap := (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if tap and _skip.is_valid():
		var cb := _skip
		_skip = Callable()
		cb.call()
		get_viewport().set_input_as_handled()

func _restore_time() -> void:
	if lv.state == "won" or lv.state == "lost":
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 2.0 if lv.fast else 1.0

func _cam_to(p: Vector3, zoom: float, t: float) -> Tween:
	var tw := _rt().set_parallel(true)
	tw.tween_property(lv.cam_rig, "target", Vector3(p.x, 0, p.z), t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lv.cam_rig, "zoom", zoom, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Stop whatever is running (victory / defeat / leaving the level).
func abort() -> void:
	if _seq and _seq.is_valid():
		_seq.kill()
	_seq = null
	_stop_timeline()
	if active != "":
		if is_instance_valid(_boss):
			_boss.stun_t = 0.0
		_boss = null
		_finish(true)
	_restore_time()

# ------------------------------------------------------------------ level intro

func _path_point(p: LanePath, d: float) -> Vector3:
	var s := p.sample(clampf(d, 0.0, p.length))
	return Vector3(s.x, 0, s.y)

## First visit: fly along the enemy road from the portal to the gate, then settle on the hero.
## Later visits keep the short zoom-in.
func level_intro(full: bool) -> void:
	var def: Dictionary = lv.def
	var hs: Array = def["hero_start"]
	var home := Vector3(hs[0], 0, hs[1])
	var cr := lv.cam_rig
	if not full or lv.paths.is_empty():
		cr.zoom = 40.0
		cr.focus(home)
		cr._pos = cr.target
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_property(cr, "zoom", 30.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lv.hud.show_banner(def["name"], def["subtitle"])
		return
	var p: LanePath = lv.paths[0]
	_begin("intro", func(): _end_intro(home))
	_saved_target = home
	cr.zoom = 21.0
	cr.target = _path_point(p, 1.5)
	cr._pos = cr.target
	var region := tr("제 %d 지역") % (lv.level_idx + 1)
	_show_title(region, tr(def["name"]), tr(def["subtitle"]))
	var dur := clampf(p.length / 13.0, 2.8, 4.4)
	var t0 := 0.35
	var gate := _path_point(p, p.length - 2.0)
	_run([[t0 + dur, func(): _drop_card()], [t0 + dur + 1.15, func(): _end_intro(home)]], func(t: float):
		if t < t0 + dur:
			var k := smoothstep(0.0, 1.0, clampf((t - t0) / dur, 0.0, 1.0))
			cr.target = _path_point(p, lerpf(1.5, p.length - 2.0, k))
			cr.zoom = lerpf(21.0, 26.0, k)
		else:
			var k2 := smoothstep(0.0, 1.0, clampf((t - t0 - dur) / 1.1, 0.0, 1.0))
			cr.target = gate.lerp(home, k2)
			cr.zoom = lerpf(26.0, 30.0, k2))

func _end_intro(home: Vector3) -> void:
	if active != "intro":
		return
	_stop_timeline()
	_cam_to(home, 30.0, 0.45)
	_finish()

func _show_title(kicker: String, title: String, sub: String) -> void:
	_drop_card()
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.16
	box.anchor_bottom = 0.16
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 2)
	var krow := HBoxContainer.new()
	krow.alignment = BoxContainer.ALIGNMENT_CENTER
	krow.add_theme_constant_override("separation", 14)
	krow.add_child(_rule(true))
	var k := UI.label(kicker, 22, UI.GOLD, 5, "ui_black")
	krow.add_child(k)
	krow.add_child(_rule(false))
	box.add_child(krow)
	var t := UI.title(title, 66, "title_kr", 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(t)
	var s := UI.label(sub, 25, UI.TEXT, 7, "ui_black")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	root.add_child(box)
	root.move_child(box, _catch.get_index())
	_card = box
	box.modulate.a = 0.0
	box.pivot_offset = Vector2(640, 60)
	box.scale = Vector2(1.08, 1.08)
	var tw := _rt().set_parallel(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.6).set_delay(0.25)
	tw.tween_property(box, "scale", Vector2.ONE, 1.4).set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _rule(left: bool) -> Control:
	var tr2 := TextureRect.new()
	var g := Gradient.new()
	var gold := Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.9)
	g.set_color(0, Color(gold.r, gold.g, gold.b, 0.0) if left else gold)
	g.set_color(1, gold if left else Color(gold.r, gold.g, gold.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 3
	tr2.texture = gt
	tr2.stretch_mode = TextureRect.STRETCH_SCALE
	tr2.custom_minimum_size = Vector2(120, 3)
	tr2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr2

func _drop_card() -> void:
	if _card and is_instance_valid(_card):
		var c := _card
		_card = null
		var tw := _rt()
		tw.tween_property(c, "modulate:a", 0.0, 0.35)
		tw.tween_callback(c.queue_free)

# ------------------------------------------------------------------ story

var _story_lines: Array = []
var _story_i := -1
var _story_then := Callable()
var _story_chain := false
var _story_panel: Control
var _story_text: Label
var _story_tw: Tween
var _typing := false

## Short dialogue: portrait + name + typed line. Tap shows the whole line, then the next one;
## the skip button ends it. With chain=true the letterbox stays up for a following cut.
func story(lines: Array, then: Callable, chain := false) -> void:
	if lines.is_empty():
		then.call()
		return
	_story_lines = lines
	_story_i = -1
	_story_then = then
	_story_chain = chain
	_begin("story", Callable())
	_story_next()

func _speaker(id: String) -> Array:
	if id == "hero":
		var h: Dictionary = DB.hero_def()
		return [h["name"], h["portrait"], false]
	if id == "captain":
		return [DB.CAPTAIN["name"], DB.CAPTAIN["portrait"], false]
	if DB.ENEMIES.has(id):
		return [DB.ENEMIES[id]["name"], "portrait_" + id, true]
	return [id, "", false]

func _story_next() -> void:
	if _typing and _story_text:
		if _story_tw and _story_tw.is_valid():
			_story_tw.kill()
		_story_text.visible_ratio = 1.0
		_typing = false
		_skip = func(): _story_next()
		return
	_story_i += 1
	if _story_i >= _story_lines.size():
		_end_story()
		return
	var line: Array = _story_lines[_story_i]
	var sp := _speaker(String(line[0]))
	if _story_panel and is_instance_valid(_story_panel):
		_story_panel.queue_free()
	var panel := UI.framed("parch", 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0 - BAR
	panel.anchor_bottom = 1.0 - BAR
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_bottom = -14
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hb)
	var por := UI.icon(Assets.tex(sp[1]), 118)
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var enemy: bool = sp[2]
	vb.add_child(UI.ink(tr(sp[0]), 22, Color(0.62, 0.14, 0.08) if enemy else Color(0.18, 0.3, 0.55), "ui_black"))
	_story_text = UI.ink(tr(String(line[1])), 21, UI.INK)
	UI.wrap_words(_story_text, 610.0)
	_story_text.custom_minimum_size = Vector2(610, 64)
	vb.add_child(_story_text)
	var more := UI.ink("탭하여 계속  ▶", 14, UI.INK_SOFT)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(more)
	if enemy:
		hb.add_child(vb)
		hb.add_child(por)
	else:
		hb.add_child(por)
		hb.add_child(vb)
	root.add_child(panel)
	root.move_child(panel, _catch.get_index())
	_story_panel = panel
	if _story_i == 0:
		var sk := UI.button("건너뛰기  ▶▶", 17, false, Vector2(170, 46), "gray")
		sk.anchor_left = 1.0
		sk.anchor_right = 1.0
		sk.offset_left = -190
		sk.offset_right = -20
		sk.offset_top = 16
		sk.name = "StorySkip"
		sk.pressed.connect(func():
			_story_i = _story_lines.size()
			_typing = false
			_end_story())
		root.add_child(sk)
	panel.modulate.a = 0.0
	var ft := _rt()
	ft.tween_property(panel, "modulate:a", 1.0, 0.2)
	_story_text.visible_ratio = 0.0
	_typing = true
	_story_tw = _rt()
	_story_tw.tween_property(_story_text, "visible_ratio", 1.0, clampf(_story_text.text.length() * 0.03, 0.4, 2.6))
	_story_tw.tween_callback(func(): _typing = false)
	Audio.play("click", -10.0, 0.05)
	_skip = func(): _story_next()

func _end_story() -> void:
	if active != "story":
		return
	if _story_panel and is_instance_valid(_story_panel):
		_story_panel.queue_free()
	_story_panel = null
	var sk := root.get_node_or_null("StorySkip")
	if sk:
		sk.queue_free()
	var then := _story_then
	_story_then = Callable()
	if _story_chain:
		# the next cut keeps the bars and the hidden HUD
		active = ""
		_skip = Callable()
	else:
		_finish()
	if then.is_valid():
		then.call()

# ------------------------------------------------------------------ bosses

## The boss steps onto the field: the world slows to a crawl, the camera finds the boss,
## it roars / taunts while its name card slides in, then everything returns to play.
var _introduced := {}

func boss_intro(e: Enemy) -> bool:
	# once per boss type per visit (endless mode brings bosses back every ten waves)
	if active != "" or lv.state == "won" or lv.state == "lost" or Game.testing or _introduced.has(e.type):
		return false
	_introduced[e.type] = true
	_boss = e
	_begin("boss", func(): _end_boss())
	var slow := 0.15
	e.stun_t = 99.0
	# stride out of the portal first so the camera has something to look at
	var d0 := e.dist
	var d1 := minf(e.dist + 5.0 + e.radius * 2.0, e.path.length * 0.3)
	_cam_to(_path_point(e.path, d1), 17.0, 0.7)
	if e.model.has("run"):
		e.model.play("run", 1.0, 0.1)
	var clip := "taunt" if e.model.has("taunt") else ("roar" if e.model.has("roar") else "")
	_run([
		[0.7, func():
			Engine.time_scale = slow
			if is_instance_valid(e) and clip != "":
				e.model.play(clip, 1.15 / slow, 0.15, true)
			Audio.play("boss_intro", 0.0, 0.0)
			Audio.play("boss_roar", 1.0, 0.0)
			lv.cam_rig.shake(0.5)
			Game.vibrate(120)],
		[1.0, func(): _boss_card(e)],
		[3.4, func(): _end_boss()],
	], func(t: float):
		if t <= 0.72 and is_instance_valid(e):
			e.dist = lerpf(d0, d1, smoothstep(0.0, 1.0, clampf(t / 0.7, 0.0, 1.0)))
			e._update_transform(0.016))
	return true

func _end_boss() -> void:
	if active != "boss":
		return
	_stop_timeline()
	if is_instance_valid(_boss):
		_boss.stun_t = 0.0
	_boss = null
	_cam_to(_saved_target, _saved_zoom, 0.55)
	_restore_time()
	_finish()

func _boss_card(e: Enemy) -> void:
	_drop_card()
	var d: Dictionary = e.d
	var band := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.02, 0.02, 0.0))
	g.set_color(1, Color(0.25, 0.02, 0.02, 0.0))
	g.add_point(0.25, Color(0.16, 0.01, 0.02, 0.88))
	g.add_point(0.75, Color(0.16, 0.01, 0.02, 0.88))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	band.texture = gt
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.6
	band.anchor_bottom = 0.6
	band.offset_top = -78
	band.offset_bottom = 78
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 22)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var por := UI.icon(Assets.tex("portrait_" + e.type), 140)
	hb.add_child(por)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(UI.label("보스", 20, Color(1.0, 0.55, 0.42), 5, "ui_black"))
	var nm := UI.title(tr(d["name"]), 54, "title_kr", 12)
	nm.add_theme_color_override("font_color", Color(1.0, 0.86, 0.78))
	vb.add_child(nm)
	if d.has("title"):
		vb.add_child(UI.label(tr(d["title"]), 23, UI.TEXT, 6, "ui_black"))
	hb.add_child(vb)
	band.add_child(hb)
	root.add_child(band)
	root.move_child(band, _catch.get_index())
	_card = band
	band.modulate.a = 0.0
	hb.position.x = -140.0
	var tw := _rt().set_parallel(true)
	tw.tween_property(band, "modulate:a", 1.0, 0.3)
	tw.tween_property(hb, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(hb, "position:x", 24.0, 2.4).set_delay(0.5)

## A boss falls: brief slow motion and a flash on the spot; the camera does not move away.
func boss_down(e: Enemy) -> void:
	if Game.testing:
		return
	var p := e.aim_point()
	lv.fx.light_flash(p, Color(1.0, 0.85, 0.6), 7.0, 14.0, 0.6)
	lv.fx.shockwave(e.global_position, 7.0, Color(1.0, 0.8, 0.5))
	lv.fx.explosion(p, 1.6)
	lv.fx.magic_burst(p, Color(1.0, 0.85, 0.5), 2.0)
	lv.cam_rig.shake(1.0)
	Audio.play("boom", 2.0, 0.0, 2)
	Game.vibrate(200)
	lv.hud.show_banner("보스 처치!", tr(e.d["name"]), Color(1.0, 0.85, 0.45))
	if active != "":
		return
	active = "slowmo"
	Engine.time_scale = 0.25
	_run([[1.2, func():
		active = ""
		_restore_time()]])

# ------------------------------------------------------------------ endings

## Lost: the world drains of colour in slow motion before the defeat card.
func defeat(env: Environment, then: Callable) -> void:
	abort()
	if Game.testing:
		then.call()
		return
	Engine.time_scale = 0.3
	_letterbox(true, 0.6)
	lv.cam_rig.shake(0.8)
	var tw := _rt().set_parallel(true)
	if env:
		tw.tween_property(env, "adjustment_saturation", 0.12, 1.3)
		tw.tween_property(env, "adjustment_brightness", 0.8, 1.3)
	tw.chain().tween_callback(func():
		Engine.time_scale = 1.0
		_letterbox(false, 0.3)
		then.call())

## Won: fireworks over the gate while the defenders cheer.
func victory_fireworks(at: Vector3) -> void:
	var cols := [Color(1.0, 0.82, 0.35), Color(0.5, 0.85, 1.0), Color(1.0, 0.45, 0.6), Color(0.6, 1.0, 0.55)]
	for i in 7:
		var tw := _rt()
		tw.tween_interval(0.25 + i * 0.32 + randf() * 0.12)
		tw.tween_callback(func():
			var off := Vector3(randf_range(-6, 6), randf_range(5.0, 8.0), randf_range(-4.5, 1.5))
			lv.fx.firework(at + off, cols[i % cols.size()])
			if i % 2 == 0:
				Audio.play("boom", -14.0, 0.3, 2))
