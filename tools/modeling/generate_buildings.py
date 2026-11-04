"""Gera os edifícios medievais do Vetheryon.

Referências: vilarejos medievais europeus têm casas de enxaimel (base de pedra,
vigas de madeira, reboco), telhado de duas águas BEM inclinado (palha), chaminé;
uma igreja com torre e campanário; bancas de mercado com toldo; poço; e ruas de
terra batida. Tudo procedural, com a geometria correta do telhado (formato "^").

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
STONE = (0.46, 0.44, 0.41)
PLASTER_A = (0.87, 0.83, 0.73)
PLASTER_B = (0.80, 0.74, 0.62)
PLASTER_C = (0.84, 0.78, 0.66)
TIMBER = (0.27, 0.17, 0.10)
THATCH_A = (0.52, 0.42, 0.24)
THATCH_B = (0.46, 0.36, 0.21)
TILE = (0.40, 0.22, 0.18)
WOOD = (0.32, 0.21, 0.12)
GLASS = (0.45, 0.58, 0.68)
GOLD = (0.72, 0.60, 0.24)
DIRT = (0.42, 0.34, 0.25)


def _reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _mat(name, color, roughness=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = roughness
    return m


def _box(loc, size, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.scale = size
    o.rotation_euler = rot
    o.data.materials.append(material)
    return o


def _prism(loc, width, depth, height, material):
    """Prisma triangular (telhado de duas águas) com ápice para CIMA (^)."""
    w2 = width / 2.0
    d2 = depth / 2.0
    verts = [
        (-w2, -d2, 0), (w2, -d2, 0), (0, -d2, height),
        (-w2, d2, 0), (w2, d2, 0), (0, d2, height),
    ]
    faces = [
        (0, 2, 1), (3, 4, 5),          # frontais/traseiras
        (0, 1, 4, 3),                   # base
        (0, 3, 5, 2),                   # água esquerda
        (1, 2, 5, 4),                   # água direita
    ]
    mesh = bpy.data.meshes.new("Roof")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new("Roof", mesh)
    bpy.context.collection.objects.link(o)
    o.location = loc
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


# ----------------------------------------------------------------------------

def make_house(seed, variant=0):
    """Casa de enxaimel: base de pedra, andar térreo, andar superior saliente
    (jetty), telhado de palha inclinado (^), chaminé, porta e janelas."""
    _reset()
    random.seed(seed)
    stone = _mat("Stone", STONE, 0.95)
    plaster = _mat("Plaster", [PLASTER_A, PLASTER_B, PLASTER_C][variant % 3], 0.9)
    timber = _mat("Timber", TIMBER, 0.85)
    thatch = _mat("Thatch", THATCH_A if variant % 2 == 0 else THATCH_B, 0.95)
    wood = _mat("Wood", WOOD, 0.8)
    glass = _mat("Glass", GLASS, 0.2)

    w = random.uniform(4.6, 5.6)
    d = random.uniform(3.8, 4.6)
    h1, h2 = 2.5, 2.0
    over = 0.30
    parts = []

    parts.append(_box((0, 0, 0.35), (w + 0.15, d + 0.15, 0.7), stone))
    parts.append(_box((0, 0, 0.7 + h1 / 2), (w, d, h1), plaster))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box((sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.7 + h1 / 2), (0.16, 0.16, h1), timber))
    for sx in (-1, 1):
        parts.append(_box((sx * w / 4, d / 2 - 0.02, 0.7 + h1 / 2), (0.14, 0.12, h1), timber))
    parts.append(_box((0, 0, 0.7 + h1 - 0.1), (w + 0.06, d + 0.06, 0.18), timber))

    y0 = 0.7 + h1
    parts.append(_box((0, 0, y0 + h2 / 2), (w + over, d + over, h2), plaster))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box((sx * ((w + over) / 2 - 0.06), sy * ((d + over) / 2 - 0.06), y0 + h2 / 2), (0.16, 0.16, h2), timber))
    for sx in (-1, 1):
        parts.append(_box((sx * w / 4, (d + over) / 2 - 0.02, y0 + h2 * 0.45), (0.11, 0.10, h2 * 0.85), timber, rot=(0, sx * 0.42, 0)))

    # Telhado correto (^) com beirais.
    roof_y = y0 + h2
    roof_h = random.uniform(2.6, 3.2)
    parts.append(_prism((0, 0, roof_y), w + over + 1.0, d + over + 0.8, roof_h, thatch))

    parts.append(_box((w * 0.28, 0, roof_y + roof_h * 0.5), (0.5, 0.5, roof_h * 1.1), stone))
    parts.append(_box((0, -(d / 2 + 0.06), 0.7 + 1.0), (1.0, 0.12, 2.0), wood))
    for sx in (-1, 1):
        parts.append(_box((sx * w * 0.28, -(d / 2 + 0.06), 0.7 + 1.5), (0.7, 0.1, 0.7), glass))
        parts.append(_box((sx * (w / 2 + over / 2 + 0.04), 0, y0 + h2 * 0.55), (0.1, 0.7, 0.7), glass))

    obj = _join(parts, "House%d" % variant)
    _export("house" if variant == 0 else "house%d" % variant)


def make_church(seed=90):
    """Igreja: nave comprida, telhado alto, torre com campanário e cruz."""
    _reset()
    random.seed(seed)
    stone = _mat("Stone", STONE, 0.95)
    stone2 = _mat("StoneLight", (0.60, 0.58, 0.54), 0.9)
    roof = _mat("Roof", TILE, 0.85)
    wood = _mat("Wood", WOOD, 0.8)
    glass = _mat("StainedGlass", (0.55, 0.35, 0.55), 0.2)
    gold = _mat("Gold", GOLD, 0.35, )

    parts = []
    # Nave
    nw, nd, nh = 6.0, 16.0, 5.5
    parts.append(_box((0, 0, nh / 2), (nw, nd, nh), stone))
    parts.append(_prism((0, 0, nh), nw + 0.6, nd + 0.6, 3.2, roof))
    # Contrafortes laterais
    for sy in range(-3, 4):
        for sx in (-1, 1):
            parts.append(_box((sx * (nw / 2 + 0.25), sy * 2.2, 1.6), (0.5, 0.7, 3.2), stone2))
    # Janelas altas (vitral)
    for sy in range(-3, 4):
        for sx in (-1, 1):
            parts.append(_box((sx * (nw / 2 + 0.02), sy * 2.2, 3.2), (0.1, 0.7, 1.8), glass))
    # Portal
    parts.append(_box((0, -(nd / 2 + 0.06), 1.5), (1.8, 0.2, 3.0), wood))
    # Torre (na frente)
    tw = 4.0
    parts.append(_box((0, -(nd / 2 + tw / 2), 9.0), (tw, tw, 18.0), stone))
    # Campanário (aberturas)
    for sx in (-1, 1):
        parts.append(_box((sx * (tw / 2 + 0.02), -(nd / 2 + tw / 2), 15.0), (0.1, 1.4, 2.4), glass))
    parts.append(_box((0, -(nd / 2 + tw / 2) - (tw / 2 + 0.02), 15.0), (1.4, 0.1, 2.4), glass))
    # Pináculo da torre
    parts.append(_prism((0, -(nd / 2 + tw / 2), 18.0), tw + 0.4, tw + 0.4, 3.0, roof))
    # Cruz
    parts.append(_box((0, -(nd / 2 + tw / 2), 21.6), (0.16, 0.16, 1.4), gold))
    parts.append(_box((0, -(nd / 2 + tw / 2), 21.9), (0.8, 0.16, 0.16), gold))

    obj = _join(parts, "Church")
    _export("church")


def make_market(seed=80, variant=0):
    """Banca de mercado: balcão de madeira + toldo listrado + postes."""
    _reset()
    random.seed(seed)
    wood = _mat("Wood", WOOD, 0.8)
    wood2 = _mat("Wood2", (0.40, 0.27, 0.15), 0.8)
    cloth_a = _mat("ClothA", (0.72, 0.24, 0.22), 0.9)
    cloth_b = _mat("ClothB", (0.86, 0.82, 0.70), 0.9)
    goods = _mat("Goods", (0.55, 0.42, 0.20), 0.8)

    w, d = 3.4, 2.0
    parts = []
    # Balcão
    parts.append(_box((0, 0, 0.95), (w, d, 0.9), wood))
    parts.append(_box((0, 0, 1.42), (w + 0.2, d + 0.2, 0.08), wood2))
    # Postes
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box((sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 1.6), (0.12, 0.12, 3.2), wood))
    # Toldo (duas águas, baixo)
    parts.append(_prism((0, 0, 3.0), w + 0.6, d + 0.9, 0.7, cloth_a if variant % 2 == 0 else cloth_b))
    # Mercadorias no balcão
    for i in range(5):
        parts.append(_box((-w / 2 + 0.5 + i * 0.6, 0, 1.55), (0.35, 0.5, 0.25), goods))

    obj = _join(parts, "Market")
    _export("market" if variant == 0 else "market%d" % variant)


def make_well(seed=70):
    """Poço de pedra com telhadinho e balde."""
    _reset()
    random.seed(seed)
    stone = _mat("Stone", STONE, 0.95)
    wood = _mat("Wood", WOOD, 0.8)
    roof = _mat("Roof", THATCH_A, 0.95)
    parts = []
    parts.append(_box((0, 0, 0.5), (1.6, 1.6, 1.0), stone))
    for sx in (-1, 1):
        parts.append(_box((sx * 0.65, 0, 1.6), (0.16, 0.16, 2.2), wood))
    parts.append(_prism((0, 0, 2.6), 2.2, 2.2, 0.9, roof))
    parts.append(_box((0, 0, 1.9), (0.4, 0.4, 0.5), wood))
    obj = _join(parts, "Well")
    _export("well")


if __name__ == "__main__":
    make_house(1, 0)
    make_house(2, 1)
    make_house(3, 2)
    make_church()
    make_market(80, 0)
    make_market(81, 1)
    make_well()
    print("BUILDINGS_DONE")
