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
## Screen rects (canvas units) the ring keeps out from under: set by the HUD (its panels).
var keepout: Callable
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
		var b := UI.icon_button(o["icon"], 78, UI.NAVY, 39, o.get("kind", "navy"))
		b.add_theme_constant_override("icon_max_width", 50)
		b.position = Vector2(-39, -39)
		b.disabled = not o.get("enabled", true)
		b.pressed.connect(_on_press.bind(o["id"]))
		holder.add_child(b)
		if o.has("label"):
			var tag := UI.framed("pill", 0)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 2)
			hb.alignment = BoxContainer.ALIGNMENT_CENTER
			if o.get("coin", false):
				hb.add_child(UI.icon(Assets.tex("coin"), 20))
			var l := UI.label(o["label"], 17, UI.GOLD if o.get("enabled", true) else Color(1.0, 0.45, 0.4), 5, "ui_black")
			hb.add_child(l)
			tag.add_child(hb)
			tag.position = Vector2(-34, 28)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(tag)
			tag.resized.connect(func(): tag.position.x = -tag.size.x * 0.5)
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
	var sr := Game.safe_rect()  # the whole ring on screen, clear of a notch
	var lo := sr.position + Vector2(radius + 40, radius + 60)
	var hi := sr.end - Vector2(radius + 40, radius + 50)
	sp = sp.clamp(lo, hi)
	# the ring lives under the HUD's panels (the map's layer): where it would slip under one (the
	# hero dock, the top bar, the selection card) it steps out to the nearest free side instead,
	# so none of its buttons is hidden
	if keepout.is_valid():
		var rects: Array = keepout.call()
		for _pass in 2:
			for r in rects:
				var rr: Rect2 = r
				var ring := Rect2(sp - Vector2(radius + 40, radius + 60), Vector2(radius * 2 + 80, radius * 2 + 110))
				if not ring.intersects(rr):
					continue
				var best := sp
				var best_d := INF
				for c in [Vector2(sp.x, rr.position.y - radius - 50), Vector2(sp.x, rr.end.y + radius + 60),
						Vector2(rr.position.x - radius - 40, sp.y), Vector2(rr.end.x + radius + 40, sp.y)]:
					var cv: Vector2 = c
					if cv.x < lo.x or cv.x > hi.x or cv.y < lo.y or cv.y > hi.y:
						continue
					var d := cv.distance_to(sp)
					if d < best_d:
						best_d = d
						best = cv
				sp = best
	position = sp

class _RingDraw extends Control:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 94.0, Color(0.04, 0.05, 0.1, 0.32))
		draw_arc(Vector2.ZERO, 94.0, 0, TAU, 96, Color(0.2, 0.11, 0.03, 0.75), 8.0, true)
		draw_arc(Vector2.ZERO, 94.0, 0, TAU, 96, Color(0.98, 0.8, 0.36, 0.9), 4.0, true)
		draw_arc(Vector2.ZERO, 86.0, 0, TAU, 96, Color(1.0, 0.92, 0.6, 0.35), 1.5, true)
