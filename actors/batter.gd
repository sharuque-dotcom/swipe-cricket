class_name Batter
extends Node3D
## Right-handed batter. The bat is driven to the real contact point; arms follow by IK.

enum Phase { STANCE, BACKLIFT, SWING, FOLLOW, RECOVER }

var figure: Figure
var bat: Bat
var phase := Phase.STANCE
var _t := 0.0
var _clock := 0.0
var _contact := Vector3(0.1, 0.5, -1.1)
var _aim := Vector3(0, 0, -1)
var _horizontal := false
var _from := {}

# Bat keys: grip position, blade direction, face direction.
const STANCE_BAT := [Vector3(-0.06, 0.70, -0.88), Vector3(0.04, -0.93, 0.36), Vector3(0, 0, -1)]
const LIFT_BAT := [Vector3(-0.20, 1.02, -0.66), Vector3(-0.10, 0.62, 0.78), Vector3(0.3, -0.5, -0.8)]

func build(kit: Color, trim: Color) -> void:
	figure = Figure.new()
	figure.kit = kit
	figure.trim = trim
	figure.pads = true
	figure.helmet = true
	add_child(figure)
	figure.build()
	bat = Bat.new()
	add_child(bat)
	bat.build()
	_from = _bat_now()
	_update(0.0)

func _bat_now() -> Dictionary:
	return {"g": bat.position, "d": -bat.basis.y, "f": bat.basis.z}

func backlift() -> void:
	if phase == Phase.STANCE or phase == Phase.RECOVER:
		_go(Phase.BACKLIFT)

func swing(contact: Vector3, angle: float) -> void:
	_contact = contact
	_aim = Vector3(sin(angle), 0.0, -cos(angle))
	var deg := absf(rad_to_deg(angle))
	_horizontal = deg > 50.0 and deg <= 130.0
	_go(Phase.SWING)

func reset() -> void:
	_go(Phase.RECOVER)

func _go(p: Phase) -> void:
	_from = _bat_now()
	phase = p
	_t = 0.0

func _process(delta: float) -> void:
	_update(delta)

func _contact_bat() -> Array:
	var d: Vector3
	if _horizontal:
		d = Vector3(_contact.x + 0.35, -0.12, _contact.z + 0.80).normalized()
	else:
		d = Vector3(0.05 + _aim.x * 0.15, -0.95, 0.28).normalized()
	return [_contact - d * Bat.SWEET, d, _aim]

func _follow_bat() -> Array:
	var g := Vector3(-0.22, 1.36, -0.95) + _aim * 0.32
	var d := (-_aim * 0.55 + Vector3(0, 0.55, 0.45)).normalized()
	return [g, d, (_aim + Vector3.UP * 0.6).normalized()]

func _update(delta: float) -> void:
	_t += delta
	_clock += delta
	var key: Array = STANCE_BAT
	var k := 1.0
	var stride := 0.0
	match phase:
		Phase.STANCE:
			key = STANCE_BAT
			k = 1.0
		Phase.BACKLIFT:
			key = LIFT_BAT
			k = smoothstep(0.0, 0.22, _t)
		Phase.SWING:
			key = _contact_bat()
			var u := clampf(_t / Tuning.SWING_TIME, 0.0, 1.0)
			k = u * u
			stride = k
			if u >= 1.0:
				_go(Phase.FOLLOW)
				stride = 1.0
		Phase.FOLLOW:
			key = _follow_bat()
			k = 1.0 - pow(1.0 - clampf(_t / 0.2, 0.0, 1.0), 2.0)
			stride = 1.0
			if _t > 1.1:
				_go(Phase.RECOVER)
		Phase.RECOVER:
			key = STANCE_BAT
			k = smoothstep(0.0, 0.45, _t)
			if _t > 0.45:
				phase = Phase.STANCE
	var g: Vector3 = (_from.g as Vector3).lerp(key[0], k)
	var d: Vector3 = (_from.d as Vector3).slerp(key[1], k).normalized()
	var f: Vector3 = (_from.f as Vector3).slerp(key[2], k).normalized()
	if phase == Phase.STANCE:
		# Idle: tap the bat.
		g.y += 0.025 * maxf(0.0, sin(_clock * 5.0))
	bat.place(g, d, f)

	var p := Figure.Pose.new()
	var bob := 0.012 * sin(_clock * 2.4)
	p.hips = Vector3(-0.36, 0.83 + bob, -0.93)
	p.hip_yaw = deg_to_rad(-82.0)
	p.chest_yaw = deg_to_rad(-70.0)
	p.lean = 0.42
	p.head_yaw = deg_to_rad(-12.0)
	p.foot_r = Vector3(-0.34, 0, -0.68)
	p.foot_l = Vector3(-0.34, 0, -1.18)
	if stride > 0.0 or phase == Phase.FOLLOW:
		var turn := atan2(_aim.x, -_aim.z)
		if _horizontal:
			p.hips = p.hips.lerp(Vector3(-0.40, 0.86, -0.82), stride)
			p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.8 - deg_to_rad(20.0), stride)
			p.lean = lerpf(p.lean, 0.2, stride)
		else:
			var plant := Vector3(clampf(_contact.x - 0.32, -0.6, 0.35), 0, clampf(_contact.z - 0.25, -1.9, -1.2))
			p.foot_l = p.foot_l.lerp(plant, stride)
			p.hips = p.hips.lerp(Vector3((plant.x - 0.34) * 0.5 - 0.02, 0.78, (plant.z - 0.68) * 0.5), stride)
			p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.6 - deg_to_rad(35.0), stride)
			p.lean = lerpf(p.lean, 0.5, stride)
		if phase == Phase.FOLLOW:
			p.lean = lerpf(p.lean, 0.12, k)
			p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.9, k)
	elif phase == Phase.BACKLIFT:
		p.hips.y -= 0.03 * k
	var bd := -bat.basis.y
	p.hand_l = bat.position - bd * 0.07
	p.hand_r = bat.position + bd * 0.06
	figure.apply(p)
