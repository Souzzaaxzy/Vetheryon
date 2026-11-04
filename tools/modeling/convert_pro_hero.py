"""Converte o personagem profissional (ClothedMan.blend) para GLB com:
  - todas as 9 animações (via trilhas NLA)
  - textura embutida (atlas 32x32, estilo low-poly)
  - escala ~1,85 m

Uso: blender --background --python tools/modeling/convert_pro_hero.py
"""

import os

import bpy

BLEND = "/workspace/tools/assets/ClothedMan.blend"
TEX = "/workspace/tools/assets/ClothedLightSkin.png"
OUT = "/workspace/vetheryon/assets/character/hero_pro.glb"
TARGET_HEIGHT = 1.85


def clean(n):
    return n.split("|")[-1]


def fix_material():
    """O material original usa Diffuse BSDF + textura. O exportador glTF só
    entende Principled BSDF, então reconstruímos o material ligando a textura
    diretamente no Base Color."""
    img = None
    for i in bpy.data.images:
        if i.name != "Render Result":
            img = i
            break
    for m in list(bpy.data.materials):
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Roughness"].default_value = 0.85
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        if img is not None:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = img
            tex.interpolation = "Closest"  # atlas 32x32: sem borrar
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        print("MAT_FIXED", m.name, "img=", img.name if img else None)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)

    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")

    # Corrige a textura ausente: aponta para o arquivo local e empacota.
    for im in bpy.data.images:
        if im.name == "Render Result":
            continue
        im.filepath = TEX
        im.source = "FILE"
        try:
            im.reload()
        except Exception as exc:  # noqa: BLE001
            print("TEX_RELOAD_FAIL", im.name, exc)
        im.pack()
    print("IMAGES", [(i.name, i.size[0], i.size[1], i.packed_file is not None) for i in bpy.data.images])

    fix_material()

    # Escala para 1,85 m.
    bpy.context.view_layer.update()
    h = mesh.dimensions.z or max(mesh.dimensions)
    s = TARGET_HEIGHT / h
    print("SCALE h=%.3f fator=%.4f" % (h, s))
    arm.scale = (arm.scale.x * s, arm.scale.y * s, arm.scale.z * s)
    bpy.context.view_layer.update()
    print("DIMS", tuple(round(x, 3) for x in mesh.dimensions))

    # Todas as ações para trilhas NLA.
    if not arm.animation_data:
        arm.animation_data_create()
    ad = arm.animation_data
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    ad.action = None
    for a in bpy.data.actions:
        if not a.fcurves:
            continue
        a.use_fake_user = True
        tr = ad.nla_tracks.new()
        tr.name = clean(a.name)
        tr.strips.new(clean(a.name), int(a.frame_range[0]), a)
    print("NLA tracks:", [t.name for t in ad.nla_tracks])

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", export_apply=False, export_yup=True,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_nla_strips=True, export_bake_animation=True,
        export_image_format="AUTO",
    )
    print("EXPORTED", OUT)


if __name__ == "__main__":
    main()
