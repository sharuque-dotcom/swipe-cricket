# Swipe Cricket (working title)

A quick, physics-driven 3D cricket game for Android, built with Godot 4.7.

Every ball is simulated: flight, swing, spin, bounce and bat contact. After each ball the game
shows how early or late you were in milliseconds, so a miss is always explainable.

## Status

Milestone 1, the nets: one batter, a bowling machine with pace, swing and spin, swipe batting,
12-ball sessions. Bowling, fielders and full matches come next.

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

- `core/` deterministic simulation: ball physics, delivery solver, shot resolution, scoring
- `input/` swipe recognition
- `actors/` procedural players and bat, animated with inverse kinematics
- `world/` stadium, pitch and shaders, all built in code
- `game/` game loop and camera
- `ui/`, `audio/` HUD and synthesised sound
- `tests/` headless tests

Feel constants live in `core/tuning.gd`.
