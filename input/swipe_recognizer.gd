class_name SwipeRecognizer
extends Node
## Turns a finger stroke into a shot intent. The swing starts when the finger lifts.

signal swipe_started
signal swipe_moved(points: PackedVector2Array)
## angle: 0 = straight up the screen, positive = to the right. power and loft are 0..1.
signal swiped(angle: float, power: float, loft: float)

var enabled := true
var _active := false
var _index := -1
var _points := PackedVector2Array()
var _t0 := 0

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true
			_index = event.index
			_points = PackedVector2Array([event.position])
			_t0 = Time.get_ticks_usec()
			swipe_started.emit()
		elif not event.pressed and _active and event.index == _index:
			_points.append(event.position)
			_finish()
	elif event is InputEventScreenDrag and _active and event.index == _index:
		_points.append(event.position)
		swipe_moved.emit(_points)

func _finish() -> void:
	_active = false
	var h := float(get_viewport().get_visible_rect().size.y)
	var v := _points[_points.size() - 1] - _points[0]
	var len_frac := v.length() / h
	if len_frac < Tuning.SWIPE_MIN_LEN:
		return
	var dur := maxf((Time.get_ticks_usec() - _t0) / 1000000.0, 0.016)
	var res := interpret(v / h, dur)
	swiped.emit(res.angle, res.power, res.loft)

## Pure mapping from a normalised stroke to a shot, so it can be tested and reused by bots.
static func interpret(stroke: Vector2, duration: float) -> Dictionary:
	var len_frac := stroke.length()
	var speed := len_frac / duration
	return {
		"angle": atan2(stroke.x, -stroke.y),
		"power": clampf(inverse_lerp(Tuning.SWIPE_POWER_SPEED_MIN, Tuning.SWIPE_POWER_SPEED_MAX, speed), 0.0, 1.0),
		"loft": clampf(inverse_lerp(Tuning.SWIPE_LOFT_LEN_MIN, Tuning.SWIPE_LOFT_LEN_MAX, len_frac), 0.0, 1.0),
	}
