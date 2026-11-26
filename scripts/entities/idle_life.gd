class_name IdleLife
extends SkeletonModifier3D
## Life on top of the idle clip: breathing, a slow shift of weight from leg to leg, and the head
## looking around now and then.
##
## The VARCO idle clips barely move (the hero's turns the head 6 degrees and the hips 1.4 in ten
## seconds), so a hero waiting between fights stood like a statue. This runs after the
## AnimationPlayer as a skeleton modifier and adds small rotations to the animated pose, only
## while the idle clip plays: it fades in after the blend from running or attacking and fades out
## at once when another clip starts, so attacks, runs and skills are exactly as animated. The
## skeleton restores the animated pose after skinning, so nothing accumulates. Rotations are given
## about the skeleton's axes (the model faces +Z, its left is +X) and turned into each bone's
## parent space, so the same numbers work for every VARCO character.

## How strongly to move (1 = hero).
var amount := 1.0
## Set by CharacterModel: true while "idle" is the current clip.
var want := false

var _w := 0.0
var _t := 0.0
var _breath := 0.0        # phase 0..1 of the current breath
var _breath_len := 3.8    # seconds; varies a little from breath to breath
var _sway_len := 8.0
var _sway_ph := 0.0
var _twist_len := 11.0
var _look := Vector2.ZERO      # head (yaw, pitch) in radians
var _look_v := Vector2.ZERO
var _look_to := Vector2.ZERO
var _look_hold := 1.5
var _bones := {}


func _ready() -> void:
	_sway_len = randf_range(7.0, 9.5)
	_sway_ph = randf() * TAU
	_twist_len = randf_range(10.0, 13.0)
	_breath = randf()
	_breath_len = randf_range(3.4, 4.2)
	_look_hold = randf_range(0.8, 2.5)
	active = false

func _bone(n: String) -> int:
	if not _bones.has(n):
		_bones[n] = get_skeleton().find_bone(n) if get_skeleton() else -1
	return _bones[n]

## Called by CharacterModel.play().
func set_idle(on: bool) -> void:
	want = on
	if on:
		active = true

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	delta = minf(delta, 0.1)
	# in slowly (the clip blends in from a run or a swing first), out at once
	_w = move_toward(_w, 1.0 if want else 0.0, delta * (1.6 if want else 8.0))
	if _w <= 0.0:
		active = false
		return
	_t += delta
	var k := _w * amount
	# breathing: a little quicker in than out; the next breath is a little longer or shorter
	_breath += delta / _breath_len
	if _breath >= 1.0:
		_breath -= 1.0
		_breath_len = randf_range(3.4, 4.2)
	var x := _breath * TAU
	var b := sin(x) + 0.22 * sin(2.0 * x - 0.6)
	# weight from one leg to the other (+1: on the left leg), with a slower twist of the hips
	var s := sin(_t * TAU / _sway_len + _sway_ph)
	var tw := sin(_t * TAU / _twist_len + _sway_ph * 1.7)
	_update_look(delta)
	var d := deg_to_rad(1.0) * k
	# pelvis tilts over the standing leg; the legs turn back so the feet stay planted, and the
	# resting leg's knee gives a little
	_rot(sk, "Hips", Vector3.BACK, 3.4 * s * d)
	_rot(sk, "Hips", Vector3.UP, 2.6 * tw * d)
	_rot(sk, "Hips", Vector3.RIGHT, 0.6 * b * d)
	_rot(sk, "LeftUpLeg", Vector3.BACK, -3.4 * s * d)
	_rot(sk, "RightUpLeg", Vector3.BACK, -3.4 * s * d)
	var rest_l := maxf(-s, 0.0)
	var rest_r := maxf(s, 0.0)
	_rot(sk, "LeftUpLeg", Vector3.RIGHT, -4.0 * rest_l * d)
	_rot(sk, "LeftLeg", Vector3.RIGHT, 8.0 * rest_l * d)
	_rot(sk, "RightUpLeg", Vector3.RIGHT, -4.0 * rest_r * d)
	_rot(sk, "RightLeg", Vector3.RIGHT, 8.0 * rest_r * d)
	# the spine bends back the other way (shoulders stay level) and the chest rises with each
	# breath, lifting the shoulders
	_rot(sk, "Spine", Vector3.BACK, -2.2 * s * d)
	_rot(sk, "Spine1", Vector3.BACK, -1.3 * s * d)
	_rot(sk, "Spine", Vector3.UP, -1.6 * tw * d)
	_rot(sk, "Spine1", Vector3.RIGHT, -1.2 * b * d)
	_rot(sk, "Spine2", Vector3.RIGHT, -1.8 * b * d)
	_rot(sk, "Spine2", Vector3.UP, _look.x * 0.15 * k)
	var lift := (b + 1.0) * 0.5
	_rot(sk, "LeftShoulder", Vector3.BACK, 2.6 * lift * d)
	_rot(sk, "RightShoulder", Vector3.BACK, -2.6 * lift * d)
	# arms: relaxed rather than mannequin-straight (elbows a little bent, hands a little forward),
	# swinging with the body a beat late
	var sw := sin(x - 0.9)
	_rot(sk, "LeftArm", Vector3.RIGHT, (-5.0 + 2.0 * sw) * d)
	_rot(sk, "RightArm", Vector3.RIGHT, (-4.0 + 1.6 * sw) * d)
	_rot(sk, "LeftArm", Vector3.BACK, -1.8 * s * d)
	_rot(sk, "RightArm", Vector3.BACK, -1.8 * s * d)
	_rot(sk, "LeftForeArm", Vector3.RIGHT, (-16.0 - 2.0 * lift) * d)
	_rot(sk, "RightForeArm", Vector3.RIGHT, (-12.0 - 2.0 * lift) * d)
	# the head keeps the eyes level through the breath and looks around
	_rot(sk, "Neck", Vector3.UP, _look.x * 0.35 * k)
	_rot(sk, "Neck", Vector3.RIGHT, _look.y * 0.4 * k)
	_rot(sk, "Head", Vector3.UP, _look.x * 0.5 * k)
	_rot(sk, "Head", Vector3.RIGHT, _look.y * 0.6 * k + 1.6 * b * d)
	_rot(sk, "Head", Vector3.BACK, 1.4 * s * d - _look.x * 0.08 * k)  # a slight tilt into the turn

## Now and then a new place to look at (often straight ahead again), reached with a damped spring:
## quick to start, soft to settle, like a real turn of the head.
func _update_look(delta: float) -> void:
	_look_hold -= delta
	if _look_hold <= 0.0:
		if _look_to != Vector2.ZERO and randf() < 0.45:
			_look_to = Vector2.ZERO
			_look_hold = randf_range(1.8, 4.0)
		else:
			_look_to = Vector2(deg_to_rad(randf_range(-38.0, 38.0)), deg_to_rad(randf_range(-4.0, 10.0)))
			_look_hold = randf_range(1.2, 3.2)
	var w := 7.0
	var acc := (_look_to - _look) * w * w - _look_v * 2.0 * w
	_look_v += acc * delta
	_look += _look_v * delta

## Turns a bone about an axis of the skeleton (not of the bone): the axis is carried into the
## parent's space, where the bone's pose rotation lives.
func _rot(sk: Skeleton3D, bone_name: String, axis: Vector3, ang: float) -> void:
	if absf(ang) < 0.00001:
		return
	var bi := _bone(bone_name)
	if bi < 0:
		return
	var parent := sk.get_bone_parent(bi)
	var pq := Quaternion.IDENTITY
	if parent >= 0:
		pq = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var la := (pq.inverse() * axis).normalized()
	sk.set_bone_pose_rotation(bi, Quaternion(la, ang) * sk.get_bone_pose_rotation(bi))
