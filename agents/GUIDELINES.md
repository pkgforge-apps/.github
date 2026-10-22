Guidelines for anyone, human or agent, working on a pkgforge-apps
repository. Every app in the organization starts from the
[app template](https://github.com/pkgforge-apps/app-template) and follows
these rules, so the repositories stay consistent with each other.

These guidelines, the shared skills, the shared scripts and the CI and
release workflows live in
[pkgforge-apps/.github](https://github.com/pkgforge-apps/.github). Each
app carries a copy that `scripts/sync-guidelines.sh` refreshes, and a
weekly workflow opens a pull request when they change. Edit them there,
never in an app; an edit made in an app is overwritten by the next sync.
`.agents/shared-guidelines.lock` lists every shared file.

## Purpose

pkgforge-apps builds lightweight native replacements for heavyweight
desktop apps, Electron apps in particular. Each app is a single Rust
binary. Small binary, fast start, low memory: if a change works against
those, it needs a strong reason.

### Choosing the GUI library

- [egui](https://github.com/emilk/egui), through eframe, is the default
  and what the app template is built on. It is immediate mode and
  mature: a good fit for tools, utilities, viewers and dashboards.
- [smudge](https://github.com/QaidVoid/smudge) is designed for
  general-purpose apps: a retained widget tree, fine-grained reactive
  signals, and repainting only what changed, which keeps an idle app
  idle. Prefer it for conventional desktop apps with many views, forms
  or documents. It is still in development: its API changes without
  notice and it is not on crates.io yet, so check its state and agree on
  it with the maintainer before starting an app on it.

Pick one per app at the start; do not mix them.

## Platforms

- Every app runs on Linux, macOS and Windows unless its function is tied
  to one OS. Say so in the README when it is.
- Put OS-specific code behind `#[cfg(target_os = "...")]` in its own
  module, with a fallback or a clear "unsupported" path on the others.
- Never hard-code path separators, line endings or config locations.
  Use `std::path`, and the platform conventions for config, data and
  cache directories.
- CI tests on all three platforms. A change that only compiles on yours
  is not done.

## Workflow

- Commit one logical change at a time. Never commit a broken state.
- Run `scripts/check.sh` before every commit. It runs what CI runs.
- Never bump the version or edit `CHANGELOG.md` by hand. release-plz
  owns both.

### Commit messages

Semantic, imperative, one line, at most 68 characters:

```
type: imperative message
type(scope): imperative message
```

Types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `style`,
`chore`, `ci`, `revert`. Use `feat!:` or a `BREAKING CHANGE:` footer for
breaking changes. Keep any body short. The commit types decide the next
version and the changelog groups, so pick them carefully:

- `feat: add a recent files menu`
- `fix(editor): keep the cursor on undo`
- `perf: cache decoded thumbnails`

## Code

- Write idiomatic Rust, edition 2024, on the latest stable toolchain.
- Document every item: modules (`//!`), functions, structs, enums,
  variants, fields and constants (`///`). Doc comments say what a thing
  is for and any contract a caller must keep. CI enforces this through
  `missing_docs` and `clippy::missing_docs_in_private_items`.
- No narrative comments. Do not restate what the code does. An inline
  comment is for a non-obvious *why*: a platform quirk, a workaround, a
  constraint that is not visible from the code.
- ASCII only, in every file: source, docs, configs, scripts. Write
  glyphs in Rust strings as `\u{..}` escapes. `scripts/check-ascii.sh`
  enforces it.
- Do not over-engineer. No abstraction, trait, generic or config knob
  for a case that does not exist yet. Three similar lines beat a
  premature helper.
- Prefer `Result` with context over panics. `expect` is for invariants
  that cannot fail, with a message that states the invariant.
- Scripts are POSIX `sh` (`#!/bin/sh`), never bash. They must pass
  `shellcheck -s sh`.

### egui apps

- Keep state and logic apart from drawing. Logic lives in plain types
  with plain methods that tests can call; `ui` functions read that
  state and turn input into calls on it.
- Never block the UI thread. Run I/O and heavy work on a
  `std::thread`, send results back over a channel, and call
  `ctx.request_repaint()` when they arrive. Reach for an async runtime
  only when the work is genuinely async-heavy.
- Repaint on demand. Do not request continuous repaints unless
  something is animating.
- The renderer is glow (OpenGL). Keep eframe's default features off and
  enable only what the app uses.
- Keep the `--smoke` flag working. CI and the release pipeline launch
  every build with it to prove the app opens a window and draws.

### smudge apps

- The template is built on egui. A smudge app starts from it and
  replaces `src/` and the eframe dependency; everything else stays,
  including the `--smoke` flag, which must draw a frame and exit 0.
- Until smudge is on crates.io, depend on it by git, pinned to a commit
  with `rev`. Move the pin deliberately, one change at a time, and read
  smudge's commits since the last pin first, since its API breaks
  without notice. Switch to crates.io once it is published.
- Follow smudge's own patterns: state in signals, views derived from
  them, and no work on the UI thread that could block a frame.
- Test views with smudge's headless harness, which runs the same frame
  pipeline a window does.

## Dependencies

- Add and change dependencies with `cargo add` and `cargo remove`,
  never by editing `Cargo.toml` by hand. Use `--no-default-features`
  and list only the features the app uses.
- Vet a crate before adding it. The `add-dependency` skill has the
  procedure. In short:
  - The latest release or commit must be under a year old.
  - An older crate is acceptable only when it is clearly complete,
    with no unanswered bug reports or stale PRs piling up.
  - Check what it pulls in with `cargo tree`. A large tree for a small
    feature is a reason to say no.
- Prefer inlining over a dependency when the functionality is a few
  dozen lines. A small, tested function in the app beats a crate.
- Prefer pure-Rust crates. A crate that links a C library adds a system
  dependency on every platform.
- No git dependencies and no `[patch]` sections. Releases build from
  crates.io. The one exception is smudge, until it is published.

## Tests

- Test behavior: what a user or caller can observe. A test should fail
  when the behavior breaks and pass through any refactor that keeps it.
- Test logic in unit tests next to the code. Test UI interaction when
  the behavior lives in the UI (clicking, typing, focus, layout that
  matters): with `egui_kittest` in an egui app, with smudge's headless
  harness in a smudge app.
- Every bug fix comes with a test that fails without the fix.
- Do not write tests that only restate the code: asserting a constant,
  that a constructor sets fields, or that a mock was called.
- Tests run on all three platforms. Use temporary directories, never
  fixed paths, and never depend on test order or wall-clock timing.

## Releases

Releases are fully automated by
[release-plz](https://release-plz.dev) on `GITHUB_TOKEN` only. No
personal tokens and no registry secrets; the `release` skill explains
the pipeline. In short:

1. Every push to `main` refreshes a release PR owned by
   github-actions[bot], with the next version and changelog.
2. Merging it tags the version and creates the GitHub release.
3. That starts `release.yml`, which builds and attaches the assets:

| Platform | Asset |
|----------|-------|
| Linux, portable | `<app>-<arch>-linux.onelf` |
| Linux | `<app>-<arch>-linux.tar.xz` |
| macOS | `<app>-<arch>-macos.tar.xz` with an `.app` bundle |
| Windows | `<app>-x86_64-windows.zip` |

Linux and macOS archives are `.tar.xz`, Windows archives are `.zip`,
and the `.onelf` bundle is shipped as is. No checksum files are
published; every asset carries a build provenance attestation instead.

The onelf bundle uses the stipplefs payload. An egui app's bundle
carries Mesa, so it draws on hosts without a usable GL stack, musl
distributions included; NVIDIA's driver still comes from the host. Mesa
makes the bundle around 60 MB; do not drop it to save space. A smudge
app drawing with its CPU renderer needs no GL, so it turns `gl` and
`dri` off in `onelf.toml`; confirm with the `test-linux-bundle` skill.

Run the `test-linux-bundle` skill before merging any change that can
alter what the bundle loads: `onelf.toml`, a dependency that links or
opens a system library, an onelf upgrade, or a feature that reaches a
new part of the system such as audio, file dialogs or notifications.
The `onelf` skill covers inspecting and debugging a bundle.

Apps are not published to crates.io by default. When one should be,
publish it through crates.io trusted publishing, never with a token
stored in repository secrets.

## Docs

- The docs site lives in `docs/`, built with VitePress and bun, and
  deploys to GitHub Pages from `main`.
- The site is personalized for the app: its own palette, type and
  home page. Do not ship the stock VitePress look. The `app-docs` skill
  covers it.
- Update the docs in the same change as the behavior they describe.

## Icons

`assets/icon.svg` is the single source for every icon. Regenerate the
rasters, the Windows `.ico` and the docs favicons with
`scripts/icons.sh` after changing it. The `app-icon` skill covers the
design rules.

## Layout

```
.
|-- src/
|   |-- main.rs          entry point, window options
|   `-- app.rs           application state and root UI
|-- assets/
|   |-- icon.svg         icon source
|   |-- icon.ico         Windows icon, generated
|   `-- icons/           PNG sizes, generated
|-- packaging/
|   |-- linux/app.desktop
|   `-- macos/Info.plist
|-- docs/                VitePress site
|-- scripts/             shared, except bootstrap.sh in the template
|   |-- check.sh         every CI gate
|   |-- check-ascii.sh   the ASCII rule
|   |-- icons.sh         icon generation
|   |-- package.sh       release archives
|   |-- package-onelf.sh portable Linux bundle
|   `-- sync-guidelines.sh  refresh every shared file
|-- onelf.toml           onelf recipe
|-- .release-plz.toml
|-- .agents/skills/      shared and app-specific skills
|-- .claude/skills/      a symlink per skill, for Claude Code
`-- .github/workflows/   shared callers: ci, release-plz, release,
                         docs, sync-guidelines
```

## Skills

Procedures live in `.agents/skills/`. Claude Code only looks in
`.claude/skills/`, so each skill also has a symlink there, which
`scripts/sync-guidelines.sh` creates. These are shared by every app:

- `add-dependency` vets and adds a crate, or decides to inline it.
- `app-icon` designs the icon and regenerates every raster.
- `app-docs` personalizes the docs site.
- `release` explains and troubleshoots the release pipeline, including
  crates.io trusted publishing.
- `onelf` inspects and debugs the portable Linux bundle.
- `test-linux-bundle` smoke-runs a bundle on the hosts users have.
- `sync-guidelines` refreshes the shared guidelines and skills.

The template also carries `bootstrap-app`, which turns a fresh copy into
a new app and is removed once that is done. An app may add skills of its
own; give them names the shared ones do not use, since a sync replaces a
shared skill of the same name.
