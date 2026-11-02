"""Núcleo Sintético (robôs): cerâmica branca, ouro e núcleos ciano; andadores e plataformas flutuantes."""

import math

from core import Model
from palettes import ROBOT as P


def _gun(t, kind, z):
    y = -0.08
    if kind == "rifle":
        t.box((0.14, y, z), (0.24, 0.045, 0.05), "dark", bev=0.012)
        t.cyl((0.3, y, z), 0.015, 0.1, "metal", axis="x", seg=10)
        t.box((0.12, y, z + 0.035), (0.14, 0.02, 0.02), "glow")
        return (0.36, y, z)
    if kind == "smg":
        # Ceifador: dois emissores nos antebraços
        for s in (1, -1):
            t.box((0.15, 0.1 * s, z), (0.18, 0.05, 0.05), "dark", bev=0.012)
            t.sphere((0.25, 0.1 * s, z), 0.03, "glow")
        return (0.27, 0.0, z)
    if kind == "mg":
        t.box((0.1, y, z), (0.26, 0.09, 0.09), "dark", bev=0.02)
        t.cyl((0.27, y, z), 0.04, 0.12, "metal", axis="x", seg=14)
        for i in range(3):
            t.torus((0.22 + i * 0.04, y, z), 0.045, 0.01, "glow", seg=16, seg2=6, rot=(0, 90, 0))
        return (0.34, y, z)
    if kind == "at":
        t.cyl((0.08, y - 0.04, z + 0.15), 0.06, 0.36, "hull", axis="x", seg=16, bev=0.015)
        t.torus((0.26, y - 0.04, z + 0.15), 0.06, 0.015, "team", seg=16, seg2=6, rot=(0, 90, 0))
        t.sphere((0.27, y - 0.04, z + 0.15), 0.045, "glow")
        return (0.3, y - 0.04, z + 0.15)
    if kind == "sniper":
        t.box((0.16, y, z), (0.3, 0.035, 0.04), "dark", bev=0.01)
        t.box((0.4, y, z), (0.24, 0.02, 0.025), "metal")
        for i in range(4):
            t.box((0.32 + i * 0.05, y, z + 0.022), (0.012, 0.03, 0.012), "glow")
        return (0.53, y, z)
    return (0.25, y, z)


def droid(name, kind):
    """Infantaria robótica: pernas digitígradas finas, tronco em cunha e olho único."""
    m = Model(name, P)
    big = kind in ("mg", "at")
    w = 1.15 if big else 1.0
    for side, g in ((1, "leg_l"), (-1, "leg_r")):
        y = side * 0.075 * w
        p = m.group(g, (0, y, 0.38))
        p.tube((0, y, 0.38), (0.06, y, 0.22), 0.03 * w, "dark")
        p.box((0.0, y, 0.33), (0.08, 0.07, 0.1), "hull", bev=0.02)
        k = m.group("knee" + g[3:], (0.06, y, 0.22), parent=g)
        k.sphere((0.06, y, 0.22), 0.035 * w, "metal")
        k.tube((0.06, y, 0.22), (-0.02, y, 0.06), 0.025 * w, "hull")
        k.box((0.02, y, 0.025), (0.14, 0.07, 0.04), "dark", bev=0.012, taper=(0.7, 0.8))
    t = m.group("torso", (0, 0, 0.38))
    t.sphere((0, 0, 0.41), (0.07, 0.1 * w, 0.05), "dark")
    t.box((0.0, 0, 0.55), (0.17, 0.24 * w, 0.19), "hull", bev=0.05, taper=(0.7, 0.9))
    t.box((0.07, 0, 0.53), (0.04, 0.08, 0.1), "team", bev=0.015)
    t.sphere((0.08, 0, 0.6), 0.03, "glow")
    t.sym("sphere", (0.0, 0.15 * w, 0.6), (0.06, 0.05, 0.05), "team")
    t.sym("box", (0.06, 0.15 * w, 0.52), (0.14, 0.04, 0.04), "dark", bev=0.012, rot=(0, 20, 0))
    t.box((-0.1, 0, 0.58), (0.05, 0.16, 0.14), "dark", bev=0.015)
    t.sym("cyl", (-0.13, 0.05, 0.64), 0.012, 0.18, "metal", seg=8)
    # Cabeça: viseira em cunha com olho ciano
    t.box((0.02, 0, 0.71), (0.13, 0.09, 0.08), "hull", bev=0.03, taper=(0.6, 0.8), rot=(0, -10, 0))
    t.box((0.075, 0, 0.71), (0.03, 0.07, 0.022), "glow", bev=0.006)
    if kind == "sniper":
        t.box((0.0, 0, 0.77), (0.02, 0.12, 0.012), "team")
    m.loc("muzzle", _gun(t, kind, 0.52), "torso")
    return m


def _hover_pads(b, pts, r=0.1):
    for x, y in pts:
        b.cyl((x, y, 0.09), r, 0.06, "dark", seg=18)
        b.cyl((x, y, 0.055), r * 0.75, 0.012, "engine", seg=18)


def harvester(name):
    """Extrator: plataforma flutuante com coletor de feixe."""
    m = Model(name, P)
    b = m.body
    _hover_pads(b, [(0.4, 0.25), (0.4, -0.25), (-0.4, 0.25), (-0.4, -0.25)], 0.12)
    b.box((0, 0, 0.25), (1.15, 0.65, 0.18), "hull", bev=0.07, taper=(0.9, 0.85))
    b.box((-0.18, 0, 0.45), (0.6, 0.5, 0.25), "dark", bev=0.06, taper=(0.85, 0.85))
    b.sphere((-0.18, 0, 0.58), (0.2, 0.2, 0.08), "glow")
    b.torus((-0.18, 0, 0.58), 0.24, 0.025, "team", seg=28, seg2=6)
    b.box((0.4, 0, 0.4), (0.25, 0.4, 0.15), "hull", bev=0.05, taper=(0.6, 0.8))
    b.box((0.47, 0, 0.42), (0.1, 0.3, 0.06), "glass", bev=0.02, rot=(0, 25, 0))
    # Garras coletoras
    b.sym("box", (0.66, 0.18, 0.18), (0.28, 0.05, 0.06), "metal", bev=0.015, rot=(0, 0, -15))
    b.cone((0.68, 0, 0.12), 0.09, 0.14, "glow", seg=16)
    b.sym("box", (0.0, 0.335, 0.25), (0.8, 0.012, 0.04), "glow")
    return m


def spider(name):
    """Aranha: andador leve de quatro patas com torre de pulso (atinge naves)."""
    m = Model(name, P)
    b = m.body
    b.sphere((0, 0, 0.42), (0.3, 0.24, 0.12), "hull")
    b.sphere((0, 0, 0.36), (0.22, 0.2, 0.08), "dark")
    b.torus((0, 0, 0.42), 0.27, 0.018, "team", seg=24, seg2=6)
    # Uma pata por grupo (limb_<lado><índice>), girando no quadril: marcha em diagonal
    for i, x in enumerate((0.2, -0.2)):
        for s in (1, -1):
            hip = (x, 0.15 * s, 0.4)
            p = m.group("limb_%s%d" % ("l" if s > 0 else "r", i), hip)
            knee = (x * 1.8, 0.42 * s, 0.55)
            foot = (x * 2.2, 0.55 * s, 0.02)
            p.sphere(hip, 0.05, "metal")
            p.tube(hip, knee, 0.035, "hull")
            p.sphere(knee, 0.045, "team")
            p.tube(knee, foot, 0.028, "dark", r2=0.012)
    t = m.group("turret", (0, 0, 0.5))
    t.sphere((0, 0, 0.53), (0.15, 0.15, 0.08), "hull")
    t.box((0.12, 0, 0.55), (0.12, 0.12, 0.06), "dark", bev=0.02)
    t.sym("cyl", (0.26, 0.04, 0.55), 0.015, 0.22, "metal", axis="x", seg=8)
    t.sphere((0.08, 0, 0.6), 0.03, "glow")
    m.loc("muzzle", (0.37, 0, 0.55), "turret")
    return m


def tank(name):
    """Bastião: disco flutuante com torre esférica de raio."""
    m = Model(name, P)
    b = m.body
    b.cyl((0, 0, 0.2), 0.55, 0.16, "hull", seg=32, r2=0.48, bev=0.05)
    b.cyl((0, 0, 0.1), 0.45, 0.08, "dark", seg=32, r2=0.52)
    b.torus((0, 0, 0.07), 0.38, 0.03, "engine", seg=32, seg2=6)
    b.torus((0, 0, 0.27), 0.5, 0.02, "team", seg=32, seg2=6)
    for i in range(6):
        a = i * math.pi / 3 + math.pi / 6
        b.box((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.22), (0.12, 0.12, 0.12), "dark", bev=0.03,
              rot=(0, 0, math.degrees(a)))
    b.box((0.5, 0, 0.22), (0.1, 0.24, 0.04), "glow")
    t = m.group("turret", (0, 0, 0.3))
    t.sphere((0, 0, 0.42), 0.24, "hull", seg=24, rings=14)
    t.torus((0, 0, 0.42), 0.245, 0.02, "dark", seg=28, seg2=6, rot=(90, 0, 0))
    t.sphere((0.15, 0, 0.47), (0.08, 0.12, 0.05), "glass")
    t.cyl((0.42, 0, 0.42), 0.05, 0.4, "dark", axis="x", seg=16, bev=0.01)
    for i in range(3):
        t.torus((0.32 + i * 0.1, 0, 0.42), 0.065, 0.012, "glow", seg=16, seg2=6, rot=(0, 90, 0))
    t.sphere((0.63, 0, 0.42), 0.04, "glow")
    m.loc("muzzle", (0.65, 0, 0.42), "turret")
    return m


def colossus(name):
    """Colosso: mecha bípede pesado; o tronco é a torre e gira sobre as pernas."""
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.58), (0.3, 0.42, 0.14), "dark", bev=0.04)
    for side, g in ((1, "leg_l"), (-1, "leg_r")):
        y = side * 0.24
        p = m.group(g, (0, y, 0.58))
        p.box((0.0, y, 0.48), (0.2, 0.15, 0.26), "hull", bev=0.05)
        k = m.group("knee" + g[3:], (0.07, y, 0.32), parent=g)
        k.sphere((0.07, y, 0.32), 0.07, "metal")
        k.tube((0.07, y, 0.32), (-0.04, y, 0.1), 0.06, "dark")
        k.box((0.06, y, 0.35), (0.06, 0.12, 0.12), "team", bev=0.02)
        k.box((0.02, y, 0.04), (0.32, 0.18, 0.08), "hull", bev=0.03, taper=(0.75, 0.85))
    t = m.group("turret", (0, 0, 0.65))
    t.box((0.0, 0, 0.82), (0.5, 0.56, 0.32), "hull", bev=0.08, taper=(0.8, 0.85))
    t.box((0.2, 0, 0.84), (0.14, 0.3, 0.12), "dark", bev=0.03)
    t.box((0.27, 0, 0.85), (0.02, 0.24, 0.04), "glow")
    t.box((-0.24, 0, 0.84), (0.16, 0.4, 0.26), "dark", bev=0.04)
    t.sym("cyl", (-0.32, 0.12, 0.96), 0.04, 0.2, "metal", seg=12)
    t.sym("sphere", (0.0, 0.34, 0.9), (0.14, 0.1, 0.12), "team")
    for s in (1, -1):
        t.box((0.15, 0.42 * s, 0.82), (0.36, 0.13, 0.14), "hull", bev=0.04)
        t.cyl((0.45, 0.42 * s, 0.82), 0.05, 0.36, "dark", axis="x", seg=14, bev=0.01)
        t.torus((0.38, 0.42 * s, 0.82), 0.065, 0.015, "glow", seg=16, seg2=6, rot=(0, 90, 0))
        t.torus((0.5, 0.42 * s, 0.82), 0.065, 0.015, "glow", seg=16, seg2=6, rot=(0, 90, 0))
    m.loc("muzzle", (0.64, 0.42, 0.82), "turret")
    return m


def fighter(name):
    """Interceptor Delta: triângulo com anel gravitacional."""
    m = Model(name, P)
    b = m.body
    b.prism((0, 0, 0), [(0.55, 0), (-0.35, 0.45), (-0.25, 0), (-0.35, -0.45)], 0.08, "hull", bev=0.02)
    b.prism((0.05, 0, 0.06), [(0.4, 0), (-0.2, 0.18), (-0.15, 0), (-0.2, -0.18)], 0.06, "dark", taper=0.7)
    b.sphere((0.12, 0, 0.08), (0.12, 0.05, 0.035), "glass")
    b.torus((-0.18, 0, 0), 0.22, 0.025, "team", seg=28, seg2=6)
    b.sphere((-0.18, 0, 0.0), 0.07, "glow")
    b.sym("box", (-0.33, 0.38, 0.0), (0.12, 0.03, 0.12), "dark", bev=0.01)
    b.sym("cyl", (-0.37, 0.22, 0.0), 0.035, 0.08, "engine", axis="x", seg=12)
    b.sym("box", (0.12, 0.2, -0.03), (0.2, 0.025, 0.025), "metal")
    m.sym_loc("muzzle", (0.23, 0.2, -0.03))
    m.sym_loc("engine", (-0.42, 0.22, 0.0))
    return m


def gunship(name):
    """Arca Prisma: núcleo octaédrico com anel giratório e lança de energia."""
    m = Model(name, P)
    b = m.body
    b.prism((0, 0, 0.12), [(0.5 * math.cos(a), 0.5 * math.sin(a)) for a in
                            [i * math.pi / 4 for i in range(8)]], 0.14, "hull", bev=0.03, taper=0.75)
    b.prism((0, 0, -0.02), [(0.4 * math.cos(a), 0.4 * math.sin(a)) for a in
                             [i * math.pi / 4 for i in range(8)]], 0.14, "dark", bev=0.03, taper=1.2)
    b.cone((0, 0, -0.2), 0.3, 0.22, "dark", seg=8, rot=(180, 0, 0))
    b.sphere((0, 0, -0.26), 0.07, "glow")
    b.sphere((0, 0, 0.24), (0.22, 0.22, 0.08), "glass")
    b.box((0.55, 0, 0.05), (0.4, 0.14, 0.1), "hull", bev=0.03, taper=(0.6, 0.6))
    b.cyl((0.78, 0, 0.05), 0.03, 0.2, "metal", axis="x", seg=10)
    b.sphere((0.88, 0, 0.05), 0.04, "glow")
    s = m.group("spin", (0, 0, 0.05))
    s.torus((0, 0, 0.05), 0.68, 0.035, "team", seg=40, seg2=8)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        s.box((math.cos(a) * 0.68, math.sin(a) * 0.68, 0.05), (0.12, 0.12, 0.12), "hull", bev=0.03,
              rot=(0, 0, math.degrees(a)))
        s.sphere((math.cos(a) * 0.68, math.sin(a) * 0.68, 0.12), 0.03, "glow")
    m.loc("muzzle", (0.9, 0, 0.05))
    return m


# ---------------------------------------------------------------- prédios

def _base(b, sx, sy):
    b.box((0, 0, 0.04), (sx, sy, 0.08), "dark", bev=0.03)
    b.box((0, 0, 0.085), (sx - 0.16, sy - 0.16, 0.01), "accent")
    for x in (-sx / 2 + 0.1, sx / 2 - 0.1):
        for y in (-sy / 2 + 0.1, sy / 2 - 0.1):
            b.sphere((x, y, 0.09), 0.03, "glow")


def _pylon(b, x, y, h, r=0.1):
    b.prism((x, y, h / 2 + 0.08), [(r * math.cos(a), r * math.sin(a)) for a in
                                    [i * math.pi / 3 for i in range(6)]], h, "hull", taper=0.4, bev=0.01)
    b.sphere((x, y, h + 0.12), r * 0.45, "glow")


def cy(name):
    m = Model(name, P)
    b = m.body
    _base(b, 2.9, 2.9)
    b.prism((0, 0.1, 0.5), [(1.1 * math.cos(a), 1.1 * math.sin(a)) for a in
                             [i * math.pi / 3 + math.pi / 6 for i in range(6)]], 0.8, "hull", taper=0.8, bev=0.06)
    b.prism((0, 0.1, 1.05), [(0.7 * math.cos(a), 0.7 * math.sin(a)) for a in
                              [i * math.pi / 3 + math.pi / 6 for i in range(6)]], 0.3, "dark", taper=0.7, bev=0.04)
    b.cone((0, 0.1, 1.55), 0.35, 0.7, "hull", seg=6)
    b.sphere((0, 0.1, 1.95), 0.12, "glow")
    s = m.group("spin", (0, 0.1, 1.5))
    s.torus((0, 0.1, 1.5), 0.55, 0.03, "team", seg=36, seg2=8, rot=(15, 0, 0))
    b.box((0, -0.85, 0.3), (0.6, 0.3, 0.45), "dark", bev=0.05)
    b.box((0, -1.0, 0.3), (0.4, 0.02, 0.32), "glow")
    for i in range(6):
        a = i * math.pi / 3 + math.pi / 6
        b.box((math.cos(a) * 0.98, 0.1 + math.sin(a) * 0.98, 0.65), (0.05, 0.25, 0.04), "glow",
              rot=(0, 0, math.degrees(a)))
    _pylon(b, -1.2, -1.2, 0.6)
    _pylon(b, 1.2, -1.2, 0.6)
    return m


def power(name):
    m = Model(name, P)
    b = m.body
    _base(b, 1.9, 1.9)
    b.box((0, 0, 0.25), (1.3, 1.3, 0.35), "hull", bev=0.06, taper=(0.85, 0.85))
    for x, y in ((0.4, 0.4), (-0.4, 0.4), (0.4, -0.4), (-0.4, -0.4)):
        _pylon(b, x, y, 0.8, 0.09)
    b.sphere((0, 0, 0.75), 0.24, "glow", seg=24, rings=14)
    s = m.group("spin", (0, 0, 0.75))
    s.torus((0, 0, 0.75), 0.33, 0.025, "team", seg=32, seg2=6, rot=(60, 0, 0))
    s.torus((0, 0, 0.75), 0.33, 0.025, "metal", seg=32, seg2=6, rot=(-60, 0, 0))
    return m


def refinery(name):
    m = Model(name, P)
    b = m.body
    _base(b, 2.9, 1.9)
    b.box((-0.4, 0.15, 0.4), (1.6, 1.2, 0.65), "hull", bev=0.08, taper=(0.9, 0.85))
    b.box((-0.4, 0.15, 0.8), (1.0, 0.7, 0.16), "dark", bev=0.04)
    for i in range(3):
        b.box((-0.75 + i * 0.35, 0.15, 0.9), (0.2, 0.5, 0.05), "glow")
    b.cyl((0.85, 0.2, 0.5), 0.35, 0.8, "dark", seg=6, bev=0.03)
    b.cyl((0.85, 0.2, 0.92), 0.25, 0.06, "glow", seg=6)
    b.torus((0.85, 0.2, 0.6), 0.37, 0.025, "team", seg=6, seg2=4)
    b.box((-0.4, -0.55, 0.22), (0.9, 0.25, 0.3), "dark", bev=0.04)
    b.box((-0.4, -0.68, 0.22), (0.7, 0.02, 0.06), "glow")
    return m


def barracks(name):
    m = Model(name, P)
    b = m.body
    _base(b, 1.9, 1.9)
    b.box((0, 0.1, 0.4), (1.4, 1.2, 0.7), "hull", bev=0.1, taper=(0.75, 0.85))
    b.box((0, -0.5, 0.3), (0.5, 0.15, 0.45), "dark", bev=0.04)
    b.box((0, -0.58, 0.3), (0.34, 0.02, 0.34), "glow")
    for i in range(4):
        b.box((-0.45 + i * 0.3, 0.1, 0.8), (0.1, 0.9, 0.08), "team", bev=0.02)
    _pylon(b, 0.7, 0.7, 0.5, 0.07)
    _pylon(b, -0.7, 0.7, 0.5, 0.07)
    return m


def factory(name):
    m = Model(name, P)
    b = m.body
    _base(b, 2.9, 2.9)
    b.box((0, 0.3, 0.55), (2.4, 1.8, 0.95), "hull", bev=0.12, taper=(0.92, 0.85))
    b.box((0, -0.7, 0.4), (1.4, 0.2, 0.7), "dark", bev=0.05)
    b.box((0, -0.81, 0.4), (1.2, 0.02, 0.55), "glass")
    for i in range(3):
        b.box((0, -0.82, 0.2 + i * 0.2), (1.2, 0.01, 0.02), "glow")
    for x in (-0.7, 0.0, 0.7):
        b.cyl((x, 0.4, 1.1), 0.22, 0.2, "dark", seg=6)
        b.cyl((x, 0.4, 1.21), 0.16, 0.02, "glow", seg=6)
    b.box((1.21, 0.3, 0.55), (0.02, 1.4, 0.08), "team")
    b.box((-1.21, 0.3, 0.55), (0.02, 1.4, 0.08), "team")
    _pylon(b, 1.25, -1.15, 0.7)
    _pylon(b, -1.25, -1.15, 0.7)
    return m


def starport(name):
    m = Model(name, P)
    b = m.body
    _base(b, 2.9, 2.9)
    b.prism((0.15, -0.15, 0.2), [(1.0 * math.cos(a), 1.0 * math.sin(a)) for a in
                                  [i * math.pi / 4 + math.pi / 8 for i in range(8)]], 0.25, "hull", bev=0.04)
    b.prism((0.15, -0.15, 0.33), [(0.8 * math.cos(a), 0.8 * math.sin(a)) for a in
                                   [i * math.pi / 4 + math.pi / 8 for i in range(8)]], 0.02, "dark")
    b.torus((0.15, -0.15, 0.34), 0.55, 0.02, "glow", seg=8, seg2=4)
    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.5
        x, y = 0.15 + math.cos(a) * 1.15, -0.15 + math.sin(a) * 1.15
        b.prism((x, y, 0.55), [(0.08 * math.cos(q), 0.08 * math.sin(q)) for q in
                                [k * math.pi / 3 for k in range(6)]], 0.9, "hull", taper=0.5)
        b.sphere((x, y, 1.05), 0.05, "glow")
    s = m.group("spin", (0.15, -0.15, 1.2))
    s.torus((0.15, -0.15, 1.2), 0.5, 0.025, "team", seg=36, seg2=6)
    b.box((-1.05, 1.05, 0.5), (0.5, 0.5, 0.9), "hull", bev=0.06, taper=(0.6, 0.6))
    b.sphere((-1.05, 1.05, 1.0), 0.1, "glow")
    return m


def turret(name):
    m = Model(name, P)
    b = m.body
    b.prism((0, 0, 0.1), [(0.42 * math.cos(a), 0.42 * math.sin(a)) for a in
                           [i * math.pi / 3 for i in range(6)]], 0.2, "hull", taper=0.85, bev=0.03)
    b.torus((0, 0, 0.21), 0.3, 0.02, "glow", seg=6, seg2=4)
    g = m.group("gun", (0, 0, 0.3))
    g.tube((0, 0, 0.2), (0, 0, 0.55), 0.06, "dark")
    for i in range(3):
        g.torus((0, 0, 0.32 + i * 0.09), 0.12 - i * 0.02, 0.02, "metal", seg=20, seg2=6)
    g.sphere((0, 0, 0.62), 0.1, "glow", seg=20, rings=12)
    g.box((0.12, 0, 0.62), (0.12, 0.05, 0.05), "team")
    m.loc("muzzle", (0.1, 0, 0.62), "gun")
    return m


def medic(name):
    """Doca de Reparo: plataforma hexagonal com braços-solda e anel de campo giratório."""
    m = Model(name, P)
    b = m.body
    _base(b, 1.9, 1.9)
    b.prism((0, 0, 0.12), [(0.75 * math.cos(a), 0.75 * math.sin(a)) for a in
                           [i * math.pi / 3 for i in range(6)]], 0.22, "hull", taper=0.9, bev=0.03)
    b.prism((0, 0, 0.24), [(0.55 * math.cos(a), 0.55 * math.sin(a)) for a in
                           [i * math.pi / 3 for i in range(6)]], 0.02, "dark")
    b.torus((0, 0, 0.26), 0.45, 0.02, "glow", seg=6, seg2=4)
    for i in range(3):
        a = i * 2 * math.pi / 3 + math.pi / 6
        x, y = math.cos(a) * 0.72, math.sin(a) * 0.72
        _pylon(b, x, y, 0.55, 0.07)
        b.tube((x, y, 0.75), (x * 0.35, y * 0.35, 0.9), 0.035, "metal")
        b.sphere((x * 0.35, y * 0.35, 0.9), 0.045, "glow")
    b.sphere((0, 0, 0.45), 0.13, "glow", seg=20, rings=12)
    s = m.group("spin", (0, 0, 0.62))
    s.torus((0, 0, 0.62), 0.32, 0.025, "team", seg=6, seg2=4)
    s.torus((0, 0, 0.62), 0.22, 0.018, "metal", seg=6, seg2=4, rot=(25, 0, 0))
    return m


def all_models():
    out = []
    for k in ("rifle", "smg", "mg", "at", "sniper"):
        out.append(droid("rob_" + k, k))
    out += [harvester("rob_harvester"), spider("rob_scout"), tank("rob_tank"),
            colossus("rob_heavy"), fighter("rob_fighter"), gunship("rob_gunship")]
    out += [cy("cy_rob"), power("power_rob"), refinery("refinery_rob"), barracks("barracks_rob"),
            factory("factory_rob"), starport("starport_rob"), turret("turret_rob"),
            medic("medic_rob")]
    return out
