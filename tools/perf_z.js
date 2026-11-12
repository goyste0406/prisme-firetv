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
function epgIdx(){const n=nowMin(),k=Math.floor(n/10)+"|"+CHS.length+"|"+FILMS.length+"|"+SERIES.length+"|"+S.playlists.length;if(EPGI.k===k)return EPGI.m;const m=new Map(),want=new Set();for(const L of [FILMS,SERIES])for(const f of L){const w=tkey(f.t);if(w.length>=3)want.add(w)}
 CHS.forEach((c,ci)=>{let L;try{L=epg(c)}catch(e){return}for(let pi=0;pi<L.length;pi++){const p=L[pi];if(p.e<n-2880||p.s>n+1440)continue;const w=tkn(p.t);if(!want.has(w))continue;let a=m.get(w);if(!a)m.set(w,a=[]);a.push({c,p,ci,pi})}});
 EPGI.k=k;EPGI.m=m;return m}
fxTV=function(f){const k=f.id+"|"+Math.floor(nowMin()/10);if(FXS.tvk===k)return FXS.tv;const want=tkey(f.t),n=nowMin(),out=[];
 if(want.length>=3){const L=(epgIdx().get(want)||[]).slice().sort((a,b)=>a.ci-b.ci||a.pi-b.pi),done=new Set();
  for(const {c,p} of L){if(out.length>=3)break;if(done.has(c.id))continue;const live=p.s<=n&&p.e>n,past=p.e<=n;if(past&&!(typeof arDays==="function"&&arDays(c)))continue;done.add(c.id);
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
{const W=[()=>films(),()=>series(),()=>chans(),()=>S.playlists.forEach(p=>counts(p)),()=>epgIdx(),()=>{const f0=films()[0];if(f0){bInfo(f0);fxIDF()}},
  ...[FILMS,SERIES].flatMap(L=>Array.from({length:Math.ceil(L.length/4000)},(_,i)=>()=>{for(const it of L.slice(i*4000,(i+1)*4000))genreKeys(it)})),()=>{if(typeof forYou==="function")forYou()},()=>genreList("f"),()=>genreList("s")];let wi=0;
 setTimeout(function warm(){if(wi>=W.length)return;if(Date.now()-(window.__lastKey||0)<1500||S.loading||(typeof P!=="undefined"&&P))return setTimeout(warm,1000);try{W[wi]()}catch(e){}wi++;setTimeout(warm,60)},1500)}
/* genres d'un titre : les mêmes listes sont partagées (des dizaines de milliers de titres ont les mêmes genres) → moins de mémoire */
{const _g=genreKeys,IN=new Map();genreKeys=function(it){const r=GK[it.id];if(r)return r;const v=_g(it),k=v.join("|");let s=IN.get(k);if(!s){IN.set(k,v);s=v}GK[it.id]=s;return s}}
/* « bientôt » et « replay récent » : le guide de chaque chaîne est trié par heure, on va directement au bon moment
   (recherche par dichotomie) au lieu de relire tous les programmes de toutes les chaînes. Résultat identique. */
const isSortedS=L=>{for(let i=1;i<L.length;i++)if(L[i].s<L[i-1].s)return false;return true};
const firstAt=(L,t)=>{let lo=0,hi=L.length;while(lo<hi){const m=(lo+hi)>>1;if(L[m].s<t)lo=m+1;else hi=m}return lo};
lSoon0=function(g,win=90){const n=nowMin(),out=[];for(const c of lvis()){const L=epg(c);if(!isSortedS(L)){for(const p of L)if(p.s>n&&p.s<=n+win&&(!g||pgen(p)===g))out.push({c,p});continue}for(let i=firstAt(L,n+1e-9);i<L.length;i++){const p=L[i];if(p.s>n+win)break;if(p.s>n&&(!g||pgen(p)===g))out.push({c,p})}}return out.sort((a,b)=>a.p.s-b.p.s)};
{lPast=function(){return lmemo("past",()=>{const n=nowMin(),out=[];for(const c of lvis()){const d=arDays(c);if(!d)continue;const L=epg(c);if(!isSortedS(L)){for(const p of L)if(p.e<=n&&p.s>=n-d*1440&&p.t!=="Programme non communiqué")out.push({c,p});continue}
  for(let i=firstAt(L,n-d*1440);i<L.length;i++){const p=L[i];if(p.s>n)break;if(p.e<=n&&p.t!=="Programme non communiqué")out.push({c,p})}}return out.sort((a,b)=>b.p.e-a.p.e)}).slice()}}
