/* ===================== Données réelles du fournisseur ===================== */
const RCODEC={"4K":"HEVC · 3840×2160","1080p":"H.264 · 1920×1080","720p":"H.264 · 1280×720","SD":"H.264 · 720×576"};
if(REAL){
 if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;
 LCATS.splice(0,LCATS.length,["all","Toutes les chaînes"],["fav","Favoris"],...REAL.lcats);
 const itemOf=key=>key.startsWith("ch:")?(CH[key.slice(3)]||{})._real:(ALL[key]||{})._real;
 const plsOf=r=>r._pl||(r._pl=new Set(r.s.map(x=>x[0])));
 base=function(pl,key){const r=itemOf(key);return r?plsOf(r).has(pl.id):false};
 variants=function(pl,key){const r=itemOf(key);if(!r)return [];const L=r.s.filter(x=>x[0]===pl.id);
  if(key.startsWith("ch:"))return L.map((x,i)=>({id:pl.id+"|"+i,i,p:pl,q:x[2],name:x[1],codec:RCODEC[x[2]],audio:["Français"],subs:["Télétexte si diffusé"],ext:"ts"}));
  return L.map((x,i)=>{const tag=/vostfr/i.test(x[1])?"VOSTFR":/multi/i.test(x[1])?"MULTI":"VF";return {id:pl.id+"|"+i,i,p:pl,q:x[2],tag,name:x[1],codec:RCODEC[x[2]],audio:tag==="VOSTFR"?["Anglais (VO)"]:tag==="MULTI"?["Français (VF)","Anglais (VO)"]:["Français (VF)"],subs:tag==="VOSTFR"?["Français"]:["Aucun"],size:"—",ext:x[3]||"mkv"}})};
 addDays=function(pl,it){const a=it._real&&it._real.a;return a?Math.max(0,Math.floor((Date.now()/1000-a)/86400)):400};
 const M0=new Date().setHours(0,0,0,0)/60000;
 const TPLG={sport:"Sport",info:"Information",cine:"Film",kids:"Dessin animé",doc:"Documentaire",series:"Divertissement"};
 const _e=epg;epg=function(ch){if(!ch._real)return _e(ch);if(EPGC[ch.id])return EPGC[ch.id];
  let L=(REAL.epg[ch._real.e]||[]).map(([s,e,t,g])=>({s:s-M0,e:e-M0,t,g:g||TPLG[ch.tpl]})).filter(p=>p.e>p.s).sort((a,b)=>a.s-b.s);
  if(!L.length)L=[{s:-360,e:1800,t:"Programme non communiqué",g:TPLG[ch.tpl]}];
  return EPGC[ch.id]=L};
}
/* ---------- import : lecture des fichiers ---------- */
const RI={
 ADULT:/adult|xxx|porn|\+ ?18|18 ?\+|for adults|erotic|\bsex|\bhot\b/i,
 FR:/(^|[^a-z])(fr|fra|france|french|vf|vff|vostfr|truefrench)([^a-z]|$)/i,
 strip:s=>s.normalize("NFD").replace(/[̀-ͯ]/g,"").toLowerCase(),
 cleanCat(n){let c=(n||"").replace(/^\s*[\[(|]?\s*(fr|fra|france|french)\s*[\])|:\-–]*\s*/i,"").replace(/^[|:\-–\s]+/,"").trim()||n||"Divers";if(c===c.toUpperCase())c=c.toLowerCase().replace(/(^|[\s\-/&])([a-zà-ÿ])/g,(m,a,b)=>a+b.toUpperCase());return c},
 q(n){return /\b(4k|uhd|2160p?)\b|⁴ᴷ|ᵁᴴᴰ/i.test(n)?"4K":/\b(fhd|1080p?|full ?hd)\b|ᶠᴴᴰ/i.test(n)?"1080p":/\b(hd|720p?)\b|ᴴᴰ/i.test(n)?"720p":/\b(sd|480p?|576p?)\b|ˢᴰ/i.test(n)?"SD":"1080p"},
 base(n){let s=(n||"").replace(/^\s*([\[(|]?\s*(fr|fra|france|be|ch|ca|qc)\s*[\])|:\-–]+\s*)+/i,"");
  s=s.replace(/[ᴴᴰᶠᵁ⁴ᴷˢ]+/g," ").replace(/\b(4k|uhd|fhd|full ?hd|hd|sd|hevc|h\.?26[45]|x26[45]|1080p?|720p?|2160p?|hdr10?|dolby ?vision|50 ?fps|raw|backup|vip|multi|vostfr|vff|vf|truefrench|french)\b/gi," ");
  return s.replace(/[\[\]()|]+/g," ").replace(/\s*[-–:]\s*$/,"").replace(/^\s*[-–:]\s*/,"").replace(/\s{2,}/g," ").trim()||n},
 year(n){const m=(n||"").match(/\b(19[2-9]\d|20[0-3]\d)\b/);return m?+m[1]:0},
 title(n){return RI.base(n).replace(/\(?\b(19[2-9]\d|20[0-3]\d)\b\)?\s*$/,"").replace(/\s*[-–:]\s*$/,"").trim()},
 id(p,k){return p+(hash(k)>>>0).toString(36)},
 ent(s){return s.replace(/&amp;/g,"&").replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').replace(/&apos;|&#39;/g,"'").replace(/&#x([0-9a-f]+);/gi,(_,h)=>String.fromCodePoint(parseInt(h,16))).replace(/&#(\d+);/g,(_,d)=>String.fromCodePoint(+d))},
 t(v){const m=/^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)?\s*([+-]\d{4})?/.exec(v||"");if(!m)return null;let ms=Date.UTC(+m[1],+m[2]-1,+m[3],+m[4],+m[5],+(m[6]||0));if(m[7]){const sg=m[7][0]==="-"?-1:1;ms-=sg*(+m[7].slice(1,3)*60+ +m[7].slice(3,5))*60000}else ms+=new Date().getTimezoneOffset()*60000;return Math.round(ms/60000)}
};
async function rReadJson(f){const t=await f.text();try{return JSON.parse(t)}catch(e){throw new Error(`${f.name} n'est pas un fichier JSON valide`)}}
async function rReadEpg(f,want,status){
 let stream=f.stream();const head=new Uint8Array(await f.slice(0,2).arrayBuffer());
 if(head[0]===0x1f&&head[1]===0x8b){if(typeof DecompressionStream==="undefined")throw new Error("Guide compressé non pris en charge par ce navigateur");stream=stream.pipeThrough(new DecompressionStream("gzip"))}
 const rd=stream.pipeThrough(new TextDecoderStream()).getReader();const out={};let buf="",n=0,kept=0;const now=Date.now()/60000,lo=now-360,hi=now+1800;
 const re=/<programme\b([^>]*)>([\s\S]*?)<\/programme>/g;
 for(;;){const {value,done}=await rd.read();if(value)buf+=value;let m,last=0;re.lastIndex=0;
  while((m=re.exec(buf))){last=re.lastIndex;n++;const a=m[1],ch=(/channel="([^"]*)"/.exec(a)||[])[1];if(!ch||!want.has(ch))continue;
   const s=RI.t((/start="([^"]*)"/.exec(a)||[])[1]),e=RI.t((/stop="([^"]*)"/.exec(a)||[])[1]);if(s==null||e==null||e<lo||s>hi)continue;
   const t=RI.ent((/<title[^>]*>([\s\S]*?)<\/title>/.exec(m[2])||[])[1]||"").trim(),g=RI.ent((/<category[^>]*>([\s\S]*?)<\/category>/.exec(m[2])||[])[1]||"").trim();
   (out[ch]=out[ch]||[]).push([s,e,t.slice(0,90),g.slice(0,40)]);kept++}
  buf=buf.slice(last);if(buf.length>4e6)buf=buf.slice(-2e6);
  if(n%2000<50)status(`Guide des programmes : ${n.toLocaleString("fr-FR")} programmes lus, ${kept.toLocaleString("fr-FR")} gardés…`);
  if(done)break}
 for(const k in out)out[k]=out[k].sort((a,b)=>a[0]-b[0]).slice(0,70);return out}
async function rImport(files,provName,status){
 const by={};for(const f of files){const n=f.name.toLowerCase();
  if(/xmltv|epg|\.xml|\.gz$/.test(n))by.epg=f;else for(const k of ["get_live_categories","get_live_streams","get_vod_categories","get_vod_streams","get_series_categories","get_series"])if(n.startsWith(k+".")||n===k+".json"||n.startsWith(k+" "))by[k]=f}
 if(!by.get_live_streams&&!by.get_vod_streams&&!by.get_series)throw new Error("Je ne trouve pas les fichiers get_live_streams.json, get_vod_streams.json ou get_series.json. Choisis tous les fichiers du dossier créé par la commande.");
 const old=(()=>{try{return JSON.parse(localStorage.getItem("prisme-real")||"null")}catch(e){return null}})();
 const R=old&&old.pls?old:{pls:[],lcats:[],fcats:[],scats:[],chans:[],films:[],series:[],epg:{}};
 const pid="rp"+(R.pls.length+1);R.pls.push({id:pid,name:provName,at:Date.now()});
 const st={};
 const cats=async(file,pref,arr)=>{const m={};if(!file)return m;const L=await rReadJson(file);const all=L.filter(c=>!RI.ADULT.test(c.category_name||""));const fr=all.filter(c=>RI.FR.test(c.category_name||""));
  (fr.length?fr:all).forEach(c=>{const nm=RI.cleanCat(c.category_name),key=RI.id(pref,RI.strip(nm));m[String(c.category_id)]=key;if(!arr.some(x=>x[0]===key))arr.push([key,nm])});return m};
 status("Lecture des catégories…");
 const lc=await cats(by.get_live_categories,"l",R.lcats),fc=await cats(by.get_vod_categories,"f",R.fcats),sc=await cats(by.get_series_categories,"s",R.scats);
 const merge=(arr,pref,key,make,add)=>{let it=arr.find(x=>x.k===key);if(!it){it=make();it.k=key;it.id=RI.id(pref,key);it.s=[];arr.push(it)}add(it);return it};
 if(by.get_live_streams){status("Lecture des chaînes…");const L=await rReadJson(by.get_live_streams);let n=0;
  for(const x of L){const ck=lc[String(x.category_id)];if(Object.keys(lc).length&&!ck)continue;if(RI.ADULT.test(x.name||""))continue;const nm=RI.base(x.name),key=RI.strip(nm);if(!key)continue;n++;
   merge(R.chans,"rc",key,()=>({n:nm,c:[],e:"",num:+x.num||0}),it=>{if(ck&&!it.c.includes(ck))it.c.push(ck);if(!it.e&&x.epg_channel_id)it.e=String(x.epg_channel_id);if(it.s.length<8)it.s.push([pid,String(x.name).slice(0,60),RI.q(x.name)])})}
  st.chans=n}
 if(by.get_vod_streams){status("Lecture des films…");const L=await rReadJson(by.get_vod_streams);let n=0;
  for(const x of L){const ck=fc[String(x.category_id)];if(Object.keys(fc).length&&!ck)continue;if(RI.ADULT.test(x.name||""))continue;const t=RI.title(x.name),y=+x.year||RI.year(x.name),key=RI.strip(t)+"#"+(y||"");if(!t)continue;n++;
   merge(R.films,"rf",key,()=>({t,y,c:[],r:+x.rating||0,a:+x.added||0}),it=>{if(ck&&!it.c.includes(ck))it.c.push(ck);it.a=Math.max(it.a,+x.added||0);if(!it.r&&+x.rating)it.r=+x.rating;if(it.s.length<6)it.s.push([pid,String(x.name).slice(0,70),RI.q(x.name),x.container_extension||"mkv"])})}
  st.films=n}
 if(by.get_series){status("Lecture des séries…");const L=await rReadJson(by.get_series);let n=0;
  for(const x of L){const ck=sc[String(x.category_id)];if(Object.keys(sc).length&&!ck)continue;if(RI.ADULT.test(x.name||""))continue;const t=RI.title(x.name),y=RI.year(x.releaseDate||x.release_date||"")||RI.year(x.name),key=RI.strip(t);if(!t)continue;n++;
   merge(R.series,"rs",key,()=>({t,y,c:[],r:+x.rating||0,a:+x.last_modified||0,p:(x.plot||"").slice(0,400),cast:(x.cast||"").slice(0,200),dir:(x.director||"").slice(0,80),g:(x.genre||"").slice(0,60)}),it=>{if(ck&&!it.c.includes(ck))it.c.push(ck);if(!it.p&&x.plot)it.p=x.plot.slice(0,400);if(it.s.length<6)it.s.push([pid,String(x.name).slice(0,70),RI.q(x.name)])})}
  st.series=n}
 R.chans.sort((a,b)=>(a.num||9999)-(b.num||9999));R.chans=R.chans.slice(0,700);
 R.films.sort((a,b)=>b.a-a.a);R.series.sort((a,b)=>b.a-a.a);
 if(by.epg){const want=new Set(R.chans.map(c=>c.e).filter(Boolean));R.epg={...R.epg,...await rReadEpg(by.epg,want,status)};st.epg=Object.values(R.epg).reduce((a,l)=>a+l.length,0)}
 // garde les catégories utilisées
 const used=new Set([...R.chans,...R.films,...R.series].flatMap(i=>i.c));["lcats","fcats","scats"].forEach(k=>R[k]=R[k].filter(c=>used.has(c[0])));
 status("Enregistrement dans ce navigateur…");
 let nf=Math.min(R.films.length,3000),ns=Math.min(R.series.length,1500),txt;
 for(let tries=0;tries<12;tries++){const out={...R,films:R.films.slice(0,nf),series:R.series.slice(0,ns),at:Date.now()};txt=JSON.stringify(out);
  if(txt.length<4.4e6){try{localStorage.setItem("prisme-real",txt);return {...st,keptF:nf,keptS:ns,totF:R.films.length,totS:R.series.length,pls:R.pls.length}}catch(e){}}
  nf=Math.floor(nf*.7);ns=Math.floor(ns*.7);if(tries===6){for(const k in R.epg)R.epg[k]=R.epg[k].slice(0,25)}}
 throw new Error("Trop de données pour la mémoire du navigateur, même après réduction.")}
/* ---------- panneau sous la télécommande ---------- */
const RCMD=`printf "Nom de ce fournisseur (ex. IPTV1) : "; read -r F; printf "Adresse du serveur (ex. http://monserveur.com:8080) : "; read -r U; printf "Nom d'utilisateur : "; read -r N; printf "Mot de passe : "; read -rs P; echo; case "$U" in http*) ;; *) U="http://$U";; esac; U="\${U%/}"; D=~/Desktop/prisme-"\${F// /-}"; mkdir -p "$D" && cd "$D" && for a in get_live_categories get_live_streams get_vod_categories get_vod_streams get_series_categories get_series; do curl -sSLG -A "Mozilla/5.0" "$U/player_api.php" --data-urlencode "username=$N" --data-urlencode "password=$P" --data-urlencode "action=$a" -o "$a.json" && echo "✓ $a"; done; curl -sSLG -A "Mozilla/5.0" "$U/xmltv.php" --data-urlencode "username=$N" --data-urlencode "password=$P" -o xmltv.xml && echo "✓ guide des programmes"; unset P; open "$D"`;
document.querySelector(".ldemo").insertAdjacentHTML("afterend",`<section class="rimp">
 <h2>Mes données fournisseur <span class="rst" id="rst">${REAL?`Données réelles : ${REAL.pls.map(p=>esc(p.name)).join(" + ")} · ${REAL.chans.length} chaînes · ${REAL.films.length} films · ${REAL.series.length} séries`:"Données de démonstration"}</span></h2>
 <p>Tes chaînes, films, séries et ton guide des programmes, sans aucune lecture vidéo. Tes identifiants restent sur ton Mac : seules les listes sont lues ici, et elles restent dans ce navigateur.</p>
 <ol><li>Sur ton Mac, ouvre <b>Terminal</b>, colle cette commande et appuie sur Entrée. Elle te demande le nom du fournisseur, l'adresse du serveur, l'utilisateur et le mot de passe (qui ne s'affiche pas quand tu tapes), puis crée un dossier sur ton Bureau et l'ouvre.</li></ol>
 <div class="rcmd"><code id="rcmd">${esc(RCMD)}</code><button type="button" id="rcopy">Copier</button></div>
 <ol start="2"><li>Choisis ici <b>tous les fichiers</b> de ce dossier (7 fichiers). Pour un 2ᵉ fournisseur, refais les deux étapes : les catalogues sont fusionnés.</li></ol>
 <div class="rrow"><label for="rname">Nom du fournisseur</label><input id="rname" value="${REAL?"Fournisseur "+(REAL.pls.length+1):"Mon fournisseur"}" autocomplete="off"><label class="rbtn" for="rfiles">Choisir les fichiers…</label><input type="file" id="rfiles" multiple accept=".json,.xml,.gz,.txt,application/json,text/xml" hidden>${REAL?'<button type="button" id="rdemo">Revenir aux données de démo</button>':""}</div>
 <div class="rlog" id="rlog" role="status"></div>
</section>`);
$("#rcopy").addEventListener("click",()=>{const done=()=>{$("#rcopy").textContent="Copié";setTimeout(()=>$("#rcopy").textContent="Copier",1600)};
 if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(RCMD).then(done,()=>{const r=document.createRange();r.selectNodeContents($("#rcmd"));const s=getSelection();s.removeAllRanges();s.addRange(r)});
 else{const r=document.createRange();r.selectNodeContents($("#rcmd"));const s=getSelection();s.removeAllRanges();s.addRange(r)}});
$("#rname").addEventListener("keydown",e=>e.stopPropagation());
$("#rfiles").addEventListener("change",async e=>{const files=[...e.target.files];if(!files.length)return;const log=$("#rlog");const say=m=>{log.textContent=m};log.classList.remove("err");
 try{const name=($("#rname").value||"Mon fournisseur").trim().slice(0,40);const r=await rImport(files,name,say);
  const R=JSON.parse(localStorage.getItem("prisme-real"));
  S.playlists=R.pls.map((p,i)=>({id:p.id,name:p.name,url:"Importé le "+new Date(p.at).toLocaleDateString("fr-FR"),user:"données réelles",pass:"",epg:true,on:true,seed:i+1,real:true}));S.adding=false;S.stack=[{t:"home"}];S.tab="live";save();
  try{localStorage.removeItem("prisme-atv-live")}catch(_){}
  say(`Import réussi : ${r.chans??0} flux de chaînes, ${r.films??0} films, ${r.series??0} séries${r.epg?`, ${r.epg.toLocaleString("fr-FR")} programmes`:""}.${r.keptF<r.totF?` ${r.keptF} films les plus récents gardés sur ${r.totF} (mémoire du navigateur).`:""} Redémarrage du simulateur…`);
  setTimeout(()=>location.reload(),1400)}
 catch(err){log.classList.add("err");say("Import impossible : "+err.message)}
 e.target.value=""});
if($("#rdemo"))$("#rdemo").addEventListener("click",()=>{try{localStorage.removeItem("prisme-real");localStorage.removeItem("prisme-atv-live")}catch(_){}S.playlists=[];S.stack=[{t:"home"}];S.tab="films";save();location.reload()});
