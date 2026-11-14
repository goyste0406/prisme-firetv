#!/usr/bin/env python3
"""Faux fournisseur Xtream + fausse TMDB, pour tester la vraie app prisme dans le simulateur Apple TV
de la compilation en ligne. Données inventées POUR LES TESTS UNIQUEMENT (jamais livrées dans l'app).
Lancement : python3 ci/fake_server.py 8099
"""
import http.server, json, sys, time, random, hashlib, io, os, re, urllib.parse
from functools import lru_cache

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
BASE = f"http://127.0.0.1:{PORT}"
NOW = int(time.time())
DAY = 86400

try:
    from PIL import Image, ImageDraw, ImageFont
except Exception:  # pragma: no cover
    Image = None

# ---------------------------------------------------------------- données
GENRES_F = ["Action", "Aventure", "Animation", "Comédie", "Crime", "Drame", "Familial", "Fantastique", "Horreur", "Romance", "Science-Fiction", "Thriller", "Documentaire"]
FILMS = [
    # (titre, année, durée, note, genres, collection, ajouté il y a N jours)
    ("Dune : Deuxième partie", 2024, 166, 8.2, ["Science-Fiction", "Aventure"], (501, "Dune - Saga"), 6),
    ("Dune", 2021, 155, 7.8, ["Science-Fiction", "Aventure"], (501, "Dune - Saga"), 40),
    ("Oppenheimer", 2023, 180, 8.1, ["Drame", "Histoire"], None, 7),
    ("Le Comte de Monte-Cristo", 2024, 178, 8.0, ["Aventure", "Drame"], None, 5),
    ("Un p'tit truc en plus", 2024, 99, 7.4, ["Comédie"], None, 1),
    ("Barbie", 2023, 114, 7.0, ["Comédie", "Aventure"], None, 0),
    ("Inception", 2010, 148, 8.4, ["Science-Fiction", "Action"], None, 90),
    ("Intouchables", 2011, 112, 8.3, ["Comédie", "Drame"], None, 120),
    ("La La Land", 2016, 128, 7.9, ["Romance", "Drame"], None, 60),
    ("Le Fabuleux Destin d'Amélie Poulain", 2001, 122, 7.9, ["Comédie", "Romance"], None, 200),
    ("La Haine", 1995, 98, 8.0, ["Drame", "Crime"], None, 300),
    ("Drive", 2011, 100, 7.6, ["Crime", "Thriller"], None, 150),
    ("Spider-Man : No Way Home", 2021, 148, 7.9, ["Action", "Aventure"], (502, "Spider-Man - Saga"), 30),
    ("Spider-Man : Far From Home", 2019, 129, 7.4, ["Action", "Aventure"], (502, "Spider-Man - Saga"), 31),
    ("Spider-Man : Homecoming", 2017, 133, 7.3, ["Action", "Aventure"], (502, "Spider-Man - Saga"), 32),
    ("Top Gun : Maverick", 2022, 131, 8.2, ["Action", "Drame"], None, 20),
    ("Interstellar", 2014, 169, 8.4, ["Science-Fiction", "Drame"], None, 400),
    ("Gladiator II", 2024, 148, 6.8, ["Action", "Aventure"], None, 3),
    ("Vice-Versa 2", 2024, 96, 7.6, ["Animation", "Familial"], (503, "Vice-Versa - Saga"), 2),
    ("Vice-Versa", 2015, 95, 7.9, ["Animation", "Familial"], (503, "Vice-Versa - Saga"), 500),
    ("Le Parrain", 1972, 175, 8.7, ["Drame", "Crime"], None, 800),
    ("Parasite", 2019, 132, 8.5, ["Thriller", "Drame"], None, 250),
    ("Joker", 2019, 122, 8.1, ["Crime", "Thriller"], None, 260),
    ("Les Trois Mousquetaires : D'Artagnan", 2023, 121, 6.9, ["Aventure", "Action"], None, 70),
    ("Anatomie d'une chute", 2023, 151, 7.7, ["Thriller", "Drame"], None, 50),
    ("Le Règne animal", 2023, 128, 7.1, ["Science-Fiction", "Drame"], None, 55),
    ("Avatar : La Voie de l'eau", 2022, 192, 7.6, ["Science-Fiction", "Aventure"], None, 100),
    ("Mission: Impossible - Dead Reckoning", 2023, 163, 7.5, ["Action", "Thriller"], None, 80),
    ("Conjuring : Sous l'emprise du diable", 2021, 112, 6.6, ["Horreur", "Thriller"], None, 140),
    ("Le Roi Lion", 1994, 89, 8.3, ["Animation", "Familial"], None, 900),
    ("Projet dernière chance", 2026, 156, 8.1, ["Science-Fiction", "Aventure"], None, 2),
    # sagas / univers : vrais liens (collection, mot-clé de franchise TMDB) et faux amis (titres proches, remake homonyme)
    ("Wonder Woman", 2017, 141, 7.2, ["Action", "Aventure", "Fantastique"], (468552, "Wonder Woman - Saga"), 45),
    ("Wonder", 2017, 113, 8.1, ["Drame", "Familial"], None, 46),
    ("Aquaman", 2018, 143, 6.9, ["Action", "Aventure", "Fantastique"], (573693, "Aquaman - Saga"), 47),
    ("Wonder Wheel", 2017, 101, 6.2, ["Drame", "Romance"], None, 48),
    ("Dune", 1984, 137, 6.3, ["Science-Fiction", "Aventure"], None, 49),
]
KW = {"Wonder Woman": [(229266, "dc extended universe (dceu)"), (9715, "superhero")], "Aquaman": [(229266, "dc extended universe (dceu)"), (9715, "superhero")],
      "Spider-Man : No Way Home": [(180547, "marvel cinematic universe (mcu)"), (9715, "superhero")], "Spider-Man : Far From Home": [(180547, "marvel cinematic universe (mcu)"), (9715, "superhero")],
      "Spider-Man : Homecoming": [(180547, "marvel cinematic universe (mcu)"), (9715, "superhero")], "Wonder": [(818, "based on novel or book")],
      "Dune": [(3386, "space opera"), (818, "based on novel or book")], "Dune : Deuxième partie": [(3386, "space opera")]}
# mêmes films sous d'autres noms chez le fournisseur (test du dédoublonnage par identifiant TMDB)
EXTRA_VOD = [(1901, 16, "FR| Interstellaire (2014) MULTI"), (1902, 16, "EN| Interstellar 4K"), (1903, 16, "Interstellar 2014 VOSTFR")]
ALIASES = {"interstellaire": 16}
# vraie bande-annonce de l'iTunes Store (le simulateur de test a Internet) : sert à tester la lecture dans l'app
APPLE_PREVIEW = "https://video-ssl.itunes.apple.com/itunes-assets/Video111/v4/54/b7/37/54b737f0-63c2-77ed-44b3-4f7e2d34f386/mzvf_806821658861734960.640x354.h264lc.U.p.m4v"
SERIES = [
    # (titre, année, note, genres, saisons, épisodes par saison, durée, ajouté il y a N jours)
    ("Engrenages", 2005, 8.2, ["Crime", "Drame"], 8, 10, 52, 3),
    ("Lupin", 2021, 7.5, ["Crime", "Mystère"], 3, 5, 45, 1),
    ("HPI", 2021, 7.3, ["Comédie", "Crime"], 4, 8, 52, 2),
    ("Stranger Things", 2016, 8.6, ["Science-Fiction & Fantastique", "Drame"], 4, 9, 55, 6),
    ("Peaky Blinders", 2013, 8.5, ["Crime", "Drame"], 6, 6, 58, 30),
    ("Succession", 2018, 8.4, ["Drame"], 4, 10, 60, 45),
    ("Le Bureau des légendes", 2015, 8.3, ["Drame", "Crime"], 5, 10, 52, 60),
    ("The Office", 2005, 8.5, ["Comédie"], 9, 22, 22, 90),
    ("Dix pour cent", 2015, 7.9, ["Comédie", "Drame"], 4, 6, 52, 100),
    ("Breaking Bad", 2008, 8.9, ["Drame", "Crime"], 5, 13, 47, 200),
    ("The Crown", 2016, 8.2, ["Drame"], 6, 10, 58, 120),
    ("Arcane", 2021, 8.7, ["Animation", "Science-Fiction & Fantastique"], 2, 9, 40, 4),
]
CHANNELS = [
    # (nom chez le fournisseur, catégorie, epg)
    ("FR| TF1 FHD", "1", "tf1.fr"), ("FR| TF1 HD", "1", "tf1.fr"), ("FR| France 2 FHD", "1", "france2.fr"), ("FR| France 3", "1", "france3.fr"),
    ("FR| Canal+ FHD", "1", "canalplus.fr"), ("FR| France 5", "1", "france5.fr"), ("FR| M6 FHD", "1", "m6.fr"), ("FR| Arte HD", "1", "arte.fr"),
    ("FR| C8", "1", "c8.fr"), ("FR| W9", "1", "w9.fr"), ("FR| TMC", "1", "tmc.fr"), ("FR| TFX", "1", "tfx.fr"),
    ("FR| 6ter", "1", "6ter.fr"), ("FR| TF1 Séries Films", "1", "tf1sf.fr"),
    ("FR| BFM TV", "2", "bfmtv.fr"), ("FR| CNews", "2", "cnews.fr"), ("FR| LCI", "2", "lci.fr"), ("FR| franceinfo", "2", "franceinfo.fr"),
    ("FR| Canal+ Sport", "3", "canalsport.fr"), ("FR| beIN Sports 1", "3", "bein1.fr"), ("FR| Eurosport 1", "3", "eurosport1.fr"), ("FR| L'Équipe", "3", "lequipe.fr"),
    ("FR| Gulli", "4", "gulli.fr"), ("FR| Disney Channel", "4", "disney.fr"), ("FR| Canal J", "4", "canalj.fr"),
    ("FR| OCS Max", "5", "ocsmax.fr"), ("FR| Ciné+ Premier", "5", "cinepremier.fr"), ("FR| TCM Cinéma", "5", "tcm.fr"),
    ("FR| M6 HD", "6", "m6.fr"), ("FR| France 2 HD", "6", "france2.fr"),
]
# Liste réaliste (format des fournisseurs) pour vérifier la classification et les doublons de la TV en direct :
# copies FHD/HD/HEVC/secours (parfois sans guide), +1, régions, autres pays, chaînes inconnues.
def _x(cat, names, epg=True):
    return [(n, cat, (re.sub(r"[^a-z0-9]", "", re.sub(r"^(FR|BE|UK)\| ", "", n).lower()) + ".x") if epg else "") for n in names]
CHANNELS += _x("1", ["FR| TF1 HEVC", "FR| TF1 4K", "FR| TF1 +1", "FR| France 3 Alsace", "FR| France 3 Paris Île-de-France", "FR| France 4", "FR| RMC Story", "FR| RMC Découverte",
                     "FR| Chérie 25", "FR| LCP", "FR| T18", "FR| Novo19", "FR| NRJ 12", "FR| CStar", "FR| Paris Première"])
CHANNELS += _x("1", ["FR| TF1 (Backup)", "FR| France 2 SD", "|FR| M6 ᴴᴰ"], epg=False)
CHANNELS += _x("2", ["FR| France 24", "FR| Euronews", "FR| i24NEWS", "FR| BFM Business", "FR| Public Sénat", "FR| TV5Monde Info", "FR| BFM Paris", "FR| LCI FHD"])
CHANNELS += _x("7", ["FR| RMC Sport 1", "FR| RMC Sport 2", "FR| beIN SPORTS 2", "FR| beIN SPORTS 3", "FR| beIN SPORTS MAX 4", "FR| Eurosport 2", "FR| Canal+ Foot", "FR| Canal+ Sport 360",
                     "FR| Equidia", "FR| Automoto", "FR| Golf+", "FR| Infosport+", "FR| Sport en France", "FR| Multisports 1", "FR| DAZN 1", "FR| Ligue 1+ 1", "FR| OL Play", "FR| Trace Sport Stars"])
CHANNELS += _x("8", ["FR| Ciné+ Frisson", "FR| Ciné+ Émotion", "FR| Ciné+ Famiz", "FR| Ciné+ Classic", "FR| OCS City", "FR| OCS Choc", "FR| OCS Géants", "FR| Paramount Channel", "FR| Warner TV",
                     "FR| Action", "FR| Polar+", "FR| RTL9", "FR| Canal+ Cinéma(s)", "FR| Canal+ Grand Écran", "FR| Série Club", "FR| 13ème Rue", "FR| Syfy", "FR| Téva", "FR| AB1",
                     "FR| Novelas TV", "FR| Canal+ Séries", "FR| Comédie+", "FR| Sundance TV"])
CHANNELS += _x("9", ["FR| Planète+", "FR| Planète+ Crime", "FR| Ushuaïa TV", "FR| National Geographic", "FR| Nat Geo Wild", "FR| Discovery Channel", "FR| Histoire TV", "FR| Toute l'Histoire",
                     "FR| Animaux", "FR| Science & Vie TV", "FR| Voyage", "FR| Trek", "FR| Seasons", "FR| Chasse et Pêche", "FR| Museum TV", "FR| Canal+ Docs"])
CHANNELS += _x("10", ["FR| MTV Hits", "FR| MCM", "FR| NRJ Hits", "FR| M6 Music", "FR| Trace Urban", "FR| Mezzo", "FR| Melody", "FR| RFM TV", "FR| Clubbing TV", "FR| Mezzo Live HD"])
CHANNELS += _x("11", ["FR| Tiji", "FR| Disney Junior", "FR| Nickelodeon", "FR| Nickelodeon Junior", "FR| Cartoon Network", "FR| Cartoonito", "FR| Boomerang", "FR| Piwi+", "FR| Télétoon+",
                      "FR| Boing", "FR| Mangas", "FR| Canal+ Kids", "FR| Okoo"])
CHANNELS += _x("12", ["FR| Tébéo", "FR| TV Rennes", "FR| Vosges Télévision", "FR| Wéo", "FR| BFM Lyon", "FR| France 3 Bretagne", "FR| France 3 Corse ViaStella"])
CHANNELS += _x("13", ["UK| BBC One", "UK| BBC Two", "UK| ITV 1", "UK| Sky Sports Main Event", "UK| Sky Cinema Premiere", "UK| Sky News", "UK| Discovery Channel"])
CHANNELS += _x("14", ["BE| TF1", "BE| La Une", "BE| RTL TVI", "BE| Tipik", "BE| LN24", "BE| Club RTL"])
CHANNELS += _x("15", ["FR| TF1 UHD", "FR| France 2 UHD", "FR| beIN SPORTS 1 4K", "FR| Canal+ 4K"])
CHANNELS += _x("16", ["FR| Game One", "FR| J-One", "FR| RMC Life", "FR| Gong", "FR| TLC", "FR| Fashion TV", "FR| E! Entertainment", "FR| Comedy Central"])
CHANNELS += _x("1", ["FR| Kombat Sport", "FR| Le Grand Show", "FR| Alpha TV"])
LIVE_CATS = [("1", "FR| TNT"), ("2", "FR| INFOS"), ("3", "FR| SPORT"), ("4", "FR| JEUNESSE"), ("5", "FR| CINÉMA"), ("6", "FR| TNT HD (SECOURS)"),
             ("7", "FR| SPORTS"), ("8", "FR| CINEMA & SERIES"), ("9", "FR| DOCUMENTAIRES"), ("10", "FR| MUSIQUE"), ("11", "FR| ENFANTS"), ("12", "FR| REGIONS"),
             ("13", "UK| GENERAL"), ("14", "BE| BELGIQUE"), ("15", "FR| 4K UHD"), ("16", "FR| DIVERTISSEMENT")]
VOD_CATS = [("10", "FR| NOUVEAUTÉS"), ("11", "FR| FILMS NETFLIX"), ("12", "FR| FILMS CLASSIQUES"), ("13", "FR| DISNEY+")]
SER_CATS = [("20", "FR| SÉRIES FRANÇAISES"), ("21", "FR| SÉRIES NETFLIX"), ("22", "FR| SÉRIES HBO")]
PROG_CAT = {"Le 20h": "Journal", "Journal de 13h": "Journal", "Météo": "Météo", "C dans l'air": "Magazine d'actualité", "Koh-Lanta": "Téléréalité",
            "Des chiffres et des lettres": "Jeu", "Questions pour un champion": "Jeu", "Top Chef": "Divertissement", "Zone interdite": "Magazine", "Quotidien": "Talk-show",
            "Le Grand Match": "Sport", "Ligue des champions": "Football", "Football : Ligue 1": "Football", "Rugby : Top 14": "Rugby", "Bob l'éponge": "Dessin animé",
            "Les Simpson": "Dessin animé", "Capital": "Magazine", "Envoyé spécial": "Magazine d'information", "Thalassa": "Documentaire", "Cash Investigation": "Magazine d'information",
            "Le Bureau des légendes": "Série dramatique", "Dune": "Film", "Inception": "Film"}
PROGS = ["Le 20h", "Koh-Lanta", "Journal de 13h", "Des chiffres et des lettres", "Questions pour un champion", "Top Chef", "Zone interdite",
         "C dans l'air", "Quotidien", "Le Grand Match", "Ligue des champions", "Bob l'éponge", "Les Simpson", "Météo", "Capital",
         "Envoyé spécial", "Thalassa", "Cash Investigation", "Le Bureau des légendes", "Dune", "Inception", "Football : Ligue 1", "Rugby : Top 14"]

def fid(i): return 1000 + i
def sid(i): return 2000 + i

# ---------------------------------------------------------------- images (générées, avec le titre comme une vraie affiche)
def color_for(s):
    h = int(hashlib.md5(s.encode()).hexdigest()[:6], 16)
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)

@lru_cache(maxsize=512)
def make_png(kind, key, w, h, label):
    if Image is None:
        return b""
    if kind == "g":  # logo de titre / de studio : texte blanc sur fond transparent
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Black.ttf", max(18, h // 3))
        except Exception:
            font = ImageFont.load_default()
        txt = (label or key).upper()[:22]
        tw = d.textlength(txt, font=font)
        d.text(((w - tw) / 2, h * 0.3), txt, font=font, fill=color_for(key) + (255,))
        out = io.BytesIO(); img.save(out, "PNG"); return out.getvalue()
    c = color_for(key)
    img = Image.new("RGB", (w, h), c)
    d = ImageDraw.Draw(img)
    for y in range(h):  # dégradé vertical
        k = y / h
        d.line([(0, y), (w, y)], fill=(int(c[0] * (1 - k * 0.8)), int(c[1] * (1 - k * 0.8)), int(c[2] * (1 - k * 0.8))))
    for i in range(6):  # quelques formes pour juger la netteté
        r = random.Random(key + str(i))
        x, y, s = r.randint(0, w), r.randint(0, h), r.randint(w // 10, w // 3)
        d.ellipse([x - s, y - s, x + s, y + s], outline=(255, 255, 255), width=max(2, w // 300))
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", max(18, w // (9 if kind == "p" else 22)))
    except Exception:
        font = ImageFont.load_default()
    if label:
        words, lines, cur = label.split(), [], ""
        for wd in words:
            t = (cur + " " + wd).strip()
            if d.textlength(t, font=font) > w * 0.86 and cur:
                lines.append(cur); cur = wd
            else:
                cur = t
        lines.append(cur)
        y = h * (0.62 if kind == "p" else 0.4)
        for ln in lines[:4]:
            d.text((w * 0.07, y), ln, font=font, fill=(255, 255, 255))
            y += font.size * 1.15
    out = io.BytesIO(); img.save(out, "PNG"); return out.getvalue()

def img_url(kind, key, label=""):
    return f"{BASE}/gen/{kind}/{urllib.parse.quote(key)}.png?l={urllib.parse.quote(label)}"

def tmdb_path(kind, key):  # chemin relatif TMDB, servi par /img/t/p/<taille>/<kind>/<key>.png
    return f"/{kind}/{key}.png"

# ---------------------------------------------------------------- Xtream
def live_streams():
    out = []
    for i, (n, c, e) in enumerate(CHANNELS):
        clean = re.sub(r"^FR\| ", "", re.sub(r" (FHD|HD)$", "", n))
        out.append({"num": i + 1, "name": n, "stream_id": 300 + i, "stream_icon": img_url("l", clean, clean), "epg_channel_id": e,
                    "category_id": c, "tv_archive": 1 if i % 3 == 0 else 0, "tv_archive_duration": 3 if i % 3 == 0 else 0})
    return out

def vod_streams():
    out = []
    for i, (t, y, rt, v, g, col, ago) in enumerate(FILMS):
        cat = "10" if ago < 14 else ("11" if i % 3 == 0 else ("13" if "Animation" in g else "12"))
        q = " 4K" if i % 4 == 0 else (" FHD" if i % 2 else "")
        out.append({"num": i + 1, "name": f"FR| {t} ({y}){q}", "stream_id": fid(i), "stream_icon": img_url("p", f"m{fid(i)}", t),
                    "rating": str(round(v, 1)), "added": str(NOW - ago * DAY - 3600), "category_id": cat, "container_extension": "mkv",
                    "tmdb": "" if i % 2 else str(fid(i))})
    for vid, i, name in EXTRA_VOD:
        t, y, rt, v, g, col, ago = FILMS[i]
        out.append({"num": vid, "name": name, "stream_id": vid, "stream_icon": img_url("p", f"m{fid(i)}", t), "rating": str(v),
                    "added": str(NOW - ago * DAY), "category_id": "12", "container_extension": "mkv", "tmdb": str(fid(i))})
    return out

# Lupin : la version principale n'a pas S2E4 (complété depuis la version VOSTFR) ; aucune n'a S3E2 (« manquant »)
LUPIN_ALT = 2900
HOLES = {2001: {(2, 4), (3, 2)}, LUPIN_ALT: {(3, 2)}}

def series_list():
    out = []
    for i, (t, y, v, g, ns, ne, rt, ago) in enumerate(SERIES):
        cat = "20" if i in (0, 1, 2, 6, 8) else ("21" if i in (3, 9) else "22")
        out.append({"num": i + 1, "name": f"FR| {t} ({y})", "series_id": sid(i), "cover": img_url("p", f"s{sid(i)}", t), "plot": f"{t} : résumé de la série.",
                    "releaseDate": f"{y}-01-01", "rating": str(v), "last_modified": str(NOW - ago * DAY - 7200), "category_id": cat, "tmdb": str(sid(i))})
    out.append({"num": 99, "name": "FR| Lupin (2021) VOSTFR", "series_id": LUPIN_ALT, "cover": img_url("p", "s2001", "Lupin"), "plot": "Lupin : résumé de la série.",
                "releaseDate": "2021-01-01", "rating": "7.5", "last_modified": str(NOW - 400 * DAY), "category_id": "22", "tmdb": "2001"})
    return out

def vod_info(vid):
    i = next((x[1] for x in EXTRA_VOD if x[0] == vid), vid - 1000)
    t, y, rt, v, g, col, ago = FILMS[i]
    return {"info": {"plot": f"{t} : résumé fourni par le fournisseur.", "cast": "Timothée Chalamet, Zendaya, Rebecca Ferguson, Javier Bardem",
                     "director": "Denis Villeneuve", "genre": ", ".join(g), "duration": f"{rt // 60:02d}:{rt % 60:02d}:00", "duration_secs": rt * 60,
                     "backdrop_path": [img_url("b", f"m{vid}", "")], "youtube_trailer": "dQw4w9WgXcQ", "tmdb_id": str(vid),
                     "releasedate": f"{y}-03-01", "rating": str(v), "country": "France", "age": "12+"},
            "movie_data": {"stream_id": vid, "container_extension": "mkv"}}

def series_info(sidv):
    i = 1 if sidv == LUPIN_ALT else sidv - 2000
    t, y, v, g, ns, ne, rt, ago = SERIES[i]
    eps = {}
    holes = HOLES.get(sidv, set())
    for s in range(1, ns + 1):
        eps[str(s)] = [{"id": f"{sidv}{s:02d}{e:02d}", "episode_num": e, "title": f"{t} - S{s:02d}E{e:02d} - Épisode {e}", "container_extension": "mkv", "season": s,
                        "info": {"plot": f"Épisode {e} de la saison {s}.", "movie_image": img_url("b", f"e{sidv}{s}{e}", ""), "duration": f"00:{rt}:00",
                                 "duration_secs": rt * 60, "rating": str(round(7.2 + ((s * 7 + e * 5) % 22) / 10, 1))},
                        # les 2 derniers épisodes de la dernière saison sont arrivés il y a 2 jours (« nouveau »), les autres il y a longtemps
                        "added": str(NOW - (2 if s == ns and e > ne - 2 else 200) * DAY)} for e in range(1, ne + 1) if (s, e) not in holes]
    return {"info": {"name": t, "plot": f"{t} : résumé fourni par le fournisseur.", "cast": "Omar Sy, Ludivine Sagnier, Clotilde Hesme",
                     "director": "George Kay", "genre": ", ".join(g), "backdrop_path": [img_url("b", f"s{sidv}", "")], "rating": str(v),
                     "releaseDate": f"{y}-01-01", "episode_run_time": str(rt), "youtube_trailer": "dQw4w9WgXcQ", "tmdb": str(sidv)},
            "episodes": eps}

def xmltv():
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', "<tv>"]
    seen = set()
    for n, c, e in CHANNELS:
        if not e or e in seen: continue
        seen.add(e)
        lines.append(f'<channel id="{e}"><display-name>{e}</display-name></channel>')
        r = random.Random(e)
        t = NOW - 6 * 3600 - r.randint(0, 3000)
        while t < NOW + 20 * 3600:
            d = r.choice([30, 45, 60, 90, 110])
            a = time.strftime("%Y%m%d%H%M%S +0000", time.gmtime(t)); b = time.strftime("%Y%m%d%H%M%S +0000", time.gmtime(t + d * 60))
            title = r.choice(PROGS)
            cat = PROG_CAT.get(title, "")
            ct = f'<category lang="fr">{cat}</category>' if cat else ""
            lines.append(f'<programme start="{a}" stop="{b}" channel="{e}"><title>{title}</title><desc>{title} : description.</desc>{ct}</programme>')
            t += d * 60
    lines.append("</tv>")
    return "\n".join(lines)

# ---------------------------------------------------------------- TMDB
PROV = [("Netflix", "nf"), ("Disney Plus", "dp"), ("Canal+", "cp"), ("Amazon Prime Video", "pv"), ("Apple TV", "atv"), ("Max", "mx")]

def providers_for(key):
    r = random.Random(key)
    pick = lambda n: [{"provider_name": p, "logo_path": tmdb_path("o", k)} for p, k in r.sample(PROV, n)]
    return {"results": {"FR": {"flatrate": pick(r.randint(0, 2)), "rent": pick(r.randint(0, 2)), "buy": pick(r.randint(0, 2))}}}

CAST = [("Timothée Chalamet", "Paul Atréides"), ("Zendaya", "Chani"), ("Rebecca Ferguson", "Jessica"), ("Javier Bardem", "Stilgar"),
        ("Austin Butler", "Feyd-Rautha"), ("Florence Pugh", "Irulan"), ("Omar Sy", "Assane Diop"), ("Audrey Fleurot", "Morgane")]

FRENCH = {3, 4, 7, 9, 10, 23, 24, 25}
DIRECTORS = {0: "Denis Villeneuve", 1: "Denis Villeneuve", 2: "Christopher Nolan", 6: "Christopher Nolan", 16: "Christopher Nolan",
             3: "Alexandre de La Patellière", 23: "Martin Bourboulon", 12: "Jon Watts", 13: "Jon Watts", 14: "Jon Watts"}
STUDIOS = [(420, "Marvel Studios"), (2, "Walt Disney Pictures"), (3, "Pixar"), (923, "Legendary Pictures"), (174, "Warner Bros. Pictures")]
def studios_for(i):
    if i in (12, 13, 14): return [STUDIOS[0]]
    if i in (18, 19, 29): return [STUDIOS[1], STUDIOS[2]]
    if i in (0, 1, 6, 16): return [STUDIOS[3], STUDIOS[4]]
    return []

# classifications françaises (format TMDB « release_dates ») : Léa (12 ans max) ne doit pas voir les « 16 »
CERTS = {"Joker": "16", "Drive": "16", "Parasite": "12", "Le Parrain": "12", "La Haine": "12", "Barbie": "TP", "Vice-Versa": "TP", "Vice-Versa 2": "U"}

def movie(i):
    t, y, rt, v, g, col, ago = FILMS[i]
    m = fid(i)
    return {"id": m, "title": t, "original_title": t, "overview": f"{t} : résumé TMDB, assez long pour tenir sur deux lignes dans l'en-tête de la fiche et vérifier la coupure du texte.",
            "poster_path": tmdb_path("p", f"m{m}"), "backdrop_path": tmdb_path("b", f"m{m}"), "genres": [{"name": x} for x in g], "runtime": rt,
            "vote_average": v, "release_date": f"{y}-03-01", "belongs_to_collection": ({"id": col[0], "name": col[1]} if col else None), "adult": False,
            "credits": {"cast": [{"name": a, "character": c, "profile_path": tmdb_path("r", a.replace(" ", "_"))} for a, c in CAST[:6]],
                        "crew": [{"job": "Director", "name": DIRECTORS.get(i, f"Réalisateur {i}")}]},
            "production_countries": [{"iso_3166_1": "FR" if i in FRENCH else "US"}],
            "production_companies": [{"id": sid_, "name": n, "logo_path": tmdb_path("g", f"co{sid_}")} for sid_, n in studios_for(i)],
            "images": {"logos": [{"iso_639_1": "fr", "file_path": tmdb_path("g", f"m{m}")}] if i % 3 != 2 else []},
            "watch/providers": providers_for(t),
            "release_dates": {"results": ([{"iso_3166_1": "FR", "release_dates": [{"certification": CERTS[t], "type": 3}]}] if t in CERTS else [])},
            "keywords": {"keywords": [{"id": a, "name": b} for a, b in KW.get(t, [])]}}

def tv(i):
    t, y, v, g, ns, ne, rt, ago = SERIES[i]
    s = sid(i)
    return {"id": s, "name": t, "original_name": t, "overview": f"{t} : résumé TMDB de la série.", "poster_path": tmdb_path("p", f"s{s}"),
            "backdrop_path": tmdb_path("b", f"s{s}"), "genres": [{"name": x} for x in g], "episode_run_time": [rt], "vote_average": v,
            "first_air_date": f"{y}-01-01", "adult": False, "origin_country": ["FR" if i in (0, 1, 2, 7, 9) else "US"],
            "created_by": [{"name": "Créateur " + t}], "networks": [], "images": {"logos": [{"iso_639_1": "fr", "file_path": tmdb_path("g", f"s{s}")}]},
            "aggregate_credits": {"cast": [{"name": a, "roles": [{"character": c}], "profile_path": tmdb_path("r", a.replace(" ", "_"))} for a, c in CAST[2:8]]},
            "watch/providers": providers_for(t),
            # Lupin : un 6e épisode de la saison 3 annoncé dans 3 jours (« à venir »)
            "next_episode_to_air": ({"season_number": ns, "episode_number": ne + 1, "name": "Le dernier coup", "air_date": day(3)} if i == 1 else None)}

def day(n):
    return time.strftime("%Y-%m-%d", time.localtime(NOW + n * DAY))

def tv_season(i, sn):
    t, y, v, g, ns, ne, rt, ago = SERIES[i]
    count = ne + (1 if i == 1 and sn == ns else 0)
    return {"season_number": sn, "episodes": [{"season_number": sn, "episode_number": e, "name": ("Le dernier coup" if e > ne else f"Épisode {e}"),
                                               "air_date": day(3) if e > ne else f"{y + sn - 1}-0{min(9, e)}-01"} for e in range(1, count + 1)]}

def tmdb(path, q):
    if path == "/configuration": return {"images": {}}
    m = re.match(r"^/search/(movie|tv)$", path)
    if m:
        qq = (q.get("query") or [""])[0].lower()
        if m.group(1) == "movie":
            hit = [i for i, f in enumerate(FILMS) if f[0].lower() == qq] or ([ALIASES[qq]] if qq in ALIASES else [])
            return {"results": [{"id": fid(i), "title": FILMS[i][0], "original_title": FILMS[i][0], "release_date": f"{FILMS[i][1]}-03-01", "popularity": 50} for i in hit]}
        return {"results": [{"id": sid(i), "name": f[0], "original_name": f[0], "first_air_date": f"{f[1]}-01-01", "popularity": 50} for i, f in enumerate(SERIES) if f[0].lower() == qq]}
    m = re.match(r"^/movie/(\d+)(/videos)?$", path)
    if m:
        i = int(m.group(1)) - 1000
        if not (0 <= i < len(FILMS)): return None
        if m.group(2): return {"results": [{"site": "YouTube", "type": "Trailer", "key": "dQw4w9WgXcQ"}] if (q.get("language") or [""])[0] == "fr-FR" else []}
        return movie(i)
    m = re.match(r"^/tv/(\d+)/season/(\d+)$", path)
    if m:
        i = int(m.group(1)) - 2000
        if not (0 <= i < len(SERIES)): return None
        return tv_season(i, int(m.group(2)))
    m = re.match(r"^/tv/(\d+)(/videos)?$", path)
    if m:
        i = int(m.group(1)) - 2000
        if not (0 <= i < len(SERIES)): return None
        if m.group(2): return {"results": [{"site": "YouTube", "type": "Trailer", "key": "dQw4w9WgXcQ"}]}
        return tv(i)
    m = re.match(r"^/collection/(\d+)$", path)
    if m:
        cid = int(m.group(1))
        parts = [{"id": fid(i), "title": f[0], "release_date": f"{f[1]}-03-01", "poster_path": tmdb_path("p", f"m{fid(i)}")} for i, f in enumerate(FILMS) if f[5] and f[5][0] == cid]
        if cid == 502: parts.append({"id": 9999, "title": "Spider-Man : Beyond", "release_date": "", "poster_path": ""})
        return {"name": next((f[5][1] for f in FILMS if f[5] and f[5][0] == cid), "Saga"), "parts": parts}
    if path == "/movie/popular":
        order = [3, 0, 4, 5, 2, 15, 17, 18, 24, 12, 6, 22]
        return {"results": [{"id": fid(i)} for i in order]} if (q.get("page") or ["1"])[0] == "1" else {"results": []}
    if path == "/trending/tv/week":
        order = [2, 0, 9, 1, 3, 11, 4, 5, 7, 6]
        return {"results": [{"id": sid(i)} for i in order]} if (q.get("page") or ["1"])[0] == "1" else {"results": []}
    return None

TITLES = {f"m{fid(i)}": f[0] for i, f in enumerate(FILMS)}
TITLES.update({f"s{sid(i)}": f[0] for i, f in enumerate(SERIES)})

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body, ctype="application/json"):
        if isinstance(body, (dict, list)): body = json.dumps(body, ensure_ascii=False)
        if isinstance(body, str): body = body.encode()
        self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "max-age=86400"); self.end_headers(); self.wfile.write(body)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query); p = u.path
        if p.endswith("/player_api.php"):
            a = (q.get("action") or [None])[0]
            if a is None: return self.send(200, {"user_info": {"auth": 1, "status": "Active", "exp_date": str(NOW + 300 * DAY)}, "server_info": {"url": "127.0.0.1", "timezone": "Europe/Paris"}})
            if a == "get_live_categories": return self.send(200, [{"category_id": c, "category_name": n} for c, n in LIVE_CATS])
            if a == "get_vod_categories": return self.send(200, [{"category_id": c, "category_name": n} for c, n in VOD_CATS])
            if a == "get_series_categories": return self.send(200, [{"category_id": c, "category_name": n} for c, n in SER_CATS])
            if a == "get_live_streams": return self.send(200, live_streams())
            if a == "get_vod_streams": return self.send(200, vod_streams())
            if a == "get_series": return self.send(200, series_list())
            if a == "get_vod_info": return self.send(200, vod_info(int((q.get("vod_id") or ["1000"])[0])))
            if a == "get_series_info": return self.send(200, series_info(int((q.get("series_id") or ["2000"])[0])))
            return self.send(200, [])
        if p.endswith("/xmltv.php"): return self.send(200, xmltv(), "application/xml")
        if p == "/itunes/search":
            term = (q.get("term") or [""])[0].lower(); country = (q.get("country") or [""])[0]
            res = [{"kind": "feature-movie", "trackName": f[0], "releaseDate": f"{f[1]}-03-01T08:00:00Z", "trackTimeMillis": f[2] * 60000,
                    "previewUrl": APPLE_PREVIEW} for f in FILMS if f[0].lower() == term and country == "fr" and "tvShow" not in (q.get("media") or [""])]
            return self.send(200, {"resultCount": len(res), "results": res})
        if p.startswith("/tmdb/3"):
            r = tmdb(p[len("/tmdb/3"):], q)
            return self.send(200 if r is not None else 404, r if r is not None else {"status_code": 34})
        m = re.match(r"^/img/t/p/(\w+)/(\w)/(.+)\.png$", p)
        if m:
            size, kind, key = m.groups(); key = urllib.parse.unquote(key)
            w = {"p": 500, "b": 1920, "o": 92, "r": 185, "g": 500}.get(kind, 300)
            if size.startswith("w") and size[1:].isdigit(): w = min(w, int(size[1:])) if kind != "b" else min(1920, int(size[1:]))
            h = {"p": int(w * 1.5), "b": int(w * 0.5625), "o": w, "r": int(w * 1.5), "g": int(w * 0.3)}.get(kind, w)
            label = TITLES.get(key, "") if kind == "p" else (key.replace("_", " ") if kind in "or" else "")
            if kind == "o": label = {k: n for n, k in PROV}.get(key, key)
            if kind == "g": label = TITLES.get(key, "") or {f"co{a}": b for a, b in STUDIOS}.get(key, key)
            return self.send(200, make_png(kind, key, w, h, label), "image/png")
        m = re.match(r"^/gen/(\w)/(.+)\.png$", p)
        if m:
            kind, key = m.groups(); key = urllib.parse.unquote(key)
            label = (q.get("l") or [""])[0]
            w, h = {"p": (400, 600), "b": (1280, 720), "l": (300, 170)}.get(kind, (300, 300))
            return self.send(200, make_png(kind, key, w, h, label), "image/png")
        # vraie vidéo (bande-annonce iTunes) pour tester le lecteur : Dune : Deuxième partie, Interstellar et une autre version
        m = re.match(r"^/movie/[^/]+/[^/]+/(\d+)\.\w+$", p)
        if m and int(m.group(1)) in (fid(0), fid(16), 1901):
            self.send_response(302); self.send_header("Location", APPLE_PREVIEW); self.send_header("Content-Length", "0"); self.end_headers(); return
        if p.startswith("/movie/") or p.startswith("/series/") or p.startswith("/live/"):
            return self.send(404, "")
        self.send(404, {"error": p})

if __name__ == "__main__":
    print(f"faux fournisseur sur {BASE}", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
