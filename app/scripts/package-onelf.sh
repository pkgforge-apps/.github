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
mkdir -p "$appdir/bin" "$appdir/.onelf/icons" "$appdir/.onelf/desktop" \
    "$appdir/share/icons/hicolor/scalable/apps"
cp "target/release/$app" "$appdir/bin/$app"
cp assets/icon.svg "$appdir/.onelf/icons/default.svg"
cp packaging/linux/app.desktop "$appdir/.onelf/desktop/default.desktop"
cp assets/icon.svg "$appdir/share/icons/hicolor/scalable/apps/$app.svg"
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
