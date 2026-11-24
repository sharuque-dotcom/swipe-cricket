class_name Pyro
extends Node3D
## Big Bash theatre: flame cannons along the rope for a six, fireworks over the stands for
## a win or a hundred. Particles only, so it costs nothing until it fires.

## Cannon angles round the ground (degrees, atan2 of z and x from the middle): two pairs
## either side of the sight screen behind the bowler, where the batting camera looks, and
## the rest spread round.
const ANGLES := [-102.0, -78.0, -130.0, -50.0, 0.0, 180.0, 60.0, 120.0]
const CANNONS := 8
const ROPE := 67.5

var _flames: Array[CPUParticles3D] = []
var _flame_left: Array[float] = []
var _works: Array[CPUParticles3D] = []
var _next_work := 0
var _rng := RandomNumberGenerator.new()

func build() -> void:
	_rng.seed = 7
	var soft := _soft_texture()
	for i in CANNONS:
		var a := deg_to_rad(ANGLES[i])
		var p := _flame(soft)
		p.position = Pitch.FIELD_CENTRE + Vector3(cos(a), 0.0, sin(a)) * ROPE
		add_child(p)
		_flames.append(p)
		_flame_left.append(0.0)
	for i in 6:
		var w := _firework(soft)
		add_child(w)
		_works.append(w)

func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _additive(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_fog = true
	return m

func _flame(tex: Texture2D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	q.material = _additive(tex)
	p.mesh = q
	p.emitting = false
	p.amount = 48
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 6.0
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector3(0, 2.0, 0)
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.7, 0.2, 0.95), Color(0.95, 0.3, 0.05, 0.6),
		Color(0.3, 0.05, 0.02, 0.0)])
	p.color_ramp = ramp
	return p

func _firework(tex: Texture2D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	q.material = _additive(tex)
	p.mesh = q
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 90
	p.lifetime = 1.8
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 13.0
	p.initial_velocity_max = 17.0
	p.gravity = Vector3(0, -6.0, 0)
	p.damping_min = 3.0
	p.damping_max = 4.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	return p

## Flames for a six: the cannons nearest where the ball went, then the rest round the ground.
func flames(toward: Vector3) -> void:
	var dir := Vector3(toward.x - Pitch.FIELD_CENTRE.x, 0.0, toward.z - Pitch.FIELD_CENTRE.z)
	var aim := atan2(dir.z, dir.x)
	for i in CANNONS:
		var a := deg_to_rad(ANGLES[i])
		var near := absf(angle_difference(a, aim)) < 1.1
		_flame_left[i] = 1.3 if near else 0.9
		_flames[i].emitting = true

## A volley of fireworks over the stands, in these colours.
func fireworks(colours: Array, count: int = 6) -> void:
	for k in count:
		var w := _works[_next_work]
		_next_work = (_next_work + 1) % _works.size()
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(55.0, 85.0)
		w.position = Pitch.FIELD_CENTRE + Vector3(cos(a) * r, _rng.randf_range(42.0, 58.0), sin(a) * r)
		var c: Color = colours[k % colours.size()]
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 1), c.lightened(0.3), c, Color(c.r, c.g, c.b, 0.0)])
		w.color_ramp = ramp
		get_tree().create_timer(0.25 * k).timeout.connect(func(): w.restart())

func _process(delta: float) -> void:
	for i in CANNONS:
		if _flame_left[i] > 0.0:
			_flame_left[i] -= delta
			if _flame_left[i] <= 0.0:
				_flames[i].emitting = false
