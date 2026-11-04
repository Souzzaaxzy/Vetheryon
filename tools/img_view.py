"""Inspetor de imagem: mostra a imagem em blocos coloridos (hex) para leitura
precisa de cores/regiões, e extrai paleta e amostras.

Uso:
    python3 tools/img_view.py imagem.png [largura_em_blocos] [altura_em_blocos]
"""

import sys
from collections import Counter

from PIL import Image


def show(path: str, cols: int = 64, rows: int = 40) -> None:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    small = im.resize((cols, rows))
    print(f"# {path}  ({w}x{h})  grade {cols}x{rows}")
    for y in range(rows):
        row = []
        for x in range(cols):
            r, g, b = small.getpixel((x, y))
            row.append(f"{r:02x}{g:02x}{b:02x}")
        print(" ".join(row))


def palette(path: str, n: int = 12) -> None:
    im = Image.open(path).convert("RGB")
    c = Counter(im.getdata())
    print(f"# paleta de {path} (top {n}):")
    total = im.size[0] * im.size[1]
    for col, cnt in c.most_common(n):
        print(f"  #{col[0]:02x}{col[1]:02x}{col[2]:02x}  rgb{col}  {cnt/total*100:5.1f}%")


if __name__ == "__main__":
    p = sys.argv[1]
    if len(sys.argv) > 2 and sys.argv[2] == "palette":
        palette(p)
    else:
        cols = int(sys.argv[2]) if len(sys.argv) > 2 else 64
        rows = int(sys.argv[3]) if len(sys.argv) > 3 else 40
        show(p, cols, rows)
        palette(p)
