class_name UI
## UI style factory. The look is heraldic and flat: surfaces and buttons are solid tinctures (no
## gradients, bevels, trims or glows), depth is a hard offset shadow, and the forward action is a
## yellow "or" plate with dark text. Headings, buttons and big numbers use the display face (Black
## Han Sans; Dela Gothic One for Japanese); body text the UI face (Noto Sans CJK). Buttons and
## banners are cut as pennants (a slight skew). Map flags and the result stars keep their pictures.
## Dialogs are built with `sheet()`: a centred card on a wide screen, a sheet that comes up from
## the bottom edge on an upright one.

# ---------------------------------------------------------------- palette (heraldic tinctures)
const SLATE := Color(0.129, 0.145, 0.2, 0.98)     # #212533  sheet surface
const WELL := Color(0.07, 0.08, 0.115, 0.72)      # inset rows inside a sheet (flat, darker)
const RIDGE := Color(0.22, 0.255, 0.36)           # #383f5c  secondary buttons, chips
const RIDGE_LIP := Color(0.12, 0.14, 0.205)
const LINE := Color(1.0, 1.0, 1.0, 0.08)
const VELLUM := Color(0.95, 0.945, 0.925)         # #f2f1ec  argent: text
const LICHEN := Color(0.66, 0.69, 0.76)           # secondary text
const GOLD := Color(0.969, 0.725, 0.165)          # #f7b92a  or: forward action, currency, stars
const GOLD_DARK := Color(0.70, 0.46, 0.05)        # its lip
const EMBER := Color(0.88, 0.29, 0.24)            # gules: danger, lives
const SAGE := Color(0.47, 0.79, 0.46)             # vert: gains (upgrade deltas, done)
const ARCANE := Color(0.46, 0.33, 0.70)           # purpure: special modes (endless, iron, talents)
const AZURE := Color(0.23, 0.46, 0.82)            # azure: information, the selected thing
const SABLE := Color(0.075, 0.08, 0.11)           # ink: hard shadows, text on or

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

## Flat rounded surface (the base of every plate).
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

## A plate: a flat fill with a hard drop (an offset shadow with no blur, in ink or in the plate's
## own darker tone for a button's lip) and, optionally, a pennant cut (skew).
static func plate(bg: Color, radius: float, pad: Vector4, drop := 0.0, drop_col := Color(SABLE, 0.6), skew := 0.0) -> StyleBoxFlat:
	var s := flat(bg, radius, pad)
	if drop > 0.0:
		s.shadow_color = drop_col
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, drop)
	if skew != 0.0:
		s.skew = Vector2(skew, 0)
	return s

## Surface styles by role: "sheet" (dialogs), "card" (floating HUD cards), "well" (rows inside a
## sheet), "bar" (the HUD resource plate), "pill" (small tags). The old kit names map onto them:
## "dark" -> sheet, "parch" -> well, "slim" -> bar, "leather" -> card.
static func frame(kind := "sheet", pad := 12.0) -> StyleBox:
	match kind:
		"dark", "sheet":
			var s := plate(SLATE, 16, Vector4(pad + 12, pad + 8, pad + 12, pad + 10), 8.0)
			s.border_width_top = 2
			s.border_color = Color(1, 1, 1, 0.06)
			return s
		"card", "leather":
			return plate(Color(SLATE, 0.97), 12, Vector4(pad + 8, pad + 5, pad + 8, pad + 6), 5.0)
		"slim", "bar":
			return plate(Color(SABLE, 0.84), 10, Vector4(pad + 14, pad + 3, pad + 14, pad + 3), 4.0, Color(SABLE, 0.5), 0.14)
		"pill":
			return plate(Color(SABLE, 0.8), 8, Vector4(pad + 10, pad + 2, pad + 10, pad + 3))
		_:  # "parch", "well"
			return flat(WELL, 10, Vector4(pad + 6, pad + 4, pad + 6, pad + 4))

## A well marked as chosen / owned / done: the same inset with an or edge.
static func well_on(pad := 8.0) -> StyleBox:
	var s := flat(Color(GOLD, 0.10), 10, Vector4(pad + 6, pad + 4, pad + 6, pad + 4))
	s.set_border_width_all(2)
	s.border_color = GOLD
	return s

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
	if font == "title_kr" and size >= 26:
		font = "title_kr_big"  # (large display text: its own Japanese face)
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

## Display heading (Black Han Sans): argent, no gradient. Over the battlefield or art it gets an
## ink outline and a hard drop; on a sheet (outline 0) it stands plain.
static func title(text: String, size := 44, font := "title_kr", outline := 10) -> Label:
	var l := label(text, size, VELLUM, 0, font)
	if outline > 0:
		l.add_theme_constant_override("outline_size", int(outline * 0.6))
		l.add_theme_color_override("font_outline_color", SABLE)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 12))
		l.add_theme_constant_override("shadow_outline_size", int(outline * 0.6))
		l.add_theme_color_override("font_shadow_color", Color(SABLE, 0.9))
	return l

# ---------------------------------------------------------------- buttons

## Buttons by role. Colour says what a button does, not which screen it is on:
## primary (or) moves the game forward, secondary (slate) is everything else, ghost is an
## unpicked option (an outlined slot), special (purpure) opens a mode, danger wipes something.
## The old kit colours map onto these: red/green/gold -> primary,
## blue -> secondary, gray -> ghost, purple -> special.
## Each role: [face, lip (the hard drop under the face), label].
const BTN_ROLES := {
	"primary": [GOLD, GOLD_DARK, SABLE],
	"secondary": [RIDGE, RIDGE_LIP, VELLUM],
	"special": [ARCANE, Color(0.25, 0.17, 0.42), Color(1.0, 0.98, 1.0)],
	"danger": [EMBER, Color(0.5, 0.12, 0.09), Color(1.0, 0.98, 0.96)],
	"ghost": [Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), LICHEN],
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

## The lip under a button face (canvas units); a pressed face sinks onto it.
const PLATE_LIP := 5.0
## The pennant cut of buttons and banners.
const CUT := 0.14

static func _btn_styles(b: Button, kind: String) -> void:
	var role := role_of(kind)
	var c: Array = BTN_ROLES[role]
	var face: Color = c[0]
	var lip: Color = c[1]
	var h := b.custom_minimum_size.y
	var px := 18.0 if h >= 48.0 else 12.0
	var rad := 9.0 if h >= 48.0 else 7.0
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s: StyleBoxFlat
		if role == "ghost":
			# an unpicked option: an outlined slot, no lip to press
			var f := face
			if st == "hover":
				f = Color(1, 1, 1, 0.10)
			elif st == "pressed":
				f = Color(1, 1, 1, 0.02)
			s = plate(f, rad, Vector4(px, 8, px, 8), 0.0, Color(), CUT)
			s.set_border_width_all(2)
			s.border_color = Color(1, 1, 1, 0.16 if st != "hover" else 0.3)
		else:
			var f := face
			var drop := PLATE_LIP
			var top := 8.0
			var bot := 8.0
			match st:
				"hover":
					f = face.lightened(0.1)
				"pressed":
					f = face.darkened(0.06)
					drop = 1.0
					top += PLATE_LIP - 1.0
					bot -= PLATE_LIP - 1.0
				"disabled":
					f = Color(face.lerp(RIDGE, 0.7), 0.55)
					lip = Color(RIDGE_LIP, 0.55)
			s = plate(f, rad, Vector4(px, top, px, bot), drop, lip, CUT)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	# keyboard focus (also the default action a sheet focuses, which Enter presses): a quiet ring
	var fr := plate(Color(0, 0, 0, 0), rad + 3, Vector4.ZERO, 0.0, Color(), CUT)
	fr.draw_center = false
	fr.set_border_width_all(2)
	fr.border_color = Color(VELLUM, 0.5)
	fr.expand_margin_left = 4
	fr.expand_margin_right = 4
	fr.expand_margin_top = 4
	fr.expand_margin_bottom = 4
	b.add_theme_stylebox_override("focus", fr)
	var fc: Color = c[2]
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc if role != "ghost" else VELLUM)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_hover_pressed_color", fc)
	b.add_theme_color_override("font_focus_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(0.66, 0.7, 0.76))
	b.add_theme_constant_override("outline_size", 0)
	# the icons are full-colour glyphs with their own dark outline: they read on any plate untinted
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.5))

static func button(text: String, size := 24, primary := true, min_size := Vector2(200, 64), kind := "") -> Button:
	var b := Button.new()
	b.text = text
	# buttons keep their height; their width follows the label when the label needs more room
	b.custom_minimum_size = Vector2(min_size.x, minf(min_size.y, maxf(52.0, size * 2.3)))
	# labels in the display face, whose Hangul sits smaller in the em than the UI face's: 15% up
	var ds := int(round(size * 1.15))
	b.add_theme_font_override("font", Assets.font("title_kr_big" if ds >= 30 else "title_kr"))
	b.add_theme_font_size_override("font_size", mini(ds, 29) if min_size.y < 80 else ds)
	b.add_theme_constant_override("icon_max_width", int(size * 1.05))
	b.add_theme_constant_override("h_separation", 10)
	_btn_styles(b, kind if kind != "" else ("primary" if primary else "secondary"))
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	juice(b)
	return b

## Round utility button styles: a flat disc on its own darker lip, for a button of diameter `sz`.
static func _medal_styles(b: Button, role: String, sz: float, pad: float) -> void:
	if not role in MEDAL_ROLES:
		role = "secondary"
	var c: Array = BTN_ROLES[role]
	var drop := maxf(3.0, sz / 14.0)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var f: Color = c[0]
		var d := drop
		var dy := 0.0
		if st == "hover":
			f = f.lightened(0.1)
		elif st == "pressed":
			f = f.darkened(0.06)
			d = 1.0
			dy = drop - 1.0
		elif st == "disabled":
			f = Color(f, 0.5)
		var s := plate(f, sz * 0.5, Vector4(pad, pad + dy, pad, pad - dy), d, c[1])
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, SABLE if role == "primary" else Color.WHITE)
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

## The close (x) of sheets and cards: a quiet square that lights up under the pointer, not a red disc.
static func close_button(sz := 44) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.icon = Assets.tex("ic_close")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(sz * 0.42))
	var pad := sz * 0.2
	b.add_theme_stylebox_override("normal", flat(Color(1, 1, 1, 0.06), 10, Vector4(pad, pad, pad, pad)))
	b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.14), 10, Vector4(pad, pad, pad, pad)))
	b.add_theme_stylebox_override("pressed", flat(Color(1, 1, 1, 0.03), 10, Vector4(pad, pad, pad, pad)))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, VELLUM)
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
	# game-object buttons (hero, skills, spells, wave calls, the radial menu): a roundel in its
	# tincture with an argent ring, sitting on a hard drop; they belong to the battlefield
	var k := kind if kind != "" else _slot_kind_for(bg)
	var face: Color = SLOT_FACES.get(k, SLOT_FACES["navy"])
	var ring := maxf(2.0, roundf(sz / 26.0))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var pad := sz * 0.17
		var f := face
		var d := maxf(3.0, sz / 18.0)
		var rc := Color(VELLUM, 0.92)
		if st == "hover":
			f = face.lightened(0.12)
		elif st == "pressed":
			f = face.darkened(0.1)
			d = 1.0
		elif st == "disabled":
			f = face.lerp(Color(0.2, 0.21, 0.25), 0.7)
			rc = Color(VELLUM, 0.35)
		var s := plate(f, sz * 0.5, Vector4(pad, pad, pad, pad), d, Color(SABLE, 0.7))
		s.set_border_width_all(int(ring))
		s.border_color = rc
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	juice(b)
	return b

## Roundel faces of the game-object slots, by the old kit colour names.
const SLOT_FACES := {
	"navy": Color(0.17, 0.2, 0.3),
	"red": Color(0.6, 0.17, 0.14),
	"brown": Color(0.43, 0.28, 0.16),
	"purple": Color(0.33, 0.22, 0.52),
	"green": Color(0.19, 0.42, 0.24),
}

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

## A pennant band with a title on it (the result screens' banner): a cut plate in a tincture,
## "red" (gules), "blue" (azure), "gold" (or) or "dark" (sable).
static func ribbon(text: String, size := 34, kind := "red", min_w := 300.0) -> PanelContainer:
	var p := PanelContainer.new()
	var face: Color = {"red": EMBER, "blue": AZURE, "gold": GOLD}.get(kind, SABLE)
	var s := plate(face, 6, Vector4(40, 2, 40, 6), 7.0, Color(SABLE, 0.75), 0.22)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(min_w, size * 1.7)
	var l := label(text, size, SABLE if kind == "gold" else VELLUM, 0, "title_kr")
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

## A short rule (kept for callers of the old trim): a hairline.
static func rule(w := 0.0) -> Control:
	var d := divider(w if w > 0.0 else 320.0)
	if w <= 0.0:
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d

## Flat progress bar ("green" / "gold" / "red" / "blue" fill) on an ink track.
const BAR_FILLS := {"green": Color(0.38, 0.74, 0.38), "gold": GOLD, "red": EMBER, "blue": AZURE}

static func bar(fill := "green", w := 120.0, h := 14.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.001
	pb.custom_minimum_size = Vector2(w, h)
	var r := clampf(h * 0.3, 2.0, 5.0)
	var bg := flat(Color(SABLE, 0.78), r, Vector4.ZERO)
	bg.expand_margin_left = 2
	bg.expand_margin_right = 2
	bg.expand_margin_top = 2
	bg.expand_margin_bottom = 2
	var fg := flat(BAR_FILLS.get(fill, GOLD), r, Vector4.ZERO)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb

## A count on a small or disc (hero level, notifications...).
static func badge(text: String, sz := 34, font_size := 20) -> Control:
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := plate(GOLD, sz * 0.5, Vector4.ZERO, 2.0, Color(SABLE, 0.7))
	st.set_border_width_all(2)
	st.border_color = SABLE
	c.add_theme_stylebox_override("panel", st)
	var l := label(text, font_size, SABLE, 0, "title_kr")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "Text"
	c.add_child(l)
	return c

## A count badge on a button's top-right corner, sticking out past its edge. In a row the next
## button is drawn after this one and would cover the part that sticks out, so the button that
## carries the badge is drawn after its siblings: its draw index is raised, not its place in the
## row, so the layout stays as it is. Godot sets the draw indices of a parent's children back to
## their order whenever that parent's children change, so it is raised again after each change.
## Anything added later to an ancestor (a sheet, a notice) still covers it.
static func corner_badge(target: Control, text: String, sz := 28, font_size := 15, off := Vector2(-22, -10)) -> Control:
	var bd := badge(text, sz, font_size)
	bd.anchor_left = 1.0
	bd.anchor_right = 1.0
	bd.offset_left = off.x
	bd.offset_right = off.x + sz
	bd.offset_top = off.y
	bd.offset_bottom = off.y + sz
	target.add_child(bd)
	var lift := func():
		if is_instance_valid(target) and target.is_inside_tree():
			RenderingServer.canvas_item_set_draw_index(target.get_canvas_item(), 1 << 20)
	var hook := func():
		if not is_instance_valid(target):
			return
		var p := target.get_parent()
		if p and target.get_meta("badge_parent", null) != p:
			target.set_meta("badge_parent", p)
			p.child_order_changed.connect(lift, CONNECT_DEFERRED)
		lift.call()
	# (deferred: the viewport resets the order in a deferred call queued when the child entered)
	target.tree_entered.connect(hook, CONNECT_DEFERRED)
	if target.is_inside_tree():
		hook.call_deferred()
	return bd

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
	# sliders: an ink track, an or fill, an argent knob
	var track := flat(Color(SABLE, 0.8), 4, Vector4(0, 4, 0, 4))
	var fill := flat(GOLD, 4, Vector4(0, 4, 0, 4))
	for cls in ["HSlider"]:
		t.set_stylebox("slider", cls, track)
		t.set_stylebox("grabber_area", cls, fill)
		t.set_stylebox("grabber_area_highlight", cls, fill)
		var knob := _knob_tex()
		t.set_icon("grabber", cls, knob)
		t.set_icon("grabber_highlight", cls, knob)
		t.set_icon("grabber_disabled", cls, knob)
		t.set_constant("center_grabber", cls, 0)
	# toggles
	for cls in ["CheckButton"]:
		t.set_icon("checked", cls, _toggle_tex(true))
		t.set_icon("unchecked", cls, _toggle_tex(false))
		t.set_icon("checked_disabled", cls, _toggle_tex(true))
		t.set_icon("unchecked_disabled", cls, _toggle_tex(false))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_focus_color", cls, TEXT)
		t.set_font_size("font_size", cls, T_BODY)
	# scrollbars
	var grab := flat(Color(1, 1, 1, 0.22), 4, Vector4(4, 4, 4, 4))
	var lane := StyleBoxFlat.new()
	lane.bg_color = Color(0, 0, 0, 0.22)
	lane.set_corner_radius_all(4)
	lane.content_margin_left = 5
	lane.content_margin_right = 5
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, lane)
		t.set_stylebox("scroll_focus", cls, lane)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab)
		t.set_stylebox("grabber_pressed", cls, grab)
	# progress bars
	t.set_stylebox("background", "ProgressBar", flat(Color(SABLE, 0.78), 4, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", flat(GOLD, 4, Vector4.ZERO))
	# text fields: wells
	for cls in ["TextEdit", "LineEdit"]:
		var n := flat(WELL, 10, Vector4(12, 10, 12, 10))
		var fo := flat(WELL, 10, Vector4(12, 10, 12, 10))
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


## Drawn once: the slider knob (an argent disc ringed in ink) and the toggle switch (a track with
## a disc; or when on). Pixels are anti-aliased by distance, at 2x for crisp edges.
static func _knob_tex() -> Texture2D:
	var n := 52
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(n * 0.5 - 1.0 - d, 0.0, 1.0)
			var col := SABLE if d > n * 0.5 - 5.0 else VELLUM
			img.set_pixel(x, y, Color(col, a))
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(26, 26))
	return tex

static func _toggle_tex(on: bool) -> Texture2D:
	var w := 112
	var h := 60
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5 - 2.0
	var knob_x := (w - h * 0.5) if on else h * 0.5
	var track := GOLD if on else RIDGE
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			# capsule distance
			var cx := clampf(p.x, h * 0.5, w - h * 0.5)
			var dt := p.distance_to(Vector2(cx, h * 0.5))
			var a := clampf(r - dt + 0.5, 0.0, 1.0)
			var col := track
			var dk := p.distance_to(Vector2(knob_x, h * 0.5))
			if dk < r - 5.0:
				col = SABLE if on else LICHEN
			elif dk < r - 4.0:
				col = col.lerp(SABLE if on else LICHEN, r - 4.0 - dk)
			img.set_pixel(x, y, Color(col, a))
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(56, 30))
	return tex

## Wraps a panel in a plain holder with a round close (x) button pinned to its top-right corner
## (a close button inside the PanelContainer itself would be stretched over the content).
static func with_close(panel: Control, on_close: Callable, sz := 50) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var x := close_button(int(sz * 0.88))
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
			fit_label(b)
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
		# a bottom sheet: square at the bottom edge, padded over the home indicator
		var up := plate(SLATE, 18, Vector4(st.content_margin_left, st.content_margin_top, st.content_margin_right, st.content_margin_bottom + 8 + Game.safe.w))
		up.corner_radius_bottom_left = 0
		up.corner_radius_bottom_right = 0
		up.border_width_top = 2
		up.border_color = Color(1, 1, 1, 0.06)
		st = up
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
		# header: the title set left in the display face; the aside and a quiet close (x) on the
		# right. No trim, no rule: the type carries the header
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var tl := title(title_text, T_TITLE + 2 - (2 if upright else 0), "title_kr", 0)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.clip_text = true
		tl.name = "Title"
		head.add_child(tl)
		var right := HBoxContainer.new()
		right.add_theme_constant_override("separation", 10)
		var aside: Control = opts.get("aside", null)
		# a phone held upright has no room for the aside beside the title: it goes on its own
		# line under the header instead
		var aside_below := upright and aside != null
		if aside and not aside_below:
			aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			right.add_child(aside)
		if on_close.is_valid():
			var x := close_button(44)
			x.name = "Close"
			x.pressed.connect(func(): on_close.call())
			right.add_child(x)
		head.add_child(right)
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 6)
		hv.add_child(head)
		if aside_below:
			aside.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	# entrance: the backdrop fades in; the sheet rises from the bottom edge (upright) or lifts 18
	# units into place (wide), quick and decelerating. No overshoot: it answers a tap.
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
			layer.position.y = 18.0
			var t3 := layer.create_tween()
			t3.set_ignore_time_scale(true)
			t3.tween_property(layer, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)).call_deferred()
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
## The buttons take their share of the row and fit their labels into it (fit_label), so a long
## translation never pushes the row past its sheet.
static func action_row(btns: Array, gap := 10.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(gap))
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in btns:
		var c := b as Control
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = 0
		if c is Button:
			fit_label(c as Button)
		hb.add_child(c)
	return hb

## A button whose label steps its size down (to 70%) when the width it is given is too narrow for
## it, instead of widening the button; past that it ends in an ellipsis.
static func fit_label(b: Button) -> void:
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var fs0 := b.get_theme_font_size("font_size")
	b.set_meta("fs0", fs0)
	var fit := func():
		if not is_instance_valid(b) or b.size.x <= 0.0:
			return
		var f := b.get_theme_font("font")
		var st := b.get_theme_stylebox("normal")
		var txt := b.tr(b.text) if b.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else b.text
		var fs_min := int(b.get_meta("fs0") * 0.7)
		# with the icon, then (if the label still does not fit at the smallest size) without it
		for with_icon in [true, false]:
			var ic: Texture2D = b.get_meta("icon0", b.icon)
			var room := b.size.x - st.get_margin(SIDE_LEFT) - st.get_margin(SIDE_RIGHT)
			if with_icon and ic:
				room -= b.get_theme_constant("icon_max_width") + b.get_theme_constant("h_separation")
			var fs: int = b.get_meta("fs0")
			while fs > fs_min and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
			var fits := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room
			if fits or not with_icon or ic == null:
				if ic:
					b.set_meta("icon0", ic)
					b.icon = ic if with_icon else null
				if fs != b.get_theme_font_size("font_size"):
					b.add_theme_font_size_override("font_size", fs)
				break
	b.resized.connect(fit)


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
