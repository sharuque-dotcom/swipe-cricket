class_name Ipl
extends RefCounted
## An IPL 2026 season with you in charge of one franchise's batting. Every fixture is played
## in its real order: yours you play (chasing), the rest are simulated ball by ball. Points
## table with net run rate, then play-offs for the top four. Saved in user://ipl.json.

const PATH := "user://ipl.json"
const STAGES := ["Qualifier 1", "Eliminator", "Qualifier 2", "Final"]

## Set by the IPL page before it opens the match.
static var active := false

var team := ""
var results := {}          # key ("L14", "Qualifier 1"...) -> result (see _result)
var playoffs := []         # [{stage, home, away}] once the league is done
var champion := ""

static func create(code: String) -> Ipl:
	var s := Ipl.new()
	s.team = code
	return s

# ---- Fixtures --------------------------------------------------------------------------

## Every fixture, league then play-offs, as {key, n, date, home, away, ground, stage}.
func fixtures() -> Array:
	var out := []
	for f: Array in IplData.FIXTURES:
		out.append({"key": "L%d" % int(f[0]), "n": int(f[0]), "date": str(f[1]), "home": str(f[2]), "away": str(f[3]),
			"ground": str(f[4]), "stage": "League"})
	for i in playoffs.size():
		var p: Dictionary = playoffs[i]
		var info: Array = IplData.PLAYOFFS[STAGES.find(str(p.stage))]
		out.append({"key": str(p.stage), "n": 71 + STAGES.find(str(p.stage)), "date": str(info[1]), "home": str(p.home),
			"away": str(p.away), "ground": str(info[2]), "stage": str(p.stage)})
	return out

func mine(f: Dictionary) -> bool:
	return str(f.home) == team or str(f.away) == team

func opponent(f: Dictionary) -> String:
	return str(f.away) if str(f.home) == team else str(f.home)

## The next fixture still to be played, yours or not; {} when the season is over.
func next_fixture() -> Dictionary:
	_advance_playoffs()
	for f: Dictionary in fixtures():
		if not results.has(f.key):
			return f
	return {}

## Your next match, after simulating everything before it. {} if you are out or it's over.
func next_mine() -> Dictionary:
	while true:
		var f := next_fixture()
		if f.is_empty():
			return {}
		if mine(f):
			return f
		sim_fixture(f)
	return {}

## Your next fixture without simulating anything (for the page).
func peek_mine() -> Dictionary:
	for f: Dictionary in fixtures():
		if mine(f) and not results.has(f.key):
			return f
	return {}

## Day games: the first of two matches on the same date.
static func is_day(f: Dictionary) -> bool:
	if str(f.stage) != "League":
		return false
	for g: Array in IplData.FIXTURES:
		if str(g[1]) == str(f.date) and int(g[0]) == int(f.n) + 1:
			return true
	return false

static func seed_for(f: Dictionary) -> int:
	return 2026 * 1000 + int(f.n) * 17

# ---- A match ---------------------------------------------------------------------------

static func _skills(code: String) -> Array:
	var out := []
	for p: Array in IplData.TEAMS[code].xi:
		out.append([str(p[1]), float(p[2]), float(p[3])])
	return out

## Modern IPL scoring: first innings around 185-190.
const IPL_PAR := 1.24

## How strong the side batting first is against the side bowling at them.
static func _scale(batting: String, bowling: String) -> float:
	return clampf(IPL_PAR + 1.6 * (IplData.batting_strength(batting) - 0.80) - 1.0 * (IplData.bowling_strength(bowling) - 0.82), 0.95, 1.6)

## MatchState options for a match: `chasing` bats second (you, in your own matches).
func match_opts(f: Dictionary, chasing: String) -> Dictionary:
	var first := str(f.home) if str(f.away) == chasing else str(f.away)
	var t1: Dictionary = IplData.TEAMS[first]
	var t2: Dictionary = IplData.TEAMS[chasing]
	return {"blue_name": chasing, "red_name": first, "lineup": IplData.xi_names(chasing), "skills": _skills(chasing),
		"red_lineup": IplData.xi_names(first), "attack": IplData.attack_names(first), "blue_bowlers": IplData.attack_names(chasing),
		"target_scale": _scale(first, chasing), "chase_scale": _scale(chasing, first) - 0.16, "pitch": IplData.GROUNDS.get(str(f.ground), "good"), "night": not is_day(f),
		"kits": {"blue": [_rgb(t2.kit), _rgb(t2.trim)], "red": [_rgb(t1.kit), _rgb(t1.trim)]},
		"ipl": {"key": str(f.key), "n": int(f.n), "stage": str(f.stage), "you": chasing, "opp": first, "ground": str(f.ground), "date": str(f.date)}}

static func _rgb(c: Color) -> Array:
	return [c.r, c.g, c.b]

## Simulates a fixture you're not in. The side that bats first is decided by a toss.
func sim_fixture(f: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(f)
	var chasing := str(f.home) if rng.randf() < 0.5 else str(f.away)
	IplData.register_bowlers()
	var m := MatchState.create(seed_for(f), match_opts(f, chasing))
	Conditions.apply(m.pitch, m.night, 0)
	while not m.finished():
		Conditions.apply(m.pitch, m.night, m.over_index())
		var r := BallSim.ball(m, rng)
		m.record(int(r[0]), str(r[1]))
	Conditions.reset()
	record(m)

## Takes a finished match (yours or simulated) into the season.
func record(m: MatchState) -> Dictionary:
	var key := str(m.ipl.key)
	var chase := str(m.blue_name)
	var first := str(m.red_name)
	var tie := m.runs == m.target - 1 and not m.won()
	var winner := chase if m.won() else first
	if tie:
		# Super over: decided on a coin flip from the match seed.
		winner = chase if m.seed_value % 2 == 0 else first
	var res := {"first": first, "first_runs": m.red_total, "first_wkts": m.red_wickets, "first_balls": 120,
		"chase": chase, "chase_runs": m.runs, "chase_wkts": m.wickets,
		"chase_balls": 120 if m.wickets >= MatchState.MAX_WICKETS else m.balls,
		"winner": winner, "text": "",
		"stage": str(m.ipl.stage), "mine": chase == team or first == team}
	res.text = _result_text(res, tie)
	results[key] = res
	if key == "Final":
		champion = winner
	_advance_playoffs()
	return res

static func _result_text(r: Dictionary, tie: bool) -> String:
	if tie:
		return "%s won the super over" % r.winner
	if r.winner == r.chase:
		var left := MatchState.MAX_WICKETS - int(r.chase_wkts)
		return "%s won by %d wicket%s" % [r.winner, left, "" if left == 1 else "s"]
	var margin := int(r.first_runs) - int(r.chase_runs)
	return "%s won by %d run%s" % [r.winner, margin, "" if margin == 1 else "s"]

# ---- Table and play-offs -----------------------------------------------------------------

## The league table: [{code, p, w, l, pts, nrr}] best first.
func table() -> Array:
	var t := {}
	for code in IplData.ORDER:
		t[code] = {"code": code, "p": 0, "w": 0, "l": 0, "pts": 0, "rf": 0, "bf": 0, "ra": 0, "ba": 0, "nrr": 0.0}
	for key in results:
		var r: Dictionary = results[key]
		if str(r.stage) != "League":
			continue
		var a: Dictionary = t[r.first]
		var b: Dictionary = t[r.chase]
		for row in [a, b]:
			row.p += 1
		a.rf += int(r.first_runs)
		a.bf += int(r.first_balls)
		a.ra += int(r.chase_runs)
		a.ba += int(r.chase_balls)
		b.rf += int(r.chase_runs)
		b.bf += int(r.chase_balls)
		b.ra += int(r.first_runs)
		b.ba += int(r.first_balls)
		var win: Dictionary = t[r.winner]
		var lose: Dictionary = b if win == a else a
		win.w += 1
		win.pts += 2
		lose.l += 1
	var rows := []
	for code in t:
		var row: Dictionary = t[code]
		if int(row.bf) > 0 and int(row.ba) > 0:
			row.nrr = float(row.rf) * 6.0 / float(row.bf) - float(row.ra) * 6.0 / float(row.ba)
		rows.append(row)
	rows.sort_custom(func(x, y): return x.pts > y.pts or (x.pts == y.pts and x.nrr > y.nrr))
	return rows

func league_done() -> bool:
	for f: Array in IplData.FIXTURES:
		if not results.has("L%d" % int(f[0])):
			return false
	return true

## Fills in the play-off fixtures as the teams become known.
func _advance_playoffs() -> void:
	if not league_done():
		return
	if playoffs.is_empty():
		var top := table()
		playoffs.append({"stage": "Qualifier 1", "home": top[0].code, "away": top[1].code})
		playoffs.append({"stage": "Eliminator", "home": top[2].code, "away": top[3].code})
	if playoffs.size() == 2 and results.has("Qualifier 1") and results.has("Eliminator"):
		var q1: Dictionary = results["Qualifier 1"]
		var loser := str(q1.first) if str(q1.winner) == str(q1.chase) else str(q1.chase)
		playoffs.append({"stage": "Qualifier 2", "home": loser, "away": str(results["Eliminator"].winner)})
	if playoffs.size() == 3 and results.has("Qualifier 2"):
		playoffs.append({"stage": "Final", "home": str(results["Qualifier 1"].winner), "away": str(results["Qualifier 2"].winner)})

func position() -> int:
	var rows := table()
	for i in rows.size():
		if rows[i].code == team:
			return i + 1
	return 0

func season_over() -> bool:
	return champion != ""

## Simulates the rest of the season (when you're knocked out).
func sim_to_end() -> void:
	var f := next_fixture()
	while not f.is_empty():
		sim_fixture(f)
		f = next_fixture()

# ---- Saving ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"v": 1, "team": team, "results": results, "playoffs": playoffs, "champion": champion}

static func from_dict(d: Dictionary) -> Ipl:
	var s := Ipl.new()
	s.team = str(d.get("team", "MI"))
	s.results = d.get("results", {})
	s.playoffs = d.get("playoffs", [])
	s.champion = str(d.get("champion", ""))
	return s

static func load_saved() -> Ipl:
	if not FileAccess.file_exists(PATH):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return from_dict(d) if d is Dictionary else null

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))

static func delete_saved() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
