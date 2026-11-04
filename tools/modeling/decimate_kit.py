"""Decima os modelos do kit para caber num celular de entrada (Galaxy A14).

Os prédios vinham com 5k-42k triângulos cada. Com 20 casas + muralha, isso passa
de 300k triângulos. Decimar para ~25% mantém a silhueta e corta o custo.

Uso: blender --background --python tools/modeling/decimate_kit.py
"""

import glob
import os

import bpy

KIT = "/workspace/vetheryon/assets/kit"
TARGET_RATIO = 0.25
MIN_TRIS = 1200  # não decimar abaixo disso (peças pequenas)


def tri_count(obj):
    m = obj.data
    return sum(len(p.vertices) - 2 for p in m.polygons)


def main():
    for f in sorted(glob.glob(os.path.join(KIT, "*.glb"))):
        name = os.path.basename(f)
        if "human" in name.lower():
            continue  # não mexer no personagem
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=f)
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        if not meshes:
            continue
        before = sum(tri_count(o) for o in meshes)
        if before < MIN_TRIS:
            print("SKIP", name, before)
            continue
        for o in meshes:
            if tri_count(o) < MIN_TRIS:
                continue
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            mod = o.modifiers.new("Decimate", "DECIMATE")
            mod.ratio = TARGET_RATIO
            bpy.ops.object.modifier_apply(modifier="Decimate")
        after = sum(tri_count(o) for o in meshes)
        bpy.ops.export_scene.gltf(filepath=f, export_format="GLB", export_apply=True, export_yup=True)
        print("DECIMATED", name, before, "->", after)


if __name__ == "__main__":
    main()
