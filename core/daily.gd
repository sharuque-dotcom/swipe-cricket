class_name Daily
extends RefCounted
## Chase of the Day: one finish per date, the same for every run of the game on that day.
## Need so many off so many with a few wickets left, against a named bowler. The first try
## of the day counts toward the streak; you can replay it, but only for fun.

const SETTINGS_KEY := "daily"
const EPOCH := "2026-11-24"     # Chase of the Day #1

## Set by the menu before it opens the match.
static var active := false

static func today() -> String:
	return Time.get_date_string_from_system()

static func number(date: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(EPOCH + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	return int((b - a) / 86400) + 1

## The scenario for a date: {date, n, balls, need, wickets_left, target, pitch, night, attack}.
static func scenario(date: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chase-of-the-day-" + date)
	var balls: int = [6, 9, 12, 12, 18, 18, 24, 30][rng.randi() % 8]
	var rate := rng.randf_range(1.35, 2.25)        # runs a ball
	var need := int(round(balls * rate))
	var wkts: int = [2, 3, 3, 4, 4, 5, 6][rng.randi() % 7]
	var target := 150 + rng.randi() % 50
	var pitches := ["good", "flat", "dusty", "green"]
	var atk: Array = BowlerProfile.DEFAULT_ATTACK.duplicate()
	# Shuffle the attack so a different bowler has the ball at the death each day.
	for i in range(atk.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = atk[i]
		atk[i] = atk[j]
		atk[j] = t
	return {"date": date, "n": number(date), "balls": balls, "need": need, "wickets_left": wkts, "target": target,
		"pitch": pitches[rng.randi() % pitches.size()], "night": rng.randf() < 0.6, "attack": atk}

## MatchState options for the scenario.
static func match_opts(sc: Dictionary) -> Dictionary:
	return {"pitch": sc.pitch, "night": sc.night, "attack": sc.attack, "daily": {"date": sc.date, "n": sc.n}}

## Puts a fresh match at the point the scenario starts: the overs gone, the runs on the
## board, the wickets down.
static func apply(m: MatchState, sc: Dictionary) -> void:
	m.target = int(sc.target)
	m.red_total = m.target - 1
	var gone := MatchState.OVERS * MatchState.BALLS_PER_OVER - int(sc.balls)
	m.balls = gone
	m.runs = m.target - int(sc.need)
	m.wickets = MatchState.MAX_WICKETS - int(sc.wickets_left)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("daily-card-" + str(sc.date))
	# Who's out, and the two batting: the score shared out roughly.
	var left := m.runs
	for i in m.wickets:
		var r := mini(left, rng.randi_range(4, 38))
		left -= r
		m.batters[i].runs = r
		m.batters[i].balls = maxi(r - rng.randi_range(-4, 8), 3)
		m.batters[i].out = "c & b"
	m.striker = m.wickets
	m.non_striker = m.wickets + 1
	m.batters[m.striker].runs = left / 2
	m.batters[m.striker].balls = maxi(left / 2 - 3, 2)
	m.batters[m.non_striker].runs = left - left / 2
	m.batters[m.non_striker].balls = maxi(left - left / 2 - 2, 2)
	# The bowlers' figures for the overs gone.
	var per_over := float(m.runs) / maxf(float(gone) / 6.0, 1.0)
	for o in gone / MatchState.BALLS_PER_OVER:
		var b: Dictionary = m.bowling[MatchState.PLAN[o]]
		b.balls += 6
		b.runs += int(round(per_over))
	for i in m.wickets:
		m.bowling[MatchState.PLAN[(i * 3) % maxi(gone / 6, 1)]].wkts += 1
	m.this_over = []

# ---- Streak --------------------------------------------------------------------------------

static func _load() -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	return cf.get_value("daily", "stats", {"last": "", "result": "", "streak": 0, "best": 0, "played": 0, "won": 0})

static func _store(d: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	cf.set_value("daily", "stats", d)
	cf.save(Settings.PATH)

static func stats() -> Dictionary:
	var d := _load()
	# A missed day breaks the streak.
	if str(d.last) != "" and str(d.last) != today() and number(today()) - number(str(d.last)) > 1:
		d.streak = 0
	return d

static func played_today() -> bool:
	return str(_load().last) == today()

## Records a finished chase; only the day's first attempt counts. Returns the stats.
static func record(date: String, won: bool) -> Dictionary:
	var d := stats()
	if str(d.last) == date:
		return d
	d.last = date
	d.result = "WON" if won else "LOST"
	d.played = int(d.played) + 1
	if won:
		d.won = int(d.won) + 1
		d.streak = int(d.streak) + 1
		d.best = maxi(int(d.best), int(d.streak))
	else:
		d.streak = 0
	_store(d)
	return d
