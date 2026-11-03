"""Fyra realistiska figurer till Chicago, byggda med MPFB (MakeHuman för Blender) efter Theos bild från fjälltoppen.

Från vänster på bilden: Kevin, Theo, Lukas, Adam. Kropparna, huden, håret och kläderna kommer från MPFB
(CC0); kläderna färgas om efter bilden. Kepsar, glasögon, solglasögon, DevEd-texten, Kevins gula handske
och Adams svarta armärm modelleras här. Figurerna sitter (vilan i skelettet är sittande), framsidan mot -Y.

    blender.exe -b -P blender/gubbar.py              (alla fyra: assets/gubbar/<namn>.glb och provbilder)
    blender.exe -b -P blender/gubbar.py -- Theo      (bara en)
    blender.exe -b -P blender/gubbar.py -- --prov    (bara provbilder, ingen export)

Kräver MPFB 2 med standardtillgångarna installerat i Blender 4.5.
"""
import importlib
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

MPFB = "bl_ext.user_default.mpfb"
HS = importlib.import_module(MPFB + ".services.humanservice").HumanService
TS = importlib.import_module(MPFB + ".services.targetservice").TargetService
MAL = os.path.join(os.environ["APPDATA"], "Blender Foundation", "Blender", "4.5", "extensions", "user_default", "mpfb", "data", "targets")
DATA = os.path.join(os.environ["APPDATA"], "Blender Foundation", "Blender", "4.5", "extensions", ".user", "user_default", "mpfb", "data")
ROT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UT = os.path.join(ROT, "assets", "gubbar")
PROV = os.path.join(ROT, "blender", "prov")

# Texturstorlek i spelet (webben och mobilen ska klara sex figurer).
TEX = {"hud": 1024, "klader": 1024, "har": 512, "ovrigt": 256}

# Alla färger anges i sRGB (som i en bildeditor): texturernas pixlar lagras så, och material() räknar om.
PERSONER = [
    {
        "namn": "Kevin",
        "macro": {"age": 0.48, "muscle": 0.55, "weight": 0.5, "height": 0.62, "proportions": 0.8},
        "hud": "young_caucasian_male", "hudton": (1.04, 0.97, 0.95),
        "har": "short04", "harfarg": (0.36, 0.22, 0.12),
        "klader": "male_casualsuit05", "troja": (0.075, 0.078, 0.085), "byxor": (0.07, 0.07, 0.078),
        "keps": {"farg": (0.36, 0.38, 0.33), "bak": True},
        "handske": "r",
        "ansikte": {"head/head-oval": 0.5, "chin/chin-width-decr": 0.3, "cheek/l-cheek-bones-decr": 0.2, "cheek/r-cheek-bones-decr": 0.2, "mouth/mouth-angles-up": 0.45},
    },
    {
        "namn": "Theo",
        "macro": {"age": 0.48, "muscle": 0.7, "weight": 0.72, "height": 0.5, "proportions": 0.75},
        "hud": "young_caucasian_male2", "hudton": (0.93, 0.83, 0.74),
        "har": "short02", "harfarg": (0.08, 0.055, 0.04),
        "klader": "male_casualsuit02", "troja": (0.1, 0.12, 0.25), "byxor": (0.24, 0.24, 0.25),
        "keps": {"farg": (0.93, 0.93, 0.91), "bak": True},
        "text": "DevEd",
        "ansikte": {"head/head-round": 0.45, "head/head-fat-incr": 0.35, "chin/chin-width-incr": 0.35, "nose/nose-scale-horiz-incr": 0.25, "mouth/mouth-angles-up": 0.55, "mouth/mouth-dimples-in": 0.3},
    },
    {
        "namn": "Lukas",
        "macro": {"age": 0.46, "muscle": 0.6, "weight": 0.62, "height": 0.85, "proportions": 0.85},
        "hud": "young_caucasian_male", "hudton": (1.0, 0.95, 0.92),
        "har": "short02", "harfarg": (0.2, 0.14, 0.09),
        "klader": "male_casualsuit05", "troja": (0.07, 0.07, 0.078), "byxor": (0.065, 0.065, 0.07),
        "keps": {"farg": (0.07, 0.07, 0.075), "bak": False, "bokstav": "P"},
        "glasogon": True,
        "ansikte": {"head/head-rectangular": 0.4, "head/head-scale-vert-incr": 0.25, "chin/chin-height-incr": 0.3, "mouth/mouth-angles-up": 0.65, "mouth/mouth-scale-horiz-incr": 0.2},
    },
    {
        "namn": "Adam",
        "macro": {"age": 0.48, "muscle": 0.75, "weight": 0.45, "height": 0.66, "proportions": 0.85},
        "hud": "young_caucasian_male2", "hudton": (0.9, 0.78, 0.66),
        "har": "short02", "harfarg": (0.07, 0.05, 0.035),
        "klader": "male_casualsuit06", "troja": (0.94, 0.94, 0.93), "byxor": (0.42, 0.43, 0.44),
        "keps": {"farg": (0.16, 0.16, 0.17), "bak": True, "solglasogon": True},
        "armarm": "l",
        "ansikte": {"head/head-triangular": 0.3, "head/head-scale-horiz-decr": 0.15, "chin/chin-prominent-incr": 0.4, "chin/chin-bones-incr": 0.3, "mouth/mouth-angles-up": 0.5},
    },
    # Kändisar för skojs skull: igenkännbara på frisyr, kläder och nummer (ansiktena är MPFB med formmål,
    # inte porträtt). Inga klubb- eller förbundsmärken.
    {
        "namn": "Ronaldo",
        "macro": {"age": 0.62, "muscle": 0.92, "weight": 0.42, "height": 0.78, "proportions": 0.9},
        "hud": "young_caucasian_male2", "hudton": (0.9, 0.76, 0.62),
        "har": "short02", "harfarg": (0.06, 0.045, 0.035),
        "klader": "male_casualsuit06", "troja": (0.72, 0.06, 0.12), "byxor": (0.05, 0.3, 0.16),
        "text": "7", "textstorlek": 0.11, "textfarg": (0.96, 0.84, 0.45),
        "ansikte": {"head/head-oval": 0.45, "chin/chin-prominent-incr": 0.45, "chin/chin-width-incr": 0.2,
                    "cheek/l-cheek-bones-incr": 0.35, "cheek/r-cheek-bones-incr": 0.35, "eyebrows/eyebrows-angle-up": 0.3,
                    "nose/nose-scale-horiz-decr": 0.2, "mouth/mouth-angles-up": 0.7, "mouth/mouth-scale-horiz-incr": 0.25},
    },
    {
        "namn": "Messi",
        "macro": {"age": 0.6, "muscle": 0.6, "weight": 0.5, "height": 0.28, "proportions": 0.75},
        "hud": "young_caucasian_male2", "hudton": (0.96, 0.84, 0.72),
        "har": "short03", "harfarg": (0.2, 0.13, 0.075),
        "klader": "male_casualsuit06", "troja": (0.47, 0.71, 0.9), "byxor": (0.08, 0.08, 0.09),
        "ranor": {"farg": (0.95, 0.95, 0.94), "bredd": 0.075},
        "text": "10", "textstorlek": 0.1, "textfarg": (0.08, 0.1, 0.18),
        "skagg": {"farg": (0.19, 0.12, 0.07), "styrka": 0.97}, "klipp_lugg": 0.012,
        "ansikte": {"head/head-round": 0.3, "chin/chin-height-incr": 0.2, "nose/nose-scale-vert-incr": 0.2, "nose/nose-point-down": 0.2,
                    "eyebrows/eyebrows-angle-down": 0.25, "mouth/mouth-angles-up": 0.35},
    },
    {
        "namn": "Trump",
        "macro": {"age": 0.88, "muscle": 0.35, "weight": 0.85, "height": 0.78, "proportions": 0.7},
        "hud": "old_caucasian_male", "hudton": (1.1, 0.83, 0.6),
        "har": "short03", "harfarg": (0.93, 0.78, 0.47),
        "klipp_lugg": 0.02, "klader": "male_elegantsuit01", "troja": (0.09, 0.11, 0.2), "slips": (0.78, 0.07, 0.09),
        "ansikte": {"head/head-square": 0.4, "head/head-fat-incr": 0.5, "chin/chin-width-incr": 0.4, "neck/neck-double-incr": 0.6,
                    "cheek/l-cheek-volume-incr": 0.4, "cheek/r-cheek-volume-incr": 0.4, "mouth/mouth-scale-horiz-decr": 0.3,
                    "mouth/mouth-lowerlip-volume-incr": 0.3, "mouth/mouth-angles-down": 0.25, "eyebrows/eyebrows-angle-down": 0.3},
    },
    {
        "namn": "Zlatan",
        "macro": {"age": 0.7, "muscle": 0.85, "weight": 0.5, "height": 0.97, "proportions": 0.85},
        "hud": "young_caucasian_male2", "hudton": (0.92, 0.8, 0.68),
        "har": "ponytail01", "harfarg": (0.07, 0.05, 0.04),
        "klader": "male_casualsuit06", "troja": (0.99, 0.82, 0.08), "byxor": (0.04, 0.2, 0.52),
        "text": "10", "textstorlek": 0.1, "textfarg": (0.04, 0.22, 0.55),
        "skagg": {"farg": (0.1, 0.07, 0.05), "styrka": 0.93},
        "ansikte": {"head/head-rectangular": 0.4, "head/head-scale-vert-incr": 0.2, "nose/nose-scale-vert-incr": 0.5, "nose/nose-hump-incr": 0.6,
                    "nose/nose-scale-depth-incr": 0.3, "chin/chin-prominent-incr": 0.35, "chin/chin-height-incr": 0.25, "mouth/mouth-angles-up": 0.3},
    },
]


def asset(*delar):
    return os.path.join(DATA, *delar)


# ------------------------------------------------------------------ texturer
def _pixlar(img):
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def _spara(img, a):
    img.pixels.foreach_set(a.ravel())
    img.update()
    img.pack()


def _kopia(img, namn):
    ny = img.copy()
    ny.name = namn
    return ny


def tona(img, faktor):
    a = _pixlar(img)
    a[..., :3] = np.clip(a[..., :3] * np.array(faktor, dtype=np.float32), 0, 1)
    _spara(img, a)


def farga_klader(img, kladnamn, troja, byxor):
    """Färgar om plaggen och behåller vecken. Jeansen ligger nere till vänster i texturerna, resten är tröjan/jackan."""
    a = _pixlar(img)
    h, w = a.shape[:2]
    v = (np.arange(h, dtype=np.float32) + 0.5)[:, None] / h  # rad 0 = v 0 (Blender lagrar nerifrån)
    u = (np.arange(w, dtype=np.float32) + 0.5)[None, :] / w
    # jeansens del av texturen (u upp till, v upp till) per plagg
    jeans_u, jeans_v = {"male_casualsuit02": (0.76, 0.58), "male_casualsuit05": (0.61, 0.46), "male_casualsuit06": (0.79, 0.58)}[kladnamn]
    jeans = (u < jeans_u) & (v < jeans_v)
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    for mask, farg, kontrast in ((jeans, byxor, 0.45), (~jeans, troja, 0.6)):
        m = mask & (a[..., 3] > 0.01)
        if not m.any():
            continue
        medel = float(np.median(lum[m]))
        skugga = 1.0 + (lum / max(medel, 1e-3) - 1.0) * kontrast
        skugga = np.clip(skugga, 0.55, 1.12)
        if kladnamn == "male_casualsuit06" and farg is troja:
            # t-shirten: MakeHuman-loggan (orange/grå) blir tyg
            sat = a[..., :3].max(-1) - a[..., :3].min(-1)
            skugga = np.where(sat > 0.08, 1.0, np.clip(skugga, 0.85, 1.04))
        for k in range(3):
            a[..., k] = np.where(m, farg[k] * skugga, a[..., k])
    _spara(img, a)


def farga_kostym(img, kostym, slips):
    """Kostymen (elegantsuit01): kavaj och byxor i kostymfärgen, skjortan vit, slipsen i slipsfärgen."""
    a = _pixlar(img)
    h, w = a.shape[:2]
    v = (np.arange(h, dtype=np.float32) + 0.5)[:, None] / h
    u = (np.arange(w, dtype=np.float32) + 0.5)[None, :] / w
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    sat = a[..., :3].max(-1) - a[..., :3].min(-1)
    slipsruta = (u > 0.355) & (u < 0.47) & (v > 0.8) & (v < 0.95)
    slips_m = slipsruta & (sat > 0.05)
    skjorta = (lum > 0.55) & ~slips_m
    kostym_m = ~slips_m & ~skjorta & (a[..., 3] > 0.01)
    medel = float(np.median(lum[kostym_m]))
    skugga = np.clip(1.0 + (lum / max(medel, 1e-3) - 1.0) * 0.55, 0.5, 1.25)
    for k in range(3):
        a[..., k] = np.where(kostym_m, kostym[k] * skugga, a[..., k])
        a[..., k] = np.where(slips_m, slips[k] * np.clip(0.75 + lum * 0.6, 0.7, 1.15), a[..., k])
        a[..., k] = np.where(skjorta, np.clip(lum * 1.05 + 0.04, 0, 0.97), a[..., k])
    _spara(img, a)


def _formlage(obj):
    """Vertexlägena i världen med alla formmål (utan modifierare), och trianglarnas vertexar och UV."""
    mods = [(m, m.show_viewport) for m in obj.modifiers]
    for m, _ in mods:
        m.show_viewport = False
    bpy.context.view_layer.update()
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    me.calc_loop_triangles()
    nt = len(me.loop_triangles)
    tl = np.empty(nt * 3, dtype=np.int32)
    tv = np.empty(nt * 3, dtype=np.int32)
    me.loop_triangles.foreach_get("loops", tl)
    me.loop_triangles.foreach_get("vertices", tv)
    uv = np.empty(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    ev.to_mesh_clear()
    for m, vis in mods:
        m.show_viewport = vis
    mw = np.array(obj.matrix_world, dtype=np.float32)
    co = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    return co, tv.reshape(-1, 3), uv.reshape(-1, 2)[tl.reshape(-1, 3)]


def mala(img, tv, tuv, varden, fn, hoppa, buffert=None):
    """Målar i en textur efter ett värde per vertex: varje triangel rastreras i UV-rymden och värdena
    interpoleras per pixel; fn(värden, rgb) ger nya färger. hoppa(värden för triangelns hörn) hoppar över."""
    a = _pixlar(img) if buffert is None else buffert
    h, w = a.shape[:2]
    skala = np.array([w, h], dtype=np.float32)
    for t in range(len(tv)):
        vv = varden[tv[t]]
        if hoppa(vv, tuv[t]):
            continue
        p = tuv[t] * skala - 0.5
        x0, y0 = np.floor(p.min(0)).astype(int) - 1
        x1, y1 = np.ceil(p.max(0)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
        if x1 < x0 or y1 < y0:
            continue
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-9:
            continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        b0 = ((p[1, 1] - p[2, 1]) * (X - p[2, 0]) + (p[2, 0] - p[1, 0]) * (Y - p[2, 1])) / d
        b1 = ((p[2, 1] - p[0, 1]) * (X - p[2, 0]) + (p[0, 0] - p[2, 0]) * (Y - p[2, 1])) / d
        b2 = 1 - b0 - b1
        inne = (b0 > -0.08) & (b1 > -0.08) & (b2 > -0.08)  # lite utanför, så att sömmarna inte syns
        if not inne.any():
            continue
        val = b0[..., None] * vv[0] + b1[..., None] * vv[1] + b2[..., None] * vv[2]
        ys, xs = Y[inne], X[inne]
        if buffert is None:
            a[ys, xs, :3] = fn(val[inne], a[ys, xs, :3])
        else:
            a[ys, xs] = np.maximum(a[ys, xs], val[inne][:, 0])
    if buffert is None:
        _spara(img, a)


JEANS = {"male_casualsuit02": (0.76, 0.58), "male_casualsuit05": (0.61, 0.46), "male_casualsuit06": (0.79, 0.58)}


def ranor(obj, img, kladnamn, cfg):
    """Lodräta ränder på tröjan (Argentina): efter världens X, så att ränderna går rakt över bröstet."""
    co, tv, tuv = _formlage(obj)
    ju, jv = JEANS[kladnamn]
    farg = np.array(cfg["farg"], dtype=np.float32)
    bredd = cfg["bredd"]
    a = _pixlar(img)
    h, w = a.shape[:2]
    v = (np.arange(h) + 0.5)[:, None] / h
    u = (np.arange(w) + 0.5)[None, :] / w
    troja = ~((u < ju) & (v < jv)) & (a[..., 3] > 0.01)
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    medel = float(np.median(lum[troja]))

    def fn(val, rgb):
        vit = (np.floor(val[:, 0] / bredd + 0.5).astype(int) % 2) == 0
        l = rgb[:, 0] * 0.3 + rgb[:, 1] * 0.59 + rgb[:, 2] * 0.11
        sk = np.clip(l / max(medel, 1e-3), 0.6, 1.2)[:, None]
        return np.where(vit[:, None], np.clip(farg[None, :] * sk, 0, 1), rgb)

    mala(img, tv, tuv, co[:, :1], fn, lambda vv, uv: bool(((uv[:, 0] < ju) & (uv[:, 1] < jv)).any()))


def skagg(kropp, img, cfg):
    """Helskägg målat på huden: kinder, haka och mustasch, men inte läpparna. Gränserna mäts från läpparna."""
    co, tv, tuv = _formlage(kropp)
    nv = len(co)

    def vikt(grupp):
        out = np.zeros(nv, dtype=np.float32)
        if grupp not in kropp.vertex_groups:
            return out
        gi = kropp.vertex_groups[grupp].index
        for v in kropp.data.vertices:
            for g in v.groups:
                if g.group == gi:
                    out[v.index] = g.weight
        return out

    lapp = vikt("lips") > 0.3
    huvud = (vikt("head") > 0.3) | (vikt("neck_01") > 0.3)
    hjalp = (vikt("HelperGeometry") > 0) | (vikt("JointCubes") > 0)
    L = co[lapp]
    mitt = L.mean(0)
    lw = (L[:, 0].max() - L[:, 0].min()) / 2
    lt = L[:, 2].max() - mitt[2]
    dx = np.abs(co[:, 0] - mitt[0])
    dz = co[:, 2] - mitt[2]
    dy = co[:, 1] - mitt[1]

    def ss(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0, 1)
        return t * t * (3 - 2 * t)

    # övre gränsen: mustaschen strax över läppen, stiger ut mot kinderna (kindskägg mot örat)
    zmax = np.minimum(lt + 0.014 + np.clip(dx - lw * 0.9, 0, None) * 0.55, lt + 0.034)
    alfa = ss(-0.004, 0.012, zmax - dz) * ss(-0.09, -0.065, dz) * ss(0.075, 0.045, dy)
    alfa = np.where(huvud & ~lapp & ~hjalp, alfa, 0.0)
    # läpparna och en smal kant runt dem fria
    nara = np.min(np.linalg.norm(co[:, None, :] - L[None, ::2, :], axis=2), axis=1)
    alfa = alfa * ss(0.001, 0.005, nara) * cfg["styrka"]
    farg = np.array(cfg["farg"], dtype=np.float32)
    # alfa målas först i en egen buffert (största värdet där trianglar överlappar), sedan blandas skägget in en gång
    px = _pixlar(img)
    buf = np.zeros(px.shape[:2], dtype=np.float32)
    mala(img, tv, tuv, alfa[:, None].astype(np.float32), None, lambda vv, uv: bool((vv[:, 0] <= 0.001).all()), buf)
    rng = np.random.default_rng(7)
    # hårstrån: brus i färgen, och huden skiner igenom lite
    brus = rng.uniform(0.55, 1.5, size=buf.shape + (1,)).astype(np.float32)
    a = (np.clip(buf, 0, 1) * rng.uniform(0.75, 1.0, size=buf.shape).astype(np.float32))[..., None]
    px[..., :3] = px[..., :3] * (1 - a) + np.clip(farg * brus, 0, 1) * a
    _spara(img, px)


def material_bilder(obj):
    for slot in obj.material_slots:
        m = slot.material
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    yield m, n


def egna_bilder(obj, prefix, storlek, bas=None):
    """Gör egna kopior av objektets bilder (så att personerna inte delar), krymper dem och returnerar diffuse-noderna."""
    diffuse = []
    for m, n in material_bilder(obj):
        if n.image.name.startswith(prefix):
            continue
        n.image = _kopia(n.image, f"{prefix}{n.image.name}")
        s = storlek if "normal" not in n.image.name.lower() else max(storlek // 2, 256)
        if n.image.size[0] > s:
            n.image.scale(s, s)
        is_diffuse = any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links) or "diffuse" in n.image.name.lower()
        if is_diffuse:
            diffuse.append(n.image)
        else:
            n.image.pack()
    return diffuse


# ------------------------------------------------------------------ pose
def rikta(rig, namn, riktning):
    pb = rig.pose.bones[namn]
    m = pb.matrix.copy()
    nu = (m.to_3x3() @ Vector((0, 1, 0))).normalized()
    q = nu.rotation_difference(Vector(riktning).normalized())
    pb.matrix = Matrix.Translation(m.to_translation()) @ q.to_matrix().to_4x4() @ Matrix(m.to_3x3()).to_4x4()
    bpy.context.view_layer.update()


def rulla(rig, namn, axel, mal):
    """Vrider benet runt sin längdaxel så att dess lokala X- eller Z-axel pekar så nära `mal` som möjligt."""
    pb = rig.pose.bones[namn]
    m = pb.matrix.copy()
    r = m.to_3x3()
    y = (r @ Vector((0, 1, 0))).normalized()
    a = (r @ (Vector((1, 0, 0)) if axel == "X" else Vector((0, 0, 1)))).normalized()
    t = Vector(mal)
    t = (t - y * t.dot(y)).normalized()
    vinkel = a.angle(t)
    tecken = 1 if y.dot(a.cross(t)) > 0 else -1
    pb.matrix = Matrix.Translation(m.to_translation()) @ Quaternion(y, tecken * vinkel).to_matrix().to_4x4() @ Matrix(r).to_4x4()
    bpy.context.view_layer.update()


def sitt(rig):
    """Sittande vid kortbordet: rak rygg, underarmarna vilar framåt på bordet, handflatorna nedåt.
    Skelettets koordinater: framsidan mot -Y, upp +Z, vänster sida åt +X."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for s, sx in (("l", 1), ("r", -1)):
        rikta(rig, f"thigh_{s}", (sx * 0.12, -1.0, -0.06))
        rikta(rig, f"calf_{s}", (sx * 0.03, 0.1, -1.0))
        rikta(rig, f"foot_{s}", (0, -0.85, -0.4))
    rikta(rig, "spine_01", (0, -0.08, 1))
    rikta(rig, "spine_02", (0, -0.12, 1))
    rikta(rig, "spine_03", (0, -0.1, 1))
    rikta(rig, "neck_01", (0, -0.25, 1))
    rikta(rig, "head", (0, -0.08, 1))
    for s, sx in (("l", 1), ("r", -1)):
        rikta(rig, f"upperarm_{s}", (sx * 0.22, -0.42, -0.88))
        rikta(rig, f"lowerarm_{s}", (-sx * 0.3, -1.0, 0.02))
        rikta(rig, f"hand_{s}", (-sx * 0.12, -1.0, -0.08))
        rulla(rig, f"hand_{s}", "X", (0, 0, -sx))
        # fingrarna raka och lätt böjda, som en hand som vilar på bordet
        hand = (rig.pose.bones[f"hand_{s}"].matrix.to_3x3() @ Vector((0, 1, 0))).normalized()
        for f in ("index", "middle", "ring", "pinky"):
            for i, ned in ((1, 0.12), (2, 0.3), (3, 0.45)):
                rikta(rig, f"{f}_{i:02d}_{s}", hand + Vector((0, 0, -ned)))
    bpy.ops.object.mode_set(mode="OBJECT")


def pose_som_vila(rig, delar):
    """Den sittande posen blir skelettets vila: meshen deformeras och sparas, skelettet får posen som vila."""
    for o in delar:
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        if o.data.shape_keys:
            o.shape_key_add(name="mix", from_mix=True)
            for kb in list(o.data.shape_keys.key_blocks)[:-1]:
                o.shape_key_remove(kb)
            o.shape_key_remove(o.data.shape_keys.key_blocks[0])
        for mod in list(o.modifiers):
            if mod.type == "ARMATURE":
                namn = mod.name
                with bpy.context.temp_override(object=o):
                    bpy.ops.object.modifier_apply(modifier=namn)
                ny = o.modifiers.new(namn, "ARMATURE")
                ny.object = rig
                # armaturen först, före masker och liknande
                while o.modifiers.find(namn) > 0:
                    with bpy.context.temp_override(object=o):
                        bpy.ops.object.modifier_move_up(modifier=namn)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")


# ------------------------------------------------------------------ hjälp för egna delar
def material(namn, farg, rough=0.7, metall=0.0, alfa=1.0):
    """farg i sRGB, som allt annat i PERSONER (blir linjär här)."""
    m = bpy.data.materials.new(namn)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*(c ** 2.2 for c in farg), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metall
    if alfa < 1.0:
        b.inputs["Alpha"].default_value = alfa
        m.surface_render_method = "BLENDED"
    return m


def till_ben(obj, rig, ben):
    """Fäster objektet vid ett ben (följer huvudet, bröstet osv.) utan att flytta det."""
    bpy.context.view_layer.update()
    mw = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = ben
    bpy.context.view_layer.update()
    obj.matrix_world = mw


def grupp_bbox(obj, grupp, minst=0.6, z_min=-1e9):
    gi = obj.vertex_groups[grupp].index
    pts = []
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if p.z < z_min:
            continue
        for g in v.groups:
            if g.group == gi and g.weight >= minst:
                pts.append(p)
                break
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def obj_bbox(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def ny_mesh(namn, bm, mat):
    me = bpy.data.meshes.new(namn)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(namn, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return o


# ------------------------------------------------------------------ keps, glasögon, text, handske, armärm
def keps(rig, huvud_lo, huvud_hi, bryn_z, cfg, namn):
    """Keps: kupa (halvt ellipsoid) som sluter tätt kring huvudet från strax ovanför ögonbrynen, och en skärm
    framåt eller bakåt. Mått från hårets/huvudets yttermått."""
    mitt = (huvud_lo + huvud_hi) / 2
    rx = (huvud_hi.x - huvud_lo.x) / 2 + 0.007
    ry = (huvud_hi.y - huvud_lo.y) / 2 + 0.007
    topp = huvud_hi.z + 0.012
    bas_z = bryn_z + 0.028
    rz = topp - bas_z
    mat = material(f"{namn}_keps", cfg["farg"], 0.85)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
    for v in bm.verts:
        z = max(v.co.z, 0.0)
        # fylligare sidor och plattare topp än en halvsfär
        v.co = Vector((v.co.x * rx, v.co.y * ry, (z ** KUPA) * rz))
    # nedre kanten följer huvudet: högst över pannan, längre ned över nacken
    for v in bm.verts:
        if v.co.z < 0.05 * rz:
            v.co.z -= 0.035 * max(0.0, v.co.y / ry)
    kupa = ny_mesh(f"{namn}_kepskupa", bm, mat)
    kupa.location = (mitt.x, mitt.y, bas_z)
    knapp = bmesh.new()
    bmesh.ops.create_uvsphere(knapp, u_segments=12, v_segments=6, radius=0.009)
    k = ny_mesh(f"{namn}_kepsknapp", knapp, mat)
    k.location = (mitt.x, mitt.y, topp + 0.002)
    # skärmen: ett rundat, lätt böjt blad framför (eller bakom) kupan
    fram = -1 if not cfg["bak"] else 1
    bm = bmesh.new()
    seg = 24
    bredd = rx * 0.92
    djup = 0.075
    yt, ner = [], []
    for i in range(seg + 1):
        t = i / seg
        x = (t * 2 - 1) * bredd
        kant = djup * math.sqrt(max(0.0, 1 - (x / bredd) ** 2))
        for j, (d, z) in enumerate(((0.0, 0.0), (kant, -0.012 - 0.02 * (kant / djup)))):
            bow = -0.012 * (x / bredd) ** 2  # böjd skärm
            yt.append(bm.verts.new((x, fram * (ry * 0.82 + d), z + bow)))
    bm.verts.ensure_lookup_table()
    for i in range(seg):
        a, b, c, d = yt[2 * i], yt[2 * i + 1], yt[2 * i + 3], yt[2 * i + 2]
        bm.faces.new((a, b, c, d) if fram < 0 else (d, c, b, a))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
    skarm = ny_mesh(f"{namn}_kepsskarm", bm, mat)
    skarm.location = (mitt.x, mitt.y, bas_z + 0.008)
    delar = [kupa, k, skarm]
    if cfg.get("bokstav"):
        delar.append(kepsbokstav(cfg["bokstav"], mitt, ry, rz, bas_z, namn))
    if cfg.get("solglasogon"):
        delar += solglasogon(mitt, rx, ry, rz, bas_z, namn)
    for d in delar:
        till_ben(d, rig, "head")
    return delar


KUPA = 0.8  # < 1 ger fylligare sidor och plattare topp än en halvsfär


def kepsyta(mitt, ry, rz, bas_z, vinkel, utat=0.0):
    """Punkt på kupans framsida vid `vinkel` (0 = nedre kanten, 90° = toppen) och utåtnormalen där."""
    y = -math.cos(vinkel) * ry
    z = (math.sin(vinkel) ** KUPA) * rz
    n = Vector((0.0, -math.cos(vinkel) * rz, math.sin(vinkel) * ry)).normalized()
    return Vector((mitt.x, mitt.y + y, bas_z + z)) + n * utat, n


def textobjekt(text, storlek, mat, namn):
    cu = bpy.data.curves.new(namn, "FONT")
    cu.body = text
    cu.size = storlek
    cu.extrude = 0.0008
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    for f in ("C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/segoeuib.ttf"):
        if os.path.exists(f):
            cu.font = bpy.data.fonts.load(f)
            break
    o = bpy.data.objects.new(namn, cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    with bpy.context.temp_override(active_object=o, selected_objects=[o], selected_editable_objects=[o]):
        bpy.ops.object.convert(target="MESH")
    o.select_set(False)
    return o


def kepsbokstav(bokstav, mitt, ry, rz, bas_z, namn):
    o = textobjekt(bokstav, 0.045, material(f"{namn}_bokstav", (0.95, 0.95, 0.95), 0.6), f"{namn}_kepsbokstav")
    vinkel = math.radians(35)
    o.data.transform(Matrix.Rotation(math.radians(90) - vinkel, 4, "X"))
    o.location, _n = kepsyta(mitt, ry, rz, bas_z, vinkel, 0.0025)
    return o


def solglasogon(mitt, rx, ry, rz, bas_z, namn):
    """Solglasögon uppskjutna på kepsen, på kupans framsida ovanför pannan."""
    glas = material(f"{namn}_solglas", (0.05, 0.05, 0.06), 0.12, 0.5)
    ram = material(f"{namn}_solram", (0.08, 0.08, 0.09), 0.4)
    delar = []
    vinkel = math.radians(34)
    mitten, n = kepsyta(mitt, ry, rz, bas_z, vinkel, 0.006)
    vrid = Matrix.Rotation(-vinkel, 4, "X")
    for sx in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * 0.029, v.co.y * 0.005, v.co.z * 0.021))
        o = ny_mesh(f"{namn}_sollins{sx}", bm, glas)
        o.data.transform(vrid)
        o.location = mitten + Vector((sx * 0.034, 0, 0))
        delar.append(o)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.13, v.co.y * 0.004, v.co.z * 0.005))
    o = ny_mesh(f"{namn}_solbage", bm, ram)
    o.data.transform(vrid)
    o.location = mitten + (vrid @ Vector((0, 0, 0.019)))
    delar.append(o)
    # skalmarna bakåt längs kupans sidor
    for sx in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * 0.004, (v.co.y + 0.5) * ry * 1.1, v.co.z * 0.005))
        o = ny_mesh(f"{namn}_solskalm{sx}", bm, ram)
        o.data.transform(Matrix.Rotation(math.radians(-12), 4, "X"))
        o.location = mitten + Vector((sx * min(0.064, rx * 0.97), 0.0, 0.006))
        delar.append(o)
    return delar


def glasogon(rig, ogon, huvud_lo, huvud_hi, namn):
    """Tunna mörka bågar framför ögonen, med skalmar bakåt mot öronen."""
    lo, hi = obj_bbox(ogon)
    mitt = (lo + hi) / 2
    avst = (hi.x - lo.x) / 2 - 0.012
    ram = material(f"{namn}_glasram", (0.06, 0.06, 0.065), 0.35, 0.3)
    glas = material(f"{namn}_glas", (0.85, 0.9, 0.95), 0.05, 0.0, alfa=0.12)
    delar = []
    fram_y = lo.y - 0.012
    for sx in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, segments=28, radius=1.0)
        ring = bmesh.new()
        # ram: torus-liknande ring av en tunn kvadrat som svepts runt en rundad rektangel
        bm.free()
        ring_verts = []
        n = 32
        for i in range(n):
            t = i / n * math.tau
            x = math.copysign(abs(math.cos(t)) ** 0.7, math.cos(t)) * 0.026
            z = math.copysign(abs(math.sin(t)) ** 0.8, math.sin(t)) * 0.019
            ring_verts.append(Vector((x, 0, z)))
        tj = 0.0016
        prof = [Vector((-tj, -tj, 0)), Vector((tj, -tj, 0)), Vector((tj, tj, 0)), Vector((-tj, tj, 0))]
        rad = []
        for i, p in enumerate(ring_verts):
            ut = p.normalized()
            rad.append([ring.verts.new(p + ut * q.x + Vector((0, q.y, 0))) for q in prof])
        for i in range(n):
            a, b = rad[i], rad[(i + 1) % n]
            for k in range(4):
                ring.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
        o = ny_mesh(f"{namn}_bage{sx}", ring, ram)
        o.location = (mitt.x + sx * avst, fram_y, mitt.z)
        delar.append(o)
        lins = bmesh.new()
        bmesh.ops.create_circle(lins, segments=28, radius=1.0, cap_ends=True)
        for v in lins.verts:
            v.co = Vector((v.co.x * 0.025, 0.0, v.co.y * 0.018))
        o = ny_mesh(f"{namn}_lins{sx}", lins, glas)
        o.location = (mitt.x + sx * avst, fram_y, mitt.z)
        delar.append(o)
        # skalm bakåt
        sk = bmesh.new()
        bmesh.ops.create_cube(sk, size=1.0)
        langd = (huvud_hi.y - lo.y) * 0.62
        for v in sk.verts:
            v.co = Vector((v.co.x * 0.003, (v.co.y + 0.5) * langd, v.co.z * 0.004))
        o = ny_mesh(f"{namn}_skalm{sx}", sk, ram)
        o.location = (mitt.x + sx * (avst + 0.027), fram_y, mitt.z + 0.006)
        delar.append(o)
    bro = bmesh.new()
    bmesh.ops.create_cube(bro, size=1.0)
    for v in bro.verts:
        v.co = Vector((v.co.x * (avst * 2 - 0.05), v.co.y * 0.003, v.co.z * 0.003))
    o = ny_mesh(f"{namn}_glasbro", bro, ram)
    o.location = (mitt.x, fram_y, mitt.z + 0.008)
    delar.append(o)
    for d in delar:
        till_ben(d, rig, "head")
    return delar


def brosttext(rig, klader, rygg, text, namn, storlek=0.06, farg=(0.95, 0.95, 0.96)):
    """Text på bröstet (DevEd, tröjnummer), strax framför tröjans yta och följer bröstkorgen."""
    z = (rig.matrix_world @ rig.pose.bones["neck_01"].head).z - 0.15
    fram = min((klader.matrix_world @ v.co).y for v in klader.data.vertices if abs((klader.matrix_world @ v.co).x) < 0.04 and abs((klader.matrix_world @ v.co).z - z) < 0.02)
    o = textobjekt(text, storlek, material(f"{namn}_text", farg, 0.6), f"{namn}_brosttext")
    o.data.transform(Matrix.Rotation(math.radians(90) - math.radians(8), 4, "X"))
    o.location = (0.0, fram - 0.011, z)
    till_ben(o, rig, "spine_03")
    return o


def hudkopia(rig, kropp, grupper, farg, tjocklek, namn, rough=0.6):
    """Kopia av huden för en grupp ben (handske, armärm), lite utanför huden och med samma vikter."""
    o = kropp.copy()
    o.data = kropp.data.copy()
    o.name = namn
    bpy.context.collection.objects.link(o)
    idx = {o.vertex_groups[g].index for g in grupper if g in o.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(o.data)
    dl = bm.verts.layers.deform.active
    hjalp = {o.vertex_groups[g].index for g in ("HelperGeometry", "JointCubes") if g in o.vertex_groups}
    bort = [v for v in bm.verts if sum(v[dl].get(i, 0.0) for i in idx) < 0.5 or any(v[dl].get(i, 0.0) > 0.0 for i in hjalp)]
    bmesh.ops.delete(bm, geom=bort, context="VERTS")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * tjocklek
    bm.to_mesh(o.data)
    bm.free()
    o.data.materials.clear()
    o.data.materials.append(material(namn, farg, rough))
    for mod in list(o.modifiers):
        if mod.type != "ARMATURE":
            o.modifiers.remove(mod)
    return o


# ------------------------------------------------------------------ en person
def bygg(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    macro = {"gender": 1.0, "cupsize": 0.5, "firmness": 0.5, "race": {"caucasian": 1.0, "asian": 0.0, "african": 0.0}}
    macro.update(p["macro"])
    kropp = HS.create_human(macro_detail_dict=macro)
    # ansiktsformen läggs på före skelett och kläder, så att allt anpassas efter den
    for mal, varde in p.get("ansikte", {}).items():
        vag = os.path.join(MAL, mal + ".target.gz")
        if os.path.exists(vag):
            TS.load_target(kropp, vag, weight=varde)
        else:
            print("SAKNAS mål", mal)
    HS.set_character_skin(asset("skins", p["hud"], p["hud"] + ".mhmat"), kropp, skin_type="GAMEENGINE")
    rig = HS.add_builtin_rig(kropp, "game_engine")
    tillagg = {}
    for typ, vag in (
        ("Eyes", asset("eyes", "low-poly", "low-poly.mhclo")),
        ("Eyebrows", asset("eyebrows", "eyebrow001", "eyebrow001.mhclo")),
        ("Eyelashes", asset("eyelashes", "eyelashes01", "eyelashes01.mhclo")),
        ("Hair", asset("hair", p["har"], p["har"] + ".mhclo")),
    ):
        if os.path.exists(vag):
            tillagg[typ] = HS.add_mhclo_asset(vag, kropp, asset_type=typ, subdiv_levels=0, material_type="GAMEENGINE")
    klader = HS.add_mhclo_asset(asset("clothes", p["klader"], p["klader"] + ".mhclo"), kropp, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
    skor = HS.add_mhclo_asset(asset("clothes", "shoes02", "shoes02.mhclo"), kropp, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
    namn = p["namn"]
    # texturer: egna kopior, toning och omfärgning
    for img in egna_bilder(kropp, f"{namn}_", TEX["hud"]):
        tona(img, p["hudton"])
        if p.get("skagg"):
            skagg(kropp, img, p["skagg"])
    for typ in ("Hair", "Eyebrows"):
        if typ in tillagg:
            for img in egna_bilder(tillagg[typ], f"{namn}_", TEX["har"]):
                a = _pixlar(img)
                # håret: gråskala gånger hårfärgen (MPFB:s hår är mörkt, så ljusheten lyfts först)
                lum = a[..., :3].mean(-1, keepdims=True)
                a[..., :3] = np.clip(lum / max(float(np.percentile(lum[a[..., 3] > 0.3], 70)), 1e-3), 0, 1.4) * np.array(p["harfarg"], dtype=np.float32)
                _spara(img, a)
    for typ in ("Eyes", "Eyelashes"):
        if typ in tillagg:
            for img in egna_bilder(tillagg[typ], f"{namn}_", TEX["ovrigt"]):
                img.pack()
    for img in egna_bilder(klader, f"{namn}_", TEX["klader"]):
        if p["klader"] == "male_elegantsuit01":
            farga_kostym(img, p["troja"], p["slips"])
        else:
            farga_klader(img, p["klader"], p["troja"], p["byxor"])
            if p.get("ranor"):
                ranor(klader, img, p["klader"], p["ranor"])
    for img in egna_bilder(skor, f"{namn}_", TEX["ovrigt"]):
        img.pack()
    # kläderna en aning ut från huden, så att axlarna inte sticker igenom i sittande pose
    push = klader.modifiers.new("Avstånd från huden", "DISPLACE")
    push.strength = 0.004
    push.mid_level = 0.0
    sitt(rig)
    delar = [o for o in bpy.data.objects if o.type == "MESH"]
    pose_som_vila(rig, delar)
    bpy.context.view_layer.update()
    # egna delar
    har = tillagg.get("Hair")
    huvud_lo, huvud_hi = grupp_bbox(kropp, "head")
    bryn = tillagg.get("Eyebrows")
    bryn_z = obj_bbox(bryn)[1].z if bryn else huvud_lo.z + (huvud_hi.z - huvud_lo.z) * 0.62
    # kepsen mäts över ögonbrynen, där den sitter (inte över öronen)
    huvud_lo, huvud_hi = grupp_bbox(kropp, "head", z_min=bryn_z + 0.02)
    if har and p.get("keps"):
        # kepsen trycker ned håret: det som skulle sticka upp genom kupan tas bort, och bredden tas
        # från håret precis under kepsens kant (där håret syns)
        hlo, hhi = obj_bbox(har)
        # håret ger några millimeter
        huvud_lo = Vector((huvud_lo.x - 0.006, huvud_lo.y - 0.006, huvud_lo.z))
        huvud_hi = Vector((huvud_hi.x + 0.006, huvud_hi.y + 0.008, huvud_hi.z))
        bm = bmesh.new()
        bm.from_mesh(har.data)
        bort = [v for v in bm.verts if (har.matrix_world @ v.co).z > bryn_z + 0.04]
        bmesh.ops.delete(bm, geom=bort, context="VERTS")
        bm.to_mesh(har.data)
        bm.free()
    if har and p.get("klipp_lugg"):
        # luggen ska inte hänga ned över ögonen
        bm = bmesh.new()
        bm.from_mesh(har.data)
        fram_y = huvud_lo.y + 0.05
        bort = [v for v in bm.verts if (har.matrix_world @ v.co).z < bryn_z + p["klipp_lugg"] and (har.matrix_world @ v.co).y < fram_y]
        bmesh.ops.delete(bm, geom=bort, context="VERTS")
        bm.to_mesh(har.data)
        bm.free()
    if p.get("keps"):
        keps(rig, huvud_lo, huvud_hi, bryn_z, p["keps"], namn)
    if p.get("glasogon") and "Eyes" in tillagg:
        glasogon(rig, tillagg["Eyes"], huvud_lo, huvud_hi, namn)
    if p.get("text"):
        brosttext(rig, klader, None, p["text"], namn, p.get("textstorlek", 0.06), p.get("textfarg", (0.95, 0.95, 0.96)))
    if p.get("handske"):
        s = p["handske"]
        grupper = [f"hand_{s}"] + [f"{f}_{i:02d}_{s}" for f in ("index", "middle", "ring", "pinky", "thumb") for i in (1, 2, 3)]
        hudkopia(rig, kropp, grupper, (0.93, 0.7, 0.18), 0.0025, f"{namn}_handske", 0.75)
    if p.get("armarm"):
        s = p["armarm"]
        hudkopia(rig, kropp, [f"lowerarm_{s}", f"upperarm_{s}"], (0.07, 0.07, 0.08), 0.0018, f"{namn}_armarm", 0.45)
    rig.name = namn
    return rig


def exportera(rig):
    os.makedirs(UT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.select_set(True)
    fil = os.path.join(UT, rig.name.lower() + ".glb")
    bpy.ops.export_scene.gltf(filepath=fil, export_format="GLB", use_selection=True, export_apply=True,
                              export_animations=False, export_morph=False, export_yup=True,
                              export_image_format="AUTO", export_jpeg_quality=85)
    print("EXPORT", fil, round(os.path.getsize(fil) / 1e6, 2), "MB")


def provbild(rig):
    """Överkroppen framifrån, med enkelt studioljus, till blender/prov/<namn>.png."""
    os.makedirs(PROV, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = 700, 800
    sc.view_settings.view_transform = "Standard"  # närmare Godot än AgX, som gör mörka färger gråa
    world = bpy.data.worlds.new("Varld")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.45, 0.5, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    huvud = rig.matrix_world @ rig.pose.bones["head"].head
    for namn, pos, energi in (("Nyckel", (-1.2, -2.2, 2.6), 260), ("Fyll", (1.6, -1.8, 1.8), 90), ("Kant", (0.5, 2.0, 2.4), 160)):
        ld = bpy.data.lights.new(namn, "AREA")
        ld.energy = energi
        ld.size = 1.5
        lo = bpy.data.objects.new(namn, ld)
        sc.collection.objects.link(lo)
        lo.location = pos
        lo.rotation_euler = (Vector(huvud) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cd = bpy.data.cameras.new("Kamera")
    cd.lens = 70
    kam = bpy.data.objects.new("Kamera", cd)
    sc.collection.objects.link(kam)
    mal = Vector((huvud.x, huvud.y, huvud.z - 0.22))
    kam.location = mal + Vector((0.35, -2.3, 0.25))
    kam.rotation_euler = (mal - kam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = kam
    sc.render.filepath = os.path.join(PROV, rig.name.lower() + ".png")
    bpy.ops.render.render(write_still=True)
    print("PROV", sc.render.filepath)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    namn = [a for a in argv if not a.startswith("--")]
    for p in PERSONER:
        if namn and p["namn"] not in namn:
            continue
        rig = bygg(p)
        if "--prov" not in argv:
            exportera(rig)
        provbild(rig)
