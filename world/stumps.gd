class_name Stumps
extends Node3D

var _stumps: Array[MeshInstance3D] = []
var _bails: Array[MeshInstance3D] = []
var _tween: Tween

func build() -> void:
	var wood := Figure.mat(Color(0.93, 0.84, 0.60), 0.5)
	for i in 3:
		var s := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.019
		m.bottom_radius = 0.019
		m.height = Pitch.STUMP_HEIGHT
		m.radial_segments = 10
		s.mesh = m
		s.material_override = wood
		add_child(s)
		_stumps.append(s)
	for i in 2:
		var b := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.011
		m.bottom_radius = 0.011
		m.height = 0.105
		m.radial_segments = 8
		b.mesh = m
		b.material_override = wood
		add_child(b)
		_bails.append(b)
	reset()

func reset() -> void:
	if _tween:
		_tween.kill()
	for i in 3:
		_stumps[i].transform = Transform3D(Basis.IDENTITY, Vector3((i - 1) * 0.0953, Pitch.STUMP_HEIGHT * 0.5, 0))
	for i in 2:
		_bails[i].transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3((i - 0.5) * 0.0953, Pitch.STUMP_HEIGHT + 0.012, 0))

## Knocks the stumps back; `hit_x` is where the ball struck across the wicket.
func shatter(hit_x: float, ball_speed: float) -> void:
	_tween = create_tween().set_parallel(true)
	var force := clampf(ball_speed / 30.0, 0.4, 1.3)
	for i in 3:
		var sx := (i - 1) * 0.0953
		var near := clampf(1.0 - absf(sx - hit_x) / 0.12, 0.15, 1.0)
		var tilt := deg_to_rad(55.0) * near * force
		var b := Basis(Vector3.RIGHT, tilt) * Basis(Vector3.BACK, (sx - hit_x) * 2.5 * near)
		var end := Transform3D(b, Vector3(sx, Pitch.STUMP_HEIGHT * 0.5 * cos(tilt), sin(tilt) * Pitch.STUMP_HEIGHT * 0.5 + 0.1 * near))
		_tween.tween_property(_stumps[i], "transform", end, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for i in 2:
		var side := 1.0 if i == 1 else -1.0
		var peak := Vector3(side * 0.35, 1.5 * force, 0.8 * force)
		var land := Vector3(side * 0.6, 0.02, 1.9 * force)
		var bail := _bails[i]
		var seq := create_tween()
		seq.tween_property(bail, "position", peak, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		seq.tween_property(bail, "position", land, 0.34).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(bail, "rotation", Vector3(9.0 * side, 4.0, 1.0), 0.62)
