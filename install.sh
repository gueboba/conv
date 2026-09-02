#!/bin/sh
# Link conv into a directory on your PATH. Usage: ./install.sh [DIR]
set -eu

src="$(cd "$(dirname "$0")" && pwd)/conv"
dest="${1:-$HOME/.local/bin}"

mkdir -p "$dest"
ln -sf "$src" "$dest/conv"
echo "linked $dest/conv -> $src"

case ":$PATH:" in
    *":$dest:"*) ;;
    *)
        echo
        echo "$dest is not on your PATH. Add this to your shell profile:"
        echo "    export PATH=\"$dest:\$PATH\""
        ;;
esac
