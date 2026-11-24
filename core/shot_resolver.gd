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
	var skill: BatterSkill = null   # who is batting; null plays as the best batter
	var advance := 0.0        # how far down the pitch they have come, metres (stepping out)
	var intent := ""          # "defend", "ground", "lofted" or "" (as the swipe says)
	var shuffle := 0.0        # how far the batter has moved across, metres (+ toward the off side)

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
	var style := ""            # which batting animation plays: see Batter.swing
	var reason := ""
	# The timing zones this swing was judged against: they depend on the batter and the shot.
	var perfect_n := Tuning.PERFECT_N
	var clean_n := Tuning.CLEAN_N

	func timing_label() -> String:
		var a := absf(timing_n)
		if a <= perfect_n:
			return "PERFECT"
		var side := "EARLY" if timing_n < 0.0 else "LATE"
		if a <= clean_n:
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
## `advance` moves the zone up the pitch for a batter who has stepped out.
static func hit_window(ball: BallPhysics.State, advance: float = 0.0) -> Dictionary:
	var a := BallPhysics.state_at_z(ball, Tuning.HIT_ZONE_FRONT_Z - advance)
	var b := BallPhysics.state_at_z(ball, Tuning.HIT_ZONE_BACK_Z - advance)
	if a == null or b == null:
		return {}
	var half := (b.time - a.time) * 0.5 + Tuning.BAT_DWELL * 0.5
	return {"t_in": a.time, "t_out": b.time, "t_mid": (a.time + b.time) * 0.5, "half": half}

static func resolve(ball: BallPhysics.State, swing: Swing) -> Result:
	var r := Result.new()
	var sk := swing.skill if swing.skill != null else BatterSkill.new()
	var pw := clampf(swing.power, 0.0, 1.0)
	var lf := clampf(swing.loft, 0.0, 1.0)
	match swing.intent:
		"defend":
			pw = minf(pw, Tuning.DEFEND_POWER)
			lf = 0.0
		"ground":
			lf = 0.0
		"lofted":
			lf = lerpf(Tuning.LOFT_FLOOR, 1.0, lf)
	# A controlled push has a wide sweet zone; a full-blooded lofted swing a narrow one.
	var control := 1.0 - Tuning.POWER_CONTROL_COST * pw * pw - Tuning.LOFT_CONTROL_COST * lf * pw
	r.perfect_n = Tuning.PERFECT_N * sk.sweet_scale() * control
	r.clean_n = Tuning.CLEAN_N * sk.clean_scale() * (1.0 - 0.10 * lf * pw)
	if swing.intent == "defend":
		r.clean_n = minf(r.clean_n * Tuning.DEFEND_CLEAN, 0.97)
		r.perfect_n = minf(r.perfect_n * Tuning.DEFEND_SWEET, r.clean_n * 0.75)
	var w := hit_window(ball, swing.advance)
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
	var rs := sk.reach_scale()
	var rx := at.pos.x - swing.shuffle   # across the pitch from where the batter now stands
	if rx < Tuning.REACH_LEG_X * rs or rx > Tuning.REACH_OFF_X * rs or at.pos.y > Tuning.REACH_TOP_Y:
		r.reason = "Out of reach"
		return r

	var speed_in := at.vel.length()
	var n := r.timing_n
	var deg := rad_to_deg(swing.angle)
	var behind := absf(deg) > 130.0
	var horizontal := absf(deg) > 50.0 and not behind
	var named := shot(deg, at.pos.y, lf, speed_in < SPIN_SPEED, swing.advance > 0.0)
	r.shot_name = named[0]
	r.style = named[1]
	if swing.intent == "defend":
		r.shot_name = "Forward defence" if at.pos.z < -1.25 or swing.advance > 0.0 else "Back-foot defence"
		r.style = "defend"

	if absf(n) > r.clean_n:
		r.outcome = Outcome.EDGE
		r.quality = 0.1
		var edge_speed := 0.5 * speed_in + 3.0
		if swing.intent == "defend":
			edge_speed *= 0.45   # soft hands: it drops short of the cordon
		if n > 0.0:
			# Late: outside edge behind the wicket. The later the bat, the finer it goes:
			# a thin one carries to the keeper, thicker ones to slip or down to third man.
			r.shot_name = "Outside edge"
			r.style = "edge"
			var fine := clampf((n - r.clean_n) / maxf(1.0 - r.clean_n, 0.01), 0.0, 1.0)
			var up := deg_to_rad(9.0 + clampf((30.0 - speed_in) * 0.35, 0.0, 5.0))
			r.exit = _exit(at, deg_to_rad(lerpf(140.0, 177.0, fine)), up, edge_speed)
		else:
			# Early: leading edge, looping up in front.
			r.shot_name = "Leading edge"
			r.style = "edge"
			r.exit = _exit(at, deg_to_rad(25.0), deg_to_rad(52.0), 9.0)
		return r

	# Timing quality: flat inside the perfect window, falling away toward the edge zone.
	var q_time := 1.0
	if absf(n) > r.perfect_n:
		var k := (absf(n) - r.perfect_n) / (r.clean_n - r.perfect_n)
		q_time = 1.0 - 0.85 * pow(k, Tuning.MISTIME_FALLOFF)
	# Is this the right shot for the ball's height?
	var y := at.pos.y
	var lo := 0.55 if horizontal else 0.10
	var hi := 1.55 if horizontal else 1.0
	var off_h := maxf(maxf(lo - y, y - hi), 0.0)
	var q_height := 1.0 - 0.6 * clampf(off_h / 0.5, 0.0, 1.0)
	# Hitting against the line costs control.
	var side := signf(sin(swing.angle))
	var against := clampf(-side * (rx - 0.05) / 0.6, 0.0, 1.0)
	var q_line := 1.0 - 0.5 * against * absf(sin(swing.angle))

	r.outcome = Outcome.HIT
	r.quality = q_time * q_height * q_line
	var bat_speed := lerpf(Tuning.BAT_SPEED_MIN, sk.bat_speed_max(), pw)
	if behind:
		bat_speed *= 0.3
	var out_speed := (Tuning.BALL_SPEED_CARRY * speed_in + Tuning.BAT_SPEED_CARRY * bat_speed) \
		* lerpf(0.4, 1.0, r.quality)
	if behind:
		out_speed = maxf(out_speed, 0.6 * speed_in * lerpf(0.5, 1.0, r.quality))
	# Late sends the ball squarer on the off side; early drags it to leg and up.
	var out_angle := swing.angle + n * Tuning.MISTIME_ANGLE * sk.scatter()
	var elev := lerpf(Tuning.LOFT_MIN, Tuning.LOFT_MAX, lf)
	elev += maxf(0.0, -n) * deg_to_rad(lerpf(7.0, 12.0, lf)) - maxf(0.0, n) * deg_to_rad(4.0)
	if not horizontal and y > 1.0:
		elev += deg_to_rad(8.0)
	elev += (1.0 - q_height) * deg_to_rad(14.0)
	elev += (1.0 - q_time) * lf * Tuning.MISTIME_SKY
	r.exit = _exit(at, out_angle, elev, out_speed)
	# Lofted shots carry backspin, which holds them up.
	var flat := Vector3(r.exit.vel.x, 0.0, r.exit.vel.z).normalized()
	r.exit.spin = Vector3(flat.z, 0.0, -flat.x) * (-90.0 * lf)
	return r

static func _exit(at: BallPhysics.State, angle: float, elev: float, speed: float) -> BallPhysics.State:
	var s := BallPhysics.State.new()
	s.pos = at.pos
	s.time = at.time
	var flat := Vector3(sin(angle), 0.0, -cos(angle))
	s.vel = (flat * cos(elev) + Vector3.UP * sin(elev)) * speed
	return s

## Balls slower than this at the bat are spin: the batter can sweep, reverse it, or dance down.
const SPIN_SPEED := 26.0

## The shot's name and the animation that goes with it, from where the swing was aimed
## (degrees, + is the off side), the height of the ball at the bat, the loft, and whether
## it was spin. Returns [name, style].
static func shot(deg: float, y: float, loft: float, spin: bool, charged: bool = false) -> Array:
	var a := absf(deg)
	var off := deg >= 0.0
	var lofted := loft > 0.5
	if a > 130.0:
		if lofted:
			return ["Ramp" if off else "Scoop", "scoop"]
		return ["Dab" if off else "Leg glance", "glance"]
	if a > 50.0:
		if off:
			if spin and y < 0.6 and a >= 70.0:
				return ["Reverse sweep", "reverse_sweep"]
			if lofted and y > 1.15:
				return ["Upper cut", "upper_cut"]
			var cut := "Square cut" if a <= 100.0 else "Late cut"
			return ["Lofted " + cut.to_lower() if lofted else cut, "cut"]
		if y > 1.3:
			return ["Hook" if not lofted else "Lofted hook", "hook"]
		if y > 0.7:
			return ["One-legged pull" if lofted else "Pull", "one_leg_pull" if lofted else "pull"]
		if spin and y < 0.6:
			return ["Slog sweep" if lofted else "Sweep", "slog_sweep" if lofted else "sweep"]
		if a > 95.0 and y < 0.6:
			return ["Sweep", "sweep"]
		return ["Lofted flick" if lofted else "Flick", "flick"]
	var base := ""
	if a <= 15.0:
		base = "Straight drive"
	elif off:
		base = "Off drive" if a <= 30.0 else "Cover drive"
	else:
		base = "On drive"
	if lofted and y < 0.36 and deg <= 20.0:
		return ["Helicopter shot", "helicopter"]
	if charged:
		return ["Down the track, " + ("lofted " if lofted else "") + base.to_lower(), "step_out" if lofted else "drive"]
	if lofted:
		return ["Lofted " + base.to_lower(), "loft_drive"]
	return [base, "drive"]
