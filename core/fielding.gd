class_name Fielding
extends RefCounted
## Fielders, catches and run-saving. Nothing here is random: a fielder catches the ball if
## they can reach it while it is still in the air at a catchable height, and stops it if they
## can reach it on the ground. How far they can reach grows with time after a short reaction.
## Runs come from how long the batters had: the time to stop the ball plus the throw back.

enum Kind { CLOSE, INFIELD, DEEP, KEEPER }

const REACTION := 0.45        # seconds before a fielder moves
const RUN_SPEED := 6.2        # metres per second, chasing a ball
const CLOSE_SPEED := 2.4      # keeper and slips mostly dive, they don't run
const CATCH_LOW := 0.08       # ball height window for a catch, metres
const CATCH_HIGH := 2.55
const STOP_HIGH := 0.75       # below this a moving ball can be fielded
const THROW_SPEED := 26.0     # m/s back to the stumps
const THROW_RELEASE := 0.55   # pick-up and release time
const STOP_CAP_IN := 9.0      # how far a fielder can get across to stop a ground ball
const STOP_CAP_DEEP := 12.0
const CATCH_REACTION := 0.65  # a catch needs the fielder to read the ball first
const CATCH_RUN_SPEED := 3.6
const CATCH_CAP_IN := 6.0
const CATCH_CAP_DEEP := 9.0
const CATCH_HARD_SPEED := 24.0 # m/s; faster than this, only a dive will do
const RUN_TIME := 3.3         # seconds per run between the wickets
const MAX_RUNS := 3

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
		return minf(base_reach + speed * maxf(0.0, t - (0.2 if kind == Kind.CLOSE or kind == Kind.KEEPER else REACTION)), cap)

class Result:
	extends NetsScoring.Summary
	var caught := false
	var fielder := -1             # index into the layout, -1 if none involved
	var fielder_name := ""
	var field_pos := Vector3.ZERO # where the fielder meets the ball
	var field_time := 0.0         # seconds after contact

## A T20 field. Batter's stumps are at the origin; the bowler runs in from -Z; +X is off side.
static func layout(spinner: bool, powerplay: bool = true) -> Array[Spot]:
	var f: Array[Spot] = []
	if spinner:
		f.append(Spot.new("keeper", 0.2, 1.6, Kind.KEEPER, 1.2))
		f.append(Spot.new("long-on", -22.0, -66.0, Kind.DEEP, 1.0))
	else:
		f.append(Spot.new("keeper", 0.4, 14.5, Kind.KEEPER, 1.5))
		if powerplay:
			f.append(Spot.new("slip", 2.4, 15.8, Kind.CLOSE, 1.3))
		else:
			f.append(Spot.new("deep cover", 40.0, -40.0, Kind.DEEP, 1.0))
	# After the powerplay, point drops back and a spinner gets a deep midwicket too.
	if powerplay:
		f.append(Spot.new("point", 21.0, 2.0, Kind.INFIELD, 1.0))
	else:
		f.append(Spot.new("deep point", 52.0, -2.0, Kind.DEEP, 1.0))
	f.append(Spot.new("cover", 18.0, -15.0, Kind.INFIELD, 1.0))
	f.append(Spot.new("mid-off", 9.0, -27.0, Kind.INFIELD, 1.0))
	f.append(Spot.new("mid-on", -9.0, -27.0, Kind.INFIELD, 1.0))
	if spinner and not powerplay:
		f.append(Spot.new("deep midwicket", -42.0, -38.0, Kind.DEEP, 1.0))
	else:
		f.append(Spot.new("midwicket", -20.0, -13.0, Kind.INFIELD, 1.0))
	f.append(Spot.new("deep square leg", -56.0, 4.0, Kind.DEEP, 1.0))
	f.append(Spot.new("fine leg", -28.0, 46.0, Kind.DEEP, 1.0))
	f.append(Spot.new("long-off", 22.0, -68.0, Kind.DEEP, 1.0))
	# The bowler, in the follow-through, takes return catches.
	f.append(Spot.new("bowler", 0.6, -17.5, Kind.INFIELD, 0.55))
	return f

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
		var fetch := maxf(s.time - t0, REACTION + best_d / RUN_SPEED)
		out.field_time = fetch
		out.runs = _runs_for(fetch, s.pos)
	return out
