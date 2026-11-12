/* ===================== Section Séries (maquettes Mix B2 + fiche G3 v2) =====================
   accueil : bannière à 5 pages · bande en verre À suivre / Ce soir ? / Cette semaine · Top 10 · Nouveau sur prisme
   · Parce que tu as aimé · Ma liste · Parcourir (Collections / Catégories / Chaînes)
   fiche : progression, saisons (courbe des notes), liste d'épisodes, versions et langue par série, à deux, rappel de saison
   lecteur : résumé automatique, saut d'intro appris, épisode suivant préparé pendant le générique, « Encore un ? »
   Les données des épisodes (titres, notes, dates, versions) viendront du script séries ; sans lui, démonstration. */
/* services de streaming / chaînes : nom unique et rang (les plus utilisés en premier) ; les autres suivent, par nombre de séries */
const SVCS=[["Netflix",/netflix/i],["Apple TV+",/apple ?tv/i],["Prime Video",/prime ?video|amazon/i],["Disney+",/disney ?(\+|plus)/i],["Canal+",/canal ?(\+|plus)/i],["Max",/^(hbo|max)\b/i],["Paramount+",/paramount/i],
 ["France TV",/^france ?([2-5]|tv|\.tv|t[ée]l[ée]visions?|o)$/i],["TF1",/^tf1/i],["M6",/^(m6|6play)/i],["Arte",/^arte/i],["OCS",/^ocs/i],["Crunchyroll",/crunchyroll/i],["BBC",/^bbc/i],["AMC",/^amc/i]];
const SVCN=n=>{if(!n)return "";const x=SVCS.find(([,r])=>r.test(n));return x?x[0]:n};
const SVCR=n=>{const i=SVCS.findIndex(([k])=>k===n);return i<0?99:i};
window.SXLG=window.SXLG||{};
(()=>{
const DEMO=()=>!REAL;
const Q=s=>s.replace(/\.([A-Za-z_][\w-]*)/g,(m,c)=>"."+(FXR[c]||c));
const qs=s=>view.querySelector(Q(s)),qa=s=>[...view.querySelectorAll(Q(s))];
const X={ask:null,h1i:0,hdir:null,prep:null,alt:[],slide:null,skel:false,skelDone:false,cache:{},fv:"eps"};
const sxOn=()=>inApp()&&topS().t==="home"&&S.tab==="series"&&!P;
const ficheOn=()=>inApp()&&topS().t==="detail"&&ALL[topS().id]&&ALL[topS().id].type==="s"&&!P;
const SET=()=>{S.set=S.set||{};const d={recap:7,skip:1,spo:1,binge:3};S.set.sx=Object.assign({},d,S.set.sx||{});return S.set.sx};
const NOW=()=>nowMin(),D=m=>fxD(m),SE=(s,e)=>`S${s} · É${e}`;
const DAYS=["dimanche","lundi","mardi","mercredi","jeudi","vendredi","samedi"];
const dayOf=j=>{const d=new Date();d.setDate(d.getDate()+j);return d};
const dayLbl=j=>j===0?"Aujourd'hui":j===-1?"Hier":j===1?"Demain":DAYS[dayOf(j).getDay()][0].toUpperCase()+DAYS[dayOf(j).getDay()].slice(1);
const ago=d=>d===0?"aujourd'hui":d===1?"hier":`il y a ${d} j`;

/* ---------- les séries ---------- */
const blk=it=>{const m=fxMax();return m!=null&&fxAgeOf(it)>m};
const SL=()=>series().filter(it=>!blk(it));
const EPS=it=>it.se&&it.se.length?it.se:[1],ED=it=>it.ep||45,NS=it=>EPS(it).length,NE=it=>EPS(it).reduce((a,b)=>a+b,0);
const NET=it=>it.net||"";
const FR=it=>(it.cat||[]).includes("fr");
const ST=it=>it.st||(DEMO()?({s4:"terminée",s5:"terminée",s7:"terminée",s3:"terminée",s2:"terminée",s9:"terminée",s8:"terminée",s10:"terminée"})[it.id]||"en cours":"");

/* ---------- ce que le profil regarde (gardé par profil) ---------- */
function MX(pid){const p=PR.list[pid||PR.cur];if(!p)return {sp:{},done:[],duo:{},skip:{},lang:{},mal:[],fmem:{},no:[],nseen:[],ord:null,hid:[],rems:[]};
 if(!p.sx){p.sx={sp:{},done:[],duo:{},skip:{},lang:{},mal:[],fmem:{},no:[],nseen:[],ord:null,hid:[],rems:[],last:0};if(DEMO())seed(p,pid||PR.cur)}
 const x=p.sx;if(!x.ord)x.ord=KEYS.slice();for(const k of KEYS)if(!x.ord.includes(k))x.ord.push(k);return x}
const DAY=864e5;
/* démonstration : des rôles répartis sur les séries disponibles (en cours, à deux, hebdomadaire, épisode manquant,
   en pause, finie…), en laissant libres les nouveautés pour la bannière et « Ce soir ? » */
function roles(){const p=PR.list[Object.keys(PR.list)[0]];if(p&&p.sx&&p.sx.demo)return p.sx.demo;const av=series().map(i=>i.id),nw=av.filter(id=>{const a=added(id);return a&&a.d<=14});
 const c=[...av.filter(id=>!nw.includes(id)&&ED(ALL[id])>35),...av.filter(id=>!nw.includes(id)&&ED(ALL[id])<=35)],R={};
 ["prog","duo","week","miss","done","pause","full"].forEach((k,i)=>{if(i<4||c.length>=7+i-4)R[k]=c.shift()});return R}
function seed(p,pid){const x=p.sx,now=Date.now(),R=roles();x.demo=R;const ep=(id,s)=>EPS(ALL[id])[s-1]||1,last=id=>NS(ALL[id]),main=pid===Object.keys(PR.list)[0];
 if(!main){if(R.duo){const s=Math.min(2,last(R.duo));x.sp[R.duo]={s,e:Math.max(1,Math.min(3,ep(R.duo,s))),pos:0,t:now-2*DAY}}return}
 if(R.prog){const s=Math.min(2,last(R.prog));x.sp[R.prog]={s,e:Math.min(3,ep(R.prog,s)),pos:.45,t:now-DAY}}
 if(R.duo){const s=Math.min(2,last(R.duo));x.sp[R.duo]={s,e:Math.min(4,ep(R.duo,s)),pos:.3,t:now-2*DAY};const o=Object.keys(PR.list).find(k=>k!==pid);if(o)x.duo[R.duo]=o}
 if(R.week){const s=last(R.week);x.sp[R.week]={s,e:Math.min(3,ep(R.week,s)),pos:0,t:now-3*DAY}}
 if(R.miss){const s=Math.min(2,last(R.miss));x.sp[R.miss]={s,e:Math.min(4,ep(R.miss,s)),pos:0,t:now-6*DAY}}
 if(R.done)x.done.push(R.done);
 if(R.pause)x.sp[R.pause]={s:1,e:Math.min(5,ep(R.pause,1)),pos:.1,t:now-41*DAY};
 if(R.full){const s=last(R.full);x.sp[R.full]={s,e:1,pos:0,t:now-9*DAY}}}
const spOf=it=>MX().sp[it.id],isDone=it=>MX().done.includes(it.id);
const jOf=it=>{const p=spOf(it);return p?Math.floor((Date.now()-(p.t||Date.now()))/DAY):0};
/* sorties de la semaine (démonstration : relatives à aujourd'hui ; avec le script séries : dates TMDB) */
function WEEK(){if(!DEMO())return (window.SXDATA&&SXDATA.week)||[];const k="wk|"+new Date().toDateString()+"|"+PR.cur;if(X.cache[k])return X.cache[k];const W=[],R=roles(),x=MX(Object.keys(PR.list)[0]);
 if(R.week&&x.sp[R.week]){const it=ALL[R.week],s=x.sp[R.week].s,n=EPS(it)[s-1],e0=x.sp[R.week].e;W.push({j:-1,id:R.week,s,e:e0});if(e0+1<=n)W.push({j:3,id:R.week,s,e:e0+1,h:"09:00"})}
 if(R.full)W.push({j:-2,id:R.full,s:NS(ALL[R.full]),full:1});
 if(R.prog&&x.sp[R.prog]){const it=ALL[R.prog],s=x.sp[R.prog].s;W.push({j:-3,id:R.prog,s,e:Math.max(1,x.sp[R.prog].e-1),seen:1})}
 const fr=series().map(i=>i.id).find(id=>!Object.values(R).includes(id)&&!x.sp[id]);if(fr)W.push({j:1,id:fr,s:1,e:1,h:"21:00",nf:1});
 return X.cache[k]=W}
const MISSING=()=>{if(!DEMO())return {};const R=roles();if(!R.miss)return {};const s=Math.min(2,NS(ALL[R.miss]));return {[R.miss]:{s,e:Math.min(4,EPS(ALL[R.miss])[s-1])}}};
const GAPS=()=>{if(!DEMO())return {};const R=roles();if(!R.prog)return {};const s=Math.min(2,NS(ALL[R.prog]));return {[R.prog]:{s,e:Math.min(EPS(ALL[R.prog])[s-1],4),from:"Nova",miss:(S.playlists[0]||{}).name||"ton fournisseur"}}};
function nextEp(it){const E=EPS(it),f=Math.max(1,E.findIndex(x=>x>0)+1),p=spOf(it);if(!p)return {s:f,e:1,pos:0};let {s,e,pos}=p;while(s<=E.length&&e>(E[s-1]||0)){s++;e=1;pos=0}if(s>E.length){s=E.length;e=Math.max(1,E[s-1])}return {s,e,pos:pos||0}}
const availTo=it=>{const n=nextEp(it),f=WEEK().filter(w=>w.id===it.id&&w.j>0&&w.s===n.s&&!w.full).map(w=>w.e);return f.length?Math.min(...f)-1:EPS(it)[n.s-1]};
const leftInSeason=it=>{const n=nextEp(it);return Math.max(1,availTo(it)-n.e+1)};
const weekly=it=>WEEK().some(w=>w.id===it.id&&w.j>0);
const epLeft=it=>{const n=nextEp(it);return Math.round(ED(it)*(1-(n.pos||0)))};
const sProg=it=>{if(isDone(it))return 1;const p=spOf(it);if(!p)return 0;const n=nextEp(it),E=EPS(it);let d=0;for(let i=0;i<n.s-1;i++)d+=E[i];return (d+n.e-1+(n.pos||0))/NE(it)};
const missOf=it=>{const m=MISSING()[it.id],n=nextEp(it);return m&&m.s===n.s&&m.e===n.e?m:null};
const gapOf=(it,s,e)=>{const g=GAPS()[it.id];return g&&g.s===s&&g.e===e?g:null};
const needRecap=it=>SET().recap&&spOf(it)&&jOf(it)>=SET().recap;
const isWait=it=>{const p=spOf(it);if(!p)return false;const n=nextEp(it);return n.e>availTo(it)};
const bed=()=>{const L=(FXS.duo||[PR.cur]).map(id=>PR.list[id]&&PR.list[id].bed).filter(x=>x!=null);const b=L.length?Math.min(...L):23*60;return b<300?b+1440:b};

/* ---------- épisodes : titres, notes, versions (démonstration ou script séries) ---------- */
const EPN=["Le pacte","Sous la surface","Ce qui reste","La ligne rouge","Point de non-retour","Les absents","Nuit blanche","Le choix","Contre-jour","La relève","Tout recommencer","L'autre rive"];
const SYNS=["Une décision prise dans l'urgence oblige chacun à choisir son camp.","Un visiteur inattendu remet en cause un équilibre déjà fragile.","Une vieille histoire refait surface au pire moment.","Tout se joue en une seule nuit, sans droit à l'erreur.","Un plan qui semblait parfait commence à se fissurer.","Les apparences tombent lors d'un dîner qui tourne mal.","Une alliance improbable se forme pour sauver ce qui peut l'être.","Un choix impossible, et des conséquences pour tout le monde."];
const EPD=(it,s,e)=>window.SXDATA&&SXDATA.ep&&SXDATA.ep[it.id]&&(SXDATA.ep[it.id][s+"-"+e]||null);
const EPT=(it,s,e)=>{const d=EPD(it,s,e);return d&&d.t?d.t:DEMO()?EPN[hash(it.id+s+"-"+e)%EPN.length]:"Épisode "+e};
const EPS_=(it,s,e)=>{const d=EPD(it,s,e);return d&&d.o?d.o:DEMO()?SYNS[hash(it.id+"#"+s+"-"+e)%SYNS.length]:""};
const epR=(it,s,e)=>{const d=EPD(it,s,e);if(d&&d.r)return d.r;return DEMO()?Math.round(73+hash(it.id+"r"+s+"-"+e)%20)/10:null};
function avail(it,s,e){if(!DEMO()){const T=new Set(srcs(it.id).map(fxTag));return {vff:T.has("VFF")||T.has("VF")||T.has("MULTI"),vf:T.has("VF")||T.has("VFF")||T.has("VFQ")||T.has("MULTI"),vost:T.has("VOSTFR")||T.has("VO")}}
 const k=hash(it.id+"av"+s+"-"+e),fr=FR(it);return {vff:fr||k%6!==0,vf:fr||k%6!==0||k%3!==0,vost:!fr||k%4!==0}}
function verOf(it,s,e){const g=gapOf(it,s,e);let v;if(!DEMO()){const sv=pickSrc(it.id)||{};v={lang:sv.fr||fxTag(sv)||"VF",q:sv.q||"HD",prov:sv.p?sv.p.name:"ton fournisseur"}}
 else{const L=[{lang:"VFF",q:"4K HDR",prov:"Nova"},{lang:"VFF",q:"1080p",prov:(S.playlists[0]||{}).name||"Lune"},{lang:"VF",q:"4K",prov:"Atlas"}];v={...L[hash(it.id+s+"/"+e)%3]}}
 if(g){v.prov=g.from;v.gap=g.miss}const A=avail(it,s,e),w=MX().lang[it.id];if(w==="VOSTFR"&&A.vost)v.lang="VOSTFR";else if(w==="VF"&&A.vf)v.lang="VF";else if(w==="VFF"&&A.vff)v.lang="VFF";else if(DEMO()&&!A.vff)v.lang=A.vf?"VF":"VOSTFR";return v}
const SREC={s4:["Walter s'enfonce un peu plus dans sa double vie.","Jesse veut sortir du trafic, mais rien n'est simple.","Skyler commence à poser les bonnes questions."],s10:["Logan reprend la main sur Waystar Royco.","Kendall cherche sa place après sa trahison.","Shiv hésite sur l'offre qu'on lui a faite."],s1:["Assane a un coup d'avance, mais la police aussi.","Sa famille est de nouveau en danger.","Un nouveau casse se prépare."],s6:["Le groupe est séparé entre plusieurs villes.","Un nouveau danger plane sur Hawkins.","Chacun cache quelque chose aux autres."],s2:["Malotru a été exfiltré, mais à quel prix.","La DGSE fait le ménage dans ses rangs.","Une nouvelle mission commence pour le Bureau."],s9:["Laure Berthaud reprend une enquête difficile.","Les juges et la police se méfient les uns des autres.","Un témoin clé disparaît."],s3:["L'agence perd un client majeur.","Andréa cache une nouvelle importante à ses associés.","Un tournage tourne mal."],s11:["Morgane s'installe à la brigade, à sa façon.","Karadec finit par lui faire confiance.","Une affaire de famille complique tout."]};
const recap=it=>SREC[it.id]||(DEMO()?["L'épisode précédent se termine sur une décision qui change tout.","Un personnage secondaire prend une place inattendue.","Tout reprend là où tu t'es arrêté."]:(()=>{const n=nextEp(it),o=EPS_(it,n.s,Math.max(1,n.e-1));return o?[o]:[`Dernier épisode vu : ${SE(n.s,Math.max(1,n.e-1))}${EPD(it,n.s,Math.max(1,n.e-1))&&EPD(it,n.s,Math.max(1,n.e-1)).t?" · "+EPD(it,n.s,Math.max(1,n.e-1)).t:""}`,"Pas de résumé pour cet épisode, ni chez ton fournisseur ni sur TMDB."]})());
function epInfo(it,s,e){const n=nextEp(it),p=spOf(it),done=isDone(it),seen=done||!!(p&&(s<n.s||(s===n.s&&e<n.e)));
 const cur=!done&&!!p&&s===n.s&&e===n.e,w=WEEK().find(z=>z.id===it.id&&z.s===s&&z.e===e),fut=!seen&&s===n.s&&e>availTo(it)?(w||{h:"bientôt"}):null;
 const M=MISSING()[it.id],RE=!DEMO()&&window.SXDATA&&SXDATA.ep&&SXDATA.ep[it.id],miss=!!(M&&M.s===s&&M.e===e)||!!(RE&&!RE[s+"-"+e]),gap=gapOf(it,s,e),k=hash(it.id+"#"+s+"-"+e),d=EPD(it,s,e);
 const ahead=!seen&&!cur&&(s>n.s||e>n.e+1);
 return {s,e,t:EPT(it,s,e),d:d&&d.d?d.d:ED(it)+(DEMO()?(k%9)-4:0),seen,cur,pos:cur?n.pos:0,fut,nw:!!(w&&w.j<=0&&!w.seen&&!seen),miss,gap,syn:EPS_(it,s,e),hue:(k%50)-25,spo:SET().spo&&ahead}}
const epSt=I=>I.miss?["ms","MANQUANT"]:I.fut?["fu","À VENIR"]:I.nw?["nw","NOUVEAU"]:I.cur?["cu",I.pos?"EN COURS":"À SUIVRE"]:I.seen?["vu","✓ VU"]:["",""];
const seasonSeen=(it,s)=>Array.from({length:EPS(it)[s-1]},(_,i)=>epInfo(it,s,i+1)).every(I=>I.seen);
const spNextEp=(it,s,e)=>{if(e+1<=EPS(it)[s-1])return {s,e:e+1};for(let t=s+1;t<=NS(it);t++)if(EPS(it)[t-1]>0)return {s:t,e:1};return null};
function setSp(it,s,e,pos){const x=MX();x.done=x.done.filter(z=>z!==it.id);x.sp[it.id]={s,e,pos:pos||0,t:Date.now()};prSave()}

/* ---------- goûts : genres des séries finies ou bien avancées ---------- */
function taste2(){const g={};for(const it of SL())if(isDone(it)||sProg(it)>.3)(it.g||[]).forEach(x=>g[x]=(g[x]||0)+1);
 /* goûts appris par le test (Réglages › Profils › Mes goûts) */
 if(window.gtTaste){const t=gtTaste();for(const k in t)g[k]=(g[k]||0)+t[k]*.8}for(const k in g)if(g[k]<0)delete g[k];return g}
function sFor(){const ck="fy|"+PR.cur+"|"+SERIES.length+"|"+JSON.stringify(MX().sp).length+MX().done.length+"|"+MX().no.length+"|"+((ME().taste||{}).at||0);if(X.cache[ck])return X.cache[ck];const g=taste2(),tot=Object.values(g).reduce((a,b)=>a+b,0)||1;
 return X.cache[ck]=SL().filter(it=>!MX().no.includes(it.id)&&!(window.gtNever&&gtNever(it))).map(it=>{const m=(it.g||[]).reduce((a,k)=>a+(g[k]||0),0)/tot;return {c:it,pct:Math.max(40,Math.min(97,Math.round(55+m*40+(it.imdb-7.5)*8))),why:m>.5?`Tes genres : ${(it.g||[]).filter(k=>g[k]).join(", ")}`:`★ ${it.imdb} · très bien notée`}}).sort((a,b)=>b.pct-a.pct)}
const pmap=()=>{const m={};sFor().forEach(o=>m[o.c.id]=o);return m};
function sUp(){return (RMEMO.sxup||(RMEMO.sxup=sUp0())).slice()}
function sUp0(){const x=MX(),av=new Set(series().map(i=>i.id));return Object.keys(x.sp).map(id=>ALL[id]).filter(it=>it&&av.has(it.id)&&!blk(it)&&!isDone(it)&&jOf(it)<30&&!(isWait(it)&&!WEEK().some(w=>w.id===it.id&&w.j<=0&&!w.seen&&!w.full&&w.e===nextEp(it).e))).sort((a,b)=>(spOf(b).t||0)-(spOf(a).t||0))}
const sStale=()=>(RMEMO.sxst||(RMEMO.sxst=sStale0())).slice();const sStale0=()=>{const av=new Set(series().map(i=>i.id));return Object.keys(MX().sp).map(id=>ALL[id]).filter(it=>it&&av.has(it.id)&&!blk(it)&&!isDone(it)&&jOf(it)>=30)};
const added2=it=>{const r=it._real;if(r&&r.a)return Math.max(0,Math.floor((Date.now()/1000-r.a)/86400));const a=added(it.id);return a?a.d:999};
function sNew(){return SL().map(it=>({it,d:added2(it)})).filter(x=>x.d<=14&&!MX().no.includes(x.it.id)).sort((a,b)=>a.d-b.d||b.it.imdb-a.it.imdb).slice(0,12)}
function sTop(){return (RMEMO.sxtop||(RMEMO.sxtop=sTop0())).slice()}
function sTop0(){const T=window.SXDATA&&SXDATA.top;if(T&&T.length)return T.map(id=>ALL[id]).filter(it=>it&&!blk(it)).slice(0,10).map((it,i)=>({it,rk:i+1,mv:"="}));
 return SL().slice().sort((a,b)=>trendScore(b)-trendScore(a)).slice(0,10).map((it,i)=>{const h=hash(it.id+"#mv")%7;return {it,rk:i+1,mv:h===0?"NOUV":h<3?"▲"+(h+1):h<5?"▼"+(h-2):"="}})}
const isNew=id=>{const x=MX();if(x.nseen.includes(id))return false;const it=ALL[id];if(!it)return false;if(added2(it)<=7)return true;return WEEK().some(w=>w.id===id&&w.j<=0&&!w.seen)};

/* ---------- « Ce soir ? » : le temps décide du nombre d'épisodes ---------- */
const STIME=[["ep","1 épisode"],["soir","Ma soirée"],["we","Le week-end"]];
function sPlan(it){const n=nextEp(it),now=NOW(),b=bed(),t=S.sxt||"soir",p=spOf(it);
 if(t==="ep"){const d=p?epLeft(it):ED(it);return {n:1,end:now+d,lbl:"1 épisode"}}
 if(t==="we"){const rest=NE(it)-Math.round(sProg(it)*NE(it)),h=rest*ED(it)/60;return {n:rest,end:null,lbl:`${rest} épisodes`,bdg:`${Math.round(h)} h`}}
 const room=Math.max(0,b-now),first=p?epLeft(it):ED(it),k=room<first?1:Math.min(1+Math.floor((room-first)/ED(it)),p?leftInSeason(it):EPS(it)[0],4);return {n:k,end:now+first+(k-1)*ED(it),lbl:`${k} épisode${k>1?"s":""}`}}
function heroIds(){return new Set(slides().flatMap(s=>s.ids||[]))}
function sRes(){const ck="res|"+(S.sxt||"soir")+"|"+(S.fhm||"")+"|"+(FXS.duo||[]).join()+"|"+JSON.stringify(MX().sp).length+"|"+X.h1i;if(X.cache[ck])return X.cache[ck];
 const m=MOODS.find(x=>x[0]===S.fhm),t=S.sxt||"soir",HI=heroIds(),NW=new Set(sNew().map(x=>x.it.id));
 return X.cache[ck]=sFor().filter(o=>{const it=o.c;if(isDone(it)||spOf(it)||HI.has(it.id)||NW.has(it.id))return false;if(m&&!m[3](it))return false;if(t==="we")return ST(it)==="terminée"||NS(it)===1||NE(it)<=16;return true})}
const SNT=6;

/* ---------- cartes ---------- */
const KEYS=["top","new","bec","liste","browse"];
const NAMES={top:"Top 10 séries",new:"Nouveau sur prisme",bec:"Parce que tu as aimé…",liste:"Ma liste",browse:"Parcourir"};
const pct=o=>o&&o.pct?`<span class="pct">${o.pct} %</span>`:"";
function spst(it,fid,row,o,plan){const p=spOf(it),pg=sProg(it),pl=plan?sPlan(it):null,late=pl&&pl.end&&pl.end>bed(),n=nextEp(it);
 return fxPst(it,fid,"sxopen:"+it.id,row,`data-hid="${it.id}"`).replace('<span class="seen">✓ Vu</span>',"").replace('<div class="pt">',`${pct(o)}${pl?`<span class="fint ${late?"late":""}">${pl.end?"fin "+fmt(pl.end%1440)+(late?"":" ☾"):pl.bdg}</span>`:""}${isDone(it)?'<span class="seen">✓ Vue</span>':""}${isNew(it.id)?'<i class="ndot"></i>':""}<div class="pt">`)
  .replace(/<div class="py">[^<]*<\/div>/,`<div class="py">${pl?pl.lbl:p?SE(n.s,n.e):NS(it)+" saison"+(NS(it)>1?"s":"")}</div>`).replace(/<div class="bar">.*?<\/div>/,"")+"";}
function rcpHtml(it){const n=nextEp(it),L=recap(it),k=n.pos?`JUSQU'ICI DANS ${SE(n.s,n.e)}`:n.e===1&&n.s>1?`FIN DE LA SAISON ${n.s-1}`:`PRÉCÉDEMMENT · ${SE(n.s,Math.max(1,n.e-1))}`;
 return `<div class="rcp"><div class="k">${k}</div><ul>${L.map(t=>`<li>${esc(t)}</li>`).join("")}</ul></div>`}
function supn(it,fid,row,paused){const n=nextEp(it),p=spOf(it),l=epLeft(it),w=WEEK().find(z=>z.id===it.id&&z.j<=0&&!z.seen&&z.e===n.e&&z.s===n.s),ms=missOf(it),gp=gapOf(it,n.s,n.e),du=MX().duo[it.id],rc=needRecap(it),v=verOf(it,n.s,n.e);
 const sub=ms?`É${n.e} pas encore chez ton fournisseur`:n.pos?`reste ${D(l)}`:gp?`É${n.e} complété depuis ${gp.from}`:w?`nouvel épisode · ${dayLbl(w.j).toLowerCase()}`:rc?`⏮ résumé auto · vu il y a ${jOf(it)} j`:n.e===1&&n.s>1?`saison ${n.s} · début`:`épisode suivant · ${D(ED(it))}`;
 const tag=paused?`<span class="tagp ps">EN PAUSE · ${jOf(it)} J</span>`:ms?'<span class="tagp ms">MANQUANT</span>':w?'<span class="tagp nw">NOUVEAU</span>':n.e===1&&n.s>1?'<span class="tagp">SAISON '+n.s+'</span>':"";
 return `<div class="lcd sup ${ms?"miss":""}" data-f data-fid="${fid}" data-act="${ms?"sxmiss:"+it.id:"sxplay:"+it.id}" data-row="${row}" data-hid="${it.id}">${fxArt(it)}<div class="sh2"></div><div class="tgs">${tag}${du&&PR.list[du]?`<span class="duo">👥 avec ${esc(PR.list[du].n)}</span>`:""}</div>${ms?`<span class="vq">${MX().mal.includes(it.id)?"🔔 alerte activée":"🔔 OK = m'avertir"}</span>`:`<span class="vq">${v.lang} · ${v.q}</span>`}<div class="t"><small class="se">${SE(n.s,n.e)}</small><b>${esc(it.t)}</b><span>${sub}</span></div>${n.pos?`<div class="pb"><i style="width:${n.pos*100}%"></i></div>`:""}<div class="ply">${ms?"🔔":FXI.play}</div>${rcpHtml(it)}</div>`}
function calTiles(p){return [-3,-2,-1,0,1,2,3].map(j=>{const L=WEEK().filter(z=>z.j===j&&ALL[z.id]&&!blk(ALL[z.id]));
 const a=L.length?(j<=0&&!L[0].seen?"sxplay:"+L[0].id:j>0?"sxrem:"+L[0].id+":"+j:"sxopen:"+L[0].id):"",nw=L.some(z=>z.j<=0&&!z.seen&&isNew(z.id));
 const eps=L.map(z=>{const it=ALL[z.id];return `<div class="cep ${z.seen?"vu":""}"><i style="--a:${it.c[0]}"></i><b>${esc(it.t)}</b><span>${z.full?`saison ${z.s} complète`:SE(z.s,z.e)}${z.seen?" · ✓ vu":j>0?" · "+z.h:z.h&&j===0?" · dispo "+z.h:""}${z.nf?" · pas suivie":""}</span>${!z.full&&!z.seen&&SET().spo?`<em class="spo">« ${esc(EPT(it,z.s,z.e))} »</em>`:""}</div>`}).join("");
 return `<div class="cday ${j===0?"tod":""} ${j<0?"past":""} ${L.length?"":"emp"}" ${L.length?`data-f data-fid="${p}c-${j}" data-act="${a}" data-row="${p}c" data-hid="${L[0].id}"`:""}><div class="cdl">${dayLbl(j)}<small>${dayOf(j).getDate()}</small></div>${eps||'<div class="cnone">rien</div>'}${nw?'<i class="ndot"></i>':""}</div>`}).join("")}
const allTile=(row,ck,n,kind="p")=>`<div class="allt ${kind}" data-f data-fid="${row}-all" data-act="sxcoll:${ck}" data-row="${row}"><i>›</i><b>Tout voir</b><small>${n} séries</small></div>`;
const sec=(k,title,sub,inner,cls="")=>inner?`<section data-anchor data-rk="${k}" class="hsec ${cls}"><div class="lh">${title}${sub?`<small>${sub}</small>`:""}</div><div class="row sx">${inner}</div></section>`:"";
const mosaic=L=>`<div class="mosa">${L.slice(0,6).map(it=>`<div class="mo">${fxArt(it)}<b class="${fxFont(it)}">${esc(it.t)}</b></div>`).join("")}</div>`;
const stack3=L=>`<div class="cstk">${L.slice(0,3).map(it=>`<i class="cp${it.po?" img":""}" style="--a:${it.c[0]};--b:${it.c[1]};${it.po?`background-image:url(${it.po}),linear-gradient(160deg,${it.c[0]},${it.c[1]})`:""}"></i>`).join("")}</div>`;

/* ---------- collections ---------- */
function colls(){const ck="co|"+PR.cur+"|"+SERIES.length+"|"+MX().no.length+"|"+MX().done.length;if(X.cache[ck])return X.cache[ck];const av=SL().filter(it=>!MX().no.includes(it.id)),C=[];
 C.push({k:"soir",n:"Ce soir",ic:"🌙",why:"Selon ton temps, ton envie et avec qui tu regardes",items:()=>sRes().map(o=>o.c)});
 C.push({k:"nouveau",n:"Nouveau sur prisme",ic:"✦",why:"Les séries ajoutées ces deux dernières semaines",items:()=>sNew().map(x=>x.it)});
 C.push({k:"pourtoi",n:"Pour toi",ic:"✨",why:"Selon les séries que tu as finies ou bien avancées",items:()=>sFor().filter(o=>!isDone(o.c)).map(o=>o.c)});
 C.push({k:"encours",n:"En cours",ic:"↺",why:"Les séries que tu regardes en ce moment",items:()=>sUp()});
 C.push({k:"liste",n:"Ma liste",ic:"＋",why:"Les séries que tu as mises de côté",items:()=>S.favs.map(id=>ALL[id]).filter(it=>it&&it.type==="s"&&srcs(it.id).length)});
 C.push({k:"mini",n:"Mini-séries",ic:"🎯",why:"Une seule saison, une vraie fin",items:()=>av.filter(it=>NS(it)===1)});
 C.push({k:"fini",n:"Terminées, à dévorer",ic:"🍿",why:"Toutes les saisons sont là, pas d'attente entre deux",items:()=>av.filter(it=>ST(it)==="terminée")});
 C.push({k:"court",n:"Épisodes courts",ic:"⏱",why:"Des épisodes de 35 minutes ou moins",items:()=>av.filter(it=>ED(it)<=35)});
 C.push({k:"fr",n:"Séries françaises",ic:"🇫🇷",why:"Produites en France",items:()=>av.filter(FR)});
 C.push({k:"top",n:"★ 8,5 et plus",ic:"🏆",why:"Les mieux notées de ton fournisseur",items:()=>av.filter(it=>it.imdb>=8.5).sort((a,b)=>b.imdb-a.imdb)});
 const nets={};const pcs={};for(const [ck,cn] of SCATS){const sv=SVCS.find(([,r])=>r.test(cn));if(sv)pcs[ck]=sv[0]}
 av.forEach(it=>{const ns=new Set();const n=SVCN(NET(it));if(n)ns.add(n);for(const c of it.cat||[])if(pcs[c])ns.add(pcs[c]);for(const x of ns)(nets[x]=nets[x]||[]).push(it)});Object.entries(nets).sort((p,q)=>SVCR(p[0])-SVCR(q[0])||q[1].length-p[1].length).forEach(([n,L])=>C.push({k:"net:"+n,n,ic:"📡",why:"Chaîne ou plateforme d'origine (TMDB)",items:()=>L,hide:1,net:1}));
 return X.cache[ck]=C}
const coll=k=>colls().find(c=>c.k===k);
const SORT=[["pert","Pertinence"],["note","Note"],["duree","Plus courtes"],["recent","Récentes"]];
function collHtml(k){const c=coll(k)||{n:"Collection",why:"",ic:"",items:()=>[]},s=S.sxsort||"pert";let L=c.items().slice();
 if(s==="note")L.sort((a,b)=>b.imdb-a.imdb);else if(s==="duree")L.sort((a,b)=>NE(a)*ED(a)-NE(b)*ED(b));else if(s==="recent")L.sort((a,b)=>b.y-a.y);
 return `<div class="gview"><div class="ghead"><div class="kick">SÉRIES · ${c.ic||""} COLLECTION</div><h1>${esc(c.n)}</h1><div style="opacity:.7;font-size:16px;margin:-6px 0 12px">${esc(c.why)}</div>
 <div class="chips">${SORT.map(([v,n])=>`<div class="chip ${s===v?"sel":""}" data-f data-fid="fs-${v}" data-row="fsort" data-act="sxsort:${v}">${n}</div>`).join("")}</div></div>
 <div class="gcount">${L.length} série${L.length>1?"s":""}</div><div class="ggrid sy" id="ggrid">${L.map((i,n)=>card(i,"g"+Math.floor(n/7)).replace('data-f ',n===0?'data-f data-default ':'data-f ')).join("")}</div></div>`}

/* ---------- bannière : 5 types de pages, jamais une série déjà proposée plus bas ---------- */
const btn=(i,lbl,a,extra="")=>`<div class="btn ${i===0?"prim":""}" data-f data-fid="sx-b${i}" ${i===0?"data-default":""} data-act="${a}" data-row="sxh" ${extra}>${lbl}</div>`;
function sxTV(){const k="tv|"+Math.floor(NOW()/10)+"|"+SERIES.length;if(X.cache[k])return X.cache[k];
 /* même résultat qu'avant, mais avec l'index des titres du guide (plus de relecture de tout le guide) */
 const idx=new Map();for(const it of SL()){const w=tkey(it.t);if(w.length>=3)idx.set(w,it)}const n=NOW(),I=epgIdx(),av=new Map(chans().map((c,i)=>[c.id,i])),best=new Map();
 for(const [w,it] of idx)for(const x of I.get(w)||[]){const p=x.p;if(p.e<=n||p.s>24*60+120||!av.has(x.c.id))continue;const b=best.get(x.c.id);if(!b||x.pi<b.pi)best.set(x.c.id,{it,c:x.c,p,pi:x.pi})}
 const out=[...best.values()].sort((a,b)=>av.get(a.c.id)-av.get(b.c.id)).slice(0,4).map(({it,c,p})=>({it,c,p,live:p.s<=n,t:p.s<=n?"en direct":(p.s<24*60?"ce soir ":"cette nuit ")+fmt(p.s%1440)}));return X.cache[k]=out}
function slides(){const ck="sl|"+PR.cur+"|"+JSON.stringify(MX().sp).length+MX().done.length+"|"+MX().no.length+"|"+Math.floor(NOW()/30)+"|"+(S.sxAlerts||[]).length+"|"+S.favs.length;if(X.cache[ck])return X.cache[ck];
 const L=[],now=NOW(),eve=now>=17*60&&now<=21*60+30,fresh=it=>it&&!blk(it)&&!spOf(it)&&!isDone(it)&&!MX().no.includes(it.id);
 const nw=sNew().filter(x=>fresh(x.it)),a=nw.sort((p,q)=>q.it.imdb-p.it.imdb)[0];
 if(a){const it=a.it;L.push({k:"arr",ids:[it.id],tr:it,tag:"✦ L'ARRIVÉE DE LA SEMAINE",bg:fxArt(it),title:it.t,font:fxFont(it),
  meta:`<span class="chp" style="--cc:#8b9cff">${esc((added(it.id)||{p:{name:"ton fournisseur"}}).p.name)}</span><span>${ago(a.d)}</span><span>${NS(it)} saison${NS(it)>1?"s":""} · ${NE(it)} ép.</span>${NET(it)?`<span>${esc(NET(it))}</span>`:""}<span class="st">★ ${it.imdb}</span>`,
  sub:"Toute la série est disponible, tu peux commencer ce soir",btns:[[`${FXI.play}<span class="vpill">Commencer ${SE(1,1)}<small>${D(ED(it))} · fin ${fmt((now+ED(it))%1440)}</small></span>`,"sxplay:"+it.id,it.id],["Voir la fiche","sxopen:"+it.id],[isFav(it.id)?"Retirer de ma liste":"Ajouter à ma liste","sxlist:"+it.id]]})}
 const tv=sxTV().filter(x=>fresh(x.it)&&(!a||x.it.id!==a.it.id));
 if(tv.length){const x=tv[0],it=x.it;L.push({k:"tv",ids:[it.id],tr:it,tag:"📺 CE SOIR À LA TÉLÉ",bg:fxArt(it),title:it.t,font:fxFont(it),
  meta:`<span class="chp" style="--cc:${x.c.col}">${esc(x.c.n)}</span><span>${esc(x.t)}</span><span>${NS(it)} saisons</span><span class="st">★ ${it.imdb}</span>`,
  sub:`À la télé ${x.live?"en ce moment":x.t}, ou dès maintenant sans pub, à ton rythme`,btns:[[`${FXI.play}<span class="vpill">Sans pub, maintenant<small>${SE(1,1)} · ${D(ED(it))}</small></span>`,"sxplay:"+it.id,it.id],[x.live?`📺 Regarder sur ${x.c.n}`:`📺 Me rappeler à ${fmt(x.p.s%1440)}`,"fhtv:"+x.c.id+":"+x.p.s],["Voir la fiche","sxopen:"+it.id]]})}
 const wd=new Date().getDay();let we=wd===5||wd===6||wd===0;if(!we&&SL().filter(it=>ED(it)<=35).length<3)we=true;const mi=we?SL().filter(it=>!isDone(it)&&(NS(it)===1||ST(it)==="terminée")):SL().filter(it=>ED(it)<=35);
 if(mi.length>=3)L.push({k:"mom",ids:[],tr:mi[0],tag:we?"🍿 LE WEEK-END · À DÉVORER":"⏱ EN SEMAINE · ÉPISODES COURTS",bg:mosaic(mi),title:we?"🍿 Séries à finir ce week-end":"⏱ Un épisode, pas plus",font:"",big:1,
  meta:`<span>${mi.length} séries</span><span>${mi.slice(0,3).map(it=>esc(it.t)).join(" · ")}</span>`,sub:we?"Des séries terminées : tout est disponible, avec une vraie fin":"Des épisodes courts pour une soirée de semaine",btns:[["Voir la collection","sxcoll:"+(we?"fini":"court")],["🎲 Une au hasard","sxrand:"+(we?"fini":"court")]]});
 const used=new Set(L.flatMap(s=>s.ids)),nets={};SL().forEach(it=>{const n=SVCN(NET(it));if(n)(nets[n]=nets[n]||[]).push(it)});
 const hn=Object.entries(nets).filter(([n,G])=>G.length>=2).sort((p,q)=>q[1].filter(it=>isDone(it)||spOf(it)).length-p[1].filter(it=>isDone(it)||spOf(it)).length||q[1].length-p[1].length)[0];
 if(hn){const [n,G]=hn,seen=G.filter(it=>isDone(it)||spOf(it)),pm=pmap(),nx=G.filter(it=>fresh(it)&&!used.has(it.id)).sort((p,q)=>(pm[q.id]?.pct||0)-(pm[p.id]?.pct||0))[0];
  if(nx)L.push({k:"hon",ids:[nx.id],tr:nx,tag:"📡 À L'HONNEUR CETTE SEMAINE",bg:mosaic(G),title:"Les séries "+n,font:"",big:1,meta:`<span>${G.length} séries chez ton fournisseur</span><span>tu en as vu ${seen.length}</span>`,
   sub:`La prochaine à voir selon toi : <b>${esc(nx.t)}</b>`,btns:[[`${FXI.play}<span class="vpill">${esc(nx.t)}<small>${SE(1,1)} · ${D(ED(nx))}</small></span>`,"sxplay:"+nx.id,nx.id],["Toutes les séries "+esc(n),"sxcoll:net:"+n]]})}
 const so=DEMO()?MX().done.map(id=>ALL[id]).filter(Boolean)[0]:null;
 if(so){const al=(S.sxAlerts||[]).includes(so.id);L.push({k:"soon",ids:[],tr:so,trs:NS(so)+1,tag:"🔔 BIENTÔT CHEZ TOI",bg:fxArt(so),title:so.t,font:fxFont(so),
  meta:`<span class="chp" style="--cc:#5ee0c8">Saison ${NS(so)+1}</span>${NET(so)?`<span>${esc(NET(so))}</span>`:""}<span class="ok2">diffusion annoncée</span>`,
  sub:"Tu as tout vu. prisme te prévient dès que le premier épisode arrive chez ton fournisseur",btns:[[al?"✓ Alerte activée":"🔔 Préviens-moi","sxalert:"+so.id],["▶ Bande-annonce","sxtrl:"+so.id+":"+(NS(so)+1)]]})}
 const ord=eve?["tv","arr","mom","hon","soon"]:["arr","mom","hon","tv","soon"],out=ord.map(k=>L.find(s=>s.k===k)).filter(Boolean);
 /* petit catalogue où rien d'autre ne s'applique : la série à reprendre, sinon la mieux notée */
 if(!out.length){const fr=SL().filter(z=>!spOf(z)&&!isDone(z)&&!blk(z)&&!WEEK().some(w=>w.id===z.id)).sort((p,q)=>q.imdb-p.imdb)[0],up=fr?null:sUp()[0],it=fr||up;if(it){const n=nextEp(it);
  out.push({k:"rep",ids:[it.id],tr:it,tag:up?"↺ ON REPREND ?":"★ LA MIEUX NOTÉE CHEZ TOI",bg:fxArt(it),title:it.t,font:fxFont(it),meta:`<span>${NS(it)} saison${NS(it)>1?"s":""} · ${NE(it)} ép.</span>${NET(it)?`<span>${esc(NET(it))}</span>`:""}<span class="st">★ ${it.imdb}</span>`,
   sub:esc((it.s||"").slice(0,160)),btns:[[`${FXI.play}<span class="vpill">${up?"Reprendre":"Commencer"} ${SE(n.s,n.e)}<small>${D(ED(it))}</small></span>`,"sxplay:"+it.id,it.id],["Voir la fiche","sxopen:"+it.id]]})}}
 return X.cache[ck]=out}
function hero(){const L=slides();if(!L.length)return `<section class="hero h1h mchero c3h" data-anchor><div class="shade"></div><div class="tx"><h1 class="t2">Séries</h1><p class="hsub">Ajoute une playlist dans Réglages pour voir tes séries ici.</p></div></section>`;
 const i=(X.h1i%L.length+L.length)%L.length,s=L[i];X.alt=s.btns.slice(1);X.slide=s;const m=s.btns[0],trS=s.trs||(s.tr&&spOf(s.tr)?nextEp(s.tr).s:1);
 return `<section class="hero h1h mchero c3h hs-${s.k}" data-anchor>${s.bg}<div class="shade"></div>
 <div class="tx ${X.hdir==="right"?"inr":X.hdir==="left"?"inl":""}"><div class="htag">${s.tag}</div><h1 class="${s.font} t2" style="font-size:${s.big?62:Math.round(titleSize({t:s.title,f:s.tr?s.tr.f:""})*.8)}px">${esc(s.title)}</h1>
  <div class="meta">${s.meta}</div><p class="hsub">${s.sub}</p><div class="acts">${btn(0,m[0],m[1],m[2]?`data-hid="${m[2]}"`:"")}</div>
  ${X.alt.length?`<div class="hmore">OK maintenu · plus d'options</div>`:""}</div>
 <div class="htrl glass">▶ BANDE-ANNONCE ${s.tr?`· ${esc(s.tr.t)} · saison ${trS} · VF`:""}<span>${fhSet().fhVol==="coupe"?"🔇 son coupé":fhSet().fhVol==="faible"?"🔉 son faible":"🔊 son normal"} · une touche pour revenir</span></div><div class="hcd glass">Bande-annonce dans <b>3</b></div>
 <div class="hnav l">‹</div><div class="hnav r">›</div><div class="dots">${L.map((x,j)=>`<i class="${j===i?"on":""}"></i>`).join("")}<i class="cnt">${i+1} / ${L.length}</i></div></section>`}

/* ---------- la bande en verre : À suivre / Ce soir ? / Cette semaine ---------- */
const sdTab=()=>S.sxtab||(sUp().length?"suivre":"soir");
function askLbl2(d){if(d==="d")return "⏱ "+STIME.find(x=>x[0]===(S.sxt||"soir"))[1];if(d==="m"){const m=MOODS.find(x=>x[0]===S.fhm);return m?m[2]+" "+m[1]:"✨ Envies"}return FXS.duo?"👥 À deux":"👤 Seul"}
function askChips(){const op=X.ask,ids=Object.keys(PR.list);
 if(op){const L=op==="d"?STIME:op==="m"?[["all","Toutes les envies"],...MOODS.map(x=>[x[0],x[2]+" "+x[1]])]:[["solo","Seul"],...(ids.length>1?[["duo","À deux"]]:[])],cur=op==="d"?(S.sxt||"soir"):op==="m"?(S.fhm||"all"):(FXS.duo?"duo":"solo");
  return L.map(([k,n])=>`<div class="hchip ${cur===k?"sel":""}" data-f data-fid="sx-o-${k}" data-act="sxaset:${op}:${k}" data-row="sxq" ${cur===k?"data-default":""}>${n}</div>`).join("")+`<div class="hchip ghost" data-f data-fid="sx-o-x" data-act="sxax" data-row="sxq">← Retour</div>`}
 return ["d","m","w"].map(d=>`<div class="hchip dd" data-f data-fid="sx-q-${d}" data-act="sxask:${d}" data-row="sxq">${askLbl2(d)}<i>▾</i></div>`).join("")+`<div class="hchip" data-f data-fid="sx-q-dice" data-act="sxdice" data-row="sxq">🎲 Surprends-moi</div>`}
function band(){const t=sdTab(),U=sUp(),stale=sStale(),R=sRes(),nNew=WEEK().filter(w=>w.j<=0&&!w.seen&&ALL[w.id]&&!blk(ALL[w.id])).length,pm=pmap();
 const tabs=[["suivre","↺ À suivre",U.length+stale.length],["soir","🌙 Ce soir ?",""],["cal","📅 Cette semaine",nNew?`<i class="nb">${nNew}</i>`:""]].map(([k,n,c])=>`<div class="btab ${k===t?"sel":""}" data-f data-fid="sxt-${k}" data-sdt="${k}" data-act="sxtab:${k}" data-row="sxq">${n}${c!==""?`<small>${c}</small>`:""}</div>${k==="soir"&&t==="soir"?`<span class="sdsep"></span>${askChips()}<span class="sdsep"></span>`:""}`).join("");
 const row=t==="suivre"?(U.length+stale.length?U.map(it=>supn(it,"sxr-"+it.id,"sxr")).join("")+stale.map(it=>supn(it,"sxr-"+it.id,"sxr",1)).join(""):(DEMO()?`<div class="empty0">Aucune série en cours · choisis-en une dans « Ce soir ? »</div>`:`<div class="empty0 sxex" data-f data-fid="sxr-ex" data-act="sxex" data-row="sxr">Tes séries en cours apparaîtront ici, avec le résumé de là où tu t'es arrêté · <b>OK = voir un exemple avec tes séries</b></div>`))
  :t==="cal"?(WEEK().length?calTiles("sx"):`<div class="empty0">Les dates de sortie arriveront avec les données TMDB des séries</div>`)
  :R.length?R.slice(0,SNT).map(o=>spst(o.c,"sxn-"+o.c.id,"sxnt",o,1)).join("")+(R.length>SNT?allTile("sxnt","soir",R.length):""):`<div class="empty0">Aucune série avec ces choix</div>`;
 return `<div data-anchor class="anc"><section data-rk="soir" class="hsec tonight glassband sbband"><div class="btabs hline sdtabs">${tabs}</div><div class="row sx ${t==="cal"?"calrow sbcal":""} ${t==="suivre"?"sdsup":""}">${row}</div></section></div>`}

/* ---------- la page ---------- */
function rows(){const pm=pmap(),HI=heroIds(),R=sRes(),shown=new Set([...HI,...R.slice(0,SNT).map(o=>o.c.id),...sNew().map(x=>x.it.id),...S.favs]);
 const tp=sTop().map(({it,rk,mv})=>{const c=mv==="NOUV"?"nw":mv[0]==="▲"?"upm":mv[0]==="▼"?"dn":"eq",n=nextEp(it);return `<div class="tp" data-f data-fid="sxk-${it.id}" data-act="sxopen:${it.id}" data-row="sxk" data-hid="${it.id}">${isNew(it.id)?'<i class="ndot"></i>':""}<div class="rk">${rk}</div>${fxPst(it,"","","").replace(/data-f |data-fid="[^"]*" |data-act="[^"]*" |data-row="[^"]*" /g,"").replace('<div class="pt">',`${pct(pm[it.id])}<span class="mv ${c}">${mv==="NOUV"?"NOUVEAU":mv}</span><div class="pt">`).replace(/<div class="py">[^<]*<\/div>/,`<div class="py">${spOf(it)&&!isDone(it)?`<span class="tpe">↺ ${SE(n.s,n.e)}</span>`:isDone(it)?"✓ vue":NS(it)+" saison"+(NS(it)>1?"s":"")}</div>`).replace(/<span class="seen">[^<]*<\/span>/,"")}</div>`}).join("");
 const NWL=sNew().filter(x=>!HI.has(x.it.id)),nw=NWL.map(({it,d})=>`<div class="nwc" data-f data-fid="sxw-${it.id}" data-act="sxopen:${it.id}" data-row="sxw" data-hid="${it.id}">${fxArt(it)}${isNew(it.id)?'<i class="ndot"></i>':""}<div class="sh2"></div><div class="nwt"><span class="nwj">${NS(it)} SAISON${NS(it)>1?"S":""} · ${ago(d)}</span>${pm[it.id]?`<span class="pct2">${pm[it.id].pct} %</span>`:""}</div><div class="t"><b>${esc(it.t)}</b><span>${NE(it)} ép. · ${esc((it.g||[])[0]||"")}${NET(it)?" · "+esc(NET(it)):""}</span></div></div>`).join("");
 let base=null,bec=[];for(const id of MX().done){const b=ALL[id];if(!b)continue;const L=sFor().filter(o=>o.c.id!==id&&!isDone(o.c)&&!spOf(o.c)&&!shown.has(o.c.id)&&(o.c.g||[]).some(g=>(b.g||[]).includes(g)));if(L.length>bec.length){bec=L;base=b}}
 const ml=S.favs.map(id=>ALL[id]).filter(it=>it&&it.type==="s"&&srcs(it.id).length&&!blk(it));
 const nN=NWL.filter(x=>isNew(x.it.id)).length,b=["col","cat","lic"].includes(S.sxbt)?S.sxbt:"col",G=genreList("s"),C=colls().filter(c=>["mini","fini","court","fr","top"].includes(c.k)).map(c=>({c,L:c.items()})).filter(x=>x.L.length>=2),N=colls().filter(c=>c.net);
 const items=b==="col"?C.map(({c,L})=>`<div class="ctile" data-f data-fid="sxe-${c.k}" data-act="sxcoll:${c.k}" data-row="sxx">${stack3(L)}<div class="ct"><em>${c.ic}</em><b>${esc(c.n)}</b><span>${L.length} séries</span></div></div>`).join("")
  :b==="cat"?G.map(({g,items})=>`<div class="gword" style="--cc:${g[2]}" data-f data-fid="sxg-${g[0]}" data-act="genre:s:${g[0]}" data-row="sxx"><b>${esc(g[1])}</b><small>${items.length} séries</small></div>`).join("")
  :N.map(c=>`<div class="lic2" style="--cc:#${((hash(c.n)&0xffffff)|0x404040).toString(16).slice(-6)}" data-f data-fid="sxn-${hash(c.n)}" data-act="sxcoll:${c.k}" data-row="sxx">${SXLG[c.n]?`<img class="lgo" src="${SXLG[c.n]}" alt="">`:`<span class="ph">LOGO</span>`}<b>${esc(c.n)}</b><small>${c.items().length} série${c.items().length>1?"s":""}</small></div>`).join("");
 const browse=`<section data-anchor data-rk="browse" class="hsec browse"><div class="lh">Parcourir</div><div class="btabs hline">${[["col","Collections"],["cat","Catégories"],["lic","Chaînes"]].map(([k,n])=>`<div class="btab ${k===b?"sel":""}" data-f data-fid="sxbt-${k}" data-bt2="${k}" data-act="sxbt:${k}" data-row="sxbt">${n}</div>`).join("")}</div><div class="row sx">${items||'<div class="empty0">Rien pour le moment</div>'}</div></section>`;
 return {top:sec("top","🔥 Top 10 séries","",tp,"topsec"),new:sec("new","✦ Nouveau sur prisme",nN?`<span class="nwc0">● ${nN} nouveau${nN>1?"x":""}</span>`:"",nw?nw+(NWL.length>=12?allTile("sxw","nouveau",NWL.length,"l"):""):""),
  bec:bec.length>=4?sec("bec",`Parce que tu as aimé ${esc(base.t)}`,"",bec.slice(0,10).map(o=>spst(o.c,"sxb-"+o.c.id,"sxb",o)).join("")):"",
  liste:ml.length?sec("liste","Ma liste","",ml.slice(0,12).map(it=>spst(it,"sxl-"+it.id,"sxl",pm[it.id])).join("")):"",browse}}
function view2(){if(X.skel)return fhSkel();const x=MX(),R=rows(),r=x.ord.filter(k=>!x.hid.includes(k)).map(k=>R[k]||"").join("\n");
 return `<div class="H H1 MC C3 SER S1 SB SD sy" id="hscr">${hero()}
 <div class="below mcb">${band()}
 ${r}${x.hid.length?`<div class="hidn">${x.hid.length} rangée${x.hid.length>1?"s":""} masquée${x.hid.length>1?"s":""} · Réglages › Accueil Séries pour les rétablir</div>`:""}<div style="height:40px"></div></div></div>`}
{const _h=homeHtml;homeHtml=function(){if(inApp()&&S.tab==="series"){if(!X.skelDone){X.skelDone=true;X.skel=true;setTimeout(()=>{X.skel=false;if(sxOn()&&!S.modal)render(F&&F.dataset.fid&&!/^tab-/.test(F.dataset.fid)?F.dataset.fid:undefined)},650)}
  return tabbar()+fxC(`<div class="fx fxhome sxhome">${view2()}</div>`)}return _h()}}

/* ===================== FICHE SÉRIE (G3 v2) ===================== */
const fSea=it=>X.fs||nextEp(it).s;
const NETC=n=>"#"+((hash(n||"x")&0xffffff)|0x404040).toString(16).slice(-6);
const CRE=it=>it.dir||"";
function fMeta(it){return `<span>${it.y}</span><span>${NS(it)} saison${NS(it)>1?"s":""}</span><span>${esc((it.g||[]).join(", "))}</span><span>${esc(it.age||"")}</span><span class="st">★ ${it.imdb}</span>${NET(it)?`<span class="chp" style="--cc:${NETC(NET(it))}">${esc(NET(it))}</span>`:""}${ST(it)?`<span>${ST(it)==="terminée"?"série terminée":"en cours de diffusion"}</span>`:""}`}
function fMain(it){const n=nextEp(it),p=spOf(it),I=epInfo(it,n.s,n.e),l=p?epLeft(it):ED(it);
 if(isDone(it))return {lbl:"Revoir depuis le début",sub:`${NS(it)} saison${NS(it)>1?"s":""} · ${NE(it)} épisodes`,act:`sxep:${it.id}:1-1`};
 if(I.miss)return {lbl:`🔔 ${SE(n.s,n.e)} pas encore disponible`,sub:"OK = m'avertir dès son arrivée",act:"sxmiss:"+it.id};
 if(I.fut)return {lbl:`${SE(n.s,n.e)} sort ${I.fut.j!=null?dayLbl(I.fut.j).toLowerCase():"bientôt"}`,sub:"tu es à jour",act:`sxrem:${it.id}:${I.fut.j??1}`};
 return {lbl:`${n.pos?"Reprendre":p?"Regarder":"Commencer"} ${SE(n.s,n.e)}`,sub:`${n.pos?"reste "+D(l):D(I.d)} · fin ${fmt((NOW()+l)%1440)}`,act:"sxplay:"+it.id}}
function fActs(it){const m=fMain(it),n=nextEp(it),v=verOf(it,n.s,n.e);
 return `<div class="acts"><div class="btn prim" data-f data-fid="sf-play" data-default data-act="${m.act}" data-row="sfa" data-hid="${it.id}">${FXI.play}<span class="vpill">${esc(m.lbl)}<small>${esc(m.sub)}</small></span></div>${spOf(it)&&!isDone(it)?`<div class="btn" data-f data-fid="sf-rec" data-act="sxrecap:${it.id}" data-row="sfa">⏮ Résumé 60 s</div>`:""}<div class="btn round" data-f data-fid="sf-list" data-act="sxlist:${it.id}" data-row="sfb" aria-label="Ma liste">${isFav(it.id)?FXI.check||"✓":FXI.plus||"＋"}</div><div class="btn vbtn" data-f data-fid="sf-ver" data-act="sxver:${it.id}" data-row="sfb"><b>${v.lang} · ${String(v.q).split(" ")[0]}</b><small>✓ auto par épisode</small></div><div class="btn round" data-f data-fid="sf-trl" data-act="sxtrl:${it.id}:${n.s}" data-row="sfb" aria-label="Bande-annonce">🎬</div>${window.apSerBtn?apSerBtn(it):""}</div>`}
function fSum(it){const n=nextEp(it),p=spOf(it),rest=isDone(it)?0:NE(it)-Math.round(sProg(it)*NE(it)),ls=p?leftInSeason(it):EPS(it)[0],wk=WEEK().find(z=>z.id===it.id&&z.j>0),pg=sProg(it),R=34,C=2*Math.PI*R;
 const L=isDone(it)?["Tu as tout vu · "+NE(it)+" épisodes"]:!p?[`${NE(it)} épisodes · ${D(NE(it)*ED(it))}`,`environ ${Math.ceil(NE(it)/2)} soirées à 2 ép./soir`]:[`Il te reste <b>${ls} ép.</b> dans la saison ${n.s} · ${D(ls*ED(it))}`,missOf(it)?`🔔 É${n.e} absent chez ton fournisseur`:wk&&ls<=1?`à jour après celui-ci · prochain ${dayLbl(wk.j).toLowerCase()}`:`saison finie <b>${(d=>d<=1?"ce soir":d===2?"demain":DAYS[dayOf(d-1).getDay()])(ls)}</b> à 1 ép./soir`,`<b>${rest} ép.</b> en tout · ${D(rest*ED(it))}`];
 const tot=p?epLeft(it)+(ls-1)*ED(it):0,end=NOW()+tot,late=end>bed(),du=MX().duo[it.id],pt=du&&PR.list[du]&&MX(du).sp[it.id];
 const fin=p&&!isDone(it)&&!missOf(it)&&ls>1?`<div class="btn g4fin ${late?"":"prim"}" data-f data-fid="sf-fin" data-act="sxfin:${it.id}" data-row="sffin">▶ Finir la saison ce soir<small>${ls} ép. · fin ${fmt(end%1440)}${late?" · après ton coucher":" ☾"}</small></div>`:"";
 let duo="";if(pt){const d=(n.s-pt.s)*100+(n.e-pt.e),nm=esc(PR.list[du].n);duo=`<div class="g4duo">${pav(du)}<span>${nm} en est à <b>${SE(pt.s,pt.e)}</b> · ${d===0?"vous êtes au même épisode":d>0?`${d} épisode${d>1?"s":""} de retard`:`${-d} épisode${-d>1?"s":""} d'avance`}</span></div>`}
 const others=Object.keys(PR.list).filter(k=>k!==PR.cur);
 return `<div class="gsum"><div class="trp" style="--a:${it.c[0]};--b:${it.c[1]}"><svg viewBox="0 0 80 80"><circle cx="40" cy="40" r="${R}" class="bg"/><circle cx="40" cy="40" r="${R}" class="fg" style="stroke-dasharray:${C*pg} ${C}"/></svg><em>${Math.round(pg*100)}<small>%</small></em></div><div class="gsl">${L.map(t=>`<div>${t}</div>`).join("")}</div></div>
 ${fin}${duo}${others.length?`<div class="sfduo" data-f data-fid="sf-duo" data-act="sxduo:${it.id}" data-row="sfduo">${du&&PR.list[du]?`👥 Suivie avec ${esc(PR.list[du].n)}`:"👥 La suivre à deux…"}</div>`:""}`}
const topEps=(it,s)=>Array.from({length:EPS(it)[s-1]},(_,i)=>[i+1,epR(it,s,i+1)]).filter(a=>a[1]!=null&&a[1]>=8.6).sort((a,b)=>b[1]-a[1]).slice(0,2).map(a=>a[0]);
function spark(it,s){const n=EPS(it)[s-1];if(epR(it,s,1)==null)return "";const y=r=>(14-(r-7.2)/2.1*12).toFixed(1),xx=i=>n>1?(i/(n-1)*100).toFixed(1):50;
 return `<svg class="spk" viewBox="0 0 100 16" preserveAspectRatio="none"><polyline points="${Array.from({length:n},(_,i)=>xx(i)+","+y(epR(it,s,i+1))).join(" ")}"/>${topEps(it,s).map(e=>`<circle cx="${xx(e-1)}" cy="${y(epR(it,s,e))}" r="1.6"/>`).join("")}</svg>`}
const fLeg=()=>`<div class="f3leg"><span class="vu">✓ vu</span><span class="cu">● à suivre</span><span class="nw">● nouveau</span><span class="fu">○ à venir</span><span class="ms">! manquant</span><span class="gpl">◆ complété</span></div>`;
function gRow(it,I,T,pt,du){const [c,l]=epSt(I),r=epR(it,I.s,I.e),top=T.includes(I.e),n=nextEp(it);
 return `<div class="sf2e ${c} ${I.s===n.s&&I.e===n.e&&!isDone(it)?"sel":""}" data-f data-fid="sfe-${I.s}-${I.e}" data-ep="${I.s}-${I.e}" data-act="sxep:${it.id}:${I.s}-${I.e}" data-row="sfe${I.e}"><div class="sfi"><div class="art" style="--a:${it.c[0]};--b:${it.c[1]};filter:hue-rotate(${I.hue}deg)${I.spo?" blur(6px)":""}"><i></i><i></i><i></i></div>${I.pos?`<div class="pb"><i style="width:${I.pos*100}%"></i></div>`:""}</div>
 <div class="sf2t"><b><span class="${I.spo?"spo":""}">${I.e}. ${esc(I.t)}</span></b><small>${r!=null?`<span class="g4r ${top?"top":""}">★ ${String(r).replace(".",",")}${top?" · à ne pas manquer":""}</span> · `:""}${I.d} min${l?` · <span class="sft2 ${c}">${l}</span>`:""}${I.gap?` · ◆ complété depuis ${I.gap.from}`:""}${I.fut?` · ${I.fut.j!=null?dayLbl(I.fut.j).toLowerCase()+" "+I.fut.h:"bientôt"}`:""}</small>${I.syn?`<p class="${I.spo?"spo":""}">${esc(I.syn)}</p>`:""}${pt&&pt.s===I.s&&pt.e===I.e?`<span class="pmk">${pav(du)} ${esc(PR.list[du].n)} est ici</span>`:""}</div></div>`}
const F2T=[["eps","Épisodes"],["cast","Qui est qui ?"],["sim","Séries proches"],["where","Où regarder"],["det","Détails"]];
function fCast(it){const L=(it.cast||[]).filter(c=>A[c[0]]);if(!L.length)return '<div class="empty0">La distribution arrivera avec les données TMDB</div>';
 return `<section class="hsec sfc"><div class="lh">Qui est qui ?<small>sans spoiler : les personnages principaux</small></div><div class="row sx">${L.map(([a,r],i)=>`<div class="av" data-f data-fid="sfc-${i}" data-act="actor:${a}" data-row="sfc">${(ph=>`<div class="ph${ph?" aph":""}" style="--h:${hash(a)%360}${ph?`;background-image:url(${ph})`:""}">${ph?"":esc((A[a]||"?").split(/\s+/).map(w=>w[0]).join("").slice(0,2))}</div>`)(window.actorPh?actorPh(a):"")}<b>${esc(r||A[a])}</b><span>${esc(A[a])}</span></div>`).join("")}</div></section>`}
function fSim(it){const L=sFor().filter(o=>o.c.id!==it.id&&(o.c.g||[]).some(g=>(it.g||[]).includes(g))).slice(0,10);return L.length?`<section class="hsec"><div class="lh">Séries proches<small>même genre, même ton</small></div><div class="row sx">${L.map(o=>spst(o.c,"sfm-"+o.c.id,"sfm",o)).join("")}</div></section>`:'<div class="empty0">Pas encore de séries proches</div>'}
function fDet(it){const s=fSea(it),N=EPS(it)[s-1],A2=Array.from({length:N},(_,i)=>avail(it,s,i+1)),c=k=>A2.filter(a=>a[k]).length;
 return `<section class="hsec sfd"><div class="lh">Détails</div><div class="sfdg"><div><em>Chaîne d'origine</em>${esc(NET(it)||"—")}</div><div><em>Créée par</em>${esc(CRE(it)||"—")}</div><div><em>Statut</em>${ST(it)==="terminée"?"Terminée":ST(it)?"En cours":"—"}</div><div><em>Épisodes</em>${NE(it)} · ${D(NE(it)*ED(it))}</div><div><em>Versions (saison ${s})</em>VFF ${c("vff")}/${N} · VF ${c("vf")}/${N} · VOSTFR ${c("vost")}/${N}</div><div><em>Choix de version</em>automatique, épisode par épisode</div></div></section>`}
function ficheHtml(it){const t=X.ft||"eps",n=nextEp(it),s=fSea(it),T=topEps(it,s),du=MX().duo[it.id],pt=du&&PR.list[du]&&MX(du).sp[it.id];
 let eps=Array.from({length:EPS(it)[s-1]},(_,i)=>epInfo(it,s,i+1));const all=eps.length;if(X.ess)eps=eps.filter(I=>(epR(it,I.s,I.e)||0)>=8.2||I.cur||T.includes(I.e));
 const ss=seasonSeen(it,s),dur=eps.reduce((a,I)=>a+I.d,0),rs=Array.from({length:all},(_,i)=>epR(it,s,i+1)).filter(r=>r!=null),avg=rs.length?(rs.reduce((a,b)=>a+b,0)/rs.length).toFixed(1).replace(".",","):null;
 const rec=s>1&&seasonSeen(it,s-1)&&!ss&&s===n.s&&(n.e<=2||jOf(it)>=7)?`<div class="sf2e g4rec" data-f data-fid="sf-srec" data-act="sxsrec:${it.id}:${s-1}" data-row="sfrec"><div class="sfi g4ri"><em>⏮</em></div><div class="sf2t"><b>Rappel de la saison ${s-1}</b><small>2 min · images et points clés</small><p>Pour te remettre dans l'histoire avant ${SE(s,1)}.</p></div></div>`:"";
 const head=`<div class="g4h"><div class="g4t"><b>Saison ${s}</b><span>${all} ép. · ${D(dur)} · ${(window.SXDATA&&SXDATA.sy&&SXDATA.sy[it.id]&&SXDATA.sy[it.id][s])||it.y+s-1}${avg?` · ★ ${avg}`:""}</span></div><div class="g4b"><div class="hchip" data-f data-fid="sfh-trl" data-act="sxtrl:${it.id}:${s}" data-row="sfh">🎬 Bande-annonce</div><div class="hchip" data-f data-fid="sfh-sea" data-act="sxsea:${it.id}:${s}" data-row="sfh">${ss?"↺ Saison non vue":"✓ Saison vue"}</div>${avg?`<div class="hchip ${X.ess?"sel":""}" data-f data-fid="sfh-ess" data-act="sxess" data-row="sfh">★ L'essentiel${X.ess?` · ${eps.length}/${all}`:""}</div>`:""}</div></div>`;
 const srows=EPS(it).map((ne,i)=>{if(!ne)return "";const s2=i+1,L=Array.from({length:ne},(_,j)=>epInfo(it,s2,j+1)),vu=L.filter(I=>I.seen).length;return `<div class="g3s g4s ${s2===s?"sel":""}" data-f data-fid="sfs-${s2}" data-fs="${s2}" data-act="sxfs:${s2}" data-row="sfs${s2}"><b>Saison ${s2}</b><div><div class="g3d">${L.map(I=>`<i class="${epSt(I)[0]} ${I.gap?"gp":""}"></i>`).join("")}</div>${spark(it,s2)}</div><small>${vu===ne?"✓":vu+"/"+ne}</small></div>`}).join("");
 const left=`<div class="sf2a ga sy"><h1 class="${fxFont(it)} t2" style="font-size:${Math.round(titleSize(it)*.55)}px">${esc(it.t)}<span class="finfo" data-f data-fid="sf-info" data-act="sxinfo:${it.id}" data-row="sfi">ⓘ</span></h1><div class="meta">${fMeta(it)}</div>${fActs(it)}<div class="sf2p glass gprog">${fSum(it)}</div><div class="g3rows">${srows}</div>${fLeg()}</div>`;
 const body=t==="eps"?`<div class="sf2l sy">${head}${rec}${eps.map(I=>gRow(it,I,T,pt,du)).join("")||'<div class="empty0">Aucun épisode</div>'}</div>`:t==="cast"?fCast(it):t==="sim"?fSim(it):t==="where"?`<div class="sfwh">${whereHtml(it)}</div>`:fDet(it);
 return `<div class="SF F2 G3 G4" id="sxf">${fxArt(it,"sf2bg")}<div class="sf2sh"></div>${left}
 <div class="sf2b glass"><div class="btabs hline sf2tabs">${F2T.map(([k,nm])=>`<div class="btab ${k===t?"sel":""}" data-f data-fid="sft-${k}" data-ft="${k}" data-act="sxft:${k}" data-row="sft">${nm}</div>`).join("")}</div><div class="sf2body">${body}</div></div>
 <div class="clock">${fmt(NOW())}</div></div>`}
{const _d=detailHtml;detailHtml=function(it){if(it&&it.type==="s"){const m=MX().fmem[it.id]||{};if(X.fid!==it.id){X.fid=it.id;X.fs=m.fs||null;X.ft=m.ft||null;X.ess=false}return fxC(`<div class="fx sxfiche">${ficheHtml(it)}</div>`)}return _d(it)}}

/* ===================== Fenêtres ===================== */
const opt=(fid,a,b,s,d)=>`<div class="opt" data-f data-fid="${fid}" data-act="${a}" ${d?"data-default":""}><div class="tx"><b>${b}</b>${s?`<span>${s}</span>`:""}</div></div>`;
function sxModal(m){const it=m.id&&ALL[m.id];
 if(m.type==="sxhopt")return `<div class="modal"><div class="mbox glass" style="width:560px"><div class="k">PLUS D'OPTIONS</div><h2>${esc(X.slide?X.slide.title:"")}</h2>${X.alt.map((a,i)=>opt("sxo-"+i,"sxalt:"+i,a[0].replace(/<[^>]+>/g,""),"",i===0)).join("")}${opt("sxo-x","sxclose","Fermer","")}</div></div>`;
 if(m.type==="sxctx"){const x=MX(),i=x.ord.indexOf(m.rk),fixed=m.rk==="soir";
  const fo=it?[["fiche","📺 Voir la fiche","saisons, épisodes, distribution"],...(spOf(it)?[["recap","⏮ Résumé de 60 s, puis l'épisode",""]]:[]),["no","👎 Pas pour moi","Elle ne te sera plus proposée"],["seen",isDone(it)?"↺ Marquer comme non vue":"✓ Déjà vue en entier","Ça affine tes suggestions"],["list",isFav(it.id)?"− Retirer de ma liste":"＋ Ajouter à ma liste",""]]:[];
  const ro=fixed||!m.rk?[]:[i>0&&["up","▲ Monter la rangée",""],i<x.ord.length-1&&["down","▼ Descendre la rangée",""],["hide","Masquer la rangée","Réglages › Accueil Séries pour la rétablir"]].filter(Boolean);
  return `<div class="modal"><div class="mbox glass" style="width:600px;max-height:690px">${it?`<div class="k">CETTE SÉRIE</div><h2>${esc(it.t)}</h2>${fo.map((a,j)=>opt("sxc-"+a[0],"sxc:"+a[0],a[1],a[2],j===0)).join("")}`:""}
  ${m.rk?`<div class="k" style="margin-top:${it?14:0}px">CETTE RANGÉE · ${esc(fixed?"À suivre · Ce soir ? · Cette semaine":NAMES[m.rk]||"")}</div>${fixed?`<div class="mfoot" style="text-align:left">Cette bande reste toujours sous la bannière.</div>`:ro.map((a,j)=>opt("sxc-"+a[0],"sxc:"+a[0],a[1],a[2],!it&&j===0)).join("")}`:""}
  ${opt("sxc-x","sxclose","Fermer","")}<div class="mfoot">Gardé pour le profil ${esc(ME().n)}</div></div></div>`}
 if(m.type==="sxep"){const [s,e]=m.ep.split("-").map(Number),I=epInfo(it,s,e);const B=I.miss?[["alert","🔔 M'avertir quand il arrive"]]:[["start",I.seen?"▶ Revoir cet épisode":"▶ Lire depuis le début"],["upto",`✓ Vu jusqu'à ${SE(s,e)}`],["here",`↺ Non vu : reprendre à ${SE(s,e)}`]];
  return `<div class="modal"><div class="mbox glass" style="width:540px"><div class="k">${esc(it.t)} · ${SE(s,e)}</div><h2 class="${I.spo?"spo":""}">${esc(I.t)}</h2>${B.map(([a,l],i)=>opt("sxe-"+a,"sxepd:"+a,l,"",i===0)).join("")}${opt("sxe-x","sxclose","Fermer","")}</div></div>`}
 if(m.type==="sxinfo")return `<div class="modal"><div class="mbox glass" style="width:660px"><div class="k">SÉRIE${NET(it)?" · "+esc(NET(it)):""}</div><h2>${esc(it.t)}</h2><p style="font-size:16px;line-height:1.5;opacity:.9;margin:0 0 12px">${esc(it.s||"")}</p><div class="sfdg" style="grid-template-columns:1fr 1fr;margin:0 0 14px"><div><em>Créée par</em>${esc(CRE(it)||"—")}</div><div><em>Statut</em>${ST(it)==="terminée"?"Terminée":ST(it)?"En cours":"—"} · ${NS(it)} saison${NS(it)>1?"s":""}</div><div><em>Première diffusion</em>${it.y}</div><div><em>Genres</em>${esc((it.g||[]).join(", "))}</div></div>${opt("sxi-x","sxclose","Fermer","",true)}</div></div>`;
 if(m.type==="sxver"){const s=fSea(it),N=EPS(it)[s-1],A2=Array.from({length:N},(_,i)=>avail(it,s,i+1)),c=k=>A2.filter(a=>a[k]).length,cur=MX().lang[it.id]||"auto";
  return `<div class="modal"><div class="mbox glass g4v" style="width:740px;max-height:680px"><div class="k">VERSIONS · SAISON ${s}</div><h2>${esc(it.t)}</h2>
  <div class="g4vs"><span class="${c("vff")===N?"ok2":"lt"}">VFF : ${c("vff")}/${N}</span><span>VF : ${c("vf")}/${N}</span><span class="${c("vost")===N?"ok2":""}">VOSTFR : ${c("vost")}/${N}</span></div>
  <div class="g4vt sy" style="max-height:250px"><div class="g4vr hd"><span></span><span>VFF</span><span>VF</span><span>VOSTFR</span><span>Lu par prisme</span></div>${A2.map((a,i)=>{const v=verOf(it,s,i+1);return `<div class="g4vr"><span>É${i+1}</span><span>${a.vff?"✓":"—"}</span><span>${a.vf?"✓":"—"}</span><span>${a.vost?"✓":"—"}</span><span>${v.lang} · ${v.q} · ${esc(v.prov)}</span></div>`}).join("")}</div>
  <div class="kk" style="margin-top:12px">LANGUE POUR CETTE SÉRIE (retenue pour elle seule)</div><div class="hchips">${[["auto","Auto (ta préférence)"],["VFF","VFF"],["VF","VF"],["VOSTFR","VOSTFR"]].map(([k,n])=>`<div class="hchip ${cur===k?"sel":""}" data-f data-fid="sxl-${k}" data-act="sxlang:${k}" data-row="sxl" ${cur===k?"data-default":""}>${n}</div>`).join("")}</div>
  <div style="margin-top:14px">${opt("sxv-x","sxclose","Fermer","")}</div></div></div>`}
 if(m.type==="sxduo"){const o=PR.list[MX().duo[m.id]],n=nextEp(it);return `<div class="modal"><div class="mbox glass" style="width:600px"><div class="k">👥 SÉRIE SUIVIE À DEUX</div><h2>Vous regardez ${esc(it.t)} avec ${esc(o.n)}</h2><div class="mfoot" style="text-align:left;margin:0 0 10px">Le prochain épisode commun est ${SE(n.s,n.e)}. Si tu le regardes seul, ${esc(o.n)} garde sa place.</div>
  ${opt("sxd-w","sxduod:wait",`⏸ Attendre ${esc(o.n)}`,"rappel quand vous êtes deux",true)}${opt("sxd-d","sxduod:duo","👥 Passer en mode à deux","")}${opt("sxd-s","sxduod:solo","▶ Regarder seul quand même","")}</div></div>`}
 if(m.type==="sxmara"){const x=ALL[P&&P.id],end=NOW()+(x?ED(x):45),late=end>bed();return `<div class="modal"><div class="mbox glass" style="width:600px"><div class="k">🍿 ${P?P.sx.binge:0} ÉPISODES D'AFFILÉE</div><h2>Encore un ?</h2><div class="mfoot" style="text-align:left;margin:0 0 10px;font-size:16px">${P?SE(P.ss,P.ep):""} finirait à <b class="${late?"lt":"ok2"}">${fmt(end%1440)}</b> · ton coucher est à ${fmt(bed()%1440)}</div>
  ${opt("sxm-y","sxmara:yes","▶ Oui, encore un","",!late)}${opt("sxm-l","sxmara:last","☾ Un dernier, puis on arrête","",late)}${opt("sxm-n","sxmara:stop","Arrêter maintenant","")}<div class="mfoot">Réglages › Accueil Séries pour changer ce rappel</div></div></div>`}
 return ""}
{const _m=modalHtml;modalHtml=function(){const m=S.modal;if(m&&String(m.type||"").startsWith("sx"))return fxC(`<div class="fx fxw">${sxModal(m)}</div>`);return _m()}}

/* ===================== Lecteur : mode épisode ===================== */
function sxStart(id,o={}){const it=ALL[id];if(!it)return;if(blk(it))return toast("🔒 Cette série dépasse la limite du profil");
 if(!o.s&&missOf(it))return sxAct("sxmiss",id);
 if(o.s){const I=epInfo(it,o.s,o.e);if(I.miss)return toast(`É${o.e} pas encore chez ton fournisseur · OK maintenu sur l'épisode pour une alerte`);if(I.fut)return toast(`${SE(o.s,o.e)} sort ${I.fut.j!=null?dayLbl(I.fut.j).toLowerCase()+" à "+I.fut.h:"bientôt"}`)}
 const du=MX().duo[id];if(du&&PR.list[du]&&!FXS.duo&&!o.solo){S.modal={type:"sxduo",id,o,ret:F&&F.dataset.fid};return render()}
 if(!srcs(id).length)return toast("Aucune source disponible pour cette série");
 const n0=nextEp(it),n=o.s?{s:o.s,e:o.e,pos:n0.s===o.s&&n0.e===o.e&&!o.restart?n0.pos:0}:n0,dur=ED(it)*60,ready=X.prep===id||X.prepEp===id+":"+n.s+"-"+n.e;
 const recapNow=!!o.recap||(needRecap(it)&&!o.s);
 push({t:"player"});startPlayer({kind:"vod",id,src:srcId(id),ss:n.s,ep:n.e,dur,pos:Math.round((n.pos||0)*dur),playing:true,
  sx:{phase:recapNow?"recap":"play",rt:0,rlen:o.srec?120:60,srec:o.srec||0,binge:0,last:false,more:!!o.season,send:o.season?n.s:0,p0:Math.round((n.pos||0)*dur),gap:jOf(it),intro:false,cd:0}});
 render(recapNow?"sx-rx":"p-pp");if(ready)toast("⚡ Démarrage instantané : l'épisode était déjà préparé")}
function sxNext(){if(!P||!P.sx)return;const it=ALL[P.id],nx=spNextEp(it,P.ss,P.ep),x=MX();
 if(nx)setSp(it,nx.s,nx.e,0);else{x.done=x.done.filter(z=>z!==it.id).concat(it.id);delete x.sp[it.id];prSave()}
 X.cache={};P.sx.binge++;
 const stop=msg=>{back();toast(msg)};
 if(P.sx.last)return stop("🌙 Bonne nuit · prisme a arrêté après cet épisode");
 if(!nx){if(window.pbSeasonEnd&&pbSeasonEnd(it,null))return;return stop(`✓ ${it.t} : tu as tout vu`)}
 if(P.sx.send&&nx.s!==P.sx.send)return stop(`✓ Saison ${P.sx.send} finie !`);
const M=MISSING()[it.id];if(M&&M.s===nx.s&&M.e===nx.e){if(window.pbSeasonEnd&&pbSeasonEnd(it,nx))return;return stop(`É${nx.e} pas encore chez ton fournisseur · 🔔 on te prévient dès qu'il arrive`)}
 {const I=epInfo(it,nx.s,nx.e);if(I.miss&&!P.sx.last&&window.pbSeasonEnd&&pbSeasonEnd(it,nx))return}
 if(SET().binge&&P.sx.binge>=SET().binge&&!P.sx.more){P.sx.phase="wait";P.playing=false;S.modal={type:"sxmara",ret:"p-pp"};return render()}
 sxGoNext()}
function sxGoNext(){const it=ALL[P.id],n=nextEp(it),v=verOf(it,n.s,n.e);Object.assign(P,{ss:n.s,ep:n.e,pos:0,playing:true});Object.assign(P.sx,{phase:"play",intro:false,cd:0});
 render("p-pp");toast(`⚡ ${SE(n.s,n.e)} enchaîne sans attente · ${v.lang} · ${v.q} · ${v.prov}`)}
{const _t=tick;tick=function(){const sx=P&&P.sx;if(sx&&sx.phase==="recap"){P.pos=sx.p0;sx.rt++;const e=$("#sxrt");if(e)e.textContent=hms(Math.max(0,sx.rlen-sx.rt));const r=_t();if(P)P.pos=sx.p0;if(sx.rt>=sx.rlen){sx.phase="play";render("p-pp");toast(`▶ ${SE(P.ss,P.ep)} démarre`)}return r}
 _t();if(!sx||!P.playing)return;const it=ALL[P.id];
 if(sx.phase==="end"){sx.cd--;const c=$("#sxcd");if(c)c.textContent=Math.max(0,sx.cd);if(sx.cd===6){const z=$("#sxprep");if(z)z.classList.add("on")}if(sx.cd<=0)sxNext();return}
 if(sx.phase!=="play")return;
 if(P.pos>=58&&P.pos<104&&!sx.intro){if(SET().skip&&MX().skip[P.id]){P.pos=104;sx.intro=true;toast(`⏭ Intro passée automatiquement · appris sur ${MX().skip[P.id]}`)}else if(!$("#sxskip"))render("sx-skip")}
 if(P.pos>=104&&$("#sxskip")){sx.intro=true;render("p-pp")}
 if(P.pos>=P.dur-90){sx.phase="end";sx.cd=10;render("sx-next")}}}
{const _ph=playerHtml;playerHtml=function(){let h=_ph();if(!P||P.kind!=="vod"||!P.sx)return h;const it=ALL[P.id],sx=P.sx,v=verOf(it,P.ss,P.ep),nx=spNextEp(it,P.ss,P.ep);
 const chips=pchip("sx-lo","sxlo","☾","Arrêt",sx.last?"✓ après cet épisode":"après cet épisode")+(DEMO()?pchip("sx-di","sxdi","⏩","Démo","aller à l'intro")+pchip("sx-dc","sxdc","⏩","Démo","aller au générique"):"");
 h=h.replace('</div><div class="pc" data-f data-fid="p-nextep"',chips+'</div><div class="pc" data-f data-fid="p-nextep"');
 let ov=`<div class="spv glass"><b>${v.lang} · ${v.q} · ${esc(v.prov)}</b><small>${v.gap?`épisode absent chez ${esc(v.gap)}, complété depuis ${esc(v.prov)}`:"meilleure version de cet épisode, choisie pour toi"}${FXS.duo?" · 👥 "+FXS.duo.map(id=>esc(PR.list[id].n)).join(" + "):""}${sx.binge?` · ${sx.binge+1}ᵉ épisode d'affilée`:""}</small></div>`;
 if(sx.phase==="recap")ov+=`<div class="sprec glass"><div class="k">${sx.srec?`⏮ RAPPEL DE LA SAISON ${sx.srec} · 2 MIN`:"⏮ RÉSUMÉ DE 60 S"} · <span id="sxrt">${hms(Math.max(0,sx.rlen-sx.rt))}</span></div><b>${sx.srec?`Ce qu'il faut retenir de la saison ${sx.srec}`:sx.gap>=(SET().recap||7)?`Tu n'as pas regardé ${esc(it.t)} depuis ${sx.gap} jours`:`Ce qu'il faut savoir avant ${SE(P.ss,P.ep)}`}</b><ul>${recap(it).map(t=>`<li>${esc(t)}</li>`).join("")}</ul><div class="btn" data-f data-fid="sx-rx" data-act="sxrx">Passer le résumé ›</div></div>`;
 if(sx.phase==="play"&&P.pos>=58&&P.pos<104&&!sx.intro&&!(SET().skip&&MX().skip[P.id]))ov+=`<div class="spskip" id="sxskip"><div class="btn prim" data-f data-fid="sx-skip" data-act="sxskip">Passer l'intro ›</div><small>${SET().skip?"prisme retiendra le moment pour les prochains épisodes":""}</small></div>`;
 if(sx.phase==="end"){const M=MISSING()[it.id],miss=nx&&M&&M.s===nx.s&&M.e===nx.e,nv=nx&&verOf(it,nx.s,nx.e),spo=SET().spo;
  ov+=nx&&!miss?`<div class="spend glass"><div class="k">${sx.last?"DERNIER ÉPISODE DE LA SOIRÉE":`ÉPISODE SUIVANT DANS <b id="sxcd">${sx.cd}</b>`}</div><div class="spn">${fxArt(it)}<span class="zap2" id="sxprep">⚡ prêt</span></div><b>${SE(nx.s,nx.e)} · « ${esc(EPT(it,nx.s,nx.e))} »</b>${EPS_(it,nx.s,nx.e)?`<p class="${spo?"spo":""}">${esc(EPS_(it,nx.s,nx.e))}</p>${spo?'<small class="spl">🙈 résumé masqué (zéro spoiler)</small>':""}`:""}<small>${nv.lang} · ${nv.q} · ${esc(nv.prov)} · préparé pendant le générique, 1 seule connexion</small>
   <div class="spb2">${sx.last?`<div class="btn prim" data-f data-fid="sx-next" data-act="sxstop">Terminer la soirée</div>`:`<div class="btn prim" data-f data-fid="sx-next" data-act="sxnext">▶ Épisode suivant</div><div class="btn" data-f data-fid="sx-cred" data-act="sxcred">Voir le générique</div>`}</div></div>`
  :`<div class="spend glass"><div class="k">FIN DE L'ÉPISODE</div><b>${miss?`É${nx.e} pas encore chez ton fournisseur`:"Tu as tout vu !"}</b><div class="spb2"><div class="btn prim" data-f data-fid="sx-next" data-act="sxnext">${miss?"🔔 M'avertir et fermer":"Fermer"}</div></div></div>`}
 const i=h.lastIndexOf("</div>");return h.slice(0,i)+fxC(`<div class="fx sxp">${ov}</div>`)+h.slice(i)}}
{const _s=stopPlayer;stopPlayer=function(){if(P&&P.kind==="vod"&&P.sx){const it=ALL[P.id],pct=P.pos/P.dur;
  if(P.sx.phase==="play"||P.sx.phase==="recap"){if(pct>=.97){const nx=spNextEp(it,P.ss,P.ep);if(nx)setSp(it,nx.s,nx.e,0)}else if(spOf(it)||pct>.02)setSp(it,P.ss,P.ep,pct)}
  X.cache={};const n=nextEp(it);X.fs=n.s;const below=S.stack[S.stack.length-2];if(below&&below.t==="detail"&&below.id===it.id)below.last=`sfe-${n.s}-${n.e}`}return _s()}}

/* ===================== Actions ===================== */
function ctxDo(v){const m=S.modal,x=MX(),i=x.ord.indexOf(m.rk),it=m.id&&ALL[m.id];let msg="",ret=m.ret;S.modal=null;
 if(v==="fiche"){render(ret);return push({t:"detail",id:m.id})}
 if(v==="recap"){render(ret);return sxStart(m.id,{recap:1})}
 if(v==="no"){x.no.push(m.id);msg=`👎 « ${it.t} » ne te sera plus proposée`;ret=null}
 if(v==="seen"){if(isDone(it)){x.done=x.done.filter(z=>z!==it.id);msg="Marquée comme non vue"}else{x.done.push(it.id);delete x.sp[it.id];msg="✓ Marquée comme vue en entier"}}
 if(v==="list"){toggleFav(m.id,it.t);msg=isFav(m.id)?"＋ Ajoutée à ma liste":"Retirée de ma liste"}
 if(v==="up"||v==="down"){const j=i+(v==="up"?-1:1);[x.ord[i],x.ord[j]]=[x.ord[j],x.ord[i]];msg=`Rangée ${v==="up"?"montée":"descendue"} · gardé pour ${ME().n}`}
 if(v==="hide"){x.hid.push(m.rk);msg="Rangée masquée · Réglages › Accueil Séries pour la rétablir";ret=null}
 X.cache={};prSave();save();render(ret||undefined);
 if(!ret||!view.querySelector(`[data-fid="${CSS.escape(m.ret)}"]`)){const s=view.querySelector(`[data-rk="${m.rk}"]`)||view.querySelector("[data-rk]");const e=s&&(s.querySelector(fxQ("row")+" [data-f]")||s.querySelector("[data-f]"));if(e)setFocus(e)}
 toast(msg)}
function sxAct(k,v,w,x){const pf=F&&F.dataset.fid,it=v&&ALL[v];
 switch(k){
 case "sxopen":return push({t:"detail",id:v});
 case "sxex":{/* exemple de reprise avec les vraies séries : quelques épisodes « en cours », dont un vu il y a plus d'une semaine (résumé auto) */
  const x=MX(),now=Date.now(),L=SL().filter(z=>EPS(z).some(c=>c>=2)).sort((p,q)=>NE(q)-NE(p)).slice(0,4);if(!L.length)return toast("Importe d'abord episodes.json (commande des données)");
  L.forEach((z,i)=>{const E=EPS(z),s=Math.max(1,E.findIndex(c=>c>=2)+1);x.sp[z.id]={s,e:Math.min(i+2,E[s-1]),pos:[.4,0,.25,0][i],t:now-[1,3,9,2][i]*DAY}});
  prSave();X.cache={};S.sxtab="suivre";render("sxr-"+L[0].id);return toast("Exemple créé : lance ou marque « non vue » une série pour la retirer")}
 case "sxplay":return sxStart(v);
 case "sxep":{const [s,e]=w.split("-").map(Number);return sxStart(v,{s,e})}
 case "sxrecap":return sxStart(v,{recap:1});
 case "sxsrec":return sxStart(v,{recap:1,srec:+w,norecap:1});
 case "sxfin":return sxStart(v,{season:1});
 case "sxlist":{toggleFav(v,it.t);X.cache={};render(pf);return}
 case "sxmiss":{const m=MX();m.mal=m.mal.includes(v)?m.mal.filter(z=>z!==v):m.mal.concat(v);prSave();render(pf);const M=MISSING()[v]||nextEp(it);return toast(m.mal.includes(v)?`🔔 ${it.t} · ${SE(M.s,M.e)} : tu seras prévenu dès qu'il arrive chez ton fournisseur`:"Alerte retirée")}
 case "sxrem":{const z=WEEK().find(q=>q.id===v&&q.j===+w);return toast(`⏰ Rappel : ${it.t}${z&&z.e?" "+SE(z.s,z.e):""} ${z?dayLbl(z.j).toLowerCase()+(z.h?" à "+z.h:""):""} · notification sur l'Apple TV et l'iPhone`)}
 case "sxcoll":{S.sxsort="pert";return push({t:"sxcoll",k:[v,w,x].filter(q=>q!=null).join(":")})}
 case "sxsort":S.sxsort=v;render("fs-"+v);{const g=$("#ggrid");if(g)g.scrollTop=0}return;
 case "sxtab":{const r=qs(".sbband .row [data-f]");if(r)setFocus(r);return}
 case "sxbt":{const r=qs(".browse .row [data-f]");if(r)setFocus(r);return}
 case "sxask":{X.ask=v;const c=v==="d"?(S.sxt||"soir"):v==="m"?(S.fhm||"all"):(FXS.duo?"duo":"solo");return render("sx-o-"+c)}
 case "sxax":{const d=X.ask;X.ask=null;return render("sx-q-"+d)}
 case "sxaset":{const d=X.ask;if(d==="d")S.sxt=w;else if(d==="m")S.fhm=w==="all"?"":w;else{const ids=Object.keys(PR.list);FXS.duo=w==="duo"&&ids.length>1?[PR.cur,ids.find(z=>z!==PR.cur)]:null;FXS.cache={};FH.cache={}}
  X.ask=null;X.cache={};save();render("sx-q-"+d);const n=sRes().length;return toast(n?`${n} séries pour ce soir`:"Aucune série avec ces choix")}
 case "sxdice":{const R=sRes();if(!R.length)return toast("Aucune série avec ces choix");const o=R[Math.floor(Math.random()*Math.min(5,R.length))];toast("🎲 "+o.c.t+" · "+sPlan(o.c).lbl);const g=F;setTimeout(()=>{if(F===g&&sxOn()&&!S.modal)push({t:"detail",id:o.c.id})},600);return}
 case "sxalt":{const a=X.alt[+v];S.modal=null;render("sx-b0");if(a)setTimeout(()=>act(a[1]),30);return}
 case "sxclose":{const r=S.modal&&S.modal.ret;S.modal=null;return render(r)}
 case "sxc":return ctxDo(v);
 case "sxrand":{const c=coll(v),L=c?c.items():[];if(!L.length)return;const r=L[Math.floor(Math.random()*L.length)];toast("🎲 "+r.t);const g=F;setTimeout(()=>{if(F===g&&sxOn()&&!S.modal)push({t:"detail",id:r.id})},600);return}
 case "sxalert":{S.sxAlerts=S.sxAlerts||[];S.sxAlerts=S.sxAlerts.includes(v)?S.sxAlerts.filter(z=>z!==v):S.sxAlerts.concat(v);save();X.cache={};render("sx-b0");return toast(S.sxAlerts.includes(v)?`🔔 Tu seras prévenu dès la nouvelle saison de ${it.t}`:"Alerte retirée")}
 case "sxtrl":return toast(`🎬 Bande-annonce · ${it.t} · saison ${w||1} · VF${DEMO()?" (simulée)":""}`);
 case "sxduo":{const m=MX(),o=Object.keys(PR.list).find(z=>z!==PR.cur);if(!o)return;if(m.duo[v])delete m.duo[v];else m.duo[v]=o;prSave();render("sf-duo");return toast(m.duo[v]?`👥 ${it.t} : suivie avec ${PR.list[o].n}`:"Suivie seul")}
 case "sxduod":{const m=S.modal,o=PR.list[MX().duo[m.id]];S.modal=null;if(v==="wait"){render(m.ret);return toast(`⏸ ${ALL[m.id].t} attend ${o.n} · rappel quand vous êtes deux`)}
  if(v==="duo"){FXS.duo=[PR.cur,MX().duo[m.id]];FXS.cache={}}render(m.ret);sxStart(m.id,{...(m.o||{}),solo:1});return toast(v==="duo"?"👥 Mode à deux : la progression avance pour vous deux":`${o.n} garde sa place`)}
 case "sxmara":{S.modal=null;if(!P)return;if(v==="stop"){back();return toast("🌙 Bonne soirée !")}P.sx.more=v==="yes";P.sx.last=v==="last";return sxGoNext()}
 case "sxfs":{const r=qs(".sf2l .sel[data-f]")||qs(".sf2l .sf2e[data-f]");if((X.ft||"eps")!=="eps"){X.ft="eps";X.fs=+v;render();const r2=qs(".sf2l .sel[data-f]")||qs(".sf2l .sf2e[data-f]");if(r2)setFocus(r2);return}if(r)setFocus(r);return}
 case "sxft":{const r=qs(".sf2body [data-f]");if(r)setFocus(r);return}
 case "sxsea":{const s=+w;if(seasonSeen(it,s)){setSp(it,s,1,0);toast(`↺ Saison ${s} marquée non vue`)}else{const nx=spNextEp(it,s,EPS(it)[s-1]);if(nx)setSp(it,nx.s,nx.e,0);else{const m=MX();m.done=m.done.concat(it.id);delete m.sp[it.id];prSave()}toast(`✓ Saison ${s} marquée vue`)}X.cache={};return render("sfh-sea")}
 case "sxess":{X.ess=!X.ess;render("sfh-ess");return toast(X.ess?"★ L'essentiel : les épisodes les mieux notés (et ton épisode en cours)":"Tous les épisodes")}
 case "sxinfo":S.modal={type:"sxinfo",id:v,ret:pf};return render();
 case "sxver":S.modal={type:"sxver",id:v,ret:pf};return render();
 case "sxlang":{const id=S.modal.id,m=MX();if(v==="auto")delete m.lang[id];else m.lang[id]=v;prSave();render("sxl-"+v);return toast(v==="auto"?"Langue automatique (ta préférence)":`${v} retenu pour ${ALL[id].t} uniquement`)}
 case "sxepd":{const m=S.modal,[s,e]=m.ep.split("-").map(Number),i2=ALL[m.id];S.modal=null;
  if(v==="upto"){const nx=spNextEp(i2,s,e);if(nx)setSp(i2,nx.s,nx.e,0);else{const q=MX();q.done=q.done.concat(i2.id);delete q.sp[i2.id];prSave()}X.cache={};render(m.ret);return toast(`✓ Vu jusqu'à ${SE(s,e)}`)}
  if(v==="here"){setSp(i2,s,e,0);X.cache={};render(m.ret);return toast(`↺ Tu reprendras à ${SE(s,e)}`)}
  if(v==="start"){render(m.ret);return sxStart(i2.id,{s,e,restart:1})}
  if(v==="alert"){render(m.ret);return sxAct("sxmiss",i2.id)}return}
 case "sxrx":if(P&&P.sx){P.sx.phase="play";P.pos=P.sx.p0;render("p-pp")}return;
 case "sxskip":if(P&&P.sx){P.pos=104;P.sx.intro=true;const nw=SET().skip&&!MX().skip[P.id];if(nw){MX().skip[P.id]=SE(P.ss,P.ep);prSave()}render("p-pp");if(nw)toast(`✓ Retenu : prisme passera l'intro de ${ALL[P.id].t} tout seul`)}return;
 case "sxdi":if(P&&P.sx){P.sx.phase="play";P.pos=54;P.sx.intro=false;render("sx-di")}return;
 case "sxdc":if(P&&P.sx){P.sx.phase="play";P.pos=Math.max(0,P.dur-94);render("sx-dc")}return;
 case "sxlo":if(P&&P.sx){P.sx.last=!P.sx.last;render("sx-lo");toast(P.sx.last?"☾ prisme s'arrêtera après cet épisode":"Lecture continue")}return;
 case "sxnext":return sxNext();
 case "sxcred":if(P&&P.sx){P.sx.cd=999;toast("Générique en cours · l'épisode suivant reste prêt")}return;
 case "sxstop":return back();
 case "sxset":{const s=SET(),C={recap:[0,7,14],skip:[1,0],spo:[1,0],binge:[0,2,3,4]}[v];s[v]=C[(C.indexOf(s[v])+1)%C.length];save();X.cache={};return render("set-sx"+v)}
 case "sxrst":{MX().hid=[];prSave();render("set-sxrst");return toast("Rangées rétablies")}
 }}
{const _a=act;act=function(a){if(!a)return;const [k,v,w,x]=a.split(":");if(k.startsWith("sx"))return sxAct(k,v,w,x);if(a==="p:nextep"&&P&&P.sx)return sxNext();return _a(a)}}
window.sxCollHtml=collHtml;

/* ===================== Navigation et focus ===================== */
/* fiche : ▲ ▼ ligne par ligne (groupées par hauteur, dans l'ordre), ◀ ▶ dans la ligne */
function lineNav(box,k){const E=[...box.querySelectorAll("[data-f]")].filter(e=>e.offsetParent!==null);if(!E.length||!box.contains(F))return false;
 const L=[];E.map(e=>{const r=e.getBoundingClientRect();return {e,r,y:r.top-(e===F?(r.height-e.offsetHeight*SCALE)/2:0)}}).forEach(o=>{const l=L[L.length-1];l&&Math.abs(l.t-o.y)<14*SCALE?l.i.push(o):L.push({t:o.y,i:[o]})});
 L.forEach(l=>l.i.sort((a,b)=>a.r.left-b.r.left));const li=L.findIndex(l=>l.i.some(o=>o.e===F)),line=L[li],ii=line.i.findIndex(o=>o.e===F),fx=line.i[ii].r.left+line.i[ii].r.width/2;
 if(k==="left"||k==="right"){const o=line.i[ii+(k==="right"?1:-1)];if(o){setFocus(o.e);return true}return "edge"}
 const nl=L[li+(k==="down"?1:-1)];if(!nl)return "edge";let best=nl.i[0],bd=1e9;for(const o of nl.i){const d=Math.abs(o.r.left+o.r.width/2-fx);if(d<bd){bd=d;best=o}}
 const sel=nl.i.find(o=>o.e.classList.contains("sel")&&(o.e.dataset.ep||o.e.dataset.fs));setFocus(sel?sel.e:best.e);return true}
function ficheKey(k){const it=ALL[topS().id],ga=qs(".ga"),pb=qs(".sf2b");
 if(F.classList.contains(FXR.g4s||"g4s")||F.dataset.fs){if(k==="right"){const s=+F.dataset.fs,n=nextEp(it),e=s===n.s?n.e:1,r=(s===n.s&&n.e<=2&&qs(".g4rec"))||view.querySelector(`[data-fid="sfe-${s}-${e}"]`)||qs(".sf2l .sf2e[data-f]");if(r){setFocus(r);return true}}if(k==="down"&&!F.nextElementSibling)return true;if(k==="up"||k==="down"){const r=lineNav(ga,k);return r!==false}}
 if(k==="left"&&F.closest(Q(".sf2l"))){const r=qs(".g4s.sel");if(r){setFocus(r);return true}}
 if(ga&&ga.contains(F)){const r=lineNav(ga,k);if(r===true)return true;if(r==="edge"&&k==="right"){const t=qs(".sf2l .sel[data-f]")||qs(".sf2b .btab.sel");if(t){setFocus(t);return true}}return true}
 if(pb&&pb.contains(F)){if(!F.closest(Q(".sf2l"))&&(k==="left"||k==="right")&&F.closest(Q(".row"))){return false}const r=lineNav(pb,k);if(r===true)return true;if(r==="edge"&&k==="left"){const t=qs(".g4s.sel")||view.querySelector('[data-fid="sf-play"]');if(t){setFocus(t);return true}}return true}
 return false}
let TICK=0;function sxTick(){clearInterval(TICK);TICK=setInterval(()=>{if(!sxOn()||S.modal||X.skel)return;if(F&&(F.closest(fxQ("hero"))||F.closest(".hline")))return;const sc=$("#hscr");if(!sc||sc.scrollTop>200)return;if(qs(".hpeek"))return;X.h1i++;render(F&&F.dataset.fid)},7000)}
function carousel(k){const hb=F.closest(".acts");if(!hb||!hb.closest(fxQ("hero")))return false;const nd=qa(".dots i:not(.cnt)").length;if(nd<2)return false;X.h1i=((X.h1i+(k==="right"?1:-1))%nd+nd)%nd;X.hdir=k;X.prep=null;render("sx-b0");X.hdir=null;return true}
{const _k=key;key=function(k){
 if(!S.modal&&F&&k==="menu"&&F.closest("#ggrid")&&ALL[F.dataset.hov]&&ALL[F.dataset.hov].type==="s"){S.modal={type:"sxctx",id:F.dataset.hov,rk:null,ret:F.dataset.fid};return render()}
 if(sxOn()&&!S.modal&&F){const pk=qs(".hpeek");if(pk){peekOff();peekArm(F);return}
  if(k==="menu"&&F.dataset.row==="tabs")return toast("Maintiens le clic sur une série pour ses options");
  if(k==="menu"){if(F.closest(fxQ("hero"))){if(X.alt.length){S.modal={type:"sxhopt",ret:F.dataset.fid};return render("sxo-0")}return toast("Pas d'autre option pour cette page")}const s=F.closest("[data-rk]");
   if(s){if(s.dataset.rk==="soir"&&!F.dataset.hid)return toast("Maintiens le clic sur une série pour ses options");S.modal={type:"sxctx",id:F.dataset.hid||null,rk:s.dataset.rk,ret:F.dataset.fid};return render()}}
  if(k==="play"&&F.dataset.hid)return sxStart(F.dataset.hid);
  if((k==="left"||k==="right")&&carousel(k))return;
  if(k==="down"&&F.dataset.row==="tabs"){const d=view.querySelector(fxQ("hero")+" [data-default]");if(d){setFocus(d);return}}
  if((k==="up"||k==="down")&&fhNav(k))return;
  if((k==="left"||k==="right")&&fhHoriz(k))return;
  if(k==="back"&&X.ask){const d=X.ask;X.ask=null;return render("sx-q-"+d)}
  if(k==="back"&&F.dataset.row!=="tabs"){const sc=$("#hscr");if(sc)sc.scrollTo({top:0,behavior:"smooth"})}}
 if(ficheOn()&&!S.modal&&F){
  if(k==="menu"){if(F.dataset.ep){S.modal={type:"sxep",id:topS().id,ep:F.dataset.ep,ret:F.dataset.fid};return render()}return act(F.dataset.act)}
  if(k==="play"){const it=ALL[topS().id];if(F.dataset.ep){const [s,e]=F.dataset.ep.split("-").map(Number);return sxStart(it.id,{s,e})}return act(fMain(it).act)}
  if(["up","down","left","right"].includes(k)&&ficheKey(k))return}
 return _k(k)}}
/* focus : onglets (on n'y change d'onglet qu'en se déplaçant dedans), ⚡ préparation, aperçu, points bleus, bande-annonce */
let PV=null,PRT=0,BUT=0,HPT=0,HPC=0;
const boxOf=e=>e&&(e.closest(Q(".sf2l"))||e.parentElement);
function peekOff(){clearTimeout(HPT);clearInterval(HPC);const h=qs(".hpeek");if(h){h.classList.remove("hpeek");qa(".hero .art").forEach(a=>a.classList.remove("play"))}const c=qs(".hcd");if(c)c.classList.remove("on")}
function peekArm(el){peekOff();const Dl=(fhSet().fhTrl||0)*1000;if(!Dl||!sxOn()||S.modal||!el||!el.closest(".acts")||!el.closest(fxQ("hero")))return;const t0=Date.now();
 HPC=setInterval(()=>{const c=qs(".hcd");if(!c)return clearInterval(HPC);const left=Math.ceil((Dl-(Date.now()-t0))/1000);if(left<=3&&left>0){c.classList.add("on");c.querySelector("b").textContent=left}},250);
 HPT=setTimeout(()=>{clearInterval(HPC);if(F!==el||!el.isConnected)return;const h=qs(".sxhome .H");if(!h)return;h.classList.add("hpeek");const c=qs(".hcd");if(c)c.classList.remove("on");qa(".hero .art").forEach(a=>a.classList.add("play"))},Dl)}
function zap(el,id,ep){clearTimeout(PRT);PRT=setTimeout(()=>{if(F!==el||S.modal||!el.isConnected)return;if(ep)X.prepEp=id+":"+ep;else X.prep=id;view.querySelectorAll(".fhzap").forEach(z=>z.remove());const z=document.createElement("span");z.className="fhzap";z.textContent="⚡ prêt";(el.querySelector(fxQ("sfi"))||el).appendChild(z);
  /* carte À suivre : l'étiquette se met à gauche de « VFF · 1080p », jamais sur le titre */
  const vq=el.matches(Q(".sup"))&&el.querySelector(Q(".vq"));if(vq){z.style.cssText="position:static;display:inline-block;margin:0 6px 0 0;padding:1px 7px;font-size:10px;vertical-align:1px;animation:none";vq.prepend(z)}},1000)}
function bubOff2(){clearTimeout(BUT);const b=view.querySelector(".fhbub");if(b)b.remove()}
function bubArm2(el){bubOff2();const it=ALL[el.dataset.hid];if(!it||el.closest(fxQ("hero"))||el.classList.contains(FXR.sup||"sup")||S.modal)return;
 BUT=setTimeout(()=>{if(F!==el||!el.isConnected||S.modal)return;const o=sFor().find(z=>z.c.id===it.id),n=nextEp(it),r=el.getBoundingClientRect(),v=view.getBoundingClientRect(),x=(r.right-v.left)/SCALE,y=(r.top-v.top)/SCALE,w=340,left=x+16+w<1270?x+16:(r.left-v.left)/SCALE-w-16;
  const d=document.createElement("div");d.className="fhbub";d.style.left=Math.max(10,left)+"px";d.style.top=Math.max(110,Math.min(720-210,y))+"px";
  d.innerHTML=`<b>${esc(it.t)}</b><p>${esc(it.s||"")}</p><div class="bm"><span>${it.y}</span><span>${NS(it)} saison${NS(it)>1?"s":""}</span><span>${NE(it)} ép. · ${D(ED(it))}</span>${o&&o.pct?`<span class="ok2">${o.pct} %</span>`:""}<span class="st">★ ${it.imdb}</span></div><div class="eps">${spOf(it)?"Prochain : "+SE(n.s,n.e):isDone(it)?"✓ Vue en entier":"Pas commencée"}${NET(it)?" · "+esc(NET(it)):""}</div><small>OK = fiche · ⏯ = lancer l'épisode · OK maintenu = options</small>`;view.appendChild(d)},1500)}
{const _sf=setFocus;setFocus=function(el,instant){
 if(el&&(sxOn()||ficheOn())){const tk=["sdt","bt2","fs","ft"].find(k=>el.dataset[k]!=null)||(el.dataset.ep&&el.closest(Q(".sf2l"))?"ls":null);
  if(tk&&!el.classList.contains("sel")&&!(PV&&PV.isConnected&&boxOf(PV)===boxOf(el))){const s=boxOf(el).querySelector(".sel[data-f]");if(s&&s!==el){PV=s;return setFocus(s,instant)}}}
 PV=el;_sf(el,instant);if(!el)return;bubOff2();
 if(sxOn()){view.classList.toggle("fhdown",!el.closest(fxQ("hero"))&&el.dataset.row!=="tabs");
  if(el.dataset.sdt&&S.sxtab!==el.dataset.sdt&&sdTab()!==el.dataset.sdt){S.sxtab=el.dataset.sdt;X.ask=null;return render(el.dataset.fid)}
  if(el.dataset.bt2&&(S.sxbt||"col")!==el.dataset.bt2){S.sxbt=el.dataset.bt2;return render(el.dataset.fid)}
  peekArm(el);clearTimeout(PRT);if(el.dataset.hid&&el.closest('[data-rk="soir"],'+fxQ("hero")))zap(el,el.dataset.hid);
  if(el.dataset.hid){bubArm2(el);const id=el.dataset.hid;if(isNew(id)){const x=MX();x.nseen.push(id);x.nseen=x.nseen.slice(-300);prSave();el.querySelectorAll(".ndot").forEach(d=>d.classList.add("gone"))}}}
 else peekOff();
 if(ficheOn()){const it=ALL[topS().id];
  if(el.dataset.fs&&+el.dataset.fs!==fSea(it)){X.fs=+el.dataset.fs;return render(el.dataset.fid)}
  if(el.dataset.ft&&el.dataset.ft!==(X.ft||"eps")){X.ft=el.dataset.ft;return render(el.dataset.fid)}
  clearTimeout(PRT);if(el.dataset.ep&&el.closest(Q(".sf2l")))zap(el,it.id,el.dataset.ep)}}}
{const _r=render;render=function(fid){bubOff2();_r(fid);
 if(sxOn())sxTick();else clearInterval(TICK);
 if(topS().t==="detail"&&ALL[topS().id]&&ALL[topS().id].type==="s"){MX().fmem[topS().id]={fs:X.fs,ft:X.ft};const l=qs(".sf2l"),s=l&&l.querySelector(".sel");if(s&&!(F&&l.contains(F)))l.scrollTop=Math.max(0,s.offsetTop-150)}}}
{const _b=back;back=function(){if(topS().t==="detail"&&ALL[topS().id]&&ALL[topS().id].type==="s")X.fid=null;return _b()}}

/* ===================== Réglages : Accueil Séries ===================== */
{const _s=settingsHtml;settingsHtml=function(){const h=_s(),s=SET(),x=MX();const sec=`<section data-anchor><h3>Accueil Séries</h3><div class="grp">
 <div class="it" data-f data-fid="set-sxrecap" data-act="sxset:recap"><span>Résumé automatique avant de reprendre</span><span>${s.recap?"après "+s.recap+" jours":"jamais"}</span></div>
 <div class="it" data-f data-fid="set-sxskip" data-act="sxset:skip"><span>Passer l'intro une fois, prisme s'en souvient</span><span>${s.skip?"activé":"désactivé"}</span></div>
 <div class="it" data-f data-fid="set-sxspo" data-act="sxset:spo"><span>Zéro spoiler (épisodes plus loin que le tien floutés)</span><span>${s.spo?"activé":"désactivé"}</span></div>
 <div class="it" data-f data-fid="set-sxbinge" data-act="sxset:binge"><span>« Encore un ? » après plusieurs épisodes</span><span>${s.binge?"après "+s.binge+" épisodes":"jamais"}</span></div>
 <div class="it" data-f data-fid="set-sxrst" data-act="sxrst"><span>Rangées masquées (${esc(ME().n)})</span><span>${x.hid.length?x.hid.map(k=>NAMES[k]).join(", ")+" · OK pour rétablir":"aucune"}</span></div></div></section>`;
 const i=h.indexOf("<section data-anchor><h3>Lecteur</h3>");return i<0?h+sec:h.slice(0,i)+sec+h.slice(i)}}
window.__sx={fMain,X,MX,sUp,sRes,slides,WEEK,nextEp,epInfo,sxStart,verOf,EPS,NS,EPT,EPS_,ED,setSp,spNextEp,SET,isDone,spOf,pv:e=>{PV=e}};
})();
/* ---------- résumés en français uniquement : un texte qui ressemble à de l'anglais est écarté ---------- */
const FR_W=new Set("le la les de des du un une et est dans pour sur qui que son sa ses leur leurs avec au aux il elle ils elles ce cette ces par pas ne se plus mais où sont été être fait après lors doit va entre tout tous".split(" "));
const EN_W=new Set("the and of to is in his her with when where what which who whose their them they he she him this that these those by but be are was were has have had an new must into while its it as at find finds discovers about only young small town life family world how out up all can will would there been more years after from for on your you our we".split(" "));
function frText(t){if(!t)return "";const w=String(t).toLowerCase().match(/[a-zàâäéèêëîïôöùûüç']+/g)||[];if(w.length<4)return /[àâéèêëîïôùûç]/i.test(t)?t:(w.some(x=>EN_W.has(x))?"":t);
 let f=0,e=0;for(const x of w){if(FR_W.has(x))f++;if(EN_W.has(x)||(x.length>5&&/ing$/.test(x)))e++}if(/[àâéèêëîïôùûç]/i.test(t))f+=2;if(f===0&&w.length>=5)return "";return e>=2&&e>f?"":t}
window.frText=frText;
const NOFR="Résumé en français pas encore disponible : lance le script « Fiches séries » pour le récupérer sur TMDB.";
if(typeof REAL!=="undefined"&&REAL)for(const it of SERIES)if(it._real&&!frText(it.s))it.s=NOFR;
/* ---------- fiches séries TMDB (series.json : affiches, grandes images, résumé, casting, chaîne, top 10) ---------- */
const SXD={m:{},names:{},nl:{},top:[],n:0};
function sxApply(only){let n=0;const byK={};
 for(const it of SERIES){if(only&&!only.has(it.id))continue;const r=it._real;if(!r)continue;let k="";for(const s of r.s||[]){if(SXD.names[s[1]]){k=SXD.names[s[1]];break}}
  const d=k&&SXD.m[k];if(!d)continue;n++;byK[k]=byK[k]||it.id;it.sxk=k;
  if(d.po)it.po=d.po;if(d.bd)it.bd=d.bd;if(!/^t/.test(k))continue;
  if(d.t)it.t=d.t;if(d.y)it.y=d.y;if(d.g&&d.g.length)it.g=d.g.slice(0,2);if(d.ov)it.s=d.ov;else if(!frText(it.s))it.s=NOFR;if(d.net)it.net=d.net;if(d.cr)it.dir=d.cr;if(d.ep)it.ep=d.ep;
  if(d.va){it.imdb=+(+d.va).toFixed(1);it.tmdb=Math.round(d.va*10)}if(d.age)it.age=fxAge(d.age);if(d.yt){it.yt=d.yt;it.ytl=d.ytl||""}
  if(d.cast&&d.cast.length)it.cast=d.cast.map(([nm,ch])=>{const aid="ra"+(hash(nm)>>>0).toString(36);A[aid]=nm;if(typeof CRED!=="undefined")(CRED[aid]=CRED[aid]||[]).some(x=>x[0]===it.id)||CRED[aid].push([it.id,ch||""]);return [aid,ch||""]})}
 /* même série TMDB proposée sous plusieurs noms (« Lupin », « Lupin - Partie 2 », « Lupin VOSTFR »…) : une seule fiche avec toutes ses versions */
 const ks=only?new Set(SERIES.filter(it=>only.has(it.id)&&it.sxk).map(it=>it.sxk)):null,rm=new Set();
 const keep={};for(const it of SERIES){const k=it.sxk;if(!k||!/^t/.test(k)||(ks&&!ks.has(k)))continue;const K=keep[k];if(!K){keep[k]=it;continue}
  for(const s2 of it._real.s||[])if(!K._real.s.some(x=>x[0]===s2[0]&&x[1]===s2[1]))K._real.s.push(s2);(it._real.c||[]).forEach(c=>{if(!K._real.c.includes(c))K._real.c.push(c)});
  for(const pid in PR.list){const x=PR.list[pid].sx;if(!x)continue;if(x.sp&&x.sp[it.id]&&!x.sp[K.id])x.sp[K.id]=x.sp[it.id];if(x.sp)delete x.sp[it.id];["done","mal","no","nseen"].forEach(f=>{if(Array.isArray(x[f])&&x[f].includes(it.id)){x[f]=x[f].filter(z=>z!==it.id);if(!x[f].includes(K.id))x[f].push(K.id)}})}
  if(S.favs.includes(it.id)){S.favs=S.favs.filter(z=>z!==it.id);if(!S.favs.includes(K.id))S.favs.push(K.id)}
  rm.add(it);ALL[it.id]=K}
 if(rm.size){let j=0;for(let i=0;i<SERIES.length;i++)if(!rm.has(SERIES[i]))SERIES[j++]=SERIES[i];SERIES.length=j}
 const top=only?[]:(SXD.top||[]).map(k=>byK[k]&&ALL[byK[k]]&&ALL[byK[k]].id).filter((v,i,A)=>v&&A.indexOf(v)===i);
 if(top.length){window.SXDATA=window.SXDATA||{};SXDATA.top=top}
 for(const nm in SXD.nl||{}){const c=SVCN(nm);if(!SXLG[c]||nm===c)SXLG[c]=SXD.nl[nm]}
 if(window.__sx&&__sx.X)__sx.X.cache={};SXD.n=only?(SXD.n||0)+n:n;return n}
async function sxImportSeries(files,say){const out=[];for(const f of files){say(`Lecture de ${f.name}…`);let d=null;try{d=JSON.parse((await f.text()).replace(/^﻿/,""))}catch(e){}
  if(!d||typeof d!=="object"||!d.m||!d.names)throw new Error(`${f.name} n'est pas un fichier de fiches séries prisme`);out.push(d)}
 let list=[];try{list=(await idbGet("series"))||[]}catch(e){}list=list.concat(out).slice(-4);await idbSet("series",list);return out.reduce((a,d)=>a+Object.keys(d.m).length,0)}
if(typeof REAL!=="undefined"&&REAL)idbGet("series").then(list=>{if(!list||!list.length)return;for(const d of list){Object.assign(SXD.m,d.m);Object.assign(SXD.names,d.names||{});Object.assign(SXD.nl,d.nl||{});if(d.top&&d.top.length)SXD.top=d.top}
 const n=sxApply();if(SXE.n)sxEpApply();const st=$("#rst");if(st)st.textContent+=` · ${n} fiches séries TMDB`;if(inApp()&&!S.loading)render(F&&F.dataset.fid)}).catch(()=>{});
/* ---------- épisodes du fournisseur (episodes.json, créé par la commande des données) ---------- */
const SXE={s:{},n:0};
function sxEpApply(){let n=0;const now=Date.now(),W=[];window.SXDATA=window.SXDATA||{};SXDATA.ep=SXDATA.ep||{};SXDATA.sy=SXDATA.sy||{};
 for(const it of SERIES){const r=it._real;if(!r)continue;let best=null;
  /* plusieurs noms chez le fournisseur (ex. une entrée par saison) : on réunit leurs épisodes */
  for(const s of r.s||[]){const d=SXE.s[s[1]];if(!d||!d.se)continue;if(!best){best={se:d.se.slice(),e:{...d.e}};continue}
   d.se.forEach((c,i)=>{best.se[i]=Math.max(best.se[i]||0,c)});for(const k in d.e)if(!best.e[k]||(!best.e[k][0]&&d.e[k][0]))best.e[k]=d.e[k]}
  if(best)for(let i=0;i<best.se.length;i++)best.se[i]=best.se[i]||0;
  if(!best||!best.se||!best.se.length)continue;n++;it.se=best.se.slice();const M={},sy={},dl=[];let ad=[];
  for(const k in best.e){const [t,d,o,rt,dt,a]=best.e[k];M[k]={t,d,o:frText(o),r:rt||null};if(d)dl.push(d);const s=+k.split("-")[0];if(dt){const y=+dt.slice(0,4);if(y&&(!sy[s]||y<sy[s]))sy[s]=y}if(a)ad.push([a,k])}
  /* titres, résumés et notes en français de TMDB (series.json) quand le fournisseur n'en donne pas */
  const T=it.sxk&&SXD.m[it.sxk]&&SXD.m[it.sxk].eps;
  if(T){for(const k in M){const x=T[k];if(!x)continue;if(x[0])M[k].t=x[0];if(x[1])M[k].o=x[1];if(!M[k].r&&x[2])M[k].r=x[2]}
   /* épisodes annoncés dans les 7 prochains jours (dates TMDB) */
   const t0=new Date();t0.setHours(0,0,0,0);for(const k in T){const ad=T[k][3];if(!ad||M[k])continue;const j=Math.round((new Date(ad+"T00:00:00")-t0)/864e5);if(j>=1&&j<=7){const [s,e]=k.split("-").map(Number);W.push({j,id:it.id,s,e})}}}
  SXDATA.ep[it.id]=M;SXDATA.sy[it.id]=sy;if(dl.length){dl.sort((a,b)=>a-b);it.ep=dl[dl.length>>1]}
  /* cette semaine : épisodes arrivés chez le fournisseur ces 7 derniers jours (saison entière d'un coup → une seule ligne) */
  ad=ad.filter(([a])=>now-a*1000<7*864e5).sort((p,q)=>q[0]-p[0]);if(!ad.length)continue;const byS={};
  for(const [a,k] of ad){const [s,e]=k.split("-").map(Number);(byS[s]=byS[s]||[]).push([a,e])}
  for(const s in byS){const L=byS[s],j=-Math.floor((now-L[0][0]*1000)/864e5);
   if(L.length>=3&&L.length>=(it.se[s-1]||0))W.push({j,id:it.id,s:+s,full:1});else L.slice(0,3).forEach(([a,e])=>W.push({j:-Math.floor((now-a*1000)/864e5),id:it.id,s:+s,e}))}}
 SXDATA.week=W.sort((p,q)=>q.j-p.j).slice(0,40);if(window.__sx&&__sx.X)__sx.X.cache={};SXE.n=n;return n}
async function sxImportEps(files,say){let n=0;for(const f of files){say(`Lecture de ${f.name}…`);let d=null;try{d=JSON.parse((await f.text()).replace(/^﻿/,""))}catch(e){}
  if(!d||typeof d!=="object"||!d.s)throw new Error(`${f.name} n'est pas un fichier d'épisodes prisme`);Object.assign(SXE.s,d.s);n+=Object.keys(d.s).length}
 await idbSet("eps",SXE.s);return n}
if(typeof REAL!=="undefined"&&REAL)idbGet("eps").then(d=>{if(!d)return;Object.assign(SXE.s,d);const n=sxEpApply();const st=$("#rst");if(st)st.textContent+=` · épisodes pour ${n} séries`;if(inApp()&&!S.loading)render(F&&F.dataset.fid)}).catch(()=>{});
