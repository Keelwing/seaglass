# Animations

Sailfish OS opens an app with a fade, shows a busy indicator on its cover while it starts, and closes it with a slide
and a fade. Seaglass adds styles for these three moments, from calm ones made of the ambience's glass, water and
light to loud ones that burn, shatter or swallow the app. Each effect is a shader on the GPU, played on a copy of the
window, so Sailfish never waits for it. Out of the box, apps open in *Ember*, load in *Dust* and close in
*Northern lights*.

<p align="center">
  <img src="images/animations-sailfish.webp" width="220" alt="Notes opening from its icon and closing in the Seaglass, Tide and Northern lights styles">
  <img src="images/animations-elements.webp" width="220" alt="Notes opening from its icon and closing in the Ember, Volt and Frost styles">
  <img src="images/animations-extreme.webp" width="220" alt="Notes opening from its icon and closing in the Shatter, Singularity and Dust styles">
</p>

## What you see

### The moments

- **Opening.** The app's window appears. Stock: a 150 ms pause until the window is drawn, then a 300 ms fade.
- **Loading.** An app that is not running starts. The app grid closes, the switcher gets a new cover for the app, and
  the cover shows the style's loading effect, with the app's icon, instead of the busy indicator. The app then opens
  from that cover.
- **Closing.** A swipe down from the top edge closes the app: the effect starts where the finger let go. Closing a
  cover in the switcher, with its × or *Close all*, plays the closing effect on the cover (*Covers too*).

An app opens from where it was tapped: from its icon in the app grid when it was running already, and from its cover
in the switcher when that was tapped or when it has just loaded there. Anything else (a notification, a link,
another app) opens it from the middle of the screen. Going home with a swipe from the side keeps the stock motion:
the window follows the finger into the switcher, and an effect there would read as closing the app.

### The styles

Nine styles in three groups, and the stock one. The lengths are at the normal speed.

| Style | Opening | Loading | Closing |
|---|---|---|---|
| **Stock** | Fades in, 300 ms | A busy indicator on the new cover | Slides on and fades out, 300 ms |
| *Sailfish: calm, made of glass, water and light* | | | |
| **Seaglass** | Rises from the icon as frosted glass in the ambience's colour and clears as it lands, 480 ms | A glass cover in the ambience's colour; a light runs round its edge, a glint crosses it and the icon breathes | Frosts over, rounds into a pebble and sinks; a ring spreads where it went in, 560 ms |
| **Tide** | A drop lands on the icon and throws a crown of droplets; the app spreads in its ripple, 650 ms | Water rises in the cover over the icon, with caustics and bubbles | A wave rolls up from the bottom and washes it away under a lip of foam, 720 ms |
| **Northern lights** | A thin ray rises from the icon, and curtains of aurora sweep down and leave the app behind them, 780 ms | An aurora over dark hills and a still lake that mirrors it | Melts upward into rays of light that rise and fade, 850 ms |
| *Elements: fire, lightning and ice* | | | |
| **Ember** | A ring of fire spreads from the icon, sparks flying ahead of it, 620 ms | The cover smoulders: coals, low flames, rising sparks | Burns away from the bottom up: charring, a glowing edge, flames and heat haze, 880 ms |
| **Volt** | Lightning strikes the icon and lights up the screen around it, then an electric ring opens the app, 620 ms | Arcs run around the cover's edge, and now and then a bolt strikes the icon | Arcs crawl over the window, then it switches off like an old TV, 700 ms |
| **Frost** | Frost forms over the screen and melts away from the icon outward, 700 ms | Frost grows over the cover from its edges and thaws again | Freezes from the edges, cracks from where the finger let go, and falls apart as snow, 950 ms |
| *Extreme: loud on purpose* | | | |
| **Shatter** | Shards burst out of the icon and fit together into the app; the seams glow and vanish, 720 ms | The cover cracks from a point on the icon; the cracks fill with gold and heal | Breaks where the finger let go; the shards fall, turning and catching the light, 1000 ms |
| **Singularity** | The app bursts out of a white hole at the icon, 660 ms | A small black hole spins in the cover, bending the icon around it | Pulled into a black hole with a glowing disk, which then winks out, 950 ms |
| **Dust** | Sand blows in and settles into the app, from the icon outward, 800 ms | Sand pours through the cover into a heap | Crumbles from the top down into dust that the wind takes, 1050 ms |

With *Ambience colours* on (the default), fire, water, ice and light take the ambience's highlight colour: a blue
ambience burns blue. Off, they have their natural colours. Tide's water keeps its own deep colour either way, and only
its light takes the ambience's. Seaglass is always in the ambience's colour.

### The settings

*Settings → Patchmanager → Seaglass → Animations*. The row on the first page shows the style of each moment,
*Surprise me* or *Off*.

<p align="center"><img src="images/settings-animations.jpg" width="250" alt="The animations settings: a live preview, and the styles as tiles with their loading effects"></p>

- **Preview.** A small home screen over the ambience's picture, as on the *Glass* page. Notes opens from its icon in
  the app grid and closes, then starts on a new cover in the switcher, opens from there and closes, over and over.
  Each moment takes its style as the home screen would, so *Moments*, *Surprise me* and *Speed* show in it at once.
  *Open*, *Loading* and *Close* under it jump to that moment. The preview draws with the home screen's own effect
  files, on a made-up app and stock icons.
- **App animations.** On or off. Off is the stock behaviour.
- **Style.** The ten styles as tiles, three to a row under their group's name, each showing its loading effect live.
  A tap picks the style for all three moments, turns the animations on, and plays a round of it in the preview.
- **Surprise me.** A different style each time an app opens, loads or closes (never *Stock*). A moment set to
  *Stock* stays stock.
- **Moments.** *Opening*, *Loading* and *Closing*, each *Same as style*, *Stock* or any style: the calm opening of
  *Seaglass* can go with an *Ember* close. By default *Ember* opens, *Dust* loads and *Northern lights* closes.
- **Speed.** *Relaxed* (×1.35), *Normal* or *Quick* (×0.72, the default).
- **Ambience colours.** As above.
- **Covers too.** Closing a cover in the switcher, or all of them, plays the closing effect on the covers. Off, they
  close the stock way.

The settings are in dconf under `/apps/seaglass/animations`, and the home screen follows them live:

| Setting | Key | Default | Values |
|---|---|---|---|
| App animations | `enabled` | true | |
| Style | `style` | `ember` | `seaglass`, `tide`, `aurora`, `ember`, `volt`, `frost`, `shatter`, `singularity`, `dust`, `stock` |
| Opening, Loading, Closing | `open`, `loading`, `close` | `ember`, `dust`, `aurora` | `""` (same as style), `stock` or a style |
| Surprise me | `surprise` | false | |
| Speed | `speed` | 2 | 0 relaxed, 1 normal, 2 quick |
| Ambience colours | `ambience` | true | |
| Covers too | `covers` | true | |

Reset, backup and restore cover the group like the others.

## How it works

Three rules hold for every effect:

- **Sailfish is never kept waiting.** The window is shown, focused and closed at the stock moment. The effect plays on
  a copy of it, over or in place of the stock layer, and touch goes to the app as soon as the stock would let it.
- **One shader per effect.** Each effect is a `ShaderEffect` with one fragment shader and the same inputs: the layer
  as a texture, a 256 × 256 noise tile, `progress` from 0 to 1, `time` in seconds, the origin point, rectangle and
  corner radius, the aspect ratio, the size in pixels, the ambience's highlight colour and whether to use it. While
  an app opens or closes, `time` is the effect's own (its progress times its length), so it follows the speed; a
  loading effect has a clock that runs on. Shatter is the exception (below).
- **Stock when anything fails.** No controller, a shader not loaded yet, a style that does not load: the stock fade,
  indicator and slide run as before. The hook changes stock values only through what our files return.

### The hook

Two more stock files, and two that were hooked already ([ARCHITECTURE.md](ARCHITECTURE.md)):

```
compositor.qml
  ├─ transitions    Loader → animations/AnimationController.qml    failed → the stock opening and closing
  │                 right after the app layer, under the dialog and alarm layers;
  │                 appLayerItem gets `seaglassTransitions: <the loaded item>`
  └─ seaglassAboveLayers   an empty Item above the layers (z 1), where the closing effects play
layers/StackLayer.qml
  ├─ property QtObject seaglassTransitions: null                     (set only on the app layer)
  ├─ showAnimation: before the FadeAnimator, a ScriptAction calls seaglassTransitions.opening(layer)
  └─ transitioning: also true while the effect plays, so that lipstick keeps drawing the home screen under it
switcher/Switcher.qml       SwitcherController.qml finds the cover an app opens from (no new lines)
switcher/SwitcherItem.qml
  ├─ loading        Loader → animations/CoverLoading.qml            failed → the stock busy indicator
  │                 the busy indicator and the icon stay hidden only while its effect plays
  └─ close()        first calls seaglassSwitcher.item.coverClosing(wrapper)
```

### Opening

`StackLayer`'s show animation waits 150 ms, then until the window is mapped, then fades the layer in over 300 ms.
The hook's step before the fade calls `AnimationController.opening(layer)`, on the pass that fades only (the stock
restarts the animation while the window is not mapped, with `retries` above 0). The controller:

1. picks the style for *Opening*, or answers `false` (off, stock, or its shader not loaded yet);
2. takes the origin: the icon that `HomeController.qml` noted when it launched an app, within the last 3 s and
   while the app grid is still out, else the cover the app has in the switcher (`SwitcherController.coverRectFor`,
   which also finds a cover that is still loading, by its app), else the middle of the screen. Its corner radius
   goes with it: half the icon's width (launcher icons are round), the cover's corners as the switcher draws them,
   or none from the middle;
3. puts a live `ShaderEffectSource` on the app layer (`hideSource`, so that the layer is not drawn twice) under the
   effect, and runs `progress` from 0 to 1;
4. lets the layer show again when done.

The stock fade runs on underneath, unseen: a running animation keeps the durations it started with, so it cannot be
cut short from inside, and the copy leaves out the layer's own opacity, which is what the fade changes. While the
effect plays, the hook keeps the layer `transitioning`; otherwise lipstick sees an opaque app layer and stops drawing
the home screen under the half-open app.

### Loading

`Switcher.activateWindowFor` makes the launching cover and goes to the switcher. In each cover a `Loader` holds
`CoverLoading.qml` while the cover is launching. It picks the style for *Loading* once, and draws the style's loading
shader over the cover, with the app's icon as its texture and `time` running. When the window is mapped, the cover
stops launching, the Loader lets go of the effect, and the opening effect starts from this cover.

### Closing

The controller listens for two signs of a committed close: the app layer's `peekFilter.gestureTriggered` with
`topActive`, and the layer itself closing a window (`closing` with a `closingWindowId`). The first one to come calls
`closing()` once. Then it

1. renders the window once into a `ShaderEffectSource` (`live: false`) from the layer's `snapshotSource`: the whole
   window, without the stock fade and wipe;
2. hides the whole app layer through a second, unused `ShaderEffectSource` (`hideSource`) while the stock close runs
   on underneath, for at most 800 ms;
3. plays the effect in `seaglassAboveLayers`. The window first comes back from where the swipe left it (its wiped top
   edge and its fade, whole again in 180 ms) while the effect takes it away. A new app shown meanwhile appears
   normally under it.

The effect cannot play in the app layer's own overlay: `peekLayer`, which holds the app layer, hides as soon as the
stock close is over, and most effects last longer.

A cover closed in the switcher calls `coverClosing(wrapper)` before the stock animation, which fades the cover and
drops it a little in 200 ms. SwitcherController puts `CoverClosing.qml` at the cover's place, in the item that holds
the covers. The stock removes the cover's delegate after 200 ms, and a `ShaderEffectSource` loses its picture with its
source item, so the frozen cover is copied once more, a frame later, into a picture of its own. A window that closed
with its own swipe has played its effect already, so its cover closes the stock way (`motion.js`,
`noteWindowClosing`).

### Shatter

A pane broken at a point: 11 rays from it and rings at 0.05 to 1.5 screen heights, every cell split into two
triangles, about 100 shards, each with its own delay (by its distance from the point), throw, gravity and turn about a
random axis, drawn in perspective with a glint where it faces the light. Each triangle knows how its edges broke, so
the cracks out from the point are drawn brightest and the cuts that split a cell faintest. Qt 5.6's `ShaderEffect` has
no custom meshes, so each shard is its own small `ShaderEffect` over its triangle's bounding box:
`shaders/shards.vert` turns and moves it, `shaders/shards.frag` cuts the triangle out. The shard items are made once;
a new break only lays them out again (`Shards.qml`, `build()`). A cover breaks into 9 rays and 5 rings, about 60
shards. An app opens the other way: each shard leaves the icon small and turning and lands in its place, the near
ones first.

### Grains: Dust and Frost

The grains are not separate items. Each pixel asks which grain covers it now: for four speed classes it steps back
along the grain's path (its start from the sweep and the noise, then drift and gravity), checks that the grain there
belongs to that class and has started, and draws it if it lands on the pixel (`grains.glsl`; Frost's snow finds its
flakes the same way, in `frost.glsl`). That is about 20 texture reads a pixel, so the moments with grains or snow
draw them at half the resolution (`layer.textureSize`) and scale them up, which grains do not mind: Dust's opening
and closing, and Frost's closing (`half` in `styles.js`, per moment; the two styles' loading effects are drawn at
half too). Through the half-size layer the window would also look soft at the start of a close, and the app at the
end of an open would sharpen at once when the effect ended. So these three moments are split (`split`): `Effect.qml`
draws the picture at full resolution and only the grains at half, in a second pass of the same shader over it, and
the shader reads `part` to know which of the two it draws. Frost's opening has no grains and draws at full
resolution.

### The shaders

The shaders are files: `shaders/STYLE-open.frag`, `-load.frag` and `-close.frag`, behind `shaders/common.glsl` (the
inputs, noise, easing, rounded rectangles, the blur, the tint) and the style's libraries (`aurora.glsl`, `ember.glsl`,
`volt.glsl`, `frost.glsl`, `grains.glsl`). `shaders.js` reads each one once with `XMLHttpRequest` (Qt 5.6 reads local
files) and keeps it for the QML engine. They are GLSL ES 1.00. Where the GPU has OpenGL ES 3 (the Jolla Phone's
Mali-G610 does), `Effect.qml` runs them as GLSL ES 3.00 with a vertex shader of its own: `shaders.js` puts
`#version 300 es` and `#define ES3` in front, and the styles that blur read a mipmap level of the window's copy
(`textureLod`), which has mipmaps for them only. The blur's taps are turned by an angle of each pixel's own, so the
level's texels never line up into squares; what is left is a fine grain, as on frosted glass. The noise tile holds
smooth noise, fractal noise, the distance to the nearest Voronoi edge and white noise in its four channels.
`scripts/noise.py` makes it when the package is built.

## Costs

- **Only while something moves.** The effects draw only while they play. The overlay is empty otherwise, and a
  cover's loading `Loader` is active only while the cover is launching.
- **Warm-up.** Compiling a shader can stall a frame. The controller reads every shader when the home screen starts,
  and from 3 s on compiles the ones the settings can pick, one every 150 ms, a pixel large and nearly clear: every
  style's with *Surprise me*, else the chosen ones. It starts again when the settings change. Until a shader is read,
  its moment plays the stock way.
- **Budget.** One full-screen pass for the effect and one capture of the layer: live while opening, once when closing.
  A split moment adds a second pass at half the resolution for its grains. The grains, the fire and Frost's opening
  are the heaviest: the grains draw at half the resolution, and Frost's opening reads about 20 textures a pixel at
  full resolution while the whole screen is iced, fewer as it melts.
- **The display going off** (`displayAboutToBeOff`) ends every effect at once, as the stock does with its transitions.

## Limits

- `ShaderEffect.status` cannot tell whether a shader works: on Sailfish OS 5.2 it reads `Error` for shaders that
  compiled and draw. A shader that does not compile draws nothing, and Qt says so in the log
  (`QOpenGLShader::compile`). `make lint` compiles every shader with `glslangValidator`, as GLSL ES 1.00 and 3.00.
- Without OpenGL ES 3 the blur has no mipmaps: it takes nine texels of the full-size copy, and under thick frost
  (*Seaglass*, *Frost*) text can show double. The Jolla Phone has OpenGL ES 3.
- With *Cards* as the switcher's layout, covers close the stock way.
- The busy indicator on an app grid icon (shown in a rare case, when the app grid stays open while an app starts)
  keeps its stock look.
- Without the closing effect's shader loaded, a cover closes the stock way (it would vanish otherwise).

## The code

- [AnimationController.qml](../qml/animations/AnimationController.qml): the compositor's overlay: opening, closing,
  the warm-up, the settings.
- [Effect.qml](../qml/animations/Effect.qml): a `ShaderEffect` for a style and moment, which loads its shader.
- [Shards.qml](../qml/animations/Shards.qml): Shatter's shards. [NoiseTile.qml](../qml/animations/NoiseTile.qml): the
  noise tile as a texture that repeats.
- [CoverLoading.qml](../qml/animations/CoverLoading.qml), [CoverClosing.qml](../qml/animations/CoverClosing.qml): the
  effects on the switcher's covers.
- [styles.js](../qml/animations/styles.js): the styles, their groups and lengths, and how a moment's style is
  chosen. [shaders.js](../qml/animations/shaders.js): reading the shaders.
- [shaders/](../qml/animations/shaders/): the shaders.
- [AnimationsPage.qml](../qml/settings/AnimationsPage.qml), [NotesPreview.qml](../qml/settings/NotesPreview.qml),
  [AnimationSettings.qml](../qml/settings/AnimationSettings.qml): the settings page with its preview, its made-up app,
  and the dconf keys.
- [apply_hook.py](../hook/apply_hook.py): `hook_compositor`, `hook_stack_layer`, and the loading and closing in
  `hook_switcher_item`.
- The harness: the `animations` scene draws one effect or checks that every shader compiles; the `reel` scene plays
  styles one after the other for the WebPs above ([DEVELOPMENT.md](DEVELOPMENT.md)).
