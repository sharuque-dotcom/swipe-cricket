class_name Bat
extends Node3D
## Cricket bat placed by its grip point and the direction the blade points.

const HANDLE := 0.28
const BLADE := 0.56
const SWEET := 0.50     # grip centre to sweet spot
const TIP := HANDLE * 0.5 + BLADE

func build() -> void:
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.108, BLADE, 0.045)
	blade.mesh = bm
	blade.position.y = -(HANDLE * 0.5 + BLADE * 0.5)
	blade.material_override = Figure.mat(Color(0.87, 0.72, 0.47), 0.6)
	add_child(blade)
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.018
	hm.bottom_radius = 0.02
	hm.height = HANDLE
	hm.radial_segments = 10
	handle.mesh = hm
	handle.material_override = Figure.mat(Color(0.12, 0.2, 0.55), 0.9)
	add_child(handle)

## `dir` points from the handle to the toe; `face` is the way the flat side looks.
func place(grip: Vector3, dir: Vector3, face: Vector3) -> void:
	var y := -dir.normalized()
	var z := face - y * face.dot(y)
	z = z.normalized() if z.length_squared() > 0.0001 else y.cross(Vector3.RIGHT).normalized()
	var x := y.cross(z).normalized()
	transform = Transform3D(Basis(x, y, z), grip)
