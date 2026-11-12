class_name NetsScoring
extends RefCounted
## Works out where a hit ends up on an empty field. Fielders arrive in a later milestone,
## so non-boundary runs are estimated from how far the ball travels.

class Summary:
	extends RefCounted
	var runs := 0
	var boundary := false
	var six := false
	var carry := 0.0        # metres to first bounce
	var distance := 0.0     # metres from the bat when it stops or crosses the rope
	var end_time := 0.0

static func evaluate(exit: BallPhysics.State, max_time: float = 9.0) -> Summary:
	var out := Summary.new()
	var s := exit.copy()
	var origin := exit.pos
	var limit := s.time + max_time
	var carried := false
	while s.time < limit and not s.at_rest:
		BallPhysics.step(s)
		if not carried and s.bounces > 0:
			carried = true
			out.carry = Vector2(s.last_bounce.x - origin.x, s.last_bounce.z - origin.z).length()
		if Pitch.beyond_boundary(s.pos):
			out.boundary = true
			out.six = s.bounces == 0
			break
	out.end_time = s.time
	out.distance = Vector2(s.pos.x - origin.x, s.pos.z - origin.z).length()
	if out.six:
		out.carry = out.distance
	if out.boundary:
		out.runs = 6 if out.six else 4
	elif out.distance >= 40.0:
		out.runs = 2
	elif out.distance >= 20.0:
		out.runs = 1
	return out
