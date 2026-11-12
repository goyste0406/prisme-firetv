#!/usr/bin/env python3
"""Rend le JavaScript d'une page générée lisible par les vieux Safari (ES2019 : sans ?. ni ??).
Usage : compat.py fichier.html  (réécrit le fichier en place)"""
import re, subprocess, sys
ESB = "/opt/npm-tools/node_modules/.bin/esbuild"
p = sys.argv[1]
h = open(p, encoding="utf-8").read()
def fix(m):
    code = m.group(2)
    if not code.strip(): return m.group(0)
    r = subprocess.run([ESB, "--target=es2019", "--loader=js"], input=code, capture_output=True, text=True)
    if r.returncode: sys.exit("esbuild: " + r.stderr[:500])
    return m.group(1) + r.stdout + "</script>"
h2 = re.sub(r"(<script[^>]*>)([\s\S]*?)</script>", fix, h)
open(p, "w", encoding="utf-8").write(h2)
print("compat ok", len(h), "->", len(h2))
