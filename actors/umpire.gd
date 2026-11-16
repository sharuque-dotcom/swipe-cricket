class_name Umpire
extends Node3D
## The umpire at the bowler's end: stands behind the stumps and signals four, six and out.

enum Sig { NONE, FOUR, SIX, OUT }

const HOLD := 2.2    # seconds a signal is held

var figure: Figure
var _sig := Sig.NONE
var _t := 0.0

func build() -> void:
	figure = Figure.new()
	figure.kit = Color(0.13, 0.17, 0.30)
	figure.trim = Color(0.95, 0.95, 0.92)
	figure.trousers = Color(0.07, 0.07, 0.09)
	figure.skin = Color(0.80, 0.60, 0.46)
	figure.hat = true
	add_child(figure)
	figure.build()
	_pose()

func give(sig: Sig) -> void:
	_sig = sig
	_t = 0.0

func _process(delta: float) -> void:
	_t += minf(delta, 0.05)
	if _sig != Sig.NONE and _t > HOLD:
		_sig = Sig.NONE
		_t = 0.0
	_pose()

func _pose() -> void:
	var p := Figure.Pose.new()
	var rest_l := Vector3(-0.24, 0.90, 0.04)
	var rest_r := Vector3(0.24, 0.90, 0.04)
	p.hand_l = rest_l
	p.hand_r = rest_r
	p.hips.y = 0.93 + 0.006 * sin(_t * 1.7)
	var k := smoothstep(0.0, 0.28, _t) * (1.0 - smoothstep(HOLD - 0.3, HOLD, _t))
	match _sig:
		Sig.FOUR:
			# Arm out at chest height, swept across the body and back.
			var sweep := sin(_t * 7.5)
			p.hand_r = rest_r.lerp(Vector3(0.10 + 0.42 * sweep, 1.36, -0.46), k)
			p.chest_yaw = 0.18 * sweep * k
		Sig.SIX:
			# Both arms straight up.
			p.hand_l = rest_l.lerp(Vector3(-0.20, 2.02, -0.04), k)
			p.hand_r = rest_r.lerp(Vector3(0.20, 2.02, -0.04), k)
			p.lean = -0.06 * k
		Sig.OUT:
			# The finger goes up, slowly.
			var slow := smoothstep(0.0, 0.55, _t) * (1.0 - smoothstep(HOLD - 0.3, HOLD, _t))
			p.hand_r = rest_r.lerp(Vector3(0.16, 2.0, -0.16), slow)
			p.head_yaw = 0.0
	figure.apply(p)
