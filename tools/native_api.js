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
function natVer(ty){return [CATV,DIRTY,S.favs.length,Object.keys(S.prog).length,TREND.f.length,TREND.s.length,NAT.gv,ty].join("|")}

window.nativeApi={
 ver(ty){return natVer(ty)},
 home(ty){
  const list=ty==="f"?films():series();
  const ok=i=>i&&i.type===ty&&srcs(i.id).length;
  const cont=Object.keys(S.prog).reverse().map(k=>ALL[k]).filter(ok).slice(0,30);
  const fav=S.favs.map(k=>ALL[k]).filter(ok).slice(0,40);
  const recent=memo("nre"+ty,()=>list.map(i=>[i,added(i.id)]).filter(x=>x[1]).sort((a,b)=>a[1].d-b[1].d).slice(0,30).map(x=>x[0]));
  const trend=memo("ntr"+ty+TREND[ty].length,()=>[...list].sort((a,b)=>trendScore(b)-trendScore(a)).slice(0,10));
  const rows=[["cont","Continuer à regarder",cont,""],["fav","Ma liste",fav,""],["new","Derniers ajouts",recent,""],["top",ty==="f"?"Top 10 des films du moment":"Top 10 des séries du moment",trend,"rank"]]
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
  p.nat=true;p.t0=Date.now();
  NAT.vis=false;
  PQ.splice(0).forEach(([k])=>{if(QPEND[k]==="probe")delete QPEND[k]});
  S.stack.push({t:"player"});
  const busy=NATIVE&&!NAT.pre&&(PQRUN||Prisme.probeBusy());
  NAT.pre=null;
  startPlayer(p);render(null);
  const cv=curVar();
  if(busy)setTimeout(()=>{if(P===p&&!p.go)Prisme.nativeEvent("loading",JSON.stringify({msg:"Analyse du flux en cours, démarrage dans un instant…"}))},300);
  return JSON.stringify({ok:true,t:it.t,f:it.f,c1:it.c[0],c2:it.c[1],bd:tmS(it.bd,"w1280"),img:tmS(it.img,"w342"),q:cv&&qr(cv.q)>0&&cv.q!=="Auto"?cv.q:"",src:[cv?cv.p.name:"",cv?cv.tag:"",res].filter(Boolean).join(" · ")});
 },
 cancel(){if(P&&P.nat){stopPlayer();if(topS().t==="player")S.stack.pop();NAT.vis=true}return ""},
 preload(id,ss,ep){
  if(P||PQRUN||NAT.pre||(NATIVE&&Prisme.probeBusy()))return "";
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
   s:it.s||"",dir:it.dir||"",loading:!it.info&&!!it.loading,fav:isFav(id)};
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
   o.seasons=sn.map((n,i)=>({n:String(n),label:"Saison "+n,eps:((it.eps||{})[n]||[]).map(e=>({num:e.num,t:e.t,d:e.dur?e.dur+" min":"",img:tmS(e.img,"w300"),q:e.q||"",pr:le&&le.ss===i+1&&le.ep===e.num?(le.pct||0):0}))}));
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
  if([401,403,429,456,458,503,509,551].includes(code)&&(P.retry||0)<10){
   P.retry=(P.retry||0)+1;P.retryAt=Date.now()+3000;P.err=1;
   const m=`Connexion précédente en cours de fermeture… nouvel essai ${P.retry} sur 10`;
   if(P.nat)Prisme.nativeEvent("loading",JSON.stringify({msg:m,warn:true}));else toast(m);
   return true}
  if(!P.started){P.err=1;LOG("Erreur de lecture · "+String(st.error).slice(0,160));if(natSwitch("erreur"))return true;if(natFail(String(st.error).slice(0,120)))return true;P.err=0}
 }
 if(P&&!P.started&&!st.error&&P.nat&&!P.slowMsg&&Date.now()-(P.t0||0)>10000){P.slowMsg=1;Prisme.nativeEvent("loading",JSON.stringify({msg:"Le serveur met du temps à répondre…"}))}
 if(P&&!P.started&&!st.error&&P.nat&&Date.now()-(P.t0||0)>25000){P.t0=Date.now();P.slowMsg=0;if(natSwitch("délai dépassé"))return true;if(!P.slowFail){P.slowFail=1;return false}if(natFail("la vidéo ne démarre pas (pas de réponse du serveur)"))return true}
 return false}
