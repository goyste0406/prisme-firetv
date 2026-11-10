if(REAL){
 FCATS.splice(0,FCATS.length,...REAL.fcats);SCATS.splice(0,SCATS.length,...REAL.scats);
 const tplOf=n=>/sport|foot|bein|rmc sport|eurosport|equipe|canal\+ sport/i.test(n)?"sport":/info|news|bfm|cnews|lci|franceinfo|euronews|france 24/i.test(n)?"info":/cin|film|movie|tcm|paramount|frisson/i.test(n)?"cine":/kid|jeunesse|gulli|disney|nick|boomerang|tiji|piwi|canal j|cartoon|okoo/i.test(n)?"kids":/docu|discovery|nat ?geo|planete|histoire|ushuaia|rmc decouverte|animaux|science/i.test(n)?"doc":"series";
 CHS.splice(0,CHS.length,...REAL.chans.map((r,i)=>{const h=hash(r.id)%360;const qs=r.s.map(x=>x[2]);const q=qs.includes("4K")?"4K":qs.includes("1080p")?"FHD":qs.includes("720p")?"HD":"SD";
  return {id:r.id,n:r.n,cat:r.c[0]||"lother",col:"#"+hsl(h,55,34),tpl:tplOf(r.n+" "+((REAL.lcats.find(c=>c[0]===r.c[0])||[])[1]||"")),q,num:r.num||i+1,_real:r}}));
}
