extends "res://game/nets.gd"
## A 20-over chase. Red have batted (simulated); you bat for Blue against Red's five bowlers
## and ten fielders. Catches, edges to the keeper, bowled, and runs that depend on where the
## fielders are. Saves after every ball so a match can be resumed.

const SAVE_PATH := "user://match.json"
const RED_KIT := Color(0.80, 0.14, 0.16)
const BLUE_KIT := Color(0.10, 0.32, 0.78)

enum Phase { INTRO, PLAY, OVER_BREAK, RESULT }

var match_state: MatchState
var phase := Phase.INTRO
var field: Array[Fielding.Spot] = []
var fielders: Array[Fielder] = []
var _spinner_field := false
var _dead_for := 0.0
var _fresh := false

# Who has the ball. Once a fielder gathers it the ball sits in their hands, then is thrown in.
const HOLD_BEFORE_THROW := 0.4
var _taker: Fielder = null    # the fielder going for the ball (null with _take_at set = the bowler)
var _take_at := -1.0          # ball-clock time at which they have it
var _held := false
var _held_for := 0.0
var _throws := false
var _throw_from := Vector3.ZERO
var _throw_time := 0.0
var _hold_pos := Vector3.ZERO

var umpire: Umpire
var non_striker: NonStriker
var _field_over := -1         # the over the field was last set for
var _mood := "normal"         # the captain's mood the field was last set for
var _ready_t := 0.0           # how long the field card has been up before this ball
var auto_bowl := false        # bowl without waiting for a tap
const AUTO_WAIT := 1.2        # seconds to look at the field before an auto ball
const AUTO_WAIT_CARD := 3.0   # longer when a new bowler's card is up

# Cutscenes between balls: openers walking out, the wicket huddle and the walk-off and
# walk-in, milestones, and the finish. Queued, played after any replay, tap skips.
var _scenes: Array = []
var _scene := {}
var walker_out: Walker
var walker_in: Walker

# A boundary or a wicket plays out as: the moment live, the umpire's signal, a full-screen
# call, then a slow-motion replay from stump height.
const SIGNAL_TIME := 0.95
var _event := {}
var _event_t := -1.0
var _cut := false             # camera is on the umpire
var _wiped := false
var _replay_pending := false
var _replaying := false
var _replay_ref := 0.0        # ball-clock time of the moment being replayed
var _replay_end := 0.0
var _replay_swung := false
var _replay_catch_cam := Vector3.ZERO
var _bowled_at := 0.0

func _new_session() -> void:
	if fielders.is_empty():
		_build_fielders()
	machine = BowlingMachine.new(1)
	var resumed := _load()
	if not resumed:
		var sd := int(Time.get_unix_time_from_system()) if not autoplay else 21
		var opts := {}
		# Test hooks: --pitch=dusty, --night, --day force the conditions.
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pitch="):
				opts["pitch"] = a.trim_prefix("--pitch=")
			elif a == "--night" or a == "--day":
				opts["night"] = a == "--night"
		match_state = MatchState.create(sd, opts)
		machine = BowlingMachine.new(sd)
		match_state.machine_state = machine.state
	else:
		machine.state = match_state.machine_state
	_fresh = not resumed
	runs = match_state.runs
	wickets = match_state.wickets
	ball_no = match_state.balls
	state = State.SUMMARY
	timer = 0.0
	phase = Phase.INTRO
	hit_view_cap = 6.0
	stadium.set_conditions(match_state.pitch, match_state.night)
	_field_over = -1
	_scenes.clear()
	_scene = {}
	if not resumed:
		_scenes.append({"kind": "openers"})
	_replay_pending = false
	_replaying = false
	_event_t = -1.0
	_cut = false
	time_scale_base = 1.0
	hud.set_replay(false)
	hud.set_hint("")
	hud.clear_result()
	hud.set_delivery("")
	_set_field()
	_refresh_hud()
	var m := match_state
	if resumed:
		hud.show_card({"kicker": "MATCH RESUMED", "title": "%d/%d" % [m.runs, m.wickets], "sub": "after %s overs" % m.overs_text(),
			"rows": [["Need", "%d off %d balls" % [m.need(), m.balls_left()]], ["Required rate", "%.1f" % m.required_rate()],
				["On strike", m.striker_name()]],
			"prompt": "Tap to carry on"})
	else:
		hud.show_card({"kicker": "20-OVER MATCH  ·  SECOND INNINGS", "title": "CHASE %d" % m.target, "sub": "off 120 balls",
			"rows": [["%s made" % m.red_name, "%d/%d" % [m.red_total, m.red_wickets], Hud.RED], ["Their top score", m.red_top],
				["Pitch", str(Conditions.info(m.pitch).name).capitalize(), Hud.GOLD],
				["Played", "Under lights" if m.night else "In the day"]],
			"notes": [str(Conditions.info(m.pitch).blurb) + (".\nDew will come in later: the ball skids on." if m.night else ".")],
			"prompt": "Tap to start the chase"})

func _build_fielders() -> void:
	for i in 11:
		var f := Fielder.new()
		add_child(f)
		f.build(RED_KIT, Color(1, 1, 1), i == 0)
		fielders.append(f)
	umpire = Umpire.new()
	umpire.position = Vector3(0.0, 0.0, Pitch.BOWLER_STUMPS_Z - 1.8)
	umpire.rotation.y = PI
	add_child(umpire)
	umpire.build()
	non_striker = NonStriker.new()
	non_striker.position = Vector3(-1.25, 0.0, Pitch.BOWLER_CREASE_Z - 0.45)
	non_striker.rotation.y = PI
	add_child(non_striker)
	non_striker.build(BLUE_KIT, Color(1.0, 0.80, 0.15))
	walker_out = Walker.new()
	add_child(walker_out)
	walker_out.build(BLUE_KIT, Color(1.0, 0.80, 0.15))
	walker_out.visible = false
	walker_in = Walker.new()
	add_child(walker_in)
	walker_in.build(BLUE_KIT, Color(1.0, 0.80, 0.15))
	walker_in.visible = false
	auto_bowl = Settings.get_bool("auto_bowl", false)
	hud.show_auto_toggle(auto_bowl)
	hud.auto_bowl_toggled.connect(func(on: bool):
		auto_bowl = on
		Settings.set_bool("auto_bowl", on)
		if state == State.READY:
			hud.show_tap_prompt(not hud._field_card.visible, on)
			_ready_t = 0.0)
	swipe.blockers.append(hud.auto_toggle)

## Spinners get a keeper up at the stumps and a long-on instead of a slip.
func _set_field() -> void:
	_spinner_field = BowlerProfile.is_spin(match_state.bowler_style())
	field = Captain.field(match_state)
	for i in fielders.size():
		var f := fielders[i]
		# The last spot is the bowler, who is already on the pitch.
		var used := i < field.size() - 1
		f.visible = used
		if used:
			f.reset(field[i].pos)
	hud.radar_field(field)
	# Names on shirts: the bowler's own, and the rest of the Red eleven round the field.
	var others := []
	for n: String in MatchState.RED:
		if n != match_state.bowler_name():
			others.append(n)
	for i in fielders.size():
		_shirt(fielders[i].figure, others[i % others.size()])
	_shirt(bowler.figure, match_state.bowler_name())

func _shirt(figure: Figure, full_name: String) -> void:
	figure.set_shirt(_surname(full_name), 1 + absi(full_name.hash()) % 98)

func _batter_skill() -> BatterSkill:
	return match_state.striker_skill()

func _next_ball() -> void:
	_event_t = -1.0
	_cut = false
	if _replay_pending:
		_start_replay()
		return
	if not _scenes.is_empty():
		_start_scene(_scenes.pop_front())
		return
	if match_state.finished():
		_show_result()
		return
	phase = Phase.PLAY
	hud.hide_card()
	hud.radar_clear()
	_taker = null
	_take_at = -1.0
	_held = false
	_throws = false
	_throw_time = 0.0
	ball_no = match_state.balls + 1
	machine.state = match_state.machine_state
	Conditions.apply(match_state.pitch, match_state.night, match_state.over_index())
	var d := machine.next_for(match_state.bowler_style(), match_state.over_index(),
		Captain.plan(match_state.seed_value, match_state.over_index(), match_state.bowler_style()),
		match_state.bowler_profile(), match_state.conditions())
	match_state.machine_state = machine.state
	# The captain sets the field every ball, for whoever is on strike and what they have
	# been doing. Say so when somebody moves.
	var new_over := match_state.over_index() != _field_over
	_field_over = match_state.over_index()
	var before := {}
	for sp in field:
		before[sp.name] = true
	_set_field()
	var moved := []
	for sp in field:
		if not before.has(sp.name):
			moved.append(sp.name)
	_start_delivery(d)
	var mood := Captain.mood(match_state)
	var mood_changed := mood != _mood and not before.is_empty()
	_mood = mood
	if before.is_empty() or new_over:
		moved.clear()
	_reset_fielders()
	umpire.give(Umpire.Sig.NONE)
	_refresh_hud()
	# Hold the bowler at the top of their mark and show the field until the player taps.
	state = State.READY
	bowler.active = false
	bowler.t = -bowler.run_time()
	bowler.pose_at(bowler.t)
	_ready_t = 0.0
	hud.set_delivery("")
	if new_over:
		# A new bowler: the full card, with the field.
		hud.show_field_card(field, _card_info(new_over, mood, mood_changed), moved)
	else:
		# Otherwise the radar is enough; say if the captain has changed something.
		hud.show_tap_prompt(true, auto_bowl)
		if mood_changed:
			hud.set_delivery(Captain.mood_text(mood))
		elif not moved.is_empty():
			hud.set_delivery("FIELD CHANGE  ·  %s" % ", ".join(moved.slice(0, 2)))

## Everything the pre-ball card says about the bowler and the field.
func _card_info(new_over: bool, mood: String, mood_changed: bool) -> Dictionary:
	var m := match_state
	var st := _style_info(m.bowler_profile())
	var bi := m.bowler_index()
	var ball_in_over := m.balls % MatchState.BALLS_PER_OVER + 1
	var info := st.duplicate()
	info["kicker"] = ("OVER %d OF %d  ·  NEW BOWLER" % [m.over_index() + 1, MatchState.OVERS]) if new_over \
		else "OVER %d  ·  BALL %d" % [m.over_index() + 1, ball_in_over]
	info["new_over"] = new_over
	info["bowler"] = m.bowler_name()
	info["figures"] = m.bowler_figures(bi)
	info["mood"] = {"attack": "ATTACKING FIELD", "defend": "SPREAD FIELD", "save_one": "SAVING THE SINGLE"}.get(mood, "STANDARD FIELD")
	info["mood_changed"] = mood_changed
	info["mood_color"] = {"attack": Hud.RED, "defend": Hud.BLUE, "save_one": Hud.GOLD}.get(mood, Hud.DIM)
	info["ring"] = "%d OUTSIDE THE RING%s" % [Fielding.outside_ring(field), "  ·  POWERPLAY" if m.over_index() < 6 else ""]
	info["shots"] = m.striker_shots()
	info["striker"] = m.striker_name()
	info["auto"] = auto_bowl
	return info

func _style_info(p: Dictionary) -> Dictionary:
	return {"kind": "SPINNER" if BowlerProfile.is_spin(str(p.style)) else "PACER", "style": str(p.label),
		"pace": BowlerProfile.pace_text(p), "trait": str(p.trait)}

## The player has seen the field: the bowler sets off.
func _bowl() -> void:
	hud.hide_field_card()
	hud.show_tap_prompt(false)
	state = State.RUNUP
	bowler.start(delivery.speed < 27.0)

func _reset_fielders() -> void:
	for i in fielders.size():
		if fielders[i].visible:
			fielders[i].reset(field[i].pos)
	_taker = null
	_take_at = -1.0
	_held = false
	_throws = false
	_throw_time = 0.0

func _refresh_hud() -> void:
	hud.set_match(match_state)
	_shirt(batter.figure, match_state.striker_name())
	batter.vary(match_state.striker)
	_shirt(non_striker.figure, str(match_state.batters[match_state.non_striker].name))

## Queue the umpire's signal, the full-screen call and the replay for a big moment.
## `lead` is how long the live view runs on first.
func _big_moment(text: String, sub: String, c: Color, sig: Umpire.Sig, lead: float) -> void:
	_event = {"text": text, "sub": sub, "color": c, "sig": sig, "lead": lead}
	_event_t = 0.0
	_cut = false
	_wiped = false
	_replay_pending = true
	# The next thing (the replay) starts while the call still covers the screen.
	timer = lead + SIGNAL_TIME + Hud.Wipe.IN + 0.15

func _start_replay() -> void:
	_replay_pending = false
	_replaying = true
	hud.clear_result()
	hud.set_delivery("")
	hud.set_replay(true)
	hud.radar_clear()
	_reset_fielders()
	umpire.give(Umpire.Sig.NONE)
	stadium.batter_stumps.reset()
	batter.reset()
	batter.backlift()
	var hit := pending != null and pending.exit != null
	_replay_ref = pending.contact_time if hit else _bowled_at
	_replay_swung = pending == null
	_replay_end = _replay_ref + 0.75
	_replay_catch_cam = Vector3.ZERO
	var r := summary as Fielding.Result
	if hit and r != null:
		if r.caught:
			_replay_end = _replay_ref + minf(r.field_time + 0.5, 3.4)
			# Second angle: beside the fielder, watching it come to them.
			var away := Vector3(r.field_pos.x, 0.0, r.field_pos.z + 1.0).normalized()
			var side := Vector3(away.z, 0.0, -away.x)
			var at := r.field_pos + away * 3.2 + side * 3.4
			var off := at - Pitch.FIELD_CENTRE
			if off.length() > 66.0:
				at = Pitch.FIELD_CENTRE + off.normalized() * 66.0
			_replay_catch_cam = at + Vector3(0, 1.9, 0)
		else:
			_replay_end = _replay_ref + minf(r.end_time - pending.contact_time + 0.1, 1.7)
	var t0 := maxf(_replay_ref - 0.42, 0.02)
	ball = ShotResolver.state_at_time(launch, t0)
	clock = t0
	_last_bounces = ball.bounces
	_trail_pos.clear()
	state = State.FLIGHT
	swung = true
	ball_node.visible = true
	blob.visible = true
	time_scale_base = 0.3
	_cam_look = Vector3(-0.1, 0.9, -1.1)

func _end_replay() -> void:
	_replaying = false
	time_scale_base = 1.0
	hud.set_replay(false)
	hud.clear_result()
	state = State.DEAD
	timer = 0.02
	_dead_for = 0.0

func _update_camera(delta: float) -> void:
	if _cam_locked:
		return
	if not _scene.is_empty():
		_scene_camera()
		return
	if _replaying:
		# Stump height, just outside off, looking up at the batter; then follow the ball.
		var real := delta / maxf(Engine.time_scale, 0.1)
		var target := Vector3(-0.1, 0.9, -1.1)
		var from := Vector3(2.5, 0.55, 2.7)
		if pending == null or pending.exit == null:
			target = Vector3(0.0, 0.5, -0.2)   # bowled: stay on the stumps
		elif state != State.FLIGHT and ball != null:
			target = Vector3(ball.pos.x, maxf(ball.pos.y, 0.5), ball.pos.z)
			if _replay_catch_cam != Vector3.ZERO and clock > _replay_ref + 0.5:
				from = _replay_catch_cam
			elif pending != null and pending.exit != null and clock > _replay_ref + 0.32:
				# Second angle: high behind the batter, watching it go.
				from = Vector3(0.0, 7.5, 13.0)
		_cam_look = _cam_look.lerp(target, 1.0 - exp(-real * 7.0))
		cam.fov = 44.0
		cam.position = from
		if from.distance_squared_to(_cam_look) > 0.01:
			cam.look_at(_cam_look)
		return
	if _cut:
		cam.fov = 30.0
		cam.position = umpire.position + Vector3(0.9, 1.55, 5.2)
		cam.look_at(umpire.position + Vector3(0.0, 1.42, 0.0))
		return
	super._update_camera(delta)

func _evaluate_hit(exit: BallPhysics.State) -> NetsScoring.Summary:
	var r := Fielding.evaluate(exit, field)
	var chaser := -1
	if r.fielder >= 0 and not r.boundary:
		# Send the fielder: they arrive as the ball does, hands where it will be.
		_take_at = exit.time + r.field_time
		_throws = not r.caught and r.fielder_name != "keeper"
		if r.fielder < fielders.size() and fielders[r.fielder].visible:
			_taker = fielders[r.fielder]
			_taker.go(r.field_pos, r.field_time, r.caught, r.field_height, r.field_dir)
			chaser = r.fielder
		else:
			_throws = false   # the bowler took it in the follow-through
	# Whoever else is nearest gives chase, so nobody stands and watches it go by.
	var best_d := 45.0
	var runner := -1
	for i in fielders.size() - 1:
		if i == chaser or i == 0 or not fielders[i].visible:
			continue
		var d := Vector2(field[i].pos.x - r.end_pos.x, field[i].pos.z - r.end_pos.z).length()
		if d < best_d:
			best_d = d
			runner = i
	if runner >= 0:
		fielders[runner].chase(r.end_pos, r.end_time - exit.time)
	return r

## The ball as drawn. Once the fielder has it, it stays in their hands until they throw it
## in to the keeper, so it can never be seen running on through them.
func _show_ball() -> void:
	if _take_at >= 0.0 and not _held and ball.time >= _take_at:
		_held = true
		_held_for = 0.0
		_cam_parked = true
		_trail_pos.clear()
		_hold_pos = _taker.hands_global() if _taker != null else Vector3(ball.pos.x, maxf(ball.pos.y, BallPhysics.RADIUS), ball.pos.z)
		if _taker != null:
			sfx.play("bounce", -9.0)
	if _held:
		var at := _taker.hands_global() if _taker != null and _held_for < HOLD_BEFORE_THROW else _hold_pos
		if _throws and _held_for >= HOLD_BEFORE_THROW:
			var keeper := fielders[0]
			if _throw_time <= 0.0:
				_throw_from = _taker.hands_global()
				_throw_time = maxf(_throw_from.distance_to(keeper.position) / Fielding.THROW_SPEED, 0.25)
				_taker.throw_to(keeper.position)
				keeper.take_throw(_throw_from)
			var u := clampf((_held_for - HOLD_BEFORE_THROW) / _throw_time, 0.0, 1.0)
			var arc := _throw_from.distance_to(keeper.position) * 0.07
			at = _throw_from.lerp(keeper.hands_global(), u) + Vector3.UP * (4.0 * arc * u * (1.0 - u))
		_hold_pos = at
		ball.pos = at
		ball.vel = Vector3.ZERO
		ball.at_rest = true
	elif state == State.HIT:
		hud.radar_ball(ball.pos)
	super._show_ball()

func _connect() -> void:
	super._connect()
	if _replaying:
		hud.clear_result()

func _score_hit() -> void:
	var r := summary as Fielding.Result
	if _replaying:
		# Let the replay run on past the catch or the rope; it ends on its own clock.
		state = State.DEAD
		timer = 99.0
		return
	state = State.DEAD
	timer = 1.6
	var who := _surname(match_state.striker_name())
	if r != null and pending != null and pending.exit != null:
		match_state.note_shot(rad_to_deg(atan2(pending.exit.vel.x, -pending.exit.vel.z)), r.distance, 0 if r.caught else r.runs)
	if r != null and r.caught:
		var how := ("c %s b %s" % [r.fielder_name, _surname(match_state.bowler_name())]) if r.fielder_name != "bowler" \
			else "c & b %s" % _surname(match_state.bowler_name())
		if r.fielder_name == "keeper":
			how = "c †keeper b %s" % _surname(match_state.bowler_name())
		hud.show_big("CAUGHT!", Color(1.0, 0.3, 0.3))
		hud.show_shot("%s  %s" % [match_state.striker_name(), how], "%s · %d (%d)" % [pending.shot_name,
			match_state.batters[match_state.striker].runs, match_state.batters[match_state.striker].balls + 1])
		sfx.play("groan", -2.0)
		_record(0, how)
		_big_moment("OUT", "%s  %s" % [who, how], Hud.RED, Umpire.Sig.OUT, 0.9)
		return
	super._score_hit()
	if r != null and not r.boundary and r.fielder >= 0:
		hud.show_shot(pending.shot_name, "Fielded by %s  ·  %d m" % [r.fielder_name, int(round(r.distance))])
		# Leave time to see the pick-up and the throw come in.
		var wait := maxf(0.0, _take_at - ball.time)
		var throw := Vector2(r.field_pos.x, r.field_pos.z).length() / Fielding.THROW_SPEED if _throws else 0.0
		timer = clampf(wait + HOLD_BEFORE_THROW + throw + 0.5, 1.6, 3.4)
	_record(summary.runs, "")
	if summary.boundary:
		_big_moment("SIX" if summary.six else "FOUR", "%s  ·  %s  ·  %d m" % [who, pending.shot_name, int(round(summary.distance))],
			Hud.GOLD if summary.six else Hud.BLUE, Umpire.Sig.SIX if summary.six else Umpire.Sig.FOUR, 0.55)

func _bowled() -> void:
	if _replaying:
		stadium.batter_stumps.shatter(ball.pos.x, ball.vel.length())
		fx.burst(Vector3(ball.pos.x, 0.45, 0.0))
		sfx.play("stumps")
		ball.vel = Vector3(ball.vel.x * 0.2, 1.5, ball.vel.z * 0.15)
		state = State.DEAD
		timer = 99.0
		return
	_bowled_at = ball.time
	var who := _surname(match_state.striker_name())
	super._bowled()
	var how := "b %s" % _surname(match_state.bowler_name())
	hud.show_shot("%s  %s" % [match_state.striker_name(), how], "%d (%d)" % [match_state.batters[match_state.striker].runs,
		match_state.batters[match_state.striker].balls + 1])
	_record(0, how)
	_big_moment("OUT", "%s  %s" % [who, how], Hud.RED, Umpire.Sig.OUT, 0.8)

func _passed() -> void:
	if _replaying:
		_end_replay()
		return
	super._passed()
	_keeper_takes()
	_record(0, "")

## A ball the batter missed or left carries through to the keeper's gloves.
func _keeper_takes() -> void:
	var keeper := fielders[0]
	var kz := field[0].pos.z
	var s := BallPhysics.state_at_z(ball, kz - Fielder.CATCH_REACH)
	if s == null or s.pos.y > 2.4 or absf(s.pos.x - field[0].pos.x) > 4.0:
		return
	_taker = keeper
	_take_at = s.time
	_throws = false
	keeper.go(s.pos, s.time - ball.time, true, s.pos.y, Vector3(0, 0, 1))

func _surname(n: String) -> String:
	var parts := n.split(" ")
	return parts[parts.size() - 1]

func _record(scored: int, how_out: String) -> void:
	_dead_for = 0.0
	var before_over := match_state.over_index()
	var hitter := match_state.striker
	var had: int = match_state.batters[hitter].runs
	var out_line := match_state.batter_line(hitter)
	var ev := match_state.record(scored, how_out)
	_queue_scenes(ev, hitter, had, how_out, out_line)
	if autoplay:
		print("%s  %d/%d  %s" % [match_state.overs_text(), match_state.runs, match_state.wickets, how_out if how_out != "" else str(scored)])
	runs = match_state.runs
	wickets = match_state.wickets
	_save()
	if ev.finished:
		_refresh_hud()
		timer = maxf(timer, 2.2)
		return
	if ev.over_end:
		var m := match_state
		phase = Phase.OVER_BREAK
		timer = maxf(timer, 1.2) + 0.8
		hud.set_delivery("End of over %d" % m.over_index())
	_refresh_hud()

func _queue_scenes(ev: Dictionary, hitter: int, had: int, how_out: String, out_line: String) -> void:
	var m := match_state
	var b: Dictionary = m.batters[hitter]
	for mark in [50, 100]:
		if had < mark and int(b.runs) >= mark:
			_scenes.append({"kind": "milestone", "who": hitter, "mark": mark})
	if ev.finished:
		_scenes.append({"kind": "win" if m.won() else "red_win"})
	elif ev.wicket:
		_scenes.append({"kind": "wicket", "out": hitter, "how": how_out, "line": out_line, "in": m.striker})

func _scene_length(kind: String) -> float:
	return {"openers": 3.6, "wicket": 4.8, "milestone": 3.0, "win": 3.2, "red_win": 3.0}.get(kind, 3.0)

func _start_scene(sc: Dictionary) -> void:
	if autoplay:
		print("scene %s at frame %d" % [sc.kind, _shot_index])
	_scene = sc
	_scene.t = 0.0
	_scene.dur = _scene_length(sc.kind)
	phase = Phase.PLAY
	state = State.DEAD
	timer = 999.0
	hud.hide_card()
	hud.clear_result()
	hud.set_delivery("")
	hud.show_tap_prompt(false)
	ball_node.visible = false
	blob.visible = false
	marker.visible = false
	_trail_pos.clear()
	_reset_fielders()
	stadium.batter_stumps.reset()
	var m := match_state
	match str(sc.kind):
		"openers":
			batter.visible = false
			non_striker.visible = false
			_shirt(walker_out.figure, str(m.batters[0].name))
			_shirt(walker_in.figure, str(m.batters[1].name))
			walker_out.walk(Vector3(-10.5, 0, 5.0), Vector3(-1.2, 0, -0.6), 3.4)
			walker_in.walk(Vector3(-11.2, 0, 4.0), Vector3(-1.9, 0, -1.6), 3.4)
			walker_out.glum = false
			hud.show_banner("BLUE OPENERS", "%s  &  %s  ·  chasing %d" % [m.batters[0].name, m.batters[1].name, m.target], Hud.BLUE)
		"wicket":
			batter.visible = false
			_shirt(walker_out.figure, str(m.batters[sc.out].name))
			_shirt(walker_in.figure, str(m.batters[sc.in].name))
			walker_out.visible = false
			walker_in.visible = false
			_huddle()
			sfx.play("cheer", -8.0)
			hud.show_banner("OUT", "%s  ·  %s" % [sc.line, sc.how], Hud.RED)
		"milestone":
			var b: Dictionary = m.batters[sc.who]
			_shirt(batter.figure, str(b.name))
			batter.celebrate("milestone")
			stadium.crowd_material.set_shader_parameter("excite", 1.0)
			sfx.play("cheer", -3.0)
			hud.show_banner("FIFTY" if sc.mark == 50 else "HUNDRED", "%s  %d (%d)  ·  %d fours  ·  %d sixes" % [
				b.name, b.runs, b.balls, b.fours, b.sixes], Hud.GOLD)
		"win":
			batter.celebrate("win")
			stadium.crowd_material.set_shader_parameter("excite", 1.0)
			sfx.play("cheer")
			hud.show_banner("BLUE WIN", m.result_text().substr(m.result_text().find(" by ") + 1).capitalize(), Hud.BLUE)
		"red_win":
			_huddle()
			sfx.play("groan")
			var tied := m.runs == m.target - 1
			hud.show_banner("TIED" if tied else "RED WIN", "" if tied else m.result_text().substr(m.result_text().find(" by ") + 1), Hud.RED)

## Fielders within reach run in to the bowler and jump; the rest celebrate where they are.
func _huddle() -> void:
	var centre := bowler.to_global(bowler.finish_point())
	centre.y = 0.0
	bowler.celebrate()
	var near := []
	for i in fielders.size():
		if not fielders[i].visible:
			continue
		var d := Vector2(field[i].pos.x - centre.x, field[i].pos.z - centre.z).length()
		if d < 26.0:
			near.append(i)
		else:
			fielders[i].celebrate(field[i].pos, 0.0, centre)
	for k in near.size():
		var i: int = near[k]
		var a := TAU * float(k) / maxf(near.size(), 1) + 0.4
		var at := centre + Vector3(cos(a), 0, sin(a)) * 1.9
		var d := Vector2(field[i].pos.x - at.x, field[i].pos.z - at.z).length()
		fielders[i].celebrate(at, d / 7.0, centre)

func _run_scene(delta: float) -> void:
	_scene.t += delta
	var t: float = _scene.t
	if str(_scene.kind) == "wicket" and t >= 2.0 and not _scene.get("walking", false):
		# Second shot: the walk off and the new batter coming in.
		_scene.walking = true
		walker_out.walk(Vector3(-0.4, 0, -0.9), Vector3(-9.5, 0, 3.6), 2.8, 0.0, true)
		walker_in.walk(Vector3(-10.5, 0, 1.8), Vector3(-1.2, 0, -0.8), 2.8, 0.0)
		var m := match_state
		var sk := MatchState.skill_of(_scene.in)
		hud.show_banner("IN: %s" % m.batters[_scene.in].name, "%s  ·  POWER %d/5  ·  TIMING %d/5" % [
			sk.role.to_upper(), BatterSkill.pips(sk.power), BatterSkill.pips(sk.timing)], Hud.BLUE)
	if t >= float(_scene.dur):
		_end_scene()

func _end_scene() -> void:
	if _scene.is_empty():
		return
	_scene = {}
	walker_out.visible = false
	walker_in.visible = false
	batter.visible = true
	non_striker.visible = true
	bowler.celebrating = false
	bowler.pose_at(-bowler.run_time())
	batter.reset()
	_refresh_hud()
	_reset_fielders()
	hud.hide_banner()
	stadium.crowd_material.set_shader_parameter("excite", 0.0)
	state = State.DEAD
	timer = 0.02
	_dead_for = 0.0

func _scene_camera() -> void:
	var t: float = _scene.t
	var from := Vector3.ZERO
	var look := Vector3.ZERO
	var fov := 40.0
	match str(_scene.kind):
		"openers":
			var mid := (walker_out.position + walker_in.position) * 0.5
			from = mid + Vector3(3.2, 2.0, -7.2)
			look = mid + Vector3(0, 1.0, 0)
		"wicket":
			if t < 2.0:
				var c := bowler.to_global(bowler.finish_point())
				from = c + Vector3(-6.5, 2.6, 5.5)
				look = c + Vector3(0, 1.0, 0)
			else:
				# In front of the new batter as they walk in; the one who is out passes by.
				var p := walker_in.position
				var dir := (Vector3(-1.2, 0, -0.8) - Vector3(-10.5, 0, 1.8)).normalized()
				from = p + dir * 5.0 + Vector3(0, 1.7, 0) + Vector3(-dir.z, 0, dir.x) * 1.4
				look = p + Vector3(0, 1.05, 0)
		"red_win":
			var c := bowler.to_global(bowler.finish_point())
			from = c + Vector3(-6.5, 2.6, 5.5)
			look = c + Vector3(0, 1.0, 0)
		_:
			# Front-on to the batter, from the off side.
			from = Vector3(2.4, 1.6, -3.3)
			look = Vector3(-0.36, 1.35, -0.93)
			fov = 42.0
	cam.fov = fov
	cam.position = from
	cam.look_at(look)

func _style_name(s: String) -> String:
	return {"swing": "swing", "pace": "pace", "off": "off spin", "leg": "leg spin"}.get(s, s)

func _show_result() -> void:
	state = State.SUMMARY
	phase = Phase.RESULT
	timer = 0.0
	var m := match_state
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var won := m.won()
	sfx.play("cheer" if won else "groan")
	stadium.crowd_material.set_shader_parameter("excite", 1.0 if won else 0.0)
	hud.set_delivery("")
	var tied := m.runs == m.target - 1
	var text := m.result_text()
	var by := text.find(" by ")
	hud.show_card({"kicker": "MATCH RESULT", "title": "YOU WIN!" if won else ("TIED!" if tied else "RED WIN"),
		"sub": "" if tied else ("Blue win" + text.substr(by) if won else text.substr(by + 1)),
		"accent": Hud.GOLD if won else (Hud.TEXT if tied else Hud.RED),
		"rows": [["BLUE", "%d/%d  (%s ov)" % [m.runs, m.wickets, m.overs_text()], Hud.BLUE],
			["RED", "%d/%d  (20 ov)" % [m.red_total, m.red_wickets], Hud.RED],
			["Top scorer", m.top_blue()], ["Best bowler", m.best_bowler()]],
		"prompt": "Tap for a new match"})

func _on_swipe_started() -> void:
	hud.trail_begin()
	match phase:
		Phase.INTRO:
			if timer > 0.4:
				hud.hide_card()
				_next_ball()
			return
		Phase.RESULT:
			if timer > 1.2:
				match_state = null
				_new_session()
			return
	if not _scene.is_empty():
		if _scene.t > 0.4:
			_end_scene()
		return
	if state == State.READY and phase != Phase.RESULT:
		if _ready_t > 0.3:
			_bowl()
		return
	# Tap to skip the replay, or the wait (and any replay) after a ball.
	if _replaying:
		_end_replay()
		return
	if state == State.DEAD and _dead_for > 0.6:
		_replay_pending = false
		_event_t = -1.0
		_cut = false
		hud.wipe_cancel()
		timer = minf(timer, 0.05)

func _process(delta: float) -> void:
	super._process(delta)
	if not _scene.is_empty():
		_run_scene(minf(delta, 0.05))
	if state == State.READY:
		_ready_t += delta
		var wait := AUTO_WAIT_CARD if hud._field_card.visible else AUTO_WAIT
		if (autoplay and _ready_t > 0.7) or (auto_bowl and _ready_t > wait):
			_bowl()
	if state == State.DEAD:
		_dead_for += delta
	if _held:
		_held_for += minf(delta, 0.05)
	# The non-striker backs up as the bowler lets go.
	var backing := 0.0
	if state == State.RUNUP:
		backing = smoothstep(-0.45, 0.25, bowler.t)
	elif state == State.FLIGHT or state == State.HIT:
		backing = 1.0
	non_striker.back_up(lerpf(non_striker._backing, backing, 1.0 - exp(-delta * 6.0)))
	if _event_t >= 0.0 and state == State.DEAD and not _replaying:
		_event_t += delta
		if not _cut and _event_t >= _event.lead:
			_cut = true
			umpire.give(_event.sig)
		if not _wiped and _event_t >= _event.lead + SIGNAL_TIME:
			_wiped = true
			hud.wipe(_event.text, _event.sub, _event.color)
	if _replaying:
		if not _replay_swung and clock >= _swing_clock:
			_replay_swung = true
			batter.swing(_swing_where, _swing_angle, _swing_style)
		time_scale_base = 0.3 if clock < _replay_ref + 0.22 else 0.7
		if clock >= _replay_end:
			_end_replay()
	if state == State.RUNUP and bowler.t > -0.6:
		for f in fielders:
			if f.visible:
				f.ready_up()
	if autoplay and state == State.SUMMARY:
		if phase == Phase.INTRO and timer > 1.5:
			_next_ball()
		elif phase == Phase.RESULT and timer > 4.0:
			match_state = null
			_new_session()

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(match_state.to_dict()))

func _load() -> bool:
	if autoplay or not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var d: Variant = JSON.parse_string(txt)
	if not d is Dictionary:
		return false
	match_state = MatchState.from_dict(d)
	return not match_state.finished()

static func has_saved_match() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
