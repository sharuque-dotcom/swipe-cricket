class_name Fielder
extends Node3D
## A fielder: crouches ready as the bowler runs in, runs to where the ball will be, and
## takes it in their hands: a catch at whatever height it arrives, or a stop on the grass.

enum Mode { STAND, READY, RUN, CATCH, STOP, THROW, DIVE, SLIDE, CELEBRATE }

const CATCH_REACH := 0.30    # how far in front of the body the hands take a catch
const STOP_REACH := 0.50

var figure: Body
var home := Vector3.ZERO
var mode := Mode.STAND
var _target := Vector3.ZERO
var _arrive := 0.0          # seconds until they should reach the target
var _t := 0.0
var _keeper := false
var _end_mode := Mode.STOP
var _take_height := 1.0
var _face_to := Vector3.ZERO  # what to face once there
var _lift := 0.0              # how far off the grass the body is in a dive
var _settle := 0.22           # seconds before arrival that the hands go for the ball
var _pace := 0.0              # running speed, m/s
var _cele := "jump_loop"

func build(kit: Color, trim: Color, keeper: bool) -> void:
	_keeper = keeper
	figure = Body.new()
	figure.kit = kit
	figure.trim = trim
	figure.pads = keeper
	figure.gloves = keeper
	figure.skin = Body.skin_for(get_instance_id())
	add_child(figure)
	figure.build()
	_cele = ["jump_loop", "dance", "leap"][get_instance_id() % 3]
	_pose(0.0)

## Back to their spot, facing the batter.
func reset(spot: Vector3) -> void:
	home = spot
	position = spot
	mode = Mode.STAND
	_tilt(0.0, 0.0)
	_face(Vector3.ZERO)
	_pose(0.0)

func _tilt(angle: float, lift: float) -> void:
	figure.rotation.x = angle
	figure.position.y = lift

func ready_up() -> void:
	if mode == Mode.STAND:
		mode = Mode.READY
		_pose(0.0)

## Meet the ball at `ball_at` in `seconds`. `ball_dir` is the way the ball is travelling
## when it gets there; the fielder sets up behind that point, facing the ball, so that
## their hands are exactly where the ball arrives.
func go(ball_at: Vector3, seconds: float, catching: bool, height: float = 0.0, ball_dir: Vector3 = Vector3.ZERO) -> void:
	var here := Vector3(position.x, 0.0, position.z)
	var flat := Vector3(ball_at.x, 0.0, ball_at.z)
	var run := flat - here
	var dist := run.length()
	var pace := dist / maxf(seconds, 0.05)
	var dir := Vector3(ball_dir.x, 0.0, ball_dir.z)
	if dir.length() < 0.01:
		dir = run
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	_take_height = height
	_end_mode = Mode.CATCH if catching else Mode.STOP
	var facing := -dir
	_settle = 0.22
	# At full stretch they leave their feet: a dive for a catch or a stop they only just
	# reach, a feet-first slide to haul the ball in at the rope.
	if dist > 1.5:
		var run_dir := run / dist
		if not catching and Pitch.distance_from_centre(flat) > 55.0 and pace > 2.5:
			_end_mode = Mode.SLIDE
			facing = run_dir
			_settle = 0.34
		elif pace > (4.2 if catching else 5.0) or (catching and height < 0.45 and pace > 2.5):
			_end_mode = Mode.DIVE
			facing = run_dir
			_settle = 0.30
	# Work out where the hands end up in the final pose, and stand so that is where the ball is.
	var keep := mode
	var keep_yaw := rotation.y
	rotation.y = atan2(-facing.x, -facing.z)
	_lift = 0.0
	mode = _end_mode
	_pose(1.0)
	var off := hands_global() - global_position
	if _end_mode == Mode.DIVE:
		_lift = maxf(clampf(height, 0.14, 1.4) - off.y, 0.1)
	mode = keep
	rotation.y = keep_yaw
	_tilt(0.0, 0.0)
	_pose(0.0)
	_target = flat - Vector3(off.x, 0.0, off.z)
	_face_to = _target + facing * 5.0
	_arrive = maxf(seconds, 0.05)
	_pace = Vector3(_target.x - position.x, 0, _target.z - position.z).length() / _arrive
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
	_pace = dist / _arrive
	_t = 0.0
	mode = Mode.RUN

## A wicket: run to `at` (or stay put if it is where they are) and celebrate there,
## facing `centre`.
func celebrate(at: Vector3, seconds: float, centre: Vector3) -> void:
	figure.set_face("joy", 3.5)
	_tilt(0.0, 0.0)
	_t = 0.0
	_face_to = centre
	if Vector3(at.x, 0, at.z).distance_to(Vector3(position.x, 0, position.z)) < 0.5:
		mode = Mode.CELEBRATE
		_face(centre)
		return
	_target = Vector3(at.x, 0.0, at.z)
	_end_mode = Mode.CELEBRATE
	_settle = 0.05
	_arrive = maxf(seconds, 0.3)
	_pace = Vector3(at.x - position.x, 0, at.z - position.z).length() / _arrive
	mode = Mode.RUN

## Arm comes through to throw the ball in.
func throw_to(p: Vector3) -> void:
	_tilt(0.0, 0.0)
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
	delta = minf(delta, 0.05)   # same cap as the ball's clock, so a slow frame keeps them in step
	if mode == Mode.THROW or mode == Mode.CELEBRATE:
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
	if left <= _settle:
		mode = _end_mode
		_face(_face_to)
		_pose(1.0 - left / _settle)
		mode = Mode.RUN if left > 0.0 else _end_mode
	else:
		_pose(_t)

func _pose(time: float) -> void:
	var b := figure
	match mode:
		Mode.STAND:
			b.release()
			b.play("idle")
		Mode.READY:
			# Crouched, hands out in front, weight forward.
			var low := 0.55 if _keeper else 0.72
			b.hold("keeper" if _keeper else "ready", 0.0)
			b.reach(Vector3(-0.16, low - 0.1, -0.4), Vector3(0.16, low - 0.1, -0.4), 0.85)
		Mode.RUN:
			b.release()
			if _pace > 5.0:
				b.play("sprint", clampf(_pace / 6.5, 0.7, 1.4))
			elif _pace > 0.6:
				b.play("jog", clampf(_pace / 3.6, 0.6, 1.5))
			else:
				b.play("idle")
		Mode.CATCH:
			# Hands cupped where the ball arrives: overhead (jumping if need be), chest or shin.
			var h := clampf(_take_height, 0.12, 2.6)
			if h > 2.1:
				b.play("jump_loop")
			elif h < 0.5:
				b.hold("stoop", 0.0)
			elif h < 0.9:
				b.hold("ready", 0.0)
			else:
				b.play("idle")
			b.reach(Vector3(-0.07, h, -CATCH_REACH), Vector3(0.07, h, -CATCH_REACH), smoothstep(0.0, 0.6, time))
		Mode.STOP:
			# Bent down, hands to the grass.
			b.hold("stoop", 0.0)
			b.reach(Vector3(-0.07, 0.07, -STOP_REACH), Vector3(0.07, 0.07, -STOP_REACH), smoothstep(0.0, 0.6, time))
		Mode.DIVE:
			# Full length, arms out in front; `time` runs 0..1 as they launch.
			var d := smoothstep(0.0, 1.0, time)
			b.hold("jump_loop", 0.5)
			b.reach(Vector3(-0.07, 1.98, -0.06), Vector3(0.07, 1.98, -0.06), 1.0)
			_tilt(-1.42 * d, _lift * d)
		Mode.SLIDE:
			# Feet first, a hand down to drag the ball back.
			var d := smoothstep(0.0, 1.0, time)
			b.play("slide")
			b.reach(Vector3(0.20, 0.72, -0.42), Vector3(0.34, 0.70, -0.42), 1.0)
			_tilt(1.05 * d, 0.10 * d)
		Mode.CELEBRATE:
			b.release()
			b.play(_cele)
		Mode.THROW:
			b.release()
			b.play("throw", 1.6, 0.08, time < 0.05)
