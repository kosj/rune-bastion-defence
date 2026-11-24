class_name Soldier
extends Node3D
## Melee defender (barracks soldier / reinforcement / hero base). Blocks enemies on the path.

signal died(s: Soldier)

var hp := 50.0
var max_hp := 50.0
var dmg := [2.0, 4.0]
var armor := 0.0
var atk_rate := 1.0
var move_speed := 3.4
var regen := 4.0
var heal_ps := 0.0
var rally := Vector3.ZERO
var slot := Vector3.ZERO
var engage_radius := 2.9
var target: Enemy = null
var alive := true
var lifetime := -1.0
var model: CharacterModel
var is_hero := false
var height := 1.7
var stun_t := 0.0
var _atk_cd := 0.0
var _impact := 0.0
var _idle_t := 0.0
var _yaw := 0.0
var _search_cd := 0.0
var holy := 0.0       # paladin ability: extra magic damage share per hit
var javelin := false  # lancer ability: ranged spear throws
var _jav_cd := 1.0

func setup_unit(model_name: String, scale: float, tint := Color.WHITE, weapon := "") -> void:
	model = CharacterModel.new()
	add_child(model)
	model.setup(model_name, scale, tint, weapon)
	height = scale * 0.95
	model.play("idle")

func set_stats(p_hp: float, p_dmg: Array, p_armor: float, p_rate := 1.0) -> void:
	var ratio := hp / max_hp if max_hp > 0 else 1.0
	max_hp = p_hp
	hp = p_hp * ratio if alive else p_hp
	dmg = p_dmg
	armor = p_armor
	atk_rate = p_rate

func aim_point() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)

func _process(delta: float) -> void:
	if not alive or delta <= 0.0:
		return
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			_expire()
			return
	if stun_t > 0.0:
		stun_t -= delta
		return
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
	if javelin:
		_jav_cd -= delta
		if _jav_cd <= 0.0:
			_jav_cd = 0.4
			_throw_javelin()
	if heal_ps > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + heal_ps * delta)
	if target == null:
		_search_cd -= delta
		if _search_cd <= 0.0:
			_search_cd = 0.2
			_find_target()
	if target != null:
		_engage(delta)
	else:
		_go_home(delta)

func _anchor() -> Vector3:
	return rally

func _find_target() -> void:
	var best: Enemy = null
	var best_score := 1e9
	var anchor := _anchor()
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive or e.flying:
			continue
		var dd := e.global_position.distance_to(anchor)
		if dd > engage_radius:
			continue
		var score := dd
		if e.blocker != null and is_instance_valid(e.blocker) and e.blocker != self:
			score += 6.0  # prefer unblocked enemies
		if score < best_score:
			best_score = score
			best = e
	if best != null:
		target = best
		if best.blocker == null or not is_instance_valid(best.blocker) or not best.blocker.alive:
			best.blocker = self

func target_lost(e: Enemy) -> void:
	if target == e:
		target = null

func _engage(delta: float) -> void:
	var tp := target.global_position
	var to := tp - global_position
	to.y = 0.0
	var reach := target.radius + 0.55
	if to.length() > reach:
		if (tp - _anchor()).length() > engage_radius + 1.5 and not is_hero:
			_release()
			return
		_move_towards(tp - to.normalized() * reach * 0.9, delta)
	else:
		if target.blocker == self:
			target.engaged = true
		_face(to, delta)
		_atk_cd -= delta
		if _atk_cd <= 0.0:
			_atk_cd = atk_rate
			var spd := maxf(model.anim_length("attack") / maxf(atk_rate * 0.85, 0.3), 0.9)
			model.play("attack", spd, 0.06, true)
			_impact = CharacterModel.ATTACK_IMPACT / spd
		if _impact > 0.0:
			_impact -= delta
			if _impact <= 0.0 and is_instance_valid(target) and target.alive:
				_on_hit(target)
		elif model.current != "attack":
			model.play("idle")

func _on_hit(e: Enemy) -> void:
	var v := randf_range(dmg[0], dmg[1])
	e.damage(v, "physical")
	if holy > 0.0 and e.alive:
		e.damage(v * holy, "magic", false)
		Tower.count_ability("holy")
		LevelMain.I.fx.hit_spark(e.aim_point(), Color(1.0, 0.95, 0.55), 0.9)
	LevelMain.I.fx.hit_spark(e.aim_point(), Color(1.0, 0.9, 0.6))
	Audio.play("sword", -8.0, 0.15, 3)

## Lancer ability: hurl a spear at the nearest enemy in reach (air included) every 3 s.
func _throw_javelin() -> void:
	var best: Enemy = null
	var bd := 6.0
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive or e == target:
			continue
		var dd := e.global_position.distance_to(global_position)
		if dd < bd:
			bd = dd
			best = e
	if best == null:
		return
	_jav_cd = 3.0
	Tower.count_ability("javelin")
	Projectile.arrow(aim_point() + Vector3(0, 0.4, 0), best, randf_range(18.0, 28.0), false, 0.0, "javelin")
	Audio.play("bow", -9.0, 0.15, 2)

func _release() -> void:
	if target and is_instance_valid(target) and target.blocker == self:
		target.blocker = null
		target.engaged = false
	target = null

func _go_home(delta: float) -> void:
	var dest := rally + slot
	var to := dest - global_position
	to.y = 0
	if to.length() > 0.25:
		_move_towards(dest, delta)
	else:
		if model.current != "idle":
			model.play("idle")
		if hp < max_hp:
			hp = minf(max_hp, hp + regen * delta)

func _move_towards(dest: Vector3, delta: float) -> void:
	var to := dest - global_position
	to.y = 0
	var dl := to.length()
	if dl < 0.01:
		return
	var step := minf(dl, move_speed * delta)
	var p := global_position + to / dl * step
	p.y = LevelMain.I.terrain.walk_height(p.x, p.z)
	global_position = p
	_face(to, delta)
	if model.current != "run":
		model.play("run", clampf(move_speed / 2.4, 0.8, 2.0))

func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	_yaw = lerp_angle(_yaw, atan2(dir.x, dir.z), clampf(delta * 12.0, 0.0, 1.0))
	model.rotation.y = _yaw

func take_damage(a: float) -> void:
	if not alive:
		return
	hp -= a * (1.0 - armor)
	model.hit_flash()
	if hp <= 0.0:
		die()

func stun(t: float) -> void:
	stun_t = maxf(stun_t, t)
	LevelMain.I.fx.stun_stars(self)

func die() -> void:
	if not alive:
		return
	alive = false
	_release()
	LevelMain.I.soldiers.erase(self)
	model.play("death", 1.0, 0.1, true)
	Audio.play("die_small", -8.0)
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.4)
	tw.tween_callback(_after_death)

var persistent := false

func _after_death() -> void:
	if persistent:
		visible = false
	else:
		queue_free()

func _expire() -> void:
	alive = false
	_release()
	LevelMain.I.soldiers.erase(self)
	LevelMain.I.fx.magic_burst(aim_point(), Color(0.7, 0.85, 1.0), 0.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
	tw.tween_callback(queue_free)

func revive_at(p: Vector3) -> void:
	alive = true
	visible = true
	hp = max_hp
	scale = Vector3.ONE
	global_position = p
	target = null
	model.play("idle", 1.0, 0.0, true)
	if not LevelMain.I.soldiers.has(self):
		LevelMain.I.soldiers.append(self)
