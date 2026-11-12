class_name InningsSim
extends RefCounted
## Red's innings, simulated ball by ball from T20 scoring rates: steady in the powerplay,
## quieter in the middle overs, big hitting at the death. Typical totals: 140 to 190.

class Result:
	extends RefCounted
	var total := 0
	var wickets := 0
	var balls := 0
	var top := ""

# Outcome weights per phase: dot, 1, 2, 3, 4, 6, wicket.
const POWERPLAY := [36.0, 33.0, 7.0, 1.0, 14.0, 4.0, 4.0]
const MIDDLE := [33.0, 42.0, 9.0, 1.0, 8.0, 3.5, 3.5]
const DEATH := [27.0, 33.0, 9.0, 1.0, 14.0, 9.0, 7.0]
const RUNS := [0, 1, 2, 3, 4, 6, -1]

static func _pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1

static func run(rng_seed: int, names: Array) -> Result:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out := Result.new()
	var scores := []
	var faced := []
	for n in names:
		scores.append(0)
		faced.append(0)
	var striker := 0
	var other := 1
	var next_in := 2
	for b in MatchState.OVERS * MatchState.BALLS_PER_OVER:
		var over := b / MatchState.BALLS_PER_OVER
		var w: Array = POWERPLAY if over < 6 else (DEATH if over >= 16 else MIDDLE)
		var k := _pick(rng, w)
		out.balls += 1
		faced[striker] += 1
		if RUNS[k] < 0:
			out.wickets += 1
			if out.wickets >= MatchState.MAX_WICKETS or next_in >= names.size():
				break
			striker = next_in
			next_in += 1
		else:
			out.total += RUNS[k]
			scores[striker] += RUNS[k]
			if RUNS[k] % 2 == 1:
				var t := striker
				striker = other
				other = t
		if out.balls % MatchState.BALLS_PER_OVER == 0:
			var t2 := striker
			striker = other
			other = t2
	var best := 0
	for i in scores.size():
		if scores[i] > scores[best]:
			best = i
	out.top = "%s %d (%d)" % [names[best], scores[best], faced[best]]
	return out
