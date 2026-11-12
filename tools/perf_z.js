/* ===== Fluidité (2/2) : calculs lourds faits une fois, puis repris tant que rien n'a changé ===== */
/* nombre de chaînes / films / séries par fournisseur (réglages, chargement) : recalculé seulement si les données changent */
{const _c=counts;counts=function(pl){const k="cnt:"+pl.id;return RMEMO[k]||(RMEMO[k]=_c(pl))}}
/* TV en direct : replays récents et « ce soir », une fois par minute (comme « en direct » et « bientôt ») */
{const _t=hTonight;hTonight=function(){return lmemo("tonight",_t).slice()}}
/* « à la TV » (fiche film, accueil films) : un index des titres du guide, refait toutes les 10 minutes,
   au lieu de relire tout le guide de toutes les chaînes pour chaque film */
const tkn=t=>norm(t||"").replace(/[^a-z0-9]/g,"");
const TKM=new Map();const tkey=t=>{let r=TKM.get(t);if(r===undefined){r=tkn(t);if(TKM.size>80000)TKM.clear();TKM.set(t,r)}return r};
/* index des programmes du guide dont le titre est celui d'un film du catalogue (le reste du guide n'est pas gardé) */
const EPGI={k:"",m:null};
/* construit une fois par jour (le guide est en minutes depuis minuit), par petites tranches pendant les temps morts ;
   la fenêtre de temps (2 jours avant, 1 jour après) est appliquée au moment de la lecture */
const epgKey=()=>CHS.length+"|"+FILMS.length+"|"+SERIES.length+"|"+S.playlists.length+"|"+new Date().toDateString();
function epgStep(ms){const k=epgKey();if(EPGI.k!==k){EPGI.k=k;EPGI.b={m:new Map(),want:new Set(),wi:0,ci:0};EPGI.m=null}if(EPGI.m)return true;
 const B=EPGI.b,end=performance.now()+ms,NI=FILMS.length+SERIES.length;
 while(B.wi<NI){const f=B.wi<FILMS.length?FILMS[B.wi]:SERIES[B.wi-FILMS.length];B.wi++;const w=tkey(f.t);if(w.length>=3)B.want.add(w);if((B.wi&511)===0&&performance.now()>end)return false}
 while(B.ci<CHS.length){const ci=B.ci,c=CHS[ci];B.ci++;let L;try{L=epg(c)}catch(e){L=[]}for(let pi=0;pi<L.length;pi++){const p=L[pi],w=tkn(p.t);if(!B.want.has(w))continue;let a=B.m.get(w);if(!a)B.m.set(w,a=[]);a.push({c,p,ci,pi})}
  if((B.ci&63)===0&&performance.now()>end)return false}
 EPGI.m=B.m;EPGI.b=null;return true}
function epgIdx(){epgStep(1e9);return EPGI.m}
fxTV=function(f){const k=f.id+"|"+Math.floor(nowMin()/10);if(FXS.tvk===k)return FXS.tv;const want=tkey(f.t),n=nowMin(),out=[];
 if(want.length>=3){const L=(epgIdx().get(want)||[]).slice().sort((a,b)=>a.ci-b.ci||a.pi-b.pi),done=new Set();
  for(const {c,p} of L){if(out.length>=3)break;if(done.has(c.id)||p.e<n-2880||p.s>n+1440)continue;const live=p.s<=n&&p.e>n,past=p.e<=n;if(past&&!(typeof arDays==="function"&&arDays(c)))continue;done.add(c.id);
   out.push({c,p,live,past,t:live?"en direct":past?"en replay":(p.s<1440?"ce soir ":"demain ")+fmt(p.s)})}}
 FXS.tvk=k;return FXS.tv=out};
fhTV=function(){const k="tv|"+Math.floor(fhNow()/10)+"|"+FILMS.length;if(FH.cache[k])return FH.cache[k];const n=fhNow(),I=epgIdx(),av=new Map(chans().map((c,i)=>[c.id,i])),best=new Map();
 const idx=new Map();for(const f of fhFilms()){const w=tkey(f.t);if(w.length>=4)idx.set(w,f)}
 for(const [w,f] of idx){if(fhNo(f.id))continue;for(const x of I.get(w)||[]){const p=x.p;if(p.e<=n||p.s>24*60+120||!av.has(x.c.id))continue;const b=best.get(x.c.id);if(!b||x.pi<b.pi)best.set(x.c.id,{f,c:x.c,p,pi:x.pi})}}
 const out=[...best.values()].sort((a,b)=>av.get(a.c.id)-av.get(b.c.id)).slice(0,6).map(({f,c,p})=>{const live=p.s<=n;return {f,c,p,live,t:live?"en direct · depuis "+fmt(p.s):(p.s<24*60?"ce soir ":"cette nuit ")+fmt(p.s%1440)}});
 out.sort((a,b)=>(a.live?0:1)-(b.live?0:1)||a.p.s-b.p.s);return FH.cache[k]=out};
/* données TMDB d'un film mises en forme : une fois par film (refait si de nouvelles fiches arrivent) */
{const _t=tmOf,TM=new WeakMap();tmOf=function(f){const n=TMD.n+"|"+(f.tmd?1:0),c=TM.get(f);if(c&&c.n===n)return c.v;const v=_t(f);TM.set(f,{n,v});return v}}
/* nombre de sources d'un titre sans fabriquer toutes leurs fiches (réglages : « titres en plusieurs versions ») */
window.nsrc=key=>{if(!key.startsWith("ch:")&&ALL[key]&&typeof fxBlocked==="function"&&fxBlocked(ALL[key]))return 0;let n=0;
 for(const p of S.playlists){if(!p.on||!has(p,key))continue;if(REAL){const r=key.startsWith("ch:")?(CH[key.slice(3)]||{})._real:(ALL[key]||{})._real;if(r)for(const x of r.s)if(x[0]===p.id)n++}else n+=variants(p,key).length}return n};
/* fiche film : « Si tu hésites encore » compare le film à tout le catalogue (0,1 à 0,2 s sur 40 000 films).
   La fiche s'affiche tout de suite ; cette rangée, plus bas, se remplit juste après (avant qu'on ait pu descendre jusqu'à elle). */
const LZ={n:0};{const _x=xSimHtml;let lzT=0;xSimHtml=function(f){const mode=FXS.xmode||"mix",ck=f.id+"|"+mode+"|"+(FXS.duo||[PR.cur]).join("+")+"|"+FILMS.length+"|"+TMD.n;
 if(FXS.cache[ck]||FILMS.length<3000)return _x(f);clearTimeout(lzT);
 const fill=()=>{const t=topS();if(!t||t.t!=="detail"||t.id!==f.id)return;const h=_x(f),el=view.querySelector("#xsimlz");if(!el)return;
  if(!h){el.remove();return}const d=document.createElement("div");d.innerHTML=fxC(h);const sec=d.firstElementChild;el.replaceWith(sec);
  if(F&&!view.contains(F)){const e=sec.querySelector("[data-f]");if(e)setFocus(e,true)}};
 const tok=++LZ.n;lzT=setTimeout(()=>{if(FXS.duo)return fill();
  /* même calcul que crossPick, découpé en tranches de 8 ms pour que les touches restent instantanées pendant ce temps */
  const pid=PR.cur,p=PR.list[pid],T=taste(pid),L=liked(pid),W=SW[mode]||SW.mix,seen=new Set(p.seen),no=new Set(p.no),ab=new Set(fxHist(pid).filter(h=>h.done<.35).map(h=>h.id));
  const C=films().filter(c=>c.id!==f.id&&!seen.has(c.id)&&!no.has(c.id)&&!(ab.has(c.id)&&!S.prog[c.id])),A=[];let i=0;
  (function step(){if(tok!==LZ.n)return;const end=performance.now()+8;while(i<C.length&&performance.now()<end)for(let j=0;j<100&&i<C.length;j++,i++){const c=C[i],o=scoreOne(f,c,T,L,pid),gate=mode==="toi"?.6+.4*o.rel:.35+.65*o.rel;o.raw=Object.keys(W).reduce((s2,k)=>s2+W[k]*o.parts[k],0)*gate-o.pen;A.push(o)}
   if(i<C.length)return setTimeout(step,0);
   const all=A.sort((a,b)=>b.raw-a.raw).slice(0,80),out=[],pool=all.slice();while(pool.length&&out.length<10){let best=null,bv=-1e9;for(const o of pool){const red=out.length?Math.max(...out.map(x=>kwSim(x.c,o.c)+(x.c.dir&&x.c.dir===o.c.dir?.3:0))):0;const v=o.raw-.18*red;if(v>bv){bv=v;best=o}}out.push(best);pool.splice(pool.indexOf(best),1)}
   out.forEach(o=>o.pct=Math.max(35,Math.min(99,Math.round(40+o.raw*95))));FXS.cache[ck]=out.sort((a,b)=>b.raw-a.raw);fill()})()},30);
 return `<section data-anchor id="xsimlz"><div class="lh">${FXS.duo?"Pour vous deux":"Si tu hésites encore"}</div><div style="height:330px"></div></section>`}}
/* au repos après l'ouverture : on prépare ce qui sert partout (disponibilités, compteurs, index du guide) pour que le premier affichage soit immédiat */
/* une étape à la fois, seulement quand personne n'appuie sur la télécommande, et jamais pendant la lecture */
/* disponibilités et compteurs préparés par tranches de 10 ms (même résultat que films(), series(), chans(), counts()) */
const AVB={};function availStep(t,ms){const src=t==="f"?FILMS:t==="s"?SERIES:CHS;if(AVM[t]){AVB[t]=null;return true}
 let b=AVB[t];if(!b||b.sig!==DV.s||b.src!==src)b=AVB[t]={sig:DV.s,src,i:0,out:[]};const end=performance.now()+ms;
 while(b.i<src.length){const it=src[b.i++];if(avail(t==="c"?"ch:"+it.id:it.id))b.out.push(it);if((b.i&255)===0&&performance.now()>end)return false}
 if(b.sig===DV.s)AVM[t]=Object.freeze(b.out);AVB[t]=null;return true}
const CNB={};function countStep(pl,ms){const k="cnt:"+pl.id;if(RMEMO[k]){CNB[k]=null;return true}let b=CNB[k];if(!b||b.sig!==DV.s)b=CNB[k]={sig:DV.s,ph:0,i:0,r:{c:0,f:0,s:0}};const end=performance.now()+ms;
 const PH=[[CHS,"c",c=>"ch:"+c.id],[FILMS,"f",i=>i.id],[SERIES,"s",i=>i.id]];
 while(b.ph<3){const [L,f,kf]=PH[b.ph];while(b.i<L.length){if(has(pl,kf(L[b.i])))b.r[f]++;b.i++;if((b.i&255)===0&&performance.now()>end)return false}b.ph++;b.i=0}
 if(b.sig===DV.s)RMEMO[k]=b.r;CNB[k]=null;return true}
const WS=[];{const W=[()=>{if(!availStep("f",10))wi--},()=>{if(!availStep("s",10))wi--},()=>{if(!availStep("c",10))wi--},()=>{if(!S.playlists.every(p=>countStep(p,10)))wi--},()=>{if(!epgStep(10))wi--},()=>{const f0=films()[0];if(f0){bInfo(f0);fxIDF()}},
  ...[FILMS,SERIES].flatMap(L=>Array.from({length:Math.ceil(L.length/4000)},(_,i)=>()=>{for(const it of L.slice(i*4000,(i+1)*4000))genreKeys(it)})),()=>{if(typeof forYou==="function")forYou()},...[0,1,2].map(j=>()=>{const L=j===0?films():j===1?series():chans();const st=(WS[j]=WS[j]||0),end=performance.now()+10;let i=st;for(;i<L.length&&performance.now()<end;i++)nzw(L[i].t||L[i].n||"");WS[j]=i;if(i<L.length)wi--}),()=>genreList("f"),()=>genreList("s")];let wi=0;
 setTimeout(function warm(){if(wi>=W.length||window.SAFE)return;if(Date.now()-(window.__lastKey||0)<1500||S.loading||(typeof P!=="undefined"&&P))return setTimeout(warm,1000);DG("préparation au repos n°"+wi);try{W[wi]()}catch(e){}DGend();wi++;setTimeout(warm,60)},1500)}
/* genres d'un titre : les mêmes listes sont partagées (des dizaines de milliers de titres ont les mêmes genres) → moins de mémoire */
{const _g=genreKeys,IN=new Map();genreKeys=function(it){const r=GK[it.id];if(r)return r;const v=_g(it),k=v.join("|");let s=IN.get(k);if(!s){IN.set(k,v);s=v}GK[it.id]=s;return s}}
/* « bientôt » et « replay récent » : le guide de chaque chaîne est trié par heure, on va directement au bon moment
   (recherche par dichotomie) au lieu de relire tous les programmes de toutes les chaînes. Résultat identique. */
const isSortedS=L=>{for(let i=1;i<L.length;i++)if(L[i].s<L[i-1].s)return false;return true};
const firstAt=(L,t)=>{let lo=0,hi=L.length;while(lo<hi){const m=(lo+hi)>>1;if(L[m].s<t)lo=m+1;else hi=m}return lo};
lSoon0=function(g,win=90){const n=nowMin(),out=[];for(const c of lvis()){const L=epg(c);if(!isSortedS(L)){for(const p of L)if(p.s>n&&p.s<=n+win&&(!g||pgen(p)===g))out.push({c,p});continue}for(let i=firstAt(L,n+1e-9);i<L.length;i++){const p=L[i];if(p.s>n+win)break;if(p.s>n&&(!g||pgen(p)===g))out.push({c,p})}}return out.sort((a,b)=>a.p.s-b.p.s)};
{lPast=function(){return lmemo("past",()=>{const n=nowMin(),out=[];for(const c of lvis()){const d=arDays(c);if(!d)continue;const L=epg(c);if(!isSortedS(L)){for(const p of L)if(p.e<=n&&p.s>=n-d*1440&&p.t!=="Programme non communiqué")out.push({c,p});continue}
  for(let i=firstAt(L,n-d*1440);i<L.length;i++){const p=L[i];if(p.s>n)break;if(p.e<=n&&p.t!=="Programme non communiqué")out.push({c,p})}}return out.sort((a,b)=>b.p.e-a.p.e)}).slice()}}
/* réglages d'un fournisseur : 60 catégories par type au départ, 120 de plus quand la sélection approche de la fin (même page, même ordre) */
const PLMN={id:null,n:{}};
function plmCut(id,type,cats){if(PLMN.id!==id){PLMN.id=id;PLMN.n={}}const n=PLMN.n[type]||(PLMN.n[type]=60);PLMN.all=PLMN.all||{};PLMN.all[type]=cats.length;return cats.length>n?cats.slice(0,n):cats}
{const _k=key;key=function(k){const r=_k(k);const t=topS();if(t&&t.t==="plm"&&F&&F.dataset.fid&&F.dataset.fid.startsWith("hc-")){const type=F.dataset.fid[3],g=F.parentElement,rows=g?g.children:[],i=[...rows].indexOf(F);
  if(i>=0&&rows.length-i<15&&(PLMN.all[type]||0)>rows.length){PLMN.n[type]=rows.length+120;const sc=view.querySelector("#set"),y=sc?sc.scrollTop:0,fid=F.dataset.fid;render(fid);const s2=view.querySelector("#set");if(s2){s2.style.scrollBehavior="auto";s2.scrollTop=y;if(F)ensureVisible(F,true);requestAnimationFrame(()=>s2.style.scrollBehavior="")}}}return r}}
/* « Pour toi », « Parce que tu as aimé », « Si tu hésites » : chaque suggestion compare un film à tout le catalogue.
   Avec beaucoup de fiches TMDB (mots-clés), ce calcul pouvait figer Safari plusieurs secondes au démarrage.
   Gros catalogue : le calcul se fait maintenant par tranches de 8 ms, les rangées se remplissent dès qu'il est fini.
   Mêmes règles de score, même résultat ; petit catalogue : inchangé (calcul immédiat). */
const CPJ={q:[],run:false,last:{},sync:false};
function scoredAllAsync(f,mode,pid,cb){pid=pid||PR.cur;const p=PR.list[pid];if(!p)return cb([]);const T=taste(pid),L=liked(pid),W=SW[mode]||SW.mix,seen=new Set(p.seen),no=new Set(p.no),ab=new Set(fxHist(pid).filter(h=>h.done<.35).map(h=>h.id));
 const C=films().filter(c=>c.id!==f.id&&!seen.has(c.id)&&!no.has(c.id)&&!(ab.has(c.id)&&!S.prog[c.id])),A=[],K=Object.keys(W);let i=0;
 (function step(){const end=performance.now()+8;while(i<C.length&&performance.now()<end)for(let j=0;j<50&&i<C.length;j++,i++){const c=C[i],o=scoreOne(f,c,T,L,pid),gate=mode==="toi"?.6+.4*o.rel:.35+.65*o.rel;o.raw=K.reduce((s2,k)=>s2+W[k]*o.parts[k],0)*gate-o.pen;A.push(o)}
  if(i<C.length)return setTimeout(step,0);cb(A)})()}
let CPRT=0;function cpRerender(){clearTimeout(CPRT);CPRT=setTimeout(()=>{if(CPJ.run||CPJ.q.length)return;if(typeof FH!=="undefined")FH.cache={};if(!inApp()||(typeof P!=="undefined"&&P))return;const t=topS();if(!t||(t.t!=="home"&&t.t!=="detail"))return;render(F&&F.dataset&&F.dataset.fid)},60)}
{const _cp=crossPick;
 const ckOf=(f,mode)=>f.id+"|"+mode+"|"+(FXS.duo||[PR.cur]).join("+")+"|"+FILMS.length+"|"+TMD.n;
 function pump(){if(CPJ.run||!CPJ.q.length)return;CPJ.run=true;const j=CPJ.q.shift();const pids=FXS.duo?FXS.duo.slice():[PR.cur],res={};let k=0;
  DG("suggestions : calcul pour « "+(j.f.t||"")+" »");
  const next=()=>{if(k>=pids.length){const save=scoredAll;scoredAll=(f,m,pid)=>res[pid||PR.cur]||[];CPJ.sync=true;let out;try{out=_cp(j.f,j.mode)}catch(e){out=[]}finally{scoredAll=save;CPJ.sync=false}
    CPJ.last[j.f.id+"|"+j.mode]=out;CPJ.run=false;DGend();cpRerender();setTimeout(pump,0);return}
   const pid=pids[k++];scoredAllAsync(j.f,j.mode,pid,A=>{res[pid]=A;next()})};next()}
 crossPick=function(f,mode){const ck=ckOf(f,mode);if(FXS.cache[ck]||CPJ.sync||films().length<3000)return _cp(f,mode);
  if(!CPJ.q.some(j=>j.ck===ck))CPJ.q.push({ck,f,mode});setTimeout(pump,0);return CPJ.last[f.id+"|"+mode]||[]}}
