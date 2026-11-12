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
func next_for(style: String, over: int) -> Delivery:
	var d := Delivery.new()
	match style:
		"off":
			d.label = "Off spin"
			d.release = Vector3(0.5, 2.05, Pitch.BOWLER_CREASE_Z)
			d.speed = _rng.randf_range(21.0, 24.5)
			d.target = Vector3(_rng.randf_range(0.1, 0.55), 0.0, _rng.randf_range(-5.4, -2.6))
			d.spin = Vector3(40.0, 0.0, _rng.randf_range(150.0, 230.0))
			if _rng.randf() < 0.18:
				d.label = "Arm ball"
				d.spin = Vector3(40.0, 0.0, _rng.randf_range(-20.0, 20.0))
				d.speed += 2.0
			return d
		"leg":
			d.label = "Leg spin"
			d.release = Vector3(0.5, 2.05, Pitch.BOWLER_CREASE_Z)
			d.speed = _rng.randf_range(20.5, 23.5)
			d.target = Vector3(_rng.randf_range(-0.25, 0.25), 0.0, _rng.randf_range(-5.4, -2.6))
			d.spin = Vector3(40.0, 0.0, -_rng.randf_range(150.0, 230.0))
			if _rng.randf() < 0.2:
				d.label = "Googly"
				d.spin = Vector3(40.0, 0.0, _rng.randf_range(140.0, 200.0))
			return d
	d.label = "Pace"
	d.speed = _rng.randf_range(32.0, 39.0)
	d.target = Vector3(_rng.randf_range(-0.12, 0.42), 0.0, _rng.randf_range(-10.5, -3.4))
	d.spin = Vector3(-50.0, 0.0, _rng.randf_range(-25.0, 25.0))
	var swing_chance := 0.8 if style == "swing" else 0.35
	if _rng.randf() < swing_chance:
		d.swing = _rng.randf_range(0.35, 0.95) * (1.0 if _rng.randf() < 0.5 else -1.0)
		d.label = "Outswinger" if d.swing > 0.0 else "Inswinger"
	var roll := _rng.randf()
	var death := over >= 16
	if roll < (0.28 if death else 0.08):
		d.label = "Yorker"
		d.swing *= 0.4
		d.target = Vector3(_rng.randf_range(-0.05, 0.25), 0.0, _rng.randf_range(-1.6, -0.9))
	elif roll < (0.42 if death else 0.18):
		d.label = "Bouncer"
		d.swing = 0.0
		d.target = Vector3(_rng.randf_range(0.0, 0.35), 0.0, _rng.randf_range(-12.5, -11.0))
	elif roll < 0.52 and death:
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
