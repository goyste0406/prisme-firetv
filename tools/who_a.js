/* ========================= « QUI REGARDE ? » · version A =========================
   Profil deviné selon l'heure et les habitudes, ouverture automatique au bout de 5 s (une touche annule),
   ▶︎ = reprise directe, ce que chacun regardait et ses nouveautés, À deux, Invité, ajout (nom au clavier ou sur l'iPhone),
   changer de profil partout en maintenant 📺, accueil aux couleurs du profil choisi. */
(function(){
const W=window.WHO={cd:0,t:null};
/* habitudes : à quelle heure chaque profil est choisi */
function learn(id){const p=PR.list[id];if(!p||p.guest)return;p.hrs=p.hrs||Array(24).fill(0);const h=new Date().getHours();p.hrs[h]=(p.hrs[h]||0)+1;prSave()}
function guess(){const h=new Date().getHours(),ids=Object.keys(PR.list).filter(id=>!PR.list[id].guest);let best=null,bs=0;
 for(const id of ids){const r=PR.list[id].hrs||[];const sc=(r[h]||0)*2+(r[(h+23)%24]||0)+(r[(h+1)%24]||0);if(sc>bs){bs=sc;best=id}}
 return best||(PR.list[PR.cur]&&!PR.list[PR.cur].guest?PR.cur:ids[0])}
const usual=id=>{const r=(PR.list[id]&&PR.list[id].hrs)||[];let h=-1,m=0;r.forEach((v,i)=>{if(v>m){m=v;h=i}});if(h<0)return "";return h<12?"d'habitude le matin":h<17?"d'habitude l'après-midi":h<20?"d'habitude en fin de journée":"d'habitude le soir"};
/* ce que chaque profil regardait */
function progOf(id){return id===PR.cur?S.prog:((PR.list[id].d||{}).prog||{})}
function resumeOf(id){const p=PR.list[id],pr=progOf(id),H=[...(p.hist||[])].reverse();
 for(const h of H){const it=ALL[h.id];if(it&&pr[h.id]&&pr[h.id]<.97&&srcs(it.id).length)return {it,pct:pr[h.id]}}
 for(const k of Object.keys(pr).reverse()){const it=ALL[k];if(it&&pr[k]<.97&&srcs(k).length)return {it,pct:pr[k]}}return null}
function newsOf(id){const p=PR.list[id],favs=id===PR.cur?S.favs:((p.d||{}).favs||[]);const L=favs.map(k=>ALL[k]).filter(it=>it&&(added(it.id)||{d:99}).d<=7);return L}
const hello=()=>{const h=new Date().getHours();return h<5?"Bonsoir":h<12?"Bonjour":h<18?"Bon après-midi":"Bonsoir"};
const AV=(id,cls,extra)=>{const p=PR.list[id];return `<div class="wa-av ${cls||""}" style="--c:${p.c}">${p.emo||esc((p.n||"?")[0])}${extra||""}</div>`};
function ringH(){const r=48,C=2*Math.PI*r;return `<div class="wa-ring"><svg viewBox="0 0 104 104"><circle cx="52" cy="52" r="${r}" stroke-dasharray="${C}" stroke-dashoffset="${C*(1-W.cd/5)}"/></svg></div>`}
function whoHtml(){const ids=Object.keys(PR.list).filter(id=>!PR.list[id].guest),g=guess(),cd=W.cd>0;const foc=(F&&F.dataset&&F.dataset.pid)||null;
 const items=ids.map(id=>{const p=PR.list[id],nw=newsOf(id).length;const sub=p.max!=null?"🔒 "+ageLbl(p.max):id===g&&usual(id)?usual(id):"&nbsp;";
  return `<div class="wa-p" data-f data-fid="m-p-${id}" data-act="fxprof:${id}" data-pid="${id}" ${id===g?"data-default":""}>${AV(id,"",(nw?`<span class="wa-bd">${nw}</span>`:"")+(cd&&id===g?ringH():""))}<b>${esc(p.n)}</b><small>${sub}</small></div>`});
 if(ids.length>=2)items.push(`<div class="wa-p" data-f data-fid="m-p-duo" data-act="fxduo:${ids[0]}:${ids[1]}" data-pid="duo"><div class="wa-av wa-duo"><span style="--c:${PR.list[ids[0]].c}">${esc(PR.list[ids[0]].n[0])}</span><span style="--c:${PR.list[ids[1]].c}">${esc(PR.list[ids[1]].n[0])}</span></div><b>À deux</b><small>${esc(PR.list[ids[0]].n)} + ${esc(PR.list[ids[1]].n)}</small></div>`);
 items.push(`<div class="wa-p" data-f data-fid="m-p-guest" data-act="whoguest" data-pid="guest"><div class="wa-av" style="--c:#64748b">👤</div><b>Invité</b><small>sans historique</small></div>`);
 if(ids.length<6)items.push(`<div class="wa-p add" data-f data-fid="m-p-add" data-act="fxpadd" data-pid="add"><div class="wa-av">＋</div><b>Ajouter</b><small>nom au clavier ou sur l'iPhone</small></div>`);
 return `<div class="modal wa"><div class="wa-bg" id="wabg"></div><div class="wa-h"><h1>${cd?`${hello()} ${esc(PR.list[g].n)} ?`:"Qui regarde ?"}</h1><p>${cd?`prisme t'ouvre ton profil dans ${W.cd} s · choisis-en un autre si ce n'est pas toi`:"OK pour choisir · ▶︎ pour reprendre directement · maintiens pour modifier"}</p></div>
 <div class="wa-row">${items.join("")}</div><div class="wa-res" id="wares">${resH(foc||g)}</div>
 <div class="wa-bot"><div class="btn" data-f data-fid="m-p-man" data-act="fxpman">Gérer les profils</div></div></div>`}
function resH(pid){if(pid==="guest")return `<div class="wa-card"><div class="wa-tx"><span class="wa-k">Mode invité</span><b>Regarder sans rien changer</b><small>Ni historique, ni reprises, ni recommandations touchés · effacé en changeant de profil</small></div></div>`;
 if(pid==="duo")return `<div class="wa-card"><div class="wa-tx"><span class="wa-k">À deux</span><b>Des films que vous aimerez tous les deux</b><small>Un score commun, fini avant l'heure de coucher la plus tôt</small></div></div>`;
 if(pid==="add"||!PR.list[pid])return "";const p=PR.list[pid],r=resumeOf(pid),nw=newsOf(pid);
 if(!r&&!nw.length)return `<div class="wa-card"><div class="wa-tx"><span class="wa-k">${esc(p.n)}</span><b>Rien en cours</b><small>OK : ouvrir son accueil</small></div></div>`;
 const c=r?(r.it.c||["#334","#111"]):["#334","#111"];
 return `<div class="wa-card">${r?`<div class="wa-th" style="--a:${c[0]};--b:${c[1]}">${r.it.po?`<img src="${r.it.po}" alt="">`:""}<i style="width:${Math.round(r.pct*100)}%"></i></div>`:""}<div class="wa-tx"><span class="wa-k">${esc(p.n)} regardait</span><b>${esc(r?r.it.t:"—")}</b><small>${r?`${r.it.type==="s"?"Série":"Film"} · ${Math.round(r.pct*100)} % vu`:""}</small>${nw.length?`<small class="nw">${nw.length} nouveauté${nw.length>1?"s":""} dans sa liste : ${esc(nw.slice(0,2).map(x=>x.t).join(", "))}</small>`:""}</div>${r?`<div class="wa-hint">▶︎ reprendre tout de suite<br>OK : ouvrir son accueil</div>`:""}</div>`}
/* ---------- branchement ---------- */
{const _pm=fxProfModal;fxProfModal=function(m){if(m.type==="fxwhofull")return whoHtml();return _pm(m)}}
function stopCd(){clearInterval(W.t);W.t=null;W.cd=0}
function startCd(){stopCd();if(!(S.modal&&S.modal.type==="fxwhofull"))return;W.cd=5;W.t=setInterval(()=>{if(!(S.modal&&S.modal.type==="fxwhofull")){stopCd();return}W.cd--;if(W.cd<=0){const g=guess();stopCd();return act("fxprof:"+g)}refresh()},1000)}
function refresh(){const fid=F&&F.dataset.fid;render(fid)}
/* le résumé suit le profil sélectionné */
{const _f=setFocus;setFocus=function(el,inst){_f(el,inst);if(el&&el.closest&&el.closest(".wa")){const r=$("#wares");if(r)r.innerHTML=fxC(resH(el.dataset.pid||guess()));const c=el.dataset.pid&&PR.list[el.dataset.pid]?PR.list[el.dataset.pid].c:"#334";const b=$("#wabg");if(b)b.style.setProperty("--c",c)}}}
{const _k=key;key=function(k){const on=S.modal&&S.modal.type==="fxwhofull";
 if(on&&W.cd&&k!=="play"){stopCd();refresh();if(k==="back")return}
 if(on&&k==="play"&&F&&F.dataset.pid&&PR.list[F.dataset.pid])return act("whoplay:"+F.dataset.pid);
 if(k==="tvhold"&&inApp()&&!S.modal&&(!window.SAval||SAval("pswitch"))){S.modal={type:"fxwho",ret:F&&F.dataset.fid};return render()}
 return _k(k)}}
/* entrée dans un profil : apprentissage de l'heure, accueil teinté, invité effacé en partant */
function tint(id){const p=PR.list[id];if(!p)return;view.classList.remove("wa-enter");void view.offsetWidth;view.classList.add("wa-enter");setBg([p.c,"#08080c"]);setTimeout(()=>view.classList.remove("wa-enter"),700)}
{const _sw=prSwitch;prSwitch=function(id){const was=PR.cur;_sw(id);if(was!==id&&PR.list[was]&&PR.list[was].guest){delete PR.list[was];prSave()}}}
{const _a=act;act=function(a){if(!a)return _a(a);const [k,v,w]=a.split(":");const from=S.modal&&S.modal.type;
 if(k==="whoguest"){stopCd();if(!PR.list.invite)PR.list.invite={n:"Invité",c:"#64748b",emo:"👤",guest:1,bed:23*60,lang:"auto",max:null,pref:{},hist:[],fb:{},seen:[],no:[],split:{},d:{favs:[],prog:{},seasons:{},srcSel:{},lh:[],lg:{},lx:[]}};prSwitch("invite");FXS.duo=null;S.modal=null;S.stack=[{t:"home"}];render();tint("invite");return toast("Mode invité : rien ne sera retenu")}
 if(k==="whoplay"){stopCd();const r=resumeOf(v);learn(v);prSwitch(v);FXS.duo=null;S.modal=null;S.stack=[{t:"home"}];render();tint(v);if(!r)return toast(`${hello()} ${PR.list[v].n} · rien en cours`);toast(`▶︎ ${PR.list[v].n} · reprise de ${r.it.t}`);return act("play:"+r.it.id)}
 if((k==="fxprof"||k==="fxduo")&&from==="fxwhofull"){stopCd();if(k==="fxprof")learn(v);const r=_a(a);tint(k==="fxduo"?v:v);if(k==="fxprof")toast(`${hello()} ${PR.list[v].n}`);return r}
 return _a(a)}}
/* l'écran s'ouvre : on lance le compte à rebours (une fois) */
{const _r=render;render=function(fid){_r(fid);if(S.modal&&S.modal.type==="fxwhofull"&&!W.started&&!S.loading){W.started=true;startCd();refresh()}if(!(S.modal&&S.modal.type==="fxwhofull"))W.started=false}}
/* maintenir le bouton 📺 (télécommande) ou la touche H : changer de profil depuis n'importe où */
{document.querySelectorAll('.remote [data-k="home"]').forEach(b=>{let t=null,held=false;b.addEventListener("pointerdown",e=>{held=false;t=setTimeout(()=>{held=true;key("tvhold")},600)},true);
  b.addEventListener("pointerdown",e=>{if(t){e.stopImmediatePropagation()}},true);
  ["pointerup","pointerleave","pointercancel"].forEach(ev=>b.addEventListener(ev,e=>{const was=t;clearTimeout(t);t=null;if(ev==="pointerup"&&was&&!held)key("home")},true))})}
{let ht=null,hh=false;window.addEventListener("keydown",e=>{if(e.key!=="h"&&e.key!=="H")return;const a=document.activeElement;if(a&&(a.tagName==="INPUT"||a.tagName==="TEXTAREA"))return;if(inApp()&&S.tab==="search"&&topS().t==="home"&&!S.modal)return;e.preventDefault();e.stopImmediatePropagation();if(e.repeat||ht)return;hh=false;ht=setTimeout(()=>{hh=true;key("tvhold")},600)},true);
 window.addEventListener("keyup",e=>{if(e.key!=="h"&&e.key!=="H")return;if(!ht&&!hh)return;clearTimeout(ht);const was=ht;ht=null;if(was&&!hh)key("home");hh=false},true)}
window.__who={guess,resumeOf,newsOf,learn};
})();
