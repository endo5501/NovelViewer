#!/usr/bin/env bash
# Verifies scripts/install_ios.sh builds the iOS app once and installs it on
# every connected iPad and iPhone.
#
# Runs the real script with stub `xcrun`, `security`, `xcodebuild` and `fvm`
# commands first on PATH, so nothing is built and no device is touched. The
# stubs append each call to a log the assertions read, and answer from files
# the test writes: the device list devicectl reports, the devices the build's
# provisioning profile names, and the apps already on each device.
#
# Usage: scripts/test/install_ios_test.sh [path-to-install_ios.sh]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_IOS="${1:-$PROJECT_ROOT/install_ios.sh}"

pass=0
fail=0

ok() {
  pass=$((pass + 1))
  printf 'ok   - %s\n' "$1"
}

ng() {
  fail=$((fail + 1))
  printf 'FAIL - %s\n' "$1"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

IPAD=00008130-000A0DD42181001C
IPHONE=00008140-00183838262B001C
SIM=15698705-AFD5-4B0B-8445-DBA62900A1BD
OFFLINE=00008120-0000000000000001

mkdir -p "$WORK/bin"

# xcrun devicectl: answers the device list from $DEVICES_JSON, the apps on a
# device from $INSTALLED_ON, whether its Documents holds voices from $VOICES_ON, and fails an install or copy on a device named in
# $FAIL_INSTALL_ON or $FAIL_COPY_ON. A device named in $LOCKED_ON answers the
# apps query as a locked one does: an error in place of the result, with the
# exit status in $LOCKED_STATUS.
cat >"$WORK/bin/xcrun" <<'SH'
#!/usr/bin/env bash
echo "xcrun $*" >>"$CALLS"
[ "$1" = devicectl ] || exit 0
shift
device=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [ "${args[$i]}" = --device ]; then device="${args[$((i + 1))]}"; fi
  if [ "${args[$i]}" = --json-output ]; then json_out="${args[$((i + 1))]}"; fi
done
case "$1 $2" in
  "list devices")
    cp "$DEVICES_JSON" "$json_out"
    ;;
  "device install")
    case " ${FAIL_INSTALL_ON:-} " in *" $device "*) exit 1 ;; esac
    ;;
  "device copy")
    case " ${FAIL_COPY_ON:-} " in *" $device "*) exit 1 ;; esac
    ;;
  "device info")
    if [ "$3" = files ]; then
      files='[{"relativePath": "NovelViewer"}, {"relativePath": "models"}]'
      if grep -qx "$device" "$VOICES_ON" 2>/dev/null; then
        files='[{"relativePath": "NovelViewer"}, {"relativePath": "voices"}, {"relativePath": "voices/narrator.wav"}]'
      fi
      printf '{"result": {"files": %s}}' "$files" >"$json_out"
      exit 0
    fi
    case " ${LOCKED_ON:-} " in
      *" $device "*)
        printf '{"error": {"userInfo": {"NSLocalizedDescription": "The device is locked."}}, "info": {"outcome": "failed"}}' >"$json_out"
        exit "${LOCKED_STATUS:-1}"
        ;;
    esac
    if grep -qx "$device" "$INSTALLED_ON" 2>/dev/null; then
      apps='[{"bundleIdentifier": "com.endo5501.novelViewer"}]'
    else
      apps='[]'
    fi
    printf '{"result": {"apps": %s}}' "$apps" >"$json_out"
    ;;
esac
SH

# security cms: prints a profile naming the devices listed in $PROFILE_DEVICES.
cat >"$WORK/bin/security" <<'SH'
#!/usr/bin/env bash
echo "security $*" >>"$CALLS"
printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
printf '<key>ProvisionedDevices</key><array>'
while read -r udid; do
  [ -n "$udid" ] && printf '<string>%s</string>' "$udid"
done <"$PROFILE_DEVICES"
printf '</array></dict></plist>\n'
SH

# xcodebuild: a build for one device registers it, as Xcode does.
cat >"$WORK/bin/xcodebuild" <<'SH'
#!/usr/bin/env bash
echo "xcodebuild $*" >>"$CALLS"
for arg in "$@"; do
  case "$arg" in id=*) echo "${arg#id=}" >>"$PROFILE_DEVICES" ;; esac
done
SH

cat >"$WORK/bin/fvm" <<'SH'
#!/usr/bin/env bash
echo "fvm $*" >>"$CALLS"
SH
chmod +x "$WORK/bin/"*

# device <udid> <name> <reality> <paired> <booted> <transport>: one entry in
# the shape `devicectl list devices --json-output` writes. An empty <reality>
# leaves the key out, as the devicectl of Xcode 27.1 does for a physical device.
device() {
  local transport="" reality=""
  [ -n "$6" ] && transport="\"transportType\": \"$6\","
  [ -n "$3" ] && reality="\"reality\": \"$3\","
  cat <<JSON
{"identifier": "x-$1",
 "connectionProperties": {$transport "pairingState": "$4"},
 "deviceProperties": {"name": "$2", "bootState": "$5"},
 "hardwareProperties": {"udid": "$1", $reality "platform": "iOS"}}
JSON
}

# devices <entry...>: writes the device list.
devices() {
  local IFS=,
  printf '{"result": {"devices": [%s]}}' "$*" >"$WORK/devices.json"
}

# reset: a fresh log, both phones in the profile, the app on both, and the
# usual set of devices (an iPad on the network, an iPhone on the cable, a
# simulator, and a device that is paired but out of reach).
reset() {
  : >"$WORK/calls"
  printf '%s\n%s\n' "$IPAD" "$IPHONE" >"$WORK/profile"
  printf '%s\n%s\n' "$IPAD" "$IPHONE" >"$WORK/installed"
  printf '%s\n' "$IPHONE" >"$WORK/voices"
  rm -rf "$WORK/backups"
  devices \
    "$(device "$IPAD" iPadmini7 physical paired booted localNetwork)" \
    "$(device "$IPHONE" satorue_16 physical paired booted wired)" \
    "$(device "$SIM" "iPhone 17" simulated paired booted "")" \
    "$(device "$OFFLINE" oldphone physical paired booted "")"
  unset FAIL_INSTALL_ON FAIL_COPY_ON LOCKED_ON LOCKED_STATUS
}

# run <args...>: runs install_ios.sh with the stubs, leaving its output in
# $WORK/out and its status in $status.
run() {
  PATH="$WORK/bin:$PATH" \
    CALLS="$WORK/calls" \
    DEVICES_JSON="$WORK/devices.json" \
    PROFILE_DEVICES="$WORK/profile" \
    INSTALLED_ON="$WORK/installed" \
    VOICES_ON="$WORK/voices" \
    FAIL_INSTALL_ON="${FAIL_INSTALL_ON:-}" \
    FAIL_COPY_ON="${FAIL_COPY_ON:-}" \
    LOCKED_ON="${LOCKED_ON:-}" \
    LOCKED_STATUS="${LOCKED_STATUS:-}" \
    NOVEL_VIEWER_IOS_APP="$WORK/Runner.app" \
    NOVEL_VIEWER_BACKUP_ROOT="$WORK/backups" \
    bash "$INSTALL_IOS" "$@" >"$WORK/out" 2>&1
  status=$?
}

calls_matching() { grep -c -- "$1" "$WORK/calls"; }
installed_on() { grep -q -- "device install app --device $1 " "$WORK/calls"; }

mkdir -p "$WORK/Runner.app"

# --- every connected device ---------------------------------------------------
reset
run
if [ "$status" -eq 0 ]; then ok "succeeds"; else ng "succeeds (status $status)"; cat "$WORK/out"; fi
if installed_on "$IPAD" && installed_on "$IPHONE"; then
  ok "installs on the iPad and the iPhone"
else
  ng "installs on the iPad and the iPhone"
fi
if ! installed_on "$SIM"; then ok "leaves the simulator alone"; else ng "leaves the simulator alone"; fi
if ! installed_on "$OFFLINE"; then
  ok "leaves a device it cannot reach alone"
else
  ng "leaves a device it cannot reach alone"
fi
if grep -q -- "device install app --device $IPAD $WORK/Runner.app" "$WORK/calls"; then
  ok "installs the built app"
else
  ng "installs the built app"
fi

# --- the build ----------------------------------------------------------------
if [ "$(calls_matching '^fvm flutter build ios')" -eq 1 ]; then
  ok "builds once, through build_app.sh"
else
  ng "builds once, through build_app.sh"
fi
first_build=$(grep -n '^fvm flutter build ios' "$WORK/calls" | head -1 | cut -d: -f1)
first_install=$(grep -n 'device install app' "$WORK/calls" | head -1 | cut -d: -f1)
if [ -n "$first_build" ] && [ -n "$first_install" ] && [ "$first_build" -lt "$first_install" ]; then
  ok "builds before it installs"
else
  ng "builds before it installs"
fi

reset
run --no-build
if [ "$(calls_matching '^fvm ')" -eq 0 ] && installed_on "$IPHONE"; then
  ok "--no-build installs the app already built"
else
  ng "--no-build installs the app already built"
fi

# --- choosing devices ---------------------------------------------------------
reset
run --device satorue_16
if installed_on "$IPHONE" && ! installed_on "$IPAD"; then
  ok "--device picks a device by name"
else
  ng "--device picks a device by name"
fi

reset
run --device "$IPAD"
if installed_on "$IPAD" && ! installed_on "$IPHONE"; then
  ok "--device picks a device by UDID"
else
  ng "--device picks a device by UDID"
fi

reset
run --device nosuchdevice
if [ "$status" -ne 0 ] && [ "$(calls_matching 'device install')" -eq 0 ] &&
  [ "$(calls_matching '^fvm ')" -eq 0 ] && grep -q nosuchdevice "$WORK/out"; then
  ok "an unknown --device fails before building, naming it"
else
  ng "an unknown --device fails before building, naming it"
fi

reset
devices "$(device "$SIM" "iPhone 17" simulated paired booted "")"
run
if [ "$status" -ne 0 ] && [ "$(calls_matching '^fvm ')" -eq 0 ]; then
  ok "no connected device fails before building"
else
  ng "no connected device fails before building"
fi

# --- registering a new device -------------------------------------------------
reset
printf '%s\n' "$IPAD" >"$WORK/profile"
run
if grep -q "^xcodebuild .*-destination id=$IPHONE" "$WORK/calls" &&
  grep -q '^xcodebuild .*-allowProvisioningDeviceRegistration' "$WORK/calls"; then
  ok "registers a device the profile does not name"
else
  ng "registers a device the profile does not name"
fi
if [ "$(calls_matching "id=$IPAD")" -eq 0 ]; then
  ok "leaves a registered device as it is"
else
  ng "leaves a registered device as it is"
fi
if [ "$(calls_matching '^fvm flutter build ios')" -eq 2 ] && installed_on "$IPHONE"; then
  ok "builds again after registering, then installs"
else
  ng "builds again after registering, then installs"
fi

reset
run
if [ "$(calls_matching '^xcodebuild')" -eq 0 ]; then
  ok "registers nothing when the profile names every device"
else
  ng "registers nothing when the profile names every device"
fi

# --- backups ------------------------------------------------------------------
reset
run
if [ "$(calls_matching 'device copy from')" -eq 0 ]; then
  ok "takes no backup unless asked"
else
  ng "takes no backup unless asked"
fi

reset
run --backup
for udid in "$IPAD" "$IPHONE"; do
  for source in Documents/NovelViewer "Library/Application Support" Library/Preferences; do
    if grep -q -- "device copy from --device $udid .*--source $source " "$WORK/calls"; then
      ok "--backup copies $source from $udid"
    else
      ng "--backup copies $source from $udid"
    fi
  done
done
if grep -q -- "--domain-identifier com.endo5501.novelViewer" "$WORK/calls"; then
  ok "--backup copies from the app's own container"
else
  ng "--backup copies from the app's own container"
fi
if grep -q -- "--destination $WORK/backups/NovelViewer-satorue_16-" "$WORK/calls"; then
  ok "--backup keeps each device in a folder of its own"
else
  ng "--backup keeps each device in a folder of its own"
fi
if [ "$(calls_matching 'source Documents/models')" -eq 0 ] &&
  [ "$(calls_matching 'source Documents ')" -eq 0 ]; then
  ok "--backup leaves the speech models out"
else
  ng "--backup leaves the speech models out"
fi
last_copy=$(grep -n "device copy from --device $IPHONE" "$WORK/calls" | tail -1 | cut -d: -f1)
install=$(grep -n "device install app --device $IPHONE" "$WORK/calls" | head -1 | cut -d: -f1)
if [ -n "$last_copy" ] && [ -n "$install" ] && [ "$last_copy" -lt "$install" ]; then
  ok "--backup copies before it installs"
else
  ng "--backup copies before it installs"
fi

reset
run --backup
if grep -q -- "device copy from --device $IPHONE .*--source Documents/voices " "$WORK/calls"; then
  ok "--backup copies the reference voices from a device that has them"
else
  ng "--backup copies the reference voices from a device that has them"
fi
if [ "$(calls_matching "device copy from --device $IPAD .*--source Documents/voices ")" -eq 0 ] &&
  installed_on "$IPAD" && [ "$status" -eq 0 ]; then
  ok "--backup passes over voices a device does not have and still installs"
else
  ng "--backup passes over voices a device does not have and still installs"
fi

reset
printf '%s\n' "$IPAD" >"$WORK/installed"
run --backup
if [ "$(calls_matching "device copy from --device $IPHONE")" -eq 0 ] && installed_on "$IPHONE"; then
  ok "--backup skips a device without the app and still installs on it"
else
  ng "--backup skips a device without the app and still installs on it"
fi

reset
FAIL_COPY_ON="$IPAD"
run --backup
if [ "$status" -ne 0 ] && ! installed_on "$IPAD" && installed_on "$IPHONE"; then
  ok "a failed backup keeps that device from being installed on"
else
  ng "a failed backup keeps that device from being installed on"
fi

# A locked device cannot say which apps it has. Taking that for "no app"
# skipped the backup and installed over the reader's data.
for locked_status in 1 0; do
  reset
  LOCKED_ON="$IPAD"
  LOCKED_STATUS=$locked_status
  run --backup
  if [ "$status" -ne 0 ] && ! installed_on "$IPAD" && installed_on "$IPHONE" &&
    grep -q iPadmini7 "$WORK/out"; then
    ok "--backup does not install on a device it cannot query (exit $locked_status)"
  else
    ng "--backup does not install on a device it cannot query (exit $locked_status)"
    cat "$WORK/out"
  fi
done

# --- failures -----------------------------------------------------------------
reset
FAIL_INSTALL_ON="$IPAD"
run
if [ "$status" -ne 0 ] && installed_on "$IPHONE" && grep -q iPadmini7 "$WORK/out"; then
  ok "a failed install still installs on the rest, names the device and fails"
else
  ng "a failed install still installs on the rest, names the device and fails"
fi

# --- a devicectl that leaves out a physical device's reality --------------------
# Xcode 27.1's devicectl marks only simulators, as "simulated".
reset
devices \
  "$(device "$IPAD" iPadmini7 "" paired booted localNetwork)" \
  "$(device "$IPHONE" satorue_16 "" paired booted wired)" \
  "$(device "$SIM" "iPhone 17" simulated paired booted "")"
run
if installed_on "$IPAD" && installed_on "$IPHONE"; then
  ok "installs on devices with no reality given"
else
  ng "installs on devices with no reality given"
  cat "$WORK/out"
fi
if ! installed_on "$SIM"; then
  ok "still leaves the simulator alone when reality is left out"
else
  ng "still leaves the simulator alone when reality is left out"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
