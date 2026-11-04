"""Gera tiles de estrada para o Vetheryon: estrada de TERRA e caminho de PEDRA.

Não há modelos de estrada nos kits CC0 usados, então criamos tiles modulares
(retos, curva, cruzamento, fim) que se encaixam numa grade de 2 m.

    blender --background --python tools/modeling/generate_roads.py
"""

import math
import os
import random

import bpy

OUT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "roads")
)

TILE = 2.0  # lado do tile em metros


def _reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _mat(name, color, roughness=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = roughness
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
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)
    print("EXPORTED", path)


def _strip(name, material, width, length, seed, pebbles=0):
    """Faixa reta (centro no eixo Z), levemente irregular, com pedrinhas opcionais."""
    random.seed(seed)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0.02))
    plane = bpy.context.object
    plane.scale = (width, length, 1.0)
    plane.data.materials.append(material)
    parts = [plane]
    for i in range(pebbles):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.04, 0.09),
                                              location=(random.uniform(-width / 2, width / 2),
                                                        random.uniform(-length / 2, length / 2), 0.04))
        p = bpy.context.object
        p.scale = (1.0, 1.0, 0.5)
        p.data.materials.append(material)
        parts.append(p)
    return _join(parts, name)


def make_dirt_tile(name, kind, seed):
    """kind: straight | curve | cross | end"""
    _reset()
    earth = _mat("Earth", (0.40, 0.32, 0.22), 1.0)
    w = TILE * 0.62
    parts = []
    if kind == "straight":
        parts.append(_strip("s", earth, w, TILE, seed, 6))
    elif kind == "end":
        parts.append(_strip("s", earth, w, TILE * 0.5, seed, 3))
    elif kind == "curve":
        # duas faixas em L
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, TILE * 0.25, 0.02))
        a = bpy.context.object
        a.scale = (w, TILE * 0.5, 1.0)
        a.data.materials.append(earth)
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(TILE * 0.25, 0, 0.02))
        b = bpy.context.object
        b.scale = (TILE * 0.5, w, 1.0)
        b.data.materials.append(earth)
        parts = [a, b]
    elif kind == "cross":
        parts.append(_strip("v", earth, w, TILE, seed, 4))
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0.021))
        h = bpy.context.object
        h.scale = (TILE, w, 1.0)
        h.data.materials.append(earth)
        parts.append(h)
    _export(name)


def make_stone_tile(name, kind, seed):
    """Caminho de pedrinhas: lajes pequenas formando o caminho."""
    _reset()
    stone = _mat("Cobble", (0.52, 0.50, 0.46), 0.95)
    random.seed(seed)
    parts = []
    if kind == "straight":
        n = 5
        for i in range(n):
            for j in (-1, 0, 1):
                bpy.ops.mesh.primitive_cube_add(
                    size=1.0,
                    location=(j * 0.42 + random.uniform(-0.03, 0.03),
                              -TILE / 2 + (i + 0.5) * (TILE / n),
                              0.03 + random.uniform(-0.01, 0.01)))
                c = bpy.context.object
                c.scale = (0.34, 0.30, 0.06)
                c.rotation_euler = (0, 0, random.uniform(-0.15, 0.15))
                c.data.materials.append(stone)
                parts.append(c)
    _export(name)


if __name__ == "__main__":
    make_dirt_tile("road_dirt_straight", "straight", 1)
    make_dirt_tile("road_dirt_curve", "curve", 2)
    make_dirt_tile("road_dirt_cross", "cross", 3)
    make_dirt_tile("road_dirt_end", "end", 4)
    make_stone_tile("road_stone_straight", "straight", 5)
    print("ROADS_DONE")
