extends TestCase
## The pitch, the conditions and what the bowler puts on the ball.

func _spin_ball(spin: Vector3, pitch: String = "good") -> BallPhysics.State:
	Conditions.apply(pitch, false, 0)
	var d := Delivery.new()
	d.release = Vector3(0.5, 2.05, Pitch.BOWLER_CREASE_Z)
	d.speed = 22.0
	d.target = Vector3(0.3, 0.0, -4.0)
	d.spin = spin
	return d.solve()

## Sideways movement between pitching and reaching the batter.
func _turn(launch: BallPhysics.State) -> float:
	var at := BallPhysics.state_at_first_bounce(launch)
	var bat := BallPhysics.state_at_z(launch, -0.5)
	return bat.pos.x - at.pos.x

func test_dusty_pitch_turns_more_than_a_green_one() -> void:
	var spin := Vector3(50.0, 0.0, 200.0)
	var dusty := absf(_turn(_spin_ball(spin, "dusty")))
	var green := absf(_turn(_spin_ball(spin, "green")))
	check(dusty > green * 1.3, "turn on dusty %.3f m v green %.3f m" % [dusty, green])
	Conditions.reset()

func test_drift_bends_it_in_the_air() -> void:
	# Same pitching spot; a leg-spinner's drift means it comes from further out.
	var plain := _spin_ball(Vector3(0, 0, 0))
	var drift := _spin_ball(Vector3(0, -60.0, 0))
	var mid_plain := ShotResolver.state_at_time(plain, 0.35).pos.x
	var mid_drift := ShotResolver.state_at_time(drift, 0.35).pos.x
	check(absf(mid_drift - mid_plain) > 0.03, "drift moves the ball in flight (%.3f m)" % (mid_drift - mid_plain))
	Conditions.reset()

func test_overspin_dips_and_kicks() -> void:
	# The solver aims both at the same spot; the top-spinner has to be tossed higher to get there.
	var flat := _spin_ball(Vector3(0, 0, 0))
	var top := _spin_ball(Vector3(150.0, 0, 0))
	check(top.vel.y > flat.vel.y, "the top-spinner leaves the hand higher (%.2f v %.2f)" % [top.vel.y, flat.vel.y])
	Conditions.reset()

func test_seam_moves_it_off_the_pitch() -> void:
	Conditions.apply("green", false, 0)
	var d := Delivery.new()
	d.speed = 36.0
	d.target = Vector3(0.1, 0.0, -6.0)
	var plain := _turn(d.solve())
	d.seam = 0.5
	var seamed := _turn(d.solve())
	check(seamed - plain > 0.04, "seam on a green pitch moves it %.3f m" % (seamed - plain))
	Conditions.reset()

func test_worn_pitch_can_keep_low() -> void:
	var d := Delivery.new()
	d.speed = 34.0
	d.target = Vector3(0.1, 0.0, -7.0)
	var normal := BallPhysics.state_at_z(d.solve(), -0.5).pos.y
	d.bounce_var = -0.25
	var low := BallPhysics.state_at_z(d.solve(), -0.5).pos.y
	check(normal - low > 0.12, "a shooter stays %.2f m lower" % (normal - low))
	check(Conditions.wear_sd("dusty", 19) > Conditions.wear_sd("green", 19), "dusty pitches wear more")
	check(Conditions.wear_sd("dusty", 0) == 0.0, "no wear on the first ball")

func test_dew_takes_the_grip_away() -> void:
	Conditions.apply("dusty", true, 2)
	var early := BallPhysics.pitch_grip
	Conditions.apply("dusty", true, 18)
	check(BallPhysics.pitch_grip < early * 0.8, "dew: grip %.2f down from %.2f" % [BallPhysics.pitch_grip, early])
	Conditions.apply("dusty", false, 18)
	check(is_equal_approx(BallPhysics.pitch_grip, early), "no dew in the day")
	Conditions.reset()

func test_every_bowler_bowls_a_real_ball() -> void:
	var machine := BowlingMachine.new(3)
	for name in BowlerProfile.ALL:
		var p := BowlerProfile.of(name)
		for over in [2, 17]:
			for pitch in Conditions.ORDER:
				var d := machine.next_for(str(p.style), over, "", p, {"pitch": pitch, "night": false})
				var w := ShotResolver.hit_window(d.solve())
				check(not w.is_empty(), "%s on %s: the ball reaches the batter" % [name, pitch])
				check(d.left_arm == (str(p.arm) == "L"), "%s bowls with the right arm" % name)
	Conditions.reset()

func test_attack_is_three_quicks_and_two_spinners() -> void:
	for sd in 20:
		var a := BowlerProfile.attack_for(sd)
		var spin := 0
		for n in a:
			if BowlerProfile.is_spin(str(BowlerProfile.of(n).style)):
				spin += 1
		check(a.size() == 5 and spin == 2, "attack %s" % str(a))
