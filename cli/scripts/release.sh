#!/bin/sh
set -e

usage() {
  echo "Usage: $0 <major|minor|patch|MAJOR.MINOR.PATCH[+BUILD]>" >&2
  exit 1
}

[ -z "$1" ] && usage

# Resolve paths relative to the script location (cli/scripts/).
script_dir="$(cd "$(dirname "$0")" && pwd)"
cli_dir="$(dirname "$script_dir")"
repo_dir="$(dirname "$cli_dir")"
cd "$cli_dir"

# Detect VCS.
if [ -d "$repo_dir/.jj" ] && command -v jj >/dev/null 2>&1; then
  vcs=jj
else
  vcs=git
fi

# Verify clean working tree.
if [ "$vcs" = "jj" ]; then
  if [ -n "$(jj diff --summary)" ]; then
    echo "Error: working tree is not clean." >&2
    exit 1
  fi
else
  if [ -n "$(git status --porcelain)" ]; then
    echo "Error: working tree is not clean." >&2
    exit 1
  fi
fi

# Extract current version from pubspec.yaml.
current="$(grep '^version:' pubspec.yaml | sed 's/version: *//')"
current_base="${current%%+*}"
current_major="$(echo "$current_base" | cut -d. -f1)"
current_minor="$(echo "$current_base" | cut -d. -f2)"
current_patch="$(echo "$current_base" | cut -d. -f3)"

# Compute new version from argument.
case "$1" in
  major) version="$((current_major + 1)).0.0" ;;
  minor) version="$current_major.$((current_minor + 1)).0" ;;
  patch) version="$current_major.$current_minor.$((current_patch + 1))" ;;
  *[0-9]*)
    # Validate semver format (MAJOR.MINOR.PATCH with optional +BUILD).
    if ! echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
      echo "Error: invalid version '$1'. Expected MAJOR.MINOR.PATCH[+BUILD]." >&2
      exit 1
    fi
    version="$1"
    ;;
  *) usage ;;
esac

tag="v$version"
date="$(date +%Y-%m-%d)"

# Update version in pubspec.yaml and version.dart.
sed -i.bak "s/^version: .*/version: $version/" pubspec.yaml
rm -f pubspec.yaml.bak
sed -i.bak "s/^const version = .*/const version = '$version';/" lib/src/version.dart
rm -f lib/src/version.dart.bak

# Ensure pub.dev authentication (no-op if already logged in).
dart pub login

echo "Releasing $tag..."

# Update CHANGELOG.md: replace [Unreleased] header with the version and date,
# then add a fresh Unreleased section above it.
changelog="$repo_dir/CHANGELOG.md"
if ! grep -q '## \[Unreleased\]' "$changelog"; then
  echo "Error: no [Unreleased] section found in CHANGELOG.md." >&2
  exit 1
fi

sed -i.bak "s/## \[Unreleased\]/## [Unreleased]\n\n## [$version] - $date/" "$changelog"
rm -f "$changelog.bak"

# Update the link references at the bottom.
sed -i.bak "s|\[Unreleased\]: \(.*\)/compare/v.*\.\.\.HEAD|[Unreleased]: \1/compare/$tag...HEAD\n[$version]: \1/releases/tag/$tag|" "$changelog"
rm -f "$changelog.bak"

# Commit, tag, and push.
if [ "$vcs" = "jj" ]; then
  jj commit -m "Release $tag"
  jj bookmark set main -r @-
  jj tag set "$tag" -r @-
  jj git push
  jj git export
  git push -f origin "$tag"
else
  git add "$changelog" pubspec.yaml
  git commit -m "Release $tag"
  git tag "$tag"
  git push
  git push -f origin "$tag"
fi

# Publish to pub.dev.
dart pub publish --force

echo "Released $tag"
