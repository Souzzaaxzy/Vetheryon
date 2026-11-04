"""Decima a natureza (arvores/arbustos) para 50% para aliviar o celular."""

import glob
import os

import bpy

SRC = "/workspace/vetheryon/assets/nature"


def main():
    for f in sorted(glob.glob(os.path.join(SRC, "*.glb"))):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=f)
        for o in [x for x in bpy.data.objects if x.type == "MESH"]:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            m = o.modifiers.new("D", "DECIMATE")
            m.ratio = 0.5
            bpy.ops.object.modifier_apply(modifier="D")
        bpy.ops.export_scene.gltf(filepath=f, export_format="GLB", export_apply=True, export_yup=True)
        print("DEC", os.path.basename(f))


if __name__ == "__main__":
    main()
