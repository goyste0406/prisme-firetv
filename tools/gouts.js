/* ========================= TEST DES GOÛTS (version mixte) =========================
   6 cartes adaptatives (j'aime / pas pour moi / pas vu), 4 duels « celui-ci ou celui-là ? », « Jamais de… » et la version,
   puis « Voici ce que prisme a compris » et une rangée « Pour toi ». Les réponses alimentent les recommandations existantes :
   👍 / 👎 du profil (p.fb), langue préférée (p.lang), genres appris et genres à ne jamais proposer (p.taste). */
(function(){
const NC=6,ND=4;
const G=window.GT={pid:null,step:"intro",f:0,ans:[],duels:[],never:new Set(),ver:0,anim:null,cur:null,duel:null,df:0,clrT:0};
const nz=t=>norm(String(t||"")).trim();
const cat=()=>[...films(),...series()].filter(it=>srcs(it.id).length&&!(it.type==="f"&&fxBlocked(it)));
const pop=it=>(it.tmdb||0)+(it.imdb||0)*8+(typeof trendScore==="function"?trendScore(it)*.3:0);
const g0=it=>(it.g||[])[0]||"Divers";
/* ---------- titres du test : des classiques que presque tout le monde a vus ----------
   Le test ne sert qu'à connaître tes goûts : il montre des titres très connus, même s'ils ne sont pas chez
   tes fournisseurs (on ne peut aimer ou pas que ce qu'on a vu). Ordre = les plus vus en France d'abord.
   Méthode reprise des travaux GroupLens/MovieLens : poser des titres populaires, puis s'adapter aux réponses. */
const MF=[["Intouchables",2011,"Comédie|Drame"],["Titanic",1997,"Drame|Romance"],["Bienvenue chez les Ch'tis",2008,"Comédie"],["Harry Potter à l'école des sorciers",2001,"Aventure|Fantastique"],
 ["Le Roi lion",1994,"Animation|Familial"],["Le Seigneur des anneaux : La Communauté de l'anneau",2001,"Aventure|Fantastique"],["Avatar",2009,"Science-Fiction|Aventure"],["Le Dîner de cons",1998,"Comédie"],
 ["Les Visiteurs",1993,"Comédie|Fantastique"],["Pirates des Caraïbes : La Malédiction du Black Pearl",2003,"Aventure|Fantastique"],["Forrest Gump",1994,"Drame|Romance"],["Astérix & Obélix : Mission Cléopâtre",2002,"Comédie|Aventure"],
 ["Retour vers le futur",1985,"Science-Fiction|Comédie"],["Jurassic Park",1993,"Aventure|Science-Fiction"],["Le Fabuleux Destin d'Amélie Poulain",2001,"Comédie|Romance"],["Shrek",2001,"Animation|Comédie"],
 ["Matrix",1999,"Action|Science-Fiction"],["Gladiator",2000,"Action|Drame"],["La Grande Vadrouille",1966,"Comédie|Guerre"],["Avengers : Endgame",2019,"Action|Science-Fiction"],
 ["La Reine des neiges",2013,"Animation|Familial"],["Taxi",1998,"Action|Comédie"],["Inception",2010,"Science-Fiction|Action"],["Les Bronzés font du ski",1979,"Comédie"],
 ["Le Parrain",1972,"Crime|Drame"],["Qu'est-ce qu'on a fait au Bon Dieu ?",2014,"Comédie"],["Pulp Fiction",1994,"Crime|Thriller"],["Les Choristes",2004,"Drame|Musique"],
 ["Toy Story",1995,"Animation|Familial"],["Skyfall",2012,"Action|Thriller"],["Pretty Woman",1990,"Romance|Comédie"],["Le Silence des agneaux",1991,"Thriller|Crime"],
 ["Top Gun : Maverick",2022,"Action|Drame"],["Interstellar",2014,"Science-Fiction|Drame"],["Il faut sauver le soldat Ryan",1998,"Guerre|Histoire"],["Ça",2017,"Horreur"],
 ["OSS 117 : Le Caire, nid d'espions",2006,"Comédie|Aventure"],["Joker",2019,"Crime|Thriller"],["Love Actually",2003,"Romance|Comédie"],["Mission : Impossible",1996,"Action|Thriller"],
 ["Le Loup de Wall Street",2013,"Crime|Comédie"],["Conjuring : Les Dossiers Warren",2013,"Horreur|Thriller"],["Bohemian Rhapsody",2018,"Musique|Drame"],["Le Prénom",2012,"Comédie"],
 ["Seven",1995,"Crime|Mystère"],["N'oublie jamais",2004,"Romance|Drame"],["Moi, moche et méchant",2010,"Animation|Comédie"],["Oppenheimer",2023,"Histoire|Drame"],
 ["Dune",2021,"Science-Fiction|Aventure"],["La La Land",2016,"Romance|Musique"],["Le Comte de Monte-Cristo",2024,"Aventure|Drame"],["Coco",2017,"Animation|Familial"]];
const MS=[["Friends",1994,"Comédie"],["Game of Thrones",2011,"Science-Fiction & Fantastique|Drame"],["Breaking Bad",2008,"Crime|Drame"],["La casa de papel",2017,"Crime|Drame"],
 ["Stranger Things",2016,"Science-Fiction & Fantastique|Mystère"],["Les Simpson",1989,"Animation|Comédie"],["Grey's Anatomy",2005,"Drame"],["Lupin",2021,"Crime|Mystère"],
 ["Dr House",2004,"Drame|Mystère"],["The Big Bang Theory",2007,"Comédie"],["The Walking Dead",2010,"Drame|Action & Adventure"],["Kaamelott",2005,"Comédie"],
 ["Squid Game",2021,"Action & Adventure|Drame"],["Prison Break",2005,"Action & Adventure|Crime"],["How I Met Your Mother",2005,"Comédie"],["Peaky Blinders",2013,"Crime|Drame"],
 ["Esprits criminels",2005,"Crime|Mystère"],["HPI",2021,"Comédie|Crime"],["Desperate Housewives",2004,"Drame|Mystère"],["Mercredi",2022,"Science-Fiction & Fantastique|Comédie"],
 ["The Crown",2016,"Drame"],["Narcos",2015,"Crime|Drame"],["Le Bureau des Légendes",2015,"Drame|Crime"],["Dix pour cent",2015,"Comédie|Drame"],
 ["Sherlock",2010,"Crime|Mystère"],["Vikings",2013,"Action & Adventure|Drame"],["The Office",2005,"Comédie"],["La Chronique des Bridgerton",2020,"Romance|Drame"],["The Last of Us",2023,"Drame|Action & Adventure"]];
/* famille d'un genre, pour retrouver le nom exact du genre chez toi (TMDB ne nomme pas pareil films et séries) */
const FAM=g=>{const x=nz(g);return /anim/.test(x)?"anim":/famil|kids|enfant/.test(x)?"famil":/science|sf|fantas/.test(x)?"sf":/horr|epouv/.test(x)?"horr":/thrill|myst|suspens/.test(x)?"thril":/crime|polic|judic/.test(x)?"crime":/comed|humour/.test(x)?"comed":/romanc/.test(x)?"roman":/guerre|war|hist/.test(x)?"hist":/music/.test(x)?"music":/action|aventure|adventure/.test(x)?"action":/docu/.test(x)?"docu":/drame|drama|soap/.test(x)?"drame":x};
const GP={};const I=id=>ALL[id]||GP[id];
const GCOL=["#7a2e3a","#2e4f7a","#3d6b3a","#6b4f2a","#4a2e6b","#2a6b66","#6b2a55","#5a5a2a"];
let POOL=null;
function pool(){if(POOL)return POOL;const C=cat(),byT={},gn={};
 for(const it of C){const k=nz(it.t).replace(/^(le|la|les|l |the) /,"");(byT[k]=byT[k]||[]).push(it);for(const g of it.g||[]){const f=FAM(g);(gn[f]=gn[f]||{})[g]=(gn[f][g]||0)+1}}
 const gName=(g,ty)=>{if(C.some(it=>(it.g||[]).includes(g)))return g;const m=gn[FAM(g)];if(!m)return g;return Object.entries(m).sort((a,b)=>b[1]-a[1])[0][0]};
 const mk=([t,y,gs],i,ty)=>{const k=nz(t).replace(/^(le|la|les|l |the) /,""),hit=(byT[k]||[]).find(it=>it.type===ty&&(!it.y||Math.abs(it.y-y)<=1));if(hit)return hit;
  const id="gt:"+ty+i;return GP[id]=GP[id]||{id,t,y,type:ty,g:gs.split("|").map(g=>gName(g,ty)),c:[GCOL[i%GCOL.length],"#0d0f15"],po:(GTPO[id+t]||""),d:0,s:"",gt:1}};
 const F=MF.map((x,i)=>mk(x,i,"f")),S2=MS.map((x,i)=>mk(x,i,"s")),out=[];
 /* deux films pour une série, et un léger mélange à chaque test pour ne pas revoir toujours les mêmes */
 for(let i=0,j=0;i<F.length||j<S2.length;){if(i<F.length)out.push(F[i++]);if(i<F.length)out.push(F[i++]);if(j<S2.length)out.push(S2[j++])}
 for(let b=0;b<out.length;b+=9){const B=out.slice(b,b+9);for(let k=B.length-1;k>0;k--){const r=Math.floor(Math.random()*(k+1));[B[k],B[r]]=[B[r],B[k]]}out.splice(b,B.length,...B)}
 /* puis les titres de ton catalogue très connus (beaucoup de votes TMDB) */
 const big=C.filter(it=>!out.includes(it)&&it.tmd&&(it.tmd.vc||0)>=8000).sort((a,b)=>(b.tmd.vc||0)-(a.tmd.vc||0)).slice(0,40);
 POOL=out.filter(it=>!(it.type==="f"&&!it.gt&&fxBlocked(it))).concat(big);return POOL}
/* affiches des titres absents du catalogue : recherche TMDB (si la clé est enregistrée), gardée en mémoire */
const GTPO=(()=>{try{return JSON.parse(localStorage.getItem("prisme-gtpo")||"{}")}catch(e){return {}}})();
function needPo(it){if(!it||!it.gt||it.po||typeof window.fcPoster!=="function")return;const k=it.id+it.t;if(GTPO[k]!==undefined)return;GTPO[k]="";
 window.fcPoster(it.type,it.t,it.y).then(u=>{GTPO[k]=u||"";it.po=u||"";try{localStorage.setItem("prisme-gtpo",JSON.stringify(GTPO))}catch(e){}if(u)draw()}).catch(()=>{})}

function weights(){const W={},seen={};const add=(g,v)=>{W[g]=(W[g]||0)+v;seen[g]=(seen[g]||0)+1};
 const nv={};for(const a of G.ans){const it=I(a.id);if(!it)continue;if(a.r==="unseen"){const g=g0(it);nv[g]=(nv[g]||0)+1;if(nv[g]>=2)seen[g]=(seen[g]||0)+1;continue}const v=a.r==="like"?1:-1.2;(it.g||[]).forEach((g,i)=>add(g,v*(i?.6:1)))}
 for(const d of G.duels){if(d.w==null)continue;(I(d.w).g||[]).forEach(g=>add(g,.7));(I(d.l).g||[]).forEach(g=>add(g,-.25))}
 for(const g of G.never)if(!/^__/.test(g))W[g]=(W[g]||0)-5;return {W,seen}}
function nextCard(){const {seen}=weights(),done=new Set(G.ans.map(a=>a.id)),refused=new Set(G.ans.filter(a=>a.r==="no").flatMap(a=>I(a.id).g||[]));
 const P=pool().filter(it=>!done.has(it.id)&&!refused.has(g0(it)));const n=P.find(it=>!seen[g0(it)])||P[0]||null;if(n){needPo(n);const nx=P.find(it=>it!==n&&!seen[g0(it)]);needPo(nx)}return n}
function nextDuel(){const {W}=weights(),used=new Set([...G.ans.map(a=>a.id),...G.duels.flatMap(d=>[d.a,d.b])]);
 const C=pool().filter(it=>!used.has(it.id)&&!(it.g||[]).some(g=>(W[g]||0)<=-1));const by={};C.forEach(it=>{(by[g0(it)]=by[g0(it)]||[]).push(it)});
 const Gs=Object.keys(by).sort((a,b)=>(W[b]||0)-(W[a]||0)||by[b].length-by[a].length);if(!Gs.length)return null;const n=G.duels.length,g1=Gs[n%Gs.length],g2=Gs[(n+1)%Gs.length];
 const a=by[g1][0],b=(g2!==g1?by[g2][0]:by[g1][1])||C.find(x=>x!==a);if(a&&b){needPo(a);needPo(b)}return a&&b?{a:a.id,b:b.id}:null}
/* « Jamais de… » : les genres sensibles présents chez toi, plus les films très longs */
function neverList(){const gs=new Set(cat().flatMap(it=>it.g||[]));const L=[...gs].filter(g=>/horr|epouv|telerea|realit|anim|docu|music|western|guerre|erot|gore|thriller/.test(nz(g))).sort();return [...L.slice(0,8),"__long"]}
const nevLbl=g=>g==="__long"?"Films de plus de 2 h 30":g;
const VERS=[["auto","✨ Automatique"],["VFF","VFF d'abord"],["VF","VF, peu importe l'accent"],["VOSTFR","VOSTFR d'abord"]];
const neverHit=(it,set)=>{set=set||G.never;return (it.g||[]).some(g=>set.has(g))||(set.has("__long")&&it.type==="f"&&it.d>150)};
function recos(){const {W}=weights(),used=new Set([...G.ans.map(a=>a.id),...G.duels.flatMap(d=>[d.a,d.b])]);const L=G.ans.filter(a=>a.r==="like").map(a=>I(a.id)).concat(G.duels.filter(d=>d.w!=null).map(d=>I(d.w)));
 const yr=L.length?L.reduce((s,x)=>s+(x.y||2015),0)/L.length:2015;
 return cat().filter(it=>!used.has(it.id)&&!neverHit(it)).map(it=>{const s=(it.g||[]).reduce((a,g,i)=>a+(W[g]||0)*(i?.6:1),0)-Math.abs((it.y||yr)-yr)/40+pop(it)/400;return {it,s}}).sort((a,b)=>b.s-a.s).slice(0,6).map(x=>({...x,pct:Math.max(55,Math.min(98,Math.round(72+x.s*9)))}))}
function why(it){const L=G.ans.filter(a=>a.r==="like").map(a=>I(a.id)).concat(G.duels.filter(d=>d.w!=null).map(d=>I(d.w)));const m=L.find(x=>(x.g||[]).includes(g0(it)));if(m)return "parce que tu aimes "+m.t;const {W}=weights();const g=(it.g||[]).filter(g=>(W[g]||0)>0)[0];return g?"tu aimes : "+g.toLowerCase():"très bien noté chez toi"}
/* ---------- rendu ---------- */
const P=()=>PR.list[G.pid];
const tot=()=>NC+ND+1,done=()=>G.ans.length+G.duels.length+(G.step==="result"?1:0);
const avH=(p,s)=>`<div class="gt-av" style="--c:${p.c};${s?`width:${s}px;height:${s}px;font-size:${Math.round(s*.43)}px`:""}">${p.emo||esc((p.n||"?")[0])}</div>`;
function topH(l){const p=P();return `<div class="gt-top">${avH(p)}<div><b>${esc(p.n)}</b><div class="gt-mut" style="font-size:13px">${l}</div></div><div class="gt-pr">${Math.min(done()+1,tot())} / ${tot()}<div class="gt-prog"><i style="width:${done()/tot()*100}%"></i></div></div></div>`}
function pst(it,extra){const c=it.c||["#334","#111"];return `<div class="gt-pst" style="--a:${c[0]};--b:${c[1]}">${it.po?`<img src="${it.po}" alt="">`:""}<span class="bd">${it.type==="s"?"SÉRIE":"FILM"}${it.y?" · "+it.y:""}</span>${extra||""}<div class="tt">${esc(it.t)}</div><div class="sb">${esc((it.g||[]).slice(0,2).join(" · "))}${it.type==="f"&&it.d?" · "+Math.floor(it.d/60)+" h "+String(it.d%60).padStart(2,"0"):""}</div></div>`}
function sideH(){const {W}=weights(),E=Object.entries(W).filter(([g,v])=>Math.abs(v)>.1&&!G.never.has(g)).sort((a,b)=>b[1]-a[1]);
 return `<div class="gt-side gt-glass"><div class="gt-k">Ce que prisme apprend</div>${E.length?E.slice(0,7).map(([g,v])=>`<div class="r"><span>${esc(g)}</span><span class="${v>0?"p":"n"}">${v>0?"+":"−"}${"●".repeat(Math.min(3,Math.ceil(Math.abs(v))))}</span></div>`).join(""):'<div class="gt-mut" style="font-size:13.5px;line-height:1.45">Rien encore : chaque réponse ajuste ce que prisme te proposera.</div>'}</div>`}
function vIntro(){const p=P(),B=["Commencer","Plus tard"];
 return `<div class="gt-bg" style="--c:${p.c}"></div><div class="gt-intro">${avH(p,96)}<h1>Apprenons tes goûts, ${esc(p.n)}</h1><p>Une minute, une dizaine de grands classiques du cinéma et des séries que presque tout le monde a vus : prisme saura quoi te proposer dès ce soir. Tu pourras le refaire dans Réglages › Profils.</p>
 <div class="gt-steps"><div class="gt-glass"><i>🃏</i><b>${NC} titres</b><small>J'aime, pas pour moi, pas vu : la suite s'adapte à tes réponses</small></div><div class="gt-glass"><i>⚖️</i><b>${ND} duels</b><small>Celui-ci ou celui-là ? Le plus précis pour départager</small></div><div class="gt-glass"><i>🚫</i><b>Jamais de…</b><small>Ce que tu ne veux jamais voir proposé</small></div></div>
 <div style="display:flex;gap:14px">${B.map((b,i)=>`<span class="gt-btn ${i===0?"pri":""} ${G.f===i?"foc":""}" data-gi="${i}">${b}</span>`).join("")}</div></div>`}
function vCard(){const it=I(G.cur),B=["← Pas pour moi","↓ Pas vu","J'aime →"];
 return `<div class="gt-bg" style="--c:${(it.c||["#334"])[0]}"></div>${topH("Tu connais ? Dis-moi si tu aimes")}${sideH()}<div class="gt-card ${G.anim||""}">${pst(it)}</div><div class="gt-syn">${it.gt?("Un grand classique · pas besoin qu'il soit chez tes fournisseurs, c'est juste pour connaître tes goûts"):esc((it.s||it.p||"").slice(0,180))}</div>
 <div class="gt-ans">${B.map((b,i)=>`<span class="gt-btn ${G.f===i?"foc":""}" data-gi="${i}">${b}</span>`).join("")}</div>`}
function vDuel(){const a=I(G.duel.a),b=I(G.duel.b);
 return `<div class="gt-bg" style="--c:#2b3245"></div>${topH("Ce soir, lequel te tente le plus ?")}<div class="gt-dq">Celui-ci ou celui-là ?</div>
 <div class="gt-duel"><div class="gt-dv ${G.df===0?"foc":G.df===1?"dim":""}" data-gd="0">${pst(a)}</div><span class="gt-vs">ou</span><div class="gt-dv ${G.df===1?"foc":G.df===0?"dim":""}" data-gd="1">${pst(b)}</div></div>
 <div class="gt-ans"><span class="gt-btn ${G.df===2?"foc":""}" data-gd="2">Aucun des deux</span></div>`}
function vNever(){const N=neverList(),n=N.length;
 return `<div class="gt-bg" style="--c:#2b3245"></div>${topH("Dernière question")}<div class="gt-nev"><h2>Jamais de… ?</h2><div class="gt-mut" style="font-size:16px">Coche ce que prisme ne doit jamais te proposer (OK pour cocher)</div>
 <div class="gt-chips">${N.map((g,i)=>`<span class="gt-chip ${G.never.has(g)?"on":""} ${G.f===i?"foc":""}" data-gi="${i}">${G.never.has(g)?"🚫 ":""}${esc(nevLbl(g))}</span>`).join("")}</div>
 <div class="gt-k" style="margin-top:10px">Et la version ?</div><div class="gt-chips">${VERS.map((v,j)=>`<span class="gt-chip ${G.ver===j?"sel":""} ${G.f===n+j?"foc":""}" data-gi="${n+j}">${G.ver===j?"✓ ":""}${esc(v[1])}</span>`).join("")}</div>
 <span class="gt-btn pri ${G.f===n+VERS.length?"foc":""}" data-gi="${n+VERS.length}" style="margin-top:10px">Voir ce que prisme a compris →</span></div>`}
function vResult(){const p=P(),{W}=weights(),E=Object.entries(W).filter(([g])=>!G.never.has(g)),pos=E.filter(([,v])=>v>0).sort((a,b)=>b[1]-a[1]).slice(0,5),neg=E.filter(([,v])=>v<0).sort((a,b)=>a[1]-b[1]).slice(0,3),mx=Math.max(1,...pos.map(x=>x[1]),...neg.map(x=>-x[1]));
 const L=G.ans.filter(a=>a.r==="like").map(a=>I(a.id)).concat(G.duels.filter(d=>d.w!=null).map(d=>I(d.w))),yr=L.length?Math.round(L.reduce((s,x)=>s+(x.y||2015),0)/L.length):null,F=L.filter(x=>x.type==="f"&&x.d),dm=F.length?Math.round(F.reduce((s,x)=>s+x.d,0)/F.length):null;
 const R=recos(),nb=R.length,BI=["Terminer","Refaire le test"];
 return `<div class="gt-bg" style="--c:${p.c}"></div>${topH("C'est prêt")}<div class="gt-res"><div class="l gt-glass"><div class="gt-k">Voici ce que prisme a compris</div><h2>${esc(p.n)} aime…</h2>
 ${pos.map(([g,v])=>`<div class="gt-gb"><span>${esc(g)}</span><span class="t"><i style="width:${v/mx*100}%;background:#34c759"></i></span></div>`).join("")||'<div class="gt-mut">Pas encore assez de « j\'aime » : les propositions resteront variées.</div>'}
 ${neg.length?`<div class="gt-k" style="margin-top:6px">…un peu moins</div>${neg.map(([g,v])=>`<div class="gt-gb"><span>${esc(g)}</span><span class="t"><i style="width:${-v/mx*100}%;background:#ff6b6b"></i></span></div>`).join("")}`:""}
 <div class="gt-facts">${yr?`<span>${yr>=2015?"plutôt récent":yr>=2000?"années 2000 et après":"aime les classiques"}</span>`:""}${dm?`<span>films de ${Math.floor(dm/60)} h ${String(dm%60).padStart(2,"0")} en moyenne</span>`:""}<span>${esc(VERS[G.ver][1])}</span>${[...G.never].map(g=>`<span class="no">🚫 ${esc(nevLbl(g))}</span>`).join("")}</div>
 <div class="gt-mut" style="font-size:13px;line-height:1.45;margin-top:auto">Ensuite, ce que tu regardes vraiment compte de plus en plus. Refaire le test ou tout oublier : Réglages › Profils › ${esc(p.n)} › Mes goûts.</div></div>
 <div class="r"><div class="gt-k">Pour toi, dès ce soir · ${nb} titres de ton catalogue</div><div class="gt-recs">${R.map((x,i)=>`<div class="gt-rc ${G.f===i?"foc":""}" data-gi="${i}">${pst(x.it,`<span class="sc">${x.pct} %</span>`)}<small>${esc(why(x.it))}</small></div>`).join("")}</div>
 <div class="gt-acts">${BI.map((b,j)=>`<span class="gt-btn ${j===0?"pri":""} ${G.f===nb+j?"foc":""}" data-gi="${nb+j}">${b}</span>`).join("")}</div></div></div>`}
function gtHtml(){return `<div class="gt">${G.step==="intro"?vIntro():G.step==="card"?vCard():G.step==="duel"?vDuel():G.step==="never"?vNever():vResult()}</div>`}
function draw(){if(topS().t!=="gtest")return;view.innerHTML=gtHtml();const p=P();if(p)setBg([p.c,"#08080c"])}
/* ---------- enregistrement dans le profil ---------- */
function apply(){const p=P();p.fb=p.fb||{};p.no=p.no||[];const ids=[];
 const noIds=[];for(const a of G.ans){if(String(a.id).startsWith("gt:"))continue;if(a.r==="like"){p.fb[a.id]=1;ids.push(a.id)}else if(a.r==="no"){p.fb[a.id]=-1;ids.push(a.id);if(!p.no.includes(a.id)){p.no.push(a.id);noIds.push(a.id)}}}
 for(const d of G.duels)if(d.w!=null&&!String(d.w).startsWith("gt:")&&!p.fb[d.w]){p.fb[d.w]=1;ids.push(d.w)}
 const {W}=weights();p.taste={g:W,never:[...G.never],ver:VERS[G.ver][0],ids,noIds,at:Date.now(),ans:G.ans.length+G.duels.length};p.lang=VERS[G.ver][0];prSave();
 FXS.cache={};if(typeof FH!=="undefined")FH.cache={};if(window.__sx&&__sx.X)__sx.X.cache={}}
function forget(pid){const p=PR.list[pid];if(!p)return;const t=p.taste;if(t){for(const id of t.ids||[])delete p.fb[id];p.no=(p.no||[]).filter(id=>!(t.noIds||[]).includes(id))}delete p.taste;prSave();FXS.cache={};if(typeof FH!=="undefined")FH.cache={};if(window.__sx&&__sx.X)__sx.X.cache={}}
window.gtNever=it=>{const t=ME().taste;return !!(t&&t.never&&neverHit(it,new Set(t.never)))};
window.gtTaste=()=>{const t=ME().taste;return t?t.g:{}};
/* les « Pour toi » des films ne proposent jamais un genre refusé */
{const _fy=forYou;forYou=function(){const fb=ME().fb||{};return _fy().filter(o=>!gtNever(o.c)&&fb[o.c.id]!==-1)}}
/* ---------- déroulé ---------- */
function open(pid,step){G.pid=pid;POOL=null;G.step=step||"intro";G.f=0;G.anim=null;if(G.step==="intro"){G.ans=[];G.duels=[];G.never=new Set();const L=P().lang||"auto";G.ver=Math.max(0,VERS.findIndex(v=>v[0]===L))}
 if(G.step==="result"){const t=P().taste;if(!t)return toast(`${P().n} n'a pas encore fait le test`);G.ans=(t.ids||[]).filter(id=>ALL[id]).map(id=>({id,r:P().fb[id]===1?"like":"no"}));G.duels=[];G.never=new Set(t.never||[]);G.ver=Math.max(0,VERS.findIndex(v=>v[0]===t.ver));G.ro=true}else G.ro=false;
 push({t:"gtest"})}
window.gtOpen=open;
function goCard(){const it=nextCard();if(!it||G.ans.length>=NC)return goDuel();G.cur=it.id;G.step="card";G.f=2;G.anim=null;draw()}
function answer(r){if(G.anim)return;G.anim=r==="no"?"out-l":r==="like"?"out-r":"out-d";G.ans.push({id:G.cur,r});draw();setTimeout(()=>{G.anim=null;goCard()},320)}
function goDuel(){if(G.duels.length>=ND){G.step="never";G.f=0;return draw()}const d=nextDuel();if(!d){G.step="never";G.f=0;return draw()}G.duel=d;G.df=0;G.step="duel";draw()}
function pick(i){const d=G.duel;G.duels.push(i===2?{a:d.a,b:d.b,w:null}:{a:d.a,b:d.b,w:i===0?d.a:d.b,l:i===0?d.b:d.a});goDuel()}
function quit(msg){S.stack.pop();render(topS().last);if(msg)toast(msg)}
function gKey(k){
 if(G.step==="intro"){if(k==="left"||k==="right"){G.f=G.f?0:1;return draw()}if(k==="ok"){if(G.f===0)return goCard();return quit("« Apprendre tes goûts » reste dans Réglages › Profils")}if(k==="back")return quit();return}
 if(G.step==="card"){if(k==="left")return answer("no");if(k==="right")return answer("like");if(k==="down")return answer("unseen");if(k==="ok")return answer(["no","unseen","like"][G.f]);
  if(k==="back"){const a=G.ans.pop();if(!a){G.step="intro";G.f=0;return draw()}G.cur=a.id;return draw()}return}
 if(G.step==="duel"){if(k==="left"){G.df=0;return draw()}if(k==="right"){G.df=1;return draw()}if(k==="down"){G.df=2;return draw()}if(k==="up"){if(G.df===2)G.df=0;return draw()}if(k==="ok")return pick(G.df);
  if(k==="back"){const d=G.duels.pop();if(!d){const a=G.ans.pop();if(!a){G.step="intro";return draw()}G.cur=a.id;G.step="card";G.f=2;return draw()}G.duel={a:d.a,b:d.b};G.df=0;return draw()}return}
 if(G.step==="never"){const n=neverList().length,v=VERS.length,go=n+v,row=i=>i<n?0:i<go?1:2;
  if(k==="right"&&G.f<go&&row(G.f+1)===row(G.f))G.f++;else if(k==="left"&&G.f>0&&row(G.f-1)===row(G.f))G.f--;else if(k==="down")G.f=row(G.f)===0?n:go;else if(k==="up")G.f=row(G.f)===2?n:0;
  else if(k==="ok"){if(G.f<n){const g=neverList()[G.f];G.never.has(g)?G.never.delete(g):G.never.add(g)}else if(G.f<go)G.ver=G.f-n;else{apply();G.step="result";G.f=0}}
  else if(k==="back"){const d=G.duels.pop();if(d){G.duel={a:d.a,b:d.b};G.df=0;G.step="duel"}else{const a=G.ans.pop();if(a){G.cur=a.id;G.step="card";G.f=2}else G.step="intro"}}return draw()}
 if(G.step==="result"){const R=recos(),nb=R.length;if(k==="right"&&G.f<nb+1)G.f++;else if(k==="left"&&G.f>0)G.f--;else if(k==="down"&&G.f<nb)G.f=nb;else if(k==="up"&&G.f>=nb)G.f=0;
  else if(k==="ok"){if(G.f<nb){const it=R[G.f].it;if(G.pid===PR.cur){S.stack.pop();return push({t:"detail",id:it.id})}return toast(`${it.t} : ouvre le profil de ${P().n} pour le regarder`)}if(G.f===nb)return quit(G.ro?"":`Goûts de ${P().n} enregistrés · ses recommandations sont à jour`);S.stack.pop();return open(G.pid,"intro")}
  else if(k==="back")return quit();return draw()}}
/* ---------- branchement ---------- */
{const _r=render;render=function(fid){_r(fid);if(inApp()&&topS().t==="gtest"&&!S.modal)draw()}}
{const _k=key;key=function(k){if(inApp()&&topS().t==="gtest"&&!S.modal&&!S.loading){if(["up","down","left","right","ok","back"].includes(k))return gKey(k);if(k==="home")return _k(k);return}return _k(k)}}
view.addEventListener("click",e=>{if(!(inApp()&&topS().t==="gtest"))return;const d=e.target.closest("[data-gd]");if(d&&G.step==="duel"){G.df=+d.dataset.gd;return pick(G.df)}const el=e.target.closest("[data-gi]");if(!el)return;G.f=+el.dataset.gi;if(G.step==="card")G.f=Math.min(2,G.f);gKey("ok")});
{const _a=act;act=function(a){if(!a)return _a(a);const [k,v,w]=a.split(":");
 if(k==="gt"){if(v==="open")return open(w,"intro");if(v==="res")return open(w,"result");if(v==="clr"){if(Date.now()-G.clrT>3000){G.clrT=Date.now();return toast("OK encore pour tout oublier")}G.clrT=0;forget(w);render(F&&F.dataset.fid);return toast(`Goûts de ${PR.list[w].n} oubliés · prisme repart de zéro`)}}
 /* nouveau profil : le test est proposé juste après le nom */
 const m=S.modal;const newId=(k==="fxpdone"&&m&&m.isNew)?m.id:(k==="fxnk"&&v==="ok"&&m&&m.id&&m.id===window.GT_NEW)?m.id:null;
 const r=_a(a);if(newId&&PR.list[newId]){window.GT_NEW=null;S.modal=null;open(newId,"intro")}return r}}
window.__gt={G,probes:()=>pool(),pool,I,recos,nextCard,neverList,apply,forget};
})();
