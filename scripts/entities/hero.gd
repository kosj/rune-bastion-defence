class_name Hero
extends Soldier
## Player-controlled hero: tap to move, auto-fights, levels up, respawns. Two skills: the first from
## the start, the second from battle level DB.SKILL2_LEVEL (Kael: flame charge, Sera: star ward,
## Ren: piercing arrow). Both cast themselves when worth it and from the HUD buttons.

signal leveled(lv: int)

var level := 1
var xp := 0.0
var skill_cd := 0.0
var respawn_t := 0.0
var spawn_point := Vector3.ZERO
var commanded := false
var _skill_t := 0.0
var _base_hp := 0.0
var _base_dmg := []
var _sel_ring: MeshInstance3D
var hid := "kael"
var ranged := false
var shoot_range := 0.0
var _skill_at := Vector3.ZERO
var skill2_cd := 0.0
var _cast := 1               # which skill the wind-up in _skill_t belongs to
var _dash_from := Vector3.ZERO
var _dash_to := Vector3.ZERO
var _pierce_dir := Vector3.FORWARD
var _ward_t := 0.0
var _ward_at := Vector3.ZERO
var _ward_tick := 0.0
const WARD_COL := Color(0.75, 0.6, 1.0)
const PIERCE_COL := Color(1.0, 0.85, 0.4)

func setup_hero(p: Vector3) -> void:
	is_hero = true
	persistent = true
	spawn_point = p
	var h: Dictionary = DB.hero_def()
	hid = Game.hero_id if DB.HEROES.has(Game.hero_id) and h == DB.HEROES[Game.hero_id] else "kael"
	ranged = h.get("ranged", false)
	shoot_range = float(h.get("range", 0.0))
	setup_unit(h["model"], h["scale"], Color.WHITE, h["weapon"])
	model.add_idle_life()
	# star upgrade + persistent talents (rank points spent in the hero screen)
	_base_hp = float(h["hp"]) * (1.2 if DB.up("hero") else 1.0) * DB.talent_mult(hid, "hp")
	var dm := DB.talent_mult(hid, "dmg")
	_base_dmg = [float(h["dmg"][0]) * dm, float(h["dmg"][1]) * dm]
	set_stats(_base_hp, _base_dmg.duplicate(), h["armor"], h["atk_rate"])
	hp = max_hp
	move_speed = h["speed"]
	regen = h["regen"]
	engage_radius = 3.4 if not ranged else shoot_range
	rally = p
	global_position = p
	_sel_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.9
	tm.rings = 24
	tm.ring_segments = 6
	_sel_ring.mesh = tm
	_sel_ring.scale = Vector3(1, 0.05, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.25, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sel_ring.material_override = m
	_sel_ring.position.y = 0.06
	_sel_ring.visible = false
	add_child(_sel_ring)

func skill_cd_max() -> float:
	return float(DB.hero_def()["skill_cd"]) * (2.0 - DB.talent_mult(hid, "cd"))

func skill_radius() -> float:
	return float(DB.hero_def()["skill_radius"]) * (1.0 + 0.05 * DB.talent(hid, "skill"))

func skill_damage() -> float:
	return float(DB.hero_def()["skill_dmg"]) * (1.0 + (level - 1) * 0.2) * DB.talent_mult(hid, "skill")

func skill2_def() -> Dictionary:
	return DB.hero_def()["skill2"]

func skill2_open() -> bool:
	return level >= DB.SKILL2_LEVEL

func skill2_cd_max() -> float:
	return float(skill2_def()["cd"]) * (2.0 - DB.talent_mult(hid, "cd"))

func skill2_damage() -> float:
	return float(skill2_def()["dmg"]) * (1.0 + (level - 1) * 0.2) * DB.talent_mult(hid, "skill")

func set_selected(v: bool) -> void:
	_sel_ring.visible = v

func _anchor() -> Vector3:
	return global_position if not commanded else rally

func move_to(p: Vector3) -> void:
	if not alive:
		return
	_release()
	rally = p
	slot = Vector3.ZERO
	commanded = true
	LevelMain.I.fx.move_marker(p)
	Audio.play("hero_move", -4.0, 0.05)
	Audio.voice(hid + "_move")

func _process(delta: float) -> void:
	if delta <= 0.0 or celebrating:
		return
	skill_cd = maxf(skill_cd - delta, 0.0)
	skill2_cd = maxf(skill2_cd - delta, 0.0)
	if _ward_t > 0.0:
		_ward_update(delta)
	if not alive:
		respawn_t -= delta
		if respawn_t <= 0.0:
			revive_at(spawn_point)
			rally = spawn_point
			commanded = false
			LevelMain.I.fx.magic_burst(aim_point(), Color(1.0, 0.7, 0.3) if not ranged else Color(0.5, 0.85, 1.0), 1.2)
			Audio.play("levelup", -6.0)
			Audio.voice(hid + "_respawn")
		return
	if _skill_t > 0.0:
		_skill_t -= delta
		if _skill_t <= 0.0:
			if _cast == 2:
				_skill2_impact()
			else:
				_skill_impact()
		return
	if commanded:
		var to := rally - global_position
		to.y = 0
		if to.length() > 0.3:
			_move_towards(rally, delta)
			hp = minf(max_hp, hp + regen * 0.5 * delta)
			return
		commanded = false
	# auto-cast skill when crowded
	if skill_cd <= 0.0 and stun_t <= 0.0:
		if ranged:
			var c := _best_cluster()
			if c[1] >= 4 or (c[1] >= 1 and target != null and target.boss):
				cast_skill()
				return
		else:
			var n := 0
			for e: Enemy in LevelMain.I.enemies:
				if e.alive and not e.flying and e.global_position.distance_to(global_position) < skill_radius():
					n += 1
			if n >= 3 or (n >= 1 and target != null and target.boss):
				cast_skill()
				return
	if skill2_open() and skill2_cd <= 0.0 and stun_t <= 0.0 and _want_skill2():
		cast_skill2()
		return
	super._process(delta)

## Ranged hero: densest enemy group within reach -> [center, count].
func _best_cluster() -> Array:
	var r: float = skill_radius()
	var best := Vector3.ZERO
	var bn := 0
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive or e.global_position.distance_to(global_position) > shoot_range + 2.0:
			continue
		var n := 0
		for o: Enemy in LevelMain.I.enemies:
			if o.alive and o.global_position.distance_to(e.global_position) < r * 0.8:
				n += 1
		if e.boss:
			n += 4
		if n > bn:
			bn = n
			best = e.global_position
	return [best, bn]

func _find_target() -> void:
	if not ranged:
		super._find_target()
		return
	var best: Enemy = null
	var best_score := -1e9
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive:
			continue
		var dd := e.global_position.distance_to(global_position)
		if dd > shoot_range:
			continue
		var score := e.dist / e.path.length - dd * 0.01
		if score > best_score:
			best_score = score
			best = e
	target = best

func _engage(delta: float) -> void:
	if not ranged:
		super._engage(delta)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > shoot_range + 0.5:
		target = null
		return
	_face(to, delta)
	_atk_cd -= delta
	if _atk_cd <= 0.0:
		_atk_cd = atk_rate
		var spd := maxf(model.anim_length("attack") / maxf(atk_rate * 0.8, 0.3), 1.0)
		model.play("attack", spd, 0.06, true)
		_impact = CharacterModel.ATTACK_IMPACT / spd
		if not _archer():
			LevelMain.I.fx.charge(aim_point() + Vector3(0, 0.3, 0), Color(0.5, 0.85, 1.0), _impact)
	if _impact > 0.0:
		_impact -= delta
		if _impact <= 0.0 and is_instance_valid(target) and target.alive:
			var from := aim_point() + Vector3(0, 0.35, 0) + to.normalized() * 0.5
			if _archer():
				Projectile.arrow(from, target, randf_range(dmg[0], dmg[1]), false, float(DB.hero_def().get("pierce", 0.0)))
				Audio.play("bow", -9.0, 0.1, 2)
			else:
				Projectile.bolt(from, target, randf_range(dmg[0], dmg[1]), Color(0.5, 0.85, 1.0), 0.0, 0.0)
				LevelMain.I.fx.magic_burst(from, Color(0.5, 0.85, 1.0), 0.45)
				Audio.play("magic", -8.0, 0.12)
	elif model.current != "attack" and _react_t <= 0.0:
		model.play("idle")

func cast_skill() -> bool:
	if not alive or skill_cd > 0.0 or _skill_t > 0.0:
		return false
	skill_cd = skill_cd_max()
	_cast = 1
	Audio.voice(hid + "_skill")
	if ranged:
		var c := _best_cluster()
		_skill_at = c[0] if c[1] > 0 else global_position + Vector3(0, 0, 3)
		var to := _skill_at - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_yaw = atan2(to.x, to.z)
			rotation.y = _yaw
		if _archer():
			# the clip is a long volley loop: play its opening draw fast, then the arrows fall
			model.play("skill", 2.6, 0.08, true)
			_skill_t = 0.7
			LevelMain.I.fx.telegraph(_skill_at, skill_radius(), 0.7 + 0.5, Color(1.0, 0.85, 0.35))
			Audio.play("bow", -2.0, 0.05, 2)
			return true
		model.play("skill", 1.4, 0.08, true)
		_skill_t = 0.85
		LevelMain.I.fx.rune_circle(_skill_at + Vector3(0, 0.08, 0), Color(0.5, 0.85, 1.0), skill_radius(), 0.9)
		LevelMain.I.fx.charge(aim_point() + Vector3(0, 0.6, 0), Color(0.6, 0.9, 1.0), 0.8)
		Audio.play("frost", -2.0)
		return true
	model.play("skill", 1.6, 0.08, true)
	_skill_t = 0.75
	Audio.play("whirl", -2.0)
	return true

func _archer() -> bool:
	return DB.hero_def().get("projectile", "") == "arrow"

func _skill_impact() -> void:
	if ranged and _archer():
		_arrow_rain()
		return
	if ranged:
		_star_storm()
		return
	var r: float = skill_radius()
	var dmg_v: float = skill_damage()
	LevelMain.I.fx.fire_ring(global_position, r)
	LevelMain.I.cam_rig.shake(0.35)
	for e: Enemy in LevelMain.I.enemies.duplicate():
		if e.alive and not e.flying and e.global_position.distance_to(global_position) < r:
			e.damage(dmg_v, "physical")
			e.burn(8.0, 3.0)
	model.play("idle")

## Sera: a rain of starlight on the chosen spot — heavy magic damage and a slow.
func _star_storm() -> void:
	var h: Dictionary = DB.hero_def()
	var r: float = skill_radius()
	var dmg_v: float = skill_damage()
	var fx := LevelMain.I.fx
	for i in 7:
		var off := Vector3(randf_range(-r, r) * 0.6, 0, randf_range(-r, r) * 0.6)
		fx.lightning(_skill_at + off + Vector3(0, 9, 0), _skill_at + off, Color(0.6, 0.9, 1.0))
	fx.frost_nova(_skill_at, r)
	fx.magic_burst(_skill_at + Vector3(0, 0.6, 0), Color(0.6, 0.9, 1.0), 1.6)
	fx.light_flash(_skill_at + Vector3(0, 1.5, 0), Color(0.6, 0.85, 1.0), 4.0, 9.0, 0.3)
	LevelMain.I.cam_rig.shake(0.4)
	Audio.play("zap", -1.0, 0.1)
	for e: Enemy in LevelMain.I.enemies.duplicate():
		if e.alive and e.global_position.distance_to(_skill_at) < r:
			e.damage(dmg_v, "magic")
			e.slow(float(h["skill_slow"]), 3.0)
	model.play("idle")

## Ren: sixteen arrows fall over the chosen spot; each splashes a little and pins (slows) what it hits.
func _arrow_rain() -> void:
	var h: Dictionary = DB.hero_def()
	var r: float = skill_radius()
	var per: float = skill_damage() * 0.4
	var slow_k: float = float(h.get("skill_slow", 0.65))
	var at := _skill_at
	var lv := LevelMain.I
	for i in 16:
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		var land := at + Vector3(cos(a) * d, 0, sin(a) * d)
		land.y = lv.terrain.walk_height(land.x, land.z)
		var start := land + Vector3(randf_range(-1.5, 1.5), 8.0, randf_range(-1.5, 1.5))
		var arr := Assets.instance("p_arrow")
		arr.scale = Vector3.ONE * 1.3
		lv.world.add_child(arr)
		arr.global_position = start
		arr.look_at(land, Vector3.RIGHT)
		arr.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		arr.visible = false
		var tw := arr.create_tween()
		tw.tween_interval(i * 0.055)
		tw.tween_callback(func(): arr.visible = true)
		tw.tween_property(arr, "global_position", land + Vector3(0, 0.25, 0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			lv.fx.hit_spark(land + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.45), 0.7)
			if i % 4 == 0:
				lv.fx.dust(land, 0.5)
				Audio.play("bow", -12.0, 0.15, 2)
			for e: Enemy in lv.enemies.duplicate():
				if e.alive and e.global_position.distance_to(land) < 1.25:
					e.damage(per, "physical", true, 0.4)
					if e.alive:
						e.slow(slow_k, 1.8))
		tw.tween_interval(0.6)
		tw.tween_callback(arr.queue_free)
	lv.cam_rig.shake(0.25)
	model.play("idle")

# ------------------------------------------------------------------ second skill

## Worth casting on its own? (The button casts it whenever there is something to hit.)
func _want_skill2() -> bool:
	match skill2_def()["id"]:
		"charge":
			var c := _charge_target()
			# a group to rush into, not the one already at his sword
			return (int(c[1]) >= 3 or (int(c[1]) >= 1 and bool(c[2]))) and float(c[3]) > 2.5
		"ward":
			var c := _best_cluster()
			return int(c[1]) >= 5
		"pierce":
			var ln := _pierce_line()
			return int(ln[1]) >= 3 or (int(ln[1]) >= 1 and bool(ln[2]))
	return false

## Kael: the best group to rush -> [centre, count, has boss, distance].
func _charge_target() -> Array:
	var reach: float = float(skill2_def()["reach"])
	var best := Vector3.ZERO
	var bn := 0
	var boss_in := false
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive or e.flying or e.global_position.distance_to(global_position) > reach:
			continue
		var n := 0
		for o: Enemy in LevelMain.I.enemies:
			if o.alive and not o.flying and o.global_position.distance_to(e.global_position) < 1.8:
				n += 1
		var score := n + (4 if e.boss else 0)
		if score > bn + (4 if boss_in else 0):
			bn = n
			boss_in = e.boss
			best = e.global_position
	return [best, bn, boss_in, best.distance_to(global_position) if bn > 0 else 0.0]

## Ren: the line through the most enemies -> [direction, count, has boss].
func _pierce_line() -> Array:
	var length: float = float(skill2_def()["length"])
	var best_dir := Vector3.ZERO
	var bn := 0
	var boss_in := false
	var from := global_position
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive or e.global_position.distance_to(from) > shoot_range + 2.0:
			continue
		var dir := e.global_position - from
		dir.y = 0.0
		if dir.length() < 0.3:
			continue
		dir = dir.normalized()
		var n := 0
		var has_boss := false
		for o: Enemy in LevelMain.I.enemies:
			if not o.alive:
				continue
			var rel := o.global_position - from
			rel.y = 0.0
			var t := rel.dot(dir)
			if t > 0.0 and t < length and (rel - dir * t).length() < 0.9:
				n += 1
				has_boss = has_boss or o.boss
		if n + (3 if has_boss else 0) > bn + (3 if boss_in else 0):
			bn = n
			boss_in = has_boss
			best_dir = dir
	return [best_dir, bn, boss_in]

func _face_to(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() > 0.1:
		_yaw = atan2(to.x, to.z)
		rotation.y = _yaw

func cast_skill2() -> bool:
	if not alive or not skill2_open() or skill2_cd > 0.0 or _skill_t > 0.0 or stun_t > 0.0:
		return false
	var d := skill2_def()
	var fx := LevelMain.I.fx
	match d["id"]:
		"charge":
			var c := _charge_target()
			if int(c[1]) == 0:
				return false
			var to: Vector3 = c[0] - global_position
			to.y = 0.0
			var dir := to.normalized() if to.length() > 0.1 else Vector3(sin(_yaw), 0, cos(_yaw))
			# straight through the front of the group
			var end := global_position + dir * clampf(to.length() + 0.6, 1.5, float(d["reach"]))
			_dash_from = global_position
			_dash_to = Vector3(end.x, LevelMain.I.terrain.walk_height(end.x, end.z), end.z)
			_face_to(_dash_to)
			_release()
			model.play("run", 2.6, 0.05, true)
			fx.charge(aim_point(), Color(1.0, 0.6, 0.2), 0.15)
			var tw := create_tween()
			tw.tween_interval(0.12)
			tw.tween_method(_dash_step, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_skill_t = 0.45
			Audio.play("whirl", -4.0, 0.1)
		"ward":
			var c := _best_cluster()
			if int(c[1]) == 0:
				return false
			_skill_at = c[0]
			_face_to(_skill_at)
			model.play("skill", 1.4, 0.08, true)
			fx.charge(aim_point() + Vector3(0, 0.6, 0), WARD_COL, 0.55)
			_skill_t = 0.6
			Audio.play("star", -4.0, 0.1)
		"pierce":
			var ln := _pierce_line()
			if int(ln[1]) == 0:
				return false
			_pierce_dir = ln[0]
			_face_to(global_position + _pierce_dir)
			model.play("attack", 1.1, 0.05, true)
			fx.charge(aim_point() + _pierce_dir * 0.5 + Vector3(0, 0.3, 0), PIERCE_COL, 0.35)
			_skill_t = 0.4
			Audio.play("bow", -4.0, 0.05, 2)
	skill2_cd = skill2_cd_max()
	_cast = 2
	Audio.voice(d.get("voice", hid + "_skill"))
	return true

func _dash_step(t: float) -> void:
	if not alive:
		return
	var p := _dash_from.lerp(_dash_to, t)
	p.y = LevelMain.I.terrain.walk_height(p.x, p.z)
	global_position = p
	if randf() < 0.45:
		LevelMain.I.fx.burn_puff(p + Vector3(0, 0.5, 0))

func _skill2_impact() -> void:
	var d := skill2_def()
	var lv := LevelMain.I
	match d["id"]:
		"charge":
			var a := _dash_from
			var b := _dash_to
			var ab := b - a
			ab.y = 0.0
			var len2 := maxf(ab.length_squared(), 0.0001)
			for e: Enemy in lv.enemies.duplicate():
				if not e.alive or e.flying:
					continue
				var rel := e.global_position - a
				rel.y = 0.0
				var t := clampf(rel.dot(ab) / len2, 0.0, 1.0)
				if (rel - ab * t).length() < 1.5:
					e.damage(skill2_damage(), "physical")
					if e.alive and not e.boss:
						e.stun(float(d["stun"]))
						lv.fx.stun_stars(e)
			lv.fx.fire_ring(b, 2.0)
			lv.fx.dust(b, 1.2)
			lv.fx.slash_arc(b, Color(1.0, 0.6, 0.2), 2.2)
			lv.cam_rig.shake(0.3)
			Audio.play("slam", -4.0, 0.1)
			rally = global_position
			commanded = false
			model.play("attack", 1.6, 0.05, true)
		"ward":
			_ward_t = float(d["time"])
			_ward_at = _skill_at
			_ward_tick = 0.0
			lv.fx.shockwave(_ward_at, _ward_radius(), WARD_COL)
			lv.fx.magic_burst(_ward_at + Vector3(0, 0.6, 0), WARD_COL, 1.3)
			lv.fx.light_flash(_ward_at + Vector3(0, 1.5, 0), WARD_COL, 3.0, 7.0, 0.3)
			Audio.play("magic", -2.0)
			model.play("idle")
		"pierce":
			_pierce_shot()
			model.play("idle")

func _ward_radius() -> float:
	return float(skill2_def()["radius"]) * (1.0 + 0.05 * DB.talent(hid, "skill"))

## Sera's ward: every half second the rune glows again, slows what stands in it and burns it with
## starlight (it keeps going if she falls).
func _ward_update(delta: float) -> void:
	_ward_t -= delta
	_ward_tick -= delta
	if _ward_tick > 0.0:
		return
	_ward_tick = 0.5
	var lv := LevelMain.I
	var r := _ward_radius()
	lv.fx.rune_circle(_ward_at + Vector3(0, 0.08, 0), WARD_COL, r, 1.1)
	var per := skill2_damage() * 0.5
	var slow_k := float(skill2_def()["slow"])
	for e: Enemy in lv.enemies.duplicate():
		if e.alive and e.global_position.distance_to(_ward_at) < r:
			e.damage(per, "magic", false)
			if e.alive:
				e.slow(slow_k, 0.7)
			lv.fx.hit_spark(e.aim_point(), WARD_COL, 0.5)

## Ren's piercing arrow: one big arrow along the chosen line, hitting each enemy once as it passes.
func _pierce_shot() -> void:
	var lv := LevelMain.I
	var length: float = float(skill2_def()["length"])
	var start := aim_point() + Vector3(0, 0.2, 0) + _pierce_dir * 0.5
	var end := start + _pierce_dir * length
	var arr := Assets.instance("p_arrow")
	arr.scale = Vector3.ONE * 2.2
	lv.world.add_child(arr)
	arr.global_position = start
	arr.look_at(end, Vector3.UP)
	arr.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	var trail_p := lv.fx.trail(arr, PIERCE_COL, 0.45)
	var dmg_v := skill2_damage()
	var hit := {}
	lv.fx.hit_spark(start, PIERCE_COL, 1.2)
	var wake_a := Vector3(start.x, lv.terrain.walk_height(start.x, start.z) + 1.0, start.z)
	var wake_b := Vector3(end.x, lv.terrain.walk_height(end.x, end.z) + 1.0, end.z)
	lv.fx.streak(wake_a, wake_b, PIERCE_COL, 0.55, 0.5)
	lv.cam_rig.shake(0.15)
	Audio.play("bow", -1.0, 0.05, 2)
	var step := func(t: float) -> void:
		var p := start.lerp(end, t)
		p.y = lv.terrain.walk_height(p.x, p.z) + 1.0
		arr.global_position = p
		for e: Enemy in lv.enemies.duplicate():
			if e.alive and not hit.has(e) and Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() < 1.0:
				hit[e] = true
				e.damage(dmg_v, "physical", true, 1.0)
				lv.fx.hit_spark(e.aim_point(), PIERCE_COL, 1.0)
				Audio.play("clash", -10.0, 0.2, 3)
	var done := func() -> void:
		lv.fx.detach_trail(trail_p)
		arr.queue_free()
	var tw := arr.create_tween()
	tw.tween_method(step, 0.0, 1.0, length / 38.0)
	tw.tween_callback(done)

func _on_hit(e: Enemy) -> void:
	super._on_hit(e)
	LevelMain.I.fx.hit_spark(e.aim_point(), Color(1.0, 0.6, 0.2))

func add_xp(v: float) -> void:
	if level >= 5:
		return
	xp += v
	var lv: Array = DB.HERO_XP
	while level < 5 and xp >= lv[level]:
		level += 1
		var mult := 1.0 + (level - 1) * 0.15
		set_stats(_base_hp * mult, [_base_dmg[0] * mult, _base_dmg[1] * mult], armor, atk_rate)
		hp = max_hp
		LevelMain.I.fx.level_up(self)
		LevelMain.I.overlay.float_text(aim_point() + Vector3(0, 1.2, 0), "LEVEL UP!", Color(1.0, 0.85, 0.3), 1.3)
		Audio.play("levelup", -2.0)
		Audio.voice(hid + "_levelup")
		leveled.emit(level)

func xp_progress() -> float:
	if level >= 5:
		return 1.0
	var lv: Array = DB.HERO_XP
	return clampf((xp - lv[level - 1]) / float(lv[level] - lv[level - 1]), 0.0, 1.0)

func die() -> void:
	if not alive:
		return
	super.die()
	Audio.voice(hid + "_death")
	respawn_t = float(DB.hero_def()["respawn"]) - (4.0 if DB.up("hero") else 0.0) - 1.5 * DB.talent(hid, "cd")
	commanded = false
	_sel_ring.visible = false
