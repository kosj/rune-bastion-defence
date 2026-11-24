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

func setup(p_type: String, p_path: LanePath, hp_mult: float) -> void:
	type = p_type
	d = DB.ENEMIES[type]
	path = p_path
	max_hp = d["hp"] * hp_mult
	hp = max_hp
	speed = d["speed"] * randf_range(0.95, 1.05)
	armor = d["armor"]
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
		"goblin": weapon = "w_dagger" if type == "goblin" else ""
		"skeleton_knight": weapon = "w_sword" if type == "skeleton_knight" else "w_dagger"
		"lich": weapon = ""
		"orc": weapon = "w_axe"
		"troll": weapon = "w_club"
	model = CharacterModel.new()
	model.ground_blob = not flying
	add_child(model)
	model.setup(d["model"], sc, d.get("tint", Color.WHITE), weapon)
	if type == "shaman":
		var staff := Assets.instance("crystal_staff")
		staff.scale = Vector3.ONE * 0.35
		staff.position = Vector3(0, height + 0.25, 0)
		add_child(staff)
	if d["model"] == "wolf" and model.anim == null:
		model.position.y = 0.42 * sc
		if model._blob:
			model._blob.position.y = 0.14 - model.position.y
	if flying:
		model.rotation_degrees.x = 8.0
	_anim_base = 1.0 / sc * 1.7
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
	if engaged and blocker != null and not flying:
		_fight(delta)
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
		model.rotation.x = sin(ph * 2.0) * 0.12
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

func _boss_slam() -> void:
	var p := global_position + Vector3(sin(_yaw), 0, cos(_yaw)) * 0.6 * float(d["scale"]) * 0.4
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
	lv.hud.show_banner("보스 격노!", "해골 기사 군단이 일어납니다" if undead else "고블린 증원이 몰려옵니다", Color(1.0, 0.35, 0.25))
	Audio.play("boss_roar", 3.0, 0.0)
	Game.vibrate(160)
	if model.has("roar"):
		model.play("roar", 1.4, 0.1, true)
		stun_t = 1.6
	var n := 3 if undead else 6
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
		a *= (1.0 - armor * (1.0 - pierce))
	elif dtype == "magic":
		a *= (1.0 - mr)
	hp -= a
	if flash and _hit_t <= 0.0:
		_hit_t = 0.08
		model.hit_flash()
	if hp <= 0.0:
		_die()

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
		_revive_t = 2.4
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
	if model.has("death"):
		model.play("death", 1.0, 0.1, true)
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
