class_name BowlerProfile
extends RefCounted
## Who bowls how. Each bowler has an action (how they run in and let it go), an arm, a
## release point, a pace, and a stock of deliveries. The release point and the spin feed
## straight into the ball physics, so the action is not just a look: a slinger lets go late
## and low, a left-armer angles it across, a tall bowler gets it to climb, a wrist spinner
## gives it more revs, drift and dip.
##
## Styles (what the captain and the HUD care about): pace, swing, off, leg, sla.
## Actions (what the animation does): express, sling, tall, skiddy, finger, wrist.
## All names are invented.

const ALL := {
	"M. Venn": {"action": "express", "arm": "L", "style": "swing", "label": "LEFT-ARM FAST",
		"pace": [36.5, 40.5], "release": Vector3(-0.42, 2.20, 0.0), "swing": 1.15, "swing_chance": 0.75,
		"inswing": 0.7, "seam": 0.8, "yorker": 0.08,
		"trait": "Angles it across you, then the late inswinging yorker"},
	"D. Hartigan": {"action": "sling", "arm": "R", "style": "pace", "label": "RIGHT-ARM FAST  ·  SLINGER",
		"pace": [35.5, 39.5], "release": Vector3(0.66, 1.98, 0.35), "swing": 0.9, "swing_chance": 0.45,
		"inswing": 0.5, "seam": 1.0, "yorker": 0.12,
		"trait": "Short run, late release from a wide, low arm: you pick it up late"},
	"C. Okafor": {"action": "tall", "arm": "R", "style": "pace", "label": "RIGHT-ARM FAST-MEDIUM  ·  TALL",
		"pace": [33.5, 37.5], "release": Vector3(0.40, 2.42, 0.0), "swing": 0.6, "swing_chance": 0.3,
		"inswing": 0.5, "seam": 1.35, "short": 0.15,
		"trait": "Steep bounce from a high arm; hits the seam hard"},
	"J. Brandt": {"action": "skiddy", "arm": "R", "style": "pace", "label": "RIGHT-ARM MEDIUM  ·  CUTTERS",
		"pace": [30.5, 34.5], "release": Vector3(0.58, 1.86, 0.0), "swing": 0.5, "swing_chance": 0.3,
		"inswing": 0.5, "seam": 1.25, "cutters": 0.3,
		"trait": "Skids on low, rolls the fingers over off and leg cutters"},
	"L. Fernando": {"action": "finger", "arm": "R", "style": "off", "label": "RIGHT-ARM OFF SPIN",
		"pace": [22.0, 25.5], "release": Vector3(0.50, 2.05, 0.0),
		"trait": "Darts it in flat: drifts away, turns back in; the arm ball goes on"},
	"R. Whitlock": {"action": "wrist", "arm": "R", "style": "leg", "label": "RIGHT-ARM LEG SPIN  ·  WRIST",
		"pace": [19.5, 22.5], "release": Vector3(0.42, 1.98, 0.0),
		"trait": "Loops it: drift in, dip, big turn away. Googly, flipper, top-spinner"},
	"T. Haldane": {"action": "finger", "arm": "L", "style": "sla", "label": "LEFT-ARM ORTHODOX SPIN",
		"pace": [21.0, 24.0], "release": Vector3(-0.50, 2.02, 0.0),
		"trait": "Turns it away from you; the arm ball skids in"},
}
const PACERS := ["M. Venn", "D. Hartigan", "C. Okafor", "J. Brandt"]
const SPINNERS := ["L. Fernando", "R. Whitlock", "T. Haldane"]
const DEFAULT_ATTACK := ["M. Venn", "D. Hartigan", "C. Okafor", "L. Fernando", "R. Whitlock"]

## How each action moves: run-up length and speed, how big the leap is, how far the bowling
## arm leans out from vertical (0 high, 40 round-arm), how side-on they get, body size.
const ACTIONS := {
	"express": {"run_time": 2.5, "speed": 5.6, "jump": 1.6, "arm_out": 0.0, "side_on": 1.0, "front": "high", "scale": 1.0},
	"sling": {"run_time": 1.45, "speed": 3.8, "jump": 0.8, "arm_out": 30.0, "side_on": 0.8, "front": "straight", "scale": 0.98},
	"tall": {"run_time": 2.2, "speed": 4.8, "jump": 1.1, "arm_out": -4.0, "side_on": 1.0, "front": "high", "scale": 1.1},
	"skiddy": {"run_time": 1.9, "speed": 4.2, "jump": 0.7, "arm_out": 40.0, "side_on": 0.9, "front": "high", "scale": 0.95},
	"finger": {"run_time": 1.35, "speed": 2.9, "jump": 0.6, "arm_out": 8.0, "side_on": 1.0, "front": "high", "scale": 1.0},
	"wrist": {"run_time": 1.2, "speed": 2.3, "jump": 0.5, "arm_out": 16.0, "side_on": 1.45, "front": "high", "scale": 0.97},
}

static func of(bowler_name: String) -> Dictionary:
	return ALL.get(bowler_name, ALL["D. Hartigan"])

static func action(action_name: String) -> Dictionary:
	return ACTIONS.get(action_name, ACTIONS["express"])

static func is_spin(style: String) -> bool:
	return style == "off" or style == "leg" or style == "sla"

## Five bowlers for a match: three quicks and two spinners, picked by the seed.
static func attack_for(rng_seed: int) -> Array:
	var h := absi(hash(rng_seed * 3571 + 1))
	var quicks: Array = PACERS.duplicate()
	quicks.remove_at(h % quicks.size())
	var spin: Array = SPINNERS.duplicate()
	spin.remove_at((h / 5) % spin.size())
	return quicks + spin

## What the card says about their pace, in km/h.
static func pace_text(p: Dictionary) -> String:
	return "%d–%d KM/H" % [int(round(p.pace[0] * 3.6)), int(round(p.pace[1] * 3.6))]
