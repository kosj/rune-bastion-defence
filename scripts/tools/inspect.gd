extends SceneTree
func _init():
	for n in ["res://assets/characters/hero.glb", "res://assets/models/archer_3.glb", "res://assets/characters/gargoyle.glb"]:
		var ps: PackedScene = load(n)
		var inst = ps.instantiate()
		print("== ", n)
		_dump(inst, 0)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = mi.mesh
			for s in m.get_surface_count():
				var mat = m.surface_get_material(s)
				if mat is StandardMaterial3D:
					print("  surf", s, " vcol=", mat.vertex_color_use_as_albedo, " tex=", mat.albedo_texture, " emis=", mat.emission_enabled, " aabb=", m.get_aabb())
				break
		inst.free()
	quit()
func _dump(n, d):
	if d > 3: return
	var extra = ""
	if n is AnimationPlayer: extra = str(n.get_animation_list())
	if n is Skeleton3D: extra = "bones=%d" % n.get_bone_count()
	if n is Node3D: extra += " pos=%s rot=%s scale=%s" % [n.position, n.rotation_degrees, n.scale]
	print("  ".repeat(d), n.name, " <", n.get_class(), "> ", extra)
	for c in n.get_children(): _dump(c, d + 1)
