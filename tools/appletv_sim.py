"""Construit simulateur-appletv.html : le simulateur prisme adapté à l'Apple TV.

Part du simulateur Fire TV validé (même données, mêmes écrans) et applique :
- télécommande Siri Remote (pavé tactile, Retour, TV, lecture/pause, Siri)
- appareil Apple TV 4K : 4K, Dolby Vision, AVPlayer + VLC (TVVLCKit) pour MKV
- accueil films/séries de la version native 2.x : Continuer, Ma liste, Derniers ajouts,
  Top 10 en affiches, puis tuiles de genres ouvrant une grille triable
- TV en direct rangée par genre
- plus de mise à jour par APK : signature gratuite Apple valable 7 jours
"""
import os, re, sys
D = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(D, "simulateur.html"), encoding="utf-8").read()
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(D, "simulateur-appletv.html")


def R(a, b):
    global src
    assert src.count(a) == 1, ("ATTENDU UNE FOIS", src.count(a), a[:90])
    src = src.replace(a, b)


def RX(pat, b):
    global src
    n = len(re.findall(pat, src, re.S))
    assert n == 1, (pat, n)
    src = re.sub(pat, lambda m: b, src, flags=re.S)


# ------------------------------------------------------------- en-tête
R("<title>Simulateur IPTV Fire TV</title>", "<title>Simulateur Prisme Apple TV</title>")
R("télécommande Fire TV à droite */", "télécommande Siri Remote à droite */")
R("<h1>Simulateur IPTV · Fire TV Stick</h1>", "<h1>Simulateur prisme · Apple TV</h1>")
R("<p>Données de démonstration · aucun flux réel n'est lu</p>",
  "<p>Données de démonstration · aucun flux réel n'est lu · cible : Apple TV 4K, tvOS</p>")

# ------------------------------------------------------------- Siri Remote
RX(r'<div class="remote" aria-label="Télécommande">.*?<div class="brand-r">fire tv</div>\s*</div>', '''<div class="remote siri" aria-label="Siri Remote">
      <button class="rb pw" data-k="home" title="Allumer / TV" aria-label="Alimentation"><svg viewBox="0 0 24 24"><path d="M11 3h2v9h-2zM7.1 5.6l1.4 1.4A6 6 0 1 0 15.5 7l1.4-1.4A8 8 0 1 1 7.1 5.6z"/></svg></button>
      <div class="ring">
        <button class="rb u" data-k="up" aria-label="Haut"></button>
        <button class="rb l" data-k="left" aria-label="Gauche"></button>
        <button class="rb r" data-k="right" aria-label="Droite"></button>
        <button class="rb d" data-k="down" aria-label="Bas"></button>
        <button class="rb ok" data-k="ok" aria-label="Clic (maintenir : menu)"></button>
      </div>
      <div class="rgrid">
        <button class="rb" data-k="back" title="Retour (Échap)" aria-label="Retour"><svg viewBox="0 0 24 24"><path d="M15.4 5.4 14 4l-8 8 8 8 1.4-1.4L8.8 12z"/></svg></button>
        <button class="rb" data-k="home" title="TV : accueil (H)" aria-label="TV"><svg viewBox="0 0 24 24"><path d="M3 5h18v11H3zm2 2v7h14V7zM8 18h8v2H8z"/></svg></button>
        <button class="rb" data-k="play" title="Lecture/Pause (Espace)" aria-label="Lecture pause"><svg viewBox="0 0 24 24"><path d="M3 5v14l9-7zm11 0h3v14h-3zm5 0h3v14h-3z"/></svg></button>
        <button class="rb vol" aria-hidden="true" tabindex="-1"><svg viewBox="0 0 24 24"><path d="M11 5h2v14h-2zM5 11h14v2H5z"/></svg></button>
        <button class="rb" data-k="menu" title="Maintenir le clic : favoris (M)" aria-label="Favoris"><svg viewBox="0 0 24 24"><path d="M12 20s-7-4.4-9-9C1.7 7.8 3.7 4.5 7 4.5c2 0 3.4 1.1 5 3 1.6-1.9 3-3 5-3 3.3 0 5.3 3.3 4 6.5-2 4.6-9 9-9 9z"/></svg></button>
        <button class="rb vol" aria-hidden="true" tabindex="-1"><svg viewBox="0 0 24 24"><path d="M5 11h14v2H5z"/></svg></button>
      </div>
      <button class="rb siri-b" data-k="mic" title="Siri : recherche (S)" aria-label="Siri"><svg viewBox="0 0 24 24"><path d="M12 15a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v6a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.9V21h2v-2.1A7 7 0 0 0 19 12z"/></svg></button>
    </div>''')
R("<kbd>M</kbd> ajouter/retirer des favoris",
  "<kbd>M</kbd> (ou maintenir le clic) ajouter/retirer des favoris")

SIRI_CSS = """
/* Siri Remote (aluminium) */
.remote.siri{width:132px;background:linear-gradient(160deg,#d7d9de,#a9adb5 55%,#8d9199);border-radius:30px;padding:18px 14px 24px;gap:16px;box-shadow:0 20px 50px rgba(0,0,0,.6),inset 0 1px 0 rgba(255,255,255,.7)}
.remote.siri .rb{background:#1d1e22;color:#e7e8ec}
.remote.siri .pw{width:28px;height:28px;align-self:flex-end}.remote.siri .pw svg{width:13px;height:13px}
.ring{position:relative;width:104px;height:104px;border-radius:50%;background:#1d1e22;box-shadow:inset 0 1px 0 rgba(255,255,255,.08),0 2px 4px rgba(0,0,0,.35)}
.ring .rb{position:absolute;width:30px;height:30px;background:transparent!important;box-shadow:none}
.ring .rb::after{content:"";position:absolute;inset:12px;border-radius:50%;background:#55575e}
.ring .u{top:3px;left:37px}.ring .d{bottom:3px;left:37px}.ring .l{left:3px;top:37px}.ring .r{right:3px;top:37px}
.ring .ok{left:27px;top:27px;width:50px;height:50px;background:#2a2b30!important;border-radius:50%;box-shadow:inset 0 1px 0 rgba(255,255,255,.08)}
.ring .ok::after{display:none}
.rgrid{display:grid;grid-template-columns:repeat(2,40px);gap:12px 16px}
.remote.siri .rgrid .rb{width:40px;height:40px}
.remote.siri .vol{opacity:.55;cursor:default}
.remote.siri .siri-b{width:30px;height:30px}
@media (max-width:760px){.remote.siri{width:auto;flex-direction:row;flex-wrap:wrap;justify-content:center;border-radius:26px;padding:14px 18px}.remote.siri .pw,.remote.siri .vol{display:none}.rgrid{grid-template-columns:repeat(2,40px)}}
/* Accueil : tuiles de genres */
.gsec{padding:26px 64px 0}
.gsec h3{margin:0;font-size:20px;font-weight:600;color:rgba(255,255,255,.78)}
.gsec h3 small{font-size:14px;color:rgba(255,255,255,.45);font-weight:500;margin-left:12px}
.gtiles{display:grid;grid-template-columns:repeat(4,1fr);gap:20px;padding-top:18px}
.gtile{height:112px;border-radius:16px;padding:16px 20px;box-sizing:border-box;display:flex;flex-direction:column;justify-content:flex-end;background:linear-gradient(135deg,var(--a),var(--b));box-shadow:0 6px 18px rgba(0,0,0,.35);cursor:pointer;transition:transform .2s cubic-bezier(.2,.8,.2,1),box-shadow .2s;position:relative;overflow:hidden}
.gtile b{font-size:22px;font-weight:700;text-shadow:0 2px 8px rgba(0,0,0,.4)}
.gtile span{font-size:14px;color:rgba(255,255,255,.78)}
.gtile::before{content:"";position:absolute;inset:0;background:linear-gradient(120deg,rgba(255,255,255,.22),transparent 45%);opacity:.6}
.gtile.foc{transform:scale(1.07);box-shadow:0 20px 40px rgba(0,0,0,.6),0 0 0 3px #fff}
/* Écran genre */
.gview{position:absolute;inset:0}
.ghead{position:absolute;left:64px;top:56px;right:64px}
.ghead .kick{letter-spacing:.08em}
.ghead h1{margin:6px 0 0;font-size:46px;font-weight:700}
.ghead .chips{display:flex;gap:12px;margin-top:18px}
.ggrid{position:absolute;left:0;right:0;top:236px;bottom:0;overflow-y:auto;display:grid;grid-template-columns:repeat(7,138px);gap:34px 26px;padding:18px 64px 60px;align-content:start;-webkit-mask-image:linear-gradient(transparent 0,#000 18px);mask-image:linear-gradient(transparent 0,#000 18px)}
.ggrid::-webkit-scrollbar{display:none}
.ggrid .card{width:138px}
.gcount{position:absolute;right:64px;top:80px;font-size:15px;color:rgba(255,255,255,.5)}
"""
R("</style>", SIRI_CSS + "</style>")

# ------------------------------------------------------------- appareil
RX(r"/\* Appareil cible : Fire TV Stick.*?\nconst DEVICE=\{[^\n]*\};",
   '''/* Appareil cible : Apple TV 4K (3e génération) · tvOS 26 · 4K HDR, Dolby Vision */
const APP={ver:"1.0",code:1,repo:"github.com/goyste0406/prisme-firetv (branche appletv)"};
const LATEST={ver:"1.0",code:1,size:0,date:"",notes:[]};
const DEVICE={name:"Apple TV 4K (3e génération)",os:"tvOS 26",maxQ:"4K",hdr:"Dolby Vision, HDR10+, HDR10, HLG",audio:"Dolby Atmos, Dolby Digital Plus (sortie directe)",ram:"4 Go",codecs:"H.264, HEVC jusqu'en 4K 60 i/s · MKV et AVI via VLC"};
/* Signature gratuite Apple : l'appli s'ouvre 7 jours après l'installation depuis le Mac */
const SIGN_DAYS=7;
function signLeft(){if(!S.signAt){S.signAt=Date.now()-86400000*2;save()}return Math.max(0,SIGN_DAYS-Math.floor((Date.now()-S.signAt)/86400000))}''')
R("engine:\"exo\",meta:", "engine:\"av\",meta:")
R("tab:S.tab,favs:S.favs,", "tab:S.tab,signAt:S.signAt,gsort:S.gsort,favs:S.favs,")

# Réglages : À propos, appareil, lecteur
RX(r'<section data-anchor><h3>À propos et mises à jour</h3>.*?</div></section>\n <section data-anchor><h3>Appareil</h3>',
   '''<section data-anchor><h3>À propos et installation</h3><div class="grp">
  <div class="it tall"><span>Application<small>Écrans et lecteur · installés depuis le Mac</small></span><span>prisme ${esc(S.appVer)} pour Apple TV</span></div>
  <div class="it tall"><span>Données et fonctions<small>Connexion Xtream, catalogue, genres, fiches · mises à jour sans le Mac</small></span><span>version ${esc(dVer(S.dataBuild||1))}</span></div>
  <div class="it" data-f data-fid="set-upd" data-act="upd:check"><span>Mettre à jour maintenant</span><span>${(S.dataBuild||1)>=(S.pubBuild||2)?"Tu as la dernière version":"Version "+esc(dVer(S.pubBuild||2))+" disponible"}</span></div>
  <div class="it" data-f data-fid="set-autoupd" data-act="set:autoUpd"><span>Installer automatiquement à l'ouverture</span>${sw(S.set.autoUpd!==false)}</div>
  <div class="it" data-f data-fid="set-sign" data-act="sign"><span>Validité de l'installation<small>Apple ID gratuit · renouvelée chaque semaine par Sideloadly depuis le Mac</small></span><span style="color:${signLeft()<=1?"#ff9f0a":"inherit"}">${signLeft()} jour${signLeft()>1?"s":""} restant${signLeft()>1?"s":""}</span></div>
  <div class="it tall"><span>Code source<small>${esc(APP.repo)} · compilé automatiquement par GitHub Actions</small></span><span></span></div>
  <div class="it tall" data-f data-fid="set-pub" data-act="upd:pub"><span>Démo : publier une nouvelle version sur GitHub<small>Simulateur uniquement · pour tester le bouton de mise à jour</small></span><span>＋</span></div>
 </div></section>
 <section data-anchor><h3>Appareil</h3>''')
R('<span>${DEVICE.maxQ} · sources 4K ignorées automatiquement</span>',
  '<span>${DEVICE.maxQ} HDR · toutes les sources sont lisibles</span>')
R('${st.engine==="vlc"?"VLC (libVLC)":"ExoPlayer (Media3) · recommandé"}',
  '${st.engine==="vlc"?"VLC (TVVLCKit) · lit tous les formats":"AVPlayer (Apple) · recommandé, VLC pour MKV/AVI"}')
R('S.set.engine=S.set.engine==="vlc"?"exo":"vlc"', 'S.set.engine=S.set.engine==="vlc"?"av":"vlc"')
src = src.replace('S.set.engine==="vlc"?"VLC (libVLC)":', 'S.set.engine==="vlc"?"VLC (TVVLCKit)":')
src = src.replace("ExoPlayer (Media3)", "AVPlayer")

# Mise à jour à chaud de la couche de données (fichier JS téléchargé depuis GitHub, exécuté par JavaScriptCore)
RX(r"function autoCheck\(\)\{[^\n]*\}",
   '''function autoCheck(){if(AUTOCHK||!inApp())return;AUTOCHK=true;const d=signLeft();
 if(S.set.autoUpd!==false&&(S.dataBuild||1)<(S.pubBuild||2))setTimeout(()=>{if(S.modal)return;const b=S.pubBuild||2;S.dataBuild=b;save();if(topS().t==="home"&&S.tab==="settings")render(F&&F.dataset.fid);toast(`Données mises à jour en ${dVer(b)} · sans redémarrer`)},1200);
 if(d<=1)setTimeout(()=>toast(d?"Plus qu'un jour : renouvelle prisme avec Sideloadly sur le Mac":"Installation expirée : renouvelle prisme avec Sideloadly sur le Mac"),4000)}''')

UPD_JS = r'''
/* Mise à jour à chaud : manifest.json + data.js sur GitHub (branche appletv), vérifiés puis chargés dans JavaScriptCore */
const DNOTES=[["Tri des genres par date de sortie","Correction des affiches manquantes dans Derniers ajouts"],["Recherche plus rapide sur les acteurs","Fiches en français en priorité (TMDB)"],["Chaînes classées par genre plus précises","Correction des doublons de sources"],["Masquage des catégories instantané","Reprise de lecture plus fiable sur les séries"],["Nouveaux épisodes détectés plus tôt","Contenu adulte toujours exclu au chargement"]];
const dVer=b=>"1.0."+b;const dNotes=b=>DNOTES[(b-2+DNOTES.length*10)%DNOTES.length];const dSize=b=>(38+(b*7)%19)+" Ko";
function updHtml(){const u=S.modal,b=S.pubBuild||2,cur=S.dataBuild||1;
 const box=(w,inner)=>`<div class="modal"><div class="mbox upd" style="width:${w}px">${inner}</div></div>`;
 if(u.stage==="check")return box(640,`<div class="kick">Mise à jour</div><h2>Recherche en cours…</h2><div class="meta2">Lecture de manifest.json sur GitHub (branche appletv)</div><div class="ubar"><i style="width:35%;animation:none"></i></div><div class="ubtns"><div class="btn" data-f data-fid="u-cancel" data-act="upd:close" data-default>Annuler</div></div>`);
 if(u.stage==="uptodate")return box(640,`<div class="kick">Mise à jour</div><h2>prisme est à jour</h2><div class="meta2">Données ${esc(dVer(cur))} · appli ${esc(S.appVer)} · vérifié à ${fmt(nowMin())}</div><div class="ubtns"><div class="btn" data-f data-fid="u-ok" data-act="upd:close" data-default>OK</div></div>`);
 if(u.stage==="avail")return box(700,`<div class="kick">Nouvelle version disponible</div><h2>Données ${esc(dVer(b))}</h2><div class="meta2">Installée : ${esc(dVer(cur))} · ${dSize(b)} · aucune réinstallation depuis le Mac</div>
  <ul class="notes2">${dNotes(b).map(n=>`<li>${esc(n)}</li>`).join("")}</ul>
  <div class="meta2" style="margin-top:12px">Tes playlists, favoris et reprises de lecture sont conservés. prisme ne redémarre pas.</div>
  <div class="ubtns"><div class="btn" data-f data-fid="u-go" data-act="upd:go" data-default>Mettre à jour</div><div class="btn" data-f data-fid="u-later" data-act="upd:close">Plus tard</div></div>`);
 if(u.stage==="dl")return box(640,`<div class="kick">${u.pct<100?"Téléchargement":"Vérification et application"}</div><h2>Données ${esc(dVer(b))}</h2><div class="ubar"><i id="ubar" style="width:${u.pct}%"></i></div><div class="meta2" id="utxt">${Math.round(u.pct)} %</div><div class="ubtns"><div class="btn" data-f data-fid="u-stop" data-act="upd:close" data-default>Annuler</div></div>`);
 if(u.stage==="done")return box(640,`<div class="kick">Mise à jour terminée</div><h2>Données ${esc(dVer(cur))} appliquées</h2><div class="meta2">Les nouveautés sont actives tout de suite. En cas de problème, l'ancienne version est gardée et se remet automatiquement.</div><div class="ubtns"><div class="btn" data-f data-fid="u-ok" data-act="upd:close" data-default>OK</div></div>`);
 return "";
}
let UT=null;
function updAct(v){clearInterval(UT);clearTimeout(UT);
 if(v==="pub"){S.pubBuild=Math.max(S.pubBuild||2,S.dataBuild||1)+1;save();render("set-pub");toast(`Version ${dVer(S.pubBuild)} publiée sur GitHub (démo)`);return}
 if(v==="close"){const r=S.modal&&S.modal.ret;if(S.modal&&S.modal.stage==="dl")toast("Mise à jour annulée");S.modal=null;render(r);return}
 if(v==="check"){S.modal={type:"upd",stage:"check",ret:F&&F.dataset.fid};render();UT=setTimeout(()=>{if(!S.modal||S.modal.type!=="upd")return;S.modal.stage=(S.dataBuild||1)>=(S.pubBuild||2)?"uptodate":"avail";render()},900);return}
 if(v==="go"){S.modal.stage="dl";S.modal.pct=0;render();
  UT=setInterval(()=>{const m=S.modal;if(!m||m.stage!=="dl"){clearInterval(UT);return}m.pct=Math.min(100,m.pct+9+Math.random()*12);const b=$("#ubar"),t=$("#utxt");if(b)b.style.width=m.pct+"%";if(t)t.textContent=Math.round(m.pct)+" %";
   if(m.pct>=100){clearInterval(UT);UT=setTimeout(()=>{if(!S.modal||S.modal.stage!=="dl")return;S.dataBuild=S.pubBuild||2;save();S.modal.stage="done";render()},500)}},120);return}
}
'''
RX(r"function updHtml\(\)\{.*?\nlet UT=null;\nfunction updAct\(v\)\{.*?\n\}\n", UPD_JS.lstrip("\n"))
R("tab:S.tab,signAt:S.signAt,", "tab:S.tab,signAt:S.signAt,dataBuild:S.dataBuild,pubBuild:S.pubBuild,")

# ------------------------------------------------------------- TV en direct par genre
R('const LCATS=[["all","Toutes les chaînes"],["fav","Favoris"],["tnt","FR | TNT"],["info","FR | Info"],["sport","FR | Sport"],["cine","FR | Cinéma"],["jeunesse","FR | Jeunesse"]];',
  'const LCATS=[["all","Toutes les chaînes"],["fav","Favoris"],["tnt","Généralistes"],["info","Info"],["sport","Sport"],["cine","Cinéma"],["jeunesse","Jeunesse"]];')

# ------------------------------------------------------------- accueil natif + genres
GENRES_JS = r'''
/* ========================= GENRES (accueil natif 2.x) ========================= */
const GDEF={
 f:[["action","Action","#e3342f","#3a0a0a",/action/],["comedie","Comédie","#f5b942","#5b3a06",/comed|humour|comique|comedy/],["drame","Drame","#7aa2c2","#0c1520",/drame|drama/],
  ["thriller","Thriller","#5b7c99","#05070d",/thriller|suspense/],["policier","Policier","#9c6b3f","#1a120b",/polic|crime|criminel|gangster|mafia|polar/],
  ["sf","Science-fiction","#6ee7f9","#0b1730",/science|sci-?fi|\bs\.?f\b/],["horreur","Horreur","#c8323a","#0a0a0a",/horreur|horror|epouvante/],
  ["animation","Animation","#ff9f0a","#5b1036",/anim|dessin|cartoon|manga/],["familial","Familial","#7fb347","#1c2b12",/famil|enfant|kids|jeunesse/],
  ["aventure","Aventure","#c9a227","#0e1a2b",/aventure|adventure/],["romance","Romance","#ff5fa2","#5b1036",/romance|romanti|amour/],
  ["fantastique","Fantastique","#bf5af2","#1d0b30",/fantas|merveilleux/],["mystere","Mystère","#8e7cc3","#120c22",/myst|enquete/],
  ["documentaire","Documentaire","#90cea1","#0f2a1d",/docu/],["histoire","Histoire","#b08d57","#1f150a",/histo|biopic|biograph/],
  ["guerre","Guerre","#b7a57a","#141414",/guerre|\bwar\b/],["autres","Autres","#5d6270","#16181d",null]],
 s:[["drame","Drame","#7aa2c2","#0c1520",/drame|drama/],["policier","Policier","#9c6b3f","#1a120b",/polic|crime|criminel|espion/],
  ["comedie","Comédie","#f5b942","#5b3a06",/comed|humour|sitcom|comique/],["action","Action & Aventure","#e3342f","#3a0a0a",/action|aventure/],
  ["sf","Science-fiction & Fantastique","#6ee7f9","#0b1730",/science|sci-?fi|fantas/],["mystere","Mystère","#8e7cc3","#120c22",/myst|thriller|suspense|enquete/],
  ["animation","Animation","#ff9f0a","#5b1036",/anim|cartoon/],["familial","Familial","#7fb347","#1c2b12",/famil|jeunesse/],
  ["documentaire","Documentaire","#90cea1","#0f2a1d",/docu/],["autres","Autres","#5d6270","#16181d",null]]};
const GK={};
function genreKeys(it){if(GK[it.id])return GK[it.id];const D=GDEF[it.type],cl={};(it.type==="f"?FCATS:SCATS).forEach(([k,n])=>cl[k]=n);
 const txt=[...(it.g||[]),...it.cat.map(k=>cl[k]||"")].map(x=>norm(String(x)));const out=[];
 for(const g of D){if(g[4]&&txt.some(t=>g[4].test(t)))out.push(g[0])}if(!out.length)out.push("autres");return GK[it.id]=out}
function genreList(ty){const L=ty==="f"?films():series();return GDEF[ty].map(g=>({g,items:L.filter(i=>genreKeys(i).includes(g[0]))})).filter(x=>x.items.length)}
const GSORT=ty=>["Derniers ajouts",ty==="f"?"Sortie au cinéma":"Première diffusion","A → Z","Les mieux notés"];
function genreItems(ty,k){const L=(ty==="f"?films():series()).filter(i=>genreKeys(i).includes(k)),s=S.gsort||0;
 if(s===0)return L.map(i=>[i,(added(i.id)||{d:999}).d]).sort((a,b)=>a[1]-b[1]).map(x=>x[0]);
 if(s===1)return [...L].sort((a,b)=>b.y-a.y);if(s===2)return [...L].sort((a,b)=>a.t.localeCompare(b.t,"fr"));return [...L].sort((a,b)=>b.tmdb-a.tmdb)}
function genreHtml(ty,k){const g=GDEF[ty].find(x=>x[0]===k),L=genreItems(ty,k);
 return `<div class="gview"><div class="ghead"><div class="kick">${ty==="f"?"FILMS":"SÉRIES"} · GENRE</div><h1>${esc(g[1])}</h1>
 <div class="chips">${GSORT(ty).map((n,i)=>`<div class="chip ${(S.gsort||0)===i?"sel":""}" data-f data-fid="gs-${i}" data-row="gsort" data-act="gsort:${i}" ${(S.gsort||0)===i&&!L.length?"data-default":""}>${esc(n)}</div>`).join("")}</div></div>
 <div class="gcount">${L.length} ${ty==="f"?"film":"série"}${L.length>1?"s":""}</div>
 <div class="ggrid sy" id="ggrid">${L.map((i,n)=>card(i,"g"+Math.floor(n/7)).replace('data-f ',n===0?'data-f data-default ':'data-f ')).join("")}</div></div>`}
'''
R("/* ========================= ÉCRANS ========================= */", GENRES_JS + "\n/* ========================= ÉCRANS ========================= */")

RX(r'  const top=\[\.\.\.list\]\.sort.*?cats\.forEach\(\(\[k,l\]\)=>\{[^\n]*\}\);\n',
   r'''  const recent=list.map(i=>[i,added(i.id)]).filter(x=>x[1]).sort((a,b)=>a[1].d-b[1].d).slice(0,30).map(x=>x[0]);
  const trend=[...list].sort((a,b)=>trendScore(b)-trendScore(a)).slice(0,10);
  const contCard=(i,r)=>card(i,r,`<div class="prog"><i style="width:${Math.round(S.prog[i.id]*100)}%"></i></div>`);
  let rows=rowHtml("cont","Continuer à regarder",cont,contCard)+rowHtml("fav","Ma liste",fav,card)+rowHtml("new","Derniers ajouts",recent,card,false)
   +rowHtml("trend",ty==="f"?"Top 10 des films du moment":"Top 10 des séries du moment",trend,(i,r)=>rankCard(i,r,trend.indexOf(i)),false);
  const G=genreList(ty);
  if(G.length)rows+=`<section class="gsec" data-anchor><h3>Genres<small>${G.length} · OK pour voir tous les titres du genre</small></h3><div class="gtiles">${G.map(({g,items},n)=>`<div class="gtile" data-f data-fid="gt-${g[0]}" data-row="gt${Math.floor(n/4)}" data-act="genre:${ty}:${g[0]}" style="--a:${g[2]};--b:${g[3]}"><b>${esc(g[1])}</b><span>${items.length} ${ty==="f"?"titre":"série"}${items.length>1?"s":""}</span></div>`).join("")}</div></section>`;
''')

R(' else if(t.t==="actor") html=actorHtml(t.id);',
  ' else if(t.t==="actor") html=actorHtml(t.id);\n else if(t.t==="genre") html=genreHtml(t.ty,t.k);\n else if(t.t==="fhcoll") html=fhCollHtml(t.k);\n else if(t.t==="sxcoll") html=sxCollHtml(t.k);')
R(' else if(t.t==="actor"){const h=hash(t.id)%360;',
  ' else if(t.t==="genre"){const g=GDEF[t.ty].find(x=>x[0]===t.k);setBg([g[2],g[3]])}\n else if(t.t==="actor"){const h=hash(t.id)%360;')

# actions
R("function act(a){\n if(!a)return;const [k,v,w,x]=a.split(\":\");",
  '''function act(a){
 if(!a)return;const [k,v,w,x]=a.split(":");
 if(k==="genre"){push({t:"genre",ty:v,k:w});return}
 if(k==="gsort"){S.gsort=+v;save();render("gs-"+v);const g=$("#ggrid");if(g)g.scrollTop=0;return}
 if(k==="sign"){toast(signLeft()>1?`Installation valable encore ${signLeft()} jours`:"Renouvelle prisme avec Sideloadly sur le Mac");return}''')

# Clic maintenu sur le pavé = menu contextuel (favoris), comme sur tvOS
R("/* Clic sur la barre de progression : saut direct */",
  '''/* Siri Remote : maintenir le clic central ouvre le menu (favoris) */
/* OK part au relâchement : un appui court = OK, un appui long (0,55 s) = menu, jamais les deux */
{const ok=document.querySelector('.ring [data-k="ok"]');let lp=null;
 ok.addEventListener("pointerdown",e=>{e.stopImmediatePropagation();e.preventDefault();clearTimeout(lp);lp=setTimeout(()=>{lp=null;key("menu")},550)},true);
 ok.addEventListener("pointerup",()=>{if(lp){clearTimeout(lp);lp=null;key("ok")}},true);
 ["pointerleave","pointercancel"].forEach(ev=>ok.addEventListener(ev,()=>{clearTimeout(lp);lp=null}));
 ok.addEventListener("click",e=>{if(e.detail)e.stopImmediatePropagation()},true);}
/* Clavier : Entrée maintenue = menu, Entrée relâchée vite = OK */
{let kt=null;window.addEventListener("keydown",e=>{if(e.key!=="Enter")return;const a=document.activeElement;if(a&&(a.tagName==="INPUT"||a.tagName==="TEXTAREA"||(a.closest&&a.closest(".remote,button"))))return;e.preventDefault();e.stopImmediatePropagation();if(e.repeat||kt)return;kt=setTimeout(()=>{kt=null;key("menu")},550)},true);
 window.addEventListener("keyup",e=>{if(e.key!=="Enter"||!kt)return;e.preventDefault();clearTimeout(kt);kt=null;key("ok")},true)}
/* Clic sur la barre de progression : saut direct */''')

# versions : la fiche technique du serveur (flux.json) en clair, sur 2 lignes, à la place du nom brut
R('<div class="md">${esc(v.name)} · ${esc(v.codec)}</div>', '<div class="md ${v.fx?"fxd":""}">${esc(v.fx?v.codec:v.name+" · "+v.codec)}</div>')
R("</style>", ".msrc .md.fxd{white-space:normal;line-height:1.35}</style>")
# stockage séparé du simulateur Fire TV
src = src.replace('localStorage.getItem("iptvsim")', 'localStorage.getItem("prisme-atv")')
src = src.replace('localStorage.setItem("iptvsim",', 'localStorage.setItem("prisme-atv",')

# textes Fire restants
for a, b in [("Non compatible avec ton Fire Stick (1080p max)", "Non compatible avec ton Apple TV"),
             ("Source 4K non lisible sur ton Fire TV Stick (1080p max)", "Source non lisible sur ton Apple TV"),
             ("ton Fire TV", "ton appareil"), ("Mon Fire TV", "Mon appareil"),
             ("Appuyez sur Accueil pour revenir au début", "Appuie sur le bouton TV pour revenir au début")]:
    src = src.replace(a, b)


# ------------------------------------------------------------- TV en direct : version A2C
R("</style>", open(os.path.join(D, "live_a2c.css"), encoding="utf-8").read() + open(os.path.join(D, "live_plus.css"), encoding="utf-8").read() + "</style>")
rd = lambda n: open(os.path.join(D, n), encoding="utf-8").read()
R("const FILMS = [", "/* pako 1.0.11 (MIT) : compression du catalogue */\n" + rd("pako.min.js") + "\n" + rd("real_boot.js") + "const FILMS = [")
R("C.filter(c=>c.cat===S.lcat)}", "C.filter(c=>inCatL(c,S.lcat))}")
R('<div class="det sy"><div class="act-top" data-anchor><div class="av" style="--h:${hash(aid)%360}">${initials(n)}</div>', '<div class="det sy"><div class="act-top" data-anchor>${(ph=>`<div class="av${ph?" aph":""}" style="--h:${hash(aid)%360}${ph?`;background-image:url(${ph})`:""}">${ph?"":initials(n)}</div>`)(window.actorPh?actorPh(aid):"")}')
# acteurs : photo (TMDB) quand on l'a, et chaque film/série une seule fois même s'il existe sous plusieurs noms
R('function castCard(aid,role,row){const n=A[aid];return `<div class="cast" data-f data-fid="${row}-${aid}" data-row="${row}" data-act="actor:${aid}"><div class="av" style="--h:${hash(aid)%360}">${initials(n)}</div>', 'function castCard(aid,role,row){const n=A[aid],ph=window.actorPh?actorPh(aid):"";return `<div class="cast" data-f data-fid="${row}-${aid}" data-row="${row}" data-act="actor:${aid}"><div class="av${ph?" aph":""}" style="--h:${hash(aid)%360}${ph?`;background-image:url(${ph})`:""}">${ph?"":initials(n)}</div>')
R('const acred=a=>(CRED[a]||[]).filter(([id])=>srcs(id).length);', 'const acred=a=>{const seen=new Set();return (CRED[a]||[]).filter(([id])=>{const o=ALL[id];if(!o||seen.has(o))return false;seen.add(o);return srcs(id).length}).map(([id,r])=>[ALL[id].id,r])};')
# genres : la table des catégories est construite une fois par type, pas pour chaque titre (des centaines de catégories × des dizaines de milliers de titres)
R('const GK={};', 'const GK={},GKC={};')
R('const D=GDEF[it.type],cl={};(it.type==="f"?FCATS:SCATS).forEach(([k,n])=>cl[k]=n);', 'const D=GDEF[it.type],cl=GKC[it.type]||(GKC[it.type]=Object.fromEntries((it.type==="f"?FCATS:SCATS).map(([k,n])=>[k,n])));')
# fenêtre des sources : la liste suit la sélection (beaucoup de versions d'un film, d'une série ou d'une chaîne)
R('<h2>${esc(title)}</h2><div class="mlist">', '<h2>${esc(title)}</h2><div class="mlist sy">')
# disponibilité : un simple « au moins un fournisseur actif l'a » (sans calculer toutes les sources), gardée le temps d'un affichage
R('const films=()=>FILMS.filter(i=>srcs(i.id).length),series=()=>SERIES.filter(i=>srcs(i.id).length),chans=()=>CHS.filter(c=>srcs("ch:"+c.id).length);', 'const AVM={};const avail=key=>S.playlists.some(p=>p.on&&has(p,key));const films=()=>AVM.f||(AVM.f=Object.freeze(FILMS.filter(i=>avail(i.id)))),series=()=>AVM.s||(AVM.s=Object.freeze(SERIES.filter(i=>avail(i.id)))),chans=()=>AVM.c||(AVM.c=Object.freeze(CHS.filter(c=>avail("ch:"+c.id))));')
R(":C.filter(c=>c.cat===k).length;", ":C.filter(c=>inCatL(c,k)).length;")
R(' ${sec("l","Catégories TV en direct",LCATS.filter(([k])=>k!=="all"&&k!=="fav"))}\n ${sec("f","Catégories films",FCATS.filter(([k])=>k!=="nolan"))}\n ${sec("s","Catégories séries",SCATS)}', ' ${sec("l","Catégories TV en direct",LCATS.filter(([k])=>k!=="all"&&k!=="fav"&&(!REAL||catCount(p,"l",k)>0)))}\n ${sec("f","Catégories films",FCATS.filter(([k])=>k!=="nolan"&&(!REAL||catCount(p,"f",k)>0)))}\n ${sec("s","Catégories séries",SCATS.filter(([k])=>!REAL||catCount(p,"s",k)>0))}')
R('function catCount(pl,type,k){if(type==="l")return CHS.filter(c=>c.cat===k&&base(pl,"ch:"+c.id)).length;return (type==="f"?FILMS:SERIES).filter(i=>base(pl,i.id)&&provCat(pl,i)===k).length}', 'function catCount(pl,type,k){if(type==="l")return CHS.filter(c=>inCatL(c,k)&&base(pl,"ch:"+c.id)).length;return (type==="f"?FILMS:SERIES).filter(i=>base(pl,i.id)&&(i._real&&i._real.c?i._real.c.includes(k):provCat(pl,i)===k)).length}')
R('FILMS.forEach(f=>f.type="f"); SERIES.forEach(s=>s.type="s");', rd("real_block1.js") + 'FILMS.forEach(f=>f.type="f"); SERIES.forEach(s=>s.type="s");')
R("const CH={}; CHS.forEach(c=>CH[c.id]=c);", rd("real_block2.js") + "const CH={}; CHS.forEach(c=>CH[c.id]=c);")
import json as _json, sys as _sys
_sys.path.insert(0, D)
from fx_css import build as _fxbuild
_simcss = src[src.index("<style>"):src.index("</style>")]
import re as _re
# défilement : une section plus haute que l'écran (ex. 100 catégories d'un fournisseur) suit l'élément, pas le haut de la section
R('const a=el.closest("[data-anchor]");const tg=a&&p.contains(a)&&a!==p?a:el;', 'const a=el.closest("[data-anchor]");const tg=a&&p.contains(a)&&a!==p&&a.offsetHeight<=p.clientHeight-20?a:el;')
_jsall = src[src.index("</style>"):] + "".join(rd(n) for n in ["perf_a.js", "live_a2c.js", "real_end.js", "live_home.js", "live_plus.js", "film_ab1.js", "film_home.js", "serie_home.js", "player_b.js", "prov.js", "settings_a.js", "search_b.js", "guide_a.js", "who_a.js", "gouts.js", "fiches.js", "erreurs.js", "liste.js", "apps.js", "perf_z.js"])
_used = set(_re.findall(r"[A-Za-z_][\w-]*", _jsall))
_fxcss, _fxren = _fxbuild(rd("film_ab1.css") + "\n" + rd("film_home.css") + "\n" + rd("serie_home.css"), _simcss, _used)
R("</style>", _fxcss + "\n" + rd("film_ab1_global.css") + rd("film_home_global.css") + rd("player_b.css") + rd("prov.css") + rd("settings_a.css") + rd("search_b.css") + rd("guide_a.css") + rd("who_a.css") + rd("gouts.css") + rd("fiches.css") + rd("erreurs.css") + rd("liste.css") + rd("icones.css") + "</style>")
_pl = rd("prisme-films.pl").replace("\\", "\\\\").replace("`", "\\`").replace("${", "\\${")
RFCMD = "const RFCMD=`cat > /tmp/prisme-films.pl <<'PRISME_FIN'\n" + _pl + "PRISME_FIN\nperl /tmp/prisme-films.pl`;\n"
_ps = rd("prisme-series.pl").replace("\\", "\\\\").replace("`", "\\`").replace("${", "\\${")
RFCMD += "const RSCMD=`cat > /tmp/prisme-series.pl <<'PRISME_FIN'\n" + _ps + "PRISME_FIN\nperl /tmp/prisme-series.pl`;\n"
_fx = rd("prisme-flux.pl")
RXFLUX = "const RCMDSH=" + _json.dumps(rd("prisme-cmd.sh").strip() + " ") + ";\n"
RXFLUX += "const RXFLUX=" + _json.dumps('export PRISME_U="$U" PRISME_N="$N" PRISME_P="$P"; cat > /tmp/prisme-flux.pl <<\'PRISME_FLUX\'\n' + _fx + 'PRISME_FLUX\nperl /tmp/prisme-flux.pl "$D"; unset PRISME_P; ') + ";\n"
R("render();\n</script>", RFCMD + RXFLUX + "const FXR=" + _json.dumps(_fxren) + ";\n" + rd("perf_a.js") + "\n" + rd("live_a2c.js") + "\n" + rd("real_end.js") + "\n" + rd("live_home.js") + "\n" + rd("live_plus.js") + "\n" + rd("film_ab1.js") + "\n" + rd("film_home.js") + "\n" + rd("serie_home.js") + "\n" + rd("player_b.js") + "\n" + rd("prov.js") + "\n" + rd("settings_a.js") + "\n" + rd("search_b.js") + "\n" + rd("guide_a.js") + "\n" + rd("who_a.js") + "\n" + rd("gouts.js") + "\n" + rd("fiches.js") + "\n" + rd("erreurs.js") + "\n" + rd("liste.js") + "\n" + rd("apps.js") + "\n" + rd("perf_z.js") + "\n" + rd("diag_z.js") + "\n" + rd("icones.js") + "\nrender();if(inApp())lPreload(()=>render());\n</script>")
R("const n=SC.streak,st=n<3?10:", 'const n=SC.streak,st=n<3?(window.SAval?[10,15,30][SAval("skip")]:10):')
R('setBg([CH[S.lch].col,"#08080c"])', 'setBg([(CH[S.lch]||{col:"#1a1a22"}).col,"#08080c"])')
R("<kbd>M</kbd> (ou maintenir le clic) ajouter/retirer des favoris", "<kbd>M</kbd> (ou maintenir le clic) favoris, ou options d'une chaîne dans la TV en direct")

R('<div class="pkick">${it.type==="s"?"Série · "+esc(it.net):"Film · "+it.y}', '<div class="pkick">${it.rp?"Replay · "+esc(CH[it.rp.c].n)+" · diffusé "+lday(it.rp.s):it.type==="s"?"Série · "+esc(it.net):"Film · "+it.y}')
# fenêtre des sources et listes du lecteur : défilement par transformation (fiable avec beaucoup de flux, et dans Safari sous le verre)
R('<div class="mlist sy">${L.map', '<div class="mlist sy ty"><div class="ttrack">${L.map')
R('}).join("")}</div><div class="mfoot">OK pour lire cette source', '}).join("")}</div></div><div class="mfoot">OK pour lire cette source')
R('  if(cs.contains("sy")){const a=el.closest("[data-anchor]")', '  if(cs.contains("ty")){tyFollow(p,el,instant)}else if(cs.contains("sy")){const a=el.closest("[data-anchor]")')
R("</style>", rd("defil.css") + "</style>")
# réglages d'un fournisseur : avec des centaines de catégories, on dessine les 60 premières de chaque type, la suite arrive en descendant
R('<div class="grp">${cats.map(([k,l])=>{const hk=type+":"+k,h=hid.includes(hk)', '<div class="grp">${plmCut(p.id,type,cats).map(([k,l])=>{const hk=type+":"+k,h=hid.includes(hk)')
R("function ensureVisible(el,instant){", rd("defil.js") + "function ensureVisible(el,instant){")
R('const norm=s=>s.normalize("NFD")', 'let norm=s=>s.normalize("NFD")')
R(' const dup=[...FILMS,...SERIES].filter(i=>srcs(i.id).length>1).length+CHS.filter(c=>srcs("ch:"+c.id).length>1).length;', ' const dup=RMEMO.dup!=null?RMEMO.dup:(RMEMO.dup=[...FILMS,...SERIES].filter(i=>nsrc(i.id)>1).length+CHS.filter(c=>nsrc("ch:"+c.id)>1).length);')
# logo officiel de prisme (icône de l'écran d'accueil Apple TV)
import base64 as _b64
R("function ensureVisible(el,instant){", 'const PRLOGO="data:image/png;base64,' + _b64.b64encode(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"assets","logo-prisme-192.png"),"rb").read()).decode() + '";\nfunction ensureVisible(el,instant){')
_k = src.index("<script>", src.index("</style>")); src = src[:_k] + "<script>\n" + rd("diag.js") + rd("errh.js") + src[_k+len("<script>"):]
src = src.replace("\nrender();if(inApp())lPreload(()=>render());\n</script>", "\nrender();if(inApp())lPreload(()=>render());window.__prReady=true;DGend();\n</script>")
assert "window.__prReady=true" in src
assert "fire tv" not in src.lower().replace("prisme-firetv", ""), [m.start() for m in re.finditer("(?i)fire ?tv", src)]
open(OUT, "w", encoding="utf-8").write(src)
print("OK", OUT, len(src))
