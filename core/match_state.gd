class_name MatchState
extends RefCounted
## A 20-over chase: Red have batted (simulated), Blue (the player) chase.
## Pure bookkeeping, no scene code, so it can be tested and saved.

const OVERS := 20
const BALLS_PER_OVER := 6
const MAX_WICKETS := 10

const BLUE := ["A. Menon", "R. Desai", "V. Nair", "K. Bose", "S. Pillai", "D. Rao",
	"P. Chopra", "N. Sethi", "J. Thomas", "M. Ali", "T. Kurian"]
## Blue's batting card: role, power, timing (0..1). Strokemakers up top, hitters in the
## middle, bowlers at the bottom who can neither time it nor clear the rope.
const BLUE_SKILL := [
	["Opener", 0.70, 0.90], ["Opener", 0.85, 0.80], ["Anchor", 0.75, 1.00], ["Power hitter", 1.00, 0.70],
	["Keeper-batter", 0.70, 0.75], ["Finisher", 0.90, 0.60], ["All-rounder", 0.60, 0.55],
	["All-rounder", 0.50, 0.45], ["Bowler", 0.35, 0.30], ["Bowler", 0.20, 0.20], ["Bowler", 0.10, 0.10]]
const RED := ["L. Cole", "B. Hayes", "T. Moreau", "G. Lindqvist", "E. Mbeki", "F. Novak",
	"O. Reyes", "C. Okafor", "M. Venn", "R. Whitlock", "D. Hartigan"]

## Who bowls each over (index into `attack`): everyone bowls four, nobody bowls two in a row.
## Slots 0-2 are the quicks, 3-4 the spinners.
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
var attack: Array = BowlerProfile.DEFAULT_ATTACK.duplicate()   # Red's five bowlers, by name
var pitch := "good"        # see Conditions.PITCHES
var night := false
var blue_name := "BLUE"
var red_name := "RED"
## In a career match: {"pos": batting position of the player's batter, "mode": "own" or "team",
## "tier": int, "match": int}. Empty for a quick match.
var career := {}
## How the player's own swings went this match: contacts in the green, early, late, misses.
var timing := {"perfect": 0, "early": 0, "late": 0, "miss": 0}
var fow: Array = []              # fall of wickets: {score, wkt, over, name}
var skills: Array = []           # per batter [role, power, timing]; empty uses BLUE_SKILL
var kits := {}                   # {"blue": [kit, trim], "red": [kit, trim]} as colour arrays
var red_names: Array = RED.duplicate()   # their eleven, for shirts in the field
var chase_scale := 1.0           # how hard simulated chasers hit (BallSim), like InningsSim's strength
var ipl := {}                    # in an IPL match: {"match": n, "stage": name, "you": code, "opp": code}
var red_card: Array = []         # their innings, batter by batter (InningsSim.batting)
var red_bowling: Array = []      # and our bowlers' figures in it
var extras := 0                  # wides and no-balls conceded to us
var free_hit := false            # the next legal ball is a free hit (after a no-ball)

## `opts` (all optional): attack (five names), pitch, night, blue_name, red_name,
## target_scale (how strong Red's batting is), lineup (Blue's eleven names), career.
static func create(rng_seed: int, opts: Dictionary = {}) -> MatchState:
	var m := MatchState.new()
	m.seed_value = rng_seed
	var cond := Conditions.pick(rng_seed)
	m.pitch = str(opts.get("pitch", cond.pitch))
	m.night = bool(opts.get("night", cond.night))
	if Settings.get_bool("day_only", false) and not opts.has("night"):
		m.night = false
	m.attack = opts.get("attack", BowlerProfile.DEFAULT_ATTACK.duplicate())
	m.blue_name = str(opts.get("blue_name", "BLUE"))
	m.red_name = str(opts.get("red_name", "RED"))
	m.career = opts.get("career", {})
	m.skills = opts.get("skills", [])
	m.kits = opts.get("kits", {})
	m.ipl = opts.get("ipl", {})
	m.chase_scale = float(opts.get("chase_scale", 1.0))
	m.red_names = opts.get("red_lineup", RED)
	var strength := float(opts.get("target_scale", 1.0)) * float(Conditions.info(m.pitch).par)
	var red_names: Array = opts.get("red_lineup", RED)
	var our: Array = opts.get("lineup", BLUE)
	var sim := InningsSim.run(rng_seed, red_names, strength, opts.get("blue_bowlers", our.slice(6, 11)), our)
	m.red_card = sim.batting
	m.red_bowling = sim.bowling
	m.red_total = sim.total
	m.red_wickets = sim.wickets
	m.red_top = sim.top
	m.target = sim.total + 1
	for n in opts.get("lineup", BLUE):
		m.batters.append({"name": n, "runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": ""})
	for b in m.attack:
		m.bowling.append({"balls": 0, "runs": 0, "wkts": 0})
	return m

## The conditions as BowlingMachine wants them.
func conditions() -> Dictionary:
	return {"pitch": pitch, "night": night, "pace": float(career.get("pace", 1.0))}

func bowler_profile() -> Dictionary:
	return BowlerProfile.of(bowler_name())

func over_index() -> int:
	return balls / BALLS_PER_OVER

func bowler_index() -> int:
	return PLAN[mini(over_index(), OVERS - 1)]

func bowler_name() -> String:
	return str(attack[bowler_index()])

func bowler_style() -> String:
	return str(bowler_profile().style)

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

static func skill_of(order: int) -> BatterSkill:
	var k: Array = BLUE_SKILL[clampi(order, 0, BLUE_SKILL.size() - 1)]
	return BatterSkill.new(k[0], k[1], k[2])

## Batter `i` in this match. In a career match your player bats with your ratings, and your
## team-mates are as good as the level you play at.
func skill_for(i: int) -> BatterSkill:
	if not career.is_empty():
		if i == int(career.pos):
			return BatterSkill.new("You  ·  " + str(career.role), float(career.power), float(career.timing),
				float(career.get("placement", 0.6)), float(career.get("footwork", 0.6)))
		var base := skill_of(i)
		if i < skills.size():
			base = BatterSkill.new(str(skills[i][0]), float(skills[i][1]), float(skills[i][2]))
		var k := float(career.get("mates", 1.0))
		return BatterSkill.new(base.role, base.power * k, base.timing * k)
	if i < skills.size():
		var s: Array = skills[i]
		return BatterSkill.new(str(s[0]), float(s[1]), float(s[2]))
	return skill_of(i)

func striker_skill() -> BatterSkill:
	return skill_for(striker)

## In a career match, whether the player's own batter is on strike / has been out.
func player_on_strike() -> bool:
	return career.is_empty() or striker == int(career.pos)

func player_out() -> bool:
	return not career.is_empty() and str(batters[int(career.pos)].out) != ""

## Whether the next ball is the player's to play.
func players_ball() -> bool:
	return career.is_empty() or str(career.get("mode", "own")) == "team" or player_on_strike()

## Remember where the striker hit it, for the fielding captain: degrees from straight
## (+ is the off side), metres travelled, runs scored.
func note_shot(angle_deg: float, distance: float, scored: int) -> void:
	var bat: Dictionary = batters[striker]
	var shots: Array = bat.get("shots", [])
	shots.append([snappedf(angle_deg, 0.1), snappedf(distance, 0.1), scored])
	if shots.size() > Fielding.SHOT_MEMORY:
		shots.pop_front()
	bat["shots"] = shots

func striker_shots() -> Array:
	return batters[striker].get("shots", [])

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
## A wide ("wd") or a no-ball ("nb", with `bat_runs` hit off it). Neither counts as one of
## the over's six; a no-ball makes the next ball a free hit. Only a run out can dismiss a
## batter off either, and the game never runs anyone out, so these carry no wicket.
func record_extra(kind: String, bat_runs: int = 0) -> Dictionary:
	var ev := {"wicket": false, "over_end": false, "finished": false, "new_batter": "", "extra": kind}
	var bi := bowler_index()
	runs += 1 + bat_runs
	extras += 1
	bowling[bi].runs += 1 + bat_runs
	if kind == "nb":
		var bat: Dictionary = batters[striker]
		bat.balls += 1
		bat.runs += bat_runs
		if bat_runs == 4:
			bat.fours += 1
		elif bat_runs == 6:
			bat.sixes += 1
		free_hit = true
		this_over.append("nb" if bat_runs == 0 else "nb%d" % bat_runs)
		if bat_runs % 2 == 1:
			_swap()
	else:
		this_over.append("wd")
	ev.finished = finished()
	return ev

func record(scored: int, how_out: String = "") -> Dictionary:
	var ev := {"wicket": how_out != "", "over_end": false, "finished": false, "new_batter": ""}
	free_hit = false
	var bi := bowler_index()
	var bat: Dictionary = batters[striker]
	bat.balls += 1
	balls += 1
	bowling[bi].balls += 1
	if how_out != "":
		wickets += 1
		bat.out = how_out
		fow.append({"score": runs, "wkt": wickets, "over": overs_text(balls), "name": str(bat.name)})
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
		return "%s WIN by %d wicket%s" % [blue_name, left, "" if left == 1 else "s"]
	if runs == target - 1:
		return "MATCH TIED"
	var margin := target - 1 - runs
	return "%s WIN by %d run%s" % [red_name, margin, "" if margin == 1 else "s"]

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
	return "%s %s" % [attack[best], bowler_figures(best)]

## Everything the scorecard shows: our innings so far, and theirs.
func scorecard() -> Dictionary:
	var bat := []
	var yet := []
	for i in batters.size():
		var b: Dictionary = batters[i]
		var batted := int(b.balls) > 0 or str(b.out) != "" or i == striker or i == non_striker
		if not batted:
			yet.append(str(b.name))
			continue
		var how := str(b.out)
		if how == "":
			how = "batting" if not finished() else "not out"
		bat.append({"name": str(b.name), "how": how, "runs": int(b.runs), "balls": int(b.balls), "fours": int(b.fours),
			"sixes": int(b.sixes), "on_strike": i == striker and not finished(), "out": str(b.out) != ""})
	var bowl := []
	for i in attack.size():
		var w: Dictionary = bowling[i]
		if int(w.balls) > 0:
			bowl.append({"name": str(attack[i]), "balls": int(w.balls), "runs": int(w.runs), "wkts": int(w.wkts)})
	var falls := []
	for f in fow:
		var parts := str(f.name).split(" ")
		falls.append("%d-%d (%s, %s)" % [int(f.score), int(f.wkt), parts[parts.size() - 1], str(f.over)])
	var them := []
	for b: Dictionary in red_card:
		var how2 := str(b.out) if str(b.out) != "" else "not out"
		them.append({"name": str(b.name), "how": how2, "runs": int(b.runs), "balls": int(b.balls), "fours": int(b.get("fours", 0)),
			"sixes": int(b.get("sixes", 0)), "on_strike": false, "out": str(b.out) != ""})
	var their_bowl := []
	for w: Dictionary in red_bowling:
		if int(w.balls) > 0:
			their_bowl.append({"name": str(w.name), "balls": int(w.balls), "runs": int(w.runs), "wkts": int(w.wkts)})
	return {
		"ours": {"team": blue_name, "score": "%d/%d" % [runs, wickets], "overs": overs_text(), "batting": bat, "yet": yet,
			"fow": ", ".join(falls), "bowling": bowl, "bowling_team": red_name, "extras": extras,
			"status": "" if finished() else "NEED %d OFF %d  ·  REQ. RATE %.1f" % [need(), balls_left(), required_rate()]},
		"theirs": {"team": red_name, "score": "%d/%d" % [red_total, red_wickets], "overs": "20", "batting": them, "yet": [],
			"fow": "", "bowling": their_bowl, "bowling_team": blue_name, "status": "TARGET %d" % target},
	}

func to_dict() -> Dictionary:
	return {"v": 1, "target": target, "red_total": red_total, "red_wickets": red_wickets, "red_top": red_top,
		"runs": runs, "wickets": wickets, "balls": balls, "batters": batters, "striker": striker,
		"non_striker": non_striker, "bowling": bowling, "this_over": this_over,
		"machine_state": str(machine_state), "seed": seed_value, "attack": attack, "pitch": pitch,
		"night": night, "blue_name": blue_name, "red_name": red_name, "career": career, "timing": timing,
		"fow": fow, "red_card": red_card, "red_bowling": red_bowling, "skills": skills, "kits": kits, "ipl": ipl, "chase_scale": chase_scale, "red_names": red_names,
		"extras": extras, "free_hit": free_hit}

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
	m.attack = d.get("attack", BowlerProfile.DEFAULT_ATTACK.duplicate())
	m.pitch = str(d.get("pitch", "good"))
	m.night = bool(d.get("night", false))
	m.blue_name = str(d.get("blue_name", "BLUE"))
	m.red_name = str(d.get("red_name", "RED"))
	m.career = d.get("career", {})
	if m.career.has("pos"):
		m.career.pos = int(m.career.pos)
	m.fow = d.get("fow", [])
	m.skills = d.get("skills", [])
	m.kits = d.get("kits", {})
	m.ipl = d.get("ipl", {})
	m.chase_scale = float(d.get("chase_scale", 1.0))
	m.red_names = d.get("red_names", RED)
	m.red_card = d.get("red_card", [])
	m.red_bowling = d.get("red_bowling", [])
	m.extras = int(d.get("extras", 0))
	m.free_hit = bool(d.get("free_hit", false))
	var t: Dictionary = d.get("timing", {})
	for k in m.timing:
		m.timing[k] = int(t.get(k, 0))
	return m
