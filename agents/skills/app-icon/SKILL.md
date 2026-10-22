---
name: app-icon
description: Design a pkgforge-apps app icon as a hand-written SVG and regenerate every raster, the Windows .ico and the docs favicons from it. Use when creating a new app's icon, changing it, or when the icons, favicon or .ico look wrong or stale.
---

# App icon

`assets/icon.svg` is the only source. Everything else is generated.

## Design rules

- Canvas `viewBox="0 0 1024 1024"`. The tile is a rounded square at
  `x=80 y=80 width=864 height=864 rx=196`, leaving the margin macOS
  expects and keeping the shape consistent across the organization.
- One idea, one glyph. The icon must read at 16 px: a bold silhouette,
  at most three or four shapes inside the tile, no text, no fine lines
  thinner than about 40 units.
- Each app gets its own palette. Use a two-stop linear gradient on the
  tile and one light glyph on top, or the inverse. Make sure the glyph
  has strong contrast against the tile in both light and dark
  surroundings.
- A subtle top sheen and a soft drop shadow under the glyph are the
  house style. Keep them subtle.
- Plain SVG only: paths, rects, circles, linear gradients. No filters,
  masks, embedded images or fonts, so every renderer draws it the same.
- ASCII only, like every file in the repository.
- When the full icon is too detailed for a browser tab, add a simplified
  `assets/favicon.svg`; the script prefers it for the favicon.

## Check it

Render previews outside the repository and look at them, at least at
512 and 32 px:

```sh
mkdir -p /tmp/icon-preview
resvg -w 512 assets/icon.svg /tmp/icon-preview/512.png
resvg -w 32 assets/icon.svg /tmp/icon-preview/32.png
```

Iterate until the 32 px render is still recognizable.

## Generate

```sh
scripts/icons.sh
```

Needs `resvg` (`cargo install resvg`). It writes:

- `assets/icons/{16..1024}.png`: window icon, hicolor theme icons for
  Linux, and the sources the release workflow turns into the macOS icns.
- `assets/icon.ico`: embedded into the Windows executable by `build.rs`.
- `docs/public/favicon.svg`, `logo.svg`, `apple-touch-icon.png`.

Commit the SVG and every generated file together. Then retune the docs
palette in `docs/.vitepress/theme/style.css` and the `accent` in
`docs/.vitepress/app.ts` to match the new icon.
