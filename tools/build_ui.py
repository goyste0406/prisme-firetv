"""Construit assets/web/index.html de l'app à partir du simulateur validé + couche de données Xtream réelle."""
import re, sys, os
D = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.join(D, "simulateur.html")
OUT = sys.argv[1]
src = open(SIM, encoding="utf-8").read()
css = src.split("<style>", 1)[1].split("</style>", 1)[0]
js = src.split("<script>", 1)[1].split("</script>", 1)[0]
data = open(os.path.join(D, "data.js"), encoding="utf-8").read()

def R(a, b, cnt=1):
    global js
    assert a in js, ("MISSING", a[:100])
    js = js.replace(a, b) if cnt == 0 else js.replace(a, b, cnt)

def RX(pat, b, flags=re.S):
    global js
    n = len(re.findall(pat, js, flags)); assert n == 1, (pat, n)
    js = re.sub(pat, lambda m: b, js, flags=flags)

def FN(name, code):
    """Remplace une fonction de premier niveau entière."""
    global js
    m = re.search(r"^(?:async )?function " + re.escape(name) + r"\(", js, re.M)
    assert m, ("FN missing", name)
    nxt = re.search(r"^(function |const |let |/\*|class |document\.|view\.|setInterval|render\(\);)", js[m.end():], re.M)
    end = m.end() + nxt.start() if nxt else len(js)
    js = js[:m.start()] + code.strip() + "\n" + js[end:]

# ---------------------------------------------------------------- données
a = js.index("/* ========================= DONNÉES")
b = js.index("/* ========================= ÉTAT")
js = js[:a] + data + "\n" + js[b:]

# ---------------------------------------------------------------- état
R('const DEFPL={id:"pl1",name:"Ma box IPTV",url:"http://iptv-demo.fr:8080",user:"steven_demo",pass:"demo1234",epg:true,on:true,seed:0};',
  'const DEFPL={id:"pl1",name:"Ma box IPTV",url:"http://",user:"",pass:"",epg:true,on:true,seed:0};')
R('favs:["m3","s2","ch:tf1","ch:f2","ch:bfm"],prog:{m5:.42,s1:.18,m1:.73}', 'favs:[],prog:{}')
R('lch:"tf1"', 'lch:""')
R('meta:{imdb:true,', 'tmdbKey:"",meta:{imdb:true,')
R('localStorage.getItem("iptvsim")', 'localStorage.getItem("prisme")')
R('localStorage.setItem("iptvsim"', 'localStorage.setItem("prisme"')
R('let S={', 'let S={booting:false,')

FN("base", 'function base(pl,key){const it=key.startsWith("ch:")?CH[key.slice(3)]:ALL[key];return !!it&&it.src.some(s=>s.pl===pl.id)}')
FN("provCat", 'function provCat(pl,it){const s=it&&it.src.find(s=>s.pl===pl.id);return s?s.cat:""}')
FN("provKey", 'function provKey(pl,key){if(key.startsWith("ch:"))return "l:"+provCat(pl,CH[key.slice(3)]);const it=ALL[key];return it.type+":"+provCat(pl,it)}')
FN("catCount", 'function catCount(pl,type,k){const L=type==="l"?CHS:type==="f"?FILMS:SERIES;return L.filter(i=>i.src.some(s=>s.pl===pl.id&&s.cat===k)).length}\nfunction plCats(pl,t){const D=DATA[pl.id];if(!D)return[];const m=t==="l"?D.lc:t==="f"?D.vc:D.sc,seen=new Set();return Object.values(m).map(n=>[catKey(n),n]).filter(([k])=>!seen.has(k)&&seen.add(k))}')
R('const qr=q=>({"4K":4,"1080p":3,"720p":2,"SD":1})[q]||0;', 'const qr=q=>({"4K":4,"1080p":3,"Auto":2.5,"720p":2,"SD":1})[q]||0;')
FN("variants", '''function variants(pl,key){const ch=key.startsWith("ch:"),it=ch?CH[key.slice(3)]:ALL[key];if(!it)return[];const kind=ch?"l":it.type==="f"?"v":"s";
 return it.src.filter(s=>s.pl===pl.id).map((s,i)=>{const k=qkey(pl.id,kind,s.sid),qi=QUAL[k]&&QUAL[k].ok?QUAL[k]:null,pend=!!QPEND[k],fail=!!(QUAL[k]&&!QUAL[k].ok);
  const q=qi?qi.q:(s.q!=="Auto"?s.q:(pend?"Analyse…":fail?"Inconnue":"Auto"));
  const tagAudio=ch?"Selon la chaîne":s.tag==="MULTI"?"Multi-langues (VF + VO)":s.tag==="VOSTFR"||s.tag==="VO"?"Version originale":"Français (VF)";
  return {id:pl.id+"|"+s.sid,i,p:pl,q,qi,hdr:!!(qi&&qi.hdr),tag:s.tag||"",sid:s.sid,ext:s.ext||"ts",name:s.name,
   codec:qi?`${qi.vc||"Vidéo"} · ${qi.w}×${qi.h}${qi.fps?" · "+qi.fps+" i/s":""}${qi.hdr?" · HDR":""}`:pend?"Analyse du flux en cours…":fail?"Analyse impossible (flux injoignable ou connexion déjà utilisée)":"Qualité lue dans le nom du flux",
   audio:qi&&qi.audio&&qi.audio.length?qi.audio.map(a=>[a.lang||"Langue non précisée",[a.codec,a.ch].filter(Boolean).join(" ")].filter(Boolean).join(" · ")):[tagAudio],
   subs:qi&&qi.subs?(qi.subs.length?qi.subs.map(x=>x.lang||"Piste sans langue"):["Aucun"]):[s.tag==="VOSTFR"?"Français":"Non communiqués"],size:"—"}})}''')
R('<span class="qb q${v.q}">${v.q==="4K"?"4K HDR":v.q}</span><span class="pn">', '<span class="qb q${v.q}">${v.q==="4K"&&v.hdr?"4K HDR":v.q}</span><span class="pn">')
R('<dt>Fichier</dt><dd>${esc(v.size)} · .${v.ext}</dd>', '<dt>Format</dt><dd>.${esc(v.ext)}${v.qi?" · infos "+esc(v.qi.from||""):""}</dd>')
R('function modalHtml(){const m=S.modal,', 'function modalHtml(){if(!P)setTimeout(()=>analyze(S.modal&&S.modal.k||""),30);const m=S.modal,')
R('mt==="chs"?(P?chsHtml():""):modalHtml()', 'mt==="chs"?(P?chsHtml():""):mt==="ctry"?ctryHtml():modalHtml()')
R('lcat:S.lcat,', 'lcat:S.lcat,ctry:S.ctry,')
FN("liveList", '''function chansC(){return memo("cc"+S.ctry,()=>chans().filter(c=>S.ctry==="*"||c.country===S.ctry))}
function liveList(){const C=chansC();return S.lcat==="all"?C:S.lcat==="fav"?chans().filter(c=>isFav("ch:"+c.id)):C.filter(c=>c.genre===S.lcat)}
function ctryHtml(){const L=[["*",CHS.length],...COUNTRIES];return `<div class="modal"><div class="mbox" style="width:600px"><div class="kick">TV en direct</div><h2>Pays des chaînes</h2><div class="tcol sy" style="max-height:440px">${L.map(([k,n])=>`<div class="trk ${k===S.ctry?"on":""}" data-f data-fid="cy-${k}" data-act="setctry:${k}" ${k===S.ctry?"data-default":""}><span>${esc(k==="*"?"Tous les pays":PAYS[k]||k)}<small>${n} chaîne${n>1?"s":""}</small></span>${k===S.ctry?'<span class="ck">✓</span>':""}</div>`).join("")}</div><div class="mfoot">Les genres se mettent à jour selon le pays choisi</div></div></div>`}''')
R('const cats=LCATS.filter(([k])=>k==="all"||k==="fav"||!rowHidden("l",k)).map(([k,l])=>{const C=chans(),n=k==="all"?C.length:k==="fav"?C.filter(c=>isFav("ch:"+c.id)).length:C.filter(c=>c.cat===k).length;',
  'const C=chansC(),cnt=k=>k==="all"?C.length:k==="fav"?chans().filter(c=>isFav("ch:"+c.id)).length:C.filter(c=>c.genre===k).length;\n const cats=(COUNTRIES.length>1?`<div class="lcat" data-f data-fid="lcat-ctry" data-row="lcats" data-act="ctry"><span>${esc(S.ctry==="*"?"Tous les pays":PAYS[S.ctry]||S.ctry)}</span><small>changer ›</small></div>`:"")+LCATS.filter(([k])=>k==="all"||k==="fav"||cnt(k)>0).map(([k,l])=>{const n=cnt(k);')
R('  case "srcplay":', '  case "ctry":S.modal={type:"ctry",ret:"lcat-ctry"};render("cy-"+S.ctry);break;\n  case "setctry":S.ctry=v;S.modal=null;S.lcat="all";save();render("lcat-ctry");break;\n  case "srcplay":')
R('function detailHtml(it){\n', 'function detailHtml(it){\n setTimeout(()=>analyze(it.id),60);\n')
# appareil réel + versions
RX(r'const APP=\{ver:"1\.0\.0".*?\nconst LATEST=\{.*?\n', '''const APPV=NATIVE?JSON.parse(Prisme.appVersion()):{name:"web",code:0};
const APP={ver:APPV.name,code:APPV.code,repo:"github.com/goyste0406/prisme-firetv"};
const UPD_URL="https://github.com/goyste0406/prisme-firetv/releases/latest/download/version.json";
let LATEST=null;
const DEV=NATIVE?JSON.parse(Prisme.device()):{model:"",sdk:0,display:""};
const DEVNAMES={AFTSSS:"Fire TV Stick (3e génération)",AFTSS:"Fire TV Stick Lite",AFTT:"Fire TV Stick (2e génération)",AFTMM:"Fire TV Stick 4K",AFTKA:"Fire TV Stick 4K Max",AFTKM:"Fire TV Stick 4K (2023)",AFTKRT:"Fire TV Stick 4K Max (2023)",AFTR:"Fire TV Cube",AFTGAZL:"Fire TV Cube (3e génération)"};
const UHD=/^AFT(MM|KA|KM|KRT|R|GAZL|N|EU)/.test(DEV.model||"");
const ANDROID={25:"7.1",26:"8",27:"8.1",28:"9",29:"10",30:"11",31:"12",32:"12L",33:"13",34:"14"};
''')
RX(r'const DEVICE=\{name:"Fire TV Stick \(3e génération\)".*?\};', '''const DEVICE={name:DEVNAMES[DEV.model]||("Fire TV "+(DEV.model||"")),os:`${DEV.display||"Fire OS"} · Android ${ANDROID[DEV.sdk]||DEV.sdk}`,maxQ:UHD?"4K":"1080p",hdr:"HDR10, HDR10+, HLG",audio:"Dolby Atmos, AC3, E-AC3 (sortie directe)",ram:"",codecs:UHD?"H.264, HEVC, VP9, AV1 jusqu'en 4K":"H.264, HEVC, VP9 jusqu'en 1080p 60 i/s"};''')
R('const films=()=>FILMS.filter(i=>srcs(i.id).length),series=()=>SERIES.filter(i=>srcs(i.id).length),chans=()=>CHS.filter(c=>srcs("ch:"+c.id).length);',
  '''const memo=(k,f)=>{if(MEMO[k]&&MEMO[k].v===CATV)return MEMO[k].r;const r=f();MEMO[k]={v:CATV,r};return r};
const films=()=>memo("f",()=>FILMS.filter(i=>srcs(i.id).length)),series=()=>memo("s",()=>SERIES.filter(i=>srcs(i.id).length)),chans=()=>memo("c",()=>CHS.filter(c=>srcs("ch:"+c.id).length));''')

# ---------------------------------------------------------------- fragments
FN("poster", '''function poster(it,nw){const img=it.img?`<img src="${esc(it.img)}" alt="" loading="lazy" decoding="async" onerror="this.parentNode.classList.remove('has-img');this.remove()">`:"";
 return `<div class="pst f-${it.f} sh${hash(it.id)%4} ${img?"has-img":""}" style="--a:${it.c[0]};--b:${it.c[1]}">${img}<div class="pst-in">${nw?'<span class="newb">Ajouté récemment</span>':`<span class="pst-k">${it.type==="s"?"SÉRIE":(it.y||"")}</span>`}<span class="pst-t">${esc(it.t)}</span></div></div>`}
function logoHtml(c,st=""){return `<span class="logo ${c.logo?"has-img":""}" style="--c:${c.col};${st}">${c.logo?`<img src="${esc(c.logo)}" alt="" loading="lazy" onerror="this.parentNode.classList.remove('has-img');this.remove()">`:""}<b>${esc(c.n)}</b></span>`}''')
R('function rowHtml(id,title,items,fn,count=true){if(!items.length)return"";return `<section class="row" data-anchor><h3>${esc(title)}${count?`<small>${items.length}</small>`:""}',
  'function rowHtml(id,title,items,fn,count=true){if(!items.length)return"";const total=items.length;items=items.slice(0,40);return `<section class="row" data-anchor><h3>${esc(title)}${count?`<small>${total}</small>`:""}')
FN("rval", '''function rval(it,k){if(k==="imdb")return it.imdb?it.imdb.toFixed(1):null;if(k==="tmdb")return it.tmdb?(it.tmdb/10).toFixed(1).replace(".",",")+"/10":null;const v=(RX[it.id]||{})[k];if(v==null)return null;
 return k==="rt"?v+" %":k==="mc"?String(v):k==="lb"?v.toFixed(1)+"/5":k==="ac"?v.toFixed(1).replace(".",",")+"/5":v.toFixed(1).replace(".",",")+"/10"}''')
FN("addDays", "")
FN("added", '''function added(id){const it=ALL[id];if(!it)return null;let best=null;const now=Date.now();
 it.src.forEach(s=>{const p=S.playlists.find(x=>x.id===s.pl&&x.on);if(!p||!s.added||(p.hidden||[]).includes(it.type+":"+s.cat))return;const d=Math.max(0,Math.floor((now-s.added*1000)/86400000));if(!best||d<best.d)best={d,p}});return best}''')
FN("trendScore", '''function trendScore(i){const L=TREND[i.type]||[],r=L.indexOf(i);if(r>=0)return 1000-r;const a=added(i.id);return (a?Math.max(0,45-a.d):0)+(i.tmdb||0)*.4+(i.y>=new Date().getFullYear()-1?15:0)}''')
FN("recoPct", 'function recoPct(i){return i.tmdb||0}')
R('const recoCard=(it,row)=>card(it,row,"",`<div class="reco">♥ ${recoPct(it)} % recommandent</div>`);',
  'const recoCard=(it,row)=>card(it,row,"",it.tmdb?`<div class="reco">★ ${(it.tmdb/10).toFixed(1).replace(".",",")}/10 · spectateurs</div>`:"");')
FN("metaLine", '''function metaLine(it,withR=true){const parts=(it.type==="f"?[it.y||"",it.d?dur(it.d):"",it.g.join(" · ")]:[it.y||"",it.se.length?`${it.se.length} saison${it.se.length>1?"s":""}`:"",it.g.join(" · "),it.net]).filter(Boolean);
 return `<div class="meta">${parts.map(esc).join('<span style="opacity:.4">•</span>')}${it.age?`<span class="badge">${esc(it.age)}</span>`:""}${withR?ratings(it,2):""}</div>`}
const catName=it=>((it.type==="f"?FCATS:SCATS).find(c=>c[0]===it.cat[0])||[,""])[1];''')
R('function heroInner(it){return `<div class="kick">${it.type==="f"?"Film":"Série"} · ${esc(it.g[0])}</div><h1 class="ttl f-${it.f}">${esc(it.t)}</h1>${metaLine(it)}<div class="syn">${esc(it.s)}</div>`}',
  'function heroInner(it){return `<div class="kick">${it.type==="f"?"Film":"Série"} · ${esc(it.g[0]||catName(it))}</div><h1 class="ttl f-${it.f}">${esc(it.t)}</h1>${metaLine(it)}<div class="syn">${esc(it.s||"")}</div>`}')
FN("setBg", '''function setBg(c,img){const L=document.querySelectorAll(".bgl");const on=L[0].classList.contains("on")?0:1;const nx=L[1-on];
 const g=`radial-gradient(55% 75% at 78% 28%, ${c[0]}d0, transparent 70%), radial-gradient(45% 60% at 30% 85%, ${c[1]}, transparent 70%), radial-gradient(30% 40% at 60% 60%, ${c[0]}55, transparent 70%), linear-gradient(160deg, ${c[1]}, #050507 80%)`;
 nx.style.background=img?`linear-gradient(90deg, rgba(0,0,0,.35), rgba(0,0,0,0) 60%), url("${img}") center/cover no-repeat, ${g}`:g;
 nx.classList.add("on");L[on].classList.remove("on")}''')

# ---------------------------------------------------------------- écrans
R('+rowHtml("trend",ty==="f"?"Top 10 des films du moment · tendances Trakt et TMDB":"Top 10 des séries du moment · tendances Trakt et TMDB",trend,',
  '+rowHtml("trend",(ty==="f"?"Top 10 des films du moment":"Top 10 des séries du moment")+(TREND[ty].length?" · tendances TMDB de la semaine":" · nouveautés les mieux notées"),trend,')
R('+rowHtml("reco","Recommandés par la communauté · Trakt",reco,recoCard,false)', '+rowHtml("reco","Recommandés · notes des spectateurs",reco,recoCard,false)')
R('const reco=[...list].sort((a,b)=>recoPct(b)-recoPct(a)).slice(0,12);', 'const reco=list.filter(i=>i.tmdb>0).sort((a,b)=>recoPct(b)-recoPct(a)).slice(12,24);')
R('const top=[...list].sort((a,b)=>b.tmdb-a.tmdb).slice(0,10);', 'const top=list.filter(i=>i.tmdb>0).sort((a,b)=>b.tmdb-a.tmdb).slice(0,12);')
R('cats.forEach(([k,l])=>{if(k!=="nolan"&&rowHidden(ty,k))return;', 'cats.slice(0,40).forEach(([k,l])=>{if(rowHidden(ty,k))return;')
R("'<div class=\"syn\">Aucun contenu : activez une playlist dans Réglages.</div>'", "'<div class=\"syn\">Aucun contenu pour l\\'instant : vérifie tes playlists dans Réglages.</div>'")
R(' const chs=L.map(c=>{const e=epgAt(c);return `<div class="lch"', ' L.slice(0,30).forEach(c=>epg(c));\n const chs=L.slice(0,400).map(c=>{const e=epgAt(c);return `<div class="lch"')
R('<span class="num">${c.num}</span><span class="logo" style="--c:${c.col}">${esc(c.n)}</span>', '<span class="num">${c.rank<999?c.rank:c.num}</span>${logoHtml(c)}')
R('<div class="lcats" data-col="1">', '<div class="lcats sy" data-col="1">')
R(' const c=CH[S.lch]&&L.includes(CH[S.lch])?CH[S.lch]:(L[0]||CHS[0]);', ' const c=CH[S.lch]&&L.includes(CH[S.lch])?CH[S.lch]:(L[0]||CHS[0]);if(c)S.lch=c.id;')
R('<div class="lpanel" id="lpanel">${panelHtml(c)}</div>', '<div class="lpanel" id="lpanel">${c?panelHtml(c):\'<div class="empty">Aucune chaîne dans tes playlists.</div>\'}</div>')
R('<span class="livebadge">EN DIRECT</span><span class="logo" style="--c:${c.col}">${esc(c.n)}</span><div class="wm">Aperçu simulé · ${esc(c.n)} ${c.q}</div>',
  '<span class="livebadge">EN DIRECT</span>${logoHtml(c)}<div class="wm">OK pour regarder ${esc(c.n)}</div>')
R('if(k==="ch"){S.lch=v;const p=$("#lpanel");if(p)p.innerHTML=panelHtml(CH[v]);setBg([CH[v].col,"#08080c"]);return}',
  'if(k==="ch"){S.lch=v;epg(CH[v]);const p=$("#lpanel");if(p)p.innerHTML=panelHtml(CH[v]);setBg([CH[v].col,"#08080c"]);return}')
R('if(ALL[h]&&topS().t==="home"){const hr=$("#hero");if(hr){hr.innerHTML=heroInner(ALL[h]);fitAll(hr)}setBg(ALL[h].c)}',
  'if(ALL[h]&&topS().t==="home"){const hr=$("#hero");if(hr){hr.innerHTML=heroInner(ALL[h]);fitAll(hr)}setBg(ALL[h].c,ALL[h].bd)}')
R('return {f:films().filter(i=>m(i.t)||m(i.dir)),s:series().filter(i=>m(i.t)),a:Object.keys(A).filter(k=>m(A[k])&&acred(k).length).slice(0,14)};',
  'return {f:films().filter(i=>m(i.t)||m(i.dir)).slice(0,40),s:series().filter(i=>m(i.t)).slice(0,40),a:Object.keys(A).filter(k=>m(A[k])&&acred(k).length).slice(0,14)};')

# réglages
R('<span>prisme ${esc(S.appVer)} (build ${S.appCode})</span>', '<span>prisme ${esc(APPV.name)} (build ${APPV.code})</span>')
R('<span>${S.appCode>=LATEST.code?"Tu as la dernière version":"Version "+LATEST.ver+" disponible"}</span>',
  '<span>${LATEST?(LATEST.code>APPV.code?"Version "+LATEST.ver+" disponible":"Tu as la dernière version"):"Appuie pour vérifier"}</span>')
R('<span>${DEVICE.ram} de RAM</span>', '<span>${esc(DEV.model||"")}</span>')
R('<span>${on.length} × xmltv.php · ${epgCount()} programmes</span>', '<span>Guide court Xtream · ${epgCount()} programmes en mémoire</span>')
R('<div class="it" data-f data-fid="set-epgauto" data-act="set:epgAuto"><span>Téléchargement automatique au démarrage</span>${sw(st.epgAuto)}</div>\n', '')
R('<div class="it" data-f data-fid="set-epg" data-act="epg"><span>Actualiser l\'EPG maintenant</span><span>Dernière mise à jour : ${S.epgAt?fmt(S.epgAt):"—"}</span></div>',
  '<div class="it" data-f data-fid="set-epg" data-act="epg"><span>Actualiser le guide TV maintenant</span><span>Chargé automatiquement chaîne par chaîne</span></div>')
R('<small>MDBList (IMDb, RT, Metacritic, Letterboxd, Trakt) · What\'s on? (AlloCiné, SensCritique)</small>',
  '<small>Prochaine version : MDBList (IMDb, RT, Metacritic, Letterboxd) · What\'s on? (AlloCiné, SensCritique)</small>')
R('<small>Trakt (tendances, titres recommandés) · TMDB (tendances de la semaine)</small></span><span></span></div>',
  '''<small>TMDB (tendances de la semaine, filmographies) · nécessite une clé gratuite</small></span><span></span></div>
  <div class="it tall"><span>Clé API TMDB<small>themoviedb.org › Paramètres › API · ${S.set.tmdbKey?"enregistrée":"non renseignée"}</small></span><input class="inp" id="f-tmdb" data-f data-fid="f-tmdb" style="width:360px;height:46px" value="${esc(S.set.tmdbKey||"")}" placeholder="Clé API (v3)" spellcheck="false"></div>''')
R('<div class="it tall"><span>Fiches, affiches et casting<small>TMDB · logos des titres : Fanart.tv · séries : TVmaze</small></span>',
  '<div class="it tall"><span>Fiches, affiches et casting<small>Fournis par tes serveurs Xtream (get_vod_info, get_series_info)</small></span>')
for t, lbl in (("l", "Catégories TV en direct"), ("f", "Catégories films"), ("s", "Catégories séries")):
    pass
R('${sec("l","Catégories TV en direct",LCATS.filter(([k])=>k!=="all"&&k!=="fav"))}', '${sec("l","Catégories TV en direct",plCats(p,"l"))}')
R('${sec("f","Catégories films",FCATS.filter(([k])=>k!=="nolan"))}', '${sec("f","Catégories films",plCats(p,"f"))}')
R('${sec("s","Catégories séries",SCATS)}', '${sec("s","Catégories séries",plCats(p,"s"))}')

# fiche
R('function detailHtml(it){\n', 'function detailHtml(it){\n if(!it.info&&!it.loading)setTimeout(()=>loadInfo(it),0);\n')
R('if(it.type==="s"){const ss=S.seasons[it.id]||1;playLbl=p?`Reprendre S${ss} E1`:"Lecture S1 E1"}',
  'if(it.type==="s"){const ss=S.seasons[it.id]||1;playLbl=!it.info?"Chargement…":`Lecture S${(it.seasons||[])[ss-1]||1} E1`}')
R('${it.id==="s8"?"Livre "+["I","II","III","IV","V","VI"][i]:"Saison "+(i+1)}', 'Saison ${(it.seasons||[])[i]??(i+1)}')
R('<div class="syn">${esc(it.s)}</div>\n   <div class="crew">', '<div class="syn">${esc(it.s||(it.info?"":"Chargement de la fiche…"))}</div>\n   <div class="crew">')
R('<div class="crew"><b>${it.type==="f"?"Réalisation":"Création"} :</b> ${esc(it.dir)}<br><b>Avec :</b> ${it.cast.slice(0,3).map(c=>esc(A[c[0]])).join(", ")}',
  '<div class="crew">${it.dir?`<b>${it.type==="f"?"Réalisation":"Création"} :</b> ${esc(it.dir)}<br>`:""}${it.cast.length?`<b>Avec :</b> ${it.cast.slice(0,3).map(c=>esc(A[c[0]]||c[2]||"")).join(", ")}`:""}')
R('<section class="row" data-anchor><h3>Distribution</h3><div class="sx">${it.cast.map(([a,r])=>castCard(a,r,"cast")).join("")}</div></section>',
  '${it.cast.length?`<section class="row" data-anchor><h3>Distribution</h3><div class="sx">${it.cast.map(([a,r])=>castCard(a,r,"cast")).join("")}</div></section>`:""}')
R('x.type===it.type&&x.g.some(g=>it.g.includes(g))).slice(0,12);', 'x.type===it.type&&(it.g.length?x.g.some(g=>it.g.includes(g)):x.cat[0]===it.cat[0])).slice(0,12);')
FN("epsHtml", '''function epsHtml(it,ss){if(!it.info)return '<div class="empty" style="padding-left:6px">Chargement des épisodes…</div>';const sn=(it.seasons||[])[ss-1],L=(it.eps||{})[sn]||[];
 return L.map(e=>`<div class="ep" data-f data-fid="ep-${ss}-${e.num}" data-row="eps" data-act="play:${it.id}:${ss}:${e.num}"><div class="eth" style="--a:${it.c[0]};--b:${it.c[1]};--x:${20+(e.num*37)%60}%">${e.img?`<img src="${esc(e.img)}" alt="" loading="lazy" onerror="this.remove()" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover">`:""}<span>S${sn} · E${e.num}</span>${e.q?`<b class="qb q${e.q}" style="position:absolute;right:10px;top:10px;z-index:1;height:22px;font-size:11px">${e.q}</b>`:""}</div><div class="et">${esc(e.t)}</div><div class="ed">${e.dur?e.dur+" min":""}</div></div>`).join("")}
function curEpOf(it,ss,ep){return ((it.eps||{})[(it.seasons||[])[ss-1]]||[]).find(e=>e.num===ep)}
function curEp(){return P&&ALL[P.id]&&ALL[P.id].type==="s"?curEpOf(ALL[P.id],P.ss,P.ep):null}
function nextEp(it){const L=(it.eps||{})[(it.seasons||[])[P.ss-1]]||[],i=L.findIndex(e=>e.num===P.ep);if(i>=0&&i<L.length-1)return {ss:P.ss,ep:L[i+1].num};const n=((it.eps||{})[(it.seasons||[])[P.ss]]||[])[0];return n?{ss:P.ss+1,ep:n.num}:null}''')
R('const n=A[aid],cr=acred(aid);', 'const n=A[aid]||"",cr=acred(aid);if(S.set.tmdbKey&&!ACTD[aid])loadActor(aid);')
R('sur votre serveur · filmographie TMDB</p>', 'dans ton catalogue${S.set.tmdbKey?" · filmographie TMDB":" · ajoute une clé TMDB pour la filmographie complète"}</p>')
R('function actorHtml(aid){', '''const ACTD={};
async function loadActor(aid){ACTD[aid]=1;try{const s=await tmdb("search/person?query="+encodeURIComponent(A[aid]||""));const id=s&&s.results&&s.results[0]&&s.results[0].id;if(!id)return;
 const c=await tmdb(`person/${id}/combined_credits`);const L=CRED[aid]=CRED[aid]||[];
 (c&&c.cast||[]).forEach(r=>{const ti=norm(r.title||r.name||""),tid=String(r.id),pool=r.media_type==="tv"?SERIES:FILMS;const it=pool.find(i=>i.tmdbId===tid)||pool.find(i=>norm(i.t)===ti);if(it&&!L.some(x=>x[0]===it.id))L.push([it.id,r.character||""])});
 if(topS().t==="actor"&&topS().id===aid)render(F&&F.dataset.fid)}catch(e){}}
function actorHtml(aid){''')

# connexion / chargement
FN("loadingHtml", '''function loadingHtml(){const f=S.form,st=[["Authentification","player_api.php"],["Catégories TV, films et séries","get_*_categories"],["Chaînes en direct","get_live_streams"],["Films","get_vod_streams"],["Séries","get_series"],["Fusion du catalogue",S.playlists.length?"dédoublonnage":"organisation"]];
 return `<div class="login"><div class="lpanel2"><h2><i></i>Connexion à ${esc(f.name||"la playlist")}</h2><p class="sub">${esc(f.url)}</p><ul class="steps" id="steps">${st.map(([a,b])=>`<li><span class="dot"></span>${a}<code>${b}</code></li>`).join("")}</ul></div></div>`}
function bootHtml(){return `<div class="login"><div class="lpanel2" style="width:560px"><h2><i></i>prisme</h2><p class="sub">Chargement de ${S.playlists.length>1?`tes ${S.playlists.length} playlists`:"ta playlist"}…</p><ul class="steps">${S.playlists.map(p=>`<li class="${p.bootSt||"run"}"><span class="dot">${p.bootSt==="done"?"✓":""}</span>${esc(p.name)}<code>${esc(p.bootMsg||"")}</code></li>`).join("")}</ul></div></div>`}''')
R("${s.epg?`<br>GET <b>${esc(u)}/xmltv.php</b> (EPG)`:\"\"}", '')
R('<div class="lrow"><div class="opt" data-f data-fid="f-epg" data-act="form:epg">${sw(s.epg)}<span>EPG automatique</span></div>', '<div class="lrow"><div class="opt" data-f data-fid="f-epg" data-act="form:epg">${sw(s.epg)}<span>Guide TV automatique</span></div>')
FN("doLogin", '''async function doLogin(){
 const f=S.form,u=clean(f.url);
 if(!/^https?:\\/\\/.+/.test(u)){toast("L'URL doit commencer par http:// ou https://");return}
 if(!f.user||!f.pass){toast("Renseigne le nom d'utilisateur et le mot de passe");return}
 if(S.playlists.some(p=>clean(p.url)===u&&p.user===f.user.trim())){toast("Cette playlist est déjà dans ta liste");return}
 const first=!S.playlists.length,b={f:films().length,s:series().length,c:chans().length};
 const pl={id:"pl"+Date.now().toString(36),name:(f.name||"").trim()||"Playlist "+(S.playlists.length+1),url:u,user:f.user.trim(),pass:f.pass,epg:f.epg,on:true,hidden:[]};
 S.loading=true;render();
 const lis=[...document.querySelectorAll("#steps li")],mark=i=>{lis.forEach((li,j)=>{li.className=j<i?"done":j===i?"run":"";const d=li.querySelector(".dot");if(d)d.textContent=j<i?"✓":""})};
 try{await loadPlaylist(pl,mark);mark(5);S.playlists.push(pl);buildCatalog();mark(6);
  S.loading=false;S.adding=false;S.stack=[{t:"home"}];save();loadTrends();
  if(first){S.tab="films";render();toast(`Connecté · ${chans().length} chaînes · ${films().length} films · ${series().length} séries`)}
  else{S.tab="settings";render("set-add");toast(`${pl.name} ajoutée : +${films().length-b.f} films, +${series().length-b.s} séries, +${chans().length-b.c} chaînes`)}
 }catch(e){S.loading=false;render("f-url");toast("Connexion impossible : "+e.message)}
}
async function boot(){if(!S.playlists.length){render();return}S.booting=true;render();
 await Promise.all(S.playlists.map(async p=>{try{await loadPlaylist(p);p.bootSt="done";p.bootMsg="ok"}catch(e){p.bootSt="";p.bootMsg=e.message}if(S.booting)render()}));
 buildCatalog();S.booting=false;S.playlists.filter(p=>p.bootMsg&&p.bootMsg!=="ok").forEach(p=>setTimeout(()=>toast(`${p.name} : ${p.bootMsg}`),1200));
 render();loadTrends().then(()=>{if(topS().t==="home"&&(S.tab==="films"||S.tab==="series"))render(F&&F.dataset.fid)})}''')
R('  case "addpl":S.adding=true;S.showPw=false;S.form={name:"Box secondaire",url:"http://iptv-secours.fr:25461",user:"steven2",pass:"demo5678",epg:true};render("f-url");break;',
  '  case "addpl":S.adding=true;S.showPw=false;S.form={name:"Playlist "+(S.playlists.length+1),url:"http://",user:"",pass:"",epg:true};render("f-url");break;')
R('S.playlists=S.playlists.filter(p=>p.id!==w);save();', 'S.playlists=S.playlists.filter(p=>p.id!==w);delete DATA[w];buildCatalog();save();')
R('if(v==="on"){pl.on=!pl.on;save();', 'if(v==="on"){pl.on=!pl.on;bump();save();')
R('if(pl.hidden.includes(hk))pl.hidden=pl.hidden.filter(k=>k!==hk);else pl.hidden.push(hk);save();', 'if(pl.hidden.includes(hk))pl.hidden=pl.hidden.filter(k=>k!==hk);else pl.hidden.push(hk);bump();save();')
R('case "hideall":{const pl=S.playlists.find(p=>p.id===v);pl.hidden=[];save();', 'case "hideall":{const pl=S.playlists.find(p=>p.id===v);pl.hidden=[];bump();save();')
RX(r'  case "plref":\{.*?break\}\n', '''  case "plref":{const pl=S.playlists.find(p=>p.id===v);toast(`Actualisation de ${pl.name}…`);loadPlaylist(pl).then(()=>{buildCatalog();save();render(F&&F.dataset.fid);toast(`${pl.name} à jour`)}).catch(e=>toast("Échec : "+e.message));break}\n''')
RX(r'  case "epg":toast\(.*?\n', '''  case "epg":Object.keys(EPGC).forEach(k=>delete EPGC[k]);toast("Guide TV rechargé");render(F.dataset.fid);break;\n''')
R('  case "trailer": toast("Bande-annonce : récupérée via TMDB (/videos) dans l\'application réelle");break;',
  '  case "trailer": toast(ALL[v]&&ALL[v].trailer?"Bande-annonce YouTube : lecture prévue dans une prochaine version":"Pas de bande-annonce fournie par le serveur");break;')

# ---------------------------------------------------------------- lecteur natif
FN("streamUrl", '''function streamUrl(mask){const v=curVar();if(!v)return"";const s=v.p,u=clean(s.url),us=encodeURIComponent(s.user),pw=mask?"••••":encodeURIComponent(s.pass);
 if(P.kind==="live")return `${u}/live/${us}/${pw}/${v.sid}.${s.fmt==="m3u8"?"m3u8":"ts"}`;
 const it=ALL[P.id];if(it.type==="f")return `${u}/movie/${us}/${pw}/${v.sid}.${v.ext}`;
 const e=curEp();return e?`${u}/series/${us}/${pw}/${e.id}.${e.ext}`:""}''')
R('`Saison ${P.ss} · Épisode ${P.ep} · ${it.ep} min`', '`Saison ${(it.seasons||[])[P.ss-1]||P.ss} · Épisode ${P.ep}${curEp()?" · "+curEp().t:""}`')
RX(r'\$\{\(\(\)=>\{let ss=P\.ss,ep=P\.ep\+1;.*?\}\)\(\)\}', '${(n=>n?`S${(it.seasons||[])[n.ss-1]} · E${n.ep}`:"Fin de la série")(nextEp(it))}')
FN("infoBox", '''function infoBox(){const v=curVar()||{name:"",audio:["—"],subs:["—"]},st=P.nst||{};return `<div class="pinfo"><b>Playlist</b> ${esc(srcName())} · <b>Lecteur</b> ExoPlayer (Media3)<br><b>Flux</b> ${esc(v.name||"")}<br><code>${esc(streamUrl(true))}</code><br><b>Vidéo</b> ${esc(st.video||"en attente")}<br><b>Audio</b> ${esc(curAudio()?curAudio().n+" "+(curAudio().c||""):"—")} · <b>Sous-titres</b> ${esc(curSub()||"désactivés")}${st.buffering?" · <b>Mise en mémoire tampon…</b>":""}</div>`}''')
FN("startPlayer", '''function startPlayer(p){P=p;P.ui=true;P.audio=null;P.sub=null;clearInterval(PT);PT=setInterval(tick,500);uiPing();
 if(NATIVE){const u=streamUrl();if(!u){toast("Flux introuvable");return}Prisme.play(u,Math.round((p.pos||0)*1000),p.kind==="live");Prisme.setFormat(curFmt()[0])}}''')
FN("tick", '''function tick(){if(!P)return;
 if(NATIVE){let st={};try{st=JSON.parse(Prisme.state()||"{}")}catch(e){}P.nst=st;
  if(st.pos!=null&&!SC.on){P.pos=st.pos/1000;if(st.dur>0)P.dur=st.dur/1000}
  if(st.error&&!P.err){P.err=1;toast("Lecture impossible : "+st.error);const s=srcs(curKey()).filter(compat);if(s.length>1)toast("Essaie une autre source avec le bouton Source")}
  if(st.ended&&!P.endH){P.endH=1;const it=ALL[P.id];if(P.kind==="vod"&&it&&it.type==="s"){const n=nextEp(it);if(n){act("p:nextep");return}}toast("Lecture terminée");back();return}
  if(P.kind==="vod"&&P.aSync==null&&st.audio&&st.audio.length){P.aSync=1;if(P.audio==null)P.audio=Math.max(0,st.aSel);if(P.sub==null)P.sub=st.sSel}}
 else if(P.kind==="vod"&&P.playing&&!SC.on)P.pos=Math.min(P.dur,P.pos+.5);
 if(P.kind==="vod"&&!SC.on){const b=$("#pbar");if(b&&P.dur>0){b.style.width=(P.pos/P.dur*100)+"%";$("#ptime").textContent=hms(P.pos);$("#prem").textContent="−"+hms(P.dur-P.pos)}}
 if(P.ui&&!SC.on&&Date.now()-P.last>5000&&!P.info){P.ui=false;const o=$("#pov");if(o)o.classList.add("hid")}}''')
R('$("#pthsc").textContent=(it.type==="s"?`S${P.ss} E${P.ep} · `:"")+"Scène "+sc;',
  'if(it.bd||it.img){img.style.background=`center/cover no-repeat url("${it.bd||it.img}")`;img.style.filter=""}$("#pthsc").textContent=(it.type==="s"?`S${P.ss} E${P.ep} · `:"")+"Aperçu";')
R('function commitScrub(){if(!SC.on||!P)return;P.pos=SC.pos;endScrub();', 'function commitScrub(){if(!SC.on||!P)return;P.pos=SC.pos;if(NATIVE)Prisme.seekTo(Math.round(P.pos*1000));endScrub();')
R('function stopPlayer(){clearInterval(PT);', 'function stopPlayer(){clearInterval(PT);if(NATIVE)Prisme.stop();')
R('P.id=L[i].id;P.src=srcId("ch:"+P.id);S.lch=P.id;render("p-pp");uiPing()}',
  'P.id=L[i].id;P.src=srcId("ch:"+P.id);P.err=0;P.audio=null;P.sub=null;S.lch=P.id;if(NATIVE)Prisme.play(streamUrl(),0,true);render("p-src");uiPing()}')
R('case "zch":{S.modal=null;P.id=v;P.src=srcId("ch:"+v);P.audio=0;P.sub=null;S.lch=v;',
  'case "zch":{S.modal=null;P.id=v;P.src=srcId("ch:"+v);P.audio=null;P.sub=null;P.err=0;S.lch=v;if(NATIVE)Prisme.play(streamUrl(),0,true);')
R('if(topS().t==="player"&&P){P.src=v;P.audio=0;P.sub=null;render("p-src");',
  'if(topS().t==="player"&&P){P.src=v;P.audio=null;P.sub=null;P.err=0;P.aSync=null;if(NATIVE)Prisme.play(streamUrl(),P.kind==="vod"?Math.round(P.pos*1000):0,P.kind==="live");render("p-src");')
R('if(v==="pp"){P.playing=!P.playing;render("p-pp");', 'if(v==="pp"){P.playing=!P.playing;if(NATIVE){P.playing?Prisme.resume():Prisme.pause()}render(F&&F.dataset.fid);')
R('case "trk":{if(v==="a")P.audio=+w;else P.sub=+w;', 'case "trk":{if(v==="a")P.audio=+w;else P.sub=+w;if(NATIVE){v==="a"?Prisme.setAudio(+w):Prisme.setSub(+w)}')
R('case "fmt":{S.set.fmt=v;save();', 'case "fmt":{S.set.fmt=v;save();if(NATIVE)Prisme.setFormat(v);')
R('''else if(v==="nextep"){const it=ALL[P.id];let ss=P.ss,ep=P.ep+1;if(ep>it.se[ss-1]){ss++;ep=1}if(ss>it.se.length){toast("Dernier épisode");break}Object.assign(P,{ss,ep,pos:0});S.seasons[P.id]=ss;render("p-nextep");toast(`Saison ${ss} · Épisode ${ep}`)}''',
  '''else if(v==="nextep"){const it=ALL[P.id],n=nextEp(it);if(!n){toast("Dernier épisode");break}Object.assign(P,{ss:n.ss,ep:n.ep,pos:0,err:0,endH:0,aSync:null,audio:null,sub:null});S.seasons[P.id]=n.ss;if(NATIVE)Prisme.play(streamUrl(),0,false);render("p-nextep");toast(`Saison ${(it.seasons||[])[n.ss-1]} · Épisode ${n.ep}`)}''')
RX(r'  case "play":\{const it=ALL\[v\];\n.*?\n   break\}\n', '''  case "play":{const it=ALL[v];if(!it)break;
   if(it.type==="s"&&!it.info){toast("Chargement des épisodes…");loadInfo(it).then(()=>{if(it.info&&(it.seasons||[]).length)act(a)});break}
   push({t:"player"});
   if(it.type==="f")startPlayer({kind:"vod",id:v,src:srcId(v),dur:(it.d||0)*60,pos:(S.prog[v]||0)*(it.d||0)*60,playing:true});
   else{const ss=+w||(S.seasons[v]||1),L=(it.eps||{})[(it.seasons||[])[ss-1]]||[],ep=+x||(L[0]&&L[0].num)||1,vv=srcs(v).find(z=>z.p.id===it.srcPl);
    startPlayer({kind:"vod",id:v,src:vv?vv.id:srcId(v),ss,ep,dur:((curEpOf(it,ss,ep)||{}).dur||0)*60,pos:0,playing:true})}
   render(null);break}
''')
R('startPlayer({kind:"live",id:v,src:srcId("ch:"+v),playing:true});render("p-pp");', 'startPlayer({kind:"live",id:v,src:srcId("ch:"+v),playing:true});render(null);')
R('startPlayer({kind:"live",id,src:v,playing:true});render("p-pp")}', 'startPlayer({kind:"live",id,src:v,playing:true});render(null)}')
FN("tracks", '''function tracks(){const st=P&&P.nst;if(NATIVE&&st&&st.audio)return {au:st.audio.map(a=>({n:a.name||a.lang||"Piste audio",c:a.codec||""})),su:(st.subs||[]).map(s=>s.name||s.lang||"Sous-titres")};
 const v=curVar()||{audio:[],subs:[]};return {au:v.audio.map(a=>{const [n,c]=a.split(" · ");return {n,c:c||""}}),su:v.subs.filter(x=>x!=="Aucun"&&!x.startsWith("Selon"))}}''')
FN("curSub", '''function curSub(){const t=tracks();if(P.sub==null||P.sub>=t.su.length)P.sub=-1;return P.sub>=0?t.su[P.sub]:null}''')
R('view.addEventListener("click",e=>{const tr=e.target.closest("#ptr");if(!tr||!P||P.kind!=="vod")return;const r=tr.getBoundingClientRect();P.pos=Math.max(0,Math.min(P.dur-1,(e.clientX-r.left)/r.width*P.dur));endScrub();',
  'view.addEventListener("click",e=>{const tr=e.target.closest("#ptr");if(!tr||!P||P.kind!=="vod")return;const r=tr.getBoundingClientRect();P.pos=Math.max(0,Math.min(P.dur-1,(e.clientX-r.left)/r.width*P.dur));if(NATIVE)Prisme.seekTo(Math.round(P.pos*1000));endScrub();')

# ---------------------------------------------------------------- mises à jour (réelles)
FN("updHtml", '''function updHtml(){const u=S.modal,L=LATEST||{};const box=(w,inner)=>`<div class="modal"><div class="mbox upd" style="width:${w}px">${inner}</div></div>`;
 if(u.stage==="check")return box(640,`<div class="kick">Mise à jour</div><h2>Recherche en cours…</h2><div class="meta2">Lecture de version.json sur ${esc(APP.repo)}</div><div class="ubtns"><div class="btn" data-f data-fid="u-cancel" data-act="upd:close" data-default>Annuler</div></div>`);
 if(u.stage==="error")return box(640,`<div class="kick">Mise à jour</div><h2>Vérification impossible</h2><div class="meta2">${esc(u.msg||"")}</div><div class="ubtns"><div class="btn" data-f data-fid="u-retry" data-act="upd:check" data-default>Réessayer</div><div class="btn" data-f data-fid="u-ok" data-act="upd:close">Fermer</div></div>`);
 if(u.stage==="uptodate")return box(640,`<div class="kick">Mise à jour</div><h2>prisme est à jour</h2><div class="meta2">Version ${esc(APPV.name)} (build ${APPV.code}) · vérifié à ${fmt(nowMin())}</div><div class="ubtns"><div class="btn" data-f data-fid="u-ok" data-act="upd:close" data-default>OK</div></div>`);
 if(u.stage==="avail")return box(680,`<div class="kick">Nouvelle version disponible</div><h2>prisme ${esc(L.ver)}</h2><div class="meta2">Installée : ${esc(APPV.name)}${L.size?` · ${L.size.toFixed(1).replace(".",",")} Mo`:""}${L.date?` · publiée le ${esc(L.date)}`:""}</div>
  ${(L.notes||[]).length?`<ul class="notes2">${L.notes.map(n=>`<li>${esc(n)}</li>`).join("")}</ul>`:""}
  <div class="meta2" style="margin-top:12px">Tes playlists, favoris et reprises de lecture sont conservés.</div>
  <div class="ubtns"><div class="btn" data-f data-fid="u-go" data-act="upd:go" data-default>Mettre à jour</div><div class="btn" data-f data-fid="u-later" data-act="upd:close">Plus tard</div></div>`);
 if(u.stage==="perm")return box(700,`<div class="kick">Autorisation nécessaire</div><h2>Autoriser les mises à jour</h2><div class="meta2" style="font-size:17px;line-height:1.5">Fire OS demande d'autoriser prisme à installer des applications, une seule fois. Dans l'écran qui s'ouvre, active <b>prisme</b>, puis reviens ici avec Retour.</div>
  <div class="ubtns"><div class="btn" data-f data-fid="u-perm" data-act="upd:perm" data-default>Ouvrir les paramètres</div><div class="btn" data-f data-fid="u-go2" data-act="upd:go">C'est fait</div></div>`);
 if(u.stage==="dl")return box(640,`<div class="kick">Téléchargement</div><h2>prisme ${esc(L.ver||"")}</h2><div class="ubar"><i id="ubar" style="width:${u.pct||0}%"></i></div><div class="meta2" id="utxt">Démarrage…</div><div class="ubtns"><div class="btn" data-f data-fid="u-stop" data-act="upd:close" data-default>Masquer</div></div>`);
 if(u.stage==="install")return box(660,`<div class="kick">Presque fini</div><h2>Confirme l'installation</h2><div class="meta2" style="font-size:17px;line-height:1.5">La fenêtre d'installation d'Android s'est ouverte : choisis <b>Installer</b>. prisme redémarrera en version ${esc(L.ver||"")}.</div><div class="ubtns"><div class="btn" data-f data-fid="u-again" data-act="upd:install" data-default>Relancer l'installation</div><div class="btn" data-f data-fid="u-ok" data-act="upd:close">Fermer</div></div>`);
 return "";}''')
FN("updAct", '''async function fetchLatest(){const r=await getJSON(UPD_URL+"?t="+Date.now(),20000);if(!r||!r.versionCode)throw new Error("fichier version.json invalide");
 LATEST={ver:r.versionName,code:+r.versionCode,size:(+r.size||0)/1048576,date:r.date||"",notes:r.notes||[],apk:r.apk};return LATEST}
function updAct(v){clearInterval(UT);
 if(v==="close"){const r=S.modal&&S.modal.ret;S.modal=null;render(r);return}
 if(v==="check"){const ret=(S.modal&&S.modal.ret)||(F&&F.dataset.fid);S.modal={type:"upd",stage:"check",ret};render();
  fetchLatest().then(L=>{if(!S.modal||S.modal.type!=="upd")return;S.modal.stage=L.code>APPV.code?"avail":"uptodate";render()}).catch(e=>{if(!S.modal||S.modal.type!=="upd")return;S.modal.stage="error";S.modal.msg=e.message;render()});return}
 if(v==="go"){if(!NATIVE){toast("Mise à jour possible uniquement sur le Fire TV");return}if(!Prisme.canInstall()){S.modal.stage="perm";render();return}
  S.modal.stage="dl";S.modal.pct=0;render();Prisme.download(LATEST.apk);
  UT=setInterval(()=>{let d={};try{d=JSON.parse(Prisme.downloadState())}catch(e){}const m=S.modal;if(!m||m.type!=="upd"){if(d.done){clearInterval(UT);Prisme.install()}return}
   if(d.error){clearInterval(UT);m.stage="error";m.msg="Téléchargement interrompu : "+d.error;render();return}
   const b=$("#ubar"),t=$("#utxt");if(b)b.style.width=(d.pct||0)+"%";if(t)t.textContent=d.total>0?`${(d.read/1048576).toFixed(1).replace(".",",")} / ${(d.total/1048576).toFixed(1).replace(".",",")} Mo`:"Téléchargement…";
   if(d.done){clearInterval(UT);m.stage="install";render();Prisme.install()}},300);return}
 if(v==="perm"){Prisme.openInstallSettings();return}
 if(v==="install"){Prisme.install();return}
}''')
FN("autoCheck", '''function autoCheck(){if(AUTOCHK||!inApp()||S.set.autoUpd===false||!NATIVE)return;AUTOCHK=true;setTimeout(()=>fetchLatest().then(L=>{if(L.code>APPV.code)toast(`Mise à jour ${L.ver} disponible · Réglages › À propos`)}).catch(()=>{}),4000)}''')

# ---------------------------------------------------------------- moteur
FN("fit", '''function fit(){const w=innerWidth||1280,h=innerHeight||720;SCALE=Math.min(w/1280,h/720);scr.style.transform=`translate(${(w-1280*SCALE)/2}px,${(h-720*SCALE)/2}px) scale(${SCALE})`}
addEventListener("resize",fit);fit();''')
R(' if(!inApp()) html=S.loading?loadingHtml():loginHtml();', ' if(S.booting) html=bootHtml();\n else if(!inApp()) html=S.loading?loadingHtml():loginHtml();')
R(' view.innerHTML=html;F=null;fitAll(view);autoCheck();', ' view.innerHTML=html;F=null;fitAll(view);if(!S.booting)autoCheck();\n document.documentElement.classList.toggle("vplay",t.t==="player");')
R(' else if(t.t==="detail") setBg(ALL[t.id].c);', ' else if(t.t==="detail") setBg(ALL[t.id].c,ALL[t.id].bd);')
R(' else if(t.t==="home"&&S.tab==="live") setBg([CH[S.lch].col,"#08080c"]);', ' else if(t.t==="home"&&S.tab==="live") setBg([(CH[S.lch]||{col:"#1e4fd8"}).col,"#08080c"]);')
R(' else if(t.t==="home"){const l=S.tab==="films"?films():series();setBg(l[0]?l[0].c:["#2b3245","#0a0b10"])}',
  ' else if(t.t==="home"){const l=S.tab==="films"?films():series();setBg(l[0]?l[0].c:["#2b3245","#0a0b10"],l[0]&&l[0].bd)}\n {const tk=$("#f-tmdb");if(tk)tk.addEventListener("change",()=>{S.set.tmdbKey=tk.value.trim();save();toast(S.set.tmdbKey?"Clé TMDB enregistrée":"Clé TMDB supprimée");loadTrends()})}')
R(' if(el.tagName==="INPUT")el.focus({preventScroll:true});', ' if(el.tagName==="INPUT")el.focus({preventScroll:true});\n if(NATIVE)Prisme.setTyping(el.tagName==="INPUT");')
R(' toast("Appuyez sur Accueil pour revenir au début");\n}', ' EXIT=true;\n}\nlet EXIT=false;\nwindow.nativeKey=k=>{EXIT=false;if(k==="chup"||k==="chdown"){if(topS().t==="player"&&P&&P.kind==="live")zap(k==="chup"?-1:1);return "ok"}key(k);return EXIT?"exit":"ok"};')
R(' if(inInput&&(k==="left"||k==="right"))return;', ' if(inInput&&(k==="left"||k==="right"))return;\n if(inInput&&NATIVE&&e.key==="Enter")return;')
R('setInterval(()=>{document.querySelectorAll(".clock")', 'if(NATIVE)document.documentElement.classList.add("native");\nsetInterval(()=>{document.querySelectorAll(".clock")')
assert js.rstrip().endswith("render();"), js[-60:]
js = js.rstrip()[:-len("render();")] + "boot();\n"

exec(open(os.path.join(D, "perf_patch.py"), encoding="utf-8").read())
exec(open(os.path.join(D, "v13_patch.py"), encoding="utf-8").read())

# ---------------------------------------------------------------- CSS + page
css += '''
/* ---- app Fire TV ---- */
html.lite .tabs,html.lite .btn,html.lite .pc,html.lite .mbox,html.lite .lpanel2,html.lite #toast,html.lite .modal,html.lite .ppause,html.lite .pinfo{backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
html.lite .tabs{background:rgba(26,26,32,.94)}
html.lite .btn{background:rgba(62,62,72,.92)}
html.lite .pc{background:rgba(48,48,58,.9)}
html.lite .mbox{background:rgba(30,30,38,.98)}
html.lite .modal{background:rgba(0,0,0,.72)}
html.lite #toast{background:rgba(36,36,44,.97)}
html.lite .lpanel2{background:rgba(24,24,30,.96)}
html.lite .pst{box-shadow:none;transition:transform .16s ease-out}
html.lite .card.foc .pst{box-shadow:0 10px 22px rgba(0,0,0,.55)}
html.lite .pst::after{display:none}
html.lite .eth,html.lite .av{box-shadow:none}
html.lite .bgl{transition:none}
html.lite .vid{animation:none}
html.lite .scan,html.lite .pth-img::after{display:none}
html.lite .btn.foc,html.lite .pc.foc,html.lite .lch.foc,html.lite .tab.foc{box-shadow:none}
.sx>*,.lchs>*{contain:layout style}
[hidden]{display:none!important}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#000}
#scr{position:fixed!important;left:0;top:0}
html.vplay,html.vplay body,html.vplay #scr{background:transparent!important}
html.vplay #bg{display:none}
html.native .player{background:transparent}
html.native .player .pframe,html.native .player .wm2{display:none}
.pst img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.pst-in{z-index:1}
.pst.has-img .pst-t,.pst.has-img .pst-k{opacity:0}
.pst.has-img::before{display:none}
.logo img{max-width:88%;max-height:80%;object-fit:contain}
.logo.has-img{background:rgba(255,255,255,.1)}
.logo.has-img b{display:none}
.logo b{font-weight:800}
.ep .eth span{z-index:1}
.av{position:relative;overflow:hidden}
.av b{font-weight:inherit}
.av img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:center 22%}
.av.has-img b{opacity:0}
.cchip small{font-size:13px;font-weight:500;opacity:.6;margin-left:8px}
.cath{padding:96px 64px 8px}
.cath h1{margin:6px 0 18px;font-size:48px;font-weight:700;letter-spacing:-.02em}
.csorts{display:flex;gap:12px}
.cgrid{display:flex;flex-wrap:wrap;gap:30px 26px;padding:22px 64px 0}
.qs{height:20px!important;font-size:11px!important;padding:0 6px!important;margin-left:6px;vertical-align:2px}
.qa{background:rgba(255,255,255,.25)!important;color:#fff!important}
.it.lg{font-size:15px}
.it.lg span:first-child{white-space:normal;line-height:1.35}
.it.lg span:last-child{flex:0 0 auto}
'''
html = f'''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=1280, user-scalable=no">
<title>prisme</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo+Black&family=Bebas+Neue&family=Outfit:wght@200;300;400;500;600;700&family=Playfair+Display:ital,wght@1,700&display=swap">
<style>{css}</style>
</head>
<body>
<div id="scr"><div id="bg"><div class="bgl"></div><div class="bgl"></div><div class="shade"></div></div><div id="view"></div><div id="toast"></div></div>
<script>{js}</script>
</body>
</html>
'''
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8").write(html)
open(os.path.join(D, "app.js"), "w", encoding="utf-8").write(js)
print("ok", len(html))
