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
	_build_world()
	_build_ui()
	Audio.play_music("menu")

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
	var castle := Assets.instance("castle")
	castle.position = Vector3(-2.0, 0, -9)
	castle.rotation_degrees.y = 12
	add_child(castle)
	var spots := [["archer_3", Vector3(-8.5, 0, -1.0)], ["mage_3", Vector3(7.5, 0, -3.5)], ["artillery_2", Vector3(-11.0, 0, 5.5)], ["barracks_3", Vector3(11.0, 0, 3.0)]]
	for sp in spots:
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
		var tr := Assets.instance(["tree_pine_v", "tree_round_v", "tree_round_v", "tree_pine_v", "rocks_v"][i % 5])
		tr.position = pos
		tr.rotation.y = rng.randf() * TAU
		tr.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		add_child(tr)
	for i in 12:
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
	_hero = CharacterModel.new()
	hero_root.add_child(_hero)
	var hd := DB.hero_def()
	_hero.setup(hd["model"], hd["scale"], Color.WHITE, hd["weapon"])
	_hero.rotation_degrees.y = 15
	_hero.play("idle")
	for i in 3:
		var fm := CharacterModel.new()
		add_child(fm)
		fm.setup("footman", 1.7, Color.WHITE, "")
		fm.position = Vector3(-0.2 + i * 2.2, 0, 3.4 - absf(i - 1) * 0.5)
		fm.rotation_degrees.y = 10
		fm.play("idle", randf_range(0.8, 1.1))
	_troll = CharacterModel.new()
	add_child(_troll)
	_troll.setup("troll", 4.2, Color.WHITE, "w_club")
	_troll.position = Vector3(-6.5, 0, -10.5)
	_troll.rotation_degrees.y = 160
	_troll.visible = false
	_troll.play("roar", 0.8)
	for i in 5:
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
	var title := UI.title("RUNE BASTION", 96, "title", 14)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 22
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(title)
	var sub := UI.ribbon("룬 바스티온 · 왕국 수호전", 26, "red", 460)
	sub.anchor_left = 0.5
	sub.anchor_right = 0.5
	sub.offset_left = -230
	sub.offset_right = 230
	sub.offset_top = 132
	ui.add_child(sub)
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.0
	vb.anchor_right = 0.0
	vb.anchor_top = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left = 48
	vb.offset_right = 428
	vb.offset_top = -330
	vb.add_theme_constant_override("separation", 12)
	ui.add_child(vb)
	var play := UI.button("게임 시작", 38, true, Vector2(380, 92), "red")
	play.icon = Assets.tex("ic_play")
	play.pressed.connect(_open_select)
	vb.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for it in [["영웅", "ic_hero", _open_heroes], ["도감", "ic_book", _open_bestiary], ["업적", "ic_trophy", _open_achievements]]:
		var b := UI.button(it[0], 22, false, Vector2(121, 66), "blue")
		b.icon = Assets.tex(it[1])
		b.add_theme_constant_override("icon_max_width", 30)
		var fn: Callable = it[2]
		b.pressed.connect(func(): fn.call())
		if it[0] == "영웅" and DB.unspent_talents() > 0:
			# unspent talent points: same red badge the upgrade dock uses for unspent stars
			var bd := UI.badge(str(DB.unspent_talents()), 28, 15)
			bd.position = Vector2(97, -8)
			b.add_child(bd)
		row.add_child(b)
	vb.add_child(row)
	var settings := UI.button("설정", 24, false, Vector2(380, 62), "blue")
	settings.icon = Assets.tex("ic_gear")
	settings.add_theme_constant_override("icon_max_width", 30)
	settings.pressed.connect(_open_settings)
	vb.add_child(settings)
	var credit := UI.label("3D 애셋: NCSOFT VARCO 3D 생성형 AI  ·  파이프라인: Blender  ·  엔진: Godot 4", 15, UI.MUTED, 4)
	credit.anchor_left = 0.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_top = -30
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(credit)
	_menu_items = [title, sub, vb, credit]
	# entrance: title drops in, ribbon unfurls, buttons slide from the left
	title.modulate.a = 0.0
	title.position.y -= 40
	var tw := title.create_tween().set_parallel(true)
	tw.tween_property(title, "modulate:a", 1.0, 0.8)
	tw.tween_property(title, "position:y", title.position.y + 40, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sub.scale = Vector2(0.2, 1.0)
	sub.modulate.a = 0.0
	(func():
		sub.pivot_offset = sub.size * 0.5
		var t2 := sub.create_tween().set_parallel(true)
		t2.tween_property(sub, "scale", Vector2.ONE, 0.5).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_property(sub, "modulate:a", 1.0, 0.3).set_delay(0.35)).call_deferred()
	var k := 0
	for c in [play, row, settings]:
		var cc := c as Control
		cc.modulate.a = 0.0
		var t3 := cc.create_tween()
		t3.tween_interval(0.5 + k * 0.08)
		t3.tween_property(cc, "modulate:a", 1.0, 0.25)
		k += 1

var _menu_items: Array = []

func _set_menu_visible(v: bool) -> void:
	for c in _menu_items:
		(c as CanvasItem).visible = v

# ---------------------------------------------------------------- world map

func _open_select() -> void:
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

## Dimmed screen + ribbon-titled enamel panel. Returns [shade, body VBox].
func _overlay(title: String, ribbon_kind := "red") -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(c)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", -30)
	c.add_child(wrap)
	var compact := get_viewport().get_visible_rect().size.y < 600.0
	var rib := UI.ribbon(title, 28 if compact else 34, ribbon_kind, 440)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rib.z_index = 1
	wrap.add_child(rib)
	var p := UI.framed("dark", 14 if compact else 18)
	var holder := UI.with_close(p, func():
		shade.queue_free()
		_refresh_select())
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(holder)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8 if compact else 10)
	p.add_child(vb)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	vb.add_child(sp)
	(func(): UI.pop_in(wrap)).call_deferred()
	return [shade, vb]

func _close_button(shade: Control, after := Callable()) -> Control:
	var cc := CenterContainer.new()
	var close := UI.button("닫기", 22, false, Vector2(220, 54), "blue")
	close.pressed.connect(func():
		shade.queue_free()
		_refresh_select()
		if after.is_valid():
			after.call())
	cc.add_child(close)
	return cc

# ---------------------------------------------------------------- heroes

## Hero roster: pick who leads the defense.
func _open_heroes() -> void:
	var o := _overlay("영웅 선택")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var compact := vs.y < 600.0
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	# three cards side by side when they fit; on narrow (phone) canvases they scroll sideways
	var n_h := DB.HEROES.size()
	var cw := minf((vs.x - 120.0 - 16.0 * (n_h - 1)) / n_h, 430.0)
	if cw >= 340.0:
		vb.add_child(hb)
	else:
		cw = 380.0
		var sc := ScrollContainer.new()
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(vs.x - 110.0, 0)
		sc.add_child(hb)
		vb.add_child(sc)
	for id in DB.HEROES:
		var h: Dictionary = DB.HEROES[id]
		var unlocked := Game.hero_unlocked(id)
		var chosen: bool = Game.hero_id == id
		var p := UI.framed("parch", 10 if compact else 14)
		p.custom_minimum_size = Vector2(cw, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4 if compact else 6)
		p.add_child(cv)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var slot := Panel.new()
		var psz := 104 if not compact else 78
		slot.custom_minimum_size = Vector2(psz, psz)
		slot.add_theme_stylebox_override("panel", UI.hd("slot_%s_normal" % ("red" if chosen else "navy"), Vector4(48, 48, 48, 48), Vector4(3, 3, 3, 3)))
		var inner := psz * 0.84
		var por := UI.portrait(Assets.tex(h["portrait"]), inner)
		por.position = Vector2.ONE * (psz - inner) * 0.5
		por.size = Vector2(inner, inner)
		if not unlocked:
			por.modulate = Color(0.25, 0.25, 0.3)
		slot.add_child(por)
		top.add_child(slot)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		nv.add_child(UI.ink(h["name"], 25 if not compact else 22, UI.INK if unlocked else UI.INK_SOFT, "title_kr"))
		nv.add_child(UI.ink(h["title"], 17, Color(0.55, 0.18, 0.1), "ui_black"))
		var kind := tr("원거리 · 사거리 %.1f") % float(h["range"]) if h.get("ranged", false) else "근접 · 적을 막아섬"
		nv.add_child(UI.ink(kind, 16, UI.INK_SOFT))
		top.add_child(nv)
		cv.add_child(top)
		var d := UI.ink(h["desc"], 16 if not compact else 15, UI.INK)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(cw - 40, 0)
		cv.add_child(d)
		var sr := HFlowContainer.new()
		sr.add_theme_constant_override("h_separation", 14)
		sr.add_child(UI.stat("heart", "%d" % h["hp"], 17))
		sr.add_child(UI.stat("st_dmg", "%d-%d" % [h["dmg"][0], h["dmg"][1]], 17))
		sr.add_child(UI.stat("st_armor", "%d%%" % int(float(h["armor"]) * 100), 17))
		cv.add_child(sr)
		var sk := HBoxContainer.new()
		sk.add_theme_constant_override("separation", 6)
		sk.add_child(UI.icon(Assets.tex(h["skill_icon"]), 30))
		sk.add_child(UI.ink(tr("%s · 재사용 %d초") % [tr(h["skill_name"]), int(h["skill_cd"])], 16, UI.INK, "ui_black"))
		cv.add_child(sk)
		# persistent rank (lifetime XP) -> talent points
		var rk := HBoxContainer.new()
		rk.add_theme_constant_override("separation", 8)
		var rb := UI.badge(str(DB.hero_rank(id)), 30, 16)
		rk.add_child(rb)
		var prog: Array = DB.hero_rank_progress(id)
		var rbar := UI.bar("gold", 0, 12)
		rbar.max_value = maxf(float(prog[1]), 1.0)
		rbar.value = float(prog[0]) if float(prog[1]) > 0.0 else rbar.max_value
		rbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rk.add_child(rbar)
		var pts := DB.talent_points(id)
		rk.add_child(UI.ink(tr("재능 포인트 %d") % pts, 16, Color(0.6, 0.16, 0.08) if pts > 0 else UI.INK_SOFT, "ui_black"))
		cv.add_child(rk)
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 8)
		var b: Button
		var bw := cw - 40 - (128 if unlocked else 0)
		if not unlocked:
			b = UI.button(tr("%d번째 지역 클리어 시 해금") % (int(h.get("unlock", 0)) + 1), 17, false, Vector2(bw, 50), "gray")
			b.icon = Assets.tex("lock")
			b.disabled = true
		elif chosen:
			b = UI.button("출전 중", 21, false, Vector2(bw, 50), "gold")
			b.icon = Assets.tex("check")
		else:
			b = UI.button("이 영웅으로 출전", 21, true, Vector2(bw, 50), "red")
			b.pressed.connect(func():
				Game.hero_id = id
				Game.save()
				Audio.play("upgrade", -4.0)
				Audio.voice(id + "_select", 0.0, 0.5)
				var hd := DB.hero_def()
				_hero.setup(hd["model"], hd["scale"], Color.WHITE, hd["weapon"])
				_hero.play("idle")
				shade.queue_free()
				_open_heroes())
		brow.add_child(b)
		if unlocked:
			var tb := UI.button("재능", 20, false, Vector2(120, 50), "purple")
			tb.icon = Assets.tex("ht_skill")
			tb.add_theme_constant_override("icon_max_width", 26)
			if pts > 0:
				var bd := UI.badge(str(pts), 26, 14)
				bd.position = Vector2(98, -8)
				tb.add_child(bd)
			tb.pressed.connect(func():
				shade.queue_free()
				_open_talents(id))
			brow.add_child(tb)
		cv.add_child(brow)
		hb.add_child(p)

## Hero talents: rank points (from lifetime battle XP) bought into four 3-step talents.
func _open_talents(id: String) -> void:
	var h: Dictionary = DB.HEROES[id]
	var o := _overlay(tr("재능 · %s") % tr(h["name"]), "dark")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var compact := get_viewport().get_visible_rect().size.y < 600.0
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UI.bust(Assets.tex(h["portrait"]), 70 if not compact else 56, 1.4, Vector2(0.5, 0.38)))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rank_l := UI.label("", 22, UI.GOLD, 5, "ui_black")
	hv.add_child(rank_l)
	var bar := UI.bar("gold", 0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(bar)
	var xp_l := UI.label("", 15, UI.MUTED, 3)
	hv.add_child(xp_l)
	head.add_child(hv)
	head.custom_minimum_size = Vector2(640, 0)
	vb.add_child(head)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6 if compact else 8)
	vb.add_child(rows)
	var refresh: Callable
	var cells := []
	for td in DB.HERO_TALENTS:
		var cp := UI.framed("slim", 2)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		cp.add_child(hb)
		hb.add_child(UI.icon(Assets.tex(td["icon"]), 50 if not compact else 42))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(td["name"], 20, UI.TEXT, 4, "ui_black"))
		tv.add_child(UI.label(td["desc"], 15, UI.MUTED, 3))
		hb.add_child(tv)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(pips)
		var bt := UI.button("+1", 20, false, Vector2(72, 48), "gold")
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
		rank_l.text = tr("등급 %d  ·  재능 포인트 %d") % [r, DB.talent_points(id)]
		bar.max_value = maxf(float(prog[1]), 1.0)
		bar.value = float(prog[0]) if float(prog[1]) > 0.0 else bar.max_value
		xp_l.text = tr("다음 등급까지 경험치 %d") % int(float(prog[1]) - float(prog[0])) if float(prog[1]) > 0.0 else tr("최고 등급 달성!")
		for c in cells:
			var lv := DB.talent(id, c[0])
			var pp: HBoxContainer = c[1]
			for ch in pp.get_children():
				ch.queue_free()
			for k in DB.TALENT_MAX:
				var st := UI.icon(Assets.tex("star" if k < lv else "star_empty"), 24)
				pp.add_child(st)
			(c[2] as Button).disabled = lv >= DB.TALENT_MAX or DB.talent_points(id) <= 0
	refresh.call()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var back := UI.button("영웅 목록", 20, false, Vector2(170, 52), "blue")
	back.icon = Assets.tex("ic_hero")
	back.add_theme_constant_override("icon_max_width", 26)
	back.pressed.connect(func():
		shade.queue_free()
		_open_heroes())
	row.add_child(back)
	var rs := UI.button("재능 초기화", 20, false, Vector2(170, 52), "gray")
	rs.icon = Assets.tex("ic_retry")
	rs.add_theme_constant_override("icon_max_width", 24)
	rs.pressed.connect(func():
		Game.hero_talents[id] = {}
		Game.save()
		Audio.play("sell", -4.0)
		refresh.call())
	row.add_child(rs)
	vb.add_child(row)
	var hint := UI.label("전투에서 얻은 경험치가 쌓여 등급이 오르고, 등급마다 재능 포인트 1을 받습니다.", 15, UI.MUTED, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(640, 0)
	vb.add_child(hint)

# ---------------------------------------------------------------- bestiary

## Bestiary: every enemy met so far, with stats and how to counter it.
func _open_bestiary(tab := "enemy") -> void:
	var o := _overlay("도감", "dark")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var compact := vs.y < 600.0
	# tabs: enemies / towers
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for tb in [["enemy", "적"], ["tower", "타워"]]:
		var b := UI.button(tb[1], 19, false, Vector2(140, 44), "gold" if tab == tb[0] else "gray")
		var id: String = tb[0]
		b.pressed.connect(func():
			if id != tab:
				Audio.play("click", -4.0)
				shade.queue_free()
				_open_bestiary(id))
		tabs.add_child(b)
	vb.add_child(tabs)
	if tab == "tower":
		_tower_codex(vb, vs, compact)
		return
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	var grid := GridContainer.new()
	grid.columns = 4 if vs.x >= 1100.0 else 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var detail := UI.framed("parch", 12)
	detail.custom_minimum_size = Vector2(minf(vs.x * 0.38, 440.0), minf(vs.y - 200.0, 400.0))
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail.add_child(dv)
	hb.add_child(detail)
	var show := func(t: String):
		for c in dv.get_children():
			c.queue_free()
		var e: Dictionary = DB.ENEMIES[t]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.add_child(UI.bust(Assets.tex("portrait_" + t), 96 if not compact else 76, 1.25))
		var nv := VBoxContainer.new()
		nv.add_child(UI.ink(e["name"], 25, UI.INK, "title_kr"))
		var tags := []
		if e.get("boss", false): tags.append("보스")
		if e.get("flying", false): tags.append("비행")
		if float(e["armor"]) >= 0.3: tags.append("중장갑")
		if float(e["mr"]) >= 0.3: tags.append("마법 저항")
		if float(e["speed"]) >= 3.0: tags.append("고속")
		nv.add_child(UI.ink(" · ".join(tags) if not tags.is_empty() else "일반", 17, Color(0.6, 0.16, 0.08), "ui_black"))
		top.add_child(nv)
		dv.add_child(top)
		dv.add_child(UI.divider(detail.custom_minimum_size.x - 40))
		var spd := "빠름" if float(e["speed"]) >= 3.0 else ("느림" if float(e["speed"]) < 1.5 else "보통")
		var g1 := GridContainer.new()
		g1.columns = 2
		g1.add_theme_constant_override("h_separation", 22)
		g1.add_theme_constant_override("v_separation", 6)
		g1.add_child(UI.stat("heart", tr("체력 %d") % e["hp"], 18))
		g1.add_child(UI.stat("st_speed", tr("속도 %s") % tr(spd), 18))
		g1.add_child(UI.stat("st_armor", tr("방어 %d%%") % int(float(e["armor"]) * 100), 18))
		g1.add_child(UI.stat("st_magic", tr("마법 저항 %d%%") % int(float(e["mr"]) * 100), 18))
		g1.add_child(UI.stat("coin", tr("보상 %d") % e["gold"], 18))
		g1.add_child(UI.stat("skull", tr("생명 -%d") % e["lives"], 18))
		dv.add_child(g1)
		var tip := UI.ink(tr("공략: ") + tr(str(e.get("desc", ""))), 17, UI.INK)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(detail.custom_minimum_size.x - 40, 0)
		dv.add_child(tip)
	var first := ""
	var seen_n := 0
	var cell := 78 if not compact else 62
	for t in DB.ENEMIES:
		var seen: bool = Game.seen_enemies.has(t)
		var b := UI.icon_button(null, cell, UI.NAVY, 14, "navy")
		if seen:
			var inner := cell * 0.8
			var por := UI.portrait(Assets.tex("portrait_" + t), inner, 1.3, Vector2(0.5, 0.4))
			por.position = Vector2.ONE * (cell - inner) * 0.5
			por.size = Vector2(inner, inner)
			b.add_child(por)
		if not seen:
			b.icon = Assets.tex("lock")
			b.add_theme_constant_override("icon_max_width", int(cell * 0.42))
			b.pressed.connect(func(): Audio.play("error", -6.0))
		else:
			seen_n += 1
			if first == "":
				first = t
			b.pressed.connect(func(): show.call(t))
		grid.add_child(b)
	if first != "":
		show.call(first)
	else:
		dv.add_child(UI.ink("아직 만난 적이 없습니다.\n전투에서 적을 만나면 기록됩니다.", 18, UI.INK_SOFT))
	var cnt := UI.label(tr("발견 %d / %d") % [seen_n, DB.ENEMIES.size()], 18, UI.GOLD, 4, "ui_black")
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(cnt)

## Tower codex: every tower's three levels, both specializations and their special abilities.
func _tower_codex(vb: VBoxContainer, vs: Vector2, compact: bool) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	var dw := minf(vs.x - 300.0, 640.0)
	var detail := UI.framed("parch", 12)
	detail.custom_minimum_size = Vector2(dw, minf(vs.y - 250.0, 400.0))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(dw - 24, minf(vs.y - 274.0, 376.0))
	detail.add_child(sc)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(dv)
	hb.add_child(detail)
	var show := func(t: String):
		for c in dv.get_children():
			c.queue_free()
		sc.scroll_vertical = 0
		var d: Dictionary = DB.TOWERS[t]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.add_child(UI.icon(Assets.tex("tower_%s_3" % t), 72 if not compact else 58))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UI.ink(d["name"], 24, UI.INK, "title_kr"))
		var dl := UI.ink(d["desc"], 16, UI.INK_SOFT)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = dw - 140
		nv.add_child(dl)
		top.add_child(nv)
		dv.add_child(top)
		# level 1-3 stats, one row each
		for lv in 3:
			var st := DB.tower_stats(t, lv + 1, "")
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.add_child(UI.ink("Lv.%d" % (lv + 1), 17, Color(0.6, 0.16, 0.08), "ui_black"))
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
		dv.add_child(UI.divider(dw - 50))
		# the two specializations (level 4), each with its special ability
		for m in d["masteries"]:
			var mh := HBoxContainer.new()
			mh.add_theme_constant_override("separation", 10)
			mh.add_child(UI.icon(Assets.tex("m_" + m["id"]), 46 if not compact else 40))
			var mv := VBoxContainer.new()
			mv.add_theme_constant_override("separation", 0)
			mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mt := HBoxContainer.new()
			mt.add_theme_constant_override("separation", 8)
			mt.add_child(UI.ink(m["name"], 19, UI.INK, "ui_black"))
			mt.add_child(UI.stat("coin", str(m["cost"]), 15))
			mv.add_child(mt)
			var md := UI.ink(m["desc"], 15, UI.INK_SOFT)
			md.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			md.custom_minimum_size.x = dw - 120
			mv.add_child(md)
			mh.add_child(mv)
			dv.add_child(mh)
			var ab: Dictionary = m.get("ability", {})
			if not ab.is_empty():
				var ah := HBoxContainer.new()
				ah.add_theme_constant_override("separation", 10)
				var pad := Control.new()
				pad.custom_minimum_size.x = 26
				ah.add_child(pad)
				ah.add_child(UI.icon(Assets.tex("a_" + ab["id"]), 36 if not compact else 32))
				var av := VBoxContainer.new()
				av.add_theme_constant_override("separation", 0)
				av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var at := HBoxContainer.new()
				at.add_theme_constant_override("separation", 8)
				at.add_child(UI.ink(tr("특수 능력 · ") + tr(ab["name"]), 16, Color(0.1, 0.4, 0.5), "ui_black"))
				at.add_child(UI.stat("coin", str(DB.ability_cost(t, m["id"])), 14))
				av.add_child(at)
				var adl := UI.ink(ab["desc"], 14, UI.INK_SOFT)
				adl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				adl.custom_minimum_size.x = dw - 150
				av.add_child(adl)
				ah.add_child(av)
				dv.add_child(ah)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var cell := 96 if not compact else 76
	for t in ["archer", "barracks", "mage", "artillery"]:
		var b := UI.icon_button(Assets.tex("tower_%s_1" % t), cell, UI.NAVY, 14, "navy")
		b.add_theme_constant_override("icon_max_width", int(cell * 0.8))
		b.tooltip_text = DB.TOWERS[t]["name"]
		b.pressed.connect(func():
			Audio.play("click", -6.0)
			show.call(t))
		grid.add_child(b)
	var hint := UI.label("3레벨 타워는 전문화로 4레벨이 되고, 전문화한 타워는 특수 능력을 하나 더 배울 수 있습니다.", 15, UI.MUTED, 3)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = cell * 2 + 6
	left.add_child(hint)
	show.call("archer")

# ---------------------------------------------------------------- achievements

## Achievements: lifetime goals, each worth one upgrade star.
func _open_achievements() -> void:
	var o := _overlay(tr("업적  ★ %d / %d") % [Game.achievement_count(), DB.ACHIEVEMENTS.size()], "blue")
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(minf(vs.x - 100.0, 1080.0), minf(vs.y - 190.0, 470.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2 if vs.x >= 900.0 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var cell_w := (sc.custom_minimum_size.x - 34.0) / grid.columns
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
		var cp := UI.framed("parch" if done else "slim", 2)
		cp.custom_minimum_size = Vector2(cell_w, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		cp.add_child(hb)
		var ic := UI.icon(Assets.tex(a["icon"]), 52)
		if not done:
			ic.modulate = Color(0.6, 0.6, 0.66)
		hb.add_child(ic)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if done:
			tv.add_child(UI.ink(a["name"], 20, UI.INK, "ui_black"))
			tv.add_child(UI.ink(a["desc"], 15, UI.INK_SOFT))
		else:
			tv.add_child(UI.label(a["name"], 20, UI.TEXT, 4, "ui_black"))
			tv.add_child(UI.label(a["desc"], 15, UI.MUTED, 3))
		var cur := mini(int(Game.stats.get(a["stat"], 0)), int(a["goal"]))
		var pb := UI.bar("gold" if done else "blue", 0, 12)
		pb.max_value = float(a["goal"])
		pb.value = cur
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(pb)
		hb.add_child(tv)
		if done:
			var ck := VBoxContainer.new()
			ck.alignment = BoxContainer.ALIGNMENT_CENTER
			ck.add_child(UI.icon(Assets.tex("check"), 30))
			ck.add_child(UI.stat("star", "+1", 15))
			hb.add_child(ck)
		else:
			hb.add_child(UI.label("%d/%d" % [cur, a["goal"]], 16, UI.MUTED, 3, "ui_black"))
		grid.add_child(cp)
	var hint := UI.label("업적마다 ★1을 얻어 ‘왕국 강화’에 쓸 수 있습니다.", 16, UI.MUTED, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

# ---------------------------------------------------------------- kingdom upgrades

## Kingdom-Rush style upgrade tree: spend stars earned in battle on permanent bonuses.
func _open_upgrades() -> void:
	var o := _overlay("왕국 강화", "red")
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var compact := vs.y < 600.0
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	head.add_child(UI.icon(Assets.tex("star"), 36))
	var have := UI.label("", 26, UI.GOLD, 6, "ui_black")
	head.add_child(have)
	vb.add_child(head)
	var grid := GridContainer.new()
	var cols := 3 if vs.x >= 1000.0 else 2
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var sc := ScrollContainer.new()
	var sw := minf(vs.x - 100.0, 1080.0)
	sc.custom_minimum_size = Vector2(sw, minf(vs.y - 250.0, 440.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(grid)
	vb.add_child(sc)
	var cell_w := (sw - 10.0 * (cols - 1) - 24.0) / cols
	var refresh: Callable
	var cells := []
	for u in DB.UPGRADES:
		var cp := PanelContainer.new()
		cp.custom_minimum_size = Vector2(cell_w, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		cp.add_child(hb)
		hb.add_child(UI.icon(Assets.tex(u["icon"]), 58 if not compact else 48))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UI.label(u["name"], 20, UI.TEXT, 4, "ui_black")
		tv.add_child(nl)
		var dl := UI.label(u["desc"], 16, UI.MUTED, 3)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		hb.add_child(tv)
		var bt := UI.button("", 19, false, Vector2(84, 50), "gold")
		bt.icon = Assets.tex("star")
		bt.add_theme_constant_override("icon_max_width", 22)
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
		cells.append([cp, bt, id, cost, nl, dl])
		grid.add_child(cp)
	refresh = func():
		have.text = tr("보유 %d") % Game.available_stars()
		for cell in cells:
			var owned: bool = Game.upgrades.get(cell[2], false)
			var afford: bool = Game.available_stars() >= int(cell[3])
			(cell[0] as PanelContainer).add_theme_stylebox_override("panel", UI.frame("parch" if owned else "slim", 4))
			var nl2: Label = cell[4]
			var dl2: Label = cell[5]
			nl2.add_theme_color_override("font_color", UI.INK if owned else UI.TEXT)
			nl2.add_theme_constant_override("outline_size", 0 if owned else 4)
			dl2.add_theme_color_override("font_color", UI.INK_SOFT if owned else UI.MUTED)
			dl2.add_theme_constant_override("outline_size", 0 if owned else 3)
			var b2: Button = cell[1]
			b2.text = "" if owned else str(cell[3])
			b2.icon = Assets.tex("check") if owned else Assets.tex("star")
			b2.disabled = owned or not afford
	refresh.call()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var reset := UI.button("전부 환불", 20, false, Vector2(190, 52), "blue")
	reset.icon = Assets.tex("ic_retry")
	reset.add_theme_constant_override("icon_max_width", 24)
	reset.pressed.connect(func():
		Game.upgrades = {}
		Game.save()
		refresh.call())
	row.add_child(reset)
	vb.add_child(row)
	var hint := UI.label("★는 지역 클리어(최대 3개), 영웅 난이도 클리어(+1), 업적(+1)으로 얻습니다. 환불은 언제든 무료.", 15, UI.MUTED, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(sw, 0)
	vb.add_child(hint)

# ---------------------------------------------------------------- settings

func _open_settings() -> void:
	var o := _overlay("설정", "blue")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_theme_constant_override("separation", 12)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	vb.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(400, 0)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(400, 0)
	cols.add_child(right)
	# --- sound & graphics
	left.add_child(_section("소리 · 그래픽"))
	for row in [["음악", Game.music_volume, "music"], ["효과음", Game.sfx_volume, "sfx"]]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		var l := UI.label(row[0], 21, UI.TEXT, 4, "ui_black")
		l.custom_minimum_size.x = 92
		hb.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 1
		sl.step = 0.05
		sl.value = row[1]
		sl.custom_minimum_size = Vector2(280, 40)
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
	right.add_child(_section("화면 · 언어"))
	var scales := [[0.9, "작게"], [1.0, "보통"], [1.15, "크게"]]
	right.add_child(_choice("UI 크기", scales, Game.ui_scale, func(v):
		Game.set_ui_scale(v)
		shade.queue_free()
		(func(): _open_settings()).call_deferred()))
	right.add_child(_choice("언어", [["", "자동"], ["ko", "한국어"], ["en", "English"]], Game.language, func(v):
		Game.language = v
		Lang.apply(v)
		Game.save()
		Game.goto_scene("res://scenes/main_menu.tscn")))
	right.add_child(_section("저장 데이터"))
	var sv := HBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	var ex := UI.button("내보내기", 19, false, Vector2(195, 52), "green")
	ex.icon = Assets.tex("ic_upgrade")
	ex.add_theme_constant_override("icon_max_width", 22)
	ex.pressed.connect(func():
		shade.queue_free()
		_open_save_code(true))
	sv.add_child(ex)
	var im := UI.button("가져오기", 19, false, Vector2(195, 52), "blue")
	im.icon = Assets.tex("ic_map")
	im.add_theme_constant_override("icon_max_width", 22)
	im.pressed.connect(func():
		shade.queue_free()
		_open_save_code(false))
	sv.add_child(im)
	right.add_child(sv)
	var pl := UI.button("플레이 기록 보내기 (밸런스 피드백)", 17, false, Vector2(400, 46), "purple")
	pl.pressed.connect(func():
		shade.queue_free()
		_open_playlog())
	right.add_child(pl)
	# installable web app (PWA): Chrome/Edge/Android hand us their install prompt; iOS needs Safari's share menu
	if OS.has_feature("web") and not bool(JavaScriptBridge.eval("!!(window.rbStandalone && window.rbStandalone())", true)):
		if bool(JavaScriptBridge.eval("!!(window.rbCanInstall && window.rbCanInstall())", true)):
			var ib := UI.button("앱으로 설치", 19, false, Vector2(400, 50), "purple")
			ib.icon = Assets.tex("ic_play")
			ib.add_theme_constant_override("icon_max_width", 22)
			ib.pressed.connect(func():
				JavaScriptBridge.eval("window.rbInstall && window.rbInstall()", true)
				ib.disabled = true)
			right.add_child(ib)
		elif OS.has_feature("web_ios"):
			var il := UI.label("Safari의 공유 버튼 → ‘홈 화면에 추가’로 설치하면 전체 화면으로 실행됩니다.", 15, UI.MUTED, 3)
			il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			il.custom_minimum_size = Vector2(400, 0)
			right.add_child(il)
	# destructive action needs a second tap within 3 s
	var rs := UI.button("진행 상황 초기화", 19, false, Vector2(400, 50), "gray")
	var armed := [false]
	rs.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			rs.text = tr("정말 초기화? 한 번 더 누르세요")
			UI._btn_styles(rs, "red")
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(rs) and armed[0]:
					armed[0] = false
					rs.text = tr("진행 상황 초기화")
					UI._btn_styles(rs, "gray"))
			return
		armed[0] = false
		Game.reset_progress()
		Game.save()
		rs.text = tr("초기화 완료")
		UI._btn_styles(rs, "gray")
		rs.disabled = true)
	right.add_child(rs)

func _section(text: String) -> Control:
	var l := UI.label(text, 17, UI.GOLD, 4, "ui_black")
	return l

func _toggle(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_override("font", Assets.font("ui_black"))
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(cb)
	return c

## Row of segmented buttons; options are [value, label] pairs.
func _choice(label: String, options: Array, current: Variant, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := UI.label(label, 19, UI.TEXT, 4, "ui_black")
	l.custom_minimum_size.x = 92
	hb.add_child(l)
	for op in options:
		var sel: bool = str(op[0]) == str(current) or (op[0] is float and current is float and absf(float(op[0]) - float(current)) < 0.01)
		var b := UI.button(op[1], 17, false, Vector2(98, 46), "gold" if sel else "gray")
		var v: Variant = op[0]
		b.pressed.connect(func():
			Audio.play("click", -4.0)
			cb.call(v))
		hb.add_child(b)
	return hb

## Save transfer: export shows the code (also copied to the clipboard / downloadable on the web),
## import takes a pasted code (the browser's own prompt on the web: it supports paste on phones).
func _open_save_code(export: bool) -> void:
	var o := _overlay("저장 내보내기" if export else "저장 가져오기", "blue")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var web := OS.has_feature("web")
	var info := UI.label("", 17, UI.TEXT, 3)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(560, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(560, 150)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_font_size_override("font_size", 13)
	vb.add_child(te)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	if export:
		var code := Game.export_code()
		te.text = code
		te.editable = false
		DisplayServer.clipboard_set(code)
		info.text = tr("아래 코드를 복사해 다른 기기에서 ‘가져오기’ 하세요. (클립보드에 복사했습니다)")
		var cp := UI.button("다시 복사", 19, false, Vector2(170, 52), "green")
		cp.pressed.connect(func():
			DisplayServer.clipboard_set(code)
			Audio.play("click", -4.0)
			info.text = tr("클립보드에 복사했습니다."))
		row.add_child(cp)
		if web:
			var dl := UI.button("파일로 저장", 19, false, Vector2(170, 52), "blue")
			dl.pressed.connect(func():
				JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "rune_bastion_save.txt", "text/plain"))
			row.add_child(dl)
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
			var pb := UI.button("코드 붙여넣기", 19, true, Vector2(200, 52), "green")
			pb.pressed.connect(func():
				var got = JavaScriptBridge.eval("window.prompt(%s, '') || ''" % JSON.stringify(tr("저장 코드를 붙여넣으세요")), true)
				if got is String and got != "":
					te.text = got
					apply.call(got))
			row.add_child(pb)
		var ok := UI.button("적용", 19, false, Vector2(150, 52), "gold")
		ok.pressed.connect(func(): apply.call(te.text))
		row.add_child(ok)
	var back := UI.button("닫기", 19, false, Vector2(150, 52), "gray")
	back.pressed.connect(func():
		shade.queue_free()
		_open_settings())
	row.add_child(back)

## Playtest feedback: the recent-run log as one code to paste into a chat.
func _open_playlog() -> void:
	var o := _overlay("플레이 기록", "blue")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var runs := Game.playlog.size()
	var won := 0
	for r in Game.playlog:
		if r is Dictionary and r.get("r", "") == "won":
			won += 1
	var head := UI.label(tr("기록된 판 %d (승리 %d)") % [runs, won], 21, UI.GOLD, 4, "ui_black")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	var info := UI.label("최근 판의 결과(도달 웨이브, 잃은 생명, 새어 나간 적, 지은 타워)를 코드로 묶었습니다. 복사해서 대화창에 붙여 넣으면 어디서 어려웠는지 분석해 난이도를 조정합니다. 개인 정보는 들어 있지 않습니다.", 16, UI.TEXT, 3)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(560, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var code := Game.playlog_code() if runs > 0 else ""
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(560, 120)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_font_size_override("font_size", 12)
	te.text = code if runs > 0 else tr("아직 기록이 없습니다. 몇 판 플레이한 뒤 다시 열어 주세요.")
	te.editable = false
	vb.add_child(te)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	if runs > 0:
		DisplayServer.clipboard_set(code)
		var cp := UI.button("복사", 19, true, Vector2(170, 52), "green")
		cp.pressed.connect(func():
			DisplayServer.clipboard_set(code)
			Audio.play("click", -4.0)
			cp.text = tr("복사했습니다"))
		row.add_child(cp)
	var back := UI.button("닫기", 19, false, Vector2(150, 52), "gray")
	back.pressed.connect(func():
		shade.queue_free()
		_open_settings())
	row.add_child(back)

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