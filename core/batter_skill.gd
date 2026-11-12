class_name BatterSkill
extends RefCounted
## What a batter is capable of. Power is how hard they can swing; timing is how forgiving
## their bat is. Both are 0..1 and shown to the player as five pips each.

var role := "Batter"
var power := 1.0
var timing := 1.0

func _init(r: String = "Batter", p: float = 1.0, t: float = 1.0) -> void:
	role = r
	power = clampf(p, 0.0, 1.0)
	timing = clampf(t, 0.0, 1.0)

## Fastest this batter can swing the bat, m/s.
func bat_speed_max() -> float:
	return Tuning.BAT_SPEED_MAX * lerpf(Tuning.SKILL_POWER_FLOOR, 1.0, power)

## Scales the sweet (green) part of the timing window.
func sweet_scale() -> float:
	return lerpf(Tuning.SKILL_SWEET_FLOOR, 1.0, timing)

## Scales the whole clean-contact window; outside it the ball takes the edge.
func clean_scale() -> float:
	return lerpf(Tuning.SKILL_CLEAN_FLOOR, 1.0, timing)

static func pips(v: float) -> int:
	return clampi(int(round(v * 5.0)), 1, 5)
