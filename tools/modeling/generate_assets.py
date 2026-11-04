"""Gera assets 3D procedurais para o Vetheryon e exporta como .glb.

Roda no Blender headless:
    blender --background --python tools/modeling/generate_assets.py

Cada asset é geometria real (malhas com materiais PBR), pronta para importar no
Godot. Serve como base programável; modelos detalhados podem substituir estes
depois sem mudar a estrutura do jogo.
"""

import math
import os
import random

import bpy
import bmesh
from mathutils import Vector

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models")


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _material(name, color, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def _export(name: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.normpath(os.path.join(OUT_DIR, name + ".glb"))
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    print("EXPORTED", path)


def _shade_smooth(obj) -> None:
    for poly in obj.data.polygons:
        poly.use_smooth = True


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bpy.context.object.name = name


def make_tree(seed: int = 1) -> None:
    _reset_scene()
    random.seed(seed)

    bark = _material("Bark", (0.24, 0.15, 0.09, 1.0), 0.9)
    leaves = _material("Leaves", (0.16, 0.36, 0.14, 1.0), 0.85)

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.22, depth=3.2, location=(0, 0, 1.6))
    trunk = bpy.context.object
    trunk.name = "Trunk"
    trunk.data.materials.append(bark)
    bm = bmesh.new()
    bm.from_mesh(trunk.data)
    for v in bm.verts:
        t = (v.co.z + 1.6) / 3.2
        scale = 1.0 - 0.55 * t
        v.co.x *= scale
        v.co.y *= scale
    bm.to_mesh(trunk.data)
    bm.free()

    parts = [trunk]
    for dx, dy, dz, r in [
        (0.0, 0.0, 3.4, 1.35),
        (0.8, 0.3, 3.0, 0.95),
        (-0.7, -0.4, 3.1, 0.9),
        (0.1, 0.8, 3.6, 0.85),
        (-0.2, -0.9, 3.5, 0.8),
    ]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(dx, dy, dz))
        part = bpy.context.object
        for v in part.data.vertices:
            v.co += Vector((random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08)))
        part.data.materials.append(leaves)
        _shade_smooth(part)
        parts.append(part)

    _join(parts, "Tree")
    _export("tree")


def make_rock(seed: int = 2) -> None:
    _reset_scene()
    random.seed(seed)

    stone = _material("Stone", (0.34, 0.33, 0.32, 1.0), 0.95)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0.55))
    rock = bpy.context.object
    rock.name = "Rock"
    rock.data.materials.append(stone)
    for v in rock.data.vertices:
        v.co.x *= random.uniform(0.85, 1.25)
        v.co.y *= random.uniform(0.85, 1.25)
        v.co.z *= random.uniform(0.55, 0.9)
        v.co += Vector((random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), random.uniform(-0.06, 0.06)))
    for v in rock.data.vertices:
        if v.co.z < 0.05:
            v.co.z = 0.02
    bpy.ops.object.modifier_add(type="DECIMATE")
    rock.modifiers["Decimate"].ratio = 0.5
    bpy.ops.object.modifier_apply(modifier="Decimate")
    _export("rock")


def make_crystal(seed: int = 3) -> None:
    _reset_scene()
    random.seed(seed)

    crystal = _material("Crystal", (0.45, 0.72, 0.95, 1.0), 0.15, metallic=0.1)
    bsdf = crystal.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Emission Color"].default_value = (0.3, 0.7, 1.0, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.6

    shards = []
    for dx, dy, h, r in [
        (0.0, 0.0, 1.4, 0.28),
        (0.35, 0.2, 0.9, 0.2),
        (-0.3, 0.3, 1.0, 0.18),
        (0.1, -0.35, 0.8, 0.16),
    ]:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r, radius2=0.02, depth=h, location=(dx, dy, h * 0.5))
        shard = bpy.context.object
        shard.rotation_euler = (random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), random.uniform(0, math.tau))
        shard.data.materials.append(crystal)
        _shade_smooth(shard)
        shards.append(shard)

    _join(shards, "Crystal")
    _export("crystal")


def make_wall(seed: int = 4) -> None:
    _reset_scene()
    random.seed(seed)

    stone = _material("WallStone", (0.42, 0.40, 0.37, 1.0), 0.95)
    bricks = []
    for r in range(4):
        offset = 0.35 if r % 2 else 0.0
        for c in range(5):
            x = c * 0.75 + offset
            z = 0.3 + r * 0.6
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, random.uniform(-0.03, 0.03), z))
            b = bpy.context.object
            b.scale = (0.34, 0.28, 0.28)
            b.rotation_euler = (0, 0, random.uniform(-0.03, 0.03))
            b.data.materials.append(stone)
            bricks.append(b)

    _join(bricks, "Wall")
    _export("wall")


if __name__ == "__main__":
    make_tree()
    make_rock()
    make_crystal()
    make_wall()
    print("ALL_ASSETS_DONE")
