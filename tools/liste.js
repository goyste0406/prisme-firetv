/* ========================= DÉMARRAGE B · MA LISTE E · HISTORIQUE B =========================
   - Démarrage instantané : l'accueil s'ouvre tout de suite, la mise à jour se fait derrière (fin liseré) ;
     ⏯ juste après l'ouverture reprend ce que tu regardais ; message de la nuit ; option « ouvrir sur la TV en direct ».
   - Ma liste « Décide pour moi » : une envie → 3 titres de ta liste qui finissent avant ton coucher, duel, rangées.
   - Historique « Ma semaine » : 7 jours en colonnes, heures, genre, série la plus suivie, soirée type.        */
(function(){
const MN=window.__mn={sub:"list",mood:0,duel:null,boot:Date.now()};
const P_=()=>PR.list[PR.cur]||{};const PX=p=>{p.x=p.x||{};return p.x};
const isGuest=()=>{const p=P_();return !!p.guest||p.n==="Invité"};
const nowM=()=>nowMin();const bedM=()=>{const b=P_().bed||23*60;return b<nowM()-120?b+1440:b};
const hm=m=>{m=((m%1440)+1440)%1440;return `${Math.floor(m/60)} h ${String(Math.round(m%60)).padStart(2,"0")}`};
const durTxt=m=>m>=60?`${Math.floor(m/60)} h ${String(m%60).padStart(2,"0")}`:`${m} min`;
const lenOf=it=>it.type==="s"?(it.ep||45):(it.d||100);

/* ---------- pourquoi il est là : on note quand et d'où chaque titre arrive dans Ma liste ---------- */
let favPrev=new Set(S.favs);
function favCtx(){const t=topS().t,m=S.modal&&S.modal.type;if(m==="fxtrl")return "après sa bande-annonce";if(t==="detail")return "depuis sa fiche";if(t==="player")return "pendant la lecture";if(S.tab==="search")return "depuis la recherche";return "depuis l'accueil"}
{const _s=save;save=function(){try{const x=PX(P_());x.favAt=x.favAt||{};for(const id of S.favs)if(!favPrev.has(id)&&!x.favAt[id])x.favAt[id]={t:Date.now(),w:favCtx()};favPrev=new Set(S.favs);prSave()}catch(e){}return _s()}}

/* ---------- historique : chaque lecture est notée (jamais pour l'invité) ---------- */
let cur=null;
{const _sp=startPlayer;startPlayer=function(p){const r=_sp(p);try{if(P&&!isGuest())cur={id:P.id,kind:P.kind,t0:Date.now(),pos0:P.pos||0}}catch(e){}return r}}
{const _st=stopPlayer;stopPlayer=function(){try{if(cur&&P&&cur.id===P.id){const real=(Date.now()-cur.t0)/1000,pos=P.kind==="vod"?Math.max(0,(P.pos||0)-cur.pos0):real,dur=Math.max(real,pos);
  if(dur>=20){const x=PX(P_());x.wh=x.wh||[];x.wh.push({id:cur.kind==="live"?"ch:"+cur.id:cur.id,t:cur.t0,d:Math.round(dur)});x.wh=x.wh.slice(-400);x.lastPlay={id:cur.id,kind:cur.kind};prSave()}}}catch(e){}cur=null;return _st()}}
/* démonstration : une semaine d'exemple quand rien n'a encore été regardé */
function demoWeek(){if(typeof REAL!=="undefined"&&REAL)return [];const out=[],d0=new Date();d0.setHours(0,0,0,0);const F=FILMS.slice(0,6),Sx=SERIES.slice(0,4),C=CHS.slice(0,3);
 const plan=[[6,[[Sx[0],21,2400],[F[0],18,4100]]],[5,[[F[1],20.9,6400]]],[4,[[Sx[1],21.2,3000],[Sx[1],22,2900]]],[3,[]],[2,[[F[2],21,5100],["ch:"+(C[0]||{}).id,20,1800]]],[1,[[Sx[0],21.5,2700],[Sx[2],22.4,1500]]],[0,[[Sx[0],21,2600]]]];
 for(const [ago,L] of plan)for(const [it,h,d] of L){if(!it)continue;out.push({id:typeof it==="string"?it:it.id,t:d0.getTime()-ago*864e5+h*3600e3,d})}return out}
const sessions=()=>{const w=(PX(P_()).wh||[]).filter(s=>(s.id.startsWith("ch:")?CH[s.id.slice(3)]:ALL[s.id]));return w.length?w:demoWeek()};

/* ---------- envies (à partir des genres et mots-clés TMDB) ---------- */
const MOODS=[["rire","😂 Envie de rire"],["tension","😱 Du suspense"],["emo","🥲 De l'émotion"],["grand","🎬 Grand spectacle"],["deux","👥 À deux"],["court","⏱ Moins d'une heure"]];
const othersFav=()=>{const s=new Set();for(const id in PR.list){if(id===PR.cur)continue;const d=PR.list[id].d;for(const f of (d&&d.favs)||[])s.add(f)}return s};
function moodsOf(it,OF){const g=(it.g||[]).join(" ").toLowerCase(),kw=((it.tmd&&it.tmd.kw)||[]).join(" ").toLowerCase(),M=new Set();
 if(/comédie|comedie|animation|famil/.test(g))M.add("rire");if(/thriller|policier|crime|horreur|action|myst/.test(g)||/meurtre|enquête|vengeance/.test(kw))M.add("tension");
 if(/drame|romance/.test(g))M.add("emo");if(/science|aventure|fantas|guerre|action/.test(g)||lenOf(it)>=130)M.add("grand");
 if(/romance|comédie|comedie/.test(g)||OF.has(it.id))M.add("deux");if((it.type==="s"&&lenOf(it)<=35)||(it.type!=="s"&&lenOf(it)<60))M.add("court");return M}
const newEp=it=>{if(it.type!=="s")return false;const W=(window.SXDATA&&SXDATA.week)||[];return W.some(w=>w.id===it.id&&w.j<=0&&!w.seen)};
function myList(){const OF=othersFav(),fa=PX(P_()).favAt||{};return S.favs.filter(k=>!String(k).startsWith("ch:")&&ALL[k]).map(k=>{const it=ALL[k];return {it,ok:srcs(it.id).length>0,M:moodsOf(it,OF),nw:newEp(it),fa:fa[k],two:OF.has(k),prog:S.prog[k]||0}})}
function why(o){if(o.nw)return "🔵 nouvel épisode";if(o.prog)return `↺ en cours · ${Math.round(o.prog*100)} %`;if(o.two)return "👥 aussi dans la liste d'un autre profil";if(o.fa){const d=Math.round((Date.now()-o.fa.t)/864e5);return `＋ ajouté ${d<1?"aujourd'hui":d<2?"hier":`il y a ${d} j`} ${o.fa.w}`}return "＋ dans ta liste"}
const endOf=o=>nowM()+Math.round(lenOf(o.it)*(1-(o.prog||0)));
function rank(L){const bed=bedM();return L.slice().sort((a,b)=>((endOf(a)>bed)-(endOf(b)>bed))||(b.nw-a.nw)||((b.it.imdb||0)-(a.it.imdb||0)))}
function moodItems(){const m=MOODS[MN.mood][0];return myList().filter(o=>o.ok&&o.M.has(m))}

/* ---------- page ---------- */
const art=(it,po)=>{const c=it.c||[it.col||"#2a3550","#0d1018"],u=po?(it.po||it.bd):(it.bd||it.po),g=`linear-gradient(135deg,${c[0]},${c[1]||"#111"})`;return `<div class="art" style="background:${u?`url('${String(u).replace(/'/g,"%27")}') center/cover no-repeat,`:""}${g}">${u?"":`<i class="mn-ttl">${esc(it.t||"")}</i>`}</div>`};
function pick(o,i){const late=endOf(o)>bedM();return `<div class="mn-pk" data-f data-fid="mnp-${i}" data-row="mnp" data-act="mn:play:${o.it.id}" data-hid="${o.it.id}">${art(o.it)}<span class="mn-sc">${i===0&&!late?"⭐ le plus adapté":late?"finit après ton coucher":"finit à "+hm(endOf(o))}</span><div class="mn-in"><small>${o.it.type==="s"?"Série · épisodes de "+lenOf(o.it)+" min":"Film · "+durTxt(lenOf(o.it))}</small><b>${esc(o.it.t)}</b><span>${esc(why(o))}</span></div></div>`}
function card(o,row,i){return `<div class="mn-po ${o.ok?"":"gone"}" data-f data-fid="${row}-${i}" data-row="${row}" data-act="mn:play:${o.it.id}" data-hid="${o.it.id}">${art(o.it,1)}${o.nw?'<span class="mn-tag nw">nouvel épisode</span>':o.ok?"":'<span class="mn-tag">plus disponible · surveillé</span>'}<b>${esc(o.it.t)}</b><small>${o.ok?(endOf(o)>bedM()?"après ton coucher":"fin "+hm(endOf(o))):"revient tout seul s'il réapparaît"}</small></div>`}
function listHtml(){const all=myList();if(!all.length)return `<div class="mn-empty">Ta liste est vide. Sur n'importe quelle affiche, maintiens le clic (ou M) pour l'ajouter ici.</div>`;
 const L=rank(moodItems()),P3=L.slice(0,3),rest=L.slice(3),others=all.filter(o=>o.ok&&!moodItems().includes(o)),gone=all.filter(o=>!o.ok);
 /* rappel doux : un titre oublié depuis 3 mois revient une fois en tête */
 const x=PX(P_());const old=all.find(o=>o.ok&&o.fa&&Date.now()-o.fa.t>90*864e5&&!(x.remind||{})[o.it.id]);
 return `<div class="mn-h">Qu'est-ce qui te ferait envie ?<small>prisme choisit dans ta liste · M sur une proposition : duel, retirer, vu</small></div>
 <div class="mn-moods">${MOODS.map((m,j)=>`<div class="mn-mc ${j===MN.mood?"on":""}" data-f data-fid="mnm-${j}" data-row="mnm" data-act="mn:mood:${j}" data-hov="mnmood:${j}">${m[1]}<em>${all.filter(o=>o.ok&&o.M.has(m[0])).length}</em></div>`).join("")}</div>
 ${old?`<div class="mn-old"><span>🕰 Tu l'avais oublié ? « ${esc(old.it.t)} » est dans ta liste depuis plus de 3 mois.</span><div class="mn-bt" data-f data-fid="mno-keep" data-row="mno" data-act="mn:keep:${old.it.id}">Le garder</div><div class="mn-bt" data-f data-fid="mno-del" data-row="mno" data-act="mn:del:${old.it.id}">Le retirer</div></div>`:""}
 <div class="mn-picks">${P3.length?P3.map(pick).join(""):`<div class="mn-empty">Rien dans ta liste pour cette envie : essaie une autre.</div>`}</div>
 ${P3.length>=2?`<div class="mn-duelb" data-f data-fid="mn-duel" data-row="mnd" data-act="mn:duel">⚔︎ Duel : départage les titres de cette envie</div>`:""}
 ${rest.length?`<section data-anchor><div class="lh">Aussi pour cette envie<small>${rest.length}</small></div><div class="row sx">${rest.map((o,i)=>card(o,"mnr",i)).join("")}</div></section>`:""}
 ${others.length?`<section data-anchor><div class="lh">Le reste de ta liste<small>${others.length}</small></div><div class="row sx">${rank(others).map((o,i)=>card(o,"mnx",i)).join("")}</div></section>`:""}
 ${gone.length?`<section data-anchor><div class="lh">Plus disponible<small>retiré par ton fournisseur · revient tout seul, ou par ton autre fournisseur</small></div><div class="row sx">${gone.map((o,i)=>card(o,"mng",i)).join("")}</div></section>`:""}`}
function weekHtml(){const W=sessions(),d0=new Date();d0.setHours(0,0,0,0);const days=[];for(let i=6;i>=0;i--){const t=d0.getTime()-i*864e5;days.push({t,L:W.filter(s=>s.t>=t&&s.t<t+864e5)})}
 const tot=W.filter(s=>s.t>=d0.getTime()-6*864e5).reduce((a,s)=>a+s.d,0)/3600;const g={},sr={},hrs=[];
 for(const s of W){const it=s.id.startsWith("ch:")?null:ALL[s.id];if(it){(it.g||[]).slice(0,1).forEach(x=>g[x]=(g[x]||0)+s.d);if(it.type==="s")sr[it.t]=(sr[it.t]||0)+s.d}hrs.push(new Date(s.t).getHours())}
 const top=o=>Object.entries(o).sort((a,b)=>b[1]-a[1])[0];const hs=hrs.sort((a,b)=>a-b)[hrs.length>>1];
 const nm=s=>s.id.startsWith("ch:")?(CH[s.id.slice(3)]||{}).n:(ALL[s.id]||{}).t;const DN=["DIM","LUN","MAR","MER","JEU","VEN","SAM"];
 const demo=!(PX(P_()).wh||[]).length;
 return `<div class="mn-h">Ma semaine<small>${demo?"exemple : ta semaine se remplira au fil de tes lectures · ":""}profil ${esc(P_().n||"")} · OK : reprendre · M : options</small></div>
 <div class="mn-stats">${[[tot?`${Math.floor(tot)} h ${String(Math.round(tot%1*60)).padStart(2,"0")}`:"—","regardées ces 7 jours"],[(top(g)||["—"])[0],"genre de la semaine"],[(top(sr)||["—"])[0],"série la plus suivie"],[hs!=null?`${hs} h – ${hs+2} h`:"—","ta soirée type"]].map(x=>`<div class="mn-st"><b>${esc(x[0])}</b><span>${x[1]}</span></div>`).join("")}</div>
 <div class="mn-week">${days.map((d,j)=>{const h=d.L.reduce((a,s)=>a+s.d,0)/3600,seen=new Set(),U=d.L.filter(s=>!seen.has(s.id)&&seen.add(s.id));
  return `<div class="mn-day ${j===6?"tod":""}"><div class="mn-dn">${j===6?"AUJ.":DN[new Date(d.t).getDay()]} · ${h?String(Math.round(h*10)/10).replace(".",",")+" h":"—"}</div><div class="mn-db"><i style="width:${Math.min(100,h/3*100)}%"></i></div>
  ${U.map((s,i)=>{const it=s.id.startsWith("ch:")?CH[s.id.slice(3)]:ALL[s.id];const c=it&&it.c?it.c:[it&&it.col||"#334","#111"];return `<div class="mn-wi" data-f data-fid="mnw-${j}-${i}" data-row="mnw${i}" data-col="${j}" data-act="mn:play:${s.id}" style="--a:${c[0]};--b:${c[1]}">${esc(nm(s)||"")}</div>`}).join("")}</div>`}).join("")}</div>`}
function mineHtml(){return `<div class="mn sy" id="mnscr"><div class="mn-sub">${[["list","Ma liste"],["week","Ma semaine"]].map(([k,n])=>`<div class="mn-tab ${MN.sub===k?"sel":""}" data-f data-fid="mns-${k}" data-row="mns" data-act="mn:sub:${k}" data-hov="mnsub:${k}">${n}</div>`).join("")}</div>${MN.sub==="list"?listHtml():weekHtml()}<div style="height:60px"></div></div>`}
{const _tb=tabbar;tabbar=function(){const h=_tb();if(!inApp())return h;const i=h.indexOf('data-fid="tab-live"');if(i<0)return h;const j=h.indexOf("</div>",i)+6;
 return h.slice(0,j)+`<div class="tab ${S.tab==="mine"?"sel":""}" data-f data-fid="tab-mine" data-row="tabs" data-act="tab:mine" data-hov="tab:mine" ${S.tab==="mine"?"data-default":""}>Ma liste</div>`+h.slice(j)}}
{const _h=homeHtml;homeHtml=function(){if(inApp()&&S.tab==="mine")return tabbar()+mineHtml();return _h()}}
{const _o=onHover;onHover=function(h){if(h&&h.startsWith("mnmood:")){const v=+h.slice(7);if(MN.mood!==v){MN.mood=v;render("mnm-"+v)}return}if(h&&h.startsWith("mnsub:")){const v=h.slice(6);if(MN.sub!==v){MN.sub=v;render("mns-"+v)}return}return _o(h)}}

/* ---------- fenêtres : duel, options ---------- */
{const _m=modalHtml;modalHtml=function(){const m=S.modal;
 if(m&&m.type==="mnduel"){const [a,b]=m.pair;return `<div class="modal mn-dm"><div class="mn-dbox"><h2>Duel · ${m.round} / ${m.max}</h2><p>← ou → puis OK pour garder ton préféré</p><div class="mn-dv">${[a,b].map((o,j)=>`<div class="mn-pk" data-f data-fid="mnd-${j}" data-row="mndv" data-act="mn:win:${j}" ${j===0?"data-default":""}>${art(o.it)}<div class="mn-in"><small>${o.it.type==="s"?"Série":"Film · "+durTxt(lenOf(o.it))}</small><b>${esc(o.it.t)}</b><span>fin ${hm(endOf(o))}</span></div></div>`).join('<div class="mn-vs">VS</div>')}</div></div></div>`}
 if(m&&m.type==="mnopt"){const it=ALL[m.id]||CH[String(m.id).slice(3)]||{};return `<div class="modal"><div class="mbox"><div class="kick">${m.h?"HISTORIQUE":"MA LISTE"}</div><h2>${esc(it.t||it.n||"")}</h2><div class="mlist sy">${m.o.map(([a,l],i)=>`<div class="msrc" data-f data-fid="mno-${i}" data-act="mn:${a}:${m.id}" ${i===0?"data-default":""}><div class="mn">${esc(l)}</div></div>`).join("")}</div></div></div>`}
 return _m()}}
{const _a=act;act=function(a){if(typeof a!=="string"||!a.startsWith("mn:"))return _a(a);const [,w,...r]=a.split(":"),v=r.join(":");const x=PX(P_());
 switch(w){
 case "sub":MN.sub=v;return render("mns-"+v);
 case "mood":MN.mood=+v;return render("mnp-0");
 case "play":{if(v.startsWith("ch:"))return act("live:"+v.slice(3));const it=ALL[v];if(!it)return;if(!srcs(v).length){(x.watch=x.watch||{})[v]=1;prSave();return toast("🔔 prisme te préviendra si ce titre revient chez un de tes fournisseurs")}
  return act(it.type==="s"?"sxplay:"+v:"play:"+v)}
 case "duel":{const L=rank(moodItems());if(L.length<2)return toast("Pas assez de titres pour un duel");S.modal={type:"mnduel",pool:L.slice(2),pair:[L[0],L[1]],round:1,max:Math.min(4,L.length-1),ret:"mn-duel"};return render("mnd-0")}
 case "win":{const m=S.modal,w2=m.pair[+v],pool=m.pool.filter(o=>o!==w2);if(!pool.length||m.round>=m.max){S.modal=null;render("mnp-0");toast("🏆 Gagnant : "+w2.it.t);return act("mn:play:"+w2.it.id)}m.pool=pool.slice(1);m.pair=[w2,pool[0]];m.round++;return render("mnd-0")}
 case "keep":(x.remind=x.remind||{})[v]=1;prSave();toast("Gardé dans ta liste");return render("mnp-0");
 case "del":S.favs=S.favs.filter(z=>z!==v);save();S.modal=null;toast("Retiré de ta liste");return render("mnp-0");
 case "seen":{const it=ALL[v];if(!it)return;if(it.type==="s"){const sx=PX(P_());}else{const p=P_();p.seen=p.seen||[];if(!p.seen.includes(v))p.seen.push(v)}delete S.prog[v];save();prSave();S.modal=null;toast("✓ Marqué comme vu");return render()}
 case "why":{const o=myList().find(o=>o.it.id===v);S.modal=null;render();return toast(o?why(o):"Dans ta liste")}
 case "unhist":x.wh=(x.wh||[]).filter(s=>s.id!==v);prSave();S.modal=null;toast("Retiré de ton historique");return render();
 case "nomore":{x.wh=(x.wh||[]).filter(s=>s.id!==v);const p=P_();p.no=p.no||[];if(!p.no.includes(v))p.no.push(v);if(typeof FXS!=="undefined")FXS.cache={};prSave();S.modal=null;toast("Ne sera plus proposé dans « Pour toi »");return render()}
 case "up":case "down":{const p=P_();p.fb=p.fb||{};p.fb[v]=w==="up"?1:-1;if(typeof FXS!=="undefined")FXS.cache={};prSave();S.modal=null;toast(w==="up"?"👍 Noté : « Pour toi » s'affine":"👎 Noté : moins de titres comme celui-ci");return render()}
 case "resume":S.modal=null;return act("mn:play:"+v)}}}
{const _k=key;key=function(k){
 /* options (M) sur Ma liste et Ma semaine */
 if(k==="menu"&&!S.modal&&S.tab==="mine"&&topS().t==="home"&&F&&F.dataset.act&&F.dataset.act.startsWith("mn:play:")){const id=F.dataset.act.slice(8),h=MN.sub==="week";
  S.modal={type:"mnopt",id,h,ret:F.dataset.fid,o:h?[["resume","Reprendre (même source, même version)"],["seen","Marquer comme vu"],["unhist","Retirer de l'historique"],["nomore","Ne plus proposer"],["up","👍 J'ai aimé"],["down","👎 Pas pour moi"]]:[["duel","⚔︎ Duel pour cette envie"],["del","Retirer de Ma liste"],["seen","Marquer comme vu"],["why","Pourquoi il est là ?"]]};return render("mno-0")}
 if(S.modal&&(S.modal.type==="mnduel"||S.modal.type==="mnopt")&&k==="back"){const r=S.modal.ret;S.modal=null;return render(r)}
 /* reprise directe : ⏯ juste après l'ouverture relance ce que tu regardais */
 if(k==="play"&&!S.modal&&topS().t==="home"&&Date.now()-MN.boot<30000){const lp=PX(P_()).lastPlay;const id=lp?lp.id:Object.keys(S.prog).sort((a,b)=>S.prog[b]-S.prog[a])[0];
  if(id){MN.boot=0;if(lp&&lp.kind==="live")return act("live:"+id);const it=ALL[id];if(it){toast("▶︎ Reprise : "+it.t);return act(it.type==="s"?"sxplay:"+id:"play:"+id)}}}
 return _k(k)}}

/* ---------- démarrage instantané : plus d'écran d'attente, la mise à jour se fait derrière ---------- */
lPreload=function(done){S.loading=false;const sc=view.parentElement;let e=sc.querySelector(".mn-edge");if(!e){e=document.createElement("div");e.className="mn-edge";sc.appendChild(e)}
 e.style.width="8%";e.classList.remove("done");let i=0;const t=setInterval(()=>{i++;e.style.width=Math.min(100,8+i*23)+"%";if(i>=4){clearInterval(t);e.classList.add("done");try{LS.loadedAt=fmt(nowMin());lsave()}catch(_){}}},450);done()};
/* message de la nuit : ce qui a changé depuis ta dernière visite (une fois par jour) */
function nightMsg(){if(!inApp())return;let last=0;try{last=+localStorage.getItem("prisme-last-visit")||0;localStorage.setItem("prisme-last-visit",Date.now())}catch(e){}
 const today=new Date().toDateString();let shown="";try{shown=localStorage.getItem("prisme-night")||""}catch(e){}if(shown===today)return;try{localStorage.setItem("prisme-night",today)}catch(e){}
 const W=((window.SXDATA&&SXDATA.week)||[]).filter(w=>w.j<=0&&w.j>=-1&&!w.seen).length;
 const nf=(typeof REAL!=="undefined"&&REAL&&last)?FILMS.filter(f=>f._real&&(f._real.a||0)*1000>last).length:(last?0:14);
 const bits=[W?`${W} nouvel${W>1?"s":""} épisode${W>1?"s":""}`:"",nf?`${nf} film${nf>1?"s":""} ajouté${nf>1?"s":""}`:""].filter(Boolean);
 const d=new Date(),sunday=d.getDay()===0&&d.getHours()>=18,wk=sessions().filter(s=>s.t>Date.now()-7*864e5).reduce((a,s)=>a+s.d,0)/3600;
 const msg=sunday&&wk?`📊 Ta semaine : ${Math.round(wk*10)/10} h regardées · le détail dans Ma liste › Ma semaine`:bits.length?`🌙 Cette nuit : ${bits.join(" · ")}`:"";if(!msg)return;
 const sc=view.parentElement,b=document.createElement("div");b.className="mn-night";b.textContent=msg;sc.appendChild(b);setTimeout(()=>b.classList.add("out"),6500);setTimeout(()=>b.remove(),7300)}
/* option : ouvrir prisme sur la TV en direct (comme une box) */
window.SAX=window.SAX||{};{const _x=SAX.live;SAX.live=()=>`<div class="it" data-f data-fid="mn-startlive" data-act="mn:startlive" data-desc="Comme une box : à l'ouverture, la dernière chaîne regardée s'allume tout de suite."><span>Ouvrir prisme sur la TV en direct</span>${sw(!!(S.set.x||{}).startLive)}</div>`+(_x?_x():"")}
{const _a=act;act=function(a){if(a==="mn:startlive"){S.set.x=S.set.x||{};S.set.x.startLive=S.set.x.startLive?0:1;save();return render("mn-startlive")}return _a(a)}}
setTimeout(()=>{try{if(!inApp())return;if((S.set.x||{}).startLive&&LS.hist&&LS.hist[0]&&CH[LS.hist[0]]&&topS().t==="home"&&!S.modal){S.tab="live";act("live:"+LS.hist[0])}nightMsg()}catch(e){}},1200);
})();
