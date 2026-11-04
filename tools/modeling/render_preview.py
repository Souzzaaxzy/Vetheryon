"""Renderiza um preview dos assets gerados (para inspeção visual).

    blender --background --python tools/modeling/render_preview.py
"""

import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "preview_models.png"))


def _clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import_glb(path, x):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        o.location.x += x
    return new


def main():
    _clear()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [
        e.bl_rna.identifier for e in bpy.types.RenderEngine.__subclasses__()
    ] else "CYCLES"
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "CYCLES"

    scene.render.resolution_x = 1280
    scene.render.resolution_y = 480
    scene.render.film_transparent = False

    _import_glb(os.path.join(MODELS, "tree.glb"), -3.2)
    _import_glb(os.path.join(MODELS, "rock.glb"), -0.8)
    _import_glb(os.path.join(MODELS, "crystal.glb"), 1.2)
    _import_glb(os.path.join(MODELS, "wall.glb"), 3.6)

    # Ground
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.object
    mat = bpy.data.materials.new("Ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.3, 0.42, 0.24, 1)
    ground.data.materials.append(mat)

    # Lights
    bpy.ops.object.light_add(type="SUN", location=(5, -5, 10))
    bpy.context.object.data.energy = 4.0
    bpy.ops.object.light_add(type="AREA", location=(-6, -6, 6))
    bpy.context.object.data.energy = 400.0

    # Camera
    bpy.ops.object.camera_add(location=(0.5, -13, 6))
    cam = bpy.context.object
    direction = Vector((0, 0, 1.6)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.68, 0.85, 1)

    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", OUT)


if __name__ == "__main__":
    main()
