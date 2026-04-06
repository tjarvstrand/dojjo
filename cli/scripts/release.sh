#!/bin/sh
# Fetch and run the common dart-release script.
set -e

RELEASE_VERSION="${RELEASE_VERSION:-main}"
RELEASE_URL="https://raw.githubusercontent.com/tjarvstrand/dart-release.sh/$RELEASE_VERSION/release.sh"

script_dir="$(cd "$(dirname "$0")" && pwd)"
PUB_DIR="$(dirname "$script_dir")"
cache_dir="${PUB_DIR}/.dart-release"
cached="${cache_dir}/release.sh"

mkdir -p "$cache_dir"
curl -fsSL "$RELEASE_URL" -o "$cached"

export PUB_DIR

release_update_files() {
    sed -i.bak "s/^const version = .*/const version = '$version';/" "$PUB_DIR/lib/src/version.dart"
    rm -f "$PUB_DIR/lib/src/version.dart.bak"
}

. "$cached" "$@"
