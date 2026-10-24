#!/bin/sh
# Builds this app into an Anylinux AppImage in dist/.
#
# Usage: package.sh
#
# Runs on Arch Linux, because quick-sharun deploys the libraries of the
# build host and is only supported there. On another system it re-runs
# itself in the Arch container, which needs podman or docker. Writes
# dist/<app>-<arch>.AppImage and, when the repository is known, its
# .zsync.
set -eu

root=$(cd "$(dirname "$0")/../../.." && pwd -P)

# Natively it has to be Arch, as root: quick-sharun deploys the build
# host's libraries, and pacman needs root. Anything else, a distro that
# merely has /etc/arch-release included, re-runs in the Arch container.
if [ "$(id -u)" -ne 0 ] || ! command -v pacman > /dev/null 2>&1; then
    engine=${CONTAINER_ENGINE:-}
    if [ -z "$engine" ]; then
        for candidate in podman docker; do
            if command -v "$candidate" > /dev/null 2>&1; then
                engine=$candidate
                break
            fi
        done
    fi
    if [ -z "$engine" ]; then
        echo "needs podman or docker: neither is on PATH" >&2
        exit 1
    fi
    exec "$engine" run --rm --security-opt label=disable \
        -v "$root:/src" -w /src \
        -e GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}" \
        ghcr.io/pkgforge-dev/archlinux:latest \
        /bin/sh /src/.agents/skills/anylinux-appimage/package.sh
fi

cd "$root"

app=$(awk -F'"' '/^name = /{print $2; exit}' Cargo.toml)
if [ -z "$app" ]; then
    echo "cannot read the package name from Cargo.toml" >&2
    exit 1
fi
arch=$(uname -m)

echo "building $app for $arch"

# The libraries winit loads, and the Rust toolchain. --needed makes the
# ones anylinux-setup-action already installed a no-op.
set -- rustup wayland libxkbcommon libxkbcommon-x11 libx11 libxcursor \
    libxi libxrandr xorg-xauth

if command -v quick-sharun > /dev/null 2>&1; then
    # anylinux-setup-action has synced the keyring, installed patchelf,
    # base-devel, git, wget, zsync, xvfb and the X libraries, and put the
    # tools on PATH. Only fill the gaps.
    pacman -S --noconfirm --needed "$@"
else
    pacman-key --init > /dev/null 2>&1 || true
    pacman -Syy --noconfirm --needed archlinux-keyring
    pacman -Syu --noconfirm --needed \
        base-devel git patchelf wget zsync xorg-server-xvfb "$@"
    tools=https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools
    for tool in quick-sharun get-debloated-pkgs; do
        wget -qO "/usr/local/bin/$tool" "$tools/$tool.sh"
        chmod +x "/usr/local/bin/$tool"
    done
fi

# The debloated packages are much smaller than Arch's, and quick-sharun
# loads them while it traces the binary, so install them before the build.
get-debloated-pkgs --add-common --prefer-nano

rustup default stable
cargo build --release --locked
install -Dm755 "target/release/$app" "/usr/bin/$app"

export OUTPATH="$root/dist"
export OUTNAME="$app-$arch.AppImage"
export DESKTOP="$root/packaging/linux/app.desktop"
export ICON="$root/assets/icons/256.png"

# Detection alone bundles GLX and gallium but no libEGL, no dri/ and no
# gbm, which leaves the image with no Wayland path and no driver behind
# the GL it does carry. Every app here draws, so ask for the whole stack.
export DEPLOY_OPENGL=1

repo=${GITHUB_REPOSITORY:-}
if [ -z "$repo" ]; then
    repo=$(git config --get remote.origin.url 2>/dev/null |
        sed -e 's|^https://github.com/||' \
            -e 's|^ssh://git@github.com/||' \
            -e 's|^git@github.com:||' \
            -e 's|\.git$||' || true)
fi
case $repo in
*/*)
    export UPINFO="gh-releases-zsync|${repo%/*}|${repo#*/}|latest|*$arch.AppImage.zsync"
    export ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}self-updater.hook"
    ;;
esac

quick-sharun "/usr/bin/$app"
quick-sharun --make-appimage

# --test expects the app to stay open for ten seconds, which an app whose
# --smoke draws a frame and exits does not, so this is the simple test.
quick-sharun --simple-test "$OUTPATH/$OUTNAME"

echo "AppImage: $OUTPATH/$OUTNAME"
