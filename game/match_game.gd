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
	hud.set_hint("")
	hud.clear_result()
	_set_field()
	_refresh_hud()
	if resumed:
		hud.show_panel("MATCH RESUMED\n\nBLUE %d/%d  (%s ov)\nNeed %d off %d\n\nTap to carry on" % [
			match_state.runs, match_state.wickets, match_state.overs_text(), match_state.need(), match_state.balls_left()])
	else:
		hud.show_panel("BLUE v RED  ·  20 OVERS\n\nRED  %d/%d\nTop score: %s\n\nTarget %d off 120 balls\n\nTap to start the chase" % [
			match_state.red_total, match_state.red_wickets, match_state.red_top, match_state.target])

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

func _next_ball() -> void:
	if match_state.finished():
		_show_result()
		return
	phase = Phase.PLAY
	hud.show_panel("")
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
	var m := match_state
	hud.set_match_score("BLUE  v  RED", "%d/%d" % [m.runs, m.wickets], "%s OV" % m.overs_text())
	var bi := m.bowler_index()
	var bat := "%s*  %d (%d)    %s  %d (%d)" % [m.batters[m.striker].name, m.batters[m.striker].runs, m.batters[m.striker].balls,
		m.batters[m.non_striker].name, m.batters[m.non_striker].runs, m.batters[m.non_striker].balls]
	var need := "" if m.finished() else "Need %d off %d  ·  RRR %.1f" % [m.need(), m.balls_left(), m.required_rate()]
	hud.set_match_info(bat, "%s  %s" % [MatchState.BOWLERS[bi][0], m.bowler_figures(bi)], need, "  ".join(m.this_over))

func _evaluate_hit(exit: BallPhysics.State) -> NetsScoring.Summary:
	var r := Fielding.evaluate(exit, field)
	# Send the fielder: they arrive as the ball does.
	if r.fielder >= 0 and r.fielder < fielders.size() and fielders[r.fielder].visible:
		fielders[r.fielder].go(r.field_pos, r.field_time, r.caught)
	return r

func _score_hit() -> void:
	var r := summary as Fielding.Result
	state = State.DEAD
	timer = 1.6
	if r != null and r.caught:
		ball.at_rest = true
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
		hud.show_shot(pending.shot_name, "Fielded at %s" % r.fielder_name)
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
	_record(0, "")

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
		hud.set_delivery("In: %s" % ev.new_batter)
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
	hud.show_big("YOU WIN!" if won else ("TIED!" if m.runs == m.target - 1 else "RED WIN"), Color(0.4, 0.85, 1.0) if won else Color(1.0, 0.35, 0.35))
	sfx.play("cheer" if won else "groan")
	stadium.crowd_material.set_shader_parameter("excite", 1.0 if won else 0.0)
	hud.show_panel("%s\n\nBLUE %d/%d (%s ov)\nRED %d/%d (20 ov)\n\nTop scorer: %s\nBest bowler: %s\n\nTap for a new match" % [
		m.result_text(), m.runs, m.wickets, m.overs_text(), m.red_total, m.red_wickets, m.top_blue(), m.best_bowler()])

func _on_swipe_started() -> void:
	hud.trail_begin()
	match phase:
		Phase.INTRO:
			if timer > 0.4:
				hud.show_panel("")
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
