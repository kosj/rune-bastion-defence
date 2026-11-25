class_name ResGuard
extends Node
## Keeps the game smooth on devices whose GPU cannot draw the 3D scene at full resolution.
## When frames stay slow, the 3D view (never the UI) is drawn slightly smaller and scaled up;
## when there is headroom again it climbs back to the quality setting's resolution. A step that
## does not raise the frame rate (the CPU, not the GPU, is the limit) is undone at once, so
## machines that already run well never see a change.

const WINDOW := 2.0  # seconds of frames per decision
const MIN_SCALE := 0.6

var _acc := 0.0
var _frames := 0
var _cool := 3.0  # let the level settle first
var _trial_from := -1.0
var _fps_before := 0.0
var _ceiling := 1.0
var _ceiling_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	_acc = 0.0
	_frames = 0
	_cool = 3.0
	_trial_from = -1.0
	_ceiling = 1.0

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	if Game.testing or get_tree().paused or real > 0.5:
		_acc = 0.0
		_frames = 0
		return
	_acc += real
	_frames += 1
	if _acc < WINDOW:
		return
	var fps := _frames / _acc
	_acc = 0.0
	_frames = 0
	_cool -= WINDOW
	_ceiling_t -= WINDOW
	if _ceiling_t <= 0.0:
		_ceiling = 1.0
	var vp := get_tree().root
	var base := Game.base_3d_scale()
	var s := vp.scaling_3d_scale
	var target := 60.0 if Engine.max_fps <= 0 else minf(Engine.max_fps, 60.0)
	if _trial_from > 0.0:
		if fps < _fps_before * 1.06:
			# no gain: the GPU was not the limit; restore and leave it alone for a while
			vp.scaling_3d_scale = _trial_from
			_cool = 60.0
		else:
			_ceiling = _trial_from
			_ceiling_t = 45.0
		_trial_from = -1.0
		return
	if _cool > 0.0:
		return
	if fps < target * 0.8 and s > MIN_SCALE + 0.01:
		_fps_before = fps
		_trial_from = s
		vp.scaling_3d_scale = maxf(MIN_SCALE, s - 0.1)
		_cool = 2.0
	elif fps > target * 0.96 and s < minf(base, _ceiling) - 0.01:
		vp.scaling_3d_scale = minf(minf(base, _ceiling), s + 0.05)
		_cool = 8.0
