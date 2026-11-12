extends Node3D
## Nets: a bowling machine, one batter, and an honest read-out of every ball.

enum State { READY, RUNUP, FLIGHT, HIT, DEAD, SUMMARY }

const BALLS := 12
const BALL_VISUAL_SCALE := 1.55
const BALL_MIN_ANGLE := 0.0065   # never let the ball shrink below this angular size
const TRAIL := 16
const CAM_HOME := Vector3(0.0, 2.25, 4.9)
const CAM_LOOK := Vector3(0.0, 1.05, -9.0)
const CAM_FOV := 44.0

var state := State.READY
var machine: BowlingMachine
var stadium: Stadium
var batter: Batter
var bowler: Bowler
var hud: Hud
var sfx: Sfx
var swipe: SwipeRecognizer
var cam: Camera3D
var ball_node: MeshInstance3D
var blob: MeshInstance3D
var marker: MeshInstance3D

var delivery: Delivery
var launch: BallPhysics.State
var ball: BallPhysics.State
var clock := 0.0
var frame_usec := 0
var pending: ShotResolver.Result
var swung := false
var summary: NetsScoring.Summary
var timer := 0.0
var hit_clock := 0.0
var runs := 0
var wickets := 0
var ball_no := 0
var best := 0
var _cam_pos := CAM_HOME
var _cam_look := CAM_LOOK
var _cam_pos_to := CAM_HOME
var _look_to := CAM_LOOK
var _fov_to := CAM_FOV
var _shake := 0.0
var _last_bounces := 0
var _trail: Array[MeshInstance3D] = []
var _trail_pos: Array[Vector3] = []
var _trail_tick := 0.0
var _cam_locked := false

# Test hooks: --autoplay swings by itself, --shots=DIR saves frames.
var autoplay := false
var shots_dir := ""
var shot_dt := 0.2
var _shot_timer := 0.0
var _shot_index := 0
var _bot_rng := RandomNumberGenerator.new()
var _bot_at := -1.0
var _bot_shot := {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).contains("autoplay"):
			autoplay = true
	for a in args:
		if a == "--autoplay":
			autoplay = true
		elif a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--shot-dt="):
			shot_dt = float(a.trim_prefix("--shot-dt="))
		elif a.begins_with("--cam="):
			# --cam=px,py,pz,lx,ly,lz pins the camera for inspection.
			var v := a.trim_prefix("--cam=").split_floats(",")
			_cam_locked = true
			_cam_pos = Vector3(v[0], v[1], v[2])
			_cam_look = Vector3(v[3], v[4], v[5])
	_bot_rng.seed = 5

	stadium = Stadium.new()
	add_child(stadium)
	stadium.build()
	batter = Batter.new()
	add_child(batter)
	batter.build(Color(0.10, 0.32, 0.78), Color(1.0, 0.80, 0.15))
	bowler = Bowler.new()
	bowler.rotation.y = PI
	add_child(bowler)
	bowler.build(Color(0.80, 0.14, 0.16), Color(1, 1, 1))

	ball_node = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BallPhysics.RADIUS * BALL_VISUAL_SCALE
	sm.height = sm.radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	ball_node.mesh = sm
	ball_node.material_override = Figure.mat(Color(0.78, 0.06, 0.08), 0.3)
	ball_node.visible = false
	add_child(ball_node)
	blob = _disc(0.09, Color(0, 0, 0, 0.38))
	marker = _disc(0.20, Color(1.0, 0.9, 0.2, 0.75), 0.13)

	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.near = 0.1
	cam.far = 400.0
	add_child(cam)
	cam.position = _cam_pos
	cam.look_at(_cam_look)
	for i in TRAIL:
		var t := MeshInstance3D.new()
		t.mesh = sm
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.albedo_color = Color(1.0, 0.92, 0.75, 0.55 * (1.0 - float(i) / TRAIL))
		t.material_override = tm
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		add_child(t)
		_trail.append(t)

	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	swipe = SwipeRecognizer.new()
	add_child(swipe)
	swipe.swiped.connect(_on_swiped)
	swipe.swipe_started.connect(_on_swipe_started)
	swipe.swipe_moved.connect(hud.trail_points)
	_new_session()

func _disc(radius: float, c: Color, hole: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if hole > 0.0:
		var tm := TorusMesh.new()
		tm.inner_radius = hole
		tm.outer_radius = radius
		tm.ring_segments = 4
		mi.mesh = tm
		mi.scale = Vector3(1, 0.05, 1)
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = 0.002
		cm.radial_segments = 16
		mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _new_session() -> void:
	machine = BowlingMachine.new(int(Time.get_unix_time_from_system()) if not autoplay else 11)
	runs = 0
	wickets = 0
	ball_no = 0
	hud.show_panel("")
	hud.set_hint("Swipe to play a shot\nDirection aims · Speed is power · Long swipe lofts")
	_next_ball()

func _next_ball() -> void:
	ball_no += 1
	if ball_no > BALLS:
		_finish_session()
		return
	state = State.RUNUP
	delivery = machine.next()
	launch = delivery.solve()
	ball = null
	pending = null
	swung = false
	summary = null
	_bot_at = -1.0
	ball_node.visible = false
	blob.visible = false
	_trail_pos.clear()
	for t in _trail:
		t.visible = false
	stadium.batter_stumps.reset()
	batter.reset()
	bowler.position = Vector3(delivery.release.x + 0.27, 0.0, delivery.release.z - 0.2)
	bowler.start(delivery.speed < 27.0)
	var pitch_at := BallPhysics.state_at_first_bounce(launch)
	marker.position = Vector3(pitch_at.pos.x, 0.03, pitch_at.pos.z)
	marker.visible = false
	hud.clear_result()
	hud.set_score(runs, wickets, ball_no, BALLS)
	hud.set_delivery("")
	_cam_pos_to = CAM_HOME
	_look_to = CAM_LOOK
	_fov_to = CAM_FOV
	stadium.crowd_material.set_shader_parameter("excite", 0.0)

func _finish_session() -> void:
	state = State.SUMMARY
	timer = 0.0
	best = maxi(best, runs)
	hud.set_hint("")
	hud.show_panel("SESSION OVER\n\n%d runs off %d balls\n%d wicket%s lost\nBest: %d\n\nTap to go again" % [
		runs, BALLS, wickets, "" if wickets == 1 else "s", best])

func _on_swipe_started() -> void:
	hud.trail_begin()
	if state == State.SUMMARY and timer > 0.6:
		_new_session()

func _now() -> float:
	# Ball-clock time at this instant, including the part of the frame already elapsed.
	return clock + minf((Time.get_ticks_usec() - frame_usec) / 1000000.0, 0.05)

func _on_swiped(angle: float, power: float, loft: float) -> void:
	hud.trail_end()
	if swung:
		return
	var t := 0.0
	if state == State.FLIGHT:
		t = _now()
	elif state == State.RUNUP and bowler.t > -0.3:
		t = bowler.t
	else:
		return
	_swing(angle, power, loft, t + Tuning.SWING_TIME)

func _swing(angle: float, power: float, loft: float, contact_time: float) -> void:
	swung = true
	hud.set_hint("")
	var sw := ShotResolver.Swing.new()
	sw.angle = angle
	sw.power = power
	sw.loft = loft
	sw.contact_time = contact_time
	pending = ShotResolver.resolve(launch, sw)
	var w := ShotResolver.hit_window(launch)
	var where := pending.contact_pos
	if pending.outcome == ShotResolver.Outcome.MISS:
		where = ShotResolver.state_at_time(launch, clampf(contact_time, w.t_in, w.t_out)).pos
		sfx.play("whoosh")
	batter.swing(where, angle)

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	frame_usec = Time.get_ticks_usec()
	match state:
		State.RUNUP:
			if bowler.t > -0.55:
				batter.backlift()
				marker.visible = true
			if bowler.t >= 0.0:
				_release()
		State.FLIGHT, State.HIT:
			_advance(delta)
		State.DEAD:
			if ball != null:
				_advance_ball_only(delta)
			timer -= delta
			if timer <= 0.0:
				_next_ball()
		State.SUMMARY:
			timer += delta
			if autoplay and timer > 2.5:
				_new_session()
	_update_camera(delta)
	_capture(delta)

func _release() -> void:
	state = State.FLIGHT
	ball = launch.copy()
	clock = 0.0
	_last_bounces = 0
	ball_node.visible = true
	blob.visible = true
	hud.set_delivery("%s  %d km/h" % [delivery.label, int(round(delivery.speed_kmh()))])
	if autoplay:
		var w := ShotResolver.hit_window(launch)
		var n := _bot_rng.randf_range(-0.85, 0.85) * _bot_rng.randf()
		_bot_shot = {"angle": deg_to_rad(_bot_rng.randf_range(-100.0, 100.0)), "power": _bot_rng.randf_range(0.5, 1.0),
			"loft": 1.0 if _bot_rng.randf() < 0.4 else 0.0, "t": w.t_mid + n * w.half}
		_bot_at = _bot_shot.t - Tuning.SWING_TIME

func _advance(delta: float) -> void:
	clock += delta
	if state == State.FLIGHT and _bot_at >= 0.0 and clock >= _bot_at and not swung:
		_swing(_bot_shot.angle, _bot_shot.power, _bot_shot.loft, _bot_shot.t)
	while ball.time + BallPhysics.DT <= clock:
		if state == State.FLIGHT and pending != null and pending.exit != null and ball.time + BallPhysics.DT > pending.contact_time:
			_connect()
			continue
		var prev := ball.pos
		BallPhysics.step(ball)
		if state == State.HIT:
			_trail_tick += BallPhysics.DT
			if _trail_tick >= 0.02:
				_trail_tick = 0.0
				_trail_pos.push_front(ball.pos)
				if _trail_pos.size() > TRAIL:
					_trail_pos.pop_back()
		if ball.bounces != _last_bounces:
			_last_bounces = ball.bounces
			if ball.bounces <= 3:
				sfx.play("bounce", -4.0 - 5.0 * ball.bounces)
			if state == State.FLIGHT:
				marker.visible = false
		if state == State.FLIGHT:
			if Pitch.hits_stumps(prev, ball.pos, BallPhysics.RADIUS):
				_bowled()
				return
			if ball.pos.z > 3.5:
				_passed()
				return
		elif state == State.HIT:
			if Pitch.beyond_boundary(ball.pos) or ball.at_rest or clock - hit_clock > minf(summary.end_time - pending.contact_time, 4.2):
				_score_hit()
				return
	_show_ball()

func _advance_ball_only(delta: float) -> void:
	clock += delta
	while ball.time + BallPhysics.DT <= clock:
		BallPhysics.step(ball)
	_show_ball()

func _show_ball() -> void:
	# Keep the ball readable at range: grow it so it never drops below a minimum on-screen size.
	var dist := cam.global_position.distance_to(ball.pos)
	var k := maxf(1.0, dist * BALL_MIN_ANGLE / (BallPhysics.RADIUS * BALL_VISUAL_SCALE))
	ball_node.scale = Vector3.ONE * k
	ball_node.position = ball.pos + Vector3(0, BallPhysics.RADIUS * (BALL_VISUAL_SCALE * k - 1.0), 0)
	for i in TRAIL:
		var on := i < _trail_pos.size()
		_trail[i].visible = on
		if on:
			_trail[i].position = _trail_pos[i]
			_trail[i].scale = Vector3.ONE * k * (0.85 - 0.6 * float(i) / TRAIL)
	blob.position = Vector3(ball.pos.x, 0.025, ball.pos.z)
	var s := clampf(1.0 - ball.pos.y / 14.0, 0.25, 1.0)
	blob.scale = Vector3(s, 1.0, s)

func _connect() -> void:
	ball = pending.exit.copy()
	state = State.HIT
	hit_clock = clock
	_last_bounces = 0
	marker.visible = false
	summary = NetsScoring.evaluate(pending.exit)
	var speed := pending.exit.vel.length()
	if pending.outcome == ShotResolver.Outcome.EDGE:
		sfx.play("edge")
	else:
		sfx.play("bat", lerpf(-8.0, 0.0, clampf(speed / 38.0, 0.0, 1.0)), lerpf(0.85, 1.1, pending.quality))
		_shake = 0.05 * clampf(speed / 40.0, 0.0, 1.0) * pending.quality
	hud.show_timing(pending.timing_n, pending.timing_label(), pending.timing_ms)
	hud.show_shot(pending.shot_name, "%d km/h off the bat" % int(round(speed * 3.6)))
	Input.vibrate_handheld(int(lerpf(15.0, 45.0, pending.quality)))
	_fov_to = 50.0

func _score_hit() -> void:
	state = State.DEAD
	timer = 1.5
	runs += summary.runs
	var detail := "%d m" % int(round(summary.distance))
	if summary.six:
		hud.show_big("SIX!", Color(1.0, 0.84, 0.2))
		sfx.play("cheer")
		stadium.crowd_material.set_shader_parameter("excite", 1.0)
		timer = 2.0
	elif summary.boundary:
		hud.show_big("FOUR!", Color(0.45, 0.9, 1.0))
		sfx.play("cheer", -5.0)
		stadium.crowd_material.set_shader_parameter("excite", 0.7)
		timer = 1.8
	elif pending.outcome == ShotResolver.Outcome.EDGE:
		hud.show_big("EDGED", Color(1.0, 0.55, 0.3))
		sfx.play("groan", -4.0)
	elif summary.runs > 0:
		hud.show_big("%d RUN%s" % [summary.runs, "" if summary.runs == 1 else "S"], Color.WHITE)
	else:
		hud.show_big("DOT", Color(0.8, 0.8, 0.85))
	hud.show_shot(pending.shot_name, "%d km/h off the bat · %s" % [int(round(pending.exit.vel.length() * 3.6)), detail])
	hud.set_score(runs, wickets, ball_no, BALLS)

func _bowled() -> void:
	state = State.DEAD
	timer = 1.9
	wickets += 1
	stadium.batter_stumps.shatter(ball.pos.x, ball.vel.length())
	sfx.play("stumps")
	sfx.play("groan", -2.0)
	_shake = 0.05
	ball.vel = Vector3(ball.vel.x * 0.2, 1.5, ball.vel.z * 0.15)
	hud.show_big("BOWLED!", Color(1.0, 0.3, 0.3))
	_explain_miss()
	hud.set_score(runs, wickets, ball_no, BALLS)

func _passed() -> void:
	state = State.DEAD
	timer = 1.2
	if swung:
		hud.show_big("MISSED", Color(0.85, 0.85, 0.9))
		_explain_miss()
	else:
		hud.show_big("LEFT", Color(0.85, 0.85, 0.9))
		hud.show_shot("No shot offered", "")

func _explain_miss() -> void:
	if pending == null:
		hud.show_shot("No shot offered", "")
		return
	hud.show_shot(pending.reason, "")
	if absf(pending.timing_n) < 3.0:
		hud.show_timing(pending.timing_n, pending.timing_label(), pending.timing_ms)

func _update_camera(delta: float) -> void:
	if _cam_locked:
		return
	if state == State.HIT or (state == State.DEAD and pending != null and pending.exit != null):
		_look_to = Vector3(ball.pos.x, maxf(ball.pos.y, 0.6), ball.pos.z)
		# Chase: sit behind and above the ball, trailing it toward the rope.
		var back := (Vector3(ball.pos.x, 0.0, ball.pos.z) - Vector3(pending.contact_pos.x, 0.0, pending.contact_pos.z))
		var flat := back.normalized() if back.length() > 0.5 else Vector3(0, 0, -1)
		var trail_dist := clampf(6.0 + back.length() * 0.35, 6.0, 22.0)
		_cam_pos_to = Vector3(ball.pos.x, 0.0, ball.pos.z) - flat * trail_dist + Vector3(0, 3.2 + back.length() * 0.09 + ball.pos.y * 0.5, 0)
	_cam_pos = _cam_pos.lerp(_cam_pos_to, 1.0 - exp(-delta * (2.4 if state == State.HIT else 4.0)))
	_cam_look = _cam_look.lerp(_look_to, 1.0 - exp(-delta * 9.0))
	cam.fov = lerpf(cam.fov, _fov_to, 1.0 - exp(-delta * 3.0))
	_shake = maxf(0.0, _shake - delta * 0.25)
	var jitter := Vector3(sin(clock * 91.0), cos(clock * 77.0), 0.0) * _shake
	cam.position = _cam_pos + jitter
	if cam.position.distance_squared_to(_cam_look) > 0.01:
		cam.look_at(_cam_look)

func _capture(delta: float) -> void:
	if shots_dir == "":
		return
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	_shot_timer = shot_dt
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/f%03d.png" % [shots_dir, _shot_index])
	_shot_index += 1
	if _shot_index > 70:
		get_tree().quit()
