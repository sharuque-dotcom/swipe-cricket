class_name NonStriker
extends Node3D
## The batter at the bowler's end, leaning on their bat and backing up as the ball is bowled.

var figure: Figure
var bat: Bat
var _t := 0.0
var _backing := 0.0

func build(kit: Color, trim: Color) -> void:
	figure = Figure.new()
	figure.kit = kit
	figure.trim = trim
	figure.pads = true
	figure.helmet = true
	figure.helmet_colour = Locker.helmet_colour()
	add_child(figure)
	figure.build()
	bat = Bat.new()
	add_child(bat)
	bat.build()
	_pose()

## 0 = standing in the crease, 1 = a couple of strides down the pitch.
func back_up(amount: float) -> void:
	_backing = clampf(amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	_pose()

func _pose() -> void:
	var p := Figure.Pose.new()
	var z := -1.3 * _backing
	p.hips = Vector3(0, 0.92 + 0.008 * sin(_t * 2.0), z)
	p.lean = 0.10 + 0.15 * _backing
	p.foot_l = Vector3(-0.12, 0, z + 0.05)
	p.foot_r = Vector3(0.12, 0, z - 0.18 * _backing)
	var grip := Vector3(0.30, 0.74, z - 0.10)
	bat.place(grip, Vector3(0.04, -1.0, 0.05).normalized(), Vector3(0, 0, -1))
	p.hand_r = grip
	p.hand_l = Vector3(-0.24, 0.92, z + 0.02)
	figure.apply(p)
