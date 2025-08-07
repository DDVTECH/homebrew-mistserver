#!/usr/bin/env bash
set -euo pipefail

# 1) Set variables
REPO_OWNER="DDVTECH"
REPO_NAME="mistserver"
TAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FORMULA_PATH="$TAP_DIR/Formula/mistserver.rb"

# Detect platform for compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  SED_INPLACE="sed -i.bak -E"
  SHA256_CMD="shasum -a 256"
else
  # Linux/other
  SED_INPLACE="sed -i.bak -r"
  SHA256_CMD="sha256sum"
fi

# 2) Get latest release-tag via GitHub API
LATEST_JSON=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
LATEST_TAG=$(echo "$LATEST_JSON" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')
TARBALL_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/tags/$LATEST_TAG.tar.gz"

# 3) Download tarball temporarily and calculate SHA256
TMPDIR=$(mktemp -d)
TARBALL_PATH="$TMPDIR/$REPO_NAME-$LATEST_TAG.tar.gz"
curl -L --fail -o "$TARBALL_PATH" "$TARBALL_URL"
NEW_SHA256=$($SHA256_CMD "$TARBALL_PATH" | awk '{print $1}')

# 4) Update Formula/mistserver.rb
$SED_INPLACE "
  s|^  url \".*\"|  url \"$TARBALL_URL\"|;
  s|^  version \".*\"|  version \"$LATEST_TAG\"|;
  s|^  sha256 \".*\"|  sha256 \"$NEW_SHA256\"|;
" "$FORMULA_PATH"

# 5) Cleanup
rm "$FORMULA_PATH.bak"
rm -rf "$TMPDIR"

echo "Updated mistserver.rb → tag=$LATEST_TAG , sha256=$NEW_SHA256"
