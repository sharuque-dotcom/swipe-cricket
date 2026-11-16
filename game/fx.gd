class_name Fx
extends Node3D
## Short-lived glow sprites: the flash off the bat, dust where the ball pitches, splinters
## of light off the stumps. A small pool, reused.

const POOL := 14

var _sprites: Array[MeshInstance3D] = []
var _life: Array[float] = []
var _age: Array[float] = []
var _from: Array[float] = []
var _to: Array[float] = []
var _vel: Array[Vector3] = []
var _next := 0
var _soft: GradientTexture2D
var _ring: GradientTexture2D

func _ready() -> void:
	_soft = _radial([0.0, 0.45, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_ring = _radial([0.0, 0.62, 0.78, 0.92, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	for i in POOL:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_sprites.append(mi)
		_life.append(0.0)
		_age.append(0.0)
		_from.append(0.0)
		_to.append(0.0)
		_vel.append(Vector3.ZERO)

func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 96
	t.height = 96
	return t

func _spawn(pos: Vector3, tex: Texture2D, c: Color, from: float, to: float, life: float, additive: bool, vel: Vector3 = Vector3.ZERO) -> void:
	var i := _next
	_next = (_next + 1) % POOL
	var mi := _sprites[i]
	var m: StandardMaterial3D = mi.material_override
	m.albedo_texture = tex
	m.albedo_color = c
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.no_depth_test = additive
	mi.position = pos
	mi.scale = Vector3.ONE * from
	mi.visible = true
	_life[i] = life
	_age[i] = 0.0
	_from[i] = from
	_to[i] = to
	_vel[i] = vel

## Bat on ball: a hot core and an expanding ring. `power` 0..1 scales it.
func impact(pos: Vector3, power: float) -> void:
	var k := lerpf(0.5, 1.0, clampf(power, 0.0, 1.0))
	_spawn(pos, _soft, Color(1.0, 0.95, 0.75, 0.95), 0.25 * k, 1.5 * k, 0.16, true)
	_spawn(pos, _ring, Color(1.0, 0.90, 0.55, 0.9), 0.3 * k, 2.6 * k, 0.26, true)

## The ball pitching: a low puff of dust.
func dust(pos: Vector3, size: float = 1.0) -> void:
	for j in 3:
		var v := Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 0.8), randf_range(-0.5, 0.5))
		_spawn(pos + Vector3(0, 0.05, 0), _soft, Color(0.80, 0.68, 0.48, 0.55), 0.18 * size, 0.75 * size, 0.42, false, v)

## Stumps broken: a burst of light.
func burst(pos: Vector3) -> void:
	_spawn(pos, _soft, Color(1.0, 0.85, 0.5, 0.9), 0.3, 2.2, 0.22, true)
	_spawn(pos, _ring, Color(1.0, 1.0, 1.0, 0.8), 0.3, 3.4, 0.34, true)

func _process(delta: float) -> void:
	for i in POOL:
		var mi := _sprites[i]
		if not mi.visible:
			continue
		_age[i] += delta
		var u := _age[i] / _life[i]
		if u >= 1.0:
			mi.visible = false
			continue
		var e := 1.0 - pow(1.0 - u, 2.0)
		mi.scale = Vector3.ONE * lerpf(_from[i], _to[i], e)
		mi.position += _vel[i] * delta
		var m: StandardMaterial3D = mi.material_override
		m.albedo_color.a = (1.0 - u) * (0.95 if m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD else 0.55)
