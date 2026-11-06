# Version 2.1.3 : réglages rapides (sous-pages, comptes en un seul passage) et masquage des catégories sans latence.
# Exécuté par build_ui.py après v20_patch.py.

# catégories masquées : recherche instantanée (ensemble) au lieu d'un parcours de liste
R('function has(pl,key){return base(pl,key)&&!(pl.hidden||[]).includes(provKey(pl,key))}',
  '''const HS={};function hidSet(pl){const a=pl.hidden||[];let h=HS[pl.id];if(!h||h.a!==a||h.n!==a.length)h=HS[pl.id]={a,n:a.length,s:new Set(a)};return h.s}
function has(pl,key){return base(pl,key)&&!hidSet(pl).has(provKey(pl,key))}
function anySrc(key){for(const p of S.playlists)if(p.on&&has(p,key))return true;return false}''')
R('if(!p||!s.added||(p.hidden||[]).includes(it.type+":"+s.cat))return;', 'if(!p||!s.added||hidSet(p).has(it.type+":"+s.cat))return;')
# catalogue visible : test simple au lieu de calculer toutes les sources de chaque titre
R('const films=()=>memo("f",()=>FILMS.filter(i=>srcs(i.id).length)),series=()=>memo("s",()=>SERIES.filter(i=>srcs(i.id).length)),chans=()=>memo("c",()=>CHS.filter(c=>srcs("ch:"+c.id).length));',
  'const films=()=>memo("f",()=>FILMS.filter(i=>anySrc(i.id))),series=()=>memo("s",()=>SERIES.filter(i=>anySrc(i.id))),chans=()=>memo("c",()=>CHS.filter(c=>anySrc("ch:"+c.id)));')
R('const acred=a=>(CRED[a]||[]).filter(([id])=>srcs(id).length);', 'const acred=a=>(CRED[a]||[]).filter(([id])=>anySrc(id));')
# comptes par playlist et par catégorie : un seul passage, gardé en mémoire
R('function counts(pl){return {c:CHS.filter(c=>has(pl,"ch:"+c.id)).length,f:FILMS.filter(i=>has(pl,i.id)).length,s:SERIES.filter(i=>has(pl,i.id)).length}}',
  '''function plStats(pl){return memo("pls"+pl.id,()=>{const r={l:{},f:{},s:{},c:0,ff:0,ss:0};
 const run=(L,t,pre,tot)=>{for(const i of L){let s=null;for(const x of i.src)if(x.pl===pl.id){s=x;break}if(!s)continue;r[t][s.cat]=(r[t][s.cat]||0)+1;if(has(pl,pre+i.id))r[tot]++}};
 run(CHS,"l","ch:","c");run(FILMS,"f","","ff");run(SERIES,"s","","ss");return r})}
function counts(pl){const r=plStats(pl);return {c:r.c,f:r.ff,s:r.ss}}''')
R('function catCount(pl,type,k){const L=type==="l"?CHS:type==="f"?FILMS:SERIES;return L.filter(i=>i.src.some(s=>s.pl===pl.id&&s.cat===k)).length}',
  'function catCount(pl,type,k){return plStats(pl)[type][k]||0}')
R(' const dup=[...FILMS,...SERIES].filter(i=>srcs(i.id).length>1).length+CHS.filter(c=>srcs("ch:"+c.id).length>1).length;',
  ' const dup=memo("dup",()=>FILMS.filter(i=>i.src.length>1).length+SERIES.filter(i=>i.src.length>1).length+CHS.filter(c=>c.src.length>1).length);')
# masquer / afficher une catégorie : mise à jour de la seule ligne, catalogue recalculé en quittant la page
R('''  case "hide":{dirty();const pl=S.playlists.find(p=>p.id===v);if(!pl)break;pl.hidden=pl.hidden||[];const hk=w+":"+x,lbl=[...LCATS,...FCATS,...SCATS].find(c=>c[0]===x);
   if(pl.hidden.includes(hk))pl.hidden=pl.hidden.filter(k=>k!==hk);else pl.hidden.push(hk);bump();save();render(F.dataset.fid);
   toast(`${pl.hidden.includes(hk)?"Masquée":"Affichée"} : ${lbl?lbl[1]:x} (${pl.name})`);break}''',
  '''  case "hide":{const pl=S.playlists.find(p=>p.id===v);if(!pl)break;pl.hidden=pl.hidden||[];const hk=w+":"+x;
   const h=!pl.hidden.includes(hk);if(h)pl.hidden.push(hk);else pl.hidden=pl.hidden.filter(k=>k!==hk);
   PLDIRTY=true;clearTimeout(PLSAVE);PLSAVE=setTimeout(save,1200);
   const el=F;if(el){const s=el.querySelector(".sw");if(s)s.classList.toggle("on",!h);const sm=el.querySelector("small");if(sm)sm.textContent=sm.textContent.replace(/ · masquée$/,"")+(h?" · masquée":"")}
   break}''')
R('  case "hideall":{const pl=S.playlists.find(p=>p.id===v);pl.hidden=[];bump();save();render(F.dataset.fid);',
  '  case "hideall":{const pl=S.playlists.find(p=>p.id===v);pl.hidden=[];PLDIRTY=false;bump();dirty();save();render(F.dataset.fid);')
R(' if(t.t==="player"){stopPlayer()}', ' if(t.t==="plm"&&PLDIRTY){PLDIRTY=false;clearTimeout(PLSAVE);save();bump();dirty()}\n if(t.t==="player"){stopPlayer()}')
R('function plmHtml(id){', 'let PLDIRTY=false,PLSAVE=null;\nfunction plmHtml(id){')

# réglages : une page d'accueil courte, chaque rubrique s'ouvre à part
R('function settingsHtml(){', '''const SSEC_IC={"Mes playlists":"▤","Catalogue":"▦","Guide":"▥","À propos":"⟳","Appareil":"▢","Lecteur":"▶","Notes":"★","Général":"⚙"};
function settingsParts(){const tp=document.createElement("template");tp.innerHTML=settingsFull();const root=tp.content.firstElementChild;
 return {root,secs:[...root.querySelectorAll(":scope>section")]}}
function settingsHtml(){const {root,secs}=settingsParts();
 const rows=secs.map((s,i)=>{const h=s.querySelector("h3"),t=h?h.textContent:"Rubrique";const n=s.querySelectorAll("[data-f]").length;
  return `<div class="it" data-f data-fid="ss-${i}" data-act="sset:${i}"><span>${esc(t)}</span><span>${n} réglage${n>1?"s":""} ›</span></div>`}).join("");
 return `<div class="set sy" id="set"><section data-anchor><h3>Réglages</h3><div class="grp">${rows}</div></section><div style="height:30px"></div></div>`}
function ssetHtml(i){const {secs}=settingsParts();const s=secs[i];if(!s)return "";
 const h=s.querySelector("h3");const title=h?h.textContent:"";if(h)h.remove();
 return `<div class="set sy" id="set" style="top:60px"><section data-anchor><div class="kick" style="margin-left:18px">Réglages</div><h2 style="margin:6px 0 14px 18px;font-size:40px;font-weight:700;letter-spacing:-.02em">${esc(title)}</h2></section>${s.outerHTML}<div style="height:30px"></div></div>`}
function settingsFull(){''')
R(' else if(t.t==="diag") html=diagHtml();', ' else if(t.t==="diag") html=diagHtml();\n else if(t.t==="sset") html=ssetHtml(t.i);')
R(' else if(t.t==="plm"||t.t==="cat"||t.t==="diag"||', ' else if(t.t==="plm"||t.t==="cat"||t.t==="diag"||t.t==="sset"||')
R('  case "ocat":', '  case "sset": push({t:"sset",i:+v});break;\n  case "ocat":')

# ---------------------------------------------------------------- 2.1.4 : contenu francophone et adulte
R(' LOG(`${pl.name} chargée en', '''{const r=dropAdult(D);if(r)LOG(`${pl.name} : ${r} catégories adultes ignorées (jamais chargées)`)}
 LOG(`${pl.name} chargée en''')
R('const mapCats=a=>', '''/* Catégories adultes : jamais chargées (sauf si activées dans Réglages › Catalogue) */
const ADULT=/(^|[^a-z0-9])(adult|adulte|adultes|adults|xxx|porn|porno|sexe|sex|erotic|erotique|erotica|charme|hentai|for adults)([^a-z0-9]|$)|18 ?\\+|\\+ ?18/;
const isAdultCat=n=>ADULT.test(norm(String(n||"")));
function dropAdult(D){if(S.set.adult)return 0;let n=0;
 for(const [lk,lst] of [["lc","live"],["vc","vod"],["sc","ser"]]){const m=D[lk]||{},bad=new Set();
  for(const k of Object.keys(m))if(isAdultCat(m[k])){bad.add(String(k));delete m[k];n++}
  if(bad.size)D[lst]=(D[lst]||[]).filter(x=>!bad.has(String(x.cat))&&!(x.cs||[]).some(c=>bad.has(String(c))))}
 return n}
/* Catégories non francophones : repérées par un code pays ou une langue étrangère, sans mention française */
const FRM=/(^|[^a-z])(fr|fra|france|francais|francaise|french|vf|vff|vfq|vfi|vostfr|truefrench|belgique|belgium|suisse|quebec|qc|afrique|francophone|dom ?tom|antilles|reunion)([^a-z]|$)/;
const FCODE="en|eng|uk|gb|us|usa|de|ger|at|it|ita|es|esp|sp|lat|mx|pt|br|ar|tr|nl|pl|ro|ru|ua|gr|al|yu|exyu|ex-yu|hr|rs|ba|mk|si|bg|cz|sk|hu|se|swe|no|dk|fi|is|in|pk|bd|lk|np|cn|tw|hk|jp|kr|kh|vn|th|ph|my|sg|id|ir|iq|af|ku|il|am|az|ge|kz|uz|so|et|ng|gh|ke|za|car|latam|latino|arab|asia";
const FMARK=new RegExp("^[^a-z0-9]*("+FCODE+")\\\\s*[|:\\\\-–»\\\\]\\\\)/]|[|\\\\[\\\\(]\\\\s*("+FCODE+")\\\\s*[|\\\\]\\\\)]");
const FWORD=/(ex-?yu|yugo|bollywood|english|anglais|german|allemand|deutsch|deutschland|italia|italian|italien|espana|spanish|espagnol|latino|portugal|portugues|brasil|brazil|arabic|arabe|turkish|turc|turkiye|turk|dutch|nederland|polska|polish|romania|russia|russe|ukrain|greek|grec|albania|albanais|serbia|croatia|bulgaria|czech|hungar|swedish|svenska|norway|danish|finnish|india|hindi|tamil|telugu|malayalam|punjabi|bengali|pakistan|urdu|chinese|chinois|japan|korean|coreen|kurd|persian|iran|afghan|somali|ethiopia|amharic|israel|hebrew|philippin|vietnam|thai|indonesia|malay|caribbean|jamaica|nigeria|ghana|kenya|swahili|armenia|georgia|azer|kazakh)/;
function foreignCat(n){const t=norm(String(n||""));return !FRM.test(t)&&(FMARK.test(t)||FWORD.test(t))}
function frOnly(pl){const D=DATA[pl.id];if(!D)return 0;const h=new Set(pl.hidden||[]);let n=0;
 for(const [t,m] of [["l",D.lc],["f",D.vc],["s",D.sc]])for(const name of Object.values(m||{}))if(foreignCat(name)){const k=t+":"+catKey(name);if(!h.has(k)){h.add(k);n++}}
 pl.hidden=[...h];return n}
const mapCats=a=>''')
# ajout d'une playlist : on ne garde que le francophone
R('try{await loadPlaylist(pl,mark);mark(5);S.playlists.push(pl);buildCatalog();mark(6);',
  'try{await loadPlaylist(pl,mark);mark(5);const nfr=frOnly(pl);if(nfr)LOG(`${pl.name} : ${nfr} catégories non francophones masquées`);S.playlists.push(pl);buildCatalog();mark(6);if(nfr)setTimeout(()=>toast(`${nfr} catégories non francophones masquées · modifiable dans la playlist`),2600);')
# page de la playlist : bouton pour les playlists déjà ajoutées
R('  <div class="it" data-f data-fid="plm-showall" data-act="hideall:${p.id}:0">',
  '  <div class="it tall" data-f data-fid="plm-fr" data-act="fronly:${p.id}"><span>Garder uniquement le contenu francophone<small>Masque les catégories marquées d\\\'un autre pays ou d\\\'une autre langue · réversible ci-dessous</small></span><span>›</span></div>\n  <div class="it" data-f data-fid="plm-showall" data-act="hideall:${p.id}:0">')
R('  case "sset":', '''  case "fronly":{const pl=S.playlists.find(p=>p.id===v);if(!pl)break;const n=frOnly(pl);PLDIRTY=false;bump();dirty();save();render(F.dataset.fid);toast(n?`${n} catégories non francophones masquées`:"Aucune autre catégorie étrangère repérée");break}
  case "sset":''')
# réglage : contenu adulte
R('''  <div class="it"><span>Titres et chaînes avec plusieurs sources</span><span>${dup} titres regroupés</span></div>''',
  '''  <div class="it"><span>Titres et chaînes avec plusieurs sources</span><span>${dup} titres regroupés</span></div>
  <div class="it tall" data-f data-fid="set-adult" data-act="set:adult"><span>Charger le contenu adulte<small>Désactivé : les catégories adultes ne sont jamais chargées · pris en compte à la prochaine actualisation des playlists</small></span>${sw(st.adult)}</div>''')
