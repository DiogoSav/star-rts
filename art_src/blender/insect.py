"""Enxame Kheth (insetos): carapaças brilhantes, bolsas de ácido luminosas, patas articuladas."""

import math

from core import Model
from palettes import INSECT as P


def _legs(m, pairs, hip_z, reach, lift, r=0.022, body_y=0.08, foot_z=0.0, mat="chitin"):
    """Patas articuladas, uma por grupo (limb_<lado><índice>) com pivô no quadril.
    pairs: posições X dos pares de patas. O jogo anima em tripé alternado."""
    for i, x in enumerate(pairs):
        for s in (1, -1):
            hip = (x, body_y * s, hip_z)
            p = m.group("limb_%s%d" % ("l" if s > 0 else "r", i), hip)
            knee = (x * 1.25, (body_y + reach * 0.55) * s, hip_z + lift)
            foot = (x * 1.5 + (0.03 if x >= 0 else -0.03), (body_y + reach) * s, foot_z)
            p.sphere(hip, r * 1.4, "dark")
            p.tube(hip, knee, r * 1.2, mat)
            p.sphere(knee, r * 1.2, "team")
            p.tube(knee, foot, r, mat, r2=r * 0.3)


def _head(t, x, z, s=1.0, mandibles=True):
    t.sphere((x, 0, z), (0.07 * s, 0.065 * s, 0.055 * s), "chitin")
    t.sym("sphere", (x + 0.035 * s, 0.04 * s, z + 0.015 * s), (0.025 * s, 0.02 * s, 0.022 * s), "glass")
    if mandibles:
        t.sym("cone", (x + 0.08 * s, 0.03 * s, z - 0.02 * s), 0.015 * s, 0.08 * s, "bone", axis="x",
              seg=8, rot=(0, 90, -20))


def _antennae(t, x, z, s=1.0):
    for k in (1, -1):
        t.tube((x, 0.03 * s * k, z), (x + 0.1 * s, 0.1 * s * k, z + 0.12 * s), 0.006 * s, "dark", r2=0.002)


def bug(name, kind):
    """Infantaria inseto: abdômen, tórax erguido (torso) com cabeça e arma orgânica."""
    m = Model(name, P)
    big = {"rifle": 1.0, "smg": 1.05, "mg": 1.15, "at": 1.2, "sniper": 0.95}[kind]
    s = big
    b = m.body
    _legs(m, [0.08 * s, -0.02 * s, -0.12 * s], 0.24 * s, 0.17 * s, 0.1 * s, r=0.018 * s, body_y=0.06 * s)
    b.sphere((-0.17 * s, 0, 0.26 * s), (0.17 * s, 0.11 * s, 0.1 * s), "chitin", rot=(0, -15, 0))
    for i in range(3):
        b.torus((-0.12 * s - i * 0.07 * s, 0, 0.26 * s + i * 0.02 * s), 0.1 * s - i * 0.015 * s, 0.012 * s,
                "dark", seg=20, seg2=6, rot=(0, 90 - 15, 0), scale_z=1.0)
    b.sphere((-0.2 * s, 0, 0.33 * s), (0.09 * s, 0.06 * s, 0.03 * s), "team", rot=(0, -15, 0))
    t = m.group("torso", (0.02 * s, 0, 0.26 * s))
    t.sphere((0.04 * s, 0, 0.3 * s), (0.08 * s, 0.075 * s, 0.09 * s), "chitin", rot=(0, 30, 0))
    t.sphere((0.02 * s, 0, 0.36 * s), (0.05 * s, 0.05 * s, 0.04 * s), "flesh")
    _head(t, 0.11 * s, 0.42 * s, s)
    _antennae(t, 0.13 * s, 0.46 * s, s)
    if kind == "rifle":
        # Lançador de espinhos no "braço" direito
        t.tube((0.06 * s, -0.08 * s, 0.32 * s), (0.2 * s, -0.08 * s, 0.33 * s), 0.025 * s, "flesh", r2=0.018 * s)
        t.cone((0.24 * s, -0.08 * s, 0.33 * s), 0.02 * s, 0.07 * s, "bone", axis="x", seg=8, rot=(0, 180, 0))
        t.sym("tube", (0.06 * s, 0.08 * s, 0.34 * s), (0.14 * s, 0.1 * s, 0.24 * s), 0.012 * s, "chitin")
        muzzle = (0.27 * s, -0.08 * s, 0.33 * s)
    elif kind == "smg":
        # Rasgador: duas foices de louva-a-deus
        for k in (1, -1):
            t.tube((0.06 * s, 0.07 * s * k, 0.36 * s), (0.16 * s, 0.1 * s * k, 0.46 * s), 0.018 * s, "chitin")
            t.tube((0.16 * s, 0.1 * s * k, 0.46 * s), (0.26 * s, 0.08 * s * k, 0.3 * s), 0.014 * s, "bone",
                   r2=0.003)
            t.sphere((0.16 * s, 0.1 * s * k, 0.46 * s), 0.02 * s, "team")
        muzzle = (0.24 * s, 0, 0.34 * s)
    elif kind == "mg":
        # Cuspidor: bolsa de ácido luminosa e boca larga (atinge naves)
        t.sphere((-0.04 * s, 0, 0.45 * s), (0.09 * s, 0.08 * s, 0.08 * s), "glow")
        t.sym("torus", (-0.04 * s, 0, 0.45 * s), 0.085 * s, 0.008 * s, "dark", seg=16, seg2=4, rot=(90, 0, 25))
        t.cone((0.18 * s, 0, 0.41 * s), 0.035 * s, 0.07 * s, "flesh", axis="x", seg=10)
        muzzle = (0.22 * s, 0, 0.41 * s)
    elif kind == "at":
        # Perfurador: chifre ósseo enorme
        t.cone((0.24 * s, 0, 0.45 * s), 0.045 * s, 0.24 * s, "bone", axis="x", seg=12, rot=(0, -10, 0))
        t.sym("sphere", (0.0, 0.07 * s, 0.4 * s), (0.05 * s, 0.03 * s, 0.05 * s), "glow")
        muzzle = (0.36 * s, 0, 0.47 * s)
    else:
        # Espreitador: pescoço longo e ferrão-agulha
        t.tube((0.06 * s, 0, 0.36 * s), (0.12 * s, 0, 0.5 * s), 0.025 * s, "flesh")
        t.cone((0.2 * s, 0, 0.5 * s), 0.016 * s, 0.22 * s, "bone", axis="x", seg=8, rot=(0, 180, 0))
        t.sphere((0.08 * s, 0, 0.46 * s), 0.025 * s, "glow")
        muzzle = (0.31 * s, 0, 0.5 * s)
    m.loc("muzzle", muzzle, "torso")
    return m


def harvester(name):
    """Larva coletora: verme segmentado com boca de sucção."""
    m = Model(name, P)
    b = m.body
    # Segmentos 1..5 são grupos (seg_<i>): o jogo os ondula para a larva rastejar
    for i in range(6):
        f = i / 5
        x = 0.45 - f
        r = 0.24 - 0.08 * f
        g = b if i == 0 else m.group("seg_%d" % i, (x, 0, r * 0.4))
        g.sphere((x, 0, r * 0.4), (r * 0.75, r, r * 0.8), "chitin")
        g.sphere((x, 0, r * 1.08), (r * 0.45, r * 0.5, r * 0.18), "team")
        if i % 2 == 1:
            g.sphere((x, 0, r * 1.2), (0.08, 0.12, 0.06), "glow")
        if i > 0:
            g.sym("cone", (x, 0.2, 0.05), 0.03, 0.12, "dark", seg=6, rot=(40, 0, 0))
    b.sphere((0.55, 0, 0.18), (0.15, 0.2, 0.17), "flesh")
    b.torus((0.66, 0, 0.18), 0.12, 0.03, "bone", seg=20, seg2=6, rot=(0, 90, 0))
    b.sphere((0.68, 0, 0.18), 0.08, "dark")
    for i in range(6):
        a = i * math.pi / 3
        b.cone((0.72, math.cos(a) * 0.12, 0.18 + math.sin(a) * 0.12), 0.02, 0.08, "bone", axis="x", seg=6)
    return m


def runner(name):
    """Corredor: besouro rápido com glândula de ácido nas costas (atinge naves)."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.2, 0.0, -0.2], 0.26, 0.32, 0.18, r=0.026, body_y=0.14)
    b.sphere((-0.05, 0, 0.3), (0.38, 0.24, 0.16), "chitin")
    b.sphere((-0.05, 0, 0.36), (0.3, 0.2, 0.1), "team")
    b.sphere((-0.05, 0, 0.4), (0.2, 0.06, 0.07), "chitin")
    b.sym("sphere", (-0.1, 0.12, 0.42), (0.1, 0.05, 0.04), "glow")
    b.sphere((0.33, 0, 0.3), (0.12, 0.13, 0.1), "chitin")
    b.sym("sphere", (0.4, 0.08, 0.33), (0.035, 0.03, 0.03), "glass")
    b.sym("cone", (0.48, 0.07, 0.26), 0.025, 0.14, "bone", axis="x", seg=8, rot=(0, 90, -25))
    t = m.group("turret", (-0.05, 0, 0.42))
    t.sphere((-0.05, 0, 0.47), (0.1, 0.1, 0.08), "flesh")
    t.cone((0.1, 0, 0.5), 0.04, 0.16, "flesh", axis="x", seg=10, rot=(0, 180, 0))
    t.sphere((-0.05, 0, 0.52), 0.05, "glow")
    m.loc("muzzle", (0.19, 0, 0.5), "turret")
    return m


def beetle(name):
    """Escaravelho: tanque vivo com chifre que dispara bolas de plasma."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.3, 0.0, -0.3], 0.3, 0.38, 0.22, r=0.034, body_y=0.2)
    b.sphere((-0.1, 0, 0.36), (0.5, 0.36, 0.24), "chitin")
    b.sym("sphere", (-0.15, 0.17, 0.46), (0.42, 0.2, 0.14), "hull", rot=(-12, 0, 0))
    b.box((-0.15, 0, 0.56), (0.7, 0.04, 0.04), "team", bev=0.015)
    b.sym("sphere", (-0.35, 0.12, 0.52), (0.08, 0.05, 0.04), "glow")
    t = m.group("turret", (0.35, 0, 0.36))
    t.sphere((0.42, 0, 0.36), (0.2, 0.24, 0.17), "chitin")
    t.sphere((0.5, 0, 0.45), (0.12, 0.14, 0.06), "team")
    t.sym("sphere", (0.56, 0.12, 0.38), (0.04, 0.035, 0.035), "glass")
    t.cone((0.75, 0, 0.47), 0.07, 0.38, "bone", axis="x", seg=14, rot=(0, -12, 0))
    t.sym("cone", (0.62, 0.12, 0.3), 0.03, 0.16, "bone", axis="x", seg=8, rot=(0, 75, -20))
    t.sphere((0.6, 0, 0.47), 0.06, "glow")
    m.loc("muzzle", (0.93, 0, 0.51), "turret")
    return m


def behemoth(name):
    """Behemoth: colosso blindado com espinhos de cristal e canhão de ácido."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.4, 0.13, -0.13, -0.4], 0.38, 0.45, 0.32, r=0.045, body_y=0.28)
    b.sphere((-0.15, 0, 0.5), (0.7, 0.45, 0.3), "chitin")
    for i in range(4):
        x = 0.25 - i * 0.25
        b.sphere((x, 0, 0.62), (0.16, 0.4, 0.16), "hull")
        b.sym("cone", (x, 0.25, 0.78), 0.05, 0.3, "bone", seg=8, rot=(-25, 0, 0))
        b.sphere((x, 0, 0.79), (0.07, 0.07, 0.05), "glow")
    b.box((-0.1, 0, 0.78), (0.9, 0.05, 0.03), "team")
    b.sphere((-0.8, 0, 0.45), (0.2, 0.25, 0.2), "flesh")
    t = m.group("turret", (0.45, 0, 0.5))
    t.sphere((0.6, 0, 0.5), (0.25, 0.3, 0.22), "chitin")
    t.sphere((0.68, 0, 0.62), (0.15, 0.2, 0.08), "team")
    t.sym("sphere", (0.78, 0.16, 0.52), (0.05, 0.045, 0.045), "glass")
    for k in (1, -1):
        t.cone((0.92, 0.12 * k, 0.42), 0.05, 0.3, "bone", axis="x", seg=10, rot=(0, 95, -15 * k))
    t.cyl((0.88, 0, 0.55), 0.08, 0.2, "flesh", axis="x", seg=14, r2=0.06)
    t.sphere((0.99, 0, 0.55), 0.06, "glow")
    m.loc("muzzle", (1.03, 0, 0.55), "turret")
    return m


def wasp(name):
    """Vespa: caça orgânico de asas batendo; ferrões contra naves e solo."""
    m = Model(name, P)
    b = m.body
    b.sphere((0.15, 0, 0.0), (0.14, 0.1, 0.1), "chitin")
    b.sphere((-0.18, 0, -0.03), (0.22, 0.11, 0.1), "chitin", rot=(0, 10, 0))
    for i in range(3):
        b.torus((-0.1 - i * 0.09, 0, -0.03 - i * 0.01), 0.1 - i * 0.012, 0.014, "team", seg=20, seg2=6,
                rot=(0, 80, 0))
    b.cone((-0.45, 0, -0.07), 0.04, 0.14, "bone", axis="x", seg=8, rot=(0, -10, 0))
    b.sphere((0.3, 0, 0.02), (0.07, 0.08, 0.065), "chitin")
    b.sym("sphere", (0.34, 0.05, 0.04), (0.035, 0.03, 0.035), "glass")
    b.sym("cone", (0.4, 0.04, -0.02), 0.015, 0.08, "bone", axis="x", seg=6, rot=(0, 90, -15))
    b.sphere((0.1, 0, -0.08), (0.06, 0.05, 0.04), "glow")
    for g, s in (("wing_l", 1), ("wing_r", -1)):
        w = m.group(g, (0.12, 0.08 * s, 0.08))
        w.wing((0.12, 0.08 * s, 0.08), 0.45, 0.18, 0.1, 0.01, "engine", sweep=0.1, dihedral=0.05, side=s)
        w.wing((0.0, 0.07 * s, 0.07), 0.3, 0.12, 0.06, 0.008, "engine", sweep=0.15, dihedral=0.02, side=s)
    m.sym_loc("muzzle", (0.42, 0.04, -0.03))
    return m


def leviathan(name):
    """Leviatã: arraia voadora gigante que despeja ácido (só alvos no solo)."""
    m = Model(name, P)
    b = m.body
    b.sphere((0, 0, 0.05), (0.55, 0.3, 0.14), "chitin")
    b.sphere((0, 0, 0.13), (0.42, 0.2, 0.08), "hull")
    for i in range(4):
        b.sphere((0.25 - i * 0.17, 0, 0.18), (0.07, 0.12, 0.05), "team")
        b.sym("sphere", (0.2 - i * 0.17, 0.15, 0.12), (0.05, 0.04, 0.04), "glow")
    b.sphere((0.55, 0, 0.04), (0.16, 0.2, 0.1), "chitin")
    b.sym("sphere", (0.63, 0.12, 0.07), (0.04, 0.04, 0.035), "glass")
    b.sym("cone", (0.72, 0.1, 0.0), 0.03, 0.16, "bone", axis="x", seg=8, rot=(0, 90, -20))
    b.sphere((0.05, 0, -0.1), (0.25, 0.18, 0.1), "glow")
    for i in range(3):
        for k in (1, -1):
            b.tube((-0.1 - i * 0.12, 0.08 * k, -0.05), (-0.3 - i * 0.12, 0.12 * k, -0.32), 0.016, "flesh", r2=0.004)
    b.tube((-0.5, 0, 0.04), (-1.0, 0, 0.0), 0.04, "chitin", r2=0.01)
    for g, s in (("wing_l", 1), ("wing_r", -1)):
        w = m.group(g, (0.05, 0.25 * s, 0.05))
        w.wing((0.05, 0.25 * s, 0.05), 0.75, 0.6, 0.18, 0.04, "chitin", sweep=0.35, dihedral=0.0, side=s)
        w.wing((0.0, 0.3 * s, 0.075), 0.55, 0.3, 0.08, 0.015, "team", sweep=0.3, dihedral=0.0, side=s)
        w.sphere((-0.05, 0.6 * s, 0.07), (0.08, 0.05, 0.03), "glow")
    m.loc("muzzle", (0.05, 0, -0.18))
    return m


# ---------------------------------------------------------------- prédios

def _mound(b, c, r, h, mat="hull"):
    b.sphere((c[0], c[1], 0.0), (r, r, h), mat)


def _spire(b, x, y, h, r=0.12):
    b.cone((x, y, h / 2), r, h, "chitin", seg=10)
    b.torus((x, y, h * 0.3), r * 0.75, r * 0.15, "team", seg=12, seg2=4)
    b.sphere((x, y, h * 0.55), r * 0.35, "glow")


def _creep(b, sx, sy):
    b.sphere((0, 0, 0.0), (sx * 0.55, sy * 0.55, 0.06), "flesh")


def _pods(b, pts, r=0.1):
    for x, y, z in pts:
        b.sphere((x, y, z), (r, r, r * 1.2), "glow")
        b.torus((x, y, z), r * 1.02, r * 0.12, "chitin", seg=14, seg2=4, rot=(90, 0, 0))


def cy(name):
    m = Model(name, P)
    b = m.body
    _creep(b, 2.9, 2.9)
    _mound(b, (0, 0.15), 1.25, 0.9)
    _mound(b, (-0.2, 0.3), 0.8, 1.45, "chitin")
    for i in range(6):
        a = i * math.pi / 3
        b.cone((math.cos(a) * 0.95, 0.15 + math.sin(a) * 0.95, 0.5), 0.12, 0.9, "bone", seg=8,
               rot=(math.sin(a) * -25, math.cos(a) * 25, 0))
    b.sphere((-0.2, 0.3, 1.25), (0.3, 0.3, 0.3), "glow")
    b.torus((-0.2, 0.3, 1.1), 0.45, 0.06, "team", seg=24, seg2=6)
    b.sphere((0.1, -0.92, 0.18), (0.38, 0.18, 0.28), "dark")    # entrada
    b.torus((0.1, -0.95, 0.2), 0.3, 0.05, "bone", seg=20, seg2=6, rot=(90, 0, 0))
    _pods(b, [(0.85, -0.6, 0.15), (-0.9, -0.5, 0.12), (0.8, 0.9, 0.15)], 0.12)
    m.loc("smoke", (-0.2, 0.3, 1.55))
    return m


def power(name):
    m = Model(name, P)
    b = m.body
    _creep(b, 1.9, 1.9)
    _mound(b, (0, 0), 0.75, 0.35)
    b.sphere((0, 0.05, 0.55), (0.42, 0.42, 0.45), "glow")
    for i in range(5):
        a = i * 2 * math.pi / 5
        b.tube((math.cos(a) * 0.6, 0.05 + math.sin(a) * 0.6, 0.05), (math.cos(a) * 0.18, 0.05 + math.sin(a) * 0.18, 0.98),
               0.05, "chitin", r2=0.02)
    b.torus((0, 0.05, 0.55), 0.44, 0.04, "team", seg=24, seg2=6)
    return m


def refinery(name):
    m = Model(name, P)
    b = m.body
    _creep(b, 2.9, 1.9)
    _mound(b, (-0.3, 0.15), 1.0, 0.75)
    b.sphere((0.8, 0.2, 0.35), (0.45, 0.45, 0.5), "flesh")
    b.torus((0.8, 0.2, 0.55), 0.38, 0.04, "chitin", seg=20, seg2=6)
    b.sphere((0.8, 0.2, 0.75), (0.18, 0.18, 0.12), "glow")
    b.sphere((-0.3, -0.62, 0.15), (0.45, 0.2, 0.18), "dark")
    b.torus((-0.3, -0.7, 0.16), 0.3, 0.04, "bone", seg=20, seg2=6, rot=(90, 0, 0), scale_z=0.6)
    _spire(b, -0.9, 0.5, 1.1)
    _pods(b, [(0.0, 0.5, 0.6), (-0.6, 0.0, 0.6)], 0.11)
    m.loc("smoke", (0.8, 0.2, 0.9))
    return m


def barracks(name):
    m = Model(name, P)
    b = m.body
    _creep(b, 1.9, 1.9)
    _mound(b, (0, 0.1), 0.8, 0.55)
    for x, y in ((-0.3, 0.3), (0.3, 0.35), (0.0, -0.1), (0.4, -0.3), (-0.45, -0.25)):
        b.sphere((x, y, 0.5), (0.2, 0.2, 0.26), "glow")
        b.sphere((x, y, 0.62), (0.21, 0.21, 0.14), "chitin")
    b.sphere((0.0, -0.75, 0.12), (0.25, 0.12, 0.18), "dark")
    _spire(b, 0.7, 0.7, 0.7, 0.08)
    return m


def factory(name):
    m = Model(name, P)
    b = m.body
    _creep(b, 2.9, 2.9)
    _mound(b, (0, 0.2), 1.25, 0.8)
    b.sphere((0.0, 0.25, 0.75), (0.85, 0.7, 0.45), "chitin")
    for i in range(5):
        x = -0.8 + i * 0.4
        b.tube((x, -0.4, 0.2), (x * 0.8, 0.3, 1.15), 0.06, "bone", r2=0.03)
    b.sphere((0.0, -0.95, 0.2), (0.6, 0.25, 0.32), "dark")
    b.torus((0.0, -1.0, 0.22), 0.45, 0.06, "bone", seg=24, seg2=6, rot=(90, 0, 0), scale_z=0.7)
    b.sphere((0.0, 0.3, 1.15), (0.25, 0.25, 0.15), "glow")
    b.torus((0.0, 0.25, 0.75), 0.86, 0.05, "team", seg=32, seg2=6)
    _spire(b, 1.1, 1.0, 1.0)
    _spire(b, -1.1, 1.0, 0.8)
    m.loc("smoke", (0.0, 0.3, 1.3))
    return m


def starport(name):
    m = Model(name, P)
    b = m.body
    _creep(b, 2.9, 2.9)
    _mound(b, (0.1, -0.1), 1.1, 0.3)
    b.torus((0.1, -0.1, 0.25), 0.85, 0.12, "chitin", seg=32, seg2=8)
    b.cyl((0.1, -0.1, 0.25), 0.75, 0.04, "flesh", seg=32)
    b.sphere((0.1, -0.1, 0.27), (0.4, 0.4, 0.05), "glow")
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        x, y = 0.1 + math.cos(a) * 1.1, -0.1 + math.sin(a) * 1.1
        b.tube((x, y, 0.0), (0.1 + math.cos(a) * 0.6, -0.1 + math.sin(a) * 0.6, 1.4), 0.07, "bone", r2=0.02)
    b.torus((0.1, -0.1, 1.3), 0.45, 0.04, "team", seg=24, seg2=6)
    _pods(b, [(-1.1, 1.0, 0.25), (1.1, 1.05, 0.25)], 0.16)
    return m


def turret(name):
    m = Model(name, P)
    b = m.body
    b.sphere((0, 0, 0.0), (0.45, 0.45, 0.18), "flesh")
    b.sphere((0, 0, 0.12), (0.3, 0.3, 0.2), "chitin")
    g = m.group("gun", (0, 0, 0.28))
    g.sphere((0, 0, 0.35), (0.16, 0.15, 0.14), "chitin")
    g.sphere((-0.05, 0, 0.42), (0.1, 0.1, 0.08), "glow")
    g.cone((0.22, 0, 0.38), 0.06, 0.3, "bone", axis="x", seg=12, rot=(0, -80, 0))
    g.sym("cone", (0.0, 0.14, 0.45), 0.04, 0.2, "bone", seg=8, rot=(-30, 0, 0))
    m.loc("muzzle", (0.37, 0, 0.4), "gun")
    return m


def medic(name):
    """Poço de Regeneração: lago de seiva brilhante cercado por costelas e bolsas de gosma."""
    m = Model(name, P)
    b = m.body
    _creep(b, 1.9, 1.9)
    b.torus((0, 0, 0.1), 0.62, 0.14, "flesh", seg=32, seg2=8)
    b.cyl((0, 0, 0.1), 0.6, 0.04, "glow", seg=32)
    b.sphere((0, 0, 0.14), (0.3, 0.3, 0.06), "glow")
    for i in range(5):
        a = i * 2 * math.pi / 5 + 0.3
        b.tube((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.02),
               (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.9), 0.05, "bone", r2=0.015)
    b.torus((0, 0, 0.32), 0.66, 0.04, "team", seg=24, seg2=6)
    b.sphere((0, 0, 0.88), (0.14, 0.14, 0.17), "chitin")
    b.cone((0, 0, 0.55), 0.04, 0.3, "glow", seg=10, rot=(180, 0, 0))   # gota de seiva
    _pods(b, [(0.75, 0.65, 0.12), (-0.8, 0.6, 0.12), (0.7, -0.7, 0.12)], 0.12)
    return m


def all_models():
    out = []
    for k in ("rifle", "smg", "mg", "at", "sniper"):
        out.append(bug("ins_" + k, k))
    out += [harvester("ins_harvester"), runner("ins_scout"), beetle("ins_tank"),
            behemoth("ins_heavy"), wasp("ins_fighter"), leviathan("ins_gunship")]
    out += [cy("cy_ins"), power("power_ins"), refinery("refinery_ins"), barracks("barracks_ins"),
            factory("factory_ins"), starport("starport_ins"), turret("turret_ins"),
            medic("medic_ins")]
    return out
