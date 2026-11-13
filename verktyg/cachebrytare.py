"""Versionsnummer på spelfilen i webbexporten (Theo 2026-11-13).

Godot hämtar index.pck utan versionsnummer, så webbläsaren kunde fortsätta
visa ett gammalt bygge ur cachen efter en ny publicering. Skriptet sätter
"mainPack":"index.pck?v=<hash>" i build/web/index.html, så att adressen
ändras när spelet ändras.

    python verktyg/cachebrytare.py [build/web]
"""
import hashlib
import pathlib
import re
import sys

mapp = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
html = mapp / "index.html"
pck = mapp / "index.pck"
v = hashlib.sha1(pck.read_bytes()).hexdigest()[:10]
s = html.read_text(encoding="utf-8")
s = re.sub(r'"mainPack":"[^"]*",?', "", s)
s, n = re.subn(r'"executable":"index"', f'"executable":"index","mainPack":"index.pck?v={v}"', s, count=1)
if n != 1:
    sys.exit("hittade inte executable i index.html")
html.write_text(s, encoding="utf-8")
print(f"index.pck?v={v}")
