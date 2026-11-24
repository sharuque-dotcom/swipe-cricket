class_name Walker
extends Node3D
## A batter walking to or from the crease, bat in the right hand.

var figure: Body
var bat: Bat
var glum := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dur := 1.0
var _delay := 0.0
var _t := 0.0

func build(kit: Color, trim: Color) -> void:
	figure = Body.new()
	figure.kit = kit
	figure.trim = trim
	figure.pads = true
	figure.gloves = true
	figure.whites = true
	figure.gear = "helmet"
	figure.helmet_colour = Locker.helmet_colour()
	add_child(figure)
	figure.build()
	# Bat carried in the right hand, toe forward and down.
	bat = Bat.new()
	figure.attach("hand_r").add_child(bat)
	bat.build()
	bat.place(Vector3(0, 0.07, 0), Vector3(0, 1, -0.5).normalized(), Vector3(1, 0, 0))

## Walk from `from` to `to` over `seconds`, starting after `delay`.
func walk(from: Vector3, to: Vector3, seconds: float, delay: float = 0.0, head_down: bool = false) -> void:
	_from = from
	_to = to
	_dur = maxf(seconds, 0.1)
	_delay = delay
	_t = 0.0
	glum = head_down
	figure.set_face("wince" if head_down else "focused")
	position = from
	var d := to - from
	if d.length() > 0.1:
		rotation.y = atan2(-d.x, -d.z)
	visible = true
	figure.play("idle")

func _process(delta: float) -> void:
	if not visible:
		return
	_t += minf(delta, 0.05)
	var u := clampf((_t - _delay) / _dur, 0.0, 1.0)
	position = _from.lerp(_to, u)
	if u > 0.0 and u < 1.0:
		# The clip covers about 1.4 m/s; match the feet to the ground speed.
		var speed := _from.distance_to(_to) / _dur
		if speed > 2.6:
			figure.play("jog", clampf(speed / 3.6, 0.6, 1.4))
		else:
			figure.play("walk", clampf(speed / 1.4, 0.5, 1.8) * (0.85 if glum else 1.0))
	else:
		figure.play("idle")
