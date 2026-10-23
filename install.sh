#!/bin/sh
# Installs or updates a Shepherd component on macOS from the latest release.
#
#   curl -fsSL https://raw.githubusercontent.com/alberthorta/shepherd-releases/main/install.sh | sh -s agent
#   curl -fsSL https://raw.githubusercontent.com/alberthorta/shepherd-releases/main/install.sh | sh -s viewer
#
# It reads manifest.json, downloads the file for this Mac and checks its SHA-256.
set -eu

REPO=alberthorta/shepherd-releases
MANIFEST="https://raw.githubusercontent.com/$REPO/main/manifest.json"

comp=${1:-}
case "$comp" in
agent | viewer) ;;
*)
	echo "usage: install.sh agent|viewer" >&2
	exit 2
	;;
esac
if [ "$(uname -s)" != Darwin ]; then
	echo "Shepherd installs on macOS only for now." >&2
	exit 1
fi
arch=$(uname -m)
[ "$arch" = x86_64 ] && arch=amd64

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$MANIFEST" -o "$tmp/manifest.json"

get() { plutil -extract "$1" raw -o - "$tmp/manifest.json" 2>/dev/null; }

version=$(get "components.$comp.version") || {
	echo "No $comp in the manifest." >&2
	exit 1
}
i=0
url=
while name=$(get "components.$comp.assets.$i.name"); do
	if [ "$(get "components.$comp.assets.$i.os")" = darwin ] && [ "$(get "components.$comp.assets.$i.arch")" = "$arch" ]; then
		url=$(get "components.$comp.assets.$i.url")
		sum=$(get "components.$comp.assets.$i.sha256")
		break
	fi
	i=$((i + 1))
done
if [ -z "$url" ]; then
	echo "No $comp build for macOS $arch." >&2
	exit 1
fi

echo "Downloading $comp $version ($arch)..."
curl -fsSL "$url" -o "$tmp/$name"
if ! echo "$sum  $tmp/$name" | shasum -a 256 -c - >/dev/null 2>&1; then
	echo "The download does not match the manifest checksum. Nothing was installed." >&2
	exit 1
fi

case "$comp" in
agent)
	mkdir -p "$HOME/.local/bin"
	tar xzf "$tmp/$name" -C "$tmp"
	install -m 755 "$tmp/shepherd" "$HOME/.local/bin/shepherd"
	"$HOME/.local/bin/shepherd" service install
	echo "Installed shepherd $version in ~/.local/bin."
	case ":$PATH:" in
	*":$HOME/.local/bin:"*) ;;
	*) echo "Add ~/.local/bin to your PATH: Claude Code hooks call 'shepherd'." ;;
	esac
	;;
viewer)
	mkdir -p "$HOME/Applications"
	rm -rf "$HOME/Applications/Shepherd.app"
	ditto -x -k "$tmp/$name" "$HOME/Applications"
	echo "Installed Shepherd.app $version in ~/Applications."
	;;
esac
