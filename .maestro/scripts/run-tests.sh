#!/bin/bash

# run-tests.sh - script to set up device, build example app, and run Maestro flows.
#
# Usage:
#   ./run-tests.sh --platform <ios|android> [--update-screenshots] [--rebuild] [flows]
#
# Opts:
#   --platform            Required. Target platform, either ios or android.
#   --update-screenshots  Instead of running tests, refresh baselines.
#   --rebuild             Force a rebuild and install, even if the app is aleady
#                           installed on the device.
#
#   flows                 One or more Maestro flow files (or directories) to run
#                           Defaults to all component suites if omited
#
# Examples:
#   ./run-tests.sh --platform ios .maestro/enrichedMarkdownTest/flows
#   ./run-tests.sh --platform android --update-screenshots --rebuild

set -euo pipefail

MIN_MAESTRO_VERSION="2.5.0"

if ! command -v maestro >/dev/null 2>&1; then
  echo "Error, maestro CLI not found." >&2
  exit 1
fi

MAESTRO_VERSION=$(maestro --version)
# Compare versions by sorting them; if the minimum sorts after the actual, it's too old.
# flags: -V (version sort) -C (check mode) so no need to check via head
if ! printf '%s\n%s\n' "$MIN_MAESTRO_VERSION" "$MAESTRO_VERSION" | sort -VC; then
  echo "Error: maestro $MAESTRO_VERSION is too old, minimum required is $MIN_MAESTRO_VERSION" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAESTRO_ROOT="$REPO_ROOT/.maestro"
SCREENSHOT_ROOT="$MAESTRO_ROOT"
BUNDLE_ID="enrichedmarkdown.example"

PLATFORM=""
UPDATE_SCREENSHOTS=""
REBUILD=""
FLOWS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --platform)           PLATFORM="$2"; shift 2 ;;
    --update-screenshots) UPDATE_SCREENSHOTS="true"; shift ;;
    --rebuild)            REBUILD="true"; shift ;;
    *)                    FLOWS="${FLOWS:+$FLOWS }$1"; shift ;;
  esac
done

[ -z "$FLOWS" ] && FLOWS="$MAESTRO_ROOT/enrichedMarkdownText/flows $MAESTRO_ROOT/enrichedMarkdownInput/flows"

case "$PLATFORM" in
  ios)      SETUP="$SCRIPT_DIR/setup-ios-simulator.sh" ;;
  android)  SETUP="$SCRIPT_DIR/setup-android-emulator.sh" ;;
  *)        echo "Error: --platform is required. (--platform <ios|android>)" >&2; exit 1 ;;
esac

DEVICE_ID=$("$SETUP" | tee /dev/tty | grep "^DEVICE_ID=" | cut -d= -f2)

app_installed() {
  if [ "$PLATFORM" = ios ]; then
    xcrun simctl listapps "$DEVICE_ID" 2>/dev/null | grep -q "$BUNDLE_ID"
  else
    adb -s "$DEVICE_ID" shell pm list packages "$BUNDLE_ID" 2>/dev/null | grep -q "$BUNDLE_ID"
  fi
}

if [ -n "$REBUILD" ] || ! app_installed; then
  [ -n "$REBUILD" ] && echo "=== rebuild forced, building and installing ==="
  [ -z "$REBUILD" ] && echo "=== App ($BUNDLE_ID) not found, building and installing ==="
  if [ "$PLATFORM" = ios ]; then
    yarn example ios --udid "$DEVICE_ID"
  else
    yarn example android --device "$DEVICE_ID"
  fi
else
  echo "=== APP ($BUNDLE_ID) aleady installed, skipping build ==="
fi

EXTRA_FLAGS="--env SCREENSHOT_ROOT=$SCREENSHOT_ROOT"
[ -n "$UPDATE_SCREENSHOTS" ] && EXTRA_FLAGS="$EXTRA_FLAGS --env UPDATE_SCREENSHOTS=true"

# Exclude platform-specific tests for other platform
case "$PLATFORM" in
  ios)      EXTRA_FLAGS="$EXTRA_FLAGS --exclude-tags android-only" ;;
  android)  EXTRA_FLAGS="$EXTRA_FLAGS --exclude-tags ios-only" ;;
esac

# Maestro resolves addMedia paths by walking the workspace inputs. Since assets
# live outside the flows directory, always include it so media files are found.
ASSETS_DIR="$MAESTRO_ROOT/assets"
[ -d "$ASSETS_DIR" ] && FLOWS="$ASSETS_DIR $FLOWS"

echo "=== Running maestro tests ==="
# shellcheck disable=SC2086
maestro test --device "$DEVICE_ID" $EXTRA_FLAGS $FLOWS

