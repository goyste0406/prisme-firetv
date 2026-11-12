/* ========================= QUAND ÇA COINCE · version B « prisme se débrouille » =========================
   prisme essaie seul la solution la plus probable (autre source, autre fournisseur, reprise 10 s avant) et ne prévient
   que par un bandeau qui disparaît. Un panneau ne monte qu'après 3 échecs.
   Le simulateur ne lit aucun vrai flux : les pannes se déclenchent avec les boutons « Démo » sous la télécommande.   */
(function(){
const LSK="prisme-err";
const ER=window.__er={log:[],rel:{},down:{},busy:{},offline:false,cuts:[],pend:null,ban:null,banT:null,exp:null,queue:null,catch:null};
try{const o=JSON.parse(localStorage.getItem(LSK)||"{}");ER.log=o.log||[];ER.rel=o.rel||{}}catch(e){}
const saveE=()=>{try{localStorage.setItem(LSK,JSON.stringify({log:ER.log.slice(0,60),rel:ER.rel}))}catch(e){}};
const nowTxt=()=>{const d=new Date();return d.toLocaleDateString("fr-FR",{day:"numeric",month:"short"})+" "+String(d.getHours()).padStart(2,"0")+":"+String(d.getMinutes()).padStart(2,"0")};
function note(prov,what,how){ER.log.unshift([nowTxt(),prov,what,how]);ER.log=ER.log.slice(0,60);saveE()}
const plName=id=>(S.playlists.find(p=>p.id===id)||{}).name||"ton fournisseur";
const relKey=v=>v.p.id+"|"+v.name;
const unreachable=pid=>ER.down[pid]||ER.busy[pid]||(ER.exp&&ER.exp.pid===pid&&ER.exp.day>=0);
const titleOf=()=>P?(P.kind==="live"?(CH[P.id]||{}).n:(ALL[P.id]||{}).t)||"":"";
/* la meilleure autre source : d'abord celles qui tiennent (fiabilité apprise), puis la qualité */
function bestNext(key,cur,excl){const L=srcs(key).filter(v=>v.id!==cur&&compat(v)&&!unreachable(v.p.id)&&!(excl&&excl(v)));
 return L.sort((a,b)=>((ER.rel[relKey(a)]||0)>=3)-((ER.rel[relKey(b)]||0)>=3)||(qr(b.q)-qr(a.q)))[0]||null}
window.erRel=v=>{const n=ER.rel[relKey(v)]||0;return n>=3?["coupe souvent","bad"]:n===0?["stable ✓","ok"]:["stable ✓","ok"]};

/* ---------- bandeau (au-dessus de l'écran, survit aux redessins) ---------- */
const host=()=>view.parentElement;
function banner(html,opt){opt=opt||{};clearTimeout(ER.banT);ER.ban={html,undo:opt.undo||null,ring:!!opt.ring,x:opt.x||""};drawBan();if(opt.ms)ER.banT=setTimeout(()=>{ER.ban=null;drawBan()},opt.ms)}
function drawBan(){let b=host().querySelector(".erban");if(!ER.ban){if(b)b.remove();return}
 const h=`${ER.ban.ring?'<span class="erring"></span>':""}<span>${ER.ban.html}</span>${ER.ban.x?`<span class="erx">· ${esc(ER.ban.x)}</span>`:""}${ER.ban.undo?`<span class="erundo">OK : revenir à ${esc(ER.ban.undo.lbl)}<i></i></span>`:""}`;
 if(!b){b=document.createElement("div");b.className="erban";host().appendChild(b)}b.classList.toggle("top",topS().t==="player");b.innerHTML=h}
function drawChips(){let c=host().querySelector(".erchip");const want=ER.offline&&topS().t==="player"?"📶 Plus d'Internet · reprise automatique dès son retour":ER.catch?`⏪ Tu as manqué ${ER.catch.s} s<small>OK pour revoir</small>`:"";
 if(!want){if(c)c.remove();return}if(!c){c=document.createElement("div");c.className="erchip";host().appendChild(c)}c.innerHTML=want;c.classList.toggle("foc",!!ER.catch)}
function freeze(on){const pl=view.querySelector(".player");if(pl)pl.classList.toggle("ercut",on)}

/* ---------- coupure pendant la lecture ---------- */
function erCut(silentOK){if(!P)return;const key=curKey(),from=srcs(key).find(v=>v.id===P.src);freeze(true);
 setTimeout(()=>{if(!P)return;const nx=bestNext(key,P.src);if(!nx){freeze(false);return erFail()}
  const pos=P.kind==="vod"?Math.max(0,P.pos-10):0;P.src=nx.id;S.srcSel[key]=nx.id;if(P.kind==="vod")P.pos=pos;save();
  if(from){ER.rel[relKey(from)]=(ER.rel[relKey(from)]||0)+1}note(from?from.p.name:"",titleOf(),`${from?from.q:"source"} a coupé → ${nx.q} · ${nx.p.name}`);
  ER.cuts.push({t:pos,from:from?`${from.p.name} · ${from.q}`:"",to:`${nx.p.name} · ${nx.q}`});
  render("p-pp");uiPing();freeze(false);
  const first=ER.cuts.length===1;
  if(first||!silentOK)banner(`<em>✓</em> ${P.kind==="live"?"Retour du direct":"Reprise 10 s avant"} · ${esc(nx.q)} · ${esc(nx.p.name)}`,{x:"source de secours vérifiée à l'avance",undo:from?{id:from.id,lbl:`${from.q} · ${from.p.name}`}:null,ms:5200});
  /* la source d'origine reviendra : on y retourne à la prochaine pause (jamais en pleine scène) */
  if(from&&P.kind==="vod"){const fid=from.id;setTimeout(()=>{if(P&&P.src!==fid)ER.pend={id:fid,lbl:`${from.q} · ${from.p.name}`}},12000)}
  /* direct : rattrapage si la chaîne a le replay */
  if(P.kind==="live"&&typeof arDays==="function"&&arDays(CH[P.id])){setTimeout(()=>{if(!P||P.kind!=="live")return;ER.catch={s:40};drawChips();setTimeout(()=>{ER.catch=null;drawChips()},9000)},5400)}
 },800)}
/* rien ne marche : 3 essais, puis le panneau */
function erFail(){let n=0;const step=()=>{n++;if(n<=3){banner(`Le flux a coupé · essai ${n} sur 3…`,{ring:true});freeze(true);setTimeout(step,1100);return}
  ER.ban=null;drawBan();S.modal={type:"erfail",ret:"p-pp"};note("",titleOf(),"3 essais ratés");render("erf-0")};step()}
window.erFail=erFail;

/* ---------- lancement : fournisseur en panne, connexion occupée, abonnement terminé ---------- */
{const _sp=startPlayer;startPlayer=function(p){
 if(ER.offline){toast("📶 Plus d'Internet : prisme lancera la lecture dès son retour");ER.queue=p;return _sp(Object.assign(p,{playing:false}))}
 const key=p.kind==="live"?"ch:"+p.id:p.id,cur=srcs(key).find(v=>v.id===p.src);
 if(cur&&unreachable(cur.p.id)){const why=ER.down[cur.p.id]?"ne répond pas":ER.busy[cur.p.id]?"est déjà utilisé ailleurs":"est terminé";
  const nx=bestNext(key,p.src,v=>v.p.id===cur.p.id);
  if(nx){p.src=nx.id;setTimeout(()=>banner(`<em>✓</em> ${esc(cur.p.name)} ${why} · via ${esc(nx.p.name)}`,{x:ER.busy[cur.p.id]?"retour sur "+cur.p.name+" à ta prochaine pause":"rien à faire",ms:4200}),60);
   if(ER.busy[cur.p.id])ER.pendBusy={pid:cur.p.id,id:cur.id,lbl:`${cur.q} · ${cur.p.name}`};note(cur.p.name,(p.kind==="live"?(CH[p.id]||{}).n:(ALL[p.id]||{}).t)||"",`${why} → ${nx.p.name}`)}
  else setTimeout(()=>erFail(),300)}
 ER.cuts=[];ER.pend=null;return _sp(p)}}
/* fin de lecture : un seul résumé au lieu de plusieurs bandeaux */
{const _st=stopPlayer;stopPlayer=function(){const c=ER.cuts.slice(),vod=P&&P.kind==="vod",t=titleOf();ER.cuts=[];ER.pend=null;ER.ban=null;drawBan();ER.catch=null;drawChips();_st();
 if(vod&&c.length)setTimeout(()=>{if(S.modal)return;S.modal={type:"ersum",cuts:c,t};render("ers-ok")},80)}}

/* ---------- fenêtres ---------- */
const fmtS=s=>{s=Math.round(s);const h=Math.floor(s/3600),m=Math.floor(s%3600/60);return h?`${h} h ${String(m).padStart(2,"0")}`:`${m} min`};
{const _m=modalHtml;modalHtml=function(){const m=S.modal;
 if(m&&m.type==="erfail"){const B=[["erf-0","er:retry","Réessayer dans 1 min","automatique"],["erf-1","er:leave","Regarder autre chose","ta position est gardée"],["erf-2","er:det","Voir les détails","pour ton fournisseur"]];
  return `<div class="modal ermod"><div class="ersheet"><h2>Impossible de reprendre ${esc(titleOf()||"la lecture")} pour l'instant</h2><div class="erdg"><span>Internet : <b class="ok">✓ fonctionne</b></span><span>${esc(S.playlists.map(p=>p.name).join(" et "))} : <b class="ko">✕ ne donnent plus ce titre</b></span></div>
  <div class="erbtns">${B.map(([f,a,l,s],i)=>`<div class="btn" data-f data-fid="${f}" data-act="${a}" ${i===0?"data-default":""}>${esc(l)}<small>${esc(s)}</small></div>`).join("")}</div></div></div>`}
 if(m&&m.type==="ersum")return `<div class="modal ermod"><div class="mbox ersum"><div style="font-size:34px">🎬</div><h2>${m.cuts.length} coupure${m.cuts.length>1?"s":""} réglée${m.cuts.length>1?"s":""} sans interruption</h2><p>${esc(m.t)} · tu n'as rien vu, voici ce que prisme a fait.</p>
  <div class="ertl">${m.cuts.sort((a,b)=>a.t-b.t).map(c=>`<div><b>${fmtS(c.t)}</b><span>${esc(c.from)} a coupé → ${esc(c.to)}</span></div>`).join("")}</div><div class="btn" data-f data-fid="ers-ok" data-act="er:close" data-default>OK</div><p class="ersm">noté dans le journal des incidents (Réglages › Fournisseurs)</p></div></div>`;
 if(m&&m.type==="erlog")return `<div class="modal ermod"><div class="mbox erlog"><div class="kick">RÉGLAGES › FOURNISSEURS</div><h2>Journal des incidents</h2><p class="ersm">à montrer à ton fournisseur si ça se répète · Retour pour fermer</p><div class="erlist sy">${ER.log.length?ER.log.map((r,i)=>`<div class="erl" data-f data-fid="erl-${i}" ${i===0?"data-default":""}><b>${esc(r[0])}</b><span>${esc(r[1])}</span><span>${esc(r[2])}</span><span>${esc(r[3])}</span></div>`).join(""):'<div class="erl" data-f data-fid="erl-0" data-default><span>Aucun incident pour l\'instant ✓</span></div>'}</div></div></div>`;
 return _m()}}
{const _a=act;act=function(a){if(typeof a!=="string"||!a.startsWith("er:"))return _a(a);const w=a.slice(3);
 if(w==="close"){S.modal=null;return render()}
 if(w==="retry"){S.modal=null;render("p-pp");toast("prisme réessaie toutes les minutes et te prévient");setTimeout(()=>{if(P){freeze(false);toast("✓ Ça marche de nouveau · reprise");}},6000);return}
 if(w==="leave"){S.modal=null;key("back");return}
 if(w==="det"){toast(`${S.playlists.map(p=>p.name+" : 0 octet reçu").join(" · ")} · ${nowTxt()}`,4200);return}
 if(w==="log"){S.modal={type:"erlog",ret:F&&F.dataset.fid};return render()}}}
/* touches : annuler la bascule, rattrapage, retour à la meilleure source à la pause, fenêtres */
{const _k=key;key=function(k){
 if(S.modal&&(S.modal.type==="ersum"||S.modal.type==="erlog")&&(k==="back"||(k==="ok"&&S.modal.type==="ersum"))){const r=S.modal.ret;S.modal=null;return render(r)}
 if(S.modal&&S.modal.type==="erfail"&&k==="back"){S.modal=null;return _k("back")}
 if(topS().t==="player"&&P&&!S.modal){
  if(k==="ok"&&ER.catch){ER.catch=null;drawChips();P.lag=(P.lag||0)+40;render("p-pp");return toast("⏪ 40 s en arrière (replay)")}
  if(k==="ok"&&ER.ban&&ER.ban.undo){const u=ER.ban.undo;P.src=u.id;S.srcSel[curKey()]=u.id;save();ER.ban=null;drawBan();ER.pend=null;render("p-pp");return toast("↩︎ Retour à "+u.lbl)}
  if(k==="play"&&P.playing){const p=ER.pend||(ER.pendBusy&&!ER.busy[ER.pendBusy.pid]?ER.pendBusy:null);if(p){ER.pend=null;ER.pendBusy=null;setTimeout(()=>{if(!P)return;P.src=p.id;S.srcSel[curKey()]=p.id;save();render("p-pp");toast(`✓ De retour sur ${p.lbl} pendant ta pause`)},900)}}}
 return _k(k)}}
{const _r=render;render=function(fid){const r=_r(fid);try{drawBan();drawChips();
 /* fiabilité apprise dans le choix des sources */
 if(S.modal&&S.modal.k)view.querySelectorAll('.msrc[data-act^="msrc:"]').forEach(e=>{const id=e.dataset.act.slice(5),v=srcs(S.modal.k).find(x=>x.id===id);if(!v||e.querySelector(".errel"))return;const [t,c]=erRel(v);e.insertAdjacentHTML("beforeend",`<span class="errel ${c}">${t}</span>`)})}catch(e){}return r}}
/* point d'état dans la barre d'onglets */
{const _tb=tabbar;tabbar=function(){const h=_tb();const d=Object.keys(ER.down).filter(k=>ER.down[k]).map(plName);const t=ER.offline?"Hors ligne":d.length?d.join(", ")+" en panne":"";if(!t)return h;const i=h.lastIndexOf("</div></div>");return h.slice(0,i)+`<span class="erdot"><i></i>${esc(t)}</span>`+h.slice(i)}}

/* ---------- Réglages › Fournisseurs : journal ---------- */
window.SAX=window.SAX||{};{const _x=SAX.acc;SAX.acc=()=>(_x?_x():"")+`<div class="it" data-f data-fid="er-log" data-act="er:log" data-desc="Heure, fournisseur, titre, cause et solution utilisée : à montrer à ton fournisseur si ça se répète."><span>Journal des incidents</span><span>${ER.log.length?ER.log.length+" incident"+(ER.log.length>1?"s":""):"aucun"} ›</span></div>`}

/* ---------- abonnement : 7 jours avant, la veille, puis bascule toute seule ---------- */
function expBanner(){const pl=S.playlists.find(p=>p.exp);if(!pl||!inApp())return;const d=Math.ceil((pl.exp-Date.now())/864e5);ER.exp={pid:pl.id,day:-d};
 const k="prisme-exp-b-"+(d>7?"":d<=0?"0":d<=1?"1":"7");if(d>7)return;let seen=false;try{seen=sessionStorage.getItem(k)}catch(e){}if(seen)return;try{sessionStorage.setItem(k,"1")}catch(e){}
 setTimeout(()=>banner(d<=0?`📅 ${esc(pl.name)} est terminé · les titres aussi chez ${esc((S.playlists.find(p=>p.id!==pl.id)||{}).name||"ton autre fournisseur")} passent par lui`:d<=1?`📅 ${esc(pl.name)} se termine demain`:`📅 Ton abonnement ${esc(pl.name)} se termine dans ${d} jours`,{x:d<=0?"les autres sont grisés, pas supprimés":"renouvelle chez ton fournisseur",ms:6500}),2500)}

/* ---------- démo (le simulateur ne lit pas de vrais flux) ---------- */
const box=document.querySelector(".ldemo");
if(box){box.insertAdjacentHTML("beforeend",`<span style="margin-left:8px">Quand ça coince :</span><button type="button" data-er="cut">Coupure (film, série ou chaîne)</button><button type="button" data-er="down">Fournisseur en panne</button><button type="button" data-er="busy">Connexion déjà utilisée</button><button type="button" data-er="fail">Rien ne marche</button><button type="button" data-er="net">Plus d'Internet</button><button type="button" data-er="exp">Abonnement : J-7 → veille → fin</button>`);
 const p1=()=>S.playlists[0];
 box.querySelectorAll("[data-er]").forEach(b=>b.addEventListener("click",()=>{const w=b.dataset.er;
  if(w==="cut"){if(!P)return toast("Lance d'abord un film, une série ou une chaîne");return erCut(true)}
  if(w==="fail"){if(!P)return toast("Lance d'abord un film, une série ou une chaîne");return erFail()}
  if(w==="down"){const pl=P?(srcs(curKey()).find(v=>v.id===P.src)||{}).p||p1():p1();if(!pl)return;ER.down[pl.id]=true;note(pl.name,"Serveur","ne répond pas");
   if(P){erCut(true)}else{banner(`<em>✓</em> ${esc(pl.name)} ne répond pas · tes lectures passent par ton autre fournisseur`,{x:"rien à faire",ms:4500});render(F&&F.dataset.fid)}
   setTimeout(()=>{delete ER.down[pl.id];toast(`✓ ${pl.name} est revenu`);render(F&&F.dataset.fid)},25000);return}
  if(w==="busy"){const pl=p1();if(!pl)return;ER.busy[pl.id]=true;toast(`Démo : le compte ${pl.name} est utilisé ailleurs pendant 20 s · lance un titre`);setTimeout(()=>{delete ER.busy[pl.id];if(ER.pendBusy)toast(`${pl.name} est libre : retour à ta prochaine pause (⏯)`)},20000);return}
  if(w==="net"){ER.offline=true;freeze(true);render(F&&F.dataset.fid);note("","Internet","coupé");setTimeout(()=>{ER.offline=false;freeze(false);if(P&&P.kind==="vod")P.pos=Math.max(0,P.pos-10);const q=ER.queue;ER.queue=null;render(F&&F.dataset.fid);toast(q?"✓ Internet est revenu · la lecture démarre":P?"✓ Internet est revenu · reprise 10 s avant la coupure":"✓ Internet est revenu");if(q&&P){P.playing=true}},7000);return}
  if(w==="exp"){const pl=p1();if(!pl)return;const st=[7,1,0];ER.expI=((ER.expI==null?-1:ER.expI)+1)%3;pl.exp=Date.now()+st[ER.expI]*864e5-(st[ER.expI]?3600e3:0);save();try{["7","1","0"].forEach(x=>sessionStorage.removeItem("prisme-exp-b-"+x))}catch(e){}expBanner();if(st[ER.expI]===0)note(pl.name,"Abonnement","terminé → bascule vers l'autre fournisseur");return}
 }))}
/* le direct : la coupure simulée suit maintenant la version B */
if(typeof lFailStart==="function")lFailStart=function(){erCut(false)};
setTimeout(expBanner,1500);
})();
