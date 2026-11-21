class_name Career
extends RefCounted
## A batting career: your player, their ratings, the level you play at, your season and
## every innings you have played. Saved in user://career.json.
##
## You start at club level. A season is a handful of chases; win enough of them, or average
## enough yourself, and you move up: club, state, franchise, international. Your ratings
## grow from how you actually bat: timing from how often you middle it, power from how far
## you hit it.

const PATH := "user://career.json"
const TIERS := [
	{"name": "CLUB", "team": "RIVERSIDE CC", "matches": 5, "strength": 0.82, "mates": 0.82, "pace": 0.87,
		"opps": ["HILLCREST CC", "OLD TOWN CC", "EASTGATE CC", "MILLBROOK CC", "SEAVIEW CC"]},
	{"name": "STATE", "team": "NORTHERN STATE", "matches": 5, "strength": 0.92, "mates": 0.9, "pace": 0.93,
		"opps": ["SOUTHERN STATE", "COASTAL", "CENTRAL", "HIGHLANDS", "WESTERN"]},
	{"name": "FRANCHISE", "team": "HARBOUR HAWKS", "matches": 6, "strength": 1.0, "mates": 0.97, "pace": 0.98,
		"opps": ["CITY TITANS", "DESERT FALCONS", "RIVER KINGS", "SUMMIT STRIKERS", "BAY ROYALS", "VALLEY VIPERS"]},
	{"name": "INTERNATIONAL", "team": "NORTHLAND", "matches": 6, "strength": 1.08, "mates": 1.0, "pace": 1.0,
		"opps": ["SOUTHLAND", "EASTLAND", "WESTLAND", "ISLAND XI", "CONTINENTAL XI", "HIGHLAND XI"]},
]
## Role: batting position (0-based) and starting ratings [power, timing].
const ROLES := {
	"Opener": {"pos": 0, "start": [0.50, 0.60]},
	"Top order": {"pos": 2, "start": [0.52, 0.60]},
	"Middle order": {"pos": 3, "start": [0.58, 0.52]},
	"Finisher": {"pos": 5, "start": [0.64, 0.46]},
}
const ROLE_ORDER := ["Opener", "Top order", "Middle order", "Finisher"]
## Win this share of a season's matches, or average this much, to go up a level.
const PROMOTE_WINS := 0.6
const PROMOTE_AVERAGE := 35.0

## Set by the career page before it opens the match; read by the match.
static var active := false

var name := "You"
var role := "Opener"
var power := 0.5
var timing := 0.6
var tier := 0
var season := 1
var match_no := 0              # matches played this season
var season_wins := 0
var season_runs := 0
var season_outs := 0
var next_seed := 1
var stats := {"matches": 0, "innings": 0, "not_outs": 0, "runs": 0, "balls": 0, "hs": 0, "hs_not_out": false,
	"fifties": 0, "hundreds": 0, "fours": 0, "sixes": 0, "ducks": 0, "wins": 0}
var timing_totals := {"perfect": 0, "early": 0, "late": 0, "miss": 0}
var recent: Array = []         # newest first: {runs, balls, out, won, opp, tier, fours, sixes}
var history: Array = []        # one line per finished season

static func create(player_name: String, player_role: String) -> Career:
	var c := Career.new()
	c.name = player_name.strip_edges() if player_name.strip_edges() != "" else "You"
	c.role = player_role if ROLES.has(player_role) else "Opener"
	c.power = ROLES[c.role].start[0]
	c.timing = ROLES[c.role].start[1]
	c.next_seed = int(Time.get_unix_time_from_system()) % 100000 + 1
	return c

func position() -> int:
	return int(ROLES[role].pos)

func tier_info() -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]

func matches_in_season() -> int:
	return int(tier_info().matches)

func opponent() -> String:
	var opps: Array = tier_info().opps
	return str(opps[match_no % opps.size()])

func skill() -> BatterSkill:
	return BatterSkill.new(role, power, timing)

## Ratings as the game shows them, out of 99.
static func rating(v: float) -> int:
	return clampi(int(round(v * 99.0)), 1, 99)

func overall() -> int:
	return rating(power * 0.45 + timing * 0.55)

func average() -> float:
	var outs := int(stats.innings) - int(stats.not_outs)
	return float(stats.runs) / maxf(outs, 1)

func strike_rate() -> float:
	return 100.0 * float(stats.runs) / maxf(float(stats.balls), 1.0)

## What MatchState.create needs for the next match.
func match_opts() -> Dictionary:
	var t := tier_info()
	var lineup: Array = MatchState.BLUE.duplicate()
	lineup[position()] = name
	var cond := Conditions.pick(next_seed)
	return {"blue_name": str(t.team), "red_name": opponent(), "target_scale": float(t.strength),
		"lineup": lineup, "attack": BowlerProfile.attack_for(next_seed), "pitch": cond.pitch, "night": cond.night,
		"career": {"pos": position(), "mode": "own", "tier": tier, "match": match_no + 1, "of": matches_in_season(),
			"power": power, "timing": timing, "role": role, "mates": float(t.mates), "pace": float(t.pace)}}

## Takes a finished match into the career. Returns what changed, for the summary card.
func record_match(m: MatchState) -> Dictionary:
	var i := position()
	var b: Dictionary = m.batters[i]
	var batted := int(b.balls) > 0 or str(b.out) != ""
	var out := str(b.out) != ""
	var runs := int(b.runs)
	var won := m.won()
	var report := {"runs": runs, "balls": int(b.balls), "out": str(b.out), "batted": batted, "won": won,
		"power_before": rating(power), "timing_before": rating(timing), "promoted": false, "season_over": false}
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
	# Ratings grow from how you batted: middle it to time it better, hit it far to hit harder.
	var contacts := int(m.timing.perfect) + int(m.timing.early) + int(m.timing.late)
	if batted:
		var middled := float(m.timing.perfect) / maxf(contacts, 1)
		timing = minf(1.0, timing + 0.004 + (0.03 * middled if contacts >= 4 else 0.0))
		power = minf(1.0, power + 0.004 + minf(0.03, 0.004 * (int(b.fours) + 2 * int(b.sixes))))
	report.power_after = rating(power)
	report.timing_after = rating(timing)
	recent.push_front({"runs": runs, "balls": int(b.balls), "out": str(b.out), "batted": batted, "won": won,
		"opp": m.red_name, "tier": str(tier_info().name), "fours": int(b.fours), "sixes": int(b.sixes)})
	if recent.size() > 12:
		recent.pop_back()
	match_no += 1
	next_seed += 7919
	if match_no >= matches_in_season():
		report.season_over = true
		var avg := float(season_runs) / maxf(season_outs, 1)
		var up := (float(season_wins) >= ceilf(matches_in_season() * PROMOTE_WINS) or avg >= PROMOTE_AVERAGE) and tier < TIERS.size() - 1
		history.push_front("Season %d · %s · %d-%d · %d runs at %.1f%s" % [season, tier_info().name, season_wins,
			matches_in_season() - season_wins, season_runs, avg, "  · PROMOTED" if up else ""])
		report.promoted = up
		report.season_line = history[0]
		if up:
			tier += 1
		season += 1
		match_no = 0
		season_wins = 0
		season_runs = 0
		season_outs = 0
	return report

func to_dict() -> Dictionary:
	return {"v": 1, "name": name, "role": role, "power": power, "timing": timing, "tier": tier, "season": season,
		"match_no": match_no, "season_wins": season_wins, "season_runs": season_runs, "season_outs": season_outs,
		"next_seed": next_seed, "stats": stats, "timing_totals": timing_totals, "recent": recent, "history": history}

static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	c.name = str(d.get("name", "You"))
	c.role = str(d.get("role", "Opener"))
	c.power = float(d.get("power", 0.5))
	c.timing = float(d.get("timing", 0.6))
	for k in ["tier", "season", "match_no", "season_wins", "season_runs", "season_outs", "next_seed"]:
		c.set(k, int(d.get(k, c.get(k))))
	var st: Dictionary = d.get("stats", {})
	for k in c.stats:
		c.stats[k] = (bool(st.get(k, false)) if k == "hs_not_out" else int(st.get(k, 0)))
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
