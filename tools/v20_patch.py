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
R(' it.loading=false;\n', ' it.loading=false;natPush(it.id);if((it.g||[]).length)natGenreBump();\n')
R('function refreshQual(){', 'function refreshQual(){natPush(NAT.detail);')
R('if(url)paintPhoto(n,url)}', 'if(url){paintPhoto(n,url);natPush(NAT.detail)}}')
R('if(P){setTimeout(pumpProbe,3000);return}', 'if(P||NAT.pre){setTimeout(pumpProbe,3000);return}')
R(' if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;\n}', ' if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;\n if(NAT.vis)setTimeout(()=>Prisme.nativeEvent("catalog",""),50);\n}')
# réglage : revenir à l'ancienne interface
R('<div class="it tall" data-f data-fid="set-lite" data-act="set:lite">',
  '<div class="it tall" data-f data-fid="set-probe" data-act="set:probe"><span>Analyser les flux avant la lecture<small>Mesure la qualité réelle (4K, 1080p…) · ouvre une connexion chez le fournisseur : à éviter avec un abonnement 1 écran</small></span>${sw(st.probe)}</div>\n  <div class="it tall" data-f data-fid="set-preload" data-act="set:preload"><span>Préchargement depuis la fiche<small>Démarrage plus rapide · ouvre une connexion à l\'avance</small></span>${sw(st.preload)}</div>\n  ${NAT.ok?`<div class="it tall" data-f data-fid="set-legacy" data-act="set:legacy"><span>Ancienne interface pour les films et séries<small>À activer seulement en cas de problème avec la nouvelle interface</small></span>${sw(st.legacy)}</div>`:""}\n  <div class="it tall" data-f data-fid="set-lite" data-act="set:lite">')

# une seule connexion chez le fournisseur : la lecture attend la fin d'une analyse de flux en cours
R('if(NATIVE){const u=streamUrl();if(!u){toast("Flux introuvable");return}Prisme.play(u,Math.round((p.pos||0)*1000),p.kind==="live");Prisme.setFormat(curFmt()[0])}}',
  'if(NATIVE){const u=streamUrl();if(!u){toast("Flux introuvable");return}PQ.splice(0).forEach(([k])=>{if(QPEND[k]==="probe")delete QPEND[k]});'
  'const go=()=>{if(P!==p||p.go)return;p.go=1;p.t0=Date.now();Prisme.play(u,Math.round((p.pos||0)*1000),p.kind==="live");Prisme.setFormat(curFmt()[0])};'
  'if(Prisme.probeBusy()){LOG("Lecture en attente de la fin d\'une analyse de flux");const w0=Date.now(),wt=setInterval(()=>{if(P!==p||!Prisme.probeBusy()||Date.now()-w0>26000){clearInterval(wt);go()}},300)}else go()}}')
