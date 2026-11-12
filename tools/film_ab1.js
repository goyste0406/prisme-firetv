/* ===================== Fiche film AB1 v2 · profils · recommandations TMDB ===================== */
const fxC=h=>h.replace(/class="([^"]*)"/g,(m,c)=>'class="'+c.split(/\s+/).map(x=>FXR[x]||x).join(" ")+'"');
const fxQ=c=>"."+(FXR[c]||c);
const fxD=m=>dur(Math.max(1,Math.round(m)));
const FXI={play:'<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 4.5v15l13-7.5z"/></svg>',film:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M8 4v16M16 4v16M3 9h5M3 15h5M16 9h5M16 15h5"/></svg>',
 plus:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',check:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5 10 17.5 19 7"/></svg>',
 back:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v4h4"/></svg>',moon:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/></svg>'};
const fxFont=f=>({serif:"f-serif",bebas:"f-bebas",black:"f-black"})[f.f]||"f-sans";
const fxPays=s=>{try{const D=new Intl.DisplayNames(["fr"],{type:"region"});return s.split(/,\s*/).slice(0,2).map(c=>D.of(c)).join(", ").toUpperCase()}catch(e){return s}};
const fxShort=f=>{const b=f.t.split(" :")[0];return FILMS.some(x=>x!==f&&x.t.split(" :")[0]===b)?f.t:b};

/* ---------- données TMDB (films.json, importé comme images.json) ---------- */
const TMD={m:{},names:{},sids:{},n:0};const TMIDX={};
const fxAge=a=>{a=String(a||"");return /^(U|TP|tous)/i.test(a)||a===""?"Tous publics":/^\d+$/.test(a)?a+"+":a};
function tmApply(){let n=0;for(const f of FILMS){const r=f._real;if(!r)continue;let id=r.tm||0;
  if(!id||!TMD.m[id])for(const s of r.s){if(s[4]&&TMD.sids[s[4]]){id=TMD.sids[s[4]];break}if(TMD.names[s[1]]){id=TMD.names[s[1]];break}}
  const d=id&&TMD.m[id];if(!d)continue;n++;f.tm=+id;f.tmd=d;TMIDX[id]=f;if(d.t)f.t=d.t;if(d.d)f.d=d.d;if(d.g&&d.g.length)f.g=d.g.slice(0,3);if(d.ov)f.s=d.ov;if(d.dir)f.dir=d.dir;if(d.y)f.y=d.y;
  if(d.va){f.imdb=+(+d.va).toFixed(1);f.tmdb=Math.round(d.va*10)}if(d.age)f.age=fxAge(d.age);if(d.po)f.po=d.po;if(d.bd)f.bd=d.bd;
  if(d.cast&&d.cast.length)f.cast=(d.cast||[]).map(([nm,ch])=>{const aid="ra"+(hash(nm)>>>0).toString(36);A[aid]=nm;(CRED[aid]=CRED[aid]||[]).some(x=>x[0]===f.id)||CRED[aid].push([f.id,ch||""]);return [aid,ch||""]})}
 /* même film TMDB proposé sous plusieurs noms : une seule fiche avec toutes ses versions */
 const by={};for(const f of FILMS.slice()){if(!f.tm)continue;const k=by[f.tm];if(!k){by[f.tm]=f;continue}
  for(const s2 of f._real.s)if(!k._real.s.some(x=>x[0]===s2[0]&&x[1]===s2[1]))k._real.s.push(s2);(f._real.c||[]).forEach(c=>{if(!k._real.c.includes(c))k._real.c.push(c)});
  if(S.prog[f.id]&&!S.prog[k.id])S.prog[k.id]=S.prog[f.id];FILMS.splice(FILMS.indexOf(f),1);ALL[f.id]=k}
 TMD.n=n;return n}
async function fxImportFilms(files,say){const out=[];for(const f of files){say(`Lecture de ${f.name}…`);let d=null;try{d=JSON.parse((await f.text()).replace(/^﻿/,""))}catch(e){}
  if(!d||typeof d!=="object"||!d.m)throw new Error(`${f.name} n'est pas un fichier de fiches films prisme`);out.push(d)}
 let list=[];try{list=(await idbGet("films"))||[]}catch(e){}list=list.concat(out).slice(-4);await idbSet("films",list);return out.reduce((a,d)=>a+Object.keys(d.m).length,0)}
if(typeof REAL!=="undefined"&&REAL)idbGet("films").then(list=>{if(!list||!list.length)return;for(const d of list){Object.assign(TMD.m,d.m);Object.assign(TMD.names,d.names||{});Object.assign(TMD.sids,d.sids||{});TMD.co=Object.assign(TMD.co||{},d.co||{});if(d.tr)TMD.tr=d.tr;if(d.trp)TMD.trp=d.trp;if(d.soon)TMD.soon=d.soon;if(d.pop)TMD.pop=d.pop}
 const n=tmApply();const st=$("#rst");if(st)st.textContent+=` · ${n} fiches films TMDB`;if(inApp()&&!S.loading)render(F&&F.dataset.fid)}).catch(()=>{});

/* ---------- profils (toute l'appli) ---------- */
const PCOL=["#f59e0b","#ec4899","#64748b","#22c55e","#3b82f6","#a855f7","#ef4444","#14b8a6"],PEMO=[null,"🎬","🍿","🚀","⚽","🎮","🌙","🐱"],AGES=[null,16,12,10,0];
const ageLbl=a=>a==null?"Aucune":a===0?"Tous publics":a+" ans max";
let PR=null;try{PR=JSON.parse(localStorage.getItem("prisme-profiles")||"null")}catch(e){}
if(!PR||!PR.list||!Object.keys(PR.list).length)PR={cur:"p1",ask:true,list:{p1:{n:"Steven",c:PCOL[0],emo:null,bed:23*60,lang:"auto",max:null,pref:{},hist:[],fb:{},seen:[],no:[],split:{},d:null}}};
if(!PR.list[PR.cur])PR.cur=Object.keys(PR.list)[0];
function prSave(){try{localStorage.setItem("prisme-profiles",JSON.stringify(PR))}catch(e){}}
const ME=()=>PR.list[PR.cur];
const FXS={duo:null,ready:null,cache:{}};
function prSnap(){const p=ME();p.d={favs:S.favs,prog:S.prog,seasons:S.seasons,srcSel:S.srcSel,lh:LS.hist,lg:LS.gw,lx:LS.hidden}}
function prSwitch(id){if(!PR.list[id])return;prSnap();PR.cur=id;const d=ME().d||{favs:[],prog:{},seasons:{},srcSel:{},lh:[],lg:{},lx:[]};
 S.favs=d.favs||[];S.prog=d.prog||{};S.seasons=d.seasons||{};S.srcSel=d.srcSel||{};LS.hist=d.lh||[];LS.gw=d.lg||{};LS.hidden=d.lx||[];FXS.cache={};save();lsave();prSave()}
const pav=(id,cls="")=>{const p=PR.list[id];return `<i class="pav ${cls}" style="--c:${p.c}">${p.emo||esc((p.n||"?")[0])}</i>`};
const fxAgeOf=f=>{const m=String(f.age||"").match(/\d+/);return m?+m[0]:0};
const fxMax=()=>{const L=(FXS.duo||[PR.cur]).map(id=>PR.list[id]&&PR.list[id].max).filter(x=>x!=null);return L.length?Math.min(...L):null};
const fxBlocked=f=>{const m=fxMax();return !!f&&f.type==="f"&&m!=null&&fxAgeOf(f)>m};
{const _s=srcs;srcs=function(key){const L=_s(key);if(L.length&&!key.startsWith("ch:")&&fxBlocked(ALL[key]))return [];return L}}
/* langue préférée (apprise ou réglée) */
/* langue d'une version : VFF (doublage France), VFQ (doublage Québec), VFI (international), VF (français sans précision), VOSTFR, MULTI */
const frOf=n=>/\bvfq\b|\bvq\b|qu[eé]b[eé]c|\bfr-?ca\b|canadien/i.test(n)?"VFQ":/\bvff\b|truefrench|\bfr-?fr\b/i.test(n)?"VFF":/\bvfi\b/i.test(n)?"VFI":"VF";
const tagOf=n=>/vostf?r?\b|\bvost\b|sous-?titr/i.test(n)?"VOSTFR":/multi/i.test(n)?"MULTI":frOf(n);
const fxTag=v=>v.tag||tagOf(v.name||"");
const fxFr=v=>v.fr||(fxTag(v)==="MULTI"?frOf(v.name||""):["VFF","VFQ","VFI","VF"].includes(fxTag(v))?fxTag(v):null);
const tagLbl=v=>{const t=fxTag(v),fr=fxFr(v);return t==="MULTI"&&fr&&fr!=="VF"?"MULTI · "+fr:t};
const FRL={VFF:"Français (France)",VFQ:"Français (Québec)",VFI:"Français (international)",VF:"Français"};
function fxPrefLang(pid){const p=PR.list[pid||PR.cur];if(p.lang&&p.lang!=="auto")return p.lang;const e=Object.entries(p.pref||{}).sort((a,b)=>b[1]-a[1]);return e.length&&e[0][1]>=2?e[0][0]:null}
/* préférence VF = n'importe quel doublage français, dans cet ordre : VFF, VF, VFI, VFQ ; VFF ou VFQ demandés = celui-là d'abord */
const FRORD={VF:["VFF","VF","VFI","VFQ"],VFF:["VFF","VF","VFI","VFQ"],VFQ:["VFQ","VF","VFF","VFI"]};
function fxPrefSrc(key){const pl=fxPrefLang();if(!pl)return null;const L=srcs(key).filter(compat);
 if(FRORD[pl]){for(const t of FRORD[pl]){const v=L.find(x=>fxFr(x)===t&&fxTag(x)!=="MULTI")||L.find(x=>fxFr(x)===t);if(v)return v}return L.find(x=>fxTag(x)==="MULTI")||null}
 return L.find(x=>fxTag(x)===pl)||L.find(x=>fxTag(x)==="MULTI")||null}
{const _p=pickSrc;pickSrc=function(key){if(!key.startsWith("ch:")&&!S.srcSel[key]){const v=fxPrefSrc(key);if(v)return v}return _p(key)}}
const fxAuto=f=>!S.srcSel[f.id]&&new Set(srcs(f.id).map(fxTag)).size>1&&!!fxPrefSrc(f.id);
function fxLearn(key,vid){const L=srcs(key);if(new Set(L.map(fxTag)).size<2)return;const v=L.find(x=>x.id===vid);if(!v)return;const p=ME(),before=fxPrefLang();p.pref=p.pref||{};const t=fxTag(v);
 for(const k in p.pref)if(k!==t)p.pref[k]*=.5;p.pref[t]=(p.pref[t]||0)+1;prSave();const after=fxPrefLang();if(after&&after!==before)setTimeout(()=>toast(`✨ prisme retient : ${p.n} préfère la ${after}`),300)}

/* ---------- données utiles à la fiche ---------- */
const STOP=new Set(["film","movie","based on novel or book","duringcreditsstinger","aftercreditsstinger","woman director","sequel","remake"]);
function tmOf(f){if(f.tmd){const d=f.tmd;return {kw:(d.kw||[]).filter(k=>!STOP.has(k)),rec:(d.rec||[]).map(id=>TMIDX[id]).filter(Boolean),w:d.w,mu:d.mu,ph:d.ph,col:d.col,vc:d.vc||1500,wp:d.wp||{},yt:d.yt,ytl:d.ytl||"",post:(d.kw||[]).some(k=>/creditsstinger/.test(k))}}
 return {kw:[...new Set([...f.g.map(g=>g.toLowerCase()),...(f.cat||[]).filter(c=>!["new","fr","top","trend","4k","nolan"].includes(c)).map(c=>c.toLowerCase())])],rec:[],w:"",mu:"",ph:"",col:null,vc:1500,wp:null,yt:"",post:hash(f.id)%5===0}}
function fxIDF(){const key=FILMS.length+"#"+TMD.n;if(FXS.idfk===key)return FXS.idf;const df={},L=films();L.forEach(f=>new Set(tmOf(f).kw).forEach(k=>df[k]=(df[k]||0)+1));const I={};for(const k in df)I[k]=Math.log(1+L.length/df[k]);FXS.idf=I;FXS.idfk=key;return I}
const kwSim=(a,b)=>{const I=fxIDF(),A1=tmOf(a).kw,B1=tmOf(b).kw,u=new Set([...A1,...B1]);let sh=0,un=0;u.forEach(k=>{const w=I[k]||1;un+=w;if(A1.includes(k)&&B1.includes(k))sh+=w});return un?sh/un:0};
function fxHist(pid){const p=PR.list[pid];return (p.hist||[]).filter(h=>ALL[h.id])}
function taste(pid){pid=pid||PR.cur;const p=PR.list[pid],g={},d={},a={},kw={},neg={},negk={},crew={};let tot=0;const I=fxIDF();
 const items=fxHist(pid).map(h=>({id:h.id,w:p.fb[h.id]===1?1.6:p.fb[h.id]===-1?-1.2:(h.done>=.85?1:h.done>=.35?.5:-.6)*(Date.now()-h.at<14*864e5?1.2:1)}));
 Object.keys(p.fb||{}).forEach(id=>{if(ALL[id]&&!items.some(x=>x.id===id))items.push({id,w:p.fb[id]===1?1.6:-1.2})});
 for(const h of items){const f=ALL[h.id],t=tmOf(f),w=h.w;if(w>0){tot+=w;f.g.forEach(x=>g[x]=(g[x]||0)+w);if(f.dir)d[f.dir]=(d[f.dir]||0)+w;f.cast.forEach(c=>a[c[0]]=(a[c[0]]||0)+w);t.kw.forEach(k=>kw[k]=(kw[k]||0)+w*(I[k]||1));[t.mu,t.ph].forEach(c=>c&&(crew[c]=(crew[c]||0)+w))}
  else{f.g.forEach(x=>neg[x]=(neg[x]||0)-w);t.kw.forEach(k=>negk[k]=(negk[k]||0)-w)}}
 const gp={};for(const k in g)gp[k]=g[k]/tot;return {g:gp,d,a,kw,neg,negk,crew,tot,items}}
const liked=pid=>taste(pid).items.filter(x=>x.w>=1).map(x=>x.id);
const SW={mix:{co:.30,kw:.25,crew:.15,prof:.15,qual:.10,fresh:.05},film:{co:.35,kw:.35,crew:.20,prof:0,qual:.10,fresh:0},toi:{co:.20,kw:.10,crew:.10,prof:.45,qual:.15,fresh:0}};
const SL={co:"Recommandé par TMDB",kw:"Thèmes communs",crew:"Équipe en commun",prof:"Tes goûts",qual:"Qualité",fresh:"Récence"};
const SMODES=[["mix","Le meilleur mix"],["film","Proche de ce film"],["toi","Selon tes goûts"]];
function scoreOne(f,c,T,L,pid){const p=PR.list[pid||PR.cur],t=tmOf(c),tf=tmOf(f),why=[];
 const inF=tf.rec.includes(c),byLiked=L.filter(id=>id!==c.id&&id!==f.id&&tmOf(ALL[id]).rec.includes(c));
 const co=Math.min(1,inF?.7+.15*byLiked.length:.15*Math.min(2,byLiked.length));
 if(co>0)why.push({c:"co",w:co,t:`Les fans de ${fxShort(inF?f:ALL[byLiked[0]])} l'adorent`});
 const kw=kwSim(f,c),I=fxIDF(),shk=tf.kw.filter(k=>t.kw.includes(k)).sort((x,y)=>(I[y]||0)-(I[x]||0));if(shk.length)why.push({c:"kw",w:kw*1.4,t:`Thèmes communs : ${shk.slice(0,2).join(", ")}`});
 let crew=0;const cw=[];if(c.dir&&c.dir===f.dir){crew+=.5;cw.push(`Même réalisateur (${c.dir.split(",")[0]})`)}if(t.w&&t.w===tf.w){crew+=.2;cw.push(`Même scénariste (${t.w})`)}if(t.mu&&t.mu===tf.mu){crew+=.15;cw.push(`Même compositeur (${t.mu})`)}if(t.ph&&t.ph===tf.ph){crew+=.15;cw.push(`Même directeur photo (${t.ph})`)}
 const sc=c.cast.filter(x=>f.cast.some(y=>y[0]===x[0]));crew+=.1*sc.length;if(sc.length)cw.push(`Avec ${A[sc[0][0]]}`);crew=Math.min(1,crew);if(cw.length)why.push({c:"crew",w:crew,t:cw[0]});
 let prof=0;const gA=c.g.reduce((s2,x)=>s2+(T.g[x]||0),0);prof+=Math.min(1,gA)*.35;const kA=t.kw.reduce((s2,k)=>s2+(T.kw[k]||0),0),kMax=Math.max(1,...Object.values(T.kw));prof+=Math.min(1,kA/kMax/1.5)*.3;
 if(c.dir&&T.d[c.dir])prof+=.15;if([t.mu,t.ph].some(x=>x&&T.crew[x]))prof+=.1;if(c.cast.some(x=>T.a[x[0]]))prof+=.1;prof=Math.min(1,prof);
 const likedSame=L.find(id=>id!==c.id&&ALL[id].dir&&ALL[id].dir===c.dir),thumb=Object.keys(p.fb||{}).find(id=>p.fb[id]===1&&ALL[id]&&(ALL[id].dir===c.dir||kwSim(ALL[id],c)>.25));
 if(thumb)why.push({c:"prof",w:prof+.3,t:`Tu as aimé 👍 ${fxShort(ALL[thumb])}`});else if(likedSame)why.push({c:"prof",w:prof+.1,t:`Du réalisateur de ${fxShort(ALL[likedSame])}`});
 else{const tk=t.kw.filter(k=>T.kw[k]).sort((x,y)=>T.kw[y]-T.kw[x])[0];if(tk)why.push({c:"prof",w:prof,t:`Un thème que tu aimes : ${tk}`})}
 const qual=Math.max(0,Math.min(1,((c.imdb*10*t.vc+68*1500)/(t.vc+1500)/10-6)/3)),fresh=Math.max(0,Math.min(1,(c.y-1990)/36));
 let pen=0;const nk=t.kw.filter(k=>T.negk[k]&&!T.kw[k]);if(nk.length){pen+=.08*Math.min(2,nk.length);why.push({c:"neg",w:-1,t:`Thème que tu abandonnes souvent : ${nk[0]}`})}if(c.g.some(x=>T.neg[x]&&!(T.g[x]>.25)))pen+=.06;
 if(S.prog[c.id])why.unshift({c:"prof",w:9,t:`Commencé · reste ${fxD(c.d*(1-S.prog[c.id]))}`});
 const gj=c.g.filter(x=>f.g.includes(x)).length/new Set([...c.g,...f.g]).size,kwp=Math.min(1,.7*Math.min(1,kw*1.6)+.3*gj),rel=Math.max(inF?1:0,kwp,crew);
 return {c,parts:{co,kw:kwp,crew,prof,qual,fresh},pen,rel,why:why.sort((x,y)=>y.w-x.w)}}
function scoredAll(f,mode,pid){pid=pid||PR.cur;const p=PR.list[pid],T=taste(pid),L=liked(pid),W=SW[mode]||SW.mix,seen=new Set(p.seen),no=new Set(p.no),ab=new Set(fxHist(pid).filter(h=>h.done<.35).map(h=>h.id));
 return films().filter(c=>c.id!==f.id&&!seen.has(c.id)&&!no.has(c.id)&&!(ab.has(c.id)&&!S.prog[c.id])).map(c=>{const o=scoreOne(f,c,T,L,pid);const gate=mode==="toi"?.6+.4*o.rel:.35+.65*o.rel;o.raw=Object.keys(W).reduce((s2,k)=>s2+W[k]*o.parts[k],0)*gate-o.pen;return o})}
function duoAll(f,mode){const [a,b]=FXS.duo,A1=scoredAll(f,mode,a),B1=scoredAll(f,mode,b),mb={};B1.forEach(o=>mb[o.c.id]=o);const Ta=taste(a),Tb=taste(b);
 return A1.filter(o=>mb[o.c.id]).map(o=>{const q=mb[o.c.id],pa=o.parts.prof,pb=q.parts.prof,raw=(o.raw+q.raw)/2-Math.abs(o.raw-q.raw)*.35,why=[];const cg=o.c.g.find(g=>(Ta.g[g]||0)>.15&&(Tb.g[g]||0)>.15);
  if(pa>.3&&pb>.3)why.push({c:"prof",w:2,t:`Vous aimez tous les deux${cg?" : "+cg.toLowerCase():""}`});else if(Ta.tot&&Tb.tot)why.push({c:"prof",w:1.5,t:`Plutôt pour ${PR.list[pa>pb?a:b].n}`});
  return {...o,raw,pA:Math.round(50+pa*49),pB:Math.round(50+pb*49),why:[...why,...o.why.filter(x=>x.c!=="prof")]}})}
function crossPick(f,mode){const ck=f.id+"|"+mode+"|"+(FXS.duo||[PR.cur]).join("+")+"|"+FILMS.length+"|"+TMD.n;if(FXS.cache[ck])return FXS.cache[ck];
 const all=(FXS.duo?duoAll(f,mode):scoredAll(f,mode)).sort((a,b)=>b.raw-a.raw).slice(0,80);
 const out=[],pool=all.slice();while(pool.length&&out.length<10){let best=null,bv=-1e9;for(const o of pool){const red=out.length?Math.max(...out.map(x=>kwSim(x.c,o.c)+(x.c.dir&&x.c.dir===o.c.dir?.3:0))):0;const v=o.raw-.18*red;if(v>bv){bv=v;best=o}}out.push(best);pool.splice(pool.indexOf(best),1)}
 out.forEach(o=>o.pct=Math.max(35,Math.min(99,Math.round(40+o.raw*95))));return FXS.cache[ck]=out.sort((a,b)=>b.raw-a.raw)}
const outside=f=>f.tmd?(f.tmd.rec||[]).filter(id=>!TMIDX[id]||!srcs(TMIDX[id].id).length).length:0;
function profFit(f,pid){const T=taste(pid);return T.tot?Math.round(50+scoreOne(f,f,T,liked(pid),pid).parts.prof*49):null}

/* ---------- soirée, TV, streaming ---------- */
function bInfo(f){const n=nowMin(),pr=S.prog[f.id]||0,end=n+f.d*(1-pr),bb=FXS.duo?Math.min(...FXS.duo.map(id=>PR.list[id].bed)):ME().bed,bed=n<300?bb-1440:bb,late=end-bed;
 const note=(f.imdb*10+f.tmdb)/2,fit=FXS.duo?null:profFit(f),sc=Math.min(99,Math.round(fit==null?note:.55*note+.45*fit));
 const why=[],p=ME(),seen=new Set(p.seen),tm=tmOf(f);
 const mate=tm.col&&films().find(x=>x.id!==f.id&&x.tmd&&x.tmd.col&&x.tmd.col[0]===tm.col[0]&&seen.has(x.id));if(mate)why.push(["🧩",`Suite de ${esc(fxShort(mate))}`]);
 const ca=f.cast.find(c=>(CRED[c[0]]||[]).some(([id])=>id!==f.id&&seen.has(id)));if(ca)why.push(["⭐",`Avec ${esc(A[ca[0]])}`]);
 const T=taste();const tg=f.g.find(g=>(T.g[g]||0)>.3);if(tg)why.push(["🚀","Ton genre préféré"]);
 if(f.imdb>=7.5)why.push(["🏆",`★ ${f.imdb} · très bien noté`]);
 return {n,end,bed,late,sc,why,fit}}
function planHtml(f){const b=bInfo(f),t0=Math.min(b.n,b.bed)-15,t1=Math.max(b.end,b.bed)+30,X=m=>+((m-t0)/(t1-t0)*100).toFixed(1);
 const lb=(m,txt,c="")=>{const x=X(m);return `<span class="lbl ${c} ${x<8?"l0":x>92?"l1":""}" style="left:${x}%">${txt}</span>`};
 return `<div class="plan"><div class="k">TA SOIRÉE</div><div class="tl"><div class="ax"></div><div class="fb" style="left:${X(b.n)}%;width:${(X(b.end)-X(b.n)).toFixed(1)}%"></div><div class="bed" style="left:${X(b.bed)}%"></div>${lb(b.n,"maintenant")}${lb(b.end,"fin "+fmt(b.end))}${Math.abs(X(b.bed)-X(b.n))>14&&Math.abs(X(b.bed)-X(b.end))>14?lb(b.bed,"☾ "+fmt(b.bed),"bedl"):""}</div><div class="msg">${planMsg(f)}</div></div>`}
function planMsg(f){const b=bInfo(f),sp=ME().split[f.id];if(sp!=null&&S.prog[f.id])return `Partie 1 vue · <b>partie 2 : ${fxD(f.d*(1-S.prog[f.id]))}</b>`;
 return b.late>10?`<b>Fin à ${fmt(b.end)}</b> · ${fxD(b.late)} après ton coucher`:b.late>-30?`<b>Fin à ${fmt(b.end)}</b> · juste avant ton coucher`:`<b>Fin à ${fmt(b.end)}</b> · il te restera ${fxD(-b.late)}`}
const needSplit=f=>bInfo(f).late>10;
function fxTV(f){const k=f.id+"|"+Math.floor(nowMin()/10);if(FXS.tvk===k)return FXS.tv;const want=norm(f.t).replace(/[^a-z0-9]/g,""),n=nowMin(),out=[];
 if(want.length>=3)for(const c of CHS){if(out.length>=3)break;let L;try{L=epg(c)}catch(e){continue}for(const p of L){if(p.e<n-2880||p.s>n+1440)continue;if(norm(p.t||"").replace(/[^a-z0-9]/g,"")!==want)continue;
   const live=p.s<=n&&p.e>n,past=p.e<=n;if(past&&!(typeof arDays==="function"&&arDays(c)))continue;out.push({c,p,live,past,t:live?"en direct":past?"en replay":(p.s<1440?"ce soir ":"demain ")+fmt(p.s)});break}}
 FXS.tvk=k;return FXS.tv=out}
const SVC_DEMO=["Netflix","Prime Video","Canal+","Max","Disney+","Apple TV","Rakuten TV","france.tv","M6+","TF1+"];
function streams(f){const t=tmOf(f),out=[];if(t.wp){for(const [k,ty] of [["f","abo"],["g","gratuit"],["r","loc"],["b","achat"]])for(const n of t.wp[k]||[])if(!out.some(x=>x.n===n&&x.t===ty))out.push({n,t:ty});}
 else if(!REAL){const h=hash(f.id);out.push({n:SVC_DEMO[h%6],t:"abo"});if(h%3===0)out.push({n:SVC_DEMO[7+h%3],t:"gratuit"});out.push({n:"Apple TV",t:"loc"},{n:"Apple TV",t:"achat"})}
 return out.map((x,i)=>({...x,i}))}
const TYP={abo:"Inclus dans l'abonnement",gratuit:"Gratuit",loc:"Location",achat:"Achat"};
const svIni=n=>n.replace(/[^A-Za-z0-9+ .]/g,"").split(/[ .]/).filter(Boolean).map(w=>w[0]).join("").slice(0,2).toUpperCase();
const svTile=(x,cls="")=>{const lg=(window.SVLG||{})[x.n];return lg?`<i class="svt img ${cls}" style="--h:${hash(x.n)%360}"><img src="${lg}" alt="${esc(x.n)}"></i>`:`<i class="svt ${cls}" style="--h:${hash(x.n)%360}">${esc(svIni(x.n))}</i>`};
function fxQual(f){const v=pickSrc(f.id);if(!v)return "";return [v.fx?(v.q==="4K"?"4K"+(v.hdr?" "+(v.hdr==="DV"?"Dolby Vision":v.hdr):""):v.q+(v.hdr?" "+v.hdr:"")):v.q==="4K"?"4K HDR":v.q,(v.audio||[])[0]&&/atmos/i.test(v.audio[0])?"Atmos":(v.audio||[])[0]&&/5\.1/.test(v.audio[0])?"5.1":""].filter(Boolean).join(" · ")}

/* ---------- fiche ---------- */
const fxArt=(f,cls="")=>f.bd?`<div class="art img ${cls}" style="background-image:url(${f.bd}),${f.po?`url(${f.po}),`:""}linear-gradient(160deg,${f.c[0]},${f.c[1]})"></div>`:f.po?`<div class="art img blur ${cls}" style="background-image:url(${f.po}),linear-gradient(160deg,${f.c[0]},${f.c[1]})"></div>`:`<div class="art ${cls}" style="--a:${f.c[0]};--b:${f.c[1]}"><i></i><i></i><i></i></div>`;
const fxPst=(f,fid,act,row,extra="")=>`<div class="pst ${fxFont(f)} ${f.po?"img":""}" style="--a:${f.c[0]};--b:${f.c[1]};${f.po?`background-image:url(${f.po}),linear-gradient(160deg,${f.c[0]},${f.c[1]})`:""}" data-f data-fid="${fid}" data-act="${act}" ${row?`data-row="${row}"`:""} ${extra}>${ME().seen.includes(f.id)?'<span class="seen">✓ Vu</span>':""}<div class="pt">${esc(f.t)}</div><div class="py">${f.y}</div>${S.prog[f.id]?`<div class="bar"><b style="width:${S.prog[f.id]*100}%"></b></div>`:""}</div>`;
function titleSize(f){const n=f.t.length,k=f.f==="bebas"?1:f.f==="serif"?.78:.72;return Math.round((n<=10?104:n<=16?92:n<=24?76:n<=34?62:52)*k)}
function whoChip(){return `<div class="who glass" data-f data-fid="w-who" data-act="fxwho" data-row="who" data-col="0">${FXS.duo?FXS.duo.map(id=>pav(id)).join(""):pav(PR.cur)}<span>${FXS.duo?FXS.duo.map(id=>esc(PR.list[id].n)).join(" + "):esc(ME().n)}</span><small>▾</small></div>`}
function scoreHtml(f){const b=bInfo(f);
 if(FXS.duo)return `<div class="scorebox"><div class="ring" style="--p:${b.sc}"><b>${b.sc}</b></div><div class="sd"><b>Pour vous deux</b><div class="duo">${FXS.duo.map(id=>`<span>${pav(id,"sm")}${esc(PR.list[id].n)} <b>${profFit(f,id)!=null?profFit(f,id)+" %":"à découvrir"}</b></span>`).join("")}</div></div></div>`;
 return `<div class="scorebox"><div class="ring" style="--p:${b.sc}"><b>${b.sc}</b></div><div class="sd"><b>Score prisme</b><br>Note ${f.imdb} · TMDB ${f.tmdb} %<br>${b.fit==null?"Tes goûts : à découvrir":"Tes goûts "+b.fit+" %"}</div></div>`}
function alsoLine(f){const tv=fxTV(f),L=streams(f),inc=L.filter(x=>x.t==="abo"||x.t==="gratuit").map(x=>x.n),loc=L.some(x=>x.t==="loc");
 const parts=[...tv.slice(0,1).map(x=>`${x.c.n} ${x.t}`),...inc.slice(0,2),...(loc?["location"]:[])];
 return parts.length?`<div class="also" data-f data-fid="w-also" data-act="fxwhere" data-row="wal"><span class="kk">AUSSI</span><span class="t">${esc(parts.join(" · "))}</span><span class="go">›</span></div>`:""}
function playLbl(f){return ME().split[f.id]!=null&&S.prog[f.id]?"Partie 2":S.prog[f.id]?"Reprendre":"Lecture"}
function playSub(f){const sp=ME().split[f.id]!=null&&S.prog[f.id];return sp?`${fxD(f.d*(1-S.prog[f.id]))} · avec résumé`:S.prog[f.id]?`reste ${fxD(f.d*(1-S.prog[f.id]))}`:`finit à ${fmt(bInfo(f).end)}`}
function actsHtml(f){const v=pickSrc(f.id),L=srcs(f.id),rd=FXS.ready===f.id;
 return `<div class="acts"><div class="btn prim ${rd?"ready":""}" data-f data-fid="w-play" data-act="fxplay" data-row="w2" data-col="0" data-default>${rd?'<span class="pzap">⚡</span>':FXI.play}<span class="vpill">${playLbl(f)}<small>${playSub(f)}</small></span></div>
 ${S.prog[f.id]?`<div class="btn" data-f data-fid="w-rs" data-act="fxrs" data-row="w2" data-col="0">${FXI.back}Début</div>`:""}
 ${needSplit(f)&&!S.prog[f.id]?`<div class="btn" data-f data-fid="w-split" data-act="fxsplit" data-row="w2" data-col="0">${FXI.moon}En 2 soirées</div>`:""}
 <div class="btn round" data-f data-fid="w-list" data-act="fxlist" data-row="w2" data-col="0" aria-label="Ma liste">${isFav(f.id)?FXI.check:FXI.plus}</div>
 ${v?`<div class="btn" data-f data-fid="w-ver" data-act="fxver" data-row="w2" data-col="0"><span class="vpill">${tagLbl(v)} · ${v.q==="4K"?"4K":v.q}<small>${fxAuto(f)?"✨ auto":L.length+" version"+(L.length>1?"s":"")} ▾</small></span></div>`:""}
 <div class="btn round trb" data-f data-fid="w-tr" data-act="fxtr" data-row="w2" data-col="0" aria-label="Bande-annonce">${FXI.film}</div></div>`}
function fxSaga(f){const t=tmOf(f);if(!t.col)return [];return films().filter(x=>x.tmd&&x.tmd.col&&x.tmd.col[0]===t.col[0]).sort((a,b)=>a.y-b.y)}
/* langue de la bande-annonce : VF d'abord (choisie par le script), sinon VOSTFR, sinon VO */
const trlTag=l=>l==="vo"?"VO":l==="vost"?"VOSTFR":"VF";
const trlTxt=l=>l==="vo"?"Pas de version française sur TMDB : bande-annonce en version originale":l==="vost"?"Pas de version doublée : bande-annonce en VO sous-titrée français":"Bande-annonce en version française (choisie automatiquement quand elle existe)";
const tchipIn=lvl=>`<span>${(()=>{const t=topS(),tf=t&&t.t==="detail"&&ALL[t.id];return trlTag(tf?tmOf(tf).ytl:"")})()} · ${lvl===3?"🔊 OK pour le plein écran":"🔈 son faible"}</span><span class="vol v${lvl}"><b></b><b></b><b></b></span>`;
const bestWhy=o=>{const P=t=>o.why.find(x=>x.c!=="neg"&&t(x));return (P(x=>x.w>=9)||P(x=>/^Tu as aimé|^Du réalisateur/.test(x.t))||P(x=>x.c==="crew")||P(x=>x.c==="co")||P(x=>x.c==="kw")||P(x=>x.c==="prof")||P(()=>1)||{t:""}).t};
function xSimHtml(f){const mode=FXS.xmode||"mix",L=crossPick(f,mode);if(!L.length)return "";
 return `<section data-anchor><div class="lh">${FXS.duo?"Pour vous deux":"Si tu hésites encore"}<small>${FXS.duo?"selon ce film et vos goûts":"selon ce film et ce que tu regardes"} · maintiens le clic pour les options</small></div>
 <div class="xmodes">${SMODES.map(([k,l])=>`<div class="xm ${mode===k?"sel":""}" data-f data-fid="w-xm-${k}" data-act="fxxmode:${k}" data-row="xm">${l}</div>`).join("")}<div class="xm info" data-f data-fid="w-xinfo" data-act="fxxinfo" data-row="xm">ⓘ Comment on choisit</div></div>
 <div class="xrow sx">${L.map(o=>`<div class="xc">${fxPst(o.c,"w-s-"+o.c.id,"fxopen:"+o.c.id,"sim",`data-xid="${o.c.id}"`).replace('<div class="pt">',o.pA!=null?`<span class="pct duo2">${pav(FXS.duo[0],"xs")}${o.pA} ${pav(FXS.duo[1],"xs")}${o.pB}</span><div class="pt">`:`<span class="pct">${o.pct} %</span><div class="pt">`)}<div class="why one">${esc(bestWhy(o))}</div></div>`).join("")}</div></section>`}
function whereHtml(f){const L=streams(f),tv=fxTV(f),v=srcs(f.id),g=t=>L.filter(x=>t.includes(x.t));if(!L.length&&!tv.length)return "";
 const card=x=>`<div class="wc" data-f data-fid="w-wh${x.i}" data-act="fxsvc:${x.i}">${svTile(x)}<div><b>${esc(x.n)}</b><span>${esc(TYP[x.t])}</span></div><em>${x.t==="abo"?"Inclus":x.t==="gratuit"?"Gratuit":"›"}</em></div>`;
 const grp=(t,items)=>items?`<div class="grp"><div class="kk">${t}</div>${items}</div>`:"";
 return `<section data-anchor id="where"><div class="lh">Où le regarder<small>ailleurs que dans prisme</small></div><div class="inp">▶ <b>Déjà dans prisme</b> · ${v.length} version${v.length>1?"s":""} (${[...new Set(v.map(tagLbl))].join(", ")}) · sans frais en plus</div><div class="wh">
  ${grp("À LA TV",tv.map((x,i)=>`<div class="wc" data-f data-fid="w-wt${i}" data-act="fxtv:${i}"><span class="ico">📺</span><div><b>${esc(x.c.n)}</b><span>${esc(x.t)}</span></div><em>${x.live?"Direct":x.past?"Replay":"Rappel"}</em></div>`).join(""))}
  ${grp("INCLUS OU GRATUIT",g(["abo","gratuit"]).map(card).join(""))}${grp("LOCATION",g(["loc"]).map(card).join(""))}${grp("ACHAT",g(["achat"]).map(card).join(""))}</div>
  <div class="src">${f.tmd?"Disponibilités en France (données TMDB, source JustWatch)":REAL?"Disponibilités : importe films.json pour les voir":"Disponibilités en France · données d'exemple"}</div></section>`}
function fxFiche(f){const b=bInfo(f),w1=b.why[0],sg=fxSaga(f);
 return `<div class="fx"><div class="A W W2 sy" id="fxscr"><div class="hero" data-anchor>${fxArt(f)}<div class="shade"></div>${whoChip()}
  <div class="tx"><div class="kick">FILM${f.tmd&&f.tmd.pays?" · "+esc(fxPays(f.tmd.pays)):""}${fxBlocked(f)?` <span class="lock">🔒 bloqué pour ce profil (${ageLbl(fxMax())})</span>`:""}</div><h1 class="${fxFont(f)} t2" style="font-size:${titleSize(f)}px">${esc(f.t)}</h1>
   <div class="meta"><span>${f.y}</span><span>${fxD(f.d)}</span><span>${esc(f.g.slice(0,2).join(", "))}</span><span>${esc(f.age||"")}</span><span class="st">★ ${f.imdb}</span>${fxQual(f)?`<span class="qpill">${fxQual(f)}</span>`:""}</div>
   ${w1?`<div class="whyc"><span><em>${w1[0]}</em>${w1[1]}</span></div>`:""}
   <div class="syn" data-f data-fid="w-syn" data-act="fxsyn" data-row="w1" data-col="0">${esc(f.s)}</div>${actsHtml(f)}</div>
  <div class="side glass" data-col="1">${scoreHtml(f)}${planHtml(f)}${alsoLine(f)}</div>
  <div class="tchip glass" id="tchip">${tchipIn(1)}</div><div class="more">▼ ${sg.length>1?"Saga, ":""}distribution, films proches et où le regarder</div></div>
  <div class="below">
  ${sg.length>1?`<section data-anchor><div class="lh">${esc(tmOf(f).col[1])}<small>${sg.length} films · dans l'ordre</small></div><div class="saga sx">${sg.map((x,i)=>`<div class="sg" data-f data-fid="w-sg-${x.id}" data-act="fxopen:${x.id}" data-row="sg">${fxArt(x)}<span class="n">${i+1}${x.id===f.id?" · cette page":ME().seen.includes(x.id)?" · ✓ Vu":""}</span><div class="t"><b>${esc(x.t)}</b><span>${x.y} · ${fxD(x.d)}</span></div></div>`).join("")}</div></section>`:""}
  ${f.cast.length?`<section data-anchor><div class="lh">Distribution<small>OK pour ses autres films dans ton abonnement</small></div><div class="row sx">${f.cast.map(([a,r])=>`<div class="av" data-f data-fid="w-c-${a}" data-act="fxactor:${a}" data-row="cast"><div class="ph" style="--h:${hash(a)%360}">${esc(initials(A[a]||"?")||"?")}</div><b>${esc(A[a]||"")}</b><span>${esc(r||"")}</span></div>`).join("")}</div>
   <div class="detl">${f.dir?`Réalisé par <b>${esc(f.dir)}</b> · `:""}${f.y} · Note <b>${f.imdb}</b> · TMDB <b>${f.tmdb} %</b>${f._real&&f._real.r&&f.tmd?` · fournisseur <b>${(+f._real.r).toFixed(1)}</b>`:""}${f._real?` · <span style="opacity:.65">infos ${f.tmd?"TMDB + fournisseur":"fournisseur"}</span>`:""}</div></section>`:`<section data-anchor><div class="detl" style="margin-top:20px">${f.dir?`Réalisé par <b>${esc(f.dir)}</b> · `:""}${f.y} · Note <b>${f.imdb}</b>${REAL&&!f.tmd?" · fiche complète avec films.json":""}</div></section>`}
  ${xSimHtml(f)}${whereHtml(f)}<div style="height:40px"></div></div></div><div class="clock">${fmt(nowMin())}</div></div>`}
{const _d=detailHtml;detailHtml=function(it){return it&&it.type==="f"?fxC(fxFiche(it)):_d(it)}}

/* ---------- fenêtres ---------- */
function fxModal(){const m=S.modal,t=topS(),f=t.t==="detail"?ALL[t.id]:P?ALL[P.id]:null,mt=m.type;
 const opt=(fid,a,b,s,dflt,extra="")=>`<div class="opt ${extra}" data-f data-fid="${fid}" data-act="${a}" ${dflt?"data-default":""}><span class="ck"></span><div class="tx"><b>${b}</b>${s?`<span>${s}</span>`:""}</div></div>`;
 if(mt==="fxsyn")return `<div class="modal"><div class="mbox glass" style="width:780px"><div class="k">SYNOPSIS</div><h2>${esc(f.t)}</h2><p class="mp">${esc(f.s)}</p>${f.tmd&&f.tmd.tg?`<p class="mp" style="font-style:italic;opacity:.7">« ${esc(f.tmd.tg)} »</p>`:""}<div class="opt" data-f data-fid="m-close" data-act="fxclose" data-default style="justify-content:center"><b>Fermer</b></div></div></div>`;
 if(mt==="fxactor"){const L=(CRED[m.a]||[]).map(([id])=>ALL[id]).filter(x=>x&&x.type==="f"&&srcs(x.id).length);return `<div class="modal"><div class="mbox glass" style="width:860px"><div style="display:flex;gap:18px;align-items:center"><div class="av" style="width:auto"><div class="ph" style="--h:${hash(m.a)%360};width:84px;height:84px;font-size:28px">${esc(initials(A[m.a]||"?"))}</div></div><div><div class="k">DANS TON ABONNEMENT</div><h2>${esc(A[m.a]||"")}</h2><div style="opacity:.65;font-size:15px">${L.length} film${L.length>1?"s":""} disponible${L.length>1?"s":""}</div></div></div>
  <div class="row sx" style="padding:14px 6px 10px">${L.map((x,i)=>fxPst(x,"m-a-"+x.id,"fxopen:"+x.id,"ma",i===0?"data-default":"")).join("")}</div></div></div>`}
 if(mt==="fxsplit"){const C=fxCuts(f),sel=m.c==null?1:m.c,n=nowMin();return `<div class="modal"><div class="mbox glass" style="width:760px"><div class="k">EN 2 SOIRÉES</div><h2>${esc(f.t)}</h2><p class="mp">Choisis où t'arrêter ce soir, toujours à la fin d'une scène. prisme s'arrête tout seul, et la partie 2 commence par un résumé de 30 s.</p>
  <div class="cutbar"><div class="ax"></div>${C.map(c=>`<i class="${c.i===sel?"on":""}" style="left:${c.m/f.d*100}%"></i>`).join("")}<span style="left:0">0</span><span style="right:0;left:auto">${fxD(f.d)}</span></div>
  ${C.map(c=>opt("m-c"+c.i,"fxsplitpick:"+c.i,`Arrêt à ${fxD(c.m)} · vers ${fmt(n+c.m)}`,`fin d'une scène · partie 2 : ${fxD(f.d-c.m)}`,c.i===sel,c.i===sel?"sel":"")).join("")}
  <div style="display:flex;gap:12px;margin-top:4px"><div class="btn prim" data-f data-fid="m-go" data-act="fxsplitgo:${sel}">${FXI.play}Lancer la partie 1</div><div class="btn" data-f data-fid="m-x" data-act="fxclose">Annuler</div></div></div></div>`}
 if(mt==="fxsvc"){const x=streams(f)[m.i],v=pickSrc(f.id);return `<div class="modal"><div class="mbox glass"><div style="display:flex;gap:16px;align-items:center">${svTile(x,"lg")}<div><div class="k">${esc(TYP[x.t].toUpperCase())}</div><h2>${esc(x.n)}</h2></div></div>
  ${v?opt("m-here","fxplay","Regarder dans prisme",`Déjà dans ton abonnement IPTV · ${fxTag(v)} · ${v.q} · sans frais en plus`,true):""}${opt("m-open","fxsvopen:"+m.i,`Ouvrir ${esc(x.n)}`,x.t==="abo"?"Si tu es abonné : le film s'ouvre dans l'app":x.t==="gratuit"?"Gratuit, dans l'app":"Dans l'app du service",!v)}
  <div class="mfoot">Sur l'Apple TV, prisme ouvre l'app du service si elle est installée</div></div></div>`}
 if(mt==="fxxinfo"){const T=taste(),G=Object.entries(T.g).sort((a,b)=>b[1]-a[1]).slice(0,4),K=Object.entries(T.kw).sort((a,b)=>b[1]-a[1]).slice(0,6).map(x=>x[0]),N=Object.keys(T.negk).filter(k=>!T.kw[k]).slice(0,4),W=SW[FXS.xmode||"mix"],p=ME(),ex=outside(f);
  return `<div class="modal"><div class="mbox glass" style="width:960px;max-height:660px"><div class="k">TMDB × ${esc(p.n.toUpperCase())}</div><h2>Comment prisme choisit</h2>
  <div class="xtab"><div><div class="k">TON PROFIL</div>${T.tot?G.map(([k,v])=>`<div class="xbar"><span>${esc(k)}</span><b><i style="width:${Math.round(v*100)}%"></i></b><em>${Math.round(v*100)} %</em></div>`).join("")+`<div class="xl">Tes thèmes : <b>${esc(K.join(", ")||"—")}</b>${N.length?`<br>Tu abandonnes souvent : <b>${esc(N.join(", "))}</b>`:""}</div>`:`<div class="xl">Ton historique est vide pour l'instant : les recommandations s'appuient sur ce film. Elles deviennent personnelles au fil des films que tu finis et de tes 👍 / 👎.</div>`}</div>
   <div><div class="k">LE CALCUL</div>${Object.keys(W).filter(k=>W[k]).map(k=>`<div class="xbar"><span><i class="dot c-${k}"></i>${SL[k]}</span><b><i class="c-${k}" style="width:${W[k]*200}%"></i></b><em>${Math.round(W[k]*100)} %</em></div>`).join("")}
   <div class="xl">Retirés : films vus, « pas intéressé », absents de ton fournisseur${ex?` (${ex} recommandation${ex>1?"s":""} TMDB écartée${ex>1?"s":""} ici)`:""}. La rangée est ensuite diversifiée.</div></div></div>
  <div class="opt" data-f data-fid="m-close" data-act="fxclose" data-default style="justify-content:center"><b>Fermer</b></div></div></div>`}
 if(mt==="fxctx"){const c=ALL[m.id];return `<div class="modal"><div class="mbox glass" style="width:560px"><div class="k">OPTIONS</div><h2>${esc(c.t)}</h2>${opt("m-why","fxwhy:"+c.id,"Pourquoi ce film ?","Le détail du calcul",true)}${opt("m-no","fxno:"+c.id,"Pas intéressé","Il ne te sera plus proposé")}${opt("m-seen","fxseen:"+c.id,"Déjà vu ailleurs","Donne ton avis : ça affine tes recommandations")}${opt("m-op","fxopen:"+c.id,"Ouvrir la fiche","")}</div></div>`}
 if(mt==="fxwhy"){const c=ALL[m.id],o=crossPick(f,FXS.xmode||"mix").find(x=>x.c.id===m.id)||scoreOne(f,c,taste(),liked()),W=SW[FXS.xmode||"mix"];
  return `<div class="modal"><div class="mbox glass" style="width:820px"><div class="k">POURQUOI CE FILM${o.pct?" · "+o.pct+" %":""}</div><h2>${esc(c.t)}</h2>${Object.keys(W).filter(k=>W[k]).map(k=>`<div class="xbar"><span><i class="dot c-${k}"></i>${SL[k]}</span><b><i class="c-${k}" style="width:${Math.round(o.parts[k]*100)}%"></i></b><em>${Math.round(o.parts[k]*100)}</em></div>`).join("")}
  <div class="xl">${o.why.slice(0,4).map(x=>"• "+esc(x.t)).join("<br>")||"• Proche de ce film par le genre"}</div><div class="opt" data-f data-fid="m-close" data-act="fxclose" data-default style="justify-content:center"><b>Fermer</b></div></div></div>`}
 if(mt==="fxrate"){const c=ALL[m.id];return `<div class="modal"><div class="mbox glass" style="width:640px;text-align:center"><div class="k">${m.end?"FIN DU FILM":"TON AVIS"}</div><h2>Tu as aimé ${esc(c.t)} ?</h2><div style="font-size:14px;opacity:.7;margin-top:-4px">Une seconde, et tes recommandations deviennent plus justes</div>
  <div style="display:flex;gap:12px;justify-content:center;margin-top:8px"><div class="btn" data-f data-fid="m-up" data-act="fxrate:${c.id}:1" data-default>👍 J'ai aimé</div><div class="btn" data-f data-fid="m-dn" data-act="fxrate:${c.id}:-1">👎 Pas pour moi</div><div class="btn" data-f data-fid="m-sk" data-act="fxrate:${c.id}:0">Passer</div></div></div></div>`}
 if(mt==="fxtrl"){const tm=tmOf(f);return `<div class="modal trlm"><div class="trl">${fxArt(f,"play")}<div class="lab glass">BANDE-ANNONCE ${trlTag(tm.ytl)} · ${esc(f.t)}</div><div class="tsrc">${trlTxt(tm.ytl)}</div><div class="go"><div class="btn prim" data-f data-fid="t-go" data-act="fxplay" data-default>${FXI.play}Regarder le film</div></div><div class="tb"><i id="tbar" style="width:0%"></i></div></div></div>`}
 if(mt==="fxcut"){return `<div class="modal"><div class="mbox glass" style="width:640px;text-align:center"><div class="k">FIN DE LA PARTIE 1</div><h2>Bonne nuit !</h2><p class="mp">La partie 2 (${fxD(f.d-fxCuts(f)[P.cut].m)}) t'attend sur la fiche et dans « Reprendre », avec un résumé.</p><div class="cnt">Arrêt automatique dans <b id="cntn">10</b> s</div>
  <div style="display:flex;gap:12px;justify-content:center"><div class="btn prim" data-f data-fid="m-stop" data-act="fxcutstop" data-default>Arrêter, la suite demain</div><div class="btn" data-f data-fid="m-cont" data-act="fxcutcont">Continuer quand même</div></div></div></div>`}
 if(mt==="fxrecap"){const tm=tmOf(f);return `<div class="modal trlm"><div class="trl">${fxArt(f,"play")}<div class="lab glass">RÉSUMÉ DE LA PARTIE 1 · 30 s</div><div class="recap glass"><b>Précédemment dans ${esc(f.t)}</b><span>${esc((f.s||"").slice(0,240))}${(f.s||"").length>240?"…":""}</span></div><div class="go"><div class="btn prim" data-f data-fid="r-skip" data-act="fxrecapskip" data-default>Passer le résumé</div></div><div class="tb"><i id="tbar" style="width:0%"></i></div></div></div>`}
 if(mt==="fxend"){const n=m.next;if(m.post&&!m.postDone)return `<div class="modal endm"><div class="endc glass"><div class="k">🎬 SCÈNE APRÈS LE GÉNÉRIQUE</div><b>Reste jusqu'au bout</b><span>Une scène t'attend à la toute fin.</span><div class="ea"><div class="btn prim" data-f data-fid="e-pc" data-act="fxpcjump" data-default>Aller à la scène</div><div class="btn" data-f data-fid="e-pcno" data-act="fxpcno">Ignorer</div>${rateBtns(f)}</div></div></div>`;
  return `<div class="modal endm"><div class="endc glass"><div class="k">À SUIVRE${n&&m.cd!=null?` · LECTURE DANS <b id="ecd">${m.cd}</b> s`:""}</div>${n?`<div class="en">${fxPst(n.c,"e-np","fxnextgo","").replace(/class="pst /,'class="pst sm ')}<div><b>${esc(n.c.t)}</b><span>${esc(n.why)}</span><span>${fxD(n.c.d)}</span></div></div>`:"<b>C'est la fin</b>"}
  <div class="ea">${n?`<div class="btn prim" data-f data-fid="e-go" data-act="fxnextgo" data-default>${FXI.play}Regarder maintenant</div>`:""}<div class="btn" data-f data-fid="e-stay" data-act="fxnextstay" ${n?"":"data-default"}>Rester</div>${rateBtns(f)}</div></div></div>`}
 if(mt==="fxshelf")return fxShelf();
 return fxProfModal(m)}
const rateBtns=f=>{const r=ME().fb[f.id];return `<div class="btn round ${r===1?"on":""}" data-f data-fid="e-up" data-act="fxerate:1" aria-label="J'ai aimé">👍</div><div class="btn round ${r===-1?"on":""}" data-f data-fid="e-dn" data-act="fxerate:-1" aria-label="Pas aimé">👎</div>`};
{const _m=modalHtml;modalHtml=function(){return S.modal&&String(S.modal.type||"").startsWith("fx")?fxC(`<div class="fx fxw">${fxModal()}</div>`):_m()}}

/* ---------- profils : fenêtres ---------- */
function fxProfModal(m){const ids=Object.keys(PR.list),mt=m.type;
 if(mt==="fxwhofull")return `<div class="modal whof"><h1>Qui regarde ?</h1><div class="wfrow">${ids.map(id=>`<div class="wfp" data-f data-fid="m-p-${id}" data-act="fxprof:${id}" data-pid="${id}" ${id===PR.cur?"data-default":""}>${pav(id,"xl")}<b>${esc(PR.list[id].n)}</b><span>${PR.list[id].max!=null?"🔒 "+ageLbl(PR.list[id].max):"&nbsp;"}</span></div>`).join("")}
  ${ids.length>=2?`<div class="wfp" data-f data-fid="m-p-duo" data-act="fxduo:${ids[0]}:${ids[1]}"><span class="duoav">${pav(ids[0],"xl")}${pav(ids[1],"xl ov")}</span><b>À deux</b><span>${esc(PR.list[ids[0]].n)} + ${esc(PR.list[ids[1]].n)}</span></div>`:""}
  <div class="wfp" data-f data-fid="m-p-add" data-act="fxpadd"><i class="pav xl add">+</i><b>Ajouter</b><span>&nbsp;</span></div></div>
  <div class="wfh">OK pour choisir · maintiens le clic sur un profil pour le modifier · <span class="lnk2" data-f data-fid="m-p-man" data-act="fxpman">Gérer les profils</span></div></div>`;
 if(mt==="fxwho"){const opts=[...ids.map(id=>({id,a:"fxprof:"+id,t:PR.list[id].n,s:(PR.list[id].max!=null?"🔒 "+ageLbl(PR.list[id].max)+" · ":"")+`${PR.list[id].seen.length} films vus · ${(PR.list[id].hist||[]).length} dans l'historique`,av:pav(id,"lg")})),...(ids.length>=2?[{id:"duo",a:`fxduo:${ids[0]}:${ids[1]}`,t:`${PR.list[ids[0]].n} + ${PR.list[ids[1]].n}, à deux`,s:"Un score commun et des films pour vous deux",av:pav(ids[0],"lg")+pav(ids[1],"lg ov")}]:[])];
  return `<div class="modal"><div class="mbox glass" style="width:640px;max-height:680px"><div class="k">QUI REGARDE ?</div><h2>Choisis un profil</h2><div class="sy" style="display:flex;flex-direction:column;gap:10px;max-height:400px;padding:4px">${opts.map(o=>{const on=o.id==="duo"?!!FXS.duo:!FXS.duo&&PR.cur===o.id;return `<div class="opt ${on?"sel":""}" data-f data-fid="m-p-${o.id}" data-act="${o.a}" ${o.id!=="duo"?`data-pid="${o.id}"`:""} ${on?"data-default":""}><span class="avs">${o.av}</span><div class="tx"><b>${esc(o.t)}</b><span>${esc(o.s)}</span></div><span class="ck"></span></div>`}).join("")}
  <div class="opt" data-f data-fid="m-p-add" data-act="fxpadd"><span class="avs"><i class="pav lg add">+</i></span><div class="tx"><b>Ajouter un profil</b><span>Nom, couleur, langue, limite d'âge…</span></div></div></div>
  <div style="display:flex;gap:10px"><div class="btn" data-f data-fid="m-p-man" data-act="fxpman" style="height:44px;font-size:15px">⚙ Gérer les profils</div></div><div class="mfoot">Maintiens le clic sur un profil pour le modifier</div></div></div>`}
 if(mt==="fxpman")return `<div class="modal"><div class="mbox glass solid" style="width:680px;max-height:680px"><div class="k">RÉGLAGES › PROFILS</div><h2>Gérer les profils</h2>
  <div class="sy" style="display:flex;flex-direction:column;gap:10px;max-height:380px;padding:4px">${ids.map(id=>{const p=PR.list[id];return `<div class="opt" data-f data-fid="m-e-${id}" data-act="fxpedit:${id}"><span class="avs">${pav(id,"lg")}</span><div class="tx"><b>${esc(p.n)}</b><span>Langue ${p.lang==="auto"?"auto":p.lang} · coucher ${fmt(p.bed)} · limite ${ageLbl(p.max)}</span></div><span style="opacity:.6">Modifier ›</span></div>`}).join("")}
   <div class="opt" data-f data-fid="m-p-add" data-act="fxpadd"><span class="avs"><i class="pav lg add">+</i></span><div class="tx"><b>Ajouter un profil</b></div></div></div>
  <div class="opt tgl ${PR.ask?"on":""}" data-f data-fid="m-ask" data-act="fxpask"><div class="tx"><b>Demander « Qui regarde ? » à l'ouverture</b><span>Seulement s'il y a plusieurs profils</span></div><span class="sw"></span></div></div></div>`;
 if(mt==="fxpedit"){const id=m.id,p=PR.list[id];const row=(fid,a,lab,val,sub="")=>`<div class="opt prow" data-f data-fid="${fid}" data-act="${a}"><div class="tx"><b>${lab}</b>${sub?`<span>${sub}</span>`:""}</div><em>${val}</em></div>`;
  return `<div class="modal"><div class="mbox glass solid" style="width:760px;max-height:690px"><div style="display:flex;gap:16px;align-items:center">${pav(id,"md")}<div><div class="k">${m.isNew?"NOUVEAU PROFIL":"MODIFIER LE PROFIL"}</div><h2>${esc(p.n)}</h2></div></div>
  <div class="sy" style="display:flex;flex-direction:column;gap:8px;max-height:450px;padding:4px">
   ${row("pe-name","fxpname:"+id,"Nom",esc(p.n)+" ✎")}
   <div class="opt prow"><div class="tx"><b>Couleur</b></div><div class="sw8">${PCOL.map((c,i)=>`<i class="${p.c===c?"on":""}" style="--c:${c}" data-f data-fid="pe-c${i}" data-act="fxpcol:${id}:${i}" data-row="pec"></i>`).join("")}</div></div>
   <div class="opt prow"><div class="tx"><b>Avatar</b></div><div class="sw8">${PEMO.map((e,i)=>`<i class="emo ${p.emo===e?"on":""}" data-f data-fid="pe-e${i}" data-act="fxpemo:${id}:${i}" data-row="pee">${e||esc((p.n||"?")[0])}</i>`).join("")}</div></div>
   ${row("pe-lang","fxplang:"+id,"Langue préférée",p.lang==="auto"?"✨ Automatique":p.lang,p.lang==="auto"?"prisme apprend de tes choix":p.lang==="VF"?"tout doublage français : VFF d'abord, puis VF, VFI, VFQ":p.lang==="VFF"?"doublage de France en priorité":p.lang==="VFQ"?"doublage québécois en priorité":"toujours cette version si elle existe")}
   ${row("pe-bed","fxpbed:"+id,"Heure de coucher habituelle",fmt(p.bed),"pour « Ta soirée » et « En 2 soirées »")}
   ${row("pe-age","fxpage:"+id,"Limite d'âge",ageLbl(p.max),"les films au-dessus sont masqués partout")}
   ${row("pe-clr","fxpclr:"+id,"Effacer l'historique","",`${p.seen.length} films vus · ${Object.keys(p.fb).length} avis · repartir de zéro`)}
   ${ids.length>1?`<div class="opt prow danger" data-f data-fid="pe-del" data-act="fxpdel:${id}"><div class="tx"><b>Supprimer le profil</b></div></div>`:""}</div>
  <div class="btn prim" data-f data-fid="pe-ok" data-act="fxpdone" data-default style="align-self:flex-start;height:46px;font-size:16px">Terminé</div><div class="mfoot">OK sur une ligne pour changer la valeur</div></div></div>`}
 if(mt==="fxpname"){const K="ABCDEFGHIJKLMNOPQRSTUVWXYZ-".split("");return `<div class="modal"><div class="mbox glass solid" style="width:640px"><div class="k">NOM DU PROFIL</div><div class="nmbox">${esc(m.v)}<span class="caret"></span></div>
  <div class="kbd">${K.map(c=>`<i data-f data-fid="nk-${c}" data-act="fxnk:${c}">${c}</i>`).join("")}<i class="w2" data-f data-fid="nk-sp" data-act="fxnk:sp">espace</i><i class="w2" data-f data-fid="nk-del" data-act="fxnk:del">⌫</i><i class="w2 ok" data-f data-fid="nk-ok" data-act="fxnk:ok">OK</i></div><div class="mfoot">Le clavier de l'ordinateur marche aussi</div></div></div>`}
 if(mt==="fxpconf"){const p=PR.list[m.id];return `<div class="modal"><div class="mbox glass solid" style="width:560px"><div class="k">CONFIRMATION</div><h2>${m.what==="del"?`Supprimer ${esc(p.n)} ?`:`Effacer l'historique de ${esc(p.n)} ?`}</h2><p class="mp">${m.what==="del"?"Ses reprises, favoris, avis et préférences seront perdus.":"Films vus, historique, 👍 / 👎 et langue apprise : les recommandations repartent de zéro."}</p>
  <div style="display:flex;gap:12px"><div class="btn" data-f data-fid="pc-no" data-act="fxpconfno" data-default>Annuler</div><div class="btn danger" data-f data-fid="pc-yes" data-act="fxpconfyes">${m.what==="del"?"Supprimer":"Effacer"}</div></div></div></div>`}
 return ""}

/* ---------- écran d'accueil de l'Apple TV (bannière du haut) ---------- */
const APPS=[["films","Films","🎬"],["prisme","prisme","◆"],["musique","Musique","♪"],["photos","Photos","▣"],["reglages","Réglages","⚙"]];
function shelfItems(){const L=[],p=ME();for(const id in S.prog){const f=ALL[id];if(!f||f.type!=="f"||!srcs(id).length)continue;L.push({f,k:p.split[id]!=null?"PARTIE 2":"REPRENDRE",s:p.split[id]!=null?`${fxD(f.d*(1-S.prog[id]))} · avec résumé`:`reste ${fxD(f.d*(1-S.prog[id]))}`,a:"fxhplay:"+id})}
 const base=ALL[(fxHist(PR.cur).slice().reverse().find(h=>h.done>=.85)||{}).id]||films()[0];if(base)crossPick(base,"mix").slice(0,5).forEach(o=>{if(!L.some(x=>x.f.id===o.c.id))L.push({f:o.c,k:"POUR "+(FXS.duo?"VOUS DEUX":ME().n.toUpperCase()),s:`${o.pct||o.pA} % · ${bestWhy(o)}`,a:"fxhopen:"+o.c.id})});
 if(L.length<4)films().slice(0,6).forEach(f=>{if(!L.some(x=>x.f.id===f.id))L.push({f,k:"NOUVEAUTÉ",s:`${f.y} · ${fxD(f.d)}`,a:"fxhopen:"+f.id})});return L.slice(0,7)}
function fxShelf(){const sel=FXS.hsel||"prisme",L=sel==="prisme"?shelfItems():[];
 return `<div class="modal homesc"><div class="hwall"></div><div class="shelf">${sel==="prisme"?`<div class="sh-row sx">${L.map((x,i)=>`<div class="shi" data-f data-fid="h-s${i}" data-act="${x.a}" data-row="shelf">${fxArt(x.f)}<div class="sh-sh"></div><div class="sh-t"><em>${x.k}</em><b>${esc(x.f.t)}</b><span>${esc(x.s)}</span></div>${S.prog[x.f.id]?`<div class="sh-p"><i style="width:${S.prog[x.f.id]*100}%"></i></div>`:""}</div>`).join("")}</div><div class="sh-lab">${FXS.duo?"À deux":esc(ME().n)} · ce que prisme te propose, sans ouvrir l'appli</div>`:`<div class="sh-empty">Bannière de l'app « ${APPS.find(a=>a[0]===sel)[1]} »</div>`}</div>
 <div class="dock">${APPS.map(([k,n,g])=>`<div class="app ${k==="prisme"?"pr":""}" data-f data-fid="h-a-${k}" data-act="fxhapp:${k}" data-app="${k}" data-row="dock" ${k===sel?"data-default":""}><div class="ai">${k==="prisme"?'<span class="prl">◆</span>':g}</div><span>${n}</span></div>`).join("")}</div><div class="clock">${fmt(nowMin())}</div></div>`}

/* ---------- lecture : démarrage immédiat, 2 soirées, fin de film ---------- */
const fxCuts=f=>[.44,.52,.6].map((r,i)=>({i,m:Math.round(f.d*r)}));
function fxNext(f){const sg=fxSaga(f),i=sg.indexOf(f),seen=new Set(ME().seen);if(i>=0&&sg[i+1]&&!seen.has(sg[i+1].id))return {c:sg[i+1],why:"La suite de la saga"};const o=crossPick(f,"mix").find(x=>!S.prog[x.c.id]);return o?{c:o.c,why:`${o.pct||o.pA} % pour toi · ${bestWhy(o)}`}:null}
function fxRec(id,done){const p=ME();p.hist=(p.hist||[]).filter(h=>h.id!==id);p.hist.push({id,done:Math.round(done*100)/100,at:Date.now()});p.hist=p.hist.slice(-200);if(done>=.85&&!p.seen.includes(id))p.seen.push(id);FXS.cache={};prSave()}
function fxStart(id,o={}){const f=ALL[id];if(!f)return;if(fxBlocked(f)){toast(`🔒 Ce film (${f.age}) dépasse la limite du profil`);return}
 const ready=FXS.ready===id;FXS.ready=null;const sp=ME().split[id]!=null&&S.prog[id]&&!o.restart;if(o.restart)delete S.prog[id];
 S.modal=null;act("play:"+id);if(!P)return;P.fx=true;P.cut=o.cut;P.part2=sp;
 if(sp){P.playing=false;S.modal={type:"fxrecap",ret:"p-pp",t0:Date.now()};render("r-skip");fxRecapRun();return}
 if(!ready){P.playing=false;P.fxbuf=true;render("p-pp");setTimeout(()=>{if(P&&P.fxbuf){P.fxbuf=false;P.playing=true;render(F&&F.dataset.fid)}},1800)}else{P.fxinst=Date.now();render("p-pp")}}
let fxRT=0;function fxRecapRun(){clearInterval(fxRT);fxRT=setInterval(()=>{const m=S.modal;if(!m||m.type!=="fxrecap")return clearInterval(fxRT);const pc=Math.min(100,(Date.now()-m.t0)/300);const b=$("#tbar");if(b)b.style.width=pc+"%";if(pc>=100){clearInterval(fxRT);act("fxrecapskip")}},250)}
{const _ph=playerHtml;playerHtml=function(){let h=_ph();if(!P||P.kind!=="vod"||!P.fx)return h;const f=ALL[P.id];
 const ov=P.fxbuf?`<div class="fx"><div class="buf"><span class="spin big"></span><b>Connexion au flux…</b><small>reste 2 s sur Lecture avant de lancer : prisme prépare le film et il démarre tout de suite</small></div></div>`:P.fxinst&&Date.now()-P.fxinst<4000?`<div class="fx"><div class="inst glass">⚡ Démarrage immédiat</div></div>`:"";
 h=h.replace('<div class="player">','<div class="player">'+fxC(ov));
 if(P.cut!=null)h=h.replace('<i id="pbar"',`<em class="fxcutm" style="left:${fxCuts(f)[P.cut].m/f.d*100}%"></em><i id="pbar"`).replace(/(<div class="pkick">)/,`$1Partie 1/2 · arrêt à ${fxD(fxCuts(f)[P.cut].m)} · `);
 h=h.replace(/(<div class="prow"><div class="pgrp">)/,`$1<div class="pc" data-f data-fid="p-fxend" data-act="${P.cut!=null&&!P.cutShown?"fxpcut":"fxpend"}"><span><b>${P.cut!=null&&!P.cutShown?"Aller à la coupure":"Aller au générique"}</b><small>démo</small></span></div>`);
 return h}}
{const _t=tick;tick=function(){_t();if(!P||P.kind!=="vod"||!P.fx||!P.playing)return;const f=ALL[P.id];if(!f||f.type!=="f")return;
 if(P.cut!=null&&!P.cutShown&&P.pos>=fxCuts(f)[P.cut].m*60){P.cutShown=true;P.playing=false;S.modal={type:"fxcut",ret:"p-pp"};render("m-stop");fxCount();return}
 if(!P.endDone&&P.pos>=P.dur-7*60){P.endDone=true;const nx=fxNext(f),post=tmOf(f).post;S.modal={type:"fxend",ret:"p-pp",next:nx,post,cd:nx&&!post?15:null};render(post?"e-pc":nx?"e-go":"e-stay");if(nx&&!post)fxNextCount()}
 if(S.modal&&S.modal.type==="fxend"&&S.modal.cd!=null){}}}
let fxCT=0;function fxCount(){clearInterval(fxCT);let n=10;fxCT=setInterval(()=>{if(!S.modal||S.modal.type!=="fxcut")return clearInterval(fxCT);n--;const e=$("#cntn");if(e)e.textContent=n;if(n<=0){clearInterval(fxCT);act("fxcutstop")}},1000)}
let fxNT=0;function fxNextCount(){clearInterval(fxNT);fxNT=setInterval(()=>{const m=S.modal;if(!m||m.type!=="fxend"||m.cd==null)return clearInterval(fxNT);m.cd--;const e=$("#ecd");if(e)e.textContent=m.cd;if(m.cd<=0){clearInterval(fxNT);act("fxnextgo")}},1000)}
{const _sp=stopPlayer;stopPlayer=function(){const p=P;let ask=null,fin=false;if(p&&p.kind==="vod"&&ALL[p.id]&&ALL[p.id].type==="f"&&!ALL[p.id].rp){const pct=p.pos/p.dur;if(pct>.01||p.endDone){fxRec(p.id,p.endDone?Math.max(pct,.9):pct)}if((pct>=.85||p.endDone)&&ME().fb[p.id]===undefined&&!p.noAsk)ask=p.id;fin=pct>=.85||p.endDone}
 _sp();if(fin){delete S.prog[p.id];delete ME().split[p.id];prSave();save()}if(ask&&!S.modal){S.modal={type:"fxrate",id:ask,end:true,ret:"w-play"}}}}

/* ---------- actions ---------- */
function fxClose(fid){const r=fid||(S.modal&&S.modal.ret);S.modal=null;render(r)}
function fxAct(k,v,w,x){const t=topS(),f=t.t==="detail"?ALL[t.id]:P?ALL[P.id]:null,m=S.modal;
 switch(k){
 case "fxclose":return fxClose();
 case "fxplay":{const id=f&&f.id;if(!id)return;if(m&&m.type==="fxtrl"){S.modal=null}if(t.t==="player")return;return fxStart(id)}
 case "fxrs":return fxStart(f.id,{restart:true});
 case "fxsplit":S.modal={type:"fxsplit",c:1,ret:"w-split"};return render("m-c1");
 case "fxsplitpick":S.modal.c=+v;return render("m-go");
 case "fxsplitgo":{S.modal=null;fxStart(f.id,{cut:+v});return}
 case "fxlist":{if(isFav(f.id))S.favs=S.favs.filter(z=>z!==f.id);else S.favs.push(f.id);save();return render("w-list")}
 case "fxver":{if(srcs(f.id).length<2){toast("Une seule version chez ton fournisseur");return}S.modal={k:f.id,ret:"w-ver",fxsel:true};return render(S.modal.ret)}
 case "fxtr":{S.modal={type:"fxtrl",ret:"w-tr",t0:Date.now()};render("t-go");clearInterval(fxRT);fxRT=setInterval(()=>{const mm=S.modal;if(!mm||mm.type!=="fxtrl")return clearInterval(fxRT);const pc=Math.min(100,(Date.now()-mm.t0)/300);const b=$("#tbar");if(b)b.style.width=pc+"%";if(pc>=100){clearInterval(fxRT);fxClose()}},250);return}
 case "fxsyn":S.modal={type:"fxsyn",ret:"w-syn"};return render();
 case "fxactor":S.modal={type:"fxactor",a:v,ret:F.dataset.fid};return render();
 case "fxopen":{S.modal=null;if(t.t==="detail"&&t.id===v){render();return}push({t:"detail",id:v});const sc=$("#fxscr");if(sc)sc.scrollTop=0;return}
 case "fxsvc":S.modal={type:"fxsvc",i:+v,ret:F.dataset.fid};return render();
 case "fxsvopen":{const s=streams(f)[+v];fxClose();return toast(`Ouverture de ${s.n}… (simulé)`)}
 case "fxwhere":{const e=view.querySelector("#where [data-f]");if(e)setFocus(e);return}
 case "fxtv":{const x=fxTV(f)[+v];if(!x)return;if(x.live)return act("live:"+x.c.id);if(x.past&&typeof lreplay==="function")return lreplay(x.c.id,x.p.s);return toast(`⏰ Rappel programmé : ${x.c.n}, ${x.t}`)}
 case "fxxmode":FXS.xmode=v;return render(F.dataset.fid);
 case "fxxinfo":S.modal={type:"fxxinfo",ret:"w-xinfo"};return render();
 case "fxwhy":S.modal={type:"fxwhy",id:v,ret:m&&m.ret};return render();
 case "fxno":{ME().no.push(v);FXS.cache={};prSave();const r=m&&m.ret;S.modal=null;render("w-xm-mix");return toast(`« ${ALL[v].t} » ne te sera plus proposé`)}
 case "fxseen":S.modal={type:"fxrate",id:v,ret:m&&m.ret};return render();
 case "fxrate":{const r=+w,ret=m&&m.ret;const p=ME();if(!p.seen.includes(v))p.seen.push(v);if(r)p.fb[v]=r;FXS.cache={};prSave();S.modal=null;render(ret);if(r)toast(r>0?"👍 Noté · tes recommandations sont mises à jour":"👎 Noté · on t'en proposera moins comme ça");return}
 case "fxerate":{const r=+v;ME().fb[P.id]=r;FXS.cache={};prSave();if(P)P.noAsk=true;render(F.dataset.fid);return toast(r>0?"👍 Noté":"👎 Noté")}
 case "fxpend":{P.pos=Math.max(0,P.dur-7*60-5);P.endDone=false;P.playing=true;render("p-pp");return toast("Le générique commence dans 5 s")}
 case "fxpcut":{P.pos=fxCuts(ALL[P.id])[P.cut].m*60-8;P.playing=true;render("p-pp");return toast("La coupure arrive dans 8 s")}
 case "fxcutstop":{clearInterval(fxCT);const id=P.id,ff=ALL[id];S.prog[id]=P.pos/P.dur;ME().split[id]=P.cut;P.noAsk=true;prSave();save();S.modal=null;stopPlayer();S.stack.pop();render(topS().last||"w-play");return toast("⏰ Partie 2 enregistrée · elle t'attend sur la fiche")}
 case "fxcutcont":{clearInterval(fxCT);S.modal=null;P.cut=null;P.playing=true;render("p-pp");return}
 case "fxrecapskip":{clearInterval(fxRT);S.modal=null;if(P){P.playing=true;P.part2=false}delete ME().split[P&&P.id];prSave();render("p-pp");return}
 case "fxpcjump":{m.postDone=true;P.pos=P.dur-50;S.modal=null;render("p-pp");return toast("🎬 La scène post-générique arrive")}
 case "fxpcno":{m.postDone=true;if(m.next){m.cd=15;render("e-go");fxNextCount()}else render("e-stay");return}
 case "fxnextstay":{clearInterval(fxNT);S.modal=null;render("p-pp");return}
 case "fxnextgo":{clearInterval(fxNT);const n=m&&m.next;if(!n)return;S.modal=null;P.noAsk=true;P.pos=P.dur;stopPlayer();S.stack.pop();if(topS().t==="detail")S.stack.pop();S.stack.push({t:"detail",id:n.c.id,last:"w-play"});FXS.ready=n.c.id;render("w-play");fxStart(n.c.id);return toast("▶ "+n.c.t)}
 case "fxwho":S.modal={type:"fxwho",ret:F&&F.dataset.fid};return render();
 case "fxprof":{const r=m&&m.ret;prSwitch(v);FXS.duo=null;FXS.ready=null;S.modal=null;if(m&&m.type==="fxwhofull"){S.stack=[{t:"home"}];return render()}return render(r)}
 case "fxduo":{const r=m&&m.ret;prSwitch(v);FXS.duo=[v,w];FXS.ready=null;FXS.cache={};S.modal=null;if(m&&m.type==="fxwhofull"){S.stack=[{t:"home"}];return render()}return render(r)}
 case "fxpadd":{const id="p"+Date.now().toString(36);const n=Object.keys(PR.list).length;PR.list[id]={n:"Profil "+(n+1),c:PCOL[n%PCOL.length],emo:null,bed:23*60,lang:"auto",max:null,pref:{},hist:[],fb:{},seen:[],no:[],split:{},d:null};prSave();S.modal={type:"fxpedit",id,isNew:true,back:m&&m.type,ret:m&&m.ret};return render("pe-name")}
 case "fxpman":S.modal={type:"fxpman",ret:m&&m.ret,from:m&&m.type};return render();
 case "fxpedit":S.modal={type:"fxpedit",id:v,back:"fxpman",ret:m&&m.ret,from:m&&m.from};return render();
 case "fxpname":S.modal={...m,type:"fxpname",v:PR.list[v].n,id:v,prev:m};return render("nk-A");
 case "fxnk":{if(v==="ok"){const nm=m.v.trim()||PR.list[m.id].n;PR.list[m.id].n=nm.charAt(0).toUpperCase()+nm.slice(1).toLowerCase();prSave();S.modal=m.prev;return render("pe-name")}if(v==="del")m.v=m.v.slice(0,-1);else if(v==="sp")m.v+=" ";else if(m.v.length<14)m.v+=v;return render(F&&F.dataset.fid)}
 case "fxpcol":PR.list[v].c=PCOL[+w];prSave();return render(F.dataset.fid);
 case "fxpemo":PR.list[v].emo=PEMO[+w];prSave();return render(F.dataset.fid);
 case "fxplang":{const L=["auto","VF","VFF","VFQ","VOSTFR"];PR.list[v].lang=L[(L.indexOf(PR.list[v].lang)+1)%L.length];prSave();return render("pe-lang")}
 case "fxpbed":{const L=[22*60,22*60+30,23*60,23*60+30,24*60,24*60+30,25*60];PR.list[v].bed=L[(L.indexOf(PR.list[v].bed)+1)%L.length];prSave();return render("pe-bed")}
 case "fxpage":{PR.list[v].max=AGES[(AGES.indexOf(PR.list[v].max)+1)%AGES.length];FXS.cache={};prSave();return render("pe-age")}
 case "fxpclr":S.modal={type:"fxpconf",what:"clr",id:v,prev:m};return render();
 case "fxpdel":S.modal={type:"fxpconf",what:"del",id:v,prev:m};return render();
 case "fxpconfno":S.modal=m.prev;return render();
 case "fxpconfyes":{const p=PR.list[m.id];if(m.what==="clr"){Object.assign(p,{hist:[],fb:{},seen:[],no:[],split:{},pref:{}});if(m.id===PR.cur){S.prog={};save()}else if(p.d)p.d.prog={};FXS.cache={};prSave();S.modal=m.prev;render("pe-ok");return toast(`Historique de ${p.n} effacé`)}
  const n=p.n;if(m.id===PR.cur){const other=Object.keys(PR.list).find(k=>k!==m.id);prSwitch(other)}delete PR.list[m.id];if(FXS.duo&&FXS.duo.includes(m.id))FXS.duo=null;prSave();S.modal={type:"fxpman",ret:m.prev&&m.prev.ret};render();return toast(`Profil ${n} supprimé`)}
 case "fxpdone":{const mm=m;S.modal=mm.back==="fxwho"||mm.back==="fxwhofull"?{type:mm.back,ret:mm.ret}:mm.back==="fxpman"?{type:"fxpman",ret:mm.ret,from:mm.from}:null;render(mm.ret);if(mm.isNew)toast(`${/^profil/i.test(PR.list[mm.id].n)?"":"Profil "}${PR.list[mm.id].n} créé`);return}
 case "fxpask":PR.ask=!PR.ask;prSave();return render("m-ask");
 case "fxhapp":{if(v!=="prisme")return toast("Ouvre une autre app (simulé)");S.modal=PR.ask&&Object.keys(PR.list).length>1?{type:"fxwhofull"}:null;return render()}
 case "fxhplay":{S.modal=null;S.stack=[{t:"home"},{t:"detail",id:v,last:"w-play"}];FXS.ready=v;render("w-play");return fxStart(v)}
 case "fxhopen":{S.modal=null;S.stack=[{t:"home"},{t:"detail",id:v}];return render()}
 }}
{const _a=act;act=function(a){if(!a)return;const [k,v,w,x]=a.split(":");if(k.startsWith("fx"))return fxAct(k,v,w,x);
 if(k==="msrc"&&S.modal&&!String(S.modal.k||"").startsWith("ch:")){fxLearn(S.modal.k,v);if(S.modal.fxsel){S.srcSel[S.modal.k]=v;save();FXS.cache={};const r=S.modal.ret;S.modal=null;return render(r)}}
 if(k==="srcplay")fxLearn(v,w);
 if(k==="play"&&ALL[v]&&ALL[v].type==="f"&&!ALL[v].rp&&!P&&topS().t!=="player"&&!fxStarting){fxStarting=true;try{fxStart(v)}finally{fxStarting=false}return}
 return _a(a)}}
let fxStarting=false;
/* le vrai lancement passe par l'action d'origine */
{const _fs=fxStart;fxStart=function(id,o){fxStarting=true;try{return _fs(id,o)}finally{fxStarting=false}}}

/* ---------- touches ---------- */
function fxBack(){const m=S.modal,mt=m.type;
 if(mt==="fxpname"){S.modal=m.prev;return render("pe-name")}if(mt==="fxpconf"){S.modal=m.prev;return render()}if(mt==="fxpedit"){if(m.isNew){const n=PR.list[m.id]&&PR.list[m.id].n;delete PR.list[m.id];prSave();S.modal=m.back==="fxwho"||m.back==="fxwhofull"?{type:m.back,ret:m.ret}:m.back==="fxpman"?{type:"fxpman",ret:m.ret}:null;render(m.ret);return toast(`${n||"Profil"} non créé`)}return fxAct("fxpdone")}
 if(mt==="fxpman"&&(m.from==="fxwho"||m.from==="fxwhofull")){S.modal={type:m.from,ret:m.ret};return render("m-p-man")}
 if(mt==="fxwhofull"||mt==="fxshelf")return;if(mt==="fxcut")return fxAct("fxcutstop");if(mt==="fxrecap")return fxAct("fxrecapskip");if(mt==="fxend")return fxAct("fxnextstay");
 clearInterval(fxRT);return fxClose()}
{const _k=key;key=function(k){
 if(S.modal&&String(S.modal.type||"").startsWith("fx")){if(k==="back")return fxBack();if(k==="menu"&&F&&F.dataset.pid){S.modal={type:"fxpedit",id:F.dataset.pid,back:S.modal.type,ret:S.modal.ret};return render()}if(k==="home"){if(S.modal.type==="fxshelf")return;}}
 if(k==="menu"&&!S.modal&&F&&F.dataset.xid){S.modal={type:"fxctx",id:F.dataset.xid,ret:F.dataset.fid};return render()}
 if(k==="home"&&inApp()){if(P)stopPlayer();S.stack=[{t:"home"}];FXS.hsel="prisme";S.modal={type:"fxshelf"};return render("h-a-prisme")}
 if(k==="play"&&!S.modal&&topS().t==="detail"&&ALL[topS().id]&&ALL[topS().id].type==="f")return fxStart(topS().id);
 return _k(k)}}
document.addEventListener("keydown",e=>{if(!(S.modal&&S.modal.type==="fxpname"))return;let k=null;if(/^[a-zA-ZÀ-ÿ]$/.test(e.key))k=e.key.toUpperCase();else if(e.key===" ")k="sp";else if(e.key==="Backspace")k="del";if(!k)return;e.preventDefault();e.stopImmediatePropagation();fxAct("fxnk",k)},true);

/* ---------- focus : démarrage immédiat, aperçu de la bande-annonce, accueil Apple TV ---------- */
let fxPT=0,fxTT=0;
{const _sf=setFocus;setFocus=function(el,instant){_sf(el,instant);if(!el)return;
 if(S.modal&&S.modal.type==="fxshelf"&&el.dataset.app&&FXS.hsel!==el.dataset.app){FXS.hsel=el.dataset.app;render(el.dataset.fid);return}
 const w=view.querySelector(fxQ("W"));if(!w)return;const on=el.dataset.fid==="w-tr";w.classList.toggle("peek",on);const c=$("#tchip");if(c&&!S.modal){if(on){c.classList.add("on");c.innerHTML=fxC(tchipIn(3));const a=w.querySelector(fxQ("hero")+" "+fxQ("art"));if(a)a.classList.add("play")}else if(c.querySelector(".v3"))c.innerHTML=fxC(tchipIn(1))}
 clearTimeout(fxPT);const t=topS();if(el.dataset.fid==="w-play"&&t.t==="detail"&&FXS.ready!==t.id&&!S.modal){fxPT=setTimeout(()=>{if(F!==el||S.modal||topS()!==t)return;FXS.ready=t.id;el.classList.add("ready");const sv=el.querySelector("svg");if(sv)sv.outerHTML='<span class="pzap">⚡</span>'},2000)}}}
{const _r=render;render=function(fid){_r(fid);const sc=view.querySelector("#fxscr");if(!sc)return;const go=()=>sc.style.setProperty("--p",Math.min(1,sc.scrollTop/560).toFixed(3));sc.addEventListener("scroll",go,{passive:true});go();
 clearTimeout(fxTT);fxTT=setTimeout(()=>{const a=sc.querySelector(fxQ("hero")+" "+fxQ("art")),c=$("#tchip");if(a&&!S.modal&&topS().t==="detail"){a.classList.add("play");if(c)c.classList.add("on")}},2500)}}

/* ---------- avatar du profil dans la barre d'onglets ---------- */
{const _tb=tabbar;tabbar=function(){const h=_tb();const i=h.lastIndexOf("</div></div>");return h.slice(0,i)+`<div class="tab ic whotab" data-f data-fid="tab-who" data-row="tabs" data-act="fxwho" aria-label="Profil">${fxC(FXS.duo?FXS.duo.map(id=>pav(id,"tb")).join(""):pav(PR.cur,"tb"))}</div>`+h.slice(i)}}
/* ---------- affiches TMDB partout dans l'appli ---------- */
{const _po=poster;poster=function(it,nw){if(!it||!it.po)return _po(it,nw);return `<div class="pst pimg" style="background-image:url(${it.po}),linear-gradient(160deg,${it.c[0]},${it.c[1]})"><div class="pst-in">${nw?'<span class="newb">Ajouté récemment</span>':""}</div></div>`}}
/* ---------- ouverture : « Qui regarde ? » ---------- */
if(inApp()&&PR.ask&&Object.keys(PR.list).length>1)S.modal={type:"fxwhofull"};
