class_name CameraRig
extends Node3D
## Strategy camera: drag to pan, pinch / wheel to zoom, smooth follow, screen shake.

signal tapped(screen_pos: Vector2)

var cam: Camera3D
var target := Vector3.ZERO
var zoom := 30.0
var zoom_min := 16.0
var zoom_max := 40.0
var pitch_deg := 54.0
var bounds := Rect2(-30, -18, 60, 34)
var input_enabled := true
var free := false  # cut-scenes may frame spots outside the playable bounds

var _pos := Vector3.ZERO
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_time := 0
var _moved := 0.0
var _touches := {}
var _pinch_start := 0.0
var _pinch_zoom := 0.0
var _shake := 0.0
var _last_mouse := Vector2.ZERO
var _vel := Vector3.ZERO

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.5
	cam.far = 220.0
	add_child(cam)
	_pos = target
	_apply(0.0)

func set_bounds(r: Rect2) -> void:
	bounds = r

func shake(amount: float) -> void:
	if not Game.screen_shake:
		return
	_shake = maxf(_shake, amount)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() == 2:
			var k := _touches.keys()
			_pinch_start = (_touches[k[0]] as Vector2).distance_to(_touches[k[1]])
			_pinch_zoom = zoom
			_dragging = false
			_moved = 999.0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_start > 0.0:
			var k := _touches.keys()
			var dist := (_touches[k[0]] as Vector2).distance_to(_touches[k[1]])
			zoom = clampf(_pinch_zoom * _pinch_start / maxf(dist, 1.0), zoom_min, zoom_max)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clampf(zoom * 0.9, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clampf(zoom * 1.1, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_dragging = true
				_press_pos = mb.position
				_last_mouse = mb.position
				_press_time = Time.get_ticks_msec()
				_moved = 0.0
				_vel = Vector3.ZERO
			else:
				_dragging = false
				if _moved < 14.0 and mb.button_index == MOUSE_BUTTON_LEFT and _touches.size() <= 1:
					tapped.emit(mb.position)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		if _touches.size() >= 2:
			return
		var delta := mm.position - _last_mouse
		_last_mouse = mm.position
		_moved += delta.length()
		if _moved < 8.0:
			return
		# convert pixel motion to world motion at ground plane
		var vp := get_viewport().get_visible_rect().size
		# the field of view spans the screen's short side (see _fit_aspect)
		var world_per_px := 2.0 * zoom * tan(deg_to_rad(cam.fov * 0.5)) / (vp.x if Game.tall else vp.y)
		var move := Vector3(-delta.x, 0, -delta.y / sin(deg_to_rad(pitch_deg))) * world_per_px
		target += move
		_vel = move * 30.0
		_clamp()

func _clamp() -> void:
	if free:
		return
	var margin := (zoom - zoom_min) / (zoom_max - zoom_min)
	var shrink_x := lerpf(0.0, bounds.size.x * 0.32, margin)
	var shrink_z := lerpf(0.0, bounds.size.y * 0.3, margin)
	target.x = clampf(target.x, bounds.position.x + shrink_x, bounds.end.x - shrink_x)
	target.z = clampf(target.z, bounds.position.y + shrink_z, bounds.end.y - shrink_z)

func _process(delta: float) -> void:
	var rd := minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	if not _dragging and _vel.length() > 0.05:
		target += _vel * rd
		_vel = _vel.lerp(Vector3.ZERO, clampf(rd * 6.0, 0.0, 1.0))
		_clamp()
	_clamp()
	_apply(rd)

## Upright screens: the field of view is kept across the width (the short side), so units keep
## the size they have with the phone held sideways and the extra height shows more of the map;
## kept across the height, an upright view would be a narrow slit of the battlefield. The far
## zoom-out also goes further, so the whole width of a map can still be seen at once.
func _fit_aspect() -> void:
	var want := Camera3D.KEEP_WIDTH if Game.tall else Camera3D.KEEP_HEIGHT
	if cam.keep_aspect != want:
		cam.keep_aspect = want
		zoom_max = 54.0 if Game.tall else 40.0
		zoom = clampf(zoom, zoom_min, zoom_max)

func _apply(rd: float) -> void:
	_fit_aspect()
	_pos = _pos.lerp(target, clampf(rd * 12.0, 0.0, 1.0)) if rd > 0.0 else target
	var p := deg_to_rad(pitch_deg)
	var off := Vector3(0, sin(p), cos(p)) * zoom
	var sh := Vector3.ZERO
	if _shake > 0.0:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.35
		_shake = maxf(_shake - rd * 3.0, 0.0)
	cam.global_position = _pos + off + sh
	cam.look_at(_pos + sh * 0.5, Vector3.UP)

func ground_point(screen: Vector2, y := 0.0) -> Vector3:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return from
	var t := (y - from.y) / dir.y
	return from + dir * t

func focus(p: Vector3, z := -1.0) -> void:
	target = Vector3(p.x, 0, p.z)
	if z > 0:
		zoom = z
	_clamp()
