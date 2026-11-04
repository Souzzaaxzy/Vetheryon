"""Diagnostico: importa o hero.glb e checa quais malhas estao rigadas."""

import os

import bpy

GLB = "/workspace/vetheryon/assets/character/hero.glb"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            mods = [m.type for m in obj.modifiers]
            arm = [m.object.name for m in obj.modifiers if m.type == "ARMATURE" and m.object]
            parent = obj.parent.name if obj.parent else None
            print(f"MESH {obj.name!r} verts={len(obj.data.vertices)} mods={mods} armature={arm} parent={parent}")
        elif obj.type == "ARMATURE":
            print(f"ARMATURE {obj.name!r} bones={len(obj.data.bones)}")
    for act in bpy.data.actions:
        print(f"ACTION {act.name!r} frames={act.frame_range}")


if __name__ == "__main__":
    main()
