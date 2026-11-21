class_name BatterSkill
extends RefCounted
## What a batter is capable of. Power is how hard they can swing; timing is how forgiving
## their bat is. Both are 0..1 and shown to the player as five pips each.

var role := "Batter"
var power := 1.0
var timing := 1.0
## How well the ball goes where it's aimed when not quite middled. 0.6 is the norm.
var placement := 0.6
## How far and how quickly they get down the pitch, and how far they reach. 0.6 is the norm.
var footwork := 0.6

func _init(r: String = "Batter", p: float = 1.0, t: float = 1.0, pl: float = 0.6, fw: float = 0.6) -> void:
	role = r
	power = clampf(p, 0.0, 1.0)
	timing = clampf(t, 0.0, 1.0)
	placement = clampf(pl, 0.0, 1.0)
	footwork = clampf(fw, 0.0, 1.0)

## How far off the aim a mistimed shot goes, as a share of the norm.
func scatter() -> float:
	return lerpf(1.6, 0.6, (placement - 0.0) / 1.0) / lerpf(1.6, 0.6, 0.6)

## How far they get down the pitch, and how far they can reach, as a share of the norm.
func reach_scale() -> float:
	return lerpf(0.75, 1.2, footwork) / lerpf(0.75, 1.2, 0.6)

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
