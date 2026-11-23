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
	vb.add_child(hb)
	var cw := minf((vs.x - 160.0) / 2.0, 430.0)
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
		var por := UI.icon(Assets.tex(h["portrait"]), psz)
		por.set_anchors_preset(Control.PRESET_FULL_RECT)
		por.offset_left = psz * 0.1
		por.offset_top = psz * 0.08
		por.offset_right = -psz * 0.1
		por.offset_bottom = -psz * 0.1
		if not unlocked:
			por.modulate = Color(0.25, 0.25, 0.3)
		slot.add_child(por)
		top.add_child(slot)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		nv.add_child(UI.ink(h["name"], 25 if not compact else 22, UI.INK if unlocked else UI.INK_SOFT, "title_kr"))
		nv.add_child(UI.ink(h["title"], 17, Color(0.55, 0.18, 0.1), "ui_black"))
		var kind := "원거리 · 사거리 %.1f" % float(h["range"]) if h.get("ranged", false) else "근접 · 적을 막아섬"
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
		sk.add_child(UI.ink("%s · 재사용 %d초" % [h["skill_name"], int(h["skill_cd"])], 16, UI.INK, "ui_black"))
		cv.add_child(sk)
		var b: Button
		if not unlocked:
			b = UI.button("2번째 지역 클리어 시 해금", 17, false, Vector2(cw - 40, 50), "gray")
			b.icon = Assets.tex("lock")
			b.disabled = true
		elif chosen:
			b = UI.button("출전 중", 21, false, Vector2(cw - 40, 50), "gold")
			b.icon = Assets.tex("check")
		else:
			b = UI.button("이 영웅으로 출전", 21, true, Vector2(cw - 40, 50), "red")
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
		cv.add_child(b)
		hb.add_child(p)

# ---------------------------------------------------------------- bestiary

## Bestiary: every enemy met so far, with stats and how to counter it.
func _open_bestiary() -> void:
	var o := _overlay("적 도감", "dark")
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var compact := vs.y < 600.0
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
		top.add_child(UI.icon(Assets.tex("portrait_" + t), 88 if not compact else 70))
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
		g1.add_child(UI.stat("heart", "체력 %d" % e["hp"], 18))
		g1.add_child(UI.stat("st_speed", "속도 %s" % spd, 18))
		g1.add_child(UI.stat("st_armor", "방어 %d%%" % int(float(e["armor"]) * 100), 18))
		g1.add_child(UI.stat("st_magic", "마법 저항 %d%%" % int(float(e["mr"]) * 100), 18))
		g1.add_child(UI.stat("coin", "보상 %d" % e["gold"], 18))
		g1.add_child(UI.stat("skull", "생명 -%d" % e["lives"], 18))
		dv.add_child(g1)
		var tip := UI.ink("공략: " + str(e.get("desc", "")), 17, UI.INK)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(detail.custom_minimum_size.x - 40, 0)
		dv.add_child(tip)
	var first := ""
	var seen_n := 0
	var cell := 78 if not compact else 62
	for t in DB.ENEMIES:
		var seen: bool = Game.seen_enemies.has(t)
		var b := UI.icon_button(Assets.tex("portrait_" + t), cell, UI.NAVY, 14, "navy")
		b.add_theme_constant_override("icon_max_width", int(cell * 0.78))
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
	var cnt := UI.label("발견 %d / %d" % [seen_n, DB.ENEMIES.size()], 18, UI.GOLD, 4, "ui_black")
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(cnt)

# ---------------------------------------------------------------- achievements

## Achievements: lifetime goals, each worth one upgrade star.
func _open_achievements() -> void:
	var o := _overlay("업적  ★ %d / %d" % [Game.achievement_count(), DB.ACHIEVEMENTS.size()], "blue")
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
		have.text = "보유 ★ %d" % Game.available_stars()
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
	var vb: VBoxContainer = o[1]
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(440, 0)
	for row in [["음악", Game.music_volume, "music"], ["효과음", Game.sfx_volume, "sfx"]]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		var l := UI.label(row[0], 22, UI.TEXT, 4, "ui_black")
		l.custom_minimum_size.x = 90
		hb.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = 0.05
		s.value = row[1]
		s.custom_minimum_size = Vector2(300, 40)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = row[2]
		s.value_changed.connect(func(v):
			if key == "music":
				Game.music_volume = v
				Audio.update_music_volume()
			else:
				Game.sfx_volume = v
				Audio.play("click")
			Game.save())
		hb.add_child(s)
		vb.add_child(hb)
	var hq := CheckButton.new()
	hq.text = "고품질 그래픽 (그림자·안티에일리어싱)"
	hq.button_pressed = Game.high_quality
	hq.add_theme_font_override("font", Assets.font("ui_black"))
	hq.toggled.connect(func(v):
		Game.high_quality = v
		Game.apply_quality()
		Game.save())
	vb.add_child(hq)
	vb.add_child(UI.divider(440))
	# destructive action needs a second tap within 3 s
	var rs := UI.button("진행 상황 초기화", 19, false, Vector2(300, 50), "gray")
	var armed := [false]
	rs.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			rs.text = "정말 초기화? 한 번 더 누르세요"
			UI._btn_styles(rs, "red")
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(rs) and armed[0] and rs.text.begins_with("정말"):
					armed[0] = false
					rs.text = "진행 상황 초기화"
					UI._btn_styles(rs, "gray"))
			return
		armed[0] = false
		Game.stars = [0, 0, 0, 0, 0]
		Game.heroic = [false, false, false, false, false]
		Game.upgrades = {}
		Game.stats = {}
		Game.achievements = {}
		Game.seen_enemies = {}
		Game.endless_best = {}
		Game.hero_id = "kael"
		Game.seen_tutorial = false
		Game.save()
		rs.text = "초기화 완료"
		UI._btn_styles(rs, "gray")
		rs.disabled = true)
	var cc := CenterContainer.new()
	cc.add_child(rs)
	vb.add_child(cc)

# screenshot hooks for tools/test_runner (open=_test_card / _test_endless)
func _test_card() -> void:
	_open_select()
	(func(): (_select as WorldMap)._open_card(1)).call_deferred()

func _test_endless() -> void:
	_open_select()
	(func(): (_select as WorldMap)._open_endless_card()).call_deferred()


func _exit_tree() -> void:
	# the world map switches 3D rendering off on the shared root viewport; never leak that into a level
	get_viewport().disable_3d = false