class_name MatchState
extends RefCounted
## A 20-over chase: Red have batted (simulated), Blue (the player) chase.
## Pure bookkeeping, no scene code, so it can be tested and saved.

const OVERS := 20
const BALLS_PER_OVER := 6
const MAX_WICKETS := 10

const BLUE := ["A. Menon", "R. Desai", "V. Nair", "K. Bose", "S. Pillai", "D. Rao",
	"P. Chopra", "N. Sethi", "J. Thomas", "M. Ali", "T. Kurian"]
const RED := ["L. Cole", "B. Hayes", "T. Moreau", "G. Lindqvist", "E. Mbeki", "F. Novak",
	"O. Reyes", "C. Okafor", "M. Venn", "R. Whitlock", "D. Hartigan"]

## Red's attack: name, style (see BowlingMachine.next_for).
const BOWLERS := [["M. Venn", "swing"], ["D. Hartigan", "pace"], ["C. Okafor", "pace"],
	["L. Fernando", "off"], ["R. Whitlock", "leg"]]
## Who bowls each over: everyone bowls four, nobody bowls two in a row.
const PLAN := [0, 1, 0, 1, 2, 0, 3, 4, 3, 4, 2, 3, 4, 3, 2, 4, 1, 2, 0, 1]

var target := 0
var red_total := 0
var red_wickets := 0
var red_top := ""          # e.g. "L. Cole 54 (38)"
var runs := 0
var wickets := 0
var balls := 0             # legal balls bowled
var batters: Array = []    # [{name, runs, balls, fours, sixes, out}]
var striker := 0
var non_striker := 1
var bowling: Array = []    # per bowler: {balls, runs, wkts}
var this_over: Array = []  # ball-by-ball marks for the current over
var machine_state := 0     # BowlingMachine RNG state, so a resumed match bowls the same balls
var seed_value := 0

static func create(rng_seed: int) -> MatchState:
	var m := MatchState.new()
	m.seed_value = rng_seed
	var sim := InningsSim.run(rng_seed, RED)
	m.red_total = sim.total
	m.red_wickets = sim.wickets
	m.red_top = sim.top
	m.target = sim.total + 1
	for n in BLUE:
		m.batters.append({"name": n, "runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": ""})
	for b in BOWLERS:
		m.bowling.append({"balls": 0, "runs": 0, "wkts": 0})
	return m

func over_index() -> int:
	return balls / BALLS_PER_OVER

func bowler_index() -> int:
	return PLAN[mini(over_index(), OVERS - 1)]

func bowler_name() -> String:
	return BOWLERS[bowler_index()][0]

func bowler_style() -> String:
	return BOWLERS[bowler_index()][1]

func overs_text(b: int = -1) -> String:
	if b < 0:
		b = balls
	return "%d.%d" % [b / BALLS_PER_OVER, b % BALLS_PER_OVER]

func need() -> int:
	return maxi(0, target - runs)

func balls_left() -> int:
	return OVERS * BALLS_PER_OVER - balls

func required_rate() -> float:
	var left := balls_left()
	return 0.0 if left <= 0 else need() * 6.0 / left

func finished() -> bool:
	return runs >= target or wickets >= MAX_WICKETS or balls >= OVERS * BALLS_PER_OVER

func won() -> bool:
	return runs >= target

func striker_name() -> String:
	return batters[striker].name

func bowler_figures(i: int) -> String:
	var b: Dictionary = bowling[i]
	return "%d-%d (%s)" % [b.wkts, b.runs, overs_text(b.balls)]

func batter_line(i: int) -> String:
	var b: Dictionary = batters[i]
	return "%s %d (%d)" % [b.name, b.runs, b.balls]

## Records one legal ball. `how_out` is "" when not out, otherwise a dismissal
## like "b Venn" or "c mid-on b Venn". Returns what happened as flags for the UI.
func record(scored: int, how_out: String = "") -> Dictionary:
	var ev := {"wicket": how_out != "", "over_end": false, "finished": false, "new_batter": ""}
	var bi := bowler_index()
	var bat: Dictionary = batters[striker]
	bat.balls += 1
	balls += 1
	bowling[bi].balls += 1
	if how_out != "":
		wickets += 1
		bat.out = how_out
		if not how_out.begins_with("run out"):
			bowling[bi].wkts += 1
		this_over.append("W")
		var nxt := wickets + 1
		if wickets < MAX_WICKETS and nxt < batters.size():
			striker = nxt
			ev.new_batter = batters[striker].name
	else:
		runs += scored
		bat.runs += scored
		bowling[bi].runs += scored
		if scored == 4:
			bat.fours += 1
		elif scored == 6:
			bat.sixes += 1
		this_over.append("·" if scored == 0 else str(scored))
		if scored % 2 == 1:
			_swap()
	if finished():
		ev.finished = true
		return ev
	if balls % BALLS_PER_OVER == 0:
		ev.over_end = true
		_swap()
		this_over.clear()
	return ev

func _swap() -> void:
	var t := striker
	striker = non_striker
	non_striker = t

func result_text() -> String:
	if won():
		var left := MAX_WICKETS - wickets
		return "BLUE WIN by %d wicket%s" % [left, "" if left == 1 else "s"]
	if runs == target - 1:
		return "MATCH TIED"
	var margin := target - 1 - runs
	return "RED WIN by %d run%s" % [margin, "" if margin == 1 else "s"]

func top_blue() -> String:
	var best := 0
	for i in batters.size():
		if batters[i].runs > batters[best].runs:
			best = i
	return batter_line(best)

func best_bowler() -> String:
	var best := 0
	for i in bowling.size():
		var a: Dictionary = bowling[i]
		var b: Dictionary = bowling[best]
		if a.wkts > b.wkts or (a.wkts == b.wkts and a.balls > 0 and a.runs < b.runs):
			best = i
	return "%s %s" % [BOWLERS[best][0], bowler_figures(best)]

func to_dict() -> Dictionary:
	return {"v": 1, "target": target, "red_total": red_total, "red_wickets": red_wickets, "red_top": red_top,
		"runs": runs, "wickets": wickets, "balls": balls, "batters": batters, "striker": striker,
		"non_striker": non_striker, "bowling": bowling, "this_over": this_over,
		"machine_state": str(machine_state), "seed": seed_value}

static func from_dict(d: Dictionary) -> MatchState:
	var m := MatchState.new()
	m.target = int(d.target)
	m.red_total = int(d.red_total)
	m.red_wickets = int(d.red_wickets)
	m.red_top = str(d.red_top)
	m.runs = int(d.runs)
	m.wickets = int(d.wickets)
	m.balls = int(d.balls)
	m.batters = d.batters
	for b in m.batters:
		for k in ["runs", "balls", "fours", "sixes"]:
			b[k] = int(b[k])
	m.striker = int(d.striker)
	m.non_striker = int(d.non_striker)
	m.bowling = d.bowling
	for b in m.bowling:
		for k in ["balls", "runs", "wkts"]:
			b[k] = int(b[k])
	m.this_over = d.this_over
	m.machine_state = int(str(d.machine_state))
	m.seed_value = int(d.seed)
	return m
