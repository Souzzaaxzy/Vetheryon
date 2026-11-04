"""Renderiza vistas do personagem (frente/lado/costas) para inspeção visual.

    blender --background --python tools/modeling/render_character.py
"""

import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GLB = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "character", "hero.glb"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "character", "preview"))


def _clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _setup_scene():
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "CYCLES"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 768
    scene.render.film_transparent = True

    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.52, 0.56, 0.62, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world

    bpy.ops.object.light_add(type="SUN", location=(3, -4, 6))
    bpy.context.object.data.energy = 3.0
    bpy.ops.object.light_add(type="AREA", location=(-3, -3, 3))
    bpy.context.object.data.energy = 300.0
    bpy.ops.object.light_add(type="AREA", location=(0, 3, 2.5))
    bpy.context.object.data.energy = 180.0
    # Sem chão: isola o personagem para inspeção.


def _add_camera(target_z, angle_deg, dist=4.5, height=1.0):
    a = math.radians(angle_deg)
    cam_loc = Vector((math.sin(a) * dist, -math.cos(a) * dist, height))
    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.object
    direction = Vector((0, 0, target_z)) - cam_loc
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    return cam


import math  # noqa: E402


def main():
    _clear()
    _setup_scene()
    bpy.ops.import_scene.gltf(filepath=GLB)
    os.makedirs(OUT, exist_ok=True)

    for label, ang in [("front", 0), ("side", 90), ("back", 180), ("threequarter", 35)]:
        cam = _add_camera(0.88, ang)
        bpy.context.scene.camera = cam
        bpy.context.scene.render.filepath = os.path.join(OUT, label + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", label)
        bpy.data.objects.remove(cam, do_unlink=True)

    print("CHAR_PREVIEW_DONE")


if __name__ == "__main__":
    main()
