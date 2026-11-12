extends TestCase

func _ball(pos: Vector3, vel: Vector3) -> BallPhysics.State:
	var s := BallPhysics.State.new()
	s.pos = pos
	s.vel = vel
	return s

func test_drop_matches_free_fall() -> void:
	var s := _ball(Vector3(30, 2.0, 30), Vector3.ZERO)
	while s.bounces == 0:
		BallPhysics.step(s)
	near(s.time, sqrt(2.0 * (2.0 - BallPhysics.RADIUS) / 9.81), 0.01, "time to fall 2 m")

func test_drag_shortens_range() -> void:
	var v := 30.0
	var a := deg_to_rad(30.0)
	var s := _ball(Vector3(0, BallPhysics.RADIUS, 0), Vector3(0, sin(a), cos(a)) * v)
	var b := BallPhysics.state_at_first_bounce(s, 10.0)
	var vacuum := v * v * sin(2.0 * a) / 9.81
	check(b.pos.z < vacuum * 0.95, "drag should cost more than 5%% of range (%.1f vs %.1f)" % [b.pos.z, vacuum])
	check(b.pos.z > vacuum * 0.65, "drag should not cost more than 35%% of range")

func test_swing_direction_and_symmetry() -> void:
	var out := _ball(Vector3(0, 2.1, -18.9), Vector3(0, -1.5, 35))
	out.swing = 1.0
	var inn := out.copy()
	inn.swing = -1.0
	var a := BallPhysics.state_at_first_bounce(out)
	var b := BallPhysics.state_at_first_bounce(inn)
	check(a.pos.x > 0.15, "positive swing moves toward +X (%.3f)" % a.pos.x)
	near(a.pos.x, -b.pos.x, 0.001, "swing is symmetric")

func test_bounce_restitution_on_pitch() -> void:
	var s := _ball(Vector3(0, 1.0, -6), Vector3(0, 0, 0))
	while s.bounces == 0:
		BallPhysics.step(s)
	var vn := sqrt(2.0 * 9.81 * (1.0 - BallPhysics.RADIUS))
	near(s.vel.y, vn * BallPhysics.PITCH_RESTITUTION, 0.15, "rebound speed")

func test_off_spin_turns_to_leg_and_leg_spin_to_off() -> void:
	var base := _ball(Vector3(0, 2.0, -18.9), Vector3(0, 1.0, 22))
	var off := base.copy()
	off.spin = Vector3(0, 0, 200)
	var leg := base.copy()
	leg.spin = Vector3(0, 0, -200)
	var none := BallPhysics.state_at_first_bounce(base)
	var a := BallPhysics.state_at_first_bounce(off)
	var b := BallPhysics.state_at_first_bounce(leg)
	near(none.vel.x, 0.0, 0.0001, "no spin, no turn")
	check(a.vel.x < -1.0, "off spin turns toward leg (-X): %.2f" % a.vel.x)
	check(b.vel.x > 1.0, "leg spin turns toward off (+X): %.2f" % b.vel.x)

func test_pace_ball_loses_some_speed_off_the_pitch() -> void:
	var s := _ball(Vector3(0, 2.1, -18.9), Vector3(0, -2.0, 36))
	var before := BallPhysics.state_at_first_bounce(s)
	check(before.vel.z < 35.5 and before.vel.z > 29.0, "keeps most pace after pitching: %.1f" % before.vel.z)

func test_rolling_ball_stops() -> void:
	var s := _ball(Vector3(20, BallPhysics.RADIUS, 20), Vector3(12, -0.1, 0))
	for _i in 240 * 30:
		BallPhysics.step(s)
	check(s.at_rest, "ball should come to rest")
	check(s.pos.x > 35.0 and s.pos.x < 60.0, "rolls a sensible distance: %.1f" % s.pos.x)

func test_determinism() -> void:
	var d := BowlingMachine.new(42).next()
	var a := d.solve()
	var b := d.solve()
	for _i in 400:
		BallPhysics.step(a)
		BallPhysics.step(b)
	check(a.pos == b.pos and a.vel == b.vel, "identical inputs give identical state")

func test_stumps_hit_detection() -> void:
	var r := BallPhysics.RADIUS
	check(Pitch.hits_stumps(Vector3(0, 0.4, -0.2), Vector3(0.01, 0.38, 0.2), r), "straight ball hits")
	check(not Pitch.hits_stumps(Vector3(0.3, 0.4, -0.2), Vector3(0.3, 0.38, 0.2), r), "wide ball misses")
	check(not Pitch.hits_stumps(Vector3(0, 0.9, -0.2), Vector3(0, 0.9, 0.2), r), "ball over the top misses")
