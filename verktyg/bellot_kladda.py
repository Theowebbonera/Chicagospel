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


HORN = (100, 115)  # hörnområdet i den beskurna bilden (bredd, höjd)
MINSTA = 120  # pixlar: mindre former i hörnet är detaljer i bilden
LITET = (0, 62, 22, 112)  # remsan med det lilla färgtecknet (x0, y0, x1, y1), under bokstaven


def ta_bort_horn(bild):
    """Gör enfärgade former (svart eller rött) som ligger helt inom hörnområdet vita, med kantpixlar."""
    px = bild.load()
    w, h = bild.size

    def farg(x, y):
        r, g, b, a = px[x, y]
        if a < 128:
            return False
        svart = max(r, g, b) < 110
        rod = r > 150 and g < 110 and b < 110
        return svart or rod

    sedd = set()
    for y0 in range(HORN[1]):
        for x0 in range(HORN[0]):
            if (x0, y0) in sedd or not farg(x0, y0):
                continue
            komp = []
            ko = [(x0, y0)]
            sedd.add((x0, y0))
            inne = True
            while ko:
                x, y = ko.pop()
                komp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in sedd and farg(nx, ny):
                        sedd.add((nx, ny))
                        ko.append((nx, ny))
                        if nx >= HORN[0] or ny >= HORN[1]:
                            inne = False
            # ramlinjerna (långa, smala) och figuren når utanför hörnet och lämnas kvar, liksom små
            # detaljer (konturbitar i ansikten); bokstäver och färgtecken är stora sammanhängande ytor
            if inne and len(komp) >= MINSTA:
                for x, y in komp:
                    for dx in (-2, -1, 0, 1, 2):
                        for dy in (-2, -1, 0, 1, 2):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < w and 0 <= ny < h and (dx == 0 and dy == 0 or min(px[nx, ny][:3]) > 60 or farg(nx, ny)):
                                if dx == 0 and dy == 0 or not (0 <= nx < w and 0 <= ny < h) or _kant(px[nx, ny]):
                                    px[nx, ny] = (255, 255, 255, 255)
    # det lilla färgtecknet kan sitta ihop med figuren (t.ex. spaderkungens spira): kompakta enfärgade ytor
    # (minst 21 av 25 grannar i samma färg) tas bort med kanter; tunna konturlinjer blir kvar
    solid = set()
    for y in range(LITET[1], LITET[3]):
        for x in range(2, LITET[2]):
            if farg(x, y) and sum(farg(x + dx, y + dy) for dx in range(-2, 3) for dy in range(-2, 3)) >= 21:
                solid.add((x, y))
    bort = set()
    for x, y in solid:
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                nx, ny = x + dx, y + dy
                if 0 <= nx < LITET[2] + 3 and 0 <= ny < h and (farg(nx, ny) or _kant(px[nx, ny])):
                    bort.add((nx, ny))
    for x, y in bort:
        px[x, y] = (255, 255, 255, 255)
    return bild


def _kant(p):
    """Kantpixel (antialias) mellan färgtecknet och vitt: ljus blandfärg."""
    r, g, b, a = p
    return a < 128 or min(r, g, b) > 60 or (r > 150 and g < 200)


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
            # Bellots engelska hörn (bokstav, litet och stort färgtecken) tas bort i båda hörnen;
            # de svenska indexen ritas av kortbild.gd. Bara former som ligger helt i hörnet tas bort.
            bild = ta_bort_horn(bild)
            bild = ta_bort_horn(bild.rotate(180)).rotate(180)
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
