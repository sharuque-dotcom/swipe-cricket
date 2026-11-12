class_name Pitch
extends RefCounted
## Field geometry. Batter's stumps are at the origin; the bowler runs in from -Z,
## so the ball travels in +Z. +X is the off side for a right-handed batter.

const LENGTH := 20.12
const HALF_WIDTH := 1.525
const CREASE := 1.22
const BOWLER_STUMPS_Z := -LENGTH
const BOWLER_CREASE_Z := -LENGTH + CREASE
const BATTER_CREASE_Z := -CREASE

const STUMP_HALF_WIDTH := 0.1143
const STUMP_HEIGHT := 0.711

const FIELD_CENTRE := Vector3(0.0, 0.0, -LENGTH * 0.5)
const BOUNDARY_RADIUS := 65.0

static func on_pitch(p: Vector3) -> bool:
	return absf(p.x) <= HALF_WIDTH and p.z >= BOWLER_STUMPS_Z - 1.22 and p.z <= 1.22

static func distance_from_centre(p: Vector3) -> float:
	return Vector2(p.x - FIELD_CENTRE.x, p.z - FIELD_CENTRE.z).length()

static func beyond_boundary(p: Vector3) -> bool:
	return distance_from_centre(p) >= BOUNDARY_RADIUS

## True when the ball's path from `a` to `b` passes through the batter's stumps.
static func hits_stumps(a: Vector3, b: Vector3, ball_radius: float) -> bool:
	if a.z > 0.0 or b.z < 0.0 or is_equal_approx(a.z, b.z):
		return false
	var t := (0.0 - a.z) / (b.z - a.z)
	var p := a.lerp(b, t)
	return absf(p.x) <= STUMP_HALF_WIDTH + ball_radius and p.y <= STUMP_HEIGHT + ball_radius
