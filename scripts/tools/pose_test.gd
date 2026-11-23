extends Node3D
## Renders a lineup of characters/animations from the front (+Z) for visual checks.

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -20, 0)
	add_child(sun)
	var spec := [["ogre", "roar", 1.9, ""], ["sera", "run", 1.9, ""], ["sapper", "attack", 1.9, ""], ["sera", "attack", 1.9, ""]]
	var i := 0
	for s in spec:
		var cm := CharacterModel.new()
		add_child(cm)
		cm.setup(s[0], s[2], Color.WHITE, s[3])
		cm.position = Vector3(-3.0 + i * 2.0, 0, 0)
		cm.play(s[1], 0.0001)
		cm.anim.seek(0.55, true)
		i += 1
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = Vector3(0, 1.4, 7.5)
	cam.look_at(Vector3(0, 1.0, 0))
	for k in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/pose.png")
	print("POSE DONE")
	get_tree().quit()
