class_name CharacterModel
extends Node3D
## Wraps an imported VARCO character (skeleton + AnimationPlayer) with weapons, tint and helpers.

const LOOPING := ["idle", "run", "roar_loop"]
## Some VARCO motion clips (jog_looping) are authored facing sideways; correct per clip.
const YAW_FIX := {"hero": {"run": 90.0}, "footman": {"run": 90.0}, "goblin": {"run": 90.0}, "sapper": {"run": 90.0}, "sera": {"run": 90.0}, "ranger": {"run": 90.0}, "orc": {"attack": -90.0}, "ogre": {"roar": -90.0}}
const ATTACK_IMPACT := 0.62  # seconds into the trimmed attack clip

static var _prepared := {}
static var _tint_mats := {}
static var _blob_mesh: QuadMesh
static var _blob_mat: StandardMaterial3D

var anim: AnimationPlayer
var skel: Skeleton3D
var body: MeshInstance3D
var model_name := ""
var current := ""
var flash := 0.0
var _flash_mat: StandardMaterial3D
var _base_mat: Material
var _inst: Node3D
var _yaw_target := 0.0
var _blob: MeshInstance3D
var _blob_size := 1.0
## Flying units (gargoyles) hover above the ground: no contact shadow under them.
var ground_blob := true

func setup(p_model: String, p_scale: float, tint := Color.WHITE, weapon := "") -> CharacterModel:
	model_name = p_model
	var inst := Assets.instance(p_model)
	_inst = inst
	add_child(inst)
	inst.scale = Vector3.ONE * p_scale
	anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		body = mi
		break
	if anim:
		_prepare_anims(p_model)
		anim.playback_default_blend_time = 0.15
	if body:
		_base_mat = body.mesh.surface_get_material(0)
		if tint != Color.WHITE:
			body.material_override = _tinted(p_model, tint)
	if weapon != "" and skel:
		attach_weapon(weapon)
	_blob_size = clampf(p_scale * 0.55, 0.7, 3.0)
	add_to_group("unit_shadow")
	refresh_shadow()
	return self

## Shadows by quality: real shadow-map shadows on the high setting; on the low setting (phones)
## units skip the shadow pass (their dense skinned meshes are most of its cost) and get a soft
## contact blob instead. Called again for every unit when the setting changes.
func refresh_shadow() -> void:
	var cheap := not Game.high_quality
	for g in find_children("*", "GeometryInstance3D", true, false):
		if g != _blob:
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if cheap else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if cheap and ground_blob and _blob == null:
		_blob = MeshInstance3D.new()
		_blob.mesh = _blob_quad()
		_blob.material_override = _blob_material()
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blob.rotation_degrees.x = -90.0
		_blob.position.y = 0.14
		_blob.scale = Vector3.ONE * _blob_size
		add_child(_blob)
	if _blob:
		_blob.visible = cheap and ground_blob

static func _blob_quad() -> QuadMesh:
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2(1, 1)
	return _blob_mesh

static func _blob_material() -> StandardMaterial3D:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.02, 0.03, 0.8))
		g.set_color(1, Color(0.02, 0.02, 0.03, 0.0))
		g.add_point(0.5, Color(0.02, 0.02, 0.03, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = gt
		_blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_blob_mat.render_priority = -1
	return _blob_mat

func _prepare_anims(key: String) -> void:
	if _prepared.has(key):
		return
	_prepared[key] = true
	for n in anim.get_animation_list():
		var a := anim.get_animation(n)
		if n in LOOPING:
			a.loop_mode = Animation.LOOP_LINEAR
		else:
			a.loop_mode = Animation.LOOP_NONE

func _tinted(key: String, tint: Color) -> Material:
	var k := key + str(tint)
	if _tint_mats.has(k):
		return _tint_mats[k]
	var src := _base_mat
	var m: Material
	if src is StandardMaterial3D:
		var sm := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.albedo_color = tint
		m = sm
	else:
		m = src
	_tint_mats[k] = m
	return m

func attach_weapon(weapon: String, bone := "RightHand") -> void:
	var idx := skel.find_bone(bone)
	if idx < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var w := Assets.instance(weapon)
	ba.add_child(w)
	# weapons are modelled in metres; the skeleton space is the ~1 unit tall raw model
	var s := 0.43
	match weapon:
		"w_axe": s = 0.46
		"w_club": s = 0.36
		"w_dagger": s = 0.55
	w.scale = Vector3.ONE * s
	w.rotation_degrees = WEAPON_ROT
	w.position = WEAPON_POS

const WEAPON_ROT := Vector3(-90, 0, 0)
const WEAPON_POS := Vector3(0.0, 0.04, 0.0)

func has(n: String) -> bool:
	return anim != null and anim.has_animation(n)

func play(n: String, speed := 1.0, blend := -1.0, restart := false) -> void:
	if anim == null:
		return
	if not anim.has_animation(n):
		if n == "idle" and anim.has_animation("run"):
			n = "run"
			speed *= 0.0001
		else:
			return
	if n == current and not restart:
		anim.speed_scale = speed
		return
	current = n
	_yaw_target = deg_to_rad(YAW_FIX.get(model_name, {}).get(n, 0.0))
	anim.speed_scale = speed
	anim.play(n, blend)
	if restart:
		anim.seek(0.0, true)

func anim_length(n: String) -> float:
	if anim and anim.has_animation(n):
		return anim.get_animation(n).length
	return 1.0

func hit_flash() -> void:
	if body == null:
		return
	flash = 0.12
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 1, 1, 0.55)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	body.material_overlay = _flash_mat

func _process(delta: float) -> void:
	if _inst and absf(_inst.rotation.y - _yaw_target) > 0.001:
		_inst.rotation.y = lerp_angle(_inst.rotation.y, _yaw_target, clampf(delta * 14.0, 0.0, 1.0))
	if flash > 0.0:
		flash -= delta / maxf(Engine.time_scale, 0.05)  # real time: no stuck white flash in slow motion
		if flash <= 0.0 and body:
			body.material_overlay = null
