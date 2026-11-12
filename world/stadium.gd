class_name Stadium
extends Node3D
## Builds the whole ground in code: outfield, pitch, creases, rope, boards, stands, sky and sun.

var batter_stumps: Stumps
var crowd_material: ShaderMaterial

func build() -> void:
	_sky()
	_ground()
	_pitch()
	_ring()
	batter_stumps = Stumps.new()
	add_child(batter_stumps)
	batter_stumps.build()
	var far := Stumps.new()
	far.position.z = Pitch.BOWLER_STUMPS_Z
	add_child(far)
	far.build()

func _sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.40, 0.82)
	sky_mat.sky_horizon_color = Color(0.66, 0.80, 0.94)
	sky_mat.ground_bottom_color = Color(0.12, 0.30, 0.14)
	sky_mat.ground_horizon_color = Color(0.55, 0.70, 0.60)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A fixed ambient colour and no sky reflections: predictable on every phone GPU,
	# and matte surfaces stop mirroring the sky at grazing angles.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.86)
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 0.62
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

func _ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(420, 420)
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://world/ground.gdshader")
	sm.set_shader_parameter("centre", Pitch.FIELD_CENTRE)
	sm.set_shader_parameter("boundary", Pitch.BOUNDARY_RADIUS)
	mi.material_override = sm
	mi.position = Pitch.FIELD_CENTRE
	add_child(mi)

func _box(size: Vector3, pos: Vector3, c: Color, rough: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Figure.mat(c, rough)
	add_child(mi)
	return mi

func _pitch() -> void:
	var mid := Pitch.BOWLER_STUMPS_Z * 0.5
	_box(Vector3(3.05, 0.02, Pitch.LENGTH + 2.44), Vector3(0, 0.002, mid), Color(0.72, 0.62, 0.42))
	# Scuffed good-length areas.
	_box(Vector3(1.6, 0.021, 5.0), Vector3(0.1, 0.003, -5.5), Color(0.64, 0.54, 0.36))
	_box(Vector3(1.6, 0.021, 5.0), Vector3(-0.1, 0.003, Pitch.BOWLER_STUMPS_Z + 5.5), Color(0.64, 0.54, 0.36))
	var white := Color(0.96, 0.96, 0.94)
	for end_z in [0.0, Pitch.BOWLER_STUMPS_Z]:
		var dir := -1.0 if end_z == 0.0 else 1.0
		_box(Vector3(2.64, 0.022, 0.05), Vector3(0, 0.004, end_z), white)
		_box(Vector3(3.66, 0.022, 0.05), Vector3(0, 0.004, end_z + dir * Pitch.CREASE), white)
		for sx in [-1.32, 1.32]:
			_box(Vector3(0.05, 0.022, 2.44), Vector3(sx, 0.004, end_z + dir * 0.0), white)

func _band(r0: float, y0: float, r1: float, y1: float, material: Material, segs: int = 96) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var p: Array[Vector3] = [
			Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a1) * r0, y0, sin(a1) * r0),
			Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a0) * r1, y1, sin(a0) * r1)]
		var uv: Array[Vector2] = [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
		# Normal faces the middle of the ground (and upward for sloped tiers).
		var n := (p[1] - p[0]).cross(p[3] - p[0]).normalized()
		if n.dot(Vector3(-cos(a0), 0.4, -sin(a0))) < 0.0:
			n = -n
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv[idx])
			st.add_vertex(p[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.position = Pitch.FIELD_CENTRE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _shader(path: String) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load(path)
	return sm

func _flat(c: Color) -> StandardMaterial3D:
	var m := Figure.mat(c, 0.7)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _ring() -> void:
	var rope := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = Pitch.BOUNDARY_RADIUS - 0.14
	tm.outer_radius = Pitch.BOUNDARY_RADIUS + 0.14
	tm.rings = 96
	tm.ring_segments = 6
	rope.mesh = tm
	rope.position = Pitch.FIELD_CENTRE + Vector3(0, 0.1, 0)
	rope.material_override = Figure.mat(Color(0.96, 0.96, 0.96))
	add_child(rope)
	_band(69.0, 0.0, 69.0, 1.3, _shader("res://world/boards.gdshader"))
	crowd_material = _shader("res://world/crowd.gdshader")
	_band(71.0, 2.2, 99.0, 25.0, crowd_material)
	_band(69.0, 1.3, 71.0, 2.2, _flat(Color(0.30, 0.32, 0.38)))
	_band(93.0, 29.0, 104.0, 27.5, _flat(Color(0.34, 0.38, 0.46)))
	_band(99.0, 0.0, 99.0, 28.0, _flat(Color(0.22, 0.25, 0.33)))
	# Sight screen behind the bowler.
	_box(Vector3(14, 7, 0.4), Vector3(0, 3.5, Pitch.FIELD_CENTRE.z - 67.5), Color(0.95, 0.95, 0.95), 1.0)
