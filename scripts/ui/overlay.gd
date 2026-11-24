class_name Overlay
extends Control
## Screen-space health bars and floating combat text, drawn in one pass for performance.

var cam: Camera3D
var texts: Array = []  # {pos, text, color, t, life, scale}
var font: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Assets.font("ui")

func float_text(p: Vector3, txt: String, c: Color, s := 1.0) -> void:
	txt = tr(txt)  # drawn with draw_string, so no automatic Control translation
	texts.append({"pos": p, "text": txt, "color": c, "t": 0.0, "life": 1.1, "scale": s})

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)
	for t in texts:
		t["t"] += rd
	texts = texts.filter(func(t): return t["t"] < t["life"])
	queue_redraw()

func _bar(p3: Vector3, ratio: float, w: float, col: Color, back := Color(0.1, 0.05, 0.05, 0.85)) -> void:
	if cam.is_position_behind(p3):
		return
	var sp := cam.unproject_position(p3)
	var h := 6.0 if w < 60 else 8.0
	var r := Rect2(sp.x - w * 0.5, sp.y, w, h)
	draw_rect(r.grow(1.5), Color(0, 0, 0, 0.8))
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(w * clampf(ratio, 0.0, 1.0), h)), col)
	draw_rect(Rect2(r.position, Vector2(w * clampf(ratio, 0.0, 1.0), h * 0.4)), Color(1, 1, 1, 0.25))

func _draw() -> void:
	if cam == null or LevelMain.I == null:
		return
	var zoom_k := clampf(28.0 / LevelMain.I.cam_rig.zoom, 0.7, 1.5)
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive:
			continue
		if e.hp < e.max_hp or e.boss:
			var w := (34.0 if not e.boss else 120.0) * zoom_k
			if e.type == "warchief":
				w = 56.0 * zoom_k
			var col := Color(0.35, 0.9, 0.3) if not e.boss else Color(0.95, 0.25, 0.2)
			if e.hp / e.max_hp < 0.35 and not e.boss:
				col = Color(0.95, 0.6, 0.2)
			_bar(e.global_position + Vector3(0, e.height + 0.35, 0), e.hp / e.max_hp, w, col)
	for s: Soldier in LevelMain.I.soldiers:
		if s.alive and (s.hp < s.max_hp or s.is_hero):
			var col2 := Color(0.3, 0.7, 1.0) if not s.is_hero else Color(1.0, 0.78, 0.25)
			_bar(s.global_position + Vector3(0, s.height + 0.35, 0), s.hp / s.max_hp, (30.0 if not s.is_hero else 46.0) * zoom_k, col2)
	for t in texts:
		var k: float = t["t"] / t["life"]
		var p3: Vector3 = t["pos"] + Vector3(0, k * 1.4, 0)
		if cam.is_position_behind(p3):
			continue
		var sp := cam.unproject_position(p3)
		var fs := int(26 * float(t["scale"]) * (1.0 + 0.25 * (1.0 - minf(k * 5.0, 1.0))))
		var c: Color = t["color"]
		c.a = 1.0 - smoothstep(0.6, 1.0, k)
		var txt: String = t["text"]
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string_outline(font, sp - Vector2(sz.x * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, c.a))
		draw_string(font, sp - Vector2(sz.x * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
