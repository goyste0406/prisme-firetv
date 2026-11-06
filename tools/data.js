/* ========================= DONNÉES (Xtream Codes) ========================= */
const NATIVE=!!window.Prisme;
let FILMS=[],SERIES=[],CHS=[],CH={},ALL={},A={},CRED={},FCATS=[],SCATS=[];
let LCATS=[["all","Toutes les chaînes"],["fav","Favoris"]];
let COUNTRIES=[];
const DATA={};            // données brutes par playlist (en mémoire)
const RX={};              // notes complémentaires (MDBList / What's on?, à venir)
let TREND={f:[],s:[]};
let CATV=0;const MEMO={};const bump=()=>CATV++;    // tendances TMDB (si clé TMDB)
const META=[["imdb","IMDb","IMDb"],["tmdb","TMDB","TMDB"],["rt","Rotten Tomatoes","RT"],["mc","Metacritic","MC"],["lb","Letterboxd","Lb"],["ac","AlloCiné","AlloCiné"],["sc","SensCritique","SC"]];
const PAL=[["#8a6b3d","#0d1422"],["#d9823b","#2b1206"],["#5b7c99","#0b1118"],["#c8323a","#1d3b22"],["#9ec5e8","#05070d"],["#c9a227","#0e1a2b"],["#ff5fa2","#5b1036"],["#7fb347","#1c2b12"],["#e3342f","#0a0a14"],["#9c6b3f","#0f0d0b"],["#6ee7f9","#0b1730"],["#f5b942","#2c2a6b"],["#b7a57a","#141414"],["#7aa2c2","#0c1520"]];
const FONTS=["bebas","serif","black","thin"];
const CHCOL=["#1e4fd8","#d1162c","#159a48","#6d2fd6","#e08a00","#0a8fd0","#c21875","#0f766e","#4b4b4b","#8b2bd6"];

/* Journal de diagnostic (Réglages › Diagnostic) : jamais de mot de passe */
const LOGS=[];
const hidePw=u=>String(u||"").replace(/password=[^&]*/,"password=•••").replace(/\/(live|movie|series)\/([^/]+)\/([^/]+)\//,"/$1/$2/•••/").replace(/api_key=[^&]*/,"api_key=•••");
function LOG(m){LOGS.unshift([Date.now(),String(m).slice(0,240)]);if(LOGS.length>120)LOGS.pop()}
const proxied=u=>NATIVE?"https://appassets.androidplatform.net/proxy?u="+encodeURIComponent(u):u;
/* Le fournisseur peut bloquer un compte qui envoie trop de demandes : au plus 2 à la fois, espacées,
   et pause de 15 minutes de toutes les demandes automatiques dès qu'il refuse (403, 429, 503). */
const PROV={busy:0,q:[],last:0,ban:0};
const isProv=u=>/player_api\.php/.test(u);
function provSlot(){return new Promise(res=>{PROV.q.push(res);provPump()})}
function provPump(){if(PROV.busy>=2||!PROV.q.length)return;const w=Math.max(0,PROV.last+250-Date.now());
 setTimeout(()=>{if(PROV.busy>=2||!PROV.q.length)return;PROV.busy++;PROV.last=Date.now();PROV.q.shift()();provPump()},w)}
async function getJSON(u,timeout=60000){
 const prov=isProv(u);
 if(prov&&Date.now()<PROV.ban)throw new Error(`le fournisseur a refusé l'accès, nouvel essai possible dans ${Math.ceil((PROV.ban-Date.now())/60000)} min`);
 if(prov)await provSlot();
 const ctl=new AbortController(),t=setTimeout(()=>ctl.abort(),timeout);
 try{const r=await fetch(proxied(u),{signal:ctl.signal});
  if(prov&&[403,429,503].includes(r.status)){PROV.ban=Date.now()+15*60000;LOG(`Le fournisseur refuse les demandes (code ${r.status}) : pause automatique de 15 minutes pour ne pas aggraver le blocage`)}
  if(!r.ok)throw new Error("le serveur répond "+r.status);const txt=await r.text();return txt?JSON.parse(txt):null}
 catch(e){const m=e.name==="AbortError"?"délai dépassé":e.message;if(!/wikipedia/.test(u))LOG("Erreur réseau · "+hidePw(u).replace(/^https?:\/\//,"").slice(0,110)+" · "+m);throw new Error(m)}finally{clearTimeout(t);if(prov){PROV.busy--;provPump()}}}
const clean=u=>(u||"").trim().replace(/\/+$/,"");
const api=(pl,action,extra="")=>`${clean(pl.url)}/player_api.php?username=${encodeURIComponent(pl.user)}&password=${encodeURIComponent(pl.pass)}${action?"&action="+action:""}${extra}`;
const b64=s=>{try{return decodeURIComponent(escape(atob(s||"")))}catch(e){return s||""}};
const catKey=n=>"k"+hash(norm(n)).toString(36);

/* Nom Xtream → titre, année, qualité, langue. Ex : "FR| Intouchables (2011) 4K MULTI" */
const QTOK=/\b(4k|uhd|2160p?|full ?hd|fhd|1080p?|hd\+?|720p?|sd|50 ?fps|60 ?fps|fps|backup|bk|raw|hevc|h\.?26[45]|x26[45]|multi|vostfr|vost|vff|vfq|vf|vo|truefrench|french|hdr10\+?|hdr|dv|10bits?|ac3|eac3|dts|atmos|web(-?dl)?|bluray|remux)\b/gi;
const SUP={"ᴬ":"A","ᴮ":"B","ᴰ":"D","ᴱ":"E","ᴳ":"G","ᴴ":"H","ᴵ":"I","ᴶ":"J","ᴷ":"K","ᴸ":"L","ᴹ":"M","ᴺ":"N","ᴼ":"O","ᴾ":"P","ᴿ":"R","ᵀ":"T","ᵁ":"U","ⱽ":"V","ᵂ":"W","ᶠ":"F","ˢ":"S","ʰ":"H","ᵈ":"D","ᵏ":"K","⁰":"0","¹":"1","²":"2","³":"3","⁴":"4","⁵":"5","⁶":"6","⁷":"7","⁸":"8","⁹":"9","⁺":"+"};
function parseName(raw){
 raw=String(raw||"").replace(/[ᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿᵀᵁⱽᵂᶠˢʰᵈᵏ⁰¹²³⁴⁵⁶⁷⁸⁹⁺]+/g,m=>" "+[...m].map(c=>SUP[c]||"").join("")+" ");
 let s=String(raw||"").replace(/^\s*[\[(]?[A-Z]{2,4}[\])]?\s*[|:\-–•]\s*/i,"").replace(/^\s*[A-Z]{2,4}\s*\|\s*/,"");
 const ym=s.match(/\((19|20)\d{2}\)/)||s.match(/[\s\-–](19|20)\d{2}\s*$/);
 const low=s.toLowerCase();
 const q=/(\b4k\b|uhd|2160)/.test(low)?"4K":/(fhd|full ?hd|1080)/.test(low)?"1080p":/(\b720p?\b|\bhd\b)/.test(low)?"720p":/\bsd\b/.test(low)?"SD":"Auto";
 const tag=/multi/.test(low)?"MULTI":/vostfr|vost\b/.test(low)?"VOSTFR":/\bvo\b/.test(low)?"VO":"VF";
 let title=s.replace(/\((19|20)\d{2}\)/,"").replace(QTOK,"").replace(/[\[\]()|]+/g," ").replace(/\s{2,}/g," ").trim().replace(/[\s\-–:.]+$/,"");
 if(ym&&!/\(/.test(ym[0]))title=title.replace(/[\s\-–](19|20)\d{2}$/,"").trim();
 return {title:title||String(raw),year:ym?+ym[0].replace(/\D/g,""):0,q,tag};
}
/* Cache du catalogue sur l'appareil (IndexedDB) : démarrage instantané */
const IDB={db:null,open(){return new Promise(r=>{try{const q=indexedDB.open("prisme",1);q.onupgradeneeded=()=>q.result.createObjectStore("data");q.onsuccess=()=>r(this.db=q.result);q.onerror=()=>r(null)}catch(e){r(null)}})},
 async get(k){const db=this.db||await this.open();if(!db)return null;return new Promise(r=>{try{const t=db.transaction("data").objectStore("data").get(k);t.onsuccess=()=>r(t.result||null);t.onerror=()=>r(null)}catch(e){r(null)}})},
 async put(k,v){const db=this.db||await this.open();if(!db)return;try{db.transaction("data","readwrite").objectStore("data").put(v,k)}catch(e){}},
 async del(k){const db=this.db||await this.open();if(!db)return;try{db.transaction("data","readwrite").objectStore("data").delete(k)}catch(e){}}};
/* Certains serveurs ne renvoient pas tout d'un coup : les catégories restées vides sont demandées une par une */
async function fillCats(pl,action,cats,list,map,D){
 if(list.length)return list;
 const have=new Set();list.forEach(x=>{have.add(x.cat);(x.cs||[]).forEach(c=>have.add(c))});
 const miss=Object.keys(cats||{}).filter(k=>!have.has(String(k))).slice(0,25);if(!miss.length)return list;
 const seen=new Set(list.map(x=>x.id));let i=0,added=0;
 const worker=async()=>{while(i<miss.length){const c=miss[i++];try{const r=await getJSON(api(pl,action,"&category_id="+encodeURIComponent(c)),60000);
  const arr=Array.isArray(r)?r:Object.values(r||{}).filter(x=>x&&typeof x==="object");if(arr.length)D.fill++;
  arr.forEach(x=>{const m=map(x);if(!m.cat)m.cat=String(c);if(seen.has(m.id)){const o=list.find(y=>y.id===m.id);if(o){o.cs=o.cs||[o.cat];if(!o.cs.includes(String(c)))o.cs.push(String(c))}}else{seen.add(m.id);list.push(m);added++}})}catch(e){}}};
 await worker();
 if(added)LOG(`${pl.name} · ${action} : +${added} éléments récupérés dans ${miss.length} catégories`);
 return list}
const mapCats=a=>{const m={};(a||[]).forEach(c=>m[c.category_id]=c.category_name||"Autres");return m};

async function loadPlaylist(pl,step=()=>{}){
 step(0);const auth=await getJSON(api(pl,""),20000);
 if(!auth||!auth.user_info)throw new Error("réponse Xtream invalide (vérifie l'URL)");
 if(String(auth.user_info.auth)!=="1")throw new Error("identifiants refusés par le serveur");
 const D={info:auth.user_info,server:auth.server_info||{}};
 step(1);const [lc,vc,sc]=await Promise.all([getJSON(api(pl,"get_live_categories")),getJSON(api(pl,"get_vod_categories")),getJSON(api(pl,"get_series_categories"))]);
 D.lc=mapCats(lc);D.vc=mapCats(vc);D.sc=mapCats(sc);
 const t0=Date.now();D.fill=0;
 const cs=x=>{const a=Array.isArray(x.category_ids)?x.category_ids.map(String):[];const c=String(x.category_id??"");if(c&&!a.includes(c))a.unshift(c);return a.length>1?a:undefined};
 const mL=x=>({id:x.stream_id,n:x.name||"",logo:x.stream_icon||"",cat:String(x.category_id??""),cs:cs(x),num:+x.num||0,arch:+x.tv_archive||0});
 const mV=x=>({id:x.stream_id,n:x.name||"",img:x.stream_icon||"",cat:String(x.category_id??""),cs:cs(x),r:+x.rating||0,added:+x.added||0,ext:x.container_extension||"mp4",tmdb:String(x.tmdb||x.tmdb_id||"")});
 const mS=x=>({id:x.series_id,n:x.name||"",img:x.cover||"",cat:String(x.category_id??""),cs:cs(x),r:+x.rating||0,added:+(x.last_modified||0),plot:x.plot||"",cast:x.cast||"",dir:x.director||"",genre:x.genre||"",year:String(x.releaseDate||x.release_date||"").slice(0,4),bd:(Array.isArray(x.backdrop_path)?x.backdrop_path[0]:x.backdrop_path)||"",tmdb:String(x.tmdb||"")});
 const all=async(action,map,to)=>{try{const r=await getJSON(api(pl,action),to);return Array.isArray(r)?r.map(map):Object.values(r||{}).filter(x=>x&&typeof x==="object").map(map)}catch(e){LOG(`${pl.name} · ${action} a échoué (${e.message}) : chargement catégorie par catégorie`);return []}};
 step(2);D.live=await fillCats(pl,"get_live_streams",D.lc,await all("get_live_streams",mL,90000),mL,D);
 step(3);D.vod=await fillCats(pl,"get_vod_streams",D.vc,await all("get_vod_streams",mV,150000),mV,D);
 step(4);D.ser=await fillCats(pl,"get_series",D.sc,await all("get_series",mS,150000),mS,D);
 LOG(`${pl.name} chargée en ${((Date.now()-t0)/1000).toFixed(1)} s · ${D.live.length} TV · ${D.vod.length} films · ${D.ser.length} séries${D.fill?` · ${D.fill} catégories complétées une par une`:""}`);
 DATA[pl.id]=D;pl.exp=D.info.exp_date?+D.info.exp_date*1000:null;pl.maxc=+D.info.max_connections||0;pl.actc=+D.info.active_cons||0;
 pl.fmt=(D.info.allowed_output_formats||[]).includes("ts")?"ts":((D.info.allowed_output_formats||[])[0]||"ts");
 pl.loadedAt=Date.now();IDB.put("pl:"+pl.id,D);
 return D;
}

/* Fusion de toutes les playlists : un titre présent sur plusieurs playlists devient un seul élément avec plusieurs sources */
function buildCatalog(){
 const keep={};[...FILMS,...SERIES].forEach(i=>{if(i.info)keep[i.id]=i});
 FILMS=[];SERIES=[];CHS=[];CH={};ALL={};const fc=new Map(),sc=new Map(),lc=new Map(),byKey={};
 const mk=(type,key,p,x)=>{const id=type+hash(key).toString(36),k=keep[id];const h=hash(key);
  const it=k||{id,type,t:p.title,y:p.year,d:0,g:[],cat:[],imdb:0,tmdb:0,age:"",dir:"",s:"",cast:[],img:"",bd:"",src:[],tmdbId:x.tmdb||"",c:PAL[h%PAL.length],f:FONTS[(h>>3)%4],net:"",se:[],ep:0};
  it.cat=[];it.src=[];return it};
 for(const pl of S.playlists){const D=DATA[pl.id];if(!D)continue;
  for(const v of D.vod){const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:norm(p.title)+"|"+p.year;let it=byKey["f"+key];
   if(!it){it=byKey["f"+key]=mk("f",key,p,v);FILMS.push(it);ALL[it.id]=it}
   const cn=D.vc[v.cat]||"Autres",ck=catKey(cn);for(const c of (v.cs||[v.cat])){const n2=D.vc[c]||cn,k2=catKey(n2);if(!it.cat.includes(k2))it.cat.push(k2);if(!fc.has(k2))fc.set(k2,n2)}
   it.src.push({pl:pl.id,sid:v.id,ext:v.ext,q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added});
   if(!it.img&&v.img)it.img=v.img;if(v.r&&!it.info){it.tmdb=Math.round(v.r*10)}}
  for(const v of D.ser){const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:norm(p.title)+"|"+(p.year||v.year);let it=byKey["s"+key];
   if(!it){it=byKey["s"+key]=mk("s",key,p,v);if(!it.y)it.y=+v.year||0;SERIES.push(it);ALL[it.id]=it}
   const cn=D.sc[v.cat]||"Autres",ck=catKey(cn);for(const c of (v.cs||[v.cat])){const n2=D.sc[c]||cn,k2=catKey(n2);if(!it.cat.includes(k2))it.cat.push(k2);if(!sc.has(k2))sc.set(k2,n2)}
   it.src.push({pl:pl.id,sid:v.id,ext:"mkv",q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added});
   if(!it.img&&v.img)it.img=v.img;if(!it.bd&&v.bd)it.bd=v.bd;
   if(!it.info){if(!it.s&&v.plot)it.s=v.plot;if(!it.dir&&v.dir)it.dir=v.dir;if(!it.g.length&&v.genre)it.g=v.genre.split(/[,/]/).map(x=>x.trim()).filter(Boolean).slice(0,3);if(v.r)it.tmdb=Math.round(v.r*10);
    if(!it.cast.length&&v.cast)it.cast=castList(v.cast)}}
  for(const v of D.live){const p=parseName(v.n),cn=D.lc[v.cat]||"Autres",ck=catKey(cn),ctry=countryOf(v.n,cn),key=norm(p.title).replace(/[^a-z0-9+]+/g," ").trim()+"|"+ctry;let c=byKey["c"+key];
   if(!c){const h=hash(key);c=byKey["c"+key]={id:"c"+h.toString(36),n:p.title,cat:ck,genre:genreOf(p.title,cn),country:ctry,rank:tntRank(p.title),col:CHCOL[h%CHCOL.length],num:v.num||CHS.length+1,logo:v.logo,src:[]};CHS.push(c);CH[c.id]=c}
   if(!lc.has(ck))lc.set(ck,cn);if(!c.logo&&v.logo)c.logo=v.logo;
   c.src.push({pl:pl.id,sid:v.id,q:p.q,name:v.n,cat:ck,arch:v.arch})}}
 CHS.sort((a,b)=>(a.rank-b.rank)||(a.num-b.num));CHS.forEach((c,i)=>c.pos=i+1);
 FCATS=[...fc.entries()];SCATS=[...sc.entries()];
 LCATS=[["all","Toutes les chaînes"],["fav","Favoris"],...GENRES];
 const cc={};CHS.forEach(c=>cc[c.country]=(cc[c.country]||0)+1);COUNTRIES=Object.entries(cc).sort((a,b)=>b[1]-a[1]);
 if(!LCATS.some(x=>x[0]===S.lcat))S.lcat="all";
 if(!S.ctry||(S.ctry!=="*"&&!cc[S.ctry]))S.ctry=cc.FR?"FR":(COUNTRIES[0]||["FR"])[0];
 CRED={};[...FILMS,...SERIES].forEach(i=>i.cast.forEach(([a,r,n])=>{if(n)A[a]=n;(CRED[a]=CRED[a]||[]).push([i.id,r])}));
 CATV++;
 if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;
}
function castList(str){return String(str||"").split(",").map(x=>x.trim()).filter(Boolean).slice(0,12).map(n=>{const a="a"+hash(norm(n)).toString(36);A[a]=n;return [a,"",n]})}

/* Fiche détaillée : get_vod_info / get_series_info, chargée à l'ouverture */
async function loadInfo(it){
 if(it.info||it.loading)return;it.loading=true;
 const s=it.src.find(x=>S.playlists.find(p=>p.id===x.pl&&p.on))||it.src[0],pl=S.playlists.find(p=>p.id===s.pl);
 try{
  if(it.type==="f"){const r=await getJSON(api(pl,"get_vod_info","&vod_id="+s.sid),30000)||{};const f=r.info||{};
   it.s=f.plot||f.description||it.s;it.dir=f.director||it.dir;
   if(f.genre)it.g=String(f.genre).split(/[,/]/).map(x=>x.trim()).filter(Boolean).slice(0,3);
   it.d=Math.round((+f.duration_secs||0)/60)||it.d;if(!it.d&&f.duration){const m=String(f.duration).match(/(\d+):(\d+)/);if(m)it.d=+m[1]*60+ +m[2]}
   if(f.releasedate&&!it.y)it.y=+String(f.releasedate).slice(0,4)||0;
   const bd=Array.isArray(f.backdrop_path)?f.backdrop_path[0]:f.backdrop_path;if(bd)it.bd=bd;if(f.movie_image&&!it.img)it.img=f.movie_image;
   if(f.rating)it.tmdb=Math.round(+f.rating*10);if(f.age||f.mpaa_rating)it.age=f.age||f.mpaa_rating;
   if(f.tmdb_id)it.tmdbId=String(f.tmdb_id);if(f.youtube_trailer)it.trailer=f.youtube_trailer;
   if(f.cast||f.actors)it.cast=castList(f.cast||f.actors);
   {const q=qualFromInfo(f);if(q)setQual(qkey(pl.id,"v",s.sid),q)}}
  else{const r=await getJSON(api(pl,"get_series_info","&series_id="+s.sid),30000)||{};const f=r.info||{};
   it.s=f.plot||it.s;it.dir=f.director||it.dir;if(f.genre)it.g=String(f.genre).split(/[,/]/).map(x=>x.trim()).filter(Boolean).slice(0,3);
   const bd=Array.isArray(f.backdrop_path)?f.backdrop_path[0]:f.backdrop_path;if(bd)it.bd=bd;if(f.rating)it.tmdb=Math.round(+f.rating*10);
   if(f.cast)it.cast=castList(f.cast);
   const eps=r.episodes||{};it.eps={};it.seasons=Object.keys(eps).map(Number).filter(n=>!isNaN(n)).sort((a,b)=>a-b);
   it.seasons.forEach(n=>{it.eps[n]=(eps[n]||[]).map(e=>{const q=qualFromInfo(e.info);return {id:e.id,num:+e.episode_num||0,t:e.title||("Épisode "+e.episode_num),ext:e.container_extension||"mkv",dur:Math.round((+(e.info&&e.info.duration_secs)||0)/60),img:(e.info&&e.info.movie_image)||"",plot:(e.info&&e.info.plot)||"",q:q&&q.q}}).sort((a,b)=>a.num-b.num)});
   {const f0=it.seasons.map(n=>(eps[n]||[])[0]).find(Boolean),q=f0&&qualFromInfo(f0.info);if(q)setQual(qkey(pl.id,"s",s.sid),q)}
   it.se=it.seasons.map(n=>it.eps[n].length);it.ep=(it.eps[it.seasons[0]]||[])[0]?.dur||0;it.srcPl=s.pl}
  it.info=true;it.cast.forEach(([a])=>{const L=CRED[a]=CRED[a]||[];if(!L.some(x=>x[0]===it.id))L.push([it.id,""])});
 }catch(e){it.infoErr=e.message;LOG("Fiche indisponible · "+it.t+" · "+e.message);toast("Fiche indisponible : "+e.message)}
 it.loading=false;
 const t=topS();if(t.t==="detail"&&t.id===it.id)render(F&&F.dataset.fid);
}

/* Guide TV : EPG court Xtream (get_short_epg), chargé à la demande et gardé 20 min */
const EPGC={},EPGQ=[];let EPGRUN=0,EPGT=null;
function midnight(){const d=new Date();d.setHours(0,0,0,0);return d.getTime()}
function epg(ch){const c=EPGC[ch.id];if(!c||Date.now()-c.at>20*60000)queueEpg(ch);return c?c.list:[]}
function queueEpg(ch){if(EPGC[ch.id]&&EPGC[ch.id].pending)return;EPGC[ch.id]={...(EPGC[ch.id]||{list:[]}),pending:true,at:Date.now()};EPGQ.push(ch);pumpEpg()}
function pumpEpg(){while(EPGRUN<3&&EPGQ.length){const ch=EPGQ.shift();EPGRUN++;fetchEpg(ch).finally(()=>{EPGRUN--;pumpEpg()})}}
async function fetchEpg(ch){
 const s=ch.src.find(x=>S.playlists.find(p=>p.id===x.pl&&p.on))||ch.src[0],pl=S.playlists.find(p=>p.id===s.pl);
 try{const r=await getJSON(api(pl,"get_short_epg","&stream_id="+s.sid+"&limit=12"),20000)||{};const m0=midnight(),sh=(S.set.epgShift||0)*60;
  const list=(r.epg_listings||[]).map(e=>({s:(+e.start_timestamp*1000-m0)/60000+sh,e:(+e.stop_timestamp*1000-m0)/60000+sh,t:b64(e.title)||"Programme",g:b64(e.description).slice(0,60)||"Direct",desc:b64(e.description)})).filter(p=>p.e>p.s).sort((a,b)=>a.s-b.s);
  EPGC[ch.id]={list,at:Date.now()}}catch(e){EPGC[ch.id]={list:[],at:Date.now()}}
 clearTimeout(EPGT);EPGT=setTimeout(refreshEpgViews,250);
}
function refreshEpgViews(){const t=topS();if(!inApp())return;
 if(t.t==="home"&&S.tab==="live"){view.querySelectorAll(".lch").forEach(el=>{const c=CH[el.dataset.hov.slice(3)];if(!c)return;const e=epgAt(c);const pg=el.querySelector(".pg"),b=el.querySelector(".bar i");if(pg)pg.textContent=`${fmt(e.cur.s)} · ${e.cur.t}`;if(b)b.style.width=e.pct+"%"});const p=$("#lpanel");if(p&&CH[S.lch])p.innerHTML=panelHtml(CH[S.lch])}
 else if(t.t==="player"&&P&&P.kind==="live"&&!S.modal)render(F&&F.dataset.fid);}
function nowMin(){const d=new Date();return d.getHours()*60+d.getMinutes()+d.getSeconds()/60}
function epgAt(ch){const n=nowMin(),L=epg(ch);const i=L.findIndex(p=>p.s<=n&&p.e>n);
 if(i<0)return {cur:{s:Math.floor(n/60)*60,e:Math.floor(n/60)*60+60,t:L.length?"Programme non communiqué":"Guide en cours de chargement…",g:"Direct"},next:L.filter(p=>p.s>n).slice(0,4),pct:0};
 return {cur:L[i],next:L.slice(i+1,i+5),pct:Math.min(100,(n-L[i].s)/(L[i].e-L[i].s)*100)}}
function epgCount(){return Object.values(EPGC).reduce((a,c)=>a+(c.list?c.list.length:0),0)}
const fmt=m=>{m=((Math.round(m)%1440)+1440)%1440;return String(Math.floor(m/60)).padStart(2,"0")+":"+String(m%60).padStart(2,"0")};

/* TMDB (facultatif, clé gratuite) : tendances de la semaine et filmographies */
async function tmdb(path){if(!S.set.tmdbKey)return null;const sep=path.includes("?")?"&":"?";return getJSON(`https://api.themoviedb.org/3/${path}${sep}api_key=${encodeURIComponent(S.set.tmdbKey)}&language=fr-FR`,20000)}
async function loadTrends(){if(!S.set.tmdbKey)return;try{const [m,t]=await Promise.all([tmdb("trending/movie/week"),tmdb("trending/tv/week")]);
 const match=(list,arr)=>(arr||[]).map(r=>{const id=String(r.id),ti=norm(r.title||r.name||"");return list.find(i=>i.tmdbId===id)||list.find(i=>norm(i.t)===ti)}).filter(Boolean);
 TREND={f:match(FILMS,m&&m.results),s:match(SERIES,t&&t.results)}}catch(e){}}

/* ========================= QUALITÉ RÉELLE DES SOURCES =========================
   1) Films et séries : get_vod_info / get_series_info donnent souvent la résolution (analyse ffprobe du serveur)
   2) Sinon, et pour la TV en direct : analyse native du flux (une à la fois) avant de choisir */
const QUAL=(()=>{try{const q=JSON.parse(localStorage.getItem("prisme-q")||"{}");Object.keys(q).forEach(k=>{if(!q[k]||!q[k].ok)delete q[k]});return q}catch(e){return {}}})();
const QPEND={};let QSAVE=null,QREF=null;
const qkey=(plId,kind,sid)=>`${plId}|${kind}|${sid}`;
function qLabel(w,h){if(!w&&!h)return "";if(w>=3200||h>=1800)return "4K";if(w>=1800||h>=1000)return "1080p";if(w>=1200||h>=700)return "720p";return "SD"}
const ISO={fre:"Français",fra:"Français",fr:"Français",eng:"Anglais",en:"Anglais",spa:"Espagnol",es:"Espagnol",ger:"Allemand",deu:"Allemand",de:"Allemand",ita:"Italien",it:"Italien",ara:"Arabe",ar:"Arabe",por:"Portugais",pt:"Portugais",jpn:"Japonais",ja:"Japonais",tur:"Turc",tr:"Turc",nld:"Néerlandais",dut:"Néerlandais"};
const vcName=c=>({h264:"H.264",avc:"H.264",hevc:"HEVC",h265:"HEVC",vp9:"VP9",av1:"AV1",mpeg2video:"MPEG-2"})[String(c||"").toLowerCase()]||String(c||"").toUpperCase();
const acName=c=>({aac:"AAC",ac3:"AC3",eac3:"E-AC3",dts:"DTS",truehd:"TrueHD",opus:"Opus",mp3:"MP3",mp2:"MP2",flac:"FLAC"})[String(c||"").toLowerCase()]||String(c||"").toUpperCase();
const chName=n=>({1:"mono",2:"stéréo",6:"5.1",8:"7.1"})[+n]||"";
function setQual(k,q){q.at=Date.now();QUAL[k]=q;delete QPEND[k];
 clearTimeout(QSAVE);QSAVE=setTimeout(()=>{try{const ks=Object.keys(QUAL);if(ks.length>3000)ks.sort((a,b)=>QUAL[a].at-QUAL[b].at).slice(0,ks.length-3000).forEach(x=>delete QUAL[x]);localStorage.setItem("prisme-q",JSON.stringify(QUAL))}catch(e){}},1500);
 clearTimeout(QREF);QREF=setTimeout(refreshQual,300)}
function qualFromInfo(info){const v=info&&info.video,a=info&&info.audio;if(!v||!(+v.width||+v.height))return null;
 const fr=String(v.avg_frame_rate||v.r_frame_rate||"");const fp=fr.includes("/")?(+fr.split("/")[0])/(+fr.split("/")[1]||1):+fr;
 const lang=a&&a.tags&&(a.tags.language||a.tags.LANGUAGE);
 return {ok:true,w:+v.width||0,h:+v.height||0,q:qLabel(+v.width,+v.height),vc:vcName(v.codec_name),fps:fp>0&&fp<200?Math.round(fp):0,
  hdr:/2084|hlg|arib/i.test(v.color_transfer||""),audio:a&&a.codec_name?[{lang:ISO[String(lang||"").toLowerCase()]||lang||"",codec:acName(a.codec_name),ch:chName(a.channels)}]:[],subs:null,from:"serveur"}}
function refreshQual(){const t=topS();if(!inApp()||S.booting)return;
 if(S.modal&&!S.modal.type)render(F&&F.dataset.fid);
 else if(t.t==="detail"&&!S.modal)render(F&&F.dataset.fid);
 else if(t.t==="home"&&S.tab==="live"&&CH[S.lch]){const p=$("#lpanel");if(p)p.innerHTML=panelHtml(CH[S.lch])}}
/* URL de flux pour une source donnée (sans lecture) */
function srcUrl(pl,kind,sid,ext){const u=clean(pl.url),us=encodeURIComponent(pl.user),pw=encodeURIComponent(pl.pass);
 return kind==="l"?`${u}/live/${us}/${pw}/${sid}.${pl.fmt==="m3u8"?"m3u8":"ts"}`:kind==="v"?`${u}/movie/${us}/${pw}/${sid}.${ext||"mkv"}`:`${u}/series/${us}/${pw}/${sid}.${ext||"mkv"}`}
const PQ=[];let PQRUN=false,PQOWN="";
function probeQueue(k,url){if(QPEND[k]||QUAL[k]||!NATIVE||!S.set.probe)return;QPEND[k]="probe";PQ.push([k,url]);pumpProbe()}
function pumpProbe(){if(PQRUN||!PQ.length)return;
 if(P){setTimeout(pumpProbe,3000);return}   // jamais pendant une lecture : une seule connexion chez beaucoup de fournisseurs
 PQRUN=true;const [k,url]=PQ.shift();Prisme.probe(k,url);const t0=Date.now();
 const poll=setInterval(()=>{const r=Prisme.probeResult(k);if(r&&r!=="pending"||Date.now()-t0>32000){clearInterval(poll);PQRUN=false;
  let o={ok:false,error:"pas de réponse après 32 s"};try{if(r&&r!=="pending")o=JSON.parse(r)}catch(e){o={ok:false,error:"réponse illisible"}}
  const nm=qName(k);
  if(o.ok&&(o.w||o.h)){setQual(k,{...o,q:qLabel(o.w,o.h),from:"analyse"});LOG(`Analyse OK · ${nm} · ${o.w}×${o.h} ${o.vc||""} · ${o.via||""} ${o.ms?(o.ms/1000).toFixed(1)+" s":""}`)}
  else{setQual(k,{ok:false,q:"",from:"analyse",err:o.error||"aucune piste vidéo trouvée"});Prisme.probeForget(k);LOG(`Analyse échouée · ${nm} · ${hidePw(o.error||"aucune piste vidéo")}`)}
  pumpProbe()}},700)}
function qName(k){const [pl,kind,sid]=k.split("|");const L=kind==="l"?CHS:kind==="v"?FILMS:SERIES;for(const i of L){const s=i.src.find(s=>s.pl===pl&&String(s.sid)===sid);if(s)return s.name||i.n||i.t}return k}
/* HLS : la résolution est écrite dans la liste maîtresse, pas besoin d'ouvrir le flux */
async function hlsQual(url){try{const ctl=new AbortController(),t=setTimeout(()=>ctl.abort(),8000);const r=await fetch(proxied(url),{signal:ctl.signal});clearTimeout(t);const txt=(await r.text()).slice(0,20000);
 let w=0,h=0;txt.replace(/RESOLUTION=(\d+)x(\d+)/g,(_,a,b)=>{if(+a*+b>w*h){w=+a;h=+b}});return w?{ok:true,w,h,q:qLabel(w,h),vc:/hvc1|hev1/.test(txt)?"HEVC":/avc1/.test(txt)?"H.264":"",fps:0,hdr:false,audio:[],subs:null,from:"liste HLS"}:null}catch(e){return null}}
/* Lance l'analyse de toutes les sources d'un titre ou d'une chaîne (la demande la plus récente passe en premier) */
async function analyze(key){
 const ch=key.startsWith("ch:"),it=ch?CH[key.slice(3)]:ALL[key];if(!it)return;
 if(PQOWN!==key){PQ.splice(0).forEach(([k])=>{if(QPEND[k]==="probe")delete QPEND[k]});PQOWN=key}
 const kind=ch?"l":it.type==="f"?"v":"s";
 for(const s of it.src){const pl=S.playlists.find(p=>p.id===s.pl&&p.on);if(!pl)continue;const k=qkey(pl.id,kind,s.sid);
  if(QUAL[k]&&(QUAL[k].ok||Date.now()-QUAL[k].at<20*60e3)||QPEND[k])continue;
  if(kind==="l"){if(!S.set.probe)continue;const u=srcUrl(pl,"l",s.sid);if(pl.fmt==="m3u8"){QPEND[k]="info";const q=await hlsQual(u);if(q){setQual(k,q);continue}delete QPEND[k]}probeQueue(k,u);continue}
  QPEND[k]="info";
  try{
   if(kind==="v"){const r=await getJSON(api(pl,"get_vod_info","&vod_id="+s.sid),20000)||{};const q=qualFromInfo(r.info);
    if(q)setQual(k,q);else{delete QPEND[k];probeQueue(k,srcUrl(pl,"v",s.sid,s.ext))}}
   else{const r=await getJSON(api(pl,"get_series_info","&series_id="+s.sid),20000)||{};const eps=r.episodes||{},first=Object.keys(eps).map(Number).sort((a,b)=>a-b).map(n=>eps[n]&&eps[n][0]).find(Boolean);
    const q=first&&qualFromInfo(first.info);
    if(q)setQual(k,q);else if(first){delete QPEND[k];probeQueue(k,srcUrl(pl,"s",first.id,first.container_extension))}else setQual(k,{ok:false,q:""})}
  }catch(e){delete QPEND[k];probeQueue(k,srcUrl(pl,kind,s.sid,s.ext))}}
}

/* ========================= PHOTOS DES ACTEURS =========================
   TMDB (si une clé est enregistrée) puis Wikipédia, gardées sur l'appareil */
const PHOTO=(()=>{try{return JSON.parse(localStorage.getItem("prisme-ph")||"{}")}catch(e){return {}}})();
let PHS=null,PHRUN=0;const PHQ=[],DAY=()=>Math.floor(Date.now()/86400000);
function phSave(){clearTimeout(PHS);PHS=setTimeout(()=>{try{const ks=Object.keys(PHOTO);if(ks.length>5000)ks.slice(0,ks.length-5000).forEach(k=>delete PHOTO[k]);localStorage.setItem("prisme-ph",JSON.stringify(PHOTO))}catch(e){}},1500)}
function photoOf(n){const v=PHOTO[norm(String(n||""))];return v&&v[0]!=="-"?v:""}
function setPhoto(n,url){const k=norm(n);if(!url&&PHOTO[k]&&PHOTO[k][0]!=="-")return;PHOTO[k]=url||("-"+DAY());phSave();if(url)paintPhoto(n,url)}
function paintPhoto(n,url){view.querySelectorAll(".av[data-nm]:not(.has-img)").forEach(av=>{if(av.dataset.nm===n){av.insertAdjacentHTML("afterbegin",`<img src="${esc(imgS(url,"p"))}" alt="" decoding="async" onerror="this.parentNode.classList.remove('has-img');this.remove()">`);av.classList.add("has-img")}})}
const PHRE=/(acteur|actrice|actor|actress|comedien|humoriste|comedian|realisat|director|cineaste|filmmaker|scenariste|screenwriter|chanteu|singer|rappeur|rapper|musicien|musician|animat|presentat|host|mannequin|model|doubleu|voice|personnalite|television|sportif|footballeur|boxeur|youtubeu|danseu|dancer|producteur|producer|ecrivain|writer|artiste|artist|showrunner)/;
async function wikiPhoto(n){let net=false;for(const lg of ["fr","en"]){try{const r=await getJSON(`https://${lg}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(n.trim().replace(/ /g,"_"))}?redirect=true`,10000);
  if(!r||r.type==="disambiguation"||!r.thumbnail||!r.thumbnail.source)continue;const d=norm((r.description||"")+" "+String(r.extract||"").slice(0,240));if(PHRE.test(d))return r.thumbnail.source}
 catch(e){if(!/ 404/.test(e.message))net=true}}return net?null:""}
function wantPhotos(names){const d=DAY();[...new Set(names)].forEach(n=>{if(!n)return;const v=PHOTO[norm(n)];if(v&&(v[0]!=="-"||d-+v.slice(1)<10))return;if(!PHQ.includes(n))PHQ.push(n)});pumpPh()}
function pumpPh(){while(PHRUN<3&&PHQ.length){const n=PHQ.shift();PHRUN++;wikiPhoto(n).then(u=>{if(u!==null)setPhoto(n,u)}).catch(()=>{}).finally(()=>{PHRUN--;pumpPh()})}}
async function castTmdb(it){if(!S.set.tmdbKey||!it.tmdbId||it.tmdbId==="0"||it._ct)return;it._ct=1;
 try{const r=await tmdb((it.type==="f"?"movie/":"tv/")+it.tmdbId+(it.type==="f"?"/credits":"/aggregate_credits"));const L=(r&&r.cast)||[];let ch=false;
  if(!it.cast.length&&L.length){it.cast=castList(L.slice(0,12).map(c=>c.name).join(","));it.cast.forEach(([a])=>{const C=CRED[a]=CRED[a]||[];if(!C.some(x=>x[0]===it.id))C.push([it.id,""])});ch=true}
  L.forEach(c=>{if(c.profile_path)setPhoto(c.name,"https://image.tmdb.org/t/p/w185"+c.profile_path);const role=c.character||(c.roles&&c.roles[0]&&c.roles[0].character)||"";const e=it.cast.find(x=>norm(x[2]||A[x[0]]||"")===norm(c.name||""));if(e&&!e[1]&&role){e[1]=role;ch=true}});
  const t=topS();if(ch&&t.t==="detail"&&t.id===it.id&&!S.modal)render(F&&F.dataset.fid)}catch(e){}}

/* ========================= TV EN DIRECT : GENRES ET PAYS ========================= */
const GENRES=[["gen","Généralistes"],["info","Info"],["sport","Sport"],["cine","Cinéma"],["series","Séries"],["kids","Jeunesse"],["docs","Découverte"],["music","Musique"],["divert","Divertissement"],["region","Régionales"],["other","Autres"]];
const GRULES=[
 ["region",/^(france 3|f3|ici) [a-z]|^bfm (paris|lyon|marseille|nice|alsace|grand|toulouse|normandie|dici|var|littoral)|^(tv7|tebeo|tebesud|tvr|via |7a limoges|tl7|weo|azur tv|maritima|alsace 20|vosges|8 mont blanc|telegrenoble|tv vendee|tv tours|grand lille|lyon capitale|canal 32|bip tv|kanaldude)/],
 ["info",/^(bfm ?tv|bfm business|bfm$|cnews|lci|franceinfo|france info|france 24|euronews|lcp|public senat|i24|bloomberg|cnbc|cnn|bbc news|sky news|al jazeera|rt france|tv5 ?monde info|lci )|\binfo\b|\bnews\b/],
 ["sport",/(sport|\bequipe\b|bein|eurosport|rmc sport|infosport|dazn|automoto|equidia|golf|foot\+|foot |\bol tv|\bom tv|ligue 1|tennis|motor|fight|\bnba\b|\bnfl\b|\bf1\b|racing|ufc|wwe|courses)/],
 ["kids",/(gulli|canal j|tiji|disney|nickelodeon|nick jr|\bnick\b|cartoon|boomerang|boing|piwi|teletoon|toonami|mangas|j ?one|baby|kids|junior|okoo|ludikids|kidz|enfant|dessin)/],
 ["cine",/(cine\+|cine |cinema|\bocs\b|\btcm\b|paramount channel|^action$|cine fx|frisson|emotion|famiz|classic|premier|\bfilms?\b|movies?|hollywood|box office)/],
 ["series",/(series?\b|warner tv|13e rue|13eme rue|syfy|tv breizh|polar|\bab1\b|comedie\+|paramount network|novelas|serie club)/],
 ["docs",/(decouverte|france 5|national geographic|nat ?geo|discovery|planete|histoire|ushuaia|science|animaux|seasons|chasse|peche|trek|voyage|crime district|investigation|museum|explore|animal|nature|documentaire|docu|arte)/],
 ["music",/(\bmtv\b|\bmcm\b|m6 music|nrj hits|trace|mezzo|cstar|rfm|melody|clubbing|music|musique|bblack|virgin|radio)/],
 ["divert",/(teva|paris premiere|rtl ?9|game ?one|^e!|cuisine|elle girl|novo ?19|t18|kto|comedy|comedie|jeux|fashion|luxe|telesud|ab3|tv5)/],
 ["gen",/^(tf1|france 2|france 3|france 4|m6|c8|w9|tmc|tfx|nrj 12|6ter|rmc story|cherie 25|canal\+|canal plus|tv5 ?monde|rtl|rtbf|la une|tipik|la trois|rts|tsr|tva|tele quebec|noovo|ici radio|lcn)\b/]];
const GCAT=[["sport",/sport|foot|ligue/],["info",/info|news|actu/],["kids",/kid|enfant|jeunesse|cartoon|anim/],["cine",/cinema|film|movie|vod/],["series",/serie/],["docs",/doc|decouv|nature|histoire/],["music",/music|musique|radio/],["region",/region/],["gen",/tnt|generalist|national|hertzien|premium/]];
function genreOf(name,cat){const n=norm(name).replace(/[^a-z0-9+! ]+/g," ").replace(/\s+/g," ").trim();
 if(/^(france 2|france 4|m6|tf1|tmc|w9|tfx|c8|6ter|cherie 25|nrj 12|rmc story)$/.test(n))return "gen";
 if(n==="arte"||n==="france 5")return n==="arte"?"gen":"docs";
 for(const [g,re] of GRULES)if(re.test(n))return g;const c=norm(cat||"");for(const [g,re] of GCAT)if(re.test(c))return g;return "other"}
const TNT=["tf1","france 2","france 3","canal+","france 5","m6","arte","c8","w9","tmc","tfx","nrj 12","lcp","france 4","bfm tv","cnews","cstar","gulli","t18","tf1 series films","l equipe","6ter","rmc story","rmc decouverte","cherie 25","lci","franceinfo"];
function tntRank(name){const n=norm(name).replace(/[^a-z0-9+ ]+/g," ").replace(/\s+/g," ").trim();const i=TNT.indexOf(n);return i<0?999:i+1}
const PAYS={FR:"France",BE:"Belgique",CH:"Suisse",CA:"Canada",QC:"Québec",UK:"Royaume-Uni",GB:"Royaume-Uni",US:"États-Unis",USA:"États-Unis",DE:"Allemagne",ES:"Espagne",IT:"Italie",PT:"Portugal",NL:"Pays-Bas",AR:"Pays arabes",MA:"Maroc",DZ:"Algérie",TN:"Tunisie",TR:"Turquie",AF:"Afrique",PL:"Pologne",RO:"Roumanie",IN:"Inde",BR:"Brésil",LU:"Luxembourg",EXYU:"Ex-Yougoslavie",AL:"Albanie",GR:"Grèce",RU:"Russie"};
function countryOf(raw,cat){const m=String(raw||"").match(/^\s*[\[(|]?\s*([A-Z]{2,4})\s*[\])|:\-–•]/)||String(cat||"").match(/^\s*[\[(|]?\s*([A-Z]{2,4})\s*[\])|:\-–•]/);return m?m[1]:"FR"}
