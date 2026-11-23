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
	var title := UI.label("RUNE BASTION", 96, UI.GOLD, 16, "title")
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 28
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	ui.add_child(title)
	var sub := UI.label("룬 바스티온 · 왕국 수호전", 34, UI.PARCH, 9, "title_kr")
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.offset_top = 136
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(sub)
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.0
	vb.anchor_right = 0.0
	vb.anchor_top = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left = 56
	vb.offset_right = 416
	vb.offset_top = -318
	vb.add_theme_constant_override("separation", 12)
	ui.add_child(vb)
	var play := UI.button("게임 시작", 36, true, Vector2(360, 86))
	play.pressed.connect(_open_select)
	vb.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for it in [["영웅", _open_heroes], ["도감", _open_bestiary], ["업적", _open_achievements]]:
		var b := UI.button(it[0], 24, false, Vector2(114, 62))
		b.pressed.connect(func():
			Audio.play("click", -4.0, 0.05)
			(it[1] as Callable).call())
		row.add_child(b)
	vb.add_child(row)
	var settings := UI.button("설정", 26, false, Vector2(360, 62))
	settings.pressed.connect(_open_settings)
	vb.add_child(settings)
	var credit := UI.label("3D 애셋: NCSOFT VARCO 3D 생성형 AI  ·  파이프라인: Blender  ·  엔진: Godot 4", 16, UI.MUTED, 4)
	credit.anchor_left = 0.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_top = -34
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(credit)
	(func(): UI.pop_in(play, 0.2)).call_deferred()
	_menu_items = [title, sub, vb]
	title.modulate.a = 0.0
	title.create_tween().tween_property(title, "modulate:a", 1.0, 1.0)

var _menu_items: Array = []

func _set_menu_visible(v: bool) -> void:
	for c in _menu_items:
		(c as CanvasItem).visible = v

func _open_select() -> void:
	if _select:
		_select.queue_free()
	_set_menu_visible(false)
	var vs := get_viewport().get_visible_rect().size
	var narrow := vs.x < 1100.0
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	_select = shade
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 14
	vb.offset_bottom = -14
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12 if narrow else 18)
	shade.add_child(vb)
	# header: title, difficulty toggle, stars / upgrades
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 22)
	vb.add_child(head)
	var t := UI.label("전장 선택", 40 if narrow else 50, UI.GOLD, 12, "title_kr")
	head.add_child(t)
	var diff := UI.button("난이도: 영웅" if Game.difficulty == 1 else "난이도: 일반", 22, Game.difficulty == 1, Vector2(200, 54))
	diff.pressed.connect(func():
		Game.difficulty = 1 - Game.difficulty
		Game.save()
		Audio.play("click")
		_open_select())
	head.add_child(diff)
	var stars_b := UI.button("★ %d  강화" % Game.available_stars(), 22, false, Vector2(170, 54))
	stars_b.add_theme_color_override("font_color", UI.GOLD)
	stars_b.pressed.connect(_open_upgrades)
	head.add_child(stars_b)
	if Game.difficulty == 1:
		var note := UI.label("영웅 난이도: 적 체력 +15% · 적 공격력 +10% · 생명 10  —  클리어 시 보너스 ★", 18, Color(1.0, 0.6, 0.5), 4)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(note)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(minf(vs.x - 40.0, 1240.0), 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cc := CenterContainer.new()
	cc.add_child(sc)
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cc)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	sc.add_child(hb)
	var first_open := 0
	for i in DB.LEVELS.size():
		hb.add_child(_level_card(i))
		if Game.unlocked(i):
			first_open = i
	hb.add_child(_endless_card())
	# scroll so the newest unlocked level is visible
	(func():
		await get_tree().process_frame
		sc.scroll_horizontal = int(maxf(0.0, (first_open - 1) * 262.0))).call_deferred()
	var back := UI.button("뒤로", 24, false, Vector2(220, 54))
	back.pressed.connect(func():
		shade.queue_free()
		_select = null
		_set_menu_visible(true))
	var c := CenterContainer.new()
	c.add_child(back)
	vb.add_child(c)

func _level_card(i: int) -> Control:
	var d: Dictionary = DB.LEVELS[i]
	var unlocked := Game.unlocked(i)
	var vs := get_viewport().get_visible_rect().size
	var border := UI.GOLD if unlocked else Color(0.35, 0.35, 0.4)
	if Game.heroic[i]:
		border = Color(1.0, 0.45, 0.35)
	var p := UI.panel(Color(0.08, 0.09, 0.15, 0.96), border, 18)
	var cw := 232.0
	p.custom_minimum_size = Vector2(cw + 24, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var img := TextureRect.new()
	img.texture = Assets.tex("level_%d" % i)
	img.custom_minimum_size = Vector2(cw, cw * 0.5625 * (0.7 if vs.y < 600.0 else 1.0))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if not unlocked:
		img.modulate = Color(0.3, 0.3, 0.35)
	vb.add_child(img)
	var n := UI.label("%d. %s" % [i + 1, d["name"]], 24, UI.GOLD if unlocked else UI.MUTED, 6)
	vb.add_child(n)
	var s := UI.label(d["desc"], 16, UI.TEXT if unlocked else UI.MUTED, 4)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(cw, 44 if vs.y < 600.0 else 64)
	vb.add_child(s)
	var sr := HBoxContainer.new()
	sr.add_child(UI.stars_row(Game.stars[i], 34))
	if Game.heroic[i]:
		sr.add_child(UI.label("  영웅 ★", 18, Color(1.0, 0.55, 0.45), 4))
	vb.add_child(sr)
	if unlocked:
		var b := UI.button("출전" if Game.difficulty == 0 else "영웅 출전", 24, true, Vector2(cw, 54))
		b.pressed.connect(func(): Game.start_level(i))
		vb.add_child(b)
	else:
		var lk := HBoxContainer.new()
		lk.alignment = BoxContainer.ALIGNMENT_CENTER
		lk.add_child(UI.icon(Assets.tex("lock"), 36))
		lk.add_child(UI.label("이전 지역 클리어 필요", 16, UI.MUTED, 4))
		vb.add_child(lk)
	(func(): UI.pop_in(p, 0.05 * i)).call_deferred()
	return p

var _endless_pick := 0

func _endless_card() -> Control:
	var unlocked := Game.endless_unlocked()
	var vs := get_viewport().get_visible_rect().size
	var p := UI.panel(Color(0.12, 0.06, 0.1, 0.96), Color(0.9, 0.4, 0.9) if unlocked else Color(0.35, 0.35, 0.4), 18)
	var cw := 232.0
	p.custom_minimum_size = Vector2(cw + 24, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var maps := []
	for i in DB.LEVELS.size():
		if Game.stars[i] > 0:
			maps.append(i)
	if maps.is_empty():
		maps.append(0)
	_endless_pick = clampi(_endless_pick, 0, maps.size() - 1)
	var mi: int = maps[_endless_pick]
	var img := TextureRect.new()
	img.texture = Assets.tex("level_%d" % mi)
	img.custom_minimum_size = Vector2(cw, cw * 0.5625 * (0.7 if vs.y < 600.0 else 1.0))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.modulate = Color(1, 0.85, 1) if unlocked else Color(0.3, 0.3, 0.35)
	vb.add_child(img)
	vb.add_child(UI.label("∞ 무한 모드", 24, Color(1.0, 0.6, 1.0) if unlocked else UI.MUTED, 6))
	var d := UI.label("끝없이 강해지는 적을 상대로 몇 웨이브까지 버틸 수 있을까? 10웨이브마다 보스 등장.", 16, UI.TEXT if unlocked else UI.MUTED, 4)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(cw, 44 if vs.y < 600.0 else 64)
	vb.add_child(d)
	if unlocked:
		var mr := HBoxContainer.new()
		mr.alignment = BoxContainer.ALIGNMENT_CENTER
		var prev := UI.button("◀", 20, false, Vector2(44, 40))
		var nm := UI.label(DB.LEVELS[mi]["name"], 17, UI.GOLD, 4)
		nm.custom_minimum_size = Vector2(130, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var nxt := UI.button("▶", 20, false, Vector2(44, 40))
		prev.pressed.connect(func():
			_endless_pick = (_endless_pick - 1 + maps.size()) % maps.size()
			_open_select())
		nxt.pressed.connect(func():
			_endless_pick = (_endless_pick + 1) % maps.size()
			_open_select())
		mr.add_child(prev)
		mr.add_child(nm)
		mr.add_child(nxt)
		vb.add_child(mr)
		vb.add_child(UI.label("최고 기록: 웨이브 %d" % int(Game.endless_best.get(str(mi), 0)), 17, UI.TEXT, 4))
		var b := UI.button("출전", 24, true, Vector2(cw, 54))
		b.pressed.connect(func(): Game.start_endless(mi))
		vb.add_child(b)
	else:
		var lk := HBoxContainer.new()
		lk.alignment = BoxContainer.ALIGNMENT_CENTER
		lk.add_child(UI.icon(Assets.tex("lock"), 36))
		lk.add_child(UI.label("3번째 지역 클리어 시 해금", 16, UI.MUTED, 4))
		vb.add_child(lk)
	return p

func _overlay(title: String) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(c)
	var p := UI.panel(Color(0.07, 0.08, 0.14, 0.98), UI.GOLD, 22)
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var t := UI.label(title, 40, UI.GOLD, 10, "title_kr")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	(func(): UI.pop_in(p)).call_deferred()
	return [shade, vb]

func _close_button(shade: Control, after := Callable()) -> Control:
	var cc := CenterContainer.new()
	var close := UI.button("닫기", 24, true, Vector2(240, 56))
	close.pressed.connect(func():
		Audio.play("click", -4.0, 0.05)
		shade.queue_free()
		if after.is_valid():
			after.call())
	cc.add_child(close)
	return cc

## Hero roster: pick who leads the defense.
func _open_heroes() -> void:
	var o := _overlay("영웅 선택")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var cw := minf((vs.x - 140.0) / 2.0, 430.0)
	for id in DB.HEROES:
		var h: Dictionary = DB.HEROES[id]
		var unlocked := Game.hero_unlocked(id)
		var chosen: bool = Game.hero_id == id
		var p := UI.panel(Color(0.1, 0.12, 0.2, 0.96), UI.GOLD if chosen else (UI.GOLD_DARK if unlocked else Color(0.3, 0.3, 0.35)), 16)
		p.custom_minimum_size = Vector2(cw, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		p.add_child(cv)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var por := UI.icon(Assets.tex(h["portrait"]), 104 if vs.y >= 600.0 else 80)
		if not unlocked:
			por.modulate = Color(0.25, 0.25, 0.3)
		top.add_child(por)
		var nv := VBoxContainer.new()
		nv.add_child(UI.label(h["name"], 24, UI.GOLD if unlocked else UI.MUTED, 6))
		nv.add_child(UI.label(h["title"], 17, UI.PARCH, 4))
		var kind := "원거리 · 사거리 %.1f" % float(h["range"]) if h.get("ranged", false) else "근접 · 적을 막아섬"
		nv.add_child(UI.label(kind, 16, UI.TEXT, 3))
		top.add_child(nv)
		cv.add_child(top)
		var d := UI.label(h["desc"], 16, UI.TEXT if unlocked else UI.MUTED, 3)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(cw - 30, 0)
		cv.add_child(d)
		var st := UI.label("체력 %d · 공격력 %d-%d · 방어 %d%%\n스킬: %s (재사용 %ds)" % [h["hp"], h["dmg"][0], h["dmg"][1], int(float(h["armor"]) * 100), h["skill_name"], int(h["skill_cd"])], 16, UI.PARCH, 3)
		cv.add_child(st)
		var b: Button
		if not unlocked:
			b = UI.button("2번째 지역 클리어 시 해금", 18, false, Vector2(cw - 30, 52))
			b.disabled = true
		elif chosen:
			b = UI.button("✓ 출전 중", 22, false, Vector2(cw - 30, 52))
		else:
			b = UI.button("이 영웅으로 출전", 22, true, Vector2(cw - 30, 52))
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
	vb.add_child(_close_button(shade))

## Bestiary: every enemy met so far, with stats and how to counter it.
func _open_bestiary() -> void:
	var o := _overlay("적 도감")
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var grid := GridContainer.new()
	grid.columns = 5 if vs.x >= 1100.0 else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	hb.add_child(grid)
	var detail := UI.panel(Color(0.1, 0.11, 0.18, 0.95), UI.GOLD_DARK, 14)
	detail.custom_minimum_size = Vector2(minf(vs.x * 0.36, 420.0), minf(vs.y - 230.0, 380.0))
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	detail.add_child(dv)
	hb.add_child(detail)
	var show := func(t: String):
		for c in dv.get_children():
			c.queue_free()
		var e: Dictionary = DB.ENEMIES[t]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.add_child(UI.icon(Assets.tex("portrait_" + t), 84))
		var nv := VBoxContainer.new()
		nv.add_child(UI.label(e["name"], 24, UI.GOLD, 6))
		var tags := []
		if e.get("boss", false): tags.append("보스")
		if e.get("flying", false): tags.append("비행")
		if float(e["armor"]) >= 0.3: tags.append("중장갑")
		if float(e["mr"]) >= 0.3: tags.append("마법 저항")
		if float(e["speed"]) >= 3.0: tags.append("고속")
		nv.add_child(UI.label(" · ".join(tags) if not tags.is_empty() else "일반", 17, Color(1.0, 0.65, 0.5), 3))
		top.add_child(nv)
		dv.add_child(top)
		var spd := "빠름" if float(e["speed"]) >= 3.0 else ("느림" if float(e["speed"]) < 1.5 else "보통")
		var st := UI.label("체력 %d\n물리 방어 %d%%  ·  마법 저항 %d%%\n이동 속도 %s  ·  보상 %d 골드\n통과 시 생명 -%d" % [e["hp"], int(float(e["armor"]) * 100), int(float(e["mr"]) * 100), spd, e["gold"], e["lives"]], 18, UI.TEXT, 3)
		dv.add_child(st)
		var tip := UI.label("공략: " + str(e.get("desc", "")), 18, UI.PARCH, 3)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(detail.custom_minimum_size.x - 30, 0)
		dv.add_child(tip)
	var first := ""
	var seen_n := 0
	for t in DB.ENEMIES:
		var seen: bool = Game.seen_enemies.has(t)
		var b := UI.icon_button(Assets.tex("portrait_" + t), 78 if vs.y >= 600.0 else 64, Color(0.15, 0.16, 0.25, 0.95), 14)
		if not seen:
			b.modulate = Color(0.12, 0.12, 0.15)
			b.tooltip_text = "???"
			b.pressed.connect(func(): Audio.play("error", -6.0))
		else:
			seen_n += 1
			if first == "":
				first = t
			b.pressed.connect(func():
				Audio.play("click", -4.0, 0.05)
				show.call(t))
		grid.add_child(b)
	if first != "":
		show.call(first)
	else:
		dv.add_child(UI.label("아직 만난 적이 없습니다.\n전투에서 적을 만나면 기록됩니다.", 18, UI.MUTED, 3))
	var cnt := UI.label("발견: %d / %d" % [seen_n, DB.ENEMIES.size()], 18, UI.MUTED, 3)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cnt)
	vb.add_child(_close_button(shade))

## Achievements: lifetime goals, each worth one upgrade star.
func _open_achievements() -> void:
	var o := _overlay("업적  ★ %d / %d" % [Game.achievement_count(), DB.ACHIEVEMENTS.size()])
	var shade: Control = o[0]
	var vb: VBoxContainer = o[1]
	var vs := get_viewport().get_visible_rect().size
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(minf(vs.x - 80.0, 1100.0), minf(vs.y - 210.0, 480.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2 if vs.x >= 900.0 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var cell_w := (sc.custom_minimum_size.x - 30.0) / grid.columns
	for a in DB.ACHIEVEMENTS:
		var done: bool = Game.achievements.get(a["id"], false)
		var cp := PanelContainer.new()
		cp.custom_minimum_size = Vector2(cell_w, 0)
		cp.add_theme_stylebox_override("panel", UI.box(Color(0.12, 0.2, 0.14, 0.95) if done else Color(0.1, 0.12, 0.2, 0.95), UI.GOLD if done else Color(0.3, 0.3, 0.38), 12, 2, 4, 8))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		cp.add_child(hb)
		var ic := UI.icon(Assets.tex(a["icon"]), 56)
		if not done:
			ic.modulate = Color(0.55, 0.55, 0.6)
		hb.add_child(ic)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(a["name"], 20, UI.GOLD if done else UI.TEXT, 4))
		tv.add_child(UI.label(a["desc"], 15, UI.MUTED, 3))
		var cur := mini(int(Game.stats.get(a["stat"], 0)), int(a["goal"]))
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 10)
		pb.max_value = float(a["goal"])
		pb.value = cur
		var fg := StyleBoxFlat.new()
		fg.bg_color = UI.GOLD if done else Color(0.45, 0.6, 1.0)
		fg.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.05, 0.08)
		bg.set_corner_radius_all(4)
		pb.add_theme_stylebox_override("fill", fg)
		pb.add_theme_stylebox_override("background", bg)
		tv.add_child(pb)
		hb.add_child(tv)
		hb.add_child(UI.label("✓ ★1" if done else "%d/%d" % [cur, a["goal"]], 17, UI.GOLD if done else UI.MUTED, 3))
		grid.add_child(cp)
	var hint := UI.label("업적마다 ★1을 얻어 ‘왕국 강화’에 쓸 수 있습니다.", 16, UI.MUTED, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	vb.add_child(_close_button(shade))

## Kingdom-Rush style upgrade tree: spend stars earned in battle on permanent bonuses.
func _open_upgrades() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	var vs := get_viewport().get_visible_rect().size
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(c)
	var p := UI.panel(Color(0.07, 0.08, 0.14, 0.98), UI.GOLD, 22)
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 24)
	head.add_child(UI.label("왕국 강화", 40, UI.GOLD, 10, "title_kr"))
	var have := UI.label("보유 ★ %d" % Game.available_stars(), 28, UI.GOLD, 6)
	head.add_child(have)
	vb.add_child(head)
	var grid := GridContainer.new()
	var cols := 4 if vs.x >= 1100.0 else 3
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(minf(vs.x - 80.0, 1120.0), minf(vs.y - 230.0, 470.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(grid)
	vb.add_child(sc)
	var cell_w := (minf(vs.x - 80.0, 1120.0) - 10.0 * (cols - 1) - 20.0) / cols
	var refresh: Callable
	var cells := []
	for u in DB.UPGRADES:
		var cp := PanelContainer.new()
		cp.custom_minimum_size = Vector2(cell_w, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		cp.add_child(hb)
		hb.add_child(UI.icon(Assets.tex(u["icon"]), 64))
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(u["name"], 21, UI.TEXT, 4))
		var dl := UI.label(u["desc"], 15, UI.MUTED, 3)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		hb.add_child(tv)
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(78, 56)
		bt.add_theme_font_override("font", Assets.font("ui"))
		bt.add_theme_font_size_override("font_size", 20)
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
			refresh.call())
		cells.append([cp, bt, id, cost])
		grid.add_child(cp)
	refresh = func():
		have.text = "보유 ★ %d" % Game.available_stars()
		for cell in cells:
			var owned: bool = Game.upgrades.get(cell[2], false)
			var afford: bool = Game.available_stars() >= int(cell[3])
			(cell[0] as PanelContainer).add_theme_stylebox_override("panel", UI.box(Color(0.12, 0.2, 0.14, 0.95) if owned else Color(0.1, 0.12, 0.2, 0.95), UI.GOLD if owned else (UI.GOLD_DARK if afford else Color(0.3, 0.3, 0.35)), 12, 2, 4, 8))
			(cell[1] as Button).text = "보유" if owned else "★ %d" % cell[3]
			(cell[1] as Button).disabled = owned or not afford
	refresh.call()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var reset := UI.button("전부 환불", 20, false, Vector2(180, 54))
	reset.pressed.connect(func():
		Game.upgrades = {}
		Game.save()
		refresh.call())
	row.add_child(reset)
	var close := UI.button("닫기", 24, true, Vector2(220, 54))
	close.pressed.connect(func():
		shade.queue_free()
		if _select:
			_open_select())
	row.add_child(close)
	vb.add_child(row)
	var hint := UI.label("★는 지역 클리어(최대 3개)와 영웅 난이도 클리어(+1)로 얻습니다. 환불은 언제든 무료.", 15, UI.MUTED, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	(func(): UI.pop_in(p)).call_deferred()

func _open_settings() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(c)
	var p := UI.panel(Color(0.07, 0.08, 0.14, 0.97), UI.GOLD, 22)
	p.custom_minimum_size = Vector2(480, 0)
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	p.add_child(vb)
	var t := UI.label("설정", 44, UI.GOLD, 10, "title_kr")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for row in [["음악", Game.music_volume, "music"], ["효과음", Game.sfx_volume, "sfx"]]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var l := UI.label(row[0], 24, UI.TEXT, 4)
		l.custom_minimum_size.x = 90
		hb.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = 0.05
		s.value = row[1]
		s.custom_minimum_size = Vector2(280, 40)
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
	hq.add_theme_font_override("font", Assets.font("ui"))
	hq.add_theme_font_size_override("font_size", 22)
	hq.toggled.connect(func(v):
		Game.high_quality = v
		Game.apply_quality()
		Game.save())
	vb.add_child(hq)
	var rs := UI.button("진행 상황 초기화", 20, false, Vector2(300, 52))
	rs.pressed.connect(func():
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
		rs.text = "초기화 완료")
	vb.add_child(rs)
	var close := UI.button("닫기", 24, true, Vector2(300, 60))
	close.pressed.connect(shade.queue_free)
	var cc := CenterContainer.new()
	cc.add_child(close)
	vb.add_child(cc)
	(func(): UI.pop_in(p)).call_deferred()
