extends SceneTree
## Balance check, not a test:  godot --headless -s tests/balance_sim.gd -- [sigma]
## Plays many balls with a simulated player (timing error ~ normal(0, sigma)) against the
## match bowlers and field, and prints scoring and dismissal rates.

func _init() -> void:
	var sigma := 0.45
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			sigma = float(a)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var machine := BowlingMachine.new(3)
	var n := 3000
	var runs := 0
	var outs := {}
	var counts := {"4": 0, "6": 0, "dot": 0, "edge": 0}
	var by_style := {}
	for i in n:
		var over := (i / 6) % 20
		var bi: int = MatchState.PLAN[over]
		var style: String = MatchState.BOWLERS[bi][1]
		var d := machine.next_for(style, over)
		var launch := d.solve()
		var w := ShotResolver.hit_window(launch)
		if w.is_empty():
			continue
		var sw := ShotResolver.Swing.new()
		sw.angle = deg_to_rad(rng.randf_range(-100.0, 100.0))
		sw.power = rng.randf_range(0.45, 1.0)
		sw.loft = 1.0 if rng.randf() < 0.35 else 0.0
		sw.contact_time = w.t_mid + rng.randfn(0.0, sigma) * w.half
		var r := ShotResolver.resolve(launch, sw)
		var scored := 0
		var out := ""
		if r.exit == null:
			# Missed: does it hit the stumps?
			var s := launch.copy()
			var prev := s.pos
			while s.pos.z < 3.5 and s.time < 3.0:
				BallPhysics.step(s)
				if Pitch.hits_stumps(prev, s.pos, BallPhysics.RADIUS):
					out = "bowled"
					break
				prev = s.pos
		else:
			if r.outcome == ShotResolver.Outcome.EDGE:
				counts.edge += 1
			var f := Fielding.evaluate(r.exit, Fielding.layout(style == "off" or style == "leg", over < 6))
			if f.caught:
				out = "c " + f.fielder_name
			else:
				scored = f.runs
		if out != "":
			outs[out] = outs.get(out, 0) + 1
		else:
			runs += scored
			if scored == 4:
				counts["4"] += 1
			elif scored == 6:
				counts["6"] += 1
			elif scored == 0:
				counts.dot += 1
		var st: Dictionary = by_style.get(style, {"balls": 0, "runs": 0, "outs": 0})
		st.balls += 1
		st.runs += scored
		st.outs += 1 if out != "" else 0
		by_style[style] = st
	var total_outs := 0
	for k in outs:
		total_outs += outs[k]
	print("sigma %.2f  balls %d" % [sigma, n])
	print("runs/over %.2f   wickets/over %.3f  (=> %.1f wkts in 20 overs)" % [runs * 6.0 / n, total_outs * 6.0 / n, total_outs * 120.0 / n])
	print("dots %.0f%%  fours %.1f%%  sixes %.1f%%  edges %.1f%%" % [100.0 * counts.dot / n, 100.0 * counts["4"] / n, 100.0 * counts["6"] / n, 100.0 * counts.edge / n])
	var keys := outs.keys()
	keys.sort_custom(func(a, b): return outs[a] > outs[b])
	for k in keys:
		print("  %-22s %d" % [k, outs[k]])
	for s in by_style:
		var st: Dictionary = by_style[s]
		print("  %-6s rpo %.2f  wkts/over %.3f" % [s, st.runs * 6.0 / st.balls, st.outs * 6.0 / st.balls])
	quit()
