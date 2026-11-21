extends TestCase
## Career mode: your player, your numbers, moving up, and team-mates' simulated balls.

func _career_match(c: Career) -> MatchState:
	return MatchState.create(c.next_seed, c.match_opts())

func test_your_player_bats_in_their_slot() -> void:
	var c := Career.create("Sam Okoro", "Top order")
	var m := _career_match(c)
	check(m.batters[2].name == "Sam Okoro", "you bat at three (%s)" % m.batters[2].name)
	check(m.skill_for(2).power == c.power and m.skill_for(2).timing == c.timing, "with your own ratings")
	check(m.blue_name == "RIVERSIDE CC" and m.red_name == "HILLCREST CC", "club cricket first: %s v %s" % [m.blue_name, m.red_name])
	check(m.skill_for(0).power < MatchState.skill_of(0).power, "club team-mates are weaker than the quick-match side")
	check(not m.players_ball(), "the openers' balls are not yours")

func test_an_innings_goes_into_the_numbers() -> void:
	var c := Career.create("A", "Opener")
	var m := _career_match(c)
	m.batters[0].runs = 62
	m.batters[0].balls = 40
	m.batters[0].fours = 6
	m.batters[0].sixes = 2
	m.batters[0].out = "c cover b Venn"
	m.timing = {"perfect": 20, "early": 10, "late": 8, "miss": 2}
	m.runs = m.target
	var t0 := c.timing
	var rep := c.record_match(m)
	check(c.stats.runs == 62 and c.stats.innings == 1 and c.stats.fifties == 1 and c.stats.hs == 62, "runs, innings, fifty, highest")
	check(c.stats.wins == 1 and rep.won, "a win")
	# 62 runs: 6, fifty: 2, strike rate 155: 1, timed it (20 of 38 in the green): 1, win: 1.
	check(c.points == 11 and rep.earned == 11, "11 points for 62 off 40 in a win (%d)" % c.points)
	check(c.timing == t0, "abilities only change when you spend points")
	check(is_equal_approx(c.average(), 62.0) and is_equal_approx(c.strike_rate(), 155.0), "average %.1f, strike rate %.1f" % [c.average(), c.strike_rate()])
	check(c.match_no == 1 and c.recent.size() == 1, "one match into the season")

func test_a_good_season_moves_you_up() -> void:
	var c := Career.create("A", "Opener")
	for i in c.matches_in_season():
		var m := _career_match(c)
		m.batters[0].runs = 40
		m.batters[0].balls = 30
		m.batters[0].out = "b Venn"
		m.runs = m.target   # won
		c.record_match(m)
	check(c.tier == 1 and c.season == 2 and c.match_no == 0, "promoted to %s, season %d" % [c.tier_info().name, c.season])
	check(c.history.size() == 1 and str(c.history[0]).contains("PROMOTED"), str(c.history))
	var m2 := _career_match(c)
	check(m2.blue_name == "NORTHERN STATE", "now playing for the state side")

func test_a_bad_season_keeps_you_there() -> void:
	var c := Career.create("A", "Opener")
	for i in c.matches_in_season():
		var m := _career_match(c)
		m.batters[0].runs = 5
		m.batters[0].balls = 9
		m.batters[0].out = "b Venn"
		m.wickets = 10   # lost
		c.record_match(m)
	check(c.tier == 0 and c.season == 2, "still club cricket, season 2")

func test_career_survives_a_save() -> void:
	var c := Career.create("Priya", "Finisher")
	var m := _career_match(c)
	m.batters[5].runs = 17
	m.batters[5].balls = 8
	c.record_match(m)
	var r := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(r.name == "Priya" and r.role == "Finisher" and r.stats.runs == 17 and r.stats.not_outs == 1, "name, role, runs, not out")
	check(is_equal_approx(r.power, c.power) and r.next_seed == c.next_seed, "ratings and next match")
	var mm := MatchState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(int(mm.career.pos) == 5 and mm.blue_name == m.blue_name and mm.pitch == m.pitch, "a career match saves too")

func test_did_not_bat_is_not_an_innings() -> void:
	var c := Career.create("A", "Finisher")
	var m := _career_match(c)
	m.runs = m.target
	var rep := c.record_match(m)
	check(not rep.batted and c.stats.innings == 0 and c.stats.matches == 1, "DNB counts a match, not an innings")

func test_simulated_chases_look_like_cricket() -> void:
	# The quick-match Blue side, played out entirely by the simulator, against Red's real totals.
	var wins := 0
	var outs := 0
	for sd in 60:
		var m := MatchState.create(sd + 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		while not m.finished():
			var r := BallSim.ball(m, rng)
			m.record(int(r[0]), str(r[1]))
		if m.won():
			wins += 1
		outs += m.wickets
	check(wins > 15 and wins < 45, "simulated side wins %d of 60 chases" % wins)
	check(outs / 60 >= 3 and outs / 60 <= 9, "losing %d wickets on average" % (outs / 60))

func test_club_bowlers_are_slower() -> void:
	var c := Career.create("A", "Opener")
	var club := _career_match(c)
	var quick := MatchState.create(c.next_seed)
	var a := BowlingMachine.new(9)
	var b := BowlingMachine.new(9)
	var prof := BowlerProfile.of("D. Hartigan")
	var s1 := a.next_for("pace", 3, "", prof, club.conditions()).speed
	var s2 := b.next_for("pace", 3, "", prof, quick.conditions()).speed
	check(s1 < s2 * 0.9, "club %.0f km/h v international %.0f km/h" % [s1 * 3.6, s2 * 3.6])


func test_spending_points() -> void:
	var c := Career.create("A", "Opener")
	c.points = 5
	var before := Career.rating(c.footwork)
	check(c.spend("footwork") and Career.rating(c.footwork) == before + 1 and c.points == 4, "one point, one rating")
	c.timing = 0.85
	check(c.cost("timing") == 2, "dearer at the top (%d)" % c.cost("timing"))
	c.timing = 0.93
	check(c.cost("timing") == 3, "dearer still above 90")
	c.points = 2
	check(not c.can_spend("timing"), "can't spend what you haven't got")

func test_a_cheap_dismissal_costs_the_right_thing() -> void:
	check(Career.area_for("b Venn") == "timing" and Career.area_for("lbw b Venn") == "timing", "bowled and lbw: timing")
	check(Career.area_for("st †keeper b Whitlock") == "footwork", "stumped: footwork")
	check(Career.area_for("c long-on b Venn") == "power" and Career.area_for("c deep midwicket b Venn") == "power", "caught in the deep: power")
	check(Career.area_for("c cover b Venn") == "placement", "caught in the ring: placement")
	check(Career.area_for("c †keeper b Venn") == "timing", "caught behind: timing")
	var c := Career.create("A", "Opener")
	var m := _career_match(c)
	m.batters[0].balls = 2
	m.batters[0].out = "c long-on b Venn"
	m.wickets = 10
	var p0 := Career.rating(c.power)
	var rep := c.record_match(m)
	check(Career.rating(c.power) == p0 - 2 and rep.losses.size() == 1, "a duck caught in the deep costs 2 power (%d → %d)" % [p0, Career.rating(c.power)])
	check(c.points == 0, "and earns nothing")

func test_state_success_leads_to_the_ipl_auction() -> void:
	var c := Career.create("Sam Okoro", "Top order")
	c.tier = 1
	for i in c.matches_in_season():
		var m := _career_match(c)
		m.batters[2].runs = 45
		m.batters[2].balls = 30
		m.batters[2].out = "b Venn"
		m.runs = m.target
		c.record_match(m)
	check(c.tier == Career.IPL_TIER and c.auction.size() == 3 and c.ipl_team == "", "promoted to the IPL: offers %s" % str(c.auction))
	check(c.match_opts(false).is_empty(), "no match until you pick a team")
	c.join(str(c.auction[0]))
	var opts := c.match_opts(false)
	check(opts.has("ipl") and str(opts.blue_name) == c.ipl_team, "an IPL fixture for %s" % c.ipl_team)
	check(opts.lineup[2] == "Sam Okoro" and opts.lineup.size() == 11, "you bat at three in an XI of eleven")
	var bowlers: Array = opts.blue_bowlers
	for b in bowlers:
		check(opts.lineup.has(b), "%s still plays" % b)

func test_an_ipl_career_season() -> void:
	var c := Career.create("A", "Opener")
	c.tier = Career.IPL_TIER
	c.join("RR")
	var played := 0
	var guard := 0
	while guard < 20:
		guard += 1
		var opts := c.match_opts(true)
		if opts.is_empty():
			break
		IplData.register_bowlers()
		var m := MatchState.create(Ipl.seed_for({"n": int(opts.ipl.n)}), opts)
		check(m.skill_for(0).role.begins_with("You"), "you open for RR")
		var rng := RandomNumberGenerator.new()
		rng.seed = guard
		while not m.finished():
			var r := BallSim.ball(m, rng)
			m.record(int(r[0]), str(r[1]))
		var rep := c.record_match(m)
		played += 1
		if rep.season_over:
			check(str(rep.season_line).begins_with("IPL season 1 · RR"), str(rep.season_line))
			break
	check(played >= 14 and played <= 18, "a season is 14 matches plus any play-offs (%d)" % played)
	check(c.season == 2 and c.ipl_team == "RR" and c.match_no == 0, "a new IPL season with RR")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(again.ipl_team == "RR" and again.history.size() == 1 and again.points == c.points, "an IPL career saves")
