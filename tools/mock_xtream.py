"""Faux serveur Xtream Codes pour tester l'interface de l'app (port 8099)."""
import json, base64, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

NOW = int(time.time())
b = lambda s: base64.b64encode(s.encode()).decode()
VCATS = [{"category_id": "1", "category_name": "FR | Nouveautés"}, {"category_id": "2", "category_name": "FR | Action"}, {"category_id": "3", "category_name": "FR | Comédie"}, {"category_id": "9", "category_name": "AR | Arabic"}]
SCATS = [{"category_id": "11", "category_name": "FR | Séries françaises"}, {"category_id": "12", "category_name": "FR | Séries US"}]
LCATS = [{"category_id": "21", "category_name": "FR | TNT"}, {"category_id": "22", "category_name": "FR | Info"}, {"category_id": "23", "category_name": "FR | Sport"}]
FILMS = [("Intouchables (2011)", "3", 8.3, "1771"), ("Le Comte de Monte-Cristo (2024) 4K", "1", 8.1, "1084736"), ("Le Comte de Monte-Cristo (2024) FHD", "1", 8.1, "1084736"),
         ("Dune : Deuxième partie (2024) MULTI", "1", 8.1, "693134"), ("Inception (2010) FHD", "2", 8.4, "27205"), ("Interstellar (2014)", "2", 8.5, "157336"),
         ("The Dark Knight (2008) 4K HDR", "2", 8.5, "155"), ("Barbie (2023) VOSTFR", "3", 7.0, "346698"), ("OSS 117 : Le Caire, nid d'espions (2006)", "3", 6.7, "15360"),
         ("La Haine (1995)", "2", 8.0, "406"), ("Joker (2019) HD", "2", 8.1, "475557"), ("Bienvenue chez les Ch'tis (2008)", "3", 6.7, "8271"), ("فيلم عربي (2020)", "9", 6.0, "")]
VOD = [{"num": i + 1, "name": "FR| " + n, "stream_id": 100 + i, "stream_icon": "", "rating": r, "added": str(NOW - (i * 3 + 1) * 86400), "category_id": c, "container_extension": "mkv", "tmdb": t} for i, (n, c, r, t) in enumerate(FILMS)]
SERIES = [{"series_id": 500 + i, "name": "FR| " + n, "cover": "", "plot": p, "cast": cast, "director": d, "genre": g, "releaseDate": y, "rating": r, "last_modified": str(NOW - i * 5 * 86400), "category_id": c, "backdrop_path": [], "tmdb": ""}
          for i, (n, p, cast, d, g, y, r, c) in enumerate([
              ("Lupin", "Assane Diop, gentleman cambrioleur, venge son père.", "Omar Sy, Ludivine Sagnier, Antoine Gouy", "George Kay", "Policier, Drame", "2021-01-08", "7.7", "11"),
              ("Le Bureau des Légendes", "Au cœur de la DGSE.", "Mathieu Kassovitz, Sara Giraudeau", "Éric Rochant", "Espionnage", "2015-04-27", "8.0", "11"),
              ("Breaking Bad", "Un professeur de chimie bascule.", "Bryan Cranston, Aaron Paul", "Vince Gilligan", "Drame", "2008-01-20", "8.9", "12")])]
CHANNELS = ["TF1 ᶠᴴᴰ", "Gulli HD", "Disney Channel FHD", "Canal J", "RMC Découverte HD", "National Geographic FHD", "RMC Sport 1 FHD", "Ciné+ Frisson HD", "M6 Music HD", "France 3 Bretagne HD", "UK| Sky Sports Main Event FHD", "UK| BBC One HD", "TF1 FHD", "France 2 FHD", "France 3 HD", "Canal+ FHD", "France 5 HD", "M6 FHD", "Arte HD", "W9 HD", "TMC HD", "BFM TV FHD", "CNEWS HD", "LCI HD", "franceinfo FHD", "L'Equipe HD", "beIN Sports 1 FHD", "TF1 4K", "TF1 HD"]
LIVE = [{"num": i + 1, "name": "FR| " + n, "stream_id": 1000 + i, "stream_icon": "", "epg_channel_id": "", "category_id": "22" if any(x in n for x in ("BFM", "CNEWS", "LCI", "franceinfo")) else "23" if any(x in n for x in ("Equipe", "beIN")) else "21", "tv_archive": 0} for i, n in enumerate(CHANNELS)]

import os
VOD[0]["category_ids"] = ["3", "1"]  # film rangé dans deux catégories
if os.environ.get("MOCK_BIG"):
    VCATS += [{"category_id": str(100 + c), "category_name": f"FR | Catégorie {c}"} for c in range(36)]
    VOD += [{"num": 1000 + i, "name": f"FR| Film démo {i} ({1980 + i % 45}) {'FHD' if i % 2 else 'HD'}", "stream_id": 5000 + i, "stream_icon": "", "rating": 5 + (i % 40) / 10, "added": str(NOW - (i % 300) * 86400), "category_id": str(100 + i % 36), "container_extension": "mkv", "tmdb": ""} for i in range(4000)]
    LIVE += [{"num": 100 + i, "name": f"FR| Chaîne {i} {'FHD' if i % 3 else 'HD'}", "stream_id": 9000 + i, "stream_icon": "", "epg_channel_id": "", "category_id": "21", "tv_archive": 0} for i in range(1500)]

def short_epg(sid):
    start = NOW - (NOW % 1800) - 1800
    out = []
    for k in range(8):
        s = start + k * 2700
        out.append({"title": b(f"Programme {k+1} ({sid})"), "description": b("Magazine d'information"), "start_timestamp": str(s), "stop_timestamp": str(s + 2700)})
    return {"epg_listings": out}

def series_info(sid):
    s = next(x for x in SERIES if x["series_id"] == sid)
    eps = {str(n): [{"id": str(sid * 100 + n * 10 + e), "episode_num": e, "title": f"Épisode {e}", "container_extension": "mkv", "info": {"duration_secs": 2700, "plot": "", "movie_image": ""}} for e in range(1, 7)] for n in (1, 2)}
    return {"info": {"name": s["name"], "plot": s["plot"], "cast": s["cast"], "director": s["director"], "genre": s["genre"], "rating": s["rating"], "backdrop_path": []}, "episodes": eps}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        u = urlparse(self.path); q = {k: v[0] for k, v in parse_qs(u.query).items()}
        if u.path == "/version.json":
            return self.send({"versionName": "1.0.1", "versionCode": 2, "size": 6291456, "date": "7 novembre 2026", "notes": ["Corrections"], "apk": "http://localhost:8099/prisme.apk"})
        if u.path != "/player_api.php": return self.send({"error": "404"}, 404)
        if q.get("username") != "demo" or q.get("password") != "demo":
            return self.send({"user_info": {"auth": 0}})
        a = q.get("action")
        if not a: return self.send({"user_info": {"auth": 1, "status": "Active", "exp_date": str(NOW + 200 * 86400), "max_connections": "2", "active_cons": "0", "allowed_output_formats": ["m3u8", "ts"]}, "server_info": {"url": "localhost"}})
        r = {"get_vod_categories": VCATS, "get_series_categories": SCATS, "get_live_categories": LCATS, "get_vod_streams": VOD, "get_series": SERIES, "get_live_streams": LIVE}.get(a)
        cid = q.get("category_id")
        if a in ("get_vod_streams", "get_series", "get_live_streams") and r is not None:
            if cid: r = [x for x in r if str(x["category_id"]) == cid or cid in x.get("category_ids", [])]
            elif os.environ.get("MOCK_PARTIAL"): r = [x for x in r if str(x["category_id"]) not in ("9", "12")]  # serveur qui « oublie » des catégories
        if a == "get_short_epg": r = short_epg(q.get("stream_id"))
        if a == "get_series_info": r = series_info(int(q.get("series_id")))
        if a == "get_vod_info":
            v = next(x for x in VOD if str(x["stream_id"]) == q.get("vod_id"))
            r = {"info": {"plot": "Synopsis de " + v["name"], "cast": "Omar Sy, François Cluzet, Audrey Fleurot", "director": "Réalisateur Démo", "genre": "Comédie, Drame", "duration_secs": 6720, "rating": v["rating"], "releasedate": "2011-11-02",
                 "video": ({"codec_name": "hevc", "width": 3840, "height": 1608, "avg_frame_rate": "24000/1001", "color_transfer": "smpte2084"} if "4K" in v["name"] else {"codec_name": "h264", "width": 1920, "height": 800, "avg_frame_rate": "24000/1001"}) if v["stream_id"] % 3 else [],
                 "audio": {"codec_name": "eac3", "channels": 6, "tags": {"language": "fre"}}}, "movie_data": {}}
        self.send(r)
    def send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Access-Control-Allow-Origin", "*"); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)

ThreadingHTTPServer(("127.0.0.1", 8099), H).serve_forever()
