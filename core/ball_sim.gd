class_name BallSim
extends RefCounted
## One ball, decided by numbers instead of played: for your team-mates' balls in a career
## match. Starts from real T20 scoring rates for the phase of the innings, then leans on the
## batter (power for boundaries, timing for fewer dots and wickets) and on the chase (behind
## the rate they take more risks).

const DISMISSALS := ["b %s", "c long-on b %s", "c cover b %s", "c †keeper b %s", "lbw b %s", "c deep midwicket b %s",
	"c mid-off b %s", "c point b %s", "c fine leg b %s"]

## Returns [runs, how_out] where how_out is "" when not out.
static func ball(m: MatchState, rng: RandomNumberGenerator) -> Array:
	var sk := m.skill_for(m.striker)
	var over := m.over_index()
	var w: Array = (InningsSim.POWERPLAY if m.powerplay() else (InningsSim.DEATH if over >= 16 else InningsSim.MIDDLE)).duplicate()
	var push := clampf((m.required_rate() - 8.0) / 6.0, -0.5, 1.0)
	var s := m.chase_scale
	if s != 1.0:
		w[0] /= s
		w[4] *= s
		w[5] *= s * s
		w[6] /= s
	# A batter with power 0.7 and timing 0.75 scores at the tables' rates.
	w[0] *= (1.45 - 0.6 * sk.timing) * (1.0 - 0.25 * push)
	w[4] *= (0.4 + 0.85 * sk.power) * (1.0 + 0.45 * push)
	w[5] *= maxf(0.05, 1.43 * sk.power) * (1.0 + 0.9 * push)
	w[6] *= (1.9 - 1.2 * sk.timing) * (1.0 + 0.8 * push)
	var k := InningsSim._pick(rng, w)
	var r: int = InningsSim.RUNS[k]
	if r >= 0:
		return [r, ""]
	if rng.randf() < 0.05:
		return [0, "run out"]
	var parts := m.bowler_name().split(" ")
	return [0, DISMISSALS[rng.randi() % DISMISSALS.size()] % parts[parts.size() - 1]]
