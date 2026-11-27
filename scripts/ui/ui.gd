class_name UI
## UI style factory. One quiet material for every surface (a matte slate sheet; darker wells for
## rows inside it), one loud colour for the action that moves the game forward (crown gold), and
## the textured fantasy kit (tools/make_ui_kit.py) kept for the pieces that are part of the game
## itself: round medallion slots, map flags, bars, badges and the result-screen ribbon.
## Dialogs are built with `sheet()`: a centred card on a wide screen, a sheet that comes up from
## the bottom edge on an upright one.

# ---------------------------------------------------------------- palette
const SLATE := Color(0.094, 0.133, 0.18, 0.97)    # #18222e  sheet surface
const WELL := Color(0.035, 0.06, 0.09, 0.55)      # inset rows inside a sheet
const RIDGE := Color(0.176, 0.239, 0.318)         # #2d3d51  secondary buttons, chips
const RIDGE_LIP := Color(0.09, 0.125, 0.17)
const LINE := Color(1.0, 1.0, 1.0, 0.08)
const VELLUM := Color(0.945, 0.91, 0.83)          # #f1e8d4  text
const LICHEN := Color(0.62, 0.667, 0.73)          # #9eaaba  secondary text
const GOLD := Color(0.949, 0.757, 0.306)          # #f2c14e  forward action, currency, stars
const GOLD_DARK := Color(0.66, 0.455, 0.12)       # #a8741f  its lip
const EMBER := Color(0.85, 0.34, 0.25)            # danger, lives
const SAGE := Color(0.6, 0.84, 0.5)               # gains (upgrade deltas, done)
const ARCANE := Color(0.29, 0.23, 0.45)           # special modes (endless, iron, talents)

# older names, still used across the screens
const NAVY := SLATE
const NAVY_LIGHT := RIDGE
const PARCH := WELL
const INK := VELLUM
const INK_SOFT := LICHEN
const RED := EMBER
const GREEN := SAGE
const TEXT := VELLUM
const MUTED := LICHEN

# ---------------------------------------------------------------- type scale (canvas px)
const T_TITLE := 28   # sheet titles (serif)
const T_HEAD := 21    # row titles, buttons
const T_BODY := 18
const T_SMALL := 16   # captions; nothing smaller on a phone canvas

const KIT := "res://assets/ui/kit/%s.png"

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

## Flat rounded surface. Depth comes from the hierarchy of radius, fill and shadow, not frames:
## sheet (raised, large radius, soft shadow) > card (floating over the battlefield) > well (inset
## row inside a sheet, no shadow) > pill (tiny tags on the map / wave preview).
static func flat(bg: Color, radius: float, pad := Vector4(12, 12, 12, 12), shadow := 0.0, shadow_a := 0.4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 10
	s.anti_aliasing = true
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	if shadow > 0.0:
		s.shadow_color = Color(0, 0, 0, shadow_a)
		s.shadow_size = int(shadow)
		s.shadow_offset = Vector2(0, shadow * 0.35)
	return s

## Surface styles by role: "sheet" (dialogs), "card" (floating HUD cards), "well" (rows inside a
## sheet), "bar" (the HUD resource capsule), "pill" (small tags). The old kit names map onto them:
## "dark" -> sheet, "parch" -> well, "slim" -> bar, "leather" -> card.
## The surfaces are forged pieces (tools/make_ui_forge.py): a slate plate in a gold trim with rune
## studs (sheet), a lighter trim (card, bar), a carved inset (well). The trim sits on the control's
## edge; the baked shadow is drawn outside it (StyleBoxHD.expand).
static func frame(kind := "sheet", pad := 12.0) -> StyleBox:
	match kind:
		"dark", "sheet":
			return hd("fs_sheet", Vector4(38, 38, 38, 38), Vector4(16, 16, 16, 16), Vector4(pad + 10, pad + 8, pad + 10, pad + 10))
		"card", "leather":
			return hd("fs_card", Vector4(28, 28, 28, 28), Vector4(10, 10, 10, 10), Vector4(pad + 7, pad + 5, pad + 7, pad + 6))
		"slim", "bar":
			return hd("fs_bar", Vector4(32, 32, 32, 32), Vector4(8, 8, 8, 8), Vector4(pad + 12, pad + 3, pad + 12, pad + 3))
		"pill":
			return hd("fs_capsule", Vector4(28, 27, 28, 27), Vector4(4, 4, 4, 4), Vector4(pad + 12, pad + 2, pad + 12, pad + 3))
		_:  # "parch", "well"
			return hd("fs_well", Vector4(14, 14, 14, 14), Vector4(1, 1, 1, 1), Vector4(pad + 6, pad + 4, pad + 6, pad + 4))

## A well marked as chosen / owned / done: the same inset with a gold edge.
static func well_on(pad := 8.0) -> StyleBox:
	return hd("fs_well_on", Vector4(14, 14, 14, 14), Vector4(1, 1, 1, 1), Vector4(pad + 6, pad + 4, pad + 6, pad + 4))

## Backwards-compatible style helper (light colours meant parchment: those are wells now).
static func box(bg: Color, _border := GOLD_DARK, _radius := 14, _bw := 3, _shadow := 8, pad := 12) -> StyleBox:
	return frame("well" if bg.get_luminance() > 0.55 else "sheet", maxf(pad - 4.0, 4.0))

static func panel(bg := NAVY, border := GOLD_DARK, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius))
	return p

static func framed(kind := "sheet", pad := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(kind, pad))
	return p

## Text colours written for the old parchment cards (dark browns, reds, greens) read on the
## slate as light tints of the same hue.
static func on_dark(c: Color) -> Color:
	if c.get_luminance() >= 0.45:
		return c
	if c.s < 0.25:
		return LICHEN
	return Color.from_hsv(c.h, minf(c.s, 0.55), 0.95, c.a)

static func label(text: String, size := 22, color := TEXT, outline := 6, font := "ui") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		# outlined text floats over the battlefield or art: a soft drop shadow seats it
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06, 0.95))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 11))
		l.add_theme_constant_override("shadow_outline_size", outline)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	return l

## Text set on a sheet or card (no outline; the surface gives the contrast).
static func ink(text: String, size := 20, color := INK, font := "ui") -> Label:
	var l := label(text, size, on_dark(color), 0, font)
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
	out += line
	# a "word" wider than the line (Japanese has no spaces between words): let the text server
	# break it instead, at the same width
	for ln in out.split("\n"):
		if f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = width
			return
	l.text = out
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

## Buttons by role. Colour says what a button does, not which screen it is on:
## primary (gold) moves the game forward, secondary (slate) is everything else, ghost is an
## unpicked option (a carved slot), special (arcane) opens a mode, danger wipes something.
## The old kit colours map onto these: red/green/gold -> primary,
## blue -> secondary, gray -> ghost, purple -> special.
## Each role: [label colour, label outline colour]. Labels are light on every plate, held by an
## outline in the plate's own dark tone (the way game buttons stay legible over any face colour).
const BTN_ROLES := {
	"primary": [Color(1.0, 0.98, 0.9), Color(0.4, 0.2, 0.02)],
	"secondary": [Color(0.97, 0.97, 1.0), Color(0.05, 0.09, 0.17)],
	"special": [Color(1.0, 0.97, 1.0), Color(0.15, 0.07, 0.32)],
	"danger": [Color(1.0, 0.97, 0.94), Color(0.33, 0.05, 0.03)],
	"ghost": [LICHEN, Color(0, 0, 0, 0)],
}
## Round medallion roles (round_button / icon_button).
const MEDAL_ROLES := ["primary", "secondary", "danger"]

static func role_of(kind: String) -> String:
	match kind:
		"red", "green", "gold", "primary":
			return "primary"
		"purple", "special":
			return "special"
		"gray", "ghost":
			return "ghost"
		"danger":
			return "danger"
	return "secondary"

## Forged plate geometry (canvas units, tools/make_ui_forge.py): 6 of shadow round the plate, a
## 6-unit lip under the face; a pressed face sinks 5 onto the lip.
const PLATE_LIP := 6.0

static func _btn_styles(b: Button, kind: String) -> void:
	var role := role_of(kind)
	var c: Array = BTN_ROLES[role]
	var h := b.custom_minimum_size.y
	var px := 18.0 if h >= 48.0 else 12.0
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s: StyleBox
		if role == "ghost":
			# an unpicked option is a slot carved into the sheet: it has no lip to press
			var w := hd("fs_well", Vector4(14, 14, 14, 14), Vector4(1, 1, 1, 1), Vector4(px, 8, px, 8))
			if st == "hover":
				w.modulate_color = Color(1.35, 1.35, 1.4)
			elif st == "pressed":
				w.modulate_color = Color(0.8, 0.8, 0.8)
			s = w
		else:
			var top := 8.0 + (PLATE_LIP - 1.0 if st == "pressed" else 0.0)
			var bot := 8.0 + (1.0 if st == "pressed" else PLATE_LIP)
			s = hd("fb_%s_%s" % [role, st], Vector4(22, 22, 22, 28), Vector4(6, 6, 6, 6), Vector4(px, top, px, bot))
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	# keyboard focus (also the default action a sheet focuses, which Enter presses): a quiet ring
	var f := flat(Color(0, 0, 0, 0), 16)
	f.draw_center = false
	f.set_border_width_all(2)
	f.border_color = Color(1, 0.92, 0.7, 0.45)
	f.expand_margin_left = 4
	f.expand_margin_right = 4
	f.expand_margin_top = 4
	f.expand_margin_bottom = 4
	b.add_theme_stylebox_override("focus", f)
	var fc: Color = c[0]
	var oc: Color = c[1]
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc if role != "ghost" else VELLUM)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_hover_pressed_color", fc)
	b.add_theme_color_override("font_focus_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(0.66, 0.7, 0.76))
	b.add_theme_color_override("font_outline_color", oc if role != "ghost" else Color(0, 0, 0, 0))
	# the icons are full-colour glyphs with their own dark outline: they read on any plate untinted
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.5))
	var fs := b.get_theme_font_size("font_size") if b.has_theme_font_size_override("font_size") else 20
	b.add_theme_constant_override("outline_size", 0 if role == "ghost" else (6 if fs >= 22 else 5))

static func button(text: String, size := 24, primary := true, min_size := Vector2(200, 64), kind := "") -> Button:
	var b := Button.new()
	b.text = text
	# buttons keep their height; their width follows the label when the label needs more room
	b.custom_minimum_size = Vector2(min_size.x, minf(min_size.y, maxf(52.0, size * 2.3)))
	b.add_theme_font_override("font", Assets.font("ui_black"))
	b.add_theme_font_size_override("font_size", mini(size, 26) if min_size.y < 80 else size)
	b.add_theme_constant_override("icon_max_width", int(size * 1.05))
	b.add_theme_constant_override("h_separation", 10)
	_btn_styles(b, kind if kind != "" else ("primary" if primary else "secondary"))
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	juice(b)
	return b

## Medallion styles (a domed disc in a metal rim) for a round button of diameter `sz`.
static func _medal_styles(b: Button, role: String, sz: float, pad: float) -> void:
	if not role in MEDAL_ROLES:
		role = "secondary"
	var e := sz * 6.0 / 84.0  # the disc is 84 of the texture's 96 units; the rest is its shadow
	for st in ["normal", "hover", "pressed", "disabled"]:
		var dy := 1.5 * sz / 84.0 if st == "pressed" else 0.0
		b.add_theme_stylebox_override(st, hd("fr_%s_%s" % [role, st], Vector4(48, 48, 48, 48), Vector4(e, e, e, e), Vector4(pad, pad + dy, pad, pad - dy)))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(0.8, 0.8, 0.8, 0.6))

## A round utility button (close, back, pause...): a small medallion. The close button is "danger".
static func round_button(tex: Texture2D, sz := 48, role := "secondary") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(sz * 0.5))
	# small padding: icon_max_width sets the glyph size, so the button can be resized later
	_medal_styles(b, "secondary" if role == "ghost" else role, sz, 4.0)
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
	# game-object buttons (hero, skills, spells, wave calls, the radial menu) keep the gold-ringed
	# slots: they belong to the battlefield, the steel medallions (round_button) to the interface
	var k := kind if kind != "" else _slot_kind_for(bg)
	var e := sz * 4.0 / 88.0
	for st in ["normal", "hover", "pressed", "disabled"]:
		var pad := sz * 0.17
		b.add_theme_stylebox_override(st, hd("slot_%s_%s" % [k, st], Vector4(48, 48, 48, 48), Vector4(e, e, e, e), Vector4(pad, pad, pad, pad)))
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
		bb.button_down.connect(func(): _tw_scale(c, 0.96, 0.05, false))
		bb.button_up.connect(func(): _tw_scale(c, 1.0, 0.22, true))
		if not Game.is_mobile:
			c.mouse_entered.connect(func():
				if not bb.disabled:
					_tw_scale(c, 1.03, 0.12, false))
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

## A hairline between groups (only where spacing alone would not say "new group").
static func divider(w := 320.0) -> Control:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(minf(w, 4000.0), 1)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## The gold trim rule under a sheet title: two tapering lines meeting at a rune diamond. Built
## from three pieces of one texture so the diamond keeps its shape at any width.
static func rule(w := 0.0) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL if w <= 0.0 else Control.SIZE_SHRINK_CENTER
	if w > 0.0:
		hb.custom_minimum_size.x = w
	var tex := kit("fs_divider")
	for part in [Rect2(0, 0, 290, 32), Rect2(290, 0, 60, 32), Rect2(350, 0, 290, 32)]:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = part
		var t := TextureRect.new()
		t.texture = at
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.custom_minimum_size = Vector2(30 if part.size.x == 60 else 0, 16)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if part.size.x != 60:
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(t)
	return hb

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
	c.scale = Vector2(0.94, 0.94)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.16).set_delay(delay)

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
	var l := label(txt, size, on_dark(color), 0, "ui_black")
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
		t.set_font_size("font_size", cls, T_BODY)
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
	# text fields: wells
	for cls in ["TextEdit", "LineEdit"]:
		var n := flat(Color(0.03, 0.05, 0.08, 0.7), 12, Vector4(12, 10, 12, 10))
		var fo := flat(Color(0.03, 0.05, 0.08, 0.7), 12, Vector4(12, 10, 12, 10))
		fo.set_border_width_all(2)
		fo.border_color = Color(GOLD, 0.7)
		t.set_stylebox("normal", cls, n)
		t.set_stylebox("read_only", cls, n)
		t.set_stylebox("focus", cls, fo)
		t.set_color("font_color", cls, VELLUM)
		t.set_color("font_readonly_color", cls, LICHEN)
		t.set_color("font_placeholder_color", cls, Color(LICHEN, 0.6))
		t.set_color("caret_color", cls, GOLD)
		t.set_color("selection_color", cls, Color(GOLD, 0.3))
	# tooltips
	t.set_stylebox("panel", "TooltipPanel", frame("card", 2))
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
	var x := round_button(Assets.tex("ic_close"), sz, "danger")
	x.pressed.connect(on_close)
	holder.add_child(x)
	var fit := func():
		holder.custom_minimum_size = panel.size
		x.position = Vector2(panel.size.x - sz * 0.8, -sz * 0.3)
	panel.resized.connect(fit)
	fit.call_deferred()
	return holder

## A labelled row of option chips (the chosen one gold), e.g. the UI size or language setting.
## options: [[value, caption], ...]; cb gets the picked value.
static func choice(label_text: String, options: Array, current: Variant, cb: Callable, btn_w := 98.0) -> BoxContainer:
	# four or more options (the languages) get their own full-width row under the label, so the
	# row fits an upright phone
	var many := options.size() > 3
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := label(label_text, T_BODY, TEXT, 0, "ui")
	l.custom_minimum_size.x = 92
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb: VBoxContainer = null
	if many:
		vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		vb.add_child(l)
		vb.add_child(hb)
	else:
		hb.add_child(l)
	for op in options:
		var sel: bool = str(op[0]) == str(current) or (op[0] is float and current is float and absf(float(op[0]) - float(current)) < 0.01)
		var b := button(op[1], 17, false, Vector2(0.0 if many else btn_w, 44), "primary" if sel else "ghost")
		if many:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: Variant = op[0]
		b.pressed.connect(func():
			Audio.play("click", -4.0)
			cb.call(v))
		hb.add_child(b)
	return vb if many else hb

## The language options shown in the settings (title screen and battle pause menu).
const LANGUAGES := [["", "자동"], ["ko", "한국어"], ["en", "English"], ["ja", "日本語"]]



# ---------------------------------------------------------------- sheets (dialogs)

## Opens a dialog over `parent` (a full-screen Control): a dimmed backdrop and a sheet with the
## title and a close button in its header row. On a wide screen the sheet is a centred card; on
## an upright one it spans the width and comes up from the bottom edge, where the thumb is. The
## body scrolls once the sheet would leave the screen.
## opts: width (wide-screen width, default 560), on_close (Callable: shows the close button, and
## a tap on the backdrop closes too), aside (Control shown in the header), ribbon (kit ribbon kind:
## the result screens put their title on a ribbon over the top edge instead), dim (backdrop alpha).
## Returns the backdrop; its metas: "body" (VBoxContainer to fill), "sheet"/"panel", "ribbon",
## "center" (the layer that carries the sheet; ResultFX shakes it), "width" (body width).
const BODY_INSET := 6

static func sheet(parent: Control, title_text: String, opts := {}) -> Control:
	# sized and placed inside the safe area (notch, home indicator); the dim covers the whole screen
	var vs := Game.safe_size()
	var upright := Game.tall
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, float(opts.get("dim", 0.55)))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	if parent.get_meta("safe_inset", false):
		Game.apply_safe(shade, true)
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(layer)
	var p := PanelContainer.new()
	p.name = "Sheet"
	# the body sits in an inner margin (BODY_INSET) inside the scroll area, so the baked shadows of
	# buttons and wells at its edges are not clipped by the scroll container
	var st := frame("sheet", 6)
	st.content_margin_bottom -= 2
	var ribbon_kind: String = opts.get("ribbon", "")
	if upright:
		# a bottom sheet: its trim runs off the bottom edge of the screen, under the home indicator
		st = hd("fs_sheet_up", Vector4(38, 38, 38, 8), Vector4(16, 16, 16, 0), Vector4(st.content_margin_left, st.content_margin_top, st.content_margin_right, st.content_margin_bottom + 8 + Game.safe.w))
	if ribbon_kind != "":
		st.content_margin_top += 30
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(p)
	var margin := 0.0 if upright else 24.0
	var w := vs.x if upright else minf(float(opts.get("width", 560)), vs.x - 2.0 * margin)
	p.custom_minimum_size.x = w
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	p.add_child(col)
	if upright:
		var grip := Panel.new()
		grip.custom_minimum_size = Vector2(44, 5)
		grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grip.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.18), 3, Vector4.ZERO))
		grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(grip)
		col.add_theme_constant_override("separation", 10)
	# on_close may take the backdrop as its argument: a caller's lambda cannot capture the sheet
	# it is being passed to (GDScript captures locals by value, when the lambda is made)
	var on_close_cb: Callable = opts.get("on_close", Callable())
	var on_close := Callable()
	if on_close_cb.is_valid():
		on_close = func():
			if on_close_cb.get_argument_count() >= 1:
				on_close_cb.call(shade)
			else:
				on_close_cb.call()
	var rib: Control = null
	if ribbon_kind != "":
		rib = ribbon(title_text, 36, ribbon_kind, minf(420.0, w - 40.0))
		layer.add_child(rib)
	else:
		# header: the title centred in gold over a trim rule; the aside and the close medallion on
		# the right, balanced by a spacer of the same width on the left
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var lsp := Control.new()
		lsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(lsp)
		var tl := title(title_text, T_TITLE - (2 if upright else 0), "title_kr", 6)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.clip_text = true
		tl.name = "Title"
		head.add_child(tl)
		var right := HBoxContainer.new()
		right.add_theme_constant_override("separation", 10)
		var aside: Control = opts.get("aside", null)
		# a phone held upright has no room for the aside beside the title (the balancing spacer
		# would squeeze the title out): it goes on its own line under the rule instead
		var aside_below := upright and aside != null
		if aside and not aside_below:
			aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			right.add_child(aside)
		if on_close.is_valid():
			var x := round_button(Assets.tex("ic_close"), 46, "danger")
			x.name = "Close"
			x.pressed.connect(func(): on_close.call())
			right.add_child(x)
		head.add_child(right)
		var bal := func():
			if is_instance_valid(lsp):
				lsp.custom_minimum_size.x = right.get_combined_minimum_size().x
		right.minimum_size_changed.connect(bal)
		bal.call()
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 2)
		hv.add_child(head)
		var r := rule()
		r.custom_minimum_size.y = 12
		hv.add_child(r)
		if aside_below:
			aside.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			hv.add_child(aside)
		col.add_child(hv)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if upright:
		# a phone scrolls by dragging; a visible bar would also add its width to a full-width
		# sheet and push the right edge (and the close button) off the screen
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	var inner := MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, BODY_INSET)
	inner.add_theme_constant_override("margin_top", 4)
	inner.add_theme_constant_override("margin_bottom", 8)
	sc.add_child(inner)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(body)
	var body_w := w - st.content_margin_left - st.content_margin_right - 2.0 * BODY_INSET
	# the body grows with its content until the sheet would leave the screen, then it scrolls
	var place := func():
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		var sr := Game.safe_rect()
		var v := sr.size
		var head_h := col.get_combined_minimum_size().y - sc.get_combined_minimum_size().y
		var room := v.y * (0.92 if upright else 1.0) - 2.0 * margin - st.content_margin_top - st.content_margin_bottom - head_h - (24.0 if rib else 0.0)
		if upright:
			room += Game.safe.w  # the bottom padding under the home indicator is part of the sheet
		sc.custom_minimum_size.y = minf(inner.get_combined_minimum_size().y, maxf(room, 120.0))
		p.size = Vector2(p.custom_minimum_size.x, 0)
		p.size = p.get_combined_minimum_size()
		if upright:
			p.position = Vector2(sr.position.x, sr.end.y + Game.safe.w - p.size.y)
		else:
			p.position = (sr.position + (v - p.size) * 0.5).round() + Vector2(0, 14 if rib else 0)
		if rib:
			rib.position = Vector2(p.position.x + (p.size.x - rib.size.x) * 0.5, p.position.y - rib.size.y * 0.55)
	inner.minimum_size_changed.connect(place)
	shade.resized.connect(place)
	place.call_deferred()
	if on_close.is_valid():
		# a tap on the dimmed backdrop (not on the sheet) closes, like the close button
		shade.gui_input.connect(func(ev: InputEvent):
			if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
				on_close.call())
	if on_close.is_valid():
		shade.set_meta("close", on_close)  # Esc / Back closes the top sheet (UI.close_top)
	shade.set_meta("body", body)
	shade.set_meta("sheet", p)
	shade.set_meta("panel", p)
	shade.set_meta("ribbon", rib)
	shade.set_meta("center", layer)
	shade.set_meta("width", body_w)
	shade.set_meta("upright", upright)
	# entrance: the backdrop fades in; the sheet rises from the bottom edge (upright) or settles
	# from 96% (wide). No overshoot: it answers a tap, it is not a celebration.
	shade.modulate.a = 0.0
	var tw := shade.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(shade, "modulate:a", 1.0, 0.16)
	if upright:
		layer.position.y = vs.y * 0.5
		var t2 := layer.create_tween()
		t2.set_ignore_time_scale(true)
		t2.tween_property(layer, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		(func():
			if not is_instance_valid(p):
				return
			p.pivot_offset = p.size * 0.5
			p.scale = Vector2(0.96, 0.96)
			var t3 := p.create_tween()
			t3.set_ignore_time_scale(true)
			t3.tween_property(p, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)).call_deferred()
	return shade

## Body width of a sheet built by `sheet()` (for wrapping text and sizing rows).
static func sheet_w(shade: Control) -> float:
	return float(shade.get_meta("width", 480.0))

## Closes a sheet with a short exit (the reverse of its entrance), then frees it.
static func dismiss(shade: Control, after := Callable()) -> void:
	if not is_instance_valid(shade) or shade.has_meta("closing"):
		return
	shade.set_meta("closing", true)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := shade.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(shade, "modulate:a", 0.0, 0.14)
	if bool(shade.get_meta("upright", false)):
		var layer: Control = shade.get_meta("center")
		tw.tween_property(layer, "position:y", 80.0, 0.14).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		shade.queue_free()
		if after.is_valid():
			after.call())

## Width a row of `n` buttons gets inside a sheet body of width `w` (gap 10).
static func split_w(w: float, n: int, gap := 10.0) -> float:
	return floorf((w - gap * (n - 1)) / n)

## A row of buttons sharing the full width (the last one, the forward action, on the right).
static func action_row(btns: Array, gap := 10.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(gap))
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in btns:
		var c := b as Control
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = 0
		hb.add_child(c)
	return hb


## Esc / the phone's Back: closes the topmost sheet under `parent` that can be closed. Returns
## whether one was closed.
static func close_top(parent: Node) -> bool:
	var kids := parent.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var c: Node = kids[i]
		if c.has_meta("close") and not c.has_meta("closing") and c.is_inside_tree():
			(c.get_meta("close") as Callable).call()
			return true
	return false
