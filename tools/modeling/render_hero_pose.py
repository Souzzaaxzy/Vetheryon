"""Renderiza o hero animado (pose de caminhada) para conferir que ha um unico
personagem masculino, com as roupas deformando junto."""

import os

import bpy
from mathutils import Vector

GLB = "/workspace/vetheryon/assets/character/hero.glb"
OUT = "/workspace/vetheryon/assets/character/preview"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        sc.render.engine = "CYCLES"
    sc.render.resolution_x = 512
    sc.render.resolution_y = 768
    sc.render.film_transparent = True

    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.66, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    bpy.context.object.data.energy = 3.5
    bpy.ops.object.light_add(type="AREA", location=(-3, -3, 3))
    bpy.context.object.data.energy = 300.0

    bpy.ops.import_scene.gltf(filepath=GLB)

    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if arm:
        walk = bpy.data.actions.get("Walk_Human.rig") or bpy.data.actions.get("Walk")
        if walk:
            if not arm.animation_data:
                arm.animation_data_create()
            arm.animation_data.action = walk
            bpy.context.scene.frame_set(9)  # meio de um passo
            print("POSE Walk frame 9")

    os.makedirs(OUT, exist_ok=True)
    for label, ang in [("walk_front", 0), ("walk_side", 90)]:
        a = ang * 3.14159 / 180
        loc = Vector((__import__("math").sin(a) * 4.5, -__import__("math").cos(a) * 4.5, 1.0))
        bpy.ops.object.camera_add(location=loc)
        cam = bpy.context.object
        d = Vector((0, 0, 0.9)) - loc
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 50
        sc.camera = cam
        sc.render.filepath = os.path.join(OUT, label + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", label)
        bpy.data.objects.remove(cam, do_unlink=True)


if __name__ == "__main__":
    main()
