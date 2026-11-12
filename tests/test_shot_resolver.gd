extends TestCase

func _ball() -> BallPhysics.State:
	var d := Delivery.new()
	d.speed = 34.0
	d.target = Vector3(0.15, 0, -6.5)
	return d.solve()

func _swing(ball: BallPhysics.State, n: float, deg: float = 0.0, power: float = 1.0, loft: float = 0.0) -> ShotResolver.Result:
	var w := ShotResolver.hit_window(ball)
	var sw := ShotResolver.Swing.new()
	sw.angle = deg_to_rad(deg)
	sw.power = power
	sw.loft = loft
	sw.contact_time = w.t_mid + n * w.half
	return ShotResolver.resolve(ball, sw)

func test_window_is_humanly_hittable() -> void:
	var w := ShotResolver.hit_window(_ball())
	check(w.half > 0.07 and w.half < 0.13, "half window for a 122 km/h ball: %.0f ms" % (w.half * 1000.0))

func test_perfect_lofted_drive_is_six() -> void:
	var r := _swing(_ball(), 0.0, 0.0, 1.0, 1.0)
	check(r.outcome == ShotResolver.Outcome.HIT, "should connect")
	var s := NetsScoring.evaluate(r.exit)
	check(s.six, "full power, perfect timing, lofted: carry %.0f m" % s.carry)

func test_perfect_ground_drive_is_four() -> void:
	var r := _swing(_ball(), 0.0, 20.0, 1.0, 0.0)
	var s := NetsScoring.evaluate(r.exit)
	check(s.boundary and not s.six, "ground drive reaches the rope: %.0f m" % s.distance)

func test_soft_push_stays_in() -> void:
	var r := _swing(_ball(), 0.0, 0.0, 0.0, 0.0)
	var s := NetsScoring.evaluate(r.exit)
	check(not s.boundary, "a push should not reach the boundary (%.0f m)" % s.distance)

func test_timing_outcomes() -> void:
	var b := _ball()
	check(_swing(b, -1.2).outcome == ShotResolver.Outcome.MISS, "far too early misses")
	check(_swing(b, 1.2).outcome == ShotResolver.Outcome.MISS, "far too late misses")
	check(_swing(b, 0.9).outcome == ShotResolver.Outcome.EDGE, "very late is an edge")
	check(_swing(b, -0.9).outcome == ShotResolver.Outcome.EDGE, "very early is an edge")
	check(_swing(b, 0.5).outcome == ShotResolver.Outcome.HIT, "slightly late still connects")

func test_quality_falls_with_mistiming() -> void:
	var b := _ball()
	var last := 2.0
	for n in [0.0, 0.2, 0.4, 0.6, 0.74]:
		var q := _swing(b, n).quality
		check(q <= last, "quality must not rise as timing worsens (n=%.2f q=%.2f)" % [n, q])
		last = q
	near(_swing(b, 0.3).quality, _swing(b, -0.3).quality, 0.0001, "early and late are equally costly")

func test_late_goes_off_side_early_goes_leg_side() -> void:
	var b := _ball()
	var late := _swing(b, 0.6)
	var early := _swing(b, -0.6)
	check(late.exit.vel.x > 1.0, "late squirts to off: %.1f" % late.exit.vel.x)
	check(early.exit.vel.x < -1.0, "early drags to leg: %.1f" % early.exit.vel.x)
	check(early.exit.vel.y > late.exit.vel.y, "early goes up more than late")

func test_contact_is_never_behind_the_stumps() -> void:
	var b := _ball()
	for n in [-0.95, -0.5, 0.0, 0.5, 0.95]:
		var r := _swing(b, n)
		check(r.contact_pos.z <= Tuning.HIT_ZONE_BACK_Z + 0.001 and r.contact_pos.z >= Tuning.HIT_ZONE_FRONT_Z - 0.001,
			"contact z in zone at n=%.2f: %.2f" % [n, r.contact_pos.z])

func test_wrong_shot_for_height_costs_quality() -> void:
	var d := Delivery.new()
	d.speed = 38.0
	d.target = Vector3(0.0, 0, -11.5)   # short ball, arrives chest high
	var b := d.solve()
	var drive := _swing(b, 0.0, 0.0)
	var pull := _swing(b, 0.0, -90.0)
	check(pull.quality > drive.quality, "pulling a short ball beats driving it (%.2f vs %.2f)" % [pull.quality, drive.quality])

func test_same_input_same_shot() -> void:
	var a := _swing(_ball(), 0.33, 40.0, 0.7, 0.4)
	var b := _swing(_ball(), 0.33, 40.0, 0.7, 0.4)
	check(a.exit.vel == b.exit.vel and a.exit.pos == b.exit.pos, "no randomness in shot resolution")
