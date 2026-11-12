extends TestCase

func _exit(dir_deg: float, elev_deg: float, speed: float) -> BallPhysics.State:
	var s := BallPhysics.State.new()
	s.pos = Vector3(0.1, 0.8, -1.2)
	var a := deg_to_rad(dir_deg)
	var e := deg_to_rad(elev_deg)
	s.vel = (Vector3(sin(a), 0.0, -cos(a)) * cos(e) + Vector3.UP * sin(e)) * speed
	return s

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
	var r := Fielding.evaluate(_exit(30.0, 2.0, 34.0), Fielding.layout(false))
	check(r.boundary and not r.six, "hard ground drive through the covers gap (got %d runs, %s)" % [r.runs, r.fielder_name])

func test_push_to_fielder_is_no_run() -> void:
	# Soft push straight at mid-off.
	var mo := Fielding.layout(false)[4].pos
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
