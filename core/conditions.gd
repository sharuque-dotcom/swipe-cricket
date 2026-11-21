class_name Conditions
extends RefCounted
## The pitch and the evening. A match is played on one pitch, in the day or under lights,
## and that changes how the ball behaves: how much it bounces, grips and turns, how much it
## seams off the surface and swings in the air, how fast the outfield is, and how the pitch
## wears as the innings goes on. At night, dew comes in during the chase: the ball gets wet,
## spinners lose grip and the ball skids on.

const PITCHES := {
	"green": {"name": "GREEN SEAMER", "blurb": "Grass on it: seam and swing for the quicks",
		"restitution": 0.60, "friction": 0.24, "grip": 0.70, "seam": 1.7, "swing": 1.3, "outfield": 2.6,
		"wear": 0.25, "reverse": false, "tint": Color(0.80, 0.95, 0.70), "par": 0.9},
	"flat": {"name": "FLAT ROAD", "blurb": "Hard and true: the ball comes on, runs everywhere",
		"restitution": 0.57, "friction": 0.20, "grip": 0.68, "seam": 0.5, "swing": 0.75, "outfield": 1.85,
		"wear": 0.35, "reverse": true, "tint": Color(1.05, 1.02, 0.95), "par": 1.14},
	"dusty": {"name": "DUSTY TURNER", "blurb": "Dry and cracked: big turn, keeps low late on",
		"restitution": 0.50, "friction": 0.30, "grip": 1.18, "seam": 0.6, "swing": 0.8, "outfield": 2.2,
		"wear": 1.0, "reverse": true, "tint": Color(1.12, 0.98, 0.82), "par": 0.94},
	"good": {"name": "GOOD PITCH", "blurb": "Something in it for everyone",
		"restitution": 0.56, "friction": 0.26, "grip": 0.85, "seam": 1.0, "swing": 1.0, "outfield": 2.3,
		"wear": 0.5, "reverse": false, "tint": Color(1, 1, 1), "par": 1.0},
}
const ORDER := ["good", "green", "flat", "dusty"]
# "par" is how many runs a side gets on it compared with a good pitch.
## Dew sets in from this over at night, fully by DEW_FULL.
const DEW_FROM := 9
const DEW_FULL := 15

## A pitch and a time of day for a match, from its seed.
static func pick(rng_seed: int) -> Dictionary:
	var h := absi(hash(rng_seed * 92821 + 7))
	return {"pitch": ORDER[h % ORDER.size()], "night": (h / 7) % 2 == 1}

static func info(pitch: String) -> Dictionary:
	return PITCHES.get(pitch, PITCHES["good"])

## How wet the ball is at night: 0 in the day or early on, 1 once the dew is down.
static func dew(night: bool, over: int) -> float:
	if not night:
		return 0.0
	return clampf(float(over - DEW_FROM) / float(DEW_FULL - DEW_FROM), 0.0, 1.0)

## How much the bounce can vary ball to ball (a fraction of the normal bounce): grows as
## the pitch wears, most on a dry one.
static func wear_sd(pitch: String, over: int) -> float:
	return float(info(pitch).wear) * 0.16 * clampf(float(over) / 19.0, 0.0, 1.0)

## Sets the ball physics for this pitch, this over.
static func apply(pitch: String, night: bool, over: int) -> void:
	var p := info(pitch)
	var d := dew(night, over)
	BallPhysics.pitch_restitution = float(p.restitution)
	BallPhysics.pitch_friction = float(p.friction) * (1.0 - 0.2 * d)
	BallPhysics.pitch_grip = float(p.grip) * (1.0 - 0.3 * d)
	BallPhysics.seam_scale = float(p.seam) * (1.0 - 0.3 * d)
	BallPhysics.swing_scale = float(p.swing) * (1.0 - 0.2 * d)
	BallPhysics.roll_decel = float(p.outfield) * (1.0 - 0.12 * d)

## Back to a plain pitch (the nets, and tests).
static func reset() -> void:
	apply("good", false, 0)

static func describe(pitch: String, night: bool) -> String:
	return "%s  ·  %s" % [info(pitch).name, "NIGHT, DEW LATER" if night else "DAY"]
