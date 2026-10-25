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
    `-- sync-apps.yml          runs here: the sync pull request in
                               every app
```

Every app copies `agents/` and `app/` with its
`scripts/sync-guidelines.sh`, which also pins the copied workflows to
the commit it synced from. A push here that changes either starts
`sync-apps`, which runs that script in every app against the new commit
and opens a pull request wherever something changed. It acts as the
`pkgforge-apps-bot` GitHub App, whose key is kept only in this
repository: a sync rewrites workflow files, which `GITHUB_TOKEN` cannot
push, and the pull requests the bot opens start the apps' CI. The
`sync-guidelines` skill describes the process.
