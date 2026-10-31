"""Núcleo do gerador de modelos do Star-RTS (Blender 5.x).

Cada modelo é montado com primitivas (caixas chanfradas, cilindros, esferas, toros...)
em "grupos": cada grupo vira um Empty no pivô + uma malha filha, para o jogo girar
partes (torre, pernas, asas...). Localizadores são Empties "loc_<nome>".

Eixos do Blender: X = frente do modelo, Y = esquerda, Z = cima. 1 unidade = 1 célula.
No glTF/Godot: X = frente, Y = cima, Z = direita (o exportador converte).
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# Papéis dos materiais. O jogo usa o nome para decidir detalhes no shader:
# hull/dark/metal ganham linhas de painel, chitin/flesh/bone ganham textura orgânica,
# team recebe a cor do time, glow/engine/glass/crystal brilham.
ROLES = ("hull", "dark", "metal", "team", "accent", "glow", "engine", "glass",
         "chitin", "flesh", "bone", "crystal", "rock", "plant")


def _v(t):
    return Vector(t) if not isinstance(t, Vector) else t


class Part:
    """Uma malha em construção (um grupo do modelo). Coordenadas absolutas do modelo."""

    def __init__(self, model, name, pivot, parent):
        self.model = model
        self.name = name
        self.pivot = _v(pivot)
        self.parent = parent
        self.bm = bmesh.new()

    # ------------------------------------------------------------ utilitários

    def _mat_index(self, mat):
        return self.model.mat_index(mat)

    def _place(self, verts, mat, center, rot, scale=None):
        m = Matrix.Translation(_v(center)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
        if scale is not None:
            m = m @ Matrix.Diagonal((*scale, 1.0))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        idx = self._mat_index(mat)
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = idx
            f.smooth = True

    def _bevel(self, verts, offset, segments=2, only_flat=False):
        if offset <= 0:
            return verts
        vs = set(verts)
        edges = [e for e in self.bm.edges if e.verts[0] in vs and e.verts[1] in vs]
        if only_flat:
            edges = [e for e in edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
        res = bmesh.ops.bevel(self.bm, geom=list(vs) + edges, offset=offset, segments=segments,
                              profile=0.5, affect="EDGES", clamp_overlap=True)
        out = set(verts)
        for f in res.get("faces", []):
            out.update(f.verts)
        out.update(v for v in res.get("verts", []))
        return [v for v in out if v.is_valid]

    # ------------------------------------------------------------ primitivas

    def box(self, c, s, mat, bev=0.0, rot=(0, 0, 0), taper=None, shift=None, seg=2):
        """Caixa de tamanho s centrada em c. taper=(tx, ty) estreita o topo;
        shift=(dx, dy) desloca o topo (rampas, frentes inclinadas)."""
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = r["verts"]
        for v in verts:
            v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
            if v.co.z > 0:
                if taper:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
                if shift:
                    v.co.x += shift[0]
                    v.co.y += shift[1]
        verts = self._bevel(verts, min(bev, min(s) * 0.45), seg)
        self._place(verts, mat, c, rot)
        return self

    def cyl(self, c, r, h, mat, axis="z", seg=20, r2=None, bev=0.0, rot=(0, 0, 0)):
        """Cilindro (ou tronco de cone com r2) de altura h ao longo de `axis`."""
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r if r2 is None else r2, depth=h)
        verts = res["verts"]
        if bev > 0 and (r2 is None or r2 > 0):
            verts = self._bevel(verts, min(bev, h * 0.4, r * 0.4), 2, only_flat=True)
        base = {"z": (0, 0, 0), "x": (0, 90, 0), "y": (90, 0, 0)}[axis]
        m = Euler([math.radians(a) for a in base], "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        self._place(verts, mat, c, rot)
        return self

    def cone(self, c, r, h, mat, axis="z", seg=20, rot=(0, 0, 0)):
        return self.cyl(c, r, h, mat, axis, seg, r2=0.0, rot=rot)

    def sphere(self, c, r, mat, seg=20, rings=12, rot=(0, 0, 0)):
        """Esfera/elipsoide; r pode ser número ou (rx, ry, rz)."""
        if isinstance(r, (int, float)):
            r = (r, r, r)
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0)
        self._place(res["verts"], mat, c, rot, scale=r)
        return self

    def ico(self, c, r, mat, sub=2, rough=0.0, seed=0, rot=(0, 0, 0), flat_bottom=False):
        """Icosfera, com deslocamento aleatório (rochas) se rough > 0."""
        if isinstance(r, (int, float)):
            r = (r, r, r)
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0)
        rnd = random.Random(seed)
        for v in res["verts"]:
            k = 1.0 + rnd.uniform(-rough, rough)
            v.co *= k
            if flat_bottom and v.co.z < -0.25:
                v.co.z = -0.25 - (v.co.z + 0.25) * 0.1
        self._place(res["verts"], mat, c, rot, scale=r)
        return self

    def torus(self, c, R, r, mat, seg=32, seg2=10, rot=(0, 0, 0), scale_z=1.0):
        bm = self.bm
        rings = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring = []
            for j in range(seg2):
                b = 2 * math.pi * j / seg2
                x = (R + r * math.cos(b)) * math.cos(a)
                y = (R + r * math.cos(b)) * math.sin(a)
                z = r * math.sin(b) * scale_z
                ring.append(bm.verts.new((x, y, z)))
            rings.append(ring)
        verts = [v for ring in rings for v in ring]
        for i in range(seg):
            for j in range(seg2):
                a = rings[i][j]
                b = rings[(i + 1) % seg][j]
                cc = rings[(i + 1) % seg][(j + 1) % seg2]
                d = rings[i][(j + 1) % seg2]
                bm.faces.new((a, b, cc, d))
        self._place(verts, mat, c, rot)
        return self

    def tube(self, a, b, r, mat, seg=12, r2=None):
        """Cilindro ligando os pontos a e b (pernas, canos, tentáculos)."""
        a, b = _v(a), _v(b)
        d = b - a
        length = d.length
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r if r2 is None else r2, depth=length)
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=m, verts=res["verts"])
        idx = self._mat_index(mat)
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.material_index = idx
            f.smooth = True
        return self

    def prism(self, c, pts, h, mat, rot=(0, 0, 0), bev=0.0, taper=1.0):
        """Prisma de base poligonal (lista de (x, y)) e altura h, centrado em c."""
        bm = self.bm
        bot = [bm.verts.new((x, y, -h / 2)) for x, y in pts]
        top = [bm.verts.new((x * taper, y * taper, h / 2)) for x, y in pts]
        n = len(pts)
        bm.faces.new(list(reversed(bot)))
        bm.faces.new(top)
        for i in range(n):
            bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
        verts = self._bevel(bot + top, bev, 2)
        self._place(verts, mat, c, rot)
        return self

    def wing(self, root, span, chord, tip_chord, thick, mat, sweep=0.0, dihedral=0.0, side=1):
        """Asa achatada: raiz em root, ponta a `span` para o lado (side 1 = esquerda)."""
        x0, y0, z0 = root
        pts_root = [(x0 + chord / 2, y0), (x0 - chord / 2, y0)]
        yt = y0 + span * side
        xt = x0 - sweep
        zt = z0 + dihedral
        bm = self.bm
        vs = [
            bm.verts.new((x0 + chord / 2, y0, z0 + thick / 2)),
            bm.verts.new((x0 - chord / 2, y0, z0 + thick / 2)),
            bm.verts.new((xt - tip_chord / 2, yt, zt + thick / 4)),
            bm.verts.new((xt + tip_chord / 2, yt, zt + thick / 4)),
            bm.verts.new((x0 + chord / 2, y0, z0 - thick / 2)),
            bm.verts.new((x0 - chord / 2, y0, z0 - thick / 2)),
            bm.verts.new((xt - tip_chord / 2, yt, zt - thick / 4)),
            bm.verts.new((xt + tip_chord / 2, yt, zt - thick / 4)),
        ]
        faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 3, 7, 4), (1, 5, 6, 2), (3, 2, 6, 7), (0, 4, 5, 1)]
        for f in faces:
            fv = [vs[i] for i in f]
            if side < 0:
                fv.reverse()
            bm.faces.new(fv)
        bmesh.ops.recalc_face_normals(bm, faces=list({f for v in vs for f in v.link_faces}))
        idx = self._mat_index(mat)
        for f in {f for v in vs for f in v.link_faces}:
            f.material_index = idx
            f.smooth = True
        return self

    # ------------------------------------------------------------ simetria

    def sym(self, fn, c, *args, **kw):
        """Chama a primitiva `fn` (nome) em c e espelhada no outro lado (Y)."""
        c = _v(c)
        getattr(self, fn)(c, *args, **kw)
        kw2 = dict(kw)
        if "rot" in kw2:
            rx, ry, rz = kw2["rot"]
            kw2["rot"] = (-rx, ry, -rz)
        if "shift" in kw2 and kw2["shift"]:
            kw2["shift"] = (kw2["shift"][0], -kw2["shift"][1])
        getattr(self, fn)(Vector((c.x, -c.y, c.z)), *args, **kw2)
        return self


class Model:
    def __init__(self, name, palette):
        self.name = name
        self.palette = palette
        self.mats = []
        self.groups = {}
        self.order = []
        self.locs = []
        self.body = self.group("body", (0, 0, 0))

    def mat_index(self, role):
        if role not in self.mats:
            self.mats.append(role)
        return self.mats.index(role)

    def group(self, name, pivot, parent="body"):
        if name in self.groups:
            return self.groups[name]
        p = Part(self, name, pivot, parent if name != "body" else None)
        self.groups[name] = p
        self.order.append(name)
        return p

    def loc(self, name, pos, group="body"):
        self.locs.append((name, _v(pos), group))

    def sym_loc(self, name, pos, group="body"):
        p = _v(pos)
        self.loc(name, p, group)
        self.loc(name, Vector((p.x, -p.y, p.z)), group)


# ---------------------------------------------------------------- Blender

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(role, spec):
    col, metal, rough = spec[0], spec[1], spec[2]
    emit = spec[3] if len(spec) > 3 else None
    mat = bpy.data.materials.new(role)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        out = mat.node_tree.nodes.get("Material Output") or mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    mat.diffuse_color = (*col, 1.0)
    return mat


def build(model, out_dir):
    reset_scene()
    scene = bpy.context.scene
    mats = [make_material(r, model.palette[r]) for r in model.mats]
    objects = {}
    # Grupos em ordem: "body" é a raiz
    for gname in model.order:
        part = model.groups[gname]
        if part.parent is None:
            parent_obj = None
            parent_pivot = Vector((0, 0, 0))
        else:
            parent_obj = objects[part.parent]
            parent_pivot = model.groups[part.parent].pivot
        if gname == "body":
            holder = None
        else:
            holder = bpy.data.objects.new(gname, None)
            holder.empty_display_size = 0.1
            scene.collection.objects.link(holder)
            holder.location = part.pivot - parent_pivot
            if parent_obj is not None:
                holder.parent = parent_obj
        objects[gname] = holder
        if len(part.bm.verts) == 0:
            part.bm.free()
            continue
        bmesh.ops.translate(part.bm, vec=-part.pivot, verts=part.bm.verts)
        bmesh.ops.remove_doubles(part.bm, verts=part.bm.verts, dist=1e-5)
        me = bpy.data.meshes.new(gname + "_mesh")
        part.bm.to_mesh(me)
        part.bm.free()
        for m in mats:
            me.materials.append(m)
        try:
            me.set_sharp_from_angle(angle=math.radians(38))
        except Exception:
            pass
        ob = bpy.data.objects.new(gname + "_m" if gname != "body" else model.name, me)
        scene.collection.objects.link(ob)
        if holder is not None:
            ob.parent = holder
        elif gname == "body":
            objects["body"] = ob   # demais grupos e locators ficam presos ao corpo
    for i, (lname, pos, gname) in enumerate(model.locs):
        e = bpy.data.objects.new("loc_%s_%d" % (lname, i), None)
        e.empty_display_size = 0.05
        scene.collection.objects.link(e)
        g = model.groups[gname]
        e.location = pos - g.pivot
        if objects.get(gname) is not None:
            e.parent = objects[gname]
    path = out_dir + "/" + model.name + ".glb"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True,
                              export_apply=True, export_materials="EXPORT",
                              export_extras=False, export_cameras=False, export_lights=False)
    return path
