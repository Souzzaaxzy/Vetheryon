"""Gera o personagem principal do Vetheryon com MPFB2 (malha humana realista).

Corpo humano real (basemesh MakeHuman, ~19k vértices) com:
  - pele parda (skin africana)
  - regata branca
  - calça preta
  - tênis branco

    blender --background --python tools/modeling/generate_hero_mpfb.py
"""

import os

import bpy

os.environ.setdefault("BLENDER_USER_EXTENSIONS", "/workspace/tools/blender-config/extensions")

USER_DATA = "/workspace/tools/mpfb-userdata"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "character", "hero.glb"))


def enable_mpfb():
    import addon_utils

    addon_utils.enable("bl_ext.user_default.mpfb", default_set=True, persistent=True)
    prefs = bpy.context.preferences.addons["bl_ext.user_default.mpfb"].preferences
    prefs.mpfb_user_data = USER_DATA


def find_asset(fragment, subdir="clothes"):
    from bl_ext.user_default.mpfb.services.assetservice import AssetService

    return AssetService.find_asset_absolute_path(fragment, subdir)


def recolor(obj, rgb):
    """Troca a cor base do material e remove QUALQUER textura de cor.

    Sem remover os nós de imagem, o exportador glTF ainda embute a textura e ela
    sobrescreve a cor base, deixando a peça com a cor original.
    """
    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:
            continue
        bsdf = None
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                bsdf = node
                break
        if not bsdf:
            continue
        inp = bsdf.inputs["Base Color"]
        for link in list(inp.links):
            mat.node_tree.links.remove(link)
        inp.default_value = (*rgb, 1.0)
        # remove nós de textura de cor para não serem exportados
        for node in list(mat.node_tree.nodes):
            if node.type in ("TEX_IMAGE", "TEX_ENVIRONMENT"):
                mat.node_tree.nodes.remove(node)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    enable_mpfb()

    from bl_ext.user_default.mpfb.services.humanservice import HumanService

    # 1. Corpo humano realista, com os pés no chão.
    human = HumanService.create_human(feet_on_ground=True)
    print("HUMAN", human.name, len(human.data.vertices), "verts")

    # 2. Pele parda (skin africana do asset pack).
    skin = find_asset("middleage_african_male.mhmat", "skins")
    print("SKIN", skin)
    HumanService.set_character_skin(skin, human, skin_type="ENHANCED_SSS", material_instances=True)

    # 3. Olhos.
    eyes = find_asset("high-poly.mhclo", "eyes") or find_asset("low-poly.mhclo", "eyes")
    print("EYES", eyes)
    if eyes:
        HumanService.add_mhclo_asset(eyes, human, asset_type="Eyes", material_type="MAKESKIN",
                                     set_up_rigging=False, interpolate_weights=False,
                                     import_subrig=False, import_weights=False)

    # 4. Roupas: regata + calça + tênis.
    def wear(fragment, label):
        path = find_asset(fragment)
        print("CLOTHES", label, path)
        if not path:
            return None
        return HumanService.add_mhclo_asset(
            path, human, asset_type="Clothes", subdiv_levels=1,
            material_type="MAKESKIN", set_up_rigging=False,
            interpolate_weights=False, import_subrig=False, import_weights=False)

    shirt = wear("toigo_keyhole_tank_top.mhclo", "regata")
    pants = wear("toigo_wool_pants.mhclo", "calca")
    shoes = wear("toigo_flats.mhclo", "tenis")

    # 5. Recolore conforme o pedido.
    if shirt:
        recolor(shirt, (0.93, 0.93, 0.91))
    if pants:
        recolor(pants, (0.05, 0.05, 0.06))
    if shoes:
        recolor(shoes, (0.95, 0.95, 0.96))

    # 6. Exporta GLB.
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", export_apply=True, export_yup=True,
    )
    print("EXPORTED", OUT)
    print("DONE")


if __name__ == "__main__":
    main()
