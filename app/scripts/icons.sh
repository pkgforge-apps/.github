#!/bin/sh
# Regenerates every raster icon from assets/icon.svg.
#
# Outputs:
#   assets/icons/<size>.png           window icon, hicolor theme, icns sources
#   assets/icon.ico                   Windows executable icon
#   docs/public/favicon.svg           assets/favicon.svg when present
#   docs/public/logo.svg              docs nav logo
#   docs/public/apple-touch-icon.png
#
# Needs resvg (cargo install resvg).
set -eu
cd "$(dirname "$0")/.."

svg=assets/icon.svg
favicon=assets/favicon.svg
[ -f "$favicon" ] || favicon=$svg

mkdir -p assets/icons docs/public
for size in 16 24 32 48 64 128 256 512 1024; do
    resvg -w "$size" -h "$size" "$svg" "assets/icons/$size.png"
done

byte() {
    # shellcheck disable=SC2059 # the format is the octal escape itself
    printf "\\$(printf '%03o' "$(($1 & 255))")"
}

le16() {
    byte "$1"
    byte "$(($1 >> 8))"
}

le32() {
    le16 "$(($1 & 65535))"
    le16 "$(($1 >> 16))"
}

# An ICO is a 6-byte header, one 16-byte entry per image, then the
# images. Vista and later read PNG-encoded entries directly.
ico_sizes="16 24 32 48 64 128 256"
count=0
for size in $ico_sizes; do
    count=$((count + 1))
done
offset=$((6 + 16 * count))
{
    le16 0
    le16 1
    le16 "$count"
    for size in $ico_sizes; do
        length=$(wc -c < "assets/icons/$size.png")
        byte "$size"
        byte "$size"
        byte 0
        byte 0
        le16 1
        le16 32
        le32 "$length"
        le32 "$offset"
        offset=$((offset + length))
    done
    for size in $ico_sizes; do
        cat "assets/icons/$size.png"
    done
} > assets/icon.ico

cp "$favicon" docs/public/favicon.svg
cp "$svg" docs/public/logo.svg
resvg -w 180 -h 180 "$svg" docs/public/apple-touch-icon.png
echo "icons regenerated from $svg"
