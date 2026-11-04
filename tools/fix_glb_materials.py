"""Corrige o hero.glb: força todos os materiais a serem OPAQUE.

Motivo: o material do corpo vinha com alphaMode=BLEND. No Godot, material
transparente é desenhado DEPOIS do opaco, então o corpo nu aparecia através da
roupa (parecia um "personagem duplicado"). Este patch reescreve o JSON do glTF
removendo o alphaMode dos materiais — funciona sem depender do Blender.

    python3 tools/fix_glb_materials.py assets/character/hero.glb
"""

import json
import struct
import sys


def fix(path: str) -> None:
    with open(path, "rb") as fh:
        data = fh.read()

    magic, version, length = struct.unpack("<III", data[:12])
    assert magic == 0x46546C67, "não é um GLB"

    # chunk 0: JSON
    clen, ctype = struct.unpack("<II", data[12:20])
    assert ctype == 0x4E4F534A, "primeiro chunk não é JSON"
    js = json.loads(data[20:20 + clen])
    rest = data[20 + clen:]

    changed = 0
    for mat in js.get("materials", []):
        if "alphaMode" in mat and mat["alphaMode"] != "OPAQUE":
            del mat["alphaMode"]
            changed += 1
        # doubleSided ajuda a não ver "buracos" em roupas finas
        mat["doubleSided"] = True

    new_json = json.dumps(js, separators=(",", ":")).encode("utf-8")
    pad = (4 - len(new_json) % 4) % 4
    new_json += b" " * pad

    out = bytearray()
    out += struct.pack("<III", magic, version, 0)  # length preenchido depois
    out += struct.pack("<II", len(new_json), 0x4E4F534A)
    out += new_json
    out += rest
    struct.pack_into("<I", out, 8, len(out))

    with open(path, "wb") as fh:
        fh.write(out)
    print(f"FIXED {path}: {changed} materiais agora OPAQUE")


if __name__ == "__main__":
    fix(sys.argv[1] if len(sys.argv) > 1 else "assets/character/hero.glb")
