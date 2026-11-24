class_name Projectile
extends Node3D
## Arrows (homing arc), magic bolts (homing), bombs (ballistic AoE), meteors.

enum Kind { ARROW, BOLT, BOMB, BOMBLET, METEOR }

var kind := Kind.ARROW
var start := Vector3.ZERO
var dest := Vector3.ZERO
var target: Enemy = null
var dmg := 0.0
var t := 0.0
var dur := 0.5
var arc := 2.0
var splash := 0.0
var slow := 0.0
var burn := 0.0
var cluster := 0
var crit := false
var pierce := 0.0
var ability := ""  # tower ability riding on this shot: poison / execute / freeze / shock / napalm
var color := Color.WHITE
var _trail: CPUParticles3D
var _last := Vector3.ZERO

static var _bolt_mesh: SphereMesh
static var _bolt_mats := {}
static var _meteor_mat: StandardMaterial3D

static func _spawn(k: int) -> Projectile:
	var p := Projectile.new()
	p.kind = k
	LevelMain.I.world.add_child(p)
	return p

static func arrow(from: Vector3, tgt: Enemy, d: float, is_crit := false, p_pierce := 0.0, p_ability := "") -> Projectile:
	var p := _spawn(Kind.ARROW)
	p.start = from
	p.target = tgt
	p.dest = tgt.aim_point()
	p.dmg = d
	p.crit = is_crit
	p.pierce = p_pierce
	p.ability = p_ability
	var dist := from.distance_to(p.dest)
	p.dur = clampf(dist / 22.0, 0.22, 0.6)
	p.arc = dist * 0.12
	var m := Assets.instance("p_arrow")
	m.scale = Vector3.ONE * (1.1 if not is_crit else 1.5)
	if p_ability == "javelin":
		m.scale = Vector3(1.6, 2.2, 1.6)
	p.add_child(m)
	p.global_position = from
	return p

static func bolt(from: Vector3, tgt: Enemy, d: float, c: Color, p_slow := 0.0, p_splash := 0.0, p_ability := "") -> void:
	var p := _spawn(Kind.BOLT)
	p.ability = p_ability
	p.start = from
	p.target = tgt
	p.dest = tgt.aim_point()
	p.dmg = d
	p.color = c
	p.slow = p_slow
	p.splash = p_splash
	p.dur = clampf(from.distance_to(p.dest) / 14.0, 0.25, 0.7)
	p.arc = 0.8
	if _bolt_mesh == null:
		_bolt_mesh = SphereMesh.new()
		_bolt_mesh.radius = 0.22
		_bolt_mesh.height = 0.44
		_bolt_mesh.radial_segments = 10
		_bolt_mesh.rings = 6
	var key := c.to_html()
	if not _bolt_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c.lightened(0.4)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 4.0
		_bolt_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _bolt_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	p._trail = LevelMain.I.fx.trail(p, c, 0.3)
	p.global_position = from

static func bomb(from: Vector3, to: Vector3, d: float, p_splash: float, p_burn := 0.0, p_cluster := 0, is_small := false, p_ability := "") -> void:
	var p := _spawn(Kind.BOMBLET if is_small else Kind.BOMB)
	p.ability = p_ability
	p.start = from
	p.dest = to
	p.dmg = d
	p.splash = p_splash
	p.burn = p_burn
	p.cluster = p_cluster
	var dist := from.distance_to(to)
	p.dur = clampf(dist / 9.0, 0.6, 1.2) if not is_small else 0.45
	p.arc = maxf(dist * 0.45, 2.5) if not is_small else 1.4
	var m := Assets.instance("p_bomb")
	m.scale = Vector3.ONE * (1.3 if not is_small else 0.7)
	p.add_child(m)
	p._trail = LevelMain.I.fx.trail(p, Color(0.5, 0.45, 0.4), 0.25, true)
	p.global_position = from

static func meteor(to: Vector3, d: float, radius: float, delay: float) -> void:
	var p := _spawn(Kind.METEOR)
	p.dest = to
	p.start = to + Vector3(-6.0, 22.0, -8.0)
	p.dmg = d
	p.splash = radius
	p.dur = 0.85
	p.arc = 0.0
	p.t = -delay
	if _meteor_mat == null:
		_meteor_mat = StandardMaterial3D.new()
		_meteor_mat.albedo_color = Color(1.0, 0.5, 0.15)
		_meteor_mat.emission_enabled = true
		_meteor_mat.emission = Color(1.0, 0.45, 0.1)
		_meteor_mat.emission_energy_multiplier = 5.0
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _meteor_mat
	p.add_child(mi)
	var rock := Assets.instance("rock_0")
	rock.scale = Vector3.ONE * 0.9
	p.add_child(rock)
	p._trail = LevelMain.I.fx.trail(p, Color(1.0, 0.5, 0.15), 0.9)
	p.global_position = p.start
	p.visible = delay <= 0.0

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	t += delta
	if t < 0.0:
		return
	visible = true
	if target != null and is_instance_valid(target) and target.alive:
		dest = target.aim_point()
	var k := clampf(t / dur, 0.0, 1.0)
	var p := start.lerp(dest, k)
	p.y += arc * 4.0 * k * (1.0 - k)
	_last = global_position
	global_position = p
	var dir := p - _last
	if dir.length_squared() > 0.00001 and kind != Kind.BOLT:
		var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT
		look_at(p + dir, up)
		if kind == Kind.ARROW:
			rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	if kind == Kind.BOMB or kind == Kind.BOMBLET or kind == Kind.METEOR:
		rotate_object_local(Vector3.FORWARD, delta * 6.0)
	if k >= 1.0:
		_impact()

func _impact() -> void:
	var fx := LevelMain.I.fx
	match kind:
		Kind.ARROW:
			if target != null and is_instance_valid(target) and target.alive:
				target.damage(dmg, "physical", true, pierce)
				fx.hit_spark(dest, Color(1, 0.95, 0.8), 0.6)
				if ability == "poison" and target.alive:
					target.poison(9.0, 3.0)
					Tower.count_ability("poison")
				elif ability == "execute" and target.alive and not target.boss and target.hp <= target.max_hp * 0.25:
					target.damage(target.hp + 1.0, "true")
					Tower.count_ability("execute")
					LevelMain.I.overlay.float_text(dest + Vector3(0, 0.7, 0), "처형!", Color(1.0, 0.4, 0.3), 1.1)
					fx.magic_burst(dest, Color(1.0, 0.35, 0.25), 0.7)
				if crit:
					LevelMain.I.overlay.float_text(dest + Vector3(0, 0.6, 0), "치명타!", Color(1.0, 0.85, 0.2), 1.0)
					fx.magic_burst(dest, Color(1.0, 0.85, 0.3), 0.6)
		Kind.BOLT:
			if splash > 0.0:
				for e: Enemy in LevelMain.I.enemies.duplicate():
					if e.alive and e.aim_point().distance_to(dest) < splash:
						e.damage(dmg, "magic")
						if slow > 0.0 and e.alive:
							e.slow(1.0 - slow, 2.5)
						if ability == "freeze" and e.alive and randf() < 0.2:
							e.freeze(1.5)
							Tower.count_ability("freeze")
				fx.frost_nova(dest, splash)
				Audio.play("frost", -6.0, 0.1)
			elif target != null and is_instance_valid(target) and target.alive:
				target.damage(dmg, "magic")
				if slow > 0.0:
					target.slow(1.0 - slow, 2.5)
			fx.magic_burst(dest, color, 0.8)
		Kind.BOMB, Kind.BOMBLET:
			_explode(dest, splash, dmg, kind == Kind.BOMB)
			if burn > 0.0:
				fx.fire_patch(dest, splash * 0.8, burn)
			if cluster > 0:
				for i in cluster:
					var a := i * TAU / cluster + randf() * 0.5
					var to := dest + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 2.6)
					to.y = LevelMain.I.terrain.walk_height(to.x, to.z)
					Projectile.bomb(dest + Vector3(0, 0.3, 0), to, dmg * 0.4, 1.4, 10.0 if ability == "napalm" else 0.0, 0, true)
					if ability == "napalm":
						Tower.count_ability("napalm")
		Kind.METEOR:
			_explode(dest, splash, dmg, true, "magic")
			fx.scorch(dest, splash)
			fx.fire_patch(dest, splash * 0.7, 10.0)
			LevelMain.I.cam_rig.shake(0.8)
	if _trail:
		LevelMain.I.fx.detach_trail(_trail)
	queue_free()

func _explode(at: Vector3, r: float, d: float, big: bool, dtype := "physical") -> void:
	var fx := LevelMain.I.fx
	fx.explosion(at, r * 0.5 if big else r * 0.35)
	if big:
		LevelMain.I.cam_rig.shake(0.25 * r * 0.5)
		Audio.play("boom", 0.0 if kind == Kind.METEOR else -3.0, 0.12, 2)
	else:
		Audio.play("boom", -9.0, 0.2, 2)
	for e: Enemy in LevelMain.I.enemies.duplicate():
		if not e.alive or e.flying:
			continue
		var dd := Vector2(e.global_position.x - at.x, e.global_position.z - at.z).length()
		if dd < r:
			var falloff := lerpf(1.0, 0.5, dd / r)
			e.damage(d * falloff, dtype)
			if burn > 0.0:
				e.burn(burn * 0.5, 3.0)
			if ability == "shock" and e.alive:
				e.stun(0.8)
				Tower.count_ability("shock")
