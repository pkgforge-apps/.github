---
name: release
description: Explain, operate and troubleshoot the release pipeline of a pkgforge-apps app (release-plz on GITHUB_TOKEN, release assets, onelf bundle, crates.io trusted publishing). Use when cutting a release, when a release or release PR misbehaves, when adding a build target, or when an app should be published to crates.io.
---

# Release pipeline

Everything runs on `GITHUB_TOKEN`. Releases, release PRs and their
commits belong to github-actions[bot]. Never add a personal access token
or a registry token to the repository secrets.

The jobs live in reusable workflows in
[pkgforge-apps/.github](https://github.com/pkgforge-apps/.github), shared
by every app. The app carries two small callers, synced from there and
pinned to the revision they were synced from:

| App workflow | Calls | Started by |
|--------------|-------|------------|
| `release-plz.yml` | `app-release-plz.yml` | every push to `main` |
| `release.yml` | `app-release.yml` with a `tag` input | `release-plz.yml`, or by hand |

A change to how apps release is made in pkgforge-apps/.github and
reaches every app through its weekly sync pull request; see the
`sync-guidelines` skill.

## How a release happens

1. A push to `main` runs the `release` job. Nothing is pending, so it
   does nothing. Then `release-pr` opens or updates the release PR: the
   version bump in `Cargo.toml` and `Cargo.lock`, and the new
   `CHANGELOG.md` section, computed from conventional commits since the
   last tag.
2. A PR pushed with `GITHUB_TOKEN` does not trigger `pull_request`
   workflows, so `release-pr` dispatches `ci.yml` on the PR branch
   itself. Its checks show on the PR as usual.
3. Merging the release PR pushes to `main`. `release` now tags the
   version (`<version>`, no `v` prefix) and creates the GitHub release
   with the changelog section.
4. A release created with `GITHUB_TOKEN` cannot trigger `on: release`
   workflows, but `workflow_dispatch` is exempt, so `release` starts
   `release.yml` with the new tag. It builds the assets in the `build`,
   `onelf` and, when the app ships one, `appimage` jobs, and `publish`
   uploads them all at once, with build provenance attestations.

To release, merge the release PR. To change the next version, edit it in
the release PR, or use `feat!:` and `BREAKING CHANGE:` for a major bump.

## Assets

| Job | Runner | Output |
|-----|--------|--------|
| build | ubuntu-22.04 (low glibc floor), ubuntu-22.04-arm | `<app>-<arch>-linux.tar.xz` |
| build | macos-latest, both arches | `<app>-<arch>-macos.tar.xz` with the `.app` |
| build | windows-latest | `<app>-x86_64-windows.zip` |
| onelf | Arch containers | `<app>-<arch>-linux.onelf` |
| appimage | Arch containers, when opted in | `<app>-<arch>-linux.AppImage` and its `.zsync` |

Packaging is in `scripts/package.sh`, `scripts/package-onelf.sh` and
`scripts/package-appimage.sh`, so it runs the same locally. No `.sha256` files: users verify with
`gh attestation verify <file> -R pkgforge-apps/<name>`.

### The onelf bundle

`onelf.toml` packs with the stipplefs payload, strips libraries, scans
the binary for dlopen'd names, keeps GTK and libdecor out (winit never
uses them) and force-includes the X11 libraries winit loads by name. The
bundle is built on Arch, because glibc bundled from Ubuntu did not run
everywhere, and the job smoke-runs it under Xvfb.

It also bundles Arch's Mesa (`gl` and `dri`). Without it the app fails
on any host where onelf finds no usable GL: Alpine and other musl
distributions, whose drivers a glibc process cannot load, and minimal
VMs and containers without Mesa. Mesa and its `libLLVM` take the bundle
from about 7 MB to about 60 MB. NVIDIA's proprietary driver is still
taken from the host when installed.

When the app starts loading another library at runtime that the scan
cannot see, add its soname to `include`. To check what a bundle carries:

```sh
onelf list dist/<app>-x86_64-linux.onelf | grep '\.so'
```

The `onelf` skill covers debugging a bundle, and the `test-linux-bundle`
skill checks one on the hosts users have. Run the latter before merging
any change to `onelf.toml`.

To bump onelf, update `PINNED_ONELF_VERSION` and both `onelf-sha256` values in
`.github/workflows/app-release.yml` of pkgforge-apps/.github. It is
shared, so the bump reaches every app. GitHub lists the digests:

```sh
gh api repos/QaidVoid/onelf/releases/tags/<version> \
  --jq '.assets[] | "\(.name) \(.digest)"'
```

Then build the bundle with the new onelf and run the
`test-linux-bundle` skill on it before merging.

To try another onelf on one release without changing the pin, rebuild
its assets with the `onelf-version` input:

```sh
gh workflow run release.yml -f tag=<version> -f onelf-version=<onelf version>
```

That version is checked against the SHA-256 digest GitHub lists for its
release asset rather than a pinned one. Releases started by release-plz
always use the pinned version.

### The AppImage

An app ships an Anylinux AppImage next to the onelf bundle by setting
this in its `Cargo.toml`:

```toml
[package.metadata.pkgforge]
appimage = true
```

The `appimage` job is skipped otherwise. The `anylinux-appimage` skill
covers building, checking and debugging the image.

## Troubleshooting

- **No release PR appears.** The repository or organization does not let
  Actions create pull requests. See step 7 of `bootstrap-app`.
- **A build job failed.** Re-run the failed jobs of the `release` run.
  When the fix needs a code change, the release has to be rebuilt from
  a commit the tag does not include, so cut a new release instead.
  `publish` waits for every build, so a release never ships with
  platforms missing; it stays without assets until a run succeeds.
- **A release has no assets at all.** The dispatch did not happen or
  failed. Build them by hand:
  `gh workflow run release.yml -f tag=<version>`.
- **The push that merged the release PR did not start the workflow.**
  Run it manually: `gh workflow run release-plz.yml --ref main`.
- **The release PR repeats old history.** A tag is missing. Tags are the
  source of truth while `git_only = true`.

## Publishing to crates.io

Apps are git-only by default: release-plz reads versions from git tags
and never runs `cargo publish`. An app can also publish to crates.io, so
it installs with `cargo install`. The shared workflows need no change:
the `release` job already has `id-token: write`, and without a
`CARGO_REGISTRY_TOKEN` release-plz uses crates.io trusted publishing to
get a publish token for each run. Never add that secret.

crates.io cannot create a crate through trusted publishing, so the first
version is published by hand, and it has to happen before the switch
lands. Otherwise release-plz's next `release` run tries to publish a
crate that does not exist yet and fails. In order:

1. Check the crate name is free on crates.io. If it is taken, the crate
   needs another name, which is a larger change; stop and ask.
2. Check the crate packages: drop `publish = false` from `Cargo.toml`
   locally, without committing, and run
   `cargo publish --dry-run --locked`.
3. Publish the version `main` is at, which is the last release, from
   that same local change: the user runs `cargo publish --locked` with a
   short-lived crates.io token of their own, scoped to `publish-new`.
   Do not store the token anywhere. The registry and the git tags then
   agree on the current version.
4. On crates.io, under the crate's Settings > Trusted Publishing, add
   GitHub: owner `pkgforge-apps`, repository `<name>`, workflow
   `release-plz.yml`, no environment. crates.io checks the workflow the
   run started from, which is the app's caller, not the shared
   reusable workflow.
5. Commit the switch as `chore: publish to crates.io`: remove
   `git_only = true` from `.release-plz.toml` and `publish = false` from
   `Cargo.toml`. From the next release on, release-plz publishes the
   crate, then tags and releases it as before.
6. Point the install instructions at crates.io:
   `cargo install --locked <name>` in the README and
   `docs/guide/installation.md`.

## Adding a target

Targets are shared. Add a row to the `build` matrix of
`.github/workflows/app-release.yml` in pkgforge-apps/.github with the
platform name, runner and Rust target, and make sure
`app/scripts/package.sh` there handles the target's OS. Then add the
matching link in each app's
`docs/.vitepress/theme/components/Downloads.vue` and README.
