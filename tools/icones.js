/* Icônes prisme : remplace les emojis de l'interface par des icônes au trait (style symboles tvOS).
   Choix de Steven (12/11/2026) : trait seul, une couleur qui suit le texte.
   Les emojis restent écrits dans le code ; un observateur les remplace à l'affichage,
   y compris dans les messages, les menus et le texte échappé. Les symboles typographiques
   (✓ → ← ▲ ▼ › ⌄ ● ○ ☰ ⌘) restent en texte. */
(function(){
const PI={
play:'<path d="M8 5.5v13l10.5-6.5z" fill="currentColor"/>',
playpause:'<path d="M3.5 7v10l7-5z" fill="currentColor"/><path d="M15 7v10M19.5 7v10"/>',
pause:'<rect x="6.5" y="5" width="3.6" height="14" rx="1.2" fill="currentColor" stroke="none"/><rect x="13.9" y="5" width="3.6" height="14" rx="1.2" fill="currentColor" stroke="none"/>',
prev:'<path d="M6 6v12"/><path d="M18 6v12l-9-6z" fill="currentColor"/>',
next:'<path d="M18 6v12"/><path d="M6 6v12l9-6z" fill="currentColor"/>',
fwd:'<path d="M3.5 7v10l7.5-5zM12.5 7v10l7.5-5z" fill="currentColor"/>',
rwd:'<path d="M20.5 7v10L13 12zM11.5 7v10L4 12z" fill="currentColor"/>',
stop:'<rect x="6" y="6" width="12" height="12" rx="2.5" fill="currentColor"/>',
live:'<circle cx="12" cy="12" r="4" fill="currentColor"/><circle cx="12" cy="12" r="8.5"/>',
restart:'<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 4v4.5H9"/>',
back:'<path d="M9 6 4 11l5 5"/><path d="M4 11h9.5a5 5 0 0 1 0 10H11"/>',
spk3:'<path d="M3.5 9.5h3.5L11.5 6v12L7 14.5H3.5z"/><path d="M15 9a4 4 0 0 1 0 6M17.8 6.3a8 8 0 0 1 0 11.4"/>',
spk2:'<path d="M3.5 9.5h3.5L11.5 6v12L7 14.5H3.5z"/><path d="M15 9a4 4 0 0 1 0 6"/>',
spk1:'<path d="M3.5 9.5h3.5L11.5 6v12L7 14.5H3.5z"/>',
mute:'<path d="M3.5 9.5h3.5L11.5 6v12L7 14.5H3.5z"/><path d="M15.5 9.5l5 5M20.5 9.5l-5 5"/>',
bell:'<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
belloff:'<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0M4 4l16 16"/>',
alarm:'<circle cx="12" cy="13" r="7"/><path d="M12 9.5V13l2.5 1.5M4.5 5.5 7 3.5M19.5 5.5 17 3.5"/>',
timer:'<circle cx="12" cy="13.5" r="7"/><path d="M12 13.5V10M10 3h4M18 6.5l1.2-1.2"/>',
cal:'<rect x="4" y="5.5" width="16" height="14" rx="2.5"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>',
clock:'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
moon:'<path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z"/>',
sun:'<circle cx="12" cy="12" r="3.6"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4"/>',
tree:'<path d="M12 3 7.5 9.5h3L6 15.5h12l-4.5-6h3z"/><path d="M12 15.5V20.5"/>',
up:'<path d="M7.5 10.5v9h-3v-9z"/><path d="M7.5 10.5 11 4c1.6 0 2.5 1 2.2 2.6l-.4 2.9h5a2 2 0 0 1 2 2.4l-1.3 6a2 2 0 0 1-2 1.6H7.5"/>',
star:'<path d="M12 3.8l2.5 5.2 5.6.7-4.1 3.9 1 5.6-5-2.7-5 2.7 1-5.6-4.1-3.9 5.6-.7z"/>',
starf:'<path d="M12 3.8l2.5 5.2 5.6.7-4.1 3.9 1 5.6-5-2.7-5 2.7 1-5.6-4.1-3.9 5.6-.7z" fill="currentColor"/>',
trophy:'<path d="M7.5 4h9v5a4.5 4.5 0 0 1-9 0z"/><path d="M7.5 6h-3a3 3 0 0 0 3 3.5M16.5 6h3a3 3 0 0 1-3 3.5M12 13.5V17M8.5 20.5h7M9.5 17h5v3.5h-5z"/>',
flame:'<path d="M12 21a6 6 0 0 0 6-6c0-3.5-2.5-5.5-3.5-8.5-1.5 1.5-2 3-2 4.5C11 9.5 10 7 10.5 3.5 7.5 6 6 9.5 6 15a6 6 0 0 0 6 6z"/>',
heart:'<path d="M12 19.5s-7.5-4.6-7.5-10A4.2 4.2 0 0 1 12 7a4.2 4.2 0 0 1 7.5 2.5c0 5.4-7.5 10-7.5 10z"/>',
heartf:'<path d="M12 19.5s-7.5-4.6-7.5-10A4.2 4.2 0 0 1 12 7a4.2 4.2 0 0 1 7.5 2.5c0 5.4-7.5 10-7.5 10z" fill="currentColor"/>',
spark:'<path d="M10 3.5l1.6 4.4 4.4 1.6-4.4 1.6-1.6 4.4-1.6-4.4L4 9.5l4.4-1.6z"/><path d="M17.5 13.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>',
star4:'<path d="M12 3l2 7 7 2-7 2-2 7-2-7-7-2 7-2z"/>',
user:'<circle cx="12" cy="8.5" r="3.8"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>',
users:'<circle cx="9" cy="9" r="3.3"/><path d="M3 19.5a6 6 0 0 1 12 0M15.5 6a3.2 3.2 0 0 1 0 6.3M17.5 14a5.5 5.5 0 0 1 3.5 5.5"/>',
clap:'<rect x="4" y="9.5" width="16" height="10" rx="2"/><path d="M4 9.5 5.4 5l14.4 2.4-.3 2.1M9.2 5.7 8 9.5M14.3 6.5 13 9.5"/>',
pop:'<path d="M6 10h12l-1.6 10H7.6zM10 10l.5 10M14 10l-.5 10"/><path d="M6.5 10a2.5 2.5 0 0 1 2-4.2 2.8 2.8 0 0 1 5.2-.8A2.6 2.6 0 0 1 17.5 10"/>',
rocket:'<path d="M12 3c3 2.5 4.5 6 4 10.5L14.5 16h-5L8 13.5C7.5 9 9 5.5 12 3z"/><circle cx="12" cy="9.5" r="1.6"/><path d="M8.3 12.5 5.5 15.5l2.5.5M15.7 12.5l2.8 3-2.5.5M10.5 18.5 12 21l1.5-2.5"/>',
ball:'<circle cx="12" cy="12" r="8.5"/><path d="M12 8.2l3.2 2.3-1.2 3.8h-4l-1.2-3.8zM12 8.2V3.5M15.2 10.5l4.4-1.4M14 14.3l2.7 3.8M10 14.3l-2.7 3.8M8.8 10.5 4.4 9.1"/>',
pad:'<path d="M7 8h10a4 4 0 0 1 4 4.3l-.4 4A2.5 2.5 0 0 1 16.3 18l-2-2.5H9.7l-2 2.5a2.5 2.5 0 0 1-4.3-1.7l-.4-4A4 4 0 0 1 7 8z"/><path d="M7.5 10.5v3M6 12h3"/><circle cx="15.5" cy="11" r=".7" fill="currentColor"/><circle cx="17.3" cy="12.8" r=".7" fill="currentColor"/>',
cat:'<path d="M5 9.5 5.5 4l4 3h5l4-3 .5 5.5a7 7 0 1 1-14 0z"/><path d="M9.5 12.2v.6M14.5 12.2v.6M11 15.5h2"/>',
laugh:'<circle cx="12" cy="12" r="8.5"/><path d="M8 13.5a4 4 0 0 0 8 0zM8.5 9.5h1M14.5 9.5h1"/>',
scared:'<circle cx="12" cy="12" r="8.5"/><path d="M8.5 9.5h1M14.5 9.5h1"/><ellipse cx="12" cy="15" rx="2" ry="2.5"/>',
tear:'<circle cx="12" cy="12" r="8.5"/><path d="M8.5 14.5a4.5 4.5 0 0 0 7 0M8.5 9.5h1M14.5 9.5h1"/><path d="M16.8 11.3c.9 1.1.9 2 0 2.4-.9-.4-.9-1.3 0-2.4z" fill="currentColor"/>',
bulb:'<path d="M9 17.5h6M10 20.5h4M8.5 14.5a6 6 0 1 1 7 0c-.8.7-1 1.6-1 3h-5c0-1.4-.2-2.3-1-3z"/>',
flag:'<rect x="3.5" y="6" width="17" height="12" rx="2"/><path d="M9.2 6v12M14.8 6v12"/><path d="M3.5 8a2 2 0 0 1 2-2h3.7v12H5.5a2 2 0 0 1-2-2z" fill="currentColor" stroke="none" opacity=".55"/>',
antenna:'<circle cx="12" cy="11" r="1.6"/><path d="M8.5 7.5a5 5 0 0 0 0 7M15.5 7.5a5 5 0 0 1 0 7M5.8 4.8a9 9 0 0 0 0 12.4M18.2 4.8a9 9 0 0 1 0 12.4M12 12.6V21"/>',
target:'<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/>',
compass:'<circle cx="12" cy="12" r="8.5"/><path d="M15.5 8.5l-2.2 4.8-4.8 2.2 2.2-4.8z"/>',
film:'<rect x="5" y="3.5" width="14" height="17" rx="2"/><path d="M8.5 3.5v17M15.5 3.5v17M5 8h3.5M5 12h3.5M5 16h3.5M15.5 8H19M15.5 12H19M15.5 16H19"/>',
bolt:'<path d="M13 3 5.5 13.5H11L10 21l7.5-10.5H12z"/>',
dice:'<rect x="4.5" y="4.5" width="15" height="15" rx="3.5"/><circle cx="9" cy="9" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="15" cy="15" r="1.2" fill="currentColor"/>',
lock:'<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5M12 14.5v2"/>',
never:'<circle cx="12" cy="12" r="8.5"/><path d="M6 6l12 12"/>',
eyeoff:'<path d="M3 12s3.3-6 9-6 9 6 9 6-3.3 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.6"/><path d="M4.5 4.5l15 15"/>',
saga:'<rect x="3.5" y="7" width="10.5" height="13" rx="2"/><path d="M8 7V5.5a2 2 0 0 1 2-2h8.5a2 2 0 0 1 2 2V15a2 2 0 0 1-2 2H14"/>',
cards:'<rect x="9.5" y="3.5" width="10" height="14" rx="2" transform="rotate(12 14.5 10.5)"/><rect x="4.5" y="6" width="10" height="14" rx="2" transform="rotate(-8 9.5 13)"/>',
scale:'<path d="M12 4v16M8 20h8M5 7h14"/><path d="M5 7l-2.5 6a2.5 2.5 0 0 0 5 0zM19 7l-2.5 6a2.5 2.5 0 0 0 5 0z"/>',
duel:'<path d="M4 8h13l-3.5-3.5M20 16H7l3.5 3.5"/>',
chart:'<path d="M4 20h16"/><rect x="5.5" y="12" width="3" height="6" rx="1"/><rect x="10.5" y="7" width="3" height="11" rx="1"/><rect x="15.5" y="10" width="3" height="8" rx="1"/>',
dot:'<circle cx="12" cy="12" r="4.5" fill="currentColor" stroke="none"/>',
tv:'<rect x="3.5" y="5.5" width="17" height="11.5" rx="2.5"/><path d="M8.5 20.5h7M12 17v3.5"/>',
mic:'<rect x="9" y="3.5" width="6" height="11" rx="3"/><path d="M6 11.5a6 6 0 0 0 12 0M12 17.5v3"/>',
gear:'<circle cx="12" cy="12" r="2.8"/><circle cx="12" cy="12" r="6.2"/><path d="M12 3.2v2.6M12 18.2v2.6M3.2 12h2.6M18.2 12h2.6M5.8 5.8l1.8 1.8M16.4 16.4l1.8 1.8M5.8 18.2l1.8-1.8M16.4 7.6l1.8-1.8"/>',
pen:'<path d="M5 19l1-4L16 5l3 3L9 18z"/><path d="M14 7l3 3"/>',
del:'<path d="M9 5.5h10.5A1.5 1.5 0 0 1 21 7v10a1.5 1.5 0 0 1-1.5 1.5H9L3 12z"/><path d="M12 9.5l5 5M17 9.5l-5 5"/>',
close:'<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
signal:'<path d="M5 19v-3M9.5 19v-6M14 19v-9M18.5 19V6"/>',
warn:'<path d="M12 4 2.8 19.5h18.4z"/><path d="M12 10v4.5M12 17v.2"/>',
layers:'<path d="M12 4 3 8.5l9 4.5 9-4.5z"/><path d="M3 12.5l9 4.5 9-4.5M3 16.5l9 4.5 9-4.5"/>',
prism:'<path d="M12 3.5 20.5 19h-17z"/><path d="M12 3.5 9.5 19"/>',
note:'<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
home:'<path d="M4 11 12 4.5 20 11"/><path d="M6 9.5V19.5h4.5v-5h3v5H18V9.5"/>',
search:'<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5"/>',
photo:'<rect x="3.5" y="5" width="17" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.6"/><path d="M4 17l5-4.5 3.5 3 3-2.5 4.5 4"/>'
};
PI.down='<g transform="rotate(180 12 12)">'+PI.up+'</g>';
const MAP={"🇫🇷":"flag","▶":"play","⏯":"playpause","⏸":"pause","⏮":"prev","⏭":"next","⏩":"fwd","⏪":"rwd","⏹":"stop","⏺":"live","↺":"restart","↩":"back",
"🔊":"spk3","🔉":"spk2","🔈":"spk1","🔇":"mute","🔔":"bell","🔕":"belloff","⏰":"alarm","⏱":"timer","📅":"cal","🕰":"clock","🌙":"moon","☾":"moon","☀":"sun","🎄":"tree",
"👍":"up","👎":"down","★":"starf","⭐":"star","☆":"star","🏠":"home","🔎":"search","🔍":"search","🏆":"trophy","🔥":"flame","♥":"heartf","♡":"heart","💛":"heart","✨":"spark","✦":"star4",
"👤":"user","👥":"users","🎬":"clap","🍿":"pop","🚀":"rocket","⚽":"ball","🎮":"pad","🐱":"cat","😄":"laugh","😂":"laugh","😱":"scared","🥲":"tear","🧠":"bulb",
"📡":"antenna","🎯":"target","🧭":"compass","🎞":"film","⚡":"bolt","🎲":"dice","🔒":"lock","🚫":"never","🙈":"eyeoff","🧩":"saga","🃏":"cards","⚖":"scale","⚔":"duel",
"📊":"chart","🔵":"dot","📺":"tv","🎤":"mic","⚙":"gear","✎":"pen","⌫":"del","✕":"close","📶":"signal","⚠":"warn","◎":"layers","◆":"prism","♪":"note","▣":"photo"};
const RE=new RegExp("("+Object.keys(MAP).sort((a,b)=>b.length-a.length).join("|")+")[\\uFE0E\\uFE0F]?","gu");
const NS="http://www.w3.org/2000/svg";
function icon(k){const s=document.createElementNS(NS,"svg");s.setAttribute("viewBox","0 0 24 24");s.setAttribute("fill","none");s.setAttribute("stroke","currentColor");s.setAttribute("stroke-width","1.8");s.setAttribute("stroke-linecap","round");s.setAttribute("stroke-linejoin","round");s.setAttribute("aria-hidden","true");s.setAttribute("class","pi pi-"+k);s.innerHTML=PI[k];return s}
const SKIP=/^(SCRIPT|STYLE|TEXTAREA|INPUT|OPTION|TITLE|svg)$/i;
function fix(t){const d=t.data;if(!d||d.indexOf("◀")>=0)return;RE.lastIndex=0;if(!RE.test(d))return;const p=t.parentNode;if(!p||SKIP.test(p.nodeName)||(p.closest&&p.closest("[data-noico],svg")))return;
 RE.lastIndex=0;const fr=document.createDocumentFragment();let i=0,m;while((m=RE.exec(d))){if(m.index>i)fr.appendChild(document.createTextNode(d.slice(i,m.index)));fr.appendChild(icon(MAP[m[1]]));i=m.index+m[0].length}
 if(i<d.length)fr.appendChild(document.createTextNode(d.slice(i)));p.replaceChild(fr,t)}
function walk(n){if(n.nodeType===3)return fix(n);if(n.nodeType!==1||SKIP.test(n.nodeName))return;const w=document.createTreeWalker(n,NodeFilter.SHOW_TEXT);const L=[];while(w.nextNode())L.push(w.currentNode);L.forEach(fix)}
window.prIcon=k=>PI[k]?icon(k).outerHTML:"";
const go=()=>{walk(document.body);new MutationObserver(ms=>{for(const m of ms){if(m.type==="characterData")fix(m.target);else m.addedNodes.forEach(walk)}}).observe(document.body,{childList:true,subtree:true,characterData:true})};
if(document.body)go();else document.addEventListener("DOMContentLoaded",go);
})();
