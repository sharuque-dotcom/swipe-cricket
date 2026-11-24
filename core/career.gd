class_name Career
extends RefCounted
## A batting career: your player, their four abilities, the level you play at, your season
## and every innings you have played. Saved in user://career.json.
##
## Club cricket, then your state side, then the IPL: when a state season goes well,
## franchises bid for you at the auction, you pick one, and from then on you play real IPL
## seasons in their XI.
##
## Abilities don't grow on their own. Each match earns skill points from what you did (runs,
## milestones, strike rate, how well you timed it, winning); you spend them where you choose.
## A bad match costs you: a cheap dismissal takes points off the ability that got you out.

const PATH := "user://career.json"
const TIERS := [
	{"name": "CLUB", "team": "RIVERSIDE CC", "matches": 5, "strength": 0.82, "mates": 0.82, "pace": 0.87,
		"opps": ["HILLCREST CC", "OLD TOWN CC", "EASTGATE CC", "MILLBROOK CC", "SEAVIEW CC"]},
	{"name": "STATE", "team": "NORTHERN STATE", "matches": 5, "strength": 0.92, "mates": 0.9, "pace": 0.93,
		"opps": ["SOUTHERN STATE", "COASTAL", "CENTRAL", "HIGHLANDS", "WESTERN"]},
	{"name": "IPL", "team": "", "matches": 14, "strength": 1.0, "mates": 1.0, "pace": 1.0, "opps": []},
]
const IPL_TIER := 2
## The four abilities, and what each one does.
const AREAS := ["power", "timing", "placement", "footwork"]
const AREA_INFO := {
	"power": "How hard you can hit it: distance and pace off the bat",
	"timing": "How big your sweet spot is, and how forgiving your edges",
	"placement": "How close a mistimed shot stays to where you aimed",
	"footwork": "How far down the pitch you get, and how far you reach",
}
## Role: batting position (0-based) and starting abilities [power, timing, placement, footwork].
const ROLES := {
	"Opener": {"pos": 0, "start": [0.50, 0.60, 0.55, 0.50]},
	"Top order": {"pos": 2, "start": [0.52, 0.60, 0.58, 0.52]},
	"Middle order": {"pos": 3, "start": [0.58, 0.52, 0.55, 0.56]},
	"Finisher": {"pos": 5, "start": [0.64, 0.46, 0.50, 0.55]},
}
const ROLE_ORDER := ["Opener", "Top order", "Middle order", "Finisher"]
## Win this share of a season's matches, or average this much, to go up a level.
const PROMOTE_WINS := 0.6
const PROMOTE_AVERAGE := 35.0
## Abilities never drop below this.
const FLOOR := 0.25
const DEEP := ["long", "deep", "fine leg", "third man", "cow corner"]

## Set by the career page before it opens the match; read by the match.
static var active := false

var name := "You"
var role := "Opener"
var power := 0.5
var timing := 0.6
var placement := 0.55
var footwork := 0.5
var points := 0                # skill points to spend
var tier := 0
var season := 1
var match_no := 0              # matches played this season
var season_wins := 0
var season_runs := 0
var season_outs := 0
var next_seed := 1
var ipl_team := ""             # once picked at the auction
var ipl_season := {}           # the current IPL season (Ipl.to_dict)
var auction: Array = []        # franchise codes bidding for you, while you choose
var stats := {"matches": 0, "innings": 0, "not_outs": 0, "runs": 0, "balls": 0, "hs": 0, "hs_not_out": false,
	"fifties": 0, "hundreds": 0, "fours": 0, "sixes": 0, "ducks": 0, "wins": 0}
var timing_totals := {"perfect": 0, "early": 0, "late": 0, "miss": 0}
var recent: Array = []         # newest first: {runs, balls, out, won, opp, tier, fours, sixes}
var history: Array = []        # one line per finished season

static func create(player_name: String, player_role: String) -> Career:
	var c := Career.new()
	c.name = player_name.strip_edges() if player_name.strip_edges() != "" else "You"
	c.role = player_role if ROLES.has(player_role) else "Opener"
	var st: Array = ROLES[c.role].start
	c.power = st[0]
	c.timing = st[1]
	c.placement = st[2]
	c.footwork = st[3]
	c.next_seed = int(Time.get_unix_time_from_system()) % 100000 + 1
	return c

func position() -> int:
	return int(ROLES[role].pos)

func tier_info() -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]

func in_ipl() -> bool:
	return tier >= IPL_TIER and ipl_team != ""

func team_name() -> String:
	if in_ipl():
		return str(IplData.team(ipl_team).name).to_upper()
	return str(tier_info().team)

func matches_in_season() -> int:
	return int(tier_info().matches)

func opponent() -> String:
	var opps: Array = tier_info().opps
	return str(opps[match_no % opps.size()]) if not opps.is_empty() else ""

func skill() -> BatterSkill:
	return BatterSkill.new(role, power, timing, placement, footwork)

# ---- Abilities and points ------------------------------------------------------------

## Ratings as the game shows them, out of 99.
static func rating(v: float) -> int:
	return clampi(int(round(v * 99.0)), 1, 99)

func value(area: String) -> float:
	return float(get(area))

func overall() -> int:
	return rating(power * 0.3 + timing * 0.35 + placement * 0.2 + footwork * 0.15)

## Points to raise an ability by one: dearer at the top.
func cost(area: String) -> int:
	var r := rating(value(area))
	return 1 if r < 80 else (2 if r < 90 else 3)

func can_spend(area: String) -> bool:
	return points >= cost(area) and rating(value(area)) < 99

func spend(area: String) -> bool:
	if not can_spend(area):
		return false
	points -= cost(area)
	set(area, minf(1.0, float(rating(value(area)) + 1) / 99.0))
	return true

## Which ability a dismissal points at.
static func area_for(how: String) -> String:
	if how.begins_with("st "):
		return "footwork"
	if how.begins_with("b ") or how.begins_with("lbw"):
		return "timing"
	if how.begins_with("c †keeper") or how.begins_with("c slip") or how.begins_with("c gully"):
		return "timing"
	if how.begins_with("c "):
		for d in DEEP:
			if how.contains(d):
				return "power"
		return "placement"
	return ""

## What a match was worth: [["Runs (42)", 4], ...] earned, and [["Duck", "timing", 2], ...] lost.
func assess(m: MatchState) -> Dictionary:
	var b: Dictionary = m.batters[position()]
	var runs := int(b.runs)
	var balls := int(b.balls)
	var out := str(b.out) != ""
	var batted := balls > 0 or out
	var won := m.won()
	var gains := []
	var losses := []
	if batted:
		if runs >= 10:
			gains.append(["%d runs" % runs, mini(runs / 10, 10)])
		if runs >= 100:
			gains.append(["Hundred", 5])
		elif runs >= 50:
			gains.append(["Fifty", 2])
		var sr := 100.0 * runs / maxf(balls, 1)
		if balls >= 10 and sr >= 200.0:
			gains.append(["Strike rate %d" % int(sr), 2])
		elif balls >= 10 and sr >= 150.0:
			gains.append(["Strike rate %d" % int(sr), 1])
		var contacts := int(m.timing.perfect) + int(m.timing.early) + int(m.timing.late)
		if contacts >= 6 and float(m.timing.perfect) / contacts >= 0.5:
			gains.append(["Timed it: %d%% in the green" % int(100.0 * m.timing.perfect / contacts), 1])
		if out:
			var area := area_for(str(b.out))
			if area != "":
				if runs == 0:
					losses.append(["Duck", area, 2])
				elif runs < 10:
					losses.append(["Out for %d" % runs, area, 1])
		if balls >= 15 and sr < 90.0:
			losses.append(["Slow: strike rate %d" % int(sr), "power", 1])
	if won:
		gains.append(["Win", 1])
		if batted and not out:
			gains.append(["There at the finish", 1])
	var earned := 0
	for g: Array in gains:
		earned += int(g[1])
	return {"gains": gains, "losses": losses, "earned": earned}

func _apply(a: Dictionary) -> void:
	points += int(a.earned)
	for l: Array in a.losses:
		set(str(l[1]), maxf(FLOOR, float(rating(value(str(l[1]))) - int(l[2])) / 99.0))

# ---- Matches -----------------------------------------------------------------------------

## What MatchState.create needs for the next match. In the IPL, `advance` plays out the
## other fixtures up to yours (save the career afterwards); without it, a preview.
func match_opts(advance: bool = true) -> Dictionary:
	if tier >= IPL_TIER:
		return _ipl_opts(advance)
	var t := tier_info()
	var lineup: Array = MatchState.BLUE.duplicate()
	lineup[position()] = name
	var cond := Conditions.pick(next_seed)
	return {"blue_name": str(t.team), "red_name": opponent(), "target_scale": float(t.strength),
		"lineup": lineup, "attack": BowlerProfile.attack_for(next_seed), "pitch": cond.pitch, "night": cond.night,
		"career": _career_dict(float(t.mates), float(t.pace))}

func _career_dict(mates: float, pace: float) -> Dictionary:
	return {"pos": position(), "mode": "own", "tier": tier, "match": match_no + 1, "of": matches_in_season(),
		"power": power, "timing": timing, "placement": placement, "footwork": footwork, "role": role,
		"mates": mates, "pace": pace}

func _ipl_opts(advance: bool) -> Dictionary:
	if ipl_team == "":
		return {}
	IplData.register_bowlers()
	var s := Ipl.from_dict(ipl_season) if not ipl_season.is_empty() else Ipl.create(ipl_team, "ipl")
	var f := s.next_mine() if advance else s.peek_mine()
	if advance:
		ipl_season = s.to_dict()
	if f.is_empty():
		return {}
	var opts := s.match_opts(f, ipl_team)
	# You take a place in the XI: the weakest batter who doesn't bowl makes way.
	var lineup: Array = opts.lineup.duplicate()
	var skills: Array = opts.skills.duplicate()
	var bowlers: Array = opts.blue_bowlers
	var worst := -1
	var worst_v := 9.0
	for i in mini(8, lineup.size()):
		if bowlers.has(lineup[i]):
			continue
		var v := float(skills[i][1]) + float(skills[i][2])
		if v < worst_v:
			worst_v = v
			worst = i
	if worst >= 0:
		lineup.remove_at(worst)
		skills.remove_at(worst)
	lineup.insert(position(), name)
	skills.insert(position(), [role, power, timing])
	opts.lineup = lineup
	opts.skills = skills
	opts.career = _career_dict(1.0, 1.0)
	opts.career.of = _ipl_fixtures(s)
	opts.career.match = _ipl_played(s) + 1
	return opts

static func _ipl_fixtures(s: Ipl) -> int:
	var n := 0
	for f: Dictionary in s.fixtures():
		if s.mine(f):
			n += 1
	return n

static func _ipl_played(s: Ipl) -> int:
	var n := 0
	for f: Dictionary in s.fixtures():
		if s.mine(f) and s.results.has(f.key):
			n += 1
	return n

func ipl() -> Ipl:
	if ipl_season.is_empty():
		return Ipl.create(ipl_team, "ipl") if ipl_team != "" else null
	return Ipl.from_dict(ipl_season)

## The franchises that want you: the three whose XI is weakest where you bat.
func make_auction() -> void:
	var scored := []
	for code in IplData.ORDER:
		var xi: Array = IplData.team(code).xi
		var p: Array = xi[clampi(position(), 0, 10)]
		var jitter := float(absi(hash(code + str(next_seed))) % 100) / 1000.0
		scored.append([float(p[2]) + float(p[3]) + jitter, code])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	auction = [scored[0][1], scored[1][1], scored[2][1]]

func join(code: String) -> void:
	ipl_team = code
	ipl_season = Ipl.create(code, "ipl").to_dict()
	auction = []
	match_no = 0
	season_wins = 0
	season_runs = 0
	season_outs = 0

## Takes a finished match into the career. Returns what changed, for the summary card.
func record_match(m: MatchState) -> Dictionary:
	var i := position()
	var b: Dictionary = m.batters[i]
	var batted := int(b.balls) > 0 or str(b.out) != ""
	var out := str(b.out) != ""
	var runs := int(b.runs)
	var won := m.won()
	var a := assess(m)
	var report := {"runs": runs, "balls": int(b.balls), "out": str(b.out), "batted": batted, "won": won,
		"gains": a.gains, "losses": a.losses, "earned": a.earned, "promoted": false, "season_over": false}
	_apply(a)
	report.points = points
	stats.matches += 1
	if won:
		stats.wins += 1
		season_wins += 1
	if batted:
		stats.innings += 1
		stats.runs += runs
		stats.balls += int(b.balls)
		stats.fours += int(b.fours)
		stats.sixes += int(b.sixes)
		if not out:
			stats.not_outs += 1
		if runs > int(stats.hs) or (runs == int(stats.hs) and not out):
			stats.hs = runs
			stats.hs_not_out = not out
		if runs >= 100:
			stats.hundreds += 1
		elif runs >= 50:
			stats.fifties += 1
		if out and runs == 0:
			stats.ducks += 1
		season_runs += runs
		if out:
			season_outs += 1
	for k in timing_totals:
		timing_totals[k] += int(m.timing.get(k, 0))
	recent.push_front({"runs": runs, "balls": int(b.balls), "out": str(b.out), "batted": batted, "won": won,
		"opp": m.red_name, "tier": str(tier_info().name), "fours": int(b.fours), "sixes": int(b.sixes)})
	if recent.size() > 12:
		recent.pop_back()
	match_no += 1
	next_seed += 7919
	if tier >= IPL_TIER and not m.ipl.is_empty():
		_record_ipl(m, report)
	elif match_no >= matches_in_season():
		report.season_over = true
		var avg := float(season_runs) / maxf(season_outs, 1)
		var up := float(season_wins) >= ceilf(matches_in_season() * PROMOTE_WINS) or avg >= PROMOTE_AVERAGE
		history.push_front("Season %d · %s · %d-%d · %d runs at %.1f%s" % [season, tier_info().name, season_wins,
			matches_in_season() - season_wins, season_runs, avg, "  · PROMOTED" if up else ""])
		report.promoted = up
		report.season_line = history[0]
		if up:
			tier += 1
			if tier >= IPL_TIER:
				make_auction()
		_new_season()
	return report

func _record_ipl(m: MatchState, report: Dictionary) -> void:
	var s := ipl()
	s.record(m)
	if s.peek_mine().is_empty():
		# Your season is done: the rest is played out, and a new season starts.
		s.sim_to_end()
		var rows := s.table()
		var avg := float(season_runs) / maxf(season_outs, 1)
		history.push_front("IPL season %d · %s · finished %d · %d runs at %.1f · champions %s" % [season, ipl_team,
			s.position(), season_runs, avg, s.champion])
		report.season_over = true
		report.season_line = history[0]
		report.champions = s.champion
		ipl_season = Ipl.create(ipl_team, "ipl").to_dict()
		_new_season()
	else:
		ipl_season = s.to_dict()

func _new_season() -> void:
	season += 1
	match_no = 0
	season_wins = 0
	season_runs = 0
	season_outs = 0

func average() -> float:
	var outs := int(stats.innings) - int(stats.not_outs)
	return float(stats.runs) / maxf(outs, 1)

func strike_rate() -> float:
	return 100.0 * float(stats.runs) / maxf(float(stats.balls), 1.0)

# ---- Saving ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"v": 2, "name": name, "role": role, "power": power, "timing": timing, "placement": placement,
		"footwork": footwork, "points": points, "tier": tier, "season": season,
		"match_no": match_no, "season_wins": season_wins, "season_runs": season_runs, "season_outs": season_outs,
		"next_seed": next_seed, "ipl_team": ipl_team, "ipl_season": ipl_season, "auction": auction,
		"stats": stats, "timing_totals": timing_totals, "recent": recent, "history": history}

static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	c.name = str(d.get("name", "You"))
	c.role = str(d.get("role", "Opener"))
	var st: Array = ROLES.get(c.role, ROLES["Opener"]).start
	c.power = float(d.get("power", st[0]))
	c.timing = float(d.get("timing", st[1]))
	c.placement = float(d.get("placement", st[2]))
	c.footwork = float(d.get("footwork", st[3]))
	for k in ["points", "tier", "season", "match_no", "season_wins", "season_runs", "season_outs", "next_seed"]:
		c.set(k, int(d.get(k, c.get(k))))
	c.ipl_team = str(d.get("ipl_team", ""))
	c.ipl_season = d.get("ipl_season", {})
	c.auction = d.get("auction", [])
	# Older saves had a franchise and an international level: both are the IPL now.
	if c.tier > IPL_TIER:
		c.tier = IPL_TIER
	if c.tier == IPL_TIER and c.ipl_team == "" and c.auction.is_empty():
		c.make_auction()
	var sd: Dictionary = d.get("stats", {})
	for k in c.stats:
		c.stats[k] = (bool(sd.get(k, false)) if k == "hs_not_out" else int(sd.get(k, 0)))
	var tt: Dictionary = d.get("timing_totals", {})
	for k in c.timing_totals:
		c.timing_totals[k] = int(tt.get(k, 0))
	c.recent = d.get("recent", [])
	c.history = d.get("history", [])
	return c

static func load_saved() -> Career:
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
