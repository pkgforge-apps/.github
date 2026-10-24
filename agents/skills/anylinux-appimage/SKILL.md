---
name: anylinux-appimage
description: Package a pkgforge-apps app as an Anylinux AppImage with quick-sharun, a single file that runs on any Linux distribution, musl and old kernels included. Use when adding an AppImage asset, when a user asks for one, when the AppImage build fails or the image does not start, or when deciding between an AppImage and the onelf bundle.
---

# Anylinux AppImages

An Anylinux AppImage is one executable that carries the app, glibc, the
dynamic loader and every library the app loads. It runs on any Linux
distribution, musl ones and kernels back to 2.6.17 included, without
FUSE: uruntime falls back to namespaces, then to extract and run. The
payload is DwarFS-compressed.

The tools are [quick-sharun](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh),
a wrapper around the [Anylinux sharun fork](https://github.com/pkgforge-dev/Anylinux-sharun),
and [appimagetool](https://github.com/pkgforge-dev/appimagetool). Read
[HOW-TO-MAKE-THESE](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md)
and the [FAQ](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/FAQ.md)
before changing the build.

This is a second Linux format next to the onelf bundle, not a
replacement. onelf stays the release pipeline's portable Linux asset;
an AppImage is for users and managers that expect that format.

## Build on Arch

quick-sharun bundles the libraries of the machine that builds it and is
supported on Arch Linux only. Do not build on Fedora or another
distribution that puts 32-bit libraries in `/usr/lib`. The script below
runs in `ghcr.io/pkgforge-dev/archlinux:latest`, the image the upstream
template and the workflow use.

The app must be installed under `/usr` before quick-sharun runs. Pass
quick-sharun the installed binary. Never copy libraries or binaries
into the AppDir by hand: quick-sharun traces what the binary loads and
deploys it.

## Package the app

```sh
sh .agents/skills/anylinux-appimage/package.sh
```

Outside a container it needs podman or docker, and re-runs itself in the
Arch image; inside one it needs root and pacman, so anything else re-runs
too. It:

1. installs the build packages and the debloated packages;
2. builds `target/release/<app>` with `cargo build --release --locked`;
3. installs the binary to `/usr/bin` and runs quick-sharun with
   `packaging/linux/app.desktop` and `assets/icons/256.png`;
4. packs `dist/<app>-<arch>.AppImage` and its `.zsync`;
5. runs `quick-sharun --simple-test` on the image.

In a container that `anylinux-setup-action` has prepared, step 1 only
adds what that action leaves out, the Rust toolchain and the winit
libraries; it installs nothing the action already brought. Run by hand
in a bare image, it does the whole setup itself.

It reads the app name from `Cargo.toml` and expects the shared layout:
the binary name, the desktop file's `Exec=` and `Icon=`, and the package
name all agree. Two variables matter:

| Variable | Default | Use |
|----------|---------|-----|
| `CONTAINER_ENGINE` | first of podman, docker | pick one |
| `GITHUB_REPOSITORY` | from the git remote | the zsync update information |

quick-sharun decides most of what to deploy from what the binary links
and opens, GTK, Qt and Vulkan included. OpenGL is the exception: left to
detection it bundles `libGLX` and gallium but not `libEGL`, the `dri/`
drivers or `libgbm`, which leaves an image with no Wayland path and no
driver behind the GL it carries. Every app here draws, so the script
sets `DEPLOY_OPENGL=1`. Set another `DEPLOY_*` variable only when
detection gets that one wrong, and say why in the app's own section of
`AGENTS.md`.

The output is `dist/<app>-<arch>.AppImage` and
`dist/<app>-<arch>.AppImage.zsync`, and both are release assets. The
`.zsync` is not optional: the update information ends in
`*<arch>.AppImage.zsync`, so the self-updater resolves that URL to the
`.zsync` asset. Publish the image without it and every installed copy
silently stops updating. It is produced only when the update
information is set, which the script does from `GITHUB_REPOSITORY` or
the `origin` remote.

## Add a workflow

The workflow is app-specific, not shared. Put it in
`.github/workflows/appimage.yml`:

```yaml
name: appimage

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ${{ matrix.runs-on }}
    container: ghcr.io/pkgforge-dev/archlinux:latest
    strategy:
      matrix:
        include:
          - { runs-on: ubuntu-latest, arch: x86_64 }
          - { runs-on: ubuntu-24.04-arm, arch: aarch64 }
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pkgforge-dev/anylinux-setup-action@ba7321e11074f9e387a0634e653d09b115d576cd # v6
      - run: sh .agents/skills/anylinux-appimage/package.sh
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: AppImage-${{ matrix.arch }}
          # The trailing * keeps the .zsync, which the release needs too.
          path: dist/*.AppImage*
          if-no-files-found: error
```

It runs only when started by hand. Nothing is scheduled: the app is
released when its author decides to, and the image is rebuilt then, not
on a timer. Drop the aarch64 row if only one architecture is wanted.

The shared skill must already be synced into the app, or the script is
not there. `anylinux-setup-action` installs patchelf, base-devel, git,
wget, zsync, xvfb and the X libraries and deploys the tools, so
`package.sh` only adds the Rust toolchain and the winit libraries it
leaves out. Add a `github-actions` ecosystem to the app's
`.github/dependabot.yml` so the pinned actions stay current: the app
template only covers cargo and bun, because the shared workflows are
kept current upstream.

An app that needs more than this shared script, such as an AUR package,
a patch or a second binary, keeps its own
`packaging/appimage/get-dependencies.sh` and
`packaging/appimage/make-appimage.sh`, following the upstream template,
and a workflow that runs them. Do not fork the shared script into the
app.

## Ship it

The shared `app-release.yml` does not build AppImages, so the workflow
above is what makes one, and its artifact is attached to the release by
hand:

```sh
gh release upload <tag> dist/*.AppImage dist/*.AppImage.zsync --clobber
```

Spell out both files rather than uploading `dist/*.AppImage` alone,
which leaves the release without the `.zsync` the updater needs.

An asset uploaded this way carries no build provenance attestation. To
have one, add an `appimage` job to `app-release.yml` in
pkgforge-apps/.github: its `publish` job uploads and attests every asset
at once.

Do not let the AppImage workflow create its own `latest` release:
release-plz owns releases.

## Rust and egui

- egui draws through glow, so the image needs the whole GL stack, which
  is why the script asks for it. A smudge app drawing with its CPU
  renderer needs none of it; an app that does not draw at all can drop
  the `DEPLOY_OPENGL` line from its own copy of the script, with a note
  in `AGENTS.md`.
- The build host needs the winit libraries: `wayland`, `libxkbcommon`,
  `libxkbcommon-x11`, `libx11`, `libxcursor`, `libxi` and `libxrandr`.
  The script installs them. quick-sharun's strace mode finds the ones
  the binary opens by name at runtime.
- The template's release profile already sets `lto = true`,
  `panic = "abort"` and `strip = true`; do not add build flags for the
  AppImage.
- Keep `--smoke` working, and test the image with
  `quick-sharun --simple-test dist/*.AppImage`, as the upstream Rust
  example does. `--test` wants the app to stay open for ten seconds and
  counts an early exit as a failure, which an app whose `--smoke` draws
  a frame and exits does not do. `--simple-test` runs the image for
  seven seconds and fails only on a loader error, so it is a check that
  the bundle is complete, not that the app draws: run `--smoke` under
  Xvfb by hand for that.
- A dependency that runs an external helper, such as a file dialog
  backend or a portal, needs that helper in the bundle. quick-sharun
  deploys libraries, not executables: pass the helper to quick-sharun
  as another argument.
- If the app checks for host libraries before starting, it will fail:
  the bundled libraries are not on the host loader path. Skip the check
  when `APPDIR` is set, or patch it out for the AppImage build. Do not
  make the check pass by installing libraries on the host; the AppImage
  must work without them.
- Do not assume `$APPDIR/usr`. The AppImage's install prefix is
  `$APPDIR` itself, and `$APPDIR/shared` belongs to sharun. Use
  `$APPDIR` as the prefix and leave `shared` alone.

## Check the image

```sh
file dist/*.AppImage
quick-sharun --simple-test dist/*.AppImage
```

The script already does that. uruntime falls back on its own when FUSE
and namespaces are unavailable, so nothing has to be set for a host
without either; launching the image once on a desktop with FUSE is still
worth doing. `--simple-test` does not prove the app draws, so run
`--smoke` under Xvfb as well:

```sh
xvfb-run -a timeout 60 dist/*.AppImage --smoke
```

Then check that the image carries its own GL stack. This is the check
that matters, and the one a desktop test cannot make:

```sh
./dist/*.AppImage --appimage-extract > /dev/null
find . -name 'libEGL.so.1' -o -name 'dri' -type d
```

Both must be listed. A host with Mesa supplies what the image is
missing, so an image without them passes every test run on a desktop,
and fails on the one host that matters. Do not install Mesa in a test
container either: on Alpine, `xvfb-run` pulls in `mesa-gl` as a
dependency, so the host ends up with a GL stack of its own.


## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ERROR: Missing dependency 'patchelf'` | the build host lacks quick-sharun's tools | run in the Arch image, or install the packages the script lists |
| `ERROR: Missing '.DirIcon'` | the desktop `Icon=` cannot be found | pass `ICON`, or install the icon under `/usr/share/icons` |
| `error while loading shared libraries` at runtime | a library is missing from the bundle | raise `STRACE_TIME`, make the app reach the code path that opens it, or pass the library to quick-sharun |
| `symbol lookup error` | a host library was used instead of the bundled one | keep the defaults `ANYLINUX_LIB=1` and `CROSS_LIBC_DLOPEN=1`, and never set `LD_LIBRARY_PATH` |
| works in the build container, fails on a host | a host library check or a hardcoded `/usr` path | skip the check; map the path with `PATH_MAPPING` |
| draws on X11, fails on Wayland | the image has no `libEGL` | keep `DEPLOY_OPENGL=1` |
| `Can't find a valid SQUASHFS superblock` | the user runs it through NixOS `appimage-run` | run the AppImage directly; it needs no FHS wrapper |
| no thumbnail in a file manager | DwarFS, not SquashFS | install a DwarFS-aware AppImage thumbnailer |
| the self-updater does nothing | no `UPINFO`, so no `.zsync` | set `GITHUB_REPOSITORY`; AppImage managers disable the updater by design |
| the image is much bigger than expected | the debloated packages were not installed, or a dependency pulled in a large tree | check `get-debloated-pkgs` ran, and `cargo tree` for the dependency |

## Rules

- Change the skill in pkgforge-apps/.github, never in an app: the next
  sync replaces it.
- Keep it app-agnostic. No app names, and only paths from the shared
  app layout.
- The script is POSIX `sh` and passes `shellcheck -s sh`.
