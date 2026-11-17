extends SceneTree
## Renders each batting style at four moments (mid-swing, contact, follow-through, finish)
## so animation changes can be checked by eye. Needs a display (or xvfb-run):
##   godot --path . --resolution 400x500 -s tests/pose_viewer.gd -- OUT_DIR [style]
var SHOTS := [
	["drive", Vector3(0.1, 0.35, -1.4), 20.0], ["loft_drive", Vector3(0.1, 0.4, -1.5), 0.0],
	["step_out", Vector3(0.1, 0.5, -1.9), 0.0], ["helicopter", Vector3(0.05, 0.2, -1.3), -15.0],
	["cut", Vector3(0.5, 0.8, -0.9), 95.0], ["upper_cut", Vector3(0.45, 1.3, -0.8), 110.0],
	["pull", Vector3(0.1, 1.0, -0.9), -80.0], ["one_leg_pull", Vector3(0.1, 1.05, -0.95), -70.0],
	["hook", Vector3(0.0, 1.5, -0.8), -110.0], ["sweep", Vector3(0.1, 0.3, -1.6), -100.0],
	["slog_sweep", Vector3(0.1, 0.35, -1.6), -70.0], ["reverse_sweep", Vector3(0.2, 0.3, -1.6), 100.0],
	["scoop", Vector3(0.05, 0.4, -1.3), 175.0], ["flick", Vector3(0.0, 0.6, -1.2), -60.0],
	["milestone", Vector3.ZERO, 0.0], ["win", Vector3.ZERO, 0.0]]
const TIMES := [0.07, 0.12, 0.45, 0.95]

func _initialize() -> void:
	_run()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var only := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
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
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	ground.material_override = Figure.mat(Color(0.75, 0.65, 0.48))
	root.add_child(ground)
	var stumps := Stumps.new()
	root.add_child(stumps)
	stumps.build()
	var b := Batter.new()
	root.add_child(b)
	b.build(Color(0.10, 0.32, 0.78), Color(1.0, 0.80, 0.15))
	b.set_process(false)
	var ballm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	ballm.mesh = sm
	ballm.material_override = Figure.mat(Color(0.8, 0.05, 0.05))
	root.add_child(ballm)
	var cam := Camera3D.new()
	cam.fov = 50
	root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(3.0, 1.45, -3.4), Vector3(-0.25, 0.95, -1.1))
	for sh in SHOTS:
		if only != "" and sh[0] != only:
			continue
		for t in TIMES:
			b.phase = Batter.Phase.STANCE
			b._update(0.6)
			b.backlift()
			b._update(0.3)
			ballm.position = sh[1]
			ballm.visible = sh[1] != Vector3.ZERO
			if sh[0] in ["milestone", "win"]:
				b.celebrate(sh[0])
			else:
				b.swing(sh[1], deg_to_rad(sh[2]), sh[0])
			var left: float = t
			while left > 0.0:
				b._update(minf(left, 0.02))
				left -= 0.02
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%03d.png" % [out, sh[0], int(t * 100)])
	quit()
