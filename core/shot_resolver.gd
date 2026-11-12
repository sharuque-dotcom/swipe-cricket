class_name ShotResolver
extends RefCounted
## Turns a swing and the ball's real trajectory into what happens next.
## Nothing here is random: the same ball and the same swing give the same shot.

enum Outcome { MISS, EDGE, HIT }

class Swing:
	extends RefCounted
	var angle := 0.0          # 0 = straight back past the bowler, +90deg = square on the off side
	var power := 0.5          # 0..1
	var loft := 0.0           # 0..1
	var contact_time := 0.0   # ball-clock time at which the bat arrives

class Result:
	extends RefCounted
	var outcome := Outcome.MISS
	var timing_n := 0.0        # normalised: negative early, positive late
	var timing_ms := 0.0
	var quality := 0.0
	var contact_time := 0.0
	var contact_pos := Vector3.ZERO
	var exit: BallPhysics.State = null
	var shot_name := ""
	var reason := ""

	func timing_label() -> String:
		var a := absf(timing_n)
		if a <= Tuning.PERFECT_N:
			return "PERFECT"
		var side := "EARLY" if timing_n < 0.0 else "LATE"
		if a <= Tuning.CLEAN_N:
			return side
		return "TOO " + side

static func state_at_time(start: BallPhysics.State, t: float) -> BallPhysics.State:
	var s := start.copy()
	while s.time + BallPhysics.DT <= t:
		BallPhysics.step(s)
	var rem := t - s.time
	if rem > 0.000001:
		BallPhysics.step(s, rem)
	return s

## Times at which the ball enters and leaves the hitting zone. Empty if it never arrives.
static func hit_window(ball: BallPhysics.State) -> Dictionary:
	var a := BallPhysics.state_at_z(ball, Tuning.HIT_ZONE_FRONT_Z)
	var b := BallPhysics.state_at_z(ball, Tuning.HIT_ZONE_BACK_Z)
	if a == null or b == null:
		return {}
	var half := (b.time - a.time) * 0.5 + Tuning.BAT_DWELL * 0.5
	return {"t_in": a.time, "t_out": b.time, "t_mid": (a.time + b.time) * 0.5, "half": half}

static func resolve(ball: BallPhysics.State, swing: Swing) -> Result:
	var r := Result.new()
	var w := hit_window(ball)
	if w.is_empty():
		r.reason = "Ball never reached the bat"
		return r
	r.timing_n = (swing.contact_time - w.t_mid) / w.half
	r.timing_ms = (swing.contact_time - w.t_mid) * 1000.0
	if absf(r.timing_n) > 1.0:
		r.reason = "Swung too early" if r.timing_n < 0.0 else "Swung too late"
		return r
	r.contact_time = clampf(swing.contact_time, w.t_in, w.t_out)
	var at := state_at_time(ball, r.contact_time)
	r.contact_pos = at.pos
	if at.pos.x < Tuning.REACH_LEG_X or at.pos.x > Tuning.REACH_OFF_X or at.pos.y > Tuning.REACH_TOP_Y:
		r.reason = "Out of reach"
		return r

	var speed_in := at.vel.length()
	var n := r.timing_n
	var deg := rad_to_deg(swing.angle)
	var behind := absf(deg) > 130.0
	var horizontal := absf(deg) > 50.0 and not behind
	r.shot_name = _name(deg, at.pos.y, swing.loft)

	if absf(n) > Tuning.CLEAN_N:
		r.outcome = Outcome.EDGE
		r.quality = 0.1
		var edge_speed := 0.5 * speed_in + 3.0
		if n > 0.0:
			# Late: thick outside edge, flying behind square on the off side.
			r.shot_name = "Outside edge"
			r.exit = _exit(at, deg_to_rad(158.0), deg_to_rad(9.0), edge_speed)
		else:
			# Early: leading edge, looping up in front.
			r.shot_name = "Leading edge"
			r.exit = _exit(at, deg_to_rad(25.0), deg_to_rad(52.0), 9.0)
		return r

	# Timing quality: flat inside the perfect window, falling away toward the edge zone.
	var q_time := 1.0
	if absf(n) > Tuning.PERFECT_N:
		var k := (absf(n) - Tuning.PERFECT_N) / (Tuning.CLEAN_N - Tuning.PERFECT_N)
		q_time = 1.0 - 0.7 * pow(k, 1.4)
	# Is this the right shot for the ball's height?
	var y := at.pos.y
	var lo := 0.55 if horizontal else 0.10
	var hi := 1.55 if horizontal else 1.0
	var off_h := maxf(maxf(lo - y, y - hi), 0.0)
	var q_height := 1.0 - 0.6 * clampf(off_h / 0.5, 0.0, 1.0)
	# Hitting against the line costs control.
	var side := signf(sin(swing.angle))
	var against := clampf(-side * (at.pos.x - 0.05) / 0.6, 0.0, 1.0)
	var q_line := 1.0 - 0.5 * against * absf(sin(swing.angle))

	r.outcome = Outcome.HIT
	r.quality = q_time * q_height * q_line
	var bat_speed := lerpf(Tuning.BAT_SPEED_MIN, Tuning.BAT_SPEED_MAX, clampf(swing.power, 0.0, 1.0))
	if behind:
		bat_speed *= 0.3
	var out_speed := (Tuning.BALL_SPEED_CARRY * speed_in + Tuning.BAT_SPEED_CARRY * bat_speed) \
		* lerpf(0.4, 1.0, r.quality)
	if behind:
		out_speed = maxf(out_speed, 0.6 * speed_in * lerpf(0.5, 1.0, r.quality))
	# Late sends the ball squarer on the off side; early drags it to leg and up.
	var out_angle := swing.angle + n * Tuning.MISTIME_ANGLE
	var elev := lerpf(Tuning.LOFT_MIN, Tuning.LOFT_MAX, clampf(swing.loft, 0.0, 1.0))
	elev += maxf(0.0, -n) * deg_to_rad(16.0) - maxf(0.0, n) * deg_to_rad(4.0)
	if not horizontal and y > 1.0:
		elev += deg_to_rad(8.0)
	elev += (1.0 - q_height) * deg_to_rad(14.0)
	r.exit = _exit(at, out_angle, elev, out_speed)
	# Lofted shots carry backspin, which holds them up.
	var flat := Vector3(r.exit.vel.x, 0.0, r.exit.vel.z).normalized()
	r.exit.spin = Vector3(flat.z, 0.0, -flat.x) * (-90.0 * swing.loft)
	return r

static func _exit(at: BallPhysics.State, angle: float, elev: float, speed: float) -> BallPhysics.State:
	var s := BallPhysics.State.new()
	s.pos = at.pos
	s.time = at.time
	var flat := Vector3(sin(angle), 0.0, -cos(angle))
	s.vel = (flat * cos(elev) + Vector3.UP * sin(elev)) * speed
	return s

static func _name(deg: float, y: float, loft: float) -> String:
	var a := absf(deg)
	var off := deg >= 0.0
	var base := ""
	if a <= 15.0:
		base = "Straight drive"
	elif a <= 50.0:
		base = "Off drive" if off and a <= 30.0 else ("Cover drive" if off else "On drive")
	elif a <= 130.0:
		if off:
			base = "Square cut" if a <= 100.0 else "Late cut"
		elif y > 1.3:
			base = "Hook"
		elif y > 0.7:
			base = "Pull"
		else:
			base = "Flick" if a <= 95.0 else "Sweep"
	else:
		base = "Dab" if off else "Leg glance"
	if loft > 0.5 and a <= 130.0:
		return "Lofted " + base.to_lower()
	return base
