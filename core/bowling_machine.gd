class_name BowlingMachine
extends RefCounted
## Seeded source of varied deliveries for the nets.

var _rng := RandomNumberGenerator.new()

func _init(rng_seed: int = 1) -> void:
	_rng.seed = rng_seed

## Lets a saved match carry on with exactly the balls it would have bowled.
var state: int:
	get:
		return _rng.state
	set(v):
		_rng.state = v

## A delivery from a bowler of a given style: "pace", "swing", "off" or "leg".
## In the last four overs pace bowlers mix in yorkers and bouncers.
## `plan` is the captain's plan for the over: most balls are bowled to it. `prof` is the
## bowler (BowlerProfile.of); `cond` the match conditions ({pitch, night}).
func next_for(style: String, over: int, plan: String = "", prof: Dictionary = {}, cond: Dictionary = {}) -> Delivery:
	if prof.is_empty():
		prof = _default_profile(style)
	var d := _stock(prof, over, cond)
	var spinner := BowlerProfile.is_spin(str(prof.style))
	if plan != "" and _rng.randf() <= 0.7:
		match plan:
			"short":
				if not spinner:
					d.target = Vector3(_rng.randf_range(0.0, 0.3), 0.0, _rng.randf_range(-12.3, -9.2))
					d.swing *= 0.3
					d.label = "Bouncer" if d.target.z < -11.0 else "Short ball"
			"wide":
				d.target.x = _rng.randf_range(0.46, 0.72)
				if not spinner and d.target.z < -7.5:
					d.target.z = _rng.randf_range(-7.0, -3.5)
			"straight":
				d.target.x = _rng.randf_range(-0.08, 0.14)
				if spinner:
					d.target.z = _rng.randf_range(-4.2, -2.6)
				else:
					d.target.z = _rng.randf_range(-4.6, -1.0)
					d.swing *= 0.5
					if d.target.z > -1.7:
						d.label = "Yorker"
	# Club bowlers are slower than international ones: quicks lose more than spinners.
	var pace := float(cond.get("pace", 1.0))
	if pace < 1.0:
		d.speed *= pace if not spinner else lerpf(1.0, pace, 0.4)
	# Under pressure some go astray: a wide on either side, or an overstep. Spinners are
	# steadier. Nets (`cond` empty) are always on target.
	if cond.has("pitch"):
		var death := over >= 15
		var stray := (0.045 + (0.02 if death else 0.0)) * (0.55 if spinner else 1.0)
		var roll := _rng.randf()
		if roll < stray:
			if _rng.randf() < 0.6:
				d.target.x = _rng.randf_range(1.05, 1.35)
			else:
				d.target.x = _rng.randf_range(-0.85, -0.6)
		d.no_ball = _rng.randf() < (0.004 if spinner else 0.012)
	# A worn pitch: some keep low, some kick up.
	d.bounce_var = _rng.randfn(0.0, Conditions.wear_sd(str(cond.get("pitch", "good")), over))
	return d

func _default_profile(style: String) -> Dictionary:
	match style:
		"off":
			return BowlerProfile.of("L. Fernando")
		"leg":
			return BowlerProfile.of("R. Whitlock")
		"sla":
			return BowlerProfile.of("T. Haldane")
		"swing":
			var p: Dictionary = BowlerProfile.of("D. Hartigan").duplicate()
			p.swing_chance = 0.8
			return p
	return BowlerProfile.of("D. Hartigan")

func _stock(prof: Dictionary, over: int, cond: Dictionary) -> Delivery:
	var d := Delivery.new()
	var rel: Vector3 = prof.release
	d.release = Vector3(rel.x, rel.y, Pitch.BOWLER_CREASE_Z + rel.z)
	d.action = str(prof.action)
	d.left_arm = str(prof.arm) == "L"
	d.speed = _rng.randf_range(prof.pace[0], prof.pace[1])
	var roll := _rng.randf()
	match str(prof.style):
		"off":
			# Over-spin for dip, a little drift away, side-spin to turn it back in.
			d.label = "Off spin"
			d.target = Vector3(_rng.randf_range(0.1, 0.55), 0.0, _rng.randf_range(-5.4, -2.6))
			d.spin = Vector3(_rng.randf_range(40.0, 60.0), 45.0, _rng.randf_range(150.0, 230.0))
			if roll < 0.18:
				d.label = "Arm ball"
				d.spin = Vector3(30.0, 0.0, _rng.randf_range(-20.0, 20.0))
				d.speed += 2.0
			return d
		"sla":
			d.label = "Left-arm spin"
			d.target = Vector3(_rng.randf_range(0.0, 0.45), 0.0, _rng.randf_range(-5.4, -2.6))
			d.spin = Vector3(_rng.randf_range(40.0, 60.0), -40.0, -_rng.randf_range(140.0, 200.0))
			if roll < 0.2:
				d.label = "Arm ball"
				d.spin = Vector3(30.0, 0.0, _rng.randf_range(20.0, 60.0))
				d.speed += 2.0
			return d
		"leg":
			# More revs than a finger spinner: more drift, more dip, more turn.
			d.label = "Leg spin"
			d.target = Vector3(_rng.randf_range(-0.25, 0.25), 0.0, _rng.randf_range(-5.4, -2.6))
			d.spin = Vector3(_rng.randf_range(70.0, 100.0), -60.0, -_rng.randf_range(170.0, 260.0))
			if roll < 0.16:
				d.label = "Googly"
				d.spin = Vector3(_rng.randf_range(60.0, 90.0), 10.0, _rng.randf_range(140.0, 200.0))
			elif roll < 0.25:
				d.label = "Flipper"
				d.spin = Vector3(-70.0, 0.0, _rng.randf_range(-20.0, 20.0))
				d.speed += 2.5
				d.target.z = _rng.randf_range(-3.4, -2.2)
			elif roll < 0.34:
				d.label = "Top-spinner"
				d.spin = Vector3(_rng.randf_range(140.0, 170.0), 0.0, _rng.randf_range(-30.0, 30.0))
			return d
	# Pace.
	d.label = "Pace"
	d.target = Vector3(_rng.randf_range(-0.12, 0.42), 0.0, _rng.randf_range(-10.5, -3.4) - float(prof.get("short", 0.0)) * 6.0)
	d.spin = Vector3(-50.0, 0.0, _rng.randf_range(-25.0, 25.0))
	d.seam = _rng.randfn(0.0, 1.0) * 0.42 * float(prof.get("seam", 1.0))
	if _rng.randf() < float(prof.get("swing_chance", 0.35)):
		var inward := _rng.randf() < float(prof.get("inswing", 0.5))
		d.swing = _rng.randf_range(0.35, 0.95) * float(prof.get("swing", 1.0)) * (-1.0 if inward else 1.0)
		d.label = "Outswinger" if d.swing > 0.0 else "Inswinger"
	# An old ball on a dry pitch goes the other way, late.
	if bool(Conditions.info(str(cond.get("pitch", "good"))).reverse) and over >= 14 and _rng.randf() < 0.45:
		d.swing = _rng.randf_range(0.6, 1.05) * (1.0 if _rng.randf() < 0.5 else -1.0)
		d.label = "Reverse swing"
	var death := over >= 16
	var yorker := float(prof.get("yorker", 0.0))
	var r2 := _rng.randf()
	if r2 < (0.28 if death else 0.08) + yorker:
		d.label = "Yorker"
		d.swing *= 0.4
		d.target = Vector3(_rng.randf_range(-0.05, 0.25), 0.0, _rng.randf_range(-1.6, -0.9))
	elif r2 < (0.42 if death else 0.18) + yorker + float(prof.get("short", 0.0)):
		d.label = "Bouncer"
		d.swing = 0.0
		d.target = Vector3(_rng.randf_range(0.0, 0.35), 0.0, _rng.randf_range(-12.5, -11.0))
	elif r2 < (0.52 if death else 0.22) + yorker + float(prof.get("short", 0.0)) + float(prof.get("cutters", 0.0)):
		if float(prof.get("cutters", 0.0)) > 0.0:
			var off := _rng.randf() < 0.5
			d.label = "Off cutter" if off else "Leg cutter"
			d.speed *= 0.86
			d.seam = (-1.0 if off else 1.0) * _rng.randf_range(0.6, 1.0)
		elif death:
			d.label = "Slower ball"
			d.speed *= 0.72
	return d

func next() -> Delivery:
	var d := Delivery.new()
	var roll := _rng.randf()
	if roll < 0.62:
		d.label = "Pace"
		d.speed = _rng.randf_range(31.0, 38.5)
		d.target = Vector3(_rng.randf_range(-0.12, 0.42), 0.0, _rng.randf_range(-11.0, -3.2))
		d.spin = Vector3(-50.0, 0.0, _rng.randf_range(-25.0, 25.0))
		if _rng.randf() < 0.55:
			d.swing = _rng.randf_range(0.35, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0)
			d.label = "Outswinger" if d.swing > 0.0 else "Inswinger"
	elif roll < 0.82:
		d.label = "Off spin"
		d.release = Vector3(0.5, 2.05, Pitch.BOWLER_CREASE_Z)
		d.speed = _rng.randf_range(21.0, 24.5)
		d.target = Vector3(_rng.randf_range(0.15, 0.55), 0.0, _rng.randf_range(-5.2, -2.8))
		d.spin = Vector3(40.0, 0.0, _rng.randf_range(150.0, 230.0))
	else:
		d.label = "Leg spin"
		d.release = Vector3(0.5, 2.05, Pitch.BOWLER_CREASE_Z)
		d.speed = _rng.randf_range(20.5, 23.5)
		d.target = Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-5.2, -2.8))
		d.spin = Vector3(40.0, 0.0, -_rng.randf_range(150.0, 230.0))
	return d
