#!/usr/bin/env bash
# No argument: check the latest published release. Argument: use that exact requested tag.
set -euo pipefail
if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [release-tag]" >&2
  exit 1
fi
REPO="DDVTECH/mistserver"
TAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FORMULA_PATH="$TAP_DIR/Formula/mistserver.rb"
SOURCE=release
TAG="${1:-}"
if [ "$#" = 1 ]; then
  SOURCE=tag
  [ -n "$TAG" ] || { echo "An explicit tag must not be empty" >&2; exit 1; }
fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ "$SOURCE" = release ]; then
  curl -fLsS --retry 3 --connect-timeout 15 --max-time 120 \
    "https://api.github.com/repos/$REPO/releases/latest" -o "$WORK/release.json"
  TAG=$(python3 - "$WORK/release.json" <<'PY'
import json, sys
release = json.load(open(sys.argv[1]))
if release.get("draft") or release.get("prerelease"):
    raise SystemExit("Expected a published stable release")
print(release["tag_name"])
PY
  )
fi

# Git ref validity is independent of release naming conventions.
git check-ref-format "refs/tags/$TAG"
[ "$TAG" != development ] || { echo "development is not a release tag" >&2; exit 1; }
# Comparable numeric versions cannot go backward. For arbitrary names, nightly
# cannot infer ordering and leaves the explicit tag selection alone.
VERSION=$(python3 - "$FORMULA_PATH" "$TAG" "$SOURCE" <<'PYVERSION'
import re, sys, urllib.parse
pattern = r"v?([0-9]+)\.([0-9]+)(?:\.([0-9]+))?"
requested = re.fullmatch(pattern, sys.argv[2])
text = open(sys.argv[1]).read()
current_field = re.search(r'^  version "((?:\\.|[^"\\])*)"', text, re.M)
if not current_field:
    raise SystemExit("Expected exactly one formula version")
current_name = current_field[1]
current = re.fullmatch(pattern, current_name)
def rank(match):
    return tuple(int(part or 0) for part in match.groups())
version = re.sub(r"^v(?=[0-9])", "", sys.argv[2])
current_url = re.search(r'^  url "([^"]+)"', text, re.M)
current_tag = None
if current_url and "/archive/refs/tags/" in current_url[1] and current_url[1].endswith(".tar.gz"):
    current_tag = urllib.parse.unquote(current_url[1].split("/archive/refs/tags/", 1)[1][:-7])
if current and requested and rank(requested) < rank(current):
    print("SKIP")
elif sys.argv[3] == "release" and current and requested and rank(requested) == rank(current) and current_tag != sys.argv[2]:
    print("SKIP")
elif sys.argv[3] == "release" and not (current and requested) and version != current_name:
    print("SKIP")
else:
    print(version)
PYVERSION
)
if [ "$VERSION" = SKIP ]; then
  echo "Keeping the formula: $TAG is older or its order cannot be determined by nightly."
  exit 0
fi

# A tag-only update reads source directly and never requests a GitHub release.
ENCODED_TAG=$(python3 - "$TAG" <<'PYURL'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=""))
PYURL
)
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$ENCODED_TAG.tar.gz"
curl -fLsS --retry 3 --connect-timeout 15 --max-time 300 \
  -o "$WORK/source.tar.gz" "$TARBALL_URL"
python3 - "$FORMULA_PATH" "$VERSION" "$TARBALL_URL" "$WORK/source.tar.gz" <<'PY'
import hashlib, json, pathlib, re, sys
formula = pathlib.Path(sys.argv[1])
sha = hashlib.sha256(pathlib.Path(sys.argv[4]).read_bytes()).hexdigest()
text = formula.read_text()
for field, value in (("url", sys.argv[3]), ("version", sys.argv[2]), ("sha256", sha)):
    # Escape both string contents and Ruby interpolation in a valid unusual tag.
    literal = json.dumps(value, ensure_ascii=False).replace("#{", "\\#{")
    text, count = re.subn(r'^  ' + field + r' "(?:\\.|[^"\\])*"',
                          lambda match: "  " + field + " " + literal, text, flags=re.M)
    if count != 1:
        raise SystemExit("Expected exactly one formula " + field)
formula.write_text(text)
print("Updated MistServer to " + sys.argv[2] + " (sha256: " + sha + ")")
PY
