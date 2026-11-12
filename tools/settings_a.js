/* ========================= RÉGLAGES · version A (catégories + recherche + explication) =========================
   Les réglages existants du simulateur sont regroupés par catégorie (mêmes actions, mêmes valeurs) ;
   s'y ajoutent les profils, les fournisseurs et les nouveaux réglages de la maquette A. */
(function(){
const SV='viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="sic" aria-hidden="true"';
const IC={user:`<svg ${SV}><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>`,card:`<svg ${SV}><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18M7 15h4"/></svg>`,
 lang:`<svg ${SV}><path d="M4 5h9M8.5 3v2M6 5c0 5 3 8 7 9M11 5c0 4-3 8-7 9"/><path d="M13 21l4-10 4 10M14.5 17h5"/></svg>`,play:`<svg ${SV}><path d="M7 4.5v15l13-7.5z"/></svg>`,
 tv:`<svg ${SV}><rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/></svg>`,guide:`<svg ${SV}><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18M9 9v11"/></svg>`,
 home:`<svg ${SV}><path d="M3 11 12 4l9 7v9H3z"/><path d="M9 20v-6h6v6"/></svg>`,lock:`<svg ${SV}><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>`,
 cloud:`<svg ${SV}><path d="M7 18a5 5 0 1 1 1-9.9A6 6 0 0 1 19 10a4 4 0 0 1-1 8z"/></svg>`,search:`<svg ${SV}><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>`,
 ck:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" class="sic" aria-hidden="true"><path d="M5 12.5 10 17.5 19 7"/></svg>`};
let scat="prof";try{scat=sessionStorage.getItem("prisme-scat")||"prof";sessionStorage.removeItem("prisme-scat")}catch(_){}
const SA=window.SA={cat:scat,q:"",open:null,prof:null,conf:null};
const X=()=>{S.set.x=S.set.x||{};return S.set.x};
/* ---------- nouveaux réglages (maquette A) : valeurs gardées dans S.set.x ---------- */
const NEW={
 autost:{t:"Sous-titres français si seule la VO existe",type:"toggle",d:1,desc:"Plus besoin d'aller les chercher : ils s'activent tout seuls sur les versions originales."},
 stsize:{t:"Taille des sous-titres",type:"choice",opts:["Petite","Moyenne","Grande","Très grande"],d:1,desc:"L'aperçu au-dessus montre le résultat tout de suite."},
 stbg:{t:"Fond des sous-titres",type:"choice",opts:["Aucun","Ombre","Bandeau"],d:1,desc:"Le bandeau reste lisible même sur les scènes claires."},
 stcol:{t:"Couleur des sous-titres",type:"choice",opts:["Blanc","Jaune"],d:0,desc:"Le jaune se lit mieux sur les vieux films."},
 qual:{t:"Qualité préférée",type:"choice",opts:["La meilleure (4K HDR)","1080p maximum","Économie de données (720p)"],d:0,rec:0,desc:"Utile si ta connexion sature le soir : prisme prend la meilleure source sous cette limite (sauf si tu en as choisi une)."},
 hdr:{t:"Adapter la plage dynamique (HDR)",type:"toggle",d:1,desc:"L'Apple TV passe en HDR seulement quand le film l'est vraiment."},
 night:{t:"Son de nuit",type:"choice",opts:["Auto après l'heure du coucher","Toujours","Jamais"],d:0,desc:"Adoucit les scènes fortes et met les voix en avant. Le lecteur peut le changer pour un film ou une chaîne."},
 stopbed:{t:"Arrêt automatique au coucher",type:"toggle",d:0,desc:"Met en pause à la fin de la scène en cours quand ton heure de coucher arrive."},
 skip:{t:"Saut avant / arrière",type:"choice",opts:["10 s","15 s","30 s"],d:0,desc:"Pour les touches ⏪ ⏩ de la télécommande."},
 lockset:{t:"Verrouiller les réglages",type:"toggle",d:0,desc:"Le code parental est demandé pour entrer dans les Réglages."},
 pswitch:{t:"Changer de profil depuis la télécommande",type:"toggle",d:1,desc:"Appui long sur le bouton TV : la liste des profils s'ouvre, où que tu sois."},
 icloud:{t:"Sauvegarder mes réglages sur iCloud",type:"toggle",d:1,desc:"Profils, listes, progression : tout revient si tu réinstalles prisme."}};
const val=k=>{const x=X();return x[k]==null?NEW[k].d:x[k]};
const isMod=k=>NEW[k]&&val(k)!==NEW[k].d;
function newH(k){const it=NEW[k],v=val(k),open=SA.open===k;
 const right=it.type==="toggle"?sw(!!v):`<span class="sa-v">${esc(it.opts[v])}${it.rec!=null&&v===it.rec?'<em class="sa-rec">conseillé</em>':""}<b>${open?"⌄":"›"}</b></span>`;
 let h=`<div class="it" data-f data-fid="sa-${k}" data-act="sa:${it.type==="toggle"?"tg":"open"}:${k}" data-desc="${esc(it.desc||"")}">${isMod(k)?'<i class="sa-mod" title="modifié"></i>':""}<span>${esc(it.t)}</span>${right}</div>`;
 if(open)h+=`<div class="sa-opts">${it.opts.map((o,i)=>`<div class="sa-op ${v===i?"on":""}" data-f data-fid="sa-o-${k}-${i}" data-act="sa:set:${k}:${i}" data-desc="${esc(it.desc||"")}"><span>${esc(o)}${it.rec===i?' <em class="sa-rec">conseillé</em>':""}</span>${v===i?IC.ck:""}</div>`).join("")}</div>`;
 return h}
const fixedH=(t,v,d)=>`<div class="it sa-fixed"><span>${esc(t)}${d?`<small>${esc(d)}</small>`:""}</span><span>${esc(v)} 🔒</span></div>`;
/* ---------- catégories ---------- */
const CATS=[{id:"prof",n:"Profils",ic:"user"},{id:"acc",n:"Fournisseurs",ic:"card",sec:["Catalogue fusionné"]},{id:"lang",n:"Langues et sous-titres",ic:"lang"},
 {id:"play",n:"Lecture et image",ic:"play",sec:["Lecteur"]},{id:"live",n:"TV en direct",ic:"tv",sec:["TV en direct"]},{id:"epg",n:"Guide TV",ic:"guide",sec:["Guide TV"]},
 {id:"homes",n:"Accueils et notes",ic:"home",sec:["Accueil Films","Accueil Séries","Notes et métadonnées"]},{id:"par",n:"Contrôle parental",ic:"lock",sec:["Général"]},
 {id:"data",n:"Sauvegarde et mises à jour",ic:"cloud",sec:["À propos","Appareil"]}];
const MOVE={"lmaxc":"acc","set:subs":"lang"};
let _base=null;
/* les sections du simulateur, rangées par catégorie */
function oldItems(){const t=document.createElement("template");t.innerHTML=_base();const out={};CATS.forEach(c=>out[c.id]=[]);
 t.content.querySelectorAll("section").forEach(sec=>{const h=(sec.querySelector("h3")||{}).textContent||"";if(/^Mes playlists/.test(h))return;
  const c=(CATS.find(c=>(c.sec||[]).some(s=>h.startsWith(s)))||CATS[CATS.length-1]).id;const lab=h.replace(/\s*\(.*$/,"");
  sec.querySelectorAll(".it").forEach(e=>{const a=e.dataset.act||"";const cc=MOVE[a]||c;if(a==="set:subs"){const s=e.querySelector("span");if(s)s.firstChild.textContent="Sous-titres français par défaut"}
   const sm=e.querySelector("span small");if(sm&&e.hasAttribute("data-f"))e.setAttribute("data-desc",sm.textContent);
   out[cc].push({h:e.outerHTML,grp:c==="homes"||c==="data"?lab:"",txt:e.textContent})})});
 return out}
function provRows(){const L=S.playlists;return L.map(p=>{const c=counts(p),ex=p.exp?Math.ceil((p.exp-Date.now())/86400000):null;
  const col=p.col||PVCOL[(+String(p.id).replace(/\D/g,"")||1)%PVCOL.length];
  const exT=ex==null?"":ex<0?"expiré":`expire dans ${ex} j`;
  return `<div class="it tall" data-f data-fid="pl-${p.id}" data-act="plm:${p.id}" data-desc="${esc(`${p.url||""}${p.user?" · "+p.user:""}${p.exp?" · expire le "+new Date(p.exp).toLocaleDateString("fr-FR",{day:"numeric",month:"long",year:"numeric"}):""}${p.maxc?" · "+p.maxc+" connexion"+(p.maxc>1?"s":"")+" simultanée"+(p.maxc>1?"s":""):""} · OK pour gérer ses catégories`)}"><span style="display:flex;align-items:center;gap:12px;min-width:0"><i class="sa-dot" style="background:${col}"></i><span>${esc(p.name)}<small>${c.c} chaînes · ${c.f} films · ${c.s} séries${p.on?"":" · désactivé"}</small></span></span><span class="${ex!=null&&ex<=7?"sa-warn":""}">${exT}${p.maxc?` · ${p.maxc} connexion${p.maxc>1?"s":""}`:""} ›</span></div>`}).join("")
 +`<div class="it" data-f data-fid="set-add" data-act="addpl" data-desc="Avec ton iPhone (QR code), en collant le lien du fournisseur ou en saisissant les identifiants. prisme vérifie l'abonnement et ne garde que les catégories françaises."><span>＋ Ajouter un fournisseur</span><span>iPhone, lien ou identifiants ›</span></div>`}
/* ---------- profils (données réelles des profils du simulateur) ---------- */
const PX=p=>{p.x=p.x||{};return p.x};
const BEDS=[22*60,22*60+30,23*60,23*60+30,24*60,24*60+30,25*60],LANGS=["auto","VF","VFF","VFQ","VOSTFR"],LANGN={auto:"✨ Automatique (prisme apprend)",VF:"Français, tout doublage",VFF:"VFF d'abord",VFQ:"VFQ d'abord",VOSTFR:"VOSTFR d'abord"};
const STO=["Comme le réglage général","Toujours en français","Jamais"];
function avH(id,cls){return `<span class="fx" style="display:contents">${fxC(pav(id,cls||"lg"))}</span>`}
function profList(){const ids=Object.keys(PR.list);
 return `<div class="sa-pfrow">${ids.map(id=>{const p=PR.list[id],x=PX(p);return `<div class="sa-pf" data-f data-fid="sap-${id}" data-act="sa:prof:${id}" data-desc="OK pour régler le profil de ${esc(p.n)} : âge, heure du coucher, langue, code, couleur…" ${id===PR.cur?"data-default":""}>${avH(id,"xl")}<b>${esc(p.n)}</b><small>${id===PR.cur?"actif":x.kids?"enfant":p.max!=null?"🔒 "+ageLbl(p.max):"&nbsp;"}</small></div>`}).join("")}
 ${ids.length<6?`<div class="sa-pf" data-f data-fid="sap-add" data-act="sa:padd" data-desc="Jusqu'à 6 profils, chacun avec sa liste, sa progression et ses réglages."><span class="fx" style="display:contents">${fxC('<i class="pav xl add">+</i>')}</span><b>Ajouter</b><small>&nbsp;</small></div>`:""}</div>
 <div class="sa-grp">Pour tous les profils</div>
 <div class="it" data-f data-fid="sa-ask" data-act="sa:ask" data-desc="« Qui regarde ? » s'affiche à l'ouverture de prisme, comme sur Netflix (s'il y a plusieurs profils)."><span>À l'ouverture de prisme</span><span>${PR.ask?"Demander qui regarde":"Ouvrir le dernier profil utilisé"} ›</span></div>
 ${newH("pswitch")}`}
function profDet(id){const p=PR.list[id],x=PX(p),cur=id===PR.cur,conf=SA.conf;
 const row=(fid,a,t,v,d)=>`<div class="it" data-f data-fid="${fid}" data-act="${a}" data-desc="${esc(d)}"><span>${t}</span><span>${v}</span></div>`;
 const opts=(k,L,curI,lab)=>SA.open===k?`<div class="sa-opts">${L.map((o,i)=>`<div class="sa-op ${curI===i?"on":""}" data-f data-fid="sa-o-${k}-${i}" data-act="sa:pset:${k}:${i}"><span>${lab?lab(o,i):esc(o)}</span>${curI===i?IC.ck:""}</div>`).join("")}</div>`:"";
 const ci=PCOL.indexOf(p.c),ei=Math.max(0,PEMO.indexOf(p.emo)),ai=Math.max(0,AGES.indexOf(p.max)),bi=Math.max(0,BEDS.indexOf(p.bed)),li=Math.max(0,LANGS.indexOf(p.lang||"auto"));
 return row("pe-name","sa:pname:"+id,"Nom",esc(p.n)+" ✎","OK pour changer le nom avec le clavier à l'écran (ou celui de l'ordinateur).")
 +row("sa-pcol","sa:popen:pcol","Couleur",`<i class="sa-dot" style="background:${p.c}"></i> ${SA.open==="pcol"?"⌄":"›"}`,"Aide à reconnaître le profil d'un coup d'œil sur l'écran « Qui regarde ? ».")+opts("pcol",PCOL,ci,(c,i)=>`<i class="sa-dot" style="background:${c}"></i> Couleur ${i+1}`)
 +row("sa-pemo","sa:popen:pemo","Image",`${p.emo||"Initiale"} ${SA.open==="pemo"?"⌄":"›"}`,"L'initiale du prénom ou un petit dessin.")+opts("pemo",PEMO,ei,e=>e||"Initiale")
 +`<div class="it" data-f data-fid="sa-pkids" data-act="sa:ptg:kids" data-desc="Interface simplifiée et limite « Tous publics » : seuls les programmes jeunesse restent."><span>Profil enfant</span>${sw(!!x.kids)}</div>`
 +row("sa-page","sa:popen:page","Limite d'âge",`${ageLbl(p.max)} ${SA.open==="page"?"⌄":"›"}`,"Les films, séries et programmes au-dessus de la limite sont cachés pour ce profil.")+opts("page",AGES,ai,a=>ageLbl(a))
 +row("sa-pbed","sa:popen:pbed","Heure du coucher",`${fmt(p.bed)} ${SA.open==="pbed"?"⌄":"›"}`,"Sert au son de nuit automatique, à l'arrêt au coucher et aux conseils « Ce soir ».")+opts("pbed",BEDS,bi,b=>fmt(b))
 +row("sa-plang","sa:popen:plang","Version préférée",`${esc(LANGN[p.lang||"auto"])} ${SA.open==="plang"?"⌄":"›"}`,"Chaque profil a sa langue : VF pour l'un, VOSTFR pour l'autre. Automatique : prisme retient tes choix.")+opts("plang",LANGS,li,l=>esc(LANGN[l]))
 +row("sa-pst","sa:popen:pst","Sous-titres",`${STO[x.st||0]} ${SA.open==="pst"?"⌄":"›"}`,"Remplace le réglage général pour ce profil seulement.")+opts("pst",STO,x.st||0)
 +(()=>{const t=p.taste;const pos=t?Object.entries(t.g||{}).filter(([,v])=>v>0).sort((a,b)=>b[1]-a[1]).slice(0,3).map(x=>x[0].toLowerCase()):[];
   return row("sa-pgout",t?"gt:res:"+id:"gt:open:"+id,"Mes goûts",t?`${esc(pos.join(", ")||"variés")}${t.never&&t.never.length?" · jamais : "+esc(t.never.map(g=>g==="__long"?"films longs":g.toLowerCase()).slice(0,2).join(", ")):""} ›`:"pas encore appris · faire le test ›","Ce que prisme a retenu de ton test et de ce que tu regardes : il s'en sert pour « Pour toi » et les scores de chaque titre.")
   +row("sa-pgtest","gt:open:"+id,t?"Refaire le test des goûts":"Apprendre mes goûts",`1 minute · ${t?"fait le "+new Date(t.at).toLocaleDateString("fr-FR"):"10 titres"} ›`,"6 titres, 4 duels « celui-ci ou celui-là ? » et « Jamais de… ».")
   +(t?row("sa-pgclr","gt:clr:"+id,"Tout oublier de mes goûts","efface ce que le test a appris ›","Les « j'aime » du test, les genres refusés et « Jamais de… » sont effacés. L'historique de lecture reste."):"")})()
 +row("sa-puse","sa:puse:"+id,"Utiliser ce profil maintenant",cur?"profil actif":"Utiliser ›","Change de profil sans repasser par l'écran « Qui regarde ? ».")
 +row("sa-phist","sa:phist:"+id,"Effacer l'historique de ce profil",conf==="hist"?'<b class="sa-danger">OK encore pour confirmer</b>':`${p.seen.length} vus · ${(p.hist||[]).length} dans l'historique ›`,"Garde la liste et les réglages, remet à zéro ce qui a été regardé et ce que prisme a appris.")
 +(Object.keys(PR.list).length>1?row("sa-pdel","sa:pdel:"+id,`<span class="sa-red">Supprimer ce profil</span>`,conf==="del"?'<b class="sa-danger">OK encore pour confirmer</b>':"›","Supprime le profil, sa liste et sa progression."):"")}
/* ---------- détail d'une catégorie ---------- */
function subPrev(){const sz=[18,22,27,32][val("stsize")],bg=["","text-shadow:0 2px 6px #000,0 0 3px #000","background:rgba(0,0,0,.72)"][val("stbg")],col=["#fff","#ffe14a"][val("stcol")];
 return `<div class="sa-prev"><span class="sa-k">Aperçu</span><span class="s" style="font-size:${sz}px;color:${col};${bg}">Je t'avais dit de ne pas revenir ici.</span></div>`}
function catItems(id,O){const L=O[id].map(o=>o.h),grp=[];let last="";O[id].forEach(o=>{grp.push(o.grp&&o.grp!==last?`<div class="sa-grp">${esc(o.grp)}</div>`:"");last=o.grp});const old=L.map((h,i)=>grp[i]+h).join("");
 switch(id){
 case "acc":return provRows()+`<div class="sa-grp">Catalogue</div>`+old+`<div class="it" data-f data-fid="sa-test" data-act="sa:test" data-desc="Mesure le temps de réponse de chaque fournisseur, sans ouvrir aucun flux."><span>Tester mes serveurs</span><span>${S.playlists.some(p=>p.ms)?S.playlists.filter(p=>p.ms).map(p=>esc(p.name)+" "+p.ms+" ms").join(" · "):"temps de réponse"} ›</span></div>`;
 case "lang":return `<div class="it" data-f data-fid="sa-plang0" data-act="sa:openprof:plang" data-desc="La version (VFF, VF, VOSTFR…) se règle par profil : OK pour régler celle de ${esc(ME().n)}."><span>Version préférée (${esc(ME().n)})</span><span>${esc(LANGN[ME().lang||"auto"])} ›</span></div>`+old+["autost","stsize","stbg","stcol"].map(newH).join("");
 case "play":return newH("qual")+old+["hdr","night","stopbed","skip"].map(newH).join("");
 case "par":return fixedH("Contenus pour adultes","toujours masqués","Jamais chargés, quel que soit le profil")+old+newH("lockset")+`<div class="it" data-f data-fid="sa-kids" data-act="sa:gokids" data-desc="Profil enfant, limite d'âge et code se règlent dans chaque profil."><span>Limites par profil</span><span>${Object.values(PR.list).filter(p=>p.max!=null).length} profil(s) limité(s) ›</span></div>`;
 case "data":return newH("icloud")+`<div class="it" data-f data-fid="sa-cache" data-act="sa:cache" data-desc="Les affiches et logos se retéléchargent au besoin."><span>Vider le cache des images</span><span>${IMG&&IMG.count?IMG.count+" images":"—"} ›</span></div>`+old;
 default:return old}}
const catMod=id=>({lang:["autost","stsize","stbg","stcol"],play:["qual","hdr","night","stopbed","skip"],par:["lockset"],data:["icloud"],prof:["pswitch"]}[id]||[]).some(isMod);
function detHtml(O){const c=CATS.find(x=>x.id===SA.cat)||CATS[0];
 if(SA.q){const q=RI.strip(SA.q).trim(),re=new RegExp("(^|[^a-z0-9])"+q.replace(/[.*+?^${}()|[\]\\]/g,"\\$&")+(q.length<4?"(?![a-z])":""));
  const all=[];CATS.forEach(cc=>{(O[cc.id]||[]).forEach(o=>all.push([cc,o.h,o.txt]))});
  Object.keys(NEW).forEach(k=>{const cc=CATS.find(x=>x.id===({autost:"lang",stsize:"lang",stbg:"lang",stcol:"lang",qual:"play",hdr:"play",night:"play",stopbed:"play",skip:"play",lockset:"par",pswitch:"prof",icloud:"data"})[k]);all.push([cc,newH(k),NEW[k].t+" "+(NEW[k].desc||"")+" "+(NEW[k].opts||[]).join(" ")])});
  const R=all.map(([cc,h,t])=>({cc,h,s:re.test(RI.strip(t.slice(0,60)))?2:re.test(RI.strip(t+" "+cc.n))?1:0})).filter(x=>x.s).sort((a,b)=>b.s-a.s);
  return `<div class="sa-det sa-glass" id="sa-det" data-col="1"><h2>Résultats pour « ${esc(SA.q)} »</h2><div class="sa-list sy">${R.length?R.map(r=>`<div class="sa-grp">${esc(r.cc.n)}</div>`+r.h).join(""):'<div class="sa-empty">Aucun réglage ne correspond · essaie « son », « langue », « code »…</div>'}</div><div class="sa-desc" id="sa-desc"><span class="sa-mut">↑ ↓ pour parcourir les résultats</span></div></div>`}
 if(c.id==="prof"){const pid=SA.prof&&PR.list[SA.prof]?SA.prof:null;
  const head=pid?`<div class="sa-ph">${avH(pid,"md")}<div><div class="sa-k">Profils ›</div><h2>${esc(PR.list[pid].n)}${pid===PR.cur?' <small>· actif</small>':""}</h2></div></div>`:`<h2>Profils</h2>`;
  return `<div class="sa-det sa-glass" id="sa-det" data-col="1">${head}<div class="sa-list sy">${pid?profDet(pid):profList()}</div><div class="sa-desc" id="sa-desc"><span class="sa-mut">${pid?"Retour pour revenir à la liste des profils.":"Choisis un profil pour le régler."}</span></div></div>`}
 return `<div class="sa-det sa-glass" id="sa-det" data-col="1"><div class="sa-hd"><h2>${esc(c.n)}</h2>${catMod(c.id)?`<span class="sa-btn" data-f data-fid="sa-reset" data-act="sa:reset:${c.id}" data-desc="Remet les nouveaux réglages de cette catégorie comme conseillé.">Rétablir les réglages conseillés</span>`:""}</div>
  ${c.id==="lang"?subPrev():""}<div class="sa-list sy">${catItems(c.id,O)}</div><div class="sa-desc" id="sa-desc"><span class="sa-mut">Choisis un réglage pour voir à quoi il sert.</span></div></div>`}
function lockHtml(){const n=(SA.pin||"").length;
 return `<div class="sa"><div class="sa-lock sa-glass"><div class="sa-k">Contrôle parental</div><h2>Réglages verrouillés</h2><div class="sa-mut" style="font-size:15px">Tape le code parental (0000 dans le simulateur)</div>
 <div class="sa-pin">${[0,1,2,3].map(i=>`<i class="${i<n?"on":""}"></i>`).join("")}</div>
 <div class="sa-pad">${["1","2","3","4","5","6","7","8","9","","0","⌫"].map(d=>d?`<span class="sa-key" data-f data-fid="sa-pin-${d==="⌫"?"del":d}" data-act="sa:pin:${d==="⌫"?"del":d}" ${d==="5"?"data-default":""}>${d}</span>`:"<span></span>").join("")}</div></div></div>`}
function saHtml(){if(val("lockset")&&!SA.unl)return lockHtml();const O=oldItems();
 return `<div class="sa"><div class="sa-side" data-col="0"><input class="inp sa-q" id="sa-q" data-f data-fid="sa-q" value="${esc(SA.q)}" placeholder="Rechercher un réglage" spellcheck="false" autocomplete="off" aria-label="Rechercher un réglage">
  <div class="sa-cats sy">${CATS.map(x=>`<div class="sa-cat ${x.id===SA.cat&&!SA.q?"sel":""}" data-f data-fid="sacat-${x.id}" data-hov="sacat:${x.id}" data-act="sa:enter" data-desc="">${IC[x.ic]}<span>${esc(x.n)}</span>${x.id==="acc"&&S.playlists.some(p=>p.exp&&p.exp-Date.now()<7*86400000)?'<i class="sa-alert" title="un abonnement expire bientôt"></i>':catMod(x.id)?'<i class="sa-mod"></i>':""}</div>`).join("")}</div></div>${detHtml(O)}</div>`}
/* ---------- branchement ---------- */
_base=settingsHtml;
settingsHtml=function(){return saHtml()};
{const _h=onHover;onHover=function(h){if(h&&h.startsWith("tab:")&&h!=="tab:settings"){SA.unl=false;SA.pin=""}if(h&&h.startsWith("sacat:")){const v=h.slice(6);if(SA.cat!==v||SA.q){SA.cat=v;SA.open=null;SA.prof=null;SA.conf=null;if(SA.q){SA.q=""}render("sacat-"+v)}return}return _h(h)}}
/* l'explication du réglage sélectionné, en bas du panneau */
{const _f=setFocus;setFocus=function(el,inst){_f(el,inst);const d=document.getElementById("sa-desc");if(!d||!el)return;if(el.closest&&el.closest("#sa-det")){const t=el.getAttribute("data-desc");d.innerHTML=t?esc(t):'<span class="sa-mut">Choisis un réglage pour voir à quoi il sert.</span>'}}}
{const _r=render;render=function(f){_r(f);const q=document.getElementById("sa-q");if(q&&!q._b){q._b=1;q.addEventListener("input",()=>{SA.q=q.value;SA.open=null;const d=document.getElementById("sa-det");if(d){const t=document.createElement("template");t.innerHTML=detHtml(oldItems());d.replaceWith(t.content.firstElementChild)}view.querySelectorAll(".sa-cat").forEach(c=>c.classList.toggle("sel",!SA.q&&c.dataset.fid==="sacat-"+SA.cat))})}applyVars()}}
function applyVars(){const r=document.documentElement.style;r.setProperty("--st-size",[18,22,27,32][val("stsize")]*1.1+"px");r.setProperty("--st-col",["#fff","#ffe14a"][val("stcol")]);r.setProperty("--st-bg",["transparent","transparent","rgba(0,0,0,.72)"][val("stbg")]);r.setProperty("--st-sh",val("stbg")===1?"0 2px 6px #000,0 0 3px #000":"none")}
function saAct(v,w,x){const fid=F&&F.dataset.fid;
 switch(v){
 case "pin":{if(w==="del")SA.pin=(SA.pin||"").slice(0,-1);else SA.pin=(SA.pin||"")+w;
  if(SA.pin.length>=4){const ok=SA.pin==="0000";SA.pin="";if(ok){SA.unl=true;toast("Réglages déverrouillés");return render("sacat-"+SA.cat)}toast("Code incorrect")}return render(fid)}
 case "enter":{const d=view.querySelector("#sa-det [data-f]");if(d)setFocus(d);return}
 case "tg":X()[w]=val(w)?0:1;if(w==="lockset")SA.unl=true;save();if(w==="lockset"&&X()[w])toast("Le code parental sera demandé la prochaine fois que tu ouvres les Réglages");return render(fid);
 case "open":SA.open=SA.open===w?null:w;return render(SA.open?`sa-o-${w}-${val(w)}`:"sa-"+w);
 case "set":X()[w]=+x;SA.open=null;save();return render("sa-"+w);
 case "reset":{const L={lang:["autost","stsize","stbg","stcol"],play:["qual","hdr","night","stopbed","skip"],par:["lockset"],data:["icloud"],prof:["pswitch"]}[w]||[];L.forEach(k=>delete X()[k]);save();toast("Réglages conseillés rétablis");return render("sacat-"+w)}
 case "test":{const L=S.playlists.filter(p=>p.on);toast(L.length?L.map(p=>`${p.name} : ${p.ms?p.ms+" ms (mesuré à l'ajout)":"mesuré par la commande du Mac"}`).join(" · "):"Aucun fournisseur actif");return}
 case "cache":toast("Cache des images vidé (démo) : les affiches reviennent au besoin");return;
 case "gokids":SA.cat="prof";SA.prof=null;return render("sacat-prof");
 case "openprof":SA.cat="prof";SA.prof=PR.cur;SA.open=w;return render(`sa-o-${w}-${Math.max(0,LANGS.indexOf(ME().lang||"auto"))}`);
 case "ask":PR.ask=!PR.ask;prSave();return render("sa-ask");
 case "prof":SA.prof=w;SA.open=null;SA.conf=null;return render("pe-name");
 case "padd":{const id="p"+Date.now().toString(36);window.GT_NEW=id;const n=Object.keys(PR.list).length;PR.list[id]={n:"Profil "+(n+1),c:PCOL[(n+3)%PCOL.length],emo:null,bed:23*60,lang:"auto",max:null,pref:{},hist:[],fb:{},seen:[],no:[],split:{},d:null};prSave();SA.prof=id;S.modal={type:"fxpname",v:"",id,prev:null};render("nk-A");return toast("Nouveau profil : tape son nom")}
 case "pname":S.modal={type:"fxpname",v:PR.list[w].n,id:w,prev:null};return render("nk-A");
 case "popen":SA.open=SA.open===w?null:w;{const p=PR.list[SA.prof],x2=PX(p),cur={pcol:PCOL.indexOf(p.c),pemo:Math.max(0,PEMO.indexOf(p.emo)),page:Math.max(0,AGES.indexOf(p.max)),pbed:Math.max(0,BEDS.indexOf(p.bed)),plang:Math.max(0,LANGS.indexOf(p.lang||"auto")),pst:x2.st||0}[w];return render(SA.open?`sa-o-${w}-${Math.max(0,cur)}`:"sa-"+w)}
 case "pset":{const p=PR.list[SA.prof];const i=+x;if(w==="pcol")p.c=PCOL[i];if(w==="pemo")p.emo=PEMO[i];if(w==="page"){p.max=AGES[i];FXS.cache={}}if(w==="pbed")p.bed=BEDS[i];if(w==="plang")p.lang=LANGS[i];if(w==="pst")PX(p).st=i;SA.open=null;prSave();return render("sa-"+w)}
 case "ptg":{const p=PR.list[SA.prof],x2=PX(p);x2[w]=x2[w]?0:1;if(w==="kids"){if(x2.kids){x2.maxBefore=p.max;p.max=0}else{p.max=x2.maxBefore??null}FXS.cache={}}prSave();return render("sa-p"+w)}
 case "puse":if(w!==PR.cur){prSwitch(w);FXS.duo=null;FXS.ready=null;toast(`Profil ${PR.list[w].n} activé`)}return render("sa-puse");
 case "phist":if(SA.conf!=="hist"){SA.conf="hist";return render("sa-phist")}{SA.conf=null;const p=PR.list[w];Object.assign(p,{hist:[],fb:{},seen:[],no:[],split:{},pref:{}});if(w===PR.cur){S.prog={};save()}else if(p.d)p.d.prog={};FXS.cache={};prSave();toast(`Historique de ${p.n} effacé`);return render("sa-phist")}
 case "pdel":if(SA.conf!=="del"){SA.conf="del";return render("sa-pdel")}{SA.conf=null;const p=PR.list[w],n=p.n;if(w===PR.cur){const o=Object.keys(PR.list).find(k=>k!==w);prSwitch(o)}delete PR.list[w];if(FXS.duo&&FXS.duo.includes(w))FXS.duo=null;prSave();SA.prof=null;toast(`Profil ${n} supprimé`);return render("sap-"+PR.cur)}
 }}
{const _a=act;act=function(a){if(a&&a.startsWith("sa:")){const [,v,w,x]=a.split(":");return saAct(v,w,x)}if(SA.conf&&!(a||"").startsWith("sa:"))SA.conf=null;return _a(a)}}
{const _b=back;back=function(){if(inApp()&&topS().t==="home"&&S.tab==="settings"&&!S.modal){
  if(SA.open){const k=SA.open;SA.open=null;return render(NEW[k]?"sa-"+k:"sa-"+k)}
  if(SA.conf){SA.conf=null;return render(F&&F.dataset.fid)}
  if(SA.q&&F&&F.closest&&F.closest("#sa-det")){return render("sa-q")}
  if(SA.prof&&SA.cat==="prof"){const id=SA.prof;SA.prof=null;return render("sap-"+id)}
  if(F&&F.closest&&F.closest("#sa-det"))return render("sacat-"+SA.cat)}
 return _b()}}
/* de la barre d'onglets, ▼ va toujours à la catégorie en cours (pas au milieu du panneau) */
{const _k=key;key=function(k){if(inApp()&&!S.modal&&!S.loading&&topS().t==="home"&&S.tab==="settings"&&F&&F.isConnected){
  if(k==="down"&&F.dataset.row==="tabs"){const c=view.querySelector(`[data-fid="sacat-${SA.cat}"]`);if(c){setFocus(c);return}}
  if(k==="right"&&F.closest(".sa-side")&&F.tagName!=="INPUT"){const d=view.querySelector("#sa-det .sa-list [data-f]")||view.querySelector("#sa-det [data-f]");if(d){setFocus(d);return}}
  if(k==="left"&&F.closest("#sa-det")){const before=F;_k(k);if(F===before||!F.closest("#sa-det")){const c=view.querySelector(`[data-fid="sacat-${SA.cat}"]`)||view.querySelector("#sa-q");if(c)setFocus(c)}return}}
 return _k(k)}}
/* son de nuit : la valeur des réglages sert de défaut au lecteur */
window.saNight=()=>val("night");
window.SAval=val;
/* qualité préférée : la meilleure source sous la limite choisie (sauf si tu as choisi une source toi-même) */
{const QR={"4K":4,"1080p":3,"720p":2,"SD":1};const _p=pickSrc;pickSrc=function(key){const cap=[9,3,2][val("qual")];if(cap===9)return _p(key);const L=srcs(key);if(S.srcSel[key]&&L.some(x=>x.id===S.srcSel[key]))return _p(key);const ok=L.filter(x=>compat(x)&&(QR[x.q]||3)<=cap);if(ok.length)return ok[0];const C=L.filter(compat).sort((a,b)=>(QR[a.q]||3)-(QR[b.q]||3));return C[0]||_p(key)}}
/* sous-titres français automatiques quand on écoute une version originale */
{const _cs=curSub;curSub=function(){if(P&&P.sub==null&&val("autost")){const a=curAudio(),t=tracks();if(a&&!/^fran/i.test(a.n)){const i=t.su.findIndex(x=>/^fran/i.test(x));if(i>=0)P.sub=i}}return _cs()}}
/* arrêt au coucher : pause d'un film ou d'un épisode quand l'heure du coucher du profil arrive */
{const _t=tick;tick=function(){_t();if(!P||P.kind!=="vod"||!P.playing||!val("stopbed")||S.modal)return;const b=((ME().bed==null?23*60:ME().bed)%1440),n=Math.floor(nowMin())%1440,day=new Date().toDateString()+b;
 if(n>=b&&n<b+3&&SA.bedDone!==day){SA.bedDone=day;act("p:pp");toast(`Il est ${fmt(b)}, l'heure du coucher de ${ME().n} : pause automatique · bonne nuit`)}}}
applyVars();
})();
