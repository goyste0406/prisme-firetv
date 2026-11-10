/* ===================== TV en direct : zapping, reprise au début, connexion unique, recherche ===================== */
for(const [k,v] of Object.entries({bgv:true,maxc:1,startAsk:true,q:"",qh:[]}))if(LS[k]===undefined)LS[k]=v;
LIC["Rechercher"]='<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 20.5 20.5"/>';
const lago=p=>Math.round(nowMin()-p.s);
const lcanStart=c=>{const p=epgAt(c).cur;return !!(arDays(c)&&lago(p)>=3&&p.e-p.s<=600&&p.t!=="Programme non communiqué")};

/* ---------- 5 · Connexion unique ---------- */
const LCX={who:null,id:null};let LCXT=null;
function lcxHtml(){const n=LCX.who?1:0,c=CH[LCX.id],lab=!LCX.who?"connexion libre":LCX.who==="apercu"?"aperçu · "+(c?c.n:""):LCX.who==="ouverture"?"ouverture du flux…":"lecture · "+(c?c.n:"");
 return `<span class="lcx ${LCX.who||"free"}" title="Connexions simultanées de ton abonnement"><i></i>${n}/${LS.maxc} · ${esc(lab)}</span>`}
function lcxSet(who,id){LCX.who=who;LCX.id=id||null;document.querySelectorAll(".lcx").forEach(e=>e.outerHTML=lcxHtml())}
function lbgStop(){clearTimeout(LBGT);const was=LBG;LBG=null;const el=$("#lbgv");if(el){el.classList.remove("on");el.innerHTML=""}if(LCX.who==="apercu")lcxSet(null);return was}
{const _bp=lbgPlay;lbgPlay=function(id){if(!LS.bgv){clearTimeout(LBGT);return}clearTimeout(LBGT);LBGT=setTimeout(()=>{if(S.tab!=="live"||topS().t!=="home"||!CH[id]||LBG===id||S.modal)return;
 LBG=id;const el=$("#lbgv");if(el){el.classList.remove("on");el.innerHTML=lbgInner(CH[id]);requestAnimationFrame(()=>el.classList.add("on"))}lcxSet("apercu",id)},900)}}
function lopening(id){lcxSet("ouverture",id);clearTimeout(LCXT);LCXT=setTimeout(()=>{if(P)lcxSet("lecture",P.kind==="live"?P.id:(ALL[P.id]&&ALL[P.id].rp?ALL[P.id].rp.c:null))},700)}

/* ---------- 1 · Zapping ---------- */
function lzapList(){const u=P&&P.uni;let L=[];
 if(u==="Reprendre"||u==="Favoris")L=deckList(u).map(x=>x.c);
 else if(u)L=lvis().filter(c=>chanGenre(c)===u||pgen(epgAt(c).cur)===u).sort((a,b)=>a.num-b.num);
 if(L.length<2||!L.some(c=>c.id===P.id))L=lvis().slice().sort((a,b)=>a.num-b.num);return L}
let LZT=null;
function lgoCh(id,how){if(!P||P.kind!=="live"||!CH[id]||id===P.id)return;P.prev=P.id;P.id=id;P.src=srcId("ch:"+id);P.audio=0;P.sub=null;S.lch=id;lrecord(id);
 P.ui=false;render("p-pp");const o=$("#pov");if(o)o.classList.add("hid");lzapShow(how);lopening(id)}
function lzapRow(c,cls){const e=epgAt(c);return `<div class="lzr ${cls}">${lth(c,"",e.cur).replace('class="lth"','class="lth lzl"')}<div class="tx"><b>${esc(c.n)}</b><span>${esc(e.cur.t)}</span>${cls==="cur"?`<div class="lpb"><i style="width:${e.pct}%"></i></div><small>${fmt(e.cur.s)} – ${fmt(e.cur.e)} · reste ${dur(Math.max(1,Math.round(e.cur.e-nowMin())))}${e.next[0]?` · ensuite ${fmt(e.next[0].s)} ${esc(e.next[0].t)}`:""}</small>`:""}</div>${cls==="cur"&&lcanStart(c)?'<em class="rpb">↺ [ début</em>':""}</div>`}
function lzapShow(how){const pl=view.querySelector(".player");if(!pl||!P)return;const L=lzapList(),i=L.findIndex(c=>c.id===P.id),n=L.length,u=P.uni||"Toutes";
 const pv=L[(i-1+n)%n],nx=L[(i+1)%n];const old=$("#lzap");if(old)old.remove();
 pl.insertAdjacentHTML("beforeend",`<div class="lzap on" id="lzap"><div class="uni" style="--g:${LGC[u]||"#fff"}">${how==="prev"?"⏯ chaîne précédente":esc(u)} · ${i+1}/${n}</div>${n>1?lzapRow(pv,"up"):""}${lzapRow(CH[P.id],"cur")}${n>2?lzapRow(nx,"dn"):""}</div>`);
 clearTimeout(LZT);LZT=setTimeout(()=>{const z=$("#lzap");if(z)z.classList.remove("on")},3500)}
zap=function(d){if(!P||P.kind!=="live")return;const L=lzapList();let i=L.findIndex(c=>c.id===P.id);if(i<0)i=0;lgoCh(L[(i+d+L.length)%L.length].id,"zap")};
{const _sp=startPlayer;startPlayer=function(p){const stopped=lbgStop();if(p.kind==="live"){const c=CH[p.id];
  p.uni=LS.deck&&deckList(LS.deck).some(x=>x.c.id===p.id)?LS.deck:LGEN.includes(LS.view)?LS.view:(chanGenre(c)||pgen(epgAt(c).cur));p.prev=LS.hist.find(id=>id!==p.id&&CH[id])||null}
 _sp(p);lopening(p.kind==="live"?p.id:null);if(stopped&&LS.maxc<2)setTimeout(()=>toast("Aperçu coupé avant l'ouverture : ta connexion unique reste disponible pour la lecture"),400)}}
{const _st=stopPlayer;stopPlayer=function(){_st();clearTimeout(LCXT);lcxSet(null)}}
{const _ph=playerHtml;playerHtml=function(){let h=_ph();if(P.kind!=="live")return h;const c=CH[P.id],pv=P.prev&&CH[P.prev],L=lzapList(),i=L.findIndex(x=>x.id===P.id);
 h=h.replace(/<div class="phint">▲ ▼ changer de chaîne · [^<]*<\/div>/,`<div class="phint">▲ ▼ zapper dans ${esc(P.uni||"toutes les chaînes")} (${i+1}/${L.length}) · ⏯ ${pv?"revenir à "+esc(pv.n):"chaîne précédente"}${lcanStart(c)?" · [ reprendre au début":""} · ☰ infos du flux</div>`);
 h=h.replace('<div class="pbadges">','<div class="pbadges">'+lcxHtml());
 if(lcanStart(c))h=h.replace(/(<div class="prow live-row"><div class="pgrp">)/,`$1${pchip("p-start","lstartp",'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v4h4"/></svg>',"Depuis le début",`commencé à ${fmt(epgAt(c).cur.s)}`)}`);
 return h}}

/* ---------- 2 · Reprendre au début ---------- */
{const _lo=lopen;lopen=function(id,force){const c=CH[id];if(!force&&c&&LS.startAsk&&lcanStart(c)){S.modal={type:"lstart",id,ret:F&&F.dataset.fid};render(null);return}_lo(id)}}
LMODAL.lstart=function(){const m=S.modal,c=CH[m.id],p=epgAt(c).cur,n=nowMin(),a=lago(p),pct=Math.round((n-p.s)/(p.e-p.s)*100),g=pgen(p),beg=["Cinéma","Séries","Découverte","Jeunesse"].includes(g);
 return `<div class="modal lstartm"><div class="lglass lst"><div class="hd">${lth(c,`<span class="lbd">DIRECT</span>`,p)}<div><div class="k">${esc(c.n.toUpperCase())} · ${esc(g.toUpperCase())}</div><b>${esc(p.t)}</b><span>a commencé il y a ${dur(Math.max(1,a))} · replay disponible</span></div></div>
 <div class="tl"><div class="tr"><i style="width:${pct}%"></i><em style="left:${pct}%"></em></div><div class="lb"><span>↺ ${fmt(p.s)} début</span><span>fin ${fmt(p.e)}</span></div><span class="now" style="left:${pct}%;transform:translateX(-${pct>75?92:pct<15?8:50}%)">maintenant · ${fmt(n)}</span></div>
 <div class="bt"><div class="btn" data-f data-fid="st-beg" data-act="lstart:beg" ${beg?"data-default":""}>↺ Depuis le début</div><div class="btn" data-f data-fid="st-live" data-act="lstart:live" ${beg?"":"data-default"}>● Rejoindre le direct</div></div>
 <div class="lnk" data-f data-fid="st-never" data-act="lstart:never">Ne plus demander · toujours le direct</div></div></div>`};

/* ---------- 3 · Recherche ---------- */
const LKEYS="abcdefghijklmnopqrstuvwxyz0123456789".split("");
function lsearch(q){const t=norm(q).trim().split(/\s+/).filter(Boolean);if(!t.length)return null;const ok=s=>{const h=norm(s);return t.every(w=>h.includes(w))},n=nowMin(),V=lvis();
 const ch=V.filter(c=>ok(c.n)).sort((a,b)=>(norm(b.n).startsWith(t[0])-norm(a.n).startsWith(t[0]))||a.num-b.num).slice(0,24);
 const now=V.map(c=>({c,e:epgAt(c)})).filter(x=>ok(x.e.cur.t+" "+(x.e.cur.g||""))).slice(0,24);
 const soon=V.flatMap(c=>epg(c).filter(p=>p.s>n&&p.s<=n+1440&&ok(p.t+" "+(p.g||""))).map(p=>({c,p}))).sort((a,b)=>a.p.s-b.p.s).slice(0,24);
 const past=lPast().filter(x=>ok(x.p.t+" "+(x.p.g||""))).slice(0,24);return {ch,now,soon,past}}
function lsearchMain(){const q=LS.q,r=lsearch(q);
 const kb=LKEYS.map(k=>`<div class="lkey" data-f data-fid="lk-${k}" data-act="lk:${k}">${k}</div>`).join("")+`<div class="lkey w3" data-f data-fid="lk-sp" data-act="lk:sp">espace</div><div class="lkey w2" data-f data-fid="lk-del" data-act="lk:del">⌫</div><div class="lkey w1" data-f data-fid="lk-clr" data-act="lk:clr">✕</div>`;
 let res="";
 if(!r){const recent=LS.hist.filter(id=>CH[id]).slice(0,6).map(id=>CH[id].n),ideas=[...LS.qh,...recent,"Match","Film","Journal","Météo","Ligue 1","Dessin animé"].filter((x,i,a)=>a.findIndex(y=>norm(y)===norm(x))===i).slice(0,12);
  res=`<section data-anchor><div class="lh3">Suggestions<small>${LS.qh.length?"tes dernières recherches et tes chaînes":"tes chaînes récentes et quelques idées"}</small></div><div class="lchips">${ideas.map((x,i)=>`<div class="lchip ${i<LS.qh.length?"h":""}" data-f data-fid="lq-${i}" data-row="lq" data-act="lqs:${esc(x)}">${i<LS.qh.length?"↺ ":""}${esc(x)}</div>`).join("")}</div></section>
  <section data-anchor><div class="lh3">Astuce<small>sur la vraie Apple TV, maintiens le bouton micro de la télécommande et dis « TF1 » ou « Ligue 1 »</small></div></section>`}
 else{const sec=(t,sub,html)=>html?`<section data-anchor><div class="lh3">${t}<small>${sub}</small></div><div class="lrow sx">${html}</div></section>`:"";
  res=sec("Chaînes",r.ch.length+" trouvée"+(r.ch.length>1?"s":""),r.ch.map(c=>lcard(c,"qc")).join(""))+sec("En direct","maintenant",r.now.map(x=>lcard(x.c,"qn")).join(""))+sec("Bientôt","dans les 24 h · OK pour un rappel",r.soon.map(x=>lcard(x.c,"qs",x.p)).join(""))+sec("Replay","déjà diffusé",r.past.map(x=>lrpCard(x.c,x.p,"qr")).join(""));
  if(!res)res=`<div class="lqempty">Rien pour « ${esc(q)} » dans tes chaînes, le guide ou le replay.</div>`}
 return `<div class="lqs"><div class="lqk"><div class="lqbox">${lsvg("Rechercher")}${q?esc(q):'<span class="ph">Chaîne, programme, sport…</span>'}<span class="caret"></span></div><div class="lkb">${kb}</div><div class="lqmic">🎤 Micro de la télécommande : dictée · clavier de l'ordinateur accepté</div></div><div class="lqres sy">${res}<div style="height:30px"></div></div></div>`}
lsideHtml=function(){const items=["Accueil","Rechercher","Replay",...LGEN];
 return `<div class="lside" data-col="0">${items.map(k=>`<div class="lsi ${LS.view===k?"sel":""}" data-f data-fid="lsv-${k}" data-row="lside" data-act="lsv:${k}" data-hov="lsv:${k}">${lsvg(k)}<span>${k}</span><small>${k==="Accueil"?lNow().length:k==="Rechercher"?"":k==="Replay"?lPast().length:lNow(k).length}</small></div>`).join("")}</div>`};
{const _lh=liveHtml;liveHtml=function(){let h;if(LS.view==="Rechercher"){LS.deck=null;h=`<div class="lv"><div class="lbgv" id="lbgv">${LBG?lbgInner(CH[LBG]):""}</div>${lsideHtml()}<div class="lmain lqmain">${lsearchMain()}</div></div>`}else h=_lh();
 return h.replace('<div class="lmain','<div class="lcxw">'+lcxHtml()+'</div><div class="lmain')}}
function lqSave(){const q=LS.q.trim();if(!q)return;LS.qh=[q,...LS.qh.filter(x=>norm(x)!==norm(q))].slice(0,5);lsave()}
function ltype(k){if(k==="sp")LS.q+=" ";else if(k==="del")LS.q=LS.q.slice(0,-1);else if(k==="clr")LS.q="";else LS.q+=k;LS.q=LS.q.slice(0,40);lsave()}

/* ---------- actions ---------- */
{const _act=act;act=function(a){if(!a)return;const i=a.indexOf(":"),k=i<0?a:a.slice(0,i),v=i<0?"":a.slice(i+1);
 if(k==="lstart"){const m=S.modal;S.modal=null;if(v==="never"){LS.startAsk=false;lsave();toast("Ouverture directe en direct · réactivable dans Réglages")}
  render(m.ret);if(v==="beg"){lreplay(m.id,epgAt(CH[m.id]).cur.s);return}lopen(m.id,true);return}
 if(k==="lstartp"){if(!P||P.kind!=="live")return;const id=P.id,s=epgAt(CH[id]).cur.s,ret=(S.stack[S.stack.length-2]||{}).last;stopPlayer();S.stack.pop();render(ret);lreplay(id,s);return}
 if(k==="lk"){ltype(v);render(F&&F.dataset.fid);return}
 if(k==="lqs"){LS.q=v.replace(/&amp;/g,"&");lsave();render("lq-0");const r=view.querySelector(".lqres [data-f]");if(r)setFocus(r);return}
 if(k==="lstartset"){LS.startAsk=!LS.startAsk;lsave();render(F.dataset.fid);return}
 if(k==="lbgv"){LS.bgv=!LS.bgv;lsave();if(!LS.bgv)lbgStop();render(F.dataset.fid);return}
 if(k==="lmaxc"){LS.maxc=LS.maxc%4+1;lsave();render(F.dataset.fid);return}
 if(k==="zch"&&P&&P.kind==="live"){S.modal=null;lgoCh(v,"zap");return}
 if(S.tab==="live"&&LS.view==="Rechercher"&&LS.q.trim()&&/^(lp|lrp|lrem)$/.test(k))lqSave();
 _act(a)}}
/* Touches : ⏯ chaîne précédente, [ reprendre au début, micro → recherche */
{const _k=key;key=function(k){const pl=topS().t==="player"&&P&&P.kind==="live"&&!S.modal;
 if(pl&&(k==="up"||k==="down")){P.last=Date.now();zap(k==="up"?-1:1);return}
 if(pl&&k==="play"){if(P.prev&&CH[P.prev])lgoCh(P.prev,"prev");else toast("Pas encore de chaîne précédente");return}
 if(pl&&k==="rw"){if(lcanStart(CH[P.id]))act("lstartp");else toast("Pas de replay pour ce programme");return}
 if(k==="mic"&&inApp()&&S.tab==="live"&&!S.modal){if(P)stopPlayer();S.stack=[{t:"home"}];LS.view="Rechercher";LS.deck=null;lsave();render("lk-a");toast("🎤 Dis le nom d'une chaîne ou d'un programme (simulé : tape au clavier)");return}
 _k(k)}}
document.addEventListener("keydown",e=>{if(!(inApp()&&S.tab==="live"&&topS().t==="home"&&LS.view==="Rechercher"&&!S.modal&&!S.loading))return;if(e.ctrlKey||e.metaKey||e.altKey)return;
 let k=null;if(/^[a-zA-Z0-9]$/.test(e.key))k=e.key.toLowerCase();else if(/^[àâäéèêëîïôöùûüç]$/i.test(e.key))k=norm(e.key);else if(e.key===" ")k="sp";else if(e.key==="Backspace")k="del";if(!k)return;
 e.preventDefault();e.stopImmediatePropagation();ltype(k);const f=F&&F.dataset.fid;render(f&&view.querySelector(`[data-fid="${CSS.escape(f)}"]`)?f:"lk-"+(k.length===1?k:k))},true);
/* Recherche : ↑ ↓ restent dans la colonne (clavier ou résultats) */
{const _mv=move;move=function(dir){if(S.tab==="live"&&topS().t==="home"&&LS.view==="Rechercher"&&!S.modal&&F&&(dir==="up"||dir==="down")){const col=F.closest(".lqk,.lqres");if(col){const other=view.querySelector(col.classList.contains("lqk")?".lqres":".lqk"),L=[...other.querySelectorAll("[data-f]")];L.forEach(e=>e.removeAttribute("data-f"));try{_mv(dir)}finally{L.forEach(e=>e.setAttribute("data-f",""))}return}}_mv(dir)}}
/* Quitter la TV en direct coupe l'aperçu */
{const _r=render;render=function(fid){_r(fid);if(!(S.tab==="live"&&topS().t==="home")&&LBG&&!P){LBG=null;clearTimeout(LBGT);if(LCX.who==="apercu")lcxSet(null)}}}
/* Réglages */
{const _sh=settingsHtml;settingsHtml=function(){return _sh().replace(/(<div class="it tall" data-f data-fid="set-lfail")/,`<div class="it tall" data-f data-fid="set-lstart" data-act="lstartset"><span>Proposer de reprendre au début<small>quand le programme a commencé et que la chaîne a le replay</small></span>${sw(LS.startAsk)}</div>
  <div class="it tall" data-f data-fid="set-lbgv" data-act="lbgv"><span>Aperçu vidéo en fond<small>utilise ta connexion · coupé automatiquement avant chaque lecture</small></span>${sw(LS.bgv)}</div>
  <div class="it tall" data-f data-fid="set-lmaxc" data-act="lmaxc"><span>Connexions simultanées de l'abonnement<small>max_connections du compte Xtream · OK pour changer</small></span><span>${LS.maxc}</span></div>
  $1`)}}
