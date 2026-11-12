/* ---------- diagnostic de démarrage : chaque grande étape est notée ; si prisme se fige, le prochain lancement dit où, et propose le mode sûr ---------- */
(function(){let prev=null;try{prev=JSON.parse(localStorage.getItem("prisme-diag")||"null")}catch(e){}
 const t0=Date.now();window.SAFE=(()=>{try{return localStorage.getItem("prisme-safe")==="1"}catch(e){return false}})();
 /* le dernier lancement s'est figé : ce lancement-ci démarre en mode sûr, pour que tu puisses toujours utiliser prisme */
 const froze=!!(prev&&prev.open&&Date.now()-prev.at<30*60000);if(froze)window.SAFE=true;
 let last="";window.DG=function(s){last=s;try{localStorage.setItem("prisme-diag",JSON.stringify({s,open:1,ms:Date.now()-t0,at:Date.now()}))}catch(e){}};
 window.DGend=function(){try{localStorage.setItem("prisme-diag",JSON.stringify({s:last,open:0,ms:Date.now()-t0,at:Date.now()}))}catch(e){}};
 DG("début du chargement");
 /* au bout de 12 s sans blocage : démarrage réussi */
 if(prev&&prev.open&&Date.now()-prev.at<30*60000){
  const show=()=>{const d=document.createElement("div");d.id="prdiag";
   d.style.cssText="position:fixed;left:50%;top:24px;transform:translateX(-50%);z-index:99998;width:min(760px,94vw);background:#16181f;color:#fff;border:1px solid rgba(255,255,255,.2);border-radius:16px;padding:16px 20px;font:14px/1.5 -apple-system,system-ui,sans-serif;box-shadow:0 20px 60px rgba(0,0,0,.6)";
   d.innerHTML='<b style="font-size:16px">Le dernier lancement de prisme s\'est figé</b><div style="opacity:.85;margin:6px 0 10px">Étape en cours au moment du blocage : <b id="prdiag-s"></b> (après <span id="prdiag-t"></span>). Fais une capture de ce message et envoie-la.</div>'
    +(froze?'<div style="opacity:.85;margin:-4px 0 10px">Ce lancement-ci a démarré en <b>mode sûr</b>.</div>':'')+'<button id="prdiag-safe" style="font:inherit;font-weight:600;padding:8px 13px;border-radius:10px;border:0;background:#fff;color:#111;cursor:pointer;margin-right:8px">'+"Garder le mode sûr"+'</button>'
    +'<button id="prdiag-x" style="font:inherit;font-weight:600;padding:8px 13px;border-radius:10px;border:1px solid rgba(255,255,255,.25);background:transparent;color:#fff;cursor:pointer">Fermer</button>'
    +'<div style="opacity:.6;font-size:12.5px;margin-top:8px">Mode sûr : prisme démarre sans préparer les listes en arrière-plan ni télécharger les fiches.</div>';
   d.querySelector("#prdiag-s").textContent=prev.s;d.querySelector("#prdiag-t").textContent=(prev.ms/1000).toFixed(1)+" s";document.body.appendChild(d);
   d.querySelector("#prdiag-x").onclick=()=>d.remove();
   d.querySelector("#prdiag-safe").onclick=()=>{try{localStorage.setItem("prisme-safe","1")}catch(e){}d.remove()}};
  if(document.body)show();else document.addEventListener("DOMContentLoaded",show)}
 if(window.SAFE&&!(prev&&prev.open)){const b=()=>{const d=document.createElement("div");d.style.cssText="position:fixed;right:14px;top:10px;z-index:99997;background:#b45309;color:#fff;border-radius:999px;padding:5px 12px;font:600 12.5px -apple-system,system-ui,sans-serif;cursor:pointer";d.textContent="Mode sûr · cliquer pour le quitter";d.onclick=()=>{try{localStorage.setItem("prisme-safe","0")}catch(e){}location.reload()};document.body.appendChild(d)};if(document.body)b();else document.addEventListener("DOMContentLoaded",b)}
})();
