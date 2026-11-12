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
window.__fc={C,E};
const isReal=()=>!E.demo&&!!getKey();
const nf=n=>Math.round(n).toLocaleString("fr-FR");
const kOf=it=>(it.type==="s"||SERIES.includes(it)?"s":"f")+":"+it.id;
const hasFiche=it=>SERIES.includes(it)?!!(it.sxk&&/^t/.test(it.sxk)):!!it.tmd;
const playing=()=>topS().t==="player"&&typeof P!=="undefined"&&P;
const night=()=>{const h=new Date().getHours();return h>=1&&h<6};
function allowed(){if(C.mode===2||E.paused)return false;if(C.mode===1&&!night())return false;if(playing()&&!C.pp)return false;return true}

/* ---------- la file : l'écran d'abord, puis en cours, ma liste, nouveautés, le reste ---------- */
function build(){const F=FILMS.slice(),Sx=SERIES.slice(),week=7*864e5,now=Date.now();
 E.tot={f:F.length,s:Sx.length};const need=it=>{const k=kOf(it),d=C.done[k];if(C.fix[k])return false;if(isReal()&&hasFiche(it)&&!E.force)return false;if(!d)return true;if(!C.nouv&&now-d>week)return true;return false};
 const score=it=>(S.prog[it.id]?3e9:0)+(S.favs.includes(it.id)?2e9:0)+((it._real&&it._real.a)||it.y*1e5||0);
 for(const k in C.unk)if(!itemOfK(k))delete C.unk[k];
 E.q=[...F,...Sx].filter(need).sort((a,b)=>score(b)-score(a)).map(kOf);
 E.ok={f:F.filter(it=>!need(it)).length,s:Sx.filter(it=>!need(it)).length}}
const left=()=>E.q.length+E.prio.length;
const total=()=>E.tot.f+E.tot.s,doneN=()=>E.ok.f+E.ok.s;
const pct=()=>{const t=doneN()+left();return t&&left()?Math.min(99,Math.floor(doneN()/t*100)):100};
function itemOfK(k){const id=k.slice(2);return ALL[id]||null}

/* ---------- TMDB ---------- */
const simp=s=>RI.strip(String(s||"")).replace(/[^a-z0-9]+/g,"");
async function tm(path){const key=getKey(),v4=key.length>60;const u=API+path+(path.includes("?")?"&":"?")+"language=fr-FR"+(v4?"":"&api_key="+encodeURIComponent(key));
 const r=await fetch(u,v4?{headers:{Authorization:"Bearer "+key}}:{});if(r.status===429){await new Promise(z=>setTimeout(z,1500));return tm(path)}
 if(r.status===401){E.lastErr="TMDB refuse la clé";throw new Error("cle")}if(!r.ok)throw new Error("http "+r.status);return r.json()}
const img=(p,w)=>p?IMGB+w+p:"";
async function fetchFilm(it){const r=it._real||{};let id=+r.tm||0,cands=[];
 if(!id){const j=await tm(`/search/movie?query=${encodeURIComponent(it.t)}${it.y?"&year="+it.y:""}&include_adult=false`);const w=simp(it.t);
  cands=(j.results||[]).slice(0,3).map(m=>[m.id,m.title,(m.release_date||"").slice(0,4),m.poster_path||""]);
  for(const m of j.results||[]){if([m.title,m.original_title].some(x=>x&&(simp(x)===w||(w.length>=5&&simp(x).indexOf(w)===0)))){id=m.id;break}}
  if(!id&&(j.results||[]).length===1)id=j.results[0].id}
 if(!id)return {unk:cands};
 let d;try{d=await tm(`/movie/${id}?append_to_response=credits,release_dates`)}catch(e){if(/http 404/.test(e.message)&&r.tm&&!r.tmRetry){r.tmRetry=1;delete r.tm;return fetchFilm(it)}throw e}let age="";
 for(const x of ((d.release_dates||{}).results||[]))if(x.iso_3166_1==="FR")for(const y of x.release_dates||[])if(y.certification){age=y.certification;break}
 const dir=((d.credits||{}).crew||[]).filter(c=>c.job==="Director").map(c=>c.name).join(", ");
 const m={t:d.title,ot:d.original_title,y:+(d.release_date||"").slice(0,4)||it.y,d:d.runtime||0,g:(d.genres||[]).map(g=>g.name),ov:d.overview||"",tg:d.tagline||"",age,va:d.vote_average||0,vc:d.vote_count||0,dir,
  po:img(d.poster_path,C.hd?"w342":"w185"),bd:img(d.backdrop_path,"w780"),cast:((d.credits||{}).cast||[]).slice(0,8).map(c=>[c.name,c.character||""])};
 TMD.m[id]=m;for(const s of r.s||[]){if(s[1])TMD.names[s[1]]=id;if(s[4])TMD.sids[s[4]]=id}if(!r.tm)r.tmfc=1;r.tm=id;return {id}}
async function fetchSerie(it){const r=it._real||{};let j=it.y?await tm(`/search/tv?query=${encodeURIComponent(it.t)}&first_air_date_year=${it.y}`):{results:[]};if(!(j.results||[]).length)j=await tm(`/search/tv?query=${encodeURIComponent(it.t)}`);const w=simp(it.t);let id=0;
 const cands=(j.results||[]).slice(0,3).map(m=>[m.id,m.name,(m.first_air_date||"").slice(0,4),m.poster_path||""]);
 for(const m of j.results||[]){if([m.name,m.original_name].some(x=>x&&(simp(x)===w||(w.length>=5&&simp(x).indexOf(w)===0)))){id=m.id;break}}
 if(!id&&(j.results||[]).length===1)id=j.results[0].id;if(!id)return {unk:cands};return applySerie(it,id)}
async function applySerie(it,id){const r=it._real||{};const d=await tm(`/tv/${id}?append_to_response=credits,content_ratings`);let age="";
 for(const x of ((d.content_ratings||{}).results||[]))if(x.iso_3166_1==="FR"&&x.rating){age=x.rating;break}
 const k="t"+id;SXD.m[k]={t:d.name,y:+(d.first_air_date||"").slice(0,4)||it.y,g:(d.genres||[]).map(g=>g.name),ov:d.overview||"",net:(((d.networks||[])[0])||{}).name||"",cr:(d.created_by||[]).map(c=>c.name).join(", "),
  va:d.vote_average||0,age,po:img(d.poster_path,C.hd?"w342":"w185"),bd:img(d.backdrop_path,"w780"),ep:(d.episode_run_time||[])[0]||0,cast:((d.credits||{}).cast||[]).slice(0,8).map(c=>[c.name,c.character||""])};
 for(const s of r.s||[])if(s[1])SXD.names[s[1]]=k;return {id}}

/* ---------- sauvegarde des fiches téléchargées (reprise après coupure) ---------- */
let dirty=0;
async function persist(){if(!dirty||E.demo)return;dirty=0;try{await idbSet("fcfilms",{m:TMD.m,names:TMD.names,sids:TMD.sids});await idbSet("fcseries",{m:SXD.m,names:SXD.names})}catch(e){}}
setInterval(persist,8000);
if(!E.demo)Promise.all([idbGet("fcfilms").catch(()=>null),idbGet("fcseries").catch(()=>null)]).then(([f,s])=>{
 if(f){Object.assign(TMD.m,f.m||{});Object.assign(TMD.names,f.names||{});Object.assign(TMD.sids,f.sids||{});tmApply()}
 if(s){Object.assign(SXD.m,s.m||{});Object.assign(SXD.names,s.names||{});sxApply()}
 if((f||s)&&inApp()&&!S.loading)render(F&&F.dataset.fid);start()}).catch(()=>start());

/* ---------- le moteur ---------- */
async function one(k){const it=itemOfK(k);if(!it){C.done[k]=Date.now();return}
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
function finish(){if(!total())return;const first=!C.first;C.first=C.first||Date.now();C.at=Date.now();saveC();persist();const u=Object.keys(C.unk).length;
 E.bilan=`✓ Fiches à jour · ${nf(E.ok.f)} films, ${nf(E.ok.s)} séries${u?` · ${u} à vérifier`:""}`;E.bilanT=Date.now()+5000;E.ringKeep=false;paint();
 if(first||E.wasRunning)refresh();E.wasRunning=false}
function start(){if(!inApp()||C.mode===2)return paint();if(!E.demo&&!getKey())return paint();build();if(left()){E.wasRunning=true;loop()}paint()}

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
 return `<div class="fcpop"><h3>${left()?"Fiches en cours":"Fiches à jour"}</h3><div class="mut">${esc(status())}${E.demo?" · démo":""}</div>${bar("Films",f,E.tot.f,"#7dd3fc")}${bar("Séries",s,E.tot.s,"#a78bfa")}
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
 h+=row("fc-unk","fc:unk","Fiches non reconnues","Les titres que TMDB n'a pas trouvés tels quels, avec sa proposition à valider.",u?u+" à vérifier":"aucune");
 if(SA.open==="fcunk")h+=Object.entries(C.unk).slice(0,30).map(([k,x],i)=>{const c=x.c[x.i||0];return `<div class="sa-op fcuk" data-f data-fid="fc-u-${i}" data-act="fc:pick:${k}" data-desc="OK : associer cette fiche · → : proposition suivante"><span><code>${esc(x.raw)}</code><small>${c?`${esc(c[1])} (${c[2]||"?"})${x.c.length>1?` · ${(x.i||0)+1}/${x.c.length}`:""}`:"aucune proposition"}</small></span><span>${c?"Associer ›":"Ignorer ›"}</span></div>`}).join("");
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
