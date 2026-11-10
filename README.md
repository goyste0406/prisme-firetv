# prisme – Apple TV (tvOS)

Branche séparée de l'appli Fire TV. Chaque push sur `appletv` compile l'appli sur un Mac GitHub
(onglet **Actions**) et publie le fichier **prisme-AppleTV.ipa** dans la release **appletv-latest**.

Pas besoin de Xcode : l'installation sur l'Apple TV se fait avec **Sideloadly** et un Apple ID gratuit
(valable 7 jours, il suffit de relancer l'installation pour prolonger).

Lecteur vidéo : VLC (TVVLCKit, via CocoaPods), qui lit directement les flux `.ts` de l'Xtream.
