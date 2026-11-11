const FLUX={vod:{},ser:{},at:0};
/* ===================== Données réelles du fournisseur ===================== */
const RCODEC={"4K":"HEVC · 3840×2160","1080p":"H.264 · 1920×1080","720p":"H.264 · 1280×720","SD":"H.264 · 720×576"};
if(REAL){
 if(!CH[S.lch]&&CHS[0])S.lch=CHS[0].id;
 LCATS.splice(0,LCATS.length,["all","Toutes les chaînes"],["fav","Favoris"],...REAL.lcats);
 const itemOf=key=>key.startsWith("ch:")?(CH[key.slice(3)]||{})._real:(ALL[key]||{})._real;
 const plsOf=r=>r._pl||(r._pl=new Set(r.s.map(x=>x[0])));
 base=function(pl,key){const r=itemOf(key);return r?plsOf(r).has(pl.id):false};
 variants=function(pl,key){const r=itemOf(key);if(!r)return [];const L=r.s.filter(x=>x[0]===pl.id);
  if(key.startsWith("ch:"))return L.map((x,i)=>({id:pl.id+"|"+i,i,p:pl,q:x[2],name:x[1],codec:RCODEC[x[2]],audio:["Français"],subs:["Télétexte si diffusé"],ext:"ts",ar:x[3]||0}));
  return L.map((x,i)=>{const tag=tagOf(x[1]),fr=tag==="VOSTFR"?null:frOf(x[1]),frl=fr&&fr!=="VF"?`${FRL[fr]} · ${fr}`:"Français (VF)";const v={id:pl.id+"|"+i,i,p:pl,q:x[2],tag,fr,name:x[1],codec:RCODEC[x[2]],audio:tag==="VOSTFR"?["Anglais (VO)"]:tag==="MULTI"?[frl,"Anglais (VO)"]:[frl],subs:tag==="VOSTFR"?["Français"]:["Aucun"],size:"—",ext:x[3]||"mkv"};
   const fx=(ALL[key]||{}).type==="s"?FLUX.ser[x[1]]:FLUX.vod[x[4]];return fx?fluxApply(v,fx,tag):v})};
 addDays=function(pl,it){const a=it._real&&it._real.a;return a?Math.max(0,Math.floor((Date.now()/1000-a)/86400)):400};
 const M0=new Date().setHours(0,0,0,0)/60000;
 const TPLG={sport:"Sport",info:"Information",cine:"Film",kids:"Dessin animé",doc:"Documentaire",series:"Divertissement"};
 const _e=epg;epg=function(ch){if(!ch._real)return _e(ch);if(EPGC[ch.id])return EPGC[ch.id];
  let L=(REAL.epg[ch._real.e]||[]).map(([s,e,t,g,img])=>({s:s-M0,e:e-M0,t,g:g||TPLG[ch.tpl],img})).filter(p=>p.e>p.s).sort((a,b)=>a.s-b.s);
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
 /* titre propre : on retire, en partant de la fin, langue, qualité, source, son et année (« … Masters 2026 VOST » → « … Masters ») */
 TRAIL:/(?:^|[\s\-–:_.,|])(?:vost(?:-?fr)?|vostfr|vo|vf2?|vff|vfq|vfi|stfr|subfrench|truefrench|french|multi|eng|subs?|hdlight|hdr10\+?|hdr|dv|dolby ?vision|imax|3d|remux|web(?:-?dl|rip)?|blu-?ray|bdrip|brrip|dvdrip|x26[45]|h\.?26[45]|hevc|10 ?bits?|atmos|dts|ac3|aac|5\.1|7\.1|extended|uncut|remastered|director'?s ?cut|version longue|4k|uhd|fhd|hd|sd|1080[pi]?|720p?|2160p?|19[2-9]\d|20[0-3]\d)[\s\-–:_.,|]*$/i,
 title(n){let s=RI.base(n),p;do{p=s;const t=s.replace(RI.TRAIL,"").replace(/\s*[-–:|,]\s*$/,"").trim();if(t.length<2)break;s=t}while(s!==p);return s},
 id(p,k){return p+(hash(k)>>>0).toString(36)},
 ent(s){return s.replace(/&amp;/g,"&").replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').replace(/&apos;|&#39;/g,"'").replace(/&#x([0-9a-f]+);/gi,(_,h)=>String.fromCodePoint(parseInt(h,16))).replace(/&#(\d+);/g,(_,d)=>String.fromCodePoint(+d))},
 t(v){const m=/^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)?\s*([+-]\d{4})?/.exec(v||"");if(!m)return null;let ms=Date.UTC(+m[1],+m[2]-1,+m[3],+m[4],+m[5],+(m[6]||0));if(m[7]){const sg=m[7][0]==="-"?-1:1;ms-=sg*(+m[7].slice(1,3)*60+ +m[7].slice(3,5))*60000}else ms+=new Date().getTimezoneOffset()*60000;return Math.round(ms/60000)}
};
async function rReadJson(f,optional){
 let buf=new Uint8Array(await f.arrayBuffer());
 if(buf[0]===0x1f&&buf[1]===0x8b&&typeof DecompressionStream!=="undefined"){buf=new Uint8Array(await new Response(new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"))).arrayBuffer())}
 const t=new TextDecoder().decode(buf).replace(/^﻿/,"").trim();
 const fail=m=>{if(optional){RWARN.push(`${f.name} ignoré (${m})`);return null}throw new Error(`${f.name} : ${m}`)};
 if(!t)return fail("le fichier est vide, le serveur n'a rien renvoyé. Vérifie l'adresse (avec le port, ex. :8080), l'utilisateur et le mot de passe, puis relance la commande");
 if(/^</.test(t))return fail(`le serveur a renvoyé une page web au lieu des données (${/cloudflare|captcha/i.test(t)?"protection anti-robot":/403|forbidden/i.test(t)?"accès refusé":/404|not found/i.test(t)?"adresse introuvable":"réponse inattendue"}). Début : « ${t.replace(/<[^>]*>/g," ").replace(/\s+/g," ").trim().slice(0,90)} »`);
 try{const j=JSON.parse(t);if(j&&!Array.isArray(j)&&typeof j==="object"){if(j.user_info&&String(j.user_info.auth)==="0")return fail("identifiants refusés par le serveur");const arr=Object.values(j).find(Array.isArray);if(arr)return arr;const vals=Object.values(j);if(vals.length&&vals.every(v=>v&&typeof v==="object"))return vals}return j}
 catch(e){return fail(`le contenu n'est pas du JSON valide. Début : « ${t.replace(/\s+/g," ").slice(0,90)} »`)}}
const RWARN=[];
async function rReadEpg(f,want,status){
 let stream=f.stream();const head=new Uint8Array(await f.slice(0,2).arrayBuffer());
 if(head[0]===0x1f&&head[1]===0x8b){if(typeof DecompressionStream==="undefined")throw new Error("Guide compressé non pris en charge par ce navigateur");stream=stream.pipeThrough(new DecompressionStream("gzip"))}
 const rd=stream.pipeThrough(new TextDecoderStream()).getReader();const out={};let buf="",n=0,kept=0;const now=Date.now()/60000,lo=now-1440*2,hi=now+1800;
 const re=/<programme\b([^>]*)>([\s\S]*?)<\/programme>/g;
 for(;;){const {value,done}=await rd.read();if(value)buf+=value;let m,last=0;re.lastIndex=0;
  while((m=re.exec(buf))){last=re.lastIndex;n++;const a=m[1],ch=(/channel="([^"]*)"/.exec(a)||[])[1];if(!ch||!want.has(ch))continue;
   const s=RI.t((/start="([^"]*)"/.exec(a)||[])[1]),e=RI.t((/stop="([^"]*)"/.exec(a)||[])[1]);if(s==null||e==null||e<lo||s>hi)continue;
   const t=RI.ent((/<title[^>]*>([\s\S]*?)<\/title>/.exec(m[2])||[])[1]||"").trim(),g=RI.ent((/<category[^>]*>([\s\S]*?)<\/category>/.exec(m[2])||[])[1]||"").trim();
   const ic=(/<icon[^>]*src="([^"]*)"/.exec(m[2])||[])[1]||"";(out[ch]=out[ch]||[]).push(ic&&ic.length<220?[s,e,t.slice(0,90),g.slice(0,40),ic]:[s,e,t.slice(0,90),g.slice(0,40)]);kept++}
  buf=buf.slice(last);if(buf.length>4e6)buf=buf.slice(-2e6);
  if(n%2000<50)status(`Guide des programmes : ${n.toLocaleString("fr-FR")} programmes lus, ${kept.toLocaleString("fr-FR")} gardés…`);
  if(done)break}
 for(const k in out)out[k]=out[k].sort((a,b)=>a[0]-b[0]).slice(-140);return out}
async function rImport(files,provName,status){
 const by={};for(const f of files){const n=f.name.toLowerCase();
  if(/xmltv|epg|\.xml|\.gz$/.test(n))by.epg=f;else for(const k of ["get_live_categories","get_live_streams","get_vod_categories","get_vod_streams","get_series_categories","get_series"])if(n.startsWith(k+".")||n===k+".json"||n.startsWith(k+" "))by[k]=f}
 if(!by.get_live_streams&&!by.get_vod_streams&&!by.get_series)throw new Error("Je ne trouve pas les fichiers get_live_streams.json, get_vod_streams.json ou get_series.json. Choisis tous les fichiers du dossier créé par la commande.");
 const old=(()=>{try{return JSON.parse(localStorage.getItem("prisme-real")||"null")}catch(e){return null}})();
 const R=old&&old.pls?old:{pls:[],lcats:[],fcats:[],scats:[],chans:[],films:[],series:[],epg:{}};
 const pid="rp"+(R.pls.length+1);R.pls.push({id:pid,name:provName,at:Date.now()});
 const st={};
 const cats=async(file,pref,arr)=>{const m={};if(!file)return m;const L=await rReadJson(file,true);if(!Array.isArray(L))return m;const all=L.filter(c=>!RI.ADULT.test(c.category_name||""));const fr=all.filter(c=>RI.FR.test(c.category_name||""));
  (fr.length?fr:all).forEach(c=>{const nm=RI.cleanCat(c.category_name),key=RI.id(pref,RI.strip(nm));m[String(c.category_id)]=key;if(!arr.some(x=>x[0]===key))arr.push([key,nm])});return m};
 status("Lecture des catégories…");
 const lc=await cats(by.get_live_categories,"l",R.lcats),fc=await cats(by.get_vod_categories,"f",R.fcats),sc=await cats(by.get_series_categories,"s",R.scats);
 const merge=(arr,pref,key,make,add)=>{let it=arr.find(x=>x.k===key);if(!it){it=make();it.k=key;it.id=RI.id(pref,key);it.s=[];arr.push(it)}add(it);return it};
 if(by.get_live_streams){status("Lecture des chaînes…");const L=await rReadJson(by.get_live_streams);let n=0;
  const frOnly=!Object.keys(lc).length&&L.some(x=>RI.FR.test(x.name||""));for(const x of L){const ck=lc[String(x.category_id)];if(Object.keys(lc).length&&!ck)continue;if(frOnly&&!RI.FR.test(x.name||""))continue;if(RI.ADULT.test(x.name||""))continue;const nm=RI.base(x.name),key=RI.strip(nm);if(!key)continue;n++;
   merge(R.chans,"rc",key,()=>({n:nm,c:[],e:"",num:+x.num||0}),it=>{if(ck&&!it.c.includes(ck))it.c.push(ck);if(!it.e&&x.epg_channel_id)it.e=String(x.epg_channel_id);const ad=String(x.tv_archive)==="1"?Math.max(1,+x.tv_archive_duration||1):0;if(ad){it.ar=Math.max(it.ar||0,ad);st.arch=(st.arch||0)+1}if(it.s.length<8)it.s.push([pid,String(x.name).slice(0,60),RI.q(x.name),ad])})}
  st.chans=n}
 if(by.get_vod_streams){status("Lecture des films…");const L=await rReadJson(by.get_vod_streams);let n=0;
  const frOnly=!Object.keys(fc).length&&L.some(x=>RI.FR.test(x.name||""));for(const x of L){const ck=fc[String(x.category_id)];if(Object.keys(fc).length&&!ck)continue;if(frOnly&&!RI.FR.test(x.name||""))continue;if(RI.ADULT.test(x.name||""))continue;const t=RI.title(x.name),y=+x.year||RI.year(x.name),key=RI.strip(t)+"#"+(y||"");if(!t)continue;n++;
   merge(R.films,"rf",key,()=>({t,y,c:[],r:+x.rating||0,a:+x.added||0}),it=>{if(ck&&!it.c.includes(ck))it.c.push(ck);it.a=Math.max(it.a,+x.added||0);if(!it.r&&+x.rating)it.r=+x.rating;if(!it.tm&&/^\d+$/.test(String(x.tmdb||x.tmdb_id||""))&&+(x.tmdb||x.tmdb_id))it.tm=+(x.tmdb||x.tmdb_id);if(it.s.length<6)it.s.push([pid,String(x.name).slice(0,70),RI.q(x.name),x.container_extension||"mkv",String(x.stream_id||"")])})}
  st.films=n}
 if(by.get_series){status("Lecture des séries…");const L=await rReadJson(by.get_series);let n=0;
  const frOnly=!Object.keys(sc).length&&L.some(x=>RI.FR.test(x.name||""));for(const x of L){const ck=sc[String(x.category_id)];if(Object.keys(sc).length&&!ck)continue;if(frOnly&&!RI.FR.test(x.name||""))continue;if(RI.ADULT.test(x.name||""))continue;const t=RI.title(x.name),y=RI.year(x.releaseDate||x.release_date||"")||RI.year(x.name),key=RI.strip(t);if(!t)continue;n++;
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
const RICMD=`cat > /tmp/prisme-images.pl <<'PRISME_FIN'
#!/usr/bin/perl
# prisme : récupère les affiches TMDB des programmes du jour et les logos des chaînes
# Lit les dossiers prisme-* du Bureau et écrit images.json dans chacun.
use strict; use warnings; use JSON::PP; use MIME::Base64; use Time::Local; use File::Temp qw(tempdir); use Unicode::Normalize;
my $TMDB = $ENV{PRISME_TMDB} || "https://api.themoviedb.org/3";
my $IMGB = $ENV{PRISME_TMDB_IMG} || "https://image.tmdb.org/t/p";
my $MAXT = 300; my $MAXL = 600;
my @dirs = grep { -d $_ } glob("$ENV{HOME}/Desktop/prisme-*");
die "Aucun dossier prisme-... sur le Bureau. Lance d'abord la commande des données.\\n" unless @dirs;
print "Clé API TMDB (elle ne s'affiche pas quand tu tapes) : ";
system("stty", "-echo"); my $key = <STDIN>; system("stty", "echo"); print "\\n";
$key = "" unless defined $key; $key =~ s/\\s+//g;
die "Aucune clé saisie.\\n" unless length $key;
my @auth = length($key) > 40 ? ("-H", "Authorization: Bearer $key") : ();
my $akey = length($key) > 40 ? "" : "&api_key=$key";
my $tmp = tempdir(CLEANUP => 1);
my $J = JSON::PP->new->utf8->canonical;
my $hasSips = (-x "/usr/bin/sips") ? 1 : 0;

sub slurp { my ($f) = @_; open(my $h, "<:raw", $f) or return ""; local $/; my $d = <$h>; close $h; return defined $d ? $d : "" }
sub enc { my ($s) = @_; $s =~ s/([^A-Za-z0-9\\-_.~])/sprintf("%%%02X", ord $1)/ge; return $s }
sub ent { my ($s) = @_; $s =~ s/<!\\[CDATA\\[(.*?)\\]\\]>/$1/gs; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&(apos|#39);/'/g; $s =~ s/&amp;/&/g; $s =~ s/^\\s+|\\s+$//g; return $s }
sub tsec { my ($v) = @_; return undef unless $v && $v =~ /^(\\d{4})(\\d\\d)(\\d\\d)(\\d\\d)(\\d\\d)(\\d\\d)?\\s*([+-])?(\\d\\d)?(\\d\\d)?/;
  my $t = timegm($6 || 0, $5, $4, $3, $2 - 1, $1); if (defined $7) { my $o = ($8 * 60 + $9) * 60; $t -= ($7 eq "-" ? -$o : $o) } else { $t = timelocal($6 || 0, $5, $4, $3, $2 - 1, $1) } return $t }
sub simp { my ($s) = @_; $s = lc $s; $s =~ s/[^a-z0-9\\x80-\\xff]+//g; return $s }
sub clean { my ($t) = @_; $t =~ s/\\s*[-:–]\\s*(S\\d+\\s*E\\d+|saison\\s*\\d+|[ée]pisode\\s*\\d+).*$//i; $t =~ s/\\s*\\([^)]*\\)\\s*$//; $t =~ s/\\s*\\|.*$//; $t =~ s/^\\s+|\\s+$//g; return $t }
sub fetch_many { # [[url, file], ...] en parallèle
  my ($list, @h) = @_; return unless @$list;
  my $cfg = "$tmp/cfg" . int(rand(1e9)); open(my $c, ">", $cfg) or die; for my $u (@$list) { my ($url, $f) = @$u; $url =~ s/"/%22/g; print $c "url = \\"$url\\"\\noutput = \\"$f\\"\\n" } close $c;
  system("curl", "-sSL", "--compressed", "--max-time", "20", "--retry", "1", "-A", "Mozilla/5.0", "--parallel", "--parallel-max", "12", @h, "-K", $cfg);
}
sub datauri { my ($f, $maxkb) = @_; return undef unless -s $f;
  if ($hasSips) { my $o = "$f.png"; system("/usr/bin/sips -s format png -Z 300 '$f' --out '$o' >/dev/null 2>&1"); $f = $o if -s $o }
  my $d = slurp($f); return undef if length($d) > $maxkb * 1024;
  my $m = substr($d, 0, 4) eq "\\x89PNG" ? "image/png" : substr($d, 0, 2) eq "\\xff\\xd8" ? "image/jpeg" : substr($d, 0, 4) eq "RIFF" ? "image/webp" : substr($d, 0, 3) eq "GIF" ? "image/gif" : undef;
  return undef unless $m; return "data:$m;base64," . encode_base64($d, "") }

# --- vérifie la clé ---
my $chk = "$tmp/chk.json"; fetch_many([["$TMDB/configuration?x=1$akey", $chk]], @auth);
my $cj = eval { $J->decode(slurp($chk)) } || {};
die "TMDB refuse cette clé (" . ($cj->{status_message} || "réponse illisible") . "). Vérifie-la sur themoviedb.org > Paramètres > API.\\n" if !$cj->{images};
print "✓ Clé TMDB acceptée\\n";

my $now = time; my %done;
# --- guide public français (xmltvfr.fr) : images par programme, comme les applis TV ---
sub cnorm { my ($s) = @_; $s = "" unless defined $s; utf8::decode($s) unless utf8::is_utf8($s); $s = NFD(lc $s); $s =~ s/\\p{M}//g;
  $s =~ s/^\\s*(\\[|\\()?\\s*(fr|fra|france|be|ch)\\s*(\\]|\\))?\\s*[|:\\-]+\\s*//; $s =~ s/\\b(uhd|fhd|full ?hd|hd|sd|4k|hevc|h\\.?26[45]|backup|vip|raw|50 ?fps|\\d{3,4}p|\\.fr|\\.be)\\b//g; $s =~ s/[^a-z0-9+]//g; return $s }
my ($pub, $pubsrc) = ("", "");
for my $u (($ENV{PRISME_PUB} ? ($ENV{PRISME_PUB}) : ()), "https://xmltvfr.fr/xmltv/xmltv.xml.gz", "https://xmltvfr.fr/xmltv/xmltv_fr.xml.gz", "https://xmltvfr.fr/xmltv/xmltv_tnt.xml.gz", "https://xmltvfr.fr/xmltv/xmltv.zip", "https://xmltvfr.fr/xmltv/xmltv.xml") {
  my $f = "$tmp/pub"; unlink $f; print "Guide public : essai de $u…\\n"; system("curl", "-sSL", "--max-time", "180", "-A", "Mozilla/5.0", "-o", $f, $u);
  next unless -s $f; my $h = substr(slurp_head($f), 0, 4); my $d;
  if (substr($h, 0, 2) eq "\\x1f\\x8b") { $d = \`gunzip -c "$f" 2>/dev/null\` } elsif ($h eq "PK\\x03\\x04") { $d = \`unzip -p "$f" 2>/dev/null\` } else { $d = slurp($f) }
  if ($d && $d =~ /<programme\\b/) { $pub = $d; $pubsrc = $u; last } }
sub slurp_head { my ($f) = @_; open(my $h, "<:raw", $f) or return ""; read($h, my $b, 8); close $h; return defined $b ? $b : "" }
my (%pubch, %pubprog);
if ($pub) { while ($pub =~ /<channel\\b[^>]*\\bid="([^"]*)"[^>]*>(.*?)<\\/channel>/gs) { my ($id, $b) = ($1, $2); my @dn = $b =~ /<display-name[^>]*>(.*?)<\\/display-name>/gs; my $idn = $id; $idn =~ s/\\.[a-z]{2,3}$//; for my $n (@dn, $idn) { my $k = cnorm(ent($n)); $pubch{$k} //= $id if length $k } }
  my $pc = 0; while ($pub =~ /<programme\\b([^>]*)>(.*?)<\\/programme>/gs) { my ($a, $b) = ($1, $2); my ($ch) = $a =~ /\\bchannel="([^"]*)"/; next unless $ch;
    my ($st) = $a =~ /\\bstart="([^"]*)"/; my ($en) = $a =~ /\\bstop="([^"]*)"/; my $s = tsec($st); my $e = tsec($en); next unless defined $s && defined $e; next if $e < $now - 3600 || $s > $now + 8 * 3600;
    my ($t) = $b =~ /<title[^>]*>(.*?)<\\/title>/s; next unless defined $t; my ($g) = $b =~ /<category[^>]*>(.*?)<\\/category>/s; my ($ic) = $b =~ /<icon[^>]*\\bsrc="([^"]*)"/;
    push @{ $pubprog{$ch} }, [int($s / 60), int($e / 60), ent($t), defined $g ? ent($g) : "", defined $ic ? ent($ic) : ""]; $pc++ }
  printf "✓ Guide public : %d chaînes, %d programmes dans les 8 prochaines heures\\n", scalar(keys %pubch), $pc }
else { print "⚠ Guide public indisponible : seules les affiches TMDB seront utilisées.\\n" }
for my $dir (@dirs) {
  print "== $dir\\n";
  my $x = slurp("$dir/xmltv.xml"); if (substr($x, 0, 2) eq "\\x1f\\x8b") { $x = \`gunzip -c "$dir/xmltv.xml"\` }
  my $ls = eval { $J->decode(slurp("$dir/get_live_streams.json")) }; $ls = [] unless ref $ls eq "ARRAY";
  # --- logos ---
  my %icon; while ($x =~ /<channel\\b[^>]*\\bid="([^"]*)"[^>]*>(.*?)<\\/channel>/gs) { my ($id, $b) = ($1, $2); $icon{ent($id)} = ent($1) if $b =~ /<icon[^>]*\\bsrc="([^"]*)"/ }
  my (@lg, %seenu); my $n = 0;
  for my $s (@$ls) { next unless ref $s eq "HASH"; my $e = defined $s->{epg_channel_id} ? "$s->{epg_channel_id}" : ""; my $u = ($e ne "" && $icon{$e}) || $s->{stream_icon} || ""; next unless $u =~ /^https?:/;
    next if $s->{name} && $s->{name} =~ /adult|xxx|porn|\\+ ?18/i; $u =~ s/ /%20/g;
    my $f = $seenu{$u} //= do { $n++; "$tmp/l$n" }; my $nm = "" . ($s->{name} || ""); utf8::encode($nm) if utf8::is_utf8($nm); utf8::encode($e) if utf8::is_utf8($e); push @lg, [$e, $nm, $u, $f]; last if $n >= $MAXL }
  print "Logos des chaînes : ", scalar(keys %seenu), " à télécharger…\\n";
  fetch_many([map { [$_, $seenu{$_}] } keys %seenu]);
  my (@logos, %lu); for my $l (@lg) { my $f = $l->[3]; $lu{$f} //= datauri($f, 120) // ""; push @logos, [$l->[0], $l->[1], $lu{$f}] if $lu{$f} ne "" }
  # --- programmes du jour ---
  my %tit; my $order = 0;
  while ($x =~ /<programme\\b([^>]*)>(.*?)<\\/programme>/gs) { my ($a, $b) = ($1, $2);
    my ($st) = $a =~ /\\bstart="([^"]*)"/; my ($en) = $a =~ /\\bstop="([^"]*)"/; my $s = tsec($st); my $e = tsec($en); next unless defined $s && defined $e;
    next if $e < $now - 3600 || $s > $now + 8 * 3600;
    my ($t) = $b =~ /<title[^>]*>(.*?)<\\/title>/s; next unless defined $t; $t = ent($t); next if length($t) < 2;
    my @cat = $b =~ /<category[^>]*>(.*?)<\\/category>/gs; my $cat = join(" ", map { ent($_) } @cat);
    next if $cat =~ /sport|foot|rugby|tennis|info|news|journal|m[ée]t[ée]o|magazine|jeu|game|t[ée]l[ée]achat|d[ée]bat|politique/i;
    next if $t =~ /^(journal|le journal|jt|m[ée]t[ée]o|info|infos|programme|fin des programmes|t[ée]l[ée]shopping|le 20h|le 13h|tirage)/i;
    my $c = clean($t); next if length($c) < 2;
    my $live = ($s <= $now && $e > $now) ? 0 : 1;
    $tit{$c} //= { t => $c, raw => {}, live => $live, ord => $order++, film => ($cat =~ /film|cin[ée]|t[ée]l[ée]film|movie/i ? 1 : 0) };
    $tit{$c}{raw}{$t} = 1; $tit{$c}{live} = 0 if !$live }
  my @T = sort { $a->{live} <=> $b->{live} || $a->{ord} <=> $b->{ord} } values %tit; @T = @T[0 .. $MAXT - 1] if @T > $MAXT;
  print "Programmes à rechercher sur TMDB : ", scalar(@T), "…\\n";
  my $i = 0; fetch_many([map { $i++; $_->{q} = "$tmp/q$i.json"; ["$TMDB/search/multi?query=" . enc($_->{t}) . "&language=fr-FR&include_adult=false$akey", $_->{q}] } @T], @auth);
  my (@dl, %pf); my $k = 0;
  for my $p (@T) { my $r = eval { $J->decode(slurp($p->{q})) } || {}; my $want = simp($p->{t}); my $best;
    for my $m (@{ $r->{results} || [] }) { next unless ($m->{media_type} || "") =~ /^(movie|tv)$/; next unless $m->{backdrop_path} || $m->{poster_path};
      my @names = grep { defined } ($m->{title}, $m->{name}, $m->{original_title}, $m->{original_name});
      my $ok = grep { my $s = simp(do { my $z = $_; utf8::encode($z) if utf8::is_utf8($z); $z }); $s eq $want || (length($want) >= 6 && (index($s, $want) == 0 || index($want, $s) == 0) && length($s) >= 6) } @names;
      next unless $ok; $best = $m if !$best || ($p->{film} && $m->{media_type} eq "movie" && $best->{media_type} ne "movie"); last if $best && (!$p->{film} || $best->{media_type} eq "movie") }
    next unless $best; my $path = $best->{backdrop_path} ? "/w300$best->{backdrop_path}" : "/w185$best->{poster_path}";
    $k++; $p->{f} = "$tmp/p$k"; push @dl, ["$IMGB$path", $p->{f}] }
  print "Affiches trouvées : ", scalar(@dl), ", téléchargement…\\n";
  fetch_many(\\@dl);
  my %prog; for my $p (@T) { next unless $p->{f}; my $u = datauri($p->{f}, 160); next unless $u; $prog{$_} = $u for keys %{ $p->{raw} } }
  my (@pch, %pdl); my $pi = 0;
  if ($pub) { my %by; for my $s (@$ls) { next unless ref $s eq "HASH"; my $nm = "" . ($s->{name} || ""); next if $nm =~ /adult|xxx|porn|\\+ ?18/i; my $id = $pubch{cnorm($nm)}; next unless $id && $pubprog{$id}; utf8::encode($nm) if utf8::is_utf8($nm); push @{ $by{$id} }, $nm }
    for my $id (sort keys %by) { my @pp; for my $q (sort { $a->[0] <=> $b->[0] } @{ $pubprog{$id} }) { my @r = @$q; my $ic = pop @r;
        if ($ic =~ /^https?:/ && $pi < 700) { $ic =~ s/ /%20/g; my $f = $pdl{$ic} //= do { $pi++; "$tmp/g$pi" }; push @r, $f } push @pp, \\@r }
      push @pch, { n => $by{$id}, p => \\@pp } }
    print "Guide public : ", scalar(@pch), " de tes chaînes reconnues, $pi images de programmes à télécharger…\\n"; fetch_many([map { [$_, $pdl{$_}] } keys %pdl]);
    my %du; for my $c (@pch) { for my $r (@{ $c->{p} }) { if (@$r == 5) { my $f = pop @$r; $du{$f} //= datauri($f, 200) // ""; push @$r, $du{$f} if $du{$f} ne "" } } } }
  my $out = { v => 2, at => $now, logos => \\@logos, progs => \\%prog, chans => \\@pch, pubsrc => $pubsrc };
  open(my $o, ">:raw", "$dir/images.json") or die "Impossible d'écrire $dir/images.json\\n"; print $o JSON::PP->new->canonical->encode($out); close $o;
  my $ni = 0; for my $c (@pch) { $ni += grep { @$_ == 5 } @{ $c->{p} } }
  printf "✓ images.json : %d logos, %d affiches TMDB, %d chaînes avec le guide public dont %d images de programmes, %.1f Mo\\n", scalar(@logos), scalar(keys %prog), scalar(@pch), $ni, (-s "$dir/images.json") / 1048576;
}
print "Terminé. Ajoute images.json dans le simulateur (bouton « Choisir les fichiers… »).\\n";
system("open", $dirs[0]) if -x "/usr/bin/open";
PRISME_FIN
perl /tmp/prisme-images.pl`;
/* ---------- panneau sous la télécommande ---------- */
const RCMD=`c(){ curl -sSLG --compressed -A "Mozilla/5.0" "$@"; }; printf "Nom de ce fournisseur (ex. IPTV1) : "; read -r F; printf "Adresse du serveur (ex. http://monserveur.com:8080) : "; read -r U; printf "Nom d'utilisateur : "; read -r N; printf "Mot de passe : "; read -rs P; echo; case "$U" in http*) ;; *) U="http://$U";; esac; U="\${U%%/get.php*}"; U="\${U%%/player_api.php*}"; U="\${U%/}"; R=$(c "$U/player_api.php" --data-urlencode "username=$N" --data-urlencode "password=$P"); case "$R" in *'"auth":1'*|*'"auth": 1'*|*'"auth":"1"'*) echo "✓ Connexion acceptée";; *) echo "⚠ Le serveur refuse la connexion ou répond autre chose. Début de la réponse :"; echo "\${R:0:200}";; esac; D=~/Desktop/prisme-"\${F// /-}"; mkdir -p "$D" && cd "$D" && for a in get_live_categories get_live_streams get_vod_categories get_vod_streams get_series_categories get_series; do c "$U/player_api.php" --data-urlencode "username=$N" --data-urlencode "password=$P" --data-urlencode "action=$a" -o "$a.json"; echo "✓ $a : $(wc -c < "$a.json" | tr -d ' ') octets, début : $(head -c 60 "$a.json")"; done; c "$U/xmltv.php" --data-urlencode "username=$N" --data-urlencode "password=$P" -o xmltv.xml; echo "✓ guide : $(wc -c < xmltv.xml | tr -d ' ') octets"; ${typeof RXFLUX!=="undefined"?RXFLUX:""}unset P R; open "$D"`;
document.querySelector(".ldemo").insertAdjacentHTML("afterend",`<section class="rimp">
 <h2>Mes données fournisseur <span class="rst" id="rst">${REAL?`Données réelles : ${REAL.pls.map(p=>esc(p.name)).join(" + ")} · ${REAL.chans.length} chaînes · ${REAL.films.length} films · ${REAL.series.length} séries`:"Données de démonstration"}</span></h2>
 <p>Tes chaînes, films, séries et ton guide des programmes, sans aucune lecture vidéo. Tes identifiants restent sur ton Mac : seules les listes sont lues ici, et elles restent dans ce navigateur.</p>
 <ol><li>Sur ton Mac, ouvre <b>Terminal</b>, colle cette commande et appuie sur Entrée. Elle te demande le nom du fournisseur, l'adresse du serveur, l'utilisateur et le mot de passe (qui ne s'affiche pas quand tu tapes), puis crée un dossier sur ton Bureau et l'ouvre. Elle demande aussi au serveur la <b>fiche technique de chaque flux</b> (qualité, HDR, codec, son, débit, taille) sans ouvrir aucun flux, et l'écrit dans <b>flux.json</b>, avec <b>tous les épisodes de chaque série</b> (saisons, titres, durées, résumés) dans <b>episodes.json</b> : la 1ʳᵉ fois, compte quelques minutes, ensuite seuls les nouveaux films sont demandés.</li></ol>
 <div class="rcmd"><code id="rcmd">${esc(RCMD)}</code><button type="button" id="rcopy">Copier</button></div>
 <ol start="2"><li>Choisis ici <b>tous les fichiers</b> de ce dossier (⌘A dans la fenêtre de choix les sélectionne tous). Pour un 2ᵉ fournisseur, refais les deux étapes : les catalogues sont fusionnés.</li></ol>
 <div class="rrow"><label for="rname">Nom du fournisseur</label><input id="rname" value="${REAL?"Fournisseur "+(REAL.pls.length+1):"Mon fournisseur"}" autocomplete="off"><label class="rbtn" for="rfiles">Choisir les fichiers…</label><input type="file" id="rfiles" multiple accept=".json,.xml,.gz,.txt,application/json,text/xml" hidden>${REAL?'<button type="button" id="rdemo">Revenir aux données de démo</button>':""}</div>
 <ol start="3"><li><b>Affiches et logos</b> (après les données) : dans Terminal, colle cette 2ᵉ commande. Elle te demande ta clé API TMDB (qui ne s'affiche pas), récupère les images des programmes depuis le guide public français (comme les applis TV), complète avec les affiches TMDB, récupère les logos des chaînes et crée <b>images.json</b> dans chaque dossier prisme-… Choisis ensuite les 8 fichiers du dossier (les 7 + images.json) avec le même bouton : ⌘A dans la fenêtre de choix les sélectionne tous.</li></ol>
 <div class="rcmd"><code id="ricmd">Script de récupération des affiches · ${RICMD.split("\n").length} lignes · utilise le bouton Copier</code><button type="button" id="ricopy">Copier</button></div>
 <ol start="4"><li><b>Fiches films complètes</b> (résumé, casting, sagas, recommandations, plateformes de streaming, affiches) : colle cette 3ᵉ commande dans Terminal. Elle te redemande ta clé TMDB et crée <b>films.json</b> dans chaque dossier prisme-… La 1ʳᵉ fois, compte 5 à 15 minutes ; ensuite seuls les nouveaux films sont téléchargés. Choisis enfin films.json avec le même bouton (seul ou avec les autres fichiers).</li></ol>
 <div class="rcmd"><code id="rfcmd">Script des fiches films · ${RFCMD.split("\n").length} lignes · utilise le bouton Copier</code><button type="button" id="rfcopy">Copier</button></div>
 <ol start="5"><li><b>Fiches séries</b> (affiches, grandes images, résumé, casting, chaîne, note, top 10 de la semaine) : colle cette 4ᵉ commande dans Terminal. Elle te redemande ta clé TMDB et crée <b>series.json</b> dans chaque dossier prisme-… Quand TMDB ne connaît pas une série, elle prend l'affiche donnée par ton fournisseur. La 1ʳᵉ fois, compte 5 à 15 minutes. Choisis ensuite series.json avec le même bouton.</li></ol>
 <div class="rcmd"><code id="rscmd">Script des fiches séries · ${RSCMD.split("\n").length} lignes · utilise le bouton Copier</code><button type="button" id="rscopy">Copier</button></div>
 <div class="rlog" id="rlog" role="status"></div>
</section>`);
$("#rcopy").addEventListener("click",()=>{const done=()=>{$("#rcopy").textContent="Copié";setTimeout(()=>$("#rcopy").textContent="Copier",1600)};
 if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(RCMD).then(done,()=>{const r=document.createRange();r.selectNodeContents($("#rcmd"));const s=getSelection();s.removeAllRanges();s.addRange(r)});
 else{const r=document.createRange();r.selectNodeContents($("#rcmd"));const s=getSelection();s.removeAllRanges();s.addRange(r)}});
$("#rname").addEventListener("keydown",e=>e.stopPropagation());
$("#rscopy").addEventListener("click",()=>{const b=$("#rscopy");const done=()=>{b.textContent="Copié";setTimeout(()=>b.textContent="Copier",1600)};const fb=()=>{const t=document.createElement("textarea");t.value=RSCMD;t.style.cssText="position:fixed;left:-9999px";document.body.appendChild(t);t.select();try{document.execCommand("copy");done()}catch(e){b.textContent="Copie impossible"}t.remove()};
 if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(RSCMD).then(done,fb);else fb()});
$("#rfcopy").addEventListener("click",()=>{const b=$("#rfcopy");const done=()=>{b.textContent="Copié";setTimeout(()=>b.textContent="Copier",1600)};const fb=()=>{const t=document.createElement("textarea");t.value=RFCMD;t.style.cssText="position:fixed;left:-9999px";document.body.appendChild(t);t.select();try{document.execCommand("copy");done()}catch(e){b.textContent="Copie impossible"}t.remove()};
 if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(RFCMD).then(done,fb);else fb()});
$("#ricopy").addEventListener("click",()=>{const b=$("#ricopy");const done=()=>{b.textContent="Copié";setTimeout(()=>b.textContent="Copier",1600)};const fb=()=>{const t=document.createElement("textarea");t.value=RICMD;t.style.cssText="position:fixed;left:-9999px";document.body.appendChild(t);t.select();try{document.execCommand("copy");done()}catch(e){b.textContent="Copie impossible"}t.remove()};
 if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(RICMD).then(done,fb);else fb()});
$("#rfiles").addEventListener("change",async e=>{const files=[...e.target.files];if(!files.length)return;const log=$("#rlog");const say=m=>{log.textContent=m};log.classList.remove("err");
 RWARN.length=0;try{const name=($("#rname").value||"Mon fournisseur").trim().slice(0,40);const r=await rImport(files,name,say);
  const R=JSON.parse(localStorage.getItem("prisme-real"));
  S.playlists=R.pls.map((p,i)=>({id:p.id,name:p.name,url:"Importé le "+new Date(p.at).toLocaleDateString("fr-FR"),user:"données réelles",pass:"",epg:true,on:true,seed:i+1,real:true}));S.adding=false;S.stack=[{t:"home"}];S.tab="live";save();
  try{localStorage.removeItem("prisme-atv-live")}catch(_){}
  say(`${r.arch?`Replay disponible : ${r.arch} flux de chaînes l'acceptent. `:r.chans?"Replay : ton fournisseur ne l'indique sur aucune chaîne. ":""}Import réussi : ${r.chans??0} flux de chaînes, ${r.films??0} films, ${r.series??0} séries${r.epg?`, ${r.epg.toLocaleString("fr-FR")} programmes`:""}.${r.keptF<r.totF?` ${r.keptF} films les plus récents gardés sur ${r.totF} (mémoire du navigateur).`:""} ${RWARN.length?" Attention : "+RWARN.join(" · "):""} Redémarrage du simulateur…`);
  setTimeout(()=>location.reload(),RWARN.length?6000:1400)}
 catch(err){log.classList.add("err");say("Import impossible : "+err.message)}
 e.target.value=""});
if($("#rdemo"))$("#rdemo").addEventListener("click",()=>{try{localStorage.removeItem("prisme-real");localStorage.removeItem("prisme-atv-live")}catch(_){}S.playlists=[];S.stack=[{t:"home"}];S.tab="films";save();location.reload()});
/* ---------- images : affiches TMDB et logos (stockés dans IndexedDB, données plus lourdes) ---------- */
const IMG={l:{},n:{},p:{},count:0};
function idb(){return new Promise((ok,ko)=>{try{const r=indexedDB.open("prisme",1);r.onupgradeneeded=()=>r.result.createObjectStore("kv");r.onsuccess=()=>ok(r.result);r.onerror=()=>ko(r.error)}catch(e){ko(e)}})}
async function idbSet(k,v){const db=await idb();return new Promise((ok,ko)=>{const t=db.transaction("kv","readwrite");t.objectStore("kv").put(v,k);t.oncomplete=ok;t.onerror=()=>ko(t.error)})}
async function idbGet(k){const db=await idb();return new Promise((ok,ko)=>{const t=db.transaction("kv","readonly");const r=t.objectStore("kv").get(k);r.onsuccess=()=>ok(r.result);r.onerror=()=>ko(r.error)})}
const EXTRA={};
function imgLoad(d){if(!d)return;for(const c of d.chans||[])for(const n of c.n||[]){const k=RI.strip(RI.base(n));EXTRA[k]=c.p}for(const [e,n,u] of d.logos||[]){if(e)IMG.l[e]=u;if(n)IMG.n[RI.strip(RI.base(n))]=u}for(const t in d.progs||{})IMG.p[RI.strip(t)]=d.progs[t];IMG.count=Object.keys(IMG.p).length+Object.keys(IMG.l).length}
const imgProg=p=>p&&(p.img||IMG.p[RI.strip(p.t||"")])||"";
const imgLogo=c=>c&&c._real&&(IMG.l[c._real.e]||IMG.n[RI.strip(c.n)])||"";
if(REAL){const M1=new Date().setHours(0,0,0,0)/60000;const _e2=epg;epg=function(ch){if(!ch._real||EPGC[ch.id])return _e2(ch);const X=EXTRA[ch._real.k];const L=_e2(ch);if(!X||!X.length)return L;
 const ex=X.map(([s,e,t,g,img])=>({s:s-M1,e:e-M1,t,g:g||L[0].g,img}));
 if(L.length===1&&L[0].t==="Programme non communiqué")return EPGC[ch.id]=ex;
 L.forEach(p=>{if(p.img)return;const m=ex.find(x=>Math.abs(x.s-p.s)<=10&&x.img);if(m)p.img=m.img});return EPGC[ch.id]=L}}
if(REAL)idbGet("images").then(list=>{if(!list||!list.length)return;list.forEach(imgLoad);for(const k in EPGC)delete EPGC[k];const st=$("#rst");if(st)st.textContent+=` · ${Object.keys(IMG.p).length} affiches TMDB · ${Object.keys(IMG.l).length} logos · guide public sur ${Object.keys(EXTRA).length} chaînes`;if(inApp()&&!S.loading)render(F&&F.dataset.fid)}).catch(()=>{});
async function rImportImages(files,status){const out=[];for(const f of files){status(`Lecture de ${f.name}…`);let d=null;try{d=JSON.parse((await f.text()).replace(/^\uFEFF/,""))}catch(e){};if(!d||typeof d!=="object"||!d.progs)throw new Error(`${f.name} n'est pas un fichier d'images prisme`);out.push(d)}
 let list=[];try{list=(await idbGet("images"))||[]}catch(e){}list=list.concat(out).slice(-4);await idbSet("images",list);
 return out.reduce((a,d)=>[a[0]+Object.keys(d.progs).length,a[1]+(d.logos||[]).length],[0,0])}
{const inp=$("#rfiles");inp.addEventListener("change",async e=>{const all=[...e.target.files];const im=all.filter(f=>/^images.*\.json$/i.test(f.name)),fj=all.filter(f=>/^films.*\.json$/i.test(f.name)),fl=all.filter(f=>/^flux.*\.json$/i.test(f.name)),sj=all.filter(f=>/^series.*\.json$/i.test(f.name)),ej=all.filter(f=>/^episodes.*\.json$/i.test(f.name));if(!im.length&&!fj.length&&!fl.length&&!sj.length&&!ej.length)return;
 e.stopImmediatePropagation();const rest=all.filter(f=>!im.includes(f)&&!fj.includes(f)&&!fl.includes(f)&&!sj.includes(f)&&!ej.includes(f));const log=$("#rlog");const say=m=>{log.textContent=m};log.classList.remove("err");
 try{if(rest.length){RWARN.length=0;const name=($("#rname").value||"Mon fournisseur").trim().slice(0,40);await rImport(rest,name,say);const R=JSON.parse(localStorage.getItem("prisme-real"));
   S.playlists=R.pls.map((p,i)=>({id:p.id,name:p.name,url:"Importé le "+new Date(p.at).toLocaleDateString("fr-FR"),user:"données réelles",pass:"",epg:true,on:true,seed:i+1,real:true}));S.adding=false;S.stack=[{t:"home"}];S.tab="live";save()}
  const [np,nl]=im.length?await rImportImages(im,say):[0,0];const nf=fj.length?await fxImportFilms(fj,say):0;const nx=fl.length?await fluxImport(fl,say):0;const nsx=sj.length?await sxImportSeries(sj,say):0;const nep=ej.length?await sxImportEps(ej,say):0;
  if(!rest.length&&!REAL){say(`Fichiers enregistrés (${np} affiches, ${nl} logos, ${nf} fiches films, ${nsx} fiches séries), mais le simulateur ne trouve pas tes données fournisseur dans ce navigateur : il affiche encore les données de démo. Sélectionne en une seule fois les 7 fichiers du dossier prisme-… ET images.json (8 fichiers), avec la touche ⌘ pour en choisir plusieurs.`);return}
  say(`${im.length?`Images importées : ${np} affiches de programmes, ${nl} logos de chaînes. `:""}${fj.length?`Fiches films importées : ${nf} films TMDB. `:""}${sj.length?`Fiches séries importées : ${nsx} séries. `:""}${ej.length?`Épisodes importés pour ${nep} séries. `:""}Redémarrage du simulateur…`);setTimeout(()=>location.reload(),1400)}
 catch(err){log.classList.add("err");say("Import impossible : "+err.message)}e.target.value=""},true)}
if($("#rdemo"))$("#rdemo").addEventListener("click",()=>{idbSet("images",[]).catch(()=>{});idbSet("series",[]).catch(()=>{});idbSet("eps",null).catch(()=>{})},true);
/* titres déjà importés : on les nettoie aussi (sans réimport) */
if(typeof REAL!=="undefined"&&REAL){for(const f of FILMS)if(f._real&&!f.tmd)f.t=RI.title(f.t)}
/* ---------- fiche technique des flux (flux.json) : connue avant d'ouvrir le flux ---------- */
const fluxQ=(w,h)=>h>=1600||w>=3200?"4K":h>=900||w>=1700?"1080p":h>=650||w>=1200?"720p":"SD";
const VCOD={hevc:"HEVC",h265:"HEVC",h264:"H.264",avc:"H.264",av1:"AV1",mpeg2video:"MPEG-2",vp9:"VP9"},ACOD={eac3:"E-AC3",ac3:"AC3",aac:"AAC",truehd:"TrueHD",dts:"DTS",mp3:"MP3",opus:"Opus",flac:"FLAC",mp2:"MP2"};
const LANG={frq:"Français (Québec)",frf:"Français (France)",fre:"Français",fra:"Français",fr:"Français",eng:"Anglais",en:"Anglais",spa:"Espagnol",ger:"Allemand",deu:"Allemand",ita:"Italien",jpn:"Japonais"};
const chLbl=c=>c>=8?"7.1":c>=6?"5.1":c===2?"stéréo":c===1?"mono":c?c+" canaux":"";
function fluxApply(v,f,tag){const [w,h,vc,hdr,fps,kb,ac,ch,lg,dur,atm,ext,neps]=f;const o={...v,fx:1};
 if(h||w)o.q=fluxQ(w,h);
 o.hdr=hdr||"";o.codec=[VCOD[vc]||(vc||"").toUpperCase(),hdr,w&&h?`${w}×${h}`:"",fps?`${String(fps).replace(".",",")} i/s`:"",kb?`${(kb/1000).toFixed(kb>=10000?0:1).replace(".",",")} Mb/s`:""].filter(Boolean).join(" · ");
 if(lg==="frq"&&tag!=="VOSTFR"){if(tag==="MULTI")o.fr="VFQ";else o.tag=o.fr="VFQ"}else if(lg==="frf"&&tag!=="VOSTFR"){if(tag==="MULTI")o.fr="VFF";else if(o.tag==="VF")o.tag=o.fr="VFF"}
 const frn=o.fr&&o.fr!=="VF"?FRL[o.fr]:"Français",al=(LANG[lg]&&!/^fr/.test(lg)?LANG[lg]:null)||(tag==="VOSTFR"?"Anglais (VO)":frn)+(o.fr&&o.fr!=="VF"&&tag!=="VOSTFR"?" · "+o.fr:""),an=[ACOD[ac]||(ac||"").toUpperCase(),chLbl(ch),atm?"Atmos":""].filter(Boolean).join(" ");
 o.audio=[an?`${al} · ${an}`:al,...(tag==="MULTI"?[/^(fr|fre|fra|frq|frf)$/.test(lg)||!lg?"Anglais (VO)":(o.fr&&o.fr!=="VF"?FRL[o.fr]+" · "+o.fr:"Français (VF)")]:[])];
 if(kb&&dur){const go=kb*dur/8/1e6;o.size=(go>=1?go.toFixed(1).replace(".",",")+" Go":Math.round(go*1000)+" Mo")+(neps?" / épisode":"")}
 if(ext)o.ext=ext;if(neps)o.neps=neps;o.codec+=` · ${o.size&&o.size!=="—"?o.size+" · ":""}${(o.ext||"").toUpperCase()} · ✓ fiche du serveur`;return o}
async function fluxImport(files,say){let n=0;for(const f of files){say(`Lecture de ${f.name}…`);let d=null;try{d=JSON.parse((await f.text()).replace(/^﻿/,""))}catch(e){}
  if(!d||!d.vod)throw new Error(`${f.name} n'est pas un fichier flux prisme`);Object.assign(FLUX.vod,d.vod);Object.assign(FLUX.ser,d.ser||{});FLUX.at=d.at;n+=Object.keys(d.vod).length+Object.keys(d.ser||{}).length}
 await idbSet("flux",{vod:FLUX.vod,ser:FLUX.ser,at:FLUX.at});return n}
if(typeof REAL!=="undefined"&&REAL)idbGet("flux").then(d=>{if(!d)return;Object.assign(FLUX.vod,d.vod||{});Object.assign(FLUX.ser,d.ser||{});FLUX.at=d.at||0;const st=$("#rst");if(st)st.textContent+=` · qualité connue pour ${Object.keys(FLUX.vod).length} flux`;if(inApp()&&!S.loading)render(F&&F.dataset.fid)}).catch(()=>{});
