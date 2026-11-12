extends SceneTree
## Balance check, not a test:  godot --headless -s tests/balance_sim.gd
## Plays whole 20-over innings with simulated players against the match bowlers and field,
## using Blue's real batting card, and prints what each kind of player scores.
## A player is a timing error (normal, in units of the timing window) and a way of batting:
##   slog   every ball flat out and in the air, somewhere in front of square
##   smart  full power along the ground into the gaps, going aerial one ball in four
##   mixed  random direction and power, as someone still learning would

const MATCHES := 8
var _outs := {}

func _play(sigma: float, style: String, sd: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var machine := BowlingMachine.new(sd * 7 + 1)
	var m := MatchState.create(sd)
	m.target = 100000
	var fours := 0
	var sixes := 0
	while not m.finished():
		var over := m.over_index()
		var style_b := m.bowler_style()
		var d := machine.next_for(style_b, over)
		var launch := d.solve()
		var w := ShotResolver.hit_window(launch)
		var sw := ShotResolver.Swing.new()
		sw.skill = m.striker_skill()
		match style:
			"slog":
				sw.angle = deg_to_rad(rng.randf_range(-60.0, 60.0))
				sw.power = 1.0
				sw.loft = 1.0
			"smart":
				sw.angle = deg_to_rad([-70.0, -38.0, 0.0, 33.0, 62.0, 95.0][rng.randi() % 6] + rng.randf_range(-6.0, 6.0))
				sw.power = 1.0
				sw.loft = 1.0 if rng.randf() < 0.25 else 0.0
			_:
				sw.angle = deg_to_rad(rng.randf_range(-100.0, 100.0))
				sw.power = rng.randf_range(0.45, 1.0)
				sw.loft = 1.0 if rng.randf() < 0.35 else 0.0
		sw.contact_time = w.t_mid + rng.randfn(0.0, sigma) * w.half
		var r := ShotResolver.resolve(launch, sw)
		var scored := 0
		var out := ""
		if r.exit == null:
			var s := launch.copy()
			var prev := s.pos
			while s.pos.z < 3.5 and s.time < 3.0:
				BallPhysics.step(s)
				if Pitch.hits_stumps(prev, s.pos, BallPhysics.RADIUS):
					out = "b"
					break
				prev = s.pos
		else:
			var f := Fielding.evaluate(r.exit, Fielding.layout(style_b == "off" or style_b == "leg", over < 6))
			if f.caught:
				out = "c " + f.fielder_name
			else:
				scored = f.runs
		if scored == 4:
			fours += 1
		elif scored == 6:
			sixes += 1
		if out != "":
			var key := "bowled" if out == "b" else ("c keeper/slip" if out in ["c keeper", "c slip"] else ("c bowler" if out == "c bowler" else \
				("c deep" if out.contains("deep") or out.contains("long") or out.contains("fine") else "c infield")))
			_outs[key] = _outs.get(key, 0) + 1
		m.record(scored, out)
	return {"runs": m.runs, "wkts": m.wickets, "balls": m.balls, "fours": fours, "sixes": sixes}

func _sigmas() -> Array:
	var out := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			out.append(float(a))
	return out if not out.is_empty() else [0.30, 0.50]

func _init() -> void:
	print("%-6s %-5s  %6s %5s %6s %6s %6s  %s" % ["style", "sigma", "total", "wkts", "overs", "fours", "sixes", "all out"])
	for style in ["slog", "smart", "mixed"]:
		for sigma in _sigmas():
			_outs = {}
			var t := {"runs": 0, "wkts": 0, "balls": 0, "fours": 0, "sixes": 0}
			var all_out := 0
			for i in MATCHES:
				var r := _play(sigma, style, i + 1)
				for k in t:
					t[k] += r[k]
				if r.wkts >= 10:
					all_out += 1
			var n := float(MATCHES)
			print("%-6s %-5.2f  %6.0f %5.1f %6.1f %6.1f %6.1f  %3.0f%%" % [style, sigma, t.runs / n, t.wkts / n,
				t.balls / n / 6.0, t.fours / n, t.sixes / n, 100.0 * all_out / n])
			var parts := []
			for k in _outs:
				parts.append("%s %.1f" % [k, _outs[k] / n])
			print("        out: " + ", ".join(parts))
	quit()
