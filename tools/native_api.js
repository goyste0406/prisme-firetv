/* ========================= INTERFACE NATIVE (films et séries, version 2) =========================
   L'interface native (Kotlin) affiche l'accueil, les genres et les fiches ; elle demande ses données ici.
   Le catalogue, les sources, la qualité, les favoris et la lecture restent gérés par cette couche. */
const NAT={ok:NATIVE&&typeof Prisme.nativeOk==="function",dead:false,vis:false,detail:"",pre:null,gv:0,pt:null};
const natOn=()=>NAT.ok&&!NAT.dead&&!S.set.legacy&&inApp();
const tmS=(u,sz)=>u?String(u).replace(/(image\.tmdb\.org\/t\/p\/)(original|w\d+)\//,"$1"+sz+"/"):"";
function natShow(tab){if(!NAT.ok)return;NAT.vis=true;Prisme.nativeShow(tab||"")}

/* Genres : liste fixe (TMDB en français), un titre peut en avoir plusieurs */
const GDEF={
 f:[["action","Action","#e3342f","#3a0a0a",/action/],["comedie","Comédie","#f5b942","#5b3a06",/comed|humour|comique|comedy/],["drame","Drame","#7aa2c2","#0c1520",/drame|drama/],
  ["thriller","Thriller","#5b7c99","#05070d",/thriller|suspense/],["policier","Policier","#9c6b3f","#1a120b",/polic|crime|criminel|gangster|mafia|polar/],
  ["sf","Science-fiction","#6ee7f9","#0b1730",/science|sci-?fi|\bs\.?f\b/],["horreur","Horreur","#c8323a","#0a0a0a",/horreur|horror|epouvante|gore|slasher/],
  ["animation","Animation","#ff9f0a","#5b1036",/anim|dessin|cartoon|manga|pixar|disney/],["familial","Familial","#7fb347","#1c2b12",/famil|enfant|kids|jeunesse/],
  ["aventure","Aventure","#c9a227","#0e1a2b",/aventure|adventure/],["romance","Romance","#ff5fa2","#5b1036",/romance|romanti|amour|love/],
  ["fantastique","Fantastique","#bf5af2","#1d0b30",/fantas|merveilleux/],["mystere","Mystère","#8e7cc3","#120c22",/myst|enquete/],
  ["documentaire","Documentaire","#90cea1","#0f2a1d",/docu/],["histoire","Histoire","#b08d57","#1f150a",/histo|peplum|biopic|biograph/],
  ["guerre","Guerre","#b7a57a","#141414",/guerre|\bwar\b|militaire/],["musique","Musique","#ff375f","#2a0612",/musi|concert/],
  ["western","Western","#d9823b","#2b1206",/western/],["telefilm","Téléfilm","#8e939e","#16181d",/telefilm|tv ?movie/],["autres","Autres","#5d6270","#16181d",null]],
 s:[["drame","Drame","#7aa2c2","#0c1520",/drame|drama/],["policier","Policier","#9c6b3f","#1a120b",/polic|crime|criminel|gangster|mafia|polar/],
  ["comedie","Comédie","#f5b942","#5b3a06",/comed|humour|sitcom|comique|comedy/],["action","Action & Aventure","#e3342f","#3a0a0a",/action|aventure|adventure/],
  ["sf","Science-fiction & Fantastique","#6ee7f9","#0b1730",/science|sci-?fi|fantas|\bs\.?f\b/],["mystere","Mystère","#8e7cc3","#120c22",/myst|thriller|suspense|enquete/],
  ["animation","Animation","#ff9f0a","#5b1036",/anim|cartoon|manga/],["jeunesse","Jeunesse","#30d158","#0b2a16",/jeunesse|enfant|kids|junior/],
  ["familial","Familial","#7fb347","#1c2b12",/famil/],["documentaire","Documentaire","#90cea1","#0f2a1d",/docu/],
  ["realite","Téléréalité","#ff5fa2","#5b1036",/realite|reality/],["feuilleton","Feuilleton","#c9a227","#2b1f06",/feuilleton|soap|novela/],
  ["guerre","Guerre & Politique","#b7a57a","#141414",/guerre|\bwar\b|politi/],["western","Western","#d9823b","#2b1206",/western/],
  ["talk","Talk-show","#bf5af2","#1d0b30",/talk|debat/],["actu","Actualités","#0a84ff","#06142b",/actu|news/],["autres","Autres","#5d6270","#16181d",null]]};
function catLabels(ty){return memo("cl"+ty,()=>{const m={};(ty==="f"?FCATS:SCATS).forEach(([k,n])=>m[k]=n);return m})}
function genreKeys(it){
 if(it._gv===NAT.gv+"|"+CATV&&it._gk)return it._gk;
 const tk=typeof tgKeys==="function"?tgKeys(it):null;if(tk){it._gk=tk;it._gv=NAT.gv+"|"+CATV;return tk}
 const D=GDEF[it.type],cl=catLabels(it.type),out=[];
 const txt=[...(it.g||[]),...it.cat.map(k=>cl[k]||"")].map(x=>norm(String(x)));
 for(const g of D){if(g[4]&&txt.some(t=>g[4].test(t)))out.push(g[0])}
 if(!out.length)out.push("autres");
 it._gk=out;it._gv=NAT.gv+"|"+CATV;return out}
function genreIndex(ty){return memo("gi"+ty+"|"+NAT.gv,()=>{const m={};(ty==="f"?films():series()).forEach(i=>genreKeys(i).forEach(k=>(m[k]=m[k]||[]).push(i)));return m})}
let NATGB=null;
function natGenreBump(){clearTimeout(NATGB);NATGB=setTimeout(()=>{NAT.gv++;if(NAT.vis)Prisme.nativeEvent("home","")},4000)}

function metaArr(i){return (i.type==="f"?[i.y||"",i.d?dur(i.d):"",(i.g||[]).slice(0,2).join(" · ")]:[i.y||"",i.se&&i.se.length?`${i.se.length} saison${i.se.length>1?"s":""}`:"",(i.g||[]).slice(0,2).join(" · "),i.net||""]).filter(Boolean).map(String)}
const tmdbTxt=i=>i.tmdb?(i.tmdb/10).toFixed(1).replace(".",",")+"/10":"";
function nI(i,full){const o={id:i.id,ty:i.type,t:i.t,y:i.y||0,img:tmS(i.img,"w342"),f:i.f,c1:i.c[0],c2:i.c[1],nw:isRecent(i.id),pr:S.prog[i.id]||0};
 if(full){o.bd=tmS(i.bd,"w1280");o.kick=(i.type==="f"?"Film":"Série")+((i.g||[])[0]?" · "+i.g[0]:"");o.meta=metaArr(i);o.s=String(i.s||"").slice(0,280);o.tmdb=tmdbTxt(i);o.age=i.age||""}
 return o}
/* Séries suivies (regardées ou dans Ma liste) mises à jour chez le fournisseur depuis la dernière visite */
function newEps(){if(!S.seen){S.seen={};const now=Date.now();[...S.favs,...Object.keys(S.lastEp||{}),...Object.keys(S.prog)].forEach(k=>{if(ALL[k]&&ALL[k].type==="s")S.seen[k]=now});save()}
 return Object.keys(S.seen).map(k=>ALL[k]).filter(i=>{if(!i||i.type!=="s"||!anySrc(i.id))return false;let m=0;for(const s of i.src)if(s.added>m)m=s.added;return m*1000>S.seen[i.id]})
  .sort((a,b)=>Math.max(...b.src.map(s=>s.added||0))-Math.max(...a.src.map(s=>s.added||0))).slice(0,30)}
function natVer(ty){return [(typeof NOWP!=="undefined"?NOWP.f.length+"/"+NOWP.s.length:""),CATV,DIRTY,S.favs.length,Object.values(S.seen||{}).reduce((a,b)=>a+b,0)%1e9,Object.keys(S.prog).length,TREND.f.length,TREND.s.length,NAT.gv,ty].join("|")}

window.nativeApi={
 ver(ty){return natVer(ty)},
 home(ty){
  const list=ty==="f"?films():series();
  const ok=i=>i&&i.type===ty&&srcs(i.id).length;
  const cont=Object.keys(S.prog).reverse().map(k=>ALL[k]).filter(ok).slice(0,30);
  const fav=S.favs.map(k=>ALL[k]).filter(ok).slice(0,40);
  const recent=memo("nre"+ty,()=>list.map(i=>[i,added(i.id)]).filter(x=>x[1]).sort((a,b)=>a[1].d-b[1].d).slice(0,30).map(x=>x[0]));
  const trend=memo("ntr"+ty+TREND[ty].length,()=>[...list].sort((a,b)=>trendScore(b)-trendScore(a)).slice(0,10));
  const nep=ty==="s"?newEps():[];
  const nowp=(NOWP[ty]||[]).filter(i=>ok(i)).slice(0,30);
  const rows=[["cont","Continuer à regarder",cont,""],["nep","Nouveaux épisodes",nep,""],["nowp",ty==="f"?"Sorties récentes au cinéma":"Séries en cours de diffusion",nowp,""],["fav","Ma liste",fav,""],["new","Derniers ajouts",recent,""],["top",ty==="f"?"Top 10 des films du moment":"Top 10 des séries du moment",trend,"rank"]]
   .filter(r=>r[2].length).map(([k,title,items,kind])=>({k,title,small:k==="new"||k==="top"?"":String(items.length),kind,items:items.map(i=>nI(i,true))}));
  const gi=genreIndex(ty);
  const genres=GDEF[ty].filter(g=>(gi[g[0]]||[]).length).map(g=>({k:g[0],n:g[1],c:gi[g[0]].length,c1:g[2],c2:g[3]}));
  return JSON.stringify({v:natVer(ty),rows,genres});
 },
 genre(ty,k,sort){
  const g=GDEF[ty].find(x=>x[0]===k)||["","Genre","#2b3245","#0a0b10"];
  const L=memo("ng"+ty+k+sort+"|"+NAT.gv,()=>{const a=[...(genreIndex(ty)[k]||[])];
   if(sort==="az")a.sort((x,y)=>String(x.t).localeCompare(String(y.t),"fr"));
   else if(sort==="note")a.sort((x,y)=>(y.tmdb||0)-(x.tmdb||0));
   else{const d=i=>{const a2=added(i.id);return a2?a2.d:1e9};a.sort((x,y)=>d(x)-d(y))}return a});
  return JSON.stringify({title:g[1],kick:`${ty==="f"?"Films":"Séries"} · ${L.length} titre${L.length>1?"s":""}`,c1:g[2],c2:g[3],items:L.map(i=>nI(i,false))});
 },
 /* Demande de la fiche par l'interface native : lance une seule fois le chargement des infos, l'analyse et les photos */
 detail(id){
  const it=ALL[id];if(!it)return JSON.stringify({error:"introuvable"});
  NAT.detail=id;
  if(!it.info&&!it.loading&&Date.now()-(it._lt||0)>60000){it._lt=Date.now();loadInfo(it)}
  setTimeout(()=>{if(!P)analyze(id)},80);
  setTimeout(()=>{if(!it.loading&&(!it.s||!it.bd))tmdbFill(it)},it.info?200:4000);
  const o=natData(id);
  NAT.last=JSON.stringify(o);return NAT.last;
 },
 fav(id){const it=ALL[id];if(!it)return JSON.stringify({});toggleFav(id,it.t);return JSON.stringify({fav:isFav(id),msg:isFav(id)?`Ajouté à Ma liste : ${it.t}`:`Retiré de Ma liste : ${it.t}`})},
 play(id,src,ss,ep){
  const it=ALL[id];if(!it)return JSON.stringify({ok:false,msg:"Titre introuvable"});
  if(src){const vv=srcs(id).find(x=>x.id===src);if(vv&&!compat(vv))return JSON.stringify({ok:false,msg:"Source 4K non lisible sur ton Fire TV Stick (1080p max)"});if(vv){S.srcSel[id]=src;save()}}
  if(it.type==="s"&&!it.info)return JSON.stringify({ok:false,msg:"Épisodes en cours de chargement"});
  const v=pickSrc(id);if(!v)return JSON.stringify({ok:false,msg:"Aucune source disponible"});
  if(P)stopPlayer();
  if(topS().t==="player")S.stack.pop();
  S.modal=null;
  let p,res="";
  if(it.type==="f"){const pos=(S.prog[id]||0)*(it.d||0)*60;p={kind:"vod",id,src:v.id,dur:(it.d||0)*60,pos,playing:true};if(pos>60)res="reprise à "+dur(Math.round(pos/60))}
  else{const sn=(it.seasons||[])[ss-1];const L=(it.eps||{})[sn]||[];const e=L.find(x=>x.num===ep)||L[0];if(!e)return JSON.stringify({ok:false,msg:"Épisode introuvable"});
   const vv=srcs(id).find(z=>z.p.id===it.srcPl);p={kind:"vod",id,src:vv?vv.id:v.id,ss,ep:e.num,dur:(e.dur||0)*60,pos:0,playing:true};res=`S${sn} · E${e.num}`;S.seasons[id]=ss}
  p.nat=true;p.natUi=true;p.t0=Date.now();
  PQ.splice(0).forEach(([k])=>{if(QPEND[k]==="probe")delete QPEND[k]});
  S.stack.push({t:"player"});
  const busy=NATIVE&&!NAT.pre&&(PQRUN||Prisme.probeBusy());
  NAT.pre=null;
  startPlayer(p);
  const cv=curVar();
  if(busy)setTimeout(()=>{if(P===p&&!p.go)Prisme.nativeEvent("loading",JSON.stringify({msg:"Analyse du flux en cours, démarrage dans un instant…"}))},300);
  return JSON.stringify({ok:true,t:it.t,f:it.f,c1:it.c[0],c2:it.c[1],bd:tmS(it.bd,"w1280"),img:tmS(it.img,"w342"),q:cv&&qr(cv.q)>0&&cv.q!=="Auto"?cv.q:"",src:[cv?cv.p.name:"",cv?cv.tag:"",res].filter(Boolean).join(" · ")});
 },
 cancel(){if(P&&P.nat){stopPlayer();if(topS().t==="player")S.stack.pop();NAT.vis=true}return ""},
 preload(id,ss,ep){
  if(!S.set.preload||P||PQRUN||NAT.pre||(NATIVE&&Prisme.probeBusy()))return "";
  const it=ALL[id];if(!it)return "";const v=pickSrc(id);if(!v||!compat(v))return "";
  let url="",pos=0;
  const mk=s=>[clean(s.url),encodeURIComponent(s.user),encodeURIComponent(s.pass)];
  if(it.type==="f"){const [u,us,pw]=mk(v.p);url=`${u}/movie/${us}/${pw}/${v.sid}.${v.ext}`;pos=(S.prog[id]||0)*(it.d||0)*60}
  else{if(!it.info)return "";const sn=(it.seasons||[])[ss-1];const e=((it.eps||{})[sn]||[]).find(x=>x.num===ep);if(!e)return "";
   const vv=srcs(id).find(z=>z.p.id===it.srcPl)||v;const [u,us,pw]=mk(vv.p);url=`${u}/series/${us}/${pw}/${e.id}.${e.ext}`}
  NAT.pre=url;Prisme.preload(url,Math.round(pos*1000));return "";
 },
 unpreload(){if(NAT.pre&&!P)Prisme.unpreload();NAT.pre=null;setTimeout(pumpProbe,1500);return ""},
 tab(v){NAT.vis=false;S.tab=v;S.modal=null;S.stack=[{t:"home"}];save();render("tab-"+v);return ""},
 web(kind,id){NAT.vis=false;S.retNat=true;S.modal=null;S.stack=[{t:"home"},{t:kind,id}];render(null);return ""},
 resume(){NAT.vis=false;S.stack=S.stack.filter(x=>x.t!=="player");S.modal=null;render(topS().last);return ""}
};

/* Fiche native : mise à jour quand les infos, la qualité ou les photos arrivent */
/* Contenu d'une fiche pour l'interface native (sans effet de bord : appelé à chaque mise à jour) */
function natData(id){
  const it=ALL[id];if(!it)return {error:"introuvable",cast:[]};
  const L=srcs(id),cur=pickSrc(id),isS=it.type==="s";
  const o={id,ty:it.type,t:it.t,f:it.f,c1:it.c[0],c2:it.c[1],img:tmS(it.img,"w342"),bd:tmS(it.bd,"w1280"),
   kick:(isS?"Série":"Film")+((it.g||[])[0]?" · "+it.g[0]:""),meta:metaArr(it),age:it.age||"",tmdb:tmdbTxt(it),imdb:it.imdb?it.imdb.toFixed(1):"",
   s:it.s||(!it.info&&!it.loading&&it.infoErr?`Résumé indisponible : le serveur n'a pas répondu (${it.infoErr})`:""),dir:it.dir||"",loading:!it.info&&!!it.loading,fav:isFav(id)};
  const nm=c=>A[c[0]]||c[2]||"";
  o.castLine=it.cast.slice(0,3).map(nm).filter(Boolean).join(", ");
  o.cast=it.cast.slice(0,14).map(c=>({id:c[0],n:nm(c),r:c[1]||"",ph:photoOf(nm(c))}));
  wantPhotos(o.cast.map(c=>c.n).filter(Boolean));
  const ad=added(id);o.added=ad?(ad.d===0?"aujourd'hui":ad.d===1?"hier":`il y a ${ad.d} jours`)+" sur "+ad.p.name:"";
  o.sources=L.map(v=>({id:v.id,q:v.q,pl:v.p.name,name:v.name||"",codec:v.codec||"",audio:(v.audio||[]).join(" | "),subs:(v.subs||[]).join(", "),fmt:"."+(v.ext||""),ok:compat(v),def:!!cur&&cur.id===v.id}));
  if(cur){o.srcLine=[cur.p.name,cur.q,cur.tag].filter(Boolean).join(" · ");o.srcQ=qr(cur.q)>0&&cur.q!=="Auto"?cur.q:""}
  if(!isS){const pr=S.prog[id]||0;o.playLabel=pr>0.02&&it.d?`Reprendre à ${dur(Math.round(pr*it.d))}`:"Lecture"}
  else{
   const le=(S.lastEp||{})[id],sn=it.seasons||[];
   o.seasons=sn.map((n,i)=>({n:String(n),label:"Saison "+n,eps:((it.eps||{})[n]||[]).map(e=>({num:e.num,t:epTitle(e,it)||("Épisode "+e.num),d:e.dur?e.dur+" min":"",img:tmS(e.img,"w300"),q:e.q||"",pr:le&&le.ss===i+1&&le.ep===e.num?(le.pct||0):0}))}));
   if(le&&sn[le.ss-1]!=null){o.resume={ss:le.ss,ep:le.ep};o.ssel=le.ss-1;o.playLabel=`Reprendre S${sn[le.ss-1]} E${le.ep}`}
   else{o.ssel=0;const e0=((it.eps||{})[sn[0]]||[])[0];o.playLabel=it.info&&e0?`Lecture S${sn[0]} E${e0.num}`:"Lecture"}
  }
  o.similar=memo("nsim"+id,()=>[...films(),...series()].filter(x=>x.id!==id&&x.type===it.type&&((it.g||[]).length?(x.g||[]).some(g=>it.g.includes(g)):x.cat[0]===it.cat[0])).slice(0,12)).map(i=>nI(i,false));
  return o;
}
function natPush(id){if(!NAT.vis||!id||NAT.detail!==id)return;clearTimeout(NAT.pt);NAT.pt=setTimeout(()=>{try{const s=JSON.stringify(natData(id));if(s!==NAT.last){NAT.last=s;Prisme.nativeEvent("detail",s)}}catch(e){}},350)}

/* Lecture lancée depuis le natif : changement de source automatique et nouvel essai si la connexion est encore occupée */
function natSwitch(reason){
 const it=ALL[P.id];if(!it||it.type!=="f"||P.kind!=="vod")return false;
 const L=srcs(P.id).filter(compat),i=L.findIndex(v=>v.id===P.src),nx=L[i+1];if(!nx)return false;
 const old=curVar();P.src=nx.id;P.t0=Date.now();P.err=0;P.retry=0;P.aSync=null;P.audio=null;P.sub=null;P.started=false;
 Prisme.play(streamUrl(),Math.round((P.pos||0)*1000),false);LOG(`Source changée (${reason}) : ${old?old.p.name+" "+old.q:""} → ${nx.p.name} ${nx.q}`);
 if(P.nat)Prisme.nativeEvent("loading",JSON.stringify({banner:`${old?old.p.name+" "+old.q:"La source"} ne répond pas · passage à ${nx.p.name} ${nx.q}`,q:qr(nx.q)>0&&nx.q!=="Auto"?nx.q:"",src:nx.p.name+(nx.tag?" · "+nx.tag:""),msg:"Démarrage de la vidéo…",warn:false}));
 else toast(`Source suivante : ${nx.p.name} ${nx.q}`);
 return true}
function natFail(msg){LOG("Lecture impossible · "+msg);if(P&&P.nat){Prisme.nativeEvent("playfail",JSON.stringify({msg:"Lecture impossible : "+msg}));stopPlayer();if(topS().t==="player")S.stack.pop();NAT.vis=true;return true}return false}
/* Appelé à chaque tour du lecteur : true = la suite de tick() est ignorée */
function natTick(st){
 if(!P)return true;
 if(!P.started&&(st.playing||(st.pos>0&&!st.buffering))){P.started=true;P.retry=0;if(P.nat)Prisme.nativeEvent("started","")}
 if(P.retryAt){if(Date.now()<P.retryAt)return true;P.retryAt=0;P.err=0;Prisme.play(streamUrl(),Math.round((P.pos||0)*1000),P.kind==="live");return true}
 if(st.error&&!P.err){
  const code=+((String(st.error).match(/(?:Response code|code)[: ]+(\d{3})/i)||[])[1]||0);
  if([401,403,429,456,458,503,509,551].includes(code)&&(P.retry||0)<5){
   P.retry=(P.retry||0)+1;P.retryAt=Date.now()+4000;P.err=1;LOG(`Serveur occupé (code ${code}) · nouvel essai ${P.retry} sur 5`);
   const m=`Connexion précédente en cours de fermeture… nouvel essai ${P.retry} sur 5`;
   if(P.nat)Prisme.nativeEvent("loading",JSON.stringify({msg:m,warn:true}));else toast(m);
   return true}
  if(!P.started){P.err=1;LOG("Erreur de lecture · "+String(st.error).slice(0,160));if(natSwitch("erreur"))return true;if(natFail(String(st.error).slice(0,120)))return true;P.err=0}
 }
 if(P&&!P.started&&!st.error&&P.nat&&!P.slowMsg&&Date.now()-(P.t0||0)>10000){P.slowMsg=1;Prisme.nativeEvent("loading",JSON.stringify({msg:"Le serveur met du temps à répondre…"}))}
 if(P&&!P.started&&!st.error&&P.nat&&Date.now()-(P.t0||0)>25000){P.t0=Date.now();P.slowMsg=0;if(natSwitch("délai dépassé"))return true;if(!P.slowFail){P.slowFail=1;return false}if(natFail("la vidéo ne démarre pas (pas de réponse du serveur)"))return true}
 return false}

/* ========================= ÉTAPE 2 : TMDB, genres réels, recherche et acteurs natifs ========================= */
/* Clé TMDB intégrée à l'appli à la compilation (secret GitHub) : utilisée si aucune clé n'est saisie */
if(NATIVE&&typeof Prisme.tmdbKey==="function"&&!S.set.tmdbKey){try{const k=Prisme.tmdbKey();if(k){S.set.tmdbKey=k;S.set.tmdbBuiltin=true;save()}}catch(e){}}

/* Genres TMDB rangés en arrière-plan, sans aucune demande au fournisseur IPTV, gardés sur l'appareil */
const TGM={f:{28:"action",12:"aventure",16:"animation",35:"comedie",80:"policier",99:"documentaire",18:"drame",10751:"familial",14:"fantastique",36:"histoire",27:"horreur",10402:"musique",9648:"mystere",10749:"romance",878:"sf",10770:"telefilm",53:"thriller",10752:"guerre",37:"western"},
 s:{10759:"action",16:"animation",35:"comedie",80:"policier",99:"documentaire",18:"drame",10751:"familial",10762:"jeunesse",9648:"mystere",10763:"actu",10764:"realite",10765:"sf",10766:"feuilleton",10767:"talk",10768:"guerre",37:"western"}};
let TG={};const TGS={run:false,done:0,found:0,todo:0,loaded:false,lastBump:0,dirty:0};
const nap=ms=>new Promise(r=>setTimeout(r,ms));
let TGSAVE=null;function tgSave(){clearTimeout(TGSAVE);TGSAVE=setTimeout(()=>{IDB.put("tg",TG).catch(()=>{})},8000)}
function tgKeys(it){const v=TG[it.id];if(!v||v[0]==="-")return null;const g=v.split(":")[1]||"";if(!g)return null;
 const M=TGM[it.type],out=[];g.split(",").forEach(x=>{const k=M[x];if(k&&!out.includes(k))out.push(k)});return out.length?out:null}
function tgBump(force){if(!TGS.dirty)return;if(!force&&Date.now()-TGS.lastBump<180000)return;TGS.lastBump=Date.now();TGS.dirty=0;NAT.gv++;if(NAT.vis)Prisme.nativeEvent("home","")}
async function tgRun(){
 if(TGS.run||!S.set.tmdbKey)return;TGS.run=true;
 try{
  if(!TGS.loaded){try{TG=(await IDB.get("tg"))||{}}catch(e){TG={}}TGS.loaded=true;NAT.gv++;if(NAT.vis)Prisme.nativeEvent("home","")}
  /* titres déjà vus avec un identifiant TMDB faux : une nouvelle chance, par le titre cette fois */
  for(const k of Object.keys(TG))if(TG[k]==="-"&&ALL[k]&&ALL[k].tmdbId&&ALL[k].tmdbId!=="0"&&!TG["~"+k]){delete TG[k];TG["~"+k]=1}
  const d=i=>{const a=added(i.id);return a?a.d:1e9};
  const todo=[...films(),...series()].filter(i=>!(i.id in TG)).sort((a,b)=>d(a)-d(b));
  TGS.todo=todo.length;let fails=0;
  for(const it of todo){
   if(!S.set.tmdbKey||!ALL[it.id])continue;
   while(P)await nap(5000);
   try{
    /* identifiant TMDB faux chez le fournisseur (404) : on l'oublie et on cherche par le titre */
    let r0=null;if(it.tmdbId&&it.tmdbId!=="0"){try{r0=await tmdb((it.type==="f"?"movie/":"tv/")+it.tmdbId)}catch(e){if(/404/.test(e.message))it.tmdbId="";else throw e}}
    if(it.tmdbId&&it.tmdbId!=="0"){const r=r0;
     TG[it.id]=r&&r.genres?it.tmdbId+":"+r.genres.map(g=>g.id).join(","):"-";
     if(r){if(!it.s&&r.overview&&isFr(r.overview))it.s=r.overview;if(!it.bd&&r.backdrop_path)it.bd="https://image.tmdb.org/t/p/w1280"+r.backdrop_path;if(!it.tmdb&&r.vote_average)it.tmdb=Math.round(r.vote_average*10)}}
    else{const y=it.y?(it.type==="f"?"&year=":"&first_air_date_year=")+it.y:"";
     const r=await tmdb(`search/${it.type==="f"?"movie":"tv"}?query=${encodeURIComponent(String(it.t).slice(0,80))}${y}`);
     const m=r&&r.results&&r.results[0];TG[it.id]=m?m.id+":"+(m.genre_ids||[]).join(","):"-";
     if(m){it.tmdbId=String(m.id);if(!it.bd&&m.backdrop_path)it.bd="https://image.tmdb.org/t/p/w1280"+m.backdrop_path;if(!it.tmdb&&m.vote_average)it.tmdb=Math.round(m.vote_average*10)}}
    if(TG[it.id][0]!=="-")TGS.found++;fails=0;
   }catch(e){fails++;if(/401/.test(e.message)){LOG("TMDB refuse la clé API : rangement des genres arrêté");break}
    if(/429/.test(e.message)||fails>5){await nap(30000);fails=0}}
   TGS.done++;TGS.dirty++;tgSave();tgBump(false);
   await nap(230);
  }
  tgBump(true);if(TGS.done)LOG(`Genres TMDB : ${TGS.found} titres classés sur ${TGS.done} vérifiés`);
 }finally{TGS.run=false}}
setTimeout(()=>tgRun(),20000);

/* Résumé et fond depuis TMDB quand le fournisseur ne les donne pas */
async function tmdbFill(it){
 if(!S.set.tmdbKey||it._tf||(it.s&&it.bd))return;it._tf=1;
 try{let id=it.tmdbId;
  if(!id||id==="0"){const y=it.y?(it.type==="f"?"&year=":"&first_air_date_year=")+it.y:"";const r=await tmdb(`search/${it.type==="f"?"movie":"tv"}?query=${encodeURIComponent(String(it.t).slice(0,80))}${y}`);const m=r&&r.results&&r.results[0];if(!m)return;id=it.tmdbId=String(m.id)}
  let r=null;try{r=await tmdb((it.type==="f"?"movie/":"tv/")+id)}catch(e){if(!/404/.test(e.message))throw e;
   const y=it.y?(it.type==="f"?"&year=":"&first_air_date_year=")+it.y:"";const q=await tmdb(`search/${it.type==="f"?"movie":"tv"}?query=${encodeURIComponent(String(it.t).slice(0,80))}${y}`);const m=q&&q.results&&q.results[0];if(!m)return;
   it.tmdbId=String(m.id);r=await tmdb((it.type==="f"?"movie/":"tv/")+it.tmdbId)}
  if(!r)return;
  if(!it.s&&r.overview&&isFr(r.overview))it.s=r.overview;if(!it.bd&&r.backdrop_path)it.bd="https://image.tmdb.org/t/p/w1280"+r.backdrop_path;
  if(!it.tmdb&&r.vote_average)it.tmdb=Math.round(r.vote_average*10);if(!(it.g||[]).length&&r.genres)it.g=r.genres.map(g=>g.name).slice(0,3);
  if(!it.d&&r.runtime)it.d=r.runtime;
  natPush(it.id)}catch(e){}}

/* Recherche native */
nativeApi.search=function(q){const old=S.q;S.q=String(q||"");let r;try{r=searchResults()}finally{S.q=old}wantPhotos(r.a.slice(0,20).map(a=>A[a]).filter(Boolean));
 return JSON.stringify({films:r.f.slice(0,60).map(i=>nI(i)),series:r.s.slice(0,60).map(i=>nI(i)),actors:r.a.slice(0,20).map(a=>({id:a,n:A[a],r:`${acred(a).length} titre${acred(a).length>1?"s":""}`,ph:photoOf(A[a])})),nf:r.f.length,ns:r.s.length})};
/* Page acteur native */
function natActor(aid){const n=A[aid]||"",cr=acred(aid);return {id:aid,n,ph:photoOf(n),count:cr.length,items:cr.map(([id,r])=>Object.assign(nI(ALL[id]),{role:r||""}))}}
nativeApi.actor=function(aid){const n=A[aid]||"";if(n)wantPhotos([n]);
 if(S.set.tmdbKey&&!ACTD[aid])loadActor(aid).then(()=>{if(NAT.vis)Prisme.nativeEvent("actor",JSON.stringify(natActor(aid)))});
 return JSON.stringify(natActor(aid))};
/* Après un arrêt de l'interface par manque de mémoire, on l'explique */
try{if(NATIVE&&typeof Prisme.lastCrash==="function"&&Date.now()-Prisme.lastCrash()<120000){LOG("L'interface a été relancée après un manque de mémoire");setTimeout(()=>toast("L'appli a manqué de mémoire et a été relancée"),4000)}}catch(e){}

/* ========================= ÉTAPES 3 et 4 : TV en direct et lecteur natifs =========================
   La liste des chaînes, le guide et l'aperçu en direct, puis le lecteur (films, épisodes, chaînes) sont dessinés en natif.
   Le choix des sources, les reprises, les nouveaux essais et l'épisode suivant restent gérés ici. */
/* Titre d'épisode lisible : sans le nom brut du fournisseur ni « S01E02 » */
function epTitle(e,it){let t=String(e&&e.t||"");const m=t.match(/S\d{1,2}\s*E\d{1,3}\s*[-–:·|]*\s*(.*)$/i);if(m)t=m[1];t=t.replace(/^[\s\-–:·|]+/,"").trim();
 if(!t||/^(É|E)pisode \d+$/i.test(t)||(it&&norm(t).includes(norm(it.t))))return "";return t}
function chQ(c){let b="";srcs("ch:"+c.id).forEach(v=>{if(qr(v.q)>0&&v.q!=="Auto"&&(!b||qr(v.q)>qr(b)))b=v.q});return b}
function chO(c,full){const e=epgAt(c);
 const o={id:c.id,n:c.n,num:c.rank<999?c.rank:c.num,logo:c.logo||"",col:c.col,q:chQ(c),pg:e.cur.t,s:fmt(e.cur.s),pct:Math.round(e.pct),fav:isFav("ch:"+c.id)};
 if(full){o.e=fmt(e.cur.e);o.g=e.cur.g&&e.cur.g!=="Direct"?e.cur.g:"";o.desc=String(e.cur.desc||"").slice(0,300);o.next=e.next.slice(0,3).map(p=>({s:fmt(p.s),t:p.t}));
  const L=srcs("ch:"+c.id),v=pickSrc("ch:"+c.id);o.ns=L.length;o.src=v?[v.p.name,qr(v.q)>0&&v.q!=="Auto"?v.q:""].filter(Boolean).join(" · "):""}
 return o}
function natLiveCats(){const C=chansC(),cnt=k=>k==="all"?C.length:k==="fav"?chans().filter(c=>isFav("ch:"+c.id)).length:C.filter(c=>c.genre===k).length;
 return LCATS.filter(([k])=>k==="all"||k==="fav"||cnt(k)>0).map(([k,n])=>({k,n,c:cnt(k)}))}
const natCatName=()=>(LCATS.find(x=>x[0]===S.lcat)||["","Toutes les chaînes"])[1];
nativeApi.live=function(cat){if(cat&&cat!==S.lcat){S.lcat=cat;save()}if(!LCATS.some(x=>x[0]===S.lcat))S.lcat="all";
 const L=liveList();L.slice(0,30).forEach(c=>epg(c));
 const sel=CH[S.lch]&&L.includes(CH[S.lch])?S.lch:(L[0]||{}).id||"";
 return JSON.stringify({cat:S.lcat,catName:natCatName(),cats:natLiveCats(),chans:L.slice(0,1500).map(c=>chO(c)),sel})};
nativeApi.ch=function(id){const c=CH[id];if(!c)return JSON.stringify({});epg(c);S.lch=id;return JSON.stringify(chO(c,true))};
nativeApi.guide=function(from,n){const L=liveList(),out=[];const a=Math.max(0,+from||0),b=Math.min(L.length,a+(+n||8));
 for(let i=a;i<b;i++){const c=L[i];const P2=epg(c);out.push({id:c.id,n:c.n,num:c.rank<999?c.rank:c.num,col:c.col,logo:c.logo||"",progs:P2.map(p=>({s:Math.round(p.s),e:Math.round(p.e),t:p.t,g:p.g&&p.g!=="Direct"?p.g:""}))})}
 return JSON.stringify({total:L.length,from:a,now:nowMin(),catName:natCatName(),chans:out})};
/* Aperçu en direct dans la liste des chaînes (une seule connexion : on arrête tout le reste) */
nativeApi.livePrev=function(id){const c=CH[id];if(!c)return "";S.lch=id;if(P&&P.kind==="live"&&P.id===id)return "";
 if(P)stopPlayer();S.stack=S.stack.filter(x=>x.t!=="player");
 startPlayer({kind:"live",id,src:srcId("ch:"+id),playing:true,nat:true,natUi:true,prev:true});return ""};
nativeApi.liveStop=function(){if(P&&P.kind==="live"){stopPlayer();S.stack=S.stack.filter(x=>x.t!=="player")}return ""};
nativeApi.liveFull=function(id){if(!(P&&P.kind==="live"&&P.id===id))nativeApi.livePrev(id);if(P){P.prev=false;P.natUi=true}if(topS().t!=="player")S.stack.push({t:"player"});return nativeApi.pinfo()};
nativeApi.unfull=function(){if(P)P.prev=true;S.stack=S.stack.filter(x=>x.t!=="player");return ""};
/* Lecteur natif */
nativeApi.pinfo=function(wl){if(!P)return JSON.stringify({none:true});const v=curVar(),fm=curFmt();
 const o={kind:P.kind,q:v&&qr(v.q)>0&&v.q!=="Auto"?v.q:"",src:v?v.p.name+(qr(v.q)>0&&v.q!=="Auto"?" · "+v.q:""):"",ns:srcs(curKey()).length,fmt:fm[1],fmtk:fm[0]};
 if(P.kind==="live"){const c=CH[P.id];if(c)Object.assign(o,chO(c,true));o.cat=natCatName();if(wl){const L=liveList();o.list=(L.length?L:chans()).slice(0,1500).map(x=>chO(x))}}
 else{const it=ALL[P.id];if(it){o.t=it.t;o.kick=(it.type==="f"?"Film":"Série")+(it.y?" · "+it.y:"");o.ser=it.type==="s";o.c1=it.c[0];o.c2=it.c[1];o.d=(it.d||0)*60;
  if(o.ser){const e=curEp(),sn=(it.seasons||[])[P.ss-1];{const et=epTitle(e,it);o.sub=`Saison ${sn} · Épisode ${P.ep}`+(et?" · "+et:"")}const n=nextEp(it);o.next=n?`S${(it.seasons||[])[n.ss-1]} · E${n.ep}`:"";if(e&&e.dur)o.d=e.dur*60}}}
 return JSON.stringify(o)};
nativeApi.psrcs=function(){if(!P)return JSON.stringify({sources:[]});return JSON.stringify({t:P.kind==="live"?(CH[P.id]||{}).n:(ALL[P.id]||{}).t,sources:srcs(curKey()).map(v=>({id:v.id,q:v.q,pl:v.p.name,name:v.name||"",codec:v.codec||"",audio:(v.audio||[]).join(" | "),ok:compat(v),def:v.id===P.src}))})};
nativeApi.pact=function(a,v){if(!P)return JSON.stringify({none:true});
 switch(a){
  case "pp":P.playing=!P.playing;P.playing?Prisme.resume():Prisme.pause();break;
  case "seek":{const s=Math.max(0,+v||0);P.pos=s/1000;Prisme.seekTo(s);break}
  case "audio":P.audio=+v;Prisme.setAudio(+v);break;
  case "sub":P.sub=+v;Prisme.setSub(+v);break;
  case "fmt":S.set.fmt=v;save();Prisme.setFormat(v);break;
  case "src":{const vv=srcs(curKey()).find(x=>x.id===v);if(!vv)break;if(!compat(vv))return JSON.stringify({msg:"Source 4K non lisible sur ton Fire TV Stick (1080p max)"});
   S.srcSel[curKey()]=v;save();Object.assign(P,{src:v,audio:null,sub:null,err:0,aSync:null,started:false,retry:0,t0:Date.now()});Prisme.play(streamUrl(),P.kind==="vod"?Math.round(P.pos*1000):0,P.kind==="live");break}
  case "nextep":upnHide();act("p:nextep");break;
  case "upnx":P.upnX=1;upnHide();break;
  case "zap":{if(v==="1"||v==="-1"||v===1||v===-1)zap(+v);else if(CH[v]){Object.assign(P,{id:v,src:srcId("ch:"+v),err:0,audio:null,sub:null,started:false,retry:0,t0:Date.now()});S.lch=v;Prisme.play(streamUrl(),0,true)}P.started=false;P.t0=Date.now();break}
  case "fav":if(P.kind==="live"&&CH[P.id])toggleFav("ch:"+P.id,CH[P.id].n);break;
  case "restart":P.pos=0;Prisme.seekTo(0);break;
  case "stop":stopPlayer();S.stack=S.stack.filter(x=>x.t!=="player");return JSON.stringify({stopped:true});
 }
 return nativeApi.pinfo()};
nativeApi.chFav=function(id){const c=CH[id];if(!c)return "{}";toggleFav("ch:"+id,c.n);const f=isFav("ch:"+id);return JSON.stringify({fav:f,msg:(f?"Ajoutée aux favoris : ":"Retirée des favoris : ")+c.n})};
nativeApi.livePos=function(){return JSON.stringify({id:P&&P.kind==="live"?P.id:"",started:!!(P&&P.started)})};

/* Sorties récentes au cinéma (films) et séries en cours de diffusion, d'après TMDB, croisées avec le catalogue */
let NOWP={f:[],s:[],at:0};
async function loadNowPlaying(){
 if(!S.set.tmdbKey||Date.now()-NOWP.at<6*3600000&&NOWP.f.length)return;
 try{
  const get=async(path,pages)=>{const out=[];for(let p=1;p<=pages;p++){try{const r=await tmdb(path+(path.includes("?")?"&":"?")+"page="+p);(r&&r.results||[]).forEach(x=>out.push(x));if(!r||p>=(r.total_pages||1))break}catch(e){break}}return out};
  const [m,t]=[await get("movie/now_playing?region=FR",4),await get("tv/on_the_air",3)];
  const match=(list,arr,isF)=>{const byId={},byT={};list.forEach(i=>{if(i.tmdbId)byId[i.tmdbId]=i;const k=norm(i.t);(byT[k]=byT[k]||[]).push(i)});const seen=new Set(),out=[];
   arr.forEach(r=>{const y=+String(isF?r.release_date:r.first_air_date||"").slice(0,4)||0;let it=byId[String(r.id)];
    if(!it){const c=byT[norm(r.title||r.name||"")]||byT[norm(r.original_title||r.original_name||"")]||[];it=c.find(i=>!y||!i.y||Math.abs(i.y-y)<=1)}
    if(it&&!seen.has(it.id)){seen.add(it.id);out.push([it,String(isF?r.release_date:r.first_air_date||"")])}});
   return out.sort((a,b)=>b[1].localeCompare(a[1])).map(x=>x[0])};
  NOWP={f:match(films(),m,true),s:match(series(),t,false),at:Date.now()};
  LOG(`TMDB : ${NOWP.f.length} sorties cinéma récentes et ${NOWP.s.length} séries en diffusion trouvées dans tes playlists`);
  if(NAT.vis)Prisme.nativeEvent("home","")}catch(e){}}
setTimeout(loadNowPlaying,12000);setInterval(()=>loadNowPlaying(),6*3600000);

/* ========================= ÉTAPE 5 : Réglages natifs =========================
   Les pages de réglages existantes (mêmes réglages, mêmes actions) sont lues ici et décrites à l'interface native. */
function nsRows(sec){return [...sec.querySelectorAll(".it")].map(el=>{const sp=el.querySelectorAll(":scope>span"),a=sp[0],sm=a&&a.querySelector("small"),sub=sm?sm.textContent:"";
 let label=a?a.textContent:"";if(sm)label=label.slice(0,label.length-sub.length);
 const swe=el.querySelector(".sw"),inp=el.querySelector("input");let val=sp[1]?sp[1].textContent:"";if(inp)val=inp.value?(S.set.tmdbBuiltin?"clé intégrée":"enregistrée"):"non renseignée";
 return {fid:el.dataset.fid||"",act:el.dataset.act||"",l:label.trim(),s:sub.trim(),v:String(val).trim(),sw:swe?swe.classList.contains("on"):null,red:/ff6961/.test(a&&a.getAttribute("style")||""),log:el.classList.contains("lg")}})}
function nsParse(html){const tp=document.createElement("template");tp.innerHTML=html;const root=tp.content.firstElementChild;if(!root)return [];
 return [...root.querySelectorAll(":scope>section")].map(s=>{const h=s.querySelector("h3"),k=s.querySelector(".kick"),h2=s.querySelector("h2");return {t:h?h.textContent.trim():"",kick:k?k.textContent:"",h2:h2?h2.textContent:"",rows:nsRows(s)}})}
nativeApi.setPage=function(kind,id){
 if(kind==="plm"){const p=S.playlists.find(x=>x.id===id);if(!p)return JSON.stringify({back:true});const secs=nsParse(plmHtml(id)),first=secs.shift()||{rows:[]};
  return JSON.stringify({kind,kick:"RÉGLAGES · MES PLAYLISTS",title:p.name,left:first.rows,secs:secs.map(s=>({t:s.t,rows:s.rows}))})}
 if(kind==="diag"){if(Object.keys(DIAGA).length<=1)setTimeout(()=>{try{Prisme.nativeEvent("setpage","")}catch(e){}},4000);const secs=nsParse(diagHtml()),first=secs.shift()||{rows:[]};
  return JSON.stringify({kind,kick:"RÉGLAGES",title:"Diagnostic",sub:`${DEV.model||"navigateur"} · Android ${ANDROID[DEV.sdk]||DEV.sdk||""} · prisme ${APPV.name}`,
   left:first.rows.filter(r=>r.act),secs:[{t:"Comptes et catalogue",rows:first.rows.filter(r=>!r.act)},...secs.map(s=>({t:s.t,rows:s.rows}))]})}
 const secs=nsParse(settingsFull()).map(s=>{const m=s.t.match(/^(.*?)\s*(?:Xtream\s*)?\((\d+)\)$/);return {n:m?m[1].replace(/\s*Xtream$/,""):s.t,c:m?m[2]:"",t:s.t,rows:s.rows.filter(r=>r.act!=="diag")}});
 secs.push({n:"Diagnostic",c:"",t:"Diagnostic",rows:[{fid:"set-diag",act:"diag",l:"Ouvrir le Diagnostic",s:"Comptes, chargements des playlists, analyses et journal",v:"›",sw:null}]});
 return JSON.stringify({kind:"root",kick:"PRISME "+APPV.name,title:"Réglages",secs})};
nativeApi.setAct=function(kind,id,a){
 if(a.startsWith("plm:"))return JSON.stringify({nav:"plm",id:a.slice(4)});
 if(a==="diag")return JSON.stringify({nav:"diag"});
 /* saisie d'une playlist et mise à jour : ancienne interface, retour aux réglages natifs ensuite */
 if(a==="addpl"||a.startsWith("upd:")){NAT.vis=false;S.retNat=true;S.tab=a==="addpl"?"films":"settings";S.modal=null;S.stack=[{t:"home"},{t:"settings"}];render(null);act(a);return JSON.stringify({web:true})}
 const want=kind==="plm"?{t:"plm",id}:kind==="diag"?{t:"diag"}:{t:"settings"},t=topS();
 if(!(t.t===want.t&&t.id===want.id&&view.querySelector(`[data-act="${CSS.escape(a)}"]`))){S.tab="settings";S.modal=null;S.stack=want.t==="settings"?[{t:"home"},want]:[{t:"home"},{t:"settings"},want];render(null)}
 const el=view.querySelector(`[data-act="${CSS.escape(a)}"]`);if(el)setFocus(el,true);
 try{act(a)}catch(e){LOG("Réglage · "+e.message)}
 if(kind==="plm"&&!S.playlists.find(p=>p.id===id))return JSON.stringify({back:true});
 if(a==="set:legacy"&&S.set.legacy){NAT.vis=false;S.stack=[{t:"home"},{t:"settings"}];render("set-legacy");return JSON.stringify({web:true})}
 if(a.startsWith("hide:")){const [,pid,ty,k]=a.split(":"),pl=S.playlists.find(p=>p.id===pid),h=(pl.hidden||[]).includes(ty+":"+k),n=catCount(pl,ty,k);
  return JSON.stringify({patch:{act:a,sw:!h,s:`${n} ${({l:"chaînes",f:"films",s:"séries"})[ty]}${h?" · masquée":""}`}})}
 if(a==="diag:test")setTimeout(()=>{try{Prisme.nativeEvent("setpage","")}catch(e){}},2500);
 return nativeApi.setPage(kind,id)};
nativeApi.setLeave=function(kind){if(kind==="plm"&&(PLDIRTY||PLRELOAD.size)){PLDIRTY=false;clearTimeout(PLSAVE);save();setTimeout(plApply,30)}
 if(kind==="root"){S.stack=[{t:"home"}];S.modal=null}return ""};
