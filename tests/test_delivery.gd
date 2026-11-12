extends TestCase

func test_solver_hits_target() -> void:
	for speed in [21.0, 30.0, 38.0]:
		for z in [-8.5, -5.0, -2.8]:
			for x in [-0.2, 0.4]:
				for swing in [-0.8, 0.0, 0.8]:
					var d := Delivery.new()
					d.speed = speed
					d.target = Vector3(x, 0, z)
					d.swing = swing
					var b := BallPhysics.state_at_first_bounce(d.solve())
					check(b != null, "ball should pitch")
					if b != null:
						near(b.pos.z, z, 0.06, "length at %.0f m/s swing %.1f" % [speed, swing])
						near(b.pos.x, x, 0.06, "line at %.0f m/s swing %.1f" % [speed, swing])

func test_machine_is_seeded() -> void:
	var a := BowlingMachine.new(7)
	var b := BowlingMachine.new(7)
	for _i in 20:
		var da := a.next()
		var db := b.next()
		check(da.speed == db.speed and da.target == db.target, "same seed, same ball")

func test_every_machine_ball_reaches_the_batter() -> void:
	var m := BowlingMachine.new(3)
	for _i in 200:
		var d := m.next()
		var w := ShotResolver.hit_window(d.solve())
		check(not w.is_empty(), "%s must reach the hitting zone" % d.label)
