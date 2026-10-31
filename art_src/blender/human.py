"""Legião Solar (humanos): armaduras de combate, veículos de esteira/hover, naves de asa delta."""

from core import Model
from palettes import HUMAN as P


# ---------------------------------------------------------------- infantaria

def _weapon(t, kind):
    """Arma segurada à frente do peito (grupo torso). Devolve a posição da boca."""
    y = -0.07
    z = 0.53
    if kind == "rifle":
        t.box((0.12, y, z), (0.26, 0.04, 0.06), "dark", bev=0.01)
        t.box((0.08, y, z - 0.05), (0.04, 0.03, 0.06), "dark", bev=0.008)
        t.cyl((0.28, y, z + 0.005), 0.012, 0.1, "metal", axis="x", seg=10)
        t.box((0.14, y, z + 0.04), (0.08, 0.025, 0.02), "glow")
        return (0.34, y, z + 0.005)
    if kind == "smg":
        t.box((0.1, y, z), (0.18, 0.05, 0.07), "dark", bev=0.012)
        t.box((0.12, y, z + 0.045), (0.1, 0.03, 0.02), "team")
        for dy in (-0.012, 0.012):
            t.cyl((0.22, y + dy, z), 0.01, 0.07, "metal", axis="x", seg=8)
        t.box((0.05, y, z - 0.05), (0.035, 0.03, 0.06), "dark")
        return (0.26, y, z)
    if kind == "mg":
        t.box((0.1, y, z - 0.01), (0.28, 0.08, 0.09), "dark", bev=0.015)
        t.cyl((0.04, y - 0.06, z - 0.02), 0.045, 0.05, "hull", axis="y", seg=14, bev=0.01)
        for a in range(6):
            import math
            dy = math.cos(a * 1.047) * 0.022
            dz = math.sin(a * 1.047) * 0.022
            t.cyl((0.31, y + dy, z + dz), 0.008, 0.16, "metal", axis="x", seg=6)
        t.cyl((0.3, y, z), 0.035, 0.03, "dark", axis="x", seg=12)
        t.box((0.12, y, z + 0.05), (0.12, 0.04, 0.02), "glow")
        return (0.4, y, z)
    if kind == "at":
        # Lança-mísseis no ombro direito
        t.cyl((0.04, y - 0.05, z + 0.17), 0.05, 0.42, "hull", axis="x", seg=16, bev=0.01)
        t.cyl((0.26, y - 0.05, z + 0.17), 0.058, 0.05, "dark", axis="x", seg=16)
        t.cyl((-0.18, y - 0.05, z + 0.17), 0.056, 0.04, "dark", axis="x", seg=16)
        t.box((0.06, y - 0.05, z + 0.23), (0.12, 0.03, 0.025), "accent")
        t.sphere((0.27, y - 0.05, z + 0.17), (0.01, 0.04, 0.04), "glow")
        return (0.3, y - 0.05, z + 0.17)
    if kind == "sniper":
        t.box((0.12, y, z), (0.3, 0.035, 0.05), "dark", bev=0.01)
        t.cyl((0.38, y, z + 0.005), 0.009, 0.26, "metal", axis="x", seg=8)
        t.cyl((0.14, y, z + 0.055), 0.022, 0.12, "dark", axis="x", seg=12)
        t.sphere((0.2, y, z + 0.055), (0.006, 0.018, 0.018), "glow")
        t.box((0.0, y, z - 0.03), (0.08, 0.03, 0.06), "team", bev=0.008)
        return (0.51, y, z + 0.005)
    return (0.2, y, z)


def soldier(name, kind):
    m = Model(name, P)
    heavy = kind in ("mg", "at")
    w = 1.12 if heavy else 1.0
    for side, g in ((1, "leg_l"), (-1, "leg_r")):
        y = side * 0.07 * w
        p = m.group(g, (0, y, 0.36))
        p.box((0, y, 0.285), (0.11 * w, 0.1 * w, 0.16), "hull", bev=0.025)
        # canela + bota giram no joelho
        k = m.group("knee" + g[3:], (0.0, y, 0.205), parent=g)
        k.box((0.06 * w, y, 0.2), (0.05, 0.075, 0.08), "team", bev=0.015)
        k.box((0.0, y, 0.13), (0.09 * w, 0.085 * w, 0.16), "dark", bev=0.02)
        k.box((0.03, y, 0.035), (0.16 * w, 0.095 * w, 0.07), "hull", bev=0.02, taper=(0.8, 0.9))
    t = m.group("torso", (0, 0, 0.36))
    t.box((0, 0, 0.41), (0.15 * w, 0.2 * w, 0.09), "dark", bev=0.02)
    t.box((0.005, 0, 0.55), (0.2 * w, 0.27 * w, 0.2), "hull", bev=0.045, taper=(0.92, 0.85))
    t.box((0.09 * w, 0, 0.56), (0.04, 0.14, 0.1), "team", bev=0.015)
    t.box((0.1 * w, 0, 0.49), (0.03, 0.12, 0.03), "glow")
    # Mochila com propulsores
    t.box((-0.12 * w, 0, 0.56), (0.09, 0.22 * w, 0.2), "dark", bev=0.025)
    t.sym("cyl", (-0.16 * w, 0.06 * w, 0.49), 0.03, 0.06, "metal", seg=12)
    t.sym("cyl", (-0.16 * w, 0.06 * w, 0.455), 0.024, 0.012, "engine", seg=12)
    # Ombreiras e braços
    t.sym("sphere", (0.0, 0.165 * w, 0.62), (0.085 * w, 0.075 * w, 0.06), "team")
    t.sym("box", (0.03, 0.17 * w, 0.52), (0.07, 0.065, 0.15), "hull", bev=0.02)
    t.sym("box", (0.11, 0.12 * w, 0.52), (0.13, 0.06, 0.06), "dark", bev=0.015)
    # Capacete com viseira
    t.sphere((0.01, 0, 0.73), (0.08, 0.075, 0.08), "hull", seg=20, rings=12)
    t.box((0.06, 0, 0.735), (0.05, 0.11, 0.035), "glass", bev=0.012)
    t.box((0.0, 0, 0.8), (0.1, 0.02, 0.02), "team", bev=0.006)
    if kind == "sniper":
        t.cyl((-0.04, 0.06, 0.82), 0.005, 0.1, "metal", seg=6)   # antena
    m.loc("muzzle", _weapon(t, kind), "torso")
    return m


# ---------------------------------------------------------------- veículos

## Espaçamento das sapatas da esteira (o jogo usa o mesmo valor para rolar as faixas)
TREAD = 0.07


def _tracks(m, x, y, length, h, w, mat="dark"):
    """Esteiras: rodas giratórias (wheel_<lado><i>) e duas faixas de sapatas na face de fora
    (treadf_* corre para frente em cima, treadb_* para trás embaixo)."""
    p = m.body
    for s in (1, -1):
        side = "l" if s > 0 else "r"
        yy = y * s
        p.box((x, yy, h / 2 + 0.01), (length, w, h), mat, bev=h * 0.4, seg=3)
        p.box((x, yy, h + 0.02), (length * 1.02, w * 1.15, 0.03), "hull", bev=0.01)
        for i in range(5):
            xx = x - length * 0.38 + i * length * 0.19
            wc = (xx, yy + (w / 2 + 0.008) * s, h / 2 + 0.01)
            g = m.group("wheel_%s%d" % (side, i), wc)
            g.cyl(wc, h * 0.36, 0.022, "metal", axis="y", seg=16)
            g.box((xx, wc[1] + 0.012 * s, wc[2]), (h * 0.62, 0.01, 0.03), "dark")
            g.box((xx, wc[1] + 0.012 * s, wc[2]), (0.03, 0.01, h * 0.62), "dark")
        n = int(length * 0.92 / TREAD)
        face = yy + (w / 2 + 0.004) * s
        for name, z in (("treadf", h * 0.93), ("treadb", h * 0.1)):
            g = m.group("%s_%s" % (name, side), (x, face, z))
            for k in range(n):
                xx = x - (n - 1) * TREAD / 2 + k * TREAD
                g.box((xx, face, z), (0.03, 0.014, h * 0.14), "metal", bev=0.004)


def harvester(name):
    m = Model(name, P)
    b = m.body
    _tracks(m, 0, 0.3, 1.2, 0.2, 0.16)
    b.box((-0.1, 0, 0.36), (1.0, 0.48, 0.24), "hull", bev=0.05)
    b.box((0.38, 0, 0.5), (0.3, 0.42, 0.22), "hull", bev=0.05, taper=(0.75, 0.9), shift=(-0.03, 0))
    b.box((0.47, 0, 0.53), (0.08, 0.34, 0.1), "glass", bev=0.02, rot=(0, 25, 0))
    b.box((-0.22, 0, 0.58), (0.62, 0.5, 0.26), "dark", bev=0.06)
    for i in range(3):
        b.box((-0.42 + i * 0.2, 0, 0.72), (0.14, 0.46, 0.03), "accent", bev=0.01)
    b.sym("box", (-0.22, 0.26, 0.58), (0.5, 0.02, 0.06), "team")
    # Braço minerador frontal com broca
    b.box((0.62, 0, 0.26), (0.12, 0.36, 0.12), "dark", bev=0.03)
    b.cone((0.78, 0, 0.22), 0.1, 0.24, "metal", axis="x", seg=12, rot=(0, 180, 0))
    b.cyl((0.68, 0, 0.22), 0.11, 0.05, "glow", axis="x", seg=14)
    b.sym("cyl", (-0.5, 0.18, 0.78), 0.04, 0.16, "metal", seg=12)
    m.sym_loc("smoke", (-0.5, 0.18, 0.88))
    return m


def scout(name):
    """Batedor: buggy de quatro rodas com metralhadora de pulso (atinge naves)."""
    m = Model(name, P)
    b = m.body
    # Rodas giratórias; as da frente (índice 0) esterçam
    for i, sx in enumerate((0.3, -0.3)):
        for s in (1, -1):
            wc = (sx, 0.27 * s, 0.13)
            g = m.group("wheel_%s%d" % ("l" if s > 0 else "r", i), wc)
            g.cyl(wc, 0.13, 0.1, "dark", axis="y", seg=18, bev=0.03)
            hub = (sx, 0.32 * s, 0.13)
            g.cyl(hub, 0.06, 0.02, "metal", axis="y", seg=12)
            g.box((sx, 0.332 * s, 0.13), (0.17, 0.012, 0.025), "accent")
            g.box((sx, 0.332 * s, 0.13), (0.025, 0.012, 0.17), "accent")
        b.sym("box", (sx, 0.24, 0.27), (0.3, 0.14, 0.04), "hull", bev=0.015)
    b.box((0.0, 0, 0.24), (0.86, 0.36, 0.12), "hull", bev=0.04, taper=(0.9, 0.9))
    b.box((0.33, 0, 0.3), (0.22, 0.3, 0.08), "hull", bev=0.03, shift=(-0.04, 0))
    b.box((0.06, 0, 0.36), (0.3, 0.28, 0.12), "dark", bev=0.03, taper=(0.7, 0.85))
    b.box((0.16, 0, 0.36), (0.06, 0.24, 0.08), "glass", bev=0.015, rot=(0, 30, 0))
    b.sym("box", (0.05, 0.19, 0.3), (0.5, 0.02, 0.04), "team")
    b.sym("box", (0.44, 0.13, 0.27), (0.02, 0.07, 0.03), "glow")
    t = m.group("turret", (-0.2, 0, 0.42))
    t.cyl((-0.2, 0, 0.44), 0.09, 0.06, "dark", seg=16, bev=0.015)
    t.box((-0.15, 0, 0.5), (0.14, 0.1, 0.08), "hull", bev=0.02)
    for dy in (-0.025, 0.025):
        t.cyl((0.0, dy, 0.51), 0.012, 0.22, "metal", axis="x", seg=8)
    t.box((-0.15, 0, 0.555), (0.06, 0.06, 0.02), "glow")
    m.loc("muzzle", (0.12, 0, 0.51), "turret")
    return m


def tank(name):
    """Gládio: tanque hover de casco anguloso e canhão de plasma."""
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.24), (1.15, 0.7, 0.2), "hull", bev=0.05, taper=(0.92, 0.88))
    b.box((0.52, 0, 0.2), (0.22, 0.6, 0.12), "hull", bev=0.04, shift=(-0.06, 0), taper=(0.6, 0.9))
    b.box((-0.05, 0, 0.12), (1.0, 0.56, 0.08), "dark", bev=0.03)
    for sx in (0.32, -0.32):
        b.sym("cyl", (sx, 0.24, 0.07), 0.12, 0.04, "dark", seg=18)
        b.sym("cyl", (sx, 0.24, 0.05), 0.09, 0.012, "engine", seg=18)
    b.sym("box", (0.0, 0.36, 0.26), (0.9, 0.06, 0.12), "dark", bev=0.025)
    b.sym("box", (0.0, 0.395, 0.26), (0.7, 0.012, 0.03), "team")
    b.sym("box", (0.56, 0.24, 0.27), (0.03, 0.1, 0.03), "glow")
    b.box((-0.56, 0, 0.27), (0.04, 0.4, 0.06), "engine")
    t = m.group("turret", (-0.02, 0, 0.36))
    t.box((-0.05, 0, 0.42), (0.5, 0.42, 0.13), "hull", bev=0.045, taper=(0.82, 0.8))
    t.box((-0.28, 0, 0.42), (0.1, 0.34, 0.1), "dark", bev=0.02)
    t.box((0.08, 0, 0.495), (0.12, 0.16, 0.03), "team", bev=0.01)
    t.cyl((0.4, 0, 0.42), 0.045, 0.6, "dark", axis="x", seg=14, bev=0.01)
    t.cyl((0.28, 0, 0.42), 0.06, 0.12, "hull", axis="x", seg=14, bev=0.01)
    for i in range(3):
        t.cyl((0.44 + i * 0.08, 0, 0.42), 0.052, 0.015, "glow", axis="x", seg=14)
    t.cyl((-0.15, 0.13, 0.52), 0.006, 0.16, "metal", seg=6)
    m.loc("muzzle", (0.71, 0, 0.42), "turret")
    return m


def heavy_tank(name):
    """Titã de Cerco: tanque pesado de esteiras com canhão duplo."""
    m = Model(name, P)
    b = m.body
    _tracks(m, 0, 0.4, 1.45, 0.26, 0.2)
    b.box((0, 0, 0.38), (1.4, 0.66, 0.24), "hull", bev=0.06, taper=(0.93, 0.9))
    b.box((0.7, 0, 0.33), (0.18, 0.62, 0.14), "hull", bev=0.04, shift=(-0.06, 0))
    b.sym("box", (0, 0.5, 0.36), (1.3, 0.06, 0.18), "hull", bev=0.03, rot=(-12, 0, 0))
    b.sym("box", (0, 0.535, 0.36), (1.0, 0.012, 0.04), "team", rot=(-12, 0, 0))
    b.box((-0.68, 0, 0.4), (0.12, 0.5, 0.16), "dark", bev=0.03)
    b.sym("cyl", (-0.72, 0.16, 0.42), 0.05, 0.05, "engine", axis="x", seg=14)
    t = m.group("turret", (-0.05, 0, 0.5))
    t.box((-0.1, 0, 0.6), (0.72, 0.58, 0.2), "hull", bev=0.06, taper=(0.8, 0.82))
    t.box((-0.42, 0, 0.6), (0.14, 0.5, 0.16), "dark", bev=0.03)
    t.box((0.15, 0, 0.72), (0.2, 0.26, 0.05), "team", bev=0.015)
    t.sym("box", (-0.1, 0.3, 0.6), (0.4, 0.04, 0.12), "dark", bev=0.015)
    for dy in (0.1, -0.1):
        t.cyl((0.6, dy, 0.6), 0.05, 0.75, "dark", axis="x", seg=14, bev=0.01)
        t.cyl((0.92, dy, 0.6), 0.065, 0.12, "hull", axis="x", seg=14, bev=0.015)
        t.cyl((0.985, dy, 0.6), 0.045, 0.012, "glow", axis="x", seg=14)
    t.box((0.24, 0, 0.6), (0.12, 0.34, 0.14), "hull", bev=0.03)
    t.cyl((-0.25, -0.18, 0.74), 0.05, 0.06, "dark", seg=12)
    t.sphere((-0.25, -0.18, 0.78), 0.035, "glass")
    m.loc("muzzle", (0.99, 0, 0.6), "turret")
    return m


# ---------------------------------------------------------------- naves

def fighter(name):
    """Falcão: caça de asa delta, mísseis contra naves e alvos leves."""
    m = Model(name, P)
    b = m.body
    b.box((0.05, 0, 0.0), (0.9, 0.18, 0.12), "hull", bev=0.05, taper=(0.9, 0.7))
    b.cone((0.62, 0, 0.0), 0.08, 0.3, "hull", axis="x", seg=16, rot=(0, 180, 0))
    b.sphere((0.28, 0, 0.07), (0.17, 0.065, 0.05), "glass")
    for s in (1, -1):
        b.wing((-0.05, 0.08 * s, -0.01), 0.5, 0.55, 0.14, 0.04, "hull", sweep=0.3, dihedral=-0.03, side=s)
        b.wing((-0.06, 0.25 * s, 0.0), 0.3, 0.16, 0.06, 0.012, "team", sweep=0.2, side=s)
        b.box((-0.38, 0.58 * s, -0.04), (0.18, 0.02, 0.1), "dark", bev=0.01)
        b.cyl((-0.15, 0.36 * s, -0.04), 0.018, 0.22, "dark", axis="x", seg=8)
    b.sym("cyl", (-0.38, 0.09, 0.0), 0.06, 0.24, "dark", axis="x", seg=16, bev=0.015)
    b.sym("cyl", (-0.505, 0.09, 0.0), 0.048, 0.02, "engine", axis="x", seg=16)
    b.sym("wing", (-0.32, 0.06, 0.05), 0.02, 0.18, 0.08, 0.015, "hull", sweep=0.1, dihedral=0.16)
    m.sym_loc("muzzle", (0.0, 0.36, -0.04))
    m.sym_loc("engine", (-0.52, 0.09, 0.0))
    return m


def gunship(name):
    """Fragata Ônix: nave pesada com torre de plasma sob o casco (só alvos no solo)."""
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.05), (1.5, 0.5, 0.24), "hull", bev=0.07, taper=(0.85, 0.75))
    b.box((0.7, 0, 0.02), (0.4, 0.4, 0.18), "hull", bev=0.06, taper=(0.5, 0.7), rot=(0, 0, 0))
    b.box((0.3, 0, 0.2), (0.5, 0.22, 0.12), "dark", bev=0.04, taper=(0.8, 0.8))
    b.box((0.48, 0, 0.22), (0.12, 0.18, 0.06), "glass", bev=0.02, rot=(0, 20, 0))
    b.box((-0.3, 0, 0.2), (0.6, 0.36, 0.08), "dark", bev=0.03)
    b.sym("box", (-0.1, 0.27, 0.06), (1.2, 0.04, 0.08), "team", bev=0.01)
    for s in (1, -1):
        b.box((-0.25, 0.45 * s, 0.03), (0.6, 0.22, 0.16), "hull", bev=0.05)
        b.cyl((-0.6, 0.45 * s, 0.03), 0.09, 0.14, "dark", axis="x", seg=16, bev=0.02)
        b.cyl((-0.675, 0.45 * s, 0.03), 0.07, 0.02, "engine", axis="x", seg=16)
        b.box((-0.25, 0.3 * s, 0.03), (0.3, 0.14, 0.06), "dark", bev=0.02)
        b.box((0.05, 0.57 * s, 0.03), (0.04, 0.03, 0.05), "glow")
    b.box((-0.68, 0, 0.12), (0.06, 0.2, 0.06), "engine")
    for i in range(4):
        b.box((-0.45 + i * 0.22, 0, 0.255), (0.08, 0.3, 0.012), "glow")
    t = m.group("turret", (0.3, 0, -0.08))
    t.sphere((0.3, 0, -0.1), (0.12, 0.12, 0.08), "dark")
    t.box((0.38, 0, -0.12), (0.14, 0.12, 0.08), "hull", bev=0.025)
    for dy in (-0.035, 0.035):
        t.cyl((0.56, dy, -0.12), 0.02, 0.28, "metal", axis="x", seg=10)
    t.cyl((0.7, 0, -0.12), 0.03, 0.02, "glow", axis="x", seg=10)
    m.loc("muzzle", (0.71, 0, -0.12), "turret")
    m.sym_loc("engine", (-0.69, 0.45, 0.03))
    return m


# ---------------------------------------------------------------- prédios

def _pad(b, sx, sy, h=0.06):
    b.box((0, 0, h / 2), (sx, sy, h), "dark", bev=0.03)
    b.box((0, 0, h + 0.005), (sx - 0.12, sy - 0.12, 0.01), "hull")


def _windows(b, x, y, z, n, dx, w=0.12, h=0.04, axis="x", mat="glow"):
    for i in range(n):
        o = (i - (n - 1) / 2) * dx
        if axis == "x":
            b.box((x + o, y, z), (w, 0.012, h), mat)
        else:
            b.box((x, y + o, z), (0.012, w, h), mat)


def cy(name):
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 2.9)
    b.box((0.1, 0.1, 0.42), (2.1, 2.0, 0.72), "hull", bev=0.1, taper=(0.9, 0.9))
    b.box((0.1, -1.08, 0.3), (1.2, 0.2, 0.5), "dark", bev=0.05)       # portão (frente = -Y)
    b.box((0.1, -1.19, 0.3), (0.9, 0.02, 0.38), "accent")
    b.box((-0.4, 0.3, 0.98), (1.0, 1.0, 0.45), "hull", bev=0.08, taper=(0.85, 0.85))
    b.sphere((-0.4, 0.3, 1.2), (0.42, 0.42, 0.26), "glass")
    b.torus((-0.4, 0.3, 1.2), 0.43, 0.035, "team", seg=32, seg2=8)
    b.box((0.75, -0.4, 0.95), (0.5, 0.5, 0.35), "dark", bev=0.05)
    b.cyl((0.75, -0.4, 1.4), 0.025, 0.6, "metal", seg=8)
    b.sphere((0.75, -0.4, 1.72), 0.05, "glow")
    b.cyl((0.65, 0.65, 0.98), 0.28, 0.06, "dark", seg=24)
    b.cone((0.65, 0.65, 1.08), 0.3, 0.12, "metal", seg=24, rot=(180, 0, 0))
    _windows(b, 0.1, -1.0, 0.65, 6, 0.3)
    b.sym("box", (1.17, 0.0, 0.42), (0.02, 1.6, 0.06), "team")
    b.box((0.1, 1.07, 0.42), (1.6, 0.02, 0.06), "team")
    for x, y in ((-1.3, -1.3), (1.3, -1.3), (-1.3, 1.3), (1.3, 1.3)):
        b.cyl((x, y, 0.12), 0.06, 0.12, "dark", seg=12)
        b.sphere((x, y, 0.2), 0.03, "glow")
    return m


def power(name):
    m = Model(name, P)
    b = m.body
    _pad(b, 1.9, 1.9)
    b.box((0, 0.1, 0.3), (1.5, 1.2, 0.5), "hull", bev=0.08)
    b.cyl((-0.25, 0.15, 0.85), 0.36, 0.7, "hull", seg=28, r2=0.3, bev=0.04)
    b.torus((-0.25, 0.15, 0.7), 0.37, 0.03, "glow", seg=32, seg2=8)
    b.torus((-0.25, 0.15, 0.95), 0.33, 0.025, "team", seg=32, seg2=8)
    b.cyl((-0.25, 0.15, 1.22), 0.22, 0.04, "dark", seg=24)
    b.sphere((-0.25, 0.15, 1.24), (0.16, 0.16, 0.06), "glow")
    b.box((0.45, -0.25, 0.65), (0.4, 0.5, 0.3), "dark", bev=0.05)
    b.sym("cyl", (0.45, 0.2, 0.7), 0.08, 0.5, "metal", seg=14)
    _windows(b, 0.0, -0.51, 0.35, 4, 0.3, w=0.14)
    m.loc("smoke", (0.45, 0.2, 1.0))
    m.loc("smoke", (0.45, -0.2, 1.0))
    return m


def refinery(name):
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 1.9)
    b.box((-0.45, 0.2, 0.42), (1.6, 1.2, 0.74), "hull", bev=0.08, taper=(0.95, 0.9))
    for x in (0.55, 1.05):
        b.cyl((x, 0.35, 0.55), 0.24, 0.9, "hull", seg=24, bev=0.04)
        b.sphere((x, 0.35, 1.0), (0.24, 0.24, 0.12), "hull")
        b.torus((x, 0.35, 0.5), 0.25, 0.022, "team", seg=28, seg2=6)
        b.box((x, 0.1, 0.6), (0.08, 0.02, 0.5), "glow")
    b.tube((0.0, 0.35, 0.8), (0.55, 0.35, 0.8), 0.05, "metal")
    b.tube((0.55, 0.35, 0.9), (1.05, 0.35, 0.9), 0.04, "metal")
    b.box((-0.45, -0.55, 0.25), (0.9, 0.3, 0.4), "dark", bev=0.04)   # doca de descarga
    b.box((-0.45, -0.71, 0.25), (0.7, 0.02, 0.3), "accent")
    b.cyl((-0.9, 0.4, 1.0), 0.07, 0.5, "metal", seg=12)
    _windows(b, -0.45, -0.41, 0.62, 4, 0.32)
    m.loc("smoke", (-0.9, 0.4, 1.28))
    return m


def barracks(name):
    m = Model(name, P)
    b = m.body
    _pad(b, 1.9, 1.9)
    b.box((0, 0.1, 0.35), (1.5, 1.3, 0.6), "hull", bev=0.08, taper=(0.92, 0.9))
    b.box((0, -0.62, 0.25), (0.6, 0.12, 0.4), "dark", bev=0.04)
    b.box((0, -0.69, 0.25), (0.44, 0.02, 0.3), "glow")
    b.box((-0.3, 0.3, 0.75), (0.7, 0.6, 0.22), "dark", bev=0.05)
    b.box((0.4, 0.3, 0.72), (0.4, 0.5, 0.16), "hull", bev=0.04)
    b.sym("box", (0.76, 0.1, 0.35), (0.02, 1.0, 0.08), "team")
    b.box((0.0, 0.76, 0.35), (1.2, 0.02, 0.08), "team")
    b.cyl((0.45, 0.4, 1.0), 0.015, 0.4, "metal", seg=6)
    b.box((0.52, 0.4, 1.1), (0.12, 0.01, 0.08), "team")   # bandeira
    _windows(b, -0.45, -0.56, 0.5, 2, 0.24, w=0.14)
    _windows(b, 0.45, -0.56, 0.5, 2, 0.24, w=0.14)
    return m


def factory(name):
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 2.9)
    b.box((0, 0.25, 0.55), (2.4, 2.0, 1.0), "hull", bev=0.1)
    for i in range(4):
        b.box((-0.9 + i * 0.6, 0.25, 1.1), (0.5, 1.9, 0.12), "dark", bev=0.04, taper=(0.6, 1.0))
    b.box((0, -0.78, 0.4), (1.3, 0.12, 0.7), "dark", bev=0.05)
    for i in range(5):
        b.box((0, -0.85, 0.12 + i * 0.13), (1.15, 0.02, 0.05), "metal")
    b.box((0, -0.87, 0.8), (1.3, 0.02, 0.05), "accent")
    b.sym("box", (0.95, -0.82, 0.4), (0.06, 0.04, 0.7), "glow")
    b.box((-0.9, 0.9, 1.3), (0.4, 0.4, 0.5), "dark", bev=0.05)
    b.cyl((-0.9, 0.9, 1.7), 0.1, 0.3, "metal", seg=12)
    b.box((1.25, 0.25, 0.55), (0.02, 1.6, 0.08), "team")
    b.box((-1.25, 0.25, 0.55), (0.02, 1.6, 0.08), "team")
    # Guindaste
    b.box((0.8, 0.6, 1.3), (0.1, 0.1, 0.5), "accent", bev=0.02)
    b.box((0.55, 0.6, 1.56), (0.7, 0.08, 0.06), "accent", bev=0.02)
    m.loc("smoke", (-0.9, 0.9, 1.88))
    return m


def starport(name):
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 2.9)
    b.cyl((0.2, -0.2, 0.18), 1.05, 0.24, "hull", seg=40, bev=0.05)
    b.cyl((0.2, -0.2, 0.31), 0.9, 0.02, "dark", seg=40)
    b.torus((0.2, -0.2, 0.32), 0.75, 0.02, "glow", seg=40, seg2=6)
    for i in range(8):
        import math
        a = i * math.pi / 4
        b.box((0.2 + math.cos(a) * 0.97, -0.2 + math.sin(a) * 0.97, 0.34), (0.1, 0.1, 0.04), "team")
    b.box((-1.0, 0.95, 0.65), (0.7, 0.7, 1.2), "hull", bev=0.08, taper=(0.8, 0.8))
    b.box((-1.0, 0.95, 1.35), (0.85, 0.85, 0.22), "glass", bev=0.05)
    b.box((-1.0, 0.95, 1.5), (0.6, 0.6, 0.08), "dark", bev=0.03)
    b.cyl((-1.0, 0.95, 1.75), 0.02, 0.4, "metal", seg=6)
    b.sphere((-1.0, 0.95, 1.96), 0.04, "glow")
    b.box((1.1, 1.05, 0.4), (0.5, 0.5, 0.7), "dark", bev=0.05)
    b.box((1.1, 0.78, 0.4), (0.4, 0.02, 0.05), "glow")
    return m


def turret(name):
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.08), (0.9, 0.9, 0.16), "dark", bev=0.05, taper=(0.9, 0.9))
    b.cyl((0, 0, 0.24), 0.33, 0.18, "hull", seg=24, bev=0.04, r2=0.28)
    b.torus((0, 0, 0.17), 0.33, 0.02, "team", seg=24, seg2=6)
    g = m.group("gun", (0, 0, 0.36))
    g.sphere((0, 0, 0.42), (0.22, 0.22, 0.14), "hull")
    g.box((0.05, 0, 0.44), (0.3, 0.22, 0.12), "hull", bev=0.04)
    for dy in (-0.07, 0.07):
        g.cyl((0.35, dy, 0.45), 0.03, 0.4, "dark", axis="x", seg=12)
        g.cyl((0.54, dy, 0.45), 0.035, 0.02, "glow", axis="x", seg=12)
    g.sym("box", (-0.05, 0.13, 0.5), (0.14, 0.06, 0.1), "dark", bev=0.02)   # mísseis AA
    g.box((0.12, 0, 0.51), (0.05, 0.1, 0.02), "glow")
    m.loc("muzzle", (0.56, 0, 0.45), "gun")
    return m


def all_models():
    out = []
    for k in ("rifle", "smg", "mg", "at", "sniper"):
        out.append(soldier("hum_" + k, k))
    out += [harvester("hum_harvester"), scout("hum_scout"), tank("hum_tank"),
            heavy_tank("hum_heavy"), fighter("hum_fighter"), gunship("hum_gunship")]
    out += [cy("cy_hum"), power("power_hum"), refinery("refinery_hum"), barracks("barracks_hum"),
            factory("factory_hum"), starport("starport_hum"), turret("turret_hum")]
    return out
