extends TestCase
## BBL|16 mode: the data, a season played out, and the finals.

func test_squads_and_elevens_are_sound() -> void:
	for code in BblData.ORDER:
		var t := BblData.team(code)
		check(t.xi.size() == 11, "%s has an XI (%d)" % [code, t.xi.size()])
		check(t.attack.size() == 5, "%s has five bowlers" % code)
		var squad := {}
		var overseas := 0
		for n: String in t.squad:
			squad[n.trim_suffix("*")] = n.ends_with("*")
		for p: Array in t.xi:
			check(squad.has(str(p[0])), "%s: %s is in the squad" % [code, p[0]])
			if squad.get(str(p[0]), false):
				overseas += 1
		check(overseas <= 3, "%s: %d overseas in the XI" % [code, overseas])
		for a: Array in t.attack:
			check(squad.has(str(a[0])), "%s: %s bowls and is in the squad" % [code, a[0]])
			check(BblData.STYLES.has(str(a[1])), "%s: %s has a known style" % [code, a[0]])
		check(BblData.GROUNDS.has(str(t.home)), "%s home ground plays a known way" % code)

func test_every_team_plays_ten() -> void:
	var count := {}
	for f: Array in BblData.FIXTURES:
		count[f[2]] = count.get(f[2], 0) + 1
		count[f[3]] = count.get(f[3], 0) + 1
		check(BblData.GROUNDS.has(str(f[4])), "ground %s is known" % f[4])
	for code in BblData.ORDER:
		check(int(count.get(code, 0)) == 10, "%s plays %d" % [code, count.get(code, 0)])
	check(BblData.FIXTURES.size() == 40, "40 league matches")

func test_a_whole_season_and_finals() -> void:
	var s := Ipl.create("BH", "bbl")
	var f := s.next_fixture()
	var guard := 0
	while not f.is_empty() and guard < 60:
		s.sim_fixture(f)
		f = s.next_fixture()
		guard += 1
	check(s.results.size() == 44, "40 league games and 4 finals (%d)" % s.results.size())
	for k in ["Qualifier", "Knockout", "Challenger", "Final"]:
		check(s.results.has(k), "the %s was played" % k)
	var t := s.table()
	var pts := 0
	for row: Dictionary in t:
		pts += int(row.pts)
	check(pts == 80, "80 points handed out (%d)" % pts)
	check(s.champion != "" and BblData.TEAMS.has(s.champion), "a champion: %s" % s.champion)
	var r := Ipl.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(r.lg == "bbl" and r.champion == s.champion, "a BBL season survives a save")

func test_bbl_scores_are_believable() -> void:
	var s := Ipl.create("PS", "bbl")
	var total := 0
	var n := 0
	for f: Dictionary in s.fixtures().slice(0, 20):
		s.sim_fixture(f)
		total += int(s.results[f.key].first_runs)
		n += 1
	var avg := float(total) / n
	check(avg > 150.0 and avg < 190.0, "first innings average %.0f" % avg)

func test_opener_is_in_chennai_at_night() -> void:
	var s := Ipl.create("MR", "bbl")
	var f := s.next_mine()
	check(int(f.n) == 1 and str(f.ground) == "Chennai", "Renegades open in Chennai")
	BblData.register_bowlers()
	var m := MatchState.create(Ipl.seed_for(f, "bbl"), s.match_opts(f, "MR"))
	check(m.night and m.attack.has("Jhye Richardson"), "a night game against the Scorchers' attack")
	check(m.batters[0].name == "Jake Fraser-McGurk", "Fraser-McGurk opens")
