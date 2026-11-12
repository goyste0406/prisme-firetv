/* Listes longues : la sélection reste toujours visible (pas de retard quand on appuie vite, rendu correct dans Safari) */
function tyTrack(p){return p.querySelector(":scope>.ttrack")}
function tySet(p,t,instant){const tr=tyTrack(p);if(!tr)return;const H=p.clientHeight,max=Math.max(0,tr.offsetHeight-H);t=Math.max(0,Math.min(t,max));p._ty=t;const v=`translate3d(0,${-t}px,0)`;
 if(instant){tr.style.transition="none";tr.style.transform=v;void tr.offsetHeight;tr.style.transition=""}else tr.style.transform=v;
 p.classList.toggle("tup",t>2);p.classList.toggle("tdn",t<max-2)}
function tyFollow(p,el,instant){const tr=tyTrack(p);if(!tr||!tr.contains(el))return;let tg=el;while(tg.parentElement&&tg.parentElement!==tr)tg=tg.parentElement;
 const tp=within(tg,tr,"offsetTop");if(tp==null)return;const H=p.clientHeight,h=Math.min(tg.offsetHeight,H-24);let t=p._ty||0;
 if(tp-12<t)t=tp-12;else if(tp+h+18>t+H)t=tp+h+18-H;tySet(p,t,instant)}
document.addEventListener("wheel",e=>{const p=e.target&&e.target.closest&&e.target.closest(".ty");if(!p||!tyTrack(p))return;e.preventDefault();tySet(p,(p._ty||0)+e.deltaY,false)},{passive:false});
