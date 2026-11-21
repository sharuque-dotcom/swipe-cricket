extends TestCase
## IPL mode: the data, a season played out, the table and the play-offs.

func test_squads_and_elevens_are_sound() -> void:
	for code in IplData.ORDER:
		var t := IplData.team(code)
		check(t.xi.size() == 11, "%s has an XI (%d)" % [code, t.xi.size()])
		check(t.attack.size() == 5, "%s has five bowlers" % code)
		check(t.squad.size() == 25, "%s squad of 25 (%d)" % [code, t.squad.size()])
		var squad := {}
		var overseas := 0
		for n: String in t.squad:
			squad[n.trim_suffix("*")] = n.ends_with("*")
		for p: Array in t.xi:
			check(squad.has(str(p[0])), "%s: %s is in the squad" % [code, p[0]])
			if squad.get(str(p[0]), false):
				overseas += 1
		check(overseas <= 4, "%s: %d overseas in the XI" % [code, overseas])
		var xi := IplData.xi_names(code)
		for a: Array in t.attack:
			check(xi.has(str(a[0])), "%s: %s bowls and is in the XI" % [code, a[0]])
			check(IplData.STYLES.has(str(a[1])), "%s: %s has a known style" % [code, a[0]])
		check(IplData.GROUNDS.has(str(t.home)), "%s home ground plays a known way" % code)

func test_every_team_plays_fourteen() -> void:
	var count := {}
	for f: Array in IplData.FIXTURES:
		count[f[2]] = count.get(f[2], 0) + 1
		count[f[3]] = count.get(f[3], 0) + 1
		check(IplData.GROUNDS.has(str(f[4])), "ground %s is known" % f[4])
	for code in IplData.ORDER:
		check(int(count.get(code, 0)) == 14, "%s plays %d" % [code, count.get(code, 0)])
	check(IplData.FIXTURES.size() == 70, "70 league matches")

func test_a_whole_season() -> void:
	var s := Ipl.create("MI")
	# Play every match by simulation, yours included.
	var f := s.next_fixture()
	var guard := 0
	while not f.is_empty() and guard < 100:
		s.sim_fixture(f)
		f = s.next_fixture()
		guard += 1
	check(s.results.size() == 74, "70 league games and 4 play-offs (%d)" % s.results.size())
	var t := s.table()
	var pts := 0
	for row: Dictionary in t:
		check(int(row.p) == 14, "%s played %d" % [row.code, row.p])
		pts += int(row.pts)
	check(pts == 140, "140 points handed out (%d)" % pts)
	check(t[0].pts >= t[9].pts and (t[0].pts > t[1].pts or t[0].nrr >= t[1].nrr), "the table is in order")
	check(s.champion != "" and IplData.TEAMS.has(s.champion), "a champion: %s" % s.champion)
	var finalists := [str(s.results["Final"].first), str(s.results["Final"].chase)]
	check(finalists.has(s.champion), "the champion played the final")
	var top4 := [t[0].code, t[1].code, t[2].code, t[3].code]
	check(top4.has(finalists[0]) and top4.has(finalists[1]), "finalists came from the top four")
	var r := Ipl.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(r.champion == s.champion and r.results.size() == 74 and r.table()[0].code == t[0].code, "a season survives a save")

func test_your_match_is_your_xi_against_their_attack() -> void:
	var s := Ipl.create("RCB")
	var f := s.next_mine()
	check(int(f.n) == 1 and str(f.home) == "RCB" and str(f.away) == "SRH", "RCB open the season against SRH")
	IplData.register_bowlers()
	var m := MatchState.create(Ipl.seed_for(f), s.match_opts(f, "RCB"))
	check(m.batters[1].name == "Virat Kohli", "Kohli at two (%s)" % m.batters[1].name)
	check(m.attack.has("Pat Cummins") and m.red_card[0].name == "Travis Head", "SRH's attack and SRH's batters")
	check(BowlerProfile.of("Pat Cummins").label == "RIGHT-ARM FAST", "Cummins bowls fast")
	check(m.pitch == "flat" and m.skill_for(1).timing > 0.9, "a Bengaluru road; Kohli times it")
	var mi := Ipl.create("MI")
	var g := mi.next_mine()
	check(int(g.n) == 2, "MI's first match is match 2")
	check(mi.results.has("L1"), "match 1 was simulated on the way")
