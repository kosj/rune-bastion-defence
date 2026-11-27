class_name SceneWipe
extends Control
## The scene change: an ink panel with a slanted leading edge sweeps across the screen from the
## left (cover), and after the new scene is up sweeps on off the right (uncover). An or stripe
## rides the slanted edge. Drawn as polygons, so it is crisp at any size.

const SLANT := 0.22   # the edge's lean, as a fraction of the screen height
const STRIPE := 10.0  # the or stripe on the edge (canvas units)

var _k := 0.0        # 0 = clear, 1 = covered
var _leaving := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Sweeps the panel in; returns when the screen is covered.
func cover(t: float) -> void:
	_leaving = false
	var tw := create_tween()
	tw.tween_method(_set_k, 0.0, 1.0, t).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

## Sweeps the panel on and off the far side; returns when the screen is clear.
func uncover(t: float) -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_method(_set_k, 1.0, 0.0, t).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_leaving = false

func _set_k(k: float) -> void:
	_k = k
	queue_redraw()

func _draw() -> void:
	if _k <= 0.0:
		return
	var w := size.x
	var h := size.y
	var sl := h * SLANT
	if w <= 1.0 or h <= 1.0:
		return
	if _k >= 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), UI.SABLE)
		return
	if not _leaving:
		# the leading edge runs from off the left to past the right
		var x := lerpf(-sl, w + sl, _k)
		# (the far side reaches well off screen, so the quad never folds over itself)
		draw_colored_polygon(PackedVector2Array([Vector2(-w - sl, -1), Vector2(x + sl * 0.5, -1), Vector2(x - sl * 0.5, h + 1), Vector2(-w - sl, h + 1)]), UI.SABLE)
		_stripe(x, sl, h, 1.0)
	else:
		# the trailing edge follows it off the right
		var x2 := lerpf(w + sl, -sl, _k)
		draw_colored_polygon(PackedVector2Array([Vector2(x2 + sl * 0.5, -1), Vector2(2.0 * w + sl, -1), Vector2(2.0 * w + sl, h + 1), Vector2(x2 - sl * 0.5, h + 1)]), UI.SABLE)
		_stripe(x2, sl, h, -1.0)

func _stripe(x: float, sl: float, h: float, side: float) -> void:
	var d := STRIPE * side
	draw_colored_polygon(PackedVector2Array([Vector2(x + sl * 0.5, -1), Vector2(x + sl * 0.5 + d, -1), Vector2(x - sl * 0.5 + d, h + 1), Vector2(x - sl * 0.5, h + 1)]), UI.GOLD)
