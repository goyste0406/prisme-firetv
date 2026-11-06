# prisme

Application IPTV pour Fire TV (Fire OS 7 et plus), inspirée de l'interface tvOS.

- Connexion **Xtream Codes** (URL, utilisateur, mot de passe), plusieurs playlists fusionnées dans un seul catalogue
- **Films**, **Séries**, **TV en direct** avec guide TV (EPG court Xtream)
- Fiches détaillées, casting, sources multiples (qualité, langue), choix automatique d'une source compatible avec l'appareil
- Lecteur natif **ExoPlayer (Media3)** : pistes audio et sous-titres, format d'image, défilement rapide, guide et liste des chaînes
- **Mises à jour en un clic** depuis Réglages › À propos

## Installer sur le Fire TV

1. Options pour les développeurs activées, **Downloader** autorisé à installer des applis inconnues.
2. Dans Downloader, saisir l'adresse :
   `https://github.com/goyste0406/prisme-firetv/releases/latest/download/prisme.apk`
   (ou le code court Downloader indiqué dans la dernière release).

## Publier une nouvelle version

1. Augmenter `versionCode` et `versionName` dans `app/build.gradle.kts`.
2. Pousser sur `main` : GitHub Actions compile, signe et publie la release (`prisme.apk` + `version.json`).
3. Sur le Fire TV : Réglages › À propos › Rechercher une mise à jour.

La signature utilise `keystore/prisme-release.jks` (chiffré) et le secret GitHub `KEYSTORE_PASSWORD`.
Toujours garder la même clé : sinon une mise à jour ne peut pas remplacer l'application installée.

## Structure

- `app/src/main/java/fr/prisme/tv/` : activité Android, pont JavaScript, proxy HTTP, lecteur ExoPlayer, mises à jour
- `app/src/main/assets/web/index.html` : interface (générée depuis le simulateur par `tools/build_ui.py`)
- `tools/` : simulateur, couche de données Xtream (`data.js`), faux serveur Xtream pour les tests
