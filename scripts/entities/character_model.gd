class_name CharacterModel
extends Node3D
## Wraps an imported VARCO character (skeleton + AnimationPlayer) with weapons, tint and helpers.

const LOOPING := ["idle", "run", "roar_loop"]
## Some VARCO motion clips (jog_looping) are authored facing sideways; correct per clip.
const YAW_FIX := {"hero": {"run": 90.0}, "footman": {"run": 90.0}, "goblin": {"run": 90.0}, "sapper": {"run": 90.0}, "sera": {"run": 90.0}, "ranger": {"run": 90.0}, "orc": {"attack": -90.0}, "ogre": {"roar": -90.0}}
const ATTACK_IMPACT := 0.62  # seconds into the trimmed attack clip

static var _prepared := {}
## Off for before/after review captures (test_runner noidlelife=1).
static var life_enabled := true
static var _tint_mats := {}
static var _blob_mesh: QuadMesh
static var _blob_mat: ShaderMaterial

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
var _blob := false  # wants a contact shadow in the shared BlobLayer (one draw call for all units)
var _blob_size := 1.0
## Height of the contact shadow above this node's origin (models lifted off their root put it lower).
var blob_y := 0.14
## Flying units (gargoyles) hover above the ground: no contact shadow under them.
var ground_blob := true
## Breathing / weight shift / looking around over the idle clip (heroes; see IdleLife).
var life: IdleLife

func setup(p_model: String, p_scale: float, tint := Color.WHITE, weapon := "") -> CharacterModel:
	model_name = p_model
	var life_amount := life.amount if is_instance_valid(life) else -1.0
	life = null  # it belongs to the previous skeleton
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
		# off-screen units skip skeletal animation (mixer, skeleton pose and skin upload are a large
		# share of each frame); they carry on from the same pose as soon as they are seen again
		var k := maxf(p_scale, 0.5)
		var en := VisibleOnScreenEnabler3D.new()
		en.aabb = AABB(Vector3(-0.9, -0.2, -0.9) * k, Vector3(1.8, 1.9, 1.8) * k)
		# the path must be set before it enters the tree: its default ("..") would switch this whole
		# model off on the first off-screen check
		en.enable_node_path = NodePath("../" + String(get_path_to(anim)))
		add_child(en)
	if body:
		_base_mat = body.mesh.surface_get_material(0)
		if tint != Color.WHITE:
			body.material_override = _tinted(p_model, tint)
	if weapon != "" and skel:
		# "w_axe+w_shield": a weapon in the right hand and a shield on the left forearm
		for w in weapon.split("+"):
			attach_weapon(w, "LeftForeArm" if w == "w_shield" else "RightHand")
	if life_amount > 0.0:
		add_idle_life(life_amount)
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
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if cheap else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var want := cheap and ground_blob
	if want != _blob:
		_blob = want
		if is_inside_tree():
			if want:
				BlobLayer.join(self)
			else:
				BlobLayer.leave(self)

func _enter_tree() -> void:
	if _blob:
		BlobLayer.join(self)

func _exit_tree() -> void:
	if _blob:
		BlobLayer.leave(self)

static func _blob_quad() -> QuadMesh:
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2(1, 1)
	return _blob_mesh

static func _blob_material() -> ShaderMaterial:
	if _blob_mat == null:
		# soft radial contact shadow worked out from the quad's own coordinates (0.8 -> 0.55 -> 0);
		# no texture, so it does not depend on UVs (MultiMesh instances of a QuadMesh lost them here)
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
varying vec2 lp;
void vertex() {
	lp = VERTEX.xy;
}
void fragment() {
	float d = length(lp) * 2.0;
	float a = d < 0.5 ? mix(0.8, 0.55, d / 0.5) : mix(0.55, 0.0, clamp((d - 0.5) / 0.5, 0.0, 1.0));
	ALBEDO = vec3(0.02, 0.02, 0.03);
	ALPHA = a;
}"""
		_blob_mat = ShaderMaterial.new()
		_blob_mat.shader = sh
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
		"p_arrow": s = 0.95  # the spear-thrower's javelin (the arrow model, stretched)
	w.scale = Vector3.ONE * s
	if weapon == "p_arrow":
		w.scale = Vector3(s, s * 1.3, s)
	w.rotation_degrees = WEAPON_ROT
	w.position = WEAPON_POS
	if weapon == "w_shield":
		w.scale = Vector3.ONE * 0.42
		w.rotation_degrees = SHIELD_ROT
		w.position = SHIELD_POS

const WEAPON_ROT := Vector3(-90, 0, 0)
const WEAPON_POS := Vector3(0.0, 0.04, 0.0)
## The shield rides the left forearm, face forward, centred halfway down it and clear of the arm.
const SHIELD_ROT := Vector3.ZERO
const SHIELD_POS := Vector3(0.0, 0.12, 0.05)

## Adds IdleLife to the skeleton (after the AnimationPlayer's pose).
func add_idle_life(amount := 1.0) -> void:
	if skel == null or life != null or not life_enabled:
		return
	life = IdleLife.new()
	life.amount = amount
	skel.add_child(life)
	life.set_idle(current == "idle")

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
	if life:
		life.set_idle(n == "idle")
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
