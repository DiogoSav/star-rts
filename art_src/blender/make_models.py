"""Gera todos os modelos .glb do Star-RTS.

Uso (na pasta do projeto):
  blender -b --factory-startup --python art_src/blender/make_models.py -- models [filtro]

Rodar de novo sobrescreve os .glb (edições feitas à mão no Blender se perdem).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import core  # noqa: E402
import human  # noqa: E402

MODULES = [human]
for mod in ("robot", "insect", "props"):
    try:
        MODULES.append(__import__(mod))
    except ImportError:
        pass

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out_dir = os.path.abspath(args[0] if args else "models")
flt = args[1] if len(args) > 1 else ""
os.makedirs(out_dir, exist_ok=True)

count = 0
for mod in MODULES:
    for model in mod.all_models():
        if flt and flt not in model.name:
            continue
        core.build(model, out_dir)
        count += 1
        print("modelo:", model.name)
print("total:", count)
