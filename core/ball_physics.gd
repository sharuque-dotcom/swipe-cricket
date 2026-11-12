class_name BallPhysics
extends RefCounted
## Deterministic fixed-step cricket ball model: gravity, drag, Magnus force,
## conventional swing, and a friction bounce that turns spin into deviation.

const RADIUS := 0.036
const GRAVITY := 9.81
const DRAG_K := 0.00704      # 0.5 * rho * Cd * A / m
const MAGNUS_K := 0.000564   # 0.5 * rho * A * r / m
const SWING_K := 0.0031      # side-force coefficient at full swing
const SWING_MIN_SPEED := 14.0
const DT := 1.0 / 240.0

const PITCH_RESTITUTION := 0.56
const PITCH_FRICTION := 0.26
const PITCH_GRIP := 0.85
const FIELD_RESTITUTION := 0.40
const FIELD_GRIP := 0.5
const FIELD_FRICTION := 0.34
const ROLL_DECEL := 2.3
const REST_SPEED := 0.25

class State:
	extends RefCounted
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO     # angular velocity, rad/s
	var swing := 0.0             # -1..1, positive moves the ball toward +X
	var time := 0.0
	var bounces := 0
	var rolling := false
	var at_rest := false
	var last_bounce := Vector3.ZERO

	func copy() -> State:
		var s := State.new()
		s.pos = pos
		s.vel = vel
		s.spin = spin
		s.swing = swing
		s.time = time
		s.bounces = bounces
		s.rolling = rolling
		s.at_rest = at_rest
		s.last_bounce = last_bounce
		return s

static func step(s: State, dt: float = DT) -> void:
	s.time += dt
	if s.at_rest:
		return
	if s.rolling:
		_roll(s, dt)
		return
	var speed := s.vel.length()
	var acc := Vector3(0.0, -GRAVITY, 0.0)
	acc -= s.vel * (DRAG_K * speed)
	acc += s.spin.cross(s.vel) * MAGNUS_K
	if s.swing != 0.0 and s.bounces == 0 and speed > SWING_MIN_SPEED:
		var h := Vector3(s.vel.x, 0.0, s.vel.z)
		if h.length_squared() > 0.0001:
			h = h.normalized()
			acc += Vector3(h.z, 0.0, -h.x) * (SWING_K * s.swing * speed * speed)
	s.vel += acc * dt
	var prev := s.pos
	s.pos += s.vel * dt
	if s.pos.y <= RADIUS and s.vel.y < 0.0:
		# Pull back to the exact point of ground contact so landing spots are not step-quantised.
		if prev.y > RADIUS:
			s.pos = prev.lerp(s.pos, (prev.y - RADIUS) / (prev.y - s.pos.y))
		_bounce(s)

static func _bounce(s: State) -> void:
	var on_pitch := Pitch.on_pitch(s.pos)
	var e := PITCH_RESTITUTION if on_pitch else FIELD_RESTITUTION
	var mu := PITCH_FRICTION if on_pitch else FIELD_FRICTION
	var vn := -s.vel.y
	s.pos.y = RADIUS
	s.last_bounce = Vector3(s.pos.x, 0.0, s.pos.z)
	s.bounces += 1
	# Slip velocity of the contact point: v_t + spin x (0, -r, 0).
	var slip := Vector3(s.vel.x + RADIUS * s.spin.z, 0.0, s.vel.z - RADIUS * s.spin.x)
	var fwd := Vector3(s.vel.x, 0.0, s.vel.z)
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3(0.0, 0.0, 1.0)
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	var slip_f := slip.dot(fwd)
	var slip_s := slip.dot(side)
	# Across the line of flight the seam grips, so side spin becomes turn.
	# Along it the ball skids, limited by sliding friction.
	var grip := PITCH_GRIP if on_pitch else FIELD_GRIP
	var j := side * (-slip_s * (2.0 / 7.0) * grip) \
		+ fwd * (-signf(slip_f) * minf(mu * (1.0 + e) * vn, absf(slip_f) * 2.0 / 7.0))
	s.vel.x += j.x
	s.vel.z += j.z
	s.spin += Vector3(-j.z, 0.0, j.x) * (2.5 / RADIUS)
	s.vel.y = vn * e
	if s.vel.y < 0.7:
		s.vel.y = 0.0
		s.rolling = true

static func _roll(s: State, dt: float) -> void:
	var h := Vector3(s.vel.x, 0.0, s.vel.z)
	var speed := h.length()
	var new_speed := speed - (ROLL_DECEL + DRAG_K * speed * speed) * dt
	if new_speed <= REST_SPEED:
		s.vel = Vector3.ZERO
		s.at_rest = true
		return
	s.vel = h / speed * new_speed
	s.pos += s.vel * dt
	s.pos.y = RADIUS

## Advances a copy until it crosses the plane z = `z`; returns null if it never does.
static func state_at_z(start: State, z: float, max_time: float = 4.0) -> State:
	var s := start.copy()
	var limit := s.time + max_time
	while s.time < limit and not s.at_rest:
		var prev_pos := s.pos
		var prev_time := s.time
		step(s)
		if prev_pos.z < z and s.pos.z >= z:
			var t := (z - prev_pos.z) / (s.pos.z - prev_pos.z)
			s.pos = prev_pos.lerp(s.pos, t)
			s.time = lerpf(prev_time, s.time, t)
			return s
	return null

## Advances a copy until its first bounce; returns null if none within `max_time`.
static func state_at_first_bounce(start: State, max_time: float = 4.0) -> State:
	var s := start.copy()
	var limit := s.time + max_time
	while s.time < limit:
		step(s)
		if s.bounces > 0:
			return s
	return null
