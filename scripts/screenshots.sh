#!/bin/bash
#
# The App Store listing's screenshots (iteration 7, R8).
#
# One Debug build, installed on a 6.9" iPhone and a 13" iPad, launched once
# per shot with a bundled fixture save in slot 0 and the tab or route the
# shot is about, photographed with `simctl io screenshot` into
# docs/release/screenshots/<device>/.
#
# Run it with `make screenshots`. The devices come from the Makefile
# (SHOT_SIM_PHONE / SHOT_SIM_IPAD) and must already exist — clone them
# first if you want to keep your own simulators out of it:
#
#     xcrun simctl clone "iPhone 17 Pro Max" shots-max
#     make screenshots SHOT_SIM_PHONE=shots-max
#
# Every launch installs its fixture into slot 0 before the shell appears
# (`-autoFixture`, App/Sources/ReleaseFixtures.swift), so a shot never
# depends on the one before it; the app is reinstalled between shots so
# neither does its UserDefaults.
#
# Fails, loudly, if the number of PNGs on disk at the end is not the number
# of shots times the number of devices — a launch that silently died is
# the failure mode this pipeline actually has.

set -euo pipefail

BUNDLE_ID="com.alpsenel.startupstudio"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/release/screenshots"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/StartupStudio.app"

PHONE="${SHOT_SIM_PHONE:-iPhone 17 Pro Max}"
IPAD="${SHOT_SIM_IPAD:-iPad Pro 13-inch (M5)}"

# How long the app gets to reach the screen before its picture is taken.
# The pixel scenes compose on the first frames and the tab roots push
# their `-autoRoute` destination from a `.task`, so this is not zero.
SETTLE="${SHOT_SETTLE:-8}"

# One line per shot: <name>|<fixture>|<extra launch arguments>
#
# `-unlocked` rides on every one (R6's flag: the store screenshots show
# the whole game). The order is the order the listing tells the story in:
# the door, the garage you start in, the studio it becomes, a life, the
# people, the work, launch week, the world. App Store Connect takes ten
# per size, so the first ten are the listing and `11-campus` is the
# alternate for shot 3 — see docs/release/screenshots.md.
#
# The company timeline is deliberately NOT here: its year view stacks
# every moment's label at the same height, and a company with 35 of them
# photographs as overlapping text. Fixing that is the timeline's own
# work, not the pipeline's.
SHOTS=(
  "01-title|release-studio-day400|"
  "02-garage|release-garage-day40|-autoTab hq"
  "03-hq|release-studio-day400|-autoTab hq"
  "04-life|release-studio-day400|-autoTab life"
  "05-team|release-campus-day900|-autoTab team"
  "06-products|release-studio-day400|-autoTab products"
  "07-war-room|release-studio-day400|-autoTab products -autoRoute warroom"
  "08-business|release-campus-day900|-autoTab business"
  "09-market-map|release-campus-day900|-autoTab business -autoRoute marketmap"
  "10-newspaper|release-studio-day400|-autoTab hq -autoRoute newspaper"
  "11-campus|release-campus-day900|-autoTab hq"
)

slug() {
  echo "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g;s/^-//;s/-$//'
}

# The output folder is named for the simulator's *device type*, not the
# simulator: run the pipeline on a clone called "r8-max" and the
# screenshots still land in iphone-17-pro-max/, which is what App Store
# Connect asks for and what belongs in the repo.
device_dir() {
  local type
  type=$(xcrun simctl list devices -j |
    /usr/bin/python3 -c '
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data["devices"].items():
    for device in devices:
        if device.get("name") == name:
            print(device.get("deviceTypeIdentifier", "").rsplit(".", 1)[-1])
            raise SystemExit
' "$1")
  slug "${type:-$1}"
}

boot() {
  local device="$1"
  xcrun simctl bootstatus "$device" -b >/dev/null 2>&1 ||
    { xcrun simctl boot "$device" >/dev/null 2>&1 || true; xcrun simctl bootstatus "$device" -b >/dev/null; }
}

shoot() {
  local device="$1" dir="$2"
  mkdir -p "$dir"
  for shot in "${SHOTS[@]}"; do
    local name fixture args
    IFS='|' read -r name fixture args <<<"$shot"
    echo "  $name  ($fixture $args)"
    xcrun simctl terminate "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl install "$device" "$APP"
    # shellcheck disable=SC2086
    xcrun simctl launch "$device" "$BUNDLE_ID" -unlocked -autoFixture "$fixture" $args >/dev/null
    sleep "$SETTLE"
    xcrun simctl io "$device" screenshot --type=png "$dir/$name.png" >/dev/null 2>&1
  done
  xcrun simctl terminate "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

echo "==> building (Debug, iOS Simulator)"
xcodebuild -project "$ROOT/StartupStudio.xcodeproj" -scheme StartupStudio \
  -destination "platform=iOS Simulator,name=$PHONE" \
  -derivedDataPath "$ROOT/build" build >/dev/null

test -d "$APP" || { echo "no app at $APP" >&2; exit 1; }

rm -rf "$OUT"
for device in "$PHONE" "$IPAD"; do
  dir="$OUT/$(device_dir "$device")"
  echo "==> $device -> ${dir#"$ROOT"/}"
  boot "$device"
  shoot "$device" "$dir"
done

expected=$(( ${#SHOTS[@]} * 2 ))
actual=$(find "$OUT" -name '*.png' | wc -l | tr -d ' ')
echo "==> $actual screenshots in ${OUT#"$ROOT"/} (expected $expected)"
if [ "$actual" -ne "$expected" ]; then
  echo "screenshot count is wrong — a launch died silently" >&2
  exit 1
fi
# A screenshot of a crashed app is a valid PNG of a black screen, so size
# is the cheapest tell that something was actually drawn.
find "$OUT" -name '*.png' -size -20k -print -exec false {} + ||
  { echo "the files above are suspiciously small — look at them" >&2; exit 1; }
