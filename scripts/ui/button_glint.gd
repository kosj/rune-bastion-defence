class_name ButtonGlint
extends Control
## A band of light that sweeps across a button now and then: the screen's main action catches the
## eye without blinking or bouncing. Clipped to the button's face (the slanted plate of UI.plate,
## rounded corners included), so it never spills onto the lip or past the slant.
##   ButtonGlint.add(button)        every few seconds, first sweep after `delay`

const SWEEP := 0.75      # seconds the band takes to cross
const BAND := 0.22       # band width, as a share of the button's width

var every := 3.8
var _t := 0.0
var _k := -1.0           # sweep progress 0..1, -1 between sweeps

static func add(b: Button, delay := 1.4, gap := 3.8) -> ButtonGlint:
	var g := ButtonGlint.new()
	g.every = gap
	g._t = gap - delay
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(g)
	return g

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _k < 0.0:
		if _t >= every:
			_t = 0.0
			_k = 0.0
	else:
		_k += delta / SWEEP
		if _k >= 1.0:
			_k = -1.0
		queue_redraw()

func _draw() -> void:
	if _k < 0.0:
		return
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var face := _face(w, h)
	# the band leans the same way as the plate, a little steeper so it reads as a glint
	var e := 1.0 - pow(1.0 - _k, 3.0)
	var bw := w * BAND
	var lean := h * (UI.CUT + 0.25)
	var x := lerpf(-bw - lean, w + lean, e)
	var a := sin(_k * PI)  # fades in and out at the edges of its path
	for part in [[0.0, 1.0, 0.16], [0.3, 0.7, 0.22]]:  # soft edge, brighter core
		var x0 := x + bw * float(part[0])
		var x1 := x + bw * float(part[1])
		var band := PackedVector2Array([Vector2(x0 + lean, 0), Vector2(x1 + lean, 0), Vector2(x1, h), Vector2(x0, h)])
		for poly in Geometry2D.intersect_polygons(band, face):
			draw_colored_polygon(poly, Color(1, 1, 1, float(part[2]) * a))

## The button's face as StyleBoxFlat draws it: a rounded rectangle sheared by the plate's skew
## (top edge shifted right by skew * h / 2, bottom edge left).
func _face(w: float, h: float) -> PackedVector2Array:
	var r := 9.0 if h >= 48.0 else 7.0
	var pts := PackedVector2Array()
	var corners := [[Vector2(w - r, r), -PI * 0.5], [Vector2(w - r, h - r), 0.0], [Vector2(r, h - r), PI * 0.5], [Vector2(r, r), PI]]
	for c in corners:
		for i in 5:
			var ang: float = float(c[1]) + PI * 0.5 * i / 4.0
			var p: Vector2 = c[0] + Vector2(cos(ang), sin(ang)) * r
			p.x -= UI.CUT * (p.y - h * 0.5)
			pts.append(p)
	return pts
