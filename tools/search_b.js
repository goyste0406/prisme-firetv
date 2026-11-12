/* ========================= RECHERCHE · version B (clavier en grille, liste filtrable, aperçu) =========================
   Une seule recherche (films, séries, chaînes, programmes en direct, acteurs), fautes de frappe pardonnées, phrases comprises,
   Siri (simulé), « À la TV maintenant », « Où le regarder », recherches récentes et tendances, clavier de l'iPhone. */
(function(){
const SV='viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sric" aria-hidden="true"';
const IC={clock:`<svg ${SV}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>`,spark:`<svg ${SV}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6"/></svg>`,
 phone:`<svg ${SV}><rect x="7" y="2" width="10" height="20" rx="2.5"/><path d="M11 18h2"/></svg>`,mic:`<svg ${SV}><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>`,
 trend:`<svg ${SV}><path d="M3 17l6-6 4 4 8-8"/><path d="M14 7h7v7"/></svg>`};
const SR=window.SR={filt:"all",sel:null,siri:false};
const nz=t=>norm(String(t||"")).replace(/[^a-z0-9 ]+/g," ").replace(/\s+/g," ").trim();
const KEYS2="abcdefghijklmnopqrstuvwxyz1234567890".split("");
const FILT=[["all","Tout"],["f","Films"],["s","Séries"],["tv","TV en direct"],["actor","Acteurs"]];
/* ---------- index : titres, chaînes, programmes en cours, acteurs ---------- */
function lev(a,b){if(Math.abs(a.length-b.length)>1)return 9;const n=b.length,d=[...Array(n+1).keys()];for(let i=1;i<=a.length;i++){let p=d[0];d[0]=i;for(let j=1;j<=n;j++){const t=d[j];d[j]=Math.min(d[j]+1,d[j-1]+1,p+(a[i-1]===b[j-1]?0:1));p=t}}return d[n]}
/* chaque mot cherché doit commencer un mot du texte, ou en être à une faute près (mots de 4 lettres et plus) */
function wscore(q,text){const Q=nz(q).split(" ").filter(Boolean);if(!Q.length)return null;const W=nz(text).split(" ");let s=0,fuz=false;
 for(const w of Q){let b=0;for(const x of W){if(x===w){b=3;break}if(x.startsWith(w))b=Math.max(b,2);else if((w.length>=4||(Q.length>1&&w.length>=2&&x.length<=w.length+1))&&(lev(w,x)<=1||(w.length>=4&&lev(w,x.slice(0,w.length))<=1)))b=Math.max(b,1.4)}if(!b)return null;if(b===1.4)fuz=true;s+=b}
 return {s:s/Q.length,fuz}}
const actName=a=>(typeof A!=="undefined"&&A[a])||a;
function actorIndex(){const M={};for(const it of [...films(),...series()])for(const c of it.cast||[]){const a=Array.isArray(c)?c[0]:c;if(!a)continue;(M[a]=M[a]||[]).push(it)}return M}
const nowList=()=>chans().map(c=>({c,p:epgAt(c).cur})).filter(x=>x.p&&x.p.t!=="Programme non communiqué");
const genOf=it=>(it.g||[]).map(nz).join(" ");
const verOf=it=>{const L=srcs(it.id),T=[...new Set(L.map(v=>v.fr&&v.fr!=="VF"?v.fr:v.tag||"VF"))],Q=L.some(v=>v.q==="4K")?" 4K":"";return T.slice(0,3).join(" · ")+Q};
const provOf=it=>[...new Set(srcs(it.id).map(v=>v.p&&v.p.name).filter(Boolean))];
const pcol=name=>{const p=S.playlists.find(x=>x.name===name);return (p&&p.col)||(window.PVCOL?PVCOL[(S.playlists.indexOf(p)+0)%PVCOL.length]:"#888")};
/* ---------- phrases comprises ---------- */
const GEN={"comedie":["comedie","comedies","drole","droles","rire","humour"],"action":["action"],"policier":["policier","policiers","polar","enquete","crime"],"animation":["animation","anime","animes","dessin","dessins"],"drame":["drame","drames"],
 "science fiction":["sf","science","science-fiction"],"horreur":["horreur","peur","epouvante"],"romance":["romance","romantique","amour"],"thriller":["thriller","suspense"],"aventure":["aventure","aventures"],"documentaire":["documentaire","docu"]};
function parse(q,AI){const n=" "+nz(q)+" ",f={g:[],dec:null,short:false,tonight:false,vost:false,kids:false,live:false,match:false,actor:null,kind:null};
 for(const [g,L] of Object.entries(GEN))if(L.some(w=>n.includes(" "+w+" ")))f.g.push(g);
 if(/ (enfant|enfants|famille|kids|jeunesse) /.test(n))f.kids=true;
 const d=n.match(/ annees? (19)?([2-9]0) | (19[5-9]0|20[0-2]0)s? /);if(d){const x=d[2]||(d[3]&&d[3].slice(2,4));f.dec=+x<30?2000+ +x:1900+ +x}
 if(/ (court|courte|courts|rapide|pas trop long) /.test(n))f.short=true;
 if(/ (ce soir|avant de dormir|avant le coucher) /.test(n)||n.includes(" ce soir "))f.tonight=true;
 if(/ (vostfr|vost|version originale|en vo) /.test(n))f.vost=true;
 if(/ (a la tv|a la tele|en direct|qui passe) /.test(n))f.live=true;
 if(/ (match|foot|football|ligue|sport|rugby) /.test(n)){f.match=true;f.live=true}
 if(/ (film|films) /.test(n))f.kind="f";if(/ (serie|series) /.test(n))f.kind="s";
 for(const a of Object.keys(AI)){const p=nz(actName(a)).split(" ");if(p.length>1&&p.every(w=>n.includes(" "+w+" ")||(w.length>3&&n.split(" ").some(x=>x.length>3&&lev(x,w)<=1)))){f.actor=a;break}}
 return f.g.length||f.dec||f.short||f.tonight||f.vost||f.kids||f.live||f.actor||f.kind?f:null}
function nlRes(f,AI){const why=[];
 if(f.live){const L=nowList().filter(x=>!f.match||/sport|foot|match|ligue|rugby|tennis/.test(nz(x.p.g+" "+x.p.t))||(typeof pgen==="function"&&pgen(x.p)==="Sport"));why.push(f.match?"les matchs en direct maintenant":"à la TV maintenant");return {L:L.map(x=>({tv:x})),why}}
 let L=[...films(),...series()];if(f.kind)L=L.filter(it=>it.type===f.kind);
 if(f.actor){L=L.filter(it=>(AI[f.actor]||[]).includes(it));why.push("avec "+actName(f.actor))}
 if(f.g.length){L=L.filter(it=>f.g.every(g=>genOf(it).includes(g.split(" ")[0])));why.push(f.g.map(g=>({comedie:"comédie",policier:"policier","science fiction":"science-fiction",documentaire:"documentaire"})[g]||g).join(" et "))}
 if(f.kids){L=L.filter(it=>/anim|famil|jeunesse|enfant/.test(genOf(it))||/tous/i.test(it.age||""));why.push("pour les enfants")}
 if(f.dec){L=L.filter(it=>it.y>=f.dec&&it.y<f.dec+10);why.push("des années "+String(f.dec).slice(2))}
 if(f.vost){L=L.filter(it=>srcs(it.id).some(v=>v.tag==="VOSTFR"));why.push("en VOSTFR")}
 const bed=(ME().bed==null?23*60:ME().bed),n=nowMin();
 if(f.short){L=L.filter(it=>it.type==="f"&&it.d<=105);why.push("de moins d'1 h 45")}
 if(f.tonight){L=L.filter(it=>it.type!=="f"||n+it.d<=bed+(bed<n?1440:0));why.push(`finis avant ${fmt(bed)}, ton heure du coucher`)}
 return {L:L.slice(0,40).map(it=>({it})),why}}
/* ---------- recherche ---------- */
let CACHE={q:null};
function search(q){if(CACHE.q===q&&CACHE.n===films().length+series().length)return CACHE.r;const r={live:[],f:[],s:[],a:[],fuz:false,nl:null};const AI=actorIndex();
 let ne=0,nf=0;if(q.trim()){const sc=[];for(const it of [...films(),...series()]){const a=wscore(q,it.t),b=it.dir?wscore(q,it.dir):null;const m=Math.max(a?a.s:0,b?b.s*.7:0);if(m){sc.push([it,m]);if(a&&a.fuz&&a.s===m)nf++;else ne++}}
  sc.sort((x,y)=>y[1]-x[1]||((y[0].y||0)-(x[0].y||0)));for(const [it] of sc)(it.type==="f"?r.f:r.s).push(it);
  for(const x of nowList()){const a=wscore(q,x.c.n),b=wscore(q,x.p.t);if(a||b){r.live.push(x);if((a&&a.fuz&&!b)||(b&&b.fuz&&!a))nf++;else ne++}}
  /* un film qui passe en ce moment à la TV apparaît aussi dans « À la TV maintenant » */
  for(const it of r.f.slice(0,20))for(const x of nowList())if(nz(x.p.t)===nz(it.t)&&!r.live.includes(x))r.live.unshift(x);
  for(const a of Object.keys(AI)){const s=wscore(q,actName(a));if(s&&s.s>=1.4){r.a.push(a);if(s.fuz)nf++;else ne++}}
  r.a.sort((x,y)=>AI[y].length-AI[x].length);r.fuz=nf>0&&ne===0;
  const f=parse(q,AI);if(f&&(!sc.length||sc[0][1]<2.5||f.g.length||f.dec||f.short||f.live||f.tonight||f.kids)){const n=nlRes(f,AI);if(n.L.length)r.nl=n}}
 r.f=r.f.slice(0,40);r.s=r.s.slice(0,40);r.a=r.a.slice(0,12);r.AI=AI;CACHE={q,r,n:films().length+series().length};return r}
/* ---------- rendu ---------- */
const sub=it=>it.type==="f"?`${it.y} · ${Math.floor(it.d/60)} h ${String(it.d%60).padStart(2,"0")} · ${(it.g||[])[0]||""}`:`Série · ${it.se?it.se.length+" saison"+(it.se.length>1?"s":""):""}${it.net?" · "+it.net:""}`;
const th=(c,cls,txt)=>`<div class="sr-th ${cls||""}" style="--a:${c[0]};--b:${c[1]||"#111"}">${txt||""}</div>`;
function rowIt(it,grp){const pr=S.prog[it.id];return `<div class="sr-lst" data-f data-fid="sr-${grp}-${it.id}" data-act="open:${it.id}" data-hov="${it.id}" data-srsel="${it.id}">${th(it.c||["#334","#111"])}<div class="tx"><b>${esc(it.t)}</b><small>${esc(sub(it))}</small><small>${esc([verOf(it),provOf(it).join(" et ")].filter(Boolean).join(" · "))}${pr?` · reprendre à ${Math.round(pr*100)} %`:""}</small></div>${it.type==="s"?'<span class="sr-tg">SÉRIE</span>':""}</div>`}
function rowTv(x,grp){const {c,p}=x,pct=Math.max(0,Math.min(100,Math.round((nowMin()-p.s)/(p.e-p.s)*100)));const logo=typeof imgLogo==="function"?imgLogo(c):"";
 return `<div class="sr-lst" data-f data-fid="sr-${grp}-ch${c.id}" data-act="live:${c.id}" data-hov="ch:${c.id}" data-srsel="ch:${c.id}">${th([c.col||"#334","#111"],"sr-w",logo?`<img src="${logo}" alt="">`:esc(c.n))}<div class="tx"><b>${esc(p.t)}</b><small>${esc(c.n)} · ${fmt(p.s)} – ${fmt(p.e)}</small><div class="sr-pg"><i style="width:${pct}%"></i></div></div><span class="sr-tg sr-live">DIRECT</span></div>`}
function rowActor(a,AI){const n=actName(a),L=AI[a]||[];return `<div class="sr-lst" data-f data-fid="sr-a-${a}" data-act="${typeof A!=="undefined"&&A[a]?"actor:"+a:"srq:"+n}" data-srsel="a:${a}">${th(["#5b6f99","#1a1d26"],"sr-av",esc(n.split(" ").map(w=>w[0]).join("").slice(0,2)))}<div class="tx"><b>${esc(n)}</b><small>${esc(L.slice(0,3).map(x=>x.t).join(" · "))}</small></div></div>`}
function listH(r){const g=(t,ic)=>`<div class="sr-gh">${ic||""}${esc(t)}</div>`;
 if(!S.q.trim()){const rec=(ME().recent||[]).slice(0,5),trend=[...films(),...series()].sort((a,b)=>trendScore(b)-trendScore(a)).slice(0,6),live=nowList().slice(0,6);
  return (rec.length?g("Recherches récentes",IC.clock)+rec.map((q,i)=>`<div class="sr-lst" data-f data-fid="sr-rc-${i}" data-act="srq:${esc(q)}">${th(["#33384a","#1a1d26"],"sr-w",IC.clock)}<div class="tx"><b>${esc(q)}</b><small>recherché récemment</small></div></div>`).join(""):"")
   +g("Tendances cette semaine",IC.trend)+trend.map(it=>rowIt(it,"tr")).join("")+g("En ce moment à la TV")+live.map(x=>rowTv(x,"lv")).join("")}
 let h=r.fuz?`<div class="sr-why">${IC.spark}Résultats pour une orthographe proche de « ${esc(S.q)} »</div>`:"";const F=SR.filt;
 if(r.nl&&F==="all")h+=g("Ce que tu demandes : "+r.nl.why.join(", "),IC.spark)+r.nl.L.map(x=>x.tv?rowTv(x.tv,"nl"):rowIt(x.it,"nl")).join("");
 if((F==="all"||F==="tv")&&r.live.length)h+=g("À la TV maintenant")+r.live.slice(0,12).map(x=>rowTv(x,"lv")).join("");
 if((F==="all"||F==="f")&&r.f.length)h+=g("Films")+r.f.map(it=>rowIt(it,"f")).join("");
 if((F==="all"||F==="s")&&r.s.length)h+=g("Séries")+r.s.map(it=>rowIt(it,"s")).join("");
 if((F==="all"||F==="actor")&&r.a.length)h+=g("Acteurs")+r.a.map(a=>rowActor(a,r.AI)).join("");
 return h||`<div class="sr-empty">Rien pour « ${esc(S.q)} »${F!=="all"?" dans ce filtre":""}. Essaie un acteur, une chaîne ou une phrase : « comédie des années 90 », « le match en ce moment ».</div>`}
function prevH(){const id=SR.sel;
 if(!id)return `<div class="sr-det" style="padding:24px"><div class="sr-k">Aperçu</div><div class="sr-mut">Le titre sélectionné s'affiche ici : où le regarder, dans quelle version, et s'il passe à la TV en ce moment.</div></div>`;
 if(id.startsWith("a:")){const a=id.slice(2),L=(search(S.q).AI||actorIndex())[a]||[];return `<div class="sr-art" style="--a:#5b6f99;--b:#1a1d26"><span>${esc(actName(a))}</span></div><div class="sr-det"><div class="sr-mut">${L.length} titre${L.length>1?"s":""} chez tes fournisseurs</div>${L.slice(0,8).map(x=>`<div>• ${esc(x.t)} <span class="sr-mut">(${x.y||""})</span></div>`).join("")}<div class="sr-hint">OK : voir tous ses films et séries</div></div>`}
 if(id.startsWith("ch:")){const c=CH[id.slice(3)];if(!c)return "";const e=epgAt(c),p=e.cur,nx=(e.next||[])[0];
  return `<div class="sr-art" style="--a:${c.col||"#334"};--b:#0b0d13"><span>${esc(p.t)}</span></div><div class="sr-det"><div class="sr-mut">${esc(c.n)} · en direct · ${fmt(p.s)} – ${fmt(p.e)}</div>${nx?`<div>Ensuite : <b>${esc(nx.t)}</b> à ${fmt(nx.s)}</div>`:""}
  <div class="sr-k">Où le regarder</div><div class="sr-where">${[...new Set(srcs("ch:"+c.id).map(v=>v.p.name))].map(n=>`<div><i style="background:${pcol(n)}"></i>${esc(n)} · ${esc(srcs("ch:"+c.id).find(v=>v.p.name===n).q)}</div>`).join("")}</div><div class="sr-hint">OK : regarder la chaîne</div></div>`}
 const it=ALL[id];if(!it)return "";const L=srcs(it.id),tvNow=nowList().find(x=>nz(x.p.t)===nz(it.t));const by={};L.forEach(v=>{const n=v.p.name;(by[n]=by[n]||[]).push(v)});
 const W=Object.entries(by).map(([n,vs])=>`<div><i style="background:${pcol(n)}"></i>${esc(n)} · ${esc([...new Set(vs.map(v=>(v.fr&&v.fr!=="VF"?v.fr:v.tag||"VF")+" "+v.q))].slice(0,3).join(", "))}</div>`);
 if(tvNow)W.push(`<div><i style="background:#e5484d"></i>${esc(tvNow.c.n)} · passe maintenant, jusqu'à ${fmt(tvNow.p.e)}</div>`);
 const cast=(it.cast||[]).slice(0,3).map(c=>actName(Array.isArray(c)?c[0]:c)).filter(Boolean);
 return `<div class="sr-art" style="--a:${(it.c||["#334"])[0]};--b:${(it.c||["","#111"])[1]}">${it.po?`<img src="${it.po}" alt="">`:""}<span>${esc(it.t)}</span></div><div class="sr-det"><div class="sr-mut">${esc(sub(it))}${cast.length?" · avec "+esc(cast.join(", ")):""}</div>
  <div class="sr-k">Où le regarder</div><div class="sr-where">${W.join("")||"<div>aucune source active</div>"}</div>
  ${S.prog[it.id]?`<div>Tu l'as regardé à ${Math.round(S.prog[it.id]*100)} % · <b>reprendre</b></div>`:""}<div class="sr-hint">OK : ouvrir la fiche · ▶︎ : lire tout de suite</div></div>`}
function srHtml(){const r=search(S.q);
 return `<div class="sr"><div class="sr-left" data-col="0"><div class="sr-q">${S.q?esc(S.q):'<span class="ph">Rechercher</span>'}<span class="caret"></span></div>
  <div class="sr-kb">${KEYS2.map(k=>`<div class="key" data-f data-fid="k-${k}" data-act="key:${k}" ${k==="a"?"data-default":""}>${k}</div>`).join("")}<div class="key w2" data-f data-fid="k-sp" data-act="key:sp">espace</div><div class="key w2" data-f data-fid="k-del" data-act="key:del">⌫</div><div class="key w2" data-f data-fid="k-mic" data-act="srsiri">${IC.mic} Siri</div></div>
  <div class="sr-note">${IC.phone}Clavier de l'iPhone ou de l'ordinateur · fautes de frappe pardonnées · « films avec Omar Sy », « comédie années 90 », « le match en ce moment »</div></div>
 <div class="sr-mid" data-col="1"><div class="sr-chips">${FILT.map(([k,n])=>`<div class="sr-chip ${SR.filt===k?"sel":""}" data-f data-fid="srf-${k}" data-act="srf:${k}">${n}</div>`).join("")}</div><div class="sr-list sy" id="srlist">${listH(r)}</div></div>
 <div class="sr-right" id="srprev">${prevH()}</div></div>`}
function siriHtml(){const SUG=["Une comédie pour ce soir","Les films avec Omar Sy","Le match en ce moment","Un film d'animation pour les enfants","Des films des années 90","Une série policière","Un film en VOSTFR","Qu'est-ce qui passe à la TV ?"];
 return `<div class="modal sr-siri"><div class="sr-orb"></div><h2>Je t'écoute…</h2><div class="sr-mut">Simulé : choisis ce que tu dirais</div><div class="sr-sug">${SUG.map((s,i)=>`<div class="sr-chip" data-f data-fid="srs-${i}" data-act="srsay:${esc(s)}" ${i===0?"data-default":""}>« ${esc(s)} »</div>`).join("")}</div></div>`}
/* ---------- branchement ---------- */
searchHtml=function(){return srHtml()};
{const _m=modalHtml;modalHtml=function(){if(S.modal&&S.modal.type==="srsiri")return siriHtml();return _m()}}
function remember(q){q=(q||S.q).trim();if(q.length<2)return;const p=ME();p.recent=[q,...(p.recent||[]).filter(x=>nz(x)!==nz(q))].slice(0,6);prSave()}
function redraw(fid){SR.sel=null;LMEM=null;const l=$("#srlist");if(l)l.scrollTop=0;render(fid)}
{const _a=act;act=function(a){if(!a)return;const i=a.indexOf(":"),k=i<0?a:a.slice(0,i),v=i<0?"":a.slice(i+1);
 if(k==="srf"){SR.filt=v;return redraw("srf-"+v)}
 if(k==="srq"){S.q=v;remember(v);SR.sel=null;render();const e=view.querySelector("#srlist [data-f]");if(e)setFocus(e);return}
 if(k==="srsiri"){S.modal={type:"srsiri",ret:F&&F.dataset.fid};return render()}
 if(k==="srsay"){S.modal=null;S.q="";render();let n=0;const t=setInterval(()=>{n+=2;S.q=v.slice(0,n);render("k-mic");if(n>=v.length){clearInterval(t);remember(v);const e=view.querySelector("#srlist [data-f]");if(e)setFocus(e)}},45);return}
 if(S.tab==="search"&&topS().t==="home"&&(k==="open"||k==="live"||k==="actor"))remember();
 if(k==="key"&&S.tab==="search"&&topS().t==="home"){SR.sel=null;LMEM=null;const l=$("#srlist");if(l)l.scrollTop=0}
 return _a(a)}}
/* aperçu du résultat sélectionné */
{const _f=setFocus;setFocus=function(el,inst){_f(el,inst);if(!el||!el.dataset||S.tab!=="search")return;const s=el.dataset.srsel;if(s&&s!==SR.sel){SR.sel=s;const p=$("#srprev");if(p)p.innerHTML=prevH()}}}
/* ↑ depuis le haut de la liste : le filtre actif ; ← depuis les filtres ou la liste : la touche quittée (mémoire de colonne) */
const visIn=e=>{const sy=e.closest(".sy");if(!sy)return true;const r=e.getBoundingClientRect(),q=sy.getBoundingClientRect();return r.bottom>q.top+6&&r.top<q.bottom-6};
let LMEM=null;
{const _f2=setFocus;setFocus=function(el,inst){_f2(el,inst);if(el&&el.closest&&el.closest("#srlist"))LMEM=el.dataset.fid}}
function listTarget(ay){const L=[...view.querySelectorAll("#srlist [data-f]")].filter(visIn);if(!L.length)return view.querySelector(`[data-fid="srf-${SR.filt}"]`);
 return L.find(e=>e.dataset.fid===LMEM)||L.reduce((b,e)=>{const r=e.getBoundingClientRect(),d=Math.abs(r.top+r.height/2-ay);return d<b[0]?[d,e]:b},[1e9,null])[1]}
{const _k=key;key=function(k){const on=inApp()&&S.tab==="search"&&topS().t==="home"&&!S.modal&&!S.loading&&F&&F.isConnected;
 if(on&&k==="up"&&(F.closest(".sr-chips")||(F.closest(".sr-kb")&&[...view.querySelectorAll(".sr-kb [data-f]")].indexOf(F)<6))){const t=view.querySelector('[data-fid="tab-search"]');if(t)setFocus(t);return}
 if(on&&k==="right"&&F.closest(".sr-left")){const before=F,r=before.getBoundingClientRect();_k(k);if(F!==before&&!F.closest(".sr-left")){const t=listTarget(r.top+r.height/2);if(t)setFocus(t)}return}

 if(on&&k==="up"&&F.closest("#srlist")){const before=F;_k(k);if(F===before||!F.closest("#srlist")){const c=view.querySelector(`[data-fid="srf-${SR.filt}"]`);if(c)setFocus(c)}return}
 if(on&&k==="down"&&F.closest(".sr-chips")){const l=view.querySelector("#srlist [data-f]");if(l)setFocus(l);return}
 if(on&&k==="back"&&(F.closest(".sr-mid"))){const m=view.querySelector(`[data-fid="${CSS.escape(colMem[0]||"k-a")}"]`);if(m){setFocus(m);return}}
 if(on&&k==="back"&&S.q&&F.closest(".sr-left")){S.q="";return redraw(F.dataset.fid)}
 if(k==="mic"&&inApp()&&!S.modal&&!(S.tab==="live"&&topS().t==="home")&&!(topS().t==="player"&&P&&P.kind==="live")){if(P)stopPlayer();S.stack=[{t:"home"}];S.tab="search";render("k-a");return act("srsiri")}
 return _k(k)}}
/* clavier de l'ordinateur (comme le clavier de l'iPhone dans l'app) */
document.addEventListener("keydown",e=>{if(!(inApp()&&S.tab==="search"&&topS().t==="home"&&!S.modal&&!S.loading))return;if(e.metaKey||e.ctrlKey||e.altKey)return;const a=document.activeElement;if(a&&(a.tagName==="INPUT"||a.tagName==="TEXTAREA"))return;
 if(/^[a-zA-Zàâäéèêëîïôöùûüç0-9'\-]$/.test(e.key)||e.key===" "){e.preventDefault();e.stopImmediatePropagation();S.q+=e.key===" "?" ":e.key.toLowerCase();return redraw(F&&F.dataset.fid)}
 if(e.key==="Backspace"&&S.q){e.preventDefault();e.stopImmediatePropagation();S.q=S.q.slice(0,-1);return redraw(F&&F.dataset.fid)}},true);
window.__sr={search,parse,wscore};
})();
