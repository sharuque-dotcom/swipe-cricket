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
	## The full card: per batter {name, runs, balls, fours, sixes, out ("" if not out)}, in order,
	## only those who batted; and the bowlers' figures {name, balls, runs, wkts}.
	var batting: Array = []
	var bowling: Array = []

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

## `strength` scales how well they bat: below 1 a weaker side (club cricket), above 1 a
## stronger one, by shifting dots and wickets into boundaries.
## `bowlers`: the five who bowl to them (default: the bottom of the Blue order); `fielders`:
## names for catches (default: the Blue side).
static func run(rng_seed: int, names: Array, strength: float = 1.0, bowlers: Array = [], fielders: Array = []) -> Result:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out := Result.new()
	if bowlers.is_empty():
		bowlers = MatchState.BLUE.slice(6, 11)
	if fielders.is_empty():
		fielders = MatchState.BLUE
	var how_rng := RandomNumberGenerator.new()
	how_rng.seed = rng_seed * 7 + 3
	var scores := []
	var faced := []
	var fours := []
	var sixes := []
	var hows := []
	for n in names:
		scores.append(0)
		faced.append(0)
		fours.append(0)
		sixes.append(0)
		hows.append("")
	for bn in bowlers:
		out.bowling.append({"name": str(bn), "balls": 0, "runs": 0, "wkts": 0})
	var striker := 0
	var other := 1
	var next_in := 2
	for b in MatchState.OVERS * MatchState.BALLS_PER_OVER:
		var over := b / MatchState.BALLS_PER_OVER
		var w: Array = (POWERPLAY if over < 6 else (DEATH if over >= 16 else MIDDLE)).duplicate()
		if strength != 1.0:
			w[0] /= strength
			w[4] *= strength
			w[5] *= strength * strength
			w[6] /= strength
		var k := _pick(rng, w)
		out.balls += 1
		faced[striker] += 1
		var bw: Dictionary = out.bowling[MatchState.PLAN[over] % out.bowling.size()]
		bw.balls += 1
		if RUNS[k] < 0:
			hows[striker] = _how(how_rng, str(bw.name), fielders)
			if not str(hows[striker]).begins_with("run out"):
				bw.wkts += 1
			out.wickets += 1
			if out.wickets >= MatchState.MAX_WICKETS or next_in >= names.size():
				break
			striker = next_in
			next_in += 1
		else:
			out.total += RUNS[k]
			scores[striker] += RUNS[k]
			bw.runs += RUNS[k]
			if RUNS[k] == 4:
				fours[striker] += 1
			elif RUNS[k] == 6:
				sixes[striker] += 1
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
	for i in names.size():
		if faced[i] > 0 or str(hows[i]) != "" or i < 2:
			out.batting.append({"name": str(names[i]), "runs": scores[i], "balls": faced[i], "fours": fours[i],
				"sixes": sixes[i], "out": hows[i]})
	return out

static func _how(rng: RandomNumberGenerator, bowler: String, fielders: Array) -> String:
	var b := bowler.split(" ")
	var bs := b[b.size() - 1]
	var f := str(fielders[rng.randi() % fielders.size()]).split(" ")
	var fs := f[f.size() - 1]
	var r := rng.randf()
	if r < 0.22:
		return "b %s" % bs
	if r < 0.32:
		return "lbw b %s" % bs
	if r < 0.40:
		return "run out (%s)" % fs
	if r < 0.46:
		return "c & b %s" % bs
	return "c %s b %s" % [fs, bs]
