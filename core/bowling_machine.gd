class_name BowlingMachine
extends RefCounted
## Seeded source of varied deliveries for the nets.

var _rng := RandomNumberGenerator.new()

func _init(rng_seed: int = 1) -> void:
	_rng.seed = rng_seed

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
