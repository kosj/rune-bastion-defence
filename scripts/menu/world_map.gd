class_name WorldMap
extends Control
## Campaign map in the Kingdom Rush tradition: a painted world (VARCO image generation), shield flags
## for each region linked by a dotted road, and a parchment briefing card when a flag is tapped.

const MAP_SIZE := Vector2(1536, 864)
# flag positions in map UV (picked on the painted map: meadow road, river bridge, snow gate,
# moon-forest shrine, troll canyon, the black fortress, the east-coast falls, the sea temple ruins,
# the south harbour and the royal capital),
# plus the old hill-top colonnade in the north-west for endless mode
const NODES := [Vector2(0.30, 0.625), Vector2(0.335, 0.435), Vector2(0.462, 0.17), Vector2(0.645, 0.45), Vector2(0.872, 0.315),
	Vector2(0.785, 0.16), Vector2(0.925, 0.555), Vector2(0.805, 0.735), Vector2(0.37, 0.835), Vector2(0.165, 0.42),
	Vector2(0.70, 0.635)]  # bonus: the shadow hollow, deep in the moonlit forest
const ENDLESS := Vector2(0.115, 0.15)
const ROADS := [
	[Vector2(0.30, 0.625), Vector2(0.293, 0.53), Vector2(0.335, 0.435)],
	[Vector2(0.335, 0.435), Vector2(0.40, 0.405), Vector2(0.47, 0.355), Vector2(0.50, 0.29), Vector2(0.48, 0.22), Vector2(0.462, 0.17)],
	[Vector2(0.462, 0.17), Vector2(0.515, 0.25), Vector2(0.55, 0.335), Vector2(0.60, 0.405), Vector2(0.645, 0.45)],
	[Vector2(0.645, 0.45), Vector2(0.70, 0.515), Vector2(0.775, 0.54), Vector2(0.83, 0.465), Vector2(0.862, 0.39), Vector2(0.872, 0.315)],
	[Vector2(0.872, 0.315), Vector2(0.85, 0.25), Vector2(0.815, 0.2), Vector2(0.785, 0.16)],
	[Vector2(0.785, 0.16), Vector2(0.84, 0.115), Vector2(0.915, 0.15), Vector2(0.952, 0.26), Vector2(0.955, 0.4), Vector2(0.925, 0.555)],
	[Vector2(0.925, 0.555), Vector2(0.90, 0.63), Vector2(0.85, 0.69), Vector2(0.805, 0.735)],
	# by sea from the temple to the south harbour, then north through the town to the capital
	[Vector2(0.805, 0.735), Vector2(0.74, 0.83), Vector2(0.62, 0.90), Vector2(0.47, 0.925), Vector2(0.40, 0.895), Vector2(0.37, 0.835)],
	[Vector2(0.37, 0.835), Vector2(0.31, 0.80), Vector2(0.245, 0.745), Vector2(0.205, 0.665), Vector2(0.215, 0.58), Vector2(0.195, 0.51), Vector2(0.165, 0.42)],
	# the bonus region opens after the capital; its path leads from the moonlit forest's glade
	[Vector2(0.645, 0.45), Vector2(0.665, 0.52), Vector2(0.71, 0.565), Vector2(0.70, 0.635)],
]

var menu: Node  # main menu (opens the hero / bestiary / upgrade overlays)
var _world: Control  # the painting with its roads and flags (moved as one when the map pans)
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
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_world.add_child(_map)
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
	_world.add_child(vg)
	_roads = _Roads.new()
	_roads.owner_map = self
	_roads.set_anchors_preset(Control.PRESET_FULL_RECT)
	_roads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_roads)
	_flags = Control.new()
	_flags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_flags)
	_build_chrome()
	resized.connect(_layout)
	Game.layout_changed.connect(_on_layout_changed)
	_layout.call_deferred()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

## Cover-fit, except that every flag (with its pin above and name below) must stay on
## screen: on squarer screens (tablets, 4:3) a plain cover would cut the flags at the
## left and right edges, and on very wide phones the harbour flag at the bottom. The map
## is then shrunk just enough, and the strips this leaves are filled with a darkened
## mirror of the map's edge (see _layout).
const FLAG_SPAN_X := Vector2(0.115 - 0.06, 0.925 + 0.055)
const FLAG_SPAN_Y := Vector2(0.15 - 0.13, 0.835 + 0.075)

var _pan_x := NAN  # upright: horizontal scroll of the painting (NAN = start at the newest region)
var _drag_from := NAN

func _map_rect() -> Rect2:
	var vs := size
	if Game.tall:
		# upright: the painting fills the height and the player pans it sideways; it opens on
		# the region to play next
		var st := vs.y / MAP_SIZE.y
		var mw := MAP_SIZE.x * st
		if is_nan(_pan_x):
			var focus := NODES[0]
			for i in DB.LEVELS.size():
				if Game.unlocked(i):
					focus = NODES[i]
			_pan_x = vs.x * 0.5 - focus.x * mw
		_pan_x = clampf(_pan_x, minf(vs.x - mw, 0.0), 0.0)
		return Rect2(Vector2(_pan_x, 0), MAP_SIZE * st)
	var cover := maxf(vs.x / MAP_SIZE.x, vs.y / MAP_SIZE.y)
	var contain := minf(vs.x / MAP_SIZE.x, vs.y / MAP_SIZE.y)
	var fit_x := vs.x / (MAP_SIZE.x * (FLAG_SPAN_X.y - FLAG_SPAN_X.x))
	var fit_y := vs.y / (MAP_SIZE.y * (FLAG_SPAN_Y.y - FLAG_SPAN_Y.x))
	var s := maxf(minf(cover, minf(fit_x, fit_y)), contain)
	var ms := MAP_SIZE * s
	var off := Vector2.ZERO
	for ax in 2:
		var span: Vector2 = FLAG_SPAN_X if ax == 0 else FLAG_SPAN_Y
		if ms[ax] > vs[ax]:
			# larger than the screen on this axis: centre the flags, never uncover an edge
			off[ax] = clampf(vs[ax] * 0.5 - (span.x + span.y) * 0.5 * ms[ax], vs[ax] - ms[ax], 0.0)
		else:
			off[ax] = (vs[ax] - ms[ax]) * 0.5
	return Rect2(off, ms)

## A point of the painting in the painting's own coordinates (the world layer is moved to the map
## rect, so this is also where the flags and roads are drawn).
func uv_to_screen(uv: Vector2) -> Vector2:
	return uv * _map_rect().size

func _gui_input(ev: InputEvent) -> void:
	if not Game.tall:
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag_from = (ev as InputEventMouseButton).position.x if ev.pressed else NAN
	elif ev is InputEventMouseMotion and not is_nan(_drag_from):
		_pan_x += (ev as InputEventMouseMotion).relative.x
		_world.position = _map_rect().position

var _bands: Array = []

func _layout() -> void:
	var r := _map_rect()
	_world.position = r.position
	_world.size = r.size
	_map.position = Vector2.ZERO
	_map.size = r.size
	for b in _bands:
		b.queue_free()
	_bands.clear()
	var s := r.size.x / MAP_SIZE.x
	var gaps := [r.position.y, size.y - r.end.y, r.position.x, size.x - r.end.x]
	for side in 4:
		var g: float = gaps[side]
		if g < 1.0 or Game.tall:
			continue
		var at := AtlasTexture.new()
		at.atlas = _map.texture
		var band := TextureRect.new()
		band.texture = at
		band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		band.stretch_mode = TextureRect.STRETCH_SCALE
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.modulate = Color(0.45, 0.45, 0.52)
		if side < 2:
			var th := minf(g / s, MAP_SIZE.y * 0.5)
			at.region = Rect2(0, 0 if side == 0 else MAP_SIZE.y - th, MAP_SIZE.x, th)
			band.flip_v = true
			band.position = Vector2(r.position.x, 0.0 if side == 0 else r.end.y)
			band.size = Vector2(r.size.x, g)
		else:
			var tw := minf(g / s, MAP_SIZE.x * 0.5)
			at.region = Rect2(0 if side == 2 else MAP_SIZE.x - tw, 0, tw, MAP_SIZE.y)
			band.flip_h = true
			band.position = Vector2(0.0 if side == 2 else r.end.x, r.position.y)
			band.size = Vector2(g, r.size.y)
		add_child(band)
		move_child(band, _world.get_index())
		_bands.append(band)
	_rebuild_flags()

func _process(delta: float) -> void:
	_t += delta
	for p in _pulse:
		if is_instance_valid(p):
			var c := p as Control
			var k := 1.0 + sin(_t * 4.0) * 0.06
			c.scale = Vector2(k, k)

# ---------------------------------------------------------------- chrome (corners)

var _chrome: Array = []

## The phone was turned: the open briefing closes, the map and its corners lay out again.
func _on_layout_changed() -> void:
	_close_card()
	_pan_x = NAN
	_rebuild_chrome()
	_layout()

func _rebuild_chrome() -> void:
	for c in _chrome:
		if is_instance_valid(c):
			c.queue_free()
	_chrome.clear()
	_build_chrome()

func _build_chrome() -> void:
	var t := Game.tall
	var back := UI.round_button(Assets.tex("ic_close"), 52 if t else 58)
	back.position = Vector2(14, 14)
	back.pressed.connect(func():
		if menu and menu.has_method("_close_select"):
			menu.call("_close_select"))
	add_child(back)
	# stars counter (kingdom upgrades currency)
	var plate := UI.framed("bar", 2)
	plate.anchor_left = 1.0
	plate.anchor_right = 1.0
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.offset_left = -14
	plate.offset_right = -14
	plate.offset_top = 18
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(UI.icon(Assets.tex("star"), 28 if t else 32))
	_stars_l = UI.label("%d / %d" % [DB.total_stars(), DB.max_stars()], 22 if t else 24, UI.GOLD, 0, "ui_black")
	hb.add_child(_stars_l)
	plate.add_child(hb)
	add_child(plate)
	# bottom dock: upgrades / heroes / bestiary / achievements (centred under the thumb upright)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 14 if t else 12)
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if t:
		dock.anchor_left = 0.5
		dock.anchor_right = 0.5
		dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	else:
		dock.offset_left = 16
	dock.offset_bottom = -12
	for it in [["ic_upgrade", "강화", "_open_upgrades"], ["ic_hero", "영웅", "_open_heroes"], ["ic_book", "도감", "_open_bestiary"], ["ic_trophy", "업적", "_open_achievements"], ["ic_daily", "오늘의 도전", "_open_daily"]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_END
		var b := UI.round_button(Assets.tex(it[0]), 62)
		b.add_theme_constant_override("icon_max_width", 36)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var fn: String = it[2]
		b.pressed.connect(func():
			if fn == "_open_daily":
				_open_daily_card(b)
			elif menu and menu.has_method(fn):
				menu.call(fn))
		if fn == "_open_daily" and not Game.daily_unlocked():
			b.self_modulate = Color(0.6, 0.6, 0.66)
		col.add_child(b)
		var l := UI.label(it[1], 16, UI.TEXT, 5, "ui_black")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		var n := 0
		if it[0] == "ic_upgrade":
			n = Game.available_stars()
		elif it[0] == "ic_hero":
			n = DB.unspent_talents()
		elif it[0] == "ic_daily" and Game.daily_unlocked() and not Game.daily_done_today():
			n = 1
		if n > 0:
			var bd := UI.badge(str(n) if it[0] != "ic_daily" else "!", 26, 14)
			bd.position = Vector2(42, -4)
			b.add_child(bd)
		dock.add_child(col)
	add_child(dock)
	_chrome = [back, plate, dock]

func refresh_stars() -> void:
	# the counter and the dock's badges (stars left to spend, talent points)
	_rebuild_chrome()

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

var _card_w := 560.0

## The briefing sheet (UI.sheet): a tap beside it closes it.
func _card_shell(title: String, _ribbon_kind := "") -> VBoxContainer:
	_close_card()
	var shade := UI.sheet(self, title, {"width": 640, "dim": 0.45, "on_close": func(): _close_card()})
	_card = shade
	_card_w = UI.sheet_w(shade)
	return shade.get_meta("body")

func _close_card() -> void:
	if _card and is_instance_valid(_card):
		UI.dismiss(_card)
	_card = null

## Picture of a region: beside the text on a wide sheet, across the top of an upright one.
func _thumb(tex: Texture2D) -> Control:
	var tw := _card_w if Game.tall else 240.0
	var img := TextureRect.new()
	img.texture = tex
	img.custom_minimum_size = Vector2(tw, roundf(tw * 9.0 / 16.0))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# rounded corners like the wells around it
	var clip := PanelContainer.new()
	clip.add_theme_stylebox_override("panel", UI.flat(Color(0, 0, 0, 0.3), 12, Vector4.ZERO))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip.add_child(img)
	return clip

func _open_card(i: int) -> void:
	var d: Dictionary = DB.LEVELS[i]
	# while the player reads the briefing, load what this battle needs first (Content.warm)
	Content.warm(Assets.battle_models(i))
	var vb := _card_shell("%d. %s" % [i + 1, tr(d["name"])])
	var w := _card_w
	var row: BoxContainer = VBoxContainer.new() if Game.tall else HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if Game.tall else 16)
	vb.add_child(row)
	row.add_child(_thumb(Assets.tex("level_%d" % i)))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 10)
	var sub := UI.ink(d.get("subtitle", ""), 18, UI.GOLD, "ui_black")
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(sub)
	sr.add_child(UI.stars_row(Game.stars[i], 24))
	info.add_child(sr)
	var desc := UI.ink(d["desc"], 17, UI.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(w if Game.tall else w - 256.0, 0)
	info.add_child(desc)
	if Game.heroic[i]:
		info.add_child(UI.ink("영웅 클리어", UI.T_SMALL, UI.GOLD, "ui_black"))
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 18)
	meta.add_child(UI.stat("skull", tr("웨이브 %d") % d["waves"].size(), 16))
	meta.add_child(UI.stat("heart", tr("생명 %d") % (10 if Game.difficulty == 1 else int(d["lives"])), 16))
	meta.add_child(UI.stat("coin", tr("시작 골드 %d") % int(int(d["gold"]) * (1.3 if Game.difficulty == 2 else 1.0)), 16))
	info.add_child(meta)
	# enemies of this region (unmet ones as silhouettes)
	var types := []
	for wv in d["waves"]:
		for e in wv:
			if not types.has(e[0]):
				types.append(e[0])
	var er := HFlowContainer.new()
	er.add_theme_constant_override("h_separation", 4)
	er.add_theme_constant_override("v_separation", 4)
	var el := UI.ink("등장 적", UI.T_SMALL, UI.INK_SOFT, "ui_black")
	el.custom_minimum_size.y = 36
	el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	er.add_child(el)
	for tname in types:
		var ic := UI.bust(Assets.tex("portrait_" + tname), 36, 1.55, Vector2(0.5, 0.34))
		if not Game.seen_enemies.get(tname, false):
			ic.modulate = Color(0.05, 0.05, 0.08, 0.85)
		er.add_child(ic)
	vb.add_child(er)
	# difficulty: three chips, what the chosen one changes written under them
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	var dl := UI.ink("난이도", UI.T_BODY, UI.INK)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr.add_child(dl)
	for dv in [[2, "쉬움"], [0, "일반"], [1, "영웅"]]:
		var sel: bool = Game.difficulty == dv[0]
		var b := UI.button(tr(dv[1], "difficulty"), 17, false, Vector2(80, 44), "primary" if sel else "ghost")
		var val: int = dv[0]
		b.pressed.connect(func():
			Game.difficulty = val
			Game.save()
			_open_card(i))
		dr.add_child(b)
	vb.add_child(dr)
	var notes := {1: "영웅 난이도: 적 체력 +15% · 공격력 +10% · 생명 10 — 클리어 시 보너스 ★", 2: "쉬움: 적 체력 -28% · 공격력 -15% · 시작 골드 +30% — 별은 그대로 얻습니다"}
	if notes.has(Game.difficulty):
		var note := UI.ink(notes[Game.difficulty], 15, UI.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(note)
	# iron challenge (three stars here) on the left, the way into the battle on the right
	var btns: Array = []
	if Game.stars[i] >= 3:
		var ib := UI.button("철인 도전", 18, false, Vector2(0, 58), "special")
		ib.icon = Assets.tex("skull")
		ib.pressed.connect(func(): Game.start_challenge(i))
		btns.append(ib)
	var go := UI.button("출전", 26, true, Vector2(0, 58), "primary")
	go.icon = Assets.tex("ic_play")
	go.pressed.connect(func(): Game.start_level(i))
	go.grab_focus.call_deferred(true)  # Enter starts the battle (ring hidden until keyboard navigation)
	btns.append(go)
	var ar := UI.action_row(btns)
	go.size_flags_stretch_ratio = 1.6
	vb.add_child(ar)
	var il := UI.ink(("✓ 철인 배지 획득" if Game.iron_done(i) else "철인 도전: 생명 3, 주문 없음, 골드 +40%") if Game.stars[i] >= 3 else "별 3개를 얻으면 철인 도전이 열립니다", 15, UI.SAGE if Game.iron_done(i) else UI.MUTED)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(il)

func _open_endless_card() -> void:
	var maps := []
	for i in DB.LEVELS.size():
		if Game.stars[i] > 0:
			maps.append(i)
	if maps.is_empty():
		maps.append(0)
	_endless_pick = clampi(_endless_pick, 0, maps.size() - 1)
	var mi: int = maps[_endless_pick]
	var vb := _card_shell("∞ 무한 모드")
	var w := _card_w
	var row: BoxContainer = VBoxContainer.new() if Game.tall else HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if Game.tall else 16)
	vb.add_child(row)
	row.add_child(_thumb(Assets.tex("level_%d" % mi)))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var desc := UI.ink("끝없이 강해지는 적을 상대로 몇 웨이브까지 버틸 수 있을까? 10웨이브마다 보스가 등장합니다.", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(w if Game.tall else w - 256.0, 0)
	info.add_child(desc)
	# which battlefield: a stepper
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 6)
	var prev := UI.button("◀", 18, false, Vector2(48, 44), "secondary")
	var nm := UI.ink(DB.LEVELS[mi]["name"], 18, UI.INK, "ui_black")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nxt := UI.button("▶", 18, false, Vector2(48, 44), "secondary")
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
	info.add_child(UI.stat("crown", tr("최고 기록: 웨이브 %d") % int(Game.endless_best.get(str(mi), 0)), 17))
	var go := UI.button("출전", 26, true, Vector2(0, 58), "primary")
	go.icon = Assets.tex("ic_play")
	go.pressed.connect(func(): Game.start_endless(mi))
	go.grab_focus.call_deferred(true)
	vb.add_child(UI.action_row([go]))

# ---------------------------------------------------------------- daily challenge

## Today's challenge: the region, its two twists, the reward and the streak.
func _open_daily_card(from: Control) -> void:
	if not Game.daily_unlocked():
		Audio.play("click", -8.0)
		_shake(from)
		_toast_locked(tr("오늘의 도전은 2지역을 클리어하면 열립니다"))
		return
	var dd := Game.daily_today()
	var mi: int = dd["level"]
	var vb := _card_shell("오늘의 도전")
	var w := _card_w
	var row: BoxContainer = VBoxContainer.new() if Game.tall else HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if Game.tall else 16)
	vb.add_child(row)
	row.add_child(_thumb(Assets.tex("level_%d" % mi)))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UI.ink(DB.LEVELS[mi]["name"], 22, UI.INK, "title_kr"))
	var iw := w if Game.tall else w - 256.0
	for m in dd["mods"]:
		# each twist: its icon, the name, and what it does underneath
		var md: Dictionary = DB.DAILY_MODS[m]
		var mr := HBoxContainer.new()
		mr.add_theme_constant_override("separation", 10)
		var mi_ic := UI.icon(Assets.tex(md["icon"]), 34)
		mi_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mr.add_child(mi_ic)
		var mc := VBoxContainer.new()
		mc.add_theme_constant_override("separation", -2)
		mc.add_child(UI.ink(md["name"], 18, UI.INK, "ui_black"))
		var ml := UI.ink(md["desc"], UI.T_SMALL, UI.INK_SOFT)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.custom_minimum_size = Vector2(iw - 44.0, 0)
		mc.add_child(ml)
		mr.add_child(mc)
		info.add_child(mr)
	var done := Game.daily_done_today()
	var rew := UI.ink(tr("오늘 완료! 내일 새 도전이 열립니다") if done else (tr("첫 승리 보상: 영웅 경험치 +%d") % DB.DAILY_XP), UI.T_SMALL, UI.GOLD if not done else UI.INK_SOFT, "ui_black")
	rew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rew.custom_minimum_size = Vector2(iw, 0)
	info.add_child(rew)
	# the streak once there is one (a "0 days" line reads as a scolding before the first win)
	var best := int(Game.stats.get("daily_streak_best", 0))
	if best > 0:
		info.add_child(UI.stat("star", tr("연속 %d일 · 최고 %d일") % [Game.daily_streak(), best], 17))
	var go := UI.button("다시 도전" if done else "도전", 26, true, Vector2(0, 58), "primary")
	go.icon = Assets.tex("ic_play")
	go.pressed.connect(func(): Game.start_daily())
	go.grab_focus.call_deferred(true)
	vb.add_child(UI.action_row([go]))

func _toast_locked(text: String) -> void:
	var l := UI.label(text, 20, UI.TEXT, 6, "ui_black")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = -150
	l.offset_bottom = -120
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

# ---------------------------------------------------------------- dotted roads

class _Roads extends Control:
	var owner_map: WorldMap

	func _draw() -> void:
		if owner_map == null:
			return
		for si in WorldMap.ROADS.size():
			var reached := Game.unlocked(si + 1)
			if not Game.unlocked(si) or (si + 1 > DB.FINAL_LEVEL and not reached):
				continue  # (a bonus region's road appears once it opens)
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
