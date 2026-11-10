if(REAL){
 const FONTS=["serif","bebas","black","thin"];
 const col=k=>{const h=hash(k)%360;return ["#"+hsl(h,45,38),"#"+hsl((h+40)%360,45,10)]};
 const NOTE="Résumé, casting et notes complètes récupérés via TMDB dans l'application réelle.";
 const gOf=cats=>{const m=(REAL.fcats||[]).concat(REAL.scats||[]);const n=cats.map(k=>(m.find(c=>c[0]===k)||[])[1]).filter(Boolean)[0]||"Divers";return n};
 FILMS.splice(0,FILMS.length,...REAL.films.map(r=>({id:r.id,t:r.t,y:r.y||new Date((r.a||0)*1000).getFullYear()||2024,d:r.d||100,g:[gOf(r.c)],cat:r.c,imdb:r.r?Math.min(10,+r.r):6.8,tmdb:Math.round((r.r?Math.min(10,+r.r):6.8)*10),age:"Tous publics",dir:r.dir||"",f:FONTS[hash(r.id)%4],c:col(r.id),s:r.p||NOTE,cast:[],_real:r})));
 SERIES.splice(0,SERIES.length,...REAL.series.map(r=>{const cast=(r.cast||"").split(/\s*,\s*/).filter(Boolean).slice(0,6).map(n=>{const id="ra"+(hash(n)>>>0).toString(36);A[id]=n;return [id,""]});
  return {id:r.id,t:r.t,y:r.y||2024,net:"",se:[1],ep:45,g:(r.g?r.g.split(/\s*[,/]\s*/).filter(Boolean):[gOf(r.c)]).slice(0,2),cat:r.c,imdb:r.r?Math.min(10,+r.r):7,tmdb:Math.round((r.r?Math.min(10,+r.r):7)*10),age:"Tous publics",dir:r.dir||"",f:FONTS[hash(r.id)%4],c:col(r.id),s:r.p||NOTE,cast,_real:r}}));
}
