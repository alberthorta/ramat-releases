#!/bin/sh
# Installs or updates a Ramat component from the latest release: the agent on macOS or
# Linux, the viewer on macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.sh | sh -s agent
#   curl -fsSL https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.sh | sh -s viewer
#
# It reads manifest.json, downloads the file for this machine and checks its SHA-256.
set -eu

REPO=alberthorta/ramat-releases
MANIFEST="https://raw.githubusercontent.com/$REPO/main/manifest.json"

comp=${1:-}
case "$comp" in
agent | viewer) ;;
*)
	echo "usage: install.sh agent|viewer" >&2
	exit 2
	;;
esac
case "$(uname -s)" in
Darwin) os=darwin ;;
Linux) os=linux ;;
*)
	echo "Ramat installs on macOS and Linux only for now." >&2
	exit 1
	;;
esac
if [ "$comp" = viewer ] && [ "$os" != darwin ]; then
	echo "The viewer is a macOS app." >&2
	exit 1
fi
arch=$(uname -m)
case "$arch" in
x86_64) arch=amd64 ;;
aarch64) arch=arm64 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$MANIFEST" -o "$tmp/manifest.json"

# A value from the manifest by key path (components.agent.version). macOS has plutil, Linux
# python3; neither needs anything installed.
if [ "$os" = darwin ]; then
	get() { plutil -extract "$1" raw -o - "$tmp/manifest.json" 2>/dev/null; }
else
	get() {
		python3 - "$tmp/manifest.json" "$1" 2>/dev/null <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    v = v[int(k)] if isinstance(v, list) else v[k]
print(v)
PY
	}
fi

version=$(get "components.$comp.version") || {
	echo "No $comp in the manifest." >&2
	exit 1
}
i=0
url=
while name=$(get "components.$comp.assets.$i.name"); do
	if [ "$(get "components.$comp.assets.$i.os")" = "$os" ] && [ "$(get "components.$comp.assets.$i.arch")" = "$arch" ]; then
		url=$(get "components.$comp.assets.$i.url")
		sum=$(get "components.$comp.assets.$i.sha256")
		break
	fi
	i=$((i + 1))
done
if [ -z "$url" ]; then
	echo "No $comp build for $os $arch." >&2
	exit 1
fi

echo "Downloading $comp $version ($arch)..."
curl -fsSL "$url" -o "$tmp/$name"
if command -v sha256sum >/dev/null; then
	check="sha256sum -c -"
else
	check="shasum -a 256 -c -"
fi
if ! echo "$sum  $tmp/$name" | $check >/dev/null 2>&1; then
	echo "The download does not match the manifest checksum. Nothing was installed." >&2
	exit 1
fi

case "$comp" in
agent)
	mkdir -p "$HOME/.local/bin"
	tar xzf "$tmp/$name" -C "$tmp"
	install -m 755 "$tmp/ramat" "$HOME/.local/bin/ramat"
	"$HOME/.local/bin/ramat" service install
	echo "Installed ramat $version in ~/.local/bin."
	case ":$PATH:" in
	*":$HOME/.local/bin:"*) ;;
	*) echo "Add ~/.local/bin to your PATH: Claude Code hooks call 'ramat'." ;;
	esac
	;;
viewer)
	# /Applications, like the app downloaded from the web: one copy, which updates itself there.
	rm -rf "/Applications/Ramat.app"
	ditto -x -k "$tmp/$name" "/Applications"
	echo "Installed Ramat.app $version in /Applications."
	;;
esac
