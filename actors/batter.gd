class_name Batter
extends Node3D
## Right-handed batter. The bat is driven to the real contact point; arms follow by IK.
## Each kind of shot has its own body shape and follow-through (see `swing`), and each
## batter stands a little differently (see `vary`).

enum Phase { STANCE, BACKLIFT, SWING, FOLLOW, RECOVER, CELEBRATE }

var figure: Figure
var bat: Bat
var phase := Phase.STANCE
var _t := 0.0
var _clock := 0.0
var _contact := Vector3(0.1, 0.5, -1.1)
var _aim := Vector3(0, 0, -1)
var _horizontal := false
var _style := "drive"
var _from := {}
var _cele := ""

# Stance, varied per batter: how low they crouch, how wide they stand, how high the bat
# goes up, how fast they tap it.
var _crouch := 0.83
var _front_z := -1.18
var _lift_y := 1.02
var _tap := 5.0

# Bat keys: grip position, blade direction, face direction.
const STANCE_BAT := [Vector3(-0.06, 0.70, -0.88), Vector3(0.04, -0.93, 0.36), Vector3(0, 0, -1)]
const LIFT_BAT := [Vector3(-0.20, 1.02, -0.66), Vector3(-0.10, 0.62, 0.78), Vector3(0.3, -0.5, -0.8)]
# Stepping out: the whole batter moves down the pitch (this node moves), with quick steps.
var _charge_to := 0.0
var _charge_dur := 0.5
var _charge_t := -1.0
var _back_t := -1.0       # walking back into the crease
var _back_from := 0.0

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

## A slightly different stance for each batter in the order.
func vary(order: int) -> void:
	var h := absi(hash(order * 7349 + 11))
	_crouch = 0.80 + 0.06 * float(h % 7) / 6.0
	_front_z = -1.12 - 0.13 * float((h / 7) % 5) / 4.0
	_lift_y = 0.98 + 0.16 * float((h / 35) % 5) / 4.0
	_tap = 3.6 + 2.4 * float((h / 175) % 4) / 3.0

func _bat_now() -> Dictionary:
	return {"g": bat.position, "d": -bat.basis.y, "f": bat.basis.z}

func backlift() -> void:
	if phase == Phase.STANCE or phase == Phase.RECOVER:
		_go(Phase.BACKLIFT)

## Play a shot at `contact`, aimed along `angle`. `style` is ShotResolver's animation name:
## drive, loft_drive, step_out, helicopter, cut, upper_cut, pull, one_leg_pull, hook,
## sweep, slog_sweep, reverse_sweep, flick, glance, scoop, edge. Empty picks from the angle.
func swing(contact: Vector3, angle: float, style: String = "") -> void:
	_contact = contact - position   # contact is in the ground's space; poses are in ours
	_aim = Vector3(sin(angle), 0.0, -cos(angle))
	var deg := absf(rad_to_deg(angle))
	_horizontal = deg > 50.0 and deg <= 130.0
	_style = style
	if _style == "":
		_style = "cut" if _horizontal and angle > 0.0 else ("pull" if _horizontal else "drive")
	_go(Phase.SWING)

func reset() -> void:
	_go(Phase.RECOVER)
	if position.z < -0.01:
		_back_t = 0.0
		_back_from = position.z
	_charge_t = -1.0

## Dance down the pitch `dist` metres over `seconds`.
func charge(dist: float, seconds: float) -> void:
	_charge_to = dist
	_charge_dur = maxf(seconds, 0.1)
	_charge_t = 0.0
	_back_t = -1.0

## Put the batter `dist` down the pitch straight away (replays).
func set_advance(dist: float) -> void:
	position.z = -dist
	_charge_t = -1.0
	_back_t = -1.0

## How far into the charge or the walk back they are, for stepping feet: 0..1 and the
## phase of the steps.
func _steps(delta: float) -> float:
	if _charge_t >= 0.0:
		_charge_t += delta
		var u := clampf(_charge_t / _charge_dur, 0.0, 1.0)
		position.z = -_charge_to * smoothstep(0.0, 1.0, u)
		if u >= 1.0:
			_charge_t = -1.0
			return 0.0
		return u * 3.0
	if _back_t >= 0.0:
		_back_t += delta
		var u := clampf(_back_t / 0.7, 0.0, 1.0)
		position.z = lerpf(_back_from, 0.0, smoothstep(0.0, 1.0, u))
		if u >= 1.0:
			_back_t = -1.0
			return 0.0
		return u * 3.0
	return 0.0

## "milestone": bat raised to the crowd. "win": both arms up, jumping.
func celebrate(kind: String) -> void:
	_cele = kind
	_go(Phase.CELEBRATE)

func _go(p: Phase) -> void:
	_from = _bat_now()
	phase = p
	_t = 0.0

func _process(delta: float) -> void:
	_update(delta)

func _low() -> bool:
	return _style in ["sweep", "slog_sweep", "reverse_sweep"]

func _contact_bat() -> Array:
	var d: Vector3
	var f := _aim
	match _style:
		"sweep", "slog_sweep":
			d = Vector3(0.62, -0.42, -0.30)
		"reverse_sweep":
			d = Vector3(0.75, -0.45, 0.45)
		"scoop":
			d = Vector3(0.10, -0.55, -0.83)
			f = (_aim + Vector3.UP).normalized()
		"helicopter":
			d = Vector3(0.08, -0.98, 0.15)
		_:
			if _horizontal:
				d = Vector3(_contact.x + 0.35, -0.12, _contact.z + 0.80)
			else:
				d = Vector3(0.05 + _aim.x * 0.15, -0.95, 0.28)
	d = d.normalized()
	return [_contact - d * Bat.SWEET, d, f]

func _follow_bat() -> Array:
	var up := Vector3.UP
	match _style:
		"defend":
			# Dead bat, soft hands: the bat stays down in front of the pad.
			return [Vector3(-0.14, 0.92, -1.30), Vector3(0.06, -0.95, 0.12).normalized(), Vector3(0, 0, -1)]
		"drive":
			# Hold the pose: high hands, blade up, face to where it went.
			return [Vector3(-0.20, 1.45, -1.15) + _aim * 0.30, (_aim * 0.55 + up * 0.85).normalized(), _aim]
		"loft_drive", "step_out":
			# The full finish, bat right over the shoulder.
			return [Vector3(-0.25, 1.78, -0.95) + _aim * 0.15, (-_aim * 0.5 + Vector3(0, 0.45, 0.75)).normalized(),
				(_aim + up * 0.6).normalized()]
		"pull", "one_leg_pull", "hook":
			# Wrapped round the front shoulder.
			return [Vector3(-0.55, 1.48 if _style != "hook" else 1.62, -0.72), Vector3(-0.25, 0.35, 0.9).normalized(), Vector3(-1, 0.3, 0).normalized()]
		"cut":
			return [Vector3(0.10, 1.05, -0.95), Vector3(0.85, -0.25, 0.45).normalized(), _aim]
		"upper_cut":
			return [Vector3(0.05, 1.65, -0.95), Vector3(0.45, 0.80, 0.40).normalized(), _aim]
		"sweep":
			return [Vector3(-0.60, 0.62, -1.25), Vector3(-0.85, -0.15, 0.50).normalized(), _aim]
		"slog_sweep":
			return [Vector3(-0.50, 1.35, -1.05), Vector3(-0.45, 0.60, 0.65).normalized(), _aim]
		"reverse_sweep":
			return [Vector3(0.10, 0.70, -1.35), Vector3(0.80, -0.05, 0.60).normalized(), _aim]
		"scoop":
			return [Vector3(-0.20, 1.05, -1.35), Vector3(0.0, 0.90, -0.40).normalized(), Vector3(0, 0, 1)]
		"helicopter":
			return [Vector3(-0.30, 1.85, -0.85), Vector3(0.95, 0.30, 0.0).normalized(), Vector3(0, 0, -1)]
	var g := Vector3(-0.22, 1.36, -0.95) + _aim * 0.32
	var dd := (-_aim * 0.55 + Vector3(0, 0.55, 0.45)).normalized()
	return [g, dd, (_aim + up * 0.6).normalized()]

func _update(delta: float) -> void:
	_t += delta
	_clock += delta
	var key: Array = STANCE_BAT
	var k := 1.0
	var stride := 0.0
	var lift: Array = [LIFT_BAT[0] + Vector3(0, _lift_y - 1.02, 0), LIFT_BAT[1], LIFT_BAT[2]]
	match phase:
		Phase.STANCE:
			key = STANCE_BAT
			k = 1.0
		Phase.BACKLIFT:
			key = lift
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
			if _style == "helicopter":
				# The whip: the blade circles over the head as the wrists roll through.
				var spin := clampf((_t - 0.06) / 0.5, 0.0, 1.0)
				var th := spin * TAU * 1.25
				key = [key[0], Vector3(cos(th) * 0.95, 0.30, -sin(th) * 0.95).normalized(), Vector3(-sin(th), 0, -cos(th))]
			if _t > 1.25:
				_go(Phase.RECOVER)
		Phase.RECOVER:
			key = STANCE_BAT
			k = smoothstep(0.0, 0.45, _t)
			if _t > 0.45:
				phase = Phase.STANCE
		Phase.CELEBRATE:
			_celebrate_pose()
			return
	var g: Vector3 = (_from.g as Vector3).lerp(key[0], k)
	var d: Vector3 = (_from.d as Vector3).slerp(key[1], k).normalized()
	var f: Vector3 = (_from.f as Vector3).slerp(key[2], k).normalized()
	if phase == Phase.STANCE:
		# Idle: tap the bat.
		g.y += 0.025 * maxf(0.0, sin(_clock * _tap))
	bat.place(g, d, f)

	var p := Figure.Pose.new()
	var bob := 0.012 * sin(_clock * 2.4)
	p.hips = Vector3(-0.36, _crouch + bob, -0.93)
	p.hip_yaw = deg_to_rad(-82.0)
	p.chest_yaw = deg_to_rad(-70.0)
	p.lean = 0.42
	p.head_yaw = deg_to_rad(-12.0)
	p.foot_r = Vector3(-0.34, 0, -0.68)
	p.foot_l = Vector3(-0.34, 0, _front_z)
	var follow := phase == Phase.FOLLOW
	if stride > 0.0 or follow:
		var turn := atan2(_aim.x, -_aim.z)
		var fk := k if follow else 0.0
		match _style:
			"sweep", "slog_sweep", "reverse_sweep":
				# Down on the back knee, front leg out toward the ball.
				p.hips = p.hips.lerp(Vector3(-0.42, 0.50, -1.12), stride)
				p.foot_l = p.foot_l.lerp(Vector3(-0.12, 0, -1.72), stride)
				p.foot_r = p.foot_r.lerp(Vector3(-0.62, 0, -0.48), stride)
				p.lean = lerpf(p.lean, 0.62, stride)
				var to := deg_to_rad(-25.0) if _style == "reverse_sweep" else deg_to_rad(-105.0)
				p.chest_yaw = lerp_angle(p.chest_yaw, to, stride)
				if follow and _style == "slog_sweep":
					p.lean = lerpf(p.lean, 0.35, fk)
			"scoop":
				p.hips = p.hips.lerp(Vector3(-0.30, 0.62, -1.15), stride)
				p.foot_l = p.foot_l.lerp(Vector3(-0.05, 0, -1.55), stride)
				p.foot_r = p.foot_r.lerp(Vector3(-0.60, 0, -0.62), stride)
				p.lean = lerpf(p.lean, 0.72, stride)
				p.chest_yaw = lerp_angle(p.chest_yaw, deg_to_rad(-88.0), stride)
				if follow:
					p.lean = lerpf(p.lean, 0.45, fk)
			"one_leg_pull", "pull", "hook":
				# Weight back and round; on the big one the front leg comes right up.
				p.hips = p.hips.lerp(Vector3(-0.40, 0.88, -0.80), stride)
				p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.8 - deg_to_rad(20.0), stride)
				p.lean = lerpf(p.lean, 0.12 if _style != "pull" else 0.2, stride)
				p.side_lean = lerpf(0.0, -0.12, stride)
				if _style == "one_leg_pull":
					p.foot_l = p.foot_l.lerp(Vector3(-0.66, 0.42, -1.02), stride)
					p.hips.y += 0.04 * stride
				if follow:
					p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.95, fk)
			"cut", "upper_cut":
				# Back and across to the off side.
				p.foot_r = p.foot_r.lerp(Vector3(0.02, 0, -0.78), stride)
				p.hips = p.hips.lerp(Vector3(-0.22, 0.84, -0.86), stride)
				p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.6 - deg_to_rad(35.0), stride)
				p.lean = lerpf(p.lean, 0.32 if _style == "cut" else 0.05, stride)
			"helicopter":
				# Front leg clears to leg side; then everything opens up as the bat whirls.
				p.foot_l = p.foot_l.lerp(Vector3(-0.66, 0, -1.30), stride)
				p.hips = p.hips.lerp(Vector3(-0.45, 0.74, -1.02), stride)
				p.lean = lerpf(p.lean, 0.55, stride)
				p.chest_yaw = lerp_angle(p.chest_yaw, deg_to_rad(-50.0), stride)
				if follow:
					p.hips = p.hips.lerp(Vector3(-0.45, 0.92, -1.02), fk)
					p.lean = lerpf(p.lean, 0.05, fk)
					p.chest_yaw = lerp_angle(p.chest_yaw, deg_to_rad(-5.0), fk)
			_:
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
				if follow:
					p.lean = lerpf(p.lean, 0.5 if _style == "defend" else (0.35 if _style == "drive" else 0.12), k)
					p.chest_yaw = lerp_angle(p.chest_yaw, turn * 0.9, k)
	elif phase == Phase.BACKLIFT:
		p.hips.y -= 0.03 * k
	var steps := _steps(delta)
	if steps > 0.0:
		# Quick shuffling steps down (or back up) the pitch: back foot chases the front.
		var ph := steps * PI
		p.foot_l.y += 0.14 * maxf(0.0, sin(ph * 2.0))
		p.foot_r.y += 0.14 * maxf(0.0, -sin(ph * 2.0))
		p.foot_r.z -= 0.25 * maxf(0.0, sin(ph))
		p.hips.y += 0.03 * absf(sin(ph * 2.0))
	var bd := -bat.basis.y
	p.hand_l = bat.position - bd * 0.07
	p.hand_r = bat.position + bd * 0.06
	if follow and _style in ["one_leg_pull", "helicopter", "slog_sweep"] and _t > 0.25:
		# Bottom hand comes off on the big finish.
		p.hand_r = p.hand_r.lerp(Vector3(-0.05, 1.05, -0.95), clampf((_t - 0.25) / 0.2, 0.0, 1.0))
	figure.apply(p)

func _celebrate_pose() -> void:
	var p := Figure.Pose.new()
	var e := smoothstep(0.0, 0.35, _t)
	var jump := 0.0
	if _cele == "win":
		jump = 0.2 * absf(sin(_t * 6.5)) * e
	p.hips = Vector3(-0.36, 0.93 + jump, -0.93)
	p.hip_yaw = deg_to_rad(-82.0)
	p.chest_yaw = deg_to_rad(-55.0)
	p.lean = -0.06
	p.head_yaw = deg_to_rad(10.0)
	p.foot_r = Vector3(-0.30, jump, -0.72)
	p.foot_l = Vector3(-0.30, jump, -1.12)
	# Bat held high in the top hand, the other arm up too.
	var grip := Vector3(-0.22, 1.98 + jump, -0.80).lerp(Vector3(-0.22, 1.98 + jump, -0.80), 1.0)
	var start: Vector3 = _from.g
	grip = start.lerp(grip, e)
	var wave := 0.06 * sin(_t * 5.0)
	bat.place(grip, (_from.d as Vector3).slerp(Vector3(0.10, 1.0, -0.05 + wave).normalized(), e).normalized(), Vector3(1, 0, 0))
	p.hand_r = grip
	p.hand_l = Vector3(-0.62, 1.70 + jump, -1.15).lerp(Vector3(-0.62, 1.98 + jump, -1.25), 0.5 + 0.5 * sin(_t * 5.0))
	if _cele == "win":
		p.hand_l = Vector3(-0.60, 2.0 + jump, -1.2)
	figure.apply(p)
