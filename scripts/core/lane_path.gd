class_name LanePath
extends RefCounted
## Smoothed, evenly resampled 2D path (x,z). Enemies move along it by distance.

const STEP := 0.5

var pts := PackedVector2Array()
var length := 0.0

func _init(raw: Array) -> void:
	var ctrl := PackedVector2Array()
	for p in raw:
		ctrl.append(Vector2(p[0], p[1]))
	# Catmull-Rom smoothing
	var dense := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in 12:
			var t := s / 12.0
			dense.append(_cr(p0, p1, p2, p3, t))
	dense.append(ctrl[ctrl.size() - 1])
	# resample evenly
	pts.append(dense[0])
	var carry := 0.0
	var prev := dense[0]
	for i in range(1, dense.size()):
		var cur := dense[i]
		var seg := prev.distance_to(cur)
		while carry + seg >= STEP:
			var need := STEP - carry
			var np := prev.lerp(cur, need / seg)
			pts.append(np)
			seg -= need
			prev = np
			carry = 0.0
		carry += seg
		prev = cur
	pts.append(dense[dense.size() - 1])
	length = (pts.size() - 1) * STEP

static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func sample(d: float) -> Vector2:
	d = clampf(d, 0.0, length)
	var f := d / STEP
	var i := int(f)
	if i >= pts.size() - 1:
		return pts[pts.size() - 1]
	return pts[i].lerp(pts[i + 1], f - i)

func tangent(d: float) -> Vector2:
	var a := sample(d - 0.6)
	var b := sample(d + 0.6)
	var t := b - a
	return t.normalized() if t.length_squared() > 0.0001 else Vector2.RIGHT

func closest(p: Vector2) -> Vector2:
	## returns Vector2(distance_to_path, offset_along_path)
	var best := 1e9
	var best_i := 0
	for i in range(0, pts.size(), 2):
		var dd := pts[i].distance_squared_to(p)
		if dd < best:
			best = dd
			best_i = i
	var lo := maxi(best_i - 3, 0)
	var hi := mini(best_i + 3, pts.size() - 2)
	var bd := 1e9
	var boff := 0.0
	for i in range(lo, hi + 1):
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var q := a + ab * t
		var dd := q.distance_to(p)
		if dd < bd:
			bd = dd
			boff = (i + t) * STEP
	return Vector2(bd, boff)
