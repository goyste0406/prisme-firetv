/* Données réelles du fournisseur (importées par l'utilisateur, stockées dans ce navigateur uniquement : IndexedDB, sinon l'ancienne copie localStorage) */
const REAL=(()=>{try{const w=window.__REAL;if(w&&w.pls&&w.pls.length)return w;const r=JSON.parse(localStorage.getItem("prisme-real")||"null");return r&&r.pls&&r.pls.length?r:null}catch(e){return null}})();
/* une chaîne (ou un film) peut être dans plusieurs catégories du fournisseur, et chez plusieurs fournisseurs */
function inCatL(c,k){return c&&c._real&&c._real.c?c._real.c.includes(k):c.cat===k}
