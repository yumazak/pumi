#!/usr/bin/env bash
# Build, install and launch on the connected iPhone. No Xcode UI.
#
#   ./deploy.sh              # pick the connected device
#   ./deploy.sh <UDID>       # pick one (xcrun devicectl list devices)
set -euo pipefail
cd "$(dirname "$0")"

UDID="${1:-}"
if [ -z "$UDID" ]; then
  UDID=$(xcrun devicectl list devices 2>/dev/null \
    | grep -v simulated \
    | grep -iE 'iphone|ipad' \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' \
    | head -1 || true)
fi
if [ -z "$UDID" ]; then
  echo "実機が見つかりません。USB で繋いで、ロックを外して「信頼」してください。" >&2
  echo "一覧: xcrun devicectl list devices" >&2
  exit 1
fi
echo "device: $UDID"

if xcrun devicectl list devices 2>/dev/null | grep "$UDID" | grep -q unavailable; then
  echo "端末が unavailable です（スリープ・ロック・USB 抜け）。" >&2
  exit 1
fi

xcodebuild -project Pumi.xcodeproj -scheme Pumi \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath build-device \
  -allowProvisioningUpdates build

xcrun devicectl device install app --device "$UDID" \
  build-device/Build/Products/Debug-iphoneos/Pumi.app

xcrun devicectl device process launch --device "$UDID" app.pumi.Pumi
echo "入れて起動しました。"
