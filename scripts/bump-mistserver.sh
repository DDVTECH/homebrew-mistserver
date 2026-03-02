#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="DDVTECH"
REPO_NAME="mistserver"
TAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FORMULA_PATH="$TAP_DIR/Formula/mistserver.rb"

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

TARBALL_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/tags/$LATEST_TAG.tar.gz"

# Download and checksum
curl -Lf -o "$TMP_DIR/source.tar.gz" "$TARBALL_URL"
NEW_SHA256=$($SHA256_CMD "$TMP_DIR/source.tar.gz" | awk '{print $1}')

# Update formula
$SED_INPLACE "
  s|^  url \".*\"|  url \"$TARBALL_URL\"|;
  s|^  version \".*\"|  version \"$LATEST_TAG\"|;
  s|^  sha256 \".*\"|  sha256 \"$NEW_SHA256\"|;
" "$FORMULA_PATH"
rm -f "$FORMULA_PATH.bak"

echo "Updated mistserver.rb → $LATEST_TAG (sha256: $NEW_SHA256)"
