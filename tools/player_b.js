/* ===================== Lecteur à panneau latéral (maquette B v2) · films, séries, TV en direct =====================
   ↑ depuis la barre : raccourcis appris (3) · ↑ encore : panneau complet · ← au bord ou Retour : ferme
   ↓ depuis la barre : boutons du moment (Qu'a-t-il dit ?, Épisode suivant, Reprendre au début, Revenir au direct)
   Retour : cache les infos ; TV : 2ᵉ Retour rapide = chaîne précédente ; Retour maintenu = quitter le lecteur
   ⏯ : pause (TV : pause du direct jusqu'à 30 min) · mémoire du panneau, Image et Son de nuit par film / série / chaîne et par profil */
(()=>{
const SE=(s,e)=>`S${s} · É${e}`;
const PB_ON=()=>topS().t==="player"&&P&&inApp();
const KIND=()=>P.kind==="live"?"tv":(ALL[P.id]&&ALL[P.id].type==="s")?"serie":"film";
const CK=()=>curKey();
const B={panel:null,sub:null,subFrom:null,memHit:false,season:null,lastBack:0,zapT:0};
function PBD(){const p=ME();p.pb=p.pb||{};const d=p.pb;d.use=d.use||{film:{Audio:5,"Sous-titres":3,Version:2},serie:{"Sous-titres":4,Audio:2,Version:1},tv:{Source:4,Audio:1,"Son de nuit":1}};d.mem=d.mem||{};d.img=d.img||{};d.night=d.night||{};return d}
const SK={film:["Audio","Sous-titres","Version","Image","Son de nuit"],serie:["Audio","Sous-titres","Version","Image","Son de nuit"],tv:["Source","Audio","Sous-titres","Image","Son de nuit"]};
const SKI={Audio:"au","Sous-titres":"st",Version:"ve",Source:"sr",Image:"im","Son de nuit":"nu"};
const ICO={
 au:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4"/></svg>',
 st:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M7 13h4M13 13h4M7 16h7"/></svg>',
 ve:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 3 8l9 5 9-5z"/><path d="m3 13 9 5 9-5"/></svg>',
 sr:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0"/><circle cx="12" cy="19.5" r="1"/></svg>',
 im:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8V4h4M16 4h4v4M20 16v4h-4M8 20H4v-4"/></svg>',
 nu:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/></svg>',
 all:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="4" width="18" height="6" rx="2"/><rect x="3" y="14" width="18" height="6" rx="2"/></svg>',
 back:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v4h4"/></svg>',
 next:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 5l8 7-8 7z"/><path d="M14 5l8 7-8 7z"/></svg>',
 ck:'<svg class="ck" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5 10 17.5 19 7"/></svg>'};
const NIGHT=["Auto après l'heure du coucher","Toujours","Jamais"];
const bedM=()=>{const b=ME().bed;return b==null?23*60:b};
const nightMode=()=>{const v=PBD().night[CK()];return v!=null?v:(window.saNight?saNight():0)};
const nightOn=()=>{const m=nightMode();if(m===1)return true;if(m===2)return false;const n=nowMin()%1440,b=bedM()%1440;return n>=b||n<300};
const effFmt=()=>PBD().img[CK()]||S.set.fmt||"auto";
const fmtName=k=>(FMTS.find(f=>f[0]===k)||FMTS[0])[1];
const optH=(fid,a,lab,sm,on)=>`<div class="pb-opt ${on?"on":""}" data-f data-fid="${fid}" data-act="${a}" ${on?"data-default":""}><span class="l">${esc(lab)}</span>${sm?`<small>${esc(sm)}</small>`:""}${on?ICO.ck:'<span class="ck"></span>'}</div>`;
const chipH=(fid,a,lab,sel,ex="")=>`<span class="pb-chip ${sel?"sel":""}" data-f data-fid="${fid}" data-act="${a}" ${ex}>${esc(lab)}</span>`;
const rowH=(fid,a,ic,lab,val,ex="")=>`<div class="pb-row" data-f data-fid="${fid}" data-act="${a}" ${ex}>${ic}<div class="tx"><b>${esc(lab)}</b><small>${esc(val)}</small></div><span class="ar">›</span></div>`;
function valOf(key){if(key==="Audio")return shortAudio();if(key==="Sous-titres")return curSub()||"Désactivés";if(key==="Version"||key==="Source")return srcShort();if(key==="Image")return fmtName(effFmt());if(key==="Son de nuit")return (nightMode()===0?"Auto après "+fmt(bedM()):NIGHT[nightMode()])+(nightOn()?" · actif":"");return ""}
const topKeys=()=>{const u=PBD().use[KIND()]||{};return SK[KIND()].slice().sort((a,b)=>(u[b]||0)-(u[a]||0)).slice(0,3)};
const memKey=()=>KIND()+":"+CK();

/* ---------- sous-listes ---------- */
function subList(key){const L=[];
 if(key==="Audio"){const t=tracks();t.au.forEach((x,i)=>L.push(optH("pbs-a"+i,"pb:a:"+i,x.n,x.c,(P.audio||0)===i)));if(!t.au.length)L.push('<div class="pb-hint">Aucune piste audio annoncée par ce flux</div>')}
 else if(key==="Sous-titres"){const t=tracks(),cs=(curSub(),P.sub);L.push(optH("pbs-s-1","pb:s:-1","Désactivés","",cs===-1));t.su.forEach((x,i)=>L.push(optH("pbs-s"+i,"pb:s:"+i,x,"",cs===i)));if(!t.su.length)L.push('<div class="pb-hint">Ce flux n\'a pas de sous-titres</div>')}
 else if(key==="Version"||key==="Source"){srcs(CK()).forEach((v,i)=>L.push(optH("pbs-v"+i,"pb:v:"+v.id,`${v.p.name} · ${v.q}`,compat(v)?((v.audio||[])[0]||"").split(" · ")[0]:"non lisible sur l'Apple TV",v.id===P.src)))}
 else if(key==="Image"){const e=effFmt();FMTS.forEach(([k,n,d])=>L.push(optH("pbs-i"+k,"pb:img:"+k,n,d,k===e)))}
 else if(key==="Son de nuit"){NIGHT.forEach((n,i)=>L.push(optH("pbs-n"+i,"pb:n:"+i,i===0?"Auto après "+fmt(bedM())+" (coucher)":n,"",nightMode()===i)));L.push('<div class="pb-hint">Actif : scènes fortes adoucies, voix mises en avant, heure plus discrète.</div>')}
 return `<div class="pb-k">${esc(key)} · Retour pour revenir</div><div class="pb-list sy ty"><div class="ttrack">${L.join("")}</div></div>`}

/* ---------- contenu du panneau complet ---------- */
function fullBody(){const k=KIND();
 if(B.sub)return subList(B.sub);
 if(k==="film"){const it=ALL[P.id],end=nowMin()+(P.dur-P.pos)/60,late=(end%1440)>bedM()||end>=1440;
  return `<div class="pb-col">${SK.film.map((key,i)=>rowH("pbr"+i,"pb:sub:"+key,ICO[SKI[key]],key,valOf(key),i===0?"data-default":"")).join("")}</div><div class="pb-sep"></div>
   <div class="pb-k">Ce soir</div><div class="pb-txt">Le film finit à <b>${fmt(end%1440)}</b>${late?`, après ton heure de coucher (${fmt(bedM())})`:""}.</div>
   <div class="pb-chips">${chipH("pbc-stop","pb:stopbed",P.stopBed?"✓ Arrêt à "+fmt(bedM()):"Arrêt à "+fmt(bedM()),P.stopBed)}${chipH("pbc-info","pb:info",P.info?"Masquer les infos du flux":"Infos du flux",P.info)}</div>
   ${(it.cast||[]).length?`<div class="pb-sep"></div><div class="pb-k">Casting</div><div class="pb-txt">${it.cast.slice(0,4).map(([a])=>esc(A[a]||"")).filter(Boolean).join(" · ")}</div>`:""}
   <div class="pb-sep"></div><div class="pb-k">Démo</div><div class="pb-chips">${chipH("pbc-end","fxpend","Aller au générique")}${chipH("pbc-sleep","pb:sleepdemo","90 min sans toucher")}</div>`}
 if(k==="serie"){const it=ALL[P.id],X_=window.__sx,E=X_.EPS(it),s=B.season||P.ss,n=E[s-1]||0;
  const eps=Array.from({length:n},(_,i)=>{const e=i+1,I=X_.epInfo(it,s,e),cu=s===P.ss&&e===P.ep;return `<div class="pb-ep ${cu?"cur":""} ${I.seen&&!cu?"vu":""}" data-f data-fid="pbe-${s}-${e}" data-act="pb:ep:${s}-${e}" ${cu?"data-default":""}><i style="--a:${it.c[0]};--b:${it.c[1]};filter:hue-rotate(${I.hue}deg)">${cu?`<em style="width:${P.pos/P.dur*100}%"></em>`:""}</i><div class="tx"><b>${e}. ${esc(I.t)}</b><small class="${I.miss?"ms":""}">${I.miss?"pas encore chez ton fournisseur":cu?"en cours · reste "+Math.max(1,Math.round((P.dur-P.pos)/60))+" min":I.seen?"✓ vu · "+I.d+" min":I.d+" min"}</small></div></div>`}).join("");
  return `<div class="pb-chips">${E.map((c,i)=>c?chipH("pbse"+(i+1),"pb:season:"+(i+1),"Saison "+(i+1),s===i+1):"").join("")}</div>
   <div class="pb-list sy ty grow"><div class="ttrack">${eps||'<div class="pb-hint">Aucun épisode pour cette saison</div>'}</div></div><div class="pb-sep"></div>
   <div class="pb-k">Réglages de cette série</div><div class="pb-chips">${chipH("pbc-au","pb:sub:Audio","Audio : "+shortAudio())}${chipH("pbc-st","pb:sub:Sous-titres","Sous-titres : "+(curSub()||"non"))}${chipH("pbc-ve","pb:sub:Version",srcShort().split(" · ").slice(0,2).join(" · "))}${chipH("pbc-sk","pb:skipauto","Intro passée auto",!!window.__sx.MX().skip[P.id])}${chipH("pbc-lo","pb:last",P.sx&&P.sx.last?"✓ Arrêt après cet épisode":"Arrêt après cet épisode",P.sx&&P.sx.last)}${chipH("pbc-im","pb:sub:Image","Image : "+fmtName(effFmt()))}${chipH("pbc-nu","pb:sub:Son de nuit","Son de nuit : "+(nightOn()?"actif":nightMode()===2?"jamais":"auto"))}</div>
   ${!(typeof REAL!=="undefined"&&REAL)?`<div class="pb-chips">${chipH("pbc-di","pb:demo:intro","Démo : aller à l'intro")}${chipH("pbc-dc","pb:demo:cred","Démo : générique")}${chipH("pbc-sl","pb:sleepdemo","Démo : 90 min sans toucher")}</div>`:""}`}
 const c=CH[P.id],L=pbGenreList(),rec=LS.hist.filter(id=>id!==P.id&&CH[id]).slice(0,3),U=["Favoris",...LGEN].filter(u=>u==="Favoris"||lvis().some(x=>chanGenre(x)===u||pgen(epgAt(x).cur)===u));
 return `${rec.length?`<div class="pb-chips"><span class="pb-k" style="margin:0 4px 0 0">Récentes</span>${rec.map(id=>chipH("pbrc-"+id,"pb:zap:"+id,CH[id].n)).join("")}</div>`:""}
  <div class="pb-chips">${chipH("pbu-all","pb:uni:","Toutes",!P.uni)}${U.map((u,i)=>chipH("pbu"+i,"pb:uni:"+u,u,(P.uni||"")===u)).join("")}</div>
  <div class="pb-list sy ty grow"><div class="ttrack">${L.length?"":`<div class="pb-empty">${P.uni==="Favoris"?"Aucune chaîne en favori pour l'instant":"Aucune chaîne dans « "+esc(P.uni)+" »"}</div>`}${pbWin(L,x=>{const e=epgAt(x),on=x.id===P.id;return `<div class="pb-ch ${on?"cur":""}" data-f data-fid="pbl-${x.id}" data-act="pb:zap:${x.id}" data-pbzap="${x.id}" ${on?"data-default":""}><b class="n">${esc(x.n)}</b><div class="tx"><b>${esc(e.cur.t)}</b><div class="pg"><i style="width:${e.pct}%"></i></div><small>${on?"tu regardes · ":""}${e.next[0]?"ensuite "+fmt(e.next[0].s)+" · "+esc(e.next[0].t):"fin "+fmt(e.cur.e)}</small></div></div>`})}</div></div>
  <div class="pb-chips">${chipH("pbc-sr","pb:sub:Source","Source : "+srcShort().split(" · ").slice(0,2).join(" · "))}${chipH("pbc-au","pb:sub:Audio","Audio : "+shortAudio())}${chipH("pbc-im","pb:sub:Image","Image : "+fmtName(effFmt()))}${chipH("pbc-nu","pb:sub:Son de nuit","Son de nuit : "+(nightOn()?"actif":nightMode()===2?"jamais":"auto"))}</div>
  <div class="pb-hint">↑ ↓ chaînes · ◀ étiquettes · ▶ réglages · Retour ×2 = chaîne précédente</div>`}

/* ---------- écran ---------- */
function specials(base){let o="";const a=base.indexOf('<div class="player">');if(a>=0){const b=base.indexOf('<div class="pframe');if(b>a+20)o+=base.slice(a+20,b)}
 const sx=fxC('<div class="fx sxp">'),i=base.indexOf(sx);if(i>=0){let seg=base.slice(i,base.lastIndexOf("</div>"));seg=seg.replace(new RegExp(fxC('<div class="spv glass">').replace(/[.*+?^${}()|[\]\\]/g,"\\$&")+"[\\s\\S]*?</small></div>"),"");o+=seg}
 return o}
function liveBar(c){const e=epgAt(c),n=nowMin(),lag=(P.lag||0)/60,pos=Math.max(e.cur.s,n-lag),pct=Math.max(0,Math.min(100,(pos-e.cur.s)/(e.cur.e-e.cur.s)*100)),lv=Math.min(100,(n-e.cur.s)/(e.cur.e-e.cur.s)*100);
 return `<div class="pprog"><span>${fmt(e.cur.s)}</span><div class="tr knob pb-lt" data-f data-fid="p-seek" data-act="pb:pp" data-default id="ptr"><b class="buf" style="left:${pct}%;width:${Math.max(0,lv-pct)}%"></b><i id="pbar" style="width:${pct}%"></i></div><span>${fmt(e.cur.e)}</span></div>`}
function chrome(){const k=KIND(),live=k==="tv",it=live?null:ALL[P.id],c=live?CH[P.id]:null,e=live?epgAt(c):null,X_=window.__sx;
 let kick,title,meta;
 if(k==="film"){const v=curVar()||{q:"",p:{name:"—"}};kick=`Film · ${it.y}`;title=it.t;meta=`${v.q==="4K"?"4K HDR":v.q} · ${shortAudio()} · chez ${v.p.name}`}
 else if(k==="serie"){const v=X_.verOf(it,P.ss,P.ep);kick=`${esc(it.t)} · Saison ${P.ss} · Épisode ${P.ep}`;title=X_.EPT(it,P.ss,P.ep);meta=`${v.lang} · ${v.q} · chez ${v.prov}${v.gap?` · épisode absent chez ${v.gap}, pris chez ${v.prov}`:""}`}
 else{kick=`<span class="pb-live ${P.lag||!P.playing?"dif":""}" id="pblive">${liveLbl()}</span> ${esc(c.n)} · canal ${c.num}`;title=e.cur.t;meta=`${srcShort()}${e.next[0]?" · ensuite "+fmt(e.next[0].s)+" "+esc(e.next[0].t):""}`}
 const it2=it||{c:["#333","#111"]};
 const bar=live?liveBar(c):`<div class="pprog"><span id="ptime">${hms(P.pos)}</span><div class="tr knob" data-f data-fid="p-seek" data-act="pb:pp" data-default id="ptr"><i id="pbar" style="width:${P.pos/P.dur*100}%"></i><div class="pthumb" id="pthumb" hidden><div class="pth-img" id="pthimg" style="--a:${it2.c[0]};--b:${it2.c[1]}"><span class="pth-sc" id="pthsc"></span></div><span class="pth-t" id="ptht"></span><span class="pth-d" id="pthd"></span></div></div><span id="prem">−${hms(P.dur-P.pos)}</span></div>`;
 let btn=`<span class="pb-btn" data-f data-fid="pb-wtd" data-act="pb:wtd">${ICO.back}Qu'a-t-il dit ?<small>−10 s + sous-titres</small></span>`;
 if(k==="serie"&&X_.spNextEp(it,P.ss,P.ep))btn+=`<span class="pb-btn" data-f data-fid="pb-next" data-act="p:nextep">${ICO.next}Épisode suivant</span>`;
 if(live){if(P.lag)btn=`<span class="pb-btn" data-f data-fid="pb-golive" data-act="pb:golive">● Revenir au direct</span>`+btn;else if(lcanStart(c))btn=`<span class="pb-btn" data-f data-fid="pb-start" data-act="lstartp">${ICO.back}Reprendre au début</span>`+btn}
 const right=B.panel==="full"?500:B.panel==="mini"?390:56;
 const end=live?`fin ${fmt(e.cur.e)} · ${Math.max(1,Math.round(e.cur.e-nowMin()))} min`:`fin à ${fmt((nowMin()+(P.dur-P.pos)/60)%1440)}`;
 return `<div class="pb-clk ${nightOn()?"dim":""} ${B.panel==="full"?"hid":""}"><b class="clock">${fmt(nowMin())}</b><span>${end}</span>${nightOn()?`<em class="pb-nite">${ICO.nu}Son de nuit · voix renforcées</em>`:""}${typeof lcxHtml==="function"&&live?lcxHtml():""}</div>
 <div class="pb-bl" style="right:${right}px"><div class="pb-kick">${kick}</div><h1>${esc(title)}</h1><div class="pb-meta">${meta}</div>${bar}
  <div class="pb-hint2">${B.panel?"":`↑ raccourcis puis ${k==="tv"?"chaînes":k==="serie"?"épisodes":"tous les réglages"} · ↓ ${live?"direct et ":""}options · ${live?"⏯ pause du direct · Retour ×2 chaîne précédente":"⏯ pause"} · Retour maintenu : quitter</div>`}<div class="pb-acts">${btn}</div></div>`}
const liveLbl=()=>!P.playing?"EN PAUSE":P.lag?"EN DIFFÉRÉ · "+(P.lag<60?Math.round(P.lag)+" s":Math.round(P.lag/60)+" min"):"EN DIRECT";
function panelHtml(){if(!B.panel)return "";const k=KIND();
 if(B.panel==="mini"){const body=B.sub?subList(B.sub):topKeys().map((key,i)=>rowH("pbm"+i,"pb:sub:"+key,ICO[SKI[key]],key,valOf(key),i===0?"data-default":"")).join("")+`<div class="pb-sep"></div>`+rowH("pbm-all","pb:full",ICO.all,k==="tv"?"Chaînes et tout le reste":k==="serie"?"Épisodes et tout le reste":"Tous les réglages","↑ ou OK");
  const an=B.anim;B.anim=false;
  return `<div class="pb-pan mini ${an?"anim":""}" id="pbpanel">${B.sub?"":`<div class="pb-hd"><b>Raccourcis</b><small>appris de tes habitudes</small></div>`}${body}</div>`}
 const title=k==="film"?"Lecture":k==="serie"?"Épisodes":"Maintenant";
 const an=B.anim;B.anim=false;
 return `<div class="pb-pan full ${an?"anim":""}" id="pbpanel"><div class="pb-hd"><b>${title}${B.memHit?' <small>· repris où tu étais</small>':""}</b><b class="clock">${fmt(nowMin())}</b></div>${fullBody()}</div>`}
function zapOv(){const c=CH[P.id],e=epgAt(c),img=typeof imgProg==="function"?imgProg(e.cur):"";
 const an=B.zanim;B.zanim=false;return `<div class="pb-zov ${an?"anim":""}" style="${img?`background-image:linear-gradient(90deg,rgba(0,0,0,.75),rgba(0,0,0,.2)),url(${img})`:`background:radial-gradient(ellipse 60% 70% at 70% 40%,${c.col} 0%,transparent 70%),linear-gradient(135deg,#10141a,#05070a)`}"><div class="pb-k">${esc(c.n)} · canal ${c.num} · image du programme</div><b>${esc(e.cur.t)}</b><div class="pg"><i style="width:${e.pct}%"></i></div><span class="ld"><i></i>Connexion au flux · une seule connexion utilisée</span></div>`}
function pbHtml(base){const k=KIND(),live=k==="tv",it=live?null:ALL[P.id];
 const t=tracks(),fr=t.su.findIndex(x=>/^fran/i.test(x));
 return `<div class="player pbp"><div class="pframe f-${effFmt()}"><div class="vid" style="--c:${live?CH[P.id].col:it.c[0]}"></div><div class="scan"></div></div><div class="wm2">${live?esc(CH[P.id].n)+" · flux simulé":"Lecture simulée · aucun flux réel"}</div>
 ${specials(base)}${live&&Date.now()-B.zapT<1500?zapOv():""}
 ${P.wtd>Date.now()?`<div class="pb-subl">${fr>=0?"[ sous-titres "+esc(t.su[fr])+" pour ce passage ]":"[ pas de sous-titres dans ce flux : retour de 10 s seulement ]"}</div>`:""}
 <div class="pov pb-ov ${P.ui||B.panel?"":"hid"}" id="pov">${!live&&!P.playing?`<div class="ppause">${I.play}</div>`:""}${chrome()}${P.info?infoBox():""}</div>${panelHtml()}</div>`}
{const _ph=playerHtml;playerHtml=function(){const base=_ph();if(!P)return base;try{return pbHtml(base)}catch(e){console.error(e);return base}}}

/* ---------- navigation (même règle que la maquette : ← → restent sur la ligne) ---------- */
const vr=e=>{const r=e.getBoundingClientRect(),sy=e.closest(".sy");if(!sy)return r;const c=sy.getBoundingClientRect(),t=Math.max(r.top,c.top),bt=Math.min(r.bottom,c.bottom);return {left:r.left,right:r.right,top:t,bottom:bt,width:r.width,height:bt-t}};
const sameSy=e=>{const a=F&&F.closest(".sy");return !!a&&e.closest(".sy")===a};
function cands(){const root=B.panel?$("#pbpanel"):view.querySelector(".player");if(!root)return [];return [...root.querySelectorAll("[data-f]")].filter(e=>{if(!B.panel&&e.closest("#pbpanel"))return false;if(e.closest(".hid"))return false;const r=e.getBoundingClientRect();if(!(r.width>0&&r.height>0))return false;return vr(e).height>6||sameSy(e)})}
/* une case d'une liste qui défile compte pour sa partie visible, sauf dans la liste où l'on est déjà (elle défilera) */
const rectOf=e=>sameSy(e)?e.getBoundingClientRect():vr(e);
function pbMove(dir){const cur=F;if(!cur||!view.contains(cur)){const L=cands();if(L[0])setFocus(L[0]);return !!L[0]}
 const L=cands().filter(x=>x!==cur),a=cur.getBoundingClientRect(),ax=a.left+a.width/2,ay=a.top+a.height/2,H=dir==="left"||dir==="right";
 const ov=b=>H?Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top)>Math.min(a.height,b.height)*.35:Math.min(a.right,b.right)-Math.max(a.left,b.left)>Math.min(a.width,b.width)*.2;
 const C=[];for(const e of L){const b=rectOf(e),bx=b.left+b.width/2,by=b.top+b.height/2;let p,s;
  if(dir==="right"){if(b.left<a.right-4&&bx<=ax+4)continue;p=bx-ax;s=Math.abs(by-ay)}
  else if(dir==="left"){if(b.right>a.left+4&&bx>=ax-4)continue;p=ax-bx;s=Math.abs(by-ay)}
  else if(dir==="down"){if(b.top<a.bottom-4&&by<=ay+4)continue;p=by-ay;s=Math.abs(bx-ax)}
  else{if(b.bottom>a.top+4&&by>=ay-4)continue;p=ay-by;s=Math.abs(bx-ax)}
  if(p>0)C.push({e,p,s,o:ov(b)})}
 let pool=C.filter(c=>c.o);if(!pool.length){if(H)return false;pool=C}
 let best=null,bs=1e9;for(const c of pool){const sc=c.o?c.p+c.s*.3:c.p+c.s*2.2;if(sc<bs){bs=sc;best=c.e}}
 if(!best)return false;B.memHit=false;setFocus(best,true);onFoc(best);return true}
let ZT=0;function onFoc(el){clearTimeout(ZT);const id=el.dataset.pbzap;if(id&&P&&P.kind==="live"&&id!==P.id)ZT=setTimeout(()=>{if(F===el&&P&&P.id!==id){pbZap(id);}},1000)}
const fidNow=()=>F&&F.dataset.fid;
function pbRender(fid){render(fid||fidNow())}
function panFocus(fid){render(fid||null);if(fid&&F&&F.dataset.fid===fid&&F.closest("#pbpanel"))return;const el=view.querySelector("#pbpanel [data-default]")||view.querySelector("#pbpanel [data-f]");if(el)setFocus(el,true)}
function openMini(){B.anim=true;B.panel="mini";B.sub=null;P.last=Date.now();panFocus(null)}
function openFull(){B.anim=B.panel!=="mini"||true;B.panel="full";B.sub=null;B.season=null;const m=PBD().mem[memKey()];B.memHit=!!m;panFocus(m||null)}
function closePanel(){if(B.panel==="full"&&!B.sub&&F)PBD().mem[memKey()]=F.dataset.fid;prSave();B.panel=null;B.sub=null;B.memHit=false;render("p-seek")}
function openSub(key){B.subFrom=fidNow();B.sub=key;const u=PBD().use[KIND()];u[key]=(u[key]||0)+1;prSave();panFocus(null)}
function closeSub(){const f=B.subFrom;B.sub=null;panFocus(f)}
function pbZap(id,how){if(!P||P.kind!=="live"||!CH[id]||id===P.id)return;P.prev=P.id;P.id=id;P.src=srcId("ch:"+id);P.audio=0;P.sub=null;P.lag=0;P.playing=true;S.lch=id;lrecord(id);if(typeof lopening==="function")lopening(id);
 B.zapT=Date.now();B.zanim=true;B.memHit=false;pbRender(B.panel?(view.querySelector(`[data-fid="pbl-${id}"]`)?"pbl-"+id:fidNow()):null);setTimeout(()=>{if(P&&PB_ON()&&Date.now()-B.zapT>=1400)pbRender()},1550);if(how==="prev")toast("Chaîne précédente · "+CH[id].n)}
function pbStep(d){const L=lzapList();let i=L.findIndex(c=>c.id===P.id);if(i<0)i=0;pbZap(L[(i+d+L.length)%L.length].id)}
function pbPlay(){if(P.kind==="live"){P.playing=!P.playing;pbRender();if(!P.playing)toast("Direct en pause · gardé jusqu'à 30 min");return}act("p:pp")}
/* la bande « zapping » de l'ancien lecteur n'est plus utilisée : l'image du programme la remplace */
lzapShow=function(){};

/* ---------- actions ---------- */
{const _a=act;act=function(a){if(!a)return;if(!a.startsWith("pb:"))return _a(a);const [,k,v]=a.split(":"),rest=a.split(":").slice(2).join(":");if(!P)return;
 switch(k){
 case "sub":return openSub(rest);
 case "full":return openFull();
 case "pp":return pbPlay();
 case "a":{P.audio=+v;const t=tracks().au[+v];toast("Audio : "+(t?t.n+(t.c?" · "+t.c:""):""));return B.sub?closeSub():pbRender()}
 case "s":{P.sub=+v;toast(+v<0?"Sous-titres désactivés":"Sous-titres : "+tracks().su[+v]);return B.sub?closeSub():pbRender()}
 case "v":{const vv=srcs(CK()).find(x=>x.id===rest);if(!vv)return;if(!compat(vv))return toast("Source non lisible sur ton Apple TV");P.src=rest;S.srcSel[CK()]=rest;save();P.audio=0;P.sub=null;toast(`${P.kind==="live"?"Source":"Version"} : ${vv.p.name} · ${vv.q} · reprise au même endroit`);return closeSub()}
 case "img":PBD().img[CK()]=rest;prSave();toast("Image : "+fmtName(rest)+" · retenu pour "+(P.kind==="live"?"cette chaîne":KIND()==="serie"?"cette série":"ce film"));return closeSub();
 case "n":PBD().night[CK()]=+v;prSave();toast("Son de nuit : "+(+v===0?"auto après "+fmt(bedM()):NIGHT[+v].toLowerCase())+(nightOn()?" · actif maintenant":""));return closeSub();
 case "wtd":{if(P.kind==="live")P.lag=(P.lag||0)+10;else P.pos=Math.max(0,P.pos-10);P.wtd=Date.now()+10000;P.playing=true;toast("−10 s · sous-titres le temps de ce passage");pbRender();setTimeout(()=>{if(P&&PB_ON())pbRender()},10100);return}
 case "golive":P.lag=0;P.playing=true;toast("Retour au direct");return pbRender("p-seek");
 case "zap":return pbZap(rest);
 case "uni":P.uni=rest;return panFocus(fidNow());
 case "season":B.season=+v;return panFocus(fidNow());
 case "ep":{const [s,e]=rest.split("-").map(Number),it=ALL[P.id],X_=window.__sx,I=X_.epInfo(it,s,e);if(I.miss)return toast(`É${e} pas encore chez ton fournisseur`);
  if(s===P.ss&&e===P.ep){B.panel=null;return pbRender("p-seek")}
  Object.assign(P,{ss:s,ep:e,pos:0,playing:true});if(P.sx)Object.assign(P.sx,{phase:"play",intro:false,cd:0});X_.setSp(it,s,e,0);X_.X.cache={};B.panel=null;B.sub=null;
  const vv=X_.verOf(it,s,e);pbRender("p-seek");return toast(`${SE(s,e)} · ${vv.lang} · ${vv.q} · chez ${vv.prov}${vv.gap?" (absent chez "+vv.gap+")":""}`)}
 case "skipauto":{const m=window.__sx.MX();if(m.skip[P.id])delete m.skip[P.id];else m.skip[P.id]=SE(P.ss,P.ep);prSave();toast(m.skip[P.id]?"L'intro sera passée toute seule":"L'intro ne sera plus passée");return pbRender()}
 case "last":if(P.sx){P.sx.last=!P.sx.last;toast(P.sx.last?"☾ prisme s'arrêtera après cet épisode":"Lecture continue")}return pbRender();
 case "stopbed":P.stopBed=!P.stopBed;toast(P.stopBed?"Arrêt à "+fmt(bedM())+", à la fin de la scène en cours":"Arrêt annulé");return pbRender();
 case "info":P.info=!P.info;return pbRender();
 case "demo":{if(!P.sx)return;if(v==="intro"){P.sx.phase="play";P.pos=54;P.sx.intro=false}else{P.sx.phase="play";P.pos=Math.max(0,P.dur-94)}B.panel=null;B.sub=null;return pbRender("p-seek")}
 case "sleepdemo":B.panel=null;B.sub=null;P.kpos=Math.max(0,(P.pos||0)-20*60);S.modal={type:"pbsleep",left:15,ret:"p-seek"};return render(null);
 case "awake":S.modal=null;toast("Bonne séance");return pbRender("p-seek");
 case "sleep":return pbSleep();
 case "sevr":{const s=+v;S.modal=null;const it=ALL[P.id];Object.assign(P,{ss:s,ep:1,pos:0,playing:true});if(P.sx)Object.assign(P.sx,{phase:"play",intro:false,cd:0});window.__sx.setSp(it,s,1,0);pbRender("p-seek");return toast("Lecture · "+SE(s,1))}
 case "sev":{const it=ALL[P.id],m=window.__sx.MX();if(v==="ep"){const i=m.mal.indexOf(it.id);if(i>=0)m.mal.splice(i,1);else m.mal.push(it.id)}else{S.sxAlerts=S.sxAlerts||[];const i=S.sxAlerts.indexOf(it.id);if(i>=0)S.sxAlerts.splice(i,1);else S.sxAlerts.push(it.id)}prSave();save();return render(fidNow())}
 case "sevc":S.modal=null;return back();
 }}}
function pbSleep(){S.modal=null;if(!P)return;P.playing=false;if(P.kind!=="live"){P.pos=P.kpos!=null?P.kpos:P.pos;toast(`Pause · marque-page à ${P.kind==="vod"&&P.sx?SE(P.ss,P.ep)+" · ":""}${hms(P.pos)}, là où tu as arrêté de réagir`)}else toast("Pause · le direct est gardé 30 min");pbRender("p-seek")}

/* ---------- fenêtres : « Tu regardes toujours ? » et fin de saison ---------- */
window.pbSeasonEnd=function(it,nx){if(!P||!P.sx)return false;P.playing=false;S.modal={type:"pbseason",nx:nx?[nx.s,nx.e]:null,ret:"p-seek"};render(null);return true};
{const _m=modalHtml;modalHtml=function(){const m=S.modal;
 if(m&&m.type==="pbsleep")return `<div class="modal"><div class="mbox pb-mdl" style="width:620px;text-align:center"><h2>Tu regardes toujours ?</h2><p class="pb-txt">Aucune touche depuis 90 min. Sans réponse dans <b id="pbsl">${m.left}</b> s, prisme met en pause et garde ta place là où tu as arrêté de réagir.</p><div class="pb-mb"><span class="pb-btn" data-f data-fid="pbs-ok" data-act="pb:awake" data-default>Oui, je regarde</span><span class="pb-btn" data-f data-fid="pbs-no" data-act="pb:sleep">Pause, je reprendrai plus tard</span></div></div></div>`;
 if(m&&m.type==="pbseason"&&P){const it=ALL[P.id],X_=window.__sx,E=X_.EPS(it),s=P.ss,n=E[s-1]||0,I=Array.from({length:n},(_,i)=>X_.epInfo(it,s,i+1)),seen=I.filter(x=>x.seen||(x.s===P.ss&&x.e<=P.ep)).length,mins=I.filter(x=>!x.miss).reduce((a,x)=>a+x.d,0),nx=m.nx,more=E.length>s,tm=it.tmd||{},mx=X_.MX();
  return `<div class="modal"><div class="mbox pb-mdl" style="width:780px"><div class="pb-k">${esc(it.t)} · saison ${s}</div><h2>Saison terminée${nx||!more?", pour l'instant":""}</h2>
  <div class="pb-stats"><div><b>${seen} / ${n}</b><span>épisodes vus</span></div><div><b>${dur(mins)}</b><span>pour toute la saison</span></div><div><b>${(P.sx.binge||0)+1}</b><span>épisode${P.sx.binge?"s":""} ce soir</span></div></div>
  ${nx?`<div class="pb-lr"><div><b>${SE(nx[0],nx[1])} · ${esc(X_.EPT(it,nx[0],nx[1]))}</b><small>pas encore chez ton fournisseur</small></div><span class="pb-btn" data-f data-fid="pbse-ep" data-act="pb:sev:ep" data-default>${mx.mal.includes(it.id)?"✓ Je te préviens":"Préviens-moi quand il arrive"}</span></div>`:""}
  ${more?`<div class="pb-lr"><div><b>Saison ${s+1}</b><small>disponible chez ton fournisseur</small></div><span class="pb-btn" data-f data-fid="pbse-go" data-act="pb:sevr:${s+1}" ${nx?"":"data-default"}>Commencer la saison ${s+1}</span></div>`:`<div class="pb-lr"><div><b>Saison ${s+1}</b><small>${tm.ns&&tm.ns>s?"existe, pas encore chez ton fournisseur":"pas encore annoncée"}</small></div><span class="pb-btn" data-f data-fid="pbse-s" data-act="pb:sev:s" ${nx?"":"data-default"}>${(S.sxAlerts||[]).includes(it.id)?"✓ Je te préviens":"Préviens-moi"}</span></div>`}
  <div class="pb-mb"><span class="pb-btn" data-f data-fid="pbse-r" data-act="pb:sevr:${s}">Revoir depuis l'épisode 1</span><span class="pb-btn" data-f data-fid="pbse-c" data-act="pb:sevc">Fermer</span></div></div></div>`}
 return _m()}}

/* ---------- touches ---------- */
{const _k=key;key=function(k){
 if(!PB_ON())return _k(k);
 if(S.modal){if(S.modal.type==="pbsleep"&&k==="back")return act("pb:awake");if(S.modal.type==="pbseason"&&k==="back")return act("pb:sevc");return _k(k)}
 const sx=P.sx;if(sx&&sx.phase!=="play")return _k(k);
 const live=P.kind==="live";P.idle=0;P.kpos=P.pos;
 if(k==="backhold"){back();return}
 if(k==="home"||k==="mic")return _k(k);
 if(!P.ui&&!B.panel){
  if(live&&(k==="up"||k==="down")){P.last=Date.now();pbStep(k==="up"?-1:1);return}
  /* direct : Retour quitte le lecteur ; deux appuis rapides reviennent à la chaîne précédente */
  if(k==="back"){if(live){clearTimeout(B.backT);if(Date.now()-B.lastBack<650&&P.prev&&CH[P.prev]){B.lastBack=0;pbZap(P.prev,"prev");return}
    B.lastBack=Date.now();if(!(P.prev&&CH[P.prev]))return back();B.backT=setTimeout(()=>{if(PB_ON()&&!S.modal)back()},650);return}back();return}
  if(k==="play"){pbPlay();return}
  if((k==="rw"||k==="ff")&&!live){uiPing();scrubStep(k==="ff"?1:-1);return}
  uiPing();pbRender(F&&view.contains(F)?fidNow():"p-seek");return}
 uiPing();
 if(k==="back"){if(SC.on){endScrub();return}if(B.sub)return closeSub();if(B.panel)return closePanel();P.ui=false;const o=$("#pov");if(o)o.classList.add("hid");B.lastBack=Date.now();return}
 if(k==="play"){pbPlay();return}
 if(k==="menu"){if(B.panel)return closePanel();return openFull()}
 if(k==="rw"||k==="ff"){if(live){if(k==="rw"){if(lcanStart(CH[P.id]))act("lstartp");else toast("Pas de replay pour ce programme")}else if(P.lag)act("pb:golive");return}scrubStep(k==="ff"?1:-1);return}
 const f=fidNow();
 if(SC.on&&k==="ok"){commitScrub();return}
 if(SC.on&&(k==="up"||k==="down"))commitScrub();
 if(f==="p-seek"&&!B.panel){
  if(!live&&(k==="left"||k==="right")){scrubStep(k==="right"?1:-1);return}
  if(live&&(k==="left"||k==="right")){const e=epgAt(CH[P.id]),max=Math.max(0,(nowMin()-e.cur.s)*60);P.lag=Math.max(0,Math.min(max,(P.lag||0)+(k==="left"?60:-60)));if(k==="left"&&P.lag>=max)toast("Début du programme · « Reprendre au début » pour le voir en entier");pbRender("p-seek");return}
  if(k==="up"){openMini();return}}
 if(k==="ok"){if(F&&F.dataset.act)act(F.dataset.act);return}
 if(live&&B.panel==="full"&&!B.sub&&F&&F.dataset.fid&&F.dataset.fid.startsWith("pbl-")&&(k==="left"||k==="right")){
  const t=k==="left"?(view.querySelector('#pbpanel [data-fid^="pbu"].sel')||view.querySelector('#pbpanel [data-fid^="pbu"]')):view.querySelector('#pbpanel [data-fid="pbc-sr"]');if(t){setFocus(t,true);return}}
 if(["up","down","left","right"].includes(k)){if(pbMove(k))return;
  if(k==="up"&&B.panel==="mini"&&!B.sub)return openFull();
  if(k==="left"&&B.panel&&!B.sub)return closePanel();
  if(k==="up"&&!B.panel)return openMini();return}
 return _k(k)}}
/* Retour maintenu (0,6 s) = quitter le lecteur ; Retour court = comportement ci-dessus */
{let bt=0,held=false;
 document.addEventListener("keydown",e=>{if(e.key!=="Escape"&&e.key!=="Backspace")return;if(!PB_ON()||S.modal)return;e.preventDefault();e.stopImmediatePropagation();if(e.repeat)return;held=false;clearTimeout(bt);bt=setTimeout(()=>{held=true;key("backhold")},600)},true);
 document.addEventListener("keyup",e=>{if(e.key!=="Escape"&&e.key!=="Backspace")return;if(!bt)return;clearTimeout(bt);bt=0;if(!held&&PB_ON())key("back");e.stopImmediatePropagation()},true);
 document.addEventListener("pointerdown",e=>{const b=e.target.closest&&e.target.closest('[data-k="back"]');if(!b||!PB_ON()||S.modal)return;e.preventDefault();e.stopImmediatePropagation();held=false;clearTimeout(bt);bt=setTimeout(()=>{held=true;key("backhold")},600);
  const up=()=>{document.removeEventListener("pointerup",up,true);if(!bt)return;clearTimeout(bt);bt=0;if(!held)key("back")};document.addEventListener("pointerup",up,true)},true)}
/* clic : sur l'image, ferme le panneau ; sur un élément du lecteur, le sélectionne et l'active */
view.addEventListener("click",e=>{if(!PB_ON()||S.modal)return;const pan=$("#pbpanel");if(B.panel&&pan&&!pan.contains(e.target)){e.stopImmediatePropagation();closePanel();return}
 const el=e.target.closest("[data-f]");if(!el)return;if(el.dataset.fid==="p-seek"&&P.kind==="vod"){e.stopImmediatePropagation();const r=el.getBoundingClientRect();P.pos=Math.round(Math.max(0,Math.min(1,(e.clientX-r.left)/r.width))*P.dur);uiPing();pbRender("p-seek");return}},true);

/* ---------- horloge : panneau ouvert = infos visibles, pause du direct, sommeil, arrêt au coucher ---------- */
{const _t=tick;tick=function(){if(P&&PB_ON()&&B.panel)P.last=Date.now();_t();if(!P||!PB_ON())return;
 if(P.kind==="live"&&!P.playing){P.lag=(P.lag||0)+1;if(P.lag>=1800){P.playing=true;toast("Pause du direct pleine (30 min) · la lecture reprend")}const l=$("#pblive");if(l){l.textContent=liveLbl();l.classList.add("dif")}}
 if(S.modal&&S.modal.type==="pbsleep"){S.modal.left--;const e=$("#pbsl");if(e)e.textContent=S.modal.left;if(S.modal.left<=0)pbSleep();return}
 if(P.playing&&!S.modal){P.idle=(P.idle||0)+1;if(P.idle>=5400){P.idle=0;P.kpos=P.kpos!=null?P.kpos:P.pos;S.modal={type:"pbsleep",left:15,ret:"p-seek"};render(null)}}
 if(P.stopBed&&P.playing&&nowMin()%1440>=bedM()%1440){P.stopBed=false;P.playing=false;toast("Arrêt à l'heure du coucher · bonne nuit");pbRender("p-seek")}
 const c=view.querySelector(".pb-clk .clock");if(c&&nightOn()!==c.parentElement.classList.contains("dim"))pbRender()}}
/* nouveau lecteur à chaque lecture : panneau fermé */
{const _sp=startPlayer;startPlayer=function(p){B.panel=null;B.sub=null;B.memHit=false;B.season=null;_sp(p);if(p.kind==="live")p.lag=0}}
window.__pb={B,openMini,openFull,closePanel,pbZap,PBD,topKeys,nightOn,effFmt};
})();

/* Liste des chaînes du lecteur : avec des milliers de chaînes, seules ~80 lignes autour de la sélection sont dessinées
   (le reste est un espace vide de la même hauteur). Même apparence, même défilement ; la fenêtre suit la sélection. */
const PBW={rh:0,s:0,e:0,N:0};
function pbWin(L,row){const N=L.length;PBW.N=N;if(N<=120){PBW.s=0;PBW.e=N;PBW.L=null;return L.map(row).join("")}
 const fid=(F&&F.dataset&&F.dataset.fid)||"",id=fid.startsWith("pbl-")?fid.slice(4):P.id;let ci=L.findIndex(x=>x.id===id);if(ci<0)ci=Math.max(0,L.findIndex(x=>x.id===P.id));
 const s=Math.max(0,ci-40),e=Math.min(N,ci+41),rh=PBW.rh||78;PBW.s=s;PBW.e=e;PBW.L=L;
 return `<div class="pb-sp" style="height:${Math.max(0,s*rh)}px;flex:none"></div>${L.slice(s,e).map(row).join("")}<div class="pb-sp" style="height:${Math.max(0,(N-e)*rh)}px;flex:none"></div>`}
function pbWinFix(){const p=view.querySelector(".pb-list.ty");if(!p||!PBW.L)return;const r=p.querySelectorAll(".pb-ch");if(r.length<3)return;const h=r[2].offsetTop-r[1].offsetTop;
 if(h>20&&Math.abs(h-PBW.rh)>1){const old=PBW.rh||78;PBW.rh=h;const sp=p.querySelectorAll(":scope>.ttrack>.pb-sp");if(sp.length===2){const t0=p._ty||0;sp[0].style.height=PBW.s*h+"px";sp[1].style.height=(PBW.N-PBW.e)*h+"px";tySet(p,t0+PBW.s*(h-old),true)}}}
{const _r=render;render=function(fid){const out=_r(fid);if(PBW.L&&topS().t==="player")pbWinFix();return out}}
{const _k=key;key=function(k){const r=_k(k);if(topS().t==="player"&&PBW.L&&F&&F.dataset.fid&&F.dataset.fid.startsWith("pbl-")){const id=F.dataset.fid.slice(4),i=PBW.L.findIndex(x=>x.id===id);
  if(i>=0&&((i-PBW.s<12&&PBW.s>0)||(PBW.e-i<12&&PBW.e<PBW.N))){const p0=view.querySelector(".pb-list.ty"),ty=p0?p0._ty||0:0;render(F.dataset.fid);const p1=view.querySelector(".pb-list.ty");if(p1){tySet(p1,ty,true);if(F)tyFollow(p1,F,true)}}}return r}}
