/* ===================== Accueil de l'onglet Films (version 2 retenue) =====================
   bannière à 5 pages · Ce soir ? · Reprendre · Top 10 · Nouveau sur prisme · Parce que tu as aimé · Ma liste
   · Explorer · Parcourir (Catégories / Licences) · ⚡ lecture préparée · aperçu · points « nouveau »
   · OK maintenu (film + rangée, gardé par profil) · bande-annonce si on reste sur la bannière */
const FH={ask:null,h1i:0,hdir:null,catT:"cat",skelDone:false,skel:false,prep:null,alt:[],cache:{}};
const fhOn=()=>inApp()&&topS().t==="home"&&S.tab==="films"&&!P;
const fhNow=()=>nowMin();
const fhSet=()=>{S.set=S.set||{};if(S.set.fhTrl==null)S.set.fhTrl=10;if(!S.set.fhVol)S.set.fhVol="faible";return S.set};
const fhP=()=>{const p=ME();p.hh=p.hh||{ord:null,hid:[],last:0,nseen:[]};if(!p.hh.ord)p.hh.ord=FHKEYS.slice();for(const k of FHKEYS)if(!p.hh.ord.includes(k))p.hh.ord.push(k);return p.hh};
const FHKEYS=["reprendre","top","new","bec","liste","explore","browse"];
const FHNAMES={reprendre:"Reprendre",top:"Top 10 du moment",new:"Nouveau sur prisme",bec:"Parce que tu as aimé…",liste:"Ma liste",explore:"Explorer",browse:"Parcourir"};
/* dernière visite : on la lit une fois par session pour les points bleus, puis on la met à jour */
let FHLAST=null;function fhLast(){if(FHLAST==null){const h=fhP();FHLAST=h.last||Date.now()-3*864e5;h.last=Date.now();prSave()}return FHLAST}

/* ---------- données ---------- */
const fhFilms=()=>films().filter(f=>!fxBlocked(f));
const fhNo=id=>ME().no.includes(id),fhSeen=id=>ME().seen.includes(id);
function fhAddDays(f){const r=f._real;if(r&&r.a)return Math.max(0,Math.floor((Date.now()/1000-r.a)/86400));const a=added(f.id);return a?a.d:999}
function fhProv(f){const a=added(f.id);return a&&a.p?a.p.name:(S.playlists[0]||{}).name||"ton fournisseur"}
function forYou(){const ck="fy|"+(FXS.duo||[PR.cur]).join("+")+"|"+FILMS.length+"|"+TMD.n+"|"+ME().no.length+"|"+ME().seen.length;if(FH.cache[ck])return FH.cache[ck];
 const L=liked().slice(-3),M={};for(const id of L){const b=ALL[id];if(b)for(const o of crossPick(b,"mix")){const c=M[o.c.id];if(!c||(o.pct||0)>(c.pct||0))M[o.c.id]=o}}
 for(const f of fhFilms())if(!M[f.id]&&!fhSeen(f.id)&&!fhNo(f.id))M[f.id]={c:f,pct:Math.max(35,Math.min(92,Math.round(f.imdb*9))),why:[{c:"qual",w:0,t:`★ ${f.imdb} · bien noté`}],raw:0};
 return FH.cache[ck]=Object.values(M).filter(o=>!fxBlocked(o.c)&&!fhNo(o.c.id)).sort((a,b)=>(b.pct||0)-(a.pct||0))}
const fhG=f=>norm((f.g||[]).join(" ")+" "+(f.tmd?(f.tmd.kw||[]).join(" "):""));
const MOODS=[["rire","Rire","😄",f=>/comed|anim|famil/.test(fhG(f))],["frisson","Frisson","😱",f=>/thriller|horreur|horror|crime|polic|myst/.test(fhG(f))],
 ["evasion","Évasion","🚀",f=>/aventure|science|fantas|action/.test(fhG(f))],["reflechir","Réfléchir","🧠",f=>/docu|histo|guerre|biograph/.test(fhG(f))],["emotion","Émotion","💛",f=>/drame|romance|musi/.test(fhG(f))]];
const DURS=[["all","Peu importe",()=>true],["105","Moins de 1 h 45",f=>f.d<=105],["150","Moins de 2 h 30",f=>f.d<=150],["bed","Fini avant mon coucher",f=>bInfo(f).late<=0]];
function h2Res(){const d=DURS.find(x=>x[0]===(S.fhd||"all"))||DURS[0],m=MOODS.find(x=>x[0]===S.fhm);return forYou().filter(o=>!S.prog[o.c.id]&&d[2](o.c)&&(!m||m[3](o.c)))}
function fhResume(){return Object.keys(S.prog).map(id=>ALL[id]).filter(f=>f&&f.type==="f"&&srcs(f.id).length&&!fxBlocked(f))}
function fhSagaNext(){const out=[],done=new Set();for(const f of fhFilms()){const c=f.tmd&&f.tmd.col;if(!c||done.has(c[0]))continue;done.add(c[0]);const sg=fxSaga(f),i=sg.findIndex(x=>!fhSeen(x.id));
  if(i>0&&!S.prog[sg[i].id]&&!fhNo(sg[i].id))out.push({f:sg[i],why:`Suite de ${fxShort(sg[i-1])}, que tu as vu`})}return out}
/* Top 10 : tendances en France (films.json) ou, sans films.json, le classement de démonstration */
function fhTop(){if(TMD.tr&&TMD.tr.length){const prev=TMD.trp||[];return TMD.tr.map(id=>TMIDX[id]).filter(f=>f&&srcs(f.id).length&&!fxBlocked(f)&&!fhNo(f.id)).slice(0,10).map((f,i)=>{const j=prev.indexOf(f.tm);return {f,rk:i+1,mv:!prev.length?"=":j<0?"NOUV":j>i?"▲"+(j-i):j<i?"▼"+(i-j):"="}})}
 return fhFilms().filter(f=>!fhNo(f.id)).sort((a,b)=>trendScore(b)-trendScore(a)).slice(0,10).map((f,i)=>{const h=hash(f.id+"#mv")%7;return {f,rk:i+1,mv:h===0?"NOUV":h<3?"▲"+(h+1):h<5?"▼"+(h-2):"="}})}
function fhNew(){return fhFilms().map(f=>({f,d:fhAddDays(f)})).filter(x=>x.d<=14&&!fhNo(x.f.id)).sort((a,b)=>a.d-b.d||(b.f.imdb-a.f.imdb)).slice(0,20)}
const fhAgo=d=>d===0?"aujourd'hui":d===1?"hier":`il y a ${d} j`;
function fhIsNew(id){const h=fhP();if(h.nseen.includes(id))return false;const f=ALL[id];if(!f)return false;const since=(Date.now()-fhLast())/864e5;
 if(fhAddDays(f)<=Math.min(7,since))return true;const t=fhTop().find(x=>x.f.id===id);return !!t&&(t.mv==="NOUV"||t.mv[0]==="▲")}
/* « Ce soir à la télé » : films de ton catalogue qui passent ce soir sur tes chaînes */
function fhTV(){const k="tv|"+Math.floor(fhNow()/10)+"|"+FILMS.length;if(FH.cache[k])return FH.cache[k];const idx={};for(const f of fhFilms()){const w=norm(f.t).replace(/[^a-z0-9]/g,"");if(w.length>=4)idx[w]=f}
 const n=fhNow(),out=[];for(const c of chans()){let L;try{L=epg(c)}catch(e){continue}for(const p of L){if(p.e<=n||p.s>24*60+120)continue;const w=norm(p.t||"").replace(/[^a-z0-9]/g,""),f=idx[w];if(!f||fhNo(f.id))continue;
   const live=p.s<=n;out.push({f,c,p,live,t:live?"en direct · depuis "+fmt(p.s):(p.s<24*60?"ce soir ":"cette nuit ")+fmt(p.s%1440)});break}if(out.length>=6)break}
 out.sort((a,b)=>(a.live?0:1)-(b.live?0:1)||a.p.s-b.p.s);return FH.cache[k]=out}
const MOMS={sem:{ic:"🏆",tag:"LE MOMENT · EN SEMAINE",t:"Les valeurs sûres",s:"En semaine, pas besoin de prendre de risque : que des films notés 8 et plus, que tu n'as pas vus.",f:f=>f.imdb>=8&&!fhSeen(f.id)},
 duo:{ic:"🍿",tag:"LE MOMENT · VENDREDI SOIR",t:"Soirée à deux",s:"Des films qu'aucun des deux profils n'a vus, et qui plaisent à vous deux.",f:f=>{const ids=Object.keys(PR.list).slice(0,2);return f.imdb>=7.3&&ids.every(id=>!PR.list[id].seen.includes(f.id))},duo:1},
 fam:{ic:"☀️",tag:"LE MOMENT · DIMANCHE",t:"Dimanche en famille",s:"Pour tous les âges ou dès 10 ans, à regarder l'après-midi.",f:f=>{const a=fxAgeOf(f);return a<=10}},
 noel:{ic:"🎄",tag:"LE MOMENT · DÉCEMBRE",t:"Les grands films des fêtes",s:"Longs, beaux, à partager : de quoi tenir jusqu'au réveillon.",f:f=>f.d>=140&&f.imdb>=7.6}};
function fhMomKey(){const d=new Date(),w=d.getDay();if(d.getMonth()===11)return "noel";if((w===5||w===6)&&Object.keys(PR.list).length>1)return "duo";if(w===0)return "fam";return "sem"}
function fhHon(){const by={};for(const f of fhFilms())(f.dir||"").split(",").map(s=>s.trim()).filter(Boolean).forEach(d=>(by[d]=by[d]||[]).push(f));
 const C=Object.entries(by).filter(([d,L])=>L.length>=3).sort((a,b)=>b[1].filter(f=>fhSeen(f.id)).length-a[1].filter(f=>fhSeen(f.id)).length||b[1].length-a[1].length).slice(0,4);if(!C.length)return null;
 const wk=Math.floor(Date.now()/(7*864e5)),[who,L]=C[wk%C.length];return {who,L:L.sort((a,b)=>a.y-b.y)}}
const SOON_DEMO=[{t:"Le Dernier Phare",y:2026,ov:"Une gardienne de phare isolée reçoit des messages d'un navire disparu depuis trente ans.",cine:"2026-11-04",vod:"2027-03-10",c:["#5aa0c8","#06121a"]}];
const fhDate=s=>{if(!s)return "";const d=new Date(s+"T12:00:00");return isNaN(d)?s:d.toLocaleDateString("fr-FR",{day:"numeric",month:"long"})};
const fhMonth=s=>{if(!s)return "";const d=new Date(s+"T12:00:00");return isNaN(d)?s:d.toLocaleDateString("fr-FR",{month:"long",year:"numeric"})};
const fhMosaic=L=>`<div class="mosa">${L.slice(0,6).map(f=>`<div class="mo">${fxArt(f)}<b class="${fxFont(f)}">${esc(f.t)}</b></div>`).join("")}</div>`;
const fhStack=L=>`<div class="cstk">${L.slice(0,3).map((f,i)=>`<i class="cp${f.po?" img":""}" style="--a:${f.c[0]};--b:${f.c[1]};${f.po?`background-image:url(${f.po})`:""}"></i>`).join("")}</div>`;
const fhBtn=(i,lbl,a,extra="")=>`<div class="btn ${i===0?"prim":""}" data-f data-fid="fh-b${i}" ${i===0?"data-default":""} data-act="${a}" data-row="fhh" ${extra}>${lbl}</div>`;

/* ---------- bannière : 5 types de pages ---------- */
function fhSlides(){const n=fhNow(),eve=n>=17*60&&n<=21*60+30,L=[];
 const nw=fhNew(),arr=nw.slice(0,5).sort((a,b)=>(b.f.tmd?b.f.tmd.vc||0:b.f.imdb*100)-(a.f.tmd?a.f.tmd.vc||0:a.f.imdb*100))[0];
 const tv=fhTV().filter(x=>!arr||x.f.id!==arr.f.id);
 if(tv.length){const x=tv.find(y=>!y.live)||tv[0],f=x.f,o=tv.filter(y=>y!==x).slice(0,2);
  L.push({k:"tv",tr:f,tag:"📺 CE SOIR À LA TÉLÉ",bg:fxArt(f),title:f.t,font:fxFont(f),
   meta:`<span class="chp" style="--cc:${x.c.col}">${esc(x.c.n)}</span><span>${esc(x.t)}</span><span>${f.y}</span><span>${fxD(f.d)}</span><span class="st">★ ${f.imdb}</span>`,
   sub:`À regarder en direct, ou dès maintenant <b>sans pub</b> chez ton fournisseur.`,
   btns:[[`${FXI.play}<span class="vpill">Sans pub, maintenant<small>${fxQual(f)||"chez ton fournisseur"} · fin ${fmt(bInfo(f).end)}</small></span>`,"fhplay:"+f.id,f.id],[x.live?`📺 Regarder sur ${x.c.n}`:`📺 Me rappeler à ${fmt(x.p.s%1440)}`,"fhtv:"+x.c.id+":"+x.p.s],["Voir la fiche","fxopen:"+f.id]],
   more:o.map(y=>`${esc(fxShort(y.f))} (${esc(y.c.n)}, ${esc(y.t)})`).join(" · ")})}
 if(arr){const f=arr.f;L.push({k:"arr",tr:f,tag:"✦ L'ARRIVÉE DE LA SEMAINE",bg:fxArt(f),title:f.t,font:fxFont(f),
  meta:`<span class="chp" style="--cc:#8b9cff">${esc(fhProv(f))}</span><span>${fhAgo(arr.d)}</span><span>${f.y}</span><span>${fxD(f.d)}</span><span class="st">★ ${f.imdb}</span>${fxQual(f)?`<span class="qpill">${fxQual(f)}</span>`:""}`,
  sub:esc(f.s||"").slice(0,170)+((f.s||"").length>170?"…":""),btns:[[`${FXI.play}<span class="vpill">${playLbl(f)}<small>${playSub(f)}</small></span>`,"fhplay:"+f.id,f.id],["Voir la fiche","fxopen:"+f.id],[isFav(f.id)?"Retirer de ma liste":"Ajouter à ma liste","fhlist:"+f.id]]})}
 const mk=fhMomKey(),M=MOMS[mk],mi=fhFilms().filter(f=>!fhNo(f.id)&&M.f(f)).sort((a,b)=>b.imdb-a.imdb);
 if(mi.length>=3)L.push({k:"mom",tr:mi[0],tag:M.tag,bg:fhMosaic(mi),title:M.ic+" "+M.t,font:"",big:1,meta:`<span>${mi.length} films</span><span>${mi.slice(0,3).map(f=>esc(fxShort(f))).join(" · ")}…</span>`,sub:esc(M.s),
  btns:[["Voir la collection","fhcoll:mom:"+mk],["🎲 Un au hasard","fhrand:"+mk],...(M.duo?[[FXS.duo?"👥 Mode à deux activé":"👥 Passer en mode à deux","fhduo"]]:[])]});
 const hon=fhHon();if(hon){const seen=hon.L.filter(f=>fhSeen(f.id)),nx=hon.L.find(f=>!fhSeen(f.id)&&!S.prog[f.id])||hon.L[0];
  L.push({k:"hon",tr:nx,tag:"🎬 À L'HONNEUR CETTE SEMAINE",bg:fhMosaic(hon.L),title:hon.who,font:"",big:1,meta:`<span>${hon.L.length} films chez ton fournisseur</span><span>tu en as vu ${seen.length}</span>`,
   sub:`${seen.length?`Tu as vu ${seen.slice(0,2).map(f=>esc(fxShort(f))).join(" et ")}. `:""}Le prochain à voir : <b>${esc(nx.t)}</b>.`,
   btns:[[`${FXI.play}<span class="vpill">${esc(fxShort(nx))}<small>${fxD(nx.d)} · fin ${fmt(bInfo(nx).end)}</small></span>`,"fhplay:"+nx.id,nx.id],["Tous ses films","fhcoll:dir:"+hon.who]]})}
 const so=(TMD.soon&&TMD.soon.length?TMD.soon:REAL?[]:SOON_DEMO)[0];
 if(so){const al=(S.fhAlerts||[]).includes(so.t);L.push({k:"soon",tr:null,trt:so.t,tag:"🔔 BIENTÔT CHEZ TOI",bg:so.bd?`<div class="art img" style="background-image:url(${so.bd})"></div>`:`<div class="art" style="--a:${(so.c||["#5aa0c8"])[0]};--b:${(so.c||["","#06121a"])[1]}"><i></i><i></i><i></i></div>`,title:so.t,font:"f-bebas",
  meta:`<span>${so.y||""}</span>${so.va?`<span class="st">★ ${(+so.va).toFixed(1)}</span>`:""}<span class="ok2">au cinéma depuis le ${fhDate(so.cine)}</span>`,
  sub:`${esc((so.ov||"").slice(0,130))}${(so.ov||"").length>130?"…":""}<br><small>Pas encore chez ton fournisseur${so.vod?` · en streaming vers ${fhMonth(so.vod)}`:""}. prisme te prévient dès qu'il arrive.</small>`,
  btns:[[al?"✓ Alerte activée":"🔔 Préviens-moi","fhalert:"+encodeURIComponent(so.t)],["▶ Bande-annonce","fhtrl"]]})}
 const ord=eve?["tv","arr","mom","hon","soon"]:["arr","mom","hon","tv","soon"];return ord.map(k=>L.find(s=>s.k===k)).filter(Boolean)}
function fhHero(){const L=fhSlides();if(!L.length)return `<section class="hero h1h mchero c3h" data-anchor><div class="shade"></div><div class="tx"><h1 class="t2">Films</h1><p class="hsub">Ajoute une playlist dans Réglages pour voir tes films.</p></div></section>`;
 const i=(FH.h1i%L.length+L.length)%L.length,s=L[i];FH.alt=s.btns.slice(1);FH.slide=s;const m=s.btns[0];
 return `<section class="hero h1h mchero c3h hs-${s.k}" data-anchor>${s.bg}<div class="shade"></div>
 <div class="tx ${FH.hdir==="right"?"inr":FH.hdir==="left"?"inl":""}"><div class="htag">${s.tag}</div><h1 class="${s.font} t2" style="font-size:${s.big?62:Math.round(titleSize({t:s.title,f:""})*.8)}px">${esc(s.title)}</h1>
  <div class="meta">${s.meta}</div><p class="hsub">${s.sub}</p><div class="acts">${fhBtn(0,m[0],m[1],m[2]?`data-hid="${m[2]}"`:"")}</div>
  ${FH.alt.length?`<div class="hmore">OK maintenu : ${FH.alt.map(a=>esc(a[0].replace(/<[^>]+>/g,""))).join(" · ")}</div>`:""}</div>
 <div class="htrl glass">▶ BANDE-ANNONCE · ${esc(s.tr?s.tr.t:s.trt||s.title)}<span>${fhSet().fhVol==="coupe"?"🔇 son coupé":fhSet().fhVol==="faible"?"🔉 son faible":"🔊 son normal"} · une touche pour revenir</span></div><div class="hcd glass">Bande-annonce dans <b>3</b></div>
 <div class="hnav l">‹</div><div class="hnav r">›</div><div class="dots">${L.map((x,j)=>`<i class="${j===i?"on":""}"></i>`).join("")}<i class="cnt">${i+1} / ${L.length}</i></div></section>`}

/* ---------- Ce soir ? ---------- */
function askLbl(d){if(d==="d")return "⏱ "+(DURS.find(x=>x[0]===(S.fhd||"all"))||DURS[0])[1];if(d==="m"){const m=MOODS.find(x=>x[0]===S.fhm);return m?m[2]+" "+m[1]:"✨ Toutes les envies"}return FXS.duo?"👥 À deux":"👤 Seul"}
function askBar(){const op=FH.ask,ids=Object.keys(PR.list);let h;
 if(op){const L=op==="d"?DURS.map(x=>[x[0],x[1]]):op==="m"?[["all","Toutes les envies"],...MOODS.map(x=>[x[0],x[2]+" "+x[1]])]:[["solo","Seul"],...(ids.length>1?[["duo","À deux"]]:[])],cur=op==="d"?(S.fhd||"all"):op==="m"?(S.fhm||"all"):(FXS.duo?"duo":"solo");
  h=`<div class="qk">${op==="d"?"DURÉE":op==="m"?"ENVIE":"AVEC"}</div>`+L.map(([k,n])=>`<div class="hchip ${cur===k?"sel":""}" data-f data-fid="fh-o-${k}" data-act="fhaset:${op}:${k}" data-row="fhq" ${cur===k?"data-default":""}>${n}</div>`).join("")+`<div class="hchip ghost" data-f data-fid="fh-o-x" data-act="fhax" data-row="fhq">← Retour</div>`}
 else h=["d","m","w"].map(d=>`<div class="hchip dd" data-f data-fid="fh-q-${d}" data-act="fhask:${d}" data-row="fhq">${askLbl(d)}<i>▾</i></div>`).join("")+`<div class="hchip" data-f data-fid="fh-q-dice" data-act="fhdice" data-row="fhq">🎲 Surprends-moi</div>`;
 return `<div class="qbar hline ${op?"open":""}">${h}</div>`}
const fhPct=o=>o&&o.pct?`<span class="pct">${o.pct} %</span>`:o&&o.pA!=null?`<span class="pct">${o.pA} · ${o.pB}</span>`:"";
function fhPst(f,fid,row,o,badge=""){return fxPst(f,fid,"fxopen:"+f.id,row,`data-hid="${f.id}"`).replace('<div class="pt">',`${fhPct(o)}${badge}${fhIsNew(f.id)?'<i class="ndot"></i>':""}<div class="pt">`)}
function fhTonightPst(o,fid,row){const f=o.c,b=bInfo(f);return fhPst(f,fid,row,o,`<span class="fint ${b.late>0?"late":""}">fin ${fmt(b.end)}${b.late<=0?" ☾":""}</span>`)}
function fhLcard(f,fid,row,sub,a){const p=S.prog[f.id];return `<div class="lcd" data-f data-fid="${fid}" data-act="${a||"fhplay:"+f.id}" data-row="${row}" data-hid="${f.id}">${fxArt(f)}<div class="sh2"></div>${ME().split[f.id]!=null&&p?'<span class="tagp">PARTIE 2</span>':""}<div class="t"><b>${esc(f.t)}</b><span>${esc(sub)}</span></div>${p?`<div class="pb"><i style="width:${p*100}%"></i></div>`:""}<div class="ply">${FXI.play}</div></div>`}
const fhAll=(row,ck,n,kind="p")=>`<div class="allt ${kind}" data-f data-fid="${row}-all" data-act="fhcoll:${ck}" data-row="${row}"><i>›</i><b>Tout voir</b><small>${n} films</small></div>`;
function fhSec(k,title,sub,inner,cls=""){return inner?`<section data-anchor data-rk="${k}" class="hsec ${cls}"><div class="lh">${title}${sub?`<small>${sub}</small>`:""}</div><div class="row sx">${inner}</div></section>`:""}

/* ---------- collections (Explorer, Tout voir, bannière) ---------- */
function fhColls(){const ck="co|"+FILMS.length+"|"+TMD.n+"|"+PR.cur+"|"+ME().seen.length+"|"+ME().no.length;if(FH.cache[ck])return FH.cache[ck];const av=fhFilms().filter(f=>!fhNo(f.id)),C=[];
 C.push({k:"soir",n:"Ce soir",ic:"🌙",why:"Selon ta durée, ton envie et avec qui tu regardes",items:()=>h2Res().map(o=>o.c)});
 C.push({k:"nouveau",n:"Nouveau sur prisme",ic:"✦",why:"Les ajouts des deux dernières semaines chez ton fournisseur",items:()=>fhNew().map(x=>x.f)});
 C.push({k:"pourtoi",n:"Pour toi",ic:"✨",why:"Croisé entre tes films finis et TMDB",items:()=>forYou().map(o=>o.c)});
 C.push({k:"liste",n:"Ma liste",ic:"＋",why:"Les films que tu as mis de côté",items:()=>S.favs.map(id=>ALL[id]).filter(f=>f&&f.type==="f"&&srcs(f.id).length)});
 C.push({k:"court",n:"Moins de 2 h",ic:"⏱",why:"Pour un film qui ne finit pas trop tard",items:()=>av.filter(f=>f.d<120).sort((a,b)=>b.imdb-a.imdb)});
 C.push({k:"fr",n:"Cinéma français",ic:"🇫🇷",why:"Films produits en France",items:()=>av.filter(f=>f.tmd?/\bFR\b/.test(f.tmd.pays||""):(f.cat||[]).includes("fr"))});
 C.push({k:"top",n:"★ 8 et plus",ic:"🏆",why:"Les mieux notés de ton abonnement",items:()=>av.filter(f=>f.imdb>=8).sort((a,b)=>b.imdb-a.imdb)});
 const by={};av.forEach(f=>(f.dir||"").split(",").map(s=>s.trim()).filter(Boolean).forEach(d=>(by[d]=by[d]||[]).push(f)));
 Object.entries(by).filter(([d,L])=>L.length>=3).sort((a,b)=>b[1].length-a[1].length).slice(0,4).forEach(([d,L])=>C.push({k:"dir:"+d,n:"Signé "+d.split(" ").pop(),ic:"🎬",why:`${d} · ${L.length} films chez ton fournisseur`,items:()=>L.slice().sort((a,b)=>a.y-b.y)}));
 const T=taste(),kws=Object.entries(T.kw).sort((a,b)=>b[1]-a[1]).map(x=>x[0]).filter(k=>av.filter(f=>tmOf(f).kw.includes(k)).length>=3).slice(0,2);
 kws.forEach(k=>C.push({k:"kw:"+k,n:k[0].toUpperCase()+k.slice(1),ic:"🧭",why:`Un thème que tu regardes souvent (mot-clé TMDB « ${k} »)`,items:()=>av.filter(f=>tmOf(f).kw.includes(k))}));
 for(const [mk,M] of Object.entries(MOMS))C.push({k:"mom:"+mk,n:M.t,ic:M.ic,why:M.s,items:()=>av.filter(M.f).sort((a,b)=>b.imdb-a.imdb),hide:1});
 const cols={};av.forEach(f=>{const c=f.tmd&&f.tmd.col;if(c)(cols[c[0]]=cols[c[0]]||{n:c[1],L:[]}).L.push(f)});
 Object.entries(cols).filter(([id,x])=>x.L.length>=2).forEach(([id,x])=>C.push({k:"col:"+id,n:x.n,ic:"🧩",why:"Saga complète (collection TMDB), dans l'ordre",items:()=>x.L.slice().sort((a,b)=>a.y-b.y),hide:1,lic:1}));
 const cos=TMD.co||{};Object.entries(cos).forEach(([id,x])=>C.push({k:"co:"+id,n:x.n,ic:"🎞",why:`Studio · ${x.k} films chez ton fournisseur`,items:()=>av.filter(f=>f.tmd&&(f.tmd.co||[]).includes(+id)),hide:1,lic:1,lg:x.lg}));
 return FH.cache[ck]=C}
const fhColl=k=>fhColls().find(c=>c.k===k);
const FHSORT=[["pert","Pertinence"],["note","Note"],["duree","Durée"],["recent","Récent"]];
function fhCollHtml(k){const c=fhColl(k)||{n:"Collection",why:"",items:()=>[]},s=S.fhsort||"pert";let L=c.items().slice();
 if(s==="note")L.sort((a,b)=>b.imdb-a.imdb);else if(s==="duree")L.sort((a,b)=>a.d-b.d);else if(s==="recent")L.sort((a,b)=>b.y-a.y);
 return `<div class="gview"><div class="ghead"><div class="kick">FILMS · ${c.ic||""} COLLECTION</div><h1>${esc(c.n)}</h1><div style="opacity:.7;font-size:16px;margin:-6px 0 12px">${esc(c.why)}</div>
 <div class="chips">${FHSORT.map(([v,n])=>`<div class="chip ${s===v?"sel":""}" data-f data-fid="fs-${v}" data-row="fsort" data-act="fhsort:${v}">${n}</div>`).join("")}</div></div>
 <div class="gcount">${L.length} film${L.length>1?"s":""}</div><div class="ggrid sy" id="ggrid">${L.map((i,n)=>card(i,"g"+Math.floor(n/7)).replace('data-f ',n===0?'data-f data-default ':'data-f ')).join("")}</div></div>`}

/* ---------- Parcourir : Catégories / Licences et sagas ---------- */
const LICS_DEMO=[["Disney","Studio",412,"#3b6fd8"],["Pixar","Studio",27,"#4aa3df"],["Marvel","Univers",34,"#c8423b"],["Star Wars","Saga",12,"#d8c25a"],["Harry Potter","Saga",11,"#a0824e"],["DC","Univers",29,"#3a7bd5"],["James Bond","Saga",25,"#9aa3ad"],["Le Seigneur des anneaux","Saga",6,"#b88a3e"],["Jurassic Park","Saga",7,"#6c9b4a"],["Mission: Impossible","Saga",8,"#d0563a"],["Fast & Furious","Saga",11,"#e08a3c"]];
/* tendance d'une licence : films populaires en France cette semaine (films.json), sinon classement de démonstration */
function fhTrendOf(L){const pop=TMD.pop||{};let sc=0;for(const f of L){const r=f.tm&&pop[f.tm];if(r)sc+=101-r}
 const tl=fhTop().map(x=>x.f.id);L.forEach(f=>{const i=tl.indexOf(f.id);if(i>=0)sc+=30-i*2});
 const ts=L.map(f=>trendScore(f)).sort((a,b)=>b-a).slice(0,3);return sc*10+ts.reduce((a,b)=>a+b,0)/Math.max(1,ts.length)+Math.max(0,...L.map(f=>f.y))/1e4}
function fhLics(){const C=fhColls().filter(c=>c.lic);
 if(C.length)return C.map(c=>{const L=c.items();return {n:c.n,k:c.k.startsWith("co:")?"Studio":"Saga",d:L.length,c:"#"+((hash(c.k)&0xffffff)|0x404040).toString(16).slice(-6),a:"fhcoll:"+c.k,lg:c.lg,tr:fhTrendOf(L)}}).filter(x=>x.d>=2).sort((a,b)=>b.tr-a.tr).map((x,i)=>({...x,rk:i+1}));
 return LICS_DEMO.map(([n,k,d,c],i)=>({n,k,d,c,a:"fhdemo:"+encodeURIComponent(n),tr:LICS_TR[i]||0})).sort((a,b)=>b.tr-a.tr).map((x,i)=>({...x,rk:i+1}))}
const LICS_TR=[70,40,95,88,55,48,62,20,35,66,58];
function fhBrowse(){const t=FH.catT,G=genreList("f"),L=fhLics();
 const inner=t==="cat"?G.map(({g,items})=>`<div class="gword" style="--cc:${g[2]}" data-f data-fid="fhg-${g[0]}" data-act="genre:f:${g[0]}" data-row="fhg"><b>${esc(g[1])}</b><small>${items.length} films</small></div>`).join("")
  :L.map(l=>`<div class="lic2" style="--cc:${l.c}" data-f data-fid="fhx-${hash(l.n)}" data-act="${l.a}" data-row="fhx">${l.rk<=3?`<span class="ltr">🔥 ${l.rk===1?"N° 1":"Top "+l.rk}</span>`:""}${l.lg?`<img class="lgo" src="${l.lg}" alt="">`:`<span class="ph">LOGO</span>`}<b>${esc(l.n)}</b><small>${l.k} · ${l.d} films</small></div>`).join("");
 return `<section data-anchor data-rk="browse" class="hsec browse"><div class="lh">Parcourir${t==="lic"?`<small>classées selon les tendances de la semaine${TMD.pop?" en France":""}</small>`:""}</div><div class="btabs hline">${[["cat","Catégories",G.length],["lic","Licences et sagas",L.length]].map(([k,n,c])=>`<div class="btab ${k===t?"sel":""}" data-f data-fid="fhbt-${k}" data-bt="${k}" data-act="fhbt:${k}" data-row="fhbt">${n}<small>${c}</small></div>`).join("")}</div><div class="row sx">${inner}</div></section>`}

/* ---------- la page ---------- */
function fhSkel(){const r=(n,w,h)=>`<div class="sk-row">${Array.from({length:n},()=>`<i class="sk" style="width:${w}px;height:${h}px"></i>`).join("")}</div>`;
 return `<div class="H H1 MC C3 skel"><div class="sk-hero"><i class="sk" style="width:120px;height:22px"></i><i class="sk" style="width:440px;height:56px"></i><i class="sk" style="width:340px;height:18px"></i><i class="sk" style="width:220px;height:50px;border-radius:14px"></i></div><div class="sk-band"><i class="sk" style="width:160px;height:24px"></i>${r(8,128,192)}</div></div>`}
function fhView(){if(FH.skel)return fhSkel();fhLast();
 const P0=forYou(),R=h2Res(),pm={};P0.forEach(o=>pm[o.c.id]=o);const shown=new Set(R.slice(0,6).map(o=>o.c.id));
 const rs=fhResume(),sn=fhSagaNext().filter(x=>!rs.includes(x.f));
 const rI=rs.map(f=>fhLcard(f,"fhr-"+f.id,"fhr",ME().split[f.id]!=null?`${fxD(f.d*(1-S.prog[f.id]))} · avec résumé`:`reste ${fxD(f.d*(1-S.prog[f.id]))}`)).join("")+sn.map(x=>fhLcard(x.f,"fhr-"+x.f.id,"fhr","🧩 "+x.why,"fxopen:"+x.f.id).replace('<div class="t">','<span class="tagp sg">SUITE</span><div class="t">')).join("");
 const top=fhTop().map(({f,rk,mv})=>{const c=mv==="NOUV"?"nw":mv[0]==="▲"?"upm":mv[0]==="▼"?"dn":"eq";return `<div class="tp" data-f data-fid="fhk-${f.id}" data-act="fxopen:${f.id}" data-row="fhk" data-hid="${f.id}">${fhIsNew(f.id)?'<i class="ndot"></i>':""}<div class="rk">${rk}</div>${fxPst(f,"","","").replace(/data-f |data-fid="[^"]*" |data-act="[^"]*" /g,"").replace('<div class="pt">',`${fhPct(pm[f.id])}<span class="mv ${c}">${mv==="NOUV"?"NOUVEAU":mv}</span><div class="pt">`)}</div>`}).join("");
 const nwL=fhNew(),nw=nwL.slice(0,12).map(({f,d})=>`<div class="nwc" data-f data-fid="fhw-${f.id}" data-act="fxopen:${f.id}" data-row="fhw" data-hid="${f.id}">${fxArt(f)}${fhIsNew(f.id)?'<i class="ndot"></i>':""}<div class="sh2"></div><div class="nwt"><span class="nwj">NOUVEAU · ${fhAgo(d)}</span>${pm[f.id]?`<span class="pct2">${pm[f.id].pct} %</span>`:""}</div><div class="t"><b>${esc(f.t)}</b><span>${f.y} · ${fxD(f.d)} · ${esc(f.g[0]||"")}</span><div class="pv"><i style="--pc:#8b9cff">${esc(fhProv(f))}</i></div></div></div>`).join("");
 let bf=null,bec=[],bs=-1;for(const id of liked().slice(-6)){const b=ALL[id];if(!b)continue;const L=crossPick(b,"film").filter(o=>!shown.has(o.c.id)&&!fxBlocked(o.c)&&!fhNo(o.c.id)).slice(0,12),sc=L.slice(0,5).reduce((t,o)=>t+o.raw,0)/5;if(sc>bs&&L.length>=3){bs=sc;bf=b;bec=L}}
 const ml=S.favs.map(id=>ALL[id]).filter(f=>f&&f.type==="f"&&srcs(f.id).length&&!fxBlocked(f));
 const C=fhColls().filter(c=>!c.hide&&!["soir","nouveau","pourtoi","liste"].includes(c.k)).map(c=>({c,L:c.items()})).filter(x=>x.L.length>=2).slice(0,6);
 const tiles=C.map(({c,L})=>`<div class="ctile" data-f data-fid="fhe-${hash(c.k)}" data-act="fhcoll:${c.k}" data-row="fhe">${fhStack(L)}<div class="ct"><em>${c.ic}</em><b>${esc(c.n)}</b><span>${L.length} films</span></div></div>`).join("");
 const nNew=[...new Set([...nwL.map(x=>x.f.id),...fhTop().map(x=>x.f.id)])].filter(fhIsNew).length;
 const SEC={reprendre:fhSec("reprendre","Reprendre",rs.length||sn.length?`${rs.length} en cours${sn.length?` · ${sn.length} suite${sn.length>1?"s":""} de saga`:""}`:"",rI),
  top:fhSec("top","🔥 Top 10 du moment",TMD.tr&&TMD.tr.length?"films populaires en France cette semaine · chez ton fournisseur":"les plus regardés cette semaine",top,"topsec"),
  new:fhSec("new","✦ Nouveau sur prisme",`ajouts récents chez ${esc((S.playlists.find(p=>p.on)||{}).name||"ton fournisseur")}${nNew?` · <span class="nwc0">● ${nNew} depuis ta dernière visite</span>`:""}`,nw?nw+fhAll("fhw","nouveau",nwL.length,"l"):""),
  bec:bf?fhSec("bec",`Parce que tu as aimé ${esc(fxShort(bf))}`,"même univers, mêmes thèmes (TMDB) · sans les films déjà proposés plus haut",bec.map(o=>fhPst(o.c,"fhb-"+o.c.id,"fhb",o)).join("")+fhAll("fhb","pourtoi",P0.length)):"",
  liste:ml.length?fhSec("liste","Ma liste",`${ml.length} film${ml.length>1?"s":""} mis de côté`,ml.slice(0,12).map(f=>fhPst(f,"fhl-"+f.id,"fhl",pm[f.id])).join("")+(ml.length>12?fhAll("fhl","liste",ml.length):"")):"",
  explore:fhSec("explore","Explorer","des collections faites à partir de ton fournisseur",tiles),browse:fhBrowse()};
 const h=fhP(),rows=h.ord.filter(k=>!h.hid.includes(k)).map(k=>SEC[k]||"").join("\n");
 return `<div class="H H1 MC C3 sy" id="hscr">${fhHero()}
 <div class="below mcb"><div data-anchor class="anc"><section data-rk="soir" class="hsec tonight glassband"><div class="mcl"><div class="lh">🌙 Ce soir ?<small>${R.length} films · il est ${fmt(fhNow())}</small></div>${askBar()}</div><div class="row sx">${R.length?R.slice(0,12).map(o=>fhTonightPst(o,"fht-"+o.c.id,"fht")).join("")+(R.length>12?fhAll("fht","soir",R.length):""):`<div class="empty0">Aucun film avec ces choix · change la durée ou l'envie</div>`}</div></section></div>
 ${rows}${h.hid.length?`<div class="hidn">${h.hid.length} rangée${h.hid.length>1?"s":""} masquée${h.hid.length>1?"s":""} · Réglages › Accueil Films pour les rétablir</div>`:""}<div style="height:40px"></div></div></div>`}
{const _h=homeHtml;homeHtml=function(){if(inApp()&&S.tab==="films"){if(!FH.skelDone){FH.skelDone=true;FH.skel=true;setTimeout(()=>{FH.skel=false;if(fhOn()&&!S.modal)render(F&&F.dataset.fid&&!/^tab-/.test(F.dataset.fid)?F.dataset.fid:undefined)},650)}
  return tabbar()+fxC(`<div class="fx fxhome">${fhView()}</div>`)}return _h()}}

/* ---------- actions ---------- */
function fhAct(k,v,w){const pf=F&&F.dataset.fid;
 switch(k){
 case "fhplay":{const f=ALL[v];if(!f)return;if(fxBlocked(f))return toast(`🔒 Ce film dépasse la limite du profil`);if(FXS.ready!==v)FXS.ready=FH.prep===v?v:null;return fxStart(v)}
 case "fhlist":{if(isFav(v))S.favs=S.favs.filter(z=>z!==v);else S.favs.push(v);save();render(pf);return toast(isFav(v)?"＋ Ajouté à ma liste":"Retiré de ma liste")}
 case "fhcoll":{const key=[v,w].filter(x=>x!=null).join(":");S.fhsort="pert";push({t:"fhcoll",k:key});return}
 case "fhsort":S.fhsort=v;render("fs-"+v);{const g=$("#ggrid");if(g)g.scrollTop=0}return;
 case "fhask":{FH.ask=v;const c=v==="d"?(S.fhd||"all"):v==="m"?(S.fhm||"all"):(FXS.duo?"duo":"solo");return render("fh-o-"+c)}
 case "fhax":{const d=FH.ask;FH.ask=null;return render("fh-q-"+d)}
 case "fhaset":{const d=FH.ask;if(d==="d")S.fhd=w;else if(d==="m")S.fhm=w==="all"?"":w;else{const ids=Object.keys(PR.list);if(w==="duo"&&ids.length>1){FXS.duo=[PR.cur,ids.find(x=>x!==PR.cur)];FXS.cache={}}else{FXS.duo=null;FXS.cache={}}FH.cache={}}
  FH.ask=null;render("fh-q-"+d);const n=h2Res().length;return toast(n?`${n} films pour ce soir`:"Aucun film avec ces choix")}
 case "fhdice":{const R=h2Res();if(!R.length)return toast("Aucun film avec ces choix");const o=R[Math.floor(Math.random()*Math.min(6,R.length))];toast("🎲 "+o.c.t);setTimeout(()=>act("fxopen:"+o.c.id),500);return}
 case "fhtv":{const c=CH[v];if(!c)return;if(+w<=fhNow())return act("live:"+v);return toast(`⏰ Rappel programmé : ${c.n}, ${fmt(+w%1440)}`)}
 case "fhalert":{const t=decodeURIComponent(v);S.fhAlerts=S.fhAlerts||[];if(S.fhAlerts.includes(t))S.fhAlerts=S.fhAlerts.filter(x=>x!==t);else S.fhAlerts.push(t);render("fh-b0");return toast(S.fhAlerts.includes(t)?"🔔 Tu seras prévenu dès qu'il arrive chez ton fournisseur":"Alerte retirée")}
 case "fhtrl":return toast("▶ Bande-annonce lue depuis TMDB (YouTube) dans l'appli");
 case "fhduo":{const ids=Object.keys(PR.list);FXS.duo=FXS.duo?null:[PR.cur,ids.find(x=>x!==PR.cur)];FXS.cache={};FH.cache={};return render("fh-b0")}
 case "fhrand":{const M=MOMS[v],L=fhFilms().filter(f=>M.f(f));if(!L.length)return;const f=L[Math.floor(Math.random()*L.length)];toast("🎲 "+f.t);setTimeout(()=>act("fxopen:"+f.id),500);return}
 case "fhdemo":return toast(`Exemple : « ${decodeURIComponent(v)} » apparaîtra avec son logo quand films.json sera importé`);
 case "fhbt":{const r=view.querySelector(".browse "+fxQ("row")+" [data-f]");if(r)setFocus(r);return}
 case "fhalt":{const a=FH.alt[+v];S.modal=null;render("fh-b0");if(a)setTimeout(()=>act(a[1]),30);return}
 case "fhc":return fhCtxDo(v);
 case "fhrst":{fhP().hid=[];prSave();render("set-fhrst");return toast("Rangées rétablies")}
 case "fhset":{const s=fhSet();if(v==="trl"){const L=[0,5,10,15,30];s.fhTrl=L[(L.indexOf(s.fhTrl)+1)%L.length]}else{const L=["coupe","faible","normal"];s.fhVol=L[(L.indexOf(s.fhVol)+1)%L.length]}save();return render("set-fh"+v)}
 }}
{const _a=act;act=function(a){if(!a)return;const [k,v,w]=a.split(":");if(k.startsWith("fh"))return fhAct(k,v,w);return _a(a)}}

/* ---------- OK maintenu : options de la bannière, ou du film + de la rangée ---------- */
function fhCtxDo(v){const m=S.modal,h=fhP(),i=h.ord.indexOf(m.rk);let msg="",ret=m.ret;S.modal=null;const p=ME();
 if(v==="no"){p.no.push(m.id);FXS.cache={};FH.cache={};msg=`👎 « ${ALL[m.id].t} » ne sera plus proposé`;ret=null}
 if(v==="seen"){if(p.seen.includes(m.id)){p.seen=p.seen.filter(x=>x!==m.id);msg="Marqué comme non vu"}else{p.seen.push(m.id);msg="✓ Marqué comme vu"}FXS.cache={};FH.cache={}}
 if(v==="list"){if(isFav(m.id))S.favs=S.favs.filter(z=>z!==m.id);else S.favs.push(m.id);save();msg=isFav(m.id)?"＋ Ajouté à ma liste":"Retiré de ma liste"}
 if(v==="up"||v==="down"){const j=i+(v==="up"?-1:1);[h.ord[i],h.ord[j]]=[h.ord[j],h.ord[i]];msg=`Rangée ${v==="up"?"montée":"descendue"} · gardé pour ${p.n}`}
 if(v==="hide"){h.hid.push(m.rk);msg="Rangée masquée · Réglages › Accueil Films pour la rétablir";ret=null}
 prSave();render(ret||undefined);
 if(!ret||!view.querySelector(`[data-fid="${CSS.escape(m.ret)}"]`)){const vis=h.ord.filter(x=>!h.hid.includes(x)),has=x=>!!view.querySelector(`[data-rk="${x}"]`),nk=v==="hide"?(h.ord.slice(i+1).find(x=>!h.hid.includes(x)&&has(x))||vis.filter(has).pop()):m.rk;
  const s=view.querySelector(`[data-rk="${nk}"]`)||view.querySelector("[data-rk]");const e=s&&(s.querySelector(fxQ("row")+" [data-f]")||s.querySelector("[data-f]"));if(e)setFocus(e)}
 toast(msg)}
function fhModal(m){const opt=(fid,a,b,s,d)=>`<div class="opt" data-f data-fid="${fid}" data-act="${a}" ${d?"data-default":""}><div class="tx"><b>${b}</b>${s?`<span>${s}</span>`:""}</div></div>`;
 if(m.type==="fxhopt")return `<div class="modal"><div class="mbox glass" style="width:560px"><div class="k">PLUS D'OPTIONS</div><h2>${esc(FH.slide?FH.slide.title:"")}</h2>${FH.alt.map((a,i)=>opt("ho-"+i,"fhalt:"+i,a[0].replace(/<[^>]+>/g,""),"",i===0)).join("")}${opt("ho-x","fxclose","Fermer","")}</div></div>`;
 if(m.type==="fxhctx"){const f=m.id&&ALL[m.id],h=fhP(),i=h.ord.indexOf(m.rk),fixed=m.rk==="soir",p=ME();
  const fo=f?[["no","👎 Pas pour moi","Il ne te sera plus proposé"],["seen",p.seen.includes(f.id)?"↺ Marquer comme non vu":"✓ Déjà vu","Ça affine tes suggestions"],["list",isFav(f.id)?"− Retirer de ma liste":"＋ Ajouter à ma liste",""]]:[];
  const ro=fixed||!m.rk?[]:[i>0&&["up","▲ Monter la rangée",""],i<h.ord.length-1&&["down","▼ Descendre la rangée",""],["hide","Masquer la rangée","Réglages › Accueil Films pour la rétablir"]].filter(Boolean);
  return `<div class="modal"><div class="mbox glass" style="width:600px;max-height:690px">${f?`<div class="k">CE FILM</div><h2>${esc(f.t)}</h2>${fo.map((a,j)=>opt("hc-"+a[0],"fhc:"+a[0],a[1],a[2],j===0)).join("")}`:""}
  ${m.rk?`<div class="k" style="margin-top:${f?14:0}px">CETTE RANGÉE · ${esc(fixed?"Ce soir ?":FHNAMES[m.rk]||"")}</div>${fixed?`<div class="mfoot" style="text-align:left">« Ce soir ? » reste toujours sous la bannière.</div>`:ro.map((a,j)=>opt("hc-"+a[0],"fhc:"+a[0],a[1],a[2],!f&&j===0)).join("")}`:""}
  ${opt("hc-x","fxclose","Fermer","")}<div class="mfoot">Gardé pour le profil ${esc(p.n)}</div></div></div>`}
 return ""}
{const _fm=fxModal;fxModal=function(){const m=S.modal;if(m&&/^fxh(opt|ctx)$/.test(m.type))return fhModal(m);return _fm()}}

/* ---------- réglages : Accueil Films ---------- */
{const _s=settingsHtml;settingsHtml=function(){const h=_s(),s=fhSet(),hh=fhP();const sec=`<section data-anchor><h3>Accueil Films</h3><div class="grp">
 <div class="it" data-f data-fid="set-fhtrl" data-act="fhset:trl"><span>Bande-annonce quand tu restes sur la bannière</span><span>${s.fhTrl?"après "+s.fhTrl+" s":"désactivée"}</span></div>
 <div class="it" data-f data-fid="set-fhvol" data-act="fhset:vol"><span>Son de cette bande-annonce</span><span>${{coupe:"coupé",faible:"faible",normal:"normal"}[s.fhVol]}</span></div>
 <div class="it" data-f data-fid="set-fhrst" data-act="fhrst"><span>Rangées masquées (${esc(ME().n)})</span><span>${hh.hid.length?hh.hid.map(k=>FHNAMES[k]).join(", ")+" · OK pour rétablir":"aucune"}</span></div></div></section>`;
 const i=h.indexOf("<section data-anchor><h3>Lecteur</h3>");return i<0?h+sec:h.slice(0,i)+sec+h.slice(i)}}

/* ---------- navigation : une ligne à la fois, début de rangée ou mémoire ---------- */
function fhLines(){const q=["#hscr "+fxQ("row"),"#hscr .hline","#hscr .acts"].join(",");return [...view.querySelectorAll(q)].filter(x=>x.querySelector("[data-f]"))}
function fhNav(k){const ln=F.closest(fxQ("row")+",.hline,.acts");if(!ln||!ln.closest("#hscr"))return false;const L=fhLines(),i=L.indexOf(ln);if(i<0)return false;
 const n=L[i+(k==="down"?1:-1)];if(!n){if(k==="down")return true;return false}
 const r0=n.querySelector("[data-row]"),row=r0&&r0.dataset.row,mem=row&&rowMem[row]&&n.querySelector(`[data-fid="${CSS.escape(rowMem[row])}"]`);
 if(mem&&!n.classList.contains("qbar")){setFocus(mem);return true}
 if(n.classList.contains("qbar")||n.classList.contains("acts")){const fx=F.getBoundingClientRect().left;let b=null,bd=1e9;for(const c of n.querySelectorAll("[data-f]")){const d=Math.abs(c.getBoundingClientRect().left-fx);if(d<bd){bd=d;b=c}}if(n.classList.contains("qbar")&&mem)b=mem;setFocus(b);return true}
 const sr=scr.getBoundingClientRect(),fv=[...n.querySelectorAll("[data-f]")].find(c=>c.getBoundingClientRect().left>=sr.left-5);setFocus(fv||n.querySelector("[data-f]"));return true}
function fhHoriz(k){const ln=F.closest(fxQ("row")+",.hline,.acts");if(!ln||!ln.closest("#hscr"))return false;const L=[...ln.querySelectorAll("[data-f]")],x=F.getBoundingClientRect().left;
 const C=L.filter(e=>e!==F&&(k==="right"?e.getBoundingClientRect().left>x+2:e.getBoundingClientRect().left<x-2)).sort((a,b)=>Math.abs(a.getBoundingClientRect().left-x)-Math.abs(b.getBoundingClientRect().left-x));if(C[0])setFocus(C[0]);return true}
function fhCarousel(k){const hb=F.closest(".acts");if(!hb||!hb.closest(fxQ("hero")))return false;const nd=view.querySelectorAll(".dots i:not(.cnt)").length;if(nd<2)return false;
 FH.h1i=((FH.h1i+(k==="right"?1:-1))%nd+nd)%nd;FH.hdir=k;FXS.ready=null;FH.prep=null;render("fh-b0");FH.hdir=null;return true}
let FHT=0;function fhTick(){clearInterval(FHT);FHT=setInterval(()=>{if(!fhOn()||S.modal||FH.skel)return;if(F&&(F.closest(fxQ("hero"))||F.closest(".hline")))return;const sc=$("#hscr");if(!sc||sc.scrollTop>200)return;if(view.querySelector(".hpeek"))return;FH.h1i++;render(F&&F.dataset.fid)},8000)}
/* grilles (Tout voir, genres) : ▲ ▼ restent dans la même colonne, ▲ depuis la 1re ligne remonte aux tris */
function gridNav(k){const g=F&&F.closest("#ggrid");if(!g||S.modal||!["up","down","left","right"].includes(k))return false;const r=+(F.dataset.row||"g0").slice(1),row=n=>[...g.querySelectorAll(`[data-row="g${n}"]`)],cur=row(r),i=cur.indexOf(F);
 if(k==="left"||k==="right"){const j=i+(k==="right"?1:-1);if(cur[j])setFocus(cur[j]);else if(k==="right"&&row(r+1)[0])setFocus(row(r+1)[0]);else if(k==="left"&&r>0){const p=row(r-1);setFocus(p[p.length-1])}return true}
 const t=row(r+(k==="down"?1:-1));if(t.length){setFocus(t[Math.min(i,t.length-1)]);return true}
 if(k==="up"){const c=view.querySelector(".chips .sel[data-f]")||view.querySelector(".chips [data-f]");if(c){setFocus(c);g.scrollTo({top:0,behavior:"smooth"})}}return true}
{const _k=key;key=function(k){bubOff();if(gridNav(k))return;
 if(k==="menu"&&!S.modal&&F&&F.closest("#ggrid")&&ALL[F.dataset.hov]&&ALL[F.dataset.hov].type==="f"){S.modal={type:"fxhctx",id:F.dataset.hov,rk:null,ret:F.dataset.fid};return render()}const pk=view.querySelector(".hpeek");if(pk){hPeekOff();if(F)hPeekArm(F);return}
 if(fhOn()&&!S.modal&&F){
  if(k==="menu"&&F.dataset.row==="tabs")return toast("Maintiens le clic sur un film pour ses options");
  if(k==="menu"){if(F.closest(fxQ("hero"))){if(FH.alt.length){S.modal={type:"fxhopt",ret:F.dataset.fid};return render("ho-0")}return toast("Pas d'autre option pour cette page")}const s=F.closest("[data-rk]");
   if(s){if(s.dataset.rk==="soir"&&!F.dataset.hid)return toast("Maintiens le clic sur un film pour ses options");S.modal={type:"fxhctx",id:F.dataset.hid||null,rk:s.dataset.rk,ret:F.dataset.fid};return render()}}
  if(k==="play"&&F.dataset.hid)return fhAct("fhplay",F.dataset.hid);
  if((k==="left"||k==="right")&&fhCarousel(k))return;
  if(k==="down"&&F.dataset.row==="tabs"){const d=view.querySelector(fxQ("hero")+" [data-default]");if(d){setFocus(d);return}}
  if((k==="up"||k==="down")&&fhNav(k))return;
  if((k==="left"||k==="right")&&fhHoriz(k))return;
  if(k==="back"&&F.dataset.row!=="tabs"){const sc=$("#hscr");if(sc)sc.scrollTo({top:0,behavior:"smooth"})}}
 return _k(k)}}

/* ---------- focus : ⚡ préparation, aperçu, points bleus, onglets Parcourir, bande-annonce ---------- */
let PRT=0,BUT=0,HPT=0,HPC=0;
function bubOff(){clearTimeout(BUT);const b=view.querySelector(".fhbub");if(b)b.remove()}
function hPeekOff(){clearTimeout(HPT);clearInterval(HPC);const h=view.querySelector(".hpeek");if(h){h.classList.remove("hpeek");view.querySelectorAll(fxQ("hero")+" .art").forEach(a=>a.classList.remove("play"))}const c=view.querySelector(".hcd");if(c)c.classList.remove("on")}
function hPeekArm(el){hPeekOff();const D=(fhSet().fhTrl||0)*1000;if(!D||!fhOn()||S.modal||!el||!el.closest(".acts")||!el.closest(fxQ("hero")))return;const t0=Date.now();
 HPC=setInterval(()=>{const c=view.querySelector(".hcd");if(!c)return clearInterval(HPC);const left=Math.ceil((D-(Date.now()-t0))/1000);if(left<=3&&left>0){c.classList.add("on");c.querySelector("b").textContent=left}},250);
 HPT=setTimeout(()=>{clearInterval(HPC);if(F!==el||!el.isConnected)return;const h=view.querySelector(".fxhome .H");if(!h)return;h.classList.add("hpeek");const c=view.querySelector(".hcd");if(c)c.classList.remove("on");view.querySelectorAll(fxQ("hero")+" .art").forEach(a=>a.classList.add("play"))},D)}
function prepArm(el){clearTimeout(PRT);if(!fhOn()||!el.dataset.hid||!el.closest('[data-rk="soir"],[data-rk="reprendre"],'+fxQ("hero")))return;
 PRT=setTimeout(()=>{if(F!==el||S.modal)return;FH.prep=el.dataset.hid;FXS.ready=el.dataset.hid;view.querySelectorAll(".fhzap").forEach(z=>z.remove());const z=document.createElement("span");z.className="fhzap";z.textContent="⚡ prêt";el.appendChild(z)},1000)}
function bubArm(el){bubOff();if(!fhOn()||!el.dataset.hid||el.closest(fxQ("hero"))||S.modal)return;
 BUT=setTimeout(()=>{if(F!==el||!el.isConnected||S.modal)return;const f=ALL[el.dataset.hid];if(!f)return;const o=forYou().find(x=>x.c.id===f.id),b=bInfo(f),r=el.getBoundingClientRect(),v=view.getBoundingClientRect();
  const x=(r.right-v.left)/SCALE,y=(r.top-v.top)/SCALE,w=340,left=x+16+w<1270?x+16:(r.left-v.left)/SCALE-w-16;const d=document.createElement("div");d.className="fhbub";d.style.left=Math.max(10,left)+"px";d.style.top=Math.max(110,Math.min(720-200,y))+"px";
  d.innerHTML=`<b>${esc(f.t)}</b><p>${esc(f.s||"")}</p><div class="bm"><span>${f.y}</span><span>${fxD(f.d)}</span><span class="${b.late>0?"lt":"ok2"}">fin ${fmt(b.end)}${b.late<=0?" ☾":""}</span>${o&&o.pct?`<span class="ok2">${o.pct} %</span>`:""}<span class="st">★ ${f.imdb}</span></div><small>OK = fiche · ⏯ = lancer · maintiens le clic = options</small>`;view.appendChild(d)},1500)}
function newSeen(el){if(!el.dataset.hid||!fhOn())return;const id=el.dataset.hid;if(!fhIsNew(id))return;const h=fhP();h.nseen.push(id);h.nseen=h.nseen.slice(-300);prSave();view.querySelectorAll(`[data-hid="${CSS.escape(id)}"] .ndot`).forEach(d=>d.classList.add("gone"))}
{const _sf=setFocus;setFocus=function(el,instant){_sf(el,instant);if(!el)return;bubOff();
 view.classList.toggle("fhdown",fhOn()&&!el.closest(fxQ("hero"))&&el.dataset.row!=="tabs");
 if(fhOn()){if(el.dataset.bt&&FH.catT!==el.dataset.bt){FH.catT=el.dataset.bt;render(el.dataset.fid);return}hPeekArm(el);prepArm(el);bubArm(el);newSeen(el)}else{hPeekOff();clearTimeout(PRT)}}}
{const _r=render;render=function(fid){bubOff();view.classList.remove("fhdown");_r(fid);if(fhOn())fhTick();else clearInterval(FHT)}}
