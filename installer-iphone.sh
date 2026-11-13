#!/bin/zsh
# Recompile, signe et réinstalle NutriRatio sur l'iPhone (à relancer tous les 7 jours
# avec un compte Apple gratuit). L'iPhone doit être branché ou sur le même Wi-Fi, déverrouillé.
set -euo pipefail
cd "${0:A:h}"
# Identifiant de l'iPhone : variable NUTRIRATIO_DEVICE, sinon fichier .iphone-udid (non versionné).
# Pour le trouver : xcrun devicectl list devices
DEVICE="${NUTRIRATIO_DEVICE:-$(cat .iphone-udid 2>/dev/null || true)}"
if [[ -z "$DEVICE" ]]; then
  echo "Indiquez l'identifiant de l'iPhone dans .iphone-udid (voir : xcrun devicectl list devices)." >&2
  exit 1
fi
BUILD_DIR="${TMPDIR:-/tmp}/NutriRatioDevice"
xcodegen generate
xcodebuild -project NutriRatio.xcodeproj -scheme NutriRatio -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath "$BUILD_DIR" -allowProvisioningUpdates build \
  | grep -E "error|BUILD" || true
xcrun devicectl device install app --device "$DEVICE" \
  "$BUILD_DIR/Build/Products/Debug-iphoneos/NutriRatio.app"
echo "NutriRatio installé."
