"""Gera o personagem principal do Vetheryon: UM humano masculino, rigado e
animado (idle, walk, run, jump), com as roupas também rigadas ao mesmo esqueleto.

Corrige dois problemas da versão anterior:
  1. gênero: agora masculino (gender=1.0), antes era 0.5 (andrógeno/feminino);
  2. roupas rigadas: antes ficavam em A-pose (parecia "dois personagens").

    blender --background --python tools/modeling/generate_hero.py
"""

import math
import os

import bpy
from mathutils import Euler

os.environ.setdefault("BLENDER_USER_EXTENSIONS", "/workspace/tools/blender-config/extensions")

USER_DATA = "/workspace/tools/mpfb-userdata"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "character", "hero.glb"))


def enable_mpfb():
    import addon_utils

    addon_utils.enable("bl_ext.user_default.mpfb", default_set=True, persistent=True)
    bpy.context.preferences.addons["bl_ext.user_default.mpfb"].preferences.mpfb_user_data = USER_DATA


def find_asset(fragment, subdir="clothes"):
    from bl_ext.user_default.mpfb.services.assetservice import AssetService

    return AssetService.find_asset_absolute_path(fragment, subdir)


def hide_body_under_clothes(basemesh, clothes_list):
    """Remove do corpo os vértices que estão sob as roupas.

    Muitos modelos do MakeHuman (ex.: a regata) NÃO trazem "delete group", então
    o corpo nu é renderizado junto da roupa -> parece um personagem duplicado.
    Um MaskModifier resolveria no Blender, mas NÃO é exportado para glTF. Então
    aqui deletamos de fato os vértices do corpo que ficam dentro do volume de
    alguma peça de roupa (BVHTree), preservando os pesos de skinning.
    """
    import bmesh
    from mathutils.bvhtree import BVHTree

    # 1. Marca os vértices do corpo que estão dentro de alguma roupa.
    hidden: set[int] = set()
    for clothes in clothes_list:
        if clothes is None:
            continue
        bm = bmesh.new()
        bm.from_mesh(clothes.data)
        bmesh.ops.transform(bm, matrix=clothes.matrix_world, verts=bm.verts)
        bvh = BVHTree.FromBMesh(bm, epsilon=0.0)
        bm.free()

        for v in basemesh.data.vertices:
            world_co = basemesh.matrix_world @ v.co
            # Remove a pele que está na altura da roupa (dentro OU muito perto),
            # para que a peça de roupa apareça em vez do corpo.
            hit = bvh.find_nearest(world_co, 0.06)
            if hit and hit[0] is not None:
                hidden.add(v.index)

    if not hidden:
        print("HIDDEN_UNDER_CLOTHES 0 (nada a remover)")
        return

    # 2. Deleta esses vértices de verdade (bmesh preserva os vertex groups/pesos).
    bm = bmesh.new()
    bm.from_mesh(basemesh.data)
    bm.verts.ensure_lookup_table()
    to_delete = [bm.verts[i] for i in hidden if i < len(bm.verts)]
    bmesh.ops.delete(bm, geom=to_delete, context="VERTS")
    bm.to_mesh(basemesh.data)
    bm.free()
    basemesh.data.update()
    print("HIDDEN_UNDER_CLOTHES", len(hidden), "vertices removidos do corpo")


def force_opaque():
    """Força TODOS os materiais a serem opacos.

    O material do corpo vem com alpha=BLEND (herdado do MakeHuman). No Godot,
    material transparente é desenhado DEPOIS do opaco, então o corpo nu aparecia
    através da roupa -> parecia um "personagem duplicado". Forçando opaco, a
    roupa (opaca) esconde o corpo corretamente.
    """
    for mat in bpy.data.materials:
        try:
            if hasattr(mat, "surface_render_method"):
                mat.surface_render_method = "DITHERED"
            if hasattr(mat, "blend_method"):
                mat.blend_method = "OPAQUE"
        except Exception as exc:  # noqa: BLE001
            print("MAT_OPAQUE_FAIL", mat.name, exc)
    print("FORCED_OPAQUE", len(bpy.data.materials), "materiais")


def recolor(obj, rgb):
    """Troca a cor base e remove texturas de cor (senão a textura vence no export)."""
    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        inp = bsdf.inputs["Base Color"]
        for link in list(inp.links):
            mat.node_tree.links.remove(link)
        inp.default_value = (*rgb, 1.0)
        for node in list(mat.node_tree.nodes):
            if node.type in ("TEX_IMAGE", "TEX_ENVIRONMENT"):
                mat.node_tree.nodes.remove(node)


# ----------------------------------------------------------------------------
# animação procedural (keyframes nas rotações dos bones)
# ----------------------------------------------------------------------------

def _bone(rig, name):
    return rig.pose.bones.get("mixamorig:" + name)


def _key_rot(rig, bone_name, frame, rot_xyz):
    pb = _bone(rig, bone_name)
    if not pb:
        return
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = Euler(rot_xyz, "XYZ")
    pb.keyframe_insert("rotation_euler", frame=frame)


def _key_loc(rig, bone_name, frame, loc):
    pb = _bone(rig, bone_name)
    if not pb:
        return
    pb.location = loc
    pb.keyframe_insert("location", frame=frame)


def _new_action(rig, name):
    if not rig.animation_data:
        rig.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    return action


def _clear_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)


def make_idle(rig):
    _clear_pose(rig)
    _new_action(rig, "Idle")
    frames = [1, 24, 48, 72, 96]
    for i, f in enumerate(frames):
        t = i / (len(frames) - 1)
        breathe = math.sin(t * math.tau) * 0.03
        sway = math.sin(t * math.tau) * 0.02
        _key_rot(rig, "Spine", f, (0.02 + breathe, 0, sway))
        _key_rot(rig, "Spine1", f, (0.02 + breathe, 0, sway * 0.5))
        _key_rot(rig, "Head", f, (-0.02, sway * 0.6, 0))
        _key_rot(rig, "LeftArm", f, (0.0, 0, 0.08 + sway * 0.3))
        _key_rot(rig, "RightArm", f, (0.0, 0, -0.08 - sway * 0.3))
        _key_loc(rig, "Hips", f, (0, 0, breathe * 0.15))
    return "Idle", frames[-1]


def make_walk(rig):
    _clear_pose(rig)
    _new_action(rig, "Walk")
    n = 32
    for i in range(n + 1):
        f = 1 + i
        phase = (i / n) * math.tau
        swing = math.sin(phase)
        _key_rot(rig, "LeftUpLeg", f, (swing * 0.55, 0, 0))
        _key_rot(rig, "RightUpLeg", f, (-swing * 0.55, 0, 0))
        _key_rot(rig, "LeftLeg", f, (max(0, -swing) * 0.7, 0, 0))
        _key_rot(rig, "RightLeg", f, (max(0, swing) * 0.7, 0, 0))
        _key_rot(rig, "LeftFoot", f, (-swing * 0.25, 0, 0))
        _key_rot(rig, "RightFoot", f, (swing * 0.25, 0, 0))
        _key_rot(rig, "LeftArm", f, (-swing * 0.45, 0, 0.08))
        _key_rot(rig, "RightArm", f, (swing * 0.45, 0, -0.08))
        _key_rot(rig, "LeftForeArm", f, (0.25 + max(0, -swing) * 0.3, 0, 0))
        _key_rot(rig, "RightForeArm", f, (0.25 + max(0, swing) * 0.3, 0, 0))
        _key_rot(rig, "Spine", f, (0.04, 0, swing * 0.06))
        _key_rot(rig, "Hips", f, (0, 0, -swing * 0.08))
        _key_loc(rig, "Hips", f, (0, 0, abs(math.sin(phase)) * 0.03))
    return "Walk", n + 1


def make_run(rig):
    _clear_pose(rig)
    _new_action(rig, "Run")
    n = 20
    for i in range(n + 1):
        f = 1 + i
        phase = (i / n) * math.tau
        swing = math.sin(phase)
        _key_rot(rig, "LeftUpLeg", f, (swing * 0.95, 0, 0))
        _key_rot(rig, "RightUpLeg", f, (-swing * 0.95, 0, 0))
        _key_rot(rig, "LeftLeg", f, (max(0, -swing) * 1.4 + 0.2, 0, 0))
        _key_rot(rig, "RightLeg", f, (max(0, swing) * 1.4 + 0.2, 0, 0))
        _key_rot(rig, "LeftFoot", f, (-swing * 0.35, 0, 0))
        _key_rot(rig, "RightFoot", f, (swing * 0.35, 0, 0))
        _key_rot(rig, "LeftArm", f, (-swing * 0.9, 0, 0.15))
        _key_rot(rig, "RightArm", f, (swing * 0.9, 0, -0.15))
        _key_rot(rig, "LeftForeArm", f, (1.1, 0, 0))
        _key_rot(rig, "RightForeArm", f, (1.1, 0, 0))
        _key_rot(rig, "Spine", f, (0.22, 0, swing * 0.09))
        _key_rot(rig, "Spine1", f, (0.12, 0, swing * 0.06))
        _key_rot(rig, "Hips", f, (0, 0, -swing * 0.12))
        _key_loc(rig, "Hips", f, (0, 0, abs(math.sin(phase)) * 0.08))
    return "Run", n + 1


def make_jump(rig):
    _clear_pose(rig)
    _new_action(rig, "Jump")
    keys = [
        (1, 0.0, 0.0),
        (6, -0.5, 0.12),
        (12, 0.35, -0.05),
        (18, 0.15, 0.0),
        (24, -0.35, 0.10),
        (30, 0.0, 0.0),
    ]
    for f, leg, hips in keys:
        _key_rot(rig, "LeftUpLeg", f, (leg, 0, 0))
        _key_rot(rig, "RightUpLeg", f, (leg, 0, 0))
        _key_rot(rig, "LeftLeg", f, (max(0, -leg) * 1.6, 0, 0))
        _key_rot(rig, "RightLeg", f, (max(0, -leg) * 1.6, 0, 0))
        _key_rot(rig, "Spine", f, (leg * 0.3, 0, 0))
        _key_rot(rig, "LeftArm", f, (-leg * 1.2, 0, 0.1))
        _key_rot(rig, "RightArm", f, (-leg * 1.2, 0, -0.1))
        _key_loc(rig, "Hips", f, (0, 0, hips))
    return "Jump", 30


def add_animations(rig):
    for fn in (make_idle, make_walk, make_run, make_jump):
        name, end = fn(rig)
        print("ANIM", name, "->", end)
    # Volta para a pose neutra ao final.
    _clear_pose(rig)
    rig.animation_data.action = None


# ----------------------------------------------------------------------------
# montagem
# ----------------------------------------------------------------------------

def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    enable_mpfb()

    from bl_ext.user_default.mpfb.services.humanservice import HumanService
    from bl_ext.user_default.mpfb.services.targetservice import TargetService

    # Corpo MASCULINO: gender=1.0 (antes ficava 0.5 = andrógeno).
    macro = TargetService.get_default_macro_info_dict()
    macro["gender"] = 1.0
    macro["muscle"] = 0.55
    macro["weight"] = 0.5
    macro["height"] = 0.5
    macro["age"] = 0.35
    macro["race"] = {"asian": 0.0, "caucasian": 0.15, "african": 0.85}

    human = HumanService.create_human(feet_on_ground=True, macro_detail_dict=macro)
    print("HUMAN", human.name, len(human.data.vertices), "verts")
    print("HUMAN_MODS", [m.type for m in human.modifiers])

    skin = find_asset("middleage_african_male.mhmat", "skins")
    HumanService.set_character_skin(skin, human, skin_type="ENHANCED_SSS", material_instances=True)

    # Rig Mixamo (antes das roupas, para que elas sejam rigadas ao anexar).
    rig = HumanService.add_builtin_rig(human, "mixamo", import_weights=True)
    print("RIG", rig.name if rig else None)

    # Roupas MASCULINAS, agora RIGADAS ao esqueleto (set_up_rigging=True).
    def wear(fragment, label):
        path = find_asset(fragment)
        print("CLOTHES", label, path)
        if not path:
            return None
        return HumanService.add_mhclo_asset(
            path, human, asset_type="Clothes", subdiv_levels=0,
            material_type="MAKESKIN", set_up_rigging=True,
            interpolate_weights=True, import_subrig=True, import_weights=True)

    shirt = wear("elvs_male_athletic_tank1.mhclo", "regata-masculina")
    pants = wear("punkduck_male_classic_jeans.mhclo", "calca-masculina")
    shoes = wear("punkduck_comfortable_sneakers.mhclo", "tenis-masculino")

    if shirt:
        recolor(shirt, (0.93, 0.93, 0.91))
    if pants:
        recolor(pants, (0.05, 0.05, 0.06))
    if shoes:
        recolor(shoes, (0.95, 0.95, 0.96))

    if rig:
        add_animations(rig)

    hide_body_under_clothes(human, [shirt, pants, shoes])
    force_opaque()

    return human, rig


def export():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_apply=False,
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_bake_animation=True,
    )
    print("EXPORTED", OUT)


if __name__ == "__main__":
    build()
    export()
    print("DONE")
