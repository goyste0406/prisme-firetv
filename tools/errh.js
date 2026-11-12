/* ---------- garde-fou : une erreur au démarrage s'affiche à l'écran au lieu d'un écran noir ---------- */
(function(){let shown=false;
 function box(title,detail){if(shown)return;shown=true;const d=document.createElement("div");d.id="prerr";
  d.style.cssText="position:fixed;left:50%;top:50%;transform:translate(-50%,-50%);z-index:99999;width:min(720px,92vw);background:#16181f;color:#fff;border:1px solid rgba(255,255,255,.18);border-radius:18px;padding:22px 24px;font:15px/1.5 -apple-system,system-ui,sans-serif;box-shadow:0 30px 80px rgba(0,0,0,.6)";
  d.innerHTML='<b style="font-size:19px">'+title+'</b><p style="opacity:.8;margin:8px 0">Fais une capture de ce message et envoie-la : il dit exactement ce qui bloque.</p><pre style="white-space:pre-wrap;background:#0b0c10;border-radius:10px;padding:10px 12px;font:12.5px/1.4 ui-monospace,Menlo,monospace;max-height:220px;overflow:auto;margin:0 0 14px"></pre>'
   +'<button id="prerr-r" style="font:inherit;font-weight:600;padding:9px 14px;border-radius:10px;border:0;background:#fff;color:#111;cursor:pointer;margin-right:8px">Recharger</button>'
   +'<button id="prerr-d" style="font:inherit;font-weight:600;padding:9px 14px;border-radius:10px;border:1px solid rgba(255,255,255,.25);background:transparent;color:#fff;cursor:pointer">Revenir aux données de démonstration</button>';
  d.querySelector("pre").textContent=detail;(document.body||document.documentElement).appendChild(d);
  d.querySelector("#prerr-r").onclick=()=>location.reload();
  d.querySelector("#prerr-d").onclick=()=>{try{["prisme-realz","prisme-real","prisme-atv","prisme-atv-live"].forEach(k=>localStorage.removeItem(k))}catch(e){}location.reload()}}
 window.__prBox=box;
 window.addEventListener("error",e=>{if(!window.__prReady)box("Le simulateur a rencontré une erreur au démarrage",(e.message||"")+"\n"+(e.filename?"ligne "+e.lineno+":"+e.colno:"")+"\n"+((e.error&&e.error.stack)||"").split("\n").slice(0,4).join("\n"))});
 setTimeout(()=>{if(!window.__prReady)box("Le simulateur ne démarre pas","Rien ne s'est affiché après 25 secondes.\nNavigateur : "+navigator.userAgent+"\nStockage utilisé : "+(()=>{try{let t=0;for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);t+=(localStorage.getItem(k)||"").length}return Math.round(t/1000)+" k caractères"}catch(e){return "?"}})())},25000);
})();
