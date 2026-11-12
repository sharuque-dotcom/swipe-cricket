class_name Fielder
extends Node3D
## A fielder: crouches ready as the bowler runs in, runs to where the ball will be, and
## takes it in their hands: a catch at whatever height it arrives, or a stop on the grass.

enum Mode { STAND, READY, RUN, CATCH, STOP, THROW }

const CATCH_REACH := 0.30    # how far in front of the body the hands take a catch
const STOP_REACH := 0.50

var figure: Figure
var home := Vector3.ZERO
var mode := Mode.STAND
var _target := Vector3.ZERO
var _arrive := 0.0          # seconds until they should reach the target
var _t := 0.0
var _keeper := false
var _end_mode := Mode.STOP
var _take_height := 1.0
var _face_to := Vector3.ZERO  # what to face once there

func build(kit: Color, trim: Color, keeper: bool) -> void:
	_keeper = keeper
	figure = Figure.new()
	figure.kit = kit
	figure.trim = trim
	figure.pads = keeper
	add_child(figure)
	figure.build()
	_pose(0.0)

## Back to their spot, facing the batter.
func reset(spot: Vector3) -> void:
	home = spot
	position = spot
	mode = Mode.STAND
	_face(Vector3.ZERO)
	_pose(0.0)

func ready_up() -> void:
	if mode == Mode.STAND:
		mode = Mode.READY
		_pose(0.0)

## Meet the ball at `ball_at` in `seconds`. `ball_dir` is the way the ball is travelling
## when it gets there; the fielder sets up behind that point, facing the ball, so that
## their hands are exactly where the ball arrives.
func go(ball_at: Vector3, seconds: float, catching: bool, height: float = 0.0, ball_dir: Vector3 = Vector3.ZERO) -> void:
	var flat := Vector3(ball_at.x, 0.0, ball_at.z)
	var dir := Vector3(ball_dir.x, 0.0, ball_dir.z)
	if dir.length() < 0.01:
		dir = flat - Vector3(position.x, 0.0, position.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	_end_mode = Mode.CATCH if catching else Mode.STOP
	_take_height = height
	_target = flat + dir * (CATCH_REACH if catching else STOP_REACH)
	_face_to = flat - dir * 5.0
	_arrive = maxf(seconds, 0.05)
	_t = 0.0
	mode = Mode.RUN

## Chase after a ball they will not get to: run that way, then pull up.
func chase(toward: Vector3, seconds: float, speed: float = 6.2) -> void:
	var here := Vector3(position.x, 0.0, position.z)
	var to := Vector3(toward.x, 0.0, toward.z) - here
	var dist := minf(to.length(), speed * seconds)
	if dist < 1.0:
		return
	_target = here + to.normalized() * dist
	_face_to = _target + to.normalized() * 5.0
	_end_mode = Mode.STAND
	_arrive = maxf(seconds, 0.05)
	_t = 0.0
	mode = Mode.RUN

## Arm comes through to throw the ball in.
func throw_to(p: Vector3) -> void:
	_face(p)
	mode = Mode.THROW
	_t = 0.0
	_pose(0.0)

## Stand at the stumps end and take a throw at chest height.
func take_throw(from: Vector3) -> void:
	_face(from)
	_take_height = 1.1
	mode = Mode.CATCH
	_pose(0.0)

func hands_global() -> Vector3:
	return figure.hands_global()

func _face(p: Vector3) -> void:
	var d := Vector3(p.x - position.x, 0.0, p.z - position.z)
	if d.length() > 0.2:
		rotation.y = atan2(-d.x, -d.z)

func _process(delta: float) -> void:
	if mode == Mode.THROW:
		_t += delta
		_pose(_t)
		return
	if mode != Mode.RUN:
		return
	_t += delta
	var left := maxf(_arrive - _t, 0.0)
	var to := _target - position
	var dist := to.length()
	if dist > 0.05:
		_face(_target)
		var step := dist if left <= delta else minf(dist, dist / left * delta)
		position += to.normalized() * step
	# Get the hands into position over the last strides so the take reads clearly.
	if left <= 0.22:
		mode = _end_mode
		_face(_face_to)
		_pose(0.0)
		mode = Mode.RUN if left > 0.0 else _end_mode
	else:
		_pose(_t)

func _pose(time: float) -> void:
	var p := Figure.Pose.new()
	match mode:
		Mode.STAND:
			p.hand_l = Vector3(-0.22, 0.92, -0.05)
			p.hand_r = Vector3(0.22, 0.92, -0.05)
		Mode.READY:
			# Crouched, hands out in front, weight forward.
			var low := 0.62 if _keeper else 0.78
			p.hips = Vector3(0, low, 0.05)
			p.lean = 0.55 if _keeper else 0.4
			p.foot_l = Vector3(-0.28, 0, 0)
			p.foot_r = Vector3(0.28, 0, 0)
			p.hand_l = Vector3(-0.16, low - 0.15, -0.38)
			p.hand_r = Vector3(0.16, low - 0.15, -0.38)
		Mode.RUN:
			var ph := time * 13.0
			var s := sin(ph)
			var c := cos(ph)
			p.hips = Vector3(0, 0.95 + 0.04 * absf(c), 0)
			p.lean = 0.25
			p.foot_l = Vector3(-0.11, maxf(0.0, c) * 0.25, 0.45 * s)
			p.foot_r = Vector3(0.11, maxf(0.0, -c) * 0.25, -0.45 * s)
			p.hand_l = Vector3(-0.27, 1.05 - 0.12 * s, -0.32 * s)
			p.hand_r = Vector3(0.27, 1.05 + 0.12 * s, 0.32 * s)
		Mode.CATCH:
			# Hands cupped where the ball arrives: overhead (jumping if need be), chest or shin.
			var h := clampf(_take_height, 0.12, 2.6)
			var jump := maxf(0.0, h - 2.0)
			var crouch := clampf((0.9 - h) / 0.8, 0.0, 1.0)
			p.hips = Vector3(0, 0.93 + jump - 0.30 * crouch, 0.08 * crouch)
			p.lean = lerpf(-0.08 if h > 1.5 else 0.12, 0.8, crouch)
			p.foot_l = Vector3(-0.16 - 0.1 * crouch, jump, 0)
			p.foot_r = Vector3(0.16 + 0.1 * crouch, jump, 0)
			p.hand_l = Vector3(-0.07, h, -CATCH_REACH)
			p.hand_r = Vector3(0.07, h, -CATCH_REACH)
		Mode.STOP:
			# Bent down, hands to the grass.
			p.hips = Vector3(0, 0.7, 0.1)
			p.lean = 0.85
			p.foot_l = Vector3(-0.25, 0, 0.1)
			p.foot_r = Vector3(0.25, 0, -0.1)
			p.hand_l = Vector3(-0.07, 0.07, -STOP_REACH)
			p.hand_r = Vector3(0.07, 0.07, -STOP_REACH)
		Mode.THROW:
			var u := clampf(time / 0.25, 0.0, 1.0)
			p.lean = lerpf(-0.1, 0.35, u)
			p.chest_yaw = lerpf(0.7, -0.3, u)
			p.foot_l = Vector3(-0.14, 0, -0.35)
			p.foot_r = Vector3(0.14, 0, 0.25)
			p.hand_l = Vector3(-0.25, 1.2, -0.35)
			p.hand_r = Vector3(0.30, lerpf(1.75, 1.35, u), lerpf(0.30, -0.60, u))
	figure.apply(p)
