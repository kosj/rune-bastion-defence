class_name TitleLife
extends Node3D
## The title diorama at work, so the screen never stands still:
##  - every so often a raiding party (goblins, now and then an orc) runs in from the right across
##    the castle's foreground; the mage tower and the archers shoot it down (arcing arrows, magic
##    bolts, hit sparks) and the raiders fall one by one
##  - when the last one falls, the hero and the footmen cheer
##  - flocks of birds cross the sky behind the castle
## Cosmetic only. Nothing spawns while the 3D view is switched off (the world map covers it).

# (in front of the mage tower and behind the footmen, so every raider stays in the open)
const START := Vector3(15.5, 0, 0.6)     # off the right edge
const END := Vector3(-4.5, 0, -3.6)      # the castle's foreground, left of centre
const RAID_GAP := Vector2(4.0, 7.0)     # seconds between two raids
const BOLT_COL := Color(0.72, 0.45, 1.0)
const BOLT_HEAD := Color(0.85, 0.7, 1.0, 0.75)
# under the ground island, on the camera's side of its far rim: drawn (so compiled) but hidden
# behind the island's top, from every pose the title camera takes
const HIDE_AT := Vector3(1.0, -3.2, -10.0)

var fx: FX
var pool: Array[CharacterModel] = []      # raiders, built hidden by the menu
var archers: Array[CharacterModel] = []   # the archer tower's two units
var archer_from: Array[Vector3] = []
var mage: CharacterModel
var mage_from := Vector3.ZERO
var cheer: Array[CharacterModel] = []     # the hero and the footmen

var armed := false        # set by the menu once the whole diorama is built
var _next := 3.0
var _warmed := false
var _cheered := false
var _raid: Array = []     # [{m, hp, d (distance along the route), side, speed, dead_t}]
var _shots: Array = []    # [{node, from, raider, to, t, dur, arc, kind}]
var _mage_cd := 0.6
var _arch_cd := 0.0
var _arch_i := 0
var _unit_t := {}         # tower unit -> seconds until it goes back to idle
var _cheer_t := -1.0
var _bird_next := 5.0
var _flocks: Array = []
static var _bolt_mesh: SphereMesh
static var _bolt_mat: StandardMaterial3D

func _route_len() -> float:
	return START.distance_to(END)

## Everything the raid draws, drawn once out of sight so its programs are compiled before the first
## raid (the web has no shader cache: a first arrow would otherwise stutter). Runs the first time
## the diorama is on screen (the world map may cover it when it is built).
func _warm() -> void:
	for m in pool:
		m.visible = true
		m.position = HIDE_AT
		m.play("run")
	pool[0].hit_flash()
	var a := Assets.instance("p_arrow")
	a.position = HIDE_AT
	add_child(a)
	var b := _bolt_node(HIDE_AT)
	var tr := fx.trail(b, BOLT_COL, 0.24, false, BOLT_HEAD)
	var bird := AmbientLife.probe("bird", HIDE_AT)
	add_child(bird)
	fx.magic_burst(HIDE_AT, BOLT_COL, 0.8)
	fx.hit_spark(HIDE_AT, Color(1, 0.95, 0.8), 0.6)
	for i in 3:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	fx.detach_trail(tr)
	a.queue_free()
	b.queue_free()
	bird.queue_free()
	for m in pool:
		m.visible = false

func _process(delta: float) -> void:
	var shown := not get_viewport().disable_3d
	if not _warmed:
		if shown and armed:
			_warmed = true
			_warm()
		return
	_next -= delta
	if _next <= 0.0 and _raid.is_empty() and shown:
		_start_raid()
	_move_raid(delta)
	_fire(delta)
	_move_shots(delta)
	for u in _unit_t.keys():
		_unit_t[u] -= delta
		if _unit_t[u] <= 0.0:
			_unit_t.erase(u)
			if is_instance_valid(u):
				(u as CharacterModel).play("idle")
				_turn(u, float(u.get_meta("yaw0", 0.0)))
	if _cheer_t >= 0.0:
		_cheer_t -= delta
		if _cheer_t < 0.0:
			for c in cheer:
				if is_instance_valid(c):
					c.play("idle")
	_bird_next -= delta
	if _bird_next <= 0.0 and shown:
		_bird_next = randf_range(11.0, 19.0)
		_spawn_flock()
	_move_flocks(delta)

# ---------------------------------------------------------------- the raid

func _start_raid() -> void:
	var goblins: Array = []
	var orcs: Array = []
	for m in pool:
		(orcs if m.model_name == "orc" else goblins).append(m)
	goblins.shuffle()
	var party: Array = goblins.slice(0, randi_range(2, 3))
	if randf() < 0.6 and not orcs.is_empty():
		party.insert(randi_range(0, party.size()), orcs[0])
	_cheered = false
	var d := 0.0
	for m: CharacterModel in party:
		var orc := m.model_name == "orc"
		var r := {"m": m, "hp": 6 if orc else 3, "d": d, "side": randf_range(-0.9, 0.9),
			"speed": 1.9 if orc else 2.5, "dead_t": -1.0}
		d -= randf_range(1.3, 1.9)
		m.visible = true
		m.play("run", 0.8 if orc else 1.1, 0.0)
		_raid.append(r)
		_place(r)

func _place(r: Dictionary) -> void:
	var m: CharacterModel = r["m"]
	var dir := (END - START).normalized()
	var side := Vector3(-dir.z, 0, dir.x) * float(r["side"])
	var p := START + dir * maxf(float(r["d"]), -6.0) + side
	m.position = p
	m.rotation.y = atan2(dir.x, dir.z)

func _aim(r: Dictionary) -> Vector3:
	var m: CharacterModel = r["m"]
	return m.position + Vector3(0, 1.4 if m.model_name == "orc" else 0.8, 0)

func _move_raid(delta: float) -> void:
	var L := _route_len()
	var alive := 0
	for r in _raid:
		var m: CharacterModel = r["m"]
		if float(r["dead_t"]) >= 0.0:
			# fallen: lie still a moment, then sink into the ground
			r["dead_t"] = float(r["dead_t"]) + delta
			var t := float(r["dead_t"]) - m.anim_length("death") - 0.6
			if t > 0.0:
				m.position.y = -t * 1.6
				if t > 0.9:
					m.visible = false
			continue
		alive += 1
		r["d"] = float(r["d"]) + float(r["speed"]) * delta
		if float(r["d"]) >= L:
			_kill(r)  # (the towers always win on the title screen)
		_place(r)
	if _raid.is_empty():
		return
	if alive == 0 and not _cheered:
		_cheered = true
		_do_cheer()
	if not _raid.any(func(x): return (x["m"] as CharacterModel).visible):
		_raid.clear()
		_next = randf_range(RAID_GAP.x, RAID_GAP.y)

func _kill(r: Dictionary) -> void:
	if float(r["dead_t"]) >= 0.0:
		return
	r["dead_t"] = 0.0
	var m: CharacterModel = r["m"]
	m.play("death2" if m.has("death2") and randf() < 0.5 else "death", 1.0, 0.05, true)

func _hit(r: Dictionary, n: int) -> void:
	if float(r["dead_t"]) >= 0.0:
		return
	r["hp"] = int(r["hp"]) - n
	var m: CharacterModel = r["m"]
	m.hit_flash()
	if int(r["hp"]) <= 0:
		_kill(r)

func _do_cheer() -> void:
	_cheer_t = 0.0
	for c in cheer:
		if is_instance_valid(c) and c.has("cheer"):
			c.play("cheer", randf_range(0.95, 1.1), 0.15, true)
			_cheer_t = maxf(_cheer_t, c.anim_length("cheer"))

## The raider a tower shoots at: the front-most living one in its reach.
func _target(min_x: float, max_x: float) -> Dictionary:
	var best := {}
	for r in _raid:
		if float(r["dead_t"]) >= 0.0 or float(r["d"]) < 0.5:
			continue
		var x := (r["m"] as CharacterModel).position.x
		if x < min_x or x > max_x:
			continue
		# shots already on their way count as hits: no overkill on a goblin with one life left
		var incoming := 0
		for s in _shots:
			if s["raider"] == r:
				incoming += 1
		if incoming >= int(r["hp"]):
			continue
		if best.is_empty() or float(r["d"]) > float(best["d"]):
			best = r
	return best

# ---------------------------------------------------------------- the towers' shots

func _fire(delta: float) -> void:
	_mage_cd -= delta
	_arch_cd -= delta
	if _mage_cd <= 0.0 and mage:
		var r := _target(-3.0, 12.0)
		if not r.is_empty():
			_mage_cd = 1.6
			_shoot("bolt", mage_from, r)
			_unit_attack(mage, _aim(r))
	if _arch_cd <= 0.0 and not archers.is_empty():
		var r2 := _target(-6.0, 8.0)
		if not r2.is_empty():
			_arch_cd = 0.5
			_arch_i = (_arch_i + 1) % archers.size()
			_shoot("arrow", archer_from[_arch_i], r2)
			_unit_attack(archers[_arch_i], _aim(r2))

## A tower's crew member turns to its target and looses; back to its post (and idle) after.
func _unit_attack(u: CharacterModel, at: Vector3) -> void:
	if not u.has_meta("yaw0"):
		u.set_meta("yaw0", u.global_rotation.y)
	var d := at - u.global_position
	_turn(u, atan2(d.x, d.z))
	if u.has("attack"):
		u.play("attack", 1.3, 0.05, true)
		_unit_t[u] = u.anim_length("attack") / 1.3 + 0.5

func _turn(u: Node3D, yaw: float) -> void:
	var from := u.global_rotation.y
	var tw := u.create_tween()
	tw.tween_method(func(y: float): u.global_rotation = Vector3(0, y, 0), from, from + wrapf(yaw - from, -PI, PI), 0.14)

func _shoot(kind: String, from: Vector3, r: Dictionary) -> void:
	var to := _aim(r)
	var dist := from.distance_to(to)
	var s := {"from": from, "raider": r, "to": to, "t": 0.0, "kind": kind}
	if kind == "arrow":
		var a := Assets.instance("p_arrow")
		a.scale = Vector3.ONE * 1.3
		a.position = from
		add_child(a)
		s["node"] = a
		s["dur"] = clampf(dist / 20.0, 0.35, 0.8)
		s["arc"] = dist * 0.14
		_point(a, to - from + Vector3(0, 4.0 * float(s["arc"]), 0))
	else:
		var b := _bolt_node(from)
		s["node"] = b
		s["dur"] = clampf(dist / 13.0, 0.4, 0.9)
		s["arc"] = 1.2
		s["trail"] = fx.trail(b, BOLT_COL, 0.24, false, BOLT_HEAD)
	_shots.append(s)

## (placed before it enters the tree: a trail made on a node still at the origin leaves a puff
## of its first particles there)
func _bolt_node(at: Vector3) -> Node3D:
	if _bolt_mesh == null:
		_bolt_mesh = SphereMesh.new()
		_bolt_mesh.radius = 0.2
		_bolt_mesh.height = 0.4
		_bolt_mesh.radial_segments = 10
		_bolt_mesh.rings = 6
		_bolt_mat = StandardMaterial3D.new()
		_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bolt_mat.albedo_color = BOLT_COL.lightened(0.25)
		_bolt_mat.emission_enabled = true
		_bolt_mat.emission = BOLT_COL
		# (dimmer than the battle's bolts: the title camera is close, a bright one blooms into a
		# white ball)
		_bolt_mat.emission_energy_multiplier = 2.2
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _bolt_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	n.position = at
	add_child(n)
	return n

func _move_shots(delta: float) -> void:
	var keep: Array = []
	for s in _shots:
		var n: Node3D = s["node"]
		var r: Dictionary = s["raider"]
		if float(r["dead_t"]) < 0.0:
			s["to"] = _aim(r)  # (homing, like the battle's arrows)
		s["t"] = float(s["t"]) + delta
		var k := clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
		var p: Vector3 = (s["from"] as Vector3).lerp(s["to"], k)
		p.y += float(s["arc"]) * 4.0 * k * (1.0 - k)
		var prev := n.position
		n.position = p
		if s["kind"] == "arrow":
			var dir := p - prev
			_point(n, dir)
		if k >= 1.0:
			if s["kind"] == "arrow":
				fx.hit_spark(p, Color(1, 0.95, 0.8), 0.7)
				_hit(r, 1)
			else:
				fx.magic_burst(p, BOLT_COL, 0.8)
				_hit(r, 1)
			if s.has("trail"):
				fx.detach_trail(s["trail"])
			n.queue_free()
		else:
			keep.append(s)
	_shots = keep

## An arrow along its flight (the model points up its Y axis, like the battle's arrows).
func _point(n: Node3D, dir: Vector3) -> void:
	if dir.length_squared() < 0.00001:
		return
	n.look_at(n.global_position + dir, Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT)
	n.rotate_object_local(Vector3.RIGHT, -PI * 0.5)

# ---------------------------------------------------------------- birds

## A loose V of birds crossing the sky behind the castle, one way or the other.
func _spawn_flock() -> void:
	var dir := 1.0 if randf() < 0.5 else -1.0
	var root := Node3D.new()
	var z := randf_range(-24.0, -32.0)
	root.position = Vector3(-34.0 * dir, randf_range(9.0, 12.5), z)
	root.rotation.y = atan2(-dir, 0.0)
	add_child(root)
	var n := randi_range(4, 7)
	var offs := []
	for i in n:
		var row := (i + 1) / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var off := Vector3(side * row * 1.1, randf_range(-0.4, 0.4), row * 1.3) if i > 0 else Vector3.ZERO
		offs.append(off)
		var b := MeshInstance3D.new()
		b.mesh = AmbientLife._bird_mesh(1.3)
		b.material_override = AmbientLife._material("bird")
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = off
		root.add_child(b)
	_flocks.append({"root": root, "v": Vector3(6.0 * dir, 0.25, 0), "t": 0.0, "offs": offs})

func _move_flocks(delta: float) -> void:
	var keep: Array = []
	for f in _flocks:
		var root: Node3D = f["root"]
		if not is_instance_valid(root):
			continue
		root.position += f["v"] * delta
		f["t"] = float(f["t"]) + delta
		var t := float(f["t"])
		for i in root.get_child_count():
			(root.get_child(i) as Node3D).position = f["offs"][i] + Vector3(0, sin(t * 1.4 + i * 1.7) * 0.3, 0)
		if absf(root.position.x) > 36.0 and t > 2.0:
			root.queue_free()
		else:
			keep.append(f)
	_flocks = keep
