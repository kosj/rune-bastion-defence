extends Node3D
## Title screen with an animated 3D diorama, level select and settings.

var cam: Camera3D
var _t := 0.0
var ui: Control
var _select: Control
var _hero: CharacterModel
var _troll: CharacterModel

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_viewport().disable_3d = false
	Game.mark("menu_build_start")
	_build_ui()
	Audio.play_music("menu")
	if Content.has_all(_title_needs()):
		_world_started = true
		_build_world()
		Game.mark("menu_world_built")
	else:
		# web, first moments: the 3D models are still downloading (Content). Show the diorama as a
		# pre-rendered picture of the opening camera pose and cross-fade to the live scene once it is
		# built (tools/render_backdrops.sh renders the pictures).
		_show_backdrop()
	Content.chunk_ready.connect(_on_chunk_ready)
	Game.mark("menu_built")
	await get_tree().process_frame
	await get_tree().process_frame
	Game.mark("menu_first_frame")

var _backdrop: TextureRect
var _async_build := false
var _world_started := false
var TITLE_3D: Array = PackChunks.DATA["title_3d_needs"]

func _backdrop_tex() -> Texture2D:
	var p := "res://assets/ui/backdrop/menu_%s.jpg" % DB.hero_def()["model"]
	if not Content.allows(p):
		p = "res://assets/ui/backdrop/menu_hero.jpg"  # in core; the others come with the menu chunk
	return Assets.tex_path(p)

func _on_chunk_ready(_chunk: String) -> void:
	if _backdrop and _backdrop.texture != _backdrop_tex():
		_backdrop.texture = _backdrop_tex()
	if not _world_started and Content.has_all(_title_needs()):
		_world_started = true
		_on_content_ready()
	elif _hero and _hero_pending:
		_show_hero()

## The 3D title needs its chunks plus the chosen hero's (the other heroes come with "world").
func _title_needs() -> Array:
	var need := TITLE_3D.duplicate()
	need.append(PackChunks.chunk_of(Assets.CHAR_DIR + DB.hero_def()["model"] + ".glb"))
	return need

var _hero_pending := false

## Dress the title hero as the chosen one, once that hero's chunk is in.
func _show_hero() -> void:
	var hd := DB.hero_def()
	_hero_pending = not Content.allows(Assets.CHAR_DIR + hd["model"] + ".glb")
	if _hero_pending:
		return
	_hero.setup(hd["model"], hd["scale"], Color.WHITE, hd["weapon"])
	_hero.play("idle")

## Menu screens show pictures of the menu chunk: wait for it (only in the first seconds of a
## first visit on the web).
func _need_menu() -> bool:
	return await Content.ensure(["menu"])

func _show_backdrop() -> void:
	var tex := _backdrop_tex()
	if tex == null:
		return
	_backdrop = TextureRect.new()
	_backdrop.texture = tex
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# the camera keeps its vertical field of view, so a centred, height-filling crop of the wide
	# picture is exactly what the live camera sees at any aspect up to 2.4:1
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_backdrop)
	ui.move_child(_backdrop, 0)

func _on_content_ready() -> void:
	if Game._busy or not is_inside_tree():
		return  # already on the way into a battle (the content arrived behind its wait card)
	# build in small steps (one new model per frame) so the menu stays responsive meanwhile
	_async_build = true
	await _build_world()
	_async_build = false
	if not is_inside_tree() or Game._busy:
		return
	Game.mark("menu_world_built")
	# the world map covers the screen with 3D switched off; wait until the diorama is on screen
	while is_inside_tree() and get_viewport().disable_3d:
		await get_tree().process_frame
	# first frames compile the new materials and upload the textures, still under the picture
	for i in 3:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_t = 0.0
	if _backdrop:
		var tw := create_tween()
		tw.tween_property(_backdrop, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_backdrop.queue_free)
		_backdrop = null

## Async build: wait a frame; false when the menu is being left (stop building).
func _step() -> bool:
	if not _async_build:
		return true
	if Game._busy or not is_inside_tree():
		return false
	await get_tree().process_frame
	return is_inside_tree() and not Game._busy

func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.3, 0.6)
	sm.sky_horizon_color = Color(1.0, 0.72, 0.5)
	sm.ground_horizon_color = Color(0.6, 0.45, 0.4)
	sm.ground_bottom_color = Color(0.15, 0.12, 0.14)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0
	env.tonemap_exposure = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.7, 0.55)
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-32, 28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40
	add_child(sun)
	# ground island
	var ground := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 16
	cm.bottom_radius = 13
	cm.height = 2.0
	cm.radial_segments = 48
	ground.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = Assets.tex_path("res://assets/textures/terrain_grass.png")
	gm.uv1_triplanar = true
	gm.uv1_scale = Vector3(0.2, 0.2, 0.2)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -1.0
	add_child(ground)
	var path := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.4, 30)
	path.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = Assets.tex_path("res://assets/textures/terrain_dirt.png")
	pmat.uv1_triplanar = true
	pmat.uv1_scale = Vector3(0.22, 0.22, 0.22)
	pmat.roughness = 1.0
	path.material_override = pmat
	path.position = Vector3(0, 0.01, 2)
	path.rotation_degrees.y = 20
	add_child(path)
	if not await _step(): return
	var castle := Assets.instance("castle")
	castle.position = Vector3(-2.0, 0, -9)
	castle.rotation_degrees.y = 12
	add_child(castle)
	var spots := [["archer_3", Vector3(-8.5, 0, -1.0)], ["mage_3", Vector3(7.5, 0, -3.5)], ["artillery_2", Vector3(-11.0, 0, 5.5)], ["barracks_3", Vector3(11.0, 0, 3.0)]]
	for sp in spots:
		if not await _step(): return
		var t := Assets.instance(sp[0])
		t.position = sp[1]
		t.rotation_degrees.y = -sign((sp[1] as Vector3).x) * 18.0
		add_child(t)
		if (sp[0] as String).begins_with("archer"):
			for k in 2:
				var u := CharacterModel.new()
				t.add_child(u)
				u.setup("archer_unit", 1.3)
				u.position = Vector3(-0.45 + 0.9 * k, ModelMeta.top(sp[0]), 0.15)
				u.play("idle", randf_range(0.9, 1.1))
		elif (sp[0] as String).begins_with("mage"):
			var mu := CharacterModel.new()
			t.add_child(mu)
			mu.setup("mage_unit", 1.35)
			mu.position = Vector3(0, ModelMeta.top(sp[0]), 0.1)
			mu.play("idle")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.5, 15.0)
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		if pos.z > 6 and absf(pos.x) < 7:
			continue
		if i < 5:
			if not await _step(): return
		var tr := Assets.instance(["tree_pine_v", "tree_round_v", "tree_round_v", "tree_pine_v", "rocks_v"][i % 5])
		tr.position = pos
		tr.rotation.y = rng.randf() * TAU
		tr.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		add_child(tr)
	for i in 12:
		if i < 3:
			if not await _step(): return
		var b2 := Assets.instance(["bush", "flowers", "lamp"][i % 3])
		var a2 := rng.randf() * TAU
		b2.position = Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(3.5, 9.0)
		b2.rotation.y = rng.randf() * TAU
		add_child(b2)
	var amb := FX.new()
	add_child(amb)
	var lv := amb.ambient("leaves")
	lv.amount = 24
	lv.scale_amount_min = 0.08
	lv.scale_amount_max = 0.14
	lv.emission_box_extents = Vector3(14, 1, 10)
	lv.position = Vector3(0, 8, 0)
	var hero_root := Node3D.new()
	add_child(hero_root)
	hero_root.position = Vector3(2.0, 0, 5.5)
	if not await _step(): return
	_hero = CharacterModel.new()
	hero_root.add_child(_hero)
	var hd := DB.hero_def()
	_hero.setup(hd["model"], hd["scale"], Color.WHITE, hd["weapon"])
	_hero.rotation_degrees.y = 15
	_hero.play("idle")
	_hero.add_idle_life()  # fades in from the still pose, so the backdrop picture still matches
	if not await _step(): return
	for i in 3:
		var fm := CharacterModel.new()
		add_child(fm)
		fm.setup("footman", 1.7, Color.WHITE, "")
		fm.position = Vector3(-0.2 + i * 2.2, 0, 3.4 - absf(i - 1) * 0.5)
		fm.rotation_degrees.y = 10
		fm.play("idle", randf_range(0.8, 1.1))
	if not await _step(): return
	_troll = CharacterModel.new()
	add_child(_troll)
	_troll.setup("troll", 4.2, Color.WHITE, "w_club")
	_troll.position = Vector3(-6.5, 0, -10.5)
	_troll.rotation_degrees.y = 160
	_troll.visible = false
	_troll.play("roar", 0.8)
	if not await _step(): return
	for i in 5:
		if i < 2:
			if not await _step(): return
		var g := CharacterModel.new()
		add_child(g)
		g.setup(["goblin", "orc", "goblin", "goblin", "orc"][i], [1.25, 2.2, 1.25, 1.25, 2.2][i], Color.WHITE, ["w_dagger", "w_axe", "w_dagger", "w_dagger", "w_axe"][i])
		g.position = Vector3(-3.0 + i * 1.8, 0, 11.5 + (i % 2) * 1.5)
		g.rotation_degrees.y = 190
		g.visible = false
		g.play("run", 0.0001)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)

func _process(delta: float) -> void:
	_t += delta
	if cam == null:
		return
	var a := sin(_t * 0.07) * 0.28
	var r := 9.5
	cam.position = Vector3(1.5 + sin(a) * r, 2.3 + sin(_t * 0.15) * 0.2, 5.5 + cos(a) * r)
	cam.look_at(Vector3(1.2, 2.7, -1.0), Vector3.UP)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UI.theme()
	layer.add_child(ui)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.02, 0.02, 0.05, 0.75))
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(grad)
	_build_title(true)
	Game.layout_changed.connect(_on_layout_changed)

var _title_root: Control

## The title screen's own parts: logo, the start button with the three menu buttons under it
## (bottom-left on a wide screen, across the bottom on an upright one, under the thumb) and the
## settings gear in the corner, where people look for it.
func _build_title(first := false) -> void:
	if _title_root:
		_title_root.queue_free()
	var t := Game.tall
	var vs := get_viewport().get_visible_rect().size
	_title_root = Control.new()
	_title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_title_root)
	ui.move_child(_title_root, 2 if _backdrop else 1)
	var title := UI.title("RUNE BASTION", 52 if t else 96, "title", 9 if t else 14)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 48 if t else 22
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_root.add_child(title)
	var rw := 360.0 if t else 460.0
	var sub := UI.ribbon("룬 바스티온 · 왕국 수호전", 20 if t else 26, "red", rw)
	sub.anchor_left = 0.5
	sub.anchor_right = 0.5
	sub.offset_left = -rw * 0.5
	sub.offset_right = rw * 0.5
	sub.offset_top = 124 if t else 132
	_title_root.add_child(sub)
	var gear := UI.round_button(Assets.tex("ic_gear"), 52 if t else 60)
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -(52 if t else 60) - 16
	gear.offset_right = -16
	gear.offset_top = 16
	gear.tooltip_text = tr("설정")
	gear.pressed.connect(_open_settings)
	_title_root.add_child(gear)
	var cw := (vs.x - 48.0) if t else 400.0
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.anchor_top = 1.0
	vb.anchor_bottom = 1.0
	vb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if t:
		vb.anchor_left = 0.5
		vb.anchor_right = 0.5
		vb.offset_left = -cw * 0.5
		vb.offset_right = cw * 0.5
		vb.offset_bottom = -64
	else:
		vb.offset_left = 48
		vb.offset_right = 48 + cw
		vb.offset_bottom = -60
	_title_root.add_child(vb)
	var play := UI.button("게임 시작", 34, true, Vector2(cw, 84), "primary")
	play.icon = Assets.tex("ic_play")
	play.pressed.connect(_open_select)
	vb.add_child(play)
	# Enter / Space starts (the default action of the screen)
	play.grab_focus.call_deferred(true)
	var btns: Array = []
	for it in [["영웅", "ic_hero", _open_heroes], ["도감", "ic_book", _open_bestiary], ["업적", "ic_trophy", _open_achievements]]:
		var b := UI.button(it[0], 20, false, Vector2(0, 58), "secondary")
		b.icon = Assets.tex(it[1])
		var fn: Callable = it[2]
		b.pressed.connect(func(): fn.call())
		if it[0] == "영웅" and DB.unspent_talents() > 0:
			# unspent talent points: the same badge the map dock uses for unspent stars
			var bd := UI.badge(str(DB.unspent_talents()), 28, 15)
			bd.anchor_left = 1.0
			bd.anchor_right = 1.0
			bd.offset_left = -22
			bd.offset_top = -10
			b.add_child(bd)
		btns.append(b)
	vb.add_child(UI.action_row(btns))
	_menu_items = [_title_root]
	if _select:
		_title_root.visible = false
	if not first:
		return
	# entrance: title drops in, ribbon unfurls, the buttons fade up in turn
	title.modulate.a = 0.0
	title.position.y -= 40
	var tw := title.create_tween().set_parallel(true)
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(title, "position:y", title.position.y + 40, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sub.scale = Vector2(0.2, 1.0)
	sub.modulate.a = 0.0
	(func():
		sub.pivot_offset = sub.size * 0.5
		var t2 := sub.create_tween().set_parallel(true)
		t2.tween_property(sub, "scale", Vector2.ONE, 0.5).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_property(sub, "modulate:a", 1.0, 0.3).set_delay(0.35)).call_deferred()
	var k := 0
	for c in [play, btns[0].get_parent(), gear]:
		var cc := c as Control
		cc.modulate.a = 0.0
		var t3 := cc.create_tween()
		t3.tween_interval(0.5 + k * 0.08)
		t3.tween_property(cc, "modulate:a", 1.0, 0.25)
		k += 1

## The phone was turned: dialogs laid out for the other orientation close, the title rebuilds
## (the world map lays itself out again on its own).
func _on_layout_changed() -> void:
	if not is_inside_tree():
		return
	for c in ui.get_children():
		if c.has_meta("body"):
			c.queue_free()
	_build_title()

var _menu_items: Array = []

func _set_menu_visible(v: bool) -> void:
	for c in _menu_items:
		(c as CanvasItem).visible = v

# ---------------------------------------------------------------- world map

func _open_select() -> void:
	if not Content.has("menu"):
		await _need_menu()
	if _select:
		_select.queue_free()
	_set_menu_visible(false)
	var m := WorldMap.new()
	m.menu = self
	ui.add_child(m)
	_select = m
	# the painted map covers the whole screen: stop rendering the 3D diorama behind it
	get_viewport().disable_3d = true

func _close_select() -> void:
	if _select:
		_select.queue_free()
		_select = null
	get_viewport().disable_3d = false
	_set_menu_visible(true)

func _refresh_select() -> void:
	if _select and _select is WorldMap:
		(_select as WorldMap).refresh_stars()
		(_select as WorldMap)._rebuild_flags()

# ---------------------------------------------------------------- overlay shell

## A dialog sheet over the title or the map (UI.sheet). Returns [shade, body VBox, body width].
## `width` is the width on a wide screen; an upright one gives the sheet the full width.
func _overlay(title: String, width := 760.0, aside: Control = null) -> Array:
	var shade := UI.sheet(ui, title, {"width": width, "aside": aside, "on_close": func(s: Control):
		UI.dismiss(s, _refresh_select)})
	return [shade, shade.get_meta("body"), UI.sheet_w(shade)]

## Esc / Back: the top sheet closes first (a briefing card on the map, then a menu sheet), then
## the map itself.
func _unhandled_input(ev: InputEvent) -> void:
	if not ev.is_action_pressed("ui_cancel"):
		return
	if UI.close_top(ui) or (_select and UI.close_top(_select)):
		get_viewport().set_input_as_handled()
		return
	if _select:
		_close_select()
		get_viewport().set_input_as_handled()

## Switch from one sheet to another without the exit animation in between.
func _swap(shade: Control, open: Callable) -> void:
	shade.queue_free()
	open.call()

# ---------------------------------------------------------------- heroes

## Hero roster: pick who leads the defense.
func _open_heroes() -> void:
	if not Content.has("menu"):
		await _need_menu()
	var o := _overlay("영웅 선택", 1240.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var w: float = o[2]
	var n_h := DB.HEROES.size()
	# side by side when they fit; upright, one under the other (the sheet scrolls); a phone held
	# sideways scrolls the row
	var cw := floorf((w - 16.0 * (n_h - 1)) / n_h)
	var box: BoxContainer
	if cw >= 330.0:
		box = HBoxContainer.new()
		vb.add_child(box)
	elif Game.tall:
		cw = w
		box = VBoxContainer.new()
		vb.add_child(box)
	else:
		cw = 360.0
		box = HBoxContainer.new()
		var sc := ScrollContainer.new()
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(w, 0)
		sc.add_child(box)
		vb.add_child(sc)
	box.add_theme_constant_override("separation", 16 if box is HBoxContainer else 12)
	for id in DB.HEROES:
		var h: Dictionary = DB.HEROES[id]
		var unlocked := Game.hero_unlocked(id)
		var chosen: bool = Game.hero_id == id
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.well_on(12) if chosen else UI.frame("well", 12))
		p.custom_minimum_size = Vector2(cw, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		p.add_child(cv)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		var slot := Panel.new()
		var psz := 92
		slot.custom_minimum_size = Vector2(psz, psz)
		slot.add_theme_stylebox_override("panel", UI.flat(UI.RIDGE, psz * 0.5, Vector4.ZERO))
		var inner := psz * 0.92
		var por := UI.portrait(Assets.tex(h["portrait"]), inner)
		por.position = Vector2.ONE * (psz - inner) * 0.5
		por.size = Vector2(inner, inner)
		if not unlocked:
			por.modulate = Color(0.25, 0.25, 0.3)
		slot.add_child(por)
		top.add_child(slot)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		# the name block wraps inside the card instead of widening it (long English names
		# pushed three cards past a phone's width)
		var name_w := cw - psz - 14.0 - 36.0
		var nl := UI.ink(h["name"], 24, UI.INK if unlocked else UI.INK_SOFT, "title_kr")
		var tl := UI.ink(h["title"], UI.T_SMALL, UI.GOLD, "ui_black")
		var kind := tr("원거리 · 사거리 %.1f") % float(h["range"]) if h.get("ranged", false) else "근접 · 적을 막아섬"
		var kl := UI.ink(kind, UI.T_SMALL, UI.INK_SOFT)
		# a long name first steps its size down (to 18) to stay on one line; wrapping is the last
		# resort (a Japanese name would otherwise break mid-word)
		var nf: Font = nl.get_theme_font("font")
		var nfs := 24
		while nfs > 18 and nf.get_string_size(tr(h["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > name_w:
			nfs -= 1
		nl.add_theme_font_size_override("font_size", nfs)
		for l in [nl, tl, kl]:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = name_w
			nv.add_child(l)
		top.add_child(nv)
		cv.add_child(top)
		var d := UI.ink(h["desc"], UI.T_SMALL, UI.INK)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(cw - 40, 0)
		cv.add_child(d)
		var sr := HFlowContainer.new()
		sr.add_theme_constant_override("h_separation", 16)
		sr.add_child(UI.stat("heart", "%d" % h["hp"], 17))
		sr.add_child(UI.stat("st_dmg", "%d-%d" % [h["dmg"][0], h["dmg"][1]], 17))
		sr.add_child(UI.stat("st_armor", "%d%%" % int(float(h["armor"]) * 100), 17))
		cv.add_child(sr)
		cv.add_child(_skill_line(h["skill_icon"], h["skill_name"], tr("재사용 %d초") % int(h["skill_cd"])))
		# the second skill opens partway through each battle
		var s2: Dictionary = h["skill2"]
		cv.add_child(_skill_line(s2["icon"], s2["name"], tr("전투 Lv%d부터 · 재사용 %d초") % [DB.SKILL2_LEVEL, int(s2["cd"])]))
		# persistent rank (lifetime XP) -> talent points
		var rk := HBoxContainer.new()
		rk.add_theme_constant_override("separation", 8)
		rk.add_child(UI.badge(str(DB.hero_rank(id)), 30, 16))
		var prog: Array = DB.hero_rank_progress(id)
		var rbar := UI.bar("gold", 0, 12)
		rbar.max_value = maxf(float(prog[1]), 1.0)
		rbar.value = float(prog[0]) if float(prog[1]) > 0.0 else rbar.max_value
		rbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rk.add_child(rbar)
		var pts := DB.talent_points(id)
		rk.add_child(UI.ink(tr("재능 포인트 %d") % pts, UI.T_SMALL, UI.GOLD if pts > 0 else UI.INK_SOFT, "ui_black"))
		cv.add_child(rk)
		var b: Button
		if not unlocked:
			b = UI.button(tr("%d번째 지역 클리어 시 해금") % (int(h.get("unlock", 0)) + 1), 17, false, Vector2(0, 52), "ghost")
			b.icon = Assets.tex("lock")
			b.disabled = true
		elif chosen:
			b = UI.button("출전 중", 20, false, Vector2(0, 52), "ghost")
			b.icon = Assets.tex("check")
			b.disabled = true
		else:
			b = UI.button("이 영웅으로 출전", 20, true, Vector2(0, 52), "primary")
			b.pressed.connect(func():
				Game.hero_id = id
				Game.save()
				Audio.play("upgrade", -4.0)
				Audio.voice(id + "_select", 0.0, 0.5)
				if _hero:
					_show_hero()
				if _backdrop:
					_backdrop.texture = _backdrop_tex()
				_swap(shade, _open_heroes))
		var brow: Array = []
		if unlocked:
			var tb := UI.button("재능", 20, false, Vector2(0, 52), "special")
			tb.icon = Assets.tex("ht_skill")
			if pts > 0:
				var bd := UI.badge(str(pts), 26, 14)
				bd.anchor_left = 1.0
				bd.anchor_right = 1.0
				bd.offset_left = -20
				bd.offset_top = -10
				tb.add_child(bd)
			tb.pressed.connect(func(): _swap(shade, func(): _open_talents(id)))
			brow.append(tb)
		brow.append(b)
		var ar := UI.action_row(brow)
		b.size_flags_stretch_ratio = 2.0
		if cw < 400.0:
			# a narrow card (three across a phone held sideways): smaller labels, and the buttons
			# never push the card wider than its share of the sheet
			for bb in brow:
				(bb as Button).add_theme_font_size_override("font_size", 17)
				(bb as Button).add_theme_constant_override("icon_max_width", 18)
				(bb as Button).add_theme_constant_override("h_separation", 6)
				(bb as Button).clip_text = true
			b.size_flags_stretch_ratio = 1.6
		# side by side, the cards share one height and their buttons one line
		var push := Control.new()
		push.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(push)
		cv.add_child(ar)
		box.add_child(p)

## Hero talents: rank points (from lifetime battle XP) bought into four 3-step talents.
func _open_talents(id: String) -> void:
	var h: Dictionary = DB.HEROES[id]
	var o := _overlay(tr("%s의 재능") % tr(h["name"]), 720.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.bust(Assets.tex(h["portrait"]), 64, 1.4, Vector2(0.5, 0.38)))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	var rl := HBoxContainer.new()
	var rank_l := UI.ink("", 20, UI.INK, "ui_black")
	rank_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.add_child(rank_l)
	var pts_l := UI.ink("", 18, UI.GOLD, "ui_black")
	rl.add_child(pts_l)
	hv.add_child(rl)
	var bar := UI.bar("gold", 0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(bar)
	var xp_l := UI.ink("", UI.T_SMALL, UI.MUTED)
	hv.add_child(xp_l)
	head.add_child(hv)
	vb.add_child(head)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	vb.add_child(rows)
	var refresh: Callable
	var cells := []
	for td in DB.HERO_TALENTS:
		var cp := UI.framed("well", 6)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		cp.add_child(hb)
		hb.add_child(UI.icon(Assets.tex(td["icon"]), 46))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.ink(td["name"], 19, UI.INK, "ui_black"))
		var dl := UI.ink(td["desc"], UI.T_SMALL, UI.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		tv.add_child(pips)
		hb.add_child(tv)
		var bt := UI.button("+1", 20, false, Vector2(68, 48), "primary")
		bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(bt)
		var tid: String = td["id"]
		bt.pressed.connect(func():
			if DB.talent_points(id) <= 0 or DB.talent(id, tid) >= DB.TALENT_MAX:
				Audio.play("error", -4.0)
				return
			var cur: Dictionary = Game.hero_talents.get(id, {})
			cur[tid] = DB.talent(id, tid) + 1
			Game.hero_talents[id] = cur
			Game.save()
			Audio.play("upgrade", -2.0)
			UI.pop_in(cp)
			refresh.call())
		cells.append([tid, pips, bt])
		rows.add_child(cp)
	refresh = func():
		var r := DB.hero_rank(id)
		var prog: Array = DB.hero_rank_progress(id)
		rank_l.text = tr("등급 %d") % r
		pts_l.text = tr("재능 포인트 %d") % DB.talent_points(id)
		bar.max_value = maxf(float(prog[1]), 1.0)
		bar.value = float(prog[0]) if float(prog[1]) > 0.0 else bar.max_value
		xp_l.text = tr("다음 등급까지 경험치 %d") % int(float(prog[1]) - float(prog[0])) if float(prog[1]) > 0.0 else tr("최고 등급 달성!")
		for c in cells:
			var lv := DB.talent(id, c[0])
			var pp: HBoxContainer = c[1]
			for ch in pp.get_children():
				ch.queue_free()
			for k in DB.TALENT_MAX:
				pp.add_child(UI.icon(Assets.tex("star" if k < lv else "star_empty"), 20))
			(c[2] as Button).disabled = lv >= DB.TALENT_MAX or DB.talent_points(id) <= 0
	refresh.call()
	var hint := UI.ink("전투에서 얻은 경험치가 쌓여 등급이 오르고, 등급마다 재능 포인트 1을 받습니다.", UI.T_SMALL, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)
	var rs := UI.button("재능 초기화", 19, false, Vector2(0, 52), "ghost")
	rs.icon = Assets.tex("ic_retry")
	rs.pressed.connect(func():
		Game.hero_talents[id] = {}
		Game.save()
		Audio.play("sell", -4.0)
		refresh.call())
	var back := UI.button("영웅 목록", 19, false, Vector2(0, 52), "secondary")
	back.icon = Assets.tex("ic_hero")
	back.pressed.connect(func(): _swap(shade, _open_heroes))
	vb.add_child(UI.action_row([rs, back]))

# ---------------------------------------------------------------- bestiary

## Bestiary: every enemy met so far, with stats and how to counter it.
func _open_bestiary(tab := "enemy") -> void:
	if not Content.has("menu"):
		await _need_menu()
	var o := _overlay("도감", 1000.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var w: float = o[2]
	# tabs: enemies / towers
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for tb in [["enemy", "적"], ["tower", "타워"]]:
		var b := UI.button(tb[1], 18, false, Vector2(120, 44), "primary" if tab == tb[0] else "ghost")
		var id: String = tb[0]
		b.pressed.connect(func():
			if id != tab:
				Audio.play("click", -4.0)
				_swap(shade, func(): _open_bestiary(id)))
		tabs.add_child(b)
	vb.add_child(tabs)
	if tab == "tower":
		_tower_codex(vb, w)
		return
	# wide: the list on the left, the page on the right; upright: the page on top, the list under it
	var cell := 74
	var box: BoxContainer = VBoxContainer.new() if Game.tall else HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var grid := GridContainer.new()
	grid.columns = int((w + 6.0) / (cell + 6.0)) if Game.tall else (4 if w >= 900.0 else 3)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.add_child(grid)
	var dw := w if Game.tall else w - grid.columns * (cell + 6.0) - 16.0
	var detail := UI.framed("well", 10)
	detail.custom_minimum_size = Vector2(dw, 0 if Game.tall else 360)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	detail.add_child(dv)
	if Game.tall:
		box.add_child(detail)
		box.add_child(left)
	else:
		box.add_child(left)
		box.add_child(detail)
	vb.add_child(box)
	var show := func(t: String):
		for c in dv.get_children():
			c.queue_free()
		var e: Dictionary = DB.ENEMIES[t]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(UI.bust(Assets.tex("portrait_" + t), 88, 1.25))
		var nv := VBoxContainer.new()
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		nv.add_theme_constant_override("separation", 6)
		nv.add_child(UI.ink(e["name"], 24, UI.INK, "title_kr"))
		var tags := []
		if e.get("boss", false): tags.append("보스")
		if e.get("flying", false): tags.append("비행")
		if float(e["armor"]) >= 0.3: tags.append("중장갑")
		if float(e["mr"]) >= 0.3: tags.append("마법 저항")
		if float(e["speed"]) >= 3.0: tags.append("고속")
		if tags.is_empty(): tags.append("일반")
		# traits as tags, not a dotted string
		var tg := HFlowContainer.new()
		tg.add_theme_constant_override("h_separation", 6)
		tg.add_theme_constant_override("v_separation", 6)
		for tx in tags:
			var pill := PanelContainer.new()
			pill.add_theme_stylebox_override("panel", UI.flat(Color(UI.EMBER, 0.18), 10, Vector4(10, 2, 10, 3)))
			pill.add_child(UI.ink(tx, 15, Color(1.0, 0.72, 0.62), "ui_black"))
			tg.add_child(pill)
		nv.add_child(tg)
		top.add_child(nv)
		dv.add_child(top)
		var spd := "빠름" if float(e["speed"]) >= 3.0 else ("느림" if float(e["speed"]) < 1.5 else "보통")
		var g1 := GridContainer.new()
		g1.columns = 2
		g1.add_theme_constant_override("h_separation", 24)
		g1.add_theme_constant_override("v_separation", 6)
		g1.add_child(UI.stat("heart", tr("체력 %d") % e["hp"], 17))
		g1.add_child(UI.stat("st_speed", tr("속도 %s") % tr(spd), 17))
		g1.add_child(UI.stat("st_armor", tr("방어 %d%%") % int(float(e["armor"]) * 100), 17))
		g1.add_child(UI.stat("st_magic", tr("마법 저항 %d%%") % int(float(e["mr"]) * 100), 17))
		g1.add_child(UI.stat("coin", tr("보상 %d") % e["gold"], 17))
		g1.add_child(UI.stat("skull", tr("생명 -%d") % e["lives"], 17))
		dv.add_child(g1)
		dv.add_child(UI.ink("공략", UI.T_SMALL, UI.GOLD, "ui_black"))
		var tip := UI.ink(str(e.get("desc", "")), 17, UI.INK)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(dw - 40, 0)
		dv.add_child(tip)
	var first := ""
	var seen_n := 0
	for t in DB.ENEMIES:
		var seen: bool = Game.seen_enemies.has(t)
		var b := Button.new()
		b.custom_minimum_size = Vector2(cell, cell)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UI.flat(UI.RIDGE if st != "hover" else UI.RIDGE.lightened(0.08), 14, Vector4(6, 6, 6, 6)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		UI.juice(b)
		if seen:
			var inner := cell * 0.86
			var por := UI.bust(Assets.tex("portrait_" + t), inner, 1.3, Vector2(0.5, 0.4))
			por.position = Vector2.ONE * (cell - inner) * 0.5
			por.size = Vector2(inner, inner)
			b.add_child(por)
			seen_n += 1
			if first == "":
				first = t
			b.pressed.connect(func():
				Audio.play("click", -6.0)
				show.call(t))
		else:
			b.icon = Assets.tex("lock")
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", int(cell * 0.36))
			b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.35))
			b.pressed.connect(func(): Audio.play("error", -6.0))
		grid.add_child(b)
	if first != "":
		show.call(first)
	else:
		dv.add_child(UI.ink("아직 만난 적이 없습니다.\n전투에서 적을 만나면 기록됩니다.", 18, UI.INK_SOFT))
	left.add_child(UI.ink(tr("발견 %d / %d") % [seen_n, DB.ENEMIES.size()], UI.T_SMALL, UI.MUTED, "ui_black"))

## Tower codex: every tower's three levels, both specializations and their special abilities.
func _tower_codex(vb: VBoxContainer, w: float) -> void:
	var cell := 88
	var box: BoxContainer = VBoxContainer.new() if Game.tall else HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	vb.add_child(box)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	var grid := GridContainer.new()
	grid.columns = 4 if Game.tall else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	box.add_child(left)
	var dw := w if Game.tall else w - (cell * 2 + 6.0) - 16.0
	var detail := UI.framed("well", 10)
	detail.custom_minimum_size = Vector2(dw, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(dv)
	box.add_child(detail)
	var picked := [""]
	var cells := {}
	var show := func(t: String):
		picked[0] = t
		for k in cells:
			(cells[k] as Button).add_theme_stylebox_override("normal", UI.well_on(6) if k == t else UI.flat(UI.RIDGE, 14, Vector4(6, 6, 6, 6)))
		for c in dv.get_children():
			c.queue_free()
		var d: Dictionary = DB.TOWERS[t]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(UI.icon(Assets.tex("tower_%s_3" % t), 68))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UI.ink(d["name"], 23, UI.INK, "title_kr"))
		var dl := UI.ink(d["desc"], UI.T_SMALL, UI.INK_SOFT)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = dw - 130
		nv.add_child(dl)
		top.add_child(nv)
		dv.add_child(top)
		# level 1-3 stats, one row each
		for lv in 3:
			var st := DB.tower_stats(t, lv + 1, "")
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 14)
			var lvl := UI.ink("Lv.%d" % (lv + 1), 16, UI.GOLD, "ui_black")
			lvl.custom_minimum_size.x = 40
			row.add_child(lvl)
			row.add_child(UI.stat("coin", str(d["levels"][lv]["cost"]), 16))
			if t == "barracks":
				row.add_child(UI.stat("st_unit", tr("병사 %d") % st["count"], 16))
				row.add_child(UI.stat("heart", "%d" % st["soldier_hp"], 16))
				row.add_child(UI.stat("st_dmg", "%d-%d" % [st["soldier_dmg"][0], st["soldier_dmg"][1]], 16))
			else:
				row.add_child(UI.stat("st_dmg", "%d-%d" % [st["dmg"][0], st["dmg"][1]], 16))
				row.add_child(UI.stat("st_rate", tr("%.1f초") % st["rate"], 16))
				row.add_child(UI.stat("st_range", "%.1f" % st["range"], 16))
			dv.add_child(row)
		dv.add_child(UI.divider(dw - 40))
		# the two specializations (level 4), each with its special ability
		for m in d["masteries"]:
			var mh := HBoxContainer.new()
			mh.add_theme_constant_override("separation", 10)
			var mi := UI.icon(Assets.tex("m_" + m["id"]), 44)
			mi.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			mh.add_child(mi)
			var mv := VBoxContainer.new()
			mv.add_theme_constant_override("separation", 2)
			mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mt := HBoxContainer.new()
			mt.add_theme_constant_override("separation", 10)
			mt.add_child(UI.ink(m["name"], 18, UI.INK, "ui_black"))
			mt.add_child(UI.stat("coin", str(m["cost"]), 15))
			mv.add_child(mt)
			var md := UI.ink(m["desc"], 15, UI.INK_SOFT)
			md.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			md.custom_minimum_size.x = dw - 110
			mv.add_child(md)
			var ab: Dictionary = m.get("ability", {})
			if not ab.is_empty():
				var ah := HBoxContainer.new()
				ah.add_theme_constant_override("separation", 8)
				ah.add_child(UI.icon(Assets.tex("a_" + ab["id"]), 30))
				var av := VBoxContainer.new()
				av.add_theme_constant_override("separation", 0)
				av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var at := HBoxContainer.new()
				at.add_theme_constant_override("separation", 10)
				at.add_child(UI.ink(ab["name"], 15, Color(0.55, 0.85, 0.95), "ui_black"))
				at.add_child(UI.stat("coin", str(DB.ability_cost(t, m["id"])), 14))
				av.add_child(at)
				var adl := UI.ink(ab["desc"], 15, UI.INK_SOFT)
				adl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				adl.custom_minimum_size.x = dw - 150
				av.add_child(adl)
				ah.add_child(av)
				mv.add_child(ah)
			mh.add_child(mv)
			dv.add_child(mh)
	for t in ["archer", "barracks", "mage", "artillery"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(cell, cell)
		b.icon = Assets.tex("tower_%s_1" % t)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", int(cell * 0.8))
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.flat(UI.RIDGE if st != "hover" else UI.RIDGE.lightened(0.08), 14, Vector4(6, 6, 6, 6)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = DB.TOWERS[t]["name"]
		UI.juice(b)
		b.pressed.connect(func():
			Audio.play("click", -6.0)
			show.call(t))
		cells[t] = b
		grid.add_child(b)
	var hint := UI.ink("3레벨 타워는 전문화로 4레벨이 되고, 전문화한 타워는 특수 능력을 하나 더 배울 수 있습니다.", 15, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = w if Game.tall else cell * 2 + 6
	left.add_child(hint)
	show.call("archer")

# ---------------------------------------------------------------- achievements

## Achievements: lifetime goals, each worth one upgrade star.
func _open_achievements() -> void:
	if not Content.has("menu"):
		await _need_menu()
	var o := _overlay("업적", 1100.0, _count_tag("star", "%d / %d" % [Game.achievement_count(), DB.ACHIEVEMENTS.size()]))
	var vb: VBoxContainer = o[1]
	var w: float = o[2]
	var hint := UI.ink("업적마다 ★1을 얻어 ‘왕국 강화’에 쓸 수 있습니다.", UI.T_SMALL, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2 if w >= 760.0 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	var cell_w := floorf((w - 10.0 * (grid.columns - 1)) / grid.columns)
	# finished ones first, then by progress
	var list: Array = DB.ACHIEVEMENTS.duplicate()
	list.sort_custom(func(a, b):
		var da: bool = Game.achievements.get(a["id"], false)
		var db_: bool = Game.achievements.get(b["id"], false)
		if da != db_:
			return da
		var pa := float(Game.stats.get(a["stat"], 0)) / float(a["goal"])
		var pb := float(Game.stats.get(b["stat"], 0)) / float(b["goal"])
		return pa > pb)
	for a in list:
		var done: bool = Game.achievements.get(a["id"], false)
		var cp := PanelContainer.new()
		cp.add_theme_stylebox_override("panel", UI.well_on(6) if done else UI.frame("well", 6))
		cp.custom_minimum_size = Vector2(cell_w, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		cp.add_child(hb)
		var ic := UI.icon(Assets.tex(a["icon"]), 48)
		if not done:
			ic.modulate = Color(0.6, 0.6, 0.66)
		hb.add_child(ic)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.ink(a["name"], 18, UI.INK, "ui_black"))
		var dl := UI.ink(a["desc"], 15, UI.INK_SOFT)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		var cur := mini(int(Game.stats.get(a["stat"], 0)), int(a["goal"]))
		if not done:
			var pb := UI.bar("blue", 0, 10)
			pb.max_value = float(a["goal"])
			pb.value = cur
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv.add_child(pb)
		hb.add_child(tv)
		if done:
			var ck := UI.stat("star", "+1", 15, UI.GOLD)
			ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(ck)
		else:
			var pl := UI.ink("%d/%d" % [cur, a["goal"]], 15, UI.MUTED, "ui_black")
			pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(pl)
		grid.add_child(cp)

## Icon + number for a sheet header (stars owned, achievements done).
func _count_tag(icon: String, txt: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(UI.icon(Assets.tex(icon), 26))
	var l := UI.ink(txt, 20, UI.GOLD, "ui_black")
	l.name = "Count"
	hb.add_child(l)
	return hb

# ---------------------------------------------------------------- kingdom upgrades

## Kingdom-Rush style upgrade tree: spend stars earned in battle on permanent bonuses.
func _open_upgrades() -> void:
	if not Content.has("menu"):
		await _need_menu()
	var tag := _count_tag("star", "")
	var o := _overlay("왕국 강화", 1100.0, tag)
	var vb: VBoxContainer = o[1]
	var w: float = o[2]
	var have: Label = tag.get_node("Count")
	var hint := UI.ink("★는 지역 클리어(최대 3개), 영웅 난이도 클리어(+1), 업적(+1)으로 얻습니다. 환불은 언제든 무료.", UI.T_SMALL, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)
	var grid := GridContainer.new()
	var cols := 3 if w >= 1000.0 else (2 if w >= 620.0 else 1)
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	var cell_w := floorf((w - 10.0 * (cols - 1)) / cols)
	var refresh: Callable
	var cells := []
	for u in DB.UPGRADES:
		var cp := PanelContainer.new()
		cp.custom_minimum_size = Vector2(cell_w, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		cp.add_child(hb)
		# every upgrade sits in the same round slot (tower renders and drawn icons alike), so the
		# grid reads as one set
		var slot := PanelContainer.new()
		var sst := UI.flat(UI.RIDGE_LIP, 29, Vector4(5, 5, 5, 5))
		sst.border_color = Color(1, 1, 1, 0.10)
		sst.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", sst)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_child(UI.icon(Assets.tex(u["icon"]), 48))
		hb.add_child(slot)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		var nl := UI.ink(u["name"], 18, UI.INK, "ui_black")
		tv.add_child(nl)
		var dl := UI.ink(u["desc"], 15, UI.INK_SOFT)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		hb.add_child(tv)
		var bt := UI.button("", 19, false, Vector2(78, 48), "primary")
		bt.icon = Assets.tex("star")
		bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(bt)
		var id: String = u["id"]
		var cost: int = u["cost"]
		bt.pressed.connect(func():
			if Game.upgrades.get(id, false):
				return
			if Game.available_stars() < cost:
				Audio.play("error", -4.0)
				return
			Game.upgrades[id] = true
			Game.save()
			Audio.play("upgrade", -2.0)
			refresh.call()
			UI.pop_in(cp))
		cells.append([cp, bt, id, cost])
		grid.add_child(cp)
	refresh = func():
		have.text = tr("보유 %d") % Game.available_stars()
		for cell in cells:
			var owned: bool = Game.upgrades.get(cell[2], false)
			var afford: bool = Game.available_stars() >= int(cell[3])
			(cell[0] as PanelContainer).add_theme_stylebox_override("panel", UI.well_on(6) if owned else UI.frame("well", 6))
			var b2: Button = cell[1]
			b2.text = "" if owned else str(cell[3])
			b2.icon = Assets.tex("check") if owned else Assets.tex("star")
			UI._btn_styles(b2, "ghost" if owned else "primary")
			if owned:
				b2.add_theme_color_override("icon_disabled_color", Color.WHITE)  # the check stays green
			b2.add_theme_constant_override("icon_max_width", 28 if owned else 20)
			b2.disabled = owned or not afford
	refresh.call()
	var reset := UI.button("전부 환불", 19, false, Vector2(200, 52), "secondary")
	reset.icon = Assets.tex("ic_retry")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func():
		Game.upgrades = {}
		Game.save()
		refresh.call())
	vb.add_child(reset)

# ---------------------------------------------------------------- settings

func _open_settings() -> void:
	var o := _overlay("설정", 900.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var w: float = o[2]
	vb.add_theme_constant_override("separation", 12)
	# two columns on a wide screen, one on an upright one
	var cols: BoxContainer = VBoxContainer.new() if Game.tall else HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20 if Game.tall else 32)
	vb.add_child(cols)
	var colw := w if Game.tall else floorf((w - 32.0) / 2.0)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(colw, 0)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(colw, 0)
	cols.add_child(right)
	# --- sound & graphics
	left.add_child(_section("소리와 그래픽"))
	for row in [["음악", Game.music_volume, "music"], ["효과음", Game.sfx_volume, "sfx"]]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		var l := UI.label(row[0], UI.T_BODY, UI.TEXT, 0, "ui")
		l.custom_minimum_size.x = 92
		hb.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 1
		sl.step = 0.05
		sl.value = row[1]
		sl.custom_minimum_size = Vector2(160, 40)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = row[2]
		sl.value_changed.connect(func(v):
			if key == "music":
				Game.music_volume = v
				Audio.update_music_volume()
			else:
				Game.sfx_volume = v
				Audio.play("click")
			Game.save())
		hb.add_child(sl)
		left.add_child(hb)
	left.add_child(_toggle("고품질 그래픽 (그림자·안티에일리어싱)", Game.high_quality, func(v):
		Game.high_quality = v
		Game.apply_quality()
		Game.save()))
	left.add_child(_toggle("화면 흔들림", Game.screen_shake, func(v):
		Game.screen_shake = v
		Game.save()))
	left.add_child(_toggle("진동 (지원하는 모바일 기기)", Game.vibration, func(v):
		Game.vibration = v
		Game.save()
		Game.vibrate(60)))
	left.add_child(_toggle("배터리 절약 (30 FPS)", Game.battery_saver, func(v):
		Game.battery_saver = v
		Game.apply_quality()
		Game.save()))
	# --- interface, language, save data
	right.add_child(_section("화면과 언어"))
	var scales := [[0.9, "작게"], [1.0, "보통"], [1.15, "크게"]]
	right.add_child(_choice("UI 크기", scales, Game.ui_scale, func(v):
		Game.set_ui_scale(v)
		_swap(shade, func(): (func(): _open_settings()).call_deferred())))
	right.add_child(_choice("언어", UI.LANGUAGES, Game.language, func(v):
		Game.language = v
		Lang.apply(v)
		Game.save()
		Game.goto_scene("res://scenes/main_menu.tscn")))
	right.add_child(_section("저장 데이터"))
	var ex := UI.button("내보내기", 18, false, Vector2(0, 50), "secondary")
	ex.icon = Assets.tex("ic_upgrade")
	ex.pressed.connect(func(): _swap(shade, func(): _open_save_code(true)))
	var im := UI.button("가져오기", 18, false, Vector2(0, 50), "secondary")
	im.icon = Assets.tex("ic_map")
	im.pressed.connect(func(): _swap(shade, func(): _open_save_code(false)))
	right.add_child(UI.action_row([ex, im]))
	if Game.dev:
		# a tester's tool (a code to paste back to the developer), not a player feature
		var pl := UI.button("플레이 기록 보내기 (밸런스 피드백)", 17, false, Vector2(0, 48), "secondary")
		pl.pressed.connect(func(): _swap(shade, _open_playlog))
		right.add_child(pl)
	# installable web app (PWA): Chrome/Edge/Android hand us their install prompt; iOS needs Safari's share menu
	if OS.has_feature("web") and not bool(JavaScriptBridge.eval("!!(window.rbStandalone && window.rbStandalone())", true)):
		if bool(JavaScriptBridge.eval("!!(window.rbCanInstall && window.rbCanInstall())", true)):
			var ib := UI.button("앱으로 설치", 18, false, Vector2(0, 50), "secondary")
			ib.icon = Assets.tex("ic_play")
			ib.pressed.connect(func():
				JavaScriptBridge.eval("window.rbInstall && window.rbInstall()", true)
				ib.disabled = true)
			right.add_child(ib)
		elif OS.has_feature("web_ios"):
			var il := UI.ink("Safari의 공유 버튼 → ‘홈 화면에 추가’로 설치하면 전체 화면으로 실행됩니다.", 15, UI.MUTED)
			il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			il.custom_minimum_size = Vector2(colw, 0)
			right.add_child(il)
	# destructive action needs a second tap within 3 s
	var rs := UI.button("진행 상황 초기화", 18, false, Vector2(0, 48), "ghost")
	var armed := [false]
	rs.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			rs.text = tr("정말 초기화? 한 번 더 누르세요")
			UI._btn_styles(rs, "danger")
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(rs) and armed[0]:
					armed[0] = false
					rs.text = tr("진행 상황 초기화")
					UI._btn_styles(rs, "ghost"))
			return
		armed[0] = false
		Game.reset_progress()
		Game.save()
		rs.text = tr("초기화 완료")
		UI._btn_styles(rs, "ghost")
		rs.disabled = true)
	right.add_child(rs)
	right.add_child(_section("정보"))
	var cr := UI.button("크레딧", 18, false, Vector2(0, 48), "ghost")
	cr.icon = Assets.tex("ic_book")
	cr.pressed.connect(func(): _swap(shade, _open_credits))
	right.add_child(cr)

## Who and what made the game (the tool credits used to sit under the title).
func _open_credits() -> void:
	var o := _overlay("크레딧", 620.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var w: float = o[2]
	vb.add_theme_constant_override("separation", 14)
	var head := UI.title("Rune Bastion", 30, "title", 5)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	for row in [["엔진", "Godot Engine 4 (MIT 라이선스)"],
			["3D 모델", "NCSOFT VARCO 3D 생성형 AI, Blender로 다듬음"],
			["음성과 음악", "ElevenLabs 음성·음악 생성, 일부 곡은 자체 작곡 도구"],
			["글꼴", "Noto Sans CJK, Noto Serif CJK, Cardo (SIL Open Font License)"],
			["게임 디자인과 개발", "룬 바스티온 팀"]]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		c.add_child(UI.ink(row[0], 16, UI.GOLD, "ui_black"))
		var l := UI.ink(row[1], 18, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		c.add_child(l)
		vb.add_child(c)
	var back := UI.button("설정으로", 18, false, Vector2(0, 50), "ghost")
	back.pressed.connect(func(): _swap(shade, _open_settings))
	vb.add_child(UI.action_row([back]))

func _section(text: String) -> Control:
	var l := UI.ink(text, 17, UI.GOLD, "ui_black")
	return l

func _toggle(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 17)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.toggled.connect(cb)
	return c

## A hero skill in the hero card: icon, then the name over its cooldown line. Two lines rather than
## name and cooldown side by side, so a long translation never widens the card past the sheet.
func _skill_line(icon: String, skill_name: String, sub: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := UI.icon(Assets.tex(icon), 34)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.ink(skill_name, 17, UI.INK, "ui_black"))
	var sl := UI.ink(sub, UI.T_SMALL, UI.INK_SOFT)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.custom_minimum_size.x = 40
	col.add_child(sl)
	row.add_child(col)
	return row

## Row of segmented buttons; options are [value, label] pairs.
func _choice(label: String, options: Array, current: Variant, cb: Callable) -> Control:
	return UI.choice(label, options, current, cb)

## Save transfer: export shows the code (also copied to the clipboard / downloadable on the web),
## import takes a pasted code (the browser's own prompt on the web: it supports paste on phones).
func _open_save_code(export: bool) -> void:
	var o := _overlay("저장 내보내기" if export else "저장 가져오기", 640.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var web := OS.has_feature("web")
	var info := UI.ink("", 17, UI.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 140)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_font_size_override("font_size", 14)
	vb.add_child(te)
	var btns: Array = []
	var back := UI.button("설정으로", 18, false, Vector2(0, 52), "ghost")
	back.pressed.connect(func(): _swap(shade, _open_settings))
	btns.append(back)
	if export:
		var code := Game.export_code()
		te.text = code
		te.editable = false
		DisplayServer.clipboard_set(code)
		info.text = tr("아래 코드를 복사해 다른 기기에서 ‘가져오기’ 하세요. (클립보드에 복사했습니다)")
		if web:
			var dl := UI.button("파일로 저장", 18, false, Vector2(0, 52), "secondary")
			dl.pressed.connect(func():
				JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "rune_bastion_save.txt", "text/plain"))
			btns.append(dl)
		var cp := UI.button("다시 복사", 18, true, Vector2(0, 52), "primary")
		cp.pressed.connect(func():
			DisplayServer.clipboard_set(code)
			Audio.play("click", -4.0)
			info.text = tr("클립보드에 복사했습니다."))
		btns.append(cp)
	else:
		info.text = tr("다른 기기에서 내보낸 저장 코드를 붙여넣으세요. 현재 진행 상황을 덮어씁니다.")
		te.placeholder_text = "RB1-..."
		var apply := func(code: String):
			var err := Game.import_code(code)
			if err != "":
				info.text = tr(err)
				info.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
				Audio.play("error", -4.0)
				return
			Audio.play("upgrade", -2.0)
			Game.goto_scene("res://scenes/main_menu.tscn")
		if web:
			var pb := UI.button("코드 붙여넣기", 18, false, Vector2(0, 52), "secondary")
			pb.pressed.connect(func():
				var got = JavaScriptBridge.eval("window.prompt(%s, '') || ''" % JSON.stringify(tr("저장 코드를 붙여넣으세요")), true)
				if got is String and got != "":
					te.text = got
					apply.call(got))
			btns.append(pb)
		var ok := UI.button("적용", 18, true, Vector2(0, 52), "primary")
		ok.pressed.connect(func(): apply.call(te.text))
		btns.append(ok)
	vb.add_child(UI.action_row(btns))

## Playtest feedback: the recent-run log as one code to paste into a chat.
func _open_playlog() -> void:
	var o := _overlay("플레이 기록", 640.0)
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var runs := Game.playlog.size()
	var won := 0
	for r in Game.playlog:
		if r is Dictionary and r.get("r", "") == "won":
			won += 1
	vb.add_child(UI.ink(tr("기록된 판 %d (승리 %d)") % [runs, won], 20, UI.GOLD, "ui_black"))
	var info := UI.ink("최근 판의 결과(도달 웨이브, 잃은 생명, 새어 나간 적, 지은 타워)를 코드로 묶었습니다. 복사해서 대화창에 붙여 넣으면 어디서 어려웠는지 분석해 난이도를 조정합니다. 개인 정보는 들어 있지 않습니다.", UI.T_SMALL, UI.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var code := Game.playlog_code() if runs > 0 else ""
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 120)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_font_size_override("font_size", 13)
	te.text = code if runs > 0 else tr("아직 기록이 없습니다. 몇 판 플레이한 뒤 다시 열어 주세요.")
	te.editable = false
	vb.add_child(te)
	var btns: Array = []
	var back := UI.button("설정으로", 18, false, Vector2(0, 52), "ghost")
	back.pressed.connect(func(): _swap(shade, _open_settings))
	btns.append(back)
	if runs > 0:
		DisplayServer.clipboard_set(code)
		var cp := UI.button("복사", 18, true, Vector2(0, 52), "primary")
		cp.pressed.connect(func():
			DisplayServer.clipboard_set(code)
			Audio.play("click", -4.0)
			cp.text = tr("복사했습니다"))
		btns.append(cp)
	vb.add_child(UI.action_row(btns))

func _test_playlog() -> void:
	Game.playlog = [{"lv": 2, "d": 0, "e": false, "h": "kael", "r": "lost", "s": 0, "wv": 9, "nw": 12, "li": 0, "ml": 20, "t": 512, "k": 230, "g": 40, "tw": ["ar3", "ba2", "ma3-arcane"], "lw": {"7": 6, "9": 14}, "lt": {"wolf": 9, "orc": 11}, "sp": 5, "hl": 4, "ts": 0}]
	_open_playlog()

# screenshot hooks for tools/test_runner (open=_test_card / _test_endless)
func _test_card() -> void:
	_open_select()
	(func(): (_select as WorldMap)._open_card(1)).call_deferred()

func _test_codex_towers() -> void:
	_open_bestiary("tower")

func _test_talents() -> void:
	_open_talents("kael")

func _test_save() -> void:
	_open_save_code(true)

func _test_endless() -> void:
	_open_select()
	(func(): (_select as WorldMap)._open_endless_card()).call_deferred()


func _exit_tree() -> void:
	# the world map switches 3D rendering off on the shared root viewport; never leak that into a level
	get_viewport().disable_3d = false