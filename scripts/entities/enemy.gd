class_name Enemy
extends Node3D
## Path-following enemy. Can be blocked by soldiers, slowed, burned, stunned.

var type := ""
var d: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 2.0
var armor := 0.0
var mr := 0.0
var path: LanePath
var dist := 0.0
var lane := 0.0
var flying := false
var boss := false
var alive := true
var blocker: Soldier = null
var engaged := false
var slow_mult := 1.0
var slow_t := 0.0
var burn_dps := 0.0
var burn_t := 0.0
var stun_t := 0.0
var model: CharacterModel
var radius := 0.45
var height := 1.6
var vel := Vector3.ZERO
var atk_cd := 0.5
var _heal_cd := 2.5
var _slam_cd := 5.0
var _anim_base := 1.0
var _bob := 0.0
var _hit_t := 0.0
var _attacking := 0.0
var _prev := Vector3.ZERO
var _yaw := 0.0
var _burn_fx := 0.0
var haste_t := 0.0
var haste_mult := 1.0
var _cry_cd := 4.0
var _fuse := -1.0
var _enraged := false
var _fuse_fx: Node3D
var poison_dps := 0.0
var poison_t := 0.0
var _poison_fx := 0.0
var _revived := false
var _revive_t := 0.0
var _summon_cd := 6.0
var _flinch := 0.0     # procedural recoil on hits (tilts the model back, decays fast)
var _react_cd := 0.0
# stealth (shadow rogue): towers other than mages cannot see it until something hurts it or a
# soldier holds it
var reveal_t := 0.0
var _ghost := 0.0
var _ghost_meshes: Array = []
var _ghost_mat: StandardMaterial3D
var _solid_mat: Material
# shield aura (orc shieldbearer): nearby enemies take less physical damage
var aura_t := 0.0
var aura_armor := 0.0
var _aura_cd := 0.0
var _aura_fx := 0.0
var _aura_ring: MeshInstance3D
# ranged (goblin spear-thrower): stops to throw javelins at soldiers in reach, three at a time
var _shot_cd := 0.0
var _throw_t := 0.0
var _shots := 0
var _move_on := 0.0
var _shot_tgt: Soldier
var _aim_yaw := 0.0
var _throwing := false
# shadow king: every 12 s slips into the shadows for 3 s (towers but mages lose him; hits do not
# bring him out)
var _vanish_cd := 7.0
var _vanish_t := 0.0
const GHOST := 0.68     # how see-through a hidden rogue is (0 solid, 1 invisible)

func setup(p_type: String, p_path: LanePath, hp_mult: float) -> void:
	type = p_type
	d = DB.ENEMIES[type]
	path = p_path
	max_hp = d["hp"] * hp_mult
	hp = max_hp
	speed = d["speed"] * randf_range(0.95, 1.05)
	armor = d["armor"]
	if LevelMain.I:
		speed *= LevelMain.I.enemy_speed_mult
		armor = minf(armor + LevelMain.I.enemy_armor_add, 0.9)
	mr = d["mr"]
	flying = d.get("flying", false)
	boss = d.get("boss", false)
	var sc: float = d["scale"]
	height = sc * 0.95
	radius = 0.18 * sc + 0.15
	lane = randf_range(-0.85, 0.85) if not boss else 0.0
	if flying:
		lane = randf_range(-1.6, 1.6)
	var weapon := ""
	match d["model"]:
		"goblin": weapon = "w_dagger" if type in ["goblin", "rogue"] else ("p_arrow" if type == "spear" else "")
		"shade": weapon = "w_dagger"
		"skeleton_knight": weapon = "w_sword" if type == "skeleton_knight" else "w_dagger"
		"lich": weapon = ""
		"orc": weapon = "w_axe+w_shield" if type == "shield" else "w_axe"
		"troll": weapon = "w_club"
	model = CharacterModel.new()
	model.ground_blob = not flying
	add_child(model)
	model.setup(d["model"], sc, d.get("tint", Color.WHITE), weapon)
	if type == "shaman":
		var staff := Assets.instance_glow("shaman_crystal", 1.3)
		staff.scale = Vector3.ONE * 0.42
		staff.position = Vector3(0, height + 0.25, 0)
		add_child(staff)
	if d.has("aura"):
		_aura_ring = LevelMain.I.fx.ground_ring(self, float(d.get("aura_r", 3.0)), Color(0.25, 0.5, 1.0, 0.65))
	if (d.get("stealth", false) or d.get("vanish", false)) and model.body:
		# its own copy of the (tinted) material with alpha, so each rogue fades on its own
		_solid_mat = model.body.material_override if model.body.material_override else model.body.mesh.surface_get_material(0)
		if _solid_mat is StandardMaterial3D:
			_ghost_mat = (_solid_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for g in model.find_children("*", "GeometryInstance3D", true, false):
			if g != model.body:
				_ghost_meshes.append(g)
		set_ghost(GHOST if d.get("stealth", false) else 0.0)
	if d["model"] == "wolf" and model.anim == null:
		model.position.y = 0.42 * sc
		model.blob_y = 0.14 - model.position.y
	if flying:
		model.rotation_degrees.x = 8.0
	# clip playback per metre travelled (gallops cover far more ground per cycle than a jog)
	_anim_base = float(d.get("anim_k", 1.0 / sc * 1.7))
	model.play("run", clampf(speed * _anim_base, 0.5, 2.6))
	_update_transform(0.0)
	_prev = global_position

func world_pos() -> Vector3:
	return global_position

func aim_point() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)

func progress() -> float:
	return dist

func _process(delta: float) -> void:
	if _revive_t > 0.0 and delta > 0.0:
		_revive_t -= delta
		if _revive_t <= 0.0:
			_rise()
		return
	if not alive:
		return
	if delta <= 0.0:
		return
	_hit_t = maxf(_hit_t - delta, 0.0)
	_react_cd -= delta
	if _flinch > 0.0:
		_flinch = maxf(_flinch - delta * 5.0, 0.0)
		if model.anim != null:
			model.rotation.x = (deg_to_rad(8.0) if flying else 0.0) - _flinch * 0.22
	# status effects
	if haste_t > 0.0:
		haste_t -= delta
		if haste_t <= 0.0:
			haste_mult = 1.0
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
			if model.body:
				model.body.material_overlay = null
	if burn_t > 0.0:
		burn_t -= delta
		damage(burn_dps * delta, "true", false)
		_burn_fx -= delta
		if _burn_fx <= 0.0:
			_burn_fx = 0.25
			LevelMain.I.fx.burn_puff(aim_point())
		if not alive:
			return
	if poison_t > 0.0:
		poison_t -= delta
		damage(poison_dps * delta, "true", false)
		_poison_fx -= delta
		if _poison_fx <= 0.0:
			_poison_fx = 0.35
			LevelMain.I.fx.hit_spark(aim_point(), Color(0.55, 1.0, 0.3), 0.5)
		if not alive:
			return
	_aura_fx -= delta
	if aura_t > 0.0:
		aura_t -= delta
		if aura_t <= 0.0:
			aura_armor = 0.0
	if d.has("aura"):
		_shield_aura(delta)
	if d.get("vanish", false):
		_vanish_t = maxf(_vanish_t - delta, 0.0)
		_vanish_cd -= delta
		if _vanish_cd <= 0.0:
			_vanish_cd = 12.0
			_vanish_t = 3.0
			LevelMain.I.fx.smoke(aim_point(), 1.6)
			LevelMain.I.fx.magic_burst(aim_point(), Color(0.45, 0.3, 0.8), 1.3)
			Audio.play("magic", -4.0, 0.1)
	if d.get("stealth", false) or d.get("vanish", false):
		reveal_t = maxf(reveal_t - delta, 0.0)
		if engaged:
			reveal_t = maxf(reveal_t, 0.4)
		var want := GHOST if hidden() else 0.0
		if absf(_ghost - want) > 0.001:
			if _ghost == GHOST or _ghost == 0.0:
				# a wisp of smoke as it slips in or out of the shadows
				LevelMain.I.fx.smoke(aim_point(), 0.7)
			set_ghost(move_toward(_ghost, want, delta * 2.5))
	if stun_t > 0.0:
		stun_t -= delta
		return
	# special abilities
	if type == "shaman":
		_heal_cd -= delta
		if _heal_cd <= 0.0:
			_heal_cd = 4.0
			_heal_allies()
	if d.get("slam", false):
		_slam_cd -= delta
	if d.get("warcry", false):
		_cry_cd -= delta
		if _cry_cd <= 0.0:
			_cry_cd = 9.0
			_warcry()
	if boss and not _enraged and hp < max_hp * 0.5 and d.has("enrage_summon"):
		_enrage()
		return
	if d.has("summon"):
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = float(d.get("summon_cd", 10.0)) * (0.75 if _enraged else 1.0)
			_raise_dead()
			return
	# blocked by a soldier?
	if blocker != null and (not is_instance_valid(blocker) or not blocker.alive or blocker.target != self):
		blocker = null
		engaged = false
	_throwing = false
	if engaged and blocker != null and not flying:
		_fight(delta)
	elif _ranged_update(delta):
		engaged = false
		_attacking = 0.0
		_throwing = true
	else:
		engaged = false
		_attacking = 0.0
		dist += speed * slow_mult * haste_mult * delta
		if model.current != "run":
			model.play("run", clampf(speed * slow_mult * haste_mult * _anim_base, 0.4, 2.6))
		if dist >= path.length:
			_reach_exit()
			return
	_update_transform(delta)
	if _throwing:
		_yaw = lerp_angle(_yaw, _aim_yaw, clampf(delta * 10.0, 0.0, 1.0))
		model.rotation.y = _yaw
	_procedural_anim(delta)
	vel = (global_position - _prev) / delta
	_prev = global_position

## Static (unrigged) models get a procedural gait: wolves bound, gargoyles flap.
func _procedural_anim(delta: float) -> void:
	if model.anim != null:
		return
	_bob += delta * (speed * slow_mult * 2.6 if not flying else 0.0)
	var sc: float = d["scale"]
	if d["model"] == "wolf":
		var ph := _bob * 1.0
		model.position.y = 0.42 * sc + absf(sin(ph)) * 0.22 * sc
		model.rotation.x = sin(ph * 2.0) * 0.12 - _flinch * 0.22
	elif flying:
		var f := sin(Time.get_ticks_msec() * 0.018 + lane * 3.0)
		model.scale = Vector3(1.0 + f * 0.14, 1.0 - f * 0.05, 1.0)

func _fight(delta: float) -> void:
	var bp := blocker.global_position
	var to := bp - global_position
	to.y = 0
	if to.length() > 0.05:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
		model.rotation.y = _yaw
	if d.has("explode"):
		if _fuse < 0.0:
			_fuse = 0.75
			model.play("attack", 1.6, 0.05, true)
			LevelMain.I.fx.charge(aim_point(), Color(1.0, 0.5, 0.2), 0.7)
			Audio.play("fuse", -4.0, 0.1)
		_fuse -= delta
		if _fuse <= 0.0:
			_explode()
		return
	atk_cd -= delta
	if atk_cd <= 0.0:
		var rate: float = d["atk_rate"]
		atk_cd = rate
		var spd := model.anim_length("attack") / maxf(rate * 0.9, 0.3)
		model.play("attack", maxf(spd, 0.8), 0.08, true)
		_attacking = CharacterModel.ATTACK_IMPACT / maxf(spd, 0.8)
		if model.anim != null and not model.has("attack"):
			# no bite clip (wolves): slow the gait and lunge at the target instead
			model.play("run", 0.35)
			var lunge := create_tween()
			lunge.tween_property(model, "position", Vector3(sin(_yaw), 0, cos(_yaw)) * 0.35, _attacking * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			lunge.tween_property(model, "position", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if d.get("slam", false) and _slam_cd <= 0.0:
			# telegraph: a red ring fills the blast zone during the wind-up
			LevelMain.I.fx.telegraph(_slam_point(), 4.0 if boss else 3.0, _attacking, Color(1.0, 0.25, 0.15))
	if _attacking > 0.0:
		_attacking -= delta
		if _attacking <= 0.0:
			if d.get("slam", false) and _slam_cd <= 0.0:
				_slam_cd = 6.0 if boss else 8.0
				_boss_slam()
			elif is_instance_valid(blocker) and blocker.alive:
				var dmg := randf_range(d["dmg"][0], d["dmg"][1]) * LevelMain.I.enemy_dmg_mult
				blocker.take_damage(dmg)
				Audio.play("clash", -6.0, 0.15, 3)
	elif model.current == "run":
		model.play("attack", 0.0001)

func _slam_point() -> Vector3:
	return global_position + Vector3(sin(_yaw), 0, cos(_yaw)) * 0.6 * float(d["scale"]) * 0.4

func _boss_slam() -> void:
	var p := _slam_point()
	var r := 4.0 if boss else 3.0
	LevelMain.I.fx.shockwave(p, r, Color(1.0, 0.8, 0.5))
	LevelMain.I.fx.dust(p, 2.0 if boss else 1.4)
	LevelMain.I.fx.scorch(p, r * 0.5)
	LevelMain.I.cam_rig.shake(0.9 if boss else 0.5)
	Audio.play("slam", 2.0 if boss else -1.0)
	for s: Soldier in LevelMain.I.soldiers.duplicate():
		if s.alive and s.global_position.distance_to(p) < r:
			s.take_damage(randf_range(d["dmg"][0], d["dmg"][1]))
			s.stun(1.6 if boss else 1.0)

## Sapper: blows up when a soldier blocks it, hurting every soldier nearby.
func _explode() -> void:
	var p := global_position
	LevelMain.I.fx.explosion(p + Vector3(0, 0.4, 0), 1.0)
	LevelMain.I.cam_rig.shake(0.35)
	Audio.play("boom", -2.0, 0.1, 2)
	for s: Soldier in LevelMain.I.soldiers.duplicate():
		if s.alive and s.global_position.distance_to(p) < 2.6:
			s.take_damage(float(d["explode"]))
	hp = 0.0
	_die()

## Warchief: roar that hastes nearby allies.
func _warcry() -> void:
	var any := false
	for e: Enemy in LevelMain.I.enemies:
		if e.alive and e != self and not e.boss and e.global_position.distance_to(global_position) < 5.0:
			e.haste_mult = 1.25
			e.haste_t = 3.5
			LevelMain.I.fx.hit_spark(e.aim_point(), Color(1.0, 0.35, 0.2), 0.8)
			any = true
	if any:
		LevelMain.I.fx.shockwave(global_position, 5.0, Color(1.0, 0.3, 0.2))
		LevelMain.I.fx.rune_circle(global_position + Vector3(0, 0.1, 0), Color(1.0, 0.3, 0.2), 3.0, 0.8)
		Audio.play("warcry", -2.0, 0.05)
		if model.has("roar") and not engaged:
			model.play("roar", 1.6, 0.1, true)
			stun_t = 0.6

## Boss: at half health becomes faster and calls goblin reinforcements.
func _enrage() -> void:
	_enraged = true
	speed *= 1.4
	_slam_cd = 0.0
	if model.body:
		model.body.material_override = null
	var lv := LevelMain.I
	lv.fx.fire_ring(global_position, 4.5)
	lv.fx.shockwave(global_position, 6.0, Color(1.0, 0.25, 0.1))
	lv.fx.light_flash(aim_point(), Color(1.0, 0.3, 0.1), 5.0, 10.0, 0.4)
	lv.cam_rig.shake(1.0)
	var kind: String = d.get("enrage_summon", "goblin")
	var undead := kind.begins_with("skeleton")
	var sub := "해골 기사 군단이 일어납니다" if undead else "고블린 증원이 몰려옵니다"
	lv.hud.show_banner("보스 격노!", String(d.get("enrage_text", sub)), Color(1.0, 0.35, 0.25))
	Audio.play("boss_roar", 3.0, 0.0)
	Game.vibrate(160)
	if model.has("cast"):
		model.play("cast", 2.2, 0.1, true)
		stun_t = 1.6
	elif model.has("roar"):
		model.play("roar", 1.4, 0.1, true)
		stun_t = 1.6
	var n := int(d.get("enrage_n", 3 if undead else 6))
	for i in n:
		lv.spawn_enemy_at(kind, path, maxf(dist - 2.5 - i * 1.4, 0.5))
	if undead:
		for i in 6:
			lv.spawn_enemy_at("skeleton", path, maxf(dist - 1.5 - i * 0.8, 0.5))

func _heal_allies() -> void:
	var healed := false
	for e: Enemy in LevelMain.I.enemies:
		if e != self and e.alive and e.hp < e.max_hp and e.global_position.distance_to(global_position) < 3.5:
			e.hp = minf(e.max_hp, e.hp + d["heal"])
			LevelMain.I.fx.heal(e.aim_point())
			healed = true
	if healed:
		LevelMain.I.fx.magic_burst(aim_point(), Color(0.6, 1.0, 0.5), 0.6)

func _update_transform(delta: float) -> void:
	var p2 := path.sample(dist)
	var t2 := path.tangent(dist)
	var side := Vector2(-t2.y, t2.x)
	var lane_eff := lane
	if engaged:
		lane_eff = lane * 0.5
	p2 += side * lane_eff
	var y := LevelMain.I.terrain.walk_height(p2.x, p2.y)
	if flying:
		_bob += delta * 3.0
		y = maxf(y, 0.0) + 2.8 + sin(_bob) * 0.25
		model.rotation.z = sin(_bob * 0.7) * 0.08
	position = Vector3(p2.x, y, p2.y)
	if not engaged:
		var target_yaw := atan2(t2.x, t2.y)
		_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 8.0, 0.0, 1.0)) if delta > 0.0 else target_yaw
		model.rotation.y = _yaw

func damage(amount: float, dtype: String, flash := true, pierce := 0.0) -> void:
	if not alive:
		return
	var a := amount
	if dtype == "physical":
		a *= (1.0 - minf(armor + aura_armor, 0.9) * (1.0 - pierce))
		if aura_armor > 0.0 and _aura_fx <= 0.0:
			_aura_fx = 0.4
			LevelMain.I.fx.hit_spark(aim_point(), Color(0.5, 0.7, 1.0), 0.7)
	elif dtype == "magic":
		a *= (1.0 - mr)
	hp -= a
	if a > 0.0 and d.get("stealth", false):
		reveal_t = maxf(reveal_t, 2.5)
	if flash and _hit_t <= 0.0:
		_hit_t = 0.08
		model.hit_flash()
	if hp <= 0.0:
		_die()
		return
	# hit feedback: everyone recoils a little; a blocked enemy between swings plays a real flinch
	var frac := a / maxf(max_hp, 1.0)
	if flash:
		_flinch = minf(_flinch + (0.25 + frac * 2.5) * (0.3 if boss else 1.0), 1.0)
	if engaged and not boss and _attacking <= 0.0 and _react_cd <= 0.0 and frac >= 0.07 and model.has("hit"):
		_react_cd = 1.4
		model.play("hit", 2.0, 0.05, true)

# ------------------------------------------------------------------ new kinds (v7)

## Stealth: can this enemy be seen by towers that cannot see through it (all but mages)?
func hidden() -> bool:
	if not alive:
		return false
	if _vanish_t > 0.0:
		return true
	return reveal_t <= 0.0 and d.get("stealth", false)

## Fades the model toward see-through (0 = solid, GHOST = hidden). Solid uses the normal
## material again (no alpha sorting); the weapon and shadow go while it is faded.
func set_ghost(a: float) -> void:
	_ghost = a
	if model.body == null or _ghost_mat == null:
		return
	if a <= 0.001:
		model.body.material_override = _solid_mat
		model.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		var c := _ghost_mat.albedo_color
		c.a = 1.0 - a
		_ghost_mat.albedo_color = c
		model.body.material_override = _ghost_mat
		model.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for g in _ghost_meshes:
		if is_instance_valid(g):
			(g as Node3D).visible = a < 0.3

## Shieldbearer: every quarter second, shields the enemies around it (not itself) for a moment.
func _shield_aura(delta: float) -> void:
	if _aura_ring:
		var k := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.04
		_aura_ring.scale = Vector3(k, 1.0, k) * float(d.get("aura_r", 3.0)) * 2.0
	_aura_cd -= delta
	if _aura_cd > 0.0:
		return
	_aura_cd = 0.25
	var r: float = d.get("aura_r", 3.0)
	for o: Enemy in LevelMain.I.enemies:
		if o != self and o.alive and o.global_position.distance_to(global_position) < r:
			o.aura_t = 0.4
			o.aura_armor = maxf(o.aura_armor, float(d["aura"]))

## Spear-thrower: true while it stands and throws (the caller then does not walk it on).
func _ranged_update(delta: float) -> bool:
	if not d.has("ranged") or flying:
		return false
	var rd: Dictionary = d["ranged"]
	_shot_cd -= delta
	if _throw_t > 0.0:
		_throw_t -= delta
		if _throw_t <= 0.0:
			_throw_javelin(rd)
		return true
	if _move_on > 0.0:
		_move_on -= delta
		return false
	var tgt := _ranged_target(float(rd["range"]))
	if tgt == null:
		return false
	var to := tgt.global_position - global_position
	_aim_yaw = atan2(to.x, to.z)
	if _shot_cd <= 0.0:
		_shot_cd = float(rd["rate"])
		_shot_tgt = tgt
		model.play("attack", 1.3, 0.06, true)
		_throw_t = CharacterModel.ATTACK_IMPACT / 1.3
	elif model.current == "run":
		model.play("attack", 0.0001)
	return true

func _ranged_target(r: float) -> Soldier:
	var best: Soldier = null
	var bd := r
	for s: Soldier in LevelMain.I.soldiers:
		if not is_instance_valid(s) or not s.alive:
			continue
		var dd := Vector2(s.global_position.x - global_position.x, s.global_position.z - global_position.z).length()
		if dd < bd:
			bd = dd
			best = s
	return best

## One javelin on an arc at the soldier picked at wind-up; after the third it walks on a while.
func _throw_javelin(rd: Dictionary) -> void:
	_shots += 1
	if _shots >= 3:
		_shots = 0
		_move_on = 2.5
	var s := _shot_tgt
	if s == null or not is_instance_valid(s) or not s.alive:
		return
	var lv := LevelMain.I
	var from := aim_point() + Vector3(0, 0.3, 0)
	var to := s.aim_point()
	var jv := Assets.instance("p_arrow")
	jv.scale = Vector3(1.4, 1.9, 1.4)
	lv.world.add_child(jv)
	jv.global_position = from
	var dist := from.distance_to(to)
	var dur := clampf(dist / 12.0, 0.25, 0.6)
	var h := dist * 0.18
	var dmg_v := randf_range(rd["dmg"][0], rd["dmg"][1]) * lv.enemy_dmg_mult
	var fly := func(t: float) -> void:
		var p := from.lerp(to, t) + Vector3(0, sin(t * PI) * h, 0)
		var t2 := minf(t + 0.05, 1.0)
		var nxt := from.lerp(to, t2) + Vector3(0, sin(t2 * PI) * h, 0)
		jv.global_position = p
		var dv := nxt - p
		if dv.length() > 0.001 and absf(dv.normalized().y) < 0.98:
			jv.look_at(nxt, Vector3.UP)
			jv.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	var land := func() -> void:
		if is_instance_valid(s) and s.alive:
			s.take_damage(dmg_v)
			lv.fx.hit_spark(s.aim_point(), Color(1.0, 0.8, 0.5), 0.6)
		jv.queue_free()
	var tw := jv.create_tween()
	tw.tween_method(fly, 0.0, 1.0, dur)
	tw.tween_callback(land)
	Audio.play("bow", -12.0, 0.15, 2)

func slow(mult: float, t: float) -> void:
	if boss:
		mult = lerpf(mult, 1.0, 0.5)
	slow_mult = minf(slow_mult, mult)
	slow_t = maxf(slow_t, t)
	if model.body:
		model.body.material_overlay = LevelMain.I.fx.frost_overlay()

func burn(dps: float, t: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_t = maxf(burn_t, t)

func stun(t: float) -> void:
	if boss:
		return
	stun_t = maxf(stun_t, t)

func poison(dps: float, t: float) -> void:
	poison_dps = maxf(poison_dps, dps)
	poison_t = maxf(poison_t, t)

## Frozen solid: a stun with an icy look (bosses shrug it off).
func freeze(t: float) -> void:
	if boss:
		return
	stun(t)
	slow(0.5, t + 1.0)
	LevelMain.I.fx.frost_nova(global_position, 0.9)

## Lich: raise skeletons around itself.
func _raise_dead() -> void:
	var lv := LevelMain.I
	var n := int(d.get("summon_n", 3)) + (2 if _enraged else 0)
	if model.has("roar"):
		model.play("roar", 1.5, 0.1, true)
	stun_t = 1.1
	lv.fx.rune_circle(global_position + Vector3(0, 0.1, 0), Color(0.5, 1.0, 0.45), 3.4, 1.0)
	lv.fx.light_flash(aim_point(), Color(0.45, 1.0, 0.4), 3.0, 8.0, 0.35)
	Audio.play("warcry", -4.0, 0.05)
	for i in n:
		lv.spawn_enemy_at(String(d.get("summon", "skeleton")), path, clampf(dist - 1.0 - i * 0.9, 0.5, path.length - 1.0))

## Skeleton knight: collapses once, then pulls itself back together.
func _rise() -> void:
	alive = true
	hp = max_hp * float(d.get("revive", 0.5))
	_revived = true
	stun_t = 0.0
	slow_t = 0.0
	burn_t = 0.0
	poison_t = 0.0
	slow_mult = 1.0
	position.y = LevelMain.I.terrain.walk_height(position.x, position.z)
	LevelMain.I.fx.rune_circle(global_position + Vector3(0, 0.1, 0), Color(0.5, 1.0, 0.45), 1.4, 0.7)
	LevelMain.I.fx.soul(aim_point(), Color(0.5, 1.0, 0.45))
	if model.has("rise"):
		# drags itself up off the ground before marching on
		model.play("rise", 3.0, 0.12, true)
		stun_t = model.anim_length("rise") / 3.0 * 0.85
	else:
		model.play("run", clampf(speed * _anim_base, 0.5, 2.6), 0.2, true)

func _die() -> void:
	alive = false
	hp = 0.0
	if blocker and is_instance_valid(blocker):
		blocker.target_lost(self)
	blocker = null
	engaged = false
	if d.has("revive") and not _revived:
		# down, not out: stays on the enemy list (the wave is not cleared) and rises again
		_revive_t = 1.2 if model.has("rise") else 2.4
		if model.body:
			model.body.material_overlay = null
		if model.has("death"):
			model.play("death", 1.2, 0.1, true)
		LevelMain.I.fx.soul(aim_point(), Color(0.6, 0.9, 0.6))
		Audio.play("die_small", -6.0, 0.12)
		LevelMain.I.overlay.float_text(aim_point() + Vector3(0, 0.8, 0), "다시 일어납니다!", Color(0.6, 1.0, 0.55), 1.0)
		return
	LevelMain.I.on_enemy_killed(self)
	var fx := LevelMain.I.fx
	fx.soul(aim_point(), Color(1.0, 0.6, 0.4) if boss else Color(0.75, 0.7, 1.0))
	fx.coin_burst(aim_point(), clampi(int(d["gold"]) / 6, 1, 8))
	if model.body:
		model.body.material_overlay = null
	model.rotation.x = deg_to_rad(8.0) if flying else 0.0
	if model.has("death"):
		var clip := "death2" if model.has("death2") and randf() < 0.5 else "death"
		model.play(clip, 1.0 if clip == "death" else 1.5, 0.1, true)
	Audio.play("die_" + ("big" if boss or type == "warchief" or type == "orc" else "small"), -4.0, 0.12)
	var tw := create_tween()
	if flying:
		tw.tween_property(self, "position:y", LevelMain.I.terrain.height_at(position.x, position.z), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): LevelMain.I.fx.dust(global_position, 0.6))
	elif not model.has("death"):
		tw.tween_property(model, "rotation:z", PI * 0.5, 0.4)
	tw.tween_interval(1.6 if not boss else 4.0)
	tw.tween_property(self, "position:y", -0.6 * (d["scale"] as float), 1.0).as_relative()
	tw.tween_callback(queue_free)

func _reach_exit() -> void:
	alive = false
	LevelMain.I.on_enemy_exit(self)
	queue_free()
