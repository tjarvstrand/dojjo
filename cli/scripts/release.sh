#!/bin/sh
set -e

# Resolve paths relative to the script location (cli/scripts/).
script_dir="$(cd "$(dirname "$0")" && pwd)"
cli_dir="$(dirname "$script_dir")"
repo_dir="$(dirname "$cli_dir")"
cd "$cli_dir"

# Extract version from pubspec.yaml.
version="$(grep '^version:' pubspec.yaml | sed 's/version: *//')"
tag="v$version"
date="$(date +%Y-%m-%d)"

# Detect VCS.
if [ -d "$repo_dir/.jj" ] && command -v jj >/dev/null 2>&1; then
  vcs=jj
else
  vcs=git
fi

# Ensure pub.dev authentication (no-op if already logged in).
dart pub login

echo "Releasing $tag (using $vcs)..."

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
  jj tag set "$tag" -r @-
  jj git push
  jj git export
  git push origin "$tag"
else
  git add "$changelog"
  git commit -m "Release $tag"
  git tag "$tag"
  git push
  git push origin "$tag"
fi

# Publish to pub.dev.
dart pub publish --force

echo "Released $tag"
