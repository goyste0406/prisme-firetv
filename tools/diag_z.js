/* diagnostic : chaque affichage et chaque touche notent l'étape en cours (voir diag.js) */
{const _r=render;render=function(f){DG("affichage : "+(S.modal?"fenêtre "+S.modal.type:((topS()||{}).t||"")+" · onglet "+S.tab));const o=_r(f);DGend();return o}}
{const _k=key;key=function(k){DG("touche « "+k+" » ("+(S.modal?"fenêtre "+S.modal.type:((topS()||{}).t||"")+" · onglet "+S.tab)+")");const o=_k(k);DGend();return o}}
