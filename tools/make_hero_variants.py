"""Build the 10 hero kaiju in assets/heroes from Quaternius' CC0 T-Rex (poly.pizza/m/UYtneO5FpF).

Exports a .glb per variant (rig + animations) and renders a preview .png.

Usage: python3 -I tools/make_hero_variants.py <fbx> <outdir> [variant-ids...]
"""
import bpy, bmesh, math, sys, os, random
from mathutils import Vector, Matrix
from mathutils.geometry import intersect_point_line

FBX, OUT = sys.argv[1], sys.argv[2]
ONLY = sys.argv[3:]
RENDER = os.environ.get("NO_RENDER") != "1"
SAMPLES = int(os.environ.get("SAMPLES", "48"))

SPINE = ["Tail5", "Tail4", "Tail3", "Tail2", "Tail1", "Back", "Hips", "Torso", "Shoulders", "Neck", "Head"]
SPINE_PATH = ["Tail5_end", "Tail5", "Tail4", "Tail3", "Tail2", "Tail1", "Back", "Hips", "Torso", "Shoulders", "Neck", "Head"]


def V(*a):
    return Vector(a)


# ---------------------------------------------------------------- variants
VARIANTS = [
    dict(id="01_atom", name="Atom-Kojira", body=(0.025, 0.03, 0.035), belly=(0.08, 0.085, 0.09), claws=(0.02, 0.02, 0.02),
         eyes=((0.3, 0.75, 1.0), 6), arms=1.5, head=1.0, tail=1.15,
         rows=[dict(shape="plate", x=0.0, count=15, h=3.4, w=1.35, s0=0.08, s1=0.86, mat="glow"),
               dict(shape="plate", x=0.45, count=13, h=1.7, w=1.05, s0=0.22, s1=0.82, tilt=22, mat="glow")],
         mats=dict(glow=dict(color=(0.3, 0.6, 1.0), emit=(0.15, 0.5, 1.0), strength=2.2))),
    dict(id="02_magma", name="Magma-Rex", body=(0.03, 0.008, 0.006), belly=(0.65, 0.16, 0.02), claws=(0.02, 0.01, 0.01),
         eyes=((1.0, 0.75, 0.1), 8), arms=1.3, head=1.1, tail=1.0,
         rows=[dict(shape="cone", x=0.0, count=15, h=2.6, w=0.9, s0=0.06, s1=0.84, mat="lava"),
               dict(shape="cone", x=0.5, count=10, h=1.2, w=0.8, s0=0.3, s1=0.8, tilt=35, mat="rock")],
         horns=[dict(u=0.25, x=0.6, len=3.0, r=0.45, dir=(0.55, 0.55, 0.65), bend=0.5, mat="rock")],
         mats=dict(lava=dict(color=(1.0, 0.35, 0.05), emit=(1.0, 0.3, 0.02), strength=6),
                   rock=dict(color=(0.05, 0.04, 0.04), rough=0.9))),
    dict(id="03_frost", name="Frost-Kojira", body=(0.45, 0.6, 0.75), belly=(0.85, 0.9, 0.95), claws=(0.15, 0.25, 0.4),
         eyes=((0.2, 0.9, 1.0), 6), arms=1.2, head=1.0, tail=1.1,
         rows=[dict(shape="crystal", x=0.0, count=16, h=3.0, w=0.8, s0=0.06, s1=0.85, jitter=0.35, mat="ice"),
               dict(shape="crystal", x=0.5, count=12, h=1.6, w=0.7, s0=0.25, s1=0.8, tilt=30, jitter=0.4, mat="ice")],
         mats=dict(ice=dict(color=(0.6, 0.9, 1.0), emit=(0.3, 0.8, 1.0), strength=1.2, rough=0.1))),
    dict(id="04_panser", name="Panser-Rex", body=(0.12, 0.13, 0.08), belly=(0.35, 0.3, 0.2), claws=(0.05, 0.05, 0.05),
         eyes=((1.0, 0.1, 0.05), 6), arms=1.4, head=1.15, tail=1.0,
         rows=[dict(shape="shield", x=0.0, count=11, h=1.4, w=1.6, s0=0.12, s1=0.82, mat="armor"),
               dict(shape="shield", x=0.55, count=9, h=1.0, w=1.5, s0=0.25, s1=0.78, tilt=55, mat="armor"),
               dict(shape="cone", x=0.0, count=6, h=1.4, w=0.5, s0=0.02, s1=0.18, mat="armor")],
         horns=[dict(u=0.78, x=0.0, len=2.2, r=0.5, dir=(0.0, -0.45, 0.9), bend=0.4, mat="armor"),
                dict(u=0.1, x=0.7, len=1.6, r=0.35, dir=(0.8, 0.3, 0.3), bend=0.2, mat="armor")],
         mats=dict(armor=dict(color=(0.35, 0.36, 0.38), metal=0.85, rough=0.35))),
    dict(id="05_meka", name="Meka-Rex", body=(0.55, 0.57, 0.6), body_metal=0.9, belly=(0.08, 0.08, 0.09), claws=(0.6, 0.05, 0.03),
         eyes=((1.0, 0.05, 0.02), 10), arms=1.6, head=1.0, tail=1.0,
         rows=[dict(shape="blade", x=0.0, count=12, h=2.4, w=0.8, s0=0.1, s1=0.84, mat="red"),
               dict(shape="blade", x=0.5, count=8, h=1.2, w=0.7, s0=0.3, s1=0.78, tilt=40, mat="steel")],
         horns=[dict(u=0.15, x=0.55, len=1.8, r=0.18, dir=(0.25, 0.7, 0.65), bend=0.0, mat="red", sides=4)],
         mats=dict(red=dict(color=(1.0, 0.08, 0.03), emit=(1.0, 0.05, 0.02), strength=4),
                   steel=dict(color=(0.3, 0.3, 0.33), metal=1.0, rough=0.3))),
    dict(id="06_gift", name="Gift-Kojira", body=(0.12, 0.02, 0.16), belly=(0.35, 0.6, 0.05), claws=(0.02, 0.02, 0.02),
         eyes=((0.4, 1.0, 0.1), 8), arms=1.25, head=1.0, tail=1.3,
         rows=[dict(shape="cone", x=0.25, count=20, h=2.0, w=0.55, s0=0.03, s1=0.86, tilt=12, mat="tox"),
               dict(shape="cone", x=0.6, count=14, h=1.0, w=0.5, s0=0.15, s1=0.8, tilt=40, mat="tox")],
         mats=dict(tox=dict(color=(0.45, 1.0, 0.15), emit=(0.35, 1.0, 0.05), strength=4))),
    dict(id="07_storm", name="Storm-Rex", body=(0.015, 0.03, 0.1), belly=(0.25, 0.3, 0.4), claws=(0.02, 0.02, 0.02),
         eyes=((1.0, 1.0, 0.6), 8), arms=1.35, head=1.05, tail=1.1,
         rows=[dict(shape="zigzag", x=0.0, count=12, h=3.0, w=1.2, s0=0.08, s1=0.86, mat="volt")],
         horns=[dict(u=0.2, x=0.6, len=3.2, r=0.35, dir=(0.35, 0.85, 0.35), bend=0.0, mat="volt"),
                dict(u=0.35, x=0.75, len=2.0, r=0.25, dir=(0.75, 0.6, 0.15), bend=0.0, mat="volt")],
         mats=dict(volt=dict(color=(1.0, 0.85, 0.1), emit=(1.0, 0.8, 0.05), strength=5))),
    dict(id="08_jungle", name="Jungle-Rex", body=(0.04, 0.12, 0.02), belly=(0.45, 0.33, 0.15), claws=(0.05, 0.03, 0.02),
         eyes=((1.0, 0.6, 0.0), 5), arms=1.8, head=1.0, tail=0.95,
         rows=[dict(shape="leaf", x=0.0, count=9, h=4.2, w=1.5, s0=0.2, s1=0.8, mat="sail"),
               dict(shape="cone", x=0.0, count=6, h=1.0, w=0.6, s0=0.03, s1=0.19, mat="dark")],
         horns=[dict(u=0.1, x=0.75, len=1.8, r=0.5, dir=(0.95, 0.25, 0.2), bend=0.0, mat="sail", flat=True)],
         mats=dict(sail=dict(color=(0.8, 0.22, 0.04), rough=0.6), dark=dict(color=(0.03, 0.06, 0.02)))),
    dict(id="09_knogle", name="Knogle-Rex", body=(0.62, 0.56, 0.45), belly=(0.3, 0.25, 0.18), claws=(0.02, 0.02, 0.02),
         eyes=((1.0, 0.05, 0.05), 8), arms=1.3, head=1.2, tail=1.05,
         rows=[dict(shape="cone", x=0.0, count=14, h=2.0, w=0.75, s0=0.04, s1=0.86, mat="bone"),
               dict(shape="cone", x=0.55, count=9, h=1.1, w=0.6, s0=0.3, s1=0.8, tilt=50, mat="bone")],
         horns=[dict(u=0.18, x=0.65, len=3.2, r=0.5, dir=(0.6, 0.1, 0.8), bend=-0.9, mat="dark"),
                dict(u=0.7, x=0.45, len=1.0, r=0.25, dir=(0.4, -0.2, 0.9), bend=0.0, mat="dark")],
         mats=dict(bone=dict(color=(0.25, 0.18, 0.12), rough=0.8), dark=dict(color=(0.02, 0.02, 0.02), rough=0.5))),
    dict(id="10_konge", name="Guld-Kongen", body=(0.7, 0.45, 0.08), body_metal=0.75, belly=(0.85, 0.8, 0.6), claws=(0.05, 0.03, 0.08),
         eyes=((0.7, 0.3, 1.0), 8), arms=1.45, head=1.1, tail=1.0,
         rows=[dict(shape="plate", x=0.0, count=14, h=2.6, w=1.1, s0=0.1, s1=0.85, mat="gem"),
               dict(shape="plate", x=0.45, count=10, h=1.4, w=1.0, s0=0.28, s1=0.8, tilt=25, mat="gem")],
         horns=[dict(u=0.12, x=0.35 * math.cos(a), xoff=True, len=1.3, r=0.22, dir=(0.4 * math.cos(a), 0.3, 1.0), bend=0.0, mat="gem")
                for a in (0.0, math.pi)] +
               [dict(u=u, x=0.55, len=1.1, r=0.2, dir=(0.45, 0.25, 1.0), bend=0.0, mat="gem") for u in (0.02, 0.22)],
         mats=dict(gem=dict(color=(0.55, 0.15, 0.9), emit=(0.45, 0.1, 1.0), strength=3, rough=0.15))),
]


# ---------------------------------------------------------------- helpers
def material(name, color, metal=0.0, rough=0.55, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    nt = m.node_tree if m.node_tree else None
    if nt is None:
        m.use_nodes = True
        nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def set_color(m, color, metal=None, rough=None):
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    if metal is not None:
        p.inputs["Metallic"].default_value = metal
    if rough is not None:
        p.inputs["Roughness"].default_value = rough


def scale_chain(arm, mesh, bones, pivot_bone, s, axis_only=None):
    """Scale a bone chain (rest pose) and its skinned vertices around pivot_bone's head."""
    if abs(s - 1) < 1e-4:
        return
    aw = arm.matrix_world
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    piv_l = eb[pivot_bone].head.copy()
    # remember originals so connected bones don't get scaled twice
    orig = {b: (eb[b].head.copy(), eb[b].tail.copy()) for b in bones if b in eb}
    for b, (h, t) in orig.items():
        eb[b].head = piv_l + (h - piv_l) * s
        eb[b].tail = piv_l + (t - piv_l) * s
    bpy.ops.object.mode_set(mode="OBJECT")
    piv = aw @ piv_l
    idx = {mesh.vertex_groups[b].index for b in bones if b in mesh.vertex_groups}
    mw, mwi = mesh.matrix_world, mesh.matrix_world.inverted()
    for v in mesh.data.vertices:
        w = min(1.0, sum(g.weight for g in v.groups if g.group in idx))
        if w > 0:
            p = mw @ v.co
            v.co = mwi @ (p + (p - piv) * (s - 1) * w)


def bone_seg(arm, name):
    b = arm.data.bones[name]
    return arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local


def spine_points(arm):
    pts = []
    t5 = bone_seg(arm, "Tail5_end")
    pts.append(t5[1])
    for n in SPINE_PATH:
        pts.append(bone_seg(arm, n)[0])
    pts.append(bone_seg(arm, "Head")[1] * 0.5 + bone_seg(arm, "Head")[0] * 0.5)
    return pts  # tail tip -> mid head


def sample_path(pts, s):
    lens = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(lens)
    d = s * total
    for i, L in enumerate(lens):
        if d <= L or i == len(lens) - 1:
            f = min(1.0, d / L) if L > 0 else 0
            p = pts[i].lerp(pts[i + 1], f)
            t = (pts[i + 1] - pts[i]).normalized()
            return p, t, total
        d -= L


def nearest_bone(arm, p, names):
    best, bd = None, 1e9
    for n in names:
        h, t = bone_seg(arm, n)
        q, f = intersect_point_line(p, h, t)
        f = max(0.0, min(1.0, f))
        q = h.lerp(t, f)
        d = (q - p).length
        if d < bd:
            best, bd = n, d
    return best


def surface_hit(mesh, origin_xy_z, side_x):
    """Ray down from above onto the mesh at (x, y). Returns (location, normal) in world."""
    o = Vector((side_x, origin_xy_z.y, origin_xy_z.z + 25))
    mwi = mesh.matrix_world.inverted()
    ok, loc, nrm, _ = mesh.ray_cast(mwi @ o, Vector((0, 0, -1)))
    if not ok:
        return None
    return mesh.matrix_world @ loc, (mesh.matrix_world.to_3x3() @ nrm).normalized()


def width_at(mesh, p):
    """Half width of the body at the spine point p (ray from the side)."""
    mwi = mesh.matrix_world.inverted()
    ok, loc, _, _ = mesh.ray_cast(mwi @ Vector((30, p.y, p.z)), Vector((-1, 0, 0)))
    return abs((mesh.matrix_world @ loc).x) if ok else 1.0


def poly2d(shape, rng, jitter=0.0):
    """2D outline in (u along body, v up), base from u=-0.5..0.5, height 1."""
    if shape == "plate":  # kaiju dorsal plate
        return [(-0.5, 0), (0.5, 0), (0.42, 0.45), (0.12, 0.8), (-0.05, 1.0), (-0.22, 0.72), (-0.45, 0.4)]
    if shape == "blade":
        return [(-0.5, 0), (0.5, 0), (0.15, 1.0), (-0.25, 1.0)]
    if shape == "zigzag":
        return [(-0.5, 0), (0.5, 0), (0.3, 0.35), (0.45, 0.42), (0.1, 0.72), (0.25, 0.75), (-0.15, 1.0), (-0.1, 0.62),
                (-0.3, 0.6), (-0.15, 0.32), (-0.35, 0.3)]
    if shape == "leaf":
        n = 9
        return [(-0.5, 0), (0.5, 0)] + [(0.5 * math.cos(math.pi * i / n) * (1 - 0.15 * (i % 2)),
                                          0.35 + 0.65 * math.sin(math.pi * i / n) * (1 - 0.12 * (i % 2)))
                                         for i in range(1, n)]
    raise ValueError(shape)


def add_prism(bm, outline, base, T, U, S, length, height, thick, bevel_top=0.35):
    """Extrude a 2D outline (u,v) into a thin wedge: full thickness at base, thinner at top."""
    ring_a, ring_b = [], []
    for u, v in outline:
        th = thick * (1 - bevel_top * v)
        c = base + T * (u * length) + U * (v * height)
        ring_a.append(bm.verts.new(c + S * th))
        ring_b.append(bm.verts.new(c - S * th))
    bm.faces.new(ring_a)
    bm.faces.new(list(reversed(ring_b)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([ring_a[i], ring_b[i], ring_b[j], ring_a[j]])
    return ring_a + ring_b


def add_cone(bm, base, axis, length, radius, sides=6, bend=0.0, side_vec=None, rings=4, flat=False):
    axis = axis.normalized()
    side = (side_vec or axis.orthogonal()).normalized()
    side = (side - axis * side.dot(axis)).normalized()
    up2 = axis.cross(side).normalized()
    verts_rings = []
    p = base.copy()
    d = axis.copy()
    for r in range(rings):
        f = r / rings
        rad = radius * (1 - f) ** 0.9
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            sx = math.cos(a) * rad * (0.35 if flat else 1)
            sy = math.sin(a) * rad
            ring.append(bm.verts.new(p + side * sx + up2 * sy))
        verts_rings.append(ring)
        d = (d + up2 * bend * (1.0 / rings)).normalized()
        p = p + d * (length / rings)
    tip = bm.verts.new(p)
    bm.faces.new(list(reversed(verts_rings[0])))
    for r in range(rings - 1):
        a, b = verts_rings[r], verts_rings[r + 1]
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new([a[k], a[j], b[j], b[k]])
    last = verts_rings[-1]
    for k in range(sides):
        bm.faces.new([last[k], last[(k + 1) % sides], tip])


def add_shield(bm, base, T, U, S, length, height, width):
    """Low rounded armour scute (half ellipsoid-ish)."""
    segs, rings = 8, 3
    grid = []
    for r in range(rings + 1):
        f = r / rings
        h = height * math.sin(f * math.pi / 2) + 0.05
        sc = math.cos(f * math.pi / 2) * 0.95 + 0.05
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ring.append(bm.verts.new(base + T * (math.cos(a) * length * 0.5 * sc) + S * (math.sin(a) * width * 0.5 * sc) + U * h))
        grid.append(ring)
    bm.faces.new(list(reversed(grid[0])))
    for r in range(rings):
        a, b = grid[r], grid[r + 1]
        for k in range(segs):
            j = (k + 1) % segs
            bm.faces.new([a[k], a[j], b[j], b[k]])
    bm.faces.new(grid[-1])


def new_part(name, bm, bone, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    for p in me.polygons:
        p.use_smooth = False
    return ob


# ---------------------------------------------------------------- build
def build(var):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=FBX)
    arm = bpy.data.objects["Armature"]
    mesh = bpy.data.objects["Trex"]
    arm.data.pose_position = "REST"
    for a in bpy.data.actions:
        a.name = a.name.split("|")[-1].replace("TRex_", "")
    rng = random.Random(var["id"])

    # proportions
    for side in "LR":
        chain = [f"FrontLeg.{side}", f"FrontUpLeg.{side}", f"FrontLowLeg.{side}", f"FrontFoot.{side}", f"FrontFoot.{side}_end"]
        scale_chain(arm, mesh, chain, chain[0], var.get("arms", 1))
    scale_chain(arm, mesh, ["Head", "Head_end"], "Head", var.get("head", 1))
    scale_chain(arm, mesh, ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail5_end"], "Tail1", var.get("tail", 1))
    mesh.data.update()

    # recolour
    mats = {m.name: m for m in mesh.data.materials}
    for m in mats.values():
        pb = m.node_tree.nodes.get("Principled BSDF")
        pb.inputs["Alpha"].default_value = 1.0
        for l in list(m.node_tree.links):
            if l.to_socket == pb.inputs["Alpha"]:
                m.node_tree.links.remove(l)
        m.blend_method = "OPAQUE" if hasattr(m, "blend_method") else None
    set_color(mats["Green"], var["body"], metal=var.get("body_metal", 0.0), rough=0.45 if var.get("body_metal") else 0.6)
    set_color(mats["LightGreen"], var["belly"])
    set_color(mats["Black"], var["claws"])
    eye_mat = material("Eyes", var["eyes"][0], emit=var["eyes"][0], strength=var["eyes"][1])
    hs, he = bone_seg(arm, "Head")
    head_end = bone_seg(arm, "Head_end")[1]
    eye_parts = []
    q = hs.lerp(head_end, 0.3)
    top = surface_hit(mesh, q, 0.0)
    ez = (top[0].z if top else q.z + 1.0) - 0.75 * var.get("head", 1)
    mwi = mesh.matrix_world.inverted()
    for sign in (1, -1):
        ok, loc, nrm, _ = mesh.ray_cast(mwi @ Vector((sign * 30, q.y, ez)), Vector((-sign, 0, 0)))
        if not ok:
            continue
        loc = mesh.matrix_world @ loc
        bm = bmesh.new()
        r = 0.42 * var.get("head", 1)
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r, matrix=Matrix.Translation(loc + Vector((-sign * r * 0.35, 0, 0))))
        eye_parts.append(new_part(f"eye_{sign}", bm, "Head", eye_mat))
        for pp in eye_parts[-1].data.polygons:
            pp.use_smooth = True
    part_mats = {k: material(f"{var['id']}_{k}", v["color"], v.get("metal", 0.0), v.get("rough", 0.5), v.get("emit"), v.get("strength", 0.0))
                 for k, v in var["mats"].items()}
    parts = list(eye_parts)
    pts = spine_points(arm)
    for row in var["rows"]:
        n = row["count"]
        _, _, total = sample_path(pts, 0)
        spacing = total * (row["s1"] - row["s0"]) / n
        for i in range(n):
            s = row["s0"] + (row["s1"] - row["s0"]) * (i + 0.5) / n
            p, T, _ = sample_path(pts, s)
            f = (s - row["s0"]) / (row["s1"] - row["s0"])
            prof = 0.3 + 0.7 * math.sin(math.pi * min(1, max(0, (f * 0.85 + 0.08)))) ** 1.3
            h = row["h"] * prof * (1 + rng.uniform(-row.get("jitter", 0.05), row.get("jitter", 0.05)))
            half_w = width_at(mesh, p)
            for sign in ([1, -1] if row["x"] > 0 else [0]):
                x = sign * row["x"] * half_w
                hit = surface_hit(mesh, p, x)
                if not hit:
                    continue
                loc, nrm = hit
                U = (V(0, 0, 1) * 0.6 + nrm * 0.4).normalized()
                tilt = math.radians(row.get("tilt", 0)) * sign
                U = (Matrix.Rotation(tilt, 3, T) @ U).normalized() if sign else U
                Tt = (T - U * T.dot(U)).normalized()
                S = Tt.cross(U).normalized()
                base = loc - U * 0.25
                bm = bmesh.new()
                shape = row["shape"]
                L = spacing * row["w"] * (0.85 if sign else 1.0)
                if shape in ("plate", "blade", "zigzag", "leaf"):
                    add_prism(bm, poly2d(shape, rng), base, Tt, U, S, L, h, max(0.12, L * 0.09))
                elif shape == "cone":
                    ax = (U - Tt * 0.35).normalized()
                    add_cone(bm, base, ax, h, L * 0.45, sides=6, bend=0.25, side_vec=S)
                elif shape == "crystal":
                    ax = (U + S * rng.uniform(-0.3, 0.3) + Tt * rng.uniform(-0.4, 0.0)).normalized()
                    add_cone(bm, base, ax, h, L * 0.4, sides=4, rings=1)
                    ax2 = (ax + S * rng.uniform(-0.6, 0.6)).normalized()
                    add_cone(bm, base + Tt * L * 0.2, ax2, h * 0.55, L * 0.25, sides=4, rings=1)
                elif shape == "shield":
                    add_shield(bm, base + U * 0.2, Tt, U, S, L, h, L * 0.8)
                bone = nearest_bone(arm, loc, SPINE)
                parts.append(new_part(f"{shape}_{len(parts)}", bm, bone, part_mats[row["mat"]]))

    # horns on the head: u = 0 at back of skull, 1 at snout
    hs, he = bone_seg(arm, "Head")
    head_end = bone_seg(arm, "Head_end")[1]
    for hn in var.get("horns", []):
        q = hs.lerp(head_end, hn["u"] * 0.8)
        for sign in ([1, -1] if hn["x"] > 0.01 else [0] if abs(hn["x"]) <= 0.01 else [1]):
            if hn.get("xoff"):
                sign = 1
            x = sign * hn["x"] * width_at(mesh, q)
            hit = surface_hit(mesh, q, x)
            if not hit:
                continue
            loc, nrm = hit
            dx, dy, dz = hn["dir"]
            ax = V(dx * (sign or 1), dy, dz).normalized()
            bm = bmesh.new()
            add_cone(bm, loc - ax * 0.3, ax, hn["len"] * var.get("head", 1), hn["r"] * var.get("head", 1),
                     sides=hn.get("sides", 6), bend=hn.get("bend", 0) * (1 if dy >= 0 else -1),
                     side_vec=V(0, 1, 0) if abs(ax.y) < 0.9 else V(1, 0, 0), flat=hn.get("flat", False))
            parts.append(new_part(f"horn_{len(parts)}", bm, "Head", part_mats[hn["mat"]]))
            if hn.get("xoff"):
                break

    # merge parts into the skinned mesh
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.join()
    mesh.name = var["name"].replace(" ", "_")
    arm.data.pose_position = "POSE"
    arm.name = var["name"].replace(" ", "_") + "_Rig"
    print(var["id"], "tris", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
    return arm, mesh


def export(arm, mesh, path):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIONS", export_apply=False)


def render(arm, mesh, path, action="Idle", frame=20):
    sc = bpy.context.scene
    if arm.animation_data is None:
        arm.animation_data_create()
    act = bpy.data.actions.get(action)
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
    sc.frame_set(frame)
    # world + ground
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.32, 0.38, 0.48, 1)
    bg.inputs[1].default_value = 0.6
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=60, fill_type="NGON", location=(0, 0, -0.08))
    g = bpy.context.active_object
    g.data.materials.append(material("Ground", (0.16, 0.17, 0.19), rough=0.9))
    # lights
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(-10), math.radians(-140))
    sc.collection.objects.link(sun)
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
    rim.data.energy = 2.0
    rim.data.color = (0.7, 0.8, 1.0)
    rim.data.use_shadow = False
    rim.rotation_euler = (math.radians(60), 0, math.radians(20))
    sc.collection.objects.link(rim)
    # camera: 3/4 front, a bit low
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    sc.camera = cam
    target = V(0, -1.0, 7.5)
    cam.location = target + V(-30, -38, 4) * 1.05
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 960, 720
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


os.makedirs(OUT, exist_ok=True)
for var in VARIANTS:
    if ONLY and var["id"] not in ONLY:
        continue
    arm, mesh = build(var)
    export(arm, mesh, os.path.join(OUT, f"{var['id']}.glb"))
    if RENDER:
        render(arm, mesh, os.path.join(OUT, f"{var['id']}.png"))
