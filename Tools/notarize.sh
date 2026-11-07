#!/usr/bin/env bash
#
# Notarizes an app or a disk image, waits for Apple's answer, and staples the
# ticket to it.
#
#   Tools/notarize.sh dist/desktop-commander-1.0.0.dmg
#   Tools/notarize.sh build/Build/Products/Release/desktop-commander.app
#
# It needs an App Store Connect API key in three variables: NOTARY_KEY_PATH
# (the .p8 file), NOTARY_KEY_ID, and NOTARY_ISSUER_ID. The release workflow
# sets them. On a refusal, it prints Apple's log, which names every file and
# the reason.

set -euo pipefail

target="${1:?usage: Tools/notarize.sh <app or dmg>}"
: "${NOTARY_KEY_PATH:?NOTARY_KEY_PATH is not set}"
: "${NOTARY_KEY_ID:?NOTARY_KEY_ID is not set}"
: "${NOTARY_ISSUER_ID:?NOTARY_ISSUER_ID is not set}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# notarytool takes a zip, a disk image, or a package, not a bare app.
upload="$target"
if [[ "$target" == *.app ]]; then
  upload="$work/$(basename "$target" .app).zip"
  ditto -c -k --sequesterRsrc --keepParent "$target" "$upload"
fi

auth=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")

set +e
xcrun notarytool submit "$upload" "${auth[@]}" \
  --wait --timeout 45m --output-format json > "$work/result.json"
status=$?
set -e
cat "$work/result.json"
echo

id=$(plutil -extract id raw "$work/result.json" 2>/dev/null || true)
result=$(plutil -extract status raw "$work/result.json" 2>/dev/null || true)
if [[ $status -ne 0 || "$result" != "Accepted" ]]; then
  if [[ -n "$id" ]]; then
    xcrun notarytool log "$id" "${auth[@]}" || true
  fi
  echo "::error::Notarization of $(basename "$target") did not succeed: ${result:-no answer}" >&2
  exit 1
fi

xcrun stapler staple "$target"
xcrun stapler validate "$target"
