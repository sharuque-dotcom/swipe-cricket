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

## Career

Make a batter (name and role: opener, top order, middle order or finisher) and start in club
cricket. Each season is a set of chases; win enough of them, or average 35, and you move up:
club, state, franchise, international. Bowlers get quicker and totals bigger as you go.

You play your own innings. Team-mates who bat before you are played out at once and a card
tells you how they got on; while you are at the non-striker's end your partner's balls are
shown as a quick read-out. When you are out you choose: play the rest of the innings yourself,
or simulate to the end.

Your ratings grow from how you bat: timing from how often you middle it, power from how far
you hit it. The career page shows your ratings, the next match (opponent, pitch, day or night,
their attack), the season, your career numbers (runs, average, strike rate, highest, 50s and
100s, 4s and 6s), how often you time it in the green, and your recent innings.

## How a match plays

- Timing decides everything. The green zone of the timing meter is the sweet spot; the further
  outside it, the less pace the ball comes off with. Only a middled lofted shot clears the rope.
- Swinging harder, and going aerial, both shrink the green zone. A mistimed slog goes up, not out.
- Batters differ. The scoreboard shows the striker's role and their POWER and TIMING out of
  five; the tail can neither time it nor hit it far.
- Fielding restrictions apply: two outside the ring in overs 1 to 6, five after that.
- The field is set for each batter. Fielders move to where the striker has been hitting it, so
  the gaps open somewhere else and the same shot stops paying.
- The game waits for you to tap before every ball, so you can check the field on the radar.
  Turn on AUTO BOWL (bottom right) to have the next ball come on its own after a moment; it
  waits longer when a new bowler's card is up, and a tap still bowls straight away.
  When a new bowler comes on, a card shows who it is (pacer or spinner, their style, pace and
  what the ball does), the whole field by name, and where this batter has been hitting it.
- Step out: touch the screen while the bowler is running in and the batter charges down the
  pitch, then swipe as usual. You meet the ball sooner, before a spinner's turn has taken
  hold, and can hit it on the full. Get beaten by a spinner and the keeper stumps you.
- Shots look different: drives, lofted drives, stepping out to spin, the helicopter shot off
  a yorker, cuts and upper cuts, pulls (the one-legged pull when you go aerial), hooks, sweeps,
  slog sweeps, reverse sweeps against spin, scoops and ramps. Each batter stands a little
  differently too.
- At the end of every over the scorecard comes up: each batter's runs, balls, fours, sixes,
  strike rate and how they got out, who is yet to bat, the fall of wickets and the bowling
  figures. Switch to the other side's innings to see how they made their total. Tap to go on.
- Between balls: the openers walk out, the fielders mob the bowler after a wicket while the
  batter walks off and the next one walks in, fifties and hundreds get the bat raised, and the
  winning runs get a celebration. Tap to skip any of it.
- Every match has a pitch and a time of day. A green seamer gives the quicks swing and seam
  movement; a flat road is true and fast with a quick outfield (and Red post a bigger total);
  a dusty turner grips and turns and keeps low as it wears. Under lights the dew comes in
  during the chase: the ball skids on and the spinners lose their grip.
- Matches use a white ball and a black sight screen, as in real T20 cricket; the nets keep the
  red ball.
- Red's bowlers each have their own action and their own stock ball: a left-arm express
  quick angling it across you, a slinger with a short run and a late, low release, a tall
  bowler who gets steep bounce, a cutter bowler who skids on, an off-spinner who darts it, a
  leg-spinner with drift, dip, googly and flipper, and a left-arm orthodox spinner. The
  release point and the spin go into the physics, so each one plays differently.
- Read the field. Each over the bowler has a plan (short, wide of off, or full and straight)
  and the field is set for it, so where the fielders are tells you what is coming.
- The captain reacts to the game: a slip and catchers in for a new batter, the field spread
  when you are behind the rate, everyone up to stop the single in a tight last over.
- Eleven in the field: nine fielders, the keeper and the bowler, shown on the radar bottom-left.
  A fielded ball stays in the fielder's hands and is thrown in to the keeper.

- Fours, sixes and wickets get the full treatment: the umpire signals, a full-screen call sweeps
  across, and a slow-motion replay runs from stump height. Tap to skip any of it.
- Fielders dive for catches and stops at full stretch and slide to save the ball at the rope.

`tests/pose_viewer.gd` and `tests/bowler_viewer.gd` render every batting and bowling animation
to images for checking.
`godot --headless -s tests/balance_sim.gd` plays whole innings with simulated players and prints
what each style of batting scores; use it when changing `core/tuning.gd` or `core/fielding.gd`.

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
