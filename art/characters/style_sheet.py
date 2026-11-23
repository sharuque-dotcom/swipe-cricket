"""Builds the character style-sheet models in Blender and exports them as .glb.

    blender -b -P art/characters/style_sheet.py -- OUT_DIR

Four style directions (chunky, athletic, bobblehead, low-poly), each with a batter in his
stance, a bowler at the moment of delivery, an umpire giving it out, and three faces
(focused, joy, wince). Bodies are skin-modifier tubes along a posed skeleton, so the shapes
come out smooth and the proportions are one set of numbers per style. All original designs.
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/style"
os.makedirs(OUT, exist_ok=True)

H = 1.8  # every character stands 1.8 m tall

STYLES = {
    "chunky": dict(head=0.24, chest=(0.175, 0.125), pelvis=(0.155, 0.115), upper=0.058, fore=0.052, hand=0.068,
                   thigh=0.078, shin=0.064, foot=(0.12, 0.27), subsurf=2, eye=0.30, pupil=0.13, faceted=False),
    "athletic": dict(head=0.155, chest=(0.16, 0.105), pelvis=(0.14, 0.1), upper=0.045, fore=0.038, hand=0.046,
                     thigh=0.066, shin=0.05, foot=(0.095, 0.25), subsurf=2, eye=0.16, pupil=0.09, faceted=False),
    "bobble": dict(head=0.34, chest=(0.17, 0.13), pelvis=(0.155, 0.12), upper=0.052, fore=0.048, hand=0.058,
                   thigh=0.074, shin=0.064, foot=(0.11, 0.22), subsurf=2, eye=0.34, pupil=0.16, faceted=False),
    "lowpoly": dict(head=0.21, chest=(0.17, 0.12), pelvis=(0.15, 0.11), upper=0.054, fore=0.048, hand=0.06,
                    thigh=0.074, shin=0.06, foot=(0.11, 0.26), subsurf=0, eye=0.24, pupil=0.11, faceted=True),
}

KIT = (0.10, 0.32, 0.78)
TRIM = (1.0, 0.80, 0.15)
CREAM = (0.95, 0.94, 0.90)
NAVY = (0.06, 0.10, 0.25)
WOOD = (0.87, 0.70, 0.45)
SKINS = [(0.55, 0.37, 0.25), (0.36, 0.23, 0.15), (0.86, 0.66, 0.52)]


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_mats = {}


def mat(name, rgb):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.8
    _mats[name] = m
    return m


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def finish(ob, st, m):
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = not st["faceted"]
    return ob


def tubes(name, joints, edges, radii, st, m):
    """Smooth limbs: a skin modifier over a little skeleton, then subdivision."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(j) for j in joints], edges, [])
    ob = link(bpy.data.objects.new(name, me))
    sk = ob.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = not st["faceted"]
    for i, r in enumerate(radii):
        v = me.skin_vertices[0].data[i]
        v.radius = r if isinstance(r, tuple) else (r, r)
        v.use_root = i == 0
    if st["subsurf"] > 0:
        ss = ob.modifiers.new("sub", "SUBSURF")
        ss.levels = st["subsurf"]
        ss.render_levels = st["subsurf"]
    ob.data.materials.append(m)
    return ob


def ball(name, at, r, st, m, scale=(1, 1, 1), segs=None):
    s = segs or ((8, 6) if st["faceted"] else (24, 14))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=s[0], ring_count=s[1], radius=r, location=at)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    return finish(ob, st, m)


def box(name, at, size, st, m, rot=None, bevel=0.3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    if rot is not None:
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = rot
    if not st["faceted"] and bevel > 0:
        bv = ob.modifiers.new("bev", "BEVEL")
        bv.width = min(size) * bevel
        bv.segments = 3
    return finish(ob, st, m)


def rod(name, a, b, r, st, m, segs=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=6 if st["faceted"] else segs, radius=r, depth=d.length,
                                        location=(a + b) / 2)
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return finish(ob, st, m)


def along(v_from, v_to):
    return Vector((0, 0, 1)).rotation_difference((Vector(v_to) - Vector(v_from)).normalized())


# ---- Poses -------------------------------------------------------------------------------
# Joints in units of the neck height N (feet at 0, neck at about 1). Facing -Y; the right
# side of the body is -X.

POSES = {
    "batter": dict(
        pelvis=(0, 0.02, 0.47), chest=(0.02, -0.03, 0.78), neck=(0.03, -0.05, 0.97),
        sh_r=(-0.18, -0.02, 0.9), el_r=(-0.17, -0.15, 0.69), wr_r=(-0.02, -0.25, 0.53),
        sh_l=(0.19, -0.06, 0.9), el_l=(0.13, -0.19, 0.73), wr_l=(0.01, -0.27, 0.58),
        hip_r=(-0.09, 0.02, 0.47), kn_r=(-0.14, -0.1, 0.25), an_r=(-0.16, 0.0, 0.04),
        hip_l=(0.09, 0.02, 0.47), kn_l=(0.15, -0.1, 0.25), an_l=(0.18, 0.0, 0.04),
        head_turn=55, bat=((-0.0, -0.26, 0.55), (-0.11, -0.33, 0.02))),
    "bowler": dict(
        pelvis=(0, 0, 0.6), chest=(0, -0.03, 0.88), neck=(0, -0.04, 1.06),
        sh_r=(-0.18, -0.02, 0.99), el_r=(-0.21, 0.01, 1.19), wr_r=(-0.2, 0.05, 1.37),
        sh_l=(0.18, -0.05, 0.99), el_l=(0.21, -0.24, 1.07), wr_l=(0.22, -0.42, 1.13),
        hip_r=(-0.09, 0.03, 0.6), kn_r=(-0.11, 0.2, 0.33), an_r=(-0.12, 0.42, 0.12),
        hip_l=(0.09, -0.03, 0.6), kn_l=(0.1, -0.2, 0.33), an_l=(0.1, -0.3, 0.04),
        head_turn=0, ball=True),
    "umpire": dict(
        pelvis=(0, 0, 0.5), chest=(0, 0, 0.79), neck=(0, -0.01, 0.98),
        sh_r=(-0.19, 0, 0.91), el_r=(-0.23, -0.03, 1.1), wr_r=(-0.23, -0.05, 1.28),
        sh_l=(0.19, 0, 0.91), el_l=(0.24, 0.0, 0.71), wr_l=(0.25, -0.02, 0.53),
        hip_r=(-0.09, 0, 0.5), kn_r=(-0.1, -0.01, 0.27), an_r=(-0.11, 0, 0.04),
        hip_l=(0.09, 0, 0.5), kn_l=(0.1, -0.01, 0.27), an_l=(0.11, 0, 0.04),
        head_turn=0, finger=True),
}


def build(style, pose_name, skin_rgb, who, face="focused", head_only=False):
    st = STYLES[style]
    P = POSES[pose_name]
    hh = H * st["head"]
    N = H - hh
    J = {k: Vector(v) * N for k, v in P.items() if isinstance(v, tuple) and len(v) == 3}
    skin = mat("skin%d" % SKINS.index(skin_rgb), skin_rgb)
    kit = mat("kit", KIT) if who != "umpire" else mat("coat", (0.93, 0.93, 0.9))
    trim = mat("trim", TRIM)
    trousers = mat("cream", CREAM) if who != "umpire" else mat("dark", (0.12, 0.12, 0.15))
    black = mat("black", (0.03, 0.03, 0.04))
    white = mat("eyewhite", (0.98, 0.98, 0.96))
    objs = []
    if not head_only:
        # Torso: pelvis, chest, neck.
        objs.append(tubes("torso", [J["pelvis"], J["chest"], J["neck"]], [(0, 1), (1, 2)],
                          [st["pelvis"], st["chest"], (0.07, 0.07)], st, kit))
        objs.append(tubes("stripe", [J["pelvis"].lerp(J["chest"], 0.62), J["pelvis"].lerp(J["chest"], 0.72)], [(0, 1)],
                          [(st["chest"][0] * 1.02, st["chest"][1] * 1.02)] * 2, st, trim))
        if who == "umpire":
            # Coat: a flared skirt from the chest to below the hips.
            objs.append(tubes("coat", [J["chest"], J["pelvis"], J["pelvis"] - Vector((0, 0, 0.12 * N))], [(0, 1), (1, 2)],
                              [st["chest"], (st["pelvis"][0] * 1.15, st["pelvis"][1] * 1.2),
                               (st["pelvis"][0] * 1.25, st["pelvis"][1] * 1.3)], st, kit))
        for s in ("r", "l"):
            sh, el, wr = J["sh_" + s], J["el_" + s].copy(), J["wr_" + s].copy()
            sgn = -1 if s == "r" else 1
            rh0 = H * st["head"] / 2
            for v, k in ((el, 1.0), (wr, 1.15)):
                if v.z > J["neck"].z - 0.1:
                    v.x = sgn * max(abs(v.x), rh0 * k + st["upper"])
            J["el_" + s], J["wr_" + s] = el, wr
            inner = Vector((sh.x * 0.55, sh.y, sh.z - st["upper"] * 0.4))
            objs.append(tubes("shoulder_" + s, [inner, sh], [(0, 1)], [st["upper"] * 1.3, st["upper"] * 1.25], st, kit))
            # Short sleeve over a skin-coloured arm.
            objs.append(tubes("sleeve_" + s, [sh, sh.lerp(el, 0.55)], [(0, 1)], [st["upper"] * 1.25, st["upper"] * 1.2], st, kit))
            objs.append(tubes("arm_" + s, [sh, el, wr], [(0, 1), (1, 2)], [st["upper"], st["fore"], st["fore"] * 0.85], st, skin))
            glove = who == "batter"
            objs.append(ball("hand_" + s, wr + (wr - el).normalized() * st["hand"] * 0.6, st["hand"] * (1.2 if glove else 1.0),
                             st, mat("glove", CREAM) if glove else skin, scale=(1, 1, 1.15)))
            hip, kn, an = J["hip_" + s], J["kn_" + s], J["an_" + s]
            objs.append(tubes("leg_" + s, [hip, kn, an], [(0, 1), (1, 2)], [st["thigh"], st["shin"] * 1.05, st["shin"] * 0.8], st, trousers))
            fw, fl = st["foot"]
            fwd = Vector((0, -1, 0))
            objs.append(box("shoe_" + s, an + fwd * fl * 0.3 + Vector((0, 0, -0.01)), (fw, fl, 0.075), st,
                            mat("shoe", (0.96, 0.96, 0.96))))
            if who == "batter":
                # Pads: rounded slabs over the shins, with three ridges.
                q = along(kn, an)
                mid = kn.lerp(an, 0.45) + Vector((0, -st["shin"] * 0.6, 0))
                objs.append(box("pad_" + s, mid, (st["shin"] * 2.6, st["shin"] * 1.2, (kn - an).length * 1.25), st,
                                mat("pad", (0.98, 0.98, 0.96)), rot=q, bevel=0.45))
        if who == "batter":
            a, b = (Vector(P["bat"][0]) * N, Vector(P["bat"][1]) * N)
            q = along(a, b)
            d = (b - a).normalized()
            objs.append(rod("handle", a - d * 0.05, a + d * 0.24, 0.02, st, mat("grip", (0.1, 0.2, 0.55))))
            objs.append(box("blade", a + d * (0.24 + 0.29), (0.11, 0.045, 0.58), st, mat("wood", WOOD), rot=q, bevel=0.25))
        if P.get("ball"):
            ball("cricket_ball", J["wr_r"] + Vector((-0.02, -st["hand"] * 1.1, st["hand"] * 0.9)), 0.045, st, mat("red", (0.8, 0.06, 0.08)))
        if P.get("finger"):
            objs.append(rod("finger", J["wr_r"] + Vector((0, 0, 0.05)), J["wr_r"] + Vector((0, -0.01, 0.16)), 0.016, st, skin))
    # Head and face.
    rh = hh / 2
    hc = J["neck"] + Vector((0, 0, rh * 0.92))
    turn = math.radians(P.get("head_turn", 0))
    rot = Matrix.Rotation(turn, 4, "Z")
    fwd = (rot @ Vector((0, -1, 0)).to_4d()).to_3d()
    side = (rot @ Vector((1, 0, 0)).to_4d()).to_3d()
    up = Vector((0, 0, 1))
    head = ball("head", hc, rh, st, skin, scale=(0.95, 0.92, 1.0))
    for sgn in (-1, 1):
        ball("ear", hc + side * sgn * rh * 0.93, rh * 0.18, st, skin, scale=(0.5, 1, 1))
    e = st["eye"] * rh
    for sgn in (-1, 1):
        ec = hc + fwd * rh * 0.78 + side * sgn * rh * 0.36 + up * rh * 0.08
        ball("eye", ec, e, st, white, scale=(1, 0.6, 1.1))
        pup = ec + fwd * e * 0.55 + up * (e * 0.05 if face != "wince" else e * 0.15)
        ball("pupil", pup, st["pupil"] * rh, st, black, scale=(1, 0.5, 1.2))
        # Brows: tilt tells the mood.
        tilt = {"focused": -18, "joy": 12, "wince": 25}[face] * sgn
        bc = ec + up * (e * 1.25 + rh * 0.05) + fwd * rh * 0.06
        bl = rh * 0.32
        ang = math.radians(tilt)
        d = side * math.cos(ang) + up * math.sin(ang)
        rod("brow", bc - d * bl / 2, bc + d * bl / 2, rh * 0.055, st, black)
    ball("nose", hc + fwd * rh * 0.97 - up * rh * 0.12, rh * 0.12, st, skin, scale=(0.8, 1, 0.8))
    mc = hc + fwd * rh * 0.86 - up * rh * 0.42
    if face == "joy":
        # A big open grin: a dark half-moon with a tongue.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=rh * 0.26, location=mc)
        g = bpy.context.active_object
        g.scale = (1.2, 0.35, 0.75)
        bm = bmesh.new()
        bm.from_mesh(g.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.01], context="VERTS")
        bm.to_mesh(g.data)
        bm.free()
        finish(g, st, mat("mouth", (0.25, 0.04, 0.06)))
    elif face == "wince":
        rod("mouth", mc - side * rh * 0.2 + up * rh * 0.04, mc, rh * 0.04, st, black)
        rod("mouth2", mc, mc + side * rh * 0.2 - up * rh * 0.05, rh * 0.04, st, black)
    else:
        rod("mouth", mc - side * rh * 0.16, mc + side * rh * 0.16, rh * 0.035, st, black)
    # What's on the head.
    if who == "batter":
        helm = mat("helmet", NAVY)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8 if st["faceted"] else 24, ring_count=6 if st["faceted"] else 12,
                                             radius=rh * 1.1, location=hc + up * rh * 0.06)
        h = bpy.context.active_object
        bm = bmesh.new()
        bm.from_mesh(h.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -rh * 0.05], context="VERTS")
        bm.to_mesh(h.data)
        bm.free()
        h.rotation_euler = (0, 0, turn)
        finish(h, st, helm)
        box("peak", hc + fwd * rh * 1.0 + up * rh * 0.12, (rh * 1.2, rh * 0.5, rh * 0.06), st, helm,
            rot=Matrix.Rotation(turn, 4, "Z").to_quaternion(), bevel=0.2)
        for k in range(3):
            y = -rh * (0.15 + 0.22 * k)
            rod("grille", hc + fwd * rh * 1.04 + up * y - side * rh * 0.6, hc + fwd * rh * 1.04 + up * y + side * rh * 0.6,
                rh * 0.035, st, mat("steel", (0.75, 0.76, 0.8)))
    elif who == "bowler":
        cap = mat("kit", KIT)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8 if st["faceted"] else 24, ring_count=6 if st["faceted"] else 12,
                                             radius=rh * 1.03, location=hc + up * rh * 0.1)
        c = bpy.context.active_object
        bm = bmesh.new()
        bm.from_mesh(c.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < rh * 0.05], context="VERTS")
        bm.to_mesh(c.data)
        bm.free()
        finish(c, st, cap)
        box("peak", hc + fwd * rh * 0.95 + up * rh * 0.15, (rh * 1.1, rh * 0.6, rh * 0.06), st, cap, bevel=0.2)
    elif who == "umpire":
        hat = mat("hat", (0.96, 0.95, 0.9))
        rod("brim", hc + up * rh * 0.32, hc + up * rh * 0.36, rh * 1.75, st, hat, segs=32)
        rod("crown", hc + up * rh * 0.34, hc + up * rh * 0.95, rh * 0.85, st, hat, segs=24)
        rod("band", hc + up * rh * 0.36, hc + up * rh * 0.5, rh * 0.87, st, mat("kit", KIT), segs=24)
    return objs


def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)


for style in STYLES:
    for who, pose, skin in [("batter", "batter", SKINS[0]), ("bowler", "bowler", SKINS[1]), ("umpire", "umpire", SKINS[2])]:
        clear()
        _mats.clear()
        build(style, pose, skin, who)
        export(os.path.join(OUT, "%s_%s.glb" % (style, who)))
    for face in ("focused", "joy", "wince"):
        clear()
        _mats.clear()
        build(style, "umpire", SKINS[0], "face", face=face, head_only=True)
        export(os.path.join(OUT, "%s_face_%s.glb" % (style, face)))
print("exported to", OUT)
