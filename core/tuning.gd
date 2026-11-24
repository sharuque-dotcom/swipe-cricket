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
const PERFECT_N := 0.28
const CLEAN_N := 0.80
# Swinging harder, and going aerial, both shrink the sweet part of the window.
const POWER_CONTROL_COST := 0.30
const LOFT_CONTROL_COST := 0.28
# How quickly a shot loses pace as timing leaves the sweet zone (smaller = harsher).
const MISTIME_FALLOFF := 0.65
# A mistimed lofted shot goes up rather than out.
const MISTIME_SKY := deg_to_rad(18.0)

# Shot choice. Defend: soft hands, a much bigger sweet spot, little power.
const DEFEND_POWER := 0.18
const DEFEND_SWEET := 1.8
const DEFEND_CLEAN := 1.2
# Lofted: always in the air; how far the swipe goes still decides how high.
const LOFT_FLOOR := 0.6

# Batter ability: what the weakest tail-ender keeps of the best batter's numbers.
const SKILL_POWER_FLOOR := 0.74
const SKILL_SWEET_FLOOR := 0.50
const SKILL_CLEAN_FLOOR := 0.70

# Where the bat can physically reach, relative to middle stump.
const REACH_LEG_X := -0.80
const REACH_OFF_X := 1.20
const REACH_TOP_Y := 2.0

const BAT_SPEED_MIN := 9.0
const BAT_SPEED_MAX := 25.5
const BALL_SPEED_CARRY := 0.22
const BAT_SPEED_CARRY := 1.18
const MISTIME_ANGLE := deg_to_rad(28.0)
const LOFT_MIN := deg_to_rad(1.5)
const LOFT_MAX := deg_to_rad(36.0)

# Stepping out: how far down the pitch the batter gets, and how long it takes.
const STEP_OUT_SPIN := 1.3
const STEP_OUT_PACE := 0.7
const CHARGE_TIME := 0.5
# Below this ball speed (m/s) it is spin: the keeper stands closer and can stump you.
const SPIN_BALL := 27.0
# Moving across the crease before the ball: how far, and how long it takes.
const SHUFFLE_OFF := 0.45
const SHUFFLE_LEG := 0.40
const SHUFFLE_TIME := 0.3
# Wide lines at the batter's stumps, across from middle stump (T20: the off-side guideline,
# and anything passing down the leg side).
const WIDE_OFF_X := 0.89
const WIDE_LEG_X := -0.42

# Swipe to shot mapping, in fractions of screen height.
const SWIPE_MIN_LEN := 0.04
const SWIPE_POWER_SPEED_MIN := 0.6    # screen heights per second
const SWIPE_POWER_SPEED_MAX := 3.2
const SWIPE_LOFT_LEN_MIN := 0.17
const SWIPE_LOFT_LEN_MAX := 0.40
