# AGENTS.md

This repository holds the organization profile and the guidelines and
skills shared by every pkgforge-apps app. Read `agents/GUIDELINES.md`
first: its rules apply here too.

- `agents/` and `app/` are copied into every app. Keep them
  app-agnostic: no app names, and only paths from the shared app
  layout.
- The workflows in `app/.github/workflows/` call the reusable ones in
  `.github/workflows/` at `@__SHARED_REF__`, which the sync replaces
  with the commit it synced from. Keep that placeholder; never write a
  ref by hand.
- A reusable workflow change reaches an app only when that app merges
  its next sync pull request, so keep each one working with the
  callers apps already have.
- `agents/GUIDELINES.md` is inserted under an app's `# AGENTS.md`
  title, so it has no title of its own and its top headings are `##`.
  It must not contain the lines `<!-- BEGIN SHARED GUIDELINES` or
  `<!-- END SHARED GUIDELINES`, which mark where it goes.
- A skill is a directory under `agents/skills/` with a `SKILL.md` and
  any scripts it runs. Scripts are POSIX `sh` and pass
  `shellcheck -s sh`.
- ASCII only, in every file.
- Before landing a change, sync it into an app from this checkout and
  read the result:

  ```sh
  PKGFORGE_SHARED=$PWD sh ../<app>/scripts/sync-guidelines.sh
  ```
