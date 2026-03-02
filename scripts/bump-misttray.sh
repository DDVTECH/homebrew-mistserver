#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="DDVTECH"
REPO_NAME="MistMacTray"
TAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CASK_PATH="$TAP_DIR/Casks/misttray.rb"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE="sed -i.bak -E"
  SHA256_CMD="shasum -a 256"
else
  SED_INPLACE="sed -i.bak -r"
  SHA256_CMD="sha256sum"
fi

# Get latest release tag
LATEST_JSON=$(curl -sf "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
LATEST_TAG=$(echo "$LATEST_JSON" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')

if [[ -z "$LATEST_TAG" ]]; then
  echo "Error: could not determine latest release tag" >&2
  exit 1
fi

VERSION=${LATEST_TAG#v}
ZIP_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$LATEST_TAG/MistTray-$LATEST_TAG.zip"

# Download and checksum
curl -Lf -o "$TMP_DIR/MistTray.zip" "$ZIP_URL"
NEW_SHA256=$($SHA256_CMD "$TMP_DIR/MistTray.zip" | awk '{print $1}')

# Update cask
$SED_INPLACE "
  s|^  version \".*\"|  version \"$VERSION\"|;
  s|^  sha256 \".*\"|  sha256 \"$NEW_SHA256\"|;
" "$CASK_PATH"
rm -f "$CASK_PATH.bak"

echo "Updated misttray.rb → $LATEST_TAG (sha256: $NEW_SHA256)"
