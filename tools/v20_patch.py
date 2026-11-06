# Version 2.0 : branchement de l'interface native (films et séries). Exécuté par build_ui.py après v13_patch.py.
_nat = open(os.path.join(D, "native_api.js"), encoding="utf-8").read()
assert js.rstrip().endswith("boot();"), js[-40:]
js = js.rstrip()[:-len("boot();")] + _nat + "\nboot();\n"

# lecteur : nouvel essai, changement de source automatique
R('P.nst=st;\n', 'P.nst=st;if(natTick(st))return;\n')
# retour depuis le lecteur ou une page web ouverte depuis le natif
R(' const t=topS();\n if(t.t==="player"){stopPlayer()}',
  ''' const t=topS();
 if(t.t==="player"&&P&&P.nat){stopPlayer();S.stack.pop();natShow("");return}
 if(S.retNat&&t.t!=="player"&&S.stack.length<=2&&natOn()){S.retNat=false;S.stack=[{t:"home"}];natShow("");return}
 if(t.t==="player"){stopPlayer()}''')
# dernier épisode vu (reprise des séries)
R('function stopPlayer(){clearInterval(PT);',
  'function stopPlayer(){clearInterval(PT);NAT.pre=null;if(P&&P.kind==="vod"&&ALL[P.id]&&ALL[P.id].type==="s"&&P.dur>0&&P.ss){S.lastEp=S.lastEp||{};S.lastEp[P.id]={ss:P.ss,ep:P.ep,pct:P.pos/P.dur}}')
R('seasons:S.seasons,', 'seasons:S.seasons,lastEp:S.lastEp,')
# onglets Films / Séries et ouverture d'une fiche : interface native
R('if(k==="tab"){if(S.tab!==v){S.tab=v;save();render("tab-"+v)}return}',
  'if(k==="tab"){if(natOn()&&(v==="films"||v==="series")){S.tab=v;save();natShow(v);return}if(S.tab!==v){S.tab=v;save();render("tab-"+v)}return}')
R('  case "open": push({t:"detail",id:v});break;',
  '  case "open": if(natOn()&&ALL[v]){NAT.vis=true;Prisme.nativeOpen(v);break}push({t:"detail",id:v});break;')
R(' bgFor(t);\n afterRender(t,fid);\n}',
  ' bgFor(t);\n afterRender(t,fid);\n if(natOn()&&!NAT.vis&&!S.booting&&!S.modal&&t.t==="home"&&(S.tab==="films"||S.tab==="series"))natShow(S.tab);\n}')
# données → fiche native
R(' it.loading=false;\n', ' it.loading=false;natPush(it.id);if((it.g||[]).length)natGenreBump();if(!it.s||!it.bd)tmdbFill(it);\n')
R('function refreshQual(){', 'function refreshQual(){natPush(NAT.detail);')
R('if(url)paintPhoto(n,url)}', 'if(url){paintPhoto(n,url);natPush(NAT.detail)}}')
R('if(P){setTimeout(pumpProbe,3000);return}', 'if(P||NAT.pre){setTimeout(pumpProbe,3000);return}')
R(' if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;\n}', ' if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;\n if(NAT.vis)setTimeout(()=>Prisme.nativeEvent("catalog",""),50);\n setTimeout(()=>{if(typeof tgRun==="function")tgRun()},30000);\n}')
# réglage : revenir à l'ancienne interface
R('<div class="it tall" data-f data-fid="set-lite" data-act="set:lite">',
  '<div class="it tall" data-f data-fid="set-probe" data-act="set:probe"><span>Analyser les flux avant la lecture<small>Mesure la qualité réelle (4K, 1080p…) · ouvre une connexion chez le fournisseur : à éviter avec un abonnement 1 écran</small></span>${sw(st.probe)}</div>\n  <div class="it tall" data-f data-fid="set-preload" data-act="set:preload"><span>Préchargement depuis la fiche<small>Démarrage plus rapide · ouvre une connexion à l\'avance</small></span>${sw(st.preload)}</div>\n  ${NAT.ok?`<div class="it tall" data-f data-fid="set-legacy" data-act="set:legacy"><span>Ancienne interface pour les films et séries<small>À activer seulement en cas de problème avec la nouvelle interface</small></span>${sw(st.legacy)}</div>`:""}\n  <div class="it tall" data-f data-fid="set-lite" data-act="set:lite">')

# une seule connexion chez le fournisseur : la lecture attend la fin d'une analyse de flux en cours
R('if(NATIVE){const u=streamUrl();if(!u){toast("Flux introuvable");return}Prisme.play(u,Math.round((p.pos||0)*1000),p.kind==="live");Prisme.setFormat(curFmt()[0])}}',
  'if(NATIVE){const u=streamUrl();if(!u){toast("Flux introuvable");return}PQ.splice(0).forEach(([k])=>{if(QPEND[k]==="probe")delete QPEND[k]});'
  'const go=()=>{if(P!==p||p.go)return;p.go=1;p.t0=Date.now();Prisme.play(u,Math.round((p.pos||0)*1000),p.kind==="live");Prisme.setFormat(curFmt()[0])};'
  'if(Prisme.probeBusy()){LOG("Lecture en attente de la fin d\'une analyse de flux");const w0=Date.now(),wt=setInterval(()=>{if(P!==p||!Prisme.probeBusy()||Date.now()-w0>26000){clearInterval(wt);go()}},300)}else go()}}')

# Diagnostic : état du compte chez le fournisseur (expiration, connexions en cours) et test d'un flux
R('function diagHtml(){', '''const DIAGA={};let DIAGT="";
async function diagAcct(){for(const p of S.playlists){try{const r=await getJSON(api(p,""),15000)||{};DIAGA[p.id]=r.user_info||{err:"réponse sans infos de compte"}}catch(e){DIAGA[p.id]={err:e.message}}}
 if(topS().t==="diag")render(F&&F.dataset.fid)}
async function diagTest(){const id=Object.keys(S.prog).reverse().find(k=>ALL[k]&&ALL[k].type==="f")||(films()[0]||{}).id;const it=ALL[id];if(!it){DIAGT="Aucun film à tester";render(F&&F.dataset.fid);return}
 const v=pickSrc(id);if(!v){DIAGT="Aucune source";render(F&&F.dataset.fid);return}
 const s=v.p,u=`${clean(s.url)}/movie/${encodeURIComponent(s.user)}/${encodeURIComponent(s.pass)}/${v.sid}.${v.ext}`;
 DIAGT="Test en cours…";render(F&&F.dataset.fid);
 const ctl=new AbortController(),t=setTimeout(()=>ctl.abort(),12000),t0=Date.now();
 try{const r=await fetch(proxied(u),{signal:ctl.signal});DIAGT=`${it.t} : réponse ${r.status} ${r.status===200||r.status===206?"(flux accessible)":r.status===502?"(redirection ou serveur injoignable)":"(refusé par le fournisseur)"} en ${((Date.now()-t0)/1000).toFixed(1)} s`;ctl.abort()}
 catch(e){DIAGT=`${it.t} : ${e.name==="AbortError"?"pas de réponse en 12 s":e.message}`}
 clearTimeout(t);LOG("Test de flux · "+DIAGT);if(topS().t==="diag")render(F&&F.dataset.fid)}
function diagHtml(){if(!Object.keys(DIAGA).length&&S.playlists.length){DIAGA._=1;setTimeout(diagAcct,50)}''')
R('''  ${it("dg-q",`Analyse de la qualité vidéo''', '''  ${S.playlists.map(p=>{const u=DIAGA[p.id];if(!u)return it("dg-a"+p.id,`Compte ${esc(p.name)}<small>vérification…</small>`,"");if(u.err)return it("dg-a"+p.id,`Compte ${esc(p.name)}<small>${esc(u.err)}</small>`,"injoignable");
   const exp=+u.exp_date?new Date(+u.exp_date*1000).toLocaleDateString("fr-FR"):"illimité";
   return it("dg-a"+p.id,`Compte ${esc(p.name)}<small>Statut : ${esc(u.status||"?")} · expire le ${exp} · connexions en cours ${esc(String(u.active_cons??"?"))} sur ${esc(String(u.max_connections??"?"))}</small>`,u.status==="Active"?"actif":esc(u.status||"?"))}).join("")}
  <div class="it tall" data-f data-fid="dg-test" data-act="diag:test"><span>Tester un flux de film<small>${esc(DIAGT||"Vérifie si le fournisseur accepte la connexion (ouvre une connexion quelques secondes)")}</small></span><span>›</span></div>
  ${it("dg-q",`Analyse de la qualité vidéo''')
R('''   else if(v==="ref")render(F&&F.dataset.fid);''','''   else if(v==="ref"){Object.keys(DIAGA).forEach(k=>delete DIAGA[k]);render(F&&F.dataset.fid)}
   else if(v==="test")diagTest();''')

# À propos : mention TMDB ; Diagnostic : avancement du rangement des genres
R('  <div class="it tall"><span>Canal de mise à jour<small>',
  '  <div class="it tall"><span>Données de films et séries<small>Ce produit utilise l\'API TMDB mais n\'est ni approuvé ni certifié par TMDB</small></span><span>TMDB</span></div>\n  <div class="it tall"><span>Canal de mise à jour<small>')
R('  ${it("dg-q",`Analyse de la qualité vidéo',
  '  ${it("dg-tg",`Genres TMDB<small>${S.set.tmdbKey?`${Object.keys(TG).length} titres vérifiés · ${Object.values(TG).filter(v=>v[0]!=="-").length} classés${TGS.run?` · en cours (${TGS.done} sur ${TGS.todo})`:""}`:"clé TMDB absente"}</small>`,S.set.tmdbBuiltin?"clé intégrée":S.set.tmdbKey?"clé saisie":"")}\n  ${it("dg-q",`Analyse de la qualité vidéo')
