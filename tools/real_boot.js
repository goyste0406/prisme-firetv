/* Données réelles du fournisseur (importées par l'utilisateur, stockées dans ce navigateur uniquement).
   Le catalogue est compressé (pako) pour tenir dans la mémoire du navigateur, même avec des dizaines de milliers de titres. */
const RZ={
 enc(str){const b=pako.deflate(str),n=b.length,o=[];let acc=0,bits=0,chunk=[];
  for(let i=0;i<n;i++){acc=(acc<<8)|b[i];bits+=8;while(bits>=15){bits-=15;chunk.push(0x4E00+((acc>>bits)&0x7FFF));if(chunk.length>=8192){o.push(String.fromCharCode.apply(null,chunk));chunk=[]}}acc&=(1<<bits)-1}
  if(bits>0)chunk.push(0x4E00+((acc<<(15-bits))&0x7FFF));o.push(String.fromCharCode.apply(null,chunk));return n+"|"+o.join("")},
 dec(z){const k=z.indexOf("|"),n=+z.slice(0,k),b=new Uint8Array(n);let acc=0,bits=0,j=0;
  for(let i=k+1;i<z.length&&j<n;i++){acc=(acc<<15)|(z.charCodeAt(i)-0x4E00);bits+=15;while(bits>=8&&j<n){bits-=8;b[j++]=(acc>>bits)&255}acc&=(1<<bits)-1}
  return pako.inflate(b,{to:"string"})}};
DG("lecture du catalogue");const REAL=(()=>{try{const z=localStorage.getItem("prisme-realz");const r=z?JSON.parse(RZ.dec(z)):JSON.parse(localStorage.getItem("prisme-real")||"null");return r&&r.pls&&r.pls.length?r:null}catch(e){console.warn("catalogue illisible",e);return null}})();
/* une chaîne (ou un film) peut être dans plusieurs catégories du fournisseur, et chez plusieurs fournisseurs */
function inCatL(c,k){return c&&c._real&&c._real.c?c._real.c.includes(k):c.cat===k}
