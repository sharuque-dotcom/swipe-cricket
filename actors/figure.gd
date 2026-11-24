class_name Figure
extends Node3D
## A stylised player drawn from joint positions. Animation is done by moving a handful of
## targets (hips, feet, hands); limbs are solved with two-bone inverse kinematics each frame.

const UPPER_ARM := 0.29
const FOREARM := 0.27
const THIGH := 0.44
const SHIN := 0.44
const SPINE := 0.50
const HIP_HALF := 0.105
const SHOULDER_HALF := 0.20

class Pose:
	extends RefCounted
	var hips := Vector3(0, 0.93, 0)
	var hip_yaw := 0.0
	var chest_yaw := 0.0
	var lean := 0.0          # forward bend of the spine
	var side_lean := 0.0
	var head_yaw := 0.0
	var foot_l := Vector3(-0.11, 0, 0)
	var foot_r := Vector3(0.11, 0, 0)
	var hand_l := Vector3(-0.25, 0.85, 0)
	var hand_r := Vector3(0.25, 0.85, 0)

	func blend(to: Pose, t: float) -> Pose:
		var p := Pose.new()
		p.hips = hips.lerp(to.hips, t)
		p.hip_yaw = lerp_angle(hip_yaw, to.hip_yaw, t)
		p.chest_yaw = lerp_angle(chest_yaw, to.chest_yaw, t)
		p.lean = lerpf(lean, to.lean, t)
		p.side_lean = lerpf(side_lean, to.side_lean, t)
		p.head_yaw = lerp_angle(head_yaw, to.head_yaw, t)
		p.foot_l = foot_l.lerp(to.foot_l, t)
		p.foot_r = foot_r.lerp(to.foot_r, t)
		p.hand_l = hand_l.lerp(to.hand_l, t)
		p.hand_r = hand_r.lerp(to.hand_r, t)
		return p

var kit := Color(0.1, 0.35, 0.8)
var trim := Color(1.0, 0.8, 0.1)
var skin := Color(0.72, 0.5, 0.36)
var pads := false
var helmet := false
var helmet_colour := Color(0, 0, 0, 0)   # from the locker; transparent: the team's colour
var hat := false                 # wide-brimmed hat instead of a cap
var trousers := Color(0, 0, 0, 0)  # leave transparent to match the kit

## Heads are drawn big: these are characters, not mannequins.
const HEAD_SCALE := 1.32
var _name_label: Label3D
var _number_label: Label3D

var _seg := {}
var _head: Node3D
var _torso_basis := Basis.IDENTITY
var shoulder_l := Vector3.ZERO
var shoulder_r := Vector3.ZERO

## Midpoint between the two hands, in world space: where a held ball sits.
func hands_global() -> Vector3:
	var l: MeshInstance3D = _seg["hand_l"]
	var r: MeshInstance3D = _seg["hand_r"]
	return to_global((l.position + r.position) * 0.5)

static func mat(c: Color, rough: float = 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.25 if rough < 0.5 else 0.0
	return m

## The low-poly look: every triangle is lit as one flat facet (the normal comes from the
## screen-space slope of the surface), so smooth meshes with few sides read as cut shapes.
const FACET_CODE := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float lift = 0.0;
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	EMISSION = albedo.rgb * lift;
}
"""
static var _facet_shader: Shader
static var _facets := {}

static func facet(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if _facets.has(key):
		return _facets[key]
	if _facet_shader == null:
		_facet_shader = Shader.new()
		_facet_shader.code = FACET_CODE
	var m := ShaderMaterial.new()
	m.shader = _facet_shader
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("lift", 0.12)
	_facets[key] = m
	return m

# Face parts, moved to show a mood (see `set_face`).
var _brows: Array[MeshInstance3D] = []
var _eyes: Array[Node3D] = []
var _mouth: MeshInstance3D
var _grin: MeshInstance3D
var mood := "focused"
var _mood_left := 0.0
var _blink := 0.0
var _next_blink := 2.0

func build() -> void:
	var white := Color(0.95, 0.95, 0.92)
	var legs := white if pads else (trousers if trousers.a > 0.0 else kit.darkened(0.12))
	_next_blink = 1.0 + randf() * 3.0
	_shape("torso", _cyl(0.145, 0.18, 8), 1.0, kit)
	_shape("pelvis", _cyl(0.155, 0.15, 8), 1.0, kit.darkened(0.12) if trousers.a == 0.0 and not pads else legs)
	_shape("stripe", _cyl(0.17, 0.172, 8), 1.0, trim)
	for s in ["l", "r"]:
		_capsule("upper_" + s, 0.062, UPPER_ARM, kit)
		_capsule("fore_" + s, 0.048, FOREARM, skin)
		if pads:
			# Batting gloves: chunky white blocks with a cuff in the team colour.
			_box("hand_" + s, Vector3(0.115, 0.125, 0.1), white)
		else:
			_ball("hand_" + s, 0.062, skin)
		_capsule("thigh_" + s, 0.086, THIGH, legs)
		_capsule("shin_" + s, 0.074 if pads else 0.062, SHIN, legs)
		if pads:
			# Pads: a tall slab in front of each shin, with a knee roll.
			_shape("pad_" + s, _boxm(Vector3(0.19, 1.0, 0.1)), 1.0, white)
			_shape("roll_" + s, _boxm(Vector3(0.2, 1.0, 0.13)), 1.0, white.darkened(0.06))
		var foot := MeshInstance3D.new()
		foot.mesh = _boxm(Vector3(0.11, 0.08, 0.27))
		foot.material_override = facet(Color(0.95, 0.95, 0.95))
		add_child(foot)
		_seg["foot_" + s] = foot
	_head = Node3D.new()
	add_child(_head)
	_build_face()
	if hat:
		_build_hat()
	else:
		_build_cap()
	set_face("focused")

func _build_face() -> void:
	var dark := Color(0.07, 0.06, 0.08)
	var skull := _part(_sphere(0.135, 8, 6), skin, Vector3.ZERO)
	skull.scale = Vector3(0.96, 1.0, 0.96)
	for side in [-1.0, 1.0]:
		_part(_sphere(0.03, 6, 3), skin, Vector3(side * 0.13, -0.005, 0.0)).scale = Vector3(0.5, 1.0, 0.8)
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.05, -0.004, -0.114)
		_head.add_child(eye)
		var white := MeshInstance3D.new()
		white.mesh = _sphere(0.034, 8, 4)
		white.material_override = facet(Color(0.98, 0.98, 0.96))
		white.scale = Vector3(1.0, 1.2, 0.6)
		eye.add_child(white)
		var pupil := MeshInstance3D.new()
		pupil.mesh = _sphere(0.017, 6, 3)
		pupil.material_override = facet(dark)
		pupil.position = Vector3(0, 0, -0.022)
		pupil.scale = Vector3(1.0, 1.25, 0.5)
		eye.add_child(pupil)
		_eyes.append(eye)
		var brow := _part(_boxm(Vector3(0.06, 0.014, 0.02)), dark, Vector3(side * 0.05, 0.046, -0.124))
		_brows.append(brow)
	_part(_sphere(0.02, 5, 3), skin.darkened(0.08), Vector3(0, -0.035, -0.133))
	_mouth = _part(_boxm(Vector3(0.055, 0.011, 0.02)), dark, Vector3(0, -0.075, -0.118))
	# The grin: a half-disc, flat edge up.
	var gm := SphereMesh.new()
	gm.radius = 0.04
	gm.height = 0.04
	gm.is_hemisphere = true
	gm.radial_segments = 8
	gm.rings = 2
	_grin = _part(gm, Color(0.45, 0.07, 0.1), Vector3(0, -0.062, -0.118))
	_grin.rotation.z = PI
	_grin.scale = Vector3(1.0, 0.85, 0.35)

func _build_cap() -> void:
	var col := (helmet_colour if helmet_colour.a > 0.0 else kit.darkened(0.45)) if helmet else kit
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.152 if helmet else 0.142
	cm.height = cm.radius
	cm.is_hemisphere = true
	cm.radial_segments = 8
	cm.rings = 3
	cap.mesh = cm
	cap.position.y = 0.012 if helmet else 0.062
	cap.material_override = facet(col)
	_head.add_child(cap)
	var peak := _part(_boxm(Vector3(0.21, 0.018, 0.12)), col, Vector3(0, 0.03 if helmet else 0.075, -0.165))
	peak.rotation.x = 0.0 if helmet else 0.22
	if helmet:
		# Neck guard and side flaps, a team stripe, and the grille.
		_part(_boxm(Vector3(0.24, 0.07, 0.12)), col, Vector3(0, -0.02, 0.06))
		_part(_boxm(Vector3(0.05, 0.012, 0.1)), trim, Vector3(0, 0.158, 0.0))
		var steel := Color(0.78, 0.79, 0.83)
		for i in 3:
			_part(_boxm(Vector3(0.22, 0.012, 0.012)), steel, Vector3(0, -0.025 - 0.038 * i, -0.158))
		for side in [-1.0, 1.0]:
			_part(_boxm(Vector3(0.012, 0.11, 0.012)), steel, Vector3(side * 0.105, -0.06, -0.152))

func _build_hat() -> void:
	var cream := Color(0.96, 0.95, 0.90)
	_part(_cyl(0.27, 0.27, 10, 0.022), cream, Vector3(0, 0.07, 0))
	_part(_cyl(0.12, 0.145, 8, 0.12), cream, Vector3(0, 0.135, 0))
	_part(_cyl(0.148, 0.148, 8, 0.03), kit, Vector3(0, 0.095, 0))

## Faces: "focused" (the default), "joy" (big grin, raised brows) or "wince" (pained,
## crooked mouth). With `seconds`, it goes back to focused afterwards.
func set_face(kind: String, seconds: float = 0.0) -> void:
	mood = kind
	_mood_left = seconds
	if _mouth == null:
		return
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		var b := _brows[i]
		match kind:
			"joy":
				b.rotation.z = side * deg_to_rad(-12.0)
				b.position.y = 0.056
			"wince":
				b.rotation.z = side * deg_to_rad(26.0)
				b.position.y = 0.04
			_:
				b.rotation.z = side * deg_to_rad(14.0)
				b.position.y = 0.046
	_mouth.visible = kind != "joy"
	_grin.visible = kind == "joy"
	_mouth.rotation.z = deg_to_rad(16.0) if kind == "wince" else 0.0
	_mouth.position.x = 0.01 if kind == "wince" else 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _eyes.is_empty():
		return
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			set_face("focused")
	# Blink now and then; squint while wincing.
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.13
		_next_blink = 2.0 + randf() * 3.5
	_blink = maxf(_blink - delta, 0.0)
	var open := 0.12 if _blink > 0.0 else (0.55 if mood == "wince" else 1.0)
	for e in _eyes:
		e.scale.y = open

func _part(m: Mesh, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = facet(c)
	mi.position = at
	_head.add_child(mi)
	return mi

static func _sphere(r: float, radial: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = radial
	m.rings = rings
	return m

static func _cyl(bottom: float, top: float, sides: int, height: float = 1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m

static func _boxm(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

## Rebuild in new colours (a different team).
func recolour(new_kit: Color, new_trim: Color) -> void:
	kit = new_kit
	trim = new_trim
	var shirt := ""
	var number := ""
	if _number_label != null:
		shirt = _name_label.text
		number = _number_label.text
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_seg.clear()
	_brows.clear()
	_eyes.clear()
	_mouth = null
	_head = null
	_name_label = null
	_number_label = null
	build()
	if number != "":
		set_shirt(shirt, int(number))

## Name and number on the back of the shirt.
func set_shirt(shirt_name: String, number: int) -> void:
	if _number_label == null:
		_number_label = _shirt_label(60)
		_name_label = _shirt_label(24)
	_number_label.text = str(number)
	_name_label.text = shirt_name.to_upper()

func _shirt_label(size: int) -> Label3D:
	var l := Label3D.new()
	l.font = Hud.font("bold")
	l.font_size = size
	l.pixel_size = 0.003
	l.modulate = trim
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(l)
	return l

func _capsule(key: String, radius: float, length: float, c: Color) -> void:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = length + radius * 2.0
	m.radial_segments = 6
	m.rings = 1
	_shape(key, m, length, c)

## A mesh whose height is `length` when unstretched; `_place` stretches it between joints.
func _shape(key: String, m: Mesh, length: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = facet(c)
	mi.set_meta("len", length)
	add_child(mi)
	_seg[key] = mi

func _ball(key: String, radius: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(radius, 6, 4)
	mi.material_override = facet(c)
	add_child(mi)
	_seg[key] = mi

func _box(key: String, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _boxm(size)
	mi.material_override = facet(c)
	add_child(mi)
	_seg[key] = mi

## Stretch a segment from `a` to `b`. `side` (optional) says which way its width faces.
func _place(key: String, a: Vector3, b: Vector3, side: Vector3 = Vector3.ZERO) -> void:
	var mi: MeshInstance3D = _seg[key]
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return
	var y := d / l
	var x: Vector3
	if side != Vector3.ZERO and absf(side.normalized().dot(y)) < 0.95:
		x = (side - y * side.dot(y)).normalized()
	else:
		var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
		x = ref.cross(y).normalized()
	var z := x.cross(y)
	var rest: float = mi.get_meta("len")
	mi.transform = Transform3D(Basis(x, y * (l / rest), z), (a + b) * 0.5)

## Body blocks (torso, pelvis, stripe) follow the body's own frame and are flattened front
## to back, with a flat facet facing forward.
func _place_body(key: String, basis: Basis, a: Vector3, b: Vector3, depth: float) -> void:
	var mi: MeshInstance3D = _seg[key]
	var rest: float = mi.get_meta("len")
	var l := (b - a).length()
	var k := basis * Basis.from_scale(Vector3(1.0, l / rest, depth)) * Basis(Vector3.UP, PI / 8.0)
	mi.transform = Transform3D(k, (a + b) * 0.5)

static func two_bone(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := target - root
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := d.normalized() if d.length_squared() > 0.000001 else Vector3.DOWN
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var perp := pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length_squared() > 0.000001 else Vector3.FORWARD
	return [root + dir * x + perp * h, root + dir * dist]

func apply(p: Pose) -> void:
	var pelvis := Basis(Vector3.UP, p.hip_yaw)
	_torso_basis = Basis(Vector3.UP, p.chest_yaw) * Basis(Vector3.RIGHT, -p.lean) * Basis(Vector3.BACK, p.side_lean)
	var up := _torso_basis.y
	var neck := p.hips + up * SPINE
	shoulder_l = neck - up * 0.05 - _torso_basis.x * SHOULDER_HALF
	shoulder_r = neck - up * 0.05 + _torso_basis.x * SHOULDER_HALF
	_place_body("torso", _torso_basis, p.hips + up * 0.04, neck - up * 0.02, 0.8)
	_place_body("stripe", _torso_basis, p.hips + up * 0.28, p.hips + up * 0.34, 0.8)
	_place_body("pelvis", pelvis, p.hips - Vector3(0, 0.1, 0), p.hips + Vector3(0, 0.1, 0), 0.78)
	_head.transform = Transform3D(Basis(Vector3.UP, p.head_yaw).scaled(Vector3.ONE * HEAD_SCALE), neck + up * 0.21)
	if _number_label != null:
		_number_label.transform = Transform3D(_torso_basis, p.hips + up * 0.17 + _torso_basis.z * 0.13)
		_name_label.transform = Transform3D(_torso_basis, p.hips + up * 0.435 + _torso_basis.z * 0.146)
	var fwd := -_torso_basis.z
	var arm_pole := Vector3.DOWN * 0.6 - fwd * 0.5
	_limb("upper_l", "fore_l", "hand_l", shoulder_l, p.hand_l, UPPER_ARM, FOREARM, arm_pole - _torso_basis.x * 0.5)
	_limb("upper_r", "fore_r", "hand_r", shoulder_r, p.hand_r, UPPER_ARM, FOREARM, arm_pole + _torso_basis.x * 0.5)
	var knee_pole := -pelvis.z
	_leg("l", p.hips - pelvis.x * HIP_HALF, p.foot_l, knee_pole, p.hip_yaw)
	_leg("r", p.hips + pelvis.x * HIP_HALF, p.foot_r, knee_pole, p.hip_yaw)

func _limb(a: String, b: String, end: String, root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> void:
	var r := two_bone(root, target, l1, l2, pole)
	_place(a, root, r[0])
	_place(b, r[0], r[1])
	var h: MeshInstance3D = _seg[end]
	h.position = r[1]
	if pads:
		# Gloves turn with the forearm.
		var y: Vector3 = (r[1] - r[0]).normalized()
		var x := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
		x = (x - y * x.dot(y)).normalized()
		h.basis = Basis(x, y, x.cross(y))

func _leg(s: String, hip: Vector3, foot: Vector3, pole: Vector3, yaw: float) -> void:
	var ankle := foot + Vector3(0, 0.09, 0)
	var r := two_bone(hip, ankle, THIGH, SHIN, pole)
	_place("thigh_" + s, hip, r[0])
	_place("shin_" + s, r[0], r[1])
	if pads:
		var fwd := -Basis(Vector3.UP, yaw).z
		var sx := Basis(Vector3.UP, yaw).x
		var down: Vector3 = (r[1] - r[0]).normalized()
		_place("pad_" + s, r[0] + fwd * 0.055 - down * 0.06, r[1] + fwd * 0.06 + down * 0.02, sx)
		_place("roll_" + s, r[0] + fwd * 0.06 - down * 0.08, r[0] + fwd * 0.06 + down * 0.04, sx)
	var f: MeshInstance3D = _seg["foot_" + s]
	var b := Basis(Vector3.UP, yaw)
	f.transform = Transform3D(b, r[1] - Vector3(0, 0.05, 0) - b.z * 0.07)
