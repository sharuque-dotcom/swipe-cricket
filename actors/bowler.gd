class_name Bowler
extends Node3D
## Right-arm bowler. Local -Z is the direction of travel; `t` is seconds relative to release.

const RUN_TIME := 2.1
const GATHER := 0.42
const RUN_SPEED := 4.6

var figure: Figure
var t := -99.0
var active := false
var slow := false          # spinners amble in

func build(kit: Color, trim: Color) -> void:
	figure = Figure.new()
	figure.kit = kit
	figure.trim = trim
	add_child(figure)
	figure.build()
	pose_at(-RUN_TIME)

func start(spinner: bool) -> void:
	slow = spinner
	t = -run_time()
	active = true

func run_time() -> float:
	return 1.5 if slow else RUN_TIME

func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	pose_at(t)
	if t > 1.4:
		active = false

static func _key(x: float, keys: Array) -> float:
	if x <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if x <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], smoothstep(0.0, 1.0, (x - a[0]) / (b[0] - a[0])))
	return keys[keys.size() - 1][1]

func pose_at(time: float) -> void:
	var speed := RUN_SPEED * (0.62 if slow else 1.0)
	var p := Figure.Pose.new()
	# Distance behind the release stride.
	var z: float
	if time < -GATHER:
		z = 1.55 + (-GATHER - time) * speed
	elif time < 0.0:
		z = _key(time, [[-GATHER, 1.55], [0.0, 0.30]])
	else:
		z = 0.30 - 2.4 * (1.0 - exp(-time * 2.2))
	var x := 0.0 if time < 0.0 else 0.5 * (1.0 - exp(-time * 2.0))
	var run := 1.0 - smoothstep(-GATHER, -GATHER + 0.12, time) + smoothstep(0.12, 0.3, time)
	run = clampf(run, 0.0, 1.0)
	var ph := time * (9.5 if slow else 13.0)
	var s := sin(ph)
	var c := cos(ph)
	p.hips = Vector3(x, 0.93 + 0.04 * absf(c) * run, z)
	p.lean = 0.22 * run
	p.foot_l = Vector3(x - 0.11, maxf(0.0, c) * 0.22, z + 0.42 * s) 
	p.foot_r = Vector3(x + 0.11, maxf(0.0, -c) * 0.22, z - 0.42 * s)
	p.hand_l = Vector3(x - 0.27, 1.05 - 0.12 * s, z - 0.30 * s - 0.05)
	p.hand_r = Vector3(x + 0.27, 1.05 + 0.12 * s, z + 0.30 * s - 0.05)
	if run < 1.0:
		var d := Figure.Pose.new()
		var jump := _key(time, [[-GATHER, 0.0], [-0.30, 0.16], [-0.17, 0.02], [0.0, 0.07], [0.2, 0.0]])
		d.hips = Vector3(x, 0.93 + jump, z)
		# Side-on in the gather, front-on by release.
		d.chest_yaw = _key(time, [[-GATHER, 0.0], [-0.22, deg_to_rad(-75.0)], [0.0, deg_to_rad(-5.0)], [0.25, deg_to_rad(50.0)]])
		d.hip_yaw = d.chest_yaw * 0.6
		d.lean = _key(time, [[-GATHER, 0.1], [-0.2, -0.12], [0.0, 0.2], [0.25, 0.75]])
		d.side_lean = _key(time, [[-0.2, 0.0], [0.0, 0.16], [0.25, 0.0]])
		d.foot_r = Vector3(x + 0.08, _key(time, [[-GATHER, 0.0], [-0.30, 0.25], [-0.20, 0.0], [0.02, 0.0], [0.16, 0.35], [0.32, 0.0]]),
			_key(time, [[-GATHER, 1.75], [-0.20, 0.95], [0.02, 0.95], [0.32, -1.25]]))
		d.foot_l = Vector3(x - 0.10, _key(time, [[-GATHER, 0.0], [-0.22, 0.4], [-0.05, 0.0], [0.3, 0.0]]),
			_key(time, [[-GATHER, 1.2], [-0.05, -0.35], [0.5, -0.35 - 0.2]]))
		# Bowling arm travels a full circle, vertical at release.
		var alpha := deg_to_rad(_key(time, [[-GATHER, 300.0], [-0.2, 225.0], [0.0, 90.0], [0.16, -40.0], [0.3, -75.0]]))
		var basis := Basis(Vector3.UP, d.chest_yaw) * Basis(Vector3.RIGHT, -d.lean)
		var sh_r := d.hips + basis.y * 0.45 + basis.x * 0.2
		var reach := 0.57
		d.hand_r = sh_r + (Vector3(0.06, sin(alpha), cos(alpha) * -1.0) * reach).rotated(Vector3.UP, d.chest_yaw * 0.3)
		var sh_l := d.hips + basis.y * 0.45 - basis.x * 0.2
		var front := deg_to_rad(_key(time, [[-GATHER, -60.0], [-0.24, 70.0], [-0.08, 40.0], [0.05, -80.0], [0.3, -110.0]]))
		d.hand_l = sh_l + Vector3(-0.05, sin(front), -cos(front)) * 0.5
		p = d.blend(p, run)
	figure.apply(p)
