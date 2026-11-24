class_name Umpire
extends Node3D
## The umpire at the bowler's end: stands behind the stumps and signals four, six and out.

enum Sig { NONE, FOUR, SIX, OUT, WIDE, NO_BALL, FREE_HIT }

const HOLD := 2.2    # seconds a signal is held

var figure: Body
var _sig := Sig.NONE
var _t := 0.0

func build() -> void:
	figure = Body.new()
	figure.kit = Color(0.13, 0.17, 0.30)
	figure.trim = Color(0.95, 0.95, 0.92)
	figure.trousers = Color(0.07, 0.07, 0.09)
	figure.skin = Color(0.80, 0.60, 0.46)
	figure.gear = "hat"
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
	var rest_l := Vector3(-0.24, 0.90, 0.04)
	var rest_r := Vector3(0.24, 0.90, 0.04)
	var k := smoothstep(0.0, 0.28, _t) * (1.0 - smoothstep(HOLD - 0.3, HOLD, _t))
	match _sig:
		Sig.FOUR:
			# Arm out at chest height, swept across the body and back.
			var sweep := sin(_t * 7.5)
			figure.play("idle")
			figure.reach(Vector3(-0.3, 1.0, 0.0), Vector3(0.10 + 0.42 * sweep, 1.36, -0.46), k)
		Sig.SIX:
			# Both arms straight up.
			figure.play("idle")
			figure.reach(Vector3(-0.20, 2.02, -0.04), Vector3(0.20, 2.02, -0.04), k)
		Sig.OUT:
			# The finger goes up, slowly.
			var slow := smoothstep(0.0, 0.55, _t) * (1.0 - smoothstep(HOLD - 0.3, HOLD, _t))
			figure.play("idle")
			figure.reach(rest_l, Vector3(0.16, 2.0, -0.16), slow)
		Sig.WIDE:
			# Both arms straight out to the sides.
			figure.play("idle")
			figure.reach(Vector3(-0.86, 1.42, -0.05), Vector3(0.86, 1.42, -0.05), k)
		Sig.NO_BALL:
			# One arm straight out.
			figure.play("idle")
			figure.reach(rest_l, Vector3(0.86, 1.42, -0.12), k)
		Sig.FREE_HIT:
			# A finger up, circling.
			var a := _t * 9.0
			figure.play("idle")
			figure.reach(rest_l, Vector3(0.18 + 0.14 * cos(a), 2.0, -0.16 + 0.14 * sin(a)), k)
		_:
			figure.release()
			figure.play("fold_arms")
