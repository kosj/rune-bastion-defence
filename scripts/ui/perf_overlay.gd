class_name PerfOverlay
extends CanvasLayer
## Small performance readout for testing on real phones and tablets: frame rate, frame time (mean
## and worst), hitches, draw calls, memory, screen and GPU. Turn it on with "?perf=1" in the page
## address, or F3 on a keyboard. It sits above everything and ignores input.

const HITCH_MS := 50.0
var _label: Label
var _acc := 0.0
var _frames := 0
var _worst := 0.0
var _sum := 0.0
var _hitches := 0
var _gpu := ""

static func toggle(tree: SceneTree) -> void:
	var cur := tree.root.get_node_or_null("PerfOverlay")
	if cur:
		cur.queue_free()
	else:
		var p := PerfOverlay.new()
		p.name = "PerfOverlay"
		tree.root.add_child(p)

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gpu = RenderingServer.get_video_adapter_name()
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(8 + Game.safe.x, 70 + Game.safe.y)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)

func _process(delta: float) -> void:
	var ms := delta * 1000.0 / maxf(Engine.time_scale, 0.01)
	_frames += 1
	_sum += ms
	_worst = maxf(_worst, ms)
	if ms > HITCH_MS:
		_hitches += 1
	_acc += delta / maxf(Engine.time_scale, 0.01)
	if _acc < 0.5:
		return
	var avg := _sum / maxf(_frames, 1)
	var vs := get_viewport().get_visible_rect().size
	var win := DisplayServer.window_get_size()
	var lines := [
		"%d fps  %.1f ms (worst %.0f)  hitches %d" % [Engine.get_frames_per_second(), avg, _worst, _hitches],
		"draws %d  prims %dk" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000],
		"vram %.0f MB  ram %.0f MB" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
			OS.get_static_memory_usage() / 1048576.0],
		"%dx%d (window %dx%d)  %s%s" % [vs.x, vs.y, win.x, win.y, "HQ" if Game.high_quality else "LQ", "  30fps" if Game.battery_saver else ""],
		"safe area l%d t%d r%d b%d" % [Game.safe.x, Game.safe.y, Game.safe.z, Game.safe.w],
		_gpu,
	]
	if LevelMain.I and is_instance_valid(LevelMain.I):
		lines.append("enemies %d  soldiers %d" % [LevelMain.I.enemies.size(), LevelMain.I.soldiers.size()])
	_label.text = "\n".join(lines)
	_acc = 0.0
	_frames = 0
	_sum = 0.0
	_worst = 0.0
