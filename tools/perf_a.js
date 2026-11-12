/* ===== Fluidité (1/2) : petites mémoires sur les fonctions appelées des milliers de fois par affichage ===== */
/* l'heure : une lecture de l'horloge par seconde suffit (elle était relue pour chaque programme de chaque chaîne) */
{let t0=0,v=0;nowMin=function(){const t=Date.now();if(t>=t0&&t-t0<1000)return v;t0=t;const d=new Date(t);v=d.getHours()*60+d.getMinutes()+d.getSeconds()/60;return v}}
/* texte sans accents : même résultat pour le même texte, gardé en mémoire (limité) */
{const _n=norm,M=new Map();norm=function(s){let r=M.get(s);if(r===undefined){r=_n(s);if(M.size>60000)M.clear();M.set(s,r)}return r}}
window.__RM={};
