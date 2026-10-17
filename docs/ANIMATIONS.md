# Animations

Sailfish OS opens an app with a fade, shows a busy indicator on its cover while it starts, and closes it with a slide
and a fade. Seaglass adds styles for these three moments, from calm ones made of the ambience's glass, water and
light to loud ones that burn, shatter or swallow the app. They are off by default and are set up, with a live
preview, on a new *Animations* page of the settings.

This note is the design. Once built, it becomes the feature's documentation, like [GLASS.md](GLASS.md).

## The moments

- **Opening.** The app's window appears. Today: a 150 ms pause until the window is drawn, then a 300 ms fade.
- **Loading.** An app that is not running is started. Today: the app grid closes, the switcher gets a new cover with
  a busy indicator on it, and the app opens from there once its window is drawn.
- **Closing.** A swipe down from the top edge closes the app. Today: the window follows the finger, and once let
  go it slides on and fades out in up to 300 ms. Closing a cover in the switcher (the × or *Close all*) fades it
  and drops it a little in 200 ms.

An app opens from where it was tapped: from its icon in the app grid when it was running already, from its cover in
the switcher when that was tapped, and from its new cover after loading. Anything else (a notification, a link,
another app) opens it from the middle of the screen. Closing starts where the finger let go.

Going home with a swipe from the side is not one of the moments: the window follows the finger into the switcher,
and an effect there would read as closing the app. It keeps the stock motion.

## The styles

Ten styles: nine in three groups, and the stock one. Durations are at the normal speed.

| Style | Opening | Loading | Closing |
|---|---|---|---|
| **Stock** | Fades in, 300 ms | A busy indicator on the new cover | Slides on and fades out, 300 ms |
| *Sailfish: calm, made of glass, water and light* | | | |
| **Seaglass** | Rises from the icon as frosted glass in the ambience's colour and clears as it lands, with a slight settle, 480 ms | A glass cover in the ambience's colour; a glint crosses it and the icon breathes | Frosts over, rounds into a pebble and sinks; a ring spreads where it went in, 460 ms |
| **Tide** | A drop falls on the icon and the app spreads in its ripple, the edge refracting, 650 ms | Water rises in the cover over the icon, with caustics and bubbles | A wave washes it away from the bottom, with foam and spray, 720 ms |
| **Northern lights** | Curtains of aurora sweep down and leave the app behind them, 780 ms | An aurora over a night sky in the cover | Melts upward into rays of light that rise and fade, 850 ms |
| *Elements: fire, lightning and ice* | | | |
| **Ember** | A ring of fire spreads from the icon, sparks flying ahead of it, 620 ms | The cover smoulders: coals, low flames, rising sparks | Burns away from the bottom up: charring, a glowing edge, flames and heat haze, 880 ms |
| **Volt** | Lightning strikes the icon, the screen flashes, and an electric ring opens the app, 620 ms | Arcs run around the cover's edge, and now and then a bolt strikes the icon | Arcs crawl over the window, then it switches off like an old TV: a line, a dot, a spark, 700 ms |
| **Frost** | The screen starts frozen, and the ice melts from the icon outward, 700 ms | Frost grows over the cover from its edges and thaws again | Freezes from the edges, cracks, and falls apart as snow, 950 ms |
| *Extreme: loud on purpose* | | | |
| **Shatter** | Shards fly in and fit together; the seams glow and vanish, 720 ms | Cracks run through the cover and fill with gold (kintsugi) | Breaks where the finger let go; the shards fall, turning and catching the light, 1000 ms |
| **Singularity** | The app bursts out of a white hole at the icon, 660 ms | A small black hole spins in the cover, bending the icon around it | Pulled into a black hole with a glowing disk, which then winks out, 950 ms |
| **Dust** | Sand blows in and settles into the app, 800 ms | Sand pours through the cover into a heap | Crumbles into dust that the wind takes, 1050 ms |

Fire, water, ice and light have their natural colours. With *Ambience colours* on they take the ambience's
highlight colour instead: a blue ambience burns blue. Seaglass is always in the ambience's colour.

## The settings page

*Settings → Patchmanager → Seaglass → Animations*, a new row on the status page between *Task switcher* and
*Widgets*, with the chosen style as its summary ("Off" when off).

- **Preview.** A small home screen over the ambience's picture, as on the *Glass* page: an app opens, closes,
  loads and opens again with the chosen style, over and over. Three buttons under it play one moment at a time:
  *Open*, *Loading*, *Close*. The preview uses the same effect files as the home screen, on a made-up app and
  stock icons.
- **App animations.** On or off. Off is the stock behaviour.
- **Style.** The ten styles as tiles, three to a row under their group's name, each tile showing its loading
  effect live. A tap picks the style for all three moments and plays it in the preview.
- **Surprise me.** A different style each time an app opens, loads or closes (never *Stock*).
- **Moments.** *Opening*, *Loading* and *Closing*, each *Same as style* (the default), *Stock* or any style. One can
  keep the calm opening of *Seaglass* and close with *Ember*.
- **Speed.** *Relaxed* (×1.35), *Normal* or *Quick* (×0.72).
- **Ambience colours.** As above.
- **Covers too.** Closing a cover in the switcher, or all of them, plays the closing effect on the covers,
  staggered by 70 ms. Off, covers close the stock way.

The settings are in dconf under `/apps/seaglass/animations`, and the home screen follows them live:

| Setting | Key | Default | Values |
|---|---|---|---|
| App animations | `enabled` | false | |
| Style | `style` | `seaglass` | `seaglass`, `tide`, `aurora`, `ember`, `volt`, `frost`, `shatter`, `singularity`, `dust`, `stock` |
| Opening, Loading, Closing | `open`, `loading`, `close` | `""` (same as style) | `""`, `stock` or a style |
| Surprise me | `surprise` | false | |
| Speed | `speed` | 1 | 0 relaxed, 1 normal, 2 quick |
| Ambience colours | `ambience` | false | |
| Covers too | `covers` | true | |

Reset, backup and restore cover the group like the others (an `AnimationSettings.qml` with its keys list).

## How it works

### Rules

- **Sailfish is never kept waiting.** The window is shown, focused and closed at the stock moment. The effect plays
  on a copy of it, above or in place of the stock layer, and touch goes to the app as soon as the stock would let it.
- **One shader per effect.** Each effect is a `ShaderEffect` with one fragment shader (GLSL ES 1.00, as Qt 5.6
  needs) and the same inputs: the layer as a texture, a 256 × 256 noise tile, `progress` from 0 to 1, `time`, the
  origin point and rectangle, the aspect ratio, the size in pixels, the ambience's highlight colour and whether to
  use it. Shatter is the one exception (see below).
- **Stock when anything fails.** No controller, a shader that does not compile, a style that does not load: the
  stock fade, indicator and slide run as before. The hook changes stock values only through what our file returns.

### The hook

Two new stock files and two that are hooked already:

```
compositor.qml
  └─ transitions    Loader → animations/AnimationController.qml    failed → stock opening and closing
       placed right after the app layer, under the dialog and alarm layers;
       appLayerItem gets `seaglassTransitions: <the loaded item>`
layers/StackLayer.qml
  ├─ property QtObject seaglassTransitions: null                    (set only on the app layer)
  ├─ showAnimation: before the FadeAnimator, a ScriptAction asks seaglassTransitions.opening(layer);
  │                 when it takes over, the fade's duration is 0 (the layer is shown at once, the effect hides it)
  └─ transitioning: also true while the effect plays, so lipstick keeps drawing the home screen under it
switcher/Switcher.qml       SwitcherController.qml learns the launching cover and taps on covers (no new lines)
switcher/SwitcherItem.qml
  ├─ loading        Loader → animations/CoverLoading.qml           failed → the stock busy indicator
  │                 the BusyIndicator runs only while that Loader has no item
  └─ close()        first tells seaglassSwitcher.item.coverClosing(wrapper)
```

`apply_hook.py` gets the anchors for both new files, and `make check-hooks` checks them on every Sailfish OS
version in `patchmanager/versions`. The architecture tree in [ARCHITECTURE.md](ARCHITECTURE.md) gains the two files.

### Opening

`StackLayer`'s show animation waits 150 ms, then until the window is mapped, then fades the layer in over 300 ms.
The hook adds a step before the fade that calls `AnimationController.opening(layer)`; it runs only on the pass that
fades (the stock restarts the animation while the window is not mapped yet, with `retries` above 0). The controller:

1. picks the style for *Opening*, or answers `false` (off, stock, the startup wizard, the lock screen camera, an
   app shown over the lock screen, a display about to turn off);
2. takes the newest origin from `motion.js` (written by HomeController for an icon, SwitcherController for a
   cover, within the last 3 s; else the middle of the screen) and maps it into the app layer's coordinates, so a
   landscape app opens from the right place too;
3. puts a live `ShaderEffectSource` on the app layer (`hideSource: true`, so the stock layer is not drawn twice)
   under the effect in its overlay, and runs `progress` from 0 to 1;
4. lets the stock layer show again when done.

The fade's duration becomes 0, so the layer's opacity is 1 at once and the effect alone decides what shows. While
the effect plays, the hook keeps the layer `transitioning`; otherwise lipstick sees an opaque app layer and stops
drawing the home screen under the half-open app.

### Loading

`Switcher.activateWindowFor` makes the launching cover (`launching: true`) and goes to the switcher. In each cover
a `Loader` holds `CoverLoading.qml` while the cover is launching and the style for *Loading* is not *Stock*. It
draws the style's loading shader over the cover's area, with the app's icon (`launcherItem.icon`) as its texture
and `time` running. The stock busy indicator stays off while it is there. When the window is mapped the cover stops
launching, the loading effect fades out in 150 ms, and the opening effect starts from this cover's rectangle.

### Closing

The controller listens to the app layer's `peekFilter`: `gestureTriggered` with `topActive` is a committed close.
Then it

1. renders the app layer once into a `ShaderEffectSource` (`live: false`), just as it is: moved down by the swipe
   and faded by the stock rule;
2. hides the stock layer (`hideSource`) until the stock close has finished, which lipstick runs as before;
3. plays the effect from that frozen frame in its overlay, with the window's rectangle at release and the finger's
   position as inputs. A new app shown in the meantime appears normally under the overlay.

A cover closed in the switcher (the × or *Close all*, which closes each cover) calls `coverClosing(wrapper)` before
the stock animation. SwitcherController freezes the cover and plays the closing effect at its place, staggered by
70 ms in *Close all*. The stock removes the cover's delegate after 200 ms, and a `ShaderEffectSource` loses its
texture with its source item. So the frozen frame is copied once more: a second, static `ShaderEffectSource` takes
a picture of the first one the frame after, and it outlives the cover (`FrozenCopy.qml`).

### Shatter

A pane broken at a point: 11 rays from it, rings at 0.05 to 1.5 screen heights, every cell split into two
triangles, about 130 shards, each with its own delay (by its distance from the point), throw, gravity and turn
about a random axis, drawn in perspective with a glint where it faces the light. Qt 5.6's `ShaderEffect` has no
custom meshes, so each shard is its own small item: a `ShaderEffect` the size of its bounding box that masks the
triangle, under a `Rotation` (3D axis) and a translation. The pattern is made once in JavaScript when the effect
starts. The cover version uses fewer rings (about 60 shards).

### Grains (Dust, Frost)

The grains are not separate items. Each pixel asks which grain covers it now: for four speed classes it steps back
along the grain's path (start time from the sweep and the noise, then drift and gravity), checks that the grain
there belongs to that class and has started, and draws it if it lands on the pixel. About 20 texture reads a
pixel; on the phone it may run at half resolution and be scaled up, which grains do not mind.

### Files

```
qml/animations/
  AnimationController.qml   the compositor's overlay: opening, closing, the warm-up, settings
  CoverLoading.qml          the loading effect in a switcher cover
  CoverClosing.qml          the closing effect over a closed cover (in SwitcherController)
  Effect.qml                a ShaderEffect for a style and moment: loads and caches its shader
  FrozenCopy.qml            a frozen frame that outlives its source
  Shards.qml                Shatter's shards
  styles.js                 the catalogue: ids, names, groups, durations, which moments a style has
  shaders/common.glsl       inputs and helpers (noise, easing, rounded rectangles, blur, tint)
  shaders/STYLE-open.frag, STYLE-close.frag, STYLE-load.frag
  noise.png                 the noise tile, made by scripts/noise.py at build time (not committed)
qml/settings/AnimationsPage.qml, AnimationSettings.qml
```

The shaders are files, not JavaScript strings: `Effect.qml` reads them once with `XMLHttpRequest` (Qt 5.6 reads
local files) and joins `common.glsl` in front. Fragment precision is `highp` where the GPU has it
(`GL_FRAGMENT_PRECISION_HIGH`), else `mediump`. The noise tile holds smooth noise (R), fractal noise (G), the
distance to the nearest Voronoi edge (B) and white noise (A); it repeats, through a `ShaderEffectSource` with
`wrapMode: Repeat`.

## Speed and safety

- **Only while something moves.** Effects exist only while they play. The overlay is empty otherwise, and the
  loading `Loader` is active only on a launching cover.
- **Warm-up.** Compiling a shader can stall a frame. When the home screen starts, and when a style is chosen, the
  controller makes each needed effect once, 1 × 1 pixel and invisible, so the first app opened does not stutter.
- **Budget.** One full-screen pass for the effect, plus one capture of the layer (live while opening, once when
  closing). The grains and the fire are the heaviest; they are checked on the phone with the harness and drop to
  half resolution if a frame takes longer than 12 ms.
- **The display going off** (`displayAboutToBeOff`) ends every effect at once, as the stock does with its
  transitions.

## The development lab

The looks were designed in a browser page that runs the same GLSL on a mock Sailfish home screen: an app grid, the
switcher, an app, the swipe to close, freeze and scrub for any frame, all ten styles and the settings page. It
moves into the repository as `scripts/animation-lab.html` and reads the shaders from `qml/animations/shaders/`, so
a shader can be tuned on the Mac before it goes to the phone. The page itself is not packaged.

## Testing

- **The harness** gets an `animations STYLE MOMENT [PROGRESS]` scene on stand-ins, like the others: one frame
  (`--shot`) or a run (`--frames`) for the docs' WebP. A `check` mode builds every style's three effects and logs
  `harness: animations OK|FAIL`, with the shader log for a failure (`ShaderEffect.status` and `log`).
- **Tests** check that every style in `styles.js` has its three shaders, the keys list, and the settings page's
  entries. CI compiles every shader with `glslangValidator` as GLSL ES 1.00.
- **On the phone,** before the rest: whether hiding the app layer during the stock close works, whether the fade's
  duration can be set from the step before it, and whether `transitioning` keeps the home screen drawn. These three
  decide the hook, so they come first, with the Seaglass style alone.

## Order of work

1. A spike on the phone: the hook in `compositor.qml` and `StackLayer.qml`, the Seaglass opening and closing, and
   the three checks above.
2. The effect files: `common.glsl`, the noise tile, `Effect.qml`, all opening and closing shaders ported from the
   lab, Shatter's shards, the grains at the right resolution.
3. Loading on the covers, closing covers, the origin from the app grid and the switcher.
4. The settings page with its preview, the hub row, reset and backup.
5. The harness scene, the tests, `glslangValidator` in CI, the lab in `scripts/`.
6. This note as the feature's documentation, a WebP for each group, the README and the site.

## Not in this round

- The side swipe home (see above).
- The busy indicator on an app grid icon: it shows only in a rare case (the app grid kept open while an app
  starts).
- Sound or vibration with the extreme styles.
