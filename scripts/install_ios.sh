#!/usr/bin/env bash
# Builds the iOS app once and installs it on every connected iPad and iPhone.
#
# A device counts as connected when it is a physical, paired, booted iOS device
# that devicectl can reach, over the cable or the local network. Simulators are
# left alone. --device narrows the set to the devices named, by name or UDID.
#
# The build is scripts/build_app.sh ios, so the app carries its commit and the
# OAuth values for progress sync. A device the build's provisioning profile does
# not name cannot take the app, and building for a generic destination never
# adds one, so such a device is registered first by a build that targets it,
# and the app is then built again (see docs/ios.md).
#
# Installing a release build over the one on the device keeps the app's data.
# --backup copies the reader's own data off each device first, into
# ~/Backups/NovelViewer-<device>-<time>/: the novels, the settings and the
# databases outside the novel folders. The speech models are left out; they are
# gigabytes and the app downloads them again. A device whose backup fails is not
# installed on.
#
# Usage: scripts/install_ios.sh [--backup] [--no-build] [--device <name|udid>]...
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${NOVEL_VIEWER_IOS_APP:-$PROJECT_ROOT/build/ios/iphoneos/Runner.app}"
BACKUP_ROOT="${NOVEL_VIEWER_BACKUP_ROOT:-$HOME/Backups}"
BUNDLE_ID=com.endo5501.novelViewer

# What --backup copies, relative to the app's data container.
BACKUP_SOURCES=(
  "Documents/NovelViewer"
  "Library/Application Support"
  "Library/Preferences"
)

usage() {
  echo "usage: $0 [--backup] [--no-build] [--device <name|udid>]..." >&2
  exit 64
}

backup=false
build=true
wanted=()
while [ $# -gt 0 ]; do
  case "$1" in
    --backup) backup=true ;;
    --no-build) build=false ;;
    --device)
      [ $# -ge 2 ] || usage
      wanted+=("$2")
      shift
      ;;
    *) usage ;;
  esac
  shift
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- the devices --------------------------------------------------------------

xcrun devicectl list devices --json-output "$WORK/devices.json" >/dev/null

# One "<udid>\t<name>" line per connected device.
python3 -I - "$WORK/devices.json" >"$WORK/connected" <<'PY'
import json, sys

with open(sys.argv[1]) as f:
    devices = json.load(f)["result"]["devices"]
for d in devices:
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    props = d.get("deviceProperties", {})
    if (
        hw.get("reality") == "physical"
        and hw.get("platform") == "iOS"
        and conn.get("pairingState") == "paired"
        and conn.get("transportType")
        and props.get("bootState") == "booted"
    ):
        print(f"{hw['udid']}\t{props.get('name', hw['udid'])}")
PY

targets=()
names=()
if [ ${#wanted[@]} -eq 0 ]; then
  while IFS=$'\t' read -r udid name; do
    targets+=("$udid")
    names+=("$name")
  done <"$WORK/connected"
else
  for want in "${wanted[@]}"; do
    found=false
    while IFS=$'\t' read -r udid name; do
      if [ "$want" = "$udid" ] || [ "$want" = "$name" ]; then
        targets+=("$udid")
        names+=("$name")
        found=true
      fi
    done <"$WORK/connected"
    if ! $found; then
      echo "error: no connected iOS device is named $want" >&2
      exit 1
    fi
  done
fi

if [ ${#targets[@]} -eq 0 ]; then
  echo "error: no iPad or iPhone is connected" >&2
  exit 1
fi

echo "Devices:"
for i in "${!targets[@]}"; do
  echo "  ${names[$i]} (${targets[$i]})"
done

# --- the build ----------------------------------------------------------------

build_app() {
  echo "Building..."
  "$PROJECT_ROOT/scripts/build_app.sh" ios
}

# Prints the UDIDs the built app's provisioning profile names, one per line.
provisioned_devices() {
  security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null |
    python3 -I -c '
import plistlib, sys
for udid in plistlib.loads(sys.stdin.buffer.read()).get("ProvisionedDevices", []):
    print(udid)
'
}

# Registers <udid> with the team by building for it, as Xcode does for a
# device it is asked to build for.
register() {
  echo "Registering $2 ($1) in the provisioning profile..."
  xcodebuild -workspace "$PROJECT_ROOT/ios/Runner.xcworkspace" -scheme Runner \
    -configuration Release -destination "id=$1" \
    -derivedDataPath "$WORK/register" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    build >"$WORK/register.log" 2>&1 || {
    tail -20 "$WORK/register.log" >&2
    echo "error: could not register $2" >&2
    exit 1
  }
}

if $build; then
  build_app
  provisioned_devices >"$WORK/provisioned"
  registered=false
  for i in "${!targets[@]}"; do
    if ! grep -qx "${targets[$i]}" "$WORK/provisioned"; then
      register "${targets[$i]}" "${names[$i]}"
      registered=true
    fi
  done
  if $registered; then build_app; fi
fi

# --- backup and install -------------------------------------------------------

has_app() {
  xcrun devicectl device info apps --device "$1" --bundle-id "$BUNDLE_ID" \
    --json-output "$WORK/apps.json" >/dev/null 2>&1 || return 1
  python3 -I -c '
import json, sys
apps = json.load(open(sys.argv[1]))["result"]["apps"]
sys.exit(0 if apps else 1)
' "$WORK/apps.json"
}

back_up() {
  local udid="$1" name="$2"
  if ! has_app "$udid"; then
    echo "  no app on $name yet; nothing to back up"
    return 0
  fi
  local dest
  dest="$BACKUP_ROOT/NovelViewer-$name-$(date +%Y%m%d-%H%M%S)"
  echo "  backing up to $dest"
  for source in "${BACKUP_SOURCES[@]}"; do
    mkdir -p "$dest/$(dirname "$source")"
    xcrun devicectl device copy from --device "$udid" \
      --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
      --source "$source" --destination "$dest/$source" >/dev/null || return 1
  done
}

failed=()
for i in "${!targets[@]}"; do
  udid="${targets[$i]}"
  name="${names[$i]}"
  echo "$name:"
  if $backup && ! back_up "$udid" "$name"; then
    echo "  backup failed; not installing on $name" >&2
    failed+=("$name")
    continue
  fi
  echo "  installing..."
  if xcrun devicectl device install app --device "$udid" "$APP" >/dev/null; then
    echo "  installed"
  else
    echo "  install failed on $name" >&2
    failed+=("$name")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "error: failed on ${failed[*]}" >&2
  exit 1
fi
echo "Done."
