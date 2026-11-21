# Development

Seaglass is built and checked from a Linux or macOS computer. It needs no Sailfish SDK: the package is noarch
QML. The scripts behind the make targets (`scripts/`) reach the phone over SSH. `make help` lists the targets.

## Requirements

- **Docker.** It runs the tool image (`docker/Dockerfile`), which has rpmbuild, GNU patch, qmllint for Qt 5,
  shellcheck and ImageMagick. The image is built on first use, and again only when the Dockerfile changes.
- **Python 3**, for the hook generator and the tests.
- **Node.js** (optional): `tests/test_grid.py`, `tests/test_search.py` and `tests/test_store.py` run the layout and
  search engines and the widget store with Node, and skip without it.
- **SSH key login to the phone as the device user** (developer mode). The scripts use the host `jolla`; set
  `SEAGLASS_SSH` to another `~/.ssh/config` alias. They share one connection (`ControlMaster`, socket `/tmp/seaglass-*`,
  kept for ten minutes).
- **Patchmanager 3.2 on the phone.**
- **7-Zip** (`7zz` or `7z`), for `make qml-check` only: it unpacks the Sailfish SDK's targets.

## Build and install

```bash
make test         # unit tests: the hook on stand-in files, layout, search, widget store, repository consistency
make lint         # qmllint (Qt 5), shellcheck, actionlint, the Python byte compiler, the shaders (glslang)
make rpm          # out/rpm/seaglass-VERSION-1.noarch.rpm
make deploy       # copy it to the phone (~/seaglass) and check it with rpm -U --test
make install      # devel-su rpm -U on the phone (asks for the developer-mode password)
make remove       # devel-su rpm -e seaglass
```

`rpm/build.sh` also runs outside Docker, on any Linux host with rpmbuild: `SRC=. OUT=out/rpm sh rpm/build.sh`.

`make status` checks on the phone, read-only, everything the home screen needs: the package, Patchmanager's
preload, the active patch, the patched files, a home screen restart after the patch, and the OS version.
`make journal` reads the home screen's QML messages of this boot into `out/journal.txt`. It asks for the
developer-mode password, and it shows our lines only while *Debug log* is on.

## The hook

`hook/apply_hook.py` makes the hook from the stock home screen files. It edits them by anchors, and fails on a
missing or non-unique anchor. There is one hook per Sailfish OS series, in `patchmanager/diffs/5.2.patch` and so on.
The package carries all of them, and its `%post` puts the phone's series in place as `unified_diff.patch`.
`patchmanager/versions` lists the versions they are made for: *release* ones are tested on a phone and listed in
`patch.json`, *preview* ones are only checked without a phone ([below](#older-sailfish-os-versions)).

```bash
make hook                    # from the phone's stock files (out/base/); the version becomes a release one
make hook VERSION=5.1.0.11   # from that release's, downloaded from Jolla into out/compat/ (no phone); a preview
make check-hook              # the hook against the phone's files: exact match, GNU patch without fuzz, qmllint
make check-hooks             # the same for every version in patchmanager/versions, downloaded (no phone)
make qml-check               # our QML compiled with the 5.1 and 5.0 SDK targets' Qt and Silica (Docker, ~200 MB each)
make rpm CHANNEL=preview     # the testers' package: patch.json lists the preview versions too
```

The downloaded files are Jolla's: they stay in `out/`, which is never committed. After a Sailfish OS update, run
`make check-hook`. If the hook no longer fits, run `make hook`, which fails loudly if an anchor moved. Then run
`make test lint check-hooks rpm`.

`tests/test_hook.py` runs the hook on stand-in files, and on the real stock files when `out/base/current` or
`out/compat/` has them.

## Older Sailfish OS versions

Seaglass is tested on a Jolla Phone with Sailfish OS 5.2. Sony Xperias and the Jolla C2 are still on 5.1, and some
phones on 5.0. Their home screen files have every anchor the hook needs, but `LauncherGrid.qml` and `Switcher.qml`
differ enough around them (mostly the Android app policy that 5.2 added to the icons) that each series gets its own
diff. Two checks cover those versions without a phone, here and in CI:
- `make check-hooks` downloads `lipstick-jolla-home-qt5` of every version in `patchmanager/versions` from Jolla's
  release repository (`scripts/stock.py`, checked against the repository's SHA-256), and checks each series' diff
  against those files as `make check-hook` does against the phone's.
- `make qml-check` compiles every file of `qml/` and the settings page with an older release's own Qt and Silica. It
  imports the Sailfish SDK's build targets of 5.1.0.11 and 5.0.0.62 (about 200 MB each, from releases.sailfishos.org)
  as Docker images, adds `qmlscene` and the modules the home screen uses from the release's repository, and creates a
  component of each file without instantiating it. Three modules get stubs (`tests/qml-check/stubs/`):
  `com.jolla.lipstick` and `com.jolla.coveractions`, which only the running home screen registers, and
  `Sailfish.Weather`, which comes with the Weather app from the Store. `qmlscene` aborts at the end, because it has
  no OpenGL for its window, so the script reads the check's own lines.

| | 5.2.0.18 to 5.2.0.22 | 5.1.0.11 | 5.0.0.78 |
|---|---|---|---|
| the hook checked against the stock files | yes | yes | yes |
| our QML compiled with that release's Qt and Silica | no (no 5.2 target yet) | yes | yes |
| run on a phone | yes | no | no |

In CI the `sailfish` job of `.github/workflows/ci.yml` has a matrix leg for each version, with its SDK target:
`make check-hook VERSION=…` and `make qml-check TARGET=…`. Each leg is a check run named *Sailfish OS VERSION*, and
the README's Compatibility table shows its status with Shields.io's check-runs badge, filtered by that name. A new
version needs its line in `patchmanager/versions`, its matrix leg and its row; `tests/test_repo.py` checks that they
agree.

So `patch.json` lists the 5.2 versions only. Each release also carries a testers' package for 5.1 and 5.0
(`-0.preview1`, built with `CHANNEL=preview`), whose `patch.json` lists those versions too. A version moves from
*preview* to *release* in `patchmanager/versions` once it has run on such a phone.

## The harness

The harness ([harness/harness.qml](../harness/harness.qml), `scripts/harness.sh`) runs this tree's QML with
`qmlscene` on the phone, as the device user. It never touches the home screen:
- It reads a copy of `~/.config/lipstick` (`XDG_CONFIG_HOME`), so its launcher model can never write the real
  `applications.menu`. The script compares the menu's checksum before and after.
- It grabs its own window. Lipstick's screenshot call needs the `privileged` group.
- Its scenes draw a stock ambience picture as the wallpaper, never the phone's own, which may be private. Data
  widgets show sample data, never the phone's events, places or tracks.

The phone must be unlocked, with the display on: QML timers and the window grab need a visible window.

```bash
make harness                                          # the folder previews → out/shots/harness.png
scripts/harness.sh [--stack] --scene "NAME [ARGUMENT]" [--shot NAME [--grab SECS] | --frames NAME] [--picture PATH] [--wait SECS] [--until TEXT] [--env NAME=VALUE] [--keep] [--own-apps]
```

`--frames` records the frames into `out/frames/NAME/` and a GIF into `out/shots/`; it waits for the scene's run to end.
`--until` waits for a line in the harness's log, up to `--wait` seconds, and keeps the display from blanking meanwhile.
`--env` passes an environment variable to `qmlscene`, such as `QSG_INFO=1` or
`QT_LOGGING_RULES=qt.scenegraph.time.*=true`.
`--stack` runs [harness/stack.qml](../harness/stack.qml) instead of `harness.qml`: a real `ApplicationWindow` and
`PageStack`, for what only a page push shows, with scenes of its own (below). There `--shot` grabs at the end of the
scene's first rest unless `--grab` says when, and `--frames` does not apply.
`--slow-animations` runs qmlscene's slow motion (every animation and Timer five times slower), so that the film
scene's grabs keep up. `--grab` takes the shot that many seconds after the scene starts (2.5 by
default), for a moment of a scene's timeline. The harness shows only the stock apps, in made-up folders (*Media*,
*Office*, *Tools*; `harness/public-launcher.sh`), so that what it draws can be shared; `--own-apps` shows the
phone's own apps and folders instead. The
scenes:

| Scene | What |
|---|---|
| `folders` | the default: the folders with the preview and with the stock count, folders with 2 to 24 apps, the pressed and drop states |
| `selector "FOLDER=panel"` | an open folder's shape selector with the home screen types |
| `controller "FOLDER=card,…"` | `HomeController.qml` on a stand-in grid: the layout, the hit test, a rename, in the harness's copy of the menu |
| `layout "normal\|edit FOLDER=card@5,… drag=… drop=…"` | widgets among the icons, the edit mode, a lifted widget, an app over a widget |
| `motion "zoom\|spring\|reveal\|slide [card] from=FOLDER slow=10"` | a folder opening and closing, slowed down for `--frames` |
| `glass "[look=glass\|clear\|stock] [photo=AMBIENCE] …"` | the app grid on glass, with a glass folder and card: pull up, page and back; `photo=ruska` puts a stock ambience's picture under the grid; the other words are in [GlassScene.qml](../harness/GlassScene.qml) |
| `probe "zoom\|anchor\|shift [frost]"` | two glass panes; at 1.5 s the glass zooms, moves its anchor or shifts: grab at 1 and 2.5 s, the picture must have moved |
| `search "pos=bottom\|top"` | the search row and sheet: A–Z, the rail, typing |
| `badges` | badges in each style, a folder's sum, a sketch of the peek |
| `switcher` | the task switcher with made-up covers, grid or cards |
| `widgets "normal\|edit\|gallery\|ghost [face=analogue] [glass] [idle\|empty\|none\|stale…] clock=card@0,…"` | data widgets with sample data; the states and setting words are in [WidgetsScene.qml](../harness/WidgetsScene.qml) |
| `touch` | data widgets driven by mouse events (QtTest's `TestEvent`), each check logged |
| `film "clip=move\|add\|resize"` | the widget clips for the README: the touch scene's controller and events, dressed as the home screen; run with `--slow-animations --frames` |
| `animations "STYLE open\|close\|load [PROGRESS]"\|"check"` | one style's effect for a moment on a made-up app, running or held at a progress; `check` draws every shader once and logs the ones that loaded |
| `reel "STYLE,STYLE,… [slow=3]"` | styles one after the other on the app grid: Notes opens from its icon and closes, with the style's name; for `--frames` |
| `settings "[PAGE] [scheme=light] [SCROLL]"` | the settings: the first page, or one of the others (`Glass`, `Widgets`, `Animations`, `AnimationViewer`, …), scrolled down so many pixels, with the live previews; `scheme=light` draws the page dark on light over a light background, which comes near a light ambience without changing one |
| `bench "cost\|play\|compile\|page\|quiet\|animators [OPTION=VALUE …]"` | what the animations cost on this phone in ms, logged: each effect held at a few progress values, each played from an idle GPU, a shader's first draw, the settings page; the modes are below, the method and options in [BenchScene.qml](../harness/BenchScene.qml); run with `--until "bench done"` |

`FOLDER` is the title of a folder: *Media*, *Office* or *Tools*, or one of the phone's with `--own-apps`.

With `--stack`, the scenes log `harness: stack step NAME begin` and `end` around each step and end with
`harness: stack done`; `orientation=landscape` in either turns the window:

| Scene | What |
|---|---|
| `push "[page=stripped] [rest=8] [from=hub] [hubrest=3]"` | the default: the Animations page pushed with the stock picture, a rest, a pop, and a second push in the same process; `page=stripped` pushes a page with only a header instead, as the measure for the real one; `from=hub` pushes the settings' first page first, leaves it `hubrest` seconds at rest and makes each push of the Animations page from it, as a tap on its row does, after a line `hub page compiled` (or `compiling`, or `not requested` before the first page has started its compile, 1 s after it is made); with `page=stripped` the stripped page is pushed over it, with no such line |
| `viewer "STYLE MOMENT [rest=8]"` | the Animations page pushed and its sheet made, then the viewer pushed on that style and moment (`ember open` by default) as a tap on a frame pushes it: its first run, a rest, a tap on the stage, a swipe to the next style (mouse events, a move each frame; the release logs `drag released after N moves in M ms`), a rest, a pop; after the first run, a line on how the stage's and the strip's made-up home screens grabbed their pictures, as `bench page` logs it; after the push and after the swipe, how the line about the style came out in the phone's font, `about STYLE MOMENT lines N whole` (or `cut`, where it needs more than its two lines) |

The bench modes, the first word of its argument:

- `cost`: every style and moment held at a few progress values, drawn K times a frame until the frames come far
  apart, so that the slope gives what one copy costs. Options: `size=100,55` (percent of the screen's width),
  `at=0.15,0.5,0.85`, `only=ember-close,blit`, `ks=1,2,4`, `kmax=160`, `layered=1`.
- `play`: every style and moment once at its length from an idle GPU, each frame counted, played as the home screen
  plays it: on the render thread, through `Effect.play()` (a loading through `runClock()`, for 3 s) and
  `Shards.play()`. Options: `size`, `only`, `rounds=3`, `driver=gui` (`progress` and `time` set from the GUI thread
  by an animation instead, for comparison).
- `compile`: the longest frame when each shader first draws, twice over. Options: `size`, `only`.
- `page`: the Animations page, by steps: the spare time over an empty window (`empty`), the sheet made (`build`), at
  rest at the top and the bottom (`rest`), flicked (`flick`), the spare time over it (`spare`), a page that keeps its
  sheet in a file (`saved`), a second one that must show it (`cached`), and last the viewer's stage (`viewer`): every
  style and moment as the viewer plays it, three rounds each, an opening or closing at its size in `stills.js` and
  then at the next larger size while it passes, or the next smaller while it fails, so that the log names the largest
  that passes. The viewer step takes the longest, 7 to 10 minutes by the moments' lengths alone, so give `--wait`
  room for it. Options: `steps=` (any of them), `ks=` (the spare time's blits), `rest=10`, `flick=1` (flicked while
  the sheet is made), `tick=0` (the scene's own tick stopped while the sheet is made, as in the Settings app, where
  only the page's animations ask for frames; any running animation keeps every Timer to frames, so this is the build
  as it is there, its frames read from the frame log), `flatten=0` (the frames stay the sheet, with no picture); for
  `viewer`, `rounds=3`, `only=ember-open,…`, `speed=2` (0 relaxed, 1 normal, 2 quick), `stage=WIDTH` (in pixels, in
  a phone's shape; by default the viewer page's own stage in portrait, from a page made and dropped at once, which the
  step logs as `viewer stage WxH from the viewer page (made in N ms)`) and `rungs=table` (each moment only at its size
  in `stills.js`) or `rungs=1,0.8` (at those sizes). The mode ends with a line for each check it ran, `check NAME: what
  it saw | limit: … | passes`, `fails`, or `-` where the bench cannot tell, from its own frame intervals; what the
  frame log shows is read with `scripts/bench-frames.py` below. After the build it logs how the made-up home screen
  the stills are drawn from grabbed its pictures: `page kit shot once its pictures came`, or `page kit gave up waiting
  for` what was still loading after 1.5 s; the viewer step logs its own as `viewer kit …`.
- `quiet`: nothing drawn and the scene's own tick stopped, as at the page's rest: what is rendered anyway. Option:
  `rest=10`.
- `animators`: a moment on the render thread through a 400 ms block of the GUI thread, how often `ended` comes, a
  split moment's grains, effects that go while they run, and how long an `Effect` takes to make: with a shader, without
  one, and for a split closing. Options: `split=dust` (the split closing it grabs and times: `dust` or `frost`),
  `back=contour` (the closing a window comes back from; `dust` or `frost` bring their grains pass back with it).

`salt=1`, in any mode, makes every shader's text new to Qt's program store, so that its first draw is a cold compile.
The store stays in `$XDG_RUNTIME_DIR` until the phone restarts and grows with each salted run, so use it sparingly.

`scripts/bench-frames.py` reads what a run's frames did from its log, step by step: the frames rendered and per
second, how long the first one took, the longest time between two and how many were over 16.7 ms, the mean sync,
render and swap, the GUI thread's animations per frame, and each shader compile. It also counts the lines no log
should have: "Problematic Vertex shader", "QOpenGLShader::compile" and a texture input with nothing to read. The run
needs the scene graph's timing in its log:

```bash
mkdir -p out
scripts/harness.sh --scene "bench play" --wait 600 --until "bench done" \
    --env 'QT_MESSAGE_PATTERN=%{time process} %{category} %{message}' \
    --env 'QT_LOGGING_RULES=qt.scenegraph.time.renderloop=true;qt.scenegraph.time.compilation=true' \
    > out/bench-play.log 2>&1
python3 -I scripts/bench-frames.py out/bench-play.log
```

## Screenshots and icons

```bash
make screenshots              # the public shot list → docs/images/ (540 px JPEGs, 360 px animated WebPs)
scripts/screenshots.sh search # only some of them
make icons                    # icons/seaglass.svg → out/icons/seaglass-200.png (the release's icon)
```

The screenshots come from the harness in its public mode: the stock apps in made-up folders, a stock ambience
picture and sample data. None may show a phone's own wallpaper, apps, notifications, events or places. The shot list
is in `scripts/screenshots.sh`. Look through every image before committing it.

The colour icon (`icons/seaglass.svg`) and the Patchmanager glyphs draw the same three shapes: a glass card
with a clock and a line of text, an app tile and a plus. Patchmanager looks for `main.svg` or `main.png` next to
`patch.json`, and for `main-light.*` under a light ambience. The phone has Qt's SVG plugin, so the glyphs
(`patchmanager/main.svg`, white, and `main-light.svg`, black) are installed as they are.

## The site

`make site` builds the GitHub Pages site into `out/site/` with `scripts/site.py`:
- the landing page, from `site/index.html`: a chapter per feature, whose phone shows the moment chosen in its list
  (`site/assets/site.js`; without scripts every moment has its own phone), the settings' pages, the install steps
  and the support link. The version, its day from the changelog and the Sailfish OS versions are filled in;
- every Markdown doc as a page with a sidebar, with the links between the docs pointing at their pages;
- the images, the icon, and the picture that link previews show (`icons/social.svg`, rendered by
  `scripts/social.sh`).

The font, Albert Sans, is served from `site/assets/fonts/`, so the site loads nothing from other hosts. The build
fails on a broken link. To look at it, serve it locally: `python3 -m http.server -d out/site`.

## Rules for the QML

- **Qt 5.6.** Use `import QtQuick 2.6` at most, and ES5 JavaScript only. `tests/test_repo.py` checks both.
- **One folder per feature.** Import other folders by relative path. `tests/test_repo.py` checks that every type
  and file used across folders is imported and exists. See [ARCHITECTURE.md](ARCHITECTURE.md).
- **Nothing in the journal without Debug.** Log through `debugLog` or under the `debug` setting. Lipstick's
  console goes to the system journal.
- **No property named like an id of its file.** In a delegate, the delegate's property wins over the file's id.

## Continuous integration

GitHub Actions runs the same make targets as a development machine, on `ubuntu-24.04`:
- **`ci.yml`**, on every push to a branch and every pull request: `make test`, `make lint`, `make rpm` and
  `make site`, with the package kept as the run's artifact. Two more jobs cover the older Sailfish OS versions:
  `make check-hooks` and `make qml-check`. The SDK targets are cached between runs.
- **`release.yml`**, on a pushed tag `vX.Y.Z`: `make test` and `make lint`, then `scripts/release.sh "$TAG"
  --publish`. It can also be run by hand (*Actions → release → Run workflow*) for an existing tag, which replaces
  that release's notes and assets.
- **`pages.yml`**, on a push to `main` that changes the site, the docs or the images: `make site`, then GitHub
  Pages publishes `out/site/`. It runs once GitHub Pages is on, with *GitHub Actions* as its source, and the
  repository variable `PAGES_ENABLED` is `true`. Until then it is skipped.
- **Dependabot** opens a pull request when one of the actions has a new version.

What needs a phone stays on the development machine: `make check-hook` (the stock files are Jolla's, and never
committed), the harness and the screenshots. `make lint` also checks the workflows, with actionlint.

## Releasing

1. Bump `VERSION` and `patch.json`'s `version`. Add the version to `CHANGELOG.md` (`## X.Y.Z (DATE)`, written for
   users: it becomes the release notes) and to the spec's `%changelog`. `tests/test_repo.py` checks that they agree.
2. Run `make test lint check-hook rpm`, then test the package on the phone. `make release` assembles the release
   in `out/release/vX.Y.Z/` for a look: the package, the 200 px icon, `SHA256SUMS` and `notes.md`.
3. Commit, then tag the version with your signature and push it:

   ```bash
   git tag -s vX.Y.Z -m "seaglass X.Y.Z: …"
   git push origin main vX.Y.Z
   ```

   The release workflow builds and checks the tagged tree, and publishes *Seaglass X.Y.Z*. It creates a draft
   first, and publishes it once every asset is up. `scripts/release.sh` refuses a tag that is not `VERSION`'s, a
   version missing from either changelog, and a tree that is not the tag's. When `patchmanager/versions` has
   preview versions, the release also carries the testers' package, with a paragraph about it in the notes.

## Troubleshooting the computer

A Mac that has been up for a very long time can run out of local ports. TIME_WAIT sockets then never expire, and
new SSH connections fail with "Can't assign requested address" until the Mac restarts. Until then, open the shared
connection from a source port outside the exhausted range, and the scripts use it:

```bash
ssh -o ControlMaster=yes -o ControlPath=/tmp/seaglass-%C -o ControlPersist=3600 -o ProxyCommand="nc -p 40361 %h %p" -fN jolla
```
