# Optimisations pour Fire TV Stick 3e génération (1 Go de RAM, GPU modeste). Exécuté par build_ui.py.
# 1) Retour en arrière instantané : l'écran précédent est gardé en mémoire et réaffiché tel quel
FN("push", """let DIRTY=0;const dirty=()=>{DIRTY++;HOMEC.k=""};
function snapshot(t){const sc=[];view.querySelectorAll(".sx,.sy").forEach((e,i)=>{if(e.scrollLeft||e.scrollTop)sc.push([i,e.scrollLeft,e.scrollTop])});
 const fr=document.createDocumentFragment();while(view.firstChild)fr.appendChild(view.firstChild);t.dom=fr;t.sc=sc;t.ver=DIRTY+"|"+CATV}
function restore(t){view.replaceChildren(t.dom);t.dom=null;const els=view.querySelectorAll(".sx,.sy");
 t.sc.forEach(([i,l,tp])=>{const e=els[i];if(!e)return;e.style.scrollBehavior="auto";e.scrollLeft=l;e.scrollTop=tp;e._tx=l;e._ty=tp;e._tt=0;e._tt2=0;e.style.scrollBehavior=""});
 document.documentElement.classList.toggle("vplay",false);view.querySelectorAll(".foc").forEach(x=>x.classList.remove("foc"));F=null;bgFor(t);
 const el=(t.last&&view.querySelector(`[data-fid="${CSS.escape(t.last)}"]`))||view.querySelector("[data-default]")||view.querySelector("[data-f]");setFocus(el,true)}
function push(e){const t=topS();t.last=F&&F.dataset.fid;if(!S.modal&&t.t!=="player"&&inApp())snapshot(t);else t.dom=null;S.stack.push(e);render(null)}""")
R(' if(S.stack.length>1){S.stack.pop();render(topS().last);return}', ' if(S.stack.length>1){S.stack.pop();const tp=topS();if(tp.dom&&tp.ver===DIRTY+"|"+CATV){restore(tp);return}tp.dom=null;render(tp.last);return}')
R('function toggleFav(k,label){', 'function toggleFav(k,label){dirty();')
R('function stopPlayer(){clearInterval(PT);', 'function stopPlayer(){clearInterval(PT);if(P&&P.kind==="vod")dirty();')
R('  case "meta":', '  case "meta":dirty();')
R('  case "hide":{', '  case "hide":{dirty();')
R('  case "set":\n', '  case "set":dirty();\n')
R(' // fond\n', ' bgFor(t);\n afterRender(t,fid);\n}\nfunction bgFor(t){\n')
R(" if(!inApp()&&!S.loading){const r=$(\"#req\");", "}\nfunction afterRender(t,fid){\n if(!inApp()&&!S.loading){const r=$(\"#req\");")
R('if(!S.booting)autoCheck();', 'if(!S.booting)autoCheck();\n document.documentElement.classList.toggle("lite",!!S.set.lite);')
# 2) accueil : calculs et HTML gardés en cache tant que rien ne change
R('function homeHtml(){', '''const HOMEC={k:"",h:""};
function homeHtml(){const t=S.tab;if(t!=="films"&&t!=="series")return homeHtml0();const k=t+"|"+CATV+"|"+DIRTY+"|"+S.favs.length+"|"+Object.keys(S.prog).length+"|"+TREND.f.length+"|"+TREND.s.length;
 if(HOMEC.k!==k){HOMEC.k=k;HOMEC.h=homeHtml0()}return HOMEC.h}
function homeHtml0(){ROWI=0;''')
# 3) rangées : 16 vignettes d'abord, la suite se charge en approchant du bout
FN("rowHtml", """const ROWS={};let RSEQ=0;
let ROWI=0;
function rowHtml(id,title,items,fn,count=true){if(!items.length)return"";const total=items.length,rk="r"+(++RSEQ),first=(ROWI++)<4?16:8;ROWS[rk]={items,fn,id,n:Math.min(first,total)};
 if(RSEQ%400===0)Object.keys(ROWS).slice(0,200).forEach(x=>delete ROWS[x]);
 return `<section class="row" data-anchor><h3>${esc(title)}${count?`<small>${total}</small>`:""}</h3><div class="sx" data-rk="${rk}">${items.slice(0,first).map(i=>fn(i,id)).join("")}</div></section>`}
let LIVEL=null,LIVEN=0;
function more(el){const p=el.parentElement;if(!p)return;
 if(p.dataset.rk){const Rw=ROWS[p.dataset.rk];if(Rw&&Rw.n<Rw.items.length){const idx=Array.prototype.indexOf.call(p.children,el);if(idx>=p.children.length-5){const nx=Rw.items.slice(Rw.n,Rw.n+16);Rw.n+=nx.length;p.insertAdjacentHTML("beforeend",nx.map(i=>Rw.fn(i,Rw.id)).join(""))}}}
 else if(el.classList.contains("lch")&&LIVEL&&LIVEN<LIVEL.length){const idx=Array.prototype.indexOf.call(p.children,el);if(idx>=p.children.length-6){const nx=LIVEL.slice(LIVEN,LIVEN+60);LIVEN+=nx.length;p.insertAdjacentHTML("beforeend",nx.map(lchHtml).join(""));nx.slice(0,20).forEach(c=>epg(c))}}}""")
R(' ensureVisible(el,instant);\n if(el.dataset.hov)onHover(el.dataset.hov);', ' more(el);\n ensureVisible(el,instant);\n if(el.dataset.hov)onHover(el.dataset.hov);')
_m = re.search(r'const chs=L\.slice\(0,400\)\.map\(c=>\{const e=epgAt\(c\);return (`.*?`)\}\)\.join\(""\)', js, re.S)
assert _m, "lch"
js = js[:_m.start()] + 'LIVEL=L;LIVEN=Math.min(60,L.length);const chs=L.slice(0,60).map(lchHtml).join("")' + js[_m.end():]
R('function liveHtml(){', 'function lchHtml(c){const e=epgAt(c);return ' + _m.group(1) + '}\nfunction liveHtml(){')
# 4) aperçu de l'accueil : mis à jour après une courte pause, pas à chaque appui
R('if(ALL[h]&&topS().t==="home"){const hr=$("#hero");if(hr){hr.innerHTML=heroInner(ALL[h]);fitAll(hr)}setBg(ALL[h].c,ALL[h].bd)}',
  'if(ALL[h]&&topS().t==="home"){clearTimeout(HOVT);HOVT=setTimeout(()=>{const hr=$("#hero");if(!hr||topS().t!=="home")return;hr.innerHTML=heroInner(ALL[h]);fitAll(hr);setBg(ALL[h].c,ALL[h].bd)},S.set.lite?220:120)}')
R('function onHover(h){', 'let HOVT=null;\nfunction onHover(h){')
# 5) plus aucune mesure de texte sur les affiches : taille calculée à l'avance ; images TMDB en petite taille
FN("fitAll", """function fitAll(root){root.querySelectorAll(".ttl").forEach(t=>{const fs=parseFloat(getComputedStyle(t).fontSize);fitEl(t,fs*(t.closest(".hero")?1.15:2.15))})}""")
FN("poster", r'''const PK={bebas:[34,.42],serif:[22,.56],black:[17,.78],thin:[19,.74]};
function pfs(it){const [b,k]=PK[it.f]||[20,.6],t=String(it.t||""),lw=Math.max(4,...t.split(/\s+/).map(w=>w.length)),L=t.length;return Math.max(10,Math.min(b,114/(lw*k),Math.sqrt(114*112/(Math.max(L,1)*k*1.15))))|0}
const imgS=(u,sz)=>u?String(u).replace(/(image\.tmdb\.org\/t\/p\/)(original|w\d+)\//,"$1"+sz+"/"):"";
function poster(it,nw){const src=imgS(it.img,"w185"),img=src?`<img src="${esc(src)}" alt="" loading="lazy" decoding="async" onerror="this.parentNode.classList.remove('has-img');this.remove()">`:"";
 return `<div class="pst f-${it.f} sh${hash(it.id)%4} ${img?"has-img":""}" style="--a:${it.c[0]};--b:${it.c[1]}">${img}<div class="pst-in">${nw?'<span class="newb">Ajouté récemment</span>':`<span class="pst-k">${it.type==="s"?"SÉRIE":(it.y||"")}</span>`}<span class="pst-t" style="font-size:${pfs(it)}px">${esc(it.t)}</span></div></div>`}''')
R(' nx.style.background=img?', ' img=imgS(img,"w780");\n nx.style.background=img?')
# 6) dates d'ajout calculées une fois par version du catalogue
R('function added(id){const it=ALL[id];if(!it)return null;', 'const ADDC={v:-1,m:{}};\nfunction added(id){if(ADDC.v!==CATV){ADDC.v=CATV;ADDC.m={}}if(id in ADDC.m)return ADDC.m[id];return ADDC.m[id]=added0(id)}\nfunction added0(id){const it=ALL[id];if(!it)return null;')
# 7) mode fluide (réglage)
R('<div class="it" data-f data-fid="set-par" data-act="set:parental">', '<div class="it tall" data-f data-fid="set-lite" data-act="set:lite"><span>Mode fluide<small>Effets de verre et ombres allégés · recommandé sur ce Fire TV</small></span>${sw(st.lite)}</div>\n  <div class="it" data-f data-fid="set-par" data-act="set:parental">')
# 8) démarrage instantané : catalogue gardé sur l'appareil, mis à jour en arrière-plan
FN("boot", """let LASTKEY=0;
async function boot(){if(S.set.lite==null){S.set.lite=!UHD;save()}document.documentElement.classList.toggle("lite",!!S.set.lite);
 if(!S.playlists.length){render();return}
 let cached=0;for(const p of S.playlists){const D=await IDB.get("pl:"+p.id);if(D){DATA[p.id]=D;cached++}}
 if(cached===S.playlists.length){buildCatalog();render();loadTrends();
  const stale=S.playlists.filter(p=>Date.now()-(p.synced||0)>6*3600e3);
  if(stale.length)Promise.all(stale.map(p=>loadPlaylist(p).then(()=>{p.synced=Date.now()}).catch(e=>{p.bootMsg=e.message}))).then(()=>{buildCatalog();save();
   const t=topS();if(t.t==="home"&&!S.modal&&Date.now()-LASTKEY>4000)render(F&&F.dataset.fid)});return}
 S.booting=true;render();
 await Promise.all(S.playlists.map(async p=>{try{await loadPlaylist(p);p.bootSt="done";p.bootMsg="ok"}catch(e){p.bootSt="";p.bootMsg=e.message}if(S.booting)render()}));
 buildCatalog();S.booting=false;S.playlists.filter(p=>p.bootMsg&&p.bootMsg!=="ok").forEach(p=>setTimeout(()=>toast(`${p.name} : ${p.bootMsg}`),1200));
 render();loadTrends().then(()=>{if(topS().t==="home"&&(S.tab==="films"||S.tab==="series"))render(F&&F.dataset.fid)})}""")
R('function key(k){\n', 'function key(k){\n LASTKEY=Date.now();\n')
R('S.playlists=S.playlists.filter(p=>p.id!==w);delete DATA[w];', 'S.playlists=S.playlists.filter(p=>p.id!==w);delete DATA[w];IDB.del("pl:"+w);')
