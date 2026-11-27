class_name ShaderWarmup
extends RefCounted
## Shader warm-up: the web build's answer to a PSO cache.
##
## WebGL cannot load compiled shader programs from disk (no glProgramBinary), so every GL program
## a battle needs is compiled the first time something drawn with it reaches the screen. Each
## program costs from a few to tens of milliseconds (ANGLE translates GLSL to HLSL/Metal first), and
## the first archer tower alone needs ~17 of them: that was the hitch when a tower went up or an
## effect showed for the first time. A program is keyed by the material's shader, the pass (colour,
## depth/shadow, instanced or not) and the lights on the object (an omni light switches on a
## variant). So while the screen is still black after loading, this draws one of everything the
## battle can show later - every tower at every level and specialisation with its soldiers and
## shots, every enemy of the level (with the hit flash and frost overlays), every effect - once
## under an omni light and once without, then removes it all. The tree is paused, sound is muted
## and nothing touches the battle state. Chrome then keeps the compiled programs in its own GPU
## cache, so later visits warm up faster still.

## Frames drawn with the omni light on, then off.
const LIT_FRAMES := 3
const DARK_FRAMES := 2
## Frames of the whole-map view (the first lit, the rest unlit).
const OVERVIEW_FRAMES := 2
## Measuring only (test_runner warmstaged=1): draw each group on its own frames and print a
## NEWTHING line before it, so tools/perf/glc_sum.py can say which group compiles what.
static var staged := false

static func run(L: LevelMain) -> void:
	if L == null or not is_instance_valid(L) or not L.is_inside_tree():
		return
	var tree := L.get_tree()
	var t0 := Time.get_ticks_msec()
	var was_paused := tree.paused
	var was_muted := AudioServer.is_bus_mute(0)
	tree.paused = true
	AudioServer.set_bus_mute(0, true)
	var fx_mode := L.fx.process_mode
	L.fx.process_mode = Node.PROCESS_MODE_ALWAYS
	var fx_before := {}
	for c in L.fx.get_children():
		fx_before[c] = true
	var world_before := {}
	for c in L.world.get_children():
		world_before[c] = true
	var hits_before: Dictionary = Tower.ability_hits.duplicate()
	var root := Node3D.new()
	root.name = "ShaderWarmup"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	L.world.add_child(root)
	var spots := _spots(L)
	var si := 0
	# enemies of this battle; the first is the target the shots fly at
	var kinds := {}
	for wv in L.waves:
		for e in wv:
			kinds[str(e[0])] = true
	var dummy: Enemy = null
	var k := 0
	for type in kinds:
		if not DB.ENEMIES.has(type):
			continue
		var e := Enemy.new()
		root.add_child(e)
		e.setup(type, L.paths[0], 1.0)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.global_position = spots[si % spots.size()]
		si += 1
		if dummy == null:
			dummy = e
		# a shadow rogue is drawn see-through until revealed, the shadow king now and then: both looks
		var ed: Dictionary = DB.ENEMIES[type]
		if ed.get("stealth", false) or ed.get("vanish", false):
			var e2 := Enemy.new()
			root.add_child(e2)
			e2.setup(type, L.paths[0], 1.0)
			e2.process_mode = Node.PROCESS_MODE_DISABLED
			e2.global_position = spots[si % spots.size()]
			si += 1
			e2.set_ghost(0.0 if ed.get("stealth", false) else Enemy.GHOST)
		# the overlays enemies get when hit or frozen are materials of their own
		if k == 1:
			e.model.hit_flash()
		elif k == 2 and e.model.body:
			e.model.body.material_overlay = L.fx.frost_overlay()
		k += 1
	var spawned: Array = [root]
	await _stage(L, tree, "warm:enemies", world_before, fx_before, spawned)
	# every tower at levels 1-3 and each specialisation with its ability, as far as downloaded
	var towers: Array = []
	var groups: Array = [["warm:towers-1", [[1, ""]]], ["warm:towers-2-3", [[2, ""], [3, ""]]], ["warm:masteries", []]]
	for type in ["archer", "barracks", "mage", "artillery"]:
		for m in DB.TOWERS[type]["masteries"]:
			if not (groups[2][1] as Array).has([4, m["id"]]):
				groups[2][1].append([4, m["id"]])
	for g in groups:
		for type in ["archer", "barracks", "mage", "artillery"]:
			for cf in g[1]:
				if cf[1] != "" and not DB.TOWERS[type]["masteries"].any(func(m): return m["id"] == cf[1]):
					continue
				var probe := Tower.new()
				probe.type = type
				var ready := probe.model_ready(mini(int(cf[0]), 3))
				probe.free()
				if not ready:
					continue
				var p: Vector3 = spots[si % spots.size()]
				si += 1
				var tw := Tower.new()
				root.add_child(tw)
				tw.setup(type, Vector2(p.x, p.z))
				for i in mini(int(cf[0]), 3) - 1:
					tw.upgrade()
				if cf[1] != "":
					tw.apply_mastery(cf[1])
					tw.buy_ability()
				tw.process_mode = Node.PROCESS_MODE_DISABLED
				towers.append(tw)
				if dummy:
					_shoot(L, tw, dummy)
		await _stage(L, tree, g[0], world_before, fx_before, spawned)
	# meteors (the spell) and every effect
	Projectile.meteor(spots[0], 0.0, 2.5, 0.0)
	_effects(L, spots, dummy)
	await _stage(L, tree, "warm:effects", world_before, fx_before, spawned)
	# the build ring, its range circle and the tower card (2D programs as well as 3D)
	if not L.plots.is_empty():
		var tut := L.tutorial_step
		L.tutorial_step = -1  # selecting a plot would clear the first battle's tutorial hint
		L._select_plot(0)
		L._on_radial_preview("build_archer")
		L.tutorial_step = tut
	if L.hero:
		L.hero.set_selected(true)
	_collect(L, world_before, fx_before, spawned, root)
	if staged:
		print("NEWTHING t=0.0 warm:rings")
	var omni := OmniLight3D.new()
	omni.omni_range = 40.0
	omni.light_energy = 0.4
	omni.shadow_enabled = false
	root.add_child(omni)
	omni.global_position = spots[0] + Vector3(0, 3.0, 0)
	for i in LIT_FRAMES:
		await tree.process_frame
	if not _alive(L):
		_finish(tree, t0, was_paused, was_muted, hits_before)
		return
	if staged:
		print("NEWTHING t=0.0 warm:unlit")
	omni.visible = false
	# short effects (lightning, sparks) are gone by now: fire them again for the unlit variants
	_effects(L, spots, dummy)
	for c in L.fx.get_children():
		if not fx_before.has(c) and not spawned.has(c):
			spawned.append(c)
	for i in DARK_FRAMES:
		await tree.process_frame
	if not _alive(L):
		_finish(tree, t0, was_paused, was_muted, hits_before)
		return
	# the whole map from above, lit and unlit: things away from the start view (map event markers,
	# decor at the far end) compile now too, not when the camera first pans to them
	if staged:
		print("NEWTHING t=0.0 warm:overview")
	var rig := L.cam_rig
	var keep := [rig.target, rig.zoom, rig.free]
	var b: Rect2 = rig.bounds
	rig.free = true
	rig.target = Vector3(b.get_center().x, 0.0, b.get_center().y)
	rig.zoom = maxf(b.size.x, b.size.y) * 1.5
	rig._apply(0.0)
	omni.omni_range = maxf(b.size.x, b.size.y) * 1.2
	omni.global_position = rig.target + Vector3(0, 6.0, 0)
	omni.visible = true
	for i in OVERVIEW_FRAMES:
		await tree.process_frame
		omni.visible = false
	if is_instance_valid(rig):
		rig.target = keep[0]
		rig.zoom = keep[1]
		rig.free = keep[2]
		rig._apply(0.0)
	# put everything back as it was
	if _alive(L):
		for tw in towers:
			if is_instance_valid(tw):
				(tw as Tower).remove()
		for c in spawned:
			if is_instance_valid(c):
				if c is Soldier:
					L.soldiers.erase(c)
				(c as Node).queue_free()
		L.fx._lights = 0
		L._deselect()
		L.fx.process_mode = fx_mode
		L.cam_rig._shake = 0.0
	_finish(tree, t0, was_paused, was_muted, hits_before)

## Shots and soldiers spawned into the world are held still (their trails keep drawing) and
## remembered for removal; only what the warm-up spawned is removed, anything else added
## meanwhile stays.
static func _collect(L: LevelMain, world_before: Dictionary, fx_before: Dictionary, spawned: Array, root: Node) -> void:
	for c in L.world.get_children():
		if world_before.has(c) or c == root or spawned.has(c):
			continue
		spawned.append(c)
		if c is Projectile:
			c.process_mode = Node.PROCESS_MODE_DISABLED
			for pt in c.find_children("*", "CPUParticles3D", true, false):
				pt.process_mode = Node.PROCESS_MODE_ALWAYS
	for c in L.fx.get_children():
		if not fx_before.has(c) and not spawned.has(c):
			spawned.append(c)

static func _stage(L: LevelMain, tree: SceneTree, label: String, world_before: Dictionary, fx_before: Dictionary, spawned: Array) -> void:
	if not staged:
		return
	_collect(L, world_before, fx_before, spawned, spawned[0])
	print("NEWTHING t=0.0 " + label)
	for i in LIT_FRAMES:
		await tree.process_frame

static func _alive(L: Object) -> bool:
	return is_instance_valid(L) and L.is_inside_tree()

static func _finish(tree: SceneTree, t0: int, was_paused: bool, was_muted: bool, hits_before: Dictionary) -> void:
	Tower.ability_hits = hits_before
	AudioServer.set_bus_mute(0, was_muted)
	tree.paused = was_paused
	print("RB_WARMUP %d ms" % (Time.get_ticks_msec() - t0))
	Game.mark("shader_warmup_done")

## Places in view around where the camera looks (things outside the view are culled, not drawn,
## and would not compile).
static func _spots(L: LevelMain) -> Array:
	var c: Vector3 = L.cam_rig.target
	var out: Array = []
	for ring: float in [0.0, 2.6, 5.2, 7.8]:
		var n := 1 if ring == 0.0 else int(ring * 2.4)
		for i in n:
			var a := TAU * float(i) / float(n)
			var x: float = c.x + cos(a) * ring
			var z: float = c.z + sin(a) * ring * 0.7
			out.append(Vector3(x, L.terrain.height_at(x, z), z))
	return out

## One shot of the kind this tower fires (the shot's own material, trail and ability tint).
static func _shoot(L: LevelMain, tw: Tower, tgt: Enemy) -> void:
	var from := tw.global_position + Vector3(0, 3.0, 0)
	match tw.type:
		"archer":
			Projectile.arrow(from, tgt, 0.0, tw.ability == "", 0.0, tw.ability)
		"mage":
			var c := Color(0.5, 0.9, 1.0) if tw.mastery == "frost" else Color(0.75, 0.45, 1.0)
			Projectile.bolt(from, tgt, 0.0, c, 0.0, 0.0, tw.ability)
			if tw.mastery == "arcane":
				L.fx.lightning(from, tgt.aim_point(), Color(0.6, 0.8, 1.0))
		"artillery":
			Projectile.bomb(from, tgt.global_position, 0.0, 2.0, 1.0 if tw.mastery != "" else 0.0, 0, false, tw.ability)
			Projectile.bomb(from, tgt.global_position, 0.0, 1.0, 0.0, 0, true, tw.ability)

static func _effects(L: LevelMain, spots: Array, dummy: Enemy) -> void:
	var fx := L.fx
	var p: Vector3 = spots[0] + Vector3(0, 0.5, 0)
	var calls: Array = [
		func(): fx.light_flash(p, Color(1, 0.6, 0.3), 3.0, 8.0, 0.4),
		func(): fx.hit_spark(p, Color(1, 0.8, 0.4)),
		func(): fx.magic_burst(p, Color(0.6, 0.4, 1.0)),
		func(): fx.heal(p),
		func(): fx.burn_puff(p),
		func(): fx.dust(p),
		func(): fx.smoke(p),
		func(): fx.muzzle_flash(p, Vector3.FORWARD),
		func(): fx.explosion(p),
		func(): fx.telegraph(p, 2.0, 0.6, Color(1, 0.3, 0.2)),
		func(): fx.firework(p, Color(1, 0.8, 0.3)),
		func(): fx.shockwave(p, 3.0, Color(0.6, 0.8, 1.0)),
		func(): fx.fire_ring(p, 2.0),
		func(): fx.slash_arc(p, Color(1, 1, 1)),
		func(): fx.build_poof(p),
		func(): fx.upgrade_beam(p),
		func(): fx.move_marker(p),
		func(): fx.frost_nova(p, 2.5),
		func(): fx.ice_shards(p, 2.5),
		func(): fx.rune_circle(p, Color(0.5, 0.8, 1.0)),
		func(): fx.charge(p, Color(0.5, 0.8, 1.0)),
		func(): fx.lightning(p + Vector3(0, 4, 0), p, Color(0.6, 0.8, 1.0)),
		func(): fx.scorch(p, 1.5),
		func(): fx.soul(p),
		func(): fx.coin_burst(p),
		func(): fx.fire_patch(p, 1.5, 0.0),
		# a bird of the level's flock (AmbientLife): its wing-beat shader is compiled here, not when
		# the first flock flies over in battle
		func(): fx.add_child(AmbientLife.probe(L.ambient_kind(), p + Vector3(0, 2, 0))),
	]
	if dummy:
		calls.append(func(): fx.level_up(dummy))
		calls.append(func(): fx.stun_stars(dummy))
	for c in calls:
		(c as Callable).call()
