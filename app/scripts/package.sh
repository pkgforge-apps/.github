#!/bin/sh
# Packages a release build into dist/.
#
# Usage: scripts/package.sh <rust-target> <platform> <version>
#   scripts/package.sh x86_64-unknown-linux-gnu x86_64-linux 0.1.0
#
# Produces dist/<app>-<platform>.tar.xz on Linux and macOS and
# dist/<app>-<platform>.zip on Windows. Build the release binary for
# <rust-target> first.
set -eu
cd "$(dirname "$0")/.."

target=$1
platform=$2
version=$3
app=$(sed -n 's/^name = "\(.*\)"$/\1/p' Cargo.toml | head -n 1)
title=$(sed -n 's/^Name=//p' packaging/linux/app.desktop | head -n 1)
bin=target/$target/release/$app
name=$app-$platform
stage=dist/$name

rm -rf "$stage"
mkdir -p "$stage"
cp LICENSE README.md "$stage/"

case $target in
*-linux-*)
    cp "$bin" "$stage/"
    mkdir -p "$stage/share/applications" "$stage/share/icons/hicolor/scalable/apps"
    cp packaging/linux/app.desktop "$stage/share/applications/$app.desktop"
    cp assets/icon.svg "$stage/share/icons/hicolor/scalable/apps/$app.svg"
    for size in 16 24 32 48 64 128 256 512; do
        dir=$stage/share/icons/hicolor/${size}x$size/apps
        mkdir -p "$dir"
        cp "assets/icons/$size.png" "$dir/$app.png"
    done
    tar -C dist -cJf "$stage.tar.xz" "$name"
    ;;
*-apple-darwin)
    contents=$stage/$title.app/Contents
    mkdir -p "$contents/MacOS" "$contents/Resources"
    cp "$bin" "$contents/MacOS/$app"
    sed "s/__VERSION__/$version/g" packaging/macos/Info.plist > "$contents/Info.plist"
    plutil -lint "$contents/Info.plist"
    iconset=dist/icon.iconset
    rm -rf "$iconset"
    mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
        cp "assets/icons/$size.png" "$iconset/icon_${size}x$size.png"
        cp "assets/icons/$((size * 2)).png" "$iconset/icon_${size}x$size@2x.png"
    done
    iconutil -c icns "$iconset" -o "$contents/Resources/icon.icns"
    rm -rf "$iconset"
    tar -C dist -cJf "$stage.tar.xz" "$name"
    ;;
*-windows-*)
    cp "$bin.exe" "$stage/"
    (cd dist && 7z a -tzip "$name.zip" "$name" > /dev/null)
    ;;
*)
    echo "unsupported target: $target" >&2
    exit 1
    ;;
esac

rm -rf "$stage"
ls dist/"$name".*
