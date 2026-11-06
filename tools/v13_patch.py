# Version 1.3 : images réduites par l'appareil, photos des acteurs, tout le catalogue (catégories, rangées
# chargées au fil du défilement), qualité vidéo plus fiable, diagnostic, défilement des réglages. Exécuté par build_ui.py.

# ---------------------------------------------------------------- images : réduites et gardées en cache par l'appli native
R('const imgS=(u,sz)=>u?String(u).replace(/(image\\.tmdb\\.org\\/t\\/p\\/)(original|w\\d+)\\//,"$1"+sz+"/"):"";',
  '''const IMGW={w185:[210,"w185"],w780:[960,"w780"],l:[160,"w185"],e:[320,"w300"],p:[180,"w185"]};
const imgS=(u,sz)=>{if(!u)return"";const [w,t]=IMGW[sz]||[200,"w185"];u=String(u).replace(/(image\\.tmdb\\.org\\/t\\/p\\/)(original|w\\d+)\\//,"$1"+t+"/");
 return NATIVE&&/^https?:\\/\\//.test(u)?"https://appassets.androidplatform.net/img?w="+w+"&u="+encodeURIComponent(u):u};''')
R('${c.logo?`<img src="${esc(c.logo)}" alt=""', '${c.logo?`<img src="${esc(imgS(c.logo,"l"))}" alt=""')
R('${e.img?`<img src="${esc(e.img)}"', '${e.img?`<img src="${esc(imgS(e.img,"e"))}"')
R('img.style.background=`center/cover no-repeat url("${it.bd||it.img}")`', 'img.style.background=`center/cover no-repeat url("${imgS(it.bd||it.img,"w780")}")`')

# ---------------------------------------------------------------- défilement : sections hautes (réglages de playlist) et mode fluide
R(' const beh=instant?"auto":"smooth";', ' const beh=instant||S.set.lite?"auto":"smooth";')
R('const a=el.closest("[data-anchor]");const tg=a&&p.contains(a)&&a!==p?a:el;',
  'const a=el.closest("[data-anchor]");const tg=a&&p.contains(a)&&a!==p&&a.offsetHeight<p.clientHeight*.9?a:el;')
FN("fit", '''function fit(){const w=innerWidth||1280,h=innerHeight||720;SCALE=Math.min(w/1280,h/720);
 scr.style.transform=Math.abs(SCALE-1)<.01&&Math.abs(w-1280)<4?"":`translate(${(w-1280*SCALE)/2}px,${(h-720*SCALE)/2}px) scale(${SCALE})`}
addEventListener("resize",fit);fit();''')

# ---------------------------------------------------------------- rangées : toutes les catégories, chargées au fil du défilement
R('function rowHtml(id,title,items,fn,count=true){if(!items.length)return"";const total=items.length,rk="r"+(++RSEQ),first=(ROWI++)<4?16:8;ROWS[rk]={items,fn,id,n:Math.min(first,total)};\n if(RSEQ%400===0)Object.keys(ROWS).slice(0,200).forEach(x=>delete ROWS[x]);',
  '''let ROWMAX=1e9,PENDR=[],HOMEPN=[];
function rowHtml(id,title,items,fn,count=true){if(!items.length)return"";if(ROWI>=ROWMAX){ROWI++;PENDR.push([id,title,items,fn,count]);return""}return rowNow(id,title,items,fn,count)}
function lazySx(items,fn,id,first=16){const rk="r"+(++RSEQ);ROWS[rk]={items,fn,id};return `<div class="sx" data-rk="${rk}">${items.slice(0,first).map(i=>fn(i,id)).join("")}</div>`}
function rowNow(id,title,items,fn,count=true){const total=items.length,rk="r"+(++RSEQ),first=(ROWI++)<4?16:8;ROWS[rk]={items,fn,id};
 if(RSEQ%3000===0)Object.keys(ROWS).slice(0,1500).forEach(x=>delete ROWS[x]);''')
R('if(p.dataset.rk){const Rw=ROWS[p.dataset.rk];if(Rw&&Rw.n<Rw.items.length){const idx=Array.prototype.indexOf.call(p.children,el);if(idx>=p.children.length-5){const nx=Rw.items.slice(Rw.n,Rw.n+16);Rw.n+=nx.length;',
  'if(p.dataset.rk){const Rw=ROWS[p.dataset.rk],n=p.children.length,g=Rw&&Rw.id==="cg";if(Rw&&n<Rw.items.length){const idx=Array.prototype.indexOf.call(p.children,el);if(idx>=n-(g?16:5)){const nx=Rw.items.slice(n,n+(g?35:16));')
R('else if(el.classList.contains("lch")&&LIVEL&&LIVEN<LIVEL.length){const idx=Array.prototype.indexOf.call(p.children,el);if(idx>=p.children.length-6){const nx=LIVEL.slice(LIVEN,LIVEN+60);LIVEN+=nx.length;',
  'else if(el.classList.contains("lch")&&LIVEL&&p.children.length<LIVEL.length){const n=p.children.length,idx=Array.prototype.indexOf.call(p.children,el);if(idx>=n-6){const nx=LIVEL.slice(n,n+60);')
R('function more(el){const p=el.parentElement;if(!p)return;',
  '''function more(el){const p=el.parentElement;if(!p)return;
 {const rows=el.closest("#rows"),P2=rows&&rows._p;if(P2&&P2.i<P2.l.length){const secs=rows.querySelectorAll(":scope>section"),sec=el.closest("section"),i=Array.prototype.indexOf.call(secs,sec);
  if(sec&&i>=secs.length-3){const nx=P2.l.slice(P2.i,P2.i+5);P2.i+=nx.length;secs[secs.length-1].insertAdjacentHTML("afterend",nx.map(a=>rowNow(...a)).join(""))}}}''')
R('function homeHtml0(){ROWI=0;', 'function homeHtml0(){ROWI=0;ROWMAX=7;PENDR=[];try{return homeHtml1()}finally{ROWMAX=1e9;HOMEPN=PENDR}}\nfunction homeHtml1(){')
R('if(HOMEC.k!==k){HOMEC.k=k;HOMEC.h=homeHtml0()}return HOMEC.h}', 'if(HOMEC.k!==k){HOMEC.k=k;HOMEC.h=homeHtml0();HOMEC.p=HOMEPN}HOMEPN=HOMEC.p;return HOMEC.h}')
R('function afterRender(t,fid){\n', '''function afterRender(t,fid){
 {const r=$("#rows");if(r&&!r._p)r._p={l:HOMEPN||[],i:0}}
 if(t.t==="detail"&&ALL[t.id])castTmdb(ALL[t.id]);
 if(t.t==="detail"||t.t==="actor"||(t.t==="home"&&S.tab==="search"))wantPhotos([...view.querySelectorAll(".av[data-nm]:not(.has-img)")].map(a=>a.dataset.nm));
''')
R('cats.slice(0,40).forEach(([k,l])=>{if(rowHidden(ty,k))return;rows+=rowHtml("c"+k,l,list.filter(i=>i.cat.includes(k)),card)});',
  'const BC=byCat(ty);cats.forEach(([k,l])=>{if(rowHidden(ty,k))return;rows+=rowHtml("c"+k,l,BC[k]||[],card)});')
R('+rowHtml("new","Derniers ajouts",recent,card,false)', '+catChips(ty)+rowHtml("new","Derniers ajouts",recent,card,false)')
R('function homeHtml(){', '''function byCat(ty){return memo("bc"+ty,()=>{const m={};(ty==="f"?films():series()).forEach(i=>i.cat.forEach(k=>(m[k]=m[k]||[]).push(i)));return m})}
function catChips(ty){const BC=byCat(ty),L=[["*",ty==="f"?"Tous les films":"Toutes les séries",(ty==="f"?films():series()).length],...(ty==="f"?FCATS:SCATS).filter(([k])=>BC[k]&&!rowHidden(ty,k)).map(([k,l])=>[k,l,BC[k].length])];
 if(L.length<2)return"";return `<section class="row" data-anchor><h3>Parcourir par catégorie<small>${L.length-1}</small></h3>${lazySx(L,(c,id)=>`<div class="chip cchip" data-f data-fid="cc-${c[0]}" data-row="ccats" data-act="ocat:${ty}:${c[0]}">${esc(c[1])}<small>${c[2]}</small></div>`,"cc",24)}</section>`}
function catItems(t){const ty=t.ty,s=t.sort||"new";return memo("cat|"+ty+"|"+t.k+"|"+s,()=>{const L=[...(t.k==="*"?(ty==="f"?films():series()):(byCat(ty)[t.k]||[]))];
 if(s==="az")L.sort((a,b)=>String(a.t).localeCompare(String(b.t),"fr"));else if(s==="note")L.sort((a,b)=>(b.tmdb||0)-(a.tmdb||0));
 else{const d=i=>{const a=added(i.id);return a?a.d:1e9};L.sort((a,b)=>d(a)-d(b))}return L})}
function catHtml(t){const L=catItems(t),name=t.k==="*"?(t.ty==="f"?"Tous les films":"Toutes les séries"):(((t.ty==="f"?FCATS:SCATS).find(c=>c[0]===t.k)||[,""])[1]);
 const so=[["new","Derniers ajouts"],["az","A → Z"],["note","Les mieux notés"]],gk="r"+(++RSEQ);ROWS[gk]={items:L,fn:card,id:"cg"};
 return `<div class="det sy" id="catv"><div class="cath"><div class="kick">${t.ty==="f"?"Films":"Séries"} · ${L.length} titre${L.length>1?"s":""}</div><h1>${esc(name)}</h1><div class="csorts">${so.map(([k,l])=>`<div class="chip ${t.sort===k?"sel":""}" data-f data-fid="cs-${k}" data-row="csort" data-act="csort:${k}" ${t.sort===k?"data-default":""}>${l}</div>`).join("")}</div></div>
 ${L.length?`<div class="cgrid" data-rk="${gk}">${L.slice(0,42).map(i=>card(i,"cg")).join("")}</div>`:'<div class="empty" style="padding:0 64px">Aucun titre dans cette catégorie.</div>'}<div style="height:60px"></div></div>`}
function homeHtml(){''')
R(' else if(t.t==="plm") html=plmHtml(t.id);', ' else if(t.t==="plm") html=plmHtml(t.id);\n else if(t.t==="cat") html=catHtml(t);\n else if(t.t==="diag") html=diagHtml();')
R(' else if(t.t==="plm"||(t.t==="home"&&', ' else if(t.t==="plm"||t.t==="cat"||t.t==="diag"||(t.t==="home"&&')
R('  case "actor":', '''  case "ocat": push({t:"cat",ty:v,k:w,sort:"new"});break;
  case "csort":{const t=topS();if(t.t==="cat"&&t.sort!==v){t.sort=v;render("cs-"+v)}break}
  case "diag": if(v==="clrq"){Object.keys(QUAL).forEach(k=>delete QUAL[k]);try{localStorage.removeItem("prisme-q")}catch(e){}toast("Analyses effacées : elles seront refaites");render("dg-clrq")}
   else if(v==="clrph"){Object.keys(PHOTO).forEach(k=>delete PHOTO[k]);try{localStorage.removeItem("prisme-ph")}catch(e){}toast("Photos des acteurs effacées");render("dg-clrph")}
   else if(v==="ref")render(F&&F.dataset.fid);else push({t:"diag"});break;
  case "actor":''')

# ---------------------------------------------------------------- recherche : plus de résultats, plus rapide
R('return {f:films().filter(i=>m(i.t)||m(i.dir)).slice(0,40),s:series().filter(i=>m(i.t)).slice(0,40),',
  'const mt=i=>(i._n||(i._n=norm(String(i.t||"")))).includes(q)||(i.dir&&m(i.dir));\n return {f:films().filter(mt).slice(0,300),s:series().filter(mt).slice(0,300),')
R('<h3>Films</h3><div class="sx">${r.f.map(i=>card(i,"rf")).join("")}</div>', '<h3>Films<small>${r.f.length}</small></h3>${lazySx(r.f,card,"rf")}')
R('<h3>Séries</h3><div class="sx">${r.s.map(i=>card(i,"rs")).join("")}</div>', '<h3>Séries<small>${r.s.length}</small></h3>${lazySx(r.s,card,"rs")}')

# ---------------------------------------------------------------- photos des acteurs (TMDB si clé, sinon Wikipédia)
FN("castCard", '''function castCard(aid,role,row){const n=A[aid]||"",ph=photoOf(n);return `<div class="cast" data-f data-fid="${row}-${aid}" data-row="${row}" data-act="actor:${aid}">${avHtml(aid,n)}<div class="n">${esc(n)}</div>${role?`<div class="r">${esc(role)}</div>`:""}</div>`}
function avHtml(aid,n){const ph=photoOf(n);return `<div class="av ${ph?"has-img":""}" data-nm="${esc(n)}" style="--h:${hash(aid)%360}">${ph?`<img src="${esc(imgS(ph,"p"))}" alt="" decoding="async" onerror="this.parentNode.classList.remove('has-img');this.remove()">`:""}<b>${initials(n)}</b></div>`}''')
R('<div class="act-top" data-anchor><div class="av" style="--h:${hash(aid)%360}">${initials(n)}</div>', '<div class="act-top" data-anchor>${avHtml(aid,n)}')

# ---------------------------------------------------------------- TV en direct : analyse de la chaîne survolée, pastille de qualité
R('if(k==="ch"){S.lch=v;epg(CH[v]);', 'if(k==="ch"){S.lch=v;epg(CH[v]);clearTimeout(LPT);LPT=setTimeout(()=>{if(!P&&topS().t==="home"&&S.tab==="live"&&S.lch===v)analyze("ch:"+v)},900);')
R('let HOVT=null;', 'let HOVT=null,LPT=null;')
R('(n=>n>1?`<span class="nsrc">${n} sources</span>`:"")(srcs("ch:"+c.id).length)}</div>', '(n=>n>1?`<span class="nsrc">${n} sources</span>`:"")(srcs("ch:"+c.id).length)}<span class="qbx">${qBadge("ch:"+c.id)}</span></div>')
R('function liveHtml(){', '''function qBadge(key){const L=srcs(key);let b=null,pend=false;L.forEach(v=>{if(v.q==="Analyse…")pend=true;if(qr(v.q)>0&&v.q!=="Auto"&&(!b||qr(v.q)>qr(b)))b=v.q});
 return b?`<span class="qb q${b} qs">${b}</span>`:pend?'<span class="qb qs qa">…</span>':""}
function liveHtml(){''')
R('function refreshQual(){', 'function refreshQual(){if(inApp()&&topS().t==="home"&&S.tab==="live")view.querySelectorAll(".lch").forEach(el=>{const b=el.querySelector(".qbx");if(b){const h=qBadge(el.dataset.hov);if(b.innerHTML!==h)b.innerHTML=h}});')
R('fail?"Analyse impossible (flux injoignable ou connexion déjà utilisée)":"Qualité lue dans le nom du flux"',
  'fail?"Analyse impossible : "+String(QUAL[k].err||"flux injoignable ou connexion déjà utilisée").slice(0,90):"Qualité lue dans le nom du flux"')

# ---------------------------------------------------------------- réglages : diagnostic, contenu reçu du serveur
R('<div class="it" data-f data-fid="set-par" data-act="set:parental"><span>Contrôle parental (code 0000)</span>${sw(st.parental)}</div>',
  '<div class="it" data-f data-fid="set-par" data-act="set:parental"><span>Contrôle parental (code 0000)</span>${sw(st.parental)}</div>\n  <div class="it" data-f data-fid="set-diag" data-act="diag"><span>Diagnostic</span><span>analyse des flux, chargements, erreurs ›</span></div>')
R('<div class="it"><span>Contenu affiché</span><span>${c.c} chaînes · ${c.f} films · ${c.s} séries</span></div>',
  '''<div class="it tall"><span>Contenu affiché<small>Les versions d'un même titre (4K, 1080p, VF, VOSTFR…) sont regroupées dans une seule fiche</small></span><span>${c.c} chaînes · ${c.f} films · ${c.s} séries</span></div>
  ${(D=>D?`<div class="it tall"><span>Reçu du serveur<small>${Object.keys(D.lc||{}).length+Object.keys(D.vc||{}).length+Object.keys(D.sc||{}).length} catégories${D.fill?` · ${D.fill} complétée${D.fill>1?"s":""} catégorie par catégorie`:""}</small></span><span>${D.live.length} flux TV · ${D.vod.length} films · ${D.ser.length} séries</span></div>`:"")(DATA[p.id])}''')
R('function plmHtml(id){', '''function diagHtml(){const q=Object.values(QUAL),ok=q.filter(x=>x.ok).length,ph=Object.values(PHOTO),nph=ph.filter(x=>x&&x[0]!=="-").length;
 const it=(f,a,b)=>`<div class="it tall" data-f data-fid="${f}"><span>${a}</span><span>${b}</span></div>`;
 return `<div class="set sy" id="set" style="top:60px"><section data-anchor><div class="kick" style="margin-left:18px">Réglages</div><h2 style="margin:6px 0 14px 18px;font-size:40px;font-weight:700;letter-spacing:-.02em">Diagnostic</h2><div class="grp">
  ${it("dg-dev",`Appareil<small>${esc(DEV.model||"navigateur")} · Android ${esc(ANDROID[DEV.sdk]||DEV.sdk||"")} · prisme ${esc(APPV.name)}</small>`,`${innerWidth}×${innerHeight} · ×${SCALE.toFixed(2)}`)}
  ${S.playlists.map(p=>{const D=DATA[p.id];return it("dg-"+p.id,`${esc(p.name)}<small>${D?`${Object.keys(D.vc||{}).length} catégories films · ${Object.keys(D.sc||{}).length} séries · ${Object.keys(D.lc||{}).length} TV${D.fill?` · ${D.fill} complétées`:""}`:"non chargée"}</small>`,D?`${D.live.length} TV · ${D.vod.length} films · ${D.ser.length} séries`:"—")}).join("")}
  ${it("dg-q",`Analyse de la qualité vidéo<small>${ok} réussie${ok>1?"s":""} · ${q.length-ok} échec${q.length-ok>1?"s":""} · ${PQ.length} en attente${PQRUN?" · analyse en cours":""}</small>`,NATIVE?"lecteur natif":"navigateur")}
  ${it("dg-ph",`Photos des acteurs<small>${nph} trouvée${nph>1?"s":""} sur ${ph.length} recherchée${ph.length>1?"s":""} · ${S.set.tmdbKey?"TMDB puis Wikipédia":"Wikipédia (ajoute une clé TMDB pour plus de photos)"}</small>`,"")}
  <div class="it" data-f data-fid="dg-clrq" data-act="diag:clrq"><span>Refaire toutes les analyses de qualité</span><span>›</span></div>
  <div class="it" data-f data-fid="dg-clrph" data-act="diag:clrph"><span>Rechercher à nouveau les photos des acteurs</span><span>›</span></div>
  <div class="it" data-f data-fid="dg-ref" data-act="diag:ref" data-default><span>Actualiser cette page</span><span>›</span></div>
 </div></section>
 <section><h3>Journal (${LOGS.length})</h3><div class="grp">${LOGS.map(([t,m],i)=>`<div class="it tall lg" data-f data-fid="lg-${i}"><span>${esc(m)}</span><span>${new Date(t).toLocaleTimeString("fr-FR")}</span></div>`).join("")||'<div class="it"><span>Rien pour l\\'instant</span><span></span></div>'}</div></section><div style="height:30px"></div></div>`}
function plmHtml(id){''')
