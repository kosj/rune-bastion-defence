class_name RadialMenu
extends Control
## Kingdom-Rush style ring menu around a plot/tower. Tap = preview, tap again = confirm.

signal chosen(id: String)
signal previewed(id: String)
signal closed

var world_pos := Vector3.ZERO
var cam: Camera3D
var options: Array = []
var buttons := {}
var selected := ""
var radius := 96.0
var _ring: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open(p: Vector3, opts: Array) -> void:
	world_pos = p
	options = opts
	selected = ""
	for c in get_children():
		c.queue_free()
	buttons.clear()
	_ring = _RingDraw.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	var n := opts.size()
	radius = 92.0 if n <= 4 else 104.0
	var start := -PI * 0.5
	if n == 2:
		start = -PI
	if n == 3:
		start = -PI * 0.5
	for i in n:
		var o: Dictionary = opts[i]
		var a := start + i * TAU / n
		if n == 2:
			a = -PI * 0.85 + i * PI * 0.7
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = Vector2(cos(a), sin(a)) * radius
		add_child(holder)
		var b := UI.icon_button(o["icon"], 76, Color(0.14, 0.18, 0.3, 0.96), 38)
		b.position = Vector2(-38, -38)
		b.disabled = not o.get("enabled", true)
		b.pressed.connect(_on_press.bind(o["id"]))
		holder.add_child(b)
		if o.has("label"):
			var tag := UI.panel(Color(0.05, 0.06, 0.1, 0.92), UI.GOLD_DARK, 10)
			tag.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.06, 0.1, 0.92), UI.GOLD_DARK, 10, 2, 3, 3))
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 2)
			if o.get("coin", false):
				hb.add_child(UI.icon(Assets.tex("coin"), 18))
			var l := UI.label(o["label"], 18, UI.GOLD if o.get("enabled", true) else Color(0.9, 0.4, 0.35), 4)
			hb.add_child(l)
			tag.add_child(hb)
			tag.position = Vector2(-34, 30)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(tag)
		var check := UI.icon(Assets.tex("check"), 34)
		check.position = Vector2(14, -44)
		check.visible = false
		holder.add_child(check)
		buttons[o["id"]] = {"button": b, "check": check, "holder": holder, "opt": o}
		holder.scale = Vector2(0.2, 0.2)
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector2.ONE, 0.22).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	visible = true
	_update_pos()

func close() -> void:
	if not visible:
		return
	visible = false
	selected = ""
	closed.emit()

func refresh_enabled(gold: int) -> void:
	for id in buttons:
		var o: Dictionary = buttons[id]["opt"]
		if o.has("cost"):
			var en: bool = gold >= int(o["cost"])
			(buttons[id]["button"] as Button).disabled = not en

func _on_press(id: String) -> void:
	var o: Dictionary = buttons[id]["opt"]
	if o.get("instant", false) or selected == id:
		chosen.emit(id)
		return
	selected = id
	for k in buttons:
		buttons[k]["check"].visible = (k == id)
		var h: Control = buttons[k]["holder"]
		h.scale = Vector2(1.12, 1.12) if k == id else Vector2.ONE
	previewed.emit(id)

func _process(_d: float) -> void:
	if visible:
		_update_pos()

func _update_pos() -> void:
	if cam == null:
		return
	var sp := cam.unproject_position(world_pos)
	var vs := get_viewport_rect().size
	sp.x = clampf(sp.x, radius + 40, vs.x - radius - 40)
	sp.y = clampf(sp.y, radius + 60, vs.y - radius - 50)
	position = sp

class _RingDraw extends Control:
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 92.0, 0, TAU, 64, Color(0.98, 0.8, 0.35, 0.55), 4.0, true)
		draw_circle(Vector2.ZERO, 92.0, Color(0.05, 0.05, 0.1, 0.25))
