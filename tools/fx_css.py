"""Transforme la feuille de style de la maquette pour l'intégrer au simulateur :
préfixe chaque sélecteur par .fx, renomme les classes qui existent déjà dans le simulateur,
renomme les animations, et retire les variantes non utilisées (B, C, D, E, X, Y, Z)."""
import re

KEEP = {"modal", "foc", "sx", "sy", "clock", "sel", "on", "play", "ready", "peek", "up", "dn", "cur", "hid", "paused", "danger", "add", "lg", "xl", "md", "sm", "xs", "ov", "h", "one", "neg", "me", "fx"}

def classes_in(css):
    return set(re.findall(r"\.([A-Za-z_][\w-]*)", re.sub(r"url\([^)]*\)|\d+\.\d+", "", css)))

def split_rules(css):
    """Renvoie une liste de (prelude, body) au niveau supérieur, en gardant les @blocs entiers."""
    out, i, n = [], 0, len(css)
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    n = len(css)
    while i < n:
        j = css.find("{", i)
        if j < 0: break
        pre = css[i:j].strip()
        depth, k = 1, j + 1
        while k < n and depth:
            if css[k] == "{": depth += 1
            elif css[k] == "}": depth -= 1
            k += 1
        out.append((pre, css[j + 1:k - 1]))
        i = k
    return out

def build(src_css, sim_css):
    sim = classes_in(sim_css)
    mine = classes_in(src_css)
    ren = {c: "fx-" + c for c in mine if c in sim and c not in KEEP}
    for c in [c for c in mine if c.startswith("f-")]:
        ren[c] = "fx-" + c
    kf = {}
    def rc(sel):
        return re.sub(r"\.([A-Za-z_][\w-]*)", lambda m: "." + ren.get(m.group(1), m.group(1)), sel)
    drop = re.compile(r"^\.(B|C|D|E|X|Y|Z)\b")
    parts = []
    for pre, body in split_rules(src_css):
        if pre.startswith("@keyframes"):
            name = pre.split()[1]
            kf[name] = "fx" + name
            parts.append(f"@keyframes fx{name}{{{body}}}")
            continue
        if pre.startswith("@media"):
            continue
        sels = []
        for sel in pre.split(","):
            sel = sel.strip()
            if not sel or drop.match(sel): continue
            sel = sel.replace("#tv.nosmooth", "").replace("#tv *", "*")
            if sel == "*": sels.append(".fx *"); continue
            if not sel: continue
            sels.append(".fx " + rc(sel))
        if sels:
            parts.append(",".join(sels) + "{" + body + "}")
    out = "\n".join(parts)
    for a, b in kf.items():
        out = re.sub(r"(animation(?:-name)?:\s*[^;{}]*?)\b" + re.escape(a) + r"\b", lambda m: m.group(1) + b, out)
    return out, ren
