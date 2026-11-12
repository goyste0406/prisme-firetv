/* ========================= GUIDE TV · version A (fiche en haut, grille dessous) =========================
   Une ligne par chaîne (les sources d'une même chaîne sont réunies), ligne rouge « maintenant », Retour = maintenant,
   replay, rappels et bascule automatique, jours et « Ce soir », genres en couleur, navigation qui garde l'heure,
   numéro de chaîne au clavier, progression, journée de 6 h à 6 h. */
(function(){
LIC["Guide TV"]='<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18M9 9v11M15 9v11"/>';
const G=window.GD={ci:0,r0:0,T:0,t0:0,day:0,zone:"grid",f:null,af:0,genre:null,num:"",numT:0,auto:new Set(),src:{}};
const W=150,CW=190,RH=52,ROWS=6,TOP=342,PPM=(1200-CW-4)/W;
const NOWM=()=>Math.floor(nowMin());
const b0=()=>NOWM()<360?-1:0;                         /* avant 6 h, on est encore dans la soirée d'hier */
const dS=d=>360+(d+b0())*1440,dE=d=>dS(d)+1440;
const f30=m=>Math.floor(m/30)*30;
const DAYN=d=>{const x=d+b0();if(d===0)return "Aujourd'hui";if(d===-1)return "Hier";if(d===1)return "Demain";const dt=new Date();dt.setDate(dt.getDate()+x);return dt.toLocaleDateString("fr-FR",{weekday:"long"}).replace(/^./,c=>c.toUpperCase())};
/* chaînes : une seule ligne par chaîne, même avec plusieurs sources ou des noms différents chez chaque fournisseur */
let CHL=null,CHK="";
function chList(){const L=lvis(),k=L.map(c=>c.id).join(",");if(CHL&&CHK===k)return CHL;const seen=new Set(),out=[];
 for(const c of L){const n=RI.strip(RI.base(c.n)).replace(/\b(sat|tnt|backup|bk|secours|alt|vip|raw|hd|fhd|uhd|sd|4k|hevc)\b/g,"").replace(/[^a-z0-9+]/g,"");if(n&&seen.has(n))continue;seen.add(n);out.push(c)}CHK=k;return CHL=out}
const SRCL=c=>srcs("ch:"+c.id).slice().sort((a,b)=>qr(b.q)-qr(a.q));
/* programmes d'une journée, trous comblés par « Programme non communiqué » */
const PGC={};
function progs(c,d){const k=c.id+"|"+d+"|"+(EPGC[c.id]?EPGC[c.id].length:0);if(PGC[k])return PGC[k];const a=dS(d),b=dE(d);
 const L=epg(c).filter(p=>p.e>a&&p.s<b&&p.t!=="Programme non communiqué").sort((x,y)=>x.s-y.s),out=[];let t=a;
 const gap=(s,e)=>{for(let x=s;x<e;){const y=Math.min(e,f30(x)+60);out.push({c,s:x,e:y,t:"Programme non communiqué",g:"",fill:1});x=y}};
 for(const p of L){const s=Math.max(p.s,t);if(s>t)gap(t,s);if(p.e>s){out.push({c,s,e:Math.min(p.e,b),os:p.s,oe:p.e,t:p.t,g:p.g,img:p.img});t=Math.min(p.e,b)}}
 if(t<b)gap(t,b);return PGC[k]=out}
const isNow=p=>p.s<=nowMin()&&p.e>nowMin(),isPast=p=>p.e<=nowMin();
const canRep=p=>isPast(p)&&!p.fill&&arDays(p.c)&&(p.os??p.s)>=nowMin()-arDays(p.c)*1440;
const gen=p=>p.fill?"":pgen(p);
const curP=()=>{const C=chList(),c=C[G.ci];if(!c)return null;const L=progs(c,G.day);return L.find(p=>p.s<=G.T&&p.e>G.T)||L[L.length-1]};
function fixRows(){const n=chList().length;G.ci=Math.max(0,Math.min(G.ci,n-1));if(G.ci<G.r0)G.r0=G.ci;if(G.ci>=G.r0+ROWS)G.r0=G.ci-ROWS+1;G.r0=Math.max(0,Math.min(G.r0,n-ROWS))}
function toNow(){G.day=0;G.T=nowMin();G.t0=Math.max(dS(0),f30(nowMin())-30);fixRows()}
/* ---------- rendu ---------- */
const rem=p=>LS.rem&&LS.rem[p.c.id+":"+Math.round(p.os??p.s)];
function cell(p){const t0=G.t0,a=Math.max(p.s,t0),b=Math.min(p.e,t0+W);if(b<=a)return "";const x=(a-t0)*PPM,w=(b-a)*PPM-4,foc=G.zone==="grid"&&p.c===chList()[G.ci]&&p.s<=G.T&&p.e>G.T;
 const g=gen(p),gm=G.genre&&g===G.genre,dim=G.genre&&!gm,now=isNow(p),pct=now?Math.round((nowMin()-(p.os??p.s))/((p.oe??p.e)-(p.os??p.s))*100):0,ic=rem(p)?"🔔":canRep(p)?"↺":"";
 return `<div class="gd-pc ${isPast(p)?"past":""} ${now?"now":""} ${gm?"gm":""} ${dim?"dim":""} ${p.fill?"fill":""} ${foc?"foc":""}" style="left:${x}px;width:${Math.max(w,6)}px;--gc:${LGC[g]||"#888"}" data-gp="${p.c.id}|${p.s}">${w>60?`<b>${p.s<t0?"‹ ":""}${esc(p.t)}</b><small>${fmt(p.os??p.s)} – ${fmt(p.oe??p.e)}${now?` · encore ${Math.max(1,Math.round((p.oe??p.e)-nowMin()))} min`:""}</small>`:""}${ic&&w>40?`<span class="ic">${ic}</span>`:""}${now?`<span class="pg" style="width:${pct}%"></span>`:""}</div>`}
const logoH=c=>{const lg=typeof imgLogo==="function"?imgLogo(c):"";return lg?`<span class="gd-lg im"><img src="${esc(lg)}" alt=""></span>`:`<span class="gd-lg" style="background:${c.col||"#334"}">${esc(c.n.slice(0,8))}</span>`};
function gridH(){const C=chList(),t0=G.t0,n=nowMin();let h=`<div class="gd-grid" style="top:${TOP}px"><div class="gd-hd">`;
 for(let m=f30(t0)+30;m<t0+W;m+=30)h+=`<span style="left:${(m-t0)*PPM}px">${fmt(m)}</span>`;
 h+=`</div><div style="position:relative">`;
 for(let r=G.r0;r<Math.min(C.length,G.r0+ROWS);r++){const c=C[r],ns=SRCL(c).length;
  h+=`<div class="gd-row"><div class="gd-ch ${r===G.ci?"cur":""}" data-gc="${r}">${logoH(c)}<span style="min-width:0"><b>${esc(c.n)}</b><small>${c.num||r+1}${arDays(c)?" · replay":""}${ns>1?` · <i>${ns} sources</i>`:""}</small></span></div><div class="gd-tr">${progs(c,G.day).map(cell).join("")}</div></div>`}
 if(n>=t0&&n<t0+W&&G.day===0)h+=`<div class="gd-now" style="left:${CW+4+(n-t0)*PPM}px"></div>`;
 return h+`</div></div>`}
function acts(p){const B=[];if(p.fill)return [["Pas d'information pour ce créneau","none"]];
 if(isNow(p))B.push(["▶︎ Regarder","watch"],[arDays(p.c)?"↺ Reprendre au début":"Pas de reprise au début (pas de replay)",arDays(p.c)?"start":"none"]);
 else if(isPast(p))B.push(canRep(p)?["↺ Revoir en replay","replay"]:["Pas de replay pour ce programme","none"]);
 else B.push([rem(p)?"🔕 Retirer le rappel":"🔔 Me prévenir 2 min avant","rem"],[G.auto.has(p.c.id+":"+p.s)?"⏹ Annuler la bascule":"⏯ Basculer automatiquement à "+fmt(p.os??p.s),"auto"]);
 if(SRCL(p.c).length>1)B.push([`Choisir la source (${SRCL(p.c).length})`,"src"]);return B}
function prevH(){const p=curP();if(!p)return `<div class="gd-prev"><h2>Aucune chaîne</h2></div>`;const c=p.c,now=isNow(p),past=isPast(p),n=nowMin(),S0=p.os??p.s,E0=p.oe??p.e,pct=now?Math.round((n-S0)/(E0-S0)*100):0,L=SRCL(c);
 const lab=now?'<span class="lbd">EN DIRECT</span>':canRep(p)?'<span class="lbd rp">REPLAY</span>':past?'<span class="lbd soon">TERMINÉ</span>':rem(p)?'<span class="lbd soon">🔔 RAPPEL</span>':'<span class="lbd soon">À VENIR</span>';
 const when=now?` · encore ${Math.max(1,Math.round(E0-n))} min`:past?"":` · dans ${S0-n>=60?Math.floor((S0-n)/60)+" h "+String(Math.round(S0-n)%60).padStart(2,"0"):Math.round(S0-n)+" min"}`;
 return `<div class="gd-prev"><div class="gd-art">${lth(c,lab,p.fill?{t:c.n,g:""}:p)}</div>
 <div class="gd-txt"><div class="k">${esc(c.n)} · ${c.num||G.ci+1}${gen(p)?" · "+esc(gen(p)):""}</div><h2>${esc(p.t)}</h2><div class="meta">${DAYN(G.day)} · ${fmt(S0)} – ${fmt(E0)} · ${Math.round(E0-S0)} min${when}</div>
 ${now?`<div class="gd-ppg"><i style="width:${pct}%"></i></div>`:""}
 <div class="gd-src">${L.map((v,i)=>`<span><i style="background:${v.p.col||(window.PVCOL?PVCOL[S.playlists.indexOf(v.p)%PVCOL.length]:"#888")}"></i>${esc(v.p.name)} · ${v.q}${i===0?" (meilleure)":""}</span>`).join("")}${L.length>1?'<span class="m">· une seule chaîne, bascule auto si une source coupe</span>':""}</div>
 <div class="gd-acts">${G.zone==="acts"?acts(p).map((b,i)=>`<span class="gd-ab ${G.af===i?"foc":""}" data-gab="${i}">${esc(b[0])}</span>`).join(""):`<span class="gd-tag">OK : ${p.fill?"rien à faire":now?"regarder ou reprendre au début":canRep(p)?"revoir en replay":past?"détails":"me prévenir ou basculer à l'heure"}</span><span class="gd-tag">Retour : maintenant · encore Retour : quitter</span><span class="gd-tag">Aperçu sans vidéo : ta connexion reste libre</span>`}</div></div></div>`}
const TOPS=()=>[...[-1,0,1,2,3,4,5].map(d=>"d"+d),"tonight","nowb",...LGEN.map(g=>"g-"+g)];
function chipsH(){return `<div class="gd-bar" id="gdbar">${TOPS().map(id=>{let t,sel=false;if(id[0]==="d"){const d=+id.slice(1);t=DAYN(d);sel=G.day===d}else if(id==="tonight")t="🌙 Ce soir 21:00";else if(id==="nowb")t="⏺ Maintenant";else{const g=id.slice(2);t=`<i style="background:${LGC[g]}"></i>${esc(g)}`;sel=G.genre===g}
 return `<span class="gd-chip ${sel?"sel":""} ${G.zone==="top"&&G.f===id?"foc":""}" data-gt="${id}">${t}</span>`}).join("")}</div>`}
function guideHtml(){let cue="";if(G.genre){const n=chList().reduce((a,c)=>a+progs(c,G.day).filter(p=>gen(p)===G.genre&&p.s>=21*60+(G.day+b0())*1440&&p.s<23*60+(G.day+b0())*1440).length,0);cue=`<div class="gd-cue">${n} programme${n>1?"s":""} ${esc(G.genre.toLowerCase())} ce soir entre 21:00 et 23:00</div>`}
 return `<div class="gd" id="gd"><div class="gd-title">${lsvg("Guide TV")}Guide TV</div><div class="clock">${fmt(nowMin())}</div>${prevH()}${chipsH()}${cue}${gridH()}${G.num?`<div class="gd-num">${esc(G.num)}<small>${esc((chList().find((c,i)=>String(c.num||i+1)===G.num)||{n:"…"}).n)}</small></div>`:""}</div>`}
function morph(a,b){const an=[...a.childNodes],bn=[...b.childNodes];
 for(let i=0;i<bn.length;i++){const x=an[i],y=bn[i];if(!x){a.appendChild(y);continue}
  if(x.nodeType!==y.nodeType||(x.nodeType===1&&(x.tagName!==y.tagName||(x.dataset.gp||"")!==(y.dataset.gp||""))))a.replaceChild(y,x);
  else if(x.nodeType===3){if(x.data!==y.data)x.data=y.data}
  else if(x.nodeType===1){for(const at of [...x.attributes])if(!y.hasAttribute(at.name))x.removeAttribute(at.name);for(const at of [...y.attributes])if(x.getAttribute(at.name)!==at.value)x.setAttribute(at.name,at.value);morph(x,y)}
  else a.replaceChild(y,x)}
 while(a.childNodes.length>bn.length)a.removeChild(a.lastChild)}
function gRender(){if(topS().t!=="lguide")return;if(S.modal&&!view.querySelector("#gd"))return render();const g=$("#gd");const t=document.createElement("template");t.innerHTML=guideHtml();if(g)morph(g,t.content.firstElementChild);else view.insertAdjacentHTML("afterbegin",guideHtml());
 const bar=$("#gdbar"),fc=bar&&bar.querySelector(".foc");if(fc){const a=fc.offsetLeft,w=fc.offsetWidth;if(a+w>bar.scrollLeft+bar.clientWidth-10)bar.scrollLeft=a+w-bar.clientWidth+40;else if(a<bar.scrollLeft)bar.scrollLeft=Math.max(0,a-40)}
 const c=chList()[G.ci];if(c)setBg([c.col||"#1a1a22","#08080c"])}
/* ---------- navigation ---------- */
function ensureT(p){if(p.s>=G.t0+W-20)G.t0=f30(p.s)-30;if(p.e<=G.t0+10||(p.s<G.t0&&p.e-G.t0<25))G.t0=f30(p.s);G.t0=Math.max(dS(G.day),Math.min(G.t0,dE(G.day)-W));G.T=Math.max(p.s,G.t0)+1}
const DMIN=-1,DMAX=5;
function gridKey(k){const C=chList(),c=C[G.ci];if(!c)return;const L=progs(c,G.day),p=curP(),i=L.indexOf(p);
 if(k==="right"){const n=L[i+1];if(!n){if(G.day<DMAX){G.day++;G.t0=dS(G.day);G.T=G.t0+1;toast(DAYN(G.day))}return gRender()}ensureT(n);return gRender()}
 if(k==="left"){const n=L[i-1];if(!n){if(G.day>DMIN){G.day--;G.t0=dE(G.day)-W;G.T=dE(G.day)-1;toast(DAYN(G.day))}return gRender()}ensureT(n);return gRender()}
 if(k==="up"){if(G.ci===0){G.zone="top";G.f=TOPS().includes(G.f)?G.f:"d"+G.day;return gRender()}G.ci--;fixRows();return gRender()}
 if(k==="down"){if(G.ci<C.length-1){G.ci++;fixRows()}return gRender()}
 if(k==="ok"){G.zone="acts";G.af=0;return gRender()}
 if(k==="back"||k==="play"){if(k==="back"&&G.day===0&&Math.abs(G.T-nowMin())<30)return quit();toNow();gRender();return toast("Retour à maintenant · "+fmt(nowMin())+" · encore Retour pour quitter le guide")}}
function quit(){S.stack.pop();render(topS().last||"lsv-Guide TV")}
function topKey(k){const ids=TOPS(),i=ids.indexOf(G.f);
 if(k==="left"&&i>0){G.f=ids[i-1];return gRender()}if(k==="right"&&i<ids.length-1){G.f=ids[i+1];return gRender()}
 if(k==="ok")return chipAct(G.f);if(k==="down"||k==="back"){G.zone="grid";return gRender()}return gRender()}
function chipAct(id){if(id[0]==="d"){G.day=+id.slice(1);if(G.day===0)toNow();else{G.t0=21*60-60+(G.day+b0())*1440;G.T=21*60+(G.day+b0())*1440+1}G.zone="grid";gRender();return toast(DAYN(G.day))}
 if(id==="tonight"){G.T=21*60+(G.day+b0())*1440+11;G.t0=21*60-30+(G.day+b0())*1440;G.zone="grid";gRender();return toast("Ce soir à partir de 21:00")}
 if(id==="nowb"){toNow();G.zone="grid";return gRender()}
 const g=id.slice(2);G.genre=G.genre===g?null:g;if(G.genre){G.T=21*60+(G.day+b0())*1440+11;G.t0=21*60-30+(G.day+b0())*1440}return gRender()}
function actDo(p,k){const c=p.c,S0=Math.round(p.os??p.s);
 if(k==="watch")return act("lp:"+c.id);
 if(k==="start"||k==="replay")return lreplay(c.id,p.os??p.s);
 if(k==="none")return toast(p.fill?"Le guide de ton fournisseur ne donne rien pour ce créneau":"Cette chaîne ne propose pas le replay");
 if(k==="rem"){LS.rem=LS.rem||{};const key=c.id+":"+S0;if(LS.rem[key]){delete LS.rem[key];lsave();gRender();return toast("Rappel retiré")}LS.rem[key]=1;lsave();gRender();return toast(`🔔 Rappel : ${p.t} à ${fmt(S0)} · prévenu 2 min avant`)}
 if(k==="auto"){const key=c.id+":"+p.s;if(G.auto.has(key)){G.auto.delete(key);gRender();return toast("Bascule annulée")}G.auto.add(key);LS.rem=LS.rem||{};LS.rem[c.id+":"+S0]=1;lsave();gRender();return toast(`⏯ À ${fmt(S0)}, prisme passera tout seul sur ${c.n}`)}
 if(k==="src"){S.modal={k:"ch:"+c.id,ret:null};return render()}}
function gKey(k){if(G.num&&k==="ok")return numGo();
 if(G.zone==="top")return topKey(k);
 if(G.zone==="acts"){const p=curP(),B=acts(p);if(k==="left"&&G.af>0)G.af--;else if(k==="right"&&G.af<B.length-1)G.af++;else if(k==="ok"){const r=B[G.af][1];G.zone="grid";gRender();return actDo(p,r)}else G.zone="grid";return gRender()}
 return gridKey(k)}
function numGo(){const C=chList(),i=C.findIndex((c,j)=>String(c.num||j+1)===G.num);G.num="";clearTimeout(G.numT);if(i<0){gRender();return toast("Pas de chaîne à ce numéro")}G.ci=i;G.zone="grid";fixRows();gRender();toast(`${C[i].num||i+1} · ${C[i].n}`)}
/* rappels : 2 min avant, et bascule automatique à l'heure */
setInterval(()=>{if(!inApp()||!LS.rem)return;const n=nowMin();for(const key in LS.rem){const [id,s]=key.split(":"),t=+s;if(!CH[id])continue;
 if(t-n<=2&&t-n>1.9-1/60&&!LS.rem[key+"w"]){LS.rem[key+"w"]=1;toast(`🔔 Dans 2 min sur ${CH[id].n} : ${(epg(CH[id]).find(p=>Math.round(p.s)===t)||{t:""}).t}`)}
 const ak=[...G.auto].find(x=>x.startsWith(id+":")&&Math.abs(+x.split(":")[1]-t)<1);if(ak&&n>=t&&n<t+1){G.auto.delete(ak);toast(`⏯ C'est l'heure : ${CH[id].n}`);act("lp:"+id)}}},15000);
/* ---------- branchement ---------- */
function open(){toNow();G.zone="grid";const c=CH[S.lch];if(c){const i=chList().indexOf(c);if(i>=0){G.ci=i;fixRows()}}push({t:"lguide"})}
window.gdOpen=open;
{const _ls=lsideHtml;lsideHtml=function(){const h=_ls();const item=`<div class="lsi" data-f data-fid="lsv-Guide TV" data-row="lside" data-act="lguide">${lsvg("Guide TV")}<span>Guide TV</span><small>${chList().length}</small></div>`;const j=h.indexOf('lsv-Accueil'),i=j<0?-1:h.indexOf('<div class="lsi',j);return i>0?h.slice(0,i)+item+h.slice(i):h}}
{const _a=act;act=function(a){if(a==="lguide")return open();return _a(a)}}
/* la page du guide ; une fenêtre ouverte par-dessus (choix de la source…) est gardée telle que le simulateur l'a dessinée */
{const _r=render;render=function(fid){_r(fid);if(inApp()&&topS().t==="lguide"){const m=view.querySelector(".modal");view.innerHTML=guideHtml();if(m)view.appendChild(m);gRender()}}}
{const _k=key;key=function(k){if(inApp()&&topS().t==="lguide"&&!S.modal&&!S.loading){if(["up","down","left","right","ok","back","play"].includes(k))return gKey(k);if(k==="home"||k==="mic"||k==="menu")return _k(k);return}return _k(k)}}
document.addEventListener("keydown",e=>{if(!(inApp()&&topS().t==="lguide"&&!S.modal))return;if(/^[0-9]$/.test(e.key)){e.preventDefault();e.stopImmediatePropagation();G.num=(G.num+e.key).slice(-3);clearTimeout(G.numT);G.numT=setTimeout(numGo,1300);gRender()}},true);
view.addEventListener("click",e=>{if(!(inApp()&&topS().t==="lguide"&&!S.modal))return;
 const ab=e.target.closest("[data-gab]");if(ab){G.af=+ab.dataset.gab;return gKey("ok")}
 const pc=e.target.closest("[data-gp]");if(pc){const [id,s]=pc.dataset.gp.split("|");const C=chList(),i=C.findIndex(c=>c.id===id);const was=G.zone==="grid"&&G.ci===i&&+s<=G.T&&curP()&&curP().s===+s;G.zone="grid";G.ci=i;G.T=Math.max(+s,G.t0)+1;fixRows();if(was)return gKey("ok");return gRender()}
 const ch=e.target.closest("[data-gt]");if(ch){G.f=ch.dataset.gt;G.zone="top";return chipAct(G.f)}
 const gc=e.target.closest("[data-gc]");if(gc){G.ci=+gc.dataset.gc;toNow();G.ci=+gc.dataset.gc;fixRows();return gRender()}});
setInterval(()=>{if(inApp()&&topS().t==="lguide"&&!S.modal)gRender()},30000);
window.__gd={chList,progs,curP,G,gKey};
})();
