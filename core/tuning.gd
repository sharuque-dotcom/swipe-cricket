class_name Tuning
extends RefCounted
## Feel constants. Change these, not the formulas, when tuning.

# Batting: the ball can be met anywhere between these two planes in front of the stumps.
const HIT_ZONE_FRONT_Z := -2.0
const HIT_ZONE_BACK_Z := -0.25
# Time from releasing the swipe to the bat reaching the ball.
const SWING_TIME := 0.12
# How long the bat stays in the hitting zone.
const BAT_DWELL := 0.12
# |n| thresholds on normalised timing error (1.0 = last possible contact).
const PERFECT_N := 0.15
const CLEAN_N := 0.75

# Where the bat can physically reach, relative to middle stump.
const REACH_LEG_X := -0.80
const REACH_OFF_X := 1.20
const REACH_TOP_Y := 2.0

const BAT_SPEED_MIN := 9.0
const BAT_SPEED_MAX := 27.0
const BALL_SPEED_CARRY := 0.22
const BAT_SPEED_CARRY := 1.18
const MISTIME_ANGLE := deg_to_rad(28.0)
const LOFT_MIN := deg_to_rad(1.5)
const LOFT_MAX := deg_to_rad(36.0)

# Swipe to shot mapping, in fractions of screen height.
const SWIPE_MIN_LEN := 0.04
const SWIPE_POWER_SPEED_MIN := 0.6    # screen heights per second
const SWIPE_POWER_SPEED_MAX := 3.2
const SWIPE_LOFT_LEN_MIN := 0.17
const SWIPE_LOFT_LEN_MAX := 0.40
