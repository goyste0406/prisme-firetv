#!/bin/bash
# Visite « envoi » : 2e Apple TV (simulateur) en réception. Attend que l'appli soit compilée par la visite,
# l'installe, l'ouvre en réception (« -prisme.debug.receive 1 »), photographie l'écran toutes les 10 s,
# laisse la confirmation affichée 25 s puis l'accepte, et relance l'appli pour écrire ses données (donnees-B.txt).
UDID2="$1"; OUT="$2"
APP=""
for i in $(seq 1 180); do
  APP=$(ls -d build-sim/Build/Products/Debug-appletvsimulator/IPTVPerso.app 2>/dev/null | head -1)
  # appli complète seulement quand son exécutable est là et que le programme de test est compilé aussi
  [ -n "$APP" ] && [ -f "$APP/IPTVPerso" ] && ls -d build-sim/Build/Products/Debug-appletvsimulator/*UITests-Runner.app >/dev/null 2>&1 && break
  sleep 10
done
[ -z "$APP" ] && { echo "pas d'appli compilée"; exit 0; }
sleep 30
for t in 1 2 3 4 5; do
  xcrun simctl install "$UDID2" "$APP" && break
  echo "installation refusée (essai $t), nouvel essai dans 20 s"; sleep 20
done
ARGS="-prisme.debug.demoServer http://127.0.0.1:8099 -prisme.debug.tmdbKey test -prisme.debug.tmdbBase http://127.0.0.1:8099/tmdb/3 -prisme.debug.imgBase http://127.0.0.1:8099/img -prisme.debug.tab settings -prisme.debug.settings data -prisme.debug.receive 1 -prisme.debug.acceptAfter 25"
xcrun simctl launch "$UDID2" com.steven.iptvperso $ARGS
for k in $(seq -w 1 60); do sleep 10; xcrun simctl io "$UDID2" screenshot "$OUT/B-$k.png" >/dev/null 2>&1; done
xcrun simctl terminate "$UDID2" com.steven.iptvperso
xcrun simctl launch "$UDID2" com.steven.iptvperso -prisme.debug.demoServer http://127.0.0.1:8099 -prisme.debug.tab settings -prisme.debug.settings prof
sleep 15; xcrun simctl io "$UDID2" screenshot "$OUT/B-99-apres-relance.png" >/dev/null 2>&1
C=$(xcrun simctl get_app_container "$UDID2" com.steven.iptvperso data 2>/dev/null)
[ -n "$C" ] && cp "$C/Documents/donnees.txt" "$OUT/donnees-B.txt" 2>/dev/null
echo fini
