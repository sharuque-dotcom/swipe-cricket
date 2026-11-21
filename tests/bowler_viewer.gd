extends SceneTree
## Renders each bowling action from side-on at six moments through the run-up and delivery,
## with a red dot where the ball is let go. Needs a display (or xvfb-run):
##   godot --path . --resolution 300x400 -s tests/bowler_viewer.gd -- OUT_DIR
const TIMES := [-0.42, -0.25, -0.12, 0.0, 0.2]

func _initialize() -> void:
	_run()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.85)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = Figure.mat(Color(0.35, 0.55, 0.3))
	ground.position = Vector3(0, 0, Pitch.BOWLER_CREASE_Z)
	root.add_child(ground)
	var b := Bowler.new()
	b.rotation.y = PI
	root.add_child(b)
	b.build(Color(0.80, 0.14, 0.16), Color(1, 1, 1))
	b.set_process(false)
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	dot.mesh = sm
	dot.material_override = Figure.mat(Color(0.9, 0.05, 0.05))
	root.add_child(dot)
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 45
	root.add_child(cam)
	for name in BowlerProfile.ALL:
		var p := BowlerProfile.of(name)
		b.set_action(str(p.action), str(p.arm) == "L", BowlerProfile.is_spin(str(p.style)))
		var rel: Vector3 = p.release
		var r := Vector3(rel.x, rel.y, Pitch.BOWLER_CREASE_Z + rel.z)
		b.place_for(r)
		dot.position = r
		for view in ["side", "front"]:
			if view == "side":
				# Side-on from the off side.
				cam.look_at_from_position(Vector3(5.0, 1.4, r.z + 0.2), Vector3(r.x, 1.2, r.z + 0.4))
			else:
				# From the batter's end, as the batter sees it.
				cam.look_at_from_position(Vector3(0.0, 1.6, r.z + 4.2), Vector3(r.x * 0.5, 1.35, r.z))
			for t in TIMES:
				b.pose_at(t)
				dot.visible = is_zero_approx(t)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s_%s_%+04d.png" % [out, name.replace(". ", "_"), view, int(t * 100)])
	quit()
