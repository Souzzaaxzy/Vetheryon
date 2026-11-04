"""Gera casas medievais realistas para o Vetheryon, no estilo enxaimel europeu.

Referências (pesquisa): casas medievais europeias típicas têm base de pedra,
paredes de enxaimel (vigas de madeira expostas sobre reboco claro), telhado de
palha BEM inclinado e chaminé. Aqui montamos isso proceduralmente, com detalhes
(pisos salientes/jetty, vigas cruzadas, porta, janelas, chaminé).

    blender --background --python tools/modeling/generate_buildings.py
"""

import math
import os
import random

import bpy
from mathutils import Vector

OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models")
)

# Paleta medieval
STONE = (0.44, 0.43, 0.41)
PLASTER = (0.86, 0.82, 0.72)
PLASTER2 = (0.80, 0.74, 0.62)
TIMBER = (0.28, 0.18, 0.10)
THATCH = (0.55, 0.45, 0.26)
THATCH2 = (0.48, 0.38, 0.22)
WOOD = (0.33, 0.22, 0.13)
GLASS = (0.50, 0.62, 0.72)


def _reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _mat(name, color, roughness=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = roughness
    return m


def _box(name, loc, size, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.rotation_euler = rot
    o.data.materials.append(material)
    return o


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _export(name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)
    print("EXPORTED", path)


def make_house(seed=1, variant=0):
    """Casa medieval de enxaimel com telhado de palha e jetty (andar saliente)."""
    _reset()
    random.seed(seed)

    stone = _mat("Stone", STONE, 0.95)
    plaster = _mat("Plaster", PLASTER if variant % 2 == 0 else PLASTER2, 0.9)
    timber = _mat("Timber", TIMBER, 0.85)
    thatch = _mat("Thatch", THATCH if variant % 2 == 0 else THATCH2, 0.95)
    wood = _mat("Wood", WOOD, 0.8)
    glass = _mat("Glass", GLASS, 0.2)

    w = random.uniform(4.4, 5.6)     # largura
    d = random.uniform(3.6, 4.4)     # profundidade
    h1 = 2.5                          # altura do andar térreo
    h2 = 2.1                          # altura do andar superior (saliente)
    over = 0.32                       # quanto o andar superior sobressai (jetty)
    parts = []

    # 1. Base de pedra
    parts.append(_box("Foundation", (0, 0, 0.35), (w + 0.15, d + 0.15, 0.7), stone))

    # 2. Térreo: reboco + vigas de enxaimel
    parts.append(_box("GroundWall", (0, 0, 0.7 + h1 / 2), (w, d, h1), plaster))
    # vigas verticais nas 4 quinas + intermediárias
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box("Post", (sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.7 + h1 / 2),
                              (0.16, 0.16, h1), timber))
    for sx in (-1, 1):
        parts.append(_box("PostMid", (sx * w / 4, d / 2, 0.7 + h1 / 2), (0.14, 0.12, h1), timber))
    # travessa horizontal
    parts.append(_box("Beam", (0, 0, 0.7 + h1 - 0.1), (w + 0.05, d + 0.05, 0.18), timber))

    # 3. Andar superior saliente (jetty)
    y0 = 0.7 + h1
    parts.append(_box("UpperWall", (0, 0, y0 + h2 / 2), (w + over, d + over, h2), plaster))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box("UPost", (sx * ((w + over) / 2 - 0.06), sy * ((d + over) / 2 - 0.06), y0 + h2 / 2),
                              (0.16, 0.16, h2), timber))
    # vigas inclinadas decorativas (diagonais) na frente
    for sx in (-1, 1):
        parts.append(_box("Brace", (sx * (w / 4), (d + over) / 2 - 0.02, y0 + h2 * 0.45),
                          (0.11, 0.10, h2 * 0.9), timber, rot=(0, sx * 0.42, 0)))

    # 4. Telhado de palha (muito inclinado), duas águas
    roof_y = y0 + h2
    roof_h = random.uniform(2.4, 3.0)
    half = (w + over) / 2 + 0.55
    for s in (1, -1):
        # prisma inclinado: caixa fina girada
        length = math.sqrt(half * half + roof_h * roof_h)
        ang = math.atan2(roof_h, half)
        cx = s * half / 2
        cy = roof_y + roof_h / 2
        parts.append(_box("Thatch", (cx, 0, cy), (length, d + over + 0.7, 0.34), thatch, rot=(0, -s * ang, 0)))
    # cumeeira
    parts.append(_box("Ridge", (0, 0, roof_y + roof_h), (0.3, d + over + 0.8, 0.3), thatch))

    # 5. Chaminé de pedra
    parts.append(_box("Chimney", (w * 0.28, 0, roof_y + roof_h * 0.55),
                      (0.5, 0.5, roof_h * 1.15), stone))

    # 6. Porta e janelas
    parts.append(_box("Door", (0, -(d / 2 + 0.06), 0.7 + 1.0), (1.0, 0.12, 2.0), wood))
    for sx in (-1, 1):
        parts.append(_box("Win1", (sx * w * 0.28, -(d / 2 + 0.06), 0.7 + 1.5), (0.7, 0.1, 0.7), glass))
        parts.append(_box("Win2", (sx * (w / 2 + over / 2 + 0.04), 0, y0 + h2 * 0.55), (0.1, 0.7, 0.7), glass))

    obj = _join(parts, "House%d" % variant)
    _export("house" if variant == 0 else "house%d" % variant)


if __name__ == "__main__":
    make_house(1, 0)
    make_house(2, 1)
    make_house(3, 2)
    print("BUILDINGS_DONE")
