/* ========================= DONNÉES (Xtream Codes) ========================= */
const NATIVE=!!window.Prisme;
let FILMS=[],SERIES=[],CHS=[],CH={},ALL={},A={},CRED={},FCATS=[],SCATS=[];
let LCATS=[["all","Toutes les chaînes"],["fav","Favoris"]];
const DATA={};            // données brutes par playlist (en mémoire)
const RX={};              // notes complémentaires (MDBList / What's on?, à venir)
let TREND={f:[],s:[]};
let CATV=0;const MEMO={};const bump=()=>CATV++;    // tendances TMDB (si clé TMDB)
const META=[["imdb","IMDb","IMDb"],["tmdb","TMDB","TMDB"],["rt","Rotten Tomatoes","RT"],["mc","Metacritic","MC"],["lb","Letterboxd","Lb"],["ac","AlloCiné","AlloCiné"],["sc","SensCritique","SC"]];
const PAL=[["#8a6b3d","#0d1422"],["#d9823b","#2b1206"],["#5b7c99","#0b1118"],["#c8323a","#1d3b22"],["#9ec5e8","#05070d"],["#c9a227","#0e1a2b"],["#ff5fa2","#5b1036"],["#7fb347","#1c2b12"],["#e3342f","#0a0a14"],["#9c6b3f","#0f0d0b"],["#6ee7f9","#0b1730"],["#f5b942","#2c2a6b"],["#b7a57a","#141414"],["#7aa2c2","#0c1520"]];
const FONTS=["bebas","serif","black","thin"];
const CHCOL=["#1e4fd8","#d1162c","#159a48","#6d2fd6","#e08a00","#0a8fd0","#c21875","#0f766e","#4b4b4b","#8b2bd6"];

const proxied=u=>NATIVE?"https://appassets.androidplatform.net/proxy?u="+encodeURIComponent(u):u;
async function getJSON(u,timeout=60000){
 const ctl=new AbortController(),t=setTimeout(()=>ctl.abort(),timeout);
 try{const r=await fetch(proxied(u),{signal:ctl.signal});if(!r.ok)throw new Error("le serveur répond "+r.status);const txt=await r.text();return txt?JSON.parse(txt):null}
 catch(e){throw new Error(e.name==="AbortError"?"délai dépassé":e.message)}finally{clearTimeout(t)}}
const clean=u=>(u||"").trim().replace(/\/+$/,"");
const api=(pl,action,extra="")=>`${clean(pl.url)}/player_api.php?username=${encodeURIComponent(pl.user)}&password=${encodeURIComponent(pl.pass)}${action?"&action="+action:""}${extra}`;
const b64=s=>{try{return decodeURIComponent(escape(atob(s||"")))}catch(e){return s||""}};
const catKey=n=>"k"+hash(norm(n)).toString(36);

/* Nom Xtream → titre, année, qualité, langue. Ex : "FR| Intouchables (2011) 4K MULTI" */
const QTOK=/\b(4k|uhd|2160p?|fhd|1080p?|hd|720p?|sd|hevc|h\.?26[45]|x26[45]|multi|vostfr|vost|vff|vfq|vf|vo|truefrench|french|hdr10\+?|hdr|dv|10bits?|ac3|eac3|dts|atmos|web(-?dl)?|bluray|remux)\b/gi;
function parseName(raw){
 let s=String(raw||"").replace(/^\s*[\[(]?[A-Z]{2,4}[\])]?\s*[|:\-–•]\s*/i,"").replace(/^\s*[A-Z]{2,4}\s*\|\s*/,"");
 const ym=s.match(/\((19|20)\d{2}\)/)||s.match(/[\s\-–](19|20)\d{2}\s*$/);
 const low=s.toLowerCase();
 const q=/(\b4k\b|uhd|2160)/.test(low)?"4K":/(fhd|1080)/.test(low)?"1080p":/(\b720p?\b|\bhd\b)/.test(low)?"720p":/\bsd\b/.test(low)?"SD":"Auto";
 const tag=/multi/.test(low)?"MULTI":/vostfr|vost\b/.test(low)?"VOSTFR":/\bvo\b/.test(low)?"VO":"VF";
 let title=s.replace(/\((19|20)\d{2}\)/,"").replace(QTOK,"").replace(/[\[\]()|]+/g," ").replace(/\s{2,}/g," ").trim().replace(/[\s\-–:.]+$/,"");
 if(ym&&!/\(/.test(ym[0]))title=title.replace(/[\s\-–](19|20)\d{2}$/,"").trim();
 return {title:title||String(raw),year:ym?+ym[0].replace(/\D/g,""):0,q,tag};
}
const mapCats=a=>{const m={};(a||[]).forEach(c=>m[c.category_id]=c.category_name||"Autres");return m};

async function loadPlaylist(pl,step=()=>{}){
 step(0);const auth=await getJSON(api(pl,""),20000);
 if(!auth||!auth.user_info)throw new Error("réponse Xtream invalide (vérifie l'URL)");
 if(String(auth.user_info.auth)!=="1")throw new Error("identifiants refusés par le serveur");
 const D={info:auth.user_info,server:auth.server_info||{}};
 step(1);const [lc,vc,sc]=await Promise.all([getJSON(api(pl,"get_live_categories")),getJSON(api(pl,"get_vod_categories")),getJSON(api(pl,"get_series_categories"))]);
 D.lc=mapCats(lc);D.vc=mapCats(vc);D.sc=mapCats(sc);
 step(2);D.live=(await getJSON(api(pl,"get_live_streams"))||[]).map(x=>({id:x.stream_id,n:x.name||"",logo:x.stream_icon||"",cat:x.category_id,num:+x.num||0,arch:+x.tv_archive||0}));
 step(3);D.vod=(await getJSON(api(pl,"get_vod_streams"),120000)||[]).map(x=>({id:x.stream_id,n:x.name||"",img:x.stream_icon||"",cat:x.category_id,r:+x.rating||0,added:+x.added||0,ext:x.container_extension||"mp4",tmdb:String(x.tmdb||x.tmdb_id||"")}));
 step(4);D.ser=(await getJSON(api(pl,"get_series"),120000)||[]).map(x=>({id:x.series_id,n:x.name||"",img:x.cover||"",cat:x.category_id,r:+x.rating||0,added:+(x.last_modified||0),plot:x.plot||"",cast:x.cast||"",dir:x.director||"",genre:x.genre||"",year:String(x.releaseDate||x.release_date||"").slice(0,4),bd:(Array.isArray(x.backdrop_path)?x.backdrop_path[0]:x.backdrop_path)||"",tmdb:String(x.tmdb||"")}));
 DATA[pl.id]=D;pl.exp=D.info.exp_date?+D.info.exp_date*1000:null;pl.maxc=+D.info.max_connections||0;pl.actc=+D.info.active_cons||0;
 pl.fmt=(D.info.allowed_output_formats||[]).includes("ts")?"ts":((D.info.allowed_output_formats||[])[0]||"ts");
 pl.loadedAt=Date.now();
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
   const cn=D.vc[v.cat]||"Autres",ck=catKey(cn);if(!it.cat.includes(ck))it.cat.push(ck);if(!fc.has(ck))fc.set(ck,cn);
   it.src.push({pl:pl.id,sid:v.id,ext:v.ext,q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added});
   if(!it.img&&v.img)it.img=v.img;if(v.r&&!it.info){it.tmdb=Math.round(v.r*10)}}
  for(const v of D.ser){const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:norm(p.title)+"|"+(p.year||v.year);let it=byKey["s"+key];
   if(!it){it=byKey["s"+key]=mk("s",key,p,v);if(!it.y)it.y=+v.year||0;SERIES.push(it);ALL[it.id]=it}
   const cn=D.sc[v.cat]||"Autres",ck=catKey(cn);if(!it.cat.includes(ck))it.cat.push(ck);if(!sc.has(ck))sc.set(ck,cn);
   it.src.push({pl:pl.id,sid:v.id,ext:"mkv",q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added});
   if(!it.img&&v.img)it.img=v.img;if(!it.bd&&v.bd)it.bd=v.bd;
   if(!it.info){if(!it.s&&v.plot)it.s=v.plot;if(!it.dir&&v.dir)it.dir=v.dir;if(!it.g.length&&v.genre)it.g=v.genre.split(/[,/]/).map(x=>x.trim()).filter(Boolean).slice(0,3);if(v.r)it.tmdb=Math.round(v.r*10);
    if(!it.cast.length&&v.cast)it.cast=castList(v.cast)}}
  for(const v of D.live){const p=parseName(v.n),cn=D.lc[v.cat]||"Autres",ck=catKey(cn),key=norm(p.title);let c=byKey["c"+key];
   if(!c){const h=hash(key);c=byKey["c"+key]={id:"c"+h.toString(36),n:p.title,cat:ck,col:CHCOL[h%CHCOL.length],num:v.num||CHS.length+1,logo:v.logo,src:[]};CHS.push(c);CH[c.id]=c}
   if(!lc.has(ck))lc.set(ck,cn);if(!c.logo&&v.logo)c.logo=v.logo;
   c.src.push({pl:pl.id,sid:v.id,q:p.q,name:v.n,cat:ck,arch:v.arch})}}
 CHS.sort((a,b)=>a.num-b.num);
 FCATS=[...fc.entries()];SCATS=[...sc.entries()];
 LCATS=[["all","Toutes les chaînes"],["fav","Favoris"],...lc.entries()];
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
   if(f.cast||f.actors)it.cast=castList(f.cast||f.actors)}
  else{const r=await getJSON(api(pl,"get_series_info","&series_id="+s.sid),30000)||{};const f=r.info||{};
   it.s=f.plot||it.s;it.dir=f.director||it.dir;if(f.genre)it.g=String(f.genre).split(/[,/]/).map(x=>x.trim()).filter(Boolean).slice(0,3);
   const bd=Array.isArray(f.backdrop_path)?f.backdrop_path[0]:f.backdrop_path;if(bd)it.bd=bd;if(f.rating)it.tmdb=Math.round(+f.rating*10);
   if(f.cast)it.cast=castList(f.cast);
   const eps=r.episodes||{};it.eps={};it.seasons=Object.keys(eps).map(Number).filter(n=>!isNaN(n)).sort((a,b)=>a-b);
   it.seasons.forEach(n=>{it.eps[n]=(eps[n]||[]).map(e=>({id:e.id,num:+e.episode_num||0,t:e.title||("Épisode "+e.episode_num),ext:e.container_extension||"mkv",dur:Math.round((+(e.info&&e.info.duration_secs)||0)/60),img:(e.info&&e.info.movie_image)||"",plot:(e.info&&e.info.plot)||""})).sort((a,b)=>a.num-b.num)});
   it.se=it.seasons.map(n=>it.eps[n].length);it.ep=(it.eps[it.seasons[0]]||[])[0]?.dur||0;it.srcPl=s.pl}
  it.info=true;it.cast.forEach(([a])=>{const L=CRED[a]=CRED[a]||[];if(!L.some(x=>x[0]===it.id))L.push([it.id,""])});
 }catch(e){toast("Fiche indisponible : "+e.message)}
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
