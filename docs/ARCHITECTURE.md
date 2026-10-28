# Architecture

Seaglass extends the stock Sailfish OS home screen (`lipstick-jolla-home-qt5`) without changing its files on
disk. A Patchmanager patch adds `Loader`s to eight stock QML files. Each `Loader` loads a file of our QML module,
which the package installs as root in `/usr/share/seaglass/qml/`. When our file does not load, that part
of the home screen stays stock.

## The hook

```
lipstick-jolla-home-qt5 (stock QML, unchanged on disk)
  └─ Patchmanager applies the series' hook (patchmanager/diffs/5.2.patch) in memory
       ├─ launcher/LauncherGrid.qml
       │    ├─ app grid       Loader → core/HomeController.qml          failed → the stock grid and drag
       │    ├─ folder icon    Loader → folders/FolderPreview.qml        failed → the stock item count
       │    ├─ widget folder  Loader → widgets/group/WidgetTile.qml     failed → the folder icon
       │    └─ app icon       Loader → badges/IconBadge.qml             failed → no badge
       ├─ launcher/LauncherFolder.qml
       │    ├─ open folder    Loader → folders/FolderMotion.qml         failed → the stock fade
       │    ├─ folder header  Loader → folders/FolderPreview.qml        failed → the stock item count
       │    └─ folder shapes  Loader → widgets/group/FolderTypeChooser.qml  failed → only the stock shapes
       ├─ main/EditableGridDelegate.qml   drawn positions for widget blocks (stock values without the controller)
       ├─ layers/LauncherLayer.qml
       │    └─ background     Loader → glass/LauncherWallpaper.qml     failed → the stock blurred background
       ├─ switcher/Switcher.qml
       │    └─ switcher       Loader → switcher/SwitcherController.qml  failed → the stock switcher
       ├─ switcher/SwitcherItem.qml
       │    ├─ cover          Loader → switcher/SwitcherChip.qml        failed → no chip
       │    └─ loading cover  Loader → animations/CoverLoading.qml      failed → the stock busy indicator
       ├─ compositor.qml
       │    └─ app layer      Loader → animations/AnimationController.qml  failed → the stock opening and closing
       └─ layers/StackLayer.qml   asks for an opening effect before its fade (stock without the controller)
```

- **A small hook, and our own module.** The hook adds `Loader`s. It changes stock behaviour only through what they
  loaded. For example, the item count hides once the preview is loaded. The widget blocks, their drawn positions
  and the drag's hit test exist only while `HomeController.qml` is loaded. Otherwise every changed value is the
  stock one. A missing or broken module gives the stock look, never a broken home screen.
- **Never patched blindly.** [hook/apply_hook.py](../hook/apply_hook.py) applies the hook by anchors. It stops when
  an anchor is missing or not unique, and it refuses an already hooked file. Its output is
  `patchmanager/diffs/SERIES.patch`, one per Sailfish OS series. `make check-hook` checks it against the phone's own
  files, `make check-hooks` against every version's, downloaded from Jolla.
- **Patchmanager does the patching.** Patchmanager 3 patches files as they are loaded; it does not change them
  on disk. It applies a patch only when it fits (`patch --dry-run`), and only on the Sailfish OS versions listed in
  `patch.json` (its strict version check).
- **Only root-owned QML runs in the home screen.** Lipstick runs with the `privileged` group, so the hook loads QML
  only from `/usr/share/seaglass`, which rpm installs. It never loads QML from the home directory.
- **Removal.** `rpm -e seaglass` deactivates the patch first. A hook left active without the package only
  loses our part. Folders shown as widgets stay ordinary folders, at their places in the app grid.

The stock home screen files are Jolla's (proprietary). They are never committed. `scripts/pull-base.sh` copies the
files the hook changes from the phone into `out/base/`, where the hook is generated and checked. It reads them with
`NO_PM_PRELOAD=1`, because with Patchmanager's preload every process on the phone sees the patched files.

### The hook contract

The `Loader` is the loaded item's parent, and it provides the data the item needs. For the folder preview, these
are:
- `folder`: the `LauncherFolderItem`. It has `itemCount` and `get(i).iconId`, and it is also a list model, so the
  icons follow apps being added, removed and reordered.
- `pressed`.
- `dropTarget`, on the app grid only.

The other entry points document their properties in their file headers.

## The QML module

`qml/` is installed as `/usr/share/seaglass/qml/`, with one folder per feature. A file sees the types of its
own folder. It imports any other folder it uses, by a relative path (`import "../glass"`). `tests/test_repo.py`
checks that every type and file used across folders is imported and exists.

| Folder | What |
|---|---|
| `core/` | `HomeController.qml`, the app grid's controller: layout, widgets, drag aiming, search, badges. `grid.js`, the layout engine. `motion.js`, state shared within the home screen (a `.pragma library`). `LauncherActions.qml`, which launches apps and opens folders and settings pages. |
| `folders/` | `FolderPreview.qml`, the mini icons on a folder. `FolderMotion.qml`, the open and close motions. |
| `glass/` | `GlassSource.qml`, the wallpaper texture, frame and material shared by every glass surface. `GlassPane.qml`, one glass surface. `LauncherWallpaper.qml`, the app grid's background. |
| `search/` | The search row, the sheet, a result tile, and `search.js` (matching, suggestions, A–Z sections). |
| `badges/` | `Badge.qml`, the drawing. `IconBadge.qml`, a badge on an icon. `BadgeSource.qml`, notifications counted per app. `NotificationPeek.qml`. |
| `switcher/` | `SwitcherController.qml` and its parts: chips, the card row, hints, the pinch and its morph layer, cover stills, recently closed apps. |
| `widgets/` | `SizeBar.qml`, the size control shared by both kinds of widget. |
| `widgets/group/` | Folders shown as widgets: `GroupWidget.qml` (the tile), `WidgetTile.qml` (the hook's wrapper), the folder type store, its chooser and its selector, `WidgetBadge.qml` (the folder-to-card toggle). |
| `widgets/data/` | Data widgets: `DataWidgets.qml` (the list in dconf), `store.js` (the kinds, and what a change does to the list), `DataWidget.qml` (a widget's block in the grid), `DataSources.qml` (the sources, loaded on demand), the gallery, and `faces.js`. |
| `widgets/data/<kind>/` | One folder per kind (`clock`, `status`, `player`, `event`, `weather`). Each has a `*Source.qml` that reads the data and a `*Face.qml` that draws it in every size, plus the face's parts. |
| `animations/` | The app animations ([ANIMATIONS.md](ANIMATIONS.md)): `AnimationController.qml` (opening and closing), `Effect.qml` (one style's shader for a moment), `Shards.qml`, the covers' `CoverLoading.qml` and `CoverClosing.qml`, `styles.js`, `shaders.js` and the shaders. |
| `settings/` | The settings: `SettingsHub.qml` (the first page), one page per feature, *What's new*, and one file per group of dconf keys (`GlassSettings.qml` and so on), which the home screen uses too. |

The page Patchmanager opens, `patchmanager/main.qml`, only holds `settings/SettingsHub.qml`, imported by its
installed URL. The pages import `glass/`, `badges/` and `core/motion.js` for their live previews, so a preview runs
the same code as the home screen.

### Settings

All settings are in dconf under `/apps/seaglass/`, and the home screen follows them live. Each group of keys
is one file in `qml/settings/`, so a key and its default are written once:

| Key | What |
|---|---|
| `folder_types` | folders shown as widgets |
| `motion/*` | folder motion |
| `glass/*` | the app grid's background and the glass |
| `search/*` | the search row, and the launch counts |
| `badges/*` | notification badges and the peek |
| `switcher/*` | the task switcher, and the recently closed apps |
| `widgets/*` | the data widgets' options, and `list`, the widgets on the grid |
| `debug` | the Debug log switch |
| `running`, `seenVersion`, `editHint` | the version the home screen runs, the version whose notes were read, the hint about the edit mode |

`defaults/*` is never written: *Reset settings* reads the defaults there, from a second copy of each group.

### The settings app

The first page starts with a status line. It checks, in order, that `patch.json` lists this Sailfish OS version,
that Patchmanager's preload line is in `/etc/ld.so.preload` (an OS update can drop it), that the patch is applied
(`isPatchApplied` on Patchmanager's D-Bus service), and that the home screen runs the installed version
(`HomeController.qml` writes the version it runs to `running`). It shows the first check that fails and what to do.
*Restart home screen* restarts `lipstick.service` through the session's systemd. The settings talk to Patchmanager
and systemd over D-Bus, not through Patchmanager's QML plugin, which hung a plain `qmlscene` in a test.

Below the status each feature has a row with what it is set to now, and a page of its own. The pulley menu has
*Reset settings* (every key a group lists in `keys` goes back to its default; the widgets, the folder types and the
launch counts stay), *Restart home screen* and *What's new*, which shows this version's section of `CHANGELOG.md`,
installed next to the QML.

*Back up*, on the About page, writes `~/Documents/seaglass-DATE.json`: every group's `keys`, the widget list and the
folder types, and with *Include usage* the launch counts and the recently closed apps. Qt 5.6's `XMLHttpRequest`
can still write a local file with PUT, so no helper is needed. *Restore* takes a file from the file picker. It
accepts only a Seaglass backup, and sets a value only when its type matches the setting's. The order of the apps
belongs to the launcher (`~/.config/lipstick/applications.menu`), and the backup leaves it alone.

### Qt 5.6

Lipstick on Sailfish OS 5.2 runs Qt 5.6. So the QML uses `import QtQuick 2.6` at most, and ES5 JavaScript only: no
arrow functions, `let`, `const` or template strings. qmllint in the tool image is Qt 5.15's, so
`tests/test_repo.py` checks the ES5 rule itself.

## Folder shapes

The 16 stock folder shapes (`icon-launcher-folder-01` … `16`) have a coloured rim around a dark inner area. They
are 128 px at the phone's 1.5 pixel ratio. A centred square of 70 % of the icon is opaque in every shape, and app
icons are round, so the preview uses that 70 % area:
- 2 × 2 icons at 30 % of the folder icon (38 px on the phone);
- 3 × 3 icons at 20 % (25 px).

## Repository layout

| Path | What |
|---|---|
| `qml/` | the QML module → `/usr/share/seaglass/qml/` |
| `patchmanager/` | the patch → `/usr/share/patchmanager/patches/seaglass/`: `patch.json`, the settings page `main.qml`, the list icons `main.svg` and `main-light.svg`; the hooks in `diffs/` (generated, one per series; `%post` copies the phone's as `unified_diff.patch`) and the versions they are for, `versions` |
| `icons/` | the colour icon (OpenRepos, README) |
| `hook/apply_hook.py` | the source of the hook: anchors in the stock QML → unified diff |
| `rpm/` | the package spec, and `build.sh`, which stages the tree and runs rpmbuild |
| `docker/Dockerfile` | the tool image: rpmbuild, GNU patch, qmllint, shellcheck, ImageMagick, rsvg-convert, Python-Markdown, bsdtar |
| `scripts/` | the scripts behind the make targets (they run on the computer and reach the phone over SSH) |
| `.github/workflows/` | CI (`ci.yml`), the release on a pushed tag (`release.yml`), the site (`pages.yml`) |
| `site/`, `scripts/site.py` | the GitHub Pages site: the landing page, and the docs rendered from this repository's Markdown |
| `harness/` | the development harness: scenes run with `qmlscene` on the phone (not packaged) |
| `tests/` | unit tests: the hook on stand-in files, the layout and search engines, the widget store, repository consistency; `qml-check/`, the QML check on older releases |
| `docs/` | how each feature works (`FOLDERS.md`, `GLASS.md`, `SEARCH.md`, `BADGES.md`, `SWITCHER.md`, `WIDGETS.md`), this file, and `DEVELOPMENT.md` |
| `docs/images/` | the screenshots (`make screenshots`) |
| `VERSION` | the package version (also in `patch.json`) |
