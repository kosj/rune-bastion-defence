extends Node
## Download chunks of the web build (scripts/data/pack_chunks.gd, split by tools/split_pck.py).
## The page starts the engine with the small core pack, then fetches the other chunks one after
## another (menu, stage1, towers, world) while the game already runs, and copies each into the
## engine's file system; this node mounts them with load_resource_pack() as they arrive.
## Native builds, the editor and unsplit packs have everything and are ready at once.
##
## Callers ask before they load (see the rules in pack_chunks.gd):
##   Content.has("menu") / has_all([...])     is it mounted?
##   await Content.ensure([...], label)       wait behind a progress card until it is
##   Content.allows(path)                     may this asset be loaded now?
##   Content.level_needs(level)               chunks a battle needs before it can start
##
## Native test option (user args): chunks=menu:1,stage1:4 makes only core plus the listed chunks
## available, each after the given seconds (a bare name means at once, chunks=none means core
## only). Loading an asset of a missing chunk then prints "CHUNK MISS" (tools/check_chunks.sh).

signal chunk_ready(chunk: String)

const PROBE := "res://assets/models/castle.glb"

var _have := {"core": true}
var _state := {}   # chunk -> pending / loading / fetched / ready / error / mounted
var _p := {}       # chunk -> download progress 0..1
var _bytes := {}   # chunk -> download size (weights the progress of several chunks)
var _sim := {}     # test option: chunk -> seconds until it arrives
var _simulating := false
var _t := 0.0
var failed := false
var misses := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("chunks="):
			_simulating = true
			for item in a.substr(7).split(",", false):
				if item == "none":
					continue
				var kv := item.split(":")
				_sim[kv[0]] = float(kv[1]) if kv.size() > 1 else 0.0
	if _simulating:
		print("CHUNKS simulated: ", _sim)
		_tick_sim()
		return
	if not OS.has_feature("web"):
		_all()
		return
	_poll()  # chunks cached by the service worker may already be here
	if _state.is_empty() and ResourceLoader.exists(PROBE):
		_all()  # an unsplit pack: everything is in the main pack

func order() -> Array:
	return PackChunks.DATA["order"]

func has(chunk: String) -> bool:
	return _have.has(chunk)

func has_all(chunks: Array) -> bool:
	for c in chunks:
		if not _have.has(c):
			return false
	return true

func all_ready() -> bool:
	return has_all(order())

## May this asset be loaded now? (Before its chunk is mounted it does not exist on the web; the
## native test option makes the same true by refusing it here.)
func allows(path: String) -> bool:
	return _have.has(PackChunks.chunk_of(path))

## An asset was asked for before its chunk arrived: a missing Content.ensure / has check.
func miss(path: String) -> void:
	misses += 1
	push_warning("CHUNK MISS %s (%s)" % [path, PackChunks.chunk_of(path)])
	if _simulating:
		print("CHUNK MISS %s (%s)" % [path, PackChunks.chunk_of(path)])

## Chunks a battle needs: the first battle of a new player (level 1 with Kael) only the menu and
## stage1 chunks, everything else all of them.
func level_needs(level: int) -> Array:
	var fb: Dictionary = PackChunks.DATA["first_battle"]
	if level == int(fb["level"]) and Game.hero_id == fb["hero"] and not Game.endless:
		return fb["needs"]
	var all := order().duplicate()
	all.erase("core")
	return all

## Download progress (0..1) of a set of chunks, weighted by their sizes.
func progress(chunks: Array) -> float:
	var tot := 0.0
	var got := 0.0
	for c in chunks:
		var w := float(_bytes.get(c, 1.0))
		tot += w
		got += w * (1.0 if _have.has(c) else float(_p.get(c, 0.0)))
	return got / tot if tot > 0.0 else 1.0

func _all() -> void:
	for c in order():
		if not _have.has(c):
			_have[c] = true
			chunk_ready.emit(c)
	set_process(false)

func _process(delta: float) -> void:
	_t += delta
	if _simulating:
		_tick_sim()
	else:
		_poll()

func _tick_sim() -> void:
	for c in _sim:
		if not _have.has(c):
			_p[c] = clampf(_t / maxf(float(_sim[c]), 0.01), 0.0, 1.0)
			if _t >= float(_sim[c]):
				_have[c] = true
				Game.mark("chunk_" + c)
				chunk_ready.emit(c)

func _poll() -> void:
	# rbChunks() copies fetched chunks into the file system and reports every chunk as
	# name:state:progress:bytes;...  ("none" when the page streams no chunks)
	var st := str(JavaScriptBridge.eval("window.rbChunks ? window.rbChunks() : 'none'", true))
	if st == "none" or st == "":
		set_process(false)
		return
	failed = false
	for item in st.split(";", false):
		var f := item.split(":")
		if f.size() < 4:
			continue
		var c := f[0]
		_state[c] = f[1]
		_p[c] = float(f[2])
		_bytes[c] = float(f[3])
		if f[1] == "error":
			failed = true
	# mount in download order
	for c in order():
		if c == "core" or _have.has(c):
			continue
		if _state.get(c, "") != "ready":
			break
		_mount(c)
	if all_ready():
		set_process(false)

func _mount(c: String) -> void:
	var t0 := Time.get_ticks_msec()
	if not ProjectSettings.load_resource_pack("/tmp/rb_%s.pck" % c, true):
		push_error("could not mount chunk " + c)
		failed = true
		return
	_have[c] = true
	_state[c] = "mounted"
	Game.mark("chunk_" + c)
	print("chunk %s mounted in %d ms" % [c, Time.get_ticks_msec() - t0])
	chunk_ready.emit(c)

## Wait for chunks; while they are missing a modal card shows the download progress.
func ensure(chunks: Array, label := "데이터를 받는 중...") -> bool:
	if has_all(chunks):
		return true
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
	var lb := UI.label(label, 26)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lb)
	var bar := UI.bar("gold", 420.0, 18.0)
	bar.max_value = 100.0
	vb.add_child(bar)
	var pct := UI.label("0%", 20, UI.MUTED)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pct)
	UI.pop_in(pc)
	while not has_all(chunks):
		var p := roundf(progress(chunks) * 100.0)
		bar.value = p
		pct.text = ("연결이 끊겼습니다. 다시 시도하는 중..." if failed else "%d%%" % int(p))
		await get_tree().process_frame
	bar.value = 100.0
	var tw := create_tween()
	tw.tween_property(shade, "modulate:a", 0.0, 0.25)
	await tw.finished
	layer.queue_free()
	return true
