class_name ResultFX
extends RefCounted
## Choreography of the victory screen, after Defold's "level complete" sample and the "Juice it or
## lose it" talk: nothing appears out of nowhere; each star slams in (big to normal, eased in) and
## lands with a flash, a shock ring, a ring of sparks, a short shake and a haptic tick; the numbers
## count up; the buttons come last and the main one breathes. A tap on the backdrop fast-forwards.

const SKIP := 6.0  # speed of a fast-forwarded sequence

var root: Control         # full-screen layer for confetti (the modal's backdrop)
var shake_node: Control   # nudged for the impact shake
var tweens: Array[Tween] = []
var fast := false
var _tick_at := 0.0
static var _add_mat: CanvasItemMaterial

func _init(layer: Control, shake: Control) -> void:
	root = layer
	shake_node = shake

## A tween of the sequence: real time (the game may be in slow motion), tracked for the skip.
func tween(n: Node) -> Tween:
	var t := n.create_tween()
	t.set_ignore_time_scale(true)
	if fast:
		t.set_speed_scale(SKIP)
	tweens.append(t)
	return t

func skip() -> void:
	if fast:
		return
	fast = true
	for t in tweens:
		if t.is_valid() and t.is_running():
			t.set_speed_scale(SKIP)

static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

## Fade + slight pop for a block that should not just appear.
## Buttons take no taps while still invisible.
func reveal(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	var mf := c.mouse_filter
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(func():
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(0.94, 0.94)
		var t := tween(c).set_parallel(true)
		t.tween_property(c, "modulate:a", 1.0, 0.16).set_delay(delay)
		t.tween_property(c, "scale", Vector2.ONE, 0.22).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): c.mouse_filter = mf).set_delay(delay)).call_deferred()

## The title pennant cuts open across the top of the card (from its left edge) and the card takes
## a small knock.
func slam(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	(func():
		c.pivot_offset = Vector2(0, c.size.y * 0.5)
		c.scale = Vector2(0.0, 1.0)
		var t := tween(c)
		t.tween_interval(delay)
		# parallel() joins only the next step to the one before it (set_parallel would also join
		# the waiting interval, and everything would start at once)
		t.tween_property(c, "modulate:a", 1.0, 0.04)
		t.parallel().tween_property(c, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): shake(3.0))).call_deferred()

## One earned star: stamped onto the card (down from 1.7x, a squash on contact, settled without
## wobble), then a flat ring, a few sparks, a knock, haptics and the chime.
func star(parent: Control, center: Vector2, sz: float, delay: float, i: int) -> void:
	var st := UI.icon(Assets.tex("star"), int(sz))
	st.size = Vector2(sz, sz)
	st.position = center - st.size * 0.5
	st.pivot_offset = st.size * 0.5
	st.scale = Vector2(1.7, 1.7)
	st.rotation = -0.18
	st.modulate.a = 0.0
	parent.add_child(st)
	var t := tween(st)
	t.tween_interval(delay)
	t.tween_property(st, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(st, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(st, "rotation", 0.0, 0.13)
	t.tween_callback(func(): _impact(parent, center, sz, i))
	t.tween_property(st, "scale", Vector2(1.14, 0.86), 0.05)
	t.tween_property(st, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _impact(parent: Control, c: Vector2, sz: float, i: int) -> void:
	Audio.play_pitched("star", -2.0 + i * 1.5, 1.0 + i * 0.125)
	ring(parent, c, sz * 0.45, sz * 1.2)
	sparks(parent, c, 8 if i == 1 else 6, sz)
	shake(4.0 + 2.5 * i)
	Game.vibrate(20 + 10 * i)

## Soft additive bloom that blows up and fades.
func flash(parent: Control, c: Vector2, d: float, col := Color(1.0, 0.85, 0.45)) -> void:
	var g := UI.icon(UI.kit("glow"), int(d))
	g.material = additive()
	g.size = Vector2(d, d)
	g.position = c - g.size * 0.5
	g.pivot_offset = g.size * 0.5
	g.scale = Vector2(0.5, 0.5)
	g.modulate = col
	parent.add_child(g)
	var t := tween(g).set_parallel(true)
	t.tween_property(g, "scale", Vector2(1.35, 1.35), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(g, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(g.queue_free)

## Expanding shock ring.
func ring(parent: Control, c: Vector2, r0: float, r1: float) -> void:
	var rc := Control.new()
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rc.position = c
	parent.add_child(rc)
	rc.set_meta("k", 0.0)
	rc.draw.connect(func():
		var k: float = rc.get_meta("k")
		rc.draw_arc(Vector2.ZERO, lerpf(r0, r1, k), 0.0, TAU, 56, Color(UI.GOLD, 1.0 - k), lerpf(5.0, 1.5, k), true))
	var t := tween(rc)
	t.tween_method(func(k: float):
		rc.set_meta("k", k)
		rc.queue_redraw(), 0.0, 1.0, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(rc.queue_free)

## A ring of small stars thrown outwards (16 at 22.5 degrees in the Defold sample).
func sparks(parent: Control, c: Vector2, n: int, sz: float) -> void:
	for k in n:
		var s := UI.icon(Assets.tex("star"), 20)
		var d := randf_range(14.0, 22.0)
		s.size = Vector2(d, d)
		s.position = c - s.size * 0.5
		s.pivot_offset = s.size * 0.5
		s.scale = Vector2(0.3, 0.3)
		parent.add_child(s)
		var ang := TAU * k / n + randf_range(-0.12, 0.12)
		var dist := sz * randf_range(0.9, 1.7)
		var t := tween(s).set_parallel(true)
		t.tween_property(s, "position", s.position + Vector2.from_angle(ang) * dist, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(s, "scale", Vector2.ONE * randf_range(0.6, 1.3), 0.55)
		t.tween_property(s, "rotation", randf_range(-3.0, 3.0), 0.55)
		t.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.25)
		t.chain().tween_callback(s.queue_free)

## Short decaying shake of the whole result card (off with the screen-shake setting).
func shake(amp: float) -> void:
	if not Game.screen_shake or shake_node == null or fast:
		return
	var home := shake_node.position
	var t := tween(shake_node)
	t.tween_method(func(k: float):
		shake_node.position = home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amp * (1.0 - k), 0.0, 1.0, 0.2)
	t.tween_callback(func(): shake_node.position = home)

## Numbers run up to their value (eased out, a tick now and then) and punch at the end.
func count_up(l: Label, fmt: Callable, target: int, delay: float, dur := 0.7) -> void:
	l.text = fmt.call(0)
	var t := tween(l)
	t.tween_interval(delay)
	t.tween_method(func(v: float):
		l.text = fmt.call(int(round(v)))
		var now := Time.get_ticks_msec() / 1000.0
		if not fast and now - _tick_at > 0.07 and target > 0:
			_tick_at = now
			Audio.play("tick", -16.0), 0.0, float(target), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func():
		l.pivot_offset = l.size * 0.5
		var p := tween(l)
		p.tween_property(l, "scale", Vector2(1.18, 1.18), 0.06)
		p.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## Confetti over the whole screen for a perfect clear.
func confetti(n: int, delay: float) -> void:
	var vs := root.get_viewport_rect().size
	var cols := [UI.GOLD, UI.EMBER, UI.AZURE, UI.VELLUM]
	for k in n:
		var p := ColorRect.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.color = cols[k % cols.size()]
		p.size = Vector2(randf_range(7, 11), randf_range(12, 18))
		p.pivot_offset = p.size * 0.5
		var x := randf_range(0.05, 0.95) * vs.x
		p.position = Vector2(x, -30.0 - randf() * vs.y * 0.25)
		p.modulate.a = 0.0
		root.add_child(p)
		var fall := randf_range(1.9, 2.8)
		var t := tween(p).set_parallel(true)
		t.tween_property(p, "modulate:a", 1.0, 0.1).set_delay(delay)
		t.tween_property(p, "position", Vector2(x + randf_range(-60, 60), vs.y * randf_range(0.75, 1.05)), fall).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		t.tween_property(p, "rotation", randf_range(-9.0, 9.0), fall).set_delay(delay)
		t.tween_property(p, "modulate:a", 0.0, 0.5).set_delay(delay + fall - 0.5)
		t.chain().tween_callback(p.queue_free)

## Slow breathing of the main button once everything has landed (not tracked: it never ends).
static func breathe(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween().set_loops()
	t.set_ignore_time_scale(true)
	t.tween_property(c, "scale", Vector2(1.06, 1.06), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
