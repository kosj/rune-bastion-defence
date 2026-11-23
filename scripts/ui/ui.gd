class_name UI
## UI style factory: fantasy navy/gold panels, buttons and labels built in code.

const GOLD := Color(0.98, 0.78, 0.32)
const GOLD_DARK := Color(0.62, 0.42, 0.12)
const NAVY := Color(0.07, 0.09, 0.16, 0.92)
const NAVY_LIGHT := Color(0.13, 0.17, 0.29, 0.95)
const PARCH := Color(0.96, 0.9, 0.76)
const RED := Color(0.86, 0.26, 0.22)
const GREEN := Color(0.36, 0.78, 0.38)
const TEXT := Color(0.97, 0.94, 0.86)
const MUTED := Color(0.7, 0.72, 0.8)

static func box(bg: Color, border := GOLD_DARK, radius := 14, bw := 3, shadow := 8, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

static func panel(bg := NAVY, border := GOLD_DARK, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius))
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

static func button(text: String, size := 24, primary := true, min_size := Vector2(200, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", Assets.font("ui"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	var base := Color(0.72, 0.2, 0.14) if primary else Color(0.18, 0.24, 0.4)
	var n := box(base, GOLD, 16, 3, 6, 10)
	var h := box(base.lightened(0.12), Color(1, 0.9, 0.55), 16, 3, 8, 10)
	var p := box(base.darkened(0.2), GOLD_DARK, 16, 3, 2, 10)
	var d := box(Color(0.25, 0.25, 0.28), Color(0.4, 0.4, 0.42), 16, 3, 2, 10)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	return b

static func icon_button(tex: Texture2D, sz := 72, bg := NAVY_LIGHT, radius := 40) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(sz * 0.62))
	var n := box(bg, GOLD, radius, 3, 6, 6)
	var h := box(bg.lightened(0.15), Color(1, 0.92, 0.6), radius, 3, 8, 6)
	var p := box(bg.darkened(0.2), GOLD_DARK, radius, 3, 2, 6)
	var d := box(Color(0.2, 0.2, 0.24, 0.9), Color(0.4, 0.4, 0.45), radius, 3, 2, 6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("click", -4.0, 0.05))
	return b

static func icon(tex: Texture2D, sz := 32) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(sz, sz)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func pop_in(c: Control, delay := 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)

static func stars_row(n: int, sz := 48) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	for i in 3:
		h.add_child(icon(Assets.tex("star" if i < n else "star_empty"), sz))
	return h
