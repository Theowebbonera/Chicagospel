"""Gör bilderna till de klädda korten ur David Bellots SVG-cards (LGPL-2.1, github.com/htdebeer/SVG-cards).

Bellots kungar har krona och skägg, knektarna hatt och damerna krona och slöja, så de går att skilja åt
(Knolls engelska knektar och kungar var för lika). Bilden beskärs till ramlinjerna och hörnet med de
engelska indexen täcks av kortbild.gd med en lapp med svenska index. Bildens vita bakgrund färgas som kortet.

    py verktyg/bellot_kladda.py <mapp med SVG-cards>

Läser png/2x/<färg>_<valör>.png och skriver assets/kort/<färg>_<valör>.png (färg 0–3 som i kort.gd, valör 11–13).
"""
import os
import sys

from PIL import Image

RAM = (18, 9, 322, 478)  # ramlinjerna i 2x-bilderna (338 × 489): vänster, topp, höger, botten
KORT = (251, 249, 242)  # kortets krämvita färg (kortbild.gd: Color(0.985, 0.975, 0.95))
FARGER = ["spade", "heart", "diamond", "club"]  # samma ordning som kort.gd
VALORER = {11: "jack", 12: "queen", 13: "king"}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    kalla = os.path.join(sys.argv[1], "png", "2x")
    ut = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "kort")
    os.makedirs(ut, exist_ok=True)
    for f, farg in enumerate(FARGER):
        for v, valor in VALORER.items():
            bild = Image.open(os.path.join(kalla, f"{farg}_{valor}.png")).convert("RGBA").crop(RAM)
            # vitt (och nästan vitt i kanterna mot linjerna) blandas mot kortets färg
            px = bild.load()
            for y in range(bild.height):
                for x in range(bild.width):
                    r, g, b, a = px[x, y]
                    vit = min(r, g, b) / 255.0
                    if vit > 0.85:
                        t = (vit - 0.85) / 0.15
                        px[x, y] = (round(r + (KORT[0] - 255) * t), round(g + (KORT[1] - 255) * t), round(b + (KORT[2] - 255) * t), a)
            bild.save(os.path.join(ut, f"{f}_{v}.png"))
            print("sparad", f"{f}_{v}.png", bild.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
