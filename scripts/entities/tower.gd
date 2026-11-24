class_name Tower
extends Node3D
## A built tower on a plot. Handles targeting, firing, upgrades, masteries and barracks soldiers.

var type := ""
var level := 1
var mastery := ""
var ability := ""  # special ability bought after the mastery (one per mastery)
var _tele_cd := 0.0
var stats: Dictionary
var invested := 0
var plot: Vector2
var model: Node3D
var units: Array = []
var crystal: Node3D
var ring: Node3D
var barrel: Node3D
var cd := 0.5
var rally := Vector3.ZERO
var soldiers: Array = []
var _respawn: Array = []
var _t := 0.0
var _aura: MeshInstance3D

func setup(p_type: String, p_plot: Vector2) -> void:
	type = p_type
	plot = p_plot
	position = Vector3(plot.x, LevelMain.I.terrain.height_at(plot.x, plot.y), plot.y)
	stats = DB.tower_stats(type, 1, "")
	invested = stats["cost"]
	_build_model(true)
	if type == "barracks":
		rally = _default_rally()
		_spawn_soldiers()

func data() -> Dictionary:
	return DB.TOWERS[type]

func range_r() -> float:
	return stats["range"]

func sell_value() -> int:
	return int(invested * (0.8 if DB.up("salvage") else 0.6))

func next_cost() -> int:
	if level < 3:
		return data()["levels"][level]["cost"]
	return -1

func upgrade() -> void:
	level += 1
	stats = DB.tower_stats(type, level, "")
	invested += stats["cost"]
	_build_model(true)
	if type == "barracks":
		_refresh_soldiers()

func apply_mastery(id: String) -> void:
	mastery = id
	var md := DB.mastery_def(type, id)
	invested += md["cost"]
	stats = DB.tower_stats(type, 3, id)
	level = 4
	_build_model(true)
	if type == "barracks":
		_refresh_soldiers()

func buy_ability() -> void:
	var ad := DB.ability_def(type, mastery)
	if ad.is_empty():
		return
	ability = ad["id"]
	invested += DB.ability_cost(type, mastery)
	_build_model(true)
	if type == "barracks":
		_refresh_soldiers()

func _build_model(animate: bool) -> void:
	if model:
		model.queue_free()
	var mname: String = DB.TOWERS[type]["levels"][mini(level, 3) - 1]["model"]
	model = Node3D.new()
	add_child(model)
	var body := Assets.instance(mname)
	model.add_child(body)
	if LevelMain.I and LevelMain.I.def.get("theme", "") == "snow":
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = Assets.snow_overlay()
	units.clear()
	crystal = null
	ring = null
	barrel = null
	var top := ModelMeta.top(mname)
	match type:
		"archer":
			var n := 2 if level < 3 else 3
			for i in n:
				var cm := CharacterModel.new()
				model.add_child(cm)
				cm.setup("archer_unit", 1.3)
				var spread := 0.9 if n == 2 else 0.75
				cm.position = Vector3(-spread * 0.5 * (n - 1) + spread * i, top - 0.02, 0.18 - absf(i - (n - 1) * 0.5) * 0.12)
				cm.play("idle", randf_range(0.9, 1.1))
				units.append(cm)
		"mage":
			var cm := CharacterModel.new()
			model.add_child(cm)
			cm.setup("mage_unit", 1.35)
			cm.position = Vector3(0, top - 0.02, 0.08)
			cm.play("idle")
			units.append(cm)
			crystal = _make_crystal()
			crystal.position = Vector3(0.0, top + 1.95, 0.25)
			model.add_child(crystal)
			ring = _make_rune_ring(0.7 + level * 0.08)
			ring.position = Vector3(0, top + 0.04, 0.08)
			model.add_child(ring)
		"artillery":
			barrel = _make_mortar(0.72 + level * 0.1)
			barrel.position = Vector3(0, top - 0.05, 0.1)
			model.add_child(barrel)
	if _aura:
		_aura.queue_free()
		_aura = null
	if mastery != "":
		_add_mastery_visual(ModelMeta.height(mname))
	if animate:
		model.scale = Vector3(0.6, 0.2, 0.6)
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		LevelMain.I.fx.build_poof(global_position)
		if level > 1:
			LevelMain.I.fx.upgrade_beam(global_position, data().get("color", Color(1.0, 0.85, 0.4)))

func _make_crystal() -> Node3D:
	var root := Node3D.new()
	root.name = "Crystal"
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 4
	sm.rings = 2
	sm.radius = 0.2
	sm.height = 0.62
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	var c := Color(0.75, 0.45, 1.0) if mastery != "frost" else Color(0.5, 0.9, 1.0)
	m.albedo_color = c.lerp(Color.WHITE, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.6
	m.metallic = 0.3
	m.roughness = 0.15
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var glow := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.3, 1.3)
	glow.mesh = qm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.albedo_texture = FX.tex("fx_glow")
	gm.albedo_color = Color(c.r, c.g, c.b, 0.7)
	gm.no_depth_test = false
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	return root

func _make_rune_ring(r: float) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "Ring"
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = FX.tex("fx_rune")
	var c := Color(0.75, 0.45, 1.0) if mastery != "frost" else Color(0.5, 0.9, 1.0)
	m.albedo_color = Color(c.r, c.g, c.b, 0.65)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static var _mortar_mats := {}

func _mortar_mat(k: String) -> StandardMaterial3D:
	if _mortar_mats.has(k):
		return _mortar_mats[k]
	var m := StandardMaterial3D.new()
	match k:
		"iron":
			m.albedo_color = Color(0.2, 0.21, 0.25)
			m.metallic = 0.65
			m.roughness = 0.4
		"gold":
			m.albedo_color = Color(0.9, 0.66, 0.24)
			m.metallic = 0.85
			m.roughness = 0.3
		"wood":
			m.albedo_color = Color(0.42, 0.26, 0.14)
			m.roughness = 0.8
		"hole":
			m.albedo_color = Color(0.03, 0.03, 0.03)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mortar_mats[k] = m
	return m

func _cyl(parent: Node3D, top_r: float, bot_r: float, h: float, y: float, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 1
	mi.mesh = cm
	mi.position.y = y
	mi.material_override = _mortar_mat(mat)
	parent.add_child(mi)
	return mi

func _make_mortar(s: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Barrel"
	root.scale = Vector3.ONE * s
	_cyl(root, 0.52, 0.6, 0.26, 0.13, "wood")
	_cyl(root, 0.55, 0.55, 0.06, 0.27, "gold")
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	tilt.position.y = 0.42
	tilt.rotation_degrees.x = 38.0
	root.add_child(tilt)
	_cyl(tilt, 0.27, 0.36, 0.95, 0.3, "iron")
	_cyl(tilt, 0.38, 0.38, 0.1, 0.05, "gold")
	_cyl(tilt, 0.33, 0.33, 0.12, 0.74, "gold")
	_cyl(tilt, 0.22, 0.22, 0.02, 0.8, "hole")
	var mz := Marker3D.new()
	mz.name = "Muzzle"
	mz.position.y = 0.85
	tilt.add_child(mz)
	return root

func _add_mastery_visual(h: float) -> void:
	var md := DB.mastery_def(type, mastery)
	var tint: Color = md["tint"]
	_aura = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.9
	cm.bottom_radius = 1.9
	cm.height = 0.02
	cm.radial_segments = 32
	_aura.mesh = cm
	_aura.position.y = 0.16
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Assets.soft_dot()
	m.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_aura.material_override = m
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	# glowing crest banner over the tower
	var crest := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.6, 0.12)
	crest.mesh = pm
	crest.rotation_degrees.z = 180
	var cmt := StandardMaterial3D.new()
	cmt.albedo_color = tint
	cmt.emission_enabled = true
	cmt.emission = tint
	cmt.emission_energy_multiplier = 2.5
	crest.material_override = cmt
	crest.position.y = h + 0.9
	crest.name = "Crest"
	model.add_child(crest)
	if ability != "":
		var g := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radial_segments = 4
		gm.rings = 2
		gm.radius = 0.16
		gm.height = 0.42
		g.mesh = gm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.95, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.9, 1.0)
		mat.emission_energy_multiplier = 3.0
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.position = Vector3(0.0, 0.62, 0.0)
		crest.add_child(g)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	_tele_cd -= delta
	if crystal:
		if not crystal.has_meta("y0"):
			crystal.set_meta("y0", crystal.position.y)
		crystal.rotation.y += delta * 1.4
		crystal.position.y = float(crystal.get_meta("y0")) + sin(_t * 2.0) * 0.12
	if ring:
		ring.rotation.y -= delta * 0.8
	for u in units:
		var cm := u as CharacterModel
		if cm.current == "attack" and cm.anim and not cm.anim.is_playing():
			cm.play("idle", 1.0, 0.25)
	var crest := model.get_node_or_null("Crest") if model else null
	if crest:
		crest.rotation.y += delta * 1.5
	if type == "barracks":
		_barracks_tick(delta)
		return
	cd -= delta
	if cd <= 0.0:
		var tgt := _find_target(range_r())
		if tgt:
			cd = stats["rate"]
			_fire(tgt)
		else:
			cd = 0.1

## Target priority: "first" (furthest along the path), "strong" (highest HP), "close" (nearest).
var priority := "first"

func cycle_priority() -> String:
	var order := ["first", "strong", "close"]
	priority = order[(order.find(priority) + 1) % order.size()]
	return priority

func _find_target(r: float, exclude := []) -> Enemy:
	var best: Enemy = null
	var best_score := -1e9
	var air: bool = data()["air"]
	var me := Vector2(global_position.x, global_position.z)
	for e: Enemy in LevelMain.I.enemies:
		if not e.alive or (e.flying and not air) or e in exclude:
			continue
		var ep := Vector2(e.global_position.x, e.global_position.z)
		var dd := ep.distance_to(me)
		if dd > r:
			continue
		var score := 0.0
		match priority:
			"strong":
				score = e.hp + e.dist / e.path.length * 0.01
			"close":
				score = -dd
			_:
				score = e.dist / e.path.length
		if score > best_score:
			best_score = score
			best = e
	return best

func _muzzle() -> Vector3:
	if crystal:
		return crystal.global_position
	if barrel:
		var mz := barrel.find_child("Muzzle", true, false) as Node3D
		if mz:
			return mz.global_position
	if not units.is_empty():
		return (units[randi() % units.size()] as Node3D).global_position + Vector3(0, 1.0, 0)
	return global_position + Vector3(0, 3.0, 0)

func _aim_units(p: Vector3, seek: float, speed: float) -> void:
	for u in units:
		var n := u as CharacterModel
		var to := p - n.global_position
		n.rotation.y = atan2(to.x, to.z)
		n.play("attack", speed, 0.05, true)
		if n.anim and n.anim.has_animation("attack"):
			n.anim.seek(seek, true)
	if barrel:
		var to2 := p - barrel.global_position
		barrel.rotation.y = atan2(to2.x, to2.z)
		var tilt := barrel.get_node("Tilt") as Node3D
		var tw := create_tween()
		tilt.position.z = -0.22
		tilt.scale = Vector3(1.12, 0.84, 1.12)
		tw.tween_property(tilt, "position:z", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tilt, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _roll() -> float:
	return randf_range(stats["dmg"][0], stats["dmg"][1])

func _fire(tgt: Enemy) -> void:
	var fx := LevelMain.I.fx
	match type:
		"archer":
			_aim_units(tgt.global_position, 0.44, 1.35)
			var targets := [tgt]
			var n: int = stats.get("multishot", 1)
			while targets.size() < n:
				var extra := _find_target(range_r(), targets)
				if extra == null:
					break
				targets.append(extra)
			get_tree().create_timer(0.13, false).timeout.connect(func():
				if not is_instance_valid(self):
					return
				var k := 0
				for t: Enemy in targets:
					if not is_instance_valid(t) or not t.alive:
						continue
					var dmgv := _roll()
					var crit: bool = randf() < float(stats.get("crit", 0.0))
					if crit:
						dmgv *= 3.0
					var u := units[k % units.size()] as Node3D
					k += 1
					Projectile.arrow(u.global_position + Vector3(0, 0.95, 0), t, dmgv, crit, float(stats.get("pierce", 0.0)), ability)
				Audio.play("bow", -6.0, 0.12, 2))
		"mage":
			_aim_units(tgt.global_position, 0.36, 1.3)
			var c := Color(0.75, 0.45, 1.0)
			if mastery == "frost":
				c = Color(0.5, 0.9, 1.0)
			fx.charge(_muzzle(), c, 0.22)
			get_tree().create_timer(0.2, false).timeout.connect(func():
				if not is_instance_valid(self):
					return
				var t2: Enemy = tgt
				if not is_instance_valid(t2) or not t2.alive:
					t2 = _find_target(range_r())
					if t2 == null:
						return
				if ring:
					fx.rune_circle(ring.global_position + Vector3(0, 0.03, 0), c, 2.0 + level * 0.2, 0.5)
				if mastery == "arcane":
					_chain_lightning(t2)
					return
				Projectile.bolt(_muzzle(), t2, _roll(), c, stats.get("slow", 0.0), stats.get("splash", 0.0), ability)
				fx.magic_burst(_muzzle(), c, 0.55)
				Audio.play("magic", -6.0, 0.1))
		"artillery":
			_aim_units(tgt.global_position, 0.0, 1.0)
			var lead := tgt.vel * 1.05
			var dest := tgt.global_position + lead
			dest.y = LevelMain.I.terrain.walk_height(dest.x, dest.z)
			var mz := _muzzle()
			Projectile.bomb(mz, dest, _roll(), stats["splash"], stats.get("burn", 0.0), stats.get("cluster", 0), false, ability)
			var dir := (dest - mz)
			dir.y = 0.0
			fx.muzzle_flash(mz, (dir.normalized() + Vector3.UP * 1.2).normalized())
			fx.smoke(mz, 0.7)
			fx.light_flash(mz, Color(1.0, 0.65, 0.3), 2.5, 6.0, 0.15)
			Audio.play("cannon", -3.0, 0.1)

func _chain_lightning(first: Enemy) -> void:
	var hit := [first]
	var from := _muzzle()
	var cur := first
	var dmgv := _roll()
	var n: int = stats.get("chain", 4)
	Audio.play("zap", -3.0, 0.1)
	if ability == "teleport" and _tele_cd <= 0.0 and not first.boss and first.dist > 3.0:
		_tele_cd = 6.0
		_teleport(first)
	for i in n:
		if not is_instance_valid(cur) or not cur.alive:
			break
		LevelMain.I.fx.lightning(from, cur.aim_point(), Color(0.8, 0.6, 1.0))
		cur.damage(dmgv, "magic")
		LevelMain.I.fx.magic_burst(cur.aim_point(), Color(0.8, 0.6, 1.0), 0.5)
		dmgv *= 0.8
		from = cur.aim_point()
		var nxt: Enemy = null
		var bd := 4.5
		for e: Enemy in LevelMain.I.enemies:
			if e.alive and not e in hit:
				var dd := e.global_position.distance_to(cur.global_position)
				if dd < bd:
					bd = dd
					nxt = e
		if nxt == null:
			break
		hit.append(nxt)
		cur = nxt

## Arcane ability: fold space and drop the enemy 8 m back down its path.
func _teleport(e: Enemy) -> void:
	var fx := LevelMain.I.fx
	fx.magic_burst(e.aim_point(), Color(0.8, 0.5, 1.0), 1.0)
	fx.rune_circle(e.global_position + Vector3(0, 0.1, 0), Color(0.8, 0.5, 1.0), 1.3, 0.6)
	if e.blocker and is_instance_valid(e.blocker):
		e.blocker.target_lost(e)
	e.blocker = null
	e.engaged = false
	e.dist = maxf(e.dist - 8.0, 0.5)
	e._update_transform(0.0)
	e._prev = e.global_position
	fx.magic_burst(e.aim_point(), Color(0.8, 0.5, 1.0), 1.0)
	LevelMain.I.overlay.float_text(e.aim_point() + Vector3(0, 0.8, 0), "차원 이동!", Color(0.85, 0.6, 1.0), 1.0)
	Audio.play("zap", -6.0, 0.1)

# ---------------------------------------------------------------- barracks

func _default_rally() -> Vector3:
	var me := Vector2(global_position.x, global_position.z)
	var best := Vector2.ZERO
	var bd := 1e9
	for lp in LevelMain.I.paths:
		var c: Vector2 = (lp as LanePath).closest(me)
		var p: Vector2 = (lp as LanePath).sample(c.y)
		if c.x < bd:
			bd = c.x
			best = p
	return Vector3(best.x, LevelMain.I.terrain.walk_height(best.x, best.y), best.y)

func set_rally(p: Vector3) -> bool:
	var me := Vector2(global_position.x, global_position.z)
	if Vector2(p.x, p.z).distance_to(me) > range_r():
		return false
	if LevelMain.I.terrain.path_dist(p.x, p.z) > 2.6:
		return false
	rally = Vector3(p.x, LevelMain.I.terrain.walk_height(p.x, p.z), p.z)
	for i in soldiers.size():
		var s: Soldier = soldiers[i]
		s.rally = rally
		s._release()
	LevelMain.I.fx.move_marker(rally)
	return true

func _slot(i: int, n: int) -> Vector3:
	var a := i * TAU / n + 0.5
	return Vector3(cos(a), 0, sin(a)) * 0.85

func _soldier_kind() -> Array:
	match mastery:
		"paladin": return [Color(1.0, 0.9, 0.55), "w_sword", 1.85]
		"lancer": return [Color(0.65, 0.85, 1.0), "w_sword", 1.75]
	return [Color.WHITE, "", 1.7]

func _spawn_soldiers() -> void:
	var n: int = stats["count"]
	for i in n:
		_spawn_one(i, n)

func _spawn_one(i: int, n: int) -> void:
	var kind := _soldier_kind()
	var s := Soldier.new()
	LevelMain.I.world.add_child(s)
	s.setup_unit("footman", kind[2], kind[0], kind[1])
	s.persistent = true
	s.set_stats(stats["soldier_hp"], stats["soldier_dmg"], stats["soldier_armor"], 1.0)
	s.hp = s.max_hp
	s.heal_ps = stats.get("heal", 0.0)
	s.holy = 0.5 if ability == "holy" else 0.0
	s.javelin = ability == "javelin"
	s.rally = rally
	s.slot = _slot(i, n)
	s.engage_radius = 3.0
	s.global_position = global_position + Vector3(0, 0, 1.6)
	s.died.connect(_on_soldier_died)
	soldiers.append(s)
	_respawn.append(0.0)
	LevelMain.I.soldiers.append(s)

func _refresh_soldiers() -> void:
	var n: int = stats["count"]
	var kind := _soldier_kind()
	# rebuild visuals if mastery changed the look
	if mastery != "" and soldiers.size() > 0 and soldiers[0].get_meta("kind", "") != mastery:
		for s in soldiers:
			LevelMain.I.soldiers.erase(s)
			s._release()
			s.queue_free()
		soldiers.clear()
		_respawn.clear()
		_spawn_soldiers()
		for s in soldiers:
			s.set_meta("kind", mastery)
		return
	for s in soldiers:
		(s as Soldier).set_stats(stats["soldier_hp"], stats["soldier_dmg"], stats["soldier_armor"], 1.0)
		(s as Soldier).heal_ps = stats.get("heal", 0.0)
		(s as Soldier).holy = 0.5 if ability == "holy" else 0.0
		(s as Soldier).javelin = ability == "javelin"
	while soldiers.size() < n:
		_spawn_one(soldiers.size(), n)
	for i in soldiers.size():
		(soldiers[i] as Soldier).slot = _slot(i, soldiers.size())

func _on_soldier_died(s: Soldier) -> void:
	var i := soldiers.find(s)
	if i >= 0:
		_respawn[i] = stats["respawn"]

func _barracks_tick(delta: float) -> void:
	for i in soldiers.size():
		var s: Soldier = soldiers[i]
		if not s.alive:
			_respawn[i] -= delta
			if _respawn[i] <= 0.0 and not s.visible:
				s.revive_at(global_position + Vector3(0, 0, 1.4))
				s.rally = rally

func remove() -> void:
	for s in soldiers:
		LevelMain.I.soldiers.erase(s)
		(s as Soldier)._release()
		(s as Soldier).queue_free()
	soldiers.clear()
	queue_free()
