extends Node
## Streamed game content: 3D models, characters and the battle music (tools/split_pck.py).
## On the web the page downloads index[_mobile]_content.pck right after the small core pack, while
## the title screen is already up, and copies it to PACK_PATH in the engine's file system; this node
## mounts it as soon as it is there.  Native builds, the editor and unsplit packs have everything
## in the main pack and are ready at once.
##   content_pack=<path> [content_delay=<s>] (user args): mount a local content pack after a delay,
##   to try the streamed start natively.

signal content_ready

const PROBE := "res://assets/models/castle.glb"
const PACK_PATH := "/tmp/rb_content.pck"

var is_ready := false
var progress := 0.0  # 0..1 download progress of the content pack
var failed := false
var _local_pack := ""
var _local_at := 0.0
var _t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("content_pack="):
			_local_pack = a.substr(13)
		elif a.begins_with("content_delay="):
			_local_at = float(a.substr(14))
	if _local_pack == "" and (ResourceLoader.exists(PROBE) or not OS.has_feature("web")):
		_finish()
		return
	if _local_pack == "":
		_poll()  # a cached content pack may already be here: then the title screen starts in 3D

func _poll() -> void:
	# rbContentMount() copies a fetched pack into the file system and reports the state
	var st := str(JavaScriptBridge.eval("window.rbContentMount ? window.rbContentMount() + ' ' + window.rbContent.p : 'none 0'", true))
	var parts := st.split(" ")
	progress = clampf(float(parts[1]) if parts.size() > 1 else 0.0, 0.0, 1.0)
	match parts[0]:
		"ready":
			_mount(PACK_PATH)
		"none":
			# the page streams no content pack and the main pack has none: nothing will arrive
			push_error("content pack missing")
			failed = true
			set_process(false)
		"error":
			failed = true
		_:
			failed = false

func _process(delta: float) -> void:
	_t += delta
	if _local_pack != "":
		progress = clampf(_t / maxf(_local_at, 0.01), 0.0, 1.0)
		if _t >= _local_at:
			_mount(_local_pack)
		return
	_poll()

func _mount(path: String) -> void:
	set_process(false)
	var t0 := Time.get_ticks_msec()
	if not ProjectSettings.load_resource_pack(path, true):
		push_error("could not mount " + path)
		failed = true
		return
	Game.mark("content_mounted")
	print("content pack mounted in %d ms" % (Time.get_ticks_msec() - t0))
	_finish()

func _finish() -> void:
	is_ready = true
	progress = 1.0
	set_process(false)
	content_ready.emit()

## A modal "preparing the battle" card with a progress bar, shown until the content is mounted.
func wait_with_overlay() -> void:
	if is_ready:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.theme = UI.theme()
	shade.add_child(cc)
	var pc := UI.framed("dark", 26.0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(vb)
	var lb := UI.label("전장을 준비하는 중...", 26)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lb)
	var bar := UI.bar("gold", 420.0, 18.0)
	bar.max_value = 100.0
	vb.add_child(bar)
	var pct := UI.label("0%", 20, UI.MUTED)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pct)
	UI.pop_in(pc)
	while not is_ready:
		var p := roundf(progress * 100.0)
		bar.value = p
		pct.text = ("연결이 끊겼습니다. 다시 시도하는 중..." if failed else "%d%%" % int(p))
		await get_tree().process_frame
	bar.value = 100.0
	var tw := create_tween()
	tw.tween_property(shade, "modulate:a", 0.0, 0.25)
	await tw.finished
	layer.queue_free()
