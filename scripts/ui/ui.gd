class_name UI
## UI style factory. Textured fantasy kit (tools/make_ui_kit.py): gold-trimmed navy enamel panels,
## parchment cards, gem buttons, round slots, ribbons and bars, plus gold-gradient titles and
## press/hover "juice" on every button.

const GOLD := Color(0.98, 0.78, 0.32)
const GOLD_DARK := Color(0.62, 0.42, 0.12)
const NAVY := Color(0.07, 0.09, 0.16, 0.92)
const NAVY_LIGHT := Color(0.13, 0.17, 0.29, 0.95)
const PARCH := Color(0.96, 0.9, 0.76)
const INK := Color(0.24, 0.15, 0.08)  # text on parchment
const INK_SOFT := Color(0.42, 0.3, 0.18)
const RED := Color(0.86, 0.26, 0.22)
const GREEN := Color(0.36, 0.78, 0.38)
const TEXT := Color(0.97, 0.94, 0.86)
const MUTED := Color(0.72, 0.74, 0.82)

const KIT := "res://assets/ui/kit/%s.png"

# kind -> [texture, margins(l,t,r,b), shadow pad baked into the texture, frame width]
const FRAMES := {
	"dark": ["panel_dark", Vector4(30, 30, 30, 30), 7.0, 7.0],
	"slim": ["panel_slim", Vector4(22, 22, 22, 22), 7.0, 4.0],
	"parch": ["panel_parch", Vector4(28, 28, 28, 28), 7.0, 5.0],
	"leather": ["panel_leather", Vector4(30, 30, 30, 30), 7.0, 6.0],
	"pill": ["pill", Vector4(14, 14, 14, 14), 2.0, 2.0],
}

static var _tex_cache := {}
static var _title_shader: Shader
static var _medal_shader: Shader
static var _theme: Theme

static func kit(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(KIT % name)
	return _tex_cache[name]

static func hd(tex_name: String, margins: Vector4, expand := Vector4.ZERO, content := Vector4(8, 8, 8, 8)) -> StyleBoxHD:
	var s := StyleBoxHD.new()
	s.texture = kit(tex_name)
	s.margins = margins
	s.expand = expand
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	return s

## Framed panel style: "dark" (enamel + gold), "slim", "parch" (parchment), "leather", "pill".
static func frame(kind := "dark", pad := 12.0) -> StyleBoxHD:
	var f: Array = FRAMES[kind]
	var e: float = f[2]
	var c: float = f[3] + pad
	return hd(f[0], f[1], Vector4(e, e, e, e), Vector4(c, c, c, c))

## Backwards-compatible style helper: picks the kit frame that best matches the old flat parameters.
static func box(bg: Color, border := GOLD_DARK, radius := 14, bw := 3, shadow := 8, pad := 12) -> StyleBox:
	var kind := "dark"
	if bg.get_luminance() > 0.55:
		kind = "parch"
	elif radius <= 12 or bw <= 2:
		kind = "slim"
	var s := frame(kind, maxf(pad - 4.0, 4.0))
	return s

static func panel(bg := NAVY, border := GOLD_DARK, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius))
	return p

static func framed(kind := "dark", pad := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(kind, pad))
	return p

static func label(text: String, size := 22, color := TEXT, outline := 6, font := "ui") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06, 0.95))
	return l

## Dark ink text for parchment cards (no outline).
static func ink(text: String, size := 20, color := INK, font := "ui") -> Label:
	var l := label(text, size, color, 0, font)
	return l

## A character portrait shown inside a round medallion: the picture is zoomed to the head
## and shoulders and clipped to a soft-edged circle, so a figure never spills over the frame
## or shows the square edge of its render. Put it inside a round slot of the same size.
static func portrait(tex: Texture2D, sz: float, zoom := 1.45, focus := Vector2(0.5, 0.35)) -> TextureRect:
	return _portrait_rect(tex, sz, zoom, focus, true)

## A free-standing bust (cards, dialogue, enemy lists): zoomed in, and the bottom of the
## picture fades out instead of ending in a hard line.
static func bust(tex: Texture2D, sz: float, zoom := 1.25, focus := Vector2(0.5, 0.42)) -> TextureRect:
	return _portrait_rect(tex, sz, zoom, focus, false)

static func _portrait_rect(tex: Texture2D, sz: float, zoom: float, focus: Vector2, round: bool) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(sz, sz)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _medal_shader == null:
		_medal_shader = Shader.new()
		_medal_shader.code = """shader_type canvas_item;
uniform float zoom = 1.35;
uniform vec2 focus = vec2(0.5, 0.36);
uniform bool round = true;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 uv = (UV - vec2(0.5)) / zoom + focus;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec2 inb = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	c.a *= inb.x * inb.y;
	if (round) {
		c.a *= 1.0 - smoothstep(0.93, 1.0, length(UV - vec2(0.5)) * 2.0);
	} else {
		c.a *= 1.0 - smoothstep(0.8, 1.0, UV.y);
	}
	COLOR = c * tint;
}"""
	var m := ShaderMaterial.new()
	m.shader = _medal_shader
	m.set_shader_parameter("zoom", zoom)
	m.set_shader_parameter("focus", focus)
	m.set_shader_parameter("round", round)
	t.material = m
	return t

## Breaks a label's text only at spaces (Hangul would otherwise split mid-word), for a fixed width.
static func wrap_words(l: Label, width: float) -> void:
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var out := ""
	var line := ""
	for w in l.text.split(" ", false):
		var cand: String = w if line == "" else line + " " + w
		if line != "" and f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out += line + "\n"
			line = w
		else:
			line = cand
	l.text = out + line
	l.autowrap_mode = TextServer.AUTOWRAP_OFF

## Gold-gradient title text with a dark outline and drop shadow (Kingdom-Rush style headings).
static func title(text: String, size := 44, font := "title_kr", outline := 10) -> Label:
	var l := label(text, size, Color.WHITE, outline, font)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.07, 0.02, 1.0))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 14))
	l.add_theme_constant_override("shadow_outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	var m := ShaderMaterial.new()
	m.shader = _gold_shader()
	l.material = m
	var upd := func():
		m.set_shader_parameter("height", maxf(l.size.y, 1.0))
	l.resized.connect(upd)
	upd.call()
	return l

static func _gold_shader() -> Shader:
	if _title_shader == null:
		_title_shader = Shader.new()
		_title_shader.code = """shader_type canvas_item;
uniform float height = 64.0;
uniform vec3 top_col = vec3(1.0, 0.98, 0.82);
uniform vec3 mid_col = vec3(1.0, 0.83, 0.38);
uniform vec3 bot_col = vec3(0.85, 0.5, 0.13);
varying float vy;
void vertex() { vy = VERTEX.y; }
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (COLOR.r > 0.98 && COLOR.g > 0.98 && COLOR.b > 0.98) {
		float t = clamp(vy / height, 0.0, 1.0);
		vec3 g = t < 0.55 ? mix(top_col, mid_col, t / 0.55) : mix(mid_col, bot_col, (t - 0.55) / 0.45);
		c.rgb = g;
	}
	COLOR = c;
}
"""
	return _title_shader

# ---------------------------------------------------------------- buttons

const BTN_KINDS := ["red", "blue", "green", "gold", "gray", "purple"]

static func _btn_styles(b: Button, kind: String) -> void:
	var m := Vector4(22, 20, 22, 24)
	var e := Vector4(4, 4, 4, 4)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var tex := "btn_%s_%s" % ["gray" if st == "disabled" else kind, "normal" if st == "disabled" else st]
		var c := Vector4(20, 7, 20, 13) if st != "pressed" else Vector4(20, 10, 20, 10)
		var s := hd(tex, m, e, c)
		if st == "disabled":
			s.modulate_color = Color(0.85, 0.85, 0.85, 0.9)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func button(text: String, size := 24, primary := true, min_size := Vector2(200, 64), kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", Assets.font("ui_black"))
	b.add_theme_font_size_override("font_size", size)
	var light := kind == "gold"
	b.add_theme_color_override("font_color", Color(0.3, 0.16, 0.03) if light else TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.25, 0.12, 0.02) if light else Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.25, 0.12, 0.02) if light else Color(1, 0.93, 0.7))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.93, 0.7))
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.78))
	b.add_theme_constant_override("outline_size", 0 if light else 6)
	b.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02, 0.9))
	b.add_theme_constant_override("icon_max_width", int(size * 1.3))
	b.add_theme_constant_override("h_separation", 8)
	_btn_styles(b, kind if kind != "" else ("red" if primary else "blue"))
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	juice(b)
	return b

static func icon_button(tex: Texture2D, sz := 72, bg := NAVY_LIGHT, radius := 40, kind := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(sz * 0.6))
	var k := kind if kind != "" else _slot_kind_for(bg)
	var e := sz * 4.0 / 88.0
	for st in ["normal", "hover", "pressed", "disabled"]:
		var pad := sz * 0.17
		var s := hd("slot_%s_%s" % [k, st], Vector4(48, 48, 48, 48), Vector4(e, e, e, e), Vector4(pad, pad, pad, pad))
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	juice(b)
	return b

static func _slot_kind_for(bg: Color) -> String:
	var h := bg.h
	if bg.s < 0.25:
		return "navy"
	if bg.r > bg.b * 1.6 and bg.r > bg.g * 1.4:
		return "red" if bg.r > 0.3 or bg.s > 0.7 else "brown"
	if bg.b > bg.r and bg.r > bg.g:
		return "purple"
	if bg.g > bg.r and bg.g > bg.b:
		return "green"
	if h > 0.04 and h < 0.12:
		return "brown"
	return "navy"

## Press squash / hover lift so every tap feels physical (UI anims ignore the 2x game speed).
static func juice(c: Control) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	if c is BaseButton:
		var bb := c as BaseButton
		bb.button_down.connect(func(): _tw_scale(c, 0.92, 0.06, false))
		bb.button_up.connect(func(): _tw_scale(c, 1.0, 0.22, true))
		if not Game.is_mobile:
			c.mouse_entered.connect(func():
				if not bb.disabled:
					_tw_scale(c, 1.05, 0.12, false))
			c.mouse_exited.connect(func(): _tw_scale(c, 1.0, 0.14, false))

static func _tw_scale(c: Control, s: float, d: float, back: bool) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	var p := tw.tween_property(c, "scale", Vector2(s, s), d)
	if back:
		p.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- pieces

static func icon(tex: Texture2D, sz := 32) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(sz, sz)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Ribbon banner with a title on it ("red" / "blue" / "dark").
static func ribbon(text: String, size := 34, kind := "red", min_w := 300.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := hd("ribbon_" + kind, Vector4(60, 0, 60, 0), Vector4(0, 0, 0, 0), Vector4(64, 4, 64, 16))
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(min_w, size * 1.9)
	var l := label(text, size, Color(1.0, 0.97, 0.88), 7, "title_kr")
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.03) if kind == "red" else Color(0.04, 0.06, 0.18))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func divider(w := 320.0) -> TextureRect:
	var t := icon(kit("divider"), 24)
	t.custom_minimum_size = Vector2(w, 22)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	return t

## Framed progress bar ("green" / "gold" / "red" / "blue" fill).
static func bar(fill := "green", w := 120.0, h := 14.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.001
	pb.custom_minimum_size = Vector2(w, h)
	var bg := hd("bar_frame", Vector4(9, 0, 9, 0), Vector4(1, 1, 1, 1), Vector4(0, 0, 0, 0))
	var fg := hd("bar_" + fill, Vector4(9, 0, 9, 0), Vector4(1, 1, 1, 1), Vector4(0, 0, 0, 0))
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb

## Round gold medallion with a number (hero level, wave count...).
static func badge(text: String, sz := 34, font_size := 20) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := icon(kit("badge"), sz)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(t)
	var l := label(text, font_size, GOLD, 5, "ui_black")
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "Text"
	c.add_child(l)
	return c

static func pop_in(c: Control, delay := 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)

static func stars_row(n: int, sz := 48) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	for i in 3:
		h.add_child(icon(Assets.tex("star" if i < n else "star_empty"), sz))
	return h

## Small icon + value pair used in stat lines (sword 12-18, clock 0.9s ...).
static func stat(icon_name: String, txt: String, size := 18, color := INK) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon(Assets.tex(icon_name), size + 6))
	var l := label(txt, size, color, 0 if color == INK else 4, "ui_black")
	hb.add_child(l)
	return hb


## Shared theme for every UI root: default fonts, sliders, toggles, scrollbars, tooltips, progress bars,
## so controls built without the factory still match the kit.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Assets.font("ui")
	t.default_font_size = 20
	# labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.03, 0.06, 0.95))
	# sliders: framed track, gold fill, gold knob
	var track := hd("bar_frame", Vector4(9, 0, 9, 0), Vector4(0, 2, 0, 2), Vector4(0, 7, 0, 7))
	var fill := hd("bar_gold", Vector4(9, 0, 9, 0), Vector4(0, 2, 0, 2), Vector4(0, 7, 0, 7))
	for cls in ["HSlider"]:
		t.set_stylebox("slider", cls, track)
		t.set_stylebox("grabber_area", cls, fill)
		t.set_stylebox("grabber_area_highlight", cls, fill)
		t.set_icon("grabber", cls, kit("knob"))
		t.set_icon("grabber_highlight", cls, kit("knob"))
		t.set_icon("grabber_disabled", cls, kit("knob"))
		t.set_constant("center_grabber", cls, 0)
	# toggles
	for cls in ["CheckButton"]:
		t.set_icon("checked", cls, kit("toggle_on"))
		t.set_icon("unchecked", cls, kit("toggle_off"))
		t.set_icon("checked_disabled", cls, kit("toggle_on"))
		t.set_icon("unchecked_disabled", cls, kit("toggle_off"))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_focus_color", cls, TEXT)
		t.set_font_size("font_size", cls, 21)
	# scrollbars
	var grab := hd("scroll_grab", Vector4(8, 14, 8, 14), Vector4.ZERO, Vector4(4, 4, 4, 4))
	var lane := StyleBoxFlat.new()
	lane.bg_color = Color(0, 0, 0, 0.28)
	lane.set_corner_radius_all(6)
	lane.content_margin_left = 6
	lane.content_margin_right = 6
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, lane)
		t.set_stylebox("scroll_focus", cls, lane)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab)
		t.set_stylebox("grabber_pressed", cls, grab)
	# progress bars
	t.set_stylebox("background", "ProgressBar", hd("bar_frame", Vector4(9, 0, 9, 0), Vector4(1, 1, 1, 1), Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", hd("bar_gold", Vector4(9, 0, 9, 0), Vector4(1, 1, 1, 1), Vector4.ZERO))
	# tooltips
	t.set_stylebox("panel", "TooltipPanel", frame("parch", 2))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 17)
	_theme = t
	return t


## Wraps a panel in a plain holder with a round close (x) button pinned to its top-right corner
## (a close button inside the PanelContainer itself would be stretched over the content).
static func with_close(panel: Control, on_close: Callable, sz := 50) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var x := icon_button(Assets.tex("ic_close"), sz, NAVY, sz / 2, "red")
	x.pressed.connect(on_close)
	holder.add_child(x)
	var fit := func():
		holder.custom_minimum_size = panel.size
		x.position = Vector2(panel.size.x - sz * 0.8, -sz * 0.3)
	panel.resized.connect(fit)
	fit.call_deferred()
	return holder
