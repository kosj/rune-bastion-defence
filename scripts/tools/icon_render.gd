extends Node3D
## Renders tower thumbnails and character portraits to PNG (run under a real renderer).

const OUT := "res://assets/ui/"
var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	_run.call_deferred()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("ICON ", name)

func _clear() -> void:
	for c in holder.get_children():
		c.queue_free()
	await get_tree().process_frame

func _run() -> void:
	var view := OS.get_cmdline_user_args()
	var only: Array = []
	for a in view:
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	# towers
	for t in ["archer", "barracks", "mage", "artillery"]:
		for lv in [1, 2, 3]:
			if not only.is_empty() and not only.has("towers"):
				continue
			await _clear()
			var m := Node3D.new()
			m.add_child(Assets.instance("%s_%d" % [t, lv]))
			var top := ModelMeta.top("%s_%d" % [t, lv])
			if t == "archer":
				for k in 2:
					var u := CharacterModel.new()
					m.add_child(u)
					u.setup("archer_unit", 1.3)
					u.position = Vector3(-0.45 + 0.9 * k, top, 0.15)
					u.play("idle", 0.0001)
			elif t == "mage":
				var mu := CharacterModel.new()
				m.add_child(mu)
				mu.setup("mage_unit", 1.35)
				mu.position = Vector3(0, top, 0.1)
				mu.play("idle", 0.0001)
			holder.add_child(m)
			var aabb := _aabb(m)
			var h := aabb.size.y
			var c := aabb.get_center()
			cam.position = c + Vector3(0.55, 0.6, 1.3).normalized() * (maxf(h, aabb.size.x) * 2.15)
			cam.look_at(c, Vector3.UP)
			await _shot("tower_%s_%d" % [t, lv])
	# characters
	var chars := {"ranger": [1.85, "", "idle"], "sera": [1.8, "", "idle"], "sapper": [1.3, "", "run"], "ogre": [3.0, "", "roar"], "hero": [1.95, "w_sword", "idle"], "goblin": [1.25, "w_dagger", "run"], "shaman": [1.35, "", "run"],
		"orc": [2.2, "w_axe", "run"], "warchief": [2.8, "w_axe", "run"], "troll": [4.2, "w_club", "roar"], "wolf": [1.5, "", ""], "gargoyle": [1.6, "", ""],
		"skeleton": [1.45, "w_dagger", "attack", 0.0, 0.15], "skeleton_knight": [2.1, "", "attack", 0.0, 0.4], "lich": [3.7, "", "run", 0.0, 0.3]}
	for k in chars:
		if not only.is_empty() and not only.has(k):
			continue
		await _clear()
		var model: String = {"shaman": "goblin", "warchief": "orc", "skeleton": "skeleton_knight"}.get(k, k)
		var tint := Color.WHITE
		if DB.ENEMIES.has(k):
			tint = DB.ENEMIES[k].get("tint", Color.WHITE)
		var cm := CharacterModel.new()
		holder.add_child(cm)
		cm.setup(model, chars[k][0], tint, chars[k][1])
		var seek_t: float = chars[k][4] if chars[k].size() > 4 else 0.4
		for a in view:
			if a.begins_with("seek_" + k + "="):
				seek_t = float(a.split("=")[1])
			if a.begins_with("anim_" + k + "="):
				chars[k][2] = a.split("=")[1]
			if a.begins_with("yaw_" + k + "="):
				cm.rotation_degrees.y = float(a.split("=")[1])
		var yaw_set := false
		for a in view:
			if a.begins_with("yaw_" + k + "="):
				yaw_set = true
		if chars[k].size() > 3 and not yaw_set:
			cm.rotation_degrees.y = chars[k][3]
		if chars[k][2] != "":
			cm.play(chars[k][2], 0.0001)
			cm.anim.seek(seek_t, true)
		await get_tree().process_frame
		var aabb := _aabb(cm)
		var top := aabb.end.y
		var c := Vector3(aabb.get_center().x, top - aabb.size.y * 0.3, aabb.get_center().z)
		var dist := aabb.size.y * 1.25
		if k in ["wolf", "gargoyle"]:
			c = aabb.get_center()
			dist = maxf(aabb.size.x, aabb.size.z) * 1.6
		cam.position = c + Vector3(0.35, 0.12, 1.0).normalized() * dist
		cam.look_at(c, Vector3.UP)
		await _shot("portrait_" + k)
	get_tree().quit()

func _aabb(n: Node) -> AABB:
	var first := true
	var box := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a := m.global_transform * m.get_aabb()
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	return box
