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

var _seg := {}
var _head: Node3D
var _torso_basis := Basis.IDENTITY
var shoulder_l := Vector3.ZERO
var shoulder_r := Vector3.ZERO

static func mat(c: Color, rough: float = 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.25 if rough < 0.5 else 0.0
	return m

func build() -> void:
	var white := Color(0.95, 0.95, 0.92)
	var legs := white if pads else kit.darkened(0.12)
	_capsule("torso", 0.165, SPINE, kit)
	_capsule("pelvis", 0.15, 0.16, kit.darkened(0.12))
	for s in ["l", "r"]:
		_capsule("upper_" + s, 0.058, UPPER_ARM, kit)
		_capsule("fore_" + s, 0.047, FOREARM, skin)
		_ball("hand_" + s, 0.062, white if pads else skin)
		_capsule("thigh_" + s, 0.088 if pads else 0.08, THIGH, legs)
		_capsule("shin_" + s, 0.082 if pads else 0.062, SHIN, legs)
		var foot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.10, 0.08, 0.26)
		foot.mesh = box
		foot.material_override = mat(Color(0.93, 0.93, 0.93))
		add_child(foot)
		_seg["foot_" + s] = foot
	_capsule("stripe", 0.168, 0.06, trim)
	_head = Node3D.new()
	add_child(_head)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.135
	sm.height = 0.27
	sm.radial_segments = 20
	sm.rings = 10
	skull.mesh = sm
	skull.material_override = mat(skin)
	_head.add_child(skull)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.15 if helmet else 0.142
	cm.height = cm.radius
	cm.is_hemisphere = true
	cm.radial_segments = 20
	cm.rings = 6
	cap.mesh = cm
	cap.position.y = 0.015
	cap.material_override = mat(kit.darkened(0.35) if helmet else kit, 0.35 if helmet else 0.8)
	_head.add_child(cap)
	var peak := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.2, 0.018, 0.13)
	peak.mesh = pm
	peak.position = Vector3(0, 0.03, -0.17)
	peak.material_override = cap.material_override
	_head.add_child(peak)
	if helmet:
		for i in 3:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.21, 0.012, 0.012)
			bar.mesh = bm
			bar.position = Vector3(0, -0.02 - 0.04 * i, -0.15)
			bar.material_override = mat(Color(0.75, 0.75, 0.78), 0.3)
			_head.add_child(bar)

func _capsule(key: String, radius: float, length: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = length + radius * 2.0
	m.radial_segments = 12
	m.rings = 4
	mi.mesh = m
	mi.material_override = mat(c)
	mi.set_meta("len", length)
	add_child(mi)
	_seg[key] = mi

func _ball(key: String, radius: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	mi.mesh = m
	mi.material_override = mat(c)
	add_child(mi)
	_seg[key] = mi

func _place(key: String, a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = _seg[key]
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return
	var y := d / l
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	var rest: float = mi.get_meta("len")
	mi.transform = Transform3D(Basis(x, y * (l / rest), z), (a + b) * 0.5)

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
	_place("torso", p.hips + up * 0.06, neck - up * 0.06)
	_place("stripe", p.hips + up * 0.30, p.hips + up * 0.36)
	_place("pelvis", p.hips - pelvis.x * 0.08, p.hips + pelvis.x * 0.08)
	_head.transform = Transform3D(Basis(Vector3.UP, p.head_yaw), neck + up * 0.17)
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
	(_seg[end] as MeshInstance3D).position = r[1]

func _leg(s: String, hip: Vector3, foot: Vector3, pole: Vector3, yaw: float) -> void:
	var ankle := foot + Vector3(0, 0.09, 0)
	var r := two_bone(hip, ankle, THIGH, SHIN, pole)
	_place("thigh_" + s, hip, r[0])
	_place("shin_" + s, r[0], r[1])
	var f: MeshInstance3D = _seg["foot_" + s]
	var b := Basis(Vector3.UP, yaw)
	f.transform = Transform3D(b, r[1] - Vector3(0, 0.05, 0) - b.z * 0.07)
