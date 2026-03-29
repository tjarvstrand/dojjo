#!/bin/sh
set -e

REPO="tjarvstrand/dojjo"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${1:-latest}"

detect_platform() {
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)
      case "$arch" in
        x86_64) echo "djo-linux-x64" ;;
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        arm64) echo "djo-macos-arm64" ;;
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    *) echo "Unsupported OS: $os" >&2; exit 1 ;;
  esac
}

artifact="$(detect_platform)"

if [ "$VERSION" = "latest" ]; then
  url="https://github.com/$REPO/releases/latest/download/$artifact"
else
  url="https://github.com/$REPO/releases/download/v$VERSION/$artifact"
fi

echo "Downloading djo from $url..."
mkdir -p "$INSTALL_DIR"
curl -fsSL -o "$INSTALL_DIR/djo" "$url"
chmod +x "$INSTALL_DIR/djo"

echo "Installed djo to $INSTALL_DIR/djo"

# Check if install dir is in PATH.
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "Add $INSTALL_DIR to your PATH to use djo from anywhere." ;;
esac

# Offer shell integration (read from /dev/tty since stdin may be piped).
if [ -t 0 ] || [ -e /dev/tty ]; then
  printf "Install shell integration (cd wrapping for switch/merge)? [y/N] "
  read -r answer </dev/tty 2>/dev/null || answer=""
  case "$answer" in
    [yY])
      shell_name="$(basename "$SHELL")"
      "$INSTALL_DIR/djo" shell install "$shell_name"
      ;;
  esac
fi
