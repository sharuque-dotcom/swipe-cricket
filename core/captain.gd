class_name Captain
extends RefCounted
## Red's captain. Decides, ball by ball, three things that show up in the field:
##   the bowler's plan for the over   (where they mean to bowl, and the field to match)
##   the mood                         (attack, normal, defend, or everyone up to save one)
##   who goes where                   (Fielding.layout, from the plan, the mood and the batter)
## Nothing here is random at play time: the plan comes from the match seed and the over,
## the mood from the score. So a resumed match sets the same fields.

## The plan for an over: "" (no particular plan), "short", "wide" or "straight".
static func plan(rng_seed: int, over: int, style: String) -> String:
	var roll := absi(hash(rng_seed * 31 + over * 7919)) % 100
	if BowlerProfile.is_spin(style):
		# Spinners don't bang it in.
		if roll < 35:
			return ""
		return "wide" if roll < 70 else "straight"
	if roll < 28:
		return ""
	if roll < 54:
		return "short"
	return "wide" if roll < 78 else "straight"

## How the captain feels about the game right now.
static func mood(m: MatchState) -> String:
	var left := m.balls_left()
	var need := m.need()
	# The last over with a run a ball or less to get: stop the single at all costs.
	if left <= 6 and need <= left:
		return "save_one"
	# A new batter is there to be got out.
	if m.wickets > 0 and int(m.batters[m.striker].balls) < 4:
		return "attack"
	# Runs are the problem for the batting side: protect the rope and give the single.
	if m.required_rate() >= 10.5:
		return "defend"
	# Into the tail, or the chase is cruising and only wickets will stop it.
	if m.wickets >= 7:
		return "attack"
	if m.balls >= 36 and left >= 24 and m.required_rate() < 5.0:
		return "attack"
	return "normal"

static func field(m: MatchState) -> Array[Fielding.Spot]:
	var style := m.bowler_style()
	return Fielding.layout(BowlerProfile.is_spin(style), m.powerplay(), m.striker_shots(),
		plan(m.seed_value, m.over_index(), style), mood(m))

## What to tell the batter when the mood changes.
static func mood_text(mood_name: String) -> String:
	return {"attack": "ATTACKING FIELD  ·  catchers in", "defend": "FIELD SPREAD  ·  protecting the rope",
		"save_one": "FIELD UP  ·  saving the single", "normal": "FIELD BACK TO NORMAL"}.get(mood_name, "")
