"""Gera modelos 3D simples (mas sólidos) para o Vetheryon: casas da vila.

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


def _reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _mat(name, color, roughness=0.8, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    return m


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


def make_house(seed=10, variant=0):
    """Casa simples: paredes, telhado de duas águas, porta e janelas."""
    _reset()
    random.seed(seed)
    wall_col = [(0.82, 0.78, 0.70), (0.74, 0.68, 0.58), (0.80, 0.74, 0.64)][variant % 3]
    wall = _mat("Wall", wall_col, 0.9)
    roof = _mat("Roof", (0.42, 0.24, 0.20), 0.85)
    wood = _mat("Wood", (0.34, 0.22, 0.13), 0.85)
    glass = _mat("Glass", (0.55, 0.68, 0.78), 0.25)

    w, d, h = 5.0, 4.2, 3.0
    parts = []

    # paredes (caixa)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, h / 2))
    body = bpy.context.object
    body.scale = (w, d, h)
    body.data.materials.append(wall)
    parts.append(body)

    # telhado de duas águas (dois prismas inclinados)
    for s in (1, -1):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(s * w * 0.26, 0, h + 0.9))
        r = bpy.context.object
        r.scale = (w * 0.62, d * 1.08, 0.24)
        r.rotation_euler = (0, s * math.radians(38), 0)
        r.data.materials.append(roof)
        parts.append(r)

    # porta
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -d / 2 - 0.02, 1.1))
    door = bpy.context.object
    door.scale = (1.1, 0.12, 2.2)
    door.data.materials.append(wood)
    parts.append(door)

    # janelas
    for sx in (-1.6, 1.6):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, -d / 2 - 0.02, 1.9))
        win = bpy.context.object
        win.scale = (0.9, 0.1, 0.9)
        win.data.materials.append(glass)
        parts.append(win)

    obj = _join(parts, "House")
    _export("house" if variant == 0 else f"house{variant}")


if __name__ == "__main__":
    make_house(10, 0)
    make_house(11, 1)
    make_house(12, 2)
    print("BUILDINGS_DONE")
