/* ===================== Accueil TV en direct : variantes ===================== */
const HV="F";
function hdeck(d,row,w,ex){const L=deckList(d),L2=ex?L.filter(x=>!ex.has(x.c.id)):L,lays=(L2.length?L2:L).slice(0,3).reverse();const soon=!["Reprendre","Favoris"].includes(d)&&lSoon(d,10)[0];
 return `<div class="ldk hdk" style="flex:0 0 ${w||220}px" data-f data-fid="dk-${d}" data-row="${row}" data-act="ldeck:${d}" data-hov="ldk:${d}">${lays.map((x,j)=>{const lv=lays.length-j;return `<div class="lay l${lv}">${lth(x.c,lv===1?`<div class="sh"></div><span class="ltag" style="--g:${LGC[d]}">${esc(d.toUpperCase())}</span><div class="tx"><b>${esc(x.e.cur.t)}</b><span>${esc(x.c.n)}</span></div><div class="lpb"><i style="width:${x.e.pct}%"></i></div>`:"")}</div>`}).join("")}
 <div class="lab"><b>${d==="Reprendre"?"↺ Reprendre":esc(d)}</b><span>${L.length}</span></div>${soon?`<span class="lsoon">${fmt(soon.p.s)} · ${esc(soon.p.t)}</span>`:""}</div>`}
function hrow(title,sub,cards){return cards?`<section data-anchor><div class="lh3">${esc(title)}<small>${sub}</small></div><div class="lrow sx">${cards}</div></section>`:""}
function hTonight(){const L=[];for(const c of lvis()){const p=epg(c).find(q=>q.s>=1230&&q.s<=1320&&q.e-q.s>=40);if(p)L.push({c,p})}return L.sort((a,b)=>a.p.s-b.p.s)}
function hForYou(){const order=[...LGEN].sort((a,b)=>(LS.gw[b]||0)-(LS.gw[a]||0));const out=[],seen=new Set();
 for(const id of LS.hist){const c=CH[id];if(c&&!seen.has(c.id)&&srcs("ch:"+c.id).length){seen.add(c.id);out.push({c,e:epgAt(c),why:"Tu l'as regardée récemment"})}if(out.length>=1)break}
 for(const g of order){const x=lNow(g).find(y=>!seen.has(y.c.id));if(x){seen.add(x.c.id);out.push({...x,why:"Parce que tu regardes du "+g.toLowerCase()})}if(out.length>=3)break}return out}
function hBig(x,row){const c=x.c,p=x.e.cur;return `<div class="lcard hbig" data-f data-fid="${row}-${c.id}" data-row="${row}" data-act="lp:${c.id}" data-hov="lp:${c.id}" data-lp="${c.id}">${lth(c,`<span class="lbd">DIRECT</span><div class="sh"></div><div class="tx"><b>${esc(p.t)}</b><span>${esc(c.n)} · reste ${dur(Math.max(1,Math.round(p.e-nowMin())))}</span></div><div class="lpb"><i style="width:${x.e.pct}%"></i></div>`,p)}<div class="s">${esc(x.why)}</div></div>`}
function hGuideRows(){const ids=[...new Set([...LS.hist,...lvis().filter(c=>isFav("ch:"+c.id)).map(c=>c.id),...lNow().map(x=>x.c.id)])].filter(id=>CH[id]&&srcs("ch:"+id).length).slice(0,8);
 return ids.map((id,i)=>{const c=CH[id],e=epgAt(c),nx=e.next.slice(0,2);return `<div class="hgr"><div class="hgc">${lth(c,"",e.cur).replace('class="lth"','class="lth hlogo"')}<b>${esc(c.n)}</b></div>
  <div class="hgp now" data-f data-fid="gr${i}-now" data-row="gr${i}" data-act="lp:${c.id}" data-hov="lp:${c.id}" data-lp="${c.id}"><span class="lbd">DIRECT</span><b>${esc(e.cur.t)}</b><small>${fmt(e.cur.s)} – ${fmt(e.cur.e)} · reste ${dur(Math.max(1,Math.round(e.cur.e-nowMin())))}</small><div class="lpb"><i style="width:${e.pct}%"></i></div></div>
  ${nx.map((p,j)=>`<div class="hgp" data-f data-fid="gr${i}-n${j}" data-row="gr${i}" data-act="lrem:${c.id}:${p.s}" data-hov="lp:${c.id}:${p.s}" data-lp="${c.id}"><span class="lbd soon">${fmt(p.s)}</span><b>${esc(p.t)}</b><small>${esc(pgen(p))} · ${dur(Math.round(p.e-p.s))}</small></div>`).join("")}</div>`}).join("")}
function homeMain(){
 const D=deckOrder(),N=lNow(),Sn=lSoon(null,60).slice(0,16),Pa=lPast().slice(0,16),T=hTonight();
 const first=(deckList(D[0]||"Sport")[0])||N[0];const hero=`<div class="lhero" id="lhero">${first?lheroHtml(first.c):""}</div>`;
 const soonC=Sn.map(x=>lcard(x.c,"hs",x.p)).join(""),pastC=Pa.map(x=>lrpCard(x.c,x.p,"hr")).join(""),tonC=T.map(x=>lcard(x.c,"ht",x.p)).join("");
 if(HV==="B")return `${hero}<div class="hscroll sy">
  <section data-anchor><div class="lh3">Tes paquets<small>OK pour ouvrir · maintenir pour les options</small></div><div class="lrow sx hdecks">${D.map(d=>hdeck(d,"hd")).join("")}</div></section>
  ${hrow("Commence bientôt","dans l'heure · OK pour un rappel",soonC)}${hrow("Replay récent","déjà diffusé · OK pour revoir",pastC)}${hrow("Ce soir","première partie de soirée",tonC)}<div style="height:30px"></div></div>`;
 if(HV==="C"){const rows=[...LGEN].sort((a,b)=>(LS.gw[b]||0)-(LS.gw[a]||0)).map(g=>{const L=lNow(g);return hrow(g,L.length+" en direct",L.map(x=>lcard(x.c,"hg-"+g)).join(""))}).join("");
  const rep=deckList("Reprendre");return `${hero}<div class="hscroll sy">${hrow("Reprendre","tes dernières chaînes, sur la même source",rep.map(x=>lcard(x.c,"hrep")).join(""))}${rows}${hrow("Replay récent","déjà diffusé",pastC)}${hrow("Commence bientôt","dans l'heure",soonC)}<div style="height:30px"></div></div>`}
 if(HV==="D"){const F=hForYou();return `<div class="lhero hsmall" id="lhero">${first?lheroHtml(first.c):""}</div><div class="hscroll sy">
  <section data-anchor><div class="lh3">Pour toi, maintenant<small>selon ce que tu regardes vers ${Math.floor(nowMin()/60)} h</small></div><div class="lrow sx">${F.map(x=>hBig(x,"hf")).join("")}</div></section>
  <section data-anchor><div class="lh3">Tous les genres<small>${D.length} paquets</small></div><div class="lrow sx hdecks">${D.map(d=>hdeck(d,"hd",180)).join("")}</div></section>
  ${hrow("Commence bientôt","dans l'heure",soonC)}<div style="height:30px"></div></div>`}
 if(HV==="F"){const F=hForYou();return `<div class="lhero hsmall" id="lhero">${first?lheroHtml(first.c):""}</div><div class="hscroll sy">
  <section data-anchor><div class="lh3">Pour toi, maintenant<small>selon ce que tu regardes vers ${Math.floor(nowMin()/60)} h</small></div><div class="lrow sx">${F.map(x=>hBig(x,"hf")).join("")}</div></section>
  <section data-anchor><div class="lh3">Tes paquets<small>OK pour ouvrir · maintenir pour les options</small></div><div class="lrow sx hdecks">${(ex=>D.map(d=>hdeck(d,"hd",190,ex)).join(""))(new Set(F.map(x=>x.c.id)))}</div></section>
  ${hrow("Commence bientôt","dans l'heure · OK pour un rappel",soonC)}${hrow("Replay récent","déjà diffusé · OK pour revoir",pastC)}${hrow("Ce soir","première partie de soirée",tonC)}<div style="height:30px"></div></div>`}
 if(HV==="G"){const F=hForYou();return `${hero}<div class="hscroll sy">
  <section data-anchor><div class="lh3">Tes paquets<small>OK pour ouvrir · maintenir pour les options</small></div><div class="lrow sx hdecks">${D.map(d=>hdeck(d,"hd")).join("")}</div></section>
  ${hrow("Commence bientôt","dans l'heure · OK pour un rappel",soonC)}
  <section data-anchor><div class="lh3">Pour toi, maintenant<small>selon tes habitudes</small></div><div class="lrow sx">${F.map(x=>hBig(x,"hf")).join("")}</div></section>
  ${hrow("Replay récent","déjà diffusé · OK pour revoir",pastC)}${hrow("Ce soir","première partie de soirée",tonC)}<div style="height:30px"></div></div>`}
 if(HV==="E")return `<div class="lhero hsmall" id="lhero">${first?lheroHtml(first.c):""}</div><div class="hscroll sy">
  <section data-anchor><div class="lrow sx hdecks">${D.map(d=>hdeck(d,"hd",168)).join("")}</div></section>
  <section data-anchor><div class="lh3">Tes chaînes<small>maintenant et ensuite · OK pour regarder ou programmer</small></div><div class="hgrid">${hGuideRows()}</div></section><div style="height:30px"></div></div>`;
 return null}
