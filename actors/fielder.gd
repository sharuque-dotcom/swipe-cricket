class_name Fielder
extends Node3D
## A fielder: crouches ready as the bowler runs in, runs to where the ball will be,
## and either takes the catch (hands up) or bends to stop it.

enum Mode { STAND, READY, RUN, CATCH, STOP }

var figure: Figure
var home := Vector3.ZERO
var mode := Mode.STAND
var _target := Vector3.ZERO
var _arrive := 0.0          # seconds until they should reach the target
var _t := 0.0
var _keeper := false

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

## Head for `target`, getting there in `seconds`; `catching` decides the final pose.
func go(target: Vector3, seconds: float, catching: bool) -> void:
	_target = Vector3(target.x, 0.0, target.z)
	_arrive = maxf(seconds, 0.05)
	_t = 0.0
	mode = Mode.RUN
	set_meta("catching", catching)

func _face(p: Vector3) -> void:
	var d := Vector3(p.x - position.x, 0.0, p.z - position.z)
	if d.length() > 0.2:
		rotation.y = atan2(-d.x, -d.z)

func _process(delta: float) -> void:
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
	_pose(_t)
	if left <= 0.0:
		mode = Mode.CATCH if get_meta("catching", false) else Mode.STOP
		_face(Vector3.ZERO)
		_pose(0.0)

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
			# Hands cupped above the head.
			p.hand_l = Vector3(-0.09, 1.95, -0.18)
			p.hand_r = Vector3(0.09, 1.95, -0.18)
			p.lean = -0.08
		Mode.STOP:
			# Bent down, hands to the grass.
			p.hips = Vector3(0, 0.7, 0.1)
			p.lean = 0.85
			p.foot_l = Vector3(-0.25, 0, 0.1)
			p.foot_r = Vector3(0.25, 0, -0.1)
			p.hand_l = Vector3(-0.1, 0.08, -0.55)
			p.hand_r = Vector3(0.1, 0.08, -0.55)
	figure.apply(p)
