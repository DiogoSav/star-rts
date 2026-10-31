"""Cenário do planeta: rochas, pináculos, cristais (recurso), plantas alienígenas e destroços."""

import math
import random

from core import Model
from palettes import PROPS as P


def rock(name, seed, n=3, h=0.5):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    for i in range(n):
        x, y = rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)
        r = rnd.uniform(0.22, 0.38)
        b.ico((x, y, r * 0.35), (r, r * rnd.uniform(0.8, 1.1), r * rnd.uniform(0.7, 1.3) * h * 2),
              "rock" if i % 3 else "dark", sub=2, rough=0.22, seed=seed * 10 + i, rot=(0, 0, rnd.uniform(0, 360)))
    return m


def spire(name, seed):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.1), (0.42, 0.42, 0.22), "dark", sub=2, rough=0.2, seed=seed)
    for i in range(3):
        x, y = rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15)
        hh = rnd.uniform(0.7, 1.3)
        b.cone((x, y, hh / 2), rnd.uniform(0.12, 0.2), hh, "rock", seg=7,
               rot=(rnd.uniform(-10, 10), rnd.uniform(-10, 10), rnd.uniform(0, 60)))
    return m


def crystal(name, seed, n=5, big=1.0):
    """Aglomerado de cristais: usado nos campos de recurso (malha instanciada) e em enfeites."""
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        d = 0.0 if i == 0 else rnd.uniform(0.06, 0.2)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = (0.55 if i == 0 else rnd.uniform(0.2, 0.4)) * big
        r = (0.08 if i == 0 else rnd.uniform(0.035, 0.06)) * big
        tilt = 0 if i == 0 else 25
        rot = (math.sin(a) * -tilt, math.cos(a) * tilt, rnd.uniform(0, 60))
        b.cyl((x, y, h * 0.4), r, h * 0.8, "crystal", seg=6, rot=rot)
        # ponta
        from mathutils import Euler, Vector
        e = Euler([math.radians(q) for q in rot], "XYZ")
        tip = Vector((0, 0, h * 0.4 + h * 0.1)) @ e.to_matrix().transposed()
        b.cone((x + tip.x, y + tip.y, h * 0.4 + tip.z), r, h * 0.2, "crystal", seg=6, rot=rot)
    return m


def plant(name, seed):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.05), (0.25, 0.25, 0.1), "dark", sub=1, rough=0.2, seed=seed)
    for i in range(5):
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(0.0, 0.18)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rnd.uniform(0.35, 0.8)
        top = (x + rnd.uniform(-0.1, 0.1), y + rnd.uniform(-0.1, 0.1), h)
        b.tube((x, y, 0.0), top, 0.025, "plant", r2=0.015)
        b.sphere(top, (0.06, 0.06, 0.05), "glow")
    return m


def debris(name, seed):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.0), (0.4, 0.35, 0.12), "rock", sub=2, rough=0.15, seed=seed)
    for i in range(4):
        b.box((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 0.12), (rnd.uniform(0.2, 0.4), 0.08, 0.05),
              "hull" if i % 2 else "metal", bev=0.01,
              rot=(rnd.uniform(-30, 30), rnd.uniform(-30, 30), rnd.uniform(0, 180)))
    b.box((0.05, 0.0, 0.2), (0.5, 0.12, 0.04), "accent", bev=0.01, rot=(0, -25, 30))
    return m


def all_models():
    return [
        rock("prop_rock_a", 1), rock("prop_rock_b", 2, 4, 0.4), rock("prop_rock_c", 3, 2, 0.7),
        spire("prop_spire_a", 4), spire("prop_spire_b", 5),
        crystal("prop_crystal", 6, 5, 1.0), crystal("ore_crystal", 7, 4, 0.7),
        plant("prop_plant", 8), debris("prop_debris", 9),
    ]
