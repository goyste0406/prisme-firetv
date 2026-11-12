/* ======== Où le regarder (films ET séries) + ouvrir dans une autre app (Netflix, Disney+…) ========
   Ordre d'ouverture, du meilleur au plus simple :
   1. lien direct vers le titre dans l'app (identifiant Netflix / Disney+ / Prime Video trouvé sur Wikidata à partir de l'id TMDB)
   2. l'app Apple TV ouverte sur le titre (identifiant Apple TV, Wikidata) : elle propose ensuite « Ouvrir dans Netflix »
   3. l'app du service ouverte sur son accueil (ou sa recherche) avec le titre à chercher affiché */
const XAPPS=[
 {k:"nf",re:/netflix/i,n:"Netflix",home:"nflx://",dl:(id)=>`nflx://www.netflix.com/title/${id}`},
 {k:"dp",re:/disney/i,n:"Disney+",home:"disneyplus://",dl:(id,s)=>`https://www.disneyplus.com/${s?"series":"movies"}/${id}`},
 {k:"pv",re:/amazon|prime video/i,n:"Prime Video",home:"aiv://",dl:(id)=>`https://app.primevideo.com/detail?gti=${id}`},
 {k:"atv",re:/^apple tv/i,n:"Apple TV",home:"videos://",dl:(id,s)=>`https://tv.apple.com/fr/${s?"show":"movie"}/${id}`},
 {k:"cp",re:/canal/i,n:"Canal+",home:"mycanal://"},
 {k:"mx",re:/^max\b|hbo/i,n:"Max",home:"hbomax://"},
 {k:"pp",re:/paramount/i,n:"Paramount+",home:"paramountplus://"},
 {k:"yt",re:/youtube/i,n:"YouTube",home:"youtube://",q:t=>`youtube://www.youtube.com/results?search_query=${encodeURIComponent(t)}`},
 {k:"ar",re:/arte/i,n:"ARTE",home:"arte://"},
 {k:"ft",re:/france\.?\s?tv/i,n:"france.tv",home:"francetv://"},
 {k:"m6",re:/m6|6play/i,n:"M6+",home:"m6plus://"},
 {k:"tf",re:/tf1/i,n:"TF1+",home:"tf1plus://"},
 {k:"rk",re:/rakuten/i,n:"Rakuten TV",home:"rakutentv://"},
 {k:"ph",re:/path[ée]/i,n:"Pathé Home",home:"pathehome://"},
];
const appOf=n=>XAPPS.find(a=>a.re.test(n||""));
/* services proposés quand on ne sait pas où le titre est disponible */
const AP_TOP=["Netflix","Amazon Prime Video","Disney Plus","Canal+","Apple TV+"];
const AP=(()=>{try{return JSON.parse(localStorage.getItem("prisme-apps")||"{}")}catch(e){return {}}})();AP.wd=AP.wd||{};
const apSave=()=>{try{const k=Object.keys(AP.wd);if(k.length>1500)k.slice(0,k.length-1500).forEach(x=>delete AP.wd[x]);localStorage.setItem("prisme-apps",JSON.stringify(AP))}catch(e){}};
const apPref=()=>AP.pref||"";
const isSer=it=>it&&it.type==="s";
const tmKey=it=>isSer(it)?(it.sxk&&/^t\d+$/.test(it.sxk)?"t"+it.sxk.slice(1):""):(it.tm?"m"+it.tm:"");

/* séries : disponibilités TMDB (abonnement, gratuit, location, achat) */
{const _s=streams;streams=function(it){if(!isSer(it))return _s(it);const d=it.sxk&&SXD.m[it.sxk],out=[];
 if(d&&(d.wp||d.wpf)){const W=d.wp||{f:d.wpf};for(const [k,ty] of [["f","abo"],["g","gratuit"],["r","loc"],["b","achat"]])for(const n of W[k]||[])if(!out.some(x=>x.n===n&&x.t===ty))out.push({n,t:ty})}
 else if(!REAL){const h=hash(it.id),nt=it.net&&SVC_DEMO.find(n=>appOf(n)&&appOf(n).re.test(it.net));out.push({n:nt||SVC_DEMO[h%6],t:"abo"});if(h%3===0)out.push({n:SVC_DEMO[7+h%3],t:"gratuit"});out.push({n:"Apple TV",t:"achat"})}
 return out.map((x,i)=>({...x,i}))}}

/* identifiants des services (Wikidata, gratuit, sans clé) à partir de l'id TMDB */
const WDQ=new Set();
function wdIds(it){const k=tmKey(it);if(!REAL){const h=hash(it.id);return {nf:h%2?String(80000000+h%999999):"",dp:h%3===0?"demo-"+h%9999:"",atv:h%4?"umc.cmc.demo"+(h%99999).toString(36):""}}return k?AP.wd[k]||null:{}}
async function wdLoad(it){const k=tmKey(it);if(!REAL||!k||AP.wd[k]||WDQ.has(k))return;WDQ.add(k);const s=k[0]==="t",id=k.slice(1);
 const q=`SELECT ?nf ?dp ?pv ?atv WHERE { ?i wdt:${s?"P4983":"P4947"} "${id}" . OPTIONAL{?i wdt:P1874 ?nf} OPTIONAL{?i wdt:${s?"P7596":"P7595"} ?dp} OPTIONAL{?i wdt:P8055 ?pv} OPTIONAL{?i wdt:${s?"P9751":"P9586"} ?atv} } LIMIT 1`;
 try{const ac=new AbortController(),tt=setTimeout(()=>ac.abort(),7000);const r=await fetch("https://query.wikidata.org/sparql?format=json&query="+encodeURIComponent(q),{signal:ac.signal,headers:{Accept:"application/sparql-results+json"}});clearTimeout(tt);
  const j=await r.json(),b=((j.results||{}).bindings||[])[0]||{},v=x=>b[x]?b[x].value:"";AP.wd[k]={nf:v("nf"),dp:v("dp"),pv:v("pv"),atv:v("atv")};apSave()}
 catch(e){AP.wd[k]={nf:"",dp:"",pv:"",atv:"",err:1}}finally{WDQ.delete(k);const m=S.modal;if(m&&(m.type==="fxapsvc")&&m.id===it.id)render(F&&F.dataset.fid)}}

/* comment le titre va s'ouvrir dans ce service */
function apPlan(it,name){const a=appOf(name),s=isSer(it),ids=wdIds(it),T=`« ${it.t} »`,quoi=s?"la série":"le film",an=a?a.n:name;
 if(ids===null)return {how:"wait",txt:`Recherche du lien direct vers ${quoi}…`,url:""};
 if(a&&a.dl&&ids[a.k])return {how:"direct",txt:`${an} s'ouvre directement sur ${quoi}`,url:a.dl(ids[a.k],s)};
 if(ids.atv&&(!a||a.k!=="atv"))return {how:"atv",txt:`L'app Apple TV s'ouvre sur ${quoi} et propose « Ouvrir dans ${an} »`,url:XAPPS[3].dl(ids.atv,s)};
 if(a&&a.q)return {how:"search",txt:`${an} s'ouvre sur sa recherche de ${T}`,url:a.q(it.t)};
 if(a)return {how:"home",txt:`${an} s'ouvre sur son accueil : cherche ${T}`,url:a.home};
 return {how:"none",txt:`prisme ne connaît pas encore l'app ${an} : ouvre-la et cherche ${T}`,url:""}}
const apHowIc={direct:"🎯",atv:"",search:"🔎",home:"🏠",none:"ℹ︎",wait:"…"};

/* section « Où le regarder » : sur toutes les fiches, films et séries */
whereHtml=function(it){const s=isSer(it),pr=apPref();let L=streams(it);const tv=s?[]:fxTV(it);
 const rank=x=>(appOf(x.n)&&appOf(x.n).k===pr?0:1);L=L.slice().sort((a,b)=>rank(a)-rank(b));
 const card=(x,ty)=>{const a=appOf(x.n),me=a&&a.k===pr;return `<div class="wc ${me?"me":""}" data-f data-fid="w-wh${s?"s":""}-${hash(x.n+ty)%99999}" data-act="ap:svc:${encodeURIComponent(x.n)}:${ty}">${svTile(x)}<div><b>${esc(x.n)}${me?" ★":""}</b><span>${esc(TYP[ty]||"Chercher dans l'app")}</span></div><em>${ty==="abo"?"Inclus":ty==="gratuit"?"Gratuit":"›"}</em></div>`};
 const g=t=>L.filter(x=>t.includes(x.t)),grp=(t,items)=>items?`<div class="grp"><div class="kk">${t}</div>${items}</div>`:"";
 const nV=s?(__sx.EPS(it)||[]).filter(Boolean).length:srcs(it.id).length;
 const inp=s?`▶ <b>Déjà dans prisme</b> · ${nV} saison${nV>1?"s":""} · sans frais en plus`:`▶ <b>Déjà dans prisme</b> · ${nV} version${nV>1?"s":""}${nV?` (${[...new Set(srcs(it.id).map(tagLbl))].join(", ")})`:""} · sans frais en plus`;
 const known=s?!!(it.sxk&&SXD.m[it.sxk]&&/^t/.test(it.sxk)):!!it.tmd;
 const none=!L.length&&!tv.length?grp("CHERCHER DANS UNE AUTRE APP",(pr&&!AP_TOP.some(n=>appOf(n)&&appOf(n).k===pr)?[XAPPS.find(a=>a.k===pr).n]:[]).concat(AP_TOP).map(n=>card({n},"cherche")).join("")):"";
 return `<section data-anchor id="where"><div class="lh">Où le regarder<small>ailleurs que dans prisme · OK sur une app pour l'ouvrir dessus</small></div><div class="inp">${inp}</div><div class="wh">
  ${grp("À LA TV",tv.map((x,i)=>`<div class="wc" data-f data-fid="w-wt${i}" data-act="fxtv:${i}"><span class="ico">📺</span><div><b>${esc(x.c.n)}</b><span>${esc(x.t)}</span></div><em>${x.live?"Direct":x.past?"Replay":"Rappel"}</em></div>`).join(""))}
  ${grp("INCLUS OU GRATUIT",g(["abo","gratuit"]).map(x=>card(x,x.t)).join(""))}${grp("LOCATION",g(["loc"]).map(x=>card(x,"loc")).join(""))}${grp("ACHAT",g(["achat"]).map(x=>card(x,"achat")).join(""))}${none}</div>
  <div class="src">${!L.length&&known?"Pas disponible ailleurs en France pour le moment (TMDB) · tu peux quand même chercher dans une app":!known&&REAL?"Fiche TMDB pas encore trouvée : disponibilités inconnues, cherche dans une app":known?"Disponibilités en France (données TMDB, source JustWatch)":"Disponibilités en France · données d'exemple"}</div></section>`};

/* bouton de l'app préférée dans la fiche, à côté de Lecture */
function apQuick(it){const pr=apPref();if(!pr)return "";const x=streams(it).find(x=>appOf(x.n)&&appOf(x.n).k===pr&&(x.t==="abo"||x.t==="gratuit"));if(!x)return "";return x}
{const _a=actsHtml;actsHtml=function(f){const h=_a(f),x=apQuick(f);if(!x)return h;const i=h.lastIndexOf("</div>");
 return h.slice(0,i)+`<div class="btn" data-f data-fid="w-app" data-act="ap:go:${encodeURIComponent(x.n)}:${f.id}" data-row="w2" data-col="0">${svTile(x)}<span>${esc(appOf(x.n).n)}</span></div>`+h.slice(i)}}
window.apSerBtn=it=>{const x=apQuick(it);return x?`<div class="btn" data-f data-fid="sf-app" data-act="ap:go:${encodeURIComponent(x.n)}:${it.id}" data-row="sfb">${svTile(x)}<span>${esc(appOf(x.n).n)}</span></div>`:""};

/* fenêtres : choix du service, puis ouverture */
const apCur=()=>{const m=S.modal,t=topS();return ALL[(m&&m.id)||(t.t==="detail"&&t.id)]};
{const _f=fxModal;fxModal=function(){const m=S.modal;
 const opt=(fid,a,b,s,dflt)=>`<div class="opt" data-f data-fid="${fid}" data-act="${a}" ${dflt?"data-default":""}><span class="ck"></span><div class="tx"><b>${b}</b>${s?`<span>${s}</span>`:""}</div></div>`;
 if(m.type==="fxapsvc"){const it=ALL[m.id],x={n:m.n},a=appOf(m.n),pl=apPlan(it,m.n),s=isSer(it),here=s?true:srcs(it.id).length>0,v=!s&&pickSrc(it.id),me=a&&apPref()===a.k;
  return `<div class="modal"><div class="mbox glass"><div style="display:flex;gap:16px;align-items:center">${svTile(x,"lg")}<div><div class="k">${esc((TYP[m.ty]||"CHERCHER DANS L'APP").toUpperCase())}</div><h2>${esc(m.n)}</h2></div></div>
  ${here?opt("m-here","ap:here",`Regarder dans prisme`,s?"Déjà chez ton fournisseur IPTV · sans frais en plus":`Déjà dans ton abonnement IPTV · ${fxTag(v)} · ${v.q} · sans frais en plus`,!me):""}
  ${opt("m-open","ap:go:"+encodeURIComponent(m.n)+":"+it.id,`Ouvrir dans ${esc(a?a.n:m.n)}`,`${apHowIc[pl.how]?apHowIc[pl.how]+" ":""}${esc(pl.txt)}${m.ty==="abo"?" · si tu es abonné":m.ty==="loc"||m.ty==="achat"?" · paiement dans l'app":""}`,me||!here)}
  ${a?opt("m-pref","ap:pref:"+a.k,me?`★ ${esc(a.n)} est ton app préférée`:`☆ Faire de ${esc(a.n)} mon app préférée`,me?"OK pour retirer · son bouton disparaît des fiches":"Son bouton apparaît à côté de Lecture quand le titre y est inclus",false):""}
  <div class="mfoot">${pl.url?`Lien ouvert sur l'Apple TV : <code style="opacity:.8">${esc(pl.url)}</code>`:"Sur l'Apple TV, prisme ouvre l'app si elle est installée"}</div></div></div>`}
 if(m.type==="fxaplaunch"){const it=ALL[m.id],a=appOf(m.n),pl=apPlan(it,m.n);
  return `<div class="modal"><div class="mbox glass" style="text-align:center;width:640px"><div style="display:flex;justify-content:center;margin:6px 0 14px">${svTile({n:m.n},"lg")}</div><div class="k">OUVERTURE</div><h2>${esc(pl.how==="atv"?"App Apple TV":(a?a.n:m.n))}</h2>
  <p class="mp">${esc(pl.txt)}${pl.how==="home"||pl.how==="none"?"":` · « ${esc(it.t)} »`}</p>${pl.url?`<p class="mp" style="font-size:12.5px;opacity:.6">${esc(pl.url)}</p>`:""}
  <p class="mp" style="font-size:12.5px;opacity:.6">Simulateur : sur l'Apple TV, l'app s'ouvrirait maintenant. Retour sur la télécommande ramène dans prisme.</p>
  <div style="display:flex;gap:12px;justify-content:center;margin-top:8px"><div class="btn prim" data-f data-fid="m-ok" data-act="fxclose" data-default>OK</div></div></div></div>`}
 return _f()}}
{const _a=act;act=function(a){if(typeof a==="string"&&a.startsWith("ap:")){const [,k,v,w]=a.split(":"),t=topS();
 if(k==="svc"){const it=apCur();if(!it)return;wdLoad(it);S.modal={type:"fxapsvc",id:it.id,n:decodeURIComponent(v),ty:w,ret:F&&F.dataset.fid};return render()}
 if(k==="go"){const it=ALL[w]||apCur();if(!it)return;wdLoad(it);const n=decodeURIComponent(v),ret=(S.modal&&S.modal.ret)||(F&&F.dataset.fid);(AP.used=AP.used||{})[appOf(n)?appOf(n).k:n]=Date.now();apSave();S.modal={type:"fxaplaunch",id:it.id,n,ret};return render("m-ok")}
 if(k==="pref"){AP.pref=AP.pref===v?"":v;apSave();toast(AP.pref?`★ ${XAPPS.find(x=>x.k===v).n} : ton app préférée`:"App préférée retirée");return render("m-pref")}
 if(k==="here"){const it=apCur();S.modal=null;if(!it)return render();if(isSer(it)){render();return act(__sx.fMain(it).act)}return fxStart(it.id)}
 return}return _a(a)}}
