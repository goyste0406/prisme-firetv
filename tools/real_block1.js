if(REAL){
 const FONTS=["serif","bebas","black","thin"];
 const col=k=>{const h=hash(k)%360;return ["#"+hsl(h,45,38),"#"+hsl((h+40)%360,45,10)]};
 const NOTE="Pas encore de résumé : la fiche TMDB arrive en arrière-plan.";
 const GOM=new Map();for(const c of (REAL.fcats||[]).concat(REAL.scats||[]))if(!GOM.has(c[0]))GOM.set(c[0],c[1]);const gOf=cats=>{const n=cats.map(k=>GOM.get(k)).filter(Boolean)[0]||"Divers";return n};
 const castOf=r=>(r.cast||"").split(/\s*,\s*/).filter(Boolean).slice(0,6).map(n=>{const id="ra"+(hash(n)>>>0).toString(36);A[id]=n;return [id,""]});
 FILMS.splice(0,FILMS.length,...REAL.films.map(r=>({id:r.id,t:r.t,y:r.y||new Date((r.a||0)*1000).getFullYear()||2024,d:r.d||100,g:(r.g?r.g.split(/\s*[,/]\s*/).filter(Boolean):[gOf(r.c)]).slice(0,3),cat:r.c,bd:r.bd||undefined,imdb:r.r?Math.min(10,+r.r):6.8,tmdb:Math.round((r.r?Math.min(10,+r.r):6.8)*10),age:"Tous publics",dir:r.dir||"",f:FONTS[hash(r.id)%4],c:col(r.id),s:r.p||NOTE,cast:castOf(r),po:r.po||undefined,_real:r})));
 SERIES.splice(0,SERIES.length,...REAL.series.map(r=>{const cast=(r.cast||"").split(/\s*,\s*/).filter(Boolean).slice(0,6).map(n=>{const id="ra"+(hash(n)>>>0).toString(36);A[id]=n;return [id,""]});
  return {id:r.id,t:r.t,y:r.y||2024,net:"",se:[1],g:(r.g?r.g.split(/\s*[,/]\s*/).filter(Boolean):[gOf(r.c)]).slice(0,2),cat:r.c,imdb:r.r?Math.min(10,+r.r):7,tmdb:Math.round((r.r?Math.min(10,+r.r):7)*10),age:"Tous publics",dir:r.dir||"",f:FONTS[hash(r.id)%4],c:col(r.id),s:r.p||NOTE,cast,po:r.po||undefined,bd:r.bd||undefined,ep:r.ep||45,_real:r}}));
}
