# Swipe Cricket (working title)

A quick, physics-driven 3D cricket game for Android, built with Godot 4.7.

Every ball is simulated: flight, swing, spin, bounce and bat contact. After each ball the game
shows how early or late you were in milliseconds, so a miss is always explainable.

## Status

- **20-over match, Blue v Red.** Red bat first (simulated from T20 scoring rates), you chase.
  Five Red bowlers with their own styles (swing, pace, off spin, leg spin; yorkers and bouncers
  at the death), ten fielders, catches, edges to the keeper and slip, bowled, strike rotation,
  and a powerplay: after six overs the slip and point drop back to the boundary.
  The match saves after every ball; resume it from the menu.
- **Nets:** 12-ball sessions against a bowling machine.

Bowling, run-outs and LBW come next.

## How to play

Swipe to play a shot. Lift your finger just before the ball arrives.

- Direction of the swipe is where the ball goes: up is straight, right is the off side.
- Speed of the swipe is power.
- A long swipe lofts the ball; a short one keeps it on the ground.

## Run it

Open the folder in Godot 4.7 and press Play, or from a terminal:

```bash
godot --path .
```

Skip the menu with `godot --path . -- --scene=match` (or `--scene=nets`). Add `--autoplay` to let a
bot bat. Check the balance of the match (simulated player, timing spread as the argument):

```bash
godot --headless -s tests/balance_sim.gd -- 0.45
```

Run the tests:

```bash
godot --headless --import
```

```bash
godot --headless -s tests/run_tests.gd
```

Build the Android debug APK (needs the Android SDK and export templates set up in Godot):

```bash
godot --headless --export-debug Android build/swipe-cricket-debug.apk
```

CI builds the APK and a web build on every push; download them from the run's artifacts.

## Layout

- `core/` deterministic simulation: ball physics, delivery solver, shot resolution, scoring,
  fielding (`fielding.gd`), the match (`match_state.gd`) and Red's innings (`innings_sim.gd`)
- `input/` swipe recognition
- `actors/` procedural players and bat, animated with inverse kinematics
- `world/` stadium, pitch and shaders, all built in code
- `game/` menu, nets loop and camera, and the match (`match_game.gd`, built on the nets)
- `ui/`, `audio/` HUD and synthesised sound
- `tests/` headless tests

Feel constants live in `core/tuning.gd`.
