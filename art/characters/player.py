"""Builds the rigged low-poly player (style D) and its animations, exported as one .glb.

    blender -b -P art/characters/player.py -- UAL1.glb UAL2.glb OUT.glb

The skeleton and animations come from Quaternius' Universal Animation Library 1 and 2
(CC0, opengameart.org). Clips from library 2 are retargeted onto library 1's rig. The body
is built here in the game's low-poly style: every part is a rigid block bound to one bone,
so it reads like the code-built figures used for the batter and bowler.

Objects (so the game can switch them on and off): Body, Hands, Gloves, Pads, Head, Face
(shape keys Joy, Wince), Eyes (Blink, Squint), Cap, Helmet, Hat. Materials are named by
role (kit, trim, skin, pants, ...) and recoloured in game.
"""
import bpy
import bmesh
import math
import sys
from mathutils import Matrix, Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
UAL1, UAL2, OUT = args[0], args[1], args[2]

# ---- Skeleton ------------------------------------------------------------------------------

RENAME1 = {"DEF-hips": "hips", "DEF-spine.001": "spine1", "DEF-spine.002": "spine2", "DEF-spine.003": "spine3",
           "DEF-neck": "neck", "DEF-head": "head"}
RENAME2 = {"pelvis": "hips", "spine_01": "spine1", "spine_02": "spine2", "spine_03": "spine3", "neck_01": "neck",
           "Head": "head", "root": "root"}
for s, S in (("l", "L"), ("r", "R")):
    RENAME1.update({"DEF-shoulder." + S: "shoulder_" + s, "DEF-upper_arm." + S: "upperarm_" + s,
                    "DEF-forearm." + S: "forearm_" + s, "DEF-hand." + S: "hand_" + s, "DEF-thigh." + S: "thigh_" + s,
                    "DEF-shin." + S: "shin_" + s, "DEF-foot." + S: "foot_" + s, "DEF-toe." + S: "toe_" + s})
    RENAME2.update({"clavicle_" + s: "shoulder_" + s, "upperarm_" + s: "upperarm_" + s, "lowerarm_" + s: "forearm_" + s,
                    "hand_" + s: "hand_" + s, "thigh_" + s: "thigh_" + s, "calf_" + s: "shin_" + s,
                    "foot_" + s: "foot_" + s, "ball_" + s: "toe_" + s})

CLIPS1 = {"Idle_Loop": "idle", "Walk_Loop": "walk", "Walk_Formal_Loop": "walk_formal", "Jog_Fwd_Loop": "jog",
          "Sprint_Loop": "sprint", "Crouch_Idle_Loop": "crouch", "PickUp_Table": "pickup", "Jump_Start": "jump_start",
          "Jump_Loop": "jump_loop", "Jump_Land": "jump_land", "Dance_Loop": "dance", "Roll": "roll",
          "Hit_Chest": "hit", "Idle_Talking_Loop": "talk"}
CLIPS2 = {"OverhandThrow": "throw", "Slide_Start": "slide_start", "Slide_Loop": "slide", "Slide_Exit": "slide_exit",
          "Idle_FoldArms_Loop": "fold_arms", "Idle_No_Loop": "no", "Yes": "yes", "NinjaJump_Start": "leap_start",
          "NinjaJump_Idle_Loop": "leap", "NinjaJump_Land": "leap_land"}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def import_rig(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in new if o.type == "ARMATURE"][0]
    for o in new:
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    return arm


def clip_name(action_name, table):
    for k, v in table.items():
        if action_name == k or action_name.startswith(k + "_"):
            if action_name[len(k):] in ("", "_Rig", "_Armature"):
                return v
    return None


rig = import_rig(UAL1)
rig.name = "Player"
rig.data.name = "PlayerRig"
actions1 = list(bpy.data.actions)

# Keep the body bones; fingers are not needed (hands are blocks).
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for eb in list(rig.data.edit_bones):
    if eb.name != "root" and eb.name not in RENAME1:
        rig.data.edit_bones.remove(eb)
bpy.ops.object.mode_set(mode="OBJECT")
for old, new in RENAME1.items():
    rig.data.bones[old].name = new


def rename_paths(action, table):
    for fc in list(action.fcurves):
        p = fc.data_path
        if p.startswith('pose.bones["'):
            b = p.split('"')[1]
            if b in table:
                fc.data_path = p.replace('"%s"' % b, '"%s"' % table[b])
            elif b not in table.values():
                action.fcurves.remove(fc)


keep = []
for a in actions1:
    n = clip_name(a.name, CLIPS1)
    if n is None:
        bpy.data.actions.remove(a)
        continue
    rename_paths(a, RENAME1)
    a.name = n
    a.use_fake_user = True
    keep.append(a)

# Retarget library 2: for every frame, give each target bone the same change from its rest
# orientation (in armature space) as the source bone.
src = import_rig(UAL2)
rest_t = {b.name: b.matrix_local.copy() for b in rig.data.bones}
rest_s = {b.name: b.matrix_local.copy() for b in src.data.bones}
order = []


def walk(b):
    order.append(b.name)
    for c in b.children:
        walk(c)


walk([b for b in rig.data.bones if b.parent is None][0])
src_of = {v: k for k, v in RENAME2.items()}
for a in [a for a in bpy.data.actions if a not in keep]:
    n = clip_name(a.name, CLIPS2)
    if n is None:
        continue
    src.animation_data_create()
    src.animation_data.action = a
    out = bpy.data.actions.new(n)
    out.use_fake_user = True
    f0, f1 = int(a.frame_range[0]), int(math.ceil(a.frame_range[1]))
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        pose = {}
        for name in order:
            sname = src_of.get(name)
            if sname is None or sname not in src.pose.bones:
                continue
            M = src.pose.bones[sname].matrix @ rest_s[sname].inverted() @ rest_t[name]
            pose[name] = M
            bone = rig.data.bones[name]
            if bone.parent is not None and bone.parent.name in pose:
                P = pose[bone.parent.name]
                local = (rest_t[bone.parent.name].inverted() @ rest_t[name]).inverted() @ P.inverted() @ M
            else:
                local = rest_t[name].inverted() @ M
            loc, rot, _ = local.decompose()
            base = 'pose.bones["%s"].' % name
            for i in range(4):
                fc = out.fcurves.find(base + "rotation_quaternion", index=i) or out.fcurves.new(base + "rotation_quaternion", index=i, action_group=name)
                fc.keyframe_points.insert(f - f0, rot[i], options={"FAST"})
            if name in ("hips", "root"):
                for i in range(3):
                    fc = out.fcurves.find(base + "location", index=i) or out.fcurves.new(base + "location", index=i, action_group=name)
                    fc.keyframe_points.insert(f - f0, loc[i], options={"FAST"})
    keep.append(out)
# ---- Poses made here: fielding crouches the libraries do not have -------------------------
# Each bone gets an orientation change in armature space (bones not listed take their
# parent's), and the hips drop. Forward is -Y, so a bend forward is +X rotation for the
# spine and a thigh lifted forward is -X.


def rx(d):
    return Matrix.Rotation(math.radians(d), 4, "X")


def ry(d):
    return Matrix.Rotation(math.radians(d), 4, "Y")


def make_pose(name, spec, drop, fwd=0.0):
    out = bpy.data.actions.new(name)
    out.use_fake_user = True
    for f in (0, 10):
        pose, delta = {}, {}
        for bname in order:
            bone = rig.data.bones[bname]
            parent = bone.parent.name if bone.parent is not None else None
            D = spec.get(bname, delta.get(parent, Matrix.Identity(4)))
            delta[bname] = D
            R = rest_t[bname]
            if parent is None:
                head = R.translation.copy()
            else:
                head = (pose[parent] @ rest_t[parent].inverted() @ R).translation
            if bname == "hips":
                head = head + Vector((0, -fwd, -drop))
            M = Matrix.Translation(head) @ (D.to_3x3() @ R.to_3x3()).to_4x4()
            pose[bname] = M
            if parent is not None:
                local = (rest_t[parent].inverted() @ R).inverted() @ pose[parent].inverted() @ M
            else:
                local = R.inverted() @ M
            loc, rot, _ = local.decompose()
            base = 'pose.bones["%s"].' % bname
            for i in range(4):
                fc = out.fcurves.find(base + "rotation_quaternion", index=i) or out.fcurves.new(base + "rotation_quaternion", index=i, action_group=bname)
                fc.keyframe_points.insert(f, rot[i], options={"FAST"})
            for i in range(3):
                fc = out.fcurves.find(base + "location", index=i) or out.fcurves.new(base + "location", index=i, action_group=bname)
                fc.keyframe_points.insert(f, loc[i], options={"FAST"})
    keep.append(out)


# Walking in as the bowler runs up: knees bent, leaning in.
make_pose("ready", {"hips": rx(8), "spine1": rx(14), "spine2": rx(22), "spine3": rx(30), "neck": rx(12), "head": rx(0),
                    "thigh_l": ry(-6) @ rx(-38), "thigh_r": ry(6) @ rx(-38), "shin_l": rx(32), "shin_r": rx(32),
                    "foot_l": rx(0), "foot_r": rx(0)}, 0.12, 0.05)
# Down on one knee behind the ball, hands to the grass.
make_pose("stoop", {"hips": rx(28), "spine1": rx(55), "spine2": rx(75), "spine3": rx(90), "neck": rx(40), "head": rx(10),
                    "thigh_l": ry(-10) @ rx(-85), "shin_l": rx(5), "foot_l": rx(0),
                    "thigh_r": ry(10) @ rx(-10), "shin_r": rx(95), "foot_r": rx(95)}, 0.47, 0.12)
# Keeper squat: knees wide, low.
make_pose("keeper", {"hips": rx(10), "spine1": rx(18), "spine2": rx(26), "spine3": rx(32), "neck": rx(10), "head": rx(-5),
                     "thigh_l": ry(-28) @ rx(-80), "thigh_r": ry(28) @ rx(-80), "shin_l": rx(55), "shin_r": rx(55),
                     "foot_l": rx(0), "foot_r": rx(0)}, 0.5, 0.0)
src_arm = src.data
bpy.data.objects.remove(src, do_unlink=True)
for a in list(bpy.data.actions):
    if a not in keep:
        bpy.data.actions.remove(a)
print("clips:", sorted(a.name for a in keep))

# Rest pose for building.
rig.animation_data_create()
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()

# ---- Body parts ----------------------------------------------------------------------------

COLOURS = {"kit": (0.1, 0.35, 0.8), "kit_dark": (0.08, 0.28, 0.65), "trim": (1.0, 0.8, 0.1),
           "skin": (0.72, 0.5, 0.36), "skin_dark": (0.66, 0.45, 0.32), "pants": (0.95, 0.95, 0.92),
           "white": (0.95, 0.95, 0.92), "pad_roll": (0.89, 0.89, 0.86), "shoe": (0.95, 0.95, 0.95),
           "dark": (0.07, 0.06, 0.08), "eyewhite": (0.98, 0.98, 0.96), "mouth": (0.45, 0.07, 0.1),
           "helmet": (0.05, 0.15, 0.4), "steel": (0.78, 0.79, 0.83), "hat": (0.96, 0.95, 0.9)}
MATS = {}
for k, c in COLOURS.items():
    m = bpy.data.materials.new(k)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*c, 1.0)
    MATS[k] = m
BONES = [b.name for b in rig.data.bones]


class Part:
    """Geometry for one object: primitives, each rigidly bound to one bone."""

    def __init__(self):
        self.verts = []   # (co, bone)
        self.faces = []   # (indices, material)
        self.mats = []

    def add(self, bm, M, mat, bone, keep=None):
        if mat not in self.mats:
            self.mats.append(mat)
        mi = self.mats.index(mat)
        base = len(self.verts)
        idx = {}
        for v in bm.verts:
            if keep is not None and not keep(v.co):
                continue
            idx[v.index] = len(self.verts) - base
            self.verts.append((M @ v.co, bone))
        for f in bm.faces:
            if all(v.index in idx for v in f.verts):
                self.faces.append(([base + idx[v.index] for v in f.verts], mi))
        bm.free()

    def coords(self):
        return [v[0] for v in self.verts]

    def build(self, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.coords(), [], [f[0] for f in self.faces])
        for m in self.mats:
            me.materials.append(MATS[m])
        for p, (_, mi) in zip(me.polygons, self.faces):
            p.material_index = mi
        ob = bpy.data.objects.new(name, me)
        scene.collection.objects.link(ob)
        groups = {}
        for i, (_, b) in enumerate(self.verts):
            if b not in groups:
                groups[b] = ob.vertex_groups.new(name=b)
            groups[b].add([i], 1.0, "REPLACE")
        ob.parent = rig
        mod = ob.modifiers.new("rig", "ARMATURE")
        mod.object = rig
        return ob


def cone(r1, r2, sides=6, rot=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r1, radius2=r2, depth=1.0,
                          matrix=Matrix.Rotation(rot, 4, "Z"))
    bm.verts.index_update()
    return bm


def sphere(r, u=8, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    bm.verts.index_update()
    return bm


def cube():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.verts.index_update()
    return bm


def between(a, b, sx=1.0, sy=1.0, side=None):
    """Matrix taking a unit-height primitive (centred, along Z) to span a..b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    z = d.normalized()
    x = Vector(side) if side is not None else (Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0)))
    x = (x - z * x.dot(z)).normalized()
    y = z.cross(x)
    R = Matrix((x, y, z)).transposed().to_4x4()
    return Matrix.Translation((a + b) / 2) @ R @ Matrix.Diagonal((sx, sy, d.length, 1.0))


def at(p, s=(1, 1, 1), rot=None):
    M = Matrix.Translation(Vector(p))
    if rot is not None:
        M = M @ rot.to_4x4()
    return M @ Matrix.Diagonal((*s, 1.0))


def head_of(b):
    return rig.data.bones[b].head_local.copy()


def tail_of(b):
    return rig.data.bones[b].tail_local.copy()


def capsule(part, a, b, r, mat, bone):
    part.add(cone(r, r, 6), between(a, b), mat, bone)
    for p in (a, b):
        part.add(sphere(r, 6, 4), at(p), mat, bone)


body = Part()
# Pelvis, lower torso, chest (squashed front to back, flat facet forward), stripe.
z_hip = head_of("hips").z
body.add(cone(0.155, 0.15, 8, math.pi / 8), between((0, 0.01, z_hip - 0.1), (0, 0.01, z_hip + 0.1), 1, 0.78), "pants", "hips")
body.add(cone(0.15, 0.165, 8, math.pi / 8), between((0, 0.01, z_hip + 0.06), (0, 0.01, 1.22), 1, 0.8), "kit", "spine1")
body.add(cone(0.165, 0.185, 8, math.pi / 8), between((0, 0.01, 1.2), (0, 0.01, 1.5), 1, 0.8), "kit", "spine3")
body.add(cone(0.17, 0.172, 8, math.pi / 8), between((0, 0.01, 1.22), (0, 0.01, 1.28), 1, 0.8), "trim", "spine2")
body.add(cone(0.055, 0.05, 6), between((0, 0.01, 1.47), (0, 0.0, 1.6)), "skin", "neck")
for s in ("l", "r"):
    sh = head_of("upperarm_" + s)
    el = head_of("forearm_" + s)
    wr = head_of("hand_" + s)
    capsule(body, sh, el, 0.062, "kit", "upperarm_" + s)
    body.add(sphere(0.07, 6, 4), at(sh + Vector((0, 0, 0.0))), "kit", "shoulder_" + s)
    capsule(body, el, wr, 0.048, "skin", "forearm_" + s)
    hip = head_of("thigh_" + s)
    kn = head_of("shin_" + s)
    an = head_of("foot_" + s)
    capsule(body, hip, kn, 0.086, "pants", "thigh_" + s)
    capsule(body, kn, an, 0.064, "pants", "shin_" + s)
    # Shoe: a block from the heel to the toe.
    toe = tail_of("toe_" + s)
    body.add(cube(), at(((an.x + toe.x) / 2, (an.y + 0.07 + toe.y + 0.06) / 2, 0.04), (0.11, abs(toe.y - 0.06 - an.y - 0.07), 0.08)), "shoe", "foot_" + s)

hands, gloves, pads = Part(), Part(), Part()
for s in ("l", "r"):
    wr = head_of("hand_" + s)
    out = (tail_of("hand_" + s) - wr).normalized()
    hands.add(sphere(0.062, 6, 4), at(wr + out * 0.05), "skin", "hand_" + s)
    gloves.add(cube(), at(wr + out * 0.055, (0.125, 0.1, 0.115)), "white", "hand_" + s)
    gloves.add(cube(), at(wr - out * 0.0, (0.03, 0.105, 0.12)), "kit", "hand_" + s)
    kn = head_of("shin_" + s)
    an = head_of("foot_" + s)
    side = Vector((1, 0, 0))
    pads.add(cube(), between(kn + Vector((0, -0.06, 0.06)), an + Vector((0, -0.065, -0.02)), 0.19, 0.1, side), "white", "shin_" + s)
    pads.add(cube(), between(kn + Vector((0, -0.065, 0.09)), kn + Vector((0, -0.065, -0.04)), 0.2, 0.13, side), "pad_roll", "shin_" + s)
    for k in (-1, 0, 1):
        pads.add(cube(), between(kn + Vector((k * 0.05, -0.115, -0.02)), an + Vector((k * 0.05, -0.115, 0.05)), 0.012, 0.012, side), "pad_roll", "shin_" + s)

# ---- Head and face -----------------------------------------------------------------------
# Head parts are written in the game figure's head coordinates (x right, y up, -z forward,
# before its 1.32 scale) so they match the code-built figures exactly.
HS = 1.32
H0 = head_of("head") + Vector((0, 0, 0.135))


def hp(g):
    """Figure head coordinates to armature space."""
    return H0 + Vector((g[0], g[2], g[1])) * HS


def hs(s):
    return (s[0] * HS, s[2] * HS, s[1] * HS)


def hrot_z(angle):
    # A roll about the figure's forward axis (its z) is a roll about our y.
    return Matrix.Rotation(angle, 3, "Y")


head = Part()
head.add(sphere(0.135, 8, 6), at(hp((0, 0, 0)), hs((0.96, 1.0, 0.96))), "skin", "head")
for side in (-1, 1):
    head.add(sphere(0.03, 6, 3), at(hp((side * 0.13, -0.005, 0)), hs((0.5, 1.0, 0.8))), "skin", "head")
head.add(sphere(0.02, 5, 3), at(hp((0, -0.035, -0.133)), hs((1, 1, 1))), "skin_dark", "head")


def face(kind):
    p = Part()
    for i, side in enumerate((-1, 1)):
        ang = {"joy": -12, "wince": 26}.get(kind, 14) * side
        y = {"joy": 0.056, "wince": 0.04}.get(kind, 0.046)
        p.add(cube(), at(hp((side * 0.05, y, -0.124)), hs((0.06, 0.014, 0.02)), hrot_z(math.radians(-ang))), "dark", "head")
    hide = 0.001
    m = 1.0 if kind != "joy" else hide
    tilt = math.radians(-16) if kind == "wince" else 0.0
    p.add(cube(), at(hp((0.01 if kind == "wince" else 0.0, -0.075, -0.118 + (0 if m == 1 else 0.05))), hs((0.055 * m, 0.011 * m, 0.02 * m)), hrot_z(tilt)), "dark", "head")
    g = 1.0 if kind == "joy" else hide
    # The grin: a half-disc, flat edge up.
    p.add(sphere(0.04, 8, 4), at(hp((0, -0.062, -0.118 + (0 if g == 1 else 0.05))), hs((1.0 * g, 0.85 * g, 0.35 * g))), "mouth", "head",
          keep=lambda co: co.z <= 0.0005)
    return p


def eyes(open_):
    p = Part()
    for side in (-1, 1):
        c = (side * 0.05, -0.004, -0.114)
        p.add(sphere(0.034, 8, 4), at(hp(c), hs((1.0, 1.2 * open_, 0.6))), "eyewhite", "head")
        p.add(sphere(0.017, 6, 3), at(hp((c[0], c[1], c[2] - 0.022)), hs((1.0, 1.25 * open_, 0.5))), "dark", "head")
    return p


def with_keys(name, base, keys):
    ob = base.build(name)
    ob.shape_key_add(name="Basis")
    for kname, part in keys.items():
        k = ob.shape_key_add(name=kname)
        for i, co in enumerate(part.coords()):
            k.data[i].co = co
    return ob


cap, helmet, hat = Part(), Part(), Part()
# Cap: dome, peak tipped up.
cap.add(sphere(0.142, 8, 6), at(hp((0, 0.062, 0))), "kit", "head", keep=lambda co: co.z >= -0.001)
cap.add(cube(), at(hp((0, 0.075, -0.165)), hs((0.21, 0.018, 0.12)), Matrix.Rotation(-0.22, 3, "X")), "kit", "head")
# Helmet: dome, peak, neck guard, team stripe, grille.
helmet.add(sphere(0.152, 8, 6), at(hp((0, 0.012, 0))), "helmet", "head", keep=lambda co: co.z >= -0.001)
helmet.add(cube(), at(hp((0, 0.03, -0.17)), hs((0.21, 0.018, 0.12))), "helmet", "head")
helmet.add(cube(), at(hp((0, -0.02, 0.06)), hs((0.24, 0.07, 0.12))), "helmet", "head")
helmet.add(cube(), at(hp((0, 0.158, 0)), hs((0.05, 0.012, 0.1))), "trim", "head")
for i in range(3):
    helmet.add(cube(), at(hp((0, -0.025 - 0.038 * i, -0.158)), hs((0.22, 0.012, 0.012))), "steel", "head")
for side in (-1, 1):
    helmet.add(cube(), at(hp((side * 0.105, -0.06, -0.152)), hs((0.012, 0.11, 0.012))), "steel", "head")
# Umpire's hat.
for r1, r2, sides, h, y, mat in ((0.27, 0.27, 10, 0.022, 0.07, "hat"), (0.145, 0.12, 8, 0.12, 0.135, "hat"),
                                 (0.148, 0.148, 8, 0.03, 0.095, "kit")):
    hat.add(cone(r1, r2, sides), at(hp((0, y, 0)), (HS, HS, h * HS)), mat, "head")

for name, part in (("Body", body), ("Hands", hands), ("Gloves", gloves), ("Pads", pads), ("Head", head),
                   ("Cap", cap), ("Helmet", helmet), ("Hat", hat)):
    part.build(name)
with_keys("Face", face("focused"), {"Joy": face("joy"), "Wince": face("wince")})
with_keys("Eyes", eyes(1.0), {"Blink": eyes(0.12), "Squint": eyes(0.55)})

# One NLA track per clip, named after it: the exporter writes each track as an animation.
ad = rig.animation_data
for t in list(ad.nla_tracks):
    ad.nla_tracks.remove(t)
ad.action = None
for act in sorted(keep, key=lambda x: x.name):
    t = ad.nla_tracks.new()
    t.name = act.name
    t.strips.new(act.name, 0, act)
    t.mute = True
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="NLA_TRACKS",
                          export_morph=True, export_skins=True, export_def_bones=False,
                          export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=True,
                          export_anim_single_armature=True, export_reset_pose_bones=True)
print("exported", OUT)
