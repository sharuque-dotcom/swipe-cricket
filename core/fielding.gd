class_name Fielding
extends RefCounted
## Fielders, catches and run-saving. Nothing here is random: a fielder catches the ball if
## they can reach it while it is still in the air at a catchable height, and stops it if they
## can reach it on the ground. How far they can reach grows with time after a short reaction.
## Runs come from how long the batters had: the time to stop the ball plus the throw back.

enum Kind { CLOSE, INFIELD, DEEP, KEEPER }

const REACTION := 0.30        # seconds before a fielder moves
const RUN_SPEED := 6.6        # metres per second, chasing a ball
const DIVE := 0.6             # extra reach when stopping a ball along the ground
const CLOSE_SPEED := 2.4      # keeper and slips mostly dive, they don't run
const CATCH_LOW := 0.08       # ball height window for a catch, metres
const CATCH_HIGH := 2.55
const STOP_HIGH := 1.5        # below this a moving ball can be fielded
const THROW_SPEED := 26.0     # m/s back to the stumps
const THROW_RELEASE := 0.55   # pick-up and release time
const STOP_CAP_IN := 30.0     # how far a fielder will chase a ball along the ground
const STOP_CAP_DEEP := 30.0
const CATCH_REACTION := 0.50  # a catch needs the fielder to read the ball first
const CATCH_RUN_SPEED := 4.0
const CATCH_CAP_IN := 5.5
const CATCH_CAP_DEEP := 12.0
const CATCH_HARD_SPEED := 24.0 # m/s; faster than this, only a dive will do
const RUN_TIME := 2.8         # seconds per run between the wickets
const MAX_RUNS := 3
const KEEPER_BACK_PACE := 14.5
const KEEPER_BACK_SPIN := 6.2

class Spot:
	extends RefCounted
	var name := ""
	var pos := Vector3.ZERO
	var kind := Kind.INFIELD
	var base_reach := 0.9

	func _init(n: String, x: float, z: float, k: int, reach: float) -> void:
		name = n
		pos = Vector3(x, 0.0, z)
		kind = k
		base_reach = reach

	## How far this fielder can get to take a catch. Catching needs them set under the ball, so
	## they react later and cover less ground than when stopping it; a hard-hit ball is only
	## caught within a dive.
	func catch_reach(t: float, ball_speed: float) -> float:
		var close := kind == Kind.CLOSE or kind == Kind.KEEPER
		if ball_speed > CATCH_HARD_SPEED:
			return base_reach + (0.6 if close else 0.4)
		var cap := 2.2 if close else (CATCH_CAP_DEEP if kind == Kind.DEEP else CATCH_CAP_IN)
		var speed := CLOSE_SPEED if close else CATCH_RUN_SPEED
		return minf(base_reach + speed * maxf(0.0, t - CATCH_REACTION), cap)

	func reach(t: float) -> float:
		var speed := CLOSE_SPEED if kind == Kind.CLOSE or kind == Kind.KEEPER else RUN_SPEED
		var cap := 2.6 if kind == Kind.CLOSE or kind == Kind.KEEPER else (STOP_CAP_DEEP if kind == Kind.DEEP else STOP_CAP_IN)
		return minf(base_reach + DIVE + speed * maxf(0.0, t - (0.2 if kind == Kind.CLOSE or kind == Kind.KEEPER else REACTION)), cap)

class Result:
	extends NetsScoring.Summary
	var caught := false
	var fielder := -1             # index into the layout, -1 if none involved
	var fielder_name := ""
	var field_pos := Vector3.ZERO # where the fielder meets the ball
	var field_time := 0.0         # seconds after contact
	var field_height := 0.0       # how high the ball is when they take it
	var field_dir := Vector3.ZERO # which way the ball is travelling when it reaches them
	var end_pos := Vector3.ZERO   # where the ball is when play ends (fielded, at rest, or over the rope)

# ---- Setting the field ----------------------------------------------------------------
# Angles are in degrees from the batter: 0 is straight back past the bowler, +90 square
# on the off side, -90 square on the leg side, 180 directly behind.

const MAX_OUT_POWERPLAY := 2   # fielders allowed outside the ring in overs 1 to 6
const MAX_OUT := 5             # and for the rest of the innings
const DEEP_IN_FROM_ROPE := 6.5
const INFIELD_DIST := 24.0     # how far from the bat the ring fielders stand, at most
const INFIELD_INSIDE_RING := 4.0
const SHOT_MEMORY := 12        # how many of a batter's shots the captain remembers
const SHOT_FADE := 0.86        # each older shot counts this much less
const DEEP_SHOT := 36.0        # a shot that travels this far needs a man in the deep

# Where a captain starts before they have seen the batter: [angle, weight].
const PRIOR_DEEP := [[-128.0, 1.00], [128.0, 0.92], [-80.0, 0.80], [14.0, 0.74], [48.0, 0.66],
	[-42.0, 0.62], [-14.0, 0.58], [88.0, 0.50]]
const PRIOR_IN := [[16.0, 1.00], [-16.0, 0.98], [46.0, 0.96], [80.0, 0.90], [-46.0, 0.88],
	[-84.0, 0.74], [122.0, 0.56], [-122.0, 0.52]]

# What a bowling plan adds to those starting points: fielders where that ball gets hit.
const PLAN_DEEP := {
	"short": [[-80.0, 0.90], [-45.0, 0.70], [-128.0, 0.50]],
	"wide": [[88.0, 0.90], [48.0, 0.60], [128.0, 0.50]],
	"straight": [[-14.0, 0.90], [14.0, 0.60], [-42.0, 0.50]]}
const PLAN_IN := {
	"short": [[-84.0, 0.60], [-46.0, 0.40]],
	"wide": [[80.0, 0.50], [46.0, 0.50], [122.0, 0.50]],
	"straight": [[16.0, 0.40], [-16.0, 0.40]]}

static func _bump(a: float, b: float, width: float) -> float:
	var d := absf(wrapf(a - b, -180.0, 180.0))
	return exp(-0.5 * (d / width) * (d / width))

static func _demand(angle: float, prior: Array, shots: Array, deep: bool) -> float:
	var v := 0.0
	for p: Array in prior:
		v += float(p[1]) * _bump(angle, float(p[0]), 13.0)
	# Recent shots pull fielders toward where this batter scores, boundaries most of all.
	var n := shots.size()
	for i in n:
		var sh: Array = shots[i]
		var far := float(sh[1]) >= DEEP_SHOT or int(sh[2]) >= 4
		if far != deep:
			continue
		var w := (0.55 + 0.30 * float(sh[2])) * pow(SHOT_FADE, n - 1 - i)
		v += w * _bump(angle, float(sh[0]), 15.0)
	return v

## Picks `count` angles: the busiest first, each pick thinning out the demand around it
## so the next man goes somewhere else.
static func _pick(count: int, lo: float, hi: float, prior: Array, shots: Array, deep: bool, spread: float) -> Array:
	var angles := []
	var value := []
	var a := -178.0
	while a <= 178.0:
		if absf(a) >= lo and absf(a) <= hi:
			angles.append(a)
			value.append(_demand(a, prior, shots, deep))
		a += 4.0
	var out := []
	for _k in count:
		var best := 0
		for i in angles.size():
			if value[i] > value[best]:
				best = i
		var at: float = angles[best]
		out.append(at)
		for i in angles.size():
			value[i] *= 1.0 - 0.97 * _bump(angles[i], at, spread)
	return out

static func _dir(angle: float) -> Vector3:
	var r := deg_to_rad(angle)
	return Vector3(sin(r), 0.0, -cos(r))

static func position_name(angle: float, deep: bool) -> String:
	var off := angle >= 0.0
	var a := absf(angle)
	if deep:
		if a < 26.0:
			return "long-off" if off else "long-on"
		if a < 62.0:
			return "deep cover" if off else "deep midwicket"
		if a < 104.0:
			return "deep point" if off else "deep square leg"
		return "third man" if off else "fine leg"
	if a < 28.0:
		return "mid-off" if off else "mid-on"
	if a < 62.0:
		return "cover" if off else "midwicket"
	if a < 104.0:
		return "point" if off else "square leg"
	return "short third" if off else "short fine leg"

## A T20 field, set to the laws and to the batter. Batter's stumps are at the origin; the
## bowler runs in from -Z; +X is the off side. Never more than two outside the ring in the
## powerplay, never more than five after it. `shots` is the striker's recent scoring shots
## as [angle in degrees, metres travelled, runs]; fielders move to where they have been
## hitting it, which leaves the gaps somewhere they have not.
## `plan` is what the bowler means to bowl this over ("short", "wide", "straight" or ""):
## the field is weighted toward where that ball gets hit. `mood` is the captain's read of
## the game: "attack" brings a slip in and a man off the rope, "defend" pushes the ring back
## to cut off twos, "save_one" brings nearly everyone up to stop the single.
## Order: keeper first, bowler last.
static func layout(spinner: bool, powerplay: bool = true, shots: Array = [], plan: String = "", mood: String = "normal") -> Array[Spot]:
	var f: Array[Spot] = []
	var n_out := MAX_OUT_POWERPLAY if powerplay else MAX_OUT
	var slip := not spinner and powerplay
	var in_dist := INFIELD_DIST
	var in_margin := INFIELD_INSIDE_RING
	match mood:
		"attack":
			slip = true
			n_out = maxi(n_out - (0 if powerplay else 1), 1)
			in_dist = 19.0
		"defend":
			in_dist = 40.0
			in_margin = 1.5
		"save_one":
			slip = false
			n_out = 1
			in_dist = 17.0
	if spinner:
		# The keeper stays back to the spinners too, out of the batter's eyeline.
		f.append(Spot.new("keeper", 0.3, KEEPER_BACK_SPIN, Kind.KEEPER, 1.3))
		if slip:
			f.append(Spot.new("slip", 1.7, KEEPER_BACK_SPIN + 0.9, Kind.CLOSE, 1.2))
	else:
		f.append(Spot.new("keeper", 0.4, KEEPER_BACK_PACE, Kind.KEEPER, 1.5))
		if slip:
			f.append(Spot.new("slip", 2.4, 15.8, Kind.CLOSE, 1.3))
	var recent := shots.slice(maxi(0, shots.size() - SHOT_MEMORY))
	var n_in := 9 - n_out - (1 if slip else 0)
	var bat := Vector3(0.0, 0.0, -1.0)
	var taken := {}
	var prior_deep: Array = PRIOR_DEEP + PLAN_DEEP.get(plan, [])
	var prior_in: Array = PRIOR_IN + PLAN_IN.get(plan, [])
	for a: float in _pick(n_out, 0.0, 172.0, prior_deep, recent, true, 24.0):
		var d := _dir(a)
		var p := bat + d * Pitch.ray_to_circle(bat, d, Pitch.BOUNDARY_RADIUS - DEEP_IN_FROM_ROPE)
		f.append(Spot.new(_unique(position_name(a, true), taken), p.x, p.z, Kind.DEEP, 1.0))
	# Nobody in the ring stands behind the keeper or in the bowler's way.
	for a: float in _pick(n_in, 9.0, 140.0, prior_in, recent, false, 19.0):
		var d := _dir(a)
		var dist := minf(in_dist, Pitch.ray_to_circle(bat, d, Pitch.RING_RADIUS) - in_margin)
		var p := bat + d * dist
		f.append(Spot.new(_unique(position_name(a, false), taken), p.x, p.z, Kind.INFIELD, 1.0))
	# The bowler, in the follow-through, takes return catches.
	f.append(Spot.new("bowler", 0.6, -17.5, Kind.INFIELD, 0.55))
	return f

static func _unique(n: String, taken: Dictionary) -> String:
	if not taken.has(n):
		taken[n] = 1
		return n
	taken[n] += 1
	var alt: String = {"long-off": "wide long-off", "long-on": "wide long-on", "deep cover": "deep extra cover",
		"deep midwicket": "cow corner", "deep point": "deep backward point", "deep square leg": "deep backward square",
		"third man": "fine third man", "fine leg": "long leg", "mid-off": "extra cover", "mid-on": "wide mid-on",
		"cover": "cover point", "midwicket": "forward square leg", "point": "backward point",
		"square leg": "backward square leg", "short third": "gully", "short fine leg": "leg slip"}.get(n, n)
	return alt if taken[n] == 2 else "%s %d" % [n, taken[n]]

static func outside_ring(field: Array) -> int:
	var n := 0
	for s in field:
		if not Pitch.inside_ring(s.pos):
			n += 1
	return n

static func _runs_for(stop_time: float, at: Vector3) -> int:
	var throw := THROW_RELEASE + Vector2(at.x, at.z).length() / THROW_SPEED
	return clampi(int(floor((stop_time + throw) / RUN_TIME)), 0, MAX_RUNS)

static func evaluate(exit: BallPhysics.State, field: Array[Spot], max_time: float = 9.0) -> Result:
	var out := Result.new()
	var s := exit.copy()
	var origin := exit.pos
	var t0 := exit.time
	var limit := t0 + max_time
	var carried := false
	while s.time < limit and not s.at_rest:
		BallPhysics.step(s)
		var t := s.time - t0
		if not carried and s.bounces > 0:
			carried = true
			out.carry = Vector2(s.last_bounce.x - origin.x, s.last_bounce.z - origin.z).length()
		if Pitch.beyond_boundary(s.pos):
			out.boundary = true
			out.six = s.bounces == 0
			out.runs = 6 if out.six else 4
			out.end_time = s.time
			out.distance = Vector2(s.pos.x - origin.x, s.pos.z - origin.z).length()
			if out.six:
				out.carry = out.distance
			out.end_pos = s.pos
			return out
		var in_air := s.bounces == 0
		var catchable := in_air and s.pos.y >= CATCH_LOW and s.pos.y <= CATCH_HIGH
		var stoppable := (not in_air or s.rolling) and s.pos.y <= STOP_HIGH
		if not catchable and not stoppable:
			continue
		for i in field.size():
			var spot: Spot = field[i]
			var d := Vector2(s.pos.x - spot.pos.x, s.pos.z - spot.pos.z).length()
			var r := spot.catch_reach(t, s.vel.length()) if catchable else spot.reach(t)
			if d > r:
				continue
			out.fielder = i
			out.fielder_name = spot.name
			out.field_pos = Vector3(s.pos.x, 0.0, s.pos.z)
			out.field_time = t
			out.end_pos = s.pos
			out.field_height = s.pos.y
			out.field_dir = Vector3(s.vel.x, 0.0, s.vel.z).normalized()
			out.end_time = s.time
			out.distance = Vector2(s.pos.x - origin.x, s.pos.z - origin.z).length()
			if catchable:
				out.caught = true
				out.runs = 0
			else:
				out.runs = _runs_for(t, s.pos)
			return out
	# Came to rest in a gap with nobody near: the nearest fielder walks over to it.
	out.end_time = s.time
	out.end_pos = s.pos
	out.distance = Vector2(s.pos.x - origin.x, s.pos.z - origin.z).length()
	var best := -1
	var best_d := INF
	for i in field.size():
		var d := Vector2(s.pos.x - field[i].pos.x, s.pos.z - field[i].pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		out.fielder = best
		out.fielder_name = field[best].name
		out.field_pos = Vector3(s.pos.x, 0.0, s.pos.z)
		out.field_height = s.pos.y
		out.field_dir = (out.field_pos - field[best].pos).normalized()
		var fetch := maxf(s.time - t0, REACTION + best_d / RUN_SPEED)
		out.field_time = fetch
		out.runs = _runs_for(fetch, s.pos)
	return out
