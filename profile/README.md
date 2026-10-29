<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/pkgforge-apps/.github/main/profile/assets/pkgforge-apps-lockup-dark.svg">
    <img src="https://raw.githubusercontent.com/pkgforge-apps/.github/main/profile/assets/pkgforge-apps-lockup-light.svg" alt="pkgforge-apps" width="515">
  </picture>
</p>

---

## About

pkgforge-apps is a sub-organization of [PkgForge](https://github.com/pkgforge).
It builds lightweight native desktop apps: original ones, and
alternatives to heavyweight apps, Electron apps in particular.

Every app here is a single Rust binary drawn with
[egui](https://github.com/emilk/egui) or
[smudge](https://github.com/QaidVoid/smudge). It starts in a blink, stays
small in memory, and runs the same on Linux, macOS and Windows.

## Getting an app

Each release ships:

| Platform | File |
|----------|------|
| Linux, portable | `<app>-<arch>-linux.onelf`, one file that runs on any distribution |
| Linux, AppImage | `<app>-anylinux-<arch>.AppImage`, from apps that also ship one |
| Linux | `<app>-<arch>-linux.tar.xz` |
| macOS | `<app>-<arch>-macos.dmg` |
| Windows | `<app>-x86_64-windows.exe`, nothing to install |

The portable Linux builds are [onelf](https://github.com/QaidVoid/onelf)
bundles. They also install through [soar](https://github.com/pkgforge/soar).
Some apps also ship an [Anylinux AppImage](https://github.com/pkgforge-dev/Anylinux-AppImages),
for AppImage managers, which updates itself.

## Contributing

Every repository starts from
[app-template](https://github.com/pkgforge-apps/app-template) and follows
the [shared guidelines](https://github.com/pkgforge-apps/.github/blob/main/agents/GUIDELINES.md):
the same layout, checks, release pipeline and conventions everywhere.
