class_name WorldMap
extends Control
## Campaign map in the Kingdom Rush tradition: a painted world (VARCO image generation), shield flags
## for each region linked by a dotted road, and a parchment briefing card when a flag is tapped.

const MAP_SIZE := Vector2(1536, 864)
# flag positions in map UV (picked on the painted map: meadow road, river bridge, snow gate,
# moon-forest shrine, troll canyon, the black fortress, the east-coast falls, the sea temple ruins),
# plus the old hill-top colonnade in the north-west for endless mode
const NODES := [Vector2(0.30, 0.625), Vector2(0.335, 0.435), Vector2(0.462, 0.17), Vector2(0.645, 0.45), Vector2(0.872, 0.315),
	Vector2(0.785, 0.16), Vector2(0.925, 0.555), Vector2(0.805, 0.735)]
const ENDLESS := Vector2(0.115, 0.15)
const ROADS := [
	[Vector2(0.30, 0.625), Vector2(0.293, 0.53), Vector2(0.335, 0.435)],
	[Vector2(0.335, 0.435), Vector2(0.40, 0.405), Vector2(0.47, 0.355), Vector2(0.50, 0.29), Vector2(0.48, 0.22), Vector2(0.462, 0.17)],
	[Vector2(0.462, 0.17), Vector2(0.515, 0.25), Vector2(0.55, 0.335), Vector2(0.60, 0.405), Vector2(0.645, 0.45)],
	[Vector2(0.645, 0.45), Vector2(0.70, 0.515), Vector2(0.775, 0.54), Vector2(0.83, 0.465), Vector2(0.862, 0.39), Vector2(0.872, 0.315)],
	[Vector2(0.872, 0.315), Vector2(0.85, 0.25), Vector2(0.815, 0.2), Vector2(0.785, 0.16)],
	[Vector2(0.785, 0.16), Vector2(0.84, 0.115), Vector2(0.915, 0.15), Vector2(0.952, 0.26), Vector2(0.955, 0.4), Vector2(0.925, 0.555)],
	[Vector2(0.925, 0.555), Vector2(0.90, 0.63), Vector2(0.85, 0.69), Vector2(0.805, 0.735)],
]

var menu: Node  # main menu (opens the hero / bestiary / upgrade overlays)
var _map: TextureRect
var _roads: Control
var _flags: Control
var _card: Control
var _t := 0.0
var _pulse: Array = []
var _endless_pick := 0
var _stars_l: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_map = TextureRect.new()
	_map.texture = Assets.tex_path("res://assets/ui/world_map.jpg")
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	# soft vignette so the UI reads on top of the bright painting
	var vg := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.1, 1.1)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.02, 0.06, 0.55))
	gt.gradient = g
	vg.texture = gt
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vg)
	_roads = _Roads.new()
	_roads.owner_map = self
	_roads.set_anchors_preset(Control.PRESET_FULL_RECT)
	_roads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_roads)
	_flags = Control.new()
	_flags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flags)
	_build_chrome()
	resized.connect(_layout)
	_layout.call_deferred()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

## Cover-fit, but on very wide phones crop mostly the sea at the bottom so the snowy pass
## (flag 3, near the top edge) stays on screen.
func _map_rect() -> Rect2:
	var vs := size
	var s := maxf(vs.x / MAP_SIZE.x, vs.y / MAP_SIZE.y)
	var off := (vs - MAP_SIZE * s)
	off.x *= 0.5
	off.y *= 0.15
	return Rect2(off, MAP_SIZE * s)

func uv_to_screen(uv: Vector2) -> Vector2:
	var r := _map_rect()
	return r.position + uv * r.size

func _layout() -> void:
	var r := _map_rect()
	_map.position = r.position
	_map.size = r.size
	_rebuild_flags()

func _process(delta: float) -> void:
	_t += delta
	for p in _pulse:
		if is_instance_valid(p):
			var c := p as Control
			var k := 1.0 + sin(_t * 4.0) * 0.06
			c.scale = Vector2(k, k)

# ---------------------------------------------------------------- chrome (corners)

func _build_chrome() -> void:
	var back := UI.icon_button(Assets.tex("ic_close"), 64, UI.NAVY, 32, "red")
	back.position = Vector2(16, 14)
	back.pressed.connect(func():
		if menu and menu.has_method("_close_select"):
			menu.call("_close_select"))
	add_child(back)
	# stars counter (kingdom upgrades currency)
	var plate := UI.framed("slim", 6)
	plate.anchor_left = 1.0
	plate.anchor_right = 1.0
	plate.offset_left = -196
	plate.offset_right = -16
	plate.offset_top = 16
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(UI.icon(Assets.tex("star"), 34))
	_stars_l = UI.label("%d / %d" % [DB.total_stars(), DB.max_stars()], 26, UI.GOLD, 6, "ui_black")
	hb.add_child(_stars_l)
	plate.add_child(hb)
	add_child(plate)
	# bottom-right dock: upgrades / heroes / bestiary / achievements
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 10)
	dock.anchor_left = 0.0
	dock.anchor_right = 0.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_left = 16
	dock.offset_bottom = -12
	for it in [["ic_upgrade", "강화", "_open_upgrades", "gold"], ["ic_hero", "영웅", "_open_heroes", "red"], ["ic_book", "도감", "_open_bestiary", "brown"], ["ic_trophy", "업적", "_open_achievements", "purple"]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -6)
		col.alignment = BoxContainer.ALIGNMENT_END
		var b := UI.icon_button(Assets.tex(it[0]), 70, UI.NAVY, 35, "navy" if it[3] == "gold" else it[3])
		var fn: String = it[2]
		b.pressed.connect(func():
			if menu and menu.has_method(fn):
				menu.call(fn))
		col.add_child(b)
		var l := UI.label(it[1], 18, UI.TEXT, 6, "ui_black")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		if it[0] == "ic_upgrade" and Game.available_stars() > 0:
			var bd := UI.badge(str(Game.available_stars()), 28, 15)
			bd.position = Vector2(46, -4)
			b.add_child(bd)
		if it[0] == "ic_hero" and DB.unspent_talents() > 0:
			var bd := UI.badge(str(DB.unspent_talents()), 28, 15)
			bd.position = Vector2(46, -4)
			b.add_child(bd)
		dock.add_child(col)
	add_child(dock)

func refresh_stars() -> void:
	if _stars_l:
		_stars_l.text = "%d / %d" % [DB.total_stars(), DB.max_stars()]

# ---------------------------------------------------------------- flags

func _rebuild_flags() -> void:
	for c in _flags.get_children():
		c.queue_free()
	_pulse.clear()
	var newest := -1
	for i in DB.LEVELS.size():
		if Game.unlocked(i) and Game.stars[i] == 0:
			newest = i
	for i in DB.LEVELS.size():
		_flags.add_child(_flag(i, i == newest))
	_flags.add_child(_endless_flag())
	_roads.queue_redraw()

func _flag(i: int, newest: bool) -> Control:
	var unlocked := Game.unlocked(i)
	var kind := "locked"
	if unlocked:
		kind = "open" if Game.stars[i] == 0 else ("heroic" if Game.heroic[i] else "done")
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = uv_to_screen(NODES[i])
	var fl := _flag_button("flag_" + kind, str(i + 1) if unlocked else "", "" if unlocked else "lock")
	fl.position = Vector2(-30, -78)
	fl.pressed.connect(func():
		if unlocked:
			_open_card(i)
		else:
			Audio.play("click", -8.0)
			_shake(fl))
	holder.add_child(fl)
	if newest:
		var gl := UI.icon(UI.kit("glow"), 130)
		gl.position = Vector2(-65, -105)
		gl.modulate = Color(1, 0.9, 0.5, 0.75)
		holder.add_child(gl)
		holder.move_child(gl, 0)
		_pulse.append(fl)
	if unlocked:
		var st := UI.stars_row(Game.stars[i], 22)
		st.position = Vector2(-37, -10)
		st.size = Vector2(74, 22)
		holder.add_child(st)
	var name_p := UI.framed("pill", 2)
	var nl := UI.label(DB.LEVELS[i]["name"], 15, UI.TEXT if unlocked else UI.MUTED, 4)
	name_p.add_child(nl)
	name_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(name_p)
	(func():
		name_p.position = Vector2(-name_p.size.x * 0.5, 12 if unlocked else -4)).call_deferred()
	return holder

func _flag_button(tex: String, number: String, glyph: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 70)
	b.size = Vector2(60, 70)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s2 := UI.hd(tex, Vector4(42, 48, 42, 48), Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 12))
		if st == "hover":
			s2.modulate_color = Color(1.12, 1.12, 1.12)
		elif st == "pressed":
			s2.modulate_color = Color(0.85, 0.85, 0.85)
		b.add_theme_stylebox_override(st, s2)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if number != "":
		b.text = number
		b.add_theme_font_override("font", Assets.font("ui_black"))
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_constant_override("outline_size", 7)
		b.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	elif glyph != "":
		b.icon = Assets.tex(glyph)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 30)
	UI.juice(b)
	return b

func _endless_flag() -> Control:
	var unlocked := Game.endless_unlocked()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = uv_to_screen(ENDLESS)
	var fl := _flag_button("flag_endless" if unlocked else "flag_locked", "", "ic_endless" if unlocked else "lock")
	fl.position = Vector2(-30, -78)
	fl.pressed.connect(func():
		if unlocked:
			_open_endless_card()
		else:
			Audio.play("click", -8.0)
			_shake(fl))
	holder.add_child(fl)
	var name_p := UI.framed("pill", 2)
	var nl := UI.label("∞ 무한 모드" if unlocked else "∞ 무한 모드 (3지역 클리어)", 15, Color(0.92, 0.75, 1.0) if unlocked else UI.MUTED, 4)
	name_p.add_child(nl)
	name_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(name_p)
	(func(): name_p.position = Vector2(-name_p.size.x * 0.5, -2)).call_deferred()
	return holder

func _shake(c: Control) -> void:
	var x0 := c.position.x
	var tw := c.create_tween()
	for k in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tw.tween_property(c, "position:x", x0 + k, 0.05)

# ---------------------------------------------------------------- briefing card

func _close_card() -> void:
	if _card:
		_card.queue_free()
		_card = null

func _card_shell(title: String, ribbon_kind := "red") -> VBoxContainer:
	_close_card()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_card())
	add_child(shade)
	_card = shade
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(cc)
	var compact := size.y < 600.0
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", -26)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(wrap)
	var rib := UI.ribbon(title, 28 if compact else 32, ribbon_kind, 420)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rib.z_index = 1
	wrap.add_child(rib)
	var p := UI.framed("parch", 16 if compact else 20)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.custom_minimum_size = Vector2(560 if not compact else 600, 0)
	var holder := UI.with_close(p, _close_card, 48)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(holder)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8 if compact else 12)
	p.add_child(vb)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vb.add_child(spacer)
	(func(): UI.pop_in(wrap)).call_deferred()
	return vb

func _open_card(i: int) -> void:
	var d: Dictionary = DB.LEVELS[i]
	var compact := size.y < 600.0
	var vb := _card_shell("%d. %s" % [i + 1, tr(d["name"])])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var thumb_p := UI.framed("slim", 0)
	var img := TextureRect.new()
	img.texture = Assets.tex("level_%d" % i)
	img.custom_minimum_size = Vector2(220, 124) if compact else Vector2(240, 135)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb_p.add_child(img)
	row.add_child(thumb_p)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UI.ink(d.get("subtitle", ""), 20, Color(0.55, 0.18, 0.1), "ui_black"))
	var desc := UI.ink(d["desc"], 17, UI.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 0)
	info.add_child(desc)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	sr.add_child(UI.stars_row(Game.stars[i], 30))
	if Game.heroic[i]:
		var hb := UI.ink("영웅 클리어", 16, Color(0.6, 0.35, 0.02), "ui_black")
		sr.add_child(hb)
	info.add_child(sr)
	# enemies of this region
	var types := []
	for w in d["waves"]:
		for e in w:
			if not types.has(e[0]):
				types.append(e[0])
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 4)
	er.add_child(UI.ink("등장 적 ", 16, UI.INK_SOFT, "ui_black"))
	for tname in types:
		var ic := UI.icon(Assets.tex("portrait_" + tname), 34)
		if not Game.seen_enemies.get(tname, false):
			ic.modulate = Color(0.05, 0.05, 0.08, 0.85)
		er.add_child(ic)
	vb.add_child(er)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 18)
	meta.add_child(UI.stat("skull", tr("웨이브 %d") % d["waves"].size(), 17))
	meta.add_child(UI.stat("heart", tr("생명 %d") % (10 if Game.difficulty == 1 else int(d["lives"])), 17))
	meta.add_child(UI.stat("coin", tr("시작 골드 %d") % int(int(d["gold"]) * (1.3 if Game.difficulty == 2 else 1.0)), 17))
	vb.add_child(meta)
	vb.add_child(UI.divider(520))
	# difficulty + start
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(bottom)
	for dv in [[2, "쉬움"], [0, "일반"], [1, "영웅"]]:
		var sel: bool = Game.difficulty == dv[0]
		var b := UI.button(tr(dv[1], "difficulty"), 19, false, Vector2(86, 54), "gold" if sel else "gray")
		var val: int = dv[0]
		b.pressed.connect(func():
			Game.difficulty = val
			Game.save()
			_open_card(i))
		bottom.add_child(b)
	var go := UI.button("출전", 30, true, Vector2(200, 62), "red")
	go.icon = Assets.tex("ic_play")
	go.pressed.connect(func(): Game.start_level(i))
	bottom.add_child(go)
	if Game.difficulty == 1:
		var note := UI.ink("영웅 난이도: 적 체력 +15% · 공격력 +10% · 생명 10 — 클리어 시 보너스 ★", 15, Color(0.6, 0.16, 0.08))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(note)
	elif Game.difficulty == 2:
		var note2 := UI.ink("쉬움: 적 체력 -28% · 공격력 -15% · 시작 골드 +30% — 별은 그대로 얻습니다", 15, Color(0.12, 0.42, 0.16))
		note2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(note2)
	# iron challenge: unlocked by three stars here
	var irow := HBoxContainer.new()
	irow.alignment = BoxContainer.ALIGNMENT_CENTER
	irow.add_theme_constant_override("separation", 12)
	if Game.stars[i] >= 3:
		var ib := UI.button("철인 도전", 19, false, Vector2(190, 48), "purple")
		ib.icon = Assets.tex("skull")
		ib.add_theme_constant_override("icon_max_width", 24)
		ib.pressed.connect(func(): Game.start_challenge(i))
		irow.add_child(ib)
		var il := UI.ink("✓ 철인 배지 획득" if Game.iron_done(i) else "생명 3 · 주문 없음 · 골드 +40%", 15, Color(0.12, 0.42, 0.16) if Game.iron_done(i) else UI.INK_SOFT, "ui_black")
		il.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		irow.add_child(il)
	else:
		var lk := UI.ink("별 3개를 얻으면 철인 도전이 열립니다", 15, UI.INK_SOFT)
		irow.add_child(lk)
	vb.add_child(irow)

func _open_endless_card() -> void:
	var maps := []
	for i in DB.LEVELS.size():
		if Game.stars[i] > 0:
			maps.append(i)
	if maps.is_empty():
		maps.append(0)
	_endless_pick = clampi(_endless_pick, 0, maps.size() - 1)
	var mi: int = maps[_endless_pick]
	var vb := _card_shell("∞ 무한 모드", "blue")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var thumb_p := UI.framed("slim", 0)
	var img := TextureRect.new()
	img.texture = Assets.tex("level_%d" % mi)
	img.custom_minimum_size = Vector2(240, 135)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb_p.add_child(img)
	row.add_child(thumb_p)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var desc := UI.ink("끝없이 강해지는 적을 상대로 몇 웨이브까지 버틸 수 있을까? 10웨이브마다 보스가 등장합니다.", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 0)
	info.add_child(desc)
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 6)
	var prev := UI.button("◀", 20, false, Vector2(48, 44), "blue")
	var nm := UI.ink(DB.LEVELS[mi]["name"], 19, UI.INK, "ui_black")
	nm.custom_minimum_size = Vector2(140, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nxt := UI.button("▶", 20, false, Vector2(48, 44), "blue")
	prev.pressed.connect(func():
		_endless_pick = (_endless_pick - 1 + maps.size()) % maps.size()
		_open_endless_card())
	nxt.pressed.connect(func():
		_endless_pick = (_endless_pick + 1) % maps.size()
		_open_endless_card())
	mr.add_child(prev)
	mr.add_child(nm)
	mr.add_child(nxt)
	info.add_child(mr)
	info.add_child(UI.stat("crown", tr("최고 기록: 웨이브 %d") % int(Game.endless_best.get(str(mi), 0)), 18))
	vb.add_child(UI.divider(520))
	var cc := CenterContainer.new()
	var go := UI.button("출전", 30, true, Vector2(240, 62), "purple")
	go.icon = Assets.tex("ic_play")
	go.pressed.connect(func(): Game.start_endless(mi))
	cc.add_child(go)
	vb.add_child(cc)

# ---------------------------------------------------------------- dotted roads

class _Roads extends Control:
	var owner_map: WorldMap

	func _draw() -> void:
		if owner_map == null:
			return
		for si in WorldMap.ROADS.size():
			var reached := Game.unlocked(si + 1)
			if not Game.unlocked(si):
				continue
			var pts: Array = []
			for uv in WorldMap.ROADS[si]:
				pts.append(owner_map.uv_to_screen(uv))
			var curve := _spline(pts, 10)
			var dash := 9.0
			var gap := 8.0
			var acc := 0.0
			var on := true
			var col := Color(1.0, 0.93, 0.7, 0.95) if reached else Color(1.0, 0.93, 0.7, 0.45)
			for k in range(curve.size() - 1):
				var a: Vector2 = curve[k]
				var b: Vector2 = curve[k + 1]
				var seg := a.distance_to(b)
				var t := 0.0
				while t < seg:
					var left := (dash if on else gap) - acc
					var step := minf(left, seg - t)
					if on:
						var p0 := a.lerp(b, t / seg)
						var p1 := a.lerp(b, (t + step) / seg)
						draw_line(p0, p1, Color(0.12, 0.07, 0.03, 0.7), 7.0, true)
						draw_line(p0, p1, col, 4.0, true)
					t += step
					acc += step
					if acc >= (dash if on else gap) - 0.001:
						acc = 0.0
						on = not on

	func _spline(p: Array, n: int) -> Array:
		var out: Array = []
		for i in p.size() - 1:
			var p0: Vector2 = p[maxi(i - 1, 0)]
			var p1: Vector2 = p[i]
			var p2: Vector2 = p[i + 1]
			var p3: Vector2 = p[mini(i + 2, p.size() - 1)]
			for k in n:
				var t := float(k) / n
				var t2 := t * t
				var t3 := t2 * t
				out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		out.append(p[p.size() - 1])
		return out
