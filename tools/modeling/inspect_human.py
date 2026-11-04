"""Inspeciona as proporções do humano gerado pelo MPFB2 (para desenhar roupas)."""

import os

import bpy

os.environ.setdefault("BLENDER_USER_EXTENSIONS", "/workspace/tools/blender-config/extensions")


def enable_mpfb():
    import addon_utils

    addon_utils.enable("bl_ext.user_default.mpfb", default_set=True, persistent=True)
    prefs = bpy.context.preferences.addons["bl_ext.user_default.mpfb"].preferences
    prefs.mpfb_user_data = "/workspace/tools/mpfb-userdata"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    enable_mpfb()
    from bl_ext.user_default.mpfb.services.humanservice import HumanService

    human = HumanService.create_human()
    obj = [o for o in bpy.data.objects if o.type == "MESH"][0]
    print("NAME", obj.name)
    co = [v.co for v in obj.data.vertices]
    xs = [c.x for c in co]
    ys = [c.y for c in co]
    zs = [c.z for c in co]
    print("BBOX x", round(min(xs), 3), round(max(xs), 3))
    print("BBOX y", round(min(ys), 3), round(max(ys), 3))
    print("BBOX z", round(min(zs), 3), round(max(zs), 3))
    print("VERTS", len(co))
    print("MATERIALS", [m.name for m in obj.data.materials])
    print("VGROUPS", len(obj.vertex_groups))
    print("MODIFIERS", [m.name for m in obj.modifiers])
    # Altura aproximada de pontos-chave
    print("SCALE", obj.scale, "loc", obj.location)
    # distribuição de z em faixas
    import collections
    hist = collections.Counter(int(z * 10) / 10 for z in zs)
    print("Z hist (top):", sorted(hist.items())[:6], "...", sorted(hist.items())[-6:])


if __name__ == "__main__":
    main()
