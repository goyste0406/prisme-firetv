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
  if(bad.size)D[lst]=(D[lst]||[]).filter(x=>{if(!bad.has(String(x.cat)))return true;const alt=(x.cs||[]).map(String).find(c=>m[c]!=null&&!bad.has(c));if(alt){x.cat=alt;return true}return false})}
 return n}
/* Catégories non francophones : repérées par un code pays ou une langue étrangère, sans mention française */
const FRM=/(^|[^a-z])(fr|fra|france|francais|francaise|french|vf|vff|vfq|vfi|vostfr|truefrench|belgique|belgium|suisse|quebec|qc|afrique|francophone|dom ?tom|antilles|reunion)([^a-z]|$)/;
const FCODE="en|eng|uk|gb|us|usa|de|ger|at|it|ita|es|esp|sp|lat|mx|pt|br|ar|tr|nl|pl|ro|ru|ua|gr|al|yu|exyu|ex-yu|hr|rs|ba|mk|si|bg|cz|sk|hu|se|swe|no|dk|fi|is|in|pk|bd|lk|np|cn|tw|hk|jp|kr|kh|vn|th|ph|my|sg|id|ir|iq|af|ku|il|am|az|ge|kz|uz|so|et|ng|gh|ke|za|car|latam|latino|arab|asia";
const FMARK=new RegExp("^[^a-z0-9]*("+FCODE+")\\\\s*[|:\\\\-–»\\\\]\\\\)/]|[|\\\\[\\\\(]\\\\s*("+FCODE+")\\\\s*[|\\\\]\\\\)]");
const FWORD=/(^|[^a-z])(ex-?yu|yugo|bollywood|english|anglais|anglaise|german|allemand|allemande|deutsch|deutschland|italia|italian|italien|italienne|espana|spain|spanish|espagnol|espagnole|latino|latina|portugal|portugues|portuguese|portugais|brasil|brazil|bresil|arabic|arabe|arab|turkish|turc|turque|turkiye|turkey|dutch|nederland|netherlands|polska|polish|polonais|romania|romanian|roumain|russia|russian|russe|ukraine|ukrainian|greek|grec|grece|albania|albanian|albanais|serbia|serbian|croatia|bulgaria|czech|hungary|hungarian|swedish|svenska|sweden|norway|norwegian|danish|denmark|finnish|finland|india|indian|hindi|tamil|telugu|malayalam|punjabi|bengali|bangla|pakistan|urdu|chinese|chinois|china|japan|japanese|japonais|korea|korean|coreen|kurd|kurdish|kurdistan|persian|farsi|iran|afghan|afghanistan|somali|somalia|ethiopia|amharic|israel|hebrew|philippines|filipino|vietnam|vietnamese|thai|thailand|indonesia|malaysia|malay|caribbean|jamaica|nigeria|ghana|kenya|swahili|armenia|armenian|georgian|azeri|azerbaijan|kazakh)([^a-z]|$)/;
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

# ---------------------------------------------------------------- 2.1.5 : sources et résumés en français uniquement
R('const mapCats=a=>', '''/* Langue d'une source : VO ou marque d'un autre pays dans le nom du flux → pas francophone */
const FCSET=new Set(FCODE.split("|"));
function frSrc(name,tag){if(tag==="VO")return false;const raw=String(name||""),t=norm(raw);if(FRM.test(t))return true;
 const m=raw.match(/^[^A-Za-z0-9]*([A-Z]{2,5})(?:\s*\||\s+[-–»]|:|\s*\]|\s*\))/)||raw.match(/^\s*[|\[(]\s*([A-Z]{2,5})\s*[|\])]/)||raw.match(/[\[(]\s*([A-Z]{2,5})\s*[\])]\s*$/);
 return !(m&&FCSET.has(m[1].toLowerCase()))}
/* Le résumé est-il en français ? (mots les plus courants de chaque langue) */
const FRW=new Set("le les des une et est dans pour qui sur avec son sa ses du au aux il elle ne pas plus ce cette leur leurs par mais lui sont ont été être après tout entre deux".split(" "));
const ENW=new Set("the and of to in is his her with for on that who when after their an as by from but he she they this was are be has have into".split(" "));
const OTW=new Set("el los las del una y con para su por como sus al der die das und ist nicht mit von zu ein eine di che della nel sono gli lo dos uma não".split(" "));
function isFr(t){t=String(t||"");if(!t.trim())return true;
 if(/[\\u0600-\\u06FF\\u0400-\\u04FF\\u0590-\\u05FF\\u0E00-\\u0E7F\\u3040-\\u30FF\\u4E00-\\u9FFF\\uAC00-\\uD7AF]/.test(t))return false;
 const w=t.toLowerCase().match(/[a-zàâäéèêëïîôöùûüçãõñß']+/g)||[];if(w.length<6)return true;
 let f=(t.match(/[èêàâçùûîôœ]/gi)||[]).length,e=0,o=(t.match(/[ñáíóú¿¡ãõß]/gi)||[]).length;
 for(const x of w){if(FRW.has(x))f++;else if(ENW.has(x))e++;else if(OTW.has(x))o++}
 return f>=Math.max(e,o)}
const mapCats=a=>''')
R('   it.src.push({pl:pl.id,sid:v.id,ext:v.ext,q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added});',
  '   it.src.push({pl:pl.id,sid:v.id,ext:v.ext,q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added,fr:frSrc(v.n,p.tag)});')
R('   it.src.push({pl:pl.id,sid:v.id,ext:"mkv",q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added});',
  '   it.src.push({pl:pl.id,sid:v.id,ext:"mkv",q:p.q,tag:p.tag,name:v.n,cat:ck,added:v.added,fr:frSrc(v.n,p.tag)});')
R('if(!it.s&&v.plot)it.s=v.plot;', 'if(!it.s&&v.plot&&isFr(v.plot))it.s=v.plot;')
R('   it.s=f.plot||f.description||it.s;', '   {const t=f.plot||f.description||"";if(t&&isFr(t))it.s=t;else if(it.s&&!isFr(it.s))it.s=""}')
R('   it.s=f.plot||it.s;', '   {const t=f.plot||"";if(t&&isFr(t))it.s=t;else if(it.s&&!isFr(it.s))it.s=""}')
# seules les sources francophones comptent (sauf réglage contraire)
R('function base(pl,key){const it=key.startsWith("ch:")?CH[key.slice(3)]:ALL[key];return !!it&&it.src.some(s=>s.pl===pl.id)}',
  'function base(pl,key){const it=key.startsWith("ch:")?CH[key.slice(3)]:ALL[key];return !!it&&it.src.some(s=>s.pl===pl.id&&(S.set.allLang||s.fr!==false))}')
R(' return it.src.filter(s=>s.pl===pl.id).map((s,i)=>{', ' return it.src.filter(s=>s.pl===pl.id&&(S.set.allLang||s.fr!==false)).map((s,i)=>{')
R('''  <div class="it tall" data-f data-fid="set-adult" data-act="set:adult">''', '''  <div class="it tall" data-f data-fid="set-alllang" data-act="langall"><span>Sources dans toutes les langues<small>Désactivé : seules les sources francophones (VF, VOSTFR, MULTI) apparaissent sur les fiches</small></span>${sw(st.allLang)}</div>
  <div class="it tall" data-f data-fid="set-adult" data-act="set:adult">''')
R('  case "sset":', '  case "langall": S.set.allLang=!S.set.allLang;bump();dirty();save();render(F.dataset.fid);break;\n  case "sset":')

# ---------------------------------------------------------------- 2.1.6 : les catégories masquées ne sont plus chargées
R('{const r=dropAdult(D);if(r)LOG(`${pl.name} : ${r} catégories adultes ignorées (jamais chargées)`)}',
  '{const r=dropAdult(D);if(r)LOG(`${pl.name} : ${r} catégories adultes ignorées (jamais chargées)`)}\n {const r=pruneHidden(pl,D);if(r)LOG(`${pl.name} : ${r} titres et chaînes de catégories masquées non chargés`)}')
R('const mapCats=a=>', '''/* Catégories masquées : leurs titres ne sont pas gardés en mémoire (ils sont rechargés si on les réaffiche) */
function pruneHidden(pl,D){const h=hidSetOf(pl);if(!h.size||!D)return 0;D.hc=D.hc||{};let n=0;
 for(const [t,cm,lst] of [["l","lc","live"],["f","vc","vod"],["s","sc","ser"]]){const m=D[cm]||{},bad=new Set();
  for(const k of Object.keys(m)){const hk=t+":"+catKey(m[k]);if(h.has(hk))bad.add(String(k))}
  if(!bad.size)continue;
  D[lst]=(D[lst]||[]).filter(x=>{if(!bad.has(String(x.cat)))return true;
   const alt=(x.cs||[]).map(String).find(c=>m[c]!=null&&!bad.has(c));if(alt){x.cat=alt;return true}
   const hk=t+":"+catKey(m[x.cat]);D.hc[hk]=(D.hc[hk]||0)+1;n++;return false})}
 return n}
function hidSetOf(pl){return new Set(pl.hidden||[])}
const mapCats=a=>''')
# nouvelle playlist : on retire tout de suite ce qui vient d'être masqué
R('const nfr=frOnly(pl);if(nfr)LOG(`${pl.name} : ${nfr} catégories non francophones masquées`);',
  'const nfr=frOnly(pl);if(nfr){LOG(`${pl.name} : ${nfr} catégories non francophones masquées`);const D=DATA[pl.id];if(pruneHidden(pl,D))IDB.put("pl:"+pl.id,D)}')
# bouton « francophone » sur une playlist existante : retire aussi de la mémoire
R('  case "fronly":{const pl=S.playlists.find(p=>p.id===v);if(!pl)break;const n=frOnly(pl);PLDIRTY=false;bump();dirty();save();render(F.dataset.fid);',
  '  case "fronly":{const pl=S.playlists.find(p=>p.id===v);if(!pl)break;const n=frOnly(pl);PLDIRTY=false;if(n){const D=DATA[pl.id];pruneHidden(pl,D);IDB.put("pl:"+pl.id,D);buildCatalog()}bump();dirty();save();render(F.dataset.fid);')
# comptes des catégories masquées (titres non chargés)
R('function catCount(pl,type,k){return plStats(pl)[type][k]||0}', 'function catCount(pl,type,k){const D=DATA[pl.id];return plStats(pl)[type][k]||(D&&D.hc&&D.hc[type+":"+k])||0}')
# réafficher une catégorie retirée de la mémoire : rechargement de la playlist en quittant la page
R('   PLDIRTY=true;clearTimeout(PLSAVE);PLSAVE=setTimeout(save,1200);',
  '   PLDIRTY=true;clearTimeout(PLSAVE);PLSAVE=setTimeout(save,1200);{const D=DATA[pl.id];if(!h&&D&&D.hc&&D.hc[hk])PLRELOAD.add(pl.id)}')
R('let PLDIRTY=false,PLSAVE=null;', 'let PLDIRTY=false,PLSAVE=null;const PLRELOAD=new Set();')
R('  case "hideall":{const pl=S.playlists.find(p=>p.id===v);pl.hidden=[];PLDIRTY=false;bump();dirty();save();render(F.dataset.fid);',
  '  case "hideall":{const pl=S.playlists.find(p=>p.id===v);pl.hidden=[];PLDIRTY=false;{const D=DATA[pl.id];if(D&&D.hc&&Object.keys(D.hc).length)PLRELOAD.add(pl.id)}bump();dirty();save();render(F.dataset.fid);setTimeout(plApply,50);')
R(' if(t.t==="plm"&&PLDIRTY){PLDIRTY=false;clearTimeout(PLSAVE);save();bump();dirty()}',
  ' if(t.t==="plm"&&(PLDIRTY||PLRELOAD.size)){PLDIRTY=false;clearTimeout(PLSAVE);save();setTimeout(plApply,30)}')
R('function plmHtml(id){', '''/* En quittant la page d'une playlist : on retire de la mémoire ce qui vient d'être masqué,
   et on recharge la playlist si des catégories retirées ont été réaffichées */
async function plApply(){
 for(const p of S.playlists){const D=DATA[p.id];if(D&&!PLRELOAD.has(p.id)&&pruneHidden(p,D))IDB.put("pl:"+p.id,D)}
 buildCatalog();bump();dirty();
 const ids=[...PLRELOAD];PLRELOAD.clear();
 for(const id of ids){const p=S.playlists.find(x=>x.id===id);if(!p)continue;toast(`${p.name} : chargement des catégories réaffichées…`);
  try{await loadPlaylist(p);p.synced=Date.now();buildCatalog();bump();dirty();save();toast(`${p.name} : catégories réaffichées chargées`)}catch(e){toast(`${p.name} : rechargement impossible (${e.message})`)}}
 if(NAT.vis)Prisme.nativeEvent("catalog","");
 const t=topS();if(t.t!=="player")render(F&&F.dataset.fid)}
function plmHtml(id){''')

# ---------------------------------------------------------------- 2.1.7 : choix des catégories avant de charger une playlist
# téléchargement sélectif : seules les catégories gardées sont demandées (une par une si peu nombreuses)
R(' const SK={get_live_streams:"live",get_vod_streams:"vod",get_series:"series"};', ''' const SK={get_live_streams:"live",get_vod_streams:"vod",get_series:"series"};
 if(pick){const ok=await pick(D);if(!ok)throw new Error("ajout annulé")}
 const hset=new Set(pl.hidden||[]);''')
R(' step(2);D.live=await fillCats(pl,"get_live_streams",D.lc,await all("get_live_streams",mL,90000),mL,D);',
  ''' const sel=async(action,map,to,t,cm)=>{const ids=Object.keys(cm||{});
  const vis=ids.filter(k=>!hset.has(t+":"+catKey(cm[k]))&&(S.set.adult||!isAdultCat(cm[k])));
  if(!hset.size||vis.length>=ids.length*0.6)return all(action,map,to);
  {const full=await all(action,map,to);if(full.length)return full}
  LOG(`${pl.name} · ${SK[action]} : liste complète indisponible, chargement des catégories gardées une par une`);
  D.sel=true;const out=[],seen=new Set();
  for(const c of vis){try{const r=await getJSON(api(pl,action,"&category_id="+encodeURIComponent(c)),60000,SK[action]||"");
   (Array.isArray(r)?r:Object.values(r||{}).filter(x=>x&&typeof x==="object")).forEach(x=>{const m=map(x);const p0=m.cat;m.cat=String(c);if(p0&&p0!==m.cat){m.cs=[m.cat,...(m.cs||[p0]).filter(z=>z!==m.cat)]}if(!seen.has(m.id)){seen.add(m.id);out.push(m)}})}
   catch(e){LOG(`${pl.name} · ${action} catégorie ${c} : ${e.message}`)}}
  LOG(`${pl.name} · ${SK[action]} : ${vis.length} catégories gardées sur ${ids.length}, chargées une par une`);return out};
 step(2);D.live=await fillCats(pl,"get_live_streams",D.lc,await sel("get_live_streams",mL,90000,"l",D.lc),mL,D);''')
R('D.vod=await fillCats(pl,"get_vod_streams",D.vc,await all("get_vod_streams",mV,300000),mV,D);', 'D.vod=await fillCats(pl,"get_vod_streams",D.vc,await sel("get_vod_streams",mV,300000,"f",D.vc),mV,D);')
R('D.ser=await fillCats(pl,"get_series",D.sc,await all("get_series",mS,300000),mS,D);', 'D.ser=await fillCats(pl,"get_series",D.sc,await sel("get_series",mS,300000,"s",D.sc),mS,D);')
R('async function fillCats(pl,action,cats,list,map,D){\n if(list.length)return list;', 'async function fillCats(pl,action,cats,list,map,D){\n if(list.length||D.sel)return list;')
R('async function loadPlaylist(pl,step=()=>{}){', 'async function loadPlaylist(pl,step=()=>{},pick=null){')
# ajout : écran de choix des catégories entre l'authentification et le téléchargement
R('try{await loadPlaylist(pl,mark);mark(5);const nfr=frOnly(pl);if(nfr){LOG(`${pl.name} : ${nfr} catégories non francophones masquées`);const D=DATA[pl.id];if(pruneHidden(pl,D))IDB.put("pl:"+pl.id,D)}S.playlists.push(pl);buildCatalog();mark(6);if(nfr)setTimeout(()=>toast(`${nfr} catégories non francophones masquées · modifiable dans la playlist`),2600);',
  'try{await loadPlaylist(pl,mark,D=>pickCats(pl,D));mark(5);S.playlists.push(pl);buildCatalog();mark(6);')
R(' }catch(e){S.loading=false;render("f-url");toast("Connexion impossible : "+e.message)}',
  ' }catch(e){S.loading=false;S.pick=null;render("f-url");toast(e.message==="ajout annulé"?"Ajout de la playlist annulé":"Connexion impossible : "+e.message)}')
R(' else if(!inApp()) html=S.loading?loadingHtml():loginHtml();', ' else if(!inApp()) html=S.pick?pickHtml():S.loading?loadingHtml():loginHtml();')
R('function back(){\n', 'function back(){\n if(S.pick){const r=S.pick.res;S.pick=null;S.loading=true;r(false);return}\n')
R('function plmHtml(id){', '''function pickCats(pl,D){return new Promise(res=>{
 const h=new Set();for(const [t,m] of [["l",D.lc],["f",D.vc],["s",D.sc]])for(const n of Object.values(m||{}))if(foreignCat(n))h.add(t+":"+catKey(n));
 S.pick={pl,D,res,h};S.loading=false;render()})}
function pickList(t){const P2=S.pick,m=t==="l"?P2.D.lc:t==="f"?P2.D.vc:P2.D.sc,seen=new Set();
 return Object.values(m||{}).filter(n=>S.set.adult||!isAdultCat(n)).map(n=>[catKey(n),n]).filter(([k])=>!seen.has(k)&&seen.add(k))}
function pickCount(){const P2=S.pick;let a=0,b=0;for(const t of ["l","f","s"])for(const [k] of pickList(t)){b++;if(!P2.h.has(t+":"+k))a++}return [a,b]}
function pickHtml(){const P2=S.pick;const [a,b]=pickCount();
 const sec=(t,label)=>{const L=pickList(t);if(!L.length)return "";return `<section data-anchor><h3>${label} · ${L.length}</h3><div class="grp">${L.map(([k,n])=>`<div class="it" data-f data-fid="pk-${t}-${k}" data-act="pk:${t}:${k}"><span>${esc(n)}</span>${sw(!P2.h.has(t+":"+k))}</div>`).join("")}</div></section>`};
 return `<div class="set sy" id="set" style="top:40px"><section data-anchor><div class="kick" style="margin-left:18px">Nouvelle playlist · ${esc(P2.pl.name)}</div><h2 style="margin:6px 0 6px 18px;font-size:40px;font-weight:700;letter-spacing:-.02em">Catégories à charger</h2>
  <p style="margin:0 0 14px 18px;color:rgba(255,255,255,.65);font-size:17px">Seules les catégories cochées seront téléchargées. Tu pourras changer ce choix plus tard dans la playlist.</p><div class="grp">
  <div class="it tall" data-f data-fid="pk-go" data-act="pkgo" data-default><span>Continuer et charger<small id="pkn">${a} catégorie${a>1?"s":""} cochée${a>1?"s":""} sur ${b}</small></span><span>›</span></div>
  <div class="it tall" data-f data-fid="pk-fr" data-act="pkfr"><span>Garder uniquement le contenu francophone<small>Décoche les catégories d'un autre pays ou d'une autre langue</small></span><span>›</span></div>
  <div class="it" data-f data-fid="pk-all" data-act="pkall"><span>Tout cocher</span><span>›</span></div>
  <div class="it" data-f data-fid="pk-none" data-act="pknone"><span>Tout décocher</span><span>›</span></div>
 </div></section>${sec("l","Catégories TV en direct")}${sec("f","Catégories films")}${sec("s","Catégories séries")}<div style="height:30px"></div></div>`}
function pickRefresh(){const [a,b]=pickCount();const n=$("#pkn");if(n)n.textContent=`${a} catégorie${a>1?"s":""} cochée${a>1?"s":""} sur ${b}`}
function plmHtml(id){''')
R('  case "sset":', '''  case "pk":{const P2=S.pick;if(!P2)break;const hk=v+":"+w;if(P2.h.has(hk))P2.h.delete(hk);else P2.h.add(hk);const s=F&&F.querySelector(".sw");if(s)s.classList.toggle("on",!P2.h.has(hk));pickRefresh();break}
  case "pkfr":{const P2=S.pick;if(!P2)break;for(const [t,m] of [["l",P2.D.lc],["f",P2.D.vc],["s",P2.D.sc]])for(const n of Object.values(m||{})){const k=t+":"+catKey(n);if(foreignCat(n))P2.h.add(k);else P2.h.delete(k)}render(F.dataset.fid);break}
  case "pkall":{if(S.pick){S.pick.h.clear();render(F.dataset.fid)}break}
  case "pknone":{const P2=S.pick;if(!P2)break;for(const t of ["l","f","s"])for(const [k] of pickList(t))P2.h.add(t+":"+k);render(F.dataset.fid);break}
  case "pkgo":{const P2=S.pick;if(!P2)break;P2.pl.hidden=[...P2.h];S.pick=null;S.loading=true;render();P2.res(true);break}
  case "sset":''')

# ---------------------------------------------------------------- 2.1.10 : titres propres et fusion prudente
# 3) préfixes en tête de nom : |FR|, FR|, VF -, NETFLIX |, [FR]… (répétés), sans toucher aux titres comme « It : Chapitre 2 »
R(' let s=String(raw||"").replace(/^\\s*[\\[(]?[A-Z]{2,4}[\\])]?\\s*[|:\\-–•]\\s*/i,"").replace(/^\\s*[A-Z]{2,4}\\s*\\|\\s*/,"");',
  ' let s=String(raw||"");for(let i=0;i<4;i++){const s2=s.replace(/^\\s*[|\\[(]\\s*[A-Z0-9+]{2,8}\\s*[|\\])]\\s*[-–•:]?\\s*/,"").replace(/^\\s*(?:[A-Z]{2,4}|VOSTFR|MULTI|4K|UHD|FHD|NETFLIX|DISNEY\\+?|AMAZON|PRIME|APPLE TV\\+?|CANAL\\+?|HBO|MAX|PARAMOUNT\\+?)(?:\\s*\\||\\s+[-–•]|:)\\s*/,"");if(s2===s)break;s=s2}')
# 4) sans identifiant TMDB ni année : pas de fusion avec un homonyme (remakes)
R('const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:norm(p.title)+"|"+p.year;',
  'const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:p.year?norm(p.title)+"|"+p.year:norm(p.title)+"|?"+pl.id+":"+v.id;')
R('const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:norm(p.title)+"|"+(p.year||v.year);',
  'const p=parseName(v.n),key=v.tmdb&&v.tmdb!=="0"?"t"+v.tmdb:(p.year||v.year)?norm(p.title)+"|"+(p.year||v.year):norm(p.title)+"|?"+pl.id+":"+v.id;')

# ---------------------------------------------------------------- 2.1.11 : langue audio et sous-titres par défaut
R('''  <div class="it" data-f data-fid="set-subs" data-act="set:subs"><span>Sous-titres par défaut</span>${sw(st.subs)}</div>''',
  '''  <div class="it tall" data-f data-fid="set-alang" data-act="lang:a"><span>Langue audio par défaut<small>Choisie automatiquement au lancement de chaque film ou épisode</small></span><span>${LANGN[st.aLang??"fr"]} ›</span></div>
  <div class="it tall" data-f data-fid="set-slang" data-act="lang:s"><span>Sous-titres par défaut<small>Affichés automatiquement s'ils existent dans la langue choisie</small></span><span>${LANGN[st.sLang??""]||"Aucun"} ›</span></div>''')
R('  case "sset":', '''  case "lang":{const opts=v==="a"?["fr","en",""]:["","fr","en"],k=v==="a"?"aLang":"sLang",cur=S.set[k]??(v==="a"?"fr":"");
   S.set[k]=opts[(opts.indexOf(cur)+1)%opts.length];save();langPrefs();render(F.dataset.fid);break}
  case "sset":''')
R('function plmHtml(id){', '''const LANGN={fr:"Français",en:"Anglais","":"Version originale"};
const LANGRE={fr:/fr|fre|fra|fran|french|\\bvf|vff|vfq|truefrench/i,en:/^en|eng|english|anglais/i};
function langPrefs(){try{if(NATIVE&&typeof Prisme.setLangPrefs==="function")Prisme.setLangPrefs(S.set.aLang??"fr",S.set.sLang??"")}catch(e){}}
setTimeout(langPrefs,500);
/* Pistes sans code de langue (fréquent dans les MKV) : on repère la piste française d'après son nom */
function langFix(st){const a=S.set.aLang??"fr";if(!a||!st.audio||st.audio.length<2)return;const re=LANGRE[a];if(!re)return;
 const ok=t=>t&&(re.test(t.code||"")||re.test(t.lang||"")||re.test(t.name||""));
 if(ok(st.audio[st.aSel]))return;const i=st.audio.findIndex(ok);if(i>=0&&i!==st.aSel){Prisme.setAudio(i);P.audio=i;LOG(`Piste audio ${LANGN[a]} choisie automatiquement`)}}
function plmHtml(id){''')
R('  if(P.kind==="vod"&&P.aSync==null&&st.audio&&st.audio.length){P.aSync=1;', '  if(P.kind==="vod"&&P.aSync==null&&st.audio&&st.audio.length){P.aSync=1;langFix(st);st.aSel=P.audio??st.aSel;')

# ---------------------------------------------------------------- 2.1.12 : actualisation en tâche de fond avec avancement
R('function plmHtml(id){', '''/* Actualisation en arrière-plan : une à la fois par playlist, avancement affiché partout (pastille en bas à droite) */
const TASK={on:false,label:"",step:"",n:0,poll:null,q:[]};const REFRESHING=new Set();
const STEPN=["connexion","catégories","chaînes","films","séries"];
function taskText(){return `Actualisation · ${TASK.label} · ${TASK.step}${TASK.n>0?` · ${TASK.n.toLocaleString("fr-FR")} reçus`:""}${TASK.q.length?` · ${TASK.q.length} en attente`:""}`}
function taskDraw(){let el=document.getElementById("bgtask");
 if(!el){el=document.createElement("div");el.id="bgtask";el.style.cssText="position:fixed;right:28px;bottom:22px;z-index:99;display:none;align-items:center;gap:10px;padding:8px 16px 8px 12px;border-radius:20px;background:rgba(26,26,32,.94);border:1px solid rgba(255,255,255,.12);color:#fff;font:500 15px Outfit,sans-serif";
  el.innerHTML='<span style="width:14px;height:14px;border-radius:50%;border:2.5px solid rgba(255,255,255,.25);border-top-color:#fff;animation:bgspin .9s linear infinite"></span><span id="bgtaskt"></span>';
  const st=document.createElement("style");st.textContent="@keyframes bgspin{to{transform:rotate(360deg)}}";document.head.appendChild(st);document.body.appendChild(el)}
 el.style.display=TASK.on?"flex":"none";const t=document.getElementById("bgtaskt");if(t)t.textContent=taskText();
 try{if(NAT.ok)Prisme.nativeEvent("task",JSON.stringify({on:TASK.on,text:taskText()}))}catch(e){}}
async function refreshPl(p,quiet){
 if(REFRESHING.has(p.id)){if(!quiet)toast(`${p.name} : actualisation déjà en cours`);return}
 REFRESHING.add(p.id);
 while(TASK.on){if(!TASK.q.includes(p.name))TASK.q.push(p.name);taskDraw();await nap(1000)}
 TASK.q=TASK.q.filter(x=>x!==p.name);
 const before=counts(p);TASK.on=true;TASK.label=p.name;TASK.step="connexion";TASK.n=0;taskDraw();
 TASK.poll=setInterval(()=>{try{if(NATIVE&&typeof Prisme.slimCount==="function"){const n=Prisme.slimCount();if(n!==TASK.n){TASK.n=n;taskDraw()}}}catch(e){}},1000);
 try{await loadPlaylist(p,i=>{TASK.step=STEPN[i]||"";TASK.n=0;taskDraw()});p.synced=Date.now();TASK.step="mise à jour du catalogue";TASK.n=0;taskDraw();await nap(30);
  buildCatalog();bump();dirty();save();const a=counts(p);
  const d=(x,y,l)=>x!==y?`${x>y?"+":""}${(x-y).toLocaleString("fr-FR")} ${l}`:"";
  const diff=[d(a.f,before.f,"films"),d(a.s,before.s,"séries"),d(a.c,before.c,"chaînes")].filter(Boolean).join(" · ");
  LOG(`${p.name} actualisée · ${a.f} films · ${a.s} séries · ${a.c} chaînes${diff?" ("+diff+")":""}`);
  if(!quiet||diff)toast(`${p.name} à jour${diff?" : "+diff:" : aucun changement"}`);
  const t=topS();if(t.t!=="player"&&!S.modal&&Date.now()-LASTKEY>1500)render(F&&F.dataset.fid)}
 catch(e){toast(`${p.name} : actualisation impossible (${e.message})`);LOG(`${p.name} : actualisation impossible · ${e.message}`)}
 finally{clearInterval(TASK.poll);TASK.on=false;REFRESHING.delete(p.id);taskDraw()}}
function plmHtml(id){''')
R('  case "plref":{const pl=S.playlists.find(p=>p.id===v);toast(`Actualisation de ${pl.name}…`);loadPlaylist(pl).then(()=>{buildCatalog();save();render(F&&F.dataset.fid);toast(`${pl.name} à jour`)}).catch(e=>toast("Échec : "+e.message));break}',
  '  case "plref":{const pl=S.playlists.find(p=>p.id===v);if(pl){toast(`Actualisation de ${pl.name} en arrière-plan : tu peux continuer à regarder`);refreshPl(pl)}break}')
R('  try{await loadPlaylist(p);p.synced=Date.now();buildCatalog();bump();dirty();save();toast(`${p.name} : catégories réaffichées chargées`)}catch(e){toast(`${p.name} : rechargement impossible (${e.message})`)}}',
  '  await refreshPl(p,false)}')
R('  if(stale.length)Promise.all(stale.map(p=>loadPlaylist(p).then(()=>{p.synced=Date.now()}).catch(e=>{p.bootMsg=e.message}))).then(()=>{buildCatalog();save();',
  '  if(stale.length)(async()=>{for(const p of stale)await refreshPl(p,true)})().then(()=>{')
