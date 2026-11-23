class_name Body
extends Node3D
## An animated player: the low-poly model from art/player.glb (built by
## art/characters/player.py), playing CC0 animation clips from Quaternius' Universal
## Animation Library. Hands can be pulled to exact points with two-bone IK, so a fielder's
## hands still meet the ball. Coordinates match Figure: -Z is forward, feet at y = 0.

const SCENE := preload("res://art/player.glb")
const LOOPS := ["idle", "walk", "walk_formal", "jog", "sprint", "crouch", "jump_loop", "dance", "talk", "slide",
	"fold_arms", "no", "leap", "ready", "stoop", "keeper"]

var kit := Color(0.1, 0.35, 0.8)
var trim := Color(1.0, 0.8, 0.1)
var skin := Color(0.72, 0.5, 0.36)
var trousers := Color(0, 0, 0, 0)   # leave transparent for kit-coloured trousers
var whites := false                # cream trousers (batters)
var gear := "cap"                  # "cap", "helmet", "hat" or ""
var pads := false
var gloves := false

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var clip := ""
var mood := "focused"
var _meshes := {}
var _ik: TwoBoneIK3D
var _target_l: Node3D
var _target_r: Node3D
var _ik_w := 0.0
var _mood_left := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _name_label: Label3D
var _number_label: Label3D
var _back: BoneAttachment3D
# Where the hands really are after animation and IK (bone poses read outside the skeleton's
# update do not include the IK), refreshed every time the skeleton updates.
var _hand_l_now := Vector3.ZERO
var _hand_r_now := Vector3.ZERO
var _have_hands := false

const SKINS := [Color(0.72, 0.5, 0.36), Color(0.55, 0.37, 0.25), Color(0.82, 0.62, 0.48), Color(0.4, 0.27, 0.18),
	Color(0.66, 0.46, 0.33)]

## A skin tone picked from a seed, so a side is not all one shade.
static func skin_for(seed: int) -> Color:
	return SKINS[absi(seed) % SKINS.size()]

func build() -> void:
	model = SCENE.instantiate()
	model.rotation.y = PI
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in LOOPS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for m in model.find_children("*", "MeshInstance3D", true, false):
		_meshes[m.name] = m
	_paint()
	_targets()
	skeleton.skeleton_updated.connect(_cache_hands)
	_next_blink = 1.0 + randf() * 3.0
	play("idle")

## Rebuild the colours (a different team).
func recolour(new_kit: Color, new_trim: Color) -> void:
	kit = new_kit
	trim = new_trim
	_paint()
	if _number_label != null:
		_number_label.modulate = trim

func _paint() -> void:
	var white := Color(0.95, 0.95, 0.92)
	var colours := {
		"kit": kit, "kit_dark": kit.darkened(0.2), "trim": trim, "skin": skin, "skin_dark": skin.darkened(0.08),
		"pants": white if whites else (trousers if trousers.a > 0.0 else kit.darkened(0.12)),
		"white": white, "pad_roll": white.darkened(0.06), "shoe": Color(0.95, 0.95, 0.95),
		"dark": Color(0.07, 0.06, 0.08), "eyewhite": Color(0.98, 0.98, 0.96), "mouth": Color(0.45, 0.07, 0.1),
		"helmet": kit.darkened(0.45), "steel": Color(0.78, 0.79, 0.83), "hat": Color(0.96, 0.95, 0.90)}
	for key in _meshes:
		var mi: MeshInstance3D = _meshes[key]
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var role: String = src.resource_name if src != null else ""
			mi.set_surface_override_material(s, Figure.facet(colours.get(role, Color.WHITE)))
	_show("Hands", not gloves)
	_show("Gloves", gloves)
	_show("Pads", pads)
	_show("Cap", gear == "cap")
	_show("Helmet", gear == "helmet")
	_show("Hat", gear == "hat")

func _show(n: String, on: bool) -> void:
	if _meshes.has(n):
		(_meshes[n] as MeshInstance3D).visible = on

func _targets() -> void:
	_target_l = Node3D.new()
	_target_r = Node3D.new()
	add_child(_target_l)
	add_child(_target_r)
	var pole_l := Node3D.new()
	var pole_r := Node3D.new()
	add_child(pole_l)
	add_child(pole_r)
	pole_l.position = Vector3(-0.8, 0.7, 0.7)
	pole_r.position = Vector3(0.8, 0.7, 0.7)
	_ik = TwoBoneIK3D.new()
	skeleton.add_child(_ik)
	_ik.setting_count = 2
	var sides := [["l", _target_l, pole_l], ["r", _target_r, pole_r]]
	for i in 2:
		var s: String = sides[i][0]
		_ik.set_root_bone_name(i, "upperarm_" + s)
		_ik.set_middle_bone_name(i, "forearm_" + s)
		_ik.set_end_bone_name(i, "hand_" + s)
		_ik.set_extend_end_bone(i, true)
		_ik.set_end_bone_length(i, 0.06)
		_ik.set_target_node(i, _ik.get_path_to(sides[i][1]))
		_ik.set_pole_node(i, _ik.get_path_to(sides[i][2]))
	_ik.influence = 0.0
	_ik.active = false

## Play a clip. `speed` scales its rate; blends from the current clip over `blend` seconds.
func play(name: String, speed: float = 1.0, blend: float = 0.15, restart: bool = false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if name != clip or restart:
		anim.play(name, blend)
		if restart:
			anim.seek(0.0, true)
		clip = name
	anim.speed_scale = speed

## Stay on one moment (0..1) of a clip. (The fielding crouches are single poses already.)
func hold(name: String, at: float) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if name != clip:
		anim.play(name, 0.08)
		clip = name
		anim.speed_scale = 1.0
		if at > 0.0:
			anim.seek(anim.get_animation(name).length * clampf(at, 0.0, 1.0), false)
	if at > 0.0:
		anim.speed_scale = 0.05

## Put the hands at these points (this node's space), blending in by `weight`.
func reach(hand_l: Vector3, hand_r: Vector3, weight: float = 1.0) -> void:
	_target_l.position = hand_l
	_target_r.position = hand_r
	_ik_w = clampf(weight, 0.0, 1.0)
	_ik.influence = _ik_w
	_ik.active = _ik_w > 0.001

func release() -> void:
	_ik_w = 0.0
	_ik.influence = 0.0
	_ik.active = false

## Midpoint between the two hands, in world space.
func hands_global() -> Vector3:
	if _ik_w > 0.5:
		return (_target_l.global_position + _target_r.global_position) * 0.5
	return (hand_global("l") + hand_global("r")) * 0.5

## Where the hands actually are now (after IK), in world space.
func hands_now() -> Vector3:
	if not _have_hands:
		return hands_global()
	return (_hand_l_now + _hand_r_now) * 0.5

func hand_r_now() -> Vector3:
	return _hand_r_now if _have_hands else hand_global("r")

func _cache_hands() -> void:
	_hand_l_now = hand_global("l")
	_hand_r_now = hand_global("r")
	_have_hands = true

func hand_global(side: String) -> Vector3:
	var i := skeleton.find_bone("hand_" + side)
	var t := skeleton.global_transform * skeleton.get_bone_global_pose(i)
	return t * Vector3(0, 0.06, 0)

## A node that follows a bone (for a bat in the hand, say).
func attach(bone: String) -> BoneAttachment3D:
	var b := BoneAttachment3D.new()
	b.bone_name = bone
	skeleton.add_child(b)
	return b

## "focused", "joy" or "wince"; with `seconds`, back to focused afterwards.
func set_face(kind: String, seconds: float = 0.0) -> void:
	mood = kind
	_mood_left = seconds
	_shape("Face", "Joy", 1.0 if kind == "joy" else 0.0)
	_shape("Face", "Wince", 1.0 if kind == "wince" else 0.0)

func _shape(mesh: String, key: String, v: float) -> void:
	if not _meshes.has(mesh):
		return
	var mi: MeshInstance3D = _meshes[mesh]
	var i := mi.find_blend_shape_by_name(key)
	if i >= 0:
		mi.set_blend_shape_value(i, v)

## Name and number on the back of the shirt.
func set_shirt(shirt_name: String, number: int) -> void:
	if _number_label == null:
		_back = attach("spine3")
		_number_label = _label(60)
		_name_label = _label(24)
		# The chest bone's frame: up its length, out of the back.
		_number_label.position = Vector3(0, 0.0, 0.14)
		_name_label.position = Vector3(0, 0.12, 0.15)
	_number_label.text = str(number)
	_name_label.text = shirt_name.to_upper()

func _label(size: int) -> Label3D:
	var l := Label3D.new()
	l.font = Hud.font("bold")
	l.font_size = size
	l.pixel_size = 0.003
	l.modulate = trim
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_back.add_child(l)
	return l

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			set_face("focused")
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.13
		_next_blink = 2.0 + randf() * 3.5
	_blink = maxf(_blink - delta, 0.0)
	_shape("Eyes", "Blink", 1.0 if _blink > 0.0 else 0.0)
	_shape("Eyes", "Squint", 1.0 if mood == "wince" and _blink <= 0.0 else 0.0)
