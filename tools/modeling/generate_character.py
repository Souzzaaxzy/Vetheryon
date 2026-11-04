"""Gera o personagem principal do Vetheryon no Blender e exporta como .glb.

Características: careca, rosto padrão, pele parda, regata branca, calça preta,
tênis branco. Corpo em A-pose (braços levemente afastados), pronto para rigging.

    blender --background --python tools/modeling/generate_character.py
"""

import math
import os

import bpy
from mathutils import Vector

OUT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "character", "hero.glb")
)


# ----------------------------------------------------------------------------
# utilidades
# ----------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, roughness=0.6, metallic=0.0, subsurface=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    if subsurface > 0:
        b.inputs["Subsurface Weight"].default_value = subsurface
        b.inputs["Subsurface Radius"].default_value = (0.15, 0.06, 0.04)
        b.inputs["Subsurface Scale"].default_value = 0.05
    return m


def smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def sphere(name, loc, r, scale=(1, 1, 1), material=None, segs=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    if material:
        o.data.materials.append(material)
    return smooth(o)


def limb(name, p1, p2, r1, r2, material=None, verts=24):
    """Cone truncado alinhado de p1 a p2."""
    p1, p2 = Vector(p1), Vector(p2)
    vec = p2 - p1
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r1, radius2=r2, depth=vec.length, location=(0, 0, 0)
    )
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(vec)
    o.location = (p1 + p2) * 0.5
    if material:
        o.data.materials.append(material)
    return smooth(o)


def rounded_box(name, loc, size, material=None, bevel=0.015, subsurf=1):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    if material:
        o.data.materials.append(material)
    if bevel > 0:
        bpy.ops.object.modifier_add(type="BEVEL")
        o.modifiers["Bevel"].width = bevel
        o.modifiers["Bevel"].segments = 3
        bpy.ops.object.modifier_apply(modifier="Bevel")
    if subsurf > 0:
        bpy.ops.object.modifier_add(type="SUBSURF")
        o.modifiers["Subdivision"].levels = subsurf
        o.modifiers["Subdivision"].render_levels = subsurf
        bpy.ops.object.modifier_apply(modifier="Subdivision")
    return smooth(o)


# ----------------------------------------------------------------------------
# personagem
# ----------------------------------------------------------------------------

def build_character():
    reset()

    SKIN = mat("Skin", (0.46, 0.30, 0.20), roughness=0.5, subsurface=0.25)   # pele parda
    SHIRT = mat("Shirt", (0.94, 0.94, 0.92), roughness=0.75)                # regata branca
    PANTS = mat("Pants", (0.06, 0.06, 0.07), roughness=0.8)                 # calça preta
    SHOE = mat("Shoe", (0.95, 0.95, 0.96), roughness=0.45)                  # tênis branco
    SOLE = mat("Sole", (0.82, 0.82, 0.84), roughness=0.7)
    EYE_W = mat("EyeWhite", (0.90, 0.90, 0.88), roughness=0.2)
    EYE_I = mat("Iris", (0.17, 0.11, 0.07), roughness=0.15)
    DARK = mat("Dark", (0.09, 0.06, 0.05), roughness=0.5)

    parts = []

    # --- tronco: regata cobre torso, mas os OMBROS ficam de fora ------------
    parts.append(sphere("Chest", (0, 0, 1.27), 0.215, (1.0, 0.60, 1.02), SHIRT))
    parts.append(sphere("PecL", (0.095, -0.10, 1.30), 0.085, (1.0, 0.7, 0.7), SHIRT))
    parts.append(sphere("PecR", (-0.095, -0.10, 1.30), 0.085, (1.0, 0.7, 0.7), SHIRT))
    parts.append(sphere("Belly", (0, 0, 1.05), 0.185, (1.0, 0.66, 1.05), SHIRT))
    parts.append(limb("TorsoLow", (0, 0, 0.98), (0, 0, 1.30), 0.17, 0.21, SHIRT))
    # alças da regata sobre os ombros
    for s in (1, -1):
        parts.append(limb("Strap", (s * 0.075, -0.02, 1.42), (s * 0.17, 0.0, 1.36), 0.030, 0.030, SHIRT))

    # --- pescoço e cabeça (pele) --------------------------------------------
    parts.append(limb("Neck", (0, 0.01, 1.42), (0, 0.005, 1.55), 0.062, 0.055, SKIN))
    parts.append(sphere("Head", (0, 0, 1.665), 0.118, (0.94, 1.0, 1.16), SKIN))
    parts.append(sphere("Jaw", (0, -0.01, 1.60), 0.086, (0.95, 0.98, 0.9), SKIN))
    parts.append(sphere("EarL", (0.112, 0.0, 1.665), 0.032, (0.5, 0.9, 1.2), SKIN))
    parts.append(sphere("EarR", (-0.112, 0.0, 1.665), 0.032, (0.5, 0.9, 1.2), SKIN))

    # rosto (voltado para -Y)
    for sx in (0.043, -0.043):
        parts.append(sphere("EyeWhite", (sx, -0.098, 1.687), 0.019, (1.0, 0.75, 1.0), EYE_W, 24, 16))
        parts.append(sphere("Iris", (sx, -0.112, 1.687), 0.010, (1.0, 0.7, 1.0), EYE_I, 16, 12))
        parts.append(rounded_box("Brow", (sx, -0.108, 1.712), (0.032, 0.012, 0.007), DARK, bevel=0.004, subsurf=0))
    parts.append(limb("Nose", (0, -0.095, 1.672), (0, -0.126, 1.658), 0.016, 0.010, SKIN, 16))
    parts.append(sphere("Mouth", (0, -0.100, 1.628), 0.020, (1.5, 0.5, 0.5), DARK, 20, 12))

    # --- braços (pele, ombros à mostra) -------------------------------------
    for s in (1, -1):
        parts.append(sphere("Deltoid", (s * 0.185, 0, 1.385), 0.082, (1.0, 1.0, 1.05), SKIN))
        parts.append(limb("UpperArm", (s * 0.185, 0, 1.38), (s * 0.245, 0, 1.10), 0.072, 0.052, SKIN))
        parts.append(sphere("Bicep", (s * 0.205, -0.03, 1.28), 0.058, (0.9, 1.0, 1.3), SKIN))
        parts.append(sphere("Elbow", (s * 0.245, 0, 1.10), 0.052, (1, 1, 1), SKIN))
        parts.append(limb("Forearm", (s * 0.245, 0, 1.10), (s * 0.275, 0, 0.845), 0.052, 0.040, SKIN))
        parts.append(sphere("Hand", (s * 0.285, -0.01, 0.79), 0.052, (0.8, 1.0, 1.25), SKIN))

    # --- quadril e pernas (calça preta) -------------------------------------
    parts.append(sphere("Pelvis", (0, 0, 0.94), 0.185, (1.0, 0.78, 0.72), PANTS))
    for s in (1, -1):
        parts.append(limb("Thigh", (s * 0.095, 0, 0.92), (s * 0.10, 0, 0.50), 0.118, 0.082, PANTS))
        parts.append(sphere("Knee", (s * 0.10, 0, 0.50), 0.082, (1, 1, 1), PANTS))
        parts.append(limb("Calf", (s * 0.10, 0, 0.50), (s * 0.10, 0.005, 0.135), 0.082, 0.055, PANTS))

    # --- tênis branco --------------------------------------------------------
    for s in (1, -1):
        parts.append(rounded_box("ShoeBody", (s * 0.10, -0.045, 0.075), (0.20, 0.46, 0.12), SHOE, bevel=0.03, subsurf=1))
        parts.append(rounded_box("ShoeSole", (s * 0.10, -0.045, 0.022), (0.215, 0.49, 0.045), SOLE, bevel=0.012, subsurf=1))
        parts.append(sphere("Ankle", (s * 0.10, 0.01, 0.16), 0.062, (0.95, 1.0, 1.0), PANTS))

    # junta tudo
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    hero = bpy.context.object
    hero.name = "VetheryonHero"

    # Origem nos pés, centrada em X/Y (necessário para o posicionamento no terreno).
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    xs = [v.co.x for v in hero.data.vertices]
    ys = [v.co.y for v in hero.data.vertices]
    zs = [v.co.z for v in hero.data.vertices]
    cx = (min(xs) + max(xs)) * 0.5
    cy = (min(ys) + max(ys)) * 0.5
    minz = min(zs)
    for v in hero.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= minz
    hero.location = (0, 0, 0)
    hero.data.update()

    return hero


def export(hero):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=False,
    )
    print("EXPORTED", OUT)


if __name__ == "__main__":
    hero = build_character()
    export(hero)
    print("CHARACTER_DONE")
