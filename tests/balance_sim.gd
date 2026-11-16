extends SceneTree
## Balance check, not a test:  godot --headless -s tests/balance_sim.gd
## Plays whole 20-over chases with simulated players against the match bowlers and field,
## using Blue's real batting card, and prints what each kind of player scores.
## A player is a timing error (normal, in units of the timing window) and a way of batting:
##   slog   every ball flat out and in the air, somewhere in front of square
##   smart  reads the field: full power into the gaps, along the ground three balls in four
##   mixed  random direction and power, as someone still learning would

const MATCHES := 8
var _outs := {}

func _play(sigma: float, style: String, sd: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var machine := BowlingMachine.new(sd * 7 + 1)
	var m := MatchState.create(sd)
	var fours := 0
	var sixes := 0
	while not m.finished():
		var over := m.over_index()
		var style_b := m.bowler_style()
		var d := machine.next_for(style_b, over, Captain.plan(m.seed_value, over, style_b))
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
				# Looks at the field and hits into one of the three biggest gaps.
				sw.loft = 1.0 if rng.randf() < 0.25 else 0.0
				sw.angle = deg_to_rad(_gap(Captain.field(m), sw.loft > 0.5, rng) + rng.randf_range(-5.0, 5.0))
				sw.power = 1.0
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
			var f := Fielding.evaluate(r.exit, Captain.field(m))
			m.note_shot(rad_to_deg(atan2(r.exit.vel.x, -r.exit.vel.z)), f.distance, 0 if f.caught else f.runs)
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
	return {"runs": m.runs, "wkts": m.wickets, "balls": m.balls, "fours": fours, "sixes": sixes, "won": 1 if m.won() else 0,
		"target": m.target}

## A direction in front of the wicket that is far from the fielders who matter for this
## shot: the ring for a ground shot, the men on the rope for a lofted one.
func _gap(field: Array, lofted: bool, rng: RandomNumberGenerator) -> float:
	var scored := []
	var a := -100.0
	while a <= 100.0:
		var nearest := 180.0
		for s in field:
			if s.name == "bowler" or s.kind == Fielding.Kind.KEEPER or s.kind == Fielding.Kind.CLOSE:
				continue
			if lofted != (s.kind == Fielding.Kind.DEEP):
				continue
			var fa := rad_to_deg(atan2(s.pos.x, -(s.pos.z + 1.0)))
			nearest = minf(nearest, absf(wrapf(a - fa, -180.0, 180.0)))
		scored.append([nearest, a])
		a += 10.0
	scored.sort_custom(func(x, y): return x[0] > y[0])
	return scored[rng.randi() % 3][1]

func _sigmas() -> Array:
	var out := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			out.append(float(a))
	return out if not out.is_empty() else [0.30, 0.50]

func _init() -> void:
	print("%-6s %-5s  %6s %6s %5s %6s %6s %6s  %7s  %s" % ["style", "sigma", "target", "total", "wkts", "overs", "fours", "sixes", "all out", "won"])
	for style in ["slog", "smart", "mixed"]:
		for sigma in _sigmas():
			_outs = {}
			var t := {"runs": 0, "wkts": 0, "balls": 0, "fours": 0, "sixes": 0, "won": 0, "target": 0}
			var all_out := 0
			for i in MATCHES:
				var r := _play(sigma, style, i + 1)
				for k in t:
					t[k] += r[k]
				if r.wkts >= 10:
					all_out += 1
			var n := float(MATCHES)
			print("%-6s %-5.2f  %6.0f %6.0f %5.1f %6.1f %6.1f %6.1f  %6.0f%%  %3.0f%%" % [style, sigma, t.target / n, t.runs / n, t.wkts / n,
				t.balls / n / 6.0, t.fours / n, t.sixes / n, 100.0 * all_out / n, 100.0 * t.won / n])
			var parts := []
			for k in _outs:
				parts.append("%s %.1f" % [k, _outs[k] / n])
			print("        out: " + ", ".join(parts))
	quit()
