/* ========================= FICHES EN ARRIÈRE-PLAN · maquette A + C =========================
   prisme télécharge tout seul les fiches TMDB (titre, résumé, casting, affiche, note) des films et des séries
   du fournisseur, l'écran d'abord, pendant que l'on navigue. Un anneau dans la barre d'onglets montre où il en est.
   - données réelles + clé TMDB (tapée sous la télécommande, gardée dans ce navigateur) : vrais appels à TMDB
   - données de démonstration : le même parcours, simulé                                                          */
(function(){
const LSK="prisme-fiches",KEYK="prisme-tmdb-key",API="https://api.themoviedb.org/3",IMGB="https://image.tmdb.org/t/p/";
let C={mode:0,pp:0,nouv:1,hd:0,done:{},unk:{},fix:{},first:0,at:0};
try{Object.assign(C,JSON.parse(localStorage.getItem(LSK)||"{}"))}catch(e){}
const saveC=()=>{try{localStorage.setItem(LSK,JSON.stringify(C))}catch(e){}};
const getKey=()=>{try{return localStorage.getItem(KEYK)||""}catch(e){return ""}};
const MODES=["Automatique","La nuit seulement","Jamais"],PPS=["Mettre en pause","Continuer lentement"];
/* état du moteur (non sauvegardé) */
const E={q:[],prio:[],busy:0,paused:false,tot:{f:0,s:0},ok:{f:0,s:0},rate:[],fresh:{},bilan:"",bilanT:0,running:false,lastRender:0,demo:!(typeof REAL!=="undefined"&&REAL),lastErr:""};
window.__fc={C,E,get extras(){return extras},get findId(){return findId}};
const isReal=()=>!E.demo&&!!getKey();
const nf=n=>Math.round(n).toLocaleString("fr-FR");
const kOf=it=>it.prog?it.id:(it.type==="s"||SERIES.includes(it)?"s":"f")+":"+it.id;
const hasFiche=it=>SERIES.includes(it)?!!(it.sxk&&/^t/.test(it.sxk)):!!it.tmd;
const playing=()=>topS().t==="player"&&typeof P!=="undefined"&&P;
const night=()=>{const h=new Date().getHours();return h>=1&&h<6};
function allowed(){if(C.mode===2||E.paused)return false;if(C.mode===1&&!night())return false;if(playing()&&!C.pp)return false;return true}

/* ---------- la file : l'écran d'abord, puis en cours, ma liste, nouveautés, le reste ---------- */
function build(){if(C.mver!==2){for(const k in C.unk)delete C.done[k];C.mver=2;saveC()}const F=FILMS.slice(),Sx=SERIES.slice(),week=7*864e5,now=Date.now();
 E.tot={f:F.length,s:Sx.length,p:0};const need=it=>{const k=kOf(it),d=C.done[k];if(C.fix[k])return false;if(isReal()&&hasFiche(it)&&!E.force){if(it.tmd&&!it.tmd.wp&&it._real&&it._real.tm)return true;if(it.sxk&&SXD.m[it.sxk]&&!SXD.m[it.sxk].ext&&it._real&&it._real.tm)return true;return false}if(!d)return true;if(!C.nouv&&now-d>week)return true;return false};
 const score=it=>(S.prog[it.id]?3e9:0)+(S.favs.includes(it.id)?2e9:0)+((it._real&&it._real.a)||it.y*1e5||0);
 for(const k in C.unk)if(!itemOfK(k))delete C.unk[k];
 E.q=[...F,...Sx].filter(need).sort((a,b)=>score(b)-score(a)).map(kOf);
 E.ok={f:F.filter(it=>!need(it)).length,s:Sx.filter(it=>!need(it)).length,p:0};
 if(isReal()||E.demo){const P=progTitles().map(t=>"p:"+t).filter(k=>!C.done[k]||(Date.now()-C.done[k]>week&&!C.pdone));E.tot.p=P.length;E.q.push(...P)}}
const left=()=>E.q.length+E.prio.length;
const total=()=>E.tot.f+E.tot.s+(E.tot.p||0),doneN=()=>E.ok.f+E.ok.s+(E.ok.p||0);
const pct=()=>{const t=doneN()+left();return t&&left()?Math.min(99,Math.floor(doneN()/t*100)):100};
function itemOfK(k){const id=k.slice(2);if(k[0]==="p")return {t:id,id:k,prog:1};return ALL[id]||null}

/* ---------- TMDB ---------- */
const simp=s=>RI.strip(String(s||"")).replace(/[^a-z0-9]+/g,"");
async function tm(path){const key=getKey(),v4=key.length>60;const u=API+path+(path.includes("?")?"&":"?")+"language=fr-FR"+(v4?"":"&api_key="+encodeURIComponent(key));
 const r=await fetch(u,v4?{headers:{Authorization:"Bearer "+key}}:{});if(r.status===429){await new Promise(z=>setTimeout(z,1500));return tm(path)}
 if(r.status===401){E.lastErr="TMDB refuse la clé";throw new Error("cle")}if(!r.ok)throw new Error("http "+r.status);return r.json()}
const img=(p,w)=>p?IMGB+w+p:"";
/* ---------- reconnaissance : plusieurs recherches, un score de ressemblance, l'année pour départager ---------- */
const bg=s=>{const t=simp(s),o=new Map();for(let i=0;i<t.length-1;i++){const k=t.slice(i,i+2);o.set(k,(o.get(k)||0)+1)}return [o,Math.max(1,t.length-1)]};
function dice(a,b){if(!a||!b)return 0;const A=simp(a),B=simp(b);if(A===B)return 1;if(A.length<2||B.length<2)return 0;const [x,nx]=bg(a),[y,ny]=bg(b);let c=0;for(const [k,v] of x)c+=Math.min(v,y.get(k)||0);return 2*c/(nx+ny)}
function variants(t){const V=[t];const add=v=>{v=(v||"").trim();if(v.length>=2&&!V.includes(v))V.push(v)};
 add(t.replace(/\s*[\(\[].*?[\)\]]\s*/g," "));add(t.split(/\s+[-–:]\s+|:\s*/)[0]);add(t.replace(/^(the|le|la|les|l'|un|une)\s+/i,""));add(t.replace(/&/g,"et"));add(t.replace(/\s+\d{1,2}$/,""));return V.slice(0,4)}
async function findId(kind,it){const tv=kind==="tv",y=+it.y||0,seen=new Map();let best=null;
 const score=m=>{const ts=[tv?m.name:m.title,tv?m.original_name:m.original_title];let sc=Math.max(...ts.map(x=>dice(x,it.t)));const my=+((tv?m.first_air_date:m.release_date)||"").slice(0,4);
  if(y&&my){const d=Math.abs(my-y);sc+=d===0?.15:d<=1?.08:(!tv&&d>3)?-.15:0}sc+=Math.min(.05,Math.log10((m.vote_count||0)+1)/60);return sc};
 for(const q of variants(it.t)){for(const wy of y?[1,0]:[0]){const j=await tm(`/search/${kind}?query=${encodeURIComponent(q)}${wy?(tv?"&first_air_date_year=":"&year=")+y:""}&include_adult=false`);
   for(const m of (j.results||[]).slice(0,8)){if(seen.has(m.id))continue;const sc=score(m);seen.set(m.id,{m,sc,n:(j.results||[]).length})}
   const L=[...seen.values()].sort((a,b)=>b.sc-a.sc);best=L[0];const sec=L[1];
   if(best&&(best.sc>=.82||(best.sc>=.62&&(!sec||best.sc-sec.sc>=.15))||(best.n===1&&best.sc>=.45)))return {id:best.m.id,sc:best.sc}}}
 const L=[...seen.values()].sort((a,b)=>b.sc-a.sc).slice(0,3);
 return {unk:L.filter(x=>x.sc>=.3).map(({m,sc})=>[m.id,tv?m.name:m.title,((tv?m.first_air_date:m.release_date)||"").slice(0,4),m.poster_path||"",Math.round(Math.min(1,sc)*100)])}}
/* ---------- sagas, plateformes, studios, logos, bande-annonce, recommandations ---------- */
const SVLG=window.SVLG=window.SVLG||{};const COK={};const CLG={};
function logoOf(d){const L=((d.images||{}).logos||[]).slice().sort((a,b)=>(a.iso_639_1==="fr"?0:a.iso_639_1==="en"?1:2)-(b.iso_639_1==="fr"?0:b.iso_639_1==="en"?1:2)||(b.vote_average||0)-(a.vote_average||0));return L[0]?img(L[0].file_path,"w300"):""}
function ext(d){const wp=((d["watch/providers"]||{}).results||{}).FR||{},W={f:[],g:[],r:[],b:[]};
 for(const [k,t] of [["f","flatrate"],["g","free"],["g","ads"],["r","rent"],["b","buy"]])for(const x of wp[t]||[]){if(!W[k].includes(x.provider_name))W[k].push(x.provider_name);if(x.logo_path)SVLG[x.provider_name]=SVLG[x.provider_name]||img(x.logo_path,"w92")}
 const vid=((d.videos||{}).results||[]).filter(v=>v.site==="YouTube"&&/Trailer|Teaser/.test(v.type||"")).map(v=>{const n=v.name||"",l=v.iso_639_1||"";return [(l==="fr"?100:l==="en"?10:0)+(/vostf?r?|sous-titr/i.test(n)?-45:0)+(/\bvf\b|version fran|en fran/i.test(n)?25:0)+(v.type==="Trailer"?10:0)+(v.official?4:0),v]}).sort((a,b)=>b[0]-a[0]);
 const v0=vid[0]&&vid[0][1],col=d.belongs_to_collection;
 for(const c of d.production_companies||[]){if(!c.id)continue;const e=COK[c.id]=COK[c.id]||{n:c.name,k:0,lg:c.logo_path?img(c.logo_path,"w185"):""};e.k++}
 const lg=logoOf(d);if(col&&col.id&&lg&&!CLG[col.id])CLG[col.id]=lg;
 return {wp:W,kw:((d.keywords||{}).keywords||[]).map(k=>k.name),rec:((d.recommendations||{}).results||[]).map(x=>x.id),yt:v0?v0.key:"",ytl:!v0?"":(v0.iso_639_1!=="fr"?"vo":/vostf?r?|sous-titr/i.test(v0.name||"")?"vost":"vf"),
  imdb:d.imdb_id||"",lang:d.original_language||"",col:col&&col.id?[col.id,col.name]:null,co:(d.production_companies||[]).map(c=>c.id).filter(Boolean),lg}}
/* studios gardés : au moins 3 films chez le fournisseur, les 24 plus présents (comme films.json) */
function studios(){const L=Object.entries(COK).filter(([,x])=>x.k>=3).sort((a,b)=>b[1].k-a[1].k).slice(0,24);if(!L.length)return;TMD.co=TMD.co||{};for(const [id,x] of L)TMD.co[id]={n:x.n,k:x.k,lg:(TMD.co[id]&&TMD.co[id].lg)||x.lg}}
/* logo d'une saga : celui de la collection TMDB, sinon le logo du premier film de la saga */
async function sagaLogos(){const want=new Set();for(const f of FILMS){const c=f.tmd&&f.tmd.col;if(c)want.add(c[0])}TMD.cl=TMD.cl||{};
 for(const id of want){if(TMD.cl[id])continue;try{const j=await tm(`/collection/${id}/images?include_image_language=fr,en,null`);const L=(j.logos||[]).sort((a,b)=>(a.iso_639_1==="fr"?0:1)-(b.iso_639_1==="fr"?0:1));TMD.cl[id]=L[0]?img(L[0].file_path,"w300"):(CLG[id]||"")}catch(e){TMD.cl[id]=CLG[id]||""}}}
/* plateformes de France (logos) et tendances de la semaine en France */
async function extras(){if(!isReal())return;try{
 for(const t of ["movie","tv"]){const j=await tm(`/watch/providers/${t}?watch_region=FR`);for(const x of j.results||[])if(x.logo_path)SVLG[x.provider_name]=SVLG[x.provider_name]||img(x.logo_path,"w92")}
 for(const n in SVLG){const c=typeof SVCN==="function"?SVCN(n):n;if(window.SXLG&&!SXLG[c])SXLG[c]=SVLG[n]}
 }catch(e){console.warn("fiches plateformes",e)}
 try{const ids=[];for(let pg=1;pg<=5;pg++){const j=await tm(`/movie/popular?region=FR&page=${pg}`);for(const m of j.results||[])if(TMD.m[m.id]&&!ids.includes(m.id))ids.push(m.id)}
 if(ids.length){TMD.pop={};ids.forEach((id,i)=>TMD.pop[id]=i+1);TMD.tr=ids.slice(0,10)}}catch(e){console.warn("fiches tendances",e)}
 try{studios();await sagaLogos();dirty=1;if(typeof FH!=="undefined")FH.cache={};if(window.__sx&&__sx.X)__sx.X.cache={};E.lastRender=0;refresh()}catch(e){console.warn("fiches extras",e)}}
async function fetchFilm(it){const r=it._real||{};let id=+r.tm||0;
 if(!id){const f=await findId("movie",it);if(f.unk)return f;id=f.id}
 let d;try{d=await tm(`/movie/${id}?append_to_response=credits,release_dates,watch/providers,keywords,recommendations,videos,images&include_image_language=fr,en,null&include_video_language=fr,en,null`)}catch(e){if(/http 404/.test(e.message)&&r.tm&&!r.tmRetry){r.tmRetry=1;delete r.tm;return fetchFilm(it)}throw e}let age="";
 for(const x of ((d.release_dates||{}).results||[]))if(x.iso_3166_1==="FR")for(const y of x.release_dates||[])if(y.certification){age=y.certification;break}
 const dir=((d.credits||{}).crew||[]).filter(c=>c.job==="Director").map(c=>c.name).join(", ");
 const m={t:d.title,ot:d.original_title,y:+(d.release_date||"").slice(0,4)||it.y,d:d.runtime||0,g:(d.genres||[]).map(g=>g.name),ov:d.overview||"",tg:d.tagline||"",age,va:d.vote_average||0,vc:d.vote_count||0,dir,
  po:img(d.poster_path,C.hd?"w342":"w185"),bd:img(d.backdrop_path,"w780"),cast:((d.credits||{}).cast||[]).slice(0,8).map(c=>[c.name,c.character||""])};
 Object.assign(m,ext(d));
 TMD.m[id]=m;for(const s of r.s||[]){if(s[1])TMD.names[s[1]]=id;if(s[4])TMD.sids[s[4]]=id}if(!r.tm)r.tmfc=1;r.tm=id;return {id}}
async function fetchSerie(it){const r=it._real||{};
 if(r.tm&&!r.tmRetry){try{return await applySerie(it,+r.tm)}catch(e){if(!/http 404/.test(e.message))throw e;r.tmRetry=1}}
 const f=await findId("tv",it);if(f.unk)return f;return applySerie(it,f.id)}
/* ---------- images des programmes de la TV en direct (aujourd'hui et demain) ---------- */
const PRG={};
async function fetchProg(t){const j=await tm(`/search/multi?query=${encodeURIComponent(t)}&include_adult=false`);let b=null,bs=0;
 for(const m of (j.results||[]).slice(0,6)){if(m.media_type!=="movie"&&m.media_type!=="tv")continue;const sc=Math.max(dice(m.title||m.name,t),dice(m.original_title||m.original_name,t))+Math.min(.05,Math.log10((m.vote_count||0)+1)/60);if(sc>bs){bs=sc;b=m}}
 if(b&&bs>=.8&&(b.backdrop_path||b.poster_path)){const u=img(b.backdrop_path||b.poster_path,b.backdrop_path?"w300":"w185");PRG[RI.strip(t)]=u;IMG.p[RI.strip(t)]=u;return true}return false}
function progTitles(){const out=new Set(),n=nowMin();try{for(const c of chans()){let L=[];try{L=epg(c)}catch(e){}for(const p of L){if(p.e<n||p.s>n+1440)continue;const t=(p.t||"").trim();if(t.length<3||p.img||IMG.p[RI.strip(t)])continue;if(/^(journal|météo|meteo|info|programmes? |fin des programmes|téléachat|teleachat|no programme|pas de programme)/i.test(t))continue;out.add(t);if(out.size>=600)return [...out]}}}catch(e){}return [...out]}
async function applySerie(it,id){const r=it._real||{};const d=await tm(`/tv/${id}?append_to_response=credits,content_ratings,watch/providers,images&include_image_language=fr,en,null`);
 for(const n of d.networks||[])if(n.logo_path&&n.name){SXD.nl=SXD.nl||{};SXD.nl[n.name]=img(n.logo_path,"w185")}
 const wpS=((d["watch/providers"]||{}).results||{}).FR||{};for(const t of ["flatrate","free","ads"])for(const x of wpS[t]||[])if(x.logo_path)SVLG[x.provider_name]=SVLG[x.provider_name]||img(x.logo_path,"w92");let age="";
 for(const x of ((d.content_ratings||{}).results||[]))if(x.iso_3166_1==="FR"&&x.rating){age=x.rating;break}
 const k="t"+id;SXD.m[k]={t:d.name,y:+(d.first_air_date||"").slice(0,4)||it.y,g:(d.genres||[]).map(g=>g.name),ov:d.overview||"",net:(((d.networks||[])[0])||{}).name||"",cr:(d.created_by||[]).map(c=>c.name).join(", "),
  va:d.vote_average||0,age,po:img(d.poster_path,C.hd?"w342":"w185"),bd:img(d.backdrop_path,"w780"),ext:1,lg:logoOf(d),wpf:(wpS.flatrate||[]).map(x=>x.provider_name),ep:(d.episode_run_time||[])[0]||0,cast:((d.credits||{}).cast||[]).slice(0,8).map(c=>[c.name,c.character||""])};
 for(const s of r.s||[])if(s[1])SXD.names[s[1]]=k;r.tm=id;return {id}}

/* ---------- sauvegarde des fiches téléchargées (reprise après coupure) ---------- */
let dirty=0;
async function persist(){if(!dirty||E.demo)return;dirty=0;try{await idbSet("fcfilms",{m:TMD.m,names:TMD.names,sids:TMD.sids});await idbSet("fcseries",{m:SXD.m,names:SXD.names});await idbSet("fcprog",PRG);await idbSet("fcext",{svlg:SVLG,co:TMD.co||null,cl:TMD.cl||null,pop:TMD.pop||null,tr:TMD.tr||null,nl:SXD.nl||null,cok:COK})}catch(e){}}
setInterval(persist,8000);
if(!E.demo)Promise.all([idbGet("fcfilms").catch(()=>null),idbGet("fcseries").catch(()=>null),idbGet("fcprog").catch(()=>null),idbGet("fcext").catch(()=>null)]).then(([f,s,pg,xt])=>{if(xt){Object.assign(SVLG,xt.svlg||{});Object.assign(COK,xt.cok||{});if(xt.co)TMD.co=xt.co;if(xt.cl)TMD.cl=xt.cl;if(xt.pop)TMD.pop=xt.pop;if(xt.tr)TMD.tr=xt.tr;if(xt.nl)SXD.nl=Object.assign(SXD.nl||{},xt.nl);for(const n in SVLG){const c=typeof SVCN==="function"?SVCN(n):n;if(window.SXLG&&!SXLG[c])SXLG[c]=SVLG[n]}}if(pg){Object.assign(PRG,pg);Object.assign(IMG.p,pg)}
 if(f){Object.assign(TMD.m,f.m||{});Object.assign(TMD.names,f.names||{});Object.assign(TMD.sids,f.sids||{});tmApply()}
 if(s){Object.assign(SXD.m,s.m||{});Object.assign(SXD.names,s.names||{});sxApply()}
 if((f||s)&&inApp()&&!S.loading)render(F&&F.dataset.fid);start()}).catch(()=>start());

/* ---------- le moteur ---------- */
async function one(k){const it=itemOfK(k);if(!it){C.done[k]=Date.now();return}
 if(k[0]==="p"){if(isReal()){try{if(await fetchProg(it.t)){dirty=1;applySoon(k)}}catch(e){if(e.message==="cle"){E.paused=true;return}}}else await new Promise(z=>setTimeout(z,120));C.done[k]=Date.now();E.ok.p=(E.ok.p||0)+1;E.rate.push(Date.now());if(E.rate.length>40)E.rate.shift();return}
 const ser=k[0]==="s";
 if(isReal()){let res;try{res=ser?await fetchSerie(it):await fetchFilm(it)}catch(e){if(e.message==="cle"){E.paused=true;toast("TMDB refuse la clé : vérifie-la sous la télécommande");return}E.tries=E.tries||{};E.tries[k]=(E.tries[k]||0)+1;if(E.tries[k]<3&&!/http 4/.test(e.message)){E.q.push(k);await new Promise(z=>setTimeout(z,800));return}res={unk:[]}}
  if(res.unk){C.unk[k]={raw:((it._real||{}).s||[[0,it.t]])[0][1]||it.t,t:it.t,c:res.unk,i:0}}else{delete C.unk[k];dirty=1;applySoon(it.id)}}
 else{await new Promise(z=>setTimeout(z,E.demo?380:10));applySoon(it.id)}
 C.done[k]=Date.now();E.ok[ser?"s":"f"]++;E.rate.push(Date.now());if(E.rate.length>40)E.rate.shift()}
let applyT=null,pend=new Set();
function applySoon(id){pend.add(id);if(applyT)return;applyT=setTimeout(()=>{applyT=null;const ids=[...pend];pend.clear();
 if(isReal()){tmApply();sxApply();if(typeof FXS!=="undefined")FXS.cache={};if(window.__sx&&__sx.X)__sx.X.cache={}}
 const t=Date.now();ids.forEach(i=>E.fresh[i]=t);refresh()},1200)}
/* on redessine sans perdre le focus, jamais pendant la lecture ni dans une fenêtre */
function refresh(){if(!inApp()||S.loading||S.modal||playing()||topS().t==="search")return;if(Date.now()-E.lastRender<4000)return;E.lastRender=Date.now();render(F&&F.dataset.fid)}
async function loop(){if(E.running)return;E.running=true;
 while(left()){if(!allowed()){await new Promise(z=>setTimeout(z,1000));paint();continue}
  const slow=playing()&&C.pp;const n=slow?1:isReal()?4:1;const batch=[];
  while(batch.length<n&&left()){const k=E.prio.length?E.prio.shift():E.q.shift();if(k&&!C.done[k]&&!batch.includes(k))batch.push(k)}
  await Promise.all(batch.map(one));saveC();paint();if(slow)await new Promise(z=>setTimeout(z,1500))}
 E.running=false;E.force=false;finish()}
function finish(){if(!total())return;if(isReal()&&!E.xDone){E.xDone=true;extras()}const first=!C.first;C.first=C.first||Date.now();C.at=Date.now();saveC();persist();const u=Object.keys(C.unk).length;
 E.bilan=`✓ Fiches à jour · ${nf(E.ok.f)} films, ${nf(E.ok.s)} séries${u?` · ${u} à vérifier`:""}`;E.bilanT=Date.now()+5000;E.ringKeep=false;paint();
 if(first||E.wasRunning)refresh();E.wasRunning=false}
/* titres importés avant le nettoyage (« Brothers 2026 US ») : on les nettoie au chargement, sans réimporter,
   et les fiches qui n'avaient pas été trouvées sous l'ancien titre sont recherchées à nouveau */
function cleanTitles(){if(E.demo||E.cleaned)return;E.cleaned=true;let n=0;
 for(const it of [...FILMS,...SERIES]){const r=it._real;if(!r||hasFiche(it))continue;const raw=((r.s||[])[0]||[])[1]||r.t||it.t;const nt=RI.title(raw);
  if(!it.y||it.y===2024){const y=RI.year(raw);if(y)it.y=y}
  if(nt&&nt.length>=2&&nt!==it.t){it.t=nt;r.t=nt;n++;const k=kOf(it);delete C.done[k];delete C.unk[k]}}
 if(n){saveC();if(window.__sx&&__sx.X)__sx.X.cache={};if(typeof FXS!=="undefined")FXS.cache={}}return n}
try{cleanTitles()}catch(e){}
function start(){try{cleanTitles()}catch(e){}if(!inApp()||C.mode===2)return paint();if(!E.demo&&!getKey())return paint();build();if(left()){E.wasRunning=true;loop()}paint()}

/* ---------- anneau dans la barre d'onglets + panneau ---------- */
const CIRC=2*Math.PI*15;
function ringIc(){if(C.mode===2)return "";if(!E.demo&&!getKey())return "";const fin=!left();if(fin&&Date.now()>E.bilanT&&!E.ringKeep)return "";
 const ic=fin?"✓":E.paused?"⏸":playing()&&!C.pp?"⏸":C.mode===1&&!night()?"🌙":pct();
 return `<div class="tab ic fcring ${fin?"fin":""}" data-f data-fid="tab-fc" data-row="tabs" data-act="fc:go" aria-label="Fiches"><svg viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" class="tr"/><circle cx="18" cy="18" r="15" class="pg" style="stroke-dasharray:${CIRC};stroke-dashoffset:${CIRC*(1-pct()/100)}"/></svg><span class="fcn ${typeof ic==="number"?"num":""}">${ic}</span></div>`}
{const _tb=tabbar;tabbar=function(){const h=_tb(),r=ringIc();if(!r)return h;const i=h.lastIndexOf("</div></div>");return h.slice(0,i)+r+h.slice(i)}}
function status(){if(C.mode===2)return "désactivé · les fiches arrivent seulement quand tu les ouvres";if(!E.demo&&!getKey())return "ajoute ta clé TMDB sous la télécommande";
 if(!left())return `à jour · ${nf(doneN())} fiches${C.at?" · le "+new Date(C.at).toLocaleDateString("fr-FR"):""} · ${mo()} Mo`;
 if(E.paused)return "en pause · "+nf(doneN())+" / "+nf(total());if(playing()&&!C.pp)return "en pause pendant la lecture";if(C.mode===1&&!night())return "prévu cette nuit, entre 1 h et 6 h";
 return `${nf(doneN())} / ${nf(total())} · reste ${eta()} · ${mo()} Mo`}
function eta(){const r=E.rate;if(r.length<5)return "…";const per=(r[r.length-1]-r[0])/(r.length-1)||100,s=left()*per/1000;return s<60?"moins d'1 min":"≈ "+Math.ceil(s/60)+" min"}
const mo=()=>Math.round(doneN()*(C.hd?.16:.06));
function popHtml(){const f=E.ok.f,s=E.ok.s,bar=(n,a,b,c)=>`<div class="fcbar" style="--c:${c}"><span>${n}</span><span class="t"><i style="width:${b?a/b*100:100}%"></i></span><span>${nf(a)} / ${nf(b)}</span></div>`;
 const nx=E.prio[0]||E.q[0],it=nx&&itemOfK(nx);
 return `<div class="fcpop"><h3>${left()?"Fiches en cours":"Fiches à jour"}</h3><div class="mut">${esc(status())}${E.demo?" · démo":""}</div>${bar("Films",f,E.tot.f,"#7dd3fc")}${bar("Séries",s,E.tot.s,"#a78bfa")}${E.tot.p?bar("TV en direct",E.ok.p||0,E.tot.p,"#f472b6"):""}
 ${left()&&allowed()&&it?`<div class="now">En ce moment : <em>${esc(it.t)}</em></div><div class="now">${E.prio.length?"Priorité : ce que tu regardes":"Ordre : en cours, ma liste, nouveautés, puis le reste"}</div>`:""}
 ${Object.keys(C.unk).length?`<div class="now">${Object.keys(C.unk).length} fiche(s) à vérifier</div>`:""}<div class="mut sm">OK : ouvrir le réglage</div></div>`}
function paint(){const v=$("#view");if(!v)return;const r=v.querySelector(".fcring");
 if(r){const pg=r.querySelector(".pg");if(pg)pg.style.strokeDashoffset=CIRC*(1-pct()/100);const n=r.querySelector(".fcn");const ic=!left()?"✓":E.paused||(playing()&&!C.pp)?"⏸":C.mode===1&&!night()?"🌙":pct();if(n&&n.textContent!==String(ic)){n.textContent=ic;n.classList.toggle("num",typeof ic==="number")}r.classList.toggle("fin",!left())}
 let p=v.querySelector(".fcpop");const want=F&&F.dataset&&F.dataset.fid==="tab-fc";
 if(want){if(!p){v.insertAdjacentHTML("beforeend",`<div class="fcpopw"></div>`);p=v.querySelector(".fcpopw")}else p=p.parentNode;p.innerHTML=popHtml()}else if(p)p.parentNode.remove();
 let w=v.querySelector(".fcwh");const show=E.bilan&&Date.now()<E.bilanT;if(show&&!w){v.insertAdjacentHTML("beforeend",`<div class="fcwh">${esc(E.bilan)}</div>`)}else if(!show&&w)w.remove();
 const st=v.querySelector("#fc-st");if(st)st.textContent=status();}
setInterval(()=>{paint();if(E.bilanT&&Date.now()>E.bilanT+300&&!left()){E.bilanT=0;if(inApp()&&!S.loading&&!S.modal&&!playing()&&F&&F.dataset.fid!=="tab-fc")render(F&&F.dataset.fid)}},1000);
/* priorité : la fiche que l'on survole passe devant */
{const _sf=setFocus;setFocus=function(el,i){const r=_sf(el,i);try{const id=el&&el.dataset&&el.dataset.hid;if(id&&ALL[id]){const k=kOf(ALL[id]);if(!C.done[k]&&E.q.includes(k)){E.q.splice(E.q.indexOf(k),1);E.prio.unshift(k);E.prio=E.prio.slice(0,6)}}}catch(e){}paint();return r}}
/* fiches qui s'allument : fondu sur les affiches arrivées à l'instant */
{const _r=render;render=function(fid){const r=_r(fid);try{const t=Date.now();for(const id in E.fresh){if(t-E.fresh[id]>5000){delete E.fresh[id];continue}document.querySelectorAll(`#view [data-hid="${CSS.escape(id)}"]`).forEach(e=>e.classList.add("fcnew"))}}catch(e){}paint();return r}}

/* ---------- Réglages › Accueils et notes ---------- */
window.SAX=window.SAX||{};
const row=(fid,act,t,d,v)=>`<div class="it" data-f data-fid="${fid}" data-act="${act}" data-desc="${esc(d)}"><span>${t}</span><span>${v} ›</span></div>`;
SAX.homes=()=>{const u=Object.keys(C.unk).length,key=getKey();let h=`<div class="sa-grp">Fiches en arrière-plan</div>`;
 h+=`<div class="it" data-f data-fid="fc-mode" data-act="fc:mode" data-desc="Automatique : prisme télécharge les fiches dès qu'un fournisseur est ajouté, l'écran d'abord. La nuit seulement : entre 1 h et 6 h. Jamais : une fiche arrive quand tu l'ouvres."><span>Fiches TMDB<small id="fc-st">${esc(status())}</small></span><span>${MODES[C.mode]} ›</span></div>`;
 if(C.mode!==2&&left())h+=row("fc-pause","fc:pause",E.paused?"Reprendre maintenant":"Mettre en pause",E.paused?"Le téléchargement repart où il en était.":"Jusqu'à ce que tu relances. Rien n'est perdu.","");
 h+=row("fc-nouv","fc:nouv","Après le premier passage","Seulement les nouveautés : les fois suivantes, prisme ne télécharge que les films et séries arrivés chez le fournisseur.",C.nouv?"Seulement les nouveautés":"Tout revérifier chaque semaine");
 h+=row("fc-pp","fc:pp","Pendant la lecture","Pour ne pas gêner la vidéo.",PPS[C.pp]);
 h+=row("fc-hd","fc:hd","Qualité des affiches",C.hd?"HD : ≈ 160 Mo pour 1 000 fiches.":"Légères : ≈ 60 Mo pour 1 000 fiches.",C.hd?"HD":"Légères");
 {const sure=Object.values(C.unk).filter(x=>x.c[0]&&x.c[0][4]>=70).length;if(sure)h+=row("fc-all","fc:all",`Accepter les ${sure} propositions sûres`,"Associe d'un coup les fiches dont la proposition de TMDB ressemble à 70 % ou plus au titre du fournisseur. Les autres restent à vérifier une par une.","")}
 h+=row("fc-unk","fc:unk","Fiches non reconnues","Les titres que TMDB n'a pas trouvés tels quels, avec sa proposition à valider.",u?u+" à vérifier":"aucune");
 if(SA.open==="fcunk")h+=Object.entries(C.unk).slice(0,30).map(([k,x],i)=>{const c=x.c[x.i||0];return `<div class="sa-op fcuk" data-f data-fid="fc-u-${i}" data-act="fc:pick:${k}" data-desc="OK : associer cette fiche · → : proposition suivante"><span><code>${esc(x.raw)}</code><small>${c?`${esc(c[1])} (${c[2]||"?"})${c[4]!=null?` · ressemblance ${c[4]} %`:""}${x.c.length>1?` · ${(x.i||0)+1}/${x.c.length}`:""}`:"aucune proposition : la fiche garde les infos du fournisseur"}</small></span><span>${c?"Associer ›":"Ignorer ›"}</span></div>`}).join("");
 h+=row("fc-redo","fc:redo","Tout retélécharger","Efface les fiches téléchargées par prisme et recommence.","");
 h+=`<div class="it sa-fixed"><span>Clé TMDB<small>${key?"enregistrée dans ce navigateur":"à taper sous la télécommande, dans « Mes données fournisseur »"}</small></span><span>${key?"✓":E.demo?"démo":"manquante"}</span></div>`;
 return h};
{const _a=act;act=function(a){if(typeof a!=="string"||!a.startsWith("fc:"))return _a(a);const rest=a.slice(3),ci=rest.indexOf(":"),w=ci<0?rest:rest.slice(0,ci),x=ci<0?"":rest.slice(ci+1);
 switch(w){
 case "go":if(window.SA){SA.cat="homes";SA.q="";SA.open=null;SA.prof=null}S.stack=[S.stack[0]];S.tab="settings";save();return render("fc-mode");
 case "mode":C.mode=(C.mode+1)%3;saveC();E.paused=false;if(C.mode!==2)start();return render("fc-mode");
 case "pause":E.paused=!E.paused;toast(E.paused?"⏸ Fiches en pause":"▶︎ Les fiches reprennent");if(!E.paused)start();return render("fc-pause");
 case "nouv":C.nouv=C.nouv?0:1;saveC();return render("fc-nouv");
 case "pp":C.pp=C.pp?0:1;saveC();return render("fc-pp");
 case "hd":C.hd=C.hd?0:1;saveC();toast(C.hd?"Les prochaines affiches seront en HD":"Les prochaines affiches seront légères");return render("fc-hd");
 case "unk":if(!Object.keys(C.unk).length){toast("Tout est reconnu ✓");return}SA.open=SA.open==="fcunk"?null:"fcunk";return render(SA.open?"fc-u-0":"fc-unk");
 case "pick":{const u=C.unk[x];if(!u)return;const c=u.c[u.i||0],it=itemOfK(x);delete C.unk[x];C.fix[x]=1;saveC();
  if(c&&it&&isReal()){(x[0]==="s"?applySerie(it,c[0]):(it._real.tm=c[0],fetchFilm(it))).then(()=>{dirty=1;applySoon(it.id);E.lastRender=0;refresh()}).catch(()=>{})}
  toast(c?`✓ Associé à « ${c[1]} »`:"Titre ignoré");return render(Object.keys(C.unk).length?"fc-u-0":"fc-unk")}
 case "all":{let n=0;for(const [k,u] of Object.entries(C.unk)){const c=u.c[0],it=itemOfK(k);if(!c||c[4]<70||!it)continue;delete C.unk[k];C.fix[k]=1;n++;
   if(isReal())(k[0]==="s"?applySerie(it,c[0]):(it._real.tm=c[0],fetchFilm(it))).then(()=>{dirty=1;applySoon(it.id)}).catch(()=>{})}saveC();toast(`✓ ${n} fiche${n>1?"s":""} associée${n>1?"s":""}`);return render("fc-unk")}
 case "redo":C.done={};C.unk={};C.fix={};C.first=0;saveC();E.force=true;if(isReal()){for(const it of FILMS)if(it._real&&it._real.tmfc){delete it._real.tm;delete it._real.tmfc}idbSet("fcfilms",{m:{},names:{},sids:{}}).catch(()=>{});idbSet("fcseries",{m:{},names:{}}).catch(()=>{})}
  E.paused=false;E.ringKeep=true;start();toast("On recommence depuis le début");return render("fc-redo")}}}
/* → sur une fiche non reconnue : proposition suivante */
{const _k=key;key=function(k){if((k==="right"||k==="left")&&F&&/^fc-u-/.test(F.dataset.fid||"")){const a=F.dataset.act.slice(8),u=C.unk[a];if(u&&u.c.length>1){u.i=((u.i||0)+(k==="right"?1:u.c.length-1))%u.c.length;saveC();return render(F.dataset.fid)}return}return _k(k)}}

/* ---------- clé TMDB sous la télécommande (jamais dans la conversation) ---------- */
const box=document.querySelector(".rimp");
if(box){box.insertAdjacentHTML("beforeend",`<div class="fckey"><b>Fiches en arrière-plan</b><p>Avec ta clé API TMDB, l'Apple TV télécharge elle-même les fiches des films et des séries, sans commande Terminal. La clé reste dans ce navigateur.</p>
 <div class="fckr"><input type="password" id="fckey" placeholder="${getKey()?"clé enregistrée ✓ (tape une autre clé pour la changer)":"colle ta clé API TMDB ici"}" autocomplete="off" spellcheck="false"><button id="fckok">Enregistrer</button>${getKey()?`<button id="fckdel">Oublier la clé</button>`:""}</div><p id="fckmsg" class="fcmsg"></p></div>`);
 const msg=t=>{const m=$("#fckmsg");if(m)m.textContent=t};
 $("#fckey").addEventListener("keydown",e=>{e.stopPropagation();if(e.key==="Enter")$("#fckok").click()});
 $("#fckok").addEventListener("click",async()=>{const v=$("#fckey").value.trim();if(!v)return msg("Colle d'abord ta clé.");msg("Vérification auprès de TMDB…");
  let r=null;const v4=v.length>60;try{r=await fetch(API+"/configuration"+(v4?"":"?api_key="+encodeURIComponent(v)),v4?{headers:{Authorization:"Bearer "+v}}:{})}
  catch(e){return msg(/^https?:/.test(location.protocol)?"Cette page publiée n'a pas le droit de contacter TMDB (protection des pages Claude). Télécharge le simulateur et ouvre le fichier sur ton Mac : la clé y fonctionnera.":"Impossible de joindre TMDB : vérifie la connexion Internet du Mac.")}
  if(r.status===401)return msg("TMDB refuse cette clé. Vérifie-la sur themoviedb.org › Paramètres › API (la « clé d'API », ou le « jeton d'accès en lecture »).");
  try{if(!r.ok)throw 0;
   localStorage.setItem(KEYK,v);$("#fckey").value="";msg(E.demo?"✓ Clé acceptée. Elle servira dès que tes données réelles seront importées.":"✓ Clé acceptée : les fiches se téléchargent sur la TV.");E.paused=false;start();if(inApp()&&!S.loading)render(F&&F.dataset.fid)}
  catch(e){msg("TMDB a répondu une erreur ("+r.status+"). Réessaie dans un instant.")}});
 const del=$("#fckdel");if(del)del.addEventListener("click",()=>{try{localStorage.removeItem(KEYK)}catch(e){}msg("Clé oubliée.");paint()})}

/* démarrage : après l'écran de chargement */
const boot=setInterval(()=>{if(typeof S!=="undefined"&&!S.loading&&inApp()){clearInterval(boot);start()}},700);
})();
