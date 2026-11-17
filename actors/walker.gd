class_name Walker
extends Node3D
## A batter walking to or from the crease, bat in the right hand.

var figure: Figure
var bat: Bat
var glum := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dur := 1.0
var _delay := 0.0
var _t := 0.0

func build(kit: Color, trim: Color) -> void:
	figure = Figure.new()
	figure.kit = kit
	figure.trim = trim
	figure.pads = true
	figure.helmet = true
	add_child(figure)
	figure.build()
	bat = Bat.new()
	add_child(bat)
	bat.build()
	_pose(0.0, false)

## Walk from `from` to `to` over `seconds`, starting after `delay`.
func walk(from: Vector3, to: Vector3, seconds: float, delay: float = 0.0, head_down: bool = false) -> void:
	_from = from
	_to = to
	_dur = maxf(seconds, 0.1)
	_delay = delay
	_t = 0.0
	glum = head_down
	position = from
	var d := to - from
	if d.length() > 0.1:
		rotation.y = atan2(-d.x, -d.z)
	visible = true
	_pose(0.0, false)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += minf(delta, 0.05)
	var u := clampf((_t - _delay) / _dur, 0.0, 1.0)
	position = _from.lerp(_to, u)
	_pose(_t, u > 0.0 and u < 1.0)

func _pose(time: float, moving: bool) -> void:
	var p := Figure.Pose.new()
	var ph := time * (7.0 if glum else 8.5)
	var s := sin(ph) if moving else 0.0
	var c := cos(ph) if moving else 0.0
	p.hips = Vector3(0, 0.93 + 0.025 * absf(c), 0)
	p.lean = 0.22 if glum else 0.06
	p.foot_l = Vector3(-0.11, maxf(0.0, c) * 0.12, 0.30 * s)
	p.foot_r = Vector3(0.11, maxf(0.0, -c) * 0.12, -0.30 * s)
	# Bat carried in the right hand, toe forward and down; left arm swings.
	var grip := Vector3(0.24, 0.86, -0.06 - 0.10 * s)
	bat.place(grip, Vector3(0.05, -0.75, -0.65).normalized(), Vector3(1, 0, 0))
	p.hand_r = grip
	p.hand_l = Vector3(-0.25, 0.92, 0.18 * s)
	figure.apply(p)
