#!/bin/sh
# Packs the native release build into a portable onelf bundle in dist/.
#
# Usage: scripts/package-onelf.sh <platform> <version>
#   scripts/package-onelf.sh x86_64-linux 0.1.0
#
# Produces dist/<app>-<platform>.onelf. Run `cargo build --release
# --locked` first. The bundle carries glibc, Mesa and every library the
# binary loads, all from the build host.
set -eu
cd "$(dirname "$0")/.."

platform=$1
version=$2
app=$(sed -n 's/^name = "\(.*\)"$/\1/p' Cargo.toml | head -n 1)
appdir=dist/AppDir

rm -rf "$appdir"
mkdir -p "$appdir/bin" "$appdir/.onelf/icons" "$appdir/.onelf/desktop"
cp "target/release/$app" "$appdir/bin/$app"
cp packaging/linux/app.desktop "$appdir/.onelf/desktop/default.desktop"

# A vector icon goes in as its SVG. A pixel-art one goes in as a raster,
# which onelf installs at its own size beside the bundled theme sizes, so
# a desktop scales the nearest of those as little as it can.
if [ -f assets/icon.svg ]; then
    cp assets/icon.svg "$appdir/.onelf/icons/default.svg"
    mkdir -p "$appdir/share/icons/hicolor/scalable/apps"
    cp assets/icon.svg "$appdir/share/icons/hicolor/scalable/apps/$app.svg"
else
    cp assets/icons/256.png "$appdir/.onelf/icons/default.png"
fi
for size in 16 24 32 48 64 128 256 512; do
    dir=$appdir/share/icons/hicolor/${size}x$size/apps
    mkdir -p "$dir"
    cp "assets/icons/$size.png" "$dir/$app.png"
done
sed "s/^version = .*/version = \"$version\"/" onelf.toml > "$appdir/onelf.toml"

onelf build "$appdir"
onelf verify "$appdir/$app.onelf"
mv "$appdir/$app.onelf" "dist/$app-$platform.onelf"
rm -rf "$appdir"
ls "dist/$app-$platform.onelf"
