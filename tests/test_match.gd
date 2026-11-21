extends TestCase

func _exit(dir_deg: float, elev_deg: float, speed: float) -> BallPhysics.State:
	var s := BallPhysics.State.new()
	s.pos = Vector3(0.1, 0.8, -1.2)
	var a := deg_to_rad(dir_deg)
	var e := deg_to_rad(elev_deg)
	s.vel = (Vector3(sin(a), 0.0, -cos(a)) * cos(e) + Vector3.UP * sin(e)) * speed
	return s

func _spot(field: Array, name: String) -> Fielding.Spot:
	for s in field:
		if s.name == name:
			return s
	return null

func test_skier_to_a_fielder_is_caught() -> void:
	# A gentle lofted hit that comes down near mid-on.
	var field := Fielding.layout(false)
	var r := Fielding.evaluate(_exit(-18.0, 48.0, 18.0), field)
	check(r.caught, "a slow skier near mid-on should be caught (fielder %s, %.0f m)" % [r.fielder_name, r.distance])

func test_big_hit_is_six() -> void:
	var r := Fielding.evaluate(_exit(5.0, 32.0, 40.0), Fielding.layout(false))
	check(r.six and not r.caught, "a 40 m/s lofted straight hit clears the rope")

func test_ground_shot_through_gap_is_four() -> void:
	# Along the ground between cover and mid-off.
	var field := Fielding.layout(false)
	var a := _spot(field, "mid-off").pos
	var b := _spot(field, "cover").pos
	var mid := (rad_to_deg(atan2(a.x, -(a.z + 1.0))) + rad_to_deg(atan2(b.x, -(b.z + 1.0)))) * 0.5
	var r := Fielding.evaluate(_exit(mid, 2.0, 34.0), field)
	check(r.boundary and not r.six, "hard ground drive through the covers gap (got %d runs, %s)" % [r.runs, r.fielder_name])

func test_push_to_fielder_is_no_run() -> void:
	# Soft push straight at mid-off.
	var mo := _spot(Fielding.layout(false), "mid-off").pos
	var dir := rad_to_deg(atan2(mo.x - 0.1, -(mo.z + 1.2)))
	var r := Fielding.evaluate(_exit(dir, 1.0, 13.0), Fielding.layout(false))
	check(not r.boundary and not r.caught and r.runs <= 1, "push to mid-off: %d runs" % r.runs)

func test_strike_rotates_and_overs_change_ends() -> void:
	var m := MatchState.create(4)
	check(m.target > 100 and m.target < 240, "target %d is a T20 total" % m.target)
	var first := m.striker_name()
	m.record(1)
	check(m.striker_name() != first, "a single changes the strike")
	for i in 5:
		m.record(0)
	check(m.overs_text() == "1.0", "six balls make an over (%s)" % m.overs_text())
	check(m.striker_name() == first, "over ended: ends swap back")
	check(m.bowler_index() == MatchState.PLAN[1], "new over, next bowler")

func test_wickets_bring_new_batters_and_end_the_innings() -> void:
	var m := MatchState.create(5)
	var ev := m.record(0, "b Venn")
	check(ev.wicket and ev.new_batter == MatchState.BLUE[2], "number three comes in")
	for i in 9:
		ev = m.record(0, "b Venn")
	check(m.wickets == 10 and m.finished() and ev.finished, "ten wickets end the chase")
	check(m.result_text().begins_with("RED WIN"), m.result_text())

func test_chase_won() -> void:
	var m := MatchState.create(6)
	m.runs = m.target - 4
	var ev := m.record(4)
	check(ev.finished and m.won() and m.result_text() == "BLUE WIN by 10 wickets", m.result_text())

func test_save_and_resume() -> void:
	var m := MatchState.create(8)
	m.record(4)
	m.record(0, "c cover b Venn")
	m.machine_state = 123456789
	var j := JSON.stringify(m.to_dict())
	var r := MatchState.from_dict(JSON.parse_string(j))
	check(r.runs == 4 and r.wickets == 1 and r.balls == 2 and r.target == m.target, "score survives a save")
	check(r.striker_name() == m.striker_name() and r.machine_state == 123456789, "strike and bowling machine survive")

func test_red_totals_look_like_t20() -> void:
	var lo := 999
	var hi := 0
	for sd in 40:
		var t := InningsSim.run(sd + 1, MatchState.RED).total
		lo = mini(lo, t)
		hi = maxi(hi, t)
	check(lo > 95 and hi < 240, "red totals between %d and %d" % [lo, hi])

func test_field_has_eleven_and_keeper_stands_back() -> void:
	for spinner in [false, true]:
		for powerplay in [false, true]:
			var f := Fielding.layout(spinner, powerplay)
			check(f.size() == 11, "eleven in the field (got %d)" % f.size())
			check(f[0].kind == Fielding.Kind.KEEPER and f[0].pos.z > 5.0, "keeper stands back, behind the camera")

func test_fielded_ball_reports_where_it_is_taken() -> void:
	var mo := _spot(Fielding.layout(false), "mid-off").pos
	var dir := rad_to_deg(atan2(mo.x - 0.1, -(mo.z + 1.2)))
	var r := Fielding.evaluate(_exit(dir, 1.0, 13.0), Fielding.layout(false))
	check(r.fielder >= 0 and r.field_dir.length() > 0.9, "fielder and ball direction are known")
	check(r.end_pos.distance_to(Vector3(r.field_pos.x, r.end_pos.y, r.field_pos.z)) < 0.01, "ball ends where the fielder takes it")

func test_batting_card_gets_weaker_down_the_order() -> void:
	check(MatchState.BLUE_SKILL.size() == MatchState.BLUE.size(), "every batter has a rating")
	var top := MatchState.skill_of(3)
	var tail := MatchState.skill_of(10)
	check(top.bat_speed_max() > tail.bat_speed_max() * 1.2, "the power hitter swings much harder than number eleven")
	check(top.sweet_scale() > tail.sweet_scale(), "and has a bigger sweet spot")

func test_fielding_restrictions_are_never_broken() -> void:
	# Whatever the batter has been doing, the field stays legal.
	var histories := [[], [[0.0, 80.0, 6], [5.0, 78.0, 6], [-8.0, 75.0, 4], [10.0, 70.0, 4], [-30.0, 66.0, 4], [40.0, 70.0, 6]],
		[[90.0, 66.0, 4], [85.0, 20.0, 1], [-90.0, 66.0, 4], [-120.0, 60.0, 4], [130.0, 62.0, 4], [60.0, 68.0, 4], [-60.0, 70.0, 6]]]
	for shots: Array in histories:
		for spinner in [false, true]:
			var pp := Fielding.layout(spinner, true, shots)
			var late := Fielding.layout(spinner, false, shots)
			check(pp.size() == 11 and late.size() == 11, "eleven in the field")
			check(Fielding.outside_ring(pp) == Fielding.MAX_OUT_POWERPLAY, "powerplay: %d outside the ring" % Fielding.outside_ring(pp))
			check(Fielding.outside_ring(late) == Fielding.MAX_OUT, "after the powerplay: %d outside the ring" % Fielding.outside_ring(late))
			for s in late:
				check(not Pitch.beyond_boundary(s.pos), "%s stands inside the rope" % s.name)

func test_field_follows_the_batter() -> void:
	# Someone who keeps hitting over cover gets a man out there, and loses one elsewhere.
	var plain := Fielding.layout(false, true)
	var shots := [[45.0, 70.0, 4], [50.0, 72.0, 6], [42.0, 68.0, 4]]
	var moved := Fielding.layout(false, true, shots)
	var covered := func(field: Array) -> bool:
		for s in field:
			if s.kind == Fielding.Kind.DEEP:
				var a := rad_to_deg(atan2(s.pos.x, -(s.pos.z + 1.0)))
				if absf(a - 46.0) < 14.0:
					return true
		return false
	check(not covered.call(plain), "no deep cover to begin with in the powerplay")
	check(covered.call(moved), "a man goes back on the cover boundary")
	check(Fielding.outside_ring(moved) == Fielding.MAX_OUT_POWERPLAY, "and still only two are out")

func test_every_plan_and_mood_keeps_the_field_legal() -> void:
	for plan in ["", "short", "wide", "straight"]:
		for mood in ["normal", "attack", "defend", "save_one"]:
			for spinner in [false, true]:
				for powerplay in [true, false]:
					var f := Fielding.layout(spinner, powerplay, [[30.0, 70.0, 4], [-70.0, 68.0, 6]], plan, mood)
					var cap := Fielding.MAX_OUT_POWERPLAY if powerplay else Fielding.MAX_OUT
					check(f.size() == 11, "eleven for %s/%s" % [plan, mood])
					check(Fielding.outside_ring(f) <= cap, "%s/%s: %d outside the ring" % [plan, mood, Fielding.outside_ring(f)])
					check(f[0].kind == Fielding.Kind.KEEPER and f[f.size() - 1].name == "bowler", "keeper first, bowler last")

func test_plan_moves_the_field() -> void:
	var leg := func(field: Array) -> int:
		var n := 0
		for s in field:
			if s.kind == Fielding.Kind.DEEP and s.pos.x < 0.0:
				n += 1
		return n
	var short := Fielding.layout(false, false, [], "short")
	var wide := Fielding.layout(false, false, [], "wide")
	check(leg.call(short) > leg.call(wide), "short-ball plan: %d deep on the leg side, wide plan: %d" % [leg.call(short), leg.call(wide)])

func test_captain_reads_the_game() -> void:
	var m := MatchState.create(9)
	check(Captain.mood(m) == "normal", "start of the chase: %s" % Captain.mood(m))
	m.record(0, "b Venn")
	check(Captain.mood(m) == "attack", "new batter in: %s" % Captain.mood(m))
	var attack := Captain.field(m)
	check(_spot(attack, "slip") != null and Fielding.outside_ring(attack) < Fielding.MAX_OUT_POWERPLAY + 1, "attacking field has a slip")
	# Last over, three to get: everyone up.
	var e := MatchState.create(9)
	e.balls = 114
	e.runs = e.target - 3
	for b in e.batters:
		b.balls = 10
	check(Captain.mood(e) == "save_one", "three off the last over: %s" % Captain.mood(e))
	check(Fielding.outside_ring(Captain.field(e)) == 1, "one man out, the rest saving the single")
	# Miles behind the rate: spread.
	var d := MatchState.create(9)
	d.balls = 60
	d.runs = d.target - 130
	for b in d.batters:
		b.balls = 10
	check(Captain.mood(d) == "defend", "needing 13 an over: %s" % Captain.mood(d))

func test_bowlers_bowl_to_the_plan() -> void:
	var machine := BowlingMachine.new(4)
	var short := 0
	var wide := 0
	for i in 200:
		if machine.next_for("pace", 8, "short").target.z < -9.0:
			short += 1
		if machine.next_for("pace", 8, "wide").target.x > 0.45:
			wide += 1
	check(short > 120, "short-ball plan: %d of 200 banged in" % short)
	check(wide > 120, "wide plan: %d of 200 outside off" % wide)

func test_scorecard_adds_up() -> void:
	var m := MatchState.create(12)
	m.record(4)
	m.record(1)
	m.record(0, "c cover b Venn")
	var sc := m.scorecard()
	var ours: Dictionary = sc.ours
	check(ours.batting.size() == 3, "openers and the new batter on the card (%d)" % ours.batting.size())
	check(ours.yet.size() == 8, "eight yet to bat (%d)" % ours.yet.size())
	check(str(ours.fow).begins_with("5-1"), "fall of wickets: %s" % ours.fow)
	var bowled := 0
	for b: Dictionary in ours.bowling:
		bowled += int(b.balls)
	check(bowled == 3, "three balls in the bowling figures")
	# Their innings: the batters' runs add up to their total, and so do our bowlers' runs.
	var theirs: Dictionary = sc.theirs
	var bat_runs := 0
	for b: Dictionary in theirs.batting:
		bat_runs += int(b.runs)
	var bowl_runs := 0
	var bowl_balls := 0
	for b: Dictionary in theirs.bowling:
		bowl_runs += int(b.runs)
		bowl_balls += int(b.balls)
	check(bat_runs == m.red_total and bowl_runs == m.red_total, "their card adds up: %d, %d, total %d" % [bat_runs, bowl_runs, m.red_total])
	var outs := 0
	for b: Dictionary in theirs.batting:
		if bool(b.out):
			outs += 1
	check(outs == m.red_wickets, "%d out on the card, %d wickets" % [outs, m.red_wickets])
