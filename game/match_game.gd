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

func _new_session() -> void:
	if fielders.is_empty():
		_build_fielders()
	machine = BowlingMachine.new(1)
	var resumed := _load()
	if not resumed:
		var sd := int(Time.get_unix_time_from_system()) if not autoplay else 21
		match_state = MatchState.create(sd)
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
			"rows": [["RED made", "%d/%d" % [m.red_total, m.red_wickets], Hud.RED], ["Their top score", m.red_top],
				["Required rate", "%.1f" % m.required_rate()]],
			"notes": ["Time it in the green to clear the rope.\nYour bowlers can't hit like your openers."],
			"prompt": "Tap to start the chase"})

func _build_fielders() -> void:
	for i in 11:
		var f := Fielder.new()
		add_child(f)
		f.build(RED_KIT, Color(1, 1, 1), i == 0)
		fielders.append(f)

## Spinners get a keeper up at the stumps and a long-on instead of a slip.
func _set_field() -> void:
	_spinner_field = match_state.bowler_style() == "off" or match_state.bowler_style() == "leg"
	field = Fielding.layout(_spinner_field, match_state.over_index() < 6)
	for i in fielders.size():
		var f := fielders[i]
		# The last spot is the bowler, who is already on the pitch.
		var used := i < field.size() - 1
		f.visible = used
		if used:
			f.reset(field[i].pos)
	hud.radar_field(field)

func _batter_skill() -> BatterSkill:
	return match_state.striker_skill()

func _next_ball() -> void:
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
	var d := machine.next_for(match_state.bowler_style(), match_state.over_index())
	match_state.machine_state = machine.state
	_start_delivery(d)
	for i in fielders.size():
		if fielders[i].visible:
			fielders[i].reset(field[i].pos)
	_refresh_hud()

func _refresh_hud() -> void:
	hud.set_match(match_state)

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

func _score_hit() -> void:
	var r := summary as Fielding.Result
	state = State.DEAD
	timer = 1.6
	if r != null and r.caught:
		var how := ("c %s b %s" % [r.fielder_name, _surname(match_state.bowler_name())]) if r.fielder_name != "bowler" \
			else "c & b %s" % _surname(match_state.bowler_name())
		if r.fielder_name == "keeper":
			how = "c †keeper b %s" % _surname(match_state.bowler_name())
		hud.show_big("CAUGHT!", Color(1.0, 0.3, 0.3))
		hud.show_shot("%s  %s" % [match_state.striker_name(), how], "%s · %d (%d)" % [pending.shot_name,
			match_state.batters[match_state.striker].runs, match_state.batters[match_state.striker].balls + 1])
		sfx.play("groan", -2.0)
		timer = 2.4
		_record(0, how)
		return
	super._score_hit()
	if r != null and not r.boundary and r.fielder >= 0:
		hud.show_shot(pending.shot_name, "Fielded by %s  ·  %d m" % [r.fielder_name, int(round(r.distance))])
		# Leave time to see the pick-up and the throw come in.
		var wait := maxf(0.0, _take_at - ball.time)
		var throw := Vector2(r.field_pos.x, r.field_pos.z).length() / Fielding.THROW_SPEED if _throws else 0.0
		timer = clampf(wait + HOLD_BEFORE_THROW + throw + 0.5, 1.6, 3.4)
	_record(summary.runs, "")

func _bowled() -> void:
	super._bowled()
	timer = 2.4
	var how := "b %s" % _surname(match_state.bowler_name())
	hud.show_shot("%s  %s" % [match_state.striker_name(), how], "%d (%d)" % [match_state.batters[match_state.striker].runs,
		match_state.batters[match_state.striker].balls + 1])
	_record(0, how)

func _passed() -> void:
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
	var ev := match_state.record(scored, how_out)
	if autoplay:
		print("%s  %d/%d  %s" % [match_state.overs_text(), match_state.runs, match_state.wickets, how_out if how_out != "" else str(scored)])
	runs = match_state.runs
	wickets = match_state.wickets
	_save()
	if ev.wicket and ev.new_batter != "":
		hud.set_delivery("NEW BATTER  ·  %s  ·  %s" % [ev.new_batter, match_state.striker_skill().role])
	if ev.finished:
		_refresh_hud()
		timer = maxf(timer, 2.2)
		return
	if ev.over_end:
		var m := match_state
		phase = Phase.OVER_BREAK
		timer = maxf(timer, 1.2) + 1.6
		_set_field_after(before_over)
		hud.set_delivery("End of over %d" % m.over_index())
	_refresh_hud()

## The new bowler's field goes in once the ball is dead.
func _set_field_after(_over: int) -> void:
	var t := get_tree().create_timer(maxf(timer - 1.4, 0.3))
	t.timeout.connect(func():
		if is_inside_tree() and match_state != null and not match_state.finished():
			_set_field()
			hud.set_delivery("%s to bowl  ·  %s" % [match_state.bowler_name(), _style_name(match_state.bowler_style())]))

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
	# Tap to skip the wait after a ball.
	if state == State.DEAD and _dead_for > 0.6:
		timer = minf(timer, 0.05)

func _process(delta: float) -> void:
	super._process(delta)
	if state == State.DEAD:
		_dead_for += delta
	if _held:
		_held_for += minf(delta, 0.05)
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
