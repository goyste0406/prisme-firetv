/* ===================== Accueil (maquette validée, novembre 2026) =====================
   Onglet « Accueil » avant Films. Grande affiche à 5 pages (direct si un match passe sur une chaîne favorite, sinon
   reprise), puis En direct · À suivre · Top 10 du moment · Pour toi. Les 10 améliorations validées :
   1 fond et titre qui suivent la sélection · 2 bande-annonce muette après 2,5 s sur la grande affiche · 3 aperçu animé
   des chaînes · 4 l'affiche s'ouvre sur la bonne chose · 5 Ce soir ? avec durées et heures de fin · 6 À suivre trié et
   menu OK maintenu · 7 Résumé 60 s quand le dernier visionnage date de plus de 7 jours · 8 profil enfant ·
   9 Retour revient sur la même carte · 10 squelette puis contenu.
   La page est dessinée à la taille de la maquette (1100 × 620) puis agrandie à l'écran (1280 × 720) : mêmes
   proportions. Toutes les données viennent du simulateur (catalogue, progression, chaînes favorites, guide TV). */
const ACC={hi:0,skel:false,skelDone:false,root:null,prev:null,menu:null,csd:"all",bdKey:"",bdi:0,idleT:0,bandT:0,boot:false,hero:[],it:{}};
const accOn=()=>inApp()&&topS().t==="home"&&S.tab==="accueil"&&!P&&!S.modal;
const ACK=1100/1280;
const ACI={play:'<path d="M7 4.5v15l12-7.5z" fill="currentColor"/>',left:'<path d="M15 5l-7 7 7 7"/>',right:'<path d="M9 5l7 7-7 7"/>',spark:'<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',bolt:'<path d="M13 3L5 13.5h6L10 21l8-10.5h-6z" fill="currentColor" stroke="none"/>',refresh:'<path d="M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5"/>',live:'<circle cx="12" cy="12" r="2.5" fill="currentColor"/><path d="M7 7a7 7 0 0 0 0 10M17 7a7 7 0 0 1 0 10M4 4.5a11 11 0 0 0 0 15M20 4.5a11 11 0 0 1 0 15"/>',flame:'<path d="M12 3c1 4 5 5.5 5 10a5 5 0 0 1-10 0c0-2.5 1.5-3.5 2-5.5 1 1.5 1.5 2 2 2 0-2.5 0-4.5 1-6.5z"/>',heart:'<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.5 4.3 4.3 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>',moon:'<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z"/>',info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',plus:'<path d="M12 5v14M5 12h14"/>',x:'<path d="M6 6l12 12M18 6L6 18"/>',ban:'<circle cx="12" cy="12" r="9"/><path d="M5.8 5.8l12.4 12.4"/>',rewind:'<path d="M11 6L4 12l7 6zM20 6l-7 6 7 6z"/>',eye:'<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>'};
const aic=n=>'<svg class="ac-ic" viewBox="0 0 24 24">'+ACI[n]+'</svg>';
function aglow(c1,c2,x,y){x=x||70;y=y||35;return `<div class="ac-bl" style="background:radial-gradient(circle at ${x}% ${y}%,${c1} 0,${c1}66 14%,transparent 42%),radial-gradient(circle at ${100-x/2}% ${100-y/2}%,${c2}55 0,transparent 55%),linear-gradient(160deg,#141720,#0b0c11)"></div>`}
const aq=s=>view.querySelector(".acc "+s),aqa=s=>[...view.querySelectorAll(".acc "+s)];
const aKid=()=>{const p=ME();return !!(p&&(p.kid||(p.max!=null&&p.max<=10)))};
const aDur=m=>{m=Math.max(1,Math.round(m));return m>=60?Math.floor(m/60)+" h "+String(m%60).padStart(2,"0"):m+" min"};
const aCol=it=>(it&&it.c&&it.c.length?[it.c[0],it.c[1]||it.c[0]]:["#5d8fd6","#1d3a6e"]);
const aChCol=c=>[c.col,c.col];
const aBed=()=>fmt(ME().bed||23*60);
const aSer=()=>window.__sx||null;

/* ---------- les données (toutes issues du simulateur) ---------- */
/* chaînes favorites, ou chaînes jeunesse pour un profil enfant ; programme en cours d'après le guide TV */
function aLive(){const kid=aKid();let L=kid?CHS.filter(c=>c.cat==="jeunesse"):S.favs.filter(k=>k.startsWith("ch:")).map(k=>CH[k.slice(3)]).filter(Boolean);
 return L.filter(c=>srcs("ch:"+c.id).length).map(c=>{const e=epgAt(c),p=e.cur||{};return {c,p,pct:Math.round(e.pct||0)}}).filter(x=>x.p.t)}
const aMatch=x=>/sport/i.test(x.p.g||"")&&/football|rugby|basket|tennis|handball|ligue|match|coupe/i.test(x.p.t||"");
/* À suivre : nouvel épisode d'abord, puis les films en cours, puis les séries ; série terminée ou épisode absent : pas affiché */
function aNext(){const sx=aSer(),out=[],now=Date.now();
 if(sx){for(const it of sx.sUp()){const n=sx.nextEp(it),I=sx.epInfo(it,n.s,n.e);if(!I||I.miss||I.fut)continue;const sp=sx.spOf(it),days=sp&&sp.t?Math.floor((now-sp.t)/864e5):0,left=Math.round((I.d||it.ep||45)*(1-(n.pos||0)));
  const w=I.nw&&sx.WEEK().find(z=>z.id===it.id&&z.s===n.s&&z.e===n.e&&z.j<=0),v=sx.verOf(it,n.s,n.e)||{};
  out.push({k:"s",it,id:it.id,s:n.s,e:n.e,nw:!!I.nw,ago:w?fhAgo(-w.j):"",q:[v.lang,v.q].filter(Boolean).join(" · "),pos:n.pos||0,left,old:days>7&&!I.nw,days,syn:I.syn||it.s||"",act:sx.fMain(it).act})}}
 const F0=Object.keys(S.prog).map(k=>ALL[k]).filter(f=>f&&f.type==="f"&&srcs(f.id).length&&!fxBlocked(f)).map(f=>({k:"f",it:f,id:f.id,pos:S.prog[f.id]||0,left:Math.round(f.d*(1-(S.prog[f.id]||0))),syn:f.s||"",act:"fhplay:"+f.id}));
 const nw=out.filter(x=>x.nw),rest=out.filter(x=>!x.nw);
 const L=[...nw,...F0,...rest];
 const lc=(LS.hist||[]).map(id=>CH[id]).find(c=>c&&srcs("ch:"+c.id).length&&(!aKid()||c.cat==="jeunesse"));
 if(lc){const e=epgAt(lc);L.push({k:"c",c:lc,id:"ch-"+lc.id,p:e.cur||{},pct:Math.round(e.pct||0)})}
 return L}
function aTop(){if(aKid())return [];return fhTop().map(x=>x.f).slice(0,10)}
function aFor(){return forYou().filter(o=>!fxBlocked(o.c)).slice(0,10)}
/* grande affiche : 4 · elle s'ouvre sur la bonne chose */
function aHero(){const S1=[],used=new Set(),kid=aKid();
 const m=aLive().find(aMatch);
 const live=m?{k:"live",tag:"EN DIRECT · "+m.c.n.toUpperCase(),tc:"#ff6b60",t:m.p.t,meta:`<span>${esc(m.p.g||"")}</span><span>jusqu'à ${fmt(m.p.e%1440)}</span><span class="ac-pill ac-q">${esc(m.c.q)}</span>`,syn:"Ta chaîne favorite, en direct maintenant.",b:"Regarder",bs:"JUSQU'À "+fmt(m.p.e%1440),c:aChCol(m.c),act:"live:"+m.c.id+":1",ch:m.c}:null;
 const nx=aNext().filter(x=>x.k!=="c"),r=nx.find(x=>x.pos>0)||nx[0];let res=null;
 if(r){const it=r.it,q=r.k==="f"?fxQual(it):"";used.add(it.id);
  res={k:"res",id:it.id,tag:"À REPRENDRE",tc:"#36D5F2",t:it.t,meta:r.k==="f"?`<span>${it.y}</span><span>${aDur(it.d)}</span><span class="ac-star">★ ${it.imdb}</span>${q?`<span class="ac-pill ac-q">${esc(q)}</span>`:""}`:`<span>S${r.s} · É${r.e}</span><span>${aDur(r.left)}</span><span class="ac-star">★ ${it.imdb}</span>`,
   syn:(r.pos>0?`Il te reste ${aDur(r.left)}. `:"")+(r.syn||""),b:r.pos>0?"Reprendre":"Lecture",bs:"FINIT À "+fmt(nowMin()+r.left),c:aCol(it),act:r.act}}
 if(m)S1.push(live);if(res)S1.push(res);
 const ne=nx.find(x=>x.nw&&!used.has(x.id));
 if(ne){const it=ne.it;used.add(it.id);S1.push({k:"new",id:it.id,tag:kid?"NOUVEAU":"NOUVEL ÉPISODE",tc:"#7fb3ff",t:it.t,meta:`<span class="ac-pill ac-pv">${esc(fhProv(it))}</span><span>S${ne.s} · É${ne.e}</span><span>${aDur(ne.left)}</span><span class="ac-star">★ ${it.imdb}</span>`,syn:ne.syn,b:`Lecture S${ne.s} · É${ne.e}`,bs:"FINIT À "+fmt(nowMin()+ne.left),c:aCol(it),act:ne.act})}
 const nwF=fhNew().map(x=>x.f).filter(f=>!used.has(f.id)&&!fxBlocked(f)),ar=nwF.sort((a,b)=>(b.tmd?b.tmd.vc||0:b.imdb*100)-(a.tmd?a.tmd.vc||0:a.imdb*100))[0];
 if(ar){used.add(ar.id);const q=fxQual(ar),d=fhAddDays(ar);S1.push({k:"arr",id:ar.id,tag:kid?"NOUVEAU":"L'ARRIVÉE DE LA SEMAINE",tc:"#f5c766",t:ar.t,meta:`<span class="ac-pill ac-pv">${esc(fhProv(ar))}</span><span>${fhAgo(d)}</span><span>${ar.y}</span><span>${aDur(ar.d)}</span><span class="ac-star">★ ${ar.imdb}</span>${q?`<span class="ac-pill ac-q">${esc(q)}</span>`:""}`,syn:ar.s||"",b:"Lecture",bs:"FINIT À "+fmt(nowMin()+ar.d),c:aCol(ar),act:"fhplay:"+ar.id})}
 const fy=aFor().find(o=>!used.has(o.c.id)&&!S.prog[o.c.id]);
 if(fy){const f=fy.c;used.add(f.id);S1.push({k:"fy",id:f.id,tag:kid?"POUR TOI":"POUR TOI · "+fy.pct+" %",tc:"#7CF0B5",t:f.t,meta:`<span class="ac-pill ac-pv">${esc(fhProv(f))}</span><span>${f.y}</span><span>${aDur(f.d)}</span><span class="ac-star">★ ${f.imdb}</span>`,syn:fy.why?String(fy.why).replace(/<[^>]+>/g,""):(f.s||""),b:"Lecture",bs:"FINIT À "+fmt(nowMin()+f.d),c:aCol(f),act:"fhplay:"+f.id})}
 if(!m&&!res&&!S1.length)return [];
 return S1.slice(0,5)}

/* ---------- dessin ---------- */
const aSec=(ico,h,s,row,inner)=>`<section class="ac-sec" data-sec><h2>${aic(ico)}${h}${s?`<small>${s}</small>`:""}</h2><div class="ac-hs" data-row="${row}">${inner}<span class="ac-sp"></span></div></section>`;
function aSkel(){const r=(w,h,n)=>`<section class="ac-sec"><h2><span class="ac-sk" style="width:140px;height:18px;border-radius:6px"></span></h2><div class="ac-hs">${Array.from({length:n},()=>`<span class="ac-sk" style="width:${w}px;height:${h}px"></span>`).join("")}</div></section>`;return r(257,145,5)+r(257,145,5)+r(128,192,8)}
function aRows(){const kid=aKid(),p=ME(),IT=ACC.it={},now=nowMin();
 const live=aLive(),next=aNext(),top=aTop(),fy=aFor();let h="";
 if(live.length)h+=aSec("live","En direct",kid?"les chaînes de "+esc(p.n):"tes chaînes favorites","acc-live",live.map(x=>{const fid="ac-l-"+x.c.id,c=aChCol(x.c);
  IT[fid]={kind:"live",t:x.p.t,tag:"EN DIRECT · "+x.c.n.toUpperCase(),tc:"#ff6b60",m:`<span>${esc(x.p.g||"")}</span><span>jusqu'à ${fmt(x.p.e%1440)}</span>`,s:"OK : regarder en direct, sur la meilleure source.",c,ch:x.c,act:"live:"+x.c.id+":1"};
  return `<div class="ac-lc ac-live" data-f data-fid="${fid}" data-row="acc-live" data-act="acc">${aglow(c[0],c[1],68,38)}<span class="ac-bdg ac-l ac-ch" style="background:${x.c.col};border:1px solid #ffffff33">${esc(x.c.n)}</span><span class="ac-bdg ac-r ac-live">EN DIRECT</span><span class="ac-pvw"><span class="ac-eq"><i></i><i></i><i></i></span>APERÇU</span><div class="ac-tx"><b>${esc(x.p.t)}</b><small>jusqu'à ${fmt(x.p.e%1440)}</small></div><div class="ac-pg ac-red"><i style="width:${x.pct}%"></i></div></div>`}).join(""));
 if(next.length)h+=aSec("refresh","À suivre","","acc-next",next.map(n=>{const fid="ac-n-"+n.id;
  if(n.k==="c"){const c=aChCol(n.c);IT[fid]={kind:"live",t:n.p.t||n.c.n,tag:"EN DIRECT · "+n.c.n.toUpperCase(),tc:"#ff6b60",m:`<span>chaîne regardée récemment</span>`,s:"",c,ch:n.c,act:"live:"+n.c.id+":1"};
   return `<div class="ac-lc ac-live" data-f data-fid="${fid}" data-row="acc-next" data-act="acc">${aglow(c[0],c[1],70,40)}<span class="ac-bdg ac-l ac-ch" style="background:${n.c.col}">${esc(n.c.n)}</span><span class="ac-bdg ac-r ac-live">EN DIRECT</span><span class="ac-pvw"><span class="ac-eq"><i></i><i></i><i></i></span>APERÇU</span><div class="ac-tx"><b>${esc(n.p.t||"")}</b><small>chaîne regardée récemment</small></div><div class="ac-pg ac-red"><i style="width:${n.pct}%"></i></div></div>`}
  const it=n.it,c=aCol(it),ep=n.k==="s"?`S${n.s} · É${n.e}`:"",q=n.k==="f"?fxQual(it):(n.q||"");
  const sub=n.nw?"nouvel épisode"+(n.ago?" · "+n.ago:""):n.pos>0?`reste ${aDur(n.left)}`:"épisode suivant";const sub2=sub+(n.old?` · vu il y a ${n.days} j`:"");
  IT[fid]={kind:"next",id:it.id,t:it.t,old:n.old,tag:n.nw?"NOUVEL ÉPISODE":(n.old?"À REPRENDRE · RÉSUMÉ 60 S DISPONIBLE":"À REPRENDRE"),tc:n.nw?"#7fb3ff":(n.old?"#B39BFF":"#36D5F2"),m:`${ep?`<span>${ep}</span>`:""}<span>${sub}</span><span>fin à ${fmt(now+n.left)}</span>`,s:n.syn,c,act:n.act,ser:n.k==="s"};
  return `<div class="ac-lc" data-f data-fid="${fid}" data-row="acc-next" data-act="acc">${aglow(c[0],c[1],65,40)}${n.nw?'<span class="ac-bdg ac-l ac-new">NOUVEAU</span>':""}${q?`<span class="ac-bdg ac-r">${esc(q)}</span>`:""}${n.old?`<span class="ac-rsm">${aic("rewind")}Résumé 60 s</span>`:""}<div class="ac-tx">${ep?`<span class="ac-ep">${ep}</span>`:""}<b>${esc(it.t)}</b><small>${sub2}</small></div>${n.pos>0?`<div class="ac-pg"><i style="width:${Math.round(n.pos*100)}%"></i></div>`:""}</div>`}).join(""));
 if(top.length)h+=aSec("flame","Top 10 du moment","","acc-top",top.map((f,i)=>{const fid="ac-t-"+f.id,c=aCol(f);
  IT[fid]={kind:"po",id:f.id,t:f.t,tag:"TOP 10 · N° "+(i+1),tc:"#f5c766",m:`<span>${f.y}</span><span>${aDur(f.d)}</span><span>fin à ${fmt(now+f.d)}</span>`,s:"",c,act:"fxopen:"+f.id};
  return `<div class="ac-t10" data-f data-fid="${fid}" data-row="acc-top" data-act="acc"><span class="ac-n">${i+1}</span><div class="ac-po">${aglow(c[0],c[1],60,30)}<div class="ac-tx"><b>${esc(f.t)}</b><small>${f.y}</small></div></div></div>`}).join(""));
 if(fy.length)h+=aSec("heart","Pour toi, "+esc(p.n),"","acc-fy",fy.map(o=>{const f=o.c,fid="ac-f-"+f.id,c=aCol(f);
  IT[fid]={kind:"po",id:f.id,t:f.t,tag:kid?"POUR TOI":"POUR TOI · "+o.pct+" %",tc:"#7CF0B5",m:`<span>${f.y}</span><span>${aDur(f.d)}</span><span>fin à ${fmt(now+f.d)}</span>`,s:"",c,act:"fxopen:"+f.id};
  return `<div class="ac-po" data-f data-fid="${fid}" data-row="acc-fy" data-act="acc">${aglow(c[0],c[1],60,30)}${kid?"":`<span class="ac-pct">${o.pct} %</span>`}<div class="ac-tx"><b>${esc(f.t)}</b><small>${f.y}</small></div></div>`}).join(""));
 if(!h)h=`<section class="ac-sec"><h2>Rien à afficher pour l'instant</h2><div style="margin:12px 69px;color:#9298A8;font-size:14px">Ajoute une playlist dans Réglages pour remplir l'accueil.</div></section>`;
 return h+'<div style="height:330px"></div>'}
function aHeroInner(h,i,n){if(!h)return `<span class="ac-htag" style="color:#c9ccd6;border-color:#c9ccd688">ACCUEIL</span><div class="ac-htitle">prisme</div><div class="ac-hsyn">Ajoute une playlist dans Réglages pour remplir l'accueil.</div>`;
 return `<span class="ac-htag" style="color:${h.tc};border-color:${h.tc}88;background:${h.tc}1f">${h.k==="live"?aic("live"):aic("spark")}${esc(h.tag)}</span><div class="ac-htitle">${esc(h.t)}</div><div class="ac-hmeta">${h.meta}</div><div class="ac-hsyn">${esc(h.syn||"")}</div>`}
function aPlay(h){return h?aic(h.k==="live"?"live":"play")+`<span><b>${esc(h.b)}</b><small>${h.bs}</small></span>`+(h.k==="live"?"":`<span class="ac-ready">${aic("bolt")}prêt</span>`):aic("play")+`<span><b>Lecture</b><small>AUCUN CONTENU</small></span>`}
const aDots=()=>ACC.hero.length>1?ACC.hero.map((_,k)=>`<i class="${k===ACC.hi?"ac-on":""}"></i>`).join("")+`<span>${ACC.hi+1} / ${ACC.hero.length}</span>`:"";
function accHtml(){const kid=aKid();ACC.hero=aHero();if(ACC.hi>=ACC.hero.length)ACC.hi=0;const h=ACC.hero[ACC.hi];
 if(!ACC.skelDone){ACC.skel=true}
 return `<div class="acc${kid?" ac-kid":""}"><div class="ac-bd"><div></div><div></div></div><div class="ac-band"></div><div class="ac-tr"><span class="ac-eq"><i></i><i></i><i></i></span>BANDE-ANNONCE · son coupé</div>
 <div class="ac-vs"><div style="position:relative"><section class="ac-hero" data-sec><div class="ac-hc">${aHeroInner(h)}<div class="ac-hrow" data-row="acc-hero"><div class="ac-play" data-f data-fid="ac-hplay" data-row="acc-hero" data-act="acc">${aPlay(h)}</div>${kid?"":`<div class="ac-hbtn" data-f data-fid="ac-hcs" data-row="acc-hero" data-act="acc">${aic("moon")}Ce soir ?</div>`}</div><div class="ac-hint">OK maintenu : voir la fiche · ajouter à ma liste</div></div>
 ${ACC.hero.length>1?`<div class="ac-chev" style="left:20px" data-c="-1">${aic("left")}</div><div class="ac-chev" style="right:20px" data-c="1">${aic("right")}</div>`:""}<div class="ac-dots">${aDots()}</div></section>
 <div class="ac-rows">${ACC.skel?aSkel():aRows()}</div></div></div><div class="ac-layer"></div></div>`}

/* ---------- branchement : onglet, page, ouverture sur l'accueil ---------- */
{const _t=tabbar;tabbar=function(){const h=_t();if(!inApp())return h;const i=h.indexOf('data-fid="tab-films"'),j=i<0?-1:h.lastIndexOf("<div",i);if(j<0)return h;
 const sel=S.tab==="accueil";return h.slice(0,j)+`<div class="tab ${sel?"sel":""}" data-f data-fid="tab-accueil" data-row="tabs" data-act="tab:accueil" data-hov="tab:accueil" ${sel?"data-default":""} aria-label="accueil">Accueil</div>`+h.slice(j)}}
{const _h=homeHtml;homeHtml=function(){if(inApp()&&S.tab==="accueil")return tabbar()+accHtml();return _h()}}
/* l'appli s'ouvre sur l'accueil (démarrage, retour depuis l'écran d'accueil de l'Apple TV, changement de profil) */
const accGo=()=>{S.tab="accueil";ACC.hi=0;ACC.skelDone=false;ACC.root=null};
{const _a=act;act=function(a){if(!a)return _a(a);const [k,v]=a.split(":");const from=S.modal&&S.modal.type;
 if(a==="acc")return accOk();
 if(k==="fxhapp"&&v==="prisme")accGo();
 if((k==="fxprof"||k==="fxduo"||k==="whoguest"||k==="whoplay")&&(from==="fxwhofull"||from==="fxwho"||k==="whoguest"||k==="whoplay"))accGo();
 return _a(a)}}

/* ---------- après chaque affichage : focus, fond, squelette ---------- */
{const _r=render;render=function(fid){if(!ACC.boot&&inApp()&&topS().t==="home"&&!S.loading){ACC.boot=true;S.tab="accueil";save()}
 /* un calque ouvert (menu, Ce soir ?) survit à un réaffichage venu d'ailleurs (mise à jour des données…) */
 const L0=ACC.root&&ACC.root.isConnected?{html:ACC.root.innerHTML,fid:F&&F.dataset.fid,prev:ACC.prev,menu:ACC.menu}:null;
 ACC.root=null;clearTimeout(ACC.idleT);const r=_r(fid);
 if(inApp()&&topS().t==="home"&&S.tab==="accueil"&&view.querySelector(".acc")){
  if(L0&&!S.modal){const L=aq(".ac-layer"),root=view.querySelector(".acc");L.innerHTML=L0.html;L.classList.add("ac-open");root.classList.add("ac-lay");ACC.root=L;ACC.prev=L0.prev;ACC.menu=L0.menu;
   const e=L0.fid&&L.querySelector(`[data-fid="${CSS.escape(L0.fid)}"]`);setFocus(e||L.querySelector("[data-f]"),true);return r}
  ACC.bdKey="";const h=ACC.hero[ACC.hi];aBd(h?h.c:["#2b3245","#0a0b10"],"h"+ACC.hi);
  if(!fid&&!S.modal){const hp=aq('[data-fid="ac-hplay"]');if(hp)setFocus(hp,true)}
  if(ACC.skel&&!ACC.skelT){ACC.skelT=setTimeout(()=>{ACC.skelT=0;ACC.skel=false;ACC.skelDone=true;const rw=aq(".ac-rows");if(!rw||!accOnAny())return;rw.innerHTML=aRows();rw.classList.remove("ac-fresh");void rw.offsetWidth;rw.classList.add("ac-fresh")},650)}}
 return r}}
const accOnAny=()=>inApp()&&topS().t==="home"&&S.tab==="accueil"&&!P;
function aBd(c,key){if(ACC.bdKey===key)return;ACC.bdKey=key;const L=aqa(".ac-bd>div");if(L.length<2)return;ACC.bdi=1-ACC.bdi;L[ACC.bdi].innerHTML=aglow(c[0],c[1],68,36);L[ACC.bdi].classList.add("ac-on");L[1-ACC.bdi].classList.remove("ac-on")}
/* 1 · bandeau du titre sélectionné quand on descend dans les rangées */
function aBand(el){const it=el&&ACC.it[el.dataset.fid],b=aq(".ac-band");if(!b)return;if(!it){b.classList.remove("ac-on");return}
 const tc=it.tc||"#c9ccd6";b.innerHTML=`<span class="ac-htag" style="color:${tc};border-color:${tc}88;background:${tc}1f">${esc(it.tag)}</span><div class="ac-bt">${esc(it.t)}</div><div class="ac-bm">${it.m}</div><div class="ac-bs">${esc(it.s||"")}</div>`;
 b.classList.add("ac-on");clearTimeout(ACC.bandT);ACC.bandT=setTimeout(()=>aBd(it.c,"i"+el.dataset.fid),180)}
/* 2 · bande-annonce muette après 2,5 s sans toucher la télécommande (pas pour le direct) */
function aIdle(){clearTimeout(ACC.idleT);const root=view.querySelector(".acc");if(!root)return;root.classList.remove("ac-trailer");const h=ACC.hero[ACC.hi];
 if(F&&F.dataset.fid==="ac-hplay"&&!ACC.root&&h&&h.k!=="live"&&accOn())ACC.idleT=setTimeout(()=>{if(F&&F.dataset.fid==="ac-hplay"&&!ACC.root&&accOn()){root.classList.add("ac-trailer");toast(`Bande-annonce de « ${h.t} » en fond, son coupé`)}},2500)}
{const _sf=setFocus;setFocus=function(el,instant){_sf(el,instant);if(!el||!view.querySelector(".acc")||!accOnAny())return;const root=view.querySelector(".acc");
 const hs=el.closest(".ac-hs");if(hs){const L=el.offsetLeft,Rr=L+el.offsetWidth;let x=hs.scrollLeft;if(Rr>x+hs.clientWidth-69)x=Rr-hs.clientWidth+69;if(L<x+69)x=L-69;hs.scrollTo({left:Math.max(0,x),behavior:instant?"auto":"smooth"})}
 if(ACC.root){return}
 const s=el.closest("[data-sec]"),inRows=!!(s&&!s.classList.contains("ac-hero")),vs=aq(".ac-vs");
 if(el.dataset.row!=="tabs"||!inRows){if(vs)vs.scrollTo({top:inRows?Math.max(0,s.offsetTop-190):0,behavior:instant?"auto":"smooth"})}
 root.classList.toggle("ac-rows",inRows);view.classList.toggle("fhdown",inRows);
 if(inRows)aBand(el);else{const b=aq(".ac-band");if(b)b.classList.remove("ac-on");const h=ACC.hero[ACC.hi];if(h)aBd(h.c,"h"+ACC.hi)}
 aIdle()}}

/* ---------- grande affiche : gauche / droite change de page ---------- */
function aSlide(i,instant){const n=ACC.hero.length;if(n<2)return;ACC.hi=(i+n)%n;const h=ACC.hero[ACC.hi],hc=aq(".ac-hc");if(!hc)return;
 const fill=()=>{const row=hc.querySelector(".ac-hrow");[...hc.children].forEach(c=>{if(!c.classList.contains("ac-hrow")&&!c.classList.contains("ac-hint"))c.remove()});row.insertAdjacentHTML("beforebegin",aHeroInner(h));
  const hp=aq('[data-fid="ac-hplay"]');if(hp)hp.innerHTML=aPlay(h);const d=aq(".ac-dots");if(d)d.innerHTML=aDots();hc.classList.remove("ac-sw")};
 aBd(h.c,"h"+ACC.hi);if(instant)fill();else{hc.classList.add("ac-sw");setTimeout(fill,200)}}

/* ---------- navigation ---------- */
function aPick(d,list,from){const a=from.getBoundingClientRect(),ax=(a.left+a.right)/2,t=10*SCALE;let b=null,bs=1e9;
 for(const x of list){const r=x.getBoundingClientRect();if(!r.width)continue;const cx=(r.left+r.right)/2;let p;
  if(d==="down"){if(r.top<a.bottom-t)continue;p=r.top-a.bottom}else{if(r.bottom>a.top+t)continue;p=a.top-r.bottom}
  const sc=Math.max(0,p)+Math.abs(cx-ax)*.4;if(sc<bs){bs=sc;b=x}}return b}
function aBump(){if(F&&F.animate)F.animate([{translate:"0 0"},{translate:"6px 0"},{translate:"0 0"}],{duration:170})}
const aVis=e=>e.offsetParent!==null;
const aMem=r=>{const id=rowMem[r];const m=id&&view.querySelector(`[data-fid="${CSS.escape(id)}"]`);return m&&aVis(m)?m:null};
function accMv(d){const cur=F;if(!cur)return;const row=cur.dataset.row||"";
 if(ACC.root){const L=[...ACC.root.querySelectorAll("[data-f]")].filter(aVis);
  if(row==="acc-menu"){if(d==="up"||d==="down"){const n=L[L.indexOf(cur)+(d==="down"?1:-1)];return n?setFocus(n):aBump()}return aBump()}
  const RL=L.filter(x=>x.dataset.row===row),i=RL.indexOf(cur);
  if(d==="left"||d==="right"){const n=RL[i+(d==="right"?1:-1)];return n?setFocus(n):aBump()}
  const t=aPick(d,L.filter(x=>x.dataset.row!==row),cur);if(!t)return aBump();const m=aMem(t.dataset.row);return setFocus(m&&ACC.root.contains(m)?m:t)}
 if(row==="tabs"){if(d==="down"){return setFocus(aMem("acc-hero")||aq('[data-fid="ac-hplay"]'))}return false}
 if(row==="acc-hero"&&d==="up"){const m=aMem("tabs");return setFocus(m||view.querySelector('[data-fid="tab-accueil"]'))}
 const L=aqa(`[data-row="${row}"][data-f]`).filter(aVis),i=L.indexOf(cur);
 if(d==="left"||d==="right"){const n=L[i+(d==="right"?1:-1)];if(n)return setFocus(n);if(row==="acc-hero"){aSlide(ACC.hi+(d==="right"?1:-1));aIdle();return}return aBump()}
 const C=aqa("[data-f]").filter(x=>x.dataset.row!==row&&aVis(x)),t=aPick(d,C,cur);if(!t)return aBump();
 const r2=t.dataset.row,m=r2!=="acc-hero"&&aMem(r2);setFocus(m||t)}
function accOk(){const c=F;if(!c)return;if(ACC.root&&!ACC.root.contains(c))return;const fid=c.dataset.fid||"";
 if(fid==="ac-hplay"){const h=ACC.hero[ACC.hi];clearTimeout(ACC.idleT);if(!h)return;return act(h.act)}
 if(fid==="ac-hcs")return aCeSoir();
 if(fid.startsWith("ac-m-"))return aMenuDo(fid.slice(5));
 if(fid.startsWith("ac-c-")){ACC.csd=c.dataset.v;const b=aq("#ac-csb");if(b){b.innerHTML=aCsHtml();setFocus(b.querySelector(".ac-chip.ac-on"))}return toast("Films proposés : "+aqa("#ac-csb .ac-po").length)}
 if(fid.startsWith("ac-p-")){const id=fid.slice(5);aClose(true);return act("fxopen:"+id)}
 const it=ACC.it[fid];if(it)return act(it.act)}
function accBack(){if(ACC.root){aClose();return true}if(F&&F.dataset.row==="tabs")return false;const vs=aq(".ac-vs");if(vs)vs.scrollTo({top:0,behavior:"smooth"});setFocus(view.querySelector('[data-fid="tab-accueil"]'));toast("Retour : barre du haut");return true}

/* ---------- calques : menu OK maintenu, Ce soir ? ---------- */
function aOpen(html,first){const L=aq(".ac-layer"),root=view.querySelector(".acc");if(!L)return;ACC.prev=F&&F.dataset.fid;L.innerHTML=html;L.classList.add("ac-open");root.classList.add("ac-lay");root.classList.remove("ac-trailer");clearTimeout(ACC.idleT);ACC.root=L;
 setFocus(first?L.querySelector(first):L.querySelector("[data-f]"))}
function aClose(silent){const L=aq(".ac-layer"),root=view.querySelector(".acc");if(L){L.classList.remove("ac-open");L.innerHTML=""}if(root)root.classList.remove("ac-lay");ACC.root=null;
 const p=ACC.prev&&view.querySelector(`[data-fid="${CSS.escape(ACC.prev)}"]`);setFocus(p||aq('[data-fid="ac-hplay"]'),true)}
function accHold(){if(ACC.root)return;const c=F;if(!c)return;const fid=c.dataset.fid||"";
 if(fid==="ac-hplay"){const h=ACC.hero[ACC.hi];if(!h)return;if(h.k==="live")return aMenu(h.t,[["live","Regarder","go"],["heart","Retirer des favoris","unfav"]],{kind:"live",ch:h.ch,act:h.act});
  return aMenu(h.t,[["info","Voir la fiche","fiche"],["plus",isFav(h.id)?"Retirer de ma liste":"Ajouter à ma liste","liste"]],{kind:"hero",id:h.id,t:h.t,act:h.act})}
 const it=ACC.it[fid];if(!it)return toast("Maintiens le clic sur une affiche pour ses options");const o=[];
 if(it.kind==="next"){o.push(["play","Reprendre","go"]);if(it.old)o.push(["rewind","Résumé 60 s","resume60"]);o.push(["info","Voir la fiche","fiche"],["eye","Marquer comme vu","seen"],["x","Retirer d'À suivre","rm"])}
 else if(it.kind==="live"){o.push(["live","Regarder","go"],["heart",isFav("ch:"+it.ch.id)?"Retirer des favoris":"Ajouter aux favoris","unfav"])}
 else o.push(["info","Voir la fiche","fiche"],["plus",isFav(it.id)?"Retirer de ma liste":"Ajouter à ma liste","liste"],["ban","Pas intéressé","nope"]);
 aMenu(it.t,o,{...it,fid})}
function aMenu(title,opts,target){ACC.menu=target;aOpen(`<div class="ac-scrim"></div><div class="ac-menu"><h4>${esc(title)}</h4><div>${opts.map(o=>`<div class="ac-mi" data-f data-fid="ac-m-${o[2]}" data-row="acc-menu" data-act="acc">${aic(o[0])}${o[1]}</div>`).join("")}</div></div>`)}
function aMenuDo(v){const t=ACC.menu||{},p=ME(),sx=aSer();
 const reb=(msg,keep)=>{aClose(true);const ret=keep?ACC.prev:null;if(typeof FH!=="undefined")FH.cache={};if(typeof FXS!=="undefined")FXS.cache={};if(sx&&sx.X)sx.X.cache={};if(window.dataChanged)dataChanged();prSave();save();
  const row=t.fid&&(view.querySelector(`[data-fid="${CSS.escape(t.fid)}"]`)||{}).dataset;const L=row&&row.row?aqa(`[data-row="${row.row}"][data-f]`):[],i=L.findIndex(e=>e.dataset.fid===t.fid),nb=L[i+1]||L[i-1];
  render(keep?ret:(nb?nb.dataset.fid:"ac-hplay"));toast(msg)};
 if(v==="go"){aClose(true);return act(t.act)}
 if(v==="fiche"){aClose(true);if(!t.id)return;return act((ALL[t.id]&&ALL[t.id].type==="s")?"open:"+t.id:"fxopen:"+t.id)}
 if(v==="liste"){aClose(true);toggleFav(t.id,t.t);return}
 if(v==="unfav"){aClose(true);toggleFav("ch:"+t.ch.id,t.ch.n);return render(t.fid&&view.querySelector(`[data-fid="${CSS.escape(t.fid)}"]`)?t.fid:"ac-hplay")}
 if(v==="resume60"){aClose(true);if(sx&&t.ser)return sx.sxStart(t.id,{recap:1});return toast(`Résumé 60 s de « ${t.t} » : les épisodes déjà vus, sans rien dévoiler de la suite`)}
 if(v==="nope"){if(sx&&ALL[t.id]&&ALL[t.id].type==="s")sx.MX().no.push(t.id);else p.no.push(t.id);return reb(`Compris : « ${t.t} » ne sera plus proposé à ${p.n}`)}
 if(v==="seen"){if(t.ser&&sx){const x=sx.MX(),it=ALL[t.id],n=sx.nextEp(it),nx=sx.spNextEp(it,n.s,n.e);if(nx&&nx.s)sx.setSp(it,nx.s,nx.e,0);else{x.done.push(t.id);delete x.sp[t.id]}delete S.prog[t.id]}
  else{if(!p.seen.includes(t.id))p.seen.push(t.id);delete S.prog[t.id]}return reb(t.ser?"Épisode marqué comme vu":"Marqué comme vu : retiré d'À suivre")}
 if(v==="rm"){if(t.ser&&sx){const x=sx.MX();delete x.sp[t.id]}delete S.prog[t.id];return reb(`Retiré d'À suivre (pour ${p.n} seulement)`)}}
/* 5 · Ce soir ? */
function aCsHtml(){const n=nowMin(),kid=aKid();let b=ME().bed||23*60;if(b<12*60)b+=1440;const left=kid?60:b-n;const mx=ACC.csd==="all"?999:ACC.csd==="bed"?left:+ACC.csd;
 const L=aFor().filter(o=>o.c.d<=mx);
 return `<div class="ac-chips">${[["all","Peu importe"],["100","Moins de 1 h 40"],["130","Moins de 2 h 10"],["bed","Avant "+aBed()]].map(c=>`<div class="ac-chip${ACC.csd===c[0]?" ac-on":""}" data-f data-fid="ac-c-${c[0]}" data-row="acc-csd" data-act="acc" data-v="${c[0]}">${c[1]}</div>`).join("")}</div><div class="ac-res">${L.length?L.slice(0,6).map(o=>{const f=o.c,c=aCol(f);return `<div class="ac-po" data-f data-fid="ac-p-${f.id}" data-row="acc-csr" data-act="acc">${aglow(c[0],c[1],60,30)}<span class="ac-pct">${o.pct} %</span><span class="ac-end">fin ${fmt(n+f.d)}</span><div class="ac-tx"><b>${esc(f.t)}</b><small>${f.y}</small></div></div>`}).join(""):'<div style="color:#9298A8;padding:40px 0">Aucun film dans ce créneau</div>'}</div>`}
function aCeSoir(){aOpen(`<div class="ac-scrim"></div><div class="ac-cs"><h3>${aic("moon")}Ce soir ?</h3><div class="ac-sub">Il est ${fmt(nowMin())} · l'heure de fin est sur chaque affiche</div><div id="ac-csb">${aCsHtml()}</div></div>`,".ac-chip.ac-on")}

/* ---------- télécommande ---------- */
{const _k=key;key=function(k){
 if(k==="home"&&inApp()&&!S.loading&&!(S.modal&&S.modal.type==="fxshelf")){accGo()}
 if(accOn()&&F&&view.contains(F)){const root=view.querySelector(".acc");if(root&&k!=="ok")root.classList.remove("ac-trailer");
  if(["up","down","left","right"].includes(k)){const r=accMv(k);if(r!==false){if(k!=="ok")aIdle();return}return _k(k)}
  if(k==="ok"){if(F.dataset.act==="acc")return accOk();return _k(k)}
  if(k==="back"){if(accBack())return;return _k(k)}
  if(k==="menu"){if(F.dataset.row==="tabs")return toast("Maintiens le clic sur une affiche pour ses options");return accHold()}
  if(k==="play"){if(ACC.root)return;const it=ACC.it[F.dataset.fid];if(F.dataset.fid==="ac-hplay")return accOk();if(it){if(it.kind==="po"&&it.id)return act("fhplay:"+it.id);return act(it.act)}return}}
 return _k(k)}}
/* clic sur les flèches de la grande affiche */
view.addEventListener("click",e=>{const ch=e.target.closest&&e.target.closest(".acc .ac-chev");if(ch&&accOn()&&!ACC.root){aSlide(ACC.hi+(+ch.dataset.c));aIdle()}});
