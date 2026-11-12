"""Construit la MAQUETTE de la refonte premium de PRISME à partir du simulateur.

Le simulateur d'origine n'est pas modifié : on lit simulateur-appletv.html et on écrit un autre fichier.
Seul le style change (couleurs, logo officiel, focus, verre). Le code des écrans, de la navigation,
des données et du lecteur est copié à l'identique.

Dans la maquette, le bouton « Voir le design actuel » (ou la touche D) rebascule sur le style d'origine,
pour comparer écran par écran.
"""
import base64, os, re, sys
D = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(D, "simulateur-appletv.html")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(D, "maquette-premium.html")
html = open(SRC, encoding="utf-8").read()

# Palette d'origine -> palette PRISME (uniquement dans les feuilles de style)
HEX = {
 "#fff": "#F5F6FA", "#ffffff": "#F5F6FA", "#eef0f5": "#F5F6FA", "#e6e8ee": "#F5F6FA", "#000": "#08090D",
 "#111318": "#10121A", "#111": "#10121A", "#14161d": "#10121A",
 "#07080b": "#08090D", "#0a0b0f": "#08090D", "#05060a": "#08090D", "#050608": "#08090D", "#0b0d13": "#08090D", "#0b0c10": "#08090D", "#0f1013": "#08090D",
 "#1d2029": "#171A24", "#1b1e27": "#171A24", "#1d1e22": "#171A24",
 "#2c303b": "#202431", "#2a2e39": "#202431", "#232733": "#202431", "#2a2b30": "#202431",
 "#8b90a0": "#9298A8", "#9aa0ad": "#9298A8",
 "#0a84ff": "#168BFF", "#4ea1ff": "#168BFF", "#60a5fa": "#168BFF", "#3b82f6": "#168BFF", "#7cc4ff": "#36D5F2",
 "#5ee0c8": "#36D5F2", "#7dd3fc": "#36D5F2", "#5ac8fa": "#36D5F2",
 "#bf5af2": "#8657FF", "#a78bfa": "#8657FF", "#b48cff": "#8657FF", "#7a8bff": "#8657FF",
 "#ff375f": "#D34BCE", "#ff6b9a": "#D34BCE", "#f472b6": "#D34BCE",
 "#ff9f0a": "#FF9B45", "#f59e0b": "#FF9B45", "#ffb35c": "#FF9B45", "#ffb340": "#FF9B45", "#ffd36b": "#FF9B45",
}
RGB = {
 "4,5,8": "8,9,13", "8,9,14": "8,9,13", "6,7,10": "8,9,13", "6,8,14": "8,9,13", "10,11,15": "8,9,13", "10,12,18": "16,18,26", "11,13,19": "16,18,26", "12,14,20": "16,18,26",
 "30,33,44": "23,26,36", "28,31,42": "23,26,36", "30,32,40": "23,26,36", "28,30,38": "23,26,36", "25,27,36": "23,26,36", "22,24,31": "23,26,36", "22,24,30": "23,26,36",
 "22,24,32": "23,26,36", "20,22,28": "23,26,36", "20,22,30": "23,26,36", "14,16,24": "16,18,26",
 "40,42,52": "32,36,49", "40,42,54": "32,36,49", "40,40,48": "32,36,49", "36,36,44": "32,36,49", "30,30,38": "32,36,49",
 "78,161,255": "22,139,255", "94,224,200": "54,213,242",
 "180,140,255": "134,87,255", "191,90,242": "134,87,255", "175,82,222": "134,87,255", "120,140,255": "134,87,255",
 "255,107,154": "211,75,206", "236,72,153": "211,75,206",
 "245,158,11": "255,155,69", "255,120,60": "255,155,69", "255,211,107": "255,155,69",
}
HALO = "0 14px 38px -12px rgba(22,139,255,.75),0 0 34px -6px rgba(134,87,255,.6),0 0 52px -14px rgba(211,75,206,.55)"

def recolor(css):
    css = re.sub(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b", lambda m: HEX.get(m.group(0).lower(), m.group(0)), css)
    css = re.sub(r"rgba?\(\s*(\d+),\s*(\d+),\s*(\d+)", lambda m: m.group(0).split("(")[0] + "(" + RGB.get(f"{m.group(1)},{m.group(2)},{m.group(3)}", f"{m.group(1)},{m.group(2)},{m.group(3)}"), css)
    # Focus : on garde la sélection claire de tvOS et on ajoute un halo prismatique doux
    def foc(m):
        sel, body = m.group(1), m.group(2)
        if ".foc" not in sel or "@" in sel:
            return m.group(0)
        white = re.search(r"background:(#F5F6FA|rgba\(255,255,255,\.9)", body)
        bs = re.search(r"box-shadow:([^;}]+)", body)
        if bs and "none" not in bs.group(1):
            body = body.replace(bs.group(0), "box-shadow:" + bs.group(1).replace("!important", "") + "," + HALO + ("!important" if "!important" in bs.group(1) else ""))
        elif white:
            body = body.rstrip(";") + ";box-shadow:" + HALO
        return sel + "{" + body + "}"
    css = re.sub(r"([^{}@]+)\{([^{}]*)\}", foc, css)
    return css

blocks = list(re.finditer(r"<style>(.*?)</style>", html, re.S))
assert blocks, "pas de feuille de style"
b64 = lambda n: "data:image/png;base64," + base64.b64encode(open(os.path.join(D, "assets", n), "rb").read()).decode()
L192, L512 = b64("logo-prisme-192.png"), b64("logo-prisme-512.png")
theme = open(os.path.join(D, "prisme_theme.css"), encoding="utf-8").read().replace("LOGO_192", L192).replace("LOGO_512", L512)

out, pos = [], 0
for m in blocks:
    out.append(html[pos:m.start()])
    css = m.group(1)
    # design actuel (désactivé) + design premium (actif) : le bouton de comparaison bascule entre les deux
    out.append(f'<style data-design="actuel" media="not all">{css}</style><style data-design="premium">{recolor(css)}</style>')
    pos = m.end()
out.append(html[pos:])
html = "".join(out)
k = html.rindex('<style data-design="premium">')
k = html.index("</style>", k) + len("</style>")
html = html[:k] + f'<style data-design="premium" id="prismeTheme">{theme}</style>' + html[k:]

def R(a, b):
    global html
    assert html.count(a) == 1, (html.count(a), a[:80])
    html = html.replace(a, b)

R("<title>Simulateur Prisme Apple TV</title>", "<title>Maquette PRISME premium</title>")
R("<h1>Simulateur prisme · Apple TV</h1>",
  f'<h1><img src="{L192}" alt="">Maquette PRISME · refonte premium <button class="ptog" id="ptog" type="button" title="Touche D">Voir le design actuel</button></h1>')
R("<p>Données de démonstration · aucun flux réel n'est lu · cible : Apple TV 4K, tvOS</p>",
  "<p>Maquette utilisable · mêmes écrans et mêmes fonctions que le simulateur · seul le style change · touche D pour comparer</p>")
TOG = r'''<script>
(function(){let premium=true;const b=document.getElementById("ptog");
function apply(){document.querySelectorAll("style[data-design]").forEach(s=>{const on=(s.dataset.design==="premium")===premium;if(on)s.removeAttribute("media");else s.setAttribute("media","not all")});
 b.innerHTML=premium?"Voir le design actuel":"Revenir à la <b>maquette premium</b>";document.title=premium?"Maquette PRISME premium":"PRISME · design actuel"}
b.addEventListener("click",e=>{premium=!premium;apply();b.blur()});
document.addEventListener("keydown",e=>{if((e.key==="d"||e.key==="D")&&!e.metaKey&&!e.ctrlKey&&!(e.target&&/INPUT|TEXTAREA/.test(e.target.tagName))){premium=!premium;apply()}},true);
})();
</script>
'''
html = html + TOG
open(OUT, "w", encoding="utf-8").write(html)
print("OK", OUT, len(html.encode()) // 1024, "Ko")
