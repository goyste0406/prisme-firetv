/* ========================= AJOUT D'UN FOURNISSEUR (4 étapes) =========================
   Connexion (iPhone par QR code, lien collé ou identifiants) → Vérification (commande du Mac, bilan du compte)
   → Contenu (types, catégories françaises, doublons, nom et couleur) → Importation.
   Dans le simulateur, le navigateur ne peut pas joindre ton serveur : la TV te donne la commande à coller dans Terminal
   (elle ne demande que le mot de passe), puis tu choisis les fichiers du dossier créé sur ton Bureau. */
(function(){
const SVG='viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="ic" aria-hidden="true"';
const PI={phone:`<svg ${SVG}><rect x="7" y="2" width="10" height="20" rx="2.5"/><path d="M11 18h2"/></svg>`,link:`<svg ${SVG}><path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/></svg>`,
 remote:`<svg ${SVG}><rect x="7" y="2" width="10" height="20" rx="5"/><circle cx="12" cy="8" r="2"/><path d="M12 14v.01M12 17v.01"/></svg>`,lock:`<svg ${SVG}><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>`,
 mac:`<svg ${SVG}><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M2 20h20"/></svg>`};
const PVCOL=["#f59e0b","#ec4899","#22c55e","#3b82f6","#a855f7","#ef4444","#14b8a6"];
window.PVCOL=PVCOL;
const STEPS=["Connexion","Vérification","Contenu","Importation"];
const TN={live:["TV en direct","chaînes","chaîne"],vod:["Films","films","film"],ser:["Séries","séries","série"]};
const TY=["live","vod","ser"];
const nf=n=>Number(n||0).toLocaleString("fr-FR").replace(/\u202f/g," ");
const pl=(n,s,p)=>n>1?p:s;
const usedCols=()=>(typeof REAL!=="undefined"&&REAL?REAL.pls.map(p=>p.col):[]);
function pvNew(){const u=usedCols();let c=PVCOL.findIndex(x=>!u.includes(x));if(c<0)c=0;return {step:0,way:null,name:"",url:"",user:"",link:"",an:null,chk:0,keep:{live:1,vod:1,ser:1},col:c,sub:0,ct:"live",showX:0,imp:{},done:false,err:"",msg:""}}
const PV=()=>S.pv||(S.pv=pvNew());window.PV=PV;
/* ---------- lien du fournisseur ---------- */
function parseLink(t){t=(t||"").trim();const m=t.match(/^(https?:\/\/[^/?#\s]+)/i);if(!m)return null;const u=t.match(/[?&]username=([^&\s#]+)/i),p=t.match(/[?&]password=([^&\s#]+)/i);
 let user=u?decodeURIComponent(u[1]):"",pass=p?decodeURIComponent(p[1]):"";
 if(!user){const q=t.match(/^https?:\/\/[^/]+\/(?:live|movie|series)\/([^/\s]+)\/([^/\s]+)\//i);if(q){user=decodeURIComponent(q[1]);pass=decodeURIComponent(q[2])}}
 return {url:m[1],user,pass:!!pass,m3u:/\.m3u8?(\?|$)|type=m3u/i.test(t)}}
const hostOf=u=>(u||"").replace(/^https?:\/\//i,"").replace(/\/.*$/,"");
const srvName=u=>{const h=hostOf(u).split(":")[0].split(".");return h.length>1&&!/^\d+$/.test(h[h.length-1])?h[h.length-2].replace(/^\w/,c=>c.toUpperCase()):""};
const normUrl=u=>{u=(u||"").trim().replace(/\/(get|player_api)\.php.*$/i,"").replace(/\/+$/,"");if(u&&!/^https?:\/\//i.test(u))u="http://"+u;return u};
const urlOk=u=>/^https?:\/\/([\w-]+\.)+[a-z0-9-]{2,}(:\d{2,5})?$/i.test(normUrl(u))||/^https?:\/\/\d{1,3}(\.\d{1,3}){3}(:\d{2,5})?$/i.test(normUrl(u));
const urlHint=u=>!u?"":!urlOk(u)?"adresse incomplète":/:\d+$/.test(normUrl(u))?"✓ adresse complète":"✓ adresse complète · sans port (souvent :8080)";
const pvName=p=>(p.name||"").trim()||srvName(p.url)||"Mon fournisseur";
const folder=p=>"prisme-"+pvName(p).replace(/ /g,"-");
/* ---------- écrans ---------- */
function stepsH(p){return `<div class="pv-steps">${STEPS.map((n,i)=>`${i?"<em></em>":""}<span class="${i===p.step?"on":i<p.step?"ok":""}"><i>${i<p.step?"✓":i+1}</i>${n}</span>`).join("")}</div>`}
function qrH(){let c="";const n=25;let x=0x9e3779b9;const r=()=>{x^=x<<13;x^=x>>>17;x^=x<<5;return (x>>>0)%100};const fin=(i,j)=>(i<7&&j<7)||(i<7&&j>=n-7)||(i>=n-7&&j<7);
 for(let i=0;i<n;i++)for(let j=0;j<n;j++){let on;if(fin(i,j)){const a=i<7?i:i-(n-7),b=j<7?j:j-(n-7);on=a===0||a===6||b===0||b===6||(a>=2&&a<=4&&b>=2&&b<=4)}else on=r()<46;if(on)c+=`<rect x="${j}" y="${i}" width="1" height="1"/>`}
 return `<div class="pv-qr"><svg viewBox="0 0 ${n} ${n}" width="228" height="228" fill="#111" role="img" aria-label="code QR à scanner avec l'iPhone">${c}</svg></div>`}
function s0(p){const first=!S.playlists.length;
 if(!p.way)return `<div class="pv-mut" style="font-size:20px">${first?"Pour commencer, ajoute ton abonnement IPTV. ":""}Comment veux-tu l'ajouter ?</div>
 <div class="pv-way">
  <div class="pv-wc" data-f data-fid="pv-w-phone" data-act="pv:way:phone" data-default>${PI.phone}<span class="rec">le plus simple</span><b>Avec mon iPhone</b><small>Tu scannes un code sur la TV, puis tu colles le lien ou les identifiants reçus par e-mail ou WhatsApp. Rien à taper à la télécommande.</small></div>
  <div class="pv-wc" data-f data-fid="pv-w-link" data-act="pv:way:link">${PI.link}<b>Coller un lien</b><small>Le lien M3U ou « get.php » donné par ton fournisseur : prisme y trouve tout seul le serveur et l'utilisateur.</small></div>
  <div class="pv-wc" data-f data-fid="pv-w-form" data-act="pv:way:form">${PI.remote}<b>Saisir les identifiants</b><small>Adresse du serveur et utilisateur Xtream, à la télécommande ou avec le clavier de l'iPhone.</small></div></div>
 <div class="pv-note">${PI.lock}Tes identifiants restent sur cette Apple TV (trousseau Apple) et ne sont envoyés qu'à ton fournisseur.</div>
 ${first&&!(typeof REAL!=="undefined"&&REAL)?`<div style="margin-top:14px"><span class="pv-lnk" data-f data-fid="pv-demo" data-act="pv:demo">Essayer d'abord avec les données de démonstration</span></div>`:""}`;
 if(p.way==="phone")return `<div style="display:flex;gap:40px;align-items:center;margin-top:10px">${qrH()}<div style="display:flex;flex-direction:column;gap:18px;min-width:0">
  <div style="font-size:26px;font-weight:800">Scanne ce code avec ton iPhone</div>
  <div class="pv-chk" style="font-size:18px;line-height:1.5"><div>1. Ouvre l'appareil photo et vise le code</div><div>2. Une page prisme s'ouvre sur ton iPhone</div><div>3. Colle le lien ou les identifiants, puis « Envoyer à la TV »</div></div>
  <div class="pv-cl run" style="background:rgba(255,255,255,.06)"><span class="d"></span>En attente de ton iPhone…<small>même Wi-Fi que l'Apple TV</small></div>
  <div class="pv-row"><span class="pv-btn" data-f data-fid="pv-ph-open" data-act="pv:phone" data-default>Ouvrir l'iPhone simulé</span><span class="pv-btn" data-f data-fid="pv-ph-back" data-act="pv:way:">Autre méthode</span></div></div></div>`;
 if(p.way==="link")return `<div style="display:flex;flex-direction:column;gap:18px;margin-top:6px"><div class="pv-mut" style="font-size:18px">Colle le lien reçu de ton fournisseur (⌘V), ou tape-le</div>
  <div class="pv-fld"><label for="pv-link">Lien</label><input class="pv-inp" id="pv-link" data-f data-fid="pv-link" data-pvin="link" data-pvgo="pv:linkgo" data-default value="${esc(p.link)}" placeholder="http://serveur.com:8080/get.php?username=…&amp;password=…" spellcheck="false" autocomplete="off"></div>
  <div id="pv-linkinfo">${linkInfo(p)}</div>
  <div class="pv-row"><span class="pv-btn pri ${linkReady(p)?"":"off"}" id="pv-lgo" data-f data-fid="pv-l-go" data-act="pv:linkgo">Continuer</span><span class="pv-btn" data-f data-fid="pv-l-back" data-act="pv:way:">Autre méthode</span></div></div>`;
 return `<div style="display:flex;flex-direction:column;gap:12px;margin-top:4px">
  <div class="pv-fld"><label for="pv-url">Adresse du serveur</label><input class="pv-inp" id="pv-url" data-f data-fid="pv-url" data-pvin="url" data-default value="${esc(p.url)}" placeholder="http://monserveur.com:8080" spellcheck="false" autocomplete="off"><span class="s ${urlOk(p.url)?"okc":"wrn"}" id="pv-urlchk">${esc(urlHint(p.url))}</span></div>
  <div class="pv-fld"><label for="pv-user">Utilisateur</label><input class="pv-inp" id="pv-user" data-f data-fid="pv-user" data-pvin="user" value="${esc(p.user)}" placeholder="ton identifiant" spellcheck="false" autocomplete="off"></div>
  <div class="pv-fld lk"><label>Mot de passe</label><span class="v">${PI.lock.replace('class="ic"','class="ic" style="width:16px;height:16px;vertical-align:-3px"')} demandé dans Terminal sur ton Mac (simulateur) · gardé dans le trousseau dans l'app</span></div>
  <div class="pv-fld"><label for="pv-name">Nom (facultatif)</label><input class="pv-inp" id="pv-name" data-f data-fid="pv-name" data-pvin="name" data-pvgo="pv:formgo" value="${esc(p.name)}" placeholder="${srvName(p.url)?"proposé : "+esc(srvName(p.url)):"ex. Lune"}" autocomplete="off"></div>
  <div class="pv-note" style="margin-top:2px">${PI.phone}Astuce : quand un champ est sélectionné, ton iPhone propose son clavier (notification « Clavier Apple TV »).</div>
  <div class="pv-row"><span class="pv-btn pri ${urlOk(p.url)&&p.user.trim()?"":"off"}" id="pv-fgo" data-f data-fid="pv-f-go" data-act="pv:formgo">Continuer</span><span class="pv-btn" data-f data-fid="pv-f-back" data-act="pv:way:">Autre méthode</span></div></div>`}
const linkReady=p=>{const q=parseLink(p.link);return !!(q&&q.user)};
function linkInfo(p){const q=parseLink(p.link);if(!q)return `<div class="pv-mut">prisme reconnaît les liens get.php, player_api.php, M3U et les liens de chaîne (…/live/utilisateur/mot-de-passe/…).</div>`;
 return `<div class="pv-chips"><span class="pv-chip okb">✓ Serveur ${esc(hostOf(q.url))}</span>${q.user?`<span class="pv-chip okb">✓ Utilisateur ${esc(q.user)}</span>`:'<span class="pv-chip">utilisateur manquant</span>'}${q.pass?'<span class="pv-chip okb">✓ Mot de passe trouvé · Terminal te le redemandera (simulateur)</span>':'<span class="pv-chip">mot de passe : demandé dans Terminal</span>'}<span class="pv-chip">${q.m3u?"lien M3U : prisme passera par l'accès Xtream, plus rapide":"accès Xtream"}</span></div>`}
/* ---------- vérification ---------- */
function checks(p){const an=p.an,A=an.acct||{},u=A.user_info||{},bad=String(u.auth)==="0";const L=[];
 L.push(["Serveur joignable",A.ms?`${nf(A.ms)} ms · Xtream Codes`:"listes reçues",an.acct?"ok":"ok"]);
 L.push([bad?"Identifiants refusés":"Identifiants acceptés",bad?"refusés par le serveur":"compte "+(u.username||p.user||"—"),bad?"bad":"ok"]);if(bad)return L;
 if(!an.acct)L.push(["Abonnement","bilan absent : relance la commande de la TV (compte.json)","warn"]);
 else{const st=String(u.status||"Active"),ex=+u.exp_date;let s,k="ok";
  if(!/active/i.test(st)){s={expired:"expiré",banned:"bloqué",disabled:"désactivé"}[st.toLowerCase()]||st;k="bad"}
  else if(ex){const d=Math.ceil((ex*1000-Date.now())/86400000);s=`jusqu'au ${new Date(ex*1000).toLocaleDateString("fr-FR",{day:"numeric",month:"long",year:"numeric"})} · ${d} jour${d>1?"s":""}`;if(d<=7)k="warn"}
  else s="sans date de fin";
  L.push(["Abonnement "+(k==="bad"?"inactif":"actif"),s+(String(u.is_trial)==="1"?" · essai":""),k]);
  const mx=+u.max_connections||0,ac=+u.active_cons||0;L.push(["Connexions",mx?`${mx} autorisée${mx>1?"s":""} · ${ac} utilisée${ac>1?"s":""} en ce moment`:"non indiqué",mx&&ac>=mx?"warn":"ok"])}
 L.push(["Guide TV",an.epg>2000?`fourni · ${(an.epg/1048576).toFixed(1).replace(".",",")} Mo de programmes`:"absent : la TV aura moins d'infos",an.epg>2000?"ok":"warn"]);
 L.push(["Replay",an.replay?`disponible sur ${nf(an.replay)} chaîne${an.replay>1?"s":""}`:"non indiqué par le fournisseur",an.replay?"ok":"warn"]);
 return L}
function s1(p){
 if(!p.an){const cmd=rCmd({name:pvName(p),url:normUrl(p.url),user:p.user.trim()});
  return `<div style="display:flex;gap:36px;margin-top:4px"><div class="pv-mac" style="flex:1 1 0;min-width:0">
  <div style="display:flex;align-items:center;gap:12px;font-size:24px;font-weight:800">${PI.mac}Sur ton Mac, une seule fois</div>
  <div class="pv-mut" style="font-size:15px;line-height:1.5">Le simulateur ne peut pas joindre ton serveur lui-même : la commande le fait sur ton Mac, sans ouvrir aucune chaîne. Elle est déjà remplie avec <b>${esc(hostOf(normUrl(p.url)))}</b> et <b>${esc(p.user.trim())}</b>, elle ne te demande que ton mot de passe.</div>
  <div class="pv-num"><i>1</i><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:8px">Copie la commande<div class="pv-code">${esc(cmd.slice(0,140))}…</div></div></div>
  <div class="pv-num"><i>2</i><div>Colle-la dans <b>Terminal</b>, appuie sur Entrée et tape ton mot de passe (il ne s'affiche pas). Elle crée le dossier <b>${esc(folder(p))}</b> sur ton Bureau.</div></div>
  <div class="pv-num"><i>3</i><div>Choisis ici <b>tous les fichiers</b> de ce dossier (⌘A dans la fenêtre de choix).</div></div>
  ${p.err?`<div class="pv-err">${esc(p.err)}</div>`:""}
  </div><div style="width:300px;display:flex;flex-direction:column;gap:14px;padding-top:54px">
  <span class="pv-btn pri" data-f data-fid="pv-copy" data-act="pv:copy" data-default>Copier la commande</span>
  <span class="pv-btn" data-f data-fid="pv-files" data-act="pv:files">Choisir les fichiers…</span>
  <div class="pv-mut" style="font-size:14px;line-height:1.5" id="pv-msg">${esc(p.msg||"")}</div></div></div>`}
 const L=checks(p),n=p.chk,doneAll=n>=L.length,bad=L.some(c=>c[2]==="bad"),T=p.an.T;
 return `<div style="display:flex;gap:40px;margin-top:6px"><div class="pv-chk" style="flex:1 1 0;min-width:0">${L.map((c,i)=>`<div class="pv-cl ${i<n?c[2]:i===n?"run":"wait"}"><span class="d">${i<n?(c[2]==="bad"?"✕":c[2]==="warn"?"!":"✓"):""}</span>${esc(c[0])}<small>${i<n?esc(c[1]):""}</small></div>`).join("")}</div>
 <div style="width:330px;display:flex;flex-direction:column;gap:14px">${doneAll?(bad?`<div class="pv-err">Le serveur refuse ce compte ou l'abonnement n'est plus actif. Vérifie l'utilisateur et le mot de passe, puis relance la commande.</div><span class="pv-btn pri" data-f data-fid="pv-redo" data-act="pv:redo" data-default>Recommencer</span>`:
  `<div class="pv-glass" style="border-radius:20px;padding:18px;display:flex;flex-direction:column;gap:8px"><div class="pv-k">Reçu de ton fournisseur</div><div style="font-size:15px;line-height:1.55">${TY.filter(t=>T[t]&&T[t].tot).map(t=>`<b>${nf(T[t].tot)}</b> ${TN[t][1]}`).join(" · ")||"aucun contenu"}</div>
   ${(+((p.an.acct||{}).user_info||{}).max_connections||0)===1?`<div style="font-size:14px;line-height:1.5" class="pv-mut">Ton abonnement n'autorise qu'<b style="color:#fff">une connexion à la fois</b> : prisme coupe les aperçus vidéo avant chaque lecture pour ne jamais te bloquer.</div>`:""}
   <div class="pv-mut" style="font-size:14px">prisme te préviendra 7 jours avant l'expiration.</div></div><span class="pv-btn pri" data-f data-fid="pv-c-go" data-act="pv:next" data-default>Continuer</span>`):
  `<div class="pv-mut" style="font-size:15px;line-height:1.5">prisme vérifie ton abonnement sans ouvrir aucune chaîne : ta connexion reste libre.</div>`}</div></div>`}
/* ---------- contenu ---------- */
const catsOf=(p,t)=>(p.an.T[t]&&p.an.T[t].cats)||[];
const tot=(p,t)=>catsOf(p,t).filter(c=>c.L.g!=="adult").reduce((a,c)=>a+c.n,0);
const kept=(p,t)=>catsOf(p,t).reduce((a,c)=>a+(c.on?c.n:0),0);
const keptN=(p,t)=>catsOf(p,t).filter(c=>c.on).length;
const dupN=(p,t)=>catsOf(p,t).reduce((a,c)=>a+(c.on?c.dup:0),0);
function s2(p){if(p.sub)return sCats(p);
 const row=t=>{const T=p.an.T[t],none=!T||!T.tot;return `<div class="pv-it" data-f data-fid="pv-k-${t}" ${none?"":`data-act="pv:keep:${t}"`} ${t==="live"?"data-default":""}><div class="tx"><b>${TN[t][0]}</b><small>${none?"rien reçu de ce fournisseur":`${nf(kept(p,t))} ${TN[t][1]} en français sur ${nf(tot(p,t))} · ${keptN(p,t)} catégorie${keptN(p,t)>1?"s":""}`}</small></div><span class="pv-sw ${p.keep[t]&&!none?"on":""}"><i></i></span></div>`};
 const chk=TY.reduce((a,t)=>a+catsOf(p,t).filter(c=>c.L.g==="chk").length,0),dups=TY.map(t=>p.keep[t]?[dupN(p,t),t]:[0,t]).filter(x=>x[0]);
 const others=typeof REAL!=="undefined"&&REAL?REAL.pls.map(x=>x.name):[];
 return `<div style="display:flex;gap:30px;margin-top:2px"><div style="flex:1 1 0;display:flex;flex-direction:column;gap:4px;min-width:0" data-col="0">
  <div class="pv-k" style="padding:0 16px 4px">Ce que prisme va importer</div>
  ${TY.map(row).join("")}
  <div class="pv-it" data-f data-fid="pv-k-cats" data-act="pv:cats"><div class="tx"><b>Catégories françaises</b><small>${chk?`${chk} catégorie${chk>1?"s":""} sans langue vérifiée${chk>1?"s":""} sur leurs titres · `:""}voir et ajuster</small></div><span class="val">${TY.reduce((a,t)=>a+keptN(p,t),0)} gardées ›</span></div>
  <div class="pv-it"><div class="tx"><b>Contenus pour adultes</b><small>jamais chargés</small></div><span class="val">toujours masqués 🔒</span></div>
  ${others.length?`<div class="pv-glass" style="border-radius:18px;padding:14px 18px;margin-top:6px;font-size:15px;line-height:1.5">${dups.length?`<b>${dups.map(([n,t])=>`${nf(n)} ${pl(n,TN[t][2],TN[t][1])}`).join(", ")} existe${dups.reduce((a,x)=>a+x[0],0)>1?"nt":""} déjà chez ${esc(others.join(" et "))}.</b> prisme les réunit : une seule fiche avec les deux sources, la meilleure d'abord, l'autre si la première coupe.`:`Aucun doublon avec ${esc(others.join(" et "))} : tout ce contenu est nouveau.`}</div>`:""}</div>
 <div style="width:360px;display:flex;flex-direction:column;gap:14px" data-col="1"><div class="pv-k">Nom et couleur</div>
  <div class="pv-fld" style="padding:4px 14px"><input class="pv-inp" id="pv-name2" data-f data-fid="pv-name2" data-pvin="name" value="${esc(p.name)}" placeholder="${esc(pvName(p))}" autocomplete="off" style="font-size:20px"></div>
  <div style="display:flex;gap:12px;padding:4px 2px">${PVCOL.map((c,i)=>`<span class="pv-col ${i===p.col?"sel":""}" data-f data-fid="pv-col-${i}" data-act="pv:col:${i}" style="background:${c}" title="couleur ${i+1}"></span>`).join("")}</div>
  <div class="pv-mut" style="font-size:14px;line-height:1.45">La couleur repère ce fournisseur dans les réglages et les sources.</div>
  <span class="pv-btn pri" data-f data-fid="pv-imp" data-act="pv:import" style="align-self:flex-start;margin-top:10px">Importer</span></div></div>`}
function sCats(p){const t=p.ct,C=catsOf(p,t),G=[["fr","Françaises","reconnues à leur nom"],["fo","Francophones","Belgique, Québec, Suisse, Afrique : à ton choix"],["chk","À vérifier","pas de langue dans le nom : prisme a regardé les titres"],["xx","Autres langues","ignorées, tu peux en ajouter une"]];
 const item=(c,i)=>`<div class="pv-it" data-f data-fid="pv-c-${t}-${i}" data-act="pv:cat:${t}:${i}"><span class="pv-sw ${c.on?"on":""}"><i></i></span><div class="tx"><b>${esc(c.name)}</b><small>${nf(c.n)} ${pl(c.n,TN[t][2],TN[t][1])} · ${esc(c.L.why)}</small></div>${c.L.g==="chk"?`<span class="pv-pc"><i style="width:${c.L.pct}%"></i></span>`:""}</div>`;
 let L="";for(const [g,h,d] of G){const I=C.map((c,i)=>[c,i]).filter(([c])=>c.L.g===g);if(!I.length)continue;
  L+=`<div class="pv-gh"><b>${h}</b> <span>${I.length}</span><small>${d}</small></div>`;
  if(g==="xx"&&!p.showX){L+=`<div class="pv-it" data-f data-fid="pv-c-showx" data-act="pv:showx"><div class="tx"><b>Afficher les ${I.length} catégories ignorées</b><small>${I.slice(0,4).map(([c])=>esc(c.name)).join(" · ")}${I.length>4?"…":""}</small></div><span class="val">›</span></div>`;continue}
  L+=I.map(([c,i])=>item(c,i)).join("")}
 const ad=C.filter(c=>c.L.g==="adult").length;if(ad)L+=`<div class="pv-gh"><b>Adultes</b> <span>${ad}</span><small>jamais chargées, même si tu changes les réglages ici</small></div>`;
 if(!C.length)L=`<div class="pv-mut" style="padding:20px 16px">Rien reçu de ce fournisseur pour ${TN[t][0].toLowerCase()}.</div>`;
 return `<div style="display:flex;gap:30px;height:100%"><div style="flex:1 1 0;display:flex;flex-direction:column;gap:12px;min-height:0;min-width:0" data-col="0">
  <div class="pv-chips">${TY.map(k=>`<span class="pv-chip tab ${k===t?"sel":""}" data-f data-fid="pv-ct-${k}" data-act="pv:ct:${k}" ${k===t?"data-default":""}>${TN[k][0]} · ${keptN(p,k)}</span>`).join("")}</div>
  <div class="pv-sy sy" id="pv-clist" style="flex:1 1 auto;min-height:0;padding:3px;margin:-3px">${L}</div></div>
 <div style="width:330px;display:flex;flex-direction:column;gap:14px" data-col="1"><div class="pv-glass" style="border-radius:20px;padding:18px;display:flex;flex-direction:column;gap:6px"><div class="pv-k">${TN[t][0]}</div><div style="font-size:30px;font-weight:800">${nf(kept(p,t))} <span style="font-size:16px;font-weight:600">${TN[t][1]}</span></div><div class="pv-mut" style="font-size:14px">${keptN(p,t)} catégories gardées sur ${C.length} · ${nf(tot(p,t))} ${TN[t][1]} au total</div></div>
  <div class="pv-mut" style="font-size:14px;line-height:1.5">Comment prisme trie : un repère FR, VF, VFF, VFQ, VOSTFR ou TRUEFRENCH dans le nom, un nom écrit en français, sinon les titres de la catégorie. « AFRICA » ou « FRIENDS » ne passent pas pour du français.</div>
  <span class="pv-btn pri" data-f data-fid="pv-cv-ok" data-act="pv:catsok" style="align-self:flex-start">Valider</span><span class="pv-btn" data-f data-fid="pv-cv-rs" data-act="pv:catsrs" style="align-self:flex-start">Revenir au choix de prisme</span></div></div>`}
/* ---------- importation ---------- */
const PH=[["live","Chaînes"],["vod","Films"],["ser","Séries"],["epg","Guide TV"],["save","Enregistrement"]];
function phases(p){return PH.filter(([k])=>k==="save"||(k==="epg"?p.keep.live&&p.an.epg>2000&&keptN(p,"live"):p.keep[k]&&keptN(p,k)))}
function s3(p){const L=phases(p),r=p.res||{};
 const lbl={live:p.done?`${nf(r.chans||0)} flux de chaînes`:`${nf(kept(p,"live"))} chaînes`,vod:p.done?`${nf(r.films||0)} films`:`${nf(kept(p,"vod"))} films`,ser:p.done?`${nf(r.series||0)} séries`:`${nf(kept(p,"ser"))} séries`,epg:p.done&&r.epg?`${nf(r.epg)} programmes`:"programmes",save:"dans ce navigateur"};
 const bar=([k,n])=>{const v=Math.round(p.imp[k]||0);return `<div class="pv-bar"><div class="h"><span>${n}</span><span class="pv-mut" id="pv-bt-${k}">${v>=100?"✓ "+lbl[k]:v?v+" %":"en attente"}</span></div><div class="t"><i id="pv-bi-${k}" style="width:${v}%"></i></div></div>`};
 return `<div style="display:flex;gap:40px;margin-top:10px"><div class="pv-bars" style="flex:1 1 0;min-width:0">${L.map(bar).join("")}
  <div class="pv-mut" style="font-size:14px;line-height:1.5;min-height:42px" id="pv-imsg">${esc(p.err?"":p.msg||"")}</div>
  ${p.err?`<div class="pv-err">Import impossible : ${esc(p.err)}</div>`:""}</div>
  <div style="width:340px;display:flex;flex-direction:column;gap:14px">${p.done?`<span class="pv-btn pri" data-f data-fid="pv-i-tv" data-act="pv:end:live" data-default>Regarder la TV maintenant</span><span class="pv-btn" data-f data-fid="pv-i-end" data-act="pv:end:settings">Terminer</span>
   <div class="pv-glass" style="border-radius:18px;padding:16px;font-size:15px;line-height:1.5"><b>${esc(pvName(p))} est prêt.</b><br>${(typeof REAL!=="undefined"&&REAL)?"Tes catalogues sont fusionnés. ":""}Ensuite, pour les affiches et les fiches complètes, lance les commandes TMDB sous la télécommande.${(r.keptF<r.totF)?`<br><span class="pv-mut">${nf(r.keptF)} films les plus récents gardés sur ${nf(r.totF)} (mémoire du navigateur).</span>`:""}</div>`
  :p.err?`<span class="pv-btn pri" data-f data-fid="pv-i-back" data-act="pv:impback" data-default>Revenir au contenu</span>`:`<span class="pv-btn off">La TV arrive…</span><div class="pv-mut" style="font-size:14px;line-height:1.5">Dans l'app, l'importation continue en arrière-plan : la TV est utilisable dès que les chaînes sont prêtes.</div>`}</div></div>`}
function pvDraw(){const p=S.pv;if(!p||p.step!==3)return;for(const [k] of PH){const b=document.getElementById("pv-bi-"+k),t=document.getElementById("pv-bt-"+k),v=Math.round(p.imp[k]||0);if(b)b.style.width=v+"%";if(t&&v<100)t.textContent=v?v+" %":"en attente"}const m=document.getElementById("pv-imsg");if(m)m.textContent=p.msg||""}
/* ---------- rendu ---------- */
function pvHtml(){const p=PV();const T=S.playlists.length?"Ajouter un fournisseur":"Bienvenue sur prisme";
 return `<div class="pv"><div class="pv-top"><h1>${T}</h1>${stepsH(p)}</div><div class="pv-body">${[s0,s1,s2,s3][p.step](p)}</div></div>`}
function bind(){view.querySelectorAll("[data-pvin]").forEach(inp=>{if(inp.dataset.pvgo)inp.onkeydown=e=>{if(e.key!=="Enter")return;e.preventDefault();e.stopPropagation();act(inp.dataset.pvgo)};inp.oninput=()=>{const p=PV(),k=inp.dataset.pvin;p[k]=inp.value;
  if(k==="link"){const i=$("#pv-linkinfo");if(i)i.innerHTML=linkInfo(p);const b=$("#pv-lgo");if(b)b.classList.toggle("off",!linkReady(p))}
  if(k==="url"){const c=$("#pv-urlchk");if(c){c.textContent=urlHint(p.url);c.className="s "+(urlOk(p.url)?"okc":"wrn")}const n=$("#pv-name");if(n)n.placeholder=srvName(p.url)?"proposé : "+srvName(p.url):"ex. Lune"}
  if(k==="url"||k==="user"){const b=$("#pv-fgo");if(b)b.classList.toggle("off",!(urlOk(p.url)&&p.user.trim()))}}})}
/* ---------- fichiers du dossier ---------- */
async function analyze(all){const by={};
 for(const f of all){const n=f.name.toLowerCase();if(/^compte.*\.json$/.test(n))by.acct=f;else if(/xmltv|epg|\.xml$|\.gz$/.test(n))by.epg=f;else for(const k of ["get_live_categories","get_live_streams","get_vod_categories","get_vod_streams","get_series_categories","get_series"])if(n.startsWith(k+".")||n===k+".json"||n.startsWith(k+" "))by[k]=f}
 if(!by.get_live_streams&&!by.get_vod_streams&&!by.get_series)throw new Error("Je ne trouve pas get_live_streams.json, get_vod_streams.json ou get_series.json. Choisis tous les fichiers du dossier "+folder(PV())+" (⌘A).");
 let acct=null;if(by.acct){try{acct=JSON.parse((await by.acct.text()).replace(/^\uFEFF/,""))}catch(e){}}
 const R=typeof REAL!=="undefined"&&REAL,oc=new Set(R?R.chans.map(c=>c.k):[]),of=new Set(R?R.films.map(c=>c.k):[]),os=new Set(R?R.series.map(c=>c.k):[]);
 const K={live:x=>oc.has(RI.strip(RI.base(x.name||""))),vod:x=>{const t=RI.title(x.name||"");return of.has(RI.strip(t)+"#"+((+x.year||RI.year(x.name))||""))},ser:x=>os.has(RI.strip(RI.title(x.name||"")))};
 const T={};let replay=0;
 for(const [t,cf,sf] of [["live","get_live_categories","get_live_streams"],["vod","get_vod_categories","get_vod_streams"],["ser","get_series_categories","get_series"]]){
  const L=by[sf]?await rReadJson(by[sf],true):null;if(!Array.isArray(L)||!L.length){T[t]={cats:[],tot:0};continue}
  const C=by[cf]?await rReadJson(by[cf],true):null,g={};for(const x of L){const id=String(x.category_id??"");(g[id]=g[id]||[]).push(x)}
  if(t==="live")replay=L.filter(x=>String(x.tv_archive)==="1").length;
  let cats=(Array.isArray(C)?C:[]).map(c=>({id:String(c.category_id),name:String(c.category_name||"Sans nom"),it:g[String(c.category_id)]||[]}));
  if(!cats.length)cats=[{id:"*",name:"Toutes les "+TN[t][1],it:L}];
  for(const c of cats){c.n=c.it.length;c.L=RL.of(c.name,c.it,t);c.dup=R?c.it.reduce((a,x)=>a+(K[t](x)?1:0),0):0;c.on=c.L.g!=="adult"&&RL.on(c.L,c.name);c.def=c.on;delete c.it}
  T[t]={cats,tot:cats.filter(c=>c.L.g!=="adult").reduce((a,c)=>a+c.n,0)}}
 return {acct,T,epg:by.epg?by.epg.size:0,replay}}
window.pvFiles=function(all){const p=S.pv;if(!p||inApp()||p.step!==1)return false;p.err="";p.msg="Lecture des fichiers…";p.files=all;render("pv-files");
 analyze(all).then(an=>{p.an=an;p.chk=0;p.msg="";for(const t of TY)if(!an.T[t].tot)p.keep[t]=0;
  if(!p.name.trim()&&an.acct&&an.acct.host&&!p.url)p.url=an.acct.host;render();clearInterval(p.ct0);
  p.ct0=setInterval(()=>{if(S.pv!==p||p.step!==1){clearInterval(p.ct0);return}p.chk++;render(p.chk>=checks(p).length?null:F&&F.dataset.fid);if(p.chk>=checks(p).length)clearInterval(p.ct0)},550)})
 .catch(e=>{p.err=e.message;p.msg="";p.files=null;render("pv-files")});return true};
async function runImport(){const p=PV();p.step=3;p.imp={};p.msg="";p.done=false;p.err="";p.res=null;render();
 const sel={};for(const t of TY)sel[t]=new Set(p.keep[t]?catsOf(p,t).filter(c=>c.on).map(c=>c.id):[]);
 const u=((p.an.acct||{}).user_info)||{};const info={col:PVCOL[p.col],exp:+u.exp_date?+u.exp_date*1000:null,max:+u.max_connections||null,host:hostOf(normUrl(p.url||(p.an.acct||{}).host||"")),user:u.username||p.user.trim()};
 let cur=null;const ph=k=>{if(cur)p.imp[cur]=100;cur=k;p.imp[k]=6;render(F&&F.dataset.fid)};
 const tk=setInterval(()=>{if(cur&&p.imp[cur]<93){p.imp[cur]+=3+Math.random()*7;pvDraw()}},180);
 try{RWARN.length=0;const r=await rImport(p.files,pvName(p),m=>{p.msg=m;pvDraw()},{sel,ph,info});if(cur)p.imp[cur]=100;
  const x=await rImportExtras(p.files,m=>{p.msg=m;pvDraw()});
  const R=JSON.parse(localStorage.getItem("prisme-real"));S.playlists=rPlaylists(R);S.adding=true;S.stack=[{t:"home"}];
  try{localStorage.removeItem("prisme-atv-live")}catch(_){}
  p.res=r;p.done=true;p.msg=`${r.arch?`Replay : ${nf(r.arch)} flux de chaînes l'acceptent. `:""}${x.nx?`Fiche technique de ${nf(x.nx)} flux. `:""}${x.nep?`Épisodes de ${nf(x.nep)} séries. `:""}${RWARN.length?"Attention : "+RWARN.join(" · "):""}`}
 catch(e){p.err=e.message}
 clearInterval(tk);render()}
function finish(where){S.adding=false;S.pv=null;S.tab=where==="live"?"live":"settings";S.stack=[{t:"home"}];save();try{sessionStorage.setItem("prisme-scat",where==="live"?"":"acc")}catch(_){}location.reload()}
/* ---------- iPhone simulé (le QR code) ---------- */
function phone(){if(document.querySelector(".pvphone-ov"))return;const ov=document.createElement("div");ov.className="pvphone-ov";
 ov.innerHTML=`<div class="pvphone" role="dialog" aria-modal="true" aria-label="iPhone simulé">
 <h3>Ajouter à prisme</h3><p>Page ouverte en scannant le code de la TV. Ce que tu saisis part directement à ton Apple TV, sur le même Wi-Fi.</p>
 <div class="seg2"><button type="button" data-m="link" aria-pressed="true">Coller un lien</button><button type="button" data-m="id" aria-pressed="false">Identifiants</button></div>
 <div data-p="link" style="display:flex;flex-direction:column;gap:6px"><label for="pvph-link">Lien du fournisseur</label><textarea id="pvph-link" placeholder="http://…/get.php?username=…&password=…" spellcheck="false"></textarea><div class="ok" id="pvph-ok" hidden></div></div>
 <div data-p="id" style="display:none;flex-direction:column;gap:6px"><label for="pvph-url">Serveur</label><input id="pvph-url" placeholder="http://monserveur.com:8080" spellcheck="false" autocomplete="off"><label for="pvph-user">Utilisateur</label><input id="pvph-user" autocomplete="off" spellcheck="false"><label for="pvph-name">Nom (facultatif)</label><input id="pvph-name" autocomplete="off"></div>
 <p>Simulateur : ton mot de passe sera demandé dans Terminal sur ton Mac. Dans l'app, il est envoyé à la TV et gardé dans le trousseau Apple.</p>
 <button type="button" class="go" disabled>Envoyer à la TV</button><button type="button" class="cx">Annuler</button></div>`;
 document.body.appendChild(ov);let mode="link";const q=s=>ov.querySelector(s),go=q(".go");
 const upd=()=>{if(mode==="link"){const r=parseLink(q("#pvph-link").value),ok=q("#pvph-ok");ok.hidden=!r;if(r)ok.textContent=`✓ ${hostOf(r.url)}${r.user?" · "+r.user:" · utilisateur manquant"}`;go.disabled=!(r&&r.user)}else go.disabled=!(urlOk(q("#pvph-url").value)&&q("#pvph-user").value.trim())};
 ov.addEventListener("keydown",e=>{e.stopPropagation();if(e.key==="Escape")close()});ov.addEventListener("input",upd);
 ov.querySelectorAll(".seg2 button").forEach(b=>b.addEventListener("click",()=>{mode=b.dataset.m;ov.querySelectorAll(".seg2 button").forEach(x=>x.setAttribute("aria-pressed",x===b));q('[data-p="link"]').style.display=mode==="link"?"flex":"none";q('[data-p="id"]').style.display=mode==="id"?"flex":"none";upd();(mode==="link"?q("#pvph-link"):q("#pvph-url")).focus()}));
 const close=()=>{ov.remove();render("pv-ph-open")};
 q(".cx").addEventListener("click",close);ov.addEventListener("click",e=>{if(e.target===ov)close()});
 go.addEventListener("click",()=>{const p=PV();if(mode==="link"){const r=parseLink(q("#pvph-link").value);if(!r||!r.user)return;p.url=r.url;p.user=r.user}else{p.url=normUrl(q("#pvph-url").value);p.user=q("#pvph-user").value.trim();p.name=q("#pvph-name").value.trim()}
  ov.remove();p.step=1;p.an=null;p.err="";toast("Reçu de ton iPhone · "+hostOf(p.url)+" · "+p.user);render()});
 setTimeout(()=>q("#pvph-link").focus(),30)}
/* ---------- actions ---------- */
function pvAct(v,w,x){const p=PV();
 switch(v){
 case "way":p.way=w||null;return render(w?null:"pv-w-"+(p.lastWay||"phone"));
 case "phone":return phone();
 case "demo":S.pv=null;S.form={name:"Démo",url:"http://demo.prisme.tv:8080",user:"demo",pass:"demo",epg:true};return doLogin();
 case "linkgo":{const q=parseLink(p.link);if(!q||!q.user)return toast("Il manque l'utilisateur dans ce lien");p.url=q.url;p.user=q.user;p.lastWay="link";p.step=1;p.an=null;p.err="";return render()}
 case "formgo":if(!urlOk(p.url))return toast(p.url?"L'adresse du serveur semble incomplète":"Saisis l'adresse du serveur");if(!p.user.trim())return toast("Saisis l'utilisateur");p.url=normUrl(p.url);p.lastWay="form";p.step=1;p.an=null;p.err="";return render();
 case "copy":rCopy(null,rCmd({name:pvName(p),url:normUrl(p.url),user:p.user.trim()})).then(ok=>{p.msg=ok?"Commande copiée : colle-la dans Terminal.":"Copie impossible : sélectionne la commande à la main.";const m=$("#pv-msg");if(m)m.textContent=p.msg;if(ok)toast("Commande copiée")});return;
 case "files":{const i=$("#rfiles");if(i)i.click();return}
 case "redo":p.an=null;p.files=null;p.chk=0;return render("pv-copy");
 case "next":p.step=2;p.sub=0;return render();
 case "keep":p.keep[w]=p.keep[w]?0:1;return render("pv-k-"+w);
 case "cats":p.sub=1;p.ct=TY.find(t=>catsOf(p,t).length)||"live";p.showX=0;return render();
 case "ct":p.ct=w;p.showX=0;render("pv-ct-"+w);{const l=$("#pv-clist");if(l)l.scrollTop=0}return;
 case "cat":{const c=catsOf(p,w)[+x];if(c){c.on=!c.on;if(c.on)p.keep[w]=1}return render(`pv-c-${w}-${x}`)}
 case "showx":{p.showX=1;const i=catsOf(p,p.ct).findIndex(c=>c.L.g==="xx");return render(`pv-c-${p.ct}-${i}`)}
 case "catsok":p.sub=0;return render("pv-k-cats");
 case "catsrs":for(const t of TY)catsOf(p,t).forEach(c=>c.on=c.def);render(F&&F.dataset.fid);return toast("Choix de prisme rétabli");
 case "col":p.col=+w;return render("pv-col-"+w);
 case "import":if(!TY.some(t=>p.keep[t]&&keptN(p,t)))return toast("Garde au moins une catégorie à importer");return runImport();
 case "impback":p.step=2;p.err="";return render("pv-imp");
 case "end":return finish(w);
 }}
function pvBack(){const p=PV();
 if(document.querySelector(".pvphone-ov"))return;
 if(p.step===3){if(p.done)return finish("settings");if(p.err){p.step=2;p.err="";return render("pv-imp")}return toast("Importation en cours…")}
 if(p.step===2&&p.sub){p.sub=0;return render("pv-k-cats")}
 if(p.step===2){p.step=1;return render()}
 if(p.step===1){clearInterval(p.ct0);p.step=0;p.an=null;p.files=null;p.chk=0;p.err="";p.msg="";if(!p.way)p.way=p.lastWay||"form";return render()}
 if(p.way){const w=p.way;p.way=null;return render("pv-w-"+w)}
 if(S.playlists.length){S.adding=false;S.pv=null;if(window.SA)SA.cat="acc";return render("set-add")}
 toast("Ajoute un fournisseur pour commencer")}
/* ---------- branchement dans le simulateur ---------- */
loginHtml=function(){return pvHtml()};
{const _a=act;act=function(a){if(a&&a.startsWith("pv:")){const [,v,w,x]=a.split(":");return pvAct(v,w,x)}if(a==="addpl"){S.pv=null;S.adding=true;return render()}return _a(a)}}
{const _b=back;back=function(){if(!inApp()&&!S.loading)return pvBack();return _b()}}
{const _r=render;render=function(f){_r(f);if(!inApp()&&!S.loading)bind()}}
/* rappel 7 jours avant l'expiration d'un abonnement (une fois par jour) */
if(typeof REAL!=="undefined"&&REAL)setTimeout(()=>{if(!inApp())return;const today=new Date().toDateString();let seen="";try{seen=localStorage.getItem("prisme-exp-rem")||""}catch(_){}if(seen===today)return;
 for(const x of REAL.pls){if(!x.exp)continue;const d=Math.ceil((x.exp-Date.now())/86400000);if(d<0){toast(`Abonnement ${x.name} expiré : renouvelle-le chez ton fournisseur`);break}if(d<=7){toast(`Abonnement ${x.name} : plus que ${d} jour${d>1?"s":""} avant l'expiration`);break}}
 try{localStorage.setItem("prisme-exp-rem",today)}catch(_){}},3500);
window.__pv={parseLink,analyze,checks,pvHtml,normUrl,urlOk,srvName};
})();
