#!/usr/bin/env bash
set -euo pipefail

# 1) Set variables
REPO_OWNER="DDVTECH"
REPO_NAME="mistserver"
TAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FORMULA_PATH="$TAP_DIR/Formula/mistserver.rb"

# 2) Get latest release-tag via GitHub API
LATEST_JSON=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
LATEST_TAG=$(echo "$LATEST_JSON" | grep -oP '"tag_name":\s*"\K(.*)(?=")')
TARBALL_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/tags/$LATEST_TAG.tar.gz"

# 3) Download tarball temporarily and calculate SHA256
TMPDIR=$(mktemp -d)
TARBALL_PATH="$TMPDIR/$REPO_NAME-$LATEST_TAG.tar.gz"
curl -L --fail -o "$TARBALL_PATH" "$TARBALL_URL"
NEW_SHA256=$(shasum -a 256 "$TARBALL_PATH" | awk '{print $1}')

# 4) Update Formula/mistserver.rb
#    - url "…/$LATEST_TAG.tar.gz"
#    - version "$LATEST_TAG"
#    - sha256 "…"
#
# Search for lines that begin with url/version/sha256 and replace them.
#
sed -i.bak -E "
  s|^  url \".*\"|  url \"$TARBALL_URL\"|;
  s|^  version \".*\"|  version \"$LATEST_TAG\"|;
  s|^  sha256 \".*\"|  sha256 \"$NEW_SHA256\"|;
" "$FORMULA_PATH"

# 5) Optionally: cleanup
rm "$FORMULA_PATH.bak"
rm -rf "$TMPDIR"

echo "Updated mistserver.rb → tag=$LATEST_TAG , sha256=$NEW_SHA256"
