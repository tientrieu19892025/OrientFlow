#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
export THEOS="${THEOS:-$HOME/theos}"

if ! /usr/bin/make --version >/dev/null 2>&1; then
  if [[ -x /Library/Developer/CommandLineTools/usr/bin/make ]]; then
    export PATH="/Library/Developer/CommandLineTools/usr/bin:$PATH"
  fi
fi
MAKEBIN="$(command -v gmake 2>/dev/null || command -v make)"

build() {
  local scheme="$1"
  echo ""
  echo "════════════════════════════════════════"
  echo "  Building OrientFlow ($scheme)"
  echo "════════════════════════════════════════"
  "$MAKEBIN" clean
  if [[ "$scheme" == "rootful" ]]; then
    "$MAKEBIN" package FINALPACKAGE=1
  else
    "$MAKEBIN" package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME="$scheme"
  fi
}

mkdir -p packages
build rootful
build rootless
if [[ -d "$HOME/theos-roothide" ]]; then
  echo "RootHide Theos detected — building roothide with $HOME/theos-roothide"
  THEOS="$HOME/theos-roothide" "$MAKEBIN" clean
  THEOS="$HOME/theos-roothide" "$MAKEBIN" package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide || {
    echo "RootHide build skipped."
  }
else
  "$MAKEBIN" clean
  "$MAKEBIN" package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide || echo "RootHide scheme unavailable on this Theos — skip."
fi

echo ""
echo "Packages successfully built:"
ls -lh packages || true
