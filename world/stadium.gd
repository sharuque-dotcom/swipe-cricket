class_name Stadium
extends Node3D
## Builds the whole ground in code: outfield, pitch, creases, rope, boards, stands, sky and sun.

var batter_stumps: Stumps
var crowd_material: ShaderMaterial
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _pitch_mat: ShaderMaterial
var _backdrop_mat: ShaderMaterial
var _lights: Array[Node3D] = []
var sight_screen: MeshInstance3D

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
	_sky_mat = sky_mat
	# Horizon matches the hazy sky in the stadium photo so the backdrop blends in.
	sky_mat.sky_top_color = Color(0.42, 0.62, 0.90)
	sky_mat.sky_horizon_color = Color(0.82, 0.87, 0.91)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.12, 0.30, 0.14)
	sky_mat.ground_horizon_color = Color(0.70, 0.78, 0.74)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A fixed ambient colour and no sky reflections: predictable on every phone GPU,
	# and matte surfaces stop mirroring the sky at grazing angles.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.73, 0.86)
	env.ambient_light_energy = 0.78
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	# A little haze over the far side of the ground, like a broadcast camera sees it.
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.85, 0.90)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 0.72
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
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
	sm.set_shader_parameter("detail", load("res://world/tex/grass_detail.jpg"))
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

## Size of the pitch photo in metres (grass fringe included). Its stump lines are at
## z = 0 and z = BOWLER_STUMPS_Z, and its crease markings are painted in the photo.
const PITCH_PHOTO_HALF_WIDTH := 1.63
const PITCH_PHOTO_Z0 := Pitch.BOWLER_STUMPS_Z - Pitch.CREASE
const PITCH_PHOTO_Z1 := Pitch.CREASE

func _pitch() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(PITCH_PHOTO_HALF_WIDTH * 2.0, PITCH_PHOTO_Z1 - PITCH_PHOTO_Z0)
	mi.mesh = pm
	mi.position = Vector3(0, 0.004, (PITCH_PHOTO_Z0 + PITCH_PHOTO_Z1) * 0.5)
	var sm := _shader("res://world/pitch.gdshader")
	sm.set_shader_parameter("albedo_tex", load("res://world/tex/pitch.jpg"))
	sm.set_shader_parameter("half_width", PITCH_PHOTO_HALF_WIDTH)
	sm.set_shader_parameter("z_start", PITCH_PHOTO_Z0)
	sm.set_shader_parameter("z_end", PITCH_PHOTO_Z1)
	_pitch_mat = sm
	mi.material_override = sm
	add_child(mi)

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
	_backdrop()
	# Sight screen behind the bowler: white for a red ball, black for a white one.
	sight_screen = _box(Vector3(14, 7, 0.4), Vector3(0, 3.5, Pitch.FIELD_CENTRE.z - 67.5), Color(0.95, 0.95, 0.95), 1.0)

## Size and place of the stadium photo: a card standing just behind the far boards.
## Sized for the batting camera: it fills the view with roof, floodlights and two packed
## tiers. Turning the camera far to either side shows the built-in stands it fades into.
const BACKDROP_SIZE := Vector2(46.0, 33.7)
const BACKDROP_DIST := 71.5

func _backdrop() -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = BACKDROP_SIZE
	mi.mesh = qm
	mi.position = Vector3(0, 1.3 + BACKDROP_SIZE.y * 0.5, Pitch.FIELD_CENTRE.z - BACKDROP_DIST)
	var sm := _shader("res://world/backdrop.gdshader")
	sm.set_shader_parameter("photo", load("res://world/tex/stadium.jpg"))
	sm.set_shader_parameter("top_fade", 0.06)
	_backdrop_mat = sm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The pitch's colour for its type, and day or night: under lights the sky goes dark, the
## floodlights come on and light the ground from high above.
func set_conditions(pitch: String, night: bool) -> void:
	var p := Conditions.info(pitch)
	_pitch_mat.set_shader_parameter("tint", p.tint)
	_pitch_mat.set_shader_parameter("grass", 1.0 if pitch == "green" else (0.25 if pitch == "good" else 0.0))
	if _lights.is_empty():
		_build_floodlights()
	for l in _lights:
		l.visible = night
	if night:
		_sky_mat.sky_top_color = Color(0.015, 0.025, 0.07)
		_sky_mat.sky_horizon_color = Color(0.10, 0.12, 0.20)
		_sky_mat.ground_horizon_color = Color(0.10, 0.12, 0.16)
		_env.ambient_light_color = Color(0.62, 0.68, 0.85)
		_env.ambient_light_energy = 0.75
		_env.fog_light_color = Color(0.10, 0.12, 0.18)
		_sun.rotation_degrees = Vector3(-72.0, 14.0, 0.0)
		_sun.light_color = Color(0.94, 0.97, 1.0)
		_sun.light_energy = 1.05
		_backdrop_mat.set_shader_parameter("tint", Color(0.48, 0.52, 0.66))
		crowd_material.set_shader_parameter("lit", 0.62)
		_env.tonemap_exposure = 1.18
	else:
		_sky_mat.sky_top_color = Color(0.42, 0.62, 0.90)
		_sky_mat.sky_horizon_color = Color(0.82, 0.87, 0.91)
		_sky_mat.ground_horizon_color = Color(0.70, 0.78, 0.74)
		_env.ambient_light_color = Color(0.66, 0.73, 0.86)
		_env.ambient_light_energy = 0.78
		_env.fog_light_color = Color(0.80, 0.85, 0.90)
		_sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
		_sun.light_color = Color(1.0, 0.96, 0.88)
		_sun.light_energy = 0.72
		_backdrop_mat.set_shader_parameter("tint", Color(1, 1, 1))
		crowd_material.set_shader_parameter("lit", 1.0)
		_env.tonemap_exposure = 1.05

## Four floodlight towers round the ground, with a glow at the top of each.
func _build_floodlights() -> void:
	var glow_tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.98, 0.9, 0.55), Color(1, 1, 1, 0)])
	glow_tex.gradient = g
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	for a in [45.0, 135.0, 225.0, 315.0]:
		var root := Node3D.new()
		var r := deg_to_rad(a)
		root.position = Pitch.FIELD_CENTRE + Vector3(cos(r), 0, sin(r)) * 96.0
		add_child(root)
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 1.0
		cm.height = 46.0
		pole.mesh = cm
		pole.position.y = 23.0
		pole.material_override = Figure.mat(Color(0.25, 0.27, 0.32))
		root.add_child(pole)
		var head := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(10, 6, 1.2)
		head.mesh = bm
		head.position.y = 48.0
		head.rotation.y = -r + PI * 0.5
		head.material_override = Figure.mat(Color(0.95, 0.96, 1.0))
		root.add_child(head)
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(34, 34)
		glow.mesh = q
		glow.position.y = 48.0
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = glow_tex
		m.albedo_color = Color(1.0, 0.97, 0.88, 0.9)
		m.disable_fog = true
		glow.material_override = m
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glow)
		pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.visible = false
		_lights.append(root)


## White-ball cricket (a match) has a black sight screen; the red ball (nets) a white one.
func set_white_ball(white: bool) -> void:
	sight_screen.material_override = Figure.mat(Color(0.06, 0.07, 0.10) if white else Color(0.95, 0.95, 0.95), 1.0)
