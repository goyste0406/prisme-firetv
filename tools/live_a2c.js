/* ===================== TV en direct : version A2C ===================== */
const LGEN=["Cinéma","Séries","Sport","Info","Divertissement","Jeunesse","Découverte"];
const LGC={"Cinéma":"#f59e0b","Séries":"#ec4899","Sport":"#22c55e","Info":"#3b82f6","Divertissement":"#a855f7","Jeunesse":"#facc15","Découverte":"#14b8a6","Reprendre":"#e5e7eb","Favoris":"#ff375f"};
const LIC={"Accueil":'<path d="M3.5 11 12 4l8.5 7"/><path d="M6 9.5V20h12V9.5"/><path d="M10 20v-5h4v5"/>',
 "Cinéma":'<path d="M4 5h16v14H4z"/><path d="M8 5v14M16 5v14M4 9h4M4 15h4M16 9h4M16 15h4"/>',"Séries":'<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M8 21h8M9 3l3 3 3-3"/>',
 "Sport":'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5l4 3-1.5 4.5h-5L8 10.5z"/>',"Info":'<path d="M5 5h11v14H6a1 1 0 0 1-1-1z"/><path d="M16 9h3v9a1 1 0 0 1-1 1h-2M8 9h5M8 12h5M8 15h3"/>',
 "Divertissement":'<path d="M12 3l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.4 6.8 19.1l1-5.8L3.5 9.2l5.9-.8z"/>',"Jeunesse":'<circle cx="12" cy="13" r="7"/><circle cx="7" cy="6" r="2.5"/><circle cx="17" cy="6" r="2.5"/><path d="M9.5 15c1.5 1.3 3.5 1.3 5 0"/>',
 "Découverte":'<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.4 3.5 5.3 3.5 8.5s-1 6.1-3.5 8.5c-2.5-2.4-3.5-5.3-3.5-8.5s1-6.1 3.5-8.5z"/>',
 "Reprendre":'<path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v4h4"/><path d="M12 8v4l3 2"/>',"Replay":'<path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v4h4"/><path d="M10 9l5 3-5 3z"/>',"Favoris":'<path d="M12 20s-7-4.4-9-9C1.7 7.8 3.7 4.5 7 4.5c2 0 3.4 1.1 5 3 1.6-1.9 3-3 5-3 3.3 0 5.3 3.3 4 6.5-2 4.6-9 9-9 9z"/>'};
const lsvg=k=>`<svg viewBox="0 0 24 24">${LIC[k]||""}</svg>`;
/* État propre à la TV en direct (mémorisé à part) */
const L0={view:"Accueil",deck:null,hist:["bein1","tf1","f2"],gw:{"Sport":7,"Cinéma":5,"Info":3,"Séries":2,"Divertissement":2,"Découverte":1,"Jeunesse":0},pref:{},seeded:false,direct:{},asked:{},hidden:[],lbest:false,fail:5,loadedAt:null};
let LS=L0;try{const v=JSON.parse(localStorage.getItem("prisme-atv-live")||"null");if(v)LS={...L0,...v,deck:null,view:"Accueil"}}catch(e){}
function lsave(){try{localStorage.setItem("prisme-atv-live",JSON.stringify(LS))}catch(e){}}
/* Genre d'un programme, déduit du guide */
function pgen(p){const g=norm(p.g||"");return /film|cinema|telefilm|movie/.test(g)?"Cinéma":/serie|feuilleton|fiction|drama|soap|sitcom/.test(g)?"Séries":/sport|foot|rugby|tennis|cyclisme|match|basket|golf|moteur|f1/.test(g)?"Sport":/info|journal|politique|debat|actualite|news|meteo/.test(g)?"Info":/dessin|anim|jeunesse|enfant|kids|children|cartoon/.test(g)?"Jeunesse":/docu|decouverte|nature|histoire|science|voyage|animaux/.test(g)?"Découverte":"Divertissement"}
const lvis=()=>chans().filter(c=>!LS.hidden.includes(c.id));
function lNow(g){return lvis().map(c=>({c,e:epgAt(c)})).filter(x=>!g||pgen(x.e.cur)===g).sort((a,b)=>b.e.cur.s-a.e.cur.s)}
function lSoon(g,win=90){const n=nowMin();return lvis().flatMap(c=>epg(c).filter(p=>p.s>n&&p.s<=n+win&&(!g||pgen(p)===g)).map(p=>({c,p}))).sort((a,b)=>a.p.s-b.p.s)}
function deckList(d){if(d==="Reprendre")return LS.hist.filter(id=>CH[id]&&srcs("ch:"+id).length).slice(0,3).map(id=>({c:CH[id],e:epgAt(CH[id])}));
 if(d==="Favoris")return lvis().filter(c=>isFav("ch:"+c.id)).map(c=>({c,e:epgAt(c)}));return lNow(d)}
function deckOrder(){return ["Reprendre","Favoris",...[...LGEN].sort((a,b)=>(LS.gw[b]||0)-(LS.gw[a]||0))].filter(d=>deckList(d).length)}
const since=p=>{if(p.e-p.s>600)return "guide non communiqué";const n=nowMin();return p.s<=n?"depuis "+dur(Math.max(1,Math.round(n-p.s))):"dans "+dur(Math.max(1,Math.round(p.s-n)))};
const lbest=key=>{const L=srcs(key).filter(compat);return L[0]};
function lpref(key){const P=LS.pref[key];if(!P)return null;let b=null,n=0;for(const k in P)if(P[k]>n){n=P[k];b=k}return n>=2?srcs(key).find(v=>v.id===b):null}
/* ---------- fragments ---------- */
function lth(c,inner,p){p=p||epgAt(c).cur;const g=pgen(p),h=hash(p.t||c.id)%360,h2=(h+50)%360;
 return `<div class="lth" style="--c:${c.col};--h1:${h};--h2:${h2};--x:${20+hash(p.t||c.id)%55}%"><div class="lart">${lsvg(g)}<span>${esc(p.t||"")}</span></div>${(im=>im?`<img class="limg" src="${esc(im)}" alt="" onerror="this.remove()"><div class="limgs"></div>`:"")(typeof imgProg==="function"?imgProg(p):p.img)}${(lg=>lg?`<span class="llogo li"><img src="${esc(lg)}" alt="${esc(c.n)}"></span>`:`<span class="llogo" style="--c:${c.col}">${esc(c.n)}</span>`)(typeof imgLogo==="function"?imgLogo(c):"")}${inner||""}</div>`}
function lheroHtml(c,p){if(!c)return `<div class="lhero"><h1>Aucune chaîne</h1></div>`;const n=nowMin();p=p||epgAt(c).cur;const past=p.e<=n,on=p.s<=n&&!past,L=srcs("ch:"+c.id),b=lbest("ch:"+c.id),ad=arDays(c);
 return `<div class="k">${past?'<span class="lbd rp">REPLAY</span>':on?'<span class="lbd">EN DIRECT</span>':'<span class="lbd soon">À VENIR</span>'}${esc(c.n.toUpperCase())} · ${esc(pgen(p).toUpperCase())}</div><h1>${esc(p.t)}</h1>
 <div class="m">${fmt(p.s)} – ${fmt(p.e)} · ${past?"diffusé "+lday(p.s)+" · "+dur(Math.round(p.e-p.s)):since(p)+(on?" · reste "+dur(Math.max(1,Math.round(p.e-n))):"")} · ${L.length} source${L.length>1?"s":""}${ad?` · <span class="rpb">↺ Replay ${ad} j</span>`:""}${b?` <span class="qb q${b.q}" style="height:20px;font-size:11px">${b.q}</span>`:""}</div>${on?`<div class="lpb"><i style="width:${Math.round((n-p.s)/(p.e-p.s)*100)}%"></i></div>`:""}`}
function lcard(c,row,soonP){const e=epgAt(c),p=soonP||e.cur,on=!soonP,g=pgen(p);
 return `<div class="lcard" data-f data-fid="${row}-${c.id}${soonP?"-"+p.s:""}" data-row="${row}" data-act="${on?"lp:"+c.id:"lrem:"+c.id+":"+p.s}" data-hov="lp:${c.id}${soonP?":"+p.s:""}" data-lp="${c.id}">${lth(c,`${on?'<span class="lbd">DIRECT</span>':`<span class="lbd soon">${fmt(p.s)}</span>`}${on?`<div class="lpb"><i style="width:${e.pct}%"></i></div>`:""}`,p)}<div class="t">${esc(p.t)}</div><div class="s">${esc(c.n)} · ${since(p)}</div></div>`}
function lsideHtml(){const items=["Accueil","Replay",...LGEN];
 return `<div class="lside" data-col="0">${items.map(k=>`<div class="lsi ${LS.view===k?"sel":""}" data-f data-fid="lsv-${k}" data-row="lside" data-act="lsv:${k}" data-hov="lsv:${k}">${lsvg(k)}<span>${k}</span><small>${k==="Accueil"?lNow().length:k==="Replay"?lPast().length:lNow(k).length}</small></div>`).join("")}</div>`}
function liveHtml(){
 if(!LS.seeded){const x=[...lNow("Sport"),...lNow()].find(y=>srcs("ch:"+y.c.id).length>1);if(x){const k="ch:"+x.c.id;LS.pref[k]={[srcs(k)[1].id]:2};LS.demo=x.c.id}LS.seeded=true;lsave()}
 let main="";
 if(LS.view==="Accueil"){const D=deckOrder();const first=deckList(D[0]||"Sport")[0];
  main=`<div class="lhero" id="lhero">${first?lheroHtml(first.c):""}</div>
  <div class="lh3">Tes paquets<small>rangés selon ce que tu regardes vers ${Math.floor(nowMin()/60)} h · OK pour ouvrir · maintenir pour les options</small></div>
  <div class="ldecks">${D.map((d,i)=>{const L=deckList(d),lays=L.slice(0,3).reverse(),top=L[0];const soon=!["Reprendre","Favoris"].includes(d)&&lSoon(d,10)[0];
   return `<div class="ldk" data-f data-fid="dk-${d}" data-row="dks" data-act="ldeck:${d}" data-hov="ldk:${d}">${lays.map((x,j)=>{const lv=lays.length-j;return `<div class="lay l${lv}">${lth(x.c,lv===1?`<div class="sh"></div><span class="ltag" style="--g:${LGC[d]}">${esc(d.toUpperCase())}</span><div class="tx"><b>${esc(x.e.cur.t)}</b><span>${esc(x.c.n)} · reste ${dur(Math.max(1,Math.round(x.e.cur.e-nowMin())))}</span></div><div class="lpb"><i style="width:${x.e.pct}%"></i></div>`:"")}</div>`}).join("")}
   <div class="lab"><b>${d==="Reprendre"?"↺ Reprendre":esc(d)}</b><span>${d==="Reprendre"?L.length+(L.length>1?" récentes":" récente"):L.length+" en direct"}</span></div>${soon?`<span class="lsoon">${fmt(soon.p.s)} · ${esc(soon.p.t)}</span>`:""}</div>`}).join("")}</div>`}
 else if(LS.view==="Replay"){const P=lPast(),A=lvis().filter(c=>arDays(c)).length;
  if(!A)main=`<div class="lhero" id="lhero"><div class="k"><span class="lbd rp">REPLAY</span></div><h1 style="font-size:32px">Pas de replay chez ton fournisseur</h1><div class="m">Aucune de tes chaînes n'indique d'archive (tv_archive). Le replay apparaîtra ici dès qu'un fournisseur le propose.</div></div>`;
  else{const first=P[0];const G=[["Revoir l'émission en cours depuis le début",lNow().filter(x=>arDays(x.c)&&nowMin()-x.e.cur.s>3).map(x=>({c:x.c,p:x.e.cur}))],...LGEN.map(g=>[g,P.filter(x=>pgen(x.p)===g)])].filter(r=>r[1].length);
   main=`<div class="lhero" id="lhero">${first?lheroHtml(first.c,first.p):""}</div>${G.map(([g,L],i)=>`<section data-anchor><div class="lh3">${esc(g)}<small>${i===0&&g.startsWith("Revoir")?L.length+" en cours":L.length+" · "+A+" chaînes avec replay"}</small></div><div class="lrow sx">${L.slice(0,30).map(x=>lrpCard(x.c,x.p,"rp"+i)).join("")}</div></section>`).join("")}`}}
 else{const g=LS.view,N=lNow(g),Sn=lSoon(g).slice(0,10);const first=N[0];
  main=`<div class="lhero" id="lhero">${first?lheroHtml(first.c):`<h1 style="font-size:30px">Rien en direct en ${esc(g.toLowerCase())}</h1>`}</div>
  <section data-anchor><div class="lh3">En ce moment<small>${N.length} · ${esc(g.toLowerCase())}</small></div><div class="lrow sx">${N.map(x=>lcard(x.c,"gn")).join("")}</div></section>
  <section data-anchor><div class="lh3">Bientôt<small>${Sn.length} dans l'heure et demie · OK pour un rappel</small></div><div class="lrow sx">${Sn.map(x=>lcard(x.c,"gs",x.p)).join("")}</div></section>`}
 let fan="";
 if(LS.deck){const d=LS.deck,L=deckList(d);
  fan=`<div class="lfan"><h2>${lsvg(d)}${d==="Reprendre"?"Reprendre":esc(d)}<small>${d==="Reprendre"?"tes dernières chaînes · reprise sur la même source, sans question":L.length+" en direct"}</small></h2><div class="hint2">OK pour regarder · maintiens le clic (ou M) pour plus d'options · Retour pour refermer</div>
  <div class="lrow sx">${L.map((x,i)=>{const c=x.c,key="ch:"+c.id,ns=srcs(key).length,b=lbest(key),last=pickSrc(key);
   return `<div class="lcard" style="animation-delay:${i*45}ms" data-f data-fid="fc-${c.id}" data-row="fan" data-act="lp:${c.id}" data-hov="lp:${c.id}" data-lp="${c.id}" ${i===0?"data-default":""}>${lth(c,`<span class="lbd">DIRECT</span><div class="lpb"><i style="width:${x.e.pct}%"></i></div>`)}<div class="t">${esc(x.e.cur.t)}</div><div class="s">${d==="Reprendre"&&last?`${esc(c.n)} · reprend en <i class="q${last.q}">${last.q}</i> ${esc(last.p.name)}`:`${esc(c.n)} · ${ns} source${ns>1?"s":""}${b?`<i class="q${b.q}">${b.q}</i>`:""}`}</div></div>`}).join("")}</div>
  <div class="btn lclose" data-f data-fid="fan-close" data-act="lclose">✕ Refermer</div></div>`}
 let bgh=lsideHtml()+`<div class="lmain">${main}</div>`;if(LS.deck)bgh=bgh.replace(/ data-f /g," ");
 return `<div class="lv"><div class="lbgv" id="lbgv">${LBG?lbgInner(CH[LBG]):""}</div>${bgh}${fan}</div>`;
}
/* ---------- fenêtres ---------- */
const LMODAL={
 lctx(){const m=S.modal,c=CH[m.id],e=epgAt(c),n=e.next[0],fav=isFav("ch:"+c.id),k="ch:"+c.id,ps=lpref(k)||lbest(k);
  return `<div class="modal"><div class="lglass lctx"><div class="hd"><span class="llogo" style="--c:${c.col}">${esc(c.n)}</span><div><b>${esc(e.cur.t)}</b><span>${esc(c.n)} · ${srcs(k).length} sources</span></div></div>
  <div class="lci" data-f data-fid="cx-fav" data-act="lcx:fav" data-default><i>${fav?"♥":"♡"}</i>${fav?"Retirer des favoris":"Ajouter aux favoris"}</div>
  ${arDays(c)&&nowMin()-e.cur.s>3?`<div class="lci" data-f data-fid="cx-rs" data-act="lrp:${c.id}:${e.cur.s}"><i>↺</i>Reprendre depuis le début<small>replay · commencé à ${fmt(e.cur.s)}</small></div>`:""}<div class="lci" data-f data-fid="cx-rem" data-act="lcx:rem"><i>🔔</i>Rappel pour la suite<small>${n?fmt(n.s)+" · "+esc(n.t):""}</small></div>
  <div class="lci" data-f data-fid="cx-src" data-act="lcx:src"><i>◎</i>Choisir la source<small>${ps?ps.q+" "+(lpref(k)?"habituelle":"conseillée"):""}</small></div>
  <div class="lci red" data-f data-fid="cx-hide" data-act="lcx:hide"><i>⊘</i>Masquer cette chaîne<small>réaffichable dans Réglages</small></div></div></div>`},
 ldirect(){const m=S.modal,c=CH[m.k.slice(3)],v=srcs(m.k).find(x=>x.id===m.src);
  return `<div class="modal lside-m"><div class="lglass lcardm"><div class="k">MÉMORISER LA SOURCE</div><b class="tt">Toujours ${v.q} · ${esc(v.p.name)} pour ${esc(c.n)} ?</b><p>Tu as choisi cette source 3 fois. prisme peut l'ouvrir directement la prochaine fois, sans te poser la question. Tu pourras changer d'avis dans Réglages.</p>
  <div class="bt"><div class="btn" data-f data-fid="dir-yes" data-act="ldir:yes" data-default>Oui, l'ouvrir directement</div><div class="btn" data-f data-fid="dir-no" data-act="ldir:no">Non</div></div></div></div>`},
 lfail(){const m=S.modal,k="ch:"+P.id,cur=srcs(k).find(x=>x.id===m.from),nx=m.next&&srcs(k).find(x=>x.id===m.next);
  return `<div class="modal lfailm"><div class="lglass lfailb">${nx&&LS.fail?`<div class="ring"><svg viewBox="0 0 86 86"><circle class="bg" cx="43" cy="43" r="38"/><circle class="fg" id="lfring" cx="43" cy="43" r="38" stroke-dasharray="238.8" stroke-dashoffset="${238.8*(1-m.left/m.total)}"/></svg><b id="lfn">${m.left}</b></div>`:""}
  <h3>${esc(cur?cur.name:"La source")} ne répond plus</h3><p>${nx?(LS.fail?`Bascule automatique sur <b>${nx.q} · ${esc(nx.p.name)}</b> dans <span id="lfs">${m.left}</span> s.`:`La bascule automatique est désactivée dans Réglages.`):`Aucune autre source disponible pour ${esc(CH[P.id].n)}.`}</p>
  <div class="bt">${nx?`<div class="btn" data-f data-fid="lf-now" data-act="lfail:now" data-default>${LS.fail?"Basculer maintenant":"Passer sur "+nx.q}</div>`:""}<div class="btn" data-f data-fid="lf-pick" data-act="lfail:pick" ${nx?"":"data-default"}>Choisir une source</div></div></div></div>`},
 lend(){const m=S.modal,c=CH[m.id],p=m.p,on=p.s<=nowMin(),cur=CH[P.id];
  return `<div class="modal lside-m"><div class="lglass lcardm"><div class="k">CE PROGRAMME SE TERMINE DANS 2 MIN · ENSUITE EN ${esc(m.g.toUpperCase())}</div><div class="bd">${lth(c)}<div><b class="tt" style="margin:0 0 4px">${esc(p.t)}</b><span>${esc(c.n)} · ${on?"en cours, "+since(p):"commence "+since(p)}</span></div></div><div class="cd"><i></i></div>
  <div class="bt"><div class="btn" data-f data-fid="end-go" data-act="lend:go" data-default>${on?"▶︎ Regarder":"🔔 Me prévenir"}</div><div class="btn" data-f data-fid="end-stay" data-act="lend:stay">Rester sur ${esc(cur.n)}</div></div></div></div>`}
};
/* Fenêtre de choix de source : met en avant le choix habituel */
{const _mh=modalHtml;modalHtml=function(){let h=_mh();const m=S.modal;if(!m||!m.k||!m.k.startsWith("ch:"))return h;const hp=lpref(m.k);
 if(hp){h=h.replace(/ data-default/g,"").replace(`data-act="msrc:${hp.id}"`,`data-act="msrc:${hp.id}" data-default`).replace(new RegExp(`(data-act="msrc:${hp.id.replace("|","\\|")}"[^>]*>[\\s\\S]*?<div class="mn">[^<]*)`),`$1<i class="hab">TON CHOIX HABITUEL</i>`)}
 return h}}
/* ---------- actions ---------- */
let LFT=null,LET=null;
function lrecord(id){const i=LS.hist.indexOf(id);if(i>=0)LS.hist.splice(i,1);LS.hist.unshift(id);LS.hist=LS.hist.slice(0,8);const g=pgen(epgAt(CH[id]).cur);LS.gw[g]=(LS.gw[g]||0)+1;lsave()}
{const _sp=startPlayer;startPlayer=function(p){_sp(p);if(p.kind==="live")lrecord(p.id)}}
{const _zp=zap;zap=function(d){_zp(d);if(P&&P.kind==="live")lrecord(P.id)}}
function lopen(id){const key="ch:"+id,L=srcs(key);let direct=null;
 if(L.length>1){if(LS.direct[key])direct=L.find(v=>v.id===LS.direct[key]);else if(LS.deck==="Reprendre")direct=pickSrc(key);else if(LS.lbest)direct=lbest(key)}
 if(direct){S.srcSel[key]=direct.id;save();act("live:"+id+":1");toast(LS.direct[key]?`Source habituelle : ${direct.q} · ${direct.p.name}`:LS.deck==="Reprendre"?`Reprise sur ${direct.q} · ${direct.p.name}`:`Meilleure source : ${direct.q} · ${direct.p.name}`);return}
 act("live:"+id)}
function lnextSrc(){const k="ch:"+P.id,cur=srcs(k).find(x=>x.id===P.src);return srcs(k).filter(v=>v.id!==P.src&&compat(v)).sort((a,b)=>((a.p.id===(cur&&cur.p.id))-(b.p.id===(cur&&cur.p.id)))||(qr(b.q)-qr(a.q)))[0]}
function lcutOn(on){const pl=view.querySelector(".player");if(pl)pl.classList.toggle("lcut",on)}
function lFailStart(){clearInterval(LFT);const nx=lnextSrc();S.modal={type:"lfail",from:P.src,next:nx&&nx.id,left:LS.fail||0,total:LS.fail||1,ret:"p-pp"};render(null);lcutOn(true);
 if(nx&&LS.fail)LFT=setInterval(()=>{const m=S.modal;if(!m||m.type!=="lfail"){clearInterval(LFT);lcutOn(false);return}m.left--;const a=$("#lfn"),b=$("#lfs"),r=$("#lfring");if(a)a.textContent=m.left;if(b)b.textContent=m.left;if(r)r.setAttribute("stroke-dashoffset",238.8*(1-m.left/m.total));if(m.left<=0){clearInterval(LFT);lFailSwitch()}},1000)}
function lFailSwitch(){const m=S.modal;if(!m||!m.next)return;const k="ch:"+P.id,old=srcs(k).find(x=>x.id===m.from),nx=srcs(k).find(x=>x.id===m.next);clearInterval(LFT);S.modal=null;P.src=nx.id;S.srcSel[k]=nx.id;save();render("p-pp");uiPing();toast(`Source coupée (${old?old.q+" · "+old.p.name:""}) · bascule sur ${nx.q} · ${nx.p.name}`)}
function lEndStart(){const c=CH[P.id],g=pgen(epgAt(c).cur);const cand=[...lSoon(g,20).map(x=>({c:x.c,p:x.p})),...lNow(g).map(x=>({c:x.c,p:x.e.cur}))].filter(x=>x.c.id!==P.id);
 if(!cand.length){toast("Rien d'autre dans ce genre pour le moment");return}clearTimeout(LET);S.modal={type:"lend",id:cand[0].c.id,p:cand[0].p,g,ret:"p-pp"};render(null);
 LET=setTimeout(()=>{if(S.modal&&S.modal.type==="lend"){S.modal=null;render("p-pp")}},15000)}
function lneedsPlayer(){if(topS().t==="player"&&P&&P.kind==="live")return true;toast("Lance d'abord une chaîne de la TV en direct");return false}
{const _act=act;act=function(a){if(!a)return;const [k,v,w]=a.split(":");
 if(k==="lsv"){if(LS.view!==v){LS.view=v;LS.deck=null;lsave();render("lsv-"+v)}else move("right");return}
 if(k==="ldeck"){LS.deck=v;lsave();const L=deckList(v);render(L[0]?"fc-"+L[0].c.id:"fan-close");return}
 if(k==="lclose"){const d=LS.deck;LS.deck=null;render("dk-"+d);return}
 if(k==="lp"){lopen(v);return}
 if(k==="lrp"){S.modal=null;lreplay(v,+w);return}
 if(k==="lrem"){toast(`Rappel : prisme passera sur ${CH[v].n} à ${fmt(+w)}`);return}
 if(k==="lcx"){const id=S.modal.id,c=CH[id],ret=S.modal.ret;S.modal=null;
  if(v==="fav"){toggleFav("ch:"+id,c.n);render(ret);return}
  if(v==="rem"){const n=epgAt(c).next[0];render(ret);toast(n?`Rappel enregistré : ${n.t} à ${fmt(n.s)}`:"Rappel enregistré");return}
  if(v==="src"){if(srcs("ch:"+id).length<2){render(ret);toast("Une seule source pour cette chaîne");return}S.modal={k:"ch:"+id,ret};render(ret);return}
  if(v==="hide"){LS.hidden.push(id);lsave();if(LS.deck&&!deckList(LS.deck).length)LS.deck=null;const L=LS.deck?deckList(LS.deck):[];render(L[0]?"fc-"+L[0].c.id:"lsv-"+LS.view);toast(`${c.n} masquée · réaffichable dans Réglages`);return}}
 if(k==="ldir"){const m=S.modal;if(v==="yes"){LS.direct[m.k]=m.src;lsave();toast("Mémorisé · modifiable dans Réglages")}S.modal=null;render("p-pp");return}
 if(k==="lfail"){if(v==="now"){lFailSwitch();return}clearInterval(LFT);S.modal={k:"ch:"+P.id,ret:"p-pp"};render(null);return}
 if(k==="lend"){const m=S.modal;clearTimeout(LET);S.modal=null;if(v==="go"){if(m.p.s>nowMin()){render("p-pp");toast(`Rappel : prisme passera sur ${CH[m.id].n} à ${fmt(m.p.s)}`);return}act("zch:"+m.id);lrecord(m.id)}else render("p-pp");return}
 if(k==="lfailset"){const o=[0,2,5,10,20];LS.fail=o[(o.indexOf(LS.fail)+1)%o.length];lsave();render(F.dataset.fid);return}
 if(k==="lbest"){LS.lbest=!LS.lbest;lsave();render(F.dataset.fid);return}
 if(k==="lforget"){const key="ch:"+v;delete LS.direct[key];delete LS.asked[key];delete LS.pref[key];lsave();render(null);toast("Source oubliée");return}
 if(k==="lshow"){LS.hidden=LS.hidden.filter(x=>x!==v);lsave();render(null);toast(`${CH[v].n} réaffichée`);return}
 if(k==="lreload"){lPreload(()=>render("set-lreload"));return}
 if(k==="msrc"&&S.modal&&S.modal.k&&S.modal.k.startsWith("ch:")){const key=S.modal.k;LS.pref[key]=LS.pref[key]||{};LS.pref[key][v]=(LS.pref[key][v]||0)+1;lsave();
  const ask=LS.pref[key][v]>=3&&!LS.direct[key]&&!LS.asked[key];_act(a);if(ask){LS.asked[key]=true;lsave();S.modal={type:"ldirect",k:key,src:v,ret:"p-pp"};render(null)}return}
 _act(a)}}
/* Fenêtres supplémentaires dans le rendu */
{const _r=render;render=function(fid){if(S.modal&&S.modal.type&&LMODAL[S.modal.type]){const m=S.modal;S.modal=null;_r(fid);S.modal=m;view.insertAdjacentHTML("beforeend",LMODAL[m.type]());if(m.type==="lfail")lcutOn(true);const box=view.querySelector(".modal");const el=box.querySelector("[data-default]")||box.querySelector("[data-f]");setFocus(el,true);return}_r(fid);if(LS.deck&&S.tab==="live"&&topS().t==="home")view.querySelectorAll(".tabbar [data-f]").forEach(e=>e.removeAttribute("data-f"))}}
/* Survol : la une suit la sélection, la barre s'ouvre quand on y est */
{const _oh=onHover;onHover=function(h){const [k,v,w]=h.split(":");
 if(k==="lsv"){if(LS.view!==v){LS.view=v;LS.deck=null;lsave();render("lsv-"+v)}return}
 if(k==="ldk"){const x=deckList(v)[0],hr=$("#lhero");if(x&&hr)hr.innerHTML=lheroHtml(x.c);if(x)setBg([x.c.col,"#08080c"]);return}
 if(k==="lp"&&CH[v]){const hr=$("#lhero");const p=w?epg(CH[v]).find(q=>q.s===+w):null;if(hr)hr.innerHTML=lheroHtml(CH[v],p);setBg([CH[v].col,"#08080c"]);S.lch=v;return}
 _oh(h)}}
let LPV=null;
{const _sf=setFocus;setFocus=function(el,inst){_sf(el,inst);const lv=view.querySelector(".lv");if(lv)lv.classList.toggle("open",!!(el&&el.closest(".lside")));
 clearTimeout(LPV);view.querySelectorAll(".lfan .lcard.pv").forEach(x=>x.classList.remove("pv"));if(el&&el.closest(".lfan")&&el.classList.contains("lcard"))LPV=setTimeout(()=>{if(F===el)el.classList.add("pv")},1000)}}
/* Retour : referme l'éventail, puis revient à la barre */
{const _b=back;back=function(){if(!S.modal&&topS().t==="home"&&S.tab==="live"&&inApp()){if(LS.deck){act("lclose");return}
  if(F&&!F.closest(".lside")&&F.dataset.row!=="tabs"){const s=view.querySelector(`[data-fid="lsv-${CSS.escape(LS.view)}"]`);if(s){setFocus(s);return}}}
 _b()}}
/* Menu (maintenir le clic) sur une vignette de la TV en direct */
{const _k=key;key=function(k){if(k==="menu"&&!S.modal&&F&&F.dataset.lp&&topS().t==="home"){S.modal={type:"lctx",id:F.dataset.lp,ret:F.dataset.fid};render(null);return}
 if(S.modal&&S.modal.type==="lfail"&&k==="back"){clearInterval(LFT);S.modal=null;render("p-pp");return}
 _k(k)}}
/* Réglages : section TV en direct */
{const _sh=settingsHtml;settingsHtml=function(){const h=_sh();
 const mem=Object.keys(LS.direct).map(k=>{const c=CH[k.slice(3)],v=srcs(k).find(x=>x.id===LS.direct[k]);return c&&v?`<div class="it tall" data-f data-fid="set-lf-${c.id}" data-act="lforget:${c.id}"><span>${esc(c.n)}<small>Ouvre directement ${v.q} · ${esc(v.p.name)}</small></span><span>Oublier</span></div>`:""}).join("");
 const hab=Object.keys(LS.pref).filter(k=>!LS.direct[k]&&lpref(k)).map(k=>{const c=CH[k.slice(3)],v=lpref(k);return `<div class="it tall" data-f data-fid="set-lp-${c.id}" data-act="lforget:${c.id}"><span>${esc(c.n)}<small>Proposée en premier : ${v.q} · ${esc(v.p.name)} (${LS.pref[k][v.id]} fois)</small></span><span>Oublier</span></div>`}).join("");
 const hid=LS.hidden.map(id=>`<div class="it" data-f data-fid="set-sh-${id}" data-act="lshow:${id}"><span>${esc(CH[id].n)}</span><span>Réafficher</span></div>`).join("");
 const sec=`<section data-anchor><h3>TV en direct</h3><div class="grp">
  <div class="it tall" data-f data-fid="set-lbest" data-act="lbest"><span>Toujours ouvrir la meilleure source<small>Ne plus afficher le choix des sources</small></span>${sw(LS.lbest)}</div>
  <div class="it tall" data-f data-fid="set-lfail" data-act="lfailset"><span>Bascule automatique si la source coupe<small>OK pour changer : désactivée, 2, 5, 10 ou 20 secondes</small></span><span>${LS.fail?LS.fail+" secondes":"Désactivée"}</span></div>
  ${mem||hab?mem+hab:'<div class="it tall"><span>Sources mémorisées<small>prisme te proposera de mémoriser une source après 3 choix identiques</small></span><span>Aucune</span></div>'}
  ${hid||'<div class="it"><span>Chaînes masquées</span><span>Aucune</span></div>'}
  <div class="it tall" data-f data-fid="set-lreload" data-act="lreload"><span>Chaînes et guide préchargés au démarrage<small>${chans().length} chaînes · ${epgCount()} programmes · OK pour recharger</small></span><span>${LS.loadedAt?"à "+LS.loadedAt:"—"}</span></div>
 </div></section>`;
 return h.replace('<section data-anchor><h3>Guide TV (EPG)</h3>',sec+'<section data-anchor><h3>Guide TV (EPG)</h3>')}}
/* Fond : couleur de la chaîne mise en avant */
/* ---------- préchargement au démarrage ---------- */
function lPreload(done){const pls=S.playlists.filter(p=>p.on);const steps=[...pls.map(p=>[p.name,counts(p).c+" chaînes"]),["Guide des programmes",epgCount()+" programmes"],["Logos et affiches","en cache"]];
 S.loading=true;view.insertAdjacentHTML("beforeend",`<div class="lsplash" id="lsplash"><div class="lg"><i></i>prisme</div><div class="bar"><i id="lspb"></i></div><div class="st" id="lsps">Préparation…</div><ul>${steps.map((x,i)=>`<li id="lspl${i}">${esc(x[0])} · ${esc(x[1])}</li>`).join("")}</ul></div>`);
 let i=0;const t=setInterval(()=>{const li=$("#lspl"+i);if(li)li.classList.add("ok");i++;const b=$("#lspb");if(b)b.style.width=Math.round(i/steps.length*100)+"%";const s=$("#lsps");if(s)s.textContent=i<steps.length?"Chargement : "+steps[i][0]+"…":"Tout est prêt";
  if(i>=steps.length){clearInterval(t);setTimeout(()=>{S.loading=false;LS.loadedAt=fmt(nowMin());lsave();const sp=$("#lsplash");if(sp)sp.remove();done()},350)}},360)}
/* ---------- boutons de démo sous la télécommande ---------- */
document.querySelector(".hint").insertAdjacentHTML("afterend",`<div class="ldemo"><span>Démo TV en direct (pendant la lecture d'une chaîne) :</span><button type="button" id="ld-fail">Simuler une coupure de la source</button><button type="button" id="ld-end">Simuler la fin du programme</button></div>`);
$("#ld-fail").addEventListener("click",()=>{if(lneedsPlayer())lFailStart()});
$("#ld-end").addEventListener("click",()=>{if(lneedsPlayer())lEndStart()});
/* Navigation barre ↔ page : la barre et la page ne sont pas alignées, on gère le passage explicitement */
const LMEM={};
{const _sf2=setFocus;setFocus=function(el,inst){_sf2(el,inst);if(el&&el.isConnected&&el.closest(".lmain"))LMEM[LS.view]=el.dataset.fid}}
{const _mv=move;move=function(dir){
 const inLive=S.tab==="live"&&topS().t==="home"&&!S.modal&&!LS.deck&&F&&F.isConnected;
 if(inLive&&dir==="right"&&F.closest(".lside")){const m=view.querySelector(".lmain");const t=(LMEM[LS.view]&&m.querySelector(`[data-fid="${CSS.escape(LMEM[LS.view])}"]`))||m.querySelector("[data-f]");if(t)setFocus(t);return}
 if(inLive&&dir==="left"&&F.closest(".lmain")){const before=F;_mv(dir);if(F===before||(F&&F.closest(".lside"))){const s=view.querySelector(`[data-fid="lsv-${CSS.escape(LS.view)}"]`);if(s)setFocus(s)}return}
 if(inLive&&(dir==="up"||dir==="down")&&F.closest(".lmain")){const sd=[...view.querySelectorAll(".lside [data-f]")];sd.forEach(e=>e.removeAttribute("data-f"));try{_mv(dir)}finally{sd.forEach(e=>e.setAttribute("data-f",""))}return}
 if(inLive&&(dir==="up"||dir==="down")&&F.closest(".lside")){const L=[...view.querySelectorAll(".lside [data-f]")],i=L.indexOf(F),j=i+(dir==="down"?1:-1);if(j>=0&&j<L.length){setFocus(L[j]);return}if(dir==="down")return}
 _mv(dir)}}

/* Vidéo en direct en fond : la chaîne sélectionnée se lance derrière la page après un court instant (une seule connexion) */
let LBG=null,LBGT=null;
function lbgInner(c){return c?`<div class="vid" style="--c:${c.col}"></div><div class="scan"></div><div class="lbgs"></div><span class="lbgtag"><i></i>EN DIRECT · ${esc(c.n)}</span>`:""}
function lbgPlay(id){clearTimeout(LBGT);LBGT=setTimeout(()=>{if(S.tab!=="live"||topS().t!=="home"||!CH[id]||LBG===id)return;LBG=id;const el=$("#lbgv");if(el){el.classList.remove("on");el.innerHTML=lbgInner(CH[id]);requestAnimationFrame(()=>el.classList.add("on"))}},900)}
{const _oh2=onHover;onHover=function(h){_oh2(h);const [k,v,w]=h.split(":");if(k==="lp"&&CH[v]&&!(w&&+w<nowMin()-1))lbgPlay(v);else if(k==="ldk"){const x=deckList(v)[0];if(x)lbgPlay(x.c.id)}}}
{const _r2=render;render=function(fid){_r2(fid);const el=$("#lbgv");if(el&&LBG)el.classList.add("on")}}

/* ===================== Replay (catch-up Xtream : tv_archive) ===================== */
function arDays(c){if(!c)return 0;if(c._real)return c._real.ar||0;return hash(c.id+"#ar")%3?7:0}
function lday(s){const n=nowMin(),d0=Math.floor(n/1440)*0;const dd=Math.floor((s+0)/1440)-Math.floor(n/1440);return (s<0?(s<-1440?"avant-hier":"hier"):"aujourd'hui")+" à "+fmt(s)}
function lPast(){const n=nowMin();return lvis().filter(c=>arDays(c)).flatMap(c=>epg(c).filter(p=>p.e<=n&&p.s>=n-arDays(c)*1440&&p.t!=="Programme non communiqué").map(p=>({c,p}))).sort((a,b)=>b.p.e-a.p.e)}
function lrpCard(c,p,row){const past=p.e<=nowMin();return `<div class="lcard" data-f data-fid="${row}-${c.id}-${Math.round(p.s)}" data-row="${row}" data-act="lrp:${c.id}:${p.s}" data-hov="lp:${c.id}:${p.s}" data-lp="${c.id}">${lth(c,`<span class="lbd rp">${past?"REPLAY":"↺ DÉBUT"}</span>${past?"":`<div class="lpb"><i style="width:${Math.round((nowMin()-p.s)/(p.e-p.s)*100)}%"></i></div>`}`,p)}<div class="t">${esc(p.t)}</div><div class="s">${esc(c.n)} · ${past?lday(p.s):"commencé à "+fmt(p.s)} · ${dur(Math.round(p.e-p.s))}</div></div>`}
function lreplay(id,s){const c=CH[id];const p=epg(c).find(q=>Math.abs(q.s-s)<0.5);if(!c||!p){toast("Programme introuvable");return}
 const rid="rp_"+c.id+"_"+Math.round(p.s+1440*10);
 ALL[rid]={id:rid,type:"f",t:p.t,y:new Date().getFullYear(),d:Math.max(5,Math.round(p.e-p.s)),g:[pgen(p)],cat:[],imdb:0,tmdb:0,age:"Tous publics",dir:"",f:"black",c:[c.col,"#08080c"],s:`Replay de ${c.n}, diffusé ${lday(p.s)}.`,cast:[],rp:{c:c.id,s:p.s,e:p.e}};
 lrecord(c.id);act("play:"+rid);toast(`Replay · ${c.n} · ${p.t}`)}
{const _srcs=srcs;srcs=function(key){if(key.startsWith("rp_")){const it=ALL[key];if(!it)return [];const c=CH[it.rp.c],L0=_srcs("ch:"+c.id),v=L0.find(x=>x.ar)||L0.find(x=>x.p)||{p:S.playlists[0],i:0};return [{id:"rp|0",i:0,p:v.p,q:v.q||"1080p",tag:"VF",name:`Replay ${c.n} · ${fmt(it.rp.s)}${v.name?" · flux "+v.name:""}`,codec:v.codec||"H.264 · 1920×1080",audio:["Français"],subs:["Aucun"],size:"—",ext:"ts"}]}return _srcs(key)}}
{const _su=streamUrl;streamUrl=function(){if(P&&P.kind==="vod"&&String(P.id).startsWith("rp_")){const it=ALL[P.id],c=CH[it.rp.c],s=(curVar()||{}).p||S.playlists[0],u=s.url.replace(/\/+$/,""),d=new Date(Date.now()-(nowMin()-it.rp.s)*60000),z=n=>String(n).padStart(2,"0");
  return `${u}/timeshift/${s.user}/••••/${it.d}/${d.getFullYear()}-${z(d.getMonth()+1)}-${z(d.getDate())}:${z(d.getHours())}-${z(d.getMinutes())}/${1000+c.num}.ts`}return _su()}}
