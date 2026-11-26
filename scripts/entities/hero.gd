class_name Hero
extends Soldier
## Player-controlled hero: tap to move, auto-fights, Ember Whirlwind skill, levels up, respawns.

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
	if not alive or skill_cd > 0.0:
		return false
	skill_cd = skill_cd_max()
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
