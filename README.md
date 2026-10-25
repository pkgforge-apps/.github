# pkgforge-apps/.github

Organization-wide files for [pkgforge-apps](https://github.com/pkgforge-apps).

```
.
|-- profile/README.md          the organization's GitHub profile
|-- agents/
|   |-- GUIDELINES.md          the shared part of every app's AGENTS.md
|   `-- skills/<name>/         skills every app carries
|-- app/                       files every app carries at the same path:
|   |-- scripts/               check, package, icons, sync
|   `-- .github/workflows/     callers of the workflows below
`-- .github/workflows/
    |-- app-ci.yml             lint, tests, smoke run, docs build
    |-- app-release-plz.yml    release PR, tag and GitHub release
    |-- app-release.yml        archives, onelf bundles and opt-in
    |                          AppImages for a tag
    |-- app-docs.yml           docs site to GitHub Pages
    `-- app-sync-guidelines.yml  the weekly sync pull request
```

Every app copies `agents/` and `app/` with its
`scripts/sync-guidelines.sh`, which also pins the copied workflows to
the commit it synced from. A weekly workflow in each app runs it and
opens a pull request when something changed, so a change here reaches
every app through those pull requests. The `sync-guidelines` skill
describes the process.
