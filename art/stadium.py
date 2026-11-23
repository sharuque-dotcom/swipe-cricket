"""Builds the low-poly stadium (style D) and exports it as .glb.

    blender -b -P art/stadium.py -- OUT.glb

Centred on the middle of the pitch, ground at z = 0. Blender +Y is toward the bowler's
end (the game's -Z). The boundary rope (65 m) and LED boards (69 m) stay in the game's
code; this is everything from the front wall outward: eight stands with gaps between them,
the pavilion and scoreboard behind the bowler, four floodlight towers and two dugouts.

Materials are named by role and coloured in game. "crowd" surfaces carry UVs for the
game's crowd shader: u runs once round the ground, v from 1 at the front row to 0 at the
back. "screen" is the scoreboard face; an empty named ScoreboardAnchor marks where the
game writes on it.
"""
import bpy
import bmesh
import math
import sys
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

COLOURS = {"crowd": (0.2, 0.25, 0.5), "concrete": (0.72, 0.72, 0.76), "concrete_dark": (0.38, 0.4, 0.47),
           "roof": (0.86, 0.88, 0.92), "roof_under": (0.3, 0.32, 0.38), "steel": (0.3, 0.32, 0.38),
           "accent": (0.12, 0.3, 0.75), "accent2": (0.96, 0.76, 0.12), "glass": (0.2, 0.34, 0.5),
           "screen": (0.04, 0.05, 0.08), "lamp": (0.95, 0.96, 1.0), "wood": (0.55, 0.38, 0.22),
           "turf": (0.25, 0.45, 0.22)}
MATS = {}
for k, c in COLOURS.items():
    m = bpy.data.materials.new(k)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*c, 1.0)
    MATS[k] = m


class Mesh:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def mat(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def quad(self, pts, mat, uvs=None):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.mat(mat)
        uvs = uvs or [(0, 0), (1, 0), (1, 1), (0, 1)][:len(pts)]
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        return f

    def box(self, centre, size, mat, rot_z=0.0, tilt=0.0):
        c = Vector(centre)
        sx, sy, sz = (s / 2 for s in size)
        R = Matrix.Rotation(rot_z, 3, "Z") @ Matrix.Rotation(tilt, 3, "X")
        corner = [R @ Vector((x, y, z)) + c for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for f in faces:
            self.quad([corner[i] for i in f], mat)

    def done(self):
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(MATS[m])
        ob = bpy.data.objects.new(self.name, me)
        scene.collection.objects.link(ob)
        return ob


def P(r, a, z):
    a = math.radians(a)
    return Vector((r * math.cos(a), r * math.sin(a), z))


STEP = 4.0   # degrees per facet: the stands read as flat panels


def strip(m, a0, a1, r0, z0, r1, z1, mat, v=None):
    """A band between two profile points (r, z), swept from angle a0 to a1."""
    n = max(1, int(round((a1 - a0) / STEP)))
    for i in range(n):
        b0 = a0 + (a1 - a0) * i / n
        b1 = a0 + (a1 - a0) * (i + 1) / n
        pts = [P(r0, b0, z0), P(r0, b1, z0), P(r1, b1, z1), P(r1, b0, z1)]
        if v is not None:
            u0, u1 = (b0 % 360) / 360.0, (b0 % 360 + (b1 - b0)) / 360.0
            m.quad(pts, mat, [(u0, v[0]), (u1, v[0]), (u1, v[1]), (u0, v[1])])
        else:
            m.quad(pts, mat)


def side(m, a, profile, mat):
    """Close the end of a stand: the polygon of its profile at angle a."""
    pts = [P(r, a, z) for r, z in profile]
    vs = [m.bm.verts.new(p) for p in pts]
    f = m.bm.faces.new(vs)
    f.material_index = m.mat(mat)


# ---- Stands --------------------------------------------------------------------------------
# Profile from the front wall to the back: lower tier, walkway, upper tier, roof.
LOWER = (71.0, 2.4, 83.0, 10.0)
UPPER = (85.0, 12.0, 97.0, 22.0)


def stand(a0, a1, accent):
    m = Mesh("Stand_%d" % int(a0))
    strip(m, a0, a1, 70.5, 0.0, 70.5, 2.4, "concrete_dark")                       # front wall
    strip(m, a0, a1, 70.5, 2.4, 71.0, 2.4, accent)                                # wall cap
    strip(m, a0, a1, *LOWER, "crowd", v=(1.0, 0.56))
    strip(m, a0, a1, 83.0, 10.0, 85.0, 10.0, "concrete")                          # walkway
    strip(m, a0, a1, 85.0, 10.0, 85.0, 12.0, accent)                              # upper tier front
    strip(m, a0, a1, *UPPER, "crowd", v=(0.5, 0.0))
    strip(m, a0, a1, 97.0, 22.0, 98.0, 25.0, "concrete")                          # back wall
    strip(m, a0, a1, 98.0, 25.0, 98.0, 0.0, "concrete_dark")                      # outside
    # Roof: a thin slab tipped toward the field, on posts at the back.
    strip(m, a0, a1, 81.0, 29.0, 100.0, 26.5, "roof")
    strip(m, a0, a1, 100.0, 26.0, 81.0, 28.4, "roof_under")
    strip(m, a0, a1, 81.0, 28.4, 81.0, 29.0, accent)
    prof = [(70.5, 0.0), (70.5, 2.4), (71.0, 2.4), (83.0, 10.0), (85.0, 10.0), (85.0, 12.0), (97.0, 22.0),
            (98.0, 25.0), (98.0, 0.0)]
    side(m, a0, prof, "concrete")
    side(m, a1, list(reversed(prof)), "concrete")
    for a in (a0 + 0.6, a1 - 0.6):
        side(m, a, [(81.0, 28.4), (100.0, 26.0), (100.0, 26.5), (81.0, 29.0)], "roof_under")
    n = max(2, int((a1 - a0) / 9))
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        c = P(98.6, a, 13.2)
        m.box(c, (0.7, 0.7, 26.4), "steel", rot_z=math.radians(a))
        # Stairways up the tiers.
        if 0 < i < n:
            for (r0, z0, r1, z1) in (LOWER, UPPER):
                for k in range(6):
                    t = (k + 0.5) / 6
                    m.box(P(r0 + (r1 - r0) * t, a, z0 + (z1 - z0) * t + 0.1), (1.6, 1.2, 0.25), "concrete",
                          rot_z=math.radians(a))
    return m.done()


# Stands all round except behind the bowler (around +Y, 90 degrees), where the pavilion is.
segments = [(112, 150), (154, 192), (196, 232), (236, 268), (272, 308), (312, 348), (352, 388), (392, 428)]
for i, (a0, a1) in enumerate(segments):
    stand(a0, a1, "accent" if i % 2 == 0 else "accent2")

# ---- Pavilion and scoreboard behind the bowler ----------------------------------------------
pav = Mesh("Pavilion")
A0, A1 = 70.0, 110.0
# Members' seats in front, then a two-storey building with a glass front.
strip(pav, A0, A1, 70.5, 0.0, 70.5, 2.4, "concrete_dark")
strip(pav, A0, A1, 71.0, 2.4, 77.0, 6.0, "crowd", v=(1.0, 0.7))
strip(pav, A0, A1, 77.0, 6.0, 77.0, 9.0, "glass")
strip(pav, A0, A1, 77.0, 9.0, 79.0, 9.0, "concrete")
strip(pav, A0, A1, 79.0, 9.0, 79.0, 10.0, "accent")
strip(pav, A0, A1, 79.0, 10.0, 79.0, 15.0, "glass")
strip(pav, A0, A1, 79.0, 15.0, 77.0, 16.0, "roof")
strip(pav, A0, A1, 77.0, 16.0, 88.0, 21.0, "roof")
strip(pav, A0, A1, 88.0, 21.0, 92.0, 16.0, "roof")
strip(pav, A0, A1, 92.0, 16.0, 92.0, 0.0, "concrete_dark")
side(pav, A0, [(70.5, 0.0), (70.5, 2.4), (71.0, 2.4), (77.0, 6.0), (77.0, 9.0), (79.0, 9.0), (79.0, 15.0), (77.0, 16.0),
               (88.0, 21.0), (92.0, 16.0), (92.0, 0.0)], "concrete")
side(pav, A1, list(reversed([(70.5, 0.0), (70.5, 2.4), (71.0, 2.4), (77.0, 6.0), (77.0, 9.0), (79.0, 9.0), (79.0, 15.0),
                             (77.0, 16.0), (88.0, 21.0), (92.0, 16.0), (92.0, 0.0)])), "concrete")
# Window mullions.
for i in range(21):
    a = A0 + (A1 - A0) * i / 20
    pav.box(P(77.05, a, 7.5), (0.25, 0.3, 3.0), "concrete", rot_z=math.radians(a))
    pav.box(P(79.05, a, 12.5), (0.25, 0.3, 5.0), "concrete", rot_z=math.radians(a))
# Clock tower and scoreboard on the roof, facing the field.
pav.box(P(86.0, 90, 25.0), (30.0, 2.0, 12.0), "concrete_dark", rot_z=math.radians(0))
pav.box(P(85.0, 90, 25.0), (28.0, 0.4, 10.0), "screen")
pav.box(P(86.0, 90, 31.4), (31.0, 2.4, 0.8), "accent")
for x in (-12.0, 12.0):
    pav.box(P(86.0, 90, 19.0) + Vector((x, 0, 0)), (0.8, 0.8, 6.0), "steel")
pav.done()
anchor = bpy.data.objects.new("ScoreboardAnchor", None)
anchor.location = P(84.7, 90, 25.0)
scene.collection.objects.link(anchor)

# ---- Floodlight towers ----------------------------------------------------------------------
for k, a in enumerate((45.0, 135.0, 225.0, 315.0)):
    t = Mesh("Floodlight_%d" % k)
    base = P(101.0, a, 0.0)
    rz = math.radians(a)
    # Tapered four-sided mast with cross bracing.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=1.6, radius2=0.7, depth=48.0,
                          matrix=Matrix.Translation(base + Vector((0, 0, 24.0))) @ Matrix.Rotation(rz + math.pi / 4, 4, "Z"))
    for f in bm.faces:
        t.quad([v.co.copy() for v in f.verts], "steel") if len(f.verts) == 4 else None
    bm.free()
    for h in range(6, 46, 8):
        t.box(base + Vector((0, 0, h)), (2.6 - h * 0.035, 2.6 - h * 0.035, 0.35), "concrete_dark", rot_z=rz)
    # Head frame tipped toward the field, rows of lamps.
    head = base + Vector((0, 0, 49.0)) - P(1.5, a, 0.0)
    t.box(head, (1.0, 13.0, 8.0), "steel", rot_z=rz, tilt=0.0)
    for row in range(3):
        for col in range(5):
            off = Vector((0, (col - 2) * 2.4, (row - 1) * 2.4))
            off = Matrix.Rotation(rz, 3, "Z") @ off
            t.box(head + off - P(0.6, a, 0.0), (0.5, 2.0, 2.0), "lamp", rot_z=rz)
    t.done()

# ---- Dugouts, square of the wicket inside the boards ---------------------------------------
for a in (0.0, 180.0):
    d = Mesh("Dugout_%d" % int(a))
    rz = math.radians(a)
    c = P(67.4, a, 0.0)
    d.box(c + Vector((0, 0, 1.25)) + P(0.9, a, 0), (0.25, 7.0, 2.5), "concrete_dark", rot_z=rz)   # back
    d.box(c + Vector((0, 0, 2.55)), (2.4, 7.4, 0.2), "accent", rot_z=rz, tilt=0.0)                 # roof
    d.box(c + Vector((0, 0, 0.45)) + P(0.4, a, 0), (0.6, 6.4, 0.15), "wood", rot_z=rz)             # bench
    for y in (-3.5, 3.5):
        off = Matrix.Rotation(rz, 3, "Z") @ Vector((0, y, 1.25))
        d.box(c + off, (2.2, 0.2, 2.5), "glass", rot_z=rz)
    d.done()

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True,
                          export_texcoords=True, export_normals=False)
print("exported", OUT)
