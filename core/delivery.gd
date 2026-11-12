class_name Delivery
extends RefCounted
## A bowler's intent, and the solver that turns it into a launch velocity.

var release := Vector3(0.45, 2.15, Pitch.BOWLER_CREASE_Z)
var speed := 34.0
var target := Vector3(0.1, 0.0, -6.0)   # where the ball should pitch
var swing := 0.0
var spin := Vector3.ZERO
var label := "Pace"

func speed_kmh() -> float:
	return speed * 3.6

func _launch(pitch_angle: float, aim_x: float) -> BallPhysics.State:
	var s := BallPhysics.State.new()
	s.pos = release
	var flat := Vector3(aim_x - release.x, 0.0, target.z - release.z).normalized()
	s.vel = (flat * cos(pitch_angle) + Vector3.UP * sin(pitch_angle)) * speed
	s.spin = spin
	s.swing = swing
	return s

## Finds the launch that pitches the ball on `target`, accounting for drag and swing.
func solve() -> BallPhysics.State:
	var aim_x := target.x
	var angle := 0.0
	for _pass in 4:
		var lo := -0.45
		var hi := 0.30
		for _i in 22:
			angle = (lo + hi) * 0.5
			var b := BallPhysics.state_at_first_bounce(_launch(angle, aim_x))
			if b == null or b.pos.z > target.z:
				hi = angle
			else:
				lo = angle
		var landed := BallPhysics.state_at_first_bounce(_launch(angle, aim_x))
		if landed == null:
			break
		aim_x += target.x - landed.pos.x
	return _launch(angle, aim_x)
