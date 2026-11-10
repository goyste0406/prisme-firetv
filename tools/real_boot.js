/* Données réelles du fournisseur (importées par l'utilisateur, stockées dans ce navigateur uniquement) */
const REAL=(()=>{try{const r=JSON.parse(localStorage.getItem("prisme-real")||"null");return r&&r.pls&&r.pls.length?r:null}catch(e){return null}})();
